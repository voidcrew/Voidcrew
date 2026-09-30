/**
 * # The Kessler researcher
 *
 * A researcher from Kessler Biolabs beams into the warden's office with the transporter's look,
 * with a chime and a line in the warden's log, and waits OUTPOST_EXPERIMENT_STAY seconds (OUTPOST_EXPERIMENT_STAY_OPEN
 * at most while a manager reads the offer). They only talk business with the outpost's managers;
 * anyone else gets "I only deal with the management." A manager clicking them gets the offer card
 * in a tgui_alert(), claimed before the prompt opens so two managers cannot both take it.
 *
 * Taking it hands over a serum injector or a specimen jar (outpost_prison_serum.dm) and resets the
 * sweetener. Declining it, or letting the researcher wait it out, raises the next offer's pay by
 * OUTPOST_EXPERIMENT_SWEETENER, up to OUTPOST_EXPERIMENT_SWEETENER_MAX. Hurt, they beam out at once.
 * A visit whose only failed gate is the wing's state is a short one: they look round, say so, and go.
 *
 * Kessler's agents (outpost_kessler_team()) beam in around a creature Kessler is taking away,
 * tranquilise it if it is still on its feet, and beam out with it. Nobody from Kessler can be
 * boxed, teleported, polymorphed or made sentient, and none of them can be hurt.
 */

// ===== THE PRISON'S SIDE =====

/**
 * Advances the researcher's visit and the wait for the next one by `seconds`. The first visit is
 * scheduled when the wing's first prisoner is in, and the next whenever nothing is out and nothing
 * is scheduled; the waits only count while `home`.
 */
/datum/outpost_prison/proc/researcher_tick(seconds, home)
	if(researcher)
		if(QDELETED(researcher) || researcher.leaving)
			researcher = null
			offer_claim = null
			return
		if(home)
			researcher_stay += seconds
		var/reading = offer_claim?.resolve()
		if(researcher_stay >= OUTPOST_EXPERIMENT_STAY_OPEN || (!reading && researcher_stay >= OUTPOST_EXPERIMENT_STAY))
			researcher_lapse()
			return
		if(home && !reading)
			pitch_left -= seconds
			if(pitch_left <= 0)
				pitch_left = OUTPOST_EXPERIMENT_PITCH_GAP
				researcher.pitch(sweetener > 0)
		return
	if(!visits_started)
		if(!researcher_prisoner_count())
			return
		visits_started = TRUE
		researcher_wait = rand(OUTPOST_EXPERIMENT_FIRST_VISIT_MIN, OUTPOST_EXPERIMENT_FIRST_VISIT_MAX)
		return
	// Nothing out and nothing scheduled: the item was used up, eaten or lost without starting
	// anything, or the researcher was deleted without leaving. The next visit is 35-50 minutes off.
	if(isnull(researcher_wait) && !experiment_active() && !length(live_items()))
		pending_multiplier = 1
		researcher_wait = rand(OUTPOST_EXPERIMENT_GAP_MIN, OUTPOST_EXPERIMENT_GAP_MAX)
		return
	if(!home || isnull(researcher_wait))
		return
	researcher_wait -= seconds
	if(researcher_wait > 0)
		return
	var/failure = researcher_gate_failure()
	if(failure)
		researcher_wait = OUTPOST_EXPERIMENT_RETRY
		if(failure == "conditions" && !pigsty_shown)
			pigsty_shown = TRUE
			pigsty_visit()
		return
	pigsty_shown = FALSE
	spawn_researcher()

/**
 * Why the researcher would not come now, or null if they would: an experiment or an item out, intake
 * shut, nobody from the wing home, no prisoner, a riot, breakout or loose prisoner, a stranger in
 * the wing, nowhere to stand, or the wing below OUTPOST_EXPERIMENT_MIN_CONDITIONS. The wing's
 * state is checked last, so the researcher only complains about it on a visit that would otherwise
 * have happened.
 */
/datum/outpost_prison/proc/researcher_gate_failure()
	if(experiment_active() || length(live_items()))
		return "busy"
	if(!intake_open)
		return "intake"
	if(!crew_home())
		return "crew"
	if(researcher_prisoner_count() < 1)
		return "prisoners"
	if(riot_active || breaking_out || loose_count() > 0)
		return "trouble"
	if(visitors_in_wing())
		return "visitors"
	if(!researcher_spot())
		return "room"
	if(conditions_score() < OUTPOST_EXPERIMENT_MIN_CONDITIONS)
		return "conditions"
	return null

/// Whether someone who is not a member of the wing is in it
/datum/outpost_prison/proc/visitors_in_wing()
	var/z = wing_z()
	if(!z || z > length(SSmobs.clients_by_zlevel))
		return FALSE
	for(var/mob/living/person as anything in SSmobs.clients_by_zlevel[z])
		if(QDELETED(person) || person.stat == DEAD || get_area(person) != wing || is_outpost_prisoner(person))
			continue
		if(!is_member(person))
			return TRUE
	return FALSE

/// Where the researcher stands: the free office tile nearest the warden's console
/datum/outpost_prison/proc/researcher_spot()
	var/turf/console_turf
	var/list/candidates = list()
	for(var/turf/tile as anything in wing_turfs())
		if(!console_turf && (locate(/obj/machinery/computer/outpost_prison_warden) in tile))
			console_turf = tile
		if(!isopenturf(tile) || cell_block[tile] || (length(staff_ground) && !staff_ground[tile]))
			continue
		candidates += tile
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/open/tile as anything in candidates)
		if(tile.is_blocked_turf(TRUE) || (locate(/mob/living) in tile) || (locate(/obj/machinery/door) in tile))
			continue
		var/distance = console_turf ? get_dist(tile, console_turf) : 0
		if(distance < best_distance)
			best = tile
			best_distance = distance
	return best

/// Picks what the researcher brings: a serum, or from the second offer on sometimes a specimen, which needs two prisoners
/datum/outpost_prison/proc/roll_offer()
	if(offers_made > 0 && researcher_prisoner_count() >= 2 && prob(OUTPOST_EXPERIMENT_SPECIMEN_CHANCE))
		offer_kind = "specimen"
		offer_form = "changeling"
	else
		offer_kind = "serum"
		offer_form = pick_weight(list(
			"hulk" = OUTPOST_EXPERIMENT_WEIGHT_HULK,
			"nightmare" = OUTPOST_EXPERIMENT_WEIGHT_NIGHTMARE,
			"fly" = OUTPOST_EXPERIMENT_WEIGHT_FLY,
		))
	offers_made++

/**
 * Beams the researcher into the office with a new offer. `forced` (the admin panel) skips the
 * gates and the wait. Returns the researcher, or null.
 */
/datum/outpost_prison/proc/spawn_researcher(forced = FALSE)
	if(researcher && !QDELETED(researcher) && !researcher.leaving)
		return null
	if(!forced && researcher_gate_failure())
		return null
	var/turf/spot = researcher_spot()
	if(!spot)
		return null
	roll_offer()
	var/mob/living/basic/outpost_kessler_staff/researcher/doctor = new(spot, src)
	researcher = doctor
	researcher_stay = 0
	pitch_left = OUTPOST_KESSLER_BEAM_TIME / (1 SECONDS) + 2
	offer_claim = null
	researcher_wait = null
	visits_started = TRUE
	doctor.beam_in()
	add_log("[doctor.real_name] of Kessler Biolabs came with an offer.")
	var/turf/chime_turf = alarm_turf()
	if(chime_turf)
		playsound(chime_turf, 'sound/machines/chime.ogg', 40, FALSE)
	log_game("PLAYER OUTPOST PRISON: a Kessler researcher came to '[outpost?.name]' with a [offer_kind] ([offer_form])[forced ? ", sent by an admin" : ""]")
	return doctor

/// The offer, as the researcher puts it: a line or two, with the fee (sweetener in) and no more
/datum/outpost_prison/proc/offer_text()
	var/multiplier = 1 + sweetener
	if(offer_kind == "specimen")
		return "I've got something nasty for one of your prisoners. [round(OUTPOST_EXPERIMENT_FEE_CHANGELING * multiplier)] cr, and a big bonus if you put down what comes out."
	var/low = round(min(OUTPOST_EXPERIMENT_FEE_FLY, OUTPOST_EXPERIMENT_FEE_HULK, OUTPOST_EXPERIMENT_FEE_NIGHTMARE) * multiplier)
	var/high = round(max(OUTPOST_EXPERIMENT_FEE_FLY, OUTPOST_EXPERIMENT_FEE_HULK, OUTPOST_EXPERIMENT_FEE_NIGHTMARE) * multiplier)
	return "Let me try something on one of your prisoners. [low] to [high] cr, and a bonus if things get out of hand."

/**
 * A manager reads the offer. It is claimed for them before the prompt yields, and everything is
 * checked again once it returns. Returns what they got: the item, TRUE for a decline, or FALSE.
 */
/datum/outpost_prison/proc/present_offer(mob/living/user)
	var/mob/living/basic/outpost_kessler_staff/researcher/doctor = researcher
	if(QDELETED(doctor) || doctor.leaving || doctor.beaming || !outpost?.can_manage(user))
		return FALSE
	var/mob/holder = offer_claim?.resolve()
	if(holder)
		if(holder != user)
			doctor.balloon_alert(user, "busy with [holder.name]")
		return FALSE
	offer_claim = WEAKREF(user)
	var/timeout = max(1 SECONDS, (OUTPOST_EXPERIMENT_STAY_OPEN - researcher_stay) SECONDS)
	var/choice = doctor.ask_offer(user, offer_text(), timeout)
	// Back from the prompt: the researcher may have left, the claim lapsed or the user wandered off.
	if(QDELETED(src))
		return FALSE
	if(offer_claim?.resolve() != user)
		return FALSE
	offer_claim = null
	if(researcher != doctor || QDELETED(doctor) || doctor.leaving)
		return FALSE
	if(!outpost?.can_manage(user) || user.stat != CONSCIOUS || get_dist(user, doctor) > 7 || user.z != doctor.z)
		return FALSE
	switch(choice)
		if("Accept")
			return accept_offer(user)
		if("Decline")
			return decline_offer(user)
	return FALSE

/**
 * `user` takes the offer: the item goes in their hands, the sweetener goes into its pay and back
 * to 0, and the researcher leaves. Refused if the wing could not run it now. Returns the item.
 */
/datum/outpost_prison/proc/accept_offer(mob/living/user)
	var/mob/living/basic/outpost_kessler_staff/researcher/doctor = researcher
	if(QDELETED(doctor) || doctor.leaving || !outpost?.can_manage(user))
		return FALSE
	var/needed = offer_kind == "specimen" ? 2 : 1
	if(experiment_active() || length(live_items()) || researcher_prisoner_count() < needed)
		doctor.say("Your wing isn't ready for this right now.")
		return FALSE
	var/obj/item/outpost_experiment/item
	if(offer_kind == "specimen")
		item = new /obj/item/outpost_experiment/specimen(get_turf(user), src, offer_form)
	else
		item = new /obj/item/outpost_experiment/serum(get_turf(user), src, offer_form)
	user.put_in_hands(item)
	pending_multiplier = 1 + sweetener
	sweetener = 0
	doctor.say_line("researcher_accept")
	add_log("[user.real_name] took [doctor.real_name]'s [offer_kind].")
	log_game("PLAYER OUTPOST PRISON: [key_name(user)] accepted a Kessler [offer_kind] ([offer_form]) at '[outpost?.name]'")
	researcher = null
	offer_claim = null
	researcher_wait = null
	doctor.leave(2 SECONDS)
	return item

/// `user` turns the offer down: the next one pays more, and the researcher leaves
/datum/outpost_prison/proc/decline_offer(mob/living/user)
	var/mob/living/basic/outpost_kessler_staff/researcher/doctor = researcher
	if(QDELETED(doctor) || doctor.leaving)
		return FALSE
	sweetener = min(sweetener + OUTPOST_EXPERIMENT_SWEETENER, OUTPOST_EXPERIMENT_SWEETENER_MAX)
	doctor.say_line("researcher_leave")
	add_log("[user ? user.real_name : "Nobody"] turned down [doctor.real_name]'s offer.")
	log_game("PLAYER OUTPOST PRISON: [key_name(user)] declined a Kessler [offer_kind] at '[outpost?.name]'")
	send_researcher_away(doctor)
	return TRUE

/// Nobody took the offer in time: the researcher leaves, and the next offer pays more
/datum/outpost_prison/proc/researcher_lapse()
	var/mob/living/basic/outpost_kessler_staff/researcher/doctor = researcher
	if(QDELETED(doctor))
		researcher = null
		return FALSE
	sweetener = min(sweetener + OUTPOST_EXPERIMENT_SWEETENER, OUTPOST_EXPERIMENT_SWEETENER_MAX)
	doctor.say_line("researcher_leave")
	add_log("Nobody took [doctor.real_name]'s offer.")
	send_researcher_away(doctor)
	return TRUE

/// Someone hurt the researcher: gone at once, with no sweetener for the next visit
/datum/outpost_prison/proc/researcher_assaulted()
	var/mob/living/basic/outpost_kessler_staff/researcher/doctor = researcher
	if(QDELETED(doctor))
		return FALSE
	// Hit while still beaming in: they just go, without a word from thin air.
	if(!doctor.beaming && !doctor.departing)
		doctor.say("I'm leaving!")
	add_log("[doctor.real_name] was attacked and left.")
	log_game("PLAYER OUTPOST PRISON: the Kessler researcher at '[outpost?.name]' was attacked and left")
	send_researcher_away(doctor, 0)
	return TRUE

/// The researcher leaves after `delay`; the next visit is 35-50 minutes off
/datum/outpost_prison/proc/send_researcher_away(mob/living/basic/outpost_kessler_staff/researcher/doctor, delay = 2 SECONDS)
	researcher = null
	offer_claim = null
	researcher_wait = rand(OUTPOST_EXPERIMENT_GAP_MIN, OUTPOST_EXPERIMENT_GAP_MAX)
	doctor.leave(delay)

/// The researcher looks round a wing below OUTPOST_EXPERIMENT_MIN_CONDITIONS, says so and goes
/datum/outpost_prison/proc/pigsty_visit()
	var/turf/spot = researcher_spot()
	if(!spot)
		return null
	// Not the wing's researcher: nobody can take an offer from them, and they hold no reference to the prison.
	var/mob/living/basic/outpost_kessler_staff/researcher/doctor = new(spot, null)
	doctor.beam_in()
	// A second after they are all the way in, not while they are still knitting together.
	addtimer(CALLBACK(doctor, TYPE_PROC_REF(/mob/living/basic/outpost_kessler_staff/researcher, refuse_wing)), OUTPOST_KESSLER_BEAM_TIME + 1 SECONDS, TIMER_DELETE_ME)
	add_log("[doctor.real_name] of Kessler Biolabs came, but would not work in the wing as it is.")
	return doctor

// ===== KESSLER STAFF =====

/// Someone from Kessler Biolabs: beams in and out, cannot be hurt, boxed, teleported or taken over
/mob/living/basic/outpost_kessler_staff
	name = "Kessler Biolabs employee"
	desc = "Someone from Kessler Biolabs."
	icon = 'icons/mob/simple/simple_human.dmi'
	mob_biotypes = MOB_ORGANIC | MOB_HUMANOID
	sentience_type = SENTIENCE_HUMANOID
	basic_mob_flags = NONE
	status_flags = NONE
	move_resist = INFINITY
	// tg's human deathgasp
	death_message = "seizes up and falls limp, their eyes dead and lifeless..."
	density = TRUE
	maxHealth = 100
	health = 100
	damage_coeff = list(BRUTE = 1, BURN = 1, TOX = 0, STAMINA = 0, OXY = 0)
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	speak_emote = list("says")
	response_help_continuous = "taps"
	response_help_simple = "tap"
	/// What they wear
	var/outfit = /datum/outfit/outpost_kessler_researcher
	/// The prison they came to
	var/datum/outpost_prison/prison
	/// On the way out
	var/leaving = FALSE
	/// Still beaming in: held still and silent until the knit is over
	var/beaming = FALSE
	/// Beaming out: held still and silent while they dematerialise
	var/departing = FALSE
	/// A line of dialogue to say once they have fully materialised, if any
	var/arrival_line

/mob/living/basic/outpost_kessler_staff/Initialize(mapload, datum/outpost_prison/owner)
	gender = pick(MALE, FEMALE)
	. = ..()
	prison = owner
	ADD_TRAIT(src, TRAIT_NO_CONTAINMENT, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_NO_STORAGE_INSERT, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_OUTPOST_EXPERIMENT, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_PUSHIMMUNE, INNATE_TRAIT)
	AddElement(/datum/element/footstep, footstep_type = FOOTSTEP_MOB_SHOE)
	RegisterSignal(src, COMSIG_MOVABLE_TELEPORTING, PROC_REF(refuse_teleport))
	RegisterSignal(src, COMSIG_LIVING_PRE_WABBAJACKED, PROC_REF(refuse_polymorph))
	RegisterSignal(src, COMSIG_PRE_MOB_CHANGED_TYPE, PROC_REF(refuse_type_change))
	apply_dynamic_human_appearance(src, outfit, /datum/species/human)

/mob/living/basic/outpost_kessler_staff/Destroy()
	if(prison?.researcher == src)
		prison.researcher = null
		prison.offer_claim = null
	prison = null
	return ..()

/// Nothing Kessler sends can be hurt: a blow makes them leave instead
/mob/living/basic/outpost_kessler_staff/adjust_health(amount, updating_health = TRUE, forced = FALSE)
	if(amount > 0 && !forced)
		INVOKE_ASYNC(src, PROC_REF(hurt_by_someone))
		return 0
	return ..()

/mob/living/basic/outpost_kessler_staff/proc/hurt_by_someone()
	leave()

/mob/living/basic/outpost_kessler_staff/proc/refuse_teleport(datum/source, atom/destination, channel)
	SIGNAL_HANDLER
	return TRUE

/mob/living/basic/outpost_kessler_staff/proc/refuse_polymorph(datum/source, what_to_randomize)
	SIGNAL_HANDLER
	return STOP_WABBAJACK

/mob/living/basic/outpost_kessler_staff/proc/refuse_type_change(datum/source)
	SIGNAL_HANDLER
	return COMPONENT_BLOCK_MOB_CHANGE

/// Says a line of `context` from the dialogue file. Never while beaming in or out, invisible or half there.
/mob/living/basic/outpost_kessler_staff/proc/say_line(context)
	if(beaming || departing)
		return null
	var/line = outpost_experiment_line(context)
	if(line)
		say(line)
	return line

/**
 * Materialises where they stand: they knit together inside the transporter's column over the
 * whole beam. They stay `beaming` (held still, silent) until finish_beam_in() as the beam ends.
 */
/mob/living/basic/outpost_kessler_staff/proc/beam_in()
	beaming = TRUE
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, OUTPOST_KESSLER_TRAIT)
	var/turf/spot = get_turf(src)
	if(spot)
		playsound(spot, 'sound/effects/magic/teleport_diss.ogg', 40, TRUE)
		new /obj/effect/temp_visual/transporter_beam(spot, OUTPOST_KESSLER_BEAM_TIME + 0.5 SECONDS)
	// Hidden under the mask from the first frame. finish_beam_in() takes the effects off, so one
	// sent away mid-knit keeps beam_out()'s.
	transporter_materialise(src, 255, OUTPOST_KESSLER_BEAM_TIME, restore = FALSE)
	addtimer(CALLBACK(src, PROC_REF(finish_beam_in)), OUTPOST_KESSLER_BEAM_TIME, TIMER_DELETE_ME)

/// Fully there as the beam ends: the flash, and only now do they talk
/mob/living/basic/outpost_kessler_staff/proc/finish_beam_in()
	if(!beaming || departing)
		return
	var/turf/spot = get_turf(src)
	if(spot)
		new /obj/effect/temp_visual/transporter_flash(spot)
		transporter_sparks(spot)
		playsound(spot, 'sound/effects/magic/teleport_app.ogg', 50, TRUE)
	// Whatever is left of the knit, gone: they are solid from here on.
	transporter_restore(src, 255)
	beaming = FALSE
	REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, OUTPOST_KESSLER_TRAIT)
	if(arrival_line)
		say_line(arrival_line)

/// Leaves after `delay`: beams out and is gone
/mob/living/basic/outpost_kessler_staff/proc/leave(delay = 0)
	if(leaving)
		return
	leaving = TRUE
	if(prison?.researcher == src)
		prison.researcher = null
		prison.offer_claim = null
	prison = null
	if(delay > 0)
		addtimer(CALLBACK(src, PROC_REF(beam_out)), delay, TIMER_DELETE_ME)
	else
		beam_out()

/mob/living/basic/outpost_kessler_staff/proc/beam_out()
	beaming = FALSE
	departing = TRUE
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, OUTPOST_KESSLER_TRAIT)
	var/turf/spot = get_turf(src)
	if(spot)
		playsound(spot, 'sound/effects/magic/teleport_diss.ogg', 40, TRUE)
		new /obj/effect/temp_visual/transporter_beam(spot, OUTPOST_KESSLER_BEAM_TIME + 0.5 SECONDS)
	transporter_dematerialise(src, OUTPOST_KESSLER_BEAM_TIME)
	addtimer(CALLBACK(src, PROC_REF(finish_beam_out)), OUTPOST_KESSLER_BEAM_TIME, TIMER_DELETE_ME)

/mob/living/basic/outpost_kessler_staff/proc/finish_beam_out()
	var/turf/spot = get_turf(src)
	if(spot)
		new /obj/effect/temp_visual/transporter_flash/departure(spot)
		transporter_sparks(spot)
		playsound(spot, 'sound/effects/magic/teleport_app.ogg', 50, TRUE)
	qdel(src)

// ----- the researcher -----

/mob/living/basic/outpost_kessler_staff/researcher
	name = "researcher"
	desc = "A researcher from Kessler Biolabs, with a clipboard and a labcoat that has never seen a stain."
	outfit = /datum/outfit/outpost_kessler_researcher
	COOLDOWN_DECLARE(brush_off_cooldown)

/mob/living/basic/outpost_kessler_staff/researcher/Initialize(mapload, datum/outpost_prison/owner)
	. = ..()
	real_name = "Dr. [pick(GLOB.last_names)]"
	name = real_name
	RegisterSignal(src, COMSIG_ATOM_ATTACK_HAND, PROC_REF(on_hand))

/mob/living/basic/outpost_kessler_staff/researcher/hurt_by_someone()
	if(prison?.researcher == src)
		prison.researcher_assaulted()
		return
	leave()

/// An empty hand, not in combat mode: a word with the researcher instead of a pat
/mob/living/basic/outpost_kessler_staff/researcher/proc/on_hand(datum/source, mob/living/user, list/modifiers)
	SIGNAL_HANDLER
	if(!istype(user) || user.combat_mode || LAZYACCESS(modifiers, RIGHT_CLICK))
		return NONE
	INVOKE_ASYNC(src, PROC_REF(talk_to), user)
	return COMPONENT_CANCEL_ATTACK_CHAIN

/// Managers get the offer; everyone else gets told who the researcher deals with
/mob/living/basic/outpost_kessler_staff/researcher/proc/talk_to(mob/living/user)
	if(leaving || beaming || !prison || prison.researcher != src)
		return FALSE
	face_atom(user)
	if(!prison.outpost?.can_manage(user))
		if(COOLDOWN_FINISHED(src, brush_off_cooldown))
			COOLDOWN_START(src, brush_off_cooldown, OUTPOST_EXPERIMENT_BRUSH_OFF_GAP)
			say("I only deal with the management.")
		return FALSE
	return prison.present_offer(user)

/// The offer card as a prompt: "Accept", "Decline", or null if it was closed
/mob/living/basic/outpost_kessler_staff/researcher/proc/ask_offer(mob/living/user, text, timeout)
	return tgui_alert(user, text, "[real_name], Kessler Biolabs", list("Accept", "Decline"), timeout)

/// A pitch to whoever is about, pushier after declines
/mob/living/basic/outpost_kessler_staff/researcher/proc/pitch(sweetened = FALSE)
	if(leaving || beaming)
		return null
	return say_line(sweetened ? "researcher_sweetened" : "researcher_offer")

/// A short visit to a wing in no state for an experiment
/mob/living/basic/outpost_kessler_staff/researcher/proc/refuse_wing()
	if(QDELETED(src) || leaving)
		return
	say_line("researcher_pigsty")
	leave(2 SECONDS)

// ----- the recovery team -----

/mob/living/basic/outpost_kessler_staff/agent
	name = "Kessler recovery agent"
	desc = "A Kessler Biolabs recovery agent in a hazmat suit, carrying a tranquilliser gun."
	outfit = /datum/outfit/outpost_kessler_agent

/**
 * Two agents beam in around `creature`, one says a line of `context` once they are all the way in,
 * and they all beam out after OUTPOST_KESSLER_TEAM_TIME. A creature still on its feet is
 * `tranquilise`d; one already down is simply collected.
 */
/proc/outpost_kessler_team(mob/living/creature, context = "kessler_recovery", tranquilise = TRUE)
	var/turf/center = get_turf(creature)
	if(!center)
		return
	var/list/spots = list()
	for(var/turf/open/tile in orange(1, center))
		if(!tile.is_blocked_turf(TRUE) && !(locate(/mob/living) in tile))
			spots += tile
	var/mob/living/basic/outpost_kessler_staff/agent/speaker
	for(var/i in 1 to min(2, length(spots)))
		var/mob/living/basic/outpost_kessler_staff/agent/agent = new(pick_n_take(spots), null)
		agent.face_atom(creature)
		agent.beam_in()
		agent.leave(OUTPOST_KESSLER_TEAM_TIME)
		if(!speaker)
			speaker = agent
	// Said once they are all the way in, not from thin air.
	if(speaker)
		speaker.arrival_line = context
	if(tranquilise)
		creature.visible_message(span_warning("Kessler Biolabs agents beam in around [creature], and a tranquilliser dart drops [creature.p_them()]."))
		playsound(center, 'sound/items/syringeproj.ogg', 50, TRUE)
	else
		creature.visible_message(span_notice("Kessler Biolabs agents beam in to collect [creature]."))

/// Kessler's beam takes `target` away for good
/proc/outpost_kessler_beam_away(mob/living/target)
	if(QDELETED(target))
		return
	var/turf/spot = get_turf(target)
	if(spot)
		target.visible_message(span_notice("A transporter beam takes [target] away."))
		playsound(spot, 'sound/effects/magic/teleport_diss.ogg', 40, TRUE)
		new /obj/effect/temp_visual/transporter_beam(spot, OUTPOST_KESSLER_BEAM_TIME + 0.5 SECONDS)
	transporter_dematerialise(target, OUTPOST_KESSLER_BEAM_TIME)
	QDEL_IN(target, OUTPOST_KESSLER_BEAM_TIME)

// ===== LOOKS =====

/datum/outfit/outpost_kessler_researcher
	name = "Kessler Biolabs researcher"
	uniform = /obj/item/clothing/under/suit/black
	suit = /obj/item/clothing/suit/toggle/labcoat
	shoes = /obj/item/clothing/shoes/laceup
	gloves = /obj/item/clothing/gloves/latex
	glasses = /obj/item/clothing/glasses/regular
	l_hand = /obj/item/clipboard

/datum/outfit/outpost_kessler_agent
	name = "Kessler Biolabs recovery agent"
	uniform = /obj/item/clothing/under/suit/black
	suit = /obj/item/clothing/suit/bio_suit/general
	head = /obj/item/clothing/head/bio_hood/general
	mask = /obj/item/clothing/mask/gas
	gloves = /obj/item/clothing/gloves/latex
	shoes = /obj/item/clothing/shoes/sneakers/white
	r_hand = /obj/item/gun/syringe
