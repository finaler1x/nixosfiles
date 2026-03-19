{ config, pkgs, ... }:

{
  services.samba = {
    enable = true;
    settings = {
      global = {
        security = "user";
        "server string" = "homelab";
        "map to guest" = "Never";
        "socket options" = "TCP_NODELAY IPTOS_LOWDELAY";
        "use sendfile" = "yes";
        # macOS (Finder) compatibility
        "vfs objects" = "catia fruit streams_xattr";
        "fruit:metadata" = "stream";
        "fruit:model" = "MacSamba";
        "fruit:posix_rename" = "yes";
        "fruit:veto_appledouble" = "no";
        "fruit:wipe_intentionally_left_blank_rfork" = "yes";
        "fruit:delete_empty_adfiles" = "yes";
      };

      media = {
        path = "/mnt/storage/media";
        comment = "Media Library";
        "read only" = "no";
        "valid users" = "antonio";
        "create mask" = "0664";
        "directory mask" = "0775";
        browseable = "yes";
      };

      documents = {
        path = "/mnt/storage/documents";
        comment = "Documents";
        "read only" = "no";
        "valid users" = "antonio";
        "create mask" = "0644";
        "directory mask" = "0755";
        browseable = "yes";
      };

      backups = {
        path = "/mnt/storage/backups";
        comment = "Backups";
        "read only" = "no";
        "valid users" = "antonio";
        "create mask" = "0644";
        "directory mask" = "0755";
        browseable = "yes";
      };

      shares = {
        path = "/mnt/storage/shares";
        comment = "Shared Files";
        "read only" = "no";
        "valid users" = "antonio";
        "create mask" = "0664";
        "directory mask" = "0775";
        browseable = "yes";
      };
    };
  };

  # Samba password must be set once per user:
  # sudo smbpasswd -a antonio

  # Network discovery (Windows + Linux)
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };
}
