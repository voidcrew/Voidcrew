/**
 * Outpost police tests: the heavy weapons officers (voidcrew/modules/outpost_police/police_units_heavy.dm, owner
 * decision 62). Helpers are in voidcrew_outpost_police_helpers.dm, _arrest.dm, _dispatch.dm, _stun_squad.dm and
 * _units.dm. Fork defines are included after the tests: literal values, with the define named.
 *
 * Heat 150 is five stars, 30 two (OUTPOST_POLICE_STAR_HEAT 10, 25, 50, 90, 140). Force 3 is POLICE_FORCE_LETHAL.
 * Unit kind "armour" is POLICE_UNIT_ARMOUR.
 */

/// The three heavy weapons officer types, in dispatch order (POLICE_HEAVY_ION, _ROCKET, _GRENADE)
/datum/unit_test/proc/heavy_types()
	return list(
		/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour,
		/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/rocket,
		/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/grenade,
	)

/// `length` free concourse tiles in a straight line, or null
/datum/unit_test/proc/heavy_line(obj/structure/overmap/trader_outpost/outpost, length)
	for(var/i in 1 to 80)
		var/turf/start = police_floor(outpost)
		if(!dispatch_free(outpost, start))
			continue
		for(var/direction in GLOB.cardinals)
			var/list/turf/line = list(start)
			var/turf/next = start
			for(var/step in 2 to length)
				next = get_step(next, direction)
				if(!dispatch_free(outpost, next))
					break
				line += next
			if(length(line) == length)
				return line
	return null

/// Deletes every living thing within `radius` of `center` that is not in `keep`, so a blast test sees only its own cast
/datum/unit_test/proc/heavy_clear_around(turf/center, radius, list/keep)
	for(var/turf/tile as anything in RANGE_TURFS(radius, center))
		for(var/mob/living/other in tile.get_all_contents())
			if(!(other in keep))
				qdel(other)

/// Waits out any action the officer is in the middle of (a stow or a draw)
/datum/unit_test/proc/heavy_settle(mob/living/officer)
	for(var/i in 1 to 20)
		if(!LAZYLEN(officer.do_afters))
			return
		sleep(0.5 SECONDS)

/// Whether `officer`'s trigger would let `gun` fire at `target`
/datum/unit_test/proc/heavy_trigger_ok(mob/living/officer, obj/item/gun/gun, atom/target)
	return !(SEND_SIGNAL(officer, COMSIG_MOB_TRYING_TO_FIRE_GUN, gun, target, FALSE, null) & COMPONENT_CANCEL_GUN_FIRE)

/// Five stars bring a heavy weapons team of two after the marshal, inside the caps, in rotation
/datum/unit_test/voidcrew_outpost_police_heavy_dispatch

/datum/unit_test/voidcrew_outpost_police_heavy_dispatch/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	police.dispatch_build_now = TRUE
	dispatch_two_lifts(outpost)
	var/mob/living/suspect = dispatch_suspect(outpost)

	// Below five stars: none
	dispatch_clear(police)
	police_pin_warrant(police, suspect.mind, 100) // four stars
	for(var/i in 1 to 12)
		police.dispatch_next_wave = 0
		police.tick_dispatch()
	TEST_ASSERT_EQUAL(dispatch_count(police, "armour"), 0, "Four stars brought heavy weapons officers")

	// Five stars: the marshal first, then the team, then the tactical officers
	dispatch_clear(police)
	police.dispatch_heavy_next = 1 // POLICE_HEAVY_ION
	police_pin_warrant(police, suspect.mind, 150) // five stars
	TEST_ASSERT_EQUAL(police.dispatch_next_kind(5), "marshal", "Five stars did not ask for the marshal first")
	for(var/i in 1 to 12)
		police.dispatch_next_wave = 0
		police.tick_dispatch()
	TEST_ASSERT_EQUAL(dispatch_count(police), 10, "Five stars did not top the scene up to ten") // OUTPOST_POLICE_UNITS[5]
	TEST_ASSERT_EQUAL(dispatch_count(police, "armour"), 2, "Five stars did not bring a heavy weapons team of two") // OUTPOST_POLICE_ARMOUR_TEAM
	TEST_ASSERT_EQUAL(dispatch_count(police, "marshal"), 1, "Five stars did not bring the marshal")
	TEST_ASSERT_EQUAL(dispatch_count(police, "tactical"), 4, "The heavy weapons team cost the tactical officers their places")
	TEST_ASSERT(dispatch_count(police) <= 12, "Five stars went over the outpost's cap") // OUTPOST_POLICE_CAP_OUTPOST
	var/has_ion = FALSE
	var/has_rocket = FALSE
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in police.officers)
		if(officer.type == /mob/living/carbon/human/npc/ambient_npc/outpost/police/armour)
			has_ion = TRUE
		if(officer.type == /mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/rocket)
			has_rocket = TRUE
	TEST_ASSERT(has_ion && has_rocket, "The first team was not an ion rifle and a rocket launcher")
	TEST_ASSERT_EQUAL(police.dispatch_heavy_type(), /mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/grenade, "The third heavy weapons officer does not bring the grenade launcher")

	// The caps hold for them too
	dispatch_clear(police)
	var/turf/floor = police_floor(outpost)
	var/list/fillers = list()
	for(var/i in 1 to 12) // OUTPOST_POLICE_CAP_OUTPOST
		var/datum/human_npc_order/filler = new /datum/human_npc_order(/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, floor)
		police.dispatch_orders[filler] = "officer"
		fillers += filler
	TEST_ASSERT_NULL(police.order_unit("armour", "concourse"), "A heavy weapons officer was ordered with the outpost full")
	for(var/datum/human_npc_order/filler as anything in fillers)
		qdel(filler)
	dispatch_clear(police)

/// Each loadout in each zone: its weapon and rounds, the sidearm, all locked to the body; lethal, and titled for players
/datum/unit_test/voidcrew_outpost_police_heavy_kit

/datum/unit_test/voidcrew_outpost_police_heavy_kit/Run()
	var/list/types = heavy_types()
	for(var/outpost_type in police_units_zones())
		var/obj/structure/overmap/trader_outpost/outpost = police_units_room_outpost(outpost_type)
		var/datum/outpost_police_profile/profile = outpost.police.profile
		for(var/loadout in 1 to 3)
			var/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/officer = allocate(types[loadout], run_loc_floor_bottom_left)
			var/label = "[officer.type] at [outpost_type]"
			TEST_ASSERT_EQUAL(officer.unit_kind, "armour", "[label] is not a heavy weapons officer")
			TEST_ASSERT_EQUAL(officer.outfit, profile.heavy_outfits[loadout], "[label] was not given the zone's heavy outfit")
			var/datum/outfit/outfit = new officer.outfit
			police_units_check_outfit(officer, outfit, label)
			TEST_ASSERT_EQUAL(officer.wear_suit?.type, initial(outfit.suit), "[label] is not in the zone's armour")
			TEST_ASSERT(findtext(officer.desc, "Heavy weapons officer"), "[label] is not called a heavy weapons officer ([officer.desc])")
			TEST_ASSERT_EQUAL(outpost.police.role_of(officer), "lethal", "[label] was given a stun role") // POLICE_ROLE_LETHAL
			var/obj/item/gun/heavy = officer.get_heavy()
			var/obj/item/gun/energy/sidearm = officer.get_sidearm()
			TEST_ASSERT(istype(sidearm, /obj/item/gun/energy/e_gun/mini), "[label]'s sidearm is [sidearm], not the miniature energy gun")
			TEST_ASSERT(human_npc_gear_locked(heavy), "[label]'s [heavy] is not locked to them")
			TEST_ASSERT(human_npc_gear_locked(sidearm), "[label]'s sidearm is not locked to them")
			for(var/obj/item/thing as anything in police_units_gear(officer))
				TEST_ASSERT(human_npc_gear_locked(thing) || human_npc_gear_consumable(thing), "[label]'s [thing] is not locked to them")
			for(var/obj/item/ammo_casing/round in officer.get_all_contents())
				if(is_type_in_typecache(round, GLOB.outpost_police_heavy_ammo))
					TEST_ASSERT(human_npc_gear_consumable(round), "[label]'s [round] is not issued as a consumable")
			switch(loadout)
				if(1) // POLICE_HEAVY_ION
					TEST_ASSERT(istype(heavy, /obj/item/gun/energy/ionrifle), "[label] carries [heavy], not an ion rifle")
					TEST_ASSERT_EQUAL(officer.back, heavy, "[label]'s ion rifle is not on their back")
					var/obj/item/gun/energy/ion = heavy
					TEST_ASSERT(ion.can_shoot() && ion.cell.charge == ion.cell.maxcharge, "[label]'s ion rifle is not charged")
				if(2) // POLICE_HEAVY_ROCKET
					var/obj/item/gun/ballistic/rocketlauncher/launcher = heavy
					TEST_ASSERT(istype(launcher), "[label] carries [heavy], not a rocket launcher")
					TEST_ASSERT_EQUAL(officer.s_store, launcher, "[label]'s rocket launcher is not in suit storage")
					TEST_ASSERT(launcher.can_shoot(), "[label]'s rocket launcher is not loaded")
					TEST_ASSERT(!launcher.backblast, "[label]'s rocket launcher has a backblast")
					TEST_ASSERT_EQUAL(length(officer.back?.get_all_contents_type(/obj/item/ammo_casing/rocket)), 2, "[label] does not carry two spare rockets") // OUTPOST_POLICE_HEAVY_ROCKETS
				if(3) // POLICE_HEAVY_GRENADE
					var/obj/item/gun/ballistic/revolver/grenadelauncher/launcher = heavy
					TEST_ASSERT(istype(launcher), "[label] carries [heavy], not a grenade launcher")
					TEST_ASSERT_EQUAL(officer.s_store, launcher, "[label]'s grenade launcher is not in suit storage")
					TEST_ASSERT(launcher.can_shoot(), "[label]'s grenade launcher is not loaded")
					TEST_ASSERT_EQUAL(length(officer.back?.get_all_contents_type(/obj/item/ammo_casing/a40mm)), 5, "[label] does not carry five spare shells") // OUTPOST_POLICE_HEAVY_SHELLS
			qdel(officer)
		qdel(outpost)

/// The blast radii the officers judge by match the explosions the rounds really make
/datum/unit_test/voidcrew_outpost_police_heavy_radius
	/// The widest reach of the last explosion caught on the dummy
	var/caught_radius = -1

/datum/unit_test/voidcrew_outpost_police_heavy_radius/proc/catch_explosion(datum/source, list/arguments)
	SIGNAL_HANDLER
	caught_radius = max(arguments[EXARG_KEY_DEV_RANGE], arguments[EXARG_KEY_HEAVY_RANGE], arguments[EXARG_KEY_LIGHT_RANGE], arguments[EXARG_KEY_FLAME_RANGE] || 0)
	return COMSIG_CANCEL_EXPLOSION

/datum/unit_test/voidcrew_outpost_police_heavy_radius/Run()
	var/obj/structure/chair/dummy = allocate(/obj/structure/chair, run_loc_floor_bottom_left)
	RegisterSignal(dummy, COMSIG_ATOM_EXPLODE, PROC_REF(catch_explosion))
	// A rocket that hits a mech (not a living thing)
	var/obj/projectile/bullet/rocket/rocket = allocate(/obj/projectile/bullet/rocket, run_loc_floor_bottom_left)
	rocket.do_boom(dummy)
	TEST_ASSERT_EQUAL(caught_radius, outpost_police_blast_radius(/obj/projectile/bullet/rocket), "A rocket's real blast does not match the radius the officers judge by")
	caught_radius = -1
	var/obj/projectile/bullet/a40mm/shell = allocate(/obj/projectile/bullet/a40mm, run_loc_floor_bottom_left)
	shell.on_hit(dummy)
	TEST_ASSERT_EQUAL(caught_radius, outpost_police_blast_radius(/obj/projectile/bullet/a40mm), "A 40mm shell's real blast does not match the radius the officers judge by")
	TEST_ASSERT_EQUAL(outpost_police_blast_radius(/obj/projectile/ion), /obj/projectile/ion::emp_radius, "The ion bolt's radius is not its EMP's")
	TEST_ASSERT(outpost_police_blast_radius(/obj/projectile/bullet/rocket) > 0, "A rocket has no blast radius")
	UnregisterSignal(dummy, COMSIG_ATOM_EXPLODE)

/**
 * The rules of fire: the heavy weapon for a mech with a wanted pilot and a clear blast, held for a bystander in the
 * blast, never at someone on foot (the sidearm instead), and the sidearm once the launcher is dry.
 */
/datum/unit_test/voidcrew_outpost_police_heavy_fire

/datum/unit_test/voidcrew_outpost_police_heavy_fire/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	police.sleep_tick()
	stun_squad_isolate(police)
	var/list/turf/line = heavy_line(outpost, 6)
	if(!line)
		TEST_FAIL("No six free tiles in a row on the concourse")
		return
	var/turf/near = line[1]
	var/turf/far = line[6]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/rocket, near)
	var/mob/living/carbon/human/suspect = police_arrest_person(far)
	police_pin_warrant(police, suspect.mind, 150) // five stars
	var/obj/vehicle/sealed/mecha/ripley/mech = allocate(/obj/vehicle/sealed/mecha/ripley, far)
	mech.mob_enter(suspect, silent = TRUE)
	heavy_clear_around(far, 7, list(officer, suspect))
	heavy_clear_around(near, 2, list(officer, suspect))
	var/datum/ai_controller/brain = officer.ai_controller
	var/obj/item/gun/heavy = officer.get_heavy()

	// 1. A mech with a five-star pilot and nobody about: the rocket launcher
	brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, mech)
	TEST_ASSERT_EQUAL(officer.force_for(mech), 3, "A heavy weapons officer is not at lethal force on a five-star mech")
	TEST_ASSERT_EQUAL(officer.get_longgun(), heavy, "A heavy weapons officer would not use the launcher on a five-star mech")
	officer.set_force(3) // POLICE_FORCE_LETHAL
	heavy_settle(officer)
	TEST_ASSERT(officer.is_holding(heavy), "A heavy weapons officer did not draw the launcher for a mech (held [english_list(officer.held_items)])")
	TEST_ASSERT_EQUAL(officer.police_loaded_gun_for(3), heavy, "The launcher is not the gun ready for a mech")
	TEST_ASSERT_NULL(officer.bystander_in_line(mech), "A clear shot at a mech was held for [officer.bystander_in_line(mech)]")
	TEST_ASSERT(heavy_trigger_ok(officer, heavy, mech), "The trigger refused a clear shot at a mech")
	TEST_ASSERT(police_plans_shot(officer, mech), "No shot was planned at a five-star mech")

	// 2. Someone clean beside the mech: no rocket, and the officer holds fire
	var/turf/beside
	for(var/direction in GLOB.cardinals)
		var/turf/candidate = get_step(far, direction)
		if(candidate && !(candidate in line) && isopenturf(candidate) && !candidate.is_blocked_turf(exclude_mobs = FALSE))
			beside = candidate
			break
	if(beside)
		brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, mech)
		var/mob/living/carbon/human/bystander = police_arrest_person(beside)
		TEST_ASSERT_EQUAL(officer.bystander_in_line(mech), bystander, "A rocket would be fired with a clean bystander beside the mech")
		TEST_ASSERT(!heavy_trigger_ok(officer, heavy, mech), "The trigger let a rocket go with a bystander in the blast")
		// A two-star player is not someone they shoot to kill either
		police_pin_warrant(police, bystander.mind, 30) // two stars
		TEST_ASSERT(!heavy_trigger_ok(officer, heavy, mech), "The trigger let a rocket go with a two-star player in the blast")
		qdel(bystander)
		// Nor another officer
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/colleague = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, beside)
		TEST_ASSERT(!heavy_trigger_ok(officer, heavy, mech), "The trigger let a rocket go with an officer in the blast")
		qdel(colleague)
		TEST_ASSERT(heavy_trigger_ok(officer, heavy, mech), "The trigger still refused once the blast was clear")
	else
		TEST_FAIL("Fixture: no free tile beside the mech")

	// 3. The officer inside their own blast: they hold, and step back
	var/turf/close = line[3]
	officer.forceMove(close)
	TEST_ASSERT_EQUAL(officer.bystander_in_line(mech), officer, "A heavy weapons officer would fire into their own blast")
	officer.forceMove(near)

	// 4. The pilot on foot: never the launcher, the sidearm instead
	mech.mob_exit(suspect, silent = TRUE)
	suspect.forceMove(far)
	qdel(mech)
	brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, suspect)
	TEST_ASSERT_NULL(officer.get_longgun(), "A heavy weapons officer would use the launcher on someone on foot")
	TEST_ASSERT(officer.police_heavy_barred(suspect), "The launcher is not barred against someone on foot")
	officer.set_force(3) // POLICE_FORCE_LETHAL
	heavy_settle(officer)
	var/obj/item/gun/energy/sidearm = officer.get_sidearm()
	TEST_ASSERT(!officer.is_holding(heavy), "A heavy weapons officer kept the launcher out for someone on foot")
	TEST_ASSERT(officer.is_holding(sidearm), "A heavy weapons officer did not draw the sidearm for someone on foot (held [english_list(officer.held_items)])")
	TEST_ASSERT_EQUAL(officer.police_loaded_gun_for(3), sidearm, "The sidearm is not the gun ready for someone on foot")
	TEST_ASSERT(!heavy_trigger_ok(officer, heavy, suspect), "The trigger would let a rocket go at someone on foot")

	// 5. A dry launcher with nothing to load: the sidearm, even for a mech
	var/obj/vehicle/sealed/mecha/ripley/second_mech = allocate(/obj/vehicle/sealed/mecha/ripley, far)
	second_mech.mob_enter(suspect, silent = TRUE)
	brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, second_mech)
	var/obj/item/gun/ballistic/launcher = heavy
	for(var/obj/item/ammo_casing/round in officer.get_all_contents())
		if(round.loc != launcher.magazine && round != launcher.chambered)
			qdel(round)
	for(var/obj/item/ammo_casing/round in launcher.magazine.stored_ammo)
		qdel(round)
	launcher.magazine.stored_ammo.Cut()
	launcher.chambered = null
	TEST_ASSERT(!launcher.can_shoot(), "Fixture: the emptied launcher still fires")
	officer.set_force(3) // POLICE_FORCE_LETHAL
	heavy_settle(officer)
	TEST_ASSERT_EQUAL(officer.police_loaded_gun_for(3), sidearm, "With a dry launcher the officer has no sidearm ready for a mech (held [english_list(officer.held_items)])")
	TEST_ASSERT(!officer.is_holding(launcher), "A heavy weapons officer kept a dry launcher out")
	second_mech.mob_exit(suspect, silent = TRUE)
	qdel(second_mech)
	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)

	// 6. The ion rifle's EMP reaches a tile: someone beside the mech holds it too
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/ion_officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/armour, near)
	var/obj/vehicle/sealed/mecha/ripley/third_mech = allocate(/obj/vehicle/sealed/mecha/ripley, far)
	third_mech.mob_enter(suspect, silent = TRUE)
	ion_officer.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, third_mech)
	var/obj/item/gun/ion = ion_officer.get_heavy()
	TEST_ASSERT(heavy_trigger_ok(ion_officer, ion, third_mech), "The trigger refused a clear ion shot at a mech")
	if(beside)
		var/mob/living/carbon/human/emp_bystander = police_arrest_person(beside)
		TEST_ASSERT(!heavy_trigger_ok(ion_officer, ion, third_mech), "The trigger let an ion bolt go with a bystander in the EMP")
		qdel(emp_bystander)
	third_mech.mob_exit(suspect, silent = TRUE)
	qdel(third_mech)
	police_pin_warrant(police, suspect.mind, 0)
	dispatch_clear(police)

/// Killed and gibbed, a heavy weapons officer leaves nothing a player can hold: no launcher, rifle or round
/datum/unit_test/voidcrew_outpost_police_heavy_death

/datum/unit_test/voidcrew_outpost_police_heavy_death/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_units_room_outpost(/obj/structure/overmap/trader_outpost/general)
	var/turf/spot = run_loc_floor_bottom_left
	var/list/officers = list()
	for(var/officer_type in heavy_types())
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/officer = allocate(officer_type, spot)
		officers += officer
		officer.apply_damage(officer.maxHealth * 2, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
		TEST_ASSERT_EQUAL(officer.stat, DEAD, "A [officer_type] did not die of their wounds")
		for(var/obj/item/thing as anything in police_units_gear(officer))
			TEST_ASSERT(HAS_TRAIT(thing, TRAIT_NO_STRIP), "A dead [officer_type]'s [thing] can be stripped")
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in officers)
		officer.gib()
	sleep(2 SECONDS) // locked gear off its body is deleted on the next tick (human_npc_gear.dm)
	for(var/obj/item/loose in view(3, spot))
		if(is_type_in_typecache(loose, GLOB.outpost_police_heavy_guns) || istype(loose, /obj/item/gun/energy/e_gun/mini))
			TEST_FAIL("A gibbed heavy weapons officer left [loose] lying about")
		var/obj/item/ammo_casing/round = loose
		if(istype(round) && round.loaded_projectile && is_type_in_typecache(round, GLOB.outpost_police_heavy_ammo))
			TEST_FAIL("A gibbed heavy weapons officer left a live [round] lying about")
	qdel(outpost)
