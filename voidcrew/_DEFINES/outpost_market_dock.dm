// Ship bay docking fee and bay eviction (outpost_dock_fees.dm)

#define OUTPOST_DOCK_FEE_DEFAULT 0
#define OUTPOST_DOCK_FEE_MAX 5000
/// How long a fee quote shown at the helm stays valid
#define OUTPOST_DOCK_FEE_QUOTE_LIFETIME (2 MINUTES)
/// How long a captain's approval of a quote stays valid
#define OUTPOST_DOCK_FEE_CONSENT_LIFETIME (2 MINUTES)
/// How often an escrowed fee checks whether its dock stalled
#define OUTPOST_DOCK_FEE_HOLD_CHECK (30 SECONDS)
/// An escrowed fee still unresolved after this long is refunded and logged
#define OUTPOST_DOCK_FEE_HOLD_CAP (10 MINUTES)
/// Warning a ship gets between an eviction and the forced undock
#define OUTPOST_BAY_EVICTION_GRACE (3 MINUTES)
/// Evicting a ship this soon after it arrived refunds its docking fee
#define OUTPOST_BAY_EVICTION_REFUND_WINDOW (30 MINUTES)
/// A refused forced undock is retried this often, this many times
#define OUTPOST_BAY_EVICTION_RETRY (30 SECONDS)
#define OUTPOST_BAY_EVICTION_RETRIES 10
