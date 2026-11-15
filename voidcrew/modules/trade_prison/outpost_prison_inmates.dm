/**
 * # Outpost lockup: player inmates
 *
 * A player whose arrest ends in jail (an unpaid 1-2 star fine, or 3+ stars taken alive) serves their
 * sentence in the outpost's lockup among its prisoners. The officer strips their gear into a property
 * locker in the front room, walks them into Processing, removes the cuffs and steps out; Processing
 * shuts the outer door and opens the inner to the yard.
 *
 * The sentence clock runs from the prison's tick() whether the inmate is conscious, in crit, asleep or
 * logged out. Time worked off (outpost_prison_work.dm) is capped at a third of the sentence. Leaving
 * the cell block and Processing on their own feet with time left is a jailbreak; being pulled, carried
 * or contained out charges the mover and gives the inmate OUTPOST_POLICE_CELL_RETURN to get back in.
 */

/// One player's lockup sentence, keyed by /datum/mind in /datum/outpost_prison/var/sentences
/datum/prison_sentence
	/// Whose sentence this is
	var/datum/mind/mind
	/// Weakref to the body booked in
	var/datum/weakref/body_ref
	/// Stars on the warrant when booked
	var/stars_at_booking = 1
	/// Total sentence in seconds (only ever rises while held if stars climb)
	var/total_seconds = 0
	/// Seconds served inside the cell block or Processing
	var/seconds_served = 0
	/// Raw seconds earned from prison jobs (capped at a third of total_seconds when applied)
	var/seconds_worked_off = 0
	/// Seconds since the last bail retry (1-2 stars)
	var/bail_elapsed = 0
	/// Seconds left to walk back in after someone else moved the inmate out (0 while inside)
	var/return_left = 0
	/// Set once a carried-out inmate bumps or clicks Processing's outer door to walk back in
	var/wants_return = FALSE
	/// Set when the inmate crossed out on a step of their own
	var/walked_out = FALSE
	/// world.time of the inmate's last client move step
	var/stepped_at = 0
	/// Weakref to whoever pulled, carried, contained or shoved the inmate out
	var/datum/weakref/carried_by_ref
	/// Weakref to whoever last shoved the inmate, and the world.time of that shove
	var/datum/weakref/shoved_by_ref
	var/shoved_at = 0
	/// Whether the mover who took the inmate out has already been reported for jailbreak
	var/carry_reported = FALSE
	/// Set when the inmate escaped; kept on sentences[mind] so rebooking resets progress to 0
	var/escaped = FALSE
	/// Set when the sentence ended by service, bail or death
	var/released = FALSE
	/// Whether a prisoner has given this inmate a tip during this stay (one per sentence)
	var/tip_given = FALSE
	/// Weakrefs to every movable container currently enclosing the inmate's body (inner to outer)
	var/list/datum/weakref/watched_container_refs
	/// Weakref of a living attacker -> world.time they last hit this inmate in the cell block (10 s self-defense window)
	var/list/provoked_by
	/// world.time until which guards baton this inmate for an unprovoked hit or breakout act in the cell block
	var/baton_until = 0
	/// Weakref to the last held inmate who landed a damaging cell-block blow on this inmate
	var/datum/weakref/last_inmate_attacker_ref
	/// world.time of that last damaging cell-block blow
	var/last_inmate_attack_at = 0
	/// Whether that blow fell inside the attacker's self-defense window against this inmate
	var/last_inmate_attack_justified = FALSE
	/// Whether a witness saw that blow when it landed
	var/last_inmate_attack_seen = FALSE
	/// world.time when this sentence ended by death in custody
	var/died_in_custody_at = 0
	/// Whether OUTPOST_CRIME_MURDER has already been reported for this death in custody
	var/murder_reported = FALSE
	/// Set when an admin booked this sentence directly with a fixed duration
	var/admin_booked = FALSE

/datum/prison_sentence/Destroy()
	mind = null
	body_ref = null
	carried_by_ref = null
	shoved_by_ref = null
	watched_container_refs = null
	provoked_by = null
	last_inmate_attacker_ref = null
	return ..()

/// Effective seconds worked off, capped at a third of total_seconds
/datum/prison_sentence/proc/effective_worked_off()
	return min(seconds_worked_off, round(total_seconds / 3))

/// Remaining seconds to serve, never negative
/datum/prison_sentence/proc/remaining_seconds()
	return max(0, total_seconds - seconds_served - effective_worked_off())

/datum/outpost_prison
	/// /datum/mind -> /datum/prison_sentence
	var/list/sentences = list()
	/// Mapped /obj/machinery/status_display/outpost_berth/lockup boards for this wing
	var/list/boards = list()
	/// Weakrefs to dead inmate bodies inside the wing awaiting carry-out to the front room
	var/list/dead_inmate_bodies = list()
	/// Weakrefs to visitors who entered Processing to recover a dead inmate when no guard could
	var/list/datum/weakref/corpse_visitor_refs = list()
	/// Weakrefs to released inmate bodies waiting to cycle out through Processing
	var/list/processing_release_refs = list()
	/// Weakref to the officer walking a newly booked inmate through Processing
	var/datum/weakref/booking_mover_ref
	/// Cooldown between guards remarking on inmate work ("That's time off.")
	COOLDOWN_DECLARE(work_say_cooldown)

// =========================================================================
// QUERIES AND BOARDS
// =========================================================================

/// Formats `seconds_left` as M:SS for the lockup board
/proc/format_lockup_board_time(seconds_left)
	var/clamped = max(0, ceil(seconds_left))
	var/minutes = round(clamped / 60)
	var/rest = clamped % 60
	return "[minutes]:[rest < 10 ? "0" : ""][rest]"

/// Strips leading radio/emote punctuation from a spoken surname so player names never trigger radio prefixes
/proc/sanitize_lockup_surname(full_name)
	if(!full_name)
		return "Inmate"
	var/list/parts = splittext(trim(full_name), " ")
	var/chosen = length(parts) ? parts[length(parts)] : full_name
	var/clean = ""
	var/started = FALSE
	for(var/i = 1, i <= length(chosen), i++)
		var/ascii = text2ascii(chosen, i)
		var/alnum = (ascii >= 48 && ascii <= 57) || (ascii >= 65 && ascii <= 90) || (ascii >= 97 && ascii <= 122) || ascii >= 128
		if(!started && !alnum)
			continue
		if(alnum || ascii == 45 || ascii == 39)
			started = TRUE
			clean += copytext(chosen, i, i + 1)
	return length(clean) ? clean : "Inmate"

/// Whether `who` is actively held on a lockup sentence here
/datum/outpost_prison/proc/holds(datum/mind/who)
	if(QDELETED(src) || !who || QDELETED(who))
		return FALSE
	var/datum/prison_sentence/sentence = sentences[who]
	if(!sentence || sentence.released || sentence.escaped)
		return FALSE
	var/mob/living/body = sentence.body_ref?.resolve()
	return !QDELETED(body) && body.mind == who

/// Whether `person` is a player inmate actively serving time in this wing
/datum/outpost_prison/proc/is_inmate(mob/person)
	var/mob/living/living_person = person
	if(!istype(living_person) || !living_person.mind)
		return FALSE
	var/datum/prison_sentence/sentence = sentences[living_person.mind]
	return !!sentence && !sentence.released && !sentence.escaped && sentence.body_ref?.resolve() == living_person

/// Whether at least one player inmate is currently serving time in this wing
/datum/outpost_prison/proc/has_inmates()
	for(var/datum/mind/who as anything in sentences)
		if(holds(who))
			return TRUE
	return FALSE

/// How many player inmates are actively serving time in this wing
/datum/outpost_prison/proc/active_inmate_count()
	var/count = 0
	for(var/datum/mind/who as anything in sentences)
		if(holds(who))
			count++
	return count

/// Rows for active player inmates in the Outpost Manipulator's Prison panel
/datum/outpost_prison/proc/admin_inmates_payload()
	var/list/rows = list()
	for(var/datum/mind/who as anything in sentences)
		if(!holds(who))
			continue
		var/datum/prison_sentence/sentence = sentences[who]
		var/mob/living/body = sentence?.body_ref?.resolve()
		if(QDELETED(body))
			continue
		rows += list(list(
			"ref" = REF(who),
			"body_ref" = REF(body),
			"name" = body.real_name || who.name || "Inmate",
			"ckey" = body.ckey || (who.key ? ckey(who.key) : null),
			"stars" = sentence.stars_at_booking,
			"remaining" = round(sentence.remaining_seconds()),
			"served" = round(sentence.seconds_served),
			"worked_off" = round(sentence.effective_worked_off()),
			"total" = round(sentence.total_seconds),
			"admin_booked" = !!sentence.admin_booked,
		))
	return rows

/// Active sentence for `person` when they are a held inmate here, or null
/datum/outpost_prison/proc/sentence_for(mob/living/person)
	if(!isliving(person) || !person.mind || !holds(person.mind))
		return null
	var/datum/prison_sentence/sentence = sentences[person.mind]
	return sentence?.body_ref?.resolve() == person ? sentence : null

/// Whether `thing` lies within the inmate containment bounds (the computed cell block plus Processing)
/datum/outpost_prison/proc/in_inmate_bounds(atom/thing)
	var/turf/spot = get_turf(thing)
	if(!spot)
		return FALSE
	return in_cell_block(spot) || in_processing(spot)

/// Registers a mapped or dynamically spawned lockup status board with this wing
/datum/outpost_prison/proc/register_lockup_board(obj/machinery/status_display/outpost_berth/lockup/board)
	if(QDELETED(board))
		return
	board.prison = src
	boards |= board
	update_lockup_boards()

/// Collects any lockup boards already in `wing` (called from New())
/datum/outpost_prison/proc/find_lockup_boards()
	for(var/turf/tile as anything in wing_turfs())
		for(var/obj/machinery/status_display/outpost_berth/lockup/board in tile)
			register_lockup_board(board)

/// Remaining M:SS string for `user` when they are a held inmate of this wing, or null
/datum/outpost_prison/proc/inmate_remaining_text(mob/user)
	var/mob/living/living_user = user
	var/datum/prison_sentence/sentence = istype(living_user) ? sentence_for(living_user) : null
	if(!sentence)
		return null
	return format_lockup_board_time(sentence.remaining_seconds())

/// Refreshes every registered lockup board to the soonest active inmate release (blank when none)
/datum/outpost_prison/proc/update_lockup_boards()
	if(!length(boards))
		return
	var/soonest
	for(var/datum/mind/who as anything in sentences)
		if(!holds(who))
			continue
		var/datum/prison_sentence/sentence = sentences[who]
		if(sentence.return_left > 0)
			continue
		var/left = sentence.remaining_seconds()
		soonest = isnull(soonest) ? left : min(soonest, left)
	var/display_text = isnull(soonest) ? "" : format_lockup_board_time(soonest)
	for(var/obj/machinery/status_display/outpost_berth/lockup/board as anything in boards.Copy())
		if(QDELETED(board))
			boards -= board
			continue
		if(display_text != "" && board.current_mode != SD_MESSAGE)
			board.current_mode = SD_MESSAGE
		if(board.message1 != display_text || board.message2 != "")
			board.set_messages(display_text, "")

// =========================================================================
// CONTAINMENT TRAITS AND MOVEMENT TRACKING
// =========================================================================

/// Keeps awake, unfloored inmates out of bags and lockers; floored or unconscious inmates can be carried like anyone
/datum/outpost_prison/proc/sync_inmate_traits(mob/living/body)
	if(QDELETED(body))
		return
	var/awake_upright = is_inmate(body) && body.stat == CONSCIOUS && !HAS_TRAIT(body, TRAIT_FLOORED) && !HAS_TRAIT(body, TRAIT_INCAPACITATED) && !HAS_TRAIT(body, TRAIT_CRITICAL_CONDITION)
	if(awake_upright)
		ADD_TRAIT(body, TRAIT_NO_CONTAINMENT, OUTPOST_PRISON_INMATE_TRAIT)
		ADD_TRAIT(body, TRAIT_NO_STORAGE_INSERT, OUTPOST_PRISON_INMATE_TRAIT)
	else
		REMOVE_TRAIT(body, TRAIT_NO_CONTAINMENT, OUTPOST_PRISON_INMATE_TRAIT)
		REMOVE_TRAIT(body, TRAIT_NO_STORAGE_INSERT, OUTPOST_PRISON_INMATE_TRAIT)

/// Whether another active sentence on this wing still watches `container`
/datum/outpost_prison/proc/container_watched_by_other_sentence(atom/movable/container, datum/prison_sentence/ignore)
	if(QDELETED(container))
		return FALSE
	for(var/datum/mind/who as anything in sentences)
		var/datum/prison_sentence/other = sentences[who]
		if(!other || other == ignore || other.released || other.escaped || !length(other.watched_container_refs))
			continue
		if(WEAKREF(container) in other.watched_container_refs)
			return TRUE
	return FALSE

/// Drops container signals for `sentence` without unhooking containers shared with another inmate
/datum/outpost_prison/proc/clear_inmate_container_watch(datum/prison_sentence/sentence)
	if(!sentence)
		return
	var/list/datum/weakref/old_refs = sentence.watched_container_refs
	sentence.watched_container_refs = null
	for(var/datum/weakref/ref as anything in old_refs)
		var/atom/movable/watched = ref?.resolve()
		if(watched && !container_watched_by_other_sentence(watched, sentence))
			UnregisterSignal(watched, list(COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_TELEPORTING))

/// Watches every movable container enclosing `body` so pulling, unnesting or teleporting a locker or bodybag is caught
/datum/outpost_prison/proc/sync_inmate_container_watch(datum/prison_sentence/sentence, mob/living/body)
	if(!sentence)
		return
	var/list/atom/movable/chain = list()
	if(!QDELETED(body) && !isturf(body.loc))
		var/atom/cursor = body.loc
		while(ismovable(cursor) && !isturf(cursor))
			chain += cursor
			cursor = cursor.loc
	var/list/datum/weakref/old_refs = sentence.watched_container_refs
	if(length(chain) == length(old_refs))
		var/unchanged = TRUE
		for(var/idx in 1 to length(chain))
			if(old_refs[idx]?.resolve() != chain[idx])
				unchanged = FALSE
				break
		if(unchanged)
			return
	var/list/datum/weakref/new_refs = length(chain) ? list() : null
	for(var/atom/movable/item as anything in chain)
		new_refs += WEAKREF(item)
	sentence.watched_container_refs = new_refs
	for(var/datum/weakref/old_ref as anything in old_refs)
		var/atom/movable/old_cont = old_ref?.resolve()
		if(old_cont && !(old_cont in chain) && !container_watched_by_other_sentence(old_cont, sentence))
			UnregisterSignal(old_cont, list(COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_TELEPORTING))
	for(var/atom/movable/cont as anything in chain)
		RegisterSignal(cont, COMSIG_MOVABLE_MOVED, PROC_REF(on_inmate_container_moved), override = TRUE)
		RegisterSignal(cont, COMSIG_MOVABLE_TELEPORTING, PROC_REF(on_inmate_container_teleport), override = TRUE)

/// Attaches containment, movement and death signals to `body` for `sentence`
/datum/outpost_prison/proc/hook_inmate(datum/prison_sentence/sentence, mob/living/body)
	if(QDELETED(body))
		return
	body.AddElement(/datum/element/relay_attackers)
	if(sentence?.mind)
		RegisterSignal(sentence.mind, COMSIG_MIND_TRANSFERRED, PROC_REF(on_inmate_mind_transferred), override = TRUE)
	RegisterSignal(body, COMSIG_MOVABLE_TELEPORTING, PROC_REF(on_inmate_teleport), override = TRUE)
	RegisterSignal(body, COMSIG_LIVING_PRE_WABBAJACKED, PROC_REF(on_inmate_pre_wabbajack), override = TRUE)
	RegisterSignal(body, COMSIG_PRE_MOB_CHANGED_TYPE, PROC_REF(on_inmate_pre_change_type), override = TRUE)
	RegisterSignal(body, COMSIG_MOVABLE_MOVED, PROC_REF(on_inmate_moved), override = TRUE)
	RegisterSignal(body, COMSIG_MOB_CLIENT_PRE_MOVE, PROC_REF(on_inmate_client_step), override = TRUE)
	RegisterSignal(body, COMSIG_LIVING_DISARM_HIT, PROC_REF(on_inmate_shoved), override = TRUE)
	RegisterSignal(body, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(on_inmate_was_attacked), override = TRUE)
	RegisterSignal(body, COMSIG_MOB_ITEM_ATTACK, PROC_REF(on_inmate_item_attack), override = TRUE)
	RegisterSignal(body, COMSIG_LIVING_ATTACK_ATOM, PROC_REF(on_inmate_attack_atom), override = TRUE)
	RegisterSignal(body, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_inmate_unarmed_attack), override = TRUE)
	RegisterSignal(body, COMSIG_MOB_STATCHANGE, PROC_REF(on_inmate_state_changed), override = TRUE)
	RegisterSignal(body, COMSIG_LIVING_SET_BODY_POSITION, PROC_REF(on_inmate_state_changed), override = TRUE)
	RegisterSignal(body, SIGNAL_ADDTRAIT(TRAIT_FLOORED), PROC_REF(on_inmate_state_changed), override = TRUE)
	RegisterSignal(body, SIGNAL_REMOVETRAIT(TRAIT_FLOORED), PROC_REF(on_inmate_state_changed), override = TRUE)
	RegisterSignal(body, SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED), PROC_REF(on_inmate_state_changed), override = TRUE)
	RegisterSignal(body, SIGNAL_REMOVETRAIT(TRAIT_INCAPACITATED), PROC_REF(on_inmate_state_changed), override = TRUE)
	RegisterSignal(body, SIGNAL_ADDTRAIT(TRAIT_CRITICAL_CONDITION), PROC_REF(on_inmate_state_changed), override = TRUE)
	RegisterSignal(body, SIGNAL_REMOVETRAIT(TRAIT_CRITICAL_CONDITION), PROC_REF(on_inmate_state_changed), override = TRUE)
	RegisterSignal(body, COMSIG_LIVING_DEATH, PROC_REF(on_inmate_died_sig), override = TRUE)
	RegisterSignal(body, COMSIG_QDELETING, PROC_REF(on_inmate_body_qdel), override = TRUE)
	sync_inmate_traits(body)
	sync_inmate_container_watch(sentence, body)

/// Removes containment traits and signals for `sentence`
/datum/outpost_prison/proc/unhook_inmate(datum/prison_sentence/sentence)
	if(!sentence)
		return
	clear_inmate_container_watch(sentence)
	if(sentence.mind)
		UnregisterSignal(sentence.mind, COMSIG_MIND_TRANSFERRED)
	var/mob/living/body = sentence.body_ref?.resolve()
	if(QDELETED(body))
		return
	REMOVE_TRAIT(body, TRAIT_NO_CONTAINMENT, OUTPOST_PRISON_INMATE_TRAIT)
	REMOVE_TRAIT(body, TRAIT_NO_STORAGE_INSERT, OUTPOST_PRISON_INMATE_TRAIT)
	UnregisterSignal(body, list(
		COMSIG_MOVABLE_TELEPORTING,
		COMSIG_LIVING_PRE_WABBAJACKED,
		COMSIG_PRE_MOB_CHANGED_TYPE,
		COMSIG_MOVABLE_MOVED,
		COMSIG_MOB_CLIENT_PRE_MOVE,
		COMSIG_LIVING_DISARM_HIT,
		COMSIG_ATOM_WAS_ATTACKED,
		COMSIG_MOB_ITEM_ATTACK,
		COMSIG_LIVING_ATTACK_ATOM,
		COMSIG_LIVING_UNARMED_ATTACK,
		COMSIG_MOB_STATCHANGE,
		COMSIG_LIVING_SET_BODY_POSITION,
		SIGNAL_ADDTRAIT(TRAIT_FLOORED),
		SIGNAL_REMOVETRAIT(TRAIT_FLOORED),
		SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED),
		SIGNAL_REMOVETRAIT(TRAIT_INCAPACITATED),
		SIGNAL_ADDTRAIT(TRAIT_CRITICAL_CONDITION),
		SIGNAL_REMOVETRAIT(TRAIT_CRITICAL_CONDITION),
		COMSIG_LIVING_DEATH,
		COMSIG_QDELETING,
	))

/datum/outpost_prison/proc/on_inmate_teleport(mob/living/source, atom/destination, channel)
	SIGNAL_HANDLER
	if(!is_inmate(source))
		return NONE
	if(isturf(source.loc))
		source.visible_message(span_notice("[source] flickers for a moment, but stays where [source.p_they()] [source.p_are()]."))
	return TRUE

/datum/outpost_prison/proc/on_inmate_pre_wabbajack(mob/living/source, what_to_randomize)
	SIGNAL_HANDLER
	if(!is_inmate(source))
		return NONE
	source.visible_message(span_notice("[source] shimmers for a moment, then looks the same as before."))
	return STOP_WABBAJACK

/datum/outpost_prison/proc/on_inmate_pre_change_type(mob/living/source)
	SIGNAL_HANDLER
	if(!is_inmate(source))
		return NONE
	return COMPONENT_BLOCK_MOB_CHANGE

/datum/outpost_prison/proc/on_inmate_container_teleport(atom/movable/container, atom/destination, channel)
	SIGNAL_HANDLER
	if(QDELETED(src) || QDELETED(container))
		return NONE
	var/list/inside = container.get_all_contents()
	for(var/datum/mind/who as anything in sentences)
		if(!holds(who))
			continue
		var/datum/prison_sentence/sentence = sentences[who]
		var/mob/living/body = sentence?.body_ref?.resolve()
		if(body && body.stat != DEAD && (body in inside))
			if(isturf(container.loc))
				container.visible_message(span_notice("[container] flickers for a moment, but stays where [container.p_they()] [container.p_are()]."))
			return TRUE
	return NONE

/datum/outpost_prison/proc/on_inmate_state_changed(datum/source)
	SIGNAL_HANDLER
	var/mob/living/body = source
	if(istype(body))
		sync_inmate_traits(body)

/datum/outpost_prison/proc/on_inmate_client_step(mob/living/source, list/move_args)
	SIGNAL_HANDLER
	var/datum/prison_sentence/sentence = sentence_for(source)
	if(sentence)
		sentence.stepped_at = world.time

/datum/outpost_prison/proc/on_inmate_shoved(mob/living/source, mob/living/attacker, zone, obj/item/weapon)
	SIGNAL_HANDLER
	var/datum/prison_sentence/sentence = sentence_for(source)
	if(sentence && isliving(attacker) && attacker != source)
		sentence.shoved_by_ref = WEAKREF(attacker)
		sentence.shoved_at = world.time
		note_inmate_provoked(source, attacker)

/// Grants `victim` a 10-second self-defense window against `attacker` inside the cell block
/datum/outpost_prison/proc/note_inmate_provoked(mob/living/victim, atom/attacker)
	if(!isliving(victim) || !isliving(attacker) || attacker == victim)
		return
	var/datum/prison_sentence/sentence = sentence_for(victim)
	if(!sentence)
		return
	// If the inmate already picked an unprovoked fight, their target hitting back does not excuse more blows
	if(sentence.baton_until > world.time)
		return
	LAZYSET(sentence.provoked_by, WEAKREF(attacker), world.time + OUTPOST_PRISON_INMATE_DEFENSE_WINDOW)

/// Whether `inmate` has an active self-defense window against `target`
/datum/outpost_prison/proc/inmate_defending_against(datum/prison_sentence/sentence, atom/target)
	if(!sentence || !isliving(target) || !LAZYLEN(sentence.provoked_by))
		return FALSE
	var/datum/weakref/key = WEAKREF(target)
	var/until = LAZYACCESS(sentence.provoked_by, key)
	if(until > world.time)
		return TRUE
	if(until)
		LAZYREMOVE(sentence.provoked_by, key)
	return FALSE

/// Records an attack by `attacker` inside the cell block; flags held inmates for the guard baton unless defending themselves
/datum/outpost_prison/proc/note_inmate_attack(atom/attacker, atom/victim, attack_flags = ATTACKER_DAMAGING_ATTACK)
	var/mob/living/inmate = outpost_living_attacker(attacker)
	if(!istype(inmate) || inmate == victim || !in_cell_block(inmate))
		return FALSE
	if(!(attack_flags & (ATTACKER_DAMAGING_ATTACK | ATTACKER_STAMINA_ATTACK)))
		return FALSE
	var/datum/prison_sentence/sentence = sentence_for(inmate)
	if(!sentence || inmate_defending_against(sentence, victim))
		return FALSE
	sentence.baton_until = max(sentence.baton_until, world.time + OUTPOST_PRISON_INMATE_BATON_WINDOW)
	return TRUE

/// Flags `inmate` for the guard baton when they batter, force, hack or climb a cell-block way out
/datum/outpost_prison/proc/note_inmate_breakout(mob/living/inmate, atom/way_out)
	if(!istype(inmate) || !in_cell_block(inmate))
		return FALSE
	var/datum/prison_sentence/sentence = sentence_for(inmate)
	if(!sentence)
		return FALSE
	if(way_out)
		if(!isobj(way_out) || isitem(way_out) || istype(way_out, /obj/machinery/door/window/outpost_prison_yard))
			return FALSE
		var/turf/way_turf = get_turf(way_out)
		var/is_exit = istype(way_out, /obj/machinery/door/airlock/security/prison_staff) || istype(way_out, /obj/machinery/door/window/brigdoor/outpost_prison_staff) || is_exit_blocker(way_out) || ((istype(way_out, /obj/structure/window) || istype(way_out, /obj/structure/grille)) && way_turf && is_exit_tile(way_turf))
		if(!is_exit)
			return FALSE
	sentence.baton_until = max(sentence.baton_until, world.time + OUTPOST_PRISON_INMATE_BATON_WINDOW)
	return TRUE

/// Whether `held` in an inmate's hand counts as a weapon to a guard (mops, soap, clothes, food, dressings and paper do not)
/datum/outpost_prison/proc/is_inmate_weapon(obj/item/held)
	if(QDELETED(held) || (held.item_flags & ABSTRACT))
		return FALSE
	if(istype(held, /obj/item/mop) || istype(held, /obj/item/soap) || istype(held, /obj/item/reagent_containers/cup/bucket))
		return FALSE
	if(istype(held, /obj/item/clothing) || istype(held, /obj/item/paper) || istype(held, /obj/item/mail) || istype(held, /obj/item/food) || istype(held, /obj/item/stack/medical) || istype(held, /obj/item/toy) || istype(held, /obj/item/outpost_prison_contraband))
		return FALSE
	if(istype(held, /obj/item/gun) || istype(held, /obj/item/melee/baton) || istype(held, /obj/item/knife))
		return TRUE
	return held.force >= 10 || !!held.get_sharpness()

/// Whether `inmate` holds a weapon in hand right now
/datum/outpost_prison/proc/inmate_holds_weapon(mob/living/inmate)
	if(!istype(inmate))
		return FALSE
	for(var/obj/item/held as anything in inmate.held_items)
		if(held && is_inmate_weapon(held))
			return TRUE
	return FALSE

/// Whether `inmate` is floored, unconscious or incapacitated enough for a guard to stop batoning them
/datum/outpost_prison/proc/inmate_down_for_guard(mob/living/inmate)
	if(QDELETED(inmate) || inmate.stat != CONSCIOUS)
		return TRUE
	return HAS_TRAIT(inmate, TRAIT_INCAPACITATED) || HAS_TRAIT(inmate, TRAIT_CRITICAL_CONDITION) || HAS_TRAIT(inmate, TRAIT_FLOORED)

/// Whether guards in the cell block should baton `inmate` right now
/datum/outpost_prison/proc/inmate_baton_warranted(mob/living/inmate)
	var/datum/prison_sentence/sentence = sentence_for(inmate)
	if(!sentence || !in_cell_block(inmate) || inmate_down_for_guard(inmate))
		return FALSE
	return sentence.baton_until > world.time || inmate_holds_weapon(inmate)

/// Active sentence for `person`, or the sentence on `person` that just ended by death in custody this tick
/datum/outpost_prison/proc/cell_block_inmate_sentence(mob/living/person)
	var/datum/prison_sentence/active = sentence_for(person)
	if(active)
		return active
	if(!istype(person))
		return null
	for(var/datum/mind/candidate as anything in sentences)
		var/datum/prison_sentence/check = sentences[candidate]
		if(check?.body_ref?.resolve() == person && check.died_in_custody_at == world.time)
			return check
	return null

/// Records a damaging cell-block blow by held inmate `attacker` against cell-block inmate `victim` so a seen kill reports OUTPOST_CRIME_MURDER
/datum/outpost_prison/proc/note_inmate_cell_damage(mob/living/attacker, mob/living/victim)
	if(!istype(attacker) || !istype(victim) || attacker == victim || !in_cell_block(attacker) || !in_cell_block(victim))
		return
	var/datum/prison_sentence/attacker_sentence = sentence_for(attacker)
	var/datum/prison_sentence/victim_sentence = cell_block_inmate_sentence(victim)
	if(!attacker_sentence || !victim_sentence || victim_sentence.murder_reported)
		return
	victim_sentence.last_inmate_attacker_ref = WEAKREF(attacker)
	victim_sentence.last_inmate_attack_at = world.time
	victim_sentence.last_inmate_attack_justified = inmate_defending_against(attacker_sentence, victim)
	victim_sentence.last_inmate_attack_seen = prisoner_violence_seen(attacker, victim)
	if(victim.stat == DEAD && victim_sentence.died_in_custody_at == world.time && !victim_sentence.last_inmate_attack_justified)
		report_inmate_murdered(victim_sentence, victim)

/// Reports OUTPOST_CRIME_MURDER when a held inmate's unprovoked cell-block attack kills another inmate and someone saw the attack or death
/datum/outpost_prison/proc/report_inmate_murdered(datum/prison_sentence/victim_sentence, mob/living/victim)
	if(!victim_sentence || victim_sentence.murder_reported || victim_sentence.last_inmate_attack_justified || !victim_sentence.last_inmate_attack_at)
		return FALSE
	if(world.time - victim_sentence.last_inmate_attack_at > OUTPOST_POLICE_KILL_WINDOW)
		return FALSE
	var/mob/living/killer = victim_sentence.last_inmate_attacker_ref?.resolve()
	if(QDELETED(killer) || !killer.mind || killer == victim || !outpost?.police)
		return FALSE
	if(!victim_sentence.last_inmate_attack_seen && !prisoner_violence_seen(killer, victim))
		return FALSE
	victim_sentence.murder_reported = TRUE
	victim_sentence.last_inmate_attack_at = 0
	var/datum/weakref/victim_ref = WEAKREF(victim)
	var/datum/outpost_warrant/killer_warrant = outpost.police.get_warrant(killer.mind)
	var/already_counted_on_death = killer_warrant?.last_crime_at == world.time && killer_warrant.recent_victims?[victim_ref] == world.time
	if(!already_counted_on_death)
		outpost.police.count_crime(killer, OUTPOST_CRIME_MURDER, victim)
		killer_warrant = outpost.police.get_warrant(killer.mind)
	if(killer_warrant?.recent_victims)
		killer_warrant.recent_victims -= victim_ref
	if(holds(killer.mind))
		var/datum/prison_sentence/killer_sentence = sentences[killer.mind]
		var/stars = outpost.police.get_stars(killer.mind)
		if(killer_sentence && stars >= 1)
			var/clamped_stars = clamp(stars, 1, length(OUTPOST_POLICE_JAIL))
			killer_sentence.total_seconds = max(killer_sentence.total_seconds, round(OUTPOST_POLICE_JAIL[clamped_stars] / (1 SECONDS)))
			update_lockup_boards()
	return TRUE

/datum/outpost_prison/proc/on_inmate_was_attacked(datum/source, atom/attacker, attack_flags)
	SIGNAL_HANDLER
	var/mob/living/victim = source
	if(!istype(victim))
		return
	var/mob/living/living_attacker = outpost_living_attacker(attacker)
	if(isliving(living_attacker) && living_attacker != victim)
		note_inmate_attack(living_attacker, victim, attack_flags)
		if(attack_flags & ATTACKER_DAMAGING_ATTACK)
			note_inmate_cell_damage(living_attacker, victim)
		if(attack_flags & (ATTACKER_DAMAGING_ATTACK | ATTACKER_STAMINA_ATTACK | ATTACKER_SHOVING))
			note_inmate_provoked(victim, living_attacker)

/datum/outpost_prison/proc/on_inmate_item_attack(mob/living/source, mob/living/target_mob, mob/living/user, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	if(target_mob == source || !in_cell_block(source))
		return NONE
	var/obj/item/held = source.get_active_held_item()
	if(!held || (held.item_flags & NOBLUDGEON))
		return NONE
	var/is_baton = istype(held, /obj/item/melee/baton)
	if(held.force > 0 || is_baton || is_inmate_weapon(held))
		note_inmate_attack(source, target_mob, ATTACKER_DAMAGING_ATTACK)
	return NONE

/datum/outpost_prison/proc/on_inmate_attack_atom(mob/living/source, atom/attacked_atom, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	if(!in_cell_block(source))
		return NONE
	var/obj/item/held = source.get_active_held_item()
	if(held && (held.force > 0 || is_inmate_weapon(held)))
		note_inmate_breakout(source, attacked_atom)
	return NONE

/datum/outpost_prison/proc/on_inmate_unarmed_attack(mob/living/source, atom/target, proximity, modifiers)
	SIGNAL_HANDLER
	if(!proximity || !source.combat_mode || LAZYACCESS(modifiers, RIGHT_CLICK) || !in_cell_block(source))
		return NONE
	if(isliving(target))
		var/mob/living/living_target = target
		if(living_target != source && living_target.stat != DEAD && !is_ai_outpost_prison_guard(living_target))
			note_inmate_attack(source, living_target, ATTACKER_DAMAGING_ATTACK)
	else if(HAS_TRAIT(source, TRAIT_HULK) || isalien(source))
		note_inmate_breakout(source, target)
	return NONE

/// Whoever is pulling, carrying, holding in a bag/closet, pushing on a bed or throwing `body` right now
/datum/outpost_prison/proc/inmate_mover_now(mob/living/body)
	var/atom/movable/cursor = body
	while(ismovable(cursor))
		if(isliving(cursor) && cursor != body)
			return cursor
		if(isliving(cursor.pulledby) && cursor.pulledby != body)
			return cursor.pulledby
		if(isliving(cursor))
			var/mob/living/living_cursor = cursor
			if(isliving(living_cursor.buckled) && living_cursor.buckled != body)
				return living_cursor.buckled
			var/atom/movable/seat = living_cursor.buckled
			if(ismovable(seat) && isliving(seat.pulledby) && seat.pulledby != body)
				return seat.pulledby
		var/datum/thrownthing/flight = cursor.throwing
		var/mob/thrower = flight?.get_thrower()
		if(isliving(thrower) && thrower != body)
			return thrower
		if(isturf(cursor.loc) || !ismovable(cursor.loc))
			break
		cursor = cursor.loc
	return null

/// Whoever shoved or bumped `subject` out of `old_loc` in this tick
/datum/outpost_prison/proc/inmate_pusher_of(atom/movable/subject, mob/living/body, atom/old_loc, datum/prison_sentence/sentence)
	if(sentence.shoved_at == world.time)
		var/mob/living/shover = sentence.shoved_by_ref?.resolve()
		sentence.shoved_by_ref = null
		sentence.shoved_at = 0
		if(isliving(shover) && shover != body)
			return shover
	var/turf/old_turf = get_turf(old_loc)
	if(!old_turf)
		return null
	for(var/mob/living/other in range(1, old_turf))
		if(other != body && other != subject && other.now_pushing)
			return other
	return null

/datum/outpost_prison/proc/on_inmate_moved(mob/living/source, atom/old_loc, movement_dir, forced, list/old_locs)
	SIGNAL_HANDLER
	if(QDELETED(src))
		return
	var/datum/prison_sentence/sentence = sentence_for(source)
	if(!sentence)
		return
	sync_inmate_container_watch(sentence, source)
	if(in_inmate_bounds(source))
		if(sentence.return_left > 0)
			sentence.return_left = 0
			sentence.wants_return = FALSE
			sentence.walked_out = FALSE
			sentence.carried_by_ref = null
			sentence.carry_reported = FALSE
			update_lockup_boards()
		return
	if(sentence.return_left > 0 || sentence.carried_by_ref || sentence.walked_out)
		return
	var/mob/living/mover = inmate_mover_now(source) || inmate_pusher_of(source, source, old_loc, sentence)
	if(mover && mover != source)
		sentence.carried_by_ref = WEAKREF(mover)
	else if(sentence.stepped_at == world.time || (!forced && isturf(source.loc) && source.stat == CONSCIOUS && !source.incapacitated && !HAS_TRAIT(source, TRAIT_RESTRAINED)))
		sentence.walked_out = TRUE

/datum/outpost_prison/proc/on_inmate_container_moved(atom/movable/container, atom/old_loc, movement_dir, forced, list/old_locs)
	SIGNAL_HANDLER
	if(QDELETED(src) || QDELETED(container))
		return
	var/datum/weakref/container_ref = WEAKREF(container)
	for(var/datum/mind/who as anything in sentences)
		if(!holds(who))
			continue
		var/datum/prison_sentence/sentence = sentences[who]
		if(!sentence || !length(sentence.watched_container_refs) || !(container_ref in sentence.watched_container_refs))
			continue
		var/mob/living/body = sentence.body_ref?.resolve()
		if(!body)
			continue
		sync_inmate_container_watch(sentence, body)
		if(in_inmate_bounds(body))
			if(sentence.return_left > 0)
				sentence.return_left = 0
				sentence.wants_return = FALSE
				sentence.walked_out = FALSE
				sentence.carried_by_ref = null
				sentence.carry_reported = FALSE
				update_lockup_boards()
			continue
		if(sentence.carried_by_ref)
			continue
		var/mob/living/mover = inmate_mover_now(body) || inmate_pusher_of(container, body, old_loc, sentence)
		if(mover && mover != body)
			sentence.carried_by_ref = WEAKREF(mover)

/datum/outpost_prison/proc/on_inmate_died_sig(mob/living/source, gibbed)
	SIGNAL_HANDLER
	if(!QDELETED(src))
		on_inmate_death(source)

/datum/outpost_prison/proc/on_inmate_mind_transferred(datum/mind/source, mob/previous_body)
	SIGNAL_HANDLER
	if(QDELETED(src) || !source)
		return
	var/datum/prison_sentence/sentence = sentences[source]
	if(!sentence || sentence.released || sentence.escaped)
		return
	var/mob/living/old_body = isliving(previous_body) ? previous_body : sentence.body_ref?.resolve()
	resolve_missing_inmate_body(source, sentence, old_body)

/// Resolves a booked inmate body that was deleted without dying or lost its mind: rebinds a live mind swap (or flags escape outside bounds) and never pardons warrants
/datum/outpost_prison/proc/resolve_missing_inmate_body(datum/mind/who, datum/prison_sentence/sentence, mob/living/old_body)
	if(!sentence || sentence.released || sentence.escaped)
		return
	var/mob/living/new_body = isliving(who?.current) ? who.current : null
	if(new_body && !QDELETED(new_body) && new_body != old_body && new_body.stat != DEAD)
		unhook_inmate(sentence)
		if(!QDELETED(old_body))
			outpost_police_drop_used_cuffs(old_body)
		sentence.body_ref = WEAKREF(new_body)
		hook_inmate(sentence, new_body)
		if(!in_inmate_bounds(new_body))
			inmate_escaped(who, new_body)
		else
			update_lockup_boards()
		return
	if(!QDELETED(old_body) && old_body.stat == DEAD && (!old_body.mind || old_body.mind == who))
		on_inmate_death(old_body)
		return
	sentence.released = TRUE
	sentence.return_left = 0
	sentence.wants_return = FALSE
	unhook_inmate(sentence)
	if(!QDELETED(old_body))
		outpost_police_drop_used_cuffs(old_body)
	var/datum/outpost_police/police = outpost?.police
	police?.mark_locker_released(who)
	police?.update_hud(who)
	police?.wake()
	update_lockup_boards()

/datum/outpost_prison/proc/on_inmate_body_qdel(mob/living/source)
	SIGNAL_HANDLER
	if(QDELETED(src))
		return
	for(var/datum/mind/who as anything in sentences.Copy())
		var/datum/prison_sentence/sentence = sentences[who]
		if(!sentence || sentence.body_ref?.resolve() != source || sentence.released || sentence.escaped)
			continue
		resolve_missing_inmate_body(who, sentence, source)
	update_lockup_boards()

/// Whether `body` outside the wing can walk back into it on its own feet right now
/datum/outpost_prison/proc/inmate_can_walk_back(mob/living/body, datum/mind/who)
	if(body.stat != CONSCIOUS || body.incapacitated || HAS_TRAIT(body, TRAIT_FLOORED) || HAS_TRAIT(body, TRAIT_IMMOBILIZED) || HAS_TRAIT(body, TRAIT_RESTRAINED))
		return FALSE
	if(body.pulledby || body.buckled || body.throwing)
		return FALSE
	if(!isturf(body.loc))
		if(istype(body.loc, /obj/structure/closet))
			var/obj/structure/closet/closet = body.loc
			if(closet.welded || closet.locked || closet.strong_grab || closet.pulledby || !isturf(closet.loc))
				return FALSE
		else if(istype(body.loc, /obj/vehicle))
			var/obj/vehicle/vehicle = body.loc
			if(vehicle.pulledby || !isturf(vehicle.loc))
				return FALSE
		else
			return FALSE
	if((body.mind?.key || who?.key) && !body.client)
		return FALSE
	return TRUE

// =========================================================================
// BOOKING
// =========================================================================

/// Where an arresting officer walks a suspect to book them into this wing (outside Processing's outer door)
/datum/outpost_prison/proc/booking_door_turf()
	if(has_processing())
		return processing_outside_turf(processing_door(FALSE))
	for(var/turf/door_tile as anything in guard_yard_doors())
		var/obj/machinery/door/airlock/door = locate() in door_tile
		if(door && (door.locked || door.welded || !door.hasPower()))
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/step_tile = get_step(door_tile, direction)
			if(step_tile && contains_turf(step_tile) && !in_cell_block(step_tile) && !isclosedturf(step_tile) && !(locate(/obj/machinery/door) in step_tile))
				return step_tile
	return null

/// Whether this wing can take `suspect` right now: running, a wing locker free, Processing usable, suspect alive and out of crit
/datum/outpost_prison/proc/can_book(mob/living/carbon/suspect)
	if(QDELETED(src) || QDELETED(outpost) || QDELETED(wing) || !outpost.police)
		return FALSE
	if(!iscarbon(suspect) || QDELETED(suspect) || !suspect.mind || !ishuman(suspect))
		return FALSE
	if(suspect.stat == DEAD || HAS_TRAIT(suspect, TRAIT_CRITICAL_CONDITION))
		return FALSE
	if(holds(suspect.mind))
		return FALSE
	if(!outpost.police.property_locker_for(suspect, must_shut = TRUE, in_area = wing, evict_oldest = FALSE))
		return FALSE
	if(has_processing())
		var/obj/machinery/door/airlock/security/prison_staff/inner = processing_door(TRUE)
		var/obj/machinery/door/airlock/security/prison_staff/outer = processing_door(FALSE)
		if(QDELETED(inner) || QDELETED(outer))
			return FALSE
		if(inner.locked || inner.welded || !inner.hasPower() || inner.lockup_breached())
			return FALSE
		if(outer.locked || outer.welded || !outer.hasPower() || outer.lockup_breached())
			return FALSE
		if(processing_outsider_inside())
			return FALSE
		if(!booking_door_turf())
			return FALSE
	return TRUE

/// Step delay during booking walks, scaled by GLOB.outpost_police_property_time_scale for tests
/datum/outpost_prison/proc/booking_step_pause()
	return max(1, round(0.15 SECONDS * GLOB.outpost_police_property_time_scale))

/// Opens `door` through its normal airlock open() and waits briefly for it to finish opening
/datum/outpost_prison/proc/booking_wait_door_open(obj/machinery/door/airlock/door)
	if(QDELETED(door))
		return FALSE
	if(!door.density && !door.operating)
		return TRUE
	var/deadline = world.time + 4 SECONDS
	while(world.time < deadline)
		if(QDELETED(src) || QDELETED(door))
			return FALSE
		if(!door.density && !door.operating)
			return TRUE
		if(door.operating)
			sleep(1)
			continue
		if(door.open())
			return TRUE
		sleep(0.2 SECONDS)
	return !QDELETED(door) && !door.density

/// Closes `door` through its normal airlock close() once its doorway is clear
/datum/outpost_prison/proc/booking_wait_door_shut(obj/machinery/door/airlock/door)
	if(QDELETED(door))
		return FALSE
	if(door.density && !door.operating)
		return TRUE
	var/deadline = world.time + 4 SECONDS
	while(world.time < deadline)
		if(QDELETED(src) || QDELETED(door))
			return FALSE
		if(door.density && !door.operating)
			return TRUE
		if(door.operating)
			sleep(1)
			continue
		var/blocked = FALSE
		for(var/atom/movable/thing in get_turf(door))
			if(thing != door && !iseffect(thing) && (isliving(thing) || thing.density))
				blocked = TRUE
				break
		if(!blocked && door.close())
			return TRUE
		sleep(0.2 SECONDS)
	return !QDELETED(door) && door.density

/// Walks `officer` pulling `suspect` through `door` into `inside_turfs` using real Move() steps (never forceMove)
/datum/outpost_prison/proc/booking_walk_pair_in(mob/living/carbon/suspect, mob/living/officer, obj/machinery/door/airlock/door, list/inside_turfs)
	var/turf/door_turf = get_turf(door)
	var/turf/outside_turf = processing_outside_turf(door)
	if(!door_turf || !length(inside_turfs))
		return FALSE
	var/turf/entry_tile
	for(var/direction in GLOB.cardinals)
		var/turf/candidate = get_step(door_turf, direction)
		if((candidate in inside_turfs) && !candidate.density)
			entry_tile = candidate
			break
	if(!entry_tile)
		entry_tile = inside_turfs[1]
	if(suspect.buckled)
		suspect.buckled.unbuckle_mob(suspect, TRUE)
	var/pause = booking_step_pause()
	if(!officer)
		if(!(get_turf(suspect) in inside_turfs))
			if(get_turf(suspect) != door_turf && suspect.Adjacent(door_turf))
				suspect.Move(door_turf, get_dir(suspect, door_turf))
				sleep(pause)
			if(!QDELETED(suspect) && get_turf(suspect) == door_turf)
				suspect.Move(entry_tile, get_dir(suspect, entry_tile))
				sleep(pause)
		return !QDELETED(suspect) && (get_turf(suspect) in inside_turfs)

	var/old_officer_intent = officer.move_intent
	var/old_officer_combat = officer.combat_mode
	var/old_suspect_intent = suspect.move_intent
	officer.move_intent = MOVE_INTENT_RUN
	officer.combat_mode = FALSE
	suspect.move_intent = MOVE_INTENT_RUN

	if(!(get_turf(suspect) in inside_turfs))
		for(var/step_try in 1 to 4)
			if(QDELETED(src) || QDELETED(officer) || QDELETED(suspect) || officer.stat == DEAD || officer.Adjacent(suspect))
				break
			step_towards(officer, suspect)
			sleep(pause)
		if(QDELETED(src) || QDELETED(officer) || QDELETED(suspect) || officer.stat == DEAD || !officer.Adjacent(suspect))
			suspect?.move_intent = old_suspect_intent
			officer?.move_intent = old_officer_intent
			officer?.combat_mode = old_officer_combat
			return FALSE
		if(officer.pulling != suspect)
			officer.start_pulling(suspect)
		if(officer.pulling != suspect)
			suspect.move_intent = old_suspect_intent
			officer.move_intent = old_officer_intent
			officer.combat_mode = old_officer_combat
			return FALSE

		if(outside_turf)
			for(var/step_try in 1 to 3)
				if(QDELETED(src) || QDELETED(officer) || QDELETED(suspect) || officer.stat == DEAD)
					break
				var/turf/here = get_turf(officer)
				if(!here || here == outside_turf || here == door_turf || (here in inside_turfs))
					break
				step_towards(officer, outside_turf)
				sleep(pause)

		if(!QDELETED(src) && !QDELETED(officer) && !QDELETED(suspect) && officer.stat != DEAD && get_turf(officer) != door_turf && !(get_turf(officer) in inside_turfs))
			if(officer.pulling != suspect && officer.Adjacent(suspect))
				officer.start_pulling(suspect)
			officer.Move(door_turf, get_dir(officer, door_turf))
			sleep(pause)

		if(!QDELETED(src) && !QDELETED(officer) && !QDELETED(suspect) && officer.stat != DEAD && !(get_turf(officer) in inside_turfs))
			if(officer.pulling != suspect && officer.Adjacent(suspect))
				officer.start_pulling(suspect)
			officer.Move(entry_tile, get_dir(officer, entry_tile))
			sleep(pause)

		if(!QDELETED(src) && !QDELETED(officer) && !QDELETED(suspect) && officer.stat != DEAD && get_turf(officer) == entry_tile)
			var/turf/deeper
			for(var/direction in GLOB.cardinals)
				var/turf/neighbor = get_step(entry_tile, direction)
				if((neighbor in inside_turfs) && !neighbor.density)
					deeper = neighbor
					break
			if(deeper)
				if(officer.pulling != suspect && officer.Adjacent(suspect))
					officer.start_pulling(suspect)
				officer.Move(deeper, get_dir(officer, deeper))
				sleep(pause)
				officer.stop_pulling()
				if(!QDELETED(src) && !QDELETED(officer) && !QDELETED(suspect) && officer.stat != DEAD && get_turf(suspect) == entry_tile && get_turf(officer) == deeper)
					officer.Move(entry_tile, get_dir(officer, entry_tile))
					sleep(pause)
		officer?.stop_pulling()
	else
		officer.stop_pulling()
		if(!officer.Adjacent(suspect))
			if(get_turf(officer) != door_turf && !(get_turf(officer) in inside_turfs))
				officer.Move(door_turf, get_dir(officer, door_turf))
				sleep(pause)
			if(!QDELETED(officer) && !QDELETED(suspect) && !officer.Adjacent(suspect))
				officer.Move(entry_tile, get_dir(officer, entry_tile))
				sleep(pause)

	if(!QDELETED(suspect))
		suspect.move_intent = old_suspect_intent
	if(!QDELETED(officer))
		officer.move_intent = old_officer_intent
		officer.combat_mode = old_officer_combat
	return !QDELETED(src) && !QDELETED(suspect) && !QDELETED(officer) && officer.stat != DEAD && (get_turf(suspect) in inside_turfs) && officer.Adjacent(suspect)

/// Walks `officer` back out through `door` onto `outside_turf` using real Move() steps
/datum/outpost_prison/proc/booking_walk_officer_out(mob/living/officer, obj/machinery/door/airlock/door, turf/outside_turf, list/inside_turfs)
	if(QDELETED(src) || QDELETED(officer) || officer.stat == DEAD || !door || !outside_turf)
		return FALSE
	var/turf/door_turf = get_turf(door)
	if(!door_turf)
		return FALSE
	if(get_turf(officer) == outside_turf)
		return TRUE
	if((get_turf(officer) in inside_turfs) && !booking_wait_door_open(door))
		return FALSE
	var/turf/entry_tile
	for(var/direction in GLOB.cardinals)
		var/turf/candidate = get_step(door_turf, direction)
		if((candidate in inside_turfs) && !candidate.density)
			entry_tile = candidate
			break
	var/old_intent = officer.move_intent
	var/old_combat = officer.combat_mode
	officer.move_intent = MOVE_INTENT_RUN
	officer.combat_mode = FALSE
	officer.stop_pulling()
	var/pause = booking_step_pause()

	if((get_turf(officer) in inside_turfs) && entry_tile && get_turf(officer) != entry_tile)
		for(var/step_try in 1 to 4)
			if(QDELETED(src) || QDELETED(officer) || officer.stat == DEAD || get_turf(officer) == entry_tile)
				break
			step_towards(officer, entry_tile)
			sleep(pause)
	if(!QDELETED(src) && !QDELETED(officer) && officer.stat != DEAD && get_turf(officer) == entry_tile)
		officer.Move(door_turf, get_dir(officer, door_turf))
		sleep(pause)
	if(!QDELETED(src) && !QDELETED(officer) && officer.stat != DEAD && get_turf(officer) == door_turf)
		officer.Move(outside_turf, get_dir(officer, outside_turf))
		sleep(pause)
	if(!QDELETED(officer))
		officer.move_intent = old_intent
		officer.combat_mode = old_combat
	return !QDELETED(officer) && officer.stat != DEAD && get_turf(officer) == outside_turf

/// Records `suspect` as a held inmate with a fresh term for `stars`, hooks traits/signals, notifies their crew and updates boards
/datum/outpost_prison/proc/admit_inmate_sentence(mob/living/carbon/suspect, datum/outpost_warrant/warrant, stars, custom_seconds = null, admin_booked = FALSE)
	var/datum/mind/mind = suspect.mind
	var/datum/prison_sentence/sentence = sentences[mind]
	if(!sentence)
		sentence = new /datum/prison_sentence
		sentences[mind] = sentence
	else
		unhook_inmate(sentence)
	var/clamped_stars = clamp(stars, 1, length(OUTPOST_POLICE_JAIL))
	sentence.mind = mind
	sentence.body_ref = WEAKREF(suspect)
	sentence.stars_at_booking = clamped_stars
	sentence.admin_booked = !!admin_booked
	sentence.total_seconds = (!isnull(custom_seconds) && custom_seconds > 0) ? round(custom_seconds) : round(OUTPOST_POLICE_JAIL[clamped_stars] / (1 SECONDS))
	sentence.seconds_served = 0
	sentence.seconds_worked_off = 0
	sentence.bail_elapsed = 0
	sentence.return_left = 0
	sentence.wants_return = FALSE
	sentence.walked_out = FALSE
	sentence.stepped_at = 0
	sentence.carried_by_ref = null
	sentence.shoved_by_ref = null
	sentence.shoved_at = 0
	sentence.carry_reported = FALSE
	sentence.escaped = FALSE
	sentence.released = FALSE
	sentence.tip_given = FALSE
	sentence.provoked_by = null
	sentence.baton_until = 0
	sentence.last_inmate_attacker_ref = null
	sentence.last_inmate_attack_at = 0
	sentence.last_inmate_attack_justified = FALSE
	sentence.last_inmate_attack_seen = FALSE
	sentence.died_in_custody_at = 0
	sentence.murder_reported = FALSE
	processing_release_refs -= WEAKREF(suspect)
	hook_inmate(sentence, suspect)
	var/datum/outpost_police/police = outpost?.police
	if(police)
		police.wake()
		police.update_hud(mind)
		SEND_SIGNAL(police, COMSIG_OUTPOST_POLICE_BOOKED, suspect, TRUE)
		var/datum/voidcrew_crew_record/crew = warrant ? police.current_warrant_crew(warrant) : mind.get_reputation_crew()
		for(var/obj/structure/overmap/ship/ship as anything in police.crew_ship_list(crew))
			ship.ship_notify("[outpost_log_name()] Security: [suspect.real_name] is in the lockup.", "LOCKUP NOTICE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 30)
	update_lockup_boards()
	add_log("[suspect.real_name] was booked in ([clamped_stars] star\s, [max(1, round(sentence.total_seconds / 60))] min).")
	record_lockup_booking(src, suspect, clamped_stars, sentence.total_seconds, sentence.admin_booked)
	return sentence

/// Picks an open yard floor turf inside `cell_block` for an admin booking
/datum/outpost_prison/proc/admin_yard_turf()
	var/turf/fallback
	for(var/turf/open/tile in cell_block)
		if(tile.density || (locate(/obj/machinery/door) in tile))
			continue
		fallback ||= tile
		if(!cell_at(tile) && prisoner_can_stand(tile))
			return tile
	return fallback

/// Admin Manipulator hook: books `suspect` into this lockup for `seconds` (stripping to a wing locker when available)
/datum/outpost_prison/proc/admin_book_player(mob/living/carbon/human/suspect, seconds)
	if(QDELETED(src) || !istype(suspect) || QDELETED(suspect) || ishumannpc(suspect) || suspect.stat == DEAD || !suspect.mind || !isnum(seconds) || seconds < 1)
		return FALSE
	var/already_held = holds(suspect.mind)
	for(var/datum/outpost_prison/other as anything in GLOB.outpost_prisons)
		if(other && other != src && other.holds(suspect.mind))
			var/datum/prison_sentence/other_sentence = other.sentences[suspect.mind]
			if(other_sentence)
				other_sentence.released = TRUE
				other_sentence.return_left = 0
				other_sentence.wants_return = FALSE
				other.unhook_inmate(other_sentence)
			other.processing_release_refs -= WEAKREF(suspect)
			other.update_lockup_boards()
			if(other.outpost != outpost)
				other.outpost?.police?.mark_locker_released(suspect.mind)
				other.outpost?.police?.update_hud(suspect.mind)
	for(var/obj/structure/overmap/trader_outpost/other_outpost as anything in GLOB.trader_outposts)
		for(var/datum/outpost_police_cell/cell as anything in other_outpost?.police?.cells)
			if(cell?.holds(suspect.mind, suspect))
				cell.forget_prisoner(suspect.mind)
				if(other_outpost != outpost)
					other_outpost?.police?.mark_locker_released(suspect.mind)
					other_outpost?.police?.update_hud(suspect.mind)
	suspect.pulledby?.stop_pulling()
	suspect.stop_pulling()
	if(suspect.buckled)
		suspect.buckled.unbuckle_mob(suspect, force = TRUE)
	var/datum/outpost_police/police = outpost?.police
	if(police)
		if(!already_held)
			police.store_property(suspect, null, wing)
			if(QDELETED(src) || QDELETED(suspect) || suspect.stat == DEAD || !suspect.mind)
				return FALSE
		booking_uncuff_prisoner(suspect, null, police)
	else
		suspect.uncuff()
	if(!suspect.w_uniform)
		suspect.equip_to_slot_or_del(new /obj/item/clothing/under/rank/prisoner(suspect), ITEM_SLOT_ICLOTHING, indirect_action = TRUE)
	if(!suspect.shoes)
		suspect.equip_to_slot_or_del(new /obj/item/clothing/shoes/sneakers/orange(suspect), ITEM_SLOT_FEET, indirect_action = TRUE)
	if(!in_inmate_bounds(suspect))
		var/turf/yard_spot = admin_yard_turf()
		if(!yard_spot)
			return FALSE
		suspect.forceMove(yard_spot)
	if(!in_inmate_bounds(suspect))
		return FALSE
	var/datum/outpost_warrant/warrant = police?.get_warrant(suspect.mind)
	var/stars = max(1, police ? police.get_stars(suspect.mind) : 1)
	admit_inmate_sentence(suspect, warrant, stars, custom_seconds = round(seconds), admin_booked = TRUE)
	if(!already_held)
		greet_new_inmate(suspect)
	return TRUE

/// Has a conscious yard prisoner greet a newly arrived inmate ("Fresh one.")
/datum/outpost_prison/proc/greet_new_inmate(mob/living/suspect)
	var/mob/living/carbon/human/npc/outpost_prisoner/fallback
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner as anything in shuffle(prisoners))
		if(QDELETED(prisoner) || prisoner.stat != CONSCIOUS || prisoner.phase != PRISONER_PRESENT || prisoner.in_trouble() || prisoner.activity?.sleeping)
			continue
		fallback ||= prisoner
		if(suspect && (suspect in view(7, prisoner)))
			note_speech()
			prisoner.last_line = "Fresh one."
			prisoner.say("Fresh one.")
			return
	if(fallback)
		note_speech()
		fallback.last_line = "Fresh one."
		fallback.say("Fresh one.")

/// Strips `suspect` into a property locker inside this wing (`store_property(..., wing)`), never overflowing clothes-on
/datum/outpost_prison/proc/booking_strip_prisoner(mob/living/carbon/suspect, mob/living/officer, datum/outpost_police/police)
	if(!officer)
		return police.store_property(suspect, null, wing)
	var/wait_until = world.time + 20 SECONDS
	for(var/attempt in 1 to 3)
		if(QDELETED(src) || QDELETED(suspect) || !suspect.mind || !ishuman(suspect))
			return FALSE
		while(!QDELETED(officer) && officer.stat != DEAD && (officer.stat != CONSCIOUS || HAS_TRAIT(officer, TRAIT_INCAPACITATED)) && world.time < wait_until)
			sleep(0.5 SECONDS)
		if(QDELETED(src) || QDELETED(suspect) || !suspect.mind || !ishuman(suspect))
			return FALSE
		if(QDELETED(officer) || officer.stat != CONSCIOUS || HAS_TRAIT(officer, TRAIT_INCAPACITATED))
			return FALSE
		if(!police.property_strip_check(suspect, officer))
			return FALSE
		if(police.store_property(suspect, officer, wing))
			return TRUE
	return FALSE

/// Removes `suspect`'s restraints and stores any non-police cuffs in their wing locker so nothing stays loose in Processing
/datum/outpost_prison/proc/booking_uncuff_prisoner(mob/living/carbon/suspect, mob/living/officer, datum/outpost_police/police, turf/outside_turf = null)
	var/list/worn_restraints = list()
	if(suspect.handcuffed)
		worn_restraints += suspect.handcuffed
	if(suspect.legcuffed)
		worn_restraints += suspect.legcuffed
	if(officer)
		police.cell_remove_cuffs(suspect, officer)
	else
		suspect.uncuff()
	for(var/obj/item/restraint as anything in worn_restraints)
		if(QDELETED(restraint) || restraint == suspect.handcuffed || restraint == suspect.legcuffed)
			continue
		if(!police.store_extra_property(suspect, restraint, wing) && outside_turf && isturf(restraint.loc) && !outpost_police_untouchable(restraint))
			restraint.forceMove(outside_turf)

/**
 * Books `suspect` into this lockup: strips their gear into the nearest free wing locker, walks them into Processing,
 * takes the cuffs off, walks `officer` out, shuts the outer door, opens the inner door to the yard and starts their
 * sentence. Sleeps. Returns TRUE once held, or FALSE (leaving warrant and clothes untouched if no locker could take
 * them) so the police arrest falls back to today's path.
 */
/datum/outpost_prison/proc/book_player(mob/living/carbon/suspect, mob/living/officer = null, datum/outpost_warrant/warrant = null)
	if(!can_book(suspect))
		return FALSE
	if(officer && (QDELETED(officer) || officer.stat == DEAD))
		return FALSE
	var/datum/outpost_police/police = outpost.police
	var/datum/mind/mind = suspect.mind
	warrant ||= police.get_warrant(mind)
	var/stars = police.get_stars(mind)
	if(!warrant || warrant.heat <= 0 || stars < 1)
		return FALSE

	var/stripped = booking_strip_prisoner(suspect, officer, police)
	if(!stripped || QDELETED(src) || QDELETED(suspect) || suspect.mind != mind || suspect.stat == DEAD || HAS_TRAIT(suspect, TRAIT_CRITICAL_CONDITION))
		if(stripped && !police.cell_holding(mind))
			police.mark_locker_released(mind)
		return FALSE

	var/use_processing = has_processing()
	var/obj/machinery/door/airlock/security/prison_staff/inner
	var/obj/machinery/door/airlock/security/prison_staff/outer
	if(use_processing)
		var/wait_pause = max(1, round(0.5 SECONDS * GLOB.outpost_police_property_time_scale))
		var/max_waits = max(30, round((15 SECONDS) / wait_pause))
		for(var/wait_step in 1 to max_waits)
			if(QDELETED(src) || QDELETED(suspect))
				break
			var/obj/machinery/door/airlock/inner_check = processing_door(TRUE)
			if(processing_state == OUTPOST_PROCESSING_IDLE && inner_check && !processing_shut(inner_check))
				processing_work_door(inner_check, FALSE)
			if(processing_state == OUTPOST_PROCESSING_IDLE && unclaimed_catch_in_processing())
				claim_idle_seconds = max(claim_idle_seconds, OUTPOST_PRISON_PROCESSING_WAIT)
			if(processing_state == OUTPOST_PROCESSING_IDLE && processing_shut(inner_check) && !processing_outsider_inside() && !processing_inmate_inside())
				break
			sleep(wait_pause)
		if(QDELETED(src) || QDELETED(suspect) || suspect.mind != mind || !can_book(suspect) || processing_state != OUTPOST_PROCESSING_IDLE || processing_inmate_inside())
			if(!police.cell_holding(mind))
				police.mark_locker_released(mind)
			return FALSE
		inner = processing_door(TRUE)
		outer = processing_door(FALSE)
		if(!booking_wait_door_shut(inner) || processing_outsider_inside() || processing_inmate_inside())
			if(!police.cell_holding(mind))
				police.mark_locker_released(mind)
			return FALSE
		processing_state = OUTPOST_PROCESSING_BOOK
		processing_who_ref = WEAKREF(suspect)
		booking_mover_ref = officer ? WEAKREF(officer) : null
		processing_entry_ref = WEAKREF(outer)
		processing_seconds = 0

		var/turf/outside_turf = processing_outside_turf(outer)
		if(!outside_turf || !booking_wait_door_shut(inner) || !booking_wait_door_open(outer))
			booking_mover_ref = null
			processing_done()
			if(!police.cell_holding(mind))
				police.mark_locker_released(mind)
			return FALSE
		processing_seconds = 0
		if(!booking_walk_pair_in(suspect, officer, outer, processing_turfs))
			officer?.stop_pulling()
			if(officer)
				booking_walk_officer_out(officer, outer, outside_turf, processing_turfs)
			booking_mover_ref = null
			processing_done()
			if(!police.cell_holding(mind))
				police.mark_locker_released(mind)
			return FALSE
		processing_seconds = 0
		booking_uncuff_prisoner(suspect, officer, police, outside_turf)
		processing_seconds = 0
		if(officer)
			if(!QDELETED(officer) && officer.stat == CONSCIOUS)
				officer.say("In you go.")
			booking_walk_officer_out(officer, outer, outside_turf, processing_turfs)
		booking_mover_ref = null
		if(QDELETED(src) || QDELETED(suspect) || suspect.mind != mind || suspect.stat == DEAD || !in_processing(suspect))
			processing_done()
			if(!police.cell_holding(mind))
				police.mark_locker_released(mind)
			return FALSE
		processing_seconds = 0
		booking_wait_door_shut(outer)
		if(QDELETED(src) || QDELETED(suspect) || suspect.mind != mind || suspect.stat == DEAD || !in_processing(suspect))
			processing_done()
			if(!police.cell_holding(mind))
				police.mark_locker_released(mind)
			return FALSE

		admit_inmate_sentence(suspect, warrant, max(stars, police.get_stars(mind)))
		processing_state = OUTPOST_PROCESSING_IN
		processing_who_ref = WEAKREF(suspect)
		processing_entry_ref = null
		processing_seconds = 0

		if(booking_wait_door_open(inner) && !QDELETED(suspect) && suspect.stat == CONSCIOUS && suspect.body_position != LYING_DOWN && !HAS_TRAIT(suspect, TRAIT_INCAPACITATED))
			var/pause = booking_step_pause()
			var/turf/inner_turf = get_turf(inner)
			var/turf/yard_turf = processing_outside_turf(inner)
			for(var/step_try in 1 to 4)
				if(QDELETED(suspect) || get_turf(suspect) == inner_turf || !in_processing(suspect))
					break
				step_towards(suspect, inner_turf)
				sleep(pause)
			if(!QDELETED(suspect) && get_turf(suspect) == inner_turf && yard_turf)
				suspect.Move(yard_turf, get_dir(suspect, yard_turf))
				sleep(pause)
			if(!QDELETED(src) && !QDELETED(suspect) && !in_processing(suspect) && get_turf(suspect) != inner_turf)
				processing_done()
				booking_wait_door_shut(inner)
		greet_new_inmate(suspect)
		return TRUE

	// Wing without a mapped Processing room (unit-test fixture): walk in through a staff door if outside the cell block
	if(!in_cell_block(suspect))
		var/obj/machinery/door/airlock/staff_door
		var/turf/outside_turf
		for(var/turf/door_tile as anything in guard_yard_doors())
			var/obj/machinery/door/airlock/candidate = locate() in door_tile
			if(candidate && (candidate.locked || candidate.welded || !candidate.hasPower()))
				continue
			for(var/direction in GLOB.cardinals)
				var/turf/step_tile = get_step(door_tile, direction)
				if(step_tile && contains_turf(step_tile) && !in_cell_block(step_tile) && !isclosedturf(step_tile))
					staff_door = candidate
					outside_turf = step_tile
					break
			if(staff_door)
				break
		if(!staff_door || !booking_wait_door_open(staff_door))
			if(!police.cell_holding(mind))
				police.mark_locker_released(mind)
			return FALSE
		var/list/yard_tiles = list()
		for(var/turf/tile as anything in cell_block)
			if(!isclosedturf(tile) && tile != get_turf(staff_door))
				yard_tiles += tile
		if(!booking_walk_pair_in(suspect, officer, staff_door, yard_tiles))
			officer?.stop_pulling()
			if(officer && outside_turf)
				booking_walk_officer_out(officer, staff_door, outside_turf, yard_tiles)
			booking_wait_door_shut(staff_door)
			if(!police.cell_holding(mind))
				police.mark_locker_released(mind)
			return FALSE
		booking_uncuff_prisoner(suspect, officer, police, outside_turf)
		if(officer)
			if(!QDELETED(officer) && officer.stat == CONSCIOUS)
				officer.say("In you go.")
			if(outside_turf)
				booking_walk_officer_out(officer, staff_door, outside_turf, yard_tiles)
		booking_wait_door_shut(staff_door)
	else
		booking_uncuff_prisoner(suspect, officer, police)
		if(officer && !QDELETED(officer) && officer.stat == CONSCIOUS)
			officer.say("In you go.")

	if(QDELETED(src) || QDELETED(suspect) || suspect.mind != mind || suspect.stat == DEAD || !in_inmate_bounds(suspect))
		if(!police.cell_holding(mind))
			police.mark_locker_released(mind)
		return FALSE
	admit_inmate_sentence(suspect, warrant, max(stars, police.get_stars(mind)))
	greet_new_inmate(suspect)
	return TRUE

// =========================================================================
// CLOCK, RELEASE, ESCAPE AND DEATH
// =========================================================================

/// Advances every held inmate's sentence, bail retry and containment check by `seconds`
/datum/outpost_prison/proc/inmate_tick(seconds)
	if(seconds <= 0)
		return
	prune_dead_inmate_bodies()
	if(!length(sentences))
		return
	var/datum/outpost_police/police = outpost?.police
	for(var/datum/mind/who as anything in sentences.Copy())
		var/datum/prison_sentence/sentence = sentences[who]
		if(!sentence || sentence.released || sentence.escaped)
			continue
		var/mob/living/body = sentence.body_ref?.resolve()
		if(QDELETED(body) || body.mind != who)
			resolve_missing_inmate_body(who, sentence, body)
			continue
		if(body.stat == DEAD)
			on_inmate_death(body)
			continue
		sync_inmate_traits(body)
		sync_inmate_container_watch(sentence, body)

		var/datum/outpost_warrant/warrant = police?.get_warrant(who)
		if(police && !sentence.admin_booked && (!warrant || warrant.heat <= 0))
			release_inmate(who, TRUE)
			continue
		var/current_stars = sentence.stars_at_booking
		if(police && warrant && warrant.heat > 0)
			current_stars = clamp(police.get_stars(who), 1, length(OUTPOST_POLICE_JAIL))
			if(!sentence.admin_booked || current_stars > sentence.stars_at_booking)
				var/star_total = round(OUTPOST_POLICE_JAIL[current_stars] / (1 SECONDS))
				if(star_total > sentence.total_seconds)
					sentence.total_seconds = star_total

		var/inside = in_inmate_bounds(body)
		if(sentence.return_left > 0)
			if(inside)
				sentence.return_left = 0
				sentence.wants_return = FALSE
				sentence.walked_out = FALSE
				sentence.carried_by_ref = null
				sentence.carry_reported = FALSE
			else
				if(!sentence.carry_reported)
					var/mob/living/late_mover = sentence.carried_by_ref?.resolve() || inmate_mover_now(body)
					if(late_mover && late_mover != body && late_mover.mind && !is_staff(late_mover))
						sentence.carry_reported = TRUE
						police?.report_crime(late_mover, OUTPOST_CRIME_JAILBREAK)
				var/obj/machinery/door/airlock/outer = has_processing() ? processing_door(FALSE) : null
				var/at_return_door = outer && in_front_room(body) && get_dist(body, outer) <= 1 && inmate_can_walk_back(body, who)
				if(!at_return_door)
					sentence.wants_return = FALSE
				else if(sentence.wants_return && processing_state == OUTPOST_PROCESSING_IDLE)
					try_start_processing_inmate_return(body)
				var/door_not_open = outer && (outer.density || outer.operating)
				var/waiting_return_door = at_return_door && door_not_open && ((processing_state == OUTPOST_PROCESSING_RETURN && processing_who() == body) || (sentence.wants_return && processing_state != OUTPOST_PROCESSING_IDLE))
				if(!waiting_return_door && inmate_can_walk_back(body, who))
					sentence.return_left -= seconds
					if(sentence.return_left <= 0)
						inmate_escaped(who, body)
				continue
		else if(!inside)
			var/mob/living/mover = sentence.carried_by_ref?.resolve() || inmate_mover_now(body)
			if(sentence.walked_out && (!mover || mover == body))
				inmate_escaped(who, body)
				continue
			sentence.return_left = round(OUTPOST_POLICE_CELL_RETURN / (1 SECONDS))
			if(mover && mover != body && !is_staff(mover))
				sentence.carry_reported = TRUE
				police?.report_crime(mover, OUTPOST_CRIME_JAILBREAK)
			continue

		sentence.seconds_served += seconds
		tally_lockup_served(src, body, seconds)
		if(sentence.remaining_seconds() <= 0)
			release_inmate(who, TRUE)
			continue

		if(police && warrant && warrant.heat > 0 && !sentence.admin_booked && current_stars <= 2)
			sentence.bail_elapsed += seconds
			var/retry_seconds = max(1, round(OUTPOST_POLICE_BAIL_RETRY / (1 SECONDS)))
			if(sentence.bail_elapsed >= retry_seconds)
				sentence.bail_elapsed = 0
				if(police.charge_fine(warrant))
					release_inmate(who, TRUE)
					continue
	update_lockup_boards()

/// Ends `who`'s lockup sentence as served: closes the warrant, buzzes the board, announces release and queues Processing
/datum/outpost_prison/proc/release_inmate(datum/mind/who, served = TRUE)
	var/datum/prison_sentence/sentence = sentences[who]
	if(!sentence || sentence.released || sentence.escaped)
		return FALSE
	var/mob/living/body = sentence.body_ref?.resolve()
	sentence.released = TRUE
	sentence.return_left = 0
	sentence.wants_return = FALSE
	unhook_inmate(sentence)
	if(body)
		outpost_police_drop_used_cuffs(body)
	var/datum/outpost_police/police = outpost?.police
	if(police)
		police.close_warrant(who, served)
		police.mark_locker_released(who)
		police.update_hud(who)
		if(body)
			SEND_SIGNAL(police, COMSIG_OUTPOST_POLICE_RELEASED, body)
	for(var/obj/machinery/status_display/outpost_berth/lockup/board as anything in boards)
		if(!QDELETED(board))
			playsound(board, 'sound/machines/ping.ogg', 40, FALSE)
	if(body)
		var/surname = sanitize_lockup_surname(body.real_name)
		var/mob/living/carbon/human/npc/outpost_prison_guard/announcer = pick_guard_speaker(body)
		if(announcer)
			announcer.last_line = "[surname]. You're out."
			announcer.say(announcer.last_line)
		if(has_processing() && contains_turf(get_turf(body)) && !in_front_room(body))
			processing_release_refs |= WEAKREF(body)
		add_log("[body.real_name] served their term and was released.")
	update_lockup_boards()
	return TRUE

/// Picks an on-duty guard able to speak, preferring one within view of `near`
/datum/outpost_prison/proc/pick_guard_speaker(atom/near)
	var/mob/living/carbon/human/npc/outpost_prison_guard/fallback
	for(var/mob/living/carbon/human/npc/outpost_prison_guard/guard in guard_mobs)
		if(QDELETED(guard) || !guard.on_duty())
			continue
		fallback ||= guard
		if(near && (near in view(7, guard)))
			return guard
	return fallback

/// Marks `who` escaped: drops custody so their old warrant is live again, reports OUTPOST_CRIME_JAILBREAK and keeps the escaped record
/datum/outpost_prison/proc/inmate_escaped(datum/mind/who, mob/living/body = null)
	var/datum/prison_sentence/sentence = sentences[who]
	if(!sentence || sentence.released || sentence.escaped)
		return FALSE
	body ||= sentence.body_ref?.resolve()
	sentence.escaped = TRUE
	sentence.return_left = 0
	sentence.wants_return = FALSE
	unhook_inmate(sentence)
	var/datum/outpost_police/police = outpost?.police
	if(police)
		if(body)
			police.report_crime(body, OUTPOST_CRIME_JAILBREAK)
		police.update_hud(who)
		police.wake()
	if(body)
		add_log("[body.real_name] broke out of the lockup.")
	record_lockup_escape(src, body, "inmate")
	update_lockup_boards()
	return TRUE

/// Ends `body`'s sentence on death, closes their warrant as served, notifies their crew and queues guard carry-out to the front room
/datum/outpost_prison/proc/on_inmate_death(mob/living/body)
	if(QDELETED(body))
		return FALSE
	var/datum/mind/who = body.mind
	var/datum/prison_sentence/sentence = who ? sentences[who] : null
	if(!sentence)
		for(var/datum/mind/candidate as anything in sentences)
			var/datum/prison_sentence/check = sentences[candidate]
			if(check?.body_ref?.resolve() == body)
				who = candidate
				sentence = check
				break
	if(!sentence || sentence.released || sentence.escaped)
		return FALSE
	var/mob/living/current_body = isliving(who?.current) ? who.current : null
	if((body.mind && body.mind != who) || (current_body && !QDELETED(current_body) && current_body != body && current_body.stat != DEAD))
		resolve_missing_inmate_body(who, sentence, body)
		return FALSE
	sentence.released = TRUE
	sentence.return_left = 0
	sentence.wants_return = FALSE
	sentence.died_in_custody_at = world.time
	unhook_inmate(sentence)
	outpost_police_drop_used_cuffs(body)
	report_inmate_murdered(sentence, body)
	var/datum/outpost_police/police = outpost?.police
	if(police && who)
		var/datum/outpost_warrant/warrant = police.get_warrant(who)
		var/datum/voidcrew_crew_record/crew = warrant ? police.current_warrant_crew(warrant) : who.get_reputation_crew()
		police.close_warrant(who, TRUE)
		police.mark_locker_released(who)
		police.update_hud(who)
		SEND_SIGNAL(police, COMSIG_OUTPOST_POLICE_RELEASED, body)
		for(var/obj/structure/overmap/ship/ship as anything in police.crew_ship_list(crew))
			ship.ship_notify("[outpost_log_name()] Security: [body.real_name] died in custody. Collect at the lockup.", "LOCKUP NOTICE", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg', 25)
	if(contains_turf(get_turf(body)) && !in_front_room(body))
		dead_inmate_bodies |= WEAKREF(body)
	add_log("[body.real_name] died in custody.")
	update_lockup_boards()
	return TRUE

/// Prunes dead inmate bodies that have been carried into the front room, removed from the wing or revived (queuing revived bodies for Processing exit)
/datum/outpost_prison/proc/prune_dead_inmate_bodies()
	for(var/datum/weakref/ref as anything in dead_inmate_bodies.Copy())
		var/mob/living/body = ref?.resolve()
		if(!QDELETED(body) && body.stat != DEAD)
			dead_inmate_bodies -= ref
			if(!holds(body.mind) && has_processing() && contains_turf(get_turf(body)) && !in_front_room(body))
				processing_release_refs |= WEAKREF(body)
			continue
		if(QDELETED(body) || !contains_turf(get_turf(body)) || in_front_room(body))
			dead_inmate_bodies -= ref

/// Next dead inmate body inside the wing waiting to be carried to the front room, or null
/datum/outpost_prison/proc/next_dead_inmate_body()
	prune_dead_inmate_bodies()
	for(var/datum/weakref/ref as anything in dead_inmate_bodies)
		var/mob/living/body = ref?.resolve()
		if(body)
			return body
	return null

/// Open front-room floor tile nearest the front desk (or Processing's outer door) where a guard leaves a dead inmate's body
/datum/outpost_prison/proc/corpse_drop_spot()
	var/atom/anchor = claim_turf || desk_turf || processing_door(FALSE)
	var/turf/outer_turf = get_turf(processing_door(FALSE))
	var/turf/best
	var/best_dist = INFINITY
	var/turf/fallback
	for(var/turf/tile as anything in front_room_ground())
		if(tile.is_blocked_turf(exclude_mobs = TRUE))
			continue
		fallback ||= tile
		// Prefer a tile off Processing's immediate threshold so the pulled body clears the outer doorway too
		if(outer_turf && get_dist(tile, outer_turf) <= 1)
			continue
		var/dist = anchor ? get_dist(tile, anchor) : 0
		if(dist < best_dist)
			best = tile
			best_dist = dist
	return best || fallback

/// Whether an on-duty guard with free hands and usable Processing doors can carry a dead inmate out
/datum/outpost_prison/proc/has_able_corpse_guard()
	if(has_processing())
		var/obj/machinery/door/airlock/inner = processing_door(TRUE)
		var/obj/machinery/door/airlock/outer = processing_door(FALSE)
		if(!inner || !outer || inner.locked || inner.welded || !inner.hasPower() || outer.locked || outer.welded || !outer.hasPower())
			return FALSE
	for(var/mob/living/carbon/human/npc/outpost_prison_guard/guard in guard_mobs)
		if(!QDELETED(guard) && guard.on_duty() && guard.usable_hands > 0 && !HAS_TRAIT(guard, TRAIT_HANDS_BLOCKED))
			return TRUE
	return FALSE

/// Whether Processing's doors should stand open so someone can carry a dead inmate out when no guard can
/datum/outpost_prison/proc/corpse_doors_open()
	return !!next_dead_inmate_body() && !has_able_corpse_guard()

/// Releases all inmate holds on wing deletion without touching warrants (design 14 #28)
/datum/outpost_prison/proc/inmates_destroy()
	work_destroy()
	booking_mover_ref = null
	dead_inmate_bodies.Cut()
	corpse_visitor_refs.Cut()
	processing_release_refs.Cut()
	for(var/obj/machinery/status_display/outpost_berth/lockup/board as anything in boards)
		if(board?.prison == src)
			board.prison = null
	boards.Cut()
	for(var/datum/mind/who as anything in sentences.Copy())
		var/datum/prison_sentence/sentence = sentences[who]
		if(!sentence)
			continue
		sentence.released = TRUE
		unhook_inmate(sentence)
		qdel(sentence)
	sentences.Cut()
