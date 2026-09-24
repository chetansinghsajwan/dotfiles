--- Toggles the files pane's linemode components independently - permissions,
--- owner, size, and (relative) modified time - instead of yazi's built-in
--- `linemode <mode>` command, which only lets you pick one fixed mode at a
--- time. The current mode string is itself the state: init.lua names each
--- combination by joining its active components with "_" in a fixed order
--- (see COMPONENT_ORDER there), so toggling just means parsing that name
--- back out, flipping one component, and re-joining. Invoke with
--- `plugin linemode-toggle toggle_<perm|owner|size|time>`.
---
--- Named "linemode-toggle", not "linemode" - the latter collides with
--- the built-in Linemode global (yazi's own linemode rendering system,
--- which init.lua's own generated methods also live on), and
--- require("linemode") failed outright with "error converting lua nil
--- to table" before this plugin's code ever ran.
---
--- setup() must be called (see init.lua) for ya.sync() below to have a
--- state table to attach to - without it, entry() crashes at runtime
--- with that same "nil to table" error, even though it never uses the
--- state itself. This is the same pattern properties.yazi/places.yazi
--- already use successfully in this repo.

local COMPONENT_ORDER = { "perm", "owner", "size", "time" }

local function setup(_) end

local get_mode = ya.sync(function(_)
    return cx.active.pref.linemode
end)

local function entry(_, job)
    local action = job.args and job.args[1]
    local toggled = action and action:match("^toggle_(%a+)$")
    if not toggled then
        return
    end

    local active = {}
    for part in (get_mode() or ""):gmatch("[^_]+") do
        active[part] = true
    end
    active[toggled] = not active[toggled]

    local parts = {}
    for _, key in ipairs(COMPONENT_ORDER) do
        if active[key] then
            parts[#parts + 1] = key
        end
    end

    ya.emit("linemode", { #parts > 0 and table.concat(parts, "_") or "none" })
end

return { setup = setup, entry = entry }
