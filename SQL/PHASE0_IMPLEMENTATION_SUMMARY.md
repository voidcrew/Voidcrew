# Ship Economy Phase 0 - Database Implementation Summary

## Overview
This document summarizes the Phase 0 database schema implementation for the own-your-ship feature based on user decisions from the consensus round.

## Schema Version
- **Previous Version**: 5.32
- **New Version**: 5.33
- **Migration Date**: 23 November 2025

## User Decisions Implemented

### Q1: Account-wide Credits (NO character_slot column)
- Credits stored at account level only (ckey-based)
- No per-character-slot tracking
- Implemented in: `player_ship_economy` table

### Q2: Rarity Names
Using exact names specified by user:
- common
- uncommon
- rare
- epic
- legendary

Implemented as: `ENUM('common', 'uncommon', 'rare', 'epic', 'legendary')`

### Q4: Failed Extraction Queue
- Implemented `pending_extractions` table
- Tracks ships that failed to extract due to crashes, timeouts, etc.
- Includes processing status and admin notes

### Q6: Minimal Logging
- Created `ship_economy_admin_log` for admin actions only
- No automatic transaction logging
- No player action audit trail

### Q7: No Anomaly Detection
- No automated anomaly detection tables
- No fraud detection systems
- Simplified design per user request

## Tables Created (6 total)

### 1. player_ship_economy
**Purpose**: Account-wide currency storage

**Columns**:
- `id` - Primary key
- `ckey` - Player account (unique)
- `credits` - Currency balance (unsigned int, default 0)
- `last_updated` - Auto-updated timestamp

**Indexes**:
- PRIMARY KEY on `id`
- UNIQUE KEY on `ckey`

### 2. player_ship_parts
**Purpose**: Ship parts inventory with rarity system

**Columns**:
- `id` - Primary key
- `ckey` - Player account
- `part_type` - Part identifier (VARCHAR 64)
- `part_subtype` - Optional variant (VARCHAR 64, nullable)
- `rarity` - ENUM(common, uncommon, rare, epic, legendary)
- `quantity` - Stack size (unsigned int, default 1)
- `metadata` - JSON for additional data (TEXT, nullable)
- `acquired_datetime` - When part was obtained
- `last_updated` - Auto-updated timestamp

**Indexes**:
- PRIMARY KEY on `id`
- KEY on `ckey`
- KEY on `ckey, part_type` (compound)
- KEY on `rarity`

### 3. player_ship_unlocks
**Purpose**: Track unlocked ship blueprints

**Columns**:
- `id` - Primary key
- `ckey` - Player account
- `blueprint_id` - Unique ship blueprint identifier (VARCHAR 64)
- `unlock_datetime` - When unlocked

**Indexes**:
- PRIMARY KEY on `id`
- UNIQUE KEY on `ckey, blueprint_id` (prevents duplicates)
- KEY on `ckey`
- KEY on `blueprint_id`

### 4. round_ship_spawns
**Purpose**: Per-round ship tracking and analytics

**Columns**:
- `id` - Primary key
- `round_id` - Game round (nullable, unsigned int)
- `server_ip` - Server identifier (unsigned int)
- `server_port` - Server port (unsigned smallint)
- `ckey` - Player who spawned ship
- `blueprint_id` - Which ship was spawned
- `spawn_datetime` - When spawned
- `extracted` - Extraction success flag (tinyint, default 0)
- `extraction_datetime` - When extracted (nullable)

**Indexes**:
- PRIMARY KEY on `id`
- KEY on `round_id`
- KEY on `ckey`
- KEY on `extracted`

### 5. pending_extractions
**Purpose**: Queue for failed extractions (crash recovery)

**Columns**:
- `id` - Primary key
- `round_spawn_id` - Foreign key to round_ship_spawns
- `ckey` - Player account
- `ship_data` - Serialized ship state (LONGTEXT)
- `extraction_type` - ENUM(normal, crash, timeout, admin)
- `queued_datetime` - When queued
- `processed` - Processing status flag (tinyint, default 0)
- `processed_datetime` - When processed (nullable)
- `processing_notes` - Admin notes/results (TEXT, nullable)

**Indexes**:
- PRIMARY KEY on `id`
- KEY on `ckey`
- KEY on `processed`
- KEY on `round_spawn_id`

### 6. ship_economy_admin_log
**Purpose**: Minimal admin action logging

**Columns**:
- `id` - Primary key
- `datetime` - Action timestamp
- `round_id` - Game round (nullable, unsigned int)
- `admin_ckey` - Admin who performed action
- `target_ckey` - Player affected
- `action` - ENUM(grant_credits, remove_credits, grant_part, remove_part, grant_unlock, remove_unlock, reset_economy, process_extraction, other)
- `details` - Action description (VARCHAR 1000)
- `old_value` - Previous value (VARCHAR 255, nullable)
- `new_value` - New value (VARCHAR 255, nullable)

**Indexes**:
- PRIMARY KEY on `id`
- KEY on `target_ckey`
- KEY on `admin_ckey`
- KEY on `datetime`

## Technical Specifications

### Engine & Charset
All tables use:
- **Engine**: InnoDB
- **Charset**: utf8mb4
- **Collation**: utf8mb4_general_ci

### Design Patterns Followed
1. **Nullable round_id**: Consistent with existing tables (can be NULL)
2. **Auto-increment IDs**: All tables use INT(11) AUTO_INCREMENT primary keys
3. **Timestamp handling**: Uses TIMESTAMP with auto-update for tracking changes
4. **DATETIME vs TIMESTAMP**:
   - DATETIME for explicit timestamps
   - TIMESTAMP for auto-updated fields
5. **VARCHAR sizing**: Followed existing patterns (ckey=32, descriptive fields=64-1000)

## Files Modified/Created

### Created
- `C:\Users\isaac\code\tg-voidcrew\SQL\ship_economy_phase0_migration.sql`
- `C:\Users\isaac\code\tg-voidcrew\SQL\PHASE0_IMPLEMENTATION_SUMMARY.md` (this file)

### Modified
- `C:\Users\isaac\code\tg-voidcrew\SQL\database_changelog.md` (added v5.33 entry)
- `C:\Users\isaac\code\tg-voidcrew\code\__DEFINES\subsystems.dm` (DB_MINOR_VERSION 32 → 33)

## Migration Instructions

### For Database Administrators

1. **Backup your database** before applying any changes

2. **Run the migration script**:
   ```bash
   mysql -u username -p database_name < SQL/ship_economy_phase0_migration.sql
   ```

3. **Update schema revision** (choose one based on your prefix setup):
   ```sql
   INSERT INTO `schema_revision` (`major`, `minor`) VALUES (5, 33);
   ```
   OR with prefix:
   ```sql
   INSERT INTO `SS13_schema_revision` (`major`, `minor`) VALUES (5, 33);
   ```

4. **Verify tables were created**:
   ```sql
   SHOW TABLES LIKE '%ship%';
   ```

### For Developers

The code changes are already complete:
- ✅ DB_MINOR_VERSION updated to 33
- ✅ Migration script created
- ✅ Changelog updated

Next steps for Phase 1 (code implementation):
- Create DM datum structures for these tables
- Implement CRUD operations
- Add admin verbs for economy management
- Create player UI for viewing economy

## Design Decisions & Rationale

### Combined vs Separate Tables
- **Credits**: Separate `player_ship_economy` table (future-proof for additional economy fields)
- **Parts**: Separate `player_ship_parts` table (allows individual part metadata and stacking)

### Why 6 Tables Instead of 8?
Original proposal had 8 tables. User decisions reduced this:
- ❌ No character_slot tracking → Removed per-character tables
- ❌ No anomaly detection → Removed detection/flagging tables
- ✅ Kept core functionality: economy, unlocks, tracking, queue, logging

### Metadata Field Design
Used TEXT fields for flexible JSON storage in:
- `player_ship_parts.metadata` - Part-specific attributes
- `pending_extractions.ship_data` - Full ship serialization

This allows schema flexibility without constant migrations.

### Index Strategy
Indexes added for common query patterns:
- Player lookups (ckey indexes)
- Round analytics (round_id indexes)
- Admin tools (target_ckey, processed flags)
- Compound indexes for common joins (ckey + part_type)

## Notes & Warnings

### ⚠️ Important Considerations

1. **No Foreign Key Constraints**: Following existing schema patterns, no FK constraints are defined. This is intentional for flexibility but requires careful application-level data integrity.

2. **LONGTEXT for ship_data**: The `pending_extractions.ship_data` field uses LONGTEXT. Large ships may require optimization or chunking.

3. **JSON in TEXT fields**: The `metadata` fields store JSON but as TEXT type, not native JSON. This is for compatibility with older MySQL versions.

4. **Round ID Nullability**: Round IDs can be NULL (server startup before rounds exist). Always handle NULL in queries.

5. **No Cascading Deletes**: Deleting a player won't auto-delete their economy data. Consider adding cleanup procedures if needed.

## Testing Checklist

Before deploying to production:

- [ ] Verify migration applies cleanly to test database
- [ ] Test schema revision update
- [ ] Insert test data into each table
- [ ] Query test data to verify indexes work
- [ ] Test NULL handling for nullable fields
- [ ] Verify ENUM values are enforced
- [ ] Check UNIQUE constraints prevent duplicates
- [ ] Test TIMESTAMP auto-update behavior

## Future Phases

This Phase 0 implementation provides the foundation for:

- **Phase 1**: DM code implementation (datums, procs, verbs)
- **Phase 2**: UI implementation (TGUI interfaces)
- **Phase 3**: Game integration (spawning, extraction, economy)
- **Phase 4**: Admin tools and management interfaces

## Questions or Issues?

Contact the implementing developer or refer to:
- Original design documents in `docs/` directory
- User decision summaries
- Database changelog for version history
