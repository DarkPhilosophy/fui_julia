module Parser

using Mmap
using Base.Threads: @spawn, @threads
using Logging

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

# Constants for file types
const BOM_PATTERN = r"^\s*(\S+)\s*,\s*([0-9.-]+),\s*([0-9.-]+),\s*([0-9.-]+),\s*(\S+)\s*,\s*\((.)?\),\s*([0-9.-]+),\s*(\S+),\s*'([^']*)',\s*'([^']*)';"
const PINS_HEADER_PATTERN = r"^Part\s+(\S+)\s+\((\w+)\)"
const PINS_DATA1_PATTERN = r"^\s*(\S+)\s+(\S+)\s+([0-9.-]+)\s+([0-9.-]+)\s+([0-9.-]+)\s+(\S+)$"
const PINS_DATA2_PATTERN = r"^\s*\"(\S+)\",\"(\S+)\",\"([0-9.-]+)\",\"([0-9.-]+)\",\"(\w+)\",\"(\S+)\",\"\",\"\"$"

"""
    parse_file(fileOrText::Union{String, IO}, fileType::String)

Parse BOM or PINS files into structured data.
"""
function parse_file(fileOrText::Union{String, IO}, fileType::String)
    @info "Starting file parsing for type: $fileType"
    
    extracts = []
    current_part = nothing
    
    function process_bom_line(line::String)
        m = match(BOM_PATTERN, line)
        if m === nothing
            return
        end
        
        part, x, y, rot, grid, typ, size, shp, device, outline = m.captures
        x, y, rot = parse.(Float64, (x, y, rot))
        
        if !isnothing(x) && !isnothing(y) && (shp == "PTH" || shp == "RADIAL") &&
           device != "NOT_LOADED" && device != "NOT_LOAD" &&
           device != "NO_LOADED" && device != "NO_LOAD"
            
            # Find existing part or create new one
            existing_part = nothing
            for extract in extracts
                if extract["part"] == part && extract["type"] == typ
                    existing_part = extract
                    break
                end
            end
            
            if isnothing(existing_part)
                existing_part = Dict(
                    "part" => part,
                    "type" => typ,
                    "data" => [],
                    "seen_data" => Set{String}()
                )
                push!(extracts, existing_part)
            end
            
            # Create unique key for data
            data_key = "$x|$y|$rot"
            
            if !(data_key in existing_part["seen_data"])
                push!(existing_part["data"], Dict(
                    "x" => x,
                    "y" => y,
                    "rot" => rot,
                    "grid" => grid,
                    "shp" => shp,
                    "device" => device,
                    "outline" => outline
                ))
                push!(existing_part["seen_data"], data_key)
            end
        end
    end
    
    function process_pins_line(line::String)
        # Try header pattern first
        m = match(PINS_HEADER_PATTERN, line)
        if !isnothing(m)
            part, typ = m.captures
            if !isnothing(part) && !isnothing(typ)
                current_part = Dict(
                    "part" => part,
                    "type" => typ,
                    "data" => []
                )
                push!(extracts, current_part)
            end
            return
        end
        
        # Try data patterns
        local part, pin, x, y, layer, net
        m = match(PINS_DATA1_PATTERN, line)
        if !isnothing(m)
            pin, _, x, y, layer, net = m.captures
        else
            m = match(PINS_DATA2_PATTERN, line)
            if !isnothing(m)
                part, pin, x, y, layer, net = m.captures
            end
        end
        
        if !isnothing(pin) || !isnothing(part)
            x = parse(Float64, x)
            y = parse(Float64, y)
            
            if !isnothing(x) && !isnothing(y)
                target_part = if !isnothing(part)
                    # Find or create part
                    found_part = nothing
                    for p in extracts
                        if p["part"] == part
                            found_part = p
                            break
                        end
                    end
                    
                    if isnothing(found_part)
                        found_part = Dict(
                            "part" => part,
                            "type" => layer[1:1],
                            "data" => []
                        )
                        push!(extracts, found_part)
                    end
                    found_part
                else
                    current_part
                end
                
                if !isnothing(target_part)
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
                    
                    if !isnothing(layer_num)
                        push!(target_part["data"], Dict(
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
    end
    
    # Process the file line by line
    lines = fileOrText isa String ? split(fileOrText, r"\r?\n") : eachline(fileOrText)
    for line in lines
        line = strip(line)
        if !isempty(line)
            if fileType == "BOM"
                process_bom_line(line)
            elseif fileType == "PINS"
                process_pins_line(line)
            else
                @error "Unknown file type: $fileType"
                return []
            end
        end
    end
    
    @info "Parsed $(length(extracts)) entries for $fileType"
    return extracts
end

end # module