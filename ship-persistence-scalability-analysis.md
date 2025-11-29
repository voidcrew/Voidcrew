# Ship Persistence System - Scalability Analysis

**Author:** AI B
**Date:** 2025-11-23
**Context:** Analysis of current persistence system and scalability concerns for the ship unlock feature

---

## Current Persistence System

### How It Works

**System:** JSON-based flat file storage
**Implementation:** `/datum/json_savefile` (code/datums/json_savefile.dm)

**File structure:**
```
data/player_saves/[first_letter]/[ckey]/preferences.json
```

**Example:**
```
data/player_saves/i/isaac/preferences.json
```

### Data Organization

**Player-level data** (root of JSON):
- `lastchangelog` - Last seen changelog
- `be_special` - Antag preferences
- `key_bindings` - Hotkey configuration
- `favorite_outfits` - Saved outfit preferences
- `ships_owned` - Ship parts inventory (CURRENTLY BROKEN - saved but not loaded)

**Character-level data** (in `character1`, `character2`, etc.):
- Character appearance
- Job preferences
- Quirks
- Randomization settings

### Ship Parts Storage

**Level:** Player-wide (not character-specific)
**Design rationale:** Ship unlocks should be account-wide, shared across all character slots

**Current implementation:**
```dm
/datum/preferences
    var/list/ships_owned = list(
        /obj/item/ship_parts/neutral = 0,
        /obj/item/ship_parts/nanotrasen = 0,
        /obj/item/ship_parts/syndicate = 0,
    )

/datum/preferences/proc/save_ships()
    savefile.set_entry("ships_owned", ships_owned)
```

**Critical bug:** `ships_owned` is saved but NEVER loaded in `load_preferences()`. Missing:
```dm
ships_owned = savefile.get_entry("ships_owned", ships_owned)
```

---

## JSON Savefile System Characteristics

### How Saves Work

1. **Read entire JSON file** into memory
2. **Modify data** in memory
3. **Write entire JSON file** back to disk
4. No database indexing
5. No atomic operations
6. No transactional safety

### Current Data Size

**Per player (estimated):**
- Character preferences: ~5-10 KB
- Keybindings: ~1-2 KB
- Ship parts (3 integers): **~0.1 KB**
- **Total current:** ~10-15 KB per player

**With new ship unlock feature (estimated):**
- Ship unlocks (30+ boolean flags): ~0.5 KB
- Currency amount (1 integer): ~0.05 KB
- Custom job slots per ship (30 ships × average 5 custom jobs × job data): ~15-20 KB
- Ship customization metadata: ~5-10 KB
- **Total with feature:** ~30-50 KB per player

**File size increase:** ~3-5x current size

---

## Scalability Analysis

### Will It Scale?

#### ✅ Should Work Fine For:

**Small to Medium Servers (10-100 concurrent players)**
- TG codebase uses this system successfully at this scale
- 100 players × 50 KB = 5 MB total data (trivial)
- File I/O for 50 KB is fast on modern systems
- Write frequency low (on spawn, on purchase, on round end)

**Basic Feature Set**
- Ship unlocks as simple boolean flags
- Currency as single integer
- Minimal customization options
- Infrequent saves (only on significant events)

#### ❌ Potential Problems With:

**Large Servers (200+ concurrent players)**
- Disk I/O becomes bottleneck
- 200+ concurrent file reads/writes during round end rewards
- No connection pooling or queue management
- Risk of file locking issues

**Frequent Write Operations**
- If currency is earned per-action (mining, combat, trading)
- Writing entire 50 KB file for every +10 currency reward
- Could trigger hundreds of writes per minute during active gameplay
- No write coalescing or batching

**Data Corruption Risks**
- Read-modify-write cycle is NOT atomic
- Two simultaneous saves can corrupt data:
  1. Thread A reads file (ships_owned = 5)
  2. Thread B reads file (ships_owned = 5)
  3. Thread A increments (ships_owned = 6), writes file
  4. Thread B increments (ships_owned = 6), writes file
  5. Result: ships_owned = 6 (should be 7)
- BYOND is single-threaded but async operations can interleave

**Cross-Player Queries**
- "How many players own Bogatyr-class ship?" → Must read all player JSON files
- "Top 10 richest players" → Scan entire player base
- "Average currency per player" → Parse every preferences.json
- No indexes, no query optimization

**Analytics and Admin Tools**
- Can't efficiently build leaderboards
- Can't track economy health (total currency in circulation)
- Can't identify balance issues (which ships most popular)
- Manual file parsing required

---

## Alternative: Database Hybrid Approach

### You Already Have Database Infrastructure!

**SSdbcore exists** (`code/controllers/subsystem/dbcore.dm`)

Currently used for:
- Polls
- Round tracking
- Admin logs
- Connection bans
- Some statistics

**NOT currently used for:**
- Player preferences
- Ship parts
- Character data

### Proposed Hybrid Architecture

**Keep in JSON (Low-write frequency, player-facing):**
- Character appearance (hair, eyes, species, etc.)
- UI preferences (hotkeys, chat settings)
- Job preferences (preferred roles)
- Quirks

**Move to Database (High-write frequency, queryable):**
- Ship unlocks
- Player currency
- Ship customizations
- Progression statistics

### Example Database Schema

```sql
-- Ship unlocks (one row per unlock)
CREATE TABLE player_ship_unlocks (
    id INTEGER PRIMARY KEY AUTO_INCREMENT,
    ckey VARCHAR(32) NOT NULL,
    ship_template VARCHAR(128) NOT NULL, -- e.g., "/datum/map_template/shuttle/voidcrew/bogatyr"
    unlocked_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY (ckey, ship_template),
    INDEX idx_ckey (ckey),
    INDEX idx_ship (ship_template)
);

-- Player currency
CREATE TABLE player_ship_currency (
    ckey VARCHAR(32) PRIMARY KEY,
    currency_amount INTEGER DEFAULT 0,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_currency (currency_amount DESC) -- For leaderboards
);

-- Ship customizations (JSON blob for flexibility)
CREATE TABLE player_ship_customizations (
    id INTEGER PRIMARY KEY AUTO_INCREMENT,
    ckey VARCHAR(32) NOT NULL,
    ship_template VARCHAR(128) NOT NULL,
    custom_job_slots TEXT, -- JSON string of custom job configurations
    custom_name VARCHAR(128),
    custom_skin VARCHAR(64),
    last_modified DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY (ckey, ship_template),
    INDEX idx_ckey (ckey)
);

-- Legacy ship parts (for migration)
CREATE TABLE player_ship_parts (
    ckey VARCHAR(32) PRIMARY KEY,
    neutral_parts INTEGER DEFAULT 0,
    nanotrasen_parts INTEGER DEFAULT 0,
    syndicate_parts INTEGER DEFAULT 0,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### Benefits of Database Approach

**Performance:**
- ✅ Atomic transactions (ACID guarantees)
- ✅ Write coalescing (batch multiple updates)
- ✅ Connection pooling
- ✅ Indexed queries (fast lookups)

**Queryability:**
- ✅ "SELECT COUNT(*) FROM player_ship_unlocks WHERE ship_template = 'bogatyr'" (instant)
- ✅ "SELECT ckey, currency_amount FROM player_ship_currency ORDER BY currency_amount DESC LIMIT 10" (leaderboard)
- ✅ "SELECT AVG(currency_amount) FROM player_ship_currency" (economy health)

**Scalability:**
- ✅ Handles hundreds of concurrent players
- ✅ Scales to millions of unlock records
- ✅ Professional database engines optimize I/O

**Data Integrity:**
- ✅ Foreign key constraints
- ✅ Transaction rollback on errors
- ✅ Backup/restore tools

### Trade-offs of Database Approach

**Complexity:**
- ❌ Two persistence systems to maintain
- ❌ Database setup/configuration required
- ❌ More complex deployment

**Infrastructure:**
- ❌ Requires MySQL/MariaDB/PostgreSQL server
- ❌ Database maintenance (backups, migrations, schema updates)
- ❌ Additional failure point (what if DB goes down?)

**Migration:**
- ❌ Must migrate existing players from JSON to DB
- ❌ Compatibility during transition period
- ❌ Risk of data loss if migration fails

---

## Recommendations by Server Size

### Small Server (< 50 players)

**Recommendation:** Stick with JSON

**Reasoning:**
- Existing infrastructure works
- Minimal performance concerns
- Less operational complexity
- Easy to backup (just file copies)

**Action items:**
1. Fix the ships_owned load bug
2. Add ships_unlocked list to JSON
3. Add currency integer to JSON
4. Implement in-memory write coalescing (batch saves)
5. Monitor file sizes and I/O patterns

### Medium Server (50-150 players)

**Recommendation:** JSON for MVP, DB for Phase 2+

**Phase 1 (MVP):**
- Fix JSON persistence bug
- Implement basic unlock system in JSON
- Monitor performance metrics

**Phase 2 (If needed):**
- Migrate to database if:
  - File I/O becomes bottleneck
  - Players report save/load lag
  - Need analytics/leaderboards

**Migration trigger points:**
- Save operations taking >500ms
- Round-end processing taking >10 seconds
- File corruption incidents
- Request for economy statistics/leaderboards

### Large Server (150+ players)

**Recommendation:** Database from the start

**Reasoning:**
- JSON won't scale at this level
- Economy features likely desired (leaderboards, stats)
- Write frequency too high for flat files
- Professional database management needed

**Implementation:**
- Use SSdbcore infrastructure (already exists)
- Implement schema above
- Keep character appearance in JSON (low-write, player-facing)
- Put ship progression in DB (high-write, queryable)

---

## Performance Optimization Strategies

### If Sticking with JSON

**1. Write Coalescing**
```dm
/datum/preferences
    var/pending_ship_save = FALSE
    var/save_timer_id

/datum/preferences/proc/queue_ship_save()
    if(pending_ship_save)
        return // Already queued
    pending_ship_save = TRUE
    save_timer_id = addtimer(CALLBACK(src, PROC_REF(flush_ship_save)), 5 SECONDS)

/datum/preferences/proc/flush_ship_save()
    pending_ship_save = FALSE
    save_ships()
```

**Benefit:** Batches multiple save requests within 5-second window

**2. Async I/O**
```dm
/datum/preferences/proc/save_ships_async()
    INVOKE_ASYNC(src, PROC_REF(save_ships))
```

**Benefit:** Doesn't block game thread during file write

**3. Dirty Flag Tracking**
```dm
/datum/preferences
    var/ships_dirty = FALSE

/datum/preferences/proc/modify_ships_owned(type, delta)
    ships_owned[type] += delta
    ships_dirty = TRUE

/datum/preferences/proc/save_ships()
    if(!ships_dirty)
        return // No changes, skip save
    ships_dirty = FALSE
    savefile.set_entry("ships_owned", ships_owned)
```

**Benefit:** Only saves when data actually changed

**4. Compression**
```dm
/datum/preferences/proc/save_ships()
    var/json_string = json_encode(ships_owned)
    var/compressed = compress_string(json_string)
    savefile.set_entry("ships_owned", compressed)
```

**Benefit:** Reduces file size (especially for large customization data)

### If Moving to Database

**1. Connection Pooling**
```dm
/datum/controller/subsystem/dbcore
    var/list/connection_pool = list()
    var/max_connections = 10
```

**Benefit:** Reuse connections, reduce overhead

**2. Prepared Statements**
```dm
var/datum/db_query/unlock_ship = SSdbcore.NewQuery(
    "INSERT INTO player_ship_unlocks (ckey, ship_template) VALUES (?, ?) ON DUPLICATE KEY UPDATE unlocked_at=NOW()",
    list(ckey, ship_template)
)
```

**Benefit:** SQL injection prevention, query plan caching

**3. Batch Inserts**
```dm
// Instead of 100 separate INSERTs at round end
// Use single multi-value INSERT
"INSERT INTO player_ship_currency (ckey, currency_amount) VALUES (?, ?), (?, ?), ... ON DUPLICATE KEY UPDATE currency_amount = currency_amount + VALUES(currency_amount)"
```

**Benefit:** Single round-trip to database

---

## Migration Strategy (JSON → Database)

### Phase 0: Preparation

1. **Deploy DB schema** (create tables)
2. **Test DB connectivity** (verify SSdbcore works)
3. **Create migration script** (read JSON, write DB)

### Phase 1: Dual-Write Period

```dm
/datum/preferences/proc/save_ships()
    // Write to JSON (legacy)
    savefile.set_entry("ships_owned", ships_owned)

    // ALSO write to DB (new)
    var/datum/db_query/query = SSdbcore.NewQuery(
        "INSERT INTO player_ship_parts (ckey, neutral_parts, nanotrasen_parts, syndicate_parts) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE ...",
        list(parent.ckey, ships_owned[/obj/item/ship_parts/neutral], ...)
    )
    query.Execute()
```

**Duration:** 1-2 weeks
**Goal:** Populate database while maintaining JSON compatibility

### Phase 2: Dual-Read Period

```dm
/datum/preferences/proc/load_ships()
    // Try DB first
    var/datum/db_query/query = SSdbcore.NewQuery("SELECT * FROM player_ship_parts WHERE ckey = ?", list(parent.ckey))
    if(query.Execute() && query.NextRow())
        ships_owned[/obj/item/ship_parts/neutral] = query.item[1]
        return

    // Fallback to JSON if DB has no data
    ships_owned = savefile.get_entry("ships_owned", ships_owned)
```

**Duration:** 1-2 weeks
**Goal:** Verify database has complete data

### Phase 3: Database Primary

```dm
/datum/preferences/proc/load_ships()
    // DB only
    var/datum/db_query/query = SSdbcore.NewQuery("SELECT * FROM player_ship_parts WHERE ckey = ?", list(parent.ckey))
    query.Execute()
    // Process results
```

**Duration:** Ongoing
**Goal:** JSON deprecated, DB is source of truth

### Rollback Plan

If database fails:
1. Toggle config flag: `USE_DB_FOR_SHIPS = FALSE`
2. Revert to JSON-only reads
3. Export DB data to JSON as emergency backup
4. Diagnose DB issues offline

---

## Testing Strategy

### JSON Persistence Testing

**Test cases:**
1. Save ships_owned → Restart server → Verify ships_owned loaded correctly
2. Multiple rapid saves (stress test write coalescing)
3. Corrupt JSON file → Verify graceful degradation
4. Very large ships_owned data (1000+ unlocks) → Measure load time
5. Concurrent save attempts → Verify no data loss

### Database Migration Testing

**Test cases:**
1. Migrate 1000 fake players from JSON → DB → Verify data integrity
2. Dual-write period → Verify JSON and DB stay in sync
3. Database connection failure → Verify fallback to JSON
4. Rollback procedure → Verify can revert to JSON without data loss

### Performance Benchmarks

**Metrics to track:**
- Average save_ships() execution time
- Average load_ships() execution time
- Round-end processing time (all players save)
- File size growth over time
- Database query response times (if using DB)

**Acceptable thresholds:**
- Single save: <100ms
- Single load: <50ms
- Round-end (100 players): <5 seconds
- File size per player: <100 KB

---

## Decision Matrix

| Server Size | Players | Data Size | Writes/Min | Recommendation | Rationale |
|-------------|---------|-----------|------------|----------------|-----------|
| Small | <50 | <5 MB total | <10 | **JSON** | Simple, works, minimal overhead |
| Medium | 50-150 | 5-15 MB | 10-50 | **JSON → DB** | Start JSON, migrate if needed |
| Large | 150+ | 15+ MB | 50+ | **Database** | JSON won't scale, need analytics |

## Key Question for User

**How many concurrent players do you expect on your server?**

- **Under 50:** JSON is fine, just fix the bug
- **50-100:** JSON for MVP, plan DB migration
- **Over 100:** Database from the start

---

## Summary

**Current system (JSON):**
- ✅ Simple
- ✅ Works for small-medium servers
- ✅ Easy backup/restore
- ❌ No atomic operations
- ❌ No cross-player queries
- ❌ Doesn't scale to 200+ players

**Database alternative:**
- ✅ Scales to large servers
- ✅ Atomic transactions
- ✅ Queryable (leaderboards, analytics)
- ✅ Professional reliability
- ❌ More complex
- ❌ Requires database infrastructure
- ❌ Migration effort

**Recommendation:** Fix JSON bug for Phase 1. Monitor performance. Migrate to database if server grows or analytics features desired.

---

**Document Status:** Living document - update as decisions are made
**Next Review:** After Phase 1 MVP implementation
**Owner:** Server admin / lead developer
