#!/usr/bin/env python3
import tempfile
import unittest
from pathlib import Path
from scan_release_secrets import scan


class ReleaseSecretScannerTests(unittest.TestCase):
    def test_generic_key_in_binary_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "executable"
            path.write_bytes(b"\0MachO\0" + b"sk-" + b"sample" * 6 + b"\0")
            scanned, findings = scan([path])
            self.assertEqual(scanned, 1)
            self.assertEqual(len(findings), 1)
            self.assertNotIn("sample", findings[0][1])

    def test_arbitrary_local_key_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "executable"
            fixture = b"local-credential-fixture"
            path.write_bytes(b"\0" + fixture + b"\0")
            self.assertEqual(len(scan([path], [fixture])[1]), 1)

    def test_zero_fixture_is_allowed(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.swift"
            path.write_bytes(b"sk-" + b"0" * 36)
            self.assertFalse(scan([path])[1])

    def test_bundle_allows_only_release_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Contents").mkdir()
            (root / "Contents/Info.plist").write_text("safe")
            self.assertFalse(scan([root], bundle=True)[1])
            (root / "Contents/local-preferences.plist").write_text("private")
            self.assertEqual(len(scan([root], bundle=True)[1]), 1)

    def test_bundle_rejects_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "local-file").write_text("safe")
            (root / "link").symlink_to(root / "local-file")
            self.assertTrue(any(reason == "不允许的符号链接" for _, reason in scan([root])[1]))


if __name__ == "__main__":
    unittest.main()
