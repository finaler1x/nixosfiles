{ config, pkgs, ... }:

{
  users.groups.photographers = { };
  users.users.antonio.extraGroups = [ "photographers" ];

  systemd.tmpfiles.rules = [
    "d /storage/photography/ante           0700 antonio photographers -"
    "d /storage/photography/ante/originals 0700 antonio photographers -"
    "d /storage/photography/ante/exports   0700 antonio photographers -"
  ];

  services.samba = {
    enable = true;
    nmbd.enable = false;
    winbindd.enable = false;
    openFirewall = false;

    settings = {
      global = {
        security = "user";
        "server string" = "homelab";
        "map to guest" = "Never";
        "smb ports" = "445";
        interfaces = "enp0s31f6 tailscale0";
        "bind interfaces only" = "yes";

        # macOS Finder compatibility and xattr-backed metadata.
        "vfs objects" = "catia fruit streams_xattr";
        "fruit:aapl" = "yes";
        "fruit:metadata" = "stream";
        "fruit:resource" = "stream";
        "fruit:encoding" = "native";
        "fruit:model" = "MacSamba";
        "fruit:posix_rename" = "yes";
        "fruit:veto_appledouble" = "no";
        "fruit:wipe_intentionally_left_blank_rfork" = "yes";
        "fruit:delete_empty_adfiles" = "yes";
        "ea support" = "yes";
        "store dos attributes" = "yes";
      };

      "ante-photography" = {
        path = "/storage/photography/ante";
        comment = "Ante Photography";
        browseable = "yes";
        "guest ok" = "no";
        "read only" = "no";
        "valid users" = "antonio";
        "force group" = "photographers";
        "create mask" = "0600";
        "force create mode" = "0600";
        "directory mask" = "0700";
        "force directory mode" = "0700";
      };
    };
  };

  networking.firewall.interfaces = {
    enp0s31f6.allowedTCPPorts = [ 445 ];
    tailscale0.allowedTCPPorts = [ 445 ];
  };

  # Activate the Samba account manually after deployment:
  # sudo smbpasswd -a antonio
}
