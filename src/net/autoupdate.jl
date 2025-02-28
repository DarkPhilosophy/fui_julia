module AutoUpdate

using HTTP
using Dates
using Base.Threads: @spawn, SpinLock
using ..XDebug
using ..Safety
using ..Compression
using ..FileOps
using ..Config

export check_for_updates, start_update_task, stop_update_task

"""
    UpdateTask

Structure for managing periodic update checking.
"""
mutable struct UpdateTask
    active::Bool
    interval::Int  # seconds
    last_check::DateTime
    task_ref::Union{Task, Nothing}
    lock::SpinLock
    
    UpdateTask() = new(false, 3600, now(), nothing, SpinLock())
end

# Global update task
const UPDATE_TASK = UpdateTask()

"""
    parse_version(version_str::String)

Parse a version string to an integer for comparison.
"""
function parse_version(version_str::String)
    # Remove non-numeric characters and convert to integer
    digits_only = replace(version_str, r"\D" => "")
    try
        return parse(Int, digits_only)
    catch
        return 0
    end
end

"""
    is_newer_version(current_version::String, remote_version::String)

Compare version strings to determine if remote is newer.
"""
function is_newer_version(current_version::String, remote_version::String)
    current_num = parse_version(current_version)
    remote_num = parse_version(remote_version)
    return remote_num > current_num
end

"""
    fetch_version(source::String, logger=nothing)

Fetch version information from a source (URL or file).
"""
function fetch_version(source::String, logger=nothing)
    log_msg = logger !== nothing ? (msg) -> XDebug.log_info(logger, msg, XDebug.NETWORK) : (msg) -> nothing
    
    log_msg("Fetching version from: $source")
    
    result = Safety.safe_operation(
        () -> begin
            if startswith(source, "http://") || startswith(source, "https://")
                # Web source
                response = HTTP.get(source, status_exception=false)
                if response.status == 200
                    version = replace(String(response.body), r"\D" => "")
                    log_msg("Received version from web: $version")
                    return version
                else
                    log_msg("Failed to fetch version from web, status: $(response.status)")
                    return "0"
                end
            elseif isfile(source)
                # File source
                file_content = read(source, String)
                version = replace(file_content, r"\D" => "")
                log_msg("Read version from file: $version")
                return version
            else
                log_msg("Source not found: $source")
                return "0"
            end
        end,
        (err) -> begin
            if logger !== nothing
                XDebug.log_error(logger, "Error fetching version: $err", XDebug.NETWORK)
            end
            return "0"
        end
    )
    
    return result
end

"""
    create_cleanup_script(old_exe_name::String, old_exe_path::String, new_exe_path::String, debug_mode::Bool)

Create a PowerShell script to clean up the old executable after update.
"""
function create_cleanup_script(old_exe_name::String, old_exe_path::String, new_exe_path::String, debug_mode::Bool)
    debug_flag = debug_mode ? "debug" : ""
    
    script_content = """
    param (
        [string]\$oldExeName = '$old_exe_name',
        [string]\$oldExePath = '$old_exe_path',
        [string]\$newExePath = '$new_exe_path',
        [string]\$debugMode = '$debug_flag'
    )
    
    function Write-Debug {
        param([string]\$message)
        if (\$debugMode -eq "debug") {
            Write-Host "[DEBUG] \$message"
        }
    }
    
    \$scriptPath = \$MyInvocation.MyCommand.Path
    \$cleanupScript = {
        if (Test-Path \$scriptPath) {
            Remove-Item -Path \$scriptPath -Force
            Write-Debug "Cleanup script removed itself"
        }
    }
    
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action \$cleanupScript
    
    try {
        Write-Debug "Received parameters:"
        Write-Debug " - Old Executable Name: \$oldExeName"
        Write-Debug " - Old Executable Path: \$oldExePath"
        Write-Debug " - New Executable Path: \$newExePath"
    
        Write-Debug "Attempting to terminate process: \$oldExeName"
        \$process = Get-Process -Name \$oldExeName -ErrorAction SilentlyContinue
        if (\$process) {
            Write-Debug "Process found. Terminating..."
            Stop-Process -Name \$oldExeName -Force
            Start-Sleep -Seconds 1
        }
    
        Start-Process -FilePath \$newExePath
    
        Write-Debug "Waiting for old process to terminate..."
        while (\$true) {
            \$process = Get-Process -Name \$oldExeName -ErrorAction SilentlyContinue
            if (-not \$process) { break }
            Start-Sleep -Seconds 1
        }
    
        if (Test-Path \$oldExePath) {
            \$retryCount = 0
            \$maxRetries = 5
            while (\$retryCount -lt \$maxRetries) {
                try {
                    Remove-Item -Path \$oldExePath -Force
                    Write-Debug "Successfully removed old executable"
                    break
                } catch {
                    \$retryCount++
                    Write-Debug "Attempt \$retryCount failed: \$_"
                    Start-Sleep -Seconds 2
                }
            }
        } else {
            Write-Debug "Old executable not found: \$oldExePath"
        }
    }
    catch {
        Write-Debug "Error during cleanup: \$_"
    }
    finally {
        if (\$debugMode -eq "debug") {
            Write-Host "Press Enter to exit..."
            Read-Host
        }
    }
    """
    
    # Create temporary script file
    script_path = joinpath(tempdir(), "fui_update_$(rand(1000:9999)).ps1")
    
    FileOps.with_file(script_path, "w") do file
        write(file, script_content)
    end
    
    return script_path
end

"""
    check_for_updates(config::Dict{String, Any}, ui_components::Any, logger=nothing)

Check for updates and handle the update process.
"""
function check_for_updates(config::Dict{String, Any}, ui_components=nothing, logger=nothing)
    log_msg = logger !== nothing ? (msg) -> XDebug.log_info(logger, msg, XDebug.NETWORK) : (msg) -> nothing
    
    log_msg("Checking for updates...")
    
    # Get current version
    current_version = get(config, "Version", "0")
    
    # Get update sources
    sources = get(config, "UpdateSources", [
        "//timnt779/MagicRay/Backup/Software programare/SW_FUI/fui/update.txt",
        "//timnt757/Tools/scripts/M2/fui/update.txt"
    ])
    
    # Debug flag
    debug_mode = get(config, "Debug", false)
    
    if debug_mode
        # Add local debug source
        pushfirst!(sources, "D://update.txt")
    end
    
    # Check each source
    for source in sources
        log_msg("Checking source: $source")
        
        remote_version = fetch_version(source, logger)
        
        if is_newer_version(current_version, remote_version)
            log_msg("New version found: $remote_version (current: $current_version)")
            
            # Ask user if they want to update
            if ui_components === nothing || show_update_dialog(ui_components, remote_version)
                log_msg("User accepted update to version $remote_version")
                
                # Apply update
                update_result = apply_update(source, remote_version, current_version, debug_mode, logger)
                
                if update_result
                    log_msg("Update process initiated successfully")
                    return true
                else
                    log_msg("Update failed")
                end
            else
                log_msg("User declined update")
            end
            
            # Found an update (accepted or declined), no need to check other sources
            return false
        end
    end
    
    log_msg("No updates found")
    return false
end

"""
    show_update_dialog(ui_components, version::String)

Show a dialog asking the user if they want to update.
"""
function show_update_dialog(ui_components, version::String)
    # This would use the UI components to show a dialog, but for simplicity,
    # we'll use a basic dialog here
    
    dialog = Gtk4.GtkMessageDialog(
        ui_components.window, 
        Gtk4.DialogFlags_MODAL | Gtk4.DialogFlags_DESTROY_WITH_PARENT,
        Gtk4.MessageType_QUESTION,
        Gtk4.ButtonsType_YES_NO,
        "A new version ($version) is available. Update?"
    )
    
    dialog.title = "Update Available"
    
    response = run(dialog)
    destroy(dialog)
    
    return response == Gtk4.ResponseType_YES
end

"""
    apply_update(source::String, new_version::String, current_version::String, 
                debug_mode::Bool, logger=nothing)

Download and apply the update.
"""
function apply_update(source::String, new_version::String, current_version::String, 
                     debug_mode::Bool, logger=nothing)
    log_msg = logger !== nothing ? (msg) -> XDebug.log_info(logger, msg, XDebug.NETWORK) : (msg) -> nothing
    
    log_msg("Applying update to v$new_version")
    
    # Create new executable name
    exe_name = "fui$(parse_version(new_version)).exe"
    
    # Get update data URL
    update_base = replace(source, "update.txt" => "")
    update_url = "$(update_base)$(new_version).txt"
    
    log_msg("Fetching update from: $update_url")
    
    result = Safety.safe_operation(
        () -> begin
            # Fetch update data
            update_data = ""
            
            if startswith(update_url, "http://") || startswith(update_url, "https://")
                response = HTTP.get(update_url, status_exception=false)
                if response.status == 200
                    update_data = String(response.body)
                else
                    log_msg("Failed to fetch update data, status: $(response.status)")
                    return false
                end
            elseif isfile(update_url)
                update_data = read(update_url, String)
            else
                log_msg("Update file not found: $update_url")
                return false
            end
            
            if isempty(update_data)
                log_msg("Empty update data received")
                return false
            end
            
            # Extract update to current directory
            current_dir = dirname(abspath(PROGRAM_FILE))
            new_exe_path = joinpath(current_dir, exe_name)
            
            # Decode and extract
            decoded_data = Base64.base64decode(update_data)
            
            # Decompress and write to file
            if Compression.decompress_to_file(decoded_data, new_exe_path)
                log_msg("Update extracted to: $new_exe_path")
                
                # Create cleanup script
                current_exe_path = abspath(PROGRAM_FILE)
                current_exe_name = basename(current_exe_path)
                
                script_path = create_cleanup_script(
                    current_exe_name,
                    current_exe_path,
                    new_exe_path,
                    debug_mode
                )
                
                log_msg("Created cleanup script: $script_path")
                
                # Run cleanup script
                debug_flag = debug_mode ? "debug" : ""
                run(`powershell -NoProfile -ExecutionPolicy Bypass -File "$script_path" "$current_exe_name" "$current_exe_path" "$new_exe_path" "$debug_flag"`)
                
                log_msg("Update process initiated, exiting current application")
                
                # Update successful - the cleanup script will terminate this process
                return true
            else
                log_msg("Failed to extract update")
                return false
            end
        end,
        (err) -> begin
            if logger !== nothing
                XDebug.log_error(logger, "Error applying update: $err", XDebug.NETWORK)
                XDebug.log_backtrace(logger)
            end
            return false
        end
    )
    
    return result
end

"""
    update_task_loop(interval::Int, ui_components::Any, logger=nothing)

Background task for periodic update checking.
"""
function update_task_loop(interval::Int, ui_components::Any, logger=nothing)
    log_msg = logger !== nothing ? (msg) -> XDebug.log_info(logger, msg, XDebug.NETWORK) : (msg) -> nothing
    
    log_msg("Starting update task with interval: $interval seconds")
    
    try
        while true
            lock(UPDATE_TASK.lock) do
                if !UPDATE_TASK.active
                    return
                end
            end
            
            # Get fresh config
            config = Config.load_config()
            
            # Check for updates
            check_for_updates(config, ui_components, logger)
            
            # Update last check time
            lock(UPDATE_TASK.lock) do
                UPDATE_TASK.last_check = now()
            end
            
            # Sleep for the interval
            sleep(interval)
        end
    catch e
        if logger !== nothing
            XDebug.log_error(logger, "Error in update task: $e", XDebug.NETWORK)
            XDebug.log_backtrace(logger)
        end
    finally
        lock(UPDATE_TASK.lock) do
            UPDATE_TASK.active = false
        end
    end
end

"""
    start_update_task(interval::Int, ui_components::Any, logger=nothing)

Start a periodic update checking task.
"""
function start_update_task(interval::Int, ui_components::Any, logger=nothing)
    lock(UPDATE_TASK.lock) do
        # Stop existing task if running
        if UPDATE_TASK.active && UPDATE_TASK.task_ref !== nothing
            stop_update_task(logger)
        end
        
        # Set up new task
        UPDATE_TASK.active = true
        UPDATE_TASK.interval = max(60, interval)  # Minimum 60 seconds
        UPDATE_TASK.last_check = now()
        
        # Start background task
        UPDATE_TASK.task_ref = @spawn update_task_loop(UPDATE_TASK.interval, ui_components, logger)
    end
end

"""
    stop_update_task(logger=nothing)

Stop the periodic update checking task.
"""
function stop_update_task(logger=nothing)
    lock(UPDATE_TASK.lock) do
        if UPDATE_TASK.active
            UPDATE_TASK.active = false
            
            if UPDATE_TASK.task_ref !== nothing && !istaskdone(UPDATE_TASK.task_ref)
                try
                    wait(UPDATE_TASK.task_ref)
                catch e
                    if logger !== nothing
                        XDebug.log_error(logger, "Error waiting for update task to end: $e", XDebug.NETWORK)
                    end
                end
            end
            
            UPDATE_TASK.task_ref = nothing
        end
    end
end

end # module