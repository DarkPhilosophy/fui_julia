module UIAnimations

export fade_in, fade_out, pulse, play_sound, stop_sound

using Gtk

# Sound system configuration - use a simple in-memory system
const AUDIO_ENABLED = Ref(true)
const SOUND_CACHE = Dict{String, Any}()

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
    fade_in(widget, duration::Float64=0.5)

Animate a widget fading in from invisible to visible.
"""
function fade_in(widget, duration::Float64=0.5)
    # Use direct GTK approach for better reliability
    # Make widget visible immediately
    ccall((:gtk_widget_set_visible, Gtk.libgtk), Cvoid, (Ptr{Gtk.GObject}, Cint), widget, true)
    
    # Set initial opacity to a low but visible value to ensure it's seen
    ccall((:gtk_widget_set_opacity, Gtk.libgtk), Cvoid, (Ptr{Gtk.GObject}, Cdouble), widget, 0.4)
    
    # Force update
    while Gtk.G_.events_pending()
        Gtk.G_.main_iteration()
    end
    
    # Set full opacity immediately
    ccall((:gtk_widget_set_opacity, Gtk.libgtk), Cvoid, (Ptr{Gtk.GObject}, Cdouble), widget, 1.0)
    
    # Force update again
    while Gtk.G_.events_pending()
        Gtk.G_.main_iteration()
    end
    
    return nothing
end

"""
    fade_out(widget, duration::Float64=0.5, remove::Bool=false)

Animate a widget fading out from visible to invisible.
"""
function fade_out(widget, duration::Float64=0.5, remove::Bool=false)
    # Ensure widget is visible
    Gtk.set_gtk_property!(widget, :visible, true)
    Gtk.set_gtk_property!(widget, :opacity, 1.0)
    
    # Create animation
    frames = 20
    interval = duration / frames
    opacity_step = 1.0 / frames
    
    # Animation state
    current_opacity = Ref(1.0)
    
    # Define the callback function
    function opacity_callback()
        current_opacity[] -= opacity_step
        
        if current_opacity[] <= 0.0
            Gtk.set_gtk_property!(widget, :opacity, 0.0)
            Gtk.set_gtk_property!(widget, :visible, false)
            
            if remove
                parent = Gtk.get_gtk_property(widget, :parent, Gtk.GtkWidget)
                if parent !== nothing
                    Gtk.G_.remove(parent, widget)
                end
            end
            
            return false  # Stop timer
        end
        
        Gtk.set_gtk_property!(widget, :opacity, current_opacity[])
        return true  # Continue timer
    end
    
    # Create a timer
    timer = simple_timeout(interval, opacity_callback)
    
    return timer
end

"""
    pulse(widget, color1::String, color2::String, duration::Float64=1.0, cycles::Int=1)

Create a pulsing animation between two colors for a widget.
"""
function pulse(widget, color1::String, color2::String, duration::Float64=1.0, cycles::Int=1)
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
    end
    
    # Set initial class
    Gtk.set_gtk_property!(widget, :name, "pulse-animation-1")
    
    # Animation state
    is_color1 = Ref(true)
    cycle_count = Ref(0)
    
    # Define the callback function
    function pulse_callback()
        if is_color1[]
            Gtk.set_gtk_property!(widget, :name, "pulse-animation-2")
        else
            Gtk.set_gtk_property!(widget, :name, "pulse-animation-1")
            
            # Count full cycles
            if cycles > 0
                cycle_count[] += 1
                
                if cycle_count[] >= cycles
                    # Reset to original
                    Gtk.set_gtk_property!(widget, :name, original_name)
                    return false  # Stop timer
                end
            end
        end
        
        is_color1[] = !is_color1[]
        return true  # Continue timer
    end
    
    # Create timer with the callback
    timer = simple_timeout(duration / 2, pulse_callback)
    
    return timer
end

"""
    play_sound(name::String, volume::Float64=1.0)

Play a sound by name.
This is a dummy implementation that just logs the sound played.
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