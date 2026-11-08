// Hyperviolence (voidcrew/modules/hyperviolence/): shared defines for the gore parts.

/// A plain bold line in the combined hit message.
#define HV_LINE_BOLD 1
/// A big bold-italic line, for severed limbs, burst heads and kills.
#define HV_LINE_HUGE 2

// Brain burst, gut spill and gut tether (voidcrew/modules/hyperviolence/braingut/).

/// A blow must deal at least this much (after armour) before it can burst a downed victim's head instead of knocking it off whole.
#define HV_HEAD_BURST_MIN_DAMAGE 30
/// The head must already be this far gone (fraction of its damage limit) before a blow can burst it.
#define HV_HEAD_BURST_MIN_HEAD_DAMAGE 0.5
/// A burst head throws its brain at least this many tiles along the blow.
#define HV_BRAIN_FLING_MIN 1
/// A burst head throws its brain at most this many tiles along the blow.
#define HV_BRAIN_FLING_MAX 3
/// How many gib decals a burst head leaves, besides the core.
#define HV_HEAD_BURST_GIBS 4
/// Percent chance that a heavy explosion bursts the head of a victim who is dead or in hard crit.
#define HV_HEAD_BURST_EXPLOSION_CHANCE 10

/// A slash must deal at least this much (after armour) to the chest to be able to spill guts.
#define HV_GUTSPILL_MIN_DAMAGE 25
/// A victim who is still up needs the chest this far gone (fraction of its damage limit) before a slash can spill guts.
#define HV_GUTSPILL_MIN_CHEST_DAMAGE 0.25
/// Percent chance that a qualifying slash spills guts.
#define HV_GUTSPILL_CHANCE 12
/// Percent chance that a qualifying slash spills guts on a victim who is dead or in hard crit.
#define HV_GUTSPILL_CHANCE_DOWNED 35
/// Percent chance that a heavy explosion spills guts.
#define HV_GUTSPILL_EXPLOSION_CHANCE 15
/// Percent chance that a heavy explosion spills guts on a victim who is dead or in hard crit.
#define HV_GUTSPILL_EXPLOSION_CHANCE_DOWNED 25
/// The chest this far gone (fraction of its damage limit) when guts spill also lets the stomach and liver slip out.
#define HV_GUTSPILL_ORGAN_CHEST_DAMAGE 0.5
/// How far the guts can lie from their owner before the owner is dragged against them.
#define HV_GUT_TETHER_RANGE 3
/// How far apart the guts and their owner can get before the tether tears.
#define HV_GUT_TETHER_SNAP_RANGE 7
/// Minimum time between the pain of two tugs on the tether.
#define HV_GUT_YANK_COOLDOWN (2 SECONDS)
/// Brute damage to the chest from one tug on the tether.
#define HV_GUT_YANK_DAMAGE 4
