/**
 * # Prison mail call
 *
 * Owner: XF (extras-plan.md 4.15). Mail comes in waves (owner, 2026-09-25): every
 * OUTPOST_MAIL_WAVE_GAP_MIN to _MAX of the crew being home, tg's supply pod drops tg's mail crate
 * into the warden's office, holding letters for a share of the prisoners (mail_wave_recipients()) and
 * nothing else (owner: "mail should come in the mail crate"). An empty crate stays a crate. The
 * pod is harmless: no explosion, damage, stun or sparks, and it never lands on anyone, on anything
 * dense or in the cell block. A member carries each letter to its prisoner, by hand or on a serving
 * hatch, and the prisoner reads it on the spot: good news, bad news, a drawing from a kid. Opening a
 * letter first shows what it says and anything packed in it, at the cost of that prisoner's trust.
 * Letters never lie. The pod aims for the office side of the first serving hatch
 * (mail_office_spot()); an admin's single letter beams onto the office table nearest it. Numbers in
 * voidcrew/_DEFINES/outpost_prison_contraband.dm.
 *
 * A letter is tg's envelope (/obj/item/mail/envelope, so sorters and disposals treat it as mail)
 * holding the letter itself and, for a contraband letter, a razor blade or a packet of yeast. The
 * prison tracks the letter paper by weakref from arrival (the crate landing) until it is read,
 * returned, lost off the level or its prisoner leaves. It never calls tg's initialize_for_recipient()
 * (goodies and money).
 *
 * The prisoner's side of a delivery by hand is an element on the prisoner (the prisoner's own
 * handler for item use already takes the signal), added from setup_contraband().
 */

// What an activity's tick() wants next, as in outpost_prison_routine.dm (which undefines its own)
#define ACTIVITY_CONTINUE 0
#define ACTIVITY_DONE 1
#define ACTIVITY_MOVE 2
/// The extra dialogue file that holds the letters and their senders
#define MAIL_STRINGS_FILE "outpost_prison_contraband.json"

/// Letter kinds and how often each comes
GLOBAL_LIST_INIT(outpost_prison_mail_kinds, list(
	"good" = OUTPOST_MAIL_WEIGHT_GOOD,
	"kid" = OUTPOST_MAIL_WEIGHT_KID,
	"news" = OUTPOST_MAIL_WEIGHT_NEWS,
	"bad" = OUTPOST_MAIL_WEIGHT_BAD,
	"contraband" = OUTPOST_MAIL_WEIGHT_CONTRABAND,
))

// ===== STATE =====

/mob/living/basic/outpost_prisoner
	/// Whether a letter has come for them this stay; one each
	var/mail_had_letter = FALSE

/datum/outpost_prison
	/// Seconds of the crew being home until the next mail pod; set on the first tick
	var/mail_next_in
	/// Seconds since the letters were last looked for (off the level, on a hatch)
	var/mail_check_clock = 0
	/// Letters on their way, as weakrefs to the letter (inside its envelope until someone opens it)
	var/list/mail_letters = list()

// ===== THE MAIL POD =====

/// tg's supply pod, made harmless: no explosion, damage, stun or sparks. It drops its mail crate and leaves.
/obj/structure/closet/supplypod/outpost_prison_mail
	name = "mail pod"
	desc = "A small drop pod from the postal service. It drops its mail crate and flies off again."
	specialised = TRUE
	bluespace = TRUE
	explosionSize = list(0, 0, 0, 0)
	damage = 0
	effectStun = FALSE
	create_sparks = FALSE
	soundVolume = 50

// ===== THE LETTER =====

/// A letter from home for a prisoner, sealed in tg's envelope. Anyone may open it; its prisoner will know.
/obj/item/mail/envelope/outpost_prison
	name = "envelope"
	desc = "A letter from home for someone in the prison wing."
	/// Whether something small and hard can be felt through the paper
	var/hard_tell = FALSE

/obj/item/mail/envelope/outpost_prison/Initialize(mapload)
	. = ..()
	// A recipient nobody is: anyone may open it, and tg's mail code never meets a null (examine_more())
	recipient_ref = outpost_prison_blank_weakref()

/obj/item/mail/envelope/outpost_prison/examine(mob/user)
	. = ..()
	if(hard_tell)
		. += span_notice("Something small and hard is sealed inside.")

/obj/item/mail/envelope/outpost_prison/examine_more(mob/user)
	// tg's /obj/item/mail/examine_more() resolves recipient_ref with no null check (mail.dm)
	recipient_ref ||= outpost_prison_blank_weakref()
	. = ..()
	var/obj/item/paper/outpost_prison_letter/letter = locate() in src
	if(letter?.letter_addressee)
		. += span_info("It's addressed to [letter.letter_addressee], in the prison wing.")

/obj/item/mail/envelope/outpost_prison/after_unwrap(mob/user)
	// Marked opened before the parent puts the letter and anything packed with it in the opener's hands
	var/obj/item/paper/outpost_prison_letter/letter = locate() in src
	letter?.outpost_note_opened(user)
	return ..()

/// A weakref that never resolves, for tg mail whose recipient is nobody
/proc/outpost_prison_blank_weakref()
	var/static/datum/weakref/blank
	if(!blank)
		var/datum/placeholder = new
		blank = WEAKREF(placeholder)
		qdel(placeholder)
	return blank

/// The letter itself. Its text comes from the extras' letters, filled in for its prisoner.
/obj/item/paper/outpost_prison_letter
	name = "letter"
	/// The prison it came to, and the prisoner it is for (and their name, for once they are gone)
	var/datum/weakref/letter_prison_ref
	var/datum/weakref/letter_prisoner_ref
	var/letter_addressee
	/// "good", "kid", "news", "bad" or "contraband"
	var/letter_kind = "news"
	/// Whether a razor blade or yeast came sealed in with it
	var/letter_contraband = FALSE
	/// Whether someone opened it before it reached its prisoner, and who they looked like then
	var/letter_opened = FALSE
	var/letter_opened_by
	/// Seconds it has waited with the crew home
	var/letter_waited = 0

/// Someone opened the envelope before its prisoner got it. Returns TRUE the first time.
/obj/item/paper/outpost_prison_letter/proc/outpost_note_opened(mob/user)
	if(letter_opened)
		return FALSE
	letter_opened = TRUE
	letter_opened_by = user ? user.get_visible_name() : "someone"
	var/datum/outpost_prison/prison = letter_prison_ref?.resolve()
	prison?.mail_opened(src, user)
	return TRUE

/// The prison letter `thing` is, or holds sealed, if any
/proc/outpost_prison_letter_in(obj/item/thing)
	if(istype(thing, /obj/item/paper/outpost_prison_letter))
		return thing
	if(istype(thing, /obj/item/mail/envelope/outpost_prison))
		return locate(/obj/item/paper/outpost_prison_letter) in thing
	return null

/// What there is of `letter` to carry about: its envelope while it is sealed, else the letter itself
/proc/outpost_prison_letter_holder(obj/item/paper/outpost_prison_letter/letter)
	return istype(letter?.loc, /obj/item/mail/envelope/outpost_prison) ? letter.loc : letter

/// The mood a kind of letter gives its reader; contraband reads as news
/proc/outpost_prison_mail_mood(kind)
	switch(kind)
		if("good")
			return OUTPOST_MAIL_MOOD_GOOD
		if("kid")
			return OUTPOST_MAIL_MOOD_KID
		if("bad")
			return OUTPOST_MAIL_MOOD_BAD
	return OUTPOST_MAIL_MOOD_NEWS

/// What a reader says about a kind of letter
/proc/outpost_prison_mail_context(kind)
	switch(kind)
		if("good")
			return "mail_good"
		if("kid")
			return "mail_kid"
		if("bad")
			return "mail_bad"
	return "mail_news"

// ===== THE PRISON: ARRIVALS AND THE CLOCK =====

/// Mail pods, expiry, letters carried off the level and prisoners fetching mail from the hatches
/datum/outpost_prison/proc/mail_tick(seconds)
	if(isnull(mail_next_in))
		mail_next_in = mail_gap()
	// The mail clock and expiry count only while the crew is home to deliver it.
	if(crew_home())
		mail_next_in -= seconds
		if(mail_next_in <= 0)
			mail_next_in = mail_gap()
			mail_wave()
		mail_age(seconds)
	mail_check_clock += seconds
	if(mail_check_clock < OUTPOST_MAIL_CHECK)
		return
	mail_check_clock = 0
	mail_check()

/// Seconds of the crew being home before the next mail pod
/datum/outpost_prison/proc/mail_gap()
	return rand(OUTPOST_MAIL_WAVE_GAP_MIN, OUTPOST_MAIL_WAVE_GAP_MAX) / (1 SECONDS)

/// The letters still waiting to be read, forgetting any that are gone
/datum/outpost_prison/proc/mail_waiting_letters()
	var/list/waiting = list()
	for(var/datum/weakref/ref in mail_letters.Copy())
		var/obj/item/paper/outpost_prison_letter/letter = ref.resolve()
		if(QDELETED(letter))
			mail_letters -= ref
			continue
		waiting += letter
	return waiting

/// The letter waiting for `prisoner`, if any
/datum/outpost_prison/proc/mail_waiting_for(mob/living/basic/outpost_prisoner/prisoner)
	for(var/obj/item/paper/outpost_prison_letter/letter in mail_waiting_letters())
		if(letter.letter_prisoner_ref?.resolve() == prisoner)
			return letter
	return null

/**
 * Who a mail pod's letters are for: OUTPOST_MAIL_WAVE_SHARE_MIN to _MAX percent of the living
 * prisoners present, rounded, at least one and never all of them (a lone prisoner can still get
 * theirs). They are picked from those who are not loose, have OUTPOST_MAIL_MIN_SENTENCE left and
 * have had no letter this stay, so a wave may carry fewer. Returns the prisoners, maybe none.
 */
/datum/outpost_prison/proc/mail_wave_recipients()
	var/present = 0
	var/list/eligible = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase != PRISONER_PRESENT || prisoner.stat == DEAD)
			continue
		present++
		if(prisoner.trouble == PRISONER_TROUBLE_LOOSE || prisoner.mail_had_letter || prisoner.sentence_left < OUTPOST_MAIL_MIN_SENTENCE)
			continue
		eligible += prisoner
	var/list/picked = list()
	if(!length(eligible))
		return picked
	var/count = round(present * rand(OUTPOST_MAIL_WAVE_SHARE_MIN, OUTPOST_MAIL_WAVE_SHARE_MAX) / 100, 1)
	count = clamp(count, 1, max(1, present - 1))
	while(length(picked) < count && length(eligible))
		picked += pick_n_take(eligible)
	return picked

/**
 * Mail call: a harmless supply pod drops tg's mail crate, holding only letters for
 * mail_wave_recipients(), on mail_pod_landing_turf(). tg's populate() is never called, so no station
 * mail comes with them. The letters count as waiting from when the crate lands (mail_crate_moved()).
 * Returns how many letters are on their way, 0 when nobody is due one or the pod has nowhere to land.
 */
/datum/outpost_prison/proc/mail_wave()
	var/list/recipients = mail_wave_recipients()
	if(!length(recipients))
		return 0
	var/turf/spot = mail_pod_landing_turf()
	if(!spot)
		return 0
	var/obj/structure/closet/supplypod/outpost_prison_mail/pod = new()
	var/obj/structure/closet/crate/mail/crate = new(pod)
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in recipients)
		mail_make_letter(prisoner, null, null, crate)
	crate.update_appearance()
	RegisterSignal(crate, COMSIG_MOVABLE_MOVED, PROC_REF(mail_crate_moved))
	new /obj/effect/pod_landingzone(spot, pod)
	log_game("PLAYER OUTPOST PRISON: a mail pod with [length(recipients)] letter\s is coming down in the prison wing at '[outpost?.name]' ([spot.x],[spot.y],[spot.z])")
	return length(recipients)

/// A mail pod dropped its crate onto the floor: it has landed. Signal handler; never sleeps.
/datum/outpost_prison/proc/mail_crate_moved(obj/structure/closet/crate/mail/crate, atom/old_loc, dir, forced, list/old_locs)
	SIGNAL_HANDLER
	if(!isturf(crate.loc))
		return
	UnregisterSignal(crate, COMSIG_MOVABLE_MOVED)
	mail_wave_landed(crate)

/// A mail pod's crate came to rest: its letters count as waiting from now. Mail that came down off the wing's level is thrown away. Never sleeps.
/datum/outpost_prison/proc/mail_wave_landed(obj/structure/closet/crate/mail/crate)
	var/turf/spot = get_turf(crate)
	var/z = wing_z()
	var/count = 0
	var/list/envelopes = list()
	for(var/obj/item/mail/envelope/outpost_prison/envelope in crate)
		envelopes += envelope
	for(var/obj/item/mail/envelope/outpost_prison/envelope as anything in envelopes)
		var/obj/item/paper/outpost_prison_letter/letter = locate() in envelope
		if(!letter)
			continue
		if(!spot || (z && spot.z != z))
			qdel(envelope)
			continue
		mail_letters += WEAKREF(letter)
		count++
	if(count)
		add_log("Mail call: a pod dropped [count] letter\s.")
	return count

/**
 * Where a mail pod comes down: the free floor tile of the warden's office nearest mail_office_spot()
 * where a crate cuts nothing off (mail_office_stays_open()), or with none, the ground just outside
 * the wing's entrance. Never in the cell block. Null when there is nowhere.
 */
/datum/outpost_prison/proc/mail_pod_landing_turf()
	var/list/office = list()
	var/list/walkable = mail_office_walkable()
	for(var/turf/tile as anything in walkable)
		if(mail_pod_can_land(tile))
			office += tile
	var/turf/anchor = mail_office_spot()
	while(length(office))
		var/turf/best = mail_nearest_turf(office, anchor)
		if(mail_office_stays_open(walkable, best))
			return best
		office -= best
	var/turf/front = mail_entrance_front()
	if(!front)
		return null
	var/list/outside = list()
	for(var/turf/tile in range(2, front))
		if(!in_wing_bounds(tile) && mail_pod_can_land(tile))
			outside += tile
	return mail_nearest_turf(outside, front)

/**
 * Whether a mail pod may come down on `tile`: open floor with ground, nobody on it, nothing dense,
 * no machine or fixture, and no door on it or beside it, so a landed pod never blocks a doorway
 */
/datum/outpost_prison/proc/mail_pod_can_land(turf/tile)
	if(!isopenturf(tile) || isspaceturf(tile) || isgroundlessturf(tile) || tile.is_blocked_turf(exclude_mobs = FALSE))
		return FALSE
	if(locate(/mob/living) in tile)
		return FALSE
	for(var/obj/thing in tile)
		if(thing.density || istype(thing, /obj/machinery) || issupplypod(thing) || istype(thing, /obj/effect/pod_landingzone))
			return FALSE
		if(istype(thing, /obj/structure) && !istype(thing, /obj/structure/cable) && !HAS_TRAIT(thing, TRAIT_UNDERFLOOR))
			return FALSE
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(tile, direction)
		if(beside && (locate(/obj/machinery/door) in beside))
			return FALSE
	return TRUE

/**
 * The tile just outside the wing's door out, on its entrance side, or null. Only the wing's own
 * doors count: an extension's cell doors face the same way and open onto its yard.
 */
/datum/outpost_prison/proc/mail_entrance_front()
	if(!upgrade?.footprint_bounds)
		return null
	var/entrance_dir = upgrade.rotated_entrance(upgrade.rotation)
	for(var/turf/tile as anything in wing_turfs())
		if(!upgrade.contains_turf(tile) || !(locate(/obj/machinery/door/airlock) in tile))
			continue
		var/turf/beyond = get_step(tile, entrance_dir)
		if(beyond && !in_wing_bounds(beyond))
			return beyond
	return null

/// Of `tiles`, the one nearest `target`, ties picked at random; null for none
/datum/outpost_prison/proc/mail_nearest_turf(list/tiles, turf/target)
	if(!length(tiles))
		return null
	if(!target)
		return pick(tiles)
	var/list/best = list()
	var/best_distance = INFINITY
	for(var/turf/tile as anything in tiles)
		var/distance = get_dist_euclidean(tile, target)
		if(distance < best_distance)
			best = list(tile)
			best_distance = distance
		else if(distance == best_distance)
			best += tile
	return pick(best)

/// The office's floor that nothing dense stands on, as tile -> TRUE: the wing outside the cell block, people aside
/datum/outpost_prison/proc/mail_office_walkable()
	var/list/walkable = list()
	for(var/turf/tile as anything in wing_turfs())
		if(isopenturf(tile) && !in_cell_block(tile) && !tile.is_blocked_turf(exclude_mobs = TRUE))
			walkable[tile] = TRUE
	return walkable

/**
 * Whether a mail crate on `tile` leaves the office usable: everything beside it that people use (a
 * table, a machine, a hatch, a locker) still has free floor of its own beside it, and the rest of the
 * office floor (`walkable`, from mail_office_walkable()) stays in one piece
 */
/datum/outpost_prison/proc/mail_office_stays_open(list/walkable, turf/tile)
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(tile, direction)
		if(!beside || walkable[beside] || beside.loc != wing || isclosedturf(beside) || in_cell_block(beside))
			continue
		var/used = FALSE
		for(var/obj/thing in beside)
			if(thing.density && !istype(thing, /obj/structure/window) && !istype(thing, /obj/structure/grille))
				used = TRUE
				break
		if(!used)
			continue
		var/still_reached = FALSE
		for(var/other_direction in GLOB.cardinals)
			var/turf/other = get_step(beside, other_direction)
			if(other != tile && walkable[other])
				still_reached = TRUE
				break
		if(!still_reached)
			return FALSE
	var/turf/start
	for(var/turf/floor as anything in walkable)
		if(floor != tile)
			start = floor
			break
	if(!start)
		return TRUE
	var/list/reached = list()
	reached[start] = TRUE
	var/list/queue = list(start)
	var/index = 1
	while(index <= length(queue))
		var/turf/current = queue[index++]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || next == tile || !walkable[next] || reached[next])
				continue
			reached[next] = TRUE
			queue += next
	return length(reached) >= length(walkable) - (walkable[tile] ? 1 : 0)

/**
 * The office spot mail goes to: the office side of the first serving hatch, where staff pass things
 * through, or with no hatch, the office floor tile nearest the middle of the office. Never in the
 * cell block. Null when the wing has no office floor.
 */
/datum/outpost_prison/proc/mail_office_spot()
	var/list/office = list()
	for(var/turf/tile as anything in wing_turfs())
		if(!isopenturf(tile))
			continue
		var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in tile
		if(hatch)
			var/turf/staff_side = hatch.staff_side_turf()
			if(staff_side && staff_side.loc == wing && !in_cell_block(staff_side))
				return staff_side
			continue
		if(!in_cell_block(tile))
			office += tile
	if(!length(office))
		return null
	var/x_total = 0
	var/y_total = 0
	for(var/turf/tile as anything in office)
		x_total += tile.x
		y_total += tile.y
	var/turf/first = office[1]
	var/turf/middle = locate(round(x_total / length(office), 1), round(y_total / length(office), 1), first.z)
	return mail_nearest_turf(office, middle)

/**
 * Where an admin's single letter beams in: onto the office table nearest mail_office_spot() (never a
 * serving hatch), or with no table, onto that spot itself
 */
/datum/outpost_prison/proc/mail_letter_drop_turf()
	var/turf/anchor = mail_office_spot()
	var/list/tables = list()
	for(var/turf/tile as anything in wing_turfs())
		if(in_cell_block(tile))
			continue
		var/obj/structure/table/table = locate() in tile
		if(table && !istype(table, /obj/structure/table/reinforced/prison_hatch))
			tables += tile
	if(length(tables))
		return mail_nearest_turf(tables, anchor)
	return anchor

/**
 * A single letter for `prisoner` beams onto the office table (mail_letter_drop_turf()), outside the
 * waves (the admin panel's prison_mail): `kind` (by weight when not given), and for a contraband
 * letter `enclosure_type` (a razor blade or yeast by chance when not given). Returns the letter, or null.
 */
/datum/outpost_prison/proc/mail_send(mob/living/basic/outpost_prisoner/prisoner, kind, enclosure_type)
	if(QDELETED(prisoner) || !(prisoner in prisoners))
		return null
	var/turf/spot = mail_letter_drop_turf()
	if(!spot)
		return null
	var/obj/item/paper/outpost_prison_letter/letter = mail_make_letter(prisoner, kind, enclosure_type, spot)
	var/obj/item/mail/envelope/outpost_prison/envelope = letter.loc
	mail_letters += WEAKREF(letter)
	transporter_materialise(envelope)
	transporter_sparks(spot)
	playsound(spot, 'sound/machines/ding_short.ogg', 30, TRUE)
	add_log("Mail for [prisoner.real_name].")
	return letter

/**
 * Writes a sealed letter for `prisoner` in a new envelope in `destination`: `kind` (by weight when
 * not given), and for a contraband letter `enclosure_type` (a razor blade or yeast by chance when not
 * given). That is their one letter this stay. The caller tracks it (mail_letters). Returns the letter.
 */
/datum/outpost_prison/proc/mail_make_letter(mob/living/basic/outpost_prisoner/prisoner, kind, enclosure_type, atom/destination)
	if(!(kind in GLOB.outpost_prison_mail_kinds))
		kind = pick_weight(GLOB.outpost_prison_mail_kinds)
	var/obj/item/mail/envelope/outpost_prison/envelope = new(destination)
	envelope.name = "envelope for [prisoner.real_name]"
	var/obj/item/paper/outpost_prison_letter/letter = new(envelope)
	letter.name = "letter for [prisoner.real_name]"
	letter.letter_prison_ref = WEAKREF(src)
	letter.letter_prisoner_ref = WEAKREF(prisoner)
	letter.letter_addressee = prisoner.real_name
	letter.letter_kind = kind
	mail_write(letter, prisoner, kind)
	if(kind == "contraband")
		letter.letter_contraband = TRUE
		if(!ispath(enclosure_type, /obj/item))
			enclosure_type = contraband_roll(OUTPOST_MAIL_RAZOR_CHANCE) ? /obj/item/outpost_prison_contraband/razor_blade : /obj/item/outpost_prison_contraband/yeast
		new enclosure_type(envelope)
		envelope.hard_tell = contraband_roll(OUTPOST_MAIL_HARD_TELL)
	prisoner.mail_had_letter = TRUE
	return letter

/// Writes a letter of `kind` to `prisoner` from the extras' templates
/datum/outpost_prison/proc/mail_write(obj/item/paper/outpost_prison_letter/letter, mob/living/basic/outpost_prisoner/prisoner, kind)
	var/list/by_kind = outpost_prisoner_extra_dialogue(MAIL_STRINGS_FILE, "letters")
	var/list/templates = by_kind[kind]
	var/list/senders = outpost_prisoner_extra_dialogue(MAIL_STRINGS_FILE, "senders")
	var/text = length(templates) ? pick(templates) : "{name},\n\nThinking of you.\n\n{sender}"
	text = replacetext(text, "{name}", prisoner.speech_name())
	text = replacetext(text, "{sender}", length(senders) ? pick(senders) : "everyone at home")
	letter.add_raw_text(replacetext(text, "\n", "<br>"))
	letter.update_appearance()

/// Letters wait with the crew home; after OUTPOST_MAIL_EXPIRY one is sent back, and its prisoner is let down
/datum/outpost_prison/proc/mail_age(seconds)
	for(var/obj/item/paper/outpost_prison_letter/letter in mail_waiting_letters())
		letter.letter_waited += seconds
		if(letter.letter_waited >= OUTPOST_MAIL_EXPIRY / (1 SECONDS))
			mail_discard(letter, lost = TRUE)

/**
 * Every OUTPOST_MAIL_CHECK: a letter whose prisoner has gone is thrown away, one taken off the
 * wing's level is lost, and one on a serving hatch is fetched by its prisoner.
 */
/datum/outpost_prison/proc/mail_check()
	var/z = wing_z()
	for(var/obj/item/paper/outpost_prison_letter/letter in mail_waiting_letters())
		var/mob/living/basic/outpost_prisoner/addressee = letter.letter_prisoner_ref?.resolve()
		if(QDELETED(addressee) || !(addressee in prisoners))
			mail_discard(letter)
			continue
		var/turf/where = get_turf(letter)
		if(!where || (z && where.z != z))
			mail_discard(letter, lost = TRUE)
			continue
		var/obj/item/holder = outpost_prison_letter_holder(letter)
		if(isturf(holder.loc) && (locate(/obj/structure/table/reinforced/prison_hatch) in holder.loc))
			mail_collect_from_hatch(addressee, holder)

/// Deletes a letter and its envelope. `lost` (it never reached them) costs its prisoner OUTPOST_MAIL_EXPIRED_MOOD.
/datum/outpost_prison/proc/mail_discard(obj/item/paper/outpost_prison_letter/letter, lost = FALSE)
	if(QDELETED(letter))
		return
	mail_letters -= WEAKREF(letter)
	var/mob/living/basic/outpost_prisoner/addressee = letter.letter_prisoner_ref?.resolve()
	if(lost && !QDELETED(addressee) && (addressee in prisoners) && addressee.stat != DEAD)
		addressee.adjust_mood(-OUTPOST_MAIL_EXPIRED_MOOD)
		add_log("[addressee.real_name]'s mail was sent back.")
	qdel(outpost_prison_letter_holder(letter))

/// Someone opened a letter before its prisoner got it
/datum/outpost_prison/proc/mail_opened(obj/item/paper/outpost_prison_letter/letter, mob/user)
	add_log("[user ? user.name : "Someone"] opened [letter.letter_addressee]'s mail.")
	var/mob/living/basic/outpost_prisoner/addressee = letter.letter_prisoner_ref?.resolve()
	if(user && addressee)
		note_staff_event(user, addressee, "mail_opened")

// ===== THE PRISON: DELIVERY =====

/**
 * A letter `thing` (an envelope, or a letter opened out of one) lies on a serving hatch for
 * `addressee`. Awake, they come and get it when nothing more pressing has them busy; with nobody on
 * the level they read it where they stand if the hatch is in their reach, as fend_for_self() does
 * with food. Returns TRUE if they went for it or read it.
 */
/datum/outpost_prison/proc/mail_collect_from_hatch(mob/living/basic/outpost_prisoner/addressee, obj/item/thing)
	if(addressee.stat != CONSCIOUS || addressee.phase != PRISONER_PRESENT || !isturf(thing.loc))
		return FALSE
	if(addressee.ai_running())
		if(istype(addressee.activity, /datum/prisoner_activity/fetch_mail) || !addressee.routine_allowed())
			return FALSE
		var/datum/prisoner_activity/current = addressee.activity
		if(current && (!current.leisure || current.sleeping || !current.interruptible))
			return FALSE
		var/datum/prisoner_activity/fetch_mail/fetch = new(addressee, thing)
		if(!fetch.setup())
			qdel(fetch)
			return FALSE
		addressee.start_activity(fetch)
		return TRUE
	if(addressee.in_trouble() || addressee.cuffs)
		return FALSE
	if(!addressee.reachable)
		refresh_prisoner_reach(addressee)
	if(!addressee.reachable?[thing.loc])
		return FALSE
	mail_reading_emote(addressee, thing)
	return !!mail_finish_reading(addressee, thing)

/// Letters put on a serving hatch by staff: each one's prisoner comes for it. TRUE if it was only mail.
/datum/outpost_prison/proc/mail_hatch_stocked(obj/structure/table/reinforced/prison_hatch/hatch, list/stocked, mob/user)
	var/only_mail = length(stocked) > 0
	for(var/obj/item/thing in stocked)
		var/obj/item/paper/outpost_prison_letter/letter = outpost_prison_letter_in(thing)
		if(!letter)
			only_mail = FALSE
			continue
		var/mob/living/basic/outpost_prisoner/addressee = letter.letter_prisoner_ref?.resolve()
		if(!QDELETED(addressee) && (addressee in prisoners))
			mail_collect_from_hatch(addressee, thing)
	return only_mail

/**
 * Someone not in combat mode uses a letter on a prisoner: its prisoner takes it and reads it (async),
 * anyone else says it isn't theirs, and a prisoner who won't listen refuses it. Runs inside a
 * signal handler: never sleeps. Returns the item interaction result.
 */
/datum/outpost_prison/proc/mail_hand_over(mob/living/basic/outpost_prisoner/prisoner, mob/living/user, obj/item/thing, obj/item/paper/outpost_prison_letter/letter)
	if(prisoner.stat != CONSCIOUS || prisoner.phase != PRISONER_PRESENT)
		return NONE
	if(letter.letter_prisoner_ref?.resolve() != prisoner)
		prisoner.balloon_alert(user, "not theirs")
		INVOKE_ASYNC(prisoner, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), "mail_not_mine")
		return ITEM_INTERACT_BLOCKING
	// Cuffed hands take nothing, as with food and uniforms (outpost_prison_capture.dm)
	if(prisoner.cuffs)
		prisoner.balloon_alert(user, "cuffed")
		return ITEM_INTERACT_BLOCKING
	// Fighting, squaring up, climbing, lying beaten, or already busy with staff: they won't take it
	if(prisoner.in_trouble() || !prisoner.will_listen())
		prisoner.balloon_alert(user, "not listening")
		INVOKE_ASYNC(prisoner, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), "talk_refuse")
		return ITEM_INTERACT_BLOCKING
	if(!user.temporarilyRemoveItemFromInventory(thing))
		return ITEM_INTERACT_BLOCKING
	if(!prisoner.take_item(thing))
		thing.forceMove(prisoner)
	user.visible_message(span_notice("[user] hands [prisoner] [thing]."), span_notice("You hand [prisoner] [thing]."))
	if(is_member(user))
		note_staff_event(user, prisoner, "mail_delivered")
	INVOKE_ASYNC(src, PROC_REF(mail_read), prisoner, thing)
	return ITEM_INTERACT_SUCCESS

/**
 * `prisoner` reads a letter they were handed: OUTPOST_MAIL_READ_TIME with their routine held,
 * unless `instant`, then the letter takes effect. Bad news sends them to sit in their cell a while.
 * Returns the kind read, or null. Sleeps unless `instant`.
 */
/datum/outpost_prison/proc/mail_read(mob/living/basic/outpost_prisoner/prisoner, obj/item/thing, instant = FALSE)
	if(QDELETED(prisoner) || QDELETED(thing))
		return null
	mail_reading_emote(prisoner, thing)
	if(!instant)
		prisoner.talking = TRUE
		prisoner.ai_controller?.CancelActions()
		sleep(OUTPOST_MAIL_READ_TIME)
		if(QDELETED(prisoner))
			return null
		prisoner.talking = FALSE
		if(QDELETED(src) || QDELETED(thing) || thing.loc != prisoner || prisoner.stat != CONSCIOUS)
			return null
	var/kind = mail_finish_reading(prisoner, thing)
	if(kind == "bad")
		mail_start_mull(prisoner)
	return kind

/datum/outpost_prison/proc/mail_reading_emote(mob/living/basic/outpost_prisoner/prisoner, obj/item/thing)
	if(istype(thing, /obj/item/mail/envelope/outpost_prison))
		prisoner.manual_emote("tears open the envelope and reads the letter.")
		playsound(prisoner, 'sound/items/poster/poster_ripped.ogg', 30, TRUE)
	else
		prisoner.manual_emote("reads the letter.")
		playsound(prisoner, 'sound/items/paper_flip.ogg', 30, TRUE)

/**
 * The letter takes effect: the kind's mood and line, and for a letter someone opened first a
 * further OUTPOST_MAIL_OPENED_MOOD and "Who opened this?" in place of the line. Anything still
 * sealed in with it is kept hidden (contraband, 4.14). The letter and its envelope are then gone
 * (they keep it). Never sleeps. Returns the kind, or null.
 */
/datum/outpost_prison/proc/mail_finish_reading(mob/living/basic/outpost_prisoner/prisoner, obj/item/thing)
	var/obj/item/paper/outpost_prison_letter/letter = outpost_prison_letter_in(thing)
	if(!letter || QDELETED(prisoner))
		return null
	var/obj/item/enclosure
	if(istype(thing, /obj/item/mail/envelope/outpost_prison))
		for(var/obj/item/inside in thing)
			if(inside != letter)
				enclosure = inside
				break
	var/kind = letter.letter_kind
	mail_letters -= WEAKREF(letter)
	prisoner.adjust_mood(outpost_prison_mail_mood(kind))
	if(letter.letter_opened)
		prisoner.adjust_mood(-OUTPOST_MAIL_OPENED_MOOD)
		prisoner.say_context("mail_opened")
	else
		prisoner.say_context(outpost_prison_mail_context(kind))
	if(enclosure && !prisoner.contraband_carry(enclosure))
		qdel(enclosure)
	qdel(thing)
	return kind

/// Bad news: they go and sit in their cell's chair (or on its bed) for a while, if they can
/datum/outpost_prison/proc/mail_start_mull(mob/living/basic/outpost_prisoner/prisoner)
	if(QDELETED(prisoner) || !prisoner.ai_running() || !prisoner.routine_allowed())
		return FALSE
	var/datum/prisoner_activity/mull_letter/mull = new(prisoner)
	if(!mull.setup())
		qdel(mull)
		return FALSE
	prisoner.start_activity(mull)
	return TRUE

// ===== THE PRISON: SPEECH, CONSOLES, CLEAN-UP =====

/// "Any mail for me?", from a prisoner with a letter waiting and a member in sight, as list(context, other, values), or null
/datum/outpost_prison/proc/mail_extra_speech(mob/living/basic/outpost_prisoner/prisoner)
	if(!mail_waiting_for(prisoner) || !contraband_roll(OUTPOST_MAIL_ASK_CHANCE))
		return null
	for(var/mob/living/person in view(OUTPOST_MAIL_ASK_RANGE, prisoner))
		if(person.stat != CONSCIOUS || !is_member(person))
			continue
		var/staff_name = staff_greeting_name(person)
		return list("mail_waiting", null, staff_name ? list("{staff}" = staff_name) : null)
	return null

/// A prisoner is leaving: their undelivered letters go
/datum/outpost_prison/proc/mail_prisoner_leaving(mob/living/basic/outpost_prisoner/prisoner)
	for(var/obj/item/paper/outpost_prison_letter/letter in mail_waiting_letters())
		if(letter.letter_prisoner_ref?.resolve() == prisoner)
			mail_discard(letter)

/datum/outpost_prison/proc/mail_destroy()
	for(var/obj/item/paper/outpost_prison_letter/letter in mail_waiting_letters())
		qdel(outpost_prison_letter_holder(letter))
	mail_letters.Cut()

/// The admin panel's mail block: {letters: [{ref, to_ref, to_name, kind, opened, contraband, age}], next_in}
/datum/outpost_prison/proc/mail_admin_payload()
	var/list/rows = list()
	for(var/obj/item/paper/outpost_prison_letter/letter in mail_waiting_letters())
		var/mob/living/basic/outpost_prisoner/addressee = letter.letter_prisoner_ref?.resolve()
		rows += list(list(
			"ref" = REF(letter),
			"to_ref" = addressee ? REF(addressee) : null,
			"to_name" = letter.letter_addressee,
			"kind" = letter.letter_kind,
			"opened" = !!letter.letter_opened,
			"contraband" = !!letter.letter_contraband,
			"age" = round(letter.letter_waited),
		))
	return list("letters" = rows, "next_in" = isnull(mail_next_in) ? null : max(0, round(mail_next_in)))

/**
 * prison_mail {ref, kind}: a letter of that kind for that prisoner, on the office table now.
 * prison_mail_wave {}: a mail pod now, past its clock, which starts over.
 * A log line, list("error" = text), or null.
 */
/datum/outpost_prison/proc/mail_admin_act(action, list/params, mob/user)
	if(action == "prison_mail_wave")
		var/sent = mail_wave()
		if(!sent)
			return list("error" = "No prisoner is due a letter, or the pod has nowhere to land.")
		mail_next_in = mail_gap()
		return "call a prison mail pod with [sent] letter\s"
	if(action != "prison_mail")
		return null
	var/mob/living/basic/outpost_prisoner/prisoner = locate(params?["ref"]) in prisoners
	if(QDELETED(prisoner))
		return list("error" = "That prisoner is gone.")
	var/kind = params["kind"]
	if(!istext(kind) || !(kind in GLOB.outpost_prison_mail_kinds))
		return list("error" = "Invalid letter kind.")
	if(prisoner.stat == DEAD || prisoner.phase != PRISONER_PRESENT)
		return list("error" = "Only a living prisoner in the wing gets mail.")
	if(!mail_send(prisoner, kind))
		return list("error" = "The wing has no office for mail to arrive in.")
	return "send prisoner [prisoner.real_name] a [kind] letter"

// ===== THE HAND-OVER =====

/**
 * A letter used on its prisoner by anyone not in combat mode. An element, since the prisoner's own
 * handler for item use (outpost_prison_prisoner.dm) already takes the signal and ignores paper.
 */
/datum/element/outpost_prison_mail_handover

/datum/element/outpost_prison_mail_handover/Attach(datum/target)
	. = ..()
	if(!istype(target, /mob/living/basic/outpost_prisoner))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_ATOM_ITEM_INTERACTION, PROC_REF(on_item_interaction))

/datum/element/outpost_prison_mail_handover/Detach(datum/source, ...)
	UnregisterSignal(source, COMSIG_ATOM_ITEM_INTERACTION)
	return ..()

/datum/element/outpost_prison_mail_handover/proc/on_item_interaction(mob/living/basic/outpost_prisoner/source, mob/living/user, obj/item/tool, list/modifiers)
	SIGNAL_HANDLER
	if(!istype(user) || user.combat_mode || is_outpost_prisoner(user) || !source.prison)
		return NONE
	var/obj/item/paper/outpost_prison_letter/letter = outpost_prison_letter_in(tool)
	if(!letter)
		return NONE
	return source.prison.mail_hand_over(source, user, tool, letter)

// ===== ACTIVITIES =====

/// A letter for them was left on a serving hatch: they fetch it, read it, and after bad news sit in their cell a while
/datum/prisoner_activity/fetch_mail
	name = "fetching a letter"
	weight = 0
	interruptible = FALSE
	var/datum/weakref/mail_ref
	/// "fetch", "reading" or "mull"
	var/stage = "fetch"
	/// Ticks spent waiting for the hatch, and seconds spent reading
	var/waited = 0
	var/read_for = 0
	var/datum/weakref/seat_ref

/datum/prisoner_activity/fetch_mail/New(mob/living/basic/outpost_prisoner/doer, obj/item/thing)
	. = ..(doer)
	mail_ref = WEAKREF(thing)

/datum/prisoner_activity/fetch_mail/setup()
	var/obj/item/thing = mail_ref?.resolve()
	if(QDELETED(thing) || !isturf(thing.loc) || !claim(thing))
		return FALSE
	spot = prisoner.approach_turf(thing)
	return !!spot

/datum/prisoner_activity/fetch_mail/arrive()
	spot = null
	if(!started)
		started = TRUE
		ends_at = INFINITY
	if(stage == "mull")
		var/obj/machinery/door/door = prisoner.cell?.door()
		prisoner.sit_in_cell(door ? get_cardinal_dir(prisoner, door) : SOUTH)
		ends_at = world.time + rand(OUTPOST_MAIL_MULL_MIN, OUTPOST_MAIL_MULL_MAX) SECONDS
	return TRUE

/datum/prisoner_activity/fetch_mail/tick(seconds)
	var/datum/outpost_prison/prison = prisoner.prison
	var/obj/item/thing = mail_ref?.resolve()
	switch(stage)
		if("fetch")
			if(QDELETED(thing) || !prison)
				return ACTIVITY_DONE
			if(thing.loc != prisoner)
				switch(prisoner.try_reach(thing))
					if(PRISONER_REACH_WAIT)
						return ++waited > 6 ? ACTIVITY_DONE : ACTIVITY_CONTINUE
					if(PRISONER_REACH_FAILED)
						return ACTIVITY_DONE
				if(!prisoner.take_item(thing))
					thing.forceMove(prisoner)
				if(thing.loc != prisoner)
					return ACTIVITY_DONE
			prison.mail_reading_emote(prisoner, thing)
			stage = "reading"
			return ACTIVITY_CONTINUE
		if("reading")
			if(QDELETED(thing) || thing.loc != prisoner || !prison)
				return ACTIVITY_DONE
			read_for += seconds
			if(read_for < OUTPOST_MAIL_READ_TIME / (1 SECONDS))
				return ACTIVITY_CONTINUE
			if(prison.mail_finish_reading(prisoner, thing) != "bad")
				return ACTIVITY_DONE
			// Bad news: back to their cell's chair (or bed) to think it over
			var/obj/structure/seat = prisoner.home_seat()
			if(!seat || !claim(seat))
				return ACTIVITY_DONE
			seat_ref = WEAKREF(seat)
			stage = "mull"
			spot = get_turf(seat)
			return ACTIVITY_MOVE
		if("mull")
			var/obj/structure/seat = seat_ref?.resolve()
			if(!seat || prisoner.loc != seat.loc || world.time >= ends_at)
				return ACTIVITY_DONE
			return ACTIVITY_CONTINUE
	return ACTIVITY_DONE

/datum/prisoner_activity/fetch_mail/finish()
	// Stopped before reading it: the letter goes down where they stand, for someone to hand back
	var/obj/item/thing = mail_ref?.resolve()
	if(thing && prisoner && thing.loc == prisoner)
		if(prisoner.held_item == thing)
			prisoner.drop_held_item()
		else
			thing.forceMove(prisoner.drop_location())
	return ..()

/// After bad news in the post: sitting in their cell's chair (or on its bed) for a while
/datum/prisoner_activity/mull_letter
	name = "thinking over a letter"
	weight = 0
	interruptible = FALSE
	min_duration = OUTPOST_MAIL_MULL_MIN SECONDS
	max_duration = OUTPOST_MAIL_MULL_MAX SECONDS
	var/datum/weakref/seat_ref

/datum/prisoner_activity/mull_letter/setup()
	var/obj/structure/seat = prisoner.home_seat()
	if(!seat || !claim(seat))
		return FALSE
	seat_ref = WEAKREF(seat)
	spot = get_turf(seat)
	return TRUE

/datum/prisoner_activity/mull_letter/begin()
	. = ..()
	var/obj/machinery/door/door = prisoner.cell?.door()
	prisoner.sit_in_cell(door ? get_cardinal_dir(prisoner, door) : SOUTH)

/datum/prisoner_activity/mull_letter/tick(seconds)
	var/obj/structure/seat = seat_ref?.resolve()
	if(!seat || prisoner.loc != seat.loc)
		return ACTIVITY_DONE
	return ..()

#undef ACTIVITY_CONTINUE
#undef ACTIVITY_DONE
#undef ACTIVITY_MOVE
#undef MAIL_STRINGS_FILE
