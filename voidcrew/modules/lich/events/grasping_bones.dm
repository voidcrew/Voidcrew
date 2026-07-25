/**
 * Ritual: Grasping Bones — ship-scoped port of TG's Make Everything Embeddable
 * (code/modules/events/wizard/embeddies.dm).
 *
 * Everything the crew owns sprouts barbs and sticks in them when thrown.
 *
 * The TG original installs a GLOB.global_funny_embedding controller datum that (a) walks
 * every /obj/item in the world and (b) registers COMSIG_GLOB_NEW_ITEM so items created for
 * the rest of the round are blessed too. Both halves are unscopable: this fork's ships
 * share z-levels with each other, with ruins and with trader outposts, so a world-wide
 * sweep would barb the stock of every NPC vendor in the galaxy and the signal hook would
 * keep doing it forever.
 *
 * Changed from the original:
 * - No global controller datum and no GLOB assignment. The effect is applied directly to
 *   the items presently aboard the target ship, resolved through shuttle areas.
 * - No COMSIG_GLOB_NEW_ITEM hook. Items made after the ritual are clean. This is the
 *   natural scope limit that falls out of dropping the global controller, and it is also
 *   the crew's out: fabricate replacements, or just stop throwing your own toolbox.
 * - The "sticky" sibling control is not ported. It is a joke variant with no bearing on
 *   the ramp and the contract's table lists one embed event.
 * - Reuses upstream's /datum/embedding/global_funny (ignore_throwspeed_threshold = TRUE)
 *   rather than declaring a parallel one, so the embed math stays identical to TG's.
 */
/datum/round_event_control/voidcrew/lich/grasping_bones
	name = "Ritual: Grasping Bones"
	typepath = /datum/round_event/voidcrew/lich/grasping_bones
	description = "Every loose object aboard the target ship grows barbs and embeds when thrown."
	max_occurrences = 2
	event_scope = EVENT_SCOPE_SHIP
	min_wizard_trigger_potency = 0
	max_wizard_trigger_potency = 3

/datum/round_event/voidcrew/lich/grasping_bones
	announce_when = 1
	/// Name prefix stamped onto every affected item, as TG prefixes its items "pointy".
	var/barb_prefix = "barbed"
	/// How many items the sweep will touch before it gives up. A ship is small; a runaway loop is not.
	var/max_items = 600

/datum/round_event/voidcrew/lich/grasping_bones/start()
	if(!target_valid())
		return
	var/touched = 0
	for(var/area/ship_area as anything in target_ship.shuttle.shuttle_areas)
		// get_all_contents() walks turfs, then the things on them, then what is inside
		// those — bags, lockers and pockets included, matching the reach of TG's
		// world-wide sweep without leaving the hull.
		for(var/obj/item/victim_item in ship_area.get_all_contents())
			CHECK_TICK
			if(touched >= max_items)
				return
			if(QDELETED(victim_item) || !(victim_item.flags_1 & INITIALIZED_1))
				continue
			if(victim_item.get_embed())
				continue // Already embeds on its own merits; leave the knives alone.
			victim_item.set_embed(/datum/embedding/global_funny)
			victim_item.name = "[barb_prefix] [victim_item.name]"
			touched++

/datum/round_event/voidcrew/lich/grasping_bones/announce(fake)
	lich_announce_ship(
		"Everything you have ever picked up remembers being held. I have reminded it. \
		Your tools want to be inside you now, and I have granted them the shape to manage it. \
		Throw nothing. Drop nothing. Try to be still.",
		"Grasping Bones",
		'sound/effects/magic/summon_magic.ogg',
	)
