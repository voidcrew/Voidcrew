# Agent C - Critical Questions Before Final Architecture

**Status:** Awaiting user responses

**Purpose:** These questions will significantly affect the Round 3 architectural proposal. Please check boxes and provide answers below.

---

## CRITICAL QUESTIONS (NEED ANSWERS)

### 1. Parts Interpretation - Unlock vs Build

**Context:** User decision said: "Currency can be used to buy parts. Parts are used to buy ships PERMANENTLY."

**Question:** What does "permanently" mean exactly?

- [ ] **Option A (Agent C's assumption):** Spend parts ONCE to unlock a ship blueprint, then spawn that ship FREE every round forever (parts are unlock currency)
  - Example: Spend 2 NEU parts → Bogatyr unlocked → Can spawn Bogatyr for free every round

- [ ] **Option B:** Parts unlock the BLUEPRINT permanently, but you still need to spend parts each time you BUILD/spawn the ship (blueprint persists, but ships still cost parts to spawn)
  - Example: Spend 2 NEU parts → Bogatyr blueprint unlocked → Still costs 2 NEU parts each round to spawn Bogatyr

**Your Answer:**
```
[Write answer here]
```

---

### 2. Antag Ships - Unlock First or Direct Purchase?

**Question:** Do antag ships require a one-time unlock, or are they direct per-round purchases?

- [ ] **Option A (Agent C's assumption):** Antag ships have NO unlock step - you just pay antag parts each round to spawn directly (no permanent unlock)
  - Example: Have 3 Syndicate Tokens → Can purchase Syndicate Battlecruiser this round (no unlock needed)

- [ ] **Option B:** You must UNLOCK antag ships first with a one-time cost, THEN pay antag parts each round to spawn
  - Example: Spend 5 Syndicate Tokens to unlock → Then costs 3 Syndicate Tokens per round to spawn

**Your Answer:**
```
[Write answer here]
```

---

### 3. New Player Experience - Starter Unlocks?

**Context:** If ships must be unlocked before spawning, brand new players have nothing unlocked.

**Question:** How do new players join their first round?

- [ ] **Option A:** Everyone starts with 1-2 basic ships pre-unlocked (tutorial/starter ships)
  - Example: New players automatically have "Box-class Hospital Ship" unlocked

- [ ] **Option B:** Players start with 0 unlocks but enough currency/parts to unlock their first ship immediately
  - Example: New players have 200 Ship Credits + 1 NEU part to unlock a starter ship

- [ ] **Option C:** Initial round-start ship still spawns automatically (keep current system), catalog is only for ADDITIONAL ships mid-round
  - Example: Round starts with one auto-spawned ship (like current), players can buy MORE ships from catalog

- [ ] **Option D (Custom):** Something else entirely

**Your Answer:**
```
[Write answer here]
```

---

### 4. Ship Preview Image Generation - How?

**Context:** Agent C proposed pre-rendered .dmm → PNG ship previews for TGUI catalog.

**Question:** How should we generate these preview images?

- [ ] **Option A:** BYOND has built-in map rendering tools (if this exists, specify which)

- [ ] **Option B:** Write custom Python/tool to parse .dmm files and render to PNG

- [ ] **Option C:** Manual screenshots of each ship (labor intensive but simple)

- [ ] **Option D:** No images in Phase 1 - launch catalog without previews, add images later

- [ ] **Option E (Custom):** Other method

**Your Answer:**
```
[Write answer here]
```

---

### 5. Customization Scope - How Deep?

**Context:** Crew customization can range from simple to extremely complex.

**Question:** How deep should Phase 4 customization go?

- [ ] **Shallow:** Change job slot counts only (2 engineers → 3 engineers)

- [ ] **Medium:** Job slot counts + outfit selection (engineer with advanced tools vs basic)

- [ ] **Deep:** Slot counts + outfits + custom job names + starting locations + custom equipment lists

- [ ] **Custom:** Specify exactly what customization options you want

**Your Answer:**
```
[Write answer here]
```

---

### 6. Database Type Confirmation

**Context:** User clarified system uses database, not savefiles. Agent B found missing load operation.

**Question A:** What database system is being used?

- [ ] BYOND's built-in SQL (sqlite)
- [ ] External MySQL
- [ ] External PostgreSQL
- [ ] Other: _______________

**Question B:** Does the table `player_ship_parts` already exist in the database?

- [ ] Yes, table exists (just missing load query)
- [ ] No, table doesn't exist (need to create it)
- [ ] Unsure, need to check

**Your Answer:**
```
[Write answer here]
```

---

### 7. Per-Round Limit - Edge Cases

**Context:** One spawn per round is clear for normal gameplay, but edge cases happen.

**Question:** Should there be exceptions to the one-spawn limit?

**Scenario A:** Admin accidentally deletes your ship
- [ ] Player stuck for rest of round (strict rule)
- [ ] Admin can override and allow re-spawn
- [ ] Automatic re-spawn if admin-deleted

**Scenario B:** Server crashes and ship is lost
- [ ] Player stuck for rest of round
- [ ] Grace period (e.g., first 10 minutes you can re-spawn)
- [ ] Automatic re-spawn after crash recovery

**Scenario C:** Ship deletion timer triggers when crew goes AFK
- [ ] Player stuck for rest of round (intentional penalty)
- [ ] Warning system before deletion
- [ ] Can re-spawn if ship auto-deleted (not destroyed in combat)

**Your Answer:**
```
[Write answer here]
```

---

### 8. Currency Trading - Allowed?

**Context:** Agent B found N-key physical part trading system. Parts can be traded, but what about currency?

**Question:** Should Ship Credits (currency) be tradeable between players?

- [ ] **Yes:** Players can convert Ship Credits → physical tradeable tokens (like parts)

- [ ] **No:** Ship Credits are account-bound, cannot be traded (prevents exploits)

- [ ] **Limited:** Can trade but with restrictions (e.g., max 100 SC per trade, or trade tax)

**Your Answer:**
```
[Write answer here]
```

---

### 9. Existing Parts Migration

**Context:** Once Agent B's bug is fixed, existing players might have parts saved in database.

**Question:** What should happen to existing parts when new system launches?

- [ ] **Option A:** Convert parts → currency at fixed rate (e.g., 1 part = 100 Ship Credits)

- [ ] **Option B:** Convert parts → ship unlocks (if player had 2 NEU parts, auto-unlock a 2-part NEU ship)

- [ ] **Option C:** Keep as parts in new system (parts still useful for unlocking ships)

- [ ] **Option D:** Wipe existing parts, everyone starts fresh (with starter unlocks/currency)

**Your Answer:**
```
[Write answer here]
```

---

### 10. Faction System - Keep or Unify?

**Context:** Current system has 3 separate faction part types (NEU/NT-C/SYN-C). Agent C proposed unified currency but faction-separated parts.

**Question:** What faction structure do you want?

- [ ] **Agent C's Proposal:** Unified currency (one Ship Credits currency) + faction-separated parts (NEU/NT-C/SYN-C parts) + faction-separated unlock trees
  - Simple economy, balanced progression

- [ ] **Fully Unified:** One currency + one part type + ships unlocked regardless of faction
  - Simplest system, lose faction identity

- [ ] **Fully Separated:** Three currencies (NEU credits, NT credits, SYN credits) + three part types
  - Most complex, strongest faction identity

**Your Answer:**
```
[Write answer here]
```

---

## PRIORITY RANKING

**Please rank these questions by importance to you (1 = most critical, 10 = least critical):**

- [ ] Question 1 (Parts interpretation): Rank ____
- [ ] Question 2 (Antag unlock): Rank ____
- [ ] Question 3 (New player experience): Rank ____
- [ ] Question 4 (Image generation): Rank ____
- [ ] Question 5 (Customization scope): Rank ____
- [ ] Question 6 (Database type): Rank ____
- [ ] Question 7 (Per-round edge cases): Rank ____
- [ ] Question 8 (Currency trading): Rank ____
- [ ] Question 9 (Parts migration): Rank ____
- [ ] Question 10 (Faction system): Rank ____

---

## ADDITIONAL QUESTIONS/CONCERNS

**Is there anything else Agent C should know before finalizing the architecture?**

```
[Write any additional context, concerns, or requirements here]
```

---

**When complete, save this file and let Agent C know answers are ready.**
