{ config, pkgs, ... }:
let 
  homePage = pkgs.callPackage ./homepage.nix { };
in
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
    openFirewall = true;
    settings = {
      bind_host = "0.0.0.0";
      bind_port = 1080;
      http = {
        address = "0.0.0.0:1080";
      };
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
        bootstrap_dns = [
          "9.9.9.10"
          "149.112.112.10"
          "2620:fe::10"
          "2620:fe::fe:10"
        ];
        upstream_dns = [
          "https://dns.cloudflare.com/dns-query"
        ];
        rewrites = [
          {
            domain = "*.home";
            answer = "192.168.4.117";
          }
        ];
      };
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
      users = [
        {
          name = "yanda";
          password = "$2a$10$BQ0wuBshl8/n6b0Pfa0KYeC3bPo/Hvv9QLbS.w8xtXCPN8.WUvtUi";
        }
      ];
    };
  };

  services.caddy= {
    enable = true;
    logFormat = ''
      level INFO
    '';
    # Note that it's not localhost. Now we let it bind on all interfaces.
    virtualHosts.":80, my.home" = {
      extraConfig = ''
        root * ${homePage}
        file_server
        tls internal
      '';
      # Needed as the default one,
      # `output file ''${config.services.caddy.logDir}/access-''${hostName}.log`
      # cannot handle multiple hosts.
      logFormat = ''
        output discard
      '';
    };
  };
  
}