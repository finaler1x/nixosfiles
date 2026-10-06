# Immich 3.2.4: isolated Docker restore trial

This is NOT the production stack. Native Immich, Caddy, phone URLs, Nix pins,
and the Nextcloud/Paperless work remain unchanged. Three containers use a separate
project/network and no automatic restart or Watchtower updates. No container
port is published on the host. SSH forwards workstation loopback to the trial
container's bridge address through homelab.

## Confirmed source and target

User-reported native source: PostgreSQL 16.13; VectorChord 1.1.1; pgvector 0.8.2;
Immich 3.2.4; media at `/storage/apps/immich`.

The database image digest in `compose.yml` was checked on homelab: PostgreSQL
16.14, VectorChord 1.1.1, pgvector 0.8.5. The other installed extension versions
match (cube 1.5, earthdistance 1.2, pg_trgm 1.6, plpgsql 1.0, unaccent 1.1,
uuid-ossp 1.1). Do not substitute the PG14 image from Immich's default Compose.

Already prepared on homelab:

- `/storage/immich-docker-trial/immich.sql.gz`: private single-database dump,
  produced with `--clean --if-exists --no-owner --no-acl`; gzip integrity checked.
- `storage/immich-docker-trial-media`: writable ZFS clone, mounted at
  `/storage/immich-docker-trial/media`, originating from
  `storage/apps/immich@docker-trial`.

The container's media destination deliberately matches the native pathname;
the **host source is the clone**, never the native directory. Do not mount native
PGDATA or PostgreSQL sockets. The clone is not an independent/off-pool backup.
Phone originals remain available, but do not replace album/metadata backups.

## Prepare only the trial database directory and credential

Run on homelab. These commands do not create/replace the existing dump or clone.
If any mount check fails, stop; do not create a substitute empty media directory.

```bash
sudo bash -euo pipefail -c '
  test ! -L /storage/immich-docker-trial
  test ! -L /storage/immich-docker-trial/media
  test "$(findmnt -n -o SOURCE --mountpoint /storage/immich-docker-trial/media)" = storage/immich-docker-trial-media
  test "$(zfs get -H -o value origin storage/immich-docker-trial-media)" = storage/apps/immich@docker-trial
  test -s /storage/immich-docker-trial/immich.sql.gz
  umask 077
  test ! -L /storage/immich-docker-trial/postgres
  test ! -L /storage/immich-docker-trial/db-password
  if test -e /storage/immich-docker-trial/postgres; then
    test -d /storage/immich-docker-trial/postgres
  else
    install -d -m 0700 /storage/immich-docker-trial/postgres
  fi
  if test -e /storage/immich-docker-trial/db-password; then
    test -f /storage/immich-docker-trial/db-password
  else
    test ! -e /storage/immich-docker-trial/postgres/PG_VERSION
    set -o noclobber
    od -An -N32 -tx1 /dev/urandom | tr -d " \n" > /storage/immich-docker-trial/db-password
  fi
  test -s /storage/immich-docker-trial/db-password
'
```

Keep the parent directory root-only (0700), as created with the dump. Do not print
or commit the password. A missing password on an initialized trial database must
be restored, not regenerated. Existing directories/credentials are not a request
to delete anything; inspect unexpected state before proceeding.

From **this directory on homelab**, start only the database and broker:

```bash
sudo docker compose config --quiet
sudo docker compose up -d --wait database redis
```

## Restore before starting the application

Only run this against the dedicated, fresh trial database. The dump contains
DROP statements. Never substitute the native database connection. Do not repeat
the restore over trial edits or with the trial server running.

From this directory, the following pipeline applies the release's documented
search-path adjustment, restores in a transaction, and stops on SQL errors:

```bash
(
  set -euo pipefail
  test -z "$(sudo docker compose --profile trial ps --status running -q immich-server)"
  sudo gzip -dc /storage/immich-docker-trial/immich.sql.gz |
    sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" |
    sudo docker compose exec -T database psql -X --username=postgres --dbname=immich \
      --single-transaction --set ON_ERROR_STOP=on --file=-
)
```

On failure, do not start Immich or bypass the error. Keep the native database
and original dump intact. A gzip check alone is not a tested database restore.

After a successful restore:

```bash
sudo docker compose --profile trial up -d --wait
sudo docker compose --profile trial ps
```

The profile is a guard against accidental ordinary `up`, not access control:
explicitly targeting `immich-server` also activates it. No machine-learning
container is included, matching the native deployment. The ML env flag sets a
default only; imported explicit ML settings may override it. Disable ML in the
trial admin UI if it was explicitly enabled. Do not connect a production ML
endpoint. The private network blocks ordinary external network egress, but is
not a guarantee against all host/browser-side access. Do not attach the trial to
the homelab network or add host-gateway aliases.

## View and verify, without switching the phone

An internal-only Docker network does not provide the normal host-port
publication used by a regular bridge. The earlier `127.0.0.1:2284:2283` mapping
was not installed by the running daemon. Keep isolation enabled rather than
adding internet access to make that mapping work.

First discover and test the server's bridge IP **on homelab**:

```bash
trial_ip="$(sudo docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' immich-docker-trial-immich-server-1)"
test -n "$trial_ip"
printf 'Trial container IP: %s\n' "$trial_ip"
curl --fail --show-error --max-time 5 "http://$trial_ip:2283/api/server/ping"
```

Expect `{"res":"pong"}`. If the host cannot reach it, inspect the bridge/firewall
and actual container listener; do not rerun the database restore. All trial
services have only one network, so the inspection yields one IPv4 address.

From your workstation, forward to **that IP**, not homelab's `127.0.0.1`.
Replace `<TRIAL-IP>` below with the printed address and use your usual SSH host:

```bash
ssh -N -o ExitOnForwardFailure=yes -L '127.0.0.1:2284:<TRIAL-IP>:2283' antonio@homelab
```

Open `http://127.0.0.1:2284` locally and use your existing Immich login from the
restored database. The SSH tunnel protects transport; do not publish the HTTP
port on the LAN. The container IP may change on recreation; rediscover it and
reopen the tunnel if necessary. Keep the phone on production `photos.homelab`.

Check user/asset counts, albums, representative original downloads, videos and
thumbnails. Test an upload through the browser only. Do not delete phone
originals. Do not assume ML/search or external libraries work without their
dependencies. Logs may expose private filenames; redact before sharing.

The native instance can resume phone uploads after the clone is created. Those
new assets will NOT appear in this frozen trial. A later cutover needs a fresh,
coordinated dump/media copy and separately approved proxy/native-service changes.

## Stop without deleting data

From this trial directory:

```bash
sudo docker compose --profile trial stop
```

This does not stop native Immich or remove the dump, trial database, clone or
origin snapshot. Snapshot/clone/data destruction is not part of this trial.
Do not use a broad prune, `down -v`, or destroy the origin snapshot as cleanup.

Sources: [release Compose](https://github.com/immich-app/immich/blob/v3.2.4/docker/docker-compose.yml),
[release restore guide](https://github.com/immich-app/immich/blob/v3.2.4/docs/docs/administration/backup-and-restore.md).
