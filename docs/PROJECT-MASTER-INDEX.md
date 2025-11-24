# Ship Purchase System Project - Master Index

**Project:** Voidcrew Ship Purchase System Complete Redesign
**Status:** Multi-agent consensus complete, feature teams ready to spawn
**Total Documents:** 35+ markdown files
**Last Updated:** 2025-11-23

---

## Project Overview

A comprehensive redesign of the ship purchase system using multi-agent consensus architecture, incorporating:
- Main ship purchase system (4 agents, consensus complete)
- Three major new features (12+ agents, ready to spawn)
- Integration planning (10 agents)
- Creative review (4 agents)

**Total Architecture:** 30-38 agents coordinated across multiple teams

---

## Quick Start Guide

### New to This Project?
1. Read this index (you're here)
2. Read [QUICK-START-SHIP-SYSTEM-DOCS.md](QUICK-START-SHIP-SYSTEM-DOCS.md)
3. Read [ship-system-user-decisions.md](ship-system-user-decisions.md) - CRITICAL REQUIREMENTS

### Ready to Implement?
1. [ship-system-user-decisions.md](ship-system-user-decisions.md) - Requirements
2. [ship-system-round4-consensus.md](ship-system-round4-consensus.md) - Implementation plan
3. [integration-synthesis-plan.md](integration-synthesis-plan.md) - Cross-team coordination

### Spawning Feature Teams?
1. [MULTI-AGENT-SETUP-COMPLETE.md](MULTI-AGENT-SETUP-COMPLETE.md) - Setup overview
2. [agent-spawn-instructions.md](agent-spawn-instructions.md) - Step-by-step spawning guide
3. Feature team documents (see below)

---

## Document Categories

## 1. START HERE - Navigation & Overview

| Document | Lines | Status | Purpose |
|----------|-------|--------|---------|
| **[PROJECT-MASTER-INDEX.md](PROJECT-MASTER-INDEX.md)** | - | Active | THIS FILE - Complete project navigation |
| **[QUICK-START-SHIP-SYSTEM-DOCS.md](QUICK-START-SHIP-SYSTEM-DOCS.md)** | 74 | Active | Fast orientation to ship system docs |
| **[ship-system-master-index.md](ship-system-master-index.md)** | 231 | Active | Main ship system navigation hub |
| **[MULTI-AGENT-SETUP-COMPLETE.md](MULTI-AGENT-SETUP-COMPLETE.md)** | 288 | Active | Multi-agent architecture overview |
| **[SHIP-SYSTEM-REORGANIZATION-SUMMARY.md](SHIP-SYSTEM-REORGANIZATION-SUMMARY.md)** | 245 | Active | Documentation reorganization summary |

**Read These First:** Start with PROJECT-MASTER-INDEX (this file), then QUICK-START for rapid orientation.

---

## 2. Main Ship System - Consolidated Documents

### Primary Documents (USE THESE)

| Document | Lines | Status | Purpose |
|----------|-------|--------|---------|
| **[ship-system-round1-2-analysis.md](ship-system-round1-2-analysis.md)** | 1,078 | Complete | Initial analysis, debates, first user decisions |
| **[ship-system-round3-proposals.md](ship-system-round3-proposals.md)** | 2,170 | Complete | All architectural proposals from 4 agents |
| **[ship-system-user-decisions.md](ship-system-user-decisions.md)** | 373 | Complete | CRITICAL - 21 answered questions, final requirements |
| **[ship-system-round4-consensus.md](ship-system-round4-consensus.md)** | 1,440 | Complete | Final consensus, implementation plan, database schema |

**Reading Order:** Round 1-2 → Round 3 → User Decisions → Round 4

**Key Discoveries:**
- Critical bug: `ships_owned` never loads from savefiles
- Rarity tier system (basic/advanced/rare/superior) replaces faction parts
- Database persistence (SQL) chosen over savefiles
- Physical parts system with extraction device
- Two-scale antag ships (large/small)

---

### Legacy/Archived Documents (Reference Only)

| Document | Lines | Status | Purpose |
|----------|-------|--------|---------|
| [agent-consensus-discussion.md](agent-consensus-discussion.md) | 4,901 | Archived | ORIGINAL - Split into 4 documents above |
| [agent-consensus-discussion-temp.md](agent-consensus-discussion-temp.md) | 4,901 | Delete | Temporary backup copy |
| [current-state-doc-A.md](current-state-doc-A.md) | ~500 | Archived | Agent A's initial analysis (now in round1-2) |
| [current-state-doc-B.md](current-state-doc-B.md) | ~500 | Archived | Agent B's initial analysis (now in round1-2) |
| [current-state-doc-C.md](current-state-doc-C.md) | ~300 | Archived | Agent C's initial analysis (now in round1-2) |
| [current-state-doc-D.md](current-state-doc-D.md) | ~200 | Archived | Agent D's initial analysis (now in round1-2) |
| [agent-a-round3-proposal.md](agent-a-round3-proposal.md) | ~500 | Archived | Agent A's proposal (now in round3-proposals) |
| [agent-b-round3-proposal.md](agent-b-round3-proposal.md) | ~5 | Archived | Stub file (now in round3-proposals) |
| [agent-a-round4-verdict.md](agent-a-round4-verdict.md) | ~800 | Archived | Agent A's verdict (now in round4-consensus) |
| [agent-d-final-verdict.md](agent-d-final-verdict.md) | ~2,500 | Archived | Agent D's verdict (now in round4-consensus) |

**Note:** All content from archived documents is preserved in the consolidated files. Originals kept for historical reference.

---

## 3. User Input & Decisions

| Document | Lines | Status | Purpose |
|----------|-------|--------|---------|
| **[ship-system-user-decisions.md](ship-system-user-decisions.md)** | 373 | Complete | Round 3.5 critical decisions (21 questions) |
| **[combined-agent-questions.md](combined-agent-questions.md)** | 555 | Complete | All agent questions combined (source for user-decisions) |
| [user-decision-points.md](user-decision-points.md) | ~150 | Archived | Initial 5 questions (now in round1-2-analysis) |
| [agent-a-questions.md](agent-a-questions.md) | ~200 | Archived | Agent A's questions (now in combined) |
| [agent-c-questions.md](agent-c-questions.md) | ~200 | Archived | Agent C's questions (now in combined) |
| [agent-d-questions.md](agent-d-questions.md) | ~250 | Archived | Agent D's questions (now in combined) |

**Critical File:** [ship-system-user-decisions.md](ship-system-user-decisions.md) - This is the authoritative requirements document.

---

## 4. Feature Teams - Ready to Spawn

### Battlepass + XP System

| Document | Status | Purpose |
|----------|--------|---------|
| **[feature-battlepass-xp-system.md](feature-battlepass-xp-system.md)** | Ready | 4 agents (BP-A, BP-B, BP-C, BP-D) |

**Scope:**
- XP earning mechanics
- Battlepass structure (levels, rewards, seasons)
- Monkestation's monkecoin integration
- Ship parts as battlepass rewards
- Database schema for XP tracking

**User Requirements:**
- "we will need an xp system for the battlepass"
- Integration with persistent credits
- Round-end rewards modification

---

### Custom Roles + Equipment Marketplace

| Document | Status | Purpose |
|----------|--------|---------|
| **[feature-custom-roles-equipment.md](feature-custom-roles-equipment.md)** | Ready | 4 agents (CR-A, CR-B, CR-C, CR-D) |

**Scope:**
- HEAVY FEATURE with full TGUI interfaces
- Ship upgrade menu (per-ship customization)
- Role slot count customization
- Custom role builder
- Equipment marketplace (OOC market)
- Per-slot equipment selection
- Persistent storage in database

**User Requirements:**
- "This would have to be a HEAVY feature with a full ui for this"
- Buy ninja gear + 3x cowboy gear for custom slots
- Based on Monkestation's monkecoin
- Full per-character-slot customization

**Estimated Timeline:** 20-30 weeks (most complex feature)

---

### Automation Crafting Minigame

| Document | Status | Purpose |
|----------|--------|---------|
| **[feature-automation-crafting.md](feature-automation-crafting.md)** | Ready | 4 agents (AUTO-A, AUTO-B, AUTO-C, AUTO-D) |

**Scope:**
- Factorio/Satisfactory-style automation
- Factory building for ship parts crafting
- Variable complexity (simple → complex to be determined)
- Integration with ship parts economy
- Resource chains and production lines

**User Requirements:**
- "I want a factorio / satisfactory like minigame for ship parts"
- Automation for crafting ship parts
- Scope to be determined by agent team

**Estimated Timeline:** 10-40 weeks (depends on scope choice)

---

## 5. Planning & Coordination

### Integration Planning

| Document | Status | Purpose |
|----------|--------|---------|
| **[integration-synthesis-plan.md](integration-synthesis-plan.md)** | Ready | 10 agents across 5 teams |

**Integration Teams:**
- Database Schema (2 agents) - Unified SQL schema
- Economy Balance (2 agents) - Credit pricing across all systems
- Ship System (2 agents) - Ship spawn flow integration
- UI/UX Consistency (2 agents) - TGUI design system
- Master Planning (2 agents) - Unified timeline

**Purpose:** Ensure all feature teams integrate cohesively without conflicts.

---

### Creative Review

| Document | Status | Purpose |
|----------|--------|---------|
| **[creative-review-plan.md](creative-review-plan.md)** | Ready | 4 creative agents |

**Creative Agent Roles:**
- CREATIVE-A: Systems integration specialist
- CREATIVE-B: Player experience designer
- CREATIVE-C: Feature completeness analyst
- CREATIVE-D: Complexity amplifier

**User Requirements:**
- "I dont want to shy away from complexity"
- Identify integration opportunities
- Make ideas more interesting
- Add features to round out

---

### Orchestration & Workflow

| Document | Status | Purpose |
|----------|--------|---------|
| **[agent-spawn-instructions.md](agent-spawn-instructions.md)** | Ready | Step-by-step spawning guide |
| [agent-orchestration-plan.md](agent-orchestration-plan.md) | Archived | Early planning (now in spawn-instructions) |
| [agent-qa-workflow.md](agent-qa-workflow.md) | Archived | Early QA planning |

**Use:** [agent-spawn-instructions.md](agent-spawn-instructions.md) for spawning all teams.

---

## 6. Planning Notes & Future Topics

| Document | Status | Purpose |
|----------|--------|---------|
| [future-discussion-topics.md](future-discussion-topics.md) | Reference | Database, creative review, task breakdown notes |
| [round3-summary-for-user.md](round3-summary-for-user.md) | Archived | Summary for user (now in round3-proposals) |
| [ship-persistence-scalability-analysis.md](ship-persistence-scalability-analysis.md) | Reference | Persistence analysis |

---

## 7. Codebase Documentation (Non-Project)

| Document | Purpose |
|----------|---------|
| [README.md](README.md) | Voidcrew codebase README |
| [CLAUDE.local.md](CLAUDE.local.md) | Claude Code local configuration |
| [migration_status.md](migration_status.md) | Migration tracking |

**Note:** These are codebase docs, not part of the ship purchase project.

---

## Key System Requirements Summary

### Economic Model
```
Round Play → Credits → Ship Parts (rarity tiers) → Blueprints → Ships
                ↓
           Battlepass → XP → Rewards
                ↓
     Equipment Market → Custom Roles
                ↓
          Automation → Part Crafting
```

### Persistence Architecture
- **Database:** SQL (not savefiles)
- **Account-wide:** Blueprint unlocks, XP, battlepass progress
- **Per-character:** Credit balance
- **No migration needed:** Server not live

### Ship Parts System
- **Rarity Tiers:** Basic / Advanced / Rare / Superior
- **NOT faction-specific:** Eliminated faction parts
- **Physical items:** Found in world (ruins, planets)
- **Extraction device:** Required to deposit into account
- **One-time unlock:** Parts unlock blueprints permanently

### Antag Ships
- **Two scales:** Large (multi-crew) and Small (solo)
- **Per-round purchase:** No unlock step
- **Direct buy:** Pay parts each round to spawn

### Credits
- **Account-bound:** Cannot trade between players
- **Per-character balance:** Each slot has separate credits
- **Earning:** 100 credits per round + battlepass + activities
- **Spending:** Buy parts, equipment, custom roles

---

## Implementation Phases

### Phase 0: Foundation (Database + Bug Fix)
- Fix `ships_owned` persistence bug
- Implement database schema
- Migration from savefiles

### Phase 1: Core Ship System (10-12 weeks)
- TGUI catalog interface
- Credit economy
- Blueprint unlock system
- Basic ship spawning

### Phase 2: Parts & Progression (4-6 weeks)
- Rarity tier system
- Physical parts + extraction
- Parts discovery in world

### Phase 3: Antag Ships (3-4 weeks)
- Large scale antag ships
- Small scale antag ships
- Per-round purchase flow

### Phase 4: Battlepass (10-15 weeks)
- XP system
- Battlepass structure
- Rewards integration

### Phase 5: Custom Roles (20-30 weeks)
- Equipment marketplace
- Role builder TGUI
- Ship upgrade menu
- Per-slot customization

### Phase 6: Automation (10-40 weeks)
- Factory building system
- Part crafting automation
- (Scope dependent)

**Total Estimated Timeline:** 40-50+ weeks (overlapping phases)

---

## Agent Team Breakdown

| Team | Agents | Status | Document |
|------|--------|--------|----------|
| Main Ship | A, B, C, D (4) | Complete ✅ | ship-system-round4-consensus.md |
| Battlepass | BP-A, BP-B, BP-C, BP-D (4) | Ready to spawn | feature-battlepass-xp-system.md |
| Custom Roles | CR-A, CR-B, CR-C, CR-D (4) | Ready to spawn | feature-custom-roles-equipment.md |
| Automation | AUTO-A, AUTO-B, AUTO-C, AUTO-D (4) | Ready to spawn | feature-automation-crafting.md |
| Creative Review | CREATIVE-A, B, C, D (4) | Ready to spawn | creative-review-plan.md |
| Integration Teams | 10 agents (5 teams of 2) | Ready to spawn | integration-synthesis-plan.md |
| Detail Teams | 4-8 agents (optional) | As needed | Various |

**Total:** 30-38 agents

---

## Recommended Reading Paths

### For Project Managers
1. [PROJECT-MASTER-INDEX.md](PROJECT-MASTER-INDEX.md) (this file)
2. [ship-system-user-decisions.md](ship-system-user-decisions.md) - Scope & requirements
3. [ship-system-round4-consensus.md](ship-system-round4-consensus.md) - Implementation plan
4. [integration-synthesis-plan.md](integration-synthesis-plan.md) - Coordination strategy

### For Developers
1. [QUICK-START-SHIP-SYSTEM-DOCS.md](QUICK-START-SHIP-SYSTEM-DOCS.md)
2. [ship-system-user-decisions.md](ship-system-user-decisions.md) - Requirements
3. [ship-system-round4-consensus.md](ship-system-round4-consensus.md) - Database schema & roadmap
4. [ship-system-round1-2-analysis.md](ship-system-round1-2-analysis.md) - Technical details

### For Feature Team Leaders
1. [MULTI-AGENT-SETUP-COMPLETE.md](MULTI-AGENT-SETUP-COMPLETE.md)
2. [agent-spawn-instructions.md](agent-spawn-instructions.md)
3. Your feature document:
   - [feature-battlepass-xp-system.md](feature-battlepass-xp-system.md)
   - [feature-custom-roles-equipment.md](feature-custom-roles-equipment.md)
   - [feature-automation-crafting.md](feature-automation-crafting.md)

### For Complete Understanding
1. [PROJECT-MASTER-INDEX.md](PROJECT-MASTER-INDEX.md) (this file)
2. [ship-system-master-index.md](ship-system-master-index.md)
3. [ship-system-round1-2-analysis.md](ship-system-round1-2-analysis.md)
4. [ship-system-round3-proposals.md](ship-system-round3-proposals.md)
5. [ship-system-user-decisions.md](ship-system-user-decisions.md)
6. [ship-system-round4-consensus.md](ship-system-round4-consensus.md)
7. All 3 feature team documents
8. [integration-synthesis-plan.md](integration-synthesis-plan.md)
9. [creative-review-plan.md](creative-review-plan.md)

---

## Document Status Legend

| Status | Meaning |
|--------|---------|
| **Active** | Currently in use, primary reference |
| **Complete** | Finished, authoritative content |
| **Ready** | Template ready for agent teams to fill |
| **Archived** | Historical reference, content moved to consolidated docs |
| **Delete** | Temporary file, can be removed |
| **Reference** | Supporting notes, not primary documentation |

---

## Cleanup Recommendations

### Safe to Archive (Move to `docs/archive/` folder)
- agent-consensus-discussion.md (content in split files)
- current-state-doc-A.md through D.md (content in round1-2)
- agent-a-round3-proposal.md (content in round3-proposals)
- agent-a-round4-verdict.md (content in round4-consensus)
- agent-d-final-verdict.md (content in round4-consensus)
- user-decision-points.md (content in round1-2-analysis)
- agent-a-questions.md, agent-c-questions.md, agent-d-questions.md (content in combined-agent-questions)
- agent-orchestration-plan.md (content in spawn-instructions)
- agent-qa-workflow.md (early planning doc)
- round3-summary-for-user.md (content in round3-proposals)

### Safe to Delete
- agent-consensus-discussion-temp.md (duplicate backup)
- agent-b-round3-proposal.md (stub file, no content)

### Keep Active
- All ship-system-*.md files (primary documentation)
- All feature-*.md files (ready for teams)
- integration-synthesis-plan.md
- creative-review-plan.md
- agent-spawn-instructions.md
- combined-agent-questions.md
- MULTI-AGENT-SETUP-COMPLETE.md
- QUICK-START-SHIP-SYSTEM-DOCS.md
- ship-system-master-index.md
- PROJECT-MASTER-INDEX.md (this file)

---

## Missing Documentation (Potential Gaps)

### Not Yet Created
- Master timeline Gantt chart
- Database ERD diagram
- TGUI component hierarchy
- Dependency graph between features
- Testing strategy document
- Deployment plan

### To Be Created by Feature Teams
- Battlepass: XP earning mechanics, reward tables
- Custom Roles: Equipment catalog, role templates
- Automation: Factory building mechanics, recipe trees

### Integration Documents (After Teams Finish)
- Unified database schema
- Cross-feature economy balance
- Master implementation roadmap
- TGUI design system guide

---

## Next Steps

### Immediate (This Week)
1. ✅ Create PROJECT-MASTER-INDEX.md (this file)
2. Review and confirm folder structure
3. Archive old documents (see Cleanup Recommendations)
4. Create docs/archive/ folder if using

### Short-term (Next 1-2 Weeks)
1. Spawn Battlepass team (4 agents)
2. Spawn Custom Roles team (4 agents)
3. Spawn Automation team (4 agents)
4. Let teams complete Round 1-4 consensus

### Medium-term (3-4 Weeks)
1. Spawn Integration teams (10 agents)
2. Spawn Creative Review team (4 agents)
3. Synthesize all team outputs
4. Create unified master plan

### Long-term (1-2 Months)
1. Begin Phase 0 implementation (database + bug fix)
2. Set up testing infrastructure
3. Create detailed task breakdown
4. Assign implementation tasks to agents

---

## Project Statistics

- **Total Documents Created:** 35+
- **Lines of Documentation:** ~15,000+
- **Agents Involved:** 4 complete, 30-38 total planned
- **User Decision Points:** 26+ questions answered
- **Implementation Phases:** 7 (0-6)
- **Estimated Timeline:** 40-50+ weeks
- **Lines of Code (Estimated):** 20,000+ lines for complete system

---

## Contact & Collaboration

**User:** isaac
**Project Start:** 2025-11-23
**Current Phase:** Feature team spawning ready
**Main Decision Authority:** User (all major decisions documented in ship-system-user-decisions.md)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-23 | Initial master index created |

---

**This is the authoritative navigation document for the entire ship purchase system redesign project.**

For questions or updates, modify this file and update the version history.
