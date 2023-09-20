{ config, pkgs, lib, flake-inputs, is_darwin, ... }: {
  fonts.fontconfig.enable = true;

  home.packages = with pkgs;
    [
      # Fonts
      comic-mono
      jetbrains-mono
      (nerdfonts.override { fonts = [ "Meslo" ]; })
      # Apps
      obsidian
    ] ++ lib.optionals (!is_darwin) [ logseq ventoy ];

  programs.kitty = { enable = true; };

  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions;
      [
        ms-vscode-remote.remote-ssh
        asvetliakov.vscode-neovim
        eamodio.gitlens
        catppuccin.catppuccin-vsc-icons
        catppuccin.catppuccin-vsc
        github.copilot
        mkhl.direnv
        # Languages
        jnoortheen.nix-ide
        mattn.lisp
        tamasfe.even-better-toml
        rust-lang.rust-analyzer
        ms-python.python
      ]
      ++ (with flake-inputs.nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace;
        [ charliermarsh.ruff ]);
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
