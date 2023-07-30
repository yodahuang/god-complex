{ config, pkgs, ... }:
{
  imports= [
    ./hardware-configuration.nix
  ];

  # Use uboot.
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  
  networking.hostName = "EarlGrey";

  services.openssh.enable = true;

  users.users.yanda = {
    isNormalUser = true;
    description = "Yanda";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  system.stateVersion = "23.05";
}