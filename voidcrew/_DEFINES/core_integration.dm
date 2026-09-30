#define R_ECONOMY (1<<15)

/// Megafauna arenas. Priced above what they pay back so a boss dive is funded by
/// running the rest of the roster, instead of paying for itself forever.
#define BITRUNNER_COST_BOSS 5
/// The four hardest megafauna arenas. Same idea, steeper.
#define BITRUNNER_COST_APEX_BOSS 8

/// Collect attached decal elements: (list/decals)
#define COMSIG_ATOM_GET_DECALS "atom_get_decals"

/// Voidcrew. From base of /atom/movable/lateShuttleMove, once every moved atom has landed and rotated: (turf/oldT, list/movement_force, move_dir)
#define COMSIG_ATOM_LATE_SHUTTLE_MOVE "movable_late_shuttle_move"

/// After normal /mob/living/UnarmedAttack resolution: (atom/target, list/modifiers, health_damage, stamina_damage).
/// Damage is the synchronous change during this attack; target may have been deleted by a lethal hit.
#define COMSIG_LIVING_AFTER_UNARMED_ATTACK "living_after_unarmed_attack"

/// Sent to the destination of a proposed stack merge: (obj/item/stack/source_stack, inhand)
#define COMSIG_STACK_CAN_RECEIVE_MERGE "stack_can_receive_merge"
/// Sent before a split source can be deleted: (obj/item/stack/new_stack)
#define COMSIG_STACK_SPLIT "stack_split"

#define ui_human_skills "EAST-4:22,SOUTH+1:7"

/// Allows an item action in soft crit, while still checking other incapacitation sources.
#define ALLOW_SOFT_CRIT (1<<13)

//Voidcrew: reaction refuses to run inside a grown food item, so plant
//chemistry can't be used to mass-produce the mob-spawning mixtures.
#define REACTION_NOT_IN_PLANTS (1<<8)
///The reaction opts into pH-driven purity. Unset (the fork-wide default) means pH is a live,
///drifting number that no reaction is blocked or purity-penalised by, so a recipe's optimal
///pH band never has to contain 7 to be usable. Set it to bring tg's pH mechanics back for
///that one recipe.
#define REACTION_USES_PURITY (1<<9)


//Voidcrew: chemistry circuits
#define PORT_COMPOSITE_TYPE_CHEMICAL "chemical list"
/// Reagent-type -> volume mapping, the currency the chemistry circuits pass around.
#define PORT_TYPE_CHEMICAL_LIST SSwiremod_composite.composite_datatype(PORT_COMPOSITE_TYPE_CHEMICAL, PORT_TYPE_DATUM, PORT_TYPE_NUMBER)
