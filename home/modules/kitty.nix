{ config, pkgs, ... }:

{
  programs.kitty = {
    enable = true;

    settings = {
      # ── Font ─────────────────────────────────────────────────────────
      font_family       = "JetBrainsMono Nerd Font Mono";
      bold_font         = "JetBrainsMono Nerd Font Mono Bold";
      italic_font       = "JetBrainsMono Nerd Font Mono Italic";
      bold_italic_font  = "JetBrainsMono Nerd Font Mono Bold Italic";
      font_size         = 13;

      # ── Catppuccin Mocha ──────────────────────────────────────────────
      foreground             = "#cdd6f4";
      background             = "#1e1e2e";
      selection_foreground   = "#1e1e2e";
      selection_background   = "#f5e0dc";

      color0  = "#45475a"; color8  = "#585b70";
      color1  = "#f38ba8"; color9  = "#f38ba8";
      color2  = "#a6e3a1"; color10 = "#a6e3a1";
      color3  = "#f9e2af"; color11 = "#f9e2af";
      color4  = "#89b4fa"; color12 = "#89b4fa";
      color5  = "#f5c2e7"; color13 = "#f5c2e7";
      color6  = "#94e2d5"; color14 = "#94e2d5";
      color7  = "#bac2de"; color15 = "#a6adc8";

      cursor           = "#f5e0dc";
      cursor_text_color = "#1e1e2e";
      url_color        = "#f5e0dc";

      # ── Window ────────────────────────────────────────────────────────
      background_opacity      = "0.95";
      dynamic_background_color = "yes";
      window_padding_width    = 8;
      hide_window_decorations = "yes";
      confirm_os_window_close = 0;

      # ── Tab bar ───────────────────────────────────────────────────────
      tab_bar_min_tabs      = 2;
      tab_bar_edge          = "bottom";
      tab_bar_style         = "powerline";
      tab_powerline_style   = "slanted";
      tab_title_template    = "{title}{' :{}:'.format(num_windows) if num_windows > 1 else ''}";

      # ── Misc ──────────────────────────────────────────────────────────
      enable_audio_bell   = "no";
      visual_bell_duration = "0.0";
      scrollback_lines    = 10000;
      copy_on_select      = "clipboard";
      strip_trailing_spaces = "smart";
    };

    keybindings = {
      "ctrl+backspace"     = "send_text all \\x1b[127;5u";
      "ctrl+shift+t"       = "new_tab_with_cwd";
      "ctrl+shift+enter"   = "new_window_with_cwd";
      "ctrl+shift+h"       = "previous_tab";
      "ctrl+shift+l"       = "next_tab";
      "ctrl+shift+equal"   = "change_font_size all +1.0";
      "ctrl+shift+minus"   = "change_font_size all -1.0";
      "ctrl+shift+0"       = "change_font_size all 0";
    };
  };
}
