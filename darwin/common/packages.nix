let
  commonBrews = [
    "mas"
    # As of June 2023, the nix-installed have some issue with QEMU
    # https://github.com/NixOS/nixpkgs/issues/169118
    "gopeed"
  ];

  commonMasApps = {
    "tailscale" = 1475387142;
    "Things 3" = 904280696;
    "Structured" = 1499198946;
    # "Klack" = 2143728525;
  };

  commonCasks = [
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
    "clash-verge-rev"
    "notion"
  ];

  hostCasks = {
    studio = [
      "godot"
      "firefox"
      "balenaetcher"
      "steam"
      "signal"
      "downie"
      "notion"
      "whisky"
      "macwhisper"
      "lm-studio"
      "typeless"
      "crossover"
      "zoom"
    ];
    geisha = [
      "microsoft-office"
    ];
  };

  hostBrews = {
    studio = [
      "podman"
    ];
    geisha = [];
  };

  hostMasApps = {
    studio = {};
    geisha = {};
  };
in {
  common = {
    brews = commonBrews;
    casks = commonCasks;
    masApps = commonMasApps;
  };

  hosts = {
    studio = {
      brews = hostBrews.studio;
      casks = hostCasks.studio;
      masApps = hostMasApps.studio;
    };
    geisha = {
      brews = hostBrews.geisha;
      casks = hostCasks.geisha;
      masApps = hostMasApps.geisha;
    };
  };
}
