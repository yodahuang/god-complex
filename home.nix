{ config, pkgs, lib, flake-inputs, is_darwin, with_display, ... }:

{
  imports = [ 
    flake-inputs.nix-doom-emacs.hmModule 
  ] ++ lib.optionals (with_display) [ ./home_gui.nix ];

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

  home.packages = with pkgs;
    [
      # Common util
      neofetch
      bat
      ripgrep
      exa
      fzf
      btop
      flake-inputs.devenv.packages.${system}.devenv
      # Nix specific
      nil
      nixfmt
    ] ++ lib.optionals (!is_darwin) [ podman ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    userName = "Yanda Huang";
    userEmail = "realyanda@hey.com";
    aliases = {
      "co" = "checkout";
      "st" = "status";
      "sw" = "switch";
    };
    extraConfig = {
      merge = { conflictstyle = "diff3"; };
      pull = { rebase = true; };
      mergetool.prompt = "false";
      core.editor = "vim";
    };
    delta.enable = true;
  };

  programs.fish = {
    enable = true;
    shellAbbrs = {
      ls = "exa";
      cat = "bat";
    };
    plugins = with pkgs.fishPlugins; [
      {
        name = "tide";
        src = tide.src;
      }
      {
        name = "fzf-fish";
        src = fzf-fish.src;
      }
      {
        name = "done";
        src = done.src;
      }
    ];
    shellInit = lib.optionalString is_darwin ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
    '';
  };

  # Define Emacs service at system level

  programs.doom-emacs = {
    enable = true;
    doomPrivateDir =
      ./doom.d; # Directory containing your config.el, init.el and packages.el files
    # Getting a working emacs shouldn't be this hard
    # https://github.com/NixOS/nixpkgs/issues/127902
    # The macport patch uses llvm 6, and upgrading it causes several segfaults.
    # emacsPackage = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.emacs-macport else pkgs.emacs;
    emacsPackage = pkgs.emacs;
  };

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
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
        extraOptions = lib.optionalAttrs with_display {
          # On NixOS, it's in its usual location.
          # On Darwin, it's from some random place AppStore puts.
          IdentityAgent = if is_darwin then
            ''
              "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"''
          else
            "~/.1password/agent.sock";
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
