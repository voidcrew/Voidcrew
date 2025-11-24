-- Ship Economy System - Phase 0 Database Migration
-- Version 5.33, 23 November 2025
-- Adds ship economy persistence tables for own-your-ship feature
--
-- This migration creates the core tables for:
-- - Account-wide credits and ship parts inventory
-- - Ship blueprint unlocks
-- - Per-round ship spawn tracking
-- - Failed extraction queue management
-- - Minimal admin action logging
--
-- To apply this migration:
-- 1. Run this script on your database
-- 2. Update DB_MINOR_VERSION in code/__DEFINES/subsystems.dm to 33
-- 3. Insert the schema revision record (see below)

-- Schema revision update query:
-- INSERT INTO `schema_revision` (`major`, `minor`) VALUES (5, 33);
-- or with prefix:
-- INSERT INTO `SS13_schema_revision` (`major`, `minor`) VALUES (5, 33);

-- =============================================================================
-- Table: player_ship_economy
-- Purpose: Stores account-wide credits and ship parts inventory
-- Key Design: Combined economy table (credits + parts) per user decision Q1
-- =============================================================================

DROP TABLE IF EXISTS `player_ship_economy`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `player_ship_economy` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `ckey` VARCHAR(32) NOT NULL,
  `credits` INT(11) UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Account-wide currency balance',
  `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_ship_econ_ckey` (`ckey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

-- =============================================================================
-- Table: player_ship_parts
-- Purpose: Stores individual ship parts/components in player inventory
-- Key Design: Separate table for parts with rarity system per user decision Q2
-- =============================================================================

DROP TABLE IF EXISTS `player_ship_parts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `player_ship_parts` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `ckey` VARCHAR(32) NOT NULL,
  `part_type` VARCHAR(64) NOT NULL COMMENT 'Type identifier for the ship part',
  `part_subtype` VARCHAR(64) NULL DEFAULT NULL COMMENT 'Optional subtype/variant',
  `rarity` ENUM('common', 'uncommon', 'rare', 'epic', 'legendary') NOT NULL DEFAULT 'common',
  `quantity` INT(11) UNSIGNED NOT NULL DEFAULT 1,
  `metadata` TEXT NULL DEFAULT NULL COMMENT 'JSON for any additional part-specific data',
  `acquired_datetime` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ship_parts_ckey` (`ckey`),
  KEY `idx_ship_parts_ckey_type` (`ckey`, `part_type`),
  KEY `idx_ship_parts_rarity` (`rarity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

-- =============================================================================
-- Table: player_ship_unlocks
-- Purpose: Tracks which ship blueprints/designs each player has unlocked
-- Key Design: Simple unlock tracking system
-- =============================================================================

DROP TABLE IF EXISTS `player_ship_unlocks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `player_ship_unlocks` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `ckey` VARCHAR(32) NOT NULL,
  `blueprint_id` VARCHAR(64) NOT NULL COMMENT 'Unique identifier for ship blueprint',
  `unlock_datetime` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_ship_unlock_unique` (`ckey`, `blueprint_id`),
  KEY `idx_ship_unlock_ckey` (`ckey`),
  KEY `idx_ship_unlock_blueprint` (`blueprint_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

-- =============================================================================
-- Table: round_ship_spawns
-- Purpose: Tracks which ships were spawned in each round
-- Key Design: Per-round tracking for ship usage analytics
-- =============================================================================

DROP TABLE IF EXISTS `round_ship_spawns`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `round_ship_spawns` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `round_id` INT(11) UNSIGNED NULL,
  `server_ip` INT(10) UNSIGNED NOT NULL,
  `server_port` SMALLINT(5) UNSIGNED NOT NULL,
  `ckey` VARCHAR(32) NOT NULL,
  `blueprint_id` VARCHAR(64) NOT NULL,
  `spawn_datetime` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `extracted` TINYINT(1) UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Whether ship was successfully extracted',
  `extraction_datetime` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_round_ships_round` (`round_id`),
  KEY `idx_round_ships_ckey` (`ckey`),
  KEY `idx_round_ships_extracted` (`extracted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

-- =============================================================================
-- Table: pending_extractions
-- Purpose: Queue for ships that failed to extract (server crash, etc.)
-- Key Design: Per user decision Q4 - queue for failed extractions
-- =============================================================================

DROP TABLE IF EXISTS `pending_extractions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `pending_extractions` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `round_spawn_id` INT(11) NOT NULL COMMENT 'FK to round_ship_spawns.id',
  `ckey` VARCHAR(32) NOT NULL,
  `ship_data` LONGTEXT NOT NULL COMMENT 'Serialized ship state data',
  `extraction_type` ENUM('normal', 'crash', 'timeout', 'admin') NOT NULL DEFAULT 'crash',
  `queued_datetime` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `processed` TINYINT(1) UNSIGNED NOT NULL DEFAULT 0,
  `processed_datetime` DATETIME NULL DEFAULT NULL,
  `processing_notes` TEXT NULL DEFAULT NULL COMMENT 'Admin notes or processing results',
  PRIMARY KEY (`id`),
  KEY `idx_pending_ext_ckey` (`ckey`),
  KEY `idx_pending_ext_processed` (`processed`),
  KEY `idx_pending_ext_spawn` (`round_spawn_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

-- =============================================================================
-- Table: ship_economy_admin_log
-- Purpose: Minimal logging of admin actions on ship economy
-- Key Design: Per user decision Q6 - minimal logging only
-- =============================================================================

DROP TABLE IF EXISTS `ship_economy_admin_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ship_economy_admin_log` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `datetime` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `round_id` INT(11) UNSIGNED NULL,
  `admin_ckey` VARCHAR(32) NOT NULL,
  `target_ckey` VARCHAR(32) NOT NULL,
  `action` ENUM('grant_credits', 'remove_credits', 'grant_part', 'remove_part', 'grant_unlock', 'remove_unlock', 'reset_economy', 'process_extraction', 'other') NOT NULL,
  `details` VARCHAR(1000) NOT NULL COMMENT 'Description of admin action',
  `old_value` VARCHAR(255) NULL DEFAULT NULL COMMENT 'Previous value (if applicable)',
  `new_value` VARCHAR(255) NULL DEFAULT NULL COMMENT 'New value (if applicable)',
  PRIMARY KEY (`id`),
  KEY `idx_ship_admin_log_target` (`target_ckey`),
  KEY `idx_ship_admin_log_admin` (`admin_ckey`),
  KEY `idx_ship_admin_log_datetime` (`datetime`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

-- =============================================================================
-- Migration Complete
-- =============================================================================
-- Remember to update the schema_revision table and DB_MINOR_VERSION define!
