/**
 * # The Aperture — voidwalker vestige
 *
 * A hull section that is mostly windows, all of them facing nothing. The
 * voidwalker's body is the antag (space-native, unportable), so the patron is
 * what watches through the glass, the trials are introductions — to the dark,
 * to the glass, to the other side — and the boons are human-tuned pieces of
 * what the voidwalker does through a pane: the dash, the void's tolerance,
 * the pull, the passing-through. Each port's doc comment records what
 * coupling it was checked for.
 */

// Tuning constants for the Watcher's trials (file-local, #undef at bottom)
/// Distinct rooms the caller's card must be pressed against from the void side (Trial of the Other Side)
#define VESTIGE_CALLER_ROOMS_NEEDED 5
/// How long one press of the card against a pane takes
#define VESTIGE_CALLER_PRESS_TIME (4 SECONDS)
/// Space turfs the keepsake must cross in one unbroken flight (Trial of the Little Moon)
#define VESTIGE_MOON_DRIFT_NEEDED 20

// ===== PATRON =====

/mob/living/basic/vestige_patron/watcher
	name = "the Watcher Behind Glass"
	desc = "A tall silhouette standing at the window — or in it, or just past it; the pane never quite agrees. It watches you the way you watch an aquarium."
	gender = NEUTER
	outfit_path = /datum/outfit/job/assistant
	appearance_tint = "#141428"
	trial_types = list(
		/datum/vestige_trial/long_dark,
		/datum/vestige_trial/other_side,
		/datum/vestige_trial/little_moon,
	)
	boon_types = list(
		/datum/vestige_boon/spell/cosmic_dash,
		/datum/vestige_boon/spell/cosmic_dash/unbroken,
		/datum/vestige_boon/spell/held_breath,
		/datum/vestige_boon/spell/held_breath/long_exposure,
		/datum/vestige_boon/spell/beckon,
		/datum/vestige_boon/spell/glass_phase,
	)
	idle_lines = list(
		"You call it nothing. It is not nothing. It is everything, minus the parts you were told to look at.",
		"Glass is the politest kind of lie: both sides get to believe they are the ones inside.",
		"Your ship is a held breath. One day every ship exhales. I simply prefer not to wait indoors.",
		"The void has never killed anyone. The vacuum does that. The void just watches, like me.",
		"Knock, sometime, from the outside. Watch how quickly a room full of air remembers it is a bubble.",
		"Nothing thrown into the void is lost. It is exactly where it stopped being yours.",
	)
	accept_line = "Good. Step outside. I will make the introductions."
	busy_line = "Something else already holds your leash. I do not share windows."
	fulfilled_line = "You have already been introduced. It remembers you."
	renounce_line = "Back behind the glass, then. It suits you."
	claim_line = "Something was set aside for you out there. Take it before you ask for more."
	exhausted_line = "I have shown you everything visible from this window. The rest you would have to see from the other side."
	remember_line = "You stopped. The void did not — it kept your things exactly where you dropped them."

// ===== TRIAL OF THE LONG DARK =====

/datum/vestige_trial/long_dark
	name = "Trial of the Long Dark"
	// Keep the count in sync with VESTIGE_VOID_SECONDS_NEEDED
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the shard. Carry it out into the nothing between hulls and stay — five minutes, all told, alive, with the shard on your person. The void does not want you dead. It wants you introduced."
	/// Cumulative seconds spent in hard vacuum with the shard
	var/seconds_in_void = 0

/datum/vestige_trial/long_dark/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_shard(get_turf(user)))

/datum/vestige_trial/long_dark/get_progress_text()
	return "The shard has soaked [round(seconds_in_void)] of [VESTIGE_VOID_SECONDS_NEEDED] seconds of void."

/// May complete (and delete) the trial
/datum/vestige_trial/long_dark/proc/soak(seconds)
	seconds_in_void += seconds
	refresh_tracker()
	if(seconds_in_void >= VESTIGE_VOID_SECONDS_NEEDED)
		complete()

/obj/item/vestige_shard
	name = "void shard"
	desc = "A splinter of crystal that is a slightly deeper black than whatever is behind it. Held to your ear, it sounds like a window being looked through."
	icon = 'icons/obj/ore.dmi'
	icon_state = "bluespace_crystal"
	color = "#3c1a5c"
	w_class = WEIGHT_CLASS_SMALL
	light_range = 1.4
	light_power = 0.4
	light_color = "#6633aa"

/obj/item/vestige_shard/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/item/vestige_shard/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

// Credits void-time while carried on someone's person (loc == mob covers
// hands, pockets and worn slots; a backpack's insides don't count as "held")
/obj/item/vestige_shard/process(seconds_per_tick)
	var/mob/living/holder = loc
	if(!istype(holder) || holder.stat == DEAD)
		return
	var/datum/vestige_trial/long_dark/trial = holder.mind?.active_vestige_trial
	if(!istype(trial))
		return
	var/turf/here = get_turf(holder)
	if(!here)
		return
	if(!isspaceturf(here))
		var/datum/gas_mixture/air = here.return_air()
		if(air && air.return_pressure() >= HAZARD_LOW_PRESSURE)
			return
	if(prob(6))
		to_chat(holder, span_notice("The shard hums against you, pleased with the company."))
	trial.soak(seconds_per_tick)

// ===== TRIAL OF THE OTHER SIDE =====

/**
 * The theme's flagship image, made into homework: a face at the window, seen
 * from indoors, with nothing behind it. The card only works from the void's
 * side of a pane with a breathing room beyond, so every credit is that scene
 * happening to somebody's ship — and the knock lands at the START of the
 * press, so anyone inside gets the whole channel to look up and meet it.
 * Progress is deduped by the AREA beyond the glass, not the pane: a row of
 * mess-hall windows is one introduction, the walk around the whole hull is
 * five.
 */
/datum/vestige_trial/other_side
	name = "Trial of the Other Side"
	// Keep the count in sync with VESTIGE_CALLER_ROOMS_NEEDED
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the card. All your life the glass has been between you and the nothing, and you have always stood on the flattering side. Trade places: stand in the void and press it to the panes of five different rooms that still hold their breath. Let whoever looks up see an aquarium from the correct side, just once."
	/// Rooms already called upon (area weakref -> TRUE) — every introduction needs a new room
	var/list/rooms_called = list()
	/// The loaned card, reclaimed (deleted) the moment the pact ends
	var/obj/item/vestige_calling_card/card

/datum/vestige_trial/other_side/on_accepted(mob/living/user)
	card = hand_over(user, new /obj/item/vestige_calling_card(get_turf(user)))
	to_chat(user, span_notice("The card settles into your palm with the weight of an appointment."))

/datum/vestige_trial/other_side/Destroy()
	QDEL_NULL(card)
	return ..()

/datum/vestige_trial/other_side/get_progress_text()
	return "The card has been pressed to the glass of [length(rooms_called)] of [VESTIGE_CALLER_ROOMS_NEEDED] breathing rooms."

/// Credits one room. May complete (and delete) the trial. Returns FALSE if this room has already been called upon.
/datum/vestige_trial/other_side/proc/call_upon(area/room)
	var/datum/weakref/key = WEAKREF(room)
	if(rooms_called[key])
		return FALSE
	rooms_called[key] = TRUE
	refresh_tracker()
	if(length(rooms_called) >= VESTIGE_CALLER_ROOMS_NEEDED)
		complete()
	return TRUE

/obj/item/vestige_calling_card
	name = "caller's card"
	desc = "A calling card cut from windowpane, its edges too smooth to have been cut at all. Whichever side of it you examine, you get the feeling you are looking in from outside."
	icon = 'icons/obj/debris.dmi'
	icon_state = "medium"
	color = "#3c1a5c"
	w_class = WEIGHT_CLASS_TINY

/obj/item/vestige_calling_card/examine(mob/user)
	. = ..()
	. += span_notice("Pressed to a window from the void's side — hard vacuum at your back, a room still holding its breath beyond the pane — it makes an introduction. It expects [VESTIGE_CALLER_ROOMS_NEEDED] different rooms.")

/obj/item/vestige_calling_card/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!istype(interacting_with, /obj/structure/window))
		return NONE
	var/obj/structure/window/pane = interacting_with
	var/datum/vestige_trial/other_side/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "just cold glass in your hand!")
		return ITEM_INTERACT_BLOCKING
	if(!pane.density)
		return ITEM_INTERACT_BLOCKING
	if(!void_side(get_turf(user)))
		balloon_alert(user, "you must call from the void's side!")
		return ITEM_INTERACT_BLOCKING
	var/turf/far_turf = resolve_far_side(user, pane)
	if(!far_turf)
		balloon_alert(user, "square up to the glass!")
		return ITEM_INTERACT_BLOCKING
	if(void_side(far_turf))
		balloon_alert(user, "no held breath beyond this pane!")
		return ITEM_INTERACT_BLOCKING
	var/area/room = get_area(far_turf)
	if(istype(room, /area/ruin/space/has_grav/vestige))
		balloon_alert(user, "this glass already knows you!")
		return ITEM_INTERACT_BLOCKING
	if(trial.rooms_called[WEAKREF(room)])
		balloon_alert(user, "this room has been called upon!")
		return ITEM_INTERACT_BLOCKING
	// The tell fires before the press lands: the knock is the point
	pane.visible_message(span_warning("Something knocks, once, and presses flat against [pane] — from the outside."))
	playsound(pane, 'sound/effects/glass/glassknock.ogg', 75, TRUE)
	if(!do_after(user, VESTIGE_CALLER_PRESS_TIME, target = pane))
		return ITEM_INTERACT_BLOCKING
	// Re-resolve everything; the pact may have been renounced (or the room vented) mid-press
	trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(pane) || !pane.density)
		return ITEM_INTERACT_BLOCKING
	if(!void_side(get_turf(user)) || void_side(far_turf))
		balloon_alert(user, "the introduction fell through!")
		return ITEM_INTERACT_BLOCKING
	if(!trial.call_upon(room))
		return ITEM_INTERACT_BLOCKING
	// call_upon may have completed (and deleted) the trial, which reclaims this
	// card — the same tail the proboscis rides; nothing past here touches either
	pane.visible_message(span_danger("Frost blooms across [pane] in the shape of a spread hand."))
	playsound(pane, 'sound/effects/magic/voidblink.ogg', 40, TRUE)
	balloon_alert(user, "introduced")
	return ITEM_INTERACT_SUCCESS

/// TRUE when a turf sits on the void's side of things: space, or air too thin to matter (the shard's own standard)
/obj/item/vestige_calling_card/proc/void_side(turf/here)
	if(!here || isspaceturf(here))
		return TRUE
	var/datum/gas_mixture/air = here.return_air()
	return !air || air.return_pressure() < HAZARD_LOW_PRESSURE

/**
 * The turf beyond the pane from where the caller floats, or null when the
 * geometry refuses. Windows are border objects: a fulltile pane seals its
 * whole tile (the room starts one step past it), a directional pane seals one
 * edge (its own tile IS the room, and it must actually face the caller — a
 * pane sealing some other edge has no glass between the two of you).
 */
/obj/item/vestige_calling_card/proc/resolve_far_side(mob/living/user, obj/structure/window/pane)
	var/turf/pane_turf = get_turf(pane)
	var/turf/user_turf = get_turf(user)
	if(!pane_turf || !user_turf)
		return null
	if(pane_turf == user_turf) // a border pane on the caller's own tile: beyond is past the edge it seals
		return get_step(pane_turf, pane.dir)
	var/press_dir = get_dir(user_turf, pane_turf)
	if(!(press_dir in GLOB.cardinals)) // no diagonal introductions
		return null
	if(pane.fulltile)
		return get_step(pane_turf, press_dir)
	if(pane.dir != REVERSE_DIR(press_dir))
		return null
	return pane_turf

// ===== TRIAL OF THE LITTLE MOON =====

/**
 * A trust exercise with ballistics: hurl the keepsake into the nothing, let it
 * cross twenty uninterrupted space turfs, then go out and collect it. Flight
 * physics live on the item (the trial datum only mirrors them for the
 * readout). Mechanics checked against source: a throw converts to newtonian
 * drift when SSthrowing finalizes it, every drift step is a real Move (so
 * Moved counts turfs), and a flight that ends by HITTING something never
 * resumes drifting — the THROW_LANDED signal catches that case. Stopping a
 * qualified flight is done by qdel-ing the drift_handler, which is the
 * handler's own supported teardown (its handle_move qdels itself mid-Moved
 * routinely). Deleting the keepsake mid-equip on completion is likewise safe:
 * put_in_hand explicitly null-checks QDELETED items after on_equipped.
 */
/datum/vestige_trial/little_moon
	name = "Trial of the Little Moon"
	// Keep the count in sync with VESTIGE_MOON_DRIFT_NEEDED
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the keepsake. Throw it into the nothing — a true throw, twenty tiles of open void without one interruption — and where its flight ends it will stop, and shine, and wait. Then go out and bring it home. If the dark keeps it, renounce your pact and I will cut you another; I will mind less than you will."
	/// Longest unbroken flight so far, in space turfs (a mirror of the keepsake's live count, for the readout)
	var/best_flight = 0
	/// Whether the keepsake has finished its flight and now waits to be brought home
	var/keepsake_settled = FALSE
	/// The loaned keepsake, reclaimed (deleted) the moment the pact ends
	var/obj/item/vestige_keepsake/keepsake

/datum/vestige_trial/little_moon/on_accepted(mob/living/user)
	keepsake = hand_over(user, new /obj/item/vestige_keepsake(get_turf(user)))
	to_chat(user, span_notice("The keepsake tugs at your grip — gently, constantly, in no particular direction."))

/datum/vestige_trial/little_moon/Destroy()
	QDEL_NULL(keepsake)
	return ..()

/datum/vestige_trial/little_moon/get_progress_text()
	if(keepsake_settled)
		return "The keepsake waits, shining, where its flight ended. Bring it home."
	return "The keepsake's longest unbroken flight: [best_flight] of [VESTIGE_MOON_DRIFT_NEEDED] tiles of nothing."

/// Mirrors the keepsake's live flight distance into the pact readout
/datum/vestige_trial/little_moon/proc/track_flight(tiles)
	if(tiles <= best_flight)
		return
	best_flight = tiles
	refresh_tracker()

/// The flight is done; all that is left is the walk out to collect it
/datum/vestige_trial/little_moon/proc/mark_settled()
	keepsake_settled = TRUE
	refresh_tracker()

/obj/item/vestige_keepsake
	name = "void keepsake"
	desc = "A knuckle of glass fused the wrong way round, dark all the way through. Held still, it leans very slightly toward the nearest window."
	icon = 'icons/obj/ore.dmi'
	icon_state = "slag"
	color = "#9b7fc4"
	w_class = WEIGHT_CLASS_SMALL
	throwforce = 0
	/// Mind of whoever last let go of it — that soul's flights are the ones that count
	var/datum/mind/bound_mind
	/// Space turfs crossed by the current unbroken flight
	var/flight_tiles = 0
	/// Whether the flight has finished: it now shines and waits to be brought home
	var/settled = FALSE

/obj/item/vestige_keepsake/Initialize(mapload)
	. = ..()
	// Catches the flight that ends by hitting something at full distance —
	// drift never resumes there, so Moved alone would miss the settle
	RegisterSignal(src, COMSIG_MOVABLE_THROW_LANDED, PROC_REF(on_flight_landed))

/obj/item/vestige_keepsake/Destroy()
	bound_mind = null
	return ..()

/obj/item/vestige_keepsake/examine(mob/user)
	. = ..()
	if(settled)
		. += span_notice("Its flight is finished. Now it waits to be brought home.")
	else
		. += span_notice("Thrown into open space, it flies until something ends the flight. It wants [VESTIGE_MOON_DRIFT_NEEDED] uninterrupted tiles of nothing — being caught, pulled or grounded starts the count over.")

// A settled keepsake keeps its provenance: couriers who ferry it home for the
// thrower must not steal (or break) the binding by putting it down
/obj/item/vestige_keepsake/dropped(mob/user, silent = FALSE)
	. = ..()
	if(!settled && user?.mind)
		bound_mind = user.mind

/// The bound soul's little-moon trial, if it still runs — resolved fresh every time, never stored (renounce-safe)
/obj/item/vestige_keepsake/proc/get_bound_trial()
	var/datum/vestige_trial/little_moon/trial = bound_mind?.active_vestige_trial
	if(istype(trial))
		return trial
	return null

/obj/item/vestige_keepsake/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(settled)
		return
	// Into a hand, a bag, a locker: the flight (if any) is over
	if(!isturf(loc))
		flight_tiles = 0
		return
	// Out of a hand onto a turf: the launch itself, counted from zero
	if(!isturf(old_loc))
		flight_tiles = 0
		return
	// Only unaccompanied flight over open space counts — a floor grounds it, a leash disqualifies it
	if(!isspaceturf(loc) || pulledby)
		flight_tiles = 0
		return
	flight_tiles++
	var/datum/vestige_trial/little_moon/trial = get_bound_trial()
	trial?.track_flight(flight_tiles)
	if(flight_tiles < VESTIGE_MOON_DRIFT_NEEDED)
		return
	if(throwing) // still mid-throw: the drift handoff (or the landing hook) settles it
		return
	settle()

/// A throw that ends by hitting something never resumes drifting — settle here if the flight already qualifies
/obj/item/vestige_keepsake/proc/on_flight_landed(datum/source, datum/thrownthing/flight)
	SIGNAL_HANDLER
	if(settled || flight_tiles < VESTIGE_MOON_DRIFT_NEEDED)
		return
	if(!isturf(loc) || !isspaceturf(loc))
		return
	settle()

/**
 * The flight is complete: kill whatever momentum is left and turn the
 * keepsake into a little moon — anchored by nothing, lit well enough to be
 * found again from a long way off.
 */
/obj/item/vestige_keepsake/proc/settle()
	settled = TRUE
	if(drift_handler)
		qdel(drift_handler)
	set_light(2, 1, "#7a5db8")
	visible_message(span_warning("[src] stops dead, mid-nothing, and begins to shine."))
	var/datum/vestige_trial/little_moon/trial = get_bound_trial()
	trial?.mark_settled()
	var/mob/living/thrower = bound_mind?.current
	if(istype(thrower))
		to_chat(thrower, span_boldnotice("Somewhere out in the dark, the keepsake stops — and shines, and waits, exactly where it stopped being yours."))
		playsound(thrower, 'sound/effects/magic/voidblink.ogg', 30, TRUE)

// Retrieval is the completion: the settled keepsake returning to the thrower's
// own possession fulfills the pact, wherever that reunion happens — geography
// already puts it twenty-plus tiles of nothing away from where it was let go
/obj/item/vestige_keepsake/equipped(mob/user, slot, initial = FALSE)
	. = ..()
	if(!settled || initial)
		return
	if(!user.mind || user.mind != bound_mind)
		return
	var/datum/vestige_trial/little_moon/trial = get_bound_trial()
	if(!istype(trial))
		return
	to_chat(user, span_notice("The keepsake is warm for exactly one heartbeat. Then your hand closes on nothing at all: reclaimed, and delivered."))
	trial.complete() // deletes the trial, which reclaims the keepsake — touch neither afterward

// ===== BOONS =====

/datum/vestige_boon/spell/cosmic_dash
	name = "Cosmic Dash"
	desc = "Hurl yourself across a gap like something the void spat out — anyone standing where you land will wish they hadn't been."
	grant_text = "Distance quietly stops feeling like your problem."
	spell_type = /datum/action/cooldown/mob_cooldown/charge/vestige_dash

/datum/vestige_boon/spell/cosmic_dash/unbroken
	name = "Unbroken Dash"
	desc = "The dash, corrected. You no longer stop where the first thing you meet thinks you should — pass through them, and let the floor make the introductions."
	grant_text = "Stopping begins to feel like a habit you picked up from other people."
	upgrades_from = /datum/vestige_boon/spell/cosmic_dash
	spell_type = /datum/action/cooldown/mob_cooldown/charge/vestige_dash/unbroken

/datum/vestige_boon/spell/held_breath
	name = "Held Breath"
	desc = "Step outside and the void will hold its breath for you — a short while in which the cold and the emptiness decline to notice. Bring your own air; it has none to lend."
	grant_text = "Somewhere on the far side of every window, something vast inhales, and waits."
	spell_type = /datum/action/cooldown/spell/vestige_held_breath

/datum/vestige_boon/spell/held_breath/long_exposure
	name = "Long Exposure"
	desc = "Stay in the frame long enough and the void stops checking. It holds its breath longer for you now — and lets you breathe the nothing, and walk on it like floor. Try not to be smug about it indoors."
	grant_text = "The void files you under scenery. Come and go as the weather does."
	upgrades_from = /datum/vestige_boon/spell/held_breath
	spell_type = /datum/action/cooldown/spell/vestige_held_breath/long_exposure

/datum/vestige_boon/spell/beckon
	name = "Come to the Window"
	desc = "Fix your eyes on someone distant and disagree with the distance. The air thins first — the watchful will feel it coming — but feeling and stopping are different hobbies."
	grant_text = "Everything you can see is now, technically, within arm's reach. Do be polite about it."
	spell_type = /datum/action/cooldown/spell/pointed/vestige_beckon

/datum/vestige_boon/spell/glass_phase
	name = "Through the Pane"
	desc = "Press yourself to the glass and wait until both sides agree you were always on the other one. Live lattice still refuses you; electricity has no imagination."
	grant_text = "Glass stops taking sides. Windows were only ever doors with opinions."
	spell_type = /datum/action/cooldown/spell/pointed/vestige_glass_phase

// ===== COSMIC DASH =====

// Human-tuned subtype of the generic charge action (the component only ever
// touches owner, so a mind-targeted grant to a plain human is safe).
// Note the icon: "void_dash" lives in actions_items.dmi — the file the charge
// base inherits and the voidwalker's own charge draws from — NOT in
// actions_voidwalker.dmi, which only holds the telepathy button.
/datum/action/cooldown/mob_cooldown/charge/vestige_dash
	name = "Cosmic Dash"
	desc = "Hurl yourself at a target, trampling whatever you connect with."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "void_dash"
	cooldown_time = 20 SECONDS
	charge_distance = 8
	charge_damage = 15
	charge_past = 0
	destroy_objects = FALSE

/datum/action/cooldown/mob_cooldown/charge/vestige_dash/do_charge_indicator(atom/charger, atom/charge_target)
	playsound(owner, 'sound/effects/curse/curse1.ogg', 60)

/**
 * The upgrade: aims one turf past the target and floors whoever it connects
 * with. The knockdown is what makes the pass-through real — the charge's move
 * loop keeps walking after a bump, and a floored mob no longer blocks the
 * tile — so the twist is mechanical, not just numbers. Same damage as the
 * base dash on purpose.
 */
/datum/action/cooldown/mob_cooldown/charge/vestige_dash/unbroken
	name = "Unbroken Dash"
	desc = "Hurl yourself at a target and pass straight through them — whoever you connect with is trampled flat and left behind you."
	cooldown_time = 15 SECONDS
	charge_distance = 9
	charge_past = 1

/datum/action/cooldown/mob_cooldown/charge/vestige_dash/unbroken/hit_target(atom/movable/source, mob/living/target, damage_dealt)
	. = ..()
	if(isliving(target))
		target.Knockdown(1.5 SECONDS)

// ===== HELD BREATH =====

/**
 * Timed void adaptation. Upstream hands humans the PERMANENT version of this
 * twice over (the stable voided trauma's trait list, the changeling's void
 * adaption), so a local status effect on a long cooldown is the conservative
 * cut: same traits, on a timer, with the countdown on the HUD.
 */
/datum/action/cooldown/spell/vestige_held_breath
	name = "Held Breath"
	desc = "For a while, cold and low pressure decline to harm you. The void has no air to lend — carry your own."
	button_icon = 'icons/mob/actions/actions_ecult.dmi'
	button_icon_state = "space_crawl"
	background_icon_state = "bg_void"
	overlay_icon_state = null
	school = SCHOOL_FORBIDDEN
	cooldown_time = 3 MINUTES
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	/// The timed adaptation this cast applies
	var/adaptation_type = /datum/status_effect/vestige_held_breath

/datum/action/cooldown/spell/vestige_held_breath/long_exposure
	name = "Long Exposure"
	desc = "For a good while, cold, low pressure and the want of air decline to harm you, and the void underfoot behaves like floor."
	cooldown_time = 2 MINUTES
	adaptation_type = /datum/status_effect/vestige_held_breath/long_exposure

/datum/action/cooldown/spell/vestige_held_breath/cast(mob/living/cast_on)
	. = ..()
	cast_on.apply_status_effect(adaptation_type)
	playsound(cast_on, 'sound/effects/magic/voidblink.ogg', 50, TRUE)
	to_chat(cast_on, span_notice("Something vast inhales on your behalf, and the cold loses your address."))

/datum/status_effect/vestige_held_breath
	id = "vestige_held_breath"
	duration = 45 SECONDS
	status_type = STATUS_EFFECT_REPLACE
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = /atom/movable/screen/alert/status_effect/vestige_held_breath
	show_duration = TRUE
	/// Traits lent for the duration (the stable voided trauma lends the first two permanently)
	var/list/adaptation_traits = list(TRAIT_RESISTLOWPRESSURE, TRAIT_RESISTCOLD)

/datum/status_effect/vestige_held_breath/on_apply()
	owner.add_traits(adaptation_traits, TRAIT_STATUS_EFFECT(id))
	return TRUE

/datum/status_effect/vestige_held_breath/on_remove()
	owner.remove_traits(adaptation_traits, TRAIT_STATUS_EFFECT(id))
	to_chat(owner, span_warning("Somewhere just past the glass, the void lets its breath back out."))

// The upgrade holds longer and adds vacuum breathing plus footing on space
// turfs (the trait the void-native fauna use), so the hold becomes a real
// walk outside rather than a countdown to the nearest airlock
/datum/status_effect/vestige_held_breath/long_exposure
	duration = 75 SECONDS
	adaptation_traits = list(TRAIT_RESISTLOWPRESSURE, TRAIT_RESISTCOLD, TRAIT_NO_BREATHLESS_DAMAGE, TRAIT_SPACEWALK)

/atom/movable/screen/alert/status_effect/vestige_held_breath
	name = "Held Breath"
	desc = "The void is holding its breath on your behalf. Cold and vacuum decline to notice you — for now."
	icon_state = "weightless"

// ===== COME TO THE WINDOW =====

/**
 * A void pull built locally: the heretic's void_pull drags victims with raw
 * forceMove (which ignores walls), so this uses a throw instead — the body
 * stops at whatever it hits, and a windowpane between you is exactly where a
 * victim ends up. Telegraphed: the victim gets a visual, a sound and a chat
 * warning one and a quarter seconds before the yank, and breaking line of
 * sight, leaving range, buckling in or holy antimagic all defeat it (the
 * caster's cooldown stays spent).
 */
/datum/action/cooldown/spell/pointed/vestige_beckon
	name = "Come to the Window"
	desc = "Mark someone at a distance; a moment later they are dragged several tiles toward you. Breaking your line of sight or being buckled down defeats the pull."
	button_icon = 'icons/mob/actions/actions_ecult.dmi'
	button_icon_state = "voidpull"
	background_icon_state = "bg_void"
	overlay_icon_state = null
	school = SCHOOL_FORBIDDEN
	cooldown_time = 30 SECONDS
	invocation_type = INVOCATION_NONE
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC
	antimagic_flags = MAGIC_RESISTANCE_HOLY
	cast_range = 7
	active_msg = "You fix your attention on the middle distance..."
	deactive_msg = "You let the distance keep its opinion."
	/// Delay between the telegraph and the yank — the victim's window to break line of sight
	var/windup = 1.25 SECONDS
	/// How many tiles the victim is dragged toward the caster
	var/pull_range = 3

/datum/action/cooldown/spell/pointed/vestige_beckon/is_valid_target(atom/cast_on)
	. = ..()
	if(!.)
		return FALSE
	if(!isliving(cast_on))
		cast_on.balloon_alert(owner, "cannot be beckoned!")
		return FALSE
	return TRUE

/datum/action/cooldown/spell/pointed/vestige_beckon/cast(mob/living/victim)
	. = ..()
	playsound(victim, 'sound/effects/magic/voidblink.ogg', 60, TRUE)
	new /obj/effect/temp_visual/circle_wave/unsettle(get_turf(victim))
	owner.Beam(victim, icon_state = "purple_lightning", time = windup)
	if(victim.stat == CONSCIOUS)
		to_chat(victim, span_userdanger("The air between you and [owner] pulls thin, like a pane about to give!"))
	addtimer(CALLBACK(src, PROC_REF(yank), victim), windup)

/// The delayed yank. Every out it checks is deliberate counterplay — don't quietly relax them.
/datum/action/cooldown/spell/pointed/vestige_beckon/proc/yank(mob/living/victim)
	if(QDELETED(victim) || QDELETED(owner) || !isliving(owner) || owner.stat == DEAD)
		return
	if(!isturf(victim.loc) || victim.z != owner.z || get_dist(owner, victim) > cast_range + 1)
		owner.balloon_alert(owner, "slipped out of the frame!")
		return
	if(!(victim in view(cast_range + 1, owner)))
		owner.balloon_alert(owner, "line of sight broken!")
		return
	if(victim.can_block_magic(antimagic_flags))
		owner.balloon_alert(owner, "something refuses the pull!")
		return
	if(victim.buckled || victim.anchored)
		owner.balloon_alert(owner, "held fast!")
		return
	victim.visible_message(
		span_danger("[victim] is wrenched through the air, as if something behind the world pulled a thread!"),
		span_userdanger("The distance between you and [owner] is abruptly withdrawn!"),
	)
	playsound(victim, 'sound/effects/curse/curse1.ogg', 60, TRUE)
	victim.Knockdown(1 SECONDS)
	victim.safe_throw_at(get_turf(owner), pull_range, 2, owner, spin = FALSE)

// ===== THROUGH THE PANE =====

/**
 * The voidwalker's glass-passing, recut as a spell. Upstream this is the
 * glass_passer component (which the stable voided trauma already puts on
 * plain humans — verified human-safe), but a component is body-bound and
 * always-on; a spell rides the mind like every other boon and takes a
 * cooldown. Mechanics checked against source: PASSWINDOW is in the
 * pass_flags_self of BOTH windows and grilles, so one flag crosses the whole
 * pane; fulltile windows deliberately skip their exit-blocking handler, so
 * stepping onward out of the pane's tile is free; shocked grilles are
 * refused, same as the component. The channel happens in before_cast so a
 * failed or interrupted phase never spends the cooldown.
 */
/datum/action/cooldown/spell/pointed/vestige_glass_phase
	name = "Through the Pane"
	desc = "Press against an adjacent window or grille and slowly pass to the far side. Electrified lattice will refuse you."
	button_icon = 'icons/mob/actions/actions_minor_antag.dmi'
	button_icon_state = "ninja_phase"
	background_icon_state = "bg_void"
	overlay_icon_state = null
	school = SCHOOL_FORBIDDEN
	cooldown_time = 15 SECONDS
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	cast_range = 1
	aim_assist = FALSE
	active_msg = "You prepare to take the glass's side of the argument..."
	deactive_msg = "You concede the pane."
	/// Length of the channel, spent visibly pressed against the glass
	var/phase_time = 3 SECONDS
	/// The pane a successful before_cast carried the owner through, for cast()'s flavor. Same-tick handoff only.
	var/obj/structure/passed_pane

/datum/action/cooldown/spell/pointed/vestige_glass_phase/Destroy()
	passed_pane = null
	return ..()

/// The dense window or grille a click lands on, accepting clicks on the turf itself
/datum/action/cooldown/spell/pointed/vestige_glass_phase/proc/resolve_pane(atom/cast_on)
	if(istype(cast_on, /obj/structure/window) || istype(cast_on, /obj/structure/grille))
		var/obj/structure/pane = cast_on
		if(pane.density)
			return pane
		return null
	if(!isturf(cast_on))
		return null
	for(var/obj/structure/candidate in cast_on)
		if(!candidate.density)
			continue
		if(istype(candidate, /obj/structure/window) || istype(candidate, /obj/structure/grille))
			return candidate
	return null

/datum/action/cooldown/spell/pointed/vestige_glass_phase/is_valid_target(atom/cast_on)
	. = ..()
	if(!.)
		return FALSE
	if(!resolve_pane(cast_on))
		owner.balloon_alert(owner, "no glass there!")
		return FALSE
	return TRUE

// The channel AND the step both live here: anything that fails cancels the
// cast outright, so the cooldown is only ever paid for an actual crossing
/datum/action/cooldown/spell/pointed/vestige_glass_phase/before_cast(atom/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return
	passed_pane = null
	var/obj/structure/pane = resolve_pane(cast_on)
	if(!pane)
		return . | SPELL_CANCEL_CAST
	var/move_dir = get_dir(owner, pane) || pane.dir
	if(!(move_dir in GLOB.cardinals))
		owner.balloon_alert(owner, "square up to the glass!")
		return . | SPELL_CANCEL_CAST
	var/turf/destination
	if(pane.loc == owner.loc) // a border window on our own tile: step across it
		destination = get_step(owner, move_dir)
	else
		destination = get_turf(pane)
	if(!destination)
		return . | SPELL_CANCEL_CAST
	owner.visible_message(
		span_warning("[owner] presses flat against [pane]..."),
		span_notice("You press yourself against [pane] and wait for it to take your side."),
	)
	playsound(pane, 'sound/effects/glass/glassknock.ogg', 60, TRUE)
	if(!do_after(owner, phase_time, target = pane))
		return . | SPELL_CANCEL_CAST
	if(QDELETED(pane) || !pane.density)
		return . | SPELL_CANCEL_CAST
	// Live lattice is the hard counter, exactly as it is for the voidwalker
	for(var/obj/structure/grille/lattice in destination)
		if(lattice.is_shocked())
			owner.balloon_alert(owner, "the lattice is live!")
			return . | SPELL_CANCEL_CAST
	// The step itself: PASSWINDOW crosses window and grille borders; any other dense thing still refuses
	passwindow_on(owner, REF(src))
	var/moved = owner.Move(destination)
	passwindow_off(owner, REF(src))
	if(!moved)
		owner.balloon_alert(owner, "something on the far side refuses!")
		return . | SPELL_CANCEL_CAST
	passed_pane = pane

/datum/action/cooldown/spell/pointed/vestige_glass_phase/cast(atom/cast_on)
	. = ..()
	var/obj/structure/pane = passed_pane
	passed_pane = null
	if(QDELETED(pane))
		return
	apply_wibbly_filters(pane)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(remove_wibbly_filters), pane, 0.5 SECONDS), 1 SECONDS)
	playsound(pane, 'sound/effects/magic/blind.ogg', 60, TRUE)
	owner.visible_message(
		span_warning("[owner] passes through [pane] like a smear on the glass!"),
		span_notice("Both sides of [pane] briefly agree about you, and then you are on the other one."),
	)

#undef VESTIGE_CALLER_ROOMS_NEEDED
#undef VESTIGE_CALLER_PRESS_TIME
#undef VESTIGE_MOON_DRIFT_NEEDED
