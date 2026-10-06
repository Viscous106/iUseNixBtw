# ── rope-select ─────────────────────────────────────────────────────────────
# Wrapper for the animated region selector whose QML lives at
# home/quickshell/rope-select/ and is symlinked live into
# ~/.config/quickshell/rope-select (see home/modules/rope-select.nix).
#
# Drop-in replacement for slurp: prints "X,Y WxH" and exits 0, or exits
# non-zero on cancel. ScreenShot.sh and ScreenRecord.sh call it in place of
# slurp; see home/quickshell/rope-select/select.sh for the contract.
#
# Same split as wallpaper-picker: the QML is deliberately NOT copied into the
# store, so the rope physics can be retuned and re-run without a rebuild. What
# the store owns is the dependency closure — launched from a Hyprland keybind
# the process inherits Hyprland's PATH, which does not reliably carry
# quickshell.
#
# slurp IS in runtimeInputs, and is not optional: select.sh falls back to it
# whenever the overlay cannot answer, so a broken selector costs the animation
# and not the screenshot. Leaving it to the ambient PATH would mean the one
# code path that exists to survive a failure could itself fail.
{
  lib,
  writeShellApplication,
  quickshell,
  slurp,
  coreutils,
}:

writeShellApplication {
  name = "rope-select";

  runtimeInputs = [
    quickshell
    slurp
    coreutils
  ];

  text = ''
    CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/rope-select"

    if [ ! -d "$CONFIG_DIR" ]; then
      echo "rope-select: $CONFIG_DIR missing (is the home-manager module enabled?)" >&2
      # Not fatal: slurp still does the job, just without the animation.
      exec slurp "$@"
    fi

    exec "$CONFIG_DIR/select.sh" "$@"
  '';

  meta = {
    description = "Animated rope-physics screen region selector, slurp-compatible";
    mainProgram = "rope-select";
    platforms = lib.platforms.linux;
  };
}
