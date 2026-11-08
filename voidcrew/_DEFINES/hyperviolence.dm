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
/// Damage multiplier of a shot fired with the barrel against the head, for deciding the outcome.
#define HV_EXECUTION_POINT_BLANK_MULT 2
/// Extra multiplier for multi-pellet shells: at the muzzle every pellet lands together.
#define HV_EXECUTION_PELLET_MULT 1.5
/// Outcome damage (after armour) at which an execution bursts the head instead of holing it.
#define HV_EXECUTION_BURST_DAMAGE 80
/// A chambered round must deal at least this much to count as an execution round.
#define HV_EXECUTION_MIN_DAMAGE 10
/// Targets with more max health than this take the shot but are not finished off (bosses).
#define HV_EXECUTION_MAX_HEALTH 200
/// do_after interaction key for an execution wind-up.
#define DOAFTER_SOURCE_HV_EXECUTION "hv_execution"

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
