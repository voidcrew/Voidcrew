// Ship Combat Cargo Supply Packs
// Purchasable missile component crates and combat equipment

/datum/supply_pack/ship_combat
	group = "Ship Combat"
	crate_type = /obj/structure/closet/crate/secure/gear

// ========== MISSILE COMPONENT PACKS ==========

/datum/supply_pack/ship_combat/missile_frames
	name = "Missile Frames Crate"
	desc = "A crate containing four missile frames. \
		Requires wiring, tracking circuit, and a warhead to arm."
	cost = CARGO_CRATE_VALUE * 4
	contains = list(/obj/structure/ship_missile = 4)
	crate_name = "missile frames crate"

/datum/supply_pack/ship_combat/tracking_circuits
	name = "Missile Tracking Circuits Crate"
	desc = "A crate containing six missile tracking circuits. \
		Required for missile guidance systems."
	cost = CARGO_CRATE_VALUE * 3
	contains = list(/obj/item/electronics/ship_missile_tracking = 6)
	crate_name = "tracking circuits crate"

/datum/supply_pack/ship_combat/warhead_standard
	name = "Standard Warheads Crate"
	desc = "A crate containing four standard missile warheads. \
		Moderate damage, good for general combat."
	cost = CARGO_CRATE_VALUE * 8
	contains = list(/obj/item/bombcore/missile = 4)
	crate_name = "standard warheads crate"

/datum/supply_pack/ship_combat/warhead_light
	name = "Light Warheads Crate"
	desc = "A crate containing six light missile warheads. \
		Lower damage but cheaper."
	cost = CARGO_CRATE_VALUE * 5
	contains = list(/obj/item/bombcore/missile/light = 6)
	crate_name = "light warheads crate"

/datum/supply_pack/ship_combat/warhead_heavy
	name = "Heavy Warheads Crate"
	desc = "A crate containing two heavy missile warheads. \
		Devastating damage but expensive."
	cost = CARGO_CRATE_VALUE * 12
	contains = list(/obj/item/bombcore/missile/heavy = 2)
	crate_name = "heavy warheads crate"

// Chemical missiles now use standard chemical grenades - no cargo pack needed
// Players order grenade casings from Science/Medical cargo and build their own

/datum/supply_pack/ship_combat/missiles_kit
	name = "Missile Assembly Kit"
	desc = "A starter kit for missile assembly: contains four frames, \
		four tracking circuits, four standard warheads, and cable coil."
	cost = CARGO_CRATE_VALUE * 12
	contains = list(
		/obj/structure/ship_missile = 4,
		/obj/item/electronics/ship_missile_tracking = 4,
		/obj/item/bombcore/missile = 4,
		/obj/item/stack/cable_coil = 1,
	)
	crate_name = "missile assembly kit"

// ========== EQUIPMENT PACKS ==========

/datum/supply_pack/ship_combat/launcher_kit
	name = "Missile Launcher Kit"
	desc = "A starter kit for ship combat: contains a missile launcher \
		circuit board, two frames, tracking circuits, and two standard warheads."
	cost = CARGO_CRATE_VALUE * 8
	contains = list(
		/obj/item/circuitboard/machine/ship_combat/missile_launcher = 1,
		/obj/structure/ship_missile = 2,
		/obj/item/electronics/ship_missile_tracking = 2,
		/obj/item/bombcore/missile = 2,
		/obj/item/stack/cable_coil = 1,
	)
	crate_name = "missile launcher kit"

/datum/supply_pack/ship_combat/combat_starter
	name = "Ship Combat Starter Pack"
	desc = "Everything you need to get started with ship combat: \
		a combat console board, launcher board, frames, tracking circuits, warheads, and wiring."
	cost = CARGO_CRATE_VALUE * 15
	contains = list(
		/obj/item/circuitboard/computer/ship_combat_console = 1,
		/obj/item/circuitboard/machine/ship_combat/missile_launcher = 1,
		/obj/structure/ship_missile = 4,
		/obj/item/electronics/ship_missile_tracking = 4,
		/obj/item/bombcore/missile = 2,
		/obj/item/bombcore/missile/light = 2,
		/obj/item/stack/cable_coil = 1,
	)
	crate_name = "ship combat starter pack"
