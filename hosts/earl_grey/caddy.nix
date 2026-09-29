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

  # Mirror the development proxies (vue.config.js) so the production PWA has
  # transports for the Pixiv APIs: strip browser-only headers, present the
  # Android app user agent, and forward the rest untouched. Pixiv images also
  # require a pixiv.net referer, which a browser cannot send.
  pixivAppUserAgent = "PixivAndroidApp/6.180.0 (Android 15; Pixel 9)";
  browserOnlyHeaders = [
    "Origin"
    "Referer"
    "Cookie"
    "Sec-Fetch-Site"
    "Sec-Fetch-Mode"
    "Sec-Fetch-Dest"
    "Sec-Ch-Ua"
    "Sec-Ch-Ua-Mobile"
    "Sec-Ch-Ua-Platform"
    "If-None-Match"
    "If-Modified-Since"
  ];
  proxyPolicies = {
    pixivApp = {
      headers = {
        User-Agent = pixivAppUserAgent;
        Accept = "application/json";
        Accept-Language = "zh-CN";
      };
      removeHeaders = browserOnlyHeaders;
    };
    pixivImage = {
      headers = {
        User-Agent = pixivAppUserAgent;
        Referer = "https://www.pixiv.net/";
        Accept = "image/avif,image/webp,image/apng,image/*,*/*;q=0.8";
      };
      removeHeaders = builtins.filter (name: name != "Referer") browserOnlyHeaders;
    };
  };
  staticSiteProxies = proxies:
    lib.concatMapStrings (proxy: let
      policy = proxyPolicies.${proxy.kind};
      headerLines = lib.concatStringsSep "\n          " (
        lib.mapAttrsToList (name: value: "header_up ${name} \"${value}\"") policy.headers
        ++ map (name: "header_up -${name}") policy.removeHeaders
      );
    in ''
      handle_path ${proxy.path} {
        reverse_proxy ${proxy.upstream} {
          header_up Host ${proxy.host}
          ${headerLines}
        }
      }
    '')
    proxies;

  extraConfig = service:
    if service.caddy.kind == "homepage"
    then ''
      root * ${homePage}
      file_server
    ''
    else if service.caddy.kind == "pages"
    then pagesConfig
    else if service.caddy.kind == "staticSite"
    then ''
      encode gzip zstd

      ${staticSiteProxies (service.caddy.proxies or [])}handle {
        root * ${staticSiteRoot service}
        try_files {path} /index.html
        file_server
      }
    ''
    else let
      backend = homelab.backendTarget validatedInventory service;
      upstream = "${backend}:${toString service.port}";
    in
      if service.caddy.setHostToBackend or false
      then ''
        reverse_proxy ${upstream} {
          header_up Host ${backend}
        }
      ''
      else ''
        reverse_proxy ${upstream}
      '';

  # A Nix-built bundle can replace the Dufs-managed directory for a static
  # site. The override is keyed by service ID and must be a store path.
  staticSiteRoot = service:
    config.services.caddy.staticSiteRoots.${service.id}
    or "/var/lib/static-sites/${service.caddy.site}";

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
  options.services.caddy.staticSiteRoots = lib.mkOption {
    type = lib.types.attrsOf lib.types.package;
    default = {};
    description = ''
      Document roots for services of kind "staticSite", keyed by service ID.
      The package's store path replaces the default Dufs-managed
      /var/lib/static-sites/<site> directory.
    '';
  };

  config = {
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
  };
}
