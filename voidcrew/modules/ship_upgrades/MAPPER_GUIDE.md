# Ship Modular Upgrades - Mapper Guide

This guide explains how to create ships with modular upgrade slots and theme variants.

## Overview

The ship customization system has three layers:

1. **Ship Template** - The base ship definition (e.g., "Scarab-class Frigate")
2. **Themes** - Configuration variants with different crews, costs, and base maps (e.g., "Hospital", "Security")
3. **Modules** - Swappable sections that load into upgrade slots (e.g., "Surgical Suite", "TEG Engineering")

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Ship Template** | Base definition for a ship class. One entry in the catalog. |
| **Theme** | A variant of a ship with unique job slots, unlock cost, and base DMM. |
| **Upgrade Slot** | A location on a ship where modules can load (e.g., "scarab_med") |
| **Module** | A DMM file that loads into a slot, with its own unlock cost |
| **`for_theme`** | Specifies which theme(s) a module is available for |

---

## Quick Start: Adding a New Ship

### 1. Create the Ship Template

In `voidcrew/mapping/shuttles/your_ship.dm`:

```dm
/datum/map_template/shuttle/voidcrew/your_ship
    name = "Your Ship Name"
    short_name = "Your-class"
    suffix = "your_ship_default"  // Base DMM suffix
    has_upgrade_slots = TRUE
    upgrade_slot_ids = list(
        "your_ship_cargo",
        "your_ship_engineering",
    )
    available_themes = list("civilian", "military")  // Theme IDs

// Docking ports (one per variant letter)
/obj/docking_port/mobile/voidcrew/your_ship
    area_type = /area/shuttle/voidcrew/your_ship

/obj/docking_port/mobile/voidcrew/your_ship/a
    name = "Your Ship A"

// Areas
/area/shuttle/voidcrew/your_ship
    name = "Your Ship"
    icon_state = "shuttle"

/area/shuttle/voidcrew/your_ship/bridge
    name = "Bridge"

// ... more areas as needed
```

### 2. Define Themes

In `voidcrew/modules/ship_upgrades/ships/your_ship.dm`:

```dm
// Base theme type - sets which ship these themes belong to
/datum/ship_theme/your_ship
    for_ship = /datum/map_template/shuttle/voidcrew/your_ship

// Civilian theme (default - free)
/datum/ship_theme/your_ship/civilian
    id = "civilian"
    name = "Civilian Variant"
    desc = "Standard civilian configuration for cargo transport."
    is_default = TRUE
    template_suffix = "your_ship_a"  // Loads ship_your_ship_a.dmm
    upgrade_slot_ids = list(
        "your_ship_cargo",
        "your_ship_engineering",
    )
    job_slots = list(
        list(
            name = "Captain",
            officer = TRUE,
            outfit = /datum/outfit/job/captain,
            category = JOB_CAT_COMMAND,
            slots = 1,
        ),
        list(
            name = "Ship Engineer",
            outfit = /datum/outfit/job/engineer,
            category = JOB_CAT_ENGINEERING,
            slots = 2,
        ),
        list(
            name = "Deckhand",
            outfit = /datum/outfit/job/assistant,
            category = JOB_CAT_ASSISTANT,
            slots = 3,
        ),
    )

// Military theme (costs parts to unlock)
/datum/ship_theme/your_ship/military
    id = "military"
    name = "Military Variant"
    desc = "Armed variant with security personnel."
    part_cost = list(PART_CLASS_COMBAT = 2)
    template_suffix = "your_ship_b"  // Loads ship_your_ship_b.dmm
    upgrade_slot_ids = list(
        "your_ship_cargo",
        "your_ship_engineering",
        "your_ship_armory",  // Extra slot for military theme
    )
    job_slots = list(
        list(
            name = "Captain",
            officer = TRUE,
            outfit = /datum/outfit/job/captain,
            category = JOB_CAT_COMMAND,
            slots = 1,
        ),
        list(
            name = "Security Officer",
            outfit = /datum/outfit/job/security,
            category = JOB_CAT_SECURITY,
            slots = 2,
        ),
        list(
            name = "Ship Engineer",
            outfit = /datum/outfit/job/engineer,
            category = JOB_CAT_ENGINEERING,
            slots = 1,
        ),
    )
```

### 3. Define Modules

In the same file (`voidcrew/modules/ship_upgrades/ships/your_ship.dm`):

```dm
// Base module type - sets which ship and themes these modules belong to
/datum/ship_upgrade_module/your_ship
    for_ship = /datum/map_template/shuttle/voidcrew/your_ship
    // Shared across all themes by default
    for_theme = list("civilian", "military")

// Cargo modules
/datum/ship_upgrade_module/your_ship/cargo_basic
    id = "your_ship_cargo_basic"
    name = "Basic Cargo Bay"
    desc = "A simple cargo hold with storage crates."
    slot = "your_ship_cargo"
    map_file = "your_ship/cargo_basic.dmm"
    is_default = TRUE

/datum/ship_upgrade_module/your_ship/cargo_expanded
    id = "your_ship_cargo_expanded"
    name = "Expanded Cargo Bay"
    desc = "A larger cargo area with conveyor belts."
    slot = "your_ship_cargo"
    map_file = "your_ship/cargo_expanded.dmm"
    part_cost = list(PART_CLASS_TRADE = 1)

// Military-only module
/datum/ship_upgrade_module/your_ship/armory
    id = "your_ship_armory_basic"
    name = "Ship Armory"
    desc = "Weapons storage for security personnel."
    slot = "your_ship_armory"
    map_file = "your_ship/armory_basic.dmm"
    is_default = TRUE
    for_theme = "military"  // Only available for military theme
```

### 4. Create Ship DMMs

Create your ship DMMs in `_maps/voidcrew/ships/`:

- `ship_your_ship_a.dmm` - Civilian variant
- `ship_your_ship_b.dmm` - Military variant

Place upgrade slot markers where modules should load:

```dm
"uC" = (
/obj/modular_map_root/ship_upgrade{
    key = "your_ship_cargo"
},
/turf/open/floor/iron,
/area/shuttle/voidcrew/your_ship/cargo)
```

### 5. Create Module DMMs

Create module DMMs in `_maps/voidcrew/ship_modules/your_ship/`:

Each module MUST have:
1. A `/obj/modular_map_connector` marker at the connection point
2. Use `/area/template_noop` for the area

Example (`cargo_basic.dmm`):
```dm
"a" = (
/turf/open/floor/iron,
/area/template_noop)

"b" = (
/obj/structure/closet/crate,
/turf/open/floor/iron,
/area/template_noop)

"c" = (
/obj/modular_map_connector,
/turf/open/floor/iron,
/area/template_noop)
```

### 5b. Layout and Content Rules (playtest-derived, 2026-08-11)

These came out of the Delta playtest; every one of them shipped as a live bug.
Review these rules on every hull and module you touch.

1. **Wallmounts need a full-tile wall face.** Diagonal-capable wall types
   (plain titanium, plastitanium, anything with `SMOOTH_DIAGONAL_CORNERS`)
   draw a 45-degree cut when they smooth into a corner, leaving any
   button/APC/air alarm/light on that face floating in space. Interior
   partitions use `/nodiagonal` variants (or never-diagonal types like the
   cult ship walls); plain diagonal-capable walls belong only on exterior
   corners nothing mounts on. Themes repainting walls must preserve the
   smoothing class 1:1. Pixel-offset mounts (`/obj/machinery/button`) are
   invisible to the lint. Keep them on nodiagonal walls by construction.
2. **No visible pipes under walls.** Only `/hidden` pipe variants may pass
   under a closed turf. A visible pipe inside a wall renders as plumbing
   punching through plating, and a 1-tile wall tab that exists only to bury
   a pipe usually deserves to be deleted instead.
3. **Dense storage goes side-by-side along a wall, never stacked N/S.** The
   3/4 perspective draws the rear closet/crate half-hidden behind the front
   one; a vertical pair reads as one confused pile. Loose item piles (ore
   stacks etc.) directly above storage read the same way.
4. **One cryopod per ship.** The hull's reserve pod is the spawn point; join
   code only needs `spawn_points` to be non-empty. Modules ship zero pods.
   A second pod is wasted floor.
5. **Starting armor tops out at the security closet's vest + helmet.** No
   `armory1/2/3` closets (riot kit, ablative, armory1 even carries the
   traitor steal-objective ablative hoodie) on any starting module. Fleet
   precedent: only the phalanx's FULL armory carries riot gear, and that
   hull costs six deltas.
6. **Keep documented keep-clear tiles clear.** Every slot header in the
   ship's module definition file (e.g. `ships/delta.dm`) lists entry lanes,
   vent/scrubber tiles and reserve-tile approaches. A rack on a lane tile
   ships as a live obstruction (the Delta clinic did exactly this).

### 6. Update TOML Config

In `voidcrew/modules/ship_upgrades/ship_upgrades.toml`, add the directory reference:

```toml
# The TOML just defines where module DMMs are located
directory = "_maps/voidcrew/ship_modules/"
```

### 7. Add to DME

Add your new DM files to `tgstation.dme`:
- Ship template file
- Module/theme definitions file

---

## Detailed Reference

### Ship Template (`/datum/map_template/shuttle/voidcrew`)

| Variable | Type | Description |
|----------|------|-------------|
| `name` | string | Full display name |
| `short_name` | string | Short name for UI |
| `suffix` | string | DMM filename suffix (loads `ship_{suffix}.dmm`) |
| `has_upgrade_slots` | bool | Set `TRUE` to enable upgrade system |
| `upgrade_slot_ids` | list | Default slot keys (can be overridden by theme) |
| `available_themes` | list | List of theme IDs available for this ship |

### Theme (`/datum/ship_theme`)

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | string | Yes | Unique identifier (e.g., "medical", "military") |
| `name` | string | Yes | Display name shown in UI |
| `desc` | string | No | Description shown in UI |
| `for_ship` | path | Yes | Ship template type this theme belongs to |
| `template_suffix` | string | Yes | Which DMM to load (e.g., "scarab_a") |
| `is_default` | bool | No | If `TRUE`, this theme is free and pre-selected |
| `part_cost` | list | No | Cost to unlock: `list(PART_CLASS_COMBAT = 1)` |
| `upgrade_slot_ids` | list | No | Theme-specific slots (overrides ship default) |
| `job_slots` | list | Yes | Crew configuration for this theme |

**Job Slot Format:**
```dm
list(
    name = "Job Title",
    officer = TRUE,              // Optional: marks as command role
    outfit = /datum/outfit/job/X,
    category = JOB_CAT_COMMAND,  // JOB_CAT_COMMAND, JOB_CAT_ENGINEERING, etc.
    slots = 2,                   // Number of positions
)
```

### Module (`/datum/ship_upgrade_module`)

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | string | Yes | Unique identifier within ship |
| `name` | string | Yes | Display name shown in UI |
| `desc` | string | No | Description shown in UI |
| `slot` | string | Yes | Which slot this fits (must match `key` in DMM) |
| `map_file` | string | Yes | Path relative to `ship_modules/` |
| `for_ship` | path | Yes | Ship template type this belongs to |
| `for_theme` | string/list | Yes* | Which theme(s) this module appears for |
| `part_cost` | list | No | Cost to unlock: `list(PART_CLASS_TRADE = 1)` |
| `is_default` | bool | No | If `TRUE`, loads when no upgrade selected |

**\*`for_theme` is REQUIRED for ships with themes.** Modules without `for_theme` won't appear in the upgrade selector.

**`for_theme` Examples:**
```dm
for_theme = "medical"                           // Single theme
for_theme = list("medical", "syndicate")        // Multiple themes
for_theme = list("civilian", "military", "pirate")  // All themes (explicit)
```

**Part Classes:**
- `PART_CLASS_COMBAT` - Combat parts
- `PART_CLASS_SCIENCE` - Science parts
- `PART_CLASS_TRADE` - Trade parts
- `PART_CLASS_MISC` - Miscellaneous parts

---

## Pricing New Content

Parts are the fleet's long-term currency. An engaged player banks roughly
**1.5 parts per round** (see the faucet breakdown below), so a hull priced at 20
is about a month of play. Price new content against that, not against vibes.

**Faucet, for reference.** Sources, in rough order of how much they contribute:

| Source | Parts | Notes |
|--------|-------|-------|
| Zone loot caches | 1 | ~25% of yellow caches, ~33% of red; class matches the theme |
| Round-end participation | 1 | Random class, everyone who played a character |
| Contested cache | 5 | 1-2 a round, to one crew |
| Colosseum spoils | 2-7 | Split between winners |
| Prospect Stake | 5 | On 35% of hard stakes |
| Pirate bounty | 1 light / 3 heavy | Repeatable |
| Map spawners | 1 | Only 7 across the whole ruin pool |

Everything except the participation grant is a **physical item** that has to ride
home in an extraction case, and a player can bank at most 5 that way per round -
one case, 5 slots, one case per player. The participation part is a direct
account grant and skips the case, so the real ceiling is 6 a round.

That works out to **~3.5 parts a round for an engaged player and ~1.5 for a
casual one**. Price against those.

Two rules the tables follow, worth keeping if you add more:

- **Green tables never pay parts.** The zone tiering exists so reward tracks
  risk; progression currency dropping in the safe ring defeats it.
- **Rare tables never pay parts.** Those are the curated one-of-a-kind channel,
  and a generic commodity dilutes the no-replacement roll that keeps their
  uniques unique per cache.

### Hull cost

Cost scales superlinearly with interior size, so a battlecruiser is a season-long
goal and a shuttle is a month's:

```
total = round(6 * (interior_tiles / 200) ** 1.6)
```

Split that total across part classes by the hull's identity, and **always use at
least two classes** - a single-class hull is farmable from one activity, which
collapses the grind. Combat parts are the most over-supplied class (bounties,
cache and Colosseum all lean combat), so a combat hull priced purely in combat
parts is the *cheapest* thing on the shelf, not the dearest.

| Hull | Tiles | Total | Split |
|------|-------|-------|-------|
| Goon | 209 | 10 | trade 5, misc 3, science 2 (owner-priced above the formula's 6) |
| Kilo | 312 | 12 | trade 6, misc 4, science 2 |
| Delta | 476 | 22 | combat 8, misc 8, trade 6 |
| Scarab | 660 | 36 | science 14, misc 10, trade 8, combat 4 |
| Phalanx | 1680 | 60 | combat 24, science 12, trade 12, misc 12 (hand-set, far below the formula's ~181) |

No modular hull is free (owner call, 2026-07-30): new players crew the roundstart
ships rather than founding their own, and the only free hulls on the shelf are the
pill gag ships.

**The curve is calibrated for hulls up to ~700 tiles.** Goon, Kilo, Delta and
Scarab all land within ~10% of it, but the 1.6 exponent runs away at the top end -
the Phalanx's 1680 tiles come out at ~181, which is a year of play for a casual
crew. It is hand-set to 60 (owner call, 2026-07-30) so the capstone stays
reachable. Price anything bigger than the Scarab by hand against this table, not
by plugging tiles into the formula:

| Hull | Cost | Engaged (~3.5/round) | Casual (~1.5/round) |
|------|------|----------------------|---------------------|
| Goon | 10 | ~3 rounds | ~7 rounds |
| Kilo | 12 | ~4 rounds | ~8 rounds |
| Delta | 22 | ~6 rounds | ~15 rounds |
| Scarab | 36 | ~10 rounds | ~24 rounds |
| Phalanx | 60 | ~17 rounds | ~40 rounds |

Those are floors - a hull's cost is spread across classes, so the real wait is
somewhat longer than cost divided by income. At roughly 13 rounds a month, the
ladder is about one hull a month for an engaged player and one every two to three
for a casual one, with modules and themes soaking up the surplus in between.

### Size multiplier

Themes and modules are priced off the hull they sit on - the same greenhouse is
worth more bolted to a battlecruiser than to a shuttle:

| Hull | Pill | Goon | Kilo | Delta | Scarab | Phalanx |
|------|------|------|------|-------|--------|---------|
| Multiplier | 1.0 | 1.0 | 1.25 | 1.5 | 2.0 | 2.0 |

The Pill sits at 1.0 rather than below it because there is no room under the T1
base of 2 to put anything - its single bay is the only fitout the hull has, so
each of its three modules is a T2 capability add at 4 parts. The hull itself is
free, which is where the joke is paid for.

The Phalanx shares the Scarab's multiplier despite being 2.5x its size. That is
deliberate (owner call, 2026-07-30): its hull was hand-cut to 60, and leaving the
fitout on a size-derived 3.0 would have made kitting the ship cost three times
buying it. **Sanity-check any new hull's multiplier against the content-to-hull
ratio, not just its tile count** - every hull in the fleet lands between 2.0x and
4.5x, and that band is the real constraint.

### Theme cost

```
theme = 6 * multiplier
```

Goon 6, Kilo 8, Delta 9, Scarab 12, Phalanx 12. The default theme is always free.

### Module cost

```
module = tier_base * multiplier
```

| Tier | Base | What it means |
|------|------|---------------|
| Default | 0 | The slot's baseline fitout. Always free. |
| T1 - sidegrade | 2 | Different flavour, same capability. Mess hall, den, gym, vault. |
| T2 - capability | 4 | Adds a real department or machine, usually a job slot. Chem lab, surgery, brig, greenhouse. |
| T3 - power spike | 7 | Raises the ship's ceiling outright. TEG, mech garage, xenobiology, full armory. |

Tier by what the module *does*, not by how much map it fills. The Goon's TEG
ships unplumbed and is a project rather than a working plant, so it is T2 while
the Scarab's working TEG is T3.

Ore redemption is tiered by what the hull already has, not by the machine. On the
Goon and the Phalanx the ORM sits in the slot's free default, because both hulls
are expected to mine and the slot's other options trade that away. The Delta's
Mining Bay adds redemption to a hull that had none, so it is T2 at trade 6; the
Kilo's Ore Refinery adds it on top of a hull already built around mining, so it
is T3 at trade 9.

### Upgrade Slot Marker

**Type:** `/obj/modular_map_root/ship_upgrade`

Place in ship DMM where modules should load:
```dm
/obj/modular_map_root/ship_upgrade{
    key = "your_ship_cargo"
}
```

The `key` must match the `slot` variable in module definitions.

### Module Connector

**Type:** `/obj/modular_map_connector`

Place in module DMM at the anchor point. This aligns with the `modular_map_root/ship_upgrade` marker when loading.

---

## Theme System

### How It Works

1. **One ship template** appears in the catalog (e.g., "Scarab-class Frigate")
2. When selected, player sees **theme options** (e.g., "Hospital", "Reinforced", "Security")
3. Each theme has:
   - Its own **job slots** (crew composition)
   - Its own **base DMM** (different starting layout)
   - Its own **unlock cost** (default theme is free)
   - Optionally different **upgrade slots**
4. **Modules specify which themes they work with** via `for_theme`

### Theme Selection Flow

```
Ship Catalog              Upgrade Selector
┌─────────────────┐      ┌──────────────────────────────┐
│ Scarab-class    │      │ THEME TAB:                   │
│ Frigate         │ ───► │ [Hospital] (Default)         │
│                 │      │ [Reinforced] 1 Science Part  │
│ [SELECT]        │      │ [Security] 1 Combat Part     │
└─────────────────┘      │                              │
                         │ UPGRADES TAB:                │
                         │ Medical: [Surgery ▼]         │
                         │ Engineering: [TEG ▼]         │
                         │                              │
                         │ [LAUNCH SHIP]                │
                         └──────────────────────────────┘
```

### Shared vs Theme-Specific Modules

**Shared across all themes:**
```dm
/datum/ship_upgrade_module/scarab
    for_ship = /datum/map_template/shuttle/voidcrew/scarab
    for_theme = list("medical", "syndicate", "mining")  // All themes
```

**Specific to one theme:**
```dm
/datum/ship_upgrade_module/scarab/security_armory
    id = "scarab_armory"
    slot = "scarab_armory"
    for_theme = "mining"  // Only Security variant has this slot
```

**Shared between some themes:**
```dm
/datum/ship_upgrade_module/scarab/chemistry_lab
    id = "scarab_chem"
    slot = "scarab_med"
    for_theme = list("medical", "syndicate")  // Not available for Security
```

---

## File Structure

```
_maps/voidcrew/
├── ships/
│   ├── ship_scarab_a.dmm       # Hospital variant
│   ├── ship_scarab_b.dmm       # Reinforced variant
│   └── ship_scarab_c.dmm       # Security variant
└── ship_modules/
    └── scarab/                 # Scarab's modules
        ├── scarab_med_basic.dmm
        ├── scarab_med_surgery.dmm
        ├── scarab_engineering_basic.dmm
        └── scarab_engineering_teg.dmm

voidcrew/
├── mapping/shuttles/
│   └── scarab.dm               # Ship template, docking ports, areas
└── modules/ship_upgrades/
    ├── _ship_upgrades.dm       # Core system (don't edit)
    ├── modular_map_root_ship.dm # Module loader (don't edit)
    ├── ship_upgrades.toml      # Directory config
    └── ships/
        └── scarab.dm           # Themes + modules for Scarab
```

---

## Complete Example: Scarab-class Frigate

### Ship Template (`voidcrew/mapping/shuttles/scarab.dm`)

```dm
/datum/map_template/shuttle/voidcrew/scarab
    name = "Scarab-class Frigate"
    short_name = "Scarab-class"
    suffix = "scarab_a"  // Default, overridden by theme
    has_upgrade_slots = TRUE
    upgrade_slot_ids = list(
        "scarab_med",
        "scarab_engineering",
        "scarab_common",
        "scarab_cargo",
    )
    available_themes = list("medical", "syndicate", "mining")

/obj/docking_port/mobile/voidcrew/scarab
    area_type = /area/shuttle/voidcrew/scarab

/obj/docking_port/mobile/voidcrew/scarab/a
    name = "Scarab-class Frigate A"

/obj/docking_port/mobile/voidcrew/scarab/b
    name = "Scarab-class Frigate B"

/obj/docking_port/mobile/voidcrew/scarab/c
    name = "Scarab-class Frigate C"

/area/shuttle/voidcrew/scarab/bridge
    name = "Bridge"
    icon_state = "bridge"

// ... more areas
```

### Themes & Modules (`voidcrew/modules/ship_upgrades/ships/scarab.dm`)

```dm
// ========== MODULES ==========

/datum/ship_upgrade_module/scarab
    for_ship = /datum/map_template/shuttle/voidcrew/scarab
    for_theme = list("medical", "syndicate", "mining")  // All themes

/datum/ship_upgrade_module/scarab/med_basic
    id = "scarab_med_basic"
    name = "Medical Storage"
    desc = "Basic medical supplies and equipment."
    slot = "scarab_med"
    map_file = "scarab/scarab_med_basic.dmm"
    is_default = TRUE

/datum/ship_upgrade_module/scarab/med_surgery
    id = "scarab_med_surgery"
    name = "Surgical Suite"
    desc = "Full surgical facilities."
    slot = "scarab_med"
    map_file = "scarab/scarab_med_surgery.dmm"
    part_cost = list(PART_CLASS_MISC = 1)

// ========== THEMES ==========

/datum/ship_theme/scarab
    for_ship = /datum/map_template/shuttle/voidcrew/scarab

/datum/ship_theme/scarab/medical
    id = "medical"
    name = "Hospital Variant"
    desc = "Medical-focused with CMO and doctors."
    is_default = TRUE
    template_suffix = "scarab_a"
    upgrade_slot_ids = list("scarab_med", "scarab_engineering", "scarab_common", "scarab_cargo")
    job_slots = list(
        list(name = "Chief Medical Officer", officer = TRUE, outfit = /datum/outfit/job/cmo, category = JOB_CAT_COMMAND, slots = 1),
        list(name = "Medical Doctor", outfit = /datum/outfit/job/doctor, category = JOB_CAT_MEDICAL, slots = 2),
        list(name = "Ship Engineer", outfit = /datum/outfit/job/engineer, category = JOB_CAT_ENGINEERING, slots = 1),
        list(name = "Resident", outfit = /datum/outfit/job/assistant, category = JOB_CAT_ASSISTANT, slots = 2),
    )

/datum/ship_theme/scarab/syndicate
    id = "syndicate"
    name = "Reinforced Variant"
    desc = "Chemistry-focused with reinforced hull."
    part_cost = list(PART_CLASS_SCIENCE = 1)
    template_suffix = "scarab_b"
    upgrade_slot_ids = list("scarab_med", "scarab_engineering", "scarab_common", "scarab_cargo")
    job_slots = list(
        list(name = "Chief Pharmacist", officer = TRUE, outfit = /datum/outfit/job/cmo, category = JOB_CAT_COMMAND, slots = 1),
        list(name = "Pharmacist", outfit = /datum/outfit/job/chemist, category = JOB_CAT_MEDICAL, slots = 1),
        list(name = "Ship Engineer", outfit = /datum/outfit/job/engineer, category = JOB_CAT_ENGINEERING, slots = 1),
        list(name = "Resident", outfit = /datum/outfit/job/assistant, category = JOB_CAT_ASSISTANT, slots = 2),
    )

/datum/ship_theme/scarab/mining
    id = "mining"
    name = "Security Variant"
    desc = "Patrol-focused with security crew."
    part_cost = list(PART_CLASS_COMBAT = 1)
    template_suffix = "scarab_c"
    upgrade_slot_ids = list("scarab_med", "scarab_engineering", "scarab_common", "scarab_cargo")
    job_slots = list(
        list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/captain, category = JOB_CAT_COMMAND, slots = 1),
        list(name = "Security Officer", outfit = /datum/outfit/job/security, category = JOB_CAT_SECURITY, slots = 2),
        list(name = "Ship Engineer", outfit = /datum/outfit/job/engineer, category = JOB_CAT_ENGINEERING, slots = 1),
        list(name = "Assistant", outfit = /datum/outfit/job/assistant, category = JOB_CAT_ASSISTANT, slots = 2),
    )
```

---

## Ship Previews (map viewer in the selector UI)

The ship customization UI shows a live top-down preview of the composited ship:
the hull PNG with the selected module's PNG overlaid on each slot, exactly where
the loader will place it. The images and geometry are **generated offline** and
committed:

```
python tools/ship_previews/generate_ship_previews.py
```

This scans every `_maps/voidcrew/ships/ship_*.dmm` containing
`/obj/modular_map_root/ship_upgrade` markers, every module DMM registered via
`map_file` in `voidcrew/modules/ship_upgrades/ships/*.dm` (plus any themed
`<base>_<theme>.dmm` reskins found beside them), renders them with dmm-tools,
and writes PNGs + `manifest.json` to `voidcrew/modules/ship_upgrades/previews/`.

**Re-run the script and commit the output whenever you:**
- Edit a modular hull DMM (slot markers moved, hull redecorated)
- Add or edit a module DMM (including themed reskins)
- Add a new modular ship or theme

Requires `dmm-tools.exe` (set `$DMM_TOOLS` or place at
`~/code/tg-tools/bin/dmm-tools.exe`). If the manifest or a PNG is missing, the
UI silently hides the preview: nothing breaks, players just don't see the map.

---

## Checklists

### New Ship with Themes

- [ ] Ship template in `voidcrew/mapping/shuttles/{ship}.dm`
  - [ ] Set `has_upgrade_slots = TRUE`
  - [ ] Set `upgrade_slot_ids` list
  - [ ] Set `available_themes` list
- [ ] Docking port subtypes (one per letter: `/a`, `/b`, `/c`)
- [ ] Area definitions for ship sections
- [ ] Theme definitions in `voidcrew/modules/ship_upgrades/ships/{ship}.dm`
  - [ ] Base theme type with `for_ship`
  - [ ] One theme with `is_default = TRUE`
  - [ ] Each theme has `template_suffix`, `job_slots`
- [ ] Module definitions in same file
  - [ ] Base module type with `for_ship` and `for_theme`
  - [ ] One module per slot with `is_default = TRUE`
- [ ] Ship DMMs in `_maps/voidcrew/ships/`
  - [ ] One DMM per theme (matching `template_suffix`)
  - [ ] Upgrade slot markers with correct `key`
- [ ] Module DMMs in `_maps/voidcrew/ship_modules/{ship}/`
  - [ ] Each module has `/obj/modular_map_connector`
  - [ ] Uses `/area/template_noop`
- [ ] Add DM files to `tgstation.dme`
- [ ] Regenerate previews: `python tools/ship_previews/generate_ship_previews.py`

### New Theme for Existing Ship

- [ ] Theme definition with unique `id`
- [ ] Set `template_suffix` to new DMM
- [ ] Define `job_slots` for crew composition
- [ ] Set `part_cost` if not free (or `is_default = TRUE` if free)
- [ ] Create ship DMM for this theme
- [ ] Add theme ID to relevant modules' `for_theme`
- [ ] Add theme ID to ship's `available_themes` list

### New Module for Existing Ship

- [ ] Module definition inheriting from ship's base type
- [ ] Set `for_theme` to specify which themes can use it
- [ ] Set `is_default = TRUE` if it's the default for a slot
- [ ] Create module DMM with connector marker
- [ ] Add to ship's modules directory
- [ ] Regenerate previews: `python tools/ship_previews/generate_ship_previews.py`

---

## Troubleshooting

### Module doesn't appear in selector
- Check `for_theme` matches the selected theme's `id`
- Verify `slot` matches one of the theme's `upgrade_slot_ids`
- Ensure `for_ship` points to correct ship template

### Module loads in wrong position
- Check `/obj/modular_map_connector` placement in module DMM
- Verify `/obj/modular_map_root/ship_upgrade` placement in ship DMM

### Theme not appearing
- Verify theme `id` is in ship's `available_themes` list
- Ensure `for_ship` points to correct ship template
- Check theme has required `template_suffix` and `job_slots`

### Ship not appearing in catalog
- Check ship template has `job_slots` (via default theme) or define them directly
- Verify ship template type is included in DME
- Check for compile errors in ship/theme definitions

---

## Testing

1. Compile the code
2. Start server as admin
3. Use **Overmap.Spawn → Spawn Specific Ship**
4. Select your ship
5. Verify themes appear and can be selected
6. Verify modules appear for selected theme
7. Launch ship and verify correct DMM loaded
8. Verify crew spawns with correct jobs
