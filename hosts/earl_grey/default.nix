{ config, pkgs, ... }:
{
  imports= [
    ./hardware-configuration.nix
    ./adguard_home.nix
  ];

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

  services.openssh.enable = true;

  users.users.yanda = {
    isNormalUser = true;
    description = "Yanda";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  system.stateVersion = "23.05";
  
}