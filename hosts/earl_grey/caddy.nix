{ config, pkgs, lib, ... }:
let
  homePage = pkgs.callPackage ./homepage.nix { };
  meowdy = pkgs.callPackage ../../pkgs/meowdy.nix { };
  ips = import ../ips.nix;
  # TODO: Duplicate here.
  ADGUARD_PORT = 1080;
  # Helper functions
  make_hostnames = name: "http://${name}.home, ${name}.int.yanda.rocks";
  # From my custom format to Caddyfile
  transform_to_virtual_hosts = hosts:
    lib.listToAttrs (map (name:
      let hostnames = make_hostnames name;
      in {
        name = hostnames;
        value = {
          logFormat =
            "output file ${config.services.caddy.logDir}/access-${name}.log";
          extraConfig = hosts.${name}.extraConfig;
        };
      }) (lib.attrNames hosts));
in {
  services.caddy = {
    enable = true;
    package = meowdy.override {
      externalPlugins = [{
        name = "cloudflare-dns";
        repo = "github.com/caddy-dns/cloudflare";
        version = "bfe272c8525b6dd8248fcdddb460fd6accfc4e84";
      }];
      vendorHash = "sha256-mwIsWJYKuEZpOU38qZOG1LEh4QpK4EO0/8l4UGsroU8=";
    };
    logFormat = ''
      level INFO
    '';
    globalConfig = ''
      acme_dns cloudflare {env.CF_API_TOKEN}
    '';
    # Note that it's not localhost. Now we let it bind on all interfaces.
    virtualHosts = transform_to_virtual_hosts {
      "my" = {
        extraConfig = ''
          root * ${homePage}
          file_server
        '';
      };
      "adguard" = {
        extraConfig = ''
          reverse_proxy localhost:${toString ADGUARD_PORT}
        '';
      };
      "radarr" = {
        extraConfig = ''
          reverse_proxy ${ips.nas}:7878
        '';
      };
      "bazarr" = {
        extraConfig = ''
          reverse_proxy ${ips.nas}:6767
        '';
      };
      "sonarr" = {
        extraConfig = ''
          reverse_proxy ${ips.nas}:8989
        '';
      };
      "plex" = {
        extraConfig = ''
          reverse_proxy ${ips.nas}:32400
        '';
      };
      "ethernet-switch" = {
        extraConfig = ''
          reverse_proxy ${ips.ethernet_switch}
        '';
      };
      "power" = {
        extraConfig = ''
          reverse_proxy ${ips.nas}:9999
        '';
      };
      "nas" = {
        extraConfig = ''
          reverse_proxy ${ips.nas}:4200
        '';
      };
      "sabnzbd" = {
        extraConfig = ''
          reverse_proxy ${ips.nas}:8080
        '';
      };
      "homebridge" = {
        extraConfig = ''
          reverse_proxy ${ips.octo}:8581
        '';
      };
      "octoprint" = {
        extraConfig = ''
          reverse_proxy ${ips.octo}:1080
        '';
      };
      "home-assistant" = {
        extraConfig = ''
          reverse_proxy ${ips.octo}:8123
        '';
      };
      "paperless" = {
        extraConfig = ''
          reverse_proxy ${ips.nas}:8000
        '';
      };
      "jellyfin" = {
        extraConfig = ''
          reverse_proxy ${ips.nas}:8096
        '';
      };
    };
  };

  systemd.services.caddy = {
    serviceConfig = {
      # CF_API_TOKEN=XXX
      EnvironmentFile = config.age.secrets.cloudflare.path;
    };
  };
}
