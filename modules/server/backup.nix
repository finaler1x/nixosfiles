{ config, pkgs, ... }:

{
  # Externe Backup-Platte (UUID anpassen nach blkid)
  fileSystems."/mnt/backup" = {
    device = "/dev/disk/by-uuid/BACKUP-UUID";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  services.restic.backups.homelab = {
    initialize = true;
    paths = [
      "/mnt/data"                  # Samba/MergerFS Daten
      "/var/lib/nextcloud"         # Nextcloud Daten
      "/var/lib/postgresql"        # Datenbank
      "/var/lib/vaultwarden"       # Passwörter
    ];
    repository = "/mnt/backup/restic-repo";
    passwordFile = "/run/secrets/restic-password";

    timerConfig = {
      OnCalendar = "03:00";
    };

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
  };
}
