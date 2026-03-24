{ config, lib, pkgs, modulesPath, ... }:

{
  # ── PLACEHOLDER ───────────────────────────────────────
  # Replace this file with the output of:
  #   nixos-generate-config --show-hardware-config
  # Run that command on the actual VM after installing NixOS.

  imports = [
    (modulesPath + "/profiles/hyperv-guest.nix")
  ];

  # Hyper-V kernel modules (hyperv-guest.nix includes most, these are extra)
  boot.initrd.availableKernelModules = [
    "hv_vmbus" "hv_storvsc" "hv_blkvsc" "hv_netvsc"
    "sd_mod" "sr_mod"
  ];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];

  # Adjust device labels/UUIDs after installation
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
