#!/run/current-system/sw/bin/bash
# Lock the session with caelestia's lock screen (SUPER+N).
#
# WHY THIS EXISTS
# modules/lock/Lock.qml exposes the lock over IPC as nothing more than
#
#   function lock(): void { lock.locked = true; }
#
# WlSessionLock.locked is a plain property, so that line is an assignment, not
# a command. When `locked` is already true the assignment changes nothing: no
# property transition fires, no WlSessionLockSurface is ever created, and
# SUPER+N does nothing at all — silently, with no error and nothing written to
# the shell log.
#
# `locked` can be left stranded at true while no lock is actually held. The one
# thing that writes it back to false is the tail of the unlock animation in
# modules/lock/LockSurface.qml
#
#   PropertyAction { target: root.lock; property: "locked"; value: false }
#
# and that lives *inside* the lock surface, so it only runs while that surface
# still exists to receive the unlock signal. Once the state is stranded nothing
# clears it on its own, and SUPER+N stays dead until the shell is restarted.
#
# Clearing a stale `true` here is always safe: Hyprland delivers plain `bind`s
# only while the session is unlocked (a locked session would need `bindl`), so
# if this script is running at all then the session is NOT locked, and any
# `locked = true` observable from here is stale by definition.

set -u

# `caelestia shell …` only forwards an `ipc call`; it never starts a shell. If
# the shell is down this reads empty, there is nothing to lock, and the final
# call below is a harmless no-op.
state="$(caelestia shell lock isLocked 2>/dev/null)"

if [ "$state" = "true" ]; then
    caelestia shell lock unlock >/dev/null 2>&1

    # unlock is animated and writes locked=false only when the animation ends,
    # so poll instead of assuming the next line already sees a cleared state.
    for _ in $(seq 1 40); do
        [ "$(caelestia shell lock isLocked 2>/dev/null)" = "true" ] || break
        sleep 0.1
    done
fi

caelestia shell lock lock >/dev/null 2>&1
