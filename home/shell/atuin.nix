{ ... }:

# Atuin owns Ctrl+R (fzf's binding is disabled in zsh.nix); don't add another
# Ctrl+R binder. Sync server: system/services/atuin-server.nix.

{
  programs.atuin = {
    enable = true;

    # Keep Up as plain zsh history; Ctrl+R is the only key atuin takes.
    flags = [ "--disable-up-arrow" ];

    # Required by search_mode "daemon-fuzzy"; HM runs it socket-activated.
    daemon.enable = true;

    settings = {
      # Local server for now; point at the other host's tailnet address to sync.
      sync_address  = "http://127.0.0.1:8888";
      auto_sync     = true;
      sync_frequency = "5m";

      # Enter runs immediately; Tab puts it on the line for editing.
      enter_accept = true;

      style = "full";

      # 0 = always full screen (default 40 leaves the box floating).
      inline_height = 0;

      search_mode = "daemon-fuzzy";

      # Nix owns the version.
      update_check = false;

      # Disable alt-1..9 quick-select; row numbers are a plain index instead
      # (pkgs/atuin-number-all-rows.patch). keymap.<mode> is undocumented but
      # real; only emacs because zsh uses `bindkey -e`.
      keymap.emacs = {
        "alt-1" = "noop";
        "alt-2" = "noop";
        "alt-3" = "noop";
        "alt-4" = "noop";
        "alt-5" = "noop";
        "alt-6" = "noop";
        "alt-7" = "noop";
        "alt-8" = "noop";
        "alt-9" = "noop";
      };
    };

    # Don't set daemon.autostart: incompatible with systemd_socket = true.
  };
}
