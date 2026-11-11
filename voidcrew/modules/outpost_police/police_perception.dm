/**
 * # Outpost police: witnesses
 *
 * Owner: P1. The whole "did anyone see it" test (owner decision 6, spec 3 and 18). This is the only police
 * file that names can_see, cyberware_camo_hides or a witness range; the stealth merge adds one subtype here
 * and changes one line in make_perception(), nothing else.
 *
 * A crime counts when witness_of() names a witness. report_crime() (police_wanted.dm) asks that one question,
 * asks report_delay() how long the witness takes to report and can_report() whether they still can. Today
 * sight within OUTPOST_POLICE_WITNESS_RANGE is all there is, the delay is 0 and a witness can always report.
 */

/// The witness test this police uses
/datum/outpost_police/proc/make_perception()
	// The stealth merge returns its subtype here, under #ifdef STEALTH_SIGHT_RANGE (spec 18)
	return new /datum/outpost_police_perception(src)

/**
 * Who, if anyone, witnessed `offender` doing `crime` to `victim` with `source`: POLICE_WITNESS_*. Sets
 * `last_witness`. Candidates in order: this outpost's officers, its traders and checkpoint guards, the
 * ambient people of its place, players not on the offender's crew (the victim first), then cameras. The first
 * that sees wins. Crimes done to an officer, and crimes the scanner or the cell see, need no one in sight.
 */
/datum/outpost_police_perception/proc/witness_of(mob/living/offender, crime, atom/victim, obj/item/source)
	last_witness = null
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
	for(var/mob/living/basic/outpost_trader/trader in police.outpost.traders)
		if(sees(trader, offender))
			last_witness = trader
			return POLICE_WITNESS_SAW
	var/datum/ambient_place/outpost/place = SSambient_npcs.outposts?[police.outpost]
	if(place)
		for(var/mob/living/carbon/human/npc/ambient_npc/person in place.npcs)
			if(sees(person, offender))
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
		var/dist = get_dist(officer, offender)
		if(!nearest || dist < nearest_dist)
			nearest = officer
			nearest_dist = dist
	return nearest

/**
 * Whether `viewer` (a conscious living mob, or a camera) sees `target` now: within the witness range with a
 * clear line, and not past the optical camo of a target an NPC or camera cannot spot. Also the test for
 * "an officer sees the suspect" (police_wanted.dm tick_warrants()).
 */
/datum/outpost_police_perception/proc/sees(atom/viewer, mob/living/target)
	if(QDELETED(viewer) || QDELETED(target))
		return FALSE
	var/mob/living/watcher = isliving(viewer) ? viewer : null
	if(watcher)
		if(watcher.stat != CONSCIOUS)
			return FALSE
	else if(!is_camera(viewer))
		return FALSE
	if(!can_see(viewer, target, OUTPOST_POLICE_WITNESS_RANGE))
		return FALSE
	// Optical camo fools AI and cameras; a player with eyes is not fooled
	if((!watcher || !watcher.mind) && cyberware_camo_hides(target, viewer))
		return FALSE
	return TRUE

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

/// Whether `witness` can still make its report
/datum/outpost_police_perception/proc/can_report(atom/witness)
	return TRUE
