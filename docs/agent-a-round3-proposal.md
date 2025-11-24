# AGENT A - ROUND 3 ARCHITECTURAL PROPOSAL
## Ship Purchase & Unlock System Redesign

**Date:** 2025-11-23
**Status:** Ready for Consensus Review

---

## EXECUTIVE SUMMARY

**Architecture Type:** Dual-Economy, Three-Tier Progression System

**Core Model:** `Credits → Parts → Permanent Unlocks`

**Key Architectural Decisions:**
1. ✅ **Unified Credits** (cross-faction meta-currency) + **Faction-Specific Parts** (NEU/NT-C/SYN-C)
2. ✅ **Parts shift from consumable to permanent unlock currency** (per user decision)
3. ✅ **Parallel antag system** (separate parts inventory, per-round consumable)
4. ✅ **Full map variant skins** (separate .dmm files, not palette swaps)
5. ✅ **Hybrid earning system** (round rewards + in-game discovery/crafting)
6. ✅ **Strict one-spawn-per-round** limit (destroyed ship = done for that round)

**Implementation:** 4-phase rollout over 16 weeks, each phase delivering working features

---

## PART 1: DEFINITIONS & ECONOMY MODEL

### 1.1 Currency System - "Credits"

**Definition:** Unified, cross-faction persistent meta-currency earned through gameplay.

**Data Structure:**
```dm
/datum/preferences
    var/ship_credits = 0  // Single unified currency, no faction restrictions
```

**Earning Methods (per user decisions):**

1. **Round Completion Rewards:**
   - Granted during `display_report()` (mirrors current part timing for anti-exploit)
   - Base reward: 100 credits per round
   - Scaled by participation (must play minimum 20 minutes)
   - No AFK farming

2. **In-Game Discovery:**
   - Lootable `/obj/item/credit_chip` items
   - Found in space ruins, derelicts, mission rewards
   - Various denominations (10/50/100/500 credits)
   - Use via `attack_self()` to redeem

3. **Crafting Byproduct:**
   - Successfully crafting ship parts grants +50 credit bonus
   - Encourages active gameplay (mining → crafting → rewards)
   - Ties into material economy

**Persistence:**
- Saved in `/datum/preferences` via JSON savefile system
- Loaded during `load_preferences()` (after fixing persistence bug)
- Cross-character if desired, or per-character (config option)

**Rationale:** Unified currency simplifies UX and economy balancing while faction-specific parts maintain progression trees.

---

### 1.2 Regular Parts System (Modified from Current)

**Definition:** Faction-specific components used to **permanently unlock ships** (no longer consumable).

**Types (preserve existing three factions):**
- **NEU parts** (Neutral faction) - `/obj/item/ship_parts/neutral`
- **NT-C parts** (Nanotrasen faction) - `/obj/item/ship_parts/nanotrasen`
- **SYN-C parts** (Syndicate faction) - `/obj/item/ship_parts/syndicate`

**Data Structure:**
```dm
/datum/preferences
    // Renamed from ships_owned for clarity
    var/list/ships_parts = list(
        /obj/item/ship_parts/neutral = 0,
        /obj/item/ship_parts/nanotrasen = 0,
        /obj/item/ship_parts/syndicate = 0,
    )

    // NEW: Permanent unlock tracking
    var/list/ships_unlocked = list()
    // Example value: list(/datum/map_template/shuttle/voidcrew/bogatyr = TRUE, ...)
```

**Acquisition Methods:**

1. **Purchase with Credits:**
   - In-game vendor or fabricator: "Ship Parts Vendor"
   - Pricing:
     - 500 credits → 1 NEU part
     - 750 credits → 1 NT-C part
     - 750 credits → 1 SYN-C part
   - Instant conversion (no crafting time for purchases)

2. **Crafting (per user decision - "find and craft parts"):**
   - Requires materials: plasteel, advanced circuits, plasma
   - Crafted at `/obj/machinery/ship_part_fabricator`
   - Time: 30-60 seconds depending on part type
   - Recipes vary by faction:
     - NEU: Common materials
     - NT-C: Requires bluespace crystals
     - SYN-C: Requires syndicate tech/blood
   - Bonus: +50 credits on successful craft

3. **Physical Discovery (preserve existing system):**
   - Lootable part items spawned in world
   - Spawners with weighted chances: 70% NEU, 20% NT-C, 10% SYN-C
   - Redeem via `attack_self()` (current behavior preserved)

4. **Round-End Rewards (optional, for backward compatibility):**
   - Keep current 1 random part grant
   - OR convert to credits-only over time
   - Design decision: transition period vs clean break

**Physical Trading System (PRESERVED - Agent B's Discovery):**
- 'N' keybind still converts digital parts → physical items
- Located in: `voidcrew/edits/keybindings.dm`
- Players can drop/trade physical parts between each other
- Creates emergent player-driven economy
- **This is critical social gameplay - must preserve**

**Usage Model (CRITICAL CHANGE from consumable):**
- Spending parts to unlock a ship **permanently unlocks that ship forever**
- Parts are deducted on unlock, but ship remains unlocked across all future rounds
- Example flow:
  - Player has 2 NEU parts
  - Unlocks Bogatyr-class (costs 2 NEU parts)
  - Parts reduced to 0
  - Bogatyr permanently added to `ships_unlocked` list
  - Every future round, can spawn Bogatyr for free (no additional parts needed)
  - One-spawn-per-round limit still applies

---

### 1.3 Antagonist Parts System (NEW)

**Definition:** Rare, special components used for **per-round antagonist ship purchases** (CONSUMABLE, not permanent unlocks).

**Types (expandable):**
- **Blood Cult Parts** - `/obj/item/ship_parts/antag/blood_cult`
- **Syndicate Ops Parts** - `/obj/item/ship_parts/antag/syndicate_ops`
- **Xenomorph Hive Parts** - `/obj/item/ship_parts/antag/xenomorph`
- (Framework supports adding more antag types)

**Data Structure:**
```dm
/datum/preferences
    var/list/antag_parts = list(
        /obj/item/ship_parts/antag/blood_cult = 0,
        /obj/item/ship_parts/antag/syndicate_ops = 0,
        /obj/item/ship_parts/antag/xenomorph = 0,
    )
```

**Acquisition Methods:**

1. **Purchase with Credits (Very Expensive):**
   - Cost: **5000 credits** → 1 antag part (10x regular part cost)
   - Only purchasable from:
     - Hidden/dangerous vendors in space
     - Syndicate uplink (for traitors)
     - Special events/missions
   - May require reputation or access codes

2. **Rare Drops:**
   - Extremely rare spawners (1% spawn rate, configurable)
   - Located in high-danger zones:
     - Abandoned cult temples
     - Syndicate outposts
     - Xenomorph nests
   - High-risk, high-reward

3. **Crafting (Restricted & Difficult):**
   - Requires rare/dangerous materials:
     - Blood Cult: dark matter, cult artifacts, human organs
     - Syndicate: syndicate tech items, plasma, uranium
     - Xenomorph: xenomorph resin, alien alloy, plasma
   - Only craftable at specific locations:
     - Cult altar for cult parts
     - Syndicate fabricator for syndicate parts
   - Crafting time: 120 seconds (2 minutes)
   - May require special tools or existing antag status

**Usage Model (CONSUMABLE per user decision):**
- Spending antag parts purchases antag ship **for current round only**
- Parts are **consumed** on purchase (not permanent unlock)
- Ship automatically deleted at round end
- Example flow:
  - Player has 1 Blood Cult Part
  - Purchases Blood Cult Vessel for current round
  - Part reduced to 0
  - Ship spawns, player converts to cultist
  - Round ends, ship deleted
  - Next round, player must spend another part to get antag ship again

**Why Consumable?**
- Antag ships are very powerful (convert to antag, special equipment)
- Permanent unlock would unbalance the game
- Scarcity maintains high stakes and special status
- Makes antag parts valuable trade commodities

---

### 1.4 Complete Economy Flow Diagram

```
═══════════════════════════════════════════════════════════════════
                        EARNING LAYER
═══════════════════════════════════════════════════════════════════

Round Completion ─────────────────┐
Finding Credit Chips ─────────────┤
Crafting Parts (bonus) ───────────┤──→ CREDITS (unified, persistent)
Trading with NPCs ────────────────┘

Finding Physical Parts ───────────┐
Round-End Part Grant ─────────────┤──→ PARTS (faction-specific, persistent)
Crafting from Materials ──────────┘

═══════════════════════════════════════════════════════════════════
                        CURRENCY LAYER
═══════════════════════════════════════════════════════════════════

CREDITS (unified, cross-faction)
    │
    ├──→ Spend at Vendors/Fabricators
    │       │
    │       ├──→ Buy Regular Parts (500-750 credits each)
    │       ├──→ Buy Antag Parts (5000 credits each)
    │       └──→ Buy Materials for Crafting
    │
    └──→ Saved in Preferences (persistent)

PARTS (faction-specific)
    │
    ├──→ Regular Parts (NEU / NT-C / SYN-C)
    │       └──→ Used for Permanent Ship Unlocks
    │
    └──→ Antag Parts (Cult / Syndicate / Xeno)
            └──→ Used for Per-Round Antag Ship Purchases

═══════════════════════════════════════════════════════════════════
                        UNLOCK LAYER
═══════════════════════════════════════════════════════════════════

Regular Parts ─────→ PERMANENT SHIP UNLOCK (one-time cost)
                         │
                         └──→ Added to ships_unlocked list
                              └──→ Persists forever

Antag Parts ───────→ PER-ROUND ANTAG SHIP (consumed)
                         │
                         └──→ Ship spawned for current round only
                              └──→ Deleted at round end

═══════════════════════════════════════════════════════════════════
                        SPAWNING LAYER
═══════════════════════════════════════════════════════════════════

Unlocked Regular Ship ──→ Spawn Once Per Round (FREE after unlock)
                              │
                              ├──→ No additional cost
                              ├──→ One-spawn-per-round limit
                              └──→ If destroyed, can't re-spawn

Antag Ship Purchase ────→ Spawn + Convert to Antag (CONSUMABLE)
                              │
                              ├──→ Costs 1 antag part
                              ├──→ Converts player to antagonist
                              ├──→ Provides antag equipment
                              └──→ One-spawn-per-round limit
```

---

## PART 2: PERSISTENCE & DATA ARCHITECTURE

### 2.1 Preferences Schema Extensions

**New Fields Added to `/datum/preferences`:**

```dm
/datum/preferences
    // ═══════ CURRENCY ═══════
    var/ship_credits = 0  // Unified meta-currency (cross-faction)

    // ═══════ REGULAR PARTS (modified from ships_owned) ═══════
    var/list/ships_parts = list(
        /obj/item/ship_parts/neutral = 0,
        /obj/item/ship_parts/nanotrasen = 0,
        /obj/item/ship_parts/syndicate = 0,
    )

    // ═══════ ANTAGONIST PARTS (new) ═══════
    var/list/antag_parts = list(
        /obj/item/ship_parts/antag/blood_cult = 0,
        /obj/item/ship_parts/antag/syndicate_ops = 0,
        /obj/item/ship_parts/antag/xenomorph = 0,
    )

    // ═══════ PERMANENT UNLOCKS (new) ═══════
    var/list/ships_unlocked = list()
    // Format: list(/datum/map_template/shuttle/voidcrew/bogatyr = TRUE, ...)
    // Boolean TRUE indicates unlocked status

    // ═══════ CUSTOMIZATIONS (new - Phase 4) ═══════
    var/list/ship_customizations = list()
    // Format: list(
    //     /datum/map_template/shuttle/voidcrew/bogatyr = list(
    //         "custom_name" = "SS Enterprise",
    //         "custom_job_slots" = list(...),
    //         "selected_skin" = /datum/ship_skin/bogatyr_red,
    //     )
    // )
```

### 2.2 Save/Load Implementation (FIXES PERSISTENCE BUG)

**File:** `voidcrew/modules/shuttle/ship_parts/user_prefs.dm`

**Save Proc (UPDATED):**
```dm
/datum/preferences/proc/save_ships()
    if(!savefile)
        return FALSE

    savefile.set_entry("ship_credits", ship_credits)
    savefile.set_entry("ships_parts", ships_parts)  // Renamed from ships_owned
    savefile.set_entry("antag_parts", antag_parts)
    savefile.set_entry("ships_unlocked", ships_unlocked)
    savefile.set_entry("ship_customizations", ship_customizations)

    return TRUE
```

**Load Proc (NEW - CRITICAL BUG FIX):**
```dm
/datum/preferences/proc/load_ships()
    if(!savefile)
        return FALSE

    // Load all ship-related data
    ship_credits = savefile.get_entry("ship_credits", 0)
    ships_parts = savefile.get_entry("ships_parts", ships_parts)
    antag_parts = savefile.get_entry("antag_parts", antag_parts)
    ships_unlocked = savefile.get_entry("ships_unlocked", list())
    ship_customizations = savefile.get_entry("ship_customizations", list())

    // Sanitize loaded data
    ship_credits = sanitize_integer(ship_credits, 0, 999999, 0)
    ships_parts = SANITIZE_LIST(ships_parts)
    antag_parts = SANITIZE_LIST(antag_parts)
    ships_unlocked = SANITIZE_LIST(ships_unlocked)
    ship_customizations = SANITIZE_LIST(ship_customizations)

    return TRUE
```

**Integration Point:**

**File:** `code/modules/client/preferences_savefile.dm`

**Modification to `load_preferences()` at line ~245:**
```dm
/datum/preferences/proc/load_preferences()
    // ... existing code ...

    // Custom hotkeys
    key_bindings = savefile.get_entry("key_bindings", key_bindings)

    // ═══════ ADD THIS CALL HERE ═══════
    load_ships()  // NEW: Load ship-related preferences
    // ═════════════════════════════════

    //try to fix any outdated data if necessary
    if(SHOULD_UPDATE_DATA(data_validity_integer))
        // ... existing migration code ...
```

**This FIXES Agent B's discovered critical bug** - ship parts/credits/unlocks will now persist across server restarts.

---

### 2.3 Migration Strategy

**Handling Old Data:**

**File:** `voidcrew/modules/shuttle/ship_parts/user_prefs.dm`

```dm
/datum/preferences/proc/migrate_legacy_ships_owned()
    // Check if old ships_owned exists (from broken system)
    var/list/legacy_owned = savefile.get_entry("ships_owned")

    if(!legacy_owned || !length(legacy_owned))
        return  // No legacy data to migrate

    // Migrate to new ships_parts
    if(!ships_parts || !length(ships_parts))
        ships_parts = legacy_owned

    // DESIGN DECISION: Should players get automatic unlocks?
    // Option A: Generous - if they had parts, unlock corresponding ships
    // Option B: Strict - parts carry over but no automatic unlocks
    // RECOMMENDATION: Option A (generous) due to broken system

    // Option A implementation (generous):
    for(var/part_type in ships_parts)
        var/part_count = ships_parts[part_type]
        if(part_count > 0)
            // Grant one basic ship unlock per faction if they had parts
            var/ship_to_unlock = get_starter_ship_for_faction(part_type)
            if(ship_to_unlock)
                ships_unlocked[ship_to_unlock] = TRUE

    // Clean up old entry
    savefile.remove_entry("ships_owned")
    save_ships()

    to_chat(usr, span_boldnotice("Your ship parts have been migrated to the new system!"))
```

---

### 2.4 Per-Round Tracking (Non-Persistent)

**File:** `code/modules/client/client.dm`

**Client Variables (reset each round):**
```dm
/client
    // Ship spawning tracking
    var/ship_spawned_this_round = FALSE  // Simple boolean for one-spawn limit
    var/obj/structure/overmap/ship/current_ship = null  // Reference to spawned ship
    var/ship_spawn_time = 0  // When ship was spawned (for analytics)
```

**Round Initialization:**

**File:** `code/controllers/subsystem/ticker.dm`

```dm
/datum/controller/subsystem/ticker/proc/setup_economy()
    for(var/client/C in GLOB.clients)
        C.ship_spawned_this_round = FALSE
        C.current_ship = null
        C.ship_spawn_time = 0
```

**Spawn Validation:**

**File:** `voidcrew/modules/ship_economy/spawn_validation.dm`

```dm
/client/proc/can_spawn_ship()
    if(ship_spawned_this_round)
        to_chat(src, span_warning("You have already spawned a ship this round!"))
        to_chat(src, span_notice("Your ship: [current_ship?.name || "Unknown"]. Spawned [get_time_since_spawn()] ago."))
        return FALSE
    return TRUE

/client/proc/get_time_since_spawn()
    if(!ship_spawn_time)
        return "Unknown"
    var/time_diff = world.time - ship_spawn_time
    return "[round(time_diff / (1 MINUTES))] minutes"
```

---

*(Continued in next message due to length - this is Part 1 of the full proposal)*
