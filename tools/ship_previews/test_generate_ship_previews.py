import re
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image, ImageChops

import generate_ship_previews as previews


class ModuleDiscoveryTests(unittest.TestCase):
    def test_workshop_and_nested_registrations_are_discovered_once(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            ships = root / "ships"
            workshop = root / "workshop"
            (ships / "nested").mkdir(parents=True)
            (workshop / "nested").mkdir(parents=True)
            (ships / "delta.dm").write_text('map_file = "delta/cabins.dmm"\n')
            (ships / "nested/extra.dm").write_text('map_file = "delta/lab.dmm"\n')
            (workshop / "bogatyr.dm").write_text(
                '/datum/ship_upgrade_module/workshop_bogatyr_engineering\n'
                '\tmap_file = "bogatyr/workshop/engineering_basic.dmm"\n')
            (workshop / "nested/extra.dm").write_text(
                '\tmap_file = "bogatyr/workshop/engineering_basic.dmm"\n'
                '\tmap_file = "bogatyr/workshop/surgical_suite.dmm"\n')
            (root / "unrelated.dm").write_text('map_file = "unrelated.dmm"\n')
            with patch.object(previews, "SHIP_DM_DIR", ships):
                self.assertEqual(previews.collect_base_module_files(), [
                    "delta/cabins.dmm", "delta/lab.dmm",
                    "bogatyr/workshop/engineering_basic.dmm", "bogatyr/workshop/surgical_suite.dmm",
                ])

    def test_workshop_modules_and_theme_only_options_reach_manifest(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            ships = root / "voidcrew/modules/ship_upgrades/ships"
            workshop = ships.parent / "workshop"
            workshop.mkdir(parents=True)
            ships.mkdir()
            maps = root / "_maps/voidcrew/ship_modules"
            rooms = maps / "bogatyr/workshop"
            rooms.mkdir(parents=True)
            (workshop / "bogatyr.dm").write_text(
                '/datum/ship_upgrade_module/workshop_bogatyr_engineering\n'
                '\tmap_file = "bogatyr/workshop/engineering_basic.dmm"\n'
                '/datum/ship_upgrade_module/workshop_bogatyr_surgery\n'
                '\tmap_file = "bogatyr/workshop/surgical_suite.dmm"\n')
            names = ["engineering_basic", "engineering_basic_freshen_up", "engineering_basic_nightclub", "surgical_suite_nightclub", "surgical_suite_trashed"]
            for name in names:
                (rooms / (name + ".dmm")).write_text(
                    '"a" = (/obj/modular_map_connector,/turf/open/floor/plating,/area/template_noop)\n'
                    '(1,1,1) = {"\na\n"}\n')
            output = root / "previews"
            rendered = []

            def render(tool, source, destination, temp, dmm):
                rendered.append(source.stem)
                Image.new("RGBA", (32, 32), (80, 100, 120, 255)).save(destination)

            with patch.multiple(previews, REPO_ROOT=root, SHIP_DM_DIR=ships,
                                MODULES_DIR=maps, SHIPS_DIR=root / "hulls", OUTPUT_DIR=output), \
                    patch.object(previews, "find_dmm_tools", return_value=Path("unused")), \
                    patch.object(previews, "render", side_effect=render), \
                    contextlib.redirect_stdout(io.StringIO()):
                previews.main()
            manifest = {"hulls": {}, "modules": {}}
            for path in output.rglob("*.preview.json"):
                document = json.loads(path.read_text())
                for group in manifest:
                    manifest[group].update(document[group])
            self.assertFalse((output / "manifest.json").exists())
            self.assertCountEqual(rendered, names)
            engineering = manifest["modules"]["bogatyr/workshop/engineering_basic.dmm"]
            self.assertEqual(engineering["connector"], [1, 1])
            self.assertEqual(set(engineering["themes"]), {"freshen_up", "nightclub"})
            surgery = manifest["modules"]["bogatyr/workshop/surgical_suite.dmm"]
            self.assertNotIn("png", surgery)
            self.assertEqual(set(surgery["themes"]), {"nightclub", "trashed"})
            self.assertEqual(len(list(output.glob("*.png"))), 5)


class MetadataTests(unittest.TestCase):
    def test_independent_edits_do_not_change_other_metadata(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder)
            manifest = {"tile_px": 32, "hulls": {
                "alpha": {"png": "alpha.png", "src_md5": "old"},
                "beta": {"png": "beta.png", "src_md5": "same"},
            }, "modules": {"alpha/room.dmm": {"themes": {"blue": {"png": "room_blue.png"}}}}}
            (output / "manifest.json").write_text(json.dumps(manifest))
            previews.write_preview_metadata(manifest, output)
            before = {p.relative_to(output).as_posix(): (p.read_bytes(), p.stat().st_mtime_ns) for p in output.rglob("*.preview.json")}
            manifest["hulls"]["alpha"]["src_md5"] = "new"
            previews.write_preview_metadata(manifest, output)
            changed = {p.relative_to(output).as_posix() for p in output.rglob("*.preview.json") if before[p.relative_to(output).as_posix()] != (p.read_bytes(), p.stat().st_mtime_ns)}
            self.assertEqual(changed, {"hulls/alpha.preview.json"})
            self.assertIn("modules/alpha/room.preview.json", before)
            del manifest["hulls"]["alpha"]
            previews.write_preview_metadata(manifest, output)
            self.assertFalse((output / "hulls/alpha.preview.json").exists())
            self.assertFalse((output / "manifest.json").exists())

    def test_nested_module_paths_and_flat_migration(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder)
            keys = ["a/b.dmm", "a_b.dmm", "other/workshop/b.dmm"]
            manifest = {"tile_px": 32, "hulls": {}, "modules": {key: {} for key in keys}}
            (output / "module.a%2Fb.dmm.preview.json").write_text("old metadata")
            previews.write_preview_metadata(manifest, output)
            self.assertEqual({p.relative_to(output).as_posix() for p in output.rglob("*.preview.json")}, {
                "modules/a/b.preview.json", "modules/a_b.preview.json", "modules/other/workshop/b.preview.json"})

    def test_unsafe_keys_cannot_escape_metadata_directory(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder)
            for key in ("../outside.dmm", "/outside.dmm", "C:/outside.dmm", "a/../../outside.dmm", "a\\outside.dmm"):
                with self.subTest(key=key), self.assertRaises(ValueError):
                    previews.write_preview_metadata({"tile_px": 32, "hulls": {}, "modules": {key: {}}}, output)
            self.assertFalse(list(output.iterdir()))


def map_with_window(window_path):
    """A window beside another window and a shuttle wall."""
    dmm = previews.Dmm.__new__(previews.Dmm)
    dmm.width = dmm.height = 3
    dmm.grid = {(x, y): "floor" for x in range(1, 4) for y in range(1, 4)}
    dmm.grid.update({(2, 2): "window", (2, 3): "neighbor", (3, 2): "wall"})
    dmm.key_paths = {
        "floor": ["/turf/open/floor/plating"],
        "window": [window_path, "/turf/open/floor/plating"],
        "neighbor": ["/obj/structure/window/reinforced/shuttle", "/turf/open/floor/plating"],
        "wall": ["/turf/closed/wall/mineral/titanium"],
    }
    return dmm


class WindowSpawnerTests(unittest.TestCase):
    def test_spawners_match_runtime_spawn_lists(self):
        source = (previews.REPO_ROOT / "code/game/objects/effects/spawners/structure.dm").read_text()
        for spawner, window in previews.WINDOW_SPAWNERS.items():
            with self.subTest(spawner=spawner):
                definition = re.search(r"^" + re.escape(spawner) + r"\n((?:\t[^\n]*\n)*)", source, re.M)
                self.assertIsNotNone(definition)
                spawn_list = re.search(r"spawn_list = list\(([^\n]*)\)", definition.group(1))
                self.assertIsNotNone(spawn_list)
                self.assertIn(window, spawn_list.group(1).split(", "))

    def test_spawners_render_like_placed_windows(self):
        background = Image.new("RGBA", (96, 96), (40, 40, 40, 255))
        for spawner, window in previews.WINDOW_SPAWNERS.items():
            with self.subTest(spawner=spawner):
                expected = previews.apply_smoothing_fixes(map_with_window(window), background, background)
                actual = previews.apply_smoothing_fixes(map_with_window(spawner), background, background)
                self.assertIsNone(ImageChops.difference(expected, actual).getbbox(alpha_only=False))
                window_box = (32, 32, 64, 64)
                self.assertIsNotNone(ImageChops.difference(
                    actual.crop(window_box), background.crop(window_box),
                ).getbbox(alpha_only=False))

    def test_spawners_join_windows_and_frame_shuttle_walls(self):
        dmm = map_with_window("/obj/effect/spawner/structure/window/reinforced/shuttle")
        turfs, _, windows = previews.build_join_sets(dmm)
        self.assertEqual(previews.junction_at(2, 2, windows["shuttle_window"]), 1)
        self.assertEqual(previews.junction_at(3, 2, turfs["shuttle_wall"]), 8)
        self.assertNotIn((2, 2), turfs["wall"])

    def test_indestructible_spawner_inherits_shuttle_glass(self):
        self.assertEqual(
            previews.smooth_obj_entry("/obj/effect/spawner/structure/window/reinforced/shuttle/indestructible"),
            previews.smooth_obj_entry("/obj/structure/window/reinforced/shuttle/indestructible"),
        )

    def test_directional_windows_do_not_get_fulltile_glass(self):
        for path in (
            "/obj/effect/spawner/structure/window/hollow",
            "/obj/effect/spawner/structure/window/hollow/reinforced/directional",
            "/obj/structure/window/reinforced/spawner/directional/north",
            "/obj/effect/spawner/structure/windowless",
        ):
            with self.subTest(path=path):
                self.assertIsNone(previews.smooth_obj_entry(path))


if __name__ == "__main__":
    unittest.main()
