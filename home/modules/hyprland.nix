{ config, pkgs, inputs, ... }:

{
  # ── Hyprland window manager ─────────────────────────────────────────────────
  # Config is hyprland.lua (native Lua config, requires the hyprland flake
  # input — nixpkgs' pinned version predates Lua support). Hyprland loads
  # hyprland.lua INSTEAD of hyprland.conf when it exists, so no extraConfig.
  wayland.windowManager.hyprland = {
    enable         = true;
    systemd.enable = true;
    # Silences the "no settings/extraConfig" warning — intentional, see above.
    extraConfig    = "# config lives in hyprland.lua, not here";
    # wrapRuntimeDeps disabled: it only adds hyprland-guiutils (the welcome /
    # dialog / donate-screen bin utilities) to Hyprland's runtime PATH -- not
    # needed for the compositor itself. hyprland-guiutils currently fails to
    # build (libstdc++ ABI mismatch: hyprtoolkit compiles with gcc16Stdenv,
    # hyprland-guiutils with the ambient default stdenv -- an inconsistency
    # in the upstream Hyprland flake overlay, not our config). Skipping it
    # avoids depending on that broken build entirely.
    package = inputs.hyprland.packages.${pkgs.system}.hyprland.override {
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
  services.hypridle = {
    enable   = true;
    settings = {}; # config managed via xdg.configFile above
  };
}
