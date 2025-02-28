module UIHandlers

export setup_event_handlers

using Gtk
using Base.Threads: @spawn
using ..XDebug
using ..Parser
using ..Converter
using ..UIAnimations
using ..Config
using ..FileOps
using ..Safety
using ..AutoUpdate

# Event debouncing machinery
mutable struct DebounceState
    last_time::Float64
    timer_id::Union{UInt, Nothing}
    
    DebounceState() = new(0.0, nothing)
end

const DEBOUNCE_REGISTRY = Dict{String, DebounceState}()

"""
    debounce(func::Function, widget_id::String, delay::Float64=0.2)

Execute a function with debouncing to prevent multiple rapid executions.

# Arguments
- `func::Function`: Function to execute
- `widget_id::String`: Unique identifier for this debounce context
- `delay::Float64`: Minimum delay between executions in seconds (default: 0.2)

# Returns
- Result of function execution
"""
function debounce(func::Function, widget_id::String, delay::Float64=0.2)
    current_time = time()
    
    # Get or create debounce state
    state = get!(DEBOUNCE_REGISTRY, widget_id, DebounceState())
    
    # Check if enough time has passed
    if current_time - state.last_time >= delay
        # Update last execution time
        state.last_time = current_time
        
        # Execute function immediately
        return func()
    else
        # Cancel existing timer if present
        if state.timer_id !== nothing
            GLib.g_source_remove(state.timer_id)
            state.timer_id = nothing
        end
        
        # Create new timer for delayed execution
        state.timer_id = GLib.timeout_add(UInt32(delay * 1000)) do
            state.last_time = time()
            state.timer_id = nothing
            func()
            return false  # Stop timer after execution
        end
    end
    
    return nothing
end

"""
    setup_event_handlers(components, config, language, logger)

Set up all UI event handlers for the application.

# Arguments
- `components`: UI components structure
- `config`: Application configuration
- `language`: Current language configuration
- `logger`: Logger instance
"""
function setup_event_handlers(components, config, language, logger)
    XDebug.log_info(logger, "Setting up UI event handlers", XDebug.UI)
    
    # Console toggle button handler
    console_button = components.console["button"]
    signal_connect(console_button, "clicked") do widget
        debounce(() -> toggle_console(components), "console_toggle", 0.5)
    end
    
    # About label handler (email link)
    about_label = components.about_label
    signal_connect(about_label, "button-press-event") do widget, event
        debounce(() -> open_email_client("adalbertalexadru.ungureanu@flex.com"), "email_client", 1.0)
    end
    
    # Language selection handler
    language_combo = components.language["combo"]
    signal_connect(language_combo, "changed") do widget
        debounce(() -> handle_language_change(widget, components, config, logger), "language_change", 0.2)
    end
    
    # File selection handlers
    setup_file_selection_handlers(components, logger)
    
    # Client management handlers
    setup_client_handlers(components, config, logger)
    
    # Generate button handler
    generate_button = components.generate_button
    signal_connect(generate_button, "clicked") do widget
        debounce(() -> handle_generate_click(components, config, logger), "generate", 1.0)
    end
    
    # Window close handler
    window = components.window
    signal_connect(window, "delete-event") do widget, event
        handle_window_close(components, config, logger)
    end
    
    XDebug.log_info(logger, "UI event handlers setup completed", XDebug.UI)
end

"""
    toggle_console(components)
    
Toggle the debug console visibility.
"""
function toggle_console(components)
    console = components.console
    console_visible = console["visible"]
    window = components.window
    
    # Get current window size
    current_width = get_gtk_property(window, :default_width, Int)
    
    if console_visible
        # Hide console
        set_gtk_property!(console["container"], :visible, false)
        set_gtk_property!(console["button"], :label, "▶")
        
        # Resize window
        set_gtk_property!(window, :default_width, current_width - 520)
    else
        # Show console
        set_gtk_property!(console["container"], :visible, true)
        set_gtk_property!(console["button"], :label, "◀")
        
        # Resize window
        set_gtk_property!(window, :default_width, current_width + 520)
    end
    
    # Update visibility state
    console["visible"] = !console_visible
    
    return console["visible"]
end

"""
    open_email_client(email::String)
    
Open the default email client with a new message.
"""
function open_email_client(email::String)
    subject = url_encode("Hey Alex I got a question!")
    body = ""
    
    # Use different commands based on platform
    if Sys.iswindows()
        run(`cmd /c start mailto:$email?subject=$subject&body=$body`)
    elseif Sys.isapple()
        run(`open mailto:$email?subject=$subject&body=$body`)
    else  # Linux and others
        run(`xdg-open mailto:$email?subject=$subject&body=$body`)
    end
    
    return true
end

"""
    url_encode(str::String)
    
URL encode a string for use in mailto links.
"""
function url_encode(str::String)
    return replace(
        replace(str, "\n" => "%0D%0A"),
        r"([^A-Za-z0-9_\-\.])" => s -> string("%", uppercase(string(Int(s[1]), base=16, pad=2)))
    )
end

"""
    handle_language_change(widget, components, config, logger)
    
Handle language selection change.
"""
function handle_language_change(widget, components, config, logger)
    lang_code = Gtk.bytestring(GAccessor.active_text(widget))
    
    if isempty(lang_code)
        return false
    end
    
    XDebug.log_info(logger, "Language changed to: $lang_code", XDebug.UI)
    
    # Load language file
    config["Language"] = "assets/lang/$lang_code.json"
    language = Config.load_language(lang_code)
    
    if language === nothing
        XDebug.log_warning(logger, "Failed to load language: $lang_code", XDebug.UI)
        return false
    end
    
    # Update UI with new language
    update_ui_with_language(components, language, logger)
    
    return true
end

"""
    update_ui_with_language(components, language, logger)
    
Update UI elements with the selected language.
"""
function update_ui_with_language(components, language, logger)
    XDebug.log_info(logger, "Updating UI with language texts", XDebug.UI)
    
    Safety.safe_operation(
        () -> begin
            # Update buttons
            set_gtk_property!(components.generate_button, :label, 
                get(get(language, "Buttons", Dict()), "Generate", "Generate .CAD/CSV"))
            
            # Update file selectors
            bomsplit_text = get_gtk_property(components.bomsplit["input"], :text, String)
            if bomsplit_text == "Click to select BOMSPLIT"
                set_gtk_property!(components.bomsplit["input"], :text,
                    get(get(language, "Buttons", Dict()), "BOMSplitPath", "Click to select BOMSPLIT"))
            end
                
            pincad_text = get_gtk_property(components.pincad["input"], :text, String)
            if pincad_text == "Click to select PINCAD"
                set_gtk_property!(components.pincad["input"], :text,
                    get(get(language, "Buttons", Dict()), "PINSCadPath", "Click to select PINCAD"))
            end
            
            # Update labels
            GAccessor.text(components.bomsplit["label"], 
                get(get(language, "Labels", Dict()), "BOMSplit", "Click to select BOM"))
            GAccessor.text(components.pincad["label"], 
                get(get(language, "Labels", Dict()), "PINSCad", "Click to select PINS"))
            GAccessor.text(components.client["label"], 
                get(get(language, "Labels", Dict()), "Client", "Client"))
            GAccessor.text(components.program["label"], 
                get(get(language, "Labels", Dict()), "ProgramName", "Program Name"))
            
            # Update client management buttons
            set_gtk_property!(components.client["removeButton"], :label, 
                "✖ " * get(get(language, "Buttons", Dict()), "Del", "Del"))
            set_gtk_property!(components.client["addButton"], :label, 
                "➕ " * get(get(language, "Buttons", Dict()), "Add", "Add"))
            
            # Play feedback sound
            UIAnimations.play_sound("interface-change")
        end,
        (err) -> begin
            XDebug.log_error(logger, "Error updating UI language: $err", XDebug.UI)
            XDebug.log_backtrace(logger)
        end
    )
end

"""
    setup_file_selection_handlers(components, logger)
    
Set up handlers for file selection fields.
"""
function setup_file_selection_handlers(components, logger)
    # BOM file selection
    bomsplit_input = components.bomsplit["input"]
    signal_connect(bomsplit_input, "button-press-event") do widget, event
        debounce(() -> select_file(widget, "Select your BOMSPLIT file", components.window, logger), "bomsplit_select", 0.5)
    end
    
    # PINS file selection
    pincad_input = components.pincad["input"]
    signal_connect(pincad_input, "button-press-event") do widget, event
        debounce(() -> select_file(widget, "Select your PINCAD file", components.window, logger), "pincad_select", 0.5)
    end
    
    # Drag and drop is setup in the layout module
end

"""
    select_file(widget, title, parent_window, logger)
    
Open a file dialog and update the entry with the selected file.
"""
function select_file(widget, title, parent_window, logger)
    XDebug.log_info(logger, "Opening file dialog: $title", XDebug.UI)
    
    dialog = GtkFileChooserDialog(title, parent_window, GConstants.GtkFileChooserAction.OPEN,
                                 ("Cancel", GConstants.GtkResponseType.CANCEL,
                                  "Open", GConstants.GtkResponseType.ACCEPT))
    
    # Add file filters
    filter_all = GtkFileFilter()
    set_gtk_property!(filter_all, :name, "All files")
    push!(filter_all, "*")
    
    filter_asc = GtkFileFilter()
    set_gtk_property!(filter_asc, :name, "ASC files")
    push!(filter_asc, "*.asc")
    
    filter_txt = GtkFileFilter()
    set_gtk_property!(filter_txt, :name, "Text files")
    push!(filter_txt, "*.txt")
    
    filter_csv = GtkFileFilter()
    set_gtk_property!(filter_csv, :name, "CSV files")
    push!(filter_csv, "*.csv")
    
    push!(dialog, filter_all, filter_asc, filter_txt, filter_csv)
    
    response = run(dialog)
    
    if response == GConstants.GtkResponseType.ACCEPT
        file_path = Gtk.filename(dialog)
        XDebug.log_info(logger, "Selected file: $file_path", XDebug.UI)
        set_gtk_property!(widget, :text, file_path)
        
        # Play sound feedback
        UIAnimations.play_sound("interface-click")
    end
    
    destroy(dialog)
    return response == GConstants.GtkResponseType.ACCEPT
end

"""
    setup_client_handlers(components, config, logger)
    
Set up handlers for client management (add/remove).
"""
function setup_client_handlers(components, config, logger)
    # Add client button
    add_button = components.client["addButton"]
    signal_connect(add_button, "clicked") do widget
        debounce(() -> add_client(components, config, logger), "add_client", 0.5)
    end
    
    # Remove client button
    remove_button = components.client["removeButton"]
    signal_connect(remove_button, "clicked") do widget
        debounce(() -> remove_client(components, config, logger), "remove_client", 0.5)
    end
end

"""
    add_client(components, config, logger)
    
Add a new client to the selection box.
"""
function add_client(components, config, logger)
    add_entry = components.client["addEntry"]
    select_box = components.client["selectBox"]
    
    new_entry = get_gtk_property(add_entry, :text, String)
    
    if isempty(new_entry)
        return false
    end
    
    XDebug.log_info(logger, "Adding new client: $new_entry", XDebug.UI)
    
    # Check if entry already exists
    combo_model = GAccessor.model(select_box)
    iter = Gtk.GtkTreeIter()
    valid = Gtk.GLib.convertible_to_boolean(ccall((:gtk_tree_model_get_iter_first, Gtk.libgtk), Cint, 
                                                 (Ptr{GObject}, Ptr{GtkTreeIter}), combo_model, Ref(iter)))
    
    entry_exists = false
    while valid
        val = GAccessor.value(combo_model, iter, 0)
        if val == new_entry
            # Entry already exists, select it
            GAccessor.active_iter(select_box, iter)
            entry_exists = true
            break
        end
        valid = Gtk.GLib.convertible_to_boolean(ccall((:gtk_tree_model_iter_next, Gtk.libgtk), Cint, 
                                                     (Ptr{GObject}, Ptr{GtkTreeIter}), combo_model, Ref(iter)))
    end
    
    if !entry_exists
        # Add new entry
        push!(select_box, new_entry)
        
        # Select the newly added item
        n_items = length(select_box)
        set_gtk_property!(select_box, :active, n_items - 1)
        
        # Clear input
        set_gtk_property!(add_entry, :text, "")
        
        # Play sound feedback
        UIAnimations.play_sound("interface-add")
    end
    
    return true
end

"""
    remove_client(components, config, logger)
    
Remove the selected client from the selection box.
"""
function remove_client(components, config, logger)
    select_box = components.client["selectBox"]
    
    # Check if anything is selected
    active_idx = get_gtk_property(select_box, :active, Int)
    if active_idx == -1
        msg_dialog = GtkMessageDialog(components.window, GConstants.GtkDialogFlags.MODAL,
                                      GConstants.GtkMessageType.WARNING, GConstants.GtkButtonsType.OK,
                                      "Nothing was selected.")
        run(msg_dialog)
        destroy(msg_dialog)
        return false
    end
    
    # Get number of items
    combo_model = GAccessor.model(select_box)
    n_items = length(select_box)
    
    # Check if this is the last item
    if n_items <= 1
        msg_dialog = GtkMessageDialog(components.window, GConstants.GtkDialogFlags.MODAL,
                                      GConstants.GtkMessageType.WARNING, GConstants.GtkButtonsType.OK,
                                      "Cannot delete the last remaining option.")
        run(msg_dialog)
        destroy(msg_dialog)
        return false
    end
    
    # Get the selected item text
    selected_text = Gtk.bytestring(GAccessor.active_text(select_box))
    
    XDebug.log_info(logger, "Removing client: $selected_text (index $active_idx)", XDebug.UI)
    
    # Remove the selected item
    iter = Gtk.GtkTreeIter()
    valid = Gtk.GLib.convertible_to_boolean(ccall((:gtk_tree_model_iter_nth_child, Gtk.libgtk), Cint, 
                                                 (Ptr{GObject}, Ptr{GtkTreeIter}, Ptr{GObject}, Cint),
                                                 combo_model, Ref(iter), C_NULL, active_idx))
    if valid
        Gtk.G_.remove(select_box, active_idx)
        
        # Select another item
        new_idx = min(active_idx, n_items - 2)
        set_gtk_property!(select_box, :active, new_idx)
        
        # Play sound feedback
        UIAnimations.play_sound("interface-remove")
    end
    
    return true
end

"""
    handle_generate_click(components, config, logger)
    
Handle the Generate button click event.
"""
function handle_generate_click(components, config, logger)
    XDebug.log_info(logger, "Generate button clicked", XDebug.UI)
    
    # Play click sound
    UIAnimations.play_sound("interface-click")
    
    # Validate program name
    program_name = get_gtk_property(components.program["input"], :text, String)
    if isempty(program_name)
        confirm_dialog = GtkMessageDialog(components.window, GConstants.GtkDialogFlags.MODAL,
                                          GConstants.GtkMessageType.QUESTION, GConstants.GtkButtonsType.YES_NO,
                                          "No PN type, use '1234' as default PN?")
        set_gtk_property!(confirm_dialog, :title, "ERROR / INVALID DATA")
        
        response = run(confirm_dialog)
        destroy(confirm_dialog)
        
        if response != GConstants.GtkResponseType.YES
            update_progress_bar(components, 0, "Generate declined", 0xFF5733)
            XDebug.log_info(logger, "Generate declined - no program name", XDebug.UI)
            return false
        end
        
        # Set default program name
        set_gtk_property!(components.program["input"], :text, "1234")
        program_name = "1234"
        XDebug.log_info(logger, "Using default program name: 1234", XDebug.UI)
    end
    
    # Validate BOM file
    bom_file = get_gtk_property(components.bomsplit["input"], :text, String)
    if isempty(bom_file) || bom_file == "Click to select BOMSPLIT" || 
       bom_file == get(get(language, "Buttons", Dict()), "BOMSplitPath", "Click to select BOMSPLIT")
        update_progress_bar(components, 0, "Error occurred", 0xFF5733)
        
        error_dialog = GtkMessageDialog(components.window, GConstants.GtkDialogFlags.MODAL,
                                        GConstants.GtkMessageType.ERROR, GConstants.GtkButtonsType.OK,
                                        "Missing BOM file path.\nSelect a valid BOMSPLIT file.")
        set_gtk_property!(error_dialog, :title, "ERROR")
        
        run(error_dialog)
        destroy(error_dialog)
        
        set_gtk_property!(components.bomsplit["input"], :text, 
                         get(get(language, "Buttons", Dict()), "BOMSplitPath", "Click to select BOMSPLIT"))
        XDebug.log_error(logger, "Missing BOM file path", XDebug.UI)
        return false
    end
    
    # Get client and PINS file
    pins_file = get_gtk_property(components.pincad["input"], :text, String)
    default_pincad = get(get(language, "Buttons", Dict()), "PINSCadPath", "Click to select PINCAD")
    if pins_file == "Click to select PINCAD" || pins_file == default_pincad
        pins_file = ""
    end
    
    client = Gtk.bytestring(GAccessor.active_text(components.client["selectBox"]))
    if isempty(client)
        client = "UNKNOWN_CLIENT"
    end
    
    # Disable the generate button during processing
    set_gtk_property!(components.generate_button, :sensitive, false)
    
    # Process in background
    @spawn begin
        process_files(components, bom_file, pins_file, client, program_name, logger)
        
        # Re-enable button on the main thread
        Gtk.g_idle_add() do
            set_gtk_property!(components.generate_button, :sensitive, true)
            return false  # Stop idle handler
        end
    end
    
    return true
end

"""
    process_files(components, bom_file, pins_file, client, program_name, logger)
    
Process the input files and generate CSV output.
"""
function process_files(components, bom_file, pins_file, client, program_name, logger)
    XDebug.log_info(logger, "Starting file processing", XDebug.DATA_PROC)
    XDebug.log_info(logger, "BOM file: $bom_file", XDebug.DATA_PROC)
    XDebug.log_info(logger, "PINS file: $pins_file", XDebug.DATA_PROC)
    XDebug.log_info(logger, "Client: $client", XDebug.DATA_PROC)
    XDebug.log_info(logger, "Program name: $program_name", XDebug.DATA_PROC)
    
    # Initialize progress
    update_progress_bar(components, 0, "Starting processing...")
    
    # Parse BOM file
    update_progress_bar(components, 5, "Parsing BOM file...")
    bom_result = Parser.parse_file(bom_file, "BOM", logger)
    
    if !bom_result.success || isempty(bom_result.extracts)
        update_progress_bar(components, 0, "Error occurred", 0xFF5733)
        
        error_dialog = GtkMessageDialog(components.window, GConstants.GtkDialogFlags.MODAL,
                                       GConstants.GtkMessageType.ERROR, GConstants.GtkButtonsType.OK,
                                       "Process BOM data has failed.\nSelect another BOMSPLIT FILE")
        set_gtk_property!(error_dialog, :title, "ERROR")
        
        Gtk.g_idle_add() do
            run(error_dialog)
            destroy(error_dialog)
            return false
        end
        
        set_gtk_property!(components.bomsplit["input"], :text, 
                        get(get(language, "Buttons", Dict()), "BOMSplitPath", "Click to select BOMSPLIT"))
        XDebug.log_error(logger, "Process BOM data has failed", XDebug.DATA_PROC)
        return false
    end
    
    update_progress_bar(components, 25, "BOM parsed successfully")
    
    # Parse PINS file if available
    pins_result = nothing
    if !isempty(pins_file)
        update_progress_bar(components, 10, "Parsing PINS file...")
        pins_result = Parser.parse_file(pins_file, "PINS", logger)
        
        if !pins_result.success || isempty(pins_result.extracts)
            set_gtk_property!(components.pincad["input"], :text, 
                            get(get(language, "Buttons", Dict()), "PINSCadPath", "Click to select PINCAD"))
            XDebug.log_warning(logger, "Process PINS data has failed", XDebug.DATA_PROC)
            
            confirm_dialog = GtkMessageDialog(components.window, GConstants.GtkDialogFlags.MODAL,
                                             GConstants.GtkMessageType.QUESTION, GConstants.GtkButtonsType.YES_NO,
                                             "No pins on bottom!\nContinue?")
            set_gtk_property!(confirm_dialog, :title, "Information")
            
            continue_without_pins = true
            
            Gtk.g_idle_add() do
                response = run(confirm_dialog)
                destroy(confirm_dialog)
                continue_without_pins = (response == GConstants.GtkResponseType.YES)
                return false
            end
            
            # Wait for dialog response
            while ccall((:g_main_context_iteration, Gtk.GLib.libglib), Cint, (Ptr{Nothing}, Cint), C_NULL, true) != 0 end
            
            if !continue_without_pins
                update_progress_bar(components, 0, "Generate declined", 0xFF5733)
                return false
            else
                update_progress_bar(components, 30, "Continuing without PINS", 0xB4BF00)
            end
        else
            update_progress_bar(components, 30, "PINS parsed successfully")
        end
    end
    
    # Generate CSV files
    update_progress_bar(components, 40, "Generating CSV files...")
    
    # Progress callback for CSV generation
    progress_callback = (progress, message) -> begin
        update_progress_bar(components, 40 + progress * 0.6, message)
    end
    
    # Generate files
    csv_result = Converter.generate_csv(
        bom_result.extracts,
        pins_result !== nothing ? pins_result.extracts : nothing,
        client,
        program_name,
        bom_result.factor,
        progress_callback,
        logger
    )
    
    if !csv_result.success
        update_progress_bar(components, 0, "Error occurred", 0xFF5733)
        
        error_dialog = GtkMessageDialog(components.window, GConstants.GtkDialogFlags.MODAL,
                                       GConstants.GtkMessageType.ERROR, GConstants.GtkButtonsType.OK,
                                       "Unexpected error occurred\nConversion not fully happened\nUsing the converted file is NOT advised\n\nError: $(csv_result.message)")
        set_gtk_property!(error_dialog, :title, "CONVERSION FAIL")
        
        Gtk.g_idle_add() do
            run(error_dialog)
            destroy(error_dialog)
            return false
        end
        
        XDebug.log_error(logger, "CSV generation failed: $(csv_result.message)", XDebug.DATA_PROC)
        return false
    end
    
    # Complete progress
    update_progress_bar(components, 100, "Processing completed", 0x097969)
    
    # Play completion sound
    UIAnimations.play_sound("complete")
    
    XDebug.log_info(logger, "Processing completed successfully", XDebug.DATA_PROC)
    
    # Show success message
    success_dialog = GtkMessageDialog(components.window, GConstants.GtkDialogFlags.MODAL,
                                     GConstants.GtkMessageType.INFO, GConstants.GtkButtonsType.OK,
                                     csv_result.message)
    set_gtk_property!(success_dialog, :title, "Conversion Complete")
    
    Gtk.g_idle_add() do
        run(success_dialog)
        destroy(success_dialog)
        return false
    end
    
    return true
end

"""
    update_progress_bar(components, progress, message="Processing...", color=nothing)
    
Update the progress bar and its label.
"""
function update_progress_bar(components, progress, message="Processing...", color=nothing)
    Gtk.g_idle_add() do
        # Update progress bar
        pb = components.progress_bar
        set_gtk_property!(pb, :fraction, progress / 100.0)
        
        # Update progress color - GTK3 approach
        if color !== nothing
            # Convert hex color to RGB tuple
            r = ((color >> 16) & 0xFF) / 255.0
            g = ((color >> 8) & 0xFF) / 255.0
            b = (color & 0xFF) / 255.0
            
            # Create CSS for this color
            css_provider = GtkCssProvider()
            css_data = """
            progressbar progress {
                background-color: rgb($(r*100)%, $(g*100)%, $(b*100)%);
            }
            """
            
            # Apply to screen
            sc = Gtk.GdkScreen()
            push!(sc, css_provider, 800)  # Higher priority than default
        end
        
        # Update label
        set_gtk_property!(components.progress_label, :label, "$(message) ($(Int(round(progress)))%)")
        
        return false  # Stop idle handler after execution
    end
end

"""
    handle_window_close(components, config, logger)
    
Handle the window close event, saving configuration.
"""
function handle_window_close(components, config, logger)
    XDebug.log_info(logger, "Window close event", XDebug.UI)
    
    # Save current configuration
    config["Last"] = Dict(
        "OptionClient" => Gtk.bytestring(GAccessor.active_text(components.client["selectBox"])),
        "BOMSplitPath" => get_gtk_property(components.bomsplit["input"], :text, String),
        "PINSCadPath" => get_gtk_property(components.pincad["input"], :text, String),
        "ProgramEntry" => get_gtk_property(components.program["input"], :text, String)
    )
    
    # Save client list
    client_names = String[]
    
    # Extract all client names
    combo_model = GAccessor.model(components.client["selectBox"])
    iter = Gtk.GtkTreeIter()
    valid = Gtk.GLib.convertible_to_boolean(ccall((:gtk_tree_model_get_iter_first, Gtk.libgtk), Cint, 
                                                 (Ptr{GObject}, Ptr{GtkTreeIter}), combo_model, Ref(iter)))
    
    while valid
        val = Gtk.bytestring(GAccessor.value(combo_model, iter, 0))
        push!(client_names, val)
        valid = Gtk.GLib.convertible_to_boolean(ccall((:gtk_tree_model_iter_next, Gtk.libgtk), Cint, 
                                                     (Ptr{GObject}, Ptr{GtkTreeIter}), combo_model, Ref(iter)))
    end
    
    config["Clients"] = join(client_names, ",")
    
    # Save config to file
    XDebug.log_info(logger, "Saving configuration to config.ini", XDebug.CONFIG)
    if !Config.save_config(config)
        error_dialog = GtkMessageDialog(components.window, GConstants.GtkDialogFlags.MODAL,
                                        GConstants.GtkMessageType.ERROR, GConstants.GtkButtonsType.OK,
                                        "Failed to save configuration")
        set_gtk_property!(error_dialog, :title, "ERROR")
        
        run(error_dialog)
        destroy(error_dialog)
    end
    
    XDebug.log_info(logger, "Configuration saved", XDebug.CONFIG)
    
    # Flush logs before exit
    XDebug.flush_logs(logger)
    
    return false  # Allow window to close
end

end # module