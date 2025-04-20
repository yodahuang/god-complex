{
  pkgs,
  lib,
  ...
}: {
  users.users.yanda = {
    home = "/Users/yanda";
  };

  nix.settings.trusted-users = [
    "root"
    "yanda"
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  environment.shells = with pkgs; [
    bashInteractive
    zsh
    fish
  ];

  system = {
    stateVersion = 5;
    defaults = {
      finder = {
        AppleShowAllExtensions = true;
        ShowPathbar = true;
      };
      NSGlobalDomain.ApplePressAndHoldEnabled = false;
    };
  };

  # Import extra Homebrew packages from darwin/packages.nix
  homebrew = let
    pkg = import ../packages.nix;
  in
    {
      enable = true;
      onActivation = {
        upgrade = true;
        cleanup = "zap";
      };
    }
    // (pkg.homebrew or {});
}
