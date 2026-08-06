/*
 * Techweb designs for the industrial chemistry circuits.
 *
 * Ported from monkestation's wiremod_chem module (design/circuits.dm), plus the chemical
 * circuit board, which upstream never gave a design and without which every component
 * below is uninstallable.
 *
 * All of these print from the component printer, same as stock circuit components.
 */

/datum/design/integrated_circuit/chemical
	name = "Chemical Circuit Board"
	desc = "An integrated circuit board unlocked to accept chemistry components."
	id = "chemical_circuit_board"
	build_path = /obj/item/integrated_circuit/chemical

/datum/design/component/chem_filter
	name = "Chemical Filter"
	id = "chemical_filter"
	build_path = /obj/item/circuit_component/chem/filter

/datum/design/component/chem_mixer
	name = "Chemical Mixer"
	id = "chemical_mixer"
	build_path = /obj/item/circuit_component/chem/mixer

/datum/design/component/chem_splitter
	name = "Chemical Splitter"
	id = "chemical_splitter"
	build_path = /obj/item/circuit_component/chem/splitter

/datum/design/component/chem_weighted_splitter
	name = "Chemical Splitter (Weighted)"
	id = "weighted_splitter"
	build_path = /obj/item/circuit_component/chem/weighted_splitter

/datum/design/component/chem_synthesizer
	name = "Chemical Synthesizer"
	id = "chemical_synthesizer"
	build_path = /obj/item/circuit_component/chem/synthesizer

/datum/design/component/chem_internal_tank
	name = "Internal Chemical Tank"
	id = "internal_chemical_tank"
	build_path = /obj/item/circuit_component/chem/internal_tank

/datum/techweb_node/chem_circuitry
	id = TECHWEB_NODE_CHEM_CIRCUITRY
	display_name = "Industrial Chemistry"
	description = "Circuitry that speaks the language of reagents, letting a chemical plant run itself."
	//Needs both halves of the idea: circuitry to wire it, and chem synthesis to have
	//anything worth automating.
	prereq_ids = list(TECHWEB_NODE_PROGRAMMING, TECHWEB_NODE_CHEM_SYNTHESIS)
	design_ids = list(
		"chemical_circuit_board",
		"chemical_filter",
		"chemical_mixer",
		"chemical_splitter",
		"chemical_synthesizer",
		"internal_chemical_tank",
		"weighted_splitter",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)
