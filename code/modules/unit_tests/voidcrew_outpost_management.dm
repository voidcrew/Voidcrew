/// The real confirmation boundary, with deterministic changes while the prompt is open.
/obj/machinery/computer/player_outpost_management/management_test
	var/datum/callback/during_confirmation
	var/confirmation_result = TRUE

/obj/machinery/computer/player_outpost_management/management_test/confirm_ownership_action(mob/user, prompt_text, title, confirm_label)
	during_confirmation?.Invoke()
	return confirmation_result

/// A second claim used only to retarget an already-open console during confirmation.
/obj/structure/overmap/dynamic/player_outpost/management_destination_test
	var/turf/service_turf

/obj/structure/overmap/dynamic/player_outpost/management_destination_test/contains_service_turf(turf/location)
	return location == service_turf

/datum/unit_test/voidcrew_outpost_management
	var/turf/visitor_turf
	var/area/original_visitor_area
	var/area/shuttle/voidcrew/visitor_area
	var/obj/docking_port/mobile/voidcrew/visitor_port
	var/list/test_player_keys = list()

/datum/unit_test/voidcrew_outpost_management/Destroy()
	GLOB.player_outpost_founder_ckeys -= test_player_keys
	// These offline keys simulate players without connecting a client to the test world.
	for(var/mob/player in allocated)
		if(!QDELETED(player))
			player.key = null
	if(visitor_turf && original_visitor_area)
		visitor_turf.change_area(get_area(visitor_turf), original_visitor_area)
	if(!QDELETED(visitor_port))
		if(visitor_port.current_ship)
			visitor_port.current_ship.shuttle = null
		visitor_port.current_ship = null
		qdel(visitor_port, force = TRUE)
	if(!QDELETED(visitor_area))
		visitor_area.shuttle_port = null
		qdel(visitor_area)
	return ..()

/datum/unit_test/voidcrew_outpost_management/proc/make_player(turf/location, player_key)
	var/mob/living/carbon/human/consistent/player = allocate(/mob/living/carbon/human/consistent, location)
	player.key = player_key
	player.mind_initialize()
	ADD_TRAIT(player, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, REF(src))
	test_player_keys |= player.ckey
	return player

/datum/unit_test/voidcrew_outpost_management/proc/act(obj/machinery/computer/player_outpost_management/console, mob/user, action, mob/candidate)
	var/datum/tgui/ui = allocate(/datum/tgui, user, console, "OutpostManagement")
	world.push_usr(user, CALLBACK(console, TYPE_PROC_REF(/datum, ui_act), action, list("ref" = REF(candidate)), ui))

/datum/unit_test/voidcrew_outpost_management/proc/set_owner(obj/structure/overmap/dynamic/player_outpost/home, owner_key)
	home.founder_ckey = owner_key

/datum/unit_test/voidcrew_outpost_management/proc/retarget_console(obj/machinery/computer/player_outpost_management/console, obj/structure/overmap/dynamic/player_outpost/management_destination_test/other, mob/user, mob/candidate)
	console.forceMove(other.service_turf)
	user.forceMove(other.service_turf)
	candidate.forceMove(other.service_turf)
	console.ui_data(user) // An ordinary UI refresh now resolves the other claim.

/datum/unit_test/voidcrew_outpost_management/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/small)
	home.founder_ckey = "managementowner"
	TEST_ASSERT(home.load_level(), "The management test home failed to load.")
	var/turf/console_turf = get_turf(home.management_console)
	var/obj/machinery/computer/player_outpost_management/management_test/console = allocate(__IMPLIED_TYPE__, console_turf)
	var/mob/living/carbon/human/owner = make_player(console_turf, "managementowner")
	var/turf/berth_turf = get_turf(home.freight_berth.panel)
	var/mob/living/carbon/human/resident = make_player(berth_turf, "managementresident")
	TEST_ASSERT(home.is_owner(owner), "The test actor is not the claim owner.")
	var/datum/action/innate/player_outpost_management/owner_action = grant_player_outpost_management(owner, home)
	TEST_ASSERT(owner_action && owner_action.managed_outpost == home, "The owner did not receive the claim-bound management action.")
	TEST_ASSERT_EQUAL(get_outpost_from_atom(resident), home, "The freight facility must belong to the claim.")
	TEST_ASSERT(!(resident in home.mapzone.get_mind_mobs_in(home.footprint)), "The freight candidate must exercise a facility outside the habitat footprint.")

	for(var/turf/open/floor/location in home.outpost_area)
		if(location != console_turf)
			visitor_turf = location
			break
	TEST_ASSERT_NOTNULL(visitor_turf, "No habitat floor was available for the visiting ship fixture.")
	original_visitor_area = get_area(visitor_turf)
	visitor_area = new
	visitor_turf.change_area(original_visitor_area, visitor_area)
	visitor_port = new(visitor_turf)
	visitor_port.width = 1
	visitor_port.height = 1
	visitor_port.dwidth = 0
	visitor_port.dheight = 0
	visitor_port.shuttle_areas = list()
	visitor_port.shuttle_areas[visitor_area] = TRUE
	visitor_area.shuttle_port = visitor_port
	visitor_port.register()
	var/obj/structure/overmap/ship/visitor_ship = allocate(__IMPLIED_TYPE__)
	visitor_ship.shuttle = visitor_port
	visitor_port.current_ship = visitor_ship
	var/mob/living/carbon/human/visitor = make_player(visitor_turf, "managementvisitor")
	TEST_ASSERT(visitor in home.mapzone.get_mind_mobs_in(home.footprint), "The visitor must exercise a ship inside the habitat footprint.")
	TEST_ASSERT_NULL(get_outpost_from_atom(visitor), "A visiting ship must remain outside claim service ownership.")

	var/list/data = console.ui_data(owner)
	var/list/candidate_keys = list()
	for(var/list/entry as anything in data["candidates"])
		candidate_keys |= entry["ckey"]
	TEST_ASSERT(resident.ckey in candidate_keys, "Management omitted a candidate in its freight facility.")
	TEST_ASSERT(!(visitor.ckey in candidate_keys), "Management listed a visiting ship's occupant as a claim candidate.")
	TEST_ASSERT(!(owner.ckey in candidate_keys), "The owner should not appear in their own candidate list.")
	act(console, owner, "add_builder", visitor)
	TEST_ASSERT(!(visitor.ckey in home.authorized_builder_ckeys), "A forged request authorized a visiting ship occupant.")
	act(console, owner, "add_builder", resident)
	TEST_ASSERT(resident.ckey in home.authorized_builder_ckeys, "The owner could not authorize a builder in the freight facility.")
	home.authorized_builder_ckeys.Cut()
	home.stewards |= visitor.mind
	grant_player_outpost_management(visitor, home)
	TEST_ASSERT(locate(/datum/action/innate/player_outpost_management) in visitor.actions, "A management delegate could not receive the remote management action.")
	act(console, visitor, "add_builder", resident)
	TEST_ASSERT(!(resident.ckey in home.authorized_builder_ckeys), "A steward gained owner-only builder delegation.")
	home.stewards -= visitor.mind
	refresh_player_outpost_management(home)
	TEST_ASSERT(!(locate(/datum/action/innate/player_outpost_management) in visitor.actions), "Revoking a management delegate left a stale action button.")
	resident.stat = DEAD
	TEST_ASSERT(!home.is_management_candidate(resident), "A dead body became an eligible management candidate.")
	resident.stat = CONSCIOUS
	var/mob/living/carbon/human/mindless = allocate(/mob/living/carbon/human/consistent, berth_turf)
	mindless.key = "managementmindless"
	TEST_ASSERT(!home.is_management_candidate(mindless), "A keyed body without a mind became an eligible candidate.")

	console.during_confirmation = CALLBACK(resident, TYPE_PROC_REF(/atom/movable, forceMove), run_loc_floor_bottom_left)
	act(console, owner, "transfer", resident)
	TEST_ASSERT(home.is_owner(owner), "A transfer completed after its candidate left the claim.")
	resident.forceMove(berth_turf)
	console.during_confirmation = CALLBACK(src, PROC_REF(set_owner), home, "managementreplacement")
	act(console, owner, "transfer", resident)
	TEST_ASSERT_EQUAL(home.founder_ckey, "managementreplacement", "A stale owner completed a transfer after losing authority.")
	home.founder_ckey = owner.ckey
	act(console, owner, "abandon", null)
	TEST_ASSERT_EQUAL(home.founder_ckey, "managementreplacement", "A stale owner abandoned the claim after losing authority.")
	home.founder_ckey = owner.ckey

	var/obj/structure/overmap/dynamic/player_outpost/management_destination_test/other = allocate(__IMPLIED_TYPE__)
	other.service_turf = run_loc_floor_bottom_left
	other.founder_ckey = owner.ckey // Retargeting must fail even if the new site's owner check passes.
	console.during_confirmation = CALLBACK(src, PROC_REF(retarget_console), console, other, owner, resident)
	act(console, owner, "transfer", resident)
	TEST_ASSERT_EQUAL(console.outpost, other, "The confirmation fixture did not retarget the console.")
	TEST_ASSERT(home.is_owner(owner) && other.is_owner(owner), "A stale transfer changed ownership after the console moved to another claim.")
	console.forceMove(console_turf)
	owner.forceMove(console_turf)
	resident.forceMove(berth_turf)
	console.ui_data(owner)
	act(console, owner, "abandon", resident)
	TEST_ASSERT(home.is_owner(owner) && other.is_owner(owner), "A stale abandonment affected a claim after the console moved.")
	console.forceMove(console_turf)
	owner.forceMove(console_turf)
	resident.forceMove(berth_turf)
	console.ui_data(owner)
	console.during_confirmation = null
	console.confirmation_result = FALSE
	act(console, owner, "transfer", resident)
	TEST_ASSERT(home.is_owner(owner), "Cancelling the confirmation still transferred ownership.")
	console.confirmation_result = TRUE
	act(console, owner, "transfer", resident)
	TEST_ASSERT(home.is_owner(resident), "A valid transfer to the freight-facility candidate failed.")
	TEST_ASSERT(resident.mind in home.residents, "A valid transfer did not retain resident membership.")
	resident.forceMove(console_turf)
	act(console, resident, "abandon", null)
	TEST_ASSERT_NULL(home.founder_ckey, "A valid owner could not abandon their claim.")
