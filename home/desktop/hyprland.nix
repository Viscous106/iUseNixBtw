{ config, pkgs, inputs, user, ... }:

{
  # ── Hyprland window manager ─────────────────────────────────────────────────
  # Config is hyprland.lua (native Lua config, requires the hyprland flake
  # input — nixpkgs' pinned version predates Lua support). Hyprland loads
  # hyprland.lua INSTEAD of hyprland.conf when it exists, so no extraConfig.
  wayland.windowManager.hyprland = {
    enable         = true;
    # Pinned explicitly: home-manager's default flipped hyprlang -> lua for
    # stateVersion >= 26.05. We must stay on "hyprlang" — under "lua" the module
    # generates its own hypr/hyprland.lua, which would collide with the
    # mkOutOfStoreSymlink for that exact path in xdg.configFile below.
    configType     = "hyprlang";
    # systemd.enable MUST stay false. It works by injecting an `exec-once` into
    # ~/.config/hypr/hyprland.conf that runs `dbus-update-activation-environment`
    # and `systemctl --user start hyprland-session.target`. But Hyprland loads
    # hyprland.lua INSTEAD of hyprland.conf (see the binary's own log lines:
    # "Using lua config found at" / "Lua config not found, using legacy config at"),
    # so that exec-once was never executed and the whole systemd session bootstrap
    # silently did nothing:
    #   * hyprland-session.target never started, and since it BindsTo
    #     graphical-session.target, graphical-session.target never activated;
    #   * so every unit WantedBy/PartOf graphical-session.target (hypridle.service,
    #     tray.target, and critically xdg-desktop-portal.service, which declares
    #     Requisite=graphical-session.target) was permanently dead — that is what
    #     broke browser screen sharing. startup_apps.lua now starts
    #     nixos-fake-graphical-session.target to activate the target directly,
    #     which fixes that without turning this option back on;
    #   * and HYPRLAND_INSTANCE_SIGNATURE / XDG_SESSION_TYPE / DISPLAY never reached
    #     the systemd + dbus activation environment.
    # Arch has no such systemd wiring at all — everything is launched by the
    # exec-once hooks in lua/startup_apps.lua, which now exports the full variable
    # set itself. Setting this false is what makes NixOS match Arch exactly.
    systemd.enable = false;
    # Silences the "no settings/extraConfig" warning. Hyprland never reads the
    # resulting hyprland.conf (hyprland.lua wins) — it exists only to keep the
    # home-manager module quiet.
    extraConfig    = "# config lives in hyprland.lua, not here";
    package = pkgs.hyprland-pinned;  # overlays/default.nix
  };

  # The rest of ~/.config/hypr is linked live in home/dotfiles.nix. hyprlock.conf
  # is a store copy instead, so @HOME@ can be substituted (hyprlock does not
  # expand $HOME in paths); editing it needs a rebuild.
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
