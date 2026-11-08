/**
 * # Human NPC outfits by zone, rank and site (N7)
 *
 * Toughness for human NPCs comes from what they wear (defaults 1.5), so harder zones get better kit,
 * not more health: rags in green, a vest in yellow, a vest and helmet in red, better guns as you go.
 *
 * An outfit table (/datum/human_npc_outfit_table) picks a /datum/outfit for one NPC from weighted lists
 * per zone and rank. Use one by setting npc_outfit_table on the NPC type, or by passing the table
 * typepath as spawn_human_npc(outfit =). The zone is the spawn context's (spawn_npc_in_zone()), else
 * the zone of the spawn turf (a ship's overmap tile when aboard one), else green. A queued order whose
 * zone isn't known yet waits for it in the queue, up to HUMAN_NPC_ZONE_WAIT (human_npc_spawning.dm).
 *
 * Whatever the outfit, the site layers then make sure the NPC can live where it is made (decision D5
 * and defaults 1.12: real suits and tanks, never immunity traits). human_npc_site_at() reads the air on
 * the spawn turf:
 * - HUMAN_NPC_SITE_VACUUM (too little pressure): if the outfit's suit and helmet aren't both sealed,
 *   the table's vacuum_layer replaces them with a sealed suit and helmet; it also gets a tank.
 * - HUMAN_NPC_SITE_BAD_AIR (pressure fine, air not): a breath mask if nothing it wears takes internals,
 *   and a tank.
 * - HUMAN_NPC_SITE_COLD: the table's cold_layer fills the slots the outfit leaves empty with cold-weather
 *   wear and swaps the shoes for winter boots. An outfit meant for ice planets should bring its own.
 * A table's always_site, and the NPC's npc_always_site, add sites regardless of the air (boarders that
 * cross vacuum). Species that need none of it (skeletons) are left alone. The NPC then opens its tank
 * and switches on its suit's thermal regulator, as a player would.
 */

/**
 * Weighted outfits for one family. Lists are outfit typepath => weight. A zone left null uses the zone
 * below it; elites and bosses fall back to the zone's regulars. Override outfits_for() to pick by
 * anything else the NPC carries (a bounty's tier, a faction's role).
 */
/datum/human_npc_outfit_table
	/// Regulars in the green zone
	var/list/green
	/// Regulars in the yellow zone. Null: green's.
	var/list/yellow
	/// Regulars in the red zone. Null: yellow's.
	var/list/red
	/// Elites in any zone. Null: the zone's regulars.
	var/list/elite
	/// Bosses in any zone. Null: elite's.
	var/list/boss
	/// HUMAN_NPC_SITE_* flags every NPC it dresses gets, whatever the air where it spawns
	var/always_site = NONE
	/// What goes over an outfit that isn't sealed, in vacuum (a /datum/human_npc_layer typepath)
	var/datum/human_npc_layer/vacuum_layer = /datum/human_npc_layer/eva
	/// What goes over an outfit in the cold
	var/datum/human_npc_layer/cold_layer = /datum/human_npc_layer/cold

/// The weighted outfits `npc` may get in `zone` (ZONE_*).
/datum/human_npc_outfit_table/proc/outfits_for(mob/living/carbon/human/npc/npc, zone)
	var/rank = npc?.npc_rank || HUMAN_NPC_RANK_REGULAR
	if(rank >= HUMAN_NPC_RANK_BOSS && length(boss))
		return boss
	if(rank >= HUMAN_NPC_RANK_ELITE && length(elite))
		return elite
	if(zone == ZONE_RED && length(red))
		return red
	if(zone >= ZONE_YELLOW && length(yellow))
		return yellow
	return green

/// One outfit typepath for `npc` in `zone`, or null if the table has nothing for it.
/datum/human_npc_outfit_table/proc/pick_outfit(mob/living/carbon/human/npc/npc, zone)
	var/list/choices = outfits_for(npc, zone)
	if(!length(choices))
		return null
	return pick_weight(choices)

/**
 * What `spot` asks of a person standing there: HUMAN_NPC_SITE_* flags read from its air. Space and
 * anything under tg's hazard pressure is vacuum; too little oxygen or a lungful of plasma or carbon
 * dioxide is bad air; air below HUMAN_NPC_SITE_COLD_TEMP is cold.
 */
/proc/human_npc_site_at(turf/spot)
	if(isnull(spot))
		return NONE
	var/datum/gas_mixture/air = spot.return_air()
	if(isnull(air))
		return HUMAN_NPC_SITE_VACUUM | HUMAN_NPC_SITE_COLD
	. = NONE
	var/pressure = air.return_pressure()
	if(pressure < HAZARD_LOW_PRESSURE)
		. |= HUMAN_NPC_SITE_VACUUM
	else
		var/oxygen = human_npc_partial_pressure(air, /datum/gas/oxygen, pressure)
		var/plasma = human_npc_partial_pressure(air, /datum/gas/plasma, pressure)
		var/carbon_dioxide = human_npc_partial_pressure(air, /datum/gas/carbon_dioxide, pressure)
		if(oxygen < HUMAN_NPC_SITE_MIN_OXYGEN || plasma > 0.5 || carbon_dioxide > 10)
			. |= HUMAN_NPC_SITE_BAD_AIR
	if(air.temperature < HUMAN_NPC_SITE_COLD_TEMP)
		. |= HUMAN_NPC_SITE_COLD

/// The partial pressure of `gas_type` in `air`, in kPa, given the mix's total `pressure`.
/proc/human_npc_partial_pressure(datum/gas_mixture/air, gas_type, pressure)
	var/list/entry = air.gases[gas_type]
	var/total = air.total_moles()
	if(!entry || !total)
		return 0
	return pressure * entry[MOLES] / total

/**
 * Its outfit, with whatever the site needs layered on (see the top of this file). Returns `outfit`
 * unchanged when nothing is needed, else an outfit instance (an instance passed in is changed in place).
 */
/mob/living/carbon/human/npc/proc/npc_fit_outfit_to_site(outfit, datum/human_npc_outfit_table/table)
	npc_site = human_npc_site_at(get_turf(src)) | npc_always_site | table?.always_site
	var/needs_seal = (npc_site & HUMAN_NPC_SITE_VACUUM) && !HAS_TRAIT(src, TRAIT_RESISTLOWPRESSURE)
	var/needs_air = (npc_site & (HUMAN_NPC_SITE_VACUUM | HUMAN_NPC_SITE_BAD_AIR)) && !HAS_TRAIT(src, TRAIT_NOBREATH)
	var/needs_warmth = (npc_site & HUMAN_NPC_SITE_COLD) && !HAS_TRAIT(src, TRAIT_RESISTCOLD)
	if(!needs_seal && !needs_air && !needs_warmth)
		return outfit
	var/datum/outfit/dressed = ispath(outfit) ? new outfit() : outfit
	if(!istype(dressed))
		return outfit
	if(needs_seal && !human_npc_outfit_sealed(dressed))
		var/datum/human_npc_layer/seal = human_npc_singleton(table?.vacuum_layer || /datum/human_npc_layer/eva)
		seal.apply(dressed)
	if(needs_air && !human_npc_outfit_has_air(dressed))
		if(!human_npc_outfit_can_breathe(dressed))
			dressed.mask = /obj/item/clothing/mask/breath
		human_npc_outfit_add_tank(dressed)
	// A sealed suit with its heating on keeps out the cold of space; warm clothes go on where it isn't sealed.
	if(needs_warmth && !(needs_seal && human_npc_outfit_sealed(dressed)))
		var/datum/human_npc_layer/warmth = human_npc_singleton(table?.cold_layer || /datum/human_npc_layer/cold)
		warmth.apply(dressed)
	return dressed

/// Whether the outfit's suit and helmet both hold pressure.
/proc/human_npc_outfit_sealed(datum/outfit/outfit)
	var/obj/item/clothing/suit = outfit.suit
	var/obj/item/clothing/head = outfit.head
	if(!ispath(suit, /obj/item/clothing) || !ispath(head, /obj/item/clothing))
		return FALSE
	return (initial(suit.clothing_flags) & STOPSPRESSUREDAMAGE) && (initial(head.clothing_flags) & STOPSPRESSUREDAMAGE)

/// Whether it wears something it can breathe a tank through: a mask or a helmet that takes internals.
/proc/human_npc_outfit_can_breathe(datum/outfit/outfit)
	var/obj/item/clothing/mask = outfit.mask
	var/obj/item/clothing/head = outfit.head
	if(ispath(mask, /obj/item/clothing) && (initial(mask.clothing_flags) & MASKINTERNALS))
		return TRUE
	return ispath(head, /obj/item/clothing) && (initial(head.clothing_flags) & HEADINTERNALS)

/// Whether it carries a tank where it can open it and can breathe through something.
/proc/human_npc_outfit_has_air(datum/outfit/outfit)
	if(!human_npc_outfit_can_breathe(outfit))
		return FALSE
	for(var/carried in list(outfit.suit_store, outfit.back, outfit.belt, outfit.l_pocket, outfit.r_pocket))
		if(ispath(carried, /obj/item/tank/internals))
			return TRUE
	return FALSE

/// Gives the outfit an air tank and opens it: in a space suit's storage, else a pocket, else the back
/// or the belt. Returns TRUE if it found a place.
/proc/human_npc_outfit_add_tank(datum/outfit/outfit)
	if(isnull(outfit.suit_store) && ispath(outfit.suit, /obj/item/clothing/suit/space))
		outfit.suit_store = /obj/item/tank/internals/oxygen
		outfit.internals_slot = ITEM_SLOT_SUITSTORE
		return TRUE
	if(isnull(outfit.l_pocket))
		outfit.l_pocket = /obj/item/tank/internals/emergency_oxygen/double
		outfit.internals_slot = ITEM_SLOT_LPOCKET
		return TRUE
	if(isnull(outfit.r_pocket))
		outfit.r_pocket = /obj/item/tank/internals/emergency_oxygen/double
		outfit.internals_slot = ITEM_SLOT_RPOCKET
		return TRUE
	if(isnull(outfit.back))
		outfit.back = /obj/item/tank/internals/oxygen
		outfit.internals_slot = ITEM_SLOT_BACK
		return TRUE
	if(isnull(outfit.belt))
		outfit.belt = /obj/item/tank/internals/emergency_oxygen/double
		outfit.internals_slot = ITEM_SLOT_BELT
		return TRUE
	stack_trace("[outfit.type] has nowhere to carry an air tank")
	return FALSE

/**
 * Clothing layered over an outfit for a site. Slots it sets are filled where the outfit leaves them
 * empty, or always for the slots in `replace_slots` (ITEM_SLOT_* flags). Anything in suit storage that
 * a replaced suit can't hold moves to the backpack, if there is one.
 */
/datum/human_npc_layer
	var/suit
	var/head
	var/mask
	var/gloves
	var/shoes
	var/neck
	/// ITEM_SLOT_* flags of slots it takes over even when the outfit fills them
	var/replace_slots = NONE

/datum/human_npc_layer/proc/apply(datum/outfit/outfit)
	if(suit && (isnull(outfit.suit) || (replace_slots & ITEM_SLOT_OCLOTHING)))
		if(outfit.suit_store && outfit.suit != suit)
			if(outfit.back)
				LAZYADDASSOC(outfit.backpack_contents, outfit.suit_store, 1)
			outfit.suit_store = null
		outfit.suit = suit
	if(head && (isnull(outfit.head) || (replace_slots & ITEM_SLOT_HEAD)))
		outfit.head = head
	if(mask && (isnull(outfit.mask) || (replace_slots & ITEM_SLOT_MASK)))
		outfit.mask = mask
	if(gloves && (isnull(outfit.gloves) || (replace_slots & ITEM_SLOT_GLOVES)))
		outfit.gloves = gloves
	if(shoes && (isnull(outfit.shoes) || (replace_slots & ITEM_SLOT_FEET)))
		outfit.shoes = shoes
	if(neck && (isnull(outfit.neck) || (replace_slots & ITEM_SLOT_NECK)))
		outfit.neck = neck

/// A plain sealed EVA suit and helmet, the fallback for any family in vacuum.
/datum/human_npc_layer/eva
	suit = /obj/item/clothing/suit/space/eva
	head = /obj/item/clothing/head/helmet/space/eva
	replace_slots = ITEM_SLOT_OCLOTHING | ITEM_SLOT_HEAD

/// Pirates' own space suit: lighter, armoured, and it holds a gun.
/datum/human_npc_layer/eva/pirate
	suit = /obj/item/clothing/suit/space/pirate
	head = /obj/item/clothing/head/helmet/space/pirate

/// Cold-weather wear for whatever an outfit leaves bare.
/datum/human_npc_layer/cold
	suit = /obj/item/clothing/suit/hooded/wintercoat
	head = /obj/item/clothing/head/costume/ushanka
	gloves = /obj/item/clothing/gloves/color/black
	shoes = /obj/item/clothing/shoes/winterboots
	neck = /obj/item/clothing/neck/scarf
	replace_slots = ITEM_SLOT_FEET
