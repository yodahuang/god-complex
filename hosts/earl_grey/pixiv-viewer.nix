{
  config,
  flake-inputs,
  pkgs,
  lib,
  ...
}: let
  # Build-time PWA defaults. This repository is public, so no secrets belong
  # here: the semantic translation token is configured per browser in the
  # app's manga translation settings instead. The App API and image proxies
  # are same-origin Caddy routes declared in the homelab inventory.
  buildEnvironment = {
    VUE_APP_SEMANTIC_TRANSLATE_URL = "https://semantic.int.yanda.rocks";
    VUE_APP_DEF_APP_API_PROXY = "pixiv.int.yanda.rocks";
    VUE_APP_APP_API_PROXYS = "pixiv.int.yanda.rocks";
    VUE_APP_DEF_PXIMG_MAIN = "pixiv.int.yanda.rocks/pixiv-image";
  };

  package = pkgs.callPackage "${flake-inputs.pixiv-viewer}/deploy/nix/pixiv-viewer-static.nix" {
    src = flake-inputs.pixiv-viewer;
    inherit buildEnvironment;
  };
in {
  options.services.pixiv-viewer-static.package = lib.mkOption {
    type = lib.types.package;
    description = "Built Pixiv Viewer Kai static bundle served by Caddy.";
  };

  config = {
    services.pixiv-viewer-static.package = package;
    # Serve the immutable store path instead of the Dufs-managed directory,
    # so `deploy .#EarlGrey` updates the app atomically.
    services.caddy.staticSiteRoots.pixiv = package;
  };
}
