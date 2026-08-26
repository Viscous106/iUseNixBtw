# Wayland display — not inherited inside tmux, set if missing.
if [[ -z "$WAYLAND_DISPLAY" ]]; then
    for _wl in "/run/user/${UID}"/wayland-*(N); do
        [[ -S "$_wl" && "$_wl" != *.lock ]] && export WAYLAND_DISPLAY="${_wl:t}" && break
    done
    unset _wl
fi
