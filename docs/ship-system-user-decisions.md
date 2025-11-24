# Ship Purchase System Redesign - User Decisions Round 3.5

**Part of:** [Ship System Redesign Master Index](ship-system-master-index.md)

## Document Navigation
- **Previous:** [Round 3: Architectural Proposals](ship-system-round3-proposals.md)
- **Next:** [Round 4: Final Consensus](ship-system-round4-consensus.md)
- **Related:** [Round 1-2: Analysis & Debates](ship-system-round1-2-analysis.md) | [Master Index](ship-system-master-index.md)

---

## Table of Contents
1. [Critical Architecture Changes](#critical-architecture-changes)
   - Eliminate faction-specific parts → Rarity tiers
   - Database persistence (SQL) not savefiles
   - Parts unlock blueprints (one-time, not consumable)
   - Physical parts with extraction device
2. [Critical Gameplay Decisions](#critical-gameplay-decisions)
   - New player experience
   - Antag ships (two-scale system)
   - Ship customization and upgrades
3. [Implementation Decisions](#implementation-decisions)
   - Manual screenshot previews
   - Credits vs parts definitions
   - Feature team integrations

---

## Document Purpose

This document contains the user's comprehensive feedback after reviewing all Round 3 proposals. The user answered 21 detailed questions that significantly changed the architectural direction.

**MAJOR PIVOTS:**
- **Faction Parts ELIMINATED** → Replaced with rarity tier system (basic/advanced/rare/superior)
- **Savefile Persistence REJECTED** → Database (SQL) mandated
- **Digital Parts REJECTED** → Physical parts with extraction device required
- **Simple Antag System REJECTED** → Two-scale system (large/small) required

**Impact:** All Round 3 proposals needed major revision. Agents incorporated these changes in Round 4 final verdicts.

**This is the most critical document** for understanding final requirements.

---
## USER DECISIONS - ROUND 3.5 CRITICAL INPUT

**Status:** User has reviewed all Round 3 proposals and answered 21 critical questions

**Source:** `combined-agent-questions.md` (completed by user)

**Purpose:** All agents MUST incorporate these decisions into Round 4 final verdicts

---

### CRITICAL ARCHITECTURE CHANGES

#### 🔴 MAJOR CHANGE: Eliminate Faction-Specific Parts

**User Decision (Q8):**
> "Eliminate faction specific ship parts and move to part rarity. so different tiers of parts, maybe make it expandable for other types in the future."

**Impact:**
- **REMOVE:** NEU/NT-C/SYN-C faction parts
- **ADD:** Rarity tiers - basic/advanced/rare/superior parts
- **Expandable:** Design for future part types
- All agents' proposals assumed faction parts - this is now INVALID
- Economy model must be redesigned around rarity tiers

**Conversion rates user provided:**
- 1 basic part = 10,000 Credits
- 1 advanced part = 15,000 Credits
- 1 rare part = 20,000 Credits
- 1 superior part = 25,000 Credits

---

#### 🔴 Parts System Model - CONFIRMED

**User Decision (Q1):**
✅ **Option A:** Parts unlock ship blueprint once, spawn FREE forever
- Parts are one-time unlock currency, NOT consumable
- Spend 2 parts → ship unlocked → spawn free every round (respecting one-spawn limit)

**User Decision (Q8 clarification):**
> "Keep ship parts, have them buy blueprints - while having credits buy ship parts"

**Three-Tier Economy:**
1. **Credits** (persistent, account-bound, not tradeable) → buy parts
2. **Parts** (rarity tiers, physical items in world) → unlock ship blueprints
3. **Blueprints** (permanent unlocks) → spawn ships free (one per round)

---

#### 🔴 Database Persistence - CONFIRMED

**User Decision (Q7):**
✅ **Database (SQL)** - not savefiles
- Use whatever database system the server already uses
- **No migration needed** - server is not live
- `player_ship_parts` table does NOT exist yet, needs creation
- All agents must design database schemas, not savefile extensions

---

#### 🔴 Physical Parts System

**User Decision (Q10, Q19):**
> "ship parts are used for buying blueprints. you get them through finding them in world and the battlepass. you have to 'Extract' the ship parts somehow to put them into your account rather than just being able to use them in hand. maybe a device that you can insert them into. they can be scattered across the galaxy, you have to find them. they can be found on ruins in space and on planets. the ship parts are just an item in the end though."

**Key Changes:**
- Parts are **physical items in the world** until extracted
- Need **extraction device** to deposit into account
- Parts found in: ruins (space), planets, scattered across galaxy
- **REMOVE N-key feature** (no digital → physical conversion)
- Parts can be traded/stolen while physical
- Once extracted, cannot be pulled back out

**Battlepass Integration:**
- Battlepass grants ship parts as rewards (this creates dependency on battlepass feature team)

---

### CRITICAL GAMEPLAY DECISIONS

#### New Player Experience (Q2, Q3)

**User Decision:**
✅ Multiple choices combined:
- **Pre-unlocked starter ships** (Option A)
- **Keep initial auto-spawn ship** (Option C)
- **Custom:** "You should be able to choose your starter ship from the starter templates, and then you get the blueprint for it. You should be able to upgrade your starter ship like all the others, by upgrading your slots and their gear."

**Implementation:**
- New players choose from starter ship templates
- Chosen starter ship is permanently unlocked (get blueprint)
- Starter ships can be upgraded (slots + gear) like all ships
- Initial auto-spawn ship still exists (backward compatible)
- Players can join auto-spawn OR spawn their own starter

---

#### Antag Ships (Q4, Q5)

**User Decision (Q4):**
✅ **Both B and D:** Need BOTH large-scale and small-scale antag ships
> "We need both large scale and small scale antag ships."

**Implementation:**
- **Large antag ships:** All crew convert to antag (Option B)
- **Small antag ships:** Solo-only, purchaser spawns alone (Option D)
- Two different antag ship types in catalog

**User Decision (Q5):**
✅ **Option A:** Direct purchase (no unlock)
- Antag ships are per-round consumable purchases
- No permanent unlock step
- Pay antag parts each round to spawn directly

---

#### Persistence Scope (Q6)

**User Decision:**
✅ **Option C - Hybrid**
- **Unlocks:** Account-wide (all characters share)
- **Credits:** Per-character (separate for each character slot)

---

#### Round-End Rewards (Q14)

**User Decision:**
✅ **Option A - Keep both**
- 1 part + 100 credits per round
- Dual reward system
- Battlepass can modify/enhance this

---

#### Currency Trading (Q17)

**User Decision:**
✅ **Option B - No**
> "the credits are for now only generated from rounds played. it can be used for permanent unlocks like clothing etc"

- Credits are account-bound, cannot be traded
- Generated from round completion
- Used for permanent unlocks (ship parts, clothing, equipment)

---

#### Crafting Sources (Q15)

**User Decision:**
> "I want a factorio / satisfactory like minigame for ship parts that allows you to use automation to craft them."

**Implementation:**
- Automation crafting minigame (separate feature team)
- Factorio/Satisfactory-inspired
- Can craft ship parts through automation
- This is a MAJOR feature, not simple crafting

---

#### Ship Preview Images (Q11)

**User Decision:**
✅ **Option A - Manual screenshots**
> "i think a is simplest for now"

- Dev team screenshots each ship in Dream Maker
- High quality, time-intensive
- No automated generation for MVP

---

#### Ship Skins (Q13)

**User Decision:**
✅ **Option E - Defer entirely to Phase 4+**
> "lets skip this entirely for now"

- Not a priority
- Focus on core unlock system first
- Can add skins later

---

#### Edge Cases (Q16)

**User Decision:**
- **Admin override:** Enabled (shuttle manipulator already exists)
- **Server crash:** Not a concern (will restart timer)
- **Auto-deletion AFK:** Not implementing warnings

---

### ECONOMY NUMBERS

**User Decision (Q20):**
- Round completion base reward: **100 credits**
- Selling parts for credits: **Varies per part rarity** (agents should propose sane defaults)

**User note on Q18:**
- Changing from faction parts to rarity tiers invalidates Agent A's proposed numbers
- Agents must propose new economy based on rarity system

---

### MAJOR NEW FEATURES (SEPARATE TEAMS)

#### 1. Battlepass + XP System (Q10)

**User Decision:**
> "we will need an xp system for the battlepass. wow we need a whole thing on the battlepass and xp."

**Scope:**
- XP earned from gameplay
- Battlepass progression
- Ship parts as battlepass rewards
- Persistent across rounds
- **Separate 4-agent team handling this** (`feature-battlepass-xp-system.md`)

---

#### 2. Custom Roles + Equipment Marketplace (Q12)

**User Decision:**
> "Okay check it - we allow you to purchase custom roles for your ships. They can be applied to any ship, and they have some way to create them through tgui. For any ship you have an upgrade menu. You can upgrade the number of slots for each role. you can also change the roles. there will be pre-determined role types like security and engineering and medical. so you could do 3 security and 0 anything else. each role would spawn with corresponding gear. NOW IMAGINE: You can create a custom role. you can choose equipment for every slot on your character. That equipment is provided from the equipment marketplace - like a full toolbelt for the belt slot or a space helmet for your helmet slot or cat ears for your ear slot. AND CHECK THIS - You will have had to BUY all of that gear from a OOC market that uses your credits. So you want 1 slot for your custom ninja main character and 3 cowboy side slots? Gotta buy the ninja gear for yourself, and the cowboy gear in duplicate for each slot. This would have to be a HEAVY feature with a full ui for this. we're going to steal monkestations's monkecoin. its a persistent coin you earn from round ends. we'll expand off that to build this custom slot feature. i downloaded their repo, so we need to expand on this in another document."

**Scope:**
- Ship upgrade menu (per-ship interface)
- Pre-determined role types (Security, Engineering, Medical, etc.)
- Custom role creation (TGUI role builder)
- Equipment marketplace (buy gear for every character slot)
- Slot count upgrades
- Monkestation's monkecoin integration
- **HEAVY FEATURE**
- **Separate 4-agent team handling this** (`feature-custom-roles-equipment.md`)

---

#### 3. Automation Crafting Minigame (Q15)

**User Decision:**
> "I want a factorio / satisfactory like minigame for ship parts that allows you to use automation to craft them."

**Scope:**
- Factorio/Satisfactory-inspired automation
- Craft ship parts through automation
- Alternative to finding/buying parts
- **Separate 4-agent team handling this** (`feature-automation-crafting.md`)

---

### LEGACY/MIGRATION

**User Decision (Q9):**
> "what existing players"

**Interpretation:**
- Server is not live, no existing players to migrate
- Clean slate, no legacy migration needed
- Can design from scratch without backward compatibility concerns

---

### CONSTRAINTS FOR ROUND 4

**All agents must incorporate:**

✅ **Rarity tier parts** (basic/advanced/rare/superior) - NOT faction parts
✅ **Database persistence** - NOT savefiles
✅ **Three-tier economy:** Credits → Parts → Blueprints
✅ **Physical parts in world** until extracted via device
✅ **Starter ship selection** from templates
✅ **Keep auto-spawn initial ship**
✅ **Both large and small antag ships** (different crew handling)
✅ **Antag ships direct purchase** (no unlock)
✅ **Account-wide unlocks, per-character credits**
✅ **Credits not tradeable**
✅ **100 credits per round + 1 part** (round-end rewards)
✅ **Manual screenshot previews**
✅ **Defer skins to Phase 4+**
✅ **Integration points for:** Battlepass, Custom Roles, Automation (separate teams)

**Invalidated assumptions:**
❌ Faction-specific parts (NEU/NT-C/SYN-C)
❌ Savefile persistence
❌ N-key physical trading system
❌ Simple crafting (now complex automation minigame)
❌ Single antag ship model

---

### UPDATED AGENT INSTRUCTIONS FOR ROUND 4

**Agents A, B, C, D:**

You must now complete Round 4 Final Verdict incorporating ALL user decisions above.

**Your Round 4 must address:**

1. **Revised Architecture:**
   - How does your Round 3 proposal adapt to rarity tiers instead of faction parts?
   - How does database schema replace your savefile proposals?
   - How do physical parts + extraction device work?
   - How do starter ship selection + auto-spawn coexist?

2. **Economy Redesign:**
   - Pricing for basic/advanced/rare/superior parts
   - Balance between finding parts, buying with credits, crafting via automation, battlepass rewards
   - Credit earning (100 per round) vs spending

3. **Integration Points:**
   - Where does battlepass grant parts?
   - Where does automation crafting fit?
   - Where does custom role application happen in spawn flow?

4. **Database Schema:**
   - Tables for credits (per-character)
   - Tables for parts inventory (rarity tiers)
   - Tables for ship unlocks (account-wide)
   - Tables for extraction/deposit tracking

5. **Final Consensus:**
   - Which Round 3 proposal is closest to user's vision?
   - What compromises between agent proposals given new constraints?
   - Final recommended architecture incorporating ALL user decisions

**Proceed to Round 4 Final Verdict below.**

---

