/**
 * # Medical lab
 *
 * A service room (outpost_service_rooms.dm) with an auto-surgeon slab (outpost_autosurgeon.dm), two
 * lab sleepers and two lab cryo cells on a sealed anaesthetic loop (outpost_medical_lab_machines.dm).
 *
 * Members (the owner, residents and the owner's crews) use it free. Visitors buy a 30 minute pass at
 * the terminal inside the door, keyed to their ckey. The pass gates every machine, never the door:
 * walking in behind someone, or being dragged in, buys nothing. An ownerless outpost's lab is free
 * for everyone.
 */

/datum/map_template/outpost_upgrade/medical_lab
	name = "Outpost Medical Lab"

/datum/map_template/outpost_upgrade/medical_lab/rundown
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_medical_lab_rundown.dmm"
	outpost_style = OUTPOST_STYLE_RUNDOWN

/datum/map_template/outpost_upgrade/medical_lab/clean
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_medical_lab_clean.dmm"
	outpost_style = OUTPOST_STYLE_CLEAN

/datum/outpost_upgrade/service/medical_lab
	id = OUTPOST_MEDICAL_LAB_ID
	name = "Medical Lab"
	desc = "An auto-surgeon, two sleepers and two cryo cells."
	price = OUTPOST_MEDICAL_LAB_COST
	template_type = /datum/map_template/outpost_upgrade/medical_lab
	area_type = /area/voidcrew/player_outpost/service_room/medical_lab
	/// Pass key (ckey) -> list("expiry" = world.time)
	var/list/passes = list()

/datum/outpost_upgrade/service/medical_lab/Destroy()
	passes = null
	return ..()

/**
 * Hooks the loop's canisters to their connector ports. Mapped canisters never connect on their
 * own (players wrench them on), and outpost property cannot be wrenched.
 */
/datum/outpost_upgrade/service/medical_lab/on_service_installed(mob/user)
	for(var/turf/tile as anything in room_turfs())
		for(var/obj/machinery/portable_atmospherics/canister/canister in tile)
			if(canister.connected_port)
				continue
			var/obj/machinery/atmospherics/components/unary/portables_connector/port = locate() in tile
			if(!port || port.connected_device)
				continue
			if(!port.parents[1])
				log_mapping("OUTPOST MEDICAL LAB: [port] at [AREACOORD(port)] had no pipeline at install; [canister] left unconnected")
				// Bolted all the same, so nobody drags it off the outpost (B-25)
				canister.set_anchored(TRUE)
				continue
			canister.connect(port)

// ===== PASSES =====

/// The key a pass is stored under: the ckey, which an SSD or unconscious body still resolves through its mind
/datum/outpost_upgrade/service/medical_lab/proc/pass_key(mob/patient)
	if(!patient)
		return null
	return patient.ckey || ckey(patient.mind?.key)

/// The patient's unexpired pass entry, or null
/datum/outpost_upgrade/service/medical_lab/proc/pass_entry(mob/patient)
	var/key = pass_key(patient)
	if(!key)
		return null
	var/list/entry = passes[key]
	if(!entry)
		return null
	if(world.time >= entry["expiry"])
		passes -= key
		return null
	return entry

/// Seconds left on the patient's pass, 0 without one
/datum/outpost_upgrade/service/medical_lab/proc/pass_seconds_left(mob/patient)
	var/list/entry = pass_entry(patient)
	return entry ? max(0, round((entry["expiry"] - world.time) / (1 SECONDS))) : 0

// A pass holder always reaches the lab they paid for, whatever its entrance is keyed to
/datum/outpost_upgrade/service/medical_lab/admits_visitor_extra(mob/user)
	return !!pass_entry(user)

/// Uses the lab free: an ownerless outpost, or a member
/datum/outpost_upgrade/service/medical_lab/proc/is_exempt(mob/patient)
	if(QDELETED(outpost))
		return FALSE
	return !outpost.founder_ckey || outpost.is_outpost_member(patient)

/// May use the lab's machines now
/datum/outpost_upgrade/service/medical_lab/proc/has_lab_access(mob/patient)
	if(!patient)
		return FALSE
	return is_exempt(patient) || !!pass_entry(patient)

/datum/outpost_upgrade/service/medical_lab/proc/active_pass_count()
	var/count = 0
	for(var/key in passes)
		var/list/entry = passes[key]
		if(world.time < entry["expiry"])
			count++
	return count

/**
 * What the lab could do for this patient now: the enabled procedures the slab would offer, and the
 * sleepers and cryo cells when they have any damage. Empty means a pass would buy nothing.
 */
/datum/outpost_upgrade/service/medical_lab/proc/treatable_list(mob/living/patient)
	var/list/treatable = list()
	if(!iscarbon(patient))
		return treatable
	for(var/procedure_id in GLOB.outpost_autosurgeon_procedures)
		var/datum/autosurgeon_procedure/procedure = GLOB.outpost_autosurgeon_procedures[procedure_id]
		if(!procedure.unavailable_reason(patient))
			treatable += procedure.name
	if(patient.getBruteLoss() > 0 || patient.getFireLoss() > 0 || patient.getToxLoss() > 0 || patient.getOxyLoss() > 0)
		treatable += "Sleepers and cryo"
	return treatable

/// Why this patient cannot get a pass now, or null
/datum/outpost_upgrade/service/medical_lab/proc/pass_denial(mob/living/patient)
	if(!isliving(patient) || !pass_key(patient))
		return "Nobody to issue a pass to."
	if(is_exempt(patient))
		return "[patient] uses the lab free."
	var/seconds_left = pass_seconds_left(patient)
	if(seconds_left * (1 SECONDS) > OUTPOST_MEDLAB_PASS_RENEW_WINDOW)
		return "[patient] has a pass for [DisplayTimeText(seconds_left * (1 SECONDS))] more."
	if(!length(treatable_list(patient)))
		return "The lab has nothing to treat [patient] for."
	return null

/// Issues or renews a pass for a patient
/datum/outpost_upgrade/service/medical_lab/proc/grant_pass(mob/living/patient)
	var/key = pass_key(patient)
	if(!key)
		return FALSE
	passes[key] = list("expiry" = world.time + OUTPOST_MEDLAB_PASS_TIME)
	return TRUE

/**
 * Sells a pass to each patient, paid by `payer` from the ID they present. `shown_fee` is the
 * per-pass fee the payer saw, which is their effective price (0 when free). Passes are charged one
 * at a time, so a payer who runs short keeps the passes already paid for.
 * Never sleeps. Returns null when every pass was issued, else a refusal.
 */
/datum/outpost_upgrade/service/medical_lab/proc/sell_pass(mob/living/payer, list/patients, shown_fee)
	if(QDELETED(src) || QDELETED(outpost) || !installed)
		return "Lab unavailable."
	if(!isliving(payer) || !length(patients))
		return "Nobody to issue a pass to."
	// A member pays nothing, so a member buying for a visitor would hand out free passes
	if(outpost.is_outpost_member(payer) && (length(patients) > 1 || patients[1] != payer))
		return "Members can't buy passes for visitors."
	var/list/seen = list()
	for(var/mob/living/patient as anything in patients)
		if(seen[patient])
			return "Nobody to issue a pass to."
		seen[patient] = TRUE
		var/denial = pass_denial(patient)
		if(denial)
			return denial
	var/listed = outpost.get_price(OUTPOST_PRICE_MEDLAB_PASS)
	var/fee = outpost.service_price_for(payer, listed)
	if(!isnum(shown_fee) || shown_fee != fee)
		return "Price changed to [fee] cr."
	for(var/mob/living/patient as anything in patients)
		if(fee > 0)
			var/refusal = outpost.charge_service(payer, OUTPOST_PRICE_MEDLAB_PASS, listed, fee, "Medical lab pass")
			if(refusal)
				return refusal
		grant_pass(patient)
		log_game("PLAYER OUTPOST: [key_name(payer)] bought a medical lab pass for [key_name(patient)] at '[outpost.name]' for [fee] cr")
	return null

// ===== ADMIN =====

/datum/outpost_upgrade/service/medical_lab/admin_ui_data()
	return list(
		list("label" = "Active passes: [active_pass_count()]", "action" = null, "ref" = null),
		list("label" = "Clear every pass", "action" = "clear_passes", "ref" = null),
	)

/datum/outpost_upgrade/service/medical_lab/admin_ui_act(mob/user, action, list/params)
	if(action != "clear_passes")
		return FALSE
	passes.Cut()
	log_admin("[key_name(user)] cleared every medical lab pass at '[outpost?.name]'")
	return TRUE

// ===== LOOKUPS =====

/// The installed medical lab that `thing` stands in, or null
/proc/outpost_medical_lab_at(atom/thing)
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(thing)
	var/datum/outpost_upgrade/service/medical_lab/lab = home?.service_upgrade(OUTPOST_MEDICAL_LAB_ID)
	if(!istype(lab) || !lab.is_inside(thing))
		return null
	return lab

/// Whether `patient` may be treated by the lab machine `machine`. A machine outside any lab (admin spawned) is free.
/proc/outpost_lab_access(atom/machine, mob/living/patient)
	var/datum/outpost_upgrade/service/medical_lab/lab = outpost_medical_lab_at(machine)
	if(!lab)
		return TRUE
	return lab.has_lab_access(patient)

/// Whether `user` may run the lab machine `machine`'s controls: members only. A machine off any outpost has no owner.
/proc/outpost_lab_staff(atom/machine, mob/user)
	if(!user)
		return FALSE
	if(isAdminGhostAI(user))
		return TRUE
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(machine)
	if(!home)
		return TRUE
	return home.is_outpost_member(user)

// ===== PASS TERMINAL =====

/**
 * Sells lab passes. Using it quotes the price, names the paying account and lists what the lab can
 * treat. A visitor pulling a patient can pay for both.
 */
/obj/machinery/computer/outpost_medlab_terminal
	name = "medical lab pass terminal"
	desc = "Sells passes for the medical lab."
	icon_screen = "crew"
	icon_keyboard = "med_key"
	circuit = null
	use_power = NO_POWER_USE
	/// Ckeys with a prompt open, so a double click cannot stack two purchases
	var/list/prompting = list()

/obj/machinery/computer/outpost_medlab_terminal/singularity_act()
	return 0

/obj/machinery/computer/outpost_medlab_terminal/singularity_pull(atom/singularity, current_size)
	return

/obj/machinery/computer/outpost_medlab_terminal/examine(mob/user)
	. = ..()
	var/datum/outpost_upgrade/service/medical_lab/lab = outpost_medical_lab_at(src)
	if(!lab)
		. += span_notice("It is not connected to a lab.")
		return
	if(lab.is_exempt(user))
		. += span_notice("You use the lab free.")
		return
	var/fee = lab.outpost.service_price_for(user, lab.outpost.get_price(OUTPOST_PRICE_MEDLAB_PASS))
	. += span_notice("A pass costs [fee] cr for [OUTPOST_MEDLAB_PASS_TIME / (1 MINUTES)] minutes.")
	var/seconds_left = lab.pass_seconds_left(user)
	if(seconds_left)
		. += span_notice("Your pass has [DisplayTimeText(seconds_left * (1 SECONDS))] left.")

// A prompt, not a window: skip the computer's ui_interact, which would leave it on active power
/obj/machinery/computer/outpost_medlab_terminal/interact(mob/user)
	if(isliving(user))
		INVOKE_ASYNC(src, PROC_REF(offer_pass), user)
	return TRUE

/// The patient `user` is pulling, when that patient could get a pass
/obj/machinery/computer/outpost_medlab_terminal/proc/pulled_patient(mob/living/user, datum/outpost_upgrade/service/medical_lab/lab)
	var/mob/living/carbon/patient = user.pulling
	if(!istype(patient) || patient == user || !patient.mind)
		return null
	return lab.pass_denial(patient) ? null : patient

/obj/machinery/computer/outpost_medlab_terminal/proc/offer_pass(mob/living/user)
	var/key = user.ckey || REF(user)
	if(prompting[key])
		return
	var/datum/outpost_upgrade/service/medical_lab/lab = outpost_medical_lab_at(src)
	if(!lab)
		balloon_alert(user, "not connected!")
		return
	var/self_denial = lab.pass_denial(user)
	var/mob/living/carbon/patient = pulled_patient(user, lab)
	if(patient && lab.outpost.is_outpost_member(user))
		to_chat(user, span_warning("Members can't buy passes for visitors."))
		return
	if(self_denial && !patient)
		to_chat(user, span_notice(self_denial))
		return
	var/fee = lab.outpost.service_price_for(user, lab.outpost.get_price(OUTPOST_PRICE_MEDLAB_PASS))
	var/minutes = OUTPOST_MEDLAB_PASS_TIME / (1 MINUTES)
	var/list/lines = list()
	if(fee > 0)
		var/account_holder = user.get_idcard(TRUE)?.registered_account?.account_holder
		lines += "Lab pass: [fee] cr for [minutes] minutes, from [account_holder ? "[account_holder]'s account" : "no account"]."
	else
		lines += "Lab pass: free for [minutes] minutes."
	var/list/buttons = list()
	if(self_denial)
		lines += self_denial
	else
		buttons += "Pay"
	if(patient)
		buttons += self_denial ? "Pay for [patient]" : "Pay for both"
	buttons += "Cancel"
	prompting[key] = TRUE
	var/choice = tgui_alert(user, jointext(lines, "\n"), "Medical Lab Pass", buttons)
	prompting -= key
	if(!choice || choice == "Cancel" || QDELETED(src) || QDELETED(user))
		return
	if(!user.can_perform_action(src, ALLOW_RESTING))
		return
	var/list/patients = list()
	if(choice == "Pay" || choice == "Pay for both")
		patients += user
	if(choice != "Pay")
		if(QDELETED(patient) || user.pulling != patient)
			balloon_alert(user, "patient not with you!")
			return
		patients += patient
	var/refusal = lab.sell_pass(user, patients, fee)
	if(refusal)
		to_chat(user, span_warning(refusal))
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)
		return
	playsound(src, 'sound/machines/ping.ogg', 30, TRUE)
	for(var/mob/living/buyer as anything in patients)
		to_chat(buyer, span_notice("Lab pass issued for [minutes] minutes."))
	if(length(patients) > 1 || patients[1] != user)
		to_chat(user, span_notice("You paid for [english_list(patients)]."))
