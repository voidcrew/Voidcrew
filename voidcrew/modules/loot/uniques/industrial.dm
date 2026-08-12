/**
 * # Industrial uniques: Helios-Betna Forgeworks certified goods cache
 *
 * Six one-of-a-kind prizes for the industrial uniques shelf
 * (`voidcrew/modules/loot/zone_loot.dm`, `loot_uniques` on /datum/loot_theme/industrial).
 * Design source: `Rare-loot-uniques.md` in the docs vault, "INDUSTRIAL: certified
 * goods cache" section.
 *
 * Every item here carries TRAIT_NO_REPLICATE (voidcrew/_DEFINES/loot.dm) so it
 * can never be memorized by the Helios pattern stamp (or any future
 * duplicator), uniques stay unique. The stamp is the trait's first consumer.
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
 * Subtypes the toolbox for its storage behaviour only. The sprite is its own
 * green lunch pail in uniques.dmi, with recoloured toolbox in-hands to match.
 * Restocks a coffee, a sandwich, and a boiled egg once an hour; finishing any
 * one of them to the last bite grants a timed buff with its own HUD alert.
 * TRAIT_QUICK_BUILD is the closest existing hook to a generic
 * "construction/repair/machine interaction" speedup in this codebase (it's
 * checked ad hoc by girder building and CRAFT_APPLIES_MATS stack recipes,
 * not a universal do_after multiplier) (see the deviation note in the)
 * implementer's report.
 */
/obj/item/storage/toolbox/helios_lunch_pail
	name = "Helios lunch pail"
	desc = "A green steel lunchbox, HELIOS-BETNA CANTEEN SERVICES. The thermos has never once been washed."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "helios_lunch_pail"
	inhand_icon_state = "helios_lunch_pail"
	lefthand_file = 'voidcrew/modules/loot/icons/uniques_lefthand.dmi'
	righthand_file = 'voidcrew/modules/loot/icons/uniques_righthand.dmi'
	// The toolbox latch overlay state lives in icons/obj/storage/toolbox.dmi. With our
	// own icon file it would resolve to nothing, and the pail already has latches drawn on.
	has_latches = FALSE
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
	var/datum/status_effect/helios_break/break_effect
	. += span_notice("Eat a whole canteen ration and construction work goes faster for [DisplayTimeText(initial(break_effect.duration))].")
	. += span_notice("Restocks itself every [DisplayTimeText(restock_interval)].")

/// Canteen coffee: flavor only, no buff hook (drinks aren't run through the edible component in this codebase).
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
 * trait_booster/trait_modifier (most platform/wall recipes), the closest
 * existing thing to a generic "construction runs faster" hook. It carries its
 * own HUD alert with a live countdown so the buff is visible while it lasts.
 */
/datum/status_effect/helios_break
	id = "helios_break"
	duration = 3 MINUTES
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_REFRESH
	alert_type = /atom/movable/screen/alert/status_effect/helios_break
	show_duration = TRUE

/datum/status_effect/helios_break/on_apply()
	ADD_TRAIT(owner, TRAIT_QUICK_BUILD, id)
	to_chat(owner, span_notice("The meal sits well. Construction work goes faster for the next [DisplayTimeText(duration)]."))
	return TRUE

/datum/status_effect/helios_break/on_remove()
	REMOVE_TRAIT(owner, TRAIT_QUICK_BUILD, id)
	to_chat(owner, span_notice("The lunch break wears off."))

/// HUD alert for the lunch break, so the speedup is visible with a countdown.
/atom/movable/screen/alert/status_effect/helios_break
	name = "Lunch Break"
	desc = "You finished a full canteen ration. Construction work goes faster until this runs out."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "alert_helios_break"

/**
 * # The honest gauge
 *
 * Subtypes the gas analyzer for its sprite. On machines: the RPED-style
 * parts manifest plus power draw and an operational diagnostic. On turfs
 * (walls and floors): integrity percentage, plus the same pipe/wire reveal
 * a T-ray scanner gives, borrowed from the global t_ray_scan() helper, no
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
 * A welding tool with its own sprite in uniques.dmi (plus the fuel-gauge and
 * lit overlay states the welder base builds from `initial(icon_state)`, so the
 * stock update_overlays() still works). Still burns ordinary welder fuel, but
 * will also grind scrap fed to it (attacking the welder with another item)
 * into extra fuel. As a repair tool it calls the universal
 * /atom/proc/repair_damage() directly for a one-pass full restore, there's no
 * single "reweld to full" proc for walls in this codebase (walls only expose
 * cosmetic dent-fixing and deconstruction via welder), so this goes straight
 * to the integrity API instead of trying to replicate wall-specific do_after
 * chains.
 *
 * The hopper only takes items with reclaimable custom_materials, and pays fuel
 * per sheet's worth of that material rather than per weight class, so a bulky
 * worthless item is refused outright instead of being worth 16 fuel. Every
 * refusal names its reason, and a feed takes a three-second do_after with a
 * progress bar. Stacks are consumed a sheet at a time, only up to what the
 * hopper has room for.
 */
/obj/item/weldingtool/slagmaw
	name = "Slagmaw"
	desc = "A welding torch rebuilt around an intake hopper. Feed it metal scrap and it makes its own fuel."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "slagmaw"
	/// Fuel granted per sheet's worth of reclaimable material in whatever's fed to it
	var/fuel_per_sheet = 3
	/// How long a feed takes, with a progress bar
	var/feed_time = 3 SECONDS

/obj/item/weldingtool/slagmaw/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/weldingtool/slagmaw/examine(mob/user)
	. = ..()
	. += span_notice("Feeding it a metal item (attack [src] while holding one) grinds it down into fuel. Takes [DisplayTimeText(feed_time)].")
	. += span_notice("It won't take anything without reclaimable material in it, and it won't take a loaded container.")
	. += span_notice("While lit, a single pass fully repairs a damaged wall, window, or breach.")

/obj/item/weldingtool/slagmaw/attackby(obj/item/tool, mob/user, list/modifiers, list/attack_modifiers)
	// Rods build a flamethrower on the welder base; leave that alone.
	if(istype(tool, /obj/item/stack/rods) || tool == src)
		return ..()
	feed(tool, user)
	return TRUE

/// Total reclaimable material in an item, in material units.
/obj/item/weldingtool/slagmaw/proc/material_worth(obj/item/morsel)
	var/total = 0
	for(var/mat_key in morsel.custom_materials)
		total += morsel.custom_materials[mat_key]
	return total

/**
 * Whether the hopper will take this item at all. Alerts the user with the
 * reason on every rejection. The whole complaint about the old version was
 * that it silently ate anything you were holding.
 */
/obj/item/weldingtool/slagmaw/proc/can_feed(obj/item/morsel, mob/user)
	if(!isitem(morsel) || (morsel.item_flags & (ABSTRACT|DROPDEL)))
		balloon_alert(user, "can't feed that")
		return FALSE
	if(istype(morsel, /obj/item/weldingtool))
		balloon_alert(user, "not another torch")
		return FALSE
	if(HAS_TRAIT(morsel, TRAIT_NODROP))
		balloon_alert(user, "stuck to your hand")
		return FALSE
	if(HAS_TRAIT(morsel, TRAIT_NO_REPLICATE))
		balloon_alert(user, "too rare to scrap")
		return FALSE
	if(morsel.resistance_flags & INDESTRUCTIBLE)
		balloon_alert(user, "hopper can't cut it")
		return FALSE
	if(length(morsel.contents))
		balloon_alert(user, "empty it out first")
		return FALSE
	if(get_fuel() >= max_fuel)
		balloon_alert(user, "hopper full")
		return FALSE
	if(!length(morsel.custom_materials) || material_worth(morsel) <= 0)
		balloon_alert(user, "no metal in it")
		return FALSE
	return TRUE

/// Grinds a metal item into fuel after a timed pass. Everything it refuses says why.
/obj/item/weldingtool/slagmaw/proc/feed(obj/item/morsel, mob/user)
	if(!can_feed(morsel, user))
		return FALSE
	balloon_alert(user, "feeding...")
	playsound(src, 'sound/items/tools/welder.ogg', 30, TRUE)
	if(!do_after(user, feed_time, target = src))
		balloon_alert(user, "interrupted")
		return FALSE
	// Three seconds is long enough for all of this to have changed. Recheck before deleting anything.
	if(QDELETED(morsel) || !user.is_holding(morsel) || !can_feed(morsel, user))
		return FALSE
	var/fuel_room = max_fuel - get_fuel()
	var/fuel_gain
	var/obj/item/stack/scrap_stack = istype(morsel, /obj/item/stack) ? morsel : null
	if(scrap_stack && scrap_stack.amount > 0)
		// Take only the sheets the hopper has room for, so nobody loses a full stack for two fuel.
		var/per_sheet = max(1, round(material_worth(scrap_stack) / scrap_stack.amount / SHEET_MATERIAL_AMOUNT * fuel_per_sheet))
		var/sheets_taken = clamp(CEILING(fuel_room / per_sheet, 1), 1, scrap_stack.amount)
		fuel_gain = sheets_taken * per_sheet
		user.visible_message(
			span_notice("[user] feeds [sheets_taken] [scrap_stack.singular_name]\s into [src]'s intake hopper."),
			span_notice("You feed [sheets_taken] [scrap_stack.singular_name]\s into [src]. The hopper grinds them to slag."),
		)
		scrap_stack.use(sheets_taken)
	else
		fuel_gain = max(1, round(material_worth(morsel) / SHEET_MATERIAL_AMOUNT * fuel_per_sheet))
		user.visible_message(
			span_notice("[user] feeds [morsel] into [src]'s intake hopper."),
			span_notice("You feed [morsel] into [src]. The hopper grinds it to slag."),
		)
		qdel(morsel)
	playsound(src, 'sound/items/tools/welder.ogg', 30, TRUE)
	reagents.add_reagent(/datum/reagent/fuel, min(fuel_gain, fuel_room))
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
 * structure, deconstructs it cleanly after a short do_after, never against
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

/// Intercepts an unarmed strike against a machine or structure. Mobs are never touched, the interlock.
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
 * codebase, space_heater does turf_gasmix.temperature += delta directly).
 * Heat shedding is always on, by design. That's the balance knob.
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
 * A rubber stamp with its own sprite in uniques.dmi. Memorizes one item's
 * typepath + custom_materials cost at a time (press it against an eligible
 * item); feed it matching material stacks to bank the cost; strike a copy
 * once fully banked, on a 5-minute cooldown. Blacklist: TRAIT_NO_REPLICATE
 * (every unique in this file, and the hook this whole trait exists for),
 * storage with contents, power cells, and guns.
 *
 * Paperwork (paper, folders, clipboards, photos) is skipped before any
 * memorize check runs, so ordinary stamping keeps working. Machinery, fixed
 * structures, material stacks and items with nothing to reclaim now say why
 * they can't be copied instead of doing nothing at all. Every refusal still
 * falls through to the normal attack chain rather than blocking it, so
 * setting the stamp down or feeding it into a machine is unaffected.
 *
 * Because the item's icon_state is no longer one of the bureaucracy.dmi stamp
 * states, get_writing_implement_details() is overridden to keep reporting the
 * stock "stamp-ok" impression; the paper spritesheet asset is keyed by state
 * name and would otherwise have no sprite to draw on the page.
 */
/obj/item/stamp/helios_pattern
	name = "Helios pattern stamp"
	desc = "A heavy seal-stamp reading FINAL INSPECTION - PASSED. It memorizes an item you press it against, and can strike one copy every 5 minutes."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "helios_stamp"
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
	/// Ticks down between strikes
	COOLDOWN_DECLARE(strike_timer)
	/// Paperwork the stamp is genuinely meant to be used on, never intercepted.
	var/static/list/paperwork_typecache = typecacheof(list(
		/obj/item/paper,
		/obj/item/paper_bin,
		/obj/item/clipboard,
		/obj/item/folder,
		/obj/item/photo,
		/obj/item/documents,
	))
	/// Structures you put things on or in, so setting the stamp down doesn't nag you.
	var/static/list/surface_typecache = typecacheof(list(
		/obj/structure/table,
		/obj/structure/rack,
		/obj/structure/closet,
		/obj/structure/displaycase,
		/obj/structure/filingcabinet,
	))

/obj/item/stamp/helios_pattern/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

// The paper spritesheet is keyed by icon_state and has no entry for our custom
// sprite, so report the stock impression instead of a blank stamp on the page.
/obj/item/stamp/helios_pattern/get_writing_implement_details()
	var/datum/asset/spritesheet_batched/sheet = get_asset_datum(/datum/asset/spritesheet/simple/paper)
	return list(
		interaction_mode = MODE_STAMPING,
		stamp_icon_state = "stamp-ok",
		stamp_class = sheet.icon_class_name("stamp-ok"),
	)

/obj/item/stamp/helios_pattern/examine(mob/user)
	. = ..()
	. += span_notice("Strikes one copy every [DisplayTimeText(strike_cooldown)].")
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
	. += span_notice(COOLDOWN_FINISHED(src, strike_timer) ? "Ready to strike." : "Cooling down: ready in [DisplayTimeText(COOLDOWN_TIMELEFT(src, strike_timer))].")

/obj/item/stamp/helios_pattern/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(interacting_with == src)
		return ..()
	if(!isitem(interacting_with))
		// Machines and fixed structures are the thing players kept pressing it against.
		// Say why nothing happened, then still fall through so any real interaction
		// (feeding it into a machine, setting it down on a table) keeps working.
		if(ismachinery(interacting_with) || (isstructure(interacting_with) && !is_type_in_typecache(interacting_with, surface_typecache)))
			balloon_alert(user, "only handheld items")
		return ..()
	// Paperwork goes straight through so the stamp still works as a stamp.
	if(is_type_in_typecache(interacting_with, paperwork_typecache))
		return ..()
	var/obj/item/target = interacting_with
	if(!can_memorize(target, user))
		return ..()
	memorize(target, user)
	return ITEM_INTERACT_SUCCESS

/**
 * Whether target is honest enough work for the stamp to remember. Alerts the user
 * with the reason on every refusal except stowing the stamp in a loaded container,
 * which is an ordinary thing to do and shouldn't nag.
 */
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
		balloon_alert(user, "raw material, not a pattern")
		return FALSE
	if(istype(target, /obj/item/storage))
		var/obj/item/storage/storage_target = target
		if(length(storage_target.contents))
			return FALSE // you're putting the stamp away, not copying the bag
	if(!length(target.custom_materials))
		balloon_alert(user, "nothing in it to measure")
		return FALSE
	return TRUE

/obj/item/stamp/helios_pattern/proc/memorize(obj/item/target, mob/user)
	memorized_type = target.type
	memorized_name = target.name
	memorized_materials = target.custom_materials.Copy()
	banked_materials = list()
	for(var/mat_key in memorized_materials)
		banked_materials[mat_key] = 0
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
	// custom_materials is keyed by material datum instances, not typepaths,
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
	if(!COOLDOWN_FINISHED(src, strike_timer))
		balloon_alert(user, "ready in [DisplayTimeText(COOLDOWN_TIMELEFT(src, strike_timer))]")
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
	COOLDOWN_START(src, strike_timer, strike_cooldown)
