{ config, lib, ... }:

let
  # Trust forwarding headers only on sockets accessible to nginx and the
  # rootful Caddy container. No TCP listener bypasses the HTTPS entry point.
  socketProxyConfig = ''
    set_real_ip_from unix:;
    real_ip_header X-Forwarded-For;
    real_ip_recursive on;
  '';

  storageGuard = mountpoint: {
    after = [ "zfs-mount.service" ];
    unitConfig = {
      RequiresMountsFor = mountpoint;
      AssertPathIsMountPoint = mountpoint;
    };
  };
in
{
  imports = [
    ./nextcloud.nix
    ./paperless.nix
  ];

  services.nginx.virtualHosts = {
    "cloud.homelab" = {
      listen = [ { addr = "unix:/run/family-web/nextcloud.sock"; } ];
      extraConfig = socketProxyConfig;
    };
    "docs.homelab" = {
      listen = [ { addr = "unix:/run/family-web/paperless.sock"; } ];
      extraConfig = socketProxyConfig + ''
        client_max_body_size 100m;
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.paperless.port}";
        proxyWebsockets = true;
        # Do not also emit the recommended X-Forwarded-Proto $scheme (http).
        recommendedProxySettings = false;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $remote_addr;
          proxy_set_header X-Forwarded-Proto https;
          proxy_read_timeout 300s;
        '';
      };
    };
  };

  # Mount the directory into Caddy, not individual sockets. Keep its inode
  # across nginx restarts; RuntimeDirectory would remove it when nginx stops.
  systemd.tmpfiles.rules = [ "d /run/family-web 0700 nginx nginx - -" ];

  # Fail closed instead of putting application data on the root filesystem
  # when an expected ZFS dataset is not mounted. No existing data is imported.
  systemd.services = lib.mkMerge [
    (lib.genAttrs [
      "nextcloud-setup"
      "nextcloud-update-db"
      "nextcloud-cron"
      "phpfpm-nextcloud"
    ] (_: storageGuard "/storage/apps/nextcloud"))
    (lib.genAttrs [
      "paperless-scheduler"
      "paperless-consumer"
      "paperless-task-queue"
      "paperless-web"
      "paperless-exporter"
    ] (_: storageGuard "/storage/apps/paperless"))
    {
      phpfpm-nextcloud.requires = [ "nextcloud-setup.service" ];
      nginx.serviceConfig.ReadWritePaths = [ "/run/family-web" ];
      docker = {
        requires = [ "systemd-tmpfiles-setup.service" ];
        after = [ "systemd-tmpfiles-setup.service" ];
      };
    }
  ];

  # Logical DB copies complement file snapshots, but are NOT a coordinated
  # application backup or an off-pool backup. See the deployment guide.
  services.postgresqlBackup = {
    enable = true;
    databases = [ "nextcloud" "paperless" ];
    startAt = "*-*-* 03:30:00";
  };
}
