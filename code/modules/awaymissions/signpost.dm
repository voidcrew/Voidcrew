/*An alternative to exit gateways, signposts send you back to somewhere safe onstation with their semiotic magic.*/
/obj/structure/signpost
	icon = 'icons/obj/fluff/general.dmi'
	icon_state = "signpost"
	anchored = TRUE
	density = TRUE
	var/question = "Travel back?"
	var/list/zlevels

/obj/structure/signpost/Initialize(mapload)
	. = ..()
	set_light(2)

/obj/structure/signpost/interact(mob/user)
	. = ..()
	if(.)
		return
	if(tgui_alert(usr,question,name,list("Yes","No")) == "Yes" && Adjacent(user))
		var/turf/T = get_destination_turf(user)

		if(T)
			var/atom/movable/AM = user.pulling
			if(AM)
				AM.forceMove(T)
			user.forceMove(T)
			if(AM)
				user.start_pulling(AM)
			to_chat(user, span_notice("You blink and find yourself in [get_area_name(T)]."))
		else
			to_chat(user, "Nothing happens. You feel that this is a bad sign.")

/**
 * Where this signpost drops [user]. Voidcrew: aboard the ship they crew, and nowhere else.
 *
 * Upstream rolled a random safe turf on any ZTRAIT_STATION z-level, which on /tg/ means the
 * station. This fork stamps that trait onto every z-level that currently holds a ship -
 * link_to_z_level(), voidcrew/mapping/docking_port/_docking_port.dm - NPC hulls included, and
 * a ship interior is the only pressurised thing on such a level, so the old roll reliably
 * deposited whoever used it inside a random ship. Pirates counted. Resolve the user's own hull
 * through the same mind-to-ship mapping the shop and the outposts use; crewing nothing means
 * there is nowhere to go back to.
 */
/obj/structure/signpost/proc/get_destination_turf(mob/user)
	var/obj/structure/overmap/ship/home = get_crew_ship(user)
	if(!home?.shuttle?.shuttle_areas)
		return null

	var/list/habitable = list()
	var/list/breached = list() //A hull venting to space is still a better landing than none at all.
	for(var/area/ship_area in home.shuttle.shuttle_areas)
		for(var/turf/deck in ship_area)
			if(!isopenturf(deck) || deck.density || isspaceturf(deck))
				continue
			if(is_safe_turf(deck))
				habitable += deck
			else
				breached += deck

	if(length(habitable))
		return pick(habitable)
	return length(breached) ? pick(breached) : null

/obj/structure/signpost/attackby(obj/item/W, mob/user, list/modifiers, list/attack_modifiers)
	return interact(user)

/obj/structure/signpost/attack_paw(mob/user, list/modifiers)
	return interact(user)

/obj/structure/signpost/attack_hulk(mob/user)
	return

/obj/structure/signpost/attack_larva(mob/user, list/modifiers)
	return interact(user)

/obj/structure/signpost/attack_robot(mob/user)
	if (Adjacent(user))
		return interact(user)

/obj/structure/signpost/attack_animal(mob/user, list/modifiers)
	return interact(user)

/obj/structure/signpost/salvation
	name = "\proper salvation"
	desc = "In the darkest times, we will find our way home."
	resistance_flags = INDESTRUCTIBLE

/obj/structure/signpost/exit
	name = "exit"
	desc = "Make sure to bring all your belongings with you when you \
		exit the area."
	question = "Leave? You might never come back."

/obj/structure/signpost/exit/Initialize(mapload)
	. = ..()
	zlevels = list()
	for(var/i in 1 to world.maxz)
		zlevels += i
	zlevels -= SSmapping.levels_by_trait(ZTRAIT_CENTCOM) // no easy victory, even with meme signposts
	// also, could you think of the horror if they ended up in a holodeck
	// template or something

/// The meme signpost keeps its anywhere-at-all roll; it is not promising anyone a way home.
/obj/structure/signpost/exit/get_destination_turf(mob/user)
	return find_safe_turf(zlevels = zlevels)
