import contextlib
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest

from tools.ci.check_ship_previews import HULLS, MODULES, PREVIEWS, check_previews, main


class ShipPreviewsTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.write(HULLS / "ship_test_a.dmm", "hull\n")
        self.write(MODULES / "test/lab.dmm", "lab\n")
        self.write(MODULES / "test/lab_dark.dmm", "dark lab\n")
        self.hull = {"png": "ship_test_a.png", "src_md5": self.md5(HULLS / "ship_test_a.dmm")}
        self.module = {"png": "test_lab.png", "src_md5": self.md5(MODULES / "test/lab.dmm"), "themes": {
            "dark": {"png": "test_lab_dark.png", "src_md5": self.md5(MODULES / "test/lab_dark.dmm")}}}
        self.save()

    def write(self, path, text):
        path = self.root / path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(text.encode())

    def md5(self, path):
        return hashlib.md5((self.root / path).read_bytes()).hexdigest()

    def save(self):
        self.write(PREVIEWS / "hulls/test_a.preview.json",
                   json.dumps({"tile_px": 32, "hulls": {"test_a": self.hull}, "modules": {}}))
        self.write(PREVIEWS / "modules/test/lab.preview.json",
                   json.dumps({"tile_px": 32, "hulls": {}, "modules": {"test/lab.dmm": self.module}}))

    def test_current_previews_pass(self):
        self.assertEqual(check_previews(self.root), [])

    def test_edited_hull_and_theme_are_reported(self):
        self.write(HULLS / "ship_test_a.dmm", "edited hull\n")
        self.write(MODULES / "test/lab_dark.dmm", "edited dark lab\n")
        problems = check_previews(self.root)
        self.assertEqual([path.as_posix() for path, _ in problems],
                         [(HULLS / "ship_test_a.dmm").as_posix(), (MODULES / "test/lab_dark.dmm").as_posix()])
        self.assertIn("ship_test_a.png", problems[0][1])

    def test_windows_line_endings_are_the_same_map(self):
        self.write(HULLS / "ship_test_a.dmm", "hull\r\n")
        self.assertEqual(check_previews(self.root), [])

    def test_missing_hash_is_reported(self):
        del self.hull["src_md5"]
        self.save()
        self.assertIn("has no src_md5", check_previews(self.root)[0][1])

    def test_github_annotations_and_exit_code(self):
        self.write(MODULES / "test/lab.dmm", "edited lab\n")
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = main(["--root", str(self.root), "--github"])
        self.assertEqual(status, 1)
        self.assertIn(f"::error file={(MODULES / 'test/lab.dmm').as_posix()}::", output.getvalue())


if __name__ == "__main__":
    unittest.main()
