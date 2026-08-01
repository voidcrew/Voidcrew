/**
 * Ritual: Grave Goods — ship-scoped port of TG's Cursed Items
 * (code/modules/events/wizard/curseditems.dm).
 *
 * The crew are dressed for their own funerals. The clothes will not come off.
 *
 * TG picks one of six item sets, then walks GLOB.alive_mob_list equipping every human in the
 * world, forcing the item into a slot with TRAIT_NODROP and DROPDEL so it can never be
 * removed for the rest of the round. Its only guard against killing people is
 * `ruins_spaceworthiness && !is_station_level(target.z)` — a station-shaped check that in
 * this fork passes for anyone standing on a ship's z-level, i.e. everyone the event would hit.
 *
 * Changed from the original:
 * - Victims are the target ship's crew only, resolved through shuttle areas.
 * - The spaceworthiness guard is rebuilt properly. Instead of "are you on the station",
 *   each victim is checked for whether the item about to displace their head or suit slot
 *   would strip a pressure-sealed garment (STOPSPRESSUREDAMAGE). If so that victim is
 *   skipped entirely. On a station "off-station" was a decent proxy for "in a hardsuit"; on
 *   a ship in deep space where any compartment can vent, the actual clothing check is the
 *   only safe version. TG's plasmaman guard (`dna.species.outfit_important_for_life`) is kept
 *   verbatim — those crew die without their own kit.
 * - The curse EXPIRES. TG's items are permanent for the round; these unstick after four
 *   minutes, which is the port spec's "nothing unrecoverable" rule. The items remain, named
 *   and grim, but wearable and removable.
 * - The items do NOT outlive Ilthuun. Every piece is registered with
 *   register_lich_leaving() (lich_loot.dm) and crumbles to dust when he dies. Without that
 *   this rite is a free set of bone armour and a skull helmet for every crew in the galaxy,
 *   six times over — a supply drop wearing a curse's clothes. If he dies while a curse is
 *   still stuck on somebody, deleting the item is also what unsticks them.
 * - Item sets rewritten as grave goods. TG's six are a lit joint, boxing gloves, kitty ears
 *   with a forced gender change, a cursed katana, a chameleon mask, and a fake wizard outfit.
 *   Three of those are pure meme, one edits a player's gender, and one is literally a wizard
 *   costume. The replacements are bone regalia, a dead man's face, and TG's cursed katana —
 *   which is genuinely a cursed grave good and stays.
 * - The event no longer touches `target.gender`.
 */

/// Bone armor and a skull helmet. Displaces head and suit, so the pressure check applies.
#define GRAVE_GOODS_BONE_REGALIA "bone_regalia"
/// A chameleon mask: the face of someone who is not you. Displaces the mask slot only.
#define GRAVE_GOODS_DEAD_FACE "dead_face"
/// TG's cursed katana, put in the hands. Nothing is displaced from a sealed slot.
#define GRAVE_GOODS_CURSED_BLADE "cursed_blade"
/// Bone bracers and a bone talisman. Gloves and neck; harmless to a hardsuit.
#define GRAVE_GOODS_BURIAL_TRINKETS "burial_trinkets"

/datum/round_event_control/voidcrew/lich/grave_goods
	name = "Ritual: Grave Goods"
	typepath = /datum/round_event/voidcrew/lich/grave_goods
	description = "Dresses everyone aboard the target ship in grave goods that will not come off."
	/**
	 * Repeatable, because the curse now expires on its own after about four minutes — each
	 * firing cleans up after itself, so a second one is a fresh inconvenience rather than
	 * an accumulating one. See the cap policy note in lich_events.dm.
	 */
	max_occurrences = 6
	event_scope = EVENT_SCOPE_SHIP
	min_wizard_trigger_potency = 3
	/**
	 * Extended to the top of the ramp: dressing a crew for their own funerals is a
	 * maximum-potency statement, and the top band needs repeatable SHIP-scoped variety so
	 * it never has to fall back on re-firing a one-shot. Each firing tracks its own items,
	 * so overlapping instances release exactly what they created.
	 */
	max_wizard_trigger_potency = 7

/datum/round_event/voidcrew/lich/grave_goods
	announce_when = 1
	/// Four minutes of ticks. The curse releases in end().
	end_when = 120
	/// Which set was rolled.
	var/item_set
	/// Items this ritual created, so end() can release exactly them and nothing else.
	///
	/// Hard refs, and end() nulls the list — which is what keeps them from outliving a
	/// crumble. If Ilthuun dies mid-curse the items are qdel'd under us and this list holds
	/// dangling refs until end() runs, at most `end_when` later. That is fine only while
	/// `end_when` stays under GC_CHECK_QUEUE (5 minutes, code/__DEFINES/qdel.dm:43);
	/// lengthen the curse past that and every crumbled item starts logging a hard delete.
	var/list/obj/item/cursed_items = list()
	/// TRUE if the rolled set would displace a pressure-sealed garment on someone in vacuum.
	var/ruins_spaceworthiness = FALSE

/datum/round_event/voidcrew/lich/grave_goods/setup()
	item_set = pick(
		GRAVE_GOODS_BONE_REGALIA,
		GRAVE_GOODS_BURIAL_TRINKETS,
		GRAVE_GOODS_CURSED_BLADE,
		GRAVE_GOODS_DEAD_FACE,
	)

/datum/round_event/voidcrew/lich/grave_goods/announce(fake)
	lich_announce_ship(
		"It is customary to be buried in something. Your uniforms are insulting to the \
		occasion, so I have made other arrangements. Wear them a while. \
		You will not be taking them off by hand.",
		"Grave Goods",
		'sound/effects/magic/curse.ogg',
	)

/datum/round_event/voidcrew/lich/grave_goods/start()
	if(!target_valid())
		return

	var/list/loadout = list()
	switch(item_set)
		if(GRAVE_GOODS_BONE_REGALIA)
			loadout += /obj/item/clothing/head/helmet/skull
			loadout += /obj/item/clothing/suit/armor/bone
			ruins_spaceworthiness = TRUE
		if(GRAVE_GOODS_BURIAL_TRINKETS)
			loadout += /obj/item/clothing/gloves/bracer
		if(GRAVE_GOODS_CURSED_BLADE)
			loadout += /obj/item/katana/cursed
		if(GRAVE_GOODS_DEAD_FACE)
			loadout += /obj/item/clothing/mask/chameleon

	if(!length(loadout))
		return

	var/list/mob/living/carbon/human/victims = list()
	for(var/mob/living/aboard_mob as anything in target_ship.get_event_crew())
		if(!ishuman(aboard_mob) || QDELETED(aboard_mob))
			continue
		var/mob/living/carbon/human/victim = aboard_mob
		if(isspaceturf(victim.loc))
			continue // Same as the original: do not undress somebody who is already outside.
		if(!isnull(victim.dna?.species?.outfit_important_for_life))
			continue // Plasmamen and friends die out of their own kit.
		if(ruins_spaceworthiness && is_pressure_sealed(victim, loadout))
			continue // Would strip a sealed suit or helmet on a ship that can vent. Skip them.
		if(!curse_victim(victim, loadout))
			continue
		victims += victim

	for(var/mob/living/carbon/human/victim as anything in victims)
		if(QDELETED(victim))
			continue
		do_smoke(0, holder = victim, location = get_turf(victim))

/**
 * TRUE if any slot this loadout wants to occupy currently holds a pressure-sealed garment.
 *
 * This is the honest replacement for TG's `!is_station_level(target.z)` proxy. On a ship,
 * "is this person relying on the thing I am about to rip off them" is the question that
 * actually matters, and it is answerable directly.
 */
/datum/round_event/voidcrew/lich/grave_goods/proc/is_pressure_sealed(mob/living/carbon/human/victim, list/loadout)
	for(var/item_path in loadout)
		var/obj/item/clothing/incoming = item_path
		if(!ispath(item_path, /obj/item/clothing))
			continue
		var/slot_flags = initial(incoming.slot_flags)
		if(!slot_flags)
			continue
		var/obj/item/clothing/displaced = victim.get_item_by_slot(slot_flags)
		if(!istype(displaced))
			continue
		if(displaced.clothing_flags & STOPSPRESSUREDAMAGE)
			return TRUE
	return FALSE

/// Equips one victim with the whole loadout. Returns TRUE if anything stuck.
/datum/round_event/voidcrew/lich/grave_goods/proc/curse_victim(mob/living/carbon/human/victim, list/loadout)
	var/equipped_any = FALSE
	for(var/item_to_equip in loadout)
		var/obj/item/new_item = new item_to_equip
		var/slot_to_equip_to = ITEM_SLOT_HANDS
		if(isclothing(new_item))
			var/obj/item/clothing/clothing_item = new_item
			slot_to_equip_to = clothing_item.slot_flags

		victim.dropItemToGround(victim.get_item_by_slot(slot_to_equip_to), TRUE)
		if(!victim.equip_to_slot_or_del(new_item, slot_to_equip_to, indirect_action = TRUE))
			continue
		if(QDELETED(new_item))
			continue
		ADD_TRAIT(new_item, TRAIT_NODROP, CURSED_ITEM_TRAIT(new_item))
		new_item.item_flags |= DROPDEL
		new_item.name = "grave-cold [new_item.name]"
		cursed_items += new_item
		// Bone armour and a skull helmet are real armour, and the curse expiring is
		// what would otherwise turn this rite into a free set for every crew in the
		// galaxy. Registered so it goes to dust with him. See lich_loot.dm.
		register_lich_leaving(new_item)
		equipped_any = TRUE
	return equipped_any

/**
 * Releases the curse. Runs regardless of whether the ship survived — the items are tracked
 * directly, so a destroyed target_ship does not leave somebody welded into a skull helmet.
 */
/datum/round_event/voidcrew/lich/grave_goods/end()
	for(var/obj/item/cursed as anything in cursed_items)
		if(QDELETED(cursed))
			continue
		REMOVE_TRAIT(cursed, TRAIT_NODROP, CURSED_ITEM_TRAIT(cursed))
		cursed.item_flags &= ~DROPDEL
		var/mob/living/wearer = cursed.loc
		if(isliving(wearer))
			to_chat(wearer, span_notice("[cursed] loosens its grip. Whatever was holding it there has lost interest."))
	cursed_items = null

#undef GRAVE_GOODS_BONE_REGALIA
#undef GRAVE_GOODS_BURIAL_TRINKETS
#undef GRAVE_GOODS_CURSED_BLADE
#undef GRAVE_GOODS_DEAD_FACE
