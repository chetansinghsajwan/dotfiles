--- Toggleable left panel listing quick-reference locations: XDG favorite
--- folders, the bookmarks.yazi marks, removable/connected drives, recently
--- visited directories, and open tabs. Purely a display panel - like
--- properties.yazi, it has no cursor/click navigation of its own; jumping
--- still goes through yazi's existing mechanisms (bookmarks' `'`, manual
--- cd, etc). Toggle with the `places toggle` command.
---
--- Reuses the parent-directory column (chunk 1), which this config leaves
--- at width 0 via `mgr.ratio` in yazi.nix. BASE_RATIO below must match
--- that setting - when hidden, the layout falls back to exactly it.

local DIM = "darkgray"
local BASE_RATIO = { 0, 3, 6 } -- must match `mgr.ratio` in yazi.nix
local SIDEBAR_WEIGHT = 2
local RECENT_LIMIT = 8

-- Holds the plugin's persistent sync state once `setup` runs, so the
-- (sync-context) redraw path can read the data refreshed on toggle-on.
local module_state

local FAVORITE_DIRS = {
    { key = "DESKTOP", label = "Desktop" },
    { key = "DOCUMENTS", label = "Documents" },
    { key = "DOWNLOAD", label = "Downloads" },
    { key = "MUSIC", label = "Music" },
    { key = "PICTURES", label = "Pictures" },
    { key = "VIDEOS", label = "Videos" },
}

local function basename(path)
    return path:match("([^/]+)/?$") or path
end

-- ***** Layout: give the parent-column chunk real width when visible *****

local function chunks_for(area, visible)
    local a, b, c = BASE_RATIO[1], BASE_RATIO[2], BASE_RATIO[3]
    if visible then
        a = SIDEBAR_WEIGHT
    end
    local total = a + b + c

    return ui.Layout()
        :direction(ui.Layout.HORIZONTAL)
        :constraints({
            ui.Constraint.Ratio(a, total),
            ui.Constraint.Ratio(b, total),
            ui.Constraint.Ratio(c, total),
        })
        :split(area)
end

-- ***** Favorites: static XDG user dirs, refreshed on toggle-on *****

local function xdg_user_dirs()
    local home = os.getenv("HOME") or ""
    local config = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")
    local fh = io.open(config .. "/user-dirs.dirs", "r")
    if not fh then
        return {}
    end

    local dirs = {}
    for line in fh:lines() do
        local key, value = line:match('^XDG_(%u+)_DIR="(.-)"$')
        if key then
            dirs[key] = (value:gsub("%$HOME", home))
        end
    end
    fh:close()
    return dirs
end

-- Plain function, not `ya.sync` - it does filesystem I/O (io.open, fs.cha),
-- which (like Command below) must run outside the sync executor. Its result
-- is handed to commit_refresh, the sync call that actually stores it.
local function compute_favorites()
    local home = os.getenv("HOME")
    local dirs = xdg_user_dirs()
    local favorites = {}

    if home and fs.cha(Url(home)) then
        favorites[#favorites + 1] = { label = "Home", path = home }
    end

    for _, fav in ipairs(FAVORITE_DIRS) do
        local path = dirs[fav.key]
        if path and fs.cha(Url(path)) then
            favorites[#favorites + 1] = { label = fav.label, path = path }
        end
    end

    return favorites
end

-- ***** Bookmarks: live via the same DDS key bookmarks.yazi persists to *****

local function load_bookmarks(state)
    ps.sub_remote("@bookmarks", function(body)
        local list = {}
        if body then
            for _, value in pairs(body) do
                list[#list + 1] = value
            end
        end
        state.bookmarks = list
        ui.render()
    end)
end

-- ***** Drives: removable block devices, plus WSL2's drive-letter mounts *****
--
-- On bare-metal Linux, lsblk's RM=1 flag is enough. This machine is WSL2
-- though, where real drives never show up as block devices lsblk can see -
-- they show up as extra Windows drive letters auto-mounted under /mnt.
-- /mnt/c is the permanent system drive (excluded); /mnt/wsl and
-- /mnt/wslg are WSL-internal (excluded by the single-letter pattern below).

local function parse_lsblk_line(line)
    local fields = {}
    for key, value in line:gmatch('(%u+)="([^"]*)"') do
        fields[key] = value
    end
    return fields
end

-- Plain function, not `ya.sync` - it shells out (Command) and reads
-- /proc/mounts, both of which must happen outside the sync executor.
local function compute_drives()
    local drives, seen = {}, {}

    local output = Command("lsblk"):arg({ "-P", "-o", "NAME,MOUNTPOINT,LABEL,SIZE,RM,TYPE" }):output()
    if output then
        for line in output.stdout:gmatch("[^\r\n]+") do
            local f = parse_lsblk_line(line)
            if f.RM == "1" and f.MOUNTPOINT and f.MOUNTPOINT ~= "" and not seen[f.MOUNTPOINT] then
                seen[f.MOUNTPOINT] = true
                drives[#drives + 1] = {
                    label = (f.LABEL ~= "" and f.LABEL) or basename(f.MOUNTPOINT),
                    path = f.MOUNTPOINT,
                    size = f.SIZE,
                }
            end
        end
    end

    local fh = io.open("/proc/mounts", "r")
    if fh then
        for line in fh:lines() do
            local mountpoint = line:match("^%S+ (%S+) ")
            if mountpoint then
                mountpoint = mountpoint:gsub("\\040", " ")
                local extra_drive_letter = mountpoint:match("^/mnt/%a$") and mountpoint ~= "/mnt/c"
                local media = mountpoint:match("^/media/") or mountpoint:match("^/run/media/")
                if (extra_drive_letter or media) and not seen[mountpoint] then
                    seen[mountpoint] = true
                    drives[#drives + 1] = { label = basename(mountpoint), path = mountpoint }
                end
            end
        end
        fh:close()
    end

    return drives
end

-- ***** Recent dirs: frecency over "cd" events, persisted like bookmarks *****

local load_recent = ya.sync(function(state)
    ps.sub_remote("@places-recent", function(body)
        if body then
            state.recent = body
        end
    end)
end)

local record_visit = ya.sync(function(state)
    local cwd = tostring(cx.active.current.cwd)
    local home = os.getenv("HOME")
    if home and cwd == home then
        return -- landing in $HOME on every session start would dominate the list
    end

    state.recent = state.recent or {}
    local entry = state.recent[cwd] or { count = 0 }
    entry.count = entry.count + 1
    entry.last = os.time()
    state.recent[cwd] = entry

    ps.pub_to(0, "@places-recent", state.recent)
end)

local function top_recent(recent, limit)
    local list = {}
    for path, e in pairs(recent or {}) do
        local age_hours = math.max((os.time() - (e.last or 0)) / 3600, 0)
        list[#list + 1] = { path = path, score = e.count / (1 + age_hours) }
    end
    table.sort(list, function(a, b)
        return a.score > b.score
    end)

    local top = {}
    for i = 1, math.min(limit, #list) do
        top[i] = list[i]
    end
    return top
end

-- ***** Rendering *****

-- Indents entries under their section header, so the header reads as a
-- title and the entries as a nested list rather than all flush-left.
local ENTRY_INDENT = "  "

-- Every entry here is a directory (favorites/drives/recent/tabs always are;
-- bookmarks usually are too), so they get the same blue+bold the files pane
-- gives directories - see the `{ url = "*/", fg = "blue" }` fallback rule in
-- yazi's default theme.toml. Decorative bits (bookmark key, drive size, tab
-- index) stay dim instead, so the name itself is what draws the eye - the
-- same split the files pane makes between its dim linemode column and its
-- colored name column.
local DIR_FG = "blue"

-- entries: { { prefix = "optional dim text before the name", name = "...",
-- suffix = "optional dim text after the name" }, ... }
local function section(lines, title, entries, empty_text)
    lines[#lines + 1] = ui.Line(ui.Span(title):fg(DIM):bold())
    if #entries == 0 then
        lines[#lines + 1] = ui.Line(ui.Span(ENTRY_INDENT .. (empty_text or "-")):fg(DIM))
    else
        for _, e in ipairs(entries) do
            local spans = { ui.Span(ENTRY_INDENT) }
            if e.prefix then
                spans[#spans + 1] = ui.Span(e.prefix):fg(DIM)
            end
            spans[#spans + 1] = ui.Span(e.name):fg(DIR_FG):bold()
            if e.suffix then
                spans[#spans + 1] = ui.Span(e.suffix):fg(DIM)
            end
            lines[#lines + 1] = ui.Line(spans)
        end
    end
    lines[#lines + 1] = ui.Line("")
end

local function build_lines(state)
    local lines = {}

    local favorites = {}
    for _, fav in ipairs(state.favorites or {}) do
        favorites[#favorites + 1] = { name = fav.label }
    end
    section(lines, "Favorites", favorites)

    local bookmarks = {}
    for _, b in ipairs(state.bookmarks or {}) do
        bookmarks[#bookmarks + 1] = { prefix = string.format("'%s ", b.on), name = basename(b.path) }
    end
    section(lines, "Bookmarks", bookmarks, "none saved")

    local drives = {}
    for _, d in ipairs(state.drives or {}) do
        drives[#drives + 1] = { name = d.label, suffix = d.size and (" (" .. d.size .. ")") or nil }
    end
    section(lines, "Drives", drives, "none detected")

    local recent = {}
    for _, r in ipairs(top_recent(state.recent, RECENT_LIMIT)) do
        recent[#recent + 1] = { name = basename(r.path) }
    end
    section(lines, "Recent", recent, "none yet")

    local tabs = {}
    for _, t in ipairs(state.tabs or {}) do
        tabs[#tabs + 1] = { prefix = (t.active and "*" or " ") .. t.index .. " ", name = basename(t.cwd) }
    end
    section(lines, "Tabs", tabs)

    return lines
end

Places = { _id = "places" }

function Places:new(area, tab)
    return setmetatable({ _area = area, _tab = tab }, { __index = self })
end

function Places:reflow()
    return { self }
end

function Places:redraw()
    return { ui.Text(build_lines(module_state)):area(self._area:pad(ui.Pad(0, 1, 0, 1))):wrap(ui.Wrap.YES) }
end

function Places:click(event, up) end
function Places:scroll(event, step) end
function Places:touch(event, step) end

-- ***** Wiring *****

-- Just flips the flag and re-renders immediately, so hiding the panel (or
-- showing it with whatever data is already cached from last time) is instant
-- - the Command/io-driven refresh below follows up a moment later.
local toggle_visible = ya.sync(function(state)
    state.visible = not state.visible
    ui.render()
    return state.visible
end)

-- Commits favorites/drives (computed by the plain functions above, outside
-- the sync executor) and reads tabs (pure cx access, safe here) in one pass,
-- then re-renders with the fresh data.
local commit_refresh = ya.sync(function(state, favorites, drives)
    state.favorites = favorites
    state.drives = drives

    local tabs = {}
    local active_cwd = tostring(cx.active.current.cwd)
    for i = 1, #cx.tabs do
        local tab = cx.tabs[i]
        local cwd = tostring(tab.current.cwd)
        tabs[#tabs + 1] = { index = i, cwd = cwd, active = cwd == active_cwd }
    end
    state.tabs = tabs

    ui.render()
end)

local function setup(state)
    module_state = state
    state.visible = true

    Tab.layout = function(self)
        self._chunks = chunks_for(self._area, state.visible)
    end

    local old_build = Tab.build
    Tab.build = function(self, ...)
        old_build(self, ...)

        if not state.visible then
            return
        end

        for i, child in ipairs(self._children) do
            if child._id == "parent" then
                self._children[i] = Places:new(self._chunks[1], self._tab)
                break
            end
        end
    end

    load_bookmarks(state)
    load_recent()
    ps.sub("cd", record_visit)

    -- Visible by default, so it needs its first data population without
    -- waiting for a toggle keypress. Self-invoke through the plugin entry
    -- point (same technique yazi's own mount.yazi uses to self-refresh)
    -- rather than calling compute_favorites/compute_drives directly here -
    -- setup() runs once during init.lua's own execution, and routing
    -- through ya.emit("plugin", ...) guarantees this runs in the same
    -- context a normal keybinding invocation would, not nested inside
    -- setup()'s.
    ya.emit("plugin", { "places", "refresh" })
end

local function entry(_, job)
    local action = job.args and job.args[1]

    if action == "toggle" then
        if toggle_visible() then
            commit_refresh(compute_favorites(), compute_drives())
        end
    elseif action == "refresh" then
        commit_refresh(compute_favorites(), compute_drives())
    end
end

return { setup = setup, entry = entry }
