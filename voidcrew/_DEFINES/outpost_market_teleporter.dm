// Outpost teleporter network (outpost_network.dm, outpost_teleporter.dm, outpost_network_ui.dm)

/// do_teleport() channel of network pad trips
#define TELEPORT_CHANNEL_OUTPOST_NETWORK "outpost_network"
#define OUTPOST_TELEPORTER_COST 6000
/// The destination's arrival fare (OUTPOST_PRICE_TELEPORT_ARRIVAL)
#define OUTPOST_TELEPORT_ARRIVAL_DEFAULT 200
#define OUTPOST_TELEPORT_ARRIVAL_MAX 2000
/// Charge-up before a trip within one zone
#define OUTPOST_NETWORK_CHARGE_TIME (5 SECONDS)
/// Charge-up before a trip across zones: ZONE_TRANSITION_TIME, the wait a ship pays to cross
#define OUTPOST_NETWORK_CROSS_ZONE_CHARGE_TIME (10 SECONDS)
/// Per traveller, between trips
#define OUTPOST_NETWORK_TRAVELLER_COOLDOWN (2 MINUTES)
/// Per traveller, after walking off a charging pad or calling the trip off
#define OUTPOST_NETWORK_CANCEL_COOLDOWN (15 SECONDS)
/// Arrival policies of a player outpost's pad
#define OUTPOST_NETWORK_ARRIVALS_OPEN "open"
#define OUTPOST_NETWORK_ARRIVALS_MEMBERS "members"
#define OUTPOST_NETWORK_ARRIVALS_ALLOWLIST "allowlist"
#define OUTPOST_NETWORK_ARRIVALS_CLOSED "closed"
/// An idle occupant (no client, or inactive this long) is stepped off a pad someone else wants
#define OUTPOST_NETWORK_IDLE_CLEAR (15 SECONDS)
