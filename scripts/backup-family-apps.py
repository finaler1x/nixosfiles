#!/usr/bin/env python3
"""Local coordinated database/file restore points; not an off-pool backup."""

import argparse
from datetime import datetime, timezone
import fcntl
import os
from pathlib import Path
import re
import signal
import subprocess
import sys


APPS = ("nextcloud", "paperless")
WRITERS = ("nextcloud-cron", "nextcloud", "paperless")


def command(args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def backup(root=Path("/storage/apps"), run=command):
    for app in APPS:
        mount = run(
            ["findmnt", "--noheadings", "--output", "SOURCE", "--mountpoint", str(root / app)],
            capture_output=True, text=True,
        ).stdout.strip()
        if mount != f"storage/apps/{app}":
            raise RuntimeError(f"Expected ZFS dataset is not mounted for {app}")
        datasets = run(
            ["zfs", "list", "-H", "-o", "name", "-r", f"storage/apps/{app}"],
            capture_output=True, text=True,
        ).stdout.splitlines()
        if datasets != [f"storage/apps/{app}"]:
            raise RuntimeError(f"Nested datasets under {app} require a different backup layout")
        if (root / app / ".compose-layout-v1").read_text() != "homelab-compose-v1\n":
            raise RuntimeError(f"Compose layout not prepared for {app}")
    for container in (*WRITERS, "nextcloud-db", "paperless-db"):
        state = run(
            ["docker", "inspect", "--format", "{{.State.Running}}", container],
            capture_output=True, text=True,
        ).stdout.strip()
        if state != "true":
            raise RuntimeError(f"Backup not started: {container} is not running")

    try:
        # Record all originally-running writers for recovery even if stop fails
        # part way through. Database servers remain up for logical dumps.
        run(["docker", "stop", "--time", "300", *WRITERS])
        for app in APPS:
            directory = root / app / "backup"
            if directory.is_symlink() or not directory.is_dir():
                raise RuntimeError(f"Missing private backup directory for {app}")
            temporary = directory / "database.dump.tmp"
            with temporary.open("wb") as stream:
                run(["docker", "exec", f"{app}-db", "pg_dump", "-U", app, "-d", app, "-Fc"], stdout=stream)
                stream.flush()
                os.fsync(stream.fileno())
            temporary.replace(directory / "database.dump")

        stamp = datetime.now(timezone.utc).strftime("family-%Y%m%dT%H%M%SZ")
        # Both snapshots are created in one operation on the same pool.
        run(["zfs", "snapshot", *[f"storage/apps/{app}@{stamp}" for app in APPS]])
    finally:
        # All writers were running before this job. Do not leave them stopped
        # after a failed dump/snapshot. Try every restart, preserving errors.
        errors = []
        for container in ("nextcloud", "paperless", "nextcloud-cron"):
            try:
                run(["docker", "start", container])
            except subprocess.CalledProcessError as error:
                errors.append(error)
        if errors:
            raise RuntimeError("Could not restart all family containers; inspect them immediately") from errors[0]

    # Keep seven of OUR restore points, never prune Sanoid/user snapshots.
    for app in APPS:
        snapshots = run(
            ["zfs", "list", "-H", "-t", "snapshot", "-o", "name", "-s", "creation", "-d", "1", f"storage/apps/{app}"],
            capture_output=True, text=True,
        ).stdout.splitlines()
        owned = [name for name in snapshots if re.fullmatch(rf"storage/apps/{app}@family-\d{{8}}T\d{{6}}Z", name)]
        for old in owned[:-7]:
            run(["zfs", "destroy", old])
    print(f"Created {stamp} with database dumps. Copy a consistent restore point AND credentials off-pool.")


def interrupted(signum, _frame):
    raise RuntimeError(f"Backup interrupted by signal {signum}")


if __name__ == "__main__":
    argparse.ArgumentParser(description=__doc__).parse_args()
    if os.geteuid() != 0:
        sys.exit("Run on homelab as root.")
    os.umask(0o077)
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    with open("/run/lock/family-apps-backup.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        backup()
