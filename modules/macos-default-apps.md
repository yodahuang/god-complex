# `macos-default-apps` — declarative macOS default applications

A Home Manager module for setting **default applications** (file-type
associations) on macOS declaratively, including for extensions that macOS
normally refuses to let you set.

Exposed by this flake as `homeManagerModules.default` (and
`homeManagerModules.macos-default-apps`).

## Why this exists

macOS associates default openers by **UTI**, and that makes a declarative setup
surprisingly hard. This module works around three real obstacles (all verified
on macOS 26 / Tahoe):

1. **Dynamic UTIs can't be set.** Many dev extensions (`.nix`, `.rs`, `.go`,
   `.toml`, …) have no app-exported UTI, so macOS only gives them a synthesized
   `dyn.…` UTI. Setting a default handler for a dynamic UTI is rejected with
   Launch Services error `-50` — by `duti`, by `infat`, by everything. The fix
   is to make some *registered, code-signed* bundle **export a real UTI** for
   the extension. This module builds a tiny ad-hoc-signed "exporter" app that
   does exactly that (the signature identifier must match the bundle id or macOS
   ignores the declarations — handled automatically).

2. **Stale Nix-store registrations cause `-50`.** Every package version bump
   leaves a dead `/nix/store/…/App.app` registered in Launch Services, and
   duplicate registrations for one bundle id make it reject default changes. Set
   `appPath` on an association to purge the dead ones and re-register the current
   app before applying defaults.

3. **`mac-app-util` is incompatible.** Its trampoline is an AppleScript applet
   that collides on bundle id and can't be a content-type handler, so its
   presence makes every default-set fail with `-50`. Don't use it alongside this.

## Usage

In your flake inputs:

```nix
inputs.god-complex.url = "github:yodahuang/god-complex";
```

In a Home Manager configuration (standalone or via the nix-darwin HM module):

```nix
{ pkgs, inputs, ... }:
{
  imports = [ inputs.god-complex.homeManagerModules.default ];

  targets.darwin.defaultApps = {
    enable = true;
    associations = [{
      bundleId   = "dev.zed.Zed";
      appPath    = "${pkgs.zed-editor}/Applications/Zed.app";
      types      = [ "public.plain-text" "public.json" "public.python-script" ];
      extensions = {
        nix  = "public.source-code";
        rs   = "public.source-code";
        toml = "public.source-code";
      };
    }];
  };
}
```

The module is macOS-only (`mkIf … isDarwin`), so importing it in a config shared
with Linux hosts is a safe no-op.

## Options

- `targets.darwin.defaultApps.enable` — turn the module on.
- `targets.darwin.defaultApps.associations` — list of associations:
  - `bundleId` (str, required) — bundle id of the app to make default, e.g.
    `"dev.zed.Zed"`.
  - `appPath` (str, optional) — path to the app bundle. When set, stale
    `/nix/store` registrations of this app are purged and this one re-registered
    before applying defaults. Recommended for Nix-installed apps.
  - `types` (list of str) — **real** UTIs to set, e.g. `"public.json"`,
    `"net.daringfireball.markdown"`.
  - `extensions` (attrset `ext -> conformsTo`) — extensions lacking a real UTI.
    For each, a real UTI is exported (conforming to the given UTI, e.g.
    `"public.source-code"`) and then pointed at the app.
- `targets.darwin.defaultApps.exporterBundleId` (str, default
  `"org.nixos.uti-exporter"`) — bundle id of the generated exporter app.
  Exported UTIs are named `<exporterBundleId>.<extension>`.
- `targets.darwin.defaultApps.exporterAppName` (str, default
  `"Exported File Types"`) — name of the exporter app placed in
  `~/Applications`.

## Finding the right UTI / bundle id

```bash
# Real UTI of a file (authoritative):
mdls -name kMDItemContentType -raw somefile.json     # -> public.json

# Bundle id of an app:
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
  "/Applications/Some.app/Contents/Info.plist"
```

If `mdls` reports a `dyn.…` UTI, that extension belongs in `extensions`
(it needs exporting); otherwise put its real UTI in `types`.

## Caveats

- **macOS 26 confirmation prompts.** The first time each default changes, macOS
  shows a one-time "Use <App>?" dialog you must click. This is imposed by macOS
  and cannot be bypassed by any tool. Subsequent rebuilds don't re-prompt once
  the handler already matches.
- **`.ts` and other extensions with built-in system UTIs.** If macOS already
  ships a UTI for an extension (e.g. `.ts` → `public.mpeg-2-transport-stream`),
  a custom exported UTI won't override it. Set the existing UTI in `types`
  instead.
- Requires `/usr/bin/codesign` and `/usr/bin/swift`/Xcode CLT-era tooling
  present (standard on macOS).
