{ config, pkgs, ... }:

{
  sops = {
    defaultSopsFile = ../secrets/nas.yaml;
    defaultSopsFormat = "yaml";

    # Decrypt using the SSH host key — no extra key management needed.
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      "samba/antonio_password"  = {};
      "vaultwarden/admin_token" = {
        # Mounted into the Vaultwarden container at this path
        path = "/run/secrets/vaultwarden/admin_token";
      };
      "ntfy/admin_password"     = {};
      "tailscale/auth_key"      = {};
      "restic/password"         = {};
      "gaming_rig_mac"          = {};
    };
  };

  environment.systemPackages = with pkgs; [ sops age ssh-to-age ];
}
