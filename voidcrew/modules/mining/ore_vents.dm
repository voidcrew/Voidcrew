/// This datum belongs to the persistent planet, never its disposable surface.
/datum/planet_ore_reserve
	var/sheets_remaining

/datum/planet_ore_reserve/New(zone_type)
	. = ..()
	switch(ordinary_ore_zone(zone_type))
		if(ZONE_YELLOW)
			sheets_remaining = 6000
		if(ZONE_RED)
			sheets_remaining = 10000
		else
			sheets_remaining = 3000

/obj/structure/overmap/planet
	var/datum/planet_ore_reserve/ore_reserve

/obj/structure/overmap/planet/Destroy()
	QDEL_NULL(ore_reserve)
	return ..()

/obj/structure/overmap/planet/proc/get_ore_reserve()
	if(!ore_reserve)
		ore_reserve = new(ore_zone())
	return ore_reserve

/datum/controller/subsystem/ore_generation
	/// Vents that stopped producing but can still have boulders awaiting retrieval.
	var/list/obj/structure/ore_vent/exhausted_vents = list()

/datum/controller/subsystem/ore_generation/fire(resumed)
	. = ..()
	// Exhaustion can make the parent's final produce_boulder() return null.
	available_boulders -= null
	// The parent rebuilds stock from producing vents; exhausted vents only supply existing rocks.
	for(var/obj/structure/ore_vent/vent in exhausted_vents)
		for(var/obj/item/boulder/rock in vent.loc)
			available_boulders |= rock

/obj/structure/ore_vent
	desc = "A fissure in the rock."
	/// Binding is permanent, including if the source is subsequently deleted.
	var/ore_source_bound = FALSE
	var/datum/weakref/ore_source_ref
	/// Unowned vents use a finite green reserve of their own.
	var/datum/planet_ore_reserve/unowned_ore_reserve
	var/boulders_remaining

/obj/structure/ore_vent/Initialize(mapload)
	. = ..()
	bind_ore_reserve()

/obj/structure/ore_vent/Destroy()
	SSore_generation.exhausted_vents -= src
	ore_source_ref = null
	QDEL_NULL(unowned_ore_reserve)
	return ..()

/obj/structure/ore_vent/examine(mob/user)
	. = ..()
	if(!can_produce_ore())
		. += span_notice("The seam is spent.")

/obj/structure/ore_vent/attack_hand(mob/living/user, list/modifiers)
	if(HAS_TRAIT(user, TRAIT_BOULDER_BREAKER) && !can_produce_ore())
		balloon_alert(user, "seam spent")
		return
	return ..()

/obj/structure/ore_vent/proc/bind_ore_reserve()
	if(ore_source_bound)
		return
	ore_source_bound = TRUE
	var/turf/location = get_turf(src)
	var/obj/structure/overmap/planet/source = location ? SSovermap_zones?.get_overmap_object_for_turf(location) : null
	var/zone_type = ZONE_GREEN
	if(istype(source))
		ore_source_ref = WEAKREF(source)
		source.get_ore_reserve()
		zone_type = source.ore_zone()
	else
		unowned_ore_reserve = new(ZONE_GREEN)
	switch(ordinary_ore_zone(zone_type))
		if(ZONE_YELLOW)
			boulders_remaining = 30
		if(ZONE_RED)
			boulders_remaining = 40
		else
			boulders_remaining = 20

/obj/structure/ore_vent/proc/bound_ore_reserve()
	bind_ore_reserve()
	if(unowned_ore_reserve)
		return unowned_ore_reserve
	var/obj/structure/overmap/planet/source = ore_source_ref?.resolve()
	return source?.ore_reserve

/obj/structure/ore_vent/proc/can_produce_ore()
	var/datum/planet_ore_reserve/reserve = bound_ore_reserve()
	if(boulders_remaining <= 0 || !reserve || reserve.sheets_remaining < 1)
		stop_ore_production()
		return FALSE
	return !isnull(get_turf(src))

/// Preserve discovery for vents whose boulders were available during automatic production.
/obj/structure/ore_vent/proc/stop_ore_production()
	if(src in SSore_generation.processed_vents)
		SSore_generation.exhausted_vents |= src
		SSore_generation.processed_vents -= src

/// Truncate to whole sheets of contained material, before refinery efficiency bonuses.
/// No sleeps between rechecking the shared balance, debiting it, and debiting the vent.
/obj/structure/ore_vent/proc/commit_ore_payload(list/materials)
	if(!can_produce_ore())
		return FALSE
	var/datum/planet_ore_reserve/reserve = bound_ore_reserve()
	var/remaining = reserve.sheets_remaining
	var/spent = 0
	for(var/material in materials.Copy())
		var/sheets = min(remaining, max(0, round(materials[material] / SHEET_MATERIAL_AMOUNT)))
		if(!sheets)
			materials -= material
			continue
		materials[material] = sheets * SHEET_MATERIAL_AMOUNT
		remaining -= sheets
		spent += sheets
	if(!spent)
		return FALSE
	reserve.sheets_remaining -= spent
	boulders_remaining--
	if(!boulders_remaining)
		stop_ore_production()
	if(reserve.sheets_remaining < 1)
		for(var/obj/structure/ore_vent/vent in SSore_generation.processed_vents.Copy())
			if(vent.bound_ore_reserve() == reserve)
				vent.stop_ore_production()
	return TRUE

/// The finite allocation pool stores counts, not just membership.
/obj/structure/ore_vent/proc/take_vent_allocation(list/pool)
	for(var/material in pool.Copy())
		if(pool[material] <= 0)
			pool -= material
	if(!length(pool))
		return null
	var/material = pick_weight(pool)
	pool[material]--
	if(pool[material] <= 0)
		pool -= material
	return material

/obj/structure/ore_vent/proc/select_vent_mineral(map_loading)
	var/list/pool = SSore_generation.ore_vent_minerals
	for(var/material in pool.Copy())
		if(pool[material] <= 0)
			pool -= material
	var/list/available = map_loading ? pool.Copy() : GLOB.ore_vent_minerals_lavaland.Copy()
	available -= mineral_breakdown
	if(length(available))
		var/material = pick_weight(available)
		if(map_loading)
			pool[material]--
			if(pool[material] <= 0)
				pool -= material
		return material
	if(!map_loading || !length(pool))
		return null
	// This vent already contains every remaining allocation. Spend one allocation,
	// but obtain its additional material from the weighted fallback pool.
	var/list/fallback = GLOB.ore_vent_minerals_lavaland.Copy()
	fallback -= mineral_breakdown
	if(!length(fallback))
		return null
	take_vent_allocation(pool)
	return pick_weight(fallback)
