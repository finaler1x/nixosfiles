{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
  ];

  # ── Boot ──────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── System ────────────────────────────────────────────
  networking.hostName = "vm";
  networking.networkmanager.enable = true;

  # ── Desktop (KDE Plasma) ─────────────────────────────
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # ── VM-spezifische Pakete ────────────────────────────
  environment.systemPackages = with pkgs; [
    firefox
    ghostty
    vscode
    neovim
    python3
    go
    nodejs
  ];

  system.stateVersion = "24.11";
}
