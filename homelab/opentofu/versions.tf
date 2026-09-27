terraform {
  required_version = ">= 1.9.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }

    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }

    unifi = {
      source  = "ubiquiti-community/unifi"
      version = "~> 0.55"
    }

    dsm = {
      source  = "registry.terraform.io/batonogov/synology-dsm"
      version = "~> 0.8"
    }
  }
}
