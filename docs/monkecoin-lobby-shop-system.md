# Monkecoin & Lobby Clothes Shop System Documentation

This document provides a comprehensive technical reference for the Monkecoin currency system and the Lobby Clothes Shop (Pre-Round Store) in the Monkestation 2.0 codebase.

---

## Table of Contents

1. [Overview](#overview)
2. [Monkecoin System](#monkecoin-system)
   - [How Monkecoins Are Earned](#how-monkecoins-are-earned)
   - [Donator Bonuses & Multipliers](#donator-bonuses--multipliers)
   - [Storage & Persistence](#storage--persistence)
   - [Configuration & Balance Settings](#configuration--balance-settings)
3. [Lobby Clothes Shop (Pre-Round Store)](#lobby-clothes-shop-pre-round-store)
   - [System Architecture](#system-architecture)
   - [Purchase Flow](#purchase-flow)
   - [Item Categories](#item-categories)
   - [Item Restrictions](#item-restrictions)
   - [Example Prices](#example-prices)
4. [ATM System](#atm-system)
5. [Loadout System Integration](#loadout-system-integration)
6. [Database Schema](#database-schema)
7. [Key File Locations](#key-file-locations)
8. [Admin Tools](#admin-tools)
9. [Anti-Exploit Measures](#anti-exploit-measures)

---

## Overview

The Monkestation 2.0 codebase implements a **meta-currency system** called "Monkecoins" that exists outside of the normal in-game credit economy. Monkecoins are earned through gameplay and can be spent on cosmetic items in the **Pre-Round Store** (Lobby Clothes Shop). This creates a persistent progression system that rewards continued engagement.

**Key Distinction:**
- **Credits (cr)**: In-game currency earned through paychecks, used at vending machines during rounds
- **Monkecoins**: Meta-currency persisted across rounds, used for permanent cosmetic unlocks

---

## Monkecoin System

### How Monkecoins Are Earned

Monkecoins are primarily awarded at **roundend** based on various factors:

| Source | Amount | Notes |
|--------|--------|-------|
| Base Roundend Reward | 100 | Given to all players who completed the round |
| MRP2 Server Bonus | +500 | Playing on the MRP2 server |
| Mentor Bonus | 200 | For mentors |
| Mentor + Head of Staff | 300 | For mentors who are also heads of staff |
| Department/Job Bonus | +225 | Security, Silicon departments, or Janitor job |
| Station Goal Completion | ~50,000 (split) | Distributed evenly if 10+ players |
| Challenge Rewards | Variable | Based on completed challenges |
| Cassette Submission Refund | 5,000 | If cassette review not completed by roundend |

**Source File:** `code/__HELPERS/~monkestation-helpers/roundend.dm`

### Donator Bonuses & Multipliers

Players with Patreon or Twitch subscriptions receive additional bonuses:

**Flat Bonuses (additive):**
| Tier | Bonus |
|------|-------|
| Twitch Tier 1 Subscriber | +25 |
| Patreon Assistant Tier | +25 |
| Patreon Nuke Tier | +25 |

**Multipliers (on earned coins):**
| Patreon Rank | Multiplier |
|--------------|------------|
| Command Rank | 1.5x |
| Traitor Rank | 2.0x |
| Nukie Rank | 3.0x |

**Source File:** `monkestation/code/modules/client/preferences/inventory.dm` (lines 45-52)

```dm
if(amount > 0 && donator_multiplier)
    switch(parent.persistent_client.patreon.access_rank)
        if(ACCESS_COMMAND_RANK)
            amount *= 1.5
        if(ACCESS_TRAITOR_RANK)
            amount *= 2
        if(ACCESS_NUKIE_RANK)
            amount *= 3
```

### Storage & Persistence

**Client-Side:**
- Loaded during character preferences via `load_metacoins()` function
- Stored in `client.prefs.metacoins` variable
- Default value: 5,000 monkecoins for new players
- Roundend bonus staged in `persistent_client.roundend_monkecoin_bonus` before distribution

**Database:**
- Primary storage in MySQL `player` table
- Column: `metacoins` (int, unsigned, default 0)
- Purchases tracked in `metacoin_item_purchases` table

### Configuration & Balance Settings

**Key Defines** (`code/__DEFINES/~monkestation/metacoins.dm`):
```dm
#define DONATOR_ROUNDEND_BONUS 25    // Flat bonus for donators
#define LOOTBOX_COST 5000            // Lootbox purchase cost
```

**Round Cap System:**
- `max_round_coins` variable tracks coins earned in current shift
- Prevents earning more than cap per round with `respects_roundcap` parameter
- Some rewards (donator bonus, mentors) respect this cap

**Configurable Job/Department Bonuses** (`code/controllers/subsystem/ticker.dm`, lines 84-87):
```dm
var/list/bitflags_to_reward = list(
    DEPARTMENT_BITFLAG_SECURITY,
    DEPARTMENT_BITFLAG_SILICON
)
var/list/jobs_to_reward = list(JOB_JANITOR)
```

---

## Lobby Clothes Shop (Pre-Round Store)

### System Architecture

The Pre-Round Store is a **TGUI-based interface** accessible from the lobby before round start. It allows players to purchase cosmetic items with Monkecoins.

**Components:**
1. **Backend Store Handler:** `monkestation/code/modules/store/pre_round/_pre_round_store.dm`
2. **Store Item Definitions:** `monkestation/code/modules/store/store_items/` (17+ category files)
3. **TGUI Interface:** `tgui/packages/tgui/interfaces/PreRoundStore.tsx`
4. **Loadout Integration:** `tgui/packages/tgui/interfaces/PreferencesMenu/LoadoutPage.tsx`

**Store Item Base Datum** (`monkestation/code/modules/store/store_items/__store.dm`):
```dm
/datum/store_item
    var/name = "Store Item"
    var/item_path                    // Path to the item object
    var/item_cost = 0                // Cost in Monkecoins
    var/category = LOADOUT_ITEM_MISC // Loadout category
    var/one_time_buy = FALSE         // If TRUE, only purchasable once per round
    var/requires_purchase = TRUE     // If TRUE, must be bought before equipping
    var/donator_only = FALSE         // If TRUE, requires donator status
    var/list/ckeywhitelist           // List of ckeys allowed to purchase
    var/list/restricted_roles        // List of jobs that can use this item
```

### Purchase Flow

1. **Player opens Preferences Menu** in lobby
2. **Navigate to Loadout section**
3. **Click store button** (sack-dollar icon) to open PreRoundStore
4. **Browse available items** by category
5. **Click "Buy"** on desired item
6. **Backend validates:**
   - `has_coins(amount)` - Does player have sufficient balance?
   - Check `inventory` list - Does player already own this item?
   - Check restrictions (donator_only, ckeywhitelist, etc.)
7. **If valid:**
   - Deduct monkecoins via `adjust_metacoins(ckey, -item_cost, reason)`
   - Add item to player's permanent inventory
   - Record purchase in `metacoin_item_purchases` database table
8. **Item appears in Loadout** for equipping in future rounds

**Key Functions:**
```dm
// Check if player has enough coins
/datum/preferences/proc/has_coins(amount)

// Adjust player's monkecoin balance
/datum/preferences/proc/adjust_metacoins(ckey, amount, reason, donator_multiplier = FALSE)
```

### Item Categories

The store organizes items into these loadout categories:

| Category | Description | Max Items |
|----------|-------------|-----------|
| Belt | Belt slot items | - |
| Ear | Earwear (headsets, earrings) | - |
| Glasses | Eyewear | - |
| Gloves | Hand coverings | - |
| Head | Hats, helmets, headwear | - |
| Mask | Face coverings | - |
| Neck | Scarves, necklaces, ties | - |
| Shoes | Footwear | - |
| Suit | Outerwear, coats, armor | - |
| Uniform | Jumpsuits, undersuits | - |
| Formal | Formal attire | - |
| Accessories | Misc accessories | - |
| In-Hand | Items held in hand | - |
| Toys | Toy items | 5 max |
| Plushies | Plush toys | 10 max |
| Pocket | Pocket items | - |
| Effects | Special transformations/effects | - |
| Unusual | Unusual/rare hats | - |

### Item Restrictions

Items can have various restrictions applied:

| Restriction | Description |
|-------------|-------------|
| `requires_purchase` | Item must be bought before it can be equipped |
| `donator_only` | Requires active Patreon/Twitch donor status |
| `ckeywhitelist` | Only specific ckeys can purchase |
| `restricted_roles` | Only certain job roles can equip |
| `one_time_buy` | Can only be purchased once per round (not permanent) |

### Example Prices

**Head Items** (`store_items/head.dm`):
| Item | Cost |
|------|------|
| Recolorable Beanie | 4,000 |
| Greyscale Beret | 2,500 |
| Rastafarian Cap | 4,000 |

**Plushies** (`store_items/plushies.dm`):
| Item | Cost |
|------|------|
| Bee Plushie | 7,500 |
| Cirno Plush | 10,000 |
| Basic Plushies | 2,500 |

**General Range:** 1,500 - 10,000 Monkecoins depending on item rarity/desirability

---

## ATM System

The ATM provides an in-game interface for managing monkecoins.

**Source File:** `monkestation/code/modules/store/atm/_atm.dm`

**Features:**
| Feature | Description |
|---------|-------------|
| Withdraw | Convert monkecoins to physical coin stacks (`/obj/item/stack/monkecoin`) |
| Deposit | Convert physical coins back to account balance |
| Buy Lootbox | Purchase lootbox for 5,000 monkecoins |
| Flash Sales | Purchase special rotating deal items |

**Physical Coin Item:** `/obj/item/stack/monkecoin`
- Stackable item with value tracking
- Can be traded between players
- Depositable back into ATM

---

## Loadout System Integration

The loadout system allows players to select purchased cosmetics to spawn with at round start.

**Source Files:**
- Backend: `monkestation/code/modules/loadouts/`
- UI: `tgui/packages/tgui/interfaces/PreferencesMenu/LoadoutPage.tsx`

**Loadout Page Features:**
- Character preview (left side)
- Total Monkecoins balance display (top right)
- Category tabs for browsing items
- Per-item controls:
  - **Selection checkbox** - Equip/unequip for round start
  - **Color picker** (palette icon) - For greyscale/recolorable items
  - **Name button** (pen icon) - For renamable items
  - **Lock icon** - Indicates job-restricted items
  - **Heart icon** - Indicates donator-only items

**At Round Start:**
- Selected cosmetics spawn in backpack or equipped slots
- Effect granters apply special effects to the player

---

## Database Schema

### Player Table (relevant columns)
```sql
CREATE TABLE `player` (
  `ckey` varchar(32) NOT NULL,
  `metacoins` int(10) unsigned NOT NULL DEFAULT '0',
  `twitch_rank` VARCHAR(32),
  `twitch_user` VARCHAR(32),
  `patreon_key` VARCHAR(32),
  `patreon_rank` VARCHAR(32),
  PRIMARY KEY (`ckey`)
);
```

### Metacoin Item Purchases Table
```sql
CREATE TABLE `metacoin_item_purchases` (
  `ckey` varchar(32) NOT NULL,
  `purchase_date` datetime NOT NULL,
  `item_id` varchar(50) NOT NULL,
  `amount` tinyint(4) unsigned NOT NULL,
  PRIMARY KEY (`ckey`, `item_id`)
);
```

**Source File:** `SQL/tgstation_schema.sql`

---

## Key File Locations

### Monkecoin System
| File | Purpose |
|------|---------|
| `code/__DEFINES/~monkestation/metacoins.dm` | Constants and defines |
| `code/__HELPERS/~monkestation-helpers/roundend.dm` | Roundend reward logic |
| `monkestation/code/modules/client/preferences/inventory.dm` | Metacoin management functions |
| `code/controllers/subsystem/ticker.dm` | Job/department bonus configuration |

### Store System
| File | Purpose |
|------|---------|
| `monkestation/code/modules/store/pre_round/_pre_round_store.dm` | Pre-round store backend |
| `monkestation/code/modules/store/store_items/__store.dm` | Base store item datum |
| `monkestation/code/modules/store/store_items/*.dm` | Item definitions by category |
| `monkestation/code/modules/store/atm/_atm.dm` | ATM system |
| `tgui/packages/tgui/interfaces/PreRoundStore.tsx` | Store UI |
| `tgui/packages/tgui/interfaces/PreferencesMenu/LoadoutPage.tsx` | Loadout UI |

### Loadout System
| File | Purpose |
|------|---------|
| `monkestation/code/modules/loadouts/` | Loadout backend |
| `monkestation/code/modules/donator/` | Donator-exclusive items |

---

## Admin Tools

**Source File:** `monkestation/code/modules/store/admin/admin_coin_modification.dm`

| Tool | Description |
|------|-------------|
| `adjust_players_metacoins` | Modify individual player's balance |
| `mass_add_metacoins` | Give coins to all online players |

**All changes are logged via:**
```dm
logger.Log(LOG_CATEGORY_META, "Adjusted [ckey] metacoins by [amount]: [reason]")
```

---

## Anti-Exploit Measures

The system includes several protections against exploitation:

1. **ATM Interaction Prevention**
   - Prevents stacking ATM interactions to duplicate coins

2. **Item Duplication Blacklist**
   - Monkecoins and spacecash are blacklisted from normal item duplication mechanics

3. **Database Commits**
   - All transactions are committed to the database immediately

4. **Balance Validation**
   - Balance is checked before every deduction
   - Transactions fail gracefully if insufficient funds

5. **Transaction Logging**
   - All metacoin adjustments are logged with reason
   - Stored in system logs for audit purposes

6. **Round Cap System**
   - Prevents unlimited earning in a single round
   - Configurable per-reward via `respects_roundcap` parameter

---

## Summary

The Monkecoin and Lobby Clothes Shop systems provide a comprehensive meta-progression layer on top of the base game. Players are rewarded for continued engagement through roundend bonuses, with donators receiving additional benefits. The Pre-Round Store offers a clean TGUI interface for purchasing permanent cosmetic unlocks, while the Loadout system allows customization of starting equipment. The entire system is backed by MySQL persistence, comprehensive logging, and anti-exploit protections.
