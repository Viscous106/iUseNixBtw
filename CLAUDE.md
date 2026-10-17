# Rules for this repo

- **One feature, one comment.** Each setting, workaround or block gets at most
  a single short comment (one line, two if it really needs it) saying *why*.
  No paragraphs, no history ("used to…", "removed X"), no investigation notes,
  no comments that restate the code. Put longer reasoning in a commit message.
- Layout and how to add things: see README.md. New `.nix` files under
  `system/` or `home/` are auto-imported; live-edited configs go in
  `dotfiles/<app>/` plus one line in `home/dotfiles.nix`.
- Scripts in `dotfiles/hypr/scripts/` are PascalCase (`ScreenShot.sh`).
- Verify changes by building both hosts:
  `nixos-rebuild build --flake .#laptop` and `.#nix`.
