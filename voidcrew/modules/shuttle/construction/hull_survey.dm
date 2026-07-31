/**
 * Hull Survey
 *
 * Tool-free, in-person hull claiming. A player seals a room out of whatever is to
 * hand - rock, plating, plastitanium, it makes no difference - stands inside it, and
 * uses the Survey Hull action. If the enclosure adjoins a ship, it is integrated into
 * that hull. If it does not adjoin one but contains a helm console, it is commissioned
 * as a new vessel.
 *
 * Both outcomes run the same survey and the same validation; only the commit differs.
 * The shared validators here are also what the ship construction console calls, so the
 * drone and the action can never disagree about what is legal.
 *
 * Airtightness is the only structural requirement, because detect_room() tests atmos
 * connectivity and nothing else. That is deliberate: it is what lets a crew build a
 * ship out of a sealed cave.
 */

/// Largest enclosure a single survey will claim, in tiles.
#define HULL_SURVEY_MAX_TILES 300
/// How long the survey takes, in-person, before it commits.
#define HULL_SURVEY_DURATION (6 SECONDS)

// ============================================
// Sizing
// ============================================

/**
 * The reserve-dock fit rule, in one place.
 *
 * Encounter berths are allocated as RESERVE_DOCK_MAX_SIZE_LONG x RESERVE_DOCK_MAX_SIZE_SHORT
 * rectangles (see outpost_hangar.dm), and adjust_reserve_dock_to_shuttle() rotates the berth
 * to align its long side with the hull's long side before docking. So the test is symmetric:
 * the hull's longer axis has to fit the berth's long side and its shorter axis the short side.
 *
 * This is the same comparison the dock-time gates make against shuttle.width/height
 * (player_outpost.dm, outpost.dm, colosseum_site.dm). A hull that fails it can still fly,
 * but can never be given a dock at a planet, ruin or outpost - which is a soft-lock, not an
 * inconvenience. Anything that grows a hull must check this BEFORE it commits, because
 * neither create_shuttle() nor expand_shuttle() can be rolled back.
 */
/proc/hull_dimensions_fit(x_extent, y_extent)
	if(max(x_extent, y_extent) > RESERVE_DOCK_MAX_SIZE_LONG)
		return FALSE
	if(min(x_extent, y_extent) > RESERVE_DOCK_MAX_SIZE_SHORT)
		return FALSE
	return TRUE

/**
 * Map-axis extents of a claim: the bounding box of `turfs`, unioned with `port`'s current
 * footprint when we are expanding an existing hull.
 *
 * Works in absolute map x/y rather than the port's local width/height. That is safe here
 * *only* because hull_dimensions_fit() is symmetric - calculate_docking_port_information()
 * swaps width and height for an EAST/WEST facing port, so {width, height} and
 * {x_extent, y_extent} are the same pair of numbers in some order, and max/min don't care
 * about the order. Do not reuse this for any asymmetric test.
 *
 * Returns list(x_extent, y_extent).
 */
/proc/hull_claim_bounds(list/turfs, obj/docking_port/mobile/port)
	var/min_x = INFINITY
	var/min_y = INFINITY
	var/max_x = 0
	var/max_y = 0

	if(port)
		// return_coords() corner order depends on the port's dir, so normalise it.
		var/list/bounds = port.return_coords()
		min_x = min(bounds[1], bounds[3])
		min_y = min(bounds[2], bounds[4])
		max_x = max(bounds[1], bounds[3])
		max_y = max(bounds[2], bounds[4])

	for(var/turf/claimed as anything in turfs)
		min_x = min(min_x, claimed.x)
		min_y = min(min_y, claimed.y)
		max_x = max(max_x, claimed.x)
		max_y = max(max_y, claimed.y)

	return list((max_x - min_x) + 1, (max_y - min_y) + 1)

/// Human-readable reason a claim busts the berth limits, or null if it fits.
/proc/hull_size_refusal(list/turfs, obj/docking_port/mobile/port)
	var/list/extents = hull_claim_bounds(turfs, port)
	if(hull_dimensions_fit(extents[1], extents[2]))
		return null
	return "Survey rejects the enclosure: the resulting hull would measure \
		[max(extents[1], extents[2])] by [min(extents[1], extents[2])] metres. No berth \
		exceeds [RESERVE_DOCK_MAX_SIZE_LONG] by [RESERVE_DOCK_MAX_SIZE_SHORT]. A hull this \
		size could never dock again."

// ============================================
// Survey
// ============================================

/**
 * Flood-fills the airtight enclosure around `origin`.
 * Returns an assoc list of turfs, or null if the room is open to space or too large.
 */
/proc/survey_enclosure(turf/origin, max_tiles = HULL_SURVEY_MAX_TILES)
	var/static/list/breaks_the_seal = typecacheof(list(
		/turf/open/space,
	))
	return detect_room(origin, breaks_the_seal, max_tiles)

/**
 * Is this turf's area one we're allowed to absorb?
 * Space and planetoid exteriors only - never a ruin, never someone else's hull.
 */
/proc/hull_claim_area_valid(turf/candidate)
	var/area/candidate_area = get_area(candidate)
	if(isnull(candidate_area))
		return FALSE
	if(istype(candidate_area, /area/ruin))
		return FALSE
	if(isshuttleturf(candidate))
		return FALSE
	return istype(candidate_area, /area/space) || istype(candidate_area, /area/overmap_encounter/planetoid)

/// TRUE if `candidate` cardinally touches any area belonging to `port`.
/proc/hull_claim_touches_port(turf/candidate, obj/docking_port/mobile/port)
	for(var/check_dir in GLOB.cardinals)
		var/turf/neighbour = get_step(candidate, check_dir)
		if(!neighbour)
			continue
		if(port.shuttle_areas[get_area(neighbour)])
			return TRUE
	return FALSE

/**
 * Full legality check for a claim. Returns a refusal string, or null if the claim is good.
 *
 * `port` is the hull being expanded, or null when commissioning a new vessel.
 */
/proc/validate_hull_claim(list/turfs, obj/docking_port/mobile/port)
	if(!length(turfs))
		return "Survey inconclusive: this space is not airtight."
	if(length(turfs) > HULL_SURVEY_MAX_TILES)
		return "Survey rejects the enclosure: [length(turfs)] tiles exceeds the \
			[HULL_SURVEY_MAX_TILES] tile limit for a single survey."

	var/size_refusal = hull_size_refusal(turfs, port)
	if(size_refusal)
		return size_refusal

	var/adjoins_port = isnull(port)
	var/list/apcs_found = list()

	for(var/turf/claimed as anything in turfs)
		if(isshuttleturf(claimed))
			return "Survey rejects the enclosure: part of it already belongs to a hull."
		if(!hull_claim_area_valid(claimed))
			return "Survey rejects the enclosure: it overlaps ground that cannot be claimed."

		var/area/claimed_area = get_area(claimed)
		if(claimed_area.apc)
			apcs_found |= claimed_area.apc
			if(length(apcs_found) > 1)
				return "Survey rejects the enclosure: it spans more than one power controller."

		if(!adjoins_port && hull_claim_touches_port(claimed, port))
			adjoins_port = TRUE

	if(!adjoins_port)
		return "Survey rejects the enclosure: it does not adjoin the hull."

	return null

// ============================================
// Turf preparation
// ============================================

/**
 * Marks the boundary between what travels with the hull and what stays behind.
 *
 * create_shuttle() and expand_shuttle() both do:
 *     turf.stack_below_baseturf(/turf/open/floor/plating, /turf/baseturf_skipover/shuttle)
 * and stack_below_baseturf() matches typepaths EXACTLY - baseturfs.Find() is not istype().
 * A planet-native floor (dirt, sand, snow, rock) has no literal /turf/open/floor/plating
 * anywhere in its chain and is not itself that exact type, so that call silently no-ops.
 * The turf then never gains a skipover, isshuttleturf() stays FALSE, and the hull leaves
 * the floor behind on its first launch with no runtime and no warning.
 *
 * So: if the stock call is going to find its plating, leave it alone and let it work. If it
 * isn't, append the skipover ourselves. Appending to the top of the chain is the same idiom
 * the shuttle-rod lattice path uses (see /turf/open/proc/build_with_rods), and it is what
 * onShuttleMove()/afterShuttleMove() expect: everything above the skipover is copied to the
 * new location, everything below it is what the old tile scrapes back down to. For a cave
 * floor that means the floor itself sails and the planet keeps its ground.
 */
/proc/prepare_claimed_turf(turf/claimed)
	if(!islist(claimed.baseturfs))
		claimed.baseturfs = list(claimed.baseturfs)
	if(claimed.depth_to_find_baseturf(/turf/baseturf_skipover/shuttle))
		return FALSE // already marked
	if(claimed.baseturfs.Find(/turf/open/floor/plating) || claimed.type == /turf/open/floor/plating)
		return FALSE // the stock stack_below_baseturf() call will place it correctly
	claimed.insert_baseturf(turf_type = /turf/baseturf_skipover/shuttle)
	return TRUE

/// Runs prepare_claimed_turf() over a whole claim.
/proc/prepare_claimed_turfs(list/turfs)
	for(var/turf/claimed as anything in turfs)
		prepare_claimed_turf(claimed)

// ============================================
// Commissioning a new vessel
// ============================================

/**
 * Stand-in template for a hull that was never loaded from a .dmm.
 *
 * setup_from_template() hard-returns FALSE without a template, and it is what supplies
 * ship_team, job_slots, ship_account and display_name. None of that needs a map, so this
 * exists purely to satisfy it.
 */
/datum/map_template/shuttle/voidcrew/commissioned
	name = "Commissioned Vessel"
	short_name = "Commissioned"
	catalog_desc = "A hull built by hand, out of whatever was to hand."
	player_hidden = TRUE
	job_slots = list(
		list(
			name = "Shipwright",
			officer = TRUE,
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 1,
		),
	)

/datum/map_template/shuttle/voidcrew/commissioned/New()
	// Deliberately does NOT call ..(). The parent chain measures [prefix][port_id]_[suffix].dmm
	// via preload_size(), and this template has no map on disk. Everything the parent New()
	// actually does for us is the part_requirements fill below.
	for(var/part_class in GLOB.ship_part_classes)
		if(!(part_class in part_requirements))
			part_requirements[part_class] = 0

/**
 * Turns a sealed enclosure into a flying vessel.
 *
 * Mirrors SSshuttle.create_ship()'s post-load wiring, minus the map load: create the port,
 * create the overmap object, point them at each other, and park the overmap token inside
 * whatever encounter the builders are standing in.
 *
 * Returns the new overmap ship, or null on failure.
 */
/proc/commission_vessel(mob/user, turf/origin, list/turfs, vessel_name)
	prepare_claimed_turfs(turfs)

	var/list/extents = hull_claim_bounds(turfs, null)
	// Berths are allocated long-side-east-west (outpost_hangar.dm), and
	// calculate_docking_port_information() swaps width/height for an EAST/WEST facing port.
	// Facing the port along the short axis therefore makes shuttle.width the hull's long
	// axis either way, which is the orientation the berth is already shaped for. Hulls whose
	// port_direction disagrees with that guess spin 90 degrees on every dock cycle.
	var/port_dir = (extents[1] >= extents[2]) ? NORTH : EAST

	var/obj/docking_port/mobile/voidcrew/port = create_shuttle(
		user,
		origin,
		turfs,
		list(),
		shuttle_dir = REVERSE_DIR(port_dir),
		port_dir = port_dir,
		area_type = /area/shuttle/voidcrew,
		docking_port_type = /obj/docking_port/mobile/voidcrew,
		name = vessel_name,
		id = "commissioned_[rand(1000, 9999)]_[world.time]",
	)
	if(!istype(port))
		return null

	var/obj/structure/overmap/ship/vessel = new(SSovermap.get_unused_overmap_square())
	if(!vessel.setup_from_template(new /datum/map_template/shuttle/voidcrew/commissioned()))
		qdel(vessel)
		return null

	port.current_ship = vessel
	vessel.shuttle = port
	vessel.name = vessel_name
	vessel.display_name = vessel_name
	vessel.calculate_mass()

	// Stationloving and observer spawns both need a landmark somewhere inside the hull.
	new /obj/effect/landmark/blobstart(origin)
	new /obj/effect/landmark/observer_start(origin)

	// The hull is sitting inside an encounter, so the overmap token belongs there, docked -
	// the same state check_loc() would force it into on the next tick anyway.
	var/obj/structure/overmap/host = SSovermap_zones.get_overmap_object_for_turf(origin)
	if(host)
		vessel.forceMove(host)
		vessel.docked = host
		vessel.state = OVERMAP_SHIP_IDLE

	vessel.update_flight_parallax()
	SEND_SIGNAL(port, COMSIG_VOIDCREW_SHIP_LOADED)

	message_admins("[key_name(user)] commissioned a scratch-built vessel, [vessel_name], at [ADMIN_VERBOSEJMP(origin)].")
	log_shuttle("[key_name(user)] commissioned scratch-built vessel [vessel_name] at [get_area(origin)].")
	return vessel

/// Folds a validated enclosure into an existing hull.
/proc/integrate_into_hull(mob/user, obj/docking_port/mobile/port, list/turfs)
	prepare_claimed_turfs(turfs)
	expand_shuttle(user, port, turfs, list())
	return TRUE

// ============================================
// The player-facing action
// ============================================

/**
 * Runs a survey where the user is standing and acts on the result.
 *
 * One entry point for both outcomes: if the enclosure adjoins a hull we expand that hull,
 * otherwise we look for a helm console and commission a new one.
 */
/mob/living/proc/perform_hull_survey()
	var/turf/origin = get_turf(src)
	if(!origin)
		return

	if(!can_perform_action(src, NEED_LITERACY|ALLOW_RESTING))
		return

	var/list/turfs = survey_enclosure(origin)
	if(!length(turfs))
		to_chat(src, span_warning("Survey inconclusive: this space is not airtight."))
		return

	// Which hull, if any, does this enclosure touch? First one wins.
	var/obj/docking_port/mobile/adjoining_port
	for(var/turf/claimed as anything in turfs)
		for(var/check_dir in GLOB.cardinals)
			var/turf/neighbour = get_step(claimed, check_dir)
			if(!neighbour)
				continue
			var/obj/docking_port/mobile/found = SSshuttle.get_containing_shuttle(neighbour)
			if(found)
				adjoining_port = found
				break
		if(adjoining_port)
			break

	var/refusal = validate_hull_claim(turfs, adjoining_port)
	if(refusal)
		to_chat(src, span_warning(refusal))
		return

	if(adjoining_port)
		survey_expand(origin, turfs, adjoining_port)
	else
		survey_commission(origin, turfs)

/// Expansion branch: confirm, re-validate, then integrate.
/mob/living/proc/survey_expand(turf/origin, list/turfs, obj/docking_port/mobile/port)
	// current_ship is declared on the voidcrew port subtype, not the base mobile port.
	var/obj/docking_port/mobile/voidcrew/voidcrew_port = port
	var/obj/structure/overmap/ship/vessel = istype(voidcrew_port) ? voidcrew_port.current_ship : null
	if(!vessel)
		to_chat(src, span_warning("The adjoining hull has no registered vessel."))
		return

	// expand_shuttle() finishes with a forced self-redock to commit the new bounds, which
	// must not happen to a ship that is under way.
	if(vessel.state != OVERMAP_SHIP_IDLE)
		to_chat(src, span_warning("[vessel.name] is under way. The hull can only be altered while docked."))
		return
	if(!COOLDOWN_FINISHED(vessel, interdiction_undock_lockout))
		to_chat(src, span_warning("Docking clamps are engaged. The hull cannot be altered right now."))
		return

	to_chat(src, span_notice("You begin surveying the enclosure - [length(turfs)] tiles, adjoining [vessel.name]."))
	if(!do_after(src, HULL_SURVEY_DURATION, origin))
		return

	// The world can change during the do_after, and neither expand_shuttle() nor
	// create_shuttle() can be rolled back once they start. Re-survey and re-validate.
	var/list/fresh_turfs = survey_enclosure(origin)
	var/refusal = validate_hull_claim(fresh_turfs, port)
	if(refusal)
		to_chat(src, span_warning(refusal))
		return
	if(vessel.state != OVERMAP_SHIP_IDLE)
		to_chat(src, span_warning("[vessel.name] got under way mid-survey."))
		return

	integrate_into_hull(src, port, fresh_turfs)
	to_chat(src, span_notice("Survey complete. [length(fresh_turfs)] tiles integrated into [vessel.name]."))

/// Commissioning branch: needs a helm console in the enclosure and a name.
/mob/living/proc/survey_commission(turf/origin, list/turfs)
	var/obj/machinery/computer/helm/found_helm
	for(var/turf/claimed as anything in turfs)
		found_helm = locate(/obj/machinery/computer/helm) in claimed
		if(found_helm)
			break

	if(!found_helm)
		to_chat(src, span_warning("Survey complete, but this enclosure has no helm console. \
			Without one there is nothing to fly it."))
		return

	var/vessel_name = tgui_input_text(src, "Designate the vessel:", "Commission Vessel", max_length = MAX_NAME_LEN)
	if(!vessel_name)
		return
	vessel_name = reject_bad_name(vessel_name, allow_numbers = TRUE)
	if(!vessel_name)
		to_chat(src, span_warning("That name will not do."))
		return

	to_chat(src, span_notice("You begin surveying the enclosure - [length(turfs)] tiles."))
	if(!do_after(src, HULL_SURVEY_DURATION, origin))
		return

	var/list/fresh_turfs = survey_enclosure(origin)
	var/refusal = validate_hull_claim(fresh_turfs, null)
	if(refusal)
		to_chat(src, span_warning(refusal))
		return
	if(QDELETED(found_helm) || !(get_turf(found_helm) in fresh_turfs))
		to_chat(src, span_warning("The helm console is no longer inside the enclosure."))
		return

	var/obj/structure/overmap/ship/vessel = commission_vessel(src, origin, fresh_turfs, vessel_name)
	if(!vessel)
		to_chat(src, span_warning("The survey failed to resolve into a hull."))
		return

	found_helm.attempt_ship_connection(last_resort = TRUE)
	to_chat(src, span_notice("Survey complete. [vessel_name] is registered as a vessel."))

/**
 * The survey button, as a persistent HUD screen object.
 *
 * Sits in the lower-right cluster alongside rest/pull/throw rather than in the action
 * button palette, so it is always on screen and never competes with granted abilities.
 */
/atom/movable/screen/hull_survey
	name = "survey hull"
	desc = "Survey the sealed space you are standing in. If it adjoins a ship it becomes \
		part of that hull; if it holds a helm console, it becomes a ship of its own."
	// icon is assigned from the hud's ui_style at construction, like every other button
	// here, so it follows the player's chosen HUD skin instead of hardcoding one.
	// act_survey exists in all nine sheets in GLOB.available_ui_styles.
	icon = 'icons/hud/screen_midnight.dmi'
	icon_state = "act_survey"
	base_icon_state = "act_survey"
	plane = HUD_PLANE
	mouse_over_pointer = MOUSE_HAND_POINTER

/atom/movable/screen/hull_survey/Click()
	if(!isliving(usr))
		return
	var/mob/living/living_user = usr
	living_user.perform_hull_survey()

/**
 * Everyone gets the button. Anyone who can seal a room can claim it, including someone
 * building a first ship from scratch who is not yet crew of anything.
 *
 * Defined as a second /datum/hud/human/New() rather than being folded into the one in
 * code/_onclick/hud/human.dm - DM chains same-type overrides across files in include
 * order and ..() walks back up the chain, which is the pattern voice_barks and intents
 * already use for their own init/login hooks.
 */
/datum/hud/human/New(mob/living/carbon/human/owner)
	. = ..()
	// Free up the tile first - stock tg puts the pull icon here, invisible while idle but
	// still clickable, so leaving it would stack two controls on one slot.
	pull_icon?.screen_loc = ui_pull_displaced

	var/atom/movable/screen/hull_survey/survey_button = new(null, src)
	survey_button.icon = ui_style
	survey_button.screen_loc = ui_hull_survey
	static_inventory += survey_button

#undef HULL_SURVEY_MAX_TILES
#undef HULL_SURVEY_DURATION
