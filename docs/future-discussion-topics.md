# Future Discussion Topics - Ship Purchase System

**Status:** Notes for topics to add to agent discussion later. DO NOT implement yet.

---

## Topic 1: Database Persistence Architecture

**Context:** Agent C mentioned database in their proposal. User wants to expand this.

### What to Use Database For:

1. **Player Currency**
   - Ship credits (unified currency)
   - Cross-round persistence
   - Transaction history

2. **Ship Parts Inventory**
   - Regular parts (NEU/NT-C/SYN-C)
   - Antag parts (rare/expensive)
   - Fix Agent B's load bug by moving to DB

3. **Customized Ships Storage**
   - **NOT paint/skins** - those are separate .dmm files
   - **Job slots configuration** (which roles, how many of each)
   - **Equipment loadouts** per slot (what gear each role starts with)
   - Per-ship customization saved in DB
   - Can have multiple customization "presets" per ship

### Questions for Agents:

- What DB system? (SQL, SQLite, existing SS13 DB infrastructure?)
- Schema design for customization JSON/storage
- Migration path from savefile to DB
- Backup/export tools
- Performance implications (DB queries vs savefile reads)
- How to handle DB connection failures (fallback to defaults?)

---

## Topic 2: Creative Agent Review Round

**Context:** Current agents (A, B, C, D) are analytical/architectural. User wants creative perspective.

### Spawn 4 New "Creative" Agents To:

1. **Identify Integration Opportunities**
   - Where can different systems tie together elegantly?
   - What synergies exist between features?
   - How can features reinforce each other?

2. **Make Ideas More Interesting**
   - How to make progression feel rewarding?
   - What makes ship unlocking exciting vs just grinding?
   - How to create memorable moments?

3. **Add Features to Round Out the System**
   - What's missing that would complete the experience?
   - What quality-of-life features enhance gameplay?
   - What edge cases become features?

4. **Don't Shy Away From Complexity**
   - User is willing to embrace complex systems
   - Don't oversimplify for convenience
   - Rich, interconnected systems are desired

### Potential Creative Prompts:

- "How can the currency/parts/unlock progression create emergent gameplay?"
- "What makes antag ships feel special beyond just stats?"
- "How can ship customization become a form of player expression?"
- "What social/economic systems emerge from physical part trading?"
- "How do ship skins become meaningful choices vs cosmetic fluff?"
- "What progression hooks create long-term engagement?"

---

## Topic 3: Implementation Breakdown Strategy

**Context:** This is a LARGE project. Need structured approach to divide into achievable chunks.

### Goals:

1. **Long, Complex Overall Plan**
   - Don't cut corners
   - Thorough technical details
   - Nothing missing

2. **Many Small Achievable Parts**
   - Each part can be tackled by a single agent
   - Each part has clear success criteria
   - Each part is independently testable

3. **Single Agent Per Task**
   - Task is scoped small enough for one agent
   - Clear inputs and outputs
   - Well-defined integration points

4. **Thoroughness Over Speed**
   - "This is going to take a while" - that's OK
   - Better to be complete than fast
   - Technical details matter

### Proposed Breakdown Approach:

**Level 1: Phases** (already exists)
- Phase 0: Bug fix
- Phase 1: TGUI catalog
- Phase 2: Currency/unlocks
- Phase 3: Antag ships
- Phase 4: Customization

**Level 2: Components** (partially exists in proposals)
- Each phase broken into 5-10 components
- Examples: "Database schema", "TGUI interface", "Currency earning system"

**Level 3: Tasks** (NEED TO CREATE)
- Each component broken into 10-30 discrete tasks
- Examples:
  - "Write migration script for ships_owned → DB"
  - "Create ShipCatalog.tsx component skeleton"
  - "Implement currency adjustment transaction logging"
  - "Add unlock validation to ship spawn flow"

**Level 4: Agent Assignments** (NEED TO CREATE)
- Map each task to agent capability
- Ensure agent has all context/files needed
- Define success criteria per task
- Create dependency graph (task X blocks task Y)

### Questions for Agents:

- How to break down each component into tasks?
- What's a reasonable task size? (hours? days?)
- How to track dependencies between tasks?
- How to handle blockers/unknowns during execution?
- What testing is required per task?
- How to integrate completed tasks without breaking existing code?

### Potential Workflow:

1. Agents complete Round 4 consensus
2. Generate "Final Implementation Plan" document
3. Break plan into Level 3 tasks (detailed task list)
4. Create dependency graph
5. Identify "critical path" (what blocks what)
6. Assign tasks to specialized agents
7. Execute Phase 0 completely before starting Phase 1
8. Iterate

---

## Implementation Strategy Ideas

### Option A: Sequential Agent Execution
- One agent completes entire task before next agent starts
- Clear handoffs between agents
- Easier to track progress
- Slower overall (no parallelization)

### Option B: Parallel Agent Execution
- Multiple agents work on independent tasks simultaneously
- Faster overall completion
- Requires careful coordination
- Risk of merge conflicts / integration issues

### Option C: Hybrid (Recommended?)
- Critical path runs sequentially (Phase 0 → Phase 1 core → etc.)
- Non-blocking tasks run in parallel (e.g., image generation while TGUI coding)
- Maximize speed while minimizing risk

---

## Workflow for Next Steps

Once agents complete Round 4 consensus:

1. **Present Topic 1 (Database)** to all 4 analytical agents
   - Get architectural proposals for DB integration
   - Schema designs
   - Migration strategies

2. **Spawn Topic 2 (Creative Review)** - 4 new creative agents
   - Give them full context from Rounds 1-4
   - Ask for creative enhancements
   - Synthesis of ideas into compelling features

3. **Execute Topic 3 (Implementation Breakdown)**
   - Possibly spawn a "project manager" agent
   - Break down final consensus into task tree
   - Create execution plan with dependencies

4. **Begin Implementation**
   - Start with Phase 0 (bug fix)
   - Use task-based agent assignments
   - Track progress, iterate

---

## Open Questions

- Should database discussion happen in Round 4 or Round 5?
- Should creative agents see the analytical proposals first, or work independently?
- How granular should task breakdown be? (file-level? function-level?)
- Should we prototype a small piece first to validate approach?
- How to handle unknown unknowns discovered during implementation?

---

## User Intent Summary

**What user wants:**
- Rich, complex, interconnected system (not simplified)
- Database-backed persistence for customization, currency, parts
- Creative thinking to make features interesting and integrated
- Thorough breakdown into small, achievable tasks
- Long-term project approach (willing to take time to do it right)

**What user does NOT want:**
- Oversimplified solutions
- Cutting corners for speed
- Missing technical details
- Scope creep without structure
- Vague high-level plans without execution details
