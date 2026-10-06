"""Check snapshot isolation and argument forwarding without a Docker daemon."""

import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/check-flake-docker.sh"


class DockerFlakeCheckTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.repo = base / "repo with spaces"
        self.repo.mkdir()
        (self.repo / "scripts").mkdir()
        shutil.copyfile(SCRIPT, self.repo / "scripts/check-flake-docker.sh")
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True)
        (self.repo / "flake.nix").write_text("staged version\n")
        (self.repo / ".gitignore").write_text(".env\n")
        subprocess.run(
            ["git", "-C", str(self.repo), "add", "flake.nix", ".gitignore"],
            check=True,
        )
        (self.repo / "flake.nix").write_text("working-tree version\n")
        (self.repo / ".env").write_text("FAKE_TEST_CREDENTIAL=not-a-real-secret\n")
        (self.repo / "untracked.txt").write_text("must not be copied\n")
        bin_dir = base / "bin"
        bin_dir.mkdir()
        docker = bin_dir / "docker"
        docker.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, pathlib, sys\n"
            "pathlib.Path(os.environ['CHECK_ARGS']).write_text(json.dumps(sys.argv[1:]))\n"
            "pathlib.Path(os.environ['CHECK_ARCHIVE']).write_bytes(sys.stdin.buffer.read())\n"
            "sys.exit(int(os.environ.get('CHECK_EXIT', '0')))\n"
        )
        docker.chmod(0o755)
        # Execute the real container shell payload against a fake Nix binary.
        # This tests stage order and fail-fast behavior, not Nix evaluation.
        nix = bin_dir / "nix"
        nix.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, sys\n"
            "with open(os.environ['CHECK_NIX_LOG'], 'a') as log:\n"
            "    log.write(json.dumps(sys.argv[1:]) + '\\n')\n"
            "sys.exit(23 if sys.argv[1] == os.environ.get('CHECK_NIX_FAIL') else 0)\n"
        )
        nix.chmod(0o755)
        self.args_file = base / "args.json"
        self.archive_file = base / "source.tar"
        self.nix_log = base / "nix.jsonl"
        self.env = dict(os.environ, PATH=f"{bin_dir}{os.pathsep}{os.environ['PATH']}")
        self.env.update(
            CHECK_ARGS=str(self.args_file), CHECK_ARCHIVE=str(self.archive_file),
            CHECK_NIX_LOG=str(self.nix_log),
        )

    def run_check(self, *args):
        return subprocess.run(
            ["bash", str(self.repo / "scripts/check-flake-docker.sh"), *args],
            cwd=self.temp.name,
            env=self.env,
            text=True,
            capture_output=True,
        )

    def test_snapshot_uses_working_tree_but_excludes_untracked_files(self):
        result = self.run_check("--show-trace")
        self.assertEqual(result.returncode, 0, result.stderr)
        with tarfile.open(fileobj=io.BytesIO(self.archive_file.read_bytes())) as archive:
            self.assertEqual(set(archive.getnames()), {"flake.nix", ".gitignore"})
            self.assertEqual(archive.extractfile("flake.nix").read(), b"working-tree version\n")
        args = json.loads(self.args_file.read_text())
        self.assertNotIn("--mount", args)
        self.assertIn("-i", args)
        self.assertEqual(args[-3:], ["check-flake", "check", "--show-trace"])
        self.assertIn("--no-write-lock-file path:/workspace", args[-4])
        self.assertEqual((self.repo / "flake.nix").read_text(), "working-tree version\n")

    def test_untracked_nix_refused_until_staged(self):
        (self.repo / "new-module.nix").write_text("{}\n")
        result = self.run_check()
        self.assertEqual(result.returncode, 2)
        self.assertIn("new-module.nix", result.stderr)
        self.assertFalse(self.args_file.exists())
        subprocess.run(
            ["git", "-C", str(self.repo), "add", "new-module.nix"], check=True
        )
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        with tarfile.open(fileobj=io.BytesIO(self.archive_file.read_bytes())) as archive:
            self.assertIn("new-module.nix", archive.getnames())

    def test_container_failure_propagates(self):
        self.env["CHECK_EXIT"] = "42"
        result = self.run_check()
        self.assertEqual(result.returncode, 42, result.stderr)

    def test_unstaged_deletion_excluded(self):
        (self.repo / "removed.txt").write_text("old content\n")
        subprocess.run(["git", "-C", str(self.repo), "add", "removed.txt"], check=True)
        (self.repo / "removed.txt").unlink()
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        with tarfile.open(fileobj=io.BytesIO(self.archive_file.read_bytes())) as archive:
            self.assertNotIn("removed.txt", archive.getnames())

    def test_symlinked_parent_cannot_copy_external_data(self):
        directory = self.repo / "tracked"
        directory.mkdir()
        (directory / "data.txt").write_text("tracked content\n")
        subprocess.run(["git", "-C", str(self.repo), "add", "tracked/data.txt"], check=True)
        (directory / "data.txt").unlink()
        directory.rmdir()
        external = Path(self.temp.name) / "external"
        external.mkdir()
        (external / "data.txt").write_text("external private content\n")
        directory.symlink_to(external, target_is_directory=True)
        result = self.run_check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Refusing symlinked parent", result.stderr)
        self.assertNotIn(b"external private content", self.archive_file.read_bytes())

    def test_image_platform_and_spaced_argument_preserved(self):
        self.env.update(NIX_DOCKER_IMAGE="nixos/nix:custom", NIX_DOCKER_PLATFORM="linux/arm64")
        result = self.run_check("--override-input", "example", "path:/path with spaces")
        self.assertEqual(result.returncode, 0, result.stderr)
        args = json.loads(self.args_file.read_text())
        self.assertEqual(args[args.index("--platform") + 1], "linux/arm64")
        self.assertIn("nixos/nix:custom", args)
        self.assertEqual(args[-3:], ["--override-input", "example", "path:/path with spaces"])

    def run_container_payload(self):
        args = json.loads(self.args_file.read_text())
        command = args[args.index("sh"):]
        with tempfile.TemporaryDirectory(dir=self.temp.name) as workspace:
            return subprocess.run(
                command, cwd=workspace, env=self.env,
                input=self.archive_file.read_bytes(), capture_output=True,
            )

    def nix_commands(self):
        return [json.loads(line) for line in self.nix_log.read_text().splitlines()]

    def test_full_runs_all_three_stages_without_activation(self):
        result = self.run_check("--full")
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_container_payload()
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.nix_commands()
        self.assertEqual([c[0] for c in commands], ["flake", "eval", "build"])
        self.assertIn("--no-build", commands[0])
        self.assertIn("/workspace/tests/family-apps-checks.nix", commands[1][-1])
        self.assertIn('builtins.getFlake "path:/workspace"', commands[1][-1])
        self.assertIn("--no-link", commands[2])
        self.assertEqual(
            commands[2][-1],
            "path:/workspace#nixosConfigurations.homelab.config.system.build.toplevel",
        )
        for command in commands:
            self.assertIn("--no-write-lock-file", command)
        self.assertIn(b"All three stages passed", result.stdout)

    def test_full_stops_at_each_failed_stage(self):
        for stage, expected in (
            ("flake", ["flake"]),
            ("eval", ["flake", "eval"]),
            ("build", ["flake", "eval", "build"]),
        ):
            with self.subTest(stage=stage):
                self.nix_log.write_text("")
                self.env["CHECK_NIX_FAIL"] = stage
                result = self.run_check("--full")
                self.assertEqual(result.returncode, 0, result.stderr)
                result = self.run_container_payload()
                self.assertEqual(result.returncode, 23, result.stderr)
                self.assertEqual([c[0] for c in self.nix_commands()], expected)
                self.assertNotIn(b"All three stages passed", result.stdout)

    def test_default_still_only_checks_flake(self):
        result = self.run_check("--show-trace")
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_container_payload()
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.nix_commands()
        self.assertEqual(len(commands), 1)
        self.assertEqual(commands[0][0:2], ["flake", "check"])
        self.assertEqual(commands[0][-1], "--show-trace")

    def test_full_rejects_extra_arguments(self):
        result = self.run_check("--full", "--override-input", "example", "other")
        self.assertEqual(result.returncode, 2)
        self.assertFalse(self.args_file.exists())

    def test_help_needs_no_docker(self):
        result = self.run_check("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--full", result.stdout)
        self.assertFalse(self.args_file.exists())


if __name__ == "__main__":
    unittest.main()
