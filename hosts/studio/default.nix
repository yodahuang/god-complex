
{ pkgs, ... }: {

  system = {
    defaults = {
      finder = {
        AppleShowAllExtensions = true;
        ShowPathbar = true;
      };
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
      "fleet"
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
    };
  };
}
