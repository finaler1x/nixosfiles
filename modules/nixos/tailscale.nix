{ config, pkgs, ... }:

{
  services.tailscale = {
    enable = true;
    openFirewall = true;              # opens UDP 41641 automatically
    useRoutingFeatures = "server";    # enables IP forwarding for subnet routing
    extraUpFlags = [ "--ssh" ];       # enables Tailscale SSH

    # Uncomment to auto-authenticate on first boot using a sops-managed auth key.
    # Generate a reusable key at tailscale.com/admin/settings/keys
    # authKeyFile = config.sops.secrets."tailscale/auth_key".path;
  };

  # ── Setup ────────────────────────────────────────────
  # After first boot (or if not using authKeyFile), run once:
  #   sudo tailscale up --advertise-routes=192.168.1.0/24 --accept-routes --ssh
  # Replace 192.168.1.0/24 with your actual LAN subnet.
  # Then approve the subnet in Tailscale admin console.
}
