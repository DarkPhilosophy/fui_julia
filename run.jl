#!/usr/bin/env julia

println("Starting application from run.jl...")

using Gtk
using Logging

# Set up logging
ENV["JULIA_DEBUG"] = "all"
global_logger(ConsoleLogger(stderr, Logging.Debug))

# Define modules
module Data
    include("src/data/parser.jl")
    include("src/data/converter.jl")
    export Parser, Converter
end

module UI
    using ..Data
    include("src/ui/components.jl")
    include("src/ui/handlers.jl")
    export UIComponents, UIHandlers
    include("src/ui/layout.jl")
    include("src/ui/csv_generator.jl")
    export UILayout, CSVGenerator
end

using .Data
using .UI

# Create and show the main window
window = UILayout.create_main_layout()
showall(window)

# Start the GTK main loop
if !isinteractive()
    Gtk.main()
end