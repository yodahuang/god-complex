# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

```bash
# Preferred: apply via nh (wrapper around darwin-rebuild/nixos-rebuild with
# nicer diffs/output). The maintainer uses nh day-to-day.
nh darwin switch . -H studio
nh os switch .            # on a NixOS host

# Apply macOS (darwin) configuration
darwin-rebuild switch --flake .#studio
darwin-rebuild switch --flake .#geisha

# Apply NixOS configuration (run on the target host itself).
# Note: flake attr names are capitalized (Rig, Surface, EarlGrey).
sudo nixos-rebuild switch --flake .#Rig
sudo nixos-rebuild switch --flake .#Surface

# Deploy to EarlGrey (aarch64-linux Pi) — do NOT build on the Pi.
# Run from studio: deploy-rs builds the closure locally on studio's
# nix.linux-builder (the aarch64-linux VM, see hosts/studio/default.nix),
# copies it to the Pi over SSH, and activates with automatic rollback.
deploy .#EarlGrey
deploy --skip-checks .#EarlGrey   # skip flake checks (faster; checks eval all nodes)

# Update flake inputs
nix flake update

# Format all nix files
alejandra .

# Install git hooks (required once per clone)
lefthook install
```

### Troubleshooting: linux-builder won't start (aarch64-linux builds fail)

Symptom: `deploy .#EarlGrey` (or any aarch64-linux build) fails with
`Failed to find a machine for remote build!` even though `/etc/nix/machines`
lists the builder. The `org.nixos.linux-builder` launchd daemon is up but
crash-loops (`launchctl print system/org.nixos.linux-builder` shows a huge
`runs` count and a non-zero `last exit code`). The QEMU args actually in use
are in the store path referenced by `/Library/LaunchDaemons/org.nixos.linux-builder.plist`
→ `linux-builder-start` → `create-builder` → `run-builder` → `run-nixos-vm`.

Two distinct failures have been seen:

1. **`last exit code = 134` (SIGABRT)** — QEMU 11.0's new SME2-over-HVF vCPU
   init asserts (`HV_SYS_REG_SMCR_EL1` in `target/arm/hvf/sysreg.c.inc`; crash
   reports under `/Library/Logs/DiagnosticReports/qemu-system-aarch64-*.ips`)
   on macOS 26.5.x SME-capable Apple Silicon. No `-cpu` flag avoided it.
2. **`last exit code = 1`** — the old workaround pinned the builder's QEMU to
   25.11's 10.1.5 via a `nixpkgs-qemu` input, but nixpkgs then started
   hardcoding `-machine virt-11.0` for aarch64-darwin (`nixos/lib/qemu-common.nix`),
   which 10.1.5 rejects (`unsupported machine type: "virt-11.0"`). The builder
   never starts, so Nix can't reach it.

Fix (applied): the pin is gone; use nixpkgs' default QEMU (11.1.1 as of
2026-09), which boots the builder under HVF on macOS 26.5.x. After applying:

```bash
nh darwin switch . -H studio                                  # native; doesn't need the builder
sudo launchctl kickstart -k system/org.nixos.linux-builder    # restart the VM cleanly
sudo ssh -i /etc/nix/builder_ed25519 builder@linux-builder 'uname -sm'  # expect: Linux aarch64
```

## Architecture

This is a multi-host Nix configuration managing 2 macOS machines and 3 Linux machines using Nix Flakes, nix-darwin, and Home Manager.

### Module Hierarchy

```
flake.nix              # Entry point — defines all system outputs
├── darwin/core.nix    # macOS base (imports common.nix + home.nix)
│   └── darwin/common/ # Homebrew, macOS preferences, system packages
├── nixos/default.nix  # Linux base (bootloader, X11, audio, SSH)
├── common.nix         # Cross-platform: fish, git, ssh, dev tools
├── home.nix           # Home Manager: shell plugins, direnv, atuin, zoxide
└── home_gui.nix       # GUI apps: VSCode, kitty, ghostty, zed, Firefox
```

Each host lives in `hosts/{hostname}/default.nix` and imports the shared modules above plus any host-specific config.

### Hosts

| Host | Platform | Profile | Notes |
|------|----------|---------|-------|
| `studio` | aarch64-darwin | full | Full Homebrew profile |
| `geisha` | aarch64-darwin | lite | Lite Homebrew profile |
| `rig` | x86_64-linux | — | Gaming PC, NVIDIA, Budgie desktop |
| `surface` | x86_64-linux | — | Surface laptop, Pantheon desktop |
| `earl_grey` | aarch64-linux | — | Headless server: Caddy, AdGuard, Plex stack |

### Key Design Patterns

- **Homebrew profiles**: `darwin/common/options.nix` defines a custom `homebrew.profile` option (`"lite"` vs `"full"`) — used in `packages.nix` to gate extra casks/apps per host.
- **Secrets**: `earl_grey` uses `agenix` for age-encrypted secrets (e.g. Cloudflare API token in `secrets/`).
- **Custom packages**: `pkgs/meowdy.nix` is a custom Caddy build with Cloudflare DNS plugin; `pkgs/homer.nix` is a dashboard app.
- **Git hooks**: `lefthook.yml` runs `alejandra` on staged `.nix` files before every commit — auto-formatting is enforced at commit time.
