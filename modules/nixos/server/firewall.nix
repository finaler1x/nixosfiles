{ config, pkgs, ... }:

{
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ]; # all traffic over Tailscale is allowed

    allowedTCPPorts = [];
  };
}
