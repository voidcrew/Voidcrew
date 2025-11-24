# Quick Start: Ship System Documentation

## What Happened?
The massive 4,901-line `agent-consensus-discussion.md` has been split into 5 organized documents with cross-references and navigation.

## Start Here
👉 **[ship-system-master-index.md](ship-system-master-index.md)** 👈

## File Summary

| File | Lines | What's Inside | When to Read |
|------|-------|---------------|--------------|
| **[ship-system-master-index.md](ship-system-master-index.md)** | 230 | Navigation hub, overview, quick reference | **START HERE** |
| **[ship-system-round1-2-analysis.md](ship-system-round1-2-analysis.md)** | 1,078 | Initial findings, debates, first user decisions | Need technical foundation |
| **[ship-system-round3-proposals.md](ship-system-round3-proposals.md)** | 2,170 | All architectural proposals | Want to see alternatives |
| **[ship-system-user-decisions.md](ship-system-user-decisions.md)** | 373 | **CRITICAL REQUIREMENTS** (21 answered questions) | **REQUIRED READING** |
| **[ship-system-round4-consensus.md](ship-system-round4-consensus.md)** | 1,440 | Final verdicts, implementation plan | Ready to implement |

## Quick Reading Paths

### I just need requirements:
1. [ship-system-user-decisions.md](ship-system-user-decisions.md) ← **Read this**
2. [ship-system-round4-consensus.md](ship-system-round4-consensus.md) (Agent C's section)

### I'm implementing the system:
1. [ship-system-user-decisions.md](ship-system-user-decisions.md) (requirements)
2. [ship-system-round4-consensus.md](ship-system-round4-consensus.md) (Agent C's database schema + roadmap)
3. [ship-system-round1-2-analysis.md](ship-system-round1-2-analysis.md) (technical details as needed)

### I want complete context:
1. [ship-system-master-index.md](ship-system-master-index.md)
2. [ship-system-round1-2-analysis.md](ship-system-round1-2-analysis.md)
3. [ship-system-round3-proposals.md](ship-system-round3-proposals.md)
4. [ship-system-user-decisions.md](ship-system-user-decisions.md)
5. [ship-system-round4-consensus.md](ship-system-round4-consensus.md)

## Key Facts

### Critical Requirements (from User Decisions):
✅ Rarity tier parts (basic/advanced/rare/superior) - **NOT faction-specific**
✅ Database (SQL) persistence - **NOT savefiles**
✅ Physical parts + extraction device
✅ One ship spawn per round
✅ Two-scale antag ships (large/small)
✅ Battlepass/Custom Roles/Automation integration

### System Architecture:
```
Credits → Parts (rarity tiers) → Blueprints → Ships
   ↓          ↓                      ↓          ↓
Account   Physical         Account-wide    Per-round
 Bound     Items            Unlocks        One spawn
```

### Timeline:
- **16 weeks** total (Agent C's proposal)
- **7 phases** (0-6)
- **3 feature team dependencies**

## The Original File
`agent-consensus-discussion.md` (4,901 lines) - **Preserved intact, use split files instead**

## Need Help?
- Lost? → [ship-system-master-index.md](ship-system-master-index.md)
- Want requirements? → [ship-system-user-decisions.md](ship-system-user-decisions.md)
- Ready to build? → [ship-system-round4-consensus.md](ship-system-round4-consensus.md)

---

**Created:** [Date]
**Total Documents:** 5 + this quick start
**Content Preserved:** 100%
**Navigation:** ✅ Full cross-references
