// Outpost floors (voidcrew/modules/trade_floors): a crew leases a floor above a trader outpost.
// Unit test files compile before this one and cannot see these: tests write the literal with a comment.

/// Defined while the floors module is compiled in, so other code can test for it
#define OUTPOST_FLOORS_API

// ===== THE LEASE =====

#define OUTPOST_FLOOR_COST_CREDITS 6000
#define OUTPOST_FLOOR_COST_VOUCHERS 2
/// Floors a trader outpost has. The lift, the board, the maps and the memory budget are sized for it.
#define OUTPOST_FLOORS_PER_OUTPOST 6
#define OUTPOST_FLOORS_PER_CREW 1
/// The lift id of floor n is this plus n (berths are 1-6, ship bays from 8)
#define OUTPOST_FLOOR_ID_BASE 100

// /datum/outpost_floor/var/state
/// Let to an NPC tenant: never reserved, never on the lift
#define OUTPOST_FLOOR_STATE_TENANT "tenant"
/// Being sold this moment: marked before anything yields
#define OUTPOST_FLOOR_STATE_LETTING "letting"
#define OUTPOST_FLOOR_STATE_OWNED "owned"
/// Given up by its owner: anyone may take it, in person
#define OUTPOST_FLOOR_STATE_VACANT "vacant"

// ===== THE GROUND =====

/// The shell map, hull included
#define OUTPOST_FLOOR_WIDTH 46
#define OUTPOST_FLOOR_HEIGHT 40
/// The landing at the south wall: the lift alcove and the foyer. Outpost ground, never built on.
#define OUTPOST_FLOOR_LANDING_WIDTH 9
#define OUTPOST_FLOOR_LANDING_HEIGHT 5
/// Cell blocks a floor's prison wing may have
#define OUTPOST_FLOOR_MAX_EXTENSIONS 0
#define OUTPOST_FLOOR_MAINS_WATTS 60000

// ===== WHO MAY COME UP =====

#define OUTPOST_FLOOR_ENTRY_CREW "crew"
#define OUTPOST_FLOOR_ENTRY_INVITED "invited"
#define OUTPOST_FLOOR_ENTRY_OPEN "open"
/// Most guests, and most barred
#define OUTPOST_FLOOR_LIST_MAX 30
/// Least time an Open floor stays public ground after it is narrowed
#define OUTPOST_FLOOR_CLOSING_TIME (2 MINUTES)
/// How long the owner must be gone before a crewmate may take over the lease
#define OUTPOST_FLOOR_OWNER_ABSENT (15 MINUTES)
#define OUTPOST_FLOOR_LIFT_EMAG_TIME (3 MINUTES)
#define OUTPOST_FLOOR_LIFT_EMAG_COOLDOWN (5 MINUTES)

// ===== IDENTITY =====

#define OUTPOST_FLOOR_NAME_MAX 24
/// The floor's line on the directory board
#define OUTPOST_FLOOR_LINE_MAX 60
#define OUTPOST_FLOOR_ACCENT_AMBER "amber"
#define OUTPOST_FLOOR_ACCENT_TEAL "teal"
#define OUTPOST_FLOOR_ACCENT_RED "red"
#define OUTPOST_FLOOR_ACCENT_BLUE "blue"
#define OUTPOST_FLOOR_ACCENT_GREEN "green"
#define OUTPOST_FLOOR_ACCENT_VIOLET "violet"
#define OUTPOST_FLOOR_ACCENT_WHITE "white"
#define OUTPOST_FLOOR_ACCENT_ROSE "rose"
/// Accent id -> colour. The only colours a floor may show; a player never types one.
#define OUTPOST_FLOOR_ACCENTS list( \
	OUTPOST_FLOOR_ACCENT_AMBER = "#e0a030", \
	OUTPOST_FLOOR_ACCENT_TEAL = "#2fb3a8", \
	OUTPOST_FLOOR_ACCENT_RED = "#d04848", \
	OUTPOST_FLOOR_ACCENT_BLUE = "#4a7fd6", \
	OUTPOST_FLOOR_ACCENT_GREEN = "#58b04c", \
	OUTPOST_FLOOR_ACCENT_VIOLET = "#9a68d0", \
	OUTPOST_FLOOR_ACCENT_WHITE = "#e6e6e6", \
	OUTPOST_FLOOR_ACCENT_ROSE = "#d86a9c", \
)

// ===== SHOPS =====

/// Extra tills, sale shelves and floor signs a floor may have down at once
#define OUTPOST_FLOOR_TILLS_MAX 4
#define OUTPOST_FLOOR_SHELVES_MAX 16
#define OUTPOST_FLOOR_SIGNS_MAX 4
// What fitting_count() and a kit's `kind` take, and where a sale was made in the ledger
#define OUTPOST_FLOOR_FITTING_TILL "till"
#define OUTPOST_FLOOR_FITTING_SHELF "shelf"
#define OUTPOST_FLOOR_FITTING_SIGN "sign"
#define OUTPOST_FLOOR_SALE_REGISTER "register"
#define OUTPOST_FLOOR_HANDS_MAX 8
/// An unanswered offer of work lapses
#define OUTPOST_FLOOR_HIRE_ANSWER_TIME (30 SECONDS)
/// Between two offers to the same person
#define OUTPOST_FLOOR_HIRE_GAP (1 MINUTES)
/// Between two "is open" calls over the concourse speakers for one floor
#define OUTPOST_FLOOR_OPEN_CALL_EVERY (20 MINUTES)

// ===== SUPPLIES =====

/// From the order to the crates standing on the goods lift
#define OUTPOST_FLOOR_GOODS_TIME (45 SECONDS)
/// The goods lift's tiles: crates a delivery
#define OUTPOST_FLOOR_GOODS_CRATES 4

// ===== ROOMS =====

#define OUTPOST_FLOOR_QUARTERS_COST 1500
#define OUTPOST_FLOOR_WORKSHOP_COST 2500
#define OUTPOST_FLOOR_CANTEEN_COST 2000

// ===== NPC CUSTOM =====

/// Visitors upstairs for the board to say Busy
#define OUTPOST_FLOOR_BUSY_AT 3
/// Most an NPC customer pays for one thing
#define OUTPOST_FLOOR_NPC_ITEM_MAX 60
/// Most NPC customers pay one floor in one window (400 an hour). 0 makes them window-shoppers.
#define OUTPOST_FLOOR_NPC_BUDGET 100
#define OUTPOST_FLOOR_NPC_BUDGET_WINDOW (15 MINUTES)
/// Between customers on one floor
#define OUTPOST_FLOOR_NPC_VISIT_LOW (3 MINUTES)
#define OUTPOST_FLOOR_NPC_VISIT_HIGH (6 MINUTES)
/// How far from where it bought a patron looks for a chair
#define OUTPOST_FLOOR_PATRON_SEAT_RANGE 7
#define OUTPOST_FLOOR_PATRON_STAY_LOW (60 SECONDS)
#define OUTPOST_FLOOR_PATRON_STAY_HIGH (120 SECONDS)
#define OUTPOST_FLOOR_FITTERS 2
#define OUTPOST_FLOOR_FITTER_TIME (2 MINUTES)

// ===== SIGNALS =====

/// On the floor datum, for every lift arrival: (list/riders, mob/rider, forced)
#define COMSIG_OUTPOST_FLOOR_ENTERED "outpost_floor_entered"
