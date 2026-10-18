# rope-select: animated slurp-compatible region selector; QML lives in dotfiles/quickshell (no rebuild).
# slurp is a runtimeInput because select.sh falls back to it.
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
