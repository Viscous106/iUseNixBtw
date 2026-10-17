# Every .nix file under `dir` (recursively), except default.nix files.
# Used by system/default.nix and home/default.nix: adding a file enables it.
lib: dir:
builtins.filter
  (path: lib.hasSuffix ".nix" path && baseNameOf path != "default.nix")
  (lib.filesystem.listFilesRecursive dir)
