{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./common/options.nix
    ./common/default.nix
  ];
}
