{ config, pkgs, inputs, ... }:

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
    #     tray.target) was permanently dead;
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
    # wrapRuntimeDeps disabled: it only adds hyprland-guiutils (the welcome /
    # dialog / donate-screen bin utilities) to Hyprland's runtime PATH -- not
    # needed for the compositor itself. hyprland-guiutils currently fails to
    # build (libstdc++ ABI mismatch: hyprtoolkit compiles with gcc16Stdenv,
    # hyprland-guiutils with the ambient default stdenv -- an inconsistency
    # in the upstream Hyprland flake overlay, not our config). Skipping it
    # avoids depending on that broken build entirely.
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland.override {
      wrapRuntimeDeps = false;
      # Hyprland's CMakeLists.txt requires glaze 7.x (find_package(glaze 7...<8)),
      # but current nixpkgs' glaze is 8.1.0 -- pinned back to 7.2.0 for this
      # build only (doesn't affect the system-wide glaze package).
      glaze-hyprland = pkgs.glaze.overrideAttrs (old: {
        version = "7.2.0";
        src = pkgs.fetchFromGitHub {
          owner = "stephenberry";
          repo = "glaze";
          rev = "v7.2.0";
          hash = "sha256-f3NVRi3SXKo42hn0WCw7JsOK3EkdOVJIcuzhPorKjFY=";
        };
      });
    };
  };

  # ── Symlink config tree into ~/.config/hypr/ ────────────────────────────────
  xdg.configFile = {
    # Top-level conf files — force = true overwrites leftovers from old HM generation
    "hypr/hyprlock.conf" = { source = ../hypr/hyprlock.conf; force = true; };
    "hypr/hypridle.conf" = { source = ../hypr/hypridle.conf; force = true; };

    # hyprland.lua — entry point; requires("lua.<module>") resolves relative to it
    "hypr/hyprland.lua".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/hyprland.lua";

    # lua/ — the actual config modules (keybinds, monitors, startup, etc.)
    "hypr/lua".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/lua";

    # animations/ — selectable animation presets
    "hypr/animations".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/animations";

    # top-level state/meta files referenced by lua/monitors.lua + setup scripts
    "hypr/monitors.conf".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/monitors.conf";
    "hypr/workspaces.conf".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/workspaces.conf";
    "hypr/hypr-setup.sh".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/hypr-setup.sh";
    "hypr/sync.sh".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/sync.sh";
    "hypr/pkglist.txt".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/pkglist.txt";
    "hypr/aurlist.txt".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/aurlist.txt";

    # configs/ — mostly dead weight left over from the pre-Lua config (kept
    # for parity with what's still on Arch), but user-defaults.sh and
    # wallpaper_effects/ are still live-read by the Lua config/scripts.
    "hypr/configs".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/configs";

    # scripts/ — live editable without a rebuild
    "hypr/scripts".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/scripts";

    # shaders/ — screen mode shaders (ScreenMode.sh)
    "hypr/shaders".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/shaders";
  };

  # ── Hyprlock screen locker ──────────────────────────────────────────────────
  programs.hyprlock = {
    enable      = true;
    extraConfig = ""; # config managed via xdg.configFile above
  };

  # ── Hypridle idle daemon ────────────────────────────────────────────────────
  # Deliberately NOT using services.hypridle. Its unit is WantedBy/PartOf
  # graphical-session.target, which never activates here (see systemd.enable
  # above), so the service could never start — and if it ever did, it would run a
  # SECOND hypridle alongside the one lua/startup_apps.lua execs directly with
  # `hypridle -c ~/.config/hypr/configs/hypridle.conf`. Arch runs exactly one
  # hypridle, started from the Lua config; this matches that.
  # The package itself is installed via modules/desktop.nix systemPackages.
  services.hypridle.enable = false;
}
