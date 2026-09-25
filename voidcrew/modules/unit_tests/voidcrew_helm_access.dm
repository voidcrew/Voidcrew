/// Exercise real UI entry points without needing a connected client.
/obj/machinery/computer/helm/access_test
	var/datum/tgui/helm_access_test/test_ui

/obj/machinery/computer/helm/access_test/ui_interact(mob/user, datum/tgui/ui)
	return ..(user, ui || test_ui)

/datum/tgui/helm_access_test
	var/updates = 0

/datum/tgui/helm_access_test/send_update(custom_data, force)
	updates++
	return ..()

/// Expose the protected item entry points without changing their behavior.
/obj/machinery/computer/helm/access_test/proc/test_item_interaction(mob/living/user, obj/item/tool, ranged = FALSE)
	return ranged ? base_ranged_item_interaction(user, tool, list()) : base_item_interaction(user, tool, list())

/obj/machinery/computer/helm/access_test/proc/test_mouse_drop(mob/living/user)
	mouse_drop_receive(user, user)

/// Helm authorization must run before item-side effects and survive roster changes.
/datum/unit_test/voidcrew_helm_access
	var/obj/docking_port/mobile/voidcrew/port
	var/obj/structure/overmap/ship/ship

/datum/unit_test/voidcrew_helm_access/Destroy()
	if(ship)
		ship.shuttle = null
	if(port)
		port.current_ship = null
		qdel(port, force = TRUE)
	return ..()

/datum/unit_test/voidcrew_helm_access/Run()
	ship = allocate(/obj/structure/overmap/ship)
	ship.ship_team = new /datum/team/voidcrew()
	ship.ship_team.ship = ship
	port = allocate(/obj/docking_port/mobile/voidcrew)
	port.current_ship = ship
	ship.shuttle = port
	port.width = 1
	port.height = 1
	port.dwidth = 0
	port.dheight = 0
	port.shuttle_areas[get_area(port)] = TRUE
	port.register()
	var/obj/machinery/computer/helm/access_test/helm = allocate(/obj/machinery/computer/helm/access_test)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	ADD_TRAIT(user, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/structure/overmap/ship/enemy_ship = allocate(/obj/structure/overmap/ship)
	enemy_ship.ship_team = new /datum/team/voidcrew()
	enemy_ship.ship_team.ship = enemy_ship
	enemy_ship.ship_team.add_member(user.mind)

	TEST_ASSERT_EQUAL(get_ship_from_atom(helm), ship, "The helm must be inside the fixture's ship bounds.")
	helm.set_current_ship(null)
	TEST_ASSERT(!helm.is_crew_member(user), "An enemy crewmember must not use a newly built helm.")
	TEST_ASSERT_EQUAL(helm.current_ship, ship, "The first authorization check must resolve the owning hull.")
	TEST_ASSERT(helm.can_interact(user), "An enemy crewmember must be able to view the helm.")
	TEST_ASSERT_EQUAL(helm.ui_status(user, GLOB.default_state), UI_INTERACTIVE, "The UI must stay available to display its crew lock.")
	var/datum/tgui/helm_access_test/console_ui = allocate(/datum/tgui/helm_access_test, user, helm, "HelmComputer")
	helm.test_ui = console_ui
	helm.ui_interact(user)
	TEST_ASSERT_EQUAL(console_ui.updates, 1, "Direct UI access must reach the locked console.")
	helm.attack_hand(user)
	TEST_ASSERT_EQUAL(console_ui.updates, 2, "An enemy's empty-hand click must reach the locked console.")
	helm.attack_paw(user)
	TEST_ASSERT_EQUAL(console_ui.updates, 3, "A peaceful paw click must also reach the locked console.")
	var/list/ui_data = helm.ui_data(user)
	TEST_ASSERT(ui_data["isNotCrew"] && !ui_data["isAbandoned"], "An enemy must see the existing crew-locked interface.")
	ship.autopilot_allow_neutral = TRUE
	world.push_usr(user, CALLBACK(helm, TYPE_PROC_REF(/datum, ui_act), "autopilot_pref", list("key" = "allowNeutral", "value" = FALSE), console_ui))
	TEST_ASSERT(ship.autopilot_allow_neutral, "An enemy must not issue orders through the visible UI.")
	TEST_ASSERT(helm.click_ctrl(user) & CLICK_ACTION_BLOCKING, "An enemy must not pull the console.")

	var/obj/item/screwdriver/screwdriver = allocate(/obj/item/screwdriver)
	helm.time_to_unscrew = 0
	user.put_in_active_hand(screwdriver)
	screwdriver.melee_attack_chain(user, helm, list())
	TEST_ASSERT(!QDELETED(helm), "An enemy's screwdriver must not dismantle the console.")
	screwdriver.melee_attack_chain(user, helm, list(RIGHT_CLICK = "1"))
	TEST_ASSERT(!QDELETED(helm), "Secondary tool use must not dismantle the console.")

	var/list/item_types = list(/obj/item/card/emag, /obj/item/construction/rcd, /obj/item/disk/star_chart, /obj/item/storage/part_replacer)
	for(var/item_type in item_types)
		var/obj/item/tool = allocate(item_type)
		TEST_ASSERT(helm.test_item_interaction(user, tool) & ITEM_INTERACT_BLOCKING, "An enemy's [item_type] must stop before its own interaction handler.")
		TEST_ASSERT(helm.test_item_interaction(user, tool, ranged = TRUE) & ITEM_INTERACT_BLOCKING, "An enemy's ranged [item_type] must also stop.")
		TEST_ASSERT(!QDELETED(tool), "Rejected items must not be consumed.")

	// Membership in another team is fine if this hull has also enlisted the user.
	ship.ship_team.add_member(user.mind)
	TEST_ASSERT(helm.is_crew_member(user), "A member of both crews must have access.")
	TEST_ASSERT(helm.can_interact(user), "Crew must retain normal helm interaction.")
	TEST_ASSERT_EQUAL(helm.ui_status(user, GLOB.default_state), UI_INTERACTIVE, "Crew must retain an interactive UI.")
	ui_data = helm.ui_data(user)
	TEST_ASSERT(!ui_data["isNotCrew"], "Joining the crew must unlock an already open UI.")
	world.push_usr(user, CALLBACK(helm, TYPE_PROC_REF(/datum, ui_act), "autopilot_pref", list("key" = "allowNeutral", "value" = FALSE), console_ui))
	TEST_ASSERT(!ship.autopilot_allow_neutral, "Crew must still be able to issue the same UI order.")
	helm.test_mouse_drop(user)
	TEST_ASSERT_NOTNULL(helm.GetComponent(/datum/component/leanable/helm), "Crew must be able to make the helm leanable.")
	ship.ship_team.remove_member(user.mind)
	TEST_ASSERT_EQUAL(helm.ui_status(user, GLOB.default_state), UI_INTERACTIVE, "Removing a crewmember must leave the locked UI visible.")
	ui_data = helm.ui_data(user)
	TEST_ASSERT(ui_data["isNotCrew"], "Removing a crewmember must lock an already open UI on its next update.")
	world.push_usr(user, CALLBACK(helm, TYPE_PROC_REF(/datum, ui_act), "autopilot_pref", list("key" = "allowNeutral", "value" = TRUE), console_ui))
	TEST_ASSERT(!ship.autopilot_allow_neutral, "A former crewmember's open UI must no longer accept orders.")
	TEST_ASSERT(SEND_SIGNAL(helm, COMSIG_MOUSEDROPPED_ONTO, user, user, list()) & COMPONENT_CANCEL_MOUSEDROPPED_ONTO, "An existing lean component must still reject enemy drags.")

	// The rigger may waive distance, but must never waive membership.
	var/obj/item/organ/cyberimp/cyberware/rigger/socket = allocate(/obj/item/organ/cyberimp/cyberware/rigger)
	socket.Insert(user, special = TRUE)
	socket.relink(ship)
	TEST_ASSERT(!socket.open_uplink(user), "An enemy rigger must not open a helm uplink.")
	TEST_ASSERT_NULL(socket.uplink_console, "A refused uplink must not leave an active console behind.")
	socket.uplink_console = helm
	TEST_ASSERT(!socket.uplink_covers(helm, user), "A stale enemy uplink must not grant remote access.")
	TEST_ASSERT_EQUAL(helm.ui_status(user, GLOB.default_state), UI_INTERACTIVE, "A refused rigger uplink must not prevent normal locked UI viewing.")
	ship.ship_team.add_member(user.mind)
	TEST_ASSERT(socket.uplink_covers(helm, user), "A crew rigger on the same hull must retain its uplink.")
	socket.drop_uplink(user, silent = TRUE)
	socket.Remove(user, special = TRUE)

	// A job already in progress must stop if the user leaves this crew.
	helm.time_to_unscrew = 1 SECONDS
	addtimer(CALLBACK(ship.ship_team, TYPE_PROC_REF(/datum/team/voidcrew, remove_member), user.mind), 0.2 SECONDS)
	screwdriver.melee_attack_chain(user, helm, list())
	TEST_ASSERT(!helm.is_crew_member(user), "The timer must remove the user during deconstruction.")
	TEST_ASSERT(!QDELETED(helm), "Losing crew membership during deconstruction must preserve the console.")

	ship.abandoned = TRUE
	TEST_ASSERT(helm.is_crew_member(user), "An abandoned hull must remain accessible for claiming.")
	ui_data = helm.ui_data(user)
	TEST_ASSERT(!ui_data["isNotCrew"] && ui_data["isAbandoned"], "An abandoned hull must unlock the live UI.")
	ship.abandoned = FALSE
	TEST_ASSERT(!helm.is_crew_member(user), "Returning to an owned hull must restore the crew lock.")
	ui_data = helm.ui_data(user)
	TEST_ASSERT(ui_data["isNotCrew"] && !ui_data["isAbandoned"], "Restoring ownership must restore the live UI lock.")
	ship.ship_team.add_member(user.mind)
	helm.time_to_unscrew = 0
	screwdriver.melee_attack_chain(user, helm, list())
	TEST_ASSERT(QDELETED(helm), "A crewmember must still be able to dismantle the console.")
	TEST_ASSERT_NOTNULL(locate(/obj/structure/frame/computer) in user.loc, "Crew deconstruction must leave a computer frame.")
	ship.ship_team.remove_member(user.mind)
	enemy_ship.ship_team.remove_member(user.mind)

/// NPC authorization keys may establish ownership, but may not steal a crewed hull.
/datum/unit_test/voidcrew_helm_claim_access/Run()
	var/obj/structure/overmap/ship/npc/ship = allocate(/obj/structure/overmap/ship/npc)
	ship.ship_team = new /datum/team/voidcrew()
	ship.ship_team.ship = ship
	ship.is_disabled = TRUE
	var/obj/machinery/computer/helm/helm = allocate(/obj/machinery/computer/helm)
	helm.set_current_ship(ship)
	var/mob/living/carbon/human/consistent/claimer = allocate(/mob/living/carbon/human/consistent)
	claimer.mind_initialize()
	var/obj/item/ship_key/key = allocate(/obj/item/ship_key)
	key.set_ship(ship)
	TEST_ASSERT(!helm.is_crew_member(claimer), "An unclaimed NPC hull must still reject ordinary helm use.")
	key.melee_attack_chain(claimer, helm, list())
	TEST_ASSERT(QDELETED(key), "A valid NPC claim must consume the key.")
	TEST_ASSERT(ship.player_controlled && helm.is_crew_member(claimer), "Claiming must grant the new crew access.")

	var/mob/living/carbon/human/consistent/boarder = allocate(/mob/living/carbon/human/consistent)
	boarder.mind_initialize()
	var/obj/item/ship_key/spare_key = allocate(/obj/item/ship_key)
	spare_key.set_ship(ship)
	spare_key.melee_attack_chain(boarder, helm, list())
	TEST_ASSERT(!QDELETED(spare_key), "A rejected spare key must not be consumed.")
	TEST_ASSERT(!helm.is_crew_member(boarder), "An old key must not steal a disabled player-owned ship.")
	TEST_ASSERT_EQUAL(ship.claimed_captain, claimer.mind, "An old key must not replace the captain.")

	ship.abandoned = TRUE
	spare_key.melee_attack_chain(boarder, helm, list())
	TEST_ASSERT(QDELETED(spare_key), "An abandoned hull must remain claimable by key.")
	TEST_ASSERT(!ship.abandoned && helm.is_crew_member(boarder), "Reclaiming must restore ownership and helm access.")
	ship.ship_team.remove_member(claimer.mind)
	ship.ship_team.remove_member(boarder.mind)

/// Physical attacks must apply the same crew restriction as tools and controls.
/datum/unit_test/voidcrew_helm_damage/Run()
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	ship.ship_team = new /datum/team/voidcrew()
	ship.ship_team.ship = ship
	var/obj/machinery/computer/helm/helm = allocate(/obj/machinery/computer/helm)
	helm.set_current_ship(ship)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	user.set_combat_mode(TRUE)
	var/obj/item/crowbar/weapon = allocate(/obj/item/crowbar)
	var/obj/projectile/bullet/projectile = allocate(/obj/projectile/bullet)
	projectile.firer = user
	var/datum/thrownthing/throw_data = allocate(/datum/thrownthing, weapon, helm, NORTH, 1, 1, user)
	var/obj/vehicle/sealed/mecha/ripley/mech = allocate(/obj/vehicle/sealed/mecha/ripley)
	var/original_integrity = helm.get_integrity()
	weapon.melee_attack_chain(user, helm, list())
	weapon.melee_attack_chain(user, helm, list(RIGHT_CLICK = "1"))
	helm.attack_hand(user)
	helm.attack_paw(user)
	helm.attack_hulk(user)
	helm.attack_generic(user, 30, BRUTE, MELEE)
	helm.mech_melee_attack(mech, user)
	TEST_ASSERT_EQUAL(helm.bullet_act(projectile), BULLET_ACT_BLOCK, "An enemy projectile must be blocked before its hit effects.")
	helm.hitby(weapon, throwingdatum = throw_data)
	TEST_ASSERT_EQUAL(helm.get_integrity(), original_integrity, "Enemy direct attacks must leave the helm intact.")

	ship.ship_team.add_member(user.mind)
	weapon.melee_attack_chain(user, helm, list())
	TEST_ASSERT(helm.get_integrity() < original_integrity, "Crew must retain normal item attacks.")
	original_integrity = helm.get_integrity()
	helm.bullet_act(projectile)
	TEST_ASSERT(helm.get_integrity() < original_integrity, "Crew projectiles must still damage the console.")
	original_integrity = helm.get_integrity()
	helm.hitby(weapon, throwingdatum = throw_data)
	TEST_ASSERT(helm.get_integrity() < original_integrity, "Crew throws must still damage the console.")
	ship.ship_team.remove_member(user.mind)
