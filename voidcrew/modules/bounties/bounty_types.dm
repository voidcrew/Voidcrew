/**
 * # Bounty hunting: shared types
 *
 * Owner: P0 seams (frozen). Only the integration lead edits this file.
 *
 * Every type the bounty packages share, and every var more than one package reads or writes, is
 * declared here and nowhere else, so two packages never declare the same var. The design is in
 * the spec (section 11 lists the packages and the API between them).
 *
 * Rules for the packages:
 * - Never declare a var on these types in your own file, unless only your package uses it. Then
 *   declare it in your own file with a prefix that names your package (`identity_`, `body_`,
 *   `ai_`, `boss_`, `board_`, `outpost_`, `prison_`, `admin_`), or on a subtype only you use.
 * - This file sets no built-in var values (name, icon, health and the like). Each type's owner sets
 *   them in its own file (the owner is noted on each type below). This file is included after
 *   every other file in the folder, and DM keeps the last value set for a var on a type without a
 *   warning, so a value set here would quietly override the owner's.
 * - For the same reason, don't give one of the vars below a different default on the type itself
 *   in your file. Set it on your own subtype, or at runtime.
 * - Before adding a proc to one of these types, search for the name. A second definition of the
 *   same proc on the same type is not an error: DM chains the two by include order, and which one
 *   runs depends on file names.
 */

/// Every live posting (/datum/criminal_bounty), public and private. P5 adds and removes them.
GLOBAL_LIST_EMPTY(criminal_bounties)
/// Records of criminals caught alive (/datum/bounty_record), oldest first, waiting for a prison. P7 adds and takes them.
GLOBAL_LIST_EMPTY(bounty_prisoner_pool)

/// "Petty", "Wanted" or "Most Wanted": what the board, the wanted boards, the prison and the admin panel call a tier
/proc/bounty_tier_name(tier)
	switch(tier)
		if(BOUNTY_TIER_PETTY)
			return "Petty"
		if(BOUNTY_TIER_WANTED)
			return "Wanted"
		if(BOUNTY_TIER_MOST_WANTED)
			return "Most Wanted"
	return "Unknown"

// ===== THE RECORD =====

/**
 * Who a criminal is, from posting to the end of their prison time. P1 fills it in
 * (generate_bounty_record()), P5 posts and pays on it, P7 rebuilds the prisoner from it. It holds
 * no hard reference to a mob, a ship or a prison, so it can outlive all of them in the pool.
 */
/datum/bounty_record
	/// Unique text id, set when the record is made
	var/id
	/// Real name
	var/name
	/// The name they go by at a trader outpost, and what examine shows there
	var/alias
	/// MALE or FEMALE
	var/gender
	/// Species typepath, /datum/species/...
	var/species
	/// How they look: body, hair and colours (/datum/bounty_look). P1's look builder dresses any mob in it.
	var/datum/bounty_look/look
	/// What they are wanted for, a lower-case phrase: "smuggling". The prison shows "wanted for <crime>".
	var/crime
	/// BOUNTY_TIER_*
	var/tier
	/// BOUNTY_ARCHETYPE_*
	var/archetype
	/// BOUNTY_STYLE_* for a normal or meek criminal, else null
	var/style
	/// BOUNTY_KIT_* for a mini-boss, else null
	var/kit
	/// Distinguishing features, as P1's feature keys; feature_lines() turns them into examine lines
	var/list/features
	/// What carries into the prison beyond the tier: P1's trait keys, which P7's danger helpers read
	var/list/prison_traits
	/// Base value in credits, rolled when posted, before the zone multiplier and the pay share
	var/base_value = 0
	/// How hurt they were when caught, 0 (unhurt) to 1; they arrive in prison as hurt
	var/hurt_fraction = 0
	/// Name of the ship that brought them in, kept after the ship is gone
	var/captor_name
	/// Weakref to the ship that brought them in (/obj/structure/overmap/ship)
	var/datum/weakref/captor_ship
	/// Weakref to the prison (/datum/outpost_prison) that gets them first: the captor's own running prison
	var/datum/weakref/preferred_prison
	/// BOUNTY_RECORD_*
	var/status = BOUNTY_RECORD_WANTED
	/// world.time the record was made
	var/created_at = 0
	/// Their mugshot, a base64 PNG built once and cached here (bounty_record_mugshot())
	var/mugshot
	/// How they looked when the mugshot was taken, if that differs from how they look now (a trader-outpost fugitive has changed their hair or clothes). P1 fills it (make_old_look()); the mugshot uses it when set.
	var/datum/bounty_look/old_look

/datum/bounty_record/New()
	. = ..()
	var/static/next_id = 0
	id = "[++next_id]"
	created_at = world.time

/**
 * The body and colours of a criminal, stored so P1's builder can put the same face on any mob, in
 * any outfit, at any time: the wanted criminal, a decoy made to look like them, the prisoner they
 * become.
 */
/datum/bounty_look
	/// Species typepath, /datum/species/...
	var/species
	/// MALE or FEMALE body
	var/physique
	/// A key of GLOB.skin_tones, for species that use skin tones
	var/skin_tone
	/// Hairstyle name (SSaccessories.hairstyles_list)
	var/hairstyle
	/// "#rrggbb"
	var/hair_color
	/// Facial hairstyle name (SSaccessories.facial_hairstyles_list)
	var/facial_hairstyle
	/// "#rrggbb"
	var/facial_hair_color
	/// "#rrggbb"
	var/eye_color
	/// Species features (dna.features), as a copy
	var/list/features

// ===== THE POSTING =====

/**
 * One criminal bounty on the board, public or offered privately to one ship. P5 makes, runs and
 * closes it (bounty_posting.dm); P6 adds the trader-outpost parts (decoys, alert); P8 lists and
 * closes it. Mobs are held by weakref; the sighting marker belongs to the posting.
 */
/datum/criminal_bounty
	/// Who is wanted (/datum/bounty_record)
	var/datum/bounty_record/record
	/// BOUNTY_PLACEMENT_*
	var/placement_kind
	/// Weakref to where the criminal is: the overmap object of the planet, ruin, pirate ship or trader outpost
	var/datum/weakref/site_ref
	/// Weakref to the criminal's mob while its site is loaded (/mob/living/basic/bounty_criminal)
	var/datum/weakref/criminal_ref
	/// Weakref to the ship a private offer is for; null for a public bounty
	var/datum/weakref/private_to
	/// Weakrefs to the ships hunting it, for the board and the notices. Hunting is not needed to turn it in: any ship with the criminal on its own pad can.
	var/list/claimants = list()
	/// BOUNTY_POSTING_*
	var/status = BOUNTY_POSTING_OPEN
	/// Credits it pays at 100%: the record's base value times the zone multiplier
	var/value = 0
	/// world.time it comes off the board
	var/expires_at = 0
	/// Weakrefs to its decoys at a trader outpost (/mob/living/basic/bounty_criminal/decoy)
	var/list/decoys = list()
	/// Weakrefs to the criminal's companions (/mob/living/basic/bounty_companion)
	var/list/companions = list()
	/// The sighting marker hunters' GPS units point to
	var/obj/effect/bounty_sighting/marker
	/// Where the criminal was last seen: the turf the marker was last moved near
	var/turf/last_seen
	/// How alert the fugitive is at a trader outpost: wrong warrants and hits on decoys raise it
	var/alert = 0
	/// Goes up whenever what the board's static data shows about this posting changes, so the UI resends it
	var/static_data_serial = 0

/// The criminal's mob, if its site is loaded and it still exists
/datum/criminal_bounty/proc/criminal()
	var/mob/living/basic/bounty_criminal/criminal = criminal_ref?.resolve()
	return QDELETED(criminal) ? null : criminal

// ===== THE CRIMINALS =====

/**
 * A wanted criminal, while its site is loaded. Its own mob family: not an outpost prisoner (a
 * caught criminal becomes a new prisoner, rebuilt from the record) and never under
 * /mob/living/basic/boss (megafauna are banned from outposts). No AI controller until P3 gives it
 * one. Built-in values are set by P2 in bounty_criminal.dm.
 */
/mob/living/basic/bounty_criminal
	/// Who they are (/datum/bounty_record)
	var/datum/bounty_record/record
	/// Weakref to the posting they are wanted on (/datum/criminal_bounty); null for an admin spawn with none
	var/datum/weakref/posting_ref
	/// At or below the downed line: floored, harmless and draggable until they recover (P2)
	var/downed = FALSE
	/// Hidden in a locker, a crate, as a potted plant or in the dark (P3)
	var/hidden = FALSE
	/// The restraints on them, held in their contents (P2), or null
	var/obj/item/restraints/handcuffs/restraints
	/// Weakrefs to their companions (/mob/living/basic/bounty_companion)
	var/list/companions = list()
	/// Blending in at a trader outpost: the fugitive and its decoys idle, talk and move the same way (P6, P3)
	var/blended = FALSE
	/// Weakrefs to the mobs they may fight: those who attacked, confronted or cuffed them (P2's may_attack())
	var/list/grudge = list()
	/// Their leash, list(min_x, min_y, max_x, max_y, z), or null for none (P2's leash_ok())
	var/list/site_bounds
	/// The worst capture state they have reached (BOUNTY_STATE_*): once downed or dead, the pay share never rises again. P2 writes it, P5 pays on it.
	var/worst_state = BOUNTY_STATE_FREE

/// The posting they are wanted on, if it still exists
/mob/living/basic/bounty_criminal/proc/posting()
	var/datum/criminal_bounty/posting = posting_ref?.resolve()
	return QDELETED(posting) ? null : posting

/// A meek criminal: runs, hides, blends in. P2 sets its body, P3 its AI.
/mob/living/basic/bounty_criminal/meek

/// A normal criminal: found doing something, fights back. P2 sets its body, P3 its AI.
/mob/living/basic/bounty_criminal/normal

/// A mini-boss: the base of the five kits. P4 sets its body and AI in bounty_boss.dm.
/mob/living/basic/bounty_criminal/boss

/mob/living/basic/bounty_criminal/boss/juggernaut
/mob/living/basic/bounty_criminal/boss/pyromaniac
/mob/living/basic/bounty_criminal/boss/demolitionist
/mob/living/basic/bounty_criminal/boss/ghost
/mob/living/basic/bounty_criminal/boss/heavy

/**
 * A patron at a trader outpost who shares some of the fugitive's features. Same body, same
 * blended-in mode and same examine layout as the fugitive, so nothing about it gives the fugitive
 * away; only what a warrant does to it differs. P6 owns its behaviour (bounty_outpost.dm).
 */
/mob/living/basic/bounty_criminal/decoy

/**
 * Someone with a normal criminal: fights beside them, is not a bounty and pays nothing. P3 owns it
 * (bounty_companions.dm) and sets its built-in values.
 */
/mob/living/basic/bounty_companion
	/// Weakref to the criminal they are with (/mob/living/basic/bounty_criminal)
	var/datum/weakref/leader_ref

// ===== OBJECTS =====

/**
 * Where a criminal was last seen: an invisible marker, moved near the criminal now and then, that
 * hunters' GPS units point to (never the mob itself). P5 owns it (bounty_placement.dm).
 */
/obj/effect/bounty_sighting
	/// Weakref to the posting (/datum/criminal_bounty)
	var/datum/weakref/posting_ref

/// A printed warrant: mugshot, listing and features. P5 prints it; P6 uses it to confront people (bounty_outpost.dm owns the type).
/obj/item/paper/bounty_warrant
	/// Weakref to the posting (/datum/criminal_bounty)
	var/datum/weakref/posting_ref

/// A locked board on a trader outpost's concourse showing the public Wanted list. P6 owns it (bounty_outpost.dm).
/obj/structure/bounty_wanted_board

/**
 * What is left of a criminal whose body was destroyed (gibbed, dusted, lost in lava or a chasm): proof of
 * death that the pad takes for the dead share. P2 drops it through bounty_drop_proof(); P5 owns the type's
 * values and takes it at the pad (bounty_turn_in.dm).
 */
/obj/item/bounty_proof
	/// Weakref to the posting (/datum/criminal_bounty)
	var/datum/weakref/posting_ref
	/// Whose it is
	var/datum/bounty_record/record
