/**
 * # Hardcore drop: the crate, the job, and the clothes on your back
 *
 * Everything a castaway owns. There is no second delivery, no cargo console and no
 * paycheque, so this list is the entire budget for the rest of their round and it is
 * chosen against one question: can one person, alone, turn this into somewhere to live
 * and a reason for somebody else to come and find them?
 *
 * What it deliberately does NOT contain is a way off the planet. See
 * voidcrew/GUIDES/HARDCORE_SPAWN_DESIGN.md, "The way home" - there is no buildable hull
 * anywhere in this codebase, and handing out a free one through the crate would make the
 * hardcore start a cheaper route to a ship than the shipyard. Rescue is the Wideband
 * radio and another crew choosing to answer it.
 */

/// Iron, glass and rods to build a shelter's worth of wall and floor with.
#define HARDCORE_SHEET_COUNT 50
/// Plasma sheets for the generator. 20 sheets is 60 minutes of PACMAN runtime at
/// time_per_sheet = 180 (code/modules/power/port_gen.dm) - enough to matter, not enough
/// to stop mining being the thing that keeps the lights on.
#define HARDCORE_PLASMA_COUNT 20

/**
 * The crate that rides down in the pod.
 *
 * /crate/engineering rather than a secure crate on purpose: a lock a castaway is the only
 * person alive to open is a lock that only ever costs them the time to cut it, and if
 * somebody else does reach this planet, the crate being openable is the interesting
 * outcome.
 */
/obj/structure/closet/crate/engineering/hardcore_drop
	name = "castaway survival crate"
	desc = "A drop-rated supply crate. The manifest sticker on the lid lists a shelter capsule, tools, \
		materials, a generator and rations. Underneath, someone has written 'good luck' in marker."

/obj/structure/closet/crate/engineering/hardcore_drop/PopulateContents()
	. = ..()

	// --- Shelter ---
	// The single most valuable thing in here. Deploys a pressurized, powered, gravity-
	// bearing prefab with a medbed and a GPS console (/datum/map_template/shelter/alpha,
	// code/modules/mining/shelters.dm) onto open ground in one click. It is what turns
	// "you are going to die of exposure" into "you have a base and a problem".
	new /obj/item/survivalcapsule(src)

	// --- Tools ---
	// The utility belt is the only container in the tree that carries all six tools AND a
	// multitool AND cable coil, and it is wearable, which matters when your pockets are
	// the only storage you have (code/game/objects/items/storage/belt.dm).
	new /obj/item/storage/belt/utility/full(src)
	// An RCD is a lot of building for one item, and that is the point: 160 matter is a
	// shelter's worth of walls and airlocks without needing a machine shop first.
	new /obj/item/construction/rcd/loaded(src)
	new /obj/item/rcd_ammo/large(src)
	new /obj/item/pickaxe/drill(src)
	new /obj/item/shovel(src)
	new /obj/item/extinguisher(src)
	// Ore is the only renewable resource on a planet, so the scanner is what makes the
	// difference between surviving and building.
	new /obj/item/mining_scanner(src)

	// --- Materials ---
	new /obj/item/stack/sheet/iron(src, HARDCORE_SHEET_COUNT)
	new /obj/item/stack/sheet/glass(src, HARDCORE_SHEET_COUNT)
	new /obj/item/stack/rods(src, HARDCORE_SHEET_COUNT)
	new /obj/item/stack/cable_coil(src, MAXCOIL)

	// --- Power ---
	// Pre-loaded so the first night does not depend on finding plasma. It has to be
	// wrenched down and cabled in before it does anything, which is the intended lesson.
	new /obj/machinery/power/port_gen/pacman/pre_loaded(src)
	new /obj/item/stack/sheet/mineral/plasma(src, HARDCORE_PLASMA_COUNT)
	new /obj/item/electronics/apc(src)
	new /obj/item/stock_parts/power_store/cell/high(src)

	// --- Food ---
	// Cans are the stopgap; the hydroponics board is the actual answer, and it needs the
	// generator running, which needs the plasma, which runs out. That chain is the
	// survival loop this crate is built around.
	for(var/i in 1 to 4)
		new /obj/item/food/canned/beans(src)
	new /obj/item/circuitboard/machine/hydroponics(src)
	new /obj/item/seeds/wheat(src)
	new /obj/item/seeds/potato(src)
	new /obj/item/reagent_containers/cup/watering_can(src)

	// --- Medical ---
	// No surgery, no cloner, no second chance: brute and burn kits are the whole medbay.
	new /obj/item/storage/medkit/regular(src)
	new /obj/item/storage/medkit/brute(src)
	new /obj/item/storage/medkit/fire(src)

	// --- Rescue ---
	// A spare headset, because the one you are wearing is the only reason anyone will
	// ever know you exist and losing it ends the round quietly. Wideband is granted to
	// every headset by a voidcrew edit in the base type (see
	// /obj/item/radio/headset/recalculateChannels), so no special path is needed.
	new /obj/item/radio/headset(src)
	// A GPS gives rescuers coordinates to fly to instead of a planet to search.
	new /obj/item/gps/mining(src)
	// Inert until somebody with a transporter pad pairs it - which is exactly the point:
	// it is the thing you offer a crew that answers your call.
	new /obj/item/transporter_transponder(src)

	new /obj/item/paper/fluff/hardcore_drop_manifest(src)

/obj/item/paper/fluff/hardcore_drop_manifest
	name = "packing slip - INDEPENDENT COLONIAL DROP"
	default_raw_text = "<b>INDEPENDENT COLONIAL DROP - PACKING SLIP</b><br><br>\
		You paid for the pod and one crate. You did not pay for a pickup, and we do not run one.<br><br>\
		<b>Recommended order of operations:</b><br>\
		1. Deploy the shelter capsule on open, level ground. Do it before dark.<br>\
		2. Wrench the generator down inside the shelter and run cable to an APC frame.<br>\
		3. Get the hydroponics tray built and planted. The cans will not last.<br>\
		4. Keep the headset on you. <b>Wideband (:w) reaches every ship in the galaxy.</b><br>\
		   It is the only channel that does. Somebody is listening. Give them coordinates \
		   off the GPS and a reason to come.<br><br>\
		The transponder in this crate is worthless to you and valuable to whoever answers. \
		That is deliberate.<br><br>\
		<i>Good luck.</i>"

/**
 * The role a castaway holds.
 *
 * Not on the preferences menu and not on any ship's slot table: it is handed out by
 * hardcore_drop_land() and nowhere else. /datum/job/map_check() strips
 * JOB_NEW_PLAYER_JOINABLE from anything outside the roundstart ship job pool anyway
 * (voidcrew/edits/jobs.dm), but leaving the flag off makes the intent explicit rather
 * than incidental.
 *
 * JOB_ANNOUNCE_ARRIVAL is deliberately absent - the arrivals announcement goes out over a
 * ship's comms, and there is no ship. JOB_CREW_MANIFEST likewise: the manifest injection
 * is done by hand in hardcore_drop_land() so a castaway shows up in the crew records
 * (and in admin tooling) without pretending to belong to a hull.
 */
/datum/job/castaway
	title = "Castaway"
	description = "You came down in a pod with one crate and no ship. Build something. Get someone's attention."
	faction = FACTION_STATION
	total_positions = -1
	spawn_positions = 0
	supervisors = "nobody at all"
	exp_granted_type = EXP_TYPE_CREW
	outfit = /datum/outfit/job/castaway
	plasmaman_outfit = /datum/outfit/plasmaman
	paycheck = PAYCHECK_LOWER
	paycheck_department = ACCOUNT_CIV
	display_order = JOB_DISPLAY_ORDER_ASSISTANT
	department_for_prefs = /datum/job_department/assistant
	departments_list = list(/datum/job_department/assistant)
	job_flags = JOB_EQUIP_RANK | JOB_CREW_MEMBER | JOB_ASSIGN_QUIRKS
	config_tag = "CASTAWAY"

/**
 * What you are wearing when the hatch opens.
 *
 * /datum/outfit/job's defaults already carry the two things that matter - a headset (and
 * therefore Wideband) and a survival box - so this only swaps the grey jumpsuit for
 * something that reads as expedition kit and adds the field gear that belongs on a body
 * rather than in a crate.
 */
/datum/outfit/job/castaway
	name = "Castaway"
	jobtype = /datum/job/castaway

	uniform = /obj/item/clothing/under/rank/cargo/miner/lavaland
	suit = /obj/item/clothing/suit/hooded/explorer
	shoes = /obj/item/clothing/shoes/workboots/mining
	gloves = /obj/item/clothing/gloves/color/black
	backpack = /obj/item/storage/backpack/explorer
	satchel = /obj/item/storage/backpack/satchel/explorer
	duffelbag = /obj/item/storage/backpack/duffelbag/explorer
	messenger = /obj/item/storage/backpack/messenger/explorer
	// The mining box over the plain survival one: it carries an explorer mask and a
	// crowbar, and a crowbar is how you get out of a pod that did not open.
	box = /obj/item/storage/box/survival/mining
	l_pocket = /obj/item/flashlight
	r_pocket = /obj/item/knife/combat/survival

#undef HARDCORE_SHEET_COUNT
#undef HARDCORE_PLASMA_COUNT
