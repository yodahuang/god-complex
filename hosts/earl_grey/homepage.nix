{
  pkgs,
  lib,
  ...
}: let
  inventory = import ../../homelab/inventory.nix;
  homelab = import ../../homelab/lib.nix {inherit lib;};
  validatedInventory = homelab.validate inventory;
  servicesById = homelab.serviceById validatedInventory;
  dashboardItem = serviceId:
    homelab.dashboardItem validatedInventory servicesById.${serviceId};
in
  pkgs.homer.withAssets {
    name = "homelab";
    config = {
      title = "Yanda's home dashboard";
      subtitle = "Hey hey";
      logo = "logo.png";
      # These colors and stuff are from https://github.com/walkxcode/homer-theme/blob/88f17f2eaaffe6466c3d940c6f15b41a6e255bd2/assets/config.yml
      stylesheet = ["assets/custom.css"];
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
      services =
        map (category: {
          inherit (category) name icon;
          items = map dashboardItem category.serviceIds;
        })
        validatedInventory.dashboard.categories;
    };
    extraAssets = [
      /*
      Any extra assets (such as icons) to include.
      /* These can be referenced through "assets/" in the Homer configuration.
      */
    ];
  }
