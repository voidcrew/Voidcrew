/// Backgrounds: owned by P6.

/**
 * # The family's day
 *
 * Activities on the ambient runner (voidcrew/modules/ambient_npcs/ambient_activity.dm). Each one
 * looks up what it uses when it starts and gives up if it is gone (MOD-3). By day the spouse cooks,
 * works the field (harvest, sow, water) and feeds the animals; the children play tag, pet the dog and gather eggs. At
 * nightfall everyone eats supper at the table, then sleeps in their own bed until sunrise. While the
 * house is not safe they wait it out in the storm cellar. Unfed, nobody does animal work; the field is
 * worked regardless, since its harvest is what fills the fridge.
 */

/// The animal work the family skips while the house is unfed (the field is worked regardless: it fills the fridge)
#define HOMESTEAD_CHORES list(/datum/ambient_activity/homestead_feed, /datum/ambient_activity/homestead_eggs)
/// The dish the cook sets out
#define HOMESTEAD_DISH /obj/item/food/butterbiscuit
/// Every this many times at the stove, a dish comes out
#define HOMESTEAD_COOKS_PER_DISH 3
/// How long it stays quiet before anyone comes up out of the cellar
#define HOMESTEAD_CALM_TIME (30 SECONDS)

/// The homestead `thing` belongs to, if it is family
/proc/homestead_of(mob/living/basic/ambient_npc/homestead/thing)
	return istype(thing) ? thing.homestead : null

// =========================================================================
// CHOOSING WHAT TO DO
// =========================================================================

/mob/living/basic/ambient_npc/homestead/pick_activity()
	if(homestead)
		if(!homestead.safe && start_activity(new /datum/ambient_activity/homestead_hide(src)))
			return activity
		if(homestead.is_night())
			var/today = homestead.day_number()
			if(supper_day != today)
				supper_day = today
				if(start_activity(new /datum/ambient_activity/homestead_supper(src)))
					return activity
			if(start_activity(new /datum/ambient_activity/homestead_sleep(src)))
				return activity
	// Field work that is due comes first, most of the time
	if(homestead && field_worker && prob(65) && homestead.next_field_job(src) && start_activity(new /datum/ambient_activity/homestead_tend(src)))
		return activity
	var/list/weights = routine?.Copy()
	if(homestead && !homestead.fed)
		weights -= HOMESTEAD_CHORES
	while(length(weights))
		var/activity_type = pick_weight(weights)
		weights -= activity_type
		if(start_activity(new activity_type(src)))
			return activity
	return start_activity(new /datum/ambient_activity/idle(src))

/// Their own bed: the one they used last, else a free one in the house nearest their room that no settler sleeps in
/mob/living/basic/ambient_npc/homestead/proc/own_bed()
	var/obj/structure/bed/bed = bed_ref?.resolve()
	if(!QDELETED(bed) && homestead?.contains(bed) && (!bed.has_buckled_mobs() || (src in bed.buckled_mobs)))
		return bed
	bed_ref = null
	if(!homestead)
		return null
	var/list/taken = list()
	for(var/obj/effect/landmark/homestead/settler/mark in GLOB.landmarks_list)
		if(homestead.contains(mark))
			taken[get_turf(mark)] = TRUE
	for(var/mob/living/basic/ambient_npc/homestead/other as anything in homestead.all_members())
		var/obj/structure/bed/theirs = other.bed_ref?.resolve()
		if(other != src && theirs)
			taken[get_turf(theirs)] = TRUE
	var/atom/near = bed_anchor()
	var/best_distance = INFINITY
	for(var/obj/structure/bed/candidate as anything in homestead.fixtures_of(/obj/structure/bed))
		if(taken[get_turf(candidate)] || !istype(get_area(candidate), /area/voidcrew/homestead/house))
			continue
		if(candidate.has_buckled_mobs())
			continue
		var/distance = get_dist(candidate, near)
		if(distance < best_distance)
			bed = candidate
			best_distance = distance
	if(bed)
		bed_ref = WEAKREF(bed)
	return bed

/// Where their bed should be near: their own room
/mob/living/basic/ambient_npc/homestead/proc/bed_anchor()
	return home || get_turf(src)

// The spouse sleeps in the double room, beside the Rancher's bed
/mob/living/basic/ambient_npc/homestead/spouse/bed_anchor()
	for(var/obj/effect/landmark/homestead/settler/rancher/mark in GLOB.landmarks_list)
		if(homestead?.contains(mark))
			return get_turf(mark)
	return ..()

// =========================================================================
// THE STOVE (spouse)
// =========================================================================

/**
 * At the range: a pot on, stirring and tasting, the sound of it. Every HOMESTEAD_COOKS_PER_DISH
 * times, while the kitchen is not already stocked, a dish is carried to the kitchen table.
 */
/datum/ambient_activity/homestead_cook
	name = "cooking"
	var/datum/weakref/stove_ref
	/// world.time the pot is done
	var/done_at = 0
	var/next_stir = 0
	/// Carrying a dish to the table
	var/serving = FALSE
	var/datum/weakref/table_ref

/datum/ambient_activity/homestead_cook/setup()
	var/datum/homestead/homestead = homestead_of(doer)
	var/obj/machinery/oven/range/stove = homestead?.find_fixture(/obj/machinery/oven/range, doer)
	if(!stove)
		return FALSE
	var/turf/stand = doer.free_tile_beside(stove, 1, failed_spots)
	if(!stand)
		return FALSE
	stove_ref = WEAKREF(stove)
	go_to(stand)
	return TRUE

/datum/ambient_activity/homestead_cook/arrive()
	if(serving)
		var/obj/structure/table/table = table_ref?.resolve()
		if(table)
			doer.face_atom(table)
		return
	var/obj/machinery/oven/range/stove = stove_ref?.resolve()
	if(stove)
		doer.face_atom(stove)
	doer.manual_emote(pick("sets a pot on the stove.", "lights the stove."))
	done_at = world.time + rand(50 SECONDS, 90 SECONDS)
	next_stir = world.time + rand(5 SECONDS, 10 SECONDS)

/datum/ambient_activity/homestead_cook/act(seconds)
	if(serving)
		return serve()
	var/obj/machinery/oven/range/stove = stove_ref?.resolve()
	if(QDELETED(stove))
		return AMBIENT_STEP_DONE
	if(world.time < done_at)
		if(world.time >= next_stir)
			next_stir = world.time + rand(8 SECONDS, 16 SECONDS)
			if(prob(50))
				doer.manual_emote(pick("stirs the pot.", "tastes from the spoon.", "adds a pinch of salt.", "turns down the heat."))
			playsound(stove, pick('sound/effects/bubbles/bubbles.ogg', 'sound/effects/bubbles/bubbles2.ogg', 'sound/machines/fryer/deep_fryer_1.ogg'), 20, TRUE, -3)
		chatter("cook", 40 SECONDS, 80 SECONDS)
		return AMBIENT_STEP_CONTINUE
	var/mob/living/basic/ambient_npc/homestead/cook = doer
	cook.cooked++
	var/datum/homestead/homestead = homestead_of(doer)
	if(!homestead || cook.cooked % HOMESTEAD_COOKS_PER_DISH || homestead.count_food(BACKGROUND_HOMESTEAD_FOOD_MIN + 2) >= BACKGROUND_HOMESTEAD_FOOD_MIN + 2)
		return AMBIENT_STEP_DONE
	var/obj/structure/table/table = homestead.kitchen_table(doer)
	var/turf/stand = table && doer.free_tile_beside(table, 1, failed_spots)
	if(!stand)
		return AMBIENT_STEP_DONE
	serving = TRUE
	table_ref = WEAKREF(table)
	doer.set_held(HOMESTEAD_DISH)
	go_to(stand)
	return AMBIENT_STEP_MOVE

/// At the table with the dish: it goes down
/datum/ambient_activity/homestead_cook/proc/serve()
	var/obj/structure/table/table = table_ref?.resolve()
	serving = FALSE
	doer.set_held(null)
	if(QDELETED(table) || !doer.Adjacent(table))
		return AMBIENT_STEP_DONE
	var/obj/item/food/dish = new HOMESTEAD_DISH(table.loc)
	dish.pixel_x = rand(-6, 6)
	dish.pixel_y = rand(0, 6)
	doer.manual_emote("sets a plate on the table.")
	return AMBIENT_STEP_DONE

/datum/ambient_activity/homestead_cook/finish()
	if(!QDELETED(doer))
		doer.set_held(null)
	return ..()

/datum/ambient_activity/homestead_cook/spot_unreachable()
	. = ..()
	serving = FALSE

/datum/ambient_activity/homestead_cook/shift_times(delay)
	. = ..()
	done_at = ambient_shifted(done_at, delay)
	next_stir = ambient_shifted(next_stir, delay)

/// Times at the stove, for the dish every HOMESTEAD_COOKS_PER_DISH
/mob/living/basic/ambient_npc/homestead/var/cooked = 0

/// The kitchen table nearest `near`, or null
/datum/homestead/proc/kitchen_table(atom/near)
	refresh_fixtures()
	var/obj/structure/table/best
	var/best_distance = INFINITY
	for(var/datum/weakref/table_ref as anything in table_refs)
		var/obj/structure/table/table = table_ref.resolve()
		if(QDELETED(table))
			continue
		var/distance = get_dist(table, near)
		if(distance < best_distance)
			best = table
			best_distance = distance
	return best

// =========================================================================
// THE FIELD (spouse)
// =========================================================================

/// Most food the house fridge is filled to from the field; the rest of a harvest goes on the compost
#define HOMESTEAD_LARDER_MAX 15
/// Plots worked in one trip out to the field
#define HOMESTEAD_PLOTS_PER_TRIP 4
/// Nutrient put back into a plot each time it is sown
#define HOMESTEAD_PLOT_NUTRIENT 5

/**
 * Working the field, one plot at a time, up to HOMESTEAD_PLOTS_PER_TRIP plots a trip: a dead or
 * empty plot is cleared and sown again from the homestead's seed stock, a ripe one is harvested and
 * sown again, a dry one is watered from the well. The harvest is carried to the kitchen fridge.
 * Each plot's work is /datum/homestead/proc/tend_plot(), so it can be driven without a walk.
 */
/datum/ambient_activity/homestead_tend
	name = "working the field"
	/// The plot being worked
	var/datum/weakref/plot_ref
	/// "harvest", "replant" or "water"
	var/job
	/// "well", "plot" or "kitchen"
	var/stage = "plot"
	/// Plots still to work this trip
	var/plots_left = HOMESTEAD_PLOTS_PER_TRIP
	/// A bucket drawn from the well
	var/has_water = FALSE
	/// Weakrefs to the harvest they carry
	var/list/datum/weakref/carried = list()
	var/done_at = 0

/datum/ambient_activity/homestead_tend/setup()
	return next_plot()

/datum/ambient_activity/homestead_tend/Destroy()
	plot_ref = null
	carried = null
	return ..()

/// Sets off for the next plot that needs work, or for the kitchen with what they carry. FALSE when there is nothing to do.
/datum/ambient_activity/homestead_tend/proc/next_plot()
	var/datum/homestead/homestead = homestead_of(doer)
	var/list/work = plots_left > 0 ? homestead?.next_field_job(doer, failed_spots) : null
	if(length(work) == 2)
		var/obj/machinery/hydroponics/plot = work[1]
		var/turf/stand = doer.free_tile_beside(plot, 1, failed_spots)
		if(stand)
			plot_ref = WEAKREF(plot)
			job = work[2]
			if(job == "water" && !has_water)
				var/obj/structure/water_source/homestead_well/well = homestead.find_fixture(/obj/structure/water_source/homestead_well, doer)
				var/turf/well_stand = well ? doer.free_tile_beside(well, 1, failed_spots) : null
				if(well_stand)
					stage = "well"
					go_to(well_stand)
					return TRUE
				job = null
			if(job)
				stage = "plot"
				go_to(stand)
				return TRUE
	if(!length(carried))
		return FALSE
	var/obj/machinery/smartfridge/fridge = homestead?.house_fridge()
	var/turf/kitchen_stand = fridge ? doer.free_tile_beside(fridge, 1, failed_spots) : null
	if(!kitchen_stand)
		return FALSE
	stage = "kitchen"
	go_to(kitchen_stand)
	return TRUE

/datum/ambient_activity/homestead_tend/arrive()
	done_at = world.time + rand(3 SECONDS, 5 SECONDS)
	switch(stage)
		if("well")
			var/obj/structure/water_source/homestead_well/well = locate() in range(1, doer)
			if(well)
				doer.face_atom(well)
			doer.manual_emote("draws a bucket from the well.")
			doer.set_held(/obj/item/reagent_containers/cup/bucket/wooden)
			playsound(doer, 'sound/effects/slosh.ogg', 25, TRUE, -3)
			has_water = TRUE
		if("plot")
			var/obj/machinery/hydroponics/plot = plot_ref?.resolve()
			if(plot)
				doer.face_atom(plot)

/datum/ambient_activity/homestead_tend/act(seconds)
	if(world.time < done_at)
		return AMBIENT_STEP_CONTINUE
	var/datum/homestead/homestead = homestead_of(doer)
	if(!homestead)
		return AMBIENT_STEP_DONE
	switch(stage)
		if("well")
			var/obj/machinery/hydroponics/plot = plot_ref?.resolve()
			var/turf/stand = plot ? doer.free_tile_beside(plot, 1, failed_spots) : null
			if(!stand)
				return next_plot() ? AMBIENT_STEP_MOVE : AMBIENT_STEP_DONE
			stage = "plot"
			go_to(stand)
			return AMBIENT_STEP_MOVE
		if("plot")
			var/obj/machinery/hydroponics/plot = plot_ref?.resolve()
			plots_left--
			if(!QDELETED(plot) && doer.Adjacent(plot))
				work_plot(homestead, plot)
			return next_plot() ? AMBIENT_STEP_MOVE : AMBIENT_STEP_DONE
		if("kitchen")
			var/obj/machinery/smartfridge/fridge = homestead.house_fridge()
			if(fridge && doer.Adjacent(fridge))
				doer.face_atom(fridge)
				var/list/harvest = list()
				for(var/datum/weakref/item_ref as anything in carried)
					var/obj/item/food/item = item_ref.resolve()
					if(!QDELETED(item) && item.loc == doer)
						harvest += item
				carried = list()
				doer.set_held(null)
				homestead.store_harvest(harvest)
				doer.manual_emote("puts the harvest away.")
			return AMBIENT_STEP_DONE
	return AMBIENT_STEP_DONE

/// The work at the plot they stand by, and what they do about it out loud
/datum/ambient_activity/homestead_tend/proc/work_plot(datum/homestead/homestead, obj/machinery/hydroponics/plot)
	var/plant_name = plot.myseed?.plantname
	var/list/harvest = homestead.tend_plot(plot, doer, job)
	switch(job)
		if("harvest")
			doer.manual_emote("harvests the [LOWER_TEXT(plant_name || "crop")].")
			for(var/obj/item/food/item in harvest)
				item.forceMove(doer)
				carried += WEAKREF(item)
			if(length(carried))
				var/datum/weakref/first_ref = carried[1]
				doer.set_held(first_ref.resolve())
			if(prob(30))
				doer.speak_context("water")
		if("replant")
			doer.manual_emote("turns the soil and sows a new row.")
		if("water")
			doer.manual_emote("waters the field.")
			playsound(plot, 'sound/effects/slosh.ogg', 25, TRUE, -3)
			has_water = FALSE
			if(!length(carried))
				doer.set_held(null)

/datum/ambient_activity/homestead_tend/finish()
	// Called away: whatever they carry goes down where they stand
	if(!QDELETED(doer))
		var/turf/here = doer.drop_location()
		for(var/datum/weakref/item_ref as anything in carried)
			var/obj/item/item = item_ref.resolve()
			if(!QDELETED(item) && item.loc == doer)
				item.forceMove(here)
		doer.set_held(null)
	carried = list()
	return ..()

/datum/ambient_activity/homestead_tend/spot_unreachable()
	. = ..()
	plot_ref = null
	if(stage != "kitchen")
		plots_left--

/datum/ambient_activity/homestead_tend/shift_times(delay)
	. = ..()
	done_at = ambient_shifted(done_at, delay)

/// The house fridge, or null
/datum/homestead/proc/house_fridge()
	refresh_fixtures()
	var/obj/machinery/smartfridge/fridge = fridge_ref?.resolve()
	return QDELETED(fridge) ? null : fridge

/// What `plot` needs: "replant" (dead, or empty where a crop was sown), "harvest", "water" (dry), or null
/datum/homestead/proc/plot_job(obj/machinery/hydroponics/plot)
	if(plot.plant_status == HYDROTRAY_PLANT_DEAD)
		return "replant"
	if(plot.plant_status == HYDROTRAY_PLANT_HARVESTABLE)
		return "harvest"
	if(!plot.myseed)
		return plot_crops[get_turf(plot)] ? "replant" : null
	if(plot.waterlevel < plot.maxwater / 2)
		return "water"
	return null

/**
 * The plot on the homestead that most needs work, nearest `near` among equals: list(plot, job), or
 * null. Sowing and harvesting come before watering. Plots in `avoid` (unreachable) are skipped.
 */
/datum/homestead/proc/next_field_job(atom/near, list/avoid)
	var/obj/machinery/hydroponics/best
	var/best_job
	var/best_rank = 0
	var/best_distance = INFINITY
	for(var/obj/machinery/hydroponics/plot as anything in fixtures_of(/obj/machinery/hydroponics))
		if(LAZYACCESS(avoid, get_turf(plot)))
			continue
		var/job = plot_job(plot)
		if(!job)
			continue
		var/rank = (job == "water") ? 1 : 2
		var/distance = near ? get_dist(plot, near) : 0
		if(rank > best_rank || (rank == best_rank && distance < best_distance))
			best = plot
			best_job = job
			best_rank = rank
			best_distance = distance
	return best ? list(best, best_job) : null

/**
 * Does `job` (by default what the plot needs) at `plot` for `tender`, at once, the way a player
 * would: a harvest (the seed's own harvest()) drops by the tender and is returned; a cleared or
 * harvested plot is sown again with a fresh seed of its crop from the seed stock.
 */
/datum/homestead/proc/tend_plot(obj/machinery/hydroponics/plot, mob/living/tender, job)
	. = list()
	if(QDELETED(plot))
		return
	job = job || plot_job(plot)
	var/seed_type = plot_crops[get_turf(plot)] || plot.myseed?.type
	switch(job)
		if("harvest")
			if(plot.plant_status != HYDROTRAY_PLANT_HARVESTABLE || !plot.myseed)
				return
			for(var/obj/item/food/item in plot.myseed.harvest(tender))
				. += item
			if(!plot.myseed)
				sow_plot(plot, seed_type)
		if("replant")
			if(plot.myseed)
				plot.set_seed(null)
			sow_plot(plot, seed_type)
		if("water")
			plot.adjust_waterlevel(40)
	plot.update_appearance()

/// Sows a fresh `seed_type` in `plot` as a player planting it does, fed and kept up like the mapped field
/datum/homestead/proc/sow_plot(obj/machinery/hydroponics/plot, seed_type)
	if(!ispath(seed_type, /obj/item/seeds) || plot.myseed)
		return FALSE
	var/obj/item/seeds/seed = new seed_type(plot)
	SEND_SIGNAL(seed, COMSIG_SEED_ON_PLANTED, plot)
	plot.set_seed(seed)
	plot.set_plant_health(seed.endurance)
	plot.lastcycle = world.time
	plot.reagents?.add_reagent(/datum/reagent/plantnutriment/eznutriment, HOMESTEAD_PLOT_NUTRIENT)
	// A harvest switches self-sustaining off (update_tray()); the homestead's own plots keep it, set as the map sets it
	if(plot_crops[get_turf(plot)])
		plot.self_sustaining = TRUE
	plot.update_appearance()
	return TRUE

/// Puts a harvest in the house fridge, up to HOMESTEAD_LARDER_MAX food in it; the rest goes on the compost
/datum/homestead/proc/store_harvest(list/harvest)
	var/obj/machinery/smartfridge/fridge = house_fridge()
	var/stored = 0
	if(fridge)
		for(var/obj/item/food/meal in fridge.contents)
			stored++
	for(var/obj/item/food/item as anything in harvest)
		if(QDELETED(item))
			continue
		if(fridge && stored < HOMESTEAD_LARDER_MAX)
			item.forceMove(fridge)
			stored++
		else
			qdel(item)
	fridge?.update_appearance()

#undef HOMESTEAD_LARDER_MAX
#undef HOMESTEAD_PLOTS_PER_TRIP
#undef HOMESTEAD_PLOT_NUTRIENT

// =========================================================================
// THE ANIMALS (spouse)
// =========================================================================

/**
 * Feed from the barn's crate: one sheaf into the trough, where the cattle find it, and one fed by
 * hand to a hen through her own feeding (/datum/component/egg_layer), so she lays. Nothing to feed
 * with, and they find something else to do.
 */
/datum/ambient_activity/homestead_feed
	name = "feeding the animals"
	/// "fetch", "trough", then "hen"
	var/stage = "fetch"
	var/datum/weakref/target_ref
	/// Weakrefs to the feed they carry
	var/list/datum/weakref/carried = list()
	var/hen_tries = 0

/datum/ambient_activity/homestead_feed/setup()
	var/datum/homestead/homestead = homestead_of(doer)
	var/obj/item/food/grown/wheat/feed = homestead?.find_feed(doer)
	if(!feed)
		return FALSE
	var/turf/stand = doer.free_tile_beside(get_turf(feed), 1, failed_spots) || (doer.standable(get_turf(feed), failed_spots) ? get_turf(feed) : null)
	if(!stand)
		return FALSE
	target_ref = WEAKREF(get_turf(feed))
	go_to(stand)
	return TRUE

/datum/ambient_activity/homestead_feed/Destroy()
	carried = null
	return ..()

/datum/ambient_activity/homestead_feed/act(seconds)
	var/datum/homestead/homestead = homestead_of(doer)
	switch(stage)
		if("fetch")
			var/turf/source = target_ref?.resolve()
			for(var/obj/item/food/grown/wheat/feed as anything in homestead?.feed_at(source))
				feed.forceMove(doer)
				carried += WEAKREF(feed)
				if(length(carried) >= 2)
					break
			if(!length(carried))
				return AMBIENT_STEP_DONE
			doer.set_held(/obj/item/food/grown/wheat)
			doer.manual_emote("takes an armful of feed.")
			var/obj/structure/ore_container/food_trough/trough = homestead.find_fixture(/obj/structure/ore_container/food_trough, doer)
			var/turf/stand = trough && doer.free_tile_beside(trough, 1, failed_spots)
			if(stand)
				stage = "trough"
				target_ref = WEAKREF(trough)
				go_to(stand)
				return AMBIENT_STEP_MOVE
			stage = "hen"
			return find_hen()
		if("trough")
			var/obj/structure/ore_container/food_trough/trough = target_ref?.resolve()
			var/obj/item/feed = take_feed()
			if(feed && !QDELETED(trough) && doer.Adjacent(trough))
				doer.face_atom(trough)
				feed.forceMove(trough.loc)
				feed.pixel_x = rand(-5, 5)
				feed.pixel_y = rand(-4, 5)
				doer.manual_emote("tips feed into [trough].")
			else if(feed)
				carried += WEAKREF(feed)
			stage = "hen"
			return find_hen()
		if("hen")
			var/mob/living/basic/chicken/hen = target_ref?.resolve()
			if(QDELETED(hen) || hen.stat == DEAD)
				return find_hen()
			if(!doer.Adjacent(hen))
				if(++hen_tries > 8)
					return AMBIENT_STEP_DONE
				go_to(get_turf(hen), 1)
				return AMBIENT_STEP_MOVE
			var/obj/item/feed = take_feed()
			if(!feed)
				return AMBIENT_STEP_DONE
			doer.face_atom(hen)
			// The hen's own feeding: she eats it (and lays later), or is full and it goes in the straw
			SEND_SIGNAL(hen, COMSIG_ATOM_ATTACKBY, feed, doer, list(), list())
			if(!QDELETED(feed))
				feed.forceMove(get_turf(hen))
			return AMBIENT_STEP_DONE
	return AMBIENT_STEP_DONE

/// Sets off after the nearest hen
/datum/ambient_activity/homestead_feed/proc/find_hen()
	var/datum/homestead/homestead = homestead_of(doer)
	var/mob/living/basic/chicken/hen = homestead?.find_hen(doer)
	if(!hen || !length(carried))
		return AMBIENT_STEP_DONE
	target_ref = WEAKREF(hen)
	go_to(get_turf(hen), 1)
	return AMBIENT_STEP_MOVE

/// One sheaf of the feed they carry, out of their arms, or null
/datum/ambient_activity/homestead_feed/proc/take_feed()
	while(length(carried))
		var/datum/weakref/feed_ref = carried[1]
		carried.Cut(1, 2)
		var/obj/item/feed = feed_ref.resolve()
		if(!QDELETED(feed) && feed.loc == doer)
			if(!length(carried))
				doer.set_held(null)
			return feed
	doer.set_held(null)
	return null

/datum/ambient_activity/homestead_feed/finish()
	// Whatever is left goes down where they stand
	if(!QDELETED(doer))
		var/turf/here = doer.drop_location()
		for(var/datum/weakref/feed_ref as anything in carried)
			var/obj/item/feed = feed_ref.resolve()
			if(!QDELETED(feed) && feed.loc == doer)
				feed.forceMove(here)
		doer.set_held(null)
	carried = list()
	return ..()

/// A sheaf of wheat in the homestead's crates or lying in the barn, nearest `near`, or null
/datum/homestead/proc/find_feed(atom/near)
	var/obj/item/food/grown/wheat/best
	var/best_distance = INFINITY
	for(var/obj/structure/closet/box as anything in fixtures_of(/obj/structure/closet))
		var/obj/item/food/grown/wheat/feed = (locate(/obj/item/food/grown/wheat) in box.contents) || (locate(/obj/item/food/grown/wheat) in box.loc)
		if(!feed)
			continue
		var/distance = get_dist(box, near)
		if(distance < best_distance)
			best = feed
			best_distance = distance
	return best

/// The wheat at `source`, in a crate there or loose on it
/datum/homestead/proc/feed_at(turf/source)
	. = list()
	if(!isturf(source))
		return
	for(var/obj/structure/closet/box in source)
		for(var/obj/item/food/grown/wheat/feed in box.contents)
			. += feed
	for(var/obj/item/food/grown/wheat/feed in source)
		. += feed

/// The living hen nearest `near` on the homestead, or null
/datum/homestead/proc/find_hen(atom/near)
	var/mob/living/basic/chicken/best
	var/best_distance = INFINITY
	for(var/mob/living/basic/chicken/hen in range(10, near))
		if(hen.stat == DEAD || !contains(hen))
			continue
		var/distance = get_dist(hen, near)
		if(distance < best_distance)
			best = hen
			best_distance = distance
	return best

// =========================================================================
// THE EGGS (children)
// =========================================================================

/// Eggs lying about the coop and the yard, carried to the nesting box
/datum/ambient_activity/homestead_eggs
	name = "gathering eggs"
	var/datum/weakref/target_ref
	var/datum/weakref/egg_ref
	var/datum/weakref/coop_ref

/datum/ambient_activity/homestead_eggs/setup()
	var/datum/homestead/homestead = homestead_of(doer)
	var/obj/structure/homestead_coop/coop = homestead?.find_fixture(/obj/structure/homestead_coop, doer)
	if(!coop)
		return FALSE
	var/obj/item/food/egg/egg = find_egg(coop)
	if(!egg)
		return FALSE
	coop_ref = WEAKREF(coop)
	target_ref = WEAKREF(egg)
	go_to(get_turf(egg), 1)
	return TRUE

/datum/ambient_activity/homestead_eggs/Destroy()
	target_ref = null
	egg_ref = null
	coop_ref = null
	return ..()

/// A loose egg on the homestead near `coop` that they could reach, or null
/datum/ambient_activity/homestead_eggs/proc/find_egg(obj/structure/homestead_coop/coop)
	var/datum/homestead/homestead = homestead_of(doer)
	for(var/obj/item/food/egg/egg in range(8, coop))
		if(!isturf(egg.loc) || LAZYACCESS(failed_spots, egg.loc) || !homestead.contains(egg))
			continue
		return egg
	return null

/datum/ambient_activity/homestead_eggs/act(seconds)
	var/obj/structure/homestead_coop/coop = coop_ref?.resolve()
	if(QDELETED(coop))
		return AMBIENT_STEP_DONE
	var/obj/item/food/egg/carrying = egg_ref?.resolve()
	if(carrying)
		if(!doer.Adjacent(coop))
			return AMBIENT_STEP_DONE
		doer.face_atom(coop)
		doer.set_held(null)
		egg_ref = null
		if(!coop.add_egg(carrying))
			carrying.forceMove(doer.drop_location())
		doer.manual_emote("tucks an egg into the straw.")
		return AMBIENT_STEP_DONE
	var/obj/item/food/egg/egg = target_ref?.resolve()
	if(QDELETED(egg) || !isturf(egg.loc) || !doer.Adjacent(egg))
		return AMBIENT_STEP_DONE
	egg.forceMove(doer)
	egg_ref = WEAKREF(egg)
	doer.set_held(egg)
	var/turf/stand = doer.free_tile_beside(coop, 1, failed_spots)
	if(!stand)
		return AMBIENT_STEP_DONE
	go_to(stand)
	return AMBIENT_STEP_MOVE

/datum/ambient_activity/homestead_eggs/finish()
	var/obj/item/food/egg/carrying = egg_ref?.resolve()
	if(!QDELETED(carrying) && !QDELETED(doer) && carrying.loc == doer)
		carrying.forceMove(doer.drop_location())
	if(!QDELETED(doer))
		doer.set_held(null)
	egg_ref = null
	return ..()

// =========================================================================
// PLAY (children)
// =========================================================================

/**
 * Tag with the other child: whoever is it runs the other one down, calls it, and it is the other's
 * turn after a count of three. Started by one child; the other drops what they were doing and runs.
 */
/datum/ambient_activity/homestead_tag
	name = "playing tag"
	duration_low = 40 SECONDS
	duration_high = 80 SECONDS
	var/datum/weakref/partner_ref
	/// It: chasing the other one
	var/chasing = TRUE
	/// The other side of a game someone else started
	var/responding = FALSE
	/// world.time they may move again after a tag (counting to three)
	var/wait_until = 0

/datum/ambient_activity/homestead_tag/setup()
	var/mob/living/basic/ambient_npc/homestead/partner = anchor()
	if(!istype(partner))
		if(responding)
			return FALSE
		partner = find_playmate()
	if(!partner)
		return FALSE
	partner_ref = WEAKREF(partner)
	if(!responding)
		set_duration()
		var/datum/ambient_activity/homestead_tag/other_side = new(partner, doer)
		other_side.responding = TRUE
		other_side.chasing = FALSE
		other_side.ends_at = ends_at
		if(!partner.start_activity(other_side))
			return FALSE
		doer.speak_context("play", partner, TRUE)
	plan_move()
	return TRUE

/// The other child, awake and free to play, or null
/datum/ambient_activity/homestead_tag/proc/find_playmate()
	var/datum/homestead/homestead = homestead_of(doer)
	for(var/mob/living/basic/ambient_npc/homestead/child/other in homestead?.living_members())
		if(other == doer || !other.can_act() || other.buckled || get_dist(other, doer) > 12)
			continue
		if(other.activity && other.activity.priority >= AMBIENT_PRIORITY_REACTION)
			continue
		if(other.activity && !other.activity.accepts_company && !istype(other.activity, /datum/ambient_activity/idle) && !istype(other.activity, /datum/ambient_activity/wander))
			continue
		return other
	return null

/datum/ambient_activity/homestead_tag/proc/partner()
	var/mob/living/basic/ambient_npc/homestead/partner = partner_ref?.resolve()
	return QDELETED(partner) ? null : partner

/// Where to go next: at the other one if it, away from them if not
/datum/ambient_activity/homestead_tag/proc/plan_move()
	var/mob/living/partner = partner()
	if(!partner)
		go_to(null)
		return
	if(chasing)
		go_to(get_turf(partner), 1)
		return
	var/turf/here = get_turf(doer)
	var/turf/best
	var/best_distance = get_dist(here, partner)
	for(var/attempt in 1 to 6)
		var/turf/tile = doer.random_tile_near(here, 4, failed_spots)
		if(!tile)
			continue
		var/distance = get_dist(tile, partner)
		if(distance > best_distance)
			best = tile
			best_distance = distance
	go_to(best)

/datum/ambient_activity/homestead_tag/act(seconds)
	var/mob/living/basic/ambient_npc/homestead/partner = partner()
	if(!partner || partner.stat != CONSCIOUS)
		return AMBIENT_STEP_DONE
	var/datum/ambient_activity/homestead_tag/their_game = partner.activity
	if(!istype(their_game) || their_game.partner() != doer)
		return AMBIENT_STEP_DONE
	if(world.time < wait_until)
		doer.face_atom(partner)
		return AMBIENT_STEP_CONTINUE
	if(chasing && get_dist(doer, partner) <= 1)
		doer.manual_emote("tags [partner.speech_name()]!")
		doer.speak_context("tag", partner, TRUE)
		chasing = FALSE
		their_game.chasing = TRUE
		their_game.wait_until = world.time + 3 SECONDS
		plan_move()
		return AMBIENT_STEP_MOVE
	plan_move()
	return AMBIENT_STEP_MOVE

/datum/ambient_activity/homestead_tag/spot_unreachable()
	. = ..()
	plan_move()

/datum/ambient_activity/homestead_tag/shift_times(delay)
	. = ..()
	wait_until = ambient_shifted(wait_until, delay)

/// The dog, petted and fussed over
/datum/ambient_activity/homestead_pet_dog
	name = "petting the dog"
	var/datum/weakref/dog_ref
	var/tries = 0
	var/done_at = 0

/datum/ambient_activity/homestead_pet_dog/setup()
	var/datum/homestead/homestead = homestead_of(doer)
	var/mob/living/basic/pet/dog/best
	var/best_distance = INFINITY
	for(var/mob/living/basic/pet/dog/dog in range(12, doer))
		if(dog.stat == DEAD || !homestead?.contains(dog))
			continue
		var/distance = get_dist(dog, doer)
		if(distance < best_distance)
			best = dog
			best_distance = distance
	if(!best)
		return FALSE
	dog_ref = WEAKREF(best)
	go_to(get_turf(best), 1)
	return TRUE

/datum/ambient_activity/homestead_pet_dog/act(seconds)
	var/mob/living/basic/pet/dog/dog = dog_ref?.resolve()
	if(QDELETED(dog) || dog.stat == DEAD)
		return AMBIENT_STEP_DONE
	if(done_at)
		return world.time >= done_at ? AMBIENT_STEP_DONE : AMBIENT_STEP_CONTINUE
	if(!doer.Adjacent(dog))
		if(++tries > 6)
			return AMBIENT_STEP_DONE
		go_to(get_turf(dog), 1)
		return AMBIENT_STEP_MOVE
	doer.face_atom(dog)
	doer.manual_emote(pick("pets [dog].", "scratches [dog] behind the ears.", "hugs [dog]."))
	dog.manual_emote(pick("wags its tail.", "rolls over.", "licks [doer.speech_name()]'s face."))
	done_at = world.time + rand(6 SECONDS, 12 SECONDS)
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/homestead_pet_dog/shift_times(delay)
	. = ..()
	done_at = ambient_shifted(done_at, delay)

// =========================================================================
// SUPPER AND BED
// =========================================================================

/// Nightfall: everyone at the table, one dish or vegetable each from the kitchen, eaten in a few bites
/datum/ambient_activity/homestead_supper
	name = "having supper"
	accepts_company = TRUE
	duration_low = 60 SECONDS
	duration_high = 90 SECONDS
	var/datum/weakref/table_ref
	var/datum/weakref/seat_ref
	var/datum/weakref/meal_ref
	var/bites = 0
	var/next_bite = 0

/datum/ambient_activity/homestead_supper/setup()
	var/datum/homestead/homestead = homestead_of(doer)
	var/obj/structure/table/table = homestead?.kitchen_table(doer)
	if(!table)
		return FALSE
	table_ref = WEAKREF(table)
	var/obj/structure/chair/seat = doer.find_seat(table, 3, TRUE, failed_spots)
	if(seat)
		seat_ref = WEAKREF(seat)
		go_to(get_turf(seat))
	else
		var/turf/stand = doer.free_tile_beside(table, 1, failed_spots)
		if(!stand)
			return FALSE
		go_to(stand)
	set_duration()
	next_line = world.time + rand(10 SECONDS, 20 SECONDS)
	return TRUE

/datum/ambient_activity/homestead_supper/Destroy()
	table_ref = null
	seat_ref = null
	meal_ref = null
	return ..()

/datum/ambient_activity/homestead_supper/arrive()
	var/obj/structure/chair/seat = seat_ref?.resolve()
	if(seat && !doer.sit_on(seat))
		seat_ref = null
	var/obj/structure/table/table = table_ref?.resolve()
	if(table && !doer.buckled)
		doer.face_atom(table)
	var/datum/homestead/homestead = homestead_of(doer)
	var/obj/item/food/meal = homestead?.find_food()
	if(meal)
		meal.forceMove(doer)
		meal_ref = WEAKREF(meal)
		doer.set_held(meal)
		next_bite = world.time + rand(5 SECONDS, 10 SECONDS)

/datum/ambient_activity/homestead_supper/act(seconds)
	var/obj/item/food/meal = meal_ref?.resolve()
	if(meal && world.time >= next_bite)
		next_bite = world.time + rand(8 SECONDS, 15 SECONDS)
		playsound(doer, 'sound/items/eatfood.ogg', 20, TRUE, -4)
		if(++bites >= 3)
			meal_ref = null
			doer.set_held(null)
			qdel(meal)
	chatter("supper", 20 SECONDS, 40 SECONDS)
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/homestead_supper/finish()
	// Called away mid-meal: the plate goes back on the table
	var/obj/item/food/meal = meal_ref?.resolve()
	if(!QDELETED(meal) && !QDELETED(doer) && meal.loc == doer)
		var/obj/structure/table/table = table_ref?.resolve()
		meal.forceMove(table ? table.loc : doer.drop_location())
	meal_ref = null
	if(!QDELETED(doer))
		doer.set_held(null)
	return ..()

/datum/ambient_activity/homestead_supper/shift_times(delay)
	. = ..()
	next_bite = ambient_shifted(next_bite, delay)

/// In their own bed from supper until sunrise
/datum/ambient_activity/homestead_sleep
	name = "asleep"
	var/datum/weakref/bed_ref

/datum/ambient_activity/homestead_sleep/setup()
	var/mob/living/basic/ambient_npc/homestead/sleeper = doer
	var/datum/homestead/homestead = homestead_of(doer)
	var/obj/structure/bed/bed = sleeper.own_bed()
	if(!bed || !homestead)
		return FALSE
	bed_ref = WEAKREF(bed)
	go_to(get_turf(bed))
	ends_at = isnull(homestead.forced_night) ? homestead.next_dawn() : world.time + BACKGROUND_HOMESTEAD_NIGHT_LENGTH
	return TRUE

/datum/ambient_activity/homestead_sleep/arrive()
	var/obj/structure/bed/bed = bed_ref?.resolve()
	var/mob/living/basic/ambient_npc/homestead/sleeper = doer
	if(!bed || doer.loc != bed.loc || (bed.has_buckled_mobs() && !(doer in bed.buckled_mobs)))
		bed_ref = null
		return
	doer.stand_up()
	if(!bed.buckle_mob(doer, force = TRUE))
		bed_ref = null
		return
	doer.manual_emote("climbs into bed.")
	doer.transform = sleeper.lying_transform()

/datum/ambient_activity/homestead_sleep/act(seconds)
	var/obj/structure/bed/bed = bed_ref?.resolve()
	var/datum/homestead/homestead = homestead_of(doer)
	if(!bed || doer.buckled != bed || !homestead?.is_night())
		return AMBIENT_STEP_DONE
	if(prob(2))
		doer.manual_emote(pick("snores softly.", "turns over.", "mumbles in their sleep."))
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/homestead_sleep/finish()
	var/obj/structure/bed/bed = bed_ref?.resolve()
	var/mob/living/basic/ambient_npc/homestead/sleeper = doer
	if(!QDELETED(doer))
		if(bed && doer.buckled == bed)
			bed.unbuckle_mob(doer, force = TRUE)
		if(doer.stat != DEAD)
			doer.transform = sleeper.standing_transform()
	return ..()

/datum/ambient_activity/homestead_sleep/spot_unreachable()
	. = ..()
	bed_ref = null

// =========================================================================
// GREETINGS AND THE CELLAR
// =========================================================================

/// A wave and a homesteader's name, then a few steps over to meet them
/datum/ambient_activity/homestead_greet
	name = "greeting someone"
	priority = AMBIENT_PRIORITY_REACTION
	duration_low = 20 SECONDS
	duration_high = 20 SECONDS
	spot_distance = 2
	/// The line said: "greet" coming home, "welcome" on arrival
	var/context = "greet"

/datum/ambient_activity/homestead_greet/setup()
	var/mob/living/settler = anchor()
	if(!isliving(settler))
		return FALSE
	set_duration()
	if(!doer.buckled)
		doer.face_atom(settler)
	doer.manual_emote(pick("waves.", "looks up and smiles.", "waves you over."))
	doer.speak_context(context, settler, TRUE)
	go_to(get_turf(settler), 2)
	return TRUE

/datum/ambient_activity/homestead_greet/act(seconds)
	var/mob/living/settler = anchor()
	var/turf/there = get_turf(settler)
	if(!settler || settler.stat == DEAD || there?.z != doer.z)
		return AMBIENT_STEP_DONE
	if(get_dist(doer, settler) > 2)
		if(LAZYACCESS(failed_spots, there))
			return AMBIENT_STEP_DONE
		go_to(there, 2)
		return AMBIENT_STEP_MOVE
	if(!doer.buckled)
		doer.face_atom(settler)
	return AMBIENT_STEP_DONE

/**
 * Down in the storm cellar, crouched, while there is danger near the house, and until it has been
 * quiet for HOMESTEAD_CALM_TIME. With no cellar, somewhere indoors; failing that, where they stand.
 */
/datum/ambient_activity/homestead_hide
	name = "hiding"
	priority = AMBIENT_PRIORITY_REACTION
	duration_low = 10 MINUTES
	duration_high = 10 MINUTES

/datum/ambient_activity/homestead_hide/setup()
	set_duration()
	var/datum/homestead/homestead = homestead_of(doer)
	go_to(homestead?.shelter_tile(doer, failed_spots))
	return TRUE

/datum/ambient_activity/homestead_hide/arrive()
	doer.crouch()
	// The first one down bars the door behind them
	var/datum/homestead/homestead = homestead_of(doer)
	if(homestead && istype(get_area(doer), /area/voidcrew/homestead/cellar) && homestead.bar_cellar())
		doer.manual_emote("bars the cellar door.")

/datum/ambient_activity/homestead_hide/act(seconds)
	var/datum/homestead/homestead = homestead_of(doer)
	if(!homestead || (homestead.safe && world.time >= homestead.safe_since + HOMESTEAD_CALM_TIME))
		return AMBIENT_STEP_DONE
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/homestead_hide/spot_unreachable()
	. = ..()
	var/datum/homestead/homestead = homestead_of(doer)
	go_to(homestead?.shelter_tile(doer, failed_spots))

/// Notes the cellar barred from inside for this raid. TRUE the first time.
/datum/homestead/proc/bar_cellar()
	if(!safe && cellar_barred_at > safe_since)
		return FALSE
	cellar_barred_at = world.time
	return TRUE

/// A free tile in the storm cellar for `member`, else indoors, else null (they stay where they are)
/datum/homestead/proc/shelter_tile(mob/living/basic/ambient_npc/homestead/member, list/avoid)
	for(var/area_type in list(/area/voidcrew/homestead/cellar, /area/voidcrew/homestead/house))
		var/area/shelter = GLOB.areas_by_type[area_type]
		if(!shelter)
			continue
		var/list/options = list()
		for(var/turf/tile as anything in shelter.get_turfs_by_zlevel(surface_z))
			if(contains(tile) && member.standable(tile, avoid, TRUE))
				options += tile
		if(length(options))
			return pick(options)
	return null

#undef HOMESTEAD_CHORES
#undef HOMESTEAD_DISH
#undef HOMESTEAD_COOKS_PER_DISH
#undef HOMESTEAD_CALM_TIME
