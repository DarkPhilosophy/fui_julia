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

# First include the base utility modules others depend on
include("utils/safety.jl")
include("debug/xdbg.jl")
include("utils/file_ops.jl") 
include("utils/compression.jl")

# Then include modules that depend on the utility modules
include("config.jl")
include("net/autoupdate.jl")
include("data/parser.jl")
include("data/converter.jl")
include("ui/components.jl")
include("ui/animations.jl")
include("ui/handlers.jl")
include("ui/layout.jl")

# Import sub-modules
using .Safety
using .XDebug
using .FileOps
using .Compression
using .Config
using .Parser
using .Converter
using .AutoUpdate
using .UIComponents
using .UIAnimations
using .UIHandlers
using .UILayout

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
        
        # Load language
        lang_code = Config.get_language_code(config)
        language = Config.load_language(lang_code)
        
        # Build UI
        ui_components = UILayout.build_interface(config, language)
        
        # Setup event handlers
        UIHandlers.setup_event_handlers(ui_components, config, language, logger)
        
        # Play startup sound
        UIAnimations.play_sound("startup")
        
        # Check for updates in background
        @spawn AutoUpdate.check_for_updates(config, ui_components)
        
        # Show main window with fade-in animation
        main_window = ui_components.window
        UIAnimations.fade_in(main_window)
        
        # Start GTK main loop
        if main_window.handle !== C_NULL
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

# Provide command-line execution functionality
if abspath(PROGRAM_FILE) == @__FILE__
    exit(run_application())
end

end # module