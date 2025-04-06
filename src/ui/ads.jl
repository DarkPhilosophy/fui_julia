module UIAds

using Gtk
using Gtk.GLib
using ..XDebug
using ..UnicodeForge

export create_ads_component, start_ads_animation, stop_ads_animation

println("UIAds module loading...")

# Constants
const DEFAULT_INTERVAL = 600  # milliseconds
const DEFAULT_SPACES = 120
const DEFAULT_SKIP_STEP = 5

# Animation state
mutable struct AnimationState
    running::Bool
    timer_id::Int
    lines::Vector{String}
    current_line::Int
    current_position::Int
    label_width::Int
    interval::Int
    spaces::Int
    skip_step::Int
    
    AnimationState() = new(false, 0, String[], 1, 0, 0, DEFAULT_INTERVAL, DEFAULT_SPACES, DEFAULT_SKIP_STEP)
end

"""
    create_ads_component()

Create an ads component with a scrolling text label.
"""
function create_ads_component()
    # Create container
    container = GtkBox(:v)
    set_gtk_property!(container, :visible, true)
    set_gtk_property!(container, :margin_start, 10)
    set_gtk_property!(container, :margin_end, 10)
    set_gtk_property!(container, :margin_top, 5)
    set_gtk_property!(container, :margin_bottom, 5)
    
    # Create label
    label = GtkLabel("")
    set_gtk_property!(label, :halign, Gtk.GtkAlign.START)
    set_gtk_property!(label, :valign, Gtk.GtkAlign.CENTER)
    set_gtk_property!(label, :hexpand, true)
    set_gtk_property!(label, :visible, true)
    
    # Add widgets to container
    push!(container, label)
    
    # Create animation state
    state = AnimationState()
    
    return Dict{String, Any}(
        "container" => container,
        "label" => label,
        "state" => state
    )
end

"""
    load_ads_content(links::Vector{String}, logger::XDebug.Logger)

Load content from multiple files for the ads component.
"""
function load_ads_content(links::Vector{String}, logger::XDebug.Logger)
    all_lines = String[]
    
    for (idx, link) in enumerate(links)
        XDebug.log_info(logger, "Loading ads file: $link", XDebug.DATA_PROC)
        
        try
            # Check if the file exists
            if !isfile(link)
                XDebug.log_warning(logger, "Ads file not found: $link", XDebug.ERRORS)
                continue
            end
            
            # Read the file
            lines = readlines(link)
            XDebug.log_info(logger, "Loaded $(length(lines)) lines from $link", XDebug.DATA_PROC)
            
            # Add lines to the collection
            for line in lines
                if !isempty(strip(line))
                    push!(all_lines, line)
                end
            end
        catch e
            XDebug.log_error(logger, "Failed to load ads file: $link, error: $e", XDebug.ERRORS)
        end
    end
    
    # Remove duplicates
    unique_lines = unique(all_lines)
    XDebug.log_info(logger, "Total unique lines loaded: $(length(unique_lines))", XDebug.DATA_PROC)
    
    return unique_lines
end

"""
    start_ads_animation(ads_component, links::Vector{String}, logger::XDebug.Logger)

Start the ads animation with content from the specified links.
"""
function start_ads_animation(ads_component::Dict{String, Any}, links::Vector{String}, logger::XDebug.Logger)
    # Stop any existing animation
    stop_ads_animation(ads_component)
    
    # Load content
    lines = load_ads_content(links, logger)
    
    if isempty(lines)
        XDebug.log_error(logger, "No lines loaded for ads animation", XDebug.ERRORS)
        return
    end
    
    # Update animation state
    state = ads_component["state"]::AnimationState
    state.lines = lines
    state.current_line = 1
    state.current_position = 0
    
    # Get initial label width
    current_width = get_gtk_property(ads_component["label"], :width_request, Int)
    if current_width <= 0
        current_width = 80  # Default width
        XDebug.log_warning(logger, "Invalid initial label width, using default 80", XDebug.ERRORS)
    end
    state.label_width = current_width
    
    # Connect to resize event
    signal_connect(ads_component["label"], "size-allocate") do widget, allocation
        # Debounce resize events
        if state.timer_id != 0
            GLib.source_remove(state.timer_id)
        end
        
        state.timer_id = GLib.g_timeout_add(100) do
            new_width = get_gtk_property(widget, :width_request, Int)
            if new_width <= 0
                new_width = 80  # Default width
                XDebug.log_warning(logger, "Invalid label width on resize, using default 80", XDebug.ERRORS)
            end
            
            state.label_width = new_width
            state.timer_id = 0
            return false
        end
        
        return false
    end
    
    # Start animation
    state.running = true
    animate_ads(ads_component, logger)
    
    XDebug.log_info(logger, "Ads animation started", XDebug.DATA_PROC)
end

"""
    animate_ads(ads_component, logger::XDebug.Logger)

Animate the ads text.
"""
function animate_ads(ads_component::Dict{String, Any}, logger::XDebug.Logger)
    state = ads_component["state"]::AnimationState
    
    if !state.running
        return
    end
    
    # Get current line
    line_idx = state.current_line
    line = state.lines[line_idx]
    
    if isempty(strip(line))
        # Skip empty lines
        XDebug.log_info(logger, "Skipping empty line $line_idx", XDebug.DATA_PROC)
        state.current_line = (line_idx % length(state.lines)) + 1
        state.current_position = 0
        GLib.g_timeout_add(state.interval) do
            animate_ads(ads_component, logger)
            return false
        end
        return
    end
    
    # Calculate animation parameters
    label_width = state.label_width
    spaces = state.spaces
    skip_step = state.skip_step
    
    # Create display text with spaces
    display_text = line * " " ^ spaces
    
    # Calculate effective width (approximate)
    effective_width = length(display_text) * 8  # Approximate character width
    
    # Calculate steps
    total_steps = effective_width + label_width
    current_step = state.current_position
    
    # Update display
    if current_step >= total_steps
        # Move to next line
        state.current_line = (line_idx % length(state.lines)) + 1
        state.current_position = 0
        XDebug.log_info(logger, "Looping back to first line", XDebug.DATA_PROC)
    else
        # Calculate visible portion
        start_pos = current_step
        end_pos = min(start_pos + label_width, length(display_text))
        
        if start_pos >= length(display_text)
            # Reset to beginning
            start_pos = 0
            end_pos = min(label_width, length(display_text))
        end
        
        visible_text = display_text[start_pos+1:end_pos]
        
        # Update label
        set_gtk_property!(ads_component["label"], :label, visible_text)
        
        # Increment position
        state.current_position += skip_step
    end
    
    # Schedule next update
    GLib.g_timeout_add(state.interval) do
        animate_ads(ads_component, logger)
        return false
    end
end

"""
    stop_ads_animation(ads_component)

Stop the ads animation.
"""
function stop_ads_animation(ads_component::Dict{String, Any})
    state = ads_component["state"]::AnimationState
    
    if state.running
        state.running = false
        
        if state.timer_id != 0
            GLib.source_remove(state.timer_id)
            state.timer_id = 0
        end
    end
end

end # module 