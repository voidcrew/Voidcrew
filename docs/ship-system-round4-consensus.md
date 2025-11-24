# Ship Purchase System Redesign - Round 4: Final Consensus

**Part of:** [Ship System Redesign Master Index](ship-system-master-index.md)

## Document Navigation
- **Previous:** [User Decisions - Round 3.5](ship-system-user-decisions.md)
- **See Also:** [Round 3: Proposals](ship-system-round3-proposals.md) | [Round 1-2: Analysis](ship-system-round1-2-analysis.md)
- **Back to:** [Master Index](ship-system-master-index.md)

---

## Table of Contents
1. [Agent A's Final Verdict](#agent-as-final-verdict)
2. [Agent B's Final Verdict](#agent-bs-final-verdict)
3. [Agent C's Final Verdict](#agent-cs-final-verdict) ✅ Complete
4. [Agent D's Final Verdict](#agent-ds-final-verdict) ⏳ Pending
5. [Final Consensus Summary](#final-consensus) 📝 To be filled

---

## Document Purpose

This document contains each agent's final verdict after incorporating all user decisions from Round 3.5. Agents revised their Round 3 proposals to accommodate:

- Rarity tier system (replacing faction parts)
- Database persistence (replacing savefiles)
- Physical parts + extraction mechanics
- Battlepass/Custom Roles/Automation integration
- Two-scale antag ship system

**Current Status:** Agent C's verdict is complete. Awaiting Agent D's final verdict before synthesizing overall consensus.

**Key Revisions:**
- Database schema designs (all agents)
- Rarity tier conversion rates
- Feature team integration points
- 7-phase implementation roadmaps (Weeks 0-16)

---
## Round 4: Consensus Building

### Agent A's Final Verdict

[Agent A: Read all proposals from Round 3. Explain:

1. Which proposal do you support (can be your own or synthesis of multiple)?
2. What compromises are you willing to make?
3. What are your non-negotiable requirements?
4. Your final recommended approach]

### Agent B's Final Verdict

**AGENT B - MAIN SHIP PURCHASE SYSTEM TEAM**

**Date:** Round 4 Final Analysis
**Status:** Critical architecture revision required after user decisions

---

## I. EXECUTIVE SUMMARY

After analyzing all Round 3 proposals (Agents A, B, C, D) and the comprehensive user decisions in "USER DECISIONS - ROUND 3.5 CRITICAL INPUT", I conclude that **no single Round 3 proposal is viable as-is**. The user's decisions fundamentally change the architecture:

**INVALIDATED ASSUMPTIONS FROM ALL PROPOSALS:**
- ❌ Faction-specific parts (NEU/NT-C/SYN-C) → User wants **rarity tiers** (basic/advanced/rare/superior)
- ❌ Savefile/JSON persistence → User wants **database immediately** (not MVP then migrate)
- ❌ N-key physical trading system → User wants **extraction device** for physical parts
- ❌ Simple crafting → User wants **Factorio/Satisfactory automation minigame** (separate team)

**CRITICAL NEW REQUIREMENTS:**
- ✅ Physical parts in world (found in ruins, planets, space) until extracted
- ✅ Extraction device deposits parts into account
- ✅ Three new feature teams need integration: Battlepass, Custom Roles, Automation
- ✅ Database schema required (no JSON)
- ✅ Starter ship selection from templates (keep auto-spawn too)
- ✅ Both large-scale and small-scale antag ships

**MY VERDICT:** I support a **synthesis approach** combining Agent D's phased methodology, Agent C's database architecture, Agent A's economy framework, and my Round 3 bug discovery - but ALL adapted to rarity tiers and physical parts system.

---

## II. ANALYSIS OF ROUND 3 PROPOSALS VS USER DECISIONS

### Agent A's Proposal - Strengths & Gaps

**Strengths:**
- ✅ Comprehensive economy numbers (exchange rates, earning rates)
- ✅ Detailed TGUI catalog design
- ✅ Clear phased implementation (16 weeks)
- ✅ Dual economy (regular + antag ships) clearly separated

**Critical Gaps:**
- ❌ Based on faction parts (NEU/NT-C/SYN-C) - user eliminated this
- ❌ Savefile persistence - user wants database
- ❌ No extraction device concept
- ❌ No integration points for Battlepass/Custom Roles/Automation teams
- ❌ Crafting system too simple - user wants full automation minigame

**Verdict:** Strong foundation but needs complete rework for rarity tiers and database.

### Agent B's Proposal (My Own) - Strengths & Gaps

**Strengths:**
- ✅ **CRITICAL:** Discovered the persistence load bug (missing `load_preferences()` calls)
- ✅ Detailed JSON schema examples (convertible to database)
- ✅ Physical trading via N-key (partially aligns with physical parts)
- ✅ Dual ship systems (regular permanent + antag consumable)
- ✅ Complete data flow examples

**Critical Gaps:**
- ❌ JSON for MVP - user wants database immediately
- ❌ Faction parts (NEU/NT-C/SYN-C) - user wants rarity tiers
- ❌ N-key withdrawal system - user wants extraction device instead
- ❌ No starter ship selection system
- ❌ No integration architecture for 3 new feature teams
- ❌ Crafting system too simple - user wants automation minigame

**Verdict:** Bug discovery was essential, but proposal needs major architectural revision.

### Agent C's Proposal - Strengths & Gaps

**Strengths:**
- ✅ Database schema proposed (ahead of curve)
- ✅ Three-tier economy (currency → parts → unlocks)
- ✅ Separation of concerns (clear subsystems)
- ✅ Transaction logging and admin tools

**Critical Gaps:**
- ❌ Still uses faction parts - needs rarity tier conversion
- ❌ No extraction device concept
- ❌ Database schema incomplete (missing extraction tracking)
- ❌ No integration points for new teams
- ❌ No physical parts in world system

**Verdict:** Database architecture is closest to user's vision, but needs extension.

### Agent D's Proposal - Strengths & Gaps

**Strengths:**
- ✅ **Best phased approach** (clear dependencies, minimal risk)
- ✅ Pluggable currency earning system (extensible for Battlepass)
- ✅ Unified currency with conversion system
- ✅ Backward compatibility emphasis
- ✅ Clean separation of catalog vs unlock logic

**Critical Gaps:**
- ❌ Savefile persistence - user wants database
- ❌ Faction parts - needs rarity tiers
- ❌ No extraction device
- ❌ Defers customization - but user wants Custom Roles (separate team handles it)
- ❌ No integration architecture

**Verdict:** Best implementation methodology, but needs database and rarity tier adaptation.

---

## III. MY REVISED ARCHITECTURE - RARITY TIERS + DATABASE + EXTRACTION DEVICE

### Core System Model

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        THREE-TIER ECONOMY (USER CONFIRMED)               │
├─────────────────────────────────────────────────────────────────────────┤
│  TIER 1: CREDITS (account-bound, not tradeable)                         │
│    - Earned: Round completion (100 base), Battlepass rewards            │
│    - Stored: Database per-character (hybrid persistence model)          │
│    - Purpose: Buy ship parts from credit store                          │
├─────────────────────────────────────────────────────────────────────────┤
│  TIER 2: PARTS (rarity tiers, physical until extracted)                 │
│    - Types: Basic/Advanced/Rare/Superior (NOT faction-specific)         │
│    - Found: Ruins (space), planets, scattered in galaxy                 │
│    - Earned: Battlepass rewards, Automation crafting                    │
│    - Physical: Can be traded/stolen until extracted                     │
│    - Extracted: Via extraction device → permanent account deposit       │
│    - Stored: Database (account-wide parts inventory)                    │
│    - Purpose: Unlock ship blueprints                                    │
├─────────────────────────────────────────────────────────────────────────┤
│  TIER 3: BLUEPRINTS (permanent unlocks, account-wide)                   │
│    - Unlocked: Spend parts (e.g., 2 advanced parts → Medium Frigate)    │
│    - Stored: Database (account-wide unlocks)                            │
│    - Purpose: Spawn ships FREE forever (one per round limit)            │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                     PHYSICAL PARTS FLOW (NEW USER REQUIREMENT)           │
├─────────────────────────────────────────────────────────────────────────┤
│  1. Player finds physical part in world (/obj/item/ship_parts/advanced) │
│  2. Part can be traded, stolen, dropped (standard item)                 │
│  3. Player uses extraction device (e.g., ship console, station terminal) │
│  4. Part is deleted from world, added to database account inventory     │
│  5. Extracted parts CANNOT be pulled back out (one-way deposit)         │
│  6. Use parts in catalog TGUI to unlock blueprints                      │
└─────────────────────────────────────────────────────────────────────────┘
```

### Database Schema (Complete Revision)

**USER DECISION:** Database, not savefiles. No existing tables to migrate.

```sql
-- Table 1: Player Credits (per-character, hybrid persistence)
CREATE TABLE player_ship_credits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    character_slot INTEGER NOT NULL,
    credits INTEGER DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(ckey, character_slot)
);

-- Table 2: Player Parts Inventory (account-wide, rarity tiers)
CREATE TABLE player_ship_parts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    part_rarity TEXT NOT NULL,  -- 'basic', 'advanced', 'rare', 'superior'
    part_count INTEGER DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(ckey, part_rarity)
);

-- Table 3: Ship Blueprint Unlocks (account-wide)
CREATE TABLE player_ship_unlocks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    ship_template_path TEXT NOT NULL,
    unlocked_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(ckey, ship_template_path)
);

-- Table 4: Starter Ship Selection (account-wide, one-time choice)
CREATE TABLE player_starter_ship (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL UNIQUE,
    starter_ship_template TEXT NOT NULL,
    selection_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table 5: Per-Round Spawn Tracking (volatile, reset each round)
CREATE TABLE round_ship_spawns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    round_id TEXT NOT NULL,
    ckey TEXT NOT NULL,
    ship_template_path TEXT NOT NULL,
    spawn_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(round_id, ckey)
);

-- Table 6: Part Extraction Log (audit trail)
CREATE TABLE part_extraction_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    part_rarity TEXT NOT NULL,
    extraction_method TEXT,
    extraction_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table 7: Credit Transaction Log (audit trail)
CREATE TABLE credit_transaction_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    character_slot INTEGER NOT NULL,
    amount INTEGER NOT NULL,
    reason TEXT,
    transaction_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_player_credits_ckey ON player_ship_credits(ckey);
CREATE INDEX idx_player_parts_ckey ON player_ship_parts(ckey);
CREATE INDEX idx_player_unlocks_ckey ON player_ship_unlocks(ckey);
CREATE INDEX idx_round_spawns_round ON round_ship_spawns(round_id);
```

**Key Design Decisions:**
1. **Credits per-character** (user Q6) - separate balance per character slot
2. **Parts account-wide** (user Q6) - shared across all characters
3. **Unlocks account-wide** (user Q6) - permanent across characters
4. **Rarity tiers expandable** - easy to add new tiers
5. **Transaction logs** - essential for economy balancing
6. **Extraction log** - tracks part sources (Battlepass vs finding vs automation)

---

## IV. NON-NEGOTIABLE REQUIREMENTS

### 1. Database Persistence (NOT Savefiles)
**Reason:** User explicitly chose database (Q7). JSON/savefile is not acceptable.
**Non-negotiable:** All 7 tables must be implemented with transaction logs.

### 2. Rarity Tiers (NOT Faction Parts)
**Reason:** User eliminated faction parts (Q8). NEU/NT-C/SYN-C is dead.
**Non-negotiable:** Basic/Advanced/Rare/Superior system, expandable design.

### 3. Physical Parts Until Extracted
**Reason:** User wants parts found in world (Q10, Q19), extraction device required.
**Non-negotiable:** Parts are physical items, extraction device (ship + station).

### 4. Persistence Load Bug MUST BE FIXED
**Reason:** I discovered this in Round 3 - affects all persistence.
**Non-negotiable:** Exhaustive testing of database load functions, transaction logs for debugging.

### 5. Integration APIs for 3 Feature Teams
**Reason:** Battlepass, Custom Roles, Automation are separate teams.
**Non-negotiable:** Clean API boundaries, documented integration points.

### 6. Hybrid Persistence Model
**Reason:** User decision Q6 - unlocks shared, credits per-character.
**Non-negotiable:** Database schema supports both models.

### 7. Both Large and Small Antag Ships
**Reason:** User wants both (Q4) with different crew handling.
**Non-negotiable:** Separate templates, crew conversion logic, consumable per-round.

### 8. Starter Ship Selection + Auto-spawn Compatibility
**Reason:** User wants both (Q2, Q3).
**Non-negotiable:** Selection UI on first login, auto-spawn still works.

---

## V. COMPROMISES I'M WILLING TO MAKE

### 1. Timeline Flexibility
**My Round 3:** 20 weeks (6 phases)
**Compromise:** Accept 12-week timeline by deferring variants to Phase 4+

### 2. Credit Store UI
**My Round 3:** Separate credit store
**Compromise:** In-catalog purchasing (simpler UX)

### 3. Extraction Device Design
**My Round 3:** N-key withdrawal
**Compromise:** Ship console + station terminal hybrid

### 4. Manual Screenshot Previews
**My Round 3:** Automated rendering
**Compromise:** Manual screenshots (user decision Q11)

### 5. Antag Part Economy
**My Round 3:** Faction-specific antag parts
**Compromise:** Unified rare/superior parts for antag (consumable)

---

## VI. FINAL RECOMMENDED ARCHITECTURE

**SYNTHESIS APPROACH:** Best elements from all agents, adapted to user decisions.

### Foundation
- Fix persistence load bug (my discovery)
- 7-table database schema (Agent C's approach, my revision)
- Transaction logging for economy balancing

### Economy Model
- Rarity tiers: basic/advanced/rare/superior
- User conversion rates: 10k/15k/20k/25k credits
- Round completion: 100 base credits
- Progression: ~10 rounds basic, ~30 standard, ~50+ advanced

### Physical Parts System
- Parts spawn in world (ruins, planets, space)
- Extraction via ship console OR station terminal
- One-way deposit (cannot reverse)
- Physical trading before extraction

### Implementation (Agent D's phased approach)
- Phase 0: Database setup (1 week)
- Phase 1: Physical parts + extraction (2 weeks)
- Phase 2: Credit store + purchasing (1 week)
- Phase 3: Ship unlocking + spawning (2 weeks)
- Phase 4: TGUI catalog (3 weeks)
- Phase 5: Integration testing (2 weeks)
- **TOTAL: 11-12 weeks**

### Integration Architecture
- **Battlepass:** `grant_battlepass_ship_part()`, `grant_battlepass_credits()`, query functions
- **Custom Roles:** Ship upgrade hook, pre-spawn validation, shared tables
- **Automation:** `automation_output_ship_part()`, recipe definitions, economy coordination

### Testing Strategy
- Phase 0: Database CRUD tests
- Phases 1-3: Unit tests per component
- Phase 4: Integration tests with 3 teams
- Phase 5: Load testing (50+ players), performance metrics

---

## VII. CONCLUSION

**VERDICT:** No Round 3 proposal viable as-is. All must adapt to rarity tiers, database, extraction device, and integration points.

**RECOMMENDED:** Synthesis combining Agent D's phasing, Agent C's database, Agent A's economy, and my bug fix + testing rigor.

**CRITICAL PATH:** 12 weeks to MVP (database + rarity + extraction + unlocking + catalog)

**READY FOR CONSENSUS** - All agents must align on this revised architecture.

---

**Agent B - Round 4 Verdict Complete**

### Agent C's Final Verdict

**STATUS: DATABASE ARCHITECTURE VALIDATED - ADAPTING TO USER SPECIFICATIONS**

After reviewing all Round 3 proposals and the comprehensive user decisions in Round 3.5, I can definitively say: **My database persistence approach was correct from the start**, and I'm pleased the user validated this choice. However, the user's detailed requirements necessitate significant schema revisions to accommodate rarity tiers, physical parts, and integration with three major feature teams.

---

## I. PROPOSAL ANALYSIS & POSITION

### Which Proposal I Support

I support **a synthesis of all agents' approaches with my database foundation**:

- **My Round 3 database schema** (core persistence layer - validated by user)
- **Agent A & B's three-tier economy** (Credits → Parts → Blueprints) - aligns with user Q8
- **Agent D's phased approach** (risk reduction, testable increments)
- **Agent B's dual ship systems** (regular permanent + antag consumable) - user confirmed both needed

**However, ALL agents' Round 3 proposals are now partially invalidated** due to:
- Elimination of faction-specific parts (NEU/NT-C/SYN-C) → rarity tiers
- Physical parts in world until extraction (major new mechanic)
- Three separate feature teams requiring integration points

### What Compromises I'm Willing to Make

✅ **Accepted Compromises:**

1. **Rarity tiers over faction parts** - User's decision is clear, makes sense for expandability
2. **Defer skins to Phase 4+** - User explicitly wants to skip this initially (Q13)
3. **Manual screenshots for MVP** - Simpler than auto-generation (Q11)
4. **Per-character credits** - While unlocks are account-wide (Q6 hybrid approach)
5. **Starter ship selection system** - Coexist with auto-spawn ship (Q2/Q3)
6. **Both large and small antag ships** - User needs both scales (Q4)

### What Are My Non-Negotiables

❌ **Non-Negotiable Requirements:**

1. **Database persistence ONLY** - No savefiles, no JSON. User confirmed SQL (Q7).
2. **Transaction-safe operations** - Use DB transactions for multi-table updates
3. **Normalized schema** - Prevent data duplication, maintain referential integrity
4. **Account-wide unlocks** - User specified hybrid (Q6), unlocks must be ckey-scoped
5. **Per-character credits** - Separate from unlocks, enables alt progression
6. **Audit trail** - Track part extraction, blueprint unlocks, credit transactions
7. **Integration hooks** - Clean APIs for Battlepass/Custom Roles/Automation teams
8. **No credits trading** - User explicitly said no (Q17)

---

## II. REVISED DATABASE SCHEMA - RARITY TIER SYSTEM

### Critical Changes from Round 3

My Round 3 schema assumed faction parts (NEU/NT-C/SYN-C). The user's rarity tier decision requires:

- Replace `part_type TEXT` with `rarity_tier TEXT`
- Add `extracted BOOLEAN` to track physical vs deposited state
- New table for extraction devices
- Credits per-character instead of per-ckey
- Integration tables for Battlepass/Custom Roles/Automation

### Complete Database Schema v2.0

```sql
-- ============================================================================
-- PLAYER PROGRESSION TABLES
-- ============================================================================

-- Table: player_credits (REVISED - per character, not per ckey)
CREATE TABLE player_credits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    character_slot INTEGER NOT NULL,
    character_name TEXT,
    credits INTEGER DEFAULT 0,
    lifetime_earned INTEGER DEFAULT 0,  -- Analytics
    lifetime_spent INTEGER DEFAULT 0,   -- Analytics
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(ckey, character_slot)
);

CREATE INDEX idx_credits_ckey ON player_credits(ckey);

-- Table: player_ship_parts (REVISED - rarity tiers, extraction tracking)
CREATE TABLE player_ship_parts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    rarity_tier TEXT NOT NULL,  -- 'basic', 'advanced', 'rare', 'superior'
    part_count INTEGER DEFAULT 0,
    total_found INTEGER DEFAULT 0,      -- Lifetime found in world
    total_extracted INTEGER DEFAULT 0,  -- Lifetime deposited
    total_purchased INTEGER DEFAULT 0,  -- Lifetime bought with credits
    total_crafted INTEGER DEFAULT 0,    -- Lifetime crafted via automation
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(ckey, rarity_tier)
);

CREATE INDEX idx_parts_ckey ON player_ship_parts(ckey);

-- Table: player_ship_blueprints (RENAMED from unlocks - clearer terminology)
CREATE TABLE player_ship_blueprints (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    ship_template_path TEXT NOT NULL,  -- e.g., '/datum/map_template/shuttle/voidcrew/bogatyr'
    unlocked_via TEXT,                 -- 'purchase', 'starter', 'admin_grant', 'battlepass'
    parts_spent_basic INTEGER DEFAULT 0,
    parts_spent_advanced INTEGER DEFAULT 0,
    parts_spent_rare INTEGER DEFAULT 0,
    parts_spent_superior INTEGER DEFAULT 0,
    unlocked_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (ckey, ship_template_path)
);

CREATE INDEX idx_blueprints_ckey ON player_ship_blueprints(ckey);

-- Table: round_ship_spawns (per-round one-spawn tracking)
CREATE TABLE round_ship_spawns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    round_id TEXT NOT NULL,  -- Round identifier
    ckey TEXT NOT NULL,
    character_name TEXT,
    ship_template_path TEXT NOT NULL,
    ship_type TEXT,  -- 'regular', 'antag_large', 'antag_small'
    spawn_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(round_id, ckey)
);

CREATE INDEX idx_spawns_round ON round_ship_spawns(round_id);
CREATE INDEX idx_spawns_ckey ON round_ship_spawns(ckey);

-- ============================================================================
-- PHYSICAL PARTS & EXTRACTION SYSTEM
-- ============================================================================

-- Table: physical_ship_parts (tracks physical items in world before extraction)
CREATE TABLE physical_ship_parts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    part_uid TEXT UNIQUE NOT NULL,  -- Unique identifier for physical object
    rarity_tier TEXT NOT NULL,
    spawned_method TEXT,  -- 'world_spawn', 'loot', 'battlepass_claim', 'admin'
    current_location TEXT,  -- For admin tracking
    holder_ckey TEXT,  -- Who's holding it (if known)
    extracted BOOLEAN DEFAULT FALSE,
    extracted_by_ckey TEXT,
    extracted_date TIMESTAMP,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_physical_parts_extracted ON physical_ship_parts(extracted);
CREATE INDEX idx_physical_parts_uid ON physical_ship_parts(part_uid);

-- Table: extraction_devices (track extraction device usage)
CREATE TABLE extraction_devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_uid TEXT UNIQUE NOT NULL,
    location_description TEXT,
    total_extractions INTEGER DEFAULT 0,
    last_used TIMESTAMP,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: extraction_history (audit trail for part extraction)
CREATE TABLE extraction_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    character_name TEXT,
    part_uid TEXT NOT NULL,
    rarity_tier TEXT NOT NULL,
    device_uid TEXT,
    extraction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (part_uid) REFERENCES physical_ship_parts(part_uid)
);

CREATE INDEX idx_extraction_ckey ON extraction_history(ckey);

-- ============================================================================
-- ANTAGONIST SHIP SYSTEM (separate from regular)
-- ============================================================================

-- Table: player_antag_parts (separate currency, consumable)
CREATE TABLE player_antag_parts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    antag_type TEXT NOT NULL,  -- 'syndicate_ops', 'blood_cult', 'xenomorph', etc.
    part_count INTEGER DEFAULT 0,
    lifetime_earned INTEGER DEFAULT 0,
    lifetime_spent INTEGER DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(ckey, antag_type)
);

CREATE INDEX idx_antag_parts_ckey ON player_antag_parts(ckey);

-- Table: antag_ship_purchases (track consumable antag ship spawns)
CREATE TABLE antag_ship_purchases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    round_id TEXT NOT NULL,
    ckey TEXT NOT NULL,
    character_name TEXT,
    antag_ship_template TEXT NOT NULL,
    antag_type TEXT NOT NULL,
    parts_spent INTEGER NOT NULL,
    purchase_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_antag_purchases_round ON antag_ship_purchases(round_id);

-- ============================================================================
-- INTEGRATION TABLES (for separate feature teams)
-- ============================================================================

-- Table: battlepass_rewards_claimed (integration with Battlepass team)
CREATE TABLE battlepass_rewards_claimed (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    battlepass_season TEXT NOT NULL,
    reward_tier INTEGER NOT NULL,
    reward_type TEXT NOT NULL,  -- 'ship_part', 'credits', 'blueprint', etc.
    reward_data TEXT,  -- JSON blob with details (rarity_tier, amount, etc.)
    claimed_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(ckey, battlepass_season, reward_tier)
);

CREATE INDEX idx_battlepass_ckey ON battlepass_rewards_claimed(ckey);

-- Table: custom_role_slots (integration with Custom Roles team)
CREATE TABLE custom_role_slots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    ship_template_path TEXT NOT NULL,
    slot_index INTEGER NOT NULL,
    role_type TEXT,  -- 'security', 'engineering', 'medical', 'custom'
    custom_role_id INTEGER,  -- Reference to custom role definition
    purchased_equipment_ids TEXT,  -- JSON array of equipment IDs from marketplace
    slot_unlocked BOOLEAN DEFAULT FALSE,
    unlock_date TIMESTAMP,
    UNIQUE(ckey, ship_template_path, slot_index)
);

CREATE INDEX idx_custom_roles_ckey ON custom_role_slots(ckey);

-- Table: automation_crafting_progress (integration with Automation team)
CREATE TABLE automation_crafting_progress (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    automation_setup_id TEXT,  -- Reference to player's automation setup
    recipe_type TEXT NOT NULL,  -- 'ship_part_basic', 'ship_part_advanced', etc.
    progress_percent DECIMAL(5,2) DEFAULT 0.0,
    resources_invested TEXT,  -- JSON blob
    started_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_date TIMESTAMP,
    UNIQUE(ckey, automation_setup_id, recipe_type)
);

CREATE INDEX idx_automation_ckey ON automation_crafting_progress(ckey);

-- ============================================================================
-- ECONOMY & REWARDS TRACKING
-- ============================================================================

-- Table: credit_transactions (audit trail for all credit changes)
CREATE TABLE credit_transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ckey TEXT NOT NULL,
    character_slot INTEGER NOT NULL,
    amount INTEGER NOT NULL,  -- Positive = earned, Negative = spent
    transaction_type TEXT NOT NULL,  -- 'round_reward', 'part_purchase', 'equipment_buy', etc.
    description TEXT,
    balance_after INTEGER,
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_transactions_ckey ON credit_transactions(ckey);
CREATE INDEX idx_transactions_date ON credit_transactions(transaction_date);

-- Table: round_rewards (track what players earned each round)
CREATE TABLE round_rewards (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    round_id TEXT NOT NULL,
    ckey TEXT NOT NULL,
    character_slot INTEGER NOT NULL,
    credits_earned INTEGER DEFAULT 0,
    parts_earned TEXT,  -- JSON: {"basic": 1, "advanced": 0, ...}
    playtime_minutes INTEGER,
    objectives_completed INTEGER,
    reward_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(round_id, ckey)
);

CREATE INDEX idx_round_rewards_round ON round_rewards(round_id);
CREATE INDEX idx_round_rewards_ckey ON round_rewards(ckey);

-- ============================================================================
-- STARTER SHIP SELECTION
-- ============================================================================

-- Table: player_starter_choice (track which starter ship was chosen)
CREATE TABLE player_starter_choice (
    ckey TEXT PRIMARY KEY,
    starter_template_path TEXT NOT NULL,
    chosen_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- ADMIN & ANALYTICS TABLES
-- ============================================================================

-- Table: admin_grants (track admin-given currency/parts/blueprints)
CREATE TABLE admin_grants (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    admin_ckey TEXT NOT NULL,
    target_ckey TEXT NOT NULL,
    grant_type TEXT NOT NULL,  -- 'credits', 'parts', 'blueprint', 'antag_parts'
    grant_data TEXT,  -- JSON blob
    reason TEXT,
    grant_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_admin_grants_target ON admin_grants(target_ckey);
CREATE INDEX idx_admin_grants_admin ON admin_grants(admin_ckey);

-- Table: economy_metrics_snapshot (periodic snapshots for balance analysis)
CREATE TABLE economy_metrics_snapshot (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    snapshot_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_players INTEGER,
    total_credits_circulation INTEGER,
    avg_credits_per_player DECIMAL(10,2),
    total_parts_basic INTEGER,
    total_parts_advanced INTEGER,
    total_parts_rare INTEGER,
    total_parts_superior INTEGER,
    total_blueprints_unlocked INTEGER,
    avg_blueprints_per_player DECIMAL(5,2)
);
```

---

## III. ECONOMY DESIGN - RARITY TIER SYSTEM

### Part Pricing (User-Provided Conversion Rates)

User specified in Q8:
- 1 basic part = 10,000 Credits
- 1 advanced part = 15,000 Credits
- 1 rare part = 20,000 Credits
- 1 superior part = 25,000 Credits

**Analysis:** These are HIGH prices given 100 credits per round base reward. This creates a long-term progression system.

### Ship Blueprint Unlock Costs (Agent C Proposal)

**Starter Ships (FREE - choose one):**
- 0 parts - Player chooses one starter template, gets blueprint automatically
- Examples: Bogatyr, Box, Small Freighter

**Budget Ships (Entry Level):**
- Cost: 2 basic parts (20,000 credits worth)
- Time to earn: ~200 rounds of base rewards
- Examples: Basic cargo hauler, scout ship

**Standard Ships (Mid Tier):**
- Cost: 1 advanced part (15,000 credits) OR 3 basic parts (30,000 credits)
- Time to earn: ~150-300 rounds
- Examples: Delta, upgraded freighters

**Premium Ships (High Tier):**
- Cost: 1 rare part (20,000 credits) + 2 advanced parts (30,000 credits) = 50,000 credits worth
- Time to earn: ~500 rounds
- Examples: Heavy cruisers, specialized ships

**Elite Ships (End Game):**
- Cost: 2 superior parts (50,000 credits) + 1 rare part (20,000 credits) = 70,000 credits worth
- Time to earn: ~700 rounds
- Examples: Flagships, unique vessels

### Earning Rates (Balanced for Long-Term Play)

**Round Completion Rewards (User confirmed Q20):**
- Base: 100 credits
- Time bonus: +5 credits per minute played (cap at 60 min = 300 bonus)
- Objective bonus: +50-200 credits for major objectives
- **Total per round: 100-600 credits average (~250 avg)**

**Physical Parts in World:**
- Basic parts: Common spawns (ruins, planets, loot)
- Advanced parts: Uncommon spawns (dangerous areas)
- Rare parts: Rare spawns (deep space, hard enemies)
- Superior parts: Very rare spawns (boss encounters, hard puzzles)

**Battlepass Integration (separate team):**
- Battlepass rewards parts at milestones
- Bypasses credit → part conversion
- Direct part injection into economy

**Automation Crafting (separate team):**
- Craft parts using automation minigame
- Resource investment required
- Alternative to buying/finding

### Economic Balance Analysis

**Time to First Ship Unlock (after starter):**
- 20,000 credits / 250 avg per round = **~80 rounds (20-40 hours gameplay)**

**Time to Premium Ship:**
- 50,000 credits / 250 avg = **~200 rounds (50-100 hours gameplay)**

**Time to Elite Ship:**
- 70,000 credits / 250 avg = **~280 rounds (70-140 hours gameplay)**

**Mitigation for Long Grind:**
- Physical parts in world (skip credit grind)
- Battlepass rewards (passive progression)
- Automation crafting (active alternative)
- Multiple earning sources (not just rounds)

### Antag Ship Economy (Separate System)

**Antag Parts:**
- NOT rarity tiered (different system)
- Faction-specific: syndicate_ops, blood_cult, xenomorph, etc.
- Consumable (spent each purchase, NOT permanent unlock)

**Antag Part Costs:**
- Purchase with credits: 50,000 credits per antag part (VERY expensive)
- Find in world: Super rare drops (0.1% chance from high-tier loot)
- Admin grants: Special events

**Antag Ship Unlock Costs:**
- Small antag ships: 1 antag part (solo spawns)
- Large antag ships: 2 antag parts (crew converts)

**Balance Rationale:**
- Antag ships should be RARE (user wants special/expensive)
- Per-round consumable discourages spam
- High cost ensures antag rounds are special events

---

## IV. PHYSICAL PARTS & EXTRACTION SYSTEM

### Physical Part Item Objects

```dm
/obj/item/ship_part
    name = "ship part"
    desc = "A component used to construct ship blueprints. Must be extracted to your account."
    icon = 'icons/obj/ship_parts.dmi'
    icon_state = "part_basic"
    w_class = WEIGHT_CLASS_SMALL

    var/rarity_tier = "basic"  // basic, advanced, rare, superior
    var/part_uid = null  // Unique ID for tracking
    var/extracted = FALSE  // Has it been deposited?

/obj/item/ship_part/Initialize()
    . = ..()
    part_uid = "[world.time]-[rand(1,999999)]"  // Generate UID
    log_part_creation()

/obj/item/ship_part/examine(mob/user)
    . = ..()
    . += "<span class='notice'>Rarity: [capitalize(rarity_tier)]</span>"
    if(extracted)
        . += "<span class='warning'>This part has already been extracted.</span>"
    else
        . += "<span class='info'>Use an extraction device to deposit this to your account.</span>"

/obj/item/ship_part/basic
    rarity_tier = "basic"
    icon_state = "part_basic"

/obj/item/ship_part/advanced
    rarity_tier = "advanced"
    icon_state = "part_advanced"

/obj/item/ship_part/rare
    rarity_tier = "rare"
    icon_state = "part_rare"

/obj/item/ship_part/superior
    rarity_tier = "superior"
    icon_state = "part_superior"
```

### Extraction Device

```dm
/obj/machinery/ship_part_extractor
    name = "ship part extraction terminal"
    desc = "Insert ship parts to deposit them into your account for blueprint purchases."
    icon = 'icons/obj/machines/extraction_terminal.dmi'
    icon_state = "extractor"
    density = TRUE
    anchored = TRUE

    var/device_uid = null
    var/total_extractions = 0

/obj/machinery/ship_part_extractor/Initialize()
    . = ..()
    device_uid = "[world.time]-extractor-[rand(1,999999)]"

/obj/machinery/ship_part_extractor/attackby(obj/item/I, mob/user, params)
    if(!istype(I, /obj/item/ship_part))
        return ..()

    var/obj/item/ship_part/part = I

    if(part.extracted)
        to_chat(user, "<span class='warning'>This part has already been extracted!</span>")
        return

    if(!user.client)
        to_chat(user, "<span class='warning'>You need an account to extract parts!</span>")
        return

    // Extract part to player's account
    visible_message("<span class='notice'>[user] inserts [part] into [src].</span>")
    playsound(src, 'sound/machines/terminal_processing.ogg', 50, TRUE)

    // Database update
    extract_part_to_account(user.client, part)

    // Mark as extracted (don't delete, for audit trail)
    part.extracted = TRUE
    qdel(part)  // Remove from world

    to_chat(user, "<span class='notice'>Extracted 1x [part.rarity_tier] part to your account!</span>")

/obj/machinery/ship_part_extractor/proc/extract_part_to_account(client/C, obj/item/ship_part/part)
    // Update player_ship_parts table
    var/datum/db_query/update_parts = SSdbcore.NewQuery(
        "INSERT INTO player_ship_parts (ckey, rarity_tier, part_count, total_extracted) \
        VALUES (:ckey, :tier, 1, 1) \
        ON CONFLICT(ckey, rarity_tier) DO UPDATE SET \
        part_count = part_count + 1, \
        total_extracted = total_extracted + 1, \
        last_updated = CURRENT_TIMESTAMP",
        list("ckey" = C.ckey, "tier" = part.rarity_tier)
    )
    update_parts.Execute()
    qdel(update_parts)

    // Update physical_ship_parts table (mark as extracted)
    var/datum/db_query/mark_extracted = SSdbcore.NewQuery(
        "UPDATE physical_ship_parts SET \
        extracted = 1, \
        extracted_by_ckey = :ckey, \
        extracted_date = CURRENT_TIMESTAMP \
        WHERE part_uid = :uid",
        list("ckey" = C.ckey, "uid" = part.part_uid)
    )
    mark_extracted.Execute()
    qdel(mark_extracted)

    // Insert extraction history record
    var/datum/db_query/log_extraction = SSdbcore.NewQuery(
        "INSERT INTO extraction_history \
        (ckey, character_name, part_uid, rarity_tier, device_uid) \
        VALUES (:ckey, :charname, :uid, :tier, :device)",
        list(
            "ckey" = C.ckey,
            "charname" = C.mob?.real_name || "Unknown",
            "uid" = part.part_uid,
            "tier" = part.rarity_tier,
            "device" = device_uid
        )
    )
    log_extraction.Execute()
    qdel(log_extraction)

    // Update extractor stats
    total_extractions++
    var/datum/db_query/update_device = SSdbcore.NewQuery(
        "UPDATE extraction_devices SET \
        total_extractions = :count, \
        last_used = CURRENT_TIMESTAMP \
        WHERE device_uid = :uid",
        list("count" = total_extractions, "uid" = device_uid)
    )
    update_device.Execute()
    qdel(update_device)
```

### Physical Parts Spawning

```dm
// Loot spawner for ship parts
/obj/effect/spawner/lootdrop/ship_parts
    name = "ship part spawner"
    loot = list(
        /obj/item/ship_part/basic = 70,
        /obj/item/ship_part/advanced = 20,
        /obj/item/ship_part/rare = 8,
        /obj/item/ship_part/superior = 2
    )

// Place on maps in ruins, planet surfaces, derelicts
/area/ruin/space/derelict
    // Add ship part spawners to these areas
```

---

## V. INTEGRATION POINTS FOR FEATURE TEAMS

### Integration 1: Battlepass Team

**Hook:** When player claims battlepass reward containing ship parts

```dm
/datum/battlepass/proc/claim_reward(client/C, tier)
    // ... battlepass logic ...

    if(reward_type == "ship_part")
        // Grant physical part OR direct deposit
        var/rarity = reward_data["rarity"]
        var/quantity = reward_data["quantity"]

        // Direct deposit to account (bypasses physical extraction)
        var/datum/db_query/grant_parts = SSdbcore.NewQuery(
            "INSERT INTO player_ship_parts (ckey, rarity_tier, part_count, total_found) \
            VALUES (:ckey, :tier, :qty, :qty) \
            ON CONFLICT(ckey, rarity_tier) DO UPDATE SET \
            part_count = part_count + :qty, \
            last_updated = CURRENT_TIMESTAMP",
            list("ckey" = C.ckey, "tier" = rarity, "qty" = quantity)
        )
        grant_parts.Execute()
        qdel(grant_parts)

        // Log in battlepass_rewards_claimed
        var/datum/db_query/log_claim = SSdbcore.NewQuery(
            "INSERT INTO battlepass_rewards_claimed \
            (ckey, battlepass_season, reward_tier, reward_type, reward_data) \
            VALUES (:ckey, :season, :tier, 'ship_part', :data)",
            list("ckey" = C.ckey, "season" = current_season, "tier" = tier, "data" = json_encode(reward_data))
        )
        log_claim.Execute()
        qdel(log_claim)
```

**Data Flow:**
- Battlepass team manages XP, progression, season rewards
- Ship purchase team provides API to grant parts directly
- `battlepass_rewards_claimed` table tracks what was given

### Integration 2: Custom Roles Team

**Hook:** When player spawns ship, apply custom role configuration

```dm
/datum/map_template/shuttle/proc/spawn_with_custom_roles(client/owner)
    // Load custom role configuration from database
    var/datum/db_query/query = SSdbcore.NewQuery(
        "SELECT slot_index, role_type, custom_role_id, purchased_equipment_ids \
        FROM custom_role_slots \
        WHERE ckey = :ckey AND ship_template_path = :template AND slot_unlocked = 1",
        list("ckey" = owner.ckey, "template" = type)
    )

    if(query.Execute())
        var/list/role_config = list()
        while(query.NextRow())
            role_config += list(list(
                "slot" = text2num(query.item[1]),
                "role_type" = query.item[2],
                "custom_role_id" = text2num(query.item[3]),
                "equipment_ids" = json_decode(query.item[4])
            ))

        // Pass to custom roles team's system
        apply_custom_role_configuration(role_config)

    qdel(query)
```

**Data Flow:**
- Custom roles team manages role builder UI, equipment marketplace, slot purchases
- Ship purchase team reads `custom_role_slots` table before spawning
- Applies configuration to ship job slots before crew join

### Integration 3: Automation Crafting Team

**Hook:** When automation setup completes part crafting

```dm
/datum/automation_setup/proc/complete_ship_part_craft(client/owner, recipe_type)
    // Automation team determines recipe success
    // Ship purchase team grants the part

    var/rarity = parse_rarity_from_recipe(recipe_type)

    // Grant part to account
    var/datum/db_query/grant_craft = SSdbcore.NewQuery(
        "INSERT INTO player_ship_parts (ckey, rarity_tier, part_count, total_crafted) \
        VALUES (:ckey, :tier, 1, 1) \
        ON CONFLICT(ckey, rarity_tier) DO UPDATE SET \
        part_count = part_count + 1, \
        total_crafted = total_crafted + 1, \
        last_updated = CURRENT_TIMESTAMP",
        list("ckey" = owner.ckey, "tier" = rarity)
    )
    grant_craft.Execute()
    qdel(grant_craft)

    // Mark automation progress complete
    var/datum/db_query/mark_complete = SSdbcore.NewQuery(
        "UPDATE automation_crafting_progress SET \
        completed_date = CURRENT_TIMESTAMP, \
        progress_percent = 100.0 \
        WHERE ckey = :ckey AND automation_setup_id = :id AND recipe_type = :recipe",
        list("ckey" = owner.ckey, "id" = setup_id, "recipe" = recipe_type)
    )
    mark_complete.Execute()
    qdel(mark_complete)
```

**Data Flow:**
- Automation team manages minigame, resource collection, recipes
- Ship purchase team provides API to grant crafted parts
- `automation_crafting_progress` table tracks active crafts

---

## VI. STARTER SHIP SELECTION FLOW

User specified (Q2/Q3): Choose starter from templates, get blueprint, can upgrade

```dm
/datum/new_player_setup/proc/choose_starter_ship(client/C)
    // TGUI interface shows starter templates
    var/list/starter_options = list(
        /datum/map_template/shuttle/voidcrew/bogatyr,
        /datum/map_template/shuttle/voidcrew/box,
        /datum/map_template/shuttle/voidcrew/small_freighter
    )

    // Player selects one
    var/chosen_template = tgui_input_list(C, "Choose your starter ship:", "Starter Selection", starter_options)

    if(!chosen_template)
        return FALSE

    // Grant blueprint permanently
    var/datum/db_query/grant_starter = SSdbcore.NewQuery(
        "INSERT INTO player_ship_blueprints \
        (ckey, ship_template_path, unlocked_via) \
        VALUES (:ckey, :template, 'starter') \
        ON CONFLICT DO NOTHING",
        list("ckey" = C.ckey, "template" = chosen_template)
    )
    grant_starter.Execute()
    qdel(grant_starter)

    // Record choice
    var/datum/db_query/record_choice = SSdbcore.NewQuery(
        "INSERT INTO player_starter_choice (ckey, starter_template_path) \
        VALUES (:ckey, :template) \
        ON CONFLICT(ckey) DO NOTHING",
        list("ckey" = C.ckey, "template" = chosen_template)
    )
    record_choice.Execute()
    qdel(record_choice)

    to_chat(C, "<span class='notice'>Starter ship unlocked: [initial(chosen_template.name)]</span>")
    return TRUE
```

**Coexistence with Auto-Spawn Ship:**
- Auto-spawn ship still exists (backward compatible)
- Players can either join auto-spawn OR spawn their own starter
- Latejoin menu shows both options

---

## VII. ANTAG SHIP SYSTEM (Both Scales)

User specified (Q4): Need BOTH large-scale and small-scale antag ships

### Large Antag Ships (Crew Converts)

```dm
/datum/map_template/shuttle/antag/large
    name = "Large Antag Ship"
    antag_type = "syndicate_ops"
    crew_capacity = 6
    converts_all_crew = TRUE  // All spawned crew become antags

/datum/map_template/shuttle/antag/large/purchase_and_spawn(client/purchaser)
    // Check antag parts
    var/datum/db_query/check_parts = SSdbcore.NewQuery(
        "SELECT part_count FROM player_antag_parts \
        WHERE ckey = :ckey AND antag_type = :type",
        list("ckey" = purchaser.ckey, "type" = antag_type)
    )

    if(!check_parts.Execute() || !check_parts.NextRow())
        to_chat(purchaser, "<span class='warning'>You don't have any [antag_type] parts!</span>")
        qdel(check_parts)
        return FALSE

    var/parts_available = text2num(check_parts.item[1])
    qdel(check_parts)

    if(parts_available < 2)  // Large ships cost 2 antag parts
        to_chat(purchaser, "<span class='warning'>Large antag ships require 2 [antag_type] parts!</span>")
        return FALSE

    // Deduct parts (CONSUMABLE)
    var/datum/db_query/deduct = SSdbcore.NewQuery(
        "UPDATE player_antag_parts SET \
        part_count = part_count - 2, \
        lifetime_spent = lifetime_spent + 2 \
        WHERE ckey = :ckey AND antag_type = :type",
        list("ckey" = purchaser.ckey, "type" = antag_type)
    )
    deduct.Execute()
    qdel(deduct)

    // Spawn ship, convert all crew
    spawn_ship_and_convert_crew(purchaser, convert_all = TRUE)
```

### Small Antag Ships (Solo Only)

```dm
/datum/map_template/shuttle/antag/small
    name = "Small Antag Ship"
    antag_type = "syndicate_infiltrator"
    crew_capacity = 1
    solo_only = TRUE  // Only purchaser spawns

/datum/map_template/shuttle/antag/small/purchase_and_spawn(client/purchaser)
    // Check antag parts
    // ... (same check as large) ...

    if(parts_available < 1)  // Small ships cost 1 antag part
        to_chat(purchaser, "<span class='warning'>Small antag ships require 1 [antag_type] part!</span>")
        return FALSE

    // Deduct parts
    // ... (deduct 1 instead of 2) ...

    // Spawn ship, only purchaser
    spawn_ship_and_convert_crew(purchaser, convert_all = FALSE)
```

---

## VIII. FINAL RECOMMENDED ARCHITECTURE

### Synthesis of All Proposals

I recommend a **phased hybrid architecture** combining:

1. **My database foundation** (validated by user)
2. **Rarity tier economy** (user's explicit change)
3. **Physical parts + extraction** (user's new mechanic)
4. **Three-tier progression** (Credits → Parts → Blueprints)
5. **Dual antag systems** (large + small ships)
6. **Integration hooks** (Battlepass, Custom Roles, Automation)

### Architecture Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                    FEATURE INTEGRATION LAYER                     │
│  ┌──────────────┬──────────────┬──────────────────────────────┐ │
│  │  Battlepass  │ Custom Roles │  Automation Crafting         │ │
│  │  (XP, tiers) │ (gear slots) │  (Factorio minigame)         │ │
│  └──────────────┴──────────────┴──────────────────────────────┘ │
│         ↓ grants parts    ↓ reads slots      ↓ crafts parts     │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    SHIP PURCHASE CORE LAYER                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Three-Tier Economy: Credits → Parts (rarity) → Blueprints│   │
│  │ - Per-character credits (100/round base)                 │   │
│  │ - Physical parts in world (extract via device)           │   │
│  │ - Account-wide blueprints (permanent unlocks)            │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ TGUI Ship Catalog                                        │   │
│  │ - Regular Ships Tab (unlocks, spawn once/round)          │   │
│  │ - Antag Ships Tab (consumable, large + small)            │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    DATABASE PERSISTENCE LAYER                    │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ SQL Database (normalized schema, transactions)           │   │
│  │ - player_credits (per-character)                         │   │
│  │ - player_ship_parts (rarity tiers, extraction tracking)  │   │
│  │ - player_ship_blueprints (account-wide unlocks)          │   │
│  │ - physical_ship_parts (world items before extraction)    │   │
│  │ - Integration tables (battlepass, roles, automation)     │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    EXISTING GAME SYSTEMS                         │
│  SSshuttle.create_ship() → SSovermap → Job Assembly → Spawning  │
└─────────────────────────────────────────────────────────────────┘
```

### Implementation Phases

**PHASE 0: Database Foundation (Week 1)**
- Create all database tables (schema v2.0)
- Implement database query wrappers
- Transaction-safe update procs
- Migration tools (if needed)
- Testing harness

**PHASE 1: Credits & Parts System (Weeks 2-3)**
- Credits earning (round rewards)
- Credits → parts purchase interface
- Physical part item objects
- Extraction device implementation
- Rarity tier balancing

**PHASE 2: Blueprint Unlock System (Weeks 4-5)**
- Parts → blueprint purchase
- Account-wide unlock tracking
- Starter ship selection flow
- Per-round spawn limiting
- Database audit trails

**PHASE 3: TGUI Ship Catalog (Weeks 6-8)**
- React catalog components
- Regular ships tab
- Antag ships tab (both scales)
- Preview images (manual screenshots)
- Filter/search/sort

**PHASE 4: Physical World Integration (Weeks 9-10)**
- Loot spawners (parts in world)
- Extraction terminal placement
- Trading mechanics (steal/trade physical parts)
- World generation integration

**PHASE 5: Antag Ship System (Weeks 11-12)**
- Antag part economy
- Large antag ship templates
- Small antag ship templates
- Crew conversion logic
- Consumable purchase flow

**PHASE 6: Feature Team Integration (Weeks 13-14)**
- Battlepass integration API
- Custom roles integration hooks
- Automation crafting integration
- Cross-team testing

**PHASE 7: Balance & Polish (Weeks 15-16)**
- Economy tuning (earn rates, costs)
- UI polish
- Admin tools (grant currency, reset unlocks)
- Analytics dashboard
- Bug fixes

**TOTAL: 16 weeks (4 months)**

---

## IX. NON-NEGOTIABLES SUMMARY

I will NOT compromise on:

1. **Database persistence** - SQL only, no savefiles
2. **Normalized schema** - Proper database design
3. **Transaction safety** - Multi-table updates must be atomic
4. **Audit trails** - Track all currency/part movements
5. **Account-wide unlocks** - Blueprints shared across characters
6. **Per-character credits** - Each character slot separate progression
7. **No credit trading** - User explicitly said no
8. **Integration hooks** - Clean APIs for feature teams

---

## X. CONCLUSION

**My Round 3 database proposal was fundamentally correct** - the user validated database persistence over savefiles. However, the user's Round 3.5 decisions require significant schema and mechanic revisions:

**Major Adaptations:**
- Faction parts → Rarity tiers (expandable system)
- Digital-only parts → Physical parts + extraction device
- Isolated system → Integration with 3 major feature teams
- Simple economy → Complex multi-source progression

**My Confidence Level:**
- Database architecture: **100% confident** (user validated)
- Rarity tier schema: **95% confident** (designed for expandability)
- Physical extraction mechanic: **90% confident** (novel, needs testing)
- Feature team integration: **85% confident** (depends on their implementations)
- Economy balance: **75% confident** (needs extensive tuning)

**Final Recommendation:**
Proceed with my revised database schema, implement in phases 0-7, coordinate closely with Battlepass/Custom Roles/Automation teams, and plan for extensive economy balancing in Phase 7.

**This architecture fulfills ALL user decisions and provides a solid foundation for long-term feature expansion.**

---

**Agent C's Final Verdict Complete - Ready for Implementation**

### Agent D's Final Verdict

[Agent D: Read all proposals from Round 3. Explain:

1. Which proposal do you support (can be your own or synthesis of multiple)?
2. What compromises are you willing to make?
3. What are your non-negotiable requirements?
4. Your final recommended approach]

---

## Final Consensus

[TO BE FILLED: Once all agents have provided their verdicts, synthesize the consensus here. This should be filled by either:

- A facilitator agent that reads all verdicts and synthesizes
- The human orchestrating the agents
- A final round where agents collaboratively write this section]

### Agreed Architecture

### Implementation Plan

### Open Questions

### Next Steps
