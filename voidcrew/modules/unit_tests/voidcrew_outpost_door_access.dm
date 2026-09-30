/**
 * Outpost door access (outpost_door_access.dm, voidcrew/edits/outpost_door_access.dm): who each
 * setting lets through, the free side and how it is picked and turned, and the tool's refusals.
 * The prebuilt rooms' doors are covered in voidcrew_outpost_market_core.dm (defaults and
 * abandonment), voidcrew_outpost_storage.dm and voidcrew_outpost_medical_lab.dm (paying visitors)
 * and voidcrew_outpost_network.dm (the teleporter room's door stays public).
 *
 * Voidcrew defines are not visible from test files, so settings and refusals appear as literals.
 *
 * The test ground, west of the claim's shell (door_access_ground()):
 *
 *     W W W W W      a 3x3 room, shut in
 *     W . . . W
 *     W . r . W      r: "room"
 *     W . . . W
 *     W W A W W      A: "inner" airlock
 *       W v W        v: "vestibule"
 *       W B W        B: "outer" airlock
 *         s          s: "space"
 *
 * and a one-tile booth shut on three sides with a windoor on its north edge, a floor tile in front.
 */

/// Builds the door access test ground and returns its landmarks by name
/datum/unit_test/voidcrew_outpost_management/proc/door_access_ground(obj/structure/overmap/dynamic/player_outpost/home)
	var/turf/shell_corner = home.template_bottom_left
	var/cx = shell_corner.x - 16
	var/oy = shell_corner.y + 2
	var/z = shell_corner.z
	var/wall = /turf/closed/wall
	var/floor = /turf/open/floor/iron
	for(var/dx in -2 to 2)
		door_access_build(home, locate(cx + dx, oy + 6, z), wall)
		door_access_build(home, locate(cx + dx, oy + 2, z), dx ? wall : floor)
	for(var/dy in 3 to 5)
		door_access_build(home, locate(cx - 2, oy + dy, z), wall)
		door_access_build(home, locate(cx + 2, oy + dy, z), wall)
		for(var/dx in -1 to 1)
			door_access_build(home, locate(cx + dx, oy + dy, z), floor)
	for(var/dy in 0 to 1)
		door_access_build(home, locate(cx - 1, oy + dy, z), wall)
		door_access_build(home, locate(cx + 1, oy + dy, z), wall)
		door_access_build(home, locate(cx, oy + dy, z), floor)
	var/bx = cx - 6
	door_access_build(home, locate(bx - 1, oy + 1, z), wall)
	door_access_build(home, locate(bx + 1, oy + 1, z), wall)
	door_access_build(home, locate(bx, oy, z), wall)
	door_access_build(home, locate(bx, oy + 1, z), floor)
	door_access_build(home, locate(bx, oy + 2, z), floor)
	var/list/ground = list()
	ground["room"] = locate(cx, oy + 4, z)
	ground["vestibule"] = locate(cx, oy + 1, z)
	ground["space"] = locate(cx, oy - 1, z)
	ground["room_wall"] = locate(cx + 2, oy + 4, z)
	ground["inner"] = allocate(/obj/machinery/door/airlock, locate(cx, oy + 2, z))
	ground["outer"] = allocate(/obj/machinery/door/airlock, locate(cx, oy, z))
	ground["booth"] = locate(bx, oy + 1, z)
	ground["booth_front"] = locate(bx, oy + 2, z)
	ground["windoor"] = allocate(/obj/machinery/door/window, locate(bx, oy + 1, z), NORTH)
	return ground

/// Lays one tile of the test ground and joins it to the outpost's area
/datum/unit_test/voidcrew_outpost_management/proc/door_access_build(obj/structure/overmap/dynamic/player_outpost/home, turf/spot, turf_type)
	var/x = spot.x
	var/y = spot.y
	var/z = spot.z
	spot.ChangeTurf(turf_type)
	var/turf/built = locate(x, y, z)
	home.adopt_turf(built)
	return built

/// Whether any door carries a setting for `home`
/proc/outpost_door_access_test_count(obj/structure/overmap/dynamic/player_outpost/home)
	. = 0
	for(var/datum/component/outpost_door_access/lock in GLOB.outpost_access_doors)
		if(lock.outpost_ref?.resolve() == home)
			.++

// ===== WHO EACH SETTING LETS THROUGH =====

/datum/unit_test/voidcrew_outpost_door_access_roles
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_door_access_roles/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("doorrolesowner")
	TEST_ASSERT_NOTNULL(home, "The door access test outpost did not load")
	var/list/ground = door_access_ground(home)
	var/obj/machinery/door/airlock/door = ground["inner"]
	var/turf/outside = ground["vestibule"]
	var/turf/inside = ground["room"]
	TEST_ASSERT(home.is_turf_buildable(get_turf(door)), "The test ground is off the claim's build region")
	TEST_ASSERT_EQUAL(get_area(door), home.outpost_area, "The test door did not join the outpost's area")

	var/mob/living/carbon/human/owner = market_test_owner(home, "doorrolesowner")
	var/mob/living/carbon/human/steward = market_test_resident(home, "doorrolessteward", "steward")
	var/mob/living/carbon/human/treasurer = market_test_resident(home, "doorrolestreasurer", "treasurer")
	var/mob/living/carbon/human/pricer = market_test_resident(home, "doorrolespricer", "pricer")
	var/mob/living/carbon/human/resident = market_test_resident(home, "doorrolesresident", null)
	var/mob/living/carbon/human/blocked = market_test_resident(home, "doorrolesblocked", null)
	home.blocked_residents += blocked.ckey
	var/mob/living/carbon/human/crewmate = make_player(outside, "doorrolescrew")
	var/datum/team/voidcrew/crew = allocate(/datum/team/voidcrew)
	LAZYADD(owner.mind.ship_teams, crew)
	LAZYADD(crewmate.mind.ship_teams, crew)
	var/mob/living/carbon/human/visitor = make_player(outside, "doorrolesvisitor")

	// Nothing keyed: nothing on the door, nothing for this outpost on the fast path, everyone passes
	TEST_ASSERT_EQUAL(outpost_door_access_test_count(home), 0, "A new outpost has keyed doors")
	TEST_ASSERT_NULL(door.GetComponent(/datum/component/outpost_door_access), "An unkeyed door carries a setting")
	TEST_ASSERT(!door.outpost_access_refuses(visitor), "An unkeyed outpost door refused a visitor")
	TEST_ASSERT(door.allowed(visitor), "A public door refused a visitor")

	var/list/people = list(owner, steward, treasurer, pricer, resident, crewmate, visitor, blocked)
	var/list/names = list("The owner", "A steward", "A treasurer", "A pricer", "A resident", "A crewmate of the owner", "A visitor", "A blocked resident")
	var/list/expected = list(
		"members" = list(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE),
		"staff" = list(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE),
		"owner" = list(TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE),
		"public" = list(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE),
	)
	for(var/access in expected)
		TEST_ASSERT_NULL(home.set_door_access(owner, door, access), "The owner could not set a door to [access]")
		TEST_ASSERT_EQUAL(outpost_door_access_of(door), access, "The door did not take the [access] setting")
		var/list/row = expected[access]
		for(var/index in 1 to length(people))
			var/mob/living/carbon/human/person = people[index]
			person.forceMove(outside)
			var/passed = !!door.allowed(person)
			TEST_ASSERT_EQUAL(passed, row[index], "[names[index]] [row[index] ? "was refused at" : "passed"] a [access] door")
			// The free side always opens
			person.forceMove(inside)
			TEST_ASSERT(door.allowed(person), "[names[index]] could not leave by the free side of a [access] door")

	// Every setting says what it is
	TEST_ASSERT_NULL(home.set_door_access(owner, door, "members"), "The owner could not key the door again")
	TEST_ASSERT(findtext(jointext(door.examine(visitor), " "), "Members only."), "A members-only door does not say so")

	// The playtest visitor is a visitor at every door, the owner's own included
	owner.forceMove(outside)
	home.playtest_visitor_ckey = owner.ckey
	TEST_ASSERT(!door.allowed(owner), "The playtest visitor passed a members-only door")
	home.playtest_visitor_ckey = null
	TEST_ASSERT(door.allowed(owner), "The owner was refused at a members-only door")

	// An ownerless outpost opens every door
	visitor.forceMove(outside)
	home.founder_ckey = null
	TEST_ASSERT(door.allowed(visitor), "An ownerless outpost's door refused a visitor")
	home.founder_ckey = "doorrolesowner"
	TEST_ASSERT(!door.allowed(visitor), "The members-only door opened for a visitor once owned again")

	// A thrown item and a janitor's key open nothing for a visitor
	var/obj/item/storage/toolbox/toolbox = allocate(/obj/item/storage/toolbox, outside)
	toolbox.throwing = new /datum/thrownthing(toolbox, get_turf(door), get_dir(outside, door), 7, 1, visitor)
	door.Bumped(toolbox)
	TEST_ASSERT(door.density, "A toolbox thrown by a visitor opened a members-only door")
	QDEL_NULL(toolbox.throwing)
	door.try_to_activate_door(visitor, TRUE)
	TEST_ASSERT(door.density, "A janitor key's bypass opened a members-only door for a visitor")
	TEST_ASSERT(!door.allowed(null), "Telekinesis opened a members-only door")

	// Windoors take the same settings; their free side is front or back
	var/obj/machinery/door/window/windoor = ground["windoor"]
	TEST_ASSERT_NULL(home.set_door_access(owner, windoor, "owner"), "The owner could not key a windoor")
	visitor.forceMove(ground["booth_front"])
	TEST_ASSERT(!windoor.allowed(visitor), "An owner-only windoor let a visitor into the booth")
	windoor.try_to_activate_door(visitor, TRUE)
	TEST_ASSERT(windoor.density, "A janitor key's bypass opened an owner-only windoor")
	visitor.forceMove(ground["booth"])
	TEST_ASSERT(windoor.allowed(visitor), "A visitor in the booth could not leave by the windoor")
	owner.forceMove(ground["booth_front"])
	TEST_ASSERT(windoor.allowed(owner), "An owner-only windoor refused the owner")

	LAZYREMOVE(owner.mind.ship_teams, crew)
	LAZYREMOVE(crewmate.mind.ship_teams, crew)

// ===== THE FREE SIDE =====

/datum/unit_test/voidcrew_outpost_door_access_free_side
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_door_access_free_side/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("doorsideowner")
	TEST_ASSERT_NOTNULL(home, "The free side test outpost did not load")
	var/list/ground = door_access_ground(home)
	var/obj/machinery/door/airlock/inner = ground["inner"]
	var/obj/machinery/door/airlock/outer = ground["outer"]
	var/mob/living/carbon/human/owner = market_test_owner(home, "doorsideowner")
	var/mob/living/carbon/human/visitor = make_player(ground["room"], "doorsidevisitor")
	var/lock_count = length(GLOB.outpost_access_doors)
	TEST_ASSERT_EQUAL(inner.unres_sides, NONE, "The test airlock came with a free side")

	// The outer door of an airlock pair: its inside is the vestibule and the room behind it, not space
	TEST_ASSERT_NULL(home.set_door_access(owner, outer, "members"), "The owner could not key the outer door")
	var/datum/component/outpost_door_access/outer_lock = outer.GetComponent(/datum/component/outpost_door_access)
	TEST_ASSERT_NOTNULL(outer_lock, "The keyed outer door carries no setting")
	TEST_ASSERT_EQUAL(outer_lock.free_side, NORTH, "The outer door's free side faces space")
	TEST_ASSERT_EQUAL(outer.unres_sides, NORTH, "The outer door's floor light is not on its free side")
	// The inner door: the room is shut in, the vestibule still leads out through the outer door's free side
	TEST_ASSERT_NULL(home.set_door_access(owner, inner, "staff"), "The owner could not key the inner door")
	var/datum/component/outpost_door_access/inner_lock = inner.GetComponent(/datum/component/outpost_door_access)
	TEST_ASSERT_EQUAL(inner_lock.free_side, NORTH, "The inner door's free side is not the room")
	TEST_ASSERT_EQUAL(length(GLOB.outpost_access_doors), lock_count + 2, "Keying two doors did not register two")

	// A visitor in the room walks out through both; from space, neither opens
	TEST_ASSERT(inner.allowed(visitor), "A visitor in the room could not leave by the inner door")
	visitor.forceMove(ground["vestibule"])
	TEST_ASSERT(outer.allowed(visitor), "A visitor in the vestibule could not leave by the outer door")
	TEST_ASSERT(!inner.allowed(visitor), "The inner door let a visitor into the room from the vestibule")
	visitor.forceMove(ground["space"])
	TEST_ASSERT(!outer.allowed(visitor), "The outer door let a visitor in from space")

	// Turning a free side away from a shut-in side would make a room nobody can leave
	TEST_ASSERT_EQUAL(home.turn_door_free_side(owner, inner), "Would lock people in.", "The inner door's free side turned away from the shut-in room")
	TEST_ASSERT_EQUAL(inner_lock.free_side, NORTH, "A refused turn still turned the inner door")
	TEST_ASSERT_EQUAL(home.turn_door_free_side(owner, outer), "Would lock people in.", "The outer door's free side turned away from the shut-in vestibule")
	TEST_ASSERT_EQUAL(outer_lock.free_side, NORTH, "A refused turn still turned the outer door")

	// Once the room has another way out, the turn goes through
	var/turf/room_wall = ground["room_wall"]
	var/room_wall_x = room_wall.x
	var/room_wall_y = room_wall.y
	room_wall.ChangeTurf(/turf/open/floor/iron)
	room_wall = locate(room_wall_x, room_wall_y, room_wall.z)
	home.adopt_turf(room_wall)
	TEST_ASSERT_NULL(home.turn_door_free_side(owner, inner), "The inner door's free side would not turn once the room had another way out")
	TEST_ASSERT_EQUAL(inner_lock.free_side, SOUTH, "The inner door's free side did not turn to the vestibule")
	TEST_ASSERT_EQUAL(inner.unres_sides, SOUTH, "The inner door's floor light did not follow its free side")
	visitor.forceMove(ground["vestibule"])
	TEST_ASSERT(inner.allowed(visitor), "The turned free side did not open")
	visitor.forceMove(ground["room"])
	TEST_ASSERT(!inner.allowed(visitor), "The inner door still opened from the room after its free side turned")
	TEST_ASSERT_EQUAL(home.turn_door_free_side(owner, ground["windoor"]), "Door is public.", "A public door's free side turned")

	// Public again: nothing left on the door, its floor light back as it was, nothing on the fast path
	TEST_ASSERT_NULL(home.set_door_access(owner, inner, "public"), "The owner could not set the inner door public")
	TEST_ASSERT_NULL(inner.GetComponent(/datum/component/outpost_door_access), "A public door kept its setting")
	TEST_ASSERT_EQUAL(inner.unres_sides, NONE, "A public door kept its free side's floor light")
	TEST_ASSERT(inner.allowed(visitor), "A door set public refused a visitor")

	// A door taken apart and rebuilt is public
	var/turf/outer_turf = get_turf(outer)
	qdel(outer)
	TEST_ASSERT_EQUAL(length(GLOB.outpost_access_doors), lock_count, "A deleted door stayed on the fast path")
	TEST_ASSERT_EQUAL(outpost_door_access_test_count(home), 0, "The outpost still has keyed doors")
	var/obj/machinery/door/airlock/rebuilt = allocate(/obj/machinery/door/airlock, outer_turf)
	TEST_ASSERT_EQUAL(outpost_door_access_of(rebuilt), "public", "A rebuilt door kept the old door's setting")
	visitor.forceMove(ground["space"])
	TEST_ASSERT(rebuilt.allowed(visitor), "A rebuilt door refused a visitor")

	// A windoor's inside is behind it: its own tile
	var/obj/machinery/door/window/windoor = ground["windoor"]
	TEST_ASSERT_NULL(home.set_door_access(owner, windoor, "members"), "The owner could not key a windoor")
	var/datum/component/outpost_door_access/windoor_lock = windoor.GetComponent(/datum/component/outpost_door_access)
	TEST_ASSERT_EQUAL(windoor_lock.free_side, SOUTH, "The windoor's free side is not the booth")

// ===== THE TOOL =====

/datum/unit_test/voidcrew_outpost_door_access_tool
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_door_access_tool/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("doortoolowner")
	TEST_ASSERT_NOTNULL(home, "The door tool test outpost did not load")
	var/list/ground = door_access_ground(home)
	var/obj/machinery/door/airlock/door = ground["inner"]
	var/mob/living/carbon/human/owner = market_test_owner(home, "doortoolowner")
	var/mob/living/carbon/human/steward = market_test_resident(home, "doortoolsteward", "steward")
	var/mob/living/carbon/human/treasurer = market_test_resident(home, "doortooltreasurer", "treasurer")
	var/mob/living/carbon/human/resident = market_test_resident(home, "doortoolresident", null)
	var/mob/living/carbon/human/builder = market_test_resident(home, "doortoolbuilder", null)
	home.authorized_builder_ckeys |= builder.ckey

	// Managers only: the owner and stewards, never builders or other staff
	for(var/mob/living/carbon/human/refused as anything in list(treasurer, resident, builder))
		TEST_ASSERT_EQUAL(home.set_door_access(refused, door, "members"), "Not authorised.", "[refused.ckey] could key a door")
		TEST_ASSERT_EQUAL(home.turn_door_free_side(refused, door), "Not authorised.", "[refused.ckey] could turn a free side")
	TEST_ASSERT_EQUAL(outpost_door_access_of(door), "public", "A refused change still keyed the door")
	TEST_ASSERT_NULL(home.set_door_access(steward, door, "staff"), "A steward could not key a door")
	TEST_ASSERT_EQUAL(outpost_door_access_of(door), "staff", "The steward's setting did not take")
	TEST_ASSERT_EQUAL(home.set_door_access(owner, door, "vault"), "Unknown setting.", "An unknown setting was accepted")
	TEST_ASSERT_EQUAL(home.set_door_access(owner, door, 1), "Unknown setting.", "A numeric setting was accepted")
	TEST_ASSERT_EQUAL(outpost_door_access_of(door), "staff", "A refused setting changed the door")

	// The console lets managers in for the tool, and still keeps visitors out
	var/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/console = home.construction_console
	TEST_ASSERT_NOTNULL(console, "The test outpost has no construction console")
	TEST_ASSERT(console.is_crew_member(steward), "A steward cannot sit at the construction console for the door tool")
	TEST_ASSERT(console.is_crew_member(builder), "A builder was turned away from the construction console")
	TEST_ASSERT(!console.is_crew_member(resident), "A resident with no role may use the construction console")
	TEST_ASSERT_EQUAL(console.door_access_target(get_turf(door)), door, "Clicking a door's tile did not pick the door")
	TEST_ASSERT_EQUAL(console.door_access_target(door), door, "Clicking a door did not pick it")
	TEST_ASSERT_NULL(console.door_access_target(ground["room"]), "Clicking a bare floor picked a door")
	var/datum/action/innate/construction/ship/door_access/tool = locate() in console.actions
	TEST_ASSERT_NOTNULL(tool, "The outpost construction console has no Door Access tool")
	TEST_ASSERT(door in home.door_access_doors(), "The Door Access view does not show an outpost door")

	// Only outpost doors: not a door in a docked ship, not one somewhere else
	var/turf/ship_spot = door_access_build(home, locate(door.x + 5, door.y, door.z), /turf/open/floor/iron)
	visitor_turf = ship_spot
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
	var/obj/machinery/door/airlock/ship_door = allocate(/obj/machinery/door/airlock, visitor_turf)
	TEST_ASSERT_NULL(get_outpost_from_atom(ship_door), "The docked ship fixture still counts as outpost ground")
	TEST_ASSERT_EQUAL(home.set_door_access(owner, ship_door, "owner"), "Not an outpost door.", "A door in a docked ship was keyed")
	TEST_ASSERT_NULL(ship_door.GetComponent(/datum/component/outpost_door_access), "A door in a docked ship carries a setting")
	TEST_ASSERT(!(ship_door in home.door_access_doors()), "The Door Access view shows a docked ship's door")
	var/obj/machinery/door/airlock/elsewhere = allocate(/obj/machinery/door/airlock, run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(home.set_door_access(owner, elsewhere, "owner"), "Not an outpost door.", "A door off the outpost was keyed")
	TEST_ASSERT_EQUAL(home.set_door_access(owner, null, "owner"), "Not a door.", "Nothing was keyed")

	// Abandonment puts every door back to public
	TEST_ASSERT(outpost_door_access_test_count(home) > 0, "The outpost has no keyed door before abandonment")
	home.abandon(owner)
	TEST_ASSERT_EQUAL(outpost_door_access_test_count(home), 0, "Abandonment left keyed doors")
	TEST_ASSERT_EQUAL(outpost_door_access_of(door), "public", "Abandonment left the door keyed")
