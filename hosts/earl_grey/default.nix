{
  config,
  pkgs,
  lib,
  ...
}: let
  ips = import ../ips.nix;
in {
  imports = [./hardware-configuration.nix ./caddy.nix ./adguard_home.nix ./chocolate-bar.nix ./homebridge.nix];

  # Use uboot.
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  networking.hostName = "EarlGrey";
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # ssh
      80
      443
      1080 # AdGuard
    ];
    allowedUDPPorts = [
      53 # dns by AdGuard
    ];
  };

  users.users.yanda = {
    isNormalUser = true;
    description = "Yanda";
    extraGroups = ["networkmanager" "wheel"];
  };

  system.stateVersion = "23.05";

  nix.settings.trusted-users = [
    "root"
    "yanda"
  ];

  services.openssh.enable = true;

  # yanda deploys via deploy-rs over a 1Password-agent SSH key, then escalates
  # to root to activate. Passwordless sudo avoids a typed sudo password on the
  # deploy channel (which deploy-rs warns is less secure than keys).
  security.sudo.wheelNeedsPassword = false;

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  # Cross compilation doesn't seem to work.
  # nixpkgs = {
  #   buildPlatform = {
  #     system = "x86_64-linux";
  #     config = "x86_64-unknown-linux-gnu";
  #   };
  # };

  # Sescrets
  age.secrets.cloudflare.file = ../../secrets/cloudflare.age;
}
