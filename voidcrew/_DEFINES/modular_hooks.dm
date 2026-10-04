// Fork constants needed by upstream integration hooks. Included before upstream consumers.

/// How many separate over-threshold seconds a client must rack up before it is autokicked.
/// A real flood (a plugged-in game controller, a scripted client) trips every consecutive
/// second and reaches this in about three seconds; a lag spike flushes one buffered burst.
#define KEYPRESS_FLOOD_STRIKES_TO_KICK 3

/// Strikes older than this are forgiven, so unrelated spikes minutes apart never add up.
#define KEYPRESS_FLOOD_STRIKE_MEMORY (30 SECONDS)

/// Strike count at which the client gets a warning, before any kick.
#define KEYPRESS_FLOOD_STRIKES_TO_WARN 2

/// Tick usage above which a keysend burst is assumed to be the server flushing queued
/// input rather than the client flooding, and so does not earn a strike.
#define KEYPRESS_FLOOD_LAG_TICK_USAGE 80

/// Megafauna arenas. Priced above what they pay back so a boss dive is funded by
/// running the rest of the roster, instead of paying for itself forever.
#define BITRUNNER_COST_BOSS 5

/// The four hardest megafauna arenas. Same idea, steeper.
#define BITRUNNER_COST_APEX_BOSS 8

/// Collect attached decal elements: (list/decals)
#define COMSIG_ATOM_GET_DECALS "atom_get_decals"

/// After normal /mob/living/UnarmedAttack resolution: (atom/target, list/modifiers, health_damage, stamina_damage).
/// Damage is the synchronous change during this attack; target may have been deleted by a lethal hit.
#define COMSIG_LIVING_AFTER_UNARMED_ATTACK "living_after_unarmed_attack"

/// Sent to the destination of a proposed stack merge: (obj/item/stack/source_stack, inhand)
#define COMSIG_STACK_CAN_RECEIVE_MERGE "stack_can_receive_merge"

/// Sent before a split source can be deleted: (obj/item/stack/new_stack)
#define COMSIG_STACK_SPLIT "stack_split"

#define ui_human_skills "EAST-4:22,SOUTH+1:7"

#define RADIO_CHANNEL_WIDEBAND "Wideband"

#define RADIO_KEY_WIDEBAND "w"

#define RADIO_TOKEN_WIDEBAND ":w"

#define RADIO_COLOR_WIDEBAND "#d99620"

#define FREQ_WIDEBAND 1339 // VOIDCREW EDIT ADDITION - galaxy-wide hailing channel, amber

#define REACTION_NOT_IN_PLANTS (1<<8)

///The reaction opts into pH-driven purity. Unset (the fork-wide default) means pH is a live,
///drifting number that no reaction is blocked or purity-penalised by, so a recipe's optimal
///pH band never has to contain 7 to be usable. Set it to bring tg's pH mechanics back for
///that one recipe.
#define REACTION_USES_PURITY (1<<9)

#define RESERVATION_ORIGIN_STRIDE 8

#define PORT_COMPOSITE_TYPE_CHEMICAL "chemical list"

/// Reagent-type -> volume mapping, the currency the chemistry circuits pass around.
#define PORT_TYPE_CHEMICAL_LIST SSwiremod_composite.composite_datatype(PORT_COMPOSITE_TYPE_CHEMICAL, PORT_TYPE_DATUM, PORT_TYPE_NUMBER)

/// Allows an item action in soft crit, while still checking other incapacitation sources.
#define ALLOW_SOFT_CRIT (1<<13)
