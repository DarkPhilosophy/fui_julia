module Parser

using Mmap
using Base.Threads: @spawn, @threads
using ..XDebug
using ..Safety
using ..FileOps

export parse_file, ParserResult, PartData

"""
    PartData

Structure representing part data from BOM or PINS files.
Contains the part identifier, type, and associated data points.
"""
struct PartData
    part::String
    type::String
    data::Vector{Dict{String, Any}}
end

"""
    ParserResult

Container for parsing results with metadata.
"""
struct ParserResult
    extracts::Vector{PartData}
    success::Bool
    factor::Float64  # Conversion factor (1.0 or 25.4 for inch)
    message::String
    parse_time::Float64  # Time taken to parse in seconds
end

"""
    parse_file(file_path::String, file_type::String, logger=nothing)

High-performance file parser optimized for BOM and PINS files.
Uses memory mapping and multi-threading for efficient parsing.
    
# Arguments
- `file_path::String`: Path to the file to parse
- `file_type::String`: Type of file ("BOM" or "PINS")
- `logger`: Optional logger for debug output

# Returns
- `ParserResult`: Structure containing parsing results and metadata
"""
function parse_file(file_path::String, file_type::String, logger=nothing)
    start_time = time()
    log_msg = logger !== nothing ? (msg) -> XDebug.log_info(logger, msg) : (msg) -> nothing
    
    log_msg("Starting to parse $file_type file: $file_path")
    
    # Define regex patterns for efficient matching
    patterns = Dict(
        "BOM" => r"^\s*(\S+)\s*,\s*([0-9\.\-]+),\s*([0-9\.\-]+),\s*([0-9\.\-]+),\s*(\S+)\s*,\s*\((.)?\)\,\s*([0-9\.\-]+),\s*(\S+),\s*'([^']*)',\s*'([^']*)';",
        "PINS_HEADER" => r"^Part\s+(\S+)\s+\((\w+)\)",
        "PINS_DATA1" => r"^\s*(\S+)\s+(\S+)\s+([0-9\.\-]+)\s+([0-9\.\-]+)\s+([0-9\.\-]+)\s+(\S+)$",
        "PINS_DATA2" => r"^\s*\"(\S+)\",\"(\S+)\",\"([0-9\.\-]+)\",\"([0-9\.\-]+)\",\"([0-9\.\-]+)\",\"(\S+)\",\"\",\"\"$"
    )
    
    # Use Safety module to handle file operations
    result = Safety.safe_operation(
        () -> begin
            # Check if file exists
            if !isfile(file_path)
                return ParserResult(PartData[], false, 1.0, "File not found: $file_path", 0.0)
            end
            
            # Use memory-mapped IO for better performance with large files
            open(file_path) do file
                # Initialize data structures
                extracts = PartData[]
                current_part = nothing
                conversion_factor = 1.0
                
                # For fast lookup of existing parts (avoid duplicates)
                part_dict = Dict{String, Int}()
                
                # Quick check for unit system in BOM files
                if file_type == "BOM"
                    # Use first 1000 bytes to check for "INCH" keyword
                    header = read(file, min(1000, filesize(file_path)))
                    if occursin("INCH", String(header))
                        conversion_factor = 25.4  # Convert inches to mm
                        log_msg("Detected inch units, using conversion factor: $conversion_factor")
                    end
                    seekstart(file)
                end
                
                # Memory map the file for faster processing
                file_data = mmap(file)
                file_str = String(file_data)
                lines = split(file_str, r"\r?\n")
                
                # Process lines based on file type
                if file_type == "BOM"
                    # Pre-allocate for performance
                    seen_data_keys = Set{String}()
                    
                    # Process each line in parallel for large files
                    if length(lines) > 10000
                        chunks = Iterators.partition(lines, max(1, div(length(lines), Threads.nthreads())))
                        partial_results = Vector{Vector{PartData}}(undef, length(collect(chunks)))
                        
                        @threads for (i, chunk) in collect(enumerate(chunks))
                            partial_results[i] = _process_bom_chunk(chunk, patterns["BOM"], seen_data_keys)
                        end
                        
                        # Merge results
                        for partial in partial_results
                            append!(extracts, partial)
                        end
                    else
                        # Process sequentially for smaller files
                        @inbounds for line in lines
                            _process_bom_line!(extracts, line, patterns["BOM"], part_dict, seen_data_keys)
                        end
                    end
                elseif file_type == "PINS"
                    @inbounds for line in lines
                        _process_pins_line!(extracts, line, patterns, current_part)
                    end
                end
                
                # Unmap the file
                finalize(file_data)
                
                elapsed_time = time() - start_time
                log_msg("Parsed $file_type file with $(length(extracts)) entries in $(round(elapsed_time, digits=3)) seconds")
                
                return ParserResult(extracts, true, conversion_factor, "Success", elapsed_time)
            end
        end,
        (err) -> begin
            error_msg = "Error parsing $file_type file: $err"
            if logger !== nothing
                XDebug.log_error(logger, error_msg)
            end
            return ParserResult(PartData[], false, 1.0, error_msg, time() - start_time)
        end
    )
    
    return result
end

"""
Process a chunk of BOM lines in parallel
"""
function _process_bom_chunk(lines, pattern, shared_seen_keys)
    local_extracts = PartData[]
    local_part_dict = Dict{String, Int}()
    local_seen_keys = Set{String}()
    
    for line in lines
        _process_bom_line!(local_extracts, line, pattern, local_part_dict, local_seen_keys)
    end
    
    # Synchronize seen keys with shared set
    lock(shared_seen_keys) do
        union!(shared_seen_keys, local_seen_keys)
    end
    
    return local_extracts
end

"""
Process a single BOM line
"""
function _process_bom_line!(extracts, line, pattern, part_dict, seen_data_keys)
    # Skip empty lines
    if isempty(strip(line))
        return
    end
    
    # Match the line against the BOM pattern
    m = match(pattern, line)
    if m === nothing
        return
    end
    
    # Extract values from regex match
    part, x_str, y_str, rot_str, grid, typ, size, shp, device, outline = m.captures
    
    # Convert coordinates and rotation to numbers
    x = parse(Float64, x_str)
    y = parse(Float64, y_str)
    rot = parse(Float64, rot_str)
    
    # Check if this is a valid component
    if (shp == "PTH" || shp == "RADIAL") && 
       !occursin("NOT_LOADED", device) && !occursin("NOT_LOAD", device) &&
       !occursin("NO_LOADED", device) && !occursin("NO_LOAD", device)
        
        # Create unique key for quick lookup
        part_key = "$(part)_$(typ)"
        data_key = "$(x)_$(y)_$(rot)"
        
        # Check if we've seen this data point before
        if !(data_key in seen_data_keys)
            push!(seen_data_keys, data_key)
            
            # Find or create part entry
            part_idx = get(part_dict, part_key, 0)
            if part_idx == 0
                # Create new part
                push!(extracts, PartData(part, typ, [Dict{String, Any}(
                    "x" => x,
                    "y" => y,
                    "rot" => rot,
                    "grid" => grid,
                    "shp" => shp,
                    "device" => device,
                    "outline" => outline
                )]))
                part_dict[part_key] = length(extracts)
            else
                # Add data to existing part
                push!(extracts[part_idx].data, Dict{String, Any}(
                    "x" => x,
                    "y" => y,
                    "rot" => rot,
                    "grid" => grid,
                    "shp" => shp,
                    "device" => device,
                    "outline" => outline
                ))
            end
        end
    end
end

"""
Process a single PINS line
"""
function _process_pins_line!(extracts, line, patterns, current_part)
    # Skip empty lines
    if isempty(strip(line))
        return
    end
    
    # Check for header line
    header_match = match(patterns["PINS_HEADER"], line)
    if header_match !== nothing
        part, typ = header_match.captures
        new_part = PartData(part, typ, Dict{String, Any}[])
        push!(extracts, new_part)
        current_part = new_part
        return
    end
    
    # Check for data lines
    data1_match = match(patterns["PINS_DATA1"], line)
    data2_match = match(patterns["PINS_DATA2"], line)
    
    if data1_match !== nothing
        pin, _, x_str, y_str, layer_str, net = data1_match.captures
        x = parse(Float64, x_str)
        y = parse(Float64, y_str)
        
        if current_part !== nothing
            # Convert layer string to number
            layer_num = if layer_str == "Top"
                1
            elseif layer_str == "Bottom"
                2
            else
                try
                    parse(Int, layer_str)
                catch
                    nothing
                end
            end
            
            if layer_num !== nothing
                push!(current_part.data, Dict{String, Any}(
                    "pin" => pin,
                    "name" => pin,
                    "x" => x,
                    "y" => y,
                    "layer" => layer_num,
                    "net" => net
                ))
            end
        end
    elseif data2_match !== nothing
        part, pin, x_str, y_str, layer, net = data2_match.captures
        x = parse(Float64, x_str)
        y = parse(Float64, y_str)
        
        # Find or create part
        target_part = current_part
        if part !== nothing
            found = false
            for p in extracts
                if p.part == part
                    target_part = p
                    found = true
                    break
                end
            end
            
            if !found
                # Create new part
                new_part = PartData(part, layer[1:1], Dict{String, Any}[])
                push!(extracts, new_part)
                target_part = new_part
            end
        end
        
        if target_part !== nothing
            layer_num = if layer == "Top"
                1
            elseif layer == "Bottom"
                2
            else
                try
                    parse(Int, layer)
                catch
                    nothing
                end
            end
            
            if layer_num !== nothing
                push!(target_part.data, Dict{String, Any}(
                    "pin" => pin,
                    "name" => pin,
                    "x" => x,
                    "y" => y,
                    "layer" => layer_num,
                    "net" => net
                ))
            end
        end
    end
end

end # module