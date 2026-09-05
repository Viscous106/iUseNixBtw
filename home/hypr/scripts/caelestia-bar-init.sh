#!/run/current-system/sw/bin/bash
# Show the caelestia bar once the shell is up.
#
# WHY THIS EXISTS
# SUPER+SHIFT+T toggles the bar through `caelestia shell drawers toggle bar`,
# which flips ScreenState.bar. But modules/bar/BarWrapper.qml computes
#
#   shouldBeVisible: … && (Config.bar.persistent || screenState.bar || isHovered)
#
# so while Config.bar.persistent is true that expression is always true and the
# toggle can never hide the bar. Setting bar.persistent = false (see
# home/modules/caelestia-quickshell.nix) makes the toggle work — but
# components/ScreenState.qml declares `property bool bar` with no initialiser,
# so it starts false and the bar would come up HIDDEN at every login.
#
# This script closes that gap: wait for the shell's IPC to answer, then show the
# bar if it is not already shown. From then on SUPER+SHIFT+T hides and shows it.
#
# It is idempotent — it toggles only when the bar reads as hidden — so a
# Hyprland config reload that re-fires hyprland.start will not flip it off.

# Wait for the shell to accept IPC (fresh login: quickshell needs a few seconds).
for _ in $(seq 1 60); do
    if caelestia shell drawers isOpen bar >/dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

state="$(caelestia shell drawers isOpen bar 2>/dev/null)"

# isOpen reports 0 when the drawer is not shown. Anything else (including an
# empty read, if the shell died between the loop above and here) is left alone
# rather than blind-toggling into the wrong state.
if [ "$state" = "0" ]; then
    caelestia shell drawers toggle bar >/dev/null 2>&1
fi

exit 0
