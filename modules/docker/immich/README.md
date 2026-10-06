# Prepared production cutover: Immich 3.2.4

**Preparation is not activation.** The repository defaults to
`homelab.immichDeployment = "native"`; no native service is stopped by adding this
Compose file. Do not execute the freeze/activation sections until the downtime
window has been explicitly agreed. Review other pending host changes too.

The isolated trial restored successfully; the user confirmed login, visible
photos and matching image/video counts. Original downloads/video playback still
belong in final acceptance. The trial is not the final data source: native
uploads may have continued after its snapshot.

The production stack uses the same three verified image references as the trial:
Immich 3.2.4, PostgreSQL 16.14 / VectorChord 1.1.1 / pgvector 0.8.5, and Valkey 9.
No application version upgrade is mixed into this cutover. New persistent state:

| Purpose | Location |
| --- | --- |
| Root dataset | `storage/apps/immich-docker`, mounted `/storage/apps/immich-docker` |
| Fresh final media clone | `storage/apps/immich-docker/media`, mounted below the root |
| New PostgreSQL files | `/storage/apps/immich-docker/postgres` |
| Final native dump | `/storage/apps/immich-docker/backup/immich-cutover.sql.gz` |
| New database credential | `/storage/apps/immich-docker/db-password` |

The native dataset/database and trial are preserved. The new media mount is
mapped to `/storage/apps/immich` only INSIDE the production container, preserving
stored paths without writing to the original host directory.

## Preflight, without stopping native Immich

Run from the updated repository root on homelab. Verify that `homelab` is the
existing external Docker bridge, its gateway is `172.18.0.1`, and LAN/Tailscale
addresses are still `192.168.178.75` and `100.99.212.33`. Production preserves
these direct port-2283 endpoints and loopback as well as Caddy's existing
`host.docker.internal:2283` target. No Caddy/DNS/phone URL edit is needed.
Unlike the isolated trial, the server joins the normal homelab network and has
outbound access; PostgreSQL/Valkey stay on a private backend network.

```bash
sudo docker network inspect homelab --format '{{json .IPAM.Config}}'
ip -4 address show
sudo systemctl show immich-server.service -p LoadState -p ActiveState -p MainPID
sudo docker compose -f modules/docker/immich/compose.yml config --quiet
```

In `modules/hosts/homelab/configuration.nix`, prepare this top-level setting for
the future generation (not inside `imports`):

```nix
homelab.immichDeployment = "docker";
```

This working-tree edit does not change running services. Build it **before** the
outage; do not run `switch` yet:

```bash
nix eval --impure --json --file tests/family-apps.nix
sudo nixos-rebuild build --flake .#homelab
```

Alternatively use the Docker-only `scripts/check-flake-docker.sh --full` on the
development machine. Its configuration checks cover both application-owner
modes, but its system build follows the mode selected in the working tree.
Do not update the flake lock or images during this migration.

Prepare an entirely new production root (these commands intentionally fail if
it already exists). This creates storage, not containers or native changes:

```bash
sudo zfs create -o mountpoint=/storage/apps/immich-docker \
  -o sharesmb=off -o sharenfs=off storage/apps/immich-docker
sudo bash -euo pipefail -c '
  r=/storage/apps/immich-docker
  test "$(findmnt -n -o SOURCE --mountpoint "$r")" = storage/apps/immich-docker
  umask 077
  chmod 0700 "$r"
  install -d -m 0700 "$r/postgres" "$r/backup"
  set -o noclobber
  od -An -N32 -tx1 /dev/urandom | tr -d " \n" > "$r/db-password"
  test -s "$r/db-password"
'
```

Do not reuse the trial password or print credentials. Copy credentials and a
consistent backup encrypted off-pool. If any target unexpectedly exists, stop
and inspect; do not destroy datasets, overwrite dumps or regenerate credentials.

## Announced downtime window: freeze and final copy

Pause phone uploads and ask clients not to edit/delete anything. Wait for active
upload/metadata/thumbnail/video jobs to finish and record the native image/video
counts; the Redis job queue is not part of the SQL dump. Do not reboot,
run other rebuilds, or manually restart native Immich during this window.
The following is the FIRST native-service interruption:

```bash
sudo systemctl stop immich-server.service
sudo systemctl show immich-server.service -p ActiveState -p SubState -p MainPID
```

Expect `inactive`, `dead`, `MainPID=0`. Native API/microservices/backup jobs run
in this unit. PostgreSQL must remain running. Confirm there are no separate
manually launched importers/workers before taking the final copy.

```bash
sudo bash -euo pipefail -c '
  test "$(systemctl show -p ActiveState --value immich-server.service)" = inactive
  test "$(systemctl show -p MainPID --value immich-server.service)" = 0
  r=/storage/apps/immich-docker
  test "$(findmnt -n -o SOURCE --mountpoint "$r")" = storage/apps/immich-docker
  test "$(findmnt -n -o SOURCE --mountpoint /storage/apps/immich)" = storage/apps/immich
  umask 077
  set -o noclobber
  sudo -u postgres pg_dump --dbname=immich --clean --if-exists --no-owner --no-acl |
    gzip > "$r/backup/immich-cutover.sql.gz"
  gzip -t "$r/backup/immich-cutover.sql.gz"
  zfs snapshot storage/apps/immich@docker-cutover
  zfs clone -o mountpoint="$r/media" -o readonly=off -o sharesmb=off -o sharenfs=off \
    storage/apps/immich@docker-cutover storage/apps/immich-docker/media
'
```

Keep the native app stopped. Verify the new clone's origin and mountpoint; do
not substitute the older `docker-trial` clone. On failure before activation,
the untouched native app can be restarted to abort the window. Any retry then
needs a new consistent final copy; do not reuse stale dump/media combinations.

## Restore only into the production container

```bash
sudo docker compose -f modules/docker/immich/compose.yml up -d --wait database redis
(
  set -euo pipefail
  running="$(sudo docker compose -f modules/docker/immich/compose.yml --profile production ps --status running -q immich-server)"
  test -z "$running"
  tables="$(sudo docker compose -f modules/docker/immich/compose.yml exec -T database \
    psql -X -U postgres -d immich -Atc "SELECT count(*) FROM pg_tables WHERE schemaname = 'public';")"
  test "$tables" = 0
  sudo gzip -dc /storage/apps/immich-docker/backup/immich-cutover.sql.gz |
    sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" |
    sudo docker compose -f modules/docker/immich/compose.yml exec -T database \
      psql -X -U postgres -d immich --quiet --single-transaction --set ON_ERROR_STOP=on --file=-
)
```

Do not start the server unless restore succeeds. This is the same tested restore
path, now using the fresh final dump and the new production database.

## Activate and accept

Apply the previously built Docker-mode host configuration. This masks only the
native `immich-server.service`, preserving native PostgreSQL, Redis, package,
user and old media for rollback. Docker startup gains checks for BOTH production
mounts. A Docker unit restart during activation can interrupt other containers;
include that possibility in the announced window.

```bash
sudo nixos-rebuild switch --flake .#homelab
(
  set -euo pipefail
  test "$(systemctl show -p LoadState --value immich-server.service)" = masked
  test "$(findmnt -n -o SOURCE --mountpoint /storage/apps/immich-docker/media)" = storage/apps/immich-docker/media
  test "$(sudo zfs get -H -o value origin storage/apps/immich-docker/media)" = storage/apps/immich@docker-cutover
  sudo docker compose -f modules/docker/immich/compose.yml --profile production up -d --wait
)
curl --fail --show-error --max-time 5 http://127.0.0.1:2283/api/server/ping
```

Publishing port 2283 makes Docker reachable through existing Caddy/direct URLs
immediately, not only after health passes. Keep users/uploads paused until
acceptance. Check `https://photos.homelab`, login, counts from the FINAL freeze,
original downloads, a video, and then one phone upload. Finally resume normal
uploads. Reboot recovery must confirm Docker healthy and native masked. Existing
Immich user credentials come from the restored database; no new account is needed.

## Recovery and continuing backups

If rollback is needed, **stop production Docker FIRST** to release port 2283:

```bash
sudo docker compose -f modules/docker/immich/compose.yml --profile production stop
```

Change the host selector back to `"native"`, rebuild/switch, then verify:

```bash
sudo nixos-rebuild switch --flake .#homelab
sudo systemctl start immich-server.service
sudo systemctl status immich-server.service --no-pager
```

Do not start both versions simultaneously. After Docker has accepted uploads,
album edits or other writes, the old native database is stale: preserve/export
those changes before rolling back. Phone originals do not preserve all metadata.
Do not delete either dataset/database, the final dump, or origin snapshots during
acceptance. The production clone depends on its origin snapshot. Any promotion
or cleanup is a separate, explicitly approved operation.

Docker mode adds recursive Sanoid snapshots of `storage/apps/immich-docker`,
covering database files and the media child together. This supplements, not
replaces, Immich's application database backups: verify their schedule and a
successful backup in the production administration UI. Confirm restore in an
isolated stack and copy backups/credentials off-pool before retiring originals.
The Nextcloud/Paperless backup timer does not include Immich. A NixOS rollback
does not undo container database migrations; future version upgrades remain
separate from this same-version migration.
