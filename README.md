# Nix god complex

[This](https://old.reddit.com/r/NixOS/comments/kauf1m/dealing_with_post_nixflake_god_complex/).

## Reusable bits

- [`macos-default-apps`](modules/macos-default-apps.md) — Home Manager module for
  setting default applications on macOS declaratively (including for `.nix`/`.rs`
  and other extensions macOS normally won't let you set). Exposed as
  `homeManagerModules.default`.

## Homelab networking and split DNS

Every service is reached at `<service>.int.yanda.rocks`. A single Caddy
ingress on **Earl Grey** terminates TLS (Let's Encrypt via the Cloudflare
DNS-01 challenge) and reverse-proxies to the backend declared in the
inventory. The same hostname answers from two DNS views, which is what makes
it work both at home and remotely:

| Where the client is | Resolver it asks | `*.int.yanda.rocks` resolves to |
| --- | --- | --- |
| Home LAN | UniFi gateway (`192.168.1.1`) | Earl Grey LAN IP |
| Tailnet / remote | Public DNS (Cloudflare) | Earl Grey Tailscale IP |

The Cloudflare record is `proxied = false` and only advertises the Tailscale
address, so nothing is exposed to the open internet: a service is reachable
from outside the house only through the tailnet.

`homelab/inventory.nix` is the single source of truth for nodes, DHCP
reservations, and services. `homelab/lib.nix` derives the Caddy vhosts, Homer
dashboard entries, hostnames, and backend targets from it and emits a
secret-free manifest. `homelab/opentofu` (run via `homelab plan` / `homelab apply`) consumes that manifest to manage the UniFi reservations
and local DNS record plus the Cloudflare wildcard. Adding a service means
adding one entry to `inventory.services`; Caddy and the dashboard pick it up.

Caddy also answers on the legacy `http://<service>.home` names, but only
`*.int.yanda.rocks` is managed in the split-horizon DNS records.

### Gotcha: clients that bring their own DNS

Split DNS only works for clients that actually ask the UniFi resolver. A host
with a hardcoded public resolver (for example the Synology NAS, whose
`/etc/resolv.conf` is `8.8.8.8`) gets the *public* answer — Earl Grey's
Tailscale IP — and if it is not itself on the tailnet, the connection times
out. That is why Radarr on the NAS could not reach
`https://sabnzbd.int.yanda.rocks/` while a laptop could. Point the host's (and
its container runtime's) DNS at `192.168.1.1`, or use the direct address for
same-host traffic.

### Synology NAS (Dumpster)

OpenTofu also manages a few DSM objects via the `batonogov/synology-dsm`
provider (`homelab/opentofu/synology.tf`), chosen because it is developed
against DSM 7.3.2 and supports boot events, weekly schedules, and container
projects:

- a **Boot-up task** that runs `tailscale configure-host` so DSM7 creates
  `/dev/net/tun` and leaves userspace networking. Without it Tailscale is
  reachable only from `tailscaled` itself, so Docker apps on the NAS cannot use
  the tailnet.
- a **weekly** `tailscale update` task that re-runs `configure-host` (upgrading
  the package drops the capabilities it sets).
- the **radarr media stack** (radarr, sabnzbd, bazarr, sonarr, notifiarr) and
  **paperless-ngx** as Container Manager projects. Image tags are pinned in
  `homelab/opentofu/compose/*.yaml`; bump a tag and apply to update. The
  remaining stacks (`stashapp`, `portainer-agent`, `calibre-web`) are not
  managed yet.

Credentials live in the `synology` agenix secret (username and password only;
the host comes from `meta.nasNode`). The `agenix` CLI is installed by Home
Manager from the pinned flake input. Run it from inside `secrets/`, because the
rule keys in `secrets.nix` are bare filenames and agenix matches the argument
verbatim:

```bash
cd secrets && agenix -e synology.age
# SYNOLOGY_DSM_USERNAME=terraform
# SYNOLOGY_DSM_PASSWORD=...
```

Remove any hand-created copy of the `Tailscale TUN` boot task in DSM first so
OpenTofu is the only owner. The boot task only fires on restart, so run it once
from DSM (or reboot) to enable TUN without waiting.

The radarr stack and paperless-ngx are **migrations**, because Container
Manager has to take them over from the CLI stacks (they would fight over the
same ports/names). Once, per stack:

```bash
ssh nas 'cd /volume1/Tools/radarr && /usr/local/bin/docker-compose down'  # stop the CLI stack
homelab plan                          # review
homelab apply                         # Container Manager creates the project
# verify the containers, then retire the old stack:
ssh nas 'rm /volume1/Tools/radarr/docker-compose.yml'
# and drop the stack from the stacks list in upgrade.sh
```

For paperless-ngx the old stack is `/volume1/Tools/paperless-local`; copy its
`docker-compose.env` to `/volume1/docker/paperless/docker-compose.env` first
(the compose file references it and it is not in git). Its named volumes
(`paperless_data`/`paperless_media`/`paperless_redisdata`) are declared by
explicit name in the compose file, so they are reused as-is.

Run `homelab` from the repo checkout (or set `HOMELAB_REPO`): it then reads the
live tree, so edits to the `.tf` files or the compose files take effect on the
next run with no `nh darwin switch`. Run from anywhere else it falls back to the
read-only `/nix/store` snapshot taken at the last switch.

To update pinned images, `homelab bump` queries the registries
(Docker Hub and GHCR) directly and rewrites the tags in place, keeping each
image on its own track (linuxserver `x.y.z.w-lsN`, plain `x.y.z`, etc.):

```bash
cd ~/.config/nix-darwin     # or set HOMELAB_REPO to the checkout
homelab bump --dry-run      # show what would change
homelab bump                # rewrite compose/*.yaml in the checkout
homelab apply               # Container Manager rebuilds the project
```

Note that a compose change stops and restarts the **whole** project, so a
one-image bump briefly restarts every service in it.

## Setting this up a a fresh Nix machine

## Git Hooks

All staged `.nix` files are auto-formatted with alejandra on commit (via lefthook). Just run `lefthook install` after cloning if needed.

```bash
nix --experimental-features 'nix-command flakes' run nixpkgs#git clone https://github.com/yodahuang/god-complex.git
```
