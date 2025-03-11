module UIAnimations

export fade_in, fade_out, pulse, play_sound, stop_sound

using Gtk

# Sound system configuration - use a simple in-memory system
const AUDIO_ENABLED = Ref(true)
const SOUND_CACHE = Dict{String, Any}()

"""
    fade_in(widget, duration::Float64=0.5)

Animate a widget fading in from invisible to visible.

# Arguments
- `widget`: The widget to animate
- `duration::Float64`: Animation duration in seconds (default: 0.5)
"""
function fade_in(widget, duration::Float64=0.5)
    # Set initial opacity to 0
    set_gtk_property!(widget, :opacity, 0.0)
    set_gtk_property!(widget, :visible, true)
    
    # Create animation
    frames = 30
    interval = duration / frames
    opacity_step = 1.0 / frames
    
    # Animation timer
    timer_id = GLib.timeout_add(UInt32(interval * 1000)) do
        current_opacity = get_gtk_property(widget, :opacity, Float64)
        
        if current_opacity >= 1.0
            set_gtk_property!(widget, :opacity, 1.0)
            return false  # Stop timer
        end
        
        set_gtk_property!(widget, :opacity, min(current_opacity + opacity_step, 1.0))
        return true  # Continue timer
    end
    
    return timer_id
end

"""
    fade_out(widget, duration::Float64=0.5, remove::Bool=false)

Animate a widget fading out from visible to invisible.

# Arguments
- `widget`: The widget to animate
- `duration::Float64`: Animation duration in seconds (default: 0.5)
- `remove::Bool`: Whether to remove the widget after fading (default: false)
"""
function fade_out(widget, duration::Float64=0.5, remove::Bool=false)
    # Ensure widget is visible
    set_gtk_property!(widget, :visible, true)
    set_gtk_property!(widget, :opacity, 1.0)
    
    # Create animation
    frames = 30
    interval = duration / frames
    opacity_step = 1.0 / frames
    
    # Animation timer
    timer_id = GLib.timeout_add(UInt32(interval * 1000)) do
        current_opacity = get_gtk_property(widget, :opacity, Float64)
        
        if current_opacity <= 0.0
            set_gtk_property!(widget, :opacity, 0.0)
            set_gtk_property!(widget, :visible, false)
            
            if remove
                parent = get_gtk_property(widget, :parent, GtkWidget)
                if parent !== nothing
                    Gtk.G_.remove(parent, widget)
                end
            end
            
            return false  # Stop timer
        end
        
        set_gtk_property!(widget, :opacity, max(current_opacity - opacity_step, 0.0))
        return true  # Continue timer
    end
    
    return timer_id
end

"""
    pulse(widget, color1::String, color2::String, duration::Float64=1.0, cycles::Int=1)

Create a pulsing animation between two colors for a widget.

# Arguments
- `widget`: The widget to animate
- `color1::String`: Starting CSS color
- `color2::String`: Ending CSS color
- `duration::Float64`: Duration of one cycle in seconds (default: 1.0)
- `cycles::Int`: Number of cycles to run (default: 1, 0 for infinite)
"""
function pulse(widget, color1::String, color2::String, duration::Float64=1.0, cycles::Int=1)
    # Store original style to restore later
    original_style = widget.name
    
    # Create CSS provider with animation
    css_provider = GtkCssProvider()
    css_data = """
    .pulse-animation {
        background-color: $(color1);
    }
    
    .pulse-animation-alt {
        background-color: $(color2);
    }
    """
    
    # Apply CSS - for GTK3
    Gtk.G_.provider_load_from_data(css_provider, css_data, -1)
    
    # Get screen
    sc = Gtk.GdkScreen()
    push!(sc, css_provider, 700)  # High priority
    
    # Apply initial style
    GAccessor.name(widget, "pulse-animation")
    
    # Animation state and cycle counter
    state = Ref(false)
    cycle_count = Ref(0)
    
    # Animation timer
    timer_id = GLib.timeout_add(UInt32(duration * 1000)) do
        if state[]
            GAccessor.name(widget, "pulse-animation")
        else
            GAccessor.name(widget, "pulse-animation-alt")
        end
        
        state[] = !state[]
        
        if cycles > 0
            cycle_count[] += 0.5  # Each color change is half a cycle
            
            if cycle_count[] >= cycles
                # Reset to original state
                GAccessor.name(widget, original_style)
                
                # Remove CSS provider
                Gtk.GLib.g_object_unref(css_provider)
                
                return false  # Stop timer
            end
        end
        
        return true  # Continue timer
    end
    
    return timer_id
end

"""
    play_sound(name::String, volume::Float64=1.0)

Play a sound by name.
This is a dummy implementation that just logs the sound played.

# Arguments
- `name::String`: Sound name (without extension)
- `volume::Float64`: Volume level from 0.0 to 1.0 (default: 1.0)

# Returns
- Sound object reference or nothing if audio is disabled
"""
function play_sound(name::String, volume::Float64=1.0)
    if !AUDIO_ENABLED[]
        println("Audio disabled: Would play sound '$name' at volume $volume")
        return nothing
    end
    
    # Just log it for now as we don't have real audio yet
    println("Playing sound: $name (volume: $volume)")
    
    # Cache the sound request
    SOUND_CACHE[name] = Dict("name" => name, "volume" => volume, "playing" => true)
    
    return SOUND_CACHE[name]
end

"""
    stop_sound(sound::Any)

Stop a currently playing sound.

# Arguments
- `sound`: Sound reference returned by play_sound()
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

# Initialize module
function __init__()
    println("UIAnimations module initialized")
    AUDIO_ENABLED[] = true
end

end # module