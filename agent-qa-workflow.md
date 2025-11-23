# Multi-Agent Q&A Workflow Guide

This document explains how to manage communication between you and your 4 agents working on the ship purchase system.

---

## The Problem You Had

- 4 agents generated extensive analysis (agent-consensus-discussion.md is 980+ lines)
- Too much information to read and process
- Needed a way to extract actionable items and provide feedback

---

## The Solution: Structured Q&A Workflow

### Step 1: Decision Points Document ✅ COMPLETED
**File:** `user-decision-points.md`

This is your **control panel** for the multi-agent discussion:
- Concise executive summary (agents found critical bug + need 5 decisions)
- Clear questions with multiple choice options
- Agent consensus summary
- Space for your answers

**How to use it:**
1. Read the executive summary (5 minutes max)
2. Answer the 5 questions by filling in checkboxes or writing responses
3. Save the file when done

---

### Step 2: Provide Your Answers (CURRENT STEP)

You have 3 options:

#### Option A: Fill Out Decision Points Document
1. Open `user-decision-points.md`
2. Check boxes or fill in "Your Decision:" fields for Questions 1-5
3. Save the file
4. Tell me "I've answered the questions"

#### Option B: Answer Verbally to Me
Just tell me your decisions conversationally, like:
> "For currency earning, I want hybrid approach with base rewards plus performance bonuses. For parts system, let's deprecate them and convert to currency..."

I'll document your answers and update the agents.

#### Option C: Ask Follow-Up Questions First
If you're unsure about any decision, ask me things like:
- "What are the tradeoffs of keeping parts vs deprecating them?"
- "How complex is Option B vs Option D for ship skins?"
- "What did Agent B mean by 'physical trading economy'?"

---

### Step 3: Update Agents with Your Decisions

Once you've made decisions, I will:
1. Add your answers to a new section in `agent-consensus-discussion.md`
2. Notify all 4 agents of your constraints
3. Have them proceed to Round 3 (architectural proposals)
4. Incorporate your decisions into their designs

---

### Step 4: Ongoing Q&A During Implementation

As agents work through rounds, they may have new questions. Here's the workflow:

#### When Agents Have Questions for You:
1. I'll create a new section "**User Input Required - [Topic]**" in the consensus doc
2. I'll alert you with a concise summary
3. You provide answers using the same 3 options above

#### When You Have Questions for Agents:
1. Tell me your question
2. I'll query the relevant agent(s)
3. I'll summarize their response concisely
4. If you want full details, I'll point you to the specific section in their analysis

---

## Example Workflows

### Example 1: You Answer Questions Directly

**You say:**
> "I've made my decisions. Currency earning should be hybrid. Deprecate parts and convert to currency. One spawn per round. Antagonist ships are not priority. Simple palette swaps for skins."

**I do:**
1. Document your decisions in structured format
2. Update `agent-consensus-discussion.md` with "User Decisions" section
3. Direct agents to proceed with Round 3 using your constraints

---

### Example 2: You Ask Clarifying Questions

**You say:**
> "I'm not sure about the parts system. What did Agent B discover about physical trading?"

**I do:**
1. Read Agent B's Round 1 summary
2. Extract relevant finding (N key allows withdrawing parts as physical items for player-to-player trading)
3. Explain implications for each option (keep vs deprecate)
4. You make informed decision

---

### Example 3: Agents Ask You Questions Mid-Round

**Agents encounter design blocker in Round 3:**
> "To design the TGUI catalog, we need to know: Should ship previews be static images or dynamically rendered screenshots?"

**I do:**
1. Alert you with context and options
2. You provide decision
3. I relay answer to agents
4. Agents continue work

---

## Tips for Managing Multi-Agent Discussions

### Keep It Concise
- Use the decision points document as your interface
- Don't read the full 980-line consensus doc unless you want deep details
- Trust agent consensus summaries

### Batch Decisions
- Answer all pending questions at once when possible
- Prevents back-and-forth delay between rounds

### Defer Low-Priority Items
- If a question isn't critical for MVP (like antagonist ships), mark it "not priority / skip for now"
- Agents can revisit later phases

### Ask for Clarification When Needed
- Don't guess if you're unsure
- Better to ask "what are tradeoffs?" than make uninformed decision

### Use Phasing to Control Scope
- Agents proposed 4 phases (Bug Fix → Catalog → Unlocks → Customization)
- You can approve Phase 0-1 now, defer Phase 2-3 decisions

---

## What's Next?

**Immediate next step:** Answer the 5 questions in `user-decision-points.md`

Choose your approach:
- [ ] Fill out the decision points document and tell me when done
- [ ] Answer questions verbally to me right now
- [ ] Ask me clarifying questions first

**Once you provide answers:**
1. I'll update the consensus document
2. Agents proceed to Round 3 (architectural proposals)
3. You'll get a concise summary of their proposals
4. Round 4: Final consensus and implementation plan
5. Phase 0: Fix the critical persistence bug

---

## Questions About This Workflow?

Ask me anything about:
- How to use the decision points document
- What any of the questions mean
- Tradeoffs between options
- How to provide feedback efficiently
- How to query specific agent findings
- Anything else!
