{
  pkgs,
  lib,
  ...
}: {
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [git vim];

  # Necessary for using flakes on this system.
  nix = {
    settings = {
      experimental-features = "nix-command flakes";
      substituters = ["https://nix-community.cachix.org" "https://cache.nixos.org/"];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };

  programs.fish.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
    # https://github.com/NixOS/nixpkgs/issues/273611
    permittedInsecurePackages =
      pkgs.lib.optional (pkgs.obsidian.version == "1.5.3") "electron-25.9.0";
  };

  users.users.yanda = {
    # NixOS would add some more ones.
    name = "yanda";
    shell = pkgs.fish;
  };

  nix.buildMachines = [
    {
      hostName = "studio";
      sshUser = "yanda";
      systems = ["aarch64-linux"];
      protocol = "ssh-ng";
      maxJobs = 1;
      speedFactor = 2;
      supportedFeatures = ["nixos-test" "big-parallel" "kvm"];
      mandatoryFeatures = [];
    }
  ];
  nix.distributedBuilds = true;
  # optional, useful when the builder has a faster internet connection than yours
  nix.settings = {
    builders-use-substitutes = true;
  };
}
