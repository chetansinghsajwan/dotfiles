-- Reimplements full-border's Tab.build wrapper (padding + outer/inner
-- border) with one addition: the current pane's border is titled with the
-- full cwd. full-border itself has no option for this, so this forks its
-- ~12-line setup rather than fighting it via further monkey-patching -
-- must run first (in full-border's place), since properties/places below
-- chain through whatever Tab.build already is and expect this padding to
-- have already happened by the time they run.
do
	local border_type = ui.Border.ROUNDED
	local old_build = Tab.build

	Tab.build = function(self, ...)
		local c = self._chunks
		self._chunks = {
			c[1]:pad(ui.Pad.y(1)),
			c[2]:pad(ui.Pad.y(1)),
			c[3]:pad(ui.Pad.y(1)),
		}

		local style = th.mgr.border_style
		self._base = ya.list_merge(self._base or {}, {
			ui.Border(ui.Edge.ALL)
				:area(c[2])
				:type(border_type)
				:style(style)
				:title(ui.Line(tostring(self._tab.current.cwd)):align(ui.Align.LEFT)),
			ui.Border(ui.Edge.ALL):area(self._area):type(border_type):style(style):merge(),
		})

		old_build(self, ...)
	end
end

require("bookmarks"):setup()
require("properties"):setup()
-- Must load after properties: its Tab.build wrapper needs to run outermost,
-- chaining through properties'/full-border's first, so self._chunks[1] is
-- already padded and self._children already built by the time it swaps in
-- the places panel.
require("places"):setup()

-- Trim the status line to just the mode and position pills — name/size/perm
-- already live in the properties panel, and the scroll-percent pill is noise.
for i = #Status._left, 1, -1 do
	if Status._left[i][1] == "length" or Status._left[i][1] == "name" then
		table.remove(Status._left, i)
	end
end
for i = #Status._right, 1, -1 do
	if Status._right[i][1] == "perm" or Status._right[i][1] == "percent" then
		table.remove(Status._right, i)
	end
end

-- Combined "permissions + relative mtime" linemode for the files pane.
-- Permissions are rendered as three spaced, colorized rwx triplets
-- (owner in full color, group/other dimmed, special bits highlighted)
-- instead of a raw `ls -la` string, and mtime is a relative duration.
local function perm_span(ch, is_owner)
	if ch == "s" or ch == "S" or ch == "t" or ch == "T" then
		return ui.Span(ch):fg("magenta"):bold()
	end
	if not is_owner then
		return ui.Span(ch):fg("darkgray")
	end
	if ch == "r" then
		return ui.Span(ch):fg("green")
	elseif ch == "w" then
		return ui.Span(ch):fg("yellow")
	elseif ch == "x" then
		return ui.Span(ch):fg("red")
	else
		return ui.Span(ch):fg("darkgray")
	end
end

local function perm_spans(cha)
	local bits = cha and cha:perm()
	if not bits or #bits < 10 then
		return { ui.Span("---------"):fg("darkgray") }
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

local function relative_time(time)
	time = math.floor(time or 0)
	if time == 0 then
		return "-"
	end

	local diff = os.time() - time
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
		return os.date("%Y", time)
	end
end

function Linemode:perm_mtime()
	local spans = perm_spans(self._file.cha)
	spans[#spans + 1] = ui.Span("  ")
	local time = relative_time(self._file.cha and self._file.cha.mtime)
	spans[#spans + 1] = ui.Span(string.format("%8s", time)):fg("darkgray")
	return spans
end
