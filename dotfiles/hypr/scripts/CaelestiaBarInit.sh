#!/run/current-system/sw/bin/bash
# bar.persistent=false lets SUPER+SHIFT+T hide the bar, but it starts hidden: show it once at login
# (idempotent across reloads), waiting for quickshell's IPC to answer.
for _ in $(seq 1 60); do
    if caelestia shell drawers isOpen bar >/dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

state="$(caelestia shell drawers isOpen bar 2>/dev/null)"

# 0 = hidden. Anything else (incl. empty if the shell died) is left alone.
if [ "$state" = "0" ]; then
    caelestia shell drawers toggle bar >/dev/null 2>&1
fi

exit 0
