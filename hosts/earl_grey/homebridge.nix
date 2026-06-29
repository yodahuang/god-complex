{...}: {
  # Migrated off the (non-Nix) octo machine. Fresh start: accessories,
  # plugins (e.g. homebridge-nest) and HomeKit pairing are configured at
  # runtime via the config-ui-x web UI on :8581 (reverse-proxied by Caddy).
  # Plugins npm-install into the writeable pluginPath; nothing to declare here.
  services.homebridge = {
    enable = true;
    # Opens the UI port (8581), the bridge port (51826) and mDNS (5353/udp)
    # so HomeKit controllers on the LAN can reach the bridge.
    openFirewall = true;
  };
}
