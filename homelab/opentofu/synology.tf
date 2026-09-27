# Synology DSM resources (NAS = "Dumpster").
#
# Credentials come from the `synology` agenix secret via the `homelab-tofu`
# launcher: SYNOLOGY_DSM_USERNAME and SYNOLOGY_DSM_PASSWORD. The host is the
# NAS node's inventory address, not a secret. allow_task_execution must be on
# because the event/scheduled tasks run shell commands as root on the NAS.

provider "dsm" {
  # The address is not a secret: it is the NAS node's desired LAN IP from the
  # inventory that also drives the UniFi reservation.
  host     = local.dsm_host
  username = var.dsm_username
  password = var.dsm_password
  insecure = true
  # Container Manager's "build" step pulls the pinned images and can exceed the
  # default timeout on first deploy.
  timeout = "10m"
  # dsm_event_task and dsm_scheduled_task run root shell commands on the NAS.
  # DSM 7.3.2 ships a self-signed certificate, hence insecure = true above.
  allow_task_execution = true
}

locals {
  nas_node = one([
    for node in local.manifest.nodes : node
    if node.id == local.manifest.meta.nasNode
  ])

  # DSM's HTTPS port is not the default 5001 on this NAS.
  dsm_host = "https://${local.nas_node.lan.desiredIPv4}:${local.manifest.meta.dsmPort}"

  tailscale_bin = "/var/packages/Tailscale/target/bin/tailscale"

  # DSM7 has no /dev/net/tun, so the Synology package runs tailscaled with
  # --tun=userspace-networking and nothing except tailscaled itself can use the
  # tailnet. `configure-host` creates the device and setcaps tailscaled so DSM
  # switches to kernel networking. It is a compatibility alias for
  # `tailscale configure synology` on current releases. restart applies it.
  tailscale_configure = "${local.tailscale_bin} configure-host; synosystemctl restart pkgctl-Tailscale.service"
}

# Boot-up task that re-enables TUN mode after every reboot. If a copy of this
# task was created by hand, delete it in DSM first so there is no duplicate.
resource "dsm_event_task" "tailscale_tun" {
  name    = "Tailscale TUN"
  user    = "root"
  event   = "bootup"
  enabled = true
  command = local.tailscale_configure
}

# Weekly updater. `tailscale update` replaces the tailscaled binary and drops
# the capabilities set by configure-host, so re-run it afterwards.
resource "dsm_scheduled_task" "tailscale_update" {
  name    = "tailscale-update"
  user    = "root"
  enabled = true
  command = "tailscale update --yes; ${local.tailscale_configure}"

  schedule {
    frequency   = "weekly"
    day_of_week = ["monday"]
    hour        = 3
    minute      = 17
  }
}

# The media stack, pinned and managed as a Container Manager project. The
# compose file is the source of truth; bump a tag there, re-switch so the store
# copy is refreshed, then apply. The old CLI stack in /volume1/Tools/radarr must
# be stopped first (same ports), and is retired once this is applied.
resource "dsm_container_project" "radarr" {
  name              = "radarr"
  share_path        = "/docker/radarr"
  running           = true
  delete_on_destroy = false
  compose_yaml      = file("${path.module}/compose/radarr.yaml")
}
