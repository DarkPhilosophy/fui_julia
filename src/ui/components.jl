module UIComponents

using Gtk
using Gtk.GLib
using Logging

export create_labeled_component, create_client_selector, create_progress_component,
       create_language_selector, create_debug_console, create_button, create_file_selection_component

println("UIComponents module loading...")
println("UIComponents: Gtk imported")
println("UIComponents module initialized")

"""
    create_labeled_component(label_text::String, input_text::String, has_button::Bool=false)

Create a component with a label and input field, optionally with a button.
"""
function create_labeled_component(label_text::String, input_text::String, has_button::Bool=false)
    # Create container
    container = GtkBox(:h)
    set_gtk_property!(container, :spacing, 5)
    set_gtk_property!(container, :margin_start, 10)
    set_gtk_property!(container, :margin_end, 10)
    set_gtk_property!(container, :margin_top, 5)
    set_gtk_property!(container, :margin_bottom, 5)
    
    # Create label
    label = GtkLabel(label_text)
    set_gtk_property!(label, :width_request, 100)
    set_gtk_property!(label, :halign, Gtk.GtkAlign.START)
    
    # Create input
    input = GtkEntry()
    set_gtk_property!(input, :text, input_text)
    set_gtk_property!(input, :hexpand, true)
    
    # Add components to container
    push!(container, label)
    push!(container, input)
    
    result = Dict{String, Any}(
        "container" => container,
        "label" => label,
        "input" => input
    )
    
    # Add button if requested
    if has_button
        button = GtkButton()
        set_gtk_property!(button, :width_request, 30)
        set_gtk_property!(button, :height_request, 30)
        push!(container, button)
        result["button"] = button
    end
    
    return result
end

"""
    create_file_selection_component(label_text::String, file_path::String)

Create a file selection component with label, input, unit and file button.
"""
function create_file_selection_component(label_text::String, file_path::String)
    # Create container
    container = GtkBox(:h)
    set_gtk_property!(container, :spacing, 5)
    set_gtk_property!(container, :margin_start, 10)
    set_gtk_property!(container, :margin_end, 10)
    set_gtk_property!(container, :margin_top, 5)
    set_gtk_property!(container, :margin_bottom, 5)
    
    # Create label with a name based on label_text for translation lookup
    label_name_key = replace(label_text, " " => "") # e.g., "BOM Split File" -> "BOMSplitFile"
    
    # Ensure consistent naming: "PINS File" should use "PINSCadFile" for compatibility
    if label_name_key == "PINSFile"
        label_name_key = "PINSCadFile" # Use the key that exists in language files
    end
    
    label = GtkLabel(label_text, name=label_name_key) # Use corrected name property
    set_gtk_property!(label, :width_request, 105)
    set_gtk_property!(label, :halign, Gtk.GtkAlign.START)
    
    # Create input
    input = GtkEntry()
    set_gtk_property!(input, :text, file_path)
    set_gtk_property!(input, :hexpand, true)
    
    # Create unit label
    unit_label = GtkLabel("cm")
    set_gtk_property!(unit_label, :margin_start, 5)
    set_gtk_property!(unit_label, :margin_end, 5)
    set_gtk_property!(unit_label, :width_request, 20)
    set_gtk_property!(unit_label, :height_request, 15)
    set_gtk_property!(unit_label, :halign, Gtk.GtkAlign.CENTER)
    
    # Create button
    button = GtkButton()
    set_gtk_property!(button, :width_request, 40)
    set_gtk_property!(button, :height_request, 40)
    
    # Use the upload file icon
    upload_icon_path = joinpath("assets", "icon", "upload-file.png")
    if isfile(upload_icon_path)
        # Create image from file
        icon = GtkImage()
        set_gtk_property!(icon, :file, upload_icon_path)
        set_gtk_property!(button, :image, icon)
    else
        # Fallback to a standard icon if file not found
        @warn "Upload icon not found at $upload_icon_path, using fallback"
        icon = GtkImage()
        set_gtk_property!(icon, :icon_name, "document-open")
        set_gtk_property!(button, :image, icon)
    end
    
    # Add components to container
    push!(container, label)
    push!(container, input)
    push!(container, unit_label)
    push!(container, button)
    
    return Dict{String, Any}(
        "container" => container,
        "label" => label,
        "input" => input,
        "button" => button,
        "unit" => unit_label
    )
end

"""
    create_client_selector()

Create the client selection component with dropdown and buttons.
"""
function create_client_selector()
    # Create container
    container = GtkBox(:h)  # Changed to horizontal layout
    set_gtk_property!(container, :spacing, 5)
    set_gtk_property!(container, :margin_start, 10)
    set_gtk_property!(container, :margin_end, 10)
    set_gtk_property!(container, :margin_top, 5)
    set_gtk_property!(container, :margin_bottom, 5)
    
    # Create label
    label = GtkLabel("Client:", name="Client") # Remove "Label" suffix
    set_gtk_property!(label, :width_request, 100)
    set_gtk_property!(label, :halign, Gtk.GtkAlign.START)
    
    # Create combo box
    combo = GtkComboBoxText()
    set_gtk_property!(combo, :width_request, 150)  # Fixed width for combo box
    set_gtk_property!(combo, :height_request, 30)
    
    # Create entry for new client
    entry = GtkEntry(name="NewClientEntry") # Add name property
    set_gtk_property!(entry, :width_request, 120)
    set_gtk_property!(entry, :height_request, 30)
    # Placeholder text will be set dynamically via update_ui_with_language
    # set_gtk_property!(entry, :placeholder_text, "New client name") 
    
    # Create buttons container
    button_box = GtkBox(:h)
    set_gtk_property!(button_box, :spacing, 5)
    
    # Create add button
    add_button = GtkButton("+", name="Add") # Name must match key in language file
    set_gtk_property!(add_button, :width_request, 30)
    set_gtk_property!(add_button, :height_request, 30)
    
    # Create delete button
    delete_button = GtkButton("-", name="Del") # Name must match key in language file
    set_gtk_property!(delete_button, :width_request, 30)
    set_gtk_property!(delete_button, :height_request, 30)
    
    # Add buttons to button box
    push!(button_box, add_button)
    push!(button_box, delete_button)
    
    # Add widgets to container
    push!(container, label)
    push!(container, combo)
    push!(container, entry)
    push!(container, button_box)
    
    # Return component dictionary
    return Dict{String, Any}(
        "container" => container,
        "label" => label,
        "combo" => combo,
        "entry" => entry,
        "add_button" => add_button,
        "delete_button" => delete_button,
        "button_box" => button_box
    )
end

"""
    create_progress_component()

Create the progress bar component.
"""
function create_progress_component()
    # Create container
    container = GtkBox(:h)
    set_gtk_property!(container, :spacing, 5)
    set_gtk_property!(container, :margin_start, 10)
    set_gtk_property!(container, :margin_end, 10)
    set_gtk_property!(container, :margin_top, 5)
    set_gtk_property!(container, :margin_bottom, 5)
    
    # Create progress bar
    progress = GtkProgressBar()
    set_gtk_property!(progress, :width_request, 500)
    set_gtk_property!(progress, :height_request, 40)
    set_gtk_property!(progress, :fraction, 0.0)
    
    # Create label
    label = GtkLabel("0%")
    set_gtk_property!(label, :width_request, 50)
    set_gtk_property!(label, :halign, Gtk.GtkAlign.CENTER)
    
    # Add components to container
    push!(container, progress)
    push!(container, label)
    
    return Dict{String, Any}(
        "container" => container,
        "progress" => progress,
        "label" => label
    )
end

"""
    create_language_selector()

Creates the language selector component with a combobox for selecting languages.
"""
function create_language_selector()
    # Create horizontal box
    box = GtkBox(:h) 
    set_gtk_property!(box, :spacing, 5)
    set_gtk_property!(box, :margin_start, 10)
    set_gtk_property!(box, :margin_end, 10)
    set_gtk_property!(box, :margin_top, 5)
    set_gtk_property!(box, :margin_bottom, 5)
    set_gtk_property!(box, :halign, Gtk.GtkAlign.END) # Position at the right side
    
    # Create label
    label = GtkLabel("Language:", name="Language") 
    set_gtk_property!(label, :width_request, 80)
    set_gtk_property!(label, :height_request, 25)
    
    # Create combo box
    combo = GtkComboBoxText()
    set_gtk_property!(combo, :width_request, 100)
    set_gtk_property!(combo, :height_request, 25)
    
    # Dynamically populate languages
    lang_dir = joinpath("assets", "lang")
    available_langs = String[]
    if isdir(lang_dir)
        try
            for filename in readdir(lang_dir)
                if endswith(lowercase(filename), ".json")
                    lang_code = replace(filename, r"\.json$"i => "") # Case-insensitive replace
                    push!(available_langs, lang_code)
                end
            end
            
            # Sort for consistent order (e.g., alphabetical)
            sort!(available_langs)
            
            # Populate the combo box
            for lang_code in available_langs
                push!(combo, lang_code, lang_code) # Use code for both ID and display text
            end
            @info "Found languages: $(join(available_langs, ", "))"
            
            # Set a default selection if available (e.g., "en")
            if "en" in available_langs
                 set_gtk_property!(combo, :active_id, "en")
            elseif !isempty(available_langs)
                 set_gtk_property!(combo, :active, 0) # Select the first one if "en" isn't there
            end

        catch e
            @error "Error reading language directory: $lang_dir" exception=(e, catch_backtrace())
             # Fallback: maybe add just 'en'?
             push!(combo, "en", "en")
             set_gtk_property!(combo, :active_id, "en")
        end
    else
         @warn "Language directory not found: $lang_dir. Adding 'en' as default."
         push!(combo, "en", "en")
         set_gtk_property!(combo, :active_id, "en")
    end
    
    # Create image for flag (adjust icon name based on selection later)
    flag = GtkImage()
    set_gtk_property!(flag, :icon_name, "flag-us") # Default to US flag
    set_gtk_property!(flag, :width_request, 35)
    set_gtk_property!(flag, :height_request, 35)
    
    # Pack components into box
    push!(box, label)
    push!(box, combo)
    push!(box, flag)
    
    # Return dictionary of components
    return Dict{String, Any}(
        "container" => box,
        "label" => label,
        "combo" => combo,
        "flag" => flag
    )
end

"""
    create_debug_console()

Create the debug console component.
"""
function create_debug_console()
    println("Creating debug console")
    
    # Create container
    container = GtkBox(:v)
    set_gtk_property!(container, :spacing, 5)
    set_gtk_property!(container, :margin_start, 10)
    set_gtk_property!(container, :margin_end, 10)
    set_gtk_property!(container, :margin_top, 5)
    set_gtk_property!(container, :margin_bottom, 5)
    
    # Create header box
    header = GtkBox(:h)
    set_gtk_property!(header, :spacing, 5)
    
    # Create label
    label = GtkLabel("Debug Console")
    set_gtk_property!(label, :halign, Gtk.GtkAlign.START)
    set_gtk_property!(label, :hexpand, true)
    
    # Create toggle button
    toggle = GtkButton("Show/Hide")
    set_gtk_property!(toggle, :width_request, 80)
    
    # Add components to header
    push!(header, label)
    push!(header, toggle)
    
    # Create scrolled window
    scroll = GtkScrolledWindow()
    set_gtk_property!(scroll, :height_request, 200)
    set_gtk_property!(scroll, :vexpand, true)
    
    # Create text view
    text_view = GtkTextView()
    set_gtk_property!(text_view, :editable, false)
    set_gtk_property!(text_view, :cursor_visible, false)
    set_gtk_property!(text_view, :wrap_mode, Gtk.GtkWrapMode.WORD)
    push!(scroll, text_view)
    
    # Initially hide the console
    set_gtk_property!(scroll, :visible, false)
    
    # Add components to container
    push!(container, header)
    push!(container, scroll)
    
    return Dict{String, Any}(
        "container" => container,
        "label" => label,
        "toggle" => toggle,
        "scroll" => scroll,
        "text_view" => text_view
    )
end

"""
    create_button(text::String)

Create a button with the specified text.
"""
function create_button(text::String)
    println("Creating button: $text")
    
    button = GtkButton(text)
    set_gtk_property!(button, :width_request, 200)
    set_gtk_property!(button, :height_request, 40)
    
    return button
end

end # module