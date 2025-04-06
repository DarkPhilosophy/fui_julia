"""
    Config

Module for handling configuration and language settings.
"""
module Config

using JSON3
using ..XDebug
using ..FileOps

export load_config, save_config, load_language, get_language_code, get_assets_dir

# Create a logger instance
const logger = XDebug.create_logger()

"""
    get_assets_dir()

Get the assets directory path.
"""
function get_assets_dir()
    return joinpath(dirname(@__DIR__), "data")
end

"""
    merge_defaults(target::Dict, default::Dict, parent_key::String="")

Merge default values into a target dictionary.
"""
function merge_defaults(target::Dict, default::Dict, parent_key::String="")
    result = copy(target)
    
    for (k, v) in default
        current_key = isempty(parent_key) ? string(k) : parent_key * "." * string(k)
        
        if v isa Dict
            if haskey(result, k) && result[k] isa Dict
                result[k] = merge_defaults(result[k], v, current_key)
            else
                XDebug.log_info(XDebug.get_logger(), "Type mismatch for key: $current_key (expected Dict, got $(typeof(result[k]))), using default", XDebug.CONFIG)
                result[k] = deepcopy(v)
            end
        elseif !haskey(result, k)
            XDebug.log_info(XDebug.get_logger(), "Adding missing key: $current_key = $v", XDebug.CONFIG)
            result[k] = deepcopy(v)
        elseif typeof(result[k]) != typeof(v)
            XDebug.log_info(XDebug.get_logger(), "Type mismatch for key: $current_key (expected $(typeof(v)), got $(typeof(result[k]))), using default", XDebug.CONFIG)
            result[k] = deepcopy(v)
        end
    end
    
    return result
end

"""
    load_config(default_config::Dict, ini_file::String)

Load and merge configuration with defaults.
"""
function load_config(default_config::Dict, ini_file::String)
    XDebug.log_info(XDebug.get_logger(), "Starting config load for: $ini_file", XDebug.CONFIG)
    
    if !isfile(ini_file)
        XDebug.log_info(XDebug.get_logger(), "Config file not found, creating: $ini_file", XDebug.CONFIG)
        save_config = deepcopy(default_config)
        XDebug.log_info(XDebug.get_logger(), "Saving default config", XDebug.CONFIG)
        
        try
            open(ini_file, "w") do io
                JSON3.write(io, save_config)
            end
        catch e
            XDebug.log_error(XDebug.get_logger(), "Failed to save default config: $e", XDebug.ERRORS)
        end
        
        return save_config
    end
    
    try
        config = open(ini_file, "r") do io
            JSON3.read(io, Dict)
        end
        XDebug.log_info(XDebug.get_logger(), "Loaded config", XDebug.CONFIG)
        
        merged_config = merge_defaults(config, default_config)
        
        if merged_config != config
            XDebug.log_info(XDebug.get_logger(), "Saving updated config: $ini_file", XDebug.CONFIG)
            open(ini_file, "w") do io
                JSON3.write(io, merged_config)
            end
        else
            XDebug.log_info(XDebug.get_logger(), "No updates needed for: $ini_file", XDebug.CONFIG)
        end
        
        return merged_config
    catch e
        XDebug.log_error(XDebug.get_logger(), "Failed to load config file: $ini_file, error: $e", XDebug.ERRORS)
        return deepcopy(default_config)
    end
end

"""
    save_config(config::Dict{String, Any})

Save configuration to file.
"""
function save_config(config::Dict{String, Any})
    config_path = "config.ini"
    
    open(config_path, "w") do f
        # Write non-section values first
                for (key, value) in config
            if !isa(value, Dict)
                if isa(value, AbstractString)
                    println(f, "$key=\"$value\"")
                else
                    println(f, "$key=$value")
                        end
                    end
                end
                
                # Write sections
                for (section, values) in config
            if isa(values, Dict)
                println(f, "\n[$section]")
                        for (key, value) in values
                    if isa(value, AbstractString)
                        println(f, "$key=\"$value\"")
                    else
                        println(f, "$key=$value")
                    end
                            end
                        end
                    end
                end
            end
            
"""
    get_language_code(config::Dict)

Extract language code from configuration.
"""
function get_language_code(config::Dict)
    lang_path = get(config, "Language", "data/lang/en.json")
    return replace(basename(lang_path), ".json" => "")
end

"""
    load_language(lang_code::String, default_translations::Dict=Dict())

Load language file with defaults.
"""
function load_language(lang_code::String, default_translations::Dict=Dict())
    XDebug.log_info(XDebug.get_logger(), "Starting language load for code: $lang_code", XDebug.CONFIG)
    
    if isempty(lang_code)
        XDebug.log_error(XDebug.get_logger(), "Invalid language code", XDebug.ERRORS)
        return default_translations
    end
    
    # Extract language code from path if necessary
    lang_code = if occursin(".json", lang_code)
        basename(lang_code)
        replace(basename(lang_code), ".json" => "")
    else
        lang_code
    end
    
    # Validate language code
    if !occursin(r"^[a-zA-Z]{2}$", lang_code)
        XDebug.log_error(XDebug.get_logger(), "Invalid language code after extraction: $lang_code", XDebug.ERRORS)
        return default_translations
    end
    
    lang_file = joinpath(get_assets_dir(), "lang", "$lang_code.json")
    lang_dir = dirname(lang_file)
    
    if !isdir(lang_dir)
        XDebug.log_info(XDebug.get_logger(), "Creating directory: $lang_dir", XDebug.CONFIG)
        mkpath(lang_dir)
    end
    
    if !isfile(lang_file)
        XDebug.log_info(XDebug.get_logger(), "Language file not found: $lang_file", XDebug.CONFIG)
        
        try
            open(lang_file, "w") do io
                JSON3.write(io, default_translations)
            end
        catch e
            XDebug.log_error(XDebug.get_logger(), "Failed to save language file: $lang_file, error: $e", XDebug.ERRORS)
        end
        
        return default_translations
    end
    
    try
        lang_data = open(lang_file, "r") do io
            JSON3.read(io, Dict)
        end
        XDebug.log_info(XDebug.get_logger(), "Loaded language data", XDebug.CONFIG)
        
        merged_data = merge_defaults(lang_data, default_translations)
        
        if merged_data != lang_data
            XDebug.log_info(XDebug.get_logger(), "Saving updated language file: $lang_file", XDebug.CONFIG)
            open(lang_file, "w") do io
                JSON3.write(io, merged_data)
            end
        else
            XDebug.log_info(XDebug.get_logger(), "No updates needed for: $lang_file", XDebug.CONFIG)
        end
        
        return merged_data
    catch e
        XDebug.log_error(XDebug.get_logger(), "Failed to load language file: $lang_file, error: $e", XDebug.ERRORS)
        return default_translations
    end
end

end # module