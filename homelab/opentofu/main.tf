locals {
  manifest = jsondecode(var.manifest_json)

  ingress = one([
    for node in local.manifest.nodes : node
    if node.id == local.manifest.meta.ingressNode
  ])

  reserved_nodes = {
    for node in local.manifest.nodes : node.id => node
    if node.lan.reservationMac != null
  }

  local_dns_records = {
    for record in local.manifest.dns.local : record.hostname => record
  }
}

provider "cloudflare" {}

provider "unifi" {
  api_url        = "https://${local.manifest.networks.home.gateway}"
  allow_insecure = true
  site           = local.manifest.meta.unifiSite
}

data "cloudflare_zone" "public" {
  filter = {
    name = local.manifest.meta.publicZone
  }
}

data "external" "tailscale" {
  program = ["python3", "${path.module}/tailscale_ip.py"]

  query = {
    selector = local.ingress.tailscale.selector
  }
}

resource "unifi_client" "reservation" {
  for_each = local.reserved_nodes

  mac        = each.value.lan.reservationMac
  name       = each.value.displayName
  fixed_ip   = each.value.lan.desiredIPv4
  network_id = local.manifest.networks[each.value.lan.network].unifiId
}

resource "unifi_dns_record" "local" {
  for_each = local.local_dns_records

  name        = each.value.hostname
  value       = unifi_client.reservation[each.value.targetNode].fixed_ip
  record_type = each.value.type
  site        = local.manifest.meta.unifiSite
}

resource "cloudflare_dns_record" "public_wildcard" {
  zone_id = data.cloudflare_zone.public.id
  name    = "*.${local.manifest.meta.publicDomain}"
  type    = "A"
  content = data.external.tailscale.result.ipv4
  proxied = false
  ttl     = 1
}

output "tailscale_ipv4" {
  value = data.external.tailscale.result.ipv4
}
