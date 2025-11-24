# Ship Economy Database Schema - Visual Diagram

## Entity Relationship Overview

```
┌─────────────────────────────┐
│   player_ship_economy       │
├─────────────────────────────┤
│ PK  id                      │
│ UK  ckey (VARCHAR 32)       │
│     credits (UINT)          │
│     last_updated            │
└─────────────────────────────┘
              │
              │ 1:N
              │
┌─────────────────────────────┐
│   player_ship_parts         │
├─────────────────────────────┤
│ PK  id                      │
│ FK  ckey (VARCHAR 32)       │
│     part_type (VARCHAR 64)  │
│     part_subtype            │
│     rarity (ENUM)           │
│     quantity (UINT)         │
│     metadata (TEXT/JSON)    │
│     acquired_datetime       │
│     last_updated            │
└─────────────────────────────┘
              │
              │ 1:N
              │
┌─────────────────────────────┐
│   player_ship_unlocks       │
├─────────────────────────────┤
│ PK  id                      │
│ FK  ckey (VARCHAR 32)       │
│ UK  blueprint_id (VARCH 64) │
│     unlock_datetime         │
└─────────────────────────────┘
              │
              │ 1:N
              │
┌─────────────────────────────┐
│   round_ship_spawns         │
├─────────────────────────────┤
│ PK  id                      │
│     round_id (UINT, NULL)   │
│     server_ip (UINT)        │
│     server_port (SMALLINT)  │
│ FK  ckey (VARCHAR 32)       │
│     blueprint_id (VARCH 64) │
│     spawn_datetime          │
│     extracted (TINYINT)     │
│     extraction_datetime     │
└─────────────────────────────┘
              │
              │ 1:1 or 1:0
              │
┌─────────────────────────────┐
│   pending_extractions       │
├─────────────────────────────┤
│ PK  id                      │
│ FK  round_spawn_id          │
│ FK  ckey (VARCHAR 32)       │
│     ship_data (LONGTEXT)    │
│     extraction_type (ENUM)  │
│     queued_datetime         │
│     processed (TINYINT)     │
│     processed_datetime      │
│     processing_notes        │
└─────────────────────────────┘


┌─────────────────────────────┐
│  ship_economy_admin_log     │
├─────────────────────────────┤
│ PK  id                      │
│     datetime                │
│     round_id (UINT, NULL)   │
│     admin_ckey (VARCHAR 32) │
│ FK  target_ckey (VARCHAR 32)│
│     action (ENUM)           │
│     details (VARCHAR 1000)  │
│     old_value (VARCHAR 255) │
│     new_value (VARCHAR 255) │
└─────────────────────────────┘
              │
              │ logs actions for
              │
              └────────────────────────┐
                                       │
                            All economy tables
```

## Table Relationships

### Primary Relationships

1. **player_ship_economy** → **player_ship_parts**
   - Relationship: One account has many parts
   - Join: `player_ship_economy.ckey = player_ship_parts.ckey`
   - Type: 1:N (one-to-many)

2. **player_ship_economy** → **player_ship_unlocks**
   - Relationship: One account has many unlocks
   - Join: `player_ship_economy.ckey = player_ship_unlocks.ckey`
   - Type: 1:N (one-to-many)

3. **player_ship_economy** → **round_ship_spawns**
   - Relationship: One account spawns many ships across rounds
   - Join: `player_ship_economy.ckey = round_ship_spawns.ckey`
   - Type: 1:N (one-to-many)

4. **round_ship_spawns** → **pending_extractions**
   - Relationship: One spawn may have one pending extraction (or none)
   - Join: `round_ship_spawns.id = pending_extractions.round_spawn_id`
   - Type: 1:0..1 (one-to-zero-or-one)

5. **ship_economy_admin_log** → **All Tables**
   - Relationship: Logs reference any player in system
   - Join: `ship_economy_admin_log.target_ckey = <any_table>.ckey`
   - Type: N:M (many-to-many via ckey)

## Data Flow Diagram

```
NEW PLAYER
    │
    ├─> Creates account
    │       │
    │       └─> INSERT INTO player_ship_economy (ckey, credits=0)
    │
    └─> Unlocks starter ship
            │
            └─> INSERT INTO player_ship_unlocks (ckey, blueprint_id)

DURING ROUND
    │
    ├─> Spawns ship
    │       │
    │       └─> INSERT INTO round_ship_spawns (ckey, blueprint_id)
    │
    ├─> Earns credits/parts
    │       │
    │       ├─> UPDATE player_ship_economy SET credits = credits + X
    │       └─> INSERT INTO player_ship_parts (ckey, part_type, rarity)
    │
    └─> Unlocks new blueprint
            │
            └─> INSERT INTO player_ship_unlocks (ckey, blueprint_id)

ROUND END
    │
    ├─> Ship extracts successfully
    │       │
    │       └─> UPDATE round_ship_spawns SET extracted=1, extraction_datetime=NOW()
    │
    └─> Server crashes during extraction
            │
            └─> INSERT INTO pending_extractions (round_spawn_id, ship_data)

ADMIN ACTIONS
    │
    ├─> Grants credits
    │       │
    │       ├─> UPDATE player_ship_economy SET credits = credits + X
    │       └─> INSERT INTO ship_economy_admin_log (action='grant_credits')
    │
    ├─> Processes pending extraction
    │       │
    │       ├─> Parse ship_data from pending_extractions
    │       ├─> UPDATE player_ship_economy (credits)
    │       ├─> INSERT INTO player_ship_parts (new parts)
    │       ├─> UPDATE pending_extractions SET processed=1
    │       └─> INSERT INTO ship_economy_admin_log (action='process_extraction')
    │
    └─> Resets player economy
            │
            ├─> DELETE FROM player_ship_economy WHERE ckey=X
            ├─> DELETE FROM player_ship_parts WHERE ckey=X
            ├─> DELETE FROM player_ship_unlocks WHERE ckey=X
            └─> INSERT INTO ship_economy_admin_log (action='reset_economy')
```

## Index Visualization

### player_ship_economy
```
PK: id ─────────────────────> Auto-increment, clustered index
UK: ckey ───────────────────> Unique, player lookups (FAST)
```

### player_ship_parts
```
PK: id ─────────────────────> Auto-increment, clustered index
K1: ckey ───────────────────> Non-unique, filter by player
K2: (ckey, part_type) ──────> Compound, specific part lookups (FAST)
K3: rarity ─────────────────> Non-unique, filter by rarity
```

### player_ship_unlocks
```
PK: id ─────────────────────> Auto-increment, clustered index
UK: (ckey, blueprint_id) ───> Unique, prevents duplicate unlocks
K1: ckey ───────────────────> Non-unique, filter by player
K2: blueprint_id ───────────> Non-unique, analytics queries
```

### round_ship_spawns
```
PK: id ─────────────────────> Auto-increment, clustered index
K1: round_id ───────────────> Non-unique, round analytics
K2: ckey ───────────────────> Non-unique, player history
K3: extracted ──────────────> Non-unique, success rate queries
```

### pending_extractions
```
PK: id ─────────────────────> Auto-increment, clustered index
K1: ckey ───────────────────> Non-unique, player's pending queue
K2: processed ──────────────> Non-unique, filter unprocessed
K3: round_spawn_id ─────────> Non-unique, link to spawn
```

### ship_economy_admin_log
```
PK: id ─────────────────────> Auto-increment, clustered index
K1: target_ckey ────────────> Non-unique, player action history
K2: admin_ckey ─────────────> Non-unique, admin action history
K3: datetime ───────────────> Non-unique, chronological queries
```

## Query Optimization Paths

### Common Query 1: Get Player Economy Summary
```sql
-- Uses UK on player_ship_economy.ckey
SELECT credits FROM player_ship_economy WHERE ckey = ?

-- Uses K1 on player_ship_parts.ckey
SELECT COUNT(*), SUM(quantity) FROM player_ship_parts WHERE ckey = ?

-- Uses UK on player_ship_unlocks
SELECT COUNT(*) FROM player_ship_unlocks WHERE ckey = ?
```
**Performance**: O(1) on economy, O(N) on parts/unlocks where N = player's items

### Common Query 2: Check Blueprint Unlock
```sql
-- Uses UK on player_ship_unlocks.(ckey, blueprint_id)
SELECT COUNT(*) FROM player_ship_unlocks
WHERE ckey = ? AND blueprint_id = ?
```
**Performance**: O(1) - unique index lookup

### Common Query 3: Get Pending Extractions
```sql
-- Uses K2 on pending_extractions.processed
SELECT * FROM pending_extractions
WHERE processed = 0
ORDER BY queued_datetime
```
**Performance**: O(M) where M = unprocessed extractions (small subset)

### Common Query 4: Round Statistics
```sql
-- Uses K1 on round_ship_spawns.round_id
SELECT COUNT(*), SUM(extracted) FROM round_ship_spawns
WHERE round_id = ?
```
**Performance**: O(K) where K = spawns in round

## Field Size Analysis

### VARCHAR Fields
| Field | Size | Justification |
|-------|------|---------------|
| ckey | 32 | BYOND standard, matches existing tables |
| blueprint_id | 64 | Allows descriptive IDs like "ship_frigate_heavy_01" |
| part_type | 64 | Allows descriptive types like "weapon_railgun_mk2" |
| part_subtype | 64 | Optional variant identifier |
| details | 1000 | Admin log descriptions (follows admin_log pattern) |
| old_value | 255 | Snapshot of previous state |
| new_value | 255 | Snapshot of new state |

### TEXT/LONGTEXT Fields
| Field | Type | Justification |
|-------|------|---------------|
| metadata | TEXT | JSON for part attributes (up to 64KB) |
| ship_data | LONGTEXT | Full ship serialization (up to 4GB) |
| processing_notes | TEXT | Admin notes (up to 64KB) |

### Numeric Fields
| Field | Type | Range | Justification |
|-------|------|-------|---------------|
| credits | INT UNSIGNED | 0 to 4,294,967,295 | Currency balance |
| quantity | INT UNSIGNED | 0 to 4,294,967,295 | Part stack size |
| round_id | INT UNSIGNED | 0 to 4,294,967,295 | Matches existing round table |
| extracted | TINYINT | 0 or 1 | Boolean flag |
| processed | TINYINT | 0 or 1 | Boolean flag |

## Storage Estimates

### Assumptions
- 1,000 active players
- Average 50 parts per player
- Average 10 unlocks per player
- Average 5 spawns per player per round
- 1% extraction failure rate

### Per-Table Estimates

**player_ship_economy**: ~60 bytes/row × 1,000 = 60 KB

**player_ship_parts**: ~200 bytes/row × 50,000 = 10 MB

**player_ship_unlocks**: ~100 bytes/row × 10,000 = 1 MB

**round_ship_spawns**: ~150 bytes/row × 5,000/round = 750 KB/round

**pending_extractions**: ~10,000 bytes/row (due to LONGTEXT) × 50 = 500 KB

**ship_economy_admin_log**: ~250 bytes/row × 100/day = 25 KB/day

### Total Estimated Storage
- **Initial**: ~12 MB
- **Per Round**: +750 KB
- **Per Day**: +25 KB (logs)
- **After 1 Year** (365 rounds): ~286 MB

## ENUM Definitions

### player_ship_parts.rarity
```
'common'     - Most frequent drops
'uncommon'   - Moderately rare
'rare'       - Less common
'epic'       - Very rare
'legendary'  - Extremely rare
```

### pending_extractions.extraction_type
```
'normal'   - Standard extraction request
'crash'    - Server crashed during extraction
'timeout'  - Extraction timed out
'admin'    - Admin-initiated extraction
```

### ship_economy_admin_log.action
```
'grant_credits'      - Give credits to player
'remove_credits'     - Remove credits from player
'grant_part'         - Give ship part
'remove_part'        - Remove ship part
'grant_unlock'       - Unlock blueprint
'remove_unlock'      - Remove unlock
'reset_economy'      - Full reset
'process_extraction' - Process pending extraction
'other'              - Other admin actions
```

## Constraints Summary

### UNIQUE Constraints
1. `player_ship_economy.ckey` - One economy record per player
2. `player_ship_unlocks(ckey, blueprint_id)` - Prevent duplicate unlocks

### NOT NULL Constraints
All fields NOT NULL except:
- `player_ship_parts.part_subtype` (optional)
- `player_ship_parts.metadata` (optional)
- `round_ship_spawns.round_id` (can be NULL before rounds start)
- `round_ship_spawns.extraction_datetime` (NULL until extracted)
- `pending_extractions.processed_datetime` (NULL until processed)
- `pending_extractions.processing_notes` (optional)
- `ship_economy_admin_log.round_id` (can be NULL)
- `ship_economy_admin_log.old_value` (optional)
- `ship_economy_admin_log.new_value` (optional)

### DEFAULT Values
- `credits` → 0
- `quantity` → 1
- `rarity` → 'common'
- `extracted` → 0
- `processed` → 0
- `extraction_type` → 'crash'
- All timestamps → CURRENT_TIMESTAMP

## Migration Compatibility

### MySQL Versions
- **Required**: MySQL 5.7+ or MariaDB 10.2+
- **Recommended**: MySQL 8.0+ or MariaDB 10.5+

### Features Used
- ✓ InnoDB engine (MySQL 5.5+)
- ✓ utf8mb4 charset (MySQL 5.5.3+)
- ✓ ENUM types (MySQL 3.23+)
- ✓ TIMESTAMP ON UPDATE (MySQL 4.1+)
- ✓ TEXT/LONGTEXT (MySQL 3.23+)
- ✗ JSON type (not used, using TEXT for compatibility)
- ✗ Foreign keys (intentionally not used)
- ✗ Triggers (not used)
- ✗ Stored procedures (not used)

## Maintenance Recommendations

### Regular Tasks
1. **Weekly**: Check for unprocessed pending_extractions
2. **Monthly**: Analyze query performance and adjust indexes
3. **Quarterly**: Archive old round_ship_spawns data
4. **Yearly**: Review storage usage and optimize tables

### Cleanup Queries
```sql
-- Archive old spawn records (older than 1 year)
DELETE FROM round_ship_spawns
WHERE spawn_datetime < DATE_SUB(NOW(), INTERVAL 1 YEAR);

-- Archive old admin logs (older than 2 years)
DELETE FROM ship_economy_admin_log
WHERE datetime < DATE_SUB(NOW(), INTERVAL 2 YEAR);

-- Clean up processed extractions (older than 30 days)
DELETE FROM pending_extractions
WHERE processed = 1
  AND processed_datetime < DATE_SUB(NOW(), INTERVAL 30 DAY);
```

### Optimization
```sql
-- Rebuild indexes and optimize tables
OPTIMIZE TABLE player_ship_economy;
OPTIMIZE TABLE player_ship_parts;
OPTIMIZE TABLE player_ship_unlocks;
OPTIMIZE TABLE round_ship_spawns;
OPTIMIZE TABLE pending_extractions;
OPTIMIZE TABLE ship_economy_admin_log;

-- Analyze tables for query optimizer
ANALYZE TABLE player_ship_economy;
ANALYZE TABLE player_ship_parts;
ANALYZE TABLE player_ship_unlocks;
ANALYZE TABLE round_ship_spawns;
ANALYZE TABLE pending_extractions;
ANALYZE TABLE ship_economy_admin_log;
```
