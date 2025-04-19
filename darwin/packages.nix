{
  homebrew = {
    brews = [
      "mas"
      # As of June 2023, the nix-installed have some issue with QEMU
      # https://github.com/NixOS/nixpkgs/issues/169118
      "podman"
      "gopeed"
    ];
    casks = [
      "raycast"
      "arc"
      "firefox"
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
      "whisky"
      "pdfsam-basic"
      "prusaslicer"
      "signal"
      "downie"
      "notion"
      "cursor"
      "windsurf"
      "ghostty"
      "anki"
    ];
    masApps = {
      "tailscale" = 1475387142;
      "Things 3" = 904280696;
      "Structured" = 1499198946;
      # "Klack" = 2143728525;
    };
  };
}
