module UILayout

using Gtk
using ..XDebug
using ..Config

export build_interface, UIComponents

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
    
    # Apply CSS styling
    css_provider = GtkCssProvider()
    css_data = """
    #main-window {
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
    
    # Load CSS provider
    sc = Gtk.GdkScreen()
    push!(sc, css_provider, 600) # 600 is the priority
    style_provider_add_provider_for_screen(sc, css_provider, 600)
    
    # Set window ID for styling
    Gtk.name!(window, "main-window")
    
    # Main container - vertical box
    box_main = GtkBox(:v)
    push!(window, box_main)
    set_gtk_property!(box_main, :margin, 10)
    
    # Header area
    header_box = GtkBox(:h)
    about_label = GtkLabel("by adalbertalexadru.ungureanu@flex.com")
    GAccessor.name(about_label, "about-label")
    push!(header_box, about_label)
    
    # Add header to main box
    push!(box_main, header_box)
    set_gtk_property!(header_box, :margin_bottom, 20)
    
    # Create component groups
    bomsplit = create_labeled_component(
        get(language, "Labels", Dict())["BOMSplit"],
        get(config, "Last", Dict())["BOMSplitPath"],
        true
    )
    
    pincad = create_labeled_component(
        get(language, "Labels", Dict())["PINSCad"],
        get(config, "Last", Dict())["PINSCadPath"],
        true
    )
    
    client = create_client_component(
        get(language, "Labels", Dict())["Client"],
        config
    )
    
    program = create_labeled_component(
        get(language, "Labels", Dict())["ProgramName"],
        get(config, "Last", Dict())["ProgramEntry"],
        false
    )
    
    # Add components to main box
    push!(box_main, bomsplit["container"])
    push!(box_main, pincad["container"])
    push!(box_main, client["container"])
    push!(box_main, program["container"])
    
    # Add spacing between components
    set_gtk_property!(bomsplit["container"], :margin_bottom, 10)
    set_gtk_property!(pincad["container"], :margin_bottom, 10)
    set_gtk_property!(client["container"], :margin_bottom, 10)
    set_gtk_property!(program["container"], :margin_bottom, 20)
    
    # Generate button
    generate_button = GtkButton(get(language, "Buttons", Dict())["Generate"])
    GAccessor.name(generate_button, "generate-button")
    generate_box = GtkBox(:h)
    push!(generate_box, generate_button)
    set_gtk_property!(generate_button, :halign, 1) # GTK_ALIGN_CENTER = 1
    set_gtk_property!(generate_button, :hexpand, true)
    push!(box_main, generate_box)
    set_gtk_property!(generate_box, :margin_bottom, 20)
    
    # Progress bar area
    progress_bar = GtkProgressBar()
    progress_bar.fraction = 0.0
    progress_label = GtkLabel("0%")
    
    progress_box = GtkBox(:h)
    push!(progress_box, progress_bar)
    push!(progress_box, progress_label)
    set_gtk_property!(progress_bar, :hexpand, true)
    set_gtk_property!(progress_label, :margin_start, 10)
    
    push!(box_main, progress_box)
    
    # Language selector
    language_box = GtkBox(:h)
    language_label = GtkLabel("Language:")
    language_combo = GtkComboBoxText()
    
    # Populate language options
    for lang_file in readdir(joinpath(Config.get_assets_dir(), "lang"))
        if endswith(lang_file, ".json")
            lang_code = replace(lang_file, ".json" => "")
            push!(language_combo, lang_code)
        end
    end
    
    # Set current language
    current_lang = Config.get_language_code(config)
    language_combo.active_text = current_lang
    
    language_icon = GtkLabel("🌐")
    
    push!(language_box, language_label)
    push!(language_box, language_icon)
    push!(language_box, language_combo)
    set_gtk_property!(language_combo, :margin_start, 5)
    
    GAccessor.name(language_box, "language-box")
    set_gtk_property!(language_box, :halign, 4) # GTK_ALIGN_END = 4
    
    push!(box_main, language_box)
    
    # Debug console (initially hidden)
    console_button = GtkButton("▶")
    console_text = GtkTextView()
    GAccessor.name(console_text, "console-text")
    set_gtk_property!(console_text, :editable, false)
    set_gtk_property!(console_text, :cursor_visible, false)
    
    console_scroll = GtkScrolledWindow()
    push!(console_scroll, console_text)
    
    console_label = GtkLabel("DEBUG CONSOLE")
    GAccessor.name(console_label, "header-label")
    
    console_header = GtkBox(:h)
    push!(console_header, console_label)
    set_gtk_property!(console_label, :halign, 1) # GTK_ALIGN_CENTER = 1
    set_gtk_property!(console_label, :hexpand, true)
    
    console_box = GtkBox(:v)
    push!(console_box, console_header)
    push!(console_box, console_scroll)
    set_gtk_property!(console_scroll, :vexpand, true)
    
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
        Dict("label" => language_label, "combo" => language_combo, "icon" => language_icon, "container" => language_box),
        Dict("button" => console_button, "text" => console_text, "scroll" => console_scroll, 
             "label" => console_label, "container" => console_box, "header" => console_header,
             "visible" => false, "dev" => console_dev),
        config,
        Dict()
    )
    
    # Make components draggable
    set_drag_destination(bomsplit["input"])
    set_drag_destination(pincad["input"])
    
    return components
end

"""
    create_labeled_component(label_text::String, input_text::String, is_button::Bool)

Create a labeled UI component (entry field or button-like entry).

# Arguments
- `label_text`: Text for the label
- `input_text`: Initial text for the input field
- `is_button`: Whether the input should look/behave like a button

# Returns
- Dictionary with component parts
"""
function create_labeled_component(label_text::String, input_text::String, is_button::Bool)
    container = GtkBox(:h)
    label = GtkLabel(label_text)
    input = GtkEntry()
    
    input.text = input_text
    if !is_button
        set_gtk_property!(input, :has_frame, true)
    else
        set_gtk_property!(input, :has_frame, false)
    end
    
    push!(container, label)
    push!(container, input)
    
    set_gtk_property!(input, :hexpand, true)
    set_gtk_property!(input, :margin_start, 10)
    
    if is_button
        # Make it look more like a button
        set_gtk_property!(input, :editable, false)
        GAccessor.name(input, "file-button")
    end
    
    return Dict(
        "container" => container,
        "label" => label,
        "input" => input
    )
end

"""
    create_client_component(label_text::String, config::Dict{String, Any})

Create the client selection component with combobox and add/remove buttons.

# Arguments
- `label_text`: Text for the label
- `config`: Configuration with client options

# Returns
- Dictionary with component parts
"""
function create_client_component(label_text::String, config::Dict{String, Any})
    container = GtkBox(:h)
    GAccessor.name(container, "client-box")
    
    label = GtkLabel(label_text)
    combo = GtkComboBoxText()
    
    # Populate client options
    if haskey(config, "Clients")
        clients = split(config["Clients"], ",")
        for client in clients
            push!(combo, client)
        end
    end
    
    # Set active client
    if haskey(config, "Last") && haskey(config["Last"], "OptionClient")
        combo.active_text = config["Last"]["OptionClient"]
    end
    
    remove_button = GtkButton("✖ Del")
    add_entry = GtkEntry()
    add_button = GtkButton("➕ Add")
    
    # Layout components
    push!(container, label)
    push!(container, combo)
    push!(container, remove_button)
    push!(container, add_entry)
    push!(container, add_button)
    
    # Set margins and expansion
    set_gtk_property!(combo, :margin_start, 10)
    set_gtk_property!(remove_button, :margin_start, 5)
    set_gtk_property!(add_entry, :margin_start, 5)
    set_gtk_property!(add_button, :margin_start, 5)
    
    set_gtk_property!(add_entry, :hexpand, true)
    
    return Dict(
        "container" => container,
        "label" => label,
        "selectBox" => combo,
        "removeButton" => remove_button,
        "addEntry" => add_entry,
        "addButton" => add_button
    )
end

"""
    set_drag_destination(widget::GtkWidget)

Make a widget a valid drag destination for files.
"""
function set_drag_destination(widget)
    # GTK3 drag and drop setup
    target_entries = [Gtk.GtkTargetEntry("text/uri-list", 0, 0)]
    targets = Gtk.GtkTargetList(target_entries)
    Gtk.drag_dest_set(widget, Gtk.GConstants.GtkDestDefaults.ALL, target_entries, 
                     Gtk.GConstants.GdkDragAction.COPY)

    # Connect to the drag-data-received signal
    signal_connect(widget, "drag-data-received") do widget, context, x, y, data, info, time
        uris = split(unsafe_string(convert(Ptr{UInt8}, data.data)), "\r\n")
        if length(uris) > 0
            uri = uris[1]
            # Convert URI to file path
            if startswith(uri, "file://")
                path = uri[8:end]
                # On Windows, convert /C:/path to C:/path
                if Sys.iswindows() && startswith(path, "/")
                    path = path[2:end]
                end
                set_gtk_property!(widget, :text, path)
            end
        end
        return nothing
    end
end

end # module