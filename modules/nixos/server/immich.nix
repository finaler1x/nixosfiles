{ config, inputs, lib, pkgs, ... }:

let
  immichPkgs = inputs.immich-nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  dockerMode = config.homelab.immichDeployment == "docker";
in
{
  options.homelab.immichDeployment = lib.mkOption {
    type = lib.types.enum [ "native" "docker" ];
    default = "native";
    description = ''
      Immich application owner. Docker mode masks the native application but
      preserves its PostgreSQL/Redis configuration and original data for rollback.
      Set only during the cutover described in modules/docker/immich/README.md.
    '';
  };

  config = {
    services.immich = {
      enable = true;
      package = immichPkgs.immich;

      # Listen for direct LAN/Tailscale access and the Dockerized Caddy proxy.
      host = "0.0.0.0";
      port = 2283;
      openFirewall = false;

      # Phone uploads / Immich-managed originals live on ZFS.
      mediaLocation = "/storage/apps/immich";

      # No local ML service for now; configure ML through the Admin UI.
      machine-learning.enable = false;

      environment.IMMICH_LOG_LEVEL = "warn";
    };

    # Redis is managed by the NixOS Immich module.
    services.redis.servers.immich.logLevel = "warning";

    # Direct access is limited to LAN and Tailscale; Caddy uses the trusted bridge.
    networking.firewall.interfaces.enp0s31f6.allowedTCPPorts = [ 2283 ];
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 2283 ];

    # Keep the module enabled to retain native DB extensions, user identities,
    # Redis and package closure. Only its application is masked in Docker mode.
    systemd.services.immich-server.enable = !dockerMode;
    # A masked unit alone need not retain its executable in the system closure.
    # Keep the native package available even after old generations are pruned.
    system.extraDependencies = lib.optional dockerMode immichPkgs.immich;
    systemd.services.docker = lib.mkIf dockerMode {
      after = [ "zfs-mount.service" ];
      unitConfig = {
        RequiresMountsFor = [ "/storage/apps/immich-docker" "/storage/apps/immich-docker/media" ];
        AssertPathIsMountPoint = [ "/storage/apps/immich-docker" "/storage/apps/immich-docker/media" ];
      };
    };
    services.sanoid.datasets."storage/apps/immich-docker" = lib.mkIf dockerMode {
      useTemplate = [ "data" ];
      recursive = "zfs";
    };
  };
}
