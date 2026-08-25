/**
 * # Drug lab machines
 *
 * The three production stations inside the hidden lab ruin. Each hosts one
 * stage of the cook as a TGUI minigame; batch state lives on the mission's
 * lab session (lab_session.dm), the machines are stateless views onto it.
 *
 * The cook objective wires session_ref when the ruin interior loads
 * (objectives.dm, wire_lab()); an unwired machine shows a dormant UI. All
 * three run NO_POWER_USE because the ruin has no APC, powered() short-
 * circuits TRUE for unpowered machines, so machine_stat never gains NOPOWER
 * and can_interact()/TGUI work in the dead area with no extra flags.
 */
/obj/machinery/drug_lab
	name = "lab machine"
	desc = "A grimy piece of clandestine chemistry equipment."
	icon = 'voidcrew/modules/drug_smuggling/icons/drug_lab.dmi'
	icon_state = "mixer"
	density = TRUE
	use_power = NO_POWER_USE
	/// DRUG_STATION_* index this machine runs
	var/station_index
	/// TGUI interface this station opens (every concrete subtype sets one)
	var/tgui_interface
	/// Weakref to the live cook session (set by the cook objective's wire_lab())
	var/datum/weakref/session_ref

/obj/machinery/drug_lab/Destroy()
	var/datum/drug_lab_session/session = session_ref?.resolve()
	session?.unregister_machine(src)
	session_ref = null
	return ..()

/// The live session this machine views, or null while dormant
/obj/machinery/drug_lab/proc/resolve_session()
	var/datum/drug_lab_session/session = session_ref?.resolve()
	if(QDELETED(session))
		return null
	return session

/// Whether this station is the batch's current live stage
/obj/machinery/drug_lab/proc/is_live_station(datum/drug_lab_session/session)
	if(!session)
		session = resolve_session()
	if(!session)
		return FALSE
	switch(station_index)
		if(DRUG_STATION_MIXER)
			// The mixer hosts both hopper loading and its own minigame
			return (session.stage == DRUG_LAB_STAGE_LOADING) || (session.stage == DRUG_LAB_STAGE_MIXER)
		if(DRUG_STATION_CATALYST)
			return session.stage == DRUG_LAB_STAGE_CATALYST
		if(DRUG_STATION_CRYSTALLIZER)
			return session.stage == DRUG_LAB_STAGE_CRYSTALLIZER
	return FALSE

/obj/machinery/drug_lab/update_icon_state()
	icon_state = is_live_station() ? "[base_icon_state]_active" : base_icon_state
	return ..()

/obj/machinery/drug_lab/examine(mob/user)
	. = ..()
	var/datum/drug_lab_session/session = resolve_session()
	if(!session)
		. += span_warning("Its console idles on a lock screen. Without an authenticated formula, it's just furniture.")
		return
	if(is_live_station(session))
		. += span_boldnotice("The console is live. This is the batch's current station.")
	else
		. += span_notice("The console is tracking the batch, waiting for its stage to come up.")

// --- TGUI ----------------------------------------------------------------

/obj/machinery/drug_lab/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, tgui_interface, name)
		ui.open()

/obj/machinery/drug_lab/ui_data(mob/user)
	var/datum/drug_lab_session/session = resolve_session()
	if(!session)
		return list(
			"dormant" = TRUE,
			"station" = station_index,
		)
	var/list/data = session.ui_data_for(station_index)
	data["dormant"] = FALSE
	data["is_live"] = is_live_station(session)
	return data

/obj/machinery/drug_lab/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/datum/drug_lab_session/session = resolve_session()
	if(!session)
		return TRUE
	switch(action)
		if("start_attempt")
			switch(station_index)
				if(DRUG_STATION_MIXER)
					session.mixer_start_attempt(ui.user)
				if(DRUG_STATION_CATALYST)
					session.catalyst_start_attempt(ui.user)
				if(DRUG_STATION_CRYSTALLIZER)
					session.crystallizer_start_attempt(ui.user)
			return TRUE
		if("commit")
			switch(station_index)
				if(DRUG_STATION_MIXER)
					session.mixer_commit(ui.user)
				if(DRUG_STATION_CATALYST)
					session.catalyst_commit(ui.user)
				if(DRUG_STATION_CRYSTALLIZER)
					session.crystallizer_commit(ui.user)
			return TRUE
		if("press")
			if(station_index != DRUG_STATION_MIXER)
				return TRUE
			session.mixer_press(params["index"], ui.user)
			return TRUE
		if("catalyst_finish")
			if(station_index != DRUG_STATION_CATALYST)
				return TRUE
			session.catalyst_finish(params["nonce"], params["perfects"], params["goods"], params["misses"], ui.user)
			return TRUE
		if("crystallizer_finish")
			if(station_index != DRUG_STATION_CRYSTALLIZER)
				return TRUE
			session.crystallizer_finish(params["nonce"], params["caught_pure"], params["caught_tainted"], params["missed_pure"], ui.user)
			return TRUE

/**
 * Botch fallout dispatcher: the session calls this when a catalyst or
 * crystallizer attempt lands under DRUG_HAZARD_BOTCH_SCORE. `harsher` marks a
 * retry taken right after a botch: pushing a curdled batch again is asking
 * for it, so overrides may widen their nastiest band. The mixer keeps its own
 * run_hazard() (its finish path predates this hook).
 */
/obj/machinery/drug_lab/proc/run_botch_hazard(mob/user, harsher = FALSE)
	return

// =========================================================================
// THE MIXER: hopper loading, the Simon minigame, and the botch hazard
// =========================================================================

/obj/machinery/drug_lab/mixer
	name = "industrial mixer"
	desc = "A hopper-fed mixing vat crusted with residue nobody wants tested. The first stop for raw precursors."
	icon_state = "mixer"
	base_icon_state = "mixer"
	station_index = DRUG_STATION_MIXER
	tgui_interface = "DrugLabMixer"

/obj/machinery/drug_lab/mixer/attackby(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(istype(attacking_item, /obj/item/drug_ingredient))
		var/datum/drug_lab_session/session = resolve_session()
		if(!session)
			balloon_alert(user, "console locked!")
			return TRUE
		session.bank_ingredient(attacking_item, user)
		return TRUE
	return ..()

/**
 * A botched mixer attempt has consequences: always sparks, and one d100 roll
 * against the hazard defines, low band ignites the housing, middle band vents
 * a caustic acid cloud over the machine (and whoever is working it). The batch
 * itself is never harmed; the score already was the punishment.
 */
/obj/machinery/drug_lab/mixer/proc/run_hazard(mob/user)
	var/turf/here = get_turf(src)
	if(!here)
		return
	do_sparks(3, FALSE, src)
	var/roll = rand(1, 100)
	if(roll <= DRUG_HAZARD_FIRE_CHANCE)
		visible_message(span_danger("[src] backfires, burning residue spatters across its housing!"))
		new /obj/effect/hotspot(here)
		return
	if(roll <= DRUG_HAZARD_FIRE_CHANCE + DRUG_HAZARD_FUME_CHANCE)
		visible_message(span_danger("[src] belches a cloud of caustic vapor!"))
		do_chem_smoke(range = 1, holder = src, location = here, reagent_type = /datum/reagent/toxin/acid, reagent_volume = DRUG_HAZARD_FUME_VOLUME)
		return
	visible_message(span_warning("[src] shrieks and rattles as the batch curdles inside it."))

// =========================================================================
// THE CATALYST COLUMN: the rhythm game and its electrical botch hazard
// =========================================================================

/obj/machinery/drug_lab/catalyst
	name = "catalyst column"
	desc = "A reaction column of four scarred glass tubes. The gauges are annotated in grease pencil and profanity."
	icon_state = "catalyst"
	base_icon_state = "catalyst"
	station_index = DRUG_STATION_CATALYST
	tgui_interface = "DrugLabCatalyst"

/**
 * A botched catalysis run is an ELECTRICAL problem: always sparks, one
 * exclusive d100 against the shared hazard bands, low band dumps the
 * capacitor bank through whoever is on the controls (gloves and clothing
 * conduct normally; the numbers are a nasty jolt, nowhere near lethal from
 * health), middle band arcs a spark shower over every adjacent mob. The
 * batch itself is never harmed; the score already was the punishment.
 */
/obj/machinery/drug_lab/catalyst/run_botch_hazard(mob/user, harsher = FALSE)
	var/turf/here = get_turf(src)
	if(!here)
		return
	do_sparks(3, FALSE, src)
	var/roll = rand(1, 100)
	if(roll <= DRUG_HAZARD_FIRE_CHANCE)
		visible_message(span_danger("[src]'s capacitor bank dumps its charge through the control panel!"))
		playsound(src, 'sound/effects/magic/lightningshock.ogg', 60, TRUE)
		if(isliving(user) && in_range(src, user))
			var/mob/living/victim = user
			victim.electrocute_act(DRUG_HAZARD_SHOCK_DAMAGE, src)
		return
	if(roll <= DRUG_HAZARD_FIRE_CHANCE + DRUG_HAZARD_FUME_CHANCE)
		visible_message(span_danger("[src] arcs wildly, spitting sparks across the deck!"))
		playsound(src, 'sound/machines/defib/defib_zap.ogg', 60, TRUE)
		for(var/mob/living/bystander in range(1, src))
			do_sparks(2, TRUE, bystander)
		return
	visible_message(span_warning("[src] hums up an octave, then settles. The batch inside smells scorched."))

// =========================================================================
// THE CRYSTALLIZER: the catch game and its thermal botch hazard
// =========================================================================

/obj/machinery/drug_lab/crystallizer
	name = "crystallization chamber"
	desc = "A glass-domed growth chamber with seals yellowed by age. This is where the batch becomes product, or evidence."
	icon_state = "crystallizer"
	base_icon_state = "crystallizer"
	station_index = DRUG_STATION_CRYSTALLIZER
	tgui_interface = "DrugLabCrystallizer"

/**
 * A botched crystallization is a THERMAL problem: always sparks, one
 * exclusive d100, low band over-pressurizes the dome into a small blast
 * (light impact only, never devastating), middle band ignites the housing.
 * Retrying straight off a botch (`harsher`) doubles the blast band: pushing
 * a hot, curdled batch is exactly how kitchens end up as craters.
 */
/obj/machinery/drug_lab/crystallizer/run_botch_hazard(mob/user, harsher = FALSE)
	var/turf/here = get_turf(src)
	if(!here)
		return
	do_sparks(3, FALSE, src)
	var/roll = rand(1, 100)
	var/blast_band = DRUG_HAZARD_FIRE_CHANCE * (harsher ? 2 : 1)
	if(roll <= blast_band)
		visible_message(span_danger("[src]'s dome over-pressurizes and blows out!"))
		explosion(src, light_impact_range = 1, explosion_cause = src)
		return
	if(roll <= blast_band + DRUG_HAZARD_FUME_CHANCE)
		visible_message(span_danger("[src] vents superheated vapor and its housing catches!"))
		new /obj/effect/hotspot(here)
		return
	visible_message(span_warning("[src] shrieks out a jet of steam and rattles back down."))
	playsound(src, 'sound/machines/steam_hiss.ogg', 60, TRUE)
