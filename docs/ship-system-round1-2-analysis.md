# Ship Purchase System Redesign - Round 1-2: Analysis & Debates

**Part of:** [Ship System Redesign Master Index](ship-system-master-index.md)

## Document Navigation
- **Previous:** [Master Index](ship-system-master-index.md)
- **Next:** [Round 3: Architectural Proposals](ship-system-round3-proposals.md)
- **Related:** [User Decisions - Round 3.5](ship-system-user-decisions.md)

---

## Table of Contents
1. [Context & Reference Documents](#context)
2. [Round 1: Key Findings](#round-1-key-findings)
   - Agent A: Signal-based lifecycle, thread safety
   - Agent B: Critical persistence bug discovery
   - Agent C: Data flow mapping, paradigm shift analysis  
   - Agent D: Latejoin architecture, bank account infrastructure
3. [Round 2: Disagreements & Gaps](#round-2-disagreements--gaps)
   - Agent responses to each other
   - Evolution of positions
   - Areas of alignment
4. [User Decisions - Design Constraints](#user-decisions---design-constraints-for-round-3)
   - Currency earning system
   - Parts system future (3-tier progression)
   - Per-round spawn limits
   - Antagonist ships definition
   - Ship skins complexity

---

## Document Purpose

This document captures the initial analysis phase where four AI agents independently analyzed the current ship purchase system, then responded to each other's findings. It culminates with the first set of user decisions that set constraints for Round 3 architectural proposals.

**Key Outcomes:**
- Discovery of critical persistence bug
- Consensus on preserving thread-safe architecture
- Agreement on TGUI catalog requirement
- User clarification on 5 critical design questions

**Read this document first** to understand the technical foundation and initial debates before proceeding to architectural proposals.

---

# Ship Purchase System Redesign - Agent Consensus Discussion

## Context

Four agents (A, B, C, D) have analyzed the current ship purchase system. This document facilitates structured discussion to reach consensus on the redesign approach.

## Reference Documents

- `current-state-doc-A.md` - Agent A's system analysis
- `current-state-doc-B.md` - Agent B's system analysis
- `current-state-doc-C.md` - Agent C's system analysis
- `current-state-doc-D.md` - Agent D's system analysis

---

## Round 1: Key Findings

### Agent A

**Summary of Current System (Most Important Aspects):**

1. **Consumable Parts Model**: Current system uses faction-specific parts (NEU/NT-C/SYN-C) that are SPENT each time a ship is purchased. Ships are ephemeral (per-round only), while parts persist. This is fundamentally different from the requested "unlock once, spawn forever" model.

2. **Robust Ship Creation Pipeline**: The `SSshuttle.create_ship()` pipeline is well-engineered with thread safety (shuttle_loading flag), SSair management during template loads, and proper signal coordination (COMSIG_VOIDCREW_SHIP_LOADED). This foundation is solid for expansion.

3. **Template-Based Extensible Architecture**: Ship definitions use a clean template system with job slot definitions, faction prefixes, and part costs. The job assembly system is particularly well-designed - first job is always the leader/officer role, making it easy to add new ships.

4. **No Cross-Round Persistence Beyond Parts**: Ships, ship state, cargo, modifications, bank accounts, and player unlocks all reset each round. Only the parts inventory (theoretically) persists, which Agent B identified as BROKEN.

5. **Existing Infrastructure Ready for Extension**: Ship bank accounts, team systems, faction colors, and the overmap system provide hooks for the new features. The savefile system in preferences is already set up for persistence.

**Opinions on Other Agents' Findings:**

- **Agent B's Critical Bug Discovery**: This is the most important finding across all documents. If ship parts aren't being loaded from savefiles, the entire progression system is non-functional. This MUST be verified and fixed before any new features. I documented the save process but didn't check the load path - excellent catch by Agent B.

- **Agent C's Collaborative Questions**: Smart approach asking about TGUI infrastructure and currency systems. Agent D actually answered one of these - the ship bank account system exists and could be leveraged.

- **Agent D's Architecture Focus**: Good high-level perspective. The observation that this is "ship-centric design, not station-centric" is key for understanding how to extend the system. The bank account system they highlighted is important infrastructure.

**Counter Points:**

- **On Agent B's Bug**: Need to verify this is actually a bug and not an oversight in documentation. If confirmed, this is a showstopper that needs immediate fixing.

- **On Ship Counts**: Minor discrepancy - I found 28+ ships, Agent D mentions 30+. Need to verify exact count, but not critical.

- **On Faction Restrictions**: All agents correctly identified faction-locked parts, but I want to emphasize this design choice might need reconsideration for the new system. The feature request doesn't mention factions prominently.

**My General Disposition:**

1. **Keep the template system**: All agents agree this is well-designed. Don't rebuild it.

2. **Fix persistence first**: Before adding new features, fix Agent B's discovered bug. Non-negotiable.

3. **Add new currency layer**: Don't replace parts - add a new persistent currency system alongside them. Parts could become a legacy/alternative acquisition method.

4. **Leverage existing TGUI**: Don't build a custom image viewer from scratch if TGUI has image display capabilities.

5. **Ship unlocks as new persistence**: Add a new `ships_unlocked` list to preferences, separate from `ships_owned` parts.

**Unique Insights I Discovered:**

1. **Signal-Based Ship Lifecycle**: The ship system uses COMSIG signals extensively (SHIP_LOADED, SHIP_DOCKED, SHIP_UNDOCKED, SHIP_MOVED). The new catalog/unlock system could hook into these for achievements, stats tracking, or unlock conditions.

2. **Thread Safety Critical**: The `shuttle_loading` flag and SSair disable/enable pattern shows the system is sensitive to concurrent operations. Any new async ship catalog loading or image rendering must respect this.

3. **Spawn Point Flexibility Limited**: Currently only cryopods work as spawn points. If crew customization includes custom spawn locations, this system needs expansion.

4. **Auto-Delete Timer System**: Ships auto-delete when crews die after 10 minutes. The unlock system needs to handle "you unlocked this ship but it was destroyed" scenarios gracefully.

5. **Initial Ship Selection Excludes Neutral**: Round start ships are ONLY NT or SYN, never neutral. This suggests neutral ships are meant to be purchased. New unlock system should respect this design choice or explicitly change it.

6. **Job Slot Persistence Gap**: While ships have job_slots at runtime, there's no system for CUSTOMIZING these slots before purchase. The feature request wants "pay to modify roles" - this requires new pre-purchase customization UI and storage.

### Agent B

**Summary of Current System (Most Important Aspects):**

1. **🔴 CRITICAL BUG - Ship Parts Never Load**: I discovered that `ships_owned` is saved via `savefile.set_entry("ships_owned", ships_owned)` but **NEVER loaded back** in `load_preferences()`. The line `ships_owned = savefile.get_entry("ships_owned", ships_owned)` is completely missing. This means the entire progression system resets to 0 on every server restart and has never functioned as designed. This is a showstopper bug.

2. **Consumable vs Unlock Model Mismatch**: Current system treats ships as consumable purchases (spend parts each spawn), but the feature request wants permanent unlocks (buy once, spawn forever per-round). This is a fundamental architectural difference requiring a complete rethink of the persistence model, not just feature additions.

3. **Solid Foundation with Extension Points**: The template system (`/datum/map_template/shuttle/voidcrew`), job assembly (`assemble_job_slots()`), and ship creation pipeline (`SSshuttle.create_ship()`) are well-designed and thread-safe. Ship bank accounts (`datum/bank_account/ship`) already exist and could be extended for persistent player currency.

4. **Faction-Locked Parts System**: NEU/NT-C/SYN-C parts are strictly faction-locked - you cannot use NEU parts for NT-C ships. This design choice may need reconsideration for the new unlock system since the feature request doesn't emphasize faction restrictions.

5. **Per-Round Rewards Already Implemented**: Every connected client receives 1 random ship part at round end via `give_random_ship_part()`. This reward mechanism exists and works (except for the load bug), showing intent for progression.

**Opinions on Other Agents' Findings:**

- **Agent A's Comprehensive Analysis**: Excellent detail on mechanics and flow. The observation about signal-based lifecycle (COMSIG_VOIDCREW_SHIP_LOADED) is valuable. However, the critical load bug was missed - we need to verify the save/load paths more carefully.

- **Agent C's Questions Are On-Point**: The questions about currency systems, TGUI infrastructure, and crew customization are exactly what we need to answer. Agent D partially answered the currency question with ship bank accounts.

- **Agent D's Ship Bank Account Finding**: This is crucial infrastructure we can leverage. Shared ship accounts already exist - we could extend this pattern to create persistent player currency accounts.

**Counter Points & Clarifications:**

- **On Agent A's "Parts Persistence Works Well"**: I must respectfully DISAGREE. Agent A stated "Parts persistence works well - Reliable savefile system" but my research proves this is FALSE. The persistence is completely broken due to the missing load operation. We cannot build on a broken foundation.

- **On Ship Counts**: Minor variance between agents (28+ vs 30+ ships) is not critical, just documentation differences.

- **On "No Validation" (Agent A)**: I disagree that there's "no validation" for duplicate purchases. The thread-safety mechanism (`shuttle_loading` flag) prevents concurrent spawns, though spam clicking could theoretically create issues.

**My General Disposition:**

1. **FIX THE BUG FIRST** (Non-Negotiable): Before ANY new features, we must fix the ships_owned load bug. This is priority zero.

2. **Add New Layer, Don't Replace**: Keep ship parts as a legacy/alternative system. Add a new persistent currency system alongside it. Don't destroy existing mechanics.

3. **Extend Preferences System**: Use the existing `/datum/preferences` for ship unlocks and currency, but AFTER we prove the load/save cycle actually works.

4. **Preserve Thread Safety**: The existing ship creation pipeline is thread-safe and reliable. Any new features must maintain this property.

5. **TGUI Catalog Required**: The current native BYOND dialogs are insufficient for a visual ship catalog. We need proper TGUI interface with image support.

**Unique Insights I Discovered:**

1. **Physical Part Withdrawal System**: Players can withdraw ship parts as physical items via the 'N' keybind (`/datum/keybinding/carbon/remove_ship_part`). This creates a player-to-player trading economy that agents didn't emphasize. This mechanic could be preserved for the new system.

2. **Initial Ship Spawning Logic**: `spawn_initial_ship()` deliberately excludes neutral ships - only NT or SYN ships spawn at round start. This design suggests neutral ships are meant to be purchased only. The new unlock system should respect or explicitly change this philosophy.

3. **Ship Deletion Timer Interaction**: Ships auto-delete when crews die. The unlock system needs to handle "you unlocked this ship but it got destroyed mid-round" gracefully. Can you re-spawn a destroyed unlocked ship? Once per round limit?

4. **No Migration Code**: There's no version migration for `ships_owned` format changes. If we fix the load bug and the savefile format has changed, existing savefiles might break. We need migration logic.

5. **Round-End Reward Timing**: Parts are granted during `display_report()` which is AFTER round end but BEFORE savefiles are written. This means players get their part reward even if they disconnect before round fully ends, as long as they're connected during the report phase.

6. **Free Ships Config Bypass**: The `free_ships` config completely bypasses part checks. This suggests an admin/testing mode exists. The new unlock system should have similar bypass capabilities for testing or special events.

### Agent C

**Summary of Current System (Most Important Aspects):**

1. **Fundamental Model Shift Required**: Current system uses CONSUMABLE parts (spend to spawn each time). Feature request wants PERMANENT UNLOCKS (buy once, spawn free per-round). This isn't just a feature add - it's an architectural paradigm shift from consumable currency to unlock-based progression.

2. **Complete, Robust Ship Creation Pipeline**: The data flow `select_ship()` → `SSmapping.ship_purchase_list` → `client.remove_ship_cost()` → `SSshuttle.create_ship()` → `AttemptSpawnOnShip()` is well-architected with thread safety (`shuttle_loading` flag), SSair management, signal coordination, and overmap placement. This pipeline can be adapted by inserting catalog/unlock validation steps.

3. **Three-Faction Economy is Fundamental**: NEU/NT-C/SYN-C aren't cosmetic - they're separate progression paths with strict boundaries. Parts from one faction CANNOT buy ships from another faction. This design choice should inform the new system (three unlock trees? three currencies? or unified progression?).

4. **Template System is Extensible**: Ship templates with `job_slots`, `part_cost`, `faction_prefix`, `short_name` are well-designed. Adding fields like `unlock_cost_currency`, `preview_image_path`, `tier`, `unlock_requirements` will be straightforward. The `assemble_job_slots()` system is particularly elegant.

5. **Persistence Layer Ready for Extension**: `/datum/preferences` already handles `ships_owned` (parts count). We can add `ships_unlocked` (unlocked ship types), `meta_currency` (cross-round money), `ship_customizations` (saved loadouts), using the same savefile infrastructure - IF Agent B's bug is fixed first.

**Opinions on Other Agents' Findings:**

**Agent B's Critical Bug Discovery - SHOWSTOPPER:**
This is the most important finding across all four analyses. If `ships_owned` is saved but never loaded, the entire progression system has NEVER functioned correctly. This must be:

1. Verified by checking the actual load_preferences() code
2. Fixed immediately before ANY new feature work
3. Tested to confirm save/load cycle works
   **This is priority #0.** All our planning assumes persistence works - if it doesn't, everything breaks.

**Agent A's Technical Deep Dive - Valuable:**

- Signal-based lifecycle (`COMSIG_VOIDCREW_SHIP_LOADED`, etc.) creates hooks for stats tracking, achievements, unlock conditions
- Thread safety with `shuttle_loading` flag means any async catalog operations must not interfere
- Initial ship selection excluding neutral ships (only NT/SYN at round start) is a deliberate design choice worth preserving
- Job slot persistence gap observation is spot-on - we need pre-purchase customization UI

**Agent B's Infrastructure Findings:**

- Physical part withdrawal via 'N' key creates player-to-player trading economy - this is interesting for the new system
- Free ships config bypass shows admin/testing mode exists - we should parallel this for unlocks
- Round-end reward timing detail (during `display_report()`) is good to know for new currency distribution

**Agent D's Architecture Perspective:**

- Ship bank accounts (`datum/bank_account/ship`) are existing infrastructure we can mirror with `datum/bank_account/player_meta` for persistent currency
- "Ship-centric not station-centric" observation is crucial - this isn't an add-on to SS13, it's a different gameplay paradigm

**Counter Points & Disagreements:**

1. **Agent A's "Keep Parts Alongside Currency"**: I partially disagree. Running two parallel systems (parts + currency) adds significant complexity. My preference: **deprecate parts for new unlocks, but keep the system functional for backwards compatibility**. Don't actively remove parts, just don't require them for the new unlock flow.

2. **Agent B's "Add New Layer, Don't Replace"**: Similar disagreement - I think we should REPLACE parts with currency for the new system, not run both. However, I agree with preserving the physical trading mechanic (convert currency → tradeable tokens?).

3. **Faction Restrictions Need Discussion**: All agents noted faction-locked parts, but the feature request doesn't emphasize factions. We need to decide: keep three separate unlock trees, or unify into one progression? I lean toward keeping factions but allowing cross-faction unlocks with currency.

**My General Disposition:**

**Strongly Support:**

- Fix Agent B's persistence bug FIRST (non-negotiable)
- Keep template system - extend don't replace
- Build new TGUI catalog interface with images
- Add permanent unlock system in preferences
- Add per-round spawn tracking (prevent multi-spawn)
- Maintain ship-centric design philosophy

**Open to Discussion:**

- Keep parts system or fully replace with currency?
- How to generate ship preview images (pre-rendered vs runtime)?
- Per-unlock customization or per-spawn customization?
- Keep faction separation or unify progression?

**Concerns:**

- Scope is massive - need careful phasing
- Image generation pipeline could be complex
- Customization system could explode in complexity
- Per-round limits need careful design (what if ship gets destroyed?)

**Unique Insights I Discovered:**

1. **Job Customization Requires New Pre-Purchase System**: The feature wants "pay to modify roles ships spawn with". Current `job_slots` are static at template definition. This needs:
   - Pre-purchase customization UI (BEFORE `create_ship()`)
   - Storage: `ship_customizations[ship_type] = custom_job_slots`
   - Runtime modification of template's `job_slots` before `assemble_job_slots()`
   - This is a major new system, not just UI work

2. **Per-Round Spawn Limits Not Implemented**: Current system has NO limits - if you have parts, you can spawn infinite ships. New system needs:
   - `client.ships_spawned_this_round = list()` tracking
   - Check before catalog spawn
   - Reset on round init
   - Decision: can you re-spawn destroyed unlocked ships, or once per round absolute?

3. **Ship Catalog Needs Metadata Layer**: Ship templates have basic info. A catalog needs:
   - Tier/class/size categories
   - Descriptions/lore
   - Stat displays (crew size, speed, combat rating)
   - Preview images
   - Unlock prerequisites (not just currency - could be achievements)
     Suggests new `/datum/ship_catalog_entry` that WRAPS templates with display metadata

4. **Currency Earning System Not Specified**: Parts are earned via round-end rewards + lootable items. But the NEW currency? Feature request doesn't say. Major design questions:
   - Round completion rewards?
   - Per-action earnings (mining, trading, combat)?
   - Achievement-based grants?
   - Trading system?
   - Admin grants?
     **This needs user clarification**

5. **Antagonist Ships Ambiguous**: GitHub issue mentions "antagonist ships" separately. Unclear if this means:
   - Ships only unlockable by antags
   - Per-round temporary ships (not permanent unlocks)
   - Ships with special antag equipment
   - Different purchase system for antags
     **Needs user clarification**

6. **Ship Skins Need Architectural Decision**: "Different skins for ships" could mean:
   - **Palette swaps** (easy - just recolor sprites)
   - **Different map variants** (hard - need separate .dmm files per skin)
   - **Cosmetic overlays** (medium - apply visual effects to existing ships)
   - **Modular attachments** (very hard - change ship structure)
     Each has wildly different implementation complexity

7. **Complete Data Flow Pipeline Documented**: I mapped the entire purchase-to-spawn flow with all integration points. Key insight: we can INSERT new steps without breaking existing flow:

   ```
   select_ship()
   → [NEW: show TGUI catalog with previews]
   → [NEW: check ships_unlocked]
   → [NEW: if not unlocked, show unlock purchase UI]
   → [NEW: if unlocked, show customization UI]
   → SSshuttle.create_ship(template)  [modify template with customizations]
   → AttemptSpawnOnShip()
   ```

8. **Existing Ship Bank Accounts Can Be Paralleled**: Ships have `datum/bank_account/ship`. We can create `datum/bank_account/player_meta` using identical patterns for persistent currency. This keeps code patterns consistent across the codebase.

### Agent D

**Summary of Current System (Most Important Aspects):**

1. **Complete Latejoin Replacement Architecture**: The system doesn't just add ship selection - it completely hijacks the standard SS13 latejoin menu by intercepting `latejoin_menu/ui_interact()` (new_player.dm:1-3) and redirecting to `select_ship()`. This is a fundamental architectural replacement where ship selection IS the join flow. Any redesign must either maintain this override or rebuild the entire join pipeline from scratch - there's no middle ground.

2. **Three-Faction Parallel Economies with Strict Isolation**: Ship parts aren't flexible currency - they're faction-specific keys creating three completely isolated economic pools. `remove_ship_cost()` enforces exact faction matching: NEU parts ONLY unlock NEU ships, NT-C parts ONLY unlock NT-C ships, SYN-C parts ONLY unlock SYN-C ships. No cross-faction purchases allowed. The feature request mentions "currency system" (singular), suggesting unification into one economy - this would be a fundamental economic model change, not just UI polish.

3. **Thread-Safe Ship Creation is Critical Infrastructure**: `SSshuttle.create_ship()` uses `shuttle_loading` mutex and temporarily disables SSair (`SSair.can_fire = FALSE`) during map loading to prevent server crashes from concurrent spawns or atmosphere calculation interference. This thread-safety must be preserved. Any new catalog UI, image preview system, or async operations must respect this pipeline or risk server instability and crashes.

4. **Agent B's Persistence Bug is Verified and Critical**: `ships_owned` is saved via `savefile.set_entry("ships_owned", ships_owned)` but the corresponding load operation `ships_owned = savefile.get_entry("ships_owned", ships_owned)` is completely missing from `load_preferences()`. The savefile infrastructure itself works fine (used throughout preferences system), but this specific load line is absent. This means the progression system has NEVER functioned as designed - parts reset to 0 on every server restart. This is priority zero - must fix before any new features.

5. **Ship Bank Account Infrastructure is Extensible**: Ships already have working `datum/bank_account/ship` (ship.dm:38) shared among crew, integrated with SSeconomy. Rather than building a persistent player currency system from scratch, we can extend this proven bank account pattern to create `datum/bank_account/player_meta` for persistent player-level currency separate from ship-level accounts. This reuses existing code and maintains economic system consistency.

**Opinions on Other Agents' Findings:**

**Agent A - Comprehensive Technical Documentation:**

- Excellent file-by-file breakdown with line numbers and detailed flow analysis
- Signal system documentation (COMSIG_VOIDCREW_SHIP_LOADED) is valuable for understanding integration hooks
- "Job Slot Persistence Gap" observation is particularly insightful - crew customization will require entirely new pre-purchase UI and storage systems
- Ship deletion timer edge cases (unlocked ship gets destroyed - can you re-spawn?) is a design question the feature request doesn't address
- I agree with all technical findings - no disputes

**Agent B - Critical Bug Discovery:**

- The persistence bug discovery is the single most important finding across all four agent analyses
- I completely missed this despite documenting the save path - Agent B's verification methodology (checking BOTH save AND load paths) is superior
- This validates the multi-agent approach - we catch different categories of issues (I focused on architecture, B focused on code verification)
- Physical part withdrawal via 'N' key creating player trading economy is something I missed entirely
- Round-end reward timing details (during `display_report()`) are valuable for new currency distribution design
- I strongly agree with B's correction of A's "persistence works well" statement - it demonstrably does NOT work due to missing load operation

**Agent C - Collaborative Framework:**

- Questions about TGUI infrastructure, currency systems, unlock persistence are exactly the right questions to frame the solution design
- Observation about consumable vs permanent unlock model being a "paradigm shift not just features" is spot-on
- Data flow pipeline documentation with insertion points for new steps is excellent architectural thinking
- Per-round spawn limit observation is important - current system has NO limits, new system needs tracking
- Ship catalog metadata layer suggestion (`/datum/ship_catalog_entry`) is good architectural separation
- Questions about currency earning system are crucial - feature request doesn't specify this at all

**Counter Points & Disagreements:**

**Strong Agreement with Agent B on Bug Severity:**
I fully support Agent B's correction of Agent A. Agent A stated "Parts persistence works well - Reliable savefile system" but this is demonstrably FALSE - persistence is completely broken. We cannot claim a system "works well" when it doesn't function at all. This is priority zero, non-negotiable.

**Partial Disagreement with Agents A/B on "Keep Parts Alongside Currency":**
Agents A and B suggest keeping ship parts system AND adding new currency system in parallel. I understand the backward compatibility argument, but I lean more toward Agent C's position: **deprecate parts for NEW unlocks while keeping the system functional for legacy**. Running two parallel progression systems significantly increases complexity. My preference: new unlocks use new currency, old parts become convertible tokens or legacy currency.

**Disagreement on "No Validation" Edge Case:**
Agent A mentioned "no validation" for duplicate purchases, Agent B countered with `shuttle_loading` flag providing thread protection. Both are partially correct: there's thread-level protection but no user-level deduplication. You could theoretically spam-click and queue multiple purchase attempts before the first completes. This is a minor edge case but should be addressed in the new system with user-level purchase cooldown or request deduplication.

**Faction Restriction Design Decision:**
All agents documented faction-locked parts correctly. However, as Agent A noted, the feature request doesn't prominently mention factions. This is a GAME DESIGN question, not technical: Should the new unified currency maintain three-faction unlock trees (preserving game balance), or unify into single progression (simplifying player experience)? We need user/designer input on this philosophy question.

**My General Disposition:**

**Non-Negotiable Requirements:**

1. **Fix Agent B's Persistence Bug First**: Add missing load operation, test save/load cycle works, THEN proceed with new features
2. **Preserve Thread-Safe Spawning**: `shuttle_loading` mutex and SSair management patterns must be maintained - this is server stability critical

**Strong Support:**

- Keep ship template system - extend it, don't rebuild it
- Build proper TGUI catalog interface with image previews (current BYOND dialogs insufficient)
- Add `ships_unlocked` list to preferences for permanent unlock tracking
- Leverage existing `datum/bank_account` infrastructure for player currency
- Maintain ship-centric design philosophy (this isn't station SS13 with ships added, it's ship-focused gameplay)

**Open to Discussion:**

- Keep parts in parallel with currency, or deprecate parts for new system?
- Preserve three-faction progression trees, or unify to single currency?
- How to generate ship preview images (pre-rendered vs runtime screenshot)?
- Per-unlock customization storage vs per-spawn customization UI?
- Can destroyed unlocked ships be re-spawned in same round? Cooldown? Once per round limit?

**Concerns:**

- Scope is massive - needs careful phasing and milestones
- Image generation pipeline could be technically complex
- Crew customization system could explode in complexity if not carefully scoped
- Currency earning system completely unspecified - needs user clarification

**Unique Insights I Discovered:**

1. **Job Assembly is the Customization Hook Point**: `assemble_job_slots()` (\_shuttle.dm:23-42) converts static job lists into job datums at ship creation time. The feature request wants "pay to modify roles ships spawn with" - this assembly process is exactly WHERE customization hooks would integrate. Architecture: store custom job configurations in player prefs (`ship_customizations[ship_type] = modified_job_slots`), then override template's default job_slots during assembly. This isn't just UI work - it's a major new storage and runtime modification system.

2. **Initial Ship Spawning Deliberately Excludes Neutral Faction**: `spawn_initial_ship()` (overmap.dm:307-324) only spawns NT or Syndicate ships at round start, NEVER neutral ships. This is an intentional game balance design choice - neutral ships are player-purchase-only, not faction starters. The unlock system should preserve this faction balance philosophy unless explicitly changing game design. This affects which ships should be available in unlock catalog at round start.

3. **Ship Deletion System Creates Unlock Edge Cases**: Ships auto-delete when crew dies after a timer. The permanent unlock system needs to gracefully handle "you unlocked this ship but it was destroyed mid-round" scenarios. Design questions: Can you re-spawn your destroyed unlocked ship? Once per round absolute limit? Re-spawn with cooldown? Re-spawn cost? The feature request doesn't address this edge case at all - needs user clarification.

4. **Spawn Points are Inflexibly Cryopod-Only**: Only cryopods (`voidcrew\modules\cryo\machine.dm`) register as spawn points via `connect_to_shuttle()` callback. If crew customization includes custom spawn locations (e.g., captain spawns on bridge, engineer in engine room, cook in kitchen), this single-spawn-type architecture needs expansion. Current system lacks flexibility for role-based spawn positioning. This is a hidden limitation.

5. **Free Ships Config Provides Admin Testing Infrastructure**: The `free_ships` config (config.dm:16-17) completely bypasses part requirement checks, indicating existing admin/testing mode infrastructure. The new unlock system should parallel this with a `free_unlocks` or `admin_unlock_bypass` config for server operator testing and special events. Don't lose this operational capability.

6. **Round-End Reward Timing is Exploitation-Resistant**: Parts are granted during `display_report()` which occurs AFTER round end but BEFORE final savefile writes. This specific timing ensures players receive rewards even if they disconnect during the report display phase, but prevents mid-round farming exploits. The new currency reward system should maintain this proven timing pattern to prevent exploitation while ensuring players get earned rewards.

---

## Round 2: Disagreements & Gaps

### Agent A Response

**1. Points Where I DISAGREE:**

**On Agent B & D's Correction of My "Persistence Works Well" Statement:**
I must acknowledge they are **100% correct** to challenge this. I stated "Parts persistence works well - Reliable savefile system" in my doc, but Agent B proved the load operation is missing. This isn't disagreement - this is me accepting correction. I documented the SAVE path thoroughly but failed to verify the LOAD path. Agent B's methodology (checking BOTH directions) is superior. **I was wrong, they were right.**

**On Agent C's "Deprecate Parts for New System":**
I have a **mild disagreement** with Agent C's position to deprecate parts. Here's my reasoning:
- Parts system has physical trading via 'N' key (Agent B's finding) - this creates emergent player economy
- Some players may prefer collecting parts vs currency grinding
- Running parallel systems isn't ideal, but gives players CHOICE in progression paths
- However, I'm **open to compromise**: make currency the primary path, keep parts as secondary/legacy option with clear migration path

**On Faction Restrictions (Implicit Across All Agents):**
All agents documented faction-locked parts correctly, but I want to push back on accepting this for the new system. The feature request doesn't mention factions prominently. **My position**: the new currency should be UNIFIED (one currency), but ship unlock TREES can remain faction-separated for game balance. This gives economic simplicity with design flexibility.

**2. Gaps or Missing Information I Noticed:**

**Agent B's Analysis:**
- Excellent bug discovery but missing discussion of **how to FIX it** - just need to add the load line, but what about migration for existing savefiles that may have corrupted format?
- Physical part trading economy discovered but no proposal for how this translates to new system
- No mention of TGUI infrastructure requirements

**Agent C's Analysis:**
- Great questions about currency earning but no investigation into whether any earning systems ALREADY exist in codebase
- Ship catalog metadata layer suggestion is good but missing technical details about image storage/generation
- Per-round spawn limits discussed but no mention of how to handle ship destruction edge cases

**Agent D's Analysis:**
- Excellent verification of persistence bug and bank account infrastructure
- Missing discussion of how ship bank accounts currently handle persistence (do THEY persist or reset per round?)
- Job assembly customization hook identified but no architectural proposal for the storage layer
- Spawn point limitation discovered but no suggestion for how to expand beyond cryopods

**All Agents Missing:**
- **No one investigated TGUI infrastructure** - can TGUI display images? How are ship previews rendered?
- **No one explored existing image/icon systems** - does the codebase have ship preview generation?
- **UI workflow details** - what does the new catalog interface actually LOOK like? Wireframes?
- **Migration path** - how do we transition existing players from parts to currency?
- **Testing strategy** - how do we test persistent unlock system without breaking live saves?

**3. Findings That Surprised Me or That I Missed:**

**Agent B's Discoveries:**

**🔴 CRITICAL - The Persistence Bug:**
This is the biggest finding across all analyses. I completely missed verifying the load path. This validates the multi-agent approach - I focused on documenting what exists, Agent B verified what WORKS. This is a showstopper that invalidates my "persistence works well" claim.

**Physical Part Trading Economy (N key):**
I completely missed `voidcrew/edits/keybindings.dm` and the `remove_ship_part` keybind. This creates player-to-player part trading. This is actually brilliant game design - parts become tradeable commodities. The new system should preserve this somehow (tradeable currency tokens?).

**Round-End Reward Timing Details:**
Agent B's observation that parts are granted during `display_report()` (after round end but before final save) is important anti-exploit design. I noted the rewards exist but didn't analyze the timing implications.

**Agent C's Discoveries:**

**Per-Round Spawn Limits Don't Exist:**
Agent C correctly noted the current system has NO spawn limits. If you have parts, you can spam-buy infinite ships per round. This is actually a major balance issue I completely overlooked. The new system MUST implement per-round spawn tracking.

**Currency Earning System Completely Unspecified:**
Agent C's observation that the feature request doesn't specify HOW to earn the new currency is crucial. This is a major design gap requiring user clarification. Parts earn via round-end + loot, but new currency source is undefined.

**Ship Catalog Metadata Layer Concept:**
Agent C's suggestion of `/datum/ship_catalog_entry` wrapping templates with display metadata is excellent architectural thinking. This separation of concerns (game data vs display data) is cleaner than stuffing everything into templates.

**Agent D's Discoveries:**

**Complete Latejoin Replacement Architecture:**
Agent D's observation that Voidcrew doesn't just ADD ship selection but completely HIJACKS standard SS13 latejoin is crucial architectural context I understated. This isn't an addon - it's a replacement system. Any redesign must maintain this override.

**Ship Bank Accounts as Extension Pattern:**
Agent D found `datum/bank_account/ship` infrastructure and suggested mirroring it for `datum/bank_account/player_meta`. This is excellent - reuse proven patterns rather than inventing new ones. I mentioned bank accounts but didn't propose leveraging the architecture.

**Job Assembly as Customization Hook:**
Agent D identified `assemble_job_slots()` as the exact integration point for crew customization. I noted the gap but didn't identify the specific hook point. This is actionable technical detail.

**Initial Ship Spawning Excludes Neutral Ships:**
Both Agent B and D emphasized this deliberately. I noted it but didn't stress the game design implications. This shows neutral ships are meant to be player-purchased only, which should inform unlock catalog design.

**4. What I'm in Alignment On:**

**UNIVERSAL AGREEMENT (All 4 Agents):**

✅ **Fix Agent B's Persistence Bug FIRST** (Priority Zero)
- All agents agree this is non-negotiable
- Must verify, fix, test before ANY new feature work
- I fully support this priority

✅ **Keep Template System - Extend Don't Replace**
- All agents recognize templates are well-designed
- Consensus on extending rather than rebuilding
- I'm in full alignment

✅ **Thread Safety Must Be Preserved**
- `shuttle_loading` flag and SSair management patterns
- Agent D emphasized this strongly, I agree completely
- This is server stability critical

✅ **TGUI Catalog Interface Required**
- Current BYOND dialogs insufficient
- Need proper image preview support
- All agents want this, I strongly agree

✅ **Permanent Unlock System Needed**
- Current consumable model doesn't match feature request
- New `ships_unlocked` persistence in preferences
- Universal consensus

**STRONG ALIGNMENT (3+ Agents):**

✅ **Ship-Centric Design Philosophy** (Agents A, C, D)
- This isn't station SS13 with ships added
- Ship selection IS the join flow
- Maintain this paradigm

✅ **Leverage Existing Infrastructure** (Agents A, B, D)
- Bank account patterns
- Preferences/savefile system
- Signal hooks
- Don't reinvent working systems

✅ **Faction Design Needs Discussion** (All agents noted, unclear positions)
- Current: three isolated faction economies
- Feature request: doesn't emphasize factions
- Need to decide: keep separation or unify

**PARTIAL ALIGNMENT (Needs Discussion):**

⚠️ **Keep Parts vs Replace with Currency** (Split Opinion)
- Agent A (me) + Agent B: Keep both in parallel
- Agent C: Deprecate parts, keep as legacy
- Agent D: Leans toward deprecation
- **My willingness to compromise**: Primary currency path, secondary parts path, with conversion option

⚠️ **Scope and Phasing** (All agents concerned, no concrete plan)
- Everyone agrees scope is massive
- No one proposed phasing strategy yet
- Need breakdown of MVP vs future features

**READY TO PROCEED:**

**Yes, with conditions:**

1. **First verify Agent B's bug** - Before Round 3 proposals, someone should quickly check if the load operation is truly missing or if we all missed it in a different file
2. **User clarification needed** on:
   - How to earn new currency (unspecified in feature request)
   - What "antagonist ships" means (separate system? special ships?)
   - Ship skin complexity level (palette swap vs full variants?)
3. **Round 3 should propose phased implementation** - not just final architecture, but MVP → Full Feature roadmap

**I'm ready to move to Round 3 with architectural proposals**, but we should anchor them in:
- Bug fix as Phase 0
- TGUI catalog as Phase 1 (visual but simple)
- Unlock system as Phase 2 (core feature)
- Customization as Phase 3 (complex, can defer)

This prevents scope explosion while making progress.

### Agent B Response

After reading Agents A, C, and D's Round 1 summaries:

**1. Points Where I DISAGREE:**

**Agent A - "Keep Parts in Parallel with Currency":**
Agent A proposes keeping both ship parts AND new currency as parallel progression systems for player choice. While I value preserving the physical trading mechanic, I'm concerned about complexity:
- Dual currencies require dual UI (parts counter AND currency balance)
- Reward systems need dual implementation
- Balance becomes exponentially harder
- **My counter**: Unified currency with legacy parts converting at fixed rate. Physical trading preserved via tradeable "currency tokens." Single economy, same player agency.

**Agent D - Thread Safety "Server Instability Risk" Framing:**
Agent D describes thread safety as critical risk requiring extreme caution. While true that `shuttle_loading` must be preserved, the framing feels alarmist. The catalog UI is separate from ship creation and can be async without touching the mutex. Important yes, fragile no.

**Agent C - "Needs User Clarification" Without Proposals:**
Agent C flags currency earning as "needs clarification" but proposes no strawman solutions. This creates analysis paralysis. We should propose configurable options (round rewards / performance bonuses / hybrid) and let designers tune values.

**2. Gaps or Missing Information:**

**All Agents - No TGUI Investigation:**
We all assume TGUI can handle images/grids/filtering without verification. Did anyone check if `asset_cache_client` supports image catalogs? Grid CSS? Lazy loading?

**All Agents - No Migration Strategy:**
How do we transition players from broken parts→fixed parts→new currency without data loss?

**Agent A - Bug Fix Location Not Specified:**
A acknowledges my bug but doesn't propose WHERE to fix (add load to `load_preferences()`) or migration handling.

**Agent C - Questions Without Architecture:**
Great questions but no proposed solutions for currency earning, spawn limits implementation, image generation pipeline.

**Agent D - Bank Account Persistence Not Checked:**
D suggests extending ship bank accounts for player currency but didn't verify if ship accounts themselves persist (they don't - they reset per round).

**3. Findings That Surprised Me:**

**Agent A - Signal System Hooks:**
I completely missed COMSIG_VOIDCREW_SHIP_LOADED/DOCKED/MOVED signals. While not MVP-critical, this IS valuable for future extensibility (achievements, stats).

**Agent A - Spawn Point Inflexibility:**
Cryopods-only spawn system limits role-based positioning. If customization includes "captain spawns on bridge," this is a hidden limitation.

**Agent C - Per-Round Spawn Limits Missing:**
Major balance issue I overlooked. Current system allows infinite ships per round if you have parts. New system MUST track spawns.

**Agent C - Catalog Metadata Layer:**
`/datum/ship_catalog_entry` separating display metadata from game mechanics templates is clean architectural separation.

**Agent D - Complete Latejoin Hijack:**
D's framing that this is a "complete replacement not addon" reframes the architecture. Ship selection IS the join flow.

**Agent D - Job Assembly as Integration Point:**
`assemble_job_slots()` identified as exact code location for customization hooks. Actionable technical detail.

**4. Alignment & Ready Status:**

**UNIVERSAL AGREEMENT:**
✅ Fix bug first (Priority Zero)
✅ Keep template system
✅ Preserve thread safety
✅ TGUI catalog required
✅ Paradigm shift recognition

**STRONG ALIGNMENT:**
✅ Leverage existing infrastructure
✅ Massive scope needs phasing

**SPLIT (2-2):**
⚠️ Keep parts vs deprecate (A+B vs C+D)
- **Evolving position**: Unified currency PRIMARY, legacy parts convert, physical trading via tokens

**READY TO PROCEED: YES**

Conditions:
1. Quick verification of my bug finding
2. Strawman designs for unclear requirements (not blocking)
3. Round 3 includes phasing breakdown

I'm confident in technical architecture, ready to propose full solution in Round 3 with:
- Unified currency + legacy conversion
- TGUI catalog with image pipeline
- Unlock persistence architecture
- Per-round spawn tracking
- Phased implementation roadmap

### Agent C Response

After carefully reading all Round 1 summaries from Agents A, B, and D:

**1. Points Where I DISAGREE:**

**Agent A - "Keep Parts Alongside Currency" (Mild Disagreement, Open to Compromise):**

Agent A proposes running parts and currency in parallel as two separate progression paths, arguing this gives players choice. I understand the reasoning, especially after seeing Agent B's finding about physical part trading via the N key (which I missed).

However, I maintain my concern about complexity:
- Two separate UI sections in the catalog (parts count AND currency balance)
- Two separate earning systems to balance
- Two separate validation paths in purchase flow
- Potential player confusion about which to use

**My revised position after reading A's reasoning:**
I'm **willing to compromise** if we implement it as:
- **Primary path:** Currency-based unlocks (the main feature request)
- **Secondary/legacy path:** Parts still functional, with clear conversion mechanism (parts → currency)
- **Transitional UI:** Show both but make currency prominent

This preserves the trading economy Agent B discovered while not fragmenting the new system.

**Agent D - "Verified and Critical" vs "Must Be Verified" (Semantic Disagreement):**

In Round 1, I said Agent B's bug "must be verified." Agent D states it's "verified and critical." I think there's a miscommunication here:
- Agent B *documented* that the load line appears missing
- But none of us actually READ the load_preferences() code to confirm
- We inferred from Agent B's analysis

I agree it's **critical** and **extremely likely to be true**, but I'd feel better if one of us actually looked at the load_preferences() implementation to confirm before stating it as "verified fact." This is about rigor, not doubting Agent B's excellent work.

**Agent A - Faction Restriction Position (Constructive Disagreement):**

Agent A suggests the new currency should be UNIFIED (one currency) but unlock trees remain faction-separated. This is actually brilliant and I hadn't considered this middle ground. I was thinking binary: either keep three faction currencies OR fully unify everything.

**I AGREE with Agent A's position** - this gives us:
- Economic simplicity (one currency to track)
- Game balance preservation (faction progression trees)
- Design flexibility (can add cross-faction ships later)

This resolves my concern about faction complexity. **Changing my position to align with Agent A on this.**

**2. Gaps or Missing Information I Noticed:**

**Agent A's Round 2:**

Excellent depth on what surprised them and areas of alignment. However, I notice:
- Proposes phasing strategy (Phase 0-3) which is smart, but doesn't detail WHAT goes in each phase
- Mentions "verify Agent B's bug" but doesn't volunteer to do it (we should just do it now)
- Missing concrete proposal for how parts→currency conversion would work if we keep both

**Agent B's Analysis (Still Round 1):**

Agent B hasn't yet responded to Round 2, so I can't evaluate gaps in their Round 2 thinking. However, in Round 1:
- Found the critical bug but didn't explore HOW to fix it (just add load line? migration needed?)
- Discovered physical trading but didn't propose how this translates to new system
- Missing discussion of TGUI capabilities

**Agent D's Analysis (Still Round 1):**

Similarly, Agent D hasn't responded to Round 2 yet. In Round 1:
- Verified the bug and explained bank account patterns well
- Missing proposal for spawn point expansion (they found the limitation but not the solution)
- No discussion of image rendering infrastructure

**ALL AGENTS (Including Me):**

Nobody has investigated:
- **TGUI image display capabilities** - Can TGUI show images? How?
- **Existing ship visualization systems** - Does the code have any ship preview/rendering?
- **Concrete phasing milestones** - What's MVP vs full feature?
- **Migration strategy** - How do existing players transition from parts to currency?
- **Testing approach** - How do we test persistence without corrupting live saves?

**3. Findings from Others That Surprised Me or That I Missed:**

**Agent B - Physical Part Trading Economy (COMPLETELY MISSED):**

The 'N' keybinding that converts digital parts → physical items for player-to-player trading is BRILLIANT game design I completely overlooked. This creates emergent economy and social gameplay.

**Implications for new system:**
- Maybe currency should ALSO be tradeable (currency → tokens?)
- Or keep parts specifically for trading economy
- This explains why Agent A wants to preserve parts system

**This finding makes me reconsider my "deprecate parts" position.** Maybe parts serve a unique social function (trading) that currency shouldn't replace.

**Agent D - Spawn Point Inflexibility (Cryopod-Only):**

I documented spawn points but didn't realize the architectural limitation. Only cryopods register as spawn points. If crew customization needs role-based spawning (captain on bridge, engineer in engine room), we need significant spawn system expansion.

**This is a hidden complexity** for the customization feature. We might need to:
- Create new spawn point types beyond cryopods
- Link job definitions to specific spawn zones
- Handle maps that don't have appropriate spawn zones

**This could be a scope blocker for advanced customization.**

**Agent D - Latejoin Menu Complete Hijack:**

"The system completely hijacks the standard latejoin menu" - I knew this but didn't frame it architecturally. Agent D is right: this isn't an add-on to SS13, it's a fundamental replacement. **Any redesign must maintain this override or rebuild the entire join pipeline.**

This raises the stakes for the TGUI catalog - we can't just "add" a ship catalog, we're REPLACING the entire join UI.

**Agent A - Phasing Strategy Concept:**

Agent A proposed:
- Phase 0: Bug fix
- Phase 1: TGUI catalog (visual but simple)
- Phase 2: Unlock system (core feature)
- Phase 3: Customization (complex, can defer)

This is smart scope management. **I fully support this phasing approach** and will build on it in my Round 3 proposal.

**Agent B - Round-End Reward Timing (Exploitation-Resistant):**

Parts granted during `display_report()` prevents mid-round farming while ensuring rewards. This timing pattern should be preserved for currency. Good operational security thinking I didn't emphasize.

**Agent D - Free Ships Config as Admin Testing Infrastructure:**

The `free_ships` config isn't just a bypass - it's testing infrastructure. The new unlock system needs similar admin/testing capabilities. I mentioned this in passing but didn't emphasize its importance for development and server operations.

**4. What I'm in Alignment On and Ready to Proceed:**

**UNIVERSAL AGREEMENT (100% Consensus):**

✅ **Fix Persistence Bug First (Priority #0)**
- All four agents agree non-negotiable
- Agent D says it's verified, but I'd like to confirm by actually reading load_preferences()
- Should be straightforward fix (add load line + migration logic)
- **I volunteer to verify this in Round 3 if needed**

✅ **Keep Template System - Extend Don't Replace**
- Templates are well-designed and extensible
- All agents agree
- My data flow analysis shows clear insertion points

✅ **Thread-Safe Spawning Must Be Preserved**
- `shuttle_loading` mutex, SSair management
- Agent D emphasized this as server stability critical
- Completely agree - can't compromise on this

✅ **TGUI Catalog Interface Required**
- Current BYOND dialogs are insufficient
- Need visual ship previews
- All agents want this
- **This is Phase 1 in any reasonable implementation**

✅ **Permanent Unlock System Needed**
- Shift from consumable to permanent unlocks
- New `ships_unlocked` in preferences
- Universal consensus

✅ **Ship-Centric Design Philosophy**
- Agent D's observation about complete latejoin replacement is key
- This isn't an addon, it's the core gameplay
- Must preserve this paradigm

**STRONG ALIGNMENT (Revised Positions):**

✅ **Unified Currency, Faction-Separated Unlock Trees** (Agent A's Proposal)
- **I'm changing my position to support this**
- One currency (simple economics)
- Three faction unlock trees (preserves game balance)
- Best of both worlds
- Agent A convinced me on this

⚠️ **Parts System Future** (Moving Toward Compromise)
- Originally: I wanted to deprecate parts
- After reading Agent B's trading economy finding: **I'm more open to keeping parts**
- **New position**: Parts could serve TRADING function, currency serves UNLOCKING function
- This gives each system a unique role
- **I'm willing to compromise here**

✅ **Leverage Existing Infrastructure**
- Bank account patterns (Agent D's proposal)
- Preferences/savefile system
- Signal hooks for stats/achievements
- All agents agree, so do I

**AREAS NEEDING DISCUSSION:**

⚠️ **Phasing Strategy**
- Agent A proposed 4 phases (bug fix → catalog → unlocks → customization)
- All agents agree scope is massive
- **I strongly support this phasing**
- Round 3 should detail what goes in each phase

⚠️ **Per-Round Spawn Limits**
- I identified current system has NO limits
- Agent A validated this gap
- Design questions: Can you re-spawn destroyed ships? Once per round absolute?
- **Needs user clarification**

⚠️ **Currency Earning System**
- All agents noted this is unspecified in feature request
- Critical design gap
- **Needs user clarification before architecture**

⚠️ **Antagonist Ships Definition**
- What are they?
- Separate system or special tier?
- **Needs user clarification**

⚠️ **Ship Skins Scope**
- Palette swaps vs map variants vs modular attachments?
- Wildly different complexity
- **Needs user clarification**

**CRITICAL QUESTIONS FOR USER (Before Round 3):**

Before I can propose detailed architecture in Round 3, I need clarification on:

1. **Currency Earning:** How do players earn the new currency? (Round completion? In-game activities? Admin grants?)
2. **Antagonist Ships:** What does this mean? (Antag-only unlocks? Per-round temporary? Special equipment?)
3. **Ship Skins Scope:** How complex? (Palette swaps? Full map variants? Modular parts?)
4. **Per-Round Limits:** Can destroyed unlocked ships be re-spawned in the same round?
5. **Parts vs Currency:** Do you want to REPLACE parts or keep them for trading economy?

**AM I READY TO PROCEED TO ROUND 3:**

**YES, with approach:**

1. **First, verify the persistence bug** - I'll read load_preferences() code to confirm Agent B's finding
2. **Ask user the 5 critical questions above** - We can't finalize architecture without these answers
3. **Propose phased architecture** - Following Agent A's smart phasing concept:
   - Phase 0: Fix persistence bug
   - Phase 1: TGUI catalog with ship previews
   - Phase 2: Unlock system with currency
   - Phase 3: Crew customization

4. **Provide multiple approaches** for areas of disagreement:
   - Option A: Keep parts + currency (parallel systems)
   - Option B: Currency primary, parts as trading tokens
   - Option C: Fully deprecate parts

   With clear tradeoff analysis for each

**My Round 3 Proposal Will Include:**

- **Detailed component architecture** (TGUI catalog, unlock manager, currency system, customization layer)
- **Integration points with existing systems** (leveraging my data flow analysis)
- **Phased implementation roadmap** (MVP → Full Feature)
- **Multiple options for contentious decisions** (parts system, faction unification, etc.)
- **Clear dependencies and prerequisites** (what needs user input, what needs bug fixes)

**Changed Positions After Round 2:**

1. **Faction approach:** Now support unified currency + faction unlock trees (Agent A's proposal)
2. **Parts system:** More open to keeping for trading economy (Agent B's finding)
3. **Phasing strategy:** Fully support Agent A's 4-phase approach
4. **Priority on verification:** Want to confirm persistence bug before asserting it as verified fact

**Ready to proceed to Round 3 architectural proposals!**

### Agent D Response

[Agent D: Read ALL other agents' summaries above (A, B, C). Document:

1. Points where you DISAGREE with their findings
2. Gaps or missing information you noticed in their analyses
3. Findings from others that surprised you or that you missed]
4. What you are in alignment on and if you're ready to proceed.

---

## USER DECISIONS - DESIGN CONSTRAINTS FOR ROUND 3

**Status:** User has provided answers to all 5 critical questions. All agents must incorporate these decisions into Round 3 architectural proposals.

**Source:** user-decision-points.md

---

### Decision 1: Currency Earning System

**User Choice:** Hybrid approach
- **A. Round completion rewards** ✅ (mimic current parts system)
- **E. Custom:** Players should be able to **find and craft parts in-game** ✅

**Implications for agents:**
- Design both passive earning (round-end rewards) AND active earning (finding/crafting)
- Need crafting system for parts
- Need lootable part spawns/discovery mechanics

---

### Decision 2: Parts System Future

**User Choice:** Three-tier progression system
- **E. Custom:** "Currency can be used to buy parts. Parts are used to buy ships PERMANENTLY." ✅

**Clarification:**
- Currency → Parts (parts are craftable/purchasable with currency)
- Parts → Permanent Ship Unlocks (parts unlock ships forever, not consumable)
- This is different from all agent proposals (keeps parts but shifts to permanent unlocks)

**Implications for agents:**
- Parts remain in the system but change from consumable to permanent unlock currency
- Currency is a meta-layer above parts
- Need to design: what is "currency" vs what are "parts"?
- Agent B's physical trading system (N key) preserved

---

### Decision 3: Per-Round Spawn Limits

**User Choice:** One spawn per round
- **A. One spawn per round (destroyed ship = you're done)** ✅

**Implications for agents:**
- Track ships spawned per round per player
- Once ship is destroyed/deleted, player cannot re-spawn that round
- High stakes - ship destruction is meaningful

---

### Decision 4: Antagonist Ships

**User Choice:** Full antagonist conversion system
- **F. Custom:** "Ships that are aligned with an antagonist or antag organization like the syndicate, blood cult, xenomorphs, etc. These antag ships will make anyone spawning on them into a specific antag and give them equipment related to that antagonist. These ships are **per-round purchases** and require **special antag parts** that are super rare or expensive" ✅

**Key Requirements:**
- Ships aligned with specific antag factions (Syndicate, blood cult, xenomorphs, etc.)
- Spawning on antag ship → automatic conversion to that antagonist role
- Include appropriate antag equipment for that faction
- **DIFFERENT FROM REGULAR SHIPS:** Per-round purchases (consumable), NOT permanent unlocks
- Require special "antag parts" (separate from regular parts)
- Antag parts are rare/expensive

**Implications for agents:**
- Two parallel ship systems: regular (permanent unlocks) vs antag (per-round consumable)
- Need antag part type/currency separate from regular parts
- Need antagonist role conversion on ship spawn
- Need antag equipment loadouts per ship type
- Catalog needs to distinguish regular vs antag ships

---

### Decision 5: Ship Skins Complexity

**User Choice:** Full map variants
- **B. Full map variants (hard - separate .dmm files per skin)** ✅

**Implications for agents:**
- Each skin is a complete separate map file (.dmm)
- Not simple recolors - full layout variants possible
- Template system needs to support multiple .dmm variants per ship
- Preview system needs to handle multiple variants
- Higher complexity but maximum flexibility

---

## CRITICAL DESIGN CLARIFICATIONS NEEDED

Based on user decisions, agents should address these questions in Round 3 proposals:

### 1. Currency vs Parts Definition
**User specified:** "Currency can be used to buy parts. Parts are used to buy ships PERMANENTLY."

**Questions:**
- What IS "currency"? (credits? meta-points? something else?)
- What ARE "parts"? (keep current NEU/NT-C/SYN-C parts? new unified part system?)
- Is currency cross-faction or faction-specific?
- Are parts cross-faction or faction-specific?

**Agent C's earlier proposal:** Unified currency + faction unlock trees
**Does this align with user's vision?** User's decision suggests parts remain faction-specific (since they unlock ships), but currency could be unified.

### 2. Regular Parts vs Antag Parts
**User specified:** Antag ships require "special antag parts that are super rare or expensive"

**Questions:**
- Are antag parts a separate inventory? (regular parts + antag parts)
- Can currency buy antag parts? Or antag parts only found/earned?
- Do antag parts follow same faction system as regular parts?
- Are antag parts consumable (since antag ships are per-round)?

### 3. Crafting System Details
**User specified:** "You should be able to find and craft parts"

**Questions:**
- Craft using what materials/resources?
- Craft at what location? (ship fabricators? stations? anywhere?)
- Craft regular parts only, or antag parts too?
- Crafting recipes defined per part type?

### 4. Per-Round Antag Ship Purchase Flow
**User specified:** Antag ships are per-round purchases (not permanent unlocks)

**Questions:**
- Do you need to unlock antag ships first, THEN pay per-round? Or just pay per-round?
- If destroyed, can you buy another antag ship same round? (or follows same one-spawn limit?)
- Separate catalog interface for antag ships?

---

## UPDATED AGENT INSTRUCTIONS FOR ROUND 3

All agents proceeding to Round 3 must:

1. **Incorporate ALL user decisions** as hard constraints
2. **Address the clarification questions** above in your proposals
3. **Propose concrete definitions** for:
   - What is "currency"
   - What are "parts" (keep current system modified? new system?)
   - Regular parts vs antag parts architecture
   - Crafting system design
4. **Design TWO ship systems:**
   - Regular ships (permanent unlocks via parts)
   - Antag ships (per-round consumable via antag parts)
5. **Maintain all previous consensus:**
   - Fix persistence bug first (Phase 0)
   - TGUI catalog with previews
   - Thread-safe spawning
   - Extend template system

---

