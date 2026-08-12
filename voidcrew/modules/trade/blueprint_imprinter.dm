/**
 * # Neural Schematic Imprinter
 *
 * The outpost service that converts a physical blueprint into round-long
 * knowledge: feed it the schematic, climb into the cradle, pay the fee, and the
 * recipe is bound to your ckey until the round ends. The scroll is shredded in
 * the process.
 *
 * The trade-off is the point: a physical schematic is shareable, resellable
 * and stealable; an imprint is theft-proof but yours alone, and the paper is
 * gone for good. Fees scale with the schematic's tier.
 *
 * Usage is a chamber flow, like a skillsoft station: slot a schematic into the
 * open cradle, feed it cash if you don't want to pay by ID, then click it to
 * seal yourself in. The imprint UI only opens for the occupant. The fee is
 * drawn from loaded cash first and your bank account for any shortfall; a cash
 * eject button hands back whatever's still loaded as a holochip.
 *
 * Outpost furniture rules apply: indestructible, and attacking it is
 * aggression (resolved through get_trader_outpost_for_turf, like the walls).
 */

#define IMPRINT_FEE_GREEN 750
#define IMPRINT_FEE_YELLOW 1500
#define IMPRINT_FEE_RED 3000

/// How long the imprint channel runs once started, with the occupant sealed in.
#define IMPRINT_WORK_TIME (3 SECONDS)

/obj/machinery/blueprint_imprinter
	name = "neural schematic imprinter"
	desc = "A skull-shaped scanner cradle wired into a schematic shredder. Slot a schematic, climb in, pay the fee, and you'll know the recipe by heart. The shredder isn't optional."
	icon = 'voidcrew/modules/trade/icons/trade.dmi'
	icon_state = "imprinter"
	density = FALSE // Becomes dense only while the cradle is sealed shut
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	occupant_typecache = list(/mob/living/carbon)
	state_open = TRUE
	// Only opens the UI when you're inside; usable while lying down (paraplegics etc.)
	interaction_flags_atom = parent_type::interaction_flags_atom | INTERACT_ATOM_IGNORE_MOBILITY
	/// The schematic currently slotted into the cradle, awaiting imprint.
	var/obj/item/blueprint/inserted_blueprint
	/// Physical credits loaded into the machine, spent before the bank account.
	var/loaded_credits = 0
	/// Whether an imprint channel is currently running.
	var/working = FALSE
	/// Timer handle for the running imprint channel.
	var/work_timer

/obj/machinery/blueprint_imprinter/Initialize(mapload)
	. = ..()
	update_appearance()

/obj/machinery/blueprint_imprinter/Destroy()
	inserted_blueprint = null
	return ..()

/obj/machinery/blueprint_imprinter/examine(mob/user)
	. = ..()
	. += span_notice("Imprint fees: [IMPRINT_FEE_GREEN] cr (green-tier) / [IMPRINT_FEE_YELLOW] cr (yellow-tier) / [IMPRINT_FEE_RED] cr (red-tier). Load cash into the cradle or pay by ID; the schematic is shredded.")
	. += span_notice("An imprint lasts the rest of the round and nobody can steal it. The paper copy could have been sold instead.")
	if(loaded_credits)
		. += span_notice("Cradle holds <b>[loaded_credits] cr</b> in loaded cash.")
	var/list/known = get_user_imprints(user)
	if(length(known))
		. += span_notice("You hold neural imprints for: <b>[known.Join(", ")]</b>.")

/**
 * Names of everything this user has imprinted, for examine.
 */
/obj/machinery/blueprint_imprinter/proc/get_user_imprints(mob/user)
	var/list/names = list()
	if(!user?.ckey)
		return names
	var/list/imprints = GLOB.blueprint_imprints[user.ckey]
	if(!length(imprints))
		return names
	for(var/datum/crafting_recipe/recipe as anything in GLOB.crafting_recipes)
		if(recipe.type in imprints)
			names += recipe.name
	return names

/// The imprint fee for a given schematic's tier.
/obj/machinery/blueprint_imprinter/proc/get_fee(obj/item/blueprint/print)
	switch(print?.tier)
		if(BLUEPRINT_TIER_GREEN)
			return IMPRINT_FEE_GREEN
		if(BLUEPRINT_TIER_RED)
			return IMPRINT_FEE_RED
	return IMPRINT_FEE_YELLOW

// --- Icon ---------------------------------------------------------------

/obj/machinery/blueprint_imprinter/update_icon_state()
	icon_state = initial(icon_state)
	if(state_open)
		icon_state += "_open"
	if(occupant)
		icon_state += "_occupied"
	return ..()

/obj/machinery/blueprint_imprinter/update_overlays()
	. = ..()
	if(working)
		. += "working"

// --- Occupancy / cradle plumbing ---------------------------------------

//Only usable by the person inside
/obj/machinery/blueprint_imprinter/ui_state(mob/user)
	return GLOB.contained_state

/obj/machinery/blueprint_imprinter/relaymove(mob/living/user, direction)
	open_machine()

// The cradle has no lock; resisting pops the door without having to walk out.
/obj/machinery/blueprint_imprinter/container_resist_act(mob/living/user)
	open_machine()

/obj/machinery/blueprint_imprinter/open_machine(drop = TRUE, density_to_set = FALSE)
	interrupt_operation()
	// Hand back any loaded cash as a holochip so nothing gets trapped when the
	// cradle opens; the schematic drops with the rest of the contents.
	eject_cash()
	return ..()

/obj/machinery/blueprint_imprinter/close_machine(atom/movable/target, density_to_set = TRUE)
	. = ..()
	if(occupant)
		ui_interact(occupant)

/obj/machinery/blueprint_imprinter/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == inserted_blueprint)
		inserted_blueprint = null
		interrupt_operation()

/obj/machinery/blueprint_imprinter/power_change()
	. = ..()
	if(working && !is_operational)
		interrupt_operation()

/obj/machinery/blueprint_imprinter/proc/toggle_open(mob/user)
	state_open ? close_machine() : open_machine()

/obj/machinery/blueprint_imprinter/proc/interrupt_operation()
	working = FALSE
	if(work_timer)
		deltimer(work_timer)
		work_timer = null
	update_appearance()

/obj/machinery/blueprint_imprinter/interact(mob/user)
	. = ..()
	if(user == occupant)
		ui_interact(user)
	else
		toggle_open(user)

/obj/machinery/blueprint_imprinter/attackby(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(istype(attacking_item, /obj/item/blueprint))
		insert_blueprint(attacking_item, user)
		return TRUE
	if(iscash(attacking_item))
		load_cash(attacking_item, user)
		return TRUE
	return ..()

/// Slot a schematic into the cradle.
/obj/machinery/blueprint_imprinter/proc/insert_blueprint(obj/item/blueprint/print, mob/living/user)
	if(inserted_blueprint)
		balloon_alert(user, "already loaded!")
		return
	if(!print.recipe_type)
		balloon_alert(user, "unreadable schematic!")
		return
	if(!user.transferItemToLoc(print, src))
		return
	inserted_blueprint = print
	balloon_alert(user, "schematic loaded")
	SStgui.update_uis(src)

/// Feed physical currency into the cradle's cash reserve.
/obj/machinery/blueprint_imprinter/proc/load_cash(obj/item/money, mob/living/user)
	var/value = money.get_item_credit_value()
	if(!value)
		balloon_alert(user, "no value!")
		return
	loaded_credits += value
	qdel(money)
	balloon_alert(user, "loaded [value] cr")
	playsound(src, 'sound/effects/cashregister.ogg', 40, TRUE)
	SStgui.update_uis(src)

/// Hand back all loaded cash as a holochip.
/obj/machinery/blueprint_imprinter/proc/eject_cash(mob/living/to_hands)
	if(loaded_credits <= 0)
		return
	var/obj/item/holochip/chip = new(drop_location(), loaded_credits)
	loaded_credits = 0
	if(to_hands)
		to_hands.put_in_hands(chip)
	SStgui.update_uis(src)

/// Pop the slotted schematic back out.
/obj/machinery/blueprint_imprinter/proc/eject_blueprint(mob/living/to_hands)
	if(!inserted_blueprint)
		return
	var/obj/item/blueprint/print = inserted_blueprint
	inserted_blueprint = null
	interrupt_operation()
	if(to_hands)
		to_hands.put_in_hands(print)
	else
		print.forceMove(drop_location())
	SStgui.update_uis(src)

/obj/machinery/blueprint_imprinter/dump_contents()
	. = ..()
	inserted_blueprint = null

// --- Imprint channel ---------------------------------------------------

/// Begin the imprint channel. Assumes the occupant, schematic and funds have
/// already been validated by ui_act.
/obj/machinery/blueprint_imprinter/proc/start_imprint()
	working = TRUE
	work_timer = addtimer(CALLBACK(src, PROC_REF(finish_imprint)), IMPRINT_WORK_TIME, TIMER_STOPPABLE)
	balloon_alert(occupant, "imprinting...")
	update_appearance()

/// Complete the imprint: re-validate, charge, bind the recipe and shred the scroll.
/obj/machinery/blueprint_imprinter/proc/finish_imprint()
	working = FALSE
	work_timer = null
	update_appearance()

	var/mob/living/carbon/carbon_occupant = occupant
	if(!istype(carbon_occupant) || !carbon_occupant.ckey)
		return
	if(QDELETED(inserted_blueprint))
		return
	var/obj/item/blueprint/print = inserted_blueprint

	var/list/imprints = GLOB.blueprint_imprints[carbon_occupant.ckey]
	if(imprints && (print.recipe_type in imprints))
		balloon_alert(carbon_occupant, "already imprinted!")
		return

	var/fee = get_fee(print)
	if(!charge_fee(carbon_occupant, fee, print.schematic_name))
		balloon_alert(carbon_occupant, "payment failed!")
		return

	LAZYINITLIST(GLOB.blueprint_imprints[carbon_occupant.ckey])
	GLOB.blueprint_imprints[carbon_occupant.ckey] |= print.recipe_type

	playsound(src, 'sound/machines/ping.ogg', 50, TRUE)
	carbon_occupant.visible_message(
		span_notice("[src] scans [carbon_occupant] and shreds [print] into confetti."),
		span_notice("Cold light sweeps across your skull. You know the [print.schematic_name] by heart now, and the schematic is confetti."),
	)
	inserted_blueprint = null
	qdel(print)
	SStgui.update_uis(src)

/// Draw a fee from loaded cash first, then the occupant's bank account for any
/// shortfall. Returns TRUE only if the whole fee was covered and charged.
/obj/machinery/blueprint_imprinter/proc/charge_fee(mob/living/carbon/user, fee, schematic_name)
	var/from_cash = min(loaded_credits, fee)
	var/remainder = fee - from_cash
	if(remainder > 0)
		var/obj/item/card/id/id_card = user.get_idcard(TRUE)
		var/datum/bank_account/account = id_card?.registered_account
		if(!account || !account.has_money(remainder))
			return FALSE
		if(!account.adjust_money(-remainder, "Neural Imprint: [schematic_name]"))
			return FALSE
	loaded_credits -= from_cash
	return TRUE

// --- UI ----------------------------------------------------------------

/obj/machinery/blueprint_imprinter/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "BlueprintImprinter", name)
		ui.open()

/obj/machinery/blueprint_imprinter/ui_data(mob/user)
	var/list/data = list()
	data["working"] = working
	data["timeleft"] = work_timer ? timeleft(work_timer) : null
	data["loaded_credits"] = loaded_credits

	var/mob/living/carbon/carbon_occupant = occupant
	data["has_occupant"] = istype(carbon_occupant)

	var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
	data["barred"] = outpost?.is_user_barred(carbon_occupant) ? TRUE : FALSE

	var/datum/bank_account/account
	if(istype(carbon_occupant))
		var/obj/item/card/id/id_card = carbon_occupant.get_idcard(TRUE)
		account = id_card?.registered_account
	data["account_credits"] = account ? account.account_balance : null

	data["blueprint_ready"] = inserted_blueprint ? TRUE : FALSE
	if(inserted_blueprint)
		var/fee = get_fee(inserted_blueprint)
		data["schematic_name"] = inserted_blueprint.schematic_name
		data["tier"] = inserted_blueprint.tier
		data["fee"] = fee
		var/already_known = FALSE
		if(carbon_occupant?.ckey)
			var/list/imprints = GLOB.blueprint_imprints[carbon_occupant.ckey]
			already_known = imprints && (inserted_blueprint.recipe_type in imprints)
		data["already_known"] = already_known
		data["can_afford"] = (loaded_credits + (account ? account.account_balance : 0)) >= fee
	return data

/obj/machinery/blueprint_imprinter/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(usr != occupant)
		return
	switch(action)
		if("imprint")
			if(working)
				return TRUE
			if(!inserted_blueprint)
				balloon_alert(usr, "no schematic!")
				return TRUE
			var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
			if(outpost?.is_user_barred(usr))
				outpost.trader?.speak_line(TRADER_LINE_REFUSAL)
				balloon_alert(usr, "trade embargo!")
				return TRUE
			var/mob/living/carbon/carbon_occupant = occupant
			if(!istype(carbon_occupant) || !carbon_occupant.ckey)
				return TRUE
			var/list/imprints = GLOB.blueprint_imprints[carbon_occupant.ckey]
			if(imprints && (inserted_blueprint.recipe_type in imprints))
				balloon_alert(usr, "already imprinted!")
				return TRUE
			var/fee = get_fee(inserted_blueprint)
			var/obj/item/card/id/id_card = carbon_occupant.get_idcard(TRUE)
			var/datum/bank_account/account = id_card?.registered_account
			if((loaded_credits + (account ? account.account_balance : 0)) < fee)
				balloon_alert(usr, "needs [fee] cr!")
				return TRUE
			start_imprint()
			return TRUE
		if("eject_blueprint")
			if(working)
				return TRUE
			eject_blueprint(occupant)
			return TRUE
		if("eject_cash")
			if(working)
				return TRUE
			eject_cash(occupant)
			return TRUE
		if("open_door")
			open_machine()
			return TRUE

// --- Outpost aggression -------------------------------------------------

// Attacking outpost property is aggression, imprinter included
/obj/machinery/blueprint_imprinter/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force && !istype(attacking_item, /obj/item/blueprint) && !iscash(attacking_item))
		var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
		outpost?.register_aggression(user)
	return ..()

/obj/machinery/blueprint_imprinter/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	if(isliving(hitting_projectile.firer))
		var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
		outpost?.register_aggression(hitting_projectile.firer)
	return ..()

#undef IMPRINT_FEE_GREEN
#undef IMPRINT_FEE_YELLOW
#undef IMPRINT_FEE_RED
#undef IMPRINT_WORK_TIME
