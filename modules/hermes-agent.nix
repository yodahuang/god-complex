{
  config,
  lib,
  pkgs,
  flake-inputs,
  ...
}: let
  ips = import ../hosts/ips.nix;
  hermes-package = flake-inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.messaging;
  hermes-home = "${config.home.homeDirectory}/.hermes";
  hermes-bin = "${hermes-package}/bin/hermes";

  # Studio's wired address is declared in homelab/inventory.nix and is also
  # the target Caddy uses on Earl Grey.
  dashboard-host = ips.studio;
  dashboard-port = 9119;

  runtime-path =
    lib.makeBinPath [
      hermes-package
      pkgs.ffmpeg
      pkgs.git
      pkgs.nodejs_22
      pkgs.ripgrep
      pkgs.uv
    ]
    + ":/usr/bin:/bin:/usr/sbin:/sbin";

  process-environment = [
    "HERMES_HOME=${hermes-home}"
    "PATH=${runtime-path}"
  ];

  # The dashboard service needs credentials and its public host.  hermes
  # refuses a non-loopback bind (dashboard-host) without an auth provider, and
  # it validates the browser's Host/Origin (chat WebSocket included) against
  # dashboard.public_url.  Both are declared here rather than in the
  # intentionally-unmanaged config.yaml.  The scrypt password hash is not a
  # secret.  FQDN mirrors the 'hermes' service in homelab/inventory.nix.
  dashboard-environment-values = {
    HERMES_DASHBOARD_BASIC_AUTH_USERNAME = "yanda";
    HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH = "scrypt$16384$8$1$Qu9L2ms1/c8UmizRtJz5Vw==$8M3qNVWJRXa6uWIprQIObHuduBjtqQHfuV+SpLrv6Jg=";
    HERMES_DASHBOARD_PUBLIC_URL = "https://hermes.int.yanda.rocks";
  };

  dashboard-environment = lib.mapAttrsToList (name: value: "${name}=${value}") dashboard-environment-values;

  # `run` is the foreground mode launchd supervises.  Bare `gateway` only
  # ensures a detached process exists and exits 75 otherwise, which launchd
  # then re-spawns every 5s.  `--external-supervisor` makes in-chat restarts /
  # `hermes update` hand the process back to launchd instead of spawning a
  # detached replacement.  No `--replace` (upstream #79048): re-arming takeover
  # on every KeepAlive respawn would let profiles sharing a token kill each other.
  gateway-arguments = [
    hermes-bin
    "gateway"
    "run"
    "--external-supervisor"
  ];

  dashboard-arguments = [
    hermes-bin
    "dashboard"
    "--host"
    dashboard-host
    "--port"
    (toString dashboard-port)
    "--no-open"
  ];

  systemd-unit = {
    description,
    arguments,
    environment ? [],
  }: {
    Unit = {
      Description = description;
      After = ["default.target"];
    };
    Install.WantedBy = ["default.target"];
    Service = {
      Type = "simple";
      Environment = process-environment ++ environment;
      ExecStart = lib.escapeShellArgs arguments;
      WorkingDirectory = config.home.homeDirectory;
      Restart = "always";
      RestartSec = 5;
      NoNewPrivileges = true;
      PrivateTmp = true;
      UMask = "0077";
    };
  };

  launchd-agent = {
    arguments,
    log-name,
    extra-environment ? {},
  }: {
    enable = true;
    config = {
      Label = "org.nix-community.home.${log-name}";
      ProgramArguments = arguments;
      EnvironmentVariables =
        {
          HERMES_HOME = hermes-home;
          PATH = runtime-path;
        }
        // extra-environment;
      WorkingDirectory = config.home.homeDirectory;
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 5;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/${log-name}.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/${log-name}.err.log";
      ProcessType = "Background";
    };
  };
in {
  # Nix owns the executable and process lifecycle. ~/.hermes remains a real,
  # writable directory so Hermes can update its own config and state.
  home.packages = [hermes-package];
  home.sessionVariables.HERMES_HOME = hermes-home;

  # The upstream managed module writes config.yaml/.managed and sets
  # HERMES_MANAGED. This local service definition intentionally does neither.
  systemd.user.services = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    hermes-agent = systemd-unit {
      description = "Hermes Agent message gateway";
      arguments = gateway-arguments;
    };
    hermes-backend = systemd-unit {
      description = "Hermes Agent web dashboard";
      arguments = dashboard-arguments;
      environment = dashboard-environment;
    };
  };

  launchd.agents = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    hermes-agent = launchd-agent {
      arguments = gateway-arguments;
      log-name = "hermes-agent";
    };
    hermes-backend = launchd-agent {
      arguments = dashboard-arguments;
      log-name = "hermes-backend";
      extra-environment = dashboard-environment-values;
    };
  };
}
