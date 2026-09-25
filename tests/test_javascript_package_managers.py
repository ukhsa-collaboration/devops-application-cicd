"""Exercise the workflow's actual package-manager setup without network access."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]


def workflow(name):
    return yaml.load((ROOT / ".github/workflows" / name).read_text(), Loader=yaml.BaseLoader)


def steps(name, job):
    return {step.get("name"): step for step in workflow(name)["jobs"][job]["steps"]}


BUILD = steps("build-test-container.yml", "build")
DEPLOY = steps("deploy-aws-ecs.yml", "deploy")

# Simulate only external package-manager operations. The workflow's Node
# configuration validation, shell branching, and output generation run unmodified.
MANAGER_STUB = """#!/usr/bin/env bash
set -eu
if [ "${1:-}" = install ] && [ "${2:-}" = --global ]; then
  prefix="$4"
  spec="$5"
  version="${spec##*@}"
  name="${spec%@*}"
  if [ "$name" = @yarnpkg/cli-dist ]; then name=yarn; fi
  mkdir -p "$prefix/bin"
  cp "$STUB_SOURCE" "$prefix/bin/$name"
  printf '%s' "$version" > "$VERSION_FILE"
  exit 0
fi
case "${1:-}" in
  --version) if [ -n "${ACTIVE_VERSION:-}" ]; then echo "$ACTIVE_VERSION"; elif [ -f "$VERSION_FILE" ]; then cat "$VERSION_FILE"; else echo 10.9.2; fi ;;
  config)
    if [ "${3:-}" = nodeLinker ]; then echo "${YARN_LINKER:-node-modules}"; else echo "$TEST_CACHE"; fi ;;
  store) echo "$TEST_CACHE" ;;
  *) printf '%s\\n' "$*" >> "$INSTALL_LOG" ;;
esac
"""


class PackageManagerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.package = self.root / "nested" / "app"
        self.package.mkdir(parents=True)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for manager in ("npm", "pnpm", "yarn"):
            stub = self.bin / manager
            stub.write_text(MANAGER_STUB)
            stub.chmod(0o755)
        self.env = dict(
            os.environ,
            PATH=f"{self.bin}:{os.environ['PATH']}",
            RUNNER_TEMP=str(self.root),
            GITHUB_OUTPUT=str(self.root / "output"),
            GITHUB_PATH=str(self.root / "path"),
            PACKAGE_DIRECTORY="nested/app",
            VERSION_FILE=str(self.root / "version"),
            STUB_SOURCE=str(self.bin / "npm"),
            TEST_CACHE=str(self.root / "cache"),
            INSTALL_LOG=str(self.root / "install"),
        )

    def run_setup(
        self, manager="npm", version="", declaration=None, lock=True, **environment
    ):
        pkg = {} if declaration is None else {"packageManager": declaration}
        (self.package / "package.json").write_text(json.dumps(pkg))
        lockfile = {
            "npm": "package-lock.json",
            "pnpm": "pnpm-lock.yaml",
            "yarn": "yarn.lock",
        }.get(manager)
        if lock and lockfile:
            (self.package / lockfile).touch()
        return subprocess.run(
            [
                "bash",
                "-eo",
                "pipefail",
                "-c",
                BUILD["Set up JavaScript package manager"]["run"],
            ],
            cwd=self.package,
            env=self.env
            | {"PACKAGE_MANAGER": manager, "PACKAGE_MANAGER_VERSION": version}
            | environment,
            capture_output=True,
            text=True,
        )

    def test_npm_default(self):
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("version=10.9.2", (self.root / "output").read_text())
        self.assertFalse((self.root / "version").exists())

    def test_pinned_managers_and_cache_outputs(self):
        for manager, version, lock in [
            ("npm", "10.9.2", "package-lock.json"),
            ("pnpm", "10.34.5", "pnpm-lock.yaml"),
            ("yarn", "4.18.0", "yarn.lock"),
        ]:
            with self.subTest(manager=manager):
                result = self.run_setup(manager, declaration=f"{manager}@{version}")
                self.assertEqual(result.returncode, 0, result.stderr)
                output = (self.root / "output").read_text()
                self.assertIn(f"lockfile=nested/app/{lock}", output)
                self.assertIn(f"version={version}", output)
                self.assertIn(f"cache_path={self.root}/cache", output)

    def test_explicit_version(self):
        result = self.run_setup("pnpm", version="10.34.5")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_invalid_configuration(self):
        cases = [
            ({"manager": "bun"}, "package_manager must"),
            ({"manager": "pnpm"}, "Pin the package manager"),
            ({"manager": "yarn", "version": "1.22.22"}, "Yarn Classic"),
            ({"manager": "pnpm", "version": "latest"}, "exact version"),
            ({"manager": "pnpm", "declaration": "pnpm@10.34.5+sha512.deadbeef"}, "checksum digest"),
            ({"declaration": "pnpm@10.34.5"}, "conflicts"),
            (
                {
                    "manager": "pnpm",
                    "version": "10.34.4",
                    "declaration": "pnpm@10.34.5",
                },
                "conflicts",
            ),
            ({"manager": "pnpm", "declaration": "pnpm@latest"}, "exact"),
            (
                {"manager": "yarn", "version": "4.18.0", "YARN_LINKER": "pnp"},
                "nodeLinker",
            ),
            (
                {"manager": "yarn", "version": "4.18.0", "ACTIVE_VERSION": "4.0.0"},
                "does not match",
            ),
        ]
        for arguments, error in cases:
            with self.subTest(arguments=arguments):
                result = self.run_setup(**arguments)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(error, result.stderr)

    def test_missing_lockfile(self):
        result = self.run_setup(lock=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing package-lock.json", result.stderr)

    def test_integration_command_required(self):
        result = subprocess.run(
            [
                "bash",
                "-eo",
                "pipefail",
                "-c",
                BUILD["Run integration tests"]["run"],
            ],
            env=self.env | {"INTEGRATION_TEST_COMMAND": ""},
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("integration_test_command must not be empty", result.stderr)

    def test_install_commands(self):
        for manager, command in [
            ("npm", "ci --include=dev"),
            ("pnpm", "install --frozen-lockfile --prod=false"),
            ("yarn", "install --immutable"),
        ]:
            with self.subTest(manager=manager):
                result = subprocess.run(
                    [
                        "bash",
                        "-eo",
                        "pipefail",
                        "-c",
                        BUILD["Install JavaScript dependencies"]["run"],
                    ],
                    env=self.env | {"PACKAGE_MANAGER": manager},
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(command, (self.root / "install").read_text())

    def test_build_and_deploy_setup_agree(self):
        for name in (
            "Set up JavaScript package manager",
            "Install JavaScript dependencies",
        ):
            self.assertEqual(BUILD[name]["run"], DEPLOY[name]["run"])

    def test_aggressive_cleanup_condition(self):
        condition = BUILD["Aggressive cleanup"]["if"]
        for value, environment, expected in [
            (True, "github-hosted", True),
            (True, "self-hosted", False),
            (False, "github-hosted", False),
        ]:
            expression = (
                f"const inputs = {{aggressively_clean: {str(value).lower()}}}; "
                f"const runner = {{environment: {json.dumps(environment)}}}; "
                f"console.log(Boolean({condition}));"
            )
            result = subprocess.run(
                ["node", "-e", expression],
                capture_output=True,
                text=True,
                check=True,
            )
            self.assertEqual(result.stdout.strip(), str(expected).lower())

    def test_disabled_checks_skip_setup(self):
        for name in (
            "Set up Node.js",
            "Set up JavaScript package manager",
            "Cache JavaScript dependencies",
            "Install JavaScript dependencies",
        ):
            condition = BUILD[name]["if"]
            for runtime, lint, unit, integration, expected in [
                ("javascript", False, False, False, False),
                ("javascript", True, False, False, True),
                ("javascript", False, True, False, True),
                ("javascript", False, False, True, True),
                ("python", True, True, True, False),
            ]:
                inputs = dict(
                    runtime=runtime,
                    lint_javascript=lint,
                    run_unit_tests=unit,
                    run_integration_tests=integration,
                )
                expression = f"const inputs = {json.dumps(inputs)}; console.log(Boolean({condition}));"
                result = subprocess.run(
                    ["node", "-e", expression],
                    capture_output=True,
                    text=True,
                    check=True,
                )
                self.assertEqual(result.stdout.strip(), str(expected).lower(), name)


if __name__ == "__main__":
    unittest.main()
