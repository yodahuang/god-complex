{
  pkgs,
  desiredManifest,
  apiKeyPath,
  cloudflareEnvPath,
  name,
  operation,
}: let
  manifest = pkgs.writeText "homelab-manifest.json" (builtins.toJSON desiredManifest);
  tofuModule = ./opentofu;
  launcher = builtins.readFile ./scripts/homelab-tofu;
in
  pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [pkgs.coreutils pkgs.opentofu pkgs.python3 pkgs.tailscale];
    text = ''
      unifi_api_key_file="${apiKeyPath}"
      cloudflare_env_file="${cloudflareEnvPath}"
      export HOMELAB_MANIFEST_FILE=${manifest}
      export HOMELAB_TOFU_MODULE=${tofuModule}
      export HOMELAB_TOFU_OPERATION=${operation}
      export UNIFI_API_KEY_FILE="''${unifi_api_key_file}"
      export CLOUDFLARE_ENV_FILE="''${cloudflare_env_file}"
      ${launcher}
    '';
  }
