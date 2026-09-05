-- ~/.config/hypr/lua/keybinds.lua
-- Migrated from configs/Keybinds.conf
-- bind/binde/bindl/bindm -> hl.bind(keys, dispatcher, opts)
--   binde -> {repeating=true}   bindl -> {locked=true}   bindm -> {mouse=true}
-- $var (mainMod/term/files/scriptsDir) come from user_defaults (cached require).

local U   = require("lua.user_defaults")
local mod = U.mainMod
local sd  = U.scriptsDir
local term  = U.term
local files = U.files

------------------------------------------------------------------ meta (SUPER)
hl.bind(mod .. " + SPACE",  hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(term))
hl.bind(mod .. " + Print",  hl.dsp.exec_cmd(sd .. "/ScreenShot.sh --area"))
hl.bind(mod .. " + tab",    hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + period", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + comma",  hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true }) -- left click move
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true }) -- right click resize
hl.bind(mod .. " + B", hl.dsp.exec_cmd([[xdg-open "https://"]]))
hl.bind(mod .. " + C", hl.dsp.exec_cmd("qalculate-gtk"))
-- App launcher. Was rofi -show drun; caelestia's launcher drawer replaces it and
-- also covers run/window/filebrowser-style modes from the same prompt. The IPC
-- call is a toggle, so pressing it again dismisses — no pkill guard needed the
-- way rofi required one to avoid stacking instances.
hl.bind(mod .. " + D", hl.dsp.exec_cmd("caelestia shell drawers toggle launcher"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(files))
hl.bind(mod .. " + H", hl.dsp.exec_cmd(sd .. "/toggle-wl-kbptr.sh left"))
hl.bind(mod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized" }))
-- Two locks, deliberately: SUPER+L is hyprlock (hyprlock.conf), SUPER+N is
-- caelestia's own lock screen. The old SUPER+CTRL+N (hyprlock) and
-- SUPER+SHIFT+L (swaylock) binds were removed to stop at two.
hl.bind(mod .. " + L", hl.dsp.exec_cmd(sd .. "/hyprlock.sh"))
hl.bind(mod .. " + N", hl.dsp.exec_cmd("caelestia shell lock lock"))
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + S", hl.dsp.exec_cmd(sd .. "/RofiSearch.sh"))
hl.bind(mod .. " + U", hl.dsp.workspace.toggle_special())
-- The wl-paste/cliphist watchers in startup_apps.lua still populate history;
-- only the picker UI moves from rofi to caelestia.
hl.bind(mod .. " + V", hl.dsp.exec_cmd("caelestia shell picker openClip"))
-- Wallpaper picker: qs-wallpaper-picker, a standalone Quickshell selector that
-- opens straight onto a thumbnail grid — arrows to move, Enter to apply, Escape
-- to close, typing filters. It is launched on demand rather than being a daemon,
-- so it costs nothing while closed. Handles video as well as images, which
-- caelestia cannot (see pkgs/qs-wallpaper-picker.nix).
hl.bind(mod .. " + W", hl.dsp.exec_cmd("qs-wallpaper-picker"))
-- move focus
hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "d" }))
-- switch to workspace 1..10 (keycodes 14..16 = the number row)
local ws_codes = { ["code:14"]=1, ["code:17"]=2, ["code:13"]=3, ["code:18"]=4, ["code:12"]=5,
                   ["code:19"]=6, ["code:11"]=7, ["code:20"]=8, ["code:15"]=9, ["code:16"]=10 }
for code, ws in pairs(ws_codes) do
  hl.bind(mod .. " + " .. code, hl.dsp.focus({ workspace = tostring(ws) }))
  hl.bind(mod .. " + SHIFT + " .. code, hl.dsp.window.move({ workspace = tostring(ws), follow = true }))
end

------------------------------------------------------------ meta SHIFT (SUPER SHIFT)
hl.bind(mod .. " + SHIFT + Return", hl.dsp.exec_cmd(sd .. "/Dropterminal.sh " .. term))
hl.bind(mod .. " + SHIFT + tab", hl.dsp.focus({ workspace = "m-1" }))
-- (removed) SUPER SHIFT A animation switcher — animations are defined in lua/animations.lua
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd("blueman-manager"))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("caelestia shell drawers toggle dashboard"))
hl.bind(mod .. " + SHIFT + G", hl.dsp.exec_cmd("caelestia shell gameMode toggle"))
hl.bind(mod .. " + SHIFT + I", hl.dsp.layout("togglesplit"))
-- (removed) SUPER SHIFT M monitor picker — monitor switching is now automatic (see lua/monitors.lua)
-- SUPER SHIFT M now opens the screen colour mode picker (normal / reading / high reading / blue)
hl.bind(mod .. " + SHIFT + M", hl.dsp.exec_cmd(sd .. "/ScreenMode.sh menu"))
hl.bind(mod .. " + SHIFT + CTRL + M", hl.dsp.exec_cmd(sd .. "/ScreenMode.sh next")) -- cycle without the menu
-- Notification centre. swaync is no longer started (caelestia owns the
-- org.freedesktop.Notifications name), so swaync-client was a no-op.
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("caelestia shell drawers toggle sidebar"))
hl.bind(mod .. " + SHIFT + O", hl.dsp.exec_cmd(sd .. "/ZshChangeTheme.sh"))
-- Toggle bar visibility. The old waybar bind sent SIGUSR1 to the process;
-- caelestia is one process for the whole shell, so visibility is a drawer
-- toggle over IPC instead of a signal. Verified against `caelestia shell -s`:
-- target `drawers`, function `toggle(drawer: string)`.
hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd("caelestia shell drawers toggle bar"))
hl.bind(mod .. " + SHIFT + U", hl.dsp.window.move({ workspace = "special", follow = true }))
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd(sd .. "/WallpaperEffects.sh"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(sd .. "/ScreenShot.sh --now"))
hl.bind(mod .. " + SHIFT + H", hl.dsp.exec_cmd(sd .. "/toggle-wl-kbptr.sh right"))
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd(sd .. "/ScreenRecord.sh"))
-- resize active (repeating)
hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.resize({ x = -50, y = 0 }),  { repeating = true })
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.resize({ x = 50,  y = 0 }),  { repeating = true })
hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.resize({ x = 0,   y = -50 }), { repeating = true })
hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.resize({ x = 0,   y = 50 }),  { repeating = true })

------------------------------------------------------------- meta ALT (SUPER ALT)
hl.bind(mod .. " + ALT + SPACE", hl.dsp.exec_cmd("hyprctl dispatch workspaceopt allfloat"))
-- Was the waybar layout switcher. Now opens nexus — caelestia's settings window
-- (Apps, Audio, Bluetooth, Network, Panels, Services, Wallpaper & Style), which
-- is where themes are changed. Note nexus exposes only open(), not a toggle, so
-- this opens and the window is dismissed normally rather than by re-pressing.
-- The dashboard is on SUPER+SHIFT+E; the quick scheme picker is SUPER+CTRL+R.
hl.bind(mod .. " + ALT + B", hl.dsp.exec_cmd("caelestia shell nexus open"))
-- `caelestia emoji` with no flag only prints help; -p opens the picker.
hl.bind(mod .. " + ALT + E", hl.dsp.exec_cmd("caelestia emoji -p"))
hl.bind(mod .. " + ALT + A", hl.dsp.exec_cmd("caelestia shell audio cycleOutput"))
hl.bind(mod .. " + ALT + I", hl.dsp.exec_cmd("caelestia shell idleInhibitor toggle"))
hl.bind(mod .. " + ALT + H", hl.dsp.exec_cmd(sd .. "/drag_hold.sh"))
hl.bind(mod .. " + ALT + L", hl.dsp.exec_cmd(sd .. "/ChangeLayout.sh"))
hl.bind(mod .. " + ALT + M", hl.dsp.exec_cmd("nwg-displays"))
hl.bind(mod .. " + ALT + N", hl.dsp.exec_cmd(sd .. "/screensaver.sh"))
hl.bind(mod .. " + ALT + O", hl.dsp.exec_cmd(sd .. "/ChangeBlur.sh"))
hl.bind(mod .. " + ALT + R", hl.dsp.exec_cmd(sd .. "/Refresh.sh"))
hl.bind(mod .. " + ALT + S", hl.dsp.exec_cmd("pavucontrol"))
-- ToggleAGS.sh never existed in this repo, so this bind has always been dead.
hl.bind(mod .. " + ALT + T", hl.dsp.exec_cmd("caelestia shell notifs toggleDnd"))
-- WallpaperRandom.sh drove awww, which is no longer started at login now that
-- caelestia owns static wallpapers — so this bind had gone dead. The CLI does
-- random natively and regenerates the colour scheme with it.
hl.bind(mod .. " + ALT + W", hl.dsp.exec_cmd("caelestia wallpaper -r"))
-- swap windows
hl.bind(mod .. " + ALT + left",  hl.dsp.window.swap({ direction = "l" }))
hl.bind(mod .. " + ALT + right", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mod .. " + ALT + up",    hl.dsp.window.swap({ direction = "u" }))
hl.bind(mod .. " + ALT + down",  hl.dsp.window.swap({ direction = "d" }))

----------------------------------------------------------- meta CTRL (SUPER CTRL)
hl.bind(mod .. " + CTRL + backspace", hl.dsp.exec_cmd("caelestia shell drawers toggle session"))
-- Was the waybar style switcher.
hl.bind(mod .. " + CTRL + B", hl.dsp.exec_cmd("caelestia shell drawers toggle utilities"))
hl.bind(mod .. " + CTRL + C", hl.dsp.exec_cmd("qalculate-gtk"))
hl.bind(mod .. " + CTRL + O", hl.dsp.exec_cmd("hyprctl setprop active opacity toggle"))
hl.bind(mod .. " + CTRL + R", hl.dsp.exec_cmd("caelestia scheme"))
-- move windows
hl.bind(mod .. " + CTRL + left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + CTRL + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mod .. " + CTRL + up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + CTRL + down",  hl.dsp.window.move({ direction = "d" }))
hl.bind(mod .. " + CTRL + S", hl.dsp.exec_cmd(sd .. "/ScreenShot.sh --area"))

--------------------------------------------------------------------- CTRL ALT
hl.bind("CTRL + ALT + Delete", hl.dsp.exit())
hl.bind("CTRL + ALT + M", hl.dsp.exec_cmd("warpd --normal"))

------------------------------------------------------ media / brightness (no mod)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(sd .. "/Volume.sh --inc"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(sd .. "/Volume.sh --dec"), { repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(sd .. "/Volume.sh --toggle-mic"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(sd .. "/Volume.sh --toggle"), { locked = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd(sd .. "/BrightnessKbd.sh --dec"), { repeating = true })
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd(sd .. "/BrightnessKbd.sh --inc"), { repeating = true })
-- Relative syntax verified against the CLI: valid forms are 0.1, +0.1, 0.1-,
-- 10%, +10%, 10%- . A leading "-0.1" is rejected; decrement is a TRAILING minus.
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("caelestia shell brightness set 10%-"), { repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("caelestia shell brightness set +10%"), { repeating = true })
hl.bind("code:202", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"), { locked = true })
hl.bind("XF86Sleep",  hl.dsp.exec_cmd("systemctl suspend"), { locked = true })
hl.bind("XF86RFKill", hl.dsp.exec_cmd(sd .. "/AirplaneMode.sh"), { locked = true })
-- NOTE: XF86AudioPlayPause is not a valid keysym (never bound under hyprlang either);
-- play/pause is covered by the XF86AudioPause + XF86AudioPlay binds below.
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("caelestia shell mpris playPause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("caelestia shell mpris playPause"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("caelestia shell mpris next"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("caelestia shell mpris previous"), { locked = true })
hl.bind("XF86AudioStop",  hl.dsp.exec_cmd("caelestia shell mpris stop"), { locked = true })
hl.bind("XF86Launch4", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/cycle_aura_mode.sh"), { locked = true })
