# Generated by nix4vscode
# See https://github.com/nix-community/nix-vscode-extensions/issues/47
{ pkgs, lib }:

let
  inherit (pkgs.stdenv)
    isDarwin
    isLinux
    isi686
    isx86_64
    isAarch32
    isAarch64
    ;
  vscode-utils = pkgs.vscode-utils;
  merge = lib.attrsets.recursiveUpdate;
in
merge
  (merge (merge
    (merge {
      "ms-python"."python" = vscode-utils.extensionFromVscodeMarketplace {
        name = "python";
        publisher = "ms-python";
        version = "2024.5.11021008";
        sha256 = "11mnnbdl7cqr18s2cvv2132rrq1f5zslnihp5i2jpa2awjak8wjj";
      };
      "github"."copilot" = vscode-utils.extensionFromVscodeMarketplace {
        name = "copilot";
        publisher = "github";
        version = "1.180.827";
        sha256 = "0b3jc5h9gimyqfq87axhdwdskajqy54b9gmc04i144v8s5mnf38w";
      };
      "github"."copilot-chat" = vscode-utils.extensionFromVscodeMarketplace {
        name = "copilot-chat";
        publisher = "github";
        version = "0.14.2024032901";
        sha256 = "11148fibdhl86gaqswvk4rd8dqhxm430ng4qwl7lr3xrcch7p8zv";
      };
    } (lib.attrsets.optionalAttrs (isLinux && (isi686 || isx86_64)) { }))
    (lib.attrsets.optionalAttrs (isLinux && (isAarch32 || isAarch64)) { })
  ) (lib.attrsets.optionalAttrs (isDarwin && (isi686 || isx86_64)) { }))
  (lib.attrsets.optionalAttrs (isDarwin && (isAarch32 || isAarch64)) { })
