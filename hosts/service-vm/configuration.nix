{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/server/docker.nix
  ];

  # ── Boot ──────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Netzwerk ──────────────────────────────────────────
  networking.hostName = "service-vm";
  networking.networkmanager.enable = true;

  # ── SSH ───────────────────────────────────────────────
  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
  };

  # ── NFS Mounts from NAS ──────────────────────────────
  # Replace NAS_IP with the actual IP of your homelab NAS.
  # x-systemd.automount: mounts on first access, unmounts after idle.
  # soft + timeo=150: don't hang indefinitely if NAS is offline.
  fileSystems."/mnt/nas/media" = {
    device = "NAS_IP:/mnt/storage/media";
    fsType = "nfs";
    options = [
      "soft" "timeo=150" "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.mount-timeout=10"
    ];
  };

  fileSystems."/mnt/nas/documents" = {
    device = "NAS_IP:/mnt/storage/documents";
    fsType = "nfs";
    options = [
      "soft" "timeo=150" "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.mount-timeout=10"
    ];
  };

  fileSystems."/mnt/nas/docker" = {
    device = "NAS_IP:/mnt/storage/docker/service-vm";
    fsType = "nfs";
    options = [
      "soft" "timeo=150" "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.mount-timeout=10"
    ];
  };

  # ── Firewall ──────────────────────────────────────────
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22   # SSH
      2283 # Immich     (Caddy on NAS routes here)
      8000 # Paperless  (Caddy on NAS routes here)
    ];
  };

  # ── Garbage Collection ───────────────────────────────
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  system.stateVersion = "24.11";
}
