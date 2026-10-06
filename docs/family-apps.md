# Family applications: Compose, with NixOS as the host

## Ownership and versions

`modules/docker/homelab/docker-compose.yml` is the source of truth. Use Portainer
for status, logs and controlled restarts. A stack deployed with host Compose is
external to Portainer; do not create a second stack or edit images independently
in its UI. Portainer Git-stack deployment would additionally require making its
file-backed credentials/config paths available to the stack runner; that is not
configured here. The supported deployment path below is host Compose.

| Service | Pinned image version | Persistent location | URL |
| --- | --- | --- | --- |
| Nextcloud + cron | 33.0.9-apache | `/storage/apps/nextcloud/html` | `https://cloud.homelab` |
| Paperless-ngx | 3.3.0 | `/storage/apps/paperless/{data,media,consume,export}` | `https://docs.homelab` |
| PostgreSQL, one per app | 18.4 | each app's `postgres` directory | no published port |
| Redis, one per app | 8.2.10-alpine3.22 | each app's `redis` directory | no published port |

All seven containers have immutable image digests and are excluded from
Watchtower. Updating requires reviewing and changing both the tag and digest.
No image is pulled by a NixOS rebuild. Immich remains native at its existing pin;
Vaultwarden, other services, flake inputs and `stateVersion` are unchanged.
The new databases are separate containers: never restore them over Immich's
host PostgreSQL cluster. PostgreSQL 18 mounts `/var/lib/postgresql`, not the old
`/var/lib/postgresql/data` layout.

## Fresh installation only

Paperless is a fresh 3.3 installation, not a 2.x migration. Nextcloud must also
be fresh for this procedure. If either native application has been activated
with real data, stop and plan a separate export/restore migration first.

The preparation utility verifies BOTH mounted datasets before creating anything:

- `storage/apps/nextcloud` at `/storage/apps/nextcloud`
- `storage/apps/paperless` at `/storage/apps/paperless`

It refuses nonempty, unmarked datasets, so an old native config/database/media
directory is not silently reused. It does not delete/import data, touch
`/storage/restore`, rotate existing credentials, or recursively chown directories.
Containers receive only their own subdirectories; never mount the entire
Nextcloud dataset at `/var/www/html` (image initialization uses `rsync --delete`).

Before a host rebuild, check for accidentally initialized native data:

```sh
zfs list -o name,mountpoint,mounted storage/apps/nextcloud storage/apps/paperless
sudo find /storage/apps/nextcloud /storage/apps/paperless -mindepth 1 -maxdepth 1
```

For a new installation these should be empty. Existing native state is not
deleted by this change, including any databases remaining in host PostgreSQL.

## Validation (including Docker-only development machines)

Stage only intended new source/test files so the Git-filtered snapshot includes
them. Never use `git add .` for credential-bearing working directories.

```sh
sudo ./scripts/check-flake-docker.sh --full
```

Omit sudo if your user has Docker access. The script checks the flake, runs the
Compose/maintenance regression tests with mocked operational commands, evaluates
NixOS host invariants, and builds the host configuration in one disposable Nix
container. It stops at the first error and does not deploy/activate anything.
It streams indexed working-tree files, not `.git` or untracked credentials, into
the container. Without `--full`, it only checks the flake without building.
The disposable build can take substantial disk space/time and is not cached
between runs. Image downloads, application startup and migrations are NOT tested
by this check; perform the acceptance checks below on homelab.

On a native Nix development machine, the host checks are still available:

```sh
nix eval --impure --json --file tests/family-apps.nix
nix build .#nixosConfigurations.homelab.config.system.build.toplevel --no-link
```

## Host preparation and credentials

After validation and the fresh-data check, apply on homelab:

```sh
sudo nixos-rebuild switch --flake .#homelab
sudo prepare-family-apps
```

NixOS no longer enables native Nextcloud/Paperless/nginx. It provides the two
maintenance utilities and a daily backup timer. **Docker startup now requires
both family datasets to be mounted. If either is unavailable, the whole Docker
daemon fails closed**, including existing containers. Restore the ZFS mounts
before restarting Docker; do not remove this check to create data on the root
filesystem. Long bind syntax also disables automatic source-directory creation.

`prepare-family-apps` is root-only and idempotent. It creates private directories
and five random, newline-free credential files under
`/var/lib/homelab-app-credentials`. The parent is root-only `0700`; the files are
readable by the selected container users through Compose secret mounts. Standalone
Compose secrets are file bind mounts, not an encrypted vault.

- `nextcloud_admin`: initial password for **nc-admin**
- `paperless_admin`: initial password for **paperless-admin**
- `nextcloud_db`, `paperless_db`: independent database credentials
- `paperless_key`: persistent application signing key

Read the two initial administrator credentials locally with root privileges,
store them in your password manager and do not paste them in chat or Git.
Bootstrap passwords do not reset an existing account. Editing a database
credential file does not rotate the PostgreSQL role password. Lost database
credentials/application keys must be restored, not regenerated after setup.
Backup the credential directory encrypted off-pool alongside application backups.

## Network and deployment

Caddy remains the only remote entry point through its existing Tailscale-bound
80/443 publications and internal CA. No new app/database/broker host ports are
published. Nextcloud and Paperless share a dedicated proxy network with Caddy;
each database and unauthenticated Redis broker is confined to its own internal
backend network. Caddy has fixed proxy address **172.30.50.2**; dynamic app IPs
come from **172.30.50.8/29**, inside **172.30.50.0/28**. Check this subnet does not
overlap an existing LAN/VPN/Docker route before deployment. Both apps trust only
that Caddy address for forwarding headers, not the entire homelab subnet.

In AdGuard, resolve `cloud.homelab` and `docs.homelab` to the NAS Tailscale IP.
Family devices need Tailscale access to that DNS server and must trust Caddy's
root CA in the actual browser/app client. Do not disable certificate validation.
Use one Tailscale identity and one application account per person. Check your
Tailscale plan's four-user allowance. No router forwarding/Funnel is required.

Existing tailnet ACLs/grants are outside the repo. Since admin sites share
Caddy's 443 port, granting that port does not restrict users to family hostnames.
This change does not implement hostname-level access separation from Cockpit,
Portainer, etc.; never give family users Docker/root/admin access by default.

From `modules/docker/homelab` on homelab, retaining its existing local environment:

```sh
sudo docker compose config --quiet
sudo docker compose up -d nextcloud nextcloud-cron paperless
sudo docker exec -i caddy caddy validate --config - --adapter caddyfile < Caddyfile
sudo docker compose up -d --no-deps caddy
sudo docker compose ps
```

Dependencies start automatically. Nextcloud's automatic installer uses the
generated admin credentials; cron waits for its installed/ready healthcheck.
Paperless has its own bootstrap administrator and built-in startup migrations.
Allow several minutes for first initialization; inspect logs if readiness fails.
Do not erase volumes or replace credentials as a startup repair.

Caddy must be recreated to join the new network and remove its old native-socket
mount; reload alone is insufficient. The brief recreation affects other proxy
sites. Do not update/recreate the whole stack or use `--remove-orphans` here.

## Four-person setup and verification

Log in as **nc-admin** and **paperless-admin** only for administration. Create
four ordinary accounts and a `familie` group in each application.

For Nextcloud, install **Team folders** (`groupfolders`, compatible NC33 release
21.0.15) from the App Store. It is no longer supplied by a Nix package. Create a
`Familie` Team Folder and grant the group the required read/write permissions.
Select Cron background jobs (the container executes them every five minutes):

```sh
sudo docker compose exec -u www-data nextcloud php occ background:cron
sudo docker compose exec -u www-data nextcloud php occ config:system:set default_phone_region --value=DE
sudo docker compose exec -u www-data nextcloud php occ status
```

Set individual quotas deliberately. Verify private files are mutually hidden,
the shared folder works, desktop/mobile sync and DAV discovery work, and login
URLs stay HTTPS. Keep photo backup in Immich rather than duplicating it by default.

For Paperless, grant ordinary application permissions, including UI settings
view, but not superuser/workflow-management rights. **Ownerless documents are
not private; tag permissions are not document permissions.** Verify ownership
for authenticated uploads with two ordinary accounts, including direct document
URLs/API and search. Shared documents need explicit `familie` view/edit rights.
Do not expose the private consume folder until ownership workflows are tested;
successfully consumed files disappear from that input folder. Never connect it
to Nextcloud's internal data or your original NAS backup.

Paperless starts with local German/English OCR, no optional AI/remote OCR or
Office-conversion services. v3 accepts duplicates by default; review them rather
than silently deleting incoming files. Test a scan, searchable text, upload
progress and document permissions. Confirm both apps survive a host reboot,
report real client addresses, and remain unreachable through unintended LAN or
public host ports. Changing image versions requires these checks again.

## Backup, updates and rollback

At 02:30, `family-apps-backup.service` verifies mounts and that app/database
containers are running. It stops only Nextcloud, its cron container and Paperless,
writes PostgreSQL custom-format dumps to each app's `backup/database.dump`, then
atomically snapshots both datasets with a `family-<UTC timestamp>` name. It tries
to restart all three writers even if a dump/snapshot fails. Only its seven newest
snapshot names per dataset are kept; **older matching `family-*` restore points
are automatically deleted**. Sanoid/user snapshots are not pruned by this job.
Do not use that reserved snapshot naming scheme for manual backups. Nested
datasets are refused, not silently omitted.

This replaces the native database dumps and scheduled Paperless exporter with
coordinated local restore points, briefly interrupting both apps. No existing
database dumps or exports are deleted. Check the timer/logs, test a manual run
when downtime is acceptable (`sudo backup-family-apps`), and perform an isolated
restore test before trusting it. A forced process/host kill can prevent automatic
restart; check the three containers and restart them if required.

These snapshots are **not independent backups**. Copy a matching snapshot (with
its database dumps) and the separate credential directory to an encrypted
off-pool destination. Do not mix a dump from one restore point with media/config
from another. Do not restore a running PostgreSQL data directory as a substitute
for an intentional recovery plan; use the logical dump with the matching app
files on an isolated test stack first. Do not alter Immich's host database.

For a portable Paperless export, the official command is also available:

```sh
sudo docker compose exec -T paperless document_exporter ../export
```

That manual live export is not the coordinated snapshot job above. Keep the
output private and copy it off-pool. Review version-specific restore guidance:

- https://docs.nextcloud.com/server/33/admin_manual/maintenance/backup.html
- https://docs.nextcloud.com/server/33/admin_manual/maintenance/restore.html
- https://github.com/paperless-ngx/paperless-ngx/blob/v3.3.0/docs/administration.md

Before updates, back up and review release notes, especially database and app
major changes. Image rollback does not undo a migrated database. To stop the
new apps without deleting data, use targeted `docker compose stop` for the seven
family services and adjust the two proxy routes. Never use `down -v` as rollback.
