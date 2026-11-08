// Hyperviolence (voidcrew/modules/hyperviolence/): shared defines for the gore parts.

/// A plain bold line in the combined hit message.
#define HV_LINE_BOLD 1
/// A big bold-italic line, for severed limbs, burst heads and kills.
#define HV_LINE_HUGE 2

// Aimed critical wounds (voidcrew/modules/hyperviolence/crits/). Each crit wound sits in its own
// series so it can stack with tg's ordinary bleeds on the same limb. The jaw and skull crits use
// tg's blunt bone series instead, since they are the worst head fractures.
/// A torn-out eye.
#define WOUND_SERIES_HV_EYE "wound_series_hv_eye"
/// A severed tongue.
#define WOUND_SERIES_HV_TONGUE "wound_series_hv_tongue"
/// A slit throat.
#define WOUND_SERIES_HV_CAROTID "wound_series_hv_carotid"
/// A torn aorta.
#define WOUND_SERIES_HV_AORTA "wound_series_hv_aorta"
/// Trait source for effects an aimed crit leaves on a mob.
#define HV_CRIT_TRAIT "hv_crit"
