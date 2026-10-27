"""Exercise the real CLI and catalog recipe without accessing system snapshots."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


class SnapperCleanupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "deleted"
        self.fixture = self.root / "list"
        # Snapper selects Unicode table borders under a UTF-8 locale.
        self.fixture.write_text(
            " # │ Description\n───┼────────────────────────\n"
            "0* │ current\n1 │ oldest\n2 │ backup | [KEEP]\n"
            "9\n10 │ before update\n11 │ after update\n"
            "12+ │ default\n13- │ mounted\n14* │ mounted default\n"
        )
        self.write_executable("sudo", '#!/bin/bash\n[[ "$1" == -v ]] && exit 0\nexec "$@"\n')
        self.write_executable("snapper", r'''#!/bin/bash
if [[ "$*" == *"list --columns number,description"* ]]; then
    if [[ "$*" == *"--table-style 0"* ]]; then
        sed 's/│/|/g' "$TEST_FIXTURE"
    else
        cat "$TEST_FIXTURE"
    fi
elif [[ "$1 $2 $3" == "-c root delete" && "$#" == 4 ]]; then
    printf '%s\n' "$4" >> "$TEST_DELETED"
else
    exit 99
fi
''')
        config = self.root / "config" / "checkpoint"
        config.mkdir(parents=True)
        (config / "config").write_text(
            "SELF_UPDATE_CHECK=off\nUSE_COLOR=false\nUSE_EMOJI=false\nAUTO_RETRIES=0\n"
        )
        self.env = dict(os.environ, HOME=str(self.root),
                        PATH=f"{self.bin}:/usr/bin:/bin",
                        CHECKPOINT_CONFIG_DIR=str(config),
                        CHECKPOINT_DATA_DIR=str(self.root / "data"),
                        CHECKPOINT_CACHE_DIR=str(self.root / "cache"),
                        CATALOG_DIR=str(REPO / "catalog" / "backends"),
                        TEST_FIXTURE=str(self.fixture), TEST_DELETED=str(self.log))

    def write_executable(self, name, content):
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o755)

    def cli(self, *args):
        result = subprocess.run([str(REPO / "checkpoint"), "--backend", "snapper", *args],
                                env=self.env, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout

    def deleted(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_rotation_keeps_newest_and_protected(self):
        self.cli("-cl", "-k", "2")
        self.assertEqual(self.deleted(), ["9", "1"])

    def test_force_override(self):
        self.cli("-cl", "-k", "2", "-f")
        self.assertEqual(self.deleted(), ["9", "2", "1"])

    def test_list_preserves_description_and_excludes_system_snapshots(self):
        output = self.cli("-l", "--porcelain")
        self.assertEqual(output.splitlines(), [
            "11 | after update", "10 | before update", "9 | (no description)",
            "2 | backup | [KEEP]", "1 | oldest",
        ])
        self.assertEqual(self.deleted(), [])

    def test_zero_limit(self):
        self.cli("-cl", "-k", "0")
        self.assertEqual(self.deleted(), ["11", "10", "9", "1"])

    def test_ascii_table(self):
        self.fixture.write_text(self.fixture.read_text().replace("│", "|"))
        self.cli("-cl", "-k", "2")
        self.assertEqual(self.deleted(), ["9", "1"])

    def test_below_limit(self):
        self.cli("-cl", "-k", "6")
        self.assertEqual(self.deleted(), [])

    def test_empty_list(self):
        self.fixture.write_text(" # │ Description\n───┼────────────\n0* │ current\n")
        self.cli("-cl", "-k", "0")
        self.assertEqual(self.deleted(), [])


if __name__ == "__main__":
    unittest.main()
