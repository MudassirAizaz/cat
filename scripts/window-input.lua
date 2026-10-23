-- Evaluated by WindowInput with local key, token and enabled values.
-- Remove only our own handles, preserving the user's bindings.
local listeners = rawget(_G, "__catWindowInput") or {}
_G.__catWindowInput = listeners
local function remove(entry)
    for _, binding in ipairs(entry.bindings) do
        binding:remove()
    end
    if entry.closed then
        entry.closed:remove()
    end
    if listeners[key] == entry then
        listeners[key] = nil
    end
end
local previous = listeners[key]
if previous and (enabled or previous.token == token) then
    remove(previous)
end
if not enabled then
    return
end

local current = { token = token, bindings = {} }
listeners[key] = current
current.closed = hl.on("layer.closed", function(layer)
    if layer.namespace == "cat-panel" and "cat-window-" .. layer.pid == key then
        remove(current)
    end
end)
for _, button in ipairs({ 272, 273, 274 }) do
    local binding = hl.bind("mouse:" .. button, function()
        local point = hl.get_cursor_pos()
        if point then
            -- Bar buttons already close or switch panels on release.
            for _, bar in ipairs(hl.get_layers({ namespace = "cat-bar" })) do
                if point.x >= bar.x and point.x < bar.x + bar.w
                    and point.y >= bar.y and point.y < bar.y + bar.h then
                    return
                end
            end
            hl.dispatch(hl.dsp.event(token .. "," .. point.x .. "," .. point.y))
        end
    end, {
        non_consuming = true,
        ignore_mods = true,
        submap_universal = true,
        description = "Cat window popup (" .. key .. ")",
    })
    table.insert(current.bindings, binding)
end
