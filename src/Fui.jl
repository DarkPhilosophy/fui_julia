module Fui

export run_application

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

# Print Gtk version information for debugging
println("Using Gtk package version: ", pkgversion(Gtk))

# First include the base utility modules others depend on
include("utils/safety.jl")
include("debug/xdbg.jl")
include("utils/file_ops.jl") 
include("utils/compression.jl")

# Then include modules that depend on the utility modules
include("config.jl")
include("data/parser.jl")
include("data/converter.jl")

# Include UI component module
include("ui/components.jl")

# Include network modules
include("net/autoupdate.jl")

# Include remaining UI modules
include("ui/animations.jl")
include("ui/layout.jl")
include("ui/handlers.jl")

# Import sub-modules in proper order to avoid circular dependencies
using .Safety
using .XDebug
using .FileOps
using .Compression
using .Config
using .Parser
using .Converter

# Import UIComponents directly to avoid naming conflicts
import .UIComponents: create_labeled_component, create_client_component, create_progress_component

# Import remaining modules
using .AutoUpdate
using .UIAnimations
using .UILayout
using .UIHandlers

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
        # Load configuration with error handling
        config = Dict{String, Any}()
        try
            config = Config.load_config()
            XDebug.log_info(logger, "Configuration loaded successfully")
        catch config_error
            XDebug.log_error(logger, "Error loading configuration: $config_error")
            # Use default configuration
            config = Dict{String, Any}(
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
        
        # Load language with error handling
        language = Dict{String, Any}()
        try
            lang_code = Config.get_language_code(config)
            XDebug.log_info(logger, "Using language code: $lang_code")
            language = Config.load_language(lang_code)
            
            if language === nothing || isempty(language)
                throw(ErrorException("Language loading returned invalid data"))
            end
            
            XDebug.log_info(logger, "Language loaded successfully")
        catch lang_error
            XDebug.log_error(logger, "Error loading language: $lang_error")
            # Use default language
            language = Dict{String, Any}(
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
        
        # Build UI with error handling
        ui_components = nothing
        try
            ui_components = UILayout.build_interface(config, language)
            XDebug.log_info(logger, "UI built successfully")
        catch ui_error
            XDebug.log_critical(logger, "Failed to build UI: $ui_error")
            XDebug.log_backtrace(logger)
            return 1
        end
        
        # Setup event handlers with error handling
        try
            UIHandlers.setup_event_handlers(ui_components, config, language, logger)
            XDebug.log_info(logger, "Event handlers set up successfully")
        catch handler_error
            XDebug.log_error(logger, "Error setting up event handlers: $handler_error")
            XDebug.log_backtrace(logger)
            # Continue anyway - some functionality might still work
        end
        
        # Play startup sound - with error handling
        try
            UIAnimations.play_sound("startup")
        catch sound_error
            XDebug.log_warning(logger, "Could not play startup sound: $sound_error")
        end
        
        # Check for updates in background
        @spawn begin
            try
                sleep(2) # Give the UI time to initialize
                AutoUpdate.check_for_updates(config, ui_components, logger)
            catch e
                XDebug.log_error(logger, "Error in update check: $e")
                XDebug.log_backtrace(logger)
            end
        end
        
        # Show main window with fade-in animation
        main_window = ui_components.window
        try
            UIAnimations.fade_in(main_window)
        catch anim_error
            XDebug.log_warning(logger, "Could not animate window: $anim_error")
        end
        
        # Start GTK main loop
        if main_window.handle !== C_NULL
            XDebug.log_info(logger, "Starting GTK main loop")
            Gtk.gtk_main()
        else
            XDebug.log_critical(logger, "Window handle is null, cannot start main loop")
            return 1
        end
        
        XDebug.log_info(logger, "Application closed normally")
        return 0
    catch e
        XDebug.log_critical(logger, "Fatal error in application: $e")
        XDebug.log_backtrace(logger)
        return 1
    end
end

# Provide command-line execution functionality
if abspath(PROGRAM_FILE) == @__FILE__
    exit(run_application())
end

end # module