{ config, pkgs, lib, ... }: {
  imports = [ ./hardware-configuration.nix ./caddy.nix ./adguard_home.nix ];

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
    extraGroups = [ "networkmanager" "wheel" ];
  };

  system.stateVersion = "23.05";

  services.openssh.enable = true;

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

  # ssh access to remote machine.
  # Don't forget to generate the file and copy the pub key to rig.
  programs.ssh.extraConfig = ''
    Host rig
      IdentityFile /root/.ssh/id_ed25519
      User yanda
      HostName 192.168.4.72
  '';

  # Sescrets
  age.secrets.cloudflare.file = ../../secrets/cloudflare.age;

}
