# Shared checks for a Git checkout or the Docker script's filtered snapshot.
flake:
let
  cfg = flake.nixosConfigurations.homelab.config;
  lib = flake.inputs.nixpkgs.lib;
  checks = {
    nixosAssertions = lib.all (a: a.assertion) cfg.assertions;
    nextcloudEnabled = cfg.services.nextcloud.enable;
    paperlessEnabled = cfg.services.paperless.enable;
    noNginxTcpListeners = lib.all
      (host: host.listen != [ ]
        && lib.all (listener: lib.hasPrefix "unix:" listener.addr && listener.port == null) host.listen
        && !host.forceSSL && !host.addSSL && !host.onlySSL)
      (builtins.attrValues cfg.services.nginx.virtualHosts);
    nextcloudPrivateListener = cfg.services.nginx.virtualHosts."cloud.homelab".listen == [
      {
        addr = "unix:/run/family-web/nextcloud.sock";
        port = null;
        ssl = false;
        proxyProtocol = false;
        extraParameters = [ ];
      }
    ];
    paperlessPrivateListener = cfg.services.nginx.virtualHosts."docs.homelab".listen == [
      {
        addr = "unix:/run/family-web/paperless.sock";
        port = null;
        ssl = false;
        proxyProtocol = false;
        extraParameters = [ ];
      }
    ] && cfg.services.paperless.address == "127.0.0.1";
    noBootstrapPasswords = cfg.services.nextcloud.config.adminuser == null
      && cfg.services.nextcloud.config.adminpassFile == null
      && cfg.services.paperless.passwordFile == null
      && !(cfg.services.paperless.settings ? PAPERLESS_AUTO_LOGIN_USERNAME);
    privatePaperlessInbox = !cfg.services.paperless.consumptionDirIsPublic
      && cfg.systemd.tmpfiles.settings."10-paperless"."/storage/apps/paperless/consume".d.mode == "0700";
    nextcloudStorageGuards = lib.all
      (name: cfg.systemd.services.${name}.unitConfig.AssertPathIsMountPoint == "/storage/apps/nextcloud")
      [ "nextcloud-setup" "nextcloud-update-db" "nextcloud-cron" "phpfpm-nextcloud" ];
    paperlessStorageGuards = lib.all
      (name: cfg.systemd.services.${name}.unitConfig.AssertPathIsMountPoint == "/storage/apps/paperless")
      [ "paperless-scheduler" "paperless-consumer" "paperless-task-queue" "paperless-web" "paperless-exporter" ];
    databasesManagedLocally = cfg.services.nextcloud.database.createLocally
      && cfg.services.paperless.database.createLocally
      && lib.all (name: builtins.elem name cfg.services.postgresql.ensureDatabases)
        [ "nextcloud" "paperless" ];
    databaseDumpsEnabled = cfg.services.postgresqlBackup.enable
      && lib.all (name: builtins.elem name cfg.services.postgresqlBackup.databases)
        [ "nextcloud" "paperless" ];
    familyFoldersInstalled = cfg.services.nextcloud.extraApps ? groupfolders;
    existingImmichPreserved = cfg.services.immich.enable;
  };
in
builtins.mapAttrs (name: passed:
  if passed then true else throw "Family application check failed: ${name}"
) checks
