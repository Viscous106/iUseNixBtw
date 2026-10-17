-- ~/.config/hypr/lua/system_settings.lua
-- Migrated from configs/SystemSettings.conf
-- All keyword sections -> hl.config{}. The `gesture =` lines become hl.gesture() calls
-- (the modern equivalent); workspace_swipe_* stay under the gestures section.

hl.config({
  dwindle = {
    preserve_split      = true,
    special_scale_factor = 0.8,
  },

  master = {
    new_status = "master",
    new_on_top = true,
    mfact      = 0.5,
  },

  general = {
    resize_on_border = true,
    layout           = "dwindle",
  },

  input = {
    kb_layout   = "us,us",
    kb_variant  = "dvp,",
    repeat_rate  = 50,
    repeat_delay = 300,
    sensitivity  = 0,
    numlock_by_default          = true,
    left_handed                 = false,
    follow_mouse                = 1,
    float_switch_override_focus = false,
    touchpad = {
      disable_while_typing   = true,
      natural_scroll         = true,
      clickfinger_behavior   = false,
      middle_button_emulation = false,
      tap_to_click           = true,
      drag_lock              = false,
    },
    touchdevice = { enabled = true },
    tablet = { transform = 0, left_handed = false },
  },

  gestures = {
    workspace_swipe_distance           = 500,
    workspace_swipe_invert             = true,
    workspace_swipe_min_speed_to_force = 30,
    workspace_swipe_cancel_ratio       = 0.5,
    workspace_swipe_create_new         = true,
    workspace_swipe_forever            = true,
  },

  misc = {
    disable_hyprland_logo    = true,
    disable_splash_rendering = true,
    vrr                      = 2,
    mouse_move_enables_dpms  = true,
    enable_swallow           = false,
    swallow_regex            = "^(kitty)$",
    focus_on_activate        = false,
    initial_workspace_tracking = 0,
    middle_click_paste       = false,
    enable_anr_dialog        = true,
    anr_missed_pings         = 15,
    allow_session_lock_restore = true,
  },

  binds = {
    workspace_back_and_forth = true,
    allow_workspace_cycles   = true,
    pass_mouse_when_bound    = false,
  },

  xwayland = {
    enabled            = true,
    force_zero_scaling = true,
  },

  render = {
    direct_scanout = 0,
  },

  cursor = {
    sync_gsettings_theme     = true,
    no_hardware_cursors      = 1,
    enable_hyprcursor        = true,
    warp_on_change_workspace = 2,
    no_warps                 = true,
  },
})

-- 3-finger horizontal swipe -> switch workspace
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- 4-finger up/down -> cursor zoom in/out.
-- The $(...) + awk is preserved verbatim inside a shell string (exec_cmd runs via sh -c,
-- so $2 is an awk field and $(...) evaluates at trigger time). Long-bracket = no escaping.
hl.gesture({
  fingers = 4, direction = "up",
  action = function()
    hl.exec_cmd([[hyprctl keyword cursor:zoom_factor "$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor * 1.5}')"]])
  end,
})
hl.gesture({
  fingers = 4, direction = "down",
  action = function()
    hl.exec_cmd([[hyprctl keyword cursor:zoom_factor "$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor / 1.5}')"]])
  end,
})
