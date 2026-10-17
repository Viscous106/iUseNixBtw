{ config, lib, ... }:

# Live-editable config: each entry is a symlink from $HOME into this repo, so
# edits take effect without a rebuild. Add an app by adding a line.
let
  repo = "/persist/nixos-config/dotfiles";
  link = path: { source = config.lib.file.mkOutOfStoreSymlink "${repo}/${path}"; };

  # ~/.config/<name> -> <repo>/<path>
  configLinks = {
    # Desktop
    "hypr/hyprland.lua"            = "hypr/hyprland.lua";
    "hypr/lua"                     = "hypr/lua";
    "hypr/monitors.lua"            = "hypr/monitors.lua";   # nwg-displays output
    "hypr/scripts"                 = "hypr/scripts";
    "hypr/icons"                   = "hypr/icons";
    "hypr/shaders"                 = "hypr/shaders";
    "quickshell/wallpaper-picker"  = "quickshell/wallpaper-picker";
    "quickshell/rope-select"       = "quickshell/rope-select";
    "rofi"                         = "rofi";
    "swappy"                       = "swappy";
    "wl-kbptr"                     = "wl-kbptr";
    "nwg-displays"                 = "nwg-displays";
    "nwg-look"                     = "nwg-look";
    "gtk-3.0"                      = "gtk-3.0";
    "qt5ct"                        = "qt5ct";
    "qt6ct"                        = "qt6ct";
    "keyd/app.conf"                = "keyd/app.conf";
    "hyprwhspr/config.json"        = "hyprwhspr/config.json";

    # Shell / terminal
    "zsh/starship.toml"            = "zsh/starship.toml";
    "zsh/scripts"                  = "zsh/scripts";
    "tmux"                         = "tmux";
    "tmuxifier"                    = "tmuxifier";
    "nvim"                         = "nvim";
    "yazi"                         = "yazi";
    "btop"                         = "btop";

    # Apps
    "cava"                         = "cava";
    "spicetify"                    = "spicetify";

    # AI agents. Only static pieces: the rest of ~/.config/claude is runtime
    # state. settings.json is linked by an activation script instead (see
    # home/dev/ai-agents.nix) because Claude rewrites it in place.
    "claude/CLAUDE.md"             = "claude/CLAUDE.md";
    "claude/hooks"                 = "claude/hooks";
    "claude/helpers"               = "claude/helpers";
    "opencode/plugin/agent-state.ts" = "tmux/scripts/agent-state-opencode.ts";
  };

  # ~/<name> -> <repo>/<path>, for tools that don't use XDG paths.
  homeLinks = {
    ".codex/config.toml"                 = "codex/config.toml";  # codex rewrites it (trust levels)
    ".codex/hooks.json"                  = "codex/hooks.json";   # approve once on first codex run
    ".gemini/antigravity-cli/hooks.json" = "agy/hooks.json";
  };
in
{
  xdg.configFile = lib.mapAttrs (_: link) configLinks;
  home.file      = lib.mapAttrs (_: link) homeLinks;
}
