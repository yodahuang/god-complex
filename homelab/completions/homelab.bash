# Completions for the homelab command.
_homelab() {
  local cur commands addresses
  cur="${COMP_WORDS[COMP_CWORD]}"
  commands="plan apply import bump manifest help"

  if [ "${COMP_CWORD}" -eq 1 ]; then
    COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
    return
  fi

  case "${COMP_WORDS[1]}" in
    bump)
      COMPREPLY=($(compgen -W "--dry-run" -- "${cur}"))
      ;;
    import)
      addresses="dsm_container_project.radarr dsm_event_task.tailscale_tun dsm_scheduled_task.tailscale_update unifi_client.reservation unifi_dns_record.local cloudflare_dns_record.public_wildcard"
      COMPREPLY=($(compgen -W "${addresses}" -- "${cur}"))
      ;;
  esac
}

complete -F _homelab homelab
