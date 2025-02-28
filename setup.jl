#!/usr/bin/env julia

"""
setup.jl - Project setup script for MagicRay CAD/CSV Generator
This script initializes the project environment, installs dependencies,
and creates necessary directories and configuration files.
"""

# Enable multithreading if not already set
if !haskey(ENV, "JULIA_NUM_THREADS")
    ENV["JULIA_NUM_THREADS"] = "4"
    println("Set JULIA_NUM_THREADS=4 for this session")
end

using Pkg

function setup_project()
    println("Setting up MagicRay CAD/CSV Generator...")
    
    # Make sure we're in the right directory
    script_dir = dirname(abspath(@__FILE__))
    cd(script_dir)
    
    # Initialize project if needed
    if !isfile("Project.toml")
        println("Initializing new Julia project...")
        Pkg.activate(".")
        
        # Add dependencies
        println("Installing dependencies...")
        dependencies = [
            "Gtk",            # UI Framework (GTK3)
            "JSON3",          # Fast JSON handling
            "StructTypes",    # Struct to JSON mapping
            "HTTP",           # HTTP client for updates
            "Dates",          # Date handling
            "Mmap",           # Memory-mapped files
            "ThreadPools",    # Thread pooling
            "CodecZlib",      # Compression
            "Base64",         # Base64 encoding/decoding
            "Logging",        # Enhanced logging
            "Test",           # Testing framework
            "CSV",            # CSV processing
            "DataFrames",     # Tabular data
            #"GtkSourceWidget" # For code/config editor
        ]
        ##Pkg.add("GtkSourceView_jll")
        for dep in dependencies
            println("Adding $dep...")
            try
                Pkg.add(dep)
            catch e
                println("Warning: Could not add $dep: $e")
            end
        end
    else
        println("Project already initialized, updating dependencies...")
        Pkg.activate(".")
        Pkg.update()
    end
    
    # Create necessary directories
    for dir in ["assets/audio", "assets/lang", "assets/styles", "data/debug"]
        if !isdir(dir)
            println("Creating directory: $dir")
            mkpath(dir)
        end
    end
    
    # Create default language files if they don't exist
    create_default_lang_files()
    
    # Create default configuration if it doesn't exist
    create_default_config()
    
    # Precompile packages
    println("Precompiling packages...")
    Pkg.precompile()
    
    println("Setup complete! Run the application with: julia --project=. src/Fui.jl")
end

function create_default_lang_files()
    en_json = """
    {
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
    }
    """
    
    ro_json = """
    {
        "Buttons": {
            "Generate": "Generează .CAD/CSV",
            "Cancel": "Anulare",
            "Yes": "Da",
            "No": "Nu",
            "Load": "Încarcă",
            "Save": "Salvează",
            "Add": "Adaugă",
            "Del": "Șterge",
            "BOMSplitPath": "Clic pentru a selecta BOMSPLIT",
            "PINSCadPath": "Clic pentru a selecta PINCAD"
        },
        "Labels": {
            "BOMSplit": "Clic pentru a selecta BOM",
            "PINSCad": "Clic pentru a selecta PINS",
            "Client": "Client",
            "ProgramName": "Nume Program"
        },
        "Errors": {
            "FileMissing": "Fișier lipsă: %s",
            "InvalidEntry": "Intrare invalidă detectată"
        }
    }
    """
    
    write_file_if_not_exists("assets/lang/en.json", en_json)
    write_file_if_not_exists("assets/lang/ro.json", ro_json)
end

function create_default_config()
    config = """
    [Last]
    BOMSplitPath = "Click to select BOM"
    PINSCadPath = "Click to select PINS"
    OptionClient = ""
    ProgramEntry = ""

    [General]
    Clients = "GEC,PBEH,AGI,NER,SEA4,SEAH,ADVA,NOK"
    Language = "assets/lang/en.json"
    """
    
    write_file_if_not_exists("config.ini", config)
end

function write_file_if_not_exists(filename, content)
    if !isfile(filename)
        println("Creating default file: $filename")
        try
            mkpath(dirname(filename))
            open(filename, "w") do f
                write(f, content)
            end
        catch e
            println("Warning: Could not create $filename: $e")
        end
    end
end

# Run setup
setup_project()