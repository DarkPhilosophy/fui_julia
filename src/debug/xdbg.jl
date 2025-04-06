"""
    XDebug

Module for handling debug logging and console output.
"""
module XDebug

export Logger, create_logger, log, log_info, log_warning, log_error, log_backtrace, get_logger

using Dates
using Logging

# Debug categories/levels (similar to Lua's debug levels)
const ERRORS = "ERROR"
const CONFIG = "CONFIG"
const NETWORK = "NETWORK"
const FILE_OPS = "FILE_OPS"
const DATA_PROC = "DATA_PROC"

"""
    Logger

A debug logger structure with enhanced functionality.
"""
mutable struct Logger
    buffer::Vector{String}
    file::Union{Nothing, IOStream}
    min_level::LogLevel
end

# Global logger instance
const _GLOBAL_LOGGER = Ref{Union{Nothing, Logger}}(nothing)

"""
    create_logger(; min_level::LogLevel = Logging.Info)

Create a new logger instance with specified minimum log level.
"""
function create_logger(; min_level::LogLevel = Logging.Info)
    logger = Logger(String[], nothing, min_level)
    
    # Create debug directory if it doesn't exist
    debug_dir = "debug"
    if !isdir(debug_dir)
        mkdir(debug_dir)
    end
    
    # Open log file with timestamp
    log_file = joinpath(debug_dir, "debug_$(Dates.format(now(), "yyyymmdd_HHMMSS")).log")
    logger.file = open(log_file, "w")
    
    # Store as global logger
    _GLOBAL_LOGGER[] = logger
    
    return logger
end

"""
    get_logger()

Get the global logger instance. Creates one if it doesn't exist.
"""
function get_logger()
    if _GLOBAL_LOGGER[] === nothing
        _GLOBAL_LOGGER[] = create_logger()
    end
    return _GLOBAL_LOGGER[]
end

"""
    format_message(level::String, message::String, category::String="")

Format a log message with timestamp and optional category.
"""
function format_message(level::String, message::String, category::String="")
    timestamp = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    category_str = isempty(category) ? "" : "[$category] "
    return "[$timestamp] [$level] $(category_str)$message"
end

"""
    write_log(logger::Logger, formatted_message::String)

Write a formatted message to all log outputs.
"""
function write_log(logger::Logger, formatted_message::String)
    # Add to buffer with limit to prevent memory issues
    if length(logger.buffer) > 10000
        popfirst!(logger.buffer)
    end
    push!(logger.buffer, formatted_message)
    
    # Write to file if available
    if logger.file !== nothing
        println(logger.file, formatted_message)
        flush(logger.file)
    end
    
    # Print to console
    println(formatted_message)
end

"""
    log(logger::Logger, message::String)

Log a general message (Info level).
"""
function log(logger::Logger, message::String)
    @info message
    formatted = format_message("INFO", message)
    write_log(logger, formatted)
end

"""
    log_info(logger::Logger, message::String, category::String="")

Log an info message with optional category.
"""
function log_info(logger::Logger, message::String, category::String="")
    if logger.min_level <= Logging.Info
        @info message
        formatted = format_message("INFO", message, category)
        write_log(logger, formatted)
    end
end

"""
    log_warning(logger::Logger, message::String, category::String="")

Log a warning message with optional category.
"""
function log_warning(logger::Logger, message::String, category::String="")
    if logger.min_level <= Logging.Warn
        @warn message
        formatted = format_message("WARN", message, category)
        write_log(logger, formatted)
    end
end

"""
    log_error(logger::Logger, message::String, category::String="")

Log an error message with optional category.
"""
function log_error(logger::Logger, message::String, category::String="")
    if logger.min_level <= Logging.Error
        @error message
        formatted = format_message("ERROR", message, category)
        write_log(logger, formatted)
    end
end

"""
    log_backtrace(logger::Logger)

Log the current exception's backtrace.
"""
function log_backtrace(logger::Logger)
    if logger.min_level <= Logging.Error
        bt = catch_backtrace()
        bt_strings = sprint.(Base.show_backtrace, bt)
        formatted = format_message("ERROR", "Backtrace:", "TRACE")
        write_log(logger, formatted)
        for (i, frame) in enumerate(bt_strings)
            write_log(logger, format_message("ERROR", "[$i] $frame", "TRACE"))
        end
    end
end

"""
    get_buffer(logger::Logger, last_n::Int=0)

Get the last n entries from the log buffer. If last_n is 0, returns all entries.
"""
function get_buffer(logger::Logger, last_n::Int=0)
    if last_n <= 0 || last_n > length(logger.buffer)
        return copy(logger.buffer)
    end
    return logger.buffer[end-last_n+1:end]
end

"""
    close(logger::Logger)

Close the logger and its file handle.
"""
function Base.close(logger::Logger)
    if logger.file !== nothing
        close(logger.file)
        logger.file = nothing
    end
end

end # module