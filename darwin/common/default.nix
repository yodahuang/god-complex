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
      CustomUserPreferences = {
        NSGlobalDomain.NSQuitAlwaysKeepsWindows = false;
        "com.apple.loginwindow" = {
          TALLogoutSavesState = false;
          LoginwindowLaunchesRelaunchApps = false;
        };
      };
    };
    activationScripts.noResume.text = ''
      rm -rf /Users/yanda/Library/Saved\ Application\ State/*
    '';
    primaryUser = "yanda";
  };

  # Homebrew packages are split into common + host-specific segments
  homebrew = let
    packages = import ./packages.nix;
    hostName = lib.toLower (config.networking.hostName or "");
    hostPackages =
      if hostName != "" && lib.hasAttr hostName packages.hosts
      then packages.hosts.${hostName}
      else {
        brews = [];
        casks = [];
        masApps = {};
      };
  in {
    enable = true;
    onActivation = {
      upgrade = true;
      cleanup = "zap";
    };
    brews = packages.common.brews ++ (hostPackages.brews or []);
    casks = packages.common.casks ++ (hostPackages.casks or []);
    masApps = packages.common.masApps // (hostPackages.masApps or {});
  };
}
