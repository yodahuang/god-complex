{ config, pkgs, ... }:
{
  imports= [
    ./hardware-configuration.nix
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
  
  # Services.
  services.adguardhome = {
    enable = true;
    mutableSettings = false;
    settings = {
      bind_host = "0.0.0.0";
      bind_port = 1080;
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
        upstream_dns = [
          "https://dns.cloudflare.com/dns-query"
        ];
        filters = [
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
            name = "AdGuard DNS filter";
            id = 1;
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_29.txt";
            name = "CHN: AdRules DNS List";
            id = 1690779191;
          }
        ];
      };
    };
  };
  
}