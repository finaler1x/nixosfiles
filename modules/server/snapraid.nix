{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ snapraid ];

  environment.etc."snapraid.conf".text = ''
    # Parity Disk
    parity /mnt/parity1/snapraid.parity

    # Daten Disks
    data d1 /mnt/disk1/
    data d2 /mnt/disk2/
    data d3 /mnt/disk3/
    data d4 /mnt/disk4/
    data d5 /mnt/disk5/

    # Content Files (auf verschiedenen Disks für Redundanz)
    content /var/lib/snapraid/snapraid.content
    content /mnt/disk1/.snapraid.content
    content /mnt/disk2/.snapraid.content

    # Ausschlüsse
    exclude *.unrecoverable
    exclude /tmp/
    exclude /lost+found/
    exclude .Trash-*/
  '';

  systemd.tmpfiles.rules = [
    "d /var/lib/snapraid 0755 root root -"
  ];

  # Täglicher Sync um 4 Uhr nachts
  systemd.services.snapraid-sync = {
    description = "SnapRAID Sync";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.snapraid}/bin/snapraid sync";
    };
  };

  systemd.timers.snapraid-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "04:00";
      Persistent = true;
    };
  };

  # Wöchentlicher Scrub
  systemd.services.snapraid-scrub = {
    description = "SnapRAID Scrub";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.snapraid}/bin/snapraid scrub -p 10 -o 0";
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
