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
        # The component is a fill gauge rather than upstream's glyph, and it
        # takes click and scroll (cycling percent / time / watts). Hover keeps
        # the stock battery popout, rewired below in checkPopout.
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

        // Battery as a drawn fill gauge rather than a glyph, sized to sit directly
        // above the clock: same innerWidth, no background pill (the clock's own
        // background defaults off, and two stacked pills read as heavy).
        //
        // The state properties below are deliberately writable and default to a
        // UPower binding rather than being readonly. Assigning one overrides the
        // binding, which is what lets the widget be driven from a test harness --
        // UPower's own properties are read-only, so there is no other way to
        // exercise the thresholds without physically draining the battery.
        Item {
            id: root

            property real charge: UPower.displayDevice.percentage
            property bool charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice.state)
            property real power: UPower.displayDevice.changeRate
            property int secsRemaining: charging ? UPower.displayDevice.timeToFull : UPower.displayDevice.timeToEmpty

            // 0 = percent, 1 = time remaining, 2 = draw in watts. Cycled by click and
            // by scrolling over the entry (see the handleWheel patch in Bar.qml).
            property int readout: 0

            // False on a desktop, and false whenever upowerd is not on the bus.
            // Bar.qml hides the whole entry on it.
            readonly property bool present: UPower.displayDevice.isLaptopBattery

            readonly property real level: Math.max(0, Math.min(1, charge))

            // Low enough to want attention, but not while it is already recovering.
            readonly property bool critical: !charging && level < 0.15

            // All four come from the Material You palette, so the gauge keeps
            // tracking `caelestia scheme` instead of pinning literal red/amber/green.
            readonly property color fillColour: charging ? Colours.palette.m3primary : level < 0.2 ? Colours.palette.m3error : level < 0.4 ? Colours.palette.m3tertiary : Colours.palette.m3secondary

            readonly property string label: {
                if (readout === 1) {
                    const s = Math.max(0, secsRemaining);
                    const h = Math.floor(s / 3600);
                    const m = Math.floor(s / 60) % 60;
                    if (h > 0)
                        return h + "h" + (m < 10 ? "0" : "") + m;
                    return m + "m";
                }
                if (readout === 2)
                    return Math.abs(power).toFixed(1) + "W";
                return String(Math.round(level * 100));
            }

            // Exposed as the animation TARGET, not fill.height: a Behavior eases
            // fill.height towards this, so reading the live height mid-transition
            // would say nothing about whether the geometry is right.
            readonly property real fillHeight: track.height * level
            readonly property alias trackHeight: track.height

            function cycleReadout(dir: int): void {
                readout = (readout + (dir < 0 ? 2 : 1)) % 3;
            }

            implicitWidth: Tokens.sizes.bar.innerWidth
            implicitHeight: layout.implicitHeight

            StateLayer {
                radius: Tokens.rounding.full
                onClicked: root.cycleReadout(1)
            }

            ColumnLayout {
                id: layout

                anchors.centerIn: parent
                spacing: Tokens.spacing.extraSmall / 2

                Item {
                    id: gauge

                    Layout.alignment: Qt.AlignHCenter

                    implicitWidth: 22
                    implicitHeight: 35

                    StyledRect {
                        id: cap

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top

                        implicitWidth: 9
                        implicitHeight: 3
                        radius: Tokens.rounding.small
                        color: root.fillColour
                    }

                    StyledClippingRect {
                        id: track

                        anchors.top: cap.bottom
                        anchors.topMargin: 2
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter

                        implicitWidth: 20
                        radius: Tokens.rounding.small
                        color: Colours.tPalette.m3surfaceContainer

                        StyledClippingRect {
                            id: fill

                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right

                            height: root.fillHeight
                            radius: track.radius
                            color: root.fillColour

                            Behavior on height {
                                Anim {
                                    type: Anim.SlowSpatial
                                }
                            }

                            // Charging: a band travels up the charged portion. Clipped
                            // to the fill, so it never appears over empty track.
                            StyledRect {
                                id: shine

                                anchors.left: parent.left
                                anchors.right: parent.right

                                implicitHeight: 7
                                visible: root.charging
                                color: Qt.alpha(Colours.palette.m3onPrimary, 0.45)
                            }

                            SequentialAnimation {
                                running: root.charging
                                loops: Animation.Infinite

                                Anim {
                                    target: shine
                                    property: "y"
                                    from: fill.height
                                    to: -shine.implicitHeight
                                    duration: 1400
                                }
                            }

                            // Low and falling: breathe, so it catches the eye without
                            // the jitter of a blink. Stops the moment it is plugged in.
                            SequentialAnimation {
                                running: root.critical
                                loops: Animation.Infinite

                                onStopped: fill.opacity = 1

                                Anim {
                                    target: fill
                                    property: "opacity"
                                    to: 0.35
                                    duration: 900
                                }
                                Anim {
                                    target: fill
                                    property: "opacity"
                                    to: 1
                                    duration: 900
                                }
                            }
                        }
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter

                    animate: true
                    text: root.label
                    color: root.fillColour
                    font: Tokens.font.body.builders.small.scale(root.label.length > 3 ? 0.7 : 0.9).build()
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
            '} else if (y < screen.height / 2 && Config.bar.scrollActions.volume) {' \
            '} else if (ch?.entryId === "battery") {
            // Must come before the half-screen branches: the battery sits in
            // the bottom half, so without this a scroll over it would fall
            // through to the brightness action.
            (ch.item as Battery).cycleReadout(angleDelta.y > 0 ? 1 : -1);
        } else if (y < screen.height / 2 && Config.bar.scrollActions.volume) {' \
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
