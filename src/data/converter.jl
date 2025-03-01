module Converter

using ..XDebug
using ..Safety
using ..Parser
using ..FileOps
using Base.Threads: @spawn, @threads
using Printf: @sprintf

export generate_csv, CSVResult

"""
    CSVResult

Structure representing the result of a CSV generation operation.
"""
struct CSVResult
    success::Bool
    top_success::Bool
    bot_success::Bool
    message::String
    top_path::String
    bot_path::String
    elapsed_time::Float64
end

"""
    generate_csv(bom_data::Vector{Parser.PartData}, pins_data::Union{Vector{Parser.PartData}, Nothing},
                client::String, part_number::String, factor::Float64, progress_callback::Function,
                logger=nothing)

Generate CSV files from parsed BOM and PINS data.

# Arguments
- `bom_data`: Vector of parsed BOM part data
- `pins_data`: Vector of parsed PINS part data (can be nothing)
- `client`: Client identifier for file naming
- `part_number`: Part number for file naming
- `factor`: Unit conversion factor
- `progress_callback`: Function to call with progress updates (0-100)
- `logger`: Optional logger for debug output

# Returns
- `CSVResult`: Structure with generation results and metadata
"""
function generate_csv(bom_data::Vector{Parser.PartData}, pins_data::Union{Vector{Parser.PartData}, Nothing},
                      client::String, part_number::String, factor::Float64, progress_callback::Function,
                      logger=nothing)
    
    start_time = time()
    log_msg = logger !== nothing ? (msg) -> XDebug.log_info(logger, msg) : (msg) -> nothing
    
    log_msg("Starting CSV generation for client: $client, part: $part_number")
    progress_callback(0, "Starting CSV generation...")
    
    # Validate inputs
    if isempty(bom_data)
        return CSVResult(false, false, false, "No BOM data provided", "", "", 0.0)
    end
    
    if isempty(part_number)
        return CSVResult(false, false, false, "No part number provided", "", "", 0.0)
    end
    
    if isempty(client)
        client = "UNKNOWN_CLIENT"
        log_msg("No client specified, using: $client")
    end
    
    # Use safe operation to handle any exceptions
    result = Safety.safe_operation(
        () -> begin
            # Track success status
            top_success = Dict("T" => false, "B" => false)
            bot_success = Dict("T" => false, "B" => false)
            
            # Prepare data structures for top-side CSV
            progress_callback(10, "Preparing top-side CSV...")
            top_lines = Dict("T" => String[], "B" => String[])
            
            # Process BOM data for top-side CSV
            @threads for bom_part in bom_data
                if bom_part.type == "T" || bom_part.type == "B"
                    # Pre-allocate string buffer for each part
                    part_lines = String[]
                    
                    for bom_entry in bom_part.data
                        pn = string(client, "-", get(bom_entry, "device", "NO_CLIENT"))
                        line = string(
                            get(bom_entry, "part", "MISSING_PART"), ",",
                            @sprintf("%.2f", get(bom_entry, "x", 0) * factor), ",",
                            @sprintf("%.2f", get(bom_entry, "y", 0) * factor), ",",
                            @sprintf("%.2f", get(bom_entry, "rot", 0)), ",",
                            pn, ",", pn, "\n"
                        )
                        push!(part_lines, line)
                    end
                    
                    # Synchronize with the shared collection
                    if !isempty(part_lines)
                        lock(() -> append!(top_lines[bom_part.type], part_lines))
                    end
                end
            end
            
            # Write top-side CSV files
            progress_callback(30, "Writing top-side CSV files...")
            for side in ["T", "B"]
                if !isempty(top_lines[side])
                    top_path = "$(part_number)_faza$(side == "T" ? 1 : 2)_TOP.csv"
                    log_msg("Writing $(length(top_lines[side])) lines to $top_path")
                    
                    FileOps.with_file(top_path, "w") do file
                        for line in top_lines[side]
                            write(file, line)
                        end
                    end
                    
                    top_success[side] = true
                    log_msg("Successfully wrote $top_path")
                end
            end
            
            # Process pins data for bottom-side CSV if available
            bot_lines = Dict("T" => String[], "B" => String[])
            if pins_data !== nothing && !isempty(pins_data)
                progress_callback(50, "Preparing bottom-side CSV...")
                
                # Create lookup table for pins data
                pins_lookup = Dict{String, Parser.PartData}()
                for pins_part in pins_data
                    pins_lookup[pins_part.part] = pins_part
                end
                
                # Process BOM data with PINS data
                @threads for bom_part in bom_data
                    # Pre-allocate string buffer for each part
                    part_lines = String[]
                    
                    for bom_entry in bom_part.data
                        pins_part = get(pins_lookup, bom_part.part, nothing)
                        if pins_part !== nothing && pins_part.type == bom_part.type
                            for pins_entry in pins_part.data
                                pn = string(client, "-", get(bom_entry, "device", "NO_CLIENT"))
                                line = string(
                                    bom_part.part, ".", get(pins_entry, "pin", "X"), ",",
                                    @sprintf("%.2f", get(pins_entry, "x", 0) * factor), ",",
                                    @sprintf("%.2f", get(pins_entry, "y", 0) * factor), ",0,",
                                    pn, ",THD\n"
                                )
                                push!(part_lines, line)
                            end
                        end
                    end
                    
                    # Synchronize with the shared collection
                    if !isempty(part_lines)
                        lock(() -> append!(bot_lines[bom_part.type], part_lines))
                    end
                end
                
                # Write bottom-side CSV files
                progress_callback(70, "Writing bottom-side CSV files...")
                for side in ["T", "B"]
                    if !isempty(bot_lines[side])
                        bot_path = "$(part_number)_faza$(side == "T" ? 1 : 2)_BOT.csv"
                        log_msg("Writing $(length(bot_lines[side])) lines to $bot_path")
                        
                        FileOps.with_file(bot_path, "w") do file
                            for line in bot_lines[side]
                                write(file, line)
                            end
                        end
                        
                        bot_success[side] = true
                        log_msg("Successfully wrote $bot_path")
                    end
                end
            else
                log_msg("No PINS data provided, skipping bottom-side CSV")
            end
            
            progress_callback(100, "CSV generation complete")
            
            # Determine overall success and create result paths
            top_any_success = top_success["T"] || top_success["B"]
            bot_any_success = bot_success["T"] || bot_success["B"]
            
            top_path = top_any_success ? "$(part_number)_faza1_TOP.csv" : ""
            bot_path = bot_any_success ? "$(part_number)_faza1_BOT.csv" : ""
            
            message = if top_any_success && bot_any_success
                "Successfully generated TOP and BOT CSV files"
            elseif top_any_success
                "Successfully generated TOP CSV files only"
            elseif bot_any_success
                "Successfully generated BOT CSV files only"
            else
                "No CSV files were generated"
            end
            
            elapsed_time = time() - start_time
            log_msg("CSV generation completed in $(round(elapsed_time, digits=3)) seconds")
            
            return CSVResult(
                top_any_success || bot_any_success,
                top_any_success,
                bot_any_success,
                message,
                top_path,
                bot_path,
                elapsed_time
            )
        end,
        (err) -> begin
            error_msg = "Error generating CSV: $err"
            if logger !== nothing
                XDebug.log_error(logger, error_msg)
                XDebug.log_backtrace(logger)
            end
            
            progress_callback(0, "Error: CSV generation failed")
            
            return CSVResult(
                false,
                false,
                false,
                error_msg,
                "",
                "",
                time() - start_time
            )
        end
    )
    
    return result
end

end # module