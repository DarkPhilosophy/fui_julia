module UIComponents

export create_labeled_component, create_client_component, create_progress_component,
       create_language_selector, create_debug_console, create_button

using Gtk
using ..XDebug

"""
    create_labeled_component(label_text::String, input_text::String, is_button::Bool=false)

Create a labeled UI component with a label and text entry.

# Arguments
- `label_text::String`: Text for the label
- `input_text::String`: Initial text for the input field
- `is_button::Bool`: Whether the input should look like a button (default: false)

# Returns
- Dictionary with component parts
"""
function create_labeled_component(label_text::String, input_text::String, is_button::Bool=false)
    container = GtkBox(:h)
    label = GtkLabel(label_text)
    input = GtkEntry()
    
    # Set properties
    if input_text !== nothing
        GAccessor.text(input, string(input_text))
    end
    
    if is_button
        GAccessor.has_frame(input, false)
        GAccessor.editable(input, false)
        GAccessor.name(input, "file-button")
    else
        GAccessor.has_frame(input, true)
    end
    
    # Layout
    push!(container, label)
    push!(container, input)
    
    # Set expansion and margins
    GAccessor.hexpand(label, false)
    GAccessor.hexpand(input, true)
    GAccessor.margin_start(input, 10)
    
    return Dict{String, Any}(
        "container" => container,
        "label" => label,
        "input" => input
    )
end

"""
    create_client_component(label_text::String, clients::Vector{String}=String[], selected::String="")

Create the client management component with combobox and add/remove buttons.

# Arguments
- `label_text::String`: Text for the label
- `clients::Vector{String}`: List of client options (default: [])
- `selected::String`: Initially selected client (default: "")

# Returns
- Dictionary with component parts
"""
function create_client_component(label_text::String, clients::Vector{String}=String[], selected::String="")
    # Container
    container = GtkBox(:h)
    GAccessor.name(container, "client-box")
    
    # Create components
    label = GtkLabel(label_text)
    combo = GtkComboBoxText(false)  # Not editable
    remove_button = GtkButton("✖ Del")
    add_entry = GtkEntry()
    add_button = GtkButton("➕ Add")
    
    # Set button classes
    GAccessor.name(remove_button, "small-button")
    GAccessor.name(add_button, "small-button")
    
    # Populate client options - convert clients to array of strings if needed
    client_array = isa(clients, String) ? split(clients, ",") : clients
    for client in client_array
        push!(combo, client)
    end
    
    # Set active client if provided
    if !isempty(selected) && (selected in client_array)
        for (i, client) in enumerate(client_array)
            if client == selected
                combo.active = i - 1
                break
            end
        end
    elseif !isempty(client_array)
        combo.active = 0  # Select first by default
    end
    
    # Layout components
    push!(container, label)
    push!(container, combo)
    push!(container, remove_button)
    push!(container, add_entry)
    push!(container, add_button)
    
    # Set margins and expansion
    GAccessor.margin_start(combo, 10)
    GAccessor.margin_start(remove_button, 5)
    GAccessor.margin_start(add_entry, 5)
    GAccessor.margin_start(add_button, 5)
    GAccessor.hexpand(add_entry, true)
    
    return Dict{String, Any}(
        "container" => container,
        "label" => label,
        "selectBox" => combo,
        "removeButton" => remove_button,
        "addEntry" => add_entry,
        "addButton" => add_button
    )
end

"""
    create_progress_component()

Create a progress bar with label.

# Returns
- Dictionary with progress bar, label, and container
"""
function create_progress_component()
    # Create container
    container = GtkBox(:h)
    
    # Create progress bar
    progress_bar = GtkProgressBar()
    GAccessor.fraction(progress_bar, 0.0)
    
    # Create label
    progress_label = GtkLabel("0%")
    GAccessor.name(progress_label, "progress-label")
    
    # Layout
    push!(container, progress_bar)
    push!(container, progress_label)
    
    # Set expansion and margins
    GAccessor.hexpand(progress_bar, true)
    GAccessor.margin_start(progress_label, 10)
    
    return Dict{String, Any}(
        "container" => container,
        "progress_bar" => progress_bar,
        "label" => progress_label
    )
end

"""
    create_language_selector(available_languages::Vector{String}, current_language::String)

Create a language selection component.

# Arguments
- `available_languages::Vector{String}`: List of available language codes
- `current_language::String`: Currently selected language code

# Returns
- Dictionary with component parts
"""
function create_language_selector(available_languages::Vector{String}, current_language::String)
    # Create container
    container = GtkBox(:h)
    GAccessor.name(container, "language-box")
    
    # Create components
    label = GtkLabel("Language:")
    icon = GtkLabel("🌐")
    combo = GtkComboBoxText(false)  # Not editable
    
    # Populate language options
    for lang in available_languages
        push!(combo, lang)
    end
    
    # Set current language
    current_idx = findfirst(==(current_language), available_languages)
    if current_idx !== nothing
        combo.active = current_idx - 1
    elseif !isempty(available_languages)
        combo.active = 0  # Select first by default
    end
    
    # Layout
    push!(container, label)
    push!(container, icon)
    push!(container, combo)
    
    # Set margins
    GAccessor.margin_start(icon, 5)
    GAccessor.margin_start(combo, 5)
    
    return Dict{String, Any}(
        "container" => container,
        "label" => label,
        "icon" => icon,
        "combo" => combo
    )
end

"""
    create_debug_console()

Create a debug console component (initially hidden).

# Returns
- Dictionary with console components
"""
function create_debug_console()
    # Create components
    button = GtkButton("▶")
    GAccessor.name(button, "console-toggle")
    
    text_view = GtkTextView()
    GAccessor.name(text_view, "console-text")
    GAccessor.editable(text_view, false)
    GAccessor.cursor_visible(text_view, false)
    
    scroll = GtkScrolledWindow()
    push!(scroll, text_view)
    
    label = GtkLabel("DEBUG CONSOLE")
    GAccessor.name(label, "header-label")
    
    header = GtkBox(:h)
    push!(header, label)
    
    # Center the label
    GAccessor.halign(label, Gtk.GConstants.GtkAlign.CENTER)
    GAccessor.hexpand(label, true)
    
    container = GtkBox(:v)
    push!(container, header)
    push!(container, scroll)
    
    # Make the scroll expandable
    GAccessor.vexpand(scroll, true)
    
    # Initially hidden
    GAccessor.visible(container, false)
    
    # Dev area for easter egg
    dev_area = GtkBox(:h)
    
    return Dict{String, Any}(
        "button" => button,
        "text" => text_view,
        "scroll" => scroll,
        "label" => label,
        "container" => container,
        "header" => header,
        "visible" => false,
        "dev" => dev_area
    )
end

"""
    create_button(label::String, class::String="")

Create a styled button.

# Arguments
- `label::String`: Button label text
- `class::String`: Optional CSS class name (default: "")

# Returns
- GtkButton instance
"""
function create_button(label::String, class::String="")
    button = GtkButton(label)
    
    if !isempty(class)
        GAccessor.name(button, class)
    end
    
    return button
end

"""
    add_css_class(widget, class_name::String)

Add a CSS class to a widget.

# Arguments
- `widget`: The widget to modify
- `class_name::String`: The CSS class to add
"""
function add_css_class(widget, class_name::String)
    # For GTK3, we'll have to concatenate class names - not ideal but works
    current_class = GAccessor.name(widget)
    if isempty(current_class)
        GAccessor.name(widget, class_name)
    else
        # If widget already has a class, append new one
        if !occursin(class_name, current_class)
            GAccessor.name(widget, string(current_class, " ", class_name))
        end
    end
end

"""
    remove_css_class(widget, class_name::String)

Remove a CSS class from a widget.

# Arguments
- `widget`: The widget to modify
- `class_name::String`: The CSS class to remove
"""
function remove_css_class(widget, class_name::String)
    current_class = GAccessor.name(widget)
    if !isempty(current_class)
        # If the class is the only one
        if current_class == class_name
            GAccessor.name(widget, "")
        else
            # Handle space-separated class names
            classes = split(current_class, " ")
            new_classes = filter(c -> c != class_name, classes)
            GAccessor.name(widget, join(new_classes, " "))
        end
    end
end

end # module