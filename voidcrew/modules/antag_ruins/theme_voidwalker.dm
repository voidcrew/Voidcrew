/**
 * # The Aperture: voidwalker vestige
 *
 * A hull section that is mostly windows, all of them facing nothing. The
 * voidwalker's body is the antag (space-native, unportable), so the patron is
 * what watches through the glass, the trials are introductions, to the dark,
 * to the glass, to the other side, and the boons are human-tuned pieces of
 * what the voidwalker does through a pane: the dash, the void's tolerance,
 * the pull, the passing-through. Each port's doc comment records what
 * coupling it was checked for.
 */

// ===== PATRON =====

/mob/living/basic/vestige_patron/watcher
	name = "the Watcher Behind Glass"
	desc = "A tall silhouette standing at the window. Or just past it - hard to tell. It watches you the way you'd watch a fish tank."
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
		"You call it nothing. It isn't nothing. It's just the part nobody bothered to name.",
		"Glass is a polite lie. Both sides get to think they're the one on the inside.",
		"Your ship is a held breath. Every ship exhales eventually. I'd rather not be indoors when yours does.",
		"The void has never killed anyone. Vacuum does that. The void just watches, same as me.",
		"Knock on a window from the outside sometime. You'll see how fast a room full of air remembers it's a bubble.",
		"Nothing thrown into the void is lost. It's exactly where you left it. You just can't reach it.",
	)
	accept_line = "Good. Step outside. I'll make the introductions."
	busy_line = "Something else already has a claim on you. I don't share."
	fulfilled_line = "You've already been introduced. It remembers you."
	renounce_line = "Back behind the glass, then. It suits you."
	claim_line = "Something was set aside for you out there. Take it before you ask for more."
	exhausted_line = "I've shown you everything you can see from this window. The rest you'd have to see from outside."
	remember_line = "You stopped for a while. The void didn't. What was yours is still yours."

// ===== TRIAL OF THE LONG DARK =====

/datum/vestige_trial/long_dark
	name = "Trial of the Long Dark"
	desc = "Activate the shard on a pressurized floor to set a return beacon. It will report a bearing toward a hidden exterior echo. Take two readings in open space, at least five tiles apart and from different angles to the echo; readings need a clear view and cannot be taken beside it. The second reading reveals the echo. Touch it with the shard to recover it, then bring the held shard back to the return beacon. Bring ordinary EVA protection and propulsion."
	var/obj/item/vestige_shard/shard
	var/obj/structure/vestige_void_beacon/home_beacon
	var/obj/structure/vestige_void_beacon/echo
	var/obj/effect/vestige_trial_marker/first_reading
	var/revealed = FALSE
	var/recovered = FALSE

/datum/vestige_trial/long_dark/on_accepted(mob/living/user)
	shard = hand_over(user, new /obj/item/vestige_shard(get_turf(user)))

/datum/vestige_trial/long_dark/Destroy()
	QDEL_NULL(shard)
	QDEL_NULL(home_beacon)
	QDEL_NULL(echo)
	return ..()

/datum/vestige_trial/long_dark/get_progress_text()
	var/mob/living/user = owner?.current
	if(!home_beacon)
		return "Set a return beacon by activating the shard on a pressurized floor."
	if(recovered)
		return "Echo recovered. Return the held shard to the beacon: [get_dist(user, home_beacon)] tiles [dir2text(get_dir(user, home_beacon))]."
	return "[first_reading ? "One bearing recorded; find a second angle." : "Take a bearing in open space."] Echo: [dir2text(get_dir(user, echo))], [get_dist(user, echo)] tiles.[revealed ? " Echo revealed: touch it with the shard." : ""]"

/datum/vestige_trial/long_dark/proc/set_home(mob/living/user)
	var/turf/center = get_turf(user)
	if(!isfloorturf(center))
		return FALSE
	var/datum/gas_mixture/air = center.return_air()
	if(!air || air.return_pressure() < HAZARD_LOW_PRESSURE)
		return FALSE
	var/list/candidates = list()
	for(var/turf/open/space/spot in range(10, center))
		if(get_dist(spot, center) < 6)
			continue
		var/clear = TRUE
		for(var/turf/nearby in range(2, spot))
			if(!isspaceturf(nearby))
				clear = FALSE
				break
		if(clear)
			candidates += spot
	if(!length(candidates))
		to_chat(user, span_warning("No open exterior echo within ten tiles. Set the beacon nearer a hull with open space beyond it."))
		return FALSE
	home_beacon = new(center)
	home_beacon.name = "void return beacon"
	register_loan(home_beacon)
	echo = new(pick(candidates))
	echo.name = "unresolved void echo"
	echo.invisibility = INVISIBILITY_ABSTRACT
	register_loan(echo)
	refresh_tracker()
	return TRUE

/// A useful baseline must be separated and not point along the same line.
/datum/vestige_trial/long_dark/proc/valid_baseline(turf/first, turf/second, turf/source)
	if(!first || !second || !source || first.z != second.z || source.z != first.z || get_dist(first, second) < 5)
		return FALSE
	var/twice_area = abs((first.x - source.x) * (second.y - source.y) - (second.x - source.x) * (first.y - source.y))
	return twice_area >= 15

/datum/vestige_trial/long_dark/proc/take_reading(mob/living/user)
	var/turf/here = get_turf(user)
	if(!home_beacon)
		return set_home(user)
	if(recovered || !isspaceturf(here) || get_dist(here, echo) < 3 || get_dist(here, echo) > 12 || !can_see(here, echo, 12))
		to_chat(user, span_warning("Readings need open space, a clear bearing, and a distance of three to twelve tiles from the echo."))
		return FALSE
	if(!first_reading)
		first_reading = mark_turf(here)
	else if(!revealed)
		if(!valid_baseline(get_turf(first_reading), here, get_turf(echo)))
			to_chat(user, span_warning("That baseline is too short or too nearly in line with the first bearing. Move at least five tiles across the bearing, not straight toward the echo."))
			return FALSE
		revealed = TRUE
		echo.invisibility = 0
		echo.name = "resolved void echo"
		echo.set_light(3, 1, "#9966dd")
	to_chat(user, span_notice(get_progress_text()))
	refresh_tracker()
	return TRUE

/obj/structure/vestige_void_beacon
	name = "void beacon"
	desc = "A temporary marker belonging to an exterior lesson."
	icon = 'icons/obj/ore.dmi'
	icon_state = "bluespace_crystal"
	color = "#9966dd"
	anchored = TRUE
	density = FALSE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF

/obj/item/vestige_shard
	name = "void shard"
	desc = "Activate to set a return beacon or take an exterior bearing. Touch the revealed echo to recover it; touch the return beacon to deliver."
	icon = 'icons/obj/ore.dmi'
	icon_state = "bluespace_crystal"
	inhand_icon_state = "minimeteor"
	color = "#3c1a5c"
	w_class = WEIGHT_CLASS_SMALL

/obj/item/vestige_shard/attack_self(mob/living/user, list/modifiers)
	var/datum/vestige_trial/long_dark/trial = user.mind?.active_vestige_trial
	if(istype(trial) && trial.shard == src)
		trial.take_reading(user)

/obj/item/vestige_shard/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/datum/vestige_trial/long_dark/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || trial.shard != src || !user.Adjacent(interacting_with))
		return NONE
	if(interacting_with == trial.home_beacon && trial.recovered)
		trial.complete()
		return ITEM_INTERACT_SUCCESS
	if(interacting_with != trial.echo || !trial.revealed || trial.recovered || !isspaceturf(get_turf(user)))
		return NONE
	if(!do_after(user, 2 SECONDS, target = interacting_with))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(trial) || user.mind?.active_vestige_trial != trial || !user.is_holding(src) || !isspaceturf(get_turf(user)))
		return ITEM_INTERACT_BLOCKING
	trial.recovered = TRUE
	trial.echo.invisibility = INVISIBILITY_ABSTRACT
	trial.echo.set_light(0)
	trial.refresh_tracker()
	balloon_alert(user, "echo held; return home")
	return ITEM_INTERACT_SUCCESS

// ===== TRIAL OF THE OTHER SIDE =====

/datum/vestige_trial/other_side
	name = "Trial of the Other Side"
	desc = "Choose one intact window separating a pressurized room from vacuum. Press the card from the room side to leave your reflection, travel outside and press the same pane from the matching void side, then carry the reply back inside and press it home. Keep the pane intact and the room pressurized throughout; venting it erases the reflection. A single full-tile or directional window is enough. Bring EVA equipment and plan the airlock route before leaving."
	var/obj/item/vestige_calling_card/card
	var/datum/weakref/pane_ref
	var/obj/effect/vestige_trial_marker/inside_ref
	var/phase = 0

/datum/vestige_trial/other_side/on_accepted(mob/living/user)
	card = hand_over(user, new /obj/item/vestige_calling_card(get_turf(user)))

/datum/vestige_trial/other_side/Destroy()
	QDEL_NULL(card)
	return ..()

/datum/vestige_trial/other_side/get_progress_text()
	return phase == 0 ? "Find one intact air-to-vacuum window; press the card from inside." : phase == 1 ? "Reflection waiting. Reach the same pane's opposite face through your airlock." : "Reply received. Bring the card back inside without breaking the pane or venting the room."

/datum/vestige_trial/other_side/proc/check_seal()
	if(!phase || inside_ref?.shuttle_moving)
		return TRUE
	var/obj/structure/window/pane = pane_ref?.resolve()
	var/turf/inside = get_turf(inside_ref)
	var/turf/outside = outside_turf()
	if(!QDELETED(pane) && pane.density && inside && outside && !card.void_side(inside) && card.void_side(outside))
		return TRUE
	phase = 0
	pane_ref = null
	QDEL_NULL(inside_ref)
	to_chat(owner?.current, span_warning("The pressure seal changed or the pane broke. The reflection is gone; start again from inside."))
	refresh_tracker()
	return FALSE

/// The vacuum face may be outside the shuttle footprint, so derive it from
/// the moving pane and its marked interior contact instead of a space marker.
/datum/vestige_trial/other_side/proc/outside_turf()
	return card?.resolve_far_side(inside_ref, pane_ref?.resolve())

/obj/item/vestige_calling_card
	name = "caller's card"
	desc = "A calling card cut from a windowpane. Leave a reflection inside, collect its reply from outside, and return it through your airlock while preserving the pressure seal."
	icon = 'icons/obj/debris.dmi'
	icon_state = "medium"
	inhand_icon_state = "shard-glass"
	lefthand_file = 'icons/mob/inhands/weapons/melee_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/weapons/melee_righthand.dmi'
	color = "#3c1a5c"
	w_class = WEIGHT_CLASS_TINY
	var/datum/weakref/trial_ref

/obj/item/vestige_calling_card/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/item/vestige_calling_card/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/vestige_calling_card/process(seconds_per_tick)
	var/datum/vestige_trial/other_side/trial = trial_ref?.resolve()
	trial?.check_seal()

/obj/item/vestige_calling_card/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!istype(interacting_with, /obj/structure/window) || !user.Adjacent(interacting_with))
		return NONE
	var/datum/vestige_trial/other_side/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || trial.card != src)
		return NONE
	trial_ref = WEAKREF(trial)
	var/obj/structure/window/pane = interacting_with
	var/turf/here = get_turf(user)
	var/turf/far_side = resolve_far_side(user, pane)
	if(!pane.density || !far_side || void_side(here) == void_side(far_side))
		balloon_alert(user, "need intact air-to-vacuum glass!")
		return ITEM_INTERACT_BLOCKING
	trial.check_seal()
	var/starting_phase = trial.phase
	if(trial.phase && pane != trial.pane_ref?.resolve())
		balloon_alert(user, "return to your marked pane!")
		return ITEM_INTERACT_BLOCKING
	var/want_outside = trial.phase == 1
	if(void_side(here) != want_outside)
		balloon_alert(user, want_outside ? "collect it from outside!" : "press it from inside!")
		return ITEM_INTERACT_BLOCKING
	var/turf/expected = want_outside ? trial.outside_turf() : get_turf(trial.inside_ref)
	if(trial.phase && here != expected)
		balloon_alert(user, "stand opposite your original print!")
		return ITEM_INTERACT_BLOCKING
	pane.visible_message(span_warning("A pale handprint presses against [pane], from [want_outside ? "outside" : "inside"]."))
	playsound(pane, 'sound/effects/glass/glassknock.ogg', 50, TRUE)
	if(!do_after(user, 3 SECONDS, target = pane))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(trial) || user.mind?.active_vestige_trial != trial || !user.is_holding(src) || QDELETED(pane) || !pane.density || get_turf(user) != here || void_side(here) == void_side(far_side))
		return ITEM_INTERACT_BLOCKING
	if(!trial.check_seal())
		return ITEM_INTERACT_BLOCKING
	if(trial.phase != starting_phase || void_side(here) != want_outside)
		return ITEM_INTERACT_BLOCKING
	if(!trial.phase)
		trial.pane_ref = WEAKREF(pane)
		trial.inside_ref = trial.mark_turf(here)
	trial.phase++
	trial.refresh_tracker()
	if(trial.phase >= 3)
		trial.complete()
	return ITEM_INTERACT_SUCCESS

/obj/item/vestige_calling_card/proc/void_side(turf/here)
	if(!here)
		return FALSE
	if(isspaceturf(here))
		return TRUE
	var/datum/gas_mixture/air = here.return_air()
	return !air || air.return_pressure() < HAZARD_LOW_PRESSURE

/// Full-tile panes seal a tile; directional panes seal one edge of their tile.
/obj/item/vestige_calling_card/proc/resolve_far_side(atom/user, obj/structure/window/pane)
	var/turf/pane_turf = get_turf(pane)
	var/turf/user_turf = get_turf(user)
	if(!pane_turf || !user_turf || get_dist(user_turf, pane_turf) > 1)
		return null
	if(pane_turf == user_turf)
		return pane.fulltile ? null : get_step(pane_turf, pane.dir)
	var/press_dir = get_dir(user_turf, pane_turf)
	if(!(press_dir in GLOB.cardinals))
		return null
	if(pane.fulltile)
		return get_step(pane_turf, press_dir)
	if(pane.dir != REVERSE_DIR(press_dir))
		return null
	return pane_turf

// ===== TRIAL OF THE LITTLE MOON =====

/datum/vestige_trial/little_moon
	name = "Trial of the Little Moon"
	desc = "Activate the recovery tether beside open space to launch the tumbling keepsake five tiles out. Examine it or the pact tracker for its two drift components. Pull it with the tether from two to six tiles away along a cardinal line: each pull moves it one tile toward you and subtracts that direction's drift, while you recoil one tile toward it in vacuum. Counter both components to zero, collect it, and deliver it to the launch cradle. Wrong-direction pulls add drift. Bring EVA propulsion so you can change approach sides."
	var/obj/item/vestige_recovery_tether/tether
	var/obj/structure/vestige_void_beacon/cradle
	var/obj/structure/vestige_tumbling_keepsake/cargo
	var/obj/item/vestige_keepsake/keepsake

/datum/vestige_trial/little_moon/on_accepted(mob/living/user)
	tether = hand_over(user, new /obj/item/vestige_recovery_tether(get_turf(user)))

/datum/vestige_trial/little_moon/Destroy()
	QDEL_NULL(tether)
	QDEL_NULL(cradle)
	QDEL_NULL(cargo)
	QDEL_NULL(keepsake)
	return ..()

/datum/vestige_trial/little_moon/get_progress_text()
	if(!cradle)
		return "Activate the tether beside five tiles of clear space to launch."
	if(keepsake)
		return "Keepsake stabilized. Collect it and touch it to the launch cradle."
	return "[cargo?.drift_text()] Cargo is [get_dist(owner?.current, cargo)] tiles [dir2text(get_dir(owner?.current, cargo))]. Pull opposite the remaining drift."

/datum/vestige_trial/little_moon/proc/launch(mob/living/user)
	if(cradle)
		to_chat(user, span_notice(get_progress_text()))
		return FALSE
	var/turf/start = get_turf(user)
	var/turf/destination
	for(var/direction in GLOB.cardinals)
		var/turf/step_turf = start
		var/clear = TRUE
		for(var/index in 1 to 5)
			step_turf = get_step(step_turf, direction)
			if(!isspaceturf(step_turf) || step_turf.is_blocked_turf(exclude_mobs = TRUE))
				clear = FALSE
				break
		if(clear)
			destination = step_turf
			break
	if(!destination)
		to_chat(user, span_warning("Stand beside a clear five-tile stretch of open space. The tether checks all four cardinal directions."))
		return FALSE
	cradle = new(start)
	cradle.name = "little moon launch cradle"
	register_loan(cradle)
	cargo = new(destination)
	cargo.drift_x = pick(-2, 2)
	cargo.drift_y = pick(-2, 2)
	register_loan(cargo)
	refresh_tracker()
	to_chat(user, span_notice(get_progress_text()))
	return TRUE

/obj/structure/vestige_tumbling_keepsake
	name = "tumbling keepsake"
	desc = "A glowing little moon precessing around its tether point. Counter both drift components with cardinal tether impulses before it can be handled."
	icon = 'icons/obj/ore.dmi'
	icon_state = "bluespace_crystal"
	color = "#ffaa66"
	anchored = TRUE
	density = FALSE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF
	light_range = 2
	light_power = 1
	var/drift_x = 2
	var/drift_y = 2

/obj/structure/vestige_tumbling_keepsake/proc/drift_text()
	return "Drift: [abs(drift_x)] [drift_x >= 0 ? "east" : "west"], [abs(drift_y)] [drift_y >= 0 ? "north" : "south"]."

/obj/structure/vestige_tumbling_keepsake/examine(mob/user)
	. = ..()
	. += span_notice(drift_text())

/// The impulse follows the cable. Wrong-side pulls worsen that component.
/obj/structure/vestige_tumbling_keepsake/proc/apply_impulse(direction)
	switch(direction)
		if(EAST)
			drift_x = clamp(drift_x + 1, -4, 4)
		if(WEST)
			drift_x = clamp(drift_x - 1, -4, 4)
		if(NORTH)
			drift_y = clamp(drift_y + 1, -4, 4)
		if(SOUTH)
			drift_y = clamp(drift_y - 1, -4, 4)
	return !drift_x && !drift_y

/obj/item/vestige_recovery_tether
	name = "little moon recovery tether"
	desc = "Activate beside space to launch the keepsake. Click it from two to six tiles away along a cardinal line to reel and counter its drift. Pulls recoil in vacuum; use EVA propulsion to reposition."
	icon = 'icons/obj/stack_objects.dmi'
	icon_state = "coil"
	inhand_icon_state = "coil_white"
	lefthand_file = 'icons/mob/inhands/equipment/tools_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/tools_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	var/next_pull = 0

/obj/item/vestige_recovery_tether/attack_self(mob/living/user, list/modifiers)
	var/datum/vestige_trial/little_moon/trial = user.mind?.active_vestige_trial
	if(istype(trial) && trial.tether == src)
		trial.launch(user)

/obj/item/vestige_recovery_tether/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/datum/vestige_trial/little_moon/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || trial.tether != src || interacting_with != trial.cargo || world.time < next_pull)
		return NONE
	var/obj/structure/vestige_tumbling_keepsake/cargo = trial.cargo
	var/direction = get_dir(cargo, user)
	var/turf/destination = get_step(cargo, direction)
	if(!(direction in GLOB.cardinals) || get_dist(user, cargo) < 2 || get_dist(user, cargo) > 6 || !can_see(user, cargo, 6) || !isspaceturf(destination))
		balloon_alert(user, "need cardinal cable, 2-6 tiles!")
		return ITEM_INTERACT_BLOCKING
	for(var/turf/cable_turf as anything in get_line(user, cargo))
		if(cable_turf.is_blocked_turf(exclude_mobs = TRUE))
			balloon_alert(user, "cable snagged!")
			return ITEM_INTERACT_BLOCKING
	if(!cargo.Move(destination, direction))
		balloon_alert(user, "cable snagged!")
		return ITEM_INTERACT_BLOCKING
	next_pull = world.time + 1 SECONDS
	if(isspaceturf(get_turf(user)))
		step_towards(user, cargo)
	if(cargo.apply_impulse(direction))
		trial.keepsake = new(get_turf(cargo))
		trial.register_loan(trial.keepsake)
		QDEL_NULL(trial.cargo)
		balloon_alert(user, "stable; collect and return!")
	else
		to_chat(user, span_notice(cargo.drift_text()))
	trial.refresh_tracker()
	return ITEM_INTERACT_SUCCESS

/obj/item/vestige_recovery_tether/ranged_interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	return interact_with_atom(interacting_with, user, modifiers)

/obj/item/vestige_keepsake
	name = "stabilized keepsake"
	desc = "A little moon at rest. Bring it back to its launch cradle."
	icon = 'icons/obj/ore.dmi'
	icon_state = "bluespace_crystal"
	inhand_icon_state = "minimeteor"
	color = "#7a5db8"
	w_class = WEIGHT_CLASS_SMALL
	light_range = 2
	light_power = 1

/obj/item/vestige_keepsake/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/datum/vestige_trial/little_moon/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || trial.keepsake != src || interacting_with != trial.cradle || !user.Adjacent(interacting_with))
		return NONE
	trial.complete()
	return ITEM_INTERACT_SUCCESS

// ===== BOONS =====

/datum/vestige_boon/spell/cosmic_dash
	name = "Cosmic Dash"
	desc = "Throw yourself across a gap fast enough to flatten whatever you land on."
	grant_text = "Distance stops being your problem."
	spell_type = /datum/action/cooldown/mob_cooldown/charge/vestige_dash

/datum/vestige_boon/spell/cosmic_dash/unbroken
	name = "Unbroken Dash"
	desc = "The dash, improved. You no longer stop at the first thing you hit - you go through it, and it goes down."
	grant_text = "Nothing gets to stop you halfway anymore."
	upgrades_from = /datum/vestige_boon/spell/cosmic_dash
	spell_type = /datum/action/cooldown/mob_cooldown/charge/vestige_dash/unbroken

/datum/vestige_boon/spell/held_breath
	name = "Held Breath"
	desc = "For a short while, cold and low pressure stop hurting you. Bring your own air - this doesn't provide any."
	grant_text = "The cold loses interest in you."
	spell_type = /datum/action/cooldown/spell/vestige_held_breath

/datum/vestige_boon/spell/held_breath/long_exposure
	name = "Long Exposure"
	desc = "For much longer, cold, low pressure and lack of air all stop hurting you, and empty space holds your feet like floor. Long enough to work out there instead of counting down to the nearest airlock."
	grant_text = "The void has stopped treating you as a visitor."
	upgrades_from = /datum/vestige_boon/spell/held_breath
	spell_type = /datum/action/cooldown/spell/vestige_held_breath/long_exposure

/datum/vestige_boon/spell/beckon
	name = "Come to the Window"
	desc = "Mark someone at range and drag them toward you. They get a moment's warning first, and breaking your line of sight defeats it."
	grant_text = "Anything you can see is within reach now."
	spell_type = /datum/action/cooldown/spell/pointed/vestige_beckon

/datum/vestige_boon/spell/glass_phase
	name = "Through the Pane"
	desc = "Press against a window or grille and pass through to the other side. Electrified grilles still stop you."
	grant_text = "Windows stop counting as walls."
	spell_type = /datum/action/cooldown/spell/pointed/vestige_glass_phase

// ===== COSMIC DASH =====

// Human-tuned subtype of the generic charge action (the component only ever
// touches owner, so a mind-targeted grant to a plain human is safe).
// Note the icon: "void_dash" lives in actions_items.dmi, the file the charge
// base inherits and the voidwalker's own charge draws from, NOT in
// actions_voidwalker.dmi, which only holds the telepathy button.
/datum/action/cooldown/mob_cooldown/charge/vestige_dash
	name = "Cosmic Dash"
	desc = "Charge at a target, trampling whatever you hit on the way."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "void_dash"
	cooldown_time = 20 SECONDS
	charge_distance = 8
	charge_damage = 15
	charge_past = 0
	destroy_objects = FALSE
	/// A blocked charge can bump the same intervening mob on several steps.
	var/list/dash_victims = list()

/datum/action/cooldown/mob_cooldown/charge/vestige_dash/charge_sequence(atom/movable/charger, atom/target_atom, delay, past)
	dash_victims.Cut()
	return ..()

/datum/action/cooldown/mob_cooldown/charge/vestige_dash/can_hit_target(atom/movable/source, atom/target)
	return ..() && !(target in dash_victims)

/datum/action/cooldown/mob_cooldown/charge/vestige_dash/hit_target(atom/movable/source, mob/living/target, damage_dealt)
	dash_victims += target
	return ..()

/datum/action/cooldown/mob_cooldown/charge/vestige_dash/do_charge_indicator(atom/charger, atom/charge_target)
	playsound(owner, 'sound/effects/curse/curse1.ogg', 60)

/**
 * The upgrade: aims one turf past the target and floors whoever it connects
 * with. The knockdown is what makes the pass-through real. The charge's move
 * loop keeps walking after a bump, and a floored mob no longer blocks the
 * tile, so the twist is mechanical, not just numbers. Same damage as the
 * base dash on purpose.
 */
/datum/action/cooldown/mob_cooldown/charge/vestige_dash/unbroken
	name = "Unbroken Dash"
	desc = "Charge at a target and pass straight through. They're knocked down and left behind you."
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
	desc = "For a while, cold and low pressure stop hurting you. You still need to bring your own air."
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
	desc = "For longer, cold, low pressure and lack of air all stop hurting you, and you can walk on empty space."
	cooldown_time = 2 MINUTES
	adaptation_type = /datum/status_effect/vestige_held_breath/long_exposure

/datum/action/cooldown/spell/vestige_held_breath/cast(mob/living/cast_on)
	. = ..()
	cast_on.apply_status_effect(adaptation_type)
	playsound(cast_on, 'sound/effects/magic/voidblink.ogg', 50, TRUE)
	to_chat(cast_on, span_notice("Something inhales somewhere behind you, and the cold stops finding you."))

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

/datum/status_effect/vestige_held_breath/be_replaced()
	// Another mind can bring the shorter adaptation to a body still wearing Long Exposure.
	owner.remove_traits(adaptation_traits, TRAIT_STATUS_EFFECT(id))
	return ..()

/datum/status_effect/vestige_held_breath/on_remove()
	owner.remove_traits(adaptation_traits, TRAIT_STATUS_EFFECT(id))
	to_chat(owner, span_warning("Somewhere behind you the breath lets out, and the cold remembers you're out here."))

// The upgrade holds longer and adds vacuum breathing plus footing on space
// turfs (the trait the void-native fauna use), so the hold becomes a real
// walk outside rather than a countdown to the nearest airlock
/datum/status_effect/vestige_held_breath/long_exposure
	duration = 75 SECONDS
	adaptation_traits = list(TRAIT_RESISTLOWPRESSURE, TRAIT_RESISTCOLD, TRAIT_NO_BREATHLESS_DAMAGE, TRAIT_SPACEWALK)

/atom/movable/screen/alert/status_effect/vestige_held_breath
	name = "Held Breath"
	desc = "Cold and vacuum are not hurting you right now."
	icon_state = "weightless"

// ===== COME TO THE WINDOW =====

/**
 * A void pull built locally: the heretic's void_pull drags victims with raw
 * forceMove (which ignores walls), so this uses a throw instead, the body
 * stops at whatever it hits, and a windowpane between you is exactly where a
 * victim ends up. Telegraphed: the victim gets a visual, a sound and a chat
 * warning one and a quarter seconds before the yank, and breaking line of
 * sight, leaving range, buckling in or holy antimagic all defeat it (the
 * caster's cooldown stays spent).
 */
/datum/action/cooldown/spell/pointed/vestige_beckon
	name = "Come to the Window"
	desc = "Mark someone at a distance; a moment later they're dragged several tiles toward you. Breaking line of sight or being buckled down stops it."
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
	active_msg = "You fix your attention on something in the distance..."
	deactive_msg = "You let it go."
	/// Delay between the telegraph and the yank, the victim's window to break line of sight
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
	addtimer(CALLBACK(src, PROC_REF(yank), victim, owner), windup)

/// The delayed yank. Every out it checks is deliberate counterplay. Don't quietly relax them.
/datum/action/cooldown/spell/pointed/vestige_beckon/proc/yank(mob/living/victim, mob/living/caster)
	if(QDELETED(victim) || QDELETED(caster) || owner != caster || !isliving(caster) || caster.stat == DEAD)
		return
	if(!isturf(victim.loc) || victim.z != owner.z || get_dist(owner, victim) > cast_range + 1)
		owner.balloon_alert(owner, "they got too far away!")
		return
	if(!(victim in view(cast_range + 1, owner)))
		owner.balloon_alert(owner, "line of sight broken!")
		return
	if(victim.can_block_magic(antimagic_flags))
		owner.balloon_alert(owner, "something blocked the pull!")
		return
	if(victim.buckled || victim.anchored)
		owner.balloon_alert(owner, "held fast!")
		return
	victim.visible_message(
		span_danger("[victim] is wrenched through the air by nothing at all!"),
		span_userdanger("Something yanks you hard toward [owner]!"),
	)
	playsound(victim, 'sound/effects/curse/curse1.ogg', 60, TRUE)
	victim.Knockdown(1 SECONDS)
	victim.safe_throw_at(get_turf(owner), pull_range, 2, owner, spin = FALSE)

// ===== THROUGH THE PANE =====

/**
 * The voidwalker's glass-passing, recut as a spell. Upstream this is the
 * glass_passer component (which the stable voided trauma already puts on
 * plain humans, verified human-safe), but a component is body-bound and
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
	desc = "Slowly push through an adjacent window or grille to the far side. Electrified grilles stop you."
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
	active_msg = "You get ready to press yourself into the glass..."
	deactive_msg = "You step back from the glass."
	/// Length of the channel, spent visibly pressed against the glass
	var/phase_time = 3 SECONDS
	/// The pane a successful before_cast carried the owner through, for cast()'s flavor. Same-tick handoff only.
	var/obj/structure/passed_pane
	/// Only one pane may be channeled at once, including across a mind transfer.
	var/phasing = FALSE

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
	if(phasing)
		return . | SPELL_CANCEL_CAST
	passed_pane = null
	var/mob/living/caster = owner
	var/obj/structure/pane = resolve_pane(cast_on)
	if(!pane || !isliving(caster) || !isturf(caster.loc) || !caster.Adjacent(pane))
		return . | SPELL_CANCEL_CAST
	var/pane_direction = pane.dir
	var/move_dir = get_dir(caster, pane) || pane_direction
	if(!(move_dir in GLOB.cardinals))
		caster.balloon_alert(caster, "square up to the glass!")
		return . | SPELL_CANCEL_CAST
	var/turf/destination
	if(pane.loc == caster.loc) // a border window on our own tile: step across it
		destination = get_step(caster, move_dir)
	else
		destination = get_turf(pane)
	if(!destination)
		return . | SPELL_CANCEL_CAST
	caster.visible_message(
		span_warning("[caster] presses flat against [pane]..."),
		span_notice("You press yourself against [pane] and start working your way into it."),
	)
	playsound(pane, 'sound/effects/glass/glassknock.ogg', 60, TRUE)
	phasing = TRUE
	var/finished_channel = do_after(caster, phase_time, target = pane)
	phasing = FALSE
	if(!finished_channel || QDELETED(src) || QDELETED(caster) || owner != caster)
		return . | SPELL_CANCEL_CAST
	if(QDELETED(pane) || !pane.density || pane.dir != pane_direction || !isturf(caster.loc) || !caster.Adjacent(pane))
		return . | SPELL_CANCEL_CAST
	var/turf/current_destination = pane.loc == caster.loc ? get_step(caster, get_dir(caster, pane) || pane.dir) : get_turf(pane)
	if(current_destination != destination)
		return . | SPELL_CANCEL_CAST
	// Live lattice is the hard counter, exactly as it is for the voidwalker
	for(var/obj/structure/grille/lattice in destination)
		if(lattice.is_shocked())
			caster.balloon_alert(caster, "the grille is live!")
			return . | SPELL_CANCEL_CAST
	// The step itself: PASSWINDOW crosses window and grille borders; any other dense thing still refuses
	passwindow_on(caster, REF(src))
	var/moved = caster.Move(destination)
	passwindow_off(caster, REF(src))
	if(!moved)
		caster.balloon_alert(caster, "something blocks the far side!")
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
		span_notice("You slide through [pane] and come out the other side."),
	)
