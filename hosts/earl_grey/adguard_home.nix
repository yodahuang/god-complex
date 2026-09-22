{
  config,
  pkgs,
  lib,
  ...
}: let
  inventory = import ../../homelab/inventory.nix;
  homelab = import ../../homelab/lib.nix {inherit lib;};
  validatedInventory = homelab.validate inventory;
  ingressIPv4 = validatedInventory.nodes.${validatedInventory.meta.ingressNode}.lan.desiredIPv4;
  ADGUARD_PORT = 1080;
in {
  services.adguardhome = {
    enable = true;
    mutableSettings = false;
    openFirewall = true;
    host = "0.0.0.0";
    port = ADGUARD_PORT;
    settings = {
      http = {address = "0.0.0.0:1080";};
      dns = {
        bind_hosts = ["0.0.0.0"];
        port = 53;
        bootstrap_dns = ["9.9.9.10" "149.112.112.10" "2620:fe::10" "2620:fe::fe:10"];
        upstream_dns = ["https://dns.cloudflare.com/dns-query"];
        rewrites = [
          {
            domain = "*.home";
            # AdGuard is not the household resolver anymore, but keep its
            # dormant local rewrite aligned with the shared inventory.
            answer = ingressIPv4;
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
}
