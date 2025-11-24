# Ship Purchase System Redesign - Round 3: Architectural Proposals

**Part of:** [Ship System Redesign Master Index](ship-system-master-index.md)

## Document Navigation
- **Previous:** [Round 1-2: Analysis & Debates](ship-system-round1-2-analysis.md)
- **Next:** [User Decisions - Round 3.5](ship-system-user-decisions.md) → [Round 4: Consensus](ship-system-round4-consensus.md)
- **Related:** [Master Index](ship-system-master-index.md)

---

## Table of Contents
1. [Agent A's Proposal - Dual-Economy Three-Tier](#agent-as-proposal)
2. [Agent B's Proposal - Unified Currency with Legacy Conversion](#agent-bs-proposal)
3. [Agent C's Proposal - Database-First Architecture](#agent-cs-proposal)
4. [Agent D's Proposal](#agent-ds-proposal)

---

## Document Purpose

This document contains the detailed architectural proposals from all four agents, created AFTER user provided initial design constraints (Round 3 decisions). Each agent proposed complete system architectures incorporating:

- Three-tier progression (Credits → Parts → Blueprints)
- Crafting and discovery mechanics
- Antag ship system (per-round consumable)
- Full map variant skins
- TGUI catalog interface
- Implementation phases

**Important:** These proposals were made BEFORE the Round 3.5 user decisions that eliminated faction parts and mandated database persistence. See [User Decisions - Round 3.5](ship-system-user-decisions.md) for major changes that required proposal revisions in Round 4.

---
## Round 3: Proposed Solution Architecture

### Agent A's Proposal

**Full detailed proposal:** See `agent-a-round3-proposal.md` (separate file for full technical details)

**EXECUTIVE SUMMARY:**

**Architecture:** Dual-Economy, Three-Tier Progression (Credits → Parts → Permanent Unlocks)

**Core Model:**
- ✅ **Unified Credits** (meta-currency) + **Faction-Specific Parts** (NEU/NT-C/SYN-C)
- ✅ **Parts = Permanent Unlock Currency** (not consumable)
- ✅ **Parallel Antag System** (separate parts, per-round consumable)
- ✅ **One-Spawn-Per-Round** (destroyed = done)
- ✅ **Hybrid Earning** (round rewards + crafting/discovery)
- ✅ **Full Map Variant Skins** (separate .dmm files)

**KEY COMPONENTS:**

1. **Persistence (Phase 0 - Week 1):**
   - FIX: Add `load_ships()` proc to load preferences
   - New fields: `ship_credits`, `ships_parts`, `antag_parts`, `ships_unlocked`
   - Per-round tracking: `ship_spawned_this_round` boolean

2. **TGUI Catalog (Phase 1 - Weeks 2-4):**
   - Visual grid catalog with preview images
   - Dual tabs: Regular Ships | Antag Ships
   - Filters: faction, class, tier, unlock status
   - Detail modal with stats, jobs, skins

3. **Unlock System (Phase 2 - Weeks 5-8):**
   - Credits earned: round rewards (100+), loot chips, crafting bonus
   - Parts purchased: 500-750 credits (regular), 5000 credits (antag)
   - Unlocking: Spend parts → permanent unlock → free spawns forever
   - Validation: Check unlocks, check one-spawn limit

4. **Crafting (Phase 3 - Weeks 9-12):**
   - Fabricator: craft parts from materials (iron, plasma, bluespace)
   - Antag parts: rare materials, dangerous locations
   - Bonus credits on successful craft
   - Antag ships: per-round purchase, convert to antag on spawn

5. **Customization (Phase 4 - Weeks 13-16):**
   - Ship skins: full .dmm variants
   - Crew customization: modify job slots pre-spawn
   - Ship naming, loadout selection

**INTEGRATION:**
- Latejoin hijack preserved (TGUI replaces BYOND dialog)
- Ship creation pipeline unchanged (`SSshuttle.create_ship`)
- Thread safety maintained (`shuttle_loading` mutex, SSair management)
- Physical trading preserved (N key: digital → physical parts)
- Job assembly extended for customizations

**PHASED DELIVERY:**
- Phase 0: Bug fix (1 week) → Persistence works
- Phase 1: TGUI catalog (3 weeks) → Visual browsing
- Phase 2: Economy (4 weeks) → Full unlock system
- Phase 3: Crafting/antag (4 weeks) → Complete features
- Phase 4: Customization (4 weeks) → Polish

**TOTAL: 16 weeks (4 months)**

**TRADEOFFS:**
- ✅ Preserves infrastructure, clear progression, phased risk reduction
- ⚠️ Three-tier economy complexity, dual catalog UI, high content creation for skins

**ANSWERS TO CLARIFICATIONS:**
- Currency = Credits (unified); Parts = Faction-specific unlock currency
- Antag parts = separate inventory, consumable, very expensive (5000 credits)
- Crafting = materials from mining, at fabricators, both regular + antag parts
- Antag flow = no unlock needed, pay per-round, one-spawn limit applies

**READY FOR CONSENSUS**

### Agent B's Proposal

**ARCHITECTURE: Three-Tier Progression with Dual Ship Systems**

Incorporating all user decisions, I propose a modular architecture that keeps parts but shifts them from consumable to permanent unlock currency, adds a unified meta-currency layer, and implements dual ship systems (regular permanent + antag per-round).

---

## I. EXECUTIVE SUMMARY

**Core Progression Flow:**
```
Gameplay → Ship Credits (unified currency) → Ship Parts (faction-specific) → Permanent Ship Unlocks → One Spawn Per Round
                                           ↓
                                    Antag Parts (rare/expensive) → Per-Round Antag Ships → Auto-Antagonist Conversion
```

**Key Architectural Principles:**
- ✅ Three-tier economy (credits → parts → unlocks) per user decision
- ✅ Preserve existing systems (faction parts, physical trading, thread safety)
- ✅ Dual ship models (permanent regular + consumable antag)
- ✅ Hybrid earning (passive + active)
- ✅ Full map variants (separate .dmm files per skin)
- ✅ JSON persistence for MVP (DB migration path documented)
- ✅ Phased implementation (6 phases, ~20 weeks)

---

## II. CURRENCY & PARTS SYSTEM DEFINITION

### Definition 1: What is "Currency"?

**Ship Credits** - A unified, cross-faction meta-currency

**Properties:**
- Name: "Ship Credits" (SC)
- Cross-faction: NOT faction-specific, universal
- Persistent: Saved in player preferences JSON
- Earnable via:
  - Round completion rewards (passive, ~100-500 per round)
  - Finding credit tokens in-game (active, 100-5000 per token)
  - Selling items/resources (active, configurable)
  - Crafting and selling parts (active)

**Storage:**
```dm
/datum/preferences
    var/ship_credits = 0  // Universal currency
```

**Why unified?** Simplifies player understanding, flexible spending, easier economy balancing, aligns with "currency can buy parts" user decision.

### Definition 2: What are "Parts"?

**Faction-Specific Permanent Unlock Tokens**

**Keep current system MODIFIED:**
- NEU Parts (Neutral faction)
- NT-C Parts (Nanotrasen faction)
- SYN-C Parts (Syndicate faction)
- **NEW:** Antag Parts (separate subsystem, detailed below)

**Changed Behavior:**
- **OLD:** Consumable (spend 2 NEU parts each time you spawn Bogatyr)
- **NEW:** Permanent unlock currency (spend 2 NEU parts ONCE to unlock Bogatyr forever)

**Obtainable via:**
- Purchase with ship credits (currency → parts conversion)
- Crafting at fabricators (materials → parts)
- Finding in-game (loot spawners)
- Round-end rewards (1 random part, preserve existing system)

**Storage:**
```dm
/datum/preferences
    // Regular parts (for permanent unlocks)
    var/list/ship_parts_inventory = list(
        /obj/item/ship_parts/neutral = 0,
        /obj/item/ship_parts/nanotrasen = 0,
        /obj/item/ship_parts/syndicate = 0,
    )
```

**Why faction-specific?** Preserves game balance, creates progression trees, physical trading still works, user decision implies parts remain central.

### Definition 3: Regular Parts vs Antag Parts

**Regular Parts:**
- Purpose: Permanent ship unlocks
- Consumption: Non-consumable (spend once, own forever)
- Earning: Credits, crafting, finding, round-end
- Rarity: Common (accumulate over time)
- Trading: Yes via N key

**Antag Parts:**
- Purpose: Per-round antag ship purchases
- Consumption: CONSUMABLE (spent each purchase)
- Earning: Rare drops, expensive credit purchases, admin grants
- Rarity: Super rare/expensive
- Types: Faction-specific to antag (Syndicate Ops, Blood Cult, Xenomorph, etc.)
- Trading: Yes via N key (but very rare)

**Separate Inventories:**
```dm
/datum/preferences
    var/list/antag_parts_inventory = list(
        /obj/item/ship_parts/antag/syndicate_ops = 0,
        /obj/item/ship_parts/antag/blood_cult = 0,
        /obj/item/ship_parts/antag/xenomorph_hive = 0,
    )
```

---

## III. CORE ARCHITECTURAL COMPONENTS

### Component 1: Currency & Parts Economy Manager
**Location:** `voidcrew/modules/ship_economy/`

**Files:**
- `ship_credits.dm` - Credit earning, display, transactions
- `ship_parts_conversion.dm` - Credit → part exchange
- `part_items.dm` - Physical part items (extends existing)
- `economy_config.dm` - Exchange rates, costs

**Responsibilities:**
- Earn ship credits (round-end, finding, selling)
- Convert credits to parts at exchange rate
- Manage part inventories
- Physical part withdrawal (N key - existing)
- Balance tuning

**Key New Procs:**
```dm
/client/proc/earn_ship_credits(amount, reason)
    prefs.ship_credits += amount
    to_chat(src, "<span class='notice'>+[amount] SC: [reason]</span>")
    prefs.save_ship_economy()

/client/proc/buy_ship_part(part_type, cost_credits)
    if(prefs.ship_credits < cost_credits)
        return FALSE
    prefs.ship_credits -= cost_credits
    prefs.ship_parts_inventory[part_type]++
    prefs.save_ship_economy()
    to_chat(src, "<span class='notice'>Purchased 1x [part_type] for [cost_credits] SC</span>")
    return TRUE

/client/proc/withdraw_credit_token(amount)
    if(prefs.ship_credits < amount)
        return FALSE
    prefs.ship_credits -= amount
    var/obj/item/ship_credit_token/token = new(mob.loc)
    token.credit_value = amount
    prefs.save_ship_economy()
    return TRUE
```

**Exchange Rates (tunable):**
- 500 SC = 1 NEU part
- 750 SC = 1 NT-C part
- 750 SC = 1 SYN-C part
- 5000 SC = 1 Antag part (very expensive)

### Component 2: Ship Unlock Manager
**Location:** `voidcrew/modules/ship_unlocks/`

**Files:**
- `unlock_manager.dm` - Core unlock logic
- `unlock_persistence.dm` - Save/load unlocked ships
- `unlock_requirements.dm` - Cost validation

**Responsibilities:**
- Track which ships player has unlocked permanently
- Validate unlock requirements (parts available, not already unlocked)
- Process unlock purchases (deduct parts, add to unlocked list)
- Prevent duplicate unlocks
- Handle unlock UI interactions

**New Datum:**
```dm
/datum/ship_unlock_manager
    var/client/owner

    proc/is_unlocked(ship_template)
        return (ship_template.type in owner.prefs.ships_unlocked)

    proc/can_unlock(ship_template)
        // Already unlocked?
        if(is_unlocked(ship_template))
            return FALSE
        // Check parts available
        var/faction = initial(ship_template.faction_prefix)
        var/cost = initial(ship_template.unlock_cost)
        var/part_type = get_part_type_for_faction(faction)
        return (owner.prefs.ship_parts_inventory[part_type] >= cost)

    proc/unlock_ship(ship_template)
        if(!can_unlock(ship_template))
            return FALSE
        // Deduct parts
        var/faction = initial(ship_template.faction_prefix)
        var/cost = initial(ship_template.unlock_cost)
        var/part_type = get_part_type_for_faction(faction)
        owner.prefs.ship_parts_inventory[part_type] -= cost
        // Add to unlocked
        owner.prefs.ships_unlocked += ship_template.type
        owner.prefs.save_ship_economy()
        to_chat(owner, "<span class='notice'>Permanently unlocked: [initial(ship_template.name)]!</span>")
        return TRUE
```

### Component 3: TGUI Ship Catalog
**Location:** `tgui/packages/tgui/interfaces/ShipCatalog/`

**Files:**
- `ShipCatalog.tsx` - Main catalog component
- `ShipCard.tsx` - Individual ship display
- `ShipPreview.tsx` - Image preview with variants
- `RegularShipsTab.tsx` - Permanent unlock ships tab
- `AntagShipsTab.tsx` - Per-round antag ships tab
- `ResourceDisplay.tsx` - Show credits, parts inventory

**Features:**
- Grid/list view toggle
- Locked/unlocked status indicators
- Ship preview images (per variant)
- Ship stats (crew size, faction, description)
- Unlock cost display
- Purchase unlock button (for locked ships)
- Spawn button with variant selection (for unlocked ships)
- Filter by faction/status
- Search by name
- Sort by cost/name/crew size

**UI Layout:**
```
┌────────────────────────────────────────────────────────────┐
│ SHIP CATALOG                    [Credits: 5000 SC]         │
│ ┌──────────┬──────────┐                                    │
│ │ Regular  │  Antag   │  [Search: ___] [Filter: All ▼]    │
│ └──────────┴──────────┘                                    │
│                                                             │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│ │  Bogatyr     │ │    Delta     │ │     Box      │        │
│ │  [PREVIEW]   │ │  [PREVIEW]   │ │  [PREVIEW]   │        │
│ │  ✓ Unlocked  │ │  🔒 Locked   │ │  ✓ Unlocked  │        │
│ │  NEU • 10ppl │ │  NEU • 9ppl  │ │  NEU • 9ppl  │        │
│ │              │ │  Needs:      │ │              │        │
│ │  Variants:   │ │  3 NEU parts │ │  Variants:   │        │
│ │  • Default   │ │  (1500 SC)   │ │  • Default   │        │
│ │  • Industrial│ │              │ │              │        │
│ │  [SPAWN ▼]   │ │  [UNLOCK]    │ │  [SPAWN]     │        │
│ └──────────────┘ └──────────────┘ └──────────────┘        │
│                                                             │
│ Your Parts: NEU: 5 | NT-C: 2 | SYN-C: 1                   │
│ Your Antag Parts: SYN-OPS: 0 | CULT: 1 | XENO: 0          │
└────────────────────────────────────────────────────────────┘
```

**TGUI Data Interface:**
```typescript
interface ShipCatalogData {
  player_credits: number;
  player_parts: Record<string, number>;
  player_antag_parts: Record<string, number>;
  ships_unlocked: string[];
  has_spawned_this_round: boolean;
  regular_ships: RegularShip[];
  antag_ships: AntagShip[];
}

interface RegularShip {
  template_type: string;
  name: string;
  faction: string;
  unlock_cost_parts: number;
  unlock_cost_credits: number; // For display (parts × exchange rate)
  preview_image: string;
  crew_capacity: number;
  description: string;
  variants: ShipVariant[];
  is_unlocked: boolean;
}

interface AntagShip {
  template_type: string;
  name: string;
  antag_type_name: string; // "Nuclear Operative", "Blood Cultist"
  cost_antag_parts: number;
  cost_credits: number; // For buying antag parts
  preview_image: string;
  description: string;
  variants: ShipVariant[];
}

interface ShipVariant {
  name: string; // "Default", "Industrial", "Luxury"
  preview_image: string;
  map_file: string;
}
```

**TGUI Actions:**
```typescript
// Purchase permanent unlock
act('unlock_ship', {
  template: '/datum/map_template/shuttle/voidcrew/bogatyr'
});

// Spawn unlocked ship with variant
act('spawn_ship', {
  template: '/datum/map_template/shuttle/voidcrew/bogatyr',
  variant: 'industrial'
});

// Purchase antag ship (per-round)
act('purchase_antag_ship', {
  template: '/datum/map_template/shuttle/voidcrew/antag/syndicate_ops'
});

// Buy parts with credits
act('buy_part', {
  part_type: '/obj/item/ship_parts/neutral',
  quantity: 2
});
```

### Component 4: Extended Ship Templates
**Location:** `voidcrew/mapping/shuttles/_shuttle.dm`

**Template Extensions:**
```dm
/datum/map_template/shuttle/voidcrew
    // EXISTING
    var/faction_prefix = NEUTRAL_SHIP
    var/short_name
    var/part_cost = 1  // DEPRECATED for regular ships
    var/list/job_slots = list()

    // NEW: Unlock system
    var/unlock_cost = 2  // Parts required to PERMANENTLY unlock
    var/preview_image = "bogatyr_preview.png"  // Asset path for catalog
    var/description = "A versatile exploration vessel capable of long-range missions."
    var/crew_capacity = 10  // For display
    var/ship_tier = 1  // Optional progression gating

    // NEW: Map variants (skins)
    var/list/map_variants = list(
        "default" = "ship_bogatyr.dmm",
        "industrial" = "ship_bogatyr_industrial.dmm",
        "luxury" = "ship_bogatyr_luxury.dmm",
    )

    // NEW: Antag ship properties
    var/is_antag_ship = FALSE
    var/antag_type = null  // /datum/antagonist/nukeop
    var/antag_part_type = null  // /obj/item/ship_parts/antag/syndicate_ops
    var/antag_part_cost = 1  // Consumable cost per purchase
    var/list/antag_equipment = list()  // Starting gear
```

**Regular Ship Example:**
```dm
/datum/map_template/shuttle/voidcrew/bogatyr
    name = "Bogatyr-class Explorator"
    short_name = "Bogatyr-class"
    faction_prefix = NEUTRAL_SHIP
    unlock_cost = 2  // 2 NEU parts to unlock permanently
    preview_image = "bogatyr_preview.png"
    description = "A sturdy exploration vessel equipped for long-range missions and resource gathering."
    crew_capacity = 10

    map_variants = list(
        "default" = "ship_bogatyr.dmm",
        "industrial" = "ship_bogatyr_industrial.dmm",
    )

    job_slots = list(
        list("name" = "Captain", "officer" = TRUE, ...),
        list("name" = "Scientist", ...),
        list("name" = "Miner", "slots" = 2, ...),
        // etc.
    )
```

**Antag Ship Example:**
```dm
/datum/map_template/shuttle/voidcrew/antag/syndicate_ops_cruiser
    name = "Syndicate Strike Cruiser"
    faction_prefix = SYNDICATE_SHIP
    is_antag_ship = TRUE
    antag_type = /datum/antagonist/nukeop
    antag_part_type = /obj/item/ship_parts/antag/syndicate_ops
    antag_part_cost = 1  // Costs 1 SYN-OPS antag part per round
    unlock_cost = 0  // No permanent unlock - always per-round

    description = "A heavily armed Syndicate vessel designed for strike operations. Spawning aboard converts you to a Nuclear Operative."
    preview_image = "syndicate_ops_cruiser_preview.png"

    antag_equipment = list(
        /obj/item/gun/ballistic/automatic/ar,
        /obj/item/pinpointer/nuke,
        /obj/item/clothing/suit/space/hardsuit/syndi,
        /obj/item/tank/internals/emergency_oxygen/double,
    )

    job_slots = list(
        list("name" = "Syndicate Commander", "outfit" = /datum/outfit/syndicate/commander, ...),
        list("name" = "Syndicate Operative", "slots" = 4, ...),
    )
```

### Component 5: Crafting System
**Location:** `voidcrew/modules/ship_economy/crafting/`

**Files:**
- `part_fabricator.dm` - Fabricator machine
- `crafting_recipes.dm` - Part recipes
- `loot_spawners.dm` - Credit/part spawners

**Ship Part Fabricator Machine:**
```dm
/obj/machinery/ship_part_fabricator
    name = "ship part fabricator"
    desc = "Converts raw materials and components into ship construction parts. Used for building new vessels."
    icon = 'icons/obj/machines/research.dmi'
    icon_state = "protolathe"

    var/list/materials_stored = list()
    var/list/available_recipes = list()
    var/currently_crafting = null
    var/craft_time_remaining = 0

    proc/can_craft(datum/crafting_recipe/ship_part/recipe)
        for(var/material_type in recipe.requirements)
            if(materials_stored[material_type] < recipe.requirements[material_type])
                return FALSE
        return TRUE

    proc/start_craft(datum/crafting_recipe/ship_part/recipe, mob/user)
        if(!can_craft(recipe))
            to_chat(user, "<span class='warning'>Insufficient materials!</span>")
            return FALSE
        // Consume materials
        for(var/material_type in recipe.requirements)
            materials_stored[material_type] -= recipe.requirements[material_type]
        currently_crafting = recipe
        craft_time_remaining = recipe.crafting_time
        visible_message("<span class='notice'>[src] begins fabricating [recipe.name]...</span>")
        addtimer(CALLBACK(src, PROC_REF(finish_craft)), recipe.crafting_time)
        return TRUE

    proc/finish_craft()
        if(!currently_crafting)
            return
        var/datum/crafting_recipe/ship_part/recipe = currently_crafting
        new recipe.result_type(get_turf(src))
        visible_message("<span class='notice'>[src] dispenses a completed [recipe.name].</span>")
        currently_crafting = null
```

**Crafting Recipes:**
```dm
/datum/crafting_recipe/ship_part
    var/result_type
    var/crafting_time = 30 SECONDS
    var/list/requirements = list()

/datum/crafting_recipe/ship_part/neutral
    name = "Neutral Ship Part"
    result_type = /obj/item/ship_parts/neutral
    crafting_time = 30 SECONDS
    requirements = list(
        /obj/item/stack/sheet/metal = 50,
        /obj/item/stack/sheet/glass = 20,
        /obj/item/stack/sheet/plasteel = 10,
    )

/datum/crafting_recipe/ship_part/nanotrasen
    name = "Nanotrasen Ship Part"
    result_type = /obj/item/ship_parts/nanotrasen
    crafting_time = 45 SECONDS
    requirements = list(
        /obj/item/stack/sheet/metal = 50,
        /obj/item/stack/sheet/glass = 20,
        /obj/item/stack/sheet/plasteel = 10,
        /obj/item/circuitboard/nanotrasen = 1,  // Rare NT-specific component
    )

/datum/crafting_recipe/ship_part/syndicate
    name = "Syndicate Ship Part"
    result_type = /obj/item/ship_parts/syndicate
    crafting_time = 45 SECONDS
    requirements = list(
        /obj/item/stack/sheet/metal = 50,
        /obj/item/stack/sheet/glass = 20,
        /obj/item/stack/sheet/plasteel = 10,
        /obj/item/assembly/signaler/syndicate = 1,  // Rare SYN-specific component
    )

// NOTE: Antag parts NOT craftable - too exploitable
```

**Loot Spawners:**
```dm
/obj/item/ship_credit_token
    name = "ship credit chip"
    desc = "A secure data chip containing transferable ship construction credits."
    icon = 'icons/obj/economy.dmi'
    icon_state = "credit_chip"
    var/credit_value = 100

    attack_self(mob/user)
        if(!user.client)
            return
        user.client.earn_ship_credits(credit_value, "redeemed credit chip")
        to_chat(user, "<span class='notice'>You redeem [src] for [credit_value] ship credits!</span>")
        qdel(src)

/obj/item/ship_credit_token/small
    credit_value = 100

/obj/item/ship_credit_token/medium
    credit_value = 500

/obj/item/ship_credit_token/large
    credit_value = 1000

/obj/item/ship_credit_token/jackpot
    credit_value = 5000

/obj/effect/spawner/random/ship_economy
    loot = list(
        /obj/item/ship_credit_token/small = 40,
        /obj/item/ship_credit_token/medium = 30,
        /obj/item/ship_parts/neutral = 15,
        /obj/item/ship_parts/nanotrasen = 10,
        /obj/item/ship_parts/syndicate = 4,
        /obj/item/ship_parts/antag/syndicate_ops = 1,  // SUPER RARE
    )
```

### Component 6: Per-Round Spawn Tracking
**Location:** `voidcrew/modules/ship_unlocks/spawn_tracking.dm`

**Per-Round State (NOT saved):**
```dm
/client
    var/has_spawned_ship_this_round = FALSE  // Resets each round
    var/spawned_ship_template = null  // Track which ship they spawned

/datum/controller/subsystem/ticker/proc/initialize_round()
    . = ..()
    for(var/client/C in GLOB.clients)
        C.has_spawned_ship_this_round = FALSE
        C.spawned_ship_template = null
```

**Spawn Validation:**
```dm
/mob/dead/new_player/proc/can_spawn_ship(ship_template)
    // Check spawn limit
    if(client.has_spawned_ship_this_round)
        tgui_alert(src, "You have already spawned a ship this round. If your ship was destroyed, you cannot spawn another until next round.", "Spawn Limit Reached")
        return FALSE

    // Regular ships: check unlocked
    if(!ship_template.is_antag_ship)
        if(!(ship_template.type in client.prefs.ships_unlocked))
            tgui_alert(src, "You have not unlocked this ship yet. Purchase the unlock with ship parts first.", "Ship Locked")
            return FALSE

    // Antag ships: check and consume antag parts
    else
        var/cost = initial(ship_template.antag_part_cost)
        var/part_type = initial(ship_template.antag_part_type)
        if(client.prefs.antag_parts_inventory[part_type] < cost)
            tgui_alert(src, "You lack the required antag parts! Need: [cost]x [part_type.name]", "Insufficient Antag Parts")
            return FALSE
        // Deduct antag parts (CONSUMABLE)
        client.prefs.antag_parts_inventory[part_type] -= cost
        client.prefs.save_ship_economy()
        to_chat(src, "<span class='warning'>You spend [cost]x [part_type.name] to purchase this antag ship for this round.</span>")

    return TRUE
```

### Component 7: Antagonist Conversion System
**Location:** `voidcrew/modules/ship_unlocks/antag_conversion.dm`

**Conversion on Antag Ship Spawn:**
```dm
/mob/dead/new_player/proc/convert_to_antagonist(antag_datum_type)
    // Create antagonist datum
    var/datum/antagonist/antag = new antag_datum_type()

    // Assign to player's mind
    mind.add_antag_datum(antag)

    // Antag-specific setup
    antag.on_gain(mind)

    // Announce
    to_chat(src, "<span class='userdanger bold'>You are now a [antag.name]!</span>")
    to_chat(src, "<span class='notice'>[antag.role_text]</span>")
    to_chat(src, "<span class='notice'>[antag.objectives_text]</span>")

    // Send antag greeting
    antag.greet()

/mob/dead/new_player/proc/give_antag_equipment(ship_template)
    // Wait for character creation
    if(!mind.current)
        return

    // Equip starting gear
    for(var/item_type in ship_template.antag_equipment)
        var/obj/item/I = new item_type(mind.current)
        if(!mind.current.equip_to_appropriate_slot(I))
            mind.current.put_in_hands(I)

/mob/dead/new_player/proc/spawn_on_antag_ship(ship_template, variant="default")
    // Create ship
    var/obj/structure/overmap/ship/new_ship = SSshuttle.create_ship(ship_template, variant)

    // Convert to antagonist
    convert_to_antagonist(ship_template.antag_type)

    // Mark as spawned
    client.has_spawned_ship_this_round = TRUE
    client.spawned_ship_template = ship_template.type

    // Spawn player as first job (usually leader)
    AttemptSpawnOnShip(new_ship.job_slots[1], new_ship)

    // Give equipment after spawn
    addtimer(CALLBACK(src, PROC_REF(give_antag_equipment), ship_template), 1 SECOND)

    return TRUE
```

**Antag Types:**
- Nuclear Operatives (Syndicate Ops ship)
- Blood Cultists (Blood Cult ship)
- Xenomorphs (Xenomorph Hive ship)
- Revolutionaries (possible future)
- Clockwork Cultists (possible future)

### Component 8: Ship Variant (Skin) System
**Location:** `voidcrew/modules/ship_variants/`

**Variant Selection in Catalog:**
When player clicks "SPAWN" on unlocked ship, show variant dropdown if multiple variants exist.

**Variant Loading:**
```dm
/datum/controller/subsystem/shuttle/proc/create_ship(datum/map_template/shuttle/voidcrew/template, variant="default")
    // Get variant map file
    var/map_file = template.map_variants[variant]
    if(!map_file)
        map_file = template.map_variants["default"]
        log_runtime("Invalid variant '[variant]' for [template.name], using default")

    // Temporarily override suffix for loading
    var/original_suffix = template.suffix
    template.suffix = map_file

    // Standard ship creation pipeline (existing code)
    shuttle_loading = TRUE
    SSair.can_fire = FALSE

    var/obj/structure/overmap/ship/new_ship = new /obj/structure/overmap/ship(SSovermap.get_unused_overmap_square(), template)
    var/obj/docking_port/mobile/voidcrew/loaded = action_load(template)

    SSair.can_fire = TRUE
    shuttle_loading = FALSE

    // Link and finalize
    loaded.current_ship = new_ship
    new_ship.shuttle = loaded
    new_ship.display_name = template.short_name
    SEND_SIGNAL(new_ship, COMSIG_VOIDCREW_SHIP_LOADED, new_ship)

    // Restore original suffix
    template.suffix = original_suffix

    return new_ship
```

**Map Variant File Structure:**
```
_maps/voidcrew/ships/
  ├── ship_bogatyr.dmm                  (default)
  ├── ship_bogatyr_industrial.dmm       (industrial skin)
  ├── ship_bogatyr_luxury.dmm           (luxury skin)
  ├── ship_delta.dmm                    (default)
  ├── ship_delta_military.dmm           (military skin)
  ├── ship_delta_cargo.dmm              (cargo hauler skin)
  └── ... (30+ ships × 2-3 variants each)
```

Each .dmm file is a COMPLETE map with different layouts, aesthetics, equipment placement.

---

## IV. PERSISTENCE & DATA FLOW

### Persistence Layer (JSON Savefile)

**Extended /datum/preferences:**
```dm
/datum/preferences
    // CURRENCY (new)
    var/ship_credits = 0

    // REGULAR PARTS (modified)
    var/list/ship_parts_inventory = list(
        /obj/item/ship_parts/neutral = 0,
        /obj/item/ship_parts/nanotrasen = 0,
        /obj/item/ship_parts/syndicate = 0,
    )

    // ANTAG PARTS (new)
    var/list/antag_parts_inventory = list(
        /obj/item/ship_parts/antag/syndicate_ops = 0,
        /obj/item/ship_parts/antag/blood_cult = 0,
        /obj/item/ship_parts/antag/xenomorph_hive = 0,
    )

    // UNLOCKED SHIPS (new)
    var/list/ships_unlocked = list()  // List of template type paths

    // CUSTOMIZATIONS (future Phase 3+)
    var/list/ship_customizations = list()

// SAVE
/datum/preferences/proc/save_ship_economy()
    savefile.set_entry("ship_credits", ship_credits)
    savefile.set_entry("ship_parts_inventory", ship_parts_inventory)
    savefile.set_entry("antag_parts_inventory", antag_parts_inventory)
    savefile.set_entry("ships_unlocked", ships_unlocked)
    savefile.set_entry("ship_customizations", ship_customizations)
    savefile.save()

// LOAD (FIX THE BUG!)
/datum/preferences/proc/load_preferences()
    // ... existing loads (lastchangelog, be_special, key_bindings, etc.) ...

    // NEW: Load ship economy data (THIS WAS MISSING - THE BUG)
    ship_credits = savefile.get_entry("ship_credits", ship_credits)
    ship_parts_inventory = savefile.get_entry("ship_parts_inventory", ship_parts_inventory)
    antag_parts_inventory = savefile.get_entry("antag_parts_inventory", antag_parts_inventory)
    ships_unlocked = savefile.get_entry("ships_unlocked", ships_unlocked)
    ship_customizations = savefile.get_entry("ship_customizations", ship_customizations)
```

**JSON File Example:**
```json
{
  "version": 49,
  "ship_credits": 5000,
  "ship_parts_inventory": {
    "/obj/item/ship_parts/neutral": 5,
    "/obj/item/ship_parts/nanotrasen": 2,
    "/obj/item/ship_parts/syndicate": 1
  },
  "antag_parts_inventory": {
    "/obj/item/ship_parts/antag/syndicate_ops": 0,
    "/obj/item/ship_parts/antag/blood_cult": 1,
    "/obj/item/ship_parts/antag/xenomorph_hive": 0
  },
  "ships_unlocked": [
    "/datum/map_template/shuttle/voidcrew/bogatyr",
    "/datum/map_template/shuttle/voidcrew/delta",
    "/datum/map_template/shuttle/voidcrew/box"
  ],
  "ship_customizations": {}
}
```

### Complete Data Flow Examples

**Flow 1: Round-End Rewards**
```dm
/datum/controller/subsystem/ticker/display_report(popcount)
    . = ..()
    for(var/client/C in GLOB.clients)
        // Give ship credits (new)
        var/base_credits = 100
        var/time_played = (world.time - SSticker.round_start_time) / (1 MINUTE)
        var/time_bonus = time_played * 5  // 5 credits per minute
        C.earn_ship_credits(base_credits + time_bonus, "round completion")

        // Give random part (existing, preserve)
        C.give_random_ship_part()
```

**Flow 2: Finding Credits**
Player finds credit token → Uses in hand → Redeems credits → Saved to preferences

**Flow 3: Unlocking Ship**
```
Player opens catalog (TGUI) → Views locked ship → Clicks "UNLOCK"
   ↓
TGUI act('unlock_ship', {template: "..."})
   ↓
/datum/ship_unlock_manager/unlock_ship(client, template)
   - Validate parts available
   - Deduct parts from inventory
   - Add to ships_unlocked list
   - Save preferences
   - Update catalog UI
```

**Flow 4: Spawning Ship**
```
Player selects unlocked ship → Chooses variant → Clicks "SPAWN"
   ↓
TGUI act('spawn_ship', {template: "...", variant: "industrial"})
   ↓
/mob/dead/new_player/spawn_on_ship(template, variant)
   - Check has_spawned_ship_this_round (FALSE)
   - Check template in ships_unlocked (TRUE)
   - Create ship with variant map file
   - Mark has_spawned_ship_this_round = TRUE
   - Spawn player as captain
```

**Flow 5: Purchasing Antag Ship**
```
Player opens catalog → Antag tab → Clicks "PURCHASE"
   ↓
TGUI act('purchase_antag_ship', {template: "..."})
   ↓
/mob/dead/new_player/spawn_on_antag_ship(template, variant)
   - Check has_spawned_ship_this_round (FALSE)
   - Check antag_parts_inventory[type] >= cost
   - Deduct antag parts (CONSUMABLE)
   - Create ship
   - Convert to antagonist
   - Give equipment
   - Mark has_spawned_ship_this_round = TRUE
```

---

## V. INTEGRATION WITH EXISTING SYSTEMS

**Latejoin Hijack:** Preserve existing override - catalog replaces latejoin menu
**Thread Safety:** Maintain `shuttle_loading` mutex and SSair patterns
**Signal Hooks:** Leverage COMSIG_VOIDCREW_SHIP_LOADED for stats/tracking
**Ship Bank Accounts:** Separate from player credits (no interaction)
**Physical Trading:** Extended - N key can withdraw parts OR credit tokens
**Job System:** Use existing `assemble_job_slots()` - no changes needed
**Template System:** Extended with new vars - backward compatible

---

## VI. TRADEOFFS & DESIGN ANALYSIS

### Advantages:
✅ **Preserves existing mechanics** - Physical trading, faction parts, thread safety all maintained
✅ **Flexible progression** - Three paths (credits, parts, unlocks) give player choice
✅ **Dual ship systems** - Regular (permanent) + antag (consumable) clearly separated
✅ **Scalable** - JSON for MVP (<100 players), DB migration path documented
✅ **Player agency** - Choose unlocks, variants, trading options
✅ **Active + passive earning** - Rewards engagement without requiring it

### Disadvantages:
❌ **Complexity** - Three-tier economy adds cognitive load
❌ **Massive scope** - ~20 weeks development across 6 phases
❌ **Content burden** - Map variants require 90+ .dmm files
❌ **Harsh one-spawn limit** - Could frustrate players
❌ **Balance nightmare** - Many tuning knobs (exchange rates, costs, earning rates)
❌ **Two parallel part systems** - Regular vs antag could confuse

### Open Questions Requiring User Input:
1. **Credit Earning Rates:** 100/round? 500/round?
2. **Exchange Rates:** 1 part = 500 credits? 1000?
3. **Unlock Costs:** Starter ships 1-2 parts, advanced 3-5?
4. **Antag Part Rarity:** How rare is "super rare"? 1% drop chance?
5. **Insurance System:** Future mitigation for one-spawn harshness?
6. **Antag Ship Limits:** Can multiple players buy antag ships same round?

---

## VII. PHASED IMPLEMENTATION PLAN

### Phase 0: Bug Fix & Foundation (1-2 weeks)
**Tasks:**
- Fix ships_owned load bug (add to `load_preferences()`)
- Add new fields: `ship_credits`, `ships_unlocked`, `antag_parts_inventory`
- Implement save/load for new fields
- Add migration logic for existing players
- Test save/load cycle thoroughly

**Deliverable:** Persistence layer functional

### Phase 1: Currency & Basic Unlock System (2-3 weeks)
**Tasks:**
- Ship credits earning (round-end, finding tokens)
- Credit → part conversion
- Part → ship unlock (permanent, not consumable)
- Extend ship templates with new vars
- Per-round spawn tracking
- Modify existing purchase flow to check `ships_unlocked`
- Keep old parts system functional (legacy compatibility)

**Testing:** Earn credits, buy parts, unlock ships, spawn once per round

**Deliverable:** Backend unlock system works via console commands

### Phase 2: TGUI Ship Catalog (3-4 weeks)
**Tasks:**
- Create React components (ShipCatalog, ShipCard, etc.)
- Grid/list view with locked/unlocked status
- Ship stats, costs, descriptions
- Placeholder preview images (temp assets)
- Unlock purchase UI flow
- Spawn UI flow
- Replace latejoin menu
- Filter/search/sort

**Testing:** Visual catalog, unlock ships via UI, spawn via UI

**Deliverable:** Players use catalog instead of console

### Phase 3: Crafting System (2-3 weeks)
**Tasks:**
- Ship part fabricator machine
- Crafting recipes (NEU/NT-C/SYN-C)
- Loot spawners (credits, parts)
- Place fabricators on maps
- Place spawners in ruins/loot

**Testing:** Craft parts, find credits/parts, trade with N key

**Deliverable:** Active earning functional

### Phase 4: Antag Ships (3-4 weeks)
**Tasks:**
- Define antag part types
- Create antag ship templates (Syndicate Ops, Blood Cult, Xenomorph)
- Antag part earning (rare drops, expensive purchases)
- Antag tab in catalog
- Per-round purchase flow
- Antagonist conversion logic
- Antag equipment loadouts

**Testing:** Earn antag parts, buy antag ship, become antagonist

**Deliverable:** Antag ships functional

### Phase 5: Ship Variants & Previews (4-6 weeks)
**Tasks:**
- Create map variants (MASSIVE content creation)
- Generate preview images (screenshots/renders)
- Variant selection UI
- Variant loading in ship creation
- Image asset pipeline
- Optimize image loading (lazy load, cache)

**Testing:** Select variant, ship loads correct .dmm, previews display

**Deliverable:** Full visual catalog with variants

### Phase 6: Polish & Balance (2-3 weeks)
**Tasks:**
- Balance tuning (rates, costs, exchange rates)
- UI polish (animations, feedback)
- Bug fixes
- Performance optimization
- Admin tools (grant credits/parts, reset unlocks)
- Analytics (economy health tracking)

**Deliverable:** Production-ready

**TOTAL ESTIMATE:** ~20 weeks (5 months)

---

## VIII. SUCCESS METRICS

**Player Engagement:**
- % players who unlock ≥1 ship
- Average ships unlocked per player
- Average time to first unlock
- % players who craft vs buy parts

**Economy Health:**
- Total credits in circulation
- Average credits per player
- Credit earning rate vs spending rate
- Part conversion rates

**Feature Usage:**
- % players using catalog vs old system
- Most popular ships
- Antag ship usage frequency
- Variant selection distribution

**Balance:**
- Time to unlock all ships (target: months)
- Antag ship spawn rate (target: <5% rounds)
- Player retention post-launch

---

## IX. CONCLUSION

This architecture fulfills ALL 5 user decisions:
1. ✅ Hybrid earning (round-end + find/craft)
2. ✅ Three-tier system (credits → parts → permanent unlocks)
3. ✅ One spawn per round (high stakes)
4. ✅ Antag ships (per-round, auto-convert, rare parts)
5. ✅ Full map variants (separate .dmm files)

Addresses ALL clarification questions with concrete definitions. Maintains backward compatibility with existing systems. Provides phased implementation preventing scope explosion. Documents persistence scalability path.

**Agent B's proposal complete - ready for Round 4 consensus.**

### Agent C's Proposal

**ARCHITECTURE: Three-Tier Permanent Unlock System with Dual Ship Economies**

After incorporating user decisions, Round 2 discussions, and the critical database persistence clarification, I propose a phased architecture that separates regular ships (permanent unlocks) from antagonist ships (per-round consumable).

---

## I. HIGH-LEVEL ARCHITECTURE

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    PLAYER PROGRESSION LAYER                      │
│  ┌──────────────┐      ┌──────────────┐      ┌───────────────┐ │
│  │   CURRENCY   │  →   │    PARTS     │  →   │ SHIP UNLOCKS  │ │
│  │  (Unified)   │      │ (3 Factions) │      │  (Permanent)  │ │
│  └──────────────┘      └──────────────┘      └───────────────┘ │
│         ↑                     ↑                                  │
│    Round Rewards         Find/Craft                              │
└─────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────┐
│                   ANTAGONIST SHIP LAYER                          │
│  ┌──────────────┐      ┌──────────────┐      ┌───────────────┐ │
│  │   CURRENCY   │  →   │ ANTAG PARTS  │  →   │ ANTAG SHIP    │ │
│  │  (Unified)   │      │  (Rare/$$)   │      │  (Per-Round)  │ │
│  └──────────────┘      └──────────────┘      └───────────────┘ │
│         ↑                     ↑                                  │
│    Round Rewards         Find/Craft (Rare)                       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        UI/CATALOG LAYER                          │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  TGUI Ship Catalog (replaces select_ship() dialogs)     │   │
│  │  - Regular Ships Tab  (unlock once, spawn free)         │   │
│  │  - Antag Ships Tab    (per-round purchase)              │   │
│  │  - Ship previews (.dmm renders + skin variants)         │   │
│  │  - Customization UI   (crew roles, loadouts)            │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    EXISTING SHIP SPAWNING                        │
│        SSshuttle.create_ship() → SSovermap → Ship Object         │
│              (UNCHANGED - we insert before this)                 │
└─────────────────────────────────────────────────────────────────┘
```

### Three-Tier Progression (User Decision)

**Tier 1: Currency (Unified Meta-Economy)**
- **Definition:** "Ship Credits" (SC) - unified cross-faction currency
- **Earning:** Hybrid (round completion + find/craft)
- **Storage:** Database-backed
- **Purpose:** Purchase parts OR antag parts

**Tier 2A: Regular Parts (Faction-Specific Unlock Currency)**
- **Definition:** NEU/NT-C/SYN-C parts (KEEP existing three factions)
- **Change:** Parts become **permanent unlock currency** (NOT consumable)
- **Acquisition:** Buy with currency, craft, find as loot
- **Storage:** Database (fix Agent B's load bug)
- **Purpose:** Permanently unlock ships (spend once, own forever)
- **Physical Trading:** Preserve N-key system

**Tier 2B: Antag Parts (Special Consumable Currency)**
- **Definition:** Separate types per antag faction
- **Acquisition:** Buy (expensive), craft (rare materials), find (super rare)
- **Storage:** Database, separate table
- **Purpose:** Per-round purchase of antag ships (CONSUMABLE)

**Tier 3: Ship Unlocks**
- **Regular Ships:** Permanent unlocks
- **Antag Ships:** Per-round purchases

---

## II. DATABASE SCHEMA (User Clarified: Database, Not Savefiles)

```sql
-- Table: player_ship_currency (NEW)
CREATE TABLE player_ship_currency (
    ckey TEXT PRIMARY KEY,
    currency_amount INTEGER DEFAULT 0,
    last_updated TIMESTAMP
);

-- Table: player_ship_parts (EXISTING - FIX LOAD BUG)
CREATE TABLE player_ship_parts (
    ckey TEXT,
    part_type TEXT,  -- 'NEU', 'NT-C', 'SYN-C'
    part_count INTEGER DEFAULT 0,
    PRIMARY KEY (ckey, part_type)
);

-- Table: player_antag_parts (NEW)
CREATE TABLE player_antag_parts (
    ckey TEXT,
    antag_part_type TEXT,
    part_count INTEGER DEFAULT 0,
    PRIMARY KEY (ckey, antag_part_type)
);

-- Table: player_ship_unlocks (NEW)
CREATE TABLE player_ship_unlocks (
    ckey TEXT,
    ship_template_path TEXT,
    unlocked_date TIMESTAMP,
    PRIMARY KEY (ckey, ship_template_path)
);

-- Table: player_ship_customizations (NEW)
CREATE TABLE player_ship_customizations (
    ckey TEXT,
    ship_template_path TEXT,
    customization_json TEXT,
    PRIMARY KEY (ckey, ship_template_path)
);

-- Table: round_ship_spawns (NEW - per-round tracking)
CREATE TABLE round_ship_spawns (
    round_id INTEGER,
    ckey TEXT,
    ship_template_path TEXT,
    spawn_time TIMESTAMP,
    PRIMARY KEY (round_id, ckey)
);
```

**FIX FOR AGENT B'S BUG:**

Current broken code only saves but never loads. Fix:

```dm
/datum/preferences/proc/load_character(slot)
    . = ..()

    // FIX: Add database load for ship parts
    var/datum/db_query/query = SSdbcore.NewQuery(
        "SELECT part_type, part_count FROM player_ship_parts WHERE ckey = :ckey",
        list("ckey" = parent.ckey)
    )

    if(query.Execute())
        ships_owned = list()
        while(query.NextRow())
            var/part_type = query.item[1]
            var/part_count = text2num(query.item[2])
            ships_owned[part_type] = part_count

    qdel(query)
```

---

## III. PHASED IMPLEMENTATION ROADMAP

### PHASE 0: Fix Persistence Bug (PRIORITY ZERO)

**Duration:** 1-2 days

**Tasks:**
1. Add database load query for `ships_owned` (fix Agent B's bug)
2. Test save/load cycle
3. Create new DB tables
4. Implement `/datum/ship_progression_manager`
5. Migration for existing players

**Deliverable:** Working database persistence

---

### PHASE 1: TGUI Ship Catalog (MVP)

**Duration:** 1-2 weeks

**Tasks:**
1. Create TGUI interface
2. Generate ship preview images
3. Replace `select_ship()` with catalog
4. Display unlocked ships (read-only)
5. Basic spawning from catalog
6. Per-round spawn limits

**Deliverable:** Visual catalog replacing BYOND dialogs

---

### PHASE 2: Currency & Unlock System (CORE)

**Duration:** 2-3 weeks

**Tasks:**
1. Currency earning (round-end + loot)
2. Parts purchasing with currency
3. Ship unlock purchasing
4. Physical trading (N-key)
5. Crafting recipes

**Deliverable:** Full three-tier progression

---

### PHASE 3: Antagonist Ship System

**Duration:** 2-3 weeks

**Tasks:**
1. Antag ship templates
2. Antag parts system
3. Antag tab in catalog
4. Antagonist conversion
5. Antag equipment loadouts

**Deliverable:** Full antag ship system

---

### PHASE 4: Customization & Skins

**Duration:** 3-4 weeks

**Tasks:**
1. Customization UI
2. Job slot editing
3. Skin system (full .dmm variants)
4. Database storage
5. Apply before spawn

**Deliverable:** Full customization

---

**Total Timeline:** ~10-13 weeks

---

## IV. INTEGRATION WITH EXISTING SYSTEMS

**Latejoin Menu:** Hijack maintained - catalog replaces `select_ship()`

**Ship Creation:** Insert before `SSshuttle.create_ship()` - pipeline unchanged

**Thread Safety:** Preserve `shuttle_loading` mutex and SSair management

**Database:** All persistence via DB queries, not savefiles

**Crafting:** Extend existing system with ship part recipes

**Signals:** Use COMSIG_VOIDCREW_SHIP_LOADED for stats/achievements

---

## V. TRADEOFFS

**Three-Tier Progression:**
- Pro: Preserves existing parts, Agent B's trading
- Con: More complex than direct unlock
- Mitigation: Clear UI, tutorial

**Database Persistence:**
- Pro: Structured, performant, transaction-safe
- Con: Requires DB setup
- Mitigation: Export tool for backups

**Antag Ships Separate:**
- Pro: Balanced rarity, clear separation
- Con: Dual system complexity
- Mitigation: Separate UI tab

**Full .dmm Variants:**
- Pro: Maximum flexibility
- Con: High content cost
- Mitigation: Start with few skins

**One Spawn Limit:**
- Pro: High stakes gameplay
- Con: Punishing if destroyed
- Mitigation: Clear warnings

---

## VI. ADDRESSING CLARIFICATION QUESTIONS

**Q1: What is "currency"?**
Ship Credits (SC) - unified meta-currency, earned via round rewards + loot + crafting sales

**Q2: What are "parts"?**
- Regular: NEU/NT-C/SYN-C (permanent unlock currency)
- Antag: Syndicate Token, Cult Artifact, etc. (consumable)

**Q3: Regular vs Antag Parts?**
- Regular: permanent unlocks, moderate rarity
- Antag: per-round consumable, super rare

**Q4: Crafting Details?**
- Materials: currency + common/rare materials
- Location: existing crafting benches
- All types craftable (antag parts very difficult)

**Q5: Antag Ship Flow?**
- No unlock required, direct purchase
- Same one-spawn limit as regular
- Separate "Antagonist Ships" tab
- Purchase & spawn in one action

---

## VII. SUMMARY

**This architecture:**
- ✅ Incorporates ALL user decisions
- ✅ Fixes Agent B's critical bug (Phase 0)
- ✅ Preserves existing systems
- ✅ Phased rollout (scope management)
- ✅ Database-backed (user confirmed)
- ✅ Addresses all clarifications
- ✅ Maintains agent consensus

**MVP:** Phases 0-2 (core unlock system working)

**Polish:** Phases 3-4 (antag ships, customization)

**Ready for parallel development:** Phases 3 & 4 can run simultaneously

**Recommendation:** Proceed with this architecture

---

**Agent C - Round 3 Proposal Complete**

### Agent D's Proposal

After reading all Round 2 discussions, here is my comprehensive architectural proposal for the ship purchase redesign:

---

## AGENT D - PHASED HYBRID ARCHITECTURE PROPOSAL

### High-Level Philosophy

**Core Principle**: Build a flexible, phased system that preserves existing infrastructure while enabling permanent ship ownership, visual catalog browsing, and player progression.

**Key Design Decision**: **Unified currency with faction-themed unlock trees** - one currency type to earn/spend, but ships organized into faction progression paths for game balance.

**Implementation Approach**: Phased rollout with each phase fully functional and testable independently.

---

## PHASE 0: FOUNDATION FIX (Priority Zero - Blocking)

**Must complete before ANY other work.**

### Component: Persistence Bug Fix

**Problem**: `ships_owned` is saved but never loaded (confirmed in `preferences_savefile.dm:193+`)

**Solution**:
```dm
// In /datum/preferences/proc/load_preferences()
// Add after line 234 (key_bindings load):

ships_owned = savefile.get_entry("ships_owned", ships_owned)
```

**Migration Strategy**:
- Existing savefiles missing `ships_owned` will default to initial value (all zeros)
- No data loss risk since load never worked anyway
- Add version check if we modify `ships_owned` structure later

**Testing Requirements**:
1. Create new player → verify `ships_owned` initializes to zeros
2. Grant parts via `give_random_ship_part()` → verify save writes
3. Restart server → verify load reads saved values
4. Verify `list_ship_parts()` displays correct counts

**Deliverable**: One-line code fix + verification test script

**Estimated Effort**: 1 hour (fix + test)

---

## PHASE 1: VISUAL SHIP CATALOG (TGUI Interface)

**Goal**: Replace current text-based purchase UI with visual ship catalog showing previews, stats, and metadata.

### Component 1.1: Ship Catalog Data Layer

**New Datum**: `/datum/ship_catalog_entry`

**Purpose**: Wrapper around ship templates that adds display metadata without polluting game logic templates.

**Structure**:
```dm
/datum/ship_catalog_entry
    var/datum/map_template/shuttle/voidcrew/ship_template  // Reference to actual ship

    // Display Metadata
    var/display_name                 // Formatted name for UI
    var/description                  // Lore/gameplay description
    var/preview_image_path           // Path to preview PNG: "icons/ship_previews/delta.png"
    var/tier                         // Visual grouping: "Starter", "Advanced", "Elite"
    var/faction                      // NEU, NT-C, SYN-C for filtering/sorting

    // Stats for Display
    var/crew_capacity                // Total job slots
    var/estimated_speed              // "Fast", "Medium", "Slow" or numeric
    var/combat_rating                // Optional: "Light", "Medium", "Heavy"
    var/special_features = list()    // List of highlights: "Medbay", "Mining", etc.

    // Unlock Prerequisites (for future phases)
    var/currency_cost = 0            // Cost in new currency
    var/required_unlocks = list()    // Other ships that must be unlocked first
    var/faction_requirement          // Optional: require faction alignment
```

**Responsibility**: Pure data - no game logic, just catalog display information.

**Integration**: Load during `SSmapping.load_ship_templates()`, build parallel catalog list.

### Component 1.2: Ship Preview Image System

**Image Storage**: `icons/ship_previews/[ship_suffix].png`

**Generation Approach** (Decision Needed - Propose Options):

**Option A: Pre-Rendered Screenshots** (Recommended for Phase 1)
- Manually screenshot each ship map in Dream Maker
- Save as PNG, resize to standard catalog size (e.g., 400x300px)
- **Pros**: High quality, no runtime cost, full control
- **Cons**: Manual work, must update if ship maps change

**Option B: Runtime Map Rendering**
- Generate preview images on-demand from .dmm files
- Cache generated images
- **Pros**: Automatic updates when maps change
- **Cons**: Complex implementation, performance concerns

**Option C: Hybrid**
- Ship creators provide preview images as part of ship definition
- Fallback to placeholder if missing
- **Pros**: Flexible, no bottleneck
- **Cons**: Quality variation

**Phase 1 Recommendation**: Option A (pre-rendered) for speed, migrate to Option C later.

### Component 1.3: TGUI Catalog Interface

**New TGUI Component**: `ShipCatalog.tsx`

**UI Structure**:
```
┌─────────────────────────────────────────────┐
│ SHIP CATALOG                    [X Close]  │
├─────────────────────────────────────────────┤
│ Filters: [All] [NEU] [NT-C] [SYN-C]       │
│ Sort: [Name] [Cost] [Tier] [Crew Size]    │
├─────────────────────────────────────────────┤
│ ┌────────┐  ┌────────┐  ┌────────┐        │
│ │ [IMG]  │  │ [IMG]  │  │ [IMG]  │        │
│ │ Delta  │  │ Bogatyr│  │ Box    │        │
│ │ 3 pts  │  │ 2 pts  │  │ 1 pt   │        │
│ │ [VIEW] │  │ [VIEW] │  │ [VIEW] │        │
│ └────────┘  └────────┘  └────────┘        │
│                                             │
│ [Selected Ship Details Panel]              │
│  • Crew: 9                                  │
│  • Class: Frigate                           │
│  • Description: ...                         │
│  • Cost: 3 NEU parts                        │
│  [PURCHASE BUTTON]                          │
└─────────────────────────────────────────────┘
```

**Features**:
- Grid view of ship thumbnails
- Faction filtering/sorting
- Detail panel on selection
- Purchase button (current parts validation initially)
- Lazy loading if 30+ ships (load 12 at a time)

**Data Flow**:
```
Player clicks "Purchase ship"
  → Opens ShipCatalog TGUI
  → TGUI requests catalog data from server
  → Server builds catalog_entry list, serializes to JSON
  → TGUI renders grid with images
  → Player selects ship
  → TGUI shows detail panel
  → Player clicks Purchase
  → Server validates parts (current system)
  → Server calls SSshuttle.create_ship()
  → Player spawns on ship
```

**Integration with Existing**:
- Replace `tgui_input_list()` call in `select_ship()` with `tgui_catalog.ui_interact()`
- Keep fallback to text list if TGUI fails (accessibility)
- Preserve existing purchase validation logic initially

**TGUI Dependencies** (Research Needed):
- Image display component (likely `<Image>` or `<img>` tag)
- Icon/PNG loading from server
- Grid layout component
- State management for filters/selection

### Component 1.4: Existing Ship Selection Integration

**Modification**: `voidcrew/edits/mobs/new_player.dm`

**Current Flow**:
```dm
proc/select_ship()
    // Build list of active ships
    // Show "Purchase ship" option
    // Use tgui_input_list()
```

**New Flow**:
```dm
proc/select_ship()
    // Build list of active ships (unchanged)
    // Show choice: "Join Existing Ship" or "Browse Ship Catalog"

    if("Browse Ship Catalog"):
        open_ship_catalog()  // New TGUI interface
    else:
        show_existing_ships()  // Keep current system
```

**Backward Compatibility**: Both paths work, gradual transition.

---

## PHASE 2: PERMANENT UNLOCK SYSTEM

**Goal**: Shift from consumable parts (spend per spawn) to permanent unlocks (buy once, own forever, spawn per-round).

### Component 2.1: Player Unlock Persistence

**Extend**: `/datum/preferences`

**New Fields**:
```dm
/datum/preferences
    // Existing
    var/list/ships_owned = list(...)  // Keep for parts (legacy/conversion)

    // NEW - Permanent Unlocks
    var/list/ships_unlocked = list()  // List of ship template types permanently unlocked
    // Example: list(/datum/map_template/shuttle/voidcrew/delta, /datum/map_template/shuttle/voidcrew/box)

    // NEW - Per-Round Spawn Tracking
    var/list/ships_spawned_this_round = list()  // Reset each round
    // Example: list(/datum/map_template/shuttle/voidcrew/delta) - spawned this round

    // NEW - Ship Customizations (for Phase 3+)
    var/list/ship_customizations = list()  // Keyed by ship template type
```

**Save/Load**:
```dm
proc/save_preferences()
    // ... existing saves ...
    savefile.set_entry("ships_unlocked", ships_unlocked)
    savefile.set_entry("ship_customizations", ship_customizations)

proc/load_preferences()
    // ... existing loads ...
    ships_unlocked = savefile.get_entry("ships_unlocked", ships_unlocked)
    ship_customizations = savefile.get_entry("ship_customizations", ship_customizations)
    // Note: ships_spawned_this_round intentionally NOT loaded (per-round only)
```

**Round Reset**:
```dm
/datum/controller/subsystem/overmap/Initialize()
    . = ..()
    // Clear per-round spawn tracking
    for(var/client/C in GLOB.clients)
        if(C.prefs)
            C.prefs.ships_spawned_this_round = list()
```

### Component 2.2: Ship Currency System

**New Datum**: `/datum/bank_account/player_meta`

**Purpose**: Persistent player currency account (separate from ship bank accounts).

**Structure**:
```dm
/datum/bank_account/player_meta
    var/ckey                          // Owner ckey
    var/meta_currency = 0             // Cross-round persistent currency
    var/currency_name = "Ship Credits" // Display name

    proc/adjust_currency(amount, reason)
        meta_currency = max(0, meta_currency + amount)
        log_currency_transaction(ckey, amount, reason)
        return TRUE

    proc/can_afford(cost)
        return meta_currency >= cost
```

**Integration**:
- Created on client login if doesn't exist
- Saved to JSON savefile alongside preferences
- Accessed via `client.meta_account`

**Why New Datum Instead of Preference Var?**
- Reuses bank account infrastructure (transaction logging, admin tools)
- Consistent with existing ship bank accounts
- Easier to extend with features (transaction history, limits, etc.)

### Component 2.3: Currency Earning System (Pluggable)

**Design Philosophy**: Configurable earning sources to allow game balance tuning.

**Base Interface**:
```dm
/datum/currency_source
    var/source_name
    var/enabled = TRUE  // Can be toggled via config

    proc/calculate_reward(client/C)
        return 0  // Override in subtypes
```

**Implemented Sources**:

**Source 1: Round Completion Reward**
```dm
/datum/currency_source/round_completion
    source_name = "Round Completion"
    var/base_reward = 100  // Config adjustable

    proc/calculate_reward(client/C)
        // Grant flat reward for round completion
        return base_reward
```

**Source 2: Performance Bonuses** (Future)
```dm
/datum/currency_source/performance
    // Reward based on objectives, survival, etc.
```

**Source 3: Admin Grants**
```dm
/datum/currency_source/admin_grant
    // Admin verb to grant currency for events
```

**Hook Integration**:
```dm
/datum/controller/subsystem/ticker/declare_completion()
    . = ..()
    for(var/client/C in GLOB.clients)
        grant_currency_rewards(C)

proc/grant_currency_rewards(client/C)
    var/total_reward = 0
    for(var/datum/currency_source/source in SSeconomy.currency_sources)
        if(source.enabled)
            total_reward += source.calculate_reward(C)

    C.meta_account.adjust_currency(total_reward, "Round Completion")
    to_chat(C, "You earned [total_reward] Ship Credits!")
```

**Config Integration**:
```dm
// config.dm
/datum/config_entry/number/base_ship_currency_reward
    default = 100
    min_val = 0
    max_val = 10000
```

### Component 2.4: Unlock Purchase Flow

**Modification**: Ship Catalog TGUI

**New UI Elements**:
- "UNLOCKED" badge on owned ships
- "UNLOCK (Cost: X)" button on locked ships
- "SPAWN" button on unlocked ships (if not spawned this round)
- "SPAWNED THIS ROUND" indicator if already spawned

**Purchase Validation**:
```dm
proc/attempt_unlock_ship(datum/map_template/shuttle/voidcrew/template)
    // Check if already unlocked
    if(template in client.prefs.ships_unlocked)
        to_chat(src, "You already own this ship!")
        return FALSE

    // Check currency cost
    var/datum/ship_catalog_entry/entry = SSovermap.ship_catalog[template]
    if(!client.meta_account.can_afford(entry.currency_cost))
        to_chat(src, "Insufficient Ship Credits! Need [entry.currency_cost], have [client.meta_account.meta_currency]")
        return FALSE

    // Deduct currency
    client.meta_account.adjust_currency(-entry.currency_cost, "Unlocked [entry.display_name]")

    // Add to unlocked list
    client.prefs.ships_unlocked += template
    client.prefs.save_preferences()

    to_chat(src, "Ship unlocked: [entry.display_name]!")
    return TRUE
```

**Spawn Validation**:
```dm
proc/attempt_spawn_ship(datum/map_template/shuttle/voidcrew/template)
    // Check if unlocked
    if(!(template in client.prefs.ships_unlocked))
        to_chat(src, "You haven't unlocked this ship yet!")
        return FALSE

    // Check per-round spawn limit
    if(template in client.prefs.ships_spawned_this_round)
        to_chat(src, "You've already spawned this ship this round!")
        return FALSE

    // Create ship (existing system)
    var/obj/structure/overmap/ship/new_ship = SSshuttle.create_ship(template)
    if(!new_ship)
        return FALSE

    // Track spawn
    client.prefs.ships_spawned_this_round += template

    // Spawn player
    AttemptSpawnOnShip(new_ship.job_slots[1], new_ship)
    return TRUE
```

### Component 2.5: Legacy Parts Migration

**Decision**: Keep parts system as **secondary currency** with conversion mechanism.

**Conversion System**:
```dm
proc/convert_parts_to_currency()
    var/total_value = 0
    var/list/conversion_rates = list(
        /obj/item/ship_parts/neutral = 50,      // 1 NEU part = 50 credits
        /obj/item/ship_parts/nanotrasen = 75,   // 1 NT-C part = 75 credits (premium)
        /obj/item/ship_parts/syndicate = 75,    // 1 SYN-C part = 75 credits (premium)
    )

    for(var/part_type in client.prefs.ships_owned)
        var/count = client.prefs.ships_owned[part_type]
        var/rate = conversion_rates[part_type]
        total_value += count * rate

    if(total_value > 0)
        client.meta_account.adjust_currency(total_value, "Parts Conversion")
        client.prefs.ships_owned = list(...)  // Reset to zeros
        client.prefs.save_preferences()
        to_chat(client, "Converted [total_value] Ship Credits from legacy parts!")
```

**UI Integration**: Add "Convert Parts" button in catalog if player has any parts.

**Physical Trading Preservation**:
- Keep 'N' key binding functional
- Parts can still be withdrawn as physical items
- Physical parts can be converted to currency via `attack_self()`
- This preserves player trading economy

---

## PHASE 3: CREW CUSTOMIZATION (Future / Deferred)

**Goal**: Allow players to modify job slots, outfits, spawn positions before spawning ship.

### Component 3.1: Customization Storage

**Extend**: `/datum/preferences`

**Structure**:
```dm
var/list/ship_customizations = list()
// Keyed by ship template type
// Value: /datum/ship_customization

/datum/ship_customization
    var/list/modified_job_slots = list()  // Override template job_slots
    var/list/job_spawn_positions = list() // Custom spawn locations per job
```

### Component 3.2: Job Assembly Hook

**Modification**: `assemble_job_slots()` in `_shuttle.dm`

**Current**:
```dm
proc/assemble_job_slots()
    // Uses template's job_slots directly
```

**New**:
```dm
proc/assemble_job_slots(client/purchaser)
    // Check for customization override
    if(purchaser?.prefs.ship_customizations[src.type])
        var/datum/ship_customization/custom = purchaser.prefs.ship_customizations[src.type]
        use job_slots = custom.modified_job_slots
    else:
        use job_slots = src.job_slots

    // Rest of assembly logic unchanged
```

### Component 3.3: Customization UI

**TGUI Component**: `ShipCustomizer.tsx`

**Accessed From**: Ship catalog detail panel → "Customize" button (only for owned ships)

**Features**:
- Drag-and-drop job slot editing
- Outfit selection per job
- Cost calculator (customizations cost additional currency)
- Save custom loadout

**Scope Control**: Phase 3 is intentionally deferred - high complexity, lower priority than core unlock system.

---

## INTEGRATION WITH EXISTING SYSTEMS

### Preserves Thread Safety

**No Changes To**:
- `SSshuttle.create_ship()` - keeps existing `shuttle_loading` mutex
- SSair disable/enable pattern
- Shuttle template loading pipeline

**Separation**: Catalog UI and unlock validation happen BEFORE ship creation, not during. Thread safety maintained.

### Leverages Existing Infrastructure

**Reuses**:
- `/datum/preferences` savefile system (proven, works)
- `/datum/bank_account` pattern (transaction logging, admin tools)
- Ship template system (extend, don't replace)
- Signal hooks (COMSIG_VOIDCREW_SHIP_LOADED for stats tracking)
- Config system (adjustable rewards, costs)

**Extends**:
- `SSmapping.ship_purchase_list` → `SSmapping.ship_catalog`
- Preferences persistence
- Economy subsystem

### Maintains Ship-Centric Design

**No Changes To**:
- Latejoin hijack (still redirects to ship selection)
- Ship-based job slots
- Overmap system
- Team/faction mechanics

**Enhancement**: Better UI doesn't change fundamental paradigm.

---

## TRADEOFFS OF THIS APPROACH

### PROS

✅ **Phased Rollout**
- Each phase is independently testable
- Can ship Phase 1 (catalog) without Phase 2 (unlocks)
- Minimizes risk of breaking existing system

✅ **Minimal Existing Code Changes**
- Catalog is additive (wraps templates, doesn't modify them)
- Unlock system extends preferences (doesn't replace parts)
- Ship creation pipeline untouched

✅ **Flexible Design Decisions**
- Currency earning is pluggable (easy to add new sources)
- Conversion rates configurable (parts → currency)
- Customization system deferred (reduces Phase 2 scope)

✅ **Backward Compatible**
- Parts system still works (legacy/conversion)
- Text-based UI still accessible (fallback)
- Existing ships unchanged

✅ **Leverages Proven Patterns**
- Bank account infrastructure (already tested)
- Savefile system (works reliably)
- Template extensibility (designed for this)

### CONS

❌ **Manual Work Required**
- Ship preview images need creation (Phase 1)
- Catalog entries need metadata authoring
- Testing across 30+ ships is time-intensive

❌ **Dual Currency Complexity** (Parts + Credits)
- UI shows both until full migration
- Two validation paths initially
- Player confusion potential during transition

❌ **TGUI Research Dependency**
- Phase 1 blocked until TGUI image display confirmed
- Unknown performance characteristics
- May need lazy-loading optimization

❌ **Deferred Crew Customization**
- Phase 3 scope is large (intentionally deferred)
- Feature request mentions it, but not in Phase 1-2
- Risk of scope creep if attempted too early

❌ **Per-Round Spawn Limits May Feel Restrictive**
- Player unlocks ship, can only spawn once per round
- If ship destroyed, can't re-spawn
- May frustrate players (needs game balance testing)

### ALTERNATIVE TRADEOFFS (If Different Approach)

**If We Fully Replaced Parts System**:
- ✅ Simpler single-currency design
- ❌ Loses physical trading economy
- ❌ No migration path for existing parts

**If We Skipped TGUI Catalog**:
- ✅ Faster Phase 1 implementation
- ❌ Feature request explicitly wants "rendered images"
- ❌ Misses major UX improvement

**If We Combined Phases 1+2**:
- ✅ Ship unlock system available sooner
- ❌ Higher risk (more simultaneous changes)
- ❌ Harder to test/debug

---

## CRITICAL DEPENDENCIES & UNKNOWNS

### Must Research Before Implementation

1. **TGUI Image Display Capabilities**
   - Can TGUI render PNG files from server?
   - What's max image size before lag?
   - Lazy-loading support for large catalogs?

2. **Ship Preview Generation**
   - Who creates preview images? (Artists? Automated?)
   - Standard resolution/format?
   - Update process when ship maps change?

3. **Currency Earning Balance**
   - What's reasonable currency reward per round?
   - How many rounds to unlock average ship?
   - Should high-tier ships require achievements too?

### Requires User/Designer Decisions

1. **Antagonist Ships System**
   - Separate unlock tree? Temporary per-round? Special equipment?
   - Not addressed in this proposal (needs clarification)

2. **Ship Skins Implementation**
   - Palette swaps (easy), map variants (hard), or modular (very hard)?
   - Not addressed in this proposal (needs scope decision)

3. **Per-Round Respawn Rules**
   - Can destroyed ships be re-spawned? With cooldown? With cost?
   - Current proposal: once per round absolute (simplest, needs balance testing)

4. **Faction Restrictions in New System**
   - Keep faction-themed unlock trees? Or all ships unlockable by anyone?
   - Current proposal: unified currency, optional faction requirements per ship

---

## IMPLEMENTATION ROADMAP

### Phase 0: Foundation (1-2 days)
- [ ] Fix persistence bug (`ships_owned` load line)
- [ ] Test save/load cycle
- [ ] Verify parts grant and redemption still works

### Phase 1: Visual Catalog (2-3 weeks)
- [ ] Research TGUI image display
- [ ] Create `/datum/ship_catalog_entry` system
- [ ] Generate ship preview images (30+ ships)
- [ ] Build ShipCatalog.tsx TGUI component
- [ ] Integrate with existing purchase flow
- [ ] Test catalog browsing and filtering

### Phase 2: Unlock System (3-4 weeks)
- [ ] Implement `/datum/bank_account/player_meta`
- [ ] Add `ships_unlocked` to preferences
- [ ] Create currency earning system (pluggable sources)
- [ ] Build unlock purchase validation
- [ ] Implement per-round spawn tracking
- [ ] Create parts → currency conversion system
- [ ] Test unlock progression across rounds

### Phase 3: Crew Customization (4-6 weeks - Future)
- [ ] Design customization storage schema
- [ ] Build ShipCustomizer TGUI interface
- [ ] Hook into `assemble_job_slots()`
- [ ] Implement cost system for customizations
- [ ] Test job slot modifications

---

## CONCLUSION

This phased hybrid architecture:
- **Fixes the critical bug first** (Priority Zero)
- **Delivers visual catalog quickly** (Phase 1 - high UX value)
- **Implements core unlock system** (Phase 2 - feature request goal)
- **Defers complex customization** (Phase 3 - scope control)
- **Preserves existing infrastructure** (minimal breaking changes)
- **Allows flexibility** (pluggable earning, configurable costs)

The unified currency with faction-themed unlock trees provides economic simplicity while maintaining game balance design space. The parts-to-currency migration path preserves player trading economy while transitioning to the new system.

**Ready for implementation** with clear dependencies and unknowns flagged for resolution.

---

