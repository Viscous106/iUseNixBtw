#!/run/current-system/sw/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# For manually starting xdg-desktop-portal-hyprland

# NixOS runs the portals as D-Bus-activated systemd --user services (Type=dbus,
# PartOf=graphical-session.target) rather than plain /usr/lib(exec) binaries,
# which don't exist here. Restart them through systemd instead of manually
# killing/relaunching nonexistent paths.
systemctl --user restart xdg-desktop-portal.service xdg-desktop-portal-hyprland.service

