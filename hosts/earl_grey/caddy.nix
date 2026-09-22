{
  config,
  flake-inputs,
  pkgs,
  lib,
  ...
}: let
  inventory = import ../../homelab/inventory.nix;
  homelab = import ../../homelab/lib.nix {inherit lib;};
  validatedInventory = homelab.validate inventory;
  homePage = pkgs.callPackage ./homepage.nix {};
  staticSitesUi = flake-inputs.static-sites.packages.${pkgs.system}.default;

  pagesConfig = ''
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

  extraConfig = service:
    if service.caddy.kind == "homepage"
    then ''
      root * ${homePage}
      file_server
    ''
    else if service.caddy.kind == "pages"
    then pagesConfig
    else ''
      reverse_proxy ${homelab.backendTarget validatedInventory service}:${toString service.port}
    '';

  transformToVirtualHosts = services:
    lib.listToAttrs (map (service: {
        name = homelab.caddyHostnames validatedInventory service;
        value = {
          logFormat = "output file ${config.services.caddy.logDir}/access-${service.id}.log";
          extraConfig = extraConfig service;
        };
      })
      services);
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
    # Caddy is the shared ingress. Local clients reach it through UniFi DNS;
    # Tailscale clients use the same hostname through the Tailnet/public DNS
    # path. Backends are selected from the shared inventory above.
    virtualHosts = transformToVirtualHosts validatedInventory.services;
  };

  systemd.services.caddy = {
    serviceConfig = {
      # CF_API_TOKEN=XXX
      EnvironmentFile = config.age.secrets.cloudflare.path;
    };
  };
}
