// ========== DELTA MODULES ==========
//
// Slot geometry (BYOND coords on the 28x17 hull, origin bottom-left):
//
//   delta_cargo   x20-26 y2-6   35 tiles  marker (20,2)   OPEN
//     The starboard hold interior. Hull keeps the x19 service column (EVA
//     airlock, APC, air alarm, fire alarm) and the in-pocket vent (22,4) /
//     scrubber (23,4), modules leave those two tiles walkable and place NO
//     infrastructure of their own. Keep (20,4) open (west entry lane) and
//     the whole x26 face at y3-5 open and unwalled (blast-hatch approach;
//     the x27 hatch, fans and buttons are hull). (21,1)/(25,1) south and
//     (21,7)/(25,7) north are shuttered windows, no wallmounts facing them;
//     (26,1) and (26,7) are the free east wall mounts. (19,2), the hull's
//     APC/hatch-control nook, is a dead end entered only from (20,2) and
//     always carries the hold floor so the two read as one room.
//     PALETTE: the hold deck is per-theme, and (19,2) is pinned to whatever
//     the theme lays, iron/dark on salvage, cult and the lightship,
//     plastitanium on the syndicate refit. The hull tile and all three cargo
//     modules must move together or the (19,2) seam reopens.
//     (26,3)(26,4)(26,5) keep iron/dark and their hazard chevrons in EVERY
//     theme, that column is the blast-hatch approach, not the lane.
//
//   delta_cafe    x20-26 y12-16  35 tiles  marker (20,12)  OPEN
//     The port wing interior. Mirror of the hold: hull keeps the x19 service
//     column and the in-pocket vent (22,14) / scrubber (23,14). Keep (20,14)
//     open (west entry lane). RESERVE (26,14): the wing-tip breach tile is
//     hull-owned and differs per theme (salvage keeps the scar.
//     Airless plating, displaced girder, wreckage; the lightship hull has
//     it patched, lit and plaqued), so every cafe module leaves it as
//     /turf/template_noop. Shuttered windows at (21,11)/(25,11) south and
//     (21,17)/(25,17) north.
//     PALETTE: x20-24 is the finished room and takes the theme floor; x25-26
//     is the breached wing tip, iron/dark on salvage, and repaired in its
//     own idiom by each of the other three themes.
//     (20,16) must match the hull's cafe APC nook at (19,16), that tile is
//     open floor, not a doorway, so it is a real seam.
//
//   delta_med     x9-14 y2-4    18 tiles  marker (9,2)    OPEN
//     The medbay interior. Hull keeps the x8 strip at y3-5, medvendor, air
//     alarm and fire alarm all on (8,3), plus (9,5) just north of the
//     pocket, which carries the medbay APC and the supply vent, and the
//     in-pocket vent (12,3) / scrubber (13,3). The hull's four medbay floor
//     tiles (8,3)(8,4)(8,5)(9,5) carry the theme's clinic floor so they match
//     the med modules; theme colour stops at the medbay walls.
//     Keep (12,4)/(13,4) open (hallway doors) and (14,4) open (east EVA).
//     The hull's defibrillator did not survive the carve, so EVERY med
//     module ships one /obj/machinery/defibrillator_mount/loaded.
//     PALETTE: the clinic floor is per-theme, and the four hull tiles plus
//     all three med modules move together, iron/white on salvage and the
//     lightship, iron/dark on the syndicate and cult refits. Repainting one
//     without the others reopens those hull tiles and desyncs chem and cryo.
//
//   delta_dorms   x9-14 y14-16  18 tiles  marker (9,14)   RESERVE (14,16)
//     The crew deck interior. (14,16) is /turf/template_noop in every
//     module: the hull keeps a cryopod + cryopod console + the dorms APC
//     there, so the bare hull is always joinable. That reserve pod is the
//     ship's ONE spawn point: dorms modules ship ZERO cryopods (one pod
//     per ship - join code only needs spawn_points to be non-empty).
//     (14,15) is the nook's ONLY approach and must stay walkable -
//     (15,16) is wall, (14,17) is a shuttered window. Put anything dense
//     on (14,15) and the guaranteed spawn is sealed in.
//     Hull vent/scrubber sit just outside the pocket at (9,13). The whole
//     y14 row is a real corridor ((7,14) west door -> south doors ->
//     (15,14) east EVA): modules keep it entirely furniture-free, leaving
//     11 usable content tiles.
//     PALETTE: (9,14) must match the hull at (8,14), iron on salvage,
//     plastitanium on the syndicate refit, engraved cult deck on the cult
//     refit, iron/white on the lightship.
//
// The hull owns ALL slot infrastructure (power, atmos, alarms). Modules
// ship zero pipe/cable/APC/alarm content; the only sanctioned exception is
// a fully self-contained closed loop (the Cryo Ward's cryotube + freezer).
//
// THEME PALETTES (read the hull before authoring a variant; stay inside it):
//   salvage   ship_delta_a  iron / iron/dark, tile/neutral + tile/blue decals,
//                           grey titanium hull
//   syndicate ship_delta_b  plastitanium deck, walls AND hull skin (the whole
//                           exterior is Gorlex black), iron/dark utility
//                           spaces, red livery and hazard trim
//   cult      ship_delta_c  engraved cult deck and runed-metal walls hull-wide
//                           - the /ship subtypes in voidcrew/turfs/cult_ship.dm,
//                           NOT the stock cult turfs, which replay a conversion
//                           animation on every dock - plus iron/dark utility
//                           spaces and candle/pylon light
//   lightship ship_delta_d  iron/white (+/textured), tile/dark_blue,
//                           siding/red and siding/dark_blue livery, no grime,
//                           full-size light fixtures rather than light/small
// WALLS: interior partitions must be a NODIAGONAL (or never-diagonal) wall
// type - every partition hosts or can host a wallmount, and diagonal-capable
// walls draw 45-degree corner cuts that leave buttons/APCs/alarms floating.
// Hull skin may be re-plated by a theme only 1:1 by smoothing class (plain
// stays plain for the rounded exterior corners, nodiagonal stays nodiagonal)
// via the retheme pipeline's skin_walls map; the tile always stays closed.
// CULT DECK CAVEAT: the engraving is drawn by a runtime /obj/effect/cult_turf
// at CULT_OVERLAY_LAYER (5) and /obj/effect/turf_decal sits at
// TURF_DECAL_LAYER (4), so turf decals painted on engraved deck are invisible
// in game while still showing in renders and baked previews. Keep trim on the
// iron/dark working decks. Cleanable decals are fine (blood is layer 15).
// Pylons are mapped `anchored = 0`: an anchored pylon runs an SSfastprocess
// loop that rewrites nearby turfs into the STOCK cult floor, reaching through
// viewports into the module pockets.
// Grime ladder across a module's themed set: salvage heavy, cult heavy,
// syndicate about half, lightship none.

/datum/ship_upgrade_module/delta
	for_ship = /datum/map_template/shuttle/voidcrew/delta
	// Modules are shared across all four themes; themed reskins are per-dmm
	// (the loader falls back from <base>_<theme>.dmm to map_file)
	for_theme = list("salvage", "syndicate", "cult", "lightship")

// -- delta_cargo: the starboard hold.

/datum/ship_upgrade_module/delta/cargo_salvage
	id = "delta_cargo_salvage"
	name = "Salvage Hold"
	desc = "A working salvager's hold: crate stack, cutting and fulton gear \
		on the rack, a charger bench, and the manifest desk where the \
		quartermaster keeps score."
	slot = "delta_cargo"
	map_file = "delta/delta_cargo_salvage.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/delta/cargo_mining
	id = "delta_cargo_mining"
	name = "Mining Bay"
	desc = "Ore redemption machine, mining lockers and an ore box - the \
		fittings this hull's miner berths never had. Adds two Shaft Miners \
		to the crew."
	slot = "delta_cargo"
	map_file = "delta/delta_cargo_mining.dmm"
	part_cost = list(PART_CLASS_TRADE = 6)
	job_slots_add = list(
		list(
			name = "Shaft Miner",
			outfit = /datum/outfit/job/miner,
			category = JOB_CAT_CARGO,
			slots = 2,
		),
	)

/datum/ship_upgrade_module/delta/cargo_gundeck
	id = "delta_cargo_gundeck"
	name = "Gun Deck"
	desc = "Security lockers, an energy gun rack with a recharger, and a \
		desk for whoever minds the old hull turrets. Adds a Security \
		Officer to the crew."
	slot = "delta_cargo"
	map_file = "delta/delta_cargo_gundeck.dmm"
	part_cost = list(PART_CLASS_COMBAT = 10)
	job_slots_add = list(
		list(
			name = "Security Officer",
			outfit = /datum/outfit/job/security,
			category = JOB_CAT_SECURITY,
			slots = 1,
		),
	)

// -- delta_cafe: the port wing.

/datum/ship_upgrade_module/delta/cafe_diner
	id = "delta_cafe_diner"
	name = "Galley Diner"
	desc = "The rust-red checkered diner: kitchen and bar at one end, and \
		the wing's unrepaired wreckage at the other. Adds a Cook to the \
		crew."
	slot = "delta_cafe"
	map_file = "delta/delta_cafe_diner.dmm"
	is_default = TRUE
	job_slots_add = list(
		list(
			name = "Cook",
			outfit = /datum/outfit/job/cook,
			category = JOB_CAT_SERVICE,
			slots = 1,
		),
	)

/datum/ship_upgrade_module/delta/cafe_greenhouse
	id = "delta_cafe_greenhouse"
	name = "Greenhouse Cafe"
	desc = "Hydroponics trays on real soil under grow lights, a seed vendor \
		and a biogenerator. Adds a Botanist to the crew."
	slot = "delta_cafe"
	map_file = "delta/delta_cafe_greenhouse.dmm"
	part_cost = list(PART_CLASS_TRADE = 6)
	job_slots_add = list(
		list(
			name = "Botanist",
			outfit = /datum/outfit/job/botanist,
			category = JOB_CAT_SERVICE,
			slots = 1,
		),
	)

/datum/ship_upgrade_module/delta/cafe_shop
	id = "delta_cafe_shop"
	name = "Machine Shop"
	desc = "A workbench row with a techfab, a circuit imprinter and parts \
		racks. Adds a Scientist to the crew."
	slot = "delta_cafe"
	map_file = "delta/delta_cafe_shop.dmm"
	part_cost = list(PART_CLASS_SCIENCE = 6)
	job_slots_add = list(
		list(
			name = "Scientist",
			outfit = /datum/outfit/job/scientist,
			category = JOB_CAT_SCIENCE,
			slots = 1,
		),
	)

/datum/ship_upgrade_module/delta/cafe_bitrunning
	id = "delta_cafe_bitrunning"
	name = "Bitrunning Den"
	desc = "Three netpods wired to a quantum server, a console to pick the \
		domain, and a byteforge that materializes the crate at the end of a \
		run. Adds a Bitrunner to the crew."
	slot = "delta_cafe"
	map_file = "delta/delta_cafe_bitrunning.dmm"
	part_cost = list(PART_CLASS_SCIENCE = 10)
	job_slots_add = list(
		list(
			name = "Bitrunner",
			outfit = /datum/outfit/job/bitrunner,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
	)

// -- delta_med: the medbay.

/datum/ship_upgrade_module/delta/med_clinic
	id = "delta_med_clinic"
	name = "Field Clinic"
	desc = "Stasis bed, operating table, defibrillator and an IV drip - a \
		clinic sized for a small crew's bad days."
	slot = "delta_med"
	map_file = "delta/delta_med_clinic.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/delta/med_chem
	id = "delta_med_chem"
	name = "Chemistry Annex"
	desc = "Chem dispenser, ChemMaster and heater behind a counter, with a \
		smartfridge for the output. Adds a Chemist to the crew."
	slot = "delta_med"
	map_file = "delta/delta_med_chem.dmm"
	part_cost = list(PART_CLASS_SCIENCE = 6)
	job_slots_add = list(
		list(
			name = "Chemist",
			outfit = /datum/outfit/job/chemist,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
	)

/datum/ship_upgrade_module/delta/med_cryo
	id = "delta_med_cryo"
	name = "Cryo Ward"
	desc = "A cryotube on its own sealed loop, a recovery bed and a sleeper. \
		Adds a Paramedic to the crew."
	slot = "delta_med"
	map_file = "delta/delta_med_cryo.dmm"
	part_cost = list(PART_CLASS_MISC = 6)
	job_slots_add = list(
		list(
			name = "Paramedic",
			outfit = /datum/outfit/job/paramedic,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
	)

/datum/ship_upgrade_module/delta/med_clone
	id = "delta_med_clone"
	name = "Cloning Bay"
	desc = "A pre-ban cloning prototype wedged into the medbay: scanner, growth \
		tank and control console, with a morgue tray and a change of clothes for \
		whatever comes out. Scan the crew while they are still walking around - \
		the tank grows one body at a time, slowly, and the copy is not always a \
		clean one."
	slot = "delta_med"
	map_file = "delta/delta_med_clone.dmm"
	// Deliberately the most expensive module in the fleet, in two part classes.
	// Nothing on the techweb prints these boards, so this is not buying past a
	// research node - it is buying a machine a crew otherwise only gets by
	// finding the cloning-facility space ruin, and it is a respawn route on top
	// of that. Owner: this number is the balance dial, tune it here.
	part_cost = list(PART_CLASS_SCIENCE = 10, PART_CLASS_MISC = 6)

// -- delta_dorms: the crew deck.

/datum/ship_upgrade_module/delta/dorms_cabins
	id = "delta_dorms_cabins"
	name = "Crew Cabins"
	desc = "A snug cabin, lockers and a small washroom."
	slot = "delta_dorms"
	map_file = "delta/delta_dorms_cabins.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/delta/dorms_bunkhouse
	id = "delta_dorms_bunkhouse"
	name = "Bunkhouse"
	desc = "Bunk rows and a locker wall - room for more hands. Adds two \
		Assistants to the crew."
	slot = "delta_dorms"
	map_file = "delta/delta_dorms_bunkhouse.dmm"
	part_cost = list(PART_CLASS_MISC = 6)
	job_slots_add = list(
		list(
			name = "Assistant",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)

/datum/ship_upgrade_module/delta/dorms_den
	id = "delta_dorms_den"
	name = "The Den"
	desc = "The crew's living room: a proper couch, a game table, a jukebox \
		and a shelf of someone's things, with a sleeping nook at the back."
	slot = "delta_dorms"
	map_file = "delta/delta_dorms_den.dmm"
	part_cost = list(PART_CLASS_MISC = 3)

// ========== DELTA THEMES ==========

/datum/ship_theme/delta
	for_ship = /datum/map_template/shuttle/voidcrew/delta

/datum/ship_theme/delta/salvage
	id = "salvage"
	name = "Salvage Claim"
	desc = "The frigate as the salvage crew that claimed her keeps her: \
		re-lit, patched where it matters, and dusty where it doesn't. Nobody \
		has scrubbed the old crew's story off the deck, and nobody is in a \
		hurry to."
	is_default = TRUE
	template_suffix = "delta_a"
	upgrade_slot_ids = list(
		"delta_cargo",
		"delta_cafe",
		"delta_med",
		"delta_dorms",
	)
	job_slots = list(
		list(
			name = "Captain",
			officer = TRUE,
			outfit = /datum/outfit/job/captain,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Quartermaster",
			outfit = /datum/outfit/job/quartermaster,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
		list(
			name = "Medical Doctor",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Station Engineer",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Assistant",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
	)

/datum/ship_theme/delta/syndicate
	id = "syndicate"
	name = "Gorlex Prize"
	desc = "Taken off Nanotrasen with her registry still on the hull, and \
		refitted by a Gorlex cell that needed a frigate more than it needed \
		the paperwork. Plastitanium welded over the old plating, corporate \
		signage painted out, and a magazine where the cargo office used to \
		be. She is maintained properly, which is more than the last owners \
		managed."
	part_cost = list(PART_CLASS_COMBAT = 9)
	template_suffix = "delta_b"
	upgrade_slot_ids = list(
		"delta_cargo",
		"delta_cafe",
		"delta_med",
		"delta_dorms",
	)
	job_slots = list(
		list(
			name = "Cell Leader",
			officer = TRUE,
			outfit = /datum/outfit/job/captain,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Quartermaster",
			outfit = /datum/outfit/job/quartermaster,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
		list(
			name = "Corpsman",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Machinist",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Marauder",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
	)

/datum/ship_theme/delta/cult
	id = "cult"
	name = "The Congregation"
	desc = "A blood cult bought the wreck at scrap value and never sold her \
		on. They cut runed metal into the partitions, engraved the deck the \
		length of the spine, and put a shrine at the end of the mess. The \
		rest of it is an ordinary working ship - somebody still has to mind \
		the engine and somebody still has to cook."
	part_cost = list(PART_CLASS_SCIENCE = 9)
	template_suffix = "delta_c"
	upgrade_slot_ids = list(
		"delta_cargo",
		"delta_cafe",
		"delta_med",
		"delta_dorms",
	)
	job_slots = list(
		list(
			name = "Shipmaster",
			officer = TRUE,
			outfit = /datum/outfit/job/captain,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Steward",
			outfit = /datum/outfit/job/quartermaster,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
		list(
			name = "Physician",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Engineer",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Congregant",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
	)

/datum/ship_theme/delta/lightship
	id = "lightship"
	name = "The Lightship"
	desc = "A volunteer rescue crew stripped the dust out, repainted the \
		hull markings, and lit every deck for the first time in years. She \
		answers maydays now. The kettle in the mess is always warm, and the \
		bell by the airlock rings every time a rescue comes home."
	part_cost = list(PART_CLASS_MISC = 9)
	template_suffix = "delta_d"
	upgrade_slot_ids = list(
		"delta_cargo",
		"delta_cafe",
		"delta_med",
		"delta_dorms",
	)
	job_slots = list(
		list(
			name = "Stationmaster",
			officer = TRUE,
			outfit = /datum/outfit/job/captain,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Storekeeper",
			outfit = /datum/outfit/job/quartermaster,
			category = JOB_CAT_CARGO,
			slots = 1,
		),
		list(
			name = "Lifeboat Medic",
			outfit = /datum/outfit/job/doctor,
			category = JOB_CAT_MEDICAL,
			slots = 1,
		),
		list(
			name = "Keeper",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Volunteer",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
	)
