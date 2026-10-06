# Shared checks for a Git checkout or the Docker script's filtered snapshot.
flake:
let
  cfg = flake.nixosConfigurations.homelab.config;
  lib = flake.inputs.nixpkgs.lib;
  dockerCfg = (flake.nixosConfigurations.homelab.extendModules {
    modules = [ { homelab.immichDeployment = lib.mkForce "docker"; } ];
  }).config;
  checks = {
    nixosAssertions = lib.all (a: a.assertion) cfg.assertions;
    nativeAppsDisabled = !cfg.services.nextcloud.enable && !cfg.services.paperless.enable;
    noNativeProxy = !cfg.services.nginx.enable;
    dockerEnabled = cfg.virtualisation.docker.enable;
    dockerMountGuards = lib.all
      (path: builtins.elem path cfg.systemd.services.docker.unitConfig.AssertPathIsMountPoint)
      [ "/storage/apps/nextcloud" "/storage/apps/paperless" ];
    noFamilyDatabasesInHostCluster = lib.all
      (name: !(builtins.elem name cfg.services.postgresql.ensureDatabases))
      [ "nextcloud" "paperless" ];
    # NixOS normalizes startAt to a list even when configured as one string.
    coordinatedBackupRegistered = cfg.systemd.services.family-apps-backup.enable
      && cfg.systemd.services.family-apps-backup.startAt == [ "*-*-* 02:30:00" ];
    existingSnapshotsPreserved = lib.all
      (dataset: cfg.services.sanoid.datasets.${dataset}.useTemplate == [ "data" ])
      [ "storage/apps/nextcloud" "storage/apps/paperless" ];
    existingImmichPreserved = cfg.services.immich.enable;
    immichApplicationOwner = cfg.systemd.services.immich-server.enable == (cfg.homelab.immichDeployment == "native");
    immichDockerVariantValid = lib.all (a: a.assertion) dockerCfg.assertions;
    immichDockerMasksNative = !dockerCfg.systemd.services.immich-server.enable;
    immichRollbackPackageRetained = lib.any
      (package: toString package == toString dockerCfg.services.immich.package)
      dockerCfg.system.extraDependencies;
    immichRollbackDependenciesPreserved = dockerCfg.services.postgresql.enable
      && dockerCfg.services.redis.servers.immich.enable
      && dockerCfg.services.immich.mediaLocation == "/storage/apps/immich";
    immichDockerStorageProtected = lib.all
      (path: builtins.elem path dockerCfg.systemd.services.docker.unitConfig.AssertPathIsMountPoint)
      [ "/storage/apps/immich-docker" "/storage/apps/immich-docker/media" ];
    immichDockerSnapshotsRecursive = dockerCfg.services.sanoid.datasets."storage/apps/immich-docker".recursive == "zfs";
  };
in
builtins.mapAttrs (name: passed:
  if passed then true else throw "Family application check failed: ${name}"
) checks
