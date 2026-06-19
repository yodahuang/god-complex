# Declarative macOS default-application associations for Home Manager.
#
# macOS associates default openers by UTI. Two things make this hard to do
# declaratively, both handled by this module:
#
#   1. Setting a handler for a *dynamic* UTI (dyn.…) is rejected by Launch
#      Services with error -50. Many dev extensions (.nix, .rs, .go, .toml, …)
#      have no app-exported UTI, so they only ever get dynamic UTIs. This module
#      ships a tiny ad-hoc-signed "exporter" .app that declares real UTIs for
#      such extensions (the signature identifier must match the bundle id or
#      macOS ignores the declarations — handled here), making them settable.
#
#   2. Every Nix version bump leaves a dead /nix/store registration behind, and
#      duplicate registrations for one bundle id make Launch Services reject
#      changes with -50. Set `appPath` on an association to purge the stale ones
#      and (re)register the current app before applying defaults.
#
# Note: on macOS 26 (Tahoe) the system shows a one-time "Use <App>?"
# confirmation dialog the first time each default changes. That GUI prompt is
# imposed by macOS and cannot be bypassed by any tool.
#
# Example usage (in a Home Manager configuration):
#
#   imports = [ inputs.<thisflake>.homeManagerModules.default ];
#
#   targets.darwin.defaultApps = {
#     enable = true;
#     associations = [{
#       bundleId = "dev.zed.Zed";
#       appPath = "${pkgs.zed-editor}/Applications/Zed.app";
#       types = [ "public.plain-text" "public.json" ];
#       extensions = { nix = "public.source-code"; rs = "public.source-code"; };
#     }];
#   };
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.targets.darwin.defaultApps;

  lsregister = "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister";

  associationType = lib.types.submodule {
    options = {
      bundleId = lib.mkOption {
        type = lib.types.str;
        example = "dev.zed.Zed";
        description = "Bundle identifier of the application to set as default handler.";
      };
      appPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = lib.literalExpression ''"''${pkgs.zed-editor}/Applications/Zed.app"'';
        description = ''
          Optional path to the app bundle. When set, stale `/nix/store` copies
          of this app are unregistered from Launch Services and this one is
          (re)registered before defaults are applied — avoiding the duplicate
          registrations that make Launch Services reject changes with error -50.
        '';
      };
      types = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["public.plain-text" "public.json"];
        description = "Real (non-dynamic) UTIs this app should become the default handler for.";
      };
      extensions = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        example = lib.literalExpression ''{ nix = "public.source-code"; rs = "public.source-code"; }'';
        description = ''
          File extensions that have no real system UTI. For each entry a real UTI
          is exported (conforming to the given UTI) so it becomes settable, then
          pointed at this app. The value is the UTI to conform to, e.g.
          `public.source-code`, `public.text`, or `public.shell-script`.
        '';
      };
    };
  };

  # All exported extensions across every association, merged into the one
  # exporter bundle. Later associations win on conflicting extensions.
  allExtensions = lib.foldl' (acc: a: acc // a.extensions) {} cfg.associations;
  hasExporter = allExtensions != {};

  utiId = ext: "${cfg.exporterBundleId}.${ext}";

  declXml = lib.concatStringsSep "\n" (lib.mapAttrsToList (ext: conformsTo: ''
    <dict>
      <key>UTTypeIdentifier</key><string>${utiId ext}</string>
      <key>UTTypeDescription</key><string>${ext} file</string>
      <key>UTTypeConformsTo</key><array><string>${conformsTo}</string></array>
      <key>UTTypeTagSpecification</key>
      <dict><key>public.filename-extension</key><array><string>${ext}</string></array></dict>
    </dict>'')
  allExtensions);

  infoPlist = pkgs.writeText "Info.plist" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleIdentifier</key><string>${cfg.exporterBundleId}</string>
      <key>CFBundleName</key><string>${cfg.exporterAppName}</string>
      <key>CFBundleExecutable</key><string>exporter</string>
      <key>CFBundlePackageType</key><string>APPL</string>
      <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
      <key>CFBundleShortVersionString</key><string>1.0</string>
      <key>LSUIElement</key><true/>
      <key>UTExportedTypeDeclarations</key>
      <array>
    ${declXml}
      </array>
    </dict>
    </plist>
  '';

  # Minimal Mach-O so the bundle is a valid, signable app (it is never launched).
  exporterBin = pkgs.runCommandCC "mac-uti-exporter-bin" {} ''
    mkdir -p "$out/bin"
    printf 'int main(void){return 0;}\n' > main.c
    $CC main.c -o "$out/bin/exporter"
  '';

  exporterApp = pkgs.runCommand "mac-uti-exporter-app" {} ''
    app="$out/${cfg.exporterAppName}.app"
    mkdir -p "$app/Contents/MacOS"
    cp ${exporterBin}/bin/exporter "$app/Contents/MacOS/exporter"
    cp ${infoPlist} "$app/Contents/Info.plist"
  '';

  duti = uti: bundleId: ''${pkgs.duti}/bin/duti -s ${lib.escapeShellArg bundleId} ${lib.escapeShellArg uti} all 2>/dev/null || true'';

  associationScript = a: let
    purge = lib.optionalString (a.appPath != null) ''
      cur=${lib.escapeShellArg a.appPath}
      # Unregister every Launch Services registration for this bundle id except
      # the current store path. This clears dead version copies AND stray
      # registrations elsewhere (e.g. leftover mac-app-util trampolines in
      # ~/Applications) that would otherwise shadow the real app and break the
      # default with a broken/old version.
      ${lsregister} -dump 2>/dev/null \
        | awk -v b=${lib.escapeShellArg a.bundleId} '
            /^-+$/ { if (hit && path != "") print path; path=""; hit=0; next }
            /^[[:space:]]*path:/ { l=$0; sub(/^[[:space:]]*path:[[:space:]]*/, "", l); sub(/[[:space:]]*\([0-9a-fx]+\)[[:space:]]*$/, "", l); path=l }
            index($0, b) { hit=1 }
            END { if (hit && path != "") print path }
          ' \
        | while IFS= read -r p; do [ "$p" = "$cur" ] || ${lsregister} -u "$p" 2>/dev/null || true; done
      ${lsregister} -f "$cur" 2>/dev/null || true
    '';
    typeCmds = map (t: duti t a.bundleId) a.types;
    extCmds = lib.mapAttrsToList (ext: _: duti (utiId ext) a.bundleId) a.extensions;
  in
    purge + lib.concatStringsSep "\n" (typeCmds ++ extCmds);
in {
  options.targets.darwin.defaultApps = {
    enable = lib.mkEnableOption "declarative macOS default application associations";

    exporterBundleId = lib.mkOption {
      type = lib.types.str;
      default = "org.nixos.uti-exporter";
      description = "Bundle identifier of the generated UTI-exporter app. Exported UTIs are named `<this>.<extension>`.";
    };

    exporterAppName = lib.mkOption {
      type = lib.types.str;
      default = "Exported File Types";
      description = "Display name / bundle name of the generated UTI-exporter app placed in ~/Applications.";
    };

    associations = lib.mkOption {
      type = lib.types.listOf associationType;
      default = [];
      description = "List of application/UTI associations to apply as Launch Services defaults.";
    };
  };

  config = lib.mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isDarwin) {
    home.packages = [pkgs.duti];

    home.activation.macosDefaultApps = lib.hm.dag.entryAfter ["writeBoundary"] (''
        export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
      ''
      + lib.optionalString hasExporter ''
        # Install + ad-hoc sign + register the UTI exporter. Signing in place
        # makes the signature identifier match the bundle id, which macOS
        # requires before it will honour the exported declarations.
        EXPORTER="$HOME/Applications/${cfg.exporterAppName}.app"
        run rm -rf "$EXPORTER"
        run cp -R ${lib.escapeShellArg "${exporterApp}/${cfg.exporterAppName}.app"} "$EXPORTER"
        run chmod -R u+w "$EXPORTER"
        run /usr/bin/codesign --force --deep --sign - "$EXPORTER"
        run ${lsregister} -f "$EXPORTER"
      ''
      + lib.concatMapStringsSep "\n" associationScript cfg.associations);
  };
}
