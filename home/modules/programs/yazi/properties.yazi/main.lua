--- Splits the preview pane and renders file properties (permissions, owner,
--- size, timestamps, links, mime type) in the bottom slice.

local DIM = "darkgray"

local function perm_span(ch, is_owner)
	if ch == "s" or ch == "S" or ch == "t" or ch == "T" then
		return ui.Span(ch):fg("magenta"):bold()
	end
	if not is_owner then
		return ui.Span(ch):fg(DIM)
	end
	if ch == "r" then
		return ui.Span(ch):fg("green")
	elseif ch == "w" then
		return ui.Span(ch):fg("yellow")
	elseif ch == "x" then
		return ui.Span(ch):fg("red")
	else
		return ui.Span(ch):fg(DIM)
	end
end

local function perm_spans(cha)
	local bits = cha and cha:perm()
	if not bits or #bits < 10 then
		return { ui.Span("---------"):fg(DIM) }
	end
	bits = bits:sub(2) -- drop the leading type char (d/l/-)

	local spans = {}
	for i = 1, 9 do
		spans[#spans + 1] = perm_span(bits:sub(i, i), i <= 3)
		if i == 3 or i == 6 then
			spans[#spans + 1] = ui.Span(" ")
		end
	end
	return spans
end

-- Left-aligns every row's label to the same column width so values start flush.
local function label(text)
	return ui.Span(string.format("%-9s", text)):fg(DIM)
end

local function relative_time(time)
	local diff = math.max(os.time() - time, 0)
	if diff < 60 then
		return "now"
	elseif diff < 3600 then
		return string.format("%dm ago", math.floor(diff / 60))
	elseif diff < 86400 then
		return string.format("%dh ago", math.floor(diff / 3600))
	elseif diff < 86400 * 30 then
		return string.format("%dd ago", math.floor(diff / 86400))
	elseif diff < 86400 * 365 then
		return string.format("%dmo ago", math.floor(diff / (86400 * 30)))
	else
		return string.format("%dy ago", math.floor(diff / (86400 * 365)))
	end
end

local function fmt_time(time)
	time = time and math.floor(time)
	if not time or time == 0 then
		return "-"
	end

	local abs
	if os.date("%Y", time) == os.date("%Y") then
		abs = os.date("%b %d %H:%M", time)
	else
		abs = os.date("%b %d  %Y", time)
	end
	return string.format("%s (%s)", abs, relative_time(time))
end

local function name_line(file, cha)
	local name = ui.Span(file.name)
	local style = file:style()
	if style then
		name = name:style(style)
	else
		name = name:bold()
	end

	-- A symlink whose target no longer exists — flag it regardless of theme.
	if cha and cha.is_link and cha.is_orphan then
		name = name:fg("red"):crossed()
	end

	if cha and cha.is_link and file.link_to then
		return ui.Line({ name, ui.Span(" -> "):fg(DIM), ui.Span(tostring(file.link_to)) })
	end
	return ui.Line({ name })
end

local function build_lines(file)
	if not file then
		return { ui.Line("") }
	end

	local cha = file.cha

	local owner = "-"
	if cha and cha.uid then
		local user = ya.user_name and ya.user_name(cha.uid) or tostring(cha.uid)
		local group = ya.group_name and ya.group_name(cha.gid) or tostring(cha.gid)
		owner = string.format("%s:%s", user, group)
	end

	local size = file:size()
	size = size and ya.readable_size(size) or "-"

	local links = (cha and cha.nlink) and tostring(cha.nlink) or "-"

	local perm = perm_spans(cha)
	table.insert(perm, 1, label("Perm"))

	return {
		name_line(file, cha),
		ui.Line(perm),
		ui.Line({ label("Owner"), ui.Span(owner) }),
		ui.Line({ label("Size"), ui.Span(size) }),
		ui.Line({ label("Modified"), ui.Span(fmt_time(cha and cha.mtime)) }),
		ui.Line({ label("Created"), ui.Span(fmt_time(cha and cha.btime)) }),
		ui.Line({ label("Links"), ui.Span(links) }),
		ui.Line({ label("Type"), ui.Span(file:mime() or "-") }),
	}
end

local function build_selection_summary(tab)
	local files, dirs, total = 0, 0, 0
	for _, f in pairs(tab.selected) do
		if f.cha and f.cha.is_dir then
			dirs = dirs + 1
		else
			files = files + 1
			total = total + ((f.cha and f.cha.len) or 0)
		end
	end

	return {
		ui.Line({ ui.Span(string.format("%d items selected", files + dirs)):bold() }),
		ui.Line({ label("Files"), ui.Span(tostring(files)) }),
		ui.Line({ label("Dirs"), ui.Span(tostring(dirs)) }),
		ui.Line({ label("Size"), ui.Span(ya.readable_size(total)) }),
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
	local tab = self._tab
	local lines = #tab.selected > 1 and build_selection_summary(tab) or build_lines(tab.current.hovered)

	return {
		ui.Border(ui.Edge.TOP):area(self._area):type(ui.Border.ROUNDED):style(th.mgr.border_style),
		ui.Text(lines):area(self._area:pad(ui.Pad(1, 1, 0, 0))):wrap(ui.Wrap.YES),
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
