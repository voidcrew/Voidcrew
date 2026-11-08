// Hyperviolence (voidcrew/modules/hyperviolence/): shared defines for the gore parts.

/// A plain bold line in the combined hit message.
#define HV_LINE_BOLD 1
/// A big bold-italic line, for severed limbs, burst heads and kills.
#define HV_LINE_HUGE 2

// ---- Stump and skull-wound overlays, gun executions (overlays_exec/) ----

/// Icon file for stump and skull-wound overlays (art from CM-SS13, CC BY-SA 3.0).
#define HV_GORE_ICON 'voidcrew/modules/hyperviolence/overlays_exec/icons/gore_overlays.dmi'
/// Mob overlay height of a healed stump: under the jumpsuit (UNIFORM_LAYER 28), over the body.
/// Fractional so it never collides with a real overlays_standing index.
#define HV_STUMP_LAYER 28.5
/// Mob overlay height of a fresh stump and the neck stump: over the jumpsuit, under ID, belt and suit.
#define HV_STUMP_FRESH_LAYER 27.5
/// Mob overlay height of a skull wound: over hair (HAIR_LAYER 13), under masks and hats.
#define HV_SKULL_WOUND_LAYER 12.5
/// How long a torn-off limb leaves a wet, bleeding stump before it reads as healed over.
#define HV_STUMP_FRESH_TIME (5 MINUTES)
/// Alpha of the blood layer on a healed-over stump.
#define HV_STUMP_OLD_ALPHA 140

/// Brute damage one hit must deal to a head to open a skull wound.
#define HV_SKULL_OPEN_HIT 20
/// Head brute damage for the light, medium and heavy skull wound. Below the light value it closes.
#define HV_SKULL_LIGHT_BRUTE 20
#define HV_SKULL_MEDIUM_BRUTE 45
#define HV_SKULL_HEAVY_BRUTE 80

/// Wind-up before an execution shot.
#define HV_EXECUTION_WINDUP (1.5 SECONDS)
/// Multiplier on the damage of an execution round, fired with the barrel against the head. The round
/// deals it through tg's normal damage; nothing else is added.
#define HV_EXECUTION_POINT_BLANK_MULT 2
/// Damage an execution round must deal to the head (after armour) to burst it instead of holing it.
#define HV_EXECUTION_BURST_DAMAGE 80
/// A chambered round must deal at least this much to count as an execution round.
#define HV_EXECUTION_MIN_DAMAGE 10
/// do_after interaction key for an execution wind-up.
#define DOAFTER_SOURCE_HV_EXECUTION "hv_execution"

// ---- NPC corpses (corpses/): the fight carried onto the human body an NPC leaves ----

/// A killing blow that cuts must deal at least this much to roll for taking the limb off the corpse.
#define HV_CORPSE_EDGED_SEVER_DAMAGE 20
/// A killing blow that crushes or pierces must deal at least this much to roll for taking the limb off.
#define HV_CORPSE_HEAVY_SEVER_DAMAGE 30
/// A crushing or piercing killing blow to the head this big always bursts it.
#define HV_CORPSE_HEAD_BURST_DAMAGE 60
/// A body zone that took this share of the NPC's max health in brute gets the clothes over it bloodied.
#define HV_CORPSE_BLOOD_ZONE_SHARE 0.15
/// Brute damage (share of max health) at which the corpse's hands are bloody and it lies in a pool.
#define HV_CORPSE_BLOOD_HANDS_SHARE 0.5
/// How long a new corpse convulses on its feet before it falls.
#define HV_DEATH_THROES_TIME (0.6 SECONDS)

// Finishers (voidcrew/modules/hyperviolence/finishers/): a boss kills someone who is down, in stages.

/// Blackboard key: the mob's finisher action (/datum/action/cooldown/mob_cooldown/hv_finisher)
#define BB_HV_FINISHER_ACTION "BB_hv_finisher_action"
/// Blackboard key: the downed victim the mob is closing on to finish
#define BB_HV_FINISHER_VICTIM "BB_hv_finisher_victim"
/// Offset source for a finisher's poses
#define HV_FINISHER_OFFSET "hv_finisher"

/// Why a finisher ended. The killing blow landed and every stage ran.
#define HV_FINISHER_DONE 1
/// The victim was pulled clear, or the attacker was moved off them.
#define HV_FINISHER_LOST_GRIP 2
/// The attacker took enough damage to let go.
#define HV_FINISHER_DAMAGED 3
/// The attacker died, was deleted or was knocked out.
#define HV_FINISHER_ATTACKER_DOWN 4
/// The victim died or was deleted before the killing blow.
#define HV_FINISHER_VICTIM_GONE 5
/// It ran past its longest possible length. A safety net, never the plan.
#define HV_FINISHER_TIMED_OUT 6

// Brain burst, gut spill and gut tether (voidcrew/modules/hyperviolence/braingut/). The guts come out with tg's chest organ spill, so they have no odds of their own.

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

/// How far the guts can lie from their owner before the owner is dragged against them.
#define HV_GUT_TETHER_RANGE 3
/// How far apart the guts and their owner can get before the tether tears.
#define HV_GUT_TETHER_SNAP_RANGE 7
/// Minimum time between the pain of two tugs on the tether.
#define HV_GUT_YANK_COOLDOWN (2 SECONDS)
/// Brute damage to the chest from one tug on the tether.
#define HV_GUT_YANK_DAMAGE 4

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
