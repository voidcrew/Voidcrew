/**
 * The changeling experiment: the host's incubation and burst, the headslug and the sealed vents,
 * the horror's emergence, its kit and its absorb, its regeneration, spacing it and burning it, and
 * what keeps it on the outpost and inside the wing's outer ring.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. The prison's own clock is stopped (prison_test_claim()), and so is the
 * event's: tests drive it with tick(). Nobody is on the level, so no AI runs and the tests do what
 * the slug's and the horror's minds would. Coordinates are the unrotated wing's authored ones
 * (1,1 is its south-west corner): cell 1 is x 2-4, y 13-15 with its bed at (2,15) and its vent at
 * (4,14); the yard vents are (2,10) and (16,10) and the office vent (13,3). Fixtures are in
 * voidcrew_outpost_prison_helpers.dm.
 */

/**
 * A host on their bunk (cell 1's by default) with the specimen in them, and the event's own clock
 * stopped. Through S4a's start_experiment() when the experiments core is in, as the specimen jar
 * does, so its experiment_paused() sees an experiment under way.
 */
/datum/unit_test/voidcrew_outpost_management/proc/changeling_host(datum/outpost_prison/prison, obj/structure/overmap/dynamic/player_outpost/home, x = 2, y = 15)
	var/mob/living/basic/outpost_prisoner/host = test_prisoner(prison, prison_spot(home, x, y))
	var/datum/outpost_changeling_event/event
	if(hascall(prison, "start_experiment"))
		call(prison, "start_experiment")("changeling", host, TRUE)
		event = prison.active_changeling
		if(event?.host != host)
			event = null
	else
		event = outpost_changeling_infect(host, prison)
	event?.stop_self_ticking()
	return event

/// The wing's sealed vent at an authored tile
/datum/unit_test/voidcrew_outpost_management/proc/changeling_vent(obj/structure/overmap/dynamic/player_outpost/home, x, y)
	return locate(/obj/structure/outpost_kessler_vent) in prison_spot(home, x, y)

/// Ticks `event` a second at a time for `seconds`
/datum/unit_test/voidcrew_outpost_management/proc/changeling_ticks(datum/outpost_changeling_event/event, seconds)
	for(var/i in 1 to seconds)
		event.tick(1)

/// A burst slug, put straight into the vent at an authored tile, as its mind would
/datum/unit_test/voidcrew_outpost_management/proc/changeling_in_vent(datum/outpost_changeling_event/event, obj/structure/overmap/dynamic/player_outpost/home, x, y)
	if(event.stage == "incubating")
		event.force_stage("burst")
	var/obj/structure/outpost_kessler_vent/vent = changeling_vent(home, x, y)
	event.slug.forceMove(get_turf(vent))
	return event.slug_reached_vent(event.slug, vent) ? vent : null

// ===== THE HOST AND THE BURST =====

/datum/unit_test/voidcrew_outpost_prison_changeling_burst
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_changeling_burst/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("burstowner")
	TEST_ASSERT_NOTNULL(home, "The burst test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.crew_home_override = TRUE
	var/datum/outpost_changeling_event/event = changeling_host(prison, home)
	TEST_ASSERT_NOTNULL(event, "The specimen did not take")
	var/mob/living/basic/outpost_prisoner/host = event.host
	TEST_ASSERT(host.experiment_subject, "The host is not marked as the experiment's subject")
	TEST_ASSERT_EQUAL(host.bubble, "experiment", "The host does not show the syringe bubble")
	TEST_ASSERT_EQUAL(event.stage, "incubating", "A fresh specimen is not incubating")
	TEST_ASSERT(event.incubation_total >= 90 && event.incubation_total <= 120, "Incubation rolled [event.incubation_total] s, not 90-120") // OUTPOST_CHANGELING_INCUBATION_MIN/_MAX
	TEST_ASSERT_NULL(outpost_changeling_infect(host, prison), "A second specimen took while one was incubating")
	event.incubation_total = 100
	event.tick(0)
	TEST_ASSERT_EQUAL(event.time_left, 100, "The console clock reads [event.time_left], not 100")

	// Nobody home: the clock waits.
	prison.crew_home_override = FALSE
	changeling_ticks(event, 30)
	TEST_ASSERT_EQUAL(event.incubation_elapsed, 0, "Incubation ran [event.incubation_elapsed] s with nobody home")
	TEST_ASSERT_EQUAL(event.time_left, 100, "A paused clock read [event.time_left]")
	prison.crew_home_override = TRUE

	// Stomach pain at 30 seconds, then the bunk 22.5 seconds before the burst.
	changeling_ticks(event, 30) // OUTPOST_CHANGELING_TELL_PAIN
	TEST_ASSERT(event.said_pain, "The host had no stomach pain at 30 s")
	host.sentence_left = 30
	changeling_ticks(event, 47)
	TEST_ASSERT(host.sentence_left >= 600, "The host's sentence ran down to [host.sentence_left] while incubating") // OUTPOST_CHANGELING_HOST_SENTENCE_HOLD
	TEST_ASSERT(!event.bed_phase, "The host went to bed [100 - event.incubation_elapsed] s early")
	changeling_ticks(event, 1) // 78, the first whole second past 100 - OUTPOST_CHANGELING_BED_WARNING (22.5)
	TEST_ASSERT(event.bed_phase, "The host did not go to bed 22.5 s before the burst")
	changeling_ticks(event, 1)
	TEST_ASSERT(event.host_down && host.can_be_dragged(), "The host on their bunk is not down and draggable")
	changeling_ticks(event, 20)
	TEST_ASSERT_EQUAL(event.stage, "incubating", "The host burst at [event.incubation_elapsed] s, not 100")

	// The burst: gore, and a headslug on the bunk.
	var/turf/bunk = get_turf(host)
	changeling_ticks(event, 1)
	TEST_ASSERT_EQUAL(event.stage, "burst", "The host did not burst at 100 s")
	TEST_ASSERT(QDELETED(host), "The host is still in one piece after the burst")
	TEST_ASSERT(istype(event.slug, /mob/living/basic/headslug/beakless/outpost), "No headslug came out")
	TEST_ASSERT_EQUAL(get_turf(event.slug), bunk, "The headslug did not come out where the host burst")
	TEST_ASSERT(!ismegafauna(event.slug), "The headslug counts as megafauna")
	TEST_ASSERT(!HAS_TRAIT(event.slug, TRAIT_VENTCRAWLER_ALWAYS), "The headslug can crawl tg's own vents")
	TEST_ASSERT(event.slug.egg_lain, "The headslug can lay an egg")
	TEST_ASSERT(event.slug.sentience_type != 1, "The headslug takes sentience potions") // SENTIENCE_ORGANIC
	var/gore = 0
	for(var/turf/near as anything in RANGE_TURFS(1, bunk))
		for(var/obj/effect/decal/cleanable/blood/mess in near)
			gore++
	TEST_ASSERT(gore >= 3, "The burst left [gore] blood decals, not a mess")
	var/logged = FALSE
	for(var/list/entry as anything in prison.entries)
		if(findtext(entry["text"], "burst"))
			logged = TRUE
	TEST_ASSERT(logged, "The warden's log did not record the burst")

	// Killing the slug ends it.
	var/mob/living/basic/headslug/beakless/outpost/slug = event.slug
	slug.death()
	TEST_ASSERT_EQUAL(event.stage, "done", "Killing the headslug did not end the experiment")
	TEST_ASSERT_NULL(event.slug, "A finished experiment kept its slug")

	// A host killed early bursts three seconds later anyway, whoever is home.
	var/datum/outpost_changeling_event/early = changeling_host(prison, home, 6, 15)
	TEST_ASSERT_NOTNULL(early, "A second specimen did not take once the first was done")
	var/mob/living/basic/outpost_prisoner/early_host = early.host
	early_host.death()
	TEST_ASSERT_EQUAL(early.stage, "incubating", "A host killed early burst at once")
	TEST_ASSERT_EQUAL(early.early_burst_left, 3, "A host killed early bursts in [early.early_burst_left] s, not 3") // OUTPOST_CHANGELING_EARLY_BURST
	prison.crew_home_override = FALSE
	changeling_ticks(early, 2)
	TEST_ASSERT_EQUAL(early.stage, "incubating", "A dead host burst after 2 s")
	changeling_ticks(early, 1)
	TEST_ASSERT_EQUAL(early.stage, "burst", "A dead host did not burst 3 s after dying")
	TEST_ASSERT(!QDELETED(early.slug), "No headslug came out of the dead host")
	early.force_stage("done")
	TEST_ASSERT(QDELETED(early.slug) || isnull(early.slug), "An ended experiment left its slug behind")
	prison.crew_home_override = TRUE

	// A host kept out of the cell block for a minute: the specimen is lost, and the host is let off.
	var/datum/outpost_changeling_event/lost = changeling_host(prison, home, 10, 15)
	var/mob/living/basic/outpost_prisoner/lost_host = lost.host
	lost_host.forceMove(prison_spot(home, 12, 3))
	TEST_ASSERT(!prison.in_cell_block(lost_host), "The office counts as the cell block")
	// Nobody home: that clock waits too.
	prison.crew_home_override = FALSE
	changeling_ticks(lost, 90)
	TEST_ASSERT_EQUAL(lost.stage, "incubating", "The specimen was lost while nobody was home")
	TEST_ASSERT_EQUAL(lost.host_outside, 0, "The host's time out of the cell block ran with nobody home")
	prison.crew_home_override = TRUE
	changeling_ticks(lost, 59) // OUTPOST_CHANGELING_HOST_LOST_AFTER
	TEST_ASSERT_EQUAL(lost.stage, "incubating", "The specimen was lost before a minute out")
	TEST_ASSERT_EQUAL(lost.incubation_elapsed, 0, "Incubation ran while the host was out of the cell block")
	changeling_ticks(lost, 1)
	TEST_ASSERT_EQUAL(lost.stage, "done", "A host a minute out of the cell block still has the specimen")
	TEST_ASSERT(!lost_host.experiment_subject, "A host who lost the specimen is still the experiment's subject")

	// A host killed out of the cell block (dragged toward a docked ship, say) does not burst there.
	var/datum/outpost_changeling_event/carried = changeling_host(prison, home, 14, 15)
	var/mob/living/basic/outpost_prisoner/carried_host = carried.host
	carried_host.forceMove(prison_spot(home, 12, 3))
	carried_host.death()
	changeling_ticks(carried, 10)
	TEST_ASSERT_EQUAL(carried.stage, "incubating", "A host killed out of the cell block burst there")
	carried_host.forceMove(prison_spot(home, 14, 15))
	changeling_ticks(carried, 3) // OUTPOST_CHANGELING_EARLY_BURST
	TEST_ASSERT_EQUAL(carried.stage, "burst", "A dead host brought back to the cell block did not burst")
	carried.force_stage("done")
	settle_prison_air(home)

// ===== THE VENTS =====

/datum/unit_test/voidcrew_outpost_prison_changeling_vents
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_changeling_vents/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("ventowner")
	TEST_ASSERT_NOTNULL(home, "The vent test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.crew_home_override = TRUE
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 3, 14), "ventowner")
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	warden.put_in_active_hand(wrench)

	// Seven sealed vents: one in each cell, two in the yard, one in the office.
	var/datum/outpost_changeling_event/event = changeling_host(prison, home)
	var/list/vents = event.closed_vents()
	TEST_ASSERT_EQUAL(length(vents), 7, "The wing has [length(vents)] sealed vents, not 7")
	for(var/list/spot in list(list(4, 14), list(8, 14), list(12, 14), list(16, 14), list(2, 10), list(16, 10), list(13, 3)))
		TEST_ASSERT_NOTNULL(changeling_vent(home, spot[1], spot[2]), "No vent at ([spot[1]],[spot[2]])")
	var/obj/structure/outpost_kessler_vent/cell_vent = changeling_vent(home, 4, 14)
	TEST_ASSERT(HAS_TRAIT(cell_vent, "outpost_property"), "The vents are not outpost property") // TRAIT_OUTPOST_PROPERTY
	TEST_ASSERT(cell_vent.resistance_flags & INDESTRUCTIBLE, "The vents can be broken")
	TEST_ASSERT(!cell_vent.density, "The vents block the floor")

	// The slug squeezes in over two seconds; a hit knocks it back out.
	event.force_stage("burst")
	var/mob/living/basic/headslug/beakless/outpost/slug = event.slug
	slug.forceMove(get_turf(cell_vent))
	TEST_ASSERT(slug.start_vent_entry(cell_vent), "The slug would not start into its vent")
	slug.adjust_health(1)
	TEST_ASSERT_NULL(slug.entering, "A hit did not stop the slug squeezing into the vent")
	TEST_ASSERT(slug.start_vent_entry(cell_vent), "The slug would not try the vent again")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(slug_in), slug, cell_vent), 3 SECONDS), "The slug was not in the vent 2 s later") // OUTPOST_HEADSLUG_VENT_ENTRY
	TEST_ASSERT_EQUAL(event.stage, "vents", "A slug in the vents is at stage [event.stage]")
	TEST_ASSERT_EQUAL(cell_vent.occupant, slug, "The vent does not know the slug is in it")
	TEST_ASSERT_EQUAL(event.time_left, 90, "The vent clock reads [event.time_left], not 90") // OUTPOST_CHANGELING_VENT_TIME

	// Nobody home: it stays put and the clock waits.
	prison.crew_home_override = FALSE
	event.dwell_left = 1
	changeling_ticks(event, 20)
	TEST_ASSERT_EQUAL(slug.loc, cell_vent, "The slug moved vents with nobody home")
	TEST_ASSERT_EQUAL(event.vent_elapsed, 0, "The vent clock ran with nobody home")
	prison.crew_home_override = TRUE

	// Dwell over: it moves on, never straight back.
	for(var/i in 1 to 6)
		var/obj/structure/outpost_kessler_vent/was_in = event.vent
		event.dwell_left = 1
		changeling_ticks(event, 1)
		TEST_ASSERT(event.vent != was_in, "The slug went back to the vent it just left")
		TEST_ASSERT_EQUAL(slug.loc, event.vent, "The slug is not in the vent the experiment has it in")
		TEST_ASSERT_EQUAL(get_area(event.vent), prison.wing, "The slug hopped to a vent outside the wing")
	TEST_ASSERT(event.dwell_left >= 14 && event.dwell_left <= 22, "The first noise level's dwell is [event.dwell_left] s, not 15-22")

	// The seal holds on an empty vent, and no tool but a wrench does anything.
	event.move_slug_to(cell_vent)
	var/obj/structure/outpost_kessler_vent/empty_vent = changeling_vent(home, 8, 14)
	warden.forceMove(prison_spot(home, 7, 14))
	TEST_ASSERT_EQUAL(empty_vent.wrench_act(warden, wrench), ITEM_INTERACT_SUCCESS, "Wrenching an empty vent did not take its time")
	TEST_ASSERT(!empty_vent.open, "An empty vent's cover came off")
	TEST_ASSERT_EQUAL(slug.loc, cell_vent, "Wrenching another vent moved the slug")
	var/obj/item/weldingtool/welder = allocate(/obj/item/weldingtool)
	TEST_ASSERT_EQUAL(cell_vent.welder_act(warden, welder), ITEM_INTERACT_BLOCKING, "A welder worked on a sealed vent")
	TEST_ASSERT_EQUAL(cell_vent.crowbar_act(warden, allocate(/obj/item/crowbar)), ITEM_INTERACT_BLOCKING, "A crowbar worked on a sealed vent")

	// A slug that moves on while the wrench turns gets away.
	warden.forceMove(prison_spot(home, 3, 14))
	INVOKE_ASYNC(cell_vent, TYPE_PROC_REF(/atom, wrench_act), warden, wrench)
	sleep(1 SECONDS)
	event.move_slug_to(changeling_vent(home, 12, 14))
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(not_wrenching), cell_vent), 4 SECONDS), "The wrench never finished")
	TEST_ASSERT(!cell_vent.open, "The cover came off a vent the slug had left")
	TEST_ASSERT_EQUAL(event.stage, "vents", "The slug came out of a vent it had left")

	// The vent it is in: the cover comes off and the slug drops out and fights, a slug for good.
	event.move_slug_to(cell_vent)
	TEST_ASSERT_EQUAL(cell_vent.wrench_act(warden, wrench), ITEM_INTERACT_SUCCESS, "Wrenching the slug's vent failed")
	TEST_ASSERT(cell_vent.open, "The slug's vent kept its cover")
	TEST_ASSERT_EQUAL(slug.loc, get_turf(cell_vent), "The slug did not drop out of its vent")
	TEST_ASSERT_EQUAL(slug.mode, "fight", "A wrenched out slug is not fighting")
	TEST_ASSERT(HAS_TRAIT(slug, TRAIT_IMMOBILIZED), "A wrenched out slug was not stunned")
	TEST_ASSERT_EQUAL(slug.ai_controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET], warden, "The slug did not turn on whoever wrenched it out")
	TEST_ASSERT_EQUAL(event.stage, "burst", "A wrenched out slug is at stage [event.stage]")
	TEST_ASSERT(event.wrenched_out, "The experiment does not know the slug was wrenched out")
	TEST_ASSERT(!event.slug_reached_vent(slug, changeling_vent(home, 12, 14)), "A wrenched out slug got back into the vents")
	TEST_ASSERT_EQUAL(cell_vent.wrench_act(warden, wrench), ITEM_INTERACT_BLOCKING, "A vent with its cover off could be wrenched again")
	changeling_ticks(event, 200)
	TEST_ASSERT(QDELETED(event.horror) || isnull(event.horror), "A wrenched out slug turned into the horror")

	// Killed: over, and Kessler refits the cover.
	slug.death()
	TEST_ASSERT_EQUAL(event.stage, "done", "Killing the wrenched out slug did not end it")
	TEST_ASSERT(!cell_vent.open, "Kessler did not refit the cover after the experiment")
	settle_prison_air(home)

/datum/unit_test/voidcrew_outpost_prison_changeling_vents/proc/slug_in(mob/living/basic/headslug/beakless/outpost/slug, obj/structure/outpost_kessler_vent/vent)
	return slug.loc == vent

/datum/unit_test/voidcrew_outpost_prison_changeling_vents/proc/not_wrenching(obj/structure/outpost_kessler_vent/vent)
	return !vent.wrenching

// ===== EMERGENCE =====

/datum/unit_test/voidcrew_outpost_prison_changeling_emergence
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_changeling_emergence/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("emergenceowner")
	TEST_ASSERT_NOTNULL(home, "The emergence test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.crew_home_override = TRUE
	var/datum/outpost_changeling_event/event = changeling_host(prison, home)
	// In front of cell 1's window, where the burst is in plain sight
	var/mob/living/basic/outpost_prisoner/bystander = test_prisoner(prison, prison_spot(home, 2, 11))
	bystander.set_mood(70)
	var/obj/structure/outpost_kessler_vent/cell_vent = changeling_in_vent(event, home, 4, 14)
	TEST_ASSERT_NOTNULL(cell_vent, "The slug did not get into cell 1's vent")
	var/mob/living/basic/headslug/beakless/outpost/slug = event.slug

	// Cell 1 is bolted: the horror will not come out there while another vent will do.
	TEST_ASSERT(prison.toggle_cell_bolts(1, null), "Cell 1 would not bolt")
	TEST_ASSERT(prison.cells[1].is_bolted(), "Cell 1 is not bolted")
	event.dwell_left = 1000
	changeling_ticks(event, 84)
	TEST_ASSERT(!event.straining, "A vent strained before 85 s")
	TEST_ASSERT_EQUAL(event.noise_level(), 3, "The last half minute in the vents is noise level [event.noise_level()]") // OUTPOST_CHANGELING_NOISE_VIOLENT
	TEST_ASSERT(cell_vent.dented, "Violent banging did not dent the cover")
	// The vent noises' own flee (a slug in the vents frightens nobody by sight, outpost_prison_panic.dm) goes by creature_panic.
	TEST_ASSERT(bystander.activity?.context == "creature_panic", "The prisoners did not run for their cells in the last minute")
	changeling_ticks(event, 1) // OUTPOST_CHANGELING_VENT_TIME - OUTPOST_CHANGELING_STRAIN_TIME
	TEST_ASSERT(event.straining, "No vent strained at 85 s")
	TEST_ASSERT(event.vent != cell_vent, "The horror is coming out of a vent in a bolted cell")
	TEST_ASSERT(!event.vent_in_bolted_cell(event.vent), "The emergence vent is in a bolted cell")
	var/obj/structure/outpost_kessler_vent/exit = event.vent
	TEST_ASSERT_EQUAL(slug.loc, exit, "The slug is not in the straining vent")
	changeling_ticks(event, 4)
	TEST_ASSERT_EQUAL(event.stage, "vents", "The horror came out before the strain was over")
	changeling_ticks(event, 1) // OUTPOST_CHANGELING_STRAIN_TIME

	// Out it comes: the cover blown off, the slug gone, the horror unfolding where it was.
	TEST_ASSERT_EQUAL(event.stage, "horror", "Nothing came out of the vents at 90 s")
	var/mob/living/basic/outpost_experiment/horror/horror = event.horror
	TEST_ASSERT_NOTNULL(horror, "The horror did not come out")
	TEST_ASSERT(QDELETED(slug), "The slug is still about after the horror came out")
	TEST_ASSERT(exit.open, "The emergence vent kept its cover")
	TEST_ASSERT_EQUAL(get_turf(horror), get_turf(exit), "The horror did not come out of the straining vent")
	TEST_ASSERT_EQUAL(horror.maxHealth, 400, "With nobody on the level the horror has [horror.maxHealth] health, not 400") // OUTPOST_HORROR_BASE_HEALTH
	TEST_ASSERT_EQUAL(horror.busy, "unfold", "The horror can act as it comes out")
	TEST_ASSERT(!horror.can_use_ability(), "The horror can use an ability while unfolding")
	TEST_ASSERT_EQUAL(horror.event, event, "The horror does not know its experiment")
	TEST_ASSERT(!ismegafauna(horror), "The horror counts as megafauna")
	TEST_ASSERT(!istype(horror, /mob/living/basic/boss), "The horror is a /mob/living/basic/boss")
	TEST_ASSERT(is_hostile_creature(horror), "Turrets would leave the horror alone") // interim turret rule
	// Its first act, once unfolded, is the resonant shriek's windup.
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(winding_up), horror), 4 SECONDS), "The horror did not start a shriek once it had unfolded") // OUTPOST_HORROR_UNFOLD_TIME
	var/datum/action/cooldown/mob_cooldown/outpost_horror/shriek = horror.abilities["resonant"]
	TEST_ASSERT(!shriek.IsAvailable(), "The resonant shriek is not on its cooldown after the first shriek")

	// Health scales with the players on the level: 100 for each after the first, three at most.
	var/mob/living/basic/outpost_experiment/horror/scaled = allocate(/mob/living/basic/outpost_experiment/horror, prison_spot(home, 9, 3))
	scaled.emerge_for(event, 2)
	TEST_ASSERT_EQUAL(scaled.maxHealth, 600, "Two extra players gave [scaled.maxHealth] health, not 600") // OUTPOST_HORROR_HEALTH_PER_PLAYER
	scaled.emerge_for(event, 7)
	TEST_ASSERT_EQUAL(scaled.maxHealth, 700, "Seven extra players gave [scaled.maxHealth] health, not the 700 cap") // OUTPOST_HORROR_EXTRA_PLAYERS_MAX
	scaled.event = null
	qdel(scaled)

	// Killed for good (the admin's kill): over, and Kessler refits the blown cover and the dent.
	TEST_ASSERT(prison.admin_horror("kill"), "The admin kill did not kill the horror")
	TEST_ASSERT_EQUAL(horror.stat, DEAD, "The admin kill left the horror alive")
	TEST_ASSERT_EQUAL(event.stage, "done", "Killing the horror did not end the experiment")
	TEST_ASSERT(!exit.open && !cell_vent.dented, "Kessler did not refit the vents after the experiment")
	// The changeling's own aftermath without S4a; with it, S4a's takes in the event's witnesses.
	TEST_ASSERT(bystander.mood < 70, "A prisoner who saw the burst lost no mood afterwards") // OUTPOST_CHANGELING_WITNESS_MOOD / OUTPOST_EXPERIMENT_SAW_DEATH_MOOD
	settle_prison_air(home)

/datum/unit_test/voidcrew_outpost_prison_changeling_emergence/proc/winding_up(mob/living/basic/outpost_experiment/horror/horror)
	return horror.busy == "windup"

// ===== THE HORROR'S KIT =====

/datum/unit_test/voidcrew_outpost_prison_changeling_kit
	parent_type = /datum/unit_test/voidcrew_outpost_management

/// A prisoner beside the horror, beaten down and ready to absorb
/datum/unit_test/voidcrew_outpost_prison_changeling_kit/proc/downed_prisoner(datum/outpost_prison/prison, turf/spot)
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, spot)
	prisoner.collapse()
	return prisoner

/// Lets the horror absorb again at once
/datum/unit_test/voidcrew_outpost_prison_changeling_kit/proc/ready(mob/living/basic/outpost_experiment/horror/horror)
	horror.clear_busy()
	horror.next_absorb_at = 0
	horror.next_ability_at = 0

/datum/unit_test/voidcrew_outpost_prison_changeling_kit/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("kitowner")
	TEST_ASSERT_NOTNULL(home, "The horror kit test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/turf/lair = prison_spot(home, 9, 9)
	var/turf/beside = prison_spot(home, 10, 9)
	var/mob/living/basic/outpost_experiment/horror/horror = allocate(/mob/living/basic/outpost_experiment/horror, lair)
	TEST_ASSERT(length(horror.abilities) == 1 && horror.abilities["resonant"], "A fresh horror does not start with the resonant shriek alone")
	TEST_ASSERT_EQUAL(horror.mob_size, MOB_SIZE_LARGE, "The horror is not large")
	TEST_ASSERT(horror.move_resist < MOVE_FORCE_OVERPOWERING, "The horror's body could never be dragged")

	// Absorb: heals to full, husks the victim, grows the horror and teaches it the next ability.
	var/list/order = list("dissonant", "fleshmend", "tentacle", null)
	for(var/i in 1 to 4)
		ready(horror)
		var/mob/living/basic/outpost_prisoner/victim = downed_prisoner(prison, beside)
		TEST_ASSERT(horror.absorbable(victim), "A prisoner beaten down could not be absorbed")
		horror.adjust_health(250)
		TEST_ASSERT(horror.start_absorb(victim), "Absorb [i] did not start")
		TEST_ASSERT(HAS_TRAIT(victim, TRAIT_IMMOBILIZED), "The horror's victim is not pinned")
		TEST_ASSERT_EQUAL(horror.finish_absorb(), victim, "Absorb [i] did not finish")
		TEST_ASSERT_EQUAL(victim.stat, DEAD, "Absorb [i] left its victim alive")
		TEST_ASSERT(HAS_TRAIT(victim, TRAIT_HUSK), "Absorb [i] did not husk its victim")
		TEST_ASSERT_EQUAL(horror.health, horror.maxHealth, "Absorb [i] healed the horror to [horror.health] of [horror.maxHealth]")
		TEST_ASSERT_EQUAL(horror.maxHealth, 400, "Absorb [i] changed the horror's maximum health") // no growth, OUTPOST_HORROR_BASE_HEALTH
		TEST_ASSERT(abs(horror.current_size - (1 + 0.05 * i)) < 0.001, "After [i] absorbs the horror is [horror.current_size] times its size, not [1 + 0.05 * i]") // OUTPOST_HORROR_SIZE_PER_ABSORB
		TEST_ASSERT_EQUAL(length(horror.abilities), min(i + 1, 4), "After [i] absorbs the horror knows [length(horror.abilities)] abilities")
		if(order[i])
			TEST_ASSERT(horror.abilities[order[i]], "Absorb [i] did not teach [order[i]]")
		TEST_ASSERT(!horror.absorbable(victim), "A husk could be absorbed again")
		qdel(victim)

	// A player down in crit is absorbed and husked; a mindless human NPC never is.
	ready(horror)
	var/mob/living/carbon/human/crewman = make_player(beside, "kitcrewman")
	crewman.adjustBruteLoss(160)
	TEST_ASSERT(crewman.stat >= SOFT_CRIT, "The crewman is not in crit")
	TEST_ASSERT(horror.start_absorb(crewman), "The horror could not absorb a downed player")
	horror.finish_absorb()
	TEST_ASSERT(crewman.stat == DEAD && HAS_TRAIT(crewman, TRAIT_HUSK), "An absorbed player is not a dead husk")
	var/mob/living/carbon/human/consistent/npc = allocate(/mob/living/carbon/human/consistent, prison_spot(home, 8, 9))
	npc.adjustBruteLoss(160)
	TEST_ASSERT(!horror.absorbable(npc), "The horror could absorb a mindless NPC")
	TEST_ASSERT(horror.valid_quarry(npc), "The horror would leave a downed NPC alive")
	var/mob/living/carbon/human/standing = make_player(prison_spot(home, 11, 9), "kitstander")
	TEST_ASSERT(!horror.absorbable(standing), "The horror could absorb someone on their feet")
	// Out of the way; the test's own cleanup deletes them.
	crewman.forceMove(prison_spot(home, 3, 7))
	npc.forceMove(prison_spot(home, 4, 7))

	// Interrupts: 40 damage, fire, or the victim dragged off their tile; each staggers it.
	ready(horror)
	var/mob/living/basic/outpost_prisoner/lucky = downed_prisoner(prison, beside)
	TEST_ASSERT(horror.start_absorb(lucky), "The interrupt test's absorb did not start")
	horror.adjust_health(39)
	TEST_ASSERT_EQUAL(horror.busy, "absorb", "39 damage broke the absorb") // OUTPOST_HORROR_ABSORB_BREAK
	horror.adjust_health(1)
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(busy_with), horror, "stagger"), 1 SECONDS), "40 damage did not break the absorb and stagger the horror")
	TEST_ASSERT(!HAS_TRAIT_FROM(lucky, TRAIT_IMMOBILIZED, "outpost_horror_grip"), "The victim is still pinned after the absorb broke") // HORROR_GRIP_TRAIT
	TEST_ASSERT(!HAS_TRAIT(lucky, TRAIT_HUSK) && lucky.stat != DEAD, "A broken absorb still drained its victim")
	TEST_ASSERT(horror.next_absorb_at > world.time + 15 SECONDS, "A broken absorb can be tried again at once") // OUTPOST_HORROR_ABSORB_COOLDOWN
	TEST_ASSERT(!horror.start_absorb(lucky), "The horror absorbed again straight after a broken absorb")
	ready(horror)
	TEST_ASSERT(horror.start_absorb(lucky), "The fire test's absorb did not start")
	horror.adjust_fire_stacks(5)
	horror.ignite_mob()
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(busy_with), horror, "stagger"), 1 SECONDS), "Setting the horror alight did not break its absorb")
	horror.extinguish_mob()
	ready(horror)
	TEST_ASSERT(horror.start_absorb(lucky), "The drag test's absorb did not start")
	lucky.forceMove(prison_spot(home, 11, 9))
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(busy_with), horror, "stagger"), 1 SECONDS), "Dragging the victim off their tile did not break the absorb")

	// The three beats in real time: the grab, the proboscis at 4 s, the husk at 10 s.
	ready(horror)
	lucky.forceMove(beside)
	TEST_ASSERT(horror.start_absorb(lucky), "The timed absorb did not start")
	sleep(3 SECONDS)
	TEST_ASSERT(!lucky.color, "The victim greyed before the proboscis beat")
	sleep(1.5 SECONDS) // OUTPOST_HORROR_ABSORB_PROBOSCIS
	TEST_ASSERT(lucky.color, "The proboscis beat did not grey the victim")
	TEST_ASSERT(lucky.stat != DEAD, "The victim died before the third beat")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(husked), lucky), 7 SECONDS), "The absorb did not finish 10 s after the grab") // OUTPOST_HORROR_ABSORB_TIME
	TEST_ASSERT_EQUAL(horror.busy, "digest", "The horror did not stop to digest")

	// Its shield: a quarter of the hits from in front, none from behind.
	ready(horror)
	horror.setDir(NORTH)
	var/turf/front = prison_spot(home, 9, 11)
	var/turf/behind = prison_spot(home, 9, 7)
	var/front_blocks = 0
	var/back_blocks = 0
	for(var/i in 1 to 400)
		if(horror.shield_catches(front))
			front_blocks++
		if(horror.shield_catches(behind))
			back_blocks++
	TEST_ASSERT(front_blocks > 50 && front_blocks < 160, "The shield caught [front_blocks] of 400 hits from in front, not about 100") // OUTPOST_HORROR_SHIELD_CHANCE
	TEST_ASSERT_EQUAL(back_blocks, 0, "The shield caught [back_blocks] hits from behind")
	settle_prison_air(home)

/datum/unit_test/voidcrew_outpost_prison_changeling_kit/proc/busy_with(mob/living/basic/outpost_experiment/horror/horror, state)
	return horror.busy == state

/datum/unit_test/voidcrew_outpost_prison_changeling_kit/proc/husked(mob/living/victim)
	return HAS_TRAIT(victim, TRAIT_HUSK) && victim.stat == DEAD

// ===== THE ABILITIES =====

/datum/unit_test/voidcrew_outpost_prison_changeling_abilities
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_changeling_abilities/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("abilityowner")
	TEST_ASSERT_NOTNULL(home, "The ability test prison did not load")
	// Along the yard's clear south row: the horror at (5,7), someone 2 tiles off and someone 6.
	var/mob/living/basic/outpost_experiment/horror/horror = allocate(/mob/living/basic/outpost_experiment/horror, prison_spot(home, 5, 7))
	for(var/i in 1 to 3)
		horror.absorbs = i
		horror.learn_next_ability()
	var/mob/living/carbon/human/near = make_player(prison_spot(home, 7, 7), "abilitynear")
	var/mob/living/carbon/human/far = make_player(prison_spot(home, 11, 7), "abilityfar")

	// Resonant shriek: confusion, jitter and broken lights within 4; nothing beyond.
	var/datum/action/cooldown/mob_cooldown/outpost_horror/resonant = horror.abilities["resonant"]
	TEST_ASSERT(resonant.Trigger(target = near), "The resonant shriek would not start")
	TEST_ASSERT_EQUAL(horror.busy, "windup", "The resonant shriek has no windup")
	TEST_ASSERT(!horror.can_use_ability(), "The horror could start a second ability during a windup")
	resonant.effect(near)
	TEST_ASSERT(near.has_status_effect(/datum/status_effect/confusion), "The resonant shriek did not confuse someone 2 tiles off")
	TEST_ASSERT(near.has_status_effect(/datum/status_effect/jitter), "The resonant shriek did not make someone 2 tiles off shake")
	TEST_ASSERT(!far.has_status_effect(/datum/status_effect/confusion), "The resonant shriek confused someone 6 tiles off")
	near.remove_status_effect(/datum/status_effect/confusion)
	horror.clear_busy()
	TEST_ASSERT(!horror.can_use_ability(), "No gap between abilities") // OUTPOST_HORROR_ABILITY_GAP
	horror.next_ability_at = 0

	// Dissonant shriek: 30% off an energy weapon within 3, never beyond; headsets go dead.
	var/obj/item/gun/energy/laser/near_gun = allocate(/obj/item/gun/energy/laser)
	var/obj/item/gun/energy/laser/far_gun = allocate(/obj/item/gun/energy/laser)
	near.put_in_active_hand(near_gun)
	far.put_in_active_hand(far_gun)
	var/obj/item/radio/headset/headset = allocate(/obj/item/radio/headset, get_turf(near))
	headset.set_on(TRUE)
	var/full = near_gun.cell.maxcharge
	var/datum/action/cooldown/mob_cooldown/outpost_horror/dissonant = horror.abilities["dissonant"]
	dissonant.effect(near)
	TEST_ASSERT(abs(near_gun.cell.charge - full * 0.7) < 1, "The dissonant shriek left a laser 2 tiles off at [near_gun.cell.charge] of [full], not 70%") // OUTPOST_HORROR_DISSONANT_DRAIN
	TEST_ASSERT_EQUAL(far_gun.cell.charge, far_gun.cell.maxcharge, "The dissonant shriek drained a laser 6 tiles off")
	TEST_ASSERT(!headset.on, "The dissonant shriek did not silence a headset")

	// Fleshmend: only when hurt; it heals, and 45 damage breaks it.
	var/datum/action/cooldown/mob_cooldown/outpost_horror/fleshmend = horror.abilities["fleshmend"]
	TEST_ASSERT(!fleshmend.worth_using(horror), "The horror would mend at full health")
	horror.adjust_health(250)
	TEST_ASSERT(fleshmend.worth_using(horror), "The horror would not mend at 150 health")
	TEST_ASSERT(fleshmend.Trigger(target = horror), "Fleshmend would not start")
	TEST_ASSERT_EQUAL(horror.busy, "fleshmend", "Fleshmend did not start its channel")
	var/before = horror.health
	sleep(2.5 SECONDS)
	TEST_ASSERT(horror.health >= before + 15, "Two seconds of fleshmend healed [horror.health - before], not 20") // OUTPOST_HORROR_FLESHMEND_HEAL
	var/mended = horror.health
	horror.adjust_health(20)
	TEST_ASSERT(abs((mended - horror.health) - 25) < 0.5, "20 damage while mending did [mended - horror.health], not 25") // OUTPOST_HORROR_FLESHMEND_VULNERABILITY
	horror.adjust_health(20)
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(staggered), horror), 1 SECONDS), "45 damage did not break fleshmend") // OUTPOST_HORROR_FLESHMEND_BREAK

	// Tentacle grip: whoever stays on the line is pulled in, knocked down and impaled.
	horror.clear_busy()
	horror.next_ability_at = 0
	var/datum/action/cooldown/mob_cooldown/outpost_horror/tentacle = horror.abilities["tentacle"]
	TEST_ASSERT(tentacle.worth_using(far), "The tentacle would not reach someone 6 tiles off")
	TEST_ASSERT(!tentacle.worth_using(near) || get_dist(horror, near) >= 2, "The tentacle would lash someone right beside it")
	near.forceMove(prison_spot(home, 7, 8))
	var/far_health = far.health
	tentacle.telegraph(far)
	tentacle.effect(far)
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(pulled_in), horror, far), 3 SECONDS), "The tentacle did not pull its target in")
	TEST_ASSERT(far.health <= far_health - 10, "The tentacle did [far_health - far.health] damage, not about 22") // OUTPOST_HORROR_TENTACLE_DAMAGE
	settle_prison_air(home)

/datum/unit_test/voidcrew_outpost_prison_changeling_abilities/proc/staggered(mob/living/basic/outpost_experiment/horror/horror)
	return horror.busy == "stagger"

/datum/unit_test/voidcrew_outpost_prison_changeling_abilities/proc/pulled_in(mob/living/basic/outpost_experiment/horror/horror, mob/living/victim)
	return get_dist(horror, victim) <= 1

// ===== CONTAINMENT =====

/datum/unit_test/voidcrew_outpost_prison_changeling_containment
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_changeling_containment/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("breachowner")
	TEST_ASSERT_NOTNULL(home, "The containment test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.crew_home_override = TRUE
	var/datum/outpost_changeling_event/event = changeling_host(prison, home)
	TEST_ASSERT(event.force_stage("horror"), "The admin horror stage did nothing")
	var/mob/living/basic/outpost_experiment/horror/horror = event.horror
	TEST_ASSERT_NOTNULL(horror, "The admin horror stage made no horror")
	horror.clear_busy()

	// The megafauna ban leaves it alone in the wing, and nothing takes it over or away.
	horror.forceMove(prison_spot(home, 9, 9))
	sleep(2)
	TEST_ASSERT(!QDELETED(horror), "The megafauna ban deleted the horror in the prison wing")
	TEST_ASSERT(horror.sentience_type != 1, "The horror takes sentience potions") // SENTIENCE_ORGANIC
	TEST_ASSERT(HAS_TRAIT(horror, "no_containment"), "The horror can be boxed") // TRAIT_NO_CONTAINMENT
	var/turf/start = get_turf(horror)
	do_teleport(horror, prison_spot(home, 9, 3), channel = TELEPORT_CHANNEL_BLUESPACE)
	TEST_ASSERT_EQUAL(get_turf(horror), start, "The horror was teleported")
	TEST_ASSERT(!horror.can_be_revived(), "A dead horror could be revived")

	// With nobody from the wing home it lies low: it answers whoever hurts it and hunts nobody.
	var/mob/living/basic/outpost_prisoner/nearby = test_prisoner(prison, prison_spot(home, 11, 9))
	TEST_ASSERT_EQUAL(horror.pick_quarry(), nearby, "The horror ignored a prisoner in plain sight")
	prison.crew_home_override = FALSE
	TEST_ASSERT_NULL(horror.pick_quarry(), "The horror hunts with nobody from the wing home")
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 8, 9), "breachvisitor")
	SEND_SIGNAL(horror, COMSIG_ATOM_WAS_ATTACKED, visitor, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT_EQUAL(horror.pick_quarry(), visitor, "The horror did not fight back with nobody home")
	prison.crew_home_override = TRUE
	visitor.forceMove(prison_spot(home, 3, 7))

	// Never off the outpost's ground.
	var/list/bounds = prison.upgrade.footprint_bounds
	var/turf/outside = locate(bounds[1] - 2, bounds[2] + 5, bounds[5])
	TEST_ASSERT(!event.on_outpost_ground(outside), "Ground beyond the wing counts as the outpost's")
	TEST_ASSERT(event.on_outpost_ground(start), "The yard does not count as the outpost's ground")
	TEST_ASSERT(SEND_SIGNAL(horror, COMSIG_MOVABLE_PRE_MOVE, outside) & COMPONENT_MOVABLE_BLOCK_PRE_MOVE, "The horror could step off the outpost's ground")

	// The outer ring holds: the yard's outer window never breaks, whatever it does.
	var/turf/yard_edge = prison_spot(home, 2, 10)
	var/turf/outer_window_turf = prison_spot(home, 1, 10)
	var/obj/structure/window/outer_window = locate() in outer_window_turf
	TEST_ASSERT_NOTNULL(outer_window, "No outer window at (1,10)")
	horror.forceMove(yard_edge)
	TEST_ASSERT(!horror.may_breach(outer_window_turf, yard_edge), "The horror may breach the wing's outer ring")
	for(var/i in 1 to 5)
		horror.next_move = 0
		horror.hack_at(outer_window)
	TEST_ASSERT(!QDELETED(outer_window) && outer_window.atom_integrity == outer_window.max_integrity, "The horror damaged the wing's outer window")
	var/obj/structure/outpost_kessler_vent/yard_vent = changeling_vent(home, 2, 10)
	var/mob/living/carbon/human/outside_man = make_player(outside, "breachoutsider")
	TEST_ASSERT_NULL(horror.barrier_toward(outside_man), "The horror would break toward someone beyond the outer ring")
	TEST_ASSERT_NOTNULL(yard_vent, "No yard vent at (2,10)")

	// An interior window gives in three blows; a staff door is pried open.
	var/turf/divider_turf = prison_spot(home, 7, 6)
	var/obj/structure/window/divider = locate() in divider_turf
	TEST_ASSERT_NOTNULL(divider, "No divider window at (7,6)")
	horror.forceMove(prison_spot(home, 7, 7))
	TEST_ASSERT(horror.may_breach(divider_turf, get_turf(horror)), "The horror may not break the divider window into the office")
	for(var/i in 1 to 2)
		horror.next_move = 0
		TEST_ASSERT(horror.hack_at(divider), "The horror did not hack at the divider window")
	TEST_ASSERT(!QDELETED(divider), "The divider window broke in fewer than three blows")
	horror.next_move = 0
	horror.hack_at(divider)
	TEST_ASSERT(QDELETED(divider), "The divider window survived three blows") // OUTPOST_HORROR_WINDOW_HITS
	var/obj/machinery/door/airlock/staff_door = locate(/obj/machinery/door/airlock/security/prison_staff) in prison_spot(home, 9, 6)
	TEST_ASSERT_NOTNULL(staff_door, "No staff door at (9,6)")
	horror.forceMove(prison_spot(home, 9, 7))
	TEST_ASSERT(horror.start_pry(staff_door), "The horror would not pry the staff door")
	TEST_ASSERT_EQUAL(horror.busy, "pry", "Prying does not hold the horror still")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(door_open), staff_door), 11 SECONDS), "The staff door was not forced open") // OUTPOST_HORROR_PRY_TIME, _BOLTED_TIME unpowered
	var/obj/machinery/door/airlock/entrance = locate(/obj/machinery/door/airlock) in prison_spot(home, 9, 1)
	horror.forceMove(prison_spot(home, 9, 2))
	var/turf/beyond_entrance = get_step(get_turf(entrance), SOUTH)
	if(!event.on_outpost_ground(beyond_entrance))
		TEST_ASSERT(!horror.start_pry(entrance), "The horror pried a door that opens off the outpost")
	settle_prison_air(home)

/datum/unit_test/voidcrew_outpost_prison_changeling_containment/proc/door_open(obj/machinery/door/airlock/door)
	return !door.density

// ===== REGENERATION =====

/datum/unit_test/voidcrew_outpost_prison_changeling_regen
	parent_type = /datum/unit_test/voidcrew_outpost_management

/// A specimen taken straight to the horror by the admin stage, standing and free, in the yard, with the event's clock stopped
/datum/unit_test/voidcrew_outpost_prison_changeling_regen/proc/fresh_horror(datum/outpost_prison/prison, obj/structure/overmap/dynamic/player_outpost/home)
	var/datum/outpost_changeling_event/event = changeling_host(prison, home)
	if(!event?.force_stage("horror"))
		return null
	var/mob/living/basic/outpost_experiment/horror/horror = event.horror
	horror.clear_busy()
	horror.forceMove(prison_spot(home, 9, 9))
	return horror

/// Whether the warden's log has an entry with `text` in it
/datum/unit_test/voidcrew_outpost_prison_changeling_regen/proc/logged(datum/outpost_prison/prison, text)
	for(var/list/entry as anything in prison.entries)
		if(findtext(entry["text"], text))
			return TRUE
	return FALSE

/datum/unit_test/voidcrew_outpost_prison_changeling_regen/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("regenowner")
	TEST_ASSERT_NOTNULL(home, "The regeneration test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.crew_home_override = TRUE
	var/datum/bank_account/treasury = trouble_fund(home, 0)
	var/mob/living/carbon/human/crew = make_player(prison_spot(home, 12, 3), "regenowner")
	var/mob/living/basic/outpost_experiment/horror/horror = fresh_horror(prison, home)
	TEST_ASSERT_NOTNULL(horror, "The admin horror stage made no horror")
	var/datum/outpost_changeling_event/event = horror.event
	var/datum/component/experiment_damage_ledger/ledger = horror.GetComponent(/datum/component/experiment_damage_ledger)
	TEST_ASSERT_NOTNULL(ledger, "The horror has no damage ledger")
	var/fee = treasury.account_balance

	// At 0 health it goes down regenerating, not dead: on the floor, out of it, and no turret's target.
	ledger.note_attacker(crew)
	horror.apply_damage(horror.maxHealth * 2, BRUTE)
	TEST_ASSERT(horror.regenerating, "The horror at 0 health did not go down regenerating")
	TEST_ASSERT(horror.stat != DEAD, "The horror at 0 health died")
	TEST_ASSERT_EQUAL(horror.stat, UNCONSCIOUS, "The horror down is not out of it")
	TEST_ASSERT_EQUAL(horror.health, 0, "The horror down has [horror.health] health, not 0")
	TEST_ASSERT(HAS_TRAIT(horror, TRAIT_FLOORED), "The horror down is not on the floor")
	TEST_ASSERT(HAS_TRAIT(horror, TRAIT_INCAPACITATED), "The horror down can act")
	TEST_ASSERT(!horror.can_use_ability(), "The horror down can use an ability")
	TEST_ASSERT(!is_hostile_creature(horror), "Turrets would shoot the horror while it is down") // interim turret rule
	TEST_ASSERT_EQUAL(horror.remains, 200, "The horror's body can take [horror.remains] damage while down, not 200") // OUTPOST_HORROR_REMAINS
	TEST_ASSERT_EQUAL(event.stage, "horror", "Going down ended the changeling event")
	TEST_ASSERT(prison.experiment_active(), "Going down ended the experiment")
	TEST_ASSERT(prison.creature_live(), "The horror down does not count as loose, so the prisoners would stop hiding")
	TEST_ASSERT_EQUAL(prison.experiment.bonus_paid, 0, "Going down paid the containment bonus")
	TEST_ASSERT_EQUAL(treasury.account_balance, fee, "Going down paid [treasury.account_balance - fee] cr")
	var/list/block = prison.experiment_payload()
	TEST_ASSERT_EQUAL(block["horror"], "regenerating", "The console does not show the horror regenerating")
	TEST_ASSERT_EQUAL(block["time_left"], 45, "The console shows [block["time_left"]] s to getting up, not 45") // OUTPOST_HORROR_REGEN_TIME
	TEST_ASSERT(findtext(jointext(horror.examine(crew), " "), "still moving"), "Examining the horror down does not say it is still moving")
	TEST_ASSERT(logged(prison, "regenerating"), "The warden's log did not record the horror going down")
	TEST_ASSERT(event.regen_announced, "The outpost was not told the horror is regenerating")

	// Down, it cannot absorb anyone.
	var/mob/living/basic/outpost_prisoner/victim = test_prisoner(prison, prison_spot(home, 10, 9))
	victim.collapse()
	TEST_ASSERT(horror.absorbable(victim), "The test's victim could not be absorbed at all")
	horror.next_absorb_at = 0
	TEST_ASSERT(!horror.start_absorb(victim), "The horror absorbed someone while it was down")
	TEST_ASSERT_NULL(horror.absorbing, "The horror down seized someone")

	// It gets up OUTPOST_HORROR_REGEN_TIME later, counted only while the crew is home, with half its health.
	prison.crew_home_override = FALSE
	changeling_ticks(event, 60)
	TEST_ASSERT(horror.regenerating, "The horror got up with nobody home")
	TEST_ASSERT_EQUAL(horror.regen_left, 45, "The regeneration clock ran with nobody home")
	prison.crew_home_override = TRUE
	changeling_ticks(event, 39)
	TEST_ASSERT(!horror.rise_warned, "The horror warned it was getting up more than 5 s early") // OUTPOST_HORROR_RISE_WARNING
	changeling_ticks(event, 1)
	TEST_ASSERT(horror.rise_warned, "The horror gave no warning 5 s before getting up")
	// Set alight, its body cannot knit: the clock waits, and it warns again once the fire is out.
	horror.adjust_fire_stacks(3)
	horror.ignite_mob()
	TEST_ASSERT(horror.on_fire, "The downed horror would not catch fire")
	changeling_ticks(event, 3)
	TEST_ASSERT(horror.regenerating, "The burning horror got up")
	TEST_ASSERT(!horror.rise_warned, "The burning horror still meant to get up")
	horror.extinguish_mob()
	changeling_ticks(event, 1)
	TEST_ASSERT(horror.rise_warned, "The horror gave no new warning once the fire was out")
	changeling_ticks(event, 4)
	TEST_ASSERT(horror.regenerating, "The horror got up less than 5 s after the fire went out")
	changeling_ticks(event, 1)
	TEST_ASSERT(!horror.regenerating, "The horror did not get up after 45 s")
	TEST_ASSERT_EQUAL(horror.stat, CONSCIOUS, "The horror got up but is not conscious")
	TEST_ASSERT_EQUAL(horror.health, horror.maxHealth * 0.5, "The horror got up with [horror.health] of [horror.maxHealth] health, not half") // OUTPOST_HORROR_REGEN_HEALTH
	TEST_ASSERT(!HAS_TRAIT(horror, TRAIT_FLOORED) && !HAS_TRAIT(horror, TRAIT_INCAPACITATED), "The horror got up but is still down")
	TEST_ASSERT(is_hostile_creature(horror), "Turrets leave the horror alone after it got up")
	TEST_ASSERT(horror.abilities["resonant"], "The horror lost its kit going down")
	TEST_ASSERT_NOTNULL(horror.ai_controller, "The horror has no mind after getting up")
	TEST_ASSERT_EQUAL(horror.GetComponent(/datum/component/experiment_damage_ledger), ledger, "The horror's damage ledger was replaced")
	TEST_ASSERT(ledger.player_damage >= 400, "The crew's damage before it went down was lost from its ledger ([ledger.player_damage])")
	TEST_ASSERT(logged(prison, "got back up"), "The warden's log did not record the horror getting up")
	TEST_ASSERT_EQUAL(prison.experiment_payload()["horror"], "up", "The console does not show the horror up again")

	// Down again (the admin's regen), its body takes OUTPOST_HORROR_REMAINS before it bursts: dead for good, and the bonus paid once.
	TEST_ASSERT(prison.admin_horror("regen"), "The admin regen did not drop the horror")
	TEST_ASSERT(horror.regenerating, "The admin regen left the horror standing")
	var/turf/spot = get_turf(horror)
	ledger.note_attacker(crew)
	horror.apply_damage(200, BRUTE)
	TEST_ASSERT(!QDELETED(horror) && horror.regenerating, "The horror's body burst before it had taken 200 damage")
	TEST_ASSERT(abs(horror.remains - 30) < 0.01, "200 brute left [horror.remains] of its body, not 30") // 200 * OUTPOST_HORROR_DAMAGE_COEFF off OUTPOST_HORROR_REMAINS
	TEST_ASSERT_EQUAL(horror.health, 0, "Hitting the body changed its health")
	TEST_ASSERT_EQUAL(prison.experiment.bonus_paid, 0, "Hitting the body paid the bonus before it burst")
	ledger.note_attacker(crew)
	horror.apply_damage(100, BRUTE)
	TEST_ASSERT(QDELETED(horror), "The horror's body did not burst when it was destroyed")
	TEST_ASSERT_EQUAL(event.stage, "done", "Destroying the body did not end the changeling event")
	TEST_ASSERT_EQUAL(prison.experiment.stage, "contained", "Destroying the body did not contain the horror")
	TEST_ASSERT_EQUAL(prison.experiment.bonus_paid, 3900, "Destroying the body paid [prison.experiment.bonus_paid], not 3900") // OUTPOST_EXPERIMENT_BONUS_HORROR
	TEST_ASSERT_EQUAL(treasury.account_balance, fee + 3900, "The containment bonus came to [treasury.account_balance - fee], not 3900 once")
	TEST_ASSERT(!prison.experiment_creature_down(horror), "The containment bonus could be claimed twice")
	TEST_ASSERT_NOTNULL(locate(/obj/item/organ/heart) in spot, "The burst body left no organs")

	// A second horror, down in a vented room inside the wing: the low pressure does nothing to it, and it gets up as usual.
	var/mob/living/basic/outpost_experiment/horror/vented = fresh_horror(prison, home)
	TEST_ASSERT_NOTNULL(vented, "The second horror did not come out")
	var/datum/outpost_changeling_event/second_event = vented.event
	TEST_ASSERT(vented.start_regenerating(), "The second horror would not go down")
	var/turf/open/cold = get_turf(vented)
	var/datum/gas_mixture/air = cold.return_air()
	air.remove_ratio(1)
	TEST_ASSERT(air.return_pressure() < 20, "Emptying the air around the horror did not vent its tile") // HAZARD_LOW_PRESSURE
	TEST_ASSERT(!vented.in_open_space(), "A vented tile in the wing counts as open space")
	changeling_ticks(second_event, 1)
	TEST_ASSERT(vented.stat != DEAD && vented.regenerating, "The horror down in a vented room died")
	changeling_ticks(second_event, 44)
	TEST_ASSERT(!vented.regenerating, "The horror down in a vented room did not get up after 45 s") // OUTPOST_HORROR_REGEN_TIME
	TEST_ASSERT_EQUAL(vented.stat, CONSCIOUS, "The horror got up in a vented room but is not conscious")
	TEST_ASSERT_EQUAL(second_event.stage, "horror", "The horror down in a vented room ended the changeling event")
	TEST_ASSERT(prison.admin_horror("kill"), "The admin kill did nothing to the second horror")
	TEST_ASSERT_EQUAL(second_event.stage, "done", "The admin kill did not end the second changeling event")

	// Brought down in a vented room, it goes down regenerating as it would anywhere on the outpost.
	var/mob/living/basic/outpost_experiment/horror/collapsing = allocate(/mob/living/basic/outpost_experiment/horror, cold)
	collapsing.adjust_health(collapsing.maxHealth)
	TEST_ASSERT(collapsing.stat != DEAD, "A horror brought down in a vented room died for good")
	TEST_ASSERT(collapsing.regenerating, "A horror brought down in a vented room did not go down regenerating")
	settle_prison_air(home)

// ===== SPACING =====

/datum/unit_test/voidcrew_outpost_prison_changeling_spacing
	parent_type = /datum/unit_test/voidcrew_outpost_management

/// A specimen taken straight to the horror by the admin stage, standing and free, with the event's clock stopped
/datum/unit_test/voidcrew_outpost_prison_changeling_spacing/proc/horror_for(datum/outpost_prison/prison, obj/structure/overmap/dynamic/player_outpost/home)
	var/datum/outpost_changeling_event/event = changeling_host(prison, home)
	if(!event?.force_stage("horror"))
		return null
	var/mob/living/basic/outpost_experiment/horror/horror = event.horror
	horror.clear_busy()
	return horror

/datum/unit_test/voidcrew_outpost_prison_changeling_spacing/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("spacingowner")
	TEST_ASSERT_NOTNULL(home, "The spacing test prison did not load")
	TEST_ASSERT_NOTNULL(home.outpost_area, "The spacing test outpost has no area")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.crew_home_override = TRUE
	var/datum/bank_account/treasury = trouble_fund(home, 0)
	var/mob/living/carbon/human/crew = make_player(prison_spot(home, 12, 3), "spacingowner")

	// West of the wing, three tiles of space. One joins the outpost's area, as a hole in its floor
	// would; the one beyond it stays open space; the one north of the hole becomes a deck that is not
	// the outpost's, as a docked ship's would be.
	var/list/bounds = prison.upgrade.footprint_bounds
	var/turf/breach = locate(bounds[1] - 2, bounds[2] + 5, bounds[5])
	var/turf/open_space = locate(bounds[1] - 3, bounds[2] + 5, bounds[5])
	var/turf/deck = locate(bounds[1] - 2, bounds[2] + 6, bounds[5])
	for(var/turf/tile as anything in list(breach, open_space, deck))
		TEST_ASSERT(isspaceturf(tile) && istype(tile.loc, /area/space), "A tile west of the wing is not open space")
	var/area/space_area = breach.loc
	breach.change_area(space_area, home.outpost_area)
	deck = deck.ChangeTurf(/turf/open/floor/plating/airless)

	var/mob/living/basic/outpost_experiment/horror/horror = horror_for(prison, home)
	TEST_ASSERT_NOTNULL(horror, "The admin horror stage made no horror")
	var/datum/outpost_changeling_event/event = horror.event
	TEST_ASSERT(event.on_outpost_ground(breach), "A hole in the outpost's floor does not count as the outpost's ground")
	TEST_ASSERT(!event.in_open_space(breach), "A hole in the outpost's floor counts as open space")
	TEST_ASSERT(event.in_open_space(open_space), "Space beside the outpost does not count as open space")
	TEST_ASSERT(!event.on_outpost_ground(deck) && !event.in_open_space(deck), "A deck off the outpost counts as the outpost's ground or as open space")
	TEST_ASSERT(!event.in_open_space(prison_spot(home, 9, 9)), "The wing's yard counts as open space")

	// Standing, it never steps off the outpost's ground: not into space, not onto the deck.
	horror.forceMove(breach)
	TEST_ASSERT(SEND_SIGNAL(horror, COMSIG_MOVABLE_PRE_MOVE, open_space) & COMPONENT_MOVABLE_BLOCK_PRE_MOVE, "The standing horror could step off the outpost into space")
	horror.Move(open_space, WEST)
	TEST_ASSERT_EQUAL(get_turf(horror), breach, "The standing horror stepped off the outpost into space")
	horror.Move(deck, NORTH)
	TEST_ASSERT_EQUAL(get_turf(horror), breach, "The standing horror stepped off the outpost onto the deck")
	TEST_ASSERT_EQUAL(horror.stat, CONSCIOUS, "The standing horror is not standing")

	// Down on the hole in the floor, still on the outpost, it lies there regenerating.
	var/datum/component/experiment_damage_ledger/ledger = horror.GetComponent(/datum/component/experiment_damage_ledger)
	var/fee = treasury.account_balance
	ledger.note_attacker(crew)
	horror.apply_damage(horror.maxHealth * 2, BRUTE)
	TEST_ASSERT(horror.regenerating, "The horror did not go down on the hole in the floor")
	changeling_ticks(event, 1)
	TEST_ASSERT(horror.regenerating && horror.stat != DEAD, "The horror died down on a space tile inside the outpost's area")

	// Its body may not be moved onto ground off the outpost.
	TEST_ASSERT(SEND_SIGNAL(horror, COMSIG_MOVABLE_PRE_MOVE, deck) & COMPONENT_MOVABLE_BLOCK_PRE_MOVE, "The horror's body could be moved onto a deck off the outpost")
	horror.Move(deck, NORTH)
	TEST_ASSERT_EQUAL(get_turf(horror), breach, "The horror's body was moved onto a deck off the outpost")
	TEST_ASSERT_EQUAL(prison.experiment.bonus_paid, 0, "The horror paid its containment bonus while down")

	// Pushed out into open space, it dies on arrival: for good, and the containment bonus is paid once.
	TEST_ASSERT(!(SEND_SIGNAL(horror, COMSIG_MOVABLE_PRE_MOVE, open_space) & COMPONENT_MOVABLE_BLOCK_PRE_MOVE), "The horror's body could not be moved into open space")
	horror.Move(open_space, WEST)
	TEST_ASSERT_EQUAL(get_turf(horror), open_space, "The horror's body was not pushed into open space")
	TEST_ASSERT_EQUAL(horror.stat, DEAD, "The horror's body in open space did not die")
	TEST_ASSERT(horror.final_death && !horror.regenerating, "The horror in open space is not dead for good")
	TEST_ASSERT_EQUAL(event.stage, "done", "Spacing the horror did not end the changeling event")
	TEST_ASSERT_EQUAL(prison.experiment.stage, "contained", "Spacing the horror did not contain it")
	TEST_ASSERT_EQUAL(prison.experiment.bonus_paid, 3900, "Spacing the horror paid [prison.experiment.bonus_paid], not 3900") // OUTPOST_EXPERIMENT_BONUS_HORROR
	TEST_ASSERT_EQUAL(treasury.account_balance, fee + 3900, "Spacing the horror paid [treasury.account_balance - fee] cr, not 3900 once")
	TEST_ASSERT(!prison.experiment_creature_down(horror), "The containment bonus could be claimed twice")
	prison.experiments_tick(1)
	TEST_ASSERT_EQUAL(prison.experiment.stage, "contained", "The off-outpost check turned the spaced horror into a recovery")
	TEST_ASSERT_EQUAL(treasury.account_balance, fee + 3900, "The off-outpost check charged for the spaced horror")

	// Nor does the off-outpost check take a body that lies down in open space: it dies there. This one is
	// held (as an admin's godmode would hold it) while it is put out there, so only the check sees to it.
	var/mob/living/basic/outpost_experiment/horror/drifter = horror_for(prison, home)
	TEST_ASSERT_NOTNULL(drifter, "The second horror did not come out")
	var/datum/outpost_changeling_event/second_event = drifter.event
	drifter.forceMove(breach)
	var/datum/component/experiment_damage_ledger/second_ledger = drifter.GetComponent(/datum/component/experiment_damage_ledger)
	second_ledger.note_attacker(crew)
	drifter.apply_damage(drifter.maxHealth * 2, BRUTE)
	TEST_ASSERT(drifter.regenerating, "The second horror did not go down")
	ADD_TRAIT(drifter, TRAIT_GODMODE, TRAIT_SOURCE_UNIT_TESTS)
	drifter.forceMove(open_space)
	TEST_ASSERT(drifter.regenerating && drifter.stat != DEAD, "A held horror died in open space")
	REMOVE_TRAIT(drifter, TRAIT_GODMODE, TRAIT_SOURCE_UNIT_TESTS)
	var/balance = treasury.account_balance
	prison.experiments_tick(1)
	TEST_ASSERT_EQUAL(drifter.stat, DEAD, "The off-outpost check did not kill the horror's body down in open space")
	TEST_ASSERT_EQUAL(second_event.stage, "done", "The horror dying on the off-outpost check did not end the changeling event")
	TEST_ASSERT_EQUAL(prison.experiment.stage, "contained", "The off-outpost check recovered the horror's body instead of letting it die")
	TEST_ASSERT_EQUAL(prison.treasury_debt(), 0, "The off-outpost check charged a recovery fee for the spaced horror")
	TEST_ASSERT_EQUAL(treasury.account_balance, balance + 3900, "The second spaced horror paid [treasury.account_balance - balance] cr, not 3900")

	breach.change_area(home.outpost_area, space_area)
	deck.ChangeTurf(/turf/open/space/basic)
	settle_prison_air(home)

// ===== FIRE =====

/datum/unit_test/voidcrew_outpost_prison_changeling_fire
	parent_type = /datum/unit_test/voidcrew_outpost_management

/// A specimen taken straight to the horror by the admin stage, standing and free in the yard
/datum/unit_test/voidcrew_outpost_prison_changeling_fire/proc/horror_for(datum/outpost_prison/prison, obj/structure/overmap/dynamic/player_outpost/home)
	var/datum/outpost_changeling_event/event = changeling_host(prison, home)
	if(!event?.force_stage("horror"))
		return null
	var/mob/living/basic/outpost_experiment/horror/horror = event.horror
	horror.clear_busy()
	horror.forceMove(prison_spot(home, 9, 9))
	return horror

/datum/unit_test/voidcrew_outpost_prison_changeling_fire/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("fireowner")
	TEST_ASSERT_NOTNULL(home, "The fire test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.crew_home_override = TRUE
	var/mob/living/carbon/human/crew = make_player(prison_spot(home, 12, 3), "fireowner")
	var/mob/living/basic/outpost_experiment/horror/horror = horror_for(prison, home)
	TEST_ASSERT_NOTNULL(horror, "The admin horror stage made no horror")
	var/datum/outpost_changeling_event/event = horror.event
	var/datum/component/experiment_damage_ledger/ledger = horror.GetComponent(/datum/component/experiment_damage_ledger)
	TEST_ASSERT(findtext(jointext(horror.examine(crew), " "), "shies away from fire"), "Examining the horror does not say it shies away from fire")

	// A laser's burn gets the chitin's 0.85, as brute does.
	var/before = horror.health
	horror.apply_damage(10, BURN)
	TEST_ASSERT(abs(before - horror.health - 8.5) < 0.01, "10 burn took [before - horror.health] health, not 8.5") // OUTPOST_HORROR_DAMAGE_COEFF
	before = horror.health
	horror.apply_damage(10, BRUTE)
	TEST_ASSERT(abs(before - horror.health - 8.5) < 0.01, "10 brute took [before - horror.health] health, not 8.5") // OUTPOST_HORROR_DAMAGE_COEFF

	// Fire on its tile lights it, and burning hurts it: 5 a second, doubled. Nobody lit it or hurt it, so it is nobody's.
	horror.fire_act(1000, 500)
	TEST_ASSERT(horror.on_fire, "Fire on its tile did not set the horror alight")
	var/datum/status_effect/fire_handler/fire_stacks/burning = horror.has_status_effect(/datum/status_effect/fire_handler/fire_stacks)
	TEST_ASSERT_NOTNULL(burning, "The burning horror has no fire on it")
	before = horror.health
	burning.tick(2)
	TEST_ASSERT(abs(before - horror.health - 20) < 0.01, "Two seconds alight took [before - horror.health] health, not 20") // OUTPOST_HORROR_FIRE_DAMAGE, OUTPOST_HORROR_FIRE_MULT
	TEST_ASSERT(horror.on_fire, "A lick of flame went out within two seconds") // OUTPOST_HORROR_FIRE_DECAY
	TEST_ASSERT_EQUAL(ledger.player_damage, 0, "Fire nobody lit counted as the crew's")
	horror.extinguish_mob()

	// Down and burning, its body goes twice as fast: 200 in 10 s, where it took 20.
	TEST_ASSERT(horror.start_regenerating(), "The horror would not go down")
	horror.adjust_fire_stacks(20)
	horror.ignite_mob()
	TEST_ASSERT(horror.on_fire, "The horror's body would not catch fire")
	changeling_ticks(event, 5)
	TEST_ASSERT(abs(horror.remains - 100) < 0.01, "Five seconds alight left [horror.remains] of its body, not 100") // OUTPOST_HORROR_REMAINS less 5 * OUTPOST_HORROR_REMAINS_BURN * OUTPOST_HORROR_FIRE_MULT
	changeling_ticks(event, 4)
	TEST_ASSERT(!QDELETED(horror) && horror.regenerating, "The burning body was destroyed before 10 s")
	changeling_ticks(event, 1)
	TEST_ASSERT(QDELETED(horror), "The burning body was not destroyed after 10 s")
	TEST_ASSERT_EQUAL(event.stage, "done", "Burning its body away did not end the changeling event")
	TEST_ASSERT_EQUAL(prison.experiment.stage, "contained", "Burning its body away did not contain the horror")

	// Fire is the crew's for the containment bonus. A second horror, last hurt by the crew 31 s ago: its burning is nobody's.
	var/mob/living/basic/outpost_experiment/horror/torched = horror_for(prison, home)
	TEST_ASSERT_NOTNULL(torched, "The second horror did not come out")
	var/datum/outpost_changeling_event/second_event = torched.event
	var/datum/component/experiment_damage_ledger/torched_ledger = torched.GetComponent(/datum/component/experiment_damage_ledger)
	torched_ledger.note_attacker(crew)
	torched_ledger.last_attack_time -= 31 SECONDS
	torched_ledger.last_player_time -= 31 SECONDS
	TEST_ASSERT(torched.take_fire_damage(5) > 0, "Fire did not hurt the second horror")
	TEST_ASSERT_EQUAL(torched_ledger.player_damage, 0, "Fire 31 s after the crew last hurt it counted as the crew's") // OUTPOST_HORROR_FIRE_CREDIT_WINDOW
	// Hurt by the crew 10 s ago, it is theirs.
	torched_ledger.last_player_time = world.time - 10 SECONDS
	torched.take_fire_damage(5)
	TEST_ASSERT(abs(torched_ledger.player_damage - 10) < 0.01, "Fire 10 s after the crew hurt it was [torched_ledger.player_damage] crew damage, not 10") // OUTPOST_HORROR_FIRE_MULT
	torched_ledger.last_player_time = world.time - 31 SECONDS

	// Set alight by a flamethrower the crew just aimed at it: theirs however long it burns, and burned down, it pays in full.
	var/obj/item/flamethrower/flamer = allocate(/obj/item/flamethrower)
	flamer.lit = TRUE
	SEND_SIGNAL(torched, COMSIG_ATOM_RANGED_ITEM_INTERACTION, crew, flamer, list())
	torched.fire_act(1000, 500)
	TEST_ASSERT(torched.on_fire, "The flamethrower's fire did not set the horror alight")
	TEST_ASSERT_EQUAL(torched.igniter_ref?.resolve(), crew, "The horror does not know who set it alight")
	torched.fire_aimed_at -= 31 SECONDS
	for(var/i in 1 to 40)
		if(torched.regenerating)
			break
		torched.fire_act(1000, 500)
		var/datum/status_effect/fire_handler/fire_stacks/flames = torched.has_status_effect(/datum/status_effect/fire_handler/fire_stacks)
		flames?.tick(2)
	TEST_ASSERT(torched.regenerating, "Burning did not bring the second horror down")
	TEST_ASSERT(torched_ledger.player_share() > 0.9, "The horror burned down by the crew's fire is [torched_ledger.player_share()] the crew's damage")
	torched.adjust_fire_stacks(20)
	changeling_ticks(second_event, 10)
	TEST_ASSERT(QDELETED(torched), "The second horror's body did not burn away")
	TEST_ASSERT_EQUAL(prison.experiment.stage, "contained", "Burning the second horror away did not contain it")
	TEST_ASSERT_EQUAL(prison.experiment.bonus_paid, 3900, "A horror killed by a flamethrower paid [prison.experiment.bonus_paid], not 3900") // OUTPOST_EXPERIMENT_BONUS_HORROR
	settle_prison_air(home)
