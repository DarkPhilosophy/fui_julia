module UILayout

export build_interface, UIComponents

using Gtk, Gtk.ShortNames, Gtk.GLib
using ..XDebug
using ..Config
import ..UIComponents as Components
import ..UIAnimations as Animations

# Constants
const ORIGINAL_WIDTH = 557
const ORIGINAL_HEIGHT = 300
const CONSOLE_WIDTH = 520

"""
    UIComponents

Structure containing all UI components and their relationships.
"""
mutable struct UIComponents
    window::GtkWindowLeaf
    css_provider::GtkCssProviderLeaf
    box_main::GtkBoxLeaf
    
    # Header area
    header_box::GtkBoxLeaf
    about_label::GtkLabelLeaf
    
    # Main components
    bomsplit::Dict{String, Any}
    pincad::Dict{String, Any}
    client::Dict{String, Any}
    program::Dict{String, Any}
    
    # Bottom area
    generate_button::GtkButtonLeaf
    progress_bar::GtkProgressBarLeaf
    progress_label::GtkLabelLeaf
    
    # Language selector
    language::Dict{String, Any}
    
    # Debug console
    console::Dict{String, Any}
    
    # Configuration reference
    config::Dict{String, Any}
    
    # Animations container
    animations::Dict{String, Any}
end

"""
    style_context_add_provider(context, provider, priority)

Add provider to style context with direct ccall for maximum compatibility.
"""
function style_context_add_provider(context, provider, priority::Integer)
    ccall((:gtk_style_context_add_provider, Gtk.libgtk), Cvoid,
          (Ptr{Nothing}, Ptr{Gtk.GObject}, Cuint),
          context, provider, Cuint(priority))
end

"""
    build_interface(config::Dict{String, Any}, language::Dict{String, Any})

Build the complete UI layout with components.
"""
function build_interface(config::Dict{String, Any}, language::Dict{String, Any})
    # Check GTK version
    gtk_version = ccall((:gtk_get_major_version, Gtk.libgtk), Cint, ())
    println("[ Info] GTK Version: $gtk_version")

    # Create main window
    window = GtkWindow("MagicRay CAD/CSV Generator", ORIGINAL_WIDTH, ORIGINAL_HEIGHT)
    
    # Apply CSS styling - corrected for GTK3 in Julia
    css_provider = GtkCssProvider()
    css_data = """
    .main-window {
        background-color: #f5f5f5;
        padding: 10px;
    }
    
    label {
        font-size: 14px;
    }
    
    entry {
        font-size: 14px;
        padding: 4px;
        border-radius: 4px;
    }
    
    entry:focus {
        border-color: #3D85C6;
    }
    
    button {
        font-size: 14px;
        background-color: #3D85C6;
        color: white;
        border-radius: 4px;
        padding: 4px 8px;
    }
    
    button:hover {
        background-color: #2C6DA3;
    }
    
    .generate-button {
        font-size: 16px;
        font-weight: bold;
        padding: 8px;
    }
    
    progressbar {
        min-height: 20px;
    }
    
    progressbar trough {
        background-color: #000000;
        border-radius: 4px;
    }
    
    progressbar progress {
        background-color: #3D85C6;
        border-radius: 4px;
    }
    
    .success-progress progress {
        background-color: #097969;
    }
    
    .error-progress progress {
        background-color: #FF5733;
    }
    
    .console-text {
        font-family: monospace;
        font-size: 12px;
    }
    
    .header-label {
        font-size: 16px;
        font-weight: bold;
    }
    
    .clickable-label:hover {
        text-decoration: underline;
    }
    
    .about-label {
        font-size: 10px;
        color: #666;
    }
    
    .client-box entry {
        min-width: 80px;
    }
    
    .language-box {
        margin-top: 20px;
    }
    """
    
    # Load CSS data into the provider - direct ccall for maximum compatibility
    try
        ccall((:gtk_css_provider_load_from_data, Gtk.libgtk), Bool, 
              (Ptr{Gtk.GObject}, Ptr{UInt8}, Csize_t, Ptr{Nothing}), 
              css_provider, css_data, length(css_data), C_NULL)
        
        # Apply CSS to window's style context
        style_context = ccall((:gtk_widget_get_style_context, Gtk.libgtk), Ptr{Nothing},
                            (Ptr{Gtk.GObject},), window)
        style_context_add_provider(style_context, css_provider, 600)  # GTK_STYLE_PROVIDER_PRIORITY_APPLICATION
    catch e
        @warn "Could not apply CSS: $e"
    end

    # Create the main vertical box container
    box_main = GtkBox(:v)

    # Add the box to the window
    push!(window, box_main)

    # Set margin for the box
    Gtk.set_gtk_property!(box_main, :border_width, 10)
    
    # Header area
    header_box = GtkBox(:h)
    about_label = GtkLabel("by adalbertalexandru.ungureanu@flex.com")
    Gtk.set_gtk_property!(about_label, :name, "about-label")
    push!(header_box, about_label)
    
    # Add header to main box
    push!(box_main, header_box)
    Gtk.set_gtk_property!(header_box, :margin_bottom, 20)
    
    # Create component groups - using Components module functions
    bomsplit = Components.create_labeled_component(
        get(get(language, "Labels", Dict()), "BOMSplit", "Select BOM File"),
        get(get(config, "Last", Dict()), "BOMSplitPath", "Click to select BOM"),
        true
    )
    
    pincad = Components.create_labeled_component(
        get(get(language, "Labels", Dict()), "PINSCad", "Select PINS File"),
        get(get(config, "Last", Dict()), "PINSCadPath", "Click to select PINS"),
        true
    )
    
    # Get clients as array of strings
    client_string = get(config, "Clients", "GEC,PBEH,AGI,NER,SEA4,SEAH,ADVA,NOK")
    clients = typeof(client_string) <: AbstractString ? split(client_string, ",") : client_string
    
    client = Components.create_client_component(
        get(get(language, "Labels", Dict()), "Client", "Client"),
        clients,
        get(get(config, "Last", Dict()), "OptionClient", "")
    )
    
    program = Components.create_labeled_component(
        get(get(language, "Labels", Dict()), "ProgramName", "Program Name"),
        get(get(config, "Last", Dict()), "ProgramEntry", ""),
        false
    )
    
    # Add components to main box
    push!(box_main, bomsplit["container"])
    push!(box_main, pincad["container"])
    push!(box_main, client["container"])
    push!(box_main, program["container"])
    
    # Add spacing between components
    Gtk.set_gtk_property!(bomsplit["container"], :margin_bottom, 10)
    Gtk.set_gtk_property!(pincad["container"], :margin_bottom, 10)
    Gtk.set_gtk_property!(client["container"], :margin_bottom, 10)
    Gtk.set_gtk_property!(program["container"], :margin_bottom, 20)
    
    # Generate button
    generate_button = GtkButton(get(get(language, "Buttons", Dict()), "Generate", "Generate .CAD/CSV"))
    Gtk.set_gtk_property!(generate_button, :name, "generate-button")
    generate_box = GtkBox(:h)
    push!(generate_box, generate_button)
    Gtk.set_gtk_property!(generate_button, :halign, Gtk.GConstants.GtkAlign.CENTER)  # Center align
    Gtk.set_gtk_property!(generate_button, :hexpand, true)
    push!(box_main, generate_box)
    Gtk.set_gtk_property!(generate_box, :margin_bottom, 20)
    
    # Progress bar area
    progress_bar = GtkProgressBar()
    # FIXED: Using property setting instead of direct field access
    Gtk.set_gtk_property!(progress_bar, :fraction, 0.0)
    progress_label = GtkLabel("0%")
    
    progress_box = GtkBox(:h)
    push!(progress_box, progress_bar)
    push!(progress_box, progress_label)
    Gtk.set_gtk_property!(progress_bar, :hexpand, true)
    Gtk.set_gtk_property!(progress_label, :margin_start, 10)
    
    push!(box_main, progress_box)
    
    # Language selector
    language_box = GtkBox(:h)
    language_label = GtkLabel("Language:")
    language_combo = GtkComboBoxText(false)  # Not editable
    
    # Find available language files
    lang_files = String[]
    lang_dir = joinpath(Config.get_assets_dir(), "lang")
    if isdir(lang_dir)
        for file in readdir(lang_dir)
            if endswith(file, ".json")
                push!(lang_files, replace(file, ".json" => ""))
            end
        end
    end
    
    # If no language files found, add default en
    if isempty(lang_files)
        push!(lang_files, "en")
    end
    
    # Populate language options
    for lang_code in lang_files
        push!(language_combo, lang_code)
    end
    
    # Set current language
    current_lang = Config.get_language_code(config)
    current_idx = findfirst(==(current_lang), lang_files)
    if current_idx !== nothing
        Gtk.set_gtk_property!(language_combo, :active, current_idx - 1)
    else
        Gtk.set_gtk_property!(language_combo, :active, 0)  # Default to first
    end
    
    language_icon = GtkLabel("🌐")
    
    push!(language_box, language_label)
    push!(language_box, language_icon)
    push!(language_box, language_combo)
    Gtk.set_gtk_property!(language_combo, :margin_start, 5)
    
    Gtk.set_gtk_property!(language_box, :name, "language-box")
    Gtk.set_gtk_property!(language_box, :halign, Gtk.GConstants.GtkAlign.END)  # Right align
    
    push!(box_main, language_box)
    
    # Debug console (initially hidden)
    console_button = GtkButton("▶")
    console_text = GtkTextView()
    Gtk.set_gtk_property!(console_text, :name, "console-text")
    Gtk.set_gtk_property!(console_text, :editable, false)
    Gtk.set_gtk_property!(console_text, :cursor_visible, false)
    
    console_scroll = GtkScrolledWindow()
    push!(console_scroll, console_text)
    
    console_label = GtkLabel("DEBUG CONSOLE")
    Gtk.set_gtk_property!(console_label, :name, "header-label")
    
    console_header = GtkBox(:h)
    push!(console_header, console_label)
    Gtk.set_gtk_property!(console_label, :halign, Gtk.GConstants.GtkAlign.CENTER)
    Gtk.set_gtk_property!(console_label, :hexpand, true)
    
    console_box = GtkBox(:v)
    push!(console_box, console_header)
    push!(console_box, console_scroll)
    Gtk.set_gtk_property!(console_scroll, :vexpand, true)
    
    # Hidden dev area for easter egg
    console_dev = GtkBox(:h)
    
    # Create UI components structure
    components = UIComponents(
        window,
        css_provider,
        box_main,
        header_box,
        about_label,
        bomsplit,
        pincad,
        client,
        program,
        generate_button,
        progress_bar,
        progress_label,
        Dict{String, Any}("label" => language_label, "combo" => language_combo, "icon" => language_icon, "container" => language_box),
        Dict{String, Any}("button" => console_button, "text" => console_text, "scroll" => console_scroll, 
             "label" => console_label, "container" => console_box, "header" => console_header,
             "visible" => false, "dev" => console_dev),
        config,
        Dict{String, Any}()
    )
    
    # Make components draggable
    set_drag_destination(bomsplit["input"])
    set_drag_destination(pincad["input"])
    
    # Hide console button unless debug mode is enabled
    debug_enabled = get(config, "Debug", false)
    if !debug_enabled
        Gtk.set_gtk_property!(console_button, :visible, false)
    end
    
    # Set window to be visible
    Gtk.showall(window)
    
    return components
end

"""
    set_drag_destination(widget::GtkWidget)

Make a widget a valid drag destination for files using direct ccall approach.
"""
function set_drag_destination(widget)
    try
        # Direct approach without GtkTargetEntry
        # Set widget as a drag destination for all kinds of data
        ccall((:gtk_drag_dest_set, Gtk.libgtk), Cvoid,
              (Ptr{Gtk.GObject}, Cint, Ptr{Nothing}, Cint, Cint),
              widget, 3, # GTK_DEST_DEFAULT_ALL = 3
              C_NULL, 0, # No targets specified, accept any
              1) # GDK_ACTION_COPY = 1
        
        # Connect to the drag-data-received signal
        signal_connect(widget, "drag-data-received") do widget, context, x, y, data, info, time
            # Converting drag data to file path
            uris = split(unsafe_string(convert(Ptr{UInt8}, data.data)), "\r\n")
            if !isempty(uris)
                uri = uris[1]
                # Convert URI to file path
                if startswith(uri, "file://")
                    path = uri[8:end]
                    # On Windows, convert /C:/path to C:/path
                    if Sys.iswindows() && startswith(path, "/")
                        path = path[2:end]
                    end
                    Gtk.set_gtk_property!(widget, :text, path)
                end
            end
            return nothing
        end
    catch e
        @warn "Could not set up drag and drop for widget: $e"
    end
end

end # module