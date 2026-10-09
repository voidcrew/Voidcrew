// Limb rig (voidcrew/modules/limb_rig): the pieces a human's sprite is cut into so each can move.

#define RIG_HEAD "head"
#define RIG_CHEST "chest"
#define RIG_L_ARM "l_arm"
#define RIG_R_ARM "r_arm"
#define RIG_L_LEG "l_leg"
#define RIG_R_LEG "r_leg"
/// The tail, for species that give the rig one.
#define RIG_TAIL "tail"

/// How much longer arms and legs are drawn than the sprite, along their length.
#define RIG_ARM_STRETCH 1.25
#define RIG_LEG_STRETCH 1.3

/// What the rig is doing, which decides what it goes back to after a one-off animation.
#define RIG_ACTIVITY_IDLE "idle"
#define RIG_ACTIVITY_MOVING "moving"
#define RIG_ACTIVITY_ONESHOT "oneshot"
#define RIG_ACTIVITY_WORKING "working"

/// How a rigged body walks.
#define RIG_WALK_NORMAL "normal"
/// Long, loping, high-kneed strides with a sway. For very long legs.
#define RIG_WALK_LOPE "lope"
