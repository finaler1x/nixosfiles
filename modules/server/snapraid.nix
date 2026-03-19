{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ snapraid ];

  environment.etc."snapraid.conf".text = ''
    # ── Parity disk ───────────────────────────────────────
    parity /mnt/parity1/snapraid.parity

    # ── Data disks (4x 4TB) ───────────────────────────────
    data d1 /mnt/disk1/
    data d2 /mnt/disk2/
    data d3 /mnt/disk3/
    data d4 /mnt/disk4/

    # ── Content files (distributed for redundancy) ────────
    content /var/lib/snapraid/snapraid.content
    content /mnt/disk1/.snapraid.content
    content /mnt/disk2/.snapraid.content

    # ── Exclusions ────────────────────────────────────────
    exclude *.unrecoverable
    exclude /tmp/
    exclude /lost+found/
    exclude .Trash-*/
    exclude *.part
    exclude *.!qb
    exclude .thumbnails/
    exclude .cache/
    exclude .Thumbnails/
    exclude /docker/
    exclude *.log
    exclude *.pid
  '';

  systemd.tmpfiles.rules = [
    "d /var/lib/snapraid 0755 root root -"
  ];

  # ── Daily sync at 04:00 ───────────────────────────────
  systemd.services.snapraid-sync = {
    description = "SnapRAID Sync";
    after = [ "mnt-storage.mount" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.snapraid}/bin/snapraid sync";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.timers.snapraid-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "04:00";
      Persistent = true;
    };
  };

  # ── Weekly scrub Sunday 05:00 (10% of data) ──────────
  systemd.services.snapraid-scrub = {
    description = "SnapRAID Scrub";
    after = [ "mnt-storage.mount" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.snapraid}/bin/snapraid scrub -p 10 -o 0";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.timers.snapraid-scrub = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun 05:00";
      Persistent = true;
    };
  };
}
