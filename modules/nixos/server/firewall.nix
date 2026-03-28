{ config, pkgs, ... }:

{
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" "docker0" ]; # all traffic over Tailscale and Docker bridge is allowed

    allowedTCPPorts = [];
  };
}
