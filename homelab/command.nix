{
  pkgs,
  desiredManifest,
  apiKeyPath,
  cloudflareEnvPath,
  synologyEnvPath,
}: let
  manifest = pkgs.writeText "homelab-manifest.json" (builtins.toJSON desiredManifest);

  app = pkgs.writeShellApplication {
    name = "homelab";
    runtimeInputs = [pkgs.coreutils pkgs.opentofu pkgs.python3 pkgs.tailscale];
    text = ''
      # The agenix paths contain a $(...) command substitution, so assign them
      # first: `export VAR=$(...)` trips shellcheck SC2155.
      unifi_api_key_file=${apiKeyPath}
      cloudflare_env_file=${cloudflareEnvPath}
      synology_env_file=${synologyEnvPath}
      export HOMELAB_MANIFEST_FILE=${manifest}
      # Live source tree, so .tf and compose edits apply without a re-switch.
      export HOMELAB_TOFU_MODULE=${builtins.toString ./opentofu}
      export HOMELAB_COMPOSE_DIR=${builtins.toString ./opentofu/compose}
      export HOMELAB_TOFU_LAUNCHER=${./scripts/homelab-tofu}
      export HOMELAB_BUMP_SCRIPT=${./scripts/bump-images}
      export UNIFI_API_KEY_FILE="''${unifi_api_key_file}"
      export CLOUDFLARE_ENV_FILE="''${cloudflare_env_file}"
      export SYNOLOGY_ENV_FILE="''${synology_env_file}"
      exec ${./scripts/homelab} "$@"
    '';
  };
in
  # Wrap so the shell completions ship in the package output; Home Manager picks
  # them up from share/fish/vendor_completions.d and friends.
  pkgs.symlinkJoin {
    name = "homelab";
    paths = [app];
    postBuild = ''
      install -Dm644 ${./completions/homelab.fish} $out/share/fish/vendor_completions.d/homelab.fish
      install -Dm644 ${./completions/homelab.bash} $out/share/bash-completion/completions/homelab
      install -Dm644 ${./completions/_homelab} $out/share/zsh/site-functions/_homelab
    '';
  }
