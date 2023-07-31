{ config, pkgs, lib, flake-inputs, is_darwin, ... }:

{
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
    extensions = with pkgs.vscode-extensions; [
      asvetliakov.vscode-neovim
      rust-lang.rust-analyzer
      jnoortheen.nix-ide
      eamodio.gitlens
      catppuccin.catppuccin-vsc-icons
      catppuccin.catppuccin-vsc
      github.copilot
      mattn.lisp
    ];
    userSettings = {
      "nix.enableLanguageServer" = true;
      "nix.serverPath" = "nil";
      "nix.formatterPath" = "nixfmt";
      "workbench.iconTheme" = "catppuccin-frappe";
      "workbench.colorTheme" = "Catppuccin Macchiato";
      "editor.formatOnSave" = true;
      "editor.inlineSuggest.enabled" = true;
      "editor.fontFamily" =
        "'Comic Mono','Droid Sans Mono', 'monospace', monosspace";
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