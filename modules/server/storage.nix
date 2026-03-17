{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ mergerfs ];

  # Jede Datenplatte einzeln mounten
  # UUIDs anpassen nach: sudo blkid
  fileSystems."/mnt/disk1" = {
    device = "/dev/disk/by-uuid/UUID-PLATTE-1";
    fsType = "ext4";
    options = [ "nofail" ];
  };
  fileSystems."/mnt/disk2" = {
    device = "/dev/disk/by-uuid/UUID-PLATTE-2";
    fsType = "ext4";
    options = [ "nofail" ];
  };
  fileSystems."/mnt/disk3" = {
    device = "/dev/disk/by-uuid/UUID-PLATTE-3";
    fsType = "ext4";
    options = [ "nofail" ];
  };
  fileSystems."/mnt/disk4" = {
    device = "/dev/disk/by-uuid/UUID-PLATTE-4";
    fsType = "ext4";
    options = [ "nofail" ];
  };
  fileSystems."/mnt/disk5" = {
    device = "/dev/disk/by-uuid/UUID-PLATTE-5";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  # disk6 = Parity für SnapRAID
  fileSystems."/mnt/parity1" = {
    device = "/dev/disk/by-uuid/UUID-PLATTE-6";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  # MergerFS: vereint disk1-5 zu einem Pool
  fileSystems."/mnt/data" = {
    device = "/mnt/disk1:/mnt/disk2:/mnt/disk3:/mnt/disk4:/mnt/disk5";
    fsType = "fuse.mergerfs";
    options = [
      "defaults"
      "allow_other"
      "use_ino"
      "category.create=mfs"
      "minfreespace=20G"
      "fsname=mergerfs"
    ];
  };
}
