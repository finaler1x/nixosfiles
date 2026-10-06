#!/usr/bin/env python3
"""Prepare fresh Compose storage/credentials; never migrate existing app data."""

import argparse
import os
from pathlib import Path
import secrets
import subprocess
import sys


MARKER = ".compose-layout-v1"
MARKER_CONTENT = "homelab-compose-v1\n"
CREDENTIALS = ("nextcloud_db", "nextcloud_admin", "paperless_db", "paperless_key", "paperless_admin")
DIRECTORIES = {
    "nextcloud": {"html": (33, 33), "postgres": (0, 0), "redis": (0, 0), "backup": (0, 0)},
    "paperless": {
        "data": (1000, 1000), "media": (1000, 1000), "consume": (1000, 1000),
        "export": (1000, 1000), "postgres": (0, 0), "redis": (0, 0), "backup": (0, 0),
    },
}


def require_dataset(path, dataset):
    result = subprocess.run(
        ["findmnt", "--noheadings", "--output", "SOURCE", "--mountpoint", str(path)],
        check=True, capture_output=True, text=True,
    )
    if result.stdout.strip() != dataset:
        raise RuntimeError(f"{path} must be the mounted dataset {dataset}")


def validate_layout(path):
    marker = path / MARKER
    if marker.is_symlink():
        raise RuntimeError(f"Refusing symlink: {marker}")
    if marker.exists():
        if marker.read_text() != MARKER_CONTENT:
            raise RuntimeError(f"Unrecognized layout marker: {marker}")
    elif any(entry.name != ".zfs" for entry in path.iterdir()):
        raise RuntimeError(f"{path} is not empty; existing/native data needs a separate migration")
    for name in DIRECTORIES[path.name]:
        entry = path / name
        if entry.is_symlink() or (entry.exists() and not entry.is_dir()):
            raise RuntimeError(f"Not a real directory: {entry}")


def prepare(root=Path("/storage/apps"), credentials=Path("/var/lib/homelab-app-credentials")):
    # Validate BOTH datasets before creating anything.
    for app in DIRECTORIES:
        path = root / app
        require_dataset(path, f"storage/apps/{app}")
        validate_layout(path)
    if credentials.is_symlink():
        raise RuntimeError(f"Refusing symlink: {credentials}")
    initialized = any(
        (root / app / "postgres" / "18" / "docker" / "PG_VERSION").exists()
        for app in DIRECTORIES
    ) or (root / "nextcloud/html/config/config.php").exists()
    for name in CREDENTIALS:
        path = credentials / name
        if path.is_symlink():
            raise RuntimeError(f"Refusing symlink: {path}")
        if path.exists():
            value = path.read_bytes()
            if len(value) != 64 or any(c not in b"0123456789abcdef" for c in value):
                raise RuntimeError(f"Invalid credential file {path}; expected 64 hex bytes, no newline")
        elif initialized:
            raise RuntimeError(f"Missing credential {path} for initialized apps; restore it, do not regenerate")

    credentials.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chown(credentials, 0, 0)
    os.chmod(credentials, 0o700)
    for name in CREDENTIALS:
        path = credentials / name
        if not path.exists():
            # Never overwrite, print or store generated credentials in Git.
            with path.open("x") as stream:
                stream.write(secrets.token_hex(32))
        os.chown(path, 0, 0)
        # Standalone Compose secrets are bind mounts. Runtime app users need
        # read access inside containers; the host parent stays root-only 0700.
        os.chmod(path, 0o444)

    for app, directories in DIRECTORIES.items():
        path = root / app
        os.chown(path, 0, 0)
        os.chmod(path, 0o700)
        marker = path / MARKER
        if not marker.exists():
            marker.write_text(MARKER_CONTENT)
        os.chmod(marker, 0o600)
        for name, (uid, gid) in directories.items():
            directory = path / name
            if not directory.exists():
                directory.mkdir(mode=0o700)
                os.chown(directory, uid, gid)
            # Do not reset database ownership after its image initialized it.
    print("Compose directories and credentials prepared; no containers started or data imported.")


if __name__ == "__main__":
    argparse.ArgumentParser(description=__doc__).parse_args()
    if os.geteuid() != 0:
        sys.exit("Run on homelab as root; this creates private directories and credentials.")
    os.umask(0o077)
    prepare()
