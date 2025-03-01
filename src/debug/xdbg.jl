module XDebug

export Logger, log_info, log_warning, log_error, log_critical, log_debug, log_backtrace, 
       start_task, stop_task, flush_logs, with_timing

using Dates
using Logging
using Base.Threads: @spawn, SpinLock
using ThreadPools
using ..Safety

"""
    LogLevel

Enumeration of log levels with appropriate colors for terminal output.
"""
@enum LogLevel begin
    Debug = 0
    Info = 1
    Warning = 2
    Error = 3
    Critical = 4
end

"""
    LogCategory

Enumeration of log categories for organizational purposes.
"""
@enum LogCategory begin
    EVENTS = 0
    FILE_OPS = 1
    DATA_PROC = 2
    CONFIG = 3
    UI = 4
    ERRORS = 5
    NETWORK = 6
    GENERAL = 7
end

"""
    LogBuffer

Thread-safe buffer for log entries before they are written to disk or console.
"""
mutable struct LogBuffer
    entries::Vector{String}
    lock::SpinLock
    max_size::Int
    
    LogBuffer(max_size::Int=1000) = new(String[], SpinLock(), max_size)
end

"""
    LogTask

Structure representing a periodic logging task.
"""
mutable struct LogTask
    active::Bool
    interval::Float64  # seconds
    last_run::Float64  # timestamp
    task_ref::Union{Task, Nothing}
    
    LogTask() = new(false, 0.0, 0.0, nothing)
end

"""
    Logger

Enhanced logging system with thread-safe buffers, async tasks, and configurable outputs.
"""
mutable struct Logger
    name::String
    enabled::Bool
    min_level::LogLevel
    print_buffer::LogBuffer
    save_buffer::LogBuffer
    log_dir::String
    print_task::LogTask
    save_task::LogTask
    suppress_console::Bool
    category_filters::Dict{LogCategory, Bool}
    timestamp_format::String
    
    function Logger(name::String, enabled::Bool=true, min_level::LogLevel=Debug, 
                    log_dir::String="data/debug", max_buffer::Int=1000,
                    suppress_console::Bool=false)
        # Create log directory if it doesn't exist
        if !isdir(log_dir)
            mkpath(log_dir)
        end
        
        # Enable all categories by default
        category_filters = Dict{LogCategory, Bool}(
            cat => true for cat in instances(LogCategory)
        )
        
        new(
            name,
            enabled,
            min_level,
            LogBuffer(max_buffer),
            LogBuffer(max_buffer),
            log_dir,
            LogTask(),
            LogTask(),
            suppress_console,
            category_filters,
            "yyyy-mm-dd HH:MM:SS.sss"
        )
    end
end

"""
    get_timestamp(logger::Logger)

Generate a formatted timestamp for log entries.
"""
function get_timestamp(logger::Logger)
    return Dates.format(now(), logger.timestamp_format)
end

"""
    get_caller()

Get information about the caller function for improved log context.
"""
function get_caller()
    # Default values
    caller = Dict(
        "name" => "unknown",
        "line" => "?",
        "file" => "unknown"
    )
    
    # Fixed implementation that doesn't use StackTraces.lookup on a vector
    try
        # Get stack trace - skip the frames related to logging
        st = stacktrace()[4:end]
        if !isempty(st)
            for frame in st
                func_name = string(frame.func)
                
                # Skip if this is a logging function
                if !startswith(func_name, "log_") && func_name != "with_timing"
                    caller["name"] = func_name
                    caller["line"] = string(frame.line)
                    caller["file"] = string(frame.file)
                    break
                end
            end
        end
    catch
        # Fallback if stacktrace fails
    end
    
    return caller
end

"""
    format_log_entry(logger::Logger, level::LogLevel, message::String, category::LogCategory)

Format a log entry with timestamp, level, category, and caller information.
"""
function format_log_entry(logger::Logger, level::LogLevel, message::String, 
                          category::LogCategory=GENERAL)
    timestamp = get_timestamp(logger)
    caller = get_caller()
    
    return "[$(timestamp)] [$(level)] [$(category)] $(caller["name"]):$(caller["line"]) - $(message)"
end

"""
    add_to_buffer!(buffer::LogBuffer, entry::String)

Add an entry to a buffer in a thread-safe manner.
"""
function add_to_buffer!(buffer::LogBuffer, entry::String)
    lock(buffer.lock) do
        push!(buffer.entries, entry)
        # Trim if over max size
        if length(buffer.entries) > buffer.max_size
            deleteat!(buffer.entries, 1:(length(buffer.entries) - buffer.max_size))
        end
    end
end

"""
    log_message(logger::Logger, level::LogLevel, message::String, category::LogCategory=GENERAL)

Log a message with the specified level and category.
"""
function log_message(logger::Logger, level::LogLevel, message::String, 
                     category::LogCategory=GENERAL)
    if !logger.enabled || level < logger.min_level || !get(logger.category_filters, category, true)
        return
    end
    
    entry = format_log_entry(logger, level, message, category)
    
    # Add to print buffer if console output is enabled
    if !logger.suppress_console
        add_to_buffer!(logger.print_buffer, entry)
    end
    
    # Always add to save buffer for file output
    add_to_buffer!(logger.save_buffer, entry)
    
    # Auto-flush if critical or error
    if level == Critical || level == Error
        flush_logs(logger)
    end
    
    return entry
end

# Convenience functions for different log levels
log_debug(logger::Logger, message::String, category::LogCategory=GENERAL) = 
    log_message(logger, Debug, message, category)

log_info(logger::Logger, message::String, category::LogCategory=GENERAL) = 
    log_message(logger, Info, message, category)

log_warning(logger::Logger, message::String, category::LogCategory=GENERAL) = 
    log_message(logger, Warning, message, category)

log_error(logger::Logger, message::String, category::LogCategory=GENERAL) = 
    log_message(logger, Error, message, category)

log_critical(logger::Logger, message::String, category::LogCategory=GENERAL) = 
    log_message(logger, Critical, message, category)

"""
    log_backtrace(logger::Logger, category::LogCategory=ERRORS)

Log the current stack trace.
"""
function log_backtrace(logger::Logger, category::LogCategory=ERRORS)
    bt = stacktrace()
    bt_strings = []
    
    for (i, frame) in enumerate(bt)
        if i <= 2  # Skip logging frames
            continue
        end
        frame_str = "$(frame.file):$(frame.line) $(frame.func)"
        push!(bt_strings, "  [$i] $frame_str")
    end
    
    backtrace_str = join(bt_strings, "\n")
    log_message(logger, Error, "Stack trace:\n$backtrace_str", category)
end

"""
    flush_print_buffer(logger::Logger)

Flush the print buffer to the console.
"""
function flush_print_buffer(logger::Logger)
    if logger.suppress_console
        return
    end
    
    entries = String[]
    lock(logger.print_buffer.lock) do
        entries = copy(logger.print_buffer.entries)
        empty!(logger.print_buffer.entries)
    end
    
    for entry in entries
        println(entry)
    end
end

"""
    flush_save_buffer(logger::Logger)

Flush the save buffer to log files.
"""
function flush_save_buffer(logger::Logger)
    entries = String[]
    lock(logger.save_buffer.lock) do
        entries = copy(logger.save_buffer.entries)
        empty!(logger.save_buffer.entries)
    end
    
    if isempty(entries)
        return
    end
    
    # Create log filename with date
    date_str = Dates.format(now(), "yyyy-mm-dd")
    log_file = joinpath(logger.log_dir, "$(logger.name)_$(date_str).log")
    
    # Write to file
    Safety.safe_operation(
        () -> begin
            open(log_file, "a") do file
                for entry in entries
                    println(file, entry)
                end
            end
        end,
        (err) -> begin
            # If we can't write to the log file, print to console as a fallback
            println("Failed to write to log file: $err")
            for entry in entries
                println(entry)
            end
        end
    )
end

"""
    flush_logs(logger::Logger)

Flush both print and save buffers.
"""
function flush_logs(logger::Logger)
    flush_print_buffer(logger)
    flush_save_buffer(logger)
end

"""
    logging_task(logger::Logger, task_type::Symbol)

Background task for periodic log flushing.
"""
function logging_task(logger::Logger, task_type::Symbol)
    task = task_type == :print ? logger.print_task : logger.save_task
    buffer_flush = task_type == :print ? flush_print_buffer : flush_save_buffer
    
    try
        while task.active
            current_time = time()
            
            # Check if it's time to run
            if current_time - task.last_run >= task.interval
                buffer_flush(logger)
                task.last_run = current_time
            end
            
            # Sleep for a short time to avoid busy-waiting
            sleep(min(0.1, task.interval / 10))
        end
    catch e
        # Last-ditch effort to log the error
        println("Error in logging task: $e")
        try
            open(joinpath(logger.log_dir, "logger_crash.log"), "a") do file
                println(file, "[$(now())] Error in logging task: $e")
                println(file, sprint(showerror, e, catch_backtrace()))
            end
        catch
            # Can't do much if even this fails
        end
    end
end

"""
    start_task(logger::Logger, task_type::Symbol, interval::Float64)

Start a periodic logging task.
"""
function start_task(logger::Logger, task_type::Symbol, interval::Float64)
    if !logger.enabled
        return
    end
    
    task = task_type == :print ? logger.print_task : logger.save_task
    
    # Stop existing task if running
    if task.active
        stop_task(logger, task_type)
    end
    
    # Setup new task
    task.active = true
    task.interval = max(0.1, interval)  # Minimum 0.1 seconds
    task.last_run = time()
    
    # Start background task
    task.task_ref = @spawn logging_task(logger, task_type)
end

"""
    stop_task(logger::Logger, task_type::Symbol)

Stop a periodic logging task.
"""
function stop_task(logger::Logger, task_type::Symbol)
    task = task_type == :print ? logger.print_task : logger.save_task
    
    if task.active
        task.active = false
        # Wait for task to end gracefully
        if task.task_ref !== nothing && !istaskdone(task.task_ref)
            try
                wait(task.task_ref)
            catch e
                # Just log and continue
                println("Error waiting for task to end: $e")
            end
        end
        task.task_ref = nothing
    end
    
    # Final flush
    if task_type == :print
        flush_print_buffer(logger)
    else
        flush_save_buffer(logger)
    end
end

"""
    with_timing(logger::Logger, operation::Function, operation_name::String, 
                category::LogCategory=GENERAL)

Execute an operation with timing information logged.
"""
function with_timing(logger::Logger, operation::Function, operation_name::String, 
                    category::LogCategory=GENERAL)
    log_info(logger, "Starting operation: $operation_name", category)
    start_time = time()
    
    result = nothing
    success = false
    
    try
        result = operation()
        success = true
        return result
    catch e
        log_error(logger, "Error in operation '$operation_name': $e", category)
        log_backtrace(logger)
        rethrow(e)
    finally
        elapsed = time() - start_time
        status = success ? "completed" : "failed"
        log_info(logger, "Operation '$operation_name' $status in $(round(elapsed, digits=3)) seconds", category)
    end
end

end # module