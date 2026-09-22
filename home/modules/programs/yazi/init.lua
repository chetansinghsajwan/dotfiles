require("full-border"):setup()
require("bookmarks"):setup()
require("properties"):setup()
-- Must load after properties: its Tab.build wrapper needs to run outermost,
-- chaining through properties'/full-border's first, so self._chunks[1] is
-- already padded and self._children already built by the time it swaps in
-- the places panel.
require("places"):setup()
-- Gives linemode-toggle.yazi's ya.sync() a state table to attach to -
-- without this it crashes at runtime ("error converting lua nil to
-- table") even though its entry() never uses the state itself. Named
-- "linemode-toggle", not "linemode" - the latter collided with the
-- built-in Linemode global (require() itself failed with the exact same
-- "nil to table" error, before this plugin's own code ever ran).
require("linemode-toggle"):setup()

-- Shows the full cwd (not header's abbreviated ~-relative one) as a
-- wrapping banner above the files list, instead of squeezed into the
-- header where it'd truncate with an ellipsis. A border :title() was
-- tried for this first and reverted because titles can't wrap at all.
-- Replacing "current" with a wrapper broke the entire UI (blank
-- screen). Splitting self._chunks[2] before old_build (like
-- properties.yazi does for chunk[3]) put the banner *outside*
-- full-border's border, since full-border draws around whatever
-- self._chunks[2] already is by the time its own wrapper runs -
-- shrinking it first meant the border wrapped only the leftover space,
-- not the banner too.
--
-- This instead waits until AFTER old_build, when "current" already has
-- its real area - the border-padded interior full-border built it
-- with - and splits THAT, so the banner ends up inside the same
-- bordered box as the file list. Only current's _area field is
-- adjusted in place (same instance, not replaced/wrapped - the thing
-- that broke the UI last time), and the banner is added as an
-- independent sibling child.
local CWD_BANNER_HEIGHT = 2

CwdBanner = { _id = "cwd_banner" }

function CwdBanner:new(area, tab)
    return setmetatable({ _area = area, _tab = tab }, { __index = self })
end

function CwdBanner:reflow() return { self } end

function CwdBanner:redraw()
    return {
        ui.Text(tostring(self._tab.current.cwd)):area(self._area):wrap(ui.Wrap.YES):style(th.mgr.cwd),
    }
end

function CwdBanner:click(event, up) end
function CwdBanner:scroll(event, step) end
function CwdBanner:touch(event, step) end

do
    local old_build = Tab.build
    Tab.build = function(self, ...)
        old_build(self, ...)

        for _, child in ipairs(self._children) do
            if child._id == "current" then
                local parts = ui.Layout()
                    :direction(ui.Layout.VERTICAL)
                    :constraints({ ui.Constraint.Length(CWD_BANNER_HEIGHT), ui.Constraint.Min(0) })
                    :split(child._area)

                child._area = parts[2]
                table.insert(self._children, CwdBanner:new(parts[1], self._tab))
                break
            end
        end
    end
end

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

-- Toggleable linemode for the files pane: permissions, owner, size, and
-- relative mtime, independently switched on/off (see linemode.yazi) and
-- combined into a single line. Every non-empty subset gets its own
-- Linemode method, named by joining its active components with "_" in
-- COMPONENT_ORDER - e.g. perm+time is "perm_time", perm alone is "perm".
-- Permissions render as three spaced, colorized rwx triplets (owner in
-- full color, group/other dimmed, special bits highlighted) instead of a
-- raw `ls -la` string; the rest are single dimmed spans.
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

-- Each render_* returns a plain array of spans (even when it's just one),
-- so the composer below can always flatten uniformly instead of having to
-- tell "one span" and "an array of spans" apart at runtime. Every
-- component pads to a fixed width (right-aligned, like ls -la columns)
-- so a mode's column stays flush row-to-row instead of jittering with
-- each file's actual perm string/username/size/time length. perm is
-- naturally fixed (perm_spans always emits 9 chars + 2 separators,
-- fallback included); owner/size/time are padded here to match.
local function render_perm(self)
    return perm_spans(self._file.cha)
end

-- 20 chars comfortably fits "user:group" for realistic name lengths
-- without being excessive; genuinely long names just overflow it rather
-- than get truncated and lose information.
local OWNER_WIDTH = 20

local function render_owner(self)
    local cha = self._file.cha
    local text = "-"
    if cha and cha.uid then
        local user = ya.user_name and ya.user_name(cha.uid) or tostring(cha.uid)
        local group = ya.group_name and ya.group_name(cha.gid) or tostring(cha.gid)
        text = string.format("%s:%s", user, group)
    end
    return { ui.Span(string.format("%" .. OWNER_WIDTH .. "s", text)):fg("darkgray") }
end

local function render_size(self)
    local size = self._file:size()
    local text = size and ya.readable_size(size) or "-"
    return { ui.Span(string.format("%8s", text)):fg("darkgray") }
end

local function render_time(self)
    local time = relative_time(self._file.cha and self._file.cha.mtime)
    return { ui.Span(string.format("%8s", time)):fg("darkgray") }
end

-- Fixed left-to-right order components appear in when combined, and the
-- order their names are joined in to name each combination.
local COMPONENT_ORDER = {
    { key = "perm", render = render_perm },
    { key = "owner", render = render_owner },
    { key = "size", render = render_size },
    { key = "time", render = render_time },
}

for mask = 1, (2 ^ #COMPONENT_ORDER) - 1 do
    local names, renders = {}, {}
    for i, component in ipairs(COMPONENT_ORDER) do
        if (mask >> (i - 1)) & 1 == 1 then
            names[#names + 1] = component.key
            renders[#renders + 1] = component.render
        end
    end

    Linemode[table.concat(names, "_")] = function(self)
        local spans = {}
        for i, render in ipairs(renders) do
            if i > 1 then
                spans[#spans + 1] = ui.Span("  ")
            end
            for _, span in ipairs(render(self)) do
                spans[#spans + 1] = span
            end
        end
        return spans
    end
end
