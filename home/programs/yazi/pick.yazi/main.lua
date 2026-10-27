-- Jump to a file or folder with `pick` (the shared picker), replacing yazi's
-- built-in `fzf` plugin. Adapted from yazi's own preset fzf.lua (26.9): hide
-- yazi, run the picker on the terminal, then cd/reveal/select the result.
-- `pick` draws on /dev/tty itself, so it only needs the terminal released.

local M = {}

local state = ya.sync(function()
	return cx.active.current.cwd
end)

function M:entry()
	ya.emit("escape", { visual = true })

	local cwd = state()
	if cwd.spec.is_virtual then
		return ya.notify { title = "Pick", content = "Not supported under virtual filesystems", timeout = 5, level = "warn" }
	end

	local permit = ui.hide()
	local output, err = M.run(cwd)
	permit:drop()
	if not output then
		return ya.notify { title = "Pick", content = tostring(err), timeout = 5, level = "error" }
	end

	local urls = M.split_urls(cwd, output)
	if #urls == 0 then
		return
	elseif #urls == 1 then
		-- pick marks folders with a trailing slash.
		local is_dir = output:match("[/\\]%s*$") ~= nil
		return ya.emit(is_dir and "cd" or "reveal", { urls[1], raw = true })
	end

	local files = {}
	for _, url in ipairs(urls) do
		files[#files + 1] = fs.file(url)
	end
	if #files > 0 then
		files.state = "on"
		ya.emit("toggle_all", files)
	end
end

---@param cwd Url
---@return string?, Error?
function M.run(cwd)
	local child, err = Command("pick")
		:arg({ "--files", "--dirs" })
		:cwd(tostring(cwd))
		:stdin(Command.INHERIT)
		:stdout(Command.PIPED)
		:spawn()
	if not child then
		return nil, Err("Failed to start `pick`, error: %s", err)
	end

	local output, err = child:wait_with_output()
	if not output then
		return nil, Err("Cannot read `pick` output, error: %s", err)
	end
	-- 1: accepted with nothing matched, 130: cancelled. Neither is an error.
	local code = output.status.code
	if not output.status.success and code ~= 1 and code ~= 130 then
		return nil, Err("`pick` exited with error code %s", code)
	end
	return output.stdout, nil
end

function M.split_urls(cwd, output)
	local t = {}
	for line in output:gmatch("[^\r\n]+") do
		local u = Url(line)
		t[#t + 1] = u.is_absolute and u or cwd:resolve(u)
	end
	return t
end

return M
