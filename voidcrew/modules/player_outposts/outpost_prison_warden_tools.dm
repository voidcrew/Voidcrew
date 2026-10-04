/**
 * # Warden tools: the talk menu
 *
 * Owner: XC (extras-plan.md 4.8). A member of the wing (is_member()), not in combat mode, left
 * clicks an awake prisoner who is not down (cuffed is fine) with an empty hand: a radial menu opens
 * with its own choices, then any other package's (talk_menu_extra_choices(): XF's search, XG's
 * questions), whose picks go to talk_menu_extra_act(). Visitors get no menu, and a right click is
 * tg's own.
 *
 * - "Calm down", offered while they will listen (will_listen()): the talk-down in
 *   outpost_prison_trouble.dm, which ends a threat or an argument and lifts mood.
 * - "How are you doing?", "What are you in for?" and "Back to your cell" are a short talk face to face
 *   (PRISON_TALK_MENU_TIME), which holds their routine and any threat as a talk-down does, and
 *   nobody in trouble or below PRISONER_TALK_MIN_MOOD will have it.
 * - "How are you doing?": their biggest complaint, or that they're fine. No mood change.
 * - "What are you in for?": what they're in for, and a small lift the first time in a stay.
 * - "Back to your cell": a request, not an order they must obey. At or above their line (by
 *   personality, lower for a fair member, higher for a brute) they go and sit in their cell's chair
 *   (or on its bed) for a minute or so; below it they refuse. Asking a third time inside PRISON_TALK_ORDER_SPAM_WINDOW
 *   costs mood and is refused. Forcing someone back is still the baton, the drag and the bolts.
 *   Not offered to someone in cuffs, who can't walk anywhere.
 * - "Uncuff", offered in its place while they are cuffed: uncuff_by() in outpost_prison_capture.dm.
 * - "Get up", offered while they lie, sit or crouch: an order, and they always get up, grumbling
 *   below their line. Off a bed they step aside and stay put for PRISON_TALK_GET_UP_HOLD, so the
 *   mattress can be searched. Nothing else changes.
 * The same left click on a prisoner asleep in bed shakes them awake instead (shake_awake()): they
 * get up as if told to, and lose PRISON_TALK_WAKE_MOOD for it. On one who is down or out cold there
 * is nothing to talk about: the click takes their cuffs off if they wear any.
 *
 * While the menu is open, and through the talk picked from it, they stop and face the member
 * (held_by_talk_menu(), which routine_allowed() checks), and a threat they were making waits
 * (threats_tick() in outpost_prison_riot.dm), so a talk-down picked from it still comes in time.
 * Anyone may pull a calm prisoner
 * (calm_for_pull() in outpost_prison_prisoner.dm): they drop what they were doing and go along
 * with it, and once let go they stay where they were left for PRISON_PULL_RELEASE_HOLD.
 * Numbers in voidcrew/_DEFINES/outpost_prison_social.dm.
 */

// What an activity's tick() wants when it is over, as in outpost_prison_routine.dm (which undefines its own)
#define ACTIVITY_DONE 1

/mob/living/basic/outpost_prisoner
	/// Between answers to "How are you doing?" and "What are you in for?"
	COOLDOWN_DECLARE(ask_how_cooldown)
	COOLDOWN_DECLARE(ask_crime_cooldown)
	/// Between orders back to the cell
	COOLDOWN_DECLARE(order_cooldown)
	/// Whether they've been asked what they're in for this stay; the lift from it comes once
	var/asked_crime = FALSE
	/// world.time of each recent order back to the cell, for PRISON_TALK_ORDER_SPAM_COUNT
	var/list/order_times
	/// Weakrefs to members with the talk menu open on them, or in the talk they picked from it
	var/list/talk_menu_holders

/// Registers the talk menu and the pull hold on the prisoner; called from setup_extras()
/mob/living/basic/outpost_prisoner/proc/setup_warden_tools()
	RegisterSignal(src, COMSIG_ATOM_ATTACK_HAND, PROC_REF(on_talk_menu_click))
	// Sent to the pulled mob by a living puller; living pullers never send COMSIG_ATOM_START_PULL.
	RegisterSignal(src, COMSIG_LIVING_GET_PULLED, PROC_REF(on_pulled))
	RegisterSignal(src, COMSIG_ATOM_NO_LONGER_PULLED, PROC_REF(on_pull_released))

/**
 * A left click with an empty hand, out of combat mode: members get the menu, or shake a sleeper
 * awake, or take the cuffs off someone down; everyone else pats them as usual. A right click is
 * tg's own.
 */
/mob/living/basic/outpost_prisoner/proc/on_talk_menu_click(datum/source, mob/living/user, list/modifiers)
	SIGNAL_HANDLER
	if(!istype(user) || user.combat_mode || LAZYACCESS(modifiers, RIGHT_CLICK) || is_outpost_prisoner(user) || !prison?.is_member(user))
		return NONE
	if(stat == DEAD || phase != PRISONER_PRESENT)
		return NONE
	if(activity?.sleeping)
		INVOKE_ASYNC(src, PROC_REF(shake_awake), user)
		return COMPONENT_CANCEL_ATTACK_CHAIN
	if(talk_menu_allowed(user))
		// The radial menu sleeps until a pick.
		INVOKE_ASYNC(src, PROC_REF(talk_menu_open), user)
		return COMPONENT_CANCEL_ATTACK_CHAIN
	// Down or out cold: nothing to talk about, but the cuffs can still come off.
	if(cuffs)
		INVOKE_ASYNC(src, PROC_REF(uncuff_by), user)
		return COMPONENT_CANCEL_ATTACK_CHAIN
	balloon_alert(user, "can't talk now")
	return COMPONENT_CANCEL_ATTACK_CHAIN

/// Whether `user` may use the talk menu on them now: a member out of combat mode, and them awake, present and not down (cuffed is fine)
/mob/living/basic/outpost_prisoner/proc/talk_menu_allowed(mob/living/user)
	if(!istype(user) || QDELETED(user) || user.stat != CONSCIOUS || user.combat_mode || is_outpost_prisoner(user))
		return FALSE
	if(QDELETED(src) || stat != CONSCIOUS || phase != PRISONER_PRESENT || is_down() || activity?.sleeping)
		return FALSE
	return !!prison?.is_member(user)

/// Shows the radial and runs the pick. They stand still facing `user` until the menu closes and the picked talk is over. Sleeps.
/mob/living/basic/outpost_prisoner/proc/talk_menu_open(mob/living/user)
	// Nothing to show a menu on.
	if(!user?.client)
		return
	var/list/choices = talk_menu_choices(user)
	var/datum/weakref/holder_ref = hold_for_talk_menu(user)
	var/choice = show_radial_menu(user, src, choices, custom_check = CALLBACK(src, PROC_REF(talk_menu_allowed), user), require_near = TRUE, tooltips = TRUE)
	if(choice && !QDELETED(src) && !QDELETED(user))
		talk_menu_act(user, choice)
	release_talk_menu(holder_ref)

/// Stops them where they are, facing `user`, while `user` has the menu open. Returns the hold, for release_talk_menu().
/mob/living/basic/outpost_prisoner/proc/hold_for_talk_menu(mob/living/user)
	var/datum/weakref/holder_ref = WEAKREF(user)
	LAZYADD(talk_menu_holders, holder_ref)
	ai_controller?.CancelActions()
	face_atom(user)
	return holder_ref

/// The menu `holder_ref` opened is closed and its talk over
/mob/living/basic/outpost_prisoner/proc/release_talk_menu(datum/weakref/holder_ref)
	LAZYREMOVE(talk_menu_holders, holder_ref)

/// Whether someone beside them has the talk menu open on them, or is in the talk they picked from it
/mob/living/basic/outpost_prisoner/proc/held_by_talk_menu()
	// A holder who walked off or went down no longer holds them, even if their menu never closed cleanly.
	for(var/datum/weakref/holder_ref in talk_menu_holders)
		var/mob/living/holder = holder_ref.resolve()
		if(holder && holder.stat == CONSCIOUS && get_dist(holder, src) <= 1)
			return TRUE
	return FALSE

/**
 * The menu's choices, name -> image: its own first (a talk-down only for someone who will listen,
 * the cuffs off in place of a walk back to the cell, no getting up for someone already up), then
 * other packages'. No two choices share an icon; all are drawn like tg's radial_talk.
 */
/mob/living/basic/outpost_prisoner/proc/talk_menu_choices(mob/living/user)
	var/static/list/own_choices
	if(!own_choices)
		own_choices = list(
			(PRISON_TALK_CALM) = image(icon = 'voidcrew/icons/hud/radial.dmi', icon_state = "radial_calm"),
			(PRISON_TALK_HOW) = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_talk"),
			(PRISON_TALK_CRIME) = image(icon = 'voidcrew/icons/hud/radial.dmi', icon_state = "radial_crime"),
			(PRISON_TALK_CELL) = image(icon = 'voidcrew/icons/hud/radial.dmi', icon_state = "radial_home"),
			(PRISON_TALK_UNCUFF) = image(icon = 'voidcrew/icons/hud/radial.dmi', icon_state = "radial_uncuff"),
			(PRISON_TALK_GET_UP) = image(icon = 'voidcrew/icons/hud/radial.dmi', icon_state = "radial_get_up"),
		)
	var/list/choices = own_choices.Copy()
	if(!will_listen())
		choices -= PRISON_TALK_CALM
	if(cuffs)
		choices -= PRISON_TALK_CELL
	else
		choices -= PRISON_TALK_UNCUFF
	if(!talk_menu_can_get_up())
		choices -= PRISON_TALK_GET_UP
	var/list/extra = talk_menu_other_choices(user)
	for(var/choice in extra)
		if(!(choice in choices))
			choices[choice] = extra[choice]
	return choices

/// Other packages' choices for this prisoner and `user` (outpost_prison_extras.dm)
/mob/living/basic/outpost_prisoner/proc/talk_menu_other_choices(mob/living/user)
	var/list/extra = prison?.talk_menu_extra_choices(src, user)
	return islist(extra) ? extra : list()

/// Runs another package's choice; TRUE if one took it. May sleep.
/mob/living/basic/outpost_prisoner/proc/talk_menu_other_act(mob/living/user, choice)
	return prison ? prison.talk_menu_extra_act(src, user, choice) : FALSE

/// Runs a pick from the menu, checked again now that the menu is closed. May sleep.
/mob/living/basic/outpost_prisoner/proc/talk_menu_act(mob/living/user, choice)
	if(!talk_menu_allowed(user) || !user.Adjacent(src))
		return FALSE
	switch(choice)
		if(PRISON_TALK_CALM)
			return talk_down(user)
		if(PRISON_TALK_UNCUFF)
			return uncuff_by(user)
		if(PRISON_TALK_HOW)
			return talk_menu_ask_how(user)
		if(PRISON_TALK_CRIME)
			return talk_menu_ask_crime(user)
		if(PRISON_TALK_CELL)
			return talk_menu_order(user)
		if(PRISON_TALK_GET_UP)
			return talk_menu_get_up(user)
	return talk_menu_other_act(user, choice)

/**
 * A moment face to face with `user`, as a talk-down has, holding their routine and any threat.
 * Anyone in trouble (fighting, rioting, loose, wrecking) or below PRISONER_TALK_MIN_MOOD won't
 * have it. Returns TRUE once the talk is done and they're still listening. Sleeps.
 */
/mob/living/basic/outpost_prisoner/proc/talk_menu_chat(mob/living/user)
	if(QDELETED(user))
		return FALSE
	if(talking)
		balloon_alert(user, "already talking")
		return FALSE
	if(!will_listen() || trouble)
		face_atom(user)
		say_context("talk_refuse")
		balloon_alert(user, "not listening")
		return FALSE
	talking = TRUE
	ai_controller?.CancelActions()
	face_atom(user)
	user.face_atom(src)
	var/finished = do_after(user, PRISON_TALK_MENU_TIME, target = src)
	talking = FALSE
	if(!finished || QDELETED(src) || stat != CONSCIOUS || phase != PRISONER_PRESENT)
		return FALSE
	if(!will_listen() || trouble)
		say_context("talk_refuse")
		return FALSE
	face_atom(user)
	return TRUE

// ===== "HOW ARE YOU DOING?" =====

/mob/living/basic/outpost_prisoner/proc/talk_menu_ask_how(mob/living/user)
	if(!COOLDOWN_FINISHED(src, ask_how_cooldown))
		balloon_alert(user, "just asked")
		return FALSE
	if(!talk_menu_chat(user))
		return FALSE
	COOLDOWN_START(src, ask_how_cooldown, PRISON_TALK_ASK_GAP)
	var/list/answer = talk_menu_complaint()
	say_context(answer[1], answer[2])
	return TRUE

/**
 * Their biggest complaint, as list(context, other): starving, hungry, filthy, dirty, hurt, locked
 * in, a dark cell, a dark wing, a dirty floor, no power, a rival (named when they can be), else fine.
 */
/mob/living/basic/outpost_prisoner/proc/talk_menu_complaint()
	var/list/needs = bubble_needs()
	if(hunger < PRISONER_HUNGER_STARVING)
		return list("ask_how_starving", null)
	if("hungry" in needs)
		return list("ask_how_hungry", null)
	if(uniform_grime >= PRISONER_GRIME_FILTHY)
		return list("ask_how_filthy", null)
	if("dirty" in needs)
		return list("ask_how_dirty", null)
	if("hurt" in needs)
		return list("ask_how_hurt", null)
	if(locked_in_seconds > OUTPOST_PRISON_LOCKED_IN_COMPLAINT)
		return list("ask_how_locked", null)
	if(prison)
		var/list/conditions = prison.conditions_payload()
		var/list/dark_cells = conditions["dark_cells"]
		if(cell && (cell.number in dark_cells))
			return list("ask_how_dark_cell", null)
		if(conditions["lit"] < PRISON_WING_MOOD_LINE)
			return list("ask_how_dark", null)
		if(conditions["clean"] < PRISON_WING_MOOD_LINE)
			return list("ask_how_dirty_floor", null)
		if(conditions["powered"] < 100)
			return list("ask_how_no_power", null)
		// Friends and rivals are outpost_prison_life.dm's.
		var/rival_name = prison.worst_rival_name(src)
		if(rival_name)
			return list("ask_how_rival", talk_menu_prisoner_named(rival_name))
	return list("ask_how_fine", null)

/// Another prisoner of theirs who goes by `first`, for naming them in a line, or null
/mob/living/basic/outpost_prisoner/proc/talk_menu_prisoner_named(first)
	for(var/mob/living/basic/outpost_prisoner/other in prison?.prisoners)
		if(other != src && other.speech_name() == first)
			return other
	return null

// ===== "CRIME" =====

/mob/living/basic/outpost_prisoner/proc/talk_menu_ask_crime(mob/living/user)
	if(!COOLDOWN_FINISHED(src, ask_crime_cooldown))
		balloon_alert(user, "just asked")
		return FALSE
	if(!talk_menu_chat(user))
		return FALSE
	COOLDOWN_START(src, ask_crime_cooldown, PRISON_TALK_ASK_GAP)
	say_context("ask_crime")
	if(!asked_crime)
		asked_crime = TRUE
		adjust_mood(PRISON_TALK_CRIME_MOOD)
	return TRUE

// ===== "HOME" =====

/**
 * Asks them back to their cell. At or above their line they go (sent_to_cell); below it they
 * refuse. The PRISON_TALK_ORDER_SPAM_COUNT-th ask inside PRISON_TALK_ORDER_SPAM_WINDOW costs
 * PRISON_TALK_ORDER_SPAM_MOOD and is refused. Returns TRUE if they went.
 */
/mob/living/basic/outpost_prisoner/proc/talk_menu_order(mob/living/user)
	// Cuffed while the menu was open: they can't walk anywhere.
	if(cuffs)
		balloon_alert(user, "cuffed")
		return FALSE
	if(!COOLDOWN_FINISHED(src, order_cooldown))
		balloon_alert(user, "just asked them")
		return FALSE
	if(!talk_menu_chat(user))
		return FALSE
	COOLDOWN_START(src, order_cooldown, PRISON_TALK_ORDER_GAP)
	var/list/recent = list()
	for(var/when in order_times)
		if(world.time - when < PRISON_TALK_ORDER_SPAM_WINDOW)
			recent += when
	recent += world.time
	order_times = recent
	if(length(order_times) >= PRISON_TALK_ORDER_SPAM_COUNT)
		adjust_mood(-PRISON_TALK_ORDER_SPAM_MOOD)
		say_context("order_again")
		return FALSE
	if(mood < talk_menu_order_line(user))
		say_context("order_refuse")
		return FALSE
	// Done with what they were doing first: its claims go with it, not the new activity's bed.
	end_activity()
	var/datum/prisoner_activity/sent_to_cell/going = new(src)
	if(!going.setup())
		qdel(going)
		balloon_alert(user, "can't get to the cell")
		return FALSE
	say_context("order_comply")
	start_activity(going)
	prison?.add_log("[user.name] sent [real_name] back to cell [cell?.number || "-"].")
	return TRUE

/// The mood at or above which they go back when `user` asks: by personality, then by how the yard sees `user`
/mob/living/basic/outpost_prisoner/proc/talk_menu_order_line(mob/living/user)
	var/line = PRISON_TALK_ORDER_LINE
	switch(personality)
		if("grumpy")
			line = PRISON_TALK_ORDER_LINE_GRUMPY
		if("chatty")
			line = PRISON_TALK_ORDER_LINE_CHATTY
		if("quiet")
			line = PRISON_TALK_ORDER_LINE_QUIET
		if("cheerful")
			line = PRISON_TALK_ORDER_LINE_CHEERFUL
		if("nervous")
			line = PRISON_TALK_ORDER_LINE_NERVOUS
	switch(prison?.staff_label(user))
		if("fair")
			line += PRISON_TALK_ORDER_FAIR_SHIFT
		if("brute")
			line += PRISON_TALK_ORDER_BRUTE_SHIFT
	return line

/// Asked back to their cell: to its chair (or with the chair taken, gone or out of reach, their bed) for a minute or so
/datum/prisoner_activity/sent_to_cell
	name = "sent back to their cell"
	context = "sent_to_cell"
	weight = 0
	interruptible = FALSE
	min_duration = PRISON_SENT_TO_CELL_MIN
	max_duration = PRISON_SENT_TO_CELL_MAX
	var/datum/weakref/seat_ref

/datum/prisoner_activity/sent_to_cell/setup()
	var/datum/outpost_prison_cell/home = prisoner.cell
	if(!home)
		return FALSE
	if(!prisoner.walkable)
		prisoner.prison?.refresh_prisoner_reach(prisoner)
	if(!prisoner.walkable)
		return FALSE
	var/obj/structure/seat = prisoner.home_seat()
	if(seat && claim(seat))
		seat_ref = WEAKREF(seat)
		spot = get_turf(seat)
		return TRUE
	for(var/turf/tile as anything in home.turfs)
		if(prisoner.walkable[tile] && (tile == prisoner.loc || !prisoner.tile_taken(tile)))
			spot = tile
			return TRUE
	return FALSE

/datum/prisoner_activity/sent_to_cell/begin()
	. = ..()
	var/obj/structure/seat = seat_ref?.resolve()
	if(seat && prisoner.loc == seat.loc)
		var/obj/machinery/door/door = prisoner.cell?.door()
		prisoner.sit_in_cell(door ? get_cardinal_dir(prisoner, door) : SOUTH)

/datum/prisoner_activity/sent_to_cell/tick(seconds)
	if(!prisoner.cell?.contains(prisoner))
		return ACTIVITY_DONE
	return ..()

// ===== "GET UP" =====

/// Whether they lie or sit on something, or crouch, so there is something to get up from
/mob/living/basic/outpost_prisoner/proc/talk_menu_can_get_up()
	return !!buckled || is_crouching()

/**
 * Tells them to get up. An order, not a request: they get up whatever their mood, cuffed or not,
 * and below the line at which they'd go back to their cell (talk_menu_order_line()) they grumble.
 * Whatever they were doing stops, a shiv or a brew on the bed included. Off a bed they step onto a
 * free tile beside it, inside its cell if they can, and if free they stay there for
 * PRISON_TALK_GET_UP_HOLD so the mattress can be searched. Costs no mood and no reputation.
 * Only trouble, or someone else already talking to them, stops it. Returns TRUE if they got up.
 * `woken`: they were asleep and `user` shook them awake (shake_awake()), which costs PRISON_TALK_WAKE_MOOD.
 */
/mob/living/basic/outpost_prisoner/proc/talk_menu_get_up(mob/living/user, woken = FALSE)
	if(QDELETED(user))
		return FALSE
	if(!talk_menu_can_get_up())
		balloon_alert(user, "already up")
		return FALSE
	if(talking || cuff_work)
		balloon_alert(user, "busy")
		return FALSE
	// Trouble comes before any order, unless cuffs have put a stop to it.
	if(!cuffs && in_trouble())
		face_atom(user)
		say_context("talk_refuse")
		balloon_alert(user, "not listening")
		return FALSE
	var/sour = mood < talk_menu_order_line(user)
	var/obj/structure/bed/bed = istype(buckled, /obj/structure/bed) ? buckled : null
	if(woken)
		user.visible_message(span_notice("[user] shakes [src] awake."), span_notice("You shake [src] awake."))
		playsound(src, 'sound/items/weapons/thudswoosh.ogg', 40, TRUE, -1)
		adjust_mood(-PRISON_TALK_WAKE_MOOD)
	else
		user.visible_message(span_notice("[user] tells [src] to get up."), span_notice("You tell [src] to get up."))
	// A cuffed prisoner is doing nothing; anyone else stops, and lets go of what they claimed.
	end_activity()
	stand_up()
	if(bed)
		talk_menu_step_off(bed)
	face_atom(user)
	var/line = sour ? "get_up_grumble" : "get_up"
	if(woken)
		line = "woken"
	say_context(line)
	// Cuffs keep them where they are anyway.
	if(!cuffs)
		var/datum/prisoner_activity/told_to_stand/standing = new(src)
		if(bed)
			standing.claim(bed)
		start_activity(standing)
		// Already where they stand: the clock starts now, AI or not.
		standing.arrive()
	return TRUE

/// Shakes them awake in their bed, and they get up as if told to (talk_menu_get_up()). Returns TRUE if they got up.
/mob/living/basic/outpost_prisoner/proc/shake_awake(mob/living/user)
	if(!activity?.sleeping)
		return FALSE
	return talk_menu_get_up(user, woken = TRUE)

/**
 * Steps off `bed` onto a free tile beside it: one inside the bed's cell if there is one, else any.
 * Returns the tile, or null if they stayed where they were.
 */
/mob/living/basic/outpost_prisoner/proc/talk_menu_step_off(obj/structure/bed/bed)
	var/turf/bed_turf = get_turf(bed)
	if(!bed_turf || loc != bed_turf)
		return null
	var/datum/outpost_prison_cell/bed_cell = prison?.cell_at(bed_turf)
	var/list/inside = list()
	var/list/outside = list()
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(bed_turf, direction)
		if(!beside || beside.is_blocked_turf(source_atom = src) || tile_taken(beside))
			continue
		if(bed_cell?.contains(beside))
			inside += beside
		else
			outside += beside
	for(var/turf/tile as anything in inside + outside)
		Move(tile, get_dir(bed_turf, tile))
		if(loc == tile)
			return tile
	return null

/// Told to get up: they stay where they stood up for PRISON_TALK_GET_UP_HOLD, keeping their bed free, then carry on
/datum/prisoner_activity/told_to_stand
	name = "told to get up"
	weight = 0
	interruptible = FALSE
	min_duration = PRISON_TALK_GET_UP_HOLD
	max_duration = PRISON_TALK_GET_UP_HOLD

// ===== A PULL =====

/// Someone took hold of them: they weigh what pull_weight() says, and a calm prisoner drops what they were doing to go along
/mob/living/basic/outpost_prisoner/proc/on_pulled(datum/source, mob/living/puller)
	SIGNAL_HANDLER
	move_resist = pull_weight()
	if(can_be_dragged() || !calm_for_pull())
		return
	INVOKE_ASYNC(src, PROC_REF(go_along_with_pull))

/// Stops whatever they were doing, and any walk, so they follow the pull instead of walking against it
/mob/living/basic/outpost_prisoner/proc/go_along_with_pull()
	if(QDELETED(src) || !pulledby)
		return
	end_activity()
	ai_controller?.CancelActions()

/// Let go: back to their usual weight, and a calm prisoner stays where they were left for a moment
/mob/living/basic/outpost_prisoner/proc/on_pull_released(datum/source, atom/movable/puller)
	SIGNAL_HANDLER
	move_resist = pull_weight()
	if(routine_allowed())
		INVOKE_ASYNC(src, PROC_REF(stay_put_after_pull))

/// Holds them where they stand for PRISON_PULL_RELEASE_HOLD before the routine picks up again
/mob/living/basic/outpost_prisoner/proc/stay_put_after_pull()
	if(QDELETED(src) || !routine_allowed())
		return
	var/datum/prisoner_activity/let_go/still = new(src)
	start_activity(still)
	// Already where they stand: the clock starts now, AI or not.
	still.arrive()

/// Pulled along while calm, and in trouble since: they shake the pull off. Called every tick of the prison.
/mob/living/basic/outpost_prisoner/proc/shake_off_pull()
	if(pulledby && !pull_allowed())
		update_drag_resistance()

/// Let go after a pull: they stay where they were left for PRISON_PULL_RELEASE_HOLD, then carry on
/datum/prisoner_activity/let_go
	name = "just let go"
	weight = 0
	interruptible = FALSE
	min_duration = PRISON_PULL_RELEASE_HOLD
	max_duration = PRISON_PULL_RELEASE_HOLD

#undef ACTIVITY_DONE
