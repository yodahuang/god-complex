let
  inventory = import ../homelab/inventory.nix;
in
  builtins.mapAttrs (_: node: node.lan.desiredIPv4) inventory.nodes
