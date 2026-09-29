# macOS-only Home Manager config: make Zed the default opener for dev files.
# The reusable mechanism lives in ./modules/macos-default-apps.nix (also exposed
# as this flake's homeManagerModules.default for others to consume).
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [./modules/macos-default-apps.nix];

  # The atuin daemon's launchd agent defaults to the `user` domain, but
  # `launchctl bootstrap user/$UID` fails with EIO on this machine, leaving the
  # daemon unstarted (so the shell errors "failed to connect to local atuin
  # daemon"). The `gui` (Aqua session) domain bootstraps cleanly here, so pin
  # it. Guarded to darwin + daemon-enabled so it's a no-op on the Linux hosts
  # that share this config.
  launchd.agents.atuin-daemon.domain =
    lib.mkIf (pkgs.stdenv.hostPlatform.isDarwin && config.programs.atuin.daemon.enable) "gui";

  # Resident semantic translation service for the Pixiv Viewer PWA. The
  # service owns its own TOML config (services/semantic_translate/config.local.toml)
  # and is reached through Caddy as semantic.int.yanda.rocks. KeepAlive keeps it
  # resident across crashes; the Qwen model loads eagerly at startup.
  launchd.agents.pixiv-semantic-translate = {
    enable = pkgs.stdenv.hostPlatform.isDarwin;
    config = {
      ProgramArguments = [
        "${pkgs.uv}/bin/uv"
        "run"
        "--project"
        "services/semantic_translate"
        "python"
        "-m"
        "services.semantic_translate.server"
      ];
      WorkingDirectory = "/Users/yanda/Projects/pixiv-viewer";
      EnvironmentVariables = {
        HOME = "/Users/yanda";
        PATH = "/etc/profiles/per-user/yanda/bin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 10;
      StandardOutPath = "/Users/yanda/Library/Logs/pixiv-semantic-translate.log";
      StandardErrorPath = "/Users/yanda/Library/Logs/pixiv-semantic-translate.err.log";
    };
  };

  # The daemon binds its unix socket directly and never unlinks a stale one
  # left behind by an unclean shutdown (e.g. macOS killing it on reboot before
  # it can clean up). On Linux this is a non-issue because home-manager wires
  # the daemon through systemd socket-activation, which owns the socket file
  # itself; launchd has no equivalent, so a leftover ~/.local/share/atuin/daemon.sock
  # makes every subsequent start hit "Address already in use"
  # (atuin-daemon/src/server.rs) and launchd's KeepAlive.Crashed just retries
  # the same doomed bind forever. Remove the socket before exec'ing so a fresh
  # boot always gets a clean bind.
  launchd.agents.atuin-daemon.config.ProgramArguments = lib.mkIf (pkgs.stdenv.hostPlatform.isDarwin && config.programs.atuin.daemon.enable) (
    lib.mkForce [
      "/bin/sh"
      "-c"
      "rm -f '${config.programs.atuin.settings.daemon.socket_path}' && exec ${lib.getExe config.programs.atuin.package} daemon start"
    ]
  );

  targets.darwin.defaultApps = {
    enable = config.programs.zed-editor.enable;
    associations = [
      {
        bundleId = "dev.zed.Zed";
        # Zed itself comes from the Homebrew cask (see home_gui.nix — building
        # it via nixpkgs' zed-editor compiles Rust from source), so point
        # straight at /Applications rather than deriving from the (now null)
        # programs.zed-editor.package.
        appPath = "/Applications/Zed.app";

        # Real, system-provided UTIs Zed should own.
        types = [
          "public.plain-text"
          "public.text"
          "public.source-code"
          "public.json"
          "public.xml"
          "public.yaml"
          "public.python-script"
          "public.shell-script"
          "public.perl-script"
          "public.ruby-script"
          "public.css"
          # NOTE: deliberately NOT setting public.html — on macOS 26 changing
          # the HTML-document default is tied to the default web browser, so the
          # confirmation dialog can hijack http/https into Zed.
          "public.c-source"
          "public.c-plus-plus-source"
          "public.c-header"
          "public.objective-c-source"
          "public.comma-separated-values-text"
          "net.daringfireball.markdown"
          # macOS maps .ts to the MPEG-2 transport-stream (video) UTI and a
          # custom exported UTI can't override that built-in tag mapping, so we
          # route the existing UTI to Zed instead (treats .ts as TypeScript).
          "public.mpeg-2-transport-stream"
        ];

        # Extensions with no real system UTI -> export one (conforming as given)
        # so it becomes settable, then point it at Zed.
        extensions = {
          nix = "public.source-code";
          rs = "public.source-code";
          go = "public.source-code";
          toml = "public.source-code";
          lua = "public.source-code";
          zig = "public.source-code";
          ron = "public.source-code";
          ex = "public.source-code";
          exs = "public.source-code";
          erl = "public.source-code";
          hs = "public.source-code";
          ml = "public.source-code";
          jl = "public.source-code";
          kt = "public.source-code";
          dart = "public.source-code";
          vue = "public.source-code";
          svelte = "public.source-code";
          astro = "public.source-code";
          fish = "public.shell-script";
          conf = "public.text";
          ini = "public.text";
        };
      }
    ];
  };
}
