# Automation Crafting Minigame - Feature Design

**Status:** Initial context document for 4-agent team

**Parent Project:** Ship Purchase System Redesign

**Feature Team:** Automation Team (Agents AUTO-A, AUTO-B, AUTO-C, AUTO-D)

---

## Feature Overview

Design and implement a Factorio/Satisfactory-style automation minigame for crafting ship parts, integrated with the ship purchase economy.

### User Requirements (from combined-agent-questions.md Q15)

**Core Concept:**
> "I want a factorio / satisfactory like minigame for ship parts that allows you to use automation to craft them."

**Inspiration:**
- Factorio: conveyor belts, assemblers, resource chains, automation
- Satisfactory: 3D factory building, resource extraction, production lines

**Context:**
- User wants ship parts craftable through automation
- Parts can also be found in world (ruins, planets)
- Parts have rarity tiers: basic/advanced/rare/superior
- Parts unlock ship blueprints permanently

---

## Known Context from Main Ship System

### What the Main Team Already Decided

**Persistence:**
- Database-backed (not savefiles)
- Account-wide unlocks, per-character currency
- No migration needed (server not live)

**Economy:**
- Credits = persistent currency (account-bound, not tradeable)
- 100 credits per round baseline
- Ship parts = physical world items until extracted

**Parts System:**
- Rarity tiers: basic/advanced/rare/superior (NOT faction-specific)
- Parts unlock ship blueprints permanently
- Parts can be found in world (ruins, planets)
- Need extraction device to deposit into account
- Selling parts for credits (varies by rarity)

**Crafting Context (from Q15 & Q10):**
- Ship parts are craftable
- Parts can be found scattered across galaxy
- Parts are physical items in world
- Extraction device needed to deposit into account

**Round-End Rewards:**
- 1 part + 100 credits per round
- Battlepass can grant parts as rewards

---

## Design Questions for Automation Team

### Critical Questions

1. **Automation Scope - How Deep?**
   - Simple crafting benches? (click button, wait, get part)
   - Conveyor belts + assemblers? (Factorio-style)
   - 3D factory building? (Satisfactory-style)
   - Power requirements, logistics, resource chains?

2. **Per-Round vs Persistent**
   - Is automation per-round only? (build factory each round)
   - Or persistent across rounds? (factory saves, continues producing)
   - If persistent, where is the factory? (player station? ship-based? separate dimension?)

3. **Resource Inputs**
   - What raw materials are needed to craft parts?
   - Mining ore/materials? (existing mining system)
   - Salvaging wrecks?
   - Trading for materials?
   - Starting resources vs gathered resources?

4. **Part Crafting Complexity**
   - Basic parts: simple recipe (iron + plasma = basic part)
   - Advanced parts: multi-step chain (iron → plates → circuits → advanced part)
   - Rare parts: complex chains with rare materials
   - Superior parts: extremely complex, long production chains

5. **Integration with Ship System**
   - Do you craft parts ON your ship?
   - Or at a separate factory location?
   - Can you automate while flying/exploring?
   - Is crafting passive income (AFK production) or active gameplay?

6. **Automation Buildings/Machines**
   - What machines exist?
     - Miners/extractors?
     - Assemblers/crafters?
     - Conveyor belts/logistics?
     - Storage containers?
     - Power generators?
   - How are they built/placed?
   - Do they cost resources to build?

7. **Factorio vs Satisfactory Balance**
   - 2D tile-based (Factorio) or 3D free-form (Satisfactory)?
   - BYOND's engine limitations (top-down 2D)
   - Complexity vs feasibility
   - TGUI interface or in-game map interaction?

8. **Power & Logistics**
   - Do machines need power?
   - Power generation systems?
   - Conveyor networks?
   - Resource transportation?
   - Bottlenecks and optimization gameplay?

### Important Questions

9. **Production Speed & Balance**
   - How long to craft a basic part? (seconds? minutes? hours?)
   - How does automation speed compare to finding parts in world?
   - How does it compare to buying parts with credits?
   - Is automation faster but requires investment?

10. **Blueprints & Unlocks**
    - Do you need to unlock automation machines?
    - Blueprint system for factory designs?
    - Can you share factory blueprints with others?
    - Progressive unlocks (start with basic assemblers, unlock advanced ones)?

11. **Database Persistence**
    - Factory state storage (machine placements, configurations)
    - Resource inventory in factory
    - Production queues
    - Automation blueprints/templates
    - Per-round snapshots or continuous state?

12. **UI/UX Design**
    - Factory builder interface (TGUI or in-game map?)
    - Machine configuration screens
    - Resource flow visualization
    - Production statistics
    - Blueprint designer?

13. **Material Sources**
    - Mining (existing system integration)
    - Salvaging wrecks
    - Trading
    - Exploring planets
    - Mission rewards
    - Starting materials per round?

14. **Anti-AFK Farming**
    - How to prevent AFK automation farming?
    - Resource caps?
    - Maintenance requirements?
    - Active player checks?
    - Diminishing returns?

15. **Complexity Tiers**
    - MVP: Basic crafting benches (no automation)
    - Phase 1: Simple automation (place machines, they produce)
    - Phase 2: Logistics (conveyors, resource chains)
    - Phase 3: Optimization (power, efficiency, blueprints)

---

## Constraints from Main System

**Must Preserve:**
- Database persistence architecture
- Credit economy (automation can't trivialize progression)
- Ship parts rarity system (basic/advanced/rare/superior)
- Parts as physical world items

**Must Integrate With:**
- Ship part extraction system (crafted parts → extracted to account)
- Mining/resource gathering (materials for automation)
- Round-end rewards (automation doesn't replace, complements)

**Must Not Conflict With:**
- Battlepass system (separate feature team)
- Custom roles + equipment (separate feature team)
- Core ship unlock system (main team)

**Balance Constraints:**
- Automation shouldn't make finding parts obsolete
- Automation shouldn't make buying parts with credits obsolete
- Should be alternative path, not superior path
- Investment (time/resources) vs reward (parts produced)

---

## Success Criteria

**Automation Team Must Deliver:**

1. **Automation System Design**
   - Scope definition (how Factorio-like? how complex?)
   - Machines/buildings catalog
   - Resource flow system
   - Power/logistics design (if applicable)
   - Production recipes for each part rarity

2. **Integration Plan**
   - How automation fits in ship part economy
   - Material sourcing (mining, salvaging, etc.)
   - Factory location (ship-based? station? separate?)
   - Per-round vs persistent factory state
   - Database schema for factory persistence

3. **UI/UX Specifications**
   - Factory builder interface
   - Machine configuration
   - Production monitoring
   - Blueprint system (if applicable)

4. **Balance Model**
   - Production speed vs finding parts
   - Resource costs vs credit costs
   - Time investment vs reward
   - Anti-AFK measures

5. **Implementation Roadmap**
   - Phased delivery (MVP → Full Automation)
   - Complexity tiers
   - Dependencies on main ship system
   - Timeline estimates

---

## Round 1-4 Process for Automation Team

### Round 1: Analysis
**Agents AUTO-A, AUTO-B, AUTO-C, AUTO-D each independently:**
- Analyze user requirements (Factorio/Satisfactory inspiration)
- Research BYOND's capabilities for automation systems
- Propose automation scope (simple vs complex)
- Identify integration points with ship part economy
- Document findings and initial thoughts

### Round 2: Disagreements & Gaps
**Agents discuss and debate:**
- Points of disagreement (scope/complexity!)
- Missing information or gaps
- Findings that surprised them
- Alignment and readiness for proposals

### Round 3: Architectural Proposals
**Each agent proposes:**
- Complete automation system design
- Machine/building catalog
- Resource chains and recipes
- UI/UX specifications
- Database schema
- Integration with ship system
- Phased implementation plan

### Round 4: Consensus
**Agents synthesize:**
- Final recommended approach
- Tradeoffs and compromises (simplicity vs depth)
- Implementation priorities
- Open questions for user

---

## Agent Team Instructions

**Automation Agents (AUTO-A, AUTO-B, AUTO-C, AUTO-D):**

You are designing an **Automation Crafting Minigame** for ship parts. User wants Factorio/Satisfactory-style automation.

**Your Scope:**
- Automation system design (machines, conveyors, resource chains)
- Part crafting recipes (basic/advanced/rare/superior)
- Factory building interface
- Resource sourcing (mining, salvaging, etc.)
- Database persistence for factory state
- Balance model (automation vs finding vs buying parts)

**User Guidance:**
- User wants "Factorio / Satisfactory like minigame"
- User wants **no loss of complexity** - embrace rich, interconnected systems
- Ship parts can be crafted through automation
- Parts have rarity tiers (basic/advanced/rare/superior)

**Key Context:**
- Main ship system uses DATABASE persistence
- Ship parts are physical items in world until extracted
- Parts unlock ship blueprints permanently
- Round-end rewards: 1 part + 100 credits
- Mining system already exists in codebase

**Critical Design Decision:**
- **How Factorio-like?** This dramatically affects scope
  - Simple: crafting benches (weeks)
  - Medium: machines + basic automation (months)
  - Complex: full conveyor networks, power, logistics (many months)

**Key Design Questions:**
- Per-round factory or persistent across rounds?
- Factory on ship, at station, or separate location?
- 2D tile-based or 3D (BYOND limitations)?
- What machines/buildings?
- Power requirements?
- Resource chains (how complex)?
- TGUI interface or in-game map interaction?

**Deliverables:**
- Round 1-4 consensus (same process as main ship team)
- Complete automation system design
- Machine/building catalog
- Resource recipes
- UI/UX specifications
- Database schema
- Balance model
- Implementation roadmap with complexity tiers

**Constraints:**
- Must work with database persistence
- Must integrate with ship part economy
- Automation can't trivialize other progression paths
- Must balance investment vs reward
- Must align with main ship system timeline

**Important Guidance:**
- Propose **multiple complexity tiers** (MVP vs Full)
- User can choose how deep to go
- Start with Round 1 analysis of feasibility vs scope

**Start with Round 1:** Each agent analyzes independently and documents findings.

---

## Consensus Discussion Template

Use this section for Round 1-4 discussions:

---

### Round 1: Initial Analysis

#### Agent AUTO-A Analysis
[Agent AUTO-A: Analyze automation minigame requirements. Research Factorio/Satisfactory mechanics. Assess BYOND's capabilities for automation. Propose scope (simple vs complex). Document findings.]

#### Agent AUTO-B Analysis
[Agent AUTO-B: Analyze automation minigame requirements. Research Factorio/Satisfactory mechanics. Assess BYOND's capabilities for automation. Propose scope (simple vs complex). Document findings.]

#### Agent AUTO-C Analysis
[Agent AUTO-C: Analyze automation minigame requirements. Research Factorio/Satisfactory mechanics. Assess BYOND's capabilities for automation. Propose scope (simple vs complex). Document findings.]

#### Agent AUTO-D Analysis
[Agent AUTO-D: Analyze automation minigame requirements. Research Factorio/Satisfactory mechanics. Assess BYOND's capabilities for automation. Propose scope (simple vs complex). Document findings.]

---

### Round 2: Disagreements & Gaps

#### Agent AUTO-A Response
[Points of disagreement, gaps noticed, surprising findings, alignment status]

#### Agent AUTO-B Response
[Points of disagreement, gaps noticed, surprising findings, alignment status]

#### Agent AUTO-C Response
[Points of disagreement, gaps noticed, surprising findings, alignment status]

#### Agent AUTO-D Response
[Points of disagreement, gaps noticed, surprising findings, alignment status]

---

### Round 3: Architectural Proposals

#### Agent AUTO-A Proposal
[Complete automation design: system scope, machines, recipes, UI/UX, database schema, integration, balance, roadmap with tiers]

#### Agent AUTO-B Proposal
[Complete automation design: system scope, machines, recipes, UI/UX, database schema, integration, balance, roadmap with tiers]

#### Agent AUTO-C Proposal
[Complete automation design: system scope, machines, recipes, UI/UX, database schema, integration, balance, roadmap with tiers]

#### Agent AUTO-D Proposal
[Complete automation design: system scope, machines, recipes, UI/UX, database schema, integration, balance, roadmap with tiers]

---

### Round 4: Final Consensus

#### Agent AUTO-A Final Verdict
[Support which proposal? Compromises? Non-negotiables? Final recommendation]

#### Agent AUTO-B Final Verdict
[Support which proposal? Compromises? Non-negotiables? Final recommendation]

#### Agent AUTO-C Final Verdict
[Support which proposal? Compromises? Non-negotiables? Final recommendation]

#### Agent AUTO-D Final Verdict
[Support which proposal? Compromises? Non-negotiables? Final recommendation]

---

### Final Automation Design (Consensus)

[To be filled after Round 4]

#### Automation System Scope
[Final scope: simple crafting, medium automation, or complex factory system]

#### Machines & Buildings
[Final catalog of automation machines/buildings]

#### Resource Chains & Recipes
[Final crafting recipes for basic/advanced/rare/superior parts]

#### Factory Persistence
[Per-round or persistent? Location? State storage?]

#### UI/UX Specifications
[Final interface designs for factory building, configuration, monitoring]

#### Database Schema
[Final schema additions for factory state, resources, blueprints]

#### Balance Model
[Production speed, resource costs, time investment, anti-AFK measures]

#### Integration Plan
[How automation integrates with ship part economy, mining, exploration]

#### Implementation Roadmap
[Phases with complexity tiers: MVP → Medium → Full, timeline, dependencies]

#### Open Questions
[Questions for user or other teams]

---

## Integration Points with Other Teams

**Main Ship System Team:**
- Ship part economy (automation as alternative acquisition path)
- Mining/resource systems (material sources)
- Extraction device (crafted parts → account deposit)
- Database schema coordination
- Balance: automation vs buying vs finding parts

**Battlepass Team:**
- Does battlepass grant automation blueprints?
- Does battlepass grant crafting materials?
- XP from automation activities?
- Crafting parts as battlepass objectives?

**Custom Roles Team:**
- Can you craft equipment in addition to parts?
- Automation-specialized roles?
- Equipment for automation bonuses?

**Creative Review Team:**
- Review automation for engagement vs tedium
- Suggest ways to make factory building rewarding
- Balance complexity vs accessibility
- Identify synergies with exploration/mining

---

## User Notes & Clarifications

**Factorio/Satisfactory Inspiration:**
- Both games feature extensive automation
- Conveyor belts, assemblers, resource chains
- Progressive complexity (start simple, build complex)
- Optimization as core gameplay loop

**BYOND Limitations:**
- Top-down 2D engine
- May not support full 3D factory building
- Consider 2D tile-based Factorio style more feasible
- TGUI can provide advanced interfaces

**Scope Considerations:**
- Full Factorio-clone may be many months of development
- Consider phased approach: simple → complex
- MVP could be basic crafting benches
- Expand to automation in later phases

*[Additional user context can be added here]*

---

**Status:** Ready for Automation Team (Agents AUTO-A, AUTO-B, AUTO-C, AUTO-D) to begin Round 1 analysis.
