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
  hey-cli = pkgs.callPackage ./pkgs/hey-cli.nix {};
  wanderlog-mcp = pkgs.callPackage ./pkgs/wanderlog-mcp.nix {};
  wanderlog-mcp-with-cookie = pkgs.writeShellScriptBin "wanderlog-mcp-with-cookie" ''
    export WANDERLOG_COOKIE="$(<${config.age.secrets.wanderlog-cookie.path})"
    exec ${lib.getExe wanderlog-mcp}
  '';
  agent-mcp-servers = {
    context7 = {
      command = "${pkgs.nodejs_22}/bin/npx";
      args = ["--yes" "@upstash/context7-mcp"];
    };
    wanderlog = {
      command = lib.getExe wanderlog-mcp-with-cookie;
      args = [];
    };
  };
  codex-mcp-config = (pkgs.formats.toml {}).generate "config.toml" {
    mcp_servers = agent-mcp-servers;
  };
  # ~/.codex/config.toml also holds state the Codex app writes itself (e.g. the
  # currently selected model), so it can't be a plain home.file symlink into
  # the (read-only) Nix store -- that would make the whole file read-only and
  # break in-app model switching. Instead, merge just the mcp_servers table
  # into a real, writable file and leave any other keys alone.
  codex-config-merge = pkgs.writeText "codex-config-merge.py" ''
    import pathlib
    import sys

    import tomlkit

    target = pathlib.Path(sys.argv[1])
    mcp_source = pathlib.Path(sys.argv[2])

    if target.is_symlink() or not target.exists():
        doc = tomlkit.document()
    else:
        doc = tomlkit.parse(target.read_text())

    mcp_doc = tomlkit.parse(mcp_source.read_text())
    doc["mcp_servers"] = mcp_doc["mcp_servers"]

    if target.is_symlink():
        target.unlink()
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(tomlkit.dumps(doc))
  '';
  codex-config-merge-python = pkgs.python3.withPackages (ps: [ps.tomlkit]);
  agent-skills = {
    hey = hey-cli.src + "/skills/hey";
    make-paper-notes = ./skills/make-paper-notes;
  };
in {
  imports =
    [
      flake-inputs.agenix.homeManagerModules.default
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
    ]
    ++ lib.optionals (!is_darwin) [podman]
    ++ lib.optionals is_darwin [qmk];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  age = lib.mkIf is_darwin {
    identityPaths = ["/Users/yanda/.ssh/id_manjaro_ed25519"];
    secrets.wanderlog-cookie.file = ./secrets/wanderlog-cookie.age;
  };

  programs.mcp = lib.mkIf is_darwin {
    enable = true;
    servers = agent-mcp-servers;
  };

  # The ChatGPT desktop app supplies the actual Codex binary. Use a no-op package
  # so Home Manager can own Codex's configuration without replacing that app.
  programs.codex = lib.mkIf is_darwin {
    enable = true;
    package = pkgs.writeShellScriptBin "codex" "";
    # Home Manager currently writes config.yaml for this integration, while the
    # Codex app reads config.toml. Manage that native file below instead.
    enableMcpIntegration = false;
    skills = agent-skills;
  };

  home.activation.codexMcpConfig = lib.mkIf is_darwin (
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      run ${codex-config-merge-python}/bin/python3 ${codex-config-merge} \
        "$HOME/.codex/config.toml" ${codex-mcp-config}
    ''
  );

  programs.claude-code = lib.mkIf is_darwin {
    enable = true;
    enableMcpIntegration = true;
    skills = agent-skills;
  };

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

  programs.atuin = {
    enable = true;
    # Use nucleo
    daemon.enable = true;
    settings = {
      search_mode = "daemon-fuzzy";
    };
  };

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
