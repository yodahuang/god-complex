# Copied from https://github.com/NixOS/nixpkgs/issues/152343#issuecomment-1367069827
{ lib, fetchzip, fetchFromGitHub, writeTextFile, runCommandLocal, symlinkJoin }:

let
  homer_icons = fetchFromGitHub {
    owner = "NX211";
    repo = "homer-icons";
    rev = "fbf21fb";
    sha256 = "sha256-rRGdRPkUPPv7pvIkRl9+XT0EfjD8PNrUGwizycG4KrA=";
  };
  homer = fetchzip rec {
    pname = "homer";
    version = "23.05.1";
    url =
      "https://github.com/bastienwirtz/${pname}/releases/download/v${version}/${pname}.zip";
    hash = "sha256-pYVbJ+7i4K3QWRYxVd2tu/aQ3FgfhGH6VM2ZRils53c=";
    stripRoot = false;

    passthru = {
      withAssets = { name ? null, config, extraAssets ? [ ] }:
        let
          nameSuffix = lib.optionalString (name != null) "-${name}";
          mergedAssets = extraAssets ++ [ homer_icons ];
        in symlinkJoin {
          name = "homer-root${nameSuffix}";
          paths = [
            homer
            (writeTextFile {
              name = "homer-configuration${nameSuffix}";
              text = builtins.toJSON config;
              destination = "/assets/config.yml";
            })
          ] ++ lib.optional (mergedAssets!= [ ])
            (runCommandLocal "homer-assets${nameSuffix}" { }
              (builtins.concatStringsSep "\n" (map (asset: ''
                mkdir -p $out/assets/${dirOf asset}
                ln -s ${asset} $out/assets/${asset}
              '') mergedAssets)));
        };
    };
  };
in homer