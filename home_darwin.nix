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

  targets.darwin.defaultApps = {
    enable = config.programs.zed-editor.enable;
    associations = [
      {
        bundleId = "dev.zed.Zed";
        appPath = "${config.programs.zed-editor.package}/Applications/Zed.app";

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
