{ config, lib, pkgs, ... }:

let
  repo = "git@gitlab.com:viscous106/wallpapers.git";
  dir  = "${config.home.homeDirectory}/Pictures/wallpapers";
in
{
  # Clone the wallpaper library (Git LFS) on first activation; never pulls or overwrites.
  home.activation.cloneWallpapers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "${dir}/.git" ]; then
      export PATH="${lib.makeBinPath [ pkgs.git pkgs.git-lfs pkgs.openssh ]}:$PATH"
      export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
      $DRY_RUN_CMD mkdir -p "$(dirname "${dir}")"
      $DRY_RUN_CMD git clone "${repo}" "${dir}" \
        || echo "wallpapers: clone failed (SSH key not set up yet?); run: git clone ${repo} ${dir}"
    fi
  '';
}
