/**
 * # Bounty hunting: what criminals and their people wear
 *
 * Owner: P2 body (the table, the base clothes and the tier armour). The families dress themselves by
 * overriding bounty_build_outfit(): P3 meek and normal criminals and companions, P4 the mini-boss kits,
 * P6 decoys, P9 the kingpin and his goons, P12 the mafia club.
 *
 * Toughness comes from what they wear (defaults 1.5, CR-12): petty criminals in plain clothes, Wanted in
 * an armour vest, Most Wanted in a vest and a helmet, mini-bosses in their kit's armour. It is real
 * armour on real slots, locked to the body (D3), so it protects by tg's armour rules and never drops.
 * Their weapons are carried, not held, until the fight starts, with real spare ammunition; their
 * self-treatment items are real (N6). The human NPC base adds a sealed suit and air in vacuum, a mask in
 * bad air and warm clothes in the cold, on top of whatever is picked here (human_npc_outfits.dm). In
 * vacuum the suit it seals up in is its own family's, in the armour class of what it wears in good air
 * (bounty_suits.dm).
 */

/**
 * The outfit table of every bounty human: it asks the NPC being dressed (bounty_build_outfit()), so
 * the choice can read its record, its tier, its style and its kit. Set as npc_outfit_table. Then the
 * clothes for its site go on (bounty_site_clothes(), companions), and its own sealed suit if it is about
 * to be sealed up for vacuum (bounty_seal_outfit()); the plain EVA layer is only the fallback.
 */
/datum/human_npc_outfit_table/bounty
	vacuum_layer = /datum/human_npc_layer/eva

/datum/human_npc_outfit_table/bounty/pick_outfit(mob/living/carbon/human/npc/npc, zone)
	if(!ishumannpc(npc))
		return null
	var/outfit = npc.bounty_build_outfit(zone || ZONE_GREEN)
	outfit = npc.bounty_site_clothes(outfit)
	return bounty_seal_outfit(npc, outfit, src)

/**
 * What a bounty human wears in `zone` (ZONE_*): a /datum/outfit typepath, or an instance made for it
 * (bounty_outfit_instance()). Null leaves it in whatever its look brings. Every bounty family overrides it.
 */
/mob/living/carbon/human/npc/proc/bounty_build_outfit(zone)
	return null

/**
 * `outfit` (from bounty_build_outfit()) in the clothes it wears for where it is, or as it is. Companions
 * swap their plain clothes for rough ones picked by their criminal's site (bounty_companions.dm).
 */
/mob/living/carbon/human/npc/proc/bounty_site_clothes(outfit)
	return outfit

/// A fresh outfit of `base_type`, to add weapons, armour and kit to before it is worn
/proc/bounty_outfit_instance(base_type)
	if(!ispath(base_type, /datum/outfit))
		return null
	return new base_type()

/**
 * Puts the armour of `tier` (BOUNTY_TIER_*) on `outfit`, an instance: Wanted an armour vest, Most Wanted
 * a vest and a helmet, Petty none. Anything the old suit carried in its storage moves to the backpack.
 */
/proc/bounty_add_tier_armour(datum/outfit/outfit, tier)
	if(!istype(outfit) || tier == BOUNTY_TIER_PETTY || isnull(tier))
		return outfit
	if(outfit.suit_store)
		if(outfit.back)
			LAZYADDASSOC(outfit.backpack_contents, outfit.suit_store, 1)
		outfit.suit_store = null
	outfit.suit = /obj/item/clothing/suit/armor/vest
	if(tier == BOUNTY_TIER_MOST_WANTED)
		outfit.head = /obj/item/clothing/head/helmet
	return outfit

/// The plain clothes a criminal of `archetype` (BOUNTY_ARCHETYPE_*) wears in `zone`
/proc/bounty_plain_clothes(archetype, zone)
	var/meek = archetype == BOUNTY_ARCHETYPE_MEEK
	switch(zone)
		if(ZONE_RED)
			return meek ? /datum/outfit/bounty_criminal/drifter : /datum/outfit/bounty_criminal/tough
		if(ZONE_YELLOW)
			return meek ? /datum/outfit/bounty_criminal/spacer : /datum/outfit/bounty_criminal/hauler
	return meek ? /datum/outfit/bounty_criminal : /datum/outfit/bounty_criminal/local

// A criminal with no family of its own to dress it: plain clothes for its archetype and zone, and its tier's armour.
/mob/living/carbon/human/npc/bounty_criminal/bounty_build_outfit(zone)
	var/datum/outfit/outfit = bounty_outfit_instance(bounty_plain_clothes(record?.archetype, zone))
	return bounty_add_tier_armour(outfit, record?.tier)

/// ZONE_GREEN, ZONE_YELLOW or ZONE_RED for where its site is (or where it stands), green if unknown
/mob/living/carbon/human/npc/bounty_criminal/proc/body_zone()
	var/atom/site = body_site_ref?.resolve()
	var/zone = site ? SSovermap_zones?.get_zone_type(get_turf(site)) : SSovermap_zones?.get_zone_type_anywhere(get_turf(src))
	return zone || ZONE_GREEN

// ===== PLAIN CLOTHES =====

/// Plain clothes for a meek criminal in green space
/datum/outfit/bounty_criminal
	name = "Bounty criminal: civilian"
	uniform = /obj/item/clothing/under/pants/jeans
	suit = /obj/item/clothing/suit/toggle/jacket/sweater
	shoes = /obj/item/clothing/shoes/sneakers/brown

/// A meek criminal in yellow space
/datum/outfit/bounty_criminal/spacer
	name = "Bounty criminal: spacer"
	uniform = /obj/item/clothing/under/color/grey
	suit = /obj/item/clothing/suit/jacket/bomber
	shoes = /obj/item/clothing/shoes/workboots
	head = /obj/item/clothing/head/beanie

/// A meek criminal in red space
/datum/outfit/bounty_criminal/drifter
	name = "Bounty criminal: drifter"
	uniform = /obj/item/clothing/under/color/black
	suit = /obj/item/clothing/suit/jacket/leather
	shoes = /obj/item/clothing/shoes/jackboots
	head = /obj/item/clothing/head/soft/grey

/// A normal criminal in green space
/datum/outfit/bounty_criminal/local
	name = "Bounty criminal: local"
	uniform = /obj/item/clothing/under/costume/buttondown/slacks
	suit = /obj/item/clothing/suit/jacket/letterman
	shoes = /obj/item/clothing/shoes/sneakers/black

/// A normal criminal in yellow space. Overalls, not bare jeans: a Wanted criminal's vest goes over a shirt.
/datum/outfit/bounty_criminal/hauler
	name = "Bounty criminal: hauler"
	uniform = /obj/item/clothing/under/misc/overalls
	suit = /obj/item/clothing/suit/jacket/miljacket
	gloves = /obj/item/clothing/gloves/fingerless
	shoes = /obj/item/clothing/shoes/workboots

/// A normal criminal in red space, and the fallback for a mini-boss
/datum/outfit/bounty_criminal/tough
	name = "Bounty criminal: tough"
	uniform = /obj/item/clothing/under/color/black
	suit = /obj/item/clothing/suit/jacket/leather/biker
	gloves = /obj/item/clothing/gloves/fingerless
	shoes = /obj/item/clothing/shoes/jackboots
