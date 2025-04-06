module UIAnimations

export fade_in, fade_out, pulse, play_sound, stop_sound, flash, slide_in, highlight_widget, animate_progress_bar, animate_text

println("UIAnimations module loading...")

using Gtk
println("UIAnimations: Gtk imported")

# Sound system configuration - use a simple in-memory system
const AUDIO_ENABLED = Ref(true)
const SOUND_CACHE = Dict{String, Any}()
const ANIMATION_ENABLED = Ref(true)

# Print initialization message
println("UIAnimations module initialized")
println("UIAnimations: AUDIO_ENABLED = $(AUDIO_ENABLED[])")
println("UIAnimations: ANIMATION_ENABLED = $(ANIMATION_ENABLED[])")

"""
    direct_timeout_add(interval_ms::Integer, callback::Function)

Direct replacement for Gtk.GLib.timeout_add using ccall.
"""
function direct_timeout_add(interval_ms::Integer, callback::Function)
    # Create a callback wrapper that will be called by C
    cb_ptr = @cfunction(
        (data) -> begin
            result = false
            try
                result = callback()::Bool
            catch e
                println("Error in timer callback: $e")
            end
            result::Bool
        end,
        Cint, (Ptr{Nothing},)
    )
    
    # Call the GLib function directly
    return ccall(
        (:g_timeout_add, Gtk.libglib), 
        Cuint, 
        (Cuint, Ptr{Nothing}, Ptr{Nothing}),
        Cuint(interval_ms), cb_ptr, C_NULL
    )
end

"""
    simple_timeout(interval_seconds::Number, callback::Function)

Create a simple timer using Base.Timer for maximum compatibility.
"""
function simple_timeout(interval_seconds::Number, callback::Function)
    # Create a timer
    timer = Timer(interval_seconds)
    
    # Add callback to wait and execute
    @async begin
        try
            while true
                wait(timer)
                result = callback()
                if result == false
                    close(timer)
                    break
                end
            end
        catch e
            if e isa EOFError
                # Timer was closed
            else
                println("Timer error: $e")
            end
        end
    end
    
    return timer
end

"""
    process_events()

Process all pending GTK events to ensure UI updates are displayed.
"""
function process_events()
    while ccall((:gtk_events_pending, Gtk.libgtk), Cint, ()) != 0
        ccall((:gtk_main_iteration, Gtk.libgtk), Cint, ())
    end
end

"""
    set_widget_opacity(widget, opacity::Float64)

Set widget opacity using direct GTK calls.
"""
function set_widget_opacity(widget, opacity::Float64)
    ccall((:gtk_widget_set_opacity, Gtk.libgtk), Cvoid, 
          (Ptr{Gtk.GObject}, Cdouble), widget, opacity)
end

"""
    set_widget_visibility(widget, visible::Bool)

Set widget visibility using direct GTK calls.
"""
function set_widget_visibility(widget, visible::Bool)
    ccall((:gtk_widget_set_visible, Gtk.libgtk), Cvoid, 
          (Ptr{Gtk.GObject}, Cint), widget, visible ? 1 : 0)
end

"""
    fade_in(widget, duration::Float64=0.5)

Animate a widget fading in from invisible to fully visible.
Uses direct GTK calls for maximum reliability.
"""
function fade_in(widget, duration::Float64=0.5)
    if !ANIMATION_ENABLED[]
        # Simple direct visibility if animations disabled
        set_widget_visibility(widget, true)
        set_widget_opacity(widget, 1.0)
        process_events()
        return nothing
    end

    # Check if widget is a window
    is_window = isa(widget, GtkWindowLeaf)

    # Set widget to be visible first
    set_widget_visibility(widget, true)
    
    process_events()
    
    # Graduated opacity animation with more steps for windows
    steps = is_window ? 5 : 10
    step_time = duration / steps
    
    for i in 1:steps
        # Calculate opacity for this step - start more visible for windows
        opacity = is_window ? 0.5 + (i / steps) * 0.5 : (i / steps)
        
        # Set the opacity
        set_widget_opacity(widget, opacity)
        
        # Force update after each step
        process_events()
        
        # Small delay between steps
        sleep(step_time)
    end
    
    # Ensure full opacity at the end
    set_widget_opacity(widget, 1.0)
    
    # For windows, present again at full opacity
    if is_window
        ccall((:gtk_window_present, Gtk.libgtk), Cvoid, (Ptr{Gtk.GObject},), widget)
    end
    
    # Final update
    process_events()
    
    return nothing
end

"""
    fade_out(widget, duration::Float64=0.5, remove::Bool=false)

Animate a widget fading out from visible to invisible.
"""
function fade_out(widget, duration::Float64=0.5, remove::Bool=false)
    if !ANIMATION_ENABLED[]
        # Simple direct visibility change if animations disabled
        set_widget_opacity(widget, 0.0)
        set_widget_visibility(widget, false)
        if remove
            parent = Gtk.get_gtk_property(widget, :parent, Gtk.GtkWidget)
            if parent !== nothing
                Gtk.G_.remove(parent, widget)
            end
        end
        process_events()
        return nothing
    end

    # Use direct GTK calls for better reliability
    set_widget_visibility(widget, true)
    set_widget_opacity(widget, 1.0)
    process_events()
    
    # Animation state
    current_opacity = Ref(1.0)
    
    # Number of steps in animation
    steps = 10
    step_time = duration / steps
    
    # For each step
    for i in 1:steps
        # Calculate new opacity
        new_opacity = 1.0 - (i / steps)
        set_widget_opacity(widget, new_opacity)
        process_events()
        sleep(step_time)
    end
    
    # Final state
    set_widget_opacity(widget, 0.0)
    
    if remove
        parent = Gtk.get_gtk_property(widget, :parent, Gtk.GtkWidget)
        if parent !== nothing
            Gtk.G_.remove(parent, widget)
        end
    else
        set_widget_visibility(widget, false)
    end
    
    process_events()
    return nothing
end

"""
    pulse(widget, color1::String, color2::String, duration::Float64=1.0, cycles::Int=1)

Create a pulsing animation between two colors for a widget.
"""
function pulse(widget, color1::String, color2::String, duration::Float64=1.0, cycles::Int=1)
    if !ANIMATION_ENABLED[]
        return nothing
    end

    # Store original color/style
    original_name = Gtk.get_gtk_property(widget, :name, String)
    
    # Create CSS provider
    css_provider = GtkCssProvider()
    css_data = """
    .pulse-animation-1 {
        background-color: $(color1);
    }
    
    .pulse-animation-2 {
        background-color: $(color2);
    }
    """
    
    # Apply CSS - direct method for maximum compatibility
    try
        ccall((:gtk_css_provider_load_from_data, Gtk.libgtk), Bool, 
              (Ptr{Gtk.GObject}, Ptr{UInt8}, Csize_t, Ptr{Nothing}), 
              css_provider, css_data, length(css_data), C_NULL)
        
        # Get style context and apply
        style = ccall((:gtk_widget_get_style_context, Gtk.libgtk), Ptr{Nothing}, 
                     (Ptr{Gtk.GObject},), widget)
                     
        ccall((:gtk_style_context_add_provider, Gtk.libgtk), Cvoid,
              (Ptr{Nothing}, Ptr{Gtk.GObject}, Cuint),
              style, css_provider, 600)  # 600 = GTK_STYLE_PROVIDER_PRIORITY_APPLICATION
    catch e
        # Just continue if this fails
        println("Could not apply pulse CSS: $e")
        return nothing
    end
    
    # Set initial class
    Gtk.set_gtk_property!(widget, :name, "pulse-animation-1")
    process_events()
    
    # For simple case with just one cycle, do it directly
    if cycles == 1
        sleep(duration / 2)
        Gtk.set_gtk_property!(widget, :name, "pulse-animation-2")
        process_events()
        sleep(duration / 2)
        Gtk.set_gtk_property!(widget, :name, original_name)
        process_events()
        return nothing
    end
    
    # For multiple cycles, use timer
    cycle_counter = Ref(0)
    is_color1 = Ref(true)
    
    # Define the timer callback
    function pulse_callback()
        if is_color1[]
            Gtk.set_gtk_property!(widget, :name, "pulse-animation-2")
        else
            Gtk.set_gtk_property!(widget, :name, "pulse-animation-1")
            cycle_counter[] += 1
            
            if cycle_counter[] >= cycles
                # Reset to original and stop
                Gtk.set_gtk_property!(widget, :name, original_name)
                return false
            end
        end
        
        is_color1[] = !is_color1[]
        return true
    end
    
    # Start timer
    timer = simple_timeout(duration / 2, pulse_callback)
    
    return timer
end

"""
    flash(widget, color::String="#FF5733", duration::Float64=0.3, cycles::Int=3)

Flash a widget for attention.
"""
function flash(widget, color::String="#FF5733", duration::Float64=0.3, cycles::Int=3)
    if !ANIMATION_ENABLED[]
        return nothing
    end

    return pulse(widget, color, "#FFFFFF", duration, cycles)
end

"""
    slide_in(widget, direction::Symbol=:right, duration::Float64=0.5)

Slide a widget in from the specified direction.
"""
function slide_in(widget, direction::Symbol=:right, duration::Float64=0.5)
    if !ANIMATION_ENABLED[]
        set_widget_visibility(widget, true)
        process_events()
        return nothing
    end

    # Get parent allocation
    parent = Gtk.get_gtk_property(widget, :parent, Gtk.GtkWidget)
    if parent === nothing
        # Can't animate without parent
        set_widget_visibility(widget, true)
        return nothing
    end
    
    # Get parent dimensions
    parent_alloc = Gtk.GdkRectangle(0, 0, 0, 0)
    ccall((:gtk_widget_get_allocation, Gtk.libgtk), Cvoid,
          (Ptr{Gtk.GObject}, Ptr{Gtk.GdkRectangle}), parent, Ref(parent_alloc))
    
    # Get widget dimensions
    widget_alloc = Gtk.GdkRectangle(0, 0, 0, 0)
    ccall((:gtk_widget_get_allocation, Gtk.libgtk), Cvoid,
          (Ptr{Gtk.GObject}, Ptr{Gtk.GdkRectangle}), widget, Ref(widget_alloc))
    
    # Calculate start position
    start_x = widget_alloc.x
    start_y = widget_alloc.y
    
    if direction == :right
        start_x = -widget_alloc.width
    elseif direction == :left
        start_x = parent_alloc.width
    elseif direction == :bottom
        start_y = -widget_alloc.height
    elseif direction == :top
        start_y = parent_alloc.height
    end
    
    # Set initial position
    ccall((:gtk_fixed_move, Gtk.libgtk), Cvoid,
          (Ptr{Gtk.GObject}, Ptr{Gtk.GObject}, Cint, Cint),
          parent, widget, start_x, start_y)
    
    # Make visible
    set_widget_visibility(widget, true)
    process_events()
    
    # Animate to target position
    steps = 10
    step_time = duration / steps
    
    for i in 1:steps
        # Calculate interpolated position
        progress = i / steps
        current_x = start_x + (widget_alloc.x - start_x) * progress
        current_y = start_y + (widget_alloc.y - start_y) * progress
        
        # Move widget
        ccall((:gtk_fixed_move, Gtk.libgtk), Cvoid,
              (Ptr{Gtk.GObject}, Ptr{Gtk.GObject}, Cint, Cint),
              parent, widget, round(Int, current_x), round(Int, current_y))
        
        process_events()
        sleep(step_time)
    end
    
    # Final position
    ccall((:gtk_fixed_move, Gtk.libgtk), Cvoid,
          (Ptr{Gtk.GObject}, Ptr{Gtk.GObject}, Cint, Cint),
          parent, widget, widget_alloc.x, widget_alloc.y)
    
    process_events()
    return nothing
end

"""
    highlight_widget(widget, color::String="#3D85C6", duration::Float64=1.0)

Temporarily highlight a widget with a colored border.
"""
function highlight_widget(widget, color::String="#3D85C6", duration::Float64=1.0)
    if !ANIMATION_ENABLED[]
        return nothing
    end

    # Store original CSS class
    original_name = Gtk.get_gtk_property(widget, :name, String)
    
    # Create CSS provider for highlight
    css_provider = GtkCssProvider()
    css_data = """
    .highlight-animation {
        border: 2px solid $(color);
        border-radius: 3px;
    }
    """
    
    # Apply CSS
    try
        ccall((:gtk_css_provider_load_from_data, Gtk.libgtk), Bool, 
              (Ptr{Gtk.GObject}, Ptr{UInt8}, Csize_t, Ptr{Nothing}), 
              css_provider, css_data, length(css_data), C_NULL)
        
        # Get style context and apply
        style = ccall((:gtk_widget_get_style_context, Gtk.libgtk), Ptr{Nothing}, 
                     (Ptr{Gtk.GObject},), widget)
                     
        ccall((:gtk_style_context_add_provider, Gtk.libgtk), Cvoid,
              (Ptr{Nothing}, Ptr{Gtk.GObject}, Cuint),
              style, css_provider, 600)
    catch e
        println("Could not apply highlight CSS: $e")
        return nothing
    end
    
    # Apply highlight class
    Gtk.set_gtk_property!(widget, :name, "highlight-animation")
    process_events()
    
    # Schedule timer to remove highlight
    @async begin
        sleep(duration)
        Gtk.set_gtk_property!(widget, :name, original_name)
        process_events()
    end
    
    return nothing
end

"""
    play_sound(name::String, volume::Float64=1.0)

Play a sound by name.
Currently a stub implementation that just logs the sound played.
"""
function play_sound(name::String, volume::Float64=1.0)
    if !AUDIO_ENABLED[]
        return nothing
    end
    
    # Log sound playback
    println("Playing sound: $name (volume: $volume)")
    
    # Cache the sound request
    SOUND_CACHE[name] = Dict("name" => name, "volume" => volume, "playing" => true)
    
    return SOUND_CACHE[name]
end

"""
    stop_sound(sound::Any)

Stop a currently playing sound.
"""
function stop_sound(sound::Any)
    if sound === nothing || !AUDIO_ENABLED[]
        return
    end
    
    if isa(sound, Dict) && haskey(sound, "name")
        println("Stopping sound: $(sound["name"])")
        sound["playing"] = false
    end
end

"""
    disable_animations()

Disable all animations for better performance or compatibility.
"""
function disable_animations()
    ANIMATION_ENABLED[] = false
end

"""
    enable_animations()

Enable all animations.
"""
function enable_animations()
    ANIMATION_ENABLED[] = true
end

"""
    disable_audio()

Disable all audio playback.
"""
function disable_audio()
    AUDIO_ENABLED[] = false
end

"""
    enable_audio()

Enable all audio playback.
"""
function enable_audio()
    AUDIO_ENABLED[] = true
end

"""
    animate_progress_bar(progress_bar::GtkProgressBar, target::Float64, duration::Float64=1.0)

Animate a progress bar to a target value over a duration.
"""
function animate_progress_bar(progress_bar::GtkProgressBar, target::Float64, duration::Float64=1.0)
    start_value = GAccessor.fraction(progress_bar)
    steps = 60  # 60 fps
    step_duration = duration / steps
    value_step = (target - start_value) / steps
    
    # Create animation task
    @async begin
        for i in 1:steps
            current = start_value + value_step * i
            GAccessor.fraction(progress_bar, current)
            sleep(step_duration)
        end
        # Ensure final value is exact
        GAccessor.fraction(progress_bar, target)
    end
end

"""
    animate_text(label::GtkLabel, text::String, interval::Float64=0.05)

Animate text appearing character by character.
"""
function animate_text(label::GtkLabel, text::String, interval::Float64=0.05)
    @async begin
        for i in 1:length(text)
            GAccessor.text(label, text[1:i])
            sleep(interval)
        end
    end
end

# Initialize module
function __init__()
    println("UIAnimations module initialized")
    ANIMATION_ENABLED[] = true
    AUDIO_ENABLED[] = true
end

end # module