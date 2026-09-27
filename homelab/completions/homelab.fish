# Completions for the homelab command.
set -l __homelab_cmds plan apply import bump manifest help

complete -c homelab -f
complete -c homelab -n "not __fish_seen_subcommand_from $__homelab_cmds" -a plan -d "Show pending OpenTofu changes"
complete -c homelab -n "not __fish_seen_subcommand_from $__homelab_cmds" -a apply -d "Apply OpenTofu changes"
complete -c homelab -n "not __fish_seen_subcommand_from $__homelab_cmds" -a import -d "Import an existing object into state"
complete -c homelab -n "not __fish_seen_subcommand_from $__homelab_cmds" -a bump -d "Update pinned image tags"
complete -c homelab -n "not __fish_seen_subcommand_from $__homelab_cmds" -a manifest -d "Print the homelab manifest JSON"
complete -c homelab -n "not __fish_seen_subcommand_from $__homelab_cmds" -a help -d "Show help"

complete -c homelab -n "__fish_seen_subcommand_from bump" -l dry-run -d "Show what would change without writing"
complete -c homelab -n "__fish_seen_subcommand_from import" -a "dsm_container_project.radarr dsm_event_task.tailscale_tun dsm_scheduled_task.tailscale_update unifi_client.reservation unifi_dns_record.local cloudflare_dns_record.public_wildcard" -d "OpenTofu address"
