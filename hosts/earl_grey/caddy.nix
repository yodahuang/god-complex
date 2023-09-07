{ config, pkgs, ... }:
let 
  homePage = pkgs.callPackage ./homepage.nix { };
  ips = import ../ips.nix;
  # TODO: Duplicate here.
  ADGUARD_PORT = 1080;
  in
{
  services.caddy = {
    enable = true;
    logFormat = ''
      level INFO
    '';
    globalConfig = ''
      local_certs
    '';
    # Note that it's not localhost. Now we let it bind on all interfaces.
    virtualHosts = {
      ":80, my.home" = {
        extraConfig = ''
          root * ${homePage}
          file_server
        '';
        # Needed as the default one,
        # `output file ''${config.services.caddy.logDir}/access-''${hostName}.log`
        # cannot handle multiple hosts.
        logFormat = ''
          output discard
        '';
      };
      "adguard.home" = {
        extraConfig = ''
          reverse_proxy localhost:${toString ADGUARD_PORT}
        '';
      };
      "radarr.home" = {
        extraConfig = ''
          reverse_proxy ${ips.nas}:7878
        '';
      };
      "bazarr.home" = {
        extraConfig = ''
          reverse_proxy ${ips.nas}:6767
        '';
      };
      "sonarr.home" = {
        extraConfig = ''
          reverse_proxy ${ips.nas}:8989
        '';
      };
      "plex.home" = {
        extraConfig = ''
          reverse_proxy ${ips.nas}:32400
        '';
      };
      "ethernet-switch.home" = {
        extraConfig = ''
          reverse_proxy ${ips.ethernet_switch}
        '';
      };
      "power.home" = {
        extraConfig = ''
          reverse_proxy ${ips.nas}:9999
        '';
      };
      "nas.home" = {
        extraConfig = ''
          reverse_proxy ${ips.nas}:4200
        '';
      };
      "sabnzbd.home" = {
        extraConfig = ''
          reverse_proxy ${ips.nas}:8080
        '';
      };
      "homebridge.home" = {
        extraConfig = ''
          reverse_proxy localhost:8581
        '';
      };
      "octoprint.home" = {
        extraConfig = ''
          reverse_proxy ${ips.octo}:1080
        '';
      };
      "home-assistant.home" = {
        extraConfig = ''
          reverse_proxy ${ips.octo}:8123
        '';
      };
      "phoscon.home" = {
        extraConfig = ''
          reverse_proxy localhost:3080
        '';
      };
    };
  };
}