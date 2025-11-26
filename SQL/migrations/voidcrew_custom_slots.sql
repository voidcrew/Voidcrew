-- Migration: Custom Loadout Slots System
-- Description: Adds support for 3 custom loadout slots per account with per-round equipment tracking
-- Date: 2025-11-25
--
-- System Design:
-- - 3 slots max per account (1 free, 2 purchasable for 10k/25k credits)
-- - Players can name their slots
-- - Each slot has: name, access preset, enabled status
-- - CLOTHES = permanent unlocks via player_loadout_purchases (no changes needed)
-- - EQUIPMENT = per-round consumables via player_custom_slot_equipment (resets each round)

-- Table: player_custom_slots
-- Stores slot unlocks, names, and access configurations
-- Slot 1 is free (always unlocked), slots 2 and 3 require purchase (10k and 25k credits respectively)
CREATE TABLE IF NOT EXISTS `player_custom_slots` (
  `ckey` VARCHAR(32) NOT NULL COMMENT 'Player canonical key',
  `slot_index` INT NOT NULL COMMENT 'Slot number: 1 (free), 2 (10k credits), or 3 (25k credits)',
  `slot_name` VARCHAR(64) NOT NULL DEFAULT '' COMMENT 'Player-defined name for this slot',
  `access_preset` VARCHAR(32) NOT NULL DEFAULT '' COMMENT 'Access level preset (engineer, medical, security, etc)',
  `loadout_json` TEXT NULL COMMENT 'JSON-encoded loadout configuration for this slot',
  `is_default` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Whether this is the default slot for spawning',
  `overwrite_spawn` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'If TRUE, always use this slot config regardless of job',
  `unlocked` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Whether this slot is unlocked (slot 1 always TRUE)',
  `unlock_date` DATETIME NULL DEFAULT NULL COMMENT 'When this slot was unlocked',
  PRIMARY KEY (`ckey`, `slot_index`),
  INDEX `idx_ckey` (`ckey`),
  INDEX `idx_unlocked` (`unlocked`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='Stores custom loadout slot configurations';

-- Add columns if table already exists (for migrations)
ALTER TABLE `player_custom_slots` ADD COLUMN IF NOT EXISTS `loadout_json` TEXT NULL COMMENT 'JSON-encoded loadout configuration for this slot' AFTER `access_preset`;
ALTER TABLE `player_custom_slots` ADD COLUMN IF NOT EXISTS `is_default` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Whether this is the default slot for spawning' AFTER `loadout_json`;
ALTER TABLE `player_custom_slots` ADD COLUMN IF NOT EXISTS `overwrite_spawn` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'If TRUE, always use this slot config regardless of job' AFTER `is_default`;

-- Table: player_custom_slot_equipment
-- Tracks equipment purchased for each slot per round
-- Equipment is consumable and resets each round
CREATE TABLE IF NOT EXISTS `player_custom_slot_equipment` (
  `id` INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Auto-incrementing primary key',
  `ckey` VARCHAR(32) NOT NULL COMMENT 'Player canonical key',
  `slot_index` INT NOT NULL COMMENT 'Which custom slot this equipment belongs to',
  `round_id` VARCHAR(32) NOT NULL COMMENT 'Current round identifier',
  `item_path` VARCHAR(255) NOT NULL COMMENT 'DM path of the purchased item',
  `purchase_date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When this item was purchased',
  KEY `idx_ckey_slot_round` (`ckey`, `slot_index`, `round_id`),
  KEY `idx_round_id` (`round_id`),
  KEY `idx_ckey` (`ckey`),
  FOREIGN KEY (`ckey`, `slot_index`)
    REFERENCES `player_custom_slots`(`ckey`, `slot_index`)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='Tracks per-round equipment purchases for custom slots';

-- Create additional indexes for efficient querying
CREATE INDEX `idx_equipment_lookup` ON `player_custom_slot_equipment` (`ckey`, `slot_index`, `round_id`);
CREATE INDEX `idx_purchase_date` ON `player_custom_slot_equipment` (`purchase_date`);

-- Optional: Initialize slot 1 for all existing players who have used the loadout system
-- This ensures everyone gets their free slot automatically
INSERT INTO `player_custom_slots` (`ckey`, `slot_index`, `slot_name`, `access_preset`, `unlocked`, `unlock_date`)
SELECT DISTINCT
  `ckey`,
  1 as `slot_index`,
  'Custom Slot 1' as `slot_name`,
  '' as `access_preset`,
  TRUE as `unlocked`,
  CURRENT_TIMESTAMP as `unlock_date`
FROM `player_loadout_purchases`
WHERE NOT EXISTS (
  SELECT 1 FROM `player_custom_slots` pcs
  WHERE pcs.`ckey` = `player_loadout_purchases`.`ckey`
  AND pcs.`slot_index` = 1
)
ON DUPLICATE KEY UPDATE `unlocked` = TRUE;
