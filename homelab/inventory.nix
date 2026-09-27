{
  meta = {
    localDomain = "home";
    publicDomain = "int.yanda.rocks";
    publicZone = "yanda.rocks";
    ingressNode = "earl_grey";
    # Node whose DSM OpenTofu talks to (homelab/opentofu/synology.tf).
    nasNode = "nas";
    # DSM HTTPS port (DSM's web UI is moved off 5001 here).
    dsmPort = 4201;
    unifiSite = "default";
  };

  # These are the networks known to the inventory.  The gateway for the IoT
  # network is intentionally left out until it is confirmed from UniFi.
  networks = {
    home = {
      cidr = "192.168.1.0/24";
      gateway = "192.168.1.1";
      # UniFi's internal network ID used by the fixed-IP client endpoint.
      unifiId = "68831ebb83b606252f6bf0ae";
    };
    iot = {
      cidr = "192.168.4.0/24";
    };
  };

  # This is desired state, not a copy of live DHCP or Tailscale observations.
  # reservationMac is the hardware identity UniFi uses for a fixed-IP record;
  # null means the device has not been safely identified yet.
  nodes = {
    earl_grey = {
      displayName = "Earl Grey";
      lan = {
        network = "home";
        desiredIPv4 = "192.168.1.46";
        reservationMac = "e4:5f:01:67:99:1c";
      };
      tailscale = {
        enabled = true;
        selector = "EarlGrey";
      };
    };
    studio = {
      displayName = "Studio";
      lan = {
        network = "home";
        desiredIPv4 = "192.168.1.143";
        reservationMac = "a4:fc:14:00:c1:b3";
      };
      tailscale = {
        enabled = false;
      };
    };
    nas = {
      displayName = "NAS";
      lan = {
        network = "home";
        desiredIPv4 = "192.168.1.168";
        reservationMac = "00:11:32:de:0e:bd";
      };
      tailscale = {
        # Managed by Synology, not Nix; Tailscale machine name is "dumpster".
        enabled = true;
        selector = "dumpster";
      };
    };
    octo = {
      displayName = "OctoPrint";
      lan = {
        network = "iot";
        desiredIPv4 = "192.168.4.153";
        reservationMac = null;
      };
      tailscale = {
        enabled = false;
      };
    };
    rig = {
      displayName = "Rig";
      lan = {
        network = "home";
        desiredIPv4 = "192.168.1.124";
        reservationMac = "04:d9:f5:f4:e6:f1";
      };
      tailscale = {
        enabled = true;
        selector = "Rig";
      };
    };
    heos = {
      displayName = "HEOS";
      lan = {
        network = "home";
        desiredIPv4 = "192.168.1.198";
        reservationMac = null;
      };
      tailscale = {
        enabled = false;
      };
    };
  };

  # Services are defined once.  Caddy and Homer derive their hostnames and
  # URLs from this list, so a backend host/IP is never repeated in either UI
  # configuration.
  services = [
    {
      id = "my";
      name = "Dashboard";
      node = "earl_grey";
      caddy = {kind = "homepage";};
    }
    {
      id = "hermes";
      name = "Hermes Agent";
      node = "studio";
      port = 9119;
      caddy = {
        kind = "reverseProxy";
        setHostToBackend = true;
      };
      dashboard = {
        category = "Agents";
        icon = "fas fa-robot";
        subtitle = "Web console and message bridge";
      };
    }
    {
      id = "pages";
      name = "Static Sites";
      node = "earl_grey";
      caddy = {kind = "pages";};
      dashboard = {
        category = "Misc";
        icon = "fas fa-globe";
        subtitle = "Upload and manage family sites";
      };
    }
    {
      id = "adguard";
      name = "AdGuard Home";
      node = "earl_grey";
      port = 1080;
      caddy = {kind = "reverseProxy";};
      dashboard = {
        category = "Home management";
        logo = "assets/homer-icons/png/adguardhome.png";
      };
    }
    {
      id = "radarr";
      name = "Radarr";
      node = "nas";
      port = 7878;
      caddy = {kind = "reverseProxy";};
      dashboard = {
        category = "Theatre";
        logo = "assets/homer-icons/png/radarr.png";
        subtitle = "Get movies";
      };
    }
    {
      id = "bazarr";
      name = "Bazarr";
      node = "nas";
      port = 6767;
      caddy = {kind = "reverseProxy";};
      dashboard = {
        category = "Theatre";
        logo = "assets/homer-icons/png/bazarr.png";
        subtitle = "Get subtitles";
      };
    }
    {
      id = "sonarr";
      name = "Sonarr";
      node = "nas";
      port = 8989;
      caddy = {kind = "reverseProxy";};
      dashboard = {
        category = "Theatre";
        logo = "assets/homer-icons/png/sonarr.png";
      };
    }
    {
      id = "plex";
      name = "Plex";
      node = "nas";
      port = 32400;
      caddy = {kind = "reverseProxy";};
      dashboard = {
        category = "Theatre";
        logo = "assets/homer-icons/png/plex.png";
        subtitle = "Movies";
      };
    }
    {
      id = "jellyfin";
      name = "Jellyfin";
      node = "nas";
      port = 8096;
      caddy = {kind = "reverseProxy";};
      dashboard = {
        category = "Theatre";
        logo = "assets/homer-icons/png/jellyfin.png";
        subtitle = "Vlogs";
      };
    }
    {
      id = "home-assistant";
      name = "Home Assistant";
      node = "octo";
      port = 8123;
      caddy = {kind = "reverseProxy";};
      dashboard = {
        category = "Home management";
        logo = "assets/homer-icons/png/home-assistant.png";
        subtitle = "One place to store them all";
      };
    }
    {
      id = "homebridge";
      name = "HomeBridge";
      node = "earl_grey";
      port = 8581;
      caddy = {kind = "reverseProxy";};
      dashboard = {
        category = "Home management";
        logo = "assets/homer-icons/png/homebridge.png";
        subtitle = "Username and password are both admin";
      };
    }
    {
      id = "nas";
      name = "NAS";
      node = "nas";
      port = 4200;
      caddy = {kind = "reverseProxy";};
      dashboard = {
        category = "Misc";
        logo = "assets/homer-icons/png/synology.png";
        subtitle = "One NAS to host them all";
      };
    }
    {
      id = "notifiarr";
      name = "Notifiarr";
      node = "nas";
      port = 5454;
      caddy = {kind = "reverseProxy";};
      dashboard = {
        category = "Misc";
        icon = "fas fa-bell";
        subtitle = "Notification settings";
      };
    }
    {
      id = "paperless";
      name = "Paperless";
      node = "nas";
      port = 8000;
      caddy = {kind = "reverseProxy";};
      dashboard = {
        category = "Misc";
        logo = "assets/homer-icons/png/paperless-ng.png";
        subtitle = "The (not) paperless docs";
      };
    }
    {
      id = "octoprint";
      name = "OctoPrint";
      node = "octo";
      port = 1080;
      caddy = {kind = "reverseProxy";};
      dashboard = {
        category = "Misc";
        logo = "assets/homer-icons/png/octoprint.png";
        subtitle = "Control 3D printer with ease";
      };
    }
    {
      id = "sabnzbd";
      name = "SABnzbd";
      node = "nas";
      port = 8080;
      caddy = {kind = "reverseProxy";};
      dashboard = {
        category = "Misc";
        logo = "assets/homer-icons/png/sabnzbd.png";
        subtitle = "Download manager";
      };
    }
    {
      id = "power";
      name = "Power";
      node = "nas";
      port = 9999;
      caddy = {kind = "reverseProxy";};
    }
    {
      id = "chocolate";
      name = "Chocolate";
      node = "earl_grey";
      port = 8000;
      caddy = {kind = "reverseProxy";};
      dashboard = {
        category = "Misc";
        icon = "fas fa-table-cells";
        subtitle = "Vestaboard controller";
      };
    }
  ];

  dashboard = {
    categories = [
      {
        name = "Theatre";
        icon = "fas fa-couch";
        serviceIds = ["radarr" "sonarr" "bazarr" "plex" "jellyfin"];
      }
      {
        name = "Home management";
        icon = "fas fa-home";
        serviceIds = ["home-assistant" "homebridge" "adguard"];
      }
      {
        name = "Agents";
        icon = "fas fa-robot";
        serviceIds = ["hermes"];
      }
      {
        name = "Misc";
        icon = "fas fa-dumpster";
        serviceIds = [
          "nas"
          "notifiarr"
          "paperless"
          "octoprint"
          "sabnzbd"
          "chocolate"
          "pages"
        ];
      }
    ];
  };
}
