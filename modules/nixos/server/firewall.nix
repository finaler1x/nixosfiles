{ config, pkgs, ... }:

{
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];

    allowedTCPPorts = [
      22    # SSH
      80    # HTTP  (Caddy)
      443   # HTTPS (Caddy)
      139   # Samba NetBIOS
      445   # Samba SMB
      2049  # NFS
      22000 # Syncthing sync protocol
    ];

    allowedUDPPorts = [
      53    # DNS (AdGuard Home)
      137   # Samba NetBIOS
      138   # Samba NetBIOS
      2049  # NFS
      21027 # Syncthing local discovery
      22000 # Syncthing sync protocol
    ];
  };
}
