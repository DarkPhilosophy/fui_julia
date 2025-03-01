module Config

export load_config, save_config, load_language, get_language_code, get_assets_dir

# Default language data structure
const DEFAULT_LANGUAGE = Dict{String, Any}(
    "Buttons" => Dict{String, Any}(
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
    "Labels" => Dict{String, Any}(
        "BOMSplit" => "Click to select BOM",
        "PINSCad" => "Click to select PINS",
        "Client" => "Client",
        "ProgramName" => "Program Name"
    ),
    "Errors" => Dict{String, Any}(
        "FileMissing" => "File missing: %s",
        "InvalidEntry" => "Invalid entry detected"
    )
)

# Load language function - minimal working version
# The parameter MUST match exactly what's being passed
function load_language(lang_code::String)
    println("Loading language: $lang_code")
    return DEFAULT_LANGUAGE
end

function get_language_code(config::Dict{String, Any})
    return "en"
end

function get_assets_dir()
    dir_path = joinpath(dirname(dirname(@__FILE__)), "assets")
    if !isdir(dir_path)
        mkpath(dir_path)
    end
    return dir_path
end

function load_config(config_path::String="config.ini")
    return Dict{String, Any}(
        "Last" => Dict{String, Any}(
            "BOMSplitPath" => "Click to select BOM",
            "PINSCadPath" => "Click to select PINS",
            "OptionClient" => "",
            "ProgramEntry" => ""
        ),
        "Clients" => "GEC,PBEH,AGI,NER,SEA4,SEAH,ADVA,NOK",
        "Language" => "assets/lang/en.json"
    )
end

function save_config(config::Dict{String, Any}, config_path::String="config.ini")
    println("Saving config")
    return true
end

end # module