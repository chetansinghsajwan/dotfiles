require("full-border"):setup()
require("bookmarks"):setup()
require("properties"):setup()
-- Must load after properties: its Tab.build wrapper needs to run outermost,
-- chaining through properties'/full-border's first, so self._chunks[1] is
-- already padded and self._children already built by the time it swaps in
-- the places panel.
require("places"):setup()

-- yazi's header already shows the cwd on the left by default, but via
-- ya.readable_path, which abbreviates $HOME to "~" - show the literal full
-- path instead. Same truncation/flags/styling as the stock Header:cwd,
-- just without the abbreviation step.
function Header:cwd()
    local max = self._area.w - self._right_width
    if max <= 0 then
        return ""
    end

    local s = tostring(self._current.cwd) .. self:flags()
    return ui.Span(ui.truncate(s, { max = max, rtl = true })):style(th.mgr.cwd)
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
-- tell "one span" and "an array of spans" apart at runtime.
local function render_perm(self)
    return perm_spans(self._file.cha)
end

local function render_owner(self)
    local cha = self._file.cha
    if not (cha and cha.uid) then
        return { ui.Span("-"):fg("darkgray") }
    end
    local user = ya.user_name and ya.user_name(cha.uid) or tostring(cha.uid)
    local group = ya.group_name and ya.group_name(cha.gid) or tostring(cha.gid)
    return { ui.Span(string.format("%s:%s", user, group)):fg("darkgray") }
end

local function render_size(self)
    local size = self._file:size()
    return { ui.Span(size and ya.readable_size(size) or "-"):fg("darkgray") }
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
