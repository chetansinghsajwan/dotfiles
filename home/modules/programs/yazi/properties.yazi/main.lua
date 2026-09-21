--- Splits the preview pane and renders file properties (permissions, owner,
--- size, modified time, mime type) in the bottom slice.

local function build_lines(file)
	if not file then
		return { ui.Line("") }
	end

	local cha = file.cha
	local perm = (cha and cha:perm()) or "-"

	local owner = "-"
	if cha and cha.uid then
		local user = ya.user_name and ya.user_name(cha.uid) or tostring(cha.uid)
		local group = ya.group_name and ya.group_name(cha.gid) or tostring(cha.gid)
		owner = string.format("%s:%s", user, group)
	end

	local size = file:size()
	size = size and ya.readable_size(size) or "-"

	local time = cha and math.floor(cha.mtime or 0) or 0
	local mtime
	if time == 0 then
		mtime = "-"
	elseif os.date("%Y", time) == os.date("%Y") then
		mtime = os.date("%b %d %H:%M", time)
	else
		mtime = os.date("%b %d  %Y", time)
	end

	local mime = file:mime() or "-"

	return {
		ui.Line(file.name),
		ui.Line(string.format("%s  %s", perm, owner)),
		ui.Line(string.format("Size     %s", size)),
		ui.Line(string.format("Modified %s", mtime)),
		ui.Line(string.format("Type     %s", mime)),
	}
end

Properties = { _id = "properties" }

function Properties:new(area, tab)
	return setmetatable({ _area = area, _tab = tab }, { __index = self })
end

function Properties:reflow()
	return { self }
end

function Properties:redraw()
	return {
		ui.Border(ui.Edge.TOP):area(self._area):type(ui.Border.ROUNDED):style(th.mgr.border_style),
		ui.Text(build_lines(self._tab.current.hovered)):area(self._area:pad(ui.Pad(1, 1, 0, 0))):wrap(ui.Wrap.YES),
	}
end

function Properties:click(event, up) end
function Properties:scroll(event, step) end
function Properties:touch(event, step) end

local function setup()
	local old_build = Tab.build

	Tab.build = function(self, ...)
		old_build(self, ...)

		local parts = ui.Layout()
			:direction(ui.Layout.VERTICAL)
			:constraints({ ui.Constraint.Percentage(80), ui.Constraint.Percentage(20) })
			:split(self._chunks[3])

		for i, child in ipairs(self._children) do
			if child._id == "preview" then
				self._children[i] = Preview:new(parts[1]:pad(ui.Pad(0, 1, 0, 0)), self._tab)
				break
			end
		end

		table.insert(self._children, Properties:new(parts[2], self._tab))
	end
end

return { setup = setup }
