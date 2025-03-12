module UIComponents

export create_labeled_component, create_client_component, create_progress_component,
       create_language_selector, create_debug_console, create_button

using Gtk

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
function create_labeled_component(label_text::AbstractString, input_text::AbstractString, is_button::Bool=false)
    # Cast inputs to strings as needed
    label_text_str = string(label_text)
    input_text_str = string(input_text)
    is_button_bool = convert(Bool, is_button)
    
    # Create container
    container = GtkBox(:h)
    
    # Create components
    label = GtkLabel(label_text_str)
    input = GtkEntry()
    
    # Set text
    Gtk.set_gtk_property!(input, :text, input_text_str)
    
    # Configure based on button flag
    if is_button_bool
        Gtk.set_gtk_property!(input, :has_frame, false)
        Gtk.set_gtk_property!(input, :editable, false)
    end
    
    # Add components to container
    push!(container, label)
    push!(container, input)
    
    # Set spacing
    Gtk.set_gtk_property!(container, :spacing, 10)
    
    # Make input expand
    Gtk.set_gtk_property!(input, :hexpand, true)
    
    # Return dictionary of components
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
function create_client_component(label_text::AbstractString, clients::Vector{AbstractString}=Vector[], selected::AbstractString="")
    # Create container
    container = GtkBox(:h)
    
    # Create components
    label = GtkLabel(string(label_text))
    combo = GtkComboBoxText(false)
    remove_button = GtkButton("✖ Del")
    add_entry = GtkEntry()
    add_button = GtkButton("➕ Add")
    
    # Convert clients to array if string
    client_array = typeof(clients) <: AbstractString ? split(clients, ",") : clients
    
    # Add clients to combo
    for client in client_array
        push!(combo, string(client))
    end
    
    # Set active client if provided
    if !isempty(selected) && length(client_array) > 0
        found = false
        for (i, client) in enumerate(client_array)
            if string(client) == string(selected)
                Gtk.set_gtk_property!(combo, :active, i - 1)
                found = true
                break
            end
        end
        
        # Default to first item if not found
        if !found && length(client_array) > 0
            Gtk.set_gtk_property!(combo, :active, 0)
        end
    elseif length(client_array) > 0
        Gtk.set_gtk_property!(combo, :active, 0)
    end
    
    # Add components to container
    push!(container, label)
    push!(container, combo)
    push!(container, remove_button)
    push!(container, add_entry)
    push!(container, add_button)
    
    # Set spacing
    Gtk.set_gtk_property!(container, :spacing, 5)
    
    # Make add_entry expand
    Gtk.set_gtk_property!(add_entry, :hexpand, true)
    
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
    container = GtkBox(:h)
    progress_bar = GtkProgressBar()
    progress_label = GtkLabel("0%")
    
    # Set initial fraction
    Gtk.set_gtk_property!(progress_bar, :fraction, 0.0)
    
    # Add components
    push!(container, progress_bar)
    push!(container, progress_label)
    
    # Set properties
    Gtk.set_gtk_property!(container, :spacing, 10)
    Gtk.set_gtk_property!(progress_bar, :hexpand, true)
    
    return Dict{String, Any}(
        "container" => container,
        "progress_bar" => progress_bar,
        "label" => progress_label
    )
end

"""
    create_language_selector(available_languages::Vector{String}, current_language::String)

Create a language selection component.
"""
function create_language_selector(available_languages::Vector{String}, current_language::String)
    # Convert inputs if needed
    langs = convert(Vector{String}, [string(lang) for lang in available_languages])
    current = string(current_language)
    
    # Create container and components
    container = GtkBox(:h)
    label = GtkLabel("Language:")
    icon = GtkLabel("🌐")
    combo = GtkComboBoxText(false)
    
    # Add languages to combo
    for lang in langs
        push!(combo, lang)
    end
    
    # Set active language
    if !isempty(current) && !isempty(langs)
        found = false
        for (i, lang) in enumerate(langs)
            if lang == current
                Gtk.set_gtk_property!(combo, :active, i - 1)
                found = true
                break
            end
        end
        
        if !found && !isempty(langs)
            Gtk.set_gtk_property!(combo, :active, 0)
        end
    elseif !isempty(langs)
        Gtk.set_gtk_property!(combo, :active, 0)
    end
    
    # Layout
    push!(container, label)
    push!(container, icon)
    push!(container, combo)
    
    # Set properties
    Gtk.set_gtk_property!(container, :spacing, 5)
    
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

Create a debug console component.
"""
function create_debug_console()
    # Create components
    button = GtkButton("▶")
    text_view = GtkTextView()
    scroll = GtkScrolledWindow()
    label = GtkLabel("DEBUG CONSOLE")
    
    # Configure components
    Gtk.set_gtk_property!(text_view, :editable, false)
    Gtk.set_gtk_property!(text_view, :cursor_visible, false)
    
    # Layout
    push!(scroll, text_view)
    
    header = GtkBox(:h)
    push!(header, label)
    Gtk.set_gtk_property!(label, :hexpand, true)
    
    container = GtkBox(:v)
    push!(container, header)
    push!(container, scroll)
    
    # Set properties
    Gtk.set_gtk_property!(container, :spacing, 5)
    Gtk.set_gtk_property!(scroll, :vexpand, true)
    Gtk.set_gtk_property!(container, :visible, false)
    
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
        Gtk.set_gtk_property!(button, :name, class)
    end
    
    return button
end

end # module