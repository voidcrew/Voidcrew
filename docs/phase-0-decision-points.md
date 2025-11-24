# Phase 0 Implementation - Decision Points

**Date:** 2025-11-23
**Status:** Awaiting User Decisions
**Phase:** Phase 0 - Database Foundation

---

## Executive Summary

All 4 workers have completed Phase 0 research. We have:

- ✅ Identified the persistence bug (1-line fix ready)
- ✅ Designed complete database schema (8 tables)
- ✅ Designed database access layer (ShipEconomyDB)
- ✅ Designed transaction safety patterns
- ✅ Designed admin tools and testing procedures

**Implementation is ready to begin once you answer the 7 questions below.**

---

## Critical Findings

### 🔴 CRITICAL: The Persistence Bug

**Location:** `code\modules\client\preferences_savefile.dm:217`

**Issue:** `ships_owned` is saved but never loaded

**Fix (1 line):**

```dm
ships_owned = savefile.get_entry("ships_owned", ships_owned)
```

**Impact:** No migration needed - bug means no data ever persisted

**Status:** Can be implemented immediately, regardless of other decisions

---

### ⚠️ CRITICAL LIMITATION: No SQL Transactions

The codebase **does NOT support** BEGIN/COMMIT/ROLLBACK.

**Implications:**

- Must use application-level transaction safety
- Pre-flight checks before writes
- Optimistic locking via WHERE clauses
- Compensating transactions (manual rollback)
- Check `affected` rows to detect race conditions

**Workers have designed patterns to handle this safely.**

---

## Database Schema Summary

Worker 1 has designed **8 core tables:**

1. **player_credits** - Per-character or account-wide credits
2. **player_ship_parts** - Rarity-based parts inventory (account-wide)
3. **player_antag_parts** - Separate antagonist inventory
4. **player_ship_unlocks** - Blueprint unlocks (account-wide)
5. **round_ship_spawns** - Per-round spawn tracking
6. **part_extraction_log** - Audit trail for extractions
7. **credit_transaction_log** - Audit trail for credits
8. **Integration stubs** - Battlepass, Custom Roles, Automation

**Ready to create once you confirm the decisions below.**

---

## Decision Points

### Q1: Character vs Account Credits

**Context:** The consensus docs mention "per-character credits" but we need confirmation.

**Options:**

- **A) Per-character credits** - Each character slot has separate bank (uses character_slot column)
- **B) Account-wide credits** - All characters share one bank (removes character_slot column)

**Impact:** Database schema structure

**Your Answer:** B

---

### Q2: Rarity Tier Naming

**Context:** Inconsistency between database design and consensus docs.

**Options:**

- **A) common, uncommon, rare, epic, legendary** (Worker 1's proposal)
- **B) basic, advanced, rare, superior** (Consensus docs terminology)

**Impact:** Database ENUM values, all UI text, code references

**Your Answer:** A

---

### Q3: Transaction Failure Handling

**Context:** When a ship purchase fails partway through (e.g., credits deducted but unlock insert fails).

**Options:**

- **A) Auto-refund + error message** - Compensating transaction restores credits, shows "Purchase failed - credits refunded"
- **B) Retry automatically** - Retry the unlock insert up to 3 times before refunding
- **C) Queue for admin review** - Flag the transaction for admin to resolve manually

**Impact:** User experience during database hiccups

**Your Answer:** B -> A

---

### Q4: Critical Failure Recovery

**Context:** When extraction device marks part as extracted but inventory add fails (worst case: rollback also fails).

**Options:**

- **A) Keep physical item in hand** - Don't delete the item, player can retry extraction (safest)
- **B) Delete item anyway** - Trust the rollback worked, remove from world
- **C) Pending extractions queue** - Add to retry queue, attempt re-extraction automatically

**Impact:** Item loss potential vs. economy integrity

**Your Answer:** C

---

### Q5: Admin Permissions

**Context:** Which admin ranks can manipulate the ship economy?

**Options:**

- **A) R_ADMIN** - All admins can grant credits/parts/unlocks
- **B) R_DEBUG** - Only debug/senior admins can manipulate economy
- **C) R_ECONOMY** - Create new permission flag specifically for economy manipulation

**Impact:** Admin access control

**Your Answer:** C

---

### Q6: Transaction Logging Scope

**Context:** What operations get logged to the database audit tables?

**Options:**

- **A) ALL transactions** - Every credit change, part add, unlock (comprehensive but large database)
- **B) Admin actions only** - Only log admin grants/resets (cleaner logs, less storage)
- **C) Admin + major player operations** - Admin actions + blueprint unlocks only (balanced)

**Impact:** Database size, debugging capability, audit trail completeness

**Your Answer:** **Minimal for now**

---

### Q7: Anomaly Detection

**Context:** Should the system automatically detect economy issues (negative balances, suspicious values)?

**Options:**

- **A) Auto-check every 5 minutes** - Notify admins automatically when anomalies detected
- **B) Admin verb only** - Manual checking via admin command
- **C) Defer to later phase** - Don't implement for Phase 0 (add in Phase 5: Polish)

**Impact:** Admin workload vs. Phase 0 complexity

**Your Answer:** **no**

---

## Recommended Answers (Based on Consensus Analysis)

These are suggestions based on the consensus docs and existing codebase patterns:

1. **Q1:** A (per-character credits) - Consensus docs specify this
2. **Q2:** B (basic/advanced/rare/superior) - Matches consensus docs
3. **Q3:** A (auto-refund + error) - Simplest, clearest UX
4. **Q4:** A (keep physical item) - Safest, prevents item loss
5. **Q5:** A (R_ADMIN) - Standard admin permission, matches existing economy systems
6. **Q6:** C (admin + major operations) - Balanced approach
7. **Q7:** B (admin verb only) - Keep Phase 0 simple, add automation in Phase 5

**You can accept these or choose differently - your call!**

---

## What Happens After You Answer

### Immediate (Same Session)

1. ✅ **Implement 1-line persistence bug fix** (can do now)
2. ✅ **Update database schema** based on Q1, Q2
3. ✅ **Finalize transaction patterns** based on Q3, Q4
4. ✅ **Configure admin tools** based on Q5, Q6, Q7

### Phase 0 Implementation (1-2 days)

1. **Worker 1:** Create database tables, run migrations
2. **Worker 2:** Implement ShipEconomyDB datum (CRUD operations)
3. **Worker 3:** Implement transaction-safe purchase/extraction flows
4. **Worker 4:** Build admin verbs and TGUI panel

### Testing (Day 3)

1. Manual database CRUD testing
2. Persistence testing (restart server, verify data)
3. Multi-player concurrent testing
4. Admin tool verification

**Total estimated time: 3 days for complete Phase 0**

---

## How to Respond

**Option 1: Accept all recommendations**

```
ACCEPT ALL RECOMMENDATIONS
```

**Option 2: Custom answers**

```
Q1: A
Q2: B
Q3: A
Q4: A
Q5: A
Q6: C
Q7: B
```

**Option 3: Questions/clarifications**

```
I have questions about Q4 - what exactly happens if...
```

---

## Contact Points

**For technical questions:**

- Worker 1 (Database Schema): Questions about table structure, migrations
- Worker 2 (Access Layer): Questions about API design, caching
- Worker 3 (Transactions): Questions about failure modes, race conditions
- Worker 4 (Admin Tools): Questions about admin UI, testing procedures

**Coordinator (Claude):** Overall architecture questions, integration concerns

---

**Please provide your answers below and we'll begin implementation immediately!**
