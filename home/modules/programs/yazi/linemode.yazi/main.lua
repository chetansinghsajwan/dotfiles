--- Toggles the files pane's linemode components independently - permissions,
--- owner, size, and (relative) modified time - instead of yazi's built-in
--- `linemode <mode>` command, which only lets you pick one fixed mode at a
--- time. The current mode string is itself the state: init.lua names each
--- combination by joining its active components with "_" in a fixed order
--- (see COMPONENT_ORDER there), so toggling just means parsing that name
--- back out, flipping one component, and re-joining. Invoke with
--- `plugin linemode toggle_<perm|owner|size|time>`.
---
--- setup() must be called (see init.lua) for this to have anything to
--- read cx from - the "@sync entry" annotation some yazi-rs/plugins
--- plugins use instead didn't work here (still crashed with "error
--- converting lua nil to table" even placed first-line-of-file, per
--- upstream examples). ya.sync(function(state) ...) is the same pattern
--- properties.yazi/places.yazi already use successfully in this repo.

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
