-- Ship Credit Audit Log
-- Companion to voidcrew_ship_parts.sql: the credit-side audit trail that the
-- transaction helpers in code/modules/ship_purchase/transaction_helpers.dm write to.
-- Credits are account-wide (ckey only, no character slot), matching player_ship_credits.

-- Credit transaction audit trail (spends, refunds, grants)
CREATE TABLE IF NOT EXISTS `ship_credit_log` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `ckey` VARCHAR(32) NOT NULL,
  `amount` INT(11) NOT NULL,
  `reason` VARCHAR(255),
  `balance_after` INT(11),
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ckey` (`ckey`),
  KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
