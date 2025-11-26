-- Player Loadout Purchases Table
-- Tracks purchased loadout items in the Voidcrew system
-- Items with requires_purchase = TRUE must have a record here to be selectable

CREATE TABLE IF NOT EXISTS `player_loadout_purchases` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `ckey` VARCHAR(32) NOT NULL,
  `item_path` VARCHAR(255) NOT NULL,
  `purchase_date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ckey_item` (`ckey`, `item_path`),
  KEY `idx_ckey` (`ckey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
