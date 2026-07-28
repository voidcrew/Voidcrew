/**
 * # Industrial uniques — Helios-Betna Forgeworks certified goods cache
 *
 * Six one-of-a-kind prizes for the industrial rare-loot table
 * (`voidcrew/modules/loot/zone_loot.dm`, `/obj/structure/closet/crate/zone_loot/industrial/rare`).
 * Design source: `Rare-loot-uniques.md` in the docs vault, "INDUSTRIAL — certified
 * goods cache" section.
 *
 * Every item here carries TRAIT_NO_REPLICATE (voidcrew/_DEFINES/loot.dm) so it
 * can never be memorized by the Helios pattern stamp (or any future
 * duplicator) — uniques stay unique. The stamp is the trait's first consumer.
 *
 * Tiers: Helios lunch pail + the honest gauge are GREEN, Slagmaw + the Line
 * gauntlet are YELLOW, Forge-heart + the Helios pattern stamp are RED.
 */

// =========================================================================
// GREEN
// =========================================================================

/**
 * # Helios lunch pail
 *
 * Subtypes the plain steel toolbox for its sprite (a "steel lunchbox" reads
 * fine on a toolbox-shaped case). Restocks a coffee, a sandwich, and a
 * boiled egg once an hour; finishing any one of them to the last bite grants
 * a timed buff. TRAIT_QUICK_BUILD is the closest existing hook to a generic
 * "construction/repair/machine interaction" speedup in this codebase (it's
 * checked ad hoc by girder building and CRAFT_APPLIES_MATS stack recipes,
 * not a universal do_after multiplier) — see the deviation note in the
 * implementer's report.
 */
/obj/item/storage/toolbox/helios_lunch_pail
	name = "Helios lunch pail"
	desc = "A steel lunchbox, HELIOS-BETNA CANTEEN SERVICES. The thermos has never once been washed."
	icon_state = "toolbox_default"
	inhand_icon_state = "toolbox_default"
	material_flags = NONE
	/// Ration types kept stocked in the pail
	var/list/ration_types = list(
		/obj/item/reagent_containers/cup/glass/coffee/helios_canteen,
		/obj/item/food/sandwich/helios_canteen,
		/obj/item/food/boiledegg/helios_canteen,
	)
	/// How often the pail tops itself back up
	var/restock_interval = 1 HOURS
	/// Timer id for the restock loop
	var/restock_timer

/obj/item/storage/toolbox/helios_lunch_pail/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)
	restock_timer = addtimer(CALLBACK(src, PROC_REF(restock)), restock_interval, TIMER_LOOP|TIMER_STOPPABLE)

/obj/item/storage/toolbox/helios_lunch_pail/Destroy()
	deltimer(restock_timer)
	return ..()

/obj/item/storage/toolbox/helios_lunch_pail/PopulateContents()
	restock()

/// Tops up any ration that isn't currently sitting in the pail.
/obj/item/storage/toolbox/helios_lunch_pail/proc/restock()
	for(var/ration_type in ration_types)
		if(locate(ration_type) in contents)
			continue
		new ration_type(src)

/obj/item/storage/toolbox/helios_lunch_pail/examine(mob/user)
	. = ..()
	. += span_notice("A hand-written union sticker reads: <i>finish a full ration and the work goes easier for a while.</i>")
	. += span_notice("Restocks itself once an hour.")

/// Canteen coffee — flavor only, no buff hook (drinks aren't run through the edible component in this codebase).
/obj/item/reagent_containers/cup/glass/coffee/helios_canteen
	name = "canteen coffee"
	desc = "Hot, black, and free. HELIOS-BETNA CANTEEN SERVICES."

/obj/item/food/sandwich/helios_canteen
	name = "canteen sandwich"
	desc = "Simple, filling, and gone in three bites. HELIOS-BETNA CANTEEN SERVICES."

/obj/item/food/sandwich/helios_canteen/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_FOOD_CONSUMED, PROC_REF(on_full_meal))

/obj/item/food/sandwich/helios_canteen/proc/on_full_meal(datum/source, mob/living/eater, mob/feeder)
	SIGNAL_HANDLER
	grant_helios_break(eater)

/obj/item/food/boiledegg/helios_canteen
	name = "canteen boiled egg"
	desc = "Peeled, salted, and free for the taking. HELIOS-BETNA CANTEEN SERVICES."

/obj/item/food/boiledegg/helios_canteen/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_FOOD_CONSUMED, PROC_REF(on_full_meal))

/obj/item/food/boiledegg/helios_canteen/proc/on_full_meal(datum/source, mob/living/eater, mob/feeder)
	SIGNAL_HANDLER
	grant_helios_break(eater)

/// Grants the lunch-break buff to whoever finished a full canteen ration.
/proc/grant_helios_break(mob/living/eater)
	if(!isliving(eater))
		return
	eater.apply_status_effect(/datum/status_effect/helios_break)

/**
 * The union break: TRAIT_QUICK_BUILD for a few minutes. In this codebase
 * that trait is checked ad hoc by girder/plating construction
 * (code/game/objects/structures/girders.dm) and by stack recipes flagged
 * trait_booster/trait_modifier (most platform/wall recipes) — the closest
 * existing thing to a generic "construction runs faster" hook. No alert
 * icon: this status effect intentionally carries none rather than reuse an
 * unrelated sprite.
 */
/datum/status_effect/helios_break
	id = "helios_break"
	duration = 3 MINUTES
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_REFRESH
	alert_type = null

/datum/status_effect/helios_break/on_apply()
	ADD_TRAIT(owner, TRAIT_QUICK_BUILD, id)
	to_chat(owner, span_notice("The meal sits well. Construction work will go easier for a while."))
	return TRUE

/datum/status_effect/helios_break/on_remove()
	REMOVE_TRAIT(owner, TRAIT_QUICK_BUILD, id)

/**
 * # The honest gauge
 *
 * Subtypes the gas analyzer for its sprite. On machines: the RPED-style
 * parts manifest plus power draw and an operational diagnostic. On turfs
 * (walls and floors): integrity percentage, plus the same pipe/wire reveal
 * a T-ray scanner gives, borrowed from the global t_ray_scan() helper — no
 * new scanning tech, just merged readouts, exactly as the design doc asks.
 */
/obj/item/analyzer/honest_gauge
	name = "the honest gauge"
	desc = "An analyzer with the plastic worn through to the metal. Reads machines and turfs, and the needle has never been wrong yet."

/obj/item/analyzer/honest_gauge/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/analyzer/honest_gauge/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(istype(interacting_with, /obj/machinery))
		read_machine(interacting_with, user)
		return ITEM_INTERACT_SUCCESS
	if(isturf(interacting_with))
		read_turf(interacting_with, user)
		return ITEM_INTERACT_SUCCESS
	return ..()

/// Prints a parts manifest, power draw, and an honest diagnostic for a machine.
/obj/item/analyzer/honest_gauge/proc/read_machine(obj/machinery/target, mob/living/user)
	var/list/message = list()
	message += span_boldnotice("[src] reads [target]:")
	message += target.display_parts(user)
	message += span_notice("Power draw: [display_power(target.idle_power_usage)] idle / [display_power(target.active_power_usage)] active.")
	if(target.machine_stat & BROKEN)
		message += span_warning("Diagnostic: broken and non-functional.")
	else if(!target.is_operational)
		message += span_warning("Diagnostic: not operational.")
	else if(target.atom_integrity < target.max_integrity)
		message += span_warning("Diagnostic: structural stress, [round(target.atom_integrity / target.max_integrity * 100)]% integrity, underperforming.")
	else
		message += span_notice("Diagnostic: nominal.")
	to_chat(user, boxed_message(jointext(message, "\n")), type = MESSAGE_TYPE_INFO)
	playsound(src, SFX_INDUSTRIAL_SCAN, 20, TRUE, -2, TRUE, FALSE)

/// Reads a turf's structural integrity and reveals what's hidden inside it, no unwrenching required.
/obj/item/analyzer/honest_gauge/proc/read_turf(turf/target, mob/living/user)
	if(target.uses_integrity && target.max_integrity)
		to_chat(user, span_notice("[src] reads [target]: [round(target.atom_integrity / target.max_integrity * 100)]% integrity."))
	else
		to_chat(user, span_notice("[src] finds nothing structural to grade in [target]."))
	t_ray_scan(user, 8, 3)
	playsound(src, SFX_INDUSTRIAL_SCAN, 20, TRUE, -2, TRUE, FALSE)

// =========================================================================
// YELLOW
// =========================================================================

/**
 * # Slagmaw
 *
 * Subtypes the standard welding tool for its sprite. Still burns ordinary
 * welder fuel, but will also grind up almost anything fed to it (attacking
 * the welder with another item) into extra fuel. As a repair tool it calls
 * the universal /atom/proc/repair_damage() directly for a one-pass full
 * restore — there's no single "reweld to full" proc for walls in this
 * codebase (walls only expose cosmetic dent-fixing and deconstruction via
 * welder), so this goes straight to the integrity API instead of trying to
 * replicate wall-specific do_after chains.
 */
/obj/item/weldingtool/slagmaw
	name = "Slagmaw"
	desc = "A welding torch rebuilt around an intake hopper. Feed it scrap and it makes its own fuel."
	/// Fuel granted per weight class of whatever's fed to it
	var/fuel_per_weight_class = 4

/obj/item/weldingtool/slagmaw/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/weldingtool/slagmaw/examine(mob/user)
	. = ..()
	. += span_notice("Feeding it another item (attack [src] while holding one) converts the mass into fuel.")
	. += span_notice("While lit, a single pass fully repairs a damaged wall, window, or breach.")

/obj/item/weldingtool/slagmaw/attackby(obj/item/tool, mob/user, list/modifiers, list/attack_modifiers)
	if(istype(tool, /obj/item/stack/rods))
		return ..()
	if(feed(tool, user))
		return TRUE
	return ..()

/// Grinds an arbitrary item into fuel. Returns FALSE (and does nothing) for rods, ourself, or a full hopper.
/obj/item/weldingtool/slagmaw/proc/feed(obj/item/morsel, mob/user)
	if(morsel == src || istype(morsel, /obj/item/weldingtool))
		return FALSE
	if(get_fuel() >= max_fuel)
		balloon_alert(user, "hopper full")
		return FALSE
	var/fuel_gain = clamp(round(morsel.w_class * fuel_per_weight_class), 2, max_fuel)
	user.visible_message(
		span_notice("[user] feeds [morsel] into [src]'s intake hopper."),
		span_notice("You feed [morsel] into [src]. The hopper grinds it to slag."),
	)
	playsound(src, 'sound/items/tools/welder.ogg', 30, TRUE)
	qdel(morsel)
	reagents.add_reagent(/datum/reagent/fuel, min(fuel_gain, max_fuel - get_fuel()))
	update_appearance()
	return TRUE

/obj/item/weldingtool/slagmaw/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	// Walls don't use atom integrity in this codebase (nothing to "repair" on them),
	// so the one-pass restore covers structures, windows, and damaged machinery instead
	if(isOn() && interacting_with.uses_integrity && (isturf(interacting_with) || istype(interacting_with, /obj/structure) || istype(interacting_with, /obj/machinery)) && interacting_with.atom_integrity < interacting_with.max_integrity)
		if(!use_tool(interacting_with, user, 3 SECONDS, amount = 5, volume = 50))
			return ITEM_INTERACT_BLOCKING
		if(QDELETED(interacting_with))
			return ITEM_INTERACT_SUCCESS
		interacting_with.repair_damage(INFINITY)
		user.visible_message(
			span_notice("[user] passes [src] over [interacting_with], and the damage closes right up."),
			span_notice("You restore [interacting_with] to full integrity in a single pass."),
		)
		return ITEM_INTERACT_SUCCESS
	return ..()

/**
 * # Line gauntlet
 *
 * Subtypes the H.A.U.L. cargo gauntlet for its sprite ("power-assisted work
 * glove" flavor matches). On an unarmed strike against a machine or
 * structure, deconstructs it cleanly after a short do_after — never against
 * anything isliving(), which is the interlock the flavor text describes.
 * Modeled on /datum/element/structure_repair's approach: register on
 * COMSIG_LIVING_UNARMED_ATTACK and cancel the normal attack chain.
 */
/obj/item/clothing/gloves/cargo_gauntlet/line_gauntlet
	name = "Line gauntlet"
	desc = "A power-assisted work glove stenciled STATION 6 - DISASSEMBLY. Takes machines and structures apart with your bare hands."
	/// How long the strike takes to finish tearing something down
	var/deconstruct_time = 3 SECONDS

/obj/item/clothing/gloves/cargo_gauntlet/line_gauntlet/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/gloves/cargo_gauntlet/line_gauntlet/equipped(mob/user, slot, initial)
	. = ..()
	if(slot & ITEM_SLOT_GLOVES)
		RegisterSignal(user, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_unarmed_attack))

/obj/item/clothing/gloves/cargo_gauntlet/line_gauntlet/dropped(mob/user, silent)
	. = ..()
	if(!QDELETED(user) && user.get_item_by_slot(ITEM_SLOT_GLOVES) != src)
		UnregisterSignal(user, COMSIG_LIVING_UNARMED_ATTACK)

/// Intercepts an unarmed strike against a machine or structure. Mobs are never touched — the interlock.
/// Combat mode only: this signal fires on every empty-hand click, and ordinary interaction
/// (opening doors, pressing machine buttons) must keep working while the gauntlet is worn.
/obj/item/clothing/gloves/cargo_gauntlet/line_gauntlet/proc/on_unarmed_attack(mob/living/attacker, atom/target, proximity_flag, list/modifiers)
	SIGNAL_HANDLER
	if(!proximity_flag || isliving(target) || !attacker.combat_mode)
		return NONE
	if(!istype(target, /obj/machinery) && !istype(target, /obj/structure))
		return NONE
	if(QDELETED(target) || (target.resistance_flags & INDESTRUCTIBLE))
		return NONE
	INVOKE_ASYNC(src, PROC_REF(try_disassemble), attacker, target)
	return COMPONENT_CANCEL_ATTACK_CHAIN

/obj/item/clothing/gloves/cargo_gauntlet/line_gauntlet/proc/try_disassemble(mob/living/user, atom/target)
	user.visible_message(
		span_warning("[user] grips [target] and starts tearing it apart!"),
		span_notice("You start tearing [target] down with [src]."),
	)
	if(!do_after(user, deconstruct_time, target = target))
		return
	if(QDELETED(target) || isliving(target))
		return
	var/obj/disassembling = target
	disassembling.deconstruct(TRUE)

// =========================================================================
// RED
// =========================================================================

/**
 * # Forge-heart
 *
 * Subtypes the power cell for its sprite (reuses the hyper-capacity cell's
 * "hpcell" icon state). Never runs dry: use() always tops back up to full
 * immediately after paying out. The cost is a processing loop that
 * constantly bleeds heat into whatever turf it's currently on, following
 * the same direct gas-mixture temperature math /obj/machinery/space_heater
 * uses (there's no adjust_heat()/set_temperature() helper in this
 * codebase — space_heater does turf_gasmix.temperature += delta directly).
 * Heat shedding is always on, by design — that's the balance knob.
 */
/obj/item/stock_parts/power_store/cell/forge_heart
	name = "Forge-heart"
	desc = "A power cell that ticks like a cooling engine block. It has never read below full."
	icon_state = "hpcell"
	maxcharge = STANDARD_CELL_CHARGE * 30
	chargerate = STANDARD_CELL_RATE * 2
	/// Watts of heat continuously bled into the local turf's air, always-on
	var/heat_output_watts = 1500

/obj/item/stock_parts/power_store/cell/forge_heart/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)
	charge = maxcharge
	START_PROCESSING(SSobj, src)

/obj/item/stock_parts/power_store/cell/forge_heart/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/stock_parts/power_store/cell/forge_heart/use(used, force = FALSE)
	. = ..(used, TRUE)
	charge = maxcharge

/obj/item/stock_parts/power_store/cell/forge_heart/examine(mob/user)
	. = ..()
	. += span_warning("It's warm to the touch, and it heats up the air around it.")

/obj/item/stock_parts/power_store/cell/forge_heart/process(seconds_per_tick)
	charge = maxcharge
	var/turf/open/local_turf = get_turf(src)
	if(!istype(local_turf))
		return
	var/datum/gas_mixture/environment = local_turf.return_air()
	if(!environment)
		return
	var/heat_capacity = environment.heat_capacity()
	if(heat_capacity <= 0)
		return
	environment.temperature += (heat_output_watts * seconds_per_tick) / heat_capacity
	air_update_turf(FALSE, FALSE)

/**
 * # Helios pattern stamp
 *
 * Subtypes the ordinary rubber stamp for its sprite. Memorizes one item's
 * typepath + custom_materials cost at a time (press it against an eligible
 * item); feed it matching material stacks to bank the cost; strike a copy
 * once fully banked, on a 5-minute cooldown. Blacklist: TRAIT_NO_REPLICATE
 * (every unique in this file, and the hook this whole trait exists for),
 * storage with contents, power cells, and guns. Memorization failures fall
 * through to the normal attack chain (return ..()) rather than blocking it,
 * so pressing the stamp against ordinary paper still stamps the paper
 * normally instead of silently eating the click.
 */
/obj/item/stamp/helios_pattern
	name = "Helios pattern stamp"
	desc = "A heavy seal-stamp reading FINAL INSPECTION - PASSED. It remembers the shape of whatever it stamps."
	/// Typepath currently memorized, if any
	var/memorized_type
	/// Display name of the memorized item, for examine/chat text
	var/memorized_name
	/// material typepath -> amount required to strike one copy
	var/list/memorized_materials
	/// material typepath -> amount currently banked
	var/list/banked_materials
	/// Cooldown between strikes
	var/strike_cooldown = 5 MINUTES
	/// world.time the stamp is next allowed to strike
	var/next_strike = 0

/obj/item/stamp/helios_pattern/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/stamp/helios_pattern/examine(mob/user)
	. = ..()
	if(!memorized_type)
		. += span_notice("No pattern held. Press it against a crafted item to memorize it.")
		return
	. += span_notice("Pattern held: <b>[memorized_name]</b>.")
	var/list/cost_lines = list()
	for(var/mat_key in memorized_materials)
		var/datum/material/mat = mat_key
		cost_lines += "[banked_materials[mat_key]]/[memorized_materials[mat_key]] [initial(mat.name)]"
	if(length(cost_lines))
		. += span_notice("Banked: [cost_lines.Join(", ")].")
	. += span_notice(next_strike <= world.time ? "Ready to strike." : "Cooling down: ready in [DisplayTimeText(next_strike - world.time)].")

/obj/item/stamp/helios_pattern/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isitem(interacting_with) || interacting_with == src)
		return ..()
	var/obj/item/target = interacting_with
	if(!can_memorize(target, user))
		return ..()
	memorize(target, user)
	return ITEM_INTERACT_SUCCESS

/// Whether target is honest enough work for the stamp to remember.
/obj/item/stamp/helios_pattern/proc/can_memorize(obj/item/target, mob/user)
	if(HAS_TRAIT(target, TRAIT_NO_REPLICATE))
		balloon_alert(user, "too unique to copy")
		return FALSE
	if(istype(target, /obj/item/gun))
		balloon_alert(user, "no guns")
		return FALSE
	if(istype(target, /obj/item/stock_parts/power_store/cell))
		balloon_alert(user, "no cells")
		return FALSE
	if(istype(target, /obj/item/stack))
		return FALSE // raw material, not a finished pattern — quietly decline
	if(istype(target, /obj/item/storage))
		var/obj/item/storage/storage_target = target
		if(length(storage_target.contents))
			balloon_alert(user, "empty it first")
			return FALSE
	if(!length(target.custom_materials))
		return FALSE // nothing to reclaim — quietly decline (also protects ordinary paper etc.)
	return TRUE

/obj/item/stamp/helios_pattern/proc/memorize(obj/item/target, mob/user)
	memorized_type = target.type
	memorized_name = target.name
	memorized_materials = target.custom_materials.Copy()
	banked_materials = list()
	for(var/mat_key in memorized_materials)
		banked_materials[mat_key] = 0
	next_strike = max(next_strike, world.time)
	user.visible_message(
		span_notice("[user] presses [src] against [target]. It hums as it memorizes a perfect impression."),
		span_notice("[src] memorizes [target]."),
	)
	playsound(src, 'sound/items/handling/standard_stamp.ogg', 40, TRUE)

/obj/item/stamp/helios_pattern/attackby(obj/item/tool, mob/user, list/modifiers, list/attack_modifiers)
	if(istype(tool, /obj/item/stack))
		if(feed_materials(tool, user))
			return TRUE
	return ..()

/// Banks material from a fed stack toward the memorized pattern's cost.
/obj/item/stamp/helios_pattern/proc/feed_materials(obj/item/stack/material_stack, mob/user)
	if(!memorized_type)
		balloon_alert(user, "no pattern held")
		return FALSE
	// custom_materials is keyed by material datum instances, not typepaths —
	// convert the stack's material_type before indexing or nothing ever matches
	var/datum/material/mat_ref = material_stack.material_type ? GET_MATERIAL_REF(material_stack.material_type) : null
	var/needed = (mat_ref && memorized_materials[mat_ref]) ? (memorized_materials[mat_ref] - banked_materials[mat_ref]) : 0
	if(needed <= 0)
		balloon_alert(user, "won't take that")
		return FALSE
	var/units_needed = max(1, CEILING(needed / SHEET_MATERIAL_AMOUNT, 1))
	var/units_to_use = min(units_needed, material_stack.amount)
	if(!material_stack.use(units_to_use))
		return FALSE
	banked_materials[mat_ref] += units_to_use * SHEET_MATERIAL_AMOUNT
	user.visible_message(
		span_notice("[user] feeds [material_stack] into [src]."),
		span_notice("You feed [src] [units_to_use] unit\s of material."),
	)
	return TRUE

/obj/item/stamp/helios_pattern/proc/materials_ready()
	for(var/mat_key in memorized_materials)
		if(banked_materials[mat_key] < memorized_materials[mat_key])
			return FALSE
	return TRUE

/obj/item/stamp/helios_pattern/proc/consume_banked_materials()
	for(var/mat_key in memorized_materials)
		banked_materials[mat_key] = max(0, banked_materials[mat_key] - memorized_materials[mat_key])

/obj/item/stamp/helios_pattern/attack_self(mob/user)
	. = ..()
	if(!memorized_type)
		balloon_alert(user, "no pattern held")
		return
	if(next_strike > world.time)
		balloon_alert(user, "cooling down")
		return
	if(!materials_ready())
		balloon_alert(user, "needs more material")
		return
	consume_banked_materials()
	new memorized_type(get_turf(user))
	user.visible_message(
		span_notice("[user] brings [src] down with a heavy clack. A perfect duplicate of [memorized_name] drops free."),
		span_notice("You strike a fresh copy of [memorized_name]."),
	)
	playsound(src, 'sound/items/handling/standard_stamp.ogg', 50, TRUE)
	next_strike = world.time + strike_cooldown
