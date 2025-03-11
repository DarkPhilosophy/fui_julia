module UILayout

export build_interface, UIComponents

using Gtk
using ..XDebug
using ..Config
import ..UIComponents as Components  # Import with rename to avoid conflicts
import ..UIAnimations as Animations  # Import animations with rename

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
    build_interface(config::Dict{String, Any}, language::Dict{String, Any})

Build the complete UI layout with components.

# Arguments
- `config`: Application configuration
- `language`: Language dictionary for UI text

# Returns
- `UIComponents`: Structure containing all UI components
"""
function build_interface(config::Dict{String, Any}, language::Dict{String, Any})
    # Create main window
    window = GtkWindow("MagicRay CAD/CSV Generator", ORIGINAL_WIDTH, ORIGINAL_HEIGHT)
    
    # Apply CSS styling - fixed for GTK3 in Julia
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
        cursor: pointer;
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
    
    # Apply CSS to window - fixed for GTK3 in Julia
    GAccessor.name(window, "main-window")
    # Retrieve the default screen once
    screen = Gtk.GdkScreen()

    # Load CSS data into the provider
    Gtk.GAccessor.load_data(css_provider, css_data)

    # Add the CSS provider to the screen with application priority
    Gtk.add_provider_for_screen(screen, css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    # Create the main vertical box container
    box_main = GtkBox(:v)

    # Add the box to the window
    push!(window, box_main)

    # Set margin for the box
    GAccessor.margin(box_main, 10)
    
    # Header area
    header_box = GtkBox(:h)
    about_label = GtkLabel("by adalbertalexandru.ungureanu@flex.com")
    GAccessor.name(about_label, "about-label")
    push!(header_box, about_label)
    
    # Add header to main box
    push!(box_main, header_box)
    GAccessor.margin_bottom(header_box, 20)
    
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
    clients = typeof(client_string) == String ? split(client_string, ",") : client_string
    
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
    GAccessor.margin_bottom(bomsplit["container"], 10)
    GAccessor.margin_bottom(pincad["container"], 10)
    GAccessor.margin_bottom(client["container"], 10)
    GAccessor.margin_bottom(program["container"], 20)
    
    # Generate button
    generate_button = GtkButton(get(get(language, "Buttons", Dict()), "Generate", "Generate .CAD/CSV"))
    GAccessor.name(generate_button, "generate-button")
    generate_box = GtkBox(:h)
    push!(generate_box, generate_button)
    GAccessor.halign(generate_button, Gtk.GConstants.GtkAlign.CENTER)  # Center align
    GAccessor.hexpand(generate_button, true)
    push!(box_main, generate_box)
    GAccessor.margin_bottom(generate_box, 20)
    
    # Progress bar area
    progress_bar = GtkProgressBar()
    progress_bar.fraction = 0.0
    progress_label = GtkLabel("0%")
    
    progress_box = GtkBox(:h)
    push!(progress_box, progress_bar)
    push!(progress_box, progress_label)
    GAccessor.hexpand(progress_bar, true)
    GAccessor.margin_start(progress_label, 10)
    
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
        language_combo.active = current_idx - 1
    else
        language_combo.active = 0  # Default to first
    end
    
    language_icon = GtkLabel("🌐")
    
    push!(language_box, language_label)
    push!(language_box, language_icon)
    push!(language_box, language_combo)
    GAccessor.margin_start(language_combo, 5)
    
    GAccessor.name(language_box, "language-box")
    GAccessor.halign(language_box, Gtk.GConstants.GtkAlign.END)  # Right align
    
    push!(box_main, language_box)
    
    # Debug console (initially hidden)
    console_button = GtkButton("▶")
    console_text = GtkTextView()
    GAccessor.name(console_text, "console-text")
    GAccessor.editable(console_text, false)
    GAccessor.cursor_visible(console_text, false)
    
    console_scroll = GtkScrolledWindow()
    push!(console_scroll, console_text)
    
    console_label = GtkLabel("DEBUG CONSOLE")
    GAccessor.name(console_label, "header-label")
    
    console_header = GtkBox(:h)
    push!(console_header, console_label)
    GAccessor.halign(console_label, Gtk.GConstants.GtkAlign.CENTER)
    GAccessor.hexpand(console_label, true)
    
    console_box = GtkBox(:v)
    push!(console_box, console_header)
    push!(console_box, console_scroll)
    GAccessor.vexpand(console_scroll, true)
    
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
        GAccessor.visible(console_button, false)
    end
    
    # Set window to be visible
    Gtk.showall(window)
    
    return components
end

"""
    set_drag_destination(widget::GtkWidget)

Make a widget a valid drag destination for files.
"""
function set_drag_destination(widget)
    # GTK3 drag and drop setup
    target_entries = [Gtk.GtkTargetEntry("text/uri-list", 0, 0)]
    targets = Gtk.GtkTargetList(target_entries)
    Gtk.drag_dest_set(
        widget, 
        Gtk.GConstants.GtkDestDefaults.ALL, 
        target_entries, 
        Gtk.GConstants.GdkDragAction.COPY
    )

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
                GAccessor.text(widget, path)
            end
        end
        return nothing
    end
    
    # Make the widget accept file drops
    GAccessor.allowdrop(widget, true)
end

end # module