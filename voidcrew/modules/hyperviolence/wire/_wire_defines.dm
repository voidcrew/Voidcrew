// Widowline monowire x hyperviolence (voidcrew/modules/hyperviolence/wire/): defines private to this part.
// The folder sorts after cyberware/ and every other hyperviolence part on purpose: it overrides procs both
// declare, and an override included before its declaration is silently dead.

/// Clean cuts, seams, the through-cut and blood beams, the garrote loop and taut wire.
#define WIRE_GORE_ICON 'voidcrew/modules/hyperviolence/wire/icons/wire_gore.dmi'
/// The wire swinging out of its spool and reeling back in, with blood-flick twins.
#define WIRE_HELD_ANIM_ICON 'voidcrew/modules/cyberware/icons/cyberware_anim_monowire.dmi'

/// On a body a Widowline is cutting right now: no flying hitsplatter, drips instead of floor splatter,
/// and a limb tg's own wound roll would tear off is left for the wire to take off clean.
#define TRAIT_HV_CLEAN_CUT "hv_clean_cut"

/// An aimed cut takes off an arm or leg already this damaged (percent of its max damage) before the hit.
/// Whole percents: in DM's floats 50 * 0.6 is a hair over 30, and a limb at exactly 60% would never qualify.
#define WIRE_SEVER_AT 60
/// The same on someone already down.
#define WIRE_SEVER_AT_DOWN 20
/// A crossing cut takes a limb off at this share of the usual damage (percent).
#define WIRE_CROSS_SEVER_SHARE 50
/// With a wire out in each hand, every this many landed hits cross both through the target.
#define WIRE_CROSS_HITS 3
/// Landed hits further apart than this start the count again.
#define WIRE_CROSS_WINDOW (3 SECONDS)

/// From the hit to the severed limb sliding off the body.
#define WIRE_CUT_DELAY (0.5 SECONDS)
/// The slide along the cut, and the fall after it.
#define WIRE_SLIDE_TIME (0.2 SECONDS)
#define WIRE_FALL_TIME (0.15 SECONDS)
/// Blood the Arc's seared cut loses, as a fraction of a plain sever's.
#define WIRE_ARC_BLEED_MULT 0.25
/// How long a seared stump smokes.
#define WIRE_ARC_SMOKE_TIME (3 SECONDS)
/// A seared stump's blood layer and bone.
#define WIRE_BURNT_STUMP_COLOR "#2a1b15"
#define WIRE_BURNT_BONE_COLOR "#7a6a60"

/// Blood on the wire: wet and dripping for this long after a cut, stained for this long.
#define WIRE_WET_TIME (15 SECONDS)
#define WIRE_STAINED_TIME (30 SECONDS)
/// Most drips one wet spell leaves.
#define WIRE_MAX_DRIPS 8
/// Drops a wet wire throws when it cracks back into the spool.
#define WIRE_FLICK_DROPS 6

/// The swing out of the spool and back in.
#define WIRE_SWING_TIME (0.4 SECONDS)

/// The garrote's wait after an attempt that got a grip, and after one that didn't.
#define WIRE_GARROTE_COOLDOWN (20 SECONDS)
#define WIRE_GARROTE_MISS_COOLDOWN (5 SECONDS)
/// Worn and plated cover at the neck (crit gate rating, the wire's penetration not counted) that turns the garrote.
#define WIRE_GARROTE_COVER 25
/// World layer between a body lying on the floor and one standing: the garrote's wire facing away, which runs from the
/// hands hidden behind the garroter to the neck of the body lying beyond them.
#define WIRE_BETWEEN_LAYER (LYING_MOB_LAYER + 0.05)
/// World layer of a body the garrote holds up in front of a garroter facing the viewer: over the garroter, under the
/// near side of the loop.
#define WIRE_PULLED_LAYER (MOB_LAYER + 0.02)
/// Most blood the garrote pours into the pool under the neck: a pool that keeps to its tile (blood/blood_pools.dm).
#define WIRE_GARROTE_POOL_CAP 190

/// Mob overlay layers. The held limb: over the jumpsuit and the stump, under the ID, belt, suit and hands.
#define WIRE_GHOST_LAYER (-(HV_STUMP_FRESH_LAYER - 0.1))
/// The wire swinging out of or into a hand: just over the held item it turns into.
#define WIRE_SWING_LAYER (-(HANDS_LAYER - 0.5))
/// Flashes, seams and loops: over everything the body wears.
#define WIRE_FX_LAYER (-(HIGHEST_LAYER - 0.5))
