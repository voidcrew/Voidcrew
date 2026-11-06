/// Most eggs the nesting box holds
#define HOMESTEAD_COOP_EGGS_MAX 12

// =========================================================================
// THE WELL
// =========================================================================

/// An endless water source on a stone mound, a bucket on its rim. Fills containers like a sink.
/obj/structure/water_source/homestead_well
	name = "well"
	desc = "A stone well with a rope and bucket. The water's cold."
	icon = 'icons/obj/mining_zones/terrain.dmi'
	icon_state = "geyser"
	density = TRUE

/obj/structure/water_source/homestead_well/update_overlays()
	. = ..()
	var/mutable_appearance/bucket = mutable_appearance('icons/obj/service/janitor.dmi', "woodbucket")
	bucket.transform = matrix().Scale(0.6)
	bucket.pixel_w = 9
	bucket.pixel_z = 1
	. += bucket

/obj/structure/water_source/homestead_well/Initialize(mapload)
	. = ..()
	update_appearance(UPDATE_OVERLAYS)

// =========================================================================
// THE NESTING BOX
// =========================================================================

/// Where the eggs go. Anyone may put an egg in or take one out with an empty hand.
/obj/structure/homestead_coop
	name = "nesting box"
	desc = "Straw and a lid. The hens like it."
	icon = 'icons/obj/storage/crates.dmi'
	icon_state = "wooden"
	anchored = TRUE
	density = TRUE

/obj/structure/homestead_coop/Exited(atom/movable/gone, direction)
	. = ..()
	update_appearance(UPDATE_OVERLAYS)

/obj/structure/homestead_coop/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	update_appearance(UPDATE_OVERLAYS)

/obj/structure/homestead_coop/update_overlays()
	. = ..()
	var/shown = 0
	for(var/obj/item/food/egg/egg in contents)
		var/mutable_appearance/egg_look = mutable_appearance(egg.icon, egg.icon_state)
		egg_look.transform = matrix().Scale(0.5)
		egg_look.pixel_w = -8 + shown * 8
		egg_look.pixel_z = 9
		. += egg_look
		if(++shown >= 3)
			break

/obj/structure/homestead_coop/examine(mob/user)
	. = ..()
	var/eggs = egg_count()
	if(eggs)
		. += "[eggs == 1 ? "An egg sits" : "[eggs] eggs sit"] in the straw."

/obj/structure/homestead_coop/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	var/obj/item/food/egg/egg = locate() in contents
	if(!egg)
		balloon_alert(user, "empty")
		return TRUE
	if(!user.put_in_hands(egg))
		egg.forceMove(drop_location())
	balloon_alert(user, "took an egg")
	return TRUE

/obj/structure/homestead_coop/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/food/egg))
		return NONE
	if(!add_egg(tool, user))
		balloon_alert(user, "full")
		return ITEM_INTERACT_BLOCKING
	return ITEM_INTERACT_SUCCESS

/// How many eggs are in the box
/obj/structure/homestead_coop/proc/egg_count()
	. = 0
	for(var/obj/item/food/egg/egg in contents)
		.++

/// Puts `egg` in, from `user`'s hand if given. FALSE when the box is full.
/obj/structure/homestead_coop/proc/add_egg(obj/item/food/egg/egg, mob/living/user)
	if(QDELETED(egg) || egg_count() >= HOMESTEAD_COOP_EGGS_MAX)
		return FALSE
	if(user && !user.transferItemToLoc(egg, src))
		return FALSE
	if(!user)
		egg.forceMove(src)
	return TRUE

// =========================================================================
// THE FEED TROUGH
// =========================================================================

/**
 * A trough set into a fence line. Feed put in lies in the trough where animals on either side
 * find it and eat it (a cow eats wheat it sees); nothing about it is ore.
 */
/obj/structure/ore_container/food_trough/homestead
	name = "feed trough"
	desc = "A wooden feed trough, worn smooth by the cattle."
	icon = 'icons/obj/structures.dmi'
	icon_state = "raptor_trough"
	x_offsets = list(-5, 5)
	y_offsets = list(-4, 5)

/obj/structure/ore_container/food_trough/homestead/ui_interact(mob/user, datum/tgui/ui)
	return

/obj/structure/ore_container/food_trough/homestead/attackby(obj/item/feed, mob/living/carbon/human/user, list/modifiers, list/attack_modifiers)
	if(istype(feed, /obj/item/food/grown) && !user.combat_mode)
		if(user.transferItemToLoc(feed, drop_location()))
			add_feed(feed)
		return
	return ..()

/// Lays `feed` in the trough, on its tile where the animals reach it
/obj/structure/ore_container/food_trough/homestead/proc/add_feed(obj/item/feed)
	if(QDELETED(feed))
		return FALSE
	feed.forceMove(drop_location())
	feed.pixel_x = rand(x_offsets[1], x_offsets[2])
	feed.pixel_y = rand(y_offsets[1], y_offsets[2])
	return TRUE

// =========================================================================
// THE FARM STAND
// =========================================================================

/**
 * The porch stand: an unbreakable custom vendor that pays the homestead's Rancher. Linked
 * to each new Rancher when they start (homestead_background.dm), so it is never left for a passer-by
 * to claim with the first card swiped.
 */
/obj/machinery/vending/custom/unbreakable/homestead
	name = "farm stand"
	desc = "A wooden stand with a cash box and a hand-painted price board."

/obj/machinery/vending/custom/unbreakable/homestead/Initialize(mapload)
	. = ..()
	GLOB.homestead_farm_stands += src

/obj/machinery/vending/custom/unbreakable/homestead/Destroy()
	GLOB.homestead_farm_stands -= src
	return ..()

/// Every homestead farm stand in the world
GLOBAL_LIST_EMPTY(homestead_farm_stands)

// =========================================================================
// THE CROP HELPER
// =========================================================================

/**
 * Plants `crop` in the soil tray on its tile the way a player planting it does
 * (/obj/machinery/hydroponics/attackby() with seeds), half grown so the field reads as a field and has
 * most of its life ahead of it, then goes. On the Frontier's homestead the crop joins the seed stock
 * the family sows that plot from again (/datum/homestead/proc/sow_plot()).
 */
/obj/effect/mapping_helpers/homestead_crop
	name = "homestead crop"
	icon = 'icons/obj/service/hydroponics/seeds.dmi'
	icon_state = "seed"
	late = TRUE
	/// The seed type planted in the soil tray on this tile, set on the map
	var/obj/item/seeds/crop

/obj/effect/mapping_helpers/homestead_crop/LateInitialize()
	plant()
	qdel(src)

/// Plants the tray here. TRUE if it did.
/obj/effect/mapping_helpers/homestead_crop/proc/plant()
	if(!ispath(crop, /obj/item/seeds))
		return FALSE
	var/obj/machinery/hydroponics/tray = locate() in loc
	if(!tray || tray.myseed)
		return FALSE
	if(GLOB.homestead?.contains(src))
		GLOB.homestead.plot_crops[get_turf(src)] = crop
	var/obj/item/seeds/seed = new crop(tray)
	SEND_SIGNAL(seed, COMSIG_SEED_ON_PLANTED, tray)
	tray.set_seed(seed)
	tray.set_plant_health(seed.endurance)
	tray.lastcycle = world.time
	// Half grown: ripe within a few cycles of the round starting, far from old age
	tray.age = round(seed.maturation / 2)
	tray.lastproduce = tray.age
	tray.update_appearance()
	return TRUE

// =========================================================================
// LANDMARKS
// =========================================================================

/// Where the family and the homesteaders start. The family is made here by code, never mapped.
/obj/effect/landmark/homestead
	name = "homestead"

/obj/effect/landmark/homestead/Initialize(mapload)
	. = ..()
	return INITIALIZE_HINT_LATELOAD

/**
 * Landmarks initialize at once, while SSmapping stamps the homestead; their LateInitialize() runs
 * with SSatoms, after the rest of the homestead has initialized. Only on the Frontier's own
 * homestead: a test load of the template makes nobody.
 */
/obj/effect/landmark/homestead/LateInitialize()
	var/datum/homestead/homestead = GLOB.homestead
	if(homestead?.contains(src))
		homestead.landmark_ready(src)

/obj/effect/landmark/homestead/spouse
	name = "homestead spouse"

/obj/effect/landmark/homestead/child
	name = "homestead child"

/obj/effect/landmark/homestead/settler
	name = "homestead settler"

/// The Rancher's bed: the first Rancher of the round wakes here, the Hands at the other settler marks
/obj/effect/landmark/homestead/settler/rancher
	name = "homestead rancher"

#undef HOMESTEAD_COOP_EGGS_MAX
