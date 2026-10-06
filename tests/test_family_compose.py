"""Compose contracts and safe host preparation/backup, without running apps."""

import importlib.util
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import yaml


ROOT = Path(__file__).resolve().parents[1]


def load_script(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


prepare = load_script("prepare-family-apps")
backup = load_script("backup-family-apps")


class ComposeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.compose = yaml.safe_load((ROOT / "modules/docker/homelab/docker-compose.yml").read_text())
        cls.services = cls.compose["services"]

    def test_pinned_and_not_published_or_auto_updated(self):
        for name in ("nextcloud", "nextcloud-cron", "nextcloud-db", "nextcloud-redis",
                     "paperless", "paperless-db", "paperless-redis"):
            with self.subTest(service=name):
                service = self.services[name]
                self.assertRegex(service["image"], r":[^:@]+@sha256:[0-9a-f]{64}$")
                self.assertNotIn(":latest", service["image"])
                self.assertFalse(service.get("ports"))
                self.assertEqual(service["labels"]["com.centurylinklabs.watchtower.enable"], "false")
                for volume in service["volumes"]:
                    self.assertFalse(volume["bind"]["create_host_path"])
                    self.assertTrue(volume["source"].startswith("/storage/apps/"))

    def test_database_and_broker_networks_are_private_and_separate(self):
        for app in ("nextcloud", "paperless"):
            backend = f"{app}-backend"
            self.assertTrue(self.compose["networks"][backend]["internal"])
            for name in (f"{app}-db", f"{app}-redis"):
                self.assertEqual(self.services[name]["networks"], [backend])
            self.assertNotIn("homelab", self.services[app]["networks"])
            volume = self.services[f"{app}-db"]["volumes"][0]
            self.assertEqual(volume["target"], "/var/lib/postgresql")
            self.assertEqual(volume["source"], f"/storage/apps/{app}/postgres")

    def test_proxy_identity_matches_both_apps(self):
        caddy = self.services["caddy"]
        address = caddy["networks"]["family-proxy"]["ipv4_address"]
        self.assertEqual(self.services["nextcloud"]["environment"]["TRUSTED_PROXIES"], address)
        self.assertEqual(self.services["paperless"]["environment"]["PAPERLESS_TRUSTED_PROXIES"], address)
        self.assertNotIn("/run/family-web", str(caddy["volumes"]))
        routes = (ROOT / "modules/docker/homelab/Caddyfile").read_text()
        self.assertIn("reverse_proxy nextcloud:80", routes)
        self.assertIn("reverse_proxy paperless:8000", routes)
        self.assertIn("reverse_proxy host.docker.internal:2283", routes)

    def test_bootstrap_and_cron_contract(self):
        web, cron = self.services["nextcloud"], self.services["nextcloud-cron"]
        self.assertEqual(web["image"], cron["image"])
        self.assertEqual(web["volumes"], cron["volumes"])
        for key, value in cron["environment"].items():
            self.assertEqual(web["environment"][key], value)
        self.assertIn("NEXTCLOUD_ADMIN_PASSWORD_FILE", web["environment"])
        self.assertIn("NEXTCLOUD_ADMIN_USER", web["environment"])
        self.assertEqual(cron["entrypoint"], "/cron.sh")
        self.assertEqual(cron["depends_on"]["nextcloud"]["condition"], "service_healthy")
        self.assertNotIn("nextcloud_admin", cron["secrets"])

    def test_paperless_v3_and_file_credentials(self):
        app = self.services["paperless"]
        env = app["environment"]
        self.assertIn(":3.3.0@", app["image"])
        self.assertEqual(env["PAPERLESS_DBENGINE"], "postgresql")
        self.assertEqual(env["PAPERLESS_ALLOWED_HOSTS"], "docs.homelab")
        self.assertEqual(env["PAPERLESS_OCR_LANGUAGE"], "deu+eng")
        self.assertIn("PAPERLESS_SECRET_KEY_FILE", env)
        self.assertNotIn("PAPERLESS_AUTO_LOGIN_USERNAME", env)
        for name in ("nextcloud", "nextcloud-cron", "nextcloud-db", "paperless", "paperless-db"):
            service = self.services[name]
            for key, value in service["environment"].items():
                if key.endswith("_FILE"):
                    self.assertIn(value.rsplit("/", 1)[1], service["secrets"])
            self.assertFalse(any(key.endswith(("PASSWORD", "DBPASS", "SECRET_KEY")) for key in service["environment"]))


class ImmichTrialTests(unittest.TestCase):
    def test_documented_shell_commands_parse_without_execution(self):
        guide = (ROOT / "modules/docker/immich-trial/README.md").read_text()
        for block in re.findall(r"```bash\n(.*?)```", guide, re.DOTALL):
            result = subprocess.run(["bash", "-n"], input=block, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_trial_is_separate_gated_and_uses_only_copied_data(self):
        trial = yaml.safe_load((ROOT / "modules/docker/immich-trial/compose.yml").read_text())
        self.assertEqual(trial["name"], "immich-docker-trial")
        self.assertTrue(trial["networks"]["default"]["internal"])
        server = trial["services"]["immich-server"]
        self.assertEqual(server["profiles"], ["trial"])
        self.assertFalse(server.get("ports"))
        self.assertRegex(server["image"], r"^ghcr.io/immich-app/immich-server:v3\.2\.4@sha256:[0-9a-f]{64}$")
        self.assertEqual(server["environment"]["IMMICH_MEDIA_LOCATION"], "/storage/apps/immich")
        for name, service in trial["services"].items():
            self.assertEqual(service["restart"], "no")
            self.assertEqual(service["labels"]["com.centurylinklabs.watchtower.enable"], "false")
            self.assertFalse(service.get("ports"))
            for volume in service.get("volumes", []):
                self.assertTrue(volume["source"].startswith("/storage/immich-docker-trial/"))
                self.assertFalse(volume["bind"]["create_host_path"])


class ImmichProductionTests(unittest.TestCase):
    def test_production_preserves_endpoints_but_uses_fresh_separate_storage(self):
        prod = yaml.safe_load((ROOT / "modules/docker/immich/compose.yml").read_text())
        trial = yaml.safe_load((ROOT / "modules/docker/immich-trial/compose.yml").read_text())
        self.assertEqual(prod["name"], "immich-production")
        self.assertTrue(prod["networks"]["backend"]["internal"])
        self.assertTrue(prod["networks"]["homelab"]["external"])
        self.assertEqual(prod["networks"]["homelab"]["name"], "homelab")
        server = prod["services"]["immich-server"]
        self.assertEqual(server["profiles"], ["production"])
        self.assertEqual(set(server["ports"]), {
            "172.18.0.1:2283:2283", "192.168.178.75:2283:2283",
            "100.99.212.33:2283:2283", "127.0.0.1:2283:2283",
        })
        self.assertIn("homelab", server["networks"])
        self.assertEqual(server["environment"]["IMMICH_MEDIA_LOCATION"], "/storage/apps/immich")
        for name, service in prod["services"].items():
            self.assertEqual(service["image"], trial["services"][name]["image"])
            self.assertEqual(service["restart"], "unless-stopped")
            self.assertEqual(service["labels"]["com.centurylinklabs.watchtower.enable"], "false")
            if name != "immich-server":
                self.assertEqual(service["networks"], ["backend"])
                self.assertFalse(service.get("ports"))
            for volume in service.get("volumes", []):
                self.assertTrue(volume["source"].startswith("/storage/apps/immich-docker/"))
                self.assertFalse(volume["bind"]["create_host_path"])

    def test_documented_cutover_commands_parse_without_execution(self):
        guide = (ROOT / "modules/docker/immich/README.md").read_text()
        for block in re.findall(r"```bash\n(.*?)```", guide, re.DOTALL):
            result = subprocess.run(["bash", "-n"], input=block, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)


class PreparationTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name) / "apps"
        for app in prepare.DIRECTORIES:
            (self.root / app).mkdir(parents=True)
        self.credentials = Path(temp.name) / "credentials"
        self.mount = patch.object(prepare, "require_dataset")
        self.mount.start()
        self.addCleanup(self.mount.stop)
        self.chown = patch.object(prepare.os, "chown")
        self.chown.start()
        self.addCleanup(self.chown.stop)

    def test_fresh_setup_is_private_idempotent_and_does_not_rotate(self):
        prepare.prepare(self.root, self.credentials)
        first = {p.name: p.read_bytes() for p in self.credentials.iterdir()}
        self.assertEqual(set(first), set(prepare.CREDENTIALS))
        self.assertEqual(self.credentials.stat().st_mode & 0o777, 0o700)
        for value in first.values():
            self.assertEqual(len(value), 64)
            self.assertNotIn(b"\n", value)
        prepare.prepare(self.root, self.credentials)
        self.assertEqual(first, {p.name: p.read_bytes() for p in self.credentials.iterdir()})
        self.assertEqual((self.root / "paperless/consume").stat().st_mode & 0o777, 0o700)

    def test_existing_native_data_rejected_before_any_mutation(self):
        original = self.root / "paperless/native-document.pdf"
        original.write_bytes(b"preserve me")
        with self.assertRaisesRegex(RuntimeError, "not empty"):
            prepare.prepare(self.root, self.credentials)
        self.assertEqual(original.read_bytes(), b"preserve me")
        self.assertFalse(self.credentials.exists())
        self.assertFalse((self.root / "nextcloud" / prepare.MARKER).exists())

    def test_missing_database_credential_not_regenerated(self):
        prepare.prepare(self.root, self.credentials)
        version = self.root / "nextcloud/postgres/18/docker/PG_VERSION"
        version.parent.mkdir(parents=True)
        version.write_text("18")
        missing = self.credentials / "nextcloud_db"
        missing.unlink()
        with self.assertRaisesRegex(RuntimeError, "restore it"):
            prepare.prepare(self.root, self.credentials)
        self.assertFalse(missing.exists())

    def test_symlinked_storage_rejected(self):
        (self.root / "nextcloud" / prepare.MARKER).write_text(prepare.MARKER_CONTENT)
        (self.root / "nextcloud/html").symlink_to(self.root / "paperless", target_is_directory=True)
        with self.assertRaisesRegex(RuntimeError, "Not a real directory"):
            prepare.prepare(self.root, self.credentials)
        self.assertFalse(self.credentials.exists())

    def test_help_and_invalid_arguments_do_not_prepare_or_backup(self):
        for script in ("prepare-family-apps.py", "backup-family-apps.py"):
            for args, expected in ((["--help"], 0), (["--invalid"], 2)):
                with self.subTest(script=script, args=args):
                    result = subprocess.run(
                        [sys.executable, "-B", str(ROOT / "scripts" / script), *args],
                        capture_output=True, text=True,
                    )
                    self.assertEqual(result.returncode, expected, result.stderr)

    def test_wrong_mount_source_rejected(self):
        self.mount.stop()
        with patch.object(prepare.subprocess, "run", return_value=SimpleNamespace(stdout="/dev/root\n")):
            with self.assertRaisesRegex(RuntimeError, "must be the mounted dataset"):
                prepare.prepare(self.root, self.credentials)
        self.assertFalse(self.credentials.exists())


class BackupTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        for app in backup.APPS:
            (self.root / app / "backup").mkdir(parents=True)
            (self.root / app / prepare.MARKER).write_text(prepare.MARKER_CONTENT)
        self.commands = []
        self.fail_dump = False
        self.running = "true"

    def run_command(self, args, **kwargs):
        self.commands.append(args)
        if args[0] == "findmnt":
            return SimpleNamespace(stdout=f"storage/apps/{Path(args[-1]).name}\n")
        if args[:2] == ["docker", "inspect"]:
            return SimpleNamespace(stdout=self.running)
        if args[:2] == ["docker", "exec"]:
            if self.fail_dump:
                raise subprocess.CalledProcessError(1, args)
            kwargs["stdout"].write(b"test database dump")
        if args[:2] == ["zfs", "list"]:
            dataset = args[-1]
            if "-r" in args:
                return SimpleNamespace(stdout=dataset)
            return SimpleNamespace(stdout="\n".join(
                [f"{dataset}@family-202610{i:02d}T023000Z" for i in range(1, 10)]
                + [f"{dataset}@manual-keep", f"{dataset}@autosnap_keep_daily"]
            ))
        return SimpleNamespace(stdout="")

    def test_backup_quiesces_snapshots_and_prunes_only_owned_names(self):
        backup.backup(self.root, self.run_command)
        stop = next(i for i, c in enumerate(self.commands) if c[:2] == ["docker", "stop"])
        dump = next(i for i, c in enumerate(self.commands) if c[:2] == ["docker", "exec"])
        snap = next(i for i, c in enumerate(self.commands) if c[:2] == ["zfs", "snapshot"])
        start = next(i for i, c in enumerate(self.commands) if c[:2] == ["docker", "start"])
        self.assertLess(stop, dump)
        self.assertLess(dump, snap)
        self.assertLess(snap, start)
        destroyed = [c[-1] for c in self.commands if c[:2] == ["zfs", "destroy"]]
        self.assertEqual(len(destroyed), 4)
        self.assertTrue(all("@family-" in name for name in destroyed))

    def test_failed_dump_restarts_writers_without_snapshot_or_pruning(self):
        self.fail_dump = True
        with self.assertRaises(subprocess.CalledProcessError):
            backup.backup(self.root, self.run_command)
        self.assertEqual(
            [c[-1] for c in self.commands if c[:2] == ["docker", "start"]],
            ["nextcloud", "paperless", "nextcloud-cron"],
        )
        self.assertFalse(any(c[:2] in (["zfs", "snapshot"], ["zfs", "destroy"]) for c in self.commands))

    def test_stopped_app_not_started_by_backup(self):
        self.running = "false"
        with self.assertRaisesRegex(RuntimeError, "not running"):
            backup.backup(self.root, self.run_command)
        self.assertFalse(any(c[:2] in (["docker", "start"], ["docker", "stop"]) for c in self.commands))

    def test_nested_dataset_rejected_before_stopping_apps(self):
        def nested(args, **kwargs):
            if args[:2] == ["zfs", "list"] and "-r" in args:
                return SimpleNamespace(stdout=f"{args[-1]}\n{args[-1]}/child\n")
            return self.run_command(args, **kwargs)

        with self.assertRaisesRegex(RuntimeError, "Nested datasets"):
            backup.backup(self.root, nested)
        self.assertFalse(any(c[:2] == ["docker", "stop"] for c in self.commands))


if __name__ == "__main__":
    unittest.main()
