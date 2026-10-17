#!/run/current-system/sw/bin/bash
# Lock.qml's lock() is a no-op while `locked` is stranded at true. Plain binds only
# fire while unlocked, so a true seen here is stale: clear it, then lock (SUPER+N).
set -u

state="$(caelestia shell lock isLocked 2>/dev/null)"

if [ "$state" = "true" ]; then
    caelestia shell lock unlock >/dev/null 2>&1

    # unlock is animated; locked=false lands only when the animation ends.
    for _ in $(seq 1 40); do
        [ "$(caelestia shell lock isLocked 2>/dev/null)" = "true" ] || break
        sleep 0.1
    done
fi

caelestia shell lock lock >/dev/null 2>&1
