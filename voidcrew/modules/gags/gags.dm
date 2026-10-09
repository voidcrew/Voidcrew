/**
 * Gags: things done to someone for a laugh, each acted out by the limb rig (voidcrew/modules/limb_rig)
 * to a clip of its own. Bodies without a rig still go through them, just without the poses.
 *
 * * Fall Down The Stairs (smite, stairs.dm): Peter Griffin's fall, down a long flight, into his pose.
 * * I Like Trains (smite, trains.dm): asdfmovie's three kids, and the tram.
 * * *skibidi (emote, skibidi.dm): a toilet with your head on a long neck, for a chorus.
 * * *springlock (emote, springlock.dm): the suit's springlocks give. Fatal.
 *
 * The smites take their victim to a room of their own: a map template in
 * _maps/voidcrew/templates/gags/, loaded on reserved ground and given back after.
 */

#define GAG_TRAIT "gag"
#define GAG_MAPS "_maps/voidcrew/templates/gags/"

/// Sleeps until this long (deciseconds) after the gag's start, and gives up if it ended meanwhile.
#define GAG_AT(at) sleep(started + (at) - world.time); if(QDELETED(src)) { return }

/mob/living/carbon/human
	/// The gag being played on them, if any.
	var/datum/gag/current_gag

/area/gag_room
	name = "somewhere else"
	icon = 'icons/area/areas_misc.dmi'
	icon_state = "unknown"
	area_flags = HIDDEN_AREA | EVENT_PROTECTED | NOTELEPORT
	default_gravity = STANDARD_GRAVITY
	requires_power = FALSE
	static_lighting = FALSE
	base_lighting_alpha = 255
	base_lighting_color = COLOR_WHITE
	ambience_index = null
	ambient_buzz = null

/// Just looks, set up in the gags' maps: the stairs, and the parts of the tram that run it.
/obj/effect/gag_scenery
	name = ""
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = TURF_DECAL_LAYER
	plane = FLOOR_PLANE

/// Scenery that stands up off the floor: doors, displays, consoles.
/obj/effect/gag_scenery/standing
	layer = OBJ_LAYER
	plane = GAME_PLANE

/// The tram's subfloor, without the tram it'd make move: under its floor and walls, as the real one is.
/obj/effect/gag_scenery/tram_subfloor
	icon = 'icons/obj/tram/tram_structure.dmi'
	icon_state = "subfloor"
	layer = TRAM_STRUCTURE_LAYER
	plane = GAME_PLANE

/// Loads one of the gags' maps (see GAG_MAPS) on reserved ground. Returns the reservation, or null.
/proc/gag_load_room(map_name)
	var/static/list/templates = list()
	var/datum/map_template/template = templates[map_name]
	if(!template)
		template = new(GAG_MAPS + map_name, cache = TRUE)
		templates[map_name] = template
	var/datum/turf_reservation/room = SSmapping.request_turf_block_reservation(template.width, template.height, requester = "a gag")
	if(!room)
		return null
	template.load(room.bottom_left_turfs[1])
	return room

/// A turf of a room, by its x and y in the map (from 1, at the bottom left, as map editors count).
/proc/gag_room_turf(datum/turf_reservation/room, x, y)
	var/turf/origin = room.bottom_left_turfs[1]
	return locate(origin.x + x - 1, origin.y + y - 1, origin.z)

/**
 * One gag being played on someone. Holds them still for it, and gives back afterwards whatever it
 * took: their transform, their place, the room it made.
 */
/datum/gag
	var/mob/living/carbon/human/victim
	/// Their transform before, given back when they're knocked down or it ends (see give_back_transform()).
	var/matrix/old_transform
	var/transform_taken = TRUE
	/// Where they were, for the gags that take them somewhere.
	var/turf/came_from
	var/datum/turf_reservation/room
	/// When it started, for its timings (see GAG_AT).
	var/started

/datum/gag/New(mob/living/carbon/human/victim)
	. = ..()
	src.victim = victim
	victim.current_gag = src
	old_transform = matrix(victim.transform)
	victim.add_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED), GAG_TRAIT)
	RegisterSignal(victim, COMSIG_QDELETING, PROC_REF(on_victim_deleted))
	RegisterSignal(victim, COMSIG_LIVING_SET_BODY_POSITION, PROC_REF(on_body_position))
	started = world.time
	INVOKE_ASYNC(src, PROC_REF(act))

/// The gag itself.
/datum/gag/proc/act()
	return

/datum/gag/Destroy()
	if(victim)
		UnregisterSignal(victim, list(COMSIG_QDELETING, COMSIG_LIVING_SET_BODY_POSITION))
		give_back_transform()
		victim.remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED, TRAIT_GODMODE), GAG_TRAIT)
		victim.pixel_w = victim.base_pixel_w
		victim.pixel_z = victim.base_pixel_z
		victim.current_gag = null
		victim = null
	// Nobody's left behind when the room goes, living or not.
	if(room)
		for(var/turf/spot as anything in room.reserved_turfs)
			for(var/mob/left in spot)
				left.forceMove(came_from || get_safe_random_station_turf())
	QDEL_NULL(room)
	return ..()

/datum/gag/proc/give_back_transform()
	if(!transform_taken)
		return
	transform_taken = FALSE
	victim.transform = old_transform

/datum/gag/proc/on_victim_deleted(datum/source)
	SIGNAL_HANDLER
	victim = null
	qdel(src)

/// Knocked down: the game turns them from their own transform, so they get it back first; and it's over.
/datum/gag/proc/on_body_position(datum/source, new_value, old_value)
	SIGNAL_HANDLER
	give_back_transform()
	if(new_value == LYING_DOWN)
		qdel(src)

/// Poses someone, held until they're told otherwise (see /datum/limb_rig/proc/settle()).
/proc/gag_pose(mob/living/carbon/who, list/pose, time = 1)
	who.limb_rig?.play(list(list(pose, max(time, 0.5))), settle_after = FALSE)

/// Every limb flung somewhere, as when tumbling.
/proc/gag_flail_pose()
	return list(
		RIG_L_ARM = list("swing" = rand(-150, 150), "raise" = rand(0, 60), "elbow" = rand(0, 120)),
		RIG_R_ARM = list("swing" = rand(-150, 150), "raise" = rand(0, 60), "elbow" = rand(0, 120)),
		RIG_L_LEG = list("swing" = rand(-70, 100), "knee" = rand(0, 120)),
		RIG_R_LEG = list("swing" = rand(-70, 100), "knee" = rand(0, 120)),
		RIG_HEAD = list("nod" = rand(-30, 30)),
		RIG_CHEST = list("bend" = rand(-20, 30)),
	)
