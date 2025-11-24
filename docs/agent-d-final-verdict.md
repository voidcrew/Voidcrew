### Agent D's Final Verdict

After reviewing all Round 3 proposals (Agent A, B, C, and my own) and analyzing the USER DECISIONS from Round 3.5, I present my final verdict with comprehensive architecture revisions.

---

## EXECUTIVE SUMMARY

**My Verdict**: I support a **synthesis of all proposals** with **critical pivots** to align with user decisions. The core remains my phased pluggable architecture, but with **rarity-based progression** replacing faction trees, **database persistence**, and **physical extraction mechanics**.

**Key Adaptations Required:**
- ✅ Rarity tiers (basic/advanced/rare/superior) replace faction parts (NEU/NT-C/SYN-C)
- ✅ Database schema replaces savefile extensions
- ✅ Physical parts + extraction device UI
- ✅ Integration points for 3 separate feature teams (Battlepass, Custom Roles, Automation)
- ✅ Starter ship selection system
- ✅ Dual antag ship models (large/small scale)

---

## 1. WHICH PROPOSAL DO I SUPPORT?

**PRIMARY SUPPORT: Synthesis of Agent A + Agent B + Agent C + My Own**

**From Agent A:**
- ✅ Three-tier economy flow (Credits → Parts → Blueprints)
- ✅ Clear phased delivery timeline (16 weeks)
- ✅ TGUI catalog with dual tabs (Regular | Antag)
- ✅ Crafting integration points

**From Agent B:**
- ✅ Modular architecture principles
- ✅ Separate regular/antag inventory systems
- ✅ Detailed TGUI data interfaces (TypeScript types)
- ✅ Ship template extension variables

**From Agent C:**
- ✅ Database persistence (validated by user Q7)
- ✅ Explicit integration contracts for new features
- ✅ Transaction-safe operations
- ✅ Testing requirements focus

**From My Round 3:**
- ✅ Pluggable architecture (currency sources, catalog entries)
- ✅ Phase 0 foundation fix (persistence bug)
- ✅ `/datum/ship_catalog_entry` wrapper system
- ✅ Per-round spawn tracking
- ✅ Backward compatibility patterns

**Critical Difference:** ALL agents proposed faction parts (NEU/NT-C/SYN-C). User has **eliminated this entirely** (Q8). My revised architecture pivots to **rarity-based progression trees** while preserving the modular catalog design.

---

## 2. CRITICAL ADAPTATIONS TO USER DECISIONS

### Adaptation A: Rarity Tiers Replace Faction Parts

**User Decision (Q8):**
> "Eliminate faction specific ship parts and move to part rarity. so different tiers of parts, maybe make it expandable for other types in the future."

**Impact on My Round 3 Proposal:**
- ❌ REMOVE: Faction-specific unlock trees
- ❌ REMOVE: `var/faction` as unlock requirement from catalog entries
- ✅ ADD: Rarity-based progression system
- ✅ KEEP: `var/faction` for display/filtering (visual lore only)

**Rarity Progression Design:**

```
PART RARITY TIERS (expandable system):

┌─────────────────────────────────────────────────┐
│ BASIC (Common)                                  │
│ - Found frequently in ruins                     │
│ - Crafted with common materials                 │
│ - Battlepass early tiers                        │
│ - Unlock starter/small ships                    │
│ - Value: 10,000 Credits                         │
├─────────────────────────────────────────────────┤
│ ADVANCED (Uncommon)                             │
│ - Found in harder ruins                         │
│ - Crafted with rare materials                   │
│ - Battlepass mid tiers                          │
│ - Unlock medium ships                           │
│ - Value: 15,000 Credits                         │
├─────────────────────────────────────────────────┤
│ RARE (Rare)                                     │
│ - Found in dangerous locations                  │
│ - Automation crafting required                  │
│ - Battlepass high tiers                         │
│ - Unlock large ships                            │
│ - Value: 20,000 Credits                         │
├─────────────────────────────────────────────────┤
│ SUPERIOR (Epic)                                 │
│ - Found in extreme endgame zones                │
│ - Complex automation chains                     │
│ - Battlepass final rewards                      │
│ - Unlock elite/flagship ships                   │
│ - Value: 25,000 Credits                         │
└─────────────────────────────────────────────────┘

EXPANDABLE DESIGN (future):
- "LEGENDARY" tier (admin grants, special events)
- "PROTOTYPE" tier (experimental ships)
- "ANTAG" tier (separate from regular progression)
- Event-specific tiers (Halloween, Christmas, etc.)
```

**Revised Ship Catalog Entry:**

```dm
/datum/ship_catalog_entry
    var/datum/map_template/shuttle/voidcrew/ship_template

    // Display Metadata
    var/display_name
    var/description
    var/preview_image_path
    var/tier                         // "Starter", "Advanced", "Elite"
    var/faction                      // KEEP for display/lore (NEU/NT-C/SYN-C)

    // NEW: Rarity-Based Unlock Requirements
    var/list/unlock_cost_parts = list()  // Mixed rarity requirements
    // Example: list("basic" = 2, "advanced" = 1) → needs 2 basic + 1 advanced parts

    var/rarity_threshold = "basic"   // Minimum rarity tier to unlock
    var/total_cost_credits = 0       // Sum of part values (for display)

    // Stats (unchanged from Round 3)
    var/crew_capacity
    var/estimated_speed
    var/combat_rating
    var/list/special_features = list()
```

**Example Ship Unlock Costs:**

```
STARTER TIER (free selection):
- Junker-class: Free (starter selection)
- Scout-class: Free (starter selection)
- Hauler-class: Free (starter selection)

BASIC TIER:
- Box: 2 basic parts (20k credits equivalent)
- Kilo: 3 basic parts (30k credits)
- Corvid: 2 basic + 1 advanced (35k credits)

ADVANCED TIER:
- Delta: 2 advanced parts (30k credits)
- Bogatyr: 1 advanced + 1 rare (35k credits)
- Li Tieguai: 3 advanced parts (45k credits)

RARE TIER:
- Gecko: 2 rare parts (40k credits)
- Shetland: 1 rare + 1 superior (45k credits)
- Hammerhead: 3 rare parts (60k credits)

SUPERIOR TIER (flagships):
- Carrier-class: 2 superior + 2 rare (90k credits)
- Dreadnought-class: 3 superior + 1 rare (95k credits)

Progression Balance:
- Round-end reward: 100 credits + 1 random part (weighted toward basic)
- Average rounds to first unlock: 3-4 rounds (with basic parts)
- Average rounds to flagship: 40-50 rounds (mix of earning/finding/crafting)
```

**TGUI Catalog Changes for Rarity:**

```typescript
// REVISED DATA INTERFACE
interface ShipCatalogData {
  player_credits: number;
  player_parts: Record<string, number>;  // {"basic": 5, "advanced": 2, "rare": 1, "superior": 0}
  player_antag_parts: Record<string, number>;  // Separate inventory
  ships_unlocked: string[];
  has_spawned_this_round: boolean;
  regular_ships: RegularShip[];
  antag_ships: AntagShip[];
}

interface RegularShip {
  template_type: string;
  name: string;
  faction: string;  // KEEP for display/filtering (visual only)

  // NEW: Rarity-based unlocking
  unlock_requirements: PartRequirement[];  // [{rarity: "basic", count: 2}, {rarity: "advanced", count: 1}]
  total_cost_credits: number;  // Sum of part values for display

  preview_image: string;
  crew_capacity: number;
  description: string;
  variants: ShipVariant[];
  is_unlocked: boolean;

  // NEW: Rarity threshold indicator
  minimum_rarity: string;  // "basic" | "advanced" | "rare" | "superior"
}

interface PartRequirement {
  rarity: string;      // "basic", "advanced", etc.
  count: number;       // Required quantity
  player_has: number;  // Current player inventory (for progress bar)
}
```

**Revised TGUI Catalog UI with Rarity Filters:**

```
┌────────────────────────────────────────────────────────────┐
│ SHIP CATALOG                [Credits: 50,000] [Extract]   │
│ ┌──────────┬──────────┐                                    │
│ │ Regular  │  Antag   │  [Search: ___]                    │
│ └──────────┴──────────┘                                    │
│                                                             │
│ Filter Rarity: [All] [Basic] [Advanced] [Rare] [Superior] │
│ Filter Faction: [All] [NEU] [NT-C] [SYN-C] (visual only)  │
│ Sort: [Name] [Cost] [Crew Size] [Rarity]                  │
│                                                             │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│ │  Bogatyr     │ │    Delta     │ │  Hammerhead  │        │
│ │  [PREVIEW]   │ │  [PREVIEW]   │ │  [PREVIEW]   │        │
│ │  ✓ Unlocked  │ │  🔒 Locked   │ │  🔒 Locked   │        │
│ │  NEU • 10ppl │ │  NEU • 9ppl  │ │  NT-C • 15pp │        │
│ │              │ │  Requires:   │ │  Requires:   │        │
│ │  Variants: 2 │ │  ▰▰▱ 2 Basic │ │  ▰▱▱ 1 Rare  │        │
│ │  [SPAWN ▼]   │ │  ▰▱▱ 1 Adv   │ │  ▰▰▱ 2 Adv   │        │
│ │              │ │  (35k cred)  │ │  (70k cred)  │        │
│ │              │ │  [UNLOCK]    │ │  [UNLOCK]    │        │
│ └──────────────┘ └──────────────┘ └──────────────┘        │
│                                                             │
│ Your Parts Inventory:                                      │
│ ● Basic: 5 | ● Advanced: 2 | ● Rare: 1 | ● Superior: 0   │
│                                                             │
│ Antag Parts: [See Antag Tab]                              │
└────────────────────────────────────────────────────────────┘

UI Features:
- Progress bars show 2/2 basic (filled), 0/1 advanced (empty)
- Rarity filter shows only ships requiring that tier or lower
- Faction filter is cosmetic (doesn't gate unlocks, just visual sorting)
- Mixed requirements clearly displayed per ship
```

---

### Adaptation B: Database Persistence Schema

**User Decision (Q7):**
✅ **Database (SQL)** - use existing server database system

**Impact on My Round 3 Proposal:**
- ❌ REMOVE: All savefile extension proposals
- ❌ REMOVE: `/datum/preferences` field additions
- ❌ REMOVE: JSON serialization code
- ✅ ADD: Comprehensive database schema design
- ✅ ADD: Database access layer (DM → SQL)

**Complete Database Schema:**

```sql
-- ============================================================================
-- TABLE 1: Player Credits (Per-Character)
-- ============================================================================
-- User Decision Q6: Credits are per-character, unlocks are account-wide
CREATE TABLE player_credits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    character_slot INTEGER NOT NULL,  -- Per-character storage
    credits INTEGER DEFAULT 0,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(ckey, character_slot),
    CHECK(credits >= 0)
);

CREATE INDEX idx_player_credits_ckey ON player_credits(ckey);
CREATE INDEX idx_player_credits_lookup ON player_credits(ckey, character_slot);

-- ============================================================================
-- TABLE 2: Player Ship Parts (Rarity-Based Inventory)
-- ============================================================================
-- NEW: Rarity tiers replace faction parts (user Q8)
CREATE TABLE player_ship_parts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    part_rarity TEXT NOT NULL,  -- 'basic', 'advanced', 'rare', 'superior'
    quantity INTEGER DEFAULT 0,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(ckey, part_rarity),
    CHECK(quantity >= 0),
    CHECK(part_rarity IN ('basic', 'advanced', 'rare', 'superior'))
);

CREATE INDEX idx_player_parts_ckey ON player_ship_parts(ckey);

-- ============================================================================
-- TABLE 3: Player Antag Parts (Separate Inventory)
-- ============================================================================
-- User Decision Q4/Q5: Antag ships are separate, consumable system
CREATE TABLE player_antag_parts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    antag_type TEXT NOT NULL,  -- 'syndicate_ops', 'blood_cult', 'xenomorph', etc.
    quantity INTEGER DEFAULT 0,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(ckey, antag_type),
    CHECK(quantity >= 0)
);

CREATE INDEX idx_player_antag_parts_ckey ON player_antag_parts(ckey);

-- ============================================================================
-- TABLE 4: Ship Unlocks (Account-Wide)
-- ============================================================================
-- User Decision Q6: Unlocks are account-wide (all characters share)
CREATE TABLE player_ship_unlocks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    ship_template_type TEXT NOT NULL,  -- '/datum/map_template/shuttle/voidcrew/delta'
    unlocked_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(ckey, ship_template_type)
);

CREATE INDEX idx_player_unlocks_ckey ON player_ship_unlocks(ckey);
CREATE INDEX idx_player_unlocks_template ON player_ship_unlocks(ship_template_type);

-- ============================================================================
-- TABLE 5: Ship Spawns (Per-Round Tracking)
-- ============================================================================
-- User Decision Q1: Ships spawn free once per round after unlock
CREATE TABLE round_ship_spawns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    round_id INTEGER NOT NULL,  -- From SSovermap or ticker
    ckey TEXT NOT NULL,
    ship_template_type TEXT NOT NULL,
    spawned_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(round_id, ckey, ship_template_type)
);

CREATE INDEX idx_round_spawns_round ON round_ship_spawns(round_id);
CREATE INDEX idx_round_spawns_player ON round_ship_spawns(round_id, ckey);

-- ============================================================================
-- TABLE 6: Part Extraction Log (Audit Trail)
-- ============================================================================
-- User Decision Q10/Q19: Physical parts must be extracted via device
CREATE TABLE part_extraction_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    part_rarity TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    extraction_method TEXT,  -- 'device', 'battlepass', 'admin_grant', 'round_end'
    extracted_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_extraction_log_ckey ON part_extraction_log(ckey);
CREATE INDEX idx_extraction_log_timestamp ON part_extraction_log(extracted_at);

-- ============================================================================
-- TABLE 7: Credit Transaction Log (Audit Trail)
-- ============================================================================
-- Admin tools, anti-cheat, economy balancing
CREATE TABLE credit_transaction_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    character_slot INTEGER NOT NULL,
    amount INTEGER NOT NULL,  -- Negative for spending, positive for earning
    reason TEXT,  -- 'round_completion', 'buy_part', 'admin_grant', 'sold_part'
    balance_after INTEGER,
    transaction_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_credit_log_ckey ON credit_transaction_log(ckey);
CREATE INDEX idx_credit_log_timestamp ON credit_transaction_log(transaction_at);

-- ============================================================================
-- TABLE 8: Integration Stubs (For Future Feature Teams)
-- ============================================================================
-- Battlepass Integration (separate 4-agent team)
CREATE TABLE player_battlepass_progress (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    season_id INTEGER NOT NULL,
    xp INTEGER DEFAULT 0,
    tier_unlocked INTEGER DEFAULT 0,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(ckey, season_id)
);

-- Custom Roles Integration (separate 4-agent team)
CREATE TABLE player_custom_roles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    role_id TEXT NOT NULL,
    role_data TEXT,  -- JSON blob for custom role configuration
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(ckey, role_id)
);

-- Automation Crafting Integration (separate 4-agent team)
CREATE TABLE player_automation_blueprints (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    blueprint_id TEXT NOT NULL,
    blueprint_data TEXT,  -- JSON blob for automation setup
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(ckey, blueprint_id)
);
```

**DM Database Access Layer:**

```dm
// ============================================================================
// DATABASE MANAGER SINGLETON
// ============================================================================
/datum/ship_economy_database
    var/datum/DBConnection/connection

    proc/initialize()
        connection = SSdbcore.Connect()
        if(!connection)
            log_world("ERROR: Ship economy database connection failed!")
            return FALSE

        // Create tables if not exist (run migrations)
        create_tables()
        return TRUE

    proc/create_tables()
        // Run all CREATE TABLE IF NOT EXISTS statements
        // (SQL from above)

    // ========================================================================
    // CREDITS OPERATIONS (Per-Character)
    // ========================================================================
    proc/get_credits(ckey, character_slot)
        var/datum/DBQuery/query = SSdbcore.NewQuery(
            "SELECT credits FROM player_credits WHERE ckey = :ckey AND character_slot = :slot",
            list("ckey" = ckey, "slot" = character_slot)
        )
        query.Execute()
        if(query.NextRow())
            return text2num(query.item[1])
        return 0  // Default if no record

    proc/add_credits(ckey, character_slot, amount, reason)
        // Start transaction
        var/current = get_credits(ckey, character_slot)
        var/new_total = current + amount

        // Update credits
        var/datum/DBQuery/update = SSdbcore.NewQuery(
            "INSERT INTO player_credits (ckey, character_slot, credits) \
             VALUES (:ckey, :slot, :amount) \
             ON CONFLICT(ckey, character_slot) \
             DO UPDATE SET credits = credits + :amount, last_updated = CURRENT_TIMESTAMP",
            list("ckey" = ckey, "slot" = character_slot, "amount" = amount)
        )
        update.Execute()

        // Log transaction
        var/datum/DBQuery/log = SSdbcore.NewQuery(
            "INSERT INTO credit_transaction_log (ckey, character_slot, amount, reason, balance_after) \
             VALUES (:ckey, :slot, :amount, :reason, :balance)",
            list("ckey" = ckey, "slot" = character_slot, "amount" = amount, "reason" = reason, "balance" = new_total)
        )
        log.Execute()

        return new_total

    // ========================================================================
    // PARTS OPERATIONS (Rarity-Based)
    // ========================================================================
    proc/get_parts(ckey)
        var/list/parts = list("basic" = 0, "advanced" = 0, "rare" = 0, "superior" = 0)
        var/datum/DBQuery/query = SSdbcore.NewQuery(
            "SELECT part_rarity, quantity FROM player_ship_parts WHERE ckey = :ckey",
            list("ckey" = ckey)
        )
        query.Execute()
        while(query.NextRow())
            var/rarity = query.item[1]
            var/quantity = text2num(query.item[2])
            parts[rarity] = quantity
        return parts

    proc/add_part(ckey, part_rarity, quantity, extraction_method)
        // Update inventory
        var/datum/DBQuery/update = SSdbcore.NewQuery(
            "INSERT INTO player_ship_parts (ckey, part_rarity, quantity) \
             VALUES (:ckey, :rarity, :qty) \
             ON CONFLICT(ckey, part_rarity) \
             DO UPDATE SET quantity = quantity + :qty, last_updated = CURRENT_TIMESTAMP",
            list("ckey" = ckey, "rarity" = part_rarity, "qty" = quantity)
        )
        update.Execute()

        // Log extraction
        var/datum/DBQuery/log = SSdbcore.NewQuery(
            "INSERT INTO part_extraction_log (ckey, part_rarity, quantity, extraction_method) \
             VALUES (:ckey, :rarity, :qty, :method)",
            list("ckey" = ckey, "rarity" = part_rarity, "qty" = quantity, "method" = extraction_method)
        )
        log.Execute()

        return TRUE

    proc/spend_parts(ckey, list/requirements)
        // requirements = list("basic" = 2, "advanced" = 1)
        // Validate sufficient parts first
        var/list/current_parts = get_parts(ckey)
        for(var/rarity in requirements)
            if(current_parts[rarity] < requirements[rarity])
                return FALSE

        // Deduct parts (transaction)
        for(var/rarity in requirements)
            var/datum/DBQuery/deduct = SSdbcore.NewQuery(
                "UPDATE player_ship_parts \
                 SET quantity = quantity - :qty, last_updated = CURRENT_TIMESTAMP \
                 WHERE ckey = :ckey AND part_rarity = :rarity",
                list("ckey" = ckey, "rarity" = rarity, "qty" = requirements[rarity])
            )
            deduct.Execute()

        return TRUE

    // ========================================================================
    // SHIP UNLOCKS OPERATIONS (Account-Wide)
    // ========================================================================
    proc/get_unlocked_ships(ckey)
        var/list/unlocked = list()
        var/datum/DBQuery/query = SSdbcore.NewQuery(
            "SELECT ship_template_type FROM player_ship_unlocks WHERE ckey = :ckey",
            list("ckey" = ckey)
        )
        query.Execute()
        while(query.NextRow())
            unlocked += query.item[1]
        return unlocked

    proc/unlock_ship(ckey, ship_template_type)
        var/datum/DBQuery/insert = SSdbcore.NewQuery(
            "INSERT OR IGNORE INTO player_ship_unlocks (ckey, ship_template_type) \
             VALUES (:ckey, :template)",
            list("ckey" = ckey, "template" = ship_template_type)
        )
        insert.Execute()
        return TRUE

    proc/is_ship_unlocked(ckey, ship_template_type)
        var/datum/DBQuery/query = SSdbcore.NewQuery(
            "SELECT 1 FROM player_ship_unlocks \
             WHERE ckey = :ckey AND ship_template_type = :template",
            list("ckey" = ckey, "template" = ship_template_type)
        )
        query.Execute()
        return query.NextRow()  // Returns TRUE if found

    // ========================================================================
    // PER-ROUND SPAWN TRACKING
    // ========================================================================
    proc/has_spawned_ship_this_round(ckey, ship_template_type, round_id)
        var/datum/DBQuery/query = SSdbcore.NewQuery(
            "SELECT 1 FROM round_ship_spawns \
             WHERE round_id = :round AND ckey = :ckey AND ship_template_type = :template",
            list("round" = round_id, "ckey" = ckey, "template" = ship_template_type)
        )
        query.Execute()
        return query.NextRow()

    proc/record_ship_spawn(ckey, ship_template_type, round_id)
        var/datum/DBQuery/insert = SSdbcore.NewQuery(
            "INSERT INTO round_ship_spawns (round_id, ckey, ship_template_type) \
             VALUES (:round, :ckey, :template)",
            list("round" = round_id, "ckey" = ckey, "template" = ship_template_type)
        )
        insert.Execute()
        return TRUE

// ============================================================================
// GLOBAL SINGLETON INSTANCE
// ============================================================================
var/global/datum/ship_economy_database/ShipEconomyDB

/hook/startup/proc/initialize_ship_economy_db()
    ShipEconomyDB = new /datum/ship_economy_database()
    ShipEconomyDB.initialize()
```

**Client Integration:**

```dm
/client
    var/cached_credits = null
    var/list/cached_parts = null
    var/list/cached_unlocked_ships = null

    proc/load_ship_economy_data()
        // Load on login
        cached_credits = ShipEconomyDB.get_credits(ckey, prefs.default_slot)
        cached_parts = ShipEconomyDB.get_parts(ckey)
        cached_unlocked_ships = ShipEconomyDB.get_unlocked_ships(ckey)

    proc/earn_credits(amount, reason)
        var/new_total = ShipEconomyDB.add_credits(ckey, prefs.default_slot, amount, reason)
        cached_credits = new_total
        to_chat(src, "<span class='notice'>+[amount] Credits: [reason] (Total: [new_total])</span>")

    proc/spend_credits(amount, reason)
        return earn_credits(-amount, reason)  // Negative amount

    proc/add_part(rarity, quantity, method)
        ShipEconomyDB.add_part(ckey, rarity, quantity, method)
        cached_parts = ShipEconomyDB.get_parts(ckey)  // Refresh cache
        to_chat(src, "<span class='notice'>+[quantity]x [rarity] ship part ([method])</span>")
```

---

### Adaptation C: Physical Parts + Extraction Device

**User Decision (Q10, Q19):**
> "ship parts are used for buying blueprints. you get them through finding them in world and the battlepass. you have to 'Extract' the ship parts somehow to put them into your account rather than just being able to use them in hand. maybe a device that you can insert them into."

**Impact on My Round 3 Proposal:**
- ❌ REMOVE: N-key digital → physical conversion (user explicitly removed this)
- ❌ REMOVE: Physical trading economy (one-way extraction only)
- ✅ ADD: Physical part items (/obj/item/ship_part)
- ✅ ADD: Extraction device machine
- ✅ ADD: Extraction device TGUI interface
- ✅ ADD: Loot spawners for ruins/planets

**Physical Ship Part Item:**

```dm
// ============================================================================
// PHYSICAL SHIP PART ITEMS
// ============================================================================
/obj/item/ship_part
    name = "ship part"
    desc = "A component used in ship blueprint unlocking. Must be extracted to your account before use."
    icon = 'icons/obj/ship_parts.dmi'
    icon_state = "part_basic"
    w_class = WEIGHT_CLASS_SMALL

    var/part_rarity = "basic"  // basic, advanced, rare, superior
    var/extracted = FALSE  // Once extracted, becomes inert

    // Rarity-specific properties
    var/static/list/rarity_colors = list(
        "basic" = "#CCCCCC",
        "advanced" = "#6699FF",
        "rare" = "#CC66FF",
        "superior" = "#FFAA00"
    )

    var/static/list/rarity_values = list(
        "basic" = 10000,
        "advanced" = 15000,
        "rare" = 20000,
        "superior" = 25000
    )

/obj/item/ship_part/Initialize()
    . = ..()
    update_appearance()
    update_name()

/obj/item/ship_part/proc/update_name()
    name = "[uppertext(copytext(part_rarity, 1, 2))][copytext(part_rarity, 2)] ship part"
    desc = "A [part_rarity]-tier ship component. Value: [rarity_values[part_rarity]] credits. Must be extracted to your account to use."

/obj/item/ship_part/proc/update_appearance()
    icon_state = "part_[part_rarity]"
    color = rarity_colors[part_rarity]

/obj/item/ship_part/examine(mob/user)
    . = ..()
    . += "<span class='notice'>Rarity: <b>[uppertext(part_rarity)]</b></span>"
    . += "<span class='notice'>Credit Value: <b>[rarity_values[part_rarity]]</b></span>"
    if(extracted)
        . += "<span class='warning'>This part has already been extracted and is now inert.</span>"
    else
        . += "<span class='info'>Insert into a Ship Part Extraction Device to add to your account.</span>"

/obj/item/ship_part/attack_self(mob/user)
    if(extracted)
        to_chat(user, "<span class='warning'>This part has already been extracted!</span>")
        return
    to_chat(user, "<span class='notice'>You need to insert this into a Ship Part Extraction Device.</span>")

// Subtype variants for spawning
/obj/item/ship_part/basic
    part_rarity = "basic"

/obj/item/ship_part/advanced
    part_rarity = "advanced"

/obj/item/ship_part/rare
    part_rarity = "rare"

/obj/item/ship_part/superior
    part_rarity = "superior"
```

**Extraction Device Machine:**

```dm
// ============================================================================
// EXTRACTION DEVICE
// ============================================================================
/obj/machinery/ship_part_extractor
    name = "ship part extraction device"
    desc = "A specialized device that extracts ship parts into your persistent account. Insert parts to deposit them."
    icon = 'icons/obj/machines/economy.dmi'
    icon_state = "extractor"
    density = TRUE
    use_power = IDLE_POWER_USE
    idle_power_usage = 20

    var/obj/item/ship_part/loaded_part = null
    var/extracting = FALSE
    var/extraction_time = 3 SECONDS

/obj/machinery/ship_part_extractor/examine(mob/user)
    . = ..()
    if(loaded_part)
        . += "<span class='notice'>Contains: [loaded_part.name]</span>"
        . += "<span class='info'>Use the interface to extract it.</span>"
    else:
        . += "<span class='info'>Insert a ship part to begin extraction.</span>"

/obj/machinery/ship_part_extractor/attackby(obj/item/I, mob/user, params)
    if(istype(I, /obj/item/ship_part))
        if(loaded_part)
            to_chat(user, "<span class='warning'>There's already a part loaded!</span>")
            return

        var/obj/item/ship_part/part = I
        if(part.extracted)
            to_chat(user, "<span class='warning'>This part has already been extracted!</span>")
            return

        if(!user.transferItemToLoc(part, src))
            return

        loaded_part = part
        to_chat(user, "<span class='notice'>You insert [part.name] into [src].</span>")
        playsound(src, 'sound/machines/click.ogg', 50, TRUE)
        ui_interact(user)
        return

    return ..()

/obj/machinery/ship_part_extractor/ui_interact(mob/user, datum/tgui/ui)
    ui = SStgui.try_update_ui(user, src, ui)
    if(!ui)
        ui = new(user, src, "ShipPartExtractor")
        ui.open()

/obj/machinery/ship_part_extractor/ui_data(mob/user)
    var/list/data = list()

    if(loaded_part)
        data["loaded_part"] = list(
            "name" = loaded_part.name,
            "rarity" = loaded_part.part_rarity,
            "value" = loaded_part.rarity_values[loaded_part.part_rarity],
            "extracted" = loaded_part.extracted
        )
    else:
        data["loaded_part"] = null

    data["extracting"] = extracting
    data["extraction_time"] = extraction_time / 10  // Convert to seconds for display

    // Show player's current inventory
    if(user.client)
        data["player_parts"] = user.client.cached_parts || ShipEconomyDB.get_parts(user.ckey)
        data["player_credits"] = user.client.cached_credits || ShipEconomyDB.get_credits(user.ckey, user.client.prefs.default_slot)

    return data

/obj/machinery/ship_part_extractor/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
    . = ..()
    if(.)
        return

    var/mob/user = usr

    switch(action)
        if("extract")
            if(!loaded_part)
                return FALSE
            if(loaded_part.extracted)
                return FALSE
            if(extracting)
                return FALSE

            extracting = TRUE
            ui.send_update()

            playsound(src, 'sound/machines/terminal_processing.ogg', 50, TRUE)

            if(!do_after(user, extraction_time, target = src))
                extracting = FALSE
                return TRUE

            // Perform extraction
            user.client.add_part(loaded_part.part_rarity, 1, "extraction_device")
            loaded_part.extracted = TRUE
            loaded_part.update_name()
            loaded_part.desc += " This part has been extracted and is now inert."

            playsound(src, 'sound/machines/terminal_success.ogg', 50, TRUE)
            to_chat(user, "<span class='notice'><b>Extraction successful!</b> +1 [loaded_part.part_rarity] part added to your account.</span>")

            extracting = FALSE
            return TRUE

        if("eject")
            if(!loaded_part)
                return FALSE
            if(extracting)
                return FALSE

            loaded_part.forceMove(drop_location())
            to_chat(user, "<span class='notice'>You eject [loaded_part] from [src].</span>")
            playsound(src, 'sound/machines/click.ogg', 50, TRUE)
            loaded_part = null
            return TRUE

        if("sell")
            if(!loaded_part)
                return FALSE
            if(extracting)
                return FALSE

            var/value = loaded_part.rarity_values[loaded_part.part_rarity]
            user.client.earn_credits(value, "Sold [loaded_part.part_rarity] part")

            qdel(loaded_part)
            loaded_part = null

            playsound(src, 'sound/machines/terminal_success.ogg', 50, TRUE)
            to_chat(user, "<span class='notice'><b>Part sold!</b> +[value] credits added to your account.</span>")
            return TRUE

    return FALSE
```

**TGUI Extraction Interface:**

```typescript
// tgui/packages/tgui/interfaces/ShipPartExtractor.tsx

import { useBackend } from '../backend';
import { Button, Section, Stack, Box, ProgressBar, LabeledList } from '../components';
import { Window } from '../layouts';

interface ExtractorData {
  loaded_part: {
    name: string;
    rarity: string;
    value: number;
    extracted: boolean;
  } | null;
  extracting: boolean;
  extraction_time: number;
  player_parts: Record<string, number>;
  player_credits: number;
}

const RARITY_COLORS = {
  basic: '#CCCCCC',
  advanced: '#6699FF',
  rare: '#CC66FF',
  superior: '#FFAA00',
};

export const ShipPartExtractor = (props, context) => {
  const { act, data } = useBackend<ExtractorData>(context);
  const { loaded_part, extracting, extraction_time, player_parts, player_credits } = data;

  return (
    <Window width={500} height={400}>
      <Window.Content>
        <Stack fill vertical>
          <Stack.Item>
            <Section title="Ship Part Extraction Device">
              {loaded_part ? (
                <Stack vertical>
                  <Stack.Item>
                    <Box
                      fontSize="1.2em"
                      color={RARITY_COLORS[loaded_part.rarity]}
                      bold
                    >
                      {loaded_part.name}
                    </Box>
                  </Stack.Item>
                  <Stack.Item>
                    <LabeledList>
                      <LabeledList.Item label="Rarity">
                        <Box color={RARITY_COLORS[loaded_part.rarity]}>
                          {loaded_part.rarity.toUpperCase()}
                        </Box>
                      </LabeledList.Item>
                      <LabeledList.Item label="Value">
                        {loaded_part.value} Credits
                      </LabeledList.Item>
                      <LabeledList.Item label="Status">
                        {loaded_part.extracted ? (
                          <Box color="red">EXTRACTED (Inert)</Box>
                        ) : (
                          <Box color="green">Ready for Extraction</Box>
                        )}
                      </LabeledList.Item>
                    </LabeledList>
                  </Stack.Item>
                  <Stack.Item>
                    {extracting ? (
                      <ProgressBar
                        value={0}
                        maxValue={extraction_time}
                        color="blue"
                      >
                        Extracting... ({extraction_time}s)
                      </ProgressBar>
                    ) : (
                      <Stack>
                        <Stack.Item grow>
                          <Button
                            icon="download"
                            content="Extract to Account"
                            disabled={loaded_part.extracted}
                            tooltip="Add this part to your persistent inventory"
                            onClick={() => act('extract')}
                            fluid
                            color="good"
                          />
                        </Stack.Item>
                        <Stack.Item grow>
                          <Button
                            icon="coins"
                            content={`Sell for ${loaded_part.value}`}
                            disabled={loaded_part.extracted}
                            tooltip="Convert directly to credits"
                            onClick={() => act('sell')}
                            fluid
                            color="average"
                          />
                        </Stack.Item>
                        <Stack.Item>
                          <Button
                            icon="eject"
                            content="Eject"
                            onClick={() => act('eject')}
                            color="bad"
                          />
                        </Stack.Item>
                      </Stack>
                    )}
                  </Stack.Item>
                </Stack>
              ) : (
                <Box color="gray" textAlign="center" fontSize="1.1em">
                  Insert a ship part to begin
                </Box>
              )}
            </Section>
          </Stack.Item>

          <Stack.Item grow>
            <Section title="Your Account">
              <Stack vertical>
                <Stack.Item>
                  <Box fontSize="1.1em" bold>
                    Credits: {player_credits.toLocaleString()}
                  </Box>
                </Stack.Item>
                <Stack.Item>
                  <Box bold mb={1}>
                    Ship Parts Inventory:
                  </Box>
                  <Stack>
                    {Object.entries(player_parts).map(([rarity, count]) => (
                      <Stack.Item key={rarity} basis="25%">
                        <Box
                          backgroundColor={RARITY_COLORS[rarity]}
                          p={1}
                          textAlign="center"
                          style={{ borderRadius: '4px' }}
                        >
                          <Box bold>{rarity.toUpperCase()}</Box>
                          <Box fontSize="1.5em">{count}</Box>
                        </Box>
                      </Stack.Item>
                    ))}
                  </Stack>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
```

**Spawning Physical Parts in World:**

```dm
// ============================================================================
// LOOT SPAWNER FOR RUINS
// ============================================================================
/obj/effect/spawner/random/ship_part
    name = "ship part spawner"
    icon = 'icons/effects/landmarks.dmi'
    icon_state = "x2"

    var/list/rarity_weights = list(
        "basic" = 50,      // 50% chance
        "advanced" = 30,   // 30% chance
        "rare" = 15,       // 15% chance
        "superior" = 5     // 5% chance
    )

/obj/effect/spawner/random/ship_part/Initialize(mapload)
    . = ..()

    var/chosen_rarity = pickweight(rarity_weights)
    var/obj/item/ship_part/part = new(loc)
    part.part_rarity = chosen_rarity
    part.update_appearance()
    part.update_name()

    return INITIALIZE_HINT_QDEL  // Delete spawner after spawning part

// Variants for specific locations
/obj/effect/spawner/random/ship_part/guaranteed_advanced
    rarity_weights = list("advanced" = 100)

/obj/effect/spawner/random/ship_part/rare_only
    rarity_weights = list("rare" = 70, "superior" = 30)

/obj/effect/spawner/random/ship_part/superior_guaranteed
    rarity_weights = list("superior" = 100)

// Placement in ruins
// Mappers add these to .dmm files:
// - Basic parts: Common ruins, asteroid caves, derelict ships
// - Advanced parts: Harder ruins, deep space anomalies
// - Rare parts: Dangerous ruins, boss encounters, planet cores
// - Superior parts: Extreme endgame zones, unique locations
```

---

### Adaptation D: Integration with 3 New Feature Teams

**User Decision:**
- Battlepass + XP System (separate 4-agent team)
- Custom Roles + Equipment Marketplace (separate 4-agent team)
- Automation Crafting Minigame (separate 4-agent team)

**Impact on My Round 3 Proposal:**
- ✅ EXPAND: Pluggable architecture now has 3 integration points
- ✅ ADD: Integration contracts (APIs between systems)
- ✅ ADD: Stub implementations (enabled=FALSE until teams deliver)

**Integration Contracts:**

```dm
// ============================================================================
// INTEGRATION CONTRACT: Battlepass System
// ============================================================================
// Location: voidcrew/modules/ship_economy/integrations/battlepass.dm

/datum/ship_economy_integration/battlepass
    var/enabled = FALSE  // Set TRUE when battlepass team delivers

    // ========================================================================
    // CALLED BY BATTLEPASS TEAM → SHIP ECONOMY
    // ========================================================================

    // When battlepass tier is unlocked, grant rewards
    proc/grant_battlepass_reward(client/C, reward_type, reward_data)
        switch(reward_type)
            if("ship_part")
                var/rarity = reward_data["rarity"]  // "basic", "advanced", etc.
                var/quantity = reward_data["quantity"] || 1
                C.add_part(rarity, quantity, "battlepass_tier_[reward_data["tier"]]")
                return TRUE

            if("credits")
                var/amount = reward_data["amount"]
                C.earn_credits(amount, "Battlepass Tier [reward_data["tier"]]")
                return TRUE

            if("ship_unlock")
                var/ship_template = text2path(reward_data["template_type"])
                ShipEconomyDB.unlock_ship(C.ckey, "[ship_template]")
                C.cached_unlocked_ships += "[ship_template]"
                to_chat(C, "<span class='boldnotice'>BATTLEPASS REWARD: [reward_data["ship_name"]] unlocked!</span>")
                return TRUE

        return FALSE

    // ========================================================================
    // CALLED BY SHIP ECONOMY → BATTLEPASS TEAM
    // ========================================================================

    // Award XP when XP-eligible event occurs
    proc/award_xp(client/C, xp_amount, source)
        if(!enabled)
            return

        // This is for battlepass team to implement
        // Example: battlepass_system.grant_xp(C, xp_amount, source)
        // Sources: "ship_spawned", "ship_destroyed", "round_completed"

// ============================================================================
// INTEGRATION CONTRACT: Custom Roles System
// ============================================================================
// Location: voidcrew/modules/ship_economy/integrations/custom_roles.dm

/datum/ship_economy_integration/custom_roles
    var/enabled = FALSE

    // ========================================================================
    // CALLED BY SHIP ECONOMY → CUSTOM ROLES TEAM
    // ========================================================================

    // Apply custom role configuration during ship spawn
    proc/apply_custom_roles(obj/structure/overmap/ship/new_ship, client/purchaser)
        if(!enabled)
            return FALSE

        // Check if player has custom role configuration for this ship
        // This is for custom roles team to implement
        // custom_roles_system.apply_to_ship(new_ship, purchaser)
        return FALSE

    // Check if player has custom roles configured
    proc/has_custom_roles(client/C, ship_template_type)
        if(!enabled)
            return FALSE
        // Check custom roles database
        return FALSE

    // Open custom roles TGUI
    proc/open_role_customizer(client/C, ship_template_type)
        if(!enabled)
            return
        // custom_roles_system.open_ui(C, ship_template_type)

    // ========================================================================
    // CALLED BY CUSTOM ROLES TEAM → SHIP ECONOMY
    // ========================================================================

    // (None needed - custom roles reads but doesn't write ship economy)
    // Custom roles team queries unlocked ships, current credits for purchasing equipment

// ============================================================================
// INTEGRATION CONTRACT: Automation Crafting
// ============================================================================
// Location: voidcrew/modules/ship_economy/integrations/automation.dm

/datum/ship_economy_integration/automation
    var/enabled = FALSE

    // ========================================================================
    // CALLED BY AUTOMATION TEAM → SHIP ECONOMY
    // ========================================================================

    // When automation system crafts a ship part
    proc/on_part_crafted(client/C, part_rarity, quantity)
        if(!enabled)
            return

        // Grant the crafted parts
        C.add_part(part_rarity, quantity, "automation_crafting")

        // Award bonus credits for crafting
        var/bonus = quantity * 1000  // 1000 credits per part crafted
        C.earn_credits(bonus, "Automation Crafting Bonus")

    // ========================================================================
    // CALLED BY SHIP ECONOMY → AUTOMATION TEAM
    // ========================================================================

    // Query if player has blueprint for crafting this part rarity
    proc/can_craft_part(client/C, part_rarity)
        if(!enabled)
            return FALSE
        // Check automation system
        // return automation_system.has_blueprint(C, part_rarity)
        return FALSE

    // Open automation UI from catalog
    proc/open_automation_ui(client/C, part_rarity)
        if(!enabled)
            return
        // automation_system.open_ui(C, part_rarity)

// ============================================================================
// SUBSYSTEM INTEGRATION MANAGER
// ============================================================================
/datum/controller/subsystem/ship_economy
    var/datum/ship_economy_integration/battlepass/battlepass_integration
    var/datum/ship_economy_integration/custom_roles/custom_roles_integration
    var/datum/ship_economy_integration/automation/automation_integration

/datum/controller/subsystem/ship_economy/Initialize()
    . = ..()

    battlepass_integration = new /datum/ship_economy_integration/battlepass()
    custom_roles_integration = new /datum/ship_economy_integration/custom_roles()
    automation_integration = new /datum/ship_economy_integration/automation()
```

**Modified Ship Spawn Flow with Integrations:**

```dm
/mob/new_player/proc/spawn_ship_from_catalog(datum/map_template/shuttle/voidcrew/template)
    // Validation checks (unlocked, not spawned this round, etc.)
    // ...

    // CREATE SHIP
    var/obj/structure/overmap/ship/new_ship = SSshuttle.create_ship(template)
    if(!new_ship)
        return FALSE

    // INTEGRATION POINT 1: Apply custom roles (if enabled)
    if(SSship_economy.custom_roles_integration.enabled)
        SSship_economy.custom_roles_integration.apply_custom_roles(new_ship, client)

    // Track spawn
    var/round_id = SSovermap.current_round_id || 1
    ShipEconomyDB.record_ship_spawn(client.ckey, "[template.type]", round_id)
    client.prefs.ships_spawned_this_round += template.type

    // INTEGRATION POINT 2: Award XP for ship spawn (if battlepass enabled)
    if(SSship_economy.battlepass_integration.enabled)
        SSship_economy.battlepass_integration.award_xp(client, 50, "ship_spawn")

    // Spawn player
    AttemptSpawnOnShip(new_ship.job_slots[1], new_ship)
    return TRUE
```

**Ship Catalog TGUI with Integration Buttons:**

```typescript
// Additional buttons in ship detail panel (ShipCatalog.tsx)

{is_unlocked && (
  <Stack>
    <Stack.Item grow>
      <Button
        icon="rocket"
        content="Spawn Ship"
        disabled={has_spawned_this_round}
        onClick={() => act('spawn_ship', { template: ship.template_type })}
        color="good"
        fluid
      />
    </Stack.Item>

    {/* INTEGRATION: Custom Roles */}
    {custom_roles_enabled && (
      <Stack.Item>
        <Button
          icon="users-cog"
          content="Customize Crew"
          tooltip="Configure custom roles for this ship"
          onClick={() => act('open_role_customizer', { template: ship.template_type })}
          color="average"
        />
      </Stack.Item>
    )}
  </Stack>
)}

{/* INTEGRATION: Automation Crafting */}
{automation_enabled && !is_unlocked && (
  <Box mt={1}>
    <Button
      icon="industry"
      content="View Automation Recipes"
      tooltip="Craft required parts via automation"
      onClick={() => act('open_automation', { requirements: ship.unlock_requirements })}
      color="blue"
      fluid
    />
  </Box>
)}

{/* Show which parts can be crafted */}
{automation_enabled && (
  <Box mt={1}>
    <Text>Parts you can craft via automation:</Text>
    {ship.unlock_requirements.map((req) => (
      automation_system.can_craft(req.rarity) && (
        <Box color="green">✓ {req.rarity} (x{req.count})</Box>
      )
    ))}
  </Box>
)}
```

---

### Adaptation E: Starter Ship Selection System

**User Decision (Q2, Q3):**
> "You should be able to choose your starter ship from the starter templates, and then you get the blueprint for it. You should be able to upgrade your starter ship like all the others."

**Implementation:**

```dm
// ============================================================================
// STARTER SHIP SELECTION
// ============================================================================
/datum/preferences
    var/starter_ship_selected = FALSE
    var/starter_ship_template = null  // Chosen starter template type

/mob/new_player/proc/select_starter_ship()
    if(client.prefs.starter_ship_selected)
        return  // Already selected

    // Build list of starter ships (tier="Starter")
    var/list/starter_ships = list()
    for(var/datum/map_template/shuttle/voidcrew/template as anything in SSovermap.ship_catalog)
        var/datum/ship_catalog_entry/entry = SSovermap.ship_catalog[template]
        if(entry.tier == "Starter")
            starter_ships[entry.display_name] = template

    // Show selection TGUI (or fallback to tgui_input_list)
    var/choice = tgui_input_list(src, "Choose your starter ship (permanent unlock)", "Starter Selection", starter_ships)
    if(!choice)
        return

    var/datum/map_template/shuttle/voidcrew/chosen_template = starter_ships[choice]

    // Unlock starter ship permanently
    ShipEconomyDB.unlock_ship(client.ckey, "[chosen_template.type]")
    client.prefs.starter_ship_template = chosen_template.type
    client.prefs.starter_ship_selected = TRUE
    client.prefs.save_preferences()
    client.cached_unlocked_ships += "[chosen_template.type]"

    to_chat(src, "<span class='boldnotice'>Starter ship selected: [choice]! This ship is now permanently unlocked.</span>")
    to_chat(src, "<span class='notice'>You can spawn this ship (and any other unlocked ships) once per round.</span>")
    to_chat(src, "<span class='info'>Your starter ship can be upgraded like all ships (slots + gear via Custom Roles system).</span>")

/mob/new_player/proc/select_ship()
    // NEW FLOW: Check if player needs starter selection
    if(!client.prefs.starter_ship_selected)
        select_starter_ship()
        return

    // Show main ship selection menu
    var/list/choices = list()
    choices["Browse Ship Catalog"] = "catalog"

    // Show active ships if any exist
    var/list/active_ships = SSovermap.get_active_player_ships()
    if(active_ships.len)
        choices["Join Existing Ship"] = "latejoin"

    // BACKWARD COMPATIBILITY: Keep auto-spawn initial ship (user Q3)
    choices["Spawn on Station Ship"] = "auto"

    var/choice = tgui_input_list(src, "Ship Selection", "Choose Action", choices)
    if(!choice)
        return

    switch(choices[choice])
        if("catalog")
            open_ship_catalog()
        if("latejoin")
            show_latejoin_ships()
        if("auto")
            spawn_on_auto_ship()
```

**Starter Ship Template Examples:**

```dm
/datum/map_template/shuttle/voidcrew/starter/junker
    name = "Junker-class Scavenger"
    short_name = "Junker"
    faction_prefix = NEUTRAL_SHIP
    unlock_cost = 0  // Free starter (no parts required)
    preview_image = "starter_junker.png"
    description = "A small, scrappy vessel perfect for beginners. Built from salvaged parts, it's not pretty but it gets the job done. Excels at scavenging and salvage operations."
    crew_capacity = 4
    tier = "Starter"

    unlock_cost_parts = list()  // No parts needed

    job_slots = list(
        list("name" = "Captain", "slots" = 1, "officer" = TRUE),
        list("name" = "Engineer", "slots" = 1),
        list("name" = "Crewmate", "slots" = 2),
    )

/datum/map_template/shuttle/voidcrew/starter/scout
    name = "Scout-class Explorer"
    short_name = "Scout"
    faction_prefix = NEUTRAL_SHIP
    unlock_cost = 0
    preview_image = "starter_scout.png"
    description = "A fast, agile ship designed for exploration. Light armor but excellent sensors. Perfect for discovering new ruins and anomalies."
    crew_capacity = 3
    tier = "Starter"

    unlock_cost_parts = list()

    job_slots = list(
        list("name" = "Pilot", "slots" = 1, "officer" = TRUE),
        list("name" = "Scientist", "slots" = 1),
        list("name" = "Crewmate", "slots" = 1),
    )

/datum/map_template/shuttle/voidcrew/starter/hauler
    name = "Hauler-class Freighter"
    short_name = "Hauler"
    faction_prefix = NEUTRAL_SHIP
    unlock_cost = 0
    preview_image = "starter_hauler.png"
    description = "A cargo-focused vessel with large storage bays. Slow but sturdy. Ideal for players who want to focus on trading and cargo operations."
    crew_capacity = 5
    tier = "Starter"

    unlock_cost_parts = list()

    job_slots = list(
        list("name" = "Captain", "slots" = 1, "officer" = TRUE),
        list("name" = "Cargo Technician", "slots" = 2),
        list("name" = "Crewmate", "slots" = 2),
    )
```

**Note:** User specified starter ships can be upgraded (slots + gear) via Custom Roles system (separate team).

---

### Adaptation F: Dual Antag Ship System

**User Decision (Q4, Q5):**
- ✅ Both large-scale (all crew antag) and small-scale (solo) antag ships
- ✅ Direct purchase (no unlock), consumable per-round

**Implementation:**

```dm
// ============================================================================
// ANTAG SHIP TEMPLATES
// ============================================================================
/datum/map_template/shuttle/voidcrew/antag
    var/is_antag_ship = TRUE
    var/antag_mode = "large"  // "large" or "small"
    var/datum/antagonist/antag_type = /datum/antagonist/traitor
    var/antag_part_type = "syndicate_ops"  // Key for antag parts inventory
    var/antag_part_cost = 1

    unlock_cost = 0  // Never permanently unlocked (direct purchase only)
    tier = "Antag"

// ============================================================================
// LARGE-SCALE ANTAG SHIP (All Crew Convert)
// ============================================================================
/datum/map_template/shuttle/voidcrew/antag/syndicate_cruiser
    name = "Syndicate Strike Cruiser"
    short_name = "Syndicate Cruiser"
    faction_prefix = SYNDICATE_SHIP
    antag_mode = "large"  // All crew convert to antag
    antag_type = /datum/antagonist/nukeop
    antag_part_type = "syndicate_ops"
    antag_part_cost = 1  // Costs 1 syndicate_ops antag part per purchase

    description = "A heavily armed Syndicate warship. WARNING: All crew aboard will be converted to Nuclear Operatives. Coordinate with your team before spawning."
    preview_image = "antag_syndicate_cruiser.png"
    crew_capacity = 8

    job_slots = list(
        list("name" = "Syndicate Commander", "slots" = 1, "officer" = TRUE, "outfit" = /datum/outfit/syndicate/commander),
        list("name" = "Syndicate Operative", "slots" = 5, "outfit" = /datum/outfit/syndicate/operative),
        list("name" = "Syndicate Medic", "slots" = 1, "outfit" = /datum/outfit/syndicate/medic),
        list("name" = "Syndicate Engineer", "slots" = 1, "outfit" = /datum/outfit/syndicate/engineer),
    )

/datum/map_template/shuttle/voidcrew/antag/blood_cult_temple
    name = "Blood Cult Temple Ship"
    short_name = "Cult Temple"
    faction_prefix = SYNDICATE_SHIP
    antag_mode = "large"
    antag_type = /datum/antagonist/cult
    antag_part_type = "blood_cult"
    antag_part_cost = 1

    description = "An ancient temple ship dedicated to Nar-Sie. All crew aboard will become Blood Cultists."
    preview_image = "antag_cult_temple.png"
    crew_capacity = 10

    job_slots = list(
        list("name" = "Cult Leader", "slots" = 1, "officer" = TRUE),
        list("name" = "Cultist", "slots" = 9),
    )

// ============================================================================
// SMALL-SCALE ANTAG SHIP (Solo Only)
// ============================================================================
/datum/map_template/shuttle/voidcrew/antag/solo_infiltrator
    name = "Solo Infiltrator Pod"
    short_name = "Infiltrator"
    faction_prefix = SYNDICATE_SHIP
    antag_mode = "small"  // Solo only, spawner becomes antag
    antag_type = /datum/antagonist/traitor
    antag_part_type = "infiltrator"
    antag_part_cost = 1

    description = "A small stealth vessel for solo operatives. Only you will spawn aboard and become a Traitor. Cannot be joined by other players."
    preview_image = "antag_infiltrator.png"
    crew_capacity = 1

    job_slots = list(
        list("name" = "Infiltrator", "slots" = 1, "officer" = TRUE, "outfit" = /datum/outfit/syndicate/infiltrator),
    )

/datum/map_template/shuttle/voidcrew/antag/solo_assassin_pod
    name = "Solo Assassin Pod"
    short_name = "Assassin"
    faction_prefix = SYNDICATE_SHIP
    antag_mode = "small"
    antag_type = /datum/antagonist/traitor
    antag_part_type = "assassin"
    antag_part_cost = 1

    description = "A compact pod designed for assassination missions. Solo only."
    preview_image = "antag_assassin.png"
    crew_capacity = 1

    job_slots = list(
        list("name" = "Assassin", "slots" = 1, "officer" = TRUE, "outfit" = /datum/outfit/syndicate/assassin),
    )

// ============================================================================
// ANTAG SHIP SPAWN LOGIC
// ============================================================================
/mob/new_player/proc/spawn_antag_ship(datum/map_template/shuttle/voidcrew/antag/template)
    // Validate antag part cost
    var/list/antag_parts = ShipEconomyDB.get_antag_parts(client.ckey)
    if(antag_parts[template.antag_part_type] < template.antag_part_cost)
        to_chat(src, "<span class='warning'>Insufficient antag parts! Need [template.antag_part_cost]x [template.antag_part_type].</span>")
        to_chat(src, "<span class='info'>Antag parts are rare drops or admin grants.</span>")
        return FALSE

    // Confirm purchase (antag parts are CONSUMABLE)
    var/confirm = tgui_alert(src, "Purchase [template.name] for [template.antag_part_cost]x [template.antag_part_type] antag part? This is CONSUMABLE (spent each round).", "Antag Ship Purchase", list("Yes", "No"))
    if(confirm != "Yes")
        return FALSE

    // Deduct antag parts (CONSUMABLE, per-round cost)
    ShipEconomyDB.spend_antag_parts(client.ckey, template.antag_part_type, template.antag_part_cost)

    // Create ship
    var/obj/structure/overmap/ship/new_ship = SSshuttle.create_ship(template)
    if(!new_ship)
        // Refund if ship creation failed
        ShipEconomyDB.add_antag_part(client.ckey, template.antag_part_type, template.antag_part_cost, "refund_failed_spawn")
        return FALSE

    // Handle antag mode
    switch(template.antag_mode)
        if("large")
            // Mark ship for crew conversion (all joiners become antag)
            new_ship.antag_conversion_enabled = TRUE
            new_ship.antag_conversion_type = template.antag_type
            to_chat(src, "<span class='userdanger'>ANTAG SHIP SPAWNED: All crew joining this ship will become [initial(template.antag_type.name)]s!</span>")
            to_chat(src, "<span class='warning'>Coordinate with your team! This ship is joinable by other players.</span>")

        if("small")
            // Solo mode: only spawner becomes antag
            var/mob/living/spawned_mob = AttemptSpawnOnShip(new_ship.job_slots[1], new_ship)
            if(spawned_mob)
                var/datum/antagonist/antag = new template.antag_type()
                spawned_mob.mind.add_antag_datum(antag)
                to_chat(spawned_mob, "<span class='userdanger'>You are now a [initial(antag.name)]!</span>")
                to_chat(spawned_mob, "<span class='warning'>This ship is SOLO ONLY. No other players can join.</span>")

            // Lock ship to solo spawner
            new_ship.locked_to_ckey = client.ckey

    // Track spawn (antag ships still respect one-per-round limit)
    var/round_id = SSovermap.current_round_id || 1
    ShipEconomyDB.record_ship_spawn(client.ckey, "[template.type]", round_id)

    return TRUE
```

---

## 3. COMPROMISES I AM WILLING TO MAKE

### Compromise A: Savefile → Database Migration
**Original Position (Round 3):** Extend savefile system (proven, simple)
**Compromise:** Full database schema (user decision Q7)
**Rationale:** Database enables better auditing, admin tools, and scales better for multiple feature teams accessing same data. Long-term benefits outweigh migration complexity.

### Compromise B: Faction Parts → Rarity Tiers
**Original Position:** Faction-specific progression trees (NEU/NT-C/SYN-C)
**Compromise:** Rarity-based universal parts with faction display-only
**Rationale:** User explicitly requested this (Q8); rarity system is simpler, more flexible for future expansion, and avoids faction-gating concerns.

### Compromise C: N-Key Trading → Physical Extraction
**Original Position:** Keep digital ↔ physical conversion for player economy
**Compromise:** One-way extraction only (physical → digital)
**Rationale:** User wants parts found in world, extraction device adds gameplay loop. Physical trading still works (parts can be stolen/traded before extraction).

### Compromise D: Single Timeline → Parallel Feature Teams
**Original Position:** 16-week phased delivery with everything in sequence
**Compromise:** Integration contracts for 3 parallel teams
**Rationale:** Faster overall delivery if teams work simultaneously; my pluggable architecture supports this with clean APIs.

### Compromise E: Custom Roles in Phase 3 → Separate Team
**Original Position:** Crew customization in my Phase 3 (deferred, 4-6 weeks)
**Compromise:** Entirely separate 4-agent team handling custom roles
**Rationale:** Scope is larger than I anticipated; user wants full equipment marketplace and role builder with monkecoin integration. Better to dedicate full team.

### Compromise F: Timeline Reduction (16 weeks → 14 weeks)
**Original Position:** 16-week phased delivery
**Compromise:** 14 weeks (3.5 months)
**Rationale:** Removing savefile complexity, N-key trading, and deferring skins/customization reduces scope. Realistic timeline remains conservative.

---

## 4. NON-NEGOTIABLES

### Non-Negotiable A: Phase 0 Persistence Bug Fix
**Why:** This is a blocking bug. Nothing works correctly until this is fixed. Literally 1 line of code. Foundation must be solid before building on top.
**Impact:** Without this, players lose progress between sessions. All economy features are broken.

### Non-Negotiable B: Pluggable Architecture
**Why:** Three separate feature teams (Battlepass, Custom Roles, Automation) MUST integrate cleanly without collision.
**Impact:** Without integration contracts, teams will merge conflict, duplicate code, and create spaghetti dependencies. Modular design is essential for parallel development.

### Non-Negotiable C: TGUI Catalog (Not BYOND Lists)
**Why:** User explicitly wants visual catalog with ship images (feature request core goal).
**Impact:** This is the primary UX improvement request. Cannot deliver text-only interface. TGUI catalog is the main deliverable.

### Non-Negotiable D: Database Transactions for Currency/Parts
**Why:** Economy systems require ACID guarantees to prevent duplication exploits.
**Impact:** Without transactions, players can dupe parts/credits via race conditions (click spam, network lag, server crashes). Must be transactional.

### Non-Negotiable E: Per-Round Spawn Limits
**Why:** Core game balance decision (prevents spam, encourages ship variety, maintains overmap gameplay).
**Impact:** Without limits, players spawn unlimited ships per round, breaking overmap population balance and causing server lag.

### Non-Negotiable F: Separation of Regular/Antag Systems
**Why:** Antag parts are consumable (per-round), regular parts are permanent unlocks - fundamentally different economies.
**Impact:** Mixing these creates confusion (players expect permanent unlocks, get consumable), balance issues (antag ships too cheap/expensive), and UI clutter.

### Non-Negotiable G: Rarity-Based Progression (Not Faction-Gated)
**Why:** User decision (Q8) explicitly eliminates faction parts.
**Impact:** Cannot gate ships by faction anymore. Rarity tiers are the new progression system. Faction is cosmetic/lore only.

### Non-Negotiable H: Physical Extraction Device
**Why:** User decision (Q10/Q19) specifies parts must be extracted via device.
**Impact:** Cannot allow instant digital deposit. Physical parts must exist in world, be tradeable/stealable until extracted. Adds risk/reward gameplay.

---

## 5. FINAL RECOMMENDED ARCHITECTURE

### Overview

**Total Timeline:** 14 weeks (3.5 months)
**Team Size:** 2 developers (1 DM backend, 1 TGUI frontend)
**Phases:** 5 phases (Foundation → Catalog → Economy → Antag/Starter → Integration → Polish)

---

### PHASE 0: FOUNDATION (Week 1)
**Goal:** Fix critical bugs and establish database schema

**Deliverables:**
- [x] Fix persistence load bug (ships_owned never loads - 1 line fix)
- [x] Create database tables (all 8 tables from schema above)
- [x] Implement database access layer (ShipEconomyDB singleton)
- [x] Migration script (existing players get clean slate - user confirmed no live players)
- [x] Test save/load cycle with database
- [x] Verify existing systems still work (latejoin, ship spawning)

**Testing Requirements:**
1. Create new player → verify database entries initialize
2. Grant parts → verify database writes
3. Restart server → verify database persists
4. Admin tools → verify database queries work

**Team:** 1 developer (DM backend)
**Duration:** 1 week
**Risk:** Low (database already exists on server)

---

### PHASE 1: VISUAL CATALOG + RARITY SYSTEM (Weeks 2-5)
**Goal:** Replace text UI with visual TGUI catalog showing rarity-based progression

**Deliverables:**

**Week 2-3: Catalog Data Layer**
- [x] Implement `/datum/ship_catalog_entry` with rarity fields
- [x] Convert all ship templates to catalog entries (30+ ships)
- [x] Generate ship preview images (manual screenshots in Dream Maker)
- [x] Upload images to asset system
- [x] Test catalog loading on server startup

**Week 4-5: TGUI Catalog Interface**
- [x] Build `ShipCatalog.tsx` component
- [x] Implement rarity filtering/sorting
- [x] Ship detail panel with mixed rarity requirements
- [x] Progress bars for unlock requirements (2/2 basic, 0/1 advanced)
- [x] Integration with database (fetch unlocks, parts inventory)
- [x] Dual tabs (Regular Ships | Antag Ships)
- [x] Faction filtering (visual only, doesn't gate)
- [x] Test catalog browsing, filtering, searching

**Testing Requirements:**
1. Catalog displays all ships correctly
2. Filters work (rarity, faction, unlocked/locked)
3. Progress bars show correct inventory
4. Images load without lag
5. Fallback to text list if TGUI fails

**Team:** 2 developers (1 DM data layer, 1 TGUI interface)
**Duration:** 4 weeks
**Risk:** Medium (TGUI image display needs research)

---

### PHASE 2: THREE-TIER ECONOMY (Weeks 6-9)
**Goal:** Implement Credits → Parts → Blueprints progression

**Deliverables:**

**Week 6-7: Currency System**
- [x] Credit earning system (100 per round base reward)
- [x] Credit spending (buy parts from catalog)
- [x] Transaction logging (audit trail)
- [x] Admin tools (grant credits/parts, view balances)
- [x] Config integration (adjustable reward rates)
- [x] Test credit flow (earn → spend → track)

**Week 8: Unlock System**
- [x] Ship unlock validation (check parts requirements)
- [x] Part spending (deduct from inventory, mixed rarities)
- [x] Permanent unlock tracking (database)
- [x] Per-round spawn tracking (one-spawn limit)
- [x] Test unlock flow (spend parts → unlock → spawn)

**Week 9: Physical Parts + Extraction**
- [x] Physical ship part items (/obj/item/ship_part)
- [x] Extraction device machine
- [x] Extraction device TGUI (ShipPartExtractor.tsx)
- [x] Loot spawners for ruins/planets (rarity-weighted)
- [x] Sell option (part → credits directly)
- [x] Test extraction flow (find part → insert → extract → unlock ship)

**Testing Requirements:**
1. Round-end rewards granted correctly
2. Credits persist across rounds (per-character)
3. Parts persist across rounds (account-wide)
4. Unlock validation prevents double-unlock
5. Per-round spawn limit enforced
6. Physical parts can be extracted once
7. Loot spawners work on ruins/planets

**Team:** 2 developers
**Duration:** 4 weeks
**Risk:** Medium (extraction device TGUI, loot spawner placement)

---

### PHASE 3: ANTAG SHIPS + STARTER SELECTION (Weeks 10-11)
**Goal:** Implement dual antag system and starter ship flow

**Deliverables:**

**Week 10: Antag System**
- [x] Antag parts inventory (separate from regular parts)
- [x] Large-scale antag ships (crew conversion on join)
- [x] Small-scale antag ships (solo mode, locked to spawner)
- [x] Antag ship tab in catalog
- [x] Consumable per-round purchase flow
- [x] Admin grants for antag parts
- [x] Test antag ship spawning (both large/small)

**Week 11: Starter Selection**
- [x] Starter ship selection TGUI (first-time flow)
- [x] 3-5 starter ship templates (Junker, Scout, Hauler, etc.)
- [x] Free permanent unlock on selection
- [x] Backward compatibility (keep auto-spawn station ship)
- [x] Test starter selection (new player → choose → unlock)

**Testing Requirements:**
1. Antag parts separate from regular parts
2. Large antag ships convert all crew joiners
3. Small antag ships lock to solo spawner
4. Antag parts consumed on purchase (not permanent)
5. Starter selection appears for new players only
6. Starter ships unlocked permanently
7. Auto-spawn station ship still works

**Team:** 1 developer
**Duration:** 2 weeks
**Risk:** Low (extends existing systems)

---

### PHASE 4: INTEGRATION POINTS (Week 12)
**Goal:** Implement contracts for 3 parallel feature teams

**Deliverables:**
- [x] Battlepass integration contract (grant parts/credits/unlocks)
- [x] Custom Roles integration hooks (apply to ship on spawn)
- [x] Automation integration (crafted parts deposit to account)
- [x] Documentation for integration APIs (wiki page)
- [x] Stub implementations (enabled=FALSE until teams deliver)
- [x] Test integration contracts (mock calls)

**Testing Requirements:**
1. Battlepass can grant parts/credits/unlocks
2. Custom Roles can apply to ships on spawn
3. Automation can deposit crafted parts
4. Integration disabled by default (no crashes)
5. Documentation is clear for other teams

**Team:** 1 developer
**Duration:** 1 week
**Risk:** Low (stub implementations, no dependencies)

---

### PHASE 5: POLISH + TESTING (Weeks 13-14)
**Goal:** Bug fixes, balance tuning, QA

**Deliverables:**
- [x] Economy balance testing (playtesting sessions, 10+ players)
- [x] Adjust part costs, credit rewards, drop rates based on feedback
- [x] Performance testing (30+ ships in catalog, 50+ players)
- [x] Admin tools refinement (better UI, bulk grants)
- [x] Documentation (player guide, admin guide, dev guide)
- [x] Bug fixes from playtesting
- [x] Final QA pass (edge cases, exploits, crashes)

**Testing Requirements:**
1. Economy feels balanced (not too easy/hard)
2. Average player unlocks first ship in 3-4 rounds
3. Catalog loads quickly (< 2 seconds)
4. No crashes under load
5. Documentation is complete

**Team:** 2 developers + QA
**Duration:** 2 weeks
**Risk:** Medium (balance tuning iterative, requires feedback)

---

## REVISED ECONOMY FLOW

```
┌───────────────────────────────────────────────────────────────┐
│ EARNING CREDITS & PARTS                                       │
├───────────────────────────────────────────────────────────────┤
│ 1. Round completion → 100 credits (per-character)             │
│ 2. Find physical part in world → Extract via device → Account │
│ 3. Battlepass tier unlock → Part/credit rewards (integration) │
│ 4. Automation crafting → Craft parts from materials (future)  │
│ 5. Admin grants → Direct deposit                              │
│ 6. Sell physical parts → Credits (bypass extraction)          │
└───────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────┐
│ SPENDING CREDITS & PARTS                                      │
├───────────────────────────────────────────────────────────────┤
│ 1. Credits → Buy rarity parts from catalog                    │
│    - Basic: 10k credits                                       │
│    - Advanced: 15k credits                                    │
│    - Rare: 20k credits                                        │
│    - Superior: 25k credits                                    │
│                                                                │
│ 2. Parts → Unlock ship blueprints (mixed rarity requirements) │
│    - Example: Delta = 2 basic + 1 advanced = 35k equivalent   │
│    - Once unlocked, permanent (account-wide)                  │
└───────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────┐
│ UNLOCKING & SPAWNING                                          │
├───────────────────────────────────────────────────────────────┤
│ 1. Spend parts → Ship permanently unlocked (account-wide)     │
│ 2. Once unlocked → Spawn free once per round                  │
│ 3. If destroyed → Cannot re-spawn this round                  │
│ 4. Next round → Can spawn again (free)                        │
└───────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────┐
│ ANTAG SHIPS (SEPARATE SYSTEM)                                 │
├───────────────────────────────────────────────────────────────┤
│ 1. Antag parts (separate inventory) → Direct purchase         │
│ 2. Consumable per-round (NOT permanent unlock)                │
│ 3. Large antag ships: All crew convert to antag               │
│ 4. Small antag ships: Solo only, spawner becomes antag        │
│ 5. Pay antag parts each round to spawn                        │
└───────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────┐
│ PROGRESSION BALANCE                                           │
├───────────────────────────────────────────────────────────────┤
│ - Round-end: 100 credits + 1 random part (weighted to basic)  │
│ - First unlock: ~3-4 rounds (basic tier ships)               │
│ - Medium unlock: ~10-15 rounds (advanced tier ships)          │
│ - Flagship unlock: ~40-50 rounds (superior tier ships)        │
│ - Accelerate via: finding parts, automation, battlepass       │
└───────────────────────────────────────────────────────────────┘
```

---

## REVISED TGUI INTERFACES (3 total)

### 1. ShipCatalog.tsx (Main Interface)

**Features:**
- Dual tabs (Regular Ships | Antag Ships)
- Rarity filtering (All | Basic | Advanced | Rare | Superior)
- Faction filtering (visual only: NEU | NT-C | SYN-C)
- Sort (Name | Cost | Crew Size | Rarity)
- Search bar
- Ship cards with preview images
- Detail panel with mixed rarity requirements
- Progress bars (2/2 basic, 0/1 advanced)
- Unlock button (spend parts)
- Spawn button (if unlocked + not spawned this round)
- Buy parts button (credits → parts)
- Integration buttons (Customize Crew, View Automation)

**Layout:**
```
┌────────────────────────────────────────────────────────────┐
│ SHIP CATALOG                [Credits: 50,000] [Extract]   │
│ ┌──────────┬──────────┐                                    │
│ │ Regular  │  Antag   │  [Search: ___]                    │
│ └──────────┴──────────┘                                    │
│                                                             │
│ Filter Rarity: [All] [Basic] [Advanced] [Rare] [Superior] │
│ Filter Faction: [All] [NEU] [NT-C] [SYN-C]                │
│ Sort: [Name] [Cost] [Crew Size] [Rarity]                  │
│                                                             │
│ [Grid of ship cards]                                       │
│                                                             │
│ [Selected ship detail panel]                               │
│ [Action buttons: Unlock/Spawn/Customize]                   │
│                                                             │
│ Your Parts Inventory:                                      │
│ ● Basic: 5 | ● Advanced: 2 | ● Rare: 1 | ● Superior: 0   │
└────────────────────────────────────────────────────────────┘
```

---

### 2. ShipPartExtractor.tsx

**Features:**
- Physical part insertion interface
- Extract button (physical → digital, 3s do_after)
- Sell button (physical → credits directly, instant)
- Eject button (remove part from device)
- Progress bar during extraction
- Account inventory display (all rarity tiers with colored boxes)
- Credit balance display
- Part information (rarity, value)
- Status indicator (Ready / Extracted / Extracting)

**Layout:**
```
┌────────────────────────────────────────┐
│ SHIP PART EXTRACTION DEVICE            │
├────────────────────────────────────────┤
│ Loaded Part:                           │
│ ● ADVANCED SHIP PART                   │
│   Rarity: ADVANCED                     │
│   Value: 15,000 Credits                │
│   Status: Ready for Extraction         │
│                                         │
│ [Extract to Account] [Sell for 15k]   │
│ [Eject]                                │
│                                         │
│ ────────────────────────────────────  │
│ Your Account:                          │
│ Credits: 50,000                        │
│                                         │
│ Parts Inventory:                       │
│ [BASIC: 5] [ADVANCED: 2]               │
│ [RARE: 1]  [SUPERIOR: 0]               │
└────────────────────────────────────────┘
```

---

### 3. StarterShipSelection.tsx (New)

**Features:**
- First-time player flow only (shown once)
- Visual grid of 3-5 starter ships
- Ship preview images
- Ship descriptions (crew size, role, playstyle)
- "Select Starter" button
- Confirmation message: "This ship is now permanently unlocked!"
- Info message: "You can upgrade your starter ship via Custom Roles"

**Layout:**
```
┌────────────────────────────────────────────────────────────┐
│ WELCOME TO VOIDCREW!                                       │
│ Choose Your Starter Ship (Permanent Unlock)               │
├────────────────────────────────────────────────────────────┤
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│ │  Junker      │ │    Scout     │ │   Hauler     │        │
│ │  [PREVIEW]   │ │  [PREVIEW]   │ │  [PREVIEW]   │        │
│ │  4 crew      │ │  3 crew      │ │  5 crew      │        │
│ │  Scavenger   │ │  Explorer    │ │  Freighter   │        │
│ │              │ │              │ │              │        │
│ │  [SELECT]    │ │  [SELECT]    │ │  [SELECT]    │        │
│ └──────────────┘ └──────────────┘ └──────────────┘        │
│                                                             │
│ Your starter ship is permanently unlocked. You can spawn   │
│ it once per round. Upgrade your ship via Custom Roles!     │
└────────────────────────────────────────────────────────────┘
```

---

## INTEGRATION CONTRACTS SUMMARY

### Battlepass Integration (Called BY battlepass TO ship economy)
```dm
ShipEconomyDB.add_part(ckey, "rare", 1, "battlepass_tier_15")
client.earn_credits(500, "Battlepass Season Complete")
ShipEconomyDB.unlock_ship(ckey, "/datum/map_template/shuttle/voidcrew/exclusive")
```

### Battlepass Integration (Called BY ship economy TO battlepass)
```dm
battlepass_system.award_xp(client, 50, "ship_spawned")
battlepass_system.award_xp(client, 100, "round_completed")
```

### Custom Roles Integration (Called BY ship economy TO custom roles)
```dm
custom_roles_system.apply_to_ship(new_ship, purchaser_client)
custom_roles_system.open_ui(client, ship_template_type)
```

### Automation Integration (Called BY automation TO ship economy)
```dm
ShipEconomyDB.add_part(ckey, "advanced", 1, "automation_crafted")
client.earn_credits(1000, "Automation Crafting Bonus")
```

### Automation Integration (Called BY ship economy TO automation)
```dm
automation_system.has_blueprint(client, "advanced") -- Query if can craft
automation_system.open_ui(client, part_rarity) -- Open automation UI
```

---

## CONCLUSION

My final verdict is a **comprehensive synthesis** adapting to all user decisions:

✅ **Rarity-based progression** (basic/advanced/rare/superior) replaces faction parts
✅ **Database persistence** with full schema (8 tables) and transactions
✅ **Physical extraction mechanics** with device + TGUI interface
✅ **Integration contracts** for 3 parallel feature teams (Battlepass, Custom Roles, Automation)
✅ **Dual antag system** (large-scale crew conversion + small-scale solo)
✅ **Starter ship selection** flow (free permanent unlock)
✅ **Pluggable architecture** preserved from my Round 3
✅ **14-week timeline** (reduced from 16, phased delivery)
✅ **Three-tier economy** (Credits → Parts → Blueprints)
✅ **TGUI catalog** with visual ship previews
✅ **Backward compatibility** (auto-spawn station ship preserved)

**This architecture:**
- Fixes critical bugs (Phase 0)
- Delivers visual catalog quickly (Phase 1)
- Implements three-tier economy (Phase 2)
- Supports antag ships + starters (Phase 3)
- Enables parallel feature development (Phase 4)
- Maintains backward compatibility
- Scales for future expansions (expandable rarity system)

**Ready for final consensus and implementation.**
