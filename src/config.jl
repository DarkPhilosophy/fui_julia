module Config

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
    load_config(config_path::String="fui.ini")

Load the application configuration from a file.
If the file doesn't exist, it creates a default configuration.

# Arguments
- `config_path::String`: Path to the configuration file (default: "fui.ini")

# Returns
- `Dict{String, Any}`: Configuration dictionary
"""
function load_config(config_path::String="fui.ini")
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
                if key_value_match !== nothing
                    key = strip(key_value_match.captures[1])
                    value = strip(key_value_match.captures[2])
                    
                    # Remove quotes if present
                    if startswith(value, "\"") && endswith(value, "\"")
                        value = value[2:end-1]
                    end
                    
                    # Parse value as array if it contains commas
                    if occursin(',', value) && !occursin('=', value) && !occursin('[', value)
                        if current_section == ""
                            config[key] = split(value, ',')
                        else
                            config[current_section][key] = split(value, ',')
                        end
                    else
                        # Try to parse as boolean
                        if lowercase(value) == "true"
                            val = true
                        elseif lowercase(value) == "false"
                            val = false
                        else
                            # Try to parse as number
                            try
                                if occursin('.', value)
                                    val = parse(Float64, value)
                                else
                                    val = parse(Int, value)
                                end
                            catch
                                # Store as string
                                val = value
                            end
                        end
                        
                        if current_section == ""
                            config[key] = val
                        else
                            config[current_section][key] = val
                        end
                    end
                end
            end
            
            return config
        end,
        (err) -> begin
            @warn "Error loading config: $err, using defaults"
            return deepcopy(DEFAULT_CONFIG)
        end
    )
    
    # Merge with defaults to ensure all keys exist
    merge_defaults!(config, DEFAULT_CONFIG)
    
    return config
end

"""
    merge_defaults!(config, defaults)

Merge default values into a configuration dictionary.

# Arguments
- `config`: Configuration to update (can be any dictionary type)
- `defaults`: Default values (can be any dictionary type)

# Returns
- Updated configuration
"""
function merge_defaults!(config, defaults)
    # Only proceed if both are dictionary-like
    if !(config isa AbstractDict) || !(defaults isa AbstractDict)
        return config
    end
    
    # Continue with the merge logic
    for (key, value) in defaults
        if !haskey(config, key)
            config[key] = deepcopy(value)
        elseif value isa AbstractDict && config[key] isa AbstractDict
            merge_defaults!(config[key], value)
        end
    end
    
    return config
end

"""
    save_config(config::Dict{String, Any}, config_path::String="fui.ini")

Save the configuration to a file.

# Arguments
- `config::Dict{String, Any}`: Configuration to save
- `config_path::String`: Path to the configuration file (default: "fui.ini")

# Returns
- `Bool`: Success status
"""
function save_config(config::Dict{String, Any}, config_path::String="fui.ini")
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
- `Dict{String, Any}`: Language dictionary or empty dict if failed
"""
function load_language(lang_code::String)
    # Try to find language file in various locations
    lang_file = nothing
    locations = [
        joinpath(get_assets_dir(), "lang", "$(lang_code).json"),  # First check in assets
        joinpath("assets", "lang", "$(lang_code).json"),          # Then check relative paths
        joinpath("data", "lang", "$(lang_code).json"),
        "$(lang_code).json"                                       # Finally check current dir
    ]
    
    # Try each location
    for path in locations
        if isfile(path)
            lang_file = path
            break
        end
    end
    
    # If no file found, try to create default
    if lang_file === nothing
        if lang_code == "en"
            default_path = joinpath(get_assets_dir(), "lang", "$(lang_code).json")
            # Ensure the directory exists
            dir_path = dirname(default_path)
            if !isdir(dir_path)
                mkpath(dir_path)
            end
            
            # Create default English language file
            if create_default_english(default_path)
                lang_file = default_path
            end
        end
    end
    
    # If we still don't have a file, return empty dict
    if lang_file === nothing
        @warn "Language file not found for code: $lang_code"
        return Dict{String, Any}()
    end
    
    # Load the language file content
    return Safety.safe_operation(
        () -> begin
            content = read(lang_file, String)
            return JSON3.read(content, Dict{String, Any})
        end,
        (err) -> begin
            @warn "Failed to load language file: $err"
            return Dict{String, Any}()
        end
    )
end

"""
    create_default_english(file_path::String)

Create default English language file.

# Arguments
- `file_path::String`: Path to create file at

# Returns
- `Bool`: Success status
"""
function create_default_english(file_path::String)
    default_content = """{
    "Buttons": {
        "Generate": "Generate .CAD/CSV",
        "Cancel": "Cancel",
        "Yes": "Yes",
        "No": "No",
        "Load": "Load",
        "Save": "Save",
        "Add": "Add",
        "Del": "Del",
        "BOMSplitPath": "Click to select BOMSPLIT",
        "PINSCadPath": "Click to select PINCAD"
    },
    "Labels": {
        "BOMSplit": "Click to select BOM",
        "PINSCad": "Click to select PINS",
        "Client": "Client",
        "ProgramName": "Program Name"
    },
    "Errors": {
        "FileMissing": "File missing: %s",
        "InvalidEntry": "Invalid entry detected"
    }
}"""

    return Safety.safe_operation(
        () -> begin
            # Create directory if it doesn't exist
            dir_path = dirname(file_path)
            if !isdir(dir_path)
                mkpath(dir_path)
            end
            
            # Write the content
            write(file_path, default_content)
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
    # Look for the assets directory in various places
    candidates = [
        joinpath(dirname(dirname(@__FILE__)), "assets"),  # Standard location
        "assets",                                         # Current directory
        joinpath("..", "assets")                          # One level up
    ]
    
    for path in candidates
        if isdir(path)
            return abspath(path)
        end
    end
    
    # If not found, try to create it
    try
        path = joinpath(dirname(dirname(@__FILE__)), "assets")
        if !isdir(path)
            mkpath(path)
        end
        return abspath(path)
    catch
        # Fallback to current directory
        return "assets"
    end
end

end # module