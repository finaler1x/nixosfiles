{ ... }:

{
  # HDD health monitoring.
  # Only monitors; no automatic long tests configured here.
  services.smartd = {
    enable = true;
    autodetect = true;
  };

  # Automatic ZFS snapshots + pruning.
  services.sanoid = {
    enable = true;
    interval = "hourly";

    templates.data = {
      # Explicitly define every retention class so we don't inherit
      # unexpected Sanoid defaults.
      frequently = 0;
      hourly = 24;
      daily = 14;
      weekly = 8;
      monthly = 6;
      yearly = 0;

      autosnap = true;
      autoprune = true;
    };

    datasets = {
      # Includes originals + exports atomically.
      "storage/photography/ante" = {
        useTemplate = [ "data" ];
        recursive = "zfs";
      };

      "storage/apps/immich" = {
        useTemplate = [ "data" ];
      };

      "storage/apps/nextcloud" = {
        useTemplate = [ "data" ];
      };

      "storage/apps/paperless" = {
        useTemplate = [ "data" ];
      };

      # storage/restore intentionally NOT included.
    };
  };
}
