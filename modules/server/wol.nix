{ config, pkgs, ... }:

let
  # Reads the MAC address from the sops secret at runtime
  wakeGaming = pkgs.writeShellScriptBin "wake-gaming" ''
    MAC=$(cat ${config.sops.secrets."gaming_rig_mac".path})
    echo "Sending Wake-on-LAN to $MAC..."
    ${pkgs.wakeonlan}/bin/wakeonlan "$MAC"
  '';

  # Shuts down the gaming rig via SSH (Windows)
  # Requires SSH server enabled on Windows + key-based auth configured
  sleepGaming = pkgs.writeShellScriptBin "sleep-gaming" ''
    echo "Sending shutdown to gaming rig..."
    ${pkgs.openssh}/bin/ssh antonio@gaming-rig.home.local "shutdown /s /t 0"
  '';
in
{
  environment.systemPackages = [
    pkgs.wakeonlan
    wakeGaming
    sleepGaming
  ];

  # ── Prerequisites on the gaming rig ──────────────────
  # 1. BIOS/UEFI: Enable "Wake on LAN"
  # 2. Windows: Device Manager → NIC → Power Management
  #             → Enable "Wake on Magic Packet"
  # 3. Windows: Enable SSH server (optional, for sleep-gaming)
  #             Settings → Optional Features → OpenSSH Server
  # 4. Gaming rig must be connected via Ethernet

  # ── Usage ────────────────────────────────────────────
  # Start rig:  wake-gaming
  # Shut down:  sleep-gaming
}
