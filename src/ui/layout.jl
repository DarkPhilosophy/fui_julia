module UILayout

using Gtk
using ..XDebug
using ..Config

export build_interface, UIComponents

# Constants
const ORIGINAL_WIDTH = 557
const ORIGINAL_HEIGHT = 300
const CONSOLE_WIDTH = 520

# GTK constants - defined at module level
const GTK_DEST_DEFAULT_ALL = 0x0007
const GDK_ACTION_COPY = 1

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
    println("Building UI interface")
    
    # Create main window
    window = GtkWindow("MagicRay CAD/CSV Generator", ORIGINAL_WIDTH, ORIGINAL_HEIGHT)
    main_container = GtkBox(:v)  # Vertical box
    set_gtk_property!(main_container, :spacing, 10)
    set_gtk_property!(main_container, :margin, 10)
    # Add the main container to the window
    push!(window, main_container)  # This is the only widget directly added to window

    # Now all other widgets should be added to main_container or its children
    # For example:
    header_box = GtkBox(:h)
    push!(main_container, header_box)  # Add to main_container, not window
    
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
    
    # Fix for CSS styling - directly load CSS without using additional function
    try
        ccall((:gtk_css_provider_load_from_data, Gtk.libgtk), Bool,
              (Ptr{Gtk.GObject}, Ptr{UInt8}, Cint, Ptr{Nothing}),
              css_provider, css_data, length(css_data), C_NULL)
        
        # Get screen and apply provider
        screen = ccall((:gdk_screen_get_default, Gtk.libgdk), Ptr{Nothing}, ())
        if screen != C_NULL
            ccall((:gtk_style_context_add_provider_for_screen, Gtk.libgtk), Nothing,
                  (Ptr{Nothing}, Ptr{Gtk.GObject}, Cuint),
                  screen, css_provider, 600)
        end
    catch css_error
        println("Warning: Could not apply CSS: $css_error")
    end
    # Load CSS data
    try
        Gtk.GAccessor.style_context(window)
        sc = Gtk.GdkScreen()
        Gtk.G_.load_from_data(css_provider, css_data, length(css_data))
        Gtk.StyleProvider(css_provider)
        Gtk.AddProviderForScreen(sc, css_provider, 600)  # 600 is priority
    catch e
        @warn "Error loading CSS: $e"
    end
    
    # Set window ID for styling
    GAccessor.name(window, "main-window")
    
    # Main container - vertical box
    box_main = GtkBox(:v)
    push!(window, box_main)
    set_gtk_property!(box_main, :margin, 10)
    
    # Header area
    header_box = GtkBox(:h)
    about_label = GtkLabel("by adalbertalexandru.ungureanu@flex.com")
    GAccessor.name(about_label, "about-label")
    push!(header_box, about_label)
    
    # Add header to main box
    push!(box_main, header_box)
    set_gtk_property!(header_box, :margin_bottom, 20)
    
    # Get labels from language data safely
    labels = get(language, "Labels", Dict{String, Any}())
    buttons = get(language, "Buttons", Dict{String, Any}())
    
    # Create component groups
    bomsplit = create_labeled_component(
        get(labels, "BOMSplit", "Select BOM File"),
        get(get(config, "Last", Dict()), "BOMSplitPath", "Click to select BOM"),
        true
    )
    
    pincad = create_labeled_component(
        get(labels, "PINSCad", "Select PINS File"),
        get(get(config, "Last", Dict()), "PINSCadPath", "Click to select PINS"),
        true
    )
    
    client = create_client_component(
        get(labels, "Client", "Client"),
        config
    )
    
    program = create_labeled_component(
        get(labels, "ProgramName", "Program name"),
        get(get(config, "Last", Dict()), "ProgramEntry", ""),
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
    generate_button = GtkButton(get(buttons, "Generate", "Generate .CAD/CSV"))
    GAccessor.name(generate_button, "generate-button")
    generate_box = GtkBox(:h)
    push!(generate_box, generate_button)
    set_gtk_property!(generate_button, :halign, 1) # GTK_ALIGN_CENTER = 1
    set_gtk_property!(generate_button, :hexpand, true)
    push!(box_main, generate_box)
    set_gtk_property!(generate_box, :margin_bottom, 20)
    
    # Progress bar area
    progress_bar = GtkProgressBar()
    set_gtk_property!(progress_bar, :fraction, 0.0)
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
    lang_dir = joinpath(Config.get_assets_dir(), "lang")
    if isdir(lang_dir)
        for lang_file in readdir(lang_dir)
            if endswith(lang_file, ".json")
                lang_code = replace(lang_file, ".json" => "")
                push!(language_combo, lang_code)
            end
        end
    else
        # Add default English if directory doesn't exist
        push!(language_combo, "en")
    end
    
    # Set current language
    current_lang = Config.get_language_code(config)
    
    # Try to find and set current language
    if length(language_combo) > 0
        # Default to first language
        set_gtk_property!(language_combo, :active, 0)
        
        # Try to set to specified language
        try
            items = language_combo.items
            for (i, item) in enumerate(items)
                if hasmethod(Gtk.bytestring, Tuple{typeof(GAccessor.text(item))}) && 
                   Gtk.bytestring(GAccessor.text(item)) == current_lang
                    set_gtk_property!(language_combo, :active, i-1)
                    break
                end
            end
        catch lang_err
            println("Warning: Could not set active language: $lang_err")
        end
    end
    
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
    
    # Try to set up drag and drop but handle missing functions
    try
        setup_file_drop(bomsplit["input"])
        setup_file_drop(pincad["input"])
    catch drag_err
        println("Warning: Could not set up drag and drop: $drag_err")
    end
    
    println("UI interface built successfully")
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
    
    set_gtk_property!(input, :text, input_text)
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
    clients_list = String[]
    
    if haskey(config, "Clients")
        clients_str = get(config, "Clients", "")
        if clients_str isa String && !isempty(clients_str)
            clients_list = split(clients_str, ",")
        elseif clients_str isa Vector
            for client in clients_str
                push!(clients_list, string(client))
            end
        end
    end
    
    # Ensure at least one default client if list is empty
    if isempty(clients_list)
        push!(clients_list, "DEFAULT")
    end
    
    # Add all clients to the combobox
    for client in clients_list
        push!(combo, client)
    end
    
    # Set active client if available
    if length(combo) > 0
        # Default to first client
        set_gtk_property!(combo, :active, 0)
        
        # Try to set to specified client from config
        if haskey(config, "Last") && haskey(config["Last"], "OptionClient")
            option_client = config["Last"]["OptionClient"]
            if !isempty(option_client)
                # Try to find and set this client
                try
                    items = combo.items
                    for (i, item) in enumerate(items)
                        if hasmethod(Gtk.bytestring, Tuple{typeof(GAccessor.text(item))}) && 
                           Gtk.bytestring(GAccessor.text(item)) == option_client
                            set_gtk_property!(combo, :active, i-1)
                            break
                        end
                    end
                catch client_err
                    println("Warning: Could not set active client: $client_err")
                end
            end
        end
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
    setup_file_drop(widget)

Set up basic drag and drop functionality for files that's compatible with Gtk 1.3.0
"""
function setup_file_drop(widget)
    # Check if gtk_drag_dest_set is available before using it
    if Gtk.libgtk === C_NULL
        error("GTK library not loaded")
    end
    
    # Set up widget as drag destination with fallback approach
    # First try to use basic drag_dest_set
    ccall((:gtk_drag_dest_set, Gtk.libgtk), Nothing,
         (Ptr{Gtk.GObject}, Cuint, Ptr{Nothing}, Cint, Cuint),
         widget, GTK_DEST_DEFAULT_ALL, C_NULL, 0, GDK_ACTION_COPY)
    
    # Connect to the drag-data-received signal
    signal_connect(widget, "drag-data-received") do widget, context, x, y, data, info, time
        try
            # Try to get the data from the selection data
            data_type = ccall((:gtk_selection_data_get_data_type, Gtk.libgtk),
                             Cuint, (Ptr{Gtk.GObject},), data)
                             
            data_ptr = ccall((:gtk_selection_data_get_data, Gtk.libgtk),
                            Ptr{UInt8}, (Ptr{Gtk.GObject},), data)
                            
            data_length = ccall((:gtk_selection_data_get_length, Gtk.libgtk),
                               Cint, (Ptr{Gtk.GObject},), data)
                               
            if data_ptr != C_NULL && data_length > 0
                # Try to convert to string
                raw_data = unsafe_string(data_ptr, data_length)
                
                # Try to find a file URI
                for line in split(raw_data, r"\r?\n")
                    if startswith(line, "file://")
                        # Convert URI to file path
                        path = line[8:end]
                        
                        # On Windows, convert /C:/path to C:/path
                        if Sys.iswindows() && startswith(path, "/")
                            path = path[2:end]
                        end
                        
                        # Update the widget text
                        set_gtk_property!(widget, :text, path)
                        break
                    end
                end
            end
        catch e
            println("Error processing drag data: $e")
        end
        
        # Complete the drag operation
        ccall((:gtk_drag_finish, Gtk.libgtk), Nothing,
             (Ptr{Gtk.GObject}, Cint, Cint, Culong),
             context, true, false, time)
             
        return nothing
    end
end

end # module