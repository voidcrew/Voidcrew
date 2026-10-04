/**
 * Shared helpers for the outpost marketplace tests. Frozen after P0: packages add their own
 * helpers to their own test files.
 *
 * Voidcrew defines are not visible from test files, so prices, ids and sizes appear as literals.
 */

/// A loaded small-shell claim owned by `owner_key`, with its treasury and freight set up
/datum/unit_test/voidcrew_outpost_management/proc/market_test_claim(owner_key)
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim(owner_key)
	home?.ensure_home_services()
	return home

/**
 * A human at `location` with a mind, an ID in its ID slot and a personal account holding `balance`.
 * Its offline `player_key` (optional) is cleared by the management harness's Destroy().
 */
/datum/unit_test/voidcrew_outpost_management/proc/make_market_visitor(turf/location, player_key, balance = 0)
	var/mob/living/carbon/human/consistent/visitor = allocate(/mob/living/carbon/human/consistent, location)
	if(player_key)
		visitor.key = player_key
	visitor.mind_initialize()
	ADD_TRAIT(visitor, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, REF(src))
	var/datum/bank_account/account = allocate(/datum/bank_account, visitor.real_name, null, 1, FALSE)
	account.account_balance = balance
	// The ID slot needs a jumpsuit; without one the card is deleted instead of worn
	visitor.equip_to_slot_or_del(allocate(/obj/item/clothing/under/color/grey), ITEM_SLOT_ICLOTHING)
	var/obj/item/card/id/card = allocate(/obj/item/card/id)
	card.registered_account = account
	card.registered_name = visitor.real_name
	visitor.equip_to_slot_or_del(card, ITEM_SLOT_ID)
	if(visitor.wear_id != card)
		TEST_FAIL("[player_key || visitor] could not wear the market test ID")
	return visitor

/**
 * The bottom-left for `blueprint`'s room beside the claim's shell at `rotation`: north, east,
 * south or west of it, 4 tiles out, like the cargo dock tests. Null when the template is missing.
 */
/datum/unit_test/proc/service_room_test_corner(obj/structure/overmap/dynamic/player_outpost/home, datum/outpost_upgrade/blueprint, rotation)
	var/turf/shell_corner = home.template_bottom_left
	var/datum/map_template/template = blueprint?.get_template()
	if(!shell_corner || !home.shell_template || !template)
		return null
	var/left = shell_corner.x
	var/bottom = shell_corner.y
	var/right = left + home.shell_template.width - 1
	var/top = bottom + home.shell_template.height - 1
	var/turned = (rotation % 180) != 0
	var/footprint_width = turned ? template.height : template.width
	var/footprint_height = turned ? template.width : template.height
	switch(rotation)
		if(0)
			return locate(left, top + 4, shell_corner.z)
		if(90)
			return locate(right + 4, bottom, shell_corner.z)
		if(180)
			return locate(left, bottom - 4 - footprint_height, shell_corner.z)
		if(270)
			return locate(left - 4 - footprint_width, bottom, shell_corner.z)
	return null

/**
 * Stamps a service room beside the claim's shell without going through the console, trying each
 * rotation's side in turn. `upgrade` is an upgrade type, or a blueprint instance (a test subtype
 * whose id is set at runtime). Returns the placed blueprint, or the last placement error with the
 * first tile that refused and what stood on it.
 */
/datum/unit_test/proc/place_test_service_room(obj/structure/overmap/dynamic/player_outpost/home, upgrade, list/rotations = list(0, 90, 180, 270), mob/user)
	var/datum/outpost_upgrade/blueprint
	if(istype(upgrade, /datum/outpost_upgrade))
		blueprint = upgrade
	else if(ispath(upgrade, /datum/outpost_upgrade))
		var/datum/outpost_upgrade/upgrade_type = upgrade
		var/upgrade_id = initial(upgrade_type.id)
		blueprint = upgrade_id ? home.outpost_upgrades[upgrade_id] : null
		if(!blueprint)
			blueprint = new upgrade_type(home)
	if(!blueprint)
		return "Not an outpost upgrade: [upgrade]."
	if(!blueprint.id)
		return "The [blueprint.name] blueprint has no id."
	blueprint.outpost = home
	blueprint.key = blueprint.id
	home.outpost_upgrades[blueprint.id] = blueprint
	var/error = "No side of the shell to try."
	for(var/rotation in rotations)
		var/turf/corner = service_room_test_corner(home, blueprint, rotation)
		if(!corner)
			continue
		error = home.place_outpost_upgrade(blueprint, corner, rotation, user)
		if(!error)
			return blueprint
		error = "[error] [cargo_dock_blocker(home, blueprint, corner, rotation)]"
	return error

/// Fresh rooms trade air for a while. Let it settle before the claim is torn down under SSair.
/datum/unit_test/proc/settle_room_air(list/room_turfs)
	settle_cargo_dock_air(room_turfs)
