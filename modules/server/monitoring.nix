{ config, pkgs, ... }:

let
  # Sends SMART alerts to Ntfy (running in Docker on localhost:8082)
  smartdNtfyAlert = pkgs.writeShellScript "smartd-ntfy-alert" ''
    ${pkgs.curl}/bin/curl -s \
      -d "''${SMARTD_MESSAGE}" \
      "http://localhost:8082/homelab-alerts" \
      -H "Title: SMART Alert: ''${SMARTD_DEVICE}" \
      -H "Priority: urgent" \
      -H "Tags: warning,hard_drive" \
      || true   # don't fail the service if ntfy is down
  '';
in
{
  # ── SMART Monitoring ──────────────────────────────────
  # Monitors all drives (SSD boot + 4x HDD data + 1x HDD parity).
  # Short self-test: daily at 02:00
  # Long self-test:  weekly on Saturday at 03:00
  services.smartd = {
    enable = true;
    autodetect = true;
    defaults = "-a -o on -S on -s (S/../.././02|L/../../6/03) -m root -M exec ${smartdNtfyAlert}";
    # Ntfy alerts only fire on real failures. Test manually with:
    #   smartctl -t short /dev/sda
  };

  environment.systemPackages = with pkgs; [
    smartmontools  # provides smartctl for manual checks
  ];

  # ── SMART alert topic in Ntfy ─────────────────────────
  # Subscribe to the "homelab-alerts" topic in the Ntfy app
  # on your phone: https://ntfy.home.local/homelab-alerts
}
