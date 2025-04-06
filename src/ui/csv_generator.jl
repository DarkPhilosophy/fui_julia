module CSVGenerator

using Gtk
using Logging

# Include parser and converter modules
include("../data/parser.jl")
include("../data/converter.jl")

using .Parser
using .Converter

export generate_csv

"""
    get_measurements(file_path::String)

Autodetect unit from a file.
"""
function get_measurements(file_path::String)
    # Conversion factors
    factors = Dict("cm" => 1.0, "inch" => 25.4)
    
    # Try to autodetect unit from file
    detected_unit = "cm"  # Default to cm
    autodetect_success = false
    
    try
        content = read(file_path, String)
        if occursin(r"inch"i, content)
            detected_unit = "inch"
            autodetect_success = true
            @info "Autodetected unit for file $file_path: $detected_unit"
        else
            @warn "Failed to autodetect unit for file $file_path, defaulting to 'cm'"
        end
    catch e
        @error "Error reading file for unit detection: $e"
    end
    
    return detected_unit, factors[detected_unit], autodetect_success
end

"""
    generate_csv(components::Dict{String, Any})

Generate CSV files from BOM and PINS data.
"""
function generate_csv(components::Dict{String, Any})
    @info "Starting CSV generation"
    
    # Get progress components
    progress = components["progress"]["progress"]
    progress_label = components["progress"]["label"]
    
    # Helper function to update progress
    function update_progress(fraction::Float64, message::String="Processing...")
        set_gtk_property!(progress, :fraction, fraction)
        set_gtk_property!(progress_label, :label, "$message ($(round(Int, fraction * 100))%)")
    end
    
    # Initialize progress
    update_progress(0.0)
    
    # Get input values
    bomsplit_path = get_gtk_property(components["bomsplit"]["input"], :text, String)
    pincad_path = get_gtk_property(components["pincad"]["input"], :text, String)
    program_name = get_gtk_property(components["program"]["input"], :text, String)
    client = get_gtk_property(components["client"]["combo"], :active_text, String)
    
    # Validate program name
    if isempty(program_name)
        program_name = "1234"
        set_gtk_property!(components["program"]["input"], :text, program_name)
        @info "Set default program name to '1234'"
    end
    
    # Parse BOM file using Parser module
    update_progress(0.1, "Parsing BOM file")
    bom_data = Parser.parse_file(bomsplit_path, "BOM")
    if isempty(bom_data)
        update_progress(0.0, "Error occurred")
        error("Process BOM data has failed")
    end
    
    # Get BOM unit and factor
    bom_unit, bom_factor, _ = get_measurements(bomsplit_path)
    
    # Parse PINS file if provided using Parser module
    pins_data = nothing
    pins_factor = 1.0
    if !isempty(pincad_path) && pincad_path != "Click to select PINS"
        update_progress(0.3, "Parsing PINS file")
        pins_data = Parser.parse_file(pincad_path, "PINS")
        _, pins_factor, _ = get_measurements(pincad_path)
    end
    
    # Use Converter module to generate CSV files
    result = Converter.generate_csv(
        bom_data,
        pins_data,
        client,
        program_name,
        bom_factor,
        update_progress,
        @__MODULE__
    )
    
    # Update UI based on result
    if result.success
        update_progress(1.0, "Processing completed")
        return Dict(
            "top" => result.top_success,
            "bot" => result.bot_success
        )
    else
        update_progress(0.0, "Error occurred")
        error(result.message)
    end
end

end # module 