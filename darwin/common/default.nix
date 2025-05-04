{
  config,
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

  # Homebrew profile selection via argument
  homebrew = let
    profiles = import ./packages.nix;
    profile =
      if config.homebrewProfile == "full"
      then profiles.homebrewFull
      else profiles.homebrewLite;
  in
    {
      enable = true;
      onActivation = {
        upgrade = true;
        cleanup = "zap";
      };
    }
    // profile;
}
