{ config, pkgs, lib, flake-inputs, is_darwin, ... }:
let
  vscode_extensions =
    flake-inputs.nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace;
in {
  fonts.fontconfig.enable = true;

  home.packages = with pkgs;
    [
      # Fonts
      comic-mono
      jetbrains-mono
      (nerdfonts.override { fonts = [ "Meslo" ]; })
      # Apps
      obsidian
      discord
    ] ++ lib.optionals (!is_darwin) [ logseq ventoy ];

  programs.kitty = {
    enable = true;
    font = {
      name = "Meslo";
      size = 16;
    };
    theme = "Catppuccin-Macchiato";
    settings = {
      background_opacity = "0.8";
      background_blur = 64;
    };
  };

  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions;
      [
        # Look
        catppuccin.catppuccin-vsc-icons
        catppuccin.catppuccin-vsc
      ] ++ (with vscode_extensions; [
        # General
        ms-vscode-remote.remote-ssh
        asvetliakov.vscode-neovim
        eamodio.gitlens
        github.copilot
        # Tools
        mkhl.direnv
        # Languages
        jnoortheen.nix-ide
        mattn.lisp
        tamasfe.even-better-toml
        rust-lang.rust-analyzer
        ms-python.python
        ms-python.vscode-pylance
        charliermarsh.ruff
        # Fun
        hoovercj.vscode-power-mode
        tonybaloney.vscode-pets
      ]);
    userSettings = {
      "nix.enableLanguageServer" = true;
      "nix.serverPath" = "nil";
      "nix.serverSettings" = {
        nil = { formatting = { command = [ "nixfmt" ]; }; };
      };
      "workbench.iconTheme" = "catppuccin-frappe";
      "workbench.colorTheme" = "Catppuccin Macchiato";
      "editor.formatOnSave" = true;
      "editor.inlineSuggest.enabled" = true;
      "editor.fontFamily" =
        "'Comic Mono','Droid Sans Mono', 'monospace', monosspace";
      "editor.fontSize" = 16;
      "remote.SSH.useLocalServer" = false;
      "remote.SSH.remotePlatform" = {
        "earl_grey" = "linux";
        "rig" = "linux";
        "octo" = "linux";
      };
      "extensions.autoUpdate" = false;
      "extensions.autoCheckUpdates" = false;
      "extensions.experimental.affinity" = { "asvetliakov.vscode-neovim" = 1; };
      "[python]" = {
        "editor.formatOnSave" = true;
        "editor.defaultFormatter" = "charliermarsh.ruff";
        "editor.codeActionsOnSave" = { "source.organizeImports" = true; };
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
      ];
      search.engines = {
        "Kagi" = {
          urls = [{ template = "https://kagi.com/search?q={searchTerms}"; }];
        };
      };
    };
  };

}
