{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/tailscale.nix
    ../../modules/secrets.nix
    # ── Storage ──────────────────────────────────────────
    ../../modules/server/storage.nix
    ../../modules/server/snapraid.nix
    # ── Network shares ───────────────────────────────────
    ../../modules/server/samba.nix
    ../../modules/server/nfs.nix
    # ── Docker ───────────────────────────────────────────
    ../../modules/server/docker.nix
    # ── Network ──────────────────────────────────────────
    ../../modules/server/firewall.nix
    # ── Maintenance ──────────────────────────────────────
    ../../modules/server/monitoring.nix
    ../../modules/server/backup.nix
    ../../modules/server/wol.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "homelab";
  networking.networkmanager.enable = true;

  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  system.stateVersion = "24.11";
}
