{ pkgs, ... }:

let
  prepare = pkgs.writeShellApplication {
    name = "prepare-family-apps";
    runtimeInputs = [ pkgs.python3 pkgs.util-linux ];
    text = ''exec python3 ${../../../scripts/prepare-family-apps.py} "$@"'';
  };
  backup = pkgs.writeShellApplication {
    name = "backup-family-apps";
    runtimeInputs = [ pkgs.python3 pkgs.util-linux pkgs.docker pkgs.zfs ];
    text = ''exec python3 ${../../../scripts/backup-family-apps.py} "$@"'';
  };
in
{
  # Applications, databases and brokers are managed by Compose/Portainer.
  # The host only supplies storage protection and a coordinated local backup.
  environment.systemPackages = [ prepare backup ];

  # Docker restores unless-stopped containers at boot, outside Compose's
  # startup checks. Never start it against an unmounted application dataset.
  # Deliberately fail closed for the whole daemon if either dataset is missing.
  systemd.services.docker = {
    after = [ "zfs-mount.service" ];
    unitConfig = {
      RequiresMountsFor = [ "/storage/apps/nextcloud" "/storage/apps/paperless" ];
      AssertPathIsMountPoint = [ "/storage/apps/nextcloud" "/storage/apps/paperless" ];
    };
  };

  systemd.services.family-apps-backup = {
    description = "Quiesce family containers, dump databases and snapshot datasets";
    requires = [ "docker.service" ];
    after = [ "docker.service" ];
    startAt = "*-*-* 02:30:00";
    unitConfig.ConditionPathExists = [
      "/storage/apps/nextcloud/.compose-layout-v1"
      "/storage/apps/paperless/.compose-layout-v1"
    ];
    serviceConfig = {
      Type = "oneshot";
      UMask = "0077";
      TimeoutStartSec = "30min";
      ExecStart = "${backup}/bin/backup-family-apps";
    };
  };
}
