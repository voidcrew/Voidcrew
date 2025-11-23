# Ship Purchase System Redesign - User Decision Required

**Status:** 4 agents have completed Round 1 & 2 analysis. They need your input before proceeding to Round 3 architectural proposals.

---

## Executive Summary (TL;DR)

Your agents analyzed the ship purchase system and found:

1. **CRITICAL BUG:** Ship parts save but never load (progression system is broken)
2. **CONSENSUS:** All 4 agents agree on core approach (fix bug, extend existing template system, build TGUI catalog)
3. **NEEDS YOUR INPUT:** 5 key design decisions below before they can propose detailed architecture

---

## Critical Questions for You

The agents cannot proceed with Round 3 proposals without your answers to these:

### Question 1: Currency Earning System

**Context:** Feature request wants "currency system" but doesn't specify how players earn it.

**Current System:** Players earn ship parts via round-end rewards + lootable items

**Options:**

- [x] A. Round completion rewards (mimic current parts system)
- [ ] B. In-game performance bonuses (mining, trading, combat achievements)
- [ ] C. Hybrid (base reward + performance bonuses)
- [ ] D. Admin grants only (manual rewards)
- [x] E. Other: **\*\***You should be able to find and craft parts.**\*\***

**Your Decision:**

---

### Question 2: Parts System Future

**Context:** Current system uses consumable "ship parts" (spend each spawn). New system wants permanent unlocks (buy once, spawn forever). What happens to parts?

**Agent Split:**

- Agents A & B: Keep both systems in parallel (parts for trading, currency for unlocks)
- Agents C & D: Deprecate parts, replace with unified currency

**Options:**

- [ ] A. Keep parts as secondary progression path (parallel systems)
- [ ] B. Convert parts to currency at fixed rate, then deprecate
- [ ] C. Keep parts ONLY for player-to-player trading (no unlocks)
- [ ] D. Fully remove parts, replace with currency
- [x] E. Other: **\*\***Currency can be used to buy parts. parts are used to buy ships PERMANENTLY. **\*\***

**Your Decision:**

---

### Question 3: Per-Round Spawn Limits

**Context:** Current system allows infinite ship spawns if you have parts. New unlock system needs limits.

**Options:**

- [x] A. One spawn per round (destroyed ship = you're done)
- [ ] B. Re-spawn destroyed unlocked ships unlimited times
- [ ] C. Re-spawn with cooldown timer (e.g., 10 minutes)
- [ ] D. Re-spawn costs currency (not free even if unlocked)
- [ ] E. Other: **\*\***\_\_\_**\*\***

**Your Decision:**

---

### Question 4: Antagonist Ships

**Context:** GitHub issue mentions "antagonist ships" but doesn't clarify what this means.

**Options:**

- [ ] A. Ships only unlockable by antagonist roles
- [ ] B. Ships with special antagonist equipment pre-loaded
- [ ] C. Temporary per-round ships (not permanent unlocks)
- [ ] D. Ships with higher combat stats/weapons
- [ ] E. Not a priority feature / skip for now
- [x] F. Other: **\*\***Ships that are aligned with an antagonist or antag organization like the syndicate, blood cult, xenomorphs, etc. These antag ships will make anyone spawning on them into a specific antag and give them equipment related to that antagonist. These ships are per-round purchases and require special antag parts that are super rare or expensive**\*\***

**Your Decision:**

---

### Question 5: Ship Skins Complexity

**Context:** Feature request wants "different skins for ships" - complexity level wildly varies.

**Options:**

- [ ] A. Simple palette swaps (easy - just recolor sprites)
- [x] B. Full map variants (hard - separate .dmm files per skin)
- [ ] C. Cosmetic overlays (medium - visual effects on existing ships)
- [ ] D. Modular attachments (very hard - change ship structure)
- [ ] E. Not a priority feature / skip for now
- [ ] F. Other: **\*\***\_\_\_**\*\***

**Your Decision:**

---

## Agent Consensus (What They Agree On)

### Universal Agreement (All 4 Agents)

- Fix persistence bug FIRST (Priority 0 - non-negotiable)
- Keep template system - extend don't replace
- Preserve thread-safe ship spawning (`shuttle_loading` mutex)
- Build TGUI catalog interface with image previews
- Shift from consumable to permanent unlock model
- Ship-centric design philosophy (not station-centric)

### Proposed Phasing (Agent A's proposal, others support)

- **Phase 0:** Fix persistence bug
- **Phase 1:** TGUI catalog with ship previews
- **Phase 2:** Unlock system with currency
- **Phase 3:** Crew customization (complex, can defer)

---

## Agent Disagreements (Need Resolution)

### Parts vs Currency (2-2 Split)

- **Agents A & B:** Keep both for player choice
- **Agents C & D:** Deprecate parts, unify to currency
- **Resolution:** See Question 2 above

### Faction Restrictions

- **Current:** 3 separate faction currencies (NEU/NT-C/SYN-C parts)
- **Feature Request:** Doesn't emphasize factions
- **Agent A's Compromise:** Unified currency + faction unlock trees (economic simplicity, game balance preserved)
- **Agent C:** Changed position to support Agent A's compromise
- **Likely Consensus:** One currency, faction-separated unlock trees

---

## Critical Bug Details (For Your Awareness)

**Agent B Discovery:** `ships_owned` is saved to player preferences but **never loaded back**. The progression system has never functioned as designed - parts reset to 0 on every server restart.

**Fix:** Add missing load line to `load_preferences()` + migration logic for existing savefiles

**Impact:** Must be fixed before ANY new feature work

---

## How to Provide Your Answers

### Option 1: Answer Inline Above

Fill in the checkboxes and "Your Decision" fields in Questions 1-5

### Option 2: Answer Here

**Q1 (Currency Earning):**

**Q2 (Parts System):**

**Q3 (Spawn Limits):**

**Q4 (Antagonist Ships):**

**Q5 (Ship Skins):**

### Option 3: Ask Me Questions

If you're unsure about any decision, you can:

- Ask for clarification on tradeoffs
- Request agent rationale for their positions
- Ask for more context about current systems
- Request simplification of scope

---

## Next Steps After Your Input

1. Update `agent-consensus-discussion.md` with your decisions
2. Agents proceed to Round 3 (architectural proposals)
3. Agents incorporate your constraints into their designs
4. Round 4: Final consensus and implementation plan
5. Begin Phase 0 (fix persistence bug)

---

## Questions for Me?

You can ask me to:

- [ ] Explain any agent's reasoning in more detail
- [ ] Clarify technical tradeoffs for any decision
- [ ] Simplify or expand any of the options
- [ ] Read specific sections from agent analyses
- [ ] Create visualizations/diagrams of proposed architectures
- [ ] Estimate complexity/time for different options
- [ ] Anything else?

**Your questions:**
