-- Ship saving (voidcrew/modules/ship_saves): one row per used save slot. Schema version 5.35.
-- A save is removed when it is used, so this table needs no purge job.

CREATE TABLE IF NOT EXISTS `player_ship_saves` (
  `ckey` VARCHAR(32) NOT NULL,
  `slot` TINYINT(3) UNSIGNED NOT NULL,
  `ship_name` VARCHAR(128) NOT NULL,
  `ship_class` VARCHAR(128) NULL,
  `tile_count` SMALLINT(5) UNSIGNED NOT NULL,
  `format_version` SMALLINT(5) UNSIGNED NOT NULL,
  `saved_round` INT(11) NOT NULL,
  `saved_at` DATETIME NOT NULL,
  `raw_bytes` INT(10) UNSIGNED NOT NULL,
  `summary` TEXT NULL,
  `payload` MEDIUMBLOB NOT NULL,
  PRIMARY KEY (`ckey`, `slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `schema_revision` (`major`, `minor`) VALUES (5, 35);
