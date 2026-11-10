// # Bounty hunting: criminal body defines
//
// Owner: P2 body (voidcrew/modules/bounties/bounty_criminal.dm, bounty_restraints.dm, bounty_outfits.dm,
// bounty_ai_human.dm). Only P2 edits this file. The shared enums are in bounties.dm.
//
// A criminal is a real human NPC (human NPC migration, phase D): its health, stamina, crit, cuffs and
// breakout times are tg's, so there are no health pools, stamina pools, downed lines, recovery timers
// or slip times here, and there must never be.
//
// Unit tests compile before voidcrew/_DEFINES and cannot see these: a test uses the literal value,
// with a comment naming the define.

// ===== TRAITS =====

/// A script is walking the criminal somewhere on purpose (a cutscene): the leash lets its steps through. Walking out (npc_walk_out()) counts the same.
#define TRAIT_BOUNTY_SCRIPTED_MOVE "bounty_scripted_move"

/// Trait source for what the body always has (no teleports, no mob swaps). A convict a crew talks down loses them.
#define BOUNTY_BODY_TRAIT "bounty_body"

// ===== LEASH AND TARGETS (AR-D1, AR-D2) =====

/// Environment damage is refused within this many tiles of a ship, a hangar, a player outpost or a planet's dock strip
#define BOUNTY_ENV_SAFE_RANGE 7
/// Leash half-width around the spawn point when the site has no bounds of its own
#define BOUNTY_BODY_FALLBACK_LEASH 40
/// Most mobs a criminal remembers as fair game; the oldest go first
#define BOUNTY_GRUDGE_MAX 12

// ===== CUFFS, TOUGHNESS, SELF-TREATMENT =====

/// A criminal answers a reach for its wrists this long after tg's cuffing starts: a person's reaction, and inside tg's 4 second do_after, so stepping away breaks it
#define BOUNTY_CUFF_REACTION_DELAY (0.5 SECONDS)
/// Sent on a criminal when someone starts putting cuffs on it, before its own reaction: (mob/living/user). Return COMPONENT_BOUNTY_CUFF_HANDLED to take the reaction over.
#define COMSIG_BOUNTY_CUFF_REACHED "bounty_cuff_reached"
	#define COMPONENT_BOUNTY_CUFF_HANDLED (1<<0)
/// A cuffed criminal that started working at its cuffs this recently and then lost them got itself out
#define BOUNTY_SELF_FREED_WINDOW (2 MINUTES)
/// Brute and burn a criminal takes, as a multiple of a person's (physiology, npc_damage_taken), by tier. Armour does the rest.
#define BOUNTY_TOUGHNESS_PETTY 1
#define BOUNTY_TOUGHNESS_WANTED 0.9
#define BOUNTY_TOUGHNESS_MOST_WANTED 0.8
/// A bounty NPC treats itself when its health is at or below this share of its max, with nothing it can see attacking it
#define BOUNTY_TREAT_SELF_BELOW 0.7
/// Between two goes at treating itself
#define BOUNTY_TREAT_SELF_COOLDOWN (20 SECONDS)
/// Blackboard key: the medical stack it is using on itself has been clicked on it once this go (bounty_ai_human.dm)
#define BB_BOUNTY_TREAT_APPLIED "bounty_treat_applied"

// ===== SUITS (bounty_suits.dm) =====

/// Open tiles of a planet site, picked at random, whose air is read when a criminal is made there: any one that would hurt a person dresses it for that
#define BOUNTY_SITE_AIR_SAMPLES 6
