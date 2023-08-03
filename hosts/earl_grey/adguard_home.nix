{ config, pkgs, ... }:

let
  # Copied from https://github.com/expipiplus1/dotfiles/blob/219ca0c29e7dc7bd05f0cf3dae8f4b4e7d0afc7c/config/nixpkgs/home/alacritty.nix#
  # Which is probably copied from
  # https://github.com/cdepillabout/stacklock2nix/blob/292fe5d9b9298234ea783157f5698ff925dd325c/nix/build-support/stacklock2nix/read-yaml.nix
  # Now I feel like a script kiddo.
  readYaml = path:
  let
    jsonOutputDrv =
      pkgs.runCommand "from-yaml" { nativeBuildInputs = [ pkgs.remarshal ]; }
      ''remarshal -if yaml -i "${path}" -of json -o "$out"'';
  in builtins.fromJSON (builtins.readFile jsonOutputDrv);

in {
  services.adguardhome = {
    enable = true;
    settings = readYaml ./configs/adguard_home.yaml;
  };
  
}