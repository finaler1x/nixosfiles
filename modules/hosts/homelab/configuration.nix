{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../nixos/common.nix
    ../../nixos/tailscale.nix
#    ../../nixos/secrets.nix
    # ── Storage ──────────────────────────────────────────
#    ../../nixos/server/storage.nix
#    ../../nixos/server/snapraid.nix
    # ── Network shares ───────────────────────────────────
#    ../../nixos/server/samba.nix
#    ../../nixos/server/nfs.nix
    # ── Docker ───────────────────────────────────────────
    ../../nixos/server/docker.nix
    # ── Network ──────────────────────────────────────────
    ../../nixos/server/firewall.nix
    # ── Maintenance ──────────────────────────────────────
#    ../../nixos/server/monitoring.nix
#    ../../nixos/server/backup.nix
#    ../../nixos/server/wol.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "homelab";
  networking.networkmanager.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };

  # ── Cockpit ──────────────────────────────────────────
  services.cockpit = {
    enable = true;
    port = 9090;
    openFirewall = false;
    settings = {
      WebService = {
        AllowUnencrypted = lib.mkForce true;
        Origins = lib.mkForce "https://cockpit.homelab";
      };
    };
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  system.stateVersion = "24.11";
}
