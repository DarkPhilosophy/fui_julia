module Fui

# Core imports
using Gtk
using Gtk.GLib
using JSON3
using Dates
using Base.Threads
using Logging
import Base: get

println("Starting Fui application...")

# Set environment variables
ENV["GTK_DEBUG"] = "all"

# Enable multi-threading if not already set
if !haskey(ENV, "JULIA_NUM_THREADS")
    ENV["JULIA_NUM_THREADS"] = "4"
end

# Set up logging
ENV["JULIA_DEBUG"] = "all"
global_logger(ConsoleLogger(stderr, Logging.Debug))

println("Loading UI module...")

# Define UI module
module UI
    using Gtk
    using Logging
    
    println("Loading UI components...")
    # First load components as they are used by other modules
    include("ui/components.jl")
    
    println("Loading CSV generator...")
    # Then load csv_generator which includes parser and converter
    include("ui/csv_generator.jl")
    
    println("Loading UI handlers...")
    # Then load handlers which uses components and csv_generator
    include("ui/handlers.jl")
    
    println("Loading UI layout...")
    # Finally load layout which depends on components and handlers
    include("ui/layout.jl")
    
    export UIComponents, UILayout, UIHandlers, CSVGenerator
end

# Import UI module
using .UI

export run_app

println("Fui module loading completed.")

"""
    run_app()

Initialize and run the main application.
"""
function run_app()
    println("Starting application initialization...")
    @info "Application starting..."
    
    # Load default configuration if not exists
    default_config = Dict{String, Any}(
        "Last" => Dict{String, Any}(
            "BOMSplitPath" => "Click to select BOM",
            "PINSCadPath" => "Click to select PINS",
            "OptionClient" => "",
            "ProgramEntry" => ""
        ),
        "Clients" => ["GEC", "PBEH", "AGI", "NER", "SEA4", "SEAH", "ADVA", "NOK"],
        "Language" => "data/lang/en.json"
    )
    
    println("Loading configuration...")
    # Load or create config
    config_path = joinpath("data", "config.json")
    config = if !isfile(config_path)
        println("Creating new config file at: $config_path")
        mkpath(dirname(config_path))
        open(config_path, "w") do io
            JSON3.write(io, default_config)
        end
        default_config
    else
        println("Loading existing config from: $config_path")
        JSON3.read(read(config_path, String), Dict)
    end
    
    @info "Configuration loaded"
    
    # Initialize GTK
    println("Initializing GTK...")
    @info "Initializing GTK..."
    
    try
        # Create main window
        println("Creating main window...")
        window = GtkWindow("Generate .CAD/CSV for MagicRa...", 500, 300)
        GAccessor.resizable(window, false)
        
        # Create main layout
        println("Creating main layout...")
        components = UILayout.create_main_layout()
        
        # Add window to components
        components["window"] = window
        # Add config to components dictionary
        components["config"] = config
        
        println("Adding components to window...")
        push!(window, components["container"])
        
        # Set up event handlers
        println("Setting up event handlers...")
        UIHandlers.setup_event_handlers(components)
        
        # Set up window close handler
        println("Setting up window close handler...")
        signal_connect(window, :destroy) do widget
            println("Window close requested...")
            Gtk.gtk_quit()
        end
        
        # Show window and all its children
        println("Showing window...")
        showall(window)
        
        println("Starting GTK main loop...")
        @info "Starting GTK main loop..."
        
        # Start GTK main loop
        println("Running GTK main loop...")
        Gtk.gtk_main()
        
        println("Application initialization completed.")
        return window
    catch e
        @error "Error during application initialization" exception=(e, catch_backtrace())
        rethrow(e)
    end
end

# Run the application when the module loads
println("Calling run_app()...")
window = run_app()

end # module