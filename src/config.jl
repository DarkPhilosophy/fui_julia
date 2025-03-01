﻿module Config

export load_config, save_config, load_language, get_language_code, get_assets_dir

using JSON3
using ..Safety
using ..FileOps

# Default configuration
const DEFAULT_CONFIG = Dict(
    "Last" => Dict(
        "BOMSplitPath" => "Click to select BOM",
        "PINSCadPath" => "Click to select PINS",
        "OptionClient" => "",
        "ProgramEntry" => ""
    ),
    "Clients" => "GEC,PBEH,AGI,NER,SEA4,SEAH,ADVA,NOK",
    "Language" => "assets/lang/en.json",
    "Version" => "22",
    "UpdateSources" => [
        "//timnt779/MagicRay/Backup/Software programare/SW_FUI/fui/update.txt",
        "//timnt757/Tools/scripts/M2/fui/update.txt"
    ],
    "Debug" => false
)

"""
    load_config(config_path::String="config.ini")

Load the application configuration from a file.
If the file doesn't exist, it creates a default configuration.

# Arguments
- `config_path::String`: Path to the configuration file (default: "config.ini")

# Returns
- `Dict{String, Any}`: Configuration dictionary
"""
function load_config(config_path::String="config.ini")
    # Check if config file exists
    if !isfile(config_path)
        # Create default config
        save_config(DEFAULT_CONFIG, config_path)
        return deepcopy(DEFAULT_CONFIG)
    end
    
    # Load existing config
    config = Safety.safe_operation(
        () -> begin
            # Parse INI file
            config = Dict{String, Any}()
            current_section = ""
            
            for line in eachline(config_path)
                # Remove comments and trim whitespace
                line = strip(split(line, '#')[1])
                if isempty(line)
                    continue
                end
                
                # Check for section header
                section_match = match(r"^\[(.*)\]$", line)
                if section_match !== nothing
                    current_section = section_match.captures[1]
                    config[current_section] = Dict{String, Any}()
                    continue
                end
                
                # Parse key-value pair
                key_value_match = match(r"^([^=]+)=(.*)$", line)
                if key_value_match !== nothing && !isempty(current_section)
                    key = strip(key_value_match.captures[1])
                    value = strip(key_value_match.captures[2])
                    
                    # Remove quotes if present
                    if startswith(value, "\"") && endswith(value, "\"")
                        value = value[2:end-1]
                    end
                    
                    # Parse value as array if it contains commas
                    if occursin(',', value) && !occursin('=', value) && !occursin('[', value)
                        config[current_section][key] = split(value, ',')
                    else
                        # Try to parse as boolean
                        if lowercase(value) == "true"
                            config[current_section][key] = true
                        elseif lowercase(value) == "false"
                            config[current_section][key] = false
                        else
                            # Try to parse as number
                            try
                                if occursin('.', value)
                                    config[current_section][key] = parse(Float64, value)
                                else
                                    config[current_section][key] = parse(Int, value)
                                end
                            catch
                                # Store as string
                                config[current_section][key] = value
                            end
                        end
                    end
                elseif !isempty(line)
                    # Key without section
                    key_value_match = match(r"^([^=]+)=(.*)$", line)
                    if key_value_match !== nothing
                        key = strip(key_value_match.captures[1])
                        value = strip(key_value_match.captures[2])
                        
                        # Remove quotes if present
                        if startswith(value, "\"") && endswith(value, "\"")
                            value = value[2:end-1]
                        end
                        
                        # Parse value
                        if lowercase(value) == "true"
                            config[key] = true
                        elseif lowercase(value) == "false"
                            config[key] = false
                        else
                            # Try to parse as number
                            try
                                if occursin('.', value)
                                    config[key] = parse(Float64, value)
                                else
                                    config[key] = parse(Int, value)
                                end
                            catch
                                # Store as string
                                config[key] = value
                            end
                        end
                    end
                end
            end
            
            return config
        end,
        (err) -> deepcopy(DEFAULT_CONFIG)
    )
    
    # Merge with defaults to ensure all keys exist
    merge_defaults!(config, DEFAULT_CONFIG)
    
    return config
end

"""
    merge_defaults!(config::Dict{String, Any}, defaults::Dict{String, Any})

Merge default values into a configuration dictionary.

# Arguments
- `config::Dict{String, Any}`: Configuration to update
- `defaults::Dict{String, Any}`: Default values

# Returns
- `Dict{String, Any}`: Updated configuration
"""
function merge_defaults!(config::Dict{String, Any}, defaults::Dict{String, Any})
    for (key, value) in defaults
        if !haskey(config, key)
            config[key] = deepcopy(value)
        elseif value isa Dict && config[key] isa Dict
            merge_defaults!(config[key], value)
        end
    end
    
    return config
end

"""
    save_config(config::Dict{String, Any}, config_path::String="config.ini")

Save the configuration to a file.

# Arguments
- `config::Dict{String, Any}`: Configuration to save
- `config_path::String`: Path to the configuration file (default: "config.ini")

# Returns
- `Bool`: Success status
"""
function save_config(config::Dict{String, Any}, config_path::String="config.ini")
    return Safety.safe_operation(
        () -> begin
            # Ensure directory exists
            config_dir = dirname(config_path)
            if !isempty(config_dir) && !isdir(config_dir)
                mkpath(config_dir)
            end
            
            # Write config to file
            open(config_path, "w") do file
                # Write non-dict values first
                for (key, value) in config
                    if !(value isa Dict)
                        if value isa Vector
                            write(file, "$key=$(join(value, ','))\n")
                        elseif value isa String
                            write(file, "$key=\"$value\"\n")
                        else
                            write(file, "$key=$value\n")
                        end
                    end
                end
                
                # Write sections
                for (section, values) in config
                    if values isa Dict
                        write(file, "\n[$section]\n")
                        for (key, value) in values
                            if value isa Vector
                                write(file, "$key=$(join(value, ','))\n")
                            elseif value isa String
                                write(file, "$key=\"$value\"\n")
                            else
                                write(file, "$key=$value\n")
                            end
                        end
                    end
                end
            end
            
            return true
        end,
        (err) -> begin
            @warn "Failed to save configuration: $err"
            return false
        end
    )
end

"""
    load_language(lang_code::String)

Load a language file.

# Arguments
- `lang_code::String`: Language code (e.g., "en")

# Returns
- `Dict{String, Any}`: Language dictionary or nothing if failed
"""
function load_language(lang_code::String)
    lang_path = joinpath(get_assets_dir(), "lang", "$(lang_code).json")
    
    if !isfile(lang_path)
        # Try to create default language file
        if lang_code == "en"
            create_default_language(lang_path)
        else
            @warn "Language file not found: $lang_path"
            return nothing
        end
    end
    
    return Safety.safe_operation(
        () -> begin
            content = read(lang_path, String)
            return JSON3.read(content, Dict{String, Any})
        end,
        (err) -> begin
            @warn "Failed to load language file: $err"
            return nothing
        end
    )
end

"""
    create_default_language(lang_path::String)

Create a default English language file.

# Arguments
- `lang_path::String`: Path to the language file

# Returns
- `Bool`: Success status
"""
function create_default_language(lang_path::String)
    default_lang = Dict(
        "Buttons" => Dict(
            "Generate" => "Generate .CAD/CSV",
            "Cancel" => "Cancel",
            "Yes" => "Yes",
            "No" => "No",
            "Load" => "Load",
            "Save" => "Save",
            "Add" => "Add",
            "Del" => "Del",
            "BOMSplitPath" => "Click to select BOMSPLIT",
            "PINSCadPath" => "Click to select PINCAD"
        ),
        "Labels" => Dict(
            "BOMSplit" => "Click to select BOM",
            "PINSCad" => "Click to select PINS",
            "Client" => "Client",
            "ProgramName" => "Program Name"
        ),
        "Errors" => Dict(
            "FileMissing" => "File missing: %s",
            "InvalidEntry" => "Invalid entry detected"
        )
    )
    
    return Safety.safe_operation(
        () -> begin
            # Ensure directory exists
            lang_dir = dirname(lang_path)
            if !isempty(lang_dir) && !isdir(lang_dir)
                mkpath(lang_dir)
            end
            
            # Write language file
            open(lang_path, "w") do file
                write(file, JSON3.write(default_lang, indent=4))
            end
            
            return true
        end,
        (err) -> begin
            @warn "Failed to create default language file: $err"
            return false
        end
    )
end

"""
    get_language_code(config::Dict{String, Any})

Extract the language code from configuration.

# Arguments
- `config::Dict{String, Any}`: Configuration dictionary

# Returns
- `String`: Language code
"""
function get_language_code(config::Dict{String, Any})
    lang_path = get(config, "Language", "assets/lang/en.json")
    
    # Extract code from path
    lang_match = match(r"([^/\\]+)\.json$", lang_path)
    if lang_match !== nothing
        return lang_match.captures[1]
    end
    
    return "en"  # Default to English
end

"""
    get_assets_dir()

Get the path to the assets directory.

# Returns
- `String`: Assets directory path
"""
function get_assets_dir()
    # Calculate paths relative to script location
    script_dir = dirname(dirname(@__FILE__))
    return joinpath(script_dir, "assets")
end

end # module