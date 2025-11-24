# Ship Purchase System - Design Decisions Needed

**Purpose**: Resolve critical design questions before finalizing Round 4 architectural consensus.

**Instructions**: Check boxes for your preferred options and add notes/clarifications as needed.

---

## 1. Currency Earning System (HIGHEST PRIORITY)

**Question**: How should players earn the new ship currency?

### Options:

- [ ] **A) Round Completion Rewards (Simple)**
  - Flat rate per round (e.g., 100 credits per round)
  - Easy to implement, predictable
  - May feel grindy without variety

- [ ] **B) Performance-Based Rewards**
  - Based on objectives completed, survival time, crew goals
  - More engaging, rewards skilled play
  - Harder to balance, more complex

- [ ] **C) In-Game Activity Rewards**
  - Earn currency during round (mining, trading, combat)
  - Most engaging, rewards active play
  - Most complex implementation

- [ ] **D) Hybrid System (Recommended)**
  - Base reward per round (e.g., 100 credits)
  - Plus performance bonuses (e.g., +50 for objectives)
  - Best of both worlds
  - Moderate complexity

- [ ] **E) Other** (describe below)

**Your Choice**: ______

**Additional Notes/Requirements**:
```


```

**Agent D Recommendation**: Start with Option A (simple round completion) in Phase 2, add performance bonuses in Phase 3. This gets the system working quickly while allowing complexity later.

---

## 2. Antagonist Ships Definition

**Question**: The feature request mentions "antagonist ships" - what does this mean?

### Options:

- [ ] **A) Antag Role-Exclusive Ships**
  - Only unlockable/spawnable by antagonist roles (traitor, nukie, etc.)
  - Requires role validation in unlock system
  - Special ships with antag-specific features

- [ ] **B) Temporary Per-Round Antag Ships**
  - Not permanent unlocks
  - Granted to antags at round start or via objectives
  - Separate from player progression system

- [ ] **C) Ships with Special Antag Equipment**
  - Regular ships but with antag-only equipment/features
  - Unlockable by anyone but optimized for antag gameplay
  - Minimal special architecture needed

- [ ] **D) Just Syndicate Faction Ships**
  - Already exists (SYN-C ships in current system)
  - No new implementation needed
  - May need rebalancing

- [ ] **E) Other** (describe below)

**Your Choice**: ______

**Additional Notes/Requirements**:
```


```

**Agent D Recommendation**: Clarify scope before Phase 2. If complex (Option A/B), defer to Phase 4. If simple (Option C/D), can include in Phase 2.

---

## 3. Ship Skins Implementation Scope

**Question**: How complex should ship skins be?

### Options:

- [ ] **A) Palette Swaps Only**
  - Recolor existing sprites (easy)
  - ~1 week implementation
  - Limited visual variety

- [ ] **B) Cosmetic Overlays**
  - Apply visual effects to existing ships (medium)
  - ~2-3 weeks implementation
  - More visual variety without new maps

- [ ] **C) Full Map Variants**
  - Separate .dmm files per skin (hard)
  - ~4-6 weeks implementation
  - Maximum visual variety, high maintenance

- [ ] **D) Modular Attachments**
  - Structural ship changes (very hard)
  - ~6+ weeks implementation
  - Changes gameplay, not just cosmetics

- [ ] **E) Defer Entirely to Phase 4+** (Recommended)
  - Focus on core unlock system first
  - Add skins after player feedback
  - Avoid scope creep

**Your Choice**: ______

**Additional Notes/Requirements**:
```


```

**Agent D Recommendation**: Option E - defer ship skins entirely. Get core unlock system working, gather player feedback, then decide skin complexity.

---

## 4. Per-Round Ship Respawn Rules

**Question**: If a player's unlocked ship is destroyed mid-round, can they spawn it again?

### Options:

- [ ] **A) Once Per Round Absolute** (Recommended)
  - Destroyed = cannot re-spawn that ship this round
  - Simplest implementation
  - May frustrate players but encourages ship survival

- [ ] **B) Re-spawn with Cooldown**
  - Can re-spawn after X minutes (e.g., 30 min cooldown)
  - Moderate complexity (cooldown tracking)
  - Balances accessibility with consequence

- [ ] **C) Re-spawn with Currency Cost**
  - Pay ship credits to re-spawn destroyed ship
  - Creates currency sink (good for economy)
  - May feel punishing

- [ ] **D) Unlimited Re-spawns**
  - Unlocked ships can spawn infinitely
  - Simplest for players
  - May trivialize ship ownership/loss

- [ ] **E) Tier-Based Rules**
  - Starter ships: unlimited re-spawns
  - Elite ships: once per round
  - Complex but nuanced balance

**Your Choice**: ______

**Additional Notes/Requirements**:
```


```

**Agent D Recommendation**: Option A for Phase 2 (simplest), gather player feedback during testing, adjust in Phase 3 if needed.

---

## 5. Faction Restrictions in New System

**Question**: Should the new currency system maintain faction restrictions on ship unlocks?

**Current System**: Three isolated economies (NEU parts only buy NEU ships, NT-C parts only buy NT-C ships, SYN-C parts only buy SYN-C ships)

### Options:

- [ ] **A) Unified Currency, No Restrictions**
  - One currency type, all ships unlockable by anyone
  - Simplest implementation and UX
  - Loses faction flavor/progression paths

- [ ] **B) Unified Currency + Faction Requirements**
  - One currency, but ships require faction alignment
  - Must be NT-aligned to unlock NT ships, etc.
  - Moderate complexity (faction tracking)

- [ ] **C) Three Separate Currencies** (Current System)
  - Maintain NEU/NT-C/SYN-C currency split
  - Most complex UI and economy
  - Preserves current faction isolation

- [ ] **D) Unified Currency + Faction-Themed Trees** (Recommended)
  - One currency type
  - Catalog organizes ships into faction "trees" for visual progression
  - No hard restrictions, just suggested paths
  - Best balance of simplicity and design flavor

**Your Choice**: ______

**Additional Notes/Requirements**:
```


```

**Agent D Recommendation**: Option D - unified currency for economic simplicity, faction-themed catalog organization for design flavor. Players can unlock any ship but trees suggest "paths."

---

## 6. Legacy Parts System Handling

**Question**: What happens to the existing ship parts system?

**Context**: All agents agree persistence bug must be fixed. Question is what role parts play in the NEW system.

### Options:

- [ ] **A) Keep Parts Parallel with Currency**
  - Both parts AND currency can unlock ships
  - Players choose which progression path to use
  - Preserves existing system but increases complexity
  - Agents A + B favor this

- [ ] **B) Deprecate Parts for Unlocks, Keep for Trading**
  - New unlocks ONLY use currency (no parts option)
  - Existing parts convert to currency at fixed rate
  - Physical trading via 'N' key preserved (parts become tradeable currency tokens)
  - Single progression path, preserves trading economy
  - Agents C + D favor this

- [ ] **C) Fully Replace Parts System**
  - Remove parts entirely, currency only
  - No conversion, no physical trading
  - Simplest but loses player trading economy
  - No agents recommended this

- [ ] **D) Other** (describe below)

**Your Choice**: ______

**Conversion Rate** (if Option B chosen):
- 1 NEU part = ______ ship credits
- 1 NT-C part = ______ ship credits
- 1 SYN-C part = ______ ship credits

**Additional Notes/Requirements**:
```


```

**Agent D Position**: Option B - deprecate for unlocks, preserve trading economy. Clean migration path without losing social gameplay.

---

## 7. Ship Preview Image Generation (Lower Priority)

**Question**: Who creates the ship preview images for the TGUI catalog?

### Options:

- [ ] **A) Manual Screenshots by Developers**
  - Dev team screenshots each ship in Dream Maker
  - High quality, full control
  - Time-intensive (30+ ships)

- [ ] **B) Automated Screenshot Tool**
  - Script to generate previews from .dmm files
  - Automatic updates when maps change
  - Complex to implement

- [ ] **C) Community Submissions**
  - Players/contributors submit ship previews
  - Distributed workload
  - Quality variation

- [ ] **D) Placeholder Images Initially**
  - Use generic placeholders for Phase 1
  - Replace with real previews later
  - Fastest to implement

**Your Choice**: ______

**Standard Image Size**: ______ x ______ pixels

**Additional Notes/Requirements**:
```


```

---

## 8. Database vs JSON Savefile (Clarification)

**Question**: You mentioned database earlier - do you want to migrate preferences to database storage?

### Options:

- [ ] **A) Keep JSON Savefiles** (Current System)
  - Already works (after bug fix)
  - No migration needed
  - File-based, no DB dependency

- [ ] **B) Migrate to Database Storage**
  - Use SSdbcore (already exists in codebase)
  - Centralized, easier to query
  - Requires migration, adds DB dependency

- [ ] **C) Hybrid** (Database for currency, JSON for preferences)

**Your Choice**: ______

**Additional Notes/Requirements**:
```


```

**Agent D Note**: Current analysis assumes JSON savefiles (all 4 agents analyzed this). If you want database migration, that's additional Phase 0 work before catalog/unlocks.

---

## 9. Implementation Timeline Expectations

**Question**: What's your expected timeline for each phase?

**Agent D Proposed Timeline**:
- Phase 0 (Bug Fix): 1-2 days
- Phase 1 (TGUI Catalog): 2-3 weeks
- Phase 2 (Unlock System): 3-4 weeks
- Phase 3 (Crew Customization): 4-6 weeks (deferred)

**Your Timeline Expectations**:
- Phase 0: ____________
- Phase 1: ____________
- Phase 2: ____________
- Phase 3: ____________

**Additional Notes/Constraints**:
```


```

---

## 10. Open Questions / Additional Requirements

**Any other requirements or constraints not covered above?**

```







```

---

## Summary Checklist

Once you've filled out the above, please confirm:

- [ ] Currency earning system decided (Question 1)
- [ ] Antagonist ships scope clarified (Question 2)
- [ ] Ship skins scope decided (Question 3)
- [ ] Per-round respawn rules decided (Question 4)
- [ ] Faction restrictions philosophy decided (Question 5)
- [ ] Parts system migration path decided (Question 6)
- [ ] Ship preview generation approach decided (Question 7)
- [ ] Database vs savefile confirmed (Question 8)
- [ ] Timeline expectations aligned (Question 9)

**Once complete, Agent D can finalize Round 4 consensus with concrete implementation decisions.**

---

**Date**: 2025-11-23
**Agent**: D
**Status**: Awaiting User Design Decisions
