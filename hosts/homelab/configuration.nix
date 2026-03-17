{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/tailscale.nix
    ../../modules/server/storage.nix
    ../../modules/server/snapraid.nix
    ../../modules/server/samba.nix
    ../../modules/server/caddy.nix
    ../../modules/server/nextcloud.nix
    ../../modules/server/immich.nix
    ../../modules/server/adguard.nix
    ../../modules/server/vaultwarden.nix
    ../../modules/server/uptime-kuma.nix
    ../../modules/server/backup.nix
  ];

  # ── Boot ──────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Netzwerk ──────────────────────────────────────────
  networking.hostName = "homelab";
  networking.networkmanager.enable = true;

  # ── SSH ───────────────────────────────────────────────
  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
  };

  # ── Firewall ──────────────────────────────────────────
  networking.firewall = {
    allowedTCPPorts = [
      22    # SSH
      80    # HTTP (Caddy redirect)
      443   # HTTPS (Caddy)
      3000  # AdGuard Home Web UI
      445   # Samba
      139   # Samba
    ];
    allowedUDPPorts = [
      53    # DNS (AdGuard)
      137   # Samba
      138   # Samba
    ];
    trustedInterfaces = [ "tailscale0" ];
  };

  # ── Garbage Collection ───────────────────────────────
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # ── Auto Updates (optional) ──────────────────────────
  # system.autoUpgrade = {
  #   enable = true;
  #   flake = "github:dein-user/nix-infra#homelab";
  #   dates = "04:00";
  #   allowReboot = true;
  # };

  system.stateVersion = "24.11";
}
