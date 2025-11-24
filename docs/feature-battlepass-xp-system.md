# Battlepass + XP System - Feature Design

**Status:** Initial context document for 4-agent team

**Parent Project:** Ship Purchase System Redesign

**Feature Team:** Battlepass Team (Agents BP-A, BP-B, BP-C, BP-D)

---

## Feature Overview

Design and implement a persistent XP and battlepass system integrated with the ship purchase economy.

### User Requirements (from combined-agent-questions.md Q10, Q14)

**Core Concept:**
> "we will need an xp system for the battlepass. wow we need a whole thing on the battlepass and xp."

**Integration Points:**
- Round-end rewards: Currently 1 part + credits per round
- Ship parts can be battlepass rewards
- XP earned from rounds played
- Persistent progression across rounds

**Inspiration:**
- Monkestation's monkecoin system (user has repo downloaded)
- Persistent coins earned from round ends
- Will be expanded for custom slot feature

---

## Known Context from Main Ship System

### What the Main Team Already Decided

**Persistence:**
- Database-backed (not savefiles)
- Account-wide unlocks, per-character currency
- No migration needed (server not live)

**Economy:**
- Credits = persistent currency (account-bound, not tradeable)
- Ship parts = physical world items until extracted
- Round completion reward: 100 credits baseline

**Parts System:**
- Rarity tiers: basic/advanced/rare/superior (NOT faction-specific)
- Parts unlock ship blueprints permanently
- Parts can be found in world (ruins, planets)
- Need extraction device to deposit into account

**Round-End Rewards (Q14):**
- Keep both: 1 part + credits per round
- Battlepass can modify/enhance these rewards

---

## Design Questions for Battlepass Team

### Critical Questions

1. **XP Earning Mechanics**
   - What actions grant XP? (time played, objectives, performance, activities)
   - Linear or diminishing returns?
   - Per-round caps or unlimited?
   - Account-wide or per-character?

2. **Battlepass Structure**
   - Free track vs premium track?
   - How many levels/tiers?
   - Season-based or continuous?
   - Reset frequency (monthly, quarterly, never)?

3. **Reward Distribution**
   - What rewards at which levels?
   - Ship parts as rewards (which rarity at which levels)?
   - Credits as rewards?
   - Exclusive cosmetics/items?
   - How does this interact with round-end rewards?

4. **Integration with Ship System**
   - Does battlepass grant ship parts directly, or currency to buy parts?
   - Do battlepass rewards affect unlock progression speed?
   - Should some ships be battlepass-exclusive unlocks?

5. **Monkecoin Integration**
   - User mentioned Monkestation's monkecoin system
   - Should we adapt monkecoin or build separate?
   - How does monkecoin relate to credits vs XP vs battlepass?

6. **Database Schema**
   - XP storage per account
   - Battlepass level tracking
   - Claimed rewards tracking
   - Season/period tracking

### Important Questions

7. **XP Sources Detail**
   - Mining ore grants XP?
   - Combat/kills grant XP?
   - Exploration/discovery grants XP?
   - Trading/economy grants XP?
   - Survival time grants XP?
   - Team objectives grant XP?

8. **Progression Curve**
   - How much XP per level?
   - Exponential curve or linear?
   - Average time to max level per season?
   - Catch-up mechanics for new/returning players?

9. **UI/UX Design**
   - TGUI interface for battlepass progression view
   - In-game XP gain notifications
   - Level-up feedback
   - Unclaimed rewards indicator

10. **Anti-Exploit Measures**
    - Prevent AFK XP farming
    - Prevent round-hopping for fast rewards
    - Rate limiting
    - Detection and penalties

---

## Constraints from Main System

**Must Preserve:**
- Database persistence architecture
- Account-wide progression philosophy
- Credit economy (account-bound)
- Round-end reward structure (enhance, don't replace)

**Must Integrate With:**
- Ship parts rarity system (basic/advanced/rare/superior)
- Credit earning from rounds
- Extraction device system (for physical parts)

**Must Not Conflict With:**
- Custom roles + equipment marketplace (separate feature team)
- Automation crafting system (separate feature team)
- Core ship unlock system (main team)

---

## Success Criteria

**Battlepass Team Must Deliver:**

1. **Complete XP System Design**
   - Earning mechanics
   - Progression curve
   - Storage schema
   - Anti-exploit measures

2. **Battlepass Structure**
   - Tier/level layout
   - Reward distribution per level
   - Season structure (if applicable)
   - Free vs premium (if applicable)

3. **Integration Plan**
   - How battlepass affects round-end rewards
   - How battlepass grants ship parts
   - How monkecoin fits in (if at all)
   - Database schema additions

4. **Implementation Roadmap**
   - Phased delivery plan
   - Dependencies on main ship system
   - Timeline estimates
   - Testing strategy

5. **UI/UX Specifications**
   - TGUI battlepass viewer design
   - XP gain feedback
   - Reward claim interface

---

## Round 1-4 Process for Battlepass Team

### Round 1: Analysis
**Agents BP-A, BP-B, BP-C, BP-D each independently:**
- Analyze user requirements
- Research Monkestation's monkecoin (user has repo)
- Propose XP earning mechanics
- Identify integration points with main ship system
- Document findings and initial thoughts

### Round 2: Disagreements & Gaps
**Agents discuss and debate:**
- Points of disagreement
- Missing information or gaps
- Findings that surprised them
- Alignment and readiness for proposals

### Round 3: Architectural Proposals
**Each agent proposes:**
- Complete XP system design
- Battlepass structure and rewards
- Database schema
- Integration with ship system
- Phased implementation plan

### Round 4: Consensus
**Agents synthesize:**
- Final recommended approach
- Tradeoffs and compromises
- Implementation priorities
- Open questions for user

---

## Agent Team Instructions

**Battlepass Agents (BP-A, BP-B, BP-C, BP-D):**

You are designing the **Battlepass + XP System** for a ship purchase game. This is a **separate but integrated feature** alongside the main ship unlock system.

**Your Scope:**
- XP earning mechanics (what grants XP, how much, caps, etc.)
- Battlepass structure (levels, tiers, seasons, rewards)
- Integration with existing ship parts and credit economy
- Database persistence design
- UI/UX for battlepass progression

**User Guidance:**
- User wants **no loss of complexity** - embrace rich, interconnected systems
- User has Monkestation's monkecoin code available as reference
- Battlepass should grant ship parts as rewards (rarity tiers: basic/advanced/rare/superior)
- XP system will be used for progression tracking

**Key Context:**
- Main ship system uses DATABASE persistence (not savefiles)
- Credits are account-bound persistent currency (100 per round baseline)
- Ship parts use rarity tiers (NOT factions)
- Parts unlock blueprints permanently
- Round-end rewards: 1 part + credits (battlepass can enhance this)

**Deliverables:**
- Round 1-4 consensus (same process as main ship team)
- Complete battlepass design
- XP system mechanics
- Integration plan with main ship system
- Implementation roadmap

**Constraints:**
- Must work with database persistence
- Must integrate with credit economy
- Must not conflict with other feature teams (Custom Roles, Automation)
- Timeline should align with main ship system phases

**Start with Round 1:** Each agent analyzes independently and documents findings.

---

## Consensus Discussion Template

Use this section for Round 1-4 discussions:

---

### Round 1: Initial Analysis

#### Agent BP-A Analysis
[Agent BP-A: Analyze the battlepass feature requirements. Research monkecoin if possible. Propose initial XP mechanics and battlepass structure. Document findings.]

#### Agent BP-B Analysis
[Agent BP-B: Analyze the battlepass feature requirements. Research monkecoin if possible. Propose initial XP mechanics and battlepass structure. Document findings.]

#### Agent BP-C Analysis
[Agent BP-C: Analyze the battlepass feature requirements. Research monkecoin if possible. Propose initial XP mechanics and battlepass structure. Document findings.]

#### Agent BP-D Analysis
[Agent BP-D: Analyze the battlepass feature requirements. Research monkecoin if possible. Propose initial XP mechanics and battlepass structure. Document findings.]

---

### Round 2: Disagreements & Gaps

#### Agent BP-A Response
[Points of disagreement, gaps noticed, surprising findings, alignment status]

#### Agent BP-B Response
[Points of disagreement, gaps noticed, surprising findings, alignment status]

#### Agent BP-C Response
[Points of disagreement, gaps noticed, surprising findings, alignment status]

#### Agent BP-D Response
[Points of disagreement, gaps noticed, surprising findings, alignment status]

---

### Round 3: Architectural Proposals

#### Agent BP-A Proposal
[Complete battlepass design: XP mechanics, structure, rewards, database schema, integration, roadmap]

#### Agent BP-B Proposal
[Complete battlepass design: XP mechanics, structure, rewards, database schema, integration, roadmap]

#### Agent BP-C Proposal
[Complete battlepass design: XP mechanics, structure, rewards, database schema, integration, roadmap]

#### Agent BP-D Proposal
[Complete battlepass design: XP mechanics, structure, rewards, database schema, integration, roadmap]

---

### Round 4: Final Consensus

#### Agent BP-A Final Verdict
[Support which proposal? Compromises? Non-negotiables? Final recommendation]

#### Agent BP-B Final Verdict
[Support which proposal? Compromises? Non-negotiables? Final recommendation]

#### Agent BP-C Final Verdict
[Support which proposal? Compromises? Non-negotiables? Final recommendation]

#### Agent BP-D Final Verdict
[Support which proposal? Compromises? Non-negotiables? Final recommendation]

---

### Final Battlepass Design (Consensus)

[To be filled after Round 4]

#### XP System
[Final XP earning mechanics, progression curve, storage]

#### Battlepass Structure
[Final levels, tiers, seasons, rewards]

#### Database Schema
[Final schema additions for XP and battlepass]

#### Integration Plan
[How battlepass integrates with main ship system]

#### Implementation Roadmap
[Phases, timeline, dependencies]

#### Open Questions
[Questions for user or other teams]

---

## Integration Points with Other Teams

**Main Ship System Team:**
- Credits economy (battlepass grants credits?)
- Ship parts rewards (which rarities at which levels?)
- Round-end reward modification
- Database schema coordination

**Custom Roles Team:**
- Does battlepass grant custom role slots?
- Does battlepass grant equipment marketplace currency?
- Shared XP system or separate progression?

**Automation Crafting Team:**
- Does battlepass grant automation blueprints?
- Crafting materials as rewards?
- XP from automation activities?

**Creative Review Team:**
- Review battlepass for engagement opportunities
- Suggest ways to make progression feel rewarding
- Identify synergies with other systems

---

## User Notes & Clarifications

*[This section for user to add additional context as needed]*

---

**Status:** Ready for Battlepass Team (Agents BP-A, BP-B, BP-C, BP-D) to begin Round 1 analysis.
