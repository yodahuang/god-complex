# Copied from https://github.com/NixOS/nixpkgs/issues/152343#issuecomment-1367069827
{
  lib,
  fetchzip,
  fetchFromGitHub,
  writeTextFile,
  runCommandLocal,
  symlinkJoin,
}: let
  homer_icons = fetchFromGitHub {
    owner = "NX211";
    repo = "homer-icons";
    rev = "691dc315413a0b644ffbd3b9702f63ebb53a36a5";
    sha256 = "sha256-rRGdRPkUPPv7pvIkRl9+XT0EfjD8PNrUGwizycG4KrA=";
  };
  homer_v2_theme = fetchFromGitHub {
    owner = "walkxcode";
    repo = "homer-theme";
    rev = "88f17f2";
    sha256 = "sha256-Oj0PGa70VxSwxg0AtIla+OHmbDHVXXg0qHebssDyiP8=";
  };
  homer = fetchzip rec {
    pname = "homer";
    version = "24.10.2";
    url = "https://github.com/bastienwirtz/${pname}/releases/download/v${version}/${pname}.zip";
    hash = "sha256-V4E/KLOzfiCMwdQrXzab2VzjuB0TYpocoYhdUVt4g78=";
    stripRoot = false;

    passthru = {
      withAssets = {
        name ? null,
        config,
        extraAssets ? [],
      }: let
        nameSuffix = lib.optionalString (name != null) "-${name}";
      in
        symlinkJoin {
          name = "homer-root${nameSuffix}";
          paths =
            [
              homer
              # Config file.
              (writeTextFile {
                name = "homer-configuration${nameSuffix}";
                text = builtins.toJSON config;
                destination = "/assets/config.yml";
              })
              # Homer icon.
              (runCommandLocal "homer-icons${nameSuffix}" {} ''
                mkdir -p $out/assets/
                ln -s ${homer_icons} $out/assets/homer-icons
              '')
              # Homer theme.
              (
                let
                  theme_assets = "${homer_v2_theme}/assets";
                in
                  # Copy the important ones.
                  runCommandLocal "homer-theme${nameSuffix}" {} (
                    builtins.concatStringsSep "\n" (
                      ["mkdir -p $out/assets/"]
                      ++ (map (filename: "ln -s ${theme_assets}/${filename} $out/assets") [
                        "fonts"
                        "custom.css"
                        "wallpaper-light.jpeg"
                        "wallpaper.jpeg"
                      ])
                    )
                  )
              )
            ]
            ++ lib.optional (extraAssets != []) (
              runCommandLocal "homer-assets${nameSuffix}" {} (
                builtins.concatStringsSep "\n" (
                  map (asset: ''
                    mkdir -p $out/assets/${dirOf asset}
                    ln -s ${asset} $out/assets/${asset}
                  '')
                  extraAssets
                )
              )
            );
        };
    };
  };
in
  homer
