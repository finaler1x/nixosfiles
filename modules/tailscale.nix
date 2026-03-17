{ config, pkgs, ... }:

{
  services.tailscale.enable = true;

  # Nach dem ersten Boot einmalig:
  # sudo tailscale up --ssh
}
