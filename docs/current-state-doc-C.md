# AI C - Current Ship Purchase System Analysis

## Overview
This document contains AI C's findings on how the current ship purchase and selection system works in the Voidcrew codebase. This is a **progression-based ship purchase mechanic** where players accumulate faction-specific ship parts across rounds to unlock larger/better ships. Parts are persistent while ships are per-round only.

---

## 1. UI/INTERFACE LAYER

### Primary Entry Point
**File:** `voidcrew/edits/mobs/new_player.dm`

**Key Proc:** `/mob/dead/new_player/proc/select_ship()` (lines 8-78)

**Flow:**
1. Player joins the game and triggers the latejoin menu
2. `select_ship()` is called, presenting a TGUI dialog with:
   - "Purchase ship" option (always first)
   - List of existing ships on the overmap (from `SSovermap.simulated_ships`)
   - Ship names displayed as: `"[ship.name] - ([ship.source_template?.short_name])"`

### Ship Purchase Dialog
When player selects "Purchase ship" (lines 26-42):
1. Shows second TGUI dialog: "Please select ship to purchase!"
2. Lists all purchasable ships from `SSmapping.ship_purchase_list`
3. Ship display format: `"[name] ([faction_prefix] [part_cost] parts)"`
   - Example: "Bogatyr-class Explorator (NEU 2 parts)"
   - Example: "Delta-class Frigate (NEU 3 parts)"

### Purchase Validation
```dm
if(!client.remove_ship_cost(initial(template.faction_prefix), initial(template.part_cost)) && !CONFIG_GET(flag/free_ships))
    tgui_alert(client, "You lack the parts needed to build this ship! (Required: [initial(template.part_cost)] [initial(template.faction_prefix)] parts)")
```

**Error Message Shown:** "You lack the parts needed to build this ship! (Required: 2 NEU parts)"

---

## 2. SHIP PARTS SYSTEM

### Ship Parts Definition
**File:** `voidcrew/modules/shuttle/ship_parts/ship_item.dm`

**Three Faction Types:**
```dm
/obj/item/ship_parts/neutral
    name = "neutral ship parts"
    ship_faction = NEUTRAL_SHIP  // "NEU"

/obj/item/ship_parts/nanotrasen
    name = "nanotrasen ship parts"
    ship_faction = NANOTRASEN_SHIP  // "NT-C"

/obj/item/ship_parts/syndicate
    name = "syndicate ship parts"
    ship_faction = SYNDICATE_SHIP  // "SYN-C"
```

**Constants File:** `voidcrew/_DEFINES/ship_defines.dm`
```dm
#define NEUTRAL_SHIP "NEU"
#define NANOTRASEN_SHIP "NT-C"
#define SYNDICATE_SHIP "SYN-C"
```

### Ship Parts Storage (Persistent)
**File:** `voidcrew/modules/shuttle/ship_parts/user_prefs.dm`

```dm
/datum/preferences
    var/list/ships_owned = list(
        /obj/item/ship_parts/neutral = 0,
        /obj/item/ship_parts/nanotrasen = 0,
        /obj/item/ship_parts/syndicate = 0,
    )

/datum/preferences/proc/save_ships()
    savefile.set_entry("ships_owned", ships_owned)
```

**Storage Location:** Saved to player's preferences savefile (persistent across rounds)

### Acquiring Ship Parts

**File:** `voidcrew/modules/shuttle/ship_parts/user_client.dm`

**Method 1: Automatic Grant (End of Round)**
- File: `user_prefs.dm` lines 14-17
```dm
/datum/controller/subsystem/ticker/display_report(popcount)
    for(var/client/all_clients as anything in GLOB.clients)
        all_clients.give_random_ship_part()
```
- Every player gets a random ship part at round end

**Method 2: Item Redemption**
```dm
/obj/item/ship_parts/attack_self(mob/user)
    user.client.prefs.ships_owned[type]++
    user.client.prefs.save_ships()
    to_chat(user, "You have redeemed [src]...")
    qdel(src)
```

**Method 3: Random Spawners**
- File: `spawners.dm`
```dm
/obj/effect/spawner/random/ship_parts
    loot = list(
        /obj/item/ship_parts/neutral = 70,
        /obj/item/ship_parts/nanotrasen = 20,
        /obj/item/ship_parts/syndicate = 10,
    )
```

### Spending Ship Parts
**File:** `voidcrew/modules/shuttle/ship_parts/user_client.dm`

```dm
/client/proc/remove_ship_cost(ship_faction, ship_cost)
    for(var/obj/item/ship_parts/ships in prefs.ships_owned)
        if(initial(ships.ship_faction) != ship_faction)
            continue
        if(prefs.ships_owned[ships] < ship_cost)
            return FALSE  // Not enough parts
        prefs.ships_owned[ships] -= ship_cost
        prefs.save_ships()
        return TRUE
    return FALSE  // No parts of that faction
```

**Logic:** Must have exact faction match AND sufficient quantity

---

## 3. SHIP SPAWNING

### Ship Creation Pipeline
**File:** `voidcrew/modules/overmap/code/controllers/subsystem/shuttle.dm`

**Proc:** `SSshuttle.create_ship(template)` (lines 1-34)

**Steps:**
1. Find unused overmap square: `SSovermap.get_unused_overmap_square()`
2. Create overmap ship object: `new /obj/structure/overmap/ship(location, template)`
3. Disable air subsystem temporarily
4. Load shuttle template: `action_load(ship.source_template)`
5. Re-enable air subsystem
6. Link shuttle to ship: `loaded.current_ship = ship`
7. Calculate ship mass
8. Create landmarks (blobstart, observer_start)
9. Return ship object

### Player Spawn to Ship
**File:** `voidcrew/edits/mobs/new_player.dm`

**Proc:** `/mob/dead/new_player/proc/AttemptSpawnOnShip(job, ship)` (lines 83-145)

**Steps:**
1. Validate ship and job slot availability
2. Decrement job slot: `joined_ship.job_slots[job]--`
3. Assign job through SSjob
4. Pick spawn point: `pick(joined_ship.shuttle.spawn_points)`
5. Create character at spawn point
6. Equip character for job
7. Inject into ship manifest
8. Add to global player list
9. Assign quirks if applicable
10. Cancel ship deletion timer if active

---

## 4. SHIP DEFINITIONS

### Ship Template Structure
**Base File:** `voidcrew/mapping/shuttles/_shuttle.dm`

```dm
/datum/map_template/shuttle/voidcrew
    prefix = "_maps/voidcrew/ships/"

    var/faction_prefix = NEUTRAL_SHIP  // "NEU", "NT-C", or "SYN-C"
    var/short_name                      // Display name (e.g., "Bogatyr-class")
    var/part_cost = 1                   // Number of parts required
    var/list/job_slots = list()         // Job definitions
```

### Example Ship Definitions

**Bogatyr (Neutral):**
```dm
/datum/map_template/shuttle/voidcrew/bogatyr
    name = "Bogatyr-class Explorator"
    suffix = "bogatyr"
    short_name = "Bogatyr-class"
    part_cost = 2
    // Map file: _maps/voidcrew/ships/bogatyr.dmm
```

**Delta (Neutral):**
```dm
/datum/map_template/shuttle/voidcrew/delta
    name = "Delta-class Frigate"
    suffix = "delta"
    short_name = "Delta-class"
    part_cost = 3
```

**Thunderbird (Nanotrasen):**
```dm
/datum/map_template/shuttle/voidcrew/thunderbird
    name = "Thunderbird-class Emergency military vessel"
    faction_prefix = NANOTRASEN_SHIP
    part_cost = 2
```

**Blackbeard (Syndicate):**
```dm
/datum/map_template/shuttle/voidcrew/blackbeard
    name = "Blackbeard-class Heavy Boarder"
    faction_prefix = SYNDICATE_SHIP
    part_cost = 1
```

### Ship Catalog Building
**File:** `voidcrew/mapping/_mapping.dm`

**Proc:** `/datum/controller/subsystem/mapping/proc/load_ship_templates()` (lines 174-186)

```dm
for(var/datum/map_template/shuttle/voidcrew/shuttles in subtypesof(/datum/map_template/shuttle/voidcrew))
    ship_purchase_list["[initial(shuttles.name)] ([initial(shuttles.faction_prefix)] [initial(shuttles.part_cost)] parts)"] = shuttles

    switch(initial(shuttles.faction_prefix))
        if(NANOTRASEN_SHIP)
            nt_ship_list[initial(shuttles.name)] = shuttles
        if(SYNDICATE_SHIP)
            syn_ship_list[initial(shuttles.name)] = shuttles
```

**Total Ships:** 28+ ship templates in `voidcrew/mapping/shuttles/`

---

## 5. PLAYER TRACKING

### Per-Player Data Structure
**Stored in:** `/datum/preferences`

```dm
var/list/ships_owned = list(
    /obj/item/ship_parts/neutral = 0,
    /obj/item/ship_parts/nanotrasen = 0,
    /obj/item/ship_parts/syndicate = 0,
)
```

### Ship Ownership Tracking
**File:** `voidcrew/modules/overmap/code/modules/overmap/ship.dm`

Ships track their crew through:
```dm
/obj/structure/overmap/ship
    var/datum/team/voidcrew/ship_team  // Team containing all crew minds
    var/list/manifest = list()          // Ship manifest (name -> job)
    var/list/job_slots                  // Remaining job slots
```

### Manifest System
```dm
/obj/structure/overmap/ship/proc/manifest_inject(mob/living/carbon/human/H, datum/job/human_job)
    if(H.mind && !length(H.mind.special_roles))
        manifest[H.real_name] = human_job
    register_crewmember(H)
```

### Active Ship Tracking
**File:** `voidcrew/modules/overmap/code/controllers/subsystem/overmap.dm`

```dm
SUBSYSTEM_DEF(overmap)
    var/list/simulated_ships = list()  // All active ships in the round
    var/obj/structure/overmap/ship/initial_ship  // Starting ship
```

---

## 6. PER-ROUND vs PERSISTENT

### PERSISTENT (Across Rounds):
1. **Ship Parts Inventory:**
   - Stored in player preferences savefile
   - Survives server restarts
   - Accumulates over time

2. **Part Acquisition:**
   - Each round end: `give_random_ship_part()`
   - Parts found in-game can be redeemed

### PER-ROUND (Reset Each Round):
1. **Active Ships:**
   - `SSovermap.simulated_ships` list cleared each round
   - Ships spawned during round are temporary

2. **Ship State:**
   - Ship positions, crew, modifications
   - All reset when round ends

3. **Initial Ship:**
   - One ship auto-spawned at round start
   - Selected randomly from NT or Syndicate ships
   - File: `overmap.dm` lines 307-347

### Config Override
**File:** `voidcrew/edits/config.dm`

```dm
/datum/config_entry/flag/free_ships
    default = FALSE
```

If set to TRUE: Bypass parts requirement entirely

---

## ARCHITECTURE SUMMARY

### Data Flow for Ship Purchase:
```
1. Player clicks "Join Game"
2. select_ship() displays dialog
3. Player selects "Purchase ship"
4. SSmapping.ship_purchase_list provides options
5. Player selects ship template
6. client.remove_ship_cost() validates and deducts parts
7. SSshuttle.create_ship() spawns ship on overmap
8. AttemptSpawnOnShip() spawns player as captain
9. Ship added to SSovermap.simulated_ships
```

### Key Files by Function:

**UI Layer:**
- `voidcrew/edits/mobs/new_player.dm` - All dialogs and player interaction

**Ship Parts:**
- `voidcrew/modules/shuttle/ship_parts/ship_item.dm` - Part item definitions
- `voidcrew/modules/shuttle/ship_parts/user_prefs.dm` - Persistent storage
- `voidcrew/modules/shuttle/ship_parts/user_client.dm` - Part management procs
- `voidcrew/modules/shuttle/ship_parts/spawners.dm` - World spawners

**Ship Definitions:**
- `voidcrew/mapping/shuttles/_shuttle.dm` - Base template
- `voidcrew/mapping/shuttles/[shipname].dm` - Individual ships (28+ files)
- `voidcrew/mapping/_mapping.dm` - Catalog building

**Ship Spawning:**
- `voidcrew/modules/overmap/code/controllers/subsystem/shuttle.dm` - Ship creation
- `voidcrew/modules/overmap/code/controllers/subsystem/overmap.dm` - Overmap management
- `voidcrew/modules/overmap/code/modules/overmap/ship.dm` - Ship object (848 lines!)

**Constants:**
- `voidcrew/_DEFINES/ship_defines.dm` - Faction constants

---

## QUESTIONS FOR OTHER AGENTS

1. **Currency System:** Do we already have any currency/points system in the codebase that could be repurposed?
2. **Ship Catalog UI:** Is there existing TGUI infrastructure for displaying ship previews/images, or do we need to build that from scratch?
3. **Rendered Ship Images:** Where would ship map renders/previews be stored? New directory needed?
4. **Unlock Persistence:** Should unlocks use the existing `/datum/preferences` system or create a new persistence layer?
5. **Crew Role Customization:** The feature mentions "pay to modify the roles that ships spawn with" - is there existing job customization code we can leverage?

---

## NOTES FROM SCREENSHOTS

From the GitHub issue screenshot, the requested features are:
- Ship catalog with rendered images of ship maps
- Currency system for ship purchases (replacing parts)
- Permanent ship unlocks (buy once, spawn forever per-round)
- Ability to customize/upgrade crew roles for ships
- Ship skins/customization options

Current system uses **consumable parts** (you spend them to spawn), but new system should be **permanent unlocks** (spend currency once, own forever).
