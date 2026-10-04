// Outpost marketplace: shared price keys, the income ledger and service doors (outpost_market.dm)

// Price keys of the shared price table (GLOB.outpost_price_table). Also the ledger's service keys.
#define OUTPOST_PRICE_DOCK_BAY "dock_bay"
#define OUTPOST_PRICE_CLONE_IMPRINT "clone_imprint"
#define OUTPOST_PRICE_MEDLAB_PASS "medlab_pass"
#define OUTPOST_PRICE_STORAGE_RENT "storage_rent"
/// Set by the destination outpost, paid by the traveller at departure (outpost_network.dm)
#define OUTPOST_PRICE_TELEPORT_ARRIVAL "teleport_arrival"
/// Ledger service key for shop sales, which are priced per item rather than from the table
#define OUTPOST_SERVICE_SHOP "shop"
/// Takings that are not a charge on anyone (record_income()): the prison wing's pay, and cargo exports
#define OUTPOST_INCOME_PRISON "prison"
#define OUTPOST_INCOME_EXPORTS "exports"
/// How far back the takings' "last hour" looks
#define OUTPOST_INCOME_WINDOW (60 MINUTES)

/// Income ledger lines kept per outpost; the treasury's own history keeps 20
#define OUTPOST_SERVICE_LEDGER_MAX 50
/// Ledger lines the management console's Pricing tab shows, newest first
#define OUTPOST_SERVICE_LEDGER_SHOWN 10
/// One price change per user this often
#define OUTPOST_PRICE_SET_COOLDOWN (1 SECONDS)

/// Door access settings (outpost_door_access.dm). A service door's door_policy is PUBLIC or STAFF: the setting its room gives it.
#define OUTPOST_DOOR_PUBLIC "public"
#define OUTPOST_DOOR_MEMBERS "members"
#define OUTPOST_DOOR_STAFF "staff"
#define OUTPOST_DOOR_OWNER "owner"
/// Open tiles a walk from one side of a door looks at before it calls that side big (outpost_door_reach())
#define OUTPOST_DOOR_FLOOD_LIMIT 600
/// What a walk from one side of a door found: ground off the outpost, nothing more to walk, or the limit
#define OUTPOST_DOOR_REACH_OPEN "open"
#define OUTPOST_DOOR_REACH_CLOSED "closed"
#define OUTPOST_DOOR_REACH_CAPPED "capped"
/// Door Access tints on the construction console, one per setting
#define OUTPOST_DOOR_TINT_PUBLIC "#3fbf3f"
#define OUTPOST_DOOR_TINT_MEMBERS "#3f8fff"
#define OUTPOST_DOOR_TINT_STAFF "#ffb030"
#define OUTPOST_DOOR_TINT_OWNER "#ff3f3f"

/// Magic recall (the summon item spell) cannot pull an item out of a holder with this trait
#define TRAIT_BLOCKS_RECALL "blocks_recall"

/// A singularity or reality tear neither eats nor pulls this (outpost service room fixtures; see singularity_spares())
#define TRAIT_SINGULARITY_IMMUNE "singularity_immune"
/// Sold by an outpost shop: summon marks made before the sale no longer recall it (sever_magic_recall())
#define TRAIT_RECALL_SEVERED "recall_severed"
/// Trait source for outpost service rooms
#define OUTPOST_SERVICE_TRAIT "outpost_service"
