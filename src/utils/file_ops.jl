﻿module FileOps

export with_file, read_file_contents, write_file_contents, file_exists, 
       make_directory, get_file_extension, get_file_name, get_directory_contents

using ..Safety

"""
    with_file(path::String, mode::String, operation::Function)

Safely open and operate on a file, ensuring it's properly closed.

# Arguments
- `path::String`: Path to the file
- `mode::String`: File mode ("r" for read, "w" for write, etc.)
- `operation::Function`: Function that takes a file handle

# Returns
- Result of the operation
"""
function with_file(path::String, mode::String, operation::Function)
    if !isfile(path) && mode == "r"
        error("File not found: $path")
    end
    
    return Safety.safe_operation(
        () -> begin
            open(path, mode) do file
                return operation(file)
            end
        end,
        (err) -> begin
            error("Error operating on file $path: $err")
        end
    )
end

"""
    read_file_contents(path::String, binary::Bool=false)

Read the entire contents of a file.

# Arguments
- `path::String`: Path to the file
- `binary::Bool`: Whether to read in binary mode (default: false)

# Returns
- File contents as string or binary data
"""
function read_file_contents(path::String, binary::Bool=false)
    mode = binary ? "rb" : "r"
    
    return with_file(path, mode, file -> begin
        if binary
            return read(file)
        else
            return read(file, String)
        end
    end)
end

"""
    write_file_contents(path::String, content::Union{String, Vector{UInt8}}, binary::Bool=false)

Write content to a file.

# Arguments
- `path::String`: Path to the file
- `content::Union{String, Vector{UInt8}}`: Content to write
- `binary::Bool`: Whether to write in binary mode (default: false)

# Returns
- `Bool`: Success status
"""
function write_file_contents(path::String, content::Union{String, Vector{UInt8}}, binary::Bool=false)
    mode = binary ? "wb" : "w"
    
    return Safety.safe_operation(
        () -> begin
            # Ensure directory exists
            dir = dirname(path)
            if !isempty(dir) && !isdir(dir)
                mkpath(dir)
            end
            
            with_file(path, mode, file -> begin
                write(file, content)
            end)
            
            return true
        end,
        (err) -> begin
            @warn "Error writing to file $path: $err"
            return false
        end
    )
end

"""
    file_exists(path::String)

Check if a file exists.

# Arguments
- `path::String`: Path to check

# Returns
- `Bool`: True if file exists
"""
function file_exists(path::String)
    return isfile(path)
end

"""
    make_directory(path::String, recursive::Bool=true)

Create a directory.

# Arguments
- `path::String`: Path to create
- `recursive::Bool`: Whether to create parent directories (default: true)

# Returns
- `Bool`: Success status
"""
function make_directory(path::String, recursive::Bool=true)
    return Safety.safe_operation(
        () -> begin
            if recursive
                mkpath(path)
            else
                mkdir(path)
            end
            return true
        end,
        (err) -> begin
            @warn "Error creating directory $path: $err"
            return false
        end
    )
end

"""
    get_file_extension(path::String)

Get the file extension from a path.

# Arguments
- `path::String`: File path

# Returns
- `String`: File extension (without dot)
"""
function get_file_extension(path::String)
    # Extract extension, removing any query parameters or fragments
    clean_path = split(path, '?')[1]
    clean_path = split(clean_path, '#')[1]
    
    # Get extension
    parts = splitext(clean_path)
    if length(parts) >= 2 && !isempty(parts[2])
        # Remove the leading dot
        return parts[2][2:end]
    end
    
    return ""
end

"""
    get_file_name(path::String, with_extension::Bool=true)

Get the file name from a path.

# Arguments
- `path::String`: File path
- `with_extension::Bool`: Whether to include the extension (default: true)

# Returns
- `String`: File name
"""
function get_file_name(path::String, with_extension::Bool=true)
    # Extract base name from path
    base_name = basename(path)
    
    if with_extension
        return base_name
    else
        # Remove extension
        return splitext(base_name)[1]
    end
end

"""
    get_directory_contents(path::String, pattern::Union{String, Regex}="", recursive::Bool=false)

Get a list of files and directories in a directory.

# Arguments
- `path::String`: Directory path
- `pattern::Union{String, Regex}`: Optional filter pattern (default: "")
- `recursive::Bool`: Whether to search recursively (default: false)

# Returns
- `Vector{String}`: List of paths
"""
function get_directory_contents(path::String, pattern::Union{String, Regex}="", recursive::Bool=false)
    if !isdir(path)
        error("Directory not found: $path")
    end
    
    return Safety.safe_operation(
        () -> begin
            results = String[]
            
            if recursive
                for (root, dirs, files) in walkdir(path)
                    for file in files
                        full_path = joinpath(root, file)
                        
                        # Apply pattern filter if specified
                        if isempty(pattern) || (pattern isa String && occursin(pattern, file)) || 
                           (pattern isa Regex && occursin(pattern, file))
                            push!(results, full_path)
                        end
                    end
                end
            else
                for item in readdir(path)
                    full_path = joinpath(path, item)
                    
                    # Apply pattern filter if specified
                    if isempty(pattern) || (pattern isa String && occursin(pattern, item)) || 
                       (pattern isa Regex && occursin(pattern, item))
                        push!(results, full_path)
                    end
                end
            end
            
            return results
        end,
        (err) -> begin
            @warn "Error reading directory $path: $err"
            return String[]
        end
    )
end

"""
    copy_file(source::String, destination::String, overwrite::Bool=false)

Copy a file from source to destination.

# Arguments
- `source::String`: Source file path
- `destination::String`: Destination file path
- `overwrite::Bool`: Whether to overwrite existing files (default: false)

# Returns
- `Bool`: Success status
"""
function copy_file(source::String, destination::String, overwrite::Bool=false)
    if !isfile(source)
        error("Source file not found: $source")
    end
    
    if isfile(destination) && !overwrite
        error("Destination file already exists: $destination")
    end
    
    return Safety.safe_operation(
        () -> begin
            # Ensure destination directory exists
            dest_dir = dirname(destination)
            if !isempty(dest_dir) && !isdir(dest_dir)
                mkpath(dest_dir)
            end
            
            cp(source, destination, force=overwrite)
            return true
        end,
        (err) -> begin
            @warn "Error copying file from $source to $destination: $err"
            return false
        end
    )
end

"""
    move_file(source::String, destination::String, overwrite::Bool=false)

Move a file from source to destination.

# Arguments
- `source::String`: Source file path
- `destination::String`: Destination file path
- `overwrite::Bool`: Whether to overwrite existing files (default: false)

# Returns
- `Bool`: Success status
"""
function move_file(source::String, destination::String, overwrite::Bool=false)
    if !isfile(source)
        error("Source file not found: $source")
    end
    
    if isfile(destination) && !overwrite
        error("Destination file already exists: $destination")
    end
    
    return Safety.safe_operation(
        () -> begin
            # Ensure destination directory exists
            dest_dir = dirname(destination)
            if !isempty(dest_dir) && !isdir(dest_dir)
                mkpath(dest_dir)
            end
            
            mv(source, destination, force=overwrite)
            return true
        end,
        (err) -> begin
            @warn "Error moving file from $source to $destination: $err"
            return false
        end
    )
end

"""
    delete_file(path::String, force::Bool=false)

Delete a file.

# Arguments
- `path::String`: File path
- `force::Bool`: Whether to ignore errors (default: false)

# Returns
- `Bool`: Success status
"""
function delete_file(path::String, force::Bool=false)
    if !isfile(path)
        if force
            return true
        else
            error("File not found: $path")
        end
    end
    
    return Safety.safe_operation(
        () -> begin
            rm(path, force=force)
            return true
        end,
        (err) -> begin
            @warn "Error deleting file $path: $err"
            return false
        end
    )
end

end # module