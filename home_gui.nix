{
  config,
  pkgs,
  lib,
  flake-inputs,
  ...
}: let
  pkgs-ext = import flake-inputs.nixpkgs {
    inherit (pkgs) system;
    config.allowUnfree = true;
    overlays = [flake-inputs.nix-vscode-extensions.overlays.default];
  };
  vscode_marketplace = (pkgs-ext.forVSCodeVersion "1.99.1").vscode-marketplace;
  vscode_marketplace_release = pkgs-ext.vscode-marketplace-release;
  is_darwin = pkgs.stdenv.isDarwin;
in {
  fonts.fontconfig.enable = true;

  home.packages = with pkgs;
    [
      # Fonts
      comic-mono
      jetbrains-mono
      nerd-fonts.meslo-lg
      # Apps
      obsidian
      discord
    ]
    ++ lib.optionals (!is_darwin) [
      logseq
      ventoy
    ];

  programs.kitty = {
    enable = true;
    font = {
      name = "Meslo";
      size = 16;
    };
    # theme = "Catppuccin-Macchiato";
    settings = {
      background_opacity = "0.8";
      background_blur = 64;
    };
  };

  programs.vscode = {
    enable = true;
    extensions = with vscode_marketplace;
      [
        # Look
        sainnhe.gruvbox-material
        jonathanharty.gruvbox-material-icon-theme
        catppuccin.catppuccin-vsc-icons
        catppuccin.catppuccin-vsc
        # General
        ms-vscode-remote.remote-ssh
        asvetliakov.vscode-neovim
        eamodio.gitlens
        # Tools
        mkhl.direnv
        # Languages
        jnoortheen.nix-ide
        mattn.lisp
        tamasfe.even-better-toml
        rust-lang.rust-analyzer
        ms-python.vscode-pylance
        ms-python.python
        charliermarsh.ruff
        # Fun
        hoovercj.vscode-power-mode
        tonybaloney.vscode-pets
        # Markdown
        streetsidesoftware.code-spell-checker
      ]
      ++ (with vscode_marketplace_release; [
        # CoPilot
        github.copilot-chat
        github.copilot
      ]);
    userSettings = {
      "nix.enableLanguageServer" = true;
      "nix.serverPath" = "nil";
      "nix.serverSettings" = {
        nil = {
          formatting = {
            command = ["alejandra" "--quiet" "--"];
          };
        };
      };
      "workbench.iconTheme" = "catppuccin-frappe";
      "workbench.colorTheme" = "Catppuccin Macchiato";
      "editor.formatOnSave" = true;
      "editor.inlineSuggest.enabled" = true;
      "editor.fontFamily" = "'Comic Mono','Droid Sans Mono', 'monospace', monosspace";
      "editor.fontSize" = 16;
      "remote.SSH.useLocalServer" = false;
      "remote.SSH.remotePlatform" = {
        "earl_grey" = "linux";
        "rig" = "linux";
        "octo" = "linux";
      };
      "extensions.autoUpdate" = false;
      "extensions.autoCheckUpdates" = false;
      "extensions.experimental.affinity" = {
        "asvetliakov.vscode-neovim" = 1;
      };
      "[python]" = {
        "editor.defaultFormatter" = "charliermarsh.ruff";
        "editor.codeActionsOnSave" = {
          "source.organizeImports" = "explicit";
        };
      };
    };
  };

  programs.firefox = {
    # https://github.com/NixOS/nixpkgs/issues/71689
    enable = !is_darwin;
    profiles.default = {
      id = 0;
      name = "Default";
      extensions = with pkgs.nur.repos.rycee.firefox-addons; [
        darkreader
        onepassword-password-manager
        ublock-origin
        tampermonkey
      ];
      search = {
        force = true;
        engines = {
          "Kagi" = {
            urls = [{template = "https://kagi.com/search?q={searchTerms}";}];
          };
        };
        default = "Kagi";
      };
    };
  };

  programs.ghostty = {
    # https://github.com/NixOS/nixpkgs/issues/388984
    enable = !is_darwin;
    enableFishIntegration = true;
    installBatSyntax = true;
  };
}
