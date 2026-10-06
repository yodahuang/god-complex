# A tiny launcher that gives a launchd job its own macOS Local Network
# identity. launchd jobs have no parent app, so macOS files their LAN access
# under whatever binary the job runs. Every nix build of uv is signed with the
# same identifier ("uv"), so two uv builds collide in System Settings: the
# switch on one row flips the other and the job stays denied.
#
# The launcher starts the real command as a child and stays its parent, so the
# whole process tree is filed under this binary. Settings lists it by its file
# name (`name`); `id` is its bundle identifier. A rebuild (e.g. a nixpkgs bump)
# triggers a fresh prompt for the new binary: allow it there.
{
  stdenv,
  writeText,
  name,
  id,
  description ? "Reaches services on the home LAN.",
}: let
  infoPlist = writeText "${name}-Info.plist" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleIdentifier</key><string>${id}</string>
      <key>CFBundleName</key><string>${name}</string>
      <key>NSLocalNetworkUsageDescription</key><string>${description}</string>
    </dict>
    </plist>
  '';
in
  stdenv.mkDerivation {
    pname = name;
    version = "1";
    src = ./launcher.c;
    dontUnpack = true;
    buildPhase = ''
      $CC -O2 -Wall -o ${name} $src -sectcreate __TEXT __info_plist ${infoPlist}
    '';
    installPhase = ''
      install -Dm755 ${name} $out/bin/${name}
    '';
    meta.mainProgram = name;
  }
