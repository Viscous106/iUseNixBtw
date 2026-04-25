{ inputs, pkgs, config, ... }:

{
  imports = [
    # Community flake — provides programs.zen-browser.*
    inputs.zen-browser.homeModules.beta
  ];

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
  };

  # ── Persistent Profile ─────────────────────────────────────────────────────
  # Ensures the Zen profile is stored on the persistent partition
  xdg.configFile."zen".source = config.lib.file.mkOutOfStoreSymlink "/persist/home/viscous/.config/zen";

  # ── Profile migration note ─────────────────────────────────────────────────
  # Zen >= 18.18.6b expects config in ~/.config/zen (not ~/.zen).
  home.activation.migrateZenProfile =
    let
      oldDir = "$HOME/.zen";
      newDir = "$HOME/.config/zen";
    in
    # entryAfter writeBoundary so home.file symlinks are already in place
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      if [ -d "${oldDir}" ] && [ ! -d "${newDir}" ] && [ ! -L "${newDir}" ]; then
        $DRY_RUN_CMD mkdir -p "${newDir}"
        $DRY_RUN_CMD cp -a "${oldDir}/." "${newDir}/"

        # Fix hardcoded ".zen" paths inside the profile files
        for f in "${newDir}"/*/extensions.json \
                 "${newDir}"/*/pkcs11.txt \
                 "${newDir}"/*/chrome_debugger_profile/pkcs11.txt; do
          [ -f "$f" ] && $DRY_RUN_CMD sed -i 's|\.zen/|\.config/zen/|g' "$f"
        done

        echo "Zen profile migrated: ${oldDir} → ${newDir}"
      fi
    '';
}
