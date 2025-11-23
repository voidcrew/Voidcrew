# AI D - Current System Analysis

## SHIP SELECTION SYSTEM

**Main Implementation:** `voidcrew\edits\mobs\new_player.dm:8-79`

The ship selection dialog works by:
- Intercepting the standard latejoin menu via `/datum/latejoin_menu/ui_interact()` override
- Pulling available ships from `SSovermap.simulated_ships`
- Filtering ships that have `joining_allowed = TRUE` and have spawn points
- Displaying format: `"[ship.name] - ([ship.source_template?.short_name])"`
- First option in the list is always "Purchase ship"
- After ship selection, shows job selection specific to that ship
- Spawning handled via `AttemptSpawnOnShip()` at lines 83-145

**Spawn Process:**
1. Decrements job slots on selected ship
2. Uses SSjob to assign the role
3. Spawns player at random spawn point on chosen ship
4. Injects player into ship's manifest
5. Cancels ship deletion timer if crew joins

## SHIP PURCHASE SYSTEM (NEU PARTS)

**Purchase Flow:** `voidcrew\edits\mobs\new_player.dm:26-42`

Current purchase mechanics:
1. Shows ships from `SSmapping.ship_purchase_list`
2. Cost verification via `client.remove_ship_cost(template)`
3. Cost based on:
   - `template.faction_prefix` (NEU, NT-C, or SYN-C)
   - `template.part_cost` (integer, typically 1-3 parts)
4. Shows "You lack the parts needed to build this ship! (Required: X NEU parts)" if insufficient
5. Config flag `free_ships` can bypass cost requirement (default: FALSE)
6. On success: `SSshuttle.create_ship(template)` spawns the ship at random overmap coordinates
7. Purchaser auto-spawns as first job slot (usually Captain)

**Parts Currency System:**

Files:
- `voidcrew\modules\shuttle\ship_parts\ship_item.dm` - Physical part items
- `voidcrew\modules\shuttle\ship_parts\user_client.dm` - Purchase/gift procs
- `voidcrew\modules\shuttle\ship_parts\user_prefs.dm` - Persistence layer
- `voidcrew\modules\shuttle\ship_parts\spawners.dm` - Spawner objects

Key mechanics:
- **Three faction currencies:** neutral parts, nanotrasen parts, syndicate parts
- **Storage:** `datum/preferences/ships_owned` dictionary with faction-specific keys
- **Earning:** 1 random part awarded per round completion (end of round)
- **Redemption:** Physical part items can be used via `attack_self()` to add parts to account
- **Persistence:** Saved via savefile system in `save_ships()` proc
- **Client Procs:**
  - `remove_ship_cost()` - Deducts parts and saves (Lines 2-13)
  - `give_random_ship_part()` - Awards random part (Lines 16-20)
  - `list_ship_parts()` - Shows owned parts (Lines 23-28)

## SHIP DEFINITIONS

**Base Template:** `voidcrew\mapping\shuttles\_shuttle.dm`

Ship template structure:
```dm
/datum/map_template/shuttle/voidcrew
    faction_prefix = NEUTRAL_SHIP  // Determines currency type (NEU, NT-C, SYN-C)
    short_name                      // Class display name (e.g. "Delta-class")
    part_cost = 1                   // Purchase price in parts
    job_slots = list()              // List of job definitions
```

**Storage:** 30+ ship files in `voidcrew\mapping\shuttles\*.dm`

Each ship includes:
- Template datum with metadata (name, faction, cost)
- Job slot definitions with outfit assignments
- Docking port datum
- Area definitions
- Corresponding .dmm map file in `_maps/voidcrew/ships/`

**Job Structure Example:**
```dm
job_slots = list(
    list(
        name = "Captain",
        officer = TRUE,
        outfit = /datum/outfit/job/captain,
        slots = 1,
    ),
    // ... more jobs
)
```

**Job Assembly:** `assemble_job_slots()` at `_shuttle.dm:23-42`
- Converts job_slots list into `/datum/job` instances
- Sets job titles, outfits, flags, and supervisors
- First job slot is always the captain/leader role

**Ship List Generation:** `voidcrew\mapping\_mapping.dm:174-186`
- `load_ship_templates()` iterates all `/datum/map_template/shuttle/voidcrew` subtypes
- Builds `ship_purchase_list` with display format: `"[name] ([faction] [cost] parts)"`
- Separates into `nt_ship_list` and `syn_ship_list` for initial spawns

## LOBBY/CHARACTER SETUP

**Override:** `voidcrew\edits\mobs\new_player.dm:1-3`

The Voidcrew system completely bypasses standard SS13 latejoin:
```dm
/datum/latejoin_menu/ui_interact(mob/dead/new_player/user, datum/tgui/ui)
    user.select_ship() // Custom ship-based selection instead
    return TRUE
```

**Standard Latejoin (Unused):** `code\modules\mob\dead\new_player\latejoin_menu.dm`
- Traditional department-based job selection
- Completely bypassed by Voidcrew's ship selection system

**New Player Flow:**
1. Player joins as `/mob/dead/new_player`
2. Clicking "Join" triggers latejoin menu
3. Voidcrew intercepts and calls `select_ship()` instead
4. Player selects ship (or purchases new one)
5. Player selects job on that ship
6. `AttemptSpawnOnShip()` spawns them on the ship

## CURRENCY/PERSISTENCE SYSTEMS

**Ship Parts Persistence:**
- **Storage:** `datum/preferences/ships_owned` dictionary
- **Three currencies:**
  - `/obj/item/ship_part` (neutral - NEU)
  - `/obj/item/ship_part/nanotrasen` (NT-C)
  - `/obj/item/ship_part/syndicate` (SYN-C)
- **Earning:** 1 random part awarded per round completion
- **Savefile:** Persists via `preferences_savefile.dm`
- **Format:** Dictionary with part type as key, count as value

**Ship Bank Accounts:**
- **Location:** `obj/structure/overmap/ship:38` in ship.dm
- **Type:** `datum/bank_account/ship/ship_account`
- **Shared:** All crew members on ship use ship's bank account
- **Setup:** Created during ship initialization (ship.dm:122)

**Initial Ship Spawning:**
- **Subsystem:** `SSovermap.spawn_initial_ship()` (overmap.dm:307-324)
- **Selection:** Picks random NT or Syndicate ship (never neutral)
- **Purpose:** Ensures at least one ship exists for players to join at round start
- **Deletion Handling:** Tracks initial ship and warns admins if deleted

**Ship Creation:** `SSshuttle.create_ship()` (shuttle subsystem:1-34)
- Loads ship template into game world
- Creates overmap object at random coordinates
- Links docking port and shuttle areas
- Calculates ship mass based on template
- Creates spawn landmarks for jobs

## CURRENT LIMITATIONS (Based on Feature Request)

From the GitHub issue screenshot, the system needs:

1. **Permanent Ownership:** Currently ships are purchased per-round only (parts deducted each time)
2. **Unlock System:** Ships should be unlocked permanently, then spawnable once per round
3. **Ship Catalog:** Need rendered ship images/maps in purchase UI
4. **Currency System:** Needs dedicated ship currency separate from unlock system
5. **Visual Catalog:** Current UI is text-only list with no previews
6. **Per-Round Spawning:** Once unlocked, ship can be spawned once per round without cost

## KEY ARCHITECTURE INSIGHTS

- **Ship-Centric Design:** Ships are the organizational unit (not stations)
- **Overmap Integration:** Ships exist on 2D overmap (`voidcrew\modules\overmap\code\modules\overmap\ship.dm`)
- **Dynamic Spawning:** Ships created on-demand via `SSshuttle.create_ship()`
- **Per-Ship Jobs:** Job slots are ship-specific, not station-wide
- **Faction System:** Three factions (NEU/NT-C/SYN-C) with separate part currencies
- **Template-Based:** Ships defined as templates that get instantiated
- **No Traditional Station:** Completely replaces standard SS13 station spawning

## FILE REFERENCE SUMMARY

**Ship Selection & Purchase:**
- `voidcrew\edits\mobs\new_player.dm` (Lines 1-161) - Main selection UI and purchase flow

**Currency System:**
- `voidcrew\modules\shuttle\ship_parts\ship_item.dm` - Part item definitions
- `voidcrew\modules\shuttle\ship_parts\user_client.dm` - Client purchase/gift procs
- `voidcrew\modules\shuttle\ship_parts\user_prefs.dm` - Persistence layer
- `voidcrew\modules\shuttle\ship_parts\spawners.dm` - Part spawner objects

**Ship Templates:**
- `voidcrew\mapping\shuttles\_shuttle.dm` - Base template class and job assembly
- `voidcrew\mapping\shuttles\*.dm` - 30+ individual ship definitions
- `voidcrew\mapping\_mapping.dm` (Lines 174-186) - Template loading and list generation

**Ship Runtime:**
- `voidcrew\modules\overmap\code\modules\overmap\ship.dm` - Ship object and bank accounts
- `voidcrew\modules\overmap\code\controllers\subsystem\shuttle.dm` - Ship creation subsystem
- `voidcrew\modules\overmap\code\controllers\subsystem\overmap.dm` - Overmap and initial ship spawning

**Configuration:**
- `voidcrew\_DEFINES\ship_defines.dm` - Faction constants (NEU/NT-C/SYN-C)
- `voidcrew\edits\config.dm` (Lines 16-17) - Free ships config flag

---

**AI D Analysis Complete** - Ready for collaboration with other agents
