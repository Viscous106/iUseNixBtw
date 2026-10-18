hl.window_rule({
  match = { class = "^([Gg]oogle-chrome(-beta|-dev|-unstable)?)$" },
  tag = "+browser",
})
hl.window_rule({
  match = { class = "^(chrome-.+-Default)$" },
  tag = "+browser",
})
hl.window_rule({
  match = { class = "^(Brave-browser(-beta|-dev|-unstable)?)$" },
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
  match = { class = "^(nwg-displays|nwg-look)$" },
  tag = "+nwg",
})
hl.window_rule({
  match = { class = "^(Alacritty|kitty|kitty-dropterm)$" },
  tag = "+terminal",
})
hl.window_rule({
  match = { class = "^([Dd]iscord|[Ww]ebCord|[Vv]esktop)$" },
  tag = "+im",
})
hl.window_rule({
  match = { class = "^(org.telegram.desktop|io.github.tdesktop_x64.TDesktop)$" },
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
  match = { class = "^([Tt]hunar|org.gnome.Nautilus|[Pp]cmanfm-qt)$" },
  tag = "+file-manager",
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
  match = { title = "(Kvantum Manager)" },
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
  match = { class = "^([Rr]ofi)$" },
  tag = "+settings",
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
  match = { class = "([Tt]hunar)", title = "negative:(.*[Tt]hunar.*)" },
  center = true,
})
hl.window_rule({
  match = { title = "^(ROG Control)$" },
  center = true,
})
hl.window_rule({
  match = { tag = "nwg*" },
  center = true,
})
hl.window_rule({
  match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$" },
  center = true,
})
hl.window_rule({
  match = { title = "^(Picture-in-Picture)$" },
  move = "72% 7%",
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
  match = { tag = "nwg*" },
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
  match = { tag = "browser*" },
  opacity = "0.99 0.8",
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
  match = { class = "^(gedit|org.gnome.TextEditor|mousepad)$" },
  opacity = "0.8 0.7",
})
hl.window_rule({
  match = { title = "^(Picture-in-Picture)$" },
  opacity = "0.95 0.75",
})
hl.window_rule({
  match = { tag = "settings*" },
  size = "70% 70%",
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

-- ============================ LAYER RULES ============================
hl.layer_rule({ match = { namespace = "rofi" }, blur = true })
hl.layer_rule({ match = { namespace = "rofi" }, xray = true })
hl.layer_rule({ match = { namespace = "notifications" }, blur = true })
hl.layer_rule({ match = { namespace = "notifications" }, xray = true })
hl.layer_rule({ match = { namespace = "quickshell:overview" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell:overview" }, xray = true })
-- xray is boolean in Lua; the old 0.5 threshold maps to ignore_alpha.
hl.layer_rule({ match = { namespace = "quickshell:overview" }, ignore_alpha = 0.5 })
