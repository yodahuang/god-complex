{ config, pkgs, flake-inputs, ... }:

{
  imports = [
    flake-inputs.nix-doom-emacs.hmModule
  ];

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "yanda";
  home.homeDirectory = "/Users/yanda";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.05";

  # manual building is failing for me
  manual.manpages.enable = false;

  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    # Common util
    neofetch
    ripgrep
    exa
    fzf
    btop
    flake-inputs.devenv.packages.${system}.devenv
    # Nix specific
    nil
    nixfmt
    # Fonts
    comic-mono
    jetbrains-mono
    (nerdfonts.override { fonts = [ "Meslo" ]; })
    # Apps
    obsidian
    # logseq need to be per-platform
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    userName = "Yanda Huang";
    userEmail = "realyanda@hey.com";
  };

  programs.kitty = {
    enable = true;
  };

  programs.fish = {
    enable = true;
    plugins = with pkgs.fishPlugins; [
      { name = "tide"; src = tide.src; }
      { name = "fzf-fish"; src = fzf-fish.src; }
      { name = "done"; src = done.src; }
    ];
  };

  # Define Emacs service at system level

  programs.doom-emacs = {
    enable = true;
    doomPrivateDir = ./doom.d; # Directory containing your config.el, init.el and packages.el files
    # Getting a working emacs shouldn't be this hard
    # https://github.com/NixOS/nixpkgs/issues/127902
    # The macport patch uses llvm 6, and upgrading it causes several segfaults.
    # emacsPackage = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.emacs-macport else pkgs.emacs;
    emacsPackage = pkgs.emacs;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.ssh = {
    enable = true;
    matchBlocks = {
      "*" = {
        extraOptions = {
          # 1Password agent. May need to change with new installation.
          IdentityAgent = "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
        };
      };
      # Hardcoding the local ip here instead of using Tailscale ones.
      "octo" = {
        hostname = "192.168.4.153";
        user = "pi";
      };
      "pi" = {
        hostname = "192.168.4.117";
        user = "pi";
      };
      "nas" = {
        hostname = "192.168.4.54";
        user = "yanda-admin";
      };
      "rig" = {
        hostname = "192.168.4.72";
        user = "yanda";
      };
    };
  };

}
