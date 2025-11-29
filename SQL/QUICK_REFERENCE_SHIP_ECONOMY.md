# Ship Economy Tables - Quick Reference

## Table Overview

| Table Name | Purpose | Key Fields |
|------------|---------|------------|
| `player_ship_economy` | Account credits | ckey, credits |
| `player_ship_parts` | Parts inventory | ckey, part_type, rarity, quantity |
| `player_ship_unlocks` | Blueprint unlocks | ckey, blueprint_id |
| `round_ship_spawns` | Round tracking | ckey, blueprint_id, extracted |
| `pending_extractions` | Failed extractions | ckey, ship_data, processed |
| `ship_economy_admin_log` | Admin actions | admin_ckey, target_ckey, action |

## Common Queries

### Get Player Credits
```sql
SELECT credits FROM player_ship_economy WHERE ckey = 'playername';
```

### Get Player Parts Inventory
```sql
SELECT part_type, rarity, quantity
FROM player_ship_parts
WHERE ckey = 'playername'
ORDER BY rarity DESC, part_type;
```

### Get Player Unlocked Blueprints
```sql
SELECT blueprint_id, unlock_datetime
FROM player_ship_unlocks
WHERE ckey = 'playername'
ORDER BY unlock_datetime DESC;
```

### Check If Blueprint Unlocked
```sql
SELECT COUNT(*)
FROM player_ship_unlocks
WHERE ckey = 'playername' AND blueprint_id = 'ship_frigate_01';
```

### Get Pending Extractions for Player
```sql
SELECT *
FROM pending_extractions
WHERE ckey = 'playername' AND processed = 0
ORDER BY queued_datetime;
```

### Get Round Ship Stats
```sql
SELECT
    COUNT(*) as total_spawns,
    SUM(extracted) as successful_extractions,
    COUNT(*) - SUM(extracted) as failed_extractions
FROM round_ship_spawns
WHERE round_id = 12345;
```

### Get Player's Round History
```sql
SELECT
    r.round_id,
    r.blueprint_id,
    r.spawn_datetime,
    r.extracted,
    r.extraction_datetime
FROM round_ship_spawns r
WHERE r.ckey = 'playername'
ORDER BY r.spawn_datetime DESC
LIMIT 10;
```

### Get Admin Action History for Player
```sql
SELECT
    datetime,
    admin_ckey,
    action,
    details,
    old_value,
    new_value
FROM ship_economy_admin_log
WHERE target_ckey = 'playername'
ORDER BY datetime DESC;
```

## Common Admin Operations

### Grant Credits
```sql
-- Update credits
UPDATE player_ship_economy
SET credits = credits + 1000
WHERE ckey = 'playername';

-- Log the action
INSERT INTO ship_economy_admin_log
    (admin_ckey, target_ckey, action, details, old_value, new_value)
VALUES
    ('admin_ckey', 'playername', 'grant_credits', 'Granted 1000 credits for event reward', '500', '1500');
```

### Grant Ship Part
```sql
-- Add new part or increase quantity
INSERT INTO player_ship_parts
    (ckey, part_type, rarity, quantity)
VALUES
    ('playername', 'engine_fusion', 'epic', 1)
ON DUPLICATE KEY UPDATE
    quantity = quantity + 1;

-- Log the action
INSERT INTO ship_economy_admin_log
    (admin_ckey, target_ckey, action, details)
VALUES
    ('admin_ckey', 'playername', 'grant_part', 'Granted epic engine_fusion part');
```

### Unlock Blueprint
```sql
-- Add blueprint unlock (UNIQUE constraint prevents duplicates)
INSERT IGNORE INTO player_ship_unlocks
    (ckey, blueprint_id)
VALUES
    ('playername', 'ship_destroyer_01');

-- Log the action
INSERT INTO ship_economy_admin_log
    (admin_ckey, target_ckey, action, details)
VALUES
    ('admin_ckey', 'playername', 'grant_unlock', 'Unlocked ship_destroyer_01 blueprint');
```

### Process Pending Extraction
```sql
-- Mark extraction as processed
UPDATE pending_extractions
SET
    processed = 1,
    processed_datetime = NOW(),
    processing_notes = 'Manually processed after crash'
WHERE id = 123;

-- Log the action
INSERT INTO ship_economy_admin_log
    (admin_ckey, target_ckey, action, details)
VALUES
    ('admin_ckey', 'playername', 'process_extraction', 'Processed pending extraction ID 123');
```

### Reset Player Economy
```sql
-- WARNING: This deletes all player economy data!
DELETE FROM player_ship_economy WHERE ckey = 'playername';
DELETE FROM player_ship_parts WHERE ckey = 'playername';
DELETE FROM player_ship_unlocks WHERE ckey = 'playername';

-- Log the action
INSERT INTO ship_economy_admin_log
    (admin_ckey, target_ckey, action, details)
VALUES
    ('admin_ckey', 'playername', 'reset_economy', 'Full economy reset requested by player');
```

## Rarity Values

The `rarity` ENUM accepts only these values:
- `'common'`
- `'uncommon'`
- `'rare'`
- `'epic'`
- `'legendary'`

## Extraction Types

The `extraction_type` ENUM accepts:
- `'normal'` - Standard successful extraction
- `'crash'` - Server crashed during extraction
- `'timeout'` - Extraction timed out
- `'admin'` - Admin-initiated extraction

## Admin Action Types

The `action` ENUM accepts:
- `'grant_credits'` - Give credits to player
- `'remove_credits'` - Remove credits from player
- `'grant_part'` - Give ship part to player
- `'remove_part'` - Remove ship part from player
- `'grant_unlock'` - Unlock blueprint for player
- `'remove_unlock'` - Remove blueprint unlock
- `'reset_economy'` - Full economy reset
- `'process_extraction'` - Process pending extraction
- `'other'` - Other admin actions

## Performance Tips

1. **Use Indexes**: Queries filtering by `ckey` are indexed for fast lookups
2. **Limit Results**: Always use LIMIT on queries that might return many rows
3. **Avoid SELECT ***: Only select columns you need
4. **Use Prepared Statements**: In application code, always use parameterized queries

## Data Integrity Notes

1. **No FK Constraints**: Tables don't have foreign key constraints. Application code must maintain referential integrity.
2. **Manual Cleanup**: Deleting a player doesn't cascade to economy tables. Clean up manually if needed.
3. **UNIQUE Constraints**: Some tables prevent duplicates (player_ship_unlocks for ckey+blueprint_id)
4. **NULL Handling**: Always check for NULL in round_id, part_subtype, and optional fields

## Migration Status

Current Schema Version: **5.33**

To verify your database has this version:
```sql
SELECT * FROM schema_revision ORDER BY major DESC, minor DESC LIMIT 1;
```

Expected result: `major=5, minor=33`
