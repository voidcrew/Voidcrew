/**
 * The Weird Route: Deltarune Chapter 5's evening lake (obj_ch5_LW20W and its handoff), with Moffer
 * in Noelle's place and whoever's sent there in Kris's. He talks them into the lake, a "Proceed" at
 * a time. Walk all the way in and they come out in the Meat Factory: a white plane strewn with sprite
 * sheets. Hesitate too long once he's under and it's over.
 *
 * Admins send someone (Admin.Fun: "Weird Route"). The music and sounds are the game's own, so they
 * aren't shipped: put them in data/weird_route/ (see WEIRD_ROUTE_SOUNDS). Without them it plays silent.
 *
 * Both places are built on reserved ground when someone's sent, before they're taken (the Meat
 * Factory takes a minute or two), and given back when they leave. Each kind shares one area, however
 * many are down there at once.
 */

/// Where the Weird Route's sounds are looked for.
#define WEIRD_ROUTE_SOUNDS "data/weird_route/"
/// Spelled out where the game's ending spells out " SIDE B".
#define WEIRD_ROUTE_DESTINATION " MEAT FACTORY"
/// Deltarune runs at 30 frames a second: this many deciseconds to a frame.
#define WEIRD_ROUTE_FRAME (1 / 3)
/// Our pixels to one of the game's (its units are its own pixels: Noelle's 46 tall, a person here 32).
#define WEIRD_ROUTE_SCALE 0.7
/// The lake, in tiles: room enough that the camera never sees past it.
#define WEIRD_ROUTE_LAKE_WIDTH 72
#define WEIRD_ROUTE_LAKE_HEIGHT 37
/// The row everyone walks along.
#define WEIRD_ROUTE_LAKE_ROW 19
/// Tiles of path to the west of where the scene's own room starts (the game's x of 0).
#define WEIRD_ROUTE_LAKE_LEFT 18
/// The tile the shore's on: where they first get their feet wet, 400 of the game's units in.
#define WEIRD_ROUTE_LAKE_SHORE (WEIRD_ROUTE_LAKE_LEFT + 9)
/// The Meat Factory, in tiles.
#define WEIRD_ROUTE_FACTORY_WIDTH 160
#define WEIRD_ROUTE_FACTORY_HEIGHT 130

/area/weird_route
	name = "the lake"
	icon = 'icons/area/areas_misc.dmi'
	icon_state = "unknown"
	area_flags = HIDDEN_AREA | EVENT_PROTECTED
	default_gravity = STANDARD_GRAVITY
	requires_power = FALSE
	static_lighting = FALSE
	// The sun going down over the water.
	base_lighting_alpha = 255
	base_lighting_color = "#ffb486"
	ambience_index = null
	ambient_buzz = null

/area/weird_route/meat_factory
	name = "MEAT FACTORY"
	// Nothing casts a shadow here but the two who arrive.
	base_lighting_color = COLOR_WHITE

/turf/open/indestructible/weird_route
	name = "dirt path"
	icon = 'voidcrew/modules/weird_route/icons/weird_route.dmi'
	icon_state = "path"
	footstep = FOOTSTEP_SAND
	barefootstep = FOOTSTEP_SAND
	clawfootstep = FOOTSTEP_SAND
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	tiled_dirt = FALSE

/turf/open/indestructible/weird_route/grass
	name = "grass"
	icon_state = "grass"
	footstep = FOOTSTEP_GRASS
	barefootstep = FOOTSTEP_GRASS
	clawfootstep = FOOTSTEP_GRASS

/turf/open/indestructible/weird_route/shore
	name = "shore"
	icon_state = "shore"

/turf/open/indestructible/weird_route/water
	name = "lake"
	desc = "It's colder than it looks."
	icon_state = "water"
	footstep = FOOTSTEP_WATER
	barefootstep = FOOTSTEP_WATER
	clawfootstep = FOOTSTEP_WATER
	heavyfootstep = FOOTSTEP_WATER

/turf/open/indestructible/weird_route/water/far
	icon_state = "water_far"

/turf/open/indestructible/weird_route/white
	name = "floor"
	desc = "There's nothing here. It goes on forever."
	icon_state = "white"
	footstep = FOOTSTEP_FLOOR
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW

/// Scenery: trees and bushes turned for autumn, leaves, and the Meat Factory's sheets. Just looks.
/obj/effect/weird_route_scenery
	name = ""
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = TURF_DECAL_LAYER
	plane = FLOOR_PLANE

/obj/effect/weird_route_scenery/Initialize(mapload, icon/look_icon, look_state, colour, offset_x = 0, offset_y = 0, standing = FALSE)
	. = ..()
	icon = look_icon
	icon_state = look_state
	color = colour
	pixel_w = offset_x
	pixel_z = offset_y
	// Trees and bushes stand up, below people, so the white can take them with the rest.
	if(standing)
		plane = GAME_PLANE
		layer = OBJ_LAYER

/// A colour matrix turning something green the colour of autumn (tint, as "#rrggbb").
/proc/weird_route_autumn(tint)
	var/list/rgb = rgb2num(tint)
	var/list/weights = list(0.25, 0.65, 0.1)
	. = list()
	for(var/channel in 1 to 3)
		for(var/out in 1 to 3)
			. += rgb[out] / 255 * weights[channel] * 1.5
	. += list(0, 0, 0)

/**
 * Builds the evening lake on reserved ground: an orange dirt path between rows of autumn trees,
 * running east into the water: olive by the shore, then orange with the sky. Returns the reservation.
 */
/proc/weird_route_build_lake()
	var/datum/turf_reservation/reservation = SSmapping.request_turf_block_reservation(WEIRD_ROUTE_LAKE_WIDTH, WEIRD_ROUTE_LAKE_HEIGHT, requester = "the Weird Route's lake")
	if(!reservation)
		return null
	var/static/area/weird_route/lake
	if(QDELETED(lake))
		lake = new
	var/turf/origin = reservation.bottom_left_turfs[1]
	for(var/turf/spot as anything in reservation.reserved_turfs)
		var/x = spot.x - origin.x + 1
		var/y = spot.y - origin.y + 1
		var/turf_type = /turf/open/indestructible/weird_route/grass
		if(x == WEIRD_ROUTE_LAKE_SHORE)
			turf_type = /turf/open/indestructible/weird_route/shore
		else if(x > WEIRD_ROUTE_LAKE_SHORE + 6)
			turf_type = /turf/open/indestructible/weird_route/water/far
		else if(x > WEIRD_ROUTE_LAKE_SHORE)
			turf_type = /turf/open/indestructible/weird_route/water
		else if(y >= WEIRD_ROUTE_LAKE_ROW - 2 && y <= WEIRD_ROUTE_LAKE_ROW + 2)
			turf_type = /turf/open/indestructible/weird_route
		var/area/old_area = spot.loc
		spot.ChangeTurf(turf_type)
		spot.change_area(old_area, lake)
		if(x >= WEIRD_ROUTE_LAKE_SHORE)
			continue
		// Fallen leaves, and the trees above and below the path.
		if(prob(30))
			new /obj/effect/weird_route_scenery(spot, 'voidcrew/modules/weird_route/icons/weird_route.dmi', "leaves[rand(1, 3)]")
		var/from_path = abs(y - WEIRD_ROUTE_LAKE_ROW)
		if((from_path == 5 || from_path == 9 || from_path == 13 || from_path == 17) && x % 2 == 1)
			new /obj/effect/weird_route_scenery(spot, 'icons/obj/fluff/flora/jungletreesmall.dmi', "tree[rand(1, 6)]", weird_route_autumn(pick("#ffc21a", "#ff8a1c", "#ffd23a")), -32, 0, TRUE)
		else if((y == WEIRD_ROUTE_LAKE_ROW - 3 || y == WEIRD_ROUTE_LAKE_ROW + 3) && prob(35))
			new /obj/effect/weird_route_scenery(spot, 'icons/obj/fluff/flora/ausflora.dmi', "leafybush_[rand(1, 3)]", weird_route_autumn(pick("#ff2a1a", "#e01810")), 0, 0, TRUE)
	// Red bushes along the bank.
	for(var/y in list(WEIRD_ROUTE_LAKE_ROW - 6, WEIRD_ROUTE_LAKE_ROW - 5, WEIRD_ROUTE_LAKE_ROW + 5, WEIRD_ROUTE_LAKE_ROW + 6))
		var/turf/bank = locate(origin.x + WEIRD_ROUTE_LAKE_SHORE - 1, origin.y + y - 1, origin.z)
		new /obj/effect/weird_route_scenery(bank, 'icons/obj/fluff/flora/ausflora.dmi', "leafybush_[rand(1, 3)]", weird_route_autumn("#ff2a1a"), 0, 0, TRUE)
	return reservation

/// Our renders and tg's test screenshots, at their sprites' own size: list(index, columns, rows) of
/// 256px squares in weird_route_sheets.dmi.
GLOBAL_LIST_INIT(weird_route_sheets, list(
	list(0, 2, 1), list(1, 3, 1), list(2, 2, 1), list(3, 2, 1), list(4, 1, 1), list(5, 2, 1), list(6, 1, 1), list(7, 1, 1), list(8, 2, 1), list(9, 1, 1), list(10, 2, 1), list(11, 2, 1), list(12, 3, 2), list(13, 3, 1), list(14, 3, 1), list(15, 2, 1), list(16, 2, 1), list(17, 3, 1), list(18, 2, 1), list(19, 2, 3), list(20, 3, 3), list(21, 1, 1), list(22, 1, 1), list(23, 2, 1), list(24, 2, 1), list(25, 1, 1), list(26, 2, 1), list(27, 2, 1), list(28, 2, 1), list(29, 1, 1), list(30, 2, 3), list(31, 1, 1), list(32, 3, 3),
))

/// Icon files laid out on the Meat Factory's floor as the sprite sheets they are, every state in a
/// grid: list(file, directions to show each state in).
GLOBAL_LIST_INIT(weird_route_icon_sheets, list(
	list('icons/mob/human/bodyparts_greyscale.dmi', 4),
	list('icons/mob/human/species/moth/bodyparts.dmi', 4),
	list('icons/mob/human/species/lizard/bodyparts.dmi', 4),
	list('icons/mob/human/human_face.dmi', 4),
	list('icons/mob/human/species/lizard/lizard_tails.dmi', 4),
	list('icons/mob/clothing/under/color.dmi', 4),
	list('icons/mob/clothing/suits/armor.dmi', 4),
	list('icons/mob/clothing/head/hats.dmi', 4),
	list('voidcrew/modules/expie/icons/bodyparts.dmi', 4),
	list('voidcrew/modules/expie/icons/milkie_bodyparts.dmi', 4),
	list('voidcrew/modules/fnf/icons/fnf_faces.dmi', 4),
	list('voidcrew/modules/fnf/icons/fnf_faces_corrupt.dmi', 4),
	list('voidcrew/modules/limb_rig/icons/humanoid.dmi', 1),
	list('icons/mob/simple/animal.dmi', 4),
	list('icons/mob/simple/pets.dmi', 4),
	list('icons/mob/silicon/robots.dmi', 4),
	list('icons/mob/nonhuman-player/alien.dmi', 4),
	list('icons/obj/medical/organs/organs.dmi', 1),
	list('icons/obj/clothing/under/color.dmi', 1),
	list('icons/obj/food/food.dmi', 1),
	list('icons/obj/weapons/guns/ballistic.dmi', 1),
	list('icons/obj/tools.dmi', 1),
	list('icons/obj/drinks/drinks.dmi', 1),
	list('icons/obj/toys/toy.dmi', 1),
	list('icons/obj/fluff/flora/plants.dmi', 1),
))

/// The most states shown from any one icon file.
#define WEIRD_ROUTE_SHEET_STATES 48

/**
 * Builds the Meat Factory on reserved ground: white as far as anyone can see, fully lit, the floor
 * strewn with sprite sheets at their sprites' own size, in rows with white between: our renders,
 * tg's test screenshots, and icon files laid out state by state. Returns the reservation.
 */
/proc/weird_route_build_factory()
	var/datum/turf_reservation/reservation = SSmapping.request_turf_block_reservation(WEIRD_ROUTE_FACTORY_WIDTH, WEIRD_ROUTE_FACTORY_HEIGHT, requester = "the Weird Route's Meat Factory")
	if(!reservation)
		return null
	var/static/area/weird_route/meat_factory/factory
	if(QDELETED(factory))
		factory = new
	var/turf/origin = reservation.bottom_left_turfs[1]
	for(var/turf/spot as anything in reservation.reserved_turfs)
		var/area/old_area = spot.loc
		spot.ChangeTurf(/turf/open/indestructible/weird_route/white)
		spot.change_area(old_area, factory)
		CHECK_TICK
	// Shelved in rows from the top, left to right, three tiles of white between each.
	var/list/shelf = list(4, WEIRD_ROUTE_FACTORY_HEIGHT - 4, 0)
	for(var/list/sheet as anything in GLOB.weird_route_sheets)
		var/list/corner = weird_route_shelve(shelf, sheet[2] * 8, sheet[3] * 8)
		if(!corner)
			break
		for(var/column in 0 to sheet[2] - 1)
			for(var/row in 0 to sheet[3] - 1)
				new /obj/effect/weird_route_scenery(locate(origin.x + corner[1] + column * 8, origin.y + corner[2] + row * 8, origin.z), 'voidcrew/modules/weird_route/icons/weird_route_sheets.dmi', "[sheet[1]]_[column]_[row]")
	for(var/list/sheet as anything in GLOB.weird_route_icon_sheets)
		var/icon/sheet_icon = sheet[1]
		var/directions = sheet[2]
		var/list/states = icon_states(sheet_icon)
		if(!length(states))
			continue
		states.Cut(min(length(states), WEIRD_ROUTE_SHEET_STATES) + 1)
		var/icon/probe = icon(sheet_icon, states[1])
		var/cell_width = max(1, ceil(probe.Width() / 32))
		var/cell_height = max(1, ceil(probe.Height() / 32))
		// A state to a row of its directions; as many of those across as fit in 16 tiles.
		var/across = max(1, floor(16 / (cell_width * directions)))
		var/rows = ceil(length(states) / across)
		var/list/corner = weird_route_shelve(shelf, across * cell_width * directions, rows * cell_height)
		if(!corner)
			break
		for(var/index in 1 to length(states))
			var/column = (index - 1) % across
			var/row = rows - 1 - floor((index - 1) / across)
			for(var/facing in 1 to directions)
				var/turf/spot = locate(origin.x + corner[1] + (column * directions + facing - 1) * cell_width, origin.y + corner[2] + row * cell_height, origin.z)
				var/obj/effect/weird_route_scenery/sprite = new(spot, sheet_icon, states[index])
				sprite.dir = list(SOUTH, NORTH, EAST, WEST)[facing]
		CHECK_TICK
	return reservation

/// Finds room on the Meat Factory's shelves (list(next x, top y, tallest so far)) for something this
/// many tiles across and high: its bottom left corner, or null once it's full.
/proc/weird_route_shelve(list/shelf, width, height)
	if(shelf[1] + width > WEIRD_ROUTE_FACTORY_WIDTH - 4)
		shelf[1] = 4
		shelf[2] -= shelf[3] + 3
		shelf[3] = 0
	if(shelf[2] - height < 4)
		return null
	. = list(shelf[1], shelf[2] - height)
	shelf[1] += width + 3
	shelf[3] = max(shelf[3], height)

ADMIN_VERB(weird_route_send, R_FUN, "Weird Route", "Send someone to the evening lake, where Moffer's waiting for them.", ADMIN_CATEGORY_FUN)
	var/list/candidates = list()
	for(var/mob/living/carbon/human/candidate in GLOB.player_list)
		if(candidate.client && !candidate.weird_route)
			candidates[key_name(candidate)] = candidate
	if(!length(candidates))
		to_chat(user, span_warning("Nobody's free to go to the lake."))
		return
	var/choice = tgui_input_list(user, "Who goes to the lake?", "Weird Route", sort_list(candidates))
	var/mob/living/carbon/human/chosen = candidates[choice]
	if(!chosen || chosen.weird_route)
		return
	var/datum/weird_route/route = new(chosen)
	if(QDELETED(route))
		return
	message_admins("[key_name_admin(user)] sent [ADMIN_LOOKUPFLW(chosen)] down the Weird Route. It's being built: they're taken once it's ready.")
	log_admin("[key_name(user)] sent [key_name(chosen)] down the Weird Route.")
	BLACKBOX_LOG_ADMIN_VERB("Weird Route")

ADMIN_VERB(weird_route_end, R_FUN, "Weird Route: Bring Back", "Bring someone back from the lake or the Meat Factory.", ADMIN_CATEGORY_FUN)
	var/list/candidates = list()
	for(var/datum/weird_route/route as anything in GLOB.weird_routes)
		candidates[key_name(route.player)] = route
	if(!length(candidates))
		to_chat(user, span_warning("Nobody's down the Weird Route."))
		return
	var/choice = tgui_input_list(user, "Who comes back?", "Weird Route", sort_list(candidates))
	var/datum/weird_route/route = candidates[choice]
	if(QDELETED(route))
		return
	log_admin("[key_name(user)] brought [key_name(route.player)] back from the Weird Route.")
	qdel(route)
