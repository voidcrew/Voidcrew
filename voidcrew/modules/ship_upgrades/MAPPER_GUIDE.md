# Ship Modular Upgrades - Mapper Guide

This guide explains how to add modular upgrade slots to ships and create upgrade modules.

## Overview

The modular upgrade system allows ships to have customizable sections that players can choose when spawning. Each ship can have multiple **upgrade slots** (like "cargobay", "medbay", "engineroom"), and each slot can have multiple **module options** to choose from.

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

Create module DMM files in `_maps/voidcrew/ship_modules/`. Each module MUST have:

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

In `voidcrew/modules/ship_upgrades/test_modules.dm` (or create a new file), add:

```dm
/datum/ship_upgrade_module/cargo_expanded
    id = "cargo_expanded"
    name = "Expanded Cargo Bay"
    desc = "A larger cargo area with more storage."
    slot = "cargobay"                    // Must match the key in the DMM
    map_file = "cargo_expanded.dmm"      // Filename only, not full path
    part_cost = list(PART_CLASS_TRADE = 1)  // Optional cost
    is_default = FALSE                   // Set TRUE for the default option
```

### 5. Add to TOML Config

In `strings/modular_maps/ship_upgrades.toml`, add your module to the appropriate slot:

```toml
[rooms.cargobay]
modules = ["cargo_basic.dmm", "cargo_expanded.dmm", "your_new_module.dmm"]
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
| `id` | string | Yes | Unique identifier (e.g., "cargo_expanded") |
| `name` | string | Yes | Display name shown in UI |
| `desc` | string | No | Description shown in UI |
| `slot` | string | Yes | Which slot this fits (must match `key` in DMM) |
| `map_file` | string | Yes | DMM filename (just the filename, not path) |
| `part_cost` | list | No | Cost to select: `list(PART_CLASS_TRADE = 1)` |
| `is_default` | bool | No | If TRUE, loads when no upgrade selected |

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
    ├── cargo_basic.dmm         # Module DMMs
    ├── cargo_expanded.dmm
    └── your_module.dmm

strings/modular_maps/
└── ship_upgrades.toml          # Module registry

voidcrew/modules/ship_upgrades/
├── _ship_upgrades.dm           # Core system (don't edit)
├── modular_map_root_ship.dm    # Loader (don't edit)
└── test_modules.dm             # Module definitions (add yours here)

voidcrew/mapping/shuttles/
└── your_ship.dm                # Ship template definition
```

---

## Step-by-Step Example: Adding a Medbay Slot

### Step 1: Create Module DMMs

**`_maps/voidcrew/ship_modules/medbay_basic.dmm`**
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

**`_maps/voidcrew/ship_modules/medbay_cloner.dmm`**
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

Add to `voidcrew/modules/ship_upgrades/test_modules.dm`:

```dm
// ===== MEDBAY UPGRADES =====

/datum/ship_upgrade_module/medbay_basic
    id = "medbay_basic"
    name = "Basic Medbay"
    desc = "A simple medical area with beds and supplies."
    slot = "medbay"
    map_file = "medbay_basic.dmm"
    is_default = TRUE

/datum/ship_upgrade_module/medbay_cloner
    id = "medbay_cloner"
    name = "Cloning Medbay"
    desc = "Advanced medical with cloning facilities."
    slot = "medbay"
    map_file = "medbay_cloner.dmm"
    part_cost = list(PART_CLASS_SCIENCE = 2)
```

### Step 3: Add to TOML

In `strings/modular_maps/ship_upgrades.toml`:

```toml
[rooms.medbay]
modules = ["medbay_basic.dmm", "medbay_cloner.dmm"]
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
- Check game log for "SHIP_UPGRADE:" messages
- Verify `key` in DMM matches `slot` in module definition
- Verify module is registered in TOML
- Verify DMM file exists at correct path

### Module loads in wrong position
- Check `/obj/modular_map_connector` placement in module DMM
- The connector aligns with the `modular_map_root/ship_upgrade` marker

### Area errors
- Use `/area/template_noop` in module DMMs
- This allows the module to inherit the ship's area

### Module not appearing in selection
- Verify `slot` matches `upgrade_slot_ids` in ship template
- Check module is registered (has `id` set)
- Run `ensure_ship_upgrades_initialized()` to trigger registration

---

## Best Practices

1. **Keep modules small** - 3x3 to 5x5 tiles is ideal
2. **Use consistent connector placement** - Usually center or entrance
3. **Test alignment** - Spawn with different modules to verify positioning
4. **Document your modules** - Use clear names and descriptions
5. **Balance costs** - Better modules should cost more parts
6. **One default per slot** - Mark exactly one module as `is_default = TRUE`
