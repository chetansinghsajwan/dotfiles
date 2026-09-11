local mod = "SUPER"
local up = "K"
local down = "J"
local left = "H"
local right = "L"
local window_resize_step = 15
local brightness_step = 5
local volume_step = 5
local defaultTerminal = "__DEFAULT_TERMINAL__"

hl.config({
  general = {
    gaps_in = 6,
    gaps_out = 10,
  },

  decoration = {
    rounding = 14,
  },

  dwindle = {
    preserve_split = true,
  },

  input = {
    natural_scroll = true,
    touchpad = {
      natural_scroll = true,
    },
  },
})

hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = 1,
})

hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + Q", hl.dsp.window.kill())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mod .. " + V", hl.dsp.window.float())
hl.bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"))

-- Move focus between windows
hl.bind(mod .. " + " .. left, hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + " .. down, hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + " .. up, hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + " .. right, hl.dsp.focus({ direction = "right" }))

-- Move windows around within the same workspace
hl.bind(mod .. " + ALT + " .. left, hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + ALT + " .. down, hl.dsp.window.move({ direction = "down" }))
hl.bind(mod .. " + ALT + " .. up, hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + ALT + " .. right, hl.dsp.window.move({ direction = "right" }))

-- Move windows around within the same workspace
hl.bind(mod .. " + SHIFT + " .. left, hl.dsp.window.resize({ x = -window_resize_step, y = 0, relative = true }))
hl.bind(mod .. " + SHIFT + " .. down, hl.dsp.window.resize({ x = 0, y= -window_resize_step, relative = true }))
hl.bind(mod .. " + SHIFT + " .. up, hl.dsp.window.resize({ x = 0, y = window_resize_step, relative = true }))
hl.bind(mod .. " + SHIFT + " .. right, hl.dsp.window.resize({ x = window_resize_step, y = 0, relative = true }))

-- Switch workspaces (SUPER+SHIFT)
hl.bind(mod .. " + CTRL + " .. down, hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + CTRL + " .. up, hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + CTRL + N", hl.dsp.focus({ workspace = "+1" }))

-- Move window to workspace
hl.bind(mod .. " + ALT + CTRL + " .. down, hl.dsp.window.move({ workspace = "e-1" }))
hl.bind(mod .. " + ALT + CTRL + " .. up, hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(mod .. " + ALT + CTRL + N", hl.dsp.window.move({ workspace = "+1" }))

-- Volume (media keys, no repeat)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ " .. volume_step .. "%+"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ " .. volume_step .. "%-"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))

-- Brightness
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +" .. brightness_step .. "%"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set " .. brightness_step .. "%-"))

hl.bind(mod .. " + period", hl.dsp.exec_cmd(defaultTerminal))
