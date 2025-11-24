# Ship Purchase System Redesign - Master Index

## Overview

This document series chronicles a comprehensive multi-agent analysis and consensus-building process for redesigning the ship purchase system in Voidcrew. Four AI agents (A, B, C, D) analyzed the current system, debated approaches, proposed architectures, and reached consensus on implementation strategy.

## Document Navigation

### 📋 [1. Round 1-2: Analysis & Debates](ship-system-round1-2-analysis.md)
**Contains:** Initial system analysis and disagreements
- Round 1: Four agents' initial findings
  - Agent A: Signal-based lifecycle, thread safety analysis
  - Agent B: Critical persistence bug discovery
  - Agent C: Data flow mapping, architectural questions
  - Agent D: Latejoin hijack architecture, bank account infrastructure
- Round 2: Agents respond to each other's findings
  - Disagreements on parts vs currency
  - Gaps in TGUI investigation
  - Alignment on core principles
- User Decisions - Design Constraints
  - Currency earning system
  - Parts system future (3-tier progression)
  - Per-round spawn limits
  - Antagonist ships definition
  - Ship skins complexity

**Key Discoveries:**
- 🔴 Critical bug: `ships_owned` never loads from savefiles
- Physical part trading economy via N-key
- Template system is well-designed and extensible
- Thread-safe spawning must be preserved

**Read this first** to understand the technical foundation and initial debates.

---

### 🏗️ [2. Round 3: Architectural Proposals](ship-system-round3-proposals.md)
**Contains:** Detailed architecture proposals from all four agents
- Agent A: Dual-Economy, Three-Tier Progression
- Agent B: Unified Currency with Legacy Parts Conversion
- Agent C: Database-First Architecture
- Agent D: [Proposal details]

**Scope:** Each agent proposed:
- Complete system architecture
- Database/persistence strategy
- TGUI catalog design
- Currency vs parts model
- Crafting and discovery mechanics
- Antagonist ship system
- Implementation phases

**Read this second** to see the competing architectural visions.

---

### ✅ [3. User Decisions - Round 3.5 Critical Input](ship-system-user-decisions.md)
**Contains:** User's comprehensive feedback on all proposals (21 questions answered)

**Critical Architecture Changes:**
- 🔴 Eliminate faction-specific parts → rarity tiers (basic/advanced/rare/superior)
- 🔴 Database persistence (SQL), not savefiles
- 🔴 Parts unlock blueprints (not consumable)
- Physical parts system with extraction device
- New player starter ship selection
- Two-scale antag ship system (large/small)
- Battlepass integration required

**Key Constraints:**
- Credits cannot be traded between players
- Each character slot has separate credit balance
- Blueprints are account-wide unlocks
- One ship spawn per round (destroyed = done)
- Manual screenshot previews (not procedural generation)

**Read this third** to understand the final requirements.

---

### 🤝 [4. Round 4: Final Consensus](ship-system-round4-consensus.md)
**Contains:** Agent verdicts incorporating user decisions
- Agent A: Final verdict and adaptations
- Agent B: Final verdict and adaptations
- Agent C: Final verdict and adaptations (complete)
- Agent D: [Pending]

**Revised Architectures:**
- Rarity tier system design
- Physical parts + extraction mechanics
- Database schema proposals
- Feature team integration (Battlepass, Custom Roles, Automation)
- 7-phase implementation roadmaps

**Read this last** to see the final consensus and implementation plan.

---

## Decision Flow Diagram

```
Round 1: Initial Analysis
         ↓
    [Critical Bug Found]
         ↓
Round 2: Debates & Gaps
         ↓
    [User Decisions - Design Constraints]
         ↓
Round 3: Architectural Proposals
         ↓
    [User Decisions - Round 3.5 Critical Input]
         ↓
Round 4: Final Consensus
         ↓
    [Implementation Plan]
```

## Key Themes Across Documents

### Technical Consensus (All Agents Agree)
✅ Fix persistence bug first (Phase 0)
✅ Keep template system - extend don't replace
✅ Preserve thread-safe spawning (`shuttle_loading` mutex)
✅ TGUI catalog interface required
✅ Database persistence over savefiles (user validated)
✅ Rarity tier system (user mandated)

### Evolution of Positions
- **Faction Parts:** Initially kept → User eliminated → Rarity tiers
- **Persistence:** Savefiles → Database (user decision)
- **Parts Model:** Consumable → Permanent unlock currency
- **Antag Ships:** Unclear → Two-scale per-round purchase system

### Major Pivots After User Input
1. **Round 3 → Round 3.5:** Faction parts completely eliminated
2. **Round 3 → Round 3.5:** Savefile persistence rejected, database mandated
3. **Round 3 → Round 3.5:** Digital parts → Physical parts with extraction
4. **Round 3 → Round 3.5:** Simple antag system → Two-scale (large/small)

## Implementation Status

**Current Phase:** Architecture finalized, awaiting Agent D's Round 4 verdict

**Next Steps:**
1. Complete Agent D's final consensus
2. Synthesize unified implementation plan
3. Coordinate with feature teams (Battlepass, Custom Roles, Automation)
4. Begin Phase 0 (database schema + persistence fix)

## Reference Documents

**Original Analysis Documents:**
- `current-state-doc-A.md` - Agent A's system analysis
- `current-state-doc-B.md` - Agent B's system analysis
- `current-state-doc-C.md` - Agent C's system analysis
- `current-state-doc-D.md` - Agent D's system analysis

**User Input Documents:**
- `user-decision-points.md` - Initial 5 questions
- `combined-agent-questions.md` - Round 3.5 comprehensive questions

## Document Reading Guide

### For Developers
**Recommended reading order:**
1. Start with this index (you're here)
2. Read [User Decisions - Round 3.5](ship-system-user-decisions.md) for final requirements
3. Read [Round 4: Final Consensus](ship-system-round4-consensus.md) for implementation plan
4. Reference [Round 1-2](ship-system-round1-2-analysis.md) for technical details as needed

### For Project Managers
**Recommended reading order:**
1. This index for overview
2. [User Decisions - Round 3.5](ship-system-user-decisions.md) for scope
3. [Round 4: Final Consensus](ship-system-round4-consensus.md) for timeline and phases

### For Designers
**Recommended reading order:**
1. This index for context
2. [User Decisions - Round 3.5](ship-system-user-decisions.md) for approved design
3. [Round 3: Proposals](ship-system-round3-proposals.md) for alternative approaches considered

### For Complete Understanding
Read all documents in order:
1. Master Index (this file)
2. Round 1-2: Analysis & Debates
3. Round 3: Architectural Proposals
4. User Decisions - Round 3.5
5. Round 4: Final Consensus

---

## Key Statistics

- **Total Discussion Length:** ~4900 lines
- **Agents Involved:** 4 (A, B, C, D)
- **Rounds of Discussion:** 4
- **User Decision Points:** 26+ questions answered
- **Implementation Phases:** 7 (0-6)
- **Estimated Timeline:** 16 weeks (Agent C's proposal)

---

## Quick Reference: Final System Design

**Economic Model:** Credits → Parts (rarity tiers) → Blueprints → Ships
- **Credits:** Persistent, account-bound, earned via rounds/activities
- **Parts:** Physical items (basic/advanced/rare/superior), craftable/lootable
- **Blueprints:** Permanent account-wide unlocks
- **Ships:** One spawn per round per player

**Persistence:** SQL database (not savefiles)
- Account-wide blueprint unlocks
- Per-character credit balances
- Audit trails for all transactions

**Ship Types:**
- **Regular Ships:** Permanent unlocks via part crafting
- **Antag Ships:** Per-round purchases (large scale / small scale)

**Integration Dependencies:**
- Battlepass feature team (part rewards)
- Custom Roles feature team (job customization)
- Automation feature team (crafting system)

---

**Document Version:** 1.0
**Last Updated:** [Current Date]
**Status:** Round 4 in progress (awaiting Agent D)
