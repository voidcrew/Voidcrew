/**
 * # Gas Harvest Contract
 *
 * "Fill a tank with hot nitrogen from a nebula and bring it to the pad.
 * Payment on chemistry, not promises."
 *
 * The contract sink for the nebula ram-scoop loop: one gas-tank deliver
 * objective, asking for a gas that a live nebula actually carries (falling
 * back to the common green-band gases if the scan comes up empty). Exotic
 * asks pay a voucher on top - danger-gated by which bands carry the gas.
 */
/datum/mission/gas_harvest
	name = "Gas Harvest Contract"
	weight = 8

	/// The /datum/gas typepath asked for
	var/gas_type
	/// Display name of the gas
	var/gas_name = "gas"
	/// Moles asked for in one tank
	var/required_moles = 600

/datum/mission/gas_harvest/get_archetype()
	return "procurement"

/datum/mission/gas_harvest/generate_details()
	// Ask parameters per gas: moles band, pay band, difficulty, voucher
	var/static/list/gas_asks = list(
		/datum/gas/plasma = list("moles" = list(600, 900), "value" = list(800, 1200), "difficulty" = MISSION_DIFFICULTY_EASY, "vouchers" = 0),
		/datum/gas/nitrogen = list("moles" = list(600, 900), "value" = list(700, 1100), "difficulty" = MISSION_DIFFICULTY_EASY, "vouchers" = 0),
		/datum/gas/water_vapor = list("moles" = list(600, 900), "value" = list(700, 1100), "difficulty" = MISSION_DIFFICULTY_EASY, "vouchers" = 0),
		/datum/gas/miasma = list("moles" = list(400, 700), "value" = list(900, 1400), "difficulty" = MISSION_DIFFICULTY_MEDIUM, "vouchers" = 0),
		/datum/gas/tritium = list("moles" = list(250, 450), "value" = list(1500, 2200), "difficulty" = MISSION_DIFFICULTY_MEDIUM, "vouchers" = 1),
		/datum/gas/pluoxium = list("moles" = list(200, 350), "value" = list(2000, 2800), "difficulty" = MISSION_DIFFICULTY_HARD, "vouchers" = 1),
		/datum/gas/nitrium = list("moles" = list(200, 350), "value" = list(2000, 2800), "difficulty" = MISSION_DIFFICULTY_HARD, "vouchers" = 1),
		/datum/gas/hypernoblium = list("moles" = list(150, 300), "value" = list(2400, 3200), "difficulty" = MISSION_DIFFICULTY_HARD, "vouchers" = 1),
	)

	// Only ask for gas somebody can actually go scoop: poll the live nebulas.
	// No nebula scan hit -> fall back to the common green-band gases.
	var/list/available_gases = list()
	for(var/obj/structure/overmap/event/nebula/nebula as anything in GLOB.nebula_events)
		if(QDELETED(nebula))
			continue
		if(nebula.gas_type && (nebula.gas_type in gas_asks))
			available_gases |= nebula.gas_type
	if(!length(available_gases))
		available_gases = list(/datum/gas/plasma, /datum/gas/nitrogen, /datum/gas/water_vapor)

	gas_type = pick(available_gases)
	var/datum/gas/gas_cast = gas_type
	gas_name = initial(gas_cast.name)

	var/list/ask = gas_asks[gas_type]
	required_moles = rand(ask["moles"][1], ask["moles"][2])
	value_min = ask["value"][1]
	value_max = ask["value"][2]
	difficulty = ask["difficulty"]
	voucher_count = ask["vouchers"]

/datum/mission/gas_harvest/build_objectives()
	var/datum/mission_objective/deliver/gas_tank/ask = new
	ask.gas_type = gas_type
	ask.required_name = gas_name
	ask.required_moles = required_moles
	add_objective(ask)

/datum/mission/gas_harvest/update_text()
	name = "Gas Harvest: [gas_name]"
	var/voucher_line = voucher_count > 0 ? " Payment includes [voucher_count] trade voucher[voucher_count > 1 ? "s" : ""]." : ""
	desc = "Deliver one handheld gas tank holding at least [required_moles] mol of [LOWER_TEXT(gas_name)] to the mission pad. \
		A ram scoop can harvest it while your ship holds still inside a matching nebula; transfer the gas from the pipe network into the tank. \
		Gas from any source counts, and mixtures are accepted if the requested gas meets the full quota in that one tank. We keep the tank and its contents.[voucher_line]"
