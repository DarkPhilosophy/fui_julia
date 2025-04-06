module UIHandlers

using Gtk
using Gtk.GLib
using Logging
using JSON3
using Base.Threads: @spawn

# Add audio playback libraries
using PortAudio
using LibSndFile
using WAV
using FFMPEG

using ..CSVGenerator

# Import Gtk constants and types
import Gtk: GtkWidget, GtkContainer, GtkWindowLeaf, GtkLabel, GtkButton, GtkComboBoxText, GtkBox, GtkEntry
# Also import specific constants needed
import Gtk.GConstants: GtkDialogFlags, GtkMessageType, GtkButtonsType

# Import GtkResponseType
const GtkResponseType = Gtk.GtkResponseType

# Event debouncing machinery
mutable struct DebounceState
    last_execution::Float64
    timer_id::Int
end

const debounce_states = Dict{String, DebounceState}()

"""
    debounce(f::Function, id::String, delay::Float64=0.5)

Execute a function with debouncing to prevent rapid executions.
"""
function debounce(f::Function, id::String, delay::Float64=0.5)
    current_time = time()
    state = get!(debounce_states, id, DebounceState(0.0, 0))
    
    if current_time - state.last_execution >= delay
        state.last_execution = current_time
        f()
    else
        if state.timer_id != 0
            GLib.source_remove(state.timer_id)
        end
        state.timer_id = GLib.timeout_add(round(Int, delay * 1000)) do
            state.last_execution = time()
            state.timer_id = 0
            f()
            return false
        end
    end
end

println("UIHandlers module loading...")

"""
    setup_event_handlers(components::Dict{String, Any})

Set up event handlers for all UI components.
"""
function setup_event_handlers(components::Dict{String, Any})
    # Set up window close handler
    signal_connect(components["window"], :destroy) do widget
        Gtk.gtk_quit()
    end
    
    # Add window to each component dictionary
    components["bomsplit"]["window"] = components["window"]
    components["pincad"]["window"] = components["window"]
    components["client"]["window"] = components["window"]
    components["language"]["window"] = components["window"]
    
    # Set up file selection handlers
    setup_file_selection_handler(components["bomsplit"])
    setup_file_selection_handler(components["pincad"])
    
    # Set up client handlers
    setup_client_handler(components["client"])
    
    # Set up language handler
    setup_language_handler(components["language"])
    
    # Set up generate button handler
    signal_connect(components["generate"]["button"], :clicked) do widget
        handle_generate_click(components)
    end
    
    # Set up exit button handler
    signal_connect(components["exit"]["button"], :clicked) do widget
        Gtk.gtk_quit()
    end
    
    # Set up about label handler
    signal_connect(components["about"]["label"], :button_press_event) do widget, event
        open_email()
        return true
    end
    
    # Set up sounds for all buttons
    setup_button_sounds(components)
end

"""
    setup_file_selection_handler(component::Dict{String, Any})

Set up event handlers for a file selection component.
"""
function setup_file_selection_handler(component::Dict{String, Any})
    button = component["button"]
    input = component["input"]
    window = component["window"]
    
    signal_connect(button, "clicked") do widget
        dialog = GtkFileChooserDialog("Pick a file", window, GtkFileChooserAction.OPEN, 
            (("_Cancel", GtkResponseType.CANCEL),
             ("_Open", GtkResponseType.ACCEPT)))
        
        if run(dialog) == GtkResponseType.ACCEPT
            chooser = GtkFileChooser(dialog)
            filename = Gtk.GAccessor.filename(chooser)
            if filename !== nothing
                set_gtk_property!(input, :text, unsafe_string(filename))
            end
        end
        destroy(dialog)
    end
    
    # Enable drag and drop
    signal_connect(input, "drag-data-received") do widget, context, x, y, data, info, time
        uris = unsafe_string(data)
        if !isempty(uris)
            # Extract filename from URI
            filename = replace(uris, "file:///" => "")
            set_gtk_property!(input, :text, filename)
        end
        Gtk.drag_finish(context, true, false, time)
    end
end

"""
    setup_client_handler(component::Dict{String, Any})

Set up event handlers for the client component.
"""
function setup_client_handler(component::Dict{String, Any})
    combo = component["combo"]
    entry = component["entry"]
    add_button = component["add_button"]
    delete_button = component["delete_button"]
    
    # Load clients from config.ini (Corrected Format)
    function load_clients()
        config_file = joinpath("data", "config.ini")
        if isfile(config_file)
            config_lines = readlines(config_file)
            for line in config_lines
                # Find the line starting with Clients=
                if startswith(strip(line), "Clients=")
                    # Extract the array string part: ["GEC", ...]
                    clients_str = strip(split(line, '=')[2])
                    try
                        # Parse the JSON-like array string
                        clients = JSON3.read(clients_str, Vector{String})
                        return clients
                    catch e
                        @error "Failed to parse Clients line in config.ini: \$clients_str" exception=(e, catch_backtrace())
                        return String[] # Return empty on parsing error
                    end
                end
            end
            # If Clients= line not found
            @warn "Clients= line not found in config.ini"
            return String[]
        end
        @warn "config.ini not found at \$config_file"
        return String[] # Return empty if file doesn't exist
    end
    
    # Save clients to config.ini (Corrected Format)
    function save_clients(clients::Vector{String})
        config_file = joinpath("data", "config.ini")
        existing_lines = String[]
        if isfile(config_file)
            existing_lines = readlines(config_file)
        else
             @warn "config.ini not found for saving, creating new one."
             mkpath(dirname(config_file)) # Ensure directory exists
        end
        
        new_config_lines = String[]
        # Keep all lines except the old Clients= line
        for line in existing_lines
            if !startswith(strip(line), "Clients=")
                push!(new_config_lines, line)
            end
        end
        
        # Format the new Clients line using JSON3 for proper quoting/escaping
        clients_str = JSON3.write(clients)
        push!(new_config_lines, "Clients=$clients_str")
        
        try
            # Write the modified lines back
            write(config_file, join(new_config_lines, "\n"))
        catch e
            @error "Failed to save clients to config.ini" exception=(e, catch_backtrace())
        end
    end
    
    # Initialize combo box with clients
    function update_combo_box()
        clients = load_clients()
        remove_all(combo)
        for client in clients
            push!(combo, client)
        end
    end
    
    # Add new client
    signal_connect(add_button, :clicked) do widget
        new_client = get_gtk_property(entry, :text, String)
        @info "Add button clicked. Entry text: '$new_client'"
        if !isempty(new_client)
            clients = load_clients()
            if !(new_client in clients)
                @info "Client '$new_client' is new. Adding..."
                push!(clients, new_client)
                save_clients(clients)
                update_combo_box() # This reloads and repopulates
                # Find the new index AFTER update_combo_box to select it
                # update_combo_box reloads, so we need the latest list again
                clients_after_add = load_clients() 
                new_idx = findfirst(==(new_client), clients_after_add)
                if new_idx !== nothing
                    set_gtk_property!(combo, :active, new_idx - 1) 
                    @info "Set active index to $(new_idx - 1) after adding."
                else
                     @warn "Added client '$new_client' but couldn't find index to select it."
                end
                set_gtk_property!(entry, :text, "")  # Clear entry after adding
            else
                # Client already exists, just select it
                @info "Client '$new_client' already exists. Selecting..."
                existing_idx = findfirst(==(new_client), clients)
                if existing_idx !== nothing
                    set_gtk_property!(combo, :active, existing_idx - 1)
                    @info "Set active index to $(existing_idx - 1) for existing client."
                else
                    @warn "Client '$new_client' exists but couldn't find index to select."
                     # Maybe refresh UI as a fallback?
                     update_combo_box()
                end
            end
        else
             @warn "Add button clicked with empty entry."
        end
    end
    
    # Delete selected client (Refactored Flow)
    signal_connect(delete_button, :clicked) do widget
        active_idx = get_gtk_property(combo, :active, Int)
        @info "Delete button clicked. Active index: $active_idx"
        
        if active_idx < 0
            @warn "No client selected for deletion."
            return # Nothing selected
        end

        # Load clients ONCE
        clients = load_clients()
        @info "Loaded clients for deletion: $clients"
        
        # Bounds check against the loaded list
        if active_idx >= length(clients)
            @error "Selected index ($active_idx) is out of bounds for loaded clients (length: $(length(clients))). Refreshing UI."
            update_combo_box() # Refresh UI to be safe
            return
        end

        # Get the client name using the validated index
        client_to_delete = clients[active_idx + 1] # Use index (0-based -> 1-based)
        @info "Client to delete: '$client_to_delete' at index $active_idx"
        
        if client_to_delete === nothing || isempty(client_to_delete)
            @error "Failed to get client name at index $active_idx, even after bounds check."
            return
        end

        # Confirmation Dialog
        @info "Showing delete confirmation dialog for '$client_to_delete'"
        dialog = GtkMessageDialog(
            component["window"],
            GtkDialogFlags.DESTROY_WITH_PARENT | GtkDialogFlags.MODAL, # Use direct imported name
            GtkMessageType.QUESTION, # Use direct imported name
            GtkButtonsType.YES_NO, # Use direct imported name
            "Are you sure you want to delete client '$client_to_delete'?"
        )
        
        response = run(dialog)
        destroy(dialog) # Destroy dialog regardless of response
        @info "Delete confirmation response: $response"

        if response == GtkResponseType.YES
            @info "Deletion confirmed for '$client_to_delete'. Filtering list..."
            # Filter the EXISTING clients list
            filter!(c -> c != client_to_delete, clients)
            @info "Filtered list: $clients"
            
            # Save the modified list
            @info "Saving filtered list..."
            save_clients(clients)
            
            # Update the UI (reloads from file implicitly)
            @info "Updating combo box..."
            update_combo_box()
            
            # Try to set a reasonable active index AFTER update
            new_count = length(clients) 
            @info "Setting active index after delete. New count: $new_count"
            if new_count > 0
                # Select the new last item (index is count - 1)
                set_gtk_property!(combo, :active, new_count - 1)
                @info "Set active index to $(new_count - 1)"
            else
                # List is empty
                set_gtk_property!(combo, :active, -1)
                @info "Set active index to -1 (empty list)"
            end
        else
             @info "Deletion cancelled for '$client_to_delete'"
        end
    end
    
    # Initial load
    update_combo_box()
end

function info_dialog(parent::GtkWindowLeaf, message::String)
    dialog = GtkMessageDialog(parent, GtkDialogFlags.MODAL, GtkMessageType.INFO, GtkButtonsType.OK, message) # Use direct imported names
    run(dialog)
    destroy(dialog)
end

"""
    load_language_data(lang_code::String)

Load language data for the given code, merging with defaults for missing keys/files.
Returns a dictionary with language strings.
"""
function load_language_data(lang_code::String)
    default_lang_code = "en"
    default_lang_file = joinpath("assets", "lang", "$(default_lang_code).json")
    target_lang_file = joinpath("assets", "lang", "$(lang_code).json")

    mkpath(dirname(target_lang_file))

    # Define default English data structure (using NEW shorter keys)
    default_data = Dict{String, Any}( 
        "Labels" => Dict{String, String}(
            "BOMSplitFile" => "BOM Split File",
            "PINSCadFile" => "PINS File",
            "ProgramName" => "Program Name",
            "Client" => "Client:",              
            "Language" => "Language:"
        ),
        "Buttons" => Dict{String, String}(
            "Add" => "Add",
            "Del" => "Delete",
            "Generate" => "GENERATE .CAD/CSV",
            "Exit" => "Exit"
        ),
        "Placeholders" => Dict{String, String}(
            "NewClientEntry" => "New client name"
        )
    )

    # Load actual defaults from en.json if possible
    if isfile(default_lang_file)
        try 
           loaded_defaults_any = JSON3.read(read(default_lang_file, String), Dict{String, Any})
           # Manually merge loaded defaults into our hardcoded structure
           for section_key in keys(default_data)
               if haskey(loaded_defaults_any, section_key) && isa(loaded_defaults_any[section_key], Dict)
                  default_section = get(default_data, section_key, Dict{String, String}())
                  loaded_section_any = get(loaded_defaults_any, section_key, Dict())
                  
                  # Filter loaded section to ensure String values before merging
                  loaded_section_str = Dict{String, String}()
                  for (k, v) in loaded_section_any
                      if isa(v, String)
                          loaded_section_str[k] = v
                      end
                  end

                  # Merge filtered loaded values into default section
                  merge!(default_section, loaded_section_str) 
               end
           end
        catch e
            @warn "Failed to read or merge default language file ($(default_lang_file)). Using hardcoded defaults." exception=e
        end
    else 
         @warn "Default language file missing ($(default_lang_file)). Creating with defaults."
         try
            # Write the hardcoded defaults (with updated keys) to the file
            write(default_lang_file, JSON3.write(default_data))
         catch e
            @error "Failed to write default language file!" exception=(e, catch_backtrace())
         end
    end

    # If we're requesting the default language, return the merged default data
    if lang_code == default_lang_code
        return default_data
    end

    # For non-default languages, just load the target file as is (without merging defaults)
    # This will show errors for missing keys instead of silently falling back to defaults
    target_data = Dict{String, Any}()
    if isfile(target_lang_file)
        try
            target_data = JSON3.read(read(target_lang_file, String), Dict{String, Any})
            @info "Loaded language $(lang_code) with sections: $(keys(target_data))"
        catch e
            @error "Failed to read target language file ($(target_lang_file))." exception=(e, catch_backtrace())
        end
    else
        @warn "Target language file missing ($(target_lang_file))."
    end

    # Ensure we have the expected structure
    for section_key in ["Labels", "Buttons", "Placeholders"]
        if !haskey(target_data, section_key)
            target_data[section_key] = Dict{String, String}()
        end
    end

    # Return the target data (with missing sections but NOT merged with defaults)
    # This allows {Parse: "KeyName" = ERROR} to show for missing keys
    return target_data
end

"""
    setup_language_handler(component::Dict{String, Any})

Set up event handlers for the language selector.
"""
function setup_language_handler(component::Dict{String, Any})
    combo = component["combo"]
    flag = component["flag"]
    window = component["window"] # Get window reference
    
    # Map known language codes to flag image files
    lang_to_flag = Dict(
        "en" => "assets/icon/united-states.png",
        "ro" => "assets/icon/romania.png",
        "broken" => "assets/icon/planet-earth.png" # Use planet for unknown/test languages
    )

    function update_flag_icon(active_id::String)
        icon_path = get(lang_to_flag, active_id, "assets/icon/planet-earth.png") # Default to earth for unknown languages
        if isfile(icon_path)
            set_gtk_property!(flag, :file, icon_path)
        else
            @warn "Flag image not found: $icon_path"
            # Fallback to icon name if file doesn't exist
            set_gtk_property!(flag, :icon_name, "image-missing")
        end
    end

    signal_connect(combo, :changed) do widget
        active_id = get_gtk_property(combo, :active_id, String)
        if active_id !== nothing && !isempty(active_id)
            # Update flag icon based on new selection
            update_flag_icon(active_id)
            
            # Load language data using the robust function
            lang_data = load_language_data(active_id)
            
            # Update UI
            update_ui_with_language(window, lang_data)
            
            # Save selected language setting
            save_language_to_config(active_id)
        else
            @warn "Language combo box changed, but active_id is invalid."
        end
    end
    
    # Initial UI update and flag setting on startup
    initial_active_id = get_gtk_property(combo, :active_id, String)
    if initial_active_id !== nothing && !isempty(initial_active_id)
        initial_lang_data = load_language_data(initial_active_id)
        update_ui_with_language(window, initial_lang_data)
        # Set initial flag based on loaded language
        update_flag_icon(initial_active_id)
    else
         @warn "Could not determine initial language. UI might not be translated."
         # Maybe set a default flag?
         set_gtk_property!(flag, :icon_name, "image-missing")
    end
end

function update_ui_with_language(window::GtkWindowLeaf, lang_data::Dict{String, Any})
    @info "Updating UI with language (safe approach)..."
    
    # Direct update of known specific widgets by their names
    # This is safer than traversing the widget hierarchy, which can lead to crashes
    
    # Update labels
    labels_data = get(lang_data, "Labels", Dict{String, String}())
    update_known_widget(window, "BOMSplitFile", labels_data, :label)
    update_known_widget(window, "PINSCadFile", labels_data, :label)
    update_known_widget(window, "ProgramName", labels_data, :label)
    update_known_widget(window, "Client", labels_data, :label)
    update_known_widget(window, "Language", labels_data, :label)
    
    # Update buttons
    buttons_data = get(lang_data, "Buttons", Dict{String, String}())
    update_known_widget(window, "Generate", buttons_data, :label)
    update_known_widget(window, "Exit", buttons_data, :label)
    
    # Update placeholders
    placeholders_data = get(lang_data, "Placeholders", Dict{String, String}())
    update_known_widget(window, "NewClientEntry", placeholders_data, :placeholder_text)
    
    # Special handling for Add/Del buttons which are in client_component's button_box
    # We'll try to directly find these widgets by name
    direct_update_client_buttons(window, buttons_data)
    
    @info "UI language update complete."
end

# Helper function to update a specific widget if it can be found
# Updated to accept Dict{String, Any} since that's what we get from JSON
function update_known_widget(window::GtkWindowLeaf, widget_name::String, data::Union{Dict{String, String}, Dict{String, Any}}, property::Symbol)
    # Try to find a widget with the specified name anywhere in the window
    try
        # Use a simple approach: look at all widgets in the main container
        main_container = window[1]
        for container in main_container
            if isa(container, GtkBox)
                for widget in container
                    try
                        name = get_gtk_property(widget, :name, String)
                        if name == widget_name
                            current_value = ""
                            try
                                current_value = get_gtk_property(widget, property, String)
                            catch; end
                            
                            # Handle Dict{String, Any} by converting to String
                            new_value = ""
                            if haskey(data, widget_name)
                                val = data[widget_name]
                                if isa(val, String)
                                    new_value = val
                                else
                                    new_value = "{Parse: \"$(widget_name)\" = TYPE ERROR}"
                                end
                            else
                                new_value = "{Parse: \"$(widget_name)\" = ERROR}"
                            end
                            
                            @debug "Updating widget '$(widget_name)': '$(current_value)' -> '$(new_value)'"
                            set_gtk_property!(widget, property, new_value)
                            return true
                        end
                    catch; end
                end
            end
        end
    catch e
        @debug "Non-critical error searching for widget '$widget_name': $e"
    end
    return false
end

# Special function to try to find and update client buttons
function direct_update_client_buttons(window::GtkWindowLeaf, buttons_data::Union{Dict{String, String}, Dict{String, Any}})
    try
        add_updated = false
        del_updated = false
        
        # Check all boxes for buttons named "Add" or "Del"
        main_container = window[1]
        for container in main_container
            if isa(container, GtkBox)
                for widget in container
                    if isa(widget, GtkBox)  # This could be the button_box
                        for button in widget
                            if isa(button, GtkButton)
                                try
                                    name = get_gtk_property(button, :name, String)
                                    if name == "Add" && !add_updated
                                        new_text = ""
                                        if haskey(buttons_data, "Add")
                                            val = buttons_data["Add"]
                                            if isa(val, String)
                                                new_text = val
                                            else
                                                new_text = "{Parse: \"Add\" = TYPE ERROR}"
                                            end
                                        else
                                            new_text = "{Parse: \"Add\" = ERROR}"
                                        end
                                        
                                        @debug "Updating Add button: -> '$(new_text)'"
                                        set_gtk_property!(button, :label, new_text)
                                        add_updated = true
                                    elseif name == "Del" && !del_updated
                                        new_text = ""
                                        if haskey(buttons_data, "Del")
                                            val = buttons_data["Del"]
                                            if isa(val, String)
                                                new_text = val
                                            else
                                                new_text = "{Parse: \"Del\" = TYPE ERROR}"
                                            end
                                        else
                                            new_text = "{Parse: \"Del\" = ERROR}"
                                        end
                                        
                                        @debug "Updating Del button: -> '$(new_text)'"
                                        set_gtk_property!(button, :label, new_text)
                                        del_updated = true
                                    end
                                catch; end
                            end
                        end
                    end
                end
            end
        end
    catch e
        @debug "Non-critical error updating client buttons: $e"
    end
end

function save_language_to_config(lang_code::String)
    config_file = "config.ini"
    if isfile(config_file)
        lines = readlines(config_file)
        open(config_file, "w") do io
            for line in lines
                if startswith(line, "Language=")
                    println(io, "Language=\"assets/lang/$lang_code.json\"")
                else
                    println(io, line)
                end
            end
        end
    end
end

"""
    handle_generate_click(components::Dict{String, Any})

Handle click event for the generate button.
"""
function handle_generate_click(components::Dict{String, Any})
    # Get file paths
    bomsplit_path = get_gtk_property(components["bomsplit"]["input"], :text, String)
    pincad_path = get_gtk_property(components["pincad"]["input"], :text, String)
    program_name = get_gtk_property(components["program"]["input"], :text, String)
    
    # Get selected client
    client = Gtk.GAccessor.active_text(components["client"]["combo"])
    
    # Validate inputs
    if isempty(bomsplit_path) || isempty(program_name) || client == nothing
        dialog = GtkMessageDialog(components["window"], GtkDialogFlags.MODAL, GtkMessageType.ERROR, GtkButtonsType.OK, "Please fill in all required fields") # Use direct imported names
        run(dialog)
        destroy(dialog)
        return
    end
    
    # Set cursor to wait
    window = components["window"]
    set_gtk_property!(window, :cursor, Gtk.GdkCursor(Gtk.GdkCursorType.WATCH))
    
    try
        # Generate CSV files
        success_status = CSVGenerator.generate_csv(components)
        
        # Show success dialog
        message = if success_status["top"] && success_status["bot"]
            "Generation completed successfully!"
        elseif success_status["top"]
            "Generation completed with TOP files only."
        else
            "Generation failed."
        end
        
        dialog = GtkMessageDialog(window, GtkDialogFlags.MODAL, GtkMessageType.INFO, GtkButtonsType.OK, message) # Use direct imported names
        run(dialog)
        destroy(dialog)
        
    catch e
        # Show error dialog
        error_dialog = GtkMessageDialog(window, GtkDialogFlags.MODAL, GtkMessageType.ERROR, GtkButtonsType.OK, "Error during generation: $(sprint(showerror, e))") # Use direct imported names
            run(error_dialog)
            destroy(error_dialog)
        
    finally
        # Reset cursor
        set_gtk_property!(window, :cursor, nothing)
    end
end

"""
    open_email()

Open the default email client with a pre-filled email.
"""
function open_email()
    email = "adalbertalexandru.ungureanu@flex.com"
    subject = "Hey Alex I got a question!"
    
    # URL encode the subject
    subject = replace(subject, " " => "%20")
    
    # Create the mailto URL
    url = "mailto:$email?subject=$subject&body="
    
    # Open the default email client
    if Sys.iswindows()
        run(`cmd /c start $url`)
    elseif Sys.isapple()
        run(`open $url`)
    else
        run(`xdg-open $url`)
    end
end

"""
    remove_all(combo::GtkComboBoxText)

Remove all items from a combo box.
"""
function remove_all(combo::GtkComboBoxText)
    # Loop as long as there's an active item (index >= 0), removing the first item (index 0) each time.
    # remove shifts indices, so removing index 0 repeatedly clears the list.
    # CORRECTED: remove is a method on the object, not in Gtk module.
    while get_gtk_property(combo, :active, Int) != -1
        remove(combo, 0) # Removed Gtk. prefix
    end
    # Ensure the combo box visually reflects no selection
    set_gtk_property!(combo, :active, -1)
end

"""
    play_sound(sound_file::String)

Attempt to play a sound effect file using FFMPEG, or fallback to a log message.
"""
function play_sound(sound_file::String)
    if !isfile(sound_file)
        @warn "Sound file not found: $sound_file"
        return
    end
    
    # Log sound for now
    @info "Playing sound: $sound_file"
    
    # Play sound in background thread to avoid blocking UI
    @spawn begin
        try
            # Convert MP3 to WAV using FFMPEG
            if endswith(lowercase(sound_file), ".mp3")
                temp_dir = joinpath(dirname(@__FILE__), "temp")
                isdir(temp_dir) || mkdir(temp_dir)
                play_id = string(hash(string(sound_file, time())), base=16)[1:8]
                temp_wav = joinpath(temp_dir, "sound_$(play_id).wav")
                FFMPEG.ffmpeg_exe(`-i $sound_file -acodec pcm_s16le $temp_wav -y`)
                
                # On Windows, use PowerShell to play the WAV file
                if Sys.iswindows()
                    run(`powershell -c "(New-Object System.Media.SoundPlayer '$temp_wav').PlaySync()"`)
                    isfile(temp_wav) && rm(temp_wav)
                elseif Sys.isapple()
                    run(`afplay $sound_file`)
                else
                    # Try various Linux players
                    for player in ["paplay", "aplay", "play"]
                        try
                            run(`which $player`, wait=true)
                            run(`$player $sound_file`)
                            break
                        catch
                            continue
                        end
                    end
                end
            else
                # For WAV files, use directly with system commands
                if Sys.iswindows()
                    run(`powershell -c "(New-Object System.Media.SoundPlayer '$sound_file').PlaySync()"`)
                elseif Sys.isapple()
                    run(`afplay $sound_file`)
                else
                    # Try various Linux players
                    for player in ["paplay", "aplay", "play"]
                        try
                            run(`which $player`, wait=true)
                            run(`$player $sound_file`)
                            break
                        catch
                            continue
                        end
                    end
                end
            end
        catch e
            @warn "Failed to play sound: $e"
        end
    end
end

"""
    setup_button_sounds()

Add click sounds to all buttons.
"""
function setup_button_sounds(components::Dict{String, Any})
    click_sound = joinpath("assets", "audio", "ui-minimal-click.mp3")
    
    # Add sound to Generate button
    add_click_sound(components["generate"]["button"], click_sound)
    
    # Add sound to Exit button
    add_click_sound(components["exit"]["button"], click_sound)
    
    # Add sound to file selection buttons
    add_click_sound(components["bomsplit"]["button"], click_sound)
    add_click_sound(components["pincad"]["button"], click_sound)
    
    # Add sound to client buttons
    add_click_sound(components["client"]["add_button"], click_sound)
    add_click_sound(components["client"]["delete_button"], click_sound)
end

"""
    add_click_sound(button::GtkButton, sound_file::String)

Add a click sound to a button.
"""
function add_click_sound(button::GtkButton, sound_file::String)
    signal_connect(button, :clicked) do widget
        play_sound(sound_file)
        false # Continue signal propagation
    end
end

end # module UIHandlers