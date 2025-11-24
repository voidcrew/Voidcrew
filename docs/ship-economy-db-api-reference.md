# ShipEconomyDB API Reference - Quick Reference Card

**For:** Worker 1 (Extraction Device), Worker 3 (TGUI Interface), and Integration Teams
**Database Layer:** `C:\Users\isaac\code\tg-voidcrew\code\modules\ship_purchase\ship_economy_database.dm`

---

## Access Pattern

```dm
// Singleton instance (initialized on server startup)
GLOB.ship_economy_db
```

---

## Rarity Constants

```dm
RARITY_COMMON      // "common"
RARITY_UNCOMMON    // "uncommon"
RARITY_RARE        // "rare"
RARITY_EPIC        // "epic"
RARITY_LEGENDARY   // "legendary"

// Validation list
GLOB.ship_part_rarities  // All valid rarities
```

---

## API Methods

### Credits (Account-Wide)

#### Get Credits
```dm
var/credits = GLOB.ship_economy_db.get_credits(ckey)
// Returns: Integer (0 if none)
```

#### Add/Deduct Credits
```dm
GLOB.ship_economy_db.add_credits(ckey, amount, reason)
// amount: positive to add, negative to deduct
// reason: string for logging (e.g., "round_completion")
// Returns: TRUE on success, FALSE on failure
```

**Example:**
```dm
// Add credits
GLOB.ship_economy_db.add_credits("playername", 100, "round_completion")

// Deduct credits
GLOB.ship_economy_db.add_credits("playername", -50, "purchased_parts")
```

---

### Parts (Account-Wide)

#### Get Parts Inventory
```dm
var/list/parts = GLOB.ship_economy_db.get_parts(ckey)
// Returns: list("common"=5, "uncommon"=2, "rare"=1, "epic"=0, "legendary"=0)
//          or null on error
```

#### Add Parts
```dm
GLOB.ship_economy_db.add_part(ckey, rarity, quantity, method)
// rarity: RARITY_COMMON, RARITY_UNCOMMON, etc.
// quantity: number to add (default 1)
// method: string for logging (e.g., "extraction_device", "battlepass_reward")
// Returns: TRUE on success, FALSE on failure
```

**Example:**
```dm
GLOB.ship_economy_db.add_part("playername", RARITY_RARE, 1, "found_in_ruins")
GLOB.ship_economy_db.add_part("playername", RARITY_COMMON, 5, "battlepass_tier_10")
```

#### Spend Parts (Purchase Blueprint)
```dm
var/list/cost = list(RARITY_RARE = 2, RARITY_EPIC = 1)
var/success = GLOB.ship_economy_db.spend_parts(ckey, cost)
// Returns: TRUE if successful (and parts deducted)
//          FALSE if insufficient parts or error
```

**Example:**
```dm
// Check if player has enough parts before attempting
var/list/parts = GLOB.ship_economy_db.get_parts(user.ckey)
if(parts[RARITY_RARE] >= 2 && parts[RARITY_EPIC] >= 1)
    var/list/cost = list(RARITY_RARE = 2, RARITY_EPIC = 1)
    if(GLOB.ship_economy_db.spend_parts(user.ckey, cost))
        // Success - unlock the ship
        to_chat(user, "Parts spent successfully!")
```

---

### Ship Unlocks (Account-Wide)

#### Check if Ship Unlocked
```dm
var/unlocked = GLOB.ship_economy_db.is_ship_unlocked(ckey, ship_template_path)
// Returns: TRUE if unlocked, FALSE otherwise
```

#### Unlock Ship (Permanent)
```dm
GLOB.ship_economy_db.unlock_ship(ckey, ship_template_path)
// Returns: TRUE on success, FALSE on failure
```

#### Get All Unlocked Ships
```dm
var/list/ships = GLOB.ship_economy_db.get_unlocked_ships(ckey)
// Returns: list("/datum/ship_template/frigate", "/datum/ship_template/corvette", ...)
```

**Example:**
```dm
// Purchase flow
var/ship_path = "/datum/ship_template/advanced_frigate"
var/list/cost = list(RARITY_RARE = 3, RARITY_EPIC = 2)

if(GLOB.ship_economy_db.spend_parts(user.ckey, cost))
    GLOB.ship_economy_db.unlock_ship(user.ckey, ship_path)
    to_chat(user, "Ship blueprint unlocked permanently!")
```

---

### Extraction & Logging

#### Log Extraction (Audit Trail)
```dm
GLOB.ship_economy_db.log_extraction(ckey, rarity, location, part_uid)
// location: "extraction_device", "found_in_ruins", etc.
// part_uid: unique identifier of the physical part (optional)
```

#### Queue Pending Extraction (Failed Extraction)
```dm
GLOB.ship_economy_db.queue_pending_extraction(ckey, rarity, part_uid)
// Used when extraction fails due to database issues
// Returns: TRUE if queued successfully
```

#### Process Pending Extractions (Retry)
```dm
var/processed = GLOB.ship_economy_db.process_pending_extractions(max_retries)
// max_retries: default 5
// Returns: Number of successfully processed extractions
// Call this on server startup or periodic timer
```

---

## Worker 1: Extraction Device Integration

### Extraction Flow
```dm
/obj/machinery/part_extractor/proc/extract_part(obj/item/ship_part/part, mob/user)
    var/ckey = user.ckey
    var/rarity = part.rarity  // Assume part has .rarity property
    var/uid = part.UID        // Unique ID generated when part spawned

    // Attempt extraction
    if(GLOB.ship_economy_db.add_part(ckey, rarity, 1, "extraction_device"))
        // Success - log and delete part
        GLOB.ship_economy_db.log_extraction(ckey, rarity, "extraction_device", uid)
        to_chat(user, span_notice("Part extracted successfully!"))
        qdel(part)
        return TRUE
    else
        // Failed - queue for retry
        GLOB.ship_economy_db.queue_pending_extraction(ckey, rarity, uid)
        to_chat(user, span_warning("Extraction failed! Queued for automatic retry."))
        return FALSE
```

### Part UID Generation
```dm
/obj/item/ship_part/New()
    . = ..()
    // Generate unique ID
    UID = "[world.time]-[sequential_id++]"
```

---

## Worker 3: TGUI Interface Integration

### Display Resources
```dm
/datum/ship_catalog_ui/proc/get_ui_data(mob/user)
    var/list/data = list()

    // Get player resources
    data["credits"] = GLOB.ship_economy_db.get_credits(user.ckey)
    data["parts"] = GLOB.ship_economy_db.get_parts(user.ckey)
    // parts = list("common"=5, "uncommon"=2, "rare"=1, "epic"=0, "legendary"=0)

    // Get unlocked ships
    data["unlocked_ships"] = GLOB.ship_economy_db.get_unlocked_ships(user.ckey)

    return data
```

### Purchase Blueprint
```dm
/datum/ship_catalog_ui/proc/purchase_blueprint(mob/user, ship_template_path, list/part_cost)
    // Check if already unlocked
    if(GLOB.ship_economy_db.is_ship_unlocked(user.ckey, ship_template_path))
        to_chat(user, span_warning("You already own this ship!"))
        return FALSE

    // Attempt to spend parts
    if(GLOB.ship_economy_db.spend_parts(user.ckey, part_cost))
        // Success - unlock ship
        GLOB.ship_economy_db.unlock_ship(user.ckey, ship_template_path)
        to_chat(user, span_notice("Ship blueprint purchased and unlocked!"))
        return TRUE
    else
        to_chat(user, span_warning("Insufficient parts!"))
        return FALSE
```

### Check Can Afford
```dm
/datum/ship_catalog_ui/proc/can_afford(mob/user, list/cost)
    var/list/parts = GLOB.ship_economy_db.get_parts(user.ckey)

    for(var/rarity in cost)
        var/needed = cost[rarity]
        var/have = parts[rarity] || 0

        if(have < needed)
            return FALSE

    return TRUE
```

---

## Performance Notes

### Caching
- All `get_*()` methods use 5-minute cache
- Cache automatically invalidated on writes (`add_*`, `spend_*`, `unlock_*`)
- Cache is per-ckey, not global
- Manual cache clear: `GLOB.ship_economy_db.clear_all_caches()`

### Best Practices
1. **Batch reads:** Call `get_parts()` once, store result
2. **Check before spend:** Validate parts BEFORE calling `spend_parts()`
3. **Handle failures:** Always check return values (TRUE/FALSE)
4. **Log transactions:** Use descriptive `reason`/`method` parameters

---

## Error Handling

### Common Failure Cases
```dm
// Database not connected
if(!SSdbcore.IsConnected())
    // All methods return FALSE or 0/null
    to_chat(user, "Database unavailable, try again later")

// Invalid rarity
GLOB.ship_economy_db.add_part(ckey, "invalid", 1, "test")
// Logs stack_trace, returns FALSE

// Insufficient parts
var/cost = list(RARITY_LEGENDARY = 100)
if(!GLOB.ship_economy_db.spend_parts(ckey, cost))
    // Player doesn't have 100 legendary parts
    to_chat(user, "Not enough parts!")
```

---

## Database Schema Reference

### Tables Used
1. `player_ship_credits` - Account credits
2. `player_ship_parts` - Parts inventory (by rarity)
3. `player_ship_unlocks` - Permanent ship unlocks
4. `pending_ship_extractions` - Failed extraction queue
5. `ship_extraction_log` - Audit trail

### Table Prefixes
All tables use `format_table_name()` for server-specific prefixes.

---

## Testing Examples

### Test Credits
```dm
/client/proc/test_ship_credits()
    var/ckey = src.ckey

    // Add credits
    GLOB.ship_economy_db.add_credits(ckey, 1000, "test")

    // Get credits
    var/credits = GLOB.ship_economy_db.get_credits(ckey)
    to_chat(src, "You have [credits] credits")

    // Deduct credits
    GLOB.ship_economy_db.add_credits(ckey, -500, "test_deduct")

    var/new_credits = GLOB.ship_economy_db.get_credits(ckey)
    to_chat(src, "After deduction: [new_credits] credits")
```

### Test Parts
```dm
/client/proc/test_ship_parts()
    var/ckey = src.ckey

    // Add parts
    GLOB.ship_economy_db.add_part(ckey, RARITY_RARE, 5, "test")
    GLOB.ship_economy_db.add_part(ckey, RARITY_EPIC, 2, "test")

    // Get parts
    var/list/parts = GLOB.ship_economy_db.get_parts(ckey)
    to_chat(src, "Parts: [json_encode(parts)]")

    // Spend parts
    var/list/cost = list(RARITY_RARE = 2, RARITY_EPIC = 1)
    if(GLOB.ship_economy_db.spend_parts(ckey, cost))
        to_chat(src, "Spent parts successfully!")
    else
        to_chat(src, "Failed to spend parts!")

    // Get updated parts
    parts = GLOB.ship_economy_db.get_parts(ckey)
    to_chat(src, "After spending: [json_encode(parts)]")
```

---

## Support & Questions

**Implementation File:**
`C:\Users\isaac\code\tg-voidcrew\code\modules\ship_purchase\ship_economy_database.dm`

**Full Documentation:**
`C:\Users\isaac\code\tg-voidcrew\docs\worker-2-implementation-report.md`

**Report Issues To:** Worker 2 - Database Access Layer Team

---

**Last Updated:** 2025-11-23
