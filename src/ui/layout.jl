module UILayout

using Gtk
using ..UIComponents
using ..UIHandlers

println("UILayout module loading...")

export create_main_layout

const ORIGINAL_WIDTH = 500
const ORIGINAL_HEIGHT = 300
const CONSOLE_WIDTH = 300

"""
    create_main_layout()

Create the main application layout.
"""
function create_main_layout()
    println("Creating main window components...")
    
    # Create main container
    main_container = GtkBox(:v)
    set_gtk_property!(main_container, :spacing, 10)
    set_gtk_property!(main_container, :margin_start, 10)
    set_gtk_property!(main_container, :margin_end, 10)
    set_gtk_property!(main_container, :margin_top, 10)
    set_gtk_property!(main_container, :margin_bottom, 10)
    
    # Create about section
    about_label = GtkLabel("by adalbertalexadru.ungureanu@flex.com")
    set_gtk_property!(about_label, :width_request, 450)
    set_gtk_property!(about_label, :height_request, 40)
    set_gtk_property!(about_label, :halign, Gtk.GtkAlign.START)
    
    # Create file selection components
    bomsplit_component = UIComponents.create_file_selection_component("BOM Split File", "")
    pincad_component = UIComponents.create_file_selection_component("PINS File", "")
    
    # Create client component
    client_component = UIComponents.create_client_selector()
    
    # Create program name component - custom version without button and cm label
    program_component = create_program_name_component("Program Name")
    
    # Create language selector
    language_component = UIComponents.create_language_selector()
    
    # Create generate button
    generate_button = GtkButton("GENERATE .CAD/CSV", name="Generate")
    set_gtk_property!(generate_button, :width_request, 200)
    set_gtk_property!(generate_button, :height_request, 40)
    
    # Create generate button container for centering
    generate_box = GtkBox(:h)
    set_gtk_property!(generate_box, :halign, Gtk.GtkAlign.CENTER)
    push!(generate_box, generate_button)
    
    # Create progress component
    progress_component = UIComponents.create_progress_component()
    
    # Create exit button
    exit_button = GtkButton("Exit", name="Exit")
    set_gtk_property!(exit_button, :width_request, 115)
    set_gtk_property!(exit_button, :height_request, 30)
    
    # Create exit button container
    exit_box = GtkBox(:h)
    set_gtk_property!(exit_box, :halign, Gtk.GtkAlign.END)
    push!(exit_box, exit_button)
    
    println("Adding components to main container...")
    
    # Add all components to main container
    push!(main_container, about_label)
    push!(main_container, bomsplit_component["container"])
    push!(main_container, pincad_component["container"])
    push!(main_container, client_component["container"])
    push!(main_container, program_component["container"])
    push!(main_container, language_component["container"])
    push!(main_container, generate_box)
    push!(main_container, progress_component["container"])
    push!(main_container, exit_box)
    
    println("Creating components dictionary...")
    
    # Create components dictionary
    components = Dict{String, Any}(
        "container" => main_container,
        "about" => Dict("label" => about_label),
        "bomsplit" => bomsplit_component,
        "pincad" => pincad_component,
        "program" => program_component,
        "client" => client_component,
        "language" => language_component,
        "generate" => Dict("button" => generate_button),
        "progress" => progress_component,
        "exit" => Dict("button" => exit_button)
    )
    
    println("Layout creation completed.")
    return components
end

"""
    create_header_component()

Create the header component.
"""
function create_header_component()
    # Create container
    container = GtkBox(:h)
    set_gtk_property!(container, :spacing, 5)
    set_gtk_property!(container, :margin_start, 10)
    set_gtk_property!(container, :margin_end, 10)
    set_gtk_property!(container, :margin_top, 5)
    set_gtk_property!(container, :margin_bottom, 5)
    
    # Create label
    label = GtkLabel("by adalbertalexandru.ungureanu@flex.com")
    set_gtk_property!(label, :halign, Gtk.GtkAlign.START)
    set_gtk_property!(label, :hexpand, true)
    
    # Add components to container
    push!(container, label)
    
    return container
end

"""
    create_file_selection_component(label_text::String, file_path::String)

Create a file selection component.
"""
function create_file_selection_component(label_text::String, file_path::String)
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
    set_gtk_property!(input, :text, file_path)
    set_gtk_property!(input, :hexpand, true)
    
    # Create button
    button = GtkButton()
    set_gtk_property!(button, :width_request, 30)
    set_gtk_property!(button, :height_request, 30)
    
    # Add components to container
    push!(container, label)
    push!(container, input)
    push!(container, button)
    
    return Dict{String, Any}(
        "container" => container,
        "label" => label,
        "input" => input,
        "button" => button
    )
end

function create_main_window()
    window = GtkWindow("Fui", 800, 600)
    set_gtk_property!(window, :title, "Fui")
    set_gtk_property!(window, :window_position, Gtk.GtkWindowPosition.CENTER)
    set_gtk_property!(window, :default_width, 800)
    set_gtk_property!(window, :default_height, 600)
    
    # Apply dark theme
    css_provider = GtkCssProvider()
    css = """
    window {
        background-color: #2d2d2d;
        color: #ffffff;
    }
    entry {
        background-color: #3d3d3d;
        color: #ffffff;
        border-radius: 4px;
        transition: all 0.2s ease;
    }
    entry:focus {
        background-color: #4a4a4a;
        box-shadow: 0 0 3px rgba(66, 135, 245, 0.8);
    }
    button {
        background-color: #4d4d4d;
        color: #ffffff;
        border-radius: 4px;
        transition: all 0.2s ease; 
    }
    button:hover {
        background-color: #5d5d5d;
        transform: translateY(-2px);
        box-shadow: 0 2px 5px rgba(0, 0, 0, 0.3);
    }
    button:active {
        background-color: #3d3d3d;
        transform: translateY(1px);
        box-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
    }
    combobox {
        background-color: #3d3d3d;
        color: #ffffff;
        border-radius: 4px;
        transition: all 0.2s ease;
    }
    combobox entry {
        background-color: #3d3d3d;
        color: #ffffff;
    }
    combobox:hover {
        background-color: #4a4a4a;
        box-shadow: 0 2px 5px rgba(0, 0, 0, 0.2);
    }
    progressbar {
        background-color: #3d3d3d;
        color: #ffffff;
        border-radius: 4px;
    }
    progressbar trough {
        background-color: #3d3d3d;
        border-radius: 4px;
    }
    progressbar progress {
        background-color: #4285f4;
        border-radius: 4px;
    }
    label {
        color: #ffffff;
    }
    """
    Gtk.GAccessor.data(css_provider, css)
    GtkStyleContext.add_provider_for_screen(
        Gtk.GAccessor.screen(window),
        css_provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )
    
    return window
end

"""
    create_program_name_component(label_text::String)

Create a program name input component with just a label and entry field (no button or unit label).
"""
function create_program_name_component(label_text::String)
    # Create container
    container = GtkBox(:h)
    set_gtk_property!(container, :spacing, 5)
    set_gtk_property!(container, :margin_start, 10)
    set_gtk_property!(container, :margin_end, 10)
    set_gtk_property!(container, :margin_top, 5)
    set_gtk_property!(container, :margin_bottom, 5)
    
    # Create label with a name based on label_text for translation lookup
    label_name_key = replace(label_text, " " => "")
    label = GtkLabel(label_text, name=label_name_key)
    set_gtk_property!(label, :width_request, 105)
    set_gtk_property!(label, :halign, Gtk.GtkAlign.START)
    
    # Create input with wider width
    input = GtkEntry()
    set_gtk_property!(input, :hexpand, true)
    set_gtk_property!(input, :width_request, 300) # Make it wider
    
    # Add components to container
    push!(container, label)
    push!(container, input)
    
    return Dict{String, Any}(
        "container" => container,
        "label" => label,
        "input" => input
    )
end

end # module