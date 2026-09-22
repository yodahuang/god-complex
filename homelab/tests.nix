{lib}: let
  inventory = import ./inventory.nix;
  homelab = import ./lib.nix {inherit lib;};
  validated = homelab.validate inventory;

  failsValidation = candidate: let
    result = builtins.tryEval (homelab.validate candidate);
  in
    !result.success;

  duplicateIPInventory =
    inventory
    // {
      nodes =
        inventory.nodes
        // {
          duplicate =
            inventory.nodes.nas
            // {
              displayName = "Duplicate NAS";
            };
        };
    };

  duplicateServiceInventory =
    inventory
    // {
      services =
        inventory.services
        ++ [
          {
            id = "notifiarr";
            name = "Duplicate Notifiarr";
            node = "nas";
            port = 5454;
            caddy = {kind = "reverseProxy";};
          }
        ];
    };

  missingDashboardServiceInventory =
    inventory
    // {
      dashboard =
        inventory.dashboard
        // {
          categories = [
            {
              name = "Broken";
              icon = "fas fa-bug";
              serviceIds = ["does-not-exist"];
            }
          ];
        };
    };
in {
  all = assert (homelab.serviceUrl validated (homelab.serviceById validated).notifiarr == "https://notifiarr.int.yanda.rocks");
  assert (validated.meta.publicZone == "yanda.rocks");
  assert (homelab.backendTarget validated (homelab.serviceById validated).notifiarr == "192.168.1.168");
  assert (builtins.length (homelab.localDnsRecords validated) == 1);
  assert ((builtins.head (homelab.localDnsRecords validated)).hostname == "*.int.yanda.rocks");
  assert ((builtins.head (homelab.localDnsRecords validated)).targetNode == "earl_grey");
  assert (builtins.length (homelab.publicDnsIntent validated) == 1);
  assert ((builtins.head (homelab.publicDnsIntent validated)).hostname == "*.int.yanda.rocks");
  assert ((builtins.head (homelab.publicDnsIntent validated)).addressSource == "tailscale");
  assert (failsValidation duplicateIPInventory);
  assert (failsValidation duplicateServiceInventory);
  assert (failsValidation missingDashboardServiceInventory); true;
}
