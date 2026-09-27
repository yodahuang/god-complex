variable "manifest_json" {
  description = "JSON-encoded homelab manifest emitted by the Nix inventory."
  type        = string
}

# DSM credentials, supplied by the `homelab-tofu` launcher from the `synology`
# agenix secret (SYNOLOGY_DSM_* -> TF_VAR_dsm_*). The host is derived from the
# inventory, so only credentials live in the secret. Defaults exist only so
# `tofu validate` passes without credentials.
variable "dsm_username" {
  description = "DSM administrator account used by OpenTofu."
  type        = string
  default     = ""
}

variable "dsm_password" {
  description = "DSM administrator password used by OpenTofu."
  type        = string
  default     = ""
  sensitive   = true
}
