{
  config,
  pkgs,
  lib,
  flake-inputs,
  with_display,
  usually_headless,
  ...
}: let
  ips = import ./hosts/ips.nix;
  is_darwin = pkgs.stdenv.isDarwin;
in {
  imports =
    [
      flake-inputs.nix-doom-emacs.hmModule
      (flake-inputs.vscode-server + "/modules/vscode-server/home.nix")
      # macOS-only effect; self-guards via pkgs.stdenv.isDarwin, so it's a
      # no-op on the Linux hosts that share this config.
      ./home_darwin.nix
    ]
    ++ lib.optionals with_display [./home_gui.nix];

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

  home.packages = with pkgs;
    [
      lefthook
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
      nixfmt
      nixd
      alejandra
      nh
      # Python
      uv
      # PDF for coding agents
      poppler-utils
    ]
    ++ lib.optionals (!usually_headless) [
      # These are useful on interactive machines, but add large npm-backed fetches
      # that are unnecessary for headless server deployments.
      claude-code
      codex
    ]
    ++ lib.optionals (!is_darwin) [podman]
    ++ lib.optionals is_darwin [qmk];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings = {
      user = {
        email = "realyanda@hey.com";
        name = "Yanda Huang";
      };
      alias = {
        co = "checkout";
        st = "status";
        sw = "switch";
      };
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
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
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
    emacsPackage =
      if pkgs.stdenv.hostPlatform.isDarwin
      then pkgs.emacs-macport
      else pkgs.emacs;
  };

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    withPython3 = false;
    withRuby = false;
  };

  xdg.configFile = {
    "nvim/lua" = {
      source = config.lib.file.mkOutOfStoreSymlink ./nvim/lua;
    };
    "nvim/init.lua" = {
      source = config.lib.file.mkOutOfStoreSymlink ./nvim/init.lua;
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
    enableDefaultConfig = false;
    settings =
      lib.optionalAttrs (!usually_headless) {
        "*" = {
          # On NixOS, it's in its usual location.
          # On Darwin, it's from some random place AppStore puts.
          IdentityAgent =
            if is_darwin
            then ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"''
            else "~/.1password/agent.sock";
        };
      }
      // {
        # Hardcoding the local ip here instead of using Tailscale ones.
        "octo" = {
          HostName = ips.octo;
          User = "pi";
          ForwardAgent = true;
        };
        "earl_grey" = {
          HostName = ips.earl_grey;
          User = "yanda";
          ForwardAgent = true;
        };
        "nas" = {
          HostName = ips.nas;
          User = "yanda-admin";
          ForwardAgent = true;
        };
        "rig" = {
          HostName = ips.rig;
          User = "yanda";
          ForwardAgent = true;
        };
      };
  };

  services.vscode-server.enable = true;
}
