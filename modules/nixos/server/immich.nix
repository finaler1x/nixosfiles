{ ... }:

{
  services.immich = {
    enable = true;

    # Listen for direct LAN/Tailscale access and the Dockerized Caddy proxy.
    host = "0.0.0.0";
    port = 2283;
    openFirewall = false;

    # Phone uploads / Immich-managed originals live on ZFS.
    mediaLocation = "/storage/apps/immich";

    # No local ML service for now; configure ML through the Admin UI.
    machine-learning.enable = false;

    environment.IMMICH_LOG_LEVEL = "warn";
  };

  # Redis is managed by the NixOS Immich module.
  services.redis.servers.immich.logLevel = "warning";

  # Direct access is limited to LAN and Tailscale; Caddy uses the trusted bridge.
  networking.firewall.interfaces.enp0s31f6.allowedTCPPorts = [ 2283 ];
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 2283 ];
}
