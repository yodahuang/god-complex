{
  pkgs,
  lib,
  ...
}: {
  imports = [../../darwin/core.nix];
  # Add host-specific config here

  homebrewProfile = "full";

  # Used to bootstrap virby
  nix.linux-builder.enable = false;

  # Virby stuff
  nix.settings.extra-substituters = ["https://virby-nix-darwin.cachix.org"];
  nix.settings.extra-trusted-public-keys = [
    "virby-nix-darwin.cachix.org-1:z9GiEZeBU5bEeoDQjyfHPMGPBaIQJOOvYOOjGMKIlLo="
  ];

  services.virby = {
    enable = false;
    onDemand.enable = true;
    onDemand.ttl = 30; # Idle timeout in minutes
    speedFactor = 3;
  };
}
