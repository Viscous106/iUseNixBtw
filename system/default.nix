# Everything both hosts share. Every .nix file under system/ is imported.
{ lib, ... }:

{
  imports = import ../lib/import-dir.nix lib ./.;
}
