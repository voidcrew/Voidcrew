# Custom Roles + Equipment Marketplace - Feature Design

**Status:** Initial context document for 4-agent team

**Parent Project:** Ship Purchase System Redesign

**Feature Team:** Custom Roles Team (Agents CR-A, CR-B, CR-C, CR-D)

---

## Feature Overview

Design and implement a custom role creation system with an equipment marketplace, allowing players to purchase and customize ship crew loadouts using persistent credits.

### User Requirements (from combined-agent-questions.md Q12)

**Core Concept:**
> "Okay check it - we allow you to purchase custom roles for your ships. They can be applied to any ship, and they have some way to create them through tgui. For any ship you have an upgrade menu. You can upgrade the number of slots for each role. you can also change the roles. there will be pre-determined role types like security and engineering and medical. so you could do 3 security and 0 anything else. each role would spawn with corresponding gear. NOW IMAGINE: You can create a custom role. you can choose equipment for every slot on your character. That equipment is provided from the equipment marketplace - like a full toolbelt for the belt slot or a space helmet for your helmet slot or cat ears for your ear slot. AND CHECK THIS - You will have had to BUY all of that gear from a OOC market that uses your credits. So you want 1 slot for your custom ninja main character and 3 cowboy side slots? Gotta buy the ninja gear for yourself, and the cowboy gear in duplicate for each slot. This would have to be a HEAVY feature with a full ui for this. we're going to steal monkestations's monkecoin. its a persistent coin you earn from round ends. we'll expand off that to build this custom slot feature. i downloaded their repo, so we need to expand on this in another document."

**Key Features:**
1. **Ship Upgrade Menu** - Per-ship customization interface
2. **Pre-Determined Role Types** - Security, Engineering, Medical, etc.
3. **Slot Count Customization** - Upgrade number of slots per role
4. **Role Swapping** - Change which roles are on your ship
5. **Custom Role Creation** - Build entirely custom roles with TGUI
6. **Equipment Marketplace** - OOC market to buy gear using credits
7. **Per-Slot Equipment Selection** - Choose equipment for every character slot (head, belt, ears, etc.)
8. **Persistence** - Purchased equipment and custom roles saved to database

**User Emphasis:**
- "HEAVY FEATURE with a full UI"
- Based on Monkestation's monkecoin (user has repo)
- Uses persistent credits (same as ship system)

**Example Use Case:**
- Player wants: 1 ninja slot + 3 cowboy slots
- Must buy: Full ninja equipment set + 3x cowboy equipment sets
- Each equipment piece purchased separately from marketplace
- Custom role saved and can be applied to any unlocked ship

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
- Used for ship parts, equipment, unlocks

**Ship System:**
- Ships have job slots defined in templates
- `assemble_job_slots()` converts static job lists into job datums at spawn time
- Ships can be unlocked and spawned per-round (one spawn limit)
- Customization is Phase 4 of main ship system

**Current Job System:**
- Ships have pre-defined job_slots in templates
- First job is always leader/officer role
- Jobs spawn with default outfits

---

## Design Questions for Custom Roles Team

### Critical Questions

1. **Role vs Equipment Separation**
   - Is a "role" just a collection of equipment?
   - Or does a role include job title, access levels, permissions, etc.?
   - Can you have custom job titles for custom roles?

2. **Equipment Marketplace Scope**
   - What items are available? (every item in game? curated list?)
   - How are items priced?
   - Are there equipment tiers/rarities?
   - Can you sell items back?
   - Are cosmetic-only items separate from functional items?

3. **Per-Ship vs Account-Wide Customization**
   - Are custom roles saved per-ship or per-account?
   - Can you apply the same custom role to multiple ships?
   - Do you have to re-buy equipment for each ship, or once per account?

4. **Slot Upgrade System**
   - How much does it cost to add a slot to a ship?
   - Are there limits per ship (max crew size)?
   - Is slot count per-role or total ship crew?
   - Example: "3 security + 2 engineering" = 5 total slots?

5. **Pre-Determined Roles**
   - What are the default role types? (Security, Engineering, Medical, Science, Command, Service, etc.)
   - Do pre-determined roles have fixed equipment, or can you customize them too?
   - Do pre-determined roles cost credits to unlock/use?

6. **Custom Role Creation UI**
   - TGUI interface for role builder
   - How do you name custom roles?
   - How do you select equipment for each slot (head, mask, ears, eyes, uniform, suit, gloves, shoes, belt, pockets, back, ID)?
   - Preview system for how role looks?
   - Save/load custom role templates?

7. **Database Schema**
   - Player equipment inventory (purchased items)
   - Custom roles storage (role definitions)
   - Ship customizations (which roles assigned to which ship)
   - Slot upgrades per ship

8. **Integration with Monkecoin**
   - User mentions "stealing" Monkestation's monkecoin
   - Is monkecoin the same as credits, or separate currency?
   - Does monkecoin replace credits for this feature, or supplement?
   - What parts of monkecoin system to adapt?

### Important Questions

9. **Equipment Duplication**
   - User said: "buy ninja gear + 3x cowboy gear"
   - Does buying equipment grant infinite copies, or limited quantity?
   - If you have 3 cowboy slots, do you need 3 separate toolbelts, or just unlock "toolbelt" once?

10. **Access Levels & Permissions**
    - Do custom roles grant access to ship areas?
    - Can you customize access levels for custom roles?
    - Security implications of custom access?

11. **Job Responsibilities**
    - Are custom roles purely cosmetic/equipment, or do they have duties?
    - Can you assign custom roles to specific ship stations?
    - Do roles affect spawn location on ship?

12. **Equipment Balance**
    - How to prevent overpowered loadouts? (security armor + medical tools + engineering tools all-in-one)
    - Restrictions on equipment combinations?
    - Should some items be role-locked?

13. **Upgrade Cost Curve**
    - How much to add a slot? (flat cost vs scaling)
    - How much for equipment items? (varies by item power/rarity)
    - How much to unlock pre-determined roles?
    - Balance between ship unlocks vs role customization costs

14. **UI/UX Complexity**
    - Ship upgrade menu (per-ship interface)
    - Role builder (custom role creation)
    - Equipment marketplace (browse and buy)
    - Equipment inventory (see what you own)
    - Role assignment (assign roles to ship slots)
    - Potentially 5+ separate TGUI interfaces

### Anti-Exploit Questions

15. **Economy Exploits**
    - Prevent credit farming for unlimited equipment
    - Equipment refund abuse?
    - Trading equipment between characters?

16. **Balance Exploits**
    - Prevent all-engineer ships for power gaming?
    - Prevent combat-optimized loadouts that break balance?
    - Role diversity incentives?

---

## Constraints from Main System

**Must Preserve:**
- Database persistence architecture
- Credit economy (account-bound, 100 per round baseline)
- Existing job slot system (`assemble_job_slots()`)
- Ship template system

**Must Integrate With:**
- Ship unlock system (custom roles apply to unlocked ships)
- Credit earning (same currency pool)
- Ship spawn flow (customizations applied at spawn time)

**Must Not Conflict With:**
- Battlepass system (separate feature team)
- Automation crafting system (separate feature team)
- Core ship unlock system (main team)

---

## Success Criteria

**Custom Roles Team Must Deliver:**

1. **Equipment Marketplace Design**
   - Item catalog structure
   - Pricing model
   - Purchase/inventory system
   - Database schema for equipment ownership

2. **Custom Role System**
   - Role creation interface (TGUI)
   - Equipment slot assignment
   - Role naming and saving
   - Role application to ships
   - Database schema for custom roles

3. **Ship Upgrade Menu**
   - Per-ship customization interface
   - Slot count upgrades
   - Role assignment to slots
   - Pre-determined role selection
   - Custom role application

4. **Integration Plan**
   - How custom roles modify `assemble_job_slots()`
   - How equipment is granted at spawn time
   - Database schema additions
   - Credit economy integration

5. **Implementation Roadmap**
   - Phased delivery plan
   - UI/UX milestones
   - Dependencies on main ship system
   - Timeline estimates

6. **Monkecoin Analysis**
   - What to adapt from Monkestation's monkecoin
   - How it integrates with existing credits
   - Implementation details

---

## Round 1-4 Process for Custom Roles Team

### Round 1: Analysis
**Agents CR-A, CR-B, CR-C, CR-D each independently:**
- Analyze user requirements (very detailed!)
- Research Monkestation's monkecoin (user has repo)
- Propose equipment marketplace structure
- Propose custom role creation UI
- Propose ship upgrade menu design
- Identify integration points with main ship system
- Document findings and initial thoughts

### Round 2: Disagreements & Gaps
**Agents discuss and debate:**
- Points of disagreement
- Missing information or gaps (lots of design questions!)
- Findings that surprised them
- Alignment and readiness for proposals

### Round 3: Architectural Proposals
**Each agent proposes:**
- Complete equipment marketplace design
- Custom role creation system
- Ship upgrade menu
- Database schema
- UI/UX specifications (TGUI interfaces)
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

**Custom Roles Agents (CR-A, CR-B, CR-C, CR-D):**

You are designing the **Custom Roles + Equipment Marketplace** feature for a ship purchase game. This is a **HEAVY FEATURE** with multiple complex TGUI interfaces.

**Your Scope:**
- Equipment marketplace (OOC market to buy gear with credits)
- Custom role creation system (TGUI role builder)
- Ship upgrade menu (per-ship customization)
- Pre-determined role types (Security, Engineering, Medical, etc.)
- Slot count upgrades
- Database persistence for equipment, roles, ship customizations

**User Guidance:**
- User explicitly called this a "HEAVY FEATURE with a full UI"
- User wants **no loss of complexity** - embrace rich, interconnected systems
- User has Monkestation's monkecoin code as reference
- Example use case: 1 ninja slot + 3 cowboy slots = buy ninja gear + 3x cowboy sets
- Each equipment piece for each character slot (head, belt, ears, uniform, etc.)

**Key Context:**
- Main ship system uses DATABASE persistence
- Credits are account-bound persistent currency (100 per round baseline)
- Ships can be unlocked and customized
- Customizations apply at ship spawn time
- Existing `assemble_job_slots()` system can be extended

**Key Design Questions:**
- Is a "role" just equipment, or does it include access/permissions/job title?
- Does buying equipment grant infinite copies, or per-slot purchases?
- Per-ship customization or account-wide role templates?
- How many TGUI interfaces needed? (marketplace, role builder, ship menu, inventory, etc.)
- How to integrate monkecoin vs credits?
- How to balance equipment combinations?

**Deliverables:**
- Round 1-4 consensus (same process as main ship team)
- Complete equipment marketplace design
- Custom role creation system
- Ship upgrade menu design
- Database schema
- UI/UX specifications (potentially 5+ TGUI interfaces)
- Integration plan with main ship system
- Implementation roadmap

**Constraints:**
- Must work with database persistence
- Must integrate with credit economy
- Must extend existing job slot system
- Must not conflict with other feature teams (Battlepass, Automation)
- Timeline should align with main ship system phases

**Start with Round 1:** Each agent analyzes independently and documents findings.

---

## Consensus Discussion Template

Use this section for Round 1-4 discussions:

---

### Round 1: Initial Analysis

#### Agent CR-A Analysis
[Agent CR-A: Analyze the custom roles + equipment feature. This is extremely detailed - address equipment marketplace, custom role creation, ship upgrade menu, monkecoin integration, UI/UX design. Document comprehensive findings.]

#### Agent CR-B Analysis
[Agent CR-B: Analyze the custom roles + equipment feature. This is extremely detailed - address equipment marketplace, custom role creation, ship upgrade menu, monkecoin integration, UI/UX design. Document comprehensive findings.]

#### Agent CR-C Analysis
[Agent CR-C: Analyze the custom roles + equipment feature. This is extremely detailed - address equipment marketplace, custom role creation, ship upgrade menu, monkecoin integration, UI/UX design. Document comprehensive findings.]

#### Agent CR-D Analysis
[Agent CR-D: Analyze the custom roles + equipment feature. This is extremely detailed - address equipment marketplace, custom role creation, ship upgrade menu, monkecoin integration, UI/UX design. Document comprehensive findings.]

---

### Round 2: Disagreements & Gaps

#### Agent CR-A Response
[Points of disagreement, gaps noticed, surprising findings, alignment status]

#### Agent CR-B Response
[Points of disagreement, gaps noticed, surprising findings, alignment status]

#### Agent CR-C Response
[Points of disagreement, gaps noticed, surprising findings, alignment status]

#### Agent CR-D Response
[Points of disagreement, gaps noticed, surprising findings, alignment status]

---

### Round 3: Architectural Proposals

#### Agent CR-A Proposal
[Complete design: equipment marketplace, custom role system, ship upgrade menu, database schema, UI/UX specs, integration, roadmap]

#### Agent CR-B Proposal
[Complete design: equipment marketplace, custom role system, ship upgrade menu, database schema, UI/UX specs, integration, roadmap]

#### Agent CR-C Proposal
[Complete design: equipment marketplace, custom role system, ship upgrade menu, database schema, UI/UX specs, integration, roadmap]

#### Agent CR-D Proposal
[Complete design: equipment marketplace, custom role system, ship upgrade menu, database schema, UI/UX specs, integration, roadmap]

---

### Round 4: Final Consensus

#### Agent CR-A Final Verdict
[Support which proposal? Compromises? Non-negotiables? Final recommendation]

#### Agent CR-B Final Verdict
[Support which proposal? Compromises? Non-negotiables? Final recommendation]

#### Agent CR-C Final Verdict
[Support which proposal? Compromises? Non-negotiables? Final recommendation]

#### Agent CR-D Final Verdict
[Support which proposal? Compromises? Non-negotiables? Final recommendation]

---

### Final Custom Roles Design (Consensus)

[To be filled after Round 4]

#### Equipment Marketplace
[Final marketplace structure, pricing, item catalog, purchase flow]

#### Custom Role System
[Final role creation UI, equipment slot assignment, role saving]

#### Ship Upgrade Menu
[Final per-ship customization interface, slot upgrades, role assignment]

#### Database Schema
[Final schema additions for equipment, roles, ship customizations]

#### UI/UX Specifications
[Final TGUI interface designs - potentially 5+ separate interfaces]

#### Integration Plan
[How custom roles integrate with ship spawn system]

#### Implementation Roadmap
[Phases, timeline, dependencies]

#### Open Questions
[Questions for user or other teams]

---

## Integration Points with Other Teams

**Main Ship System Team:**
- Credit economy (equipment uses same credits)
- Ship unlock system (custom roles apply to unlocked ships)
- Job slot system (`assemble_job_slots()` extension)
- Ship spawn flow (when to apply customizations)
- Database schema coordination

**Battlepass Team:**
- Does battlepass grant equipment?
- Does battlepass grant slot upgrades?
- Shared credit currency or separate?
- XP from role performance?

**Automation Crafting Team:**
- Can you craft equipment instead of buying?
- Equipment as crafting output?
- Materials for equipment?

**Creative Review Team:**
- Review equipment marketplace for engagement
- Suggest equipment combinations that create interesting gameplay
- Identify ways to make role customization feel rewarding
- Balance between flexibility and overwhelming complexity

---

## User Notes & Clarifications

**Monkestation Monkecoin Reference:**
- User has downloaded Monkestation's repo
- Monkecoin is persistent currency earned from round ends
- We're "stealing" their system to expand for custom slots
- Agents should research monkecoin implementation if possible

**Complexity Expectations:**
- User explicitly said this is a "HEAVY FEATURE"
- Multiple TGUI interfaces needed
- Don't shy away from complexity
- Rich, detailed system expected

*[Additional user context can be added here]*

---

**Status:** Ready for Custom Roles Team (Agents CR-A, CR-B, CR-C, CR-D) to begin Round 1 analysis.
