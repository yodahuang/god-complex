{
  config,
  flake-inputs,
  ...
}: let
  chocolate-bar = flake-inputs.chocolate-bar.packages.aarch64-linux.default;
  ips = import ../ips.nix;
in {
  age.secrets.chocolate-bar.file = ../../secrets/chocolate-bar.age;

  systemd.services.chocolate-bar = {
    description = "chocolate-bar";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    environment.HEOS_HOST = ips.heos;
    serviceConfig = {
      ExecStart = "${chocolate-bar}/bin/chocolate-bar";
      # VESTA_RW_KEY=...
      EnvironmentFile = config.age.secrets.chocolate-bar.path;
      Restart = "always";
      RestartSec = 10;
      DynamicUser = true;
    };
  };
}
