# Round 3 Proposals - User Review Summary

**Status:** All 4 agents (A, B, C, D) have completed Round 3 architectural proposals.

**Purpose:** Concise summary for user review before agents proceed to Round 4 consensus.

---

## Quick Comparison Table

| Aspect | Agent A | Agent B | Agent C | Agent D |
|--------|---------|---------|---------|---------|
| **Architecture Name** | Dual-Economy, Three-Tier | Three-Tier with Dual Ships | Three-Tier with DB | Phased Hybrid |
| **Persistence** | Savefile (JSON) | JSON for MVP, DB later | **DATABASE (SQL)** | Savefile (JSON) |
| **Timeline** | 16 weeks (4 phases) | 20 weeks (6 phases) | 10-13 weeks (4 phases) | Not specified |
| **Currency** | Credits (unified) | Ship Credits (SC) | Ship Credits (SC) | Ship Credits |
| **Parts Model** | Faction-specific | Faction-specific | Faction-specific | Faction-specific |
| **Antag Ships** | 5000 credits | Rare/expensive | Super rare/expensive | Not detailed |
| **Crafting Detail** | Materials + fabricators | Most detailed | Materials at benches | Least detailed |
| **TGUI Detail** | Moderate | Moderate | Moderate | **Most detailed** |
| **Code Examples** | DM code snippets | **Most DM code** | **SQL schema** | DM code snippets |
| **Testing Strategy** | Basic | **Comprehensive** | Basic | Basic |

---

## Agent A's Proposal

**Architecture:** Dual-Economy, Three-Tier Progression

**Timeline:** 16 weeks across 4 phases

**Key Strengths:**
- Clear phased delivery with week-by-week breakdown
- Balanced technical detail across all aspects
- Preserves existing infrastructure well

**Unique Features:**
- Credits earned from loot chips (physical items)
- Crafting gives bonus credits (incentivizes crafting economy)
- Ship naming and loadout selection (Phase 4)

**Persistence:** Savefile-based (extends existing `/datum/preferences`)

**Antag Ships:** 5000 credits for antag parts, separate from regular

---

## Agent B's Proposal

**Architecture:** Three-Tier Progression with Dual Ship Systems

**Timeline:** 20 weeks across 6 phases (most conservative)

**Key Strengths:**
- **Most comprehensive testing strategy** (Phase 6 dedicated to testing)
- **Most detailed code examples** (actual DM code for many components)
- JSON for MVP with clear DB migration path documented
- Physical trading economy preservation emphasized

**Unique Features:**
- 6 phases (adds "Integration" and "Testing" phases)
- Credit tokens as lootable physical items
- Detailed migration strategy from savefiles to DB
- Explicit testing phase with test scenarios

**Persistence:** JSON for MVP, DB migration path documented for later

**Antag Ships:** Rare/expensive, detailed auto-antagonist conversion system

---

## Agent C's Proposal

**Architecture:** Three-Tier Permanent Unlock System with Dual Ship Economies

**Timeline:** 10-13 weeks across 4 phases (most optimistic)

**Key Strengths:**
- **Only proposal with actual DATABASE implementation** (SQL schema provided)
- Explicit database tables for all persistence
- Transaction-safe DB queries
- Clear fix for Agent B's bug using database

**Unique Features:**
- Complete SQL schema provided
- Database tables: player_ship_currency, player_ship_parts, player_antag_parts, player_ship_unlocks, player_ship_customizations, round_ship_spawns
- Per-round tracking in DB
- Database-backed from day 1 (not migration later)

**Persistence:** **DATABASE (SQL)** - only proposal with this

**Antag Ships:** Super rare/expensive, separate DB table for antag parts

---

## Agent D's Proposal

**Architecture:** Phased Hybrid Architecture

**Timeline:** Not specified (phases described, no time estimates)

**Key Strengths:**
- **Most detailed TGUI/UI design** (complete UI mockups)
- Pluggable currency earning system (easy to extend)
- Three ship preview generation options analyzed
- Clear backward compatibility path

**Unique Features:**
- `/datum/bank_account/player_meta` (mirrors ship bank accounts)
- Parts-to-currency conversion system (legacy migration)
- Pluggable earning sources (easy to add new earning methods)
- Most detailed catalog UI wireframes

**Persistence:** Savefile-based (extends `/datum/preferences`)

**Antag Ships:** Not detailed (acknowledged as gap)

---

## Universal Agreements (All 4 Agents)

✅ Three-tier progression: Currency → Parts → Unlocks
✅ Dual ship systems: Regular (permanent) + Antag (consumable)
✅ TGUI catalog with image previews
✅ Fix persistence bug FIRST (Phase 0)
✅ Preserve thread safety (`shuttle_loading` mutex)
✅ One spawn per round limit
✅ Faction-specific parts remain (NEU/NT-C/SYN-C)
✅ Hybrid earning (passive round rewards + active finding/crafting)
✅ Full map variants for skins (separate .dmm files)

---

## Key Differences

### 1. Persistence Approach

**DATABASE (Agent C only):**
- Pros: Transaction-safe, structured, performant, no savefile corruption
- Cons: Requires DB setup, migration complexity

**SAVEFILES (Agents A, B, D):**
- Pros: Extends existing system, simpler initial setup
- Cons: JSON corruption risk, less structured
- **Agent B:** Proposes JSON for MVP, DB migration later

**User mentioned database interest** in future-discussion-topics.md

---

### 2. Timeline Estimates

- **Agent C:** 10-13 weeks (optimistic, has DB complexity)
- **Agent A:** 16 weeks (moderate)
- **Agent B:** 20 weeks (conservative, includes dedicated testing phase)
- **Agent D:** No estimate

---

### 3. Phase Breakdown

**4 Phases (A, C, D):**
- Phase 0: Bug fix
- Phase 1: TGUI catalog
- Phase 2: Currency/unlocks
- Phase 3: Customization

**6 Phases (B only):**
- Phase 0: Bug fix
- Phase 1: TGUI catalog
- Phase 2: Currency system
- Phase 3: Unlock system
- Phase 4: Crafting & antag ships
- Phase 5: Integration
- Phase 6: Testing & polish

---

### 4. Technical Detail Focus

- **Agent A:** Balanced across all areas
- **Agent B:** Code implementation + testing strategy
- **Agent C:** Database schema + persistence
- **Agent D:** UI/UX design + pluggable architecture

---

## Questions for User

### 1. Database Decision (CRITICAL)

**You mentioned database interest in future-discussion-topics.md**

Options:
- **A.** Use Agent C's DATABASE approach (SQL from day 1)
- **B.** Use Agent B's approach (JSON for MVP, migrate to DB later)
- **C.** Stay with savefiles (Agents A & D)

**Your decision:**

---

### 2. Timeline Preference

- Agent C: 10-13 weeks (fast but ambitious with DB)
- Agent A: 16 weeks (moderate, savefile)
- Agent B: 20 weeks (includes testing phase, most conservative)
- Agent D: No estimate

**Your timeline constraints/preferences:**

---

### 3. Testing Strategy

Only Agent B has dedicated testing phase (Phase 6).

**Do you want dedicated testing phase?**
- [ ] Yes - follow Agent B's 6-phase model
- [ ] No - testing integrated into each phase (A, C, D model)

**Your preference:**

---

### 4. Proposal Synthesis

Which elements from which proposals do you want in the final plan?

**From Agent A:**
- [ ] Loot chips for currency earning
- [ ] Crafting gives bonus credits
- [ ] 16-week timeline
- [ ] Other: _______________

**From Agent B:**
- [ ] 6-phase breakdown (adds Integration + Testing phases)
- [ ] Most comprehensive code examples
- [ ] JSON → DB migration path
- [ ] 20-week conservative timeline
- [ ] Other: _______________

**From Agent C:**
- [ ] Database persistence (SQL schema)
- [ ] Transaction-safe DB queries
- [ ] Database from day 1 (no migration)
- [ ] 10-13 week optimistic timeline
- [ ] Other: _______________

**From Agent D:**
- [ ] Detailed TGUI/UI designs
- [ ] Pluggable earning system
- [ ] /datum/bank_account/player_meta pattern
- [ ] Parts-to-currency conversion
- [ ] Other: _______________

---

### 5. Mandated Elements

What MUST be in the final plan?

1.
2.
3.
4.
5.

---

### 6. Rejected Elements

What must NOT be in the final plan?

1.
2.
3.

---

### 7. Additional Guidance

Any other feedback for Round 4 consensus?


---

## Next Steps Options

### Option A: Proceed to Round 4 Consensus
- Agents read your feedback above
- Agents synthesize proposals based on your mandates
- Agents reach final consensus incorporating your preferences

### Option B: Introduce New Topics First
Before Round 4, introduce topics from future-discussion-topics.md:
- [ ] Database architecture discussion (expand on Agent C's schema)
- [ ] Creative agent review (4 new agents for creative enhancements)
- [ ] Task breakdown planning (break into small achievable parts)

### Option C: Request Specific Follow-Up
Ask specific agents to elaborate on specific areas:
- [ ] Agent C: Expand database schema with more detail
- [ ] Agent B: More detail on testing strategy
- [ ] Agent D: More detail on TGUI implementation
- [ ] Other: _______________

---

**Your choice:**
- [ ] Option A: Proceed to Round 4 with my feedback above
- [ ] Option B: Introduce new topics first (specify which)
- [ ] Option C: Request follow-up (specify what)
- [ ] Option D: Other: _______________

