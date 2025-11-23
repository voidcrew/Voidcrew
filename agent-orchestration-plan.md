# Agent Orchestration Plan

## Overview
This document explains how to orchestrate the 4 agents through the consensus-building process.

## Prerequisites
- All 4 agents have completed their analysis documents (current-state-doc-A/B/C/D.md)
- The consensus discussion document has been created (agent-consensus-discussion.md)

---

## Execution Strategy

### Option 1: Sequential Processing (Recommended for First Pass)
Run each round completely before moving to the next. This ensures proper information flow.

### Option 2: Parallel Within Rounds
Within each round, agents can work in parallel since they're reading the same input.

---

## Round-by-Round Instructions

### Round 1: Key Findings (Can Run in Parallel)

**For Each Agent (A, B, C, D):**

Prompt template:
```
You are Agent [X].

First, read ALL analysis documents:
- current-state-doc-A.md
- current-state-doc-B.md
- current-state-doc-C.md
- current-state-doc-D.md

Then open agent-consensus-discussion.md and fill in ONLY your section under "Round 1: Key Findings > Agent [X]".

Provide:
1. A concise summary (3-5 bullet points) of the MOST important aspects of the current system (synthesizing across all analyses)
2. Any unique insights you discovered that others might have missed

Do NOT fill in other agents' sections. Only fill in your own section.
```

**Order:** Can run A, B, C, D in parallel

---

### Round 2: Disagreements & Gaps (MUST Run Sequentially After Round 1)

**Wait until ALL agents have completed Round 1**

**For Each Agent (A, B, C, D):**

Prompt template:
```
You are Agent [X].

First, read the current state of agent-consensus-discussion.md, specifically ALL of Round 1.

Then fill in ONLY your section under "Round 2: Disagreements & Gaps > Agent [X] Response".

Document:
1. Points where you DISAGREE with other agents' findings
2. Gaps or missing information you noticed in their analyses
3. Findings from others that surprised you or that you missed

Be specific and reference other agents by letter (A, B, C, D).
```

**Order:** Can run A, B, C, D in parallel (since they're all reading the same Round 1 results)

---

### Round 3: Proposed Solution Architecture (MUST Run Sequentially After Round 2)

**Wait until ALL agents have completed Round 2**

**For Each Agent (A, B, C, D):**

Prompt template:
```
You are Agent [X].

First, read the current state of agent-consensus-discussion.md, specifically:
- ALL of Round 1 (Key Findings)
- ALL of Round 2 (Disagreements & Gaps)

Then fill in ONLY your section under "Round 3: Proposed Solution Architecture > Agent [X]'s Proposal".

Propose YOUR architectural approach for the new ship purchase system. Include:
1. High-level architecture
2. Key components and their responsibilities
3. How it integrates with existing systems
4. Tradeoffs of your approach

Consider the disagreements and gaps raised in Round 2 when crafting your proposal.
```

**Order:** Can run A, B, C, D in parallel (since they're all reading the same Round 1-2 results)

---

### Round 4: Consensus Building (MUST Run Sequentially After Round 3)

**Wait until ALL agents have completed Round 3**

**For Each Agent (A, B, C, D):**

Prompt template:
```
You are Agent [X].

First, read the ENTIRE agent-consensus-discussion.md document, paying special attention to all proposals in Round 3.

Then fill in ONLY your section under "Round 4: Consensus Building > Agent [X]'s Final Verdict".

Explain:
1. Which proposal do you support? (Can be your own, another agent's, or a synthesis)
2. What compromises are you willing to make?
3. What are your non-negotiable requirements?
4. Your final recommended approach

Be diplomatic but firm on critical technical points.
```

**Order:**
- **Recommended:** Sequential A → B → C → D (allows later agents to react to earlier verdicts)
- **Alternative:** Parallel (more independent but may miss consensus opportunities)

---

### Round 5: Final Synthesis (Single Agent or Human)

**Option A: Human Synthesis**
You read all verdicts and write the "Final Consensus" section.

**Option B: Facilitator Agent**
```
You are a facilitator agent. Read the ENTIRE agent-consensus-discussion.md document.

Synthesize the "Final Consensus" section by:
1. Identifying points of agreement across all agents
2. Resolving remaining disagreements (favor majority opinion or most technically sound argument)
3. Creating a unified architecture that incorporates the best ideas
4. Documenting the agreed implementation plan
5. Listing any open questions that remain

Be objective and focus on technical merit.
```

---

## Practical Execution Tips

### 1. Agent Context Management
Each agent invocation should include:
```
Read these files:
- current-state-doc-A.md
- current-state-doc-B.md
- current-state-doc-C.md
- current-state-doc-D.md
- agent-consensus-discussion.md (current state)

Then update agent-consensus-discussion.md with your section.
```

### 2. Preventing Cross-Contamination
- Explicitly tell agents which section to fill in
- Tell them NOT to modify other agents' sections
- Use clear delimiters in prompts

### 3. Verification Between Rounds
After each round completes:
- Read agent-consensus-discussion.md
- Verify all agents filled their sections
- Check for any formatting issues
- Proceed to next round only when satisfied

### 4. Handling Deadlock
If agents can't reach consensus in Round 4:
- Add a Round 5: "Compromise Proposals"
- Have agents propose specific compromises
- Use voting mechanism (majority wins)
- Human makes final decision as tiebreaker

---

## Example Agent Invocation

### For Round 1, Agent C:
```
I need you to participate in a multi-agent consensus discussion.

Context:
- You are Agent C
- You previously analyzed the ship purchase system (see current-state-doc-C.md)
- Three other agents (A, B, D) have also done analyses

Task:
1. Read ALL analysis documents:
   - current-state-doc-A.md
   - current-state-doc-B.md
   - current-state-doc-C.md
   - current-state-doc-D.md
2. Open agent-consensus-discussion.md
3. Fill in ONLY the "Round 1: Key Findings > Agent C" section
4. Provide 3-5 bullet points of the most important findings (synthesizing across all analyses)
5. Add unique insights that might not be obvious from the analyses

Do NOT fill in other agents' sections or modify their content.
```

---

## Monitoring Progress

Create a checklist:

**Round 1:**
- [ ] Agent A completed
- [ ] Agent B completed
- [ ] Agent C completed
- [ ] Agent D completed

**Round 2:**
- [ ] Agent A completed
- [ ] Agent B completed
- [ ] Agent C completed
- [ ] Agent D completed

**Round 3:**
- [ ] Agent A completed
- [ ] Agent B completed
- [ ] Agent C completed
- [ ] Agent D completed

**Round 4:**
- [ ] Agent A completed
- [ ] Agent B completed
- [ ] Agent C completed
- [ ] Agent D completed

**Final Synthesis:**
- [ ] Consensus document completed

---

## Expected Timeline

**Per Round:**
- Setup/prompt crafting: 2-3 minutes
- Agent execution (parallel): 3-5 minutes per agent
- Verification: 1-2 minutes

**Total:** ~45-60 minutes for complete consensus process

---

## Troubleshooting

**Problem:** Agent modifies another agent's section
**Solution:** Roll back the change, re-run with more explicit instructions

**Problem:** Agent refuses to disagree in Round 2
**Solution:** Emphasize that constructive disagreement is expected and valuable

**Problem:** Round 4 verdicts are too vague
**Solution:** Ask agents to be more specific about technical implementation details

**Problem:** No clear consensus emerges
**Solution:** Run synthesis agent or make human decision based on technical merit
