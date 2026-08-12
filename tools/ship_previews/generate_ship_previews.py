#!/usr/bin/env python3
"""Generate ship preview assets for the ShipUpgradeSelector TGUI.

Scans hull DMMs for /obj/modular_map_root/ship_upgrade slot markers and module
DMMs for their /obj/modular_map_connector anchor, renders everything to PNG via
dmm-tools, and writes a manifest.json describing the compositing geometry.

dmm-tools' icon-smoothing pass implements the pre-2020 corner system, so
anything using modern bitmask smoothing (walls, carpets, tables) renders as
nothing. We repair that here:
  - walls/carpets: compute the bitmask junction ourselves and paste the exact
    `<base>-<junction>` dmi sprite as an underlay (wallmounts/posters that
    rendered on top of the wall tile stay on top)
  - tables/falsewalls (objects sandwiched between floor and items): copy those
    tiles from a second render done with --disable icon-smoothing, where they
    draw their unsmoothed default state in correct layer order
  - fulltile/shuttle windows: compute the junction ourselves and composite the
    sprite ON TOP of the render (the window draws over its grille; the glass
    is translucent so the grille stays visible)

Outputs (commit these):
    voidcrew/modules/ship_upgrades/previews/manifest.json
    voidcrew/modules/ship_upgrades/previews/*.png

Run from the repo root after editing modular hulls or modules:
    python tools/ship_previews/generate_ship_previews.py

dmm-tools location: $DMM_TOOLS or ~/code/tg-tools/bin/dmm-tools.exe
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[2]
SHIPS_DIR = REPO_ROOT / "_maps" / "voidcrew" / "ships"
MODULES_DIR = REPO_ROOT / "_maps" / "voidcrew" / "ship_modules"
SHIP_DM_DIR = REPO_ROOT / "voidcrew" / "modules" / "ship_upgrades" / "ships"
OUTPUT_DIR = REPO_ROOT / "voidcrew" / "modules" / "ship_upgrades" / "previews"

MARKER_PATH = "/obj/modular_map_root/ship_upgrade"
CONNECTOR_PATH = "/obj/modular_map_connector"
TILE_PX = 32

# Non-modular hulls sold anyway (force_purchasable in DM): rendered with no slots
# so the upgrade selector still gets a preview image.
EXTRA_HULLS = ("ship_pill.dmm", "ship_pill_black.dmm")

# Must be passed explicitly: left to itself dmm-tools picks up the gitignored,
# always-stale `tgstation.test.dme` and renders anything it defines as a black
# tile ("bad path: ...").
ENVIRONMENT = "tgstation.dme"

# --- Smoothing repair registries ---------------------------------------------
# Turf types whose smoothed sprite we paint as an underlay.
# type path -> (dmi path, base_icon_state, join group)
# Longest matching path prefix wins, so subtypes (nodiagonal, rust, ...) inherit.
# Join groups (mirroring DM canSmoothWith):
#   wall          joins other walls/doors/falsewalls only
#   shuttle_wall  additionally extends toward shuttle parts (shuttle and
#                 plastitanium windows, shuttle engines) - the window does NOT
#                 extend back, matching in-game framing
#   pod_wall      shuttle_wall plus regular fulltile windows
SMOOTH_TURFS = {
    "/turf/closed/wall": ("icons/turf/walls/wall.dmi", "wall", "wall"),
    "/turf/closed/wall/r_wall": ("icons/turf/walls/reinforced_wall.dmi", "reinforced_wall", "wall"),
    "/turf/closed/wall/r_wall/plastitanium": ("icons/turf/walls/plastitanium_wall.dmi", "plastitanium_wall", "shuttle_wall"),
    "/turf/closed/wall/mineral/gold": ("icons/turf/walls/gold_wall.dmi", "gold_wall", "wall"),
    "/turf/closed/wall/mineral/silver": ("icons/turf/walls/silver_wall.dmi", "silver_wall", "wall"),
    "/turf/closed/wall/mineral/diamond": ("icons/turf/walls/diamond_wall.dmi", "diamond_wall", "wall"),
    "/turf/closed/wall/mineral/bananium": ("icons/turf/walls/bananium_wall.dmi", "bananium_wall", "wall"),
    "/turf/closed/wall/mineral/sandstone": ("icons/turf/walls/sandstone_wall.dmi", "sandstone_wall", "wall"),
    "/turf/closed/wall/mineral/uranium": ("icons/turf/walls/uranium_wall.dmi", "uranium_wall", "wall"),
    "/turf/closed/wall/mineral/plasma": ("icons/turf/walls/plasma_wall.dmi", "plasma_wall", "wall"),
    "/turf/closed/wall/mineral/wood": ("icons/turf/walls/wood_wall.dmi", "wood_wall", "wall"),
    "/turf/closed/wall/mineral/bamboo": ("icons/turf/walls/bamboo_wall.dmi", "bamboo_wall", "wall"),
    "/turf/closed/wall/mineral/iron": ("icons/turf/walls/iron_wall.dmi", "iron_wall", "wall"),
    "/turf/closed/wall/mineral/snow": ("icons/turf/walls/snow_wall.dmi", "snow_wall", "wall"),
    "/turf/closed/wall/mineral/abductor": ("icons/turf/walls/abductor_wall.dmi", "abductor_wall", "wall"),
    "/turf/closed/wall/mineral/titanium": ("icons/turf/walls/shuttle_wall.dmi", "shuttle_wall", "shuttle_wall"),
    "/turf/closed/wall/mineral/titanium/survival": ("icons/turf/walls/survival_pod_walls.dmi", "survival_pod_walls", "pod_wall"),
    "/turf/closed/wall/mineral/titanium/dollhouse": ("voidcrew/icons/turf/walls/dollhouse_wall.dmi", "shuttle_wall", "shuttle_wall"),
    "/turf/closed/wall/mineral/plastitanium": ("icons/turf/walls/plastitanium_wall.dmi", "plastitanium_wall", "shuttle_wall"),
    "/turf/closed/wall/mineral/cult": ("icons/turf/walls/cult_wall.dmi", "cult_wall", "wall"),
    "/turf/open/floor/carpet": ("icons/turf/floors/carpet.dmi", "carpet", "carpet"),
}

# Bitmask-smoothed objects drawn as an overlay on top of the render.
# type path -> (dmi path, base_icon_state, join group)
# Join groups mirror DM's canSmoothWith: each window family only connects to
# itself (fulltile windows are SMOOTH_GROUP_WINDOW_FULLTILE, shuttle windows
# only WINDOW_FULLTILE_SHUTTLE, etc.), never to walls.
SMOOTH_OBJS = {
    "/obj/structure/window/fulltile": ("icons/obj/smooth_structures/window.dmi", "window", "window"),
    "/obj/structure/window/plasma/fulltile": ("icons/obj/smooth_structures/plasma_window.dmi", "plasma_window", "window"),
    "/obj/structure/window/reinforced/fulltile": ("icons/obj/smooth_structures/reinforced_window.dmi", "reinforced_window", "window"),
    "/obj/structure/window/reinforced/fulltile/ice": ("icons/obj/smooth_structures/rice_window.dmi", "rice_window", "window"),
    "/obj/structure/window/reinforced/plasma/fulltile": ("icons/obj/smooth_structures/rplasma_window.dmi", "rplasma_window", "window"),
    "/obj/structure/window/reinforced/tinted/fulltile": ("icons/obj/smooth_structures/tinted_window.dmi", "tinted_window", "window"),
    "/obj/structure/window/reinforced/shuttle": ("icons/obj/smooth_structures/shuttle_window.dmi", "shuttle_window", "shuttle_window"),
    "/obj/structure/window/reinforced/shuttle/survival_pod": ("icons/obj/smooth_structures/pod_window.dmi", "pod_window", "pod_window"),
    "/obj/structure/window/reinforced/plasma/plastitanium": ("icons/obj/smooth_structures/plastitanium_window.dmi", "plastitanium_window", "plastitanium_window"),
    "/obj/structure/window/bronze/fulltile": ("icons/obj/smooth_structures/clockwork_window.dmi", "clockwork_window", "bronze_window"),
}

# Non-window tiles that also count as joins for a window group
# (pod windows connect to pod walls/airlocks: SMOOTH_GROUP_SURVIVAL_TITANIUM_POD)
WINDOW_JOIN_EXTRA = {
    "pod_window": (
        "/turf/closed/wall/mineral/titanium/survival/pod",
        "/obj/machinery/door/airlock/survival_pod",
    ),
}

# SMOOTH_GROUP_SHUTTLE_PARTS members: what shuttle_wall/pod_wall extend toward
# (opsglass is /turf/closed and therefore already a wall join)
SHUTTLE_PARTS_PREFIXES = (
    "/obj/structure/window/reinforced/shuttle",
    "/obj/structure/window/reinforced/plasma/plastitanium",
    "/obj/machinery/power/shuttle_engine",
)

# A tile joins the "wall" smoothing group when it holds any of these
WALL_JOIN_PREFIXES = (
    "/turf/closed",
    "/obj/machinery/door",
    "/obj/structure/falsewall",
)
# ...except firedoors, which sit on open hallway tiles and must not attract walls
WALL_JOIN_EXCLUDE = ("/obj/machinery/door/firedoor",)

# Objects sandwiched between the floor and their contents: tiles holding these
# are copied wholesale from the --disable icon-smoothing render
COPY_B_PREFIXES = (
    "/obj/structure/table",
    "/obj/structure/falsewall",
)

# Junction bits (tg icon_smoothing.dm): N/S/E/W then diagonals
JUNCTION_CARDINALS = ((1, 0, 1), (2, 0, -1), (4, 1, 0), (8, -1, 0))
JUNCTION_DIAGONALS = ((16, 1, 4, 1, 1), (32, 2, 4, 1, -1), (64, 2, 8, -1, -1), (128, 1, 8, -1, 1))


def path_matches(path: str, prefix: str) -> bool:
    """DM type-path prefix match on segment boundaries."""
    return path == prefix or path.startswith(prefix + "/")


def find_dmm_tools() -> Path:
    candidate = os.environ.get("DMM_TOOLS")
    if candidate and Path(candidate).is_file():
        return Path(candidate)
    default = Path.home() / "code" / "tg-tools" / "bin" / "dmm-tools.exe"
    if default.is_file():
        return default
    sys.exit("dmm-tools not found: set $DMM_TOOLS or place it at ~/code/tg-tools/bin/dmm-tools.exe")


class Dmm:
    """Minimal TGM/legacy .dmm parser: key definitions + grid coordinates."""

    def __init__(self, path: Path):
        self.path = path
        text = path.read_text(encoding="utf-8")

        # "AB" = (\n.../area/foo)  -- the area path is always the last entry
        self.keys: dict[str, str] = {}
        lines = text.splitlines()
        i = 0
        while i < len(lines) and not lines[i].startswith("("):
            single = re.match(r'"([^"]+)" = \((.*)\)\s*$', lines[i])
            multi = re.match(r'"([^"]+)" = \($', lines[i])
            if single:
                self.keys[single.group(1)] = single.group(2)
            elif multi:
                body = []
                i += 1
                while i < len(lines):
                    body.append(lines[i])
                    if lines[i].startswith("/area") and lines[i].endswith(")"):
                        break
                    i += 1
                self.keys[multi.group(1)] = "\n".join(body)[:-1]
            i += 1
        if not self.keys:
            sys.exit(f"{path}: no key definitions parsed")
        self.key_length = len(next(iter(self.keys)))
        self.key_paths = {
            key: re.findall(r"/(?:turf|obj|mob|area)(?:/\w+)*", body)
            for key, body in self.keys.items()
        }

        # grid[(x, y)] = key, with y=1 at the bottom (BYOND convention)
        self.grid: dict[tuple[int, int], str] = {}
        blocks = re.findall(r'\((\d+),(\d+),(\d+)\) = \{"\n(.*?)\n"\}', text, re.DOTALL)
        if not blocks:
            sys.exit(f"{path}: no grid blocks parsed")
        for bx, by, _bz, body in blocks:
            bx, by = int(bx), int(by)
            lines = body.split("\n")
            keys_per_line = len(lines[0]) // self.key_length
            if keys_per_line == 1:
                # TGM: one block per column, lines run top -> bottom
                height = len(lines)
                for i, line in enumerate(lines):
                    self.grid[(bx, by + height - 1 - i)] = line
            else:
                # Legacy: one block of rows, each line is a full row, top -> bottom
                height = len(lines)
                for i, line in enumerate(lines):
                    y = by + height - 1 - i
                    for j in range(keys_per_line):
                        key = line[j * self.key_length:(j + 1) * self.key_length]
                        self.grid[(bx + j, y)] = key

        self.width = max(x for x, _ in self.grid)
        self.height = max(y for _, y in self.grid)

    def find_instances(self, type_path: str) -> list[tuple[int, int, str]]:
        """Return (x, y, props_text) for each instance of type_path on the grid."""
        pattern = re.compile(re.escape(type_path) + r"(\{[^}]*\})?[,\n)]")
        matching: dict[str, str] = {}
        for key, body in self.keys.items():
            hit = pattern.search(body + "\n")
            if hit:
                matching[key] = hit.group(1) or ""
        results = []
        for (x, y), key in self.grid.items():
            if key in matching:
                results.append((x, y, matching[key]))
        return sorted(results)


def collect_base_module_files() -> list[str]:
    """map_file values registered in the ship upgrade module datums."""
    files: list[str] = []
    for dm_file in sorted(SHIP_DM_DIR.glob("*.dm")):
        for match in re.finditer(r'map_file = "([^"]+)"', dm_file.read_text(encoding="utf-8")):
            if match.group(1) not in files:
                files.append(match.group(1))
    return files


class Dmi:
    """Minimal .dmi reader: state name -> first-dir first-frame sprite."""

    _cache: dict[str, "Dmi | None"] = {}

    def __init__(self, path: Path):
        image = Image.open(path)
        desc = image.text.get("Description", "")
        self.icon_w = self.icon_h = 32
        self.index: dict[str, int] = {}
        sprite_index = 0
        state_name = None
        dirs = frames = 1
        for line in desc.splitlines():
            line = line.strip()
            if line.startswith("width ="):
                self.icon_w = int(line.split("=")[1])
            elif line.startswith("height ="):
                self.icon_h = int(line.split("=")[1])
            elif line.startswith("state ="):
                if state_name is not None:
                    sprite_index += dirs * frames
                state_name = line.split("=", 1)[1].strip().strip('"')
                dirs = frames = 1
                self.index.setdefault(state_name, sprite_index)
            elif line.startswith("dirs ="):
                dirs = int(line.split("=")[1])
            elif line.startswith("frames ="):
                frames = int(line.split("=")[1])
        self.image = image.convert("RGBA")
        self.columns = max(1, self.image.width // self.icon_w)

    @classmethod
    def load(cls, rel_path: str) -> "Dmi | None":
        if rel_path not in cls._cache:
            full = REPO_ROOT / rel_path
            cls._cache[rel_path] = cls(full) if full.is_file() else None
            if cls._cache[rel_path] is None:
                print(f"WARN: missing dmi {rel_path}")
        return cls._cache[rel_path]

    def sprite(self, state: str) -> Image.Image | None:
        idx = self.index.get(state)
        if idx is None:
            return None
        x = (idx % self.columns) * self.icon_w
        y = (idx // self.columns) * self.icon_h
        return self.image.crop((x, y, x + self.icon_w, y + self.icon_h))


def smooth_turf_at(dmm: Dmm, x: int, y: int):
    """Longest-prefix SMOOTH_TURFS entry for the tile's turf, or None."""
    key = dmm.grid.get((x, y))
    if key is None:
        return None
    best = None
    best_len = -1
    for path in dmm.key_paths[key]:
        if not path.startswith("/turf/"):
            continue
        for prefix, entry in SMOOTH_TURFS.items():
            if path_matches(path, prefix) and len(prefix) > best_len:
                best = entry
                best_len = len(prefix)
    return best


def smooth_obj_entry(path: str):
    """Longest-prefix SMOOTH_OBJS entry for an obj path, or None."""
    best = None
    best_len = -1
    for prefix, entry in SMOOTH_OBJS.items():
        if path_matches(path, prefix) and len(prefix) > best_len:
            best = entry
            best_len = len(prefix)
    return best


def smooth_obj_at(dmm: Dmm, x: int, y: int):
    key = dmm.grid.get((x, y))
    if key is None:
        return None
    for path in dmm.key_paths[key]:
        entry = smooth_obj_entry(path)
        if entry:
            return entry
    return None


def build_join_sets(dmm: Dmm) -> tuple[dict, set, dict]:
    """Precompute per-tile membership: one join set per turf group (wall families,
    carpet), copy-from-B tiles, and one join set per window group."""
    wall_join: set[tuple[int, int]] = set()
    carpet: set[tuple[int, int]] = set()
    copy_b: set[tuple[int, int]] = set()
    shuttle_parts: set[tuple[int, int]] = set()
    window_joins: dict[str, set[tuple[int, int]]] = {
        entry[2]: set() for entry in SMOOTH_OBJS.values()
    }
    for pos, key in dmm.grid.items():
        for path in dmm.key_paths[key]:
            if any(path_matches(path, p) for p in WALL_JOIN_PREFIXES) and not any(
                path_matches(path, p) for p in WALL_JOIN_EXCLUDE
            ):
                wall_join.add(pos)
            if path.startswith("/turf/") and path_matches(path, "/turf/open/floor/carpet"):
                carpet.add(pos)
            if any(path_matches(path, p) for p in COPY_B_PREFIXES):
                copy_b.add(pos)
            if any(path_matches(path, p) for p in SHUTTLE_PARTS_PREFIXES):
                shuttle_parts.add(pos)
            obj_entry = smooth_obj_entry(path)
            if obj_entry:
                window_joins[obj_entry[2]].add(pos)
            for group, prefixes in WINDOW_JOIN_EXTRA.items():
                if any(path_matches(path, p) for p in prefixes):
                    window_joins[group].add(pos)
    turf_joins = {
        "wall": wall_join,
        "shuttle_wall": wall_join | shuttle_parts,
        "pod_wall": wall_join | shuttle_parts | window_joins["window"],
        "carpet": carpet,
    }
    return turf_joins, copy_b, window_joins


def junction_at(x: int, y: int, joins: set) -> int:
    j = 0
    for bit, dx, dy in JUNCTION_CARDINALS:
        if (x + dx, y + dy) in joins:
            j |= bit
    for bit, need_a, need_b, dx, dy in JUNCTION_DIAGONALS:
        if (j & need_a) and (j & need_b) and (x + dx, y + dy) in joins:
            j |= bit
    return j


def junction_sprite(dmi: Dmi, base_state: str, junction: int) -> Image.Image | None:
    return (
        dmi.sprite(f"{base_state}-{junction}")
        or dmi.sprite(f"{base_state}-{junction & 15}")
        or dmi.sprite(f"{base_state}-0")
    )


def apply_smoothing_fixes(dmm: Dmm, render_a: Image.Image, render_b: Image.Image) -> Image.Image:
    """Underlay computed wall/carpet sprites, patch table tiles from render B,
    then overlay computed window sprites."""
    T = TILE_PX
    turf_joins, copy_b, window_joins = build_join_sets(dmm)
    out = Image.new("RGBA", render_a.size, (0, 0, 0, 0))

    for (x, y) in dmm.grid:
        entry = smooth_turf_at(dmm, x, y)
        if not entry:
            continue
        dmi_path, base_state, group = entry
        dmi = Dmi.load(dmi_path)
        if not dmi:
            continue
        junction = junction_at(x, y, turf_joins[group])
        sprite = junction_sprite(dmi, base_state, junction)
        if not sprite:
            print(f"WARN: no sprite {base_state}-{junction} in {dmi_path}")
            continue
        out.alpha_composite(sprite, ((x - 1) * T, (dmm.height - y) * T))

    out.alpha_composite(render_a)

    for (x, y) in copy_b:
        box = ((x - 1) * T, (dmm.height - y) * T, x * T, (dmm.height - y + 1) * T)
        out.paste(render_b.crop(box), box)

    for (x, y) in dmm.grid:
        entry = smooth_obj_at(dmm, x, y)
        if not entry:
            continue
        dmi_path, base_state, group = entry
        dmi = Dmi.load(dmi_path)
        if not dmi:
            continue
        junction = junction_at(x, y, window_joins[group])
        sprite = junction_sprite(dmi, base_state, junction)
        if not sprite:
            print(f"WARN: no sprite {base_state}-{junction} in {dmi_path}")
            continue
        out.alpha_composite(sprite, ((x - 1) * T, (dmm.height - y) * T))

    return out


def render_pass(dmm_tools: Path, dmm_path: Path, tmp_dir: Path, extra_args: list[str]) -> Path:
    out_dir = tmp_dir / ("nosmooth" if extra_args else "normal")
    out_dir.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        [str(dmm_tools), "-e", ENVIRONMENT, "minimap", *extra_args, "-o", str(out_dir), str(dmm_path)],
        cwd=REPO_ROOT, capture_output=True, text=True,
    )
    rendered = out_dir / f"{dmm_path.stem}-1.png"
    if result.returncode != 0 or not rendered.is_file():
        sys.exit(f"dmm-tools render failed for {dmm_path}:\n{result.stdout}\n{result.stderr}")
    return rendered


def render(dmm_tools: Path, dmm_path: Path, out_png: Path, tmp_dir: Path, dmm: Dmm) -> None:
    pass_a = render_pass(dmm_tools, dmm_path, tmp_dir, [])
    pass_b = render_pass(dmm_tools, dmm_path, tmp_dir, ["--disable", "icon-smoothing"])
    with Image.open(pass_a) as render_a, Image.open(pass_b) as render_b:
        fixed = apply_smoothing_fixes(dmm, render_a.convert("RGBA"), render_b.convert("RGBA"))
    out_png.parent.mkdir(parents=True, exist_ok=True)
    fixed.save(out_png)


def source_md5(dmm_path: Path) -> str:
    """MD5 of the .dmm this preview was rendered from.

    The purchase screen shows committed PNGs, so a map edit is invisible there
    until the previews are regenerated. DM has no way to read a file's mtime,
    so the manifest carries the source hash instead and
    /datum/unit_test/voidcrew_ship_previews compares it against the map on disk
    with rustg_hash_file(). Raw bytes, to match what rustg hashes.
    """
    return hashlib.md5(dmm_path.read_bytes()).hexdigest()


def module_geometry(dmm: Dmm) -> dict:
    connectors = dmm.find_instances(CONNECTOR_PATH)
    if len(connectors) != 1:
        sys.exit(f"{dmm.path}: expected exactly 1 {CONNECTOR_PATH}, found {len(connectors)}")
    cx, cy, _ = connectors[0]
    return {"width": dmm.width, "height": dmm.height, "connector": [cx, cy]}


def main() -> None:
    dmm_tools = find_dmm_tools()
    tmp_dir = Path(tempfile.mkdtemp(prefix="ship_previews_"))
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    manifest: dict = {"tile_px": TILE_PX, "hulls": {}, "modules": {}}

    # --- Hulls: any ship dmm containing upgrade slot markers, plus EXTRA_HULLS ---
    for ship_dmm in sorted(SHIPS_DIR.glob("ship_*.dmm")):
        is_extra = ship_dmm.name in EXTRA_HULLS
        if not is_extra and MARKER_PATH not in ship_dmm.read_text(encoding="utf-8"):
            continue
        dmm = Dmm(ship_dmm)
        slots: dict[str, list[int]] = {}
        for x, y, props in dmm.find_instances(MARKER_PATH):
            key_match = re.search(r'key = "([^"]+)"', props)
            if not key_match:
                print(f"WARN: {ship_dmm.name}: slot marker at ({x},{y}) has no key, skipped")
                continue
            slots[key_match.group(1)] = [x, y]
        if not slots and not is_extra:
            continue
        hull_key = ship_dmm.stem.removeprefix("ship_")
        png_name = f"{ship_dmm.stem}.png"
        render(dmm_tools, ship_dmm, OUTPUT_DIR / png_name, tmp_dir, dmm)
        manifest["hulls"][hull_key] = {
            "png": png_name,
            "width": dmm.width,
            "height": dmm.height,
            "slots": slots,
            "src_md5": source_md5(ship_dmm),
        }
        print(f"hull {hull_key}: {dmm.width}x{dmm.height}, slots {list(slots)}")

    # --- Modules: base files from the DM datums, plus themed variants on disk ---
    base_files = collect_base_module_files()
    base_stems = {Path(f).stem for f in base_files}
    for rel_file in base_files:
        base_path = MODULES_DIR / rel_file
        png_name = rel_file.replace("/", "_").removesuffix(".dmm") + ".png"
        stem = base_path.stem

        entry: dict | None = None
        if base_path.is_file():
            base_dmm = Dmm(base_path)
            entry = module_geometry(base_dmm)
            entry["png"] = png_name
            entry["src_md5"] = source_md5(base_path)
            render(dmm_tools, base_path, OUTPUT_DIR / png_name, tmp_dir, base_dmm)

        # themed variants: <base>_<theme>.dmm beside the base file.
        # Some modules (e.g. Scarab's) are for_theme-only in DM and have no
        # unthemed map_file on disk at all - only these variants exist.
        themes: dict[str, dict] = {}
        for variant in sorted(base_path.parent.glob(f"{stem}_*.dmm")):
            if variant.stem in base_stems:
                continue  # another registered module, not a reskin of this one
            theme_id = variant.stem.removeprefix(f"{stem}_")
            variant_png = png_name.removesuffix(".png") + f"_{theme_id}.png"
            variant_dmm = Dmm(variant)
            variant_entry = module_geometry(variant_dmm)
            variant_entry["png"] = variant_png
            variant_entry["src_md5"] = source_md5(variant)
            render(dmm_tools, variant, OUTPUT_DIR / variant_png, tmp_dir, variant_dmm)
            themes[theme_id] = variant_entry

        if not entry:
            if not themes:
                print(f"WARN: registered module map missing on disk, skipped: {rel_file}")
                continue
            # No unthemed render exists; borrow geometry from a variant so the
            # manifest entry is non-null. The UI always resolves art through
            # entry["themes"] when a theme is active, so no "png" is set here.
            first = next(iter(themes.values()))
            entry = {k: first[k] for k in ("width", "height", "connector")}
        if themes:
            entry["themes"] = themes
        manifest["modules"][rel_file] = entry
        print(f"module {rel_file}: {entry['width']}x{entry['height']}"
              + (f", themed: {list(themes)}" if themes else ""))

    manifest_path = OUTPUT_DIR / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=1) + "\n", encoding="utf-8")
    shutil.rmtree(tmp_dir, ignore_errors=True)
    print(f"\nwrote {manifest_path.relative_to(REPO_ROOT)} "
          f"({len(manifest['hulls'])} hulls, {len(manifest['modules'])} modules)")


if __name__ == "__main__":
    main()
