/**
 * # Outpost Deed
 *
 * A name-bound land claim sold at trader outposts. Used in-hand while your
 * ship holds still on an empty overmap tile, it opens the shell catalog and
 * founds a player outpost on that tile (see player_outpost.dm).
 *
 * Purchasing charges credits + vouchers every time. Nothing about the deed or
 * the outpost persists across rounds; a player may found a single outpost per
 * round (see GLOB.player_outpost_founder_ckeys).
 */

/obj/item/outpost_deed
	name = "outpost deed"
	desc = "A colonial registry land claim for one sector of open space, notarized in triplicate. Only the buyer can use it."
	icon = 'voidcrew/modules/player_outposts/icons/outpost.dmi'
	icon_state = "outpost_deed"
	w_class = WEIGHT_CLASS_SMALL
	resistance_flags = FIRE_PROOF | ACID_PROOF // losing the physical copy to a house fire would be embarrassing
	/// Ckey the deed is registered to; only they can found with it
	var/owner_ckey
	/// Display name of the buyer, for examine
	var/owner_name
	/// The open catalog UI, if any
	var/datum/outpost_shell_catalog_ui/catalog

/obj/item/outpost_deed/Destroy()
	QDEL_NULL(catalog)
	return ..()

/obj/item/outpost_deed/examine(mob/user)
	. = ..()
	if(owner_name)
		. += span_notice("Registered to [owner_name].")
	if(user.ckey && user.ckey == owner_ckey)
		. += span_notice("Use it in hand while your ship holds still over an empty overmap tile to found your outpost.")
	else
		. += span_warning("It isn't registered to you. The registry won't honor it.")

/obj/item/outpost_deed/attack_self(mob/user)
	. = ..()
	if(.)
		return
	var/denial = get_founding_denial(user)
	if(denial)
		to_chat(user, span_warning(denial))
		return
	if(!catalog)
		catalog = new(user, src)
	catalog.ui_interact(user)

/**
 * Why the holder can't found an outpost right now. Null when everything checks out.
 * Re-run at confirm time; UI state can go stale.
 */
/obj/item/outpost_deed/proc/get_founding_denial(mob/user)
	if(!user.ckey || user.ckey != owner_ckey)
		return "The deed isn't registered to you."
	if(user.ckey in GLOB.player_outpost_founder_ckeys)
		return "The registry already has an active claim under your name this shift."
	if(SSovermap.jump_mode != BS_JUMP_IDLE)
		return "The registry has suspended new claims. Bluespace exodus in progress."
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!ship)
		return "You need to be a crew member of a ship to stake a claim."
	if(ship.state != OVERMAP_SHIP_FLYING || !ship.is_still())
		return "Your ship must hold still in open space to fix the claim's coordinates."
	var/turf/claim_turf = get_turf(ship)
	if(!istype(claim_turf, /turf/open/overmap))
		return "The registry can't resolve your ship's coordinates."
	for(var/obj/structure/overmap/other in claim_turf)
		if(istype(other, /obj/structure/overmap/ship))
			continue
		return "This sector is already occupied by [other.name]."
	return null

/**
 * # Outpost Shell Catalog
 *
 * The founding UI: pick a shell, name the outpost, confirm. Opened by the
 * deed; everything is re-validated on confirm.
 */
/datum/outpost_shell_catalog_ui
	var/mob/user
	var/obj/item/outpost_deed/deed

/datum/outpost_shell_catalog_ui/New(mob/viewing_user, obj/item/outpost_deed/parent_deed)
	. = ..()
	user = viewing_user
	deed = parent_deed

/datum/outpost_shell_catalog_ui/Destroy()
	user = null
	if(deed?.catalog == src)
		deed.catalog = null
	deed = null
	return ..()

/datum/outpost_shell_catalog_ui/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OutpostShellCatalog", "Colonial Registry")
		ui.open()

/datum/outpost_shell_catalog_ui/ui_host()
	return deed

/datum/outpost_shell_catalog_ui/ui_state(mob/user)
	return GLOB.hands_state

/datum/outpost_shell_catalog_ui/ui_static_data(mob/user)
	var/list/data = list()
	var/list/shells = list()
	for(var/shell_type in subtypesof(/datum/map_template/player_outpost))
		var/datum/map_template/player_outpost/shell = shell_type
		shells += list(list(
			"id" = "[shell_type]",
			"name" = initial(shell.name),
			"description" = initial(shell.catalog_desc),
		))
	data["shells"] = shells
	data["max_name_length"] = MAX_CHARTER_LEN
	return data

/datum/outpost_shell_catalog_ui/ui_data(mob/user)
	var/list/data = list()
	var/denial = deed?.get_founding_denial(user)
	data["denial"] = denial
	data["zone_name"] = null
	data["protected"] = FALSE
	if(!denial)
		var/obj/structure/overmap/ship/ship = get_crew_ship(user)
		var/zone = SSovermap.get_zone_band_for_turf(get_turf(ship))
		switch(zone)
			if(ZONE_GREEN)
				data["zone_name"] = "GREEN"
			if(ZONE_YELLOW)
				data["zone_name"] = "YELLOW"
			if(ZONE_RED)
				data["zone_name"] = "RED"
		data["protected"] = (zone == ZONE_GREEN)
	return data

/datum/outpost_shell_catalog_ui/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(action != "found")
		return

	. = TRUE

	// Everything can have changed while the catalog was open, re-validate all of it
	var/denial = deed?.get_founding_denial(usr)
	if(denial)
		to_chat(usr, span_warning(denial))
		return

	var/datum/map_template/player_outpost/shell_type = text2path(params["shell_id"])
	if(!ispath(shell_type, /datum/map_template/player_outpost))
		return
	var/datum/map_template/player_outpost/shell = new shell_type

	var/outpost_name = trim(params["name"])
	if(!length(outpost_name))
		to_chat(usr, span_warning("Your outpost needs a name."))
		return
	if(!reject_bad_text(outpost_name, MAX_CHARTER_LEN))
		to_chat(usr, span_warning("The registry rejected that name."))
		return

	var/obj/structure/overmap/ship/ship = get_crew_ship(usr)
	var/obj/structure/overmap/dynamic/player_outpost/outpost = new(get_turf(ship))
	if(!outpost.found(usr, shell, outpost_name))
		to_chat(usr, span_warning("Registration failed - the site couldn't be prepared. Your deed is still good."))
		return

	ui.close()
	to_chat(usr, span_boldnotice("Claim registered. [outpost_name] is yours. Fly over and dock to move in."))
	qdel(deed) // also tears this UI down via Destroy

/**
 * # Outpost Deed SKU
 *
 * Sold over the counter at trader outposts. Charges the full price on every
 * purchase, the deed carries no cross-round persistence. A player who has
 * already founded an outpost this round can't buy another. Deeds dispense
 * name-bound to the buyer.
 */
/datum/shop_sku/outpost_deed
	name = "outpost deed"
	desc = "A colonial registry claim for one sector of open space. Found your own outpost. One active claim per person per shift."
	item_path = /obj/item/outpost_deed
	category = "Colonial Registry"
	price_credits = OUTPOST_DEED_COST_CREDITS
	price_vouchers = OUTPOST_DEED_COST_VOUCHERS
	stock_min = 1
	stock_max = 1

/datum/shop_sku/outpost_deed/get_denial_reason(mob/living/user)
	if(!user.ckey)
		return "The registry can't establish your identity."
	if(user.ckey in GLOB.player_outpost_founder_ckeys)
		return "The registry already has an active claim under your name this shift."
	return ..()

/datum/shop_sku/outpost_deed/try_purchase(mob/living/user, mob/living/basic/outpost_trader/vendor)
	if(!user.ckey || (user.ckey in GLOB.player_outpost_founder_ckeys))
		return FALSE
	return ..()

/datum/shop_sku/outpost_deed/dispense(mob/living/user, mob/living/basic/outpost_trader/vendor)
	var/atom/drop_loc = user.drop_location() || vendor?.drop_location()
	var/obj/item/outpost_deed/deed = new(drop_loc)
	deed.owner_ckey = user.ckey
	deed.owner_name = user.real_name
	deed.name = "outpost deed ([user.real_name])"
	if(user.put_in_hands(deed))
		to_chat(user, span_notice("You receive [deed]."))
	else
		to_chat(user, span_notice("[deed] is set down at your feet."))
