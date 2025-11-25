-- Ship Economy System - Phase 0 Database Migration
-- Version 5.33, 24 November 2025
-- Updated to match ship_economy_database.dm implementation
--
-- IMPORTANT: Uses SS13_ prefix to match dbconfig.txt FEEDBACK_TABLEPREFIX
--
-- This migration creates the core tables for:
-- - Account-wide credits (SS13_player_ship_credits)
-- - Account-wide ship parts inventory by rarity (SS13_player_ship_parts)
-- - Ship blueprint unlocks (SS13_player_ship_unlocks)
-- - Pending extraction queue (SS13_pending_ship_extractions)
-- - Extraction audit log (SS13_ship_extraction_log)
--
-- To apply this migration:
-- 1. First run SQL/tgstation_schema_prefixed.sql for base tables
-- 2. Then run this script on your database

-- =============================================================================
-- Table: SS13_player_ship_credits
-- Purpose: Stores account-wide credits balance
-- =============================================================================

DROP TABLE IF EXISTS `SS13_player_ship_credits`;
CREATE TABLE `SS13_player_ship_credits` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `ckey` VARCHAR(32) NOT NULL,
  `credits` INT(11) UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Account-wide currency balance',
  `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_ship_credits_ckey` (`ckey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- =============================================================================
-- Table: SS13_player_ship_parts
-- Purpose: Stores ship parts inventory by rarity tier (account-wide)
-- Each row represents a ckey + rarity combination with quantity
-- =============================================================================

DROP TABLE IF EXISTS `SS13_player_ship_parts`;
CREATE TABLE `SS13_player_ship_parts` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `ckey` VARCHAR(32) NOT NULL,
  `part_rarity` ENUM('common', 'uncommon', 'rare', 'epic', 'legendary') NOT NULL DEFAULT 'common',
  `quantity` INT(11) UNSIGNED NOT NULL DEFAULT 0,
  `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_ship_parts_ckey_rarity` (`ckey`, `part_rarity`),
  KEY `idx_ship_parts_ckey` (`ckey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- =============================================================================
-- Table: SS13_player_ship_unlocks
-- Purpose: Tracks which ship blueprints/designs each player has unlocked
-- =============================================================================

DROP TABLE IF EXISTS `SS13_player_ship_unlocks`;
CREATE TABLE `SS13_player_ship_unlocks` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `ckey` VARCHAR(32) NOT NULL,
  `ship_template_path` VARCHAR(255) NOT NULL COMMENT 'DM type path of ship template',
  `unlocked_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_ship_unlock_unique` (`ckey`, `ship_template_path`),
  KEY `idx_ship_unlock_ckey` (`ckey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- =============================================================================
-- Table: SS13_pending_ship_extractions
-- Purpose: Queue for part extractions that failed and need retry
-- =============================================================================

DROP TABLE IF EXISTS `SS13_pending_ship_extractions`;
CREATE TABLE `SS13_pending_ship_extractions` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `ckey` VARCHAR(32) NOT NULL,
  `part_rarity` ENUM('common', 'uncommon', 'rare', 'epic', 'legendary') NOT NULL,
  `part_uid` VARCHAR(64) NULL COMMENT 'Unique identifier for tracking the physical part',
  `queued_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `retry_count` INT(11) UNSIGNED NOT NULL DEFAULT 0,
  `last_retry_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pending_ext_ckey` (`ckey`),
  KEY `idx_pending_ext_retry` (`retry_count`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- =============================================================================
-- Table: SS13_ship_extraction_log
-- Purpose: Audit trail for part extractions (analytics/debugging)
-- =============================================================================

DROP TABLE IF EXISTS `SS13_ship_extraction_log`;
CREATE TABLE `SS13_ship_extraction_log` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `ckey` VARCHAR(32) NOT NULL,
  `part_rarity` ENUM('common', 'uncommon', 'rare', 'epic', 'legendary') NOT NULL,
  `extraction_location` VARCHAR(255) NULL COMMENT 'Where the part was extracted from',
  `part_uid` VARCHAR(64) NULL COMMENT 'Unique identifier of part',
  `extraction_timestamp` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_extract_log_ckey` (`ckey`),
  KEY `idx_extract_log_time` (`extraction_timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- =============================================================================
-- Migration Complete
-- =============================================================================
