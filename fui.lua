-- Slap those paths wide open for DLLs and Lua
package.cpath = package.cpath .. ";./bin/?.dll;./bin/?.so;?.dll;?.so"
package.path = package.path .. ";./lua/?.lua"

-- UnicodeForge: Dynamic Unicode Text & Path Manipulation with Encoding Switch
-- Creates a table of functions to handle any Unicode chars (non-printable or otherwise) for text and path ops.
-- Args: None (self-contained factory)
-- Returns: Table {
--   get(choice): string - Raw Unicode char (e.g., "\u{200B}" for "ZWSP" or any "\u{XXXX}")
--   concat(invis, ...): string - Concatenates multiple strings with chosen Unicode char as separator
--   format(invis, base, suffix, pattern): string - Builds string from base, Unicode char, and suffix using pattern
--   list(): table - Array of predefined Unicode char names (e.g., {"ZWSP", "ZWNJ", ...})
--   setEncoding(mode): nil - Switches between "manual" (default) and "utf8" encoding
-- }
-- How it works: Predefines common non-printables, accepts any \u{XXXX} Unicode via get(), and applies them dynamically.
--               Encoding mode toggles between manual UTF-8 byte crafting and utf8.char library use.

local UnicodeForge = (function()
    local PREDEFINED = {
        ZWSP = "\u{200B}", ZWNJ = "\u{200C}", ZWJ = "\u{200D}",
        WJ = "\u{2060}", IS = "\u{2063}", SHY = "\u{00AD}"
    }

    -- Encoding mode: "manual" or "utf8"
    local encoding_mode = "utf8" -- Default to manual

    -- Manual UTF-8 encoding function
    local function manual_utf8(num)
        if num <= 0x7F then
            return string.char(num)
        elseif num <= 0x7FF then
            return string.char(0xC0 | (num >> 6), 0x80 | (num & 0x3F))
        elseif num <= 0xFFFF then
            return string.char(0xE0 | (num >> 12), 0x80 | ((num >> 6) & 0x3F), 0x80 | (num & 0x3F))
        elseif num <= 0x10FFFF then
            return string.char(0xF0 | (num >> 18), 0x80 | ((num >> 12) & 0x3F), 0x80 | ((num >> 6) & 0x3F), 0x80 | (num & 0x3F))
        end
        return PREDEFINED.ZWSP -- Fallback for invalid
    end

    -- Dynamic Unicode handler with switch
    local function get_unicode(choice)
        if PREDEFINED[choice] then
            return PREDEFINED[choice]
        end
        if choice:match("^\\u{[0-9A-Fa-f]+}$") then
            local hex = choice:match("\\u{([0-9A-Fa-f]+)}")
            local num = tonumber(hex, 16)
            if encoding_mode == "utf8" and utf8 and utf8.char then
                return utf8.char(num)
            else
                return manual_utf8(num)
            end
        end
        return PREDEFINED.ZWSP
    end

    local function format_string(invis, base, suffix, pattern)
        pattern = pattern or "{base}{invis}{suffix}"
        local uni = get_unicode(invis)
        return (pattern:gsub("{(%w+)}", {base = base or "", invis = uni, suffix = suffix or ""}))
    end

    return {
        get = function(choice) return get_unicode(choice) end,
        concat = function(invis, ...)
            local sep = get_unicode(invis)
            local args = {...}
            if #args == 0 then return "" end
            local result = args[1]
            for i = 2, #args do result = result .. sep .. args[i] end
            return result
        end,
        format = function(invis, base, suffix, pattern) return format_string(invis, base, suffix, pattern) end,
        list = function()
            local opts = {}
            for k in pairs(PREDEFINED) do opts[#opts + 1] = k end
            return opts
        end,
        setEncoding = function(mode)
            if mode == "manual" or mode == "utf8" then
                encoding_mode = mode
            end
        end
    }
end)()

_G.App = {
    Version = "23",
    Update = {
      "//timnt757/Tools/scripts/M2/fui/update.txt",
      "//timnt779/MagicRay/Backup/Software programare/SW_FUI/fui/update.txt",
      UnicodeForge.format("ZWSP", "//timsrv03/Common/Prototyping/", "/Proiecte/LuaRT/FUI/update/update.txt"),
      UnicodeForge.format("ZWSP", "//timsrv03/Common/NPI/", "/Proiecte/LuaRT/FUI/update/update.txt")
    },
    News = {
      "//timnt757/Tools/scripts/M2/fui/news.txt",
      "//timnt779/MagicRay/Backup/Software programare/SW_FUI/fui/news.txt",
      UnicodeForge.format("ZWSP", "//timsrv03/Common/Prototyping/", "/Proiecte/LuaRT/FUI/update/news.txt"),
      UnicodeForge.format("ZWSP", "//timsrv03/Common/NPI/", "/Proiecte/LuaRT/FUI/update/news.txt")
    },
    libs = {load = {"json", "ini", "audio", "ui", "sys", "compression", "net"}, cached = {}, fresh = {}, failed = {}},
    hooks = {load = {
      Task = "sys.Task",
      File = "sys.File",
      Dir = "sys.Directory",
      Http = "net.Http",
      Zip = "compression.Zip"
    }, cached = {}, fresh = {}, failed = {}}
  }

local function loadStuff(type)
    local dst = _G.App[type]       -- "libs" → _G.App.libs, "hooks" → _G.App.hooks
    for key, value in (type == "libs" and ipairs or pairs)(dst.load) do -- "libs" → _G.App.libs.load, "hooks" → _G.App.hooks.load
        local name = type == "libs" and value or key
        if not _G[name] then
        local ok, result
        if type == "libs" then
            --ok, result = pcall(
            result = require(name)
            ok = result
        else
            local mod, field = value:match("([^%.]+)%.([^%.]+)")
            ok, result = _G[mod] and _G[mod][field] ~= nil, _G[mod] and _G[mod][field]
        end
        if ok then
            _G[name] = result
            table.insert(dst.fresh, name)
        else
            table.insert(dst.failed, name)
        end
        else
        if type == "libs" then _G[name] = package.loaded[name] end
        table.insert(dst.cached, name)
        end
    end
end

-- Call it tight
loadStuff("libs")
loadStuff("hooks")
print(type(json), type(ini), type(audio), type(ui), type(sys), type(compression), type(net))
-- Unified status printer
local function printStatus(title)
    local status = _G.App[title:lower().."s"]
    print("["..title.." Status] >>>>>>>")
    print("^ Loaded:")
    print("  ✅ Cached: " .. (#status.cached > 0 and table.concat(status.cached, ", ") or "None"))
    print("  ✅ Fresh: " .. (#status.fresh > 0 and table.concat(status.fresh, ", ") or "None"))
    print("  ❌ Failed: " .. (#status.failed > 0 and table.concat(status.failed, ", ") or "None"))
end

printStatus("Lib")
printStatus("Hook")

-- Constants (precomputed and immutable)
-- Define window dimensions and logging categories
local ORIGINAL_WIDTH, ORIGINAL_HEIGHT, CONSOLE_WIDTH = 557, 300, 520

local function fallthrough(next_value) return { "fallthrough", next_value } end-- Keep this for potential future use, but it's not needed for this specific case

local function switch(inputTable)
    return function(cases)
        local lastResult
        local orderedCases = false

        -- Check if cases are passed as an array of {["key"] = function} tables
        if #cases > 0 and type(cases[1]) == "table" then
            orderedCases = true
        end

        if orderedCases then
            -- Process cases in declared array order
            for _, caseEntry in ipairs(cases) do
                for key, action in pairs(caseEntry) do
                    if key ~= "__default" then
                        -- Check if key exists in inputTable
                        local exists = false
                        if inputTable.children_order then -- hasParam table
                            exists = inputTable[key] == true
                        else -- Generic table
                            for _, v in pairs(inputTable) do
                                if v == key then exists = true break end
                            end
                        end
                        -- Execute action
                        if exists and type(action) == "function" then
                            action()
                        end
                    end
                end
            end
        else
            -- Process in inputTable's order (array or hasParam children)
            local processOrder
            if inputTable.children_order then
                processOrder = inputTable.children_order
            elseif #inputTable > 0 then
                processOrder = inputTable
            else
                processOrder = {}
                for k in pairs(cases) do
                    if k ~= "__default" then
                        table.insert(processOrder, k)
                    end
                end
            end

            -- Execute in inputTable's order
            for _, key in ipairs(processOrder) do
                if cases[key] then
                    local action = cases[key]
                    -- Check existence
                    local exists = false
                    if inputTable.children_order then
                        exists = inputTable[key] == true
                    else
                        for _, v in pairs(inputTable) do
                            if v == key then exists = true break end
                        end
                    end
                    -- Execute action
                    if exists and type(action) == "function" then
                        action()
                    end
                end
            end
        end

        -- Handle __default
        if cases.__default then
            lastResult = type(cases.__default) == "function" 
                       and cases.__default() 
                       or cases.__default
        end

        return lastResult
    end
end

-- Fast parameter checking
-- Checks if a command-line parameter exists in arg table
-- Args: param (string, parameter to check)
-- Returns: Boolean (true if found, false otherwise)
-- How it works: Extracts first word from param, scans arg table for match
local function createBoolMetaTable(value)
    local proxy = {
        [0] = value,           -- Boolean state: true/false
        children = {},         -- Child parameters
        children_order = {}    -- Insertion order tracking
    }
    return setmetatable(proxy, {
        __newindex = function(t, k, v)
            if k == 0 then
                --t[0] = v  -- Allow setting boolean state internally
                rawset(t, 0, v) -- Use rawset to avoid recursion
            elseif type(k) == "number" then
                error("Cannot modify numeric indices directly; use children")
            else
                if not t.children[k] then
                    table.insert(t.children_order, k)
                end
                rawset(t.children, k, v) -- Directly set to avoid __newindex loop
            end
        end,
        __index = function(t, k)
            -- Return the boolean value when accessed directly
            if k == nil then return t[0] end -- Add this line
            --if k == "__value" then return t[0] end
            --if k == "children_order" then return t.children_order end
            return rawget(t.children, k) -- Use rawget for performance
        end,
        __tonumber = function(t) return tonumber(t[0]) end,
        __tostring = function(t) return tostring(t[0]) end,
        __toboolean = function(t) return t[0] end,
        __bool = function(t) return t[0] end,
        __len = function(t) return t[0] and 1 or 0 end,
        __eq = function(t1, t2)
            local v2 = type(t2) == "table" and t2[0] or t2
            return t1[0] == v2
        end,
        __call = function(t) return t[0] end,
        __pairs = function(t)
            local i = 0
            return function()
                i = i + 1
                local key = t.children_order[i]
                return key, t.children[key]
            end
        end,
        __ipairs = function(t)
            return function(t, i)
                i = i + 1
                if i > 1 then return nil end
                return i, t[0]
            end, t, 0
        end,
        __concat = function(t1, t2)
            return tostring(t1) .. tostring(t2)
        end,
        __band = function(t1, t2)
            local v2 = type(t2) == "table" and t2[0] or t2
            return t1[0] and v2
        end,
        __bor = function(t1, t2)
            local v2 = type(t2) == "table" and t2[0] or t2
            return t1[0] or v2
        end
    })
end

local splitCache = setmetatable({}, { __mode = "k" })
local childCache = setmetatable({}, { __mode = "k" })
local function hasParam(parentArg, ...)

    local function splitString(str)
        if not splitCache[str] then
            splitCache[str] = {}
            for w in str:gmatch("[^,%s]+") do splitCache[str][#splitCache[str]+1] = w end
        end
        return splitCache[str]
    end

    local function collectChildren(str)
        local t = { wildcard = false }
        for w in (str or ""):gmatch("%S+") do 
            if w == "*" then t.wildcard = true else t[#t+1] = w end 
        end
        return t
    end

    local function getChildren(parent, i, startIdx, endIdx)
        local key = parent .. ":" .. i .. ":" .. startIdx .. "-" .. endIdx
        if not childCache[key] then
            childCache[key] = {}
            for idx = startIdx + 1, endIdx - 1 do
                if not arg[idx]:match("^%-%-") then
                    childCache[key][arg[idx]] = true
                end
            end
        end
        return childCache[key]
    end

    if not arg or #arg == 0 then 
        local result = {}
        for _, word in ipairs(splitString(parentArg)) do
            if word:match("^%-%-") then
                result[word:gsub("^%-%-", "")] = createBoolMetaTable(false)
            end
        end
        return false, result
    end

    local parents = {}
    local parentParts = splitString(parentArg)
    for _, word in ipairs(parentParts) do
        if word:match("^%-%-") then
            parents[#parents + 1] = word
        end
    end
    if #parents == 0 then return false, {} end

    local childArgs = {...}
    local result = {}
    local allFound = true
    local parentIndices = {}
    for i, v in ipairs(arg) do
        for _, parent in ipairs(parents) do
            if v == parent then
                parentIndices[parent] = parentIndices[parent] or {}
                parentIndices[parent][#parentIndices[parent] + 1] = i
            end
        end
    end

    for i, parent in ipairs(parents) do
        local parentKey = parent:gsub("^%-%-", "")
        local requestedChildren = {}
        if #parents == 1 and #childArgs == 0 then
            for _, word in ipairs(parentParts) do
                if not word:match("^%-%-") then
                    requestedChildren[#requestedChildren + 1] = word
                end
            end
        elseif #parents == 1 then
            requestedChildren = collectChildren(table.concat(childArgs, " "))
        elseif i <= #childArgs then
            requestedChildren = collectChildren(childArgs[i])
        end

        local parentFound = parentIndices[parent] ~= nil
        allFound = allFound and parentFound

        result[parentKey] = createBoolMetaTable(parentFound)
        if #requestedChildren > 0 or requestedChildren.wildcard then
            if parentFound then
                local allChildren = {}
                for _, startIdx in ipairs(parentIndices[parent]) do
                    local endIdx = #arg + 1
                    for idx = startIdx + 1, #arg do
                        if arg[idx]:match("^%-%-") then
                            endIdx = idx
                            break
                        end
                    end
                    local children = getChildren(parent, i, startIdx, endIdx)
                    for k, v in pairs(children) do allChildren[k] = v end
                end
                if requestedChildren.wildcard then
                    for k, v in pairs(allChildren) do
                        result[parentKey][k] = v
                    end
                    allFound = allFound and next(allChildren) ~= nil
                else
                    for _, child in ipairs(requestedChildren) do
                        local childFound = allChildren[child] or false
                        result[parentKey][child] = childFound
                        allFound = allFound and childFound
                    end
                end
            else
                for _, child in ipairs(requestedChildren) do
                    result[parentKey][child] = false
                end
            end
        end
    end

    setmetatable(result, {
        __index = {
            hasParam = function(self, mode, target, ...)
                local parts = {}
                for w in target:gmatch("[^,%s]+") do
                    table.insert(parts, w)
                end

                if mode == "||add" then
                    for _, parent in ipairs(parts) do
                        local parentKey = parent:gsub("^%-%-", "")
                        if not self[parentKey] then
                            self[parentKey] = createBoolMetaTable(true)
                        end
                        for _, child in ipairs({...}) do
                            self[parentKey][child] = true
                        end
                    end
                elseif mode == "||del" then
                    for _, parent in ipairs(parts) do
                        local parentKey = parent:gsub("^%-%-", "")
                        if self[parentKey] then
                            if select("#", ...) > 0 then
                                for _, child in ipairs({...}) do
                                    self[parentKey][child] = nil
                                end
                            else
                                self[parentKey] = nil
                            end
                        end
                    end
                end
                return self
            end
        }
    })

    return allFound, result
end

--interactive expand print save
local _, paramsAsTable = hasParam("--debug, --noembed, --noversion", "*", "", "")
local function xPrintParam(header, param, ...)
    local childArgs = ...
    local function error_handler(err)
        return debug.traceback(tostring(err))
    end
    
    local ok, result = xpcall(function()
        -- Call hasParam with each argument individually instead of using unpack
        local allFound, paramsAsTable = hasParam(param, childArgs)
        
        header(allFound, paramsAsTable) -- Execute header function first with param
        for z, v in pairs(paramsAsTable) do
            print("-^Parent: " .. z .. " // type:" .. type(v) .. " value:" .. tostring(v))
            for k, v in pairs(v) do
                print("   >Child: " .. k .. (v and " True" or " False"))
            end
        end
        --print("\n")
        return allFound, paramsAsTable -- Optional return for further use
    end, error_handler)
    
    -- Create a safe string representation of the parameters
    local paramDesc = param
    --[[for i=1, #childArgs do
        if childArgs[i] then
            paramDesc = paramDesc .. childArgs[i]
        end
    end]]
    
    print("  >>>>  "..(ok and "PASS" or "FAIL")..(not ok and " ("..result..")" or ""))
    print("\n\n")
    if ok then
        return result
    end
    return nil, nil
end

-- Preload audio files with embedding optimization
-- Loads audio assets, optionally embedding them if --noembed flag isn’t set
-- How it works: Checks for embedding flag, adjusts file paths, loads sounds
local function preloadFiles(files)
    -- Get a safe substring of a path for logging
    local function safePathForLog(path, maxLen)
        maxLen = maxLen or 60
        if #path > maxLen then
            return path:sub(1, maxLen) .. "..."
        end
        return path
    end
    
    local function resolveFilePath(filePath, isDirectory)
        isDirectory = isDirectory or false
        arg[0] = arg[0] or sys.Directory().fullpath
        print("Debug: Resolving " .. (isDirectory and "directory" or "file") .. " path: " .. filePath)
        print("Debug: arg[0]: " .. arg[0])
    
        -- Get the directory from the script's own path (arg[0])
        local scriptDir = arg[0]:gsub("\\", "/"):match("^(.*/)")
        if not scriptDir then
            -- Try using backslashes instead
            scriptDir = arg[0]:gsub("/", "\\"):match("^(.*\\)")
        end
        
        print("Debug: arg[0] as scriptDir: " .. (scriptDir or "nil"))
        
        if scriptDir then
            -- Make sure the script directory has a trailing slash
            if scriptDir:sub(-1) ~= "/" and scriptDir:sub(-1) ~= "\\" then
                scriptDir = scriptDir .. "/"
            end
            
            -- Concatenate the script directory with the file path
            local fullPath = scriptDir .. filePath
            print("Debug: Checking fullPath: " .. fullPath)
            
            if isDirectory then
                local dir = Dir(fullPath)
                if dir.exists then
                    print("Debug: Directory found in script directory: " .. fullPath)
                    return fullPath
                end
            else
                local file = File(fullPath)
                if file.exists then
                    print("Debug: File found in script directory: " .. fullPath)
                    return fullPath
                end
            end
        end
    
        -- If not found, return the original path
        print("Debug: " .. (isDirectory and "Directory" or "File") .. " not found in script directory, returning: " .. filePath)
        return filePath
    end

    -- Helper function to embed a file and return the embedded path
    local function embedFile(embedPath, tbl, k)
        print("Embedding file: " .. safePathForLog(embedPath))
        local embedded_file = embed.File(embedPath)
        if embedded_file and embedded_file.fullpath then
            tbl[k] = embedded_file.fullpath
            print("Embedded path: " .. safePathForLog(tbl[k]))
            return true
        else
            print("Error: Failed to embed file: " .. safePathForLog(embedPath))
            return false
        end
    end

    -- Helper function to list .png files in a directory (for no-embed mode)
    local function listPngFiles(anim_dir_path, anim_key)
        local anim_files = {}
        print("Debug: Attempting to list files in directory: " .. safePathForLog(anim_dir_path))
        
        -- CRITICAL FIX: Check for drive letter issues
        if anim_dir_path == "c" or anim_dir_path:match("^%a$") then
            print("Debug: Converting single letter '" .. anim_dir_path .. "' to proper drive path")
            anim_dir_path = anim_dir_path .. ":\\"
        end
        
        if anim_dir_path:match("^%a:$") then
            print("Debug: Adding separator to bare drive letter: " .. anim_dir_path)
            anim_dir_path = anim_dir_path .. "\\"
        end
        
        local dir = Dir(anim_dir_path)
        if dir.exists then
            print("Debug: Absolute path of directory: " .. safePathForLog(dir.fullpath))
            if not dir.isempty then
                local entryCount = 0
                local pngCount = 0
                
                for entry in each(dir:list("*")) do
                    entryCount = entryCount + 1
                    if entry.name:lower():match("%.png$") then
                        pngCount = pngCount + 1
                        
                        -- Properly handle path concatenation with separator check
                        local fullpath
                        if anim_dir_path:sub(-1) == "/" or anim_dir_path:sub(-1) == "\\" then
                            fullpath = anim_dir_path .. entry.name
                        else
                            fullpath = anim_dir_path .. "/" .. entry.name
                        end
                        
                        table.insert(anim_files, {name = entry.name, fullpath = fullpath})
                    end
                end
                
                print("Debug: Directory scan stats - Total entries: " .. entryCount .. ", PNG files: " .. pngCount)
                
                if #anim_files == 0 then
                    print("Warning: No .png files found in " .. safePathForLog(anim_dir_path))
                else
                    print("Debug: Found " .. #anim_files .. " animation files for " .. anim_key)
                    
                    -- Sort the animation files by numeric suffix
                    table.sort(anim_files, function(a, b)
                        local num_a = tonumber(a.name:match("%-(%d+)%.%w+$") or 0)
                        local num_b = tonumber(b.name:match("%-(%d+)%.%w+$") or 0)
                        return num_a < num_b
                    end)
                    
                    -- Log the pattern instead of individual files
                    if #anim_files > 0 then
                        local first = anim_files[1].fullpath
                        local base = first:match("(.*)%-[0-9]+%.png$")
                        
                        if base then
                            local last_index = tonumber(anim_files[#anim_files].name:match("%-(%d+)%.png$") or 0)
                            print("Debug: anim." .. anim_key .. "[0 to " .. last_index .. "]: " .. 
                                  safePathForLog(base) .. "-[0 to " .. last_index .. "].png")
                        else
                            print("Debug: Animation pattern could not be determined, using individual logs")
                            -- Log only first and last few files
                            if #anim_files <= 5 then
                                for i, file in ipairs(anim_files) do
                                    print("Debug: anim." .. anim_key .. "[" .. (i-1) .. "]: " .. safePathForLog(file.fullpath))
                                end
                            else
                                for i = 1, 2 do
                                    print("Debug: anim." .. anim_key .. "[" .. (i-1) .. "]: " .. safePathForLog(anim_files[i].fullpath))
                                end
                                print("Debug: ... " .. (#anim_files - 4) .. " more files ...")
                                for i = #anim_files - 1, #anim_files do
                                    print("Debug: anim." .. anim_key .. "[" .. (i-1) .. "]: " .. safePathForLog(anim_files[i].fullpath))
                                end
                            end
                        end
                    end
                end
            else
                print("Warning: Directory is empty: " .. safePathForLog(anim_dir_path))
            end
        else
            print("Error: Animation directory not found: " .. safePathForLog(anim_dir_path))
        end
        return anim_files
    end

    -- Step 1: Pre-list all animation files
    local prelisted_files = {}
    if not paramsAsTable["noembed"]() then
        -- In embedding mode, list files directly from embed.zip
        local embed = require "embed"
        if embed and embed.zip then
            print("Debug: Type of embed module: " .. type(embed))
            print("Debug: Type of embed.zip: " .. type(embed.zip))

            -- Iterate over all entries in embed.zip
            print("Debug: Listing all entries in embed.zip...")
            local wait_files = {}
            local search_files = {}
            local zip_entries = 0
            
            for entry_name, is_dir in each(embed.zip) do
                zip_entries = zip_entries + 1
                -- Filter for .png files in anim/wait/ or anim/search/
                if not is_dir and entry_name:lower():match("%.png$") then
                    if entry_name:match("^anim/wait/") then
                        table.insert(wait_files, {fullpath = entry_name})
                    elseif entry_name:match("^anim/search/") then
                        table.insert(search_files, {fullpath = entry_name})
                    end
                end
            end
            
            print("Debug: Found " .. zip_entries .. " total entries in embed.zip")
            print("Debug: Found " .. #wait_files .. " wait animation files and " .. 
                  #search_files .. " search animation files")

            -- Sort the files by their numeric suffix (e.g., -0.png, -1.png, etc.)
            local function sortFiles(file_list)
                table.sort(file_list, function(a, b)
                    local num_a = tonumber(a.fullpath:match("%-(%d+)%.%w+$") or 0)
                    local num_b = tonumber(b.fullpath:match("%-(%d+)%.%w+$") or 0)
                    return num_a < num_b
                end)
            end
            sortFiles(wait_files)
            sortFiles(search_files)

            -- Store the found files
            prelisted_files["wait"] = wait_files
            prelisted_files["search"] = search_files
        else
            print("Error: Embed module or embed.zip not available")
        end
    else
        -- In no-embed mode, list files from the original location (data/anim/wait, etc.)
        for k, v in pairs(files) do
            if type(v) == "table" and k == "anim" then
                for anim_key, anim_dir_path in pairs(v) do
                    if type(anim_dir_path) == "string" then
                        -- Resolve the directory path with isDirectory=true
                        local resolvedDirPath = resolveFilePath(anim_dir_path, true)
                        local anim_files = listPngFiles(resolvedDirPath, anim_key)
                        prelisted_files[anim_key] = anim_files
                    end
                end
            end
        end
    end

    -- Log the files table in a compact way
    print("Debug: Inspecting files table:")
    local function printTable(tbl, indent)
        indent = indent or 1
        local indentStr = string.rep("  ", indent)
        
        for k, v in pairs(tbl) do
            if type(v) == "table" then
                if k == "anim" then
                    print(indentStr .. k .. ": table with animations")
                    for anim_k, anim_v in pairs(v) do
                        print(indentStr .. "  " .. anim_k .. ": " .. tostring(anim_v))
                    end
                else
                    print(indentStr .. k .. ": table")
                    printTable(v, indent + 1)
                end
            else
                print(indentStr .. k .. ": " .. safePathForLog(tostring(v)))
            end
        end
    end
    
    printTable(files)

    if not paramsAsTable["noembed"]() then
        local function processTable(tbl)
            -- Process non-anim entries (e.g., audio files, fonts)
            for k, v in pairs(tbl) do
                if type(v) == "table" then
                    if k == "anim" then
                        -- Process wait and search animations directly from prelisted_files
                        for anim_key, anim_files in pairs(prelisted_files) do
                            print("Processing animation (" .. anim_key .. ") with prelisted files")
                            if #anim_files > 0 then
                                tbl[k][anim_key] = {}
                                print("Debug: Embedding " .. #anim_files .. " animation frames for " .. anim_key)
                                
                                for i, file in ipairs(anim_files) do
                                    -- CRITICAL FIX: Check for drive letter issues
                                    local embedPath = file.fullpath
                                    if embedPath == "c" or embedPath:match("^%a$") then
                                        embedPath = embedPath .. ":\\"
                                    end
                                    
                                    if embedPath:match("^%a:$") then
                                        embedPath = embedPath .. "\\"
                                    end
                                    
                                    embedFile(embedPath, tbl[k][anim_key], i)
                                    
                                    -- Only log first few and last few files for long sequences
                                    if i <= 2 or i > #anim_files - 2 or #anim_files <= 5 then
                                        print("Debug: Embedded animation " .. anim_key .. "[" .. i .. "]: " .. safePathForLog(tbl[k][anim_key][i]))
                                    elseif i == 3 then
                                        print("Debug: ... " .. (#anim_files - 4) .. " more files ...")
                                    end
                                end
                            else
                                print("Warning: No prelisted files for " .. anim_key)
                            end
                        end
                    else
                        processTable(v)
                    end
                elseif type(v) == "string" and v:match("^data/") then
                    -- Resolve the file path (check temp directory if winrar, then working directory)
                    local resolvedPath = resolveFilePath(v)
                    print("Debug: Processing file: " .. safePathForLog(v) .. " -> " .. safePathForLog(resolvedPath))
                    local embedPath = resolvedPath:gsub("^data/", "")
                    embedFile(embedPath, tbl, k)
                end
            end
        end
        processTable(files)
    else
        print("No embedding: --noembed flag is set")
        
        local function processTableNoEmbed(tbl, prefix)
            prefix = prefix or ""
            for k, v in pairs(tbl) do
                local current_path = prefix .. (prefix ~= "" and "." or "") .. k
                
                if type(v) == "table" then
                    if k == "anim" then
                        -- Animation files handling
                        for anim_key, anim_dir_path in pairs(v) do
                            if prelisted_files[anim_key] then
                                print("Debug: Processing animation [" .. current_path .. "." .. anim_key .. "] with prelisted files")
                                local anim_files = prelisted_files[anim_key]
                                if #anim_files > 0 then
                                    tbl[k][anim_key] = {}
                                    
                                    -- Create compact animation summary log
                                    print("Debug: Adding " .. #anim_files .. " animation frames for " .. anim_key)
                                    
                                    for i, file in ipairs(anim_files) do
                                        -- CRITICAL FIX: Check for drive letter issues
                                        local path = file.fullpath
                                        
                                        -- Don't resolve if the path is already absolute
                                        if path:match("^%a:[\\/]") then
                                            tbl[k][anim_key][i] = path
                                            -- Limited logging for long sequences
                                            if i <= 2 or i > #anim_files - 2 or #anim_files <= 5 then
                                                print("Debug: Using absolute path for " .. anim_key .. "[" .. i .. "]: " .. safePathForLog(path))
                                            elseif i == 3 then
                                                print("Debug: ... " .. (#anim_files - 4) .. " more files ...")
                                            end
                                        else
                                            -- Resolve the file path for relative paths
                                            tbl[k][anim_key][i] = resolveFilePath(path)
                                            if i <= 2 or i > #anim_files - 2 or #anim_files <= 5 then
                                                print("Debug: Resolved path for " .. anim_key .. "[" .. i .. "]: " .. safePathForLog(tbl[k][anim_key][i]))
                                            end
                                        end
                                    end
                                    
                                    -- Print a summary of the animation files (pattern)
                                    if #anim_files > 0 then
                                        local first = tbl[k][anim_key][1]
                                        local base = first:match("(.*)%-[0-9]+%.png$")
                                        
                                        if base then
                                            local last_index = #anim_files - 1
                                            print("Debug: Final " .. anim_key .. " frame pattern: " .. 
                                                  safePathForLog(base) .. "-[0 to " .. last_index .. "].png")
                                        end
                                    end
                                else
                                    print("Warning: No prelisted files for " .. anim_key)
                                end
                            else
                                print("Error: No prelisted files found for " .. anim_key)
                            end
                        end
                    else
                        -- Recursively process other tables
                        processTableNoEmbed(v, current_path)
                    end
                elseif type(v) == "string" then
                    -- Process individual file paths
                    local pathToResolve = v
                    
                    local resolvedPath = resolveFilePath(pathToResolve)
                    tbl[k] = resolvedPath
                    
                    -- Check if file exists after resolution
                    local fileExists = File(resolvedPath).exists
                    if fileExists then
                        print("Debug: Successfully resolved " .. current_path .. ": " .. safePathForLog(resolvedPath))
                    else
                        print("WARNING: File does not exist for " .. current_path .. ": " .. safePathForLog(resolvedPath))
                    end
                end
            end
        end
        
        processTableNoEmbed(files)
    end
    
    -- Print a summary of loaded files
    print("\nFile Loading Summary:")
    local function printSummary(tbl, prefix)
        prefix = prefix or ""
        local fileCount = 0
        local missingCount = 0
        
        for k, v in pairs(tbl) do
            local current_path = prefix .. (prefix ~= "" and "." or "") .. k
            
            if type(v) == "table" then
                if k == "anim" then
                    for anim_key, anim_files in pairs(v) do
                        if type(anim_files) == "table" then
                            local missing_frames = 0
                            for i, file_path in ipairs(anim_files) do
                                fileCount = fileCount + 1
                                
                                if not File(file_path).exists then
                                    missingCount = missingCount + 1
                                    missing_frames = missing_frames + 1
                                    
                                    -- Only log first few missing frames
                                    if missing_frames <= 3 then
                                        print("  - MISSING: " .. safePathForLog(file_path))
                                    elseif missing_frames == 4 then
                                        print("  - ... more missing frames ...")
                                    end
                                end
                            end
                            
                            print(string.format("Animation '%s': %d frames, %d missing", 
                                  anim_key, #anim_files, missing_frames))
                        end
                    end
                else
                    local subFileCount, subMissingCount = printSummary(v, current_path)
                    fileCount = fileCount + subFileCount
                    missingCount = missingCount + subMissingCount
                end
            elseif type(v) == "string" and v:match("%.%w+$") then  -- Only count strings that look like file paths
                fileCount = fileCount + 1
                
                if not File(v).exists then
                    missingCount = missingCount + 1
                    print("MISSING: " .. current_path .. " -> " .. safePathForLog(v))
                end
            end
        end
        
        if prefix == "" then  -- Only print the summary at the top level
            print(string.format("\nTotal files: %d, Missing: %d", fileCount, missingCount))
        end
        
        return fileCount, missingCount
    end
    
    printSummary(files)
    
    return files
end

-- Usage
local PREP_FILES = {
    sound = {finish = "data/audio/ui-cute-level-up.mp3", click = "data/audio/ui-minimal-click.mp3"},
    ico = {
        app_flex = "data/icon/appfui.ico",
        app = "data/icon/artificial-intelligence.ico",
        app_tray = "data/icon/artificial-intelligence2.ico",
        source = "data/icon/source.png",
        destination = "data/icon/destination.png",
        move = "data/icon/move.png",
        copy = "data/icon/copy.png",
        pc = "data/icon/computer-case.png",
        add = "data/icon/add.png",
        del = "data/icon/cross.png",
        upload = "data/icon/upload-file.png",
        ro = "data/icon/romania.png",
        en = "data/icon/united-states.png",
        earth = "data/icon/planet-earth.png"
    },
    font = {
        laser = {otf = "data/LASER.otf", ttf = "data/LASER.ttf"}
    },
    anim = {search = "data/anim/search", wait = "data/anim/wait"}
}

preloadFiles(PREP_FILES)

PREP_FILES.sound.click = audio.Sound(PREP_FILES.sound.click)
PREP_FILES.sound.finish = audio.Sound(PREP_FILES.sound.finish)

-- Optimized file handling
-- Safely opens and operates on a file, handling errors
-- Args: path (string, file path), mode (string, file mode), operation (function, file action)
-- Returns: success (bool), result/error (varies)
-- How it works: Opens file, executes operation in xpcall, closes file, returns result
local function withFile(path, mode, operation)
    --local func = getCaller()
    --xdbg:Log("Function started with path: " .. path .. ", mode: " .. mode, LOG_FILES.FILE_OPS, func.name)
    assert(type(path) == "string" and path ~= "", "Invalid file path")
    assert(type(mode) == "string" and mode ~= "", "Invalid file mode")
    assert(type(operation) == "function", "Operation must be a function")
    --xdbg:Log("Opening file: " .. path, LOG_FILES.FILE_OPS, func.name)
    local fil, err = io.open(path, mode)
    if not fil then 
        --xdbg:Log("Failed to open file: " .. tostring(err), LOG_FILES.ERRORS, func.name)
        return nil, err 
    end
    local ok, result = xpcall(function()
        --xdbg:Log("Executing operation on file: " .. path, LOG_FILES.FILE_OPS, func.name)
        local op_result = operation(fil)
        fil:close()
        return op_result == nil and true or op_result
    end, function(err)
        fil:close()
        --xdbg:Log("Error in operation: " .. tostring(err), LOG_FILES.ERRORS, func.name)
        return tostring(err)
    end)
    --xdbg:Log("Function completed with success: " .. tostring(ok), LOG_FILES.FILE_OPS, func.name)
    return ok and result or nil, ok and nil or result
end

local LOG_FILES = {EVENTS = "UIEvents.txt", FILE_OPS = "FileOps.txt", DATA_PROC = "DataProcessing.txt", CONFIG = "ConfigOps.txt", UI = "UIOps.txt", ERRORS = "AllErrors.txt"}
-- Optimized xdbg with conditional logging, pre-allocated buffers, and advanced features and enhanced task scheduling
local xdbg = (function()
    local cBuffer = setmetatable({
        print = {{}, { __mode = "v" }},
        save = {{}, { __mode = "v" }}
    }, { __index = function(t, k) return rawget(t, k) end })

    local MAX_BUFFER = 100
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local tasks = {
        print = {id = nil, interval = 0, co = nil},
        save = {id = nil, interval = 0, co = nil}
    }
    local logPath = "debug"
    local selfRef

    local xdbg_tostring = function(t) return string.format("xdbg[print=%d, save=%d]", #cBuffer.print[1], #cBuffer.save[1]) end

    local function getCaller(func_name)
        local caller = {name = func_name or "anonymous", line = "???"}
        if func_name then
            local info = debug.getinfo(2, "Sln")
            if info then caller.line = info.currentline or "???" end
            return caller
        end
        local level, call_stack = 2, {}
        while true do
            local info = debug.getinfo(level, "Sln")
            if not info then break end
            if info.what == "Lua" and info.name and not info.name:match("^(Log|Flush|_xdbg|getCaller)$") then
                caller.line = info.currentline or "???"
                table.insert(call_stack, 1, info.name)
            end
            level = level + 1
        end
        if #call_stack > 0 then caller.name = table.concat(call_stack, "/") end
        return caller
    end

    local function buildEntry(func, msg) return "[" .. timestamp .. "] " .. func .. " -> " .. msg end

    local function cancelTask(taskName, force)
        if tasks[taskName] and tasks[taskName].id then
            if force then
                tasks[taskName].id:cancel()
                tasks[taskName].id, tasks[taskName].co = nil, nil
            else
                tasks[taskName].interval = 0
            end
        end
    end

    local function preallocateTask(self, taskName, writeToFile)
        tasks[taskName].id = Task(function()
            tasks[taskName].co = coroutine.running()
            repeat
                if tasks[taskName].interval > 0 then
                    self:Flush(nil, writeToFile)
                    sleep(tasks[taskName].interval * 1000)
                    coroutine.yield()
                else
                    sleep(1000)
                    coroutine.yield()
                end
            until tasks[taskName].id.status == "terminated"
        end)
    end

    local function startTask(self, taskName, writeToFile)
        if tasks[taskName] then
            if not tasks[taskName].id or tasks[taskName].id.status == "terminated" then
                preallocateTask(self, taskName, writeToFile)
            end
            if tasks[taskName].id.status == "created" then
                tasks[taskName].id()
            elseif tasks[taskName].co and coroutine.status(tasks[taskName].co) == "suspended" then
                coroutine.resume(tasks[taskName].co)
            end
        end
    end

    local self = {
        Log = function(self, msg, logFile, func)
            func = getCaller(func)
            logFile = logFile or "Any.txt"
            local entry = buildEntry(func.name .. " / " .. func.line, msg)

            for nChild, bChild in pairs(paramsAsTable["debug"]) do
                if bChild and cBuffer[nChild] then
                    if nChild == "print" and tasks.print.interval == 0 then
                        -- If print interval is 0, print directly without caching
                        print(entry)
                    else
                        -- Otherwise, cache the message
                        table.insert(cBuffer[nChild][1], entry)
                        if #cBuffer[nChild][1] >= MAX_BUFFER then
                            self:Flush(nil, nChild == "save")
                        end
                    end
                end
            end

            return {filename = logFile, message = msg, formatted = entry, func = func.name, line = func.line}
        end,

        Flush = function(self, specificFile, writeToFile)
            local bufferKey = writeToFile and "save" or "print"
            local buffer = cBuffer[bufferKey][1]
            if #buffer > 0 then
                if writeToFile then
                    logPath = logPath or "debug"
                    assert(type(logPath) == "string", "logPath must be a string")
                    local dir = Dir(logPath)
                    if not dir.exists then dir:make() end
                    local path = logPath .. "/log.txt"
                    local fileDir = Dir(path:match("^(.*[\\/])"))
                    if not fileDir.exists then fileDir:make() end
                    local success, err = withFile(path, "a", function(f) f:write(table.concat(buffer, "\n")) end)
                    if not success then print("[Flush force writeToFile] *.txt: " .. tostring(err)) end
                else
                    print(table.concat(buffer, "\n"))
                end
                cBuffer[bufferKey][1] = {}
            end
            timestamp = os.date("%Y-%m-%d %H:%M:%S")
        end,

        Task = function(self, interval, action, param, force)
            local intValue = tonumber(interval)
            if intValue then
                assert(action == "save" or action == "print", "Invalid task action")
                logPath = (action == "save" and param) or logPath or "debug"
                tasks[action].interval = intValue

                if action == "print" and intValue == 0 then
                    -- If print interval is 0, cancel the task and clear the buffer
                    cancelTask("print", true)
                    self:Flush(nil, false) -- Flush any remaining messages
                else
                    if force then cancelTask(action, true) end
                    startTask(self, action, action == "save")
                end
            elseif interval == "stop" then
                if not action or action == "all" then
                    for taskName in pairs(tasks) do cancelTask(taskName, param == "force") end
                else
                    for taskName in action:gmatch("%S+") do cancelTask(taskName, param == "force") end
                end
            elseif interval == "save" and action then
                logPath = action
            end
        end,

        Status = function(self, taskName)
            if tasks[taskName] and tasks[taskName].id then
                return {
                    status = tasks[taskName].id.status,
                    interval = tasks[taskName].interval,
                    co_status = tasks[taskName].co and coroutine.status(tasks[taskName].co) or "none"
                }
            end
            return {status = "nil", interval = 0, co_status = "none"}
        end
    }

    selfRef = self
    setmetatable(self, { __tostring = xdbg_tostring })
    preallocateTask(self, "print", false)
    preallocateTask(self, "save", true)

    return self
end)()

-- Deep copy function to create a deep copy of a table
local function deep_copy(original)
    if type(original) ~= "table" then
        return original
    end
    local copy = {}
    local k, v = next(original)
    while k ~= nil do
        if type(k) == "string" and k == "next" then
            xdbg:Log("Skipping invalid key 'next' during deep_copy", LOG_FILES.ERRORS)
        else
            copy[k] = deep_copy(v)
        end
        k, v = next(original, k)
    end
    return copy
end

-- Merges default values into a target table, handling type mismatches
local function merge_defaults(target, default, parent_key)
    parent_key = parent_key or ""
    local result = type(target) == "table" and deep_copy(target) or {}
    local k, v = next(default)
    while k ~= nil do
        local current_key = parent_key == "" and tostring(k) or (parent_key .. "." .. tostring(k))
        if type(k) == "string" and k == "next" then
            xdbg:Log("Skipping invalid key 'next' in default at: " .. current_key, LOG_FILES.ERRORS)
        elseif type(v) == "table" then
            if type(result[k]) == "table" then
                -- Recursively merge nested tables
                result[k] = merge_defaults(result[k], v, current_key)
            else
                xdbg:Log("Type mismatch for key: " .. current_key .. " (expected table, got " .. type(result[k]) .. "), using default", LOG_FILES.CONFIG)
                result[k] = deep_copy(v)
            end
        elseif result[k] == nil then
            xdbg:Log("Adding missing key: " .. current_key .. " = " .. tostring(v), LOG_FILES.CONFIG)
            result[k] = deep_copy(v)
        elseif type(result[k]) ~= type(v) then
            xdbg:Log("Type mismatch for key: " .. current_key .. " (expected " .. type(v) .. ", got " .. type(result[k]) .. "), using default", LOG_FILES.CONFIG)
            result[k] = deep_copy(v)
        else
            xdbg:Log("Key already exists: " .. current_key .. " = " .. tostring(result[k]) .. ", default: " .. tostring(v), LOG_FILES.CONFIG)
        end
        k, v = next(default, k)
    end
    return result
end


-- Compares two tables for equality
local function tables_equal(t1, t2)
    if type(t1) ~= "table" or type(t2) ~= "table" then
        xdbg:Log("Type mismatch: t1=" .. type(t1) .. ", t2=" .. type(t2), LOG_FILES.CONFIG)
        return false
    end
    -- Use a safe iterator to avoid metatable issues
    local k, v = next(t1)
    while k ~= nil do
        if type(k) == "string" and k == "next" then
            xdbg:Log("Found invalid key 'next' in t1, skipping", LOG_FILES.ERRORS)
            return false
        end
        if t2[k] == nil then
            xdbg:Log("Key missing in t2: " .. tostring(k), LOG_FILES.CONFIG)
            return false
        end
        if type(v) == "table" then
            if not tables_equal(v, t2[k]) then
                xdbg:Log("Nested tables differ at key: " .. tostring(k), LOG_FILES.CONFIG)
                return false
            end
        elseif v ~= t2[k] then
            xdbg:Log("Values differ at key: " .. tostring(k) .. " (" .. tostring(v) .. " vs " .. tostring(t2[k]) .. ")", LOG_FILES.CONFIG)
            return false
        end
        k, v = next(t1, k)
    end
    k, v = next(t2)
    while k ~= nil do
        if type(k) == "string" and k == "next" then
            xdbg:Log("Found invalid key 'next' in t2, skipping", LOG_FILES.ERRORS)
            return false
        end
        if t1[k] == nil then
            xdbg:Log("Key missing in t1: " .. tostring(k), LOG_FILES.CONFIG)
            return false
        end
        k, v = next(t2, k)
    end
    xdbg:Log("Tables are equal", LOG_FILES.CONFIG)
    return true
end

-- Helper function to serialize a table to a string
local function table_to_string(tbl)
    if tbl == nil then
        return "nil"
    end
    if type(tbl) ~= "table" then
        return tostring(tbl)
    end
    local result = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            table.insert(result, tostring(k) .. " = " .. table_to_string(v))
        else
            table.insert(result, tostring(k) .. " = " .. tostring(v))
        end
    end
    return "{ " .. table.concat(result, ", ") .. " }"
end

-- Helper function to deserialize a comma-separated string to a table
local function string_to_table(str)
    if type(str) ~= "string" or str == "" then
        return {}
    end
    local result = {}
    for item in str:gmatch("[^,]+") do
        --result[#result + 1] = item -- Add item without explicit numeric index
        table.insert(result, item)
    end
    return result
end

-- Flattens tables for INI saving, ensuring all nested tables are converted to strings
local function flatten_for_ini(config)
    local result = deep_copy(config)
    local function flatten_recursive(tbl)
        -- If the table is an array of strings/numbers, flatten it into a string
        local is_array = true
        for k, v in pairs(tbl) do
            if type(k) ~= "number" or k > #tbl then
                is_array = false
                break
            end
        end
        if is_array then
            local items = {}
            for _, item in ipairs(tbl) do
                if type(item) == "table" then
                    table.insert(items, flatten_recursive(item))
                else
                    table.insert(items, tostring(item))
                end
            end
            return table.concat(items, ",") or ""
        end
        -- Otherwise, recurse into the table
        local sub_result = {}
        for k, v in pairs(tbl) do
            if type(v) == "table" then
                sub_result[k] = flatten_recursive(v)
            else
                sub_result[k] = tostring(v)
            end
        end
        return sub_result
    end
    for k, v in pairs(result) do
        if type(v) == "table" then
            result[k] = flatten_recursive(v)
            xdbg:Log("Flattened " .. tostring(k) .. " for INI: " .. table_to_string(result[k]), LOG_FILES.CONFIG)
        end
    end
    return result
end

-- Optimized config loading with minimal I/O
-- Loads and merges config with defaults, saves if updated
-- Args: default_config (table), ini_file (string)
-- Returns: Merged config table
local function load_config(default_config, ini_file)
    xdbg:Log("Starting config load for: " .. ini_file, LOG_FILES.CONFIG)

    if not default_config or type(default_config) ~= "table" then
        xdbg:Log("Invalid default_config: " .. tostring(default_config), LOG_FILES.ERRORS)
        return {}
    end

    local config = {}
    local ini_file_obj = File(ini_file)
    if not ini_file_obj.exists then
        xdbg:Log("Config file not found, creating: " .. ini_file, LOG_FILES.CONFIG)
        local save_config = flatten_for_ini(deep_copy(default_config))
        xdbg:Log("Saving default config: " .. table_to_string(save_config), LOG_FILES.CONFIG)
        local success, err = pcall(ini.save, ini_file, save_config)
        if not success then
            xdbg:Log("Failed to save default config: " .. tostring(err), LOG_FILES.ERRORS)
        end
        return save_config
    end

    local success, loaded_config = pcall(ini.load, ini_file)
    if success and type(loaded_config) == "table" then
        config = loaded_config
        xdbg:Log("Loaded config: " .. table_to_string(config), LOG_FILES.CONFIG)
    else
        xdbg:Log("Failed to load config file: " .. ini_file .. ", error: " .. tostring(loaded_config), LOG_FILES.ERRORS)
        config = {}
    end

    local merged_config = merge_defaults(config, default_config)
    xdbg:Log("Merged config before saving: " .. table_to_string(merged_config), LOG_FILES.CONFIG)

    if not tables_equal(config, merged_config) then
        xdbg:Log("Saving updated config: " .. ini_file, LOG_FILES.CONFIG)
        local save_config = flatten_for_ini(deep_copy(merged_config))
        xdbg:Log("Config to save: " .. table_to_string(save_config), LOG_FILES.CONFIG)
        local success, err = pcall(ini.save, ini_file, save_config)
        if success then
            xdbg:Log("Successfully saved updated config", LOG_FILES.CONFIG)
        else
            xdbg:Log("Failed to save updated config: " .. tostring(err), LOG_FILES.ERRORS)
        end
    else
        xdbg:Log("No updates needed for: " .. ini_file, LOG_FILES.CONFIG)
    end

    -- Flatten the merged config before returning
    local final_config = flatten_for_ini(deep_copy(merged_config))
    xdbg:Log("Config load completed for: " .. ini_file, LOG_FILES.CONFIG)
    return final_config or {}
end

-- Cache for default translations per language
local defaultTranslationsCache = {}
-- Cache for loaded language data
local langCache = {}

-- Optimized language loading with memoization
-- Loads and caches language files with defaults
-- Args: lang_code (string, e.g., "en" or "data/lang/en.json"), default_translations (table, optional)
-- Returns: Language table
local function load_language(lang_code, default_translations)
    xdbg:Log("Starting language load for code: " .. tostring(lang_code), LOG_FILES.CONFIG)

    if not lang_code then
        xdbg:Log("Invalid language code: " .. tostring(lang_code), LOG_FILES.ERRORS)
        return default_translations or {}
    end

    local extracted_lang = lang_code:match("([^/]+)%.json$") or lang_code
    if extracted_lang ~= lang_code then
        xdbg:Log("Extracted language code from full path: " .. tostring(extracted_lang), LOG_FILES.CONFIG)
    end

    if not extracted_lang:match("^%w+$") then
        xdbg:Log("Invalid language code after extraction: " .. tostring(extracted_lang), LOG_FILES.ERRORS)
        return default_translations or {}
    end
    lang_code = extracted_lang

    if default_translations then
        defaultTranslationsCache[lang_code] = default_translations
        xdbg:Log("Cached default translations for: " .. lang_code, LOG_FILES.CONFIG)
    end

    local final_defaults = default_translations or defaultTranslationsCache[lang_code]
    if not final_defaults then
        xdbg:Log("No default translations available for: " .. lang_code, LOG_FILES.ERRORS)
        return default_translations or {}
    end

    if langCache[lang_code] then
        xdbg:Log("Returning cached language: " .. lang_code, LOG_FILES.CONFIG)
        return langCache[lang_code]
    end

    local lang_file = "data/lang/" .. lang_code .. ".json"
    local lang_dir = Dir("data/lang")
    if not lang_dir.exists then
        xdbg:Log("Creating directory: data/lang", LOG_FILES.CONFIG)
        lang_dir:make()
    end

    xdbg:Log("Final defaults: " .. table_to_string(final_defaults), LOG_FILES.CONFIG)

    local lang_file_obj = File(lang_file)
    local lang_data = {}
    if lang_file_obj.exists then
        xdbg:Log("Loading language file: " .. lang_file, LOG_FILES.CONFIG)
        local success, result = pcall(json.load, lang_file)
        if success and type(result) == "table" then
            lang_data = result
            xdbg:Log("Loaded language data: " .. table_to_string(lang_data), LOG_FILES.CONFIG)
        else
            xdbg:Log("Failed to load language file: " .. lang_file .. ", error: " .. tostring(result), LOG_FILES.ERRORS)
        end
    else
        xdbg:Log("Language file not found: " .. lang_file, LOG_FILES.CONFIG)
    end

    local merged_data = merge_defaults(lang_data, final_defaults)
    if not tables_equal(lang_data, merged_data) then
        xdbg:Log("Saving updated language file: " .. lang_file, LOG_FILES.CONFIG)
        local success, err = pcall(json.save, lang_file, merged_data)
        if not success then
            xdbg:Log("Failed to save language file: " .. lang_file .. ", error: " .. tostring(err), LOG_FILES.ERRORS)
        end
    else
        xdbg:Log("No updates needed for: " .. lang_file, LOG_FILES.CONFIG)
    end

    langCache[lang_code] = merged_data
    xdbg:Log("Language load completed for: " .. lang_code, LOG_FILES.CONFIG)
    return merged_data or {}
end

-- Optimized safe_operation
-- Executes a function with error handling
-- Args: operation (function), fallback (optional function)
-- Returns: success (bool), result/error, status message
-- How it works: Runs operation in xpcall, logs errors, calls fallback if provided
local function safe_operation(operation, fallback)
    local func = (debug.getinfo(2, "n").name or debug.getinfo(1, "n").name or "anonymous")
    xdbg:Log("Function started ( "..func.." )", LOG_FILES.DATA_PROC)
    local error_handler = function(err)
        return {
            message = tostring(err),
            trace = debug.traceback("", 2),
            timestamp = os.date("%Y-%m-%d %H:%M:%S")
        }
    end
    xdbg:Log("Executing operation ( "..func.." )", LOG_FILES.DATA_PROC)
    local success, result = xpcall(operation, error_handler)
    if not success then
        local error_info = result
        xdbg:Log("[" .. error_info.timestamp .. "] Error: " .. error_info.message .. "\n" .. error_info.trace, LOG_FILES.ERRORS)
        if type(fallback) == "function" then 
            xdbg:Log("Calling fallback ( "..func.." )", LOG_FILES.DATA_PROC)
            pcall(fallback, error_info) 
        end
        xdbg:Log("Function completed with failure ( "..func.." )", LOG_FILES.DATA_PROC)
        return nil, error_info, "Operation failed: " .. tostring(operation)
    end
    xdbg:Log("Function completed with success ( "..func.." )", LOG_FILES.DATA_PROC)
    return success, result, "Operation succeeded: " .. tostring(operation)
end

local function handleError(err)
    xdbg:Log("Error: " .. tostring(err), LOG_FILES.ERRORS)
    return debug.traceback(tostring(err))
end

local function executeWithFallback(operation, fallback)
    local success, result = xpcall(operation, handleError)
    if not success and fallback then
        fallback(result)
    end
    return success, result
end

-- Optimized construct with precomputed constants and lazy initialization
-- Creates a compression/decompression utility
-- Returns: Function returning utility table
-- How it works: Predefines base64 helpers, lazily initializes compression tools
local construct = (function()
    xdbg:Log("Function started", LOG_FILES.DATA_PROC)
    local char, byte, sub, gsub, format = string.char, string.byte, string.sub, string.gsub, string.format
    local insert, concat = table.insert, table.concat
    local os_time, tonumber = os.time, tonumber

    local BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local BASE64_LOOKUP = setmetatable({}, {__index = function(t, k) for i = 0, 63 do t[BASE64_CHARS:sub(i+1, i+1)] = i end return t[k] end})

    -- Encodes data to base64
    local function base64_encode(data)
        local result = {}
        local len = #data
        local remainder = len % 3
        len = len - remainder
        for i = 1, len, 3 do
            local a, b, c = byte(data, i, i+2)
            local n = a * 0x10000 + b * 0x100 + c
            insert(result, BASE64_CHARS:sub((n >> 18) & 0x3F + 1, (n >> 18) & 0x3F + 1))
            insert(result, BASE64_CHARS:sub((n >> 12) & 0x3F + 1, (n >> 12) & 0x3F + 1))
            insert(result, BASE64_CHARS:sub((n >> 6) & 0x3F + 1, (n >> 6) & 0x3F + 1))
            insert(result, BASE64_CHARS:sub(n & 0x3F + 1, n & 0x3F + 1))
        end
        if remainder > 0 then
            local a, b = byte(data, len + 1, len + 2)
            local n = (a or 0) * 0x10000 + (b or 0) * 0x100
            insert(result, BASE64_CHARS:sub((n >> 18) & 0x3F + 1, (n >> 18) & 0x3F + 1))
            insert(result, BASE64_CHARS:sub((n >> 12) & 0x3F + 1, (n >> 12) & 0x3F + 1))
            insert(result, remainder == 2 and BASE64_CHARS:sub((n >> 6) & 0x3F + 1, (n >> 6) & 0x3F + 1) or "=")
            insert(result, "=")
        end
        return concat(result)
    end

    -- Decodes base64 data to binary
    local function base64_decode(data)
        data = gsub(data, "[^" .. BASE64_CHARS .. "=]", "")
        local result = {}
        local len = #data
        local pad = data:sub(-2) == "==" and 2 or data:sub(-1) == "=" and 1 or 0
        for i = 1, len - 4, 4 do
            local a, b, c, d = BASE64_LOOKUP[data:sub(i, i)], BASE64_LOOKUP[data:sub(i+1, i+1)], BASE64_LOOKUP[data:sub(i+2, i+2)], BASE64_LOOKUP[data:sub(i+3, i+3)]
            local n = a << 18 | b << 12 | c << 6 | d
            insert(result, char((n >> 16) & 0xFF))
            insert(result, char((n >> 8) & 0xFF))
            insert(result, char(n & 0xFF))
        end
        if len % 4 == 0 then
            local i = len - 3
            local a, b, c, d = BASE64_LOOKUP[data:sub(i, i)], BASE64_LOOKUP[data:sub(i+1, i+1)], BASE64_LOOKUP[data:sub(i+2, i+2)], BASE64_LOOKUP[data:sub(i+3, i+3)]
            local n = a << 18 | b << 12 | c << 6 | d
            insert(result, char((n >> 16) & 0xFF))
            if pad < 2 then insert(result, char((n >> 8) & 0xFF)) end
            if pad < 1 then insert(result, char(n & 0xFF)) end
        end
        return concat(result)
    end

    -- Executes a callback with a temporary file, cleaning up afterward
    local function with_tempfile(pattern, callback)
        local temp_path = "temp_" .. os_time() .. (pattern or "")
        local success, result = pcall(callback, temp_path)
        pcall(os.remove, temp_path)
        return success and result or nil
    end

    xdbg:Log("Function completed, returning factory", LOG_FILES.DATA_PROC)
    return function()
        xdbg:Log("Creating compression utility", LOG_FILES.DATA_PROC)
        local util = {
            decompress = {
                unzipBase64 = function(base64Data, extractDir, extractValidate)
                    if not base64Data then return nil, "No data" end
                    return with_tempfile(".zip", function(tempZip)
                        local zipData = base64_decode(base64Data)
                        withFile(tempZip, "wb", function(f) f:write(zipData) end)
                        local zip = Zip(tempZip, "read")
                        local dir = Dir(extractDir)
                        if not dir.exists and not dir:make() then error("Failed to create directory: " .. extractDir) end
                        zip:extractall(dir)
                        zip:close()
                        return extractValidate and withFile(extractDir .. "/" .. extractValidate, "rb", function(f) return true end) or true
                    end)
                end
            },
            compress = {
                ToBase64 = function(inputPath, outputPath)
                    return with_tempfile(".zip", function(tempZip)
                        local zip = Zip(tempZip, "write", 9)
                        zip:add(inputPath, inputPath:match("[^/\\]+$"))
                        zip:close()
                        local zipData = withFile(tempZip, "rb", function(f) return f:read("*a") end)
                        local b64 = base64_encode(zipData)
                        if outputPath then
                            withFile(outputPath, "w", function(f) f:write(b64) end)
                            return outputPath
                        end
                        return b64
                    end)
                end
            },
            base64 = {encode = base64_encode, decode = base64_decode}
        }
        xdbg:Log("Utility created", LOG_FILES.DATA_PROC)
        return util
    end
end)()

    -- Pure Lua MD5 Implementation (unchanged, for hash_method = "md5")
    local function md5_sum(file_path)
        local file = File(file_path)
        if not file.exists then return nil end

        local function bit_xor(a, b) return a ~ b end
        local function bit_and(a, b) return a & b end
        local function bit_or(a, b) return a | b end
        local function bit_not(a) return ~a end
        local function bit_left(a, s) return a << s end
        local function bit_right(a, s) return a >> s end

        local function F(x, y, z) return bit_or(bit_and(x, y), bit_and(bit_not(x), z)) end
        local function G(x, y, z) return bit_or(bit_and(x, z), bit_and(y, bit_not(z))) end
        local function H(x, y, z) return bit_xor(bit_xor(x, y), z) end
        local function I(x, y, z) return bit_xor(y, bit_or(x, bit_not(z))) end

        local function FF(a, b, c, d, x, s, ac)
            a = a + F(b, c, d) + x + ac
            a = bit_and(a, 0xFFFFFFFF)
            a = bit_or(bit_left(a, s), bit_right(a, 32 - s))
            return bit_and(a + b, 0xFFFFFFFF)
        end

        local function GG(a, b, c, d, x, s, ac)
            a = a + G(b, c, d) + x + ac
            a = bit_and(a, 0xFFFFFFFF)
            a = bit_or(bit_left(a, s), bit_right(a, 32 - s))
            return bit_and(a + b, 0xFFFFFFFF)
        end

        local function HH(a, b, c, d, x, s, ac)
            a = a + H(b, c, d) + x + ac
            a = bit_and(a, 0xFFFFFFFF)
            a = bit_or(bit_left(a, s), bit_right(a, 32 - s))
            return bit_and(a + b, 0xFFFFFFFF)
        end

        local function II(a, b, c, d, x, s, ac)
            a = a + I(b, c, d) + x + ac
            a = bit_and(a, 0xFFFFFFFF)
            a = bit_or(bit_left(a, s), bit_right(a, 32 - s))
            return bit_and(a + b, 0xFFFFFFFF)
        end

        local a, b, c, d = 0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476
        local content = file:read() or ""
        local len = #content * 8
        content = content .. string.char(0x80)
        while (#content % 64) ~= 56 do content = content .. string.char(0) end
        content = content .. string.pack("<I8", len)

        for i = 1, #content, 64 do
            local chunk = content:sub(i, i + 63)
            local x = {}
            for j = 1, 64, 4 do
                x[#x + 1] = string.unpack("<I4", chunk:sub(j, j + 3))
            end

            local aa, bb, cc, dd = a, b, c, d
            a = FF(a, b, c, d, x[1], 7, 0xD76AA478)
            d = FF(d, a, b, c, x[2], 12, 0xE8C7B756)
            c = FF(c, d, a, b, x[3], 17, 0x242070DB)
            b = FF(b, c, d, a, x[4], 22, 0xC1BDCEEE)
            a = FF(a, b, c, d, x[5], 7, 0xF57C0FAF)
            d = FF(d, a, b, c, x[6], 12, 0x4787C62A)
            c = FF(c, d, a, b, x[7], 17, 0xA8304613)
            b = FF(b, c, d, a, x[8], 22, 0xFD469501)
            a = FF(a, b, c, d, x[9], 7, 0x698098D8)
            d = FF(d, a, b, c, x[10], 12, 0x8B44F7AF)
            c = FF(c, d, a, b, x[11], 17, 0xFFFF5BB1)
            b = FF(b, c, d, a, x[12], 22, 0x895CD7BE)
            a = FF(a, b, c, d, x[13], 7, 0x6B901122)
            d = FF(d, a, b, c, x[14], 12, 0xFD987193)
            c = FF(c, d, a, b, x[15], 17, 0xA679438E)
            b = FF(b, c, d, a, x[16], 22, 0x49B40821)

            a = GG(a, b, c, d, x[2], 5, 0xF61E2562)
            d = GG(d, a, b, c, x[7], 9, 0xC040B340)
            c = GG(c, d, a, b, x[12], 14, 0x265E5A51)
            b = GG(b, c, d, a, x[1], 20, 0xE9B6C7AA)
            a = GG(a, b, c, d, x[6], 5, 0xD62F105D)
            d = GG(d, a, b, c, x[11], 9, 0x02441453)
            c = GG(c, d, a, b, x[16], 14, 0xD8A1E681)
            b = GG(b, c, d, a, x[5], 20, 0xE7D3FBC8)
            a = GG(a, b, c, d, x[10], 5, 0x21E1CDE6)
            d = GG(d, a, b, c, x[15], 9, 0xC33707D6)
            c = GG(c, d, a, b, x[4], 14, 0xF4D50D87)
            b = GG(b, c, d, a, x[9], 20, 0x455A14ED)
            a = GG(a, b, c, d, x[14], 5, 0xA9E3E905)
            d = GG(d, a, b, c, x[3], 9, 0xFCEFA3F8)
            c = GG(c, d, a, b, x[8], 14, 0x676F02D9)
            b = GG(b, c, d, a, x[13], 20, 0x8D2A4C8A)

            a = HH(a, b, c, d, x[6], 4, 0xFFFA3942)
            d = HH(d, a, b, c, x[9], 11, 0x8771F681)
            c = HH(c, d, a, b, x[12], 16, 0x6D9D6122)
            b = HH(b, c, d, a, x[15], 23, 0xFDE5380C)
            a = HH(a, b, c, d, x[2], 4, 0xA4BEEA44)
            d = HH(d, a, b, c, x[5], 11, 0x4BDECFA9)
            c = HH(c, d, a, b, x[8], 16, 0xF6BB4B60)
            b = HH(b, c, d, a, x[11], 23, 0xBEBFBC70)
            a = HH(a, b, c, d, x[14], 4, 0x289B7EC6)
            d = HH(d, a, b, c, x[1], 11, 0xEAA127FA)
            c = HH(c, d, a, b, x[4], 16, 0xD4EF3085)
            b = HH(b, c, d, a, x[7], 23, 0x04881D05)
            a = HH(a, b, c, d, x[10], 4, 0xD9D4D039)
            d = HH(d, a, b, c, x[13], 11, 0xE6DB99E5)
            c = HH(c, d, a, b, x[16], 16, 0x1FA27CF8)
            b = HH(b, c, d, a, x[3], 23, 0xC4AC5665)

            a = II(a, b, c, d, x[1], 6, 0xF4292244)
            d = II(d, a, b, c, x[8], 10, 0x432AFF97)
            c = II(c, d, a, b, x[15], 15, 0xAB9423A7)
            b = II(b, c, d, a, x[6], 21, 0xFC93A039)
            a = II(a, b, c, d, x[13], 6, 0x655B59C3)
            d = II(d, a, b, c, x[4], 10, 0x8F0CCC92)
            c = II(c, d, a, b, x[11], 15, 0xFFEFF47D)
            b = II(b, c, d, a, x[2], 21, 0x85845DD1)
            a = II(a, b, c, d, x[9], 6, 0x6FA87E4F)
            d = II(d, a, b, c, x[16], 10, 0xFE2CE6E0)
            c = II(c, d, a, b, x[7], 15, 0xA3014314)
            b = II(b, c, d, a, x[14], 21, 0x4E0811A1)
            a = II(a, b, c, d, x[5], 6, 0xF7537E82)
            d = II(d, a, b, c, x[12], 10, 0xBD3AF235)
            c = II(c, d, a, b, x[3], 15, 0x2AD7D2BB)
            b = II(b, c, d, a, x[10], 21, 0xEB86D391)

            a = bit_and(a + aa, 0xFFFFFFFF)
            b = bit_and(b + bb, 0xFFFFFFFF)
            c = bit_and(c + cc, 0xFFFFFFFF)
            d = bit_and(d + dd, 0xFFFFFFFF)
        end

        return string.format("%08x%08x%08x%08x", a, b, c, d)
    end

-- Optimized parsing with buffered I/O and reduced logging
-- Parses BOM or PINS files into structured data
-- Left unchanged per your request, existing logs sufficient
local function parseFile(fileOrText, fileType, func_name)
    xdbg:Log("Starting file parsing for type: " .. fileType, LOG_FILES.DATA_PROC)
    local patterns = {
        BOM = "^%s*(%S+)%s*,%s*([%d%.%-]+),%s*([%d%.%-]+),%s*([%d%.%-]+),%s*(%S+)%s*,%s*%((.)%)%,%s*([%d%.%-]+),%s*(%S+),%s*'([^']*)',%s*'([^']*)';",
        PINS = {
            header = "^Part%s+(%S+)%s+%((%w+)%)",
            data1 = "^%s*(%S+)%s+(%S+)%s+([%d%.%-]+)%s+([%d%.%-]+)%s+([%d%.%-]+)%s+(%S+)$",
            data2 = '^%s*"(%S+)","(%S+)","([%d%.%-]+)","([%d%.%-]+)","([%w]+)","(%S+)","",""$'
        }
    }

    local extracts = {}
    local current_part
    local process = fileType == "BOM" and function(line)
        local part, x, y, rot, grid, typ, size, shp, device, outline = line:match(patterns.BOM)
        if not part then return end
        x, y, rot = tonumber(x), tonumber(y), tonumber(rot)
        if x and y and (shp == "PTH" or shp == "RADIAL") and
        device ~= "NOT_LOADED" and device ~= "NOT_LOAD" and
        device ~= "NO_LOADED" and device ~= "NO_LOAD" then
            local existing_part
            for _, extract in ipairs(extracts) do
                if extract.part == part and extract.type == typ then
                    existing_part = extract
                    break
                end
            end
            if not existing_part then
                existing_part = {part = part, type = typ, data = {}, seen_data = setmetatable({}, {__mode = "k"})}
                table.insert(extracts, existing_part)
            end
            local data_key = x .. "|" .. y .. "|" .. rot
            if not existing_part.seen_data[data_key] then
                table.insert(existing_part.data, {x = x, y = y, rot = rot, grid = grid, shp = shp, device = device, outline = outline})
                existing_part.seen_data[data_key] = true
            end
        end
    end or fileType == "PINS" and function(line)
        if line:match(patterns.PINS.header) then
            local part, typ = line:match(patterns.PINS.header)
            if part and typ then
                current_part = {part = part, type = typ, data = {}}
                table.insert(extracts, current_part)
            end
        else
            local part, pin, x, y, layer, net
            if line:match(patterns.PINS.data1) then
                pin, _, x, y, layer, net = line:match(patterns.PINS.data1)
            elseif line:match(patterns.PINS.data2) then
                part, pin, x, y, layer, net = line:match(patterns.PINS.data2)
            end
            if part or pin then
                x, y = tonumber(x), tonumber(y)
                if x and y then
                    local target_part = part and (function()
                        for _, p in ipairs(extracts) do if p.part == part then return p end end
                        local new_part = {part = part, type = layer:sub(1, 1), data = {}}
                        table.insert(extracts, new_part)
                        return new_part
                    end)() or current_part
                    if target_part then
                        local layer_num = layer == "Top" and 1 or layer == "Bottom" and 2 or tonumber(layer)
                        if layer_num then
                            table.insert(target_part.data, {pin = pin, name = pin, x = x, y = y, layer = layer_num, net = net})
                        end
                    end
                end
            end
        end
    end or function() xdbg:Log(">>>> unknown file type: " .. fileType, LOG_FILES.DATA_PROC) return end

    local lines = type(fileOrText) == "string" and fileOrText:gmatch("[^\r\n]+") or fileOrText:lines()
    for line in lines do
        line = line:gsub("^%s*(.-)%s*$", "%1")
        if line ~= "" then process(line) end
    end
    xdbg:Log("Parsed " .. #extracts .. " entries for " .. fileType, LOG_FILES.DATA_PROC)
    return extracts
end

local mtasks = {}
-- get_measurements: Autodetects unit from a file, updates value.text, and flickers value.bgcolor
-- Args:
--   file (string): Path to the file to read
--   value (object): Object with text and bgcolor properties (e.g., a UI element)
-- Returns:
--   detected_unit (string): Detected unit ("cm" or "inch")
--   factor (number): Conversion factor for the unit (1 for cm, 25.4 for inch)
local function get_measurements(file, value)
    local factor = {["cm"] = 1, ["inch"] = 25.4}

    -- Autodetect the unit from the file
    local detected_unit, autodetect_success
    local result = withFile(file, "r", function(f)
        local content = f:read("*a")
        return content:lower():match("inch") and "inch" or "cm"
    end)

    if result then
        detected_unit = result
        autodetect_success = true
        value.text = detected_unit
        xdbg:Log("Autodetected unit for file " .. tostring(file) .. ": " .. detected_unit, LOG_FILES.DATA_PROC)
    else
        detected_unit = "cm"
        autodetect_success = false
        value.text = detected_unit
        xdbg:Log("Failed to autodetect unit for file " .. tostring(file) .. ", defaulting to 'cm'", LOG_FILES.ERRORS)
    end
    
    --if mtasks[value] then print("<><><><><><><> Task Before status ?> "..(mtasks[value].status)) end
    -- Async loop: flicker colors with decreasing sleep duration
    if mtasks[value] == nil or 
    (mtasks[value] and (mtasks[value].status ~= "running" and mtasks[value].status ~= "sleeping")) then
        mtasks[value] = async(function()
            -- Define the flickering parameters
            local _bgcolor = value.bgcolor
            local colors = {0xf41421, _bgcolor, 0x097969}
            local iterations = 20
            local start_sleep = 100
            local end_sleep = 50
            local sleep_step = (start_sleep - end_sleep) / (iterations - 1) -- 400 / 14 ≈ 28.57ms
            for i = 1, iterations do
                local sleep_duration = math.floor(start_sleep - (i - 1) * sleep_step)
                value.bgcolor = colors[(i - 1) % 3 + 1]
                sleep(sleep_duration)
            end
        end)
        --print("<><><><><><><> Task After status ?> "..(mtasks[value].status))
        mtasks[value].after = function()
            -- Set final color based on autodetection success
            local final_color = autodetect_success and 0x097969 or 0xff8f00 -- Green for success, yellow for failure
            value.bgcolor = final_color
            value.fgcolor = autodetect_success and 0xffffff or 0x000000
            xdbg:Log("Set final bgcolor to " .. string.format("0x%06x", final_color) .. " for file " .. tostring(file), LOG_FILES.DATA_PROC)
            xdbg:Log("Task completed and removed for value object for file " .. tostring(file), LOG_FILES.DATA_PROC)
            mtasks[value] = nil
        end
    end
    return detected_unit, factor[detected_unit]
end

-- Optimized CSV generation with inline processing and minimal allocations
-- Generates CSV files from BOM and PINS data
-- Args: components (UI components table)
-- Returns: Table with error and success status
-- How it works: Parses files, builds CSV lines, writes to disk with progress updates
local function generateCSV(components)
    local func_name = "GenerateCSV"
    local window = components.window
    window.cursor = "wait"
    xdbg:Log("Function started", LOG_FILES.DATA_PROC)

    local pb, pbLabel = components.pb, components.pbLabel
    pb.position = 0
    pbLabel:tofront()

    -- String pool
    local string_pool = setmetatable({}, { __mode = "k" })
    local function pool_format(template, ...)
        local key = template .. table.concat({...}, "|")
        if not string_pool[key] then
            string_pool[key] = string.format(template, ...)
        end
        return string_pool[key]
    end

    -- Updates progress bar and label
    local function update_progress(increment, colour, message)
        xdbg:Log("Updating progress with increment: " .. tostring(increment), LOG_FILES.DATA_PROC)
        pb.position = math.min(pb.position + (increment or 0), 100)
        pb.fgcolor = colour or (pb.position == 100 and 0x097969 or 0x3D85C6)
        pbLabel.text = pool_format("%s (%d%%)", message or "Processing...", math.floor(pb.position))
        pbLabel.bgcolor, pbLabel.fgcolor = pb.fgcolor, 0xFFFFFF
        ui.update()
        xdbg:Log(pbLabel.text, LOG_FILES.DATA_PROC)
    end

    local success_status = {top = false, bot = false}
    local factor = {["cm"] = 1, ["inch"] = 25.4}

    xdbg:Log("Starting pcall for CSV generation", LOG_FILES.DATA_PROC)
    local overall_success, err = safe_operation(function()
        -- Validate program name
        if components.program.input.text == "" then
            xdbg:Log("No program name, prompting user", LOG_FILES.UI)
            if ui.confirm("No PN type, use '1234' as default PN?", "ERROR / INVALID DATA") ~= "yes" then
                update_progress(0, 0xFF5733, "GenerateDeclined")
                return
            end
            components.program.input.text = "1234"
            xdbg:Log("Set default program name to '1234'", LOG_FILES.UI)
        end

        -- Validate BOM file
        local bomfile = components.bomsplit.input.text
        if not bomfile or bomfile == "Click to select BOMSPLIT" then
            update_progress(0, 0xFF5733, "Error occurred")
            ui.error("Missing BOM file path.\nSelect a valid BOMSPLIT file.", "ERROR")
            components.bomsplit.input.text = "Click to select BOMSPLIT"
            xdbg:Log("Missing BOM file path", LOG_FILES.ERRORS)
            return
        end

        -- Validate unit settings
        if not factor[components.bomsplit.measure.text] then
            xdbg:Log("Invalid unit for bomsplit: " .. tostring(components.bomsplit.measure.text) .. ", defaulting to 'cm'", LOG_FILES.ERRORS)
            components.bomsplit.measure.text = "cm"
        end
        local bom_factor = factor[components.bomsplit.measure.text]

        local pinsfile = components.pincad.input.text
        if pinsfile and pinsfile ~= "" and pinsfile ~= "Click to select PINS" then
            if not factor[components.pincad.measure.text] then
                xdbg:Log("Invalid unit for pincad: " .. tostring(components.pincad.measure.text) .. ", defaulting to 'cm'", LOG_FILES.ERRORS)
                components.pincad.measure.text = "cm"
            end
        end
        local pins_factor = factor[components.pincad.measure.text]

        local client = components.client.selectBox.text or "UNKNOWN_CLIENT"
        local partnumber = components.program.input.text
        xdbg:Log("Inputs: bomfile=" .. bomfile .. ", pinsfile=" .. tostring(pinsfile) .. ", client=" .. client .. ", partnumber=" .. partnumber .. ", bom_unit=" .. components.bomsplit.measure.text .. ", pins_unit=" .. components.pincad.measure.text, LOG_FILES.DATA_PROC)

        update_progress(5, nil, "Getting & saving configuration")

        -- Parse BOM file
        local bomData = withFile(bomfile, "r", function(f)
            update_progress(10, nil, "Parsing BOM file")
            return parseFile(f, "BOM", "generate_csv:BOM")
        end)

        if not bomData then
            update_progress(0, 0xFF5733, "Error occurred")
            ui.error("Process BOM data has failed.\nSelect another BOMSPLIT FILE", "ERROR")
            components.bomsplit.input.text = "Click to select BOMSPLIT"
            xdbg:Log("Process BOM data has failed", LOG_FILES.DATA_PROC)
            return
        end
        update_progress(25, nil, "BOM parsed successfully")

        -- Parse PINS file if provided
        local pinsData
        if pinsfile and pinsfile ~= "" and pinsfile ~= "Click to select PINS" then
            pinsData = withFile(pinsfile, "r", function(f)
                update_progress(10, nil, "Parsing PINS file")
                return parseFile(f, "PINS", "generate_csv:PINS")
            end)
            if not pinsData then
                components.pincad.input.text = "Click to select PINS"
                xdbg:Log("Process PINS data has failed", LOG_FILES.DATA_PROC)
                if ui.confirm("No pins on bottom!\nContinue?", "Information") ~= "yes" then
                    update_progress(pb.position, 0xFF5733, "GenerateDeclined")
                    return
                else
                    update_progress(pb.position, 0xB4BF00, "GenerateDeclined")
                end
            else
                update_progress(30, nil, "PINS parsed successfully")
            end
        end

        -- Generate TOP-side CSV
        update_progress(10, nil, "Generating TOP-side CSV")
        local top_lines = {T = {}, B = {}}
        for _, bom_data in ipairs(bomData) do
            if bom_data.type == "T" or bom_data.type == "B" then
                local side = bom_data.type
                local lines = top_lines[side]
                for _, bom_entry in ipairs(bom_data.data) do
                    local pn = client .. "-" .. (bom_entry.device or "NO_CLIENT")
                    local x = (bom_entry.x or 0) * bom_factor
                    local y = (bom_entry.y or 0) * bom_factor
                    local rot = bom_entry.rot or 0
                    local part = bom_data.part or "MISSING_PART"
                    table.insert(lines, part .. "," .. string.format("%.2f", x) .. "," .. string.format("%.2f", y) .. "," .. string.format("%.2f", rot) .. "," .. pn .. "," .. pn .. "\n")
                end
            end
        end

        for side, content in pairs(top_lines) do
            if #content > 0 then
                local path = partnumber .. "_faza" .. (side == "T" and 1 or 2) .. "_TOP.csv"
                xdbg:Log("Writing TOP CSV to: " .. path, LOG_FILES.DATA_PROC)
                success_status[side:lower()] = withFile(path, "w", function(f) f:write(table.concat(content)) end)
            end
        end

        -- Generate BOT-side CSV if pinsData exists
        if pinsData then
            update_progress(20, nil, "Generating BOT-side CSV")
            local bot_lines = {T = {}, B = {}}
            local pin_lookup = {}
            for _, pins_data in ipairs(pinsData) do
                pin_lookup[pins_data.part] = pins_data
            end
            for _, bom_data in ipairs(bomData) do
                local pins_data = pin_lookup[bom_data.part]
                if pins_data and pins_data.type == bom_data.type then
                    local side = bom_data.type
                    local lines = bot_lines[side]
                    for _, bom_entry in ipairs(bom_data.data) do
                        for _, pins_entry in ipairs(pins_data.data) do
                            local pn = client .. "-" .. (bom_entry.device or "NO_CLIENT")
                            local x = (pins_entry.x or 0) * pins_factor
                            local y = (pins_entry.y or 0) * pins_factor
                            local part = bom_data.part or "MISSING_PART"
                            local pin = pins_entry.pin or "X"
                            table.insert(lines, part .. "." .. pin .. "," .. string.format("%.2f", x) .. "," .. string.format("%.2f", y) .. ",0," .. pn .. ",THD\n")
                        end
                    end
                end
            end
            for side, content in pairs(bot_lines) do
                if #content > 0 then
                    local path = partnumber .. "_faza" .. (side == "T" and 1 or 2) .. "_BOT.csv"
                    xdbg:Log("Writing BOT CSV to: " .. path, LOG_FILES.DATA_PROC)
                    success_status[side:lower()] = withFile(path, "w", function(f) f:write(table.concat(content)) end)
                end
            end
        end

        update_progress(100, 0x097969, "Processing completed")
        if PREP_FILES.sound.click then
            xdbg:Log("Playing completion sound", LOG_FILES.UI)
            PREP_FILES.sound.click:play()
        end
        xdbg:Log("Processing completed successfully", LOG_FILES.DATA_PROC)
    end)

    if not overall_success then
        update_progress(0, 0xFF5733, "Error occurred")
        ui.error("Unexpected error occurred\nConversion not fully happened\nUsing the converted file is NOT advised\n\nError: " .. tostring(err), "CONVERSION FAIL")
        xdbg:Log("Process failed: " .. tostring(err), LOG_FILES.ERRORS)
    end
    xdbg:Log("Function completed with success: " .. tostring(overall_success), LOG_FILES.DATA_PROC)
    window.cursor = "arrow"
    return {error = err, success = success_status}
end

-- Optimized UI update with minimal redraws
-- Updates UI elements with language translations
-- Args: components (UI table), lang (language table)
-- How it works: Sets UI text from lang, updates display
local function update_ui_with_language(components, lang)
    xdbg:Log("Function started", LOG_FILES.EVENTS)
    local lang_table = load_language(lang)
    local config = components.config
    if lang_table then
            -- Dynamic DPI scaling function
        local max_scale = 2
        local scale_factor = 1 + (max_scale - 1) * (ui.dpi - 1) / (3 - 1)
        local scaled_size = math.floor(35 * scale_factor)
        --[[local function scale_with_dpi(base_size, dpi, max_scale)
            max_scale = max_scale or 1.5
            local scale_factor = 1 + (max_scale - 1) * (dpi - 1) / (3 - 1)
            return base_size * scale_factor
        end]]
        
        -- Load language-specific icon
        if lang == "en" then
            xdbg:Log("Loading English icon", LOG_FILES.CONFIG)
            components.language.icon:load(PREP_FILES.ico.en, scaled_size, scaled_size)
        elseif lang == "ro" then
            xdbg:Log("Loading Romanian icon", LOG_FILES.CONFIG)
            components.language.icon:load(PREP_FILES.ico.ro, scaled_size, scaled_size)
        else
            xdbg:Log("Loading default icon", LOG_FILES.CONFIG)
            components.language.icon:load(PREP_FILES.ico.earth, scaled_size, scaled_size)
        end
        
        xdbg:Log("Updating UI with language", LOG_FILES.EVENTS)
        components.GenerateButton.text = lang_table.Buttons.Generate
        components.bomsplit.input.text = config.Last.BOMSplitPath or lang_table.Buttons.BOMSplitPath
        components.pincad.input.text = config.Last.PINSCadPath or lang_table.Buttons.PINSCadPath
        components.bomsplit.label.text = lang_table.Labels.BOMSplit
        components.pincad.label.text = lang_table.Labels.PINSCad
        components.client.label.text = lang_table.Labels.Client
        components.program.label.text = lang_table.Labels.ProgramName
        xdbg:Log("Calling ui.update", LOG_FILES.EVENTS)
        ui.update()
    end
    xdbg:Log("Function completed", LOG_FILES.EVENTS)
end

-- Ads: Displays lines from multiple files in a scrolling ticker animation, looping indefinitely
-- Args:
--   link (table): List of file paths (e.g., {"path1.txt", "path2.txt"})
--   label (object): Label object with text and width properties (e.g., a UI Label)
--   interval (number): Sleep interval between animation steps in ms (e.g., 100)
--   textalign (string): Text alignment ("left", "right", "center")
--   spaces (number): Number of spaces to use for scrolling (e.g., 20)
--   skip_step (number): Number of steps to skip per frame (e.g., 1 for fluid, 3 for teleporting)
local function Ads(link, label, interval, textalign, spaces, skip_step)
    -- Validate inputs
    if type(link) ~= "table" or #link == 0 then
        xdbg:Log("Invalid link table: " .. tostring(link), LOG_FILES.ERRORS, "Ads")
        return
    end
    if not label or not label.text or not label.width then
        xdbg:Log("Invalid label object", LOG_FILES.ERRORS, "Ads")
        return
    end
    interval = interval or 100 -- Default to 100ms if not provided
    textalign = textalign or "left" -- Default to left alignment
    if not (textalign == "left" or textalign == "right" or textalign == "center") then
        xdbg:Log("Invalid textalign: " .. tostring(textalign) .. ", using 'left'", LOG_FILES.ERRORS, "Ads")
        textalign = "left"
    end
    spaces = spaces or 20 -- Default to 20 spaces if not provided
    if type(spaces) ~= "number" or spaces <= 0 then
        xdbg:Log("Invalid spaces: " .. tostring(spaces) .. ", using default 20", LOG_FILES.ERRORS, "Ads")
        spaces = 20
    end
    skip_step = skip_step or 1 -- Default to 1 (fluid scrolling)
    if type(skip_step) ~= "number" or skip_step <= 0 then
        xdbg:Log("Invalid skip_step: " .. tostring(skip_step) .. ", using default 1", LOG_FILES.ERRORS, "Ads")
        skip_step = 1
    end

    -- Set the label's text alignment
    label.textalign = textalign
    xdbg:Log("Set label textalign to: " .. textalign, LOG_FILES.DATA_PROC, "Ads")
    xdbg:Log("Using spaces: " .. spaces .. ", skip_step: " .. skip_step, LOG_FILES.DATA_PROC, "Ads")

    -- Load all lines from all files using withFile
    local all_lines = {}
    local file_lines = {} -- Temporary storage for each file's lines

    for idx, file_path in ipairs(link) do
        xdbg:Log("Loading file: " .. file_path, LOG_FILES.DATA_PROC, "Ads")
        local success, result = withFile(file_path, "r", function(file)
            local content = {}
            for line in file:lines() do
                table.insert(content, line)
            end
            return content
        end)

        if success and result then
            xdbg:Log("Loaded " .. #result .. " lines from " .. file_path, LOG_FILES.DATA_PROC, "Ads")
            file_lines[idx] = result
        else
            xdbg:Log("Failed to load file: " .. file_path .. ", error: " .. tostring(result), LOG_FILES.ERRORS, "Ads")
            file_lines[idx] = {}
        end
    end

    -- Merge all lines into all_lines
    for idx, lines in ipairs(file_lines) do
        xdbg:Log("Merging lines from file " .. idx .. ": " .. tostring(link[idx]), LOG_FILES.DATA_PROC, "Ads")
        if type(lines) == "table" then
            for _, line in ipairs(lines) do
                xdbg:Log("Inserting line: " .. tostring(line), LOG_FILES.DATA_PROC, "Ads")
                table.insert(all_lines, line)
            end
        else
            xdbg:Log("Invalid lines for file " .. idx .. ": " .. tostring(lines), LOG_FILES.ERRORS, "Ads")
        end
    end

    -- Remove duplicate lines
    local seen_lines = {}
    local unique_lines = {}
    local duplicate_count = 0
    for _, line in ipairs(all_lines) do
        if not seen_lines[line] then
            seen_lines[line] = true
            table.insert(unique_lines, line)
        else
            duplicate_count = duplicate_count + 1
        end
    end
    all_lines = unique_lines
    xdbg:Log("Removed " .. duplicate_count .. " duplicate lines", LOG_FILES.DATA_PROC, "Ads")

    if #all_lines == 0 then
        xdbg:Log("No lines loaded from any file after deduplication", LOG_FILES.ERRORS, "Ads")
        return
    end

    xdbg:Log("Total unique lines loaded: " .. #all_lines, LOG_FILES.DATA_PROC, "Ads")

    -- Track the current label width dynamically (for trimming only)
    local current_width = label.width or 80
    if current_width <= 0 then
        xdbg:Log("Invalid initial label width: " .. tostring(current_width) .. ", using default 80", LOG_FILES.ERRORS, "Ads")
        current_width = 80
    end
    xdbg:Log("Initial label width: " .. current_width, LOG_FILES.DATA_PROC, "Ads")

    -- Debounce resize events
    local last_resize_time = 0
    local resize_debounce_ms = 200

    -- Handle label resize to update the width dynamically (for trimming)
    label.onResize = function()
        local now = os.time()
        if now - last_resize_time < resize_debounce_ms then
            xdbg:Log("Debouncing resize event", LOG_FILES.EVENTS, "Ads/onResize")
            return
        end
        last_resize_time = now

        local new_width = label.width or 80
        if new_width <= 0 then
            xdbg:Log("Invalid label width on resize: " .. tostring(new_width) .. ", using default 80", LOG_FILES.ERRORS, "Ads/onResize")
            new_width = 80
        end
        xdbg:Log("Label resized, new width: " .. new_width, LOG_FILES.EVENTS, "Ads/onResize")
        current_width = new_width
    end

    -- Run the animation in an async task, looping indefinitely
    async(function()
        local line_idx = 1
        while true do
            -- Reset to the first line if we've reached the end
            if line_idx > #all_lines then
                line_idx = 1
                xdbg:Log("Looping back to first line", LOG_FILES.DATA_PROC, "Ads")
            end

            local line = all_lines[line_idx]
            xdbg:Log("Animating line " .. line_idx .. ": " .. line, LOG_FILES.DATA_PROC, "Ads")

            -- Skip empty lines
            if line == "" then
                xdbg:Log("Skipping empty line " .. line_idx, LOG_FILES.DATA_PROC, "Ads")
                line_idx = line_idx + 1
                goto continue
            end

            -- Calculate the total steps: spaces plus line length to fully move off-screen
            local line_len = #line
            local total_steps = spaces + line_len
            local effective_frames = math.ceil(total_steps / skip_step)
            xdbg:Log("Spaces: " .. spaces .. ", line length: " .. line_len .. ", total steps: " .. total_steps .. ", skip_step: " .. skip_step .. ", effective frames: " .. effective_frames, LOG_FILES.DATA_PROC, "Ads")

            -- Animate based on textalign
            if textalign == "right" then
                -- Scroll from left to right
                for step = 0, total_steps, skip_step do
                    local display_text = ""
                    local current_spaces = math.min(step, spaces) -- Spaces to add on the left (starts at 0, increases to spaces)

                    -- Add leading spaces to push the text to the left initially
                    for i = 1, current_spaces do
                        display_text = display_text .. " "
                    end

                    -- Add the visible portion of the line
                    local start_idx = math.max(1, step - spaces + 1)
                    local end_idx = math.min(line_len, total_steps - step)
                    if start_idx <= line_len then
                        display_text = display_text .. line:sub(start_idx, end_idx)
                    end

                    -- Trim to label width to avoid rendering issues
                    if #display_text > current_width then
                        display_text = display_text:sub(1, current_width)
                    end

                    -- Update the label
                    xdbg:Log("Step " .. step .. ": display_text='" .. display_text .. "'", LOG_FILES.DATA_PROC, "Ads")
                    label.text = display_text
                    sleep(interval)
                end
            else
                -- Scroll from right to left (for "left" and "center")
                for step = 0, total_steps, skip_step do
                    local display_text = ""
                    local current_spaces = math.max(0, spaces - step) -- Spaces to add on the left (starts at spaces, decreases to 0)

                    -- For "center", adjust spaces to center the visible text within the spaces area
                    if textalign == "center" then
                        local visible_text = ""
                        local start_idx = math.max(1, step - spaces + 1)
                        local end_idx = math.min(line_len, step)
                        if start_idx <= line_len then
                            visible_text = line:sub(start_idx, end_idx)
                        end

                        local visible_len = #visible_text
                        local total_space = spaces - visible_len
                        if total_space > 0 and visible_len > 0 then
                            local left_spaces = math.floor(total_space / 2)
                            current_spaces = left_spaces
                            display_text = string.rep(" ", left_spaces) .. visible_text .. string.rep(" ", total_space - left_spaces)
                        else
                            -- Add leading spaces
                            for i = 1, current_spaces do
                                display_text = display_text .. " "
                            end
                            if start_idx <= line_len then
                                display_text = display_text .. line:sub(start_idx, end_idx)
                            end
                        end
                    else
                        -- For "left", just add leading spaces
                        for i = 1, current_spaces do
                            display_text = display_text .. " "
                        end

                        -- Add the visible portion of the line
                        local start_idx = math.max(1, step - spaces + 1)
                        local end_idx = math.min(line_len, step)
                        if start_idx <= line_len then
                            display_text = display_text .. line:sub(start_idx, end_idx)
                        end
                    end

                    -- Trim to label width to avoid rendering issues
                    if #display_text > current_width then
                        display_text = display_text:sub(1, current_width)
                    end

                    -- Update the label
                    --xdbg:Log("Step " .. step .. ": display_text='" .. display_text .. "'", LOG_FILES.DATA_PROC, "Ads")
                    label.text = display_text
                    sleep(interval)
                end
            end

            -- Clear the label after the line disappears
            label.text = ""
            xdbg:Log("Finished animating line " .. line_idx, LOG_FILES.DATA_PROC, "Ads")

            line_idx = line_idx + 1
            ::continue::
        end
    end)
end

-- Optimized event handlers with debouncing and event delegation
-- Sets up UI event handlers for components
-- Args: ux (components table)
-- How it works: Defines handlers with debouncing for UI interactions
local function setup_event_handlers(window, ux, config, lang)
    xdbg:Log("Function started", LOG_FILES.EVENTS)

    -- Toggles console visibility and adjusts window size
    local function toggleDevPos()
        xdbg:Log("Toggling console visibility", LOG_FILES.EVENTS)
        ux.console.visible = not ux.console.visible
        ux.console.button.x = ux.console.visible and ORIGINAL_WIDTH + 2 or ORIGINAL_WIDTH - 40
        ux.console.button.text = ux.console.visible and "◀" or "▶"
        ux.console.text.visible = ux.console.visible
        ux.console.label.visible = ux.console.visible
        ux.console.label.x = ORIGINAL_WIDTH + 45
        ux.window.width = ux.console.visible and ORIGINAL_WIDTH + CONSOLE_WIDTH or ORIGINAL_WIDTH
        xdbg:Log("Console visibility set to: " .. tostring(ux.console.visible), LOG_FILES.EVENTS)
    end

    local last_time = 0
    -- Standalone debounce function with debug
    local function debounce(fn, delay)
        return function(...)
            local now = os.clock()
            local time_diff = now - last_time
            --print(string.format("Debounce: now=%.3f, last_time=%.3f, diff=%.3f, delay=%.1f", now, last_time, time_diff, delay or 0.2))
            
            if time_diff >= (delay or 0.2) then
                --print("Debounce: Executing fn")
                last_time = now
                fn(...)
            else
                --print("Debounce: Skipped (within delay)")
            end
        end
    end

    -- Delays button actions with sound and error handling
    -- Args: self (object, e.g., button), func (function to execute), fallback (optional error handler), timer (delay in ms, nil or <=0 for instant)
    -- Returns: Table with Now and Wait methods
    local function recordActionPlusSound(self, func, fallback, timer)
        local log_msg = string.format("Click (%s/[%s]) at X:%d Y:%d", type(self), self.text, self.x, self.y)
        local operationRan = false -- Track if the core operation has run

        local function runOperation()
            if not operationRan then -- Only run the operation once
                if PREP_FILES.sound.click then PREP_FILES.sound.click:play() end
                xdbg:Log(log_msg, LOG_FILES.EVENTS)
                safe_operation(func, fallback)
                ui.update()
                operationRan = true
            end
        end

        local action = {
            Now = function(action_self)
                runOperation() -- Run immediately
                if timer and timer > 0 then
                    -- Delay re-enabling if timer > 0
                    self.enabled = false
                    async(function()
                        sleep(timer)
                        self.enabled = true
                    end)
                end
            end,
            Wait = function(action_self, time)
                runOperation() -- Run immediately
                if time and time > 0 then
                    self.enabled = false
                    async(function()
                        sleep(time) -- Delay by specified time in milliseconds
                        self.enabled = true
                    end)
                end
            end
        }

        setmetatable(action, {
            __call = function(t)
                t.Now(self) -- Runs via __call
                return t
            end
        })

        -- Immediate execution, delay (if any) after
        action.Now(self)
        return action
    end

    local function openDirDialog(self, title, default_text)
        xdbg:Log("Opening dir dialog: " .. title, LOG_FILES.EVENTS)
        ux.window:hide()
        local file = ui.dirdialog(title)
        self.text = file and file.fullpath or default_text
        ux.window:show()
        xdbg:Log("Selected path: " .. self.text, LOG_FILES.EVENTS)
    end

    local function openFileDialog(setters, title, default_text)
        xdbg:Log("Opening file dialog: " .. title, LOG_FILES.EVENTS)
        ux.window:hide()
    
        local file = ui.opendialog(title, false, "All files (*.*)|*.*|Asc file (*.asc)|*.asc|Csv file (*.csv)|*.csv|Text files (*.txt)|*.txt")
        local fullpath = file and file.fullpath or default_text
    
        -- Call each setter with the fullpath
        for _, set in ipairs(setters) do
            set(fullpath)
        end
    
        ux.window:show()
        xdbg:Log("Selected path: " .. fullpath, LOG_FILES.EVENTS)
        return fullpath
    end
    
    switch(paramsAsTable["debug"]) {
        ["interactive"] = (function()
            xdbg:Log("Hiding dev click if no debug interactive mode found", LOG_FILES.EVENTS, "setup_event_handlers")
            ux.console.dev:hide()
         end),
        ["expand"] = (function()
            xdbg:Log("Debug interactive expand mode, toggling console", LOG_FILES.EVENTS, "setup_event_handlers")
            toggleDevPos()
        end),
        ["__default"] = (function()
        end)
    }
    
    ux.console.button.visible = paramsAsTable["debug"]()
    
    -- Event handlers with enhanced debug logging
    function ux.console.button:onClick()
        xdbg:Log("Console button clicked", LOG_FILES.EVENTS, "ux.console.button:onClick")
        recordActionPlusSound(self, function()
            xdbg:Log("Toggling developer position", LOG_FILES.EVENTS, "ux.console.button:onClick/recordActionPlusSound")
            toggleDevPos()
        end):Wait(2000)
        xdbg:Log("Event handler completed", LOG_FILES.EVENTS, "ux.console.button:onClick")
    end

    function ux.language.selectBox:onChange()
        xdbg:Log("Language change event triggered", LOG_FILES.EVENTS, "ux.language.selectBox:onChange")
        recordActionPlusSound(self, function()
            local inputText = self.text:lower()
            xdbg:Log("Input text: " .. inputText, LOG_FILES.EVENTS, "ux.language.selectBox:onChange/recordActionPlusSound")
            if inputText and inputText ~= "" then
                local closestMatch = nil
                for _, item in ipairs(self.items) do
                    local itemText = item.text:lower()
                    if itemText:find("^" .. inputText) then
                        closestMatch = item
                        xdbg:Log("Found match: " .. itemText, LOG_FILES.EVENTS, "ux.language.selectBox:onChange/recordActionPlusSound")
                        break
                    end
                end
                if closestMatch then
                    self.selected = closestMatch
                    local selected_lang = closestMatch.text
                    ux.config.Language = "data/lang/" .. selected_lang .. ".json"
                    xdbg:Log("Loading language: " .. selected_lang, LOG_FILES.EVENTS, "ux.language.selectBox:onChange/recordActionPlusSound")
                    update_ui_with_language(ux, selected_lang)
                    xdbg:Log("Selected language: " .. selected_lang, LOG_FILES.EVENTS, "ux.language.selectBox:onChange/recordActionPlusSound")
                else
                    self.selected = self.items[#self.items]
                    update_ui_with_language(ux, self.selected.text)
                    xdbg:Log("Selected default language: " .. self.selected.text, LOG_FILES.EVENTS, "ux.language.selectBox:onChange/recordActionPlusSound")
                
                    xdbg:Log("No language match for: " .. inputText, LOG_FILES.EVENTS, "ux.language.selectBox:onChange/recordActionPlusSound")
                end
            end
        end):Wait(1169)
        xdbg:Log("Calling ui.update", LOG_FILES.EVENTS, "ux.language.selectBox:onChange")
        ui.update()
        xdbg:Log("Event handler completed", LOG_FILES.EVENTS, "ux.language.selectBox:onChange")
    end

    function ux.language.selectBox:onSelect()
        xdbg:Log("Language select event triggered", LOG_FILES.EVENTS, "ux.language.selectBox:onSelect")
        recordActionPlusSound(self, function()
            local lang = self.text
            xdbg:Log("Selected lang: " .. lang, LOG_FILES.EVENTS, "ux.language.selectBox:onSelect/recordActionPlusSound")
            if lang and lang ~= "" then
                ux.config.Language = "data/lang/" .. lang .. ".json"
                xdbg:Log("Loading language: " .. lang, LOG_FILES.EVENTS, "ux.language.selectBox:onSelect/recordActionPlusSound")
                update_ui_with_language(ux, lang) 
                xdbg:Log("Language UI updated", LOG_FILES.EVENTS, "ux.language.selectBox:onSelect/recordActionPlusSound")
            end
        end):Wait(1169)
        xdbg:Log("Event handler completed", LOG_FILES.EVENTS, "ux.language.selectBox:onSelect")
    end

    function ux.client.addEntry:onClick()
        xdbg:Log("Client addEntry clicked", LOG_FILES.EVENTS, "ux.client.addEntry:onClick")
        recordActionPlusSound(self, function()
            xdbg:Log("Processing addEntry click", LOG_FILES.EVENTS, "ux.client.addEntry:onClick/recordActionPlusSound")
        end)
        xdbg:Log("Event handler completed", LOG_FILES.EVENTS, "ux.client.addEntry:onClick")
    end

    function ux.language.selectBox:onClick()
        xdbg:Log("Language selectBox clicked", LOG_FILES.EVENTS, "ux.language.selectBox:onClick")
        recordActionPlusSound(self, function()
            xdbg:Log("Processing language selectBox click", LOG_FILES.EVENTS, "ux.language.selectBox:onClick/recordActionPlusSound")
        end)
        xdbg:Log("Event handler completed", LOG_FILES.EVENTS, "ux.language.selectBox:onClick")
    end

    function ux.program.input:onClick()
        xdbg:Log("Program input clicked", LOG_FILES.EVENTS, "ux.program.input:onClick")
        recordActionPlusSound(self, function()
            xdbg:Log("Processing program input click", LOG_FILES.EVENTS, "ux.program.input:onClick/recordActionPlusSound")
        end)
        xdbg:Log("Event handler completed", LOG_FILES.EVENTS, "ux.program.input:onClick")
    end

    function ux.bomsplit.measure:onClick()
        xdbg:Log("BOMSPLIT measure clicked", LOG_FILES.EVENTS, "ux.bomsplit.measure:onClick")
        recordActionPlusSound(self, function()
            self.text = self.text == "inch" and "cm" or "inch"
        end):Wait(1000)
        xdbg:Log("BOMSPLIT Event handler completed", LOG_FILES.EVENTS, "ux.bomsplit.measure:onClick")
    end

    function ux.bomsplit.input:onClick(file_path)
        -- Log the raw file_path value to debug what the framework is passing
        xdbg:Log("Raw file_path received: " .. tostring(file_path) .. " (type: " .. type(file_path) .. ")", LOG_FILES.EVENTS, "ux.bomsplit.input:onClick")
    
        -- If file_path is 0 or not a string, set it to nil
        if file_path == 0 or type(file_path) ~= "string" then
            file_path = nil
        end
    
        xdbg:Log("BOMSPLIT input clicked" .. (file_path and " with path: " .. file_path or ""), LOG_FILES.EVENTS, "ux.bomsplit.input:onClick")
        recordActionPlusSound(self, function()
            local path
            if file_path then
                -- Use the provided file path
                path = file_path
                ux.bomsplit.input.text = path
                ux.bomsplit.entry.text = path
                config.Last.BOMSplitPath = path
                xdbg:Log("Using provided file path: " .. path, LOG_FILES.EVENTS, "ux.bomsplit.input:onClick/recordActionPlusSound")
            else
                -- Open file dialog to select a file
                path = openFileDialog({
                    function(val) ux.bomsplit.input.text = val end,
                    function(val) ux.bomsplit.entry.text = val end,
                    function(val) config.Last.BOMSplitPath = val end
                }, "Select your destination file", config.Last.BOMSplitPath or lang.Buttons.BOMSplitPath)
                xdbg:Log("Selected file path from dialog: " .. tostring(path), LOG_FILES.EVENTS, "ux.bomsplit.input:onClick/recordActionPlusSound")
            end
    
            if path then
                get_measurements(path, ux.bomsplit.measure)
            else
                xdbg:Log("No file path selected, skipping get_measurements", LOG_FILES.EVENTS, "ux.bomsplit.input:onClick/recordActionPlusSound")
            end
        end):Wait(1000)
        xdbg:Log("BOMSPLIT Event handler completed", LOG_FILES.EVENTS, "ux.bomsplit.input:onClick")
    end
    
    function ux.bomsplit.input:onDrop(kind, content)
        xdbg:Log("BOMSPLIT input drop >" .. kind .. " size " .. #content, LOG_FILES.EVENTS, "ux.bomsplit.input:onDrop")
        if kind == "files" and content[1] and content[1].fullpath then
            -- Call onClick with the dropped file path
            xdbg:Log("Processing BOMSPLIT drop: " .. kind, LOG_FILES.EVENTS, "ux.bomsplit.input:onDrop")
            self:onClick(content[1].fullpath)
        else
            xdbg:Log("Invalid drop content, kind=" .. kind .. ", skipping", LOG_FILES.EVENTS, "ux.bomsplit.input:onDrop")
            recordActionPlusSound(self, function()
                xdbg:Log("Processed invalid BOMSPLIT drop: " .. kind, LOG_FILES.EVENTS, "ux.bomsplit.input:onDrop/recordActionPlusSound")
            end):Wait(1000)
            xdbg:Log("BOMSPLIT Event handler completed", LOG_FILES.EVENTS, "ux.bomsplit.input:onDrop")
        end
    end
    
    function ux.bomsplit.entry:onDrop(kind, content)
        xdbg:Log("BOMSPLIT entry drop", LOG_FILES.EVENTS, "ux.bomsplit.entry:onDrop")
        if kind == "files" and content[1] and content[1].fullpath then
            -- Call onClick with the dropped file path
            xdbg:Log("Processing BOMSPLIT drop: " .. kind, LOG_FILES.EVENTS, "ux.bomsplit.entry:onDrop")
            ux.bomsplit.input:onClick(content[1].fullpath)
        else
            xdbg:Log("Invalid drop content, kind=" .. kind .. ", skipping", LOG_FILES.EVENTS, "ux.bomsplit.entry:onDrop")
            recordActionPlusSound(self, function()
                xdbg:Log("Processed invalid BOMSPLIT drop: " .. kind, LOG_FILES.EVENTS, "ux.bomsplit.entry:onDrop/recordActionPlusSound")
            end):Wait(1000)
            xdbg:Log("BOMSPLIT Event handler completed", LOG_FILES.EVENTS, "ux.bomsplit.entry:onDrop")
        end
        xdbg:Log("BOMSPLIT Event handler completed", LOG_FILES.EVENTS, "ux.bomsplit.entry:onDrop")
    end

    function ux.pincad.measure:onClick()
        xdbg:Log("PINCAD measure clicked", LOG_FILES.EVENTS, "ux.pincad.measure:onClick")
        recordActionPlusSound(self, function()
            self.text = self.text == "inch" and "cm" or "inch"
        end):Wait(1000)
        xdbg:Log("PINCAD Event handler completed", LOG_FILES.EVENTS, "ux.pincad.measure:onClick")
    end

    function ux.pincad.input:onClick(file_path)
        -- Log the raw file_path value to debug what the framework is passing
        xdbg:Log("Raw file_path received: " .. tostring(file_path) .. " (type: " .. type(file_path) .. ")", LOG_FILES.EVENTS, "ux.bomsplit.input:onClick")

        -- If file_path is 0 or not a string, set it to nil
        if file_path == 0 or type(file_path) ~= "string" then
            file_path = nil
        end

        xdbg:Log("PINCAD input clicked" .. (file_path and " with path: " .. file_path or ""), LOG_FILES.EVENTS, "ux.pincad.input:onClick")
        recordActionPlusSound(self, function()
            local path
            if file_path then
                -- Use the provided file path
                path = file_path
                ux.pincad.input.text = path
                ux.pincad.entry.text = path
                config.Last.PINSCadPath = path
                xdbg:Log("Using provided file path: " .. path, LOG_FILES.EVENTS, "ux.pincad.input:onClick/recordActionPlusSound")
            else
                -- Open file dialog to select a file
                path = openFileDialog({
                    function(val) ux.pincad.input.text = val end,
                    function(val) ux.pincad.entry.text = val end,
                    function(val) config.Last.PINSCadPath = val end
                }, "Select your destination file", config.Last.PINSCadPath or lang.Buttons.PINSCadPath)
                xdbg:Log("Selected file path from dialog: " .. tostring(path), LOG_FILES.EVENTS, "ux.pincad.input:onClick/recordActionPlusSound")
            end
    
            if path then
                get_measurements(path, ux.pincad.measure)
            else
                xdbg:Log("No file path selected, skipping get_measurements", LOG_FILES.EVENTS, "ux.pincad.input:onClick/recordActionPlusSound")
            end
        end):Wait(1000)
        xdbg:Log("PINCAD Event handler completed", LOG_FILES.EVENTS, "ux.pincad.input:onClick")
    end

    function ux.pincad.input:onDrop(kind, content)
        xdbg:Log("PINCAD input drop >" .. kind .. " size " .. #content, LOG_FILES.EVENTS, "ux.pincad.input:onDrop")
        if kind == "files" and content[1] and content[1].fullpath then
            -- Call onClick with the dropped file path
            xdbg:Log("Processing PINCAD drop: " .. kind, LOG_FILES.EVENTS, "ux.pincad.input:onDrop")
            self:onClick(content[1].fullpath)
        else
            xdbg:Log("Invalid drop content, kind=" .. kind .. ", skipping", LOG_FILES.EVENTS, "ux.pincad.input:onDrop")
            recordActionPlusSound(self, function()
                xdbg:Log("Processed invalid PINCAD drop: " .. kind, LOG_FILES.EVENTS, "ux.pincad.input:onDrop/recordActionPlusSound")
            end):Wait(1000)
            xdbg:Log("PINCAD Event handler completed", LOG_FILES.EVENTS, "ux.pincad.input:onDrop")
        end
    end

    function ux.pincad.entry:onDrop(kind, content)
        xdbg:Log("PINCAD entry drop", LOG_FILES.EVENTS, "ux.pincad.entry:onDrop")
        if kind == "files" and content[1] and content[1].fullpath then
            -- Call onClick with the dropped file path
            xdbg:Log("Processing PINCAD drop: " .. kind, LOG_FILES.EVENTS, "ux.pincad.entry:onDrop")
            ux.pincad.input:onClick(content[1].fullpath)
        else
            xdbg:Log("Invalid drop content, kind=" .. kind .. ", skipping", LOG_FILES.EVENTS, "ux.pincad.entry:onDrop")
            recordActionPlusSound(self, function()
                xdbg:Log("Processed invalid PINCAD drop: " .. kind, LOG_FILES.EVENTS, "ux.pincad.entry:onDrop/recordActionPlusSound")
            end):Wait(1000)
            xdbg:Log("PINCAD Event handler completed", LOG_FILES.EVENTS, "ux.pincad.entry:onDrop")
        end
        xdbg:Log("PINCAD Event handler completed", LOG_FILES.EVENTS, "ux.pincad.entry:onDrop")
    end

    function ux.GenerateButton:onClick()
        xdbg:Log("Generate button clicked", LOG_FILES.EVENTS, "ux.GenerateButton:onClick")
        recordActionPlusSound(self, function()
            xdbg:Log("Starting CSV generation", LOG_FILES.EVENTS, "ux.GenerateButton:onClick/recordActionPlusSound")
            window.cursor = "wait"
            await(generateCSV, ux)
            window.cursor = "arrow"
        end):Wait(2500)
        xdbg:Log("Generate Event handler completed", LOG_FILES.EVENTS, "ux.GenerateButton:onClick")
    end

    function ux.about.label:onClick()
        xdbg:Log("About label clicked", LOG_FILES.EVENTS, "ux.about.label:onClick")
        local function url_encode(str)
            return str:gsub("\n", "\r\n"):gsub("([^%w%-%.%_%~ ])", function(c) return string.format("%%%02X", string.byte(c)) end):gsub(" ", "%%20")
        end
        xdbg:Log("Opening email client", LOG_FILES.EVENTS, "ux.about.label:onClick")
        sys.cmd("start mailto:adalbertalexandru.ungureanu@flex.com?subject=" .. url_encode("Hey Alex I got a question!") .. "&body=")
        xdbg:Log("About label Event handler completed", LOG_FILES.EVENTS, "ux.about.label:onClick")
    end

    local function updateArgToNumber(arg, dev_prefix)
        local max_num = 0
        for _, v in ipairs(arg) do -- Find highest "devX" number in table
            local num = tonumber(tostring(v):match("^" .. dev_prefix .. "(%d+)$")) or 0
            if num > max_num then max_num = num end
        end
        local last = arg[#arg] or ""
        local target_index = #arg + (last:match("^" .. dev_prefix .. "%d+$") and 0 or 1)
        arg[target_index] = dev_prefix .. tostring(max_num + 1)
        return target_index
    end
    
    function ux.console.dev:onClick(x, y)
        local dev_index = updateArgToNumber(arg, "dev")
        
        --[[for i, v in ipairs(arg) do
            print(tostring(v) .. "\t")
        end]]
        
        if arg[dev_index] == "dev5" then
            arg[dev_index] = nil
            collectgarbage("collect")
            xdbg:Log("Activating developer mode", LOG_FILES.EVENTS, "ux.console.dev:onClick")
            self:hide()
            ux.console.button:show()
            arg[#arg-2], arg[#arg-1] = "--debug", "interactive"
            toggleDevPos()
            ui.msg("CONGRATULATION YOU'VE BECOME A DEVELOPER\nCONSOLE HAS BEEN ACTIVATED")
        end
        
        xdbg:Log("Event handler completed", LOG_FILES.EVENTS, "ux.console.dev:onClick")
    end

    function ux.client.removeButton:onClick()
        xdbg:Log("Remove button clicked", LOG_FILES.EVENTS, "ux.client.removeButton:onClick")
        recordActionPlusSound(self, function()
            local selectedText = ux.client.selectBox.text
            xdbg:Log("Selected text: " .. tostring(selectedText), LOG_FILES.EVENTS, "ux.client.removeButton:onClick/recordActionPlusSound")
            if selectedText ~= "" then
                xdbg:Log("Selected Box: " .. selectedText, LOG_FILES.EVENTS, "ux.client.removeButton:onClick/recordActionPlusSound")
                if #ux.client.selectBox.items > 1 then
                    for index, item in ipairs(ux.client.selectBox.items) do
                        if item.text == selectedText then
                            local adjustedIndex = index - 1
                            if adjustedIndex >= 0 then
                                xdbg:Log("Removing item at adjusted index " .. adjustedIndex, LOG_FILES.EVENTS, "ux.client.removeButton:onClick/recordActionPlusSound")
                                ux.client.selectBox:remove(adjustedIndex)
                                xdbg:Log("Removed option at adjusted index " .. adjustedIndex .. " (original " .. index .. "): " .. selectedText, LOG_FILES.EVENTS, "ux.client.removeButton:onClick/recordActionPlusSound")
                            else
                                xdbg:Log("Invalid adjusted index for " .. selectedText, LOG_FILES.EVENTS, "ux.client.removeButton:onClick/recordActionPlusSound")
                            end
                            break
                        end
                    end
                    if #ux.client.selectBox.items > 0 then
                        xdbg:Log("Setting selected to last item", LOG_FILES.EVENTS, "ux.client.removeButton:onClick/recordActionPlusSound")
                        ux.client.selectBox.selected = ux.client.selectBox.items[#ux.client.selectBox.items]
                    end
                else
                    ui.msg("Cannot delete the last remaining option.", "Warning")
                end
            else
                ui.msg("Nothing was selected.", "Warning")
                if #ux.client.selectBox.items > 0 then
                    xdbg:Log("Setting selected to last item (no selection)", LOG_FILES.EVENTS, "ux.client.removeButton:onClick/recordActionPlusSound")
                    ux.client.selectBox.selected = ux.client.selectBox.items[#ux.client.selectBox.items]
                end
            end
        end):Wait(1000)
        xdbg:Log("Calling ui.update", LOG_FILES.EVENTS, "ux.client.removeButton:onClick")
        ui.update()
        xdbg:Log("Event handler completed", LOG_FILES.EVENTS, "ux.client.removeButton:onClick")
    end

    function ux.client.addButton:onClick()
        xdbg:Log("Add button clicked", LOG_FILES.EVENTS, "ux.client.addButton:onClick")
        recordActionPlusSound(self, function()
            local newEntry = ux.client.addEntry.text
            xdbg:Log("New entry: " .. tostring(newEntry), LOG_FILES.EVENTS, "ux.client.addButton:onClick/recordActionPlusSound")
            if newEntry ~= "" then
                for _, item in ipairs(ux.client.selectBox.items) do
                    if item.text == newEntry then
                        ux.client.selectBox.text = newEntry
                        xdbg:Log("Entry already exists: " .. newEntry, LOG_FILES.EVENTS, "ux.client.addButton:onClick/recordActionPlusSound")
                        return
                    end
                end
                xdbg:Log("Adding new entry: " .. newEntry, LOG_FILES.EVENTS, "ux.client.addButton:onClick/recordActionPlusSound")
                ux.client.selectBox:add(newEntry)
                ux.client.selectBox.selected = ux.client.selectBox.items[#ux.client.selectBox.items]
                ux.client.addEntry.text = ""
                xdbg:Log("Added new option: " .. newEntry, LOG_FILES.EVENTS, "ux.client.addButton:onClick/recordActionPlusSound")
            end
        end):Wait(1000)
        xdbg:Log("Calling ui.update", LOG_FILES.EVENTS, "ux.client.addButton:onClick")
        ui.update()
        xdbg:Log("Event handler completed", LOG_FILES.EVENTS, "ux.client.addButton:onClick")
    end

    function ux.exit:onClick()
        recordActionPlusSound(self, function()
            --xdbg:Flush(nil, true)
            for entry in each(ux.client.selectBox.items) do
                if entry.text ~= "" then
                    xdbg:Log("Adding entry to config.Clients: " .. entry.text, LOG_FILES.EVENTS, "ux.window:onClose/await")
                    ux.config.Clients = table.concat(entry.text .. ",")
                end
            end
            config.Last.OptionClient = ux.client.selectBox.text
            local success, err = pcall(ini.save, "fui.ini", config)
            if not success then
                xdbg:Log("Failed to save config: " .. tostring(err), LOG_FILES.ERRORS)
                --ui.error("Failed to save config", tostring(err))
            else
                print("About to exit") -- Add debug output
                sys.exit(0) -- Explicitly set exit code to 0
            end
        end):Wait(100)
    end

    function ux.window:onClose()
        xdbg:Log("Window close event triggered", LOG_FILES.EVENTS, "ux.window:onClose")
        return await(function()
            xdbg:Log("Logs flushed on window close", LOG_FILES.EVENTS, "ux.window:onClose/await")
            --config.Last.OptionClient = ux.client.selectBox.text
            --config.Last.BOMSplitPath = ux.bomsplit.input.text
            --config.Last.PINSCadPath = ux.pincad.input.text
            for entry in each(ux.client.selectBox.items) do
                if entry.text ~= "" then
                    xdbg:Log("Adding entry to config.Clients: " .. entry.text, LOG_FILES.EVENTS, "ux.window:onClose/await")
                    ux.config.Clients = table.concat(entry.text .. ",")
                end
            end
            config.Last.OptionClient = ux.client.selectBox.text

            --ux.config.Clients = ux.client.selectBox.items
            xdbg:Log("Saving config to fui.ini", LOG_FILES.CONFIG, "ux.window:onClose/await")
            if not ini.save("fui.ini",config) then 
                ui.error("Failed to save config", "ERROR")
            end
            xdbg:Log("Configuration validated and saved", LOG_FILES.CONFIG, "ux.window:onClose/await")
            xdbg:Log("Final flush before exit", LOG_FILES.EVENTS, "ux.window:onClose/await")
            xdbg:Flush(nil, true)
            xdbg:Log("Calling ui.update", LOG_FILES.EVENTS, "ux.window:onClose/await")
            ui.update()
            xdbg:Log("Event handler completed", LOG_FILES.EVENTS, "ux.window:onClose/await")
        end)
    end
    xdbg:Log("Function completed", LOG_FILES.EVENTS)
end

-- Optimized UI constructor with precomputed layouts
-- Builds the UI with components and handlers
-- Args: config (table), lang (language table)
-- Returns: Table with window, components, config
-- How it works: Creates UI elements, sets properties, attaches handlers
local function uiConstruct(config, lang)
    xdbg:Log("Function started", LOG_FILES.UI)
    xdbg:Log("Initializing window", LOG_FILES.UI)
    local window = ui.Window(nil, "                                 Generate .CAD/CSV for MagicRay ver.".._G.App.Version, "single", ORIGINAL_WIDTH, ORIGINAL_HEIGHT+20)
    --window:status("ADS")
    window:loadicon(PREP_FILES.ico.app)

    local padding = 10
    local default_size = 25
    
    -- Dynamic DPI scaling function
    local function scale_with_dpi(base_size, dpi, max_scale)
        max_scale = max_scale or 1.5
        local scale_factor = 1 + (max_scale - 1) * (dpi - 1) / (3 - 1)
        return base_size * scale_factor
    end
    
    local function build_ui(orientation, ...)
        local components_def = {...}
        local props_list = {}
        local component_types = {}
    
        -- Extract component types and properties
        for i, comp_def in ipairs(components_def) do
            local comp_type, props = next(comp_def)
            xdbg:Log("comp_def[" .. i .. "]: type=" .. tostring(comp_type), LOG_FILES.EVENTS)
            table.insert(component_types, comp_type)
            table.insert(props_list, props or {})
        end
        xdbg:Log("component_types length: " .. #component_types, LOG_FILES.EVENTS)
    
        -- If no components, return empty table
        if #component_types == 0 then
            xdbg:Log("No components to build, returning empty table", LOG_FILES.EVENTS)
            return {}
        end
    
        local ui_components = {}
        local start_x, start_y = 20, 20
    
        -- Create components
        for i, comp_type in ipairs(component_types) do
            local success, result = pcall(function()
                local props = props_list[i]
                local ui_comp
                local base_width = default_size
                local base_height = default_size
    
                if comp_type == "Picture" then
                    base_width = 10
                    base_height = 10
                elseif comp_type == "Entry" then
                    base_width = default_size * 20
                elseif comp_type == "Combobox" then
                    base_height = default_size * 20
                end
    
                -- Set width and height, prioritizing manual values
                local w = props.width or base_width
                local h = props.height or base_height
                -- Apply DPI scaling only if dpi_scale is true and no manual width/height
                if props.dpi_scale then
                    if not props.width then
                        w = scale_with_dpi(base_width, ui.dpi)
                    end
                    if not props.height then
                        h = scale_with_dpi(base_height, ui.dpi)
                    end
                end
    
                if comp_type == "Label" then
                    ui_comp = ui.Label(window, props.text or " ", start_x, start_y, w, h)
                elseif comp_type == "Button" then
                    ui_comp = ui.Button(window, props.text or " ", start_x, start_y, w, h)
                elseif comp_type == "Entry" then
                    ui_comp = ui.Entry(window, props.text or " ", start_x, start_y, w, h)
                elseif comp_type == "Checkbox" then
                    ui_comp = ui.Checkbox(window, props.text or " ", start_x, start_y, w)
                elseif comp_type == "Combobox" then
                    local items = props.items or {}
                    if type(items) ~= "table" then
                        error("Combobox items must be a table, got: " .. tostring(items))
                    end
                    ui_comp = ui.Combobox(window, true, items, start_x, start_y, w, h)
                elseif comp_type == "List" then
                    ui_comp = ui.List(window, props.items or {}, start_x, start_y, w, h)
                elseif comp_type == "Edit" then
                    ui_comp = ui.Edit(window, " ", start_x, start_y, w, h)
                elseif comp_type == "Progressbar" then
                    ui_comp = ui.Progressbar(window, props.value or 0, start_x, start_y, w, h)
                elseif comp_type == "Picture" then
                    ui_comp = ui.Picture(window, props.source or "", start_x, start_y, w, h)
                else
                    error("Unknown component type: " .. tostring(comp_type))
                end
    
                ui_comp.font = "Segoe UI"
                ui_comp.fontsize = 10
    
                for key, value in pairs(props) do
                    if key ~= "text" and key ~= "items" and key ~= "value" and key ~= "source" and key ~= "xgap_before" and key ~= "ygap_before" and key ~= "xgap_after" and key ~= "ygap_after" and key ~= "dpi_scale" then
                        ui_comp[key] = value
                    end
                end
    
                return ui_comp
            end)
    
            if success then
                table.insert(ui_components, result)
                xdbg:Log("Created component " .. i .. ": " .. tostring(result), LOG_FILES.EVENTS)
            else
                xdbg:Log("Failed to create component " .. i .. ": " .. tostring(result), LOG_FILES.EVENTS)
            end
        end
    
        -- Layout calculation
        local prev_x, prev_y, prev_w, prev_h = start_x, start_y, default_size, default_size
    
        if orientation == "h" then
            local total_fixed = 0
            local dynamic_count = 0
            local dynamic_with_width = 0
            local positions = {}
            local sizes = {}
            local xgaps_before = {}
            local xgaps_after = {}
    
            for i, props in ipairs(props_list) do
                positions[i] = props.x
                sizes[i] = props.width
                xgaps_before[i] = props.xgap_before or 0
                xgaps_after[i] = props.xgap_after or 0
                if positions[i] and sizes[i] then
                    total_fixed = total_fixed + sizes[i] + (xgaps_after[i] or 0)
                elseif not positions[i] then
                    if sizes[i] then
                        dynamic_with_width = dynamic_with_width + sizes[i] + (xgaps_after[i] or 0)
                    else
                        dynamic_count = dynamic_count + 1
                    end
                end
            end
    
            local last_fixed_end = positions[1] or start_x
            for i = 1, #props_list do
                if positions[i] and sizes[i] then
                    last_fixed_end = positions[i] + sizes[i] + (xgaps_after[i] or 0)
                end
            end
    
            local total_xgap_before = 0
            local total_xgap_after = 0
            for i = 1, #props_list - 1 do
                if not positions[i + 1] then
                    total_xgap_before = total_xgap_before + (xgaps_before[i] or 0)
                    total_xgap_after = total_xgap_after + (xgaps_after[i] or 0)
                end
            end
            if not positions[#props_list] then
                total_xgap_after = total_xgap_after + (xgaps_after[#props_list] or 0)
            end
    
            local available = ORIGINAL_WIDTH - last_fixed_end - dynamic_with_width - total_xgap_before - total_xgap_after
            local dynamic_size = dynamic_count > 0 and math.max(0, math.floor(available / dynamic_count)) or 0
    
            for i, comp in ipairs(ui_components) do
                local props = props_list[i]
                -- Use the *current* component's xgap_before when its x is dynamic
                local current_xgap_before = (not positions[i]) and (xgaps_before[i] or 0) or 0
                local current_xgap_after = xgaps_after[i] or 0
                local x = positions[i] or (i == 1 and start_x or (prev_x + prev_w + current_xgap_before))
                local y = props.y or start_y
                local w = sizes[i] or dynamic_size
                local h = props.height or default_size
    
                comp.x, comp.y = x, y
                comp.width, comp.height = w, h
    
                prev_x, prev_y, prev_w, prev_h = x, y, w + current_xgap_after, h
            end
        else
            local total_fixed = 0
            local dynamic_count = 0
            local dynamic_with_height = 0
            local positions = {}
            local sizes = {}
            local ygaps_before = {}
            local ygaps_after = {}
    
            for i, props in ipairs(props_list) do
                positions[i] = props.y
                sizes[i] = props.height
                ygaps_before[i] = props.ygap_before or 0
                ygaps_after[i] = props.ygap_after or 0
                if positions[i] and sizes[i] then
                    total_fixed = total_fixed + sizes[i] + (ygaps_after[i] or 0)
                elseif not positions[i] then
                    if sizes[i] then
                        dynamic_with_height = dynamic_with_height + sizes[i] + (ygaps_after[i] or 0)
                    else
                        dynamic_count = dynamic_count + 1
                    end
                end
            end
    
            local first_y = positions[1] or start_y
            local total_ygap_before = 0
            local total_ygap_after = 0
            for i = 1, #props_list - 1 do
                if not positions[i + 1] then
                    total_ygap_before = total_ygap_before + (ygaps_before[i] or 0)
                    total_ygap_after = total_ygap_after + (ygaps_after[i] or 0)
                end
            end
            if not positions[#props_list] then
                total_ygap_after = total_ygap_after + (ygaps_after[#props_list] or 0)
            end
    
            local available = ORIGINAL_HEIGHT - first_y - total_fixed - dynamic_with_height - total_ygap_before - total_ygap_after
            local dynamic_size = dynamic_count > 0 and math.max(0, math.floor(available / dynamic_count)) or default_size
    
            for i, comp in ipairs(ui_components) do
                local props = props_list[i]
                local current_ygap_before = (not positions[i]) and (ygaps_before[i] or 0) or 0
                local current_ygap_after = ygaps_after[i] or 0
                local x = props.x or prev_x
                local y = positions[i] or (i == 1 and start_y or (prev_y + prev_h + current_ygap_before))
                local w = props.width or prev_w
                local h = sizes[i] or dynamic_size
    
                if i == #ui_components then
                    h = math.min(h, ORIGINAL_HEIGHT - y)
                end
    
                comp.x, comp.y = x, y
                comp.width, comp.height = w, h
    
                prev_x, prev_y, prev_w, prev_h = x, y, w, h + current_ygap_after
            end
        end
    
        xdbg:Log("UI components created successfully", LOG_FILES.EVENTS, "build_ui")
        return ui_components
    end

    xdbg:Log("Building components", LOG_FILES.UI)

    -- Component definitions using build_ui with named returns
    local defui = {w = 160, h = 25, xs = 20, xe = 20}

    local components = {
        ads = (function()
            local comps = build_ui("h", {Label = {text = "", x = 0, y = ORIGINAL_HEIGHT-5, width = ORIGINAL_WIDTH, height = 30, fontsize = 12}})
            Ads(_G.App.News, comps[1], 600, "left", 120, 5)
            return comps[1]
        end)(),
        language = (function()
            local comps = build_ui("h", 
                --{Label = {text = "🌐", x = ORIGINAL_WIDTH - 135, y = ORIGINAL_HEIGHT - 85, width = 20, height = 25, fontsize = 12}},
                {Combobox = {enabled = true, items = {}, x = ORIGINAL_WIDTH - 90, y = ORIGINAL_HEIGHT - 85, width = 70, height = 225}},
                {Label = {text = "Language:", x = ORIGINAL_WIDTH - 90, y = ORIGINAL_HEIGHT - 105, width = 80, height = 20}},
                {Picture = {source = PREP_FILES.ico.earth, x = ORIGINAL_WIDTH - 125, y = ORIGINAL_HEIGHT - 90, width = 35, height = 35, dpi_scale = true}}
            )
            --ui.info("Windows scale factor is x"..math.floor(ui.dpi))
            return {label = comps[2], selectBox = comps[1], icon = comps[3]}
        end)(),
        console = (function()
                local button = build_ui("h", {Button = {text = "▶", x = ORIGINAL_WIDTH - 40, y = 10, width = 30, height = 20}})[1]
                local label = build_ui("h", {Label = {text = "DEBUG CONSOLE", x = ORIGINAL_WIDTH + 45, y = 10, width = CONSOLE_WIDTH - 50, height = 25, textalign = "center"}})[1]
                local dev = build_ui("h", {Edit = {text = "", x = ORIGINAL_WIDTH - 50, y = 0, width = 50, height = 30, border = false, readonly = true, bgcolor = window.bgcolor}})[1]
                local text = build_ui("h", {Edit = {text = "", x = ORIGINAL_WIDTH, y = 40, width = CONSOLE_WIDTH - 10, height = ORIGINAL_HEIGHT - 50, readonly = true, border = false}})[1]
                return {button = button, text = text, label = label, dev = dev, visible = false}
            end)(),
        about = (function()
            local comps = build_ui("h",
                {Label = {text = "by adalbertalexadru.ungureanu@flex.com", x = 5, y = 0, width = 450, height = 40, fontsize = 10}}
            )
            return {label = comps[1]}
        end)(),

        bomsplit = (function()
            local comps = build_ui("h",
                {Label = {text = lang.Labels.BOMSplitPath or "", x = 20, y = 5 + 35, width = 105, height = 25}},
                {Entry = {text = config.Last.BOMSplitPath or lang.Buttons.BOMSplitPath or "", x = 105 + 25 - 5, y = 5 + 35, width = (ORIGINAL_WIDTH-(105 + 25)-50), height = 25, fontsize = 12, allowdrop = true, xgap_before = 20}},
                {Label = {text = "cm", x = (105 + 25 - 5) + (ORIGINAL_WIDTH-(105 + 25)-50-20), y = 5 + 35 + 10, width = 20, height = 15, fontsize = 7, border = false, readonly = false, bgcolor = window.bgcolor, textalign = "center"}},
                {Picture = {source = PREP_FILES.ico.upload, y = 5 + 35, width = 25, height = 25, allowdrop = true, xgap_before = 10, dpi_scale = true}}
            )
            comps[3]:tofront()
        
            return {label = comps[1], entry = comps[2], measure = comps[3], input = comps[4]}
        end)(),

        pincad = (function()
            local comps = build_ui("h", 
                {Label = {text = lang.Labels.PINSCadPath or "", x = 20, y = 5 + 70, width = 105, height = 25}},
                {Entry = {text = config.Last.PINSCadPath or lang.Buttons.PINSCadPath or "", x = 105 + 25 - 5, y = 5 + 70, width = (ORIGINAL_WIDTH-(105 + 25)-50), height = 25, fontsize = 12, allowdrop = true, xgap_before = 20}},
                {Label = {text = "cm", x= (105 + 25 - 5) + (ORIGINAL_WIDTH-(105 + 25)-50-20), y = 5 + 70+10, width = 20, height = 15, fontsize = 7, border = false, readonly = false, bgcolor = window.bgcolor, textalign = "center"}},
                {Picture ={source = PREP_FILES.ico.upload, y = 5 + 70, width = 25, height = 25, allowdrop = true, xgap_before = 10, dpi_scale = true}}
            )
            comps[3]:tofront()
            --comps[4] = ui.Picture(window, PREP_FILES.ico.destination,125 + 20+(ORIGINAL_WIDTH-125-20-padding-30)+5, 5 + 70, 24*math.floor(ui.dpi),24*math.floor(ui.dpi))
            return {label = comps[1], entry = comps[2], measure = comps[3], input = comps[4]}
        end)(),
        program = (function()
            local comps = build_ui("h",
                {Label = {text = "", x = 20, y = 160, width = 105, height = 25}},
                {Entry = {text = "", x = 105+20, y = 160, width = (ORIGINAL_WIDTH-(105 + 25)-24*math.floor(ui.dpi)) , height = 20, border = false, fontsize = 10}}
            )
            --comps[2]:autosize()
            return {label = comps[1], input = comps[2]}
        end)(),
        client = (function()
            local comps = build_ui("h",
                {Label = {text = "Client:", x = 20, y = 120, width = 105, height = 25}},
                {Combobox = {items = {}, x = 105 + 20, y = 120, width = 100, height = 175}},
                {Picture = {source = PREP_FILES.ico.del, x = 105 + 20+100, y = 120, width=18, height=18, dpi_scale = true}},
                --# Normalize Gap Between
                {Entry = {text = "", y = 120, width=120, height = 25, fontsize = 10, xgap_before = 100}},
                {Picture = {source = PREP_FILES.ico.add, y = 110, width=45, height=45, scale_with_dpi = true}}
            )
            comps[3]:tofront()
            return {label = comps[1], selectBox = comps[2], removeButton = comps[3], addEntry = comps[4], addButton = comps[5]}
        end)(),
        GenerateButton = build_ui("h",
            {Button = {text = "GENERATE .CAD/CSV", x = 150, y = 220, width = 200, height = 40, fontsize=14}}
        )[1], -- Still a singleton
        pb = build_ui("h",
            {Progressbar = {value = 0, x = 0, y = 270, width = ORIGINAL_WIDTH, height = 40, fgcolor = 0x3D85C6, bgcolor = 0x000000, range = {0, 100}}}
        )[1],
        pbLabel = build_ui("h",
            {Label = {text = "", x = math.floor(ORIGINAL_WIDTH/2/2), y = 271, width = math.floor(ORIGINAL_WIDTH/2), height = 24, textalign = "center", fontsize = 12, bgcolor = 0x000000, fgcolor = 0xFFFFFF}}
        )[1],
        exit = build_ui("h", {Button = {text = "Exit", x = ORIGINAL_WIDTH - 130, y = ORIGINAL_HEIGHT - 55, width = 115, height = 30}})[1],
        lang = lang,
        config = config,
        window = window
    }

    xdbg:Log("Setting component properties", LOG_FILES.UI)
    components.console.button:hide() 
    components.console.label:hide()
    components.exit:tofront()
    --components.pb:tofront()
    --components.pbLabel:tofront()
    components.ads:toback()
    --Ads(link, label, interval, textalign)

    xdbg:Log("Populating language select box", LOG_FILES.UI)
    local languages = {}
    local lang_dir = Dir("data/lang")
    if not lang_dir.exists then 
        xdbg:Log("Creating lang directory: data/lang", LOG_FILES.UI)
        lang_dir:make() 
    end
    for file in lang_dir:list("*.json") do
        local parselang = file.name:gsub("%.json$", "")
        table.insert(languages, parselang)
    end
    table.sort(languages)
    if #languages == 0 then 
        xdbg:Log("No languages found, defaulting to 'en'", LOG_FILES.UI)
        languages = {"en"} 
    end
    for _, lang_name in ipairs(languages) do 
        components.language.selectBox:add(lang_name) 
    end

    local current_lang = config.Language and config.Language:match("([^/]+)%.json$") or "en"
    components.language.selectBox.text = current_lang
    xdbg:Log("Loading initial language: " .. current_lang, LOG_FILES.UI)
     
    update_ui_with_language(components, current_lang) 

    components.client.addEntry.border = false
    components.program.input.border = false
    xdbg:Log("Loading client list from config", LOG_FILES.UI)
    for word in config.Clients:gmatch("[^,]+") do 
        components.client.selectBox:add(word) 
    end
    --components.client.selectBox.items = config.Clients
    components.client.selectBox.text = #config.Last.OptionClient > 0 and config.Last.OptionClient or components.client.selectBox.items[#components.client.selectBox.items].text or "UNKNOWN_CLIENT"
    config.Last.OptionClient = components.client.selectBox.text
    components.client.selectBox.editable = false

    xdbg:Log("Overriding Log for console output", LOG_FILES.UI)
    local _xdbg = xdbg.Log
    local pendingLines = {} -- Queue for lines to append
    local isAppending = false -- Flag to prevent multiple async tasks

    -- Function to append lines after a delay
    local function appendWithDelay()
        isAppending = true
        sleep(1000) -- Delay before appending 1 second`
        -- Append all pending lines to the UI
        while #pendingLines > 0 do
            local line = table.remove(pendingLines, 1) -- Take the first line (oldest first)
            components.console.text:append(line .. "\n")
        end
        isAppending = false
    end

    xdbg.Log = function(self, message, file, func)
        local result = _xdbg(self, message, file, func)
        if type(result) == "table" and components.console.text then
            -- Format the new log line
            local newLine = result.func .. "    /   Line: "..result.line.."\n      " .. result.message
            -- Add directly to pendingLines (oldest first)
            table.insert(pendingLines, newLine)
            -- Start async task if not already appending
            if not isAppending then
                async(function()
                    appendWithDelay()
                end)
            end
        end
        return result
    end

    xdbg:Log("Setting up event handlers", LOG_FILES.UI)
    setup_event_handlers(window, components, config, lang)
    xdbg:Log("Calling ui.update", LOG_FILES.UI)
    
    components.ads:tofront()
    ui.update()
    components.lang = lang
    components.config = config
    components.window = window
    xdbg:Log("Function completed", LOG_FILES.UI)
    return {window = window, components = components, config = config}
end

-- Optimized AutoUpdate with async fetching and cleanup
-- Manages application updates with tray integration
-- Args: config (table with sources and version)
-- Returns: Update manager object
-- How it works: Checks sources for updates, applies them with cleanup
local AutoUpdate = function(config)
    xdbg:Log("Function started", LOG_FILES.DATA_PROC)
    local cfg = {sources = {}, currentVersion = "0"}
    for k, v in pairs(config or {}) do 
        cfg[k] = v 
    end
    xdbg:Log("Config initialized with sources: " .. table.concat(cfg.sources, ", "), LOG_FILES.DATA_PROC)

    -- Checks if a source is a web URL
    local function isWebSource(url) 
        return url and url:lower():match("^https?://") 
    end

    -- Parses version string to number
    local function parseVersion(ver) 
        return tonumber((ver or "0"):gsub("%D", "") or 0) 
    end

    -- Compares versions numerically
    local function isNewer(current, remote) 
        return remote > current 
    end

    -- Creates a PowerShell script for cleanup
    local function createCleanupScript()
        xdbg:Log("Generating cleanup script", LOG_FILES.DATA_PROC)
        local psContent = [[
            param (
                [string]$oldExeName = $args[0],
                [string]$oldExePath = $args[1],
                [string]$newExePath = $args[2],
                [string]$debugMode = $args[3]
            )
            
            function Write-Debug {
                param([string]$message)
                if ($debugMode -eq "debug") {
                    Write-Host "[DEBUG] $message"
                }
            }
            
            $scriptPath = $MyInvocation.MyCommand.Path
            $cleanupScript = {
                if (Test-Path $scriptPath) {
                    Remove-Item -Path $scriptPath -Force
                    Write-Debug "Cleanup script removed itself"
                }
            }
            
            Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $cleanupScript
            
            try {
                Write-Debug "Received parameters:"
                Write-Debug " - Old Executable Name: $oldExeName"
                Write-Debug " - Old Executable Path: $oldExePath"
                Write-Debug " - New Executable Path: $newExePath"
            
                Write-Debug "Attempting to terminate process: $oldExeName"
                $process = Get-Process -Name $oldExeName -ErrorAction SilentlyContinue
                if ($process) {
                    Write-Debug "Process found. Terminating..."
                    Stop-Process -Name $oldExeName -Force
                    Start-Sleep -Seconds 1
                }
            
                Start-Process -FilePath $newExePath
            
                Write-Debug "Waiting for old process to terminate..."
                while ($true) {
                    $process = Get-Process -Name $oldExeName -ErrorAction SilentlyContinue
                    if (-not $process) { break }
                    Start-Sleep -Seconds 1
                }
            
                if (Test-Path $oldExePath) {
                    $retryCount = 0
                    $maxRetries = 5
                    while ($retryCount -lt $maxRetries) {
                        try {
                            Remove-Item -Path $oldExePath -Force
                            Write-Debug "Successfully removed old executable"
                            break
                        } catch {
                            $retryCount++
                            Write-Debug "Attempt $retryCount failed: $_"
                            Start-Sleep -Seconds 2
                        end
                    end
                } else {
                    Write-Debug "Old executable not found: $oldExePath"
                }
            }
            catch {
                Write-Debug "Error during cleanup: $_"
            }
            finally {
                if ($debugMode -eq "debug") {
                    Write-Host "Press Enter to exit..."
                    Read-Host
                }
            }]]
        local psPath = sys.tempfile().path .. "\\fuiX" .. math.random(100000000, 999999999) .. ".ps1"
        xdbg:Log("Writing script to: " .. psPath, LOG_FILES.DATA_PROC)
        withFile(psPath, "w", function(f) f:write(psContent) end)
        xdbg:Log("Script created", LOG_FILES.DATA_PROC)
        return psPath
    end

    -- Fetches version from a source
    local function fetchVersion(source)
        xdbg:Log("Fetching version from: " .. source, LOG_FILES.DATA_PROC)
        if isWebSource(source) then
            local response = Http(source):get()
            local version = response and response.status == 200 and response.content:gsub("%D", "") or "0"
            xdbg:Log("Web fetch result: " .. version, LOG_FILES.DATA_PROC)
            return version
        elseif File(source).exists then
            local version = withFile(source, "r", function(f) return (f:read() or "0"):gsub("%D", "") end) or "0"
            xdbg:Log("File fetch result: " .. version, LOG_FILES.DATA_PROC)
            return version
        end
        xdbg:Log("No version found, defaulting to '0'", LOG_FILES.DATA_PROC)
        return "0"
    end

    -- Checks for updates and applies them
    local function checkForUpdates()
        xdbg:Log("Checking for updates...", LOG_FILES.INFO)
        local currentNumeric = parseVersion(cfg.currentVersion)
        for i, source in ipairs(cfg.sources) do
            xdbg:Log("Checking source " .. i .. ": " .. source, LOG_FILES.DATA_PROC)
            local latestVersion = fetchVersion(source)
            local latestNumeric = parseVersion(latestVersion)
            if isNewer(currentNumeric, latestNumeric) then
                xdbg:Log("New version found: " .. latestVersion, LOG_FILES.INFO)
                if ui.confirm("A new version (" .. latestVersion .. ") is available. Update?", "Update Available") == "yes" then
                    xdbg:Log("Applying update to v" .. latestVersion, LOG_FILES.INFO)
                    local exeName = "fui" .. latestNumeric .. ".exe"
                    local updateBase = source:gsub("update%.txt", "")
                    local updateUrl = updateBase .. latestVersion .. ".txt"
                    xdbg:Log("Fetching update from: " .. updateUrl, LOG_FILES.DATA_PROC)
                    local fileData = File(updateUrl).exists and withFile(updateUrl, "rb", function(f) return f:read("*a") end)
                    if fileData and rec.decompress.unzipBase64(fileData, Dir().path, exeName) then
                        local currentExePath = File(arg[-1]).fullpath
                        local justExe = currentExePath:gsub("[/\\]", "\\"):match("[^\\]+$")
                        local newExePath = File(arg[-1]).path .. "\\" .. exeName
                        xdbg:Log("Creating cleanup script", LOG_FILES.DATA_PROC)
                        local psPath = createCleanupScript()
                        local debug_flag = paramsAsTable["debug"]() and "debug" or ""
                        xdbg:Log("Launching cleanup script: " .. psPath, LOG_FILES.DATA_PROC)
                        sys.cmd(string.format('start powershell -NoProfile -ExecutionPolicy Bypass -File "%s" "%s" "%s" "%s" "%s"', psPath, justExe, currentExePath, newExePath, debug_flag), true, true)
                        cfg.currentVersion = latestVersion
                        xdbg:Log("Update applied, exiting", LOG_FILES.INFO)
                        sys.exit()
                    else
                        xdbg:Log("Failed to apply update v" .. latestVersion, LOG_FILES.ERRORS)
                    end
                else
                    xdbg:Log("User declined update to v" .. latestVersion, LOG_FILES.INFO)
                end
                xdbg:Log("Update check completed (new version found)", LOG_FILES.DATA_PROC)
                return
            end
        end
        xdbg:Log("No updates found", LOG_FILES.INFO)
        xdbg:Log("Function completed", LOG_FILES.DATA_PROC)
    end

    xdbg:Log("Function completed, returning update object", LOG_FILES.DATA_PROC)
    return {
        -- Manages periodic update tasks
        -- Args: self (AutoUpdate object), interval (seconds)
        -- Returns: Task control object
        -- How it works: Starts/stops periodic update checks
        Task = function(self, action)
            --xdbg:Log("Function started with interval: " .. tostring(interval), LOG_FILES.DATA_PROC)
            local interval = tonumber(action) or 0
            if action == "Stop" then
                xdbg:Log("Stopping update task", LOG_FILES.DATA_PROC)
                if self.task then
                    self.task:cancel()
                    self.task = nil
                    xdbg:Log("Periodic update check stopped", LOG_FILES.INFO)
                end
                xdbg:Log("Function completed", LOG_FILES.DATA_PROC)
            end

            if interval <= 0 or action == "Start" then
                xdbg:Log("Immediate update check", LOG_FILES.DATA_PROC)
                checkForUpdates()
                return
            end

            xdbg:Log("Starting update task", LOG_FILES.DATA_PROC)
            if interval and interval > 0 then
                self.task = Task(function()
                    while self.task do
                        checkForUpdates()
                        sleep(interval * 1000)
                    end
                end)
                self.task()
                xdbg:Log("Periodic update check started every " .. interval .. "s", LOG_FILES.INFO)
            end
            xdbg:Log("Function completed", LOG_FILES.DATA_PROC)
        end,

        -- Returns current version
        -- Returns: String (current version)
        -- How it works: Retrieves stored version from config
        GetCurrentVersion = function() 
            xdbg:Log("Returning current version: " .. cfg.currentVersion, LOG_FILES.DATA_PROC)
            return cfg.currentVersion 
        end
    }
end

--[[ MAIN INITIALIZATION ]] --
-- Main initialization with lazy loading and minimal redraws
-- Sets up the UI and starts the application
-- How it works: Constructs UI, sets up logging tasks, initiates update checks, runs event loop
xdbg:Log("Starting application initialization", LOG_FILES.UI, "Main")
local rec = construct() -- Define rec here to avoid undefined variable later
local ui_app = uiConstruct(
    load_config({
        Last = {
            BOMSplitPath = "Click to select BOM",
            PINSCadPath = "Click to select PINS",
            OptionClient = "",
            ProgramEntry = ""
        },
        Clients = {"GEC","PBEH","AGI","NER","SEA4","SEAH","ADVA","NOK"},
        Language = "data/lang/en.json" -- Default language path
    }, "fui.ini"),
    load_language("en", {
        Buttons = {
            Generate = "Generate .CAD/CSV",
            Add = "Add",
            Del = "Del",
            BOMSplitPath = "Click to Select BOM",
            PINSCadPath = "Click to Select PINS",
        },
        Labels = {
            BOMSplit = "Select BOM File",
            PINSCad = "Select PINS File",
            ProgramName = "Program name",
            Client = "Client",
        }
    }) and load_language("ro", {
        Buttons = {
            Generate = "Generează .CAD/CSV",
            Add = "Adaugă",
            Del = "Șterge",
            BOMSplitPath = "Clic pentru a selecta fișierul BOM",
            PINSCadPath = "Clic pentru a selecta fișierul PINS",
        },
        Labels = {
            BOMSplit = "Selectați fișierul BOM",
            PINSCad = "Selectați fișierul PINS",
            ProgramName = "Nume program",
            Client = "Clientul",
        }
    })
)

xdbg:Log("Setting up logging tasks", LOG_FILES.DATA_PROC, "Main:XDBG Task")

local tasks = { save = 300, print = 0 }
for nChild, bChild in pairs(paramsAsTable["debug"]) do
    --if bChild and (nChild == "print" or "save") table.insert(cBuffer[nChild], entry)
    if bChild and tasks[nChild] then xdbg:Task(tasks[nChild], nChild, nChild == "save" and "data/debug" or nil) end
end

xdbg:Log("Initializing AutoUpdate", LOG_FILES.DATA_PROC, "Main:AutoUpdate Task")
AutoUpdate({
    sources = (paramsAsTable["debug"]() and {"D://update.txt"} or _G.App.Update),
    currentVersion = paramsAsTable["noversion"]() and "0" or _G.App.Version
}):Task("Start")

xdbg:Log("Showing UI window", LOG_FILES.UI, "Main: UI APP")
ui_app.window.topmost = true
ui_app.window:show()
xdbg:Log("Starting UI event loop", LOG_FILES.UI, "Main: UI APP")
ui.run(ui_app.window):wait()
xdbg:Log("Application terminated", LOG_FILES.UI, "Main: UI APP")
