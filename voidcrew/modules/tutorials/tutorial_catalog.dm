/**
 * # Tutorial checklist catalog
 *
 * One /datum/vc_tutorial per checklist item and one /datum/vc_tutorial_step per step,
 * each a singleton owned by SSvc_tutorials. Steps are credited passively by hooks
 * (hooks_*.dm) calling tutorial_credit() or tutorial_credit_crew() with a step key
 * from voidcrew/_DEFINES/tutorials.dm. Nothing here acts on the world.
 *
 * The panel is the one place how-to text is allowed in player UI (kit rule exception
 * for the checklist). Keep the intro to 1-3 plain sentences and each step to one line.
 *
 * Adding an item: give it an id, a category (TUTORIAL_CATEGORY_*), an order within that
 * category, an intro and its steps. A step with a route is one way to finish the item:
 * give every step of one way the same route id and route_name, and the item needs at
 * least two routes. Once every counted step of one route is done, the other routes'
 * steps are excused.
 */

/// Panel categories, in panel order: category id -> name.
GLOBAL_LIST_INIT(tutorial_categories, list(
	TUTORIAL_CATEGORY_START = "Getting started",
	TUTORIAL_CATEGORY_EXPLORE = "Exploring",
	TUTORIAL_CATEGORY_BODY = "Your body",
	TUTORIAL_CATEGORY_FIGHT = "Fighting",
	TUTORIAL_CATEGORY_KEEP = "Keeping your ship",
))

/datum/vc_tutorial
	/// Item key, a TUTORIAL_ITEM_* define. Written to the DB when the item completes.
	var/id
	/// Shown in the panel's item list.
	var/name
	/// The panel category it is listed under, a TUTORIAL_CATEGORY_* define.
	var/category
	/// Position within its category, lowest first.
	var/order = 0
	/// 1-3 plain sentences on how the system works, shown above the steps.
	var/intro
	/// Step typepaths, in the order they are shown.
	var/list/steps = list()

/datum/vc_tutorial_step
	/// Step key, a TUTORIAL_STEP_* define. At most 64 characters.
	var/key
	/// Short imperative title.
	var/name
	/// One plain line of how-to text.
	var/text
	/// Optional steps are shown but never counted toward the item.
	var/optional = FALSE
	/// Route id. Steps sharing one form one way to finish the item; null for shared steps.
	var/route
	/// The route's heading in the panel.
	var/route_name
	/// Atom types (objects, mobs or turfs) the in-game highlight outlines while this step is the
	/// guide step. Empty when no fixed type fits; see extra_targets() and highlight_filter().
	var/list/highlight_types
	/// Window id -> focus key. While this is the viewer's guide step, a window whose ui_data sends
	/// tutorial_ui_focus(user, window id) pulses the element wrapped in <TutorialFocus id={key}>.
	/// Example: list("helm" = "helm_dock").
	var/list/ui_focus

/**
 * A short note shown under the step for this viewer, or null.
 * Machine scans are cached per ship by SSvc_tutorials.
 * A note also tells suggested_item() the step can't be done yet; use live_line() for state.
 */
/datum/vc_tutorial_step/proc/availability(mob/user)
	return null

/**
 * A short line of live state shown under the step while it is undone, or null.
 * Example: "Batteries at 12%". It is state, never rules. Plain text: React renders it as text,
 * so don't html_encode it. Called only for the viewer's open item, about every 5 s while the
 * panel is open. It never affects suggested_item().
 */
/datum/vc_tutorial_step/proc/live_line(mob/user)
	return null

/**
 * TRUE to keep a highlight candidate (a highlight_types match or an extra_targets() entry).
 * Example: only the unlinked machine, only the armed missile.
 */
/datum/vc_tutorial_step/proc/highlight_filter(mob/user, atom/candidate)
	return TRUE

/**
 * Atoms to highlight besides highlight_types matches: specific mobs, turfs or objects.
 * Only atoms on the viewer's z-level are used. Default empty.
 */
/datum/vc_tutorial_step/proc/extra_targets(mob/user)
	return list()

/**
 * What the off-screen arrow points at, or null for no arrow. The arrow hides while the target
 * is on the viewer's screen. The default is the nearest highlight candidate on the viewer's
 * z-level within TUTORIAL_ARROW_RANGE tiles, and no arrow at all while any candidate is on
 * screen. Override it for things that aren't highlight candidates (the nearest ruin).
 */
/datum/vc_tutorial_step/proc/arrow_target(mob/user)
	return tutorial_default_arrow_target(user, tutorial_step_candidates(user, src))

/**
 * TRUE when this step should not count toward its item for this viewer, for example
 * a captain-only step seen by a crewmate, or a route step once another route is done.
 * Overrides must keep the parent's result.
 */
/datum/vc_tutorial_step/proc/excused(mob/user)
	return route_excused(tutorial_viewer_ckey(user))

/**
 * TRUE when this is a route step and every counted step of a different route in the same
 * item is done for this ckey. Reads SSvc_tutorials.progress only, so it never recurses.
 */
/datum/vc_tutorial_step/proc/route_excused(ckey)
	if(!route || !ckey)
		return FALSE
	var/list/done = SSvc_tutorials.progress[ckey]
	var/datum/vc_tutorial/item = SSvc_tutorials.item_by_step?[key]
	if(!done || !item)
		return FALSE
	// route id -> TRUE while every counted step of it is done so far
	var/list/finished = list()
	for(var/datum/vc_tutorial_step/other as anything in item.steps)
		if(!other.route || other.route == route || other.optional)
			continue
		if(isnull(finished[other.route]))
			finished[other.route] = TRUE
		if(!done[other.key])
			finished[other.route] = FALSE
	for(var/other_route in finished)
		if(finished[other_route])
			return TRUE
	return FALSE

/**
 * State check run when the panel opens. TRUE credits the step to the viewer.
 * Use it for things a player may have finished before the hook could see them.
 */
/datum/vc_tutorial_step/proc/state_satisfied(mob/user)
	return FALSE

// ---------------------------------------------------------------------------
// Your ship
// ---------------------------------------------------------------------------

/datum/vc_tutorial/ship
	id = TUTORIAL_ITEM_SHIP
	name = "Your ship"
	category = TUTORIAL_CATEGORY_START
	order = 1
	intro = "The helm flies the ship and docks it at planets, outposts and ruins. The captain runs the crew and ship settings from Ship Management. Your ship's lockers hold most of what you need to start."
	steps = list(
		/datum/vc_tutorial_step/ship_manage,
		/datum/vc_tutorial_step/ship_search,
		/datum/vc_tutorial_step/ship_course,
		/datum/vc_tutorial_step/ship_dock,
		/datum/vc_tutorial_step/ship_undock,
		/datum/vc_tutorial_step/ship_build,
	)

/datum/vc_tutorial_step/ship_manage
	key = TUTORIAL_STEP_SHIP_MANAGE
	name = "Open Ship Management"
	text = "Use the Ship Management button at the top left to see your crew, invites and ship settings."

/datum/vc_tutorial_step/ship_manage/availability(mob/user)
	if(excused(user))
		return "Captain only."
	return null

/datum/vc_tutorial_step/ship_manage/excused(mob/user)
	if(..())
		return TRUE
	return !(locate(/datum/action/innate/captain_management) in user?.actions)

/datum/vc_tutorial_step/ship_search
	key = TUTORIAL_STEP_SHIP_SEARCH
	name = "Search the lockers"
	text = "Open your ship's lockers and crates, or Alt-click a tile to see everything on it."
	highlight_types = list(/obj/structure/closet)

/// Skip lockers someone already opened or emptied. A closet that was never opened may not
/// have made its contents yet, so it still counts.
/datum/vc_tutorial_step/ship_search/highlight_filter(mob/user, atom/candidate)
	var/obj/structure/closet/closet = candidate
	if(!istype(closet))
		return TRUE
	if(closet.opened)
		return FALSE
	return !closet.contents_initialized || length(closet.contents)

/// Shared by the helm steps: a hull with no helm can't do them.
/datum/vc_tutorial_step/proc/no_helm_note(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(ship && !SSvc_tutorials.ship_has_machine(ship, /obj/machinery/computer/helm))
		return "No helm aboard."
	return null

/datum/vc_tutorial_step/ship_course
	key = TUTORIAL_STEP_SHIP_COURSE
	name = "Set a course"
	text = "At the helm, pick a heading, or right-click the chart to fly there on autopilot."
	highlight_types = list(/obj/machinery/computer/helm)
	ui_focus = list("helm" = "helm_course")

/datum/vc_tutorial_step/ship_course/availability(mob/user)
	return no_helm_note(user)

/datum/vc_tutorial_step/ship_course/live_line(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!ship?.shuttle || !isturf(ship.loc))
		return null
	if(!ship.can_thrust())
		return "The engines have no power."
	return null

/datum/vc_tutorial_step/ship_dock
	key = TUTORIAL_STEP_SHIP_DOCK
	name = "Dock"
	text = "Fly onto a planet, outpost or ruin and press Dock at the helm."
	highlight_types = list(/obj/machinery/computer/helm)
	ui_focus = list("helm" = "helm_dock")

/datum/vc_tutorial_step/ship_dock/availability(mob/user)
	return no_helm_note(user)

/datum/vc_tutorial_step/ship_dock/live_line(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!ship)
		return null
	if(ship.dock_warmup_timer || ship.state == OVERMAP_SHIP_DOCKING)
		return "Docking..."
	if(!isturf(ship.loc))
		return "Docked. Undock to fly somewhere new."
	if(!ship.is_still() && MAGNITUDE(ship.speed[1], ship.speed[2]) > ship.max_speed * DOCK_ASSIST_SPEED_FRACTION)
		return "Too fast to dock."
	return null

/datum/vc_tutorial_step/ship_undock
	key = TUTORIAL_STEP_SHIP_UNDOCK
	name = "Undock"
	text = "Press Undock at the helm to leave."
	highlight_types = list(/obj/machinery/computer/helm)
	ui_focus = list("helm" = "helm_undock")

/datum/vc_tutorial_step/ship_undock/availability(mob/user)
	return no_helm_note(user)

/// The same blocks the helm's Undock button shows, in the order it checks them.
/datum/vc_tutorial_step/ship_undock/live_line(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!ship || isturf(ship.loc))
		return null
	if(ship.undock_warmup_timer || ship.state == OVERMAP_SHIP_UNDOCKING)
		return "Undocking..."
	if(!COOLDOWN_FINISHED(ship, integrity_undock_lockout))
		return "The hull is too damaged to leave yet."
	if(!COOLDOWN_FINISHED(ship, interdiction_undock_lockout))
		return "Held by an interdiction."
	if(!COOLDOWN_FINISHED(ship, undock_cooldown))
		return "The docking clamps are still cycling."
	var/datum/voidcrew_cargo_shuttle/cargo_shuttle = ship.get_cargo_shuttle()
	if(cargo_shuttle && cargo_shuttle.state != CARGO_SHUTTLE_AWAY)
		return "The cargo shuttle is aboard."
	return null

/datum/vc_tutorial_step/ship_build
	key = TUTORIAL_STEP_SHIP_BUILD
	name = "See the construction console"
	text = "Research Shuttle Construction, build the console, and use its drone to change your hull."
	optional = TRUE
	highlight_types = list(/obj/machinery/computer/camera_advanced/base_construction/ship)

/datum/vc_tutorial_step/ship_build/live_line(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!ship || SSvc_tutorials.ship_has_machine(ship, /obj/machinery/computer/camera_advanced/base_construction/ship))
		return null
	var/datum/techweb/web = ship.get_research_web()
	if(!web)
		return null
	if(web.researched_nodes[TECHWEB_NODE_SHIP_CONSTRUCTION])
		return "Researched. Print its board at the circuit imprinter."
	return "Shuttle Construction isn't researched yet."

// ---------------------------------------------------------------------------
// First contract
// ---------------------------------------------------------------------------

/datum/vc_tutorial/contract
	id = TUTORIAL_ITEM_CONTRACT
	name = "First contract"
	category = TUTORIAL_CATEGORY_START
	order = 5
	intro = "Contracts are paid jobs from the board on your ship or from outpost traders. Do the job, bring back what they asked for and turn it in at the pad."
	steps = list(
		/datum/vc_tutorial_step/contract_take,
		/datum/vc_tutorial_step/contract_work,
		/datum/vc_tutorial_step/contract_turn_in,
	)

/datum/vc_tutorial_step/contract_take
	key = TUTORIAL_STEP_CONTRACT_TAKE
	name = "Take a contract"
	text = "Open the contract board and press Accept Mission on a contract. At an outpost, the main trader has Contracts."
	highlight_types = list(/obj/machinery/computer/mission_board, /mob/living/basic/outpost_trader)
	ui_focus = list("board" = "board_accept")

/datum/vc_tutorial_step/contract_take/availability(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(ship && !SSvc_tutorials.ship_has_machine(ship, /obj/machinery/computer/mission_board))
		return "No board aboard. Traders offer contracts, or research Mission Logistics."
	return null

/datum/vc_tutorial_step/contract_work
	key = TUTORIAL_STEP_CONTRACT_WORK
	name = "Do the job"
	text = "Do what the contract asks. Jobs at a site are marked on the helm."
	ui_focus = list("board" = "board_active_tab")

/datum/vc_tutorial_step/contract_turn_in
	key = TUTORIAL_STEP_CONTRACT_TURN_IN
	name = "Get paid"
	text = "Put the goods on the pad and press Turn In under Active, or Complete if there's nothing to hand over. Traders take goods from your hands."
	highlight_types = list(/obj/machinery/mission_pad, /obj/machinery/computer/mission_board)
	ui_focus = list("board" = "board_turn_in")

// ---------------------------------------------------------------------------
// R&D setup
// ---------------------------------------------------------------------------

/datum/vc_tutorial/research
	id = TUTORIAL_ITEM_RESEARCH
	name = "R&D setup"
	category = TUTORIAL_CATEGORY_START
	order = 3
	intro = "Research unlocks new gear and machines for your ship. You need a server, a console and a protolathe, all linked together. The autolathe prints a kit with everything to start."
	steps = list(
		/datum/vc_tutorial_step/research_kit,
		/datum/vc_tutorial_step/research_server,
		/datum/vc_tutorial_step/research_disk,
		/datum/vc_tutorial_step/research_console,
		/datum/vc_tutorial_step/research_protolathe,
		/datum/vc_tutorial_step/research_multitool,
		/datum/vc_tutorial_step/research_link,
	)

/datum/vc_tutorial_step/research_kit
	key = TUTORIAL_STEP_RESEARCH_KIT
	name = "Get the R&D kit"
	text = "Print the Research & Development Kit at the autolathe and pick it up."
	highlight_types = list(/obj/machinery/autolathe, /obj/item/storage/box/rndboards/all)

/// A hull that already has a ship server is past needing the kit.
/datum/vc_tutorial_step/research_kit/state_satisfied(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return ship && SSvc_tutorials.ship_has_machine(ship, /obj/machinery/rnd/server/ship)

/datum/vc_tutorial_step/research_server
	key = TUTORIAL_STEP_RESEARCH_SERVER
	name = "Build the R&D server"
	text = "Set the server flatpack on the floor and use a multitool on it."
	highlight_types = list(/obj/item/flatpack)

/datum/vc_tutorial_step/research_server/state_satisfied(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return ship && SSvc_tutorials.ship_has_machine(ship, /obj/machinery/rnd/server/ship)

/// Only the server's flatpack, not the other three from the kit.
/datum/vc_tutorial_step/research_server/highlight_filter(mob/user, atom/candidate)
	return tutorial_flatpack_builds(candidate, list(/obj/machinery/rnd/server/ship))

/datum/vc_tutorial_step/research_server/live_line(mob/user)
	return tutorial_tool_line(user, TOOL_MULTITOOL)

/datum/vc_tutorial_step/research_disk
	key = TUTORIAL_STEP_RESEARCH_DISK
	name = "Add the ship disk"
	text = "Put the R&D server source code disk from the kit into the server."
	highlight_types = list(/obj/machinery/rnd/server/ship, /obj/item/computer_disk/ship_disk)

/datum/vc_tutorial_step/research_disk/state_satisfied(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return !!ship?.get_research_web()

/datum/vc_tutorial_step/research_console
	key = TUTORIAL_STEP_RESEARCH_CONSOLE
	name = "Set up the R&D console"
	text = "Use the kit's iron in hand to make a computer frame. Wrench it, add the console board, screwdriver it, add 5 cable and 2 glass, then screwdriver it again."
	highlight_types = list(/obj/structure/frame/computer)

/datum/vc_tutorial_step/research_console/state_satisfied(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return ship && SSvc_tutorials.ship_has_machine(ship, /obj/machinery/computer/rdconsole)

/// Empty frames and frames holding the R&D console board.
/datum/vc_tutorial_step/research_console/highlight_filter(mob/user, atom/candidate)
	return tutorial_frame_for(candidate, /obj/item/circuitboard/computer/rdconsole)

/datum/vc_tutorial_step/research_console/live_line(mob/user)
	var/obj/structure/frame/computer/frame = tutorial_nearest_frame(user, src, /obj/item/circuitboard/computer/rdconsole)
	if(!frame)
		return "No computer frame yet."
	return tutorial_frame_line(user, frame)

/datum/vc_tutorial_step/research_protolathe
	key = TUTORIAL_STEP_RESEARCH_PROTOLATHE
	name = "Set up the protolathe"
	text = "Set the protolathe flatpack on the floor and use a multitool on it. Do the same with the circuit imprinter."
	highlight_types = list(/obj/item/flatpack)

/datum/vc_tutorial_step/research_protolathe/state_satisfied(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return ship && SSvc_tutorials.ship_has_machine(ship, /obj/machinery/rnd/production/protolathe)

/datum/vc_tutorial_step/research_protolathe/highlight_filter(mob/user, atom/candidate)
	return tutorial_flatpack_builds(candidate, list(/obj/machinery/rnd/production/protolathe, /obj/machinery/rnd/production/circuit_imprinter))

/datum/vc_tutorial_step/research_protolathe/live_line(mob/user)
	return tutorial_tool_line(user, TOOL_MULTITOOL)

/datum/vc_tutorial_step/research_multitool
	key = TUTORIAL_STEP_RESEARCH_MULTITOOL
	name = "Multitool the server"
	text = "Hold a multitool and use it on the server to copy its link."
	highlight_types = list(/obj/machinery/rnd/server/ship)

/// A hull whose console and protolathe already run off its server got here some other way.
/datum/vc_tutorial_step/research_multitool/state_satisfied(mob/user)
	return tutorial_ship_rnd_linked(get_crew_ship(user))

/datum/vc_tutorial_step/research_multitool/live_line(mob/user)
	return tutorial_tool_line(user, TOOL_MULTITOOL)

/datum/vc_tutorial_step/research_link
	key = TUTORIAL_STEP_RESEARCH_LINK
	name = "Link all the devices"
	text = "Use that multitool on the R&D console, the protolathe and the circuit imprinter."
	highlight_types = list(/obj/machinery/computer/rdconsole, /obj/machinery/rnd/production/protolathe, /obj/machinery/rnd/production/circuit_imprinter)

/datum/vc_tutorial_step/research_link/state_satisfied(mob/user)
	return tutorial_ship_rnd_linked(get_crew_ship(user))

/// Only the machines that aren't on the ship's research web yet.
/datum/vc_tutorial_step/research_link/highlight_filter(mob/user, atom/candidate)
	return !tutorial_rnd_device_linked(candidate, get_crew_ship(user)?.get_research_web())

/datum/vc_tutorial_step/research_link/live_line(mob/user)
	var/datum/techweb/web = get_crew_ship(user)?.get_research_web()
	if(!web)
		return null
	var/unlinked_tool = FALSE
	for(var/obj/item/multitool/tool in user.get_all_contents())
		if(tool.buffer == web)
			unlinked_tool = FALSE
			break
		unlinked_tool = TRUE
	if(unlinked_tool)
		return "Your multitool has no server link."
	var/list/unlinked = list()
	for(var/atom/machine as anything in tutorial_step_candidates(user, src))
		var/label = tutorial_rnd_device_label(machine)
		if(label)
			unlinked |= label
	if(!length(unlinked))
		return null
	return "Not linked: [unlinked.Join(", ")]."

// ---------------------------------------------------------------------------
// Surveys
// ---------------------------------------------------------------------------

/datum/vc_tutorial/surveys
	id = TUTORIAL_ITEM_SURVEYS
	name = "Surveys"
	category = TUTORIAL_CATEGORY_EXPLORE
	order = 1
	intro = "A survey console scans a planet from orbit and prints research notes. The R&D console turns the notes into research points."
	steps = list(
		/datum/vc_tutorial_step/surveys_node,
		/datum/vc_tutorial_step/surveys_build,
		/datum/vc_tutorial_step/surveys_survey,
		/datum/vc_tutorial_step/surveys_notes,
	)

/datum/vc_tutorial_step/surveys_node
	key = TUTORIAL_STEP_SURVEYS_NODE
	name = "Research the survey console"
	text = "At the R&D console, research Orbital survey console. It's on the Available tab."
	highlight_types = list(/obj/machinery/computer/rdconsole)
	ui_focus = list("rdconsole" = "rd_node_" + TECHWEB_NODE_SURVEY_CONSOLE)

/datum/vc_tutorial_step/surveys_node/state_satisfied(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	var/datum/techweb/web = ship?.get_research_web()
	return !!web?.researched_nodes[TECHWEB_NODE_SURVEY_CONSOLE]

/datum/vc_tutorial_step/surveys_node/live_line(mob/user)
	return tutorial_node_points_line(get_crew_ship(user)?.get_research_web(), TECHWEB_NODE_SURVEY_CONSOLE)

/datum/vc_tutorial_step/surveys_build
	key = TUTORIAL_STEP_SURVEYS_BUILD
	name = "Build a survey console"
	text = "Print the Orbital survey console board at the circuit imprinter. Build it in a computer frame like the R&D console."
	highlight_types = list(
		/obj/machinery/rnd/production/circuit_imprinter,
		/obj/item/flatpack,
		/obj/structure/frame/computer,
		/obj/item/circuitboard/computer/survey_shuttle_docker,
	)
	ui_focus = list("imprinter" = "imprinter_survey_console_board")

/datum/vc_tutorial_step/surveys_build/state_satisfied(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return ship && SSvc_tutorials.ship_has_machine(ship, /obj/machinery/computer/camera_advanced/shuttle_docker/survey)

/// The imprinter's flatpack while no imprinter is aboard, and frames empty or holding the survey board.
/datum/vc_tutorial_step/surveys_build/highlight_filter(mob/user, atom/candidate)
	if(istype(candidate, /obj/item/flatpack))
		var/obj/structure/overmap/ship/ship = get_crew_ship(user)
		if(ship && SSvc_tutorials.ship_has_machine(ship, /obj/machinery/rnd/production/circuit_imprinter))
			return FALSE
		return tutorial_flatpack_builds(candidate, list(/obj/machinery/rnd/production/circuit_imprinter))
	if(istype(candidate, /obj/structure/frame/computer))
		return tutorial_frame_for(candidate, /obj/item/circuitboard/computer/survey_shuttle_docker)
	return TRUE

/datum/vc_tutorial_step/surveys_build/live_line(mob/user)
	var/datum/techweb/web = get_crew_ship(user)?.get_research_web()
	if(!web)
		return null
	var/obj/structure/frame/computer/frame = tutorial_nearest_frame(user, src, /obj/item/circuitboard/computer/survey_shuttle_docker, TRUE)
	if(frame)
		return tutorial_frame_line(user, frame)
	var/has_imprinter = FALSE
	for(var/obj/machinery/rnd/production/circuit_imprinter/imprinter in tutorial_step_candidates(user, src))
		has_imprinter = TRUE
		if(imprinter.stored_research == web)
			return null
	if(has_imprinter)
		return "The circuit imprinter isn't linked to the server."
	return "No circuit imprinter set up."

/datum/vc_tutorial_step/surveys_survey
	key = TUTORIAL_STEP_SURVEYS_SURVEY
	name = "Survey a planet"
	text = "Park the ship on a planet's tile and start a survey at the console. Keep the ship still until it ends."
	highlight_types = list(/obj/machinery/computer/camera_advanced/shuttle_docker/survey)
	ui_focus = list("survey" = "survey_start")

/datum/vc_tutorial_step/surveys_survey/live_line(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!ship)
		return null
	var/obj/machinery/computer/camera_advanced/shuttle_docker/survey/console = ship.survey_console?.resolve()
	if(!console)
		return "No survey console aboard."
	if(console.survey_in_progress)
		return "Surveying. Keep the ship still."
	if(console.tutorial_moved_at && world.time < console.tutorial_moved_at + 2 MINUTES)
		return "The last survey stopped when the ship moved."
	if(!ship.is_still())
		return "The ship is moving."
	var/list/blacklisted_types = console.get_blacklisted_overmap_types()
	for(var/obj/structure/overmap/object in ship.close_overmap_objects)
		if(!is_type_in_list(object, blacklisted_types))
			return "Over [object.name]."
	return "Nothing to survey on this tile."

/datum/vc_tutorial_step/surveys_notes
	key = TUTORIAL_STEP_SURVEYS_NOTES
	name = "Turn in the notes"
	text = "Print the notes on the survey console's Research tab and use them on the R&D console."
	highlight_types = list(/obj/machinery/computer/camera_advanced/shuttle_docker/survey, /obj/item/research_notes, /obj/machinery/computer/rdconsole)
	ui_focus = list("survey" = "survey_print")

/// The survey console only while it has research waiting to print.
/datum/vc_tutorial_step/surveys_notes/highlight_filter(mob/user, atom/candidate)
	var/obj/machinery/computer/camera_advanced/shuttle_docker/survey/console = candidate
	if(istype(console))
		return console.banked_points > 0
	return TRUE

/datum/vc_tutorial_step/surveys_notes/live_line(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	var/obj/machinery/computer/camera_advanced/shuttle_docker/survey/console = ship?.survey_console?.resolve()
	if(console?.banked_points > 0)
		return "[console.banked_points] research waiting to print."
	return null

// ---------------------------------------------------------------------------
// Planet ruin
// ---------------------------------------------------------------------------

/datum/vc_tutorial/ruin
	id = TUTORIAL_ITEM_RUIN
	name = "Planet ruin"
	category = TUTORIAL_CATEGORY_EXPLORE
	order = 2
	intro = "Planets are dotted with ruins people left behind. Most hold loot, often an abandoned cache, and usually something guarding it."
	steps = list(
		/datum/vc_tutorial_step/ruin_land,
		/datum/vc_tutorial_step/ruin_find,
		/datum/vc_tutorial_step/ruin_cache,
	)

/datum/vc_tutorial_step/ruin_land
	key = TUTORIAL_STEP_RUIN_LAND
	name = "Land on a planet"
	text = "Fly onto a planet and press Dock at the helm."
	highlight_types = list(/obj/machinery/computer/helm)
	ui_focus = list("helm" = "helm_dock")

/// Already berthed on a planet, or standing on one: a late joiner walks straight out.
/datum/vc_tutorial_step/ruin_land/state_satisfied(mob/user)
	return !!tutorial_planet_under(user)

/datum/vc_tutorial_step/ruin_land/live_line(mob/user)
	var/obj/structure/overmap/ship/ship = get_ship_from_atom(user)
	var/obj/structure/overmap/berth = ship?.docked
	if(!berth || tutorial_planet_under(user))
		return null
	return "Docked at [berth]."

/datum/vc_tutorial_step/ruin_find
	key = TUTORIAL_STEP_RUIN_FIND
	name = "Find a ruin"
	text = "Walk out and explore until you find a place someone left behind."

/// Open-air ruins have no ruin area to walk into, so standing inside one's footprint counts.
/datum/vc_tutorial_step/ruin_find/state_satisfied(mob/user)
	return tutorial_ruin_footprint_check(user, credit = FALSE)

/datum/vc_tutorial_step/ruin_find/arrow_target(mob/user)
	if(tutorial_ruin_footprint_check(user, credit = TRUE))
		return null
	var/obj/effect/landmark/ruin/mark = tutorial_nearest_ruin_landmark(user)
	return mark ? get_turf(mark) : null

/datum/vc_tutorial_step/ruin_find/live_line(mob/user)
	var/obj/effect/landmark/ruin/mark = tutorial_nearest_ruin_landmark(user)
	var/turf/here = get_turf(user)
	var/turf/there = get_turf(mark)
	if(!here || !there || tutorial_in_ruin_footprint(here, mark))
		return null
	var/distance = max(10, round(get_dist(here, there), 10))
	return "A ruin lies about [distance] tiles [dir2text(get_dir(here, there))]."

/datum/vc_tutorial_step/ruin_cache
	key = TUTORIAL_STEP_RUIN_CACHE
	name = "Open the cache"
	text = "Find the abandoned cache and open it. A locked one needs a code; a multitool on it rates your last try."
	highlight_types = list(/obj/structure/closet/crate/zone_loot, /obj/structure/closet/crate/secure/loot)

/// Unopened caches in the ruin the viewer is in or near, so the arrow finds one behind walls.
/datum/vc_tutorial_step/ruin_cache/extra_targets(mob/user)
	return tutorial_nearby_ruin_caches(user)

/// Closed, found caches only: never a bought one, never one aboard a ship.
/datum/vc_tutorial_step/ruin_cache/highlight_filter(mob/user, atom/candidate)
	var/obj/structure/closet/cache = candidate
	return istype(cache) && !cache.opened && tutorial_countable_cache(cache)

/datum/vc_tutorial_step/ruin_cache/live_line(mob/user)
	var/obj/effect/landmark/ruin/mark = tutorial_nearest_ruin_landmark(user)
	if(!mark || !tutorial_in_ruin_footprint(get_turf(user), mark))
		return null
	for(var/obj/structure/closet/cache as anything in GLOB.tutorial_ruin_caches)
		if(!cache.opened && tutorial_countable_cache(cache) && tutorial_in_ruin_footprint(get_turf(cache), mark))
			return null
	return "No closed cache left in this ruin."

// ---------------------------------------------------------------------------
// Outpost trade
// ---------------------------------------------------------------------------

/datum/vc_tutorial/trade
	id = TUTORIAL_ITEM_TRADE
	name = "Outpost trade"
	category = TUTORIAL_CATEGORY_EXPLORE
	order = 3
	intro = "Outposts are where you buy gear and sell what you found. Each trader has their own stock and a list of things they want."
	steps = list(
		/datum/vc_tutorial_step/trade_travel,
		/datum/vc_tutorial_step/trade_elevator,
		/datum/vc_tutorial_step/trade_buy,
		/datum/vc_tutorial_step/trade_sell,
	)

/datum/vc_tutorial_step/trade_travel
	key = TUTORIAL_STEP_TRADE_TRAVEL
	name = "Travel to an outpost and dock"
	text = "Fly to a trading outpost and press Dock at the helm."
	highlight_types = list(/obj/machinery/computer/helm)
	ui_focus = list("helm" = "helm_dock")

/datum/vc_tutorial_step/trade_elevator
	key = TUTORIAL_STEP_TRADE_ELEVATOR
	name = "Ride the elevator"
	text = "Stand in the elevator by your berth's panel and pick the concourse."
	highlight_types = list(/obj/machinery/outpost_elevator)
	ui_focus = list("elevator" = "elevator_concourse")

/datum/vc_tutorial_step/trade_buy
	key = TUTORIAL_STEP_TRADE_BUY
	name = "Buy something"
	text = "Click a trader, pick Trade and buy from their stock."
	highlight_types = list(/mob/living/basic/outpost_trader)
	ui_focus = list("trader" = "trader_buy")

/datum/vc_tutorial_step/trade_sell
	key = TUTORIAL_STEP_TRADE_SELL
	name = "Sell something"
	text = "Open a trader's Buys tab and sell what they want while carrying it. They won't buy back shop goods."
	highlight_types = list(/mob/living/basic/outpost_trader)
	ui_focus = list("trader" = "trader_sell")

// ---------------------------------------------------------------------------
// Ship power
// ---------------------------------------------------------------------------

/datum/vc_tutorial/power
	id = TUTORIAL_ITEM_POWER
	name = "Ship power"
	category = TUTORIAL_CATEGORY_START
	order = 2
	intro = "Most ships store their power in SMES batteries in engineering. A fuel generator recharges them while it runs. Each room has an APC that switches its lights, machines and air on or off."
	steps = list(
		/datum/vc_tutorial_step/power_smes,
		/datum/vc_tutorial_step/power_generator,
		/datum/vc_tutorial_step/power_apc,
	)

/datum/vc_tutorial_step/power_smes
	key = TUTORIAL_STEP_POWER_SMES
	name = "Check the batteries"
	text = "Find the SMES in engineering. It powers the ship."
	highlight_types = list(/obj/machinery/power/smes)

/datum/vc_tutorial_step/power_smes/availability(mob/user)
	if(excused(user))
		return "No batteries aboard."
	return null

/// Some small hulls run straight off a generator with no SMES at all.
/datum/vc_tutorial_step/power_smes/excused(mob/user)
	if(..())
		return TRUE
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return ship && !SSvc_tutorials.ship_has_machine(ship, /obj/machinery/power/smes)

/datum/vc_tutorial_step/power_smes/live_line(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!ship || !SSvc_tutorials.ship_has_machine(ship, /obj/machinery/power/smes))
		return null
	var/stored = 0
	var/capacity = 0
	var/output_off = FALSE
	for(var/obj/machinery/power/smes/battery as anything in ship.get_ship_machines(/obj/machinery/power/smes))
		if(!battery.output_attempt)
			output_off = TRUE
		for(var/obj/item/stock_parts/power_store/cell in battery.component_parts)
			stored += cell.charge()
			capacity += cell.max_charge()
	if(output_off)
		return "A battery's output is switched off."
	if(capacity <= 0)
		return null
	return "Batteries at [round(stored / capacity * 100)]%."

/datum/vc_tutorial_step/power_generator
	key = TUTORIAL_STEP_POWER_GENERATOR
	name = "Start the generator"
	text = "Bolt the generator down, load its fuel sheets and turn it on."
	highlight_types = list(/obj/machinery/power/port_gen)

/datum/vc_tutorial_step/power_generator/live_line(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!ship || !SSvc_tutorials.ship_has_machine(ship, /obj/machinery/power/port_gen))
		return null
	var/obj/machinery/power/port_gen/generator = tutorial_power_nearest(user, ship.get_ship_machines(/obj/machinery/power/port_gen))
	if(!generator)
		return null
	if(generator.active)
		return "Running."
	if(!generator.anchored)
		return "Not bolted down. Wrench it to the floor."
	var/obj/machinery/power/port_gen/pacman/pacman = generator
	if(istype(pacman) && !pacman.HasFuel())
		var/obj/item/fuel = pacman.sheet_path
		return "No [initial(fuel.name)] loaded."
	return "Ready. Turn it on."

/datum/vc_tutorial_step/power_generator/availability(mob/user)
	if(excused(user))
		return "No generator aboard. The general store sells one."
	return null

/datum/vc_tutorial_step/power_generator/excused(mob/user)
	if(..())
		return TRUE
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return ship && !SSvc_tutorials.ship_has_machine(ship, /obj/machinery/power/port_gen)

/datum/vc_tutorial_step/power_apc
	key = TUTORIAL_STEP_POWER_APC
	name = "Use an APC"
	text = "Each room has a power panel on the wall. Right-click it to unlock it, then switch things off or back on."
	highlight_types = list(/obj/machinery/power/apc)

/// The panel for the room the viewer stands in, when it has one; otherwise any.
/datum/vc_tutorial_step/power_apc/highlight_filter(mob/user, atom/candidate)
	var/obj/machinery/power/apc/room_apc = tutorial_room_apc(user)
	return !room_apc || candidate == room_apc

/datum/vc_tutorial_step/power_apc/live_line(mob/user)
	var/obj/machinery/power/apc/room_apc = tutorial_room_apc(user)
	if(!room_apc)
		return null
	return room_apc.locked ? "This room's panel is locked." : "This room's panel is unlocked."

/// The APC of the ship room the viewer stands in, or null.
/proc/tutorial_room_apc(mob/user)
	var/area/room = get_area(user)
	var/obj/machinery/power/apc/room_apc = room?.apc
	if(QDELETED(room_apc) || !get_ship_from_atom(room_apc))
		return null
	return room_apc

/// The atom in a list nearest the viewer on their z-level, or null.
/proc/tutorial_power_nearest(mob/user, list/things)
	var/turf/here = get_turf(user)
	if(!here)
		return null
	var/atom/best
	var/best_dist = INFINITY
	for(var/atom/thing as anything in things)
		var/turf/spot = get_turf(thing)
		if(spot?.z != here.z)
			continue
		var/dist = get_dist(here, spot)
		if(dist < best_dist)
			best = thing
			best_dist = dist
	return best

// ---------------------------------------------------------------------------
// Cyberware
// ---------------------------------------------------------------------------

/datum/vc_tutorial/chrome
	id = TUTORIAL_ITEM_CHROME
	name = "Cyberware"
	category = TUTORIAL_CATEGORY_BODY
	order = 1
	intro = "Chrome is cybernetic parts fitted into your body. Some of it lets you finish off a downed enemy in one move."
	steps = list(
		/datum/vc_tutorial_step/chrome_buy,
		/datum/vc_tutorial_step/chrome_install,
		/datum/vc_tutorial_step/chrome_execute,
	)

/datum/vc_tutorial_step/chrome_buy
	key = TUTORIAL_STEP_CHROME_BUY
	name = "Buy chrome"
	text = "Halcyon's general store sells a little street chrome. The Back Bay at Quartermain Depot sells more, and the Chop Shop in the red zone sells the rest."
	highlight_types = list(/mob/living/basic/outpost_trader)

/// Only traders whose shelf holds chrome.
/datum/vc_tutorial_step/chrome_buy/highlight_filter(mob/user, atom/candidate)
	var/mob/living/basic/outpost_trader/trader = candidate
	if(!istype(trader))
		return FALSE
	return tutorial_shop_sells_chrome(trader.shop)

/// Chrome found in the field and fitted counts: nobody has to buy what they already wear.
/datum/vc_tutorial_step/chrome_buy/excused(mob/user)
	. = ..()
	if(!.)
		. = SSvc_tutorials.has_key(tutorial_viewer_ckey(user), TUTORIAL_STEP_CHROME_INSTALL)

/datum/vc_tutorial_step/chrome_install
	key = TUTORIAL_STEP_CHROME_INSTALL
	name = "Get it installed"
	text = "Lie in a Chrome Cradle at the Back Bay or the Chop Shop, pick the part and press Install. Surgery can fit it too."
	highlight_types = list(/obj/machinery/chrome_cradle)
	ui_focus = list("cradle" = "cradle_install")

/// Cradles are outpost machines, never in a ship scan: any on the viewer's z-level, so the
/// arrow can lead to one.
/datum/vc_tutorial_step/chrome_install/extra_targets(mob/user)
	. = list()
	var/turf/here = get_turf(user)
	if(!here)
		return
	for(var/obj/machinery/chrome_cradle/cradle as anything in SSmachines.get_machines_by_type(/obj/machinery/chrome_cradle))
		if(cradle.z == here.z)
			. += cradle

/datum/vc_tutorial_step/chrome_install/live_line(mob/user)
	var/obj/item/organ/ware = tutorial_carried_chrome(user)
	if(!ware)
		return null
	var/where = parse_zone(deprecise_zone(ware.zone))
	if(!cyberware_insert_check(ware, user, silent = TRUE))
		return "[format_text(ware.name)] ([where]) won't fit."
	return "[format_text(ware.name)] goes in your [where]."

/// Chrome already in the body counts, whoever fitted it and whenever.
/datum/vc_tutorial_step/chrome_install/state_satisfied(mob/user)
	return length(get_installed_cyberware(user)) > 0

/datum/vc_tutorial_step/chrome_execute
	key = TUTORIAL_STEP_CHROME_EXECUTE
	name = "Do an execution"
	text = "Get someone down, stand square on, then finish them with Brawler Myomers, Gorilla Arms, Mantis Blades or a Widowline."

/datum/vc_tutorial_step/chrome_execute/live_line(mob/user)
	var/list/state = tutorial_chrome_finisher_state(user)
	return state[1]

/// Someone the viewer could finish right now, if they carry a finisher. Only bodies already
/// down within a few tiles, in plain sight.
/datum/vc_tutorial_step/chrome_execute/extra_targets(mob/user)
	. = list()
	var/list/state = tutorial_chrome_finisher_state(user)
	if(!state[2])
		return
	for(var/mob/living/carbon/victim in oview(3, user))
		if(chrome_finisher_valid_victim(user, victim))
			. += victim

// ---------------------------------------------------------------------------
// First surgery
// ---------------------------------------------------------------------------

/datum/vc_tutorial/surgery
	id = TUTORIAL_ITEM_SURGERY
	name = "First surgery"
	category = TUTORIAL_CATEGORY_BODY
	order = 2
	intro = "Surgery heals wounds and works on organs. The patient lies down under a sheet or drapes, and each step needs the right tool. Dissecting a body adds to your ship's research."
	steps = list(
		/datum/vc_tutorial_step/surgery_start,
		/datum/vc_tutorial_step/surgery_finish,
		/datum/vc_tutorial_step/surgery_dissect,
	)

/datum/vc_tutorial_step/surgery_start
	key = TUTORIAL_STEP_SURGERY_START
	name = "Start an operation"
	text = "Lay a crewmate or yourself on a table or bed, cover them with a bedsheet or surgical drapes, aim at the chest and pick Tend Wounds. The autolathe prints the tools."
	highlight_types = list(/obj/structure/table, /obj/structure/bed, /obj/item/bedsheet)
	ui_focus = list("surgery" = "surgery_tend_wounds")

/// Missing tools: the autolathe. Then a sheet. Then somewhere to lie down.
/datum/vc_tutorial_step/surgery_start/extra_targets(mob/user)
	. = list()
	var/list/missing = tutorial_surgery_missing(user)
	if(!length(missing) || (length(missing) == 1 && missing[1] == "a sheet"))
		return
	var/obj/structure/overmap/ship/ship = get_ship_from_atom(user)
	if(!ship)
		return
	for(var/obj/machinery/autolathe/lathe as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/autolathe))
		if(lathe.z == user.z && get_ship_from_atom(lathe) == ship)
			. += lathe

/datum/vc_tutorial_step/surgery_start/highlight_filter(mob/user, atom/candidate)
	if(istype(candidate, /obj/machinery/autolathe))
		return TRUE
	var/list/missing = tutorial_surgery_missing(user)
	if(istype(candidate, /obj/item/bedsheet))
		return length(missing) == 1 && missing[1] == "a sheet"
	return !length(missing)

/datum/vc_tutorial_step/surgery_start/live_line(mob/user)
	var/list/missing = tutorial_surgery_missing(user)
	if(!length(missing))
		return null
	return "Missing: [english_list(missing)]."

/datum/vc_tutorial_step/surgery_finish
	key = TUTORIAL_STEP_SURGERY_FINISH
	name = "Finish it"
	text = "Use the tool each step names, in your active hand, until you mend the incision."

/datum/vc_tutorial_step/surgery_finish/live_line(mob/user)
	var/datum/surgery/operation = tutorial_surgery_in_reach(user)
	var/datum/surgery_step/next = operation && GLOB.surgery_steps[operation.steps[operation.status]]
	if(!next)
		return null
	return "Next: [next.name]."

/// The patient of an operation the viewer is working on (never the viewer themselves).
/datum/vc_tutorial_step/surgery_finish/extra_targets(mob/user)
	. = list()
	var/datum/surgery/operation = tutorial_surgery_in_reach(user)
	var/mob/living/patient = operation?.target
	if(patient && patient != user)
		. += patient

/datum/vc_tutorial_step/surgery_dissect
	key = TUTORIAL_STEP_SURGERY_DISSECT
	name = "Dissect a body"
	text = "Lay a corpse or dead creature on a table, cover it, aim at the chest and pick Dissection. Take the notes it gives you to an R&D console."
	highlight_types = list(/obj/structure/table/optable)
	ui_focus = list("surgery" = "surgery_dissection")

/// Dead bodies in sight that still have something to teach.
/datum/vc_tutorial_step/surgery_dissect/extra_targets(mob/user)
	. = list()
	var/static/datum/surgery_step/experimental_dissection/pricer
	if(!pricer)
		pricer = new
	for(var/mob/living/body in oview(9, user))
		if(body.stat != DEAD || HAS_TRAIT(body, TRAIT_DISSECTED) || !isturf(body.loc))
			continue
		if(pricer.check_value(body) > body.dissection_points_paid)
			. += body

// ---------------------------------------------------------------------------
// Zones (replaces the old orientation briefing)
// ---------------------------------------------------------------------------

/datum/vc_tutorial/zones
	id = TUTORIAL_ITEM_ZONES
	name = "Zones"
	category = TUTORIAL_CATEGORY_FIGHT
	order = 1
	intro = "Space is split into green, yellow and red zones. Green is safe from other crews. In yellow crews can board each other, and in red anything goes."
	steps = list(
		/datum/vc_tutorial_step/zones_yellow,
		/datum/vc_tutorial_step/zones_warfare,
		/datum/vc_tutorial_step/zones_red,
	)

/datum/vc_tutorial_step/zones_yellow
	key = TUTORIAL_STEP_ZONES_YELLOW
	name = "Enter the yellow zone"
	text = "Green space has no fighting between crews. In yellow, other crews can board and rob you."
	highlight_types = list(/obj/machinery/computer/helm)

/datum/vc_tutorial_step/zones_warfare
	key = TUTORIAL_STEP_ZONES_WARFARE
	name = "Research Shuttle Warfare Systems"
	text = "At the R&D console. It leads to shields, guns, missiles and an interdictor for your ship."
	highlight_types = list(/obj/machinery/computer/rdconsole)

/datum/vc_tutorial_step/zones_warfare/state_satisfied(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return ship && ship.has_ship_combat_research()

/datum/vc_tutorial_step/zones_red
	key = TUTORIAL_STEP_ZONES_RED
	name = "Enter the red zone"
	text = "Anything goes in red. Ships fire on each other and players can kill you for nothing."
	optional = TRUE
	highlight_types = list(/obj/machinery/computer/helm)

// ---------------------------------------------------------------------------
// Ship weapons
// ---------------------------------------------------------------------------

/datum/vc_tutorial/weapons
	id = TUTORIAL_ITEM_WEAPONS
	name = "Ship weapons"
	category = TUTORIAL_CATEGORY_FIGHT
	order = 2
	intro = "Ship weapons come from Shuttle Warfare Systems research and only fire in red space. Shields, the interdictor and electronic warfare also need crew reputation to research."
	steps = list(
		/datum/vc_tutorial_step/weapons_console,
		/datum/vc_tutorial_step/weapons_launcher,
		/datum/vc_tutorial_step/weapons_missile,
		/datum/vc_tutorial_step/weapons_laser,
		/datum/vc_tutorial_step/weapons_shield,
		/datum/vc_tutorial_step/weapons_interdictor,
		/datum/vc_tutorial_step/weapons_ew,
	)

/// A note while the viewer's crew is below the reputation that ZONE_PERMISSION_ADVANCED
/// research needs. Reads the crew record without creating one.
/datum/vc_tutorial_step/proc/crew_reputation_note(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	var/datum/voidcrew_crew_record/record = ship?.ship_team?.crew_record
	if(QDELETED(record) || record.get_zone_permission() < ZONE_PERMISSION_ADVANCED)
		return "Needs more crew reputation."
	return null

/datum/vc_tutorial_step/weapons_console
	key = TUTORIAL_STEP_WEAPONS_CONSOLE
	name = "Build a weapons console"
	text = "Print the weapons console board and build it in a computer frame."
	highlight_types = list(/obj/structure/frame/computer)

/datum/vc_tutorial_step/weapons_launcher
	key = TUTORIAL_STEP_WEAPONS_LAUNCHER
	name = "Build a missile launcher"
	text = "Print the launcher board, build it in a machine frame, then drag it onto an outer wall."
	highlight_types = list(/obj/structure/frame/machine)

/datum/vc_tutorial_step/weapons_missile
	key = TUTORIAL_STEP_WEAPONS_MISSILE
	name = "Arm a missile"
	text = "Print a missile frame, wire it, add a tracking circuit and a warhead, then screwdriver it shut."
	highlight_types = list(/obj/structure/ship_missile)

/datum/vc_tutorial_step/weapons_laser
	key = TUTORIAL_STEP_WEAPONS_LASER
	name = "Build a laser turret"
	text = "Print the turret board, build it in a machine frame, then drag it onto an outer wall."
	highlight_types = list(/obj/structure/frame/machine)

/datum/vc_tutorial_step/weapons_shield
	key = TUTORIAL_STEP_WEAPONS_SHIELD
	name = "Build a shield generator"
	text = "Print the shield generator board and build it in a machine frame."
	highlight_types = list(/obj/structure/frame/machine)

/datum/vc_tutorial_step/weapons_shield/availability(mob/user)
	return crew_reputation_note(user)

/datum/vc_tutorial_step/weapons_interdictor
	key = TUTORIAL_STEP_WEAPONS_INTERDICTOR
	name = "Build an interdictor"
	text = "Print the interdictor board and build it in a machine frame."
	highlight_types = list(/obj/structure/frame/machine)

/datum/vc_tutorial_step/weapons_interdictor/availability(mob/user)
	return crew_reputation_note(user)

/datum/vc_tutorial_step/weapons_ew
	key = TUTORIAL_STEP_WEAPONS_EW
	name = "Build an EW suite"
	text = "Print the EW suite board and build it in a machine frame. Link it to the weapons console with a multitool and load a cartridge."
	highlight_types = list(/obj/structure/frame/machine)

/datum/vc_tutorial_step/weapons_ew/availability(mob/user)
	return crew_reputation_note(user)

// ---------------------------------------------------------------------------
// Ship combat
// ---------------------------------------------------------------------------

/datum/vc_tutorial/combat
	id = TUTORIAL_ITEM_COMBAT
	name = "Ship combat"
	category = TUTORIAL_CATEGORY_FIGHT
	order = 3
	intro = "Ship weapons and hacking only work in red space. The interdictor also works in yellow space and holds a ship so you can hit it or board it."
	steps = list(
		/datum/vc_tutorial_step/combat_interdict,
		/datum/vc_tutorial_step/combat_missile,
		/datum/vc_tutorial_step/combat_shields,
		/datum/vc_tutorial_step/combat_hack,
		/datum/vc_tutorial_step/combat_force_dock,
	)

/datum/vc_tutorial_step/combat_interdict
	key = TUTORIAL_STEP_COMBAT_INTERDICT
	name = "Interdict a ship"
	text = "Lock the interdictor onto a ship close by. It slows them down and stops them docking."
	highlight_types = list(/obj/machinery/ship_combat/interdictor)

/datum/vc_tutorial_step/combat_missile
	key = TUTORIAL_STEP_COMBAT_MISSILE
	name = "Launch a missile"
	text = "Load an armed missile into the launcher, pick a ship at the weapons console and fire."
	highlight_types = list(/obj/machinery/computer/camera_advanced/ship_combat)

/datum/vc_tutorial_step/combat_shields
	key = TUTORIAL_STEP_COMBAT_SHIELDS
	name = "Bring down their shields"
	text = "Keep hitting a shielded ship with missiles or lasers until its shield fails."
	highlight_types = list(/obj/machinery/computer/camera_advanced/ship_combat)

/datum/vc_tutorial_step/combat_hack
	key = TUTORIAL_STEP_COMBAT_HACK
	name = "Hack a ship"
	text = "Lock onto a ship at the weapons console and run a cartridge from the EW suite."
	highlight_types = list(/obj/machinery/computer/camera_advanced/ship_combat)

/datum/vc_tutorial_step/combat_force_dock
	key = TUTORIAL_STEP_COMBAT_FORCE_DOCK
	name = "Force-dock a ship"
	text = "Fly onto the ship you're holding and force it to dock with you from the interdictor."
	optional = TRUE
	highlight_types = list(/obj/machinery/ship_combat/interdictor)

// ---------------------------------------------------------------------------
// Hunting pirates
// ---------------------------------------------------------------------------

/datum/vc_tutorial/pirates
	id = TUTORIAL_ITEM_PIRATES
	name = "Hunting pirates"
	category = TUTORIAL_CATEGORY_FIGHT
	order = 4
	intro = "Pirate ships hunt crews in red space. You can let them board and then take the fight to their ship, or shoot their ship down from yours. In yellow space they only board a crew that's broke."
	steps = list(
		/datum/vc_tutorial_step/pirates_boarders,
		/datum/vc_tutorial_step/pirates_commander,
		/datum/vc_tutorial_step/pirates_board,
		/datum/vc_tutorial_step/pirates_shoot,
		/datum/vc_tutorial_step/pirates_claim,
	)

/datum/vc_tutorial_step/pirates_boarders
	key = TUTORIAL_STEP_PIRATES_BOARDERS
	name = "Hold off the boarders"
	text = "They board in one wave sized to your crew. Kill or cuff every one of them."
	route = "board"
	route_name = "Let them board"

/datum/vc_tutorial_step/pirates_commander
	key = TUTORIAL_STEP_PIRATES_COMMANDER
	name = "Beat their commander"
	text = "In red space their commander pods in after the wave. Kill them, put them down or cuff them."
	route = "board"
	route_name = "Let them board"

/datum/vc_tutorial_step/pirates_board
	key = TUTORIAL_STEP_PIRATES_BOARD
	name = "Board their ship"
	text = "Dock with their ship from the helm, or force-dock it with the interdictor."
	route = "board"
	route_name = "Let them board"
	highlight_types = list(/obj/machinery/computer/helm)

/datum/vc_tutorial_step/pirates_shoot
	key = TUTORIAL_STEP_PIRATES_SHOOT
	name = "Shoot them down"
	text = "Hit their hull with missiles and lasers until it fails."
	route = "shoot"
	route_name = "Fight ship to ship"
	highlight_types = list(/obj/machinery/computer/camera_advanced/ship_combat)

/datum/vc_tutorial_step/pirates_claim
	key = TUTORIAL_STEP_PIRATES_CLAIM
	name = "Claim the hull"
	text = "Clear out their crew, then claim the ship at its helm."
	optional = TRUE
	ui_focus = list("helm" = "helm_claim")

// ---------------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------------

/datum/vc_tutorial/storage
	id = TUTORIAL_ITEM_STORAGE
	name = "Storage"
	category = TUTORIAL_CATEGORY_START
	order = 4
	intro = "Loose items get lost fast on a ship. Cargo shelves stack crates out of the way, and smart lockers keep items sorted for the whole crew."
	steps = list(
		/datum/vc_tutorial_step/storage_shelf,
		/datum/vc_tutorial_step/storage_crate,
		/datum/vc_tutorial_step/storage_locker,
		/datum/vc_tutorial_step/storage_store,
	)

/datum/vc_tutorial_step/storage_shelf
	key = TUTORIAL_STEP_STORAGE_SHELF
	name = "Build a cargo shelf"
	text = "Make cargo shelf parts from four iron sheets, then use them where the shelf should stand."

/datum/vc_tutorial_step/storage_crate
	key = TUTORIAL_STEP_STORAGE_CRATE
	name = "Shelve a crate"
	text = "Drag a crate onto a cargo shelf to lift it up."
	highlight_types = list(/obj/structure/cargo_shelf)

/datum/vc_tutorial_step/storage_locker
	key = TUTORIAL_STEP_STORAGE_LOCKER
	name = "Build a smart locker"
	text = "Print a Smart Locker board and build it in a machine frame."
	highlight_types = list(/obj/machinery/rnd/production/circuit_imprinter)

/datum/vc_tutorial_step/storage_store
	key = TUTORIAL_STEP_STORAGE_STORE
	name = "Fill a smart locker"
	text = "Put an item in a smart locker, or drag a bag onto it to empty the bag."
	highlight_types = list(/obj/machinery/smartfridge/storage)

// ---------------------------------------------------------------------------
// Repair drones
// ---------------------------------------------------------------------------

/datum/vc_tutorial/repair_drones
	id = TUTORIAL_ITEM_REPAIR_DRONES
	name = "Repair drones"
	category = TUTORIAL_CATEGORY_KEEP
	order = 1
	intro = "Repair drones fix hull damage while you fly. They rebuild it with ore from your ship's silo."
	steps = list(
		/datum/vc_tutorial_step/repair_drones_research,
		/datum/vc_tutorial_step/repair_drones_assemble,
		/datum/vc_tutorial_step/repair_drones_link,
		/datum/vc_tutorial_step/repair_drones_repair,
	)

/datum/vc_tutorial_step/repair_drones_research
	key = TUTORIAL_STEP_REPAIR_DRONES_RESEARCH
	name = "Research Shuttle Repair Swarm"
	text = "At the R&D console, after Shuttle Automation, Robotics and Mech Assembly."
	highlight_types = list(/obj/machinery/computer/rdconsole)

/datum/vc_tutorial_step/repair_drones_research/state_satisfied(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	var/datum/techweb/web = ship?.get_research_web()
	return web && (TECHWEB_NODE_SHIP_REPAIR_SWARM in web.researched_nodes)

/datum/vc_tutorial_step/repair_drones_assemble
	key = TUTORIAL_STEP_REPAIR_DRONES_ASSEMBLE
	name = "Assemble a drone"
	text = "Print the four drone parts at an exosuit fabricator and fit them to the chassis."
	highlight_types = list(/obj/machinery/mecha_part_fabricator)

/datum/vc_tutorial_step/repair_drones_link
	key = TUTORIAL_STEP_REPAIR_DRONES_LINK
	name = "Link the drone"
	text = "Install the repair swarm disk, then use a multitool on the construction console and the drone."
	highlight_types = list(/obj/machinery/computer/camera_advanced/base_construction/ship, /obj/structure/ship_repair_drone)

/datum/vc_tutorial_step/repair_drones_repair
	key = TUTORIAL_STEP_REPAIR_DRONES_REPAIR
	name = "Watch it repair"
	text = "Take hull damage while flying. Linked drones rebuild it from the ore silo."

// ---------------------------------------------------------------------------
// Save your ship
// ---------------------------------------------------------------------------

/datum/vc_tutorial/ship_save
	id = TUTORIAL_ITEM_SHIP_SAVE
	name = "Save your ship"
	category = TUTORIAL_CATEGORY_KEEP
	order = 2
	intro = "A saved ship can be loaded again in a later round. Saving happens at a crew outpost with ship bays."
	steps = list(
		/datum/vc_tutorial_step/ship_save_dock,
		/datum/vc_tutorial_step/ship_save_save,
		/datum/vc_tutorial_step/ship_save_load,
	)

/datum/vc_tutorial_step/ship_save_dock
	key = TUTORIAL_STEP_SHIP_SAVE_DOCK
	name = "Dock in a ship bay"
	text = "Dock at a crew outpost that has ship bays."
	highlight_types = list(/obj/machinery/computer/helm)
	ui_focus = list("helm" = "helm_dock_bay")

/// Only the captain can save or load a ship.
/datum/vc_tutorial_step/proc/captain_only_note(mob/user)
	if(excused(user))
		return "Captain only."
	return null

/datum/vc_tutorial_step/ship_save_save
	key = TUTORIAL_STEP_SHIP_SAVE_SAVE
	name = "Save the ship"
	text = "At the bay's shipyard console, open Saved ships and save your ship to a slot."
	highlight_types = list(/obj/machinery/computer/ship_checkpoint)

/datum/vc_tutorial_step/ship_save_save/availability(mob/user)
	return captain_only_note(user)

/datum/vc_tutorial_step/ship_save_save/excused(mob/user)
	if(..())
		return TRUE
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return ship && !ship.is_ship_captain(user)

/datum/vc_tutorial_step/ship_save_load
	key = TUTORIAL_STEP_SHIP_SAVE_LOAD
	name = "Load a saved ship"
	text = "Pick a saved ship when you join, or build it at a shipyard console once the old hull is gone."
	optional = TRUE
	highlight_types = list(/obj/machinery/computer/ship_checkpoint)

// ---------------------------------------------------------------------------
// Vestige pact
// ---------------------------------------------------------------------------

/datum/vc_tutorial/vestige
	id = TUTORIAL_ITEM_VESTIGE
	name = "Vestige pact"
	category = TUTORIAL_CATEGORY_FIGHT
	order = 10
	intro = "Vestiges are strange places that show up during the round. The patron inside sets you one trial, and finishing it earns a boon."
	steps = list(
		/datum/vc_tutorial_step/vestige_find,
		/datum/vc_tutorial_step/vestige_pact,
		/datum/vc_tutorial_step/vestige_trial,
		/datum/vc_tutorial_step/vestige_claim,
	)

/datum/vc_tutorial_step/vestige_find
	key = TUTORIAL_STEP_VESTIGE_FIND
	name = "Find a vestige"
	text = "Vestiges surface during the round. The helm lists each one under its patron's name. Fly to one and go inside."

/datum/vc_tutorial_step/vestige_find/live_line(mob/user)
	var/obj/structure/overmap/ship/ship = get_ship_from_atom(user)
	var/surfaced = FALSE
	for(var/obj/structure/overmap/space_ruin/vestige/signal in GLOB.space_ruin_signals)
		if(QDELETED(signal))
			continue
		surfaced = TRUE
		if(ship?.discovered_contacts?[REF(signal)])
			return "Your helm has charted [signal]."
	if(!surfaced)
		return "None have surfaced yet."
	return ship ? "One has surfaced. Your helm hasn't found it yet." : "One has surfaced."

/datum/vc_tutorial_step/vestige_pact
	key = TUTORIAL_STEP_VESTIGE_PACT
	name = "Make a pact"
	text = "Click the patron inside with an empty hand and choose Pact. It sets you one trial."
	highlight_types = list(/mob/living/basic/vestige_patron)

/// Patrons in the vestige the viewer is in, so the arrow finds one behind walls. They never move.
/datum/vc_tutorial_step/vestige_pact/extra_targets(mob/user)
	return tutorial_nearby_patrons(user)

/datum/vc_tutorial_step/vestige_pact/live_line(mob/user)
	var/datum/mind/mind = user.mind
	var/datum/action/vestige_reward/pending = mind?.vestige_pending_reward
	if(pending)
		return "A patron still owes you a boon."
	var/datum/vestige_trial/active = mind?.active_vestige_trial
	if(active)
		return "You already have a pact with [active.patron_name]."
	return null

/datum/vc_tutorial_step/vestige_trial
	key = TUTORIAL_STEP_VESTIGE_TRIAL
	name = "Complete the trial"
	text = "Do what the patron asked. Click the pact button on your screen to read the terms again."

/datum/vc_tutorial_step/vestige_trial/live_line(mob/user)
	var/datum/vestige_trial/active = user.mind?.active_vestige_trial
	if(!active)
		return null
	return "[active.name]: [active.get_progress_text()]"

/datum/vc_tutorial_step/vestige_claim
	key = TUTORIAL_STEP_VESTIGE_CLAIM
	name = "Claim your boon"
	text = "Use the Claim Your Boon button and pick one."

/datum/vc_tutorial_step/vestige_claim/live_line(mob/user)
	var/datum/vestige_record/record = get_vestige_record(user.mind)
	if(!user.mind?.vestige_pending_reward)
		return null
	return record?.pending_patron_name ? "[record.pending_patron_name] owes you a boon." : "A boon is waiting for you."
