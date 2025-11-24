editors notes: I want you to split off from this document when we have things that need deeper discussions

# Combined Agent Questions - All Agents A, C, D

**Status:** Awaiting user responses before Round 4 consensus

**Purpose:** All 3 agents (A, C, D) submitted clarification questions. This document combines them, merges duplicates, and organizes by priority.

**Instructions:** Check boxes `[x]` for your preferred options and fill in additional comments as needed.

---

## 🔴 CRITICAL QUESTIONS (Must Answer Before Round 4)

### Q1: Parts System Interpretation - UNLOCK vs BUILD (Agent C)

**Context:** Your decision said "Currency can be used to buy parts. Parts are used to buy ships PERMANENTLY." What does "permanently" mean?

**Options:**

- [x] **A. Parts unlock ship blueprint once, spawn FREE forever** (Agent C's assumption)
  - Example: Spend 2 NEU parts → Bogatyr unlocked → Spawn Bogatyr free every round
  - Parts are one-time unlock currency

- [ ] **B. Parts unlock blueprint, but still cost parts to spawn each round**
  - Example: Spend 2 NEU parts → Bogatyr blueprint unlocked → Still costs 2 NEU parts to spawn
  - Blueprint persists, but ships still cost parts to build

**Your Answer:**

```


```

---

### Q2: New Player Experience - Starter Ships/Currency (Agents A, C)

**Context:** Brand new players have no unlocked ships. How do they join their first round?

**Options:**

- [x] **A. Pre-unlocked starter ships** - 1-2 basic ships automatically unlocked for new players
  - Example: New players have "Box-class Hospital Ship" pre-unlocked

- [ ] **B. Starter currency/parts** - Enough resources to unlock first ship immediately
  - Example: New players start with 200 Ship Credits + 1 NEU part

- [x] **C. Keep initial auto-spawn ship** - Round-start ship still spawns (current system), catalog is for ADDITIONAL ships
  - Example: One ship auto-spawns at round start like current, players can buy more from catalog

- [ ] **D. Join existing ships only** - Must join other players' ships until earn first unlock
  - Example: New players join the auto-spawned ship or other players' ships

- [x] **E. Custom solution:** You should be able to choose your starter ship from the starter templates., and then you get the blueprint for it. You should be able to upgrade your starter ship like all the others, by upgrading your slots and their gear.

**Your Answer:**

```


```

---

### Q3: Initial Ship System - Keep or Remove? (Agent A)

**Context:** Currently one ship auto-spawns at round start (NT or Syndicate). With unlock system, what happens?

**Options:**

- [x] **A. Keep it** - Auto-spawn ship still exists, players can join it OR spawn their own
  - Backward compatible, safe for new players

- [ ] **B. Remove it** - Players MUST have unlocked ships (requires starter ships from Q2)
  - Clean break, fully new system

- [ ] **C. Transition period** - Keep for a few weeks/months while economy establishes, then remove
  - Gradual migration

- [ ] **D. Community ship** - Keep as special "community ship" anyone can join, separate from personal unlocks
  - Hybrid approach

- [ ] **E. Custom solution:** \***\*\*\*\*\***\*\*\***\*\*\*\*\***\_\_\_\_\***\*\*\*\*\***\*\*\***\*\*\*\*\***

**Your Answer:**

```


```

---

### Q4: Antag Ships - Multi-Crew Conversion (Agent A)

**Context:** You said spawning on antag ship converts you to that antag. What if multiple players crew the same antag ship?

**Options:**

- [ ] **A. Purchaser only** - Only buyer converts to antag, others join as normal crew
  - Antag can manually recruit crew

- [x] **B. All crew convert** - ALL players spawning on antag ship auto-convert to that antag
  - Instant antag team

- [ ] **C. Choice prompt** - Purchaser auto-converts, others get "Join as [Antag]?" prompt
  - Player choice

- [x] **D. Solo-only** - Antag ships are single-player, purchaser spawns alone
  - No crew complexity

- [ ] **E. Custom solution:** \***\*\*\*\*\***\*\*\***\*\*\*\*\***\_\_\_\_\***\*\*\*\*\***\*\*\***\*\*\*\*\***

**Your Answer:**

```
We need both large scale and small scale antag ships.

```

---

### Q5: Antag Ships - Unlock First or Direct Purchase? (Agents C, D)

**Context:** Do antag ships require a one-time unlock, or are they direct per-round purchases?

**Options:**

- [x] **A. Direct purchase (no unlock)** - Just pay antag parts each round to spawn
  - Example: Have 3 Syndicate Tokens → Purchase Syndicate ship this round (no unlock step)

- [ ] **B. Unlock first, then pay per-round** - One-time unlock cost, THEN pay each round
  - Example: 5 Syndicate Tokens to unlock → Then 3 Syndicate Tokens per round to spawn

**Your Answer:**

```


```

---

### Q6: Persistence Scope - Per-Character or Account-Wide? (Agent A)

**Context:** Should unlocks and currency be tied to individual character slots or shared across account?

**Options:**

- [ ] **A. Per-character** - Each character slot has separate progress
  - Character 1 unlocks ≠ Character 2 unlocks

- [ ] **B. Account-wide** - All characters share unlocks and credits
  - Unlock once, all characters can use

- [x] **C. Hybrid** - Unlocks shared account-wide, credits per-character
  - Shared ships, separate economy

- [ ] **D. Custom solution:** \***\*\*\*\*\***\*\*\***\*\*\*\*\***\_\_\_\_\***\*\*\*\*\***\*\*\***\*\*\*\*\***

**Your Answer:**

```


```

---

### Q7: Database vs Savefile - Persistence Backend (Agents C, D)

**Context:** Agent C proposes DATABASE (SQL), others propose JSON savefiles. You mentioned database interest in future-topics.

**Options:**

- [x] **A. Database (SQL)** - Use SSdbcore, store everything in database
  - Agent C's proposal: SQL schema provided
  - Transaction-safe, structured, performant
  - Requires migration

- [ ] **B. JSON Savefiles** - Extend existing preference system
  - Agents A, D proposals
  - Simpler, no migration
  - File-based, corruption risk

- [ ] **C. Hybrid - JSON for MVP, migrate to DB later** - Agent B's proposal
  - Get working quickly with JSON
  - Plan DB migration for later phase

**Your Answer:**

```
no migration needed this server isnt live

```

**If Database chosen - what type?**

- [ ] BYOND's built-in SQL (sqlite)
- [ ] External MySQL
- [ ] External PostgreSQL
- [ x ] Other: **\*\***whatever everything else is using**\*\***

**Does `player_ship_parts` table already exist?**

- [ ] Yes, table exists (just missing load query)
- [x] No, need to create it
- [ ] Unsure, need to check

---

### Q8: Faction System - Keep or Unify? (Agents C, D)

**Context:** Current system has 3 faction-specific part types (NEU/NT-C/SYN-C).

**Options:**

- [ ] **A. Unified currency + faction-separated parts** (Agent C's proposal)
  - One Ship Credits currency (cross-faction)
  - Three part types (NEU/NT-C/SYN-C) for unlocking
  - Three faction unlock trees
  - Economic simplicity, game balance preserved

- [ ] **B. Fully unified** - One currency + one part type + all ships unlockable by anyone
  - Simplest system
  - Loses faction identity

- [ ] **C. Fully separated** - Three currencies (NEU/NT/SYN credits) + three part types
  - Most complex
  - Strongest faction identity

- [ ] **D. Unified currency + faction-themed trees** (Agent D's proposal)
  - One currency type
  - Catalog organized into faction "trees" (visual only, no hard restrictions)
  - Economic simplicity, design flavor

**Your Answer:**

```
Keep ship parts, have them buy blueprints - while having credits buy ship parts
Eliminate faction specific ship parts and move to part rarity. so different tiers of parts, maybe make it expandable for other types in the future.
Dont need to call them ship credits just credits. and watch out tg code already has a notion of credits which are round only... but maybe we could use them
```

---

## 🟡 IMPORTANT QUESTIONS (Affects Architecture)

### Q9: Legacy Parts Migration Strategy (Agents A, C)

**Context:** Once bug is fixed, existing players might have saved parts. What happens to them?

**Options:**

- [ ] **A. Convert parts → currency** - Fixed rate (e.g., 1 part = 100 Ship Credits)

- [ ] **B. Convert parts → ship unlocks** - If player had 2 NEU parts, auto-unlock a 2-part ship

- [ ] **C. Keep as parts** - Parts remain useful in new system for unlocking

- [ ] **D. Wipe and compensate** - Everyone starts fresh with generous starter unlocks/currency

- [ ] **E. Custom solution:** \***\*\*\*\*\***\*\*\***\*\*\*\*\***\_\_\_\_\***\*\*\*\*\***\*\*\***\*\*\*\*\***

**Your Answer:**

```
what existing players

```

---

### Q10: Parts System Future - Keep or Deprecate? (Agent D)

**Context:** What role do parts play in the NEW system?

**Options:**

- [ ] **A. Keep parts parallel with currency** (Agents A, B favor)
  - Both parts AND currency can unlock ships
  - Dual progression paths
  - More complex

- [ ] **B. Deprecate parts for unlocks, keep for trading** (Agents C, D favor)
  - New unlocks ONLY use currency
  - Physical parts become tradeable tokens (N-key preserved)
  - Single progression, preserves trading economy

- [ ] **C. Fully replace parts** - Remove parts entirely, currency only
  - Simplest, loses trading economy
  - No agents recommended this

- [ ] **D. Custom solution:** \***\*\*\*\*\***\*\*\***\*\*\*\*\***\_\_\_\_\***\*\*\*\*\***\*\*\***\*\*\*\*\***

**Your Answer:**

```
ship parts are used for buying blueprints. you get them through finding them in world and the battlepass. you have to "Extract" the ship parts somehow to put them into your account rather than just being able to use them in hand. maybe a device that you can insert them into. they can be scattered across the galaxy, you have to find them. they can be found on ruins in space and on planets.  the ship parts are just an item in the end though. we will need an xp system for the battlepass. wow we need a whole thing on the battlepass and xp. lets expand on this in a separate document

```

**If deprecating, conversion rates:**

- 1 basic part = 10000 Credits
- 1 advanced part = 15000 Credits
- 1 rare part = 20000 Credits
- 1 superior part = 25000 Credits
- ***

### Q11: Ship Preview Image Generation (Agents C, D)

**Context:** TGUI catalog needs ship preview images. How to generate them?

**Options:**

- [x] **A. Manual screenshots** - Dev team screenshots each ship in Dream Maker
  - High quality, time-intensive

- [ ] **B. Automated tool** - Script to parse .dmm and render PNG
  - Automatic, complex to build

- [ ] **C. Community submissions** - Players/contributors submit previews
  - Distributed workload, quality variation

- [ ] **D. Placeholder images initially** - Generic placeholders, replace later
  - Fastest to implement

- [ ] **E. Custom solution:** \***\*\*\*\*\***\*\*\***\*\*\*\*\***\_\_\_\_\***\*\*\*\*\***\*\*\***\*\*\*\*\***

**Your Answer:**

```
i think a is simplest for now

```

**Standard image size:** **\_\_\_** x **\_\_\_** pixels

---

### Q12: Customization Scope - How Deep? (Agent C)

**Context:** Phase 4 crew customization can range from simple to extremely complex.

**Options:**

- [ ] **A. Shallow** - Change job slot counts only (2 engineers → 3 engineers)

- [ ] **B. Medium** - Slot counts + outfit selection (engineer with advanced tools vs basic)

- [ ] **C. Deep** - Slot counts + outfits + custom job names + starting locations + equipment lists

- [ ] **D. Custom:** Specify exactly what you want: **\*\***\*\*\*\***\*\***\_\_\_**\*\***\*\*\*\***\*\***

**Your Answer:**

```
Okay check it - we allow you to purchase custom roles for your ships. They can be applied to any ship, and they have some way to create them through tgui. For any ship you have an upgrade menu. You can upgrade the number of slots for each role. you can also change the roles. there will be pre-determined role types like security and engineering and medical. so you could do 3 security and 0 anything else. each role would spawn with corresponding gear. NOW IMAGINE: You can create a custom role. you can choose equipment for every slot on your character. That equipment is provided from the equipment marketplace - like a full toolbelt for the belt slot or a space helmet for your helmet slot or cat ears for your ear slot. AND CHECK THIS - You will have had to BUY all of that gear from a OOC market that uses your credits. So you want 1 slot for your custom ninja main character and 3 cowboy side slots? Gotta buy the ninja gear for yourself, and the cowboy gear in duplicate for each slot. This would have to be a HEAVY feature with a full ui for this. we're going to steal monkestations's monkecoin. its a persistent coin you earn from round ends. we'll expand off that to build this custom slot feature. i downloaded their repo, so we need to expand on this in another document.

```

---

### Q13: Ship Skins Unlock Model (Agents A, D)

**Context:** You chose full map variants (.dmm files) for skins. How should they be unlocked?

**Options:**

- [ ] **A. Per-skin unlocks** - Default skin free, each variant costs credits to unlock (permanent)
  - Example: 100 credits per skin variant

- [ ] **B. Auto-unlock** - All skins automatically unlocked when you unlock the base ship

- [ ] **C. Per-round rental** - Selecting non-default skin costs credits each round

- [ ] **D. Prestige purchases** - Skins are expensive permanent unlocks (500+ credits)

- [x] **E. Defer entirely to Phase 4+** - Focus on core unlock system first, add skins later

**Your Answer:**

```
lets skip this entirely for now

```

---

### Q14: Round-End Part Rewards - Keep or Remove? (Agent A)

**Context:** Currently players get 1 random part per round end. With credits system, should we keep this?

**Options:**

- [x] **A. Keep both** - 1 part + 100 credits per round (dual rewards)

- [ ] **B. Credits only** - Remove part grants, 100 credits only (cleaner economy)

- [ ] **C. Transition period** - Both for 1-2 months, then credits only

- [ ] **D. Parts only** - Keep 1 part per round, no credits (minimal change)

**Your Answer:**

```


```

---

### Q15: Crafting Material Sources (Agent A)

**Context:** Crafting ship parts requires materials. Where should they come from?

**Options:**

- [ ] **A. Mining only** - Mine asteroids/planets for materials (existing system)

- [ ] **B. Alternative sources** - Salvaging wrecks, trading NPCs, mission rewards

- [ ] **C. Both** - Mining + alternative sources (most flexible)

- [ ] **D. Purchase with credits** - Buy materials from vendors (skip gathering)

**Your Answer:**

```
I want a factorio / satisfactory like minigame for ship parts that allows you to use automation to craft them.

```

---

### Q16: Per-Round Spawn Limits - Edge Cases (Agent C)

**Context:** One spawn per round is clear, but what about edge cases?

**Scenario A - Admin accidentally deletes ship:**

- [ ] Player stuck (strict rule)
- [x] Admin can override and allow re-spawn
- [ ] Automatic re-spawn if admin-deleted

**Scenario B - Server crash loses ship:**

- [ ] Player stuck
- [ ] Grace period (first 10 min can re-spawn)
- [ ] Automatic re-spawn after crash

**Scenario C - Auto-deletion when crew AFK:**

- [ ] Player stuck (intentional penalty)
- [ ] Warning before deletion
- [ ] Can re-spawn if auto-deleted (not combat)

**Your Answer:**

```
a is already enabled as we have a shuttle manipulator, b is pointless since server crash will restart timer, and c is not something i want to add

```

---

### Q17: Currency Trading - Allowed? (Agent C)

**Context:** Physical part trading exists (N key). Should Ship Credits also be tradeable?

**Options:**

- [ ] **A. Yes** - Players can convert credits → tradeable tokens (like parts)

- [x] **B. No** - Credits are account-bound, cannot trade (prevents exploits)

- [ ] **C. Limited** - Can trade with restrictions (max amount, trade tax, etc.)

**Your Answer:**

```
the credits are for now only generated from rounds played. it can be used for permanent unlocks like clothing etc
```

---

## 🟢 BALANCE/TUNING QUESTIONS (Can Adjust Later)

### Q18: Economy Numbers Validation (Agent A)

**Context:** Agent A proposed these values. Validate or adjust:

| Item                    | Agent A Proposal | Your Adjustment    |
| ----------------------- | ---------------- | ------------------ |
| Round completion reward | 100 credits      | **\_\_\_** credits |
| NEU part cost           | 500 credits      | **\_\_\_** credits |
| NT-C part cost          | 750 credits      | **\_\_\_** credits |
| SYN-C part cost         | 750 credits      | **\_\_\_** credits |
| Antag part cost         | 5000 credits     | **\_\_\_** credits |
| Crafting bonus          | 50 credits       | **\_\_\_** credits |
| Credit chip loot        | 10-500 credits   | **\_\_\_** credits |
| Ship skin unlock        | 100 credits      | **\_\_\_** credits |

**Your Answer:**

- [ ] **A. Values are fine** - Use Agent A's proposals
- [ ] **B. Adjust specific values** - See table above
- [ ] **C. Different approach:** We're changing from faction ship parts to rarity tiers

---

### Q19: Physical Trading Restrictions (Agent A)

**Context:** N key converts digital parts → physical items for trading. Should there be restrictions?

**Options:**

- [ ] **A. No restrictions** - Unlimited trading, free market

- [ ] **B. Cooldown** - Can only withdraw 1 part per hour

- [ ] **C. Small cost** - Pay 50 credits to withdraw physical part (anti-spam)

- [ ] **D. One-way** - Can give physical parts, but can't convert back to digital

**Your Answer:**

```
when in game you find parts and can extract / deposit them. until that point, they are physical items in the world that can be traded or stolen. once they are extracted you cannot pull them out. removal of N key feature

```

---

### Q20: Currency Earning Details (Agent D)

**Context:** How should players earn currency? (Already answered in user-decision-points.md, but clarify details)

You chose: Round completion + find/craft parts

**Additional details:**

- Round completion base reward: **100** credits
- Selling parts for credits - varies per part. come up with sane defaults.

**Other earning methods to add?**

```


```
