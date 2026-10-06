{ ... }:

# Atuin client — SQLite-backed shell history with fuzzy search, replacing the
# fzf Ctrl+R widget. The sync server it talks to is modules/atuin.nix.
#
# Ctrl+R ownership is the fiddly part of this. Three things used to claim that
# key and home-manager's init ordering decides who wins:
#
#   oh-my-zsh                                  order 800
#   programs.fzf.enable -> source <(fzf --zsh) order 910  (binds Ctrl+R)
#   zsh-fzf-history-search plugin              plugin phase (binds Ctrl+R)
#   home/zsh/scripts/keybinds.sh               order 1000 (bound Ctrl+R AGAIN,
#                                                via a duplicate fzf --zsh)
#   this module's init                         order 1000 (unordered)
#
# The plugin is gone from zsh.nix and the duplicate `source <(fzf --zsh)` is
# gone from keybinds.sh, which leaves fzf at 910 and atuin at 1000 — atuin
# binds last, so atuin wins, deterministically. keybinds.sh still rebinds
# fzf-cd-widget to Alt+R and still works, because 1000 runs after 910.

{
  programs.atuin = {
    enable = true;

    # Up arrow stays plain zsh line-walking. Atuin binds it by default to a
    # prefix-filtered search, which reassigns very ingrained muscle memory and
    # overlaps with zsh-autosuggestions (enabled in zsh.nix). Ctrl+R is the
    # one key atuin takes.
    flags = [ "--disable-up-arrow" ];

    # Background daemon: keeps the SQLite connection warm so a search does not
    # pay DB-open cost on every keypress, and is what search_mode
    # "daemon-fuzzy" below requires. The home-manager module wires this as a
    # socket-activated systemd user unit and sets daemon.systemd_socket = true
    # for us.
    daemon.enable = true;

    settings = {
      # Self-hosted server from modules/atuin.nix, on this same machine for
      # now. To sync with the other host later, point this at its tailnet
      # address instead — that is the whole change.
      sync_address  = "http://127.0.0.1:8888";
      auto_sync     = true;
      sync_frequency = "5m";

      # Enter runs the selected command immediately; Tab puts it on the line
      # for editing instead.
      enter_accept = true;

      # The bordered, full-screen renderer — a box around the result list, the
      # help row with the version and keymap hints along the top, the
      # Search/Inspect tabs under it, and the "[ GLOBAL ]" filter indicator on
      # the input line at the bottom. Atuin's default is "compact", which is
      # the same UI with the border and chrome stripped off and drawn inline
      # under the prompt.
      style = "full";

      # 0 means "always go full screen" rather than capping the UI at N lines.
      # The default is 40, which on a tall terminal leaves the box floating in
      # the middle instead of filling it.
      inline_height = 0;

      # Fuzzy matching performed in the daemon rather than the foreground
      # process. Requires daemon.enable above.
      search_mode = "daemon-fuzzy";

      # Nix owns the version, so atuin checking for its own updates only
      # produces a nag it cannot act on.
      update_check = false;

      # Unbind the alt-1..alt-9 quick-select chords.
      #
      # Upstream ties the numbers in the result list to these shortcuts: the
      # label IS the chord, which is why only nine rows ever get one. We want
      # the numbers as a plain index on every row (that half needs the patch in
      # pkgs/atuin-number-all-rows.patch) and no chord behind them, so the keys
      # are pointed at the no-op action here.
      #
      # `[keymap.<mode>]` is undocumented in atuin's shipped config.toml but is
      # a real, supported option — settings.keymap is a KeymapConfig of
      # HashMap<String, KeyBindingConfig> per mode, and keys named here override
      # the defaults while everything unmentioned is left alone. Only the emacs
      # map is touched because zsh runs `bindkey -e` (see zsh.nix) and atuin's
      # keymap_mode follows the shell.
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

    # Deliberately NOT set: daemon.autostart. The home-manager daemon option
    # above uses systemd socket activation, and atuin's own config docs say
    # autostart is not compatible with systemd_socket = true. Letting both
    # mechanisms try to own the daemon's lifecycle is how you get two of them.
    #
    # Also not set: the [ai] section. Atuin AI is a separate service needing
    # its own Atuin Hub account and sending prompts to atuin.sh. The
    # self-hostable backend is atuinsh/atuin-ai-server, which fronts any
    # OpenAI-compatible endpoint (Ollama, llama.cpp, vLLM) via `[ai] endpoint`.
    # Worth its own pass once sync is proven; not wired up here.
  };
}
