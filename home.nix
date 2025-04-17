{
  config,
  pkgs,
  lib,
  flake-inputs,
  with_display,
  usually_headless,
  ...
}:
let
  ips = import ./hosts/ips.nix;
  is_darwin = pkgs.stdenv.isDarwin;
in
{
  imports = [
    flake-inputs.nix-doom-emacs.hmModule
    flake-inputs.vscode-server.homeModules.default
  ] ++ lib.optionals with_display [ ./home_gui.nix ];

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.11";

  # manual building is failing for me
  manual.manpages.enable = false;

  home.packages =
    with pkgs;
    [
      # Common util
      neofetch
      bat
      ripgrep
      eza
      devenv
      yazi
      btop
      tailscale
      atool
      unzip
      # Nix specific
      nil
      nixfmt-rfc-style
      nixd
      alejandra
      # Python
      uv
    ]
    ++ lib.optionals (!is_darwin) [ podman ]
    ++ lib.optionals is_darwin [ qmk ];

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
      merge = {
        conflictstyle = "diff3";
      };
      pull = {
        rebase = true;
      };
      mergetool.prompt = "false";
      core.editor = "vim";
    };
    lfs.enable = true;
    delta.enable = true;
  };

  programs.fish = {
    enable = true;
    shellAbbrs = {
      ls = "eza";
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
    shellInit =
      lib.optionalString is_darwin ''
        eval "$(/opt/homebrew/bin/brew shellenv)"
      ''
      + ''
        fish_vi_key_bindings
      '';
  };

  # This is quite broken.
  # Tracked in https://github.com/nix-community/nix-doom-emacs/issues/353
  programs.doom-emacs = {
    # We cheated here. This is to prevent doom-emacs compiling for forever on pi.
    # enable = with_display;
    enable = false;
    doomPrivateDir = ./doom.d; # Directory containing your config.el, init.el and packages.el files
    emacsPackage = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.emacs-macport else pkgs.emacs;
  };

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
  };
  home.file = {
    ".config/nvim" = {
      source = config.lib.file.mkOutOfStoreSymlink ./nvim;
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.zoxide.enable = true;

  programs.atuin.enable = true;

  programs.ssh = {
    enable = true;
    matchBlocks = {
      "*" = {
        extraOptions = lib.optionalAttrs (!usually_headless) {
          # On NixOS, it's in its usual location.
          # On Darwin, it's from some random place AppStore puts.
          IdentityAgent =
            if is_darwin then
              ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"''
            else
              "~/.1password/agent.sock";
        };
      };
      # Hardcoding the local ip here instead of using Tailscale ones.
      "octo" = {
        hostname = ips.octo;
        user = "pi";
        forwardAgent = true;
      };
      "earl_grey" = {
        hostname = ips.earl_grey;
        user = "yanda";
        forwardAgent = true;
      };
      "nas" = {
        hostname = ips.nas;
        user = "yanda-admin";
        forwardAgent = true;
      };
      "rig" = {
        hostname = ips.rig;
        user = "yanda";
        forwardAgent = true;
      };
    };
  };

  services.vscode-server.enable = true;
}
