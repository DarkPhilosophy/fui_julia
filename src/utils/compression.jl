module Compression

__precompile__(false)

export compress_to_base64, decompress_from_base64, decompress_to_file

using CodecZlib
using Base64
using ..Safety
using ..XDebug
using ..FileOps

"""
    compress_to_base64(data::Union{String, Vector{UInt8}})

Compress data and encode it as base64.

# Arguments
- `data::Union{String, Vector{UInt8}}`: Data to compress

# Returns
- `String`: Base64-encoded compressed data, or `nothing` if an error occurs
"""
function compress_to_base64(data::Union{String, Vector{UInt8}})
    try
        # Convert string to bytes if needed
        bytes = data isa String ? Vector{UInt8}(data) : data
        
        # Compress the data
        compressed = transcode(ZlibCompressor, bytes)
        
        # Encode as base64
        return base64encode(compressed)
    catch e
        XDebug.log_error(XDebug.get_logger(), "Error in compression: $e", XDebug.ERRORS)
        return nothing
    end
end

"""
    compress_to_base64(data::String)

Compress string data and encode it as Base64.

# Arguments
- `data::String`: String data to compress

# Returns
- `String`: Base64-encoded compressed data
"""
function compress_to_base64(data::String)
    return compress_to_base64(Vector{UInt8}(data))
end

"""
    compress_to_base64(file_path::String)

Compress a file's contents and encode it as Base64.

# Arguments
- `file_path::String`: Path to the file to compress

# Returns
- `String`: Base64-encoded compressed data, or empty string on error
"""
function compress_to_base64(file_path::String)
    result = Safety.safe_operation(
        () -> begin
            if !isfile(file_path)
                return ""
            end
            
            data = read(file_path)
            return compress_to_base64(data)
        end,
        (err) -> ""
    )
    
    return result
end

"""
    decompress_from_base64(base64_data::String)

Decode base64 data and decompress it.

# Arguments
- `base64_data::String`: Base64-encoded compressed data

# Returns
- `String`: Decompressed data
"""
function decompress_from_base64(base64_data::String)
    try
        # Decode base64
        compressed = base64decode(base64_data)
        
        # Decompress the data
        decompressed = transcode(ZlibDecompressor, compressed)
        
        # Convert back to string
        return String(decompressed)
    catch e
        XDebug.log_error(XDebug.get_logger(), "Error in decompression: $e", XDebug.ERRORS)
        return nothing
    end
end

"""
    decompress_to_file(compressed_data::Vector{UInt8}, output_path::String)

Decompress binary data and write it to a file.

# Arguments
- `compressed_data::Vector{UInt8}`: Compressed binary data
- `output_path::String`: Path to write the decompressed data to

# Returns
- `Bool`: Success status
"""
function decompress_to_file(compressed_data::Vector{UInt8}, output_path::String, logger=nothing)
    log_msg = logger !== nothing ? (msg) -> XDebug.log_info(logger, msg) : (msg) -> nothing
    
    result = Safety.safe_operation(
        () -> begin
            # Create the output directory if it doesn't exist
            output_dir = dirname(output_path)
            if !isdir(output_dir) && !isempty(output_dir)
                mkpath(output_dir)
            end
            
            # Decompress the data
            decompressed = transcode(ZlibDecompressor, compressed_data)
            
            # Write to file
            FileOps.with_file(output_path, "wb") do file
                write(file, decompressed)
            end
            
            log_msg("Decompressed data written to: $output_path")
            return true
        end,
        (err) -> begin
            if logger !== nothing
                XDebug.log_error(logger, "Failed to decompress data to file: $err")
            end
            return false
        end
    )
    
    return result
end

"""
    decompress_to_file(base64_data::String, output_path::String)

Decode Base64 data, decompress it, and write to a file.

# Arguments
- `base64_data::String`: Base64-encoded compressed data
- `output_path::String`: Path to write the decompressed data to

# Returns
- `Bool`: Success status
"""
function decompress_to_file(base64_data::String, output_path::String, logger=nothing)
    compressed = base64decode(base64_data)
    return decompress_to_file(compressed, output_path, logger)
end

"""
    compress_directory(dir_path::String, output_file::String)

Compress an entire directory into a zip file and optionally encode as Base64.

# Arguments
- `dir_path::String`: Path to the directory to compress
- `output_file::String`: Path to the output zip file
- `as_base64::Bool`: Whether to return the result as Base64 (default: false)

# Returns
- `Union{Bool, String}`: Success status or Base64 string if as_base64 is true
"""
function compress_directory(dir_path::String, output_file::String, as_base64::Bool=false, logger=nothing)
    log_msg = logger !== nothing ? (msg) -> XDebug.log_info(logger, msg) : (msg) -> nothing
    
    result = Safety.safe_operation(
        () -> begin
            if !isdir(dir_path)
                log_msg("Directory not found: $dir_path")
                return as_base64 ? "" : false
            end
            
            # Create a temporary file for the zip
            temp_file = tempname() * ".zip"
            
            try
                # We'll use Julia's built-in run command to call an external zip utility
                # In a real implementation, we'd use a Julia zip library
                
                if Sys.iswindows()
                    run(`powershell -Command "Compress-Archive -Path \"$dir_path\\*\" -DestinationPath \"$temp_file\" -Force"`)
                else
                    run(`zip -r $temp_file $dir_path`)
                end
                
                # Check if zip was created
                if !isfile(temp_file)
                    log_msg("Failed to create zip file")
                    return as_base64 ? "" : false
                end
                
                if as_base64
                    # Read the zip file and encode it
                    zip_data = read(temp_file)
                    base64_data = base64encode(zip_data)
                    return base64_data
                else
                    # Move the zip file to the output location
                    mv(temp_file, output_file, force=true)
                    return true
                end
            finally
                # Clean up temporary file
                if isfile(temp_file)
                    rm(temp_file, force=true)
                end
            end
        end,
        (err) -> begin
            if logger !== nothing
                XDebug.log_error(logger, "Failed to compress directory: $err")
            end
            return as_base64 ? "" : false
        end
    )
    
    return result
end

"""
    decompress_directory(zip_file::String, output_dir::String)

Decompress a zip file into a directory.

# Arguments
- `zip_file::String`: Path to the zip file
- `output_dir::String`: Path to the output directory

# Returns
- `Bool`: Success status
"""
function decompress_directory(zip_file::String, output_dir::String, logger=nothing)
    log_msg = logger !== nothing ? (msg) -> XDebug.log_info(logger, msg) : (msg) -> nothing
    
    result = Safety.safe_operation(
        () -> begin
            if !isfile(zip_file)
                log_msg("Zip file not found: $zip_file")
                return false
            end
            
            # Create the output directory if it doesn't exist
            if !isdir(output_dir)
                mkpath(output_dir)
            end
            
            # We'll use Julia's built-in run command to call an external unzip utility
            # In a real implementation, we'd use a Julia zip library
            
            if Sys.iswindows()
                run(`powershell -Command "Expand-Archive -Path \"$zip_file\" -DestinationPath \"$output_dir\" -Force"`)
            else
                run(`unzip -o $zip_file -d $output_dir`)
            end
            
            log_msg("Decompressed to: $output_dir")
            return true
        end,
        (err) -> begin
            if logger !== nothing
                XDebug.log_error(logger, "Failed to decompress directory: $err")
            end
            return false
        end
    )
    
    return result
end

"""
    decompress_directory_from_base64(base64_data::String, output_dir::String)

Decode Base64 data, decompress it as a zip file, and extract to a directory.

# Arguments
- `base64_data::String`: Base64-encoded zip data
- `output_dir::String`: Path to the output directory

# Returns
- `Bool`: Success status
"""
function decompress_directory_from_base64(base64_data::String, output_dir::String, logger=nothing)
    log_msg = logger !== nothing ? (msg) -> XDebug.log_info(logger, msg) : (msg) -> nothing
    
    result = Safety.safe_operation(
        () -> begin
            # Create a temporary file for the zip
            temp_file = tempname() * ".zip"
            
            try
                # Decode and write the zip file
                zip_data = base64decode(base64_data)
                write(temp_file, zip_data)
                
                # Extract the zip file
                return decompress_directory(temp_file, output_dir, logger)
            finally
                # Clean up temporary file
                if isfile(temp_file)
                    rm(temp_file, force=true)
                end
            end
        end,
        (err) -> begin
            if logger !== nothing
                XDebug.log_error(logger, "Failed to decompress from Base64: $err")
            end
            return false
        end
    )
    
    return result
end

end # module