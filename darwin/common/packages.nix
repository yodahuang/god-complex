let
  brewsLite = [
    "mas"
    # As of June 2023, the nix-installed have some issue with QEMU
    # https://github.com/NixOS/nixpkgs/issues/169118
    "gopeed"
  ];
  brewsFull = brewsLite ++ ["podman"];

  masAppsLite = {
    "tailscale" = 1475387142;
    "Things 3" = 904280696;
    "Structured" = 1499198946;
    # "Klack" = 2143728525;
  };
  masAppsFull = masAppsLite // {};

  casksLite = [
    "raycast"
    "arc"
    "thebrowsercompany-dia"
    "1password"
    "1password-cli"
    "logseq"
    "hey-desktop"
    "resilio-sync"
    "calibre"
    "dash"
    "pdfsam-basic"
    "prusaslicer"
    "cursor"
    "windsurf"
    "ghostty"
    "anki"
    "appcleaner"
    "iina"
  ];
  casksFull = casksLite ++ ["godot" "firefox" "balenaetcher" "steam" "signal" "downie" "notion" "whisky" "macwhisper" "lm-studio"];
in {
  homebrewLite = {
    brews = brewsLite;
    casks = casksLite;
    masApps = masAppsLite;
  };
  homebrewFull = {
    brews = brewsFull;
    casks = casksFull;
    masApps = masAppsFull;
  };
}
