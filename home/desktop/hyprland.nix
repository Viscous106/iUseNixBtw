{ config, pkgs, inputs, user, ... }:

{
  # ── Hyprland window manager ─────────────────────────────────────────────────
  # hyprland.lua (needs the hyprland flake; nixpkgs predates Lua support), loaded instead of hyprland.conf.
  wayland.windowManager.hyprland = {
    enable         = true;
    # Must stay "hyprlang": under "lua" (the default for stateVersion >= 26.05)
    # the module generates hypr/hyprland.lua, colliding with home/dotfiles.nix's link.
    configType     = "hyprlang";
    # The injected exec-once lives in hyprland.conf, which never runs since
    # hyprland.lua wins; startup_apps.lua starts the session target and exports env.
    systemd.enable = false;
    # Only silences the module's "no settings" warning; hyprland.conf is unused.
    extraConfig    = "# config lives in hyprland.lua, not here";
    package = pkgs.hyprland-pinned;  # overlays/default.nix
  };

  # A store copy, not linked live like the rest of ~/.config/hypr, so @HOME@ can be substituted
  # (hyprlock doesn't expand $HOME); editing it needs a rebuild.
  xdg.configFile."hypr/hyprlock.conf" = {
    text = builtins.replaceStrings
      [ "@HOME@" ] [ "/home/${user.username}" ]
      (builtins.readFile ../../dotfiles/hypr/hyprlock.conf);
    force = true;
  };

  # Not the NixOS programs.hyprlock: that one force-enables services.hypridle,
  # and caelestia is the idle manager here.
  programs.hyprlock.enable = true;
}
