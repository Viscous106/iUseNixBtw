{ inputs, pkgs, config, user, ... }:

{
  imports = [
    inputs.zen-browser.homeModules.beta
  ];

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
  };

  # The flake installs the binary as `zen-beta`, but setAsDefaultBrowser leaves
  # $BROWSER as `zen-browser`, which is not on PATH. Point it at the real name.
  home.sessionVariables.BROWSER = "zen-beta";

  # Profile lives on /persist.
  xdg.configFile."zen".source = config.lib.file.mkOutOfStoreSymlink "/persist/home/${user.username}/.config/zen";

  # Zen >= 18.18.6b moved the profile from ~/.zen to ~/.config/zen.
  home.activation.migrateZenProfile =
    let
      oldDir = "$HOME/.zen";
      newDir = "$HOME/.config/zen";
    in
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
