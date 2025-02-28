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
    set_gtk_property!(input, :text, input_text)
    
    if is_button
        set_gtk_property!(input, :has_frame, false)
        set_gtk_property!(input, :editable, false)
        GAccessor.name(input, "file-button")
    else
        set_gtk_property!(input, :has_frame, true)
    end
    
    # Layout
    push!(container, label)
    push!(container, input)
    set_gtk_property!(input, :hexpand, true)
    set_gtk_property!(input, :margin_start, 10)
    
    return Dict(
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
    combo = GtkComboBoxText()
    remove_button = GtkButton("✖ Del")
    add_entry = GtkEntry()
    add_button = GtkButton("➕ Add")
    
    # Set button classes
    GAccessor.name(remove_button, "small-button")
    GAccessor.name(add_button, "small-button")
    
    # Populate client options
    for client in clients
        push!(combo, client)
    end
    
    # Set active client if provided
    if !isempty(selected) && selected in clients
        for (i, client) in enumerate(clients)
            if client == selected
                set_gtk_property!(combo, :active, i - 1)
                break
            end
        end
    elseif !isempty(clients)
        set_gtk_property!(combo, :active, 0)  # Select first by default
    end
    
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
    set_gtk_property!(progress_bar, :fraction, 0.0)
    
    # Create label
    progress_label = GtkLabel("0%")
    GAccessor.name(progress_label, "progress-label")
    
    # Layout
    push!(container, progress_bar)
    push!(container, progress_label)
    set_gtk_property!(progress_bar, :hexpand, true)
    set_gtk_property!(progress_label, :margin_start, 10)
    
    return Dict(
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
    combo = GtkComboBoxText()
    
    # Populate language options
    for lang in available_languages
        push!(combo, lang)
    end
    
    # Set current language
    if !isempty(current_language) && current_language in available_languages
        for (i, lang) in enumerate(available_languages)
            if lang == current_language
                set_gtk_property!(combo, :active, i - 1)
                break
            end
        end
    elseif !isempty(available_languages)
        set_gtk_property!(combo, :active, 0)  # Select first by default
    end
    
    # Layout
    push!(container, label)
    push!(container, icon)
    push!(container, combo)
    
    # Set margins
    set_gtk_property!(icon, :margin_start, 5)
    set_gtk_property!(combo, :margin_start, 5)
    
    return Dict(
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
    set_gtk_property!(text_view, :editable, false)
    set_gtk_property!(text_view, :cursor_visible, false)
    
    scroll = GtkScrolledWindow()
    push!(scroll, text_view)
    
    label = GtkLabel("DEBUG CONSOLE")
    GAccessor.name(label, "header-label")
    
    header = GtkBox(:h)
    push!(header, label)
    set_gtk_property!(label, :halign, 1)  # GTK_ALIGN_CENTER = 1
    set_gtk_property!(label, :hexpand, true)
    
    container = GtkBox(:v)
    push!(container, header)
    push!(container, scroll)
    set_gtk_property!(scroll, :vexpand, true)
    
    # Initially hidden
    set_gtk_property!(container, :visible, false)
    
    # Dev area for easter egg
    dev_area = GtkBox(:h)
    
    return Dict(
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
    # In GTK3, we use GAccessor.name to set a CSS class
    # For multiple classes, we'd need to implement custom handling
    current_class = get_gtk_property(widget, :name, String)
    if isempty(current_class)
        GAccessor.name(widget, class_name)
    else
        # If widget already has a class, append new one
        if !occursin(class_name, current_class)
            GAccessor.name(widget, current_class * " " * class_name)
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
    current_class = get_gtk_property(widget, :name, String)
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