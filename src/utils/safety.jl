module Safety

export safe_operation, handle_error, execute_with_fallback

using Dates

"""
    safe_operation(operation::Function, fallback::Union{Function, Nothing}=nothing)

Execute an operation with error handling.
"""
function safe_operation(operation::Function, fallback::Union{Function, Nothing}=nothing)
    func = string(operation)
    println("Function started ( $func )")
    
    error_handler = function(err)
        return Dict(
            "message" => string(err),
            "trace" => sprint(showerror, err, catch_backtrace()),
            "timestamp" => Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
        )
    end
    
    println("Executing operation ( $func )")
    success, result = try
        true, operation()
    catch e
        error_info = error_handler(e)
        println("[$(error_info["timestamp"])] Error: $(error_info["message"])\n$(error_info["trace"])")
        if !isnothing(fallback)
            println("Calling fallback ( $func )")
            try
                fallback(error_info)
            catch fb_err
                println("Fallback error: $fb_err")
            end
        end
        println("Function completed with failure ( $func )")
        false, error_info
    end
    
    println("Function completed with success: $success ( $func )")
    return success ? result : nothing
end

"""
    handle_error(err)

Handle an error by logging it and returning a backtrace.
"""
function handle_error(err)
    println("Error: $err")
    return sprint(showerror, err, catch_backtrace())
end

"""
    execute_with_fallback(operation::Function, fallback::Union{Function, Nothing}=nothing)

Execute an operation with a fallback in case of error.
"""
function execute_with_fallback(operation::Function, fallback::Union{Function, Nothing}=nothing)
    success, result = try
        true, operation()
    catch e
        if !isnothing(fallback)
            fallback(e)
        end
        false, e
    end
    return success, result
end

end # module