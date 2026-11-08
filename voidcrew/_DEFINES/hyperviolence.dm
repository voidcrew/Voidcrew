// Hyperviolence (voidcrew/modules/hyperviolence/): shared defines for the gore parts.

/// A plain bold line in the combined hit message.
#define HV_LINE_BOLD 1
/// A big bold-italic line, for severed limbs, burst heads and kills.
#define HV_LINE_HUGE 2

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
