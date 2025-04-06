module UnicodeForge

export get, concat, format, list, set_encoding

println("UnicodeForge module loading...")

# Predefined Unicode characters
const PREDEFINED = Dict(
    "ZWSP" => "\u200B",  # Zero Width Space
    "ZWNJ" => "\u200C",  # Zero Width Non-Joiner
    "ZWJ" => "\u200D",   # Zero Width Joiner
    "WJ" => "\u2060",    # Word Joiner
    "IS" => "\u2063",    # Invisible Separator
    "SHY" => "\u00AD"    # Soft Hyphen
)

# Encoding mode: "manual" or "utf8"
encoding_mode = "utf8"  # Default to utf8

"""
    manual_utf8(num::Integer)

Manual UTF-8 encoding function for Unicode code points.
"""
function manual_utf8(num::Integer)
    if num <= 0x7F
        return Char(num)
    elseif num <= 0x7FF
        return string(Char(0xC0 | (num >> 6)), Char(0x80 | (num & 0x3F)))
    elseif num <= 0xFFFF
        return string(Char(0xE0 | (num >> 12)), Char(0x80 | ((num >> 6) & 0x3F)), Char(0x80 | (num & 0x3F)))
    elseif num <= 0x10FFFF
        return string(Char(0xF0 | (num >> 18)), Char(0x80 | ((num >> 12) & 0x3F)), Char(0x80 | ((num >> 6) & 0x3F)), Char(0x80 | (num & 0x3F)))
    end
    return PREDEFINED["ZWSP"]  # Fallback for invalid
end

"""
    get(choice::String)

Get a Unicode character by name or code point.
"""
function get(choice::String)
    if haskey(PREDEFINED, choice)
        return PREDEFINED[choice]
    end
    
    # Check if it's a Unicode code point in the format \u{XXXX}
    m = match(r"^\\u\{([0-9A-Fa-f]+)\}$", choice)
    if m !== nothing
        hex = m[1]
        num = parse(Int, hex, base=16)
        if encoding_mode == "utf8"
            return Char(num)
        else
            return manual_utf8(num)
        end
    end
    
    return PREDEFINED["ZWSP"]  # Default fallback
end

"""
    concat(invis::String, args...)

Concatenate multiple strings with a chosen Unicode character as separator.
"""
function concat(invis::String, args...)
    sep = get(invis)
    if isempty(args)
        return ""
    end
    
    result = string(args[1])
    for i in 2:length(args)
        result = result * sep * string(args[i])
    end
    
    return result
end

"""
    format(invis::String, base::String, suffix::String, pattern::String="{base}{invis}{suffix}")

Build a string from base, Unicode character, and suffix using a pattern.
"""
function format(invis::String, base::String, suffix::String, pattern::String="{base}{invis}{suffix}")
    uni = get(invis)
    return replace(pattern, "{base}" => base, "{invis}" => uni, "{suffix}" => suffix)
end

"""
    list()

Return an array of predefined Unicode character names.
"""
function list()
    return collect(keys(PREDEFINED))
end

"""
    set_encoding(mode::String)

Switch between "manual" and "utf8" encoding modes.
"""
function set_encoding(mode::String)
    if mode == "manual" || mode == "utf8"
        global encoding_mode = mode
    end
end

end # module 