# Generated by nix4vscode
# See https://github.com/nix-community/nix-vscode-extensions/issues/47
# cd ~/Projects/nix4vscode
# nix run "nixpkgs#cargo" run my.toml | fish_clipboard_copy
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
  (merge
    (merge
      (merge
        {
          "github"."copilot" = vscode-utils.extensionFromVscodeMarketplace {
            name = "copilot";
            publisher = "github";
            version = "1.252.0";
            sha256 = "0i610aly3slv9akjv0gsm1vf8s94zwncdkrgzz4nv73cw3h6lp5x";
          };
          "github"."copilot-chat" = vscode-utils.extensionFromVscodeMarketplace {
            name = "copilot-chat";
            publisher = "github";
            version = "0.24.2024121201";
            sha256 = "14cs1ncbv0fib65m1iv6njl892p09fmamjkfyxrsjqgks2hisz5z";
          };
        }
        (
          lib.attrsets.optionalAttrs (isLinux && (isi686 || isx86_64)) {
            "ms-python"."python" = vscode-utils.extensionFromVscodeMarketplace {
              name = "python";
              publisher = "ms-python";
              version = "2024.23.2024121301";
              sha256 = "0rmqilxg8wd8nzskny10k6z903x30mwjix9anbyjg5kc23436li5";
              arch = "linux-x64";
            };
          }
        )
      )
      (
        lib.attrsets.optionalAttrs (isLinux && (isAarch32 || isAarch64)) {
          "ms-python"."python" = vscode-utils.extensionFromVscodeMarketplace {
            name = "python";
            publisher = "ms-python";
            version = "2024.23.2024121301";
            sha256 = "0wl66ylvfd35zj42akg6vlmrb9z9xnqiarha0w9cjzhcxbslzawl";
            arch = "linux-arm64";
          };
        }
      )
    )
    (
      lib.attrsets.optionalAttrs (isDarwin && (isi686 || isx86_64)) {
        "ms-python"."python" = vscode-utils.extensionFromVscodeMarketplace {
          name = "python";
          publisher = "ms-python";
          version = "2024.23.2024121301";
          sha256 = "1fb0zfg0l6x38rbdaa3k07znc2jj4i1g99rqpc5ka60hn1qz5sma";
          arch = "darwin-x64";
        };
      }
    )
  )
  (
    lib.attrsets.optionalAttrs (isDarwin && (isAarch32 || isAarch64)) {
      "ms-python"."python" = vscode-utils.extensionFromVscodeMarketplace {
        name = "python";
        publisher = "ms-python";
        version = "2024.23.2024121301";
        sha256 = "1sazzalri80rawispqc52f4v5gjzqrhamfclajmqq0d58i7ap0bp";
        arch = "darwin-arm64";
      };
    }
  )
