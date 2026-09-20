{
  flake-inputs,
  pkgs,
  ...
}: {
  imports = [flake-inputs.static-sites.nixosModules.default];

  services.static-sites = {
    enable = true;
    uiPackage = flake-inputs.static-sites.packages.${pkgs.system}.default;
    stateDirectory = "/var/lib/static-sites";
    listenAddress = "127.0.0.1";
    port = 5000;
  };

  users.users.caddy.extraGroups = ["static-sites"];
}
