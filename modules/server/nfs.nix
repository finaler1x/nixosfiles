{ config, pkgs, ... }:

{
  services.nfs.server = {
    enable = true;

    # ── NFS Exports ───────────────────────────────────────
    # Adjust the subnet (192.168.1.0/24) to match your local network.
    # After changing, run: sudo exportfs -ra
    exports = ''
      # service-vm: Immich (media) + Paperless (documents) + container data
      /mnt/storage/media          192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
      /mnt/storage/documents      192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
      /mnt/storage/docker/service-vm  192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)

      # dev-vm: full storage pool (Code Server access) + container data
      /mnt/storage                192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
      /mnt/storage/docker/dev-vm  192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
    '';
  };

  # Open NFS port in firewall
  networking.firewall.allowedTCPPorts = [ 2049 ];
  networking.firewall.allowedUDPPorts = [ 2049 ];
}
