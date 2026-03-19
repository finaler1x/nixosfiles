{ config, pkgs, ... }:

{
  # External backup drive (adjust UUID after: sudo blkid)
  fileSystems."/mnt/backup" = {
    device = "/dev/disk/by-uuid/BACKUP-UUID";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  services.restic.backups.homelab = {
    initialize = true;
    paths = [
      "/mnt/storage/documents"       # Documents (high priority)
      "/mnt/storage/backups"         # User backups
      "/mnt/storage/shares"          # Shared files
      "/mnt/storage/docker/nas"      # NAS container configs + data
      "/var/lib/vaultwarden"         # Passwords (critical, if NixOS module active)
      "/etc/nixos"                   # NixOS configuration
    ];
    # Note: /mnt/storage/media is large — back up separately or exclude.
    # Note: docker/service-vm and docker/dev-vm are backed up on those VMs.

    repository = "/mnt/backup/restic-repo";
    passwordFile = config.sops.secrets."restic/password".path;

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
