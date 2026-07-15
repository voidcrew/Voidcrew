/**
 * Weapons assembly bench
 *
 * A crafting workstation, not an assembler: gun schematic recipes (see
 * blueprint.dm) list it as their `machinery` requirement, so finished
 * firearms are crafted from the ordinary crafting menu while standing next
 * to one. It holds nothing, stores nothing and has no UI of its own — the
 * crafting menu is the interface.
 *
 * Cheap tier-1 board on purpose: the gates are the blueprint find and the
 * techweb part nodes, never the bench.
 */
/obj/machinery/weapons_bench
	name = "weapons assembly bench"
	desc = "A heavy fabrication bench with clamps, jigs and torque tooling for finishing firearms. Stand beside it with a weapon schematic, its machined part and a firing pin, and the build appears in your crafting menu."
	icon = 'voidcrew/modules/weapons_bench/icons/weapons_bench.dmi'
	icon_state = "bench"
	density = TRUE
	use_power = NO_POWER_USE
	circuit = /obj/item/circuitboard/machine/weapons_bench

/obj/machinery/weapons_bench/examine(mob/user)
	. = ..()
	. += span_notice("Gun schematic recipes appear in your <b>crafting menu</b> while you're next to it — bring the schematic (or its neural imprint), the machined part and a firing pin.")

/obj/machinery/weapons_bench/wrench_act(mob/living/user, obj/item/tool)
	tool.play_tool_sound(src, 15)
	set_anchored(!anchored)
	return TRUE

/obj/machinery/weapons_bench/screwdriver_act(mob/living/user, obj/item/tool)
	if(!default_deconstruction_screwdriver(user, "bench-o", "bench", tool))
		return FALSE
	return TRUE

/obj/machinery/weapons_bench/crowbar_act(mob/living/user, obj/item/tool)
	if(!default_deconstruction_crowbar(tool))
		return FALSE
	return TRUE

/**
 * Circuit board
 */
/obj/item/circuitboard/machine/weapons_bench
	name = "Weapons Assembly Bench"
	greyscale_colors = CIRCUIT_COLOR_SCIENCE
	build_path = /obj/machinery/weapons_bench
	req_components = list(
		/obj/item/stock_parts/servo = 2,
		/obj/item/stock_parts/micro_laser = 1,
		/obj/item/stack/cable_coil = 5,
	)

/**
 * Board design + unlock node (cheap, early -- the bench is meant to be ubiquitous;
 * the gating lives on the part nodes and the blueprint find, not here).
 */
/datum/design/board/weapons_bench
	name = "Weapons Assembly Bench (Machine Board)"
	desc = "The circuit board for a weapons assembly bench."
	id = "vc_weapons_bench_board"
	build_path = /obj/item/circuitboard/machine/weapons_bench
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_SECURITY,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

/datum/techweb_node/weapons_bench
	id = TECHWEB_NODE_WEAPONS_BENCH
	display_name = "Field Weapon Assembly"
	description = "A workbench with the jigs and tooling to finish firearms from schematics, machined parts and firing pins."
	prereq_ids = list(TECHWEB_NODE_BASIC_ARMS)
	design_ids = list("vc_weapons_bench_board")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_1_POINTS)
