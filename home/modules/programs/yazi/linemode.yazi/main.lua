--- @sync entry

-- Toggles the files pane's linemode components independently - permissions,
-- owner, size, and (relative) modified time - instead of yazi's built-in
-- `linemode <mode>` command, which only lets you pick one fixed mode at a
-- time. The current mode string is itself the state: init.lua names each
-- combination by joining its active components with "_" in a fixed order
-- (see COMPONENT_ORDER there), so toggling just means parsing that name
-- back out, flipping one component, and re-joining. Invoke with
-- `plugin linemode toggle_<perm|owner|size|time>`.
--
-- @sync entry (above, must be the file's first line to be recognized -
-- see toggle-pane.yazi/smart-paste.yazi/vcs-files.yazi upstream, all of
-- which have it first with nothing before) runs entry in the sync
-- context directly, so cx is available with no ya.sync() wrapper needed -
-- this plugin has no setup()/persistent state table for one to attach to.

local COMPONENT_ORDER = { "perm", "owner", "size", "time" }

local function entry(_, job)
	local action = job.args and job.args[1]
	local toggled = action and action:match("^toggle_(%a+)$")
	if not toggled then
		return
	end

	local active = {}
	for part in (cx.active.pref.linemode or ""):gmatch("[^_]+") do
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

return { entry = entry }
