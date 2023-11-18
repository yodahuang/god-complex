{ pkgs, lib, ... }: {

  users.users.yanda = { home = "/Users/yanda"; };

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  environment.shells = with pkgs; [ bashInteractive zsh fish ];

  system = {
    # Used for backwards compatibility, please read the changelog before changing.
    # $ darwin-rebuild changelog
    stateVersion = 4;
    defaults = {
      finder = {
        AppleShowAllExtensions = true;
        ShowPathbar = true;
      };
      # Repeat the key instead inputting strange characters.
      NSGlobalDomain.ApplePressAndHoldEnabled = false;
    };
  };

  homebrew = {
    enable = true;
    onActivation = {
      upgrade = true;
      cleanup = "zap";
    };
    brews = [
      "mas"
      # As of June 2023, the nix-installed have some issue with QEMU
      # https://github.com/NixOS/nixpkgs/issues/169118
      "podman"
    ];
    casks = [
      "raycast"
      "arc"
      "1password"
      "1password-cli"
      "warp"
      "logseq"
      "hey"
      "resilio-sync"
      "calibre"
      "mos"
      "rectangle"
      "dash"
      "steam"
      "balenaetcher"
      "godot"
    ];
    # These app IDs are from using the mas CLI app
    # mas = mac app store
    # https://github.com/mas-cli/mas
    #
    # $ mas search <app name>
    #
    masApps = {
      "tailscale" = 1475387142;
      "Things 3" = 904280696;
      "Structured" = 1499198946;
      # "Klack" = 2143728525;
    };
  };
}
