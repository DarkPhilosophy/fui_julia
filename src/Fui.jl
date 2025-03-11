module Fui

export run_application
# At the beginning of your application's run_application function
ENV["GTK_DEBUG"] = "interactive"

# Enable multi-threading
if !haskey(ENV, "JULIA_NUM_THREADS")
    ENV["JULIA_NUM_THREADS"] = "4"
end

# Core imports
using Gtk
using JSON3
using Dates
using Mmap
using ThreadPools
using Base.Threads: @spawn, @threads
using Base: @kwdef

# First include the base utility modules others depend on
include("utils/safety.jl")
include("debug/xdbg.jl")
include("utils/file_ops.jl") 
include("utils/compression.jl")

# Then include modules that depend on the utility modules
include("config.jl")
include("data/parser.jl")
include("data/converter.jl")
include("ui/components.jl")
include("ui/animations.jl") # Include animations before layout and handlers
include("net/autoupdate.jl")
include("ui/layout.jl")
include("ui/handlers.jl")

# Import sub-modules with explicit naming to avoid conflicts
using .Safety
using .XDebug
using .FileOps
using .Compression
using .Config
using .Parser
using .Converter
import .UIComponents as Components  # Renamed to avoid conflicts
import .UILayout as Layout
import .UIHandlers as Handlers
import .UIAnimations as Animations  # Renamed for consistency
import .AutoUpdate as Update  # Renamed for consistency

gtk_version = ccall((:gtk_get_major_version, Gtk.libgtk), Cint, ())
@info "GTK Version: $gtk_version"

"""
    run_application()

Main entry point for the MagicRay CAD/CSV Generator application.
Initializes the UI, sets up event handlers, and starts the application.
"""
function run_application()
    # Initialize logger
    logger = XDebug.Logger("MagicRay", true)
    XDebug.log_info(logger, "Application starting...")
    
    try
        # Load configuration
        config = Config.load_config()
        XDebug.log_info(logger, "Configuration loaded successfully")
        
        # Get language code directly
        lang_code = get(config, "Language", "assets/lang/en.json")
        lang_match = match(r"([^/\\]+)\.json$", lang_code)
        if lang_match !== nothing
            lang_code = lang_match.captures[1]
        else
            lang_code = "en"
        end
        langt = typeof(lang_code)
        XDebug.log_info(logger, "Using language code: $(lang_code) type : $(langt)")
        
        # Load language directly without using Config.load_language
        language = load_language_directly(lang_code)
        
        @info "Language loaded successfully"
        @info "Building UI interface"
        XDebug.log_info(logger, "Language loaded successfully")
        
        # Build UI
        XDebug.log_info(logger, "Building UI interface")
        ui_components = Layout.build_interface(config, language)
        XDebug.log_info(logger, "UI built successfully")
        
        # Setup event handlers
        Handlers.setup_event_handlers(ui_components, config, language, logger)
        XDebug.log_info(logger, "Event handlers configured")
        
        # Play startup sound
        Animations.play_sound("startup")
        
        # Check for updates in background
        @spawn Update.check_for_updates(config, ui_components)
        
        # Show main window with fade-in animation
        main_window = ui_components.window
        Animations.fade_in(main_window)
        XDebug.log_info(logger, "Application window displayed")
        
        # Start GTK main loop
        if main_window.handle !== C_NULL
            XDebug.log_info(logger, "Starting GTK main loop")
            Gtk.gtk_main()
        end
        
        XDebug.log_info(logger, "Application closed normally")
        return 0
    catch e
        XDebug.log_critical(logger, "Fatal error in application: $e")
        XDebug.log_backtrace(logger)
        return 1
    end
end

"""
    load_language_directly(lang_code::String)

Direct implementation of language loading without using Config module.

# Arguments
- `lang_code::String`: Language code (e.g., "en")

# Returns
- Language dictionary
"""
function load_language_directly(lang_code::AbstractString)
    locations = [
        joinpath("assets", "lang", "$(lang_code).json"),
        joinpath("data", "lang", "$(lang_code).json"),
        "$(lang_code).json"
    ]
    for path in locations
        if isfile(path)
            try
                content = read(path, String)
                if startswith(content, "\ufeff")
                    content = content[4:end]  # Strip BOM
                end
                return JSON3.read(content, Dict{String, Any})
            catch e
                @warn "Failed to load language file $path: $e"
            end
        end
    end
    # Fallback to default dictionary
    @warn "Could not load language file for '$lang_code', using defaults"
    return get_default_language_dict()
end

"""
    get_default_language_dict()

Returns a default language dictionary as fallback when language loading fails.
"""
function get_default_language_dict()
    return Dict{String, Any}(
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
end

# Provide command-line execution functionality
if abspath(PROGRAM_FILE) == @__FILE__
    exit(run_application())
end

end # module