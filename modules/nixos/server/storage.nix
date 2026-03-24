{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ mergerfs ];

  # ── Individual disk mounts ─────────────────────────────
  # Adjust UUIDs after: sudo blkid
  fileSystems."/mnt/disk1" = {
    device = "/dev/disk/by-uuid/UUID-DISK-1";
    fsType = "ext4";
    options = [ "nofail" "defaults" ];
  };
  fileSystems."/mnt/disk2" = {
    device = "/dev/disk/by-uuid/UUID-DISK-2";
    fsType = "ext4";
    options = [ "nofail" "defaults" ];
  };
  fileSystems."/mnt/disk3" = {
    device = "/dev/disk/by-uuid/UUID-DISK-3";
    fsType = "ext4";
    options = [ "nofail" "defaults" ];
  };
  fileSystems."/mnt/disk4" = {
    device = "/dev/disk/by-uuid/UUID-DISK-4";
    fsType = "ext4";
    options = [ "nofail" "defaults" ];
  };

  # ── Parity disk (SnapRAID) ────────────────────────────
  fileSystems."/mnt/parity1" = {
    device = "/dev/disk/by-uuid/UUID-PARITY-1";
    fsType = "ext4";
    options = [ "nofail" "defaults" ];
  };

  # ── MergerFS: pool disk1–4 → /mnt/storage ─────────────
  # epmfs = existing path, most free space (balances across disks)
  fileSystems."/mnt/storage" = {
    device = "/mnt/disk1:/mnt/disk2:/mnt/disk3:/mnt/disk4";
    fsType = "fuse.mergerfs";
    options = [
      "defaults"
      "allow_other"
      "use_ino"
      "category.create=epmfs"
      "minfreespace=20G"
      "fsname=mergerfs"
    ];
  };

  # ── Directory structure ───────────────────────────────
  systemd.tmpfiles.rules = [
    "d /mnt/storage/media              0775 antonio users -"
    "d /mnt/storage/documents          0775 antonio users -"
    "d /mnt/storage/backups            0775 antonio users -"
    "d /mnt/storage/shares             0775 antonio users -"
    "d /mnt/storage/docker             0775 antonio users -"
    "d /mnt/storage/docker/nas         0775 antonio users -"
    "d /mnt/storage/docker/service-vm  0775 antonio users -"
    "d /mnt/storage/docker/dev-vm      0775 antonio users -"
    "d /mnt/storage/syncthing          0775 antonio users -"
  ];
}
