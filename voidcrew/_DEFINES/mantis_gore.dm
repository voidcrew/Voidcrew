// Mantis Blades x hyperviolence (voidcrew/modules/mantis_gore/). Balance notes for developers; none of
// these numbers go in player text.

/// 32x32 pictures: glints, the coil glow, trails, the impale tips, the scorch seam.
#define MANTIS_GORE_ICON 'voidcrew/modules/mantis_gore/icons/mantis_gore.dmi'
/// 64x64 pictures: the flick.
#define MANTIS_GORE_LARGE_ICON 'voidcrew/modules/mantis_gore/icons/mantis_gore_large.dmi'
/// 96x96 pictures of the drops a torn artery throws, for each of the eight ways they fly. The wound is in the
/// middle across and MANTIS_ARTERY_WOUND_RISE pixels above the middle: the drops fall further than they rise.
#define MANTIS_ARTERY_ICON 'voidcrew/modules/mantis_gore/icons/mantis_artery.dmi'
#define MANTIS_ARTERY_WOUND_RISE 16
/// 96x96 pictures centred on the bearer: the arms and blades of each beat of the impale and the scissor, drawn
/// around the victim by the blade rig (mantis_rig.dm).
#define MANTIS_GORE_REACH_ICON 'voidcrew/modules/mantis_gore/icons/mantis_gore_reach.dmi'
/// Layer for blade drawn in front of the victim (and the bearer).
#define MANTIS_OVER_VICTIM_LAYER ABOVE_MOB_LAYER
/// The posed held blades.
#define MANTIS_LEFTHAND_ICON 'voidcrew/modules/mantis_gore/icons/mantis_lefthand.dmi'
#define MANTIS_RIGHTHAND_ICON 'voidcrew/modules/mantis_gore/icons/mantis_righthand.dmi'
/// Layer for pictures on the blades: just over the held blades (cyberware_anim.dm's swing layer).
#define MANTIS_ANIM_BLADE_LAYER (-(HANDS_LAYER - 0.5))
/// Layer for pictures over the whole body: over everything it wears.
#define MANTIS_ANIM_TOP_LAYER (-(HIGHEST_LAYER - 0.5))

// What a blade of the line can do, on /obj/item/melee/energy/blade/hardlight/cyberware_mantis/var/gore_moves.
/// Repeated cuts on one limb tear its artery.
#define MANTIS_MOVE_ARTERY (1<<0)
/// A two-blade lunge skewers someone already hurt.
#define MANTIS_MOVE_IMPALE (1<<1)
/// A head swing at someone dying takes the head off.
#define MANTIS_MOVE_SCISSOR (1<<2)
/// Every third cut with both blades out is a crossed double slash.
#define MANTIS_MOVE_XSLASH (1<<3)
#define MANTIS_MOVES_ALL (MANTIS_MOVE_ARTERY|MANTIS_MOVE_IMPALE|MANTIS_MOVE_SCISSOR|MANTIS_MOVE_XSLASH)

// Poses of the held blades. Each is an in-hand state "[base_icon_state]_[pose]".
#define MANTIS_POSE_GUARD "guard"
#define MANTIS_POSE_LUNGE "lunge"
#define MANTIS_POSE_RAISE "raise"
#define MANTIS_POSE_COIL "coil"

// Fields of mantis_rig_beat().
#define MANTIS_RIG_ORDER 1
#define MANTIS_RIG_BEARER_W 2
#define MANTIS_RIG_BEARER_Z 3
#define MANTIS_RIG_TARGET_W 4
#define MANTIS_RIG_TARGET_Z 5
#define MANTIS_RIG_TILT 6
#define MANTIS_RIG_RAISE 7

/// Trait and offset sources.
#define MANTIS_IMPALE_TRAIT "mantis_impale"
#define MANTIS_CHARGE_TRAIT "mantis_charge"

/// The wound series of a torn limb artery, so it stacks with ordinary cuts on the same limb.
#define WOUND_SERIES_HV_LIMB_ARTERY "wound_series_hv_limb_artery"

// ---- Arterial gashes ----
/// Cuts on one limb add up while each lands within this long of the last.
#define MANTIS_CUT_WINDOW (8 SECONDS)
/// A cut must deal this much brute after armour to count.
#define MANTIS_CUT_MIN_DAMAGE 8
/// Cuts that tear the artery on a limb covered by less than MANTIS_COVER_LIGHT (after armour penetration).
#define MANTIS_TEAR_CUTS_BARE 3
/// Cuts that tear it under cover from MANTIS_COVER_LIGHT up to MANTIS_COVER_STOP.
#define MANTIS_TEAR_CUTS_COVERED 5
#define MANTIS_COVER_LIGHT 15
/// Cover at or above this never tears.
#define MANTIS_COVER_STOP 35
/// Blood flow at or above which a torn limb artery spurts.
#define MANTIS_ARTERY_OPEN_FLOW 1.5

// ---- Kill credit and the lunge reset ----
/// A death this long after the bearer's last cut counts as their kill.
#define MANTIS_KILL_CREDIT_WINDOW (5 SECONDS)
/// A kill puts the lunge's cooldown down to this, never lower.
#define MANTIS_KILL_RESET_FLOOR (3 SECONDS)
/// At most one reset per bearer in this long.
#define MANTIS_KILL_RESET_COOLDOWN (8 SECONDS)
/// A body that gave a reset gives no other for this long (revive loops).
#define MANTIS_KILL_RESET_VICTIM_LOCKOUT (2 MINUTES)
/// Anything that isn't a person must have at least this much max health to count.
#define MANTIS_KILL_RESET_MIN_HEALTH 100

// ---- X-slash ----
/// Every this many landed cuts on one target is a crossed double slash.
#define MANTIS_XSLASH_EVERY 3
/// The count holds while each cut lands within this long of the last.
#define MANTIS_XSLASH_WINDOW (4 SECONDS)
#define MANTIS_XSLASH_STAGGER (1.5 SECONDS)

// ---- Impaling lunge ----
#define MANTIS_IMPALE_HOLD (0.8 SECONDS)
#define MANTIS_IMPALE_PIN_HOLD (1.5 SECONDS)
/// Brute per blade when they rip free.
#define MANTIS_IMPALE_RIP_DAMAGE 8
#define MANTIS_IMPALE_RIP_WOUND_BONUS 15
/// Damage the bearer can take while holding someone up before they lose the grip.
#define MANTIS_IMPALE_BREAK_DAMAGE 15
/// A target at or under this share of max health is hurt enough to skewer.
#define MANTIS_IMPALE_HEALTH_FRACTION 0.7
// The beats of the impale (mantis_impale.dm), from the approved storyboard. The bearer's lunge pose shows
// while the lunging body glides in; the blades go in as it lands, and the hold, the pull-back, the rip and
// the drop follow. Where the two bodies sit in each beat is mantis_rig_beat()'s.
/// The victim sliding onto the blades, after the lunging body lands.
#define MANTIS_IMPALE_CONTACT_BEAT (0.05 SECONDS)
/// From the blades going in to the hoist, held up. Short, so the hold fills the 0.8 s.
#define MANTIS_IMPALE_ENTER_BEAT (0.1 SECONDS)
/// Each step of the hoist from the stab up to the hold, and of the pull-back.
#define MANTIS_IMPALE_STEP (0.05 SECONDS)
#define MANTIS_IMPALE_PULL_STEP (0.1 SECONDS)
/// Held up they sag a pixel this long into the hold, for this long, and once more this long after the first.
#define MANTIS_IMPALE_SAG_AFTER (0.15 SECONDS)
#define MANTIS_IMPALE_SAG_FOR (0.1 SECONDS)
#define MANTIS_IMPALE_SAG_EVERY (0.2 SECONDS)
/// From the pull-back to the rip-out.
#define MANTIS_IMPALE_RIP_BEAT (0.2 SECONDS)
/// How long the bearer holds the last pose after the blades are out, before they are drawn as usual again,
/// and how long the body takes to fall from the blades to the floor.
#define MANTIS_IMPALE_DROP_BEAT (0.3 SECONDS)
/// From the pull-back to the blades coming out and the body dropping.
#define MANTIS_IMPALE_PULL_BEAT (0.3 SECONDS)

/// Pixels under a body's middle that it is tipped about: its feet (mantis_tip_matrix()).
#define MANTIS_TIP_FEET (ICON_SIZE_Y / 2 - 4)

/// How long the lunging body takes to glide in after it has arrived. The hit shows as it lands.
#define MANTIS_LUNGE_GLIDE 1.5
/// How long the blade rig's pictures take to fade into the real bearer when a move ends (mantis_rig.dm).
#define MANTIS_RIG_HANDBACK (0.15 SECONDS)

// ---- Charged leap ----
/// Held shorter than this, it is the ordinary lunge.
#define MANTIS_CHARGE_TAP (0.35 SECONDS)
/// Held this long, it reaches the furthest.
#define MANTIS_CHARGE_FULL (1.2 SECONDS)
/// Pixels the body sinks into the crouch.
#define MANTIS_CHARGE_CROUCH_DROP 5
/// Held this long, the bearer gives up and straightens.
#define MANTIS_CHARGE_MAX_HOLD (3 SECONDS)
/// After straightening, this long before they can crouch again.
#define MANTIS_CHARGE_REARM (1 SECONDS)
/// One hit this big while crouched breaks it.
#define MANTIS_CHARGE_BREAK_DAMAGE 10
/// Extra tiles a full charge reaches over the lunge.
#define MANTIS_CHARGE_EXTRA_RANGE 2

// ---- Scissor ----
#define MANTIS_SCISSOR_WINDUP (1.2 SECONDS)
/// Pixels the bearer leans in for the cut, and further when the head lies on the far side of the body.
/// Drawn by the blade rig; this is the bearer's own lean when the rig can't draw them.
#define MANTIS_SCISSOR_LEAN 12
#define MANTIS_SCISSOR_FAR_LEAN 16
/// The scissor's swing: the blades come down from the raise, close on the neck, and shut through it this long apart.
#define MANTIS_SCISSOR_SWING_STEP (0.1 SECONDS)
/// The scissor's beats after the cut: the blades shut through the neck, then the bearer straightens over
/// MANTIS_SCISSOR_STRAIGHTEN.
#define MANTIS_SCISSOR_RECOVER_BEAT (0.25 SECONDS)
#define MANTIS_SCISSOR_STRAIGHTEN (0.25 SECONDS)
#define MANTIS_SCISSOR_COOLDOWN (10 SECONDS)
/// Brute to the neck when the head won't come off.
#define MANTIS_SCISSOR_FALLBACK_DAMAGE 25
/// Where a head cut off by the scissor is drawn on its tile: pixels out from the middle toward the side the
/// head lay, where the neck was, then where it comes to rest, and how far below the middle.
#define MANTIS_HEAD_ROLL_FROM 7
#define MANTIS_HEAD_ROLL_TO 11
#define MANTIS_HEAD_ROLL_DROP 5

// ---- Blood on the blades ----
/// How long a drenched blade drips.
#define MANTIS_DRENCH_TIME (60 SECONDS)
#define MANTIS_DRIP_INTERVAL (1.5 SECONDS)
/// Most drops one drench leaves on the floor.
#define MANTIS_DRIP_MAX 20
