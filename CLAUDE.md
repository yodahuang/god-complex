# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

```bash
# Apply macOS (darwin) configuration
darwin-rebuild switch --flake .#studio
darwin-rebuild switch --flake .#geisha

# Apply NixOS configuration (run on target host)
sudo nixos-rebuild switch --flake .#rig
sudo nixos-rebuild switch --flake .#surface
sudo nixos-rebuild switch --flake .#earl_grey

# Update flake inputs
nix flake update

# Format all nix files
alejandra .

# Install git hooks (required once per clone)
lefthook install
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
