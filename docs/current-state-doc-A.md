# SHIP PURCHASE/SPAWN SYSTEM - CURRENT STATE DOCUMENTATION
## AI A's Findings

---

## 1. SHIP PURCHASE/SELECTION FLOW

### Entry Point
**File:** `voidcrew\edits\mobs\new_player.dm`

The ship selection system is triggered when a player joins the game.

#### Main Flow: `/mob/dead/new_player/proc/select_ship()` (lines 8-79)

**Step 1: Initial Menu Display**
- System builds a list of available options: "Purchase ship" + all active ships
- Active ships are retrieved from `SSovermap.simulated_ships`
- Ships must have spawn points: `length(active_ships.shuttle.spawn_points) > 0`
- Ships must allow joining: `active_ships.joining_allowed == TRUE`
- Display format: `"[ship_name] - ([ship_class])"`

**Step 2: Ship Purchase Branch** (lines 26-42)
If player selects "Purchase ship":
1. Shows list from `SSmapping.ship_purchase_list` (all purchasable ship templates)
2. Checks if player has required parts via `client.remove_ship_cost()`
3. If insufficient parts AND `free_ships` config is FALSE ’ shows error dialog
4. Creates ship via `SSshuttle.create_ship(template)`
5. Spawns player as first job slot (usually captain) via `AttemptSpawnOnShip()`

**Step 3: Existing Ship Join Branch** (lines 44-78)
If player selects an existing ship:
1. If ship has a memo, displays it with OK/Cancel prompt
2. Shows available job slots on that ship
3. Filters jobs with `< 1` slots remaining
4. Spawns player via `AttemptSpawnOnShip(selected_job, selected_ship)`

### UI Override
**File:** `voidcrew\edits\mobs\new_player.dm` (lines 1-3)
- The standard latejoin menu is overridden to redirect to `select_ship()`
- Uses native BYOND `tgui_input_list()` dialogs
- No custom TGUI interface currently exists for ship selection

---

## 2. PARTS SYSTEM

### Part Types
**File:** `voidcrew\modules\shuttle\ship_parts\ship_item.dm`

Three faction types exist:
- **NEU (Neutral)** - `NEUTRAL_SHIP` - Color: Beige
- **NT-C (Nanotrasen)** - `NANOTRASEN_SHIP` - Color: Light Blue
- **SYN-C (Syndicate)** - `SYNDICATE_SHIP` - Color: Light Red

**Define locations:** `voidcrew\_DEFINES\ship_defines.dm`

### Part Storage (Persistence)
**File:** `voidcrew\modules\shuttle\ship_parts\user_prefs.dm`

Parts are stored in player preferences:
```dm
/datum/preferences
    var/list/ships_owned = list(
        /obj/item/ship_parts/neutral = 0,
        /obj/item/ship_parts/nanotrasen = 0,
        /obj/item/ship_parts/syndicate = 0,
    )
```

- Saved to savefile via `save_ships()` proc
- Persists between rounds per player character
- Stored in character-specific savefile

### Part Distribution
**File:** `voidcrew\modules\shuttle\ship_parts\user_prefs.dm` (lines 14-17)

**IMPORTANT:** Every player receives ONE random ship part at the start of each round:
```dm
/datum/controller/subsystem/ticker/display_report(popcount)
    . = ..()
    for(var/client/all_clients as anything in GLOB.clients)
        all_clients.give_random_ship_part()
```

This ensures players always accumulate parts over time.

### Part Redemption
**File:** `voidcrew\modules\shuttle\ship_parts\ship_item.dm` (lines 10-15)

Physical ship part items can be found in-game and used:
- Using the item (`attack_self()`) increments the player's part count for that faction
- Deletes the item after redemption
- Notifies player: "You have redeemed [src], you may redeem it to purchase future ships."
- Additional way to earn parts beyond the 1-per-round grant

### Part Verification
**File:** `voidcrew\modules\shuttle\ship_parts\user_client.dm` (lines 1-13)

`/client/proc/remove_ship_cost(ship_faction, ship_cost)`:
- Checks if player has enough parts of the correct faction
- Deducts parts if sufficient
- Saves updated count via `prefs.save_ships()`
- Returns TRUE if successful, FALSE if insufficient parts

### Part Spawners
**File:** `voidcrew\modules\shuttle\ship_parts\spawners.dm`

World spawner with weighted loot:
- 70% Neutral parts
- 20% Nanotrasen parts
- 10% Syndicate parts

These can be placed on maps to create lootable part items.

### Config Override
**File:** `voidcrew\edits\config.dm` (line 16-17)

`/datum/config_entry/flag/free_ships` - Default: FALSE
- When TRUE, bypasses part requirements entirely
- Players can purchase any ship without cost
- Used for testing or special game modes

---

## 3. SHIP SPAWNING

### Ship Creation Pipeline
**File:** `voidcrew\modules\overmap\code\controllers\subsystem\shuttle.dm` (lines 1-34)

`/datum/controller/subsystem/shuttle/proc/create_ship(template)`:

**Step 1: Thread Safety**
- Waits if another ship is loading: `UNTIL(!shuttle_loading)`
- Prevents concurrent ship spawns from corrupting state

**Step 2: Overmap Placement**
- Creates ship at `SSovermap.get_unused_overmap_square()`
- Ensures ships don't spawn on top of each other

**Step 3: Map Loading**
- Temporarily disables SSair: `SSair.can_fire = FALSE`
- Calls `action_load(ship_to_spawn.source_template)`
- Re-enables SSair after load completes
- This prevents atmosphere calculation during map load

**Step 4: Ship Linking**
- Links docking port to ship object
- Sends `COMSIG_VOIDCREW_SHIP_LOADED` signal
- Other systems can hook into this signal

**Step 5: Finalization**
- Calculates ship mass based on loaded structures
- Creates blob/observer spawn landmarks
- Returns the ship object

### Player Spawning
**File:** `voidcrew\edits\mobs\new_player.dm` (lines 83-145)

`/mob/dead/new_player/proc/AttemptSpawnOnShip(job, joined_ship)`:

**Step 1: Validation**
- Checks if ship/shuttle exists
- Verifies job slots available
- Checks for admin blocks (DISABLE_NON_OBSJOBS flag)

**Step 2: Job Assignment**
- Decrements job slot count in ship's `job_slots` list
- Assigns role via `SSjob.assign_role()`
- Removes player from join queue

**Step 3: Character Creation**
- Picks random spawn point from `joined_ship.shuttle.spawn_points` (cryopods)
- Creates character at spawn point via `create()`
- Transfers consciousness via `transfer_character()`
- Equips job outfit via `SSjob.equip_rank()`

**Step 4: Ship Integration**
- Adds to ship manifest via `joined_ship.manifest_inject()`
- Adds to global manifest
- Loads persistent scars
- Assigns quirks if applicable
- Ends deletion timer if ship was scheduled for deletion

### Spawn Points
**File:** `voidcrew\modules\cryo\machine.dm`

Cryopods serve as spawn points:
- Register with docking port via `connect_to_shuttle()` callback
- Added to `linked_ship.spawn_points` list during initialization
- Players spawn inside cryopod, then wake up (5 second stun)
- Prevents spawning in walls or space

---

## 4. SHIP DEFINITIONS

### Template Structure
**File:** `voidcrew\mapping\shuttles\_shuttle.dm`

```dm
/datum/map_template/shuttle/voidcrew
    prefix = "_maps/voidcrew/ships/"
    var/faction_prefix = NEUTRAL_SHIP    // Ship faction (NEU/NT-C/SYN-C)
    var/short_name                       // Short display name
    var/part_cost = 1                    // Number of parts required
    var/list/job_slots = list()          // Job definitions
    var/abstract_type = /datum/map_template/shuttle/voidcrew  // Prevent spawning abstracts
```

### Job Slot Definition
Each ship defines jobs as a list of associative lists:
```dm
job_slots = list(
    list(
        "name" = "Captain",              // Job title
        "officer" = TRUE,                // Is this the ship leader?
        "outfit" = /datum/outfit/job/captain,  // Outfit to give
        "slots" = 1,                     // Number of slots
    ),
    list(
        "name" = "Engineer",
        "outfit" = /datum/outfit/job/engineer,
        "slots" = 2,
    ),
    // ... more jobs
)
```

**Job Assembly:** `assemble_job_slots()` (lines 23-42)
- Converts job definitions to actual job datums
- Sets job flags (CREW_MANIFEST, EQUIP_RANK, etc.)
- First job is always considered the supervisor
- Returns associative list: `job_datum = slot_count`

### Example Ships

**Bogatyr-class Explorator** (2 NEU parts):
- File: `voidcrew\mapping\shuttles\bogatyr.dm`
- Map: `_maps\voidcrew\ships\ship_bogatyr.dmm`
- Crew: 10 (Captain, Uchenyy, 2x Shakhter, Vrach, Gruzovoy Tekhnik, 4x Pomoshchnik)

**Box-class Hospital Ship** (1 NEU part):
- File: `voidcrew\mapping\shuttles\box.dm`
- Map: `_maps\voidcrew\ships\ship_box.dmm`
- Crew: 9 (CMO, 3x Doctor, 2x Paramedic, 3x Assistant)

**Delta-class Frigate** (3 NEU parts):
- File: `voidcrew\mapping\shuttles\delta.dm`
- Map: `_maps\voidcrew\ships\ship_delta.dmm`
- Crew: 9 (Captain, QM, Doctor, Engineer, 2x Miner, 3x Assistant)

### Ship Template Loading
**File:** `voidcrew\mapping\_mapping.dm` (lines 174-186)

`/datum/controller/subsystem/mapping/proc/load_ship_templates()`:
- Iterates all `/datum/map_template/shuttle/voidcrew` subtypes
- Adds to `ship_purchase_list` with display name: `"[name] ([faction] [cost] parts)"`
- Categorizes NT ships into `nt_ship_list`
- Categorizes Syndicate ships into `syn_ship_list`
- Called during mapping subsystem initialization

### Map Files
**Location:** `_maps\voidcrew\ships\*.dmm`
- DMM format (BYOND map files)
- Each ship has a corresponding `.dmm` file
- Contains actual tile/object layout
- Includes walls, floors, equipment, cryopods, etc.

---

## 5. PERSISTENCE SYSTEM

### Current Implementation
**File:** `voidcrew\modules\shuttle\ship_parts\user_prefs.dm`

**What IS Saved:**
- Ship parts owned per faction type
- Saved per character via savefile system
- Persists across rounds

**Savefile Entry:**
```dm
/datum/preferences/proc/save_ships()
    var/savefile/savefile = new /savefile(path)
    savefile.cd = "/character[default_slot]"
    savefile.set_entry("ships_owned", ships_owned)
```

### Player Data Management
**File:** `voidcrew\modules\shuttle\ship_parts\user_client.dm`

**Available Procs:**
- `give_random_ship_part()` - Adds random part, saves to prefs
- `list_ship_parts()` - Displays owned parts to chat
- `get_ships()` - Returns formatted list of owned parts
- `remove_ship_cost()` - Deducts parts, saves to prefs

### What is NOT Saved
- Ship existence/state across rounds (ships delete on round end)
- Player credits/money (resets each round)
- Ship cargo/items (all lost on round end)
- Ship damage/modifications (resets)
- Ship upgrades (if any exist)
- Player unlock status for specific ships

**Important:** Ships are completely ephemeral within a single round. Only the parts used to purchase them persist.

---

## 6. CURRENCY SYSTEMS

### Ship Bank Accounts
**File:** `voidcrew\modules\cargo\bank_account.dm`

Each ship has a `datum/bank_account/ship`:
- Created during ship initialization
- Linked to ship's first job (captain)
- Named after ship team name
- Registered in `SSeconomy.department_accounts`

**Location in Ship Object:** `voidcrew\modules\overmap\code\modules\overmap\ship.dm` (line 38)
```dm
/datum/overmap/ship/simulated
    var/datum/bank_account/ship/ship_account
```

### Player Account Integration
**File:** `voidcrew\modules\overmap\code\modules\overmap\ship.dm` (lines 261-277)

When a player joins a ship (`manifest_inject()`):
1. Individual bank account is deleted: `qdel(account)`
2. ID card linked to ship account
3. Ship account added to ID's `bank_cards` list
4. Player memory wiped (clears old account reference)
5. Paycheck department set to ship team name

**Effect:** All crew share the same bank account, promoting cooperation.

### Currency System Integration
- Uses standard TG economy system (`SSeconomy`)
- Individual player credits replaced with shared ship pool
- Compatible with existing cargo/ATM/vendor systems
- **No persistence** - bank accounts reset each round
- Starting balance determined by ship configuration

### No Cross-Round Currency
Currently, there is **no currency system that persists between rounds**. The feature request mentions needing to create one for permanent ship purchases.

---

## 7. CHARACTER/ROLE SYSTEMS

### Job Assignment Flow
**File:** `voidcrew\edits\jobs.dm`

`/datum/job/map_check()`:
- Overrides standard job availability system
- Checks against initial ship's job slots (for roundstart)
- Non-joinable jobs bypass this system
- First "officer" job becomes overflow role

### Ship Team System
**File:** `voidcrew\modules\overmap\code\modules\overmap\ship.dm` (lines 112-116, 255-277)

Each ship has a `datum/team/voidcrew/ship_team`:
- Created during ship initialization
- All crewmembers added to team via `ship_team.add_member(mind)`
- Tracks faction prefix (NEU/NT-C/SYN-C)
- Links back to ship object
- Used for announcements and team-based gameplay

### Job Slots Management

**Dynamic Slot Adjustment:**
- Ships track `job_slots` (associative list: `job = remaining_slots`)
- Decremented when player joins
- Checked by latejoin menu to show availability
- Can be modified via ship management console (with cooldown)

**Slot Tracking:**
- Initial slots defined in ship template
- Runtime slots stored in ship object
- No persistence between rounds

### Role Features

**Officer Flag:**
- First job in `job_slots` list is considered leader
- Has `officer = TRUE` flag
- Becomes supervisor for all other crew
- Used for overflow role assignment
- Typically the Captain role

### Initial Ship Selection
**File:** `voidcrew\modules\overmap\code\controllers\subsystem\overmap.dm` (lines 307-349)

`spawn_initial_ship()` / `set_initial_ship()`:
- Randomly selects from NT or Syndicate ships (excludes neutral)
- Creates ship at round start
- All roundstart players join this ship
- Stored in `SSovermap.initial_ship` and `SSovermap.initial_ship_template`

### Faction Integration
Ships have faction colors on overmap:
- Syndicate: Red (#F10303)
- Nanotrasen: Blue (#115188)
- Neutral: Light Gray (#DDDDDD)

---

## 8. KEY FILE LOCATIONS

### Core Systems
- **Ship Purchase UI:** `voidcrew\edits\mobs\new_player.dm`
- **Ship Creation:** `voidcrew\modules\overmap\code\controllers\subsystem\shuttle.dm`
- **Ship Object:** `voidcrew\modules\overmap\code\modules\overmap\ship.dm`
- **Overmap System:** `voidcrew\modules\overmap\code\controllers\subsystem\overmap.dm`

### Parts System
- **Part Items:** `voidcrew\modules\shuttle\ship_parts\ship_item.dm`
- **Part Persistence:** `voidcrew\modules\shuttle\ship_parts\user_prefs.dm`
- **Part Client Procs:** `voidcrew\modules\shuttle\ship_parts\user_client.dm`
- **Part Spawners:** `voidcrew\modules\shuttle\ship_parts\spawners.dm`

### Ship Definitions
- **Template Base:** `voidcrew\mapping\shuttles\_shuttle.dm`
- **Template Loader:** `voidcrew\mapping\_mapping.dm`
- **Ship Examples:** `voidcrew\mapping\shuttles\*.dm`
- **Ship Maps:** `_maps\voidcrew\ships\*.dmm`

### Supporting Systems
- **Docking Port:** `voidcrew\mapping\docking_port\_docking_port.dm`
- **Spawn Points:** `voidcrew\modules\cryo\machine.dm`
- **Bank Accounts:** `voidcrew\modules\cargo\bank_account.dm`
- **Job System:** `voidcrew\edits\jobs.dm`
- **Helm Console:** `voidcrew\modules\shuttle\helm\_helm.dm`

### Configuration
- **Defines:** `voidcrew\_DEFINES\ship_defines.dm`, `voidcrew\_DEFINES\overmap.dm`
- **Config:** `voidcrew\edits\config.dm`

---

## 9. TECHNICAL NOTES

### Thread Safety
- Ship loading uses `shuttle_loading` flag to prevent concurrent spawns
- SSair temporarily disabled during map load to prevent performance issues
- Ships must finish loading before next ship can spawn

### Signal System
Ships use several signals for event coordination:
- `COMSIG_VOIDCREW_SHIP_LOADED` - Ship fully loaded and ready
- `COMSIG_VOIDCREW_SHIP_DOCKED` - Ship docked at station/structure
- `COMSIG_VOIDCREW_SHIP_UNDOCKED` - Ship undocked and flying
- `COMSIG_VOIDCREW_SHIP_MOVED` - Ship moved on overmap

### Deletion System
Ships auto-delete when:
- All crew dead for 10 minutes (converts to ruin or deletes)
- Admin-initiated bluespace jump
- Manual admin deletion
- Round end

### UI System
The purchase menu uses native BYOND UI:
- `tgui_input_list()` for modal dialogs
- No custom TGUI interface for ship selection currently
- Displays as simple list selection
- Limited visual feedback

---

## 10. CURRENT LIMITATIONS & GAPS

Based on the feature request, here are the gaps in the current system:

### Missing Features
1. **Permanent Ship Ownership** - Ships currently only exist for one round
2. **Ship Catalog with Images** - No visual catalog, only text list
3. **Persistent Currency** - No cross-round currency for ship purchases
4. **Ship Unlocking System** - Ships are part-gated, not unlock-based
5. **Crew Role Customization** - Cannot modify roles/gear before purchase
6. **Ship Skins** - No cosmetic variation system
7. **Antagonist Ships** - Mentioned in feature request, unclear if different from current system
8. **Ship Upgrade Purchases** - No permanent upgrade system

### Current System Strengths
1. **Parts persistence works well** - Reliable savefile system
2. **Dynamic ship spawning** - Can create ships mid-round
3. **Flexible job system** - Easy to define custom roles per ship
4. **Team integration** - Ships already have faction teams
5. **Bank account sharing** - Crew cooperation mechanics exist

### Technical Debt
1. **UI is minimal** - Native BYOND dialogs, not TGUI
2. **No image rendering** - Cannot display ship previews
3. **Limited spawn point logic** - Only cryopods work
4. **No validation** - Can purchase duplicate ships if spammed

---

## CONCLUSION

The current system is a **functional but basic ship purchase system** based on consumable parts. It works well for temporary, per-round ship spawning but lacks the persistence and richness described in the feature request.

Key architectural decisions to make:
1. How to handle permanent ship ownership (new savefile structure?)
2. Where to store persistent currency (character prefs? account system?)
3. How to render ship catalog images (TGUI interface needed)
4. Whether to keep parts system or replace with credits
5. How to handle ship unlocking (progression system needed)

The existing codebase provides a solid foundation for expansion, particularly:
- Ship template system is well-designed and extensible
- Spawning pipeline is robust and thread-safe
- Job slot system is flexible
- Faction system exists and works

Most of the requested features will require **new systems** rather than modifications to existing ones.

---

**Document prepared by: AI A**
**Date: 2025-11-23**
**Codebase explored: tg-voidcrew (own-your-ship branch)**
