{ pkgs, ... }:

pkgs.homer.withAssets {
  name = "homelab";
  config = {
    title = "Yanda's home dashboard";
    subtitle = "Hey hey";
    logo = "logo.png";
    # These colors and stuff are from https://github.com/walkxcode/homer-theme/blob/88f17f2eaaffe6466c3d940c6f15b41a6e255bd2/assets/config.yml
    stylesheet = [ "assets/custom.css" ];
    columns = "3";
    theme = "default";
    colors = {
      light = {
        "highlight-primary" = "#fff5f2";
        "highlight-secondary" = "#fff5f2";
        "highlight-hover" = "#bebebe";
        background = "#12152B";
        "card-background" = "rgba(255, 245, 242, 0.8)";
        text = "#ffffff";
        "text-header" = "#fafafa";
        "text-title" = "#000000";
        "text-subtitle" = "#111111";
        "card-shadow" = "rgba(0, 0, 0, 0.5)";
        link = "#3273dc";
        "link-hover" = "#2e4053";
        "background-image" = "../assets/wallpaper-light.jpeg";
      };
      dark = {
        "highlight-primary" = "#181C3A";
        "highlight-secondary" = "#181C3A";
        "highlight-hover" = "#1F2347";
        background = "#12152B";
        "card-background" = "rgba(24, 28, 58, 0.8)";
        text = "#eaeaea";
        "text-header" = "#7C71DD";
        "text-title" = "#fafafa";
        "text-subtitle" = "#8B8D9C";
        "card-shadow" = "rgba(0, 0, 0, 0.5)";
        link = "#c1c1c1";
        "link-hover" = "#fafafa";
        "background-image" = "../assets/wallpaper.jpeg";
      };
    };
    services = [
      {
        name = "Theatre";
        icon = "fas fa-couch";
        items = [
          {
            name = "Radarr";
            logo = "assets/homer-icons/png/radarr.png";
            subtitle = "Get movies";
            url = "http://radarr.home";
          }
          {
            name = "Sonarr";
            logo = "assets/homer-icons/png/sonarr.png";
            url = "http://sonarr.home";
          }
          {
            name = "Bazarr";
            logo = "assets/homer-icons/png/bazarr.png";
            subtitle = "Get Subtitles";
            url = "http://bazarr.home";
          }
          {
            name = "Plex";
            logo = "assets/homer-icons/png/plex.png";
            subtitle = "Plex server";
          }
        ];
      }
      {
        name = "Home management";
        icon = "fas fa-home";
        items = [
          {
            name = "Home Assistnat";
            logo = "assets/homer-icons/png/home-assistant.png";
            subtitle = "One place to store them all";
            url = "http://home-assistant.home";
          }
          {
            name = "HomeBridge";
            logo = "assets/homer-icons/png/homebridge.png";
            subtitle = "Username and password are both admin";
            url = "http://homebridge.home";
          }
          {
            name = "Phoscon (deCONZ)";
            logo = "assets/icons/phoscon.svg";
            subtitle = "All Zigbee stuff";
            url = "http://phoscon.home";
          }
          {
            name = "AdGuard Home";
            logo = "assets/homer-icons/png/adguardhome.png";
            subtitle = "Block ads and trackings";
            url = "http://adguard.home";
          }
          {
            name = "Ethernet Switch";
            icon = "fas fa-ethernet";
            subtitle = "TP-Link switch";
            url = "http://ethernet-switch.home";
          }
        ];
      }
      {
        name = "Books";
        icon = "fas fa-book";
        items = [
          {
            name = "Calibre";
            logo = "assets/homer-icons/png/calibreweb.png";
            subtitle = "Manage books";
            url = "http://calibre.home";
          }
          {
            name = "Readarr";
            logo = "assets/homer-icons/png/readarr.png";
            subtitle = "Get more books";
            url = "http://readarr.home";
          }
        ];
      }
      {
        name = "Admin";
        icon = "fas fa-user-cog";
        items = [{
          name = "Portainer";
          logo = "assets/homer-icons/png/portainer.png";
          subtitle = "Manage all the containers";
          url = "http://portainer.home";
        }];
      }
      {
        name = "Misc";
        icon = "fas fa-dumpster";
        items = [
          {
            name = "NAS";
            logo = "assets/homer-icons/png/synology.png";
            subtitle = "One NAS to host them all";
            url = "http://nas.home";
          }
          {
            name = "OctoPrint";
            logo = "assets/homer-icons/png/octoprint.png";
            subtitle = "Control 3D printer with ease";
            url = "http://octoprint.home";
          }
          {
            name = "Sabnzbd";
            logo = "assets/homer-icons/png/sabnzbd.png";
            subtitle = "Download manager";
            url = "http://sabnzbd.home";
          }
        ];
      }
    ];
  };
  extraAssets = [
    /* Any extra assets (such as icons) to include.
       /* These can be referenced through "assets/" in the Homer configuration.
    */
  ];
}
