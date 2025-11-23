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

## Round 3: Proposed Solution Architecture

### Agent A's Proposal

**Full detailed proposal:** See `agent-a-round3-proposal.md` (separate file for full technical details)

**EXECUTIVE SUMMARY:**

**Architecture:** Dual-Economy, Three-Tier Progression (Credits → Parts → Permanent Unlocks)

**Core Model:**
- ✅ **Unified Credits** (meta-currency) + **Faction-Specific Parts** (NEU/NT-C/SYN-C)
- ✅ **Parts = Permanent Unlock Currency** (not consumable)
- ✅ **Parallel Antag System** (separate parts, per-round consumable)
- ✅ **One-Spawn-Per-Round** (destroyed = done)
- ✅ **Hybrid Earning** (round rewards + crafting/discovery)
- ✅ **Full Map Variant Skins** (separate .dmm files)

**KEY COMPONENTS:**

1. **Persistence (Phase 0 - Week 1):**
   - FIX: Add `load_ships()` proc to load preferences
   - New fields: `ship_credits`, `ships_parts`, `antag_parts`, `ships_unlocked`
   - Per-round tracking: `ship_spawned_this_round` boolean

2. **TGUI Catalog (Phase 1 - Weeks 2-4):**
   - Visual grid catalog with preview images
   - Dual tabs: Regular Ships | Antag Ships
   - Filters: faction, class, tier, unlock status
   - Detail modal with stats, jobs, skins

3. **Unlock System (Phase 2 - Weeks 5-8):**
   - Credits earned: round rewards (100+), loot chips, crafting bonus
   - Parts purchased: 500-750 credits (regular), 5000 credits (antag)
   - Unlocking: Spend parts → permanent unlock → free spawns forever
   - Validation: Check unlocks, check one-spawn limit

4. **Crafting (Phase 3 - Weeks 9-12):**
   - Fabricator: craft parts from materials (iron, plasma, bluespace)
   - Antag parts: rare materials, dangerous locations
   - Bonus credits on successful craft
   - Antag ships: per-round purchase, convert to antag on spawn

5. **Customization (Phase 4 - Weeks 13-16):**
   - Ship skins: full .dmm variants
   - Crew customization: modify job slots pre-spawn
   - Ship naming, loadout selection

**INTEGRATION:**
- Latejoin hijack preserved (TGUI replaces BYOND dialog)
- Ship creation pipeline unchanged (`SSshuttle.create_ship`)
- Thread safety maintained (`shuttle_loading` mutex, SSair management)
- Physical trading preserved (N key: digital → physical parts)
- Job assembly extended for customizations

**PHASED DELIVERY:**
- Phase 0: Bug fix (1 week) → Persistence works
- Phase 1: TGUI catalog (3 weeks) → Visual browsing
- Phase 2: Economy (4 weeks) → Full unlock system
- Phase 3: Crafting/antag (4 weeks) → Complete features
- Phase 4: Customization (4 weeks) → Polish

**TOTAL: 16 weeks (4 months)**

**TRADEOFFS:**
- ✅ Preserves infrastructure, clear progression, phased risk reduction
- ⚠️ Three-tier economy complexity, dual catalog UI, high content creation for skins

**ANSWERS TO CLARIFICATIONS:**
- Currency = Credits (unified); Parts = Faction-specific unlock currency
- Antag parts = separate inventory, consumable, very expensive (5000 credits)
- Crafting = materials from mining, at fabricators, both regular + antag parts
- Antag flow = no unlock needed, pay per-round, one-spawn limit applies

**READY FOR CONSENSUS**

### Agent B's Proposal

**ARCHITECTURE: Three-Tier Progression with Dual Ship Systems**

Incorporating all user decisions, I propose a modular architecture that keeps parts but shifts them from consumable to permanent unlock currency, adds a unified meta-currency layer, and implements dual ship systems (regular permanent + antag per-round).

---

## I. EXECUTIVE SUMMARY

**Core Progression Flow:**
```
Gameplay → Ship Credits (unified currency) → Ship Parts (faction-specific) → Permanent Ship Unlocks → One Spawn Per Round
                                           ↓
                                    Antag Parts (rare/expensive) → Per-Round Antag Ships → Auto-Antagonist Conversion
```

**Key Architectural Principles:**
- ✅ Three-tier economy (credits → parts → unlocks) per user decision
- ✅ Preserve existing systems (faction parts, physical trading, thread safety)
- ✅ Dual ship models (permanent regular + consumable antag)
- ✅ Hybrid earning (passive + active)
- ✅ Full map variants (separate .dmm files per skin)
- ✅ JSON persistence for MVP (DB migration path documented)
- ✅ Phased implementation (6 phases, ~20 weeks)

---

## II. CURRENCY & PARTS SYSTEM DEFINITION

### Definition 1: What is "Currency"?

**Ship Credits** - A unified, cross-faction meta-currency

**Properties:**
- Name: "Ship Credits" (SC)
- Cross-faction: NOT faction-specific, universal
- Persistent: Saved in player preferences JSON
- Earnable via:
  - Round completion rewards (passive, ~100-500 per round)
  - Finding credit tokens in-game (active, 100-5000 per token)
  - Selling items/resources (active, configurable)
  - Crafting and selling parts (active)

**Storage:**
```dm
/datum/preferences
    var/ship_credits = 0  // Universal currency
```

**Why unified?** Simplifies player understanding, flexible spending, easier economy balancing, aligns with "currency can buy parts" user decision.

### Definition 2: What are "Parts"?

**Faction-Specific Permanent Unlock Tokens**

**Keep current system MODIFIED:**
- NEU Parts (Neutral faction)
- NT-C Parts (Nanotrasen faction)
- SYN-C Parts (Syndicate faction)
- **NEW:** Antag Parts (separate subsystem, detailed below)

**Changed Behavior:**
- **OLD:** Consumable (spend 2 NEU parts each time you spawn Bogatyr)
- **NEW:** Permanent unlock currency (spend 2 NEU parts ONCE to unlock Bogatyr forever)

**Obtainable via:**
- Purchase with ship credits (currency → parts conversion)
- Crafting at fabricators (materials → parts)
- Finding in-game (loot spawners)
- Round-end rewards (1 random part, preserve existing system)

**Storage:**
```dm
/datum/preferences
    // Regular parts (for permanent unlocks)
    var/list/ship_parts_inventory = list(
        /obj/item/ship_parts/neutral = 0,
        /obj/item/ship_parts/nanotrasen = 0,
        /obj/item/ship_parts/syndicate = 0,
    )
```

**Why faction-specific?** Preserves game balance, creates progression trees, physical trading still works, user decision implies parts remain central.

### Definition 3: Regular Parts vs Antag Parts

**Regular Parts:**
- Purpose: Permanent ship unlocks
- Consumption: Non-consumable (spend once, own forever)
- Earning: Credits, crafting, finding, round-end
- Rarity: Common (accumulate over time)
- Trading: Yes via N key

**Antag Parts:**
- Purpose: Per-round antag ship purchases
- Consumption: CONSUMABLE (spent each purchase)
- Earning: Rare drops, expensive credit purchases, admin grants
- Rarity: Super rare/expensive
- Types: Faction-specific to antag (Syndicate Ops, Blood Cult, Xenomorph, etc.)
- Trading: Yes via N key (but very rare)

**Separate Inventories:**
```dm
/datum/preferences
    var/list/antag_parts_inventory = list(
        /obj/item/ship_parts/antag/syndicate_ops = 0,
        /obj/item/ship_parts/antag/blood_cult = 0,
        /obj/item/ship_parts/antag/xenomorph_hive = 0,
    )
```

---

## III. CORE ARCHITECTURAL COMPONENTS

### Component 1: Currency & Parts Economy Manager
**Location:** `voidcrew/modules/ship_economy/`

**Files:**
- `ship_credits.dm` - Credit earning, display, transactions
- `ship_parts_conversion.dm` - Credit → part exchange
- `part_items.dm` - Physical part items (extends existing)
- `economy_config.dm` - Exchange rates, costs

**Responsibilities:**
- Earn ship credits (round-end, finding, selling)
- Convert credits to parts at exchange rate
- Manage part inventories
- Physical part withdrawal (N key - existing)
- Balance tuning

**Key New Procs:**
```dm
/client/proc/earn_ship_credits(amount, reason)
    prefs.ship_credits += amount
    to_chat(src, "<span class='notice'>+[amount] SC: [reason]</span>")
    prefs.save_ship_economy()

/client/proc/buy_ship_part(part_type, cost_credits)
    if(prefs.ship_credits < cost_credits)
        return FALSE
    prefs.ship_credits -= cost_credits
    prefs.ship_parts_inventory[part_type]++
    prefs.save_ship_economy()
    to_chat(src, "<span class='notice'>Purchased 1x [part_type] for [cost_credits] SC</span>")
    return TRUE

/client/proc/withdraw_credit_token(amount)
    if(prefs.ship_credits < amount)
        return FALSE
    prefs.ship_credits -= amount
    var/obj/item/ship_credit_token/token = new(mob.loc)
    token.credit_value = amount
    prefs.save_ship_economy()
    return TRUE
```

**Exchange Rates (tunable):**
- 500 SC = 1 NEU part
- 750 SC = 1 NT-C part
- 750 SC = 1 SYN-C part
- 5000 SC = 1 Antag part (very expensive)

### Component 2: Ship Unlock Manager
**Location:** `voidcrew/modules/ship_unlocks/`

**Files:**
- `unlock_manager.dm` - Core unlock logic
- `unlock_persistence.dm` - Save/load unlocked ships
- `unlock_requirements.dm` - Cost validation

**Responsibilities:**
- Track which ships player has unlocked permanently
- Validate unlock requirements (parts available, not already unlocked)
- Process unlock purchases (deduct parts, add to unlocked list)
- Prevent duplicate unlocks
- Handle unlock UI interactions

**New Datum:**
```dm
/datum/ship_unlock_manager
    var/client/owner

    proc/is_unlocked(ship_template)
        return (ship_template.type in owner.prefs.ships_unlocked)

    proc/can_unlock(ship_template)
        // Already unlocked?
        if(is_unlocked(ship_template))
            return FALSE
        // Check parts available
        var/faction = initial(ship_template.faction_prefix)
        var/cost = initial(ship_template.unlock_cost)
        var/part_type = get_part_type_for_faction(faction)
        return (owner.prefs.ship_parts_inventory[part_type] >= cost)

    proc/unlock_ship(ship_template)
        if(!can_unlock(ship_template))
            return FALSE
        // Deduct parts
        var/faction = initial(ship_template.faction_prefix)
        var/cost = initial(ship_template.unlock_cost)
        var/part_type = get_part_type_for_faction(faction)
        owner.prefs.ship_parts_inventory[part_type] -= cost
        // Add to unlocked
        owner.prefs.ships_unlocked += ship_template.type
        owner.prefs.save_ship_economy()
        to_chat(owner, "<span class='notice'>Permanently unlocked: [initial(ship_template.name)]!</span>")
        return TRUE
```

### Component 3: TGUI Ship Catalog
**Location:** `tgui/packages/tgui/interfaces/ShipCatalog/`

**Files:**
- `ShipCatalog.tsx` - Main catalog component
- `ShipCard.tsx` - Individual ship display
- `ShipPreview.tsx` - Image preview with variants
- `RegularShipsTab.tsx` - Permanent unlock ships tab
- `AntagShipsTab.tsx` - Per-round antag ships tab
- `ResourceDisplay.tsx` - Show credits, parts inventory

**Features:**
- Grid/list view toggle
- Locked/unlocked status indicators
- Ship preview images (per variant)
- Ship stats (crew size, faction, description)
- Unlock cost display
- Purchase unlock button (for locked ships)
- Spawn button with variant selection (for unlocked ships)
- Filter by faction/status
- Search by name
- Sort by cost/name/crew size

**UI Layout:**
```
┌────────────────────────────────────────────────────────────┐
│ SHIP CATALOG                    [Credits: 5000 SC]         │
│ ┌──────────┬──────────┐                                    │
│ │ Regular  │  Antag   │  [Search: ___] [Filter: All ▼]    │
│ └──────────┴──────────┘                                    │
│                                                             │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│ │  Bogatyr     │ │    Delta     │ │     Box      │        │
│ │  [PREVIEW]   │ │  [PREVIEW]   │ │  [PREVIEW]   │        │
│ │  ✓ Unlocked  │ │  🔒 Locked   │ │  ✓ Unlocked  │        │
│ │  NEU • 10ppl │ │  NEU • 9ppl  │ │  NEU • 9ppl  │        │
│ │              │ │  Needs:      │ │              │        │
│ │  Variants:   │ │  3 NEU parts │ │  Variants:   │        │
│ │  • Default   │ │  (1500 SC)   │ │  • Default   │        │
│ │  • Industrial│ │              │ │              │        │
│ │  [SPAWN ▼]   │ │  [UNLOCK]    │ │  [SPAWN]     │        │
│ └──────────────┘ └──────────────┘ └──────────────┘        │
│                                                             │
│ Your Parts: NEU: 5 | NT-C: 2 | SYN-C: 1                   │
│ Your Antag Parts: SYN-OPS: 0 | CULT: 1 | XENO: 0          │
└────────────────────────────────────────────────────────────┘
```

**TGUI Data Interface:**
```typescript
interface ShipCatalogData {
  player_credits: number;
  player_parts: Record<string, number>;
  player_antag_parts: Record<string, number>;
  ships_unlocked: string[];
  has_spawned_this_round: boolean;
  regular_ships: RegularShip[];
  antag_ships: AntagShip[];
}

interface RegularShip {
  template_type: string;
  name: string;
  faction: string;
  unlock_cost_parts: number;
  unlock_cost_credits: number; // For display (parts × exchange rate)
  preview_image: string;
  crew_capacity: number;
  description: string;
  variants: ShipVariant[];
  is_unlocked: boolean;
}

interface AntagShip {
  template_type: string;
  name: string;
  antag_type_name: string; // "Nuclear Operative", "Blood Cultist"
  cost_antag_parts: number;
  cost_credits: number; // For buying antag parts
  preview_image: string;
  description: string;
  variants: ShipVariant[];
}

interface ShipVariant {
  name: string; // "Default", "Industrial", "Luxury"
  preview_image: string;
  map_file: string;
}
```

**TGUI Actions:**
```typescript
// Purchase permanent unlock
act('unlock_ship', {
  template: '/datum/map_template/shuttle/voidcrew/bogatyr'
});

// Spawn unlocked ship with variant
act('spawn_ship', {
  template: '/datum/map_template/shuttle/voidcrew/bogatyr',
  variant: 'industrial'
});

// Purchase antag ship (per-round)
act('purchase_antag_ship', {
  template: '/datum/map_template/shuttle/voidcrew/antag/syndicate_ops'
});

// Buy parts with credits
act('buy_part', {
  part_type: '/obj/item/ship_parts/neutral',
  quantity: 2
});
```

### Component 4: Extended Ship Templates
**Location:** `voidcrew/mapping/shuttles/_shuttle.dm`

**Template Extensions:**
```dm
/datum/map_template/shuttle/voidcrew
    // EXISTING
    var/faction_prefix = NEUTRAL_SHIP
    var/short_name
    var/part_cost = 1  // DEPRECATED for regular ships
    var/list/job_slots = list()

    // NEW: Unlock system
    var/unlock_cost = 2  // Parts required to PERMANENTLY unlock
    var/preview_image = "bogatyr_preview.png"  // Asset path for catalog
    var/description = "A versatile exploration vessel capable of long-range missions."
    var/crew_capacity = 10  // For display
    var/ship_tier = 1  // Optional progression gating

    // NEW: Map variants (skins)
    var/list/map_variants = list(
        "default" = "ship_bogatyr.dmm",
        "industrial" = "ship_bogatyr_industrial.dmm",
        "luxury" = "ship_bogatyr_luxury.dmm",
    )

    // NEW: Antag ship properties
    var/is_antag_ship = FALSE
    var/antag_type = null  // /datum/antagonist/nukeop
    var/antag_part_type = null  // /obj/item/ship_parts/antag/syndicate_ops
    var/antag_part_cost = 1  // Consumable cost per purchase
    var/list/antag_equipment = list()  // Starting gear
```

**Regular Ship Example:**
```dm
/datum/map_template/shuttle/voidcrew/bogatyr
    name = "Bogatyr-class Explorator"
    short_name = "Bogatyr-class"
    faction_prefix = NEUTRAL_SHIP
    unlock_cost = 2  // 2 NEU parts to unlock permanently
    preview_image = "bogatyr_preview.png"
    description = "A sturdy exploration vessel equipped for long-range missions and resource gathering."
    crew_capacity = 10

    map_variants = list(
        "default" = "ship_bogatyr.dmm",
        "industrial" = "ship_bogatyr_industrial.dmm",
    )

    job_slots = list(
        list("name" = "Captain", "officer" = TRUE, ...),
        list("name" = "Scientist", ...),
        list("name" = "Miner", "slots" = 2, ...),
        // etc.
    )
```

**Antag Ship Example:**
```dm
/datum/map_template/shuttle/voidcrew/antag/syndicate_ops_cruiser
    name = "Syndicate Strike Cruiser"
    faction_prefix = SYNDICATE_SHIP
    is_antag_ship = TRUE
    antag_type = /datum/antagonist/nukeop
    antag_part_type = /obj/item/ship_parts/antag/syndicate_ops
    antag_part_cost = 1  // Costs 1 SYN-OPS antag part per round
    unlock_cost = 0  // No permanent unlock - always per-round

    description = "A heavily armed Syndicate vessel designed for strike operations. Spawning aboard converts you to a Nuclear Operative."
    preview_image = "syndicate_ops_cruiser_preview.png"

    antag_equipment = list(
        /obj/item/gun/ballistic/automatic/ar,
        /obj/item/pinpointer/nuke,
        /obj/item/clothing/suit/space/hardsuit/syndi,
        /obj/item/tank/internals/emergency_oxygen/double,
    )

    job_slots = list(
        list("name" = "Syndicate Commander", "outfit" = /datum/outfit/syndicate/commander, ...),
        list("name" = "Syndicate Operative", "slots" = 4, ...),
    )
```

### Component 5: Crafting System
**Location:** `voidcrew/modules/ship_economy/crafting/`

**Files:**
- `part_fabricator.dm` - Fabricator machine
- `crafting_recipes.dm` - Part recipes
- `loot_spawners.dm` - Credit/part spawners

**Ship Part Fabricator Machine:**
```dm
/obj/machinery/ship_part_fabricator
    name = "ship part fabricator"
    desc = "Converts raw materials and components into ship construction parts. Used for building new vessels."
    icon = 'icons/obj/machines/research.dmi'
    icon_state = "protolathe"

    var/list/materials_stored = list()
    var/list/available_recipes = list()
    var/currently_crafting = null
    var/craft_time_remaining = 0

    proc/can_craft(datum/crafting_recipe/ship_part/recipe)
        for(var/material_type in recipe.requirements)
            if(materials_stored[material_type] < recipe.requirements[material_type])
                return FALSE
        return TRUE

    proc/start_craft(datum/crafting_recipe/ship_part/recipe, mob/user)
        if(!can_craft(recipe))
            to_chat(user, "<span class='warning'>Insufficient materials!</span>")
            return FALSE
        // Consume materials
        for(var/material_type in recipe.requirements)
            materials_stored[material_type] -= recipe.requirements[material_type]
        currently_crafting = recipe
        craft_time_remaining = recipe.crafting_time
        visible_message("<span class='notice'>[src] begins fabricating [recipe.name]...</span>")
        addtimer(CALLBACK(src, PROC_REF(finish_craft)), recipe.crafting_time)
        return TRUE

    proc/finish_craft()
        if(!currently_crafting)
            return
        var/datum/crafting_recipe/ship_part/recipe = currently_crafting
        new recipe.result_type(get_turf(src))
        visible_message("<span class='notice'>[src] dispenses a completed [recipe.name].</span>")
        currently_crafting = null
```

**Crafting Recipes:**
```dm
/datum/crafting_recipe/ship_part
    var/result_type
    var/crafting_time = 30 SECONDS
    var/list/requirements = list()

/datum/crafting_recipe/ship_part/neutral
    name = "Neutral Ship Part"
    result_type = /obj/item/ship_parts/neutral
    crafting_time = 30 SECONDS
    requirements = list(
        /obj/item/stack/sheet/metal = 50,
        /obj/item/stack/sheet/glass = 20,
        /obj/item/stack/sheet/plasteel = 10,
    )

/datum/crafting_recipe/ship_part/nanotrasen
    name = "Nanotrasen Ship Part"
    result_type = /obj/item/ship_parts/nanotrasen
    crafting_time = 45 SECONDS
    requirements = list(
        /obj/item/stack/sheet/metal = 50,
        /obj/item/stack/sheet/glass = 20,
        /obj/item/stack/sheet/plasteel = 10,
        /obj/item/circuitboard/nanotrasen = 1,  // Rare NT-specific component
    )

/datum/crafting_recipe/ship_part/syndicate
    name = "Syndicate Ship Part"
    result_type = /obj/item/ship_parts/syndicate
    crafting_time = 45 SECONDS
    requirements = list(
        /obj/item/stack/sheet/metal = 50,
        /obj/item/stack/sheet/glass = 20,
        /obj/item/stack/sheet/plasteel = 10,
        /obj/item/assembly/signaler/syndicate = 1,  // Rare SYN-specific component
    )

// NOTE: Antag parts NOT craftable - too exploitable
```

**Loot Spawners:**
```dm
/obj/item/ship_credit_token
    name = "ship credit chip"
    desc = "A secure data chip containing transferable ship construction credits."
    icon = 'icons/obj/economy.dmi'
    icon_state = "credit_chip"
    var/credit_value = 100

    attack_self(mob/user)
        if(!user.client)
            return
        user.client.earn_ship_credits(credit_value, "redeemed credit chip")
        to_chat(user, "<span class='notice'>You redeem [src] for [credit_value] ship credits!</span>")
        qdel(src)

/obj/item/ship_credit_token/small
    credit_value = 100

/obj/item/ship_credit_token/medium
    credit_value = 500

/obj/item/ship_credit_token/large
    credit_value = 1000

/obj/item/ship_credit_token/jackpot
    credit_value = 5000

/obj/effect/spawner/random/ship_economy
    loot = list(
        /obj/item/ship_credit_token/small = 40,
        /obj/item/ship_credit_token/medium = 30,
        /obj/item/ship_parts/neutral = 15,
        /obj/item/ship_parts/nanotrasen = 10,
        /obj/item/ship_parts/syndicate = 4,
        /obj/item/ship_parts/antag/syndicate_ops = 1,  // SUPER RARE
    )
```

### Component 6: Per-Round Spawn Tracking
**Location:** `voidcrew/modules/ship_unlocks/spawn_tracking.dm`

**Per-Round State (NOT saved):**
```dm
/client
    var/has_spawned_ship_this_round = FALSE  // Resets each round
    var/spawned_ship_template = null  // Track which ship they spawned

/datum/controller/subsystem/ticker/proc/initialize_round()
    . = ..()
    for(var/client/C in GLOB.clients)
        C.has_spawned_ship_this_round = FALSE
        C.spawned_ship_template = null
```

**Spawn Validation:**
```dm
/mob/dead/new_player/proc/can_spawn_ship(ship_template)
    // Check spawn limit
    if(client.has_spawned_ship_this_round)
        tgui_alert(src, "You have already spawned a ship this round. If your ship was destroyed, you cannot spawn another until next round.", "Spawn Limit Reached")
        return FALSE

    // Regular ships: check unlocked
    if(!ship_template.is_antag_ship)
        if(!(ship_template.type in client.prefs.ships_unlocked))
            tgui_alert(src, "You have not unlocked this ship yet. Purchase the unlock with ship parts first.", "Ship Locked")
            return FALSE

    // Antag ships: check and consume antag parts
    else
        var/cost = initial(ship_template.antag_part_cost)
        var/part_type = initial(ship_template.antag_part_type)
        if(client.prefs.antag_parts_inventory[part_type] < cost)
            tgui_alert(src, "You lack the required antag parts! Need: [cost]x [part_type.name]", "Insufficient Antag Parts")
            return FALSE
        // Deduct antag parts (CONSUMABLE)
        client.prefs.antag_parts_inventory[part_type] -= cost
        client.prefs.save_ship_economy()
        to_chat(src, "<span class='warning'>You spend [cost]x [part_type.name] to purchase this antag ship for this round.</span>")

    return TRUE
```

### Component 7: Antagonist Conversion System
**Location:** `voidcrew/modules/ship_unlocks/antag_conversion.dm`

**Conversion on Antag Ship Spawn:**
```dm
/mob/dead/new_player/proc/convert_to_antagonist(antag_datum_type)
    // Create antagonist datum
    var/datum/antagonist/antag = new antag_datum_type()

    // Assign to player's mind
    mind.add_antag_datum(antag)

    // Antag-specific setup
    antag.on_gain(mind)

    // Announce
    to_chat(src, "<span class='userdanger bold'>You are now a [antag.name]!</span>")
    to_chat(src, "<span class='notice'>[antag.role_text]</span>")
    to_chat(src, "<span class='notice'>[antag.objectives_text]</span>")

    // Send antag greeting
    antag.greet()

/mob/dead/new_player/proc/give_antag_equipment(ship_template)
    // Wait for character creation
    if(!mind.current)
        return

    // Equip starting gear
    for(var/item_type in ship_template.antag_equipment)
        var/obj/item/I = new item_type(mind.current)
        if(!mind.current.equip_to_appropriate_slot(I))
            mind.current.put_in_hands(I)

/mob/dead/new_player/proc/spawn_on_antag_ship(ship_template, variant="default")
    // Create ship
    var/obj/structure/overmap/ship/new_ship = SSshuttle.create_ship(ship_template, variant)

    // Convert to antagonist
    convert_to_antagonist(ship_template.antag_type)

    // Mark as spawned
    client.has_spawned_ship_this_round = TRUE
    client.spawned_ship_template = ship_template.type

    // Spawn player as first job (usually leader)
    AttemptSpawnOnShip(new_ship.job_slots[1], new_ship)

    // Give equipment after spawn
    addtimer(CALLBACK(src, PROC_REF(give_antag_equipment), ship_template), 1 SECOND)

    return TRUE
```

**Antag Types:**
- Nuclear Operatives (Syndicate Ops ship)
- Blood Cultists (Blood Cult ship)
- Xenomorphs (Xenomorph Hive ship)
- Revolutionaries (possible future)
- Clockwork Cultists (possible future)

### Component 8: Ship Variant (Skin) System
**Location:** `voidcrew/modules/ship_variants/`

**Variant Selection in Catalog:**
When player clicks "SPAWN" on unlocked ship, show variant dropdown if multiple variants exist.

**Variant Loading:**
```dm
/datum/controller/subsystem/shuttle/proc/create_ship(datum/map_template/shuttle/voidcrew/template, variant="default")
    // Get variant map file
    var/map_file = template.map_variants[variant]
    if(!map_file)
        map_file = template.map_variants["default"]
        log_runtime("Invalid variant '[variant]' for [template.name], using default")

    // Temporarily override suffix for loading
    var/original_suffix = template.suffix
    template.suffix = map_file

    // Standard ship creation pipeline (existing code)
    shuttle_loading = TRUE
    SSair.can_fire = FALSE

    var/obj/structure/overmap/ship/new_ship = new /obj/structure/overmap/ship(SSovermap.get_unused_overmap_square(), template)
    var/obj/docking_port/mobile/voidcrew/loaded = action_load(template)

    SSair.can_fire = TRUE
    shuttle_loading = FALSE

    // Link and finalize
    loaded.current_ship = new_ship
    new_ship.shuttle = loaded
    new_ship.display_name = template.short_name
    SEND_SIGNAL(new_ship, COMSIG_VOIDCREW_SHIP_LOADED, new_ship)

    // Restore original suffix
    template.suffix = original_suffix

    return new_ship
```

**Map Variant File Structure:**
```
_maps/voidcrew/ships/
  ├── ship_bogatyr.dmm                  (default)
  ├── ship_bogatyr_industrial.dmm       (industrial skin)
  ├── ship_bogatyr_luxury.dmm           (luxury skin)
  ├── ship_delta.dmm                    (default)
  ├── ship_delta_military.dmm           (military skin)
  ├── ship_delta_cargo.dmm              (cargo hauler skin)
  └── ... (30+ ships × 2-3 variants each)
```

Each .dmm file is a COMPLETE map with different layouts, aesthetics, equipment placement.

---

## IV. PERSISTENCE & DATA FLOW

### Persistence Layer (JSON Savefile)

**Extended /datum/preferences:**
```dm
/datum/preferences
    // CURRENCY (new)
    var/ship_credits = 0

    // REGULAR PARTS (modified)
    var/list/ship_parts_inventory = list(
        /obj/item/ship_parts/neutral = 0,
        /obj/item/ship_parts/nanotrasen = 0,
        /obj/item/ship_parts/syndicate = 0,
    )

    // ANTAG PARTS (new)
    var/list/antag_parts_inventory = list(
        /obj/item/ship_parts/antag/syndicate_ops = 0,
        /obj/item/ship_parts/antag/blood_cult = 0,
        /obj/item/ship_parts/antag/xenomorph_hive = 0,
    )

    // UNLOCKED SHIPS (new)
    var/list/ships_unlocked = list()  // List of template type paths

    // CUSTOMIZATIONS (future Phase 3+)
    var/list/ship_customizations = list()

// SAVE
/datum/preferences/proc/save_ship_economy()
    savefile.set_entry("ship_credits", ship_credits)
    savefile.set_entry("ship_parts_inventory", ship_parts_inventory)
    savefile.set_entry("antag_parts_inventory", antag_parts_inventory)
    savefile.set_entry("ships_unlocked", ships_unlocked)
    savefile.set_entry("ship_customizations", ship_customizations)
    savefile.save()

// LOAD (FIX THE BUG!)
/datum/preferences/proc/load_preferences()
    // ... existing loads (lastchangelog, be_special, key_bindings, etc.) ...

    // NEW: Load ship economy data (THIS WAS MISSING - THE BUG)
    ship_credits = savefile.get_entry("ship_credits", ship_credits)
    ship_parts_inventory = savefile.get_entry("ship_parts_inventory", ship_parts_inventory)
    antag_parts_inventory = savefile.get_entry("antag_parts_inventory", antag_parts_inventory)
    ships_unlocked = savefile.get_entry("ships_unlocked", ships_unlocked)
    ship_customizations = savefile.get_entry("ship_customizations", ship_customizations)
```

**JSON File Example:**
```json
{
  "version": 49,
  "ship_credits": 5000,
  "ship_parts_inventory": {
    "/obj/item/ship_parts/neutral": 5,
    "/obj/item/ship_parts/nanotrasen": 2,
    "/obj/item/ship_parts/syndicate": 1
  },
  "antag_parts_inventory": {
    "/obj/item/ship_parts/antag/syndicate_ops": 0,
    "/obj/item/ship_parts/antag/blood_cult": 1,
    "/obj/item/ship_parts/antag/xenomorph_hive": 0
  },
  "ships_unlocked": [
    "/datum/map_template/shuttle/voidcrew/bogatyr",
    "/datum/map_template/shuttle/voidcrew/delta",
    "/datum/map_template/shuttle/voidcrew/box"
  ],
  "ship_customizations": {}
}
```

### Complete Data Flow Examples

**Flow 1: Round-End Rewards**
```dm
/datum/controller/subsystem/ticker/display_report(popcount)
    . = ..()
    for(var/client/C in GLOB.clients)
        // Give ship credits (new)
        var/base_credits = 100
        var/time_played = (world.time - SSticker.round_start_time) / (1 MINUTE)
        var/time_bonus = time_played * 5  // 5 credits per minute
        C.earn_ship_credits(base_credits + time_bonus, "round completion")

        // Give random part (existing, preserve)
        C.give_random_ship_part()
```

**Flow 2: Finding Credits**
Player finds credit token → Uses in hand → Redeems credits → Saved to preferences

**Flow 3: Unlocking Ship**
```
Player opens catalog (TGUI) → Views locked ship → Clicks "UNLOCK"
   ↓
TGUI act('unlock_ship', {template: "..."})
   ↓
/datum/ship_unlock_manager/unlock_ship(client, template)
   - Validate parts available
   - Deduct parts from inventory
   - Add to ships_unlocked list
   - Save preferences
   - Update catalog UI
```

**Flow 4: Spawning Ship**
```
Player selects unlocked ship → Chooses variant → Clicks "SPAWN"
   ↓
TGUI act('spawn_ship', {template: "...", variant: "industrial"})
   ↓
/mob/dead/new_player/spawn_on_ship(template, variant)
   - Check has_spawned_ship_this_round (FALSE)
   - Check template in ships_unlocked (TRUE)
   - Create ship with variant map file
   - Mark has_spawned_ship_this_round = TRUE
   - Spawn player as captain
```

**Flow 5: Purchasing Antag Ship**
```
Player opens catalog → Antag tab → Clicks "PURCHASE"
   ↓
TGUI act('purchase_antag_ship', {template: "..."})
   ↓
/mob/dead/new_player/spawn_on_antag_ship(template, variant)
   - Check has_spawned_ship_this_round (FALSE)
   - Check antag_parts_inventory[type] >= cost
   - Deduct antag parts (CONSUMABLE)
   - Create ship
   - Convert to antagonist
   - Give equipment
   - Mark has_spawned_ship_this_round = TRUE
```

---

## V. INTEGRATION WITH EXISTING SYSTEMS

**Latejoin Hijack:** Preserve existing override - catalog replaces latejoin menu
**Thread Safety:** Maintain `shuttle_loading` mutex and SSair patterns
**Signal Hooks:** Leverage COMSIG_VOIDCREW_SHIP_LOADED for stats/tracking
**Ship Bank Accounts:** Separate from player credits (no interaction)
**Physical Trading:** Extended - N key can withdraw parts OR credit tokens
**Job System:** Use existing `assemble_job_slots()` - no changes needed
**Template System:** Extended with new vars - backward compatible

---

## VI. TRADEOFFS & DESIGN ANALYSIS

### Advantages:
✅ **Preserves existing mechanics** - Physical trading, faction parts, thread safety all maintained
✅ **Flexible progression** - Three paths (credits, parts, unlocks) give player choice
✅ **Dual ship systems** - Regular (permanent) + antag (consumable) clearly separated
✅ **Scalable** - JSON for MVP (<100 players), DB migration path documented
✅ **Player agency** - Choose unlocks, variants, trading options
✅ **Active + passive earning** - Rewards engagement without requiring it

### Disadvantages:
❌ **Complexity** - Three-tier economy adds cognitive load
❌ **Massive scope** - ~20 weeks development across 6 phases
❌ **Content burden** - Map variants require 90+ .dmm files
❌ **Harsh one-spawn limit** - Could frustrate players
❌ **Balance nightmare** - Many tuning knobs (exchange rates, costs, earning rates)
❌ **Two parallel part systems** - Regular vs antag could confuse

### Open Questions Requiring User Input:
1. **Credit Earning Rates:** 100/round? 500/round?
2. **Exchange Rates:** 1 part = 500 credits? 1000?
3. **Unlock Costs:** Starter ships 1-2 parts, advanced 3-5?
4. **Antag Part Rarity:** How rare is "super rare"? 1% drop chance?
5. **Insurance System:** Future mitigation for one-spawn harshness?
6. **Antag Ship Limits:** Can multiple players buy antag ships same round?

---

## VII. PHASED IMPLEMENTATION PLAN

### Phase 0: Bug Fix & Foundation (1-2 weeks)
**Tasks:**
- Fix ships_owned load bug (add to `load_preferences()`)
- Add new fields: `ship_credits`, `ships_unlocked`, `antag_parts_inventory`
- Implement save/load for new fields
- Add migration logic for existing players
- Test save/load cycle thoroughly

**Deliverable:** Persistence layer functional

### Phase 1: Currency & Basic Unlock System (2-3 weeks)
**Tasks:**
- Ship credits earning (round-end, finding tokens)
- Credit → part conversion
- Part → ship unlock (permanent, not consumable)
- Extend ship templates with new vars
- Per-round spawn tracking
- Modify existing purchase flow to check `ships_unlocked`
- Keep old parts system functional (legacy compatibility)

**Testing:** Earn credits, buy parts, unlock ships, spawn once per round

**Deliverable:** Backend unlock system works via console commands

### Phase 2: TGUI Ship Catalog (3-4 weeks)
**Tasks:**
- Create React components (ShipCatalog, ShipCard, etc.)
- Grid/list view with locked/unlocked status
- Ship stats, costs, descriptions
- Placeholder preview images (temp assets)
- Unlock purchase UI flow
- Spawn UI flow
- Replace latejoin menu
- Filter/search/sort

**Testing:** Visual catalog, unlock ships via UI, spawn via UI

**Deliverable:** Players use catalog instead of console

### Phase 3: Crafting System (2-3 weeks)
**Tasks:**
- Ship part fabricator machine
- Crafting recipes (NEU/NT-C/SYN-C)
- Loot spawners (credits, parts)
- Place fabricators on maps
- Place spawners in ruins/loot

**Testing:** Craft parts, find credits/parts, trade with N key

**Deliverable:** Active earning functional

### Phase 4: Antag Ships (3-4 weeks)
**Tasks:**
- Define antag part types
- Create antag ship templates (Syndicate Ops, Blood Cult, Xenomorph)
- Antag part earning (rare drops, expensive purchases)
- Antag tab in catalog
- Per-round purchase flow
- Antagonist conversion logic
- Antag equipment loadouts

**Testing:** Earn antag parts, buy antag ship, become antagonist

**Deliverable:** Antag ships functional

### Phase 5: Ship Variants & Previews (4-6 weeks)
**Tasks:**
- Create map variants (MASSIVE content creation)
- Generate preview images (screenshots/renders)
- Variant selection UI
- Variant loading in ship creation
- Image asset pipeline
- Optimize image loading (lazy load, cache)

**Testing:** Select variant, ship loads correct .dmm, previews display

**Deliverable:** Full visual catalog with variants

### Phase 6: Polish & Balance (2-3 weeks)
**Tasks:**
- Balance tuning (rates, costs, exchange rates)
- UI polish (animations, feedback)
- Bug fixes
- Performance optimization
- Admin tools (grant credits/parts, reset unlocks)
- Analytics (economy health tracking)

**Deliverable:** Production-ready

**TOTAL ESTIMATE:** ~20 weeks (5 months)

---

## VIII. SUCCESS METRICS

**Player Engagement:**
- % players who unlock ≥1 ship
- Average ships unlocked per player
- Average time to first unlock
- % players who craft vs buy parts

**Economy Health:**
- Total credits in circulation
- Average credits per player
- Credit earning rate vs spending rate
- Part conversion rates

**Feature Usage:**
- % players using catalog vs old system
- Most popular ships
- Antag ship usage frequency
- Variant selection distribution

**Balance:**
- Time to unlock all ships (target: months)
- Antag ship spawn rate (target: <5% rounds)
- Player retention post-launch

---

## IX. CONCLUSION

This architecture fulfills ALL 5 user decisions:
1. ✅ Hybrid earning (round-end + find/craft)
2. ✅ Three-tier system (credits → parts → permanent unlocks)
3. ✅ One spawn per round (high stakes)
4. ✅ Antag ships (per-round, auto-convert, rare parts)
5. ✅ Full map variants (separate .dmm files)

Addresses ALL clarification questions with concrete definitions. Maintains backward compatibility with existing systems. Provides phased implementation preventing scope explosion. Documents persistence scalability path.

**Agent B's proposal complete - ready for Round 4 consensus.**

### Agent C's Proposal

**ARCHITECTURE: Three-Tier Permanent Unlock System with Dual Ship Economies**

After incorporating user decisions, Round 2 discussions, and the critical database persistence clarification, I propose a phased architecture that separates regular ships (permanent unlocks) from antagonist ships (per-round consumable).

---

## I. HIGH-LEVEL ARCHITECTURE

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    PLAYER PROGRESSION LAYER                      │
│  ┌──────────────┐      ┌──────────────┐      ┌───────────────┐ │
│  │   CURRENCY   │  →   │    PARTS     │  →   │ SHIP UNLOCKS  │ │
│  │  (Unified)   │      │ (3 Factions) │      │  (Permanent)  │ │
│  └──────────────┘      └──────────────┘      └───────────────┘ │
│         ↑                     ↑                                  │
│    Round Rewards         Find/Craft                              │
└─────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────┐
│                   ANTAGONIST SHIP LAYER                          │
│  ┌──────────────┐      ┌──────────────┐      ┌───────────────┐ │
│  │   CURRENCY   │  →   │ ANTAG PARTS  │  →   │ ANTAG SHIP    │ │
│  │  (Unified)   │      │  (Rare/$$)   │      │  (Per-Round)  │ │
│  └──────────────┘      └──────────────┘      └───────────────┘ │
│         ↑                     ↑                                  │
│    Round Rewards         Find/Craft (Rare)                       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        UI/CATALOG LAYER                          │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  TGUI Ship Catalog (replaces select_ship() dialogs)     │   │
│  │  - Regular Ships Tab  (unlock once, spawn free)         │   │
│  │  - Antag Ships Tab    (per-round purchase)              │   │
│  │  - Ship previews (.dmm renders + skin variants)         │   │
│  │  - Customization UI   (crew roles, loadouts)            │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    EXISTING SHIP SPAWNING                        │
│        SSshuttle.create_ship() → SSovermap → Ship Object         │
│              (UNCHANGED - we insert before this)                 │
└─────────────────────────────────────────────────────────────────┘
```

### Three-Tier Progression (User Decision)

**Tier 1: Currency (Unified Meta-Economy)**
- **Definition:** "Ship Credits" (SC) - unified cross-faction currency
- **Earning:** Hybrid (round completion + find/craft)
- **Storage:** Database-backed
- **Purpose:** Purchase parts OR antag parts

**Tier 2A: Regular Parts (Faction-Specific Unlock Currency)**
- **Definition:** NEU/NT-C/SYN-C parts (KEEP existing three factions)
- **Change:** Parts become **permanent unlock currency** (NOT consumable)
- **Acquisition:** Buy with currency, craft, find as loot
- **Storage:** Database (fix Agent B's load bug)
- **Purpose:** Permanently unlock ships (spend once, own forever)
- **Physical Trading:** Preserve N-key system

**Tier 2B: Antag Parts (Special Consumable Currency)**
- **Definition:** Separate types per antag faction
- **Acquisition:** Buy (expensive), craft (rare materials), find (super rare)
- **Storage:** Database, separate table
- **Purpose:** Per-round purchase of antag ships (CONSUMABLE)

**Tier 3: Ship Unlocks**
- **Regular Ships:** Permanent unlocks
- **Antag Ships:** Per-round purchases

---

## II. DATABASE SCHEMA (User Clarified: Database, Not Savefiles)

```sql
-- Table: player_ship_currency (NEW)
CREATE TABLE player_ship_currency (
    ckey TEXT PRIMARY KEY,
    currency_amount INTEGER DEFAULT 0,
    last_updated TIMESTAMP
);

-- Table: player_ship_parts (EXISTING - FIX LOAD BUG)
CREATE TABLE player_ship_parts (
    ckey TEXT,
    part_type TEXT,  -- 'NEU', 'NT-C', 'SYN-C'
    part_count INTEGER DEFAULT 0,
    PRIMARY KEY (ckey, part_type)
);

-- Table: player_antag_parts (NEW)
CREATE TABLE player_antag_parts (
    ckey TEXT,
    antag_part_type TEXT,
    part_count INTEGER DEFAULT 0,
    PRIMARY KEY (ckey, antag_part_type)
);

-- Table: player_ship_unlocks (NEW)
CREATE TABLE player_ship_unlocks (
    ckey TEXT,
    ship_template_path TEXT,
    unlocked_date TIMESTAMP,
    PRIMARY KEY (ckey, ship_template_path)
);

-- Table: player_ship_customizations (NEW)
CREATE TABLE player_ship_customizations (
    ckey TEXT,
    ship_template_path TEXT,
    customization_json TEXT,
    PRIMARY KEY (ckey, ship_template_path)
);

-- Table: round_ship_spawns (NEW - per-round tracking)
CREATE TABLE round_ship_spawns (
    round_id INTEGER,
    ckey TEXT,
    ship_template_path TEXT,
    spawn_time TIMESTAMP,
    PRIMARY KEY (round_id, ckey)
);
```

**FIX FOR AGENT B'S BUG:**

Current broken code only saves but never loads. Fix:

```dm
/datum/preferences/proc/load_character(slot)
    . = ..()

    // FIX: Add database load for ship parts
    var/datum/db_query/query = SSdbcore.NewQuery(
        "SELECT part_type, part_count FROM player_ship_parts WHERE ckey = :ckey",
        list("ckey" = parent.ckey)
    )

    if(query.Execute())
        ships_owned = list()
        while(query.NextRow())
            var/part_type = query.item[1]
            var/part_count = text2num(query.item[2])
            ships_owned[part_type] = part_count

    qdel(query)
```

---

## III. PHASED IMPLEMENTATION ROADMAP

### PHASE 0: Fix Persistence Bug (PRIORITY ZERO)

**Duration:** 1-2 days

**Tasks:**
1. Add database load query for `ships_owned` (fix Agent B's bug)
2. Test save/load cycle
3. Create new DB tables
4. Implement `/datum/ship_progression_manager`
5. Migration for existing players

**Deliverable:** Working database persistence

---

### PHASE 1: TGUI Ship Catalog (MVP)

**Duration:** 1-2 weeks

**Tasks:**
1. Create TGUI interface
2. Generate ship preview images
3. Replace `select_ship()` with catalog
4. Display unlocked ships (read-only)
5. Basic spawning from catalog
6. Per-round spawn limits

**Deliverable:** Visual catalog replacing BYOND dialogs

---

### PHASE 2: Currency & Unlock System (CORE)

**Duration:** 2-3 weeks

**Tasks:**
1. Currency earning (round-end + loot)
2. Parts purchasing with currency
3. Ship unlock purchasing
4. Physical trading (N-key)
5. Crafting recipes

**Deliverable:** Full three-tier progression

---

### PHASE 3: Antagonist Ship System

**Duration:** 2-3 weeks

**Tasks:**
1. Antag ship templates
2. Antag parts system
3. Antag tab in catalog
4. Antagonist conversion
5. Antag equipment loadouts

**Deliverable:** Full antag ship system

---

### PHASE 4: Customization & Skins

**Duration:** 3-4 weeks

**Tasks:**
1. Customization UI
2. Job slot editing
3. Skin system (full .dmm variants)
4. Database storage
5. Apply before spawn

**Deliverable:** Full customization

---

**Total Timeline:** ~10-13 weeks

---

## IV. INTEGRATION WITH EXISTING SYSTEMS

**Latejoin Menu:** Hijack maintained - catalog replaces `select_ship()`

**Ship Creation:** Insert before `SSshuttle.create_ship()` - pipeline unchanged

**Thread Safety:** Preserve `shuttle_loading` mutex and SSair management

**Database:** All persistence via DB queries, not savefiles

**Crafting:** Extend existing system with ship part recipes

**Signals:** Use COMSIG_VOIDCREW_SHIP_LOADED for stats/achievements

---

## V. TRADEOFFS

**Three-Tier Progression:**
- Pro: Preserves existing parts, Agent B's trading
- Con: More complex than direct unlock
- Mitigation: Clear UI, tutorial

**Database Persistence:**
- Pro: Structured, performant, transaction-safe
- Con: Requires DB setup
- Mitigation: Export tool for backups

**Antag Ships Separate:**
- Pro: Balanced rarity, clear separation
- Con: Dual system complexity
- Mitigation: Separate UI tab

**Full .dmm Variants:**
- Pro: Maximum flexibility
- Con: High content cost
- Mitigation: Start with few skins

**One Spawn Limit:**
- Pro: High stakes gameplay
- Con: Punishing if destroyed
- Mitigation: Clear warnings

---

## VI. ADDRESSING CLARIFICATION QUESTIONS

**Q1: What is "currency"?**
Ship Credits (SC) - unified meta-currency, earned via round rewards + loot + crafting sales

**Q2: What are "parts"?**
- Regular: NEU/NT-C/SYN-C (permanent unlock currency)
- Antag: Syndicate Token, Cult Artifact, etc. (consumable)

**Q3: Regular vs Antag Parts?**
- Regular: permanent unlocks, moderate rarity
- Antag: per-round consumable, super rare

**Q4: Crafting Details?**
- Materials: currency + common/rare materials
- Location: existing crafting benches
- All types craftable (antag parts very difficult)

**Q5: Antag Ship Flow?**
- No unlock required, direct purchase
- Same one-spawn limit as regular
- Separate "Antagonist Ships" tab
- Purchase & spawn in one action

---

## VII. SUMMARY

**This architecture:**
- ✅ Incorporates ALL user decisions
- ✅ Fixes Agent B's critical bug (Phase 0)
- ✅ Preserves existing systems
- ✅ Phased rollout (scope management)
- ✅ Database-backed (user confirmed)
- ✅ Addresses all clarifications
- ✅ Maintains agent consensus

**MVP:** Phases 0-2 (core unlock system working)

**Polish:** Phases 3-4 (antag ships, customization)

**Ready for parallel development:** Phases 3 & 4 can run simultaneously

**Recommendation:** Proceed with this architecture

---

**Agent C - Round 3 Proposal Complete**

### Agent D's Proposal

After reading all Round 2 discussions, here is my comprehensive architectural proposal for the ship purchase redesign:

---

## AGENT D - PHASED HYBRID ARCHITECTURE PROPOSAL

### High-Level Philosophy

**Core Principle**: Build a flexible, phased system that preserves existing infrastructure while enabling permanent ship ownership, visual catalog browsing, and player progression.

**Key Design Decision**: **Unified currency with faction-themed unlock trees** - one currency type to earn/spend, but ships organized into faction progression paths for game balance.

**Implementation Approach**: Phased rollout with each phase fully functional and testable independently.

---

## PHASE 0: FOUNDATION FIX (Priority Zero - Blocking)

**Must complete before ANY other work.**

### Component: Persistence Bug Fix

**Problem**: `ships_owned` is saved but never loaded (confirmed in `preferences_savefile.dm:193+`)

**Solution**:
```dm
// In /datum/preferences/proc/load_preferences()
// Add after line 234 (key_bindings load):

ships_owned = savefile.get_entry("ships_owned", ships_owned)
```

**Migration Strategy**:
- Existing savefiles missing `ships_owned` will default to initial value (all zeros)
- No data loss risk since load never worked anyway
- Add version check if we modify `ships_owned` structure later

**Testing Requirements**:
1. Create new player → verify `ships_owned` initializes to zeros
2. Grant parts via `give_random_ship_part()` → verify save writes
3. Restart server → verify load reads saved values
4. Verify `list_ship_parts()` displays correct counts

**Deliverable**: One-line code fix + verification test script

**Estimated Effort**: 1 hour (fix + test)

---

## PHASE 1: VISUAL SHIP CATALOG (TGUI Interface)

**Goal**: Replace current text-based purchase UI with visual ship catalog showing previews, stats, and metadata.

### Component 1.1: Ship Catalog Data Layer

**New Datum**: `/datum/ship_catalog_entry`

**Purpose**: Wrapper around ship templates that adds display metadata without polluting game logic templates.

**Structure**:
```dm
/datum/ship_catalog_entry
    var/datum/map_template/shuttle/voidcrew/ship_template  // Reference to actual ship

    // Display Metadata
    var/display_name                 // Formatted name for UI
    var/description                  // Lore/gameplay description
    var/preview_image_path           // Path to preview PNG: "icons/ship_previews/delta.png"
    var/tier                         // Visual grouping: "Starter", "Advanced", "Elite"
    var/faction                      // NEU, NT-C, SYN-C for filtering/sorting

    // Stats for Display
    var/crew_capacity                // Total job slots
    var/estimated_speed              // "Fast", "Medium", "Slow" or numeric
    var/combat_rating                // Optional: "Light", "Medium", "Heavy"
    var/special_features = list()    // List of highlights: "Medbay", "Mining", etc.

    // Unlock Prerequisites (for future phases)
    var/currency_cost = 0            // Cost in new currency
    var/required_unlocks = list()    // Other ships that must be unlocked first
    var/faction_requirement          // Optional: require faction alignment
```

**Responsibility**: Pure data - no game logic, just catalog display information.

**Integration**: Load during `SSmapping.load_ship_templates()`, build parallel catalog list.

### Component 1.2: Ship Preview Image System

**Image Storage**: `icons/ship_previews/[ship_suffix].png`

**Generation Approach** (Decision Needed - Propose Options):

**Option A: Pre-Rendered Screenshots** (Recommended for Phase 1)
- Manually screenshot each ship map in Dream Maker
- Save as PNG, resize to standard catalog size (e.g., 400x300px)
- **Pros**: High quality, no runtime cost, full control
- **Cons**: Manual work, must update if ship maps change

**Option B: Runtime Map Rendering**
- Generate preview images on-demand from .dmm files
- Cache generated images
- **Pros**: Automatic updates when maps change
- **Cons**: Complex implementation, performance concerns

**Option C: Hybrid**
- Ship creators provide preview images as part of ship definition
- Fallback to placeholder if missing
- **Pros**: Flexible, no bottleneck
- **Cons**: Quality variation

**Phase 1 Recommendation**: Option A (pre-rendered) for speed, migrate to Option C later.

### Component 1.3: TGUI Catalog Interface

**New TGUI Component**: `ShipCatalog.tsx`

**UI Structure**:
```
┌─────────────────────────────────────────────┐
│ SHIP CATALOG                    [X Close]  │
├─────────────────────────────────────────────┤
│ Filters: [All] [NEU] [NT-C] [SYN-C]       │
│ Sort: [Name] [Cost] [Tier] [Crew Size]    │
├─────────────────────────────────────────────┤
│ ┌────────┐  ┌────────┐  ┌────────┐        │
│ │ [IMG]  │  │ [IMG]  │  │ [IMG]  │        │
│ │ Delta  │  │ Bogatyr│  │ Box    │        │
│ │ 3 pts  │  │ 2 pts  │  │ 1 pt   │        │
│ │ [VIEW] │  │ [VIEW] │  │ [VIEW] │        │
│ └────────┘  └────────┘  └────────┘        │
│                                             │
│ [Selected Ship Details Panel]              │
│  • Crew: 9                                  │
│  • Class: Frigate                           │
│  • Description: ...                         │
│  • Cost: 3 NEU parts                        │
│  [PURCHASE BUTTON]                          │
└─────────────────────────────────────────────┘
```

**Features**:
- Grid view of ship thumbnails
- Faction filtering/sorting
- Detail panel on selection
- Purchase button (current parts validation initially)
- Lazy loading if 30+ ships (load 12 at a time)

**Data Flow**:
```
Player clicks "Purchase ship"
  → Opens ShipCatalog TGUI
  → TGUI requests catalog data from server
  → Server builds catalog_entry list, serializes to JSON
  → TGUI renders grid with images
  → Player selects ship
  → TGUI shows detail panel
  → Player clicks Purchase
  → Server validates parts (current system)
  → Server calls SSshuttle.create_ship()
  → Player spawns on ship
```

**Integration with Existing**:
- Replace `tgui_input_list()` call in `select_ship()` with `tgui_catalog.ui_interact()`
- Keep fallback to text list if TGUI fails (accessibility)
- Preserve existing purchase validation logic initially

**TGUI Dependencies** (Research Needed):
- Image display component (likely `<Image>` or `<img>` tag)
- Icon/PNG loading from server
- Grid layout component
- State management for filters/selection

### Component 1.4: Existing Ship Selection Integration

**Modification**: `voidcrew/edits/mobs/new_player.dm`

**Current Flow**:
```dm
proc/select_ship()
    // Build list of active ships
    // Show "Purchase ship" option
    // Use tgui_input_list()
```

**New Flow**:
```dm
proc/select_ship()
    // Build list of active ships (unchanged)
    // Show choice: "Join Existing Ship" or "Browse Ship Catalog"

    if("Browse Ship Catalog"):
        open_ship_catalog()  // New TGUI interface
    else:
        show_existing_ships()  // Keep current system
```

**Backward Compatibility**: Both paths work, gradual transition.

---

## PHASE 2: PERMANENT UNLOCK SYSTEM

**Goal**: Shift from consumable parts (spend per spawn) to permanent unlocks (buy once, own forever, spawn per-round).

### Component 2.1: Player Unlock Persistence

**Extend**: `/datum/preferences`

**New Fields**:
```dm
/datum/preferences
    // Existing
    var/list/ships_owned = list(...)  // Keep for parts (legacy/conversion)

    // NEW - Permanent Unlocks
    var/list/ships_unlocked = list()  // List of ship template types permanently unlocked
    // Example: list(/datum/map_template/shuttle/voidcrew/delta, /datum/map_template/shuttle/voidcrew/box)

    // NEW - Per-Round Spawn Tracking
    var/list/ships_spawned_this_round = list()  // Reset each round
    // Example: list(/datum/map_template/shuttle/voidcrew/delta) - spawned this round

    // NEW - Ship Customizations (for Phase 3+)
    var/list/ship_customizations = list()  // Keyed by ship template type
```

**Save/Load**:
```dm
proc/save_preferences()
    // ... existing saves ...
    savefile.set_entry("ships_unlocked", ships_unlocked)
    savefile.set_entry("ship_customizations", ship_customizations)

proc/load_preferences()
    // ... existing loads ...
    ships_unlocked = savefile.get_entry("ships_unlocked", ships_unlocked)
    ship_customizations = savefile.get_entry("ship_customizations", ship_customizations)
    // Note: ships_spawned_this_round intentionally NOT loaded (per-round only)
```

**Round Reset**:
```dm
/datum/controller/subsystem/overmap/Initialize()
    . = ..()
    // Clear per-round spawn tracking
    for(var/client/C in GLOB.clients)
        if(C.prefs)
            C.prefs.ships_spawned_this_round = list()
```

### Component 2.2: Ship Currency System

**New Datum**: `/datum/bank_account/player_meta`

**Purpose**: Persistent player currency account (separate from ship bank accounts).

**Structure**:
```dm
/datum/bank_account/player_meta
    var/ckey                          // Owner ckey
    var/meta_currency = 0             // Cross-round persistent currency
    var/currency_name = "Ship Credits" // Display name

    proc/adjust_currency(amount, reason)
        meta_currency = max(0, meta_currency + amount)
        log_currency_transaction(ckey, amount, reason)
        return TRUE

    proc/can_afford(cost)
        return meta_currency >= cost
```

**Integration**:
- Created on client login if doesn't exist
- Saved to JSON savefile alongside preferences
- Accessed via `client.meta_account`

**Why New Datum Instead of Preference Var?**
- Reuses bank account infrastructure (transaction logging, admin tools)
- Consistent with existing ship bank accounts
- Easier to extend with features (transaction history, limits, etc.)

### Component 2.3: Currency Earning System (Pluggable)

**Design Philosophy**: Configurable earning sources to allow game balance tuning.

**Base Interface**:
```dm
/datum/currency_source
    var/source_name
    var/enabled = TRUE  // Can be toggled via config

    proc/calculate_reward(client/C)
        return 0  // Override in subtypes
```

**Implemented Sources**:

**Source 1: Round Completion Reward**
```dm
/datum/currency_source/round_completion
    source_name = "Round Completion"
    var/base_reward = 100  // Config adjustable

    proc/calculate_reward(client/C)
        // Grant flat reward for round completion
        return base_reward
```

**Source 2: Performance Bonuses** (Future)
```dm
/datum/currency_source/performance
    // Reward based on objectives, survival, etc.
```

**Source 3: Admin Grants**
```dm
/datum/currency_source/admin_grant
    // Admin verb to grant currency for events
```

**Hook Integration**:
```dm
/datum/controller/subsystem/ticker/declare_completion()
    . = ..()
    for(var/client/C in GLOB.clients)
        grant_currency_rewards(C)

proc/grant_currency_rewards(client/C)
    var/total_reward = 0
    for(var/datum/currency_source/source in SSeconomy.currency_sources)
        if(source.enabled)
            total_reward += source.calculate_reward(C)

    C.meta_account.adjust_currency(total_reward, "Round Completion")
    to_chat(C, "You earned [total_reward] Ship Credits!")
```

**Config Integration**:
```dm
// config.dm
/datum/config_entry/number/base_ship_currency_reward
    default = 100
    min_val = 0
    max_val = 10000
```

### Component 2.4: Unlock Purchase Flow

**Modification**: Ship Catalog TGUI

**New UI Elements**:
- "UNLOCKED" badge on owned ships
- "UNLOCK (Cost: X)" button on locked ships
- "SPAWN" button on unlocked ships (if not spawned this round)
- "SPAWNED THIS ROUND" indicator if already spawned

**Purchase Validation**:
```dm
proc/attempt_unlock_ship(datum/map_template/shuttle/voidcrew/template)
    // Check if already unlocked
    if(template in client.prefs.ships_unlocked)
        to_chat(src, "You already own this ship!")
        return FALSE

    // Check currency cost
    var/datum/ship_catalog_entry/entry = SSovermap.ship_catalog[template]
    if(!client.meta_account.can_afford(entry.currency_cost))
        to_chat(src, "Insufficient Ship Credits! Need [entry.currency_cost], have [client.meta_account.meta_currency]")
        return FALSE

    // Deduct currency
    client.meta_account.adjust_currency(-entry.currency_cost, "Unlocked [entry.display_name]")

    // Add to unlocked list
    client.prefs.ships_unlocked += template
    client.prefs.save_preferences()

    to_chat(src, "Ship unlocked: [entry.display_name]!")
    return TRUE
```

**Spawn Validation**:
```dm
proc/attempt_spawn_ship(datum/map_template/shuttle/voidcrew/template)
    // Check if unlocked
    if(!(template in client.prefs.ships_unlocked))
        to_chat(src, "You haven't unlocked this ship yet!")
        return FALSE

    // Check per-round spawn limit
    if(template in client.prefs.ships_spawned_this_round)
        to_chat(src, "You've already spawned this ship this round!")
        return FALSE

    // Create ship (existing system)
    var/obj/structure/overmap/ship/new_ship = SSshuttle.create_ship(template)
    if(!new_ship)
        return FALSE

    // Track spawn
    client.prefs.ships_spawned_this_round += template

    // Spawn player
    AttemptSpawnOnShip(new_ship.job_slots[1], new_ship)
    return TRUE
```

### Component 2.5: Legacy Parts Migration

**Decision**: Keep parts system as **secondary currency** with conversion mechanism.

**Conversion System**:
```dm
proc/convert_parts_to_currency()
    var/total_value = 0
    var/list/conversion_rates = list(
        /obj/item/ship_parts/neutral = 50,      // 1 NEU part = 50 credits
        /obj/item/ship_parts/nanotrasen = 75,   // 1 NT-C part = 75 credits (premium)
        /obj/item/ship_parts/syndicate = 75,    // 1 SYN-C part = 75 credits (premium)
    )

    for(var/part_type in client.prefs.ships_owned)
        var/count = client.prefs.ships_owned[part_type]
        var/rate = conversion_rates[part_type]
        total_value += count * rate

    if(total_value > 0)
        client.meta_account.adjust_currency(total_value, "Parts Conversion")
        client.prefs.ships_owned = list(...)  // Reset to zeros
        client.prefs.save_preferences()
        to_chat(client, "Converted [total_value] Ship Credits from legacy parts!")
```

**UI Integration**: Add "Convert Parts" button in catalog if player has any parts.

**Physical Trading Preservation**:
- Keep 'N' key binding functional
- Parts can still be withdrawn as physical items
- Physical parts can be converted to currency via `attack_self()`
- This preserves player trading economy

---

## PHASE 3: CREW CUSTOMIZATION (Future / Deferred)

**Goal**: Allow players to modify job slots, outfits, spawn positions before spawning ship.

### Component 3.1: Customization Storage

**Extend**: `/datum/preferences`

**Structure**:
```dm
var/list/ship_customizations = list()
// Keyed by ship template type
// Value: /datum/ship_customization

/datum/ship_customization
    var/list/modified_job_slots = list()  // Override template job_slots
    var/list/job_spawn_positions = list() // Custom spawn locations per job
```

### Component 3.2: Job Assembly Hook

**Modification**: `assemble_job_slots()` in `_shuttle.dm`

**Current**:
```dm
proc/assemble_job_slots()
    // Uses template's job_slots directly
```

**New**:
```dm
proc/assemble_job_slots(client/purchaser)
    // Check for customization override
    if(purchaser?.prefs.ship_customizations[src.type])
        var/datum/ship_customization/custom = purchaser.prefs.ship_customizations[src.type]
        use job_slots = custom.modified_job_slots
    else:
        use job_slots = src.job_slots

    // Rest of assembly logic unchanged
```

### Component 3.3: Customization UI

**TGUI Component**: `ShipCustomizer.tsx`

**Accessed From**: Ship catalog detail panel → "Customize" button (only for owned ships)

**Features**:
- Drag-and-drop job slot editing
- Outfit selection per job
- Cost calculator (customizations cost additional currency)
- Save custom loadout

**Scope Control**: Phase 3 is intentionally deferred - high complexity, lower priority than core unlock system.

---

## INTEGRATION WITH EXISTING SYSTEMS

### Preserves Thread Safety

**No Changes To**:
- `SSshuttle.create_ship()` - keeps existing `shuttle_loading` mutex
- SSair disable/enable pattern
- Shuttle template loading pipeline

**Separation**: Catalog UI and unlock validation happen BEFORE ship creation, not during. Thread safety maintained.

### Leverages Existing Infrastructure

**Reuses**:
- `/datum/preferences` savefile system (proven, works)
- `/datum/bank_account` pattern (transaction logging, admin tools)
- Ship template system (extend, don't replace)
- Signal hooks (COMSIG_VOIDCREW_SHIP_LOADED for stats tracking)
- Config system (adjustable rewards, costs)

**Extends**:
- `SSmapping.ship_purchase_list` → `SSmapping.ship_catalog`
- Preferences persistence
- Economy subsystem

### Maintains Ship-Centric Design

**No Changes To**:
- Latejoin hijack (still redirects to ship selection)
- Ship-based job slots
- Overmap system
- Team/faction mechanics

**Enhancement**: Better UI doesn't change fundamental paradigm.

---

## TRADEOFFS OF THIS APPROACH

### PROS

✅ **Phased Rollout**
- Each phase is independently testable
- Can ship Phase 1 (catalog) without Phase 2 (unlocks)
- Minimizes risk of breaking existing system

✅ **Minimal Existing Code Changes**
- Catalog is additive (wraps templates, doesn't modify them)
- Unlock system extends preferences (doesn't replace parts)
- Ship creation pipeline untouched

✅ **Flexible Design Decisions**
- Currency earning is pluggable (easy to add new sources)
- Conversion rates configurable (parts → currency)
- Customization system deferred (reduces Phase 2 scope)

✅ **Backward Compatible**
- Parts system still works (legacy/conversion)
- Text-based UI still accessible (fallback)
- Existing ships unchanged

✅ **Leverages Proven Patterns**
- Bank account infrastructure (already tested)
- Savefile system (works reliably)
- Template extensibility (designed for this)

### CONS

❌ **Manual Work Required**
- Ship preview images need creation (Phase 1)
- Catalog entries need metadata authoring
- Testing across 30+ ships is time-intensive

❌ **Dual Currency Complexity** (Parts + Credits)
- UI shows both until full migration
- Two validation paths initially
- Player confusion potential during transition

❌ **TGUI Research Dependency**
- Phase 1 blocked until TGUI image display confirmed
- Unknown performance characteristics
- May need lazy-loading optimization

❌ **Deferred Crew Customization**
- Phase 3 scope is large (intentionally deferred)
- Feature request mentions it, but not in Phase 1-2
- Risk of scope creep if attempted too early

❌ **Per-Round Spawn Limits May Feel Restrictive**
- Player unlocks ship, can only spawn once per round
- If ship destroyed, can't re-spawn
- May frustrate players (needs game balance testing)

### ALTERNATIVE TRADEOFFS (If Different Approach)

**If We Fully Replaced Parts System**:
- ✅ Simpler single-currency design
- ❌ Loses physical trading economy
- ❌ No migration path for existing parts

**If We Skipped TGUI Catalog**:
- ✅ Faster Phase 1 implementation
- ❌ Feature request explicitly wants "rendered images"
- ❌ Misses major UX improvement

**If We Combined Phases 1+2**:
- ✅ Ship unlock system available sooner
- ❌ Higher risk (more simultaneous changes)
- ❌ Harder to test/debug

---

## CRITICAL DEPENDENCIES & UNKNOWNS

### Must Research Before Implementation

1. **TGUI Image Display Capabilities**
   - Can TGUI render PNG files from server?
   - What's max image size before lag?
   - Lazy-loading support for large catalogs?

2. **Ship Preview Generation**
   - Who creates preview images? (Artists? Automated?)
   - Standard resolution/format?
   - Update process when ship maps change?

3. **Currency Earning Balance**
   - What's reasonable currency reward per round?
   - How many rounds to unlock average ship?
   - Should high-tier ships require achievements too?

### Requires User/Designer Decisions

1. **Antagonist Ships System**
   - Separate unlock tree? Temporary per-round? Special equipment?
   - Not addressed in this proposal (needs clarification)

2. **Ship Skins Implementation**
   - Palette swaps (easy), map variants (hard), or modular (very hard)?
   - Not addressed in this proposal (needs scope decision)

3. **Per-Round Respawn Rules**
   - Can destroyed ships be re-spawned? With cooldown? With cost?
   - Current proposal: once per round absolute (simplest, needs balance testing)

4. **Faction Restrictions in New System**
   - Keep faction-themed unlock trees? Or all ships unlockable by anyone?
   - Current proposal: unified currency, optional faction requirements per ship

---

## IMPLEMENTATION ROADMAP

### Phase 0: Foundation (1-2 days)
- [ ] Fix persistence bug (`ships_owned` load line)
- [ ] Test save/load cycle
- [ ] Verify parts grant and redemption still works

### Phase 1: Visual Catalog (2-3 weeks)
- [ ] Research TGUI image display
- [ ] Create `/datum/ship_catalog_entry` system
- [ ] Generate ship preview images (30+ ships)
- [ ] Build ShipCatalog.tsx TGUI component
- [ ] Integrate with existing purchase flow
- [ ] Test catalog browsing and filtering

### Phase 2: Unlock System (3-4 weeks)
- [ ] Implement `/datum/bank_account/player_meta`
- [ ] Add `ships_unlocked` to preferences
- [ ] Create currency earning system (pluggable sources)
- [ ] Build unlock purchase validation
- [ ] Implement per-round spawn tracking
- [ ] Create parts → currency conversion system
- [ ] Test unlock progression across rounds

### Phase 3: Crew Customization (4-6 weeks - Future)
- [ ] Design customization storage schema
- [ ] Build ShipCustomizer TGUI interface
- [ ] Hook into `assemble_job_slots()`
- [ ] Implement cost system for customizations
- [ ] Test job slot modifications

---

## CONCLUSION

This phased hybrid architecture:
- **Fixes the critical bug first** (Priority Zero)
- **Delivers visual catalog quickly** (Phase 1 - high UX value)
- **Implements core unlock system** (Phase 2 - feature request goal)
- **Defers complex customization** (Phase 3 - scope control)
- **Preserves existing infrastructure** (minimal breaking changes)
- **Allows flexibility** (pluggable earning, configurable costs)

The unified currency with faction-themed unlock trees provides economic simplicity while maintaining game balance design space. The parts-to-currency migration path preserves player trading economy while transitioning to the new system.

**Ready for implementation** with clear dependencies and unknowns flagged for resolution.

---

## Round 4: Consensus Building

### Agent A's Final Verdict

[Agent A: Read all proposals from Round 3. Explain:

1. Which proposal do you support (can be your own or synthesis of multiple)?
2. What compromises are you willing to make?
3. What are your non-negotiable requirements?
4. Your final recommended approach]

### Agent B's Final Verdict

[Agent B: Read all proposals from Round 3. Explain:

1. Which proposal do you support (can be your own or synthesis of multiple)?
2. What compromises are you willing to make?
3. What are your non-negotiable requirements?
4. Your final recommended approach]

### Agent C's Final Verdict

[Agent C: Read all proposals from Round 3. Explain:

1. Which proposal do you support (can be your own or synthesis of multiple)?
2. What compromises are you willing to make?
3. What are your non-negotiable requirements?
4. Your final recommended approach]

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
