-- Ship Economy Tables Migration
-- Run this SQL to create the ship parts/credits system tables
-- Note: Table names have NO prefix (matches FEEDBACK_TABLEPREFIX config)

-- =====================================================
-- MIGRATION: Rarity -> Class System
-- =====================================================
-- If upgrading from rarity-based system, run these first:
-- This will CLEAR existing parts data and update schema

-- Drop old rarity-based data and recreate with class system
DROP TABLE IF EXISTS `player_ship_parts`;

-- =====================================================
-- TABLE DEFINITIONS
-- =====================================================

-- Account-wide credits
CREATE TABLE IF NOT EXISTS `player_ship_credits` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `ckey` VARCHAR(32) NOT NULL,
    `credits` INT(11) NOT NULL DEFAULT 0,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `ckey` (`ckey`),
    INDEX `idx_ckey` (`ckey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Account-wide parts inventory (by class)
CREATE TABLE IF NOT EXISTS `player_ship_parts` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `ckey` VARCHAR(32) NOT NULL,
    `part_class` ENUM('combat', 'science', 'trade', 'misc') NOT NULL,
    `quantity` INT(11) NOT NULL DEFAULT 0,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `ckey_class` (`ckey`, `part_class`),
    INDEX `idx_ckey` (`ckey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Permanent ship blueprint unlocks
CREATE TABLE IF NOT EXISTS `player_ship_unlocks` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `ckey` VARCHAR(32) NOT NULL,
    `ship_template_path` VARCHAR(255) NOT NULL,
    `unlocked_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `ckey_ship` (`ckey`, `ship_template_path`),
    INDEX `idx_ckey` (`ckey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Pending extractions queue (for failed extraction retry)
CREATE TABLE IF NOT EXISTS `pending_ship_extractions` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `ckey` VARCHAR(32) NOT NULL,
    `part_class` ENUM('combat', 'science', 'trade', 'misc') NOT NULL,
    `part_uid` VARCHAR(64) DEFAULT NULL,
    `queued_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `last_retry_at` DATETIME DEFAULT NULL,
    `retry_count` INT(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    INDEX `idx_ckey` (`ckey`),
    INDEX `idx_retry` (`retry_count`, `queued_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Extraction audit log
CREATE TABLE IF NOT EXISTS `ship_extraction_log` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `ckey` VARCHAR(32) NOT NULL,
    `part_class` ENUM('combat', 'science', 'trade', 'misc') NOT NULL,
    `extraction_location` VARCHAR(128) DEFAULT NULL,
    `part_uid` VARCHAR(64) DEFAULT NULL,
    `extraction_timestamp` DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_ckey` (`ckey`),
    INDEX `idx_timestamp` (`extraction_timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
