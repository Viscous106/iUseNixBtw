{ pkgs, ... }:

{
  # What the Hyprland keybinds and hypr/scripts call.
  home.packages = with pkgs; [
    wallpaper-picker   # SUPER+W (pkgs/wallpaper-picker.nix)
    rope-select        # region picker for screenshots/recording
    awww               # image wallpapers (used by wallpaper-picker)
    grim
    slurp
    swappy
    wl-clipboard
    cliphist
    rofi               # RofiSearch / ScreenMode / ZshChangeTheme / WallpaperEffects menus
    wl-kbptr
    nwg-displays       # SUPER+ALT+M
    hyprland-qtutils

    # Media keys / OSD scripts
    playerctl
    pamixer
    brightnessctl
    pavucontrol
    pulseaudio         # paplay for Sounds.sh

    # Script plumbing
    jq
    bc
    imagemagick        # WallpaperEffects.sh
  ];
}
