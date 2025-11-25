-- Player Shop Purchases Table
-- Tracks permanent item purchases from the Voidcrew player shop system
-- Uses ship credits (not metacoins) for purchases

CREATE TABLE `player_shop_purchases` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `ckey` VARCHAR(32) NOT NULL,
  `item_id` VARCHAR(255) NOT NULL,
  `purchase_date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `amount` INT(11) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ckey_item` (`ckey`, `item_id`),
  KEY `idx_ckey` (`ckey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
