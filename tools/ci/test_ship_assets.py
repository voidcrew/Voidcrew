import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest

from tools.ci.check_ship_assets import HULLS, MODULES, PREVIEWS, check_assets, main


REGISTRATIONS = '''
/datum/map_template/shuttle/voidcrew/test
    suffix = "test"

/datum/ship_theme/test
    for_ship = /datum/map_template/shuttle/voidcrew/test

/datum/ship_theme/test/dark
    id = "dark"
    template_suffix = "test_dark"

/datum/ship_upgrade_module/test
    for_ship = /datum/map_template/shuttle/voidcrew/test
    for_theme = list(
        "dark",
    )

/datum/ship_upgrade_module/test/lab
    map_file = "test/lab.dmm"
'''


class ShipAssetsTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.write("tgstation.dme", '#include "voidcrew/ships.dm"\n')
        self.write("voidcrew/ships.dm", REGISTRATIONS)
        for name in ("ship_test.dmm", "ship_test_dark.dmm"):
            self.write(HULLS / name)
        for name in ("lab.dmm", "lab_dark.dmm"):
            self.write(MODULES / "test" / name)
        self.manifest = {
            "hulls": {"test": {"png": "ship_test.png"}},
            "modules": {"test/lab.dmm": {
                "png": "test_lab.png",
                "themes": {"dark": {"png": "test_lab_dark.png"}},
            }},
        }
        for name in ("ship_test.png", "test_lab.png", "test_lab_dark.png"):
            self.write(PREVIEWS / name)
        self.save_manifest()

    def write(self, path, text=""):
        path = self.root / path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def save_manifest(self):
        for path in (self.root / PREVIEWS).rglob("*.preview.json"):
            path.unlink()
        for group, entries in self.manifest.items():
            for key, entry in entries.items():
                document = {"tile_px": 32, "hulls": {}, "modules": {}}
                document[group][key] = entry
                self.write(PREVIEWS / group / (key.removesuffix(".dmm") + ".preview.json"), json.dumps(document))

    def append_source(self, source):
        path = self.root / "voidcrew/ships.dm"
        path.write_text(path.read_text() + source)

    def test_registered_hulls_modules_and_inherited_themes_pass(self):
        self.assertEqual(check_assets(self.root), [])

    def test_squab_leftovers_fail_even_with_editor_or_unincluded_references(self):
        old = HULLS / "ship_nanotrasen_squab.dmm"
        png = PREVIEWS / "squab_squab_ai_core_nanotrasen_frigate.png"
        self.write(old)
        self.write(png)
        self.write("voidcrew/unused.dm", '/datum/map_template/shuttle/voidcrew/old\n\tsuffix = "nanotrasen_squab"\n')
        self.write("voidcrew/mapping/ship_projects/squab.ship.json", '{"Suffix": "nanotrasen_squab"}')
        problems = dict(check_assets(self.root))
        self.assertEqual(set(problems), {old, png})
        self.assertIn("register", problems[old])
        self.assertIn("preview metadata", problems[png])

    def test_commented_or_proc_local_registrations_do_not_keep_old_maps(self):
        self.append_source('''
// /datum/map_template/shuttle/voidcrew/old
//     suffix = "old"
/*
/* nested comment */
Documentation can contain https://example.com and unmatched "quotes.
/datum/map_template/shuttle/voidcrew/old
    suffix = "old"
*/
/datum/map_template/shuttle/voidcrew/test/proc/example()
    suffix = "old"
''')
        path = HULLS / "ship_old.dmm"
        self.write(path)
        self.assertEqual([p for p, _ in check_assets(self.root)], [path])

    def test_orphan_module_and_unknown_theme_suffix_fail(self):
        paths = {MODULES / "test/old_lab.dmm", MODULES / "test/lab_obsolete.dmm"}
        for path in paths:
            self.write(path)
        self.assertEqual({p for p, _ in check_assets(self.root)}, paths)

    def test_theme_only_modules_and_optional_variant_fallback_pass(self):
        (self.root / MODULES / "test/lab.dmm").unlink()
        (self.root / PREVIEWS / "test_lab.png").unlink()
        del self.manifest["modules"]["test/lab.dmm"]["png"]
        self.save_manifest()
        self.assertEqual(check_assets(self.root), [])
        # A different module may use the base map for every theme.
        self.append_source('\n/datum/ship_upgrade_module/test/cargo\n    map_file = "test/cargo.dmm"\n')
        self.write(MODULES / "test/cargo.dmm")
        self.assertEqual(check_assets(self.root), [])

    def test_string_theme_filter_and_explicit_parent_type(self):
        self.append_source('''
/datum/ship_upgrade_module/other
    parent_type = /datum/ship_upgrade_module/test
    for_theme = "dark"
    map_file = "test/other.dmm"
''')
        self.write(MODULES / "test/other_dark.dmm")
        self.assertEqual(check_assets(self.root), [])

    def test_unrestricted_modules_use_their_ships_registered_themes(self):
        self.append_source('''
/datum/ship_upgrade_module/test/lab
    for_theme = null
''')
        self.assertEqual(check_assets(self.root), [])

    def test_empty_theme_filter_does_not_accept_every_variant(self):
        self.append_source('\n/datum/ship_upgrade_module/test/lab\n    for_theme = list()\n')
        self.assertEqual([p for p, _ in check_assets(self.root)], [MODULES / "test/lab_dark.dmm"])

    def test_hull_prefix_and_port_are_inherited(self):
        self.append_source('''
/datum/map_template/shuttle/voidcrew/test
    prefix = "_maps/voidcrew/ships/"
    port_id = "custom"
''')
        for suffix in ("test", "test_dark"):
            (self.root / HULLS / f"ship_{suffix}.dmm").rename(self.root / HULLS / f"custom_{suffix}.dmm")
        self.assertEqual(check_assets(self.root), [])

    def test_quoted_comment_markers_do_not_hide_later_fields(self):
        self.append_source('''
/datum/map_template/shuttle/voidcrew/test
    desc = "Contains // and /* text."
    suffix = "test"
''')
        self.assertEqual(check_assets(self.root), [])

    def test_direct_ship_subtype_theme_and_nested_includes(self):
        self.append_source('\n#include "nested.dm"\n')
        self.write("voidcrew/nested.dm", '''
/datum/map_template/shuttle/voidcrew/test/pirate
    suffix = "test_pirate"
    theme = "pirate"
/datum/ship_upgrade_module/test/lab
    for_theme = null
''')
        self.write(HULLS / "ship_test_pirate.dmm")
        self.write(MODULES / "test/lab_pirate.dmm")
        self.assertEqual(check_assets(self.root), [])

    def test_removed_registration_or_manifest_entry_invalidates_existing_files(self):
        self.write("voidcrew/ships.dm", REGISTRATIONS.replace('    suffix = "test"', '    suffix = "replacement"'))
        del self.manifest["modules"]["test/lab.dmm"]["themes"]
        self.save_manifest()
        paths = {p for p, _ in check_assets(self.root)}
        self.assertEqual(paths, {HULLS / "ship_test.dmm", PREVIEWS / "test_lab_dark.png"})

    def test_missing_png_and_unreferenced_nested_png_fail(self):
        missing = PREVIEWS / "test_lab_dark.png"
        extra = PREVIEWS / "old/test.png"
        (self.root / missing).unlink()
        self.write(extra)
        self.assertEqual({p for p, _ in check_assets(self.root)}, {missing, extra})

    def test_legacy_exception_is_one_exact_map_not_a_prefix(self):
        self.write(HULLS / "trader.dmm")
        extra = HULLS / "trader_old.dmm"
        self.write(extra)
        self.assertEqual([p for p, _ in check_assets(self.root)], [extra])

    def test_unsupported_registration_expression_fails_closed(self):
        self.append_source('\n/datum/ship_upgrade_module/test/lab\n    map_file = COMPUTED_MAP\n')
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            self.assertEqual(main(["--root", str(self.root), "--github"]), 1)
        self.assertIn("::error::Cannot validate ship assets", output.getvalue())
        self.assertIn("COMPUTED_MAP", output.getvalue())

    def test_github_annotations_and_success_exit_code(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(main(["--root", str(self.root)]), 0)
        self.write(HULLS / "ship_old.dmm")
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            self.assertEqual(main(["--root", str(self.root), "--github"]), 1)
        self.assertIn("::error file=_maps/voidcrew/ships/ship_old.dmm::", output.getvalue())

    def test_missing_or_malformed_inputs_fail(self):
        for path, text in (("tgstation.dme", '#include "missing.dm"'), (PREVIEWS / "hulls/test.preview.json", "{}")):
            with self.subTest(path=path):
                target = self.root / path
                original = target.read_text()
                self.write(path, text)
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(main(["--root", str(self.root)]), 1)
                self.write(path, original)

    def test_legacy_flat_metadata_files_still_pass(self):
        for index, path in enumerate((self.root / PREVIEWS).rglob("*.preview.json")):
            path.rename(self.root / PREVIEWS / f"legacy{index}.preview.json")
        self.assertEqual(check_assets(self.root), [])

    def test_duplicate_metadata_is_rejected(self):
        source = self.root / PREVIEWS / "hulls/test.preview.json"
        self.write(PREVIEWS / "duplicate.preview.json", source.read_text())
        with self.assertRaisesRegex(ValueError, "duplicate ship preview"):
            check_assets(self.root)

    def test_combined_manifest_cannot_replace_split_metadata(self):
        for path in (self.root / PREVIEWS).rglob("*.preview.json"):
            path.unlink()
        self.write(PREVIEWS / "manifest.json", json.dumps(self.manifest))
        with self.assertRaisesRegex(ValueError, "Regenerate previews"):
            check_assets(self.root)

    def test_metadata_outside_reserved_directories_is_ignored(self):
        self.write(PREVIEWS / "backups/old.preview.json", "invalid backup")
        self.assertEqual(check_assets(self.root), [])

    def test_invalid_metadata_size_count_and_entry_are_rejected(self):
        path = PREVIEWS / "hulls/test.preview.json"
        for document in (
            {"tile_px": 16, "hulls": {"test": {}}, "modules": {}},
            {"tile_px": 32, "hulls": {}, "modules": {}},
            {"tile_px": 32, "hulls": {"test": {}, "other": {}}, "modules": {}},
            {"tile_px": 32, "hulls": {"test": []}, "modules": {}},
        ):
            with self.subTest(document=document):
                self.write(path, json.dumps(document))
                with self.assertRaises(ValueError):
                    check_assets(self.root)


if __name__ == "__main__":
    unittest.main()
