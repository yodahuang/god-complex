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

  # Weekly store GC. nix-darwin has no programs.nh and nix.gc can't keep the
  # last N generations, so run `nh clean all` (every user's profiles + the
  # system profile) as root: keep 5 generations, plus anything newer than 7d.
  launchd.daemons.nh-clean = {
    script = ''
      ${pkgs.nh}/bin/nh clean all --keep 5 --keep-since 7d
    '';
    path = [config.nix.package pkgs.coreutils];
    serviceConfig = {
      StartCalendarInterval = [
        {
          Weekday = 0;
          Hour = 3;
          Minute = 30;
        }
      ];
      StandardOutPath = "/var/log/nh-clean.log";
      StandardErrorPath = "/var/log/nh-clean.log";
    };
  };

  environment.shells = with pkgs; [
    bashInteractive
    zsh
    fish
  ];

  # HEY CLI — upstream ships no Nix package, so we build it ourselves.
  environment.systemPackages = [
    (pkgs.callPackage ../../pkgs/hey-cli.nix {})
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
      # Was "zap". Homebrew >=5.1 (commit bc44e3d) removed the
      # `--force-cleanup` flag that nix-darwin still emits for
      # cleanup = "uninstall"/"zap", so activation fails with
      # `Error: invalid option: --force-cleanup`. "none" drops the flag.
      # Revert to "zap" once nix-darwin supports the new `trust` model.
      # Manual cleanup meanwhile: `brew bundle --cleanup --force --global`.
      cleanup = "none";
    };
    brews = packages.common.brews ++ (hostPackages.brews or []);
    casks = packages.common.casks ++ (hostPackages.casks or []);
    masApps = packages.common.masApps // (hostPackages.masApps or {});
  };
}
