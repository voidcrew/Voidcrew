/**
 * # Medical lab machines
 *
 * The lab's sleepers, cryo cells and the sealed anaesthetic loop behind the cells. All of them
 * check the patient's lab pass (outpost_medical_lab.dm) and keep their controls to members, with
 * the occupant always able to get out. Controls means every route: the tgui window, alt- and
 * ctrl-clicks, and items used on the machine.
 */

/// Tells a non-member they cannot use this lab control. TRUE when refused.
/proc/outpost_lab_refuse(atom/machine, mob/user)
	if(outpost_lab_staff(machine, user))
		return FALSE
	if(user)
		machine.balloon_alert(user, "staff only!")
	return TRUE

// ===== LAB SLEEPER =====

/**
 * The trader outpost sleeper (controls inside, no power) without morphine, its one sedative.
 * Only the occupant or a member injects, and only into an occupant with lab access. No emag.
 */
/obj/machinery/sleeper/outpost/medical_lab
	name = "lab sleeper"
	desc = "A sleeper bolted into the lab floor."
	possible_chems = list(
		list(
			/datum/reagent/medicine/epinephrine,
			/datum/reagent/medicine/c2/convermol,
			/datum/reagent/medicine/c2/libital,
			/datum/reagent/medicine/c2/aiuri,
		),
		list(
			/datum/reagent/medicine/oculine,
			/datum/reagent/medicine/inacusiate,
		),
		list(
			/datum/reagent/medicine/c2/multiver,
			/datum/reagent/medicine/mutadone,
			/datum/reagent/medicine/mannitol,
			/datum/reagent/medicine/salbutamol,
			/datum/reagent/medicine/pen_acid,
		),
		list(
			/datum/reagent/medicine/omnizine,
		),
	)

/obj/machinery/sleeper/outpost/medical_lab/singularity_act()
	return 0

/obj/machinery/sleeper/outpost/medical_lab/singularity_pull(atom/singularity, current_size)
	return

/obj/machinery/sleeper/outpost/medical_lab/examine(mob/user)
	. = ..()
	if(!outpost_lab_access(src, user))
		. += span_notice("It needs a lab pass.")

/obj/machinery/sleeper/outpost/medical_lab/inject_chem(chem, mob/user)
	if(user && user != occupant && !outpost_lab_staff(src, user))
		balloon_alert(user, "occupant or staff only!")
		return FALSE
	if(!outpost_lab_access(src, occupant))
		if(user)
			balloon_alert(user, "no lab pass!")
		return FALSE
	return ..()

/obj/machinery/sleeper/outpost/medical_lab/emag_act(mob/user, obj/item/card/emag/emag_card)
	if(user)
		balloon_alert(user, "no effect!")
	return FALSE

/// Why `user` cannot open or close the sleeper now, or null. Members may; the occupant may get out.
/obj/machinery/sleeper/outpost/medical_lab/proc/door_denial(mob/user)
	if(!state_open && user && user == occupant)
		return null
	if(outpost_lab_staff(src, user))
		return null
	return "staff only!"

/obj/machinery/sleeper/outpost/medical_lab/click_alt(mob/user)
	var/denial = door_denial(user)
	if(denial)
		balloon_alert(user, denial)
		return CLICK_ACTION_BLOCKING
	return ..()

/obj/machinery/sleeper/outpost/medical_lab/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(action == "door")
		var/denial = door_denial(ui.user)
		if(denial)
			balloon_alert(ui.user, denial)
			return TRUE
	return ..()

// Dragging someone in heals nothing without their pass, so it is refused up front
/obj/machinery/sleeper/outpost/medical_lab/mouse_drop_receive(atom/target, mob/user, params)
	if(isliving(target) && !outpost_lab_access(src, target))
		balloon_alert(user, "no lab pass!")
		return
	return ..()

// ===== LAB CRYO CELL =====

/**
 * A cryo cell a lone visitor can use: it takes a conscious patient who climbs in, always ejects
 * (autoeject cannot be switched off), ejects when switched off, after OUTPOST_LAB_CRYO_MAX_STAY,
 * and when its cryoxadone runs out. Patients without lab access are put straight back out.
 * Only members switch it, open it on others, or touch its beaker.
 */
/obj/machinery/cryo_cell/outpost_lab
	name = "lab cryo cell"
	desc = "A cryo cell on the lab's anaesthetic loop."
	autoeject = TRUE
	/// world.time the current occupant was closed in
	var/entered_at = 0
	/// TRUE while open_machine() runs. It switches the cell off, and the switch-off must not open it again.
	var/opening = FALSE

/obj/machinery/cryo_cell/outpost_lab/Initialize(mapload)
	. = ..()
	if(!beaker)
		beaker = new /obj/item/reagent_containers/cup/beaker/cryoxadone(src)
	RegisterSignal(src, COMSIG_CRYO_SET_ON, PROC_REF(on_cryo_set_on))
	// Open and waiting: visitors cannot work the door, so an empty cell must be ready to climb into
	if(!occupant)
		open_machine()

/obj/machinery/cryo_cell/outpost_lab/singularity_act()
	return 0

/obj/machinery/cryo_cell/outpost_lab/singularity_pull(atom/singularity, current_size)
	return

/obj/machinery/cryo_cell/outpost_lab/examine(mob/user)
	. = ..()
	if(!outpost_lab_access(src, user))
		. += span_notice("It needs a lab pass.")

/// Whether the beaker can still treat anyone
/obj/machinery/cryo_cell/outpost_lab/proc/has_cryoxadone()
	return !QDELETED(beaker) && beaker.reagents?.has_reagent(/datum/reagent/medicine/cryoxadone)

/// Why the occupant may not stay in, or null
/obj/machinery/cryo_cell/outpost_lab/proc/stay_denial()
	var/mob/living/patient = occupant
	if(!patient)
		return null
	if(!outpost_lab_access(src, patient))
		return "No lab pass."
	if(!has_cryoxadone())
		return "The cell has no cryoxadone left."
	if(entered_at && world.time >= entered_at + OUTPOST_LAB_CRYO_MAX_STAY)
		return "The cycle is over."
	return null

/// Opens the cell on its occupant, telling them why
/obj/machinery/cryo_cell/outpost_lab/proc/eject_patient(reason)
	if(state_open || opening || !occupant)
		return
	var/mob/living/patient = occupant
	open_machine()
	if(reason && patient)
		to_chat(patient, span_notice(reason))

/// Switched off with someone inside (power loss, a member, the stock shutdowns): let them out.
/obj/machinery/cryo_cell/outpost_lab/proc/on_cryo_set_on(datum/source, active)
	SIGNAL_HANDLER
	// set_on() signals before it sets `on`, so an eject from here would switch off, signal and eject
	// again without end. That recursion crashed the server; open_machine() is already letting them out.
	if(active || state_open || opening || !occupant)
		return
	INVOKE_ASYNC(src, PROC_REF(eject_patient), "The cryo cell switched off.")

/obj/machinery/cryo_cell/outpost_lab/close_machine(mob/living/carbon/user, density_to_set = TRUE)
	. = ..()
	if(!occupant)
		return
	entered_at = world.time
	var/denial = stay_denial()
	if(denial)
		eject_patient(denial)

/obj/machinery/cryo_cell/outpost_lab/open_machine(drop = TRUE, density_to_set = FALSE)
	entered_at = 0
	opening = TRUE
	. = ..()
	opening = FALSE

/obj/machinery/cryo_cell/outpost_lab/process(seconds_per_tick)
	if(on && occupant)
		var/denial = stay_denial()
		if(denial)
			eject_patient(denial)
			return PROCESS_KILL
	return ..()

/obj/machinery/cryo_cell/outpost_lab/ui_act(action, params, datum/tgui/ui, datum/ui_state/state)
	switch(action)
		if("autoeject")
			balloon_alert(ui.user, "always on!")
			return TRUE
		if("door", "power", "eject")
			if(outpost_lab_refuse(src, ui.user))
				return TRUE
	return ..()

/obj/machinery/cryo_cell/outpost_lab/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/reagent_containers/cup) && outpost_lab_refuse(src, user))
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/machinery/cryo_cell/outpost_lab/click_ctrl(mob/user)
	if(outpost_lab_refuse(src, user))
		return CLICK_ACTION_BLOCKING
	return ..()

/obj/machinery/cryo_cell/outpost_lab/click_alt(mob/user)
	// The occupant can always open their own cell
	if(user == occupant)
		if(!state_open)
			open_machine()
		return CLICK_ACTION_SUCCESS
	if(outpost_lab_refuse(src, user))
		return CLICK_ACTION_BLOCKING
	return ..()

/**
 * The stock cell only takes patients who cannot move. This one also takes a conscious patient
 * climbing in on their own, which is how a visitor alone uses it.
 */
/obj/machinery/cryo_cell/outpost_lab/mouse_drop_receive(mob/target, mob/user, params)
	if(!iscarbon(target) || !state_open || occupant)
		return
	if(!outpost_lab_access(src, target))
		balloon_alert(user, "no lab pass!")
		return
	if(target == user)
		INVOKE_ASYNC(src, PROC_REF(self_enter), target)
		return
	return ..()

/obj/machinery/cryo_cell/outpost_lab/proc/self_enter(mob/living/carbon/patient)
	if(patient.incapacitated)
		return
	patient.visible_message(span_notice("[patient] starts climbing into [src]."), span_notice("You start climbing into [src]."))
	if(!do_after(patient, OUTPOST_LAB_CRYO_ENTRY_TIME, target = src))
		return
	if(!state_open || occupant || !patient.Adjacent(src) || patient.buckled)
		return
	close_machine(patient)

// ===== ANAESTHETIC LOOP =====
// The loop's canisters, freezer and filter answer to members only. The element already stops
// wrenches, so the canisters stay on their ports.

/obj/machinery/portable_atmospherics/canister/anesthetic_mix/outpost_lab
	name = "lab anaesthetic canister"
	desc = "Feeds the lab's cryo loop with an anaesthetic mix."
	flags_1 = parent_type::flags_1 | NO_NEW_GAGS_PREVIEW_1

/obj/machinery/portable_atmospherics/canister/anesthetic_mix/outpost_lab/singularity_act()
	return 0

/obj/machinery/portable_atmospherics/canister/anesthetic_mix/outpost_lab/singularity_pull(atom/singularity, current_size)
	return

/obj/machinery/portable_atmospherics/canister/anesthetic_mix/outpost_lab/ui_status(mob/user, datum/ui_state/state)
	. = ..()
	if(!outpost_lab_staff(src, user))
		. = min(., UI_UPDATE)

/obj/machinery/portable_atmospherics/canister/anesthetic_mix/outpost_lab/click_alt(mob/living/user)
	if(outpost_lab_refuse(src, user))
		return CLICK_ACTION_BLOCKING
	return ..()

/obj/machinery/portable_atmospherics/canister/anesthetic_mix/outpost_lab/attackby(obj/item/item, mob/user, list/modifiers, list/attack_modifiers)
	if((istype(item, /obj/item/tank) || istype(item, /obj/item/stock_parts/power_store)) && outpost_lab_refuse(src, user))
		return TRUE
	return ..()

/// Takes the CO2 the loop's filter pulls out of it
/obj/machinery/portable_atmospherics/canister/outpost_lab_drain
	name = "lab drain canister"
	desc = "Collects the carbon dioxide filtered out of the lab's cryo loop."
	flags_1 = parent_type::flags_1 | NO_NEW_GAGS_PREVIEW_1

/obj/machinery/portable_atmospherics/canister/outpost_lab_drain/singularity_act()
	return 0

/obj/machinery/portable_atmospherics/canister/outpost_lab_drain/singularity_pull(atom/singularity, current_size)
	return

/obj/machinery/portable_atmospherics/canister/outpost_lab_drain/ui_status(mob/user, datum/ui_state/state)
	. = ..()
	if(!outpost_lab_staff(src, user))
		. = min(., UI_UPDATE)

/obj/machinery/portable_atmospherics/canister/outpost_lab_drain/click_alt(mob/living/user)
	if(outpost_lab_refuse(src, user))
		return CLICK_ACTION_BLOCKING
	return ..()

/obj/machinery/portable_atmospherics/canister/outpost_lab_drain/attackby(obj/item/item, mob/user, list/modifiers, list/attack_modifiers)
	if((istype(item, /obj/item/tank) || istype(item, /obj/item/stock_parts/power_store)) && outpost_lab_refuse(src, user))
		return TRUE
	return ..()

/obj/machinery/atmospherics/components/unary/thermomachine/freezer/on/outpost_lab
	name = "lab cryo freezer"
	flags_1 = parent_type::flags_1 | NO_NEW_GAGS_PREVIEW_1

/obj/machinery/atmospherics/components/unary/thermomachine/freezer/on/outpost_lab/singularity_act()
	return 0

/obj/machinery/atmospherics/components/unary/thermomachine/freezer/on/outpost_lab/singularity_pull(atom/singularity, current_size)
	return

/obj/machinery/atmospherics/components/unary/thermomachine/freezer/on/outpost_lab/ui_status(mob/user, datum/ui_state/state)
	. = ..()
	if(!outpost_lab_staff(src, user))
		. = min(., UI_UPDATE)

/obj/machinery/atmospherics/components/unary/thermomachine/freezer/on/outpost_lab/click_alt(mob/living/user)
	if(outpost_lab_refuse(src, user))
		return CLICK_ACTION_BLOCKING
	return ..()

/obj/machinery/atmospherics/components/unary/thermomachine/freezer/on/outpost_lab/click_ctrl(mob/user)
	if(outpost_lab_refuse(src, user))
		return CLICK_ACTION_BLOCKING
	return ..()

/obj/machinery/atmospherics/components/trinary/filter/atmos/co2/outpost_lab
	name = "lab carbon dioxide filter"

/obj/machinery/atmospherics/components/trinary/filter/atmos/co2/outpost_lab/singularity_act()
	return 0

/obj/machinery/atmospherics/components/trinary/filter/atmos/co2/outpost_lab/singularity_pull(atom/singularity, current_size)
	return

/obj/machinery/atmospherics/components/trinary/filter/atmos/co2/outpost_lab/ui_status(mob/user, datum/ui_state/state)
	. = ..()
	if(!outpost_lab_staff(src, user))
		. = min(., UI_UPDATE)

/obj/machinery/atmospherics/components/trinary/filter/atmos/co2/outpost_lab/click_alt(mob/user)
	if(outpost_lab_refuse(src, user))
		return CLICK_ACTION_BLOCKING
	return ..()

/obj/machinery/atmospherics/components/trinary/filter/atmos/co2/outpost_lab/click_ctrl(mob/user)
	if(outpost_lab_refuse(src, user))
		return CLICK_ACTION_BLOCKING
	return ..()
