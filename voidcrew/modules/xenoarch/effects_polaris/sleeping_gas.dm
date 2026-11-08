// Artifact effect: sleeping gas.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/gassleeping.dm.
// Voidcrew: vents nitrous oxide indoors only, from a finite reserve, and stops at a modest
// pressure on its tile (see the gas_vent parent in plasma_vent.dm). Everyone breathing near it is
// logged. Not harvestable.

/datum/artifact_effect/gas_vent/sleeping
	label_name = "Vents sleeping gas"
	log_name = "Sleeping gas"
	tier = ARTIFACT_TIER_RARE
	possible_kinds = list(ARTIFACT_ENERGY_BLUESPACE, ARTIFACT_ENERGY_SYNTHESIS)
	gas_type = /datum/gas/nitrous_oxide
	puff_color = "#f2f2ff"
	reserve_low = 100
	reserve_high = 200
