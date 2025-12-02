// Ship Combat Cargo Supply Packs
// Purchasable missile crates and combat equipment

/datum/supply_pack/ship_combat
	group = "Ship Combat"
	crate_type = /obj/structure/closet/crate/secure/gear

// ========== MISSILE PACKS ==========

/datum/supply_pack/ship_combat/missiles_standard
	name = "Standard Missiles Crate"
	desc = "A crate containing four standard ship-to-ship missiles. \
		Moderate damage, good for general combat."
	cost = CARGO_CRATE_VALUE * 10
	contains = list(/obj/item/ship_combat_missile = 4)
	crate_name = "standard missiles crate"

/datum/supply_pack/ship_combat/missiles_light
	name = "Light Missiles Crate"
	desc = "A crate containing six light ship-to-ship missiles. \
		Lower damage but cheaper and easier to handle."
	cost = CARGO_CRATE_VALUE * 6
	contains = list(/obj/item/ship_combat_missile/light = 6)
	crate_name = "light missiles crate"

/datum/supply_pack/ship_combat/missiles_heavy
	name = "Heavy Missiles Crate"
	desc = "A crate containing two heavy warhead missiles. \
		Devastating damage but expensive and bulky."
	cost = CARGO_CRATE_VALUE * 15
	contains = list(/obj/item/ship_combat_missile/heavy = 2)
	crate_name = "heavy missiles crate"

/datum/supply_pack/ship_combat/missiles_incendiary
	name = "Incendiary Missiles Crate"
	desc = "A crate containing three incendiary missiles. \
		Sets the impact area ablaze."
	cost = CARGO_CRATE_VALUE * 12
	contains = list(/obj/item/ship_combat_missile/incendiary = 3)
	crate_name = "incendiary missiles crate"

/datum/supply_pack/ship_combat/missiles_emp
	name = "EMP Missiles Crate"
	desc = "A crate containing three EMP missiles. \
		Disables electronics and equipment on impact."
	cost = CARGO_CRATE_VALUE * 14
	contains = list(/obj/item/ship_combat_missile/emp = 3)
	crate_name = "EMP missiles crate"

/datum/supply_pack/ship_combat/missiles_mixed
	name = "Mixed Missiles Crate"
	desc = "A crate containing an assortment of missiles: \
		two standard, one heavy, one EMP, and one incendiary."
	cost = CARGO_CRATE_VALUE * 14
	contains = list(
		/obj/item/ship_combat_missile = 2,
		/obj/item/ship_combat_missile/heavy = 1,
		/obj/item/ship_combat_missile/emp = 1,
		/obj/item/ship_combat_missile/incendiary = 1,
	)
	crate_name = "mixed missiles crate"

// ========== EQUIPMENT PACKS ==========

/datum/supply_pack/ship_combat/launcher_kit
	name = "Missile Launcher Kit"
	desc = "A starter kit for ship combat: contains a missile launcher \
		circuit board and two standard missiles."
	cost = CARGO_CRATE_VALUE * 8
	contains = list(
		/obj/item/circuitboard/machine/ship_combat/missile_launcher = 1,
		/obj/item/ship_combat_missile = 2,
	)
	crate_name = "missile launcher kit"

/datum/supply_pack/ship_combat/combat_starter
	name = "Ship Combat Starter Pack"
	desc = "Everything you need to get started with ship combat: \
		a combat console board, launcher board, and four standard missiles."
	cost = CARGO_CRATE_VALUE * 15
	contains = list(
		/obj/item/circuitboard/computer/ship_combat_console = 1,
		/obj/item/circuitboard/machine/ship_combat/missile_launcher = 1,
		/obj/item/ship_combat_missile = 4,
	)
	crate_name = "ship combat starter pack"
