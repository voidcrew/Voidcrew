# Agent Spawn Instructions - Complete Multi-Team Coordination

**Purpose:** Step-by-step instructions for spawning all agent teams and coordinating their work

**Total Agent Teams:** 8 teams (34-38 total agents)

**Document Status:** Ready to execute

---

## Overview of All Teams

| Team | Agents | Purpose | Document |
|------|--------|---------|----------|
| **Main Ship** | A, B, C, D (4) | Core ship purchase system | `agent-consensus-discussion.md` |
| **Battlepass** | BP-A, BP-B, BP-C, BP-D (4) | XP + battlepass | `feature-battlepass-xp-system.md` |
| **Custom Roles** | CR-A, CR-B, CR-C, CR-D (4) | Role customization + equipment marketplace | `feature-custom-roles-equipment.md` |
| **Automation** | AUTO-A, AUTO-B, AUTO-C, AUTO-D (4) | Factory automation crafting | `feature-automation-crafting.md` |
| **Creative Review** | CREATIVE-A, B, C, D (4) | Review all systems for improvements | `creative-review-plan.md` |
| **Integration - DB** | INT-DB-A, INT-DB-B (2) | Database schema synthesis | `integration-synthesis-plan.md` |
| **Integration - Economy** | INT-ECON-A, INT-ECON-B (2) | Economy balance | `integration-synthesis-plan.md` |
| **Integration - Ship** | INT-SHIP-A, INT-SHIP-B (2) | Ship system integration | `integration-synthesis-plan.md` |
| **Integration - UI** | INT-UI-A, INT-UI-B (2) | TGUI design consistency | `integration-synthesis-plan.md` |
| **Integration - PM** | INT-PM-A, INT-PM-B (2) | Master planning | `integration-synthesis-plan.md` |
| **Detail Teams** | 4-8 agents (optional) | Deep-dive detail work | Various |

**Total: 30-38 agents** (plus main ship team already complete)

---

## Execution Phases

### Phase 1: Feature Team Consensus (Async)
Spawn Battlepass, Custom Roles, Automation teams simultaneously

### Phase 2: Integration Analysis
Spawn 5 integration teams after Phase 1 complete

### Phase 3: Creative Review
Spawn creative team after Phase 2 complete

### Phase 4: Synthesis & Master Plan
All teams collaborate

### Phase 5: Implementation
Execute based on master plan

---

## PHASE 1: Spawn Feature Teams (Async)

### Team 1: Battlepass + XP System

**Document:** `feature-battlepass-xp-system.md`

**Agents to Spawn:** BP-A, BP-B, BP-C, BP-D (4 agents)

**Spawn Method:** Use Task tool with `subagent_type: "general-purpose"`

**Prompt for All 4 Agents:**

```
You are Agent [BP-A/BP-B/BP-C/BP-D] on the Battlepass + XP System team.

Your task: Design a complete battlepass and XP system for a ship purchase game, integrated with persistent credits, ship parts, and round-end rewards.

CONTEXT DOCUMENT: Read `feature-battlepass-xp-system.md` completely. It contains:
- User requirements (from combined-agent-questions.md Q10, Q14)
- Context from main ship system (database, credits, parts rarity system)
- Design questions you must answer
- Round 1-4 process template
- Integration constraints

YOUR PROCESS:
1. Round 1: Independently analyze requirements, research Monkestation's monkecoin (if possible), propose XP earning mechanics and battlepass structure
2. Round 2: Read other Battlepass agents' Round 1 findings, identify disagreements/gaps, express alignment
3. Round 3: Propose complete architecture (XP system, battlepass structure, database schema, integration plan, roadmap)
4. Round 4: Read all Round 3 proposals, synthesize final consensus

WRITE YOUR ANALYSIS DIRECTLY INTO `feature-battlepass-xp-system.md` in the appropriate Round sections.

KEY REQUIREMENTS:
- XP earning mechanics (what grants XP, how much, caps)
- Battlepass structure (levels, rewards, seasons)
- Database schema for XP and battlepass
- Integration with ship parts economy (battlepass grants parts as rewards)
- Round-end reward modification (currently 1 part + 100 credits)
- Monkecoin integration analysis
- Implementation roadmap

CONSTRAINTS:
- Must use database persistence (not savefiles)
- Must integrate with credit economy (100 credits per round baseline)
- Ship parts use rarity tiers (basic/advanced/rare/superior)
- Account-wide unlocks, per-character currency
- Must not conflict with Custom Roles or Automation teams

USER GUIDANCE: "I dont want to shy away from complexity" - embrace rich, interconnected systems

START WITH ROUND 1: Write your analysis in the "Agent [BP-A/BP-B/BP-C/BP-D] Analysis" section of `feature-battlepass-xp-system.md`.

Your analysis should be thorough and detailed.
```

**How to Spawn:**
Spawn 4 agents using the Task tool, each with the prompt above (replace [BP-A/BP-B/BP-C/BP-D] with appropriate agent ID)

---

### Team 2: Custom Roles + Equipment Marketplace

**Document:** `feature-custom-roles-equipment.md`

**Agents to Spawn:** CR-A, CR-B, CR-C, CR-D (4 agents)

**Spawn Method:** Use Task tool with `subagent_type: "general-purpose"`

**Prompt for All 4 Agents:**

```
You are Agent [CR-A/CR-B/CR-C/CR-D] on the Custom Roles + Equipment Marketplace team.

Your task: Design a HEAVY FEATURE with equipment marketplace, custom role creation system, and ship upgrade menus for a ship purchase game.

CONTEXT DOCUMENT: Read `feature-custom-roles-equipment.md` completely. It contains:
- User requirements (from combined-agent-questions.md Q12) - VERY DETAILED
- Context from main ship system (job slots, credits, database)
- Design questions you must answer (16 critical questions!)
- Round 1-4 process template
- Integration constraints

USER SAID: "This would have to be a HEAVY feature with a full ui for this"

YOUR PROCESS:
1. Round 1: Independently analyze requirements, research Monkestation's monkecoin, propose equipment marketplace structure, custom role system, ship upgrade menu
2. Round 2: Read other Custom Roles agents' Round 1 findings, identify disagreements/gaps, express alignment
3. Round 3: Propose complete architecture (marketplace, role builder, ship menu, database schema, UI/UX specs, integration, roadmap)
4. Round 4: Read all Round 3 proposals, synthesize final consensus

WRITE YOUR ANALYSIS DIRECTLY INTO `feature-custom-roles-equipment.md` in the appropriate Round sections.

KEY REQUIREMENTS:
- Equipment marketplace (OOC market to buy gear with credits)
- Custom role creation UI (TGUI role builder - choose equipment for every character slot)
- Ship upgrade menu (per-ship customization, slot count upgrades, role assignment)
- Pre-determined role types (Security, Engineering, Medical, etc.)
- Database schema for equipment ownership, custom roles, ship customizations
- Multiple TGUI interfaces (5+: marketplace, role builder, ship menu, inventory, etc.)
- Monkecoin integration

EXAMPLE USE CASE: Player wants 1 ninja slot + 3 cowboy slots = must buy full ninja gear + 3x cowboy gear sets

CONSTRAINTS:
- Must use database persistence
- Must integrate with credit economy
- Must extend existing job slot system (assemble_job_slots())
- Must not conflict with Battlepass or Automation teams

USER GUIDANCE: "I dont want to shy away from complexity" - this is a HEAVY feature, embrace it

START WITH ROUND 1: Write your analysis in the "Agent [CR-A/CR-B/CR-C/CR-D] Analysis" section of `feature-custom-roles-equipment.md`.

Your analysis should be extremely thorough given the complexity.
```

**How to Spawn:**
Spawn 4 agents using the Task tool, each with the prompt above (replace [CR-A/CR-B/CR-C/CR-D] with appropriate agent ID)

---

### Team 3: Automation Crafting Minigame

**Document:** `feature-automation-crafting.md`

**Agents to Spawn:** AUTO-A, AUTO-B, AUTO-C, AUTO-D (4 agents)

**Spawn Method:** Use Task tool with `subagent_type: "general-purpose"`

**Prompt for All 4 Agents:**

```
You are Agent [AUTO-A/AUTO-B/AUTO-C/AUTO-D] on the Automation Crafting Minigame team.

Your task: Design a Factorio/Satisfactory-style automation system for crafting ship parts.

CONTEXT DOCUMENT: Read `feature-automation-crafting.md` completely. It contains:
- User requirements (from combined-agent-questions.md Q15) - "factorio / satisfactory like minigame"
- Context from main ship system (parts rarity tiers, database, mining)
- Design questions you must answer
- Round 1-4 process template
- Integration constraints

YOUR PROCESS:
1. Round 1: Independently analyze requirements, research Factorio/Satisfactory mechanics, assess BYOND's automation capabilities, propose scope (simple vs complex)
2. Round 2: Read other Automation agents' Round 1 findings, identify disagreements/gaps, express alignment
3. Round 3: Propose complete architecture (automation scope, machines, recipes, UI, database schema, balance, phased roadmap)
4. Round 4: Read all Round 3 proposals, synthesize final consensus

WRITE YOUR ANALYSIS DIRECTLY INTO `feature-automation-crafting.md` in the appropriate Round sections.

KEY REQUIREMENTS:
- Automation system design (how Factorio-like? simple vs complex)
- Machine/building catalog (miners, assemblers, conveyors, etc.)
- Resource chains and recipes (basic/advanced/rare/superior parts)
- Factory persistence (per-round or persistent across rounds?)
- UI/UX for factory building
- Database schema for factory state
- Balance model (automation vs finding vs buying parts)
- Phased implementation (MVP → Full Automation)

CRITICAL SCOPE DECISION: How complex?
- Simple: Crafting benches (weeks)
- Medium: Machines + basic automation (months)
- Complex: Full Factorio-clone conveyor networks (many months)

CONSTRAINTS:
- Must use database persistence
- Must integrate with ship part economy
- Automation can't trivialize other progression paths
- BYOND engine limitations (top-down 2D, consider tile-based Factorio style)

USER GUIDANCE: "I dont want to shy away from complexity" - but propose multiple tiers so user can choose depth

START WITH ROUND 1: Write your analysis in the "Agent [AUTO-A/AUTO-B/AUTO-C/AUTO-D] Analysis" section of `feature-automation-crafting.md`.

Propose multiple complexity tiers with clear tradeoffs.
```

**How to Spawn:**
Spawn 4 agents using the Task tool, each with the prompt above (replace [AUTO-A/AUTO-B/AUTO-C/AUTO-D] with appropriate agent ID)

---

## PHASE 2: Integration Teams (After Phase 1 Complete)

**WAIT FOR:** All 3 feature teams to complete Round 4 consensus

**THEN SPAWN:** 5 integration teams (10 agents total)

---

### Integration Team 1: Database Schema

**Agents:** INT-DB-A, INT-DB-B (2 agents)

**Prompt:**

```
You are the Database Schema Integration Team.

TASK: Synthesize database schemas from all 4 feature teams into one unified schema.

READ THESE DOCUMENTS:
1. `agent-consensus-discussion.md` - Main ship system (Round 3-4 proposals for database schema)
2. `feature-battlepass-xp-system.md` - Battlepass system (Round 3-4 proposals for XP/battlepass schema)
3. `feature-custom-roles-equipment.md` - Custom roles (Round 3-4 proposals for equipment/roles schema)
4. `feature-automation-crafting.md` - Automation (Round 3-4 proposals for factory schema)

YOUR DELIVERABLES:
1. Analyze all 4 schemas
2. Identify conflicts, overlaps, gaps
3. Propose unified schema merging all requirements
4. Create relationship diagrams
5. Migration strategy (if needed)
6. Write full analysis to `integrated-database-schema.md`

CONSTRAINTS:
- All teams use same database (whatever existing server uses)
- No table name conflicts
- Efficient queries
- Data integrity
- Proper normalization

OUTPUT: `integrated-database-schema.md` with complete unified schema + SQL (if applicable)
```

---

### Integration Team 2: Economy Balance

**Agents:** INT-ECON-A, INT-ECON-B (2 agents)

**Prompt:**

```
You are the Economy Balance Integration Team.

TASK: Create unified credit economy balancing all 4 feature systems.

READ THESE DOCUMENTS:
1. `agent-consensus-discussion.md` - Ship unlock costs, part prices
2. `feature-battlepass-xp-system.md` - Battlepass rewards, XP earning
3. `feature-custom-roles-equipment.md` - Equipment marketplace prices, role costs
4. `feature-automation-crafting.md` - Automation costs, production rates

YOUR DELIVERABLES:
1. Analyze all credit earning sources
2. Analyze all credit spending sinks
3. Create unified pricing model
4. Balance earning vs spending across all systems
5. Ensure no system trivializes others
6. Create economy simulation/spreadsheet
7. Recommend values for desired progression speed
8. Write full analysis to `integrated-economy-balance.md`

CONSTRAINTS:
- Base: 100 credits per round
- Ship parts have rarity tiers (basic/advanced/rare/superior) with different prices
- Credits account-bound, not tradeable
- Battlepass grants parts AND credits
- Automation produces parts (competes with buying)

OUTPUT: `integrated-economy-balance.md` with complete pricing model + balance spreadsheet
```

---

### Integration Team 3: Ship System

**Agents:** INT-SHIP-A, INT-SHIP-B (2 agents)

**Prompt:**

```
You are the Ship System Integration Team.

TASK: Define how custom roles, automation, and battlepass integrate into core ship spawn flow.

READ THESE DOCUMENTS:
1. `agent-consensus-discussion.md` - Ship spawn flow (`SSshuttle.create_ship()`, `assemble_job_slots()`)
2. `feature-battlepass-xp-system.md` - Battlepass grants ship parts
3. `feature-custom-roles-equipment.md` - Custom roles modify job slots at spawn
4. `feature-automation-crafting.md` - Automation crafts parts

YOUR DELIVERABLES:
1. Analyze current ship spawn pipeline
2. Define integration points for custom roles (when to apply customizations)
3. Define how battlepass parts are granted
4. Define how automation-crafted parts are handled
5. Ensure thread safety preserved (`shuttle_loading` mutex)
6. Handle all edge cases
7. Create flow diagrams
8. Write full analysis to `integrated-ship-system.md`

CONSTRAINTS:
- Must preserve existing ship spawn flow
- Thread safety critical (SSair management, shuttle_loading)
- Custom roles apply at spawn time
- One spawn per round limit
- Antag ships special handling

OUTPUT: `integrated-ship-system.md` with complete spawn flow integration + diagrams
```

---

### Integration Team 4: UI/UX Consistency

**Agents:** INT-UI-A, INT-UI-B (2 agents)

**Prompt:**

```
You are the UI/UX Consistency Integration Team.

TASK: Ensure all TGUI interfaces have consistent design, styling, and navigation.

READ THESE DOCUMENTS:
1. `agent-consensus-discussion.md` - Ship catalog UI
2. `feature-battlepass-xp-system.md` - Battlepass progression viewer UI
3. `feature-custom-roles-equipment.md` - Role builder, equipment marketplace, ship upgrade menu UIs (5+ interfaces)
4. `feature-automation-crafting.md` - Factory builder UI

YOUR DELIVERABLES:
1. Analyze all proposed TGUI interfaces
2. Define consistent styling/theming
3. Shared component library
4. Navigation flow between interfaces
5. Responsive design standards
6. Accessibility standards
7. Mockups/wireframes
8. Write full analysis to `integrated-tgui-design.md`

CONSTRAINTS:
- All interfaces use TGUI
- Consistent look and feel
- Easy navigation between systems
- Accessibility for all players

OUTPUT: `integrated-tgui-design.md` with design system + component library + mockups
```

---

### Integration Team 5: Master Planning

**Agents:** INT-PM-A, INT-PM-B (2 agents)

**Prompt:**

```
You are the Master Planning Integration Team.

TASK: Create unified implementation timeline combining all 4 feature systems.

READ THESE DOCUMENTS:
1. `agent-consensus-discussion.md` - Main ship: 10-20 weeks (agent proposals vary)
2. `feature-battlepass-xp-system.md` - Battlepass timeline from Round 3-4
3. `feature-custom-roles-equipment.md` - Custom roles timeline from Round 3-4 (HEAVY FEATURE)
4. `feature-automation-crafting.md` - Automation timeline from Round 3-4 (varies by scope)
5. `integrated-database-schema.md` - Database work estimates
6. `integrated-economy-balance.md` - Economy tuning estimates
7. `integrated-ship-system.md` - Integration work estimates
8. `integrated-tgui-design.md` - UI work estimates

YOUR DELIVERABLES:
1. Analyze all timeline proposals
2. Identify dependencies between systems
3. Create critical path analysis
4. Parallel work opportunities
5. Risk assessment and buffer time
6. Create phased roadmap (Phase 0-6)
7. Resource allocation
8. Testing strategy
9. Write full plan to `master-implementation-plan.md`

CONSTRAINTS:
- Phase 0: Bug fix + database setup (must go first)
- Some systems depend on others (custom roles need ship spawn flow)
- Custom roles is HEAVY (potentially 20-30 weeks alone)
- Automation scope varies (10-40 weeks depending on complexity)

OUTPUT: `master-implementation-plan.md` with complete timeline + Gantt chart + critical path
```

---

## PHASE 3: Creative Review Team (After Phase 2 Complete)

**WAIT FOR:** All integration teams to complete analysis

**THEN SPAWN:** Creative review team (4 agents)

**Agents:** CREATIVE-A, CREATIVE-B, CREATIVE-C, CREATIVE-D

**Each Agent Has Different Focus:**

---

### Agent CREATIVE-A: Systems Integration Specialist

**Prompt:**

```
You are Agent CREATIVE-A: Systems Integration Specialist on the Creative Review Team.

TASK: Find elegant ways to connect all systems and identify cross-system synergies.

READ ALL DOCUMENTS:
1. Main ship system proposals
2. Battlepass system proposals
3. Custom roles system proposals
4. Automation system proposals
5. ALL integration analysis documents

YOUR FOCUS:
- How can battlepass tie into ship unlocks elegantly?
- How can custom roles enhance automation gameplay?
- How can automation feed into equipment marketplace?
- What cross-system synergies create emergent gameplay?
- How can credits flow cohesively?

WRITE YOUR ANALYSIS to `creative-review-plan.md` in "Agent CREATIVE-A: Systems Integration Review" section.

USER GUIDANCE: "dont want to shy away from complexity" - look for rich, interconnected systems

BE CREATIVE. Propose enhancements that make systems work together in surprising, elegant ways.
```

---

### Agent CREATIVE-B: Player Experience Designer

**Prompt:**

```
You are Agent CREATIVE-B: Player Experience Designer on the Creative Review Team.

TASK: Make features feel rewarding, exciting, and create memorable moments.

READ ALL DOCUMENTS:
1. Main ship system proposals
2. Battlepass system proposals
3. Custom roles system proposals
4. Automation system proposals
5. ALL integration analysis documents

YOUR FOCUS:
- How to make unlocking ships feel like achievements, not grinding?
- How to make custom roles feel like player expression?
- How to make automation satisfying, not tedious?
- What memorable "wow" moments can each system create?
- Social features (showing off, sharing, competing)?

WRITE YOUR ANALYSIS to `creative-review-plan.md` in "Agent CREATIVE-B: Player Experience Review" section.

USER GUIDANCE: "dont want to shy away from complexity" - engagement through depth, not simplification

BE CREATIVE. Propose enhancements that make players EXCITED about these systems.
```

---

### Agent CREATIVE-C: Feature Completeness Analyst

**Prompt:**

```
You are Agent CREATIVE-C: Feature Completeness Analyst on the Creative Review Team.

TASK: Identify gaps, missing features, and round out the systems.

READ ALL DOCUMENTS:
1. Main ship system proposals
2. Battlepass system proposals
3. Custom roles system proposals
4. Automation system proposals
5. ALL integration analysis documents

YOUR FOCUS:
- What quality-of-life features are missing?
- What edge cases should become features?
- What complementary systems would complete the experience?
- What player needs aren't addressed?
- What "nice to have" becomes "must have"?

WRITE YOUR ANALYSIS to `creative-review-plan.md` in "Agent CREATIVE-C: Feature Completeness Review" section.

USER GUIDANCE: "dont want to shy away from complexity" - don't avoid features due to scope concerns

BE CREATIVE. Propose missing pieces that would make the whole greater than the sum of parts.
```

---

### Agent CREATIVE-D: Complexity Amplifier

**Prompt:**

```
You are Agent CREATIVE-D: Complexity Amplifier on the Creative Review Team.

TASK: Add depth, mastery paths, and advanced features for dedicated players.

READ ALL DOCUMENTS:
1. Main ship system proposals
2. Battlepass system proposals
3. Custom roles system proposals
4. Automation system proposals
5. ALL integration analysis documents

YOUR FOCUS:
- Where can we add layers of depth?
- How to create mastery paths for experienced players?
- What advanced features for power users?
- Balance accessibility for newbies with depth for veterans?
- What complex systems would dedicated players appreciate?

WRITE YOUR ANALYSIS to `creative-review-plan.md` in "Agent CREATIVE-D: Complexity Enhancement Review" section.

USER GUIDANCE: "I dont want to shy away from complexity" - THIS IS YOUR MANDATE. EMBRACE COMPLEXITY.

BE CREATIVE. Propose deep, rich systems that reward mastery and long-term engagement.
```

---

## PHASE 4: Synthesis (All Teams Collaborate)

**After creative review complete:**

1. All feature teams read integration analysis
2. All feature teams read creative recommendations
3. Feature teams revise Round 4 consensus based on integration + creative feedback
4. Resolve conflicts collaboratively
5. Finalize unified approach

**User reviews and approves final synthesis**

---

## PHASE 5: Task Breakdown (Optional)

**If user wants detailed task breakdown:**

Spawn Task Breakdown Team (2-4 agents) to:
- Read master implementation plan
- Break into small tasks (each doable by single agent)
- Define dependencies
- Create task assignment list
- Output: `detailed-task-breakdown.md`

---

## Quick Reference: Spawn Commands

**To spawn all Phase 1 teams in parallel (12 agents):**

Use the Task tool 12 times (or spawn them in batches):

1-4. Battlepass agents (BP-A, BP-B, BP-C, BP-D)
5-8. Custom Roles agents (CR-A, CR-B, CR-C, CR-D)
9-12. Automation agents (AUTO-A, AUTO-B, AUTO-C, AUTO-D)

**To spawn Phase 2 integration teams (10 agents):**

13-14. Database integration (INT-DB-A, INT-DB-B)
15-16. Economy integration (INT-ECON-A, INT-ECON-B)
17-18. Ship system integration (INT-SHIP-A, INT-SHIP-B)
19-20. UI/UX integration (INT-UI-A, INT-UI-B)
21-22. Master planning (INT-PM-A, INT-PM-B)

**To spawn Phase 3 creative review (4 agents):**

23-26. Creative team (CREATIVE-A, CREATIVE-B, CREATIVE-C, CREATIVE-D)

---

## Success Criteria

All teams successful when:

✅ All 3 feature teams complete Round 4 consensus
✅ Integration teams produce unified schemas/plans
✅ Creative team provides actionable recommendations
✅ All conflicts resolved in synthesis phase
✅ Master implementation plan created
✅ User approves final unified approach
✅ No detail lost in the process

---

## User Decision Points

**Before spawning, user must decide:**

1. **Spawn all feature teams now (async)?** [Recommended: YES]
2. **Or stagger spawning?** [Alternative: One team at a time]
3. **When to spawn integration teams?** [Recommended: After all feature Round 4s]
4. **When to run creative review?** [Recommended: After integration analysis]
5. **Spawn detail agents proactively or reactively?** [Recommended: Reactively based on proposal depth]

---

**Status:** All documents created and ready. Awaiting user decision to begin Phase 1 spawning.

**Next Action:** User approves and spawns Phase 1 teams (12 agents).
