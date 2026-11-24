/**
 * # Xenoarchaeology research nodes
 *
 * Three nodes on tg's price ladder. The excavation kit itself comes from the ship autolathe and
 * needs no research (dig/designs.dm).
 *
 * - Xenoarchaeology (tier 1): stabiliser, spectrometer, analyser and scan pad, labeler, specimen crate.
 * - Advanced Excavation (tier 2): the advanced scanner and quick brush.
 * - Exotic Particles (tier 3, yellow standing): the harvester, exotic battery and utilizer.
 *
 * Each node lists every design it unlocks, including those printed by the dig, use and trade
 * parts of this module (named below by the file that defines them).
 */

#define TECHWEB_NODE_XENOARCH "xenoarchaeology"
#define TECHWEB_NODE_XENOARCH_EXCAVATION "xenoarch_excavation"
#define TECHWEB_NODE_XENOARCH_EXOTIC "xenoarch_exotic_particles"

/datum/techweb_node/xenoarchaeology
	id = TECHWEB_NODE_XENOARCH
	display_name = "Xenoarchaeology"
	description = "Field stabilisers and a sample spectrometer for getting large finds out whole, and a bench analyser to read them once they're home."
	prereq_ids = list(TECHWEB_NODE_FUNDIMENTAL_SCI)
	design_ids = list(
		"xenoarch_analyser",
		"xenoarch_scanpad",
		"xenoarch_labeler",
		"xenoarch_stabiliser", // dig/stabiliser.dm
		"xenoarch_spectrometer", // dig/spectrometer.dm
		"xenoarch_specimen_crate", // trade/specimen_crate.dm
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_1_POINTS)

/datum/techweb_node/xenoarch_excavation
	id = TECHWEB_NODE_XENOARCH_EXCAVATION
	display_name = "Advanced Excavation"
	description = "A depth scanner that reads the stabilising field on the spot, and a quicker brush."
	prereq_ids = list(TECHWEB_NODE_XENOARCH)
	design_ids = list(
		"xenoarch_scanner_advanced", // dig/tools.dm
		"xenoarch_brush_quick", // dig/tools.dm
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)

/datum/techweb_node/xenoarch_exotic_particles
	id = TECHWEB_NODE_XENOARCH_EXOTIC
	display_name = "Exotic Particles"
	description = "A harvester that draws a live emission out of a large find into a battery, and a handheld projector that can let it out again."
	prereq_ids = list(TECHWEB_NODE_XENOARCH)
	design_ids = list(
		"xenoarch_harvester", // use/harvester.dm
		"xenoarch_battery", // use/battery.dm
		"xenoarch_utilizer", // use/utilizer.dm
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)
	// The utilizer and battery are rated yellow (tools/gear_catalog/ratings/relics.json).
	zone_permission = ZONE_PERMISSION_YELLOW

// ===== Designs printed by this part =====

/datum/design/board/artifact_analyser
	name = "Machine Design (Artifact Analyser Board)"
	desc = "The circuit board for a bench artifact analyser."
	id = "xenoarch_analyser"
	build_path = /obj/item/circuitboard/machine/artifact_analyser
	category = list(RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_RESEARCH)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE

/datum/design/board/artifact_scanpad
	name = "Machine Design (Scan Pad Board)"
	desc = "The circuit board for the scan pad an artifact analyser reads through."
	id = "xenoarch_scanpad"
	build_path = /obj/item/circuitboard/machine/artifact_scanpad
	category = list(RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_RESEARCH)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE

/datum/design/artifact_labeler
	name = "Specimen Labeler"
	desc = "A handheld printer for the tags that go on large finds."
	id = "xenoarch_labeler"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SMALL_MATERIAL_AMOUNT * 2,
		/datum/material/glass = SMALL_MATERIAL_AMOUNT * 1.5,
	)
	build_path = /obj/item/artifact_labeler
	category = list(RND_CATEGORY_EQUIPMENT + RND_SUBCATEGORY_EQUIPMENT_SCIENCE)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE
