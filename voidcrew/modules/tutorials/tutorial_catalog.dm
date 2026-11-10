/**
 * # Tutorial checklist catalog
 *
 * One /datum/vc_tutorial per checklist item and one /datum/vc_tutorial_step per step,
 * each a singleton owned by SSvc_tutorials. Steps are credited passively by hooks
 * (hooks_*.dm) calling tutorial_credit() or tutorial_credit_crew() with a step key
 * from voidcrew/_DEFINES/tutorials.dm. Nothing here acts on the world.
 *
 * The step text is the one place how-to text is allowed in player UI (kit rule
 * exception for the checklist). Keep it to one plain line.
 */

/datum/vc_tutorial
	/// Item key, a TUTORIAL_ITEM_* define. Written to the DB when the item completes.
	var/id
	/// Shown in the panel's item list.
	var/name
	/// Position in the panel, lowest first.
	var/order = 0
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

/**
 * A short note shown under the step for this viewer, or null.
 * Machine scans are cached per ship by SSvc_tutorials.
 */
/datum/vc_tutorial_step/proc/availability(mob/user)
	return null

/**
 * TRUE when this step should not count toward its item for this viewer, for example
 * a captain-only step seen by a crewmate.
 */
/datum/vc_tutorial_step/proc/excused(mob/user)
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
	order = 1
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
	text = "Use the Ship Management button to see your crew, invites and ship settings."

/datum/vc_tutorial_step/ship_manage/availability(mob/user)
	if(excused(user))
		return "Captain only."
	return null

/datum/vc_tutorial_step/ship_manage/excused(mob/user)
	return !(locate(/datum/action/innate/captain_management) in user?.actions)

/datum/vc_tutorial_step/ship_search
	key = TUTORIAL_STEP_SHIP_SEARCH
	name = "Search the lockers"
	text = "Open your ship's lockers and crates, or Alt-click a tile to see everything on it."

/// Shared by the helm steps: a hull with no helm can't do them.
/datum/vc_tutorial_step/proc/no_helm_note(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(ship && !SSvc_tutorials.ship_has_machine(ship, /obj/machinery/computer/helm))
		return "No helm aboard."
	return null

/datum/vc_tutorial_step/ship_course
	key = TUTORIAL_STEP_SHIP_COURSE
	name = "Set a course"
	text = "At the helm, pick a heading, or click the map to fly there on autopilot."

/datum/vc_tutorial_step/ship_course/availability(mob/user)
	return no_helm_note(user)

/datum/vc_tutorial_step/ship_dock
	key = TUTORIAL_STEP_SHIP_DOCK
	name = "Dock"
	text = "Fly onto a planet, outpost or ruin and press Dock at the helm."

/datum/vc_tutorial_step/ship_dock/availability(mob/user)
	return no_helm_note(user)

/datum/vc_tutorial_step/ship_undock
	key = TUTORIAL_STEP_SHIP_UNDOCK
	name = "Undock"
	text = "Press Undock at the helm to leave."

/datum/vc_tutorial_step/ship_undock/availability(mob/user)
	return no_helm_note(user)

/datum/vc_tutorial_step/ship_build
	key = TUTORIAL_STEP_SHIP_BUILD
	name = "See the construction console"
	text = "Research Shuttle Construction, build the console, and use its drone to change your hull."
	optional = TRUE

// ---------------------------------------------------------------------------
// First contract
// ---------------------------------------------------------------------------

/datum/vc_tutorial/contract
	id = TUTORIAL_ITEM_CONTRACT
	name = "First contract"
	order = 2
	steps = list(
		/datum/vc_tutorial_step/contract_take,
		/datum/vc_tutorial_step/contract_work,
		/datum/vc_tutorial_step/contract_turn_in,
	)

/datum/vc_tutorial_step/contract_take
	key = TUTORIAL_STEP_CONTRACT_TAKE
	name = "Take a contract"
	text = "Open the contract board on your ship and accept one. Traders at outposts offer contracts too."

/datum/vc_tutorial_step/contract_take/availability(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(ship && !SSvc_tutorials.ship_has_machine(ship, /obj/machinery/computer/mission_board))
		return "No board aboard. Traders offer contracts, or research Mission Logistics."
	return null

/datum/vc_tutorial_step/contract_work
	key = TUTORIAL_STEP_CONTRACT_WORK
	name = "Do the job"
	text = "Follow the contract. The helm marks where to go."

/datum/vc_tutorial_step/contract_turn_in
	key = TUTORIAL_STEP_CONTRACT_TURN_IN
	name = "Get paid"
	text = "Bring the goods to the contract pad and press Turn In on the board."

// ---------------------------------------------------------------------------
// R&D setup
// ---------------------------------------------------------------------------

/datum/vc_tutorial/research
	id = TUTORIAL_ITEM_RESEARCH
	name = "R&D setup"
	order = 3
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

/// A hull that already has a ship server is past needing the kit.
/datum/vc_tutorial_step/research_kit/state_satisfied(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return ship && SSvc_tutorials.ship_has_machine(ship, /obj/machinery/rnd/server/ship)

/datum/vc_tutorial_step/research_server
	key = TUTORIAL_STEP_RESEARCH_SERVER
	name = "Build the R&D server"
	text = "Set the server flatpack on the floor and use a multitool on it."

/datum/vc_tutorial_step/research_server/state_satisfied(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return ship && SSvc_tutorials.ship_has_machine(ship, /obj/machinery/rnd/server/ship)

/datum/vc_tutorial_step/research_disk
	key = TUTORIAL_STEP_RESEARCH_DISK
	name = "Add the ship disk"
	text = "Put the R&D server source code disk into the server."

/datum/vc_tutorial_step/research_disk/state_satisfied(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return !!ship?.get_research_web()

/datum/vc_tutorial_step/research_console
	key = TUTORIAL_STEP_RESEARCH_CONSOLE
	name = "Set up the R&D console"
	text = "Make a computer frame from the kit's iron, then add the console board, cable and glass."

/datum/vc_tutorial_step/research_console/state_satisfied(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return ship && SSvc_tutorials.ship_has_machine(ship, /obj/machinery/computer/rdconsole)

/datum/vc_tutorial_step/research_protolathe
	key = TUTORIAL_STEP_RESEARCH_PROTOLATHE
	name = "Set up the protolathe"
	text = "Set the protolathe flatpack on the floor and use a multitool on it."

/datum/vc_tutorial_step/research_protolathe/state_satisfied(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return ship && SSvc_tutorials.ship_has_machine(ship, /obj/machinery/rnd/production/protolathe)

/datum/vc_tutorial_step/research_multitool
	key = TUTORIAL_STEP_RESEARCH_MULTITOOL
	name = "Multitool the server"
	text = "Use a multitool on the server to copy its link."

/// A hull whose console and protolathe already run off its server got here some other way.
/datum/vc_tutorial_step/research_multitool/state_satisfied(mob/user)
	return tutorial_ship_rnd_linked(get_crew_ship(user))

/datum/vc_tutorial_step/research_link
	key = TUTORIAL_STEP_RESEARCH_LINK
	name = "Link all the devices"
	text = "Use that multitool on the R&D console and the protolathe."

/datum/vc_tutorial_step/research_link/state_satisfied(mob/user)
	return tutorial_ship_rnd_linked(get_crew_ship(user))

// ---------------------------------------------------------------------------
// Surveys
// ---------------------------------------------------------------------------

/datum/vc_tutorial/surveys
	id = TUTORIAL_ITEM_SURVEYS
	name = "Surveys"
	order = 4
	steps = list(
		/datum/vc_tutorial_step/surveys_node,
		/datum/vc_tutorial_step/surveys_build,
		/datum/vc_tutorial_step/surveys_survey,
		/datum/vc_tutorial_step/surveys_notes,
	)

/datum/vc_tutorial_step/surveys_node
	key = TUTORIAL_STEP_SURVEYS_NODE
	name = "Research the survey console"
	text = "At the R&D console, research Orbital Survey Console."

/datum/vc_tutorial_step/surveys_node/state_satisfied(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	var/datum/techweb/web = ship?.get_research_web()
	return !!web?.researched_nodes[TECHWEB_NODE_SURVEY_CONSOLE]

/datum/vc_tutorial_step/surveys_build
	key = TUTORIAL_STEP_SURVEYS_BUILD
	name = "Build a survey console"
	text = "Print its board at the circuit imprinter and build it like any computer."

/datum/vc_tutorial_step/surveys_build/state_satisfied(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return ship && SSvc_tutorials.ship_has_machine(ship, /obj/machinery/computer/camera_advanced/shuttle_docker/survey)

/datum/vc_tutorial_step/surveys_survey
	key = TUTORIAL_STEP_SURVEYS_SURVEY
	name = "Survey a planet"
	text = "Fly next to a planet and start a survey at the console."

/datum/vc_tutorial_step/surveys_notes
	key = TUTORIAL_STEP_SURVEYS_NOTES
	name = "Turn in the notes"
	text = "Print the notes at the survey console and use them on the R&D console."

// ---------------------------------------------------------------------------
// Planet ruin
// ---------------------------------------------------------------------------

/datum/vc_tutorial/ruin
	id = TUTORIAL_ITEM_RUIN
	name = "Planet ruin"
	order = 5
	steps = list(
		/datum/vc_tutorial_step/ruin_land,
		/datum/vc_tutorial_step/ruin_find,
		/datum/vc_tutorial_step/ruin_cache,
	)

/datum/vc_tutorial_step/ruin_land
	key = TUTORIAL_STEP_RUIN_LAND
	name = "Land on a planet"
	text = "Dock at a planet from the helm."

/datum/vc_tutorial_step/ruin_find
	key = TUTORIAL_STEP_RUIN_FIND
	name = "Find a ruin"
	text = "Explore until you find a building someone left behind."

/datum/vc_tutorial_step/ruin_cache
	key = TUTORIAL_STEP_RUIN_CACHE
	name = "Open the cache"
	text = "Find the abandoned cache and open it. No cache? Try another ruin."

// ---------------------------------------------------------------------------
// Outpost trade
// ---------------------------------------------------------------------------

/datum/vc_tutorial/trade
	id = TUTORIAL_ITEM_TRADE
	name = "Outpost trade"
	order = 6
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

/datum/vc_tutorial_step/trade_elevator
	key = TUTORIAL_STEP_TRADE_ELEVATOR
	name = "Ride the elevator"
	text = "From your berth, take the elevator up to the concourse."

/datum/vc_tutorial_step/trade_buy
	key = TUTORIAL_STEP_TRADE_BUY
	name = "Buy something"
	text = "Talk to a trader and buy from their stock."

/datum/vc_tutorial_step/trade_sell
	key = TUTORIAL_STEP_TRADE_SELL
	name = "Sell something"
	text = "Traders buy the items on their wanted list. Hold one and sell it."

// ---------------------------------------------------------------------------
// Ship power
// ---------------------------------------------------------------------------

/datum/vc_tutorial/power
	id = TUTORIAL_ITEM_POWER
	name = "Ship power"
	order = 7
	steps = list(
		/datum/vc_tutorial_step/power_smes,
		/datum/vc_tutorial_step/power_generator,
		/datum/vc_tutorial_step/power_apc,
	)

/datum/vc_tutorial_step/power_smes
	key = TUTORIAL_STEP_POWER_SMES
	name = "Check the batteries"
	text = "Find the SMES in engineering. It powers the ship."

/datum/vc_tutorial_step/power_generator
	key = TUTORIAL_STEP_POWER_GENERATOR
	name = "Start the generator"
	text = "Load plasma into the generator and turn it on to recharge the batteries."

/datum/vc_tutorial_step/power_generator/availability(mob/user)
	if(excused(user))
		return "No generator aboard. The general store sells one."
	return null

/datum/vc_tutorial_step/power_generator/excused(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return ship && !SSvc_tutorials.ship_has_machine(ship, /obj/machinery/power/port_gen)

/datum/vc_tutorial_step/power_apc
	key = TUTORIAL_STEP_POWER_APC
	name = "Find an APC"
	text = "Each room has a power panel on the wall. Use it to turn things off or back on."

// ---------------------------------------------------------------------------
// Cyberware
// ---------------------------------------------------------------------------

/datum/vc_tutorial/chrome
	id = TUTORIAL_ITEM_CHROME
	name = "Cyberware"
	order = 8
	steps = list(
		/datum/vc_tutorial_step/chrome_buy,
		/datum/vc_tutorial_step/chrome_install,
		/datum/vc_tutorial_step/chrome_execute,
	)

/datum/vc_tutorial_step/chrome_buy
	key = TUTORIAL_STEP_CHROME_BUY
	name = "Buy chrome"
	text = "The general store sells street chrome. The Chop Shop in the red zone sells the rest."

/datum/vc_tutorial_step/chrome_install
	key = TUTORIAL_STEP_CHROME_INSTALL
	name = "Get it installed"
	text = "Lie in the Chop Shop's Chrome Cradle, or have it put in by surgery."

/datum/vc_tutorial_step/chrome_execute
	key = TUTORIAL_STEP_CHROME_EXECUTE
	name = "Do an execution"
	text = "Get someone down, then finish them with Gorilla Arms, Mantis Blades or a Widowline."

// ---------------------------------------------------------------------------
// First surgery
// ---------------------------------------------------------------------------

/datum/vc_tutorial/surgery
	id = TUTORIAL_ITEM_SURGERY
	name = "First surgery"
	order = 9
	steps = list(
		/datum/vc_tutorial_step/surgery_start,
		/datum/vc_tutorial_step/surgery_finish,
		/datum/vc_tutorial_step/surgery_dissect,
	)

/datum/vc_tutorial_step/surgery_start
	key = TUTORIAL_STEP_SURGERY_START
	name = "Start an operation"
	text = "Lay a hurt crewmate down, cover them with a bedsheet or surgical drapes and pick Tend Wounds. The autolathe prints the tools."

/datum/vc_tutorial_step/surgery_finish
	key = TUTORIAL_STEP_SURGERY_FINISH
	name = "Finish it"
	text = "Work through each step with the right tool until the wound is closed."

/datum/vc_tutorial_step/surgery_dissect
	key = TUTORIAL_STEP_SURGERY_DISSECT
	name = "Dissect a body"
	text = "Lay a corpse or dead creature on a table, cover it with a bedsheet or surgical drapes and pick Dissection. What you learn goes into your ship's research."

// ---------------------------------------------------------------------------
// Zones (replaces the old orientation briefing)
// ---------------------------------------------------------------------------

/datum/vc_tutorial/zones
	id = TUTORIAL_ITEM_ZONES
	name = "Zones"
	order = 10
	steps = list(
		/datum/vc_tutorial_step/zones_yellow,
		/datum/vc_tutorial_step/zones_warfare,
		/datum/vc_tutorial_step/zones_red,
	)

/datum/vc_tutorial_step/zones_yellow
	key = TUTORIAL_STEP_ZONES_YELLOW
	name = "Enter the yellow zone"
	text = "Green space has no fighting between crews. In yellow, other crews can board and rob you."

/datum/vc_tutorial_step/zones_warfare
	key = TUTORIAL_STEP_ZONES_WARFARE
	name = "Research Shuttle Warfare Systems"
	text = "At the R&D console. It leads to shields, guns, missiles and an interdictor for your ship."

/datum/vc_tutorial_step/zones_warfare/state_satisfied(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return ship && ship.has_ship_combat_research()

/datum/vc_tutorial_step/zones_red
	key = TUTORIAL_STEP_ZONES_RED
	name = "Enter the red zone"
	text = "Anything goes in red. Ships fire on each other and players can kill you for nothing."
	optional = TRUE

// ---------------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------------

/datum/vc_tutorial/storage
	id = TUTORIAL_ITEM_STORAGE
	name = "Storage"
	order = 11
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

/datum/vc_tutorial_step/storage_locker
	key = TUTORIAL_STEP_STORAGE_LOCKER
	name = "Build a smart locker"
	text = "Print a Smart Locker board and build it in a machine frame."

/datum/vc_tutorial_step/storage_store
	key = TUTORIAL_STEP_STORAGE_STORE
	name = "Fill a smart locker"
	text = "Put an item in a smart locker, or drag a bag onto it to empty the bag."

// ---------------------------------------------------------------------------
// Repair drones
// ---------------------------------------------------------------------------

/datum/vc_tutorial/repair_drones
	id = TUTORIAL_ITEM_REPAIR_DRONES
	name = "Repair drones"
	order = 12
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

/datum/vc_tutorial_step/repair_drones_research/state_satisfied(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	var/datum/techweb/web = ship?.get_research_web()
	return web && (TECHWEB_NODE_SHIP_REPAIR_SWARM in web.researched_nodes)

/datum/vc_tutorial_step/repair_drones_assemble
	key = TUTORIAL_STEP_REPAIR_DRONES_ASSEMBLE
	name = "Assemble a drone"
	text = "Print the four drone parts at an exosuit fabricator and fit them to the chassis."

/datum/vc_tutorial_step/repair_drones_link
	key = TUTORIAL_STEP_REPAIR_DRONES_LINK
	name = "Link the drone"
	text = "Install the repair swarm disk, then use a multitool on the construction console and the drone."

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
	order = 13
	steps = list(
		/datum/vc_tutorial_step/ship_save_dock,
		/datum/vc_tutorial_step/ship_save_save,
		/datum/vc_tutorial_step/ship_save_load,
	)

/datum/vc_tutorial_step/ship_save_dock
	key = TUTORIAL_STEP_SHIP_SAVE_DOCK
	name = "Dock in a ship bay"
	text = "Dock at a crew outpost that has ship bays."

/// Only the captain can save or load a ship.
/datum/vc_tutorial_step/proc/captain_only_note(mob/user)
	if(excused(user))
		return "Captain only."
	return null

/datum/vc_tutorial_step/ship_save_save
	key = TUTORIAL_STEP_SHIP_SAVE_SAVE
	name = "Save the ship"
	text = "At the bay's shipyard console, open Saved ships and save your ship to a slot."

/datum/vc_tutorial_step/ship_save_save/availability(mob/user)
	return captain_only_note(user)

/datum/vc_tutorial_step/ship_save_save/excused(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return ship && !ship.is_ship_captain(user)

/datum/vc_tutorial_step/ship_save_load
	key = TUTORIAL_STEP_SHIP_SAVE_LOAD
	name = "Load a saved ship"
	text = "Pick a saved ship when you join, or build it at a shipyard console once the old hull is gone."
	optional = TRUE

// ---------------------------------------------------------------------------
// Vestige pact
// ---------------------------------------------------------------------------

/datum/vc_tutorial/vestige
	id = TUTORIAL_ITEM_VESTIGE
	name = "Vestige pact"
	order = 14
	steps = list(
		/datum/vc_tutorial_step/vestige_find,
		/datum/vc_tutorial_step/vestige_pact,
		/datum/vc_tutorial_step/vestige_trial,
		/datum/vc_tutorial_step/vestige_claim,
	)

/datum/vc_tutorial_step/vestige_find
	key = TUTORIAL_STEP_VESTIGE_FIND
	name = "Find a vestige"
	text = "Vestiges appear during the round as red signals on sensors. Fly to one and go inside."

/datum/vc_tutorial_step/vestige_pact
	key = TUTORIAL_STEP_VESTIGE_PACT
	name = "Make a pact"
	text = "Find the patron inside and choose Pact. It sets you one trial."

/datum/vc_tutorial_step/vestige_trial
	key = TUTORIAL_STEP_VESTIGE_TRIAL
	name = "Complete the trial"
	text = "Do what the patron asked. The reminder on your screen shows your progress."

/datum/vc_tutorial_step/vestige_claim
	key = TUTORIAL_STEP_VESTIGE_CLAIM
	name = "Claim your boon"
	text = "Use the Claim Your Boon button and pick one."
