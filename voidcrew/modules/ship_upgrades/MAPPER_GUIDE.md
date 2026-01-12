# Ship Modular Upgrades - Mapper Guide

This guide explains how to add modular upgrade slots to ships and create upgrade modules.

## Overview

The modular upgrade system allows ships to have customizable sections that players can choose when spawning. Each ship can have multiple **upgrade slots** (like "cargobay", "medbay", "engineroom"), and each slot can have multiple **module options** to choose from.

### Key Concepts

- **Ship Template** - The base ship definition (e.g., "Delta-class Frigate")
- **Theme** - An aesthetic variant of a ship (e.g., "Pirate", "Science")
- **Upgrade Slot** - A location on a ship where modules can load (e.g., "cargobay")
- **Module** - A DMM file that loads into a slot (e.g., "cargo_expanded.dmm")
- **Themed Module** - A theme-specific variant that auto-loads (e.g., "cargo_expanded_pirate.dmm")

## Quick Start

### 1. Adding Upgrade Slots to a Ship

In your ship's DMM file, place `modular_map_root/ship_upgrade` markers where you want upgradeable sections:

```dm
/obj/modular_map_root/ship_upgrade{
    key = "cargobay"
}
```

The `key` identifies which slot this is. Use consistent key names across ships (e.g., always use "cargobay" for cargo areas).

### 2. Update the Ship Template

In the ship's `.dm` template file, add:

```dm
/datum/map_template/shuttle/voidcrew/your_ship
    name = "Your Ship Name"
    // ... other vars ...

    has_upgrade_slots = TRUE
    upgrade_slot_ids = list("cargobay", "engineroom")  // List all slot keys used in DMM
```

### 3. Create Module DMMs

Create module DMM files in `_maps/voidcrew/ship_modules/your_ship/`. Each module MUST have:

1. A `/obj/modular_map_connector` marker at the connection point
2. Use `/area/template_noop` for the area (inherits from base map)

Example module (`cargo_expanded.dmm`):
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

(1,1,1) = {"
b
c
b
"}
```

### 4. Register the Module

Create a new file for your ship's modules (e.g., `voidcrew/modules/ship_upgrades/ships/your_ship.dm`), or add to an existing ship's module file:

```dm
/// Base type for all your_ship modules - sets the ship they belong to
/datum/ship_upgrade_module/your_ship
    for_ship = /datum/map_template/shuttle/voidcrew/your_ship

/// Expanded cargo bay module
/datum/ship_upgrade_module/your_ship/cargo_expanded
    id = "cargo_expanded"
    name = "Expanded Cargo Bay"
    desc = "A larger cargo area with more storage."
    slot = "cargobay"                        // Must match the key in the DMM
    map_file = "your_ship/cargo_expanded.dmm" // Path relative to ship_modules/
    part_cost = list(PART_CLASS_TRADE = 1)   // Optional cost
    is_default = FALSE                       // Set TRUE for the default option
```

**Important:** Modules are organized by ship class. Each ship has its own set of modules, allowing multiple ships to have modules with the same display name (e.g., "Basic Cargo Bay") without conflicts.

### 5. Add to TOML Config

In `voidcrew/modules/ship_upgrades/ship_upgrades.toml`, add your ship's modules:

```toml
# Your ship's modules
[rooms.your_ship.cargobay]
modules = ["your_ship/cargo_basic.dmm", "your_ship/cargo_expanded.dmm"]

[rooms.your_ship.engineroom]
modules = ["your_ship/engine_basic.dmm"]
```

---

## Detailed Reference

### Upgrade Slot Marker

**Type:** `/obj/modular_map_root/ship_upgrade`

**Variables:**
- `key` (required) - String identifying this slot (e.g., "cargobay", "medbay")

**Placement:** Place at the anchor point where modules will load. The module's connector will align to this position.

### Module Connector

**Type:** `/obj/modular_map_connector`

**Purpose:** Marks the anchor point in a module DMM. When the module loads, this point aligns with the `modular_map_root/ship_upgrade` marker in the base ship.

**Placement:** Usually placed at the "entrance" or connection point of the module.

### Module Definition

**Type:** `/datum/ship_upgrade_module`

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | string | Yes | Unique identifier within this ship (e.g., "cargo_expanded") |
| `name` | string | Yes | Display name shown in UI |
| `desc` | string | No | Description shown in UI |
| `slot` | string | Yes | Which slot this fits (must match `key` in DMM) |
| `map_file` | string | Yes | Path relative to `ship_modules/` (e.g., `"your_ship/cargo.dmm"`) |
| `part_cost` | list | No | Cost to select: `list(PART_CLASS_TRADE = 1)` |
| `is_default` | bool | No | If TRUE, loads when no upgrade selected |
| `for_ship` | path | Yes | Ship template type this module belongs to |

**Best Practice:** Create a base subtype for each ship that sets `for_ship`, then inherit from it:

```dm
// Base type sets the ship - all subtypes inherit it
/datum/ship_upgrade_module/delta
    for_ship = /datum/map_template/shuttle/voidcrew/delta

// Modules inherit from base type
/datum/ship_upgrade_module/delta/cargo_basic
    id = "cargo_basic"
    // ... other vars
```

**Part Classes:**
- `PART_CLASS_COMBAT` - Combat parts
- `PART_CLASS_SCIENCE` - Science parts
- `PART_CLASS_TRADE` - Trade parts
- `PART_CLASS_MISC` - Miscellaneous parts

### Ship Template Variables

Add to `/datum/map_template/shuttle/voidcrew/your_ship`:

| Variable | Type | Description |
|----------|------|-------------|
| `has_upgrade_slots` | bool | Set to `TRUE` to enable upgrades |
| `upgrade_slot_ids` | list | List of slot keys used (e.g., `list("cargobay", "engineroom")`) |

---

## Standard Slot Names

Use these standard slot names for consistency across ships:

| Slot Key | Purpose |
|----------|---------|
| `cargobay` | Cargo storage area |
| `engineroom` | Engine/engineering section |
| `medbay` | Medical facilities |
| `bridge` | Command/bridge area |
| `armory` | Weapons storage |
| `kitchen` | Food preparation |
| `quarters` | Crew living quarters |
| `science` | Research/science lab |

You can create custom slot names, but standard names allow modules to be shared across ships.

---

## File Structure

```
_maps/voidcrew/
├── ships/
│   └── ship_your_ship.dmm      # Base ship with upgrade markers
└── ship_modules/
    ├── test_modular/           # Test Modular Ship modules
    │   ├── cargo_basic.dmm
    │   ├── cargo_expanded.dmm
    │   └── engine_basic.dmm
    ├── delta/                  # Delta-class modules
    │   ├── cargo_basic.dmm
    │   └── medbay_cloner.dmm
    └── your_ship/              # Your ship's modules
        └── your_module.dmm

voidcrew/modules/ship_upgrades/
├── _ship_upgrades.dm           # Core system (don't edit)
├── modular_map_root_ship.dm    # Loader (don't edit)
├── ship_upgrades.toml          # Module file registry
└── ships/                      # Per-ship module definitions
    ├── test_modular.dm         # Test Modular Ship modules
    ├── delta.dm                # Delta-class modules
    └── your_ship.dm            # Your ship's modules

voidcrew/mapping/shuttles/
└── your_ship.dm                # Ship template definition
```

**Note:** Module definitions are organized by ship. Each ship class gets its own file defining its available modules. This allows different ships to have modules with the same display name without conflicts.

---

## Step-by-Step Example: Adding a Medbay Slot

### Step 1: Create Module DMMs

Create a subdirectory for your ship if it doesn't exist: `_maps/voidcrew/ship_modules/your_ship/`

**`_maps/voidcrew/ship_modules/your_ship/medbay_basic.dmm`**
```dm
//MAP CONVERTED BY dmm2tgm.py THIS HEADER COMMENT PREVENTS RECONVERSION, DO NOT REMOVE
"a" = (
/turf/open/floor/iron/white,
/area/template_noop)
"b" = (
/obj/structure/bed,
/obj/item/bedsheet/medical,
/turf/open/floor/iron/white,
/area/template_noop)
"c" = (
/obj/modular_map_connector,
/turf/open/floor/iron/white,
/area/template_noop)
"d" = (
/obj/structure/closet/crate/medical,
/turf/open/floor/iron/white,
/area/template_noop)

(1,1,1) = {"
a
b
a
"}
(2,1,1) = {"
d
c
a
"}
(3,1,1) = {"
a
b
a
"}
```

**`_maps/voidcrew/ship_modules/your_ship/medbay_cloner.dmm`**
```dm
//MAP CONVERTED BY dmm2tgm.py THIS HEADER COMMENT PREVENTS RECONVERSION, DO NOT REMOVE
"a" = (
/turf/open/floor/iron/white,
/area/template_noop)
"b" = (
/obj/machinery/cloning/clonepod,
/turf/open/floor/iron/white,
/area/template_noop)
"c" = (
/obj/modular_map_connector,
/turf/open/floor/iron/white,
/area/template_noop)
"d" = (
/obj/machinery/computer/cloning,
/turf/open/floor/iron/white,
/area/template_noop)

(1,1,1) = {"
a
b
a
"}
(2,1,1) = {"
d
c
a
"}
(3,1,1) = {"
a
b
a
"}
```

### Step 2: Register Modules

Add to your ship's module file (e.g., `voidcrew/modules/ship_upgrades/ships/your_ship.dm`):

```dm
/// Base type for your ship's modules
/datum/ship_upgrade_module/your_ship
    for_ship = /datum/map_template/shuttle/voidcrew/your_ship

// ===== MEDBAY UPGRADES =====

/datum/ship_upgrade_module/your_ship/medbay_basic
    id = "medbay_basic"
    name = "Basic Medbay"
    desc = "A simple medical area with beds and supplies."
    slot = "medbay"
    map_file = "your_ship/medbay_basic.dmm"
    is_default = TRUE

/datum/ship_upgrade_module/your_ship/medbay_cloner
    id = "medbay_cloner"
    name = "Cloning Medbay"
    desc = "Advanced medical with cloning facilities."
    slot = "medbay"
    map_file = "your_ship/medbay_cloner.dmm"
    part_cost = list(PART_CLASS_SCIENCE = 2)
```

### Step 3: Add to TOML

In `voidcrew/modules/ship_upgrades/ship_upgrades.toml`:

```toml
[rooms.your_ship.medbay]
modules = ["your_ship/medbay_basic.dmm", "your_ship/medbay_cloner.dmm"]
```

### Step 4: Add Slot to Ship DMM

In your ship's DMM, place the marker:

```dm
"mB" = (
/obj/modular_map_root/ship_upgrade{
    key = "medbay"
},
/turf/open/floor/iron/white,
/area/shuttle/voidcrew/your_ship)
```

### Step 5: Update Ship Template

```dm
/datum/map_template/shuttle/voidcrew/your_ship
    has_upgrade_slots = TRUE
    upgrade_slot_ids = list("cargobay", "engineroom", "medbay")  // Add "medbay"
```

### Step 6: Add Include to DME

Add your new module definition file to `tgstation.dme` if you created a new file.

---

## Testing

1. Compile the code
2. Start server as admin
3. Use **Overmap.Spawn → Spawn Modular Ship (With Upgrades)**
4. Select your ship
5. Choose upgrades for each slot
6. Verify the correct modules loaded

---

## Troubleshooting

### Module doesn't load
- Verify `key` in DMM matches `slot` in module definition
- Verify module is registered in TOML
- Verify DMM file exists at correct path
- Check that module has `/obj/modular_map_connector` placed correctly

### Module loads in wrong position
- Check `/obj/modular_map_connector` placement in module DMM
- The connector aligns with the `modular_map_root/ship_upgrade` marker

### Area errors
- Use `/area/template_noop` in module DMMs
- This allows the module to inherit the ship's area

### Module not appearing in selection
- Verify `for_ship` points to the correct ship template type
- Verify `slot` matches `upgrade_slot_ids` in ship template
- Check module is registered (has both `id` and `for_ship` set)
- For themed ship variants, `for_ship` should point to the BASE ship type (not the themed subtype)

---

## Best Practices

1. **Keep modules small** - 3x3 to 5x5 tiles is ideal
2. **Use consistent connector placement** - Usually center or entrance
3. **Test alignment** - Spawn with different modules to verify positioning
4. **Document your modules** - Use clear names and descriptions
5. **Balance costs** - Better modules should cost more parts
6. **One default per slot** - Mark exactly one module as `is_default = TRUE`

---

## Theme System

Themes allow ships to have completely different aesthetics while sharing the same upgrade modules. The system uses **automatic file naming** to resolve themed variants.

### How Themes Work

1. **Base Ship** - `ship_delta.dmm` with `theme = null`
2. **Themed Ship** - `ship_delta_pirate.dmm` with `theme = "pirate"`
3. **When modules load**, the system automatically checks for themed variants:
   - Player selects "Expanded Cargo" upgrade
   - System looks for `cargo_expanded_pirate.dmm`
   - If found, loads themed version
   - If not found, falls back to `cargo_expanded.dmm`

### Creating a Themed Ship Variant

#### Step 1: Create the Themed Ship DMM

Create a new ship DMM with your theme's aesthetic (different walls, floors, etc.):

`_maps/voidcrew/ships/ship_delta_pirate.dmm`

**Important:** Keep the `modular_map_root/ship_upgrade` markers with the SAME keys as the base ship!

```dm
"e" = (
/obj/modular_map_root/ship_upgrade{
    key = "cargobay"           // Same key as base ship
},
/turf/open/floor/wood,         // Themed floor
/area/shuttle/voidcrew/delta/pirate)
```

#### Step 2: Create the Themed Ship Template

```dm
// Base ship (no theme)
/datum/map_template/shuttle/voidcrew/delta
    name = "Delta-class Frigate"
    suffix = "delta"
    has_upgrade_slots = TRUE
    upgrade_slot_ids = list("cargobay", "engineroom", "medbay")
    theme = null  // No theme (default)

// Pirate variant - inherits from base
/datum/map_template/shuttle/voidcrew/delta/pirate
    name = "Delta-class Frigate (Pirate)"
    suffix = "delta_pirate"  // Points to ship_delta_pirate.dmm
    short_name = "Delta-class (Pirate)"
    theme = "pirate"  // This triggers themed module lookup
    // Inherits: has_upgrade_slots, upgrade_slot_ids from parent

// Docking port for themed variant
/obj/docking_port/mobile/voidcrew/delta/pirate
    name = "Delta-class Frigate (Pirate)"
    area_type = /area/shuttle/voidcrew/delta/pirate

// Area for themed variant
/area/shuttle/voidcrew/delta/pirate
    name = "Pirate Delta Ship"
```

#### Step 3: Create Themed Module Variants (Optional)

For any module you want to theme, create a file with the theme suffix:

| Base Module | Pirate Variant | Science Variant |
|-------------|----------------|-----------------|
| `cargo_basic.dmm` | `cargo_basic_pirate.dmm` | `cargo_basic_science.dmm` |
| `cargo_expanded.dmm` | `cargo_expanded_pirate.dmm` | `cargo_expanded_science.dmm` |
| `medbay_cloner.dmm` | `medbay_cloner_pirate.dmm` | `medbay_cloner_science.dmm` |

**You don't need to create themed variants for every module!** The system falls back to the base module if no themed variant exists.

### Theme Naming Convention

```
{base_filename}_{theme}.dmm
```

Examples:
- Base: `cargo_expanded.dmm`
- Pirate: `cargo_expanded_pirate.dmm`
- Science: `cargo_expanded_science.dmm`
- Corporate: `cargo_expanded_corporate.dmm`

### Standard Theme Names

Use these standard theme identifiers:

| Theme ID | Description |
|----------|-------------|
| `pirate` | Pirate/rustic aesthetic (wood, gold) |
| `science` | Science/research aesthetic (white, glass) |
| `corporate` | Corporate/NT aesthetic (blue, clean) |
| `syndicate` | Syndicate aesthetic (red, dark) |
| `mining` | Mining/industrial aesthetic (orange, metal) |
| `medical` | Medical aesthetic (white, green) |

### Full Theme Example

Here's how to add a "Pirate" theme to the Delta-class:

**1. Ship Template** (`voidcrew/mapping/shuttles/delta.dm`):
```dm
/datum/map_template/shuttle/voidcrew/delta/pirate
    name = "Delta-class Frigate (Pirate)"
    suffix = "delta_pirate"
    short_name = "Delta-class (Pirate)"
    theme = "pirate"

/obj/docking_port/mobile/voidcrew/delta/pirate
    name = "Delta-class Frigate (Pirate)"
    area_type = /area/shuttle/voidcrew/delta/pirate

/area/shuttle/voidcrew/delta/pirate
    name = "Pirate Delta"
```

**2. Ship DMM** (`_maps/voidcrew/ships/ship_delta_pirate.dmm`):
- Copy base `ship_delta.dmm`
- Replace floors with `/turf/open/floor/wood`
- Replace walls with `/turf/closed/wall/mineral/wood`
- Keep ALL `modular_map_root/ship_upgrade` markers unchanged!

**3. Themed Modules** (only create if you want different aesthetics):

`_maps/voidcrew/ship_modules/cargo_basic_pirate.dmm`:
```dm
"a" = (
/turf/open/floor/wood,
/area/template_noop)
"b" = (
/obj/structure/closet/crate/wooden,  // Wooden crate instead of metal
/turf/open/floor/wood,
/area/template_noop)
"c" = (
/obj/modular_map_connector,
/turf/open/floor/wood,
/area/template_noop)
```

### Theme Fallback Behavior

```
Player spawns "Delta-class (Pirate)" with "Expanded Cargo" upgrade
    │
    ▼
System looks for: cargo_expanded_pirate.dmm
    │
    ├─► EXISTS: Load cargo_expanded_pirate.dmm
    │
    └─► NOT FOUND: Load cargo_expanded.dmm (base fallback)
```

This means:
- **Mappers can gradually add themed modules** - Non-themed base modules will work
- **Not every module needs every theme** - Only create themed variants where it matters
- **New themes work immediately** - They just use base modules until themed ones are added

---

## Complete File Checklist

### For a new ship class with upgrades:

- [ ] `_maps/voidcrew/ships/ship_{name}.dmm` - Ship DMM with upgrade markers
- [ ] Ship template definition in `voidcrew/mapping/shuttles/{name}.dm`
- [ ] Docking port and area subtypes
- [ ] Module definition file: `voidcrew/modules/ship_upgrades/ships/{name}.dm`
- [ ] Base module subtype with `for_ship = /datum/map_template/shuttle/voidcrew/{name}`
- [ ] Create subdirectory: `_maps/voidcrew/ship_modules/{name}/`
- [ ] Module DMMs in `_maps/voidcrew/ship_modules/{name}/`
- [ ] Add module files to TOML config under `[rooms.{name}.{slot}]`
- [ ] Include module DM file in `tgstation.dme`

### For a new themed ship variant:

- [ ] `_maps/voidcrew/ships/ship_{name}_{theme}.dmm` - Themed ship DMM
- [ ] Template definition with `theme = "{theme}"` in shuttle DM file
- [ ] Docking port subtype for themed variant
- [ ] Area subtype for themed variant
- [ ] (Optional) Themed module DMMs: `{module}_{theme}.dmm`
- [ ] **Note:** Themed variants use the BASE ship's modules (don't need separate module definitions)

### For a new module for an existing ship:

- [ ] `_maps/voidcrew/ship_modules/{ship}/{module}.dmm` - Module DMM in ship's subdirectory
- [ ] Module datum definition inheriting from ship's base type (e.g., `/datum/ship_upgrade_module/delta/new_module`)
- [ ] Set `map_file = "{ship}/{module}.dmm"`
- [ ] Add to TOML config under `[rooms.{ship}.{slot}]`
- [ ] (Optional) Create themed variants: `{ship}/{module}_{theme}.dmm`
