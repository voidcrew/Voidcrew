/**
 * # Bounty lairs: shared types
 *
 * Owner: the integration lead (frozen, like bounty_types.dm). Decision 20: custom ruins for Most Wanted bosses,
 * kill-only bounties, the lich, and the mafia club. Spec section 14.
 *
 * Every type the lair packages share, and every var more than one of them reads or writes, is declared here and
 * nowhere else. This file sets no built-in values (name, icon, health): each type's owner sets them in its own
 * file. P10 lair framework (bounty_lair.dm), P11 mafia club map (bounty_lair_maps.dm and the .dmm), P12 mafia
 * mobs and the don's mech (bounty_lair_mafia.dm).
 */

/// A lair ruin spawned for one posting and released when the posting closes. P10 owns it.
/obj/structure/overmap/space_ruin/bounty_lair
	/// Weakref to the posting (/datum/criminal_bounty) the lair was spawned for
	var/datum/weakref/posting_ref
	/// Whether the loaded interior has been indexed and its boss spawned (once per load)
	var/lair_linked = FALSE

/// Where a lair's boss appears when the interior loads. Placed on the map (P11); P10 spawns boss_type there.
/obj/effect/landmark/bounty_lair_boss
	/// The boss to spawn here (a /mob/living/basic/bounty_lair_boss path), set on the map
	var/boss_type

/// A lair's gatekeeper spot. P10 spawns gatekeeper_type here at load; when every gatekeeper in the lair is dead, P10 opens the lair's gate poddoors (mapped with id "bounty_lair_gate").
/obj/effect/landmark/bounty_lair_gatekeeper
	/// The mob to spawn here as a gatekeeper, set on the map (the mafia lieutenant for the club)
	var/gatekeeper_type

/// The base of lair bosses: never under /mob/living/basic/boss (megafauna are banned from ruins and outposts). P12 sets the mafia ones.
/mob/living/basic/bounty_lair_boss
	/// Weakref to the posting (/datum/criminal_bounty), or null for an admin spawn
	var/datum/weakref/posting_ref

/// The don in his mech (phase one). P12.
/mob/living/basic/bounty_lair_boss/mafia_mech
/// The don on foot after the mech breaks (phase two). His death drops the trophy. P12.
/mob/living/basic/bounty_lair_boss/mafia_don

/// Mafia goons for the club. P12 sets them (lootless, club outfits); P11 places their markers.
/mob/living/basic/trooper/russian/mafia
/mob/living/basic/trooper/russian/mafia/pistol
/mob/living/basic/trooper/russian/mafia/smg
/// Tougher; their deaths open the arena (P10's gate rule). P12.
/mob/living/basic/trooper/russian/mafia/lieutenant

/// Room spawner for the club's goons. P12 sets its tables; P11 places it on the map (the loot test requires every zone_mobs subtype to appear in a ruin map).
/obj/effect/zone_mobs/mafia

/// A kill-only bounty's proof: the boss's trophy, turned in at a pad for the full value. P10 owns the base values.
/obj/item/bounty_proof/trophy
/// The don's gold signet ring. P12 sets its values.
/obj/item/bounty_proof/trophy/mafia_don
/// A shard of the lich's crown. P10 sets its values.
/obj/item/bounty_proof/trophy/lich
