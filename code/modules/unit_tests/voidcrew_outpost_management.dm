/// The real confirmation boundary, with deterministic changes while the prompt is open.
/datum/player_outpost_management_ui/management_test
	var/datum/callback/during_confirmation
	var/confirmation_result = TRUE

/datum/player_outpost_management_ui/management_test/confirm_ownership_action(mob/user, prompt_text, title, confirm_label)
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

/datum/unit_test/voidcrew_outpost_management/Destroy()
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
	return player

/datum/unit_test/voidcrew_outpost_management/proc/act(datum/player_outpost_management_ui/panel, mob/user, action, datum/candidate, list/extra_params = list())
	var/list/params = list("ref" = REF(candidate))
	params += extra_params
	var/datum/tgui/ui = allocate(/datum/tgui, user, panel, "OutpostManagement")
	world.push_usr(user, CALLBACK(panel, TYPE_PROC_REF(/datum, ui_act), action, params, ui))

/datum/unit_test/voidcrew_outpost_management/proc/set_owner(obj/structure/overmap/dynamic/player_outpost/home, owner_key)
	home.founder_ckey = owner_key

/datum/unit_test/voidcrew_outpost_management/proc/retarget_console(datum/player_outpost_management_ui/panel, obj/machinery/computer/player_outpost_management/console, obj/structure/overmap/dynamic/player_outpost/management_destination_test/other, mob/user, mob/candidate)
	console.forceMove(other.service_turf)
	user.forceMove(other.service_turf)
	candidate.forceMove(other.service_turf)
	panel.ui_data(user) // The claim-bound panel must not retarget to the moved console.

/datum/unit_test/voidcrew_outpost_management/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/small)
	home.founder_ckey = "managementowner"
	TEST_ASSERT(home.load_level(), "The management test home failed to load.")
	var/turf/console_turf = get_turf(home.management_console)
	var/obj/machinery/computer/player_outpost_management/console = allocate(__IMPLIED_TYPE__, console_turf)
	var/mob/living/carbon/human/owner = make_player(console_turf, "managementowner")
	var/datum/player_outpost_management_ui/management_test/console_panel = allocate(__IMPLIED_TYPE__, home, owner, console)
	var/datum/player_outpost_management_ui/management_test/physical_panel = allocate(__IMPLIED_TYPE__, home, owner, console)
	var/turf/berth_turf = get_turf(home.freight_berth.panel)
	var/mob/living/carbon/human/resident = make_player(berth_turf, "managementresident")
	TEST_ASSERT(home.is_owner(owner), "The test actor is not the claim owner.")
	act(console_panel, owner, "buy_advert", null)
	TEST_ASSERT_NULL(home.current_advert, "An unfunded broadcast went live")
	var/list/broadcast_data = console_panel.ui_data(owner)
	TEST_ASSERT_EQUAL(broadcast_data["advert_denial"], "Insufficient outpost funds", "An unfunded broadcast gave no visible rejection reason")
	home.treasury.adjust_money(2500, "Broadcast fixture") // OUTPOST_ADVERT_COST; fork defines follow test includes.
	TEST_ASSERT_NULL(console_panel.advert_denial(owner), "Funding the treasury left stale broadcast rejection feedback")
	TEST_ASSERT_EQUAL(console_panel.advert_denial(resident), "Treasury permission required", "Missing treasury authority gave no broadcast rejection reason")
	act(console_panel, owner, "buy_advert", null)
	TEST_ASSERT_NOTNULL(home.current_advert, "A funded authorized broadcast did not start")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 0, "A broadcast charged the wrong amount")
	TEST_ASSERT_EQUAL(console_panel.advert_denial(owner), "Broadcast already live", "An active broadcast gave no feedback")
	TEST_ASSERT(!console_panel.buy_advert(owner), "A duplicate broadcast was accepted")
	qdel(home.current_advert)
	TEST_ASSERT(findtext(console_panel.advert_denial(owner), "Ready in ") == 1, "Broadcast cooldown gave no feedback")
	var/datum/player_outpost_management_ui/unbound_panel = allocate(__IMPLIED_TYPE__, home, owner)
	TEST_ASSERT_EQUAL(unbound_panel.ui_status(owner, GLOB.always_state), UI_CLOSE, "A management panel without a console or implant granted remote access.")
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
	SSovermap.simulated_ships |= visitor_ship
	visitor_ship.shuttle = visitor_port
	visitor_port.current_ship = visitor_ship
	var/mob/living/carbon/human/visitor = make_player(visitor_turf, "managementvisitor")
	TEST_ASSERT(visitor in home.mapzone.get_mind_mobs_in(home.footprint), "The visitor must exercise a ship inside the habitat footprint.")
	TEST_ASSERT_NULL(get_outpost_from_atom(visitor), "A visiting ship must remain outside claim service ownership.")

	// Management sends ship invitations before the crew has built a relay.
	var/obj/machinery/rnd/server/ship/research_server = allocate(__IMPLIED_TYPE__, console_turf)
	var/obj/item/computer_disk/ship_disk/research_disk = allocate(__IMPLIED_TYPE__, console_turf)
	research_server.attacked_by(research_disk, owner)
	var/old_ship_state = visitor_ship.state
	visitor_ship.docked = home
	visitor_ship.state = "idle"
	var/list/invite_params = list("ship" = REF(visitor_ship), "server" = REF(research_server))
	act(console_panel, owner, "invite_research", null, invite_params)
	TEST_ASSERT_EQUAL(length(home.research_links), 1, "Management could not invite a docked ship without a relay")
	var/datum/outpost_research_link/invitation = home.research_links[1]
	TEST_ASSERT_EQUAL(invitation.ship_ref.resolve(), visitor_ship, "Management invited the wrong ship")
	TEST_ASSERT_NULL(invitation.ship_relay, "Sending an invitation invented a ship relay")
	act(console_panel, owner, "invite_research", null, invite_params)
	TEST_ASSERT_EQUAL(length(home.research_links), 1, "Repeated management clicks duplicated a pending invitation")
	act(physical_panel, visitor, "revoke_research", invitation)
	TEST_ASSERT(!QDELETED(invitation), "A visitor revoked the outpost's research invitation")
	visitor_ship.docked = null
	act(console_panel, owner, "invite_research", null, invite_params)
	TEST_ASSERT_NOTNULL(console_panel.research_error, "Inviting a departed ship gave no rejection feedback")
	act(console_panel, owner, "revoke_research", invitation)
	TEST_ASSERT(QDELETED(invitation), "Management could not cancel a pending invitation")
	TEST_ASSERT_EQUAL(length(home.research_links), 0, "Cancellation retained the pending invitation")
	visitor_ship.state = old_ship_state

	var/list/data = console_panel.ui_data(owner)
	var/list/candidate_keys = list()
	for(var/list/entry as anything in data["candidates"])
		candidate_keys |= entry["ckey"]
	TEST_ASSERT(resident.ckey in candidate_keys, "Management omitted a candidate in its freight facility.")
	TEST_ASSERT(!(visitor.ckey in candidate_keys), "Management listed a visiting ship's occupant as a claim candidate.")
	TEST_ASSERT(!(owner.ckey in candidate_keys), "The owner should not appear in their own candidate list.")
	act(console_panel, owner, "add_builder", visitor)
	TEST_ASSERT(!(visitor.ckey in home.authorized_builder_ckeys), "A forged request authorized a visiting ship occupant.")
	act(console_panel, owner, "add_builder", resident)
	TEST_ASSERT(resident.ckey in home.authorized_builder_ckeys, "The owner could not authorize a builder in the freight facility.")
	home.authorized_builder_ckeys.Cut()
	home.residents |= visitor.mind
	act(console_panel, owner, "delegate", visitor.mind, list("role" = "steward"))
	TEST_ASSERT(visitor.mind in home.stewards, "The owner could not delegate management through the console.")
	visitor.forceMove(console_turf)
	var/datum/player_outpost_management_ui/management_test/delegate_panel = allocate(__IMPLIED_TYPE__, home, visitor, console)
	TEST_ASSERT_EQUAL(delegate_panel.ui_status(visitor, GLOB.always_state), UI_INTERACTIVE, "A management delegate could not use the physical console.")
	act(delegate_panel, visitor, "remove_resident", visitor.mind)
	TEST_ASSERT(visitor.mind in home.residents, "A steward removed themselves from the resident list")
	TEST_ASSERT(visitor.mind in home.stewards, "Refusing self-removal revoked the steward's authority")
	home.residents |= owner.mind
	act(console_panel, owner, "remove_resident", owner.mind)
	TEST_ASSERT(owner.mind in home.residents, "An owner removed themselves from the resident list")
	act(delegate_panel, visitor, "add_builder", resident)
	TEST_ASSERT(!(resident.ckey in home.authorized_builder_ckeys), "A steward gained owner-only builder delegation.")
	act(console_panel, owner, "delegate", visitor.mind, list("role" = "steward"))
	TEST_ASSERT(!(visitor.mind in home.stewards), "The owner could not revoke management through the console.")
	TEST_ASSERT_EQUAL(delegate_panel.ui_status(visitor, GLOB.always_state), UI_UPDATE, "Revoking management authority left the console interactive.")
	act(console_panel, owner, "remove_resident", visitor.mind)
	TEST_ASSERT(!(visitor.mind in home.residents), "Self-removal protection prevented removing another resident")
	resident.stat = DEAD
	TEST_ASSERT(!home.is_management_candidate(resident), "A dead body became an eligible management candidate.")
	resident.stat = CONSCIOUS
	var/mob/living/carbon/human/mindless = allocate(/mob/living/carbon/human/consistent, berth_turf)
	mindless.key = "managementmindless"
	TEST_ASSERT(!home.is_management_candidate(mindless), "A keyed body without a mind became an eligible candidate.")

	console_panel.during_confirmation = CALLBACK(resident, TYPE_PROC_REF(/atom/movable, forceMove), run_loc_floor_bottom_left)
	act(console_panel, owner, "transfer", resident)
	TEST_ASSERT(home.is_owner(owner), "A transfer completed after its candidate left the claim.")
	resident.forceMove(berth_turf)
	console_panel.during_confirmation = CALLBACK(src, PROC_REF(set_owner), home, "managementreplacement")
	act(console_panel, owner, "transfer", resident)
	TEST_ASSERT_EQUAL(home.founder_ckey, "managementreplacement", "A stale owner completed a transfer after losing authority.")
	home.founder_ckey = owner.ckey
	act(console_panel, owner, "abandon", null)
	TEST_ASSERT_EQUAL(home.founder_ckey, "managementreplacement", "A stale owner abandoned the claim after losing authority.")
	home.founder_ckey = owner.ckey

	var/obj/structure/overmap/dynamic/player_outpost/management_destination_test/other = allocate(__IMPLIED_TYPE__)
	other.service_turf = run_loc_floor_bottom_left
	other.founder_ckey = owner.ckey // Retargeting must fail even if the new site's owner check passes.
	physical_panel.during_confirmation = CALLBACK(src, PROC_REF(retarget_console), physical_panel, console, other, owner, resident)
	act(physical_panel, owner, "transfer", resident)
	TEST_ASSERT_EQUAL(physical_panel.outpost, home, "The claim-bound physical panel retargeted after its console moved.")
	TEST_ASSERT(home.is_owner(owner) && other.is_owner(owner), "A stale transfer changed ownership after the console moved to another claim.")
	console.forceMove(console_turf)
	owner.forceMove(console_turf)
	resident.forceMove(berth_turf)
	act(physical_panel, owner, "abandon", resident)
	TEST_ASSERT(home.is_owner(owner) && other.is_owner(owner), "A stale abandonment affected a claim after the console moved.")
	console.forceMove(console_turf)
	owner.forceMove(console_turf)
	resident.forceMove(berth_turf)
	physical_panel.during_confirmation = null
	physical_panel.confirmation_result = FALSE
	act(physical_panel, owner, "transfer", resident)
	TEST_ASSERT(home.is_owner(owner), "Cancelling the confirmation still transferred ownership.")
	physical_panel.confirmation_result = TRUE
	act(physical_panel, owner, "transfer", resident)
	TEST_ASSERT(home.is_owner(resident), "A valid transfer to the freight-facility candidate failed.")
	TEST_ASSERT(resident.mind in home.residents, "A valid transfer did not retain resident membership.")
	resident.forceMove(console_turf)
	var/datum/player_outpost_management_ui/management_test/resident_panel = allocate(__IMPLIED_TYPE__, home, resident, console)
	act(resident_panel, resident, "abandon", null)
	TEST_ASSERT_NULL(home.founder_ckey, "A valid owner could not abandon their claim.")
	var/datum/bank_account/retained_account = home.treasury
	var/datum/player_outpost_management_ui/management_test/claim_panel = allocate(__IMPLIED_TYPE__, home, resident, home.management_console)
	var/list/claim_data = claim_panel.ui_data(resident)
	TEST_ASSERT(claim_data["can_claim"], "An abandoned outpost did not expose its local claim action")
	act(claim_panel, resident, "rename", null, list("name" = "Unauthorized rename"))
	TEST_ASSERT(home.name != "Unauthorized rename", "An unowned site's claim interface allowed management before claiming")
	var/datum/player_outpost_management_ui/management_test/unbound_claim_panel = allocate(__IMPLIED_TYPE__, home, resident)
	act(unbound_claim_panel, resident, "claim", null)
	TEST_ASSERT_NULL(home.founder_ckey, "An unbound remote panel claimed an abandoned site")
	act(claim_panel, resident, "claim", null)
	TEST_ASSERT(home.is_owner(resident), "A former owner could not reclaim the outpost at its terminal")
	TEST_ASSERT_EQUAL(home.treasury, retained_account, "Reclaiming replaced the existing bank account")
	TEST_ASSERT_EQUAL(home.resident_mode, "approved", "Reclaiming left all resident arrivals closed")
	TEST_ASSERT(home.home_bundle_installed, "Reclaiming removed the existing equipment")
	TEST_ASSERT(home.is_current_management_user(resident), "Claiming did not grant console management authority")
	TEST_ASSERT(!home.transfer_ownership(owner, owner), "Another visitor could take an already-owned outpost")

	// Remote access is supplied by installed hardware, never by claim ownership alone.
	TEST_ASSERT(!(locate(/datum/action/cooldown/cyberware/outpost_management) in resident.actions), "Claiming granted remote access without an implant")
	var/obj/item/organ/cyberimp/cyberware/registry_uplink/uplink = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(uplink.Insert(resident, special = TRUE), "Could not install the Registry uplink")
	var/datum/action/cooldown/cyberware/outpost_management/remote_action = locate() in resident.actions
	TEST_ASSERT_NOTNULL(remote_action, "The installed uplink did not grant its action")
	resident.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(remote_action.IsAvailable(), "The uplink did not work outside the outpost")
	var/datum/player_outpost_management_ui/remote_panel = uplink.get_management_panel(resident, home)
	TEST_ASSERT_NOTNULL(remote_panel, "The uplink did not open an authorized outpost")
	TEST_ASSERT_EQUAL(remote_panel.ui_status(resident, GLOB.always_state), UI_INTERACTIVE, "Remote management depended on physical proximity")
	TEST_ASSERT_EQUAL(uplink.get_management_panel(resident, home), remote_panel, "Repeated access duplicated the remote panel")
	TEST_ASSERT_NULL(uplink.get_management_panel(owner, home), "A different actor used the installed uplink")
	TEST_ASSERT_NULL(uplink.get_management_panel(resident, other), "The uplink granted authority over another owner's outpost")
	act(remote_panel, resident, "set_memo", null, list("memo" = "Managed remotely"))
	TEST_ASSERT_EQUAL(home.memo, "Managed remotely", "An authorized remote management action failed")
	console.machine_stat |= NOPOWER
	TEST_ASSERT_EQUAL(remote_panel.ui_status(resident, GLOB.always_state), UI_INTERACTIVE, "The implanted registry link required a powered physical console")
	console.machine_stat &= ~NOPOWER

	var/datum/component/cyberware/chrome = uplink.GetComponent(/datum/component/cyberware)
	chrome.start_emp_reboot()
	TEST_ASSERT(QDELETED(remote_panel), "EMP failure left a remote management panel open")
	TEST_ASSERT(!remote_action.IsAvailable(), "The EMP-disabled uplink remained usable")
	chrome.tune_up()
	remote_panel = uplink.get_management_panel(resident, home)
	TEST_ASSERT_NOTNULL(remote_panel, "The repaired uplink did not recover")
	uplink.Remove(resident, special = TRUE)
	TEST_ASSERT(QDELETED(remote_panel), "Removing the implant left its remote panel open")
	TEST_ASSERT(!(remote_action in resident.actions), "Removing the implant left its action granted")
	TEST_ASSERT_NULL(uplink.get_management_panel(resident, home), "A removed implant still granted remote access")

	// A new bearer gets only their own permissions, and revocation applies to open panels.
	TEST_ASSERT(uplink.Insert(visitor, special = TRUE), "Could not reinstall the uplink in another bearer")
	TEST_ASSERT_NULL(uplink.get_management_panel(visitor, home), "Implant resale transferred the previous bearer's authority")
	home.residents |= visitor.mind
	home.stewards |= visitor.mind
	remote_panel = uplink.get_management_panel(visitor, home)
	TEST_ASSERT_NOTNULL(remote_panel, "An authorized steward could not use their own implant")
	home.stewards -= visitor.mind
	TEST_ASSERT_EQUAL(remote_panel.ui_status(visitor, GLOB.always_state), UI_CLOSE, "Revoking steward authority left remote management available")
	act(remote_panel, visitor, "set_memo", null, list("memo" = "Unauthorized"))
	TEST_ASSERT_EQUAL(home.memo, "Managed remotely", "A revoked remote panel accepted a management action")
	qdel(uplink)
	TEST_ASSERT(QDELETED(remote_panel), "Deleting the implant left a management panel behind")
