module Safety

export safe_operation, retry_operation, with_timeout, validate_input

using Base.Threads: SpinLock

"""
    safe_operation(operation::Function, error_handler::Union{Function, Nothing}=nothing)

Execute an operation in a protected environment with error handling.

# Arguments
- `operation::Function`: The function to execute
- `error_handler::Union{Function, Nothing}`: Optional function to handle errors (default: nothing)

# Returns
- Result of the operation or error handler
"""
function safe_operation(operation::Function, error_handler::Union{Function, Nothing}=nothing)
    try
        return operation()
    catch e
        if error_handler !== nothing
            return error_handler(e)
        else
            rethrow(e)
        end
    end
end

"""
    retry_operation(operation::Function, max_retries::Int=3, delay::Float64=1.0, 
                   backoff_factor::Float64=2.0, error_handler::Union{Function, Nothing}=nothing)

Retry an operation multiple times with exponential backoff.

# Arguments
- `operation::Function`: The function to execute
- `max_retries::Int`: Maximum number of retry attempts (default: 3)
- `delay::Float64`: Initial delay between retries in seconds (default: 1.0)
- `backoff_factor::Float64`: Factor by which to increase delay after each retry (default: 2.0)
- `error_handler::Union{Function, Nothing}`: Optional function to handle final error (default: nothing)

# Returns
- Result of the operation or error handler
"""
function retry_operation(operation::Function, max_retries::Int=3, delay::Float64=1.0, 
                        backoff_factor::Float64=2.0, error_handler::Union{Function, Nothing}=nothing)
    retries = 0
    current_delay = delay
    last_error = nothing
    
    while retries <= max_retries
        try
            return operation()
        catch e
            last_error = e
            retries += 1
            
            if retries > max_retries
                break
            end
            
            sleep(current_delay)
            current_delay *= backoff_factor
        end
    end
    
    if error_handler !== nothing
        return error_handler(last_error)
    else
        throw(last_error)
    end
end

"""
    with_timeout(operation::Function, timeout::Float64, 
                default_value=nothing, error_handler::Union{Function, Nothing}=nothing)

Execute an operation with a timeout.

# Arguments
- `operation::Function`: The function to execute
- `timeout::Float64`: Maximum execution time in seconds
- `default_value`: Value to return if timeout occurs (default: nothing)
- `error_handler::Union{Function, Nothing}`: Optional function to handle errors (default: nothing)

# Returns
- Result of the operation, default value on timeout, or error handler result
"""
function with_timeout(operation::Function, timeout::Float64, 
                     default_value=nothing, error_handler::Union{Function, Nothing}=nothing)
    # Create shared state
    result = Ref{Any}(default_value)
    completed = Ref(false)
    error_occurred = Ref(false)
    error_value = Ref{Any}(nothing)
    lock = SpinLock()
    
    # Launch operation in a separate task
    task = @async begin
        try
            op_result = operation()
            
            # Store result
            lock(lock) do
                if !completed[]
                    result[] = op_result
                    completed[] = true
                end
            end
        catch e
            # Store error
            lock(lock) do
                if !completed[]
                    error_occurred[] = true
                    error_value[] = e
                    completed[] = true
                end
            end
        end
    end
    
    # Wait for timeout or completion
    timeout_time = time() + timeout
    while !completed[] && time() < timeout_time
        sleep(0.01)
    end
    
    # If not completed, mark as timed out
    lock(lock) do
        if !completed[]
            completed[] = true
            # Cancel task if possible
            if !istaskdone(task)
                @async begin
                    try
                        schedule(task, InterruptException(), error=true)
                    catch
                        # Ignore errors from cancellation
                    end
                end
            end
        end
    end
    
    # Handle error if it occurred
    if error_occurred[]
        if error_handler !== nothing
            return error_handler(error_value[])
        else
            throw(error_value[])
        end
    end
    
    return result[]
end

"""
    validate_input(input::Any, validators::Vector{Tuple{Function, String}})

Validate input against multiple validation functions.

# Arguments
- `input::Any`: The input to validate
- `validators::Vector{Tuple{Function, String}}`: List of validator functions and error messages

# Returns
- `Tuple{Bool, String}`: Success status and error message if validation failed
"""
function validate_input(input::Any, validators::Vector{Tuple{Function, String}})
    for (validator, error_message) in validators
        if !validator(input)
            return (false, error_message)
        end
    end
    
    return (true, "")
end

"""
    validate_input(inputs::Dict{String, Any}, validators::Dict{String, Vector{Tuple{Function, String}}})

Validate multiple inputs against their respective validators.

# Arguments
- `inputs::Dict{String, Any}`: Dictionary of inputs to validate
- `validators::Dict{String, Vector{Tuple{Function, String}}}`: Dictionary of validator lists

# Returns
- `Tuple{Bool, Dict{String, String}}`: Success status and dictionary of error messages
"""
function validate_input(inputs::Dict{String, Any}, validators::Dict{String, Vector{Tuple{Function, String}}})
    errors = Dict{String, String}()
    valid = true
    
    for (key, validators_list) in validators
        if haskey(inputs, key)
            input_valid, error_message = validate_input(inputs[key], validators_list)
            
            if !input_valid
                errors[key] = error_message
                valid = false
            end
        end
    end
    
    return (valid, errors)
end

# Common validators
is_not_empty(value::String) = !isempty(value)
is_positive(value::Number) = value > 0
is_non_negative(value::Number) = value >= 0
is_file_exists(value::String) = isfile(value)
is_dir_exists(value::String) = isdir(value)
is_integer(value::Number) = value == round(value)
is_float(value::Number) = typeof(value) <: AbstractFloat
is_bool(value::Any) = typeof(value) <: Bool
is_vector(value::Any) = typeof(value) <: AbstractVector
is_dict(value::Any) = typeof(value) <: AbstractDict

function is_email(value::String)
    # Basic email validation
    return occursin(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", value)
end

function is_numeric_string(value::String)
    # Check if string can be parsed as a number
    try
        parse(Float64, value)
        return true
    catch
        return false
    end
end

# Custom type validator factory
function is_type_of(type_to_check)
    return value -> typeof(value) <: type_to_check
end

end # module