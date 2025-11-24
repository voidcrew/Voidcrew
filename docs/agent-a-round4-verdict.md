# Agent A - Round 4 Final Verdict

**STATUS:** ROUND 4 VERDICT COMPLETE - All user decisions incorporated

**Date:** 2025-11-23

**Context:** Main Ship Purchase System - Round 4 Consensus Building

---

## I. EXECUTIVE SUMMARY

After reviewing all Round 3 proposals (mine, Agent B, Agent C, Agent D) and the comprehensive user decisions from Round 3.5, I now propose a **REVISED UNIFIED ARCHITECTURE** that fundamentally transforms the economy model while preserving the best structural elements from all proposals.

**Key Transformation:** My Round 3 proposal centered on faction-specific parts (NEU/NT-C/SYN-C). The user has decisively pivoted to **rarity-tier parts** (basic/advanced/rare/superior) with **database persistence** and **physical world extraction**. This requires complete economic redesign.

**Supported Architecture:** **Synthesis of Agent C's database-first approach + Agent D's phased rollout + My three-tier economy**, adapted to rarity tiers.

---

## II. CRITICAL ADAPTATIONS TO USER DECISIONS

### Adaptation 1: Rarity Tiers Replace Faction Parts

**REMOVED from my Round 3 proposal:**
- NEU/NT-C/SYN-C faction-specific parts
- Faction-based unlock trees
- Physical trading N-key for faction parts

**ADDED per user decisions:**
- **Basic Parts** (Tier 1) - Common drops, low-value
- **Advanced Parts** (Tier 2) - Moderate rarity
- **Rare Parts** (Tier 3) - Significant finds
- **Superior Parts** (Tier 4) - Elite/endgame content

**Expandable Design:**
```dm
/obj/item/ship_parts/base
    var/rarity_tier = 1  // 1=basic, 2=advanced, 3=rare, 4=superior
    var/part_type = "generic"  // Future: "engine", "hull", "weapon", etc.
    var/credit_value = 0  // Set by rarity tier

/obj/item/ship_parts/basic
    rarity_tier = 1
    part_type = "generic"
    credit_value = 10000
    icon_state = "part_basic"

/obj/item/ship_parts/advanced
    rarity_tier = 2
    credit_value = 15000
    icon_state = "part_advanced"

/obj/item/ship_parts/rare
    rarity_tier = 3
    credit_value = 20000
    icon_state = "part_rare"

/obj/item/ship_parts/superior
    rarity_tier = 4
    credit_value = 25000
    icon_state = "part_superior"
```

**Future Expansion Path:**
```dm
// Phase 5+ (Post-MVP)
/obj/item/ship_parts/advanced/engine
    part_type = "engine"
    // Used for engine-specific upgrades

/obj/item/ship_parts/rare/weapon_system
    part_type = "weapon"
    // Used for weapon upgrades
```

### Adaptation 2: Database Schema (NOT Savefiles)

**REMOVED from my Round 3 proposal:**
- JSON savefile extensions (`preferences_savefile.dm`)
- `ships_owned` list persistence
- Savefile save/load procs

**ADDED per user Q7 decision (Database SQL):**

```sql
-- Table 1: Player Credits (Per-Character, User Q6)
CREATE TABLE player_credits (
    ckey TEXT NOT NULL,
    character_slot INTEGER NOT NULL,
    credits INTEGER DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (ckey, character_slot)
);

-- Table 2: Player Ship Parts Inventory (Account-Wide)
CREATE TABLE player_ship_parts (
    ckey TEXT NOT NULL,
    part_rarity INTEGER NOT NULL,  -- 1=basic, 2=advanced, 3=rare, 4=superior
    part_type TEXT DEFAULT 'generic',  -- Future expansion
    quantity INTEGER DEFAULT 0,
    PRIMARY KEY (ckey, part_rarity, part_type)
);

-- Table 3: Ship Blueprint Unlocks (Account-Wide, User Q6)
CREATE TABLE player_ship_unlocks (
    ckey TEXT NOT NULL,
    ship_template_path TEXT NOT NULL,
    unlock_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (ckey, ship_template_path)
);

-- Table 4: Per-Round Spawn Tracking (NOT persistent across rounds)
CREATE TABLE round_ship_spawns (
    round_id INTEGER NOT NULL,
    ckey TEXT NOT NULL,
    ship_template_path TEXT NOT NULL,
    spawn_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (round_id, ckey)
);

-- Table 5: Antag Parts (Separate, Consumable)
CREATE TABLE player_antag_parts (
    ckey TEXT NOT NULL,
    antag_type TEXT NOT NULL,  -- 'syndicate_ops', 'blood_cult', etc.
    quantity INTEGER DEFAULT 0,
    PRIMARY KEY (ckey, antag_type)
);

-- Table 6: Physical Part Extraction Log (Audit Trail)
CREATE TABLE part_extraction_log (
    extraction_id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    part_rarity INTEGER NOT NULL,
    extraction_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    extraction_location TEXT  -- For analytics
);
```

**Database Abstraction Layer:**
```dm
/datum/ship_economy_db
    var/database_name = "player_ship_economy"

    proc/get_credits(ckey, character_slot)
        var/datum/db_query/Q = SSdbcore.NewQuery(
            "SELECT credits FROM player_credits WHERE ckey = :ckey AND character_slot = :slot",
            list("ckey" = ckey, "slot" = character_slot)
        )
        if(!Q.Execute())
            return 0
        if(Q.NextRow())
            var/credits = text2num(Q.item[1])
            qdel(Q)
            return credits
        qdel(Q)
        return 0

    proc/add_credits(ckey, character_slot, amount, reason)
        var/datum/db_query/Q = SSdbcore.NewQuery(
            "INSERT INTO player_credits (ckey, character_slot, credits)
             VALUES (:ckey, :slot, :amount)
             ON CONFLICT(ckey, character_slot)
             DO UPDATE SET credits = credits + :amount",
            list("ckey" = ckey, "slot" = character_slot, "amount" = amount)
        )
        Q.Execute()
        qdel(Q)
        log_economy("CREDIT_EARN: [ckey] (slot [character_slot]) +[amount] - [reason]")

    proc/get_parts(ckey, rarity)
        var/datum/db_query/Q = SSdbcore.NewQuery(
            "SELECT quantity FROM player_ship_parts
             WHERE ckey = :ckey AND part_rarity = :rarity AND part_type = 'generic'",
            list("ckey" = ckey, "rarity" = rarity)
        )
        if(!Q.Execute())
            return 0
        if(Q.NextRow())
            var/qty = text2num(Q.item[1])
            qdel(Q)
            return qty
        qdel(Q)
        return 0

    proc/add_parts(ckey, rarity, quantity)
        var/datum/db_query/Q = SSdbcore.NewQuery(
            "INSERT INTO player_ship_parts (ckey, part_rarity, part_type, quantity)
             VALUES (:ckey, :rarity, 'generic', :qty)
             ON CONFLICT(ckey, part_rarity, part_type)
             DO UPDATE SET quantity = quantity + :qty",
            list("ckey" = ckey, "rarity" = rarity, "qty" = quantity)
        )
        Q.Execute()
        qdel(Q)

    proc/is_ship_unlocked(ckey, ship_template_path)
        var/datum/db_query/Q = SSdbcore.NewQuery(
            "SELECT 1 FROM player_ship_unlocks WHERE ckey = :ckey AND ship_template_path = :path",
            list("ckey" = ckey, "path" = ship_template_path)
        )
        var/unlocked = FALSE
        if(Q.Execute() && Q.NextRow())
            unlocked = TRUE
        qdel(Q)
        return unlocked

    proc/unlock_ship(ckey, ship_template_path)
        var/datum/db_query/Q = SSdbcore.NewQuery(
            "INSERT OR IGNORE INTO player_ship_unlocks (ckey, ship_template_path) VALUES (:ckey, :path)",
            list("ckey" = ckey, "path" = ship_template_path)
        )
        Q.Execute()
        qdel(Q)
```

### Adaptation 3: Physical Parts + Extraction Device

**REMOVED from my Round 3 proposal:**
- N-key digital-to-physical conversion
- Direct physical trading of digital parts

**ADDED per user Q10/Q19 decisions:**

**Physical Part Items:**
```dm
/obj/item/ship_parts/base
    name = "ship construction part"
    desc = "A modular component used in ship blueprint assembly. Must be extracted to deposit into your account."
    icon = 'icons/obj/ship_parts.dmi'
    w_class = WEIGHT_CLASS_NORMAL
    var/rarity_tier = 1
    var/extracted = FALSE  // Prevents re-extraction

    attack_self(mob/user)
        to_chat(user, "<span class='notice'>This part must be inserted into a Part Extraction Device to deposit into your account.</span>")
```

**Extraction Device:**
```dm
/obj/machinery/part_extractor
    name = "ship part extraction terminal"
    desc = "A secure terminal that authenticates and deposits ship construction parts into your persistent account. Parts cannot be withdrawn once extracted."
    icon = 'icons/obj/machines/research.dmi'
    icon_state = "destructive_analyzer"
    density = TRUE
    anchored = TRUE

    var/obj/item/ship_parts/loaded_part = null
    var/extracting = FALSE

    attackby(obj/item/I, mob/user, params)
        if(istype(I, /obj/item/ship_parts))
            var/obj/item/ship_parts/part = I
            if(part.extracted)
                to_chat(user, "<span class='warning'>This part has already been extracted!</span>")
                return
            if(loaded_part)
                to_chat(user, "<span class='warning'>[src] already has a part loaded!</span>")
                return
            if(!user.transferItemToLoc(part, src))
                return
            loaded_part = part
            to_chat(user, "<span class='notice'>You insert [part] into [src].</span>")
            update_appearance()
        return ..()

    attack_hand(mob/user)
        . = ..()
        if(!user.client)
            return
        if(!loaded_part)
            to_chat(user, "<span class='warning'>No part loaded. Insert a ship part to extract.</span>")
            return
        if(extracting)
            to_chat(user, "<span class='warning'>Extraction already in progress!</span>")
            return

        to_chat(user, "<span class='notice'>Beginning extraction of [loaded_part]...</span>")
        extracting = TRUE
        if(!do_after(user, 3 SECONDS, src))
            extracting = FALSE
            return

        // Extract to database
        GLOB.ship_economy_db.add_parts(user.client.ckey, loaded_part.rarity_tier, 1)
        GLOB.ship_economy_db.log_extraction(user.client.ckey, loaded_part.rarity_tier, get_area(src))

        to_chat(user, "<span class='boldnotice'>Part extracted! You now have [GLOB.ship_economy_db.get_parts(user.client.ckey, loaded_part.rarity_tier)] Tier-[loaded_part.rarity_tier] parts.</span>")

        loaded_part.extracted = TRUE
        qdel(loaded_part)
        loaded_part = null
        extracting = FALSE
        update_appearance()
```

**Loot Spawners (User Q10: ruins, planets, galaxy):**
```dm
/obj/effect/spawner/random/ship_parts
    name = "ship part spawner"
    loot = list(
        /obj/item/ship_parts/basic = 50,      // 50% basic
        /obj/item/ship_parts/advanced = 30,   // 30% advanced
        /obj/item/ship_parts/rare = 15,       // 15% rare
        /obj/item/ship_parts/superior = 5     // 5% superior
    )

/obj/effect/spawner/random/ship_parts/ruin
    name = "ruin ship part cache"
    loot = list(
        /obj/item/ship_parts/basic = 30,
        /obj/item/ship_parts/advanced = 40,
        /obj/item/ship_parts/rare = 25,
        /obj/item/ship_parts/superior = 5
    )

/obj/effect/spawner/random/ship_parts/planet_rare
    name = "planetary ship part deposit"
    loot = list(
        /obj/item/ship_parts/advanced = 30,
        /obj/item/ship_parts/rare = 50,
        /obj/item/ship_parts/superior = 20
    )
```

### Adaptation 4: Integration with Battlepass/Custom Roles/Automation

**INTEGRATION POINT 1: Battlepass Rewards**

User decision (Q10): Battlepass grants ship parts as rewards.

```dm
// Called by separate Battlepass feature team
/proc/grant_battlepass_reward_ship_part(client/C, rarity_tier)
    // Directly deposit to database (skip physical item)
    GLOB.ship_economy_db.add_parts(C.ckey, rarity_tier, 1)
    to_chat(C, "<span class='boldnotice'>Battlepass Reward: Tier-[rarity_tier] Ship Part added to your inventory!</span>")
```

**INTEGRATION POINT 2: Custom Roles Application**

User decision (Q12): Custom roles can be applied to any ship via upgrade menu.

```dm
/datum/map_template/shuttle/voidcrew
    var/list/custom_role_slots = list()  // Applied from Custom Roles system

    proc/apply_custom_roles(client/purchaser)
        // Called by Custom Roles feature team before ship spawn
        // Overrides default job_slots if custom roles purchased
        if(GLOB.custom_roles_system.has_custom_loadout(purchaser.ckey, src.type))
            var/datum/custom_ship_loadout/loadout = GLOB.custom_roles_system.get_loadout(purchaser.ckey, src.type)
            src.job_slots = loadout.get_modified_job_slots()
```

**INTEGRATION POINT 3: Automation Crafting Output**

User decision (Q15): Factorio/Satisfactory automation can craft ship parts.

```dm
// Called by Automation Crafting feature team
/proc/automation_craft_part(mob/user, rarity_tier)
    // Creates physical part in world (not direct deposit)
    var/obj/item/ship_parts/part = null
    switch(rarity_tier)
        if(1) part = new /obj/item/ship_parts/basic(get_turf(user))
        if(2) part = new /obj/item/ship_parts/advanced(get_turf(user))
        if(3) part = new /obj/item/ship_parts/rare(get_turf(user))
        if(4) part = new /obj/item/ship_parts/superior(get_turf(user))
    to_chat(user, "<span class='notice'>Automation system produced [part]! Extract it to deposit into your account.</span>")
```

---

## III. REVISED ECONOMY MODEL

### Three-Tier Economy (User Q1, Q8)

**Tier 1: CREDITS** (Account-bound, NOT tradeable - User Q17)
- Generated: 100 credits per round (User Q20)
- Per-character persistence (User Q6)
- Used to: Buy parts from shop (NOT from players)

**Tier 2: PARTS** (Physical until extracted, Rarity tiers - User Q8)
- Obtained: Find in world, Battlepass rewards, Automation crafting, Round-end (1 part - User Q14)
- Stored: Database after extraction
- Used to: Unlock ship blueprints (spend parts, get permanent unlock)

**Tier 3: BLUEPRINTS** (Account-wide permanent unlocks - User Q1, Q6)
- One-time unlock: Spend parts once, own forever
- Spawn: FREE every round (respecting one-spawn-per-round limit)

### Revised Part Pricing (Rarity-Based)

**Credit → Parts (Shop Prices):**
- 1 Basic Part = 10,000 Credits (User-provided Q8)
- 1 Advanced Part = 15,000 Credits (User-provided Q8)
- 1 Rare Part = 20,000 Credits (User-provided Q8)
- 1 Superior Part = 25,000 Credits (User-provided Q8)

**Parts → Sell for Credits (50% shop value):**
- 1 Basic Part = 5,000 Credits
- 1 Advanced Part = 7,500 Credits
- 1 Rare Part = 10,000 Credits
- 1 Superior Part = 12,500 Credits

**Ship Unlock Costs (Balanced by tier):**

**Starter Ships (Pre-unlocked per User Q2):**
- Cost: Free (chosen during new player flow)
- Examples: Basic Scout, Basic Hauler, Basic Explorer

**Tier 1 Ships (Beginner-friendly):**
- Cost: 2 Basic Parts (20,000 Credits equivalent)
- 200 rounds of passive earning
- Examples: Box, Junker, Serendipity

**Tier 2 Ships (Mid-game):**
- Cost: 2 Advanced Parts OR 4 Basic Parts
- 300 rounds passive / 150 rounds active grinding
- Examples: Bogatyr, Delta, Riggs

**Tier 3 Ships (Advanced):**
- Cost: 2 Rare Parts OR 1 Rare + 2 Advanced
- 400 rounds passive / 200 rounds active
- Examples: Schmiedeberg, Sunskipper

**Tier 4 Ships (Elite/Endgame):**
- Cost: 2 Superior Parts OR 1 Superior + 1 Rare + 2 Advanced
- 500+ rounds passive / 250+ rounds active
- Examples: Flagship vessels, specialized endgame ships

**Antag Ships (Direct purchase, User Q5):**
- Small Antag Ships: 1 Antag Part (solo-only)
- Large Antag Ships: 2 Antag Parts (all crew convert)
- Antag Parts: ONLY from admin grants, super-rare drops (0.1% chance)

### Economic Balance Rationale

**Earning Rates:**
- Passive (round-end only): 100 credits/round + 1 random part/round
- Active (finding parts): 5-10 parts per round (exploration gameplay)
- Automation: 2-5 parts per round (once automation built)
- Battlepass: 1-3 parts per tier (incentivizes progression)

**Time to Unlock:**
- First ship beyond starter: 20-50 rounds (1-2 weeks casual play)
- Mid-tier ship: 100-150 rounds (1 month casual play)
- Endgame ship: 300-500 rounds (2-3 months casual play)

**Prevents Griefing:**
- Parts can be stolen while physical (risk/reward)
- Once extracted, cannot be lost (safe storage)
- Credits cannot be traded (prevents RMT)

---

## IV. STARTER SHIP SELECTION SYSTEM

**User Decision Q2/Q3:** Choose starter ship, get blueprint, can upgrade.

### New Player Flow

```dm
/mob/dead/new_player/proc/choose_starter_ship()
    var/list/starter_templates = list()
    for(var/datum/map_template/shuttle/voidcrew/template in SSmapping.ship_purchase_list)
        if(template.is_starter_ship)
            starter_templates += template

    var/datum/map_template/shuttle/voidcrew/choice = tgui_input_list(src, "Choose your starter ship (permanent unlock):", "Starter Ship Selection", starter_templates)
    if(!choice)
        return FALSE

    // Permanently unlock chosen starter
    GLOB.ship_economy_db.unlock_ship(client.ckey, choice.type)

    to_chat(src, "<span class='boldnotice'>You have permanently unlocked: [choice.name]!</span>")
    to_chat(src, "<span class='notice'>You can spawn this ship any round (once per round limit applies). It can be upgraded via the ship upgrade menu.</span>")

    return TRUE
```

### Starter Ship Template Flag

```dm
/datum/map_template/shuttle/voidcrew
    var/is_starter_ship = FALSE  // Mark which ships are starter choices

/datum/map_template/shuttle/voidcrew/box
    is_starter_ship = TRUE
    unlock_cost = 0  // Free for starters

/datum/map_template/shuttle/voidcrew/junker
    is_starter_ship = TRUE
    unlock_cost = 0

/datum/map_template/shuttle/voidcrew/serendipity
    is_starter_ship = TRUE
    unlock_cost = 0
```

### Auto-Spawn Ship Preservation (User Q2)

```dm
/mob/dead/new_player/proc/LateChoices()
    // ... existing code ...

    // Show both options
    var/choice = tgui_alert(src, "Join the round:", "Join", list("Join Auto-Spawn Ship", "Browse Ship Catalog", "Spectate"))

    switch(choice)
        if("Join Auto-Spawn Ship")
            // Existing system (backward compatible)
            join_auto_spawn_ship()

        if("Browse Ship Catalog")
            // New catalog system
            open_ship_catalog()
```

---

## V. ANTAG SHIP SYSTEM

**User Decision Q4:** Need BOTH large-scale AND small-scale antag ships.
**User Decision Q5:** Direct purchase (no unlock), per-round consumable.

### Antag Ship Templates

```dm
/datum/map_template/shuttle/voidcrew/antag
    is_antag_ship = TRUE
    var/antag_scale = "large"  // "large" or "small"
    var/datum/antagonist/antag_type = null
    var/list/antag_equipment = list()
    unlock_cost = 0  // No unlock needed

    // Large: all crew convert
    // Small: solo-only
    var/min_crew = 1
    var/max_crew = 1  // Set to 1 for small, 5+ for large

/datum/map_template/shuttle/voidcrew/antag/syndicate_ops_cruiser
    name = "Syndicate Operations Cruiser"
    antag_scale = "large"
    min_crew = 2
    max_crew = 5
    antag_type = /datum/antagonist/nukeop
    antag_part_cost = 2  // 2 antag parts

/datum/map_template/shuttle/voidcrew/antag/syndicate_infiltrator
    name = "Syndicate Infiltrator Pod"
    antag_scale = "small"
    min_crew = 1
    max_crew = 1
    antag_type = /datum/antagonist/traitor
    antag_part_cost = 1  // 1 antag part
```

### Antag Ship Purchase Flow

```dm
/mob/dead/new_player/proc/purchase_antag_ship(datum/map_template/shuttle/voidcrew/antag/template)
    // Check antag parts
    var/antag_parts = GLOB.ship_economy_db.get_antag_parts(client.ckey, template.antag_type_name)
    if(antag_parts < template.antag_part_cost)
        to_chat(src, "<span class='warning'>Insufficient Antag Parts! Need [template.antag_part_cost], have [antag_parts].</span>")
        return FALSE

    // Check one-spawn limit
    if(GLOB.ship_economy_db.has_spawned_this_round(SSticker.current_round_id, client.ckey))
        to_chat(src, "<span class='warning'>You have already spawned a ship this round!</span>")
        return FALSE

    // Confirm (antag conversion warning)
    if(tgui_alert(src, "Purchasing this ship will convert you to [template.antag_type.name]. Continue?", "Antag Warning", list("Yes", "No")) != "Yes")
        return FALSE

    // Deduct antag parts (CONSUMABLE)
    GLOB.ship_economy_db.add_antag_parts(client.ckey, template.antag_type_name, -template.antag_part_cost)

    // Create ship
    var/obj/structure/overmap/ship/new_ship = SSshuttle.create_ship(template)

    // Convert to antagonist
    var/datum/antagonist/antag = new template.antag_type()
    mind.add_antag_datum(antag)
    antag.on_gain(mind)

    // Spawn player
    AttemptSpawnOnShip(new_ship.job_slots[1], new_ship)

    // Track spawn
    GLOB.ship_economy_db.log_round_spawn(SSticker.current_round_id, client.ckey, template.type)

    return TRUE
```

---

## VI. WHICH PROPOSAL I SUPPORT

**PRIMARY SUPPORT: Synthesis of Agent C + Agent D**

**From Agent C (Database-First Design):**
- Database schema structure (proven, scalable)
- Per-round spawn tracking approach
- Clean separation of economy layers

**From Agent D (Phased Rollout Strategy):**
- Phase 0: Bug fix first (critical blocking issue)
- Phase 1: TGUI catalog (high UX value)
- Phase 2: Economy system (core features)
- Phase 3+: Customization (deferred scope)

**From Agent B (Comprehensive Detail):**
- Thorough TGUI interface mockups
- Physical trading preservation concepts (adapted for extraction device)
- Crafting system integration

**From My Round 3 Proposal (Refined for Rarity Tiers):**
- Three-tier economy clarity (Credits → Parts → Blueprints)
- Dual ship systems (Regular permanent + Antag consumable)
- Economic balance rationale

---

## VII. COMPROMISES I'M WILLING TO MAKE

1. **Abandon Faction-Specific Parts Entirely**
   - My Round 3 proposal heavily featured NEU/NT-C/SYN-C
   - User decisively chose rarity tiers
   - I fully embrace rarity system (basic/advanced/rare/superior)

2. **Abandon Savefile Persistence**
   - My Round 3 assumed JSON savefiles
   - User chose database (Q7)
   - I fully embrace SQL database architecture

3. **Abandon N-Key Physical Trading**
   - My Round 3 featured digital-to-physical conversion
   - User chose extraction-only flow (Q10/Q19)
   - I fully embrace one-way extraction device system

4. **Defer Ship Skins to Phase 4+**
   - My Round 3 proposed full .dmm map variants
   - User chose to skip for MVP (Q13)
   - I accept skin deferral (focus on core unlock system)

5. **Accept Manual Screenshot Previews**
   - I would prefer automated rendering
   - User chose manual screenshots (Q11)
   - I accept this for MVP simplicity

6. **Credits Per-Character Instead of Account-Wide**
   - I initially thought account-wide credits made sense
   - User chose per-character (Q6)
   - I embrace this (encourages multi-character play)

---

## VIII. NON-NEGOTIABLE REQUIREMENTS

1. **Three-Tier Economy MUST Be Preserved**
   - Credits → Parts → Blueprints flow is fundamental
   - User confirmed this (Q1, Q8)
   - Any proposal that collapses tiers is unacceptable

2. **One-Spawn-Per-Round Limit MUST Be Enforced**
   - Critical balance mechanism
   - Prevents ship spam
   - User confirmed (implicit in Q1 context)
   - No exceptions (even for destroyed ships)

3. **Database Persistence MUST Be Used**
   - User explicitly chose database (Q7)
   - No savefile fallback acceptable
   - Must use existing server database infrastructure

4. **Rarity Tiers MUST Replace Faction Parts**
   - User explicitly eliminated faction parts (Q8)
   - Basic/Advanced/Rare/Superior system required
   - No mixing with old faction system

5. **Physical Parts + Extraction Device MUST Be Implemented**
   - User explicitly described this system (Q10, Q19)
   - One-way extraction (cannot withdraw)
   - Physical parts can be found/traded until extracted

6. **Integration Points for Battlepass/Custom Roles/Automation MUST Exist**
   - User confirmed these are separate heavy features (Q10, Q12, Q15)
   - Our system must expose hooks for these teams
   - Cannot design in isolation

7. **Starter Ship Selection MUST Be Implemented**
   - User explicitly requested (Q2/Q3)
   - New players choose starter, get permanent unlock
   - Coexists with auto-spawn ship (backward compatible)

8. **Antag Ships MUST Support Both Large and Small Scale**
   - User explicitly requested both (Q4)
   - Large: all crew convert
   - Small: solo-only
   - Direct purchase, no unlock (Q5)

---

## IX. FINAL RECOMMENDED ARCHITECTURE

### Phase 0: Foundation (Week 1)

**Critical Blocking Tasks:**
1. Create database tables (schema in Section II.2)
2. Implement `/datum/ship_economy_db` abstraction layer
3. Test database CRUD operations
4. Create admin tools (grant credits/parts, view inventories)

**Deliverable:** Database persistence layer functional

### Phase 1: Physical Parts + Extraction (Weeks 2-3)

**Tasks:**
1. Create `/obj/item/ship_parts/` items (basic/advanced/rare/superior)
2. Implement `/obj/machinery/part_extractor` device
3. Create loot spawners (ruins, planets, galaxy)
4. Place extractors on station/ships
5. Test find → extract → deposit flow

**Deliverable:** Physical part economy functional

### Phase 2: TGUI Ship Catalog (Weeks 4-6)

**Tasks:**
1. Research TGUI image display capabilities
2. Create ship preview screenshots (manual, 30+ ships)
3. Build `ShipCatalog.tsx` interface
4. Implement regular ships tab (locked/unlocked states)
5. Implement antag ships tab (direct purchase)
6. Replace latejoin menu with catalog
7. Test browsing, filtering, purchasing

**Deliverable:** Visual catalog replacing old UI

### Phase 3: Credits + Shop System (Weeks 7-9)

**Tasks:**
1. Implement credit earning (100/round - Q20)
2. Create shop UI (buy parts with credits)
3. Implement sell parts for credits (50% shop value)
4. Add credit/part displays to catalog UI
5. Test economic loops

**Deliverable:** Full economy functional

### Phase 4: Blueprint Unlock System (Weeks 10-12)

**Tasks:**
1. Implement unlock purchase validation
2. Update ship templates with unlock costs (by tier)
3. Implement per-round spawn tracking
4. Create starter ship selection flow
5. Test unlock → spawn → one-per-round enforcement

**Deliverable:** Core unlock system complete

### Phase 5: Antag Ship System (Weeks 13-15)

**Tasks:**
1. Define antag part types (database)
2. Create antag ship templates (large + small)
3. Implement antag conversion on spawn
4. Implement antag equipment loadouts
5. Test antag purchase flow

**Deliverable:** Antag ships functional

### Phase 6: Integration + Polish (Weeks 16-18)

**Tasks:**
1. Create integration hooks (Battlepass, Custom Roles, Automation)
2. Balance tuning (costs, earning rates, drop chances)
3. UI polish (animations, feedback, error handling)
4. Performance optimization
5. Admin tools (monitoring, grants, resets)
6. Documentation

**Deliverable:** Production-ready system

**Total Timeline:** 18 weeks (4.5 months)

---

## X. SUCCESS METRICS

**Player Engagement:**
- 80%+ new players choose starter ship (vs auto-spawn)
- Average 3-5 ships unlocked per active player (month 1)
- 60%+ players extract at least 1 physical part per session

**Economy Health:**
- Average credit balance: 15,000-30,000 (healthy saving)
- Part extraction rate: 500-1000 parts/day (active exploration)
- Shop purchases: 30%+ players buy parts with credits weekly

**Feature Adoption:**
- Catalog usage: 90%+ spawns via TGUI (vs fallback text menu)
- Antag ship spawns: <5% of total spawns (balanced rarity)
- Battlepass integration: 70%+ parts from battlepass vs finding

**Balance:**
- Time to first unlock: 10-30 rounds (1-2 weeks casual)
- Time to mid-tier ship: 100-150 rounds (1 month)
- Credit inflation: <10% monthly (economy stability)

---

## XI. CONCLUSION

This revised architecture fully incorporates ALL user decisions from Round 3.5:

**Critical Changes Addressed:**
- Rarity tiers (basic/advanced/rare/superior) replace faction parts
- Database persistence replaces savefiles
- Physical parts + extraction device replaces N-key
- Integration hooks for Battlepass/Custom Roles/Automation
- Starter ship selection + auto-spawn coexistence
- Both large and small antag ships (direct purchase)
- Per-character credits, account-wide unlocks
- 100 credits/round + 1 part/round dual rewards

**Synthesis of Best Ideas:**
- Agent C's database schema structure
- Agent D's phased rollout strategy
- Agent B's comprehensive TGUI mockups
- My three-tier economy clarity

**Non-Negotiables Preserved:**
- Three-tier economy (Credits → Parts → Blueprints)
- One-spawn-per-round limit
- Database-first architecture
- Physical part extraction system

**This is my final recommendation. I support immediate implementation starting with Phase 0 database foundation.**

---

**Agent A - Round 4 Final Verdict Complete**
**Date:** 2025-11-23
**Status:** Ready for implementation
