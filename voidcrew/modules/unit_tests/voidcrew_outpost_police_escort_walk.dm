/// DIAGNOSTIC (temporary): what tg's pull does to a cuffed prisoner at the Undertow's poker tables
/datum/unit_test/voidcrew_outpost_police_escort_diag

/datum/unit_test/voidcrew_outpost_police_escort_diag/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(/obj/structure/overmap/trader_outpost/black_market)
	if(!outpost)
		return
	var/list/found = list()
	for(var/dx in 29 to 33)
		for(var/dy in 17 to 22)
			var/turf/tile = police_outpost_tile(outpost, dx, dy)
			var/list/stuff = list()
			for(var/atom/movable/thing in tile)
				if(thing.density || ismob(thing) || istype(thing, /obj/structure))
					stuff += "[thing.type][thing.density ? "(dense)" : ""]"
			found += "[dx],[dy]: [tile.type] [stuff.Join(" ")]"
	TEST_FAIL("Tiles: [found.Join(" ; ")]")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, where = police_outpost_tile(outpost, 31, 19))
	ADD_TRAIT(officer, TRAIT_AI_PAUSED, "diag")
	var/mob/living/carbon/human/suspect = police_arrest_person(police_outpost_tile(outpost, 32, 20))
	var/obj/item/restraints/handcuffs/cuffs = new(suspect)
	suspect.set_handcuffed(cuffs)
	suspect.update_handcuffed()
	TEST_FAIL("A: [try_step(outpost, officer, suspect, list(31, 19), list(32, 20), list(30, 18))]")
	var/mob/living/carbon/human/bystander = allocate(/mob/living/carbon/human/consistent, police_outpost_tile(outpost, 32, 19))
	TEST_FAIL("B (someone on 32,19): [try_step(outpost, officer, suspect, list(31, 19), list(32, 20), list(30, 18))]")
	bystander.forceMove(police_outpost_tile(outpost, 30, 19))
	TEST_FAIL("B2 (someone on 30,19): [try_step(outpost, officer, suspect, list(31, 19), list(32, 20), list(30, 18))]")
	bystander.forceMove(police_outpost_tile(outpost, 34, 25))
	TEST_FAIL("C: [try_step(outpost, officer, suspect, list(32, 20), list(32, 21), list(31, 19))]")
	TEST_FAIL("D: [try_step(outpost, officer, suspect, list(32, 21), list(31, 22), list(32, 20))]")

/datum/unit_test/voidcrew_outpost_police_escort_diag/proc/try_step(obj/structure/overmap/trader_outpost/outpost, mob/living/officer, mob/living/suspect, list/from, list/held_at, list/to_tile)
	officer.stop_pulling()
	officer.forceMove(police_outpost_tile(outpost, from[1], from[2]))
	suspect.forceMove(police_outpost_tile(outpost, held_at[1], held_at[2]))
	officer.start_pulling(suspect)
	var/held = officer.pulling == suspect
	var/turf/goal = police_outpost_tile(outpost, to_tile[1], to_tile[2])
	var/moved = officer.Move(goal, get_dir(officer, goal))
	var/turf/officer_at = get_turf(officer)
	var/turf/suspect_at = get_turf(suspect)
	var/turf/corner = outpost.template_bottom_left
	return "held=[held] moved=[moved] officer at [officer_at.x - corner.x],[officer_at.y - corner.y] suspect at [suspect_at.x - corner.x],[suspect_at.y - corner.y] still held=[officer.pulling == suspect]"
