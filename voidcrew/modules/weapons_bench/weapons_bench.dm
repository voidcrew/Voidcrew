/**
 * Weapons assembly bench
 *
 * The final stage of the blueprint -> gun pipeline (see the Loot-economy design doc).
 * Deliberately a "dumb assembler" with no techweb link of its own: possessing a
 * machined gun part is already proof its part node was researched (the protolathe
 * gated the print). The bench just combines, on one tile:
 *
 *   blueprint (retained, removable/stealable) + matching part (consumed)
 *   + firing pin (consumed -> installed into the finished gun)  ==>  finished gun
 *
 * One loaded blueprint builds the gun as many times as the crew can feed it parts
 * and pins -- replication for the whole crew is the point. Materials beyond the
 * part + pin are intentionally omitted for now (non-load-bearing per design; the
 * real gates are research depth and finding/buying the blueprint).
 */
/obj/machinery/weapons_bench
	name = "weapons assembly bench"
	desc = "A heavy fabrication bench for assembling finished firearms from a blueprint, a machined part and a firing pin."
	icon = 'voidcrew/modules/weapons_bench/icons/weapons_bench.dmi'
	icon_state = "bench"
	density = TRUE
	circuit = /obj/item/circuitboard/machine/weapons_bench

	/// The loaded blueprint. Retained across builds; removable/stealable.
	var/obj/item/gun_blueprint/loaded_blueprint
	/// The loaded machined part. Consumed on assembly.
	var/obj/item/gun_part/loaded_part
	/// The loaded firing pin. Installed into the built gun on assembly.
	var/obj/item/firing_pin/loaded_pin
	/// TRUE while an assembly do_after is running.
	var/building = FALSE
	/// How long an assembly takes.
	var/assembly_time = 3 SECONDS

/obj/machinery/weapons_bench/Destroy()
	QDEL_NULL(loaded_blueprint)
	QDEL_NULL(loaded_part)
	QDEL_NULL(loaded_pin)
	return ..()

/obj/machinery/weapons_bench/on_deconstruction(disassembled)
	drop_loaded()
	return ..()

/obj/machinery/weapons_bench/examine(mob/user)
	. = ..()
	if(loaded_blueprint)
		. += span_notice("Loaded blueprint: <b>[loaded_blueprint.blueprint_name]</b>.")
	else
		. += span_notice("No blueprint loaded. Insert a weapon blueprint.")
	. += span_notice("Part: [loaded_part ? loaded_part.name : "<i>none</i>"] &mdash; Firing pin: [loaded_pin ? "installed" : "<i>none</i>"].")
	. += span_notice("<b>Click</b> to assemble once a blueprint, matching part and firing pin are all loaded. <b>Right-click</b> to eject loaded components.")

/obj/machinery/weapons_bench/update_icon_state()
	. = ..()
	icon_state = (building && is_operational) ? "bench_on" : "bench"

/obj/machinery/weapons_bench/attackby(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(istype(attacking_item, /obj/item/gun_blueprint))
		return load_blueprint(attacking_item, user)
	if(istype(attacking_item, /obj/item/gun_part))
		return load_part(attacking_item, user)
	if(istype(attacking_item, /obj/item/firing_pin))
		return load_pin(attacking_item, user)
	return ..()

/obj/machinery/weapons_bench/proc/load_blueprint(obj/item/gun_blueprint/blueprint, mob/living/user)
	if(loaded_blueprint)
		balloon_alert(user, "blueprint already loaded!")
		return TRUE
	if(!user.transferItemToLoc(blueprint, src))
		return TRUE
	loaded_blueprint = blueprint
	balloon_alert(user, "blueprint loaded")
	return TRUE

/obj/machinery/weapons_bench/proc/load_part(obj/item/gun_part/part, mob/living/user)
	if(!loaded_blueprint)
		balloon_alert(user, "load a blueprint first!")
		return TRUE
	if(!istype(part, loaded_blueprint.required_part))
		balloon_alert(user, "part doesn't fit this blueprint!")
		return TRUE
	if(loaded_part)
		balloon_alert(user, "part already loaded!")
		return TRUE
	if(!user.transferItemToLoc(part, src))
		return TRUE
	loaded_part = part
	balloon_alert(user, "part loaded")
	return TRUE

/obj/machinery/weapons_bench/proc/load_pin(obj/item/firing_pin/pin, mob/living/user)
	if(loaded_pin)
		balloon_alert(user, "firing pin already loaded!")
		return TRUE
	if(!user.transferItemToLoc(pin, src))
		return TRUE
	loaded_pin = pin
	balloon_alert(user, "firing pin loaded")
	return TRUE

/obj/machinery/weapons_bench/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(!is_operational)
		return
	try_assemble(user)

/obj/machinery/weapons_bench/attack_hand_secondary(mob/user, list/modifiers)
	. = ..()
	if(. == SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN)
		return
	if(eject_components(user))
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/machinery/weapons_bench/proc/try_assemble(mob/living/user)
	if(building)
		return
	if(!loaded_blueprint)
		balloon_alert(user, "no blueprint!")
		return
	if(!loaded_part)
		balloon_alert(user, "missing part!")
		return
	if(!loaded_pin)
		balloon_alert(user, "missing firing pin!")
		return
	building = TRUE
	update_appearance(UPDATE_ICON_STATE)
	balloon_alert(user, "assembling...")
	if(!do_after(user, assembly_time, src) || !ready_to_assemble())
		building = FALSE
		update_appearance(UPDATE_ICON_STATE)
		return
	finish_assembly(user)
	building = FALSE
	update_appearance(UPDATE_ICON_STATE)

/obj/machinery/weapons_bench/proc/ready_to_assemble()
	return loaded_blueprint && loaded_part && loaded_pin && is_operational

/obj/machinery/weapons_bench/proc/finish_assembly(mob/living/user)
	var/obj/item/gun/built = new loaded_blueprint.result_path(drop_location())
	// Swap the gun's default pin for the crew-supplied one (mirrors /obj/item/gun/proc/unlock()).
	if(built.pin)
		QDEL_NULL(built.pin)
	loaded_pin.gun_insert(new_gun = built)
	loaded_pin = null
	QDEL_NULL(loaded_part)
	playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
	say("Assembly complete: [built.name].")

/obj/machinery/weapons_bench/proc/eject_components(mob/living/user)
	if(building)
		balloon_alert(user, "assembling!")
		return FALSE
	if(!loaded_blueprint && !loaded_part && !loaded_pin)
		balloon_alert(user, "nothing loaded")
		return FALSE
	drop_loaded()
	balloon_alert(user, "components ejected")
	return TRUE

/// Moves any loaded components out onto the bench's turf. No messaging (used by deconstruction too).
/obj/machinery/weapons_bench/proc/drop_loaded()
	var/drop_turf = drop_location()
	if(loaded_pin)
		loaded_pin.forceMove(drop_turf)
		loaded_pin = null
	if(loaded_part)
		loaded_part.forceMove(drop_turf)
		loaded_part = null
	if(loaded_blueprint)
		loaded_blueprint.forceMove(drop_turf)
		loaded_blueprint = null

/obj/machinery/weapons_bench/wrench_act(mob/living/user, obj/item/tool)
	if(building)
		return FALSE
	tool.play_tool_sound(src, 15)
	set_anchored(!anchored)
	return TRUE

/obj/machinery/weapons_bench/screwdriver_act(mob/living/user, obj/item/tool)
	if(building)
		return FALSE
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
 * the gating lives on the part/ammo nodes and the blueprint find, not here).
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
	description = "A workbench that assembles finished firearms from a blueprint, a machined part and a firing pin."
	prereq_ids = list(TECHWEB_NODE_BASIC_ARMS)
	design_ids = list("vc_weapons_bench_board")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_1_POINTS)
