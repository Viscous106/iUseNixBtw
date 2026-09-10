{ config, pkgs, inputs, ... }:

{
  # ── Caelestia shell ─────────────────────────────────────────────────────────
  # Quickshell-based desktop shell (bar, notifications, launcher, lock, OSDs) —
  # the replacement for waybar + swaync. Upstream ships its own Home Manager
  # module at nix/hm-module.nix, exposed as homeManagerModules.default; it
  # defines programs.caelestia and puts `caelestia-shell` on home.packages.
  #
  # `inputs` is in scope here because flake.nix passes
  # home-manager.extraSpecialArgs = { inherit inputs; }.
  imports = [ inputs.caelestia-shell.homeManagerModules.default ];

  # ── Patch: stop panels closing when another surface takes focus ────────────
  # modules/drawers/ContentWindow.qml wraps the drawers in a HyprlandFocusGrab.
  # Whenever the grab is lost it runs onCleared, which sets screenState.launcher
  # /session/sidebar back to false — i.e. the panel closes. That is how
  # click-outside-to-dismiss is implemented.
  #
  # wl-kbptr (SUPER+H) is a keyboard pointer: it maps its own layer surface and
  # takes focus. That breaks the grab, so opening a panel and then reaching for
  # wl-kbptr to click something in it closes the very panel you were aiming at.
  # There is no config option for this — nothing in upstream's settings schema
  # touches the focus grab — so the condition is patched out.
  #
  # Split by panel, because the grab is simultaneously the click-outside
  # dismissal AND the thing wl-kbptr trips:
  #   * launcher + session KEEP the grab. Both already handle Escape
  #     (modules/{launcher,session}/Content.qml) and have vimKeybinds enabled
  #     below, so they are fully keyboard-drivable and never need wl-kbptr.
  #     Keeping the grab means click-outside still dismisses them.
  #   * sidebar + dashboard LOSE it. Neither has an Escape handler upstream, and
  #     ContentWindow's keyboardFocus is None unless launcher/session is open, so
  #     they cannot receive keys at all — clicking is the only way to use them,
  #     which is exactly when wl-kbptr is needed. They close via their keybind.
  #   * tray menus keep it: transient popups where click-away is the only
  #     sensible dismissal.
  # The two onCleared assignments are dropped too, so a launcher/session grab
  # clearing does not drag an open sidebar or dashboard shut with it.
  programs.caelestia.package =
    (inputs.caelestia-shell.packages.${pkgs.stdenv.hostPlatform.system}.with-cli).overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace modules/drawers/ContentWindow.qml \
          --replace-fail \
            'if ((s.launcher && conf.launcher.enabled) || (s.session && conf.session.enabled) || (s.sidebar && conf.sidebar.enabled))' \
            'if ((s.launcher && conf.launcher.enabled) || (s.session && conf.session.enabled)) // patched: sidebar dropped' \
          --replace-fail \
            'if (!conf.dashboard.showOnHover && s.dashboard && conf.dashboard.enabled)' \
            'if (false) // patched: dashboard grab disabled' \
          --replace-fail \
            'root.screenState.sidebar = false;' \
            '// patched: sidebar is not auto-closed on focus loss' \
          --replace-fail \
            'root.screenState.dashboard = false;' \
            '// patched: dashboard is not auto-closed on focus loss'

        # vimKeybinds ships Ctrl+J/K (and Ctrl+N/P) for next/previous. Move that
        # to Alt. Bare j/k cannot be used in the launcher — it has a live search
        # field, so unmodified letters must stay typeable — and the session reuses
        # the same handler, so both files get the same change. Alt is otherwise
        # unused in both. Tab / Shift+Tab keep working either way.
        substituteInPlace modules/launcher/Content.qml \
          --replace-fail \
            'if (event.modifiers & Qt.ControlModifier) {' \
            'if (event.modifiers & Qt.AltModifier) {'

        substituteInPlace modules/session/Content.qml \
          --replace-fail \
            'if (event.modifiers & Qt.ControlModifier) {' \
            'if (event.modifiers & Qt.AltModifier) {'

        # ── Patch: battery as its own bar entry, above the clock ─────────────
        # Upstream only draws the battery inside the statusIcons pill, which
        # sits BELOW the clock and shares one rounded background with wifi and
        # bluetooth. There is no config knob to lift it out: the C++ schema
        # (plugin/src/Caelestia/Config/barconfig.hpp) hardcodes the default
        # bar.entries list, and modules/bar/Bar.qml's DelegateChooser only has
        # choices for spacer/logo/workspaces/activeWindow/tray/clock/
        # statusIcons/power.
        #
        # ListEntry.id is a plain QString with no enum validation, though, so
        # bar.entries in shell.json happily takes an id upstream never defined.
        # All that is missing is a DelegateChoice to match it — added below,
        # along with the component it draws. An entry whose id matches no
        # choice renders nothing, so this patch and the bar.entries setting
        # further down have to ship together.
        #
        # Every --replace-fail pattern here is a SINGLE line on purpose. A
        # multi-line pattern would need lines at column 0 to match the file,
        # and that drops the common indent Nix strips from this indented
        # string to zero — which would leave the heredoc terminator below
        # indented, and an indented terminator does not end a quoted heredoc.
        cat > modules/bar/components/Battery.qml <<'CAELESTIA_BATTERY_QML'
        import QtQuick
        import QtQuick.Layouts
        import Quickshell.Services.UPower
        import Caelestia.Config
        import qs.components
        import qs.services
        import qs.utils

        // Charge icon over the percentage, sized and coloured to sit directly
        // above the clock: same innerWidth, no background pill (the clock's
        // own background defaults off, and two stacked pills read as heavy).
        Item {
            id: root

            // False on a desktop, and false whenever upowerd is not on the
            // bus. Bar.qml hides the whole entry on it.
            readonly property bool present: UPower.displayDevice.isLaptopBattery

            readonly property bool charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice.state)

            // Matches status/BatteryStatus.qml: error colour under 20%, but
            // only while actually running off the battery.
            readonly property color colour: !UPower.onBattery || UPower.displayDevice.percentage > 0.2 ? Colours.palette.m3secondary : Colours.palette.m3error

            implicitWidth: Tokens.sizes.bar.innerWidth
            implicitHeight: layout.implicitHeight

            ColumnLayout {
                id: layout

                anchors.centerIn: parent
                spacing: Tokens.spacing.extraSmall / 2

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter

                    animate: true
                    text: Icons.getBatteryIcon(UPower.displayDevice.percentage, root.charging)
                    color: root.colour
                    fill: 1
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter

                    animate: true
                    text: Math.round(UPower.displayDevice.percentage * 100)
                    color: root.colour
                    font: Tokens.font.body.builders.small.scale(0.9).build()
                }
            }
        }
        CAELESTIA_BATTERY_QML

        substituteInPlace modules/bar/Bar.qml \
          --replace-fail \
            'roleValue: "clock"' \
            'roleValue: "battery"
                delegate: EntryWrapper {
                    // ColumnLayout skips invisible items along with their
                    // spacing, so the battery-less case costs no gap and the
                    // same bar.entries list works on the desktop too.
                    visible: bat.present

                    Battery {
                        id: bat

                        objectName: "taskbarBattery"
                    }
                }
            }
            DelegateChoice {
                roleValue: "clock"' \
          --replace-fail \
            '} else if (id === "activeWindow" && Config.bar.popouts.activeWindow && Config.bar.activeWindow.showOnHover) {' \
            '} else if (id === "battery" && Config.bar.popouts.statusIcons) {
            // Reuses the "battery" popout in popouts/Content.qml — the same
            // one the statusIcons entry opened on hover before it moved here.
            popouts.currentName = "battery";
            popouts.currentCenter = (ch.item as Item).mapToItem(root, 0, (ch.item as Item).implicitHeight / 2).y ?? 0;
            popouts.hasCurrent = true;
        } else if (id === "activeWindow" && Config.bar.popouts.activeWindow && Config.bar.activeWindow.showOnHover) {'
      '';
    });

  programs.caelestia = {
    enable = true;

    # The caelestia CLI drives the running shell over IPC (wallpaper and colour
    # scheme switching, toggling panels from keybinds). The module's default
    # package is already the `with-cli` variant, so the shell bundles it; this
    # additionally puts the standalone `caelestia` binary on PATH.
    cli.enable = true;

    # Launch from Hyprland's startup_apps.lua rather than the systemd user unit.
    # Upstream's unit is WantedBy = config.wayland.systemd.target, which resolves
    # to graphical-session.target — and this session never reaches it. Hyprland
    # is started directly here (no uwsm), so that target sits inactive and the
    # unit would never fire. Verified: `systemctl --user is-active
    # graphical-session.target` -> inactive. exec_cmd also matches how waybar was
    # launched, keeping one startup mechanism for the session.
    systemd.enable = false;

    settings = {
      # Caelestia's default is ~/Pictures/Wallpapers (capital W); this library is
      # ~/Pictures/wallpapers, and btrfs is case-sensitive — so it found nothing
      # and fell back to its own bundled assets/wallpaper.webp. That is why the
      # desktop background changed when the shell first started.
      # FileSystemModel is `recursive: true`, so the per-theme subdirectories
      # (favs, scene, animeGirls, …) are all picked up from this one path.
      paths.wallpaperDir = "~/Pictures/wallpapers";

      # Upstream defaults dashboard.showOnHover to true, which makes the whole
      # top edge of the screen a hover trigger: moving the pointer up to reach a
      # window's own top-right controls slides the dashboard down over them, so
      # the click lands on the dashboard instead. The drawers surface is
      # full-screen (namespace caelestia-drawers, 1920x1080 at layer "top") and
      # its input mask grows to the panel's height once the panel opens, so this
      # is not recoverable by clicking faster. The dashboard is still on
      # SUPER+SHIFT+E and SUPER+ALT+B; only the hover trigger goes away.
      dashboard.showOnHover = false;

      # Caelestia must not paint a wallpaper: qs-wallpaper-picker applies through
      # awww (images, with transitions) and mpvpaper (video), and both draw on
      # the background layer. With caelestia also painting there, the two fight
      # over the same surface. awww/mpvpaper wins ownership because it is the
      # only one of the two that can do video at all.
      # Consequence: the wallpaper no longer drives caelestia's Material colour
      # scheme. Use `caelestia scheme set …` by hand, or set
      # enableDynamicColors in the picker's Settings.qml to hand that job to
      # matugen (already on the picker's PATH).
      background.wallpaperEnabled = false;

      # SUPER+SHIFT+T toggles the bar via `drawers toggle bar`, which flips
      # ScreenState.bar. modules/bar/BarWrapper.qml computes
      #   shouldBeVisible: … && (bar.persistent || screenState.bar || isHovered)
      # so while persistent is true that is unconditionally true and the toggle
      # can never hide the bar — which is exactly what it looked like was broken.
      # showOnHover off too, so the bar responds ONLY to the keybind and does not
      # slide back in whenever the pointer nears the left edge.
      # ScreenState.bar defaults to false, so scripts/caelestia-bar-init.sh shows
      # the bar once at login; see that file.
      bar.persistent = false;
      bar.showOnHover = false;

      # Battery above the clock. Upstream's default entry order is
      #   logo, workspaces, spacer, activeWindow, spacer, tray, clock,
      #   statusIcons, power
      # and the whole list has to be restated because bar.entries replaces the
      # default rather than merging into it — the only change against upstream
      # is the "battery" line, which the Bar.qml patch above teaches the bar to
      # draw.
      bar.entries = [
        { id = "logo";         enabled = true; }
        { id = "workspaces";   enabled = true; }
        { id = "spacer";       enabled = true; }
        { id = "activeWindow"; enabled = true; }
        { id = "spacer";       enabled = true; }
        { id = "tray";         enabled = true; }
        { id = "battery";      enabled = true; }
        { id = "clock";        enabled = true; }
        { id = "statusIcons";  enabled = true; }
        { id = "power";        enabled = true; }
      ];

      # …and off in the statusIcons pill, so it is not drawn twice. Same deal:
      # the full list is restated, and only the battery line differs from
      # upstream's defaults.
      bar.statusIcons = [
        { id = "lockStatus"; enabled = true; }
        { id = "audio";      enabled = false; }
        { id = "microphone"; enabled = false; }
        { id = "kbLayout";   enabled = false; }
        { id = "network";    enabled = true; }
        { id = "bluetooth";  enabled = true; }
        { id = "battery";    enabled = false; }
      ];

      # The launcher and session panels have built-in hjkl navigation, off by
      # default. With these on, neither needs wl-kbptr at all — type/arrows/Enter
      # already drive them. (No such option exists for the sidebar, which is why
      # the focus-grab patch below is still needed.)
      launcher.vimKeybinds = true;
      session.vimKeybinds = true;
    };
  };

  # The CLI does not read shell.json. caelestia/utils/paths.py resolves the
  # library as os.getenv("CAELESTIA_WALLPAPERS_DIR", ~/Pictures/Wallpapers) —
  # a completely separate mechanism from the shell's paths.wallpaperDir above.
  # Without this, `caelestia wallpaper -r` dies with "No valid wallpapers found"
  # while the shell's own picker happily lists all 274 images.
  home.sessionVariables.CAELESTIA_WALLPAPERS_DIR = "${config.home.homeDirectory}/Pictures/wallpapers";

  # ── qs-wallpaper-picker ─────────────────────────────────────────────────────
  # Fast keyboard-first Quickshell picker on SUPER+W, handling images and video.
  # See pkgs/qs-wallpaper-picker.nix. It reads its library from QS_WALLPAPER_DIR
  # (upstream default is ~/Wallpapers, which is not where this library lives).
  home.packages = [
    pkgs.qs-wallpaper-picker
    # `caelestia clipboard` (SUPER+V) shells out to `fuzzel --dmenu` to render
    # the picker and to cliphist to read/decode history — see the CLI's
    # subcommands/clipboard.py. cliphist and wl-copy were already installed;
    # fuzzel was not, so the command would have died on a missing binary.
    pkgs.fuzzel
  ];
  home.sessionVariables.QS_WALLPAPER_DIR = "${config.home.homeDirectory}/Pictures/wallpapers";
}
