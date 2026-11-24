/**
 * Outpost police soak: the rules themselves. The soak's invariants (voidcrew_outpost_police_soak_invariants.dm) only
 * help if they fire when an officer does the wrong thing, and seven of them had never fired in any run. Each test
 * here builds the wrong situation by hand in the walled room of voidcrew_stealth_live, runs the rule's check() the
 * way the soak's sampler does, and expects a break; then puts the situation right and expects none.
 *
 * States are set by hand on purpose: these tests are about the rules, not the police. Nothing sleeps, so no AI or
 * police tick moves anything between the checks. A condition that "held for a minute" is the sampler's clock wound
 * back a minute between two checks (breaks_after()).
 * Written out: "alert", "unaware" (STEALTH_*); "stealth_state" is BB_STEALTH_STATE; heat 25 is two stars.
 */

/// A soak run with no outpost of its own: the rules check a test room's police, and the breaks are kept, not reported
/datum/police_soak/rule_probe

/datum/police_soak/rule_probe/New(datum/unit_test/new_test, datum/outpost_police/new_police)
	. = ..(new_test, "rule", null, /datum/police_soak_scenario)
	police = new_police
	started_at = world.time

/datum/unit_test/voidcrew_stealth_live/police/soak_rule
	abstract_type = /datum/unit_test/voidcrew_stealth_live/police/soak_rule
	var/datum/police_soak/rule_probe/probe
	/// Cells made by hand, taken off the police at the end
	var/list/datum/outpost_police_cell/made_cells = list()

/datum/unit_test/voidcrew_stealth_live/police/soak_rule/Destroy()
	for(var/datum/outpost_police_cell/cell as anything in made_cells)
		police?.cells -= cell
		qdel(cell)
	made_cells.Cut()
	QDEL_NULL(probe)
	return ..()

/// The room (16 by 5) and the probe. FALSE if there is no room.
/datum/unit_test/voidcrew_stealth_live/police/soak_rule/proc/rule_room()
	if(!police_room(16, 5))
		return FALSE
	probe = new(src, police)
	return TRUE

/// Someone with a mind at (dx, dy), wanted at `heat` and last seen where they stand
/datum/unit_test/voidcrew_stealth_live/police/soak_rule/proc/wanted_visitor(dx, dy, heat = 25)
	var/mob/living/carbon/human/person = visitor_at(dx, dy)
	police_pin_warrant(police, person.mind, heat)
	police.note_seen(person.mind, get_turf(person))
	return person

/// A cell made by hand round `body`'s tile, holding them
/datum/unit_test/voidcrew_stealth_live/police/soak_rule/proc/jail(mob/living/body)
	var/datum/outpost_police_cell/cell = new(police, "soak_rule_cell")
	cell.tiles += get_turf(body)
	cell.prisoners[body.mind] = world.time + 10 MINUTES
	police.cells += cell
	made_cells += cell
	return cell

/// `officer`'s stealth state and target, set by hand
/datum/unit_test/voidcrew_stealth_live/police/soak_rule/proc/set_mind(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, state, mob/living/target)
	var/datum/ai_controller/brain = officer.ai_controller
	brain.set_blackboard_key("stealth_state", state)
	if(target)
		brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, target)
	else
		brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)

/**
 * The breaks `rule_type` reports once the situation as it stands has held for `seconds`, as the sampler would see
 * it: one check to start its clocks, the clocks wound back, a second check. The texts of its breaks.
 */
/datum/unit_test/voidcrew_stealth_live/police/soak_rule/proc/breaks_after(rule_type, seconds = 60)
	probe.breaks.Cut()
	probe.break_keys.Cut()
	probe.held_since.Cut()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police.officers)
		var/datum/police_soak_track/found = probe.track(officer)
		found?.scene_dists.Cut()
	var/datum/police_soak_invariant/rule = new rule_type
	rule.check(probe)
	for(var/key in probe.held_since)
		probe.held_since[key] -= seconds SECONDS
	for(var/mob/living/body as anything in probe.tracks)
		var/datum/police_soak_track/found = probe.tracks[body]
		found.moved_at -= seconds SECONDS
	rule.check(probe)
	. = list()
	for(var/list/found as anything in probe.breaks)
		if(found["name"] == rule.name)
			. += found["text"]
	qdel(rule)

// ----- alert_on_custody -----

/datum/unit_test/voidcrew_stealth_live/police/soak_rule/alert_on_custody

/datum/unit_test/voidcrew_stealth_live/police/soak_rule/alert_on_custody/Run()
	TEST_ASSERT(rule_room(), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(2, 2, EAST)
	var/mob/living/carbon/human/prisoner = wanted_visitor(5, 2)
	// Alert on them while they were at large (the police brain refuses anyone in hand as a new target), and still so
	// once they are in a cell
	set_mind(officer, "alert", prisoner)
	jail(prisoner)
	TEST_ASSERT(police.in_custody(prisoner), "The prisoner in a cell made by hand is not in custody")
	TEST_ASSERT(probe.minds(officer, prisoner), "Fixture: the officer does not have the prisoner in mind")
	TEST_ASSERT_EQUAL(probe.state_of(officer), "alert", "Fixture: the officer is not alert")
	var/list/found = breaks_after(/datum/police_soak_invariant/alert_on_custody)
	TEST_ASSERT(length(found), "alert_on_custody stayed quiet about an officer alert on someone in a cell for a minute")
	// Alert on someone at large is the officer's work
	var/mob/living/carbon/human/free = wanted_visitor(8, 2)
	set_mind(officer, "alert", free)
	found = breaks_after(/datum/police_soak_invariant/alert_on_custody)
	TEST_ASSERT(!length(found), "alert_on_custody fired on an officer alert on someone at large: [jointext(found, "; ")]")

// ----- wanted_ignored -----

/datum/unit_test/voidcrew_stealth_live/police/soak_rule/wanted_ignored

/datum/unit_test/voidcrew_stealth_live/police/soak_rule/wanted_ignored/Run()
	TEST_ASSERT(rule_room(), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(1, 2, WEST)
	var/mob/living/carbon/human/suspect = wanted_visitor(14, 2)
	TEST_ASSERT(length(probe.at_large()), "A two-star visitor in the room is not at large at the room's outpost")
	TEST_ASSERT(!police.perception.sees(officer, suspect), "The officer facing away sees the suspect thirteen tiles behind it")
	var/list/found = breaks_after(/datum/police_soak_invariant/wanted_ignored)
	TEST_ASSERT(length(found), "wanted_ignored stayed quiet about a wanted person nobody saw or went to for a minute")
	// An officer standing near where they were last seen is attending
	officer.forceMove(at(9, 2))
	found = breaks_after(/datum/police_soak_invariant/wanted_ignored)
	TEST_ASSERT(!length(found), "wanted_ignored fired with an officer five tiles from the last sighting: [jointext(found, "; ")]")

// ----- calm_in_sight -----

/datum/unit_test/voidcrew_stealth_live/police/soak_rule/calm_in_sight

/datum/unit_test/voidcrew_stealth_live/police/soak_rule/calm_in_sight/Run()
	TEST_ASSERT(rule_room(), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(2, 2, EAST)
	var/mob/living/carbon/human/suspect = wanted_visitor(5, 2)
	set_mind(officer, "unaware", null)
	TEST_ASSERT(police.perception.sees(officer, suspect), "The officer does not see the suspect three tiles in front of it")
	TEST_ASSERT(!police.arrest_on(suspect), "An arrest is open on the suspect")
	var/list/found = breaks_after(/datum/police_soak_invariant/calm_in_sight)
	TEST_ASSERT(length(found), "calm_in_sight stayed quiet about an officer calm for a minute with a wanted person in sight")
	// An officer alert on them is not calm
	set_mind(officer, "alert", suspect)
	found = breaks_after(/datum/police_soak_invariant/calm_in_sight)
	TEST_ASSERT(!length(found), "calm_in_sight fired on an officer alert on the wanted person it sees: [jointext(found, "; ")]")

// ----- downed_unattended -----

/datum/unit_test/voidcrew_stealth_live/police/soak_rule/downed_unattended

/datum/unit_test/voidcrew_stealth_live/police/soak_rule/downed_unattended/Run()
	TEST_ASSERT(rule_room(), "No room for the test")
	officer_at(2, 2, EAST)
	var/mob/living/carbon/human/suspect = wanted_visitor(5, 2)
	suspect.Paralyze(5 MINUTES)
	TEST_ASSERT(police_suspect_down(suspect), "A paralysed suspect is not down to the police")
	TEST_ASSERT(length(probe.at_large()), "A downed suspect with no arrest on them is not at large")
	var/list/found = breaks_after(/datum/police_soak_invariant/downed_unattended)
	TEST_ASSERT(length(found), "downed_unattended stayed quiet about a downed wanted person three tiles from an officer with no arrest for a minute")
	// On their feet, nobody has anything to cuff
	suspect.SetParalyzed(0)
	TEST_ASSERT(!police_suspect_down(suspect), "The suspect is still down")
	found = breaks_after(/datum/police_soak_invariant/downed_unattended)
	TEST_ASSERT(!length(found), "downed_unattended fired on a suspect on their feet: [jointext(found, "; ")]")

// ----- cuffed_and_left -----

/datum/unit_test/voidcrew_stealth_live/police/soak_rule/cuffed_and_left

/datum/unit_test/voidcrew_stealth_live/police/soak_rule/cuffed_and_left/Run()
	TEST_ASSERT(rule_room(), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(2, 2, EAST)
	var/mob/living/carbon/human/suspect = wanted_visitor(10, 2)
	suspect.equip_to_slot(allocate(/obj/item/restraints/handcuffs/outpost_police/used), ITEM_SLOT_HANDCUFFED)
	TEST_ASSERT(istype(suspect.handcuffed, /obj/item/restraints/handcuffs/outpost_police), "The suspect is not in police cuffs")
	var/list/found = breaks_after(/datum/police_soak_invariant/cuffed_and_left)
	TEST_ASSERT(length(found), "cuffed_and_left stayed quiet about someone in police cuffs eight tiles from any officer for a minute")
	// An officer beside them
	officer.forceMove(at(9, 2))
	found = breaks_after(/datum/police_soak_invariant/cuffed_and_left)
	TEST_ASSERT(!length(found), "cuffed_and_left fired with an officer beside the cuffed person: [jointext(found, "; ")]")

// ----- cuffed_in_cell -----

/datum/unit_test/voidcrew_stealth_live/police/soak_rule/cuffed_in_cell

/datum/unit_test/voidcrew_stealth_live/police/soak_rule/cuffed_in_cell/Run()
	TEST_ASSERT(rule_room(), "No room for the test")
	officer_at(2, 2, EAST)
	var/mob/living/carbon/human/prisoner = wanted_visitor(10, 2)
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	prisoner.equip_to_slot(cuffs, ITEM_SLOT_HANDCUFFED)
	jail(prisoner)
	var/list/found = breaks_after(/datum/police_soak_invariant/cuffed_in_cell)
	TEST_ASSERT(length(found), "cuffed_in_cell stayed quiet about a prisoner in a cell with the cuffs on for a minute")
	// The cuffs off
	prisoner.dropItemToGround(cuffs, force = TRUE)
	TEST_ASSERT(!prisoner.handcuffed, "The cuffs did not come off")
	found = breaks_after(/datum/police_soak_invariant/cuffed_in_cell)
	TEST_ASSERT(!length(found), "cuffed_in_cell fired on a prisoner with the cuffs off: [jointext(found, "; ")]")

// ----- paused_with_work -----

/datum/unit_test/voidcrew_stealth_live/police/soak_rule/paused_with_work

/datum/unit_test/voidcrew_stealth_live/police/soak_rule/paused_with_work/Run()
	TEST_ASSERT(rule_room(), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(2, 2, EAST)
	var/mob/living/carbon/human/suspect = wanted_visitor(10, 2)
	ADD_TRAIT(officer, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)
	var/list/found = breaks_after(/datum/police_soak_invariant/paused_with_work)
	TEST_ASSERT(length(found), "paused_with_work stayed quiet about an officer held still for a minute with someone wanted at large")
	// Nobody wanted: an officer held still has no work waiting
	police_pin_warrant(police, suspect.mind, 0)
	TEST_ASSERT(!length(probe.at_large()), "Someone at no heat is still at large")
	found = breaks_after(/datum/police_soak_invariant/paused_with_work)
	REMOVE_TRAIT(officer, TRAIT_AI_PAUSED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!length(found), "paused_with_work fired with nobody wanted: [jointext(found, "; ")]")

// ----- door_loiter: an officer of an arrest in a checkpoint doorway beside its suspect -----
// Pass 3: the two officers of an arrest swap parts as it goes. The one left covering, in the doorway of the scanner
// room with the suspect cuffed on the one tile outside it, has no other tile beside them to go to (Halcyon
// gate_emag_step_in, second 20). Before, the rule spared only the arresting officer.

/datum/unit_test/voidcrew_stealth_live/police/soak_rule/door_loiter_cover

/datum/unit_test/voidcrew_stealth_live/police/soak_rule/door_loiter_cover/Run()
	TEST_ASSERT(rule_room(), "No room for the test")
	allocate(/obj/machinery/door/airlock/outpost/checkpoint, at(6, 2))
	var/mob/living/carbon/human/suspect = wanted_visitor(7, 2)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/arresting = officer_at(8, 2, WEST)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/covering = officer_at(6, 2, EAST)
	var/datum/outpost_police_case/case = police.open_case(police.get_warrant(suspect.mind))
	police.sleep_tick()
	TEST_ASSERT(case, "Fixture: no arrest opened on the suspect")
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police.officers)
		officer.case = null
	case.officers = list(WEAKREF(arresting), WEAKREF(covering))
	arresting.case = case
	covering.case = case
	TEST_ASSERT_EQUAL(case.cover(), covering, "Fixture: the officer in the doorway is not the arrest's cover")
	var/list/found = breaks_after(/datum/police_soak_invariant/door_loiter)
	TEST_ASSERT(!length(found), "door_loiter fired on the cover officer of an arrest in a doorway beside its suspect: [jointext(found, "; ")]")
	// With the suspect away from the doorway, standing in it is loitering again
	suspect.forceMove(at(11, 2))
	police.note_seen(suspect.mind, get_turf(suspect))
	found = breaks_after(/datum/police_soak_invariant/door_loiter)
	TEST_ASSERT(length(found), "door_loiter stayed quiet about the cover officer standing in a doorway for a minute, four tiles from its suspect")
