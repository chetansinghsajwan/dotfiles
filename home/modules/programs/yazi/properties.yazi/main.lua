--- Splits the preview pane and renders file properties (permissions, owner,
--- size, timestamps, links, mime type) in the bottom slice. Toggle with the
--- `properties toggle` command. Archives, CSV/TSV, images and media files get
--- an extra row fetched in the background (`properties archive|csv|image|media`).

local DIM = "darkgray"

-- Holds the plugin's persistent sync state once `setup` runs, so the
-- (sync-context) redraw path can read fetch results written from async fetch().
local module_state

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

-- ***** Type-specific extra row (archive / csv / image / media) *****

local function is_csv_name(name)
	return name:match("%.[cC][sS][vV]$") ~= nil or name:match("%.[tT][sS][vV]$") ~= nil
end

local function is_archive(mime)
	if not mime then
		return false
	end
	for _, needle in ipairs({ "zip", "tar", "7z", "rar", "gzip", "bzip", "xz", "lzma", "zstd" }) do
		if mime:find(needle, 1, true) then
			return true
		end
	end
	return false
end

local function is_csv(mime, name)
	return mime == "text/csv" or mime == "text/tab-separated-values" or is_csv_name(name)
end

local function is_image(mime)
	return mime ~= nil and mime:sub(1, 6) == "image/"
end

local function is_media(mime)
	return mime ~= nil and (mime:sub(1, 6) == "video/" or mime:sub(1, 6) == "audio/")
end

local function extra_kind(mime, name)
	if is_archive(mime) then
		return "Archive"
	elseif is_csv(mime, name) then
		return "CSV"
	elseif is_image(mime) then
		return "Dims"
	elseif is_media(mime) then
		return "Media"
	end
	return nil
end

-- Fetched values live in the plugin's sync state, keyed by file url string:
-- absent = not fetched yet, `false` = fetched but nothing to show, string = value.
local function extra_value(url)
	if not module_state or not module_state.extra then
		return "…"
	end
	local v = module_state.extra[tostring(url)]
	if v == nil then
		return "…"
	elseif v == false then
		return "-"
	end
	return v
end

local set_extra = ya.sync(function(state, key, value)
	state.extra = state.extra or {}
	state.extra[key] = value == nil and false or value
	ui.render()
end)

local function fetch_archive(file)
	local path = tostring(file.url)

	local output = Command("7zz"):arg({ "l", "-slt", path }):output()
	if not output then
		output = Command("7z"):arg({ "l", "-slt", path }):output()
	end
	if not output then
		set_extra(path, nil)
		return
	end

	local kind, method, count = nil, nil, 0
	for line in output.stdout:gmatch("[^\r\n]+") do
		local k, v = line:match("^(%a+) = (.*)$")
		if k == "Path" then
			count = count + 1
		elseif k == "Type" and not kind then
			kind = v
		elseif k == "Method" and not method then
			method = v
		end
	end
	-- The first "Path" block describes the archive itself, not an entry.
	count = math.max(count - 1, 0)

	if not kind then
		set_extra(path, nil)
		return
	end

	local text = kind
	if method then
		text = text .. " (" .. method .. ")"
	end
	text = text .. string.format(", %d item%s", count, count == 1 and "" or "s")
	set_extra(path, text)
end

local function fetch_csv(file)
	if not is_csv_name(file.name) then
		return
	end
	local path = tostring(file.url)

	local fh = io.open(path, "r")
	if not fh then
		set_extra(path, nil)
		return
	end

	local sep = file.name:match("%.[tT][sS][vV]$") and "\t" or ","
	local rows, cols = 0, nil
	for line in fh:lines() do
		rows = rows + 1
		if not cols then
			cols = select(2, line:gsub(sep, "")) + 1
		end
	end
	fh:close()

	if rows == 0 then
		set_extra(path, "empty")
		return
	end
	set_extra(path, string.format("%d row%s, %d col%s", rows, rows == 1 and "" or "s", cols or 0, cols == 1 and "" or "s"))
end

local function be16(s, i)
	return s:byte(i) * 256 + s:byte(i + 1)
end

local function be32(s, i)
	return ((s:byte(i) * 256 + s:byte(i + 1)) * 256 + s:byte(i + 2)) * 256 + s:byte(i + 3)
end

local function le16(s, i)
	return s:byte(i + 1) * 256 + s:byte(i)
end

local function le32(s, i)
	return ((s:byte(i + 3) * 256 + s:byte(i + 2)) * 256 + s:byte(i + 1)) * 256 + s:byte(i)
end

-- Scans JPEG markers after SOI for the first SOF segment (width/height).
local function jpeg_dims(fh)
	fh:seek("set", 2)
	while true do
		local marker = fh:read(4)
		if not marker or #marker < 4 or marker:byte(1) ~= 0xFF then
			return nil
		end
		local kind, len = marker:byte(2), be16(marker, 3)
		if kind >= 0xC0 and kind <= 0xCF and kind ~= 0xC4 and kind ~= 0xC8 and kind ~= 0xCC then
			local seg = fh:read(5)
			if not seg or #seg < 5 then
				return nil
			end
			return be16(seg, 4), be16(seg, 2)
		end
		if not fh:seek("cur", len - 2) then
			return nil
		end
	end
end

-- Reads width/height straight out of PNG/GIF/BMP/JPEG headers — no imagemagick dependency.
local function image_dims(path)
	local fh = io.open(path, "rb")
	if not fh then
		return nil
	end

	local head = fh:read(26) or ""
	local w, h

	if head:sub(1, 8) == "\137PNG\r\n\26\n" then
		w, h = be32(head, 17), be32(head, 21)
	elseif head:sub(1, 3) == "GIF" then
		w, h = le16(head, 7), le16(head, 9)
	elseif head:sub(1, 2) == "BM" then
		w, h = le32(head, 19), le32(head, 23)
	elseif head:byte(1) == 0xFF and head:byte(2) == 0xD8 then
		w, h = jpeg_dims(fh)
	end

	fh:close()
	return w, h
end

local function fetch_image(file)
	local path = tostring(file.url)
	local w, h = image_dims(path)
	set_extra(path, (w and h) and string.format("%d x %d", w, h) or nil)
end

local function fetch_media(file)
	local path = tostring(file.url)

	local output = Command("ffprobe")
		:arg({ "-v", "error", "-show_entries", "format=duration:stream=codec_name", "-of", "default=noprint_wrappers=1", path })
		:output()
	if not output then
		set_extra(path, nil)
		return
	end

	local duration, codec
	for line in output.stdout:gmatch("[^\r\n]+") do
		local k, v = line:match("^([%w_]+)=(.+)$")
		if k == "duration" and not duration then
			duration = tonumber(v)
		elseif k == "codec_name" and not codec then
			codec = v
		end
	end

	if not duration then
		set_extra(path, nil)
		return
	end

	local text = string.format("%d:%02d", math.floor(duration / 60), math.floor(duration % 60))
	if codec then
		text = text .. " (" .. codec .. ")"
	end
	set_extra(path, text)
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

	local mime = file:mime()

	local lines = {
		name_line(file, cha),
		ui.Line(perm),
		ui.Line({ label("Owner"), ui.Span(owner) }),
		ui.Line({ label("Size"), ui.Span(size) }),
		ui.Line({ label("Modified"), ui.Span(fmt_time(cha and cha.mtime)) }),
		ui.Line({ label("Created"), ui.Span(fmt_time(cha and cha.btime)) }),
		ui.Line({ label("Links"), ui.Span(links) }),
		ui.Line({ label("Type"), ui.Span(mime or "-") }),
	}

	local kind = extra_kind(mime, file.name)
	if kind then
		lines[#lines + 1] = ui.Line({ label(kind), ui.Span(extra_value(file.url)) })
	end

	return lines
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

local function setup(state)
	module_state = state
	state.visible = true
	state.extra = state.extra or {}

	local old_build = Tab.build

	Tab.build = function(self, ...)
		old_build(self, ...)

		if not state.visible then
			return
		end

		-- Fixed height: 1 border + up to 9 content rows (name, perm, owner, size,
		-- modified, created, links, type, and the optional type-specific row) —
		-- a percentage split truncates that last row on most terminal sizes.
		local parts = ui.Layout()
			:direction(ui.Layout.VERTICAL)
			:constraints({ ui.Constraint.Min(0), ui.Constraint.Length(10) })
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

local toggle_visible = ya.sync(function(state)
	state.visible = not state.visible
	ui.render()
end)

local function entry(_, job)
	if job.args and job.args[1] == "toggle" then
		toggle_visible()
	end
end

local function fetch(_, job)
	local action = job.args and job.args[1]
	-- job.files can batch several matching files into one call — handle all of
	-- them, since delegating to noop marks the whole batch complete either way.
	if action and job.files then
		for _, file in ipairs(job.files) do
			if action == "archive" then
				fetch_archive(file)
			elseif action == "csv" then
				fetch_csv(file)
			elseif action == "image" then
				fetch_image(file)
			elseif action == "media" then
				fetch_media(file)
			end
		end
	end

	return require("noop"):fetch(job)
end

return { setup = setup, entry = entry, fetch = fetch }
