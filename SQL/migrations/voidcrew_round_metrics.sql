-- Round metrics (voidcrew/modules/metrics): one row per recorded event, used for balance work.
-- Apply once, then the game starts writing rows on its next round. Schema version 5.34.

CREATE TABLE IF NOT EXISTS `round_metric` (
  `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `round_id` INT(11) NOT NULL,
  `round_seconds` INT(11) NOT NULL,
  `datetime` DATETIME NOT NULL,
  `category` VARCHAR(32) NOT NULL,
  `event` VARCHAR(64) NOT NULL,
  `ckey` VARCHAR(32) NULL,
  `other_ckey` VARCHAR(32) NULL,
  `ship_id` VARCHAR(64) NULL,
  `ship_name` VARCHAR(128) NULL,
  `ship_class` VARCHAR(128) NULL,
  `zone` VARCHAR(8) NULL,
  `subject` VARCHAR(255) NULL,
  `credits` INT(11) NOT NULL DEFAULT 0,
  `vouchers` INT(11) NOT NULL DEFAULT 0,
  `points` INT(11) NOT NULL DEFAULT 0,
  `quantity` INT(11) NOT NULL DEFAULT 0,
  `details` TEXT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_round_event` (`round_id`, `category`, `event`),
  KEY `idx_ckey_round` (`ckey`, `round_id`),
  KEY `idx_event_datetime` (`event`, `datetime`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `schema_revision` (`major`, `minor`) VALUES (5, 34);
