-- ~/.config/hypr/lua/window_rules.lua
-- Migrated from configs/WindowRules.conf
-- windowrule = <EFFECT>, match:<k> <v>  ->  hl.window_rule({ match = { k = "v" }, <effect> = <val> })
--   effect "on" -> true ; parameterised effects (opacity/size/move/tag) -> string value.
-- (window rules below are auto-generated from the .conf, then reviewed)

hl.window_rule({
  match = { class = "^([Ff]irefox|org.mozilla.firefox|[Ff]irefox-esr|[Ff]irefox-bin)$" },
  tag = "+browser",
})
hl.window_rule({
  match = { class = "^([Gg]oogle-chrome(-beta|-dev|-unstable)?)$" },
  tag = "+browser",
})
hl.window_rule({
  match = { class = "^(chrome-.+-Default)$" },
  tag = "+browser",
})
hl.window_rule({
  match = { class = "^([Cc]hromium)$" },
  tag = "+browser",
})
hl.window_rule({
  match = { class = "^([Mm]icrosoft-edge(-stable|-beta|-dev|-unstable))$" },
  tag = "+browser",
})
hl.window_rule({
  match = { class = "^(Brave-browser(-beta|-dev|-unstable)?)$" },
  tag = "+browser",
})
hl.window_rule({
  match = { class = "^([Tt]horium-browser|[Cc]achy-browser)$" },
  tag = "+browser",
})
hl.window_rule({
  match = { class = "^(zen-alpha|zen)$" },
  tag = "+browser",
})
hl.window_rule({
  match = { class = "^([Oo]pera)$" },
  tag = "+browser",
})
hl.window_rule({
  match = { class = "^(swaync-control-center|swaync-notification-window|swaync-client|class)$" },
  tag = "+notif",
})
hl.window_rule({
  match = { title = "^(KooL Quick Cheat Sheet)$" },
  tag = "+KooL_Cheat",
})
hl.window_rule({
  match = { title = "^(KooL Hyprland Settings)$" },
  tag = "+KooL_Settings",
})
hl.window_rule({
  match = { class = "^(nwg-displays|nwg-look)$" },
  tag = "+KooL-Settings",
})
hl.window_rule({
  match = { class = "^(Alacritty|kitty|kitty-dropterm)$" },
  tag = "+terminal",
})
hl.window_rule({
  match = { class = "^([Tt]hunderbird|org.gnome.Evolution)$" },
  tag = "+email",
})
hl.window_rule({
  match = { class = "^(eu.betterbird.Betterbird)$" },
  tag = "+email",
})
hl.window_rule({
  match = { class = "^(codium|codium-url-handler|VSCodium)$" },
  tag = "+projects",
})
hl.window_rule({
  match = { class = "^(VSCode|code-url-handler)$" },
  tag = "+projects",
})
hl.window_rule({
  match = { class = "^(jetbrains-.+)$" },
  tag = "+projects",
})
hl.window_rule({
  match = { class = "^(com.obsproject.Studio)$" },
  tag = "+screenshare",
})
hl.window_rule({
  match = { class = "^([Dd]iscord|[Ww]ebCord|[Vv]esktop)$" },
  tag = "+im",
})
hl.window_rule({
  match = { class = "^([Ff]erdium)$" },
  tag = "+im",
})
hl.window_rule({
  match = { class = "^([Ww]hatsapp-for-linux)$" },
  tag = "+im",
})
hl.window_rule({
  match = { class = "^(ZapZap|com.rtosta.zapzap)$" },
  tag = "+im",
})
hl.window_rule({
  match = { class = "^(org.telegram.desktop|io.github.tdesktop_x64.TDesktop)$" },
  tag = "+im",
})
hl.window_rule({
  match = { class = "^(teams-for-linux)$" },
  tag = "+im",
})
hl.window_rule({
  match = { class = "^(im.riot.Riot|Element)$" },
  tag = "+im",
})
hl.window_rule({
  match = { class = "^(gamescope)$" },
  tag = "+games",
})
hl.window_rule({
  match = { class = "^(steam_app_\\d+)$" },
  tag = "+games",
})
hl.window_rule({
  match = { class = "^([Ss]team)$" },
  tag = "+gamestore",
})
hl.window_rule({
  match = { title = "^([Ll]utris)$" },
  tag = "+gamestore",
})
hl.window_rule({
  match = { class = "^(com.heroicgameslauncher.hgl)$" },
  tag = "+gamestore",
})
hl.window_rule({
  match = { class = "^([Tt]hunar|org.gnome.Nautilus|[Pp]cmanfm-qt)$" },
  tag = "+file-manager",
})
hl.window_rule({
  match = { class = "^(app.drey.Warp)$" },
  tag = "+file-manager",
})
hl.window_rule({
  match = { class = "^([Ww]aytrogen)$" },
  tag = "+wallpaper",
})
hl.window_rule({
  match = { class = "^([Aa]udacious)$" },
  tag = "+multimedia",
})
hl.window_rule({
  match = { class = "^([Mm]pv|vlc)$" },
  tag = "+multimedia_video",
})
hl.window_rule({
  match = { title = "^(ROG Control)$" },
  tag = "+settings",
})
hl.window_rule({
  match = { class = "^(wihotspot(-gui)?)$" },
  tag = "+settings",
})
hl.window_rule({
  match = { class = "^([Bb]aobab|org.gnome.[Bb]aobab)$" },
  tag = "+settings",
})
hl.window_rule({
  match = { class = "^(gnome-disks|wihotspot(-gui)?)$" },
  tag = "+settings",
})
hl.window_rule({
  match = { title = "(Kvantum Manager)" },
  tag = "+settings",
})
hl.window_rule({
  match = { class = "^(file-roller|org.gnome.FileRoller)$" },
  tag = "+settings",
})
hl.window_rule({
  match = { class = "^(nm-applet|nm-connection-editor|blueman-manager)$" },
  tag = "+settings",
})
hl.window_rule({
  match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$" },
  tag = "+settings",
})
hl.window_rule({
  match = { class = "^(qt5ct|qt6ct|[Yy]ad)$" },
  tag = "+settings",
})
hl.window_rule({
  match = { class = "(xdg-desktop-portal-gtk)" },
  tag = "+settings",
})
hl.window_rule({
  match = { class = "^(org.kde.polkit-kde-authentication-agent-1)$" },
  tag = "+settings",
})
hl.window_rule({
  match = { class = "^([Rr]ofi)$" },
  tag = "+settings",
})
hl.window_rule({
  match = { class = "^(gnome-system-monitor|org.gnome.SystemMonitor|io.missioncenter.MissionCenter)$" },
  tag = "+viewer",
})
hl.window_rule({
  match = { class = "^(evince)$" },
  tag = "+viewer",
})
hl.window_rule({
  match = { class = "^(eog|org.gnome.Loupe)$" },
  tag = "+viewer",
})
hl.window_rule({
  match = { tag = "multimedia_video*" },
  no_blur = true,
})
hl.window_rule({
  match = { tag = "multimedia_video*" },
  opacity = "1 override 1 override",
})
hl.window_rule({
  match = { tag = "KooL_Cheat*" },
  center = true,
})
hl.window_rule({
  match = { class = "([Tt]hunar)", title = "negative:(.*[Tt]hunar.*)" },
  center = true,
})
hl.window_rule({
  match = { title = "^(ROG Control)$" },
  center = true,
})
hl.window_rule({
  match = { tag = "KooL-Settings*" },
  center = true,
})
hl.window_rule({
  match = { title = "^(Keybindings)$" },
  center = true,
})
hl.window_rule({
  match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$" },
  center = true,
})
hl.window_rule({
  match = { class = "^([Ww]hatsapp-for-linux|ZapZap|com.rtosta.zapzap)$" },
  center = true,
})
hl.window_rule({
  match = { class = "^([Ff]erdium)$" },
  center = true,
})
hl.window_rule({
  match = { title = "^(Picture-in-Picture)$" },
  move = "72% 7%",
})
hl.window_rule({
  match = { tag = "KooL_Cheat*" },
  float = true,
})
hl.window_rule({
  match = { tag = "wallpaper*" },
  float = true,
})
hl.window_rule({
  match = { tag = "settings*" },
  float = true,
})
hl.window_rule({
  match = { tag = "viewer*" },
  float = true,
})
hl.window_rule({
  match = { tag = "KooL-Settings*" },
  float = true,
})
hl.window_rule({
  match = { class = "([Zz]oom|onedriver|onedriver-launcher)$" },
  float = true,
})
hl.window_rule({
  match = { class = "(org.gnome.Calculator)", title = "(Calculator)" },
  float = true,
})
hl.window_rule({
  match = { class = "^(mpv|com.github.rafostar.Clapper)$" },
  float = true,
})
hl.window_rule({
  match = { class = "^([Qq]alculate-gtk)$" },
  float = true,
})
hl.window_rule({
  match = { class = "^([Ff]erdium)$" },
  float = true,
})
hl.window_rule({
  match = { title = "^(Picture-in-Picture)$" },
  float = true,
})
hl.window_rule({
  match = { title = "^(Authentication Required)$" },
  float = true,
})
hl.window_rule({
  match = { title = "^(Authentication Required)$" },
  center = true,
})
hl.window_rule({
  match = { class = "(codium|codium-url-handler|VSCodium)", title = "negative:(.*codium.*|.*VSCodium.*)" },
  float = true,
})
hl.window_rule({
  match = { class = "^(com.heroicgameslauncher.hgl)$", title = "negative:(Heroic Games Launcher)" },
  float = true,
})
hl.window_rule({
  match = { class = "^([Ss]team)$", title = "negative:^([Ss]steam)$" },
  float = true,
})
hl.window_rule({
  match = { class = "([Tt]hunar)", title = "negative:(.*[Tt]hunar.*)" },
  float = true,
})
hl.window_rule({
  match = { title = "^(Add Folder to Workspace)$" },
  float = true,
})
hl.window_rule({
  match = { title = "^(Add Folder to Workspace)$" },
  size = "70% 60%",
})
hl.window_rule({
  match = { title = "^(Add Folder to Workspace)$" },
  center = true,
})
hl.window_rule({
  match = { title = "^(Save As)$" },
  float = true,
})
hl.window_rule({
  match = { title = "^(Save As)$" },
  size = "70% 60%",
})
hl.window_rule({
  match = { title = "^(Save As)$" },
  center = true,
})
hl.window_rule({
  match = { title = "(Open Files)" },
  float = true,
})
hl.window_rule({
  match = { title = "(Open Files)" },
  size = "70% 60%",
})
hl.window_rule({
  match = { title = "^(SDDM Background)$" },
  float = true,
})
hl.window_rule({
  match = { title = "^(SDDM Background)$" },
  center = true,
})
hl.window_rule({
  match = { title = "^(SDDM Background)$" },
  size = "16% 12%",
})
hl.window_rule({
  match = { tag = "browser*" },
  opacity = "0.99 0.8",
})
hl.window_rule({
  match = { tag = "projects*" },
  opacity = "0.9 0.8",
})
hl.window_rule({
  match = { tag = "im*" },
  opacity = "0.94 0.86",
})
hl.window_rule({
  match = { tag = "multimedia*" },
  opacity = "0.94 0.86",
})
hl.window_rule({
  match = { tag = "file-manager*" },
  opacity = "0.9 0.8",
})
hl.window_rule({
  match = { tag = "terminal*" },
  opacity = "0.9 0.7",
})
hl.window_rule({
  match = { tag = "settings*" },
  opacity = "0.8 0.7",
})
hl.window_rule({
  match = { tag = "viewer*" },
  opacity = "0.82 0.75",
})
hl.window_rule({
  match = { tag = "wallpaper*" },
  opacity = "0.9 0.7",
})
hl.window_rule({
  match = { class = "^(gedit|org.gnome.TextEditor|mousepad)$" },
  opacity = "0.8 0.7",
})
hl.window_rule({
  match = { class = "^(deluge)$" },
  opacity = "0.9 0.8",
})
hl.window_rule({
  match = { class = "^(seahorse)$" },
  opacity = "0.9 0.8",
})
hl.window_rule({
  match = { title = "^(Picture-in-Picture)$" },
  opacity = "0.95 0.75",
})
hl.window_rule({
  match = { class = "^(code)$" },
  opacity = "0.9",
})
hl.window_rule({
  match = { tag = "KooL_Cheat*" },
  size = "65% 90%",
})
hl.window_rule({
  match = { tag = "wallpaper*" },
  size = "70% 70%",
})
hl.window_rule({
  match = { tag = "settings*" },
  size = "70% 70%",
})
hl.window_rule({
  match = { class = "^([Ww]hatsapp-for-linux|ZapZap|com.rtosta.zapzap)$" },
  size = "60% 70%",
})
hl.window_rule({
  match = { class = "^([Ff]erdium)$" },
  size = "60% 70%",
})
hl.window_rule({
  match = { title = "^(Picture-in-Picture)$" },
  pin = true,
})
hl.window_rule({
  match = { title = "^(Picture-in-Picture)$" },
  keep_aspect_ratio = true,
})
hl.window_rule({
  match = { tag = "games*" },
  no_blur = true,
})
hl.window_rule({
  match = { tag = "games*" },
  fullscreen = true,
})
hl.window_rule({
  match = { class = "^(jetbrains-.*)" },
  no_initial_focus = true,
})
hl.window_rule({
  match = { title = "^(wind.*)$" },
  no_initial_focus = true,
})
hl.window_rule({
  match = { class = "^(code)$" },
  opacity = "0.8",
})

-- ============================ LAYER RULES ============================
hl.layer_rule({ match = { namespace = "rofi" }, blur = true })
hl.layer_rule({ match = { namespace = "rofi" }, xray = true })
hl.layer_rule({ match = { namespace = "notifications" }, blur = true })
hl.layer_rule({ match = { namespace = "notifications" }, xray = true })
hl.layer_rule({ match = { namespace = "quickshell:overview" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell:overview" }, xray = true })
-- original had `layerrule = xray 0.5` (xray is boolean in the Lua API; the 0.5
-- is interpreted as ignore_alpha, the closest faithful equivalent)
hl.layer_rule({ match = { namespace = "quickshell:overview" }, ignore_alpha = 0.5 })
