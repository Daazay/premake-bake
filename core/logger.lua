local m = {}

local indent_level = 0

function m.indent_push() indent_level = indent_level + 1 end
function m.indent_pop()  indent_level = math.max(0, indent_level - 1) end
function m.get_indent()  return string.rep("  ", indent_level) end

function m.printf(fmt, ...)
    local msg = string.format(fmt, ...)
    print(m.get_indent() .. msg)
end

function m.verbosef(fmt, ...)
    local msg = string.format(fmt, ...)
    verbosef(m.get_indent() .. msg)
end

return m