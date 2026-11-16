/**
 * # Bounty hunting: suits where the air kills, and the crew's things at the pad
 *
 * Owner: A1 company and suits. Criminals and companions are real human NPCs, so they breathe, freeze and
 * suffocate as anyone does (human_npc.dm); the human NPC base dresses them for the air where they are made
 * (human_npc_outfits.dm). This file adds the bounty's rules on top:
 *
 * - Where they are dressed for. At a space ruin, vacuum is a door away, so a criminal there is always
 *   dressed for it; on a planet, so is one whose site has air that would hurt a person on any of a few
 *   tiles read at random, not only on its own (bounty_site_dress_for()). Companions are dressed for what
 *   their criminal was (bounty_companions.dm).
 * - What they seal up in (bounty_vacuum_gear()): a suit in the armour class of what they wear in good air,
 *   so the vacuum neither strips nor gives armour. Petty and meek criminals and companions wear a soft
 *   suit; a Wanted or Most Wanted criminal, who wears an armour vest, an armoured space suit; a mini-boss
 *   its kit's own (bounty_boss_kits.dm). It is real gear, locked to them like the rest (D3,
 *   human_npc_gear.dm): it can't be stripped and never becomes loot.
 * - Suiting up a catch. A hunter can put their own pressure suit or helmet on a criminal that is down,
 *   cuffed, stunned or dead, through the strip menu: it goes on in place of the locked piece in that slot,
 *   which is gone, taking as long as taking one off a person and putting the other on. It is the hunter's
 *   and can come off again like on anyone. An empty slot takes one the ordinary way.
 * - The pad gives the crew back everything they put on the body (bounty_return_crew_items()).
 */

/// Soft suits, for those who wear no armour, each list(suit, helmet)
GLOBAL_LIST_INIT(bounty_soft_suits, list(
	list(/obj/item/clothing/suit/space/eva, /obj/item/clothing/head/helmet/space/eva),
	list(/obj/item/clothing/suit/space, /obj/item/clothing/head/helmet/space),
	list(/obj/item/clothing/suit/space/nasavoid, /obj/item/clothing/head/helmet/space/nasavoid),
))

/// Armoured space suits, for those who wear an armour vest, each list(suit, helmet)
GLOBAL_LIST_INIT(bounty_armoured_suits, list(
	list(/obj/item/clothing/suit/space/syndicate/black, /obj/item/clothing/head/helmet/space/syndicate/black),
	list(/obj/item/clothing/suit/space/syndicate/black/green, /obj/item/clothing/head/helmet/space/syndicate/black/green),
	list(/obj/item/clothing/suit/space/syndicate/black/blue, /obj/item/clothing/head/helmet/space/syndicate/black/blue),
	list(/obj/item/clothing/suit/space/syndicate/black/orange, /obj/item/clothing/head/helmet/space/syndicate/black/orange),
))

// ===== WHERE THEY ARE DRESSED FOR =====

/**
 * The BOUNTY_PLACEMENT_* kind of the site a spawn context was made for (the overmap object it names:
 * spawn_bounty_criminal() makes the criminal's from its site, and companions inherit it), or null.
 */
/proc/bounty_site_kind_of(datum/npc_spawn_context/context)
	var/source_type = context?.source_type
	if(ispath(source_type, /obj/structure/overmap/planet))
		return BOUNTY_PLACEMENT_PLANET
	if(ispath(source_type, /obj/structure/overmap/space_ruin))
		return BOUNTY_PLACEMENT_RUIN
	if(ispath(source_type, /obj/structure/overmap/ship/npc/pirate))
		return BOUNTY_PLACEMENT_NPC_SHIP
	if(ispath(source_type, /obj/structure/overmap/trader_outpost))
		return BOUNTY_PLACEMENT_TRADER_OUTPOST
	return null

/**
 * HUMAN_NPC_SITE_* flags a bounty NPC made for `context`'s site is dressed for whatever the air on its own
 * tile: vacuum at a space ruin, and on a planet whatever a few of its tiles' air asks of a person
 * (bounty_planet_site()). The human NPC base adds the spawn tile's own. NONE anywhere else.
 */
/proc/bounty_site_dress_for(datum/npc_spawn_context/context)
	switch(bounty_site_kind_of(context))
		if(BOUNTY_PLACEMENT_RUIN)
			return HUMAN_NPC_SITE_VACUUM
		if(BOUNTY_PLACEMENT_PLANET)
			return bounty_planet_site(locate(context.source_id))
	return NONE

/**
 * What the air of `planet`'s site asks of a person (HUMAN_NPC_SITE_* flags), read on
 * BOUNTY_SITE_AIR_SAMPLES open tiles picked at random within its footprint: a criminal in a sealed ruin
 * on a planet whose air would kill it still has to go out in it.
 */
/proc/bounty_planet_site(obj/structure/overmap/planet/planet)
	. = NONE
	if(!istype(planet) || QDELETED(planet))
		return
	var/list/bounds = bounty_site_bounds(planet)
	if(length(bounds) < 5)
		return
	for(var/i in 1 to BOUNTY_SITE_AIR_SAMPLES)
		var/turf/open/sample = locate(rand(bounds[1], bounds[3]), rand(bounds[2], bounds[4]), bounds[5])
		if(!istype(sample) || is_space_or_openspace(sample))
			continue
		. |= human_npc_site_at(sample)

/// Whether the human NPC base will seal `npc` up as it dresses it (npc_fit_outfit_to_site()): its site asks for it, and its species isn't proof against both vacuum and its cold
/proc/bounty_dressing_sealed(mob/living/carbon/human/npc/npc, datum/human_npc_outfit_table/table)
	var/site = human_npc_site_at(get_turf(npc)) | npc.npc_always_site | table?.always_site
	if(!(site & HUMAN_NPC_SITE_VACUUM))
		return FALSE
	return !(HAS_TRAIT(npc, TRAIT_RESISTLOWPRESSURE) && HAS_TRAIT(npc, TRAIT_RESISTCOLD))

// ===== WHAT THEY SEAL UP IN =====

/mob/living/carbon/human/npc
	/// The sealed suit and helmet it was given for vacuum, list(suit, helmet), once it has been dressed in them (bounty_vacuum_gear())
	var/list/suits_vacuum_gear

/**
 * The suit and helmet a bounty NPC seals up in where the air would kill it: list(suit, helmet) typepaths,
 * a null helmet keeping its own (already sealed). Null for the human NPC base's plain EVA layer. Each
 * family overrides it; a random pick is fine, as it is asked once per body (bounty_vacuum_gear()).
 */
/mob/living/carbon/human/npc/proc/bounty_sealed_gear()
	return null

/// A soft suit or an armoured one for a criminal of `tier` (BOUNTY_TIER_*): armoured for those who wear an armour vest (bounty_add_tier_armour())
/proc/bounty_tier_sealed_gear(tier)
	if(isnull(tier) || tier == BOUNTY_TIER_PETTY)
		return pick(GLOB.bounty_soft_suits)
	return pick(GLOB.bounty_armoured_suits)

/mob/living/carbon/human/npc/bounty_criminal/normal/bounty_sealed_gear()
	return bounty_tier_sealed_gear(record?.tier)

/mob/living/carbon/human/npc/bounty_criminal/meek/bounty_sealed_gear()
	return bounty_tier_sealed_gear(record?.tier)

// A mini-boss's kit sets its own (bounty_boss_kits.dm); one with none wears plain clothes, so a soft suit
/mob/living/carbon/human/npc/bounty_criminal/boss/bounty_sealed_gear()
	return pick(GLOB.bounty_soft_suits)

/mob/living/carbon/human/npc/bounty_companion/bounty_sealed_gear()
	return pick(GLOB.bounty_soft_suits)

/**
 * The sealed suit and helmet `npc` wears where the air would kill it (bounty_sealed_gear()), the same
 * every time it is asked: list(suit, helmet), or null for the plain EVA layer. Anything that changes a
 * bounty NPC's clothes later (the chrome exposure, a blend) leaves these pieces alone.
 */
/proc/bounty_vacuum_gear(mob/living/carbon/human/npc/npc)
	if(!ishumannpc(npc))
		return null
	if(isnull(npc.suits_vacuum_gear))
		var/list/gear = npc.bounty_sealed_gear()
		npc.suits_vacuum_gear = islist(gear) ? gear.Copy() : list()
	return length(npc.suits_vacuum_gear) ? npc.suits_vacuum_gear : null

/**
 * `outfit` (a typepath or an instance) with `npc`'s own sealed suit and helmet on, if it is about to be
 * sealed up for vacuum (bounty_dressing_sealed()): the human NPC base then finds it sealed, and only adds
 * the air tank. Anything the old suit held moves to the backpack, as the base's layers do. Returns the
 * outfit unchanged when nothing is needed, else an instance (one passed in is changed in place).
 */
/proc/bounty_seal_outfit(mob/living/carbon/human/npc/npc, outfit, datum/human_npc_outfit_table/table)
	if(isnull(outfit) || !bounty_dressing_sealed(npc, table))
		return outfit
	var/list/gear = bounty_vacuum_gear(npc)
	if(length(gear) < 2 || !ispath(gear[1], /obj/item/clothing/suit))
		return outfit
	var/datum/outfit/dressed = ispath(outfit, /datum/outfit) ? new outfit() : outfit
	if(!istype(dressed))
		return outfit
	if(dressed.suit_store)
		if(dressed.back)
			LAZYADDASSOC(dressed.backpack_contents, dressed.suit_store, 1)
		dressed.suit_store = null
	dressed.suit = gear[1]
	var/obj/item/clothing/own_head = dressed.head
	if(ispath(gear[2], /obj/item/clothing/head))
		dressed.head = gear[2]
	else if(!ispath(own_head, /obj/item/clothing) || !(initial(own_head.clothing_flags) & STOPSPRESSUREDAMAGE) || !initial(own_head.min_cold_protection_temperature) || initial(own_head.min_cold_protection_temperature) > SPACE_HELM_MIN_TEMP_PROTECT)
		dressed.head = /obj/item/clothing/head/helmet/space
	return dressed

// ===== SUITING UP A CATCH =====

/// Whether `garment` is a pressure suit or helmet `user` could put on someone in `slot` (ITEM_SLOT_OCLOTHING or ITEM_SLOT_HEAD)
/proc/bounty_pressure_garment_for(obj/item/clothing/garment, slot)
	if(!istype(garment) || QDELETED(garment) || !(garment.clothing_flags & STOPSPRESSUREDAMAGE) || !(garment.slot_flags & slot))
		return FALSE
	if(HAS_TRAIT(garment, TRAIT_NODROP) || (garment.item_flags & ABSTRACT))
		return FALSE
	switch(slot)
		if(ITEM_SLOT_OCLOTHING)
			return istype(garment, /obj/item/clothing/suit)
		if(ITEM_SLOT_HEAD)
			return istype(garment, /obj/item/clothing/head)
	return FALSE

/**
 * The pressure suit or helmet `user` holds ready to put on it in place of `worn`, one of its own locked
 * pieces in the suit or head slot, or null when this isn't that (any other reach goes to tg's strip menu
 * as it is). A hood belongs to its suit, and goes with it.
 */
/mob/living/carbon/human/npc/bounty_criminal/proc/suits_garment_offered(mob/user, obj/item/worn)
	if(!ismob(user) || !istype(worn) || worn.loc != src || !human_npc_gear_locked(worn))
		return null
	if(istype(worn, /obj/item/clothing/head/hooded))
		return null
	var/slot = get_slot_by_item(worn)
	if(slot != ITEM_SLOT_OCLOTHING && slot != ITEM_SLOT_HEAD)
		return null
	var/obj/item/clothing/garment = user.get_active_held_item()
	return bounty_pressure_garment_for(garment, slot) ? garment : null

/**
 * The bounty_body component's strip hook (bounty_criminal.dm): `user` reaches for `worn` through the strip
 * menu. With a pressure suit or helmet in hand for a slot its own locked piece fills, on a criminal that is
 * down, cuffed, stunned or dead, the hunter starts putting theirs on (suits_put_on()); on one that is free,
 * it pulls away. Returns COMPONENT_CANT_STRIP when it takes the reach over, so tg's strip doesn't go on to
 * refuse the locked piece, else NONE.
 */
/mob/living/carbon/human/npc/bounty_criminal/proc/suits_strip_reach(mob/user, obj/item/worn)
	var/obj/item/clothing/garment = suits_garment_offered(user, worn)
	if(!garment)
		return NONE
	if(capture_state() == BOUNTY_STATE_FREE)
		balloon_alert(user, "[p_they()] pull[p_s()] away!")
		return COMPONENT_CANT_STRIP
	INVOKE_ASYNC(src, PROC_REF(suits_put_on), user, worn, garment)
	return COMPONENT_CANT_STRIP

/**
 * `user` puts `garment` on it in place of `worn`: as long as taking the one off a person and putting the
 * other on (`worn`'s strip delay and `garment`'s equip delay), standing beside it. Sleeps. Returns TRUE if
 * it went on.
 */
/mob/living/carbon/human/npc/bounty_criminal/proc/suits_put_on(mob/user, obj/item/worn, obj/item/clothing/garment)
	garment.item_start_equip(src, garment, user)
	if(!do_after(user, worn.strip_delay + garment.equip_delay_other, src, interaction_key = REF(garment)))
		return FALSE
	return suits_swap_now(user, worn, garment)

/**
 * Puts `garment`, from `user`'s hands, on it in place of `worn`, now: the locked piece is gone (it never
 * leaves the body as loot), and the garment is the hunter's, an ordinary item that can come off again.
 * Only while it is still the same reach: `worn` in its slot, `garment` in the hunter's hand, the hunter
 * beside it, and it down, cuffed, stunned or dead. Returns TRUE if it went on. Doesn't sleep.
 */
/mob/living/carbon/human/npc/bounty_criminal/proc/suits_swap_now(mob/user, obj/item/worn, obj/item/clothing/garment)
	if(QDELETED(src) || QDELETED(user) || !user.Adjacent(src))
		return FALSE
	if(suits_garment_offered(user, worn) != garment || capture_state() == BOUNTY_STATE_FREE)
		return FALSE
	var/slot = get_slot_by_item(worn)
	// One that wouldn't fit them (their species, their shape) leaves their own piece on
	if(!can_equip(garment, slot, disable_warning = TRUE, bypass_equip_delay_self = TRUE, ignore_equipped = TRUE))
		return FALSE
	if(!user.temporarilyRemoveItemFromInventory(garment))
		return FALSE
	qdel(worn)
	if(!equip_to_slot_if_possible(garment, slot, disable_warning = TRUE, bypass_equip_delay_self = TRUE))
		user.put_in_hands(garment)
		return FALSE
	finish_equip_mob(garment, src, user)
	return TRUE

// ===== THE CREW'S THINGS =====

/// Whether `item`, directly on a bounty NPC's body, is something the crew put there: not its own locked gear or consumables, and not part of the body (limbs, organs, implants). A hood goes with its suit.
/proc/bounty_crew_item(obj/item/item)
	if(!istype(item) || QDELETED(item) || (item.item_flags & ABSTRACT))
		return FALSE
	if(isbodypart(item) || isorgan(item) || istype(item, /obj/item/implant) || istype(item, /obj/item/clothing/head/hooded))
		return FALSE
	return !HAS_TRAIT(item, TRAIT_HUMAN_NPC_GEAR) && !HAS_TRAIT(item, TRAIT_HUMAN_NPC_CONSUMABLE)

/**
 * Puts down at `spot` everything the crew put on `body`: their cuffs, a suit and helmet, an air tank in its
 * suit storage, whatever else. Its own gear goes with it (D3). Returns what was put down.
 */
/proc/bounty_return_crew_items(mob/living/carbon/human/npc/body, turf/spot)
	. = list()
	if(QDELETED(body) || !isturf(spot))
		return
	for(var/obj/item/item in body.contents.Copy())
		if(item.loc != body || !bounty_crew_item(item))
			continue
		if(body.transferItemToLoc(item, spot, force = TRUE))
			. += item
