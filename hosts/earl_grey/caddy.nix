{
  config,
  flake-inputs,
  pkgs,
  lib,
  ...
}: let
  homePage = pkgs.callPackage ./homepage.nix {};
  staticSitesUi = flake-inputs.static-sites.packages.${pkgs.system}.default;
  ips = import ../ips.nix;
  # TODO: Duplicate here.
  ADGUARD_PORT = 1080;
  # Helper functions
  make_hostnames = name: "http://${name}.home, ${name}.int.yanda.rocks";
  # From my custom format to Caddyfile
  transform_to_virtual_hosts = hosts:
    lib.listToAttrs (map (name: let
      hostnames = make_hostnames name;
    in {
      name = hostnames;
      value = {
        logFormat = "output file ${config.services.caddy.logDir}/access-${name}.log";
        extraConfig = hosts.${name}.extraConfig;
      };
    }) (lib.attrNames hosts));
in {
  services.caddy = {
    enable = true;
    package = pkgs.caddy.withPlugins {
      plugins = [
        "github.com/caddy-dns/cloudflare@v0.0.0-20250407183951-bbf79111721a"
      ];
      hash = "sha256-GEM8c8x42iYkDtG1pG4IqTIc9qEgSVOa0cGejn5UT4U=";
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
      "pages" = {
        extraConfig = ''
          request_body {
            max_size 250MB
          }

          redir /admin /admin/ 308
          redir /api /api/ 308

          handle_path /api/* {
            reverse_proxy 127.0.0.1:5000
          }

          handle_path /admin/* {
            root * ${staticSitesUi}
            file_server
          }

          encode gzip zstd
          root * /var/lib/static-sites

          @hidden {
            path_regexp static_sites_hidden (^|/)\\.
          }
          respond @hidden 404

          @spa_missing {
            not file
            not path /api*
            not path /admin*
            path_regexp static_site ^/([^/]+)(?:/.*)?$
          }
          rewrite @spa_missing /{re.static_site.1}/index.html

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
          reverse_proxy localhost:8581
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
      "chocolate" = {
        extraConfig = ''
          reverse_proxy localhost:8000
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
