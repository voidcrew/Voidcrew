/**
 * # Outpost police: witnesses
 *
 * Owner: P1, then P13 (the stealth merge). The whole "did anyone see it" test (owner decisions 6 and 19,
 * spec 3 and spec-stealth 2). This is the only police file that names can_see, stealth_in_cone,
 * cyberware_camo_hides or a witness range.
 *
 * A crime counts when witness_of() names a witness. report_crime() (police_wanted.dm) asks that one question,
 * asks report_delay() how long the witness takes to report, reports_by_call() whether only its radio call
 * makes the report, and can_report() whether they still can.
 *
 * The police use /datum/outpost_police_perception/stealth (below): sight convicts, sound never does. An officer
 * sees by stealth's own rules (cone, darkness, cloaks, boxes) and its report counts when its radio call goes out,
 * so dropping, stunning, jamming or EMPing the only officer who saw it before the call means nobody is wanted.
 * Traders, checkpoint guards and cameras report at once; townspeople take a moment. The base datum is the plain
 * rule (sight within range, reports at once), kept for tests.
 */

/// The witness test this police uses
/datum/outpost_police/proc/make_perception()
	return new /datum/outpost_police_perception/stealth(src)

/datum/outpost_police_perception
	/// Every officer who saw the last crime witness_of() was asked about (the stealth subtype; one report, many witnesses)
	var/list/last_witnesses
#ifdef UNIT_TESTS
	/// Tests not about sight: every witness sees by the plain rule and reports at once. The stealth tests turn it off.
	var/test_plain = TRUE
#endif

/**
 * Who, if anyone, witnessed `offender` doing `crime` to `victim` with `source`: POLICE_WITNESS_*. Sets
 * `last_witness`. Candidates in order: this outpost's officers, its traders and checkpoint guards, the
 * ambient people of its place, players not on the offender's crew (the victim first), then cameras. The first
 * that sees wins. Crimes done to an officer, and crimes the scanner or the cell see, need no one in sight.
 */
/datum/outpost_police_perception/proc/witness_of(mob/living/offender, crime, atom/victim, obj/item/source)
	last_witness = null
	last_witnesses = null
	if(!offender || !police?.outpost)
		return POLICE_WITNESS_NONE
	switch(crime)
		if(OUTPOST_CRIME_RESIST, OUTPOST_CRIME_ASSAULT_OFFICER, OUTPOST_CRIME_KILL_OFFICER)
			// Always counts while an officer of this outpost is alive
			last_witness = living_officer_near(offender, victim)
			return last_witness ? POLICE_WITNESS_SAW : POLICE_WITNESS_NONE
		if(OUTPOST_CRIME_WEAPON_DRAWN, OUTPOST_CRIME_CHECKPOINT_BREACH, OUTPOST_CRIME_JAILBREAK, OUTPOST_CRIME_TRESPASS, OUTPOST_CRIME_ACCOMPLICE)
			// The scanner, the cell and the officers' own sighting see these
			return POLICE_WITNESS_CAMERA

	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police.officers)
		if(sees(officer, offender))
			last_witness = officer
			return POLICE_WITNESS_SAW
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/trader in police.outpost.traders)
		if(sees(trader, offender))
			last_witness = trader
			return POLICE_WITNESS_SAW
	var/datum/ambient_place/outpost/place = SSambient_npcs.outposts?[police.outpost]
	if(place)
		for(var/mob/living/carbon/human/npc/ambient_npc/person in place.npcs)
			if(!person.mind && !person.client && sees(person, offender))
				last_witness = person
				return POLICE_WITNESS_SAW
	var/datum/voidcrew_crew_record/own_crew = offender.mind?.get_reputation_crew()
	var/mob/living/watching_victim = isliving(victim) ? victim : null
	if(watching_victim?.mind && watching_victim != offender && !on_crew(watching_victim, own_crew) && sees(watching_victim, offender))
		last_witness = watching_victim
		return POLICE_WITNESS_SAW
	for(var/mob/living/player in GLOB.alive_player_list)
		if(player == offender || player == watching_victim || on_crew(player, own_crew))
			continue
		if(sees(player, offender) && get_trader_outpost_for_turf(get_turf(player)) == police.outpost)
			last_witness = player
			return POLICE_WITNESS_SAW
	for(var/atom/camera as anything in cameras())
		if(sees(camera, offender))
			last_witness = camera
			return POLICE_WITNESS_CAMERA
	return POLICE_WITNESS_NONE

/// Whether `person` belongs to `crew` (a null crew has no members)
/datum/outpost_police_perception/proc/on_crew(mob/living/person, datum/voidcrew_crew_record/crew)
	return !!crew && person.mind?.get_reputation_crew() == crew

/// The living officer of this outpost who answers an attack on `victim`: that officer if it is one, else the nearest to `offender`; null if none lives
/datum/outpost_police_perception/proc/living_officer_near(mob/living/offender, atom/victim)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/nearest
	var/nearest_dist = INFINITY
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police.officers)
		if(officer.stat == DEAD || QDELETED(officer))
			continue
		if(officer == victim)
			return officer
		var/dist = (offender && officer.z == offender.z) ? get_dist(officer, offender) : 1000
		if(!nearest || dist < nearest_dist)
			nearest = officer
			nearest_dist = dist
	return nearest

/**
 * Whether `viewer` (a conscious living mob, or a camera) sees `target` now: within the witness range with a
 * clear line, and not past the optical camo of a target an NPC or camera cannot spot. Also the test for
 * "an officer sees the suspect" (police_wanted.dm tick_warrants()).
 * A turf `viewer` asks whether that tile and `target` are in sight of each other (police_dispatch.dm picks
 * lift points and arrival tiles out of a suspect's sight with it): range and a clear line only.
 */
/datum/outpost_police_perception/proc/sees(atom/viewer, mob/living/target)
	if(QDELETED(viewer) || QDELETED(target))
		return FALSE
	var/atom/seen_target = isvehicle(target.loc) ? target.loc : target
	if(isturf(viewer))
		return can_see(viewer, seen_target, OUTPOST_POLICE_WITNESS_RANGE)
	if(!isturf(seen_target.loc))
		return FALSE
	var/mob/living/watcher = isliving(viewer) ? viewer : null
	if(watcher)
		if(watcher.stat != CONSCIOUS || watcher.is_blind() || is_fading_npc(watcher))
			return FALSE
	else if(!is_camera(viewer))
		return FALSE
	if(!can_see(viewer, seen_target, OUTPOST_POLICE_WITNESS_RANGE))
		return FALSE
	// Optical camo fools AI and cameras; a player with eyes is not fooled, and a mech is never cloaked
	if(!ismecha(seen_target) && (!watcher || !watcher.mind) && cyberware_camo_hides(target, viewer))
		return FALSE
	return TRUE

/// Unblocked line of sight on the same z-level within `max_dist`, facing and camo aside (for furniture and routine small talk)
/proc/outpost_police_clear_line(atom/from, atom/to_atom, max_dist = OUTPOST_POLICE_WITNESS_RANGE)
	var/turf/from_turf = get_turf(from)
	var/turf/to_turf = get_turf(to_atom)
	return from_turf && to_turf && from_turf.z == to_turf.z && can_see(from, to_atom, max_dist)

/// Whether `thing` is one of the outpost's cameras
/datum/outpost_police_perception/proc/is_camera(atom/thing)
	return istype(thing, /obj/machinery/outpost_checkpoint_sensor) || istype(thing, /obj/machinery/outpost_elevator)

/// Whether a checkpoint scanner has `target` in its chamber (the scan counts as seeing them)
/datum/outpost_police_perception/proc/scanned(mob/living/target)
	var/turf/where = get_turf(target)
	if(!where || !police?.outpost)
		return FALSE
	for(var/checkpoint_id in police.outpost.checkpoints)
		var/datum/outpost_checkpoint/checkpoint = police.outpost.checkpoints[checkpoint_id]
		if(checkpoint?.sensor && (where in checkpoint.chamber_turfs))
			return TRUE
	return FALSE

/// Whether `listener` hears `offender` doing `crime` with `source`. Nothing is heard in this build.
/datum/outpost_police_perception/proc/hears(atom/listener, mob/living/offender, crime, obj/item/source)
	return FALSE

/// What watches for the police besides people: the checkpoint wall scanners and the lift panels
/datum/outpost_police_perception/proc/cameras()
	. = list()
	var/obj/structure/overmap/trader_outpost/outpost = police?.outpost
	if(!outpost)
		return
	for(var/checkpoint_id in outpost.checkpoints)
		var/datum/outpost_checkpoint/checkpoint = outpost.checkpoints[checkpoint_id]
		if(checkpoint?.sensor)
			. += checkpoint.sensor
	for(var/obj/machinery/outpost_elevator/lobby_panel in outpost.lobby_panels)
		. += lobby_panel
	for(var/datum/outpost_berth/berth as anything in outpost.berths)
		if(berth?.panel)
			. += berth.panel

/// How long `witness` takes to report `crime`; 0 is at once
/datum/outpost_police_perception/proc/report_delay(atom/witness, crime)
	return 0

/// Whether only `witness`'s own radio call (or telling someone in person) makes its report: confirm_reports() decides when
/datum/outpost_police_perception/proc/reports_by_call(atom/witness)
	return FALSE

/**
 * Once a second while `witness` has a report waiting on its call: gets the call going again if it can. TRUE while
 * it is telling someone in person instead (OUTPOST_POLICE_RADIOLESS_TIME of that makes the report).
 */
/datum/outpost_police_perception/proc/nudge_witness(atom/witness, datum/outpost_pending_report/report)
	return FALSE

/// Whether `witness` can still make its report
/datum/outpost_police_perception/proc/can_report(atom/witness)
	return TRUE

// =========================================================================
// THE STEALTH RULES (spec-stealth 2; owner decision 19)
// =========================================================================

/**
 * Sight convicts, sound summons, the radio decides when it counts.
 * - Officers see by stealth's rules (officer_sees()); a struck officer sees whoever hit it in range and line of
 *   sight, cone or not. Every officer who saw a crime shares one report, made when the first of them gets the
 *   call out (police_wanted.dm confirm_reports(), from the call in police_stealth.dm) or tells an officer with a
 *   working radio, or the desk, in person.
 * - Traders, checkpoint guards and cameras see all round and report at once; townspeople see all round and take
 *   OUTPOST_POLICE_CIVILIAN_REPORT_TIME. Players see as before.
 * - hears() stays FALSE: a noise brings officers to look (stealth_noise.dm), never stars.
 */
/datum/outpost_police_perception/stealth

/datum/outpost_police_perception/stealth/witness_of(mob/living/offender, crime, atom/victim, obj/item/source)
	last_witness = null
	last_witnesses = null
	if(!offender || !police?.outpost)
		return POLICE_WITNESS_NONE
	switch(crime)
		if(OUTPOST_CRIME_WEAPON_DRAWN, OUTPOST_CRIME_CHECKPOINT_BREACH, OUTPOST_CRIME_JAILBREAK, OUTPOST_CRIME_TRESPASS, OUTPOST_CRIME_ACCOMPLICE)
			// The scanner, the cell and the officers' own sighting see these
			return POLICE_WITNESS_CAMERA
	// At once: the traders and checkpoint guards, players not on the offender's crew (the victim first), the cameras
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/trader in police.outpost.traders)
		if(can_report(trader) && sees(trader, offender))
			last_witness = trader
			return POLICE_WITNESS_SAW
	var/datum/voidcrew_crew_record/own_crew = offender.mind?.get_reputation_crew()
	var/mob/living/watching_victim = isliving(victim) ? victim : null
	if(watching_victim?.mind && !is_officer(watching_victim) && watching_victim != offender && !on_crew(watching_victim, own_crew) && sees(watching_victim, offender))
		last_witness = watching_victim
		return POLICE_WITNESS_SAW
	for(var/mob/living/player in GLOB.alive_player_list)
		if(player == offender || player == watching_victim || is_officer(player) || on_crew(player, own_crew))
			continue
		if(sees(player, offender) && get_trader_outpost_for_turf(get_turf(player)) == police.outpost)
			last_witness = player
			return POLICE_WITNESS_SAW
	for(var/atom/camera as anything in cameras())
		if(sees(camera, offender))
			last_witness = camera
			return POLICE_WITNESS_CAMERA
	// Delayed witnesses: every officer who saw it (radio call) and every ambient civilian/crew member who saw it (3s delay).
	// Keeping all of them on the report means silencing one witness does not blind another standing right beside them.
	var/list/officers_saw = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police.officers)
		if(officer == victim ? struck_sees(officer, offender) : sees(officer, offender))
			officers_saw += officer
	var/list/civilians_saw = list()
	var/datum/ambient_place/outpost/place = SSambient_npcs.outposts?[police.outpost]
	if(place)
		for(var/mob/living/carbon/human/npc/ambient_npc/person in place.npcs)
			if(!person.mind && !person.client && !is_officer(person) && !(person in police.outpost.traders) && sees(person, offender))
				civilians_saw += person
	if(length(civilians_saw) && length(officers_saw))
		last_witnesses = civilians_saw + officers_saw
		last_witness = civilians_saw[1]
		return POLICE_WITNESS_SAW
	if(length(officers_saw))
		last_witnesses = officers_saw
		last_witness = officers_saw[1]
		return POLICE_WITNESS_SAW
	if(length(civilians_saw))
		last_witnesses = civilians_saw
		last_witness = civilians_saw[1]
		return POLICE_WITNESS_SAW
	return POLICE_WITNESS_NONE

/// Whether `thing` is an NPC police officer (never a player in an officer's body, abuse SF3)
/datum/outpost_police_perception/proc/is_officer(atom/thing)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = thing
	return istype(officer) && !officer.mind && !officer.client

/// Whether `thing` is an NPC slipping away down a lift (fade_out()) and no longer here to watch or report
/datum/outpost_police_perception/proc/is_fading_npc(atom/thing)
	var/mob/living/carbon/human/npc/ambient_npc/npc = thing
	return istype(npc) && npc.fading && !npc.mind && !npc.client

/datum/outpost_police_perception/stealth/sees(atom/viewer, mob/living/target)
	if(QDELETED(viewer) || QDELETED(target))
		return FALSE
#ifdef UNIT_TESTS
	if(test_plain)
		return ..()
#endif
	if(isturf(viewer))
		return ..()
	if(is_officer(viewer))
		return officer_sees(viewer, target)
	if(isliving(viewer))
		var/mob/living/watcher = viewer
		// A player sees as they always did
		if(watcher.mind || watcher.client)
			return ..()
		if(watcher.stat != CONSCIOUS)
			return FALSE
		return all_round_sees(watcher, target, FALSE)
	if(!is_camera(viewer))
		return FALSE
	return all_round_sees(viewer, target, TRUE)

/**
 * A trader, guard, townsperson (`see_cloaks` FALSE) or camera (TRUE): all round, OUTPOST_POLICE_NPC_WITNESS_RANGE,
 * STEALTH_DARK_SIGHT_RANGE onto a dark tile, never someone shut in a box or locker. A cloak hides its wearer from
 * all but a camera beyond STEALTH_CLOSE_RANGE.
 */
/datum/outpost_police_perception/stealth/proc/all_round_sees(atom/viewer, mob/living/target, see_cloaks)
	if(isliving(viewer))
		var/mob/living/living_viewer = viewer
		if(living_viewer.is_blind() || is_fading_npc(living_viewer))
			return FALSE
	var/atom/seen_target = isvehicle(target.loc) ? target.loc : target
	var/turf/where = seen_target.loc
	var/turf/from = get_turf(viewer)
	if(!isturf(where) || !from || from.z != where.z)
		return FALSE
	var/dist = get_dist(from, where)
	if(ismecha(seen_target))
		return dist <= OUTPOST_POLICE_NPC_WITNESS_RANGE && can_see(viewer, seen_target, OUTPOST_POLICE_NPC_WITNESS_RANGE)
	var/reach = OUTPOST_POLICE_NPC_WITNESS_RANGE
	if(dist > STEALTH_CLOSE_RANGE && stealth_tile_is_dark(where))
		reach = STEALTH_DARK_SIGHT_RANGE
	if(dist > reach)
		return FALSE
	if(!see_cloaks && dist > STEALTH_CLOSE_RANGE && stealth_is_cloaked(target))
		return FALSE
	return can_see(viewer, seen_target, reach)

/**
 * An officer: stealth's sight (stealth_ai.dm stealth_look()). Within STEALTH_SIGHT_RANGE and in its cone (wider
 * when wary or searching), STEALTH_DARK_SIGHT_RANGE onto a dark tile, or within STEALTH_CLOSE_RANGE whatever its
 * facing where the light lets it. A cloak hides beyond STEALTH_CLOSE_RANGE; a box or a locker hides always; a mech
 * is never hidden (stealth_ai.dm). Also the "seen" test that holds the hide clock (police_wanted.dm tick_warrants()).
 */
/datum/outpost_police_perception/stealth/proc/officer_sees(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, mob/living/target)
	if(officer.stat != CONSCIOUS || officer.is_blind() || is_fading_npc(officer))
		return FALSE
	var/atom/seen_target = isvehicle(target.loc) ? target.loc : target
	var/turf/where = seen_target.loc
	var/turf/here = get_turf(officer)
	if(!isturf(where) || !here || here.z != where.z)
		return FALSE
	var/dist = get_dist(here, where)
	if(dist > STEALTH_SIGHT_RANGE)
		return FALSE
	if(ismecha(seen_target))
		return can_see(officer, seen_target, STEALTH_SIGHT_RANGE)
	if(dist > STEALTH_CLOSE_RANGE && stealth_is_cloaked(target))
		return FALSE
	var/dark = !HAS_TRAIT(officer, TRAIT_NIGHT_VISION) && stealth_tile_is_dark(where)
	var/datum/ai_controller/basic_controller/human_npc/stealth/brain = officer.ai_controller
	var/half_angle = istype(brain) ? brain.stealth_half_angle() : STEALTH_CONE_HALF_ANGLE
	var/in_view = FALSE
	if(officer.body_position != LYING_DOWN && stealth_in_cone(officer, where, half_angle))
		in_view = dist <= ((dist <= STEALTH_ADJACENT_RANGE || !dark) ? STEALTH_SIGHT_RANGE : STEALTH_DARK_SIGHT_RANGE)
	if(!in_view && dist <= STEALTH_CLOSE_RANGE && !dark)
		in_view = TRUE
	return in_view && can_see(officer, seen_target, STEALTH_SIGHT_RANGE)

/// An officer just struck by `offender` sees them in range and line of sight, its facing aside (stealth's rule for a hit)
/datum/outpost_police_perception/stealth/proc/struck_sees(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, mob/living/offender)
#ifdef UNIT_TESTS
	if(test_plain)
		return sees(officer, offender)
#endif
	var/atom/seen_target = isvehicle(offender.loc) ? offender.loc : offender
	if(officer.stat != CONSCIOUS || officer.is_blind() || !isturf(seen_target.loc) || officer.z != seen_target.z)
		return FALSE
	var/dist = get_dist(officer, seen_target)
	if(dist > STEALTH_SIGHT_RANGE || (!ismecha(seen_target) && dist > STEALTH_CLOSE_RANGE && stealth_is_cloaked(offender)))
		return FALSE
	return can_see(officer, seen_target, STEALTH_SIGHT_RANGE)

/datum/outpost_police_perception/stealth/report_delay(atom/witness, crime)
#ifdef UNIT_TESTS
	if(test_plain)
		return 0
#endif
	// Townspeople take a moment; a trader or gate guard (ambient NPCs since R1) reports at once, as an officer's desk would
	var/mob/living/carbon/human/npc/ambient_npc/npc = witness
	if(istype(npc) && !npc.mind && !npc.client && !is_officer(npc) && !istype(npc, /mob/living/carbon/human/npc/ambient_npc/outpost/trader))
		return OUTPOST_POLICE_CIVILIAN_REPORT_TIME
	return 0

/datum/outpost_police_perception/stealth/reports_by_call(atom/witness)
#ifdef UNIT_TESTS
	if(test_plain)
		return FALSE
#endif
	return is_officer(witness)

/// An officer reports while awake and not held (stealth_captive()); a townsperson while awake and not tied up; a crew
/// member only with a working headset
/datum/outpost_police_perception/stealth/can_report(atom/witness)
	if(!isliving(witness))
		return TRUE
	var/mob/living/person = witness
	if(person.stat != CONSCIOUS || HAS_TRAIT(person, TRAIT_INCAPACITATED) || is_fading_npc(person))
		return FALSE
	if(person.mind || person.client)
		return TRUE
	if(is_officer(person))
		var/datum/ai_controller/basic_controller/human_npc/stealth/brain = person.ai_controller
		return !istype(brain) || !brain.stealth_captive()
	// A morgue or cleaning crew member calls it in on their headset: dead air with it off, EMPed or jammed (decision 19)
	if(istype(person, /mob/living/carbon/human/npc/ambient_npc/outpost/recovery))
		var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/crew = person
		if(!crew.stealth_radio_ready() || !human_npc_can_talk(crew))
			return FALSE
	if(istype(person, /mob/living/carbon/human/npc/ambient_npc))
		return !HAS_TRAIT(person, TRAIT_RESTRAINED)
	return TRUE

/**
 * `witness` (an officer) has a report waiting. With a working radio it gets a call going if none is (a call lost to
 * a stun, an EMP or a jammer is tried again once it can be, inside the report's keep: owner decision 42). Without
 * one, TRUE while it stands within OUTPOST_POLICE_RADIOLESS_RANGE of an officer with a working radio, or of the desk:
 * telling them in person.
 */
/datum/outpost_police_perception/stealth/nudge_witness(atom/witness, datum/outpost_pending_report/report)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = witness
	if(!is_officer(officer) || !can_report(officer))
		return FALSE
	if(officer.stealth_radio_ready())
		var/datum/ai_controller/basic_controller/human_npc/stealth/brain = officer.ai_controller
		if(istype(brain) && isnull(brain.pending_call))
			var/mob/living/offender = report.offender?.resolve()
			brain.stealth_start_call(STEALTH_CALL_ALARM, get_turf(offender) || get_turf(officer))
		return FALSE
	var/turf/here = get_turf(officer)
	if(!here)
		return FALSE
	var/turf/desk = police?.desk_turf
	if(desk && desk.z == here.z && get_dist(desk, here) <= OUTPOST_POLICE_RADIOLESS_RANGE)
		return TRUE
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/other in police?.officers)
		if(other == officer || other.z != here.z || get_dist(other, here) > OUTPOST_POLICE_RADIOLESS_RANGE)
			continue
		if(other.stealth_radio_ready() && can_report(other))
			return TRUE
	return FALSE
