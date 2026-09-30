import contextlib
import io
from pathlib import Path
import unittest

from tools.ci.check_voidworks_compat import DECLARATION, WATCHED, main, reminders


class VoidworksCompatReminderTest(unittest.TestCase):
    def test_watched_files_exist(self):
        root = Path(__file__).resolve().parents[2]
        for name in WATCHED:
            self.assertTrue((root / name).is_file(), f"{name} moved; update WATCHED")

    def test_watched_change_is_reported(self):
        found = reminders(["voidcrew/edits/jobs.dm", "code/game/objects/items.dm", ""])
        self.assertEqual(found, [("voidcrew/edits/jobs.dm", "ship crew roles")])

    def test_compatibility_update_silences_reminder(self):
        self.assertEqual(reminders(["voidcrew/edits/jobs.dm", DECLARATION]), [])

    def test_unrelated_changes_pass_quietly(self):
        self.assertEqual(reminders(["_maps/voidcrew/ships/ship_squab_a.dmm", "voidcrew/mapping/ship_projects/squab.ship.json"]), [])

    def test_github_warning_never_fails(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = main(["--github"], io.StringIO("code/datums/ruins.dm\n"))
        self.assertEqual(status, 0)
        self.assertIn("::warning file=code/datums/ruins.dm::", output.getvalue())


if __name__ == "__main__":
    unittest.main()
