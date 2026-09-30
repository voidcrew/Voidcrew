/**
 * # Prison interrogation: leads
 *
 * Owner: XG (extras-plan.md 4.16). Some prisoners know where an uncharted wreck sits: 30% of
 * arrivals carry a lead, and hint at it now and then while a member is near and the wing is ready
 * to give one. A member asks from the talk menu ("Heard anything?", offered on every prisoner so the
 * question gives nothing away); the answer lands on the asker's ship helm as a Rumors waypoint.
 *
 * A content prisoner tells the truth: a real space ruin the ship has not charted, seen or been told
 * about. An unhappy one may lie instead: a real-sounding ruin name and an empty spot on the
 * overmap. Lies are the owner's approved exception to "deceptions are atmosphere", and every one
 * can be caught:
 * - mood shows who might lie, and a prisoner under OUTPOST_PRISON_LEAD_REFUSE_MOOD refuses outright;
 * - a liar usually shows a tell when answering (an honest teller now and then does too);
 * - a content prisoner who saw it may call it out a few seconds later;
 * - any other prisoner who was in the wing can be asked about the tip for a while ("About that tip");
 * - true tips never point at anything the ship has charted, seen or flown past, so a tip at a spot
 *   the helm already knows is empty is a lie;
 * - flying within sight of a lie renames its waypoint "nothing there", and the liar owns up when
 *   the asker next comes by.
 * At most one lead per wing per OUTPOST_PRISON_LEAD_GAP, stored as a ready time that nothing but a
 * given lead moves. Numbers in voidcrew/_DEFINES/outpost_prison_leads.dm.
 */

/// The talk menu's question, offered on every prisoner
#define LEAD_ASK_CHOICE "Heard anything?"
/// The talk menu's question about the newest tip a prisoner saw given
#define LEAD_TIP_CHOICE "About that tip"
/// This package's dialogue file (tells and fake names; its "lines" are found by context name)
#define LEAD_DIALOGUE_FILE "outpost_prison_leads.json"

/// Lies given anywhere this round, so every lie's waypoint key is unique on any ship's helm
GLOBAL_VAR_INIT(outpost_prison_lead_lies, 0)

/mob/living/basic/outpost_prisoner
	/// Knows where something is, until they tell it (leads_prisoner_admitted())
	var/carries_lead = FALSE
	/// A member is putting a question about leads to them right now
	var/lead_questioned = FALSE
	/// Between questions about what they know
	COOLDOWN_DECLARE(lead_ask_cooldown)

/datum/outpost_prison
	/// world.time the wing may give its next lead. Only a given lead moves it; intake and admission never do.
	var/lead_ready_at = 0
	/// Leads given in the last OUTPOST_PRISON_LEAD_TRACK_TIME, oldest first, at most OUTPOST_PRISON_LEAD_OPEN_MAX
	var/list/datum/outpost_prison_lead/open_leads = list()
	/// Seconds since the open lies were last checked against their ships
	var/lead_check_clock = 0
	/// Tests only: TRUE or FALSE decides every hint, tell and gossip roll
	var/lead_test_roll = null

/// One tip a prisoner gave, true or not, kept while the wing tracks it
/datum/outpost_prison_lead
	var/datum/weakref/teller_ref
	/// The teller's full name, for the helm and the log, and first name, for the yard's lines
	var/teller_name
	var/teller_first_name
	var/datum/weakref/asker_ref
	var/asker_name
	var/datum/weakref/ship_ref
	var/ship_name
	/// The waypoint's source key on that ship's helm
	var/waypoint_key
	/// The ruin's name as told, and the band's name
	var/place
	var/band_name
	/// Relative overmap coordinates of the mark
	var/target_x = 0
	var/target_y = 0
	var/lie = FALSE
	/// A lie the ship has flown within sight of
	var/exposed = FALSE
	/// The liar has owned up to the asker (or never will: they left the wing)
	var/caught_said = FALSE
	/// world.time it was given
	var/given_at = 0
	/// The other prisoners in the wing when it was given, who can be asked about it
	var/list/datum/weakref/witnesses = list()
	/// Those of them who have answered for it
	var/list/datum/weakref/vouched = list()

// ===== CARRIERS =====

/// A prisoner was booked in: some carry a lead
/datum/outpost_prison/proc/leads_prisoner_admitted(mob/living/basic/outpost_prisoner/prisoner)
	prisoner.carries_lead = prob(OUTPOST_PRISON_LEAD_CHANCE)

/// Their tips stay on the helms and in the tracking by name; a liar who has gone never owns up
/datum/outpost_prison/proc/leads_prisoner_leaving(mob/living/basic/outpost_prisoner/prisoner)
	prisoner.carries_lead = FALSE

/// Whether the wing's gap between leads is over
/datum/outpost_prison/proc/lead_ready()
	return world.time >= lead_ready_at

/// prob() for hints, tells and gossip; lead_test_roll decides it in tests
/datum/outpost_prison/proc/lead_roll(chance)
	if(!isnull(lead_test_roll))
		return !!lead_test_roll
	return prob(chance)

/datum/outpost_prison/proc/lead_member_in_view(mob/living/basic/outpost_prisoner/prisoner, range)
	for(var/mob/living/person in view(range, prisoner))
		if(person.stat == CONSCIOUS && is_member(person))
			return TRUE
	return FALSE

// ===== SPEECH AND EXAMINE =====

/// A carrier hints at what they know, while the wing is ready to give a lead and a member is near
/datum/outpost_prison/proc/leads_extra_speech(mob/living/basic/outpost_prisoner/prisoner)
	if(!prisoner.carries_lead || !lead_ready())
		return null
	if(!lead_member_in_view(prisoner, OUTPOST_PRISON_LEAD_HINT_RANGE) || !lead_roll(OUTPOST_PRISON_LEAD_HINT_CHANCE))
		return null
	return list("lead_hint", null)

/// Nothing: mood (XB's examine) and the tells as they answer are what there is to read
/datum/outpost_prison/proc/leads_examine(mob/living/basic/outpost_prisoner/prisoner, mob/user)
	return null

// ===== THE TALK MENU =====

/// "Heard anything?" on every prisoner, and "About that tip" on those who saw a recent one given; members only
/datum/outpost_prison/proc/leads_talk_choices(mob/living/basic/outpost_prisoner/prisoner, mob/living/user)
	var/list/choices = list()
	if(!prisoner || !user || !is_member(user))
		return choices
	choices[LEAD_ASK_CHOICE] = image(icon = 'voidcrew/icons/hud/radial.dmi', icon_state = "radial_rumour")
	if(lead_newest_vouchable(prisoner))
		choices[LEAD_TIP_CHOICE] = image(icon = 'voidcrew/icons/hud/radial.dmi', icon_state = "radial_tip")
	return choices

/// Runs a talk menu choice of this package; TRUE if it was one. May sleep.
/datum/outpost_prison/proc/leads_talk_act(mob/living/basic/outpost_prisoner/prisoner, mob/living/user, choice)
	if(choice == LEAD_ASK_CHOICE)
		lead_ask(prisoner, user)
		return TRUE
	if(choice == LEAD_TIP_CHOICE)
		var/datum/outpost_prison_lead/lead = lead_newest_vouchable(prisoner)
		if(!lead)
			prisoner.balloon_alert(user, "nothing to add")
			return TRUE
		lead_ask_about(prisoner, user, lead)
		return TRUE
	return FALSE

/// The newest tip `prisoner` can be asked about (lead_vouchable()), or null
/datum/outpost_prison/proc/lead_newest_vouchable(mob/living/basic/outpost_prisoner/prisoner)
	var/list/vouchable = lead_vouchable(prisoner)
	return length(vouchable) ? vouchable[length(vouchable)] : null

/// Open leads `prisoner` saw given, recent enough to ask about, that they did not give and have not answered for
/datum/outpost_prison/proc/lead_vouchable(mob/living/basic/outpost_prisoner/prisoner)
	var/list/found = list()
	var/datum/weakref/prisoner_ref = WEAKREF(prisoner)
	for(var/datum/outpost_prison_lead/lead as anything in open_leads)
		if(world.time - lead.given_at > OUTPOST_PRISON_LEAD_VOUCH_TIME || lead.teller_ref == prisoner_ref)
			continue
		if(!(prisoner_ref in lead.witnesses) || (prisoner_ref in lead.vouched))
			continue
		found += lead
	return found

/// Whether `user` may put a question to `prisoner` now; shows or says why not
/datum/outpost_prison/proc/lead_can_ask(mob/living/basic/outpost_prisoner/prisoner, mob/living/user)
	if(QDELETED(prisoner) || QDELETED(user) || prisoner.prison != src || prisoner.phase != PRISONER_PRESENT || prisoner.stat != CONSCIOUS)
		return FALSE
	if(!is_member(user))
		prisoner.balloon_alert(user, "not your prisoner")
		return FALSE
	// Not talking: the talk menu may hold that while it hands this question over.
	if(prisoner.lead_questioned || prisoner.trouble || prisoner.fight || prisoner.threat_ref || prisoner.swing_ref || prisoner.climb_ref || prisoner.beaten_left > 0)
		prisoner.balloon_alert(user, "they're busy")
		return FALSE
	if(!prisoner.will_listen())
		prisoner.face_atom(user)
		prisoner.say_context("talk_refuse")
		prisoner.balloon_alert(user, "not listening")
		return FALSE
	return TRUE

/// A few seconds face to face, as a talk-down takes; FALSE if it was cut short or they stopped listening
/datum/outpost_prison/proc/lead_face_to_face(mob/living/basic/outpost_prisoner/prisoner, mob/living/user, self_message)
	prisoner.lead_questioned = TRUE
	// Put back as found: the talk menu may already hold it and clear it itself.
	var/was_talking = prisoner.talking
	prisoner.talking = TRUE
	prisoner.ai_controller?.CancelActions()
	prisoner.face_atom(user)
	user.face_atom(prisoner)
	user.visible_message(span_notice("[user] asks [prisoner] something quietly."), span_notice(self_message))
	var/finished = do_after(user, OUTPOST_PRISON_LEAD_ASK_TIME, target = prisoner)
	if(!QDELETED(prisoner))
		prisoner.lead_questioned = FALSE
		prisoner.talking = was_talking
	if(!finished || QDELETED(prisoner) || QDELETED(user) || prisoner.prison != src || prisoner.stat != CONSCIOUS || prisoner.phase != PRISONER_PRESENT)
		return FALSE
	if(!prisoner.will_listen())
		prisoner.say_context("talk_refuse")
		return FALSE
	prisoner.face_atom(user)
	return TRUE

/// "Heard anything?": the checks and the talk, then give_lead() for the asker's ship
/datum/outpost_prison/proc/lead_ask(mob/living/basic/outpost_prisoner/prisoner, mob/living/user)
	if(!lead_can_ask(prisoner, user))
		return FALSE
	if(!get_crew_ship(user))
		prisoner.face_atom(user)
		prisoner.say_context("lead_no_ship")
		return FALSE
	if(!COOLDOWN_FINISHED(prisoner, lead_ask_cooldown))
		prisoner.balloon_alert(user, "asked recently")
		return FALSE
	if(!lead_face_to_face(prisoner, user, "You ask [prisoner] what they know."))
		return FALSE
	COOLDOWN_START(prisoner, lead_ask_cooldown, OUTPOST_PRISON_LEAD_ASK_COOLDOWN)
	// Looked up again: the ship could have gone in those seconds.
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!ship)
		prisoner.say_context("lead_no_ship")
		return FALSE
	give_lead(prisoner, ship, user)
	return TRUE

/// "About that tip": the checks and the talk, then lead_vouch()
/datum/outpost_prison/proc/lead_ask_about(mob/living/basic/outpost_prisoner/prisoner, mob/living/user, datum/outpost_prison_lead/lead)
	if(!lead_can_ask(prisoner, user))
		return FALSE
	if(!(lead in lead_vouchable(prisoner)))
		prisoner.balloon_alert(user, "nothing to add")
		return FALSE
	if(!lead_face_to_face(prisoner, user, "You ask [prisoner] about [lead.teller_first_name]'s tip."))
		return FALSE
	lead_vouch(prisoner, lead, user)
	return TRUE

// ===== GIVING A LEAD =====

/// Whether `asker` hit `prisoner` unprovoked in the last OUTPOST_PRISON_LEAD_HIT_MEMORY
/datum/outpost_prison/proc/lead_hit_by(mob/living/basic/outpost_prisoner/prisoner, mob/asker)
	if(prisoner.last_hit_justified || !prisoner.last_staff_hit)
		return FALSE
	if(world.time - prisoner.last_staff_hit > OUTPOST_PRISON_LEAD_HIT_MEMORY)
		return FALSE
	return prisoner.last_staff_attacker_ref?.resolve() == asker

/// Percent chance `prisoner` lies to `asker`: none when content, then by mood, the asker's name in the yard and personality
/datum/outpost_prison/proc/lead_lie_chance(mob/living/basic/outpost_prisoner/prisoner, mob/asker)
	if(prisoner.mood >= OUTPOST_PRISON_LEAD_TRUE_MOOD)
		return 0
	var/chance = prisoner.mood < OUTPOST_PRISON_LEAD_HOSTILE_MOOD ? OUTPOST_PRISON_LEAD_LIE_HOSTILE : OUTPOST_PRISON_LEAD_LIE_UNEASY
	switch(staff_label(asker))
		if("brute")
			chance += OUTPOST_PRISON_LEAD_BRUTE_LIE
		if("fair")
			chance -= OUTPOST_PRISON_LEAD_FAIR_LIE
	switch(prisoner.personality)
		if("grumpy")
			chance *= OUTPOST_PRISON_LEAD_GRUMPY_LIE_MULT
		if("nervous")
			chance *= OUTPOST_PRISON_LEAD_NERVOUS_LIE_MULT
	return clamp(chance, 0, 100)

/**
 * The answer to "Heard anything?", once the talk is done. They refuse (after a recent unprovoked
 * hit by the asker, or under OUTPOST_PRISON_LEAD_REFUSE_MOOD, keeping the lead either way), have
 * nothing (not a carrier, or the wing's gap is running: the same line for both), have nothing left
 * (no ruin to tell of: the lead and the gap are kept), or tell: the truth, or a lie by
 * lead_lie_chance(), which `force_lie` (tests) decides instead. Returns "invalid", "refuse_hit",
 * "refuse", "none", "nothing", "truth" or "lie".
 */
/datum/outpost_prison/proc/give_lead(mob/living/basic/outpost_prisoner/prisoner, obj/structure/overmap/ship/ship, mob/living/asker, force_lie = null)
	if(QDELETED(prisoner) || prisoner.prison != src || prisoner.phase != PRISONER_PRESENT || prisoner.stat != CONSCIOUS)
		return "invalid"
	if(QDELETED(ship) || QDELETED(asker))
		return "invalid"
	prisoner.face_atom(asker)
	if(lead_hit_by(prisoner, asker))
		prisoner.say_context("lead_refuse_hit")
		return "refuse_hit"
	// Before the carrier check, so a sour prisoner's refusal says nothing about whether they know anything
	if(prisoner.mood < OUTPOST_PRISON_LEAD_REFUSE_MOOD)
		prisoner.say_context("lead_refuse")
		return "refuse"
	if(!prisoner.carries_lead || !lead_ready())
		prisoner.say_context("lead_none")
		return "none"
	var/list/candidates = lead_candidates(ship)
	if(!length(candidates))
		prisoner.say_context("lead_nothing")
		return "nothing"

	var/lie = isnull(force_lie) ? prob(lead_lie_chance(prisoner, asker)) : !!force_lie
	var/datum/outpost_prison_lead/lead = new
	var/list/spot = lie ? lead_lie_spot(ship, candidates) : null
	var/obj/structure/overmap/space_ruin/ruin
	var/band
	if(spot)
		lead.lie = TRUE
		lead.target_x = spot[1]
		lead.target_y = spot[2]
		band = spot[3]
		lead.place = lead_fake_name()
		GLOB.outpost_prison_lead_lies++
		lead.waypoint_key = "prison_lead_lie_[GLOB.outpost_prison_lead_lies]"
	else
		// The truth, which is also what a would-be liar tells with nowhere fair to point
		ruin = pick(candidates)
		var/list/coords = ruin.get_relative_overmap_coords()
		lead.target_x = coords[1]
		lead.target_y = coords[2]
		band = outpost_lead_band(get_turf(ruin))
		lead.place = ruin.true_name || ruin.name
		lead.waypoint_key = "prison_lead_[REF(ruin)]"
	lead.band_name = outpost_lead_band_name(band)
	// Tracked to the ruin when true, as a bought tip is; the helm draws both the same
	ship.add_waypoint(lead.waypoint_key, "[prisoner.real_name]'s tip: [lead.place] ([lead.band_name])", lead.target_x, lead.target_y, "Rumors", ruin)
	lead.teller_ref = WEAKREF(prisoner)
	lead.teller_name = prisoner.real_name
	lead.teller_first_name = prisoner.speech_name()
	lead.asker_ref = WEAKREF(asker)
	lead.asker_name = asker.name
	lead.ship_ref = WEAKREF(ship)
	lead.ship_name = ship.name
	lead.given_at = world.time
	for(var/mob/living/basic/outpost_prisoner/other in prisoners)
		if(other != prisoner && other.phase == PRISONER_PRESENT)
			lead.witnesses += WEAKREF(other)

	// The same words and the same mark either way; only the tell and the yard give a lie away here.
	var/band_phrase = outpost_lead_band_phrase(band)
	prisoner.say_context_with("lead_tell", list("{place}" = lead.place, "{band}" = band_phrase))
	to_chat(asker, span_notice("A new mark lands on [ship.name]'s helm: [lead.place] at ([lead.target_x], [lead.target_y]), in [band_phrase]."))
	if(lead_roll(lead.lie ? OUTPOST_PRISON_LEAD_TELL_LIE : OUTPOST_PRISON_LEAD_TELL_TRUTH))
		lead_tell_emote(prisoner)

	prisoner.carries_lead = FALSE
	lead_ready_at = world.time + OUTPOST_PRISON_LEAD_GAP
	add_log("[prisoner.real_name] gave [asker.name] a tip.")
	open_leads += lead
	if(length(open_leads) > OUTPOST_PRISON_LEAD_OPEN_MAX)
		open_leads.Cut(1, 2)
	addtimer(CALLBACK(src, PROC_REF(lead_gossip), WEAKREF(lead)), rand(OUTPOST_PRISON_LEAD_GOSSIP_DELAY_MIN, OUTPOST_PRISON_LEAD_GOSSIP_DELAY_MAX))
	return lead.lie ? "lie" : "truth"

/// A tell as they answer: an emote from the dialogue file's "tells", their personality's more often than the shared ones
/datum/outpost_prison/proc/lead_tell_emote(mob/living/basic/outpost_prisoner/prisoner)
	var/list/tells = outpost_prisoner_extra_dialogue(LEAD_DIALOGUE_FILE, "tells")
	var/list/own = prisoner.personality ? tells[prisoner.personality] : null
	var/list/shared = tells["any"]
	var/list/pool = (length(own) && prob(60)) ? own : shared
	if(!length(pool))
		pool = own
	if(!length(pool))
		return FALSE
	prisoner.manual_emote(pick(pool))
	return TRUE

// ===== WHAT A LEAD CAN POINT AT =====

/**
 * The ruins a true lead to `ship` can name: plain space ruins only (never the contested cache, a
 * lich lair or a vestige), never a rare one (it belongs to whoever bought its chart) or one a
 * mission holds, on the overmap, and nothing the ship already knows: not on its helm under any key
 * a tip or a scan uses, not seen or charted, not on a tile it has flown past, not in sight now.
 */
/datum/outpost_prison/proc/lead_candidates(obj/structure/overmap/ship/ship)
	var/list/candidates = list()
	if(QDELETED(ship))
		return candidates
	var/list/ship_position = outpost_lead_ship_position(ship)
	for(var/obj/structure/overmap/space_ruin/ruin in GLOB.space_ruin_signals)
		if(lead_is_candidate(ruin, ship, ship_position))
			candidates += ruin
	return candidates

/datum/outpost_prison/proc/lead_is_candidate(obj/structure/overmap/space_ruin/ruin, obj/structure/overmap/ship/ship, list/ship_position)
	if(QDELETED(ruin) || ruin.type != /obj/structure/overmap/space_ruin)
		return FALSE
	if(ruin.rare || ruin.mission_locked || ruin.mission_exclusive)
		return FALSE
	if(!istype(get_turf(ruin), /turf/open/overmap))
		return FALSE
	var/key = REF(ruin)
	if(ship.get_waypoint(key) || ship.get_waypoint("rumor_[key]") || ship.get_waypoint("prison_lead_[key]"))
		return FALSE
	if(LAZYACCESS(ship.discovered_contacts, key))
		return FALSE
	var/list/coords = ruin.get_relative_overmap_coords()
	if(!outpost_lead_coords_valid(coords) || ship.is_tile_surveyed(coords[1], coords[2]))
		return FALSE
	if(ship_position && in_view_ring(ship_position, coords))
		return FALSE
	return TRUE

/**
 * Where a lie points: list(x, y, band) in relative overmap coordinates, or null when no tile is
 * fair. The band is drawn with the weights of the true candidates' bands, so a lie is no likelier
 * than the truth to send a crew into the deep; bands with no clear tile are left out of the draw.
 */
/datum/outpost_prison/proc/lead_lie_spot(obj/structure/overmap/ship/ship, list/candidates)
	var/list/spots_by_band = lead_lie_spots(outpost_lead_ship_position(ship))
	var/list/band_weights = list()
	for(var/obj/structure/overmap/space_ruin/ruin as anything in candidates)
		var/band_key = "[outpost_lead_band(get_turf(ruin))]"
		if(length(spots_by_band[band_key]))
			band_weights[band_key] += 1
	if(!length(band_weights))
		return null
	var/band_key = pick_weight(band_weights)
	var/list/spot = pick(spots_by_band[band_key])
	return list(spot[1], spot[2], text2num(band_key))

/**
 * Every tile a lie may point at, as band ("1") -> list of list(x, y): in the flyable part of the
 * overmap, with nothing on it, no ruin, planet or player outpost within SHIP_VIEW_RANGE, and out
 * of sight of `ship_position` (null when the ship is not on the overmap). A crew that flies there
 * sees nothing that could pass for the place they were told of. One pass over the chart, as a
 * bought star chart's; it runs once per lie, and a wing gives at most one lead per
 * OUTPOST_PRISON_LEAD_GAP.
 */
/datum/outpost_prison/proc/lead_lie_spots(list/ship_position)
	var/list/in_sight = new /list(OVERMAP_SIZE * OVERMAP_SIZE)
	for(var/obj/structure/overmap/site in GLOB.overmap_objects)
		if(QDELETED(site) || !site.sensor_detectable)
			continue
		var/turf/site_turf = get_turf(site)
		if(site_turf?.z != OVERMAP_Z_LEVEL)
			continue
		var/list/coords = site.get_relative_overmap_coords()
		if(outpost_lead_coords_valid(coords))
			outpost_lead_stamp_sight(in_sight, coords)
	if(ship_position)
		outpost_lead_stamp_sight(in_sight, ship_position)
	var/list/spots_by_band = list()
	for(var/tile_x in 2 to OVERMAP_SIZE - 1)
		for(var/tile_y in 2 to OVERMAP_SIZE - 1)
			if(in_sight[(tile_y - 1) * OVERMAP_SIZE + tile_x])
				continue
			var/turf/open/overmap/tile = outpost_lead_overmap_turf(tile_x, tile_y)
			if(!istype(tile) || (locate(/obj/structure/overmap) in tile))
				continue
			var/band_key = "[outpost_lead_band(tile)]"
			if(!spots_by_band[band_key])
				spots_by_band[band_key] = list()
			spots_by_band[band_key] += list(list(tile_x, tile_y))
	return spots_by_band

/// A lie's ruin name: a space ruin that turns up naturally but is not on the overmap now, so the name alone gives nothing away
/datum/outpost_prison/proc/lead_fake_name()
	var/list/on_map = list()
	for(var/obj/structure/overmap/space_ruin/ruin in GLOB.space_ruin_signals)
		if(QDELETED(ruin))
			continue
		if(ruin.true_name)
			on_map[ruin.true_name] = TRUE
		on_map[ruin.name] = TRUE
	var/list/names = list()
	for(var/template_name in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/template = SSmapping.space_ruins_templates[template_name]
		if(!istype(template) || template.unpickable || !istext(template.name) || on_map[template.name])
			continue
		names += template.name
	if(!length(names))
		for(var/fallback in outpost_prisoner_extra_dialogue(LEAD_DIALOGUE_FILE, "fake_names"))
			if(istext(fallback) && !on_map[fallback])
				names += fallback
	return length(names) ? pick(names) : "an old wreck"

// ===== THE YARD'S WORD =====

/// A few seconds after a tip, a content prisoner who saw it may say whether it holds up
/datum/outpost_prison/proc/lead_gossip(datum/weakref/lead_ref)
	var/datum/outpost_prison_lead/lead = lead_ref?.resolve()
	if(!lead || !(lead in open_leads))
		return FALSE
	var/mob/living/basic/outpost_prisoner/teller = lead.teller_ref?.resolve()
	var/mob/living/asker = lead.asker_ref?.resolve()
	if(QDELETED(teller) || QDELETED(asker) || teller.prison != src)
		return FALSE
	if(!lead_roll(OUTPOST_PRISON_LEAD_GOSSIP_CHANCE))
		return FALSE
	for(var/mob/living/basic/outpost_prisoner/other in shuffle(prisoners))
		if(other == teller || other.stat != CONSCIOUS || other.phase != PRISONER_PRESENT || other.trouble || other.mood < OUTPOST_PRISON_LEAD_GOSSIP_MOOD)
			continue
		var/list/seen = view(OUTPOST_PRISON_LEAD_GOSSIP_RANGE, other)
		if(!(teller in seen) || !(asker in seen))
			continue
		other.face_atom(teller)
		return other.say_context_with(lead.lie ? "lead_gossip_lie" : "lead_gossip_true", list("{teller}" = lead.teller_first_name))
	return FALSE

/**
 * What `prisoner` says when `asker` asks about `lead`: content ones tell the truth about it, the
 * middling aren't sure, and the sour and anyone the asker hit refuse (they can be asked again
 * later). Returns "refuse_hit", "refuse", "unsure", "true" or "lie" (what they said the tip was).
 */
/datum/outpost_prison/proc/lead_vouch(mob/living/basic/outpost_prisoner/prisoner, datum/outpost_prison_lead/lead, mob/living/asker)
	prisoner.face_atom(asker)
	if(lead_hit_by(prisoner, asker))
		prisoner.say_context("lead_refuse_hit")
		return "refuse_hit"
	if(prisoner.mood < OUTPOST_PRISON_LEAD_REFUSE_MOOD)
		prisoner.say_context("lead_refuse")
		return "refuse"
	lead.vouched |= WEAKREF(prisoner)
	var/list/values = list("{teller}" = lead.teller_first_name)
	if(prisoner.mood < OUTPOST_PRISON_LEAD_GOSSIP_MOOD)
		prisoner.say_context_with("lead_vouch_unsure", values)
		return "unsure"
	prisoner.say_context_with(lead.lie ? "lead_vouch_lie" : "lead_vouch_true", values)
	return lead.lie ? "lie" : "true"

// ===== IN FLIGHT =====

/// Every OUTPOST_PRISON_LEAD_CHECK_INTERVAL seconds: drops old leads and those whose ship is gone, exposes lies a ship has flown to, and has caught liars own up
/datum/outpost_prison/proc/leads_tick(seconds)
	if(!length(open_leads))
		lead_check_clock = 0
		return
	lead_check_clock += seconds
	if(lead_check_clock < OUTPOST_PRISON_LEAD_CHECK_INTERVAL)
		return
	lead_check_clock = 0
	for(var/datum/outpost_prison_lead/lead as anything in open_leads.Copy())
		var/obj/structure/overmap/ship/ship = lead.ship_ref?.resolve()
		if(QDELETED(ship) || world.time - lead.given_at > OUTPOST_PRISON_LEAD_TRACK_TIME)
			open_leads -= lead
			continue
		if(lead.lie && !lead.exposed)
			lead_check_exposed(lead, ship)
		if(lead.exposed && !lead.caught_said)
			lead_caught_line(lead)

/// A lie's ship is within sight of the spot: the mark says so, and so does the log
/datum/outpost_prison/proc/lead_check_exposed(datum/outpost_prison_lead/lead, obj/structure/overmap/ship/ship)
	var/list/position = outpost_lead_ship_position(ship)
	if(!position || !in_view_ring(position, list(lead.target_x, lead.target_y)))
		return FALSE
	lead.exposed = TRUE
	var/datum/ship_waypoint/waypoint = ship.get_waypoint(lead.waypoint_key)
	if(waypoint)
		waypoint.name = "[lead.teller_name]'s tip: nothing there"
		ship.contact_snapshot = null
	add_log("[lead.teller_name]'s tip was a lie.")
	return TRUE

/// A caught liar still in the wing owns up once the asker comes within OUTPOST_PRISON_LEAD_CAUGHT_RANGE
/datum/outpost_prison/proc/lead_caught_line(datum/outpost_prison_lead/lead)
	var/mob/living/basic/outpost_prisoner/teller = lead.teller_ref?.resolve()
	if(QDELETED(teller) || teller.prison != src)
		lead.caught_said = TRUE
		return FALSE
	var/mob/living/asker = lead.asker_ref?.resolve()
	if(QDELETED(asker) || teller.stat != CONSCIOUS || teller.phase != PRISONER_PRESENT)
		return FALSE
	if(!(asker in view(OUTPOST_PRISON_LEAD_CAUGHT_RANGE, teller)))
		return FALSE
	teller.face_atom(asker)
	if(!teller.say_context("lead_lie_caught"))
		return FALSE
	lead.caught_said = TRUE
	return TRUE

/datum/outpost_prison/proc/leads_destroy()
	open_leads.Cut()
	lead_check_clock = 0

// ===== ADMIN =====

/// The admin panel's leads block: {ready_in, carriers: [ref], open: [{teller, ship, name, lie, exposed, age}]}; times in seconds
/datum/outpost_prison/proc/leads_admin_payload()
	var/list/carriers = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.carries_lead)
			carriers += REF(prisoner)
	var/list/open = list()
	for(var/datum/outpost_prison_lead/lead as anything in open_leads)
		open += list(list(
			"teller" = lead.teller_name,
			"ship" = lead.ship_name,
			"name" = lead.place,
			"lie" = lead.lie,
			"exposed" = lead.exposed,
			"age" = round((world.time - lead.given_at) / (1 SECONDS)),
		))
	return list(
		"ready_in" = lead_ready() ? null : round((lead_ready_at - world.time) / (1 SECONDS)),
		"carriers" = carriers,
		"open" = open,
	)

/// prison_lead {ref}: that prisoner carries a lead and the wing is ready to give one
/datum/outpost_prison/proc/leads_admin_act(action, list/params, mob/user)
	if(action != "prison_lead")
		return null
	var/ref = params ? params["ref"] : null
	var/mob/living/basic/outpost_prisoner/prisoner = istext(ref) ? (locate(ref) in prisoners) : null
	if(QDELETED(prisoner))
		return list("error" = "No such prisoner.")
	prisoner.carries_lead = TRUE
	lead_ready_at = 0
	return "give prisoner [prisoner.real_name] a lead to tell, with the wing ready to give it"

// ===== OVERMAP HELPERS =====

/// The overmap turf at relative overmap coordinates (1 to OVERMAP_SIZE), or null
/proc/outpost_lead_overmap_turf(rel_x, rel_y)
	if(rel_x < 1 || rel_x > OVERMAP_SIZE || rel_y < 1 || rel_y > OVERMAP_SIZE)
		return null
	return locate(OVERMAP_LEFT_SIDE_COORD + rel_x - 1, OVERMAP_SOUTH_SIDE_COORD + rel_y - 1, OVERMAP_Z_LEVEL)

/// Whether `coords` are relative overmap coordinates on the chart
/proc/outpost_lead_coords_valid(list/coords)
	return length(coords) >= 2 && coords[1] >= 1 && coords[1] <= OVERMAP_SIZE && coords[2] >= 1 && coords[2] <= OVERMAP_SIZE

/// Where `ship` is on the overmap in relative coordinates (a docked ship is where it docked), or null when it is not on it
/proc/outpost_lead_ship_position(obj/structure/overmap/ship/ship)
	var/turf/ship_turf = get_turf(ship)
	if(ship_turf?.z != OVERMAP_Z_LEVEL)
		return null
	var/list/coords = ship.get_relative_overmap_coords()
	return outpost_lead_coords_valid(coords) ? coords : null

/// The zone band an overmap tile lies in (ZONE_GREEN and so on), or 0 when it has none
/proc/outpost_lead_band(turf/tile)
	return SSovermap_zones?.get_zone_type(tile) || 0

/// A band's name on a waypoint: "Contested Zone"
/proc/outpost_lead_band_name(band)
	switch(band)
		if(ZONE_GREEN)
			return ZONE_NAME_GREEN
		if(ZONE_YELLOW)
			return ZONE_NAME_YELLOW
		if(ZONE_RED)
			return ZONE_NAME_RED
	return "uncharted"

/// A band as prisoners say it: "the Contested Zone"
/proc/outpost_lead_band_phrase(band)
	switch(band)
		if(ZONE_GREEN, ZONE_YELLOW, ZONE_RED)
			return "the [outpost_lead_band_name(band)]"
	return "uncharted space"

/// Marks every tile of `grid` (OVERMAP_SIZE squared, by relative coordinates) within SHIP_VIEW_RANGE of `center`, across the seams, as the helm's sight does
/proc/outpost_lead_stamp_sight(list/grid, list/center)
	for(var/offset_x in -SHIP_VIEW_RANGE to SHIP_VIEW_RANGE)
		for(var/offset_y in -SHIP_VIEW_RANGE to SHIP_VIEW_RANGE)
			if(offset_x * offset_x + offset_y * offset_y > SHIP_VIEW_RANGE * SHIP_VIEW_RANGE)
				continue
			var/tile_x = overmap_wrap_x(center[1] + OVERMAP_LEFT_SIDE_COORD - 1 + offset_x) - OVERMAP_LEFT_SIDE_COORD + 1
			var/tile_y = overmap_wrap_y(center[2] + OVERMAP_SOUTH_SIDE_COORD - 1 + offset_y) - OVERMAP_SOUTH_SIDE_COORD + 1
			grid[(tile_y - 1) * OVERMAP_SIZE + tile_x] = TRUE

#undef LEAD_ASK_CHOICE
#undef LEAD_TIP_CHOICE
#undef LEAD_DIALOGUE_FILE
