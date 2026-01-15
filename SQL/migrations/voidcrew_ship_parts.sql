-- Ship Economy Tables
-- Account-wide ship parts, credits, unlocks, and upgrade unlocks

-- Player ship credits (account-wide)
CREATE TABLE IF NOT EXISTS `player_ship_credits` (
  `ckey` VARCHAR(32) NOT NULL,
  `credits` INT(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`ckey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Player ship parts inventory (by class: combat, science, trade, misc)
CREATE TABLE IF NOT EXISTS `player_ship_parts` (
  `ckey` VARCHAR(32) NOT NULL,
  `part_class` VARCHAR(32) NOT NULL,
  `quantity` INT(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`ckey`, `part_class`),
  KEY `idx_ckey` (`ckey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Player ship unlocks (permanent blueprint unlocks)
CREATE TABLE IF NOT EXISTS `player_ship_unlocks` (
  `ckey` VARCHAR(32) NOT NULL,
  `ship_template_path` VARCHAR(255) NOT NULL,
  `unlock_date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`ckey`, `ship_template_path`),
  KEY `idx_ckey` (`ckey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Player upgrade unlocks (permanent upgrade module unlocks)
CREATE TABLE IF NOT EXISTS `player_upgrade_unlocks` (
  `ckey` VARCHAR(32) NOT NULL,
  `ship_template` VARCHAR(255) NOT NULL,
  `upgrade_id` VARCHAR(64) NOT NULL,
  `unlock_date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`ckey`, `ship_template`, `upgrade_id`),
  KEY `idx_ckey` (`ckey`),
  KEY `idx_ship` (`ship_template`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Player theme unlocks (permanent ship theme unlocks)
CREATE TABLE IF NOT EXISTS `player_theme_unlocks` (
  `ckey` VARCHAR(32) NOT NULL,
  `ship_template` VARCHAR(255) NOT NULL,
  `theme_id` VARCHAR(64) NOT NULL,
  `unlock_date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`ckey`, `ship_template`, `theme_id`),
  KEY `idx_ckey` (`ckey`),
  KEY `idx_ship` (`ship_template`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Pending ship extractions queue (for failed extraction retry)
CREATE TABLE IF NOT EXISTS `pending_ship_extractions` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `ckey` VARCHAR(32) NOT NULL,
  `part_class` VARCHAR(32) NOT NULL,
  `part_uid` VARCHAR(255),
  `queued_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_retry_at` DATETIME,
  `retry_count` INT(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_ckey` (`ckey`),
  KEY `idx_retry` (`retry_count`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Ship extraction log (audit trail)
CREATE TABLE IF NOT EXISTS `ship_extraction_log` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `ckey` VARCHAR(32) NOT NULL,
  `part_class` VARCHAR(32) NOT NULL,
  `extraction_location` VARCHAR(255),
  `part_uid` VARCHAR(255),
  `extraction_timestamp` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ckey` (`ckey`),
  KEY `idx_timestamp` (`extraction_timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
