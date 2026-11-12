/**
 * # Outpost floors: who may build
 *
 * Owner: P13 (spec 3b.1, L29, L37). outpost_service_build_allowed() (stack recipes, the RCD, pipes, disposals, cable)
 * and the RCD's deconstruct mode ask the proc below. P13 also keeps tg's restaurant portal shut on a floor (A86).
 *
 * Three rules live here:
 * - Only a floor's own people and the builders its owner named build, bolt down, lay cable or use an RCD on it,
 *   whatever its setting (L29, A77). Nobody at all does on the hull, the landing or the goods lift (A5).
 * - Bolting something down with a wrench is building. The P0 seams cover stack recipes, the RCD, pipes, disposals
 *   and cable; /obj/can_be_unfasten_wrench() below covers everything that anchors through
 *   default_unfasten_wrench() (machines, vendors, frames). Unbolting is left alone: tools are not building (A79).
 * - tg's restaurant venues never run on a floor (L37, A86).
 *
 * What is not covered, because tg anchors it with its own inline tool code and nothing asks a common proc:
 * closets and crates, girders, airlock assemblies and loose windows. A visitor can wrench one of those down on an
 * Open floor, and anyone can wrench it back up.
 */

/**
 * Whether `builder` may build, bolt down, lay cable or use an RCD on `target`. Off a floor: yes. On a floor: only
 * its people and its owner's named builders, and never on the hull, the landing or the goods lift (A5, A77).
 * Asked for every build in the game, so it leaves at once when no floor has ground or `target` is on none.
 */
/proc/outpost_floor_build_allowed(mob/builder, atom/target)
	if(!length(GLOB.outpost_floors_on_ground))
		return TRUE
	var/turf/where = get_turf(target)
	var/datum/outpost_floor/floor = get_outpost_floor_for_turf(where)
	if(!floor)
		return TRUE
	// Outpost ground: the hull ring, the landing and the goods lift's tiles are nobody's to build on
	if(!floor.is_buildable(where))
		return FALSE
	if(!builder)
		return FALSE
	return floor.is_member(builder) || !!floor.host?.can_build(builder)

/// What a refused builder reads on `target`: a floor's own line, or the outpost's everywhere else
/proc/outpost_build_refusal_text(atom/target)
	if(get_outpost_floor_for_turf(get_turf(target)))
		return "not yours to build on!"
	return "outpost property!"

/// L29: a wrench bolts nothing down on a floor for anyone but its builders, and for nobody on outpost ground (A5)
/obj/can_be_unfasten_wrench(mob/user, silent)
	if(!anchored && length(GLOB.outpost_floors_on_ground) && !outpost_floor_build_allowed(user, src))
		if(!silent && user)
			balloon_alert(user, outpost_build_refusal_text(src))
		return FAILED_UNFASTEN
	return ..()

// ===== THE RESTAURANT PORTAL (L37, A86) =====
// tg's venues are one of each for the whole game: every portal linked to a venue shares its open flag, and a new
// robot customer walks out of a portal picked at random. Its customers pay in holochips with no cap, which would
// bury the one NPC budget a floor has. So a portal on a floor cannot open its venue, and no customer ever comes
// out of one, whoever opened the venue and wherever.

/// Whether this portal stands on a leased floor
/obj/machinery/restaurant_portal/proc/on_outpost_floor()
	return !!get_outpost_floor_for_turf(get_turf(src))

/obj/machinery/restaurant_portal/attack_hand(mob/living/user, list/modifiers)
	if(on_outpost_floor())
		balloon_alert(user, "no signal!")
		return
	return ..()

/// The door stays down on a floor even while the venue is open somewhere else
/obj/machinery/restaurant_portal/update_overlays()
	. = ..()
	if(linked_venue?.open && on_outpost_floor())
		. += mutable_appearance(icon, "portal_door")

/// A customer never arrives through a portal on a floor. With every portal upstairs, nobody comes.
/datum/venue/create_new_customer()
	if(!length(GLOB.outpost_floors_on_ground))
		return ..()
	var/list/obj/machinery/restaurant_portal/every_portal = restaurant_portals
	var/list/obj/machinery/restaurant_portal/downstairs = list()
	for(var/obj/machinery/restaurant_portal/portal in every_portal)
		if(!portal.on_outpost_floor())
			downstairs += portal
	if(length(downstairs) == length(every_portal))
		return ..()
	if(!length(downstairs))
		return
	// The parent picks from restaurant_portals and does not sleep: lend it the short list for the one call
	restaurant_portals = downstairs
	. = ..()
	restaurant_portals = every_portal
