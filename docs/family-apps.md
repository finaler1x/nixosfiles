# Family files and documents

## Service boundaries

- **Nextcloud:** `https://cloud.homelab`, four ordinary personal accounts and a
  shared Team Folder. Native NixOS, PostgreSQL and Redis, with Team folders
  installed declaratively. No Office server, SMTP or public federation setup.
- **Paperless-ngx:** `https://docs.homelab`, private documents plus explicit
  family sharing. Native NixOS, PostgreSQL, Redis and German/English OCR. Start
  with authenticated browser uploads; no shared scanner or email intake yet.
- **Immich:** unchanged. Do not enable a second automatic photo upload in
  Nextcloud unless you deliberately want duplicate copies.
- **Filebrowser:** removed from configuration. Its old database and all NAS
  files are preserved. A previously running container must be stopped separately.

The current lock selects Nextcloud 33.0.0, Team folders 21.0.6 and Paperless
2.20.11. Do not apply instructions for Paperless 3.x blindly. Review supported
patch releases/security advisories before production use; changing the main
nixpkgs input affects the entire host. Nextcloud major upgrades must be sequential.
Watchtower does not manage these native applications.

## Storage and network prerequisites

The existing ZFS datasets must be mounted at these exact paths:

| Dataset | Mountpoint | Contents |
| --- | --- | --- |
| `storage/apps/nextcloud` | `/storage/apps/nextcloud` | config, user files, application state |
| `storage/apps/paperless` | `/storage/apps/paperless` | media, index, private consume directory, application key, export |

Check on homelab before rebuilding:

```sh
zfs list -o name,mountpoint,mounted storage/apps/nextcloud storage/apps/paperless
findmnt --mountpoint /storage/apps/nextcloud
findmnt --mountpoint /storage/apps/paperless
```

Both datasets must be mounted (`yes`) and initially empty of unrelated data.
Do not recursively chown or import `/storage/restore`. The application service
units fail if their dataset mountpoint is absent. NixOS tmpfiles may create empty
directories/configuration links before a missing mount is repaired; do not
manually start application tools against such an unmounted path.

The databases live in the existing host PostgreSQL cluster, **not** these ZFS
datasets. Immich's cluster location and version are unchanged.

Caddy remains the only remote entry point, using its existing Tailscale-bound
80/443 publications and internal CA. nginx listens on two UNIX sockets; Paperless
itself listens only on loopback. No new LAN/Tailscale TCP ports are opened.

Only the Caddy container receives `/run/family-web` as a read-only directory
mount. The directory is mode 0700, owned by nginx; this assumes rootful Docker,
Caddy running as root and no user-namespace remapping. Do not grant family users
the Docker group or mount this directory in other containers. Socket access
permits application requests despite the read-only mount. nginx restores the
client IP from Caddy's forwarding header only on those private sockets.

Configure `cloud.homelab` and `docs.homelab` in AdGuard to resolve to the NAS's
Tailscale IP, and make that DNS server available to the family devices through
Tailscale. Each person uses their own Tailscale identity and application account.
Check the Tailscale plan's current user allowance for four people. Trust Caddy's
root CA on every browser/app client; do not disable certificate verification.
Applications may have platform-specific CA trust requirements.

No router port forwarding or Tailscale Funnel is needed. Tailnet membership
alone is not a least-privilege policy: existing tailnet ACLs/grants are outside
this repository. The host trusts `tailscale0`, and several admin sites share
Caddy's port 443. A grant to that port reaches all those sites, not just these
two hostnames. Do not give family members broad network access assuming this
configuration prevents access to Cockpit/Portainer/SSH. A hostname-aware access
boundary or separate listener/node needs a separate design if that is required.

## Activation and administrator bootstrap

On a Docker-only machine, run all pre-deployment checks with:

```sh
sudo ./scripts/check-flake-docker.sh --full
```

Omit sudo if your user already has Docker access. This runs flake evaluation,
the family application invariants and the homelab system build **inside the same
container**, stopping at the first failure. No local Nix installation is needed,
and nothing is deployed or activated. The build can take substantial time and
disk space. The container's Nix store is disposable: a subsequent run downloads
or builds again. Boot/login/upload/permission tests still require homelab.

Without `--full`, the script retains its build-free flake evaluation behavior.
It streams only Git-indexed working-tree files into a disposable container-owned
directory, preserving edits/staged additions but excluding `.git` and untracked
files. This avoids libgit2's host/container ownership mismatch without changing
Git trust settings or host file ownership. Untracked Nix files are rejected with
an instruction to stage the intended files. The `path:/workspace` source used
inside the container contains only that filtered snapshot; the native test
entry point below continues to use Git filtering. Script regression tests run
without Docker using:

```sh
python3 -B -m unittest discover -s tests -p 'test_check_flake_docker.py' -v
```

From the updated repository on a Nix-enabled machine:

```sh
nix eval --impure --json --file tests/family-apps.nix
nix build .#nixosConfigurations.homelab.config.system.build.toplevel --no-link
```

New modules must be tracked by Git to participate in flake evaluation. If
testing uncommitted changes, stage only the intended new module/test files,
never `.env` or credential files. Do not use `path:.` to bypass Git filtering:
that can copy untracked credentials into the Nix store. After the checks pass,
deploy on homelab:

```sh
sudo nixos-rebuild switch --flake .#homelab
sudo systemctl status nextcloud-setup paperless-scheduler nginx --no-pager
```

Neither application has a default username/password. Create separate admin
accounts interactively after setup succeeds; do not put passwords in shell
arguments, the repository or chat:

```sh
sudo nextcloud-occ user:add --group admin nc-admin
sudo paperless-manage createsuperuser
```

These are initial creation commands, not password reset commands. Keep admin
credentials in your password manager. Leaving bootstrap incomplete leaves the
applications without a usable administrator; it does not enable anonymous login.

The Compose directory on homelab must contain the updated Compose file and
Caddyfile and retain its existing local environment. From that directory:

```sh
sudo docker compose config --quiet
sudo docker compose run --rm --no-deps caddy caddy validate --config /etc/caddy/Caddyfile
sudo docker compose up -d --no-deps caddy
```

Recreating Caddy is necessary for the new socket-directory mount; reload alone
is insufficient the first time. This briefly affects the existing proxy sites.
Do not run a whole-stack update or `--remove-orphans` just for these services.

If the old Filebrowser container still exists, stop it and disable its restart
policy without deleting its data:

```sh
sudo docker update --restart=no filebrowser
sudo docker stop filebrowser
```

## Four-person onboarding

In Nextcloud, create four **ordinary** users and a `familie` group. Add those users
to the group. In the administration settings for Team folders, create `Familie`
and grant that group the intended read/write permissions. Personal file areas
remain separate. Decide quotas based on pool capacity; no names, passwords or
quotas are invented by the configuration. Configure the desktop/mobile clients
with `https://cloud.homelab` over Tailscale.

In Paperless, create four ordinary users and a `familie` group. Grant the needed
application permissions (including UI settings view permission), not superuser
or workflow-management rights. Explicitly set private documents' owner, with no
additional sharing. Shared documents have an owner plus view/edit permissions
for `familie`. Superusers can always see all documents.

**Ownerless Paperless documents are not private.** Tag permissions do not grant
or restrict document access. Before any shared scanner/mail intake, configure
and test ownership workflows for each source. The consume directory is private
and is not shared over Samba. Files successfully consumed are removed from that
directory; never point it at a NAS backup or Nextcloud's internal data directory.

## Acceptance checks before real family data

- Both HTTPS URLs validate without certificate warnings on phones and PCs,
  locally and over mobile data with Tailscale. Without Tailscale, there is no
  unintended LAN/public entry point.
- Login/logout and Nextcloud desktop/WebDAV upload/download work; DAV discovery
  redirects to `/remote.php/dav/`. Test a large file within the 512 MiB request
  limit (sync clients may use chunks).
- A German scanned PDF in Paperless is OCR-searchable; upload progress/WebSocket
  updates work. Its nginx upload limit is 100 MiB per request.
- With two ordinary test accounts, private documents/files are mutually hidden;
  shared family content is accessible. Test permissions using the direct document
  URL/API as well as search, not just dashboard visibility.
- Application logs show the client address, not one shared proxy address;
  user-supplied `X-Forwarded-For` must not override it.
- `ss -ltn` shows Paperless only on `127.0.0.1:28981`, with no new nginx TCP
  listener. Caddy's existing published ports remain Tailscale-bound.
- After restarting nginx, Caddy still connects without recreation. After a host
  reboot, datasets, sockets, PostgreSQL, Redis, cron and both apps recover.
- `sudo nextcloud-occ status` and `sudo nextcloud-occ app:list` show a healthy
  installation and enabled `groupfolders`.
- `systemctl list-timers` includes Nextcloud cron, Paperless export and database
  backup timers. Inspect failures with `journalctl -u <unit>`.

## Backup and recovery boundary

Existing Sanoid snapshots cover both application datasets. Daily PostgreSQL
dumps of `nextcloud` and `paperless` are configured at 03:30 in the NixOS default
`/var/backup/postgresql`. Paperless exports run at 02:30 into its dataset's
`export` directory; the upstream module temporarily stops its application
services during export and restarts them on success or failure. Allow capacity
for the additional exported documents. These copies contain sensitive data.

**This is not yet an independent, coordinated family-data backup.** In
particular, a Nextcloud file snapshot and a database dump from different times
are not guaranteed to form a consistent restore point. Before relying on the
services, choose an encrypted off-pool destination, capture Nextcloud config,
data and database while writes/background jobs are quiesced, copy the Paperless
export and relevant configuration/key material, and test restoration in an
isolated instance. Do not restore these applications over the live shared
PostgreSQL cluster or disturb Immich.

Relevant upstream guidance:
- https://docs.nextcloud.com/server/33/admin_manual/maintenance/backup.html
- https://docs.nextcloud.com/server/33/admin_manual/maintenance/restore.html
- https://github.com/paperless-ngx/paperless-ngx/blob/v2.20.11/docs/administration.md
- https://github.com/paperless-ngx/paperless-ngx/blob/v2.20.11/docs/usage.md#permissions

Removing the NixOS imports disables the applications but does not constitute
data deletion. Preserve datasets, databases and the previous configuration.
After an application schema migration, a NixOS generation rollback alone is
**not** a safe application downgrade: restore matching files and database from
a tested backup instead.
