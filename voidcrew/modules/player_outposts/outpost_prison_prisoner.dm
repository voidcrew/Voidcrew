/**
 * # Outpost prisoner
 *
 * An inmate of a player outpost's prison wing (outpost_prison_core.dm). Each prisoner owns one
 * cell, beams into it on arrival and out of it on release, and fills the time in between with the
 * routine in outpost_prison_routine.dm. They talk (outpost_prison_dialogue.dm), and when unhappy
 * they threaten, fight, riot and escape (outpost_prison_trouble.dm, outpost_prison_riot.dm).
 *
 * Needs, on 0-100 scales: `hunger` falls over time and food restores it, by how good the food
 * is; `uniform_grime` rises over time, three times as fast at sport, and a cleaner prison uniform
 * resets it. Health does not come back on its own; brute medical stacks treat it. Arrivals come in
 * hungry, a third in a stained uniform and a fifth roughed up in transfer. A thought bubble with
 * the item they need shows when one needs attention, cycling when they need several. They bleed
 * when hit, and drip while badly hurt. They take supplies only from a serving hatch or from a
 * person's hand (outpost_prison_core.dm).
 *
 * Awake, they cannot be dragged onto things or boxed, and only a calm one (calm_for_pull()) can be
 * pulled, going along with it (outpost_prison_warden_tools.dm). Knocked down, in stamina crit,
 * cuffed or dead, staff can drag them; stamina crit lasts PRISONER_STAMCRIT_TIME after the last
 * hit. Cuffs and lockdown are in outpost_prison_capture.dm.
 */

/// Trait source for the beam holding a prisoner still
#define PRISONER_BEAM_TRAIT "outpost_prisoner_beam"
/// Offset source for sitting on a bed edge
#define PRISONER_SITTING_OFFSET "outpost_prisoner_sitting"

/mob/living/basic/outpost_prisoner
	name = "prisoner"
	desc = "An inmate of the outpost's prison wing."
	icon = 'icons/mob/simple/simple_human.dmi'
	unique_name = FALSE
	combat_mode = FALSE
	mob_biotypes = MOB_ORGANIC | MOB_HUMANOID
	sentience_type = SENTIENCE_HUMANOID
	maxHealth = 100
	health = 100
	speed = 2
	// Heavy while awake, so nobody shoves them about; see update_drag_resistance().
	move_resist = MOVE_FORCE_VERY_STRONG
	density = TRUE
	basic_mob_flags = NONE
	// tg's human deathgasp
	death_message = "seizes up and falls limp, their eyes dead and lifeless..."
	// They lie down on beds, when knocked down and when dead.
	mobility_flags = MOBILITY_FLAGS_REST_CAPABLE_DEFAULT
	rotate_on_lying = TRUE
	blood_volume = BLOOD_VOLUME_NORMAL
	// Batons knock them down, as they do people.
	status_flags = CANPUSH | CANSTUN | CANKNOCKDOWN
	stamina_regen_time = PRISONER_STAMCRIT_TIME
	// No air needs yet: a breach must not kill the inmates.
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	response_help_continuous = "pats"
	response_help_simple = "pat"
	ai_controller = /datum/ai_controller/basic_controller/outpost_prisoner

	/// The prison holding them
	var/datum/outpost_prison/prison
	/// The cell they own
	var/datum/outpost_prison_cell/cell
	/// PRISONER_ARRIVING, PRISONER_PRESENT or PRISONER_LEAVING
	var/phase = PRISONER_PRESENT
	/// A personality from the dialogue file; shapes what they do and say
	var/personality
	/// What they are in for
	var/crime
	/// 100 is full, 0 is empty
	var/hunger = 100
	/// How dirty the uniform they are wearing is, 0 to 100
	var/uniform_grime = 0
	/// Seconds of sentence left
	var/sentence_left = 0
	/// Seconds served, and the same seconds weighted by care x conditions, for the release bonus
	var/served_seconds = 0
	var/kept_seconds = 0
	/// Seconds spent bolted into a cell, without a break; step 3's mood will read this
	var/locked_in_seconds = 0
	/// Outfit whose look they wear
	var/outfit_path
	/// Which of the people wearing that outfit they look like (outpost_npc_looks.dm)
	var/look_number = 1
	/// The need their thought bubble is about, if any; see update_bubble()
	var/bubble
	/// The bubble that is up now, if one is; it pops up now and then rather than staying
	var/popped_bubble
	/// world.time the bubble next pops up
	var/bubble_next_pop = 0
	/// What draws the popped bubble, in their vis_contents while it is up, and the timer that takes it down
	var/obj/effect/abstract/outpost_thought/thought
	var/bubble_timer
	/// Which grime overlay they show: 0 none, 1 dirty, 2 filthy
	var/grime_stage = 0
	/// What they are carrying, held in their contents
	var/obj/item/held_item
	/// What they are holding a hand out for, one activity tick before they take it (see reach_for())
	var/datum/weakref/reaching_ref
	/// What they are doing now
	var/datum/prisoner_activity/activity
	/// The type of the last thing they did, so they vary it
	var/last_activity_type
	/// Activity types they gave up on, until world.time
	var/list/activity_cooldowns
	/// Tiles they can walk to (turf = TRUE), refreshed by the prison
	var/list/walkable
	/// Tiles they can walk to or reach into from one (turf = TRUE)
	var/list/reachable
	/// The last thing they said, so they don't repeat it at once
	var/last_line
	/// Whether they have said they are nearly out
	var/said_release_soon = FALSE
	/// Health at the last update, to notice treatment
	var/last_health = 100
	/// Seconds of "well fed" left after cooked food: hunger does not fall meanwhile
	var/well_fed_left = 0
	/// Came in wearing a stained transfer uniform
	var/arrived_stained = FALSE
	/// Brute damage they carry from transfer, applied when they beam in, and whether they came in hurt
	var/arrival_brute = 0
	var/arrived_hurt = FALSE
	/// Seconds the thought bubble has shown the current set of needs, for cycling through them
	var/bubble_clock = 0
	/// The needs the bubble cycles through, as text, so a change starts the cycle at the most urgent
	var/shown_needs = ""
	/// Who last fed, clothed or treated them by hand, and when (world.time)
	var/datum/weakref/last_carer_ref
	var/last_cared_at = 0
	/// world.time they last got the lift of a shared meal
	var/shared_meal_at = 0
	/// The criminal they were, when a bounty hunter caught them (outpost_prison_bounty.dm); null for an ordinary prisoner
	var/datum/bounty_record/bounty_record
	COOLDOWN_DECLARE(speech_cooldown)
	COOLDOWN_DECLARE(thanks_cooldown)
	/// Running while someone is putting a dressing on them
	COOLDOWN_DECLARE(treatment_window)
	/// Running after they tidied up, so they don't go round the yard doing it
	COOLDOWN_DECLARE(tidy_cooldown)
	/// Running after they asked for the medic
	COOLDOWN_DECLARE(sick_call_cooldown)
	/// Running while what they last said is up over their head: no thought bubble (hush_bubble())
	COOLDOWN_DECLARE(bubble_hush)

/mob/living/basic/outpost_prisoner/Initialize(mapload, datum/bounty_record/record)
	gender = pick(MALE, FEMALE)
	// A caught bounty criminal (admit_next()) keeps their body and who they were (outpost_prison_bounty.dm).
	bounty_record = record
	if(record)
		apply_bounty_body(record)
	. = ..()
	real_name = generate_random_name_species_based(gender, TRUE, /datum/species/human)
	name = real_name
	roll_arrival()
	var/list/personalities = outpost_prisoner_dialogue("personalities")
	personality = length(personalities) ? pick(personalities) : "quiet"
	var/list/crimes = outpost_prisoner_dialogue("crimes")
	crime = length(crimes) ? pick(crimes) : "unpaid docking fees"
	outfit_path = pick(/datum/outfit/outpost_prisoner, /datum/outfit/outpost_prisoner/glasses, /datum/outfit/outpost_prisoner/beanie)
	look_number = random_outpost_npc_look_number()
	if(record)
		apply_bounty_record(record)
	INVOKE_ASYNC(src, PROC_REF(build_look))
	// One shared list: element arguments are keyed by list reference.
	var/static/list/edible_types = list(/obj/item/food)
	AddElement(/datum/element/basic_eating, food_types = edible_types)
	AddElement(/datum/element/footstep, footstep_type = FOOTSTEP_MOB_SHOE)
	RegisterSignal(src, COMSIG_MOB_PRE_EAT, PROC_REF(on_pre_eat))
	RegisterSignal(src, COMSIG_MOB_ATE, PROC_REF(on_ate))
	RegisterSignal(src, COMSIG_ATOM_ITEM_INTERACTION, PROC_REF(on_item_interaction))
	RegisterSignal(src, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_damaged))
	RegisterSignal(src, COMSIG_LIVING_HEALTH_UPDATE, PROC_REF(on_health_update))
	// Talking puts the thought bubble away (manual_emote() below covers the prison's own emotes).
	RegisterSignals(src, list(COMSIG_MOB_SAY, COMSIG_MOB_EMOTE), PROC_REF(on_speech))
	// Dragging only while they are down or cuffed (can_be_dragged()); pulling also while calm (pull_allowed()).
	RegisterSignal(src, COMSIG_MOUSEDROP_ONTO, PROC_REF(block_being_dragged))
	RegisterSignal(src, COMSIG_ATOM_CAN_BE_PULLED, PROC_REF(check_pullable))
	// Changes to being down reach update_drag_resistance() through the living trait handlers
	// overridden below; registering those trait signals here would replace living's own.
	ADD_TRAIT(src, TRAIT_NO_CONTAINMENT, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_NO_STORAGE_INSERT, INNATE_TRAIT)
	setup_trouble()
	setup_containment()
	setup_extras()
	last_health = health

/mob/living/basic/outpost_prisoner/Destroy()
	end_activity(cancel_ai = FALSE)
	clear_trouble()
	if(held_item)
		held_item.forceMove(drop_location())
	remove_cuffs()
	prison?.forget(src)
	prison = null
	cell = null
	walkable = null
	reachable = null
	deltimer(bubble_timer)
	if(thought)
		vis_contents -= thought
		QDEL_NULL(thought)
	return ..()

/mob/living/basic/outpost_prisoner/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == held_item)
		held_item = null
		update_appearance(UPDATE_OVERLAYS)
	else if(gone == cuffs)
		// Cuffs taken or destroyed some other way than remove_cuffs()
		cuffs = null
		uncuffed()

/// Dresses them as their own person in their outfit, with a body to match their gender; a bounty prisoner keeps the face they were caught with (bounty_looks.dm). Can sleep.
/mob/living/basic/outpost_prisoner/proc/build_look()
	if(bounty_record)
		apply_bounty_look(src, bounty_record, outfit_path)
	else
		set_outpost_npc_look(src, outfit_path, gender, look_number)
	if(QDELETED(src))
		return
	update_appearance(UPDATE_OVERLAYS)

/**
 * How they come in: hungry, a third in a stained transfer uniform, a fifth roughed up in transfer.
 * The injury waits for beam_in(), so a prisoner made any other way (an admin, a test) starts whole.
 */
/mob/living/basic/outpost_prisoner/proc/roll_arrival()
	hunger = rand(PRISONER_ARRIVAL_HUNGER_MIN, PRISONER_ARRIVAL_HUNGER_MAX)
	arrived_stained = prob(PRISONER_STAINED_CHANCE)
	uniform_grime = arrived_stained ? rand(PRISONER_STAINED_GRIME_MIN, PRISONER_STAINED_GRIME_MAX) : rand(0, PRISONER_ARRIVAL_GRIME_MAX)
	arrival_brute = prob(PRISONER_HURT_ARRIVAL_CHANCE) ? round(maxHealth * (100 - rand(PRISONER_HURT_ARRIVAL_MIN, PRISONER_HURT_ARRIVAL_MAX)) / 100) : 0

/// Their first name, for dialogue. (Not called first_name(): inside it, that would call itself.)
/mob/living/basic/outpost_prisoner/proc/speech_name()
	return first_name(real_name)

// ===== BEAMING IN AND OUT =====

/**
 * Materialises them where they stand: beam_out() backwards. The column comes down and they knit
 * together inside it from nothing, from the feet up, over the whole beam. They stay
 * PRISONER_ARRIVING, and so do nothing at all (no walking, routine, trouble, speech or thought
 * bubble), until finish_beam_in() as the beam ends.
 */
/mob/living/basic/outpost_prisoner/proc/beam_in()
	phase = PRISONER_ARRIVING
	if(arrival_brute > 0)
		// Roughed up in transfer: no attacker, so no blame, no blood and no collapse.
		adjustBruteLoss(arrival_brute)
		arrival_brute = 0
		arrived_hurt = TRUE
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, PRISONER_BEAM_TRAIT)
	update_bubble()
	// A bubble ignores the knit: one already up would hang over an empty tile.
	drop_bubble()
	var/turf/spot = get_turf(src)
	if(spot)
		playsound(spot, 'sound/effects/magic/teleport_diss.ogg', 40, TRUE)
		new /obj/effect/temp_visual/transporter_beam(spot, OUTPOST_PRISON_BEAM_TIME + 0.5 SECONDS)
	// Hidden under the mask from the first frame. finish_beam_in() takes the effects off, so a
	// prisoner beamed out mid-knit keeps beam_out()'s.
	transporter_materialise(src, 255, OUTPOST_PRISON_BEAM_TIME, restore = FALSE)
	addtimer(CALLBACK(src, PROC_REF(finish_beam_in)), OUTPOST_PRISON_BEAM_TIME)

/// Fully there as the beam ends: the flash, and only now are they present, free to move, and say hello
/mob/living/basic/outpost_prisoner/proc/finish_beam_in()
	if(phase != PRISONER_ARRIVING)
		return
	var/turf/spot = get_turf(src)
	if(spot)
		new /obj/effect/temp_visual/transporter_flash(spot)
		transporter_sparks(spot)
		playsound(spot, 'sound/effects/magic/teleport_app.ogg', 50, TRUE)
	// Whatever is left of the knit, gone: they are solid from here on.
	transporter_restore(src, 255)
	phase = PRISONER_PRESENT
	REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, PRISONER_BEAM_TRAIT)
	update_bubble()
	// A bounty prisoner names the crew that caught them (outpost_prison_bounty.dm)
	if(bounty_arrival_speech())
		return
	// How they came in, if it shows; otherwise hello.
	if(arrived_hurt && say_context("arrival_hurt"))
		return
	if(arrived_stained && say_context("arrival_stained"))
		return
	say_context("arrival")

/**
 * Dematerialises them where they stand and deletes them at the end of the beam. From the start
 * they are PRISONER_LEAVING: held still, with no routine, trouble, speech or thought bubble.
 */
/mob/living/basic/outpost_prisoner/proc/beam_out()
	if(phase == PRISONER_LEAVING)
		return
	phase = PRISONER_LEAVING
	end_activity()
	clear_trouble()
	drop_held_item()
	remove_cuffs()
	stand_up()
	pulledby?.stop_pulling()
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, PRISONER_BEAM_TRAIT)
	update_bubble()
	drop_bubble()
	var/turf/spot = get_turf(src)
	if(spot)
		playsound(spot, 'sound/effects/magic/teleport_diss.ogg', 40, TRUE)
		new /obj/effect/temp_visual/transporter_beam(spot, OUTPOST_PRISON_BEAM_TIME + 0.5 SECONDS)
	new /obj/effect/abstract/particle_holder(src, /particles/transporter_motes, PARTICLE_ATTACH_MOB)
	transporter_dematerialise(src, OUTPOST_PRISON_BEAM_TIME)
	addtimer(CALLBACK(src, PROC_REF(finish_beam_out)), OUTPOST_PRISON_BEAM_TIME)

/mob/living/basic/outpost_prisoner/proc/finish_beam_out()
	var/turf/spot = get_turf(src)
	if(spot)
		new /obj/effect/temp_visual/transporter_flash/departure(spot)
		transporter_sparks(spot)
		playsound(spot, 'sound/effects/magic/teleport_app.ogg', 50, TRUE)
	qdel(src)

/// What the warden's roster calls them: present, arriving, leaving or dead
/mob/living/basic/outpost_prisoner/proc/console_status()
	if(stat == DEAD)
		return "dead"
	if(phase == PRISONER_ARRIVING)
		return "arriving"
	if(phase == PRISONER_LEAVING || sentence_left <= OUTPOST_PRISON_RELEASE_WALK)
		return "leaving"
	return "present"

// ===== DRAGGING =====

/// Whether they are down: knocked down, in stamina crit, beaten, out or dead
/mob/living/basic/outpost_prisoner/proc/is_down()
	// Floored but not buckled is on the floor; a bed floors them too, and that doesn't count.
	return stat != CONSCIOUS || HAS_TRAIT(src, TRAIT_INCAPACITATED) || (HAS_TRAIT(src, TRAIT_FLOORED) && !buckled)

/// Staff may drag them only while they are down or cuffed (outpost_prison_capture.dm)
/mob/living/basic/outpost_prisoner/proc/can_be_dragged()
	return is_down() || !!cuffs

/**
 * Calm enough to go along with a pull: awake, present, and in no trouble of their own (rioting,
 * loose, fighting, wrecking, squaring up, swinging, climbing, beaten down or hitting back).
 * Someone talking to them or working on their cuffs does not count.
 */
/mob/living/basic/outpost_prisoner/proc/calm_for_pull()
	return stat == CONSCIOUS && phase == PRISONER_PRESENT && !trouble && !threat_ref && !swing_ref && !climb_ref && beaten_left <= 0 && !retaliating()

/// Anyone may pull them while they are down or cuffed, or while they are calm
/mob/living/basic/outpost_prisoner/proc/pull_allowed()
	return can_be_dragged() || calm_for_pull()

/// Their move_resist: ordinary while they can be dragged or are going along with a pull, else too heavy to shove or pull
/mob/living/basic/outpost_prisoner/proc/pull_weight()
	return (can_be_dragged() || (pulledby && calm_for_pull())) ? MOVE_RESIST_DEFAULT : MOVE_FORCE_VERY_STRONG

/mob/living/basic/outpost_prisoner/proc/check_pullable(datum/source, mob/living/puller)
	SIGNAL_HANDLER
	return pull_allowed() ? NONE : COMSIG_ATOM_CANT_PULL

// Calm, they go along with a pull however heavy they are against shoves; pull_weight() lightens them once it has hold.
/mob/living/basic/outpost_prisoner/can_be_pulled(user, force)
	if(!can_be_dragged() && calm_for_pull())
		force = max(force, move_resist * MOVE_FORCE_PULL_RATIO)
	return ..(user, force)

/mob/living/basic/outpost_prisoner/proc/block_being_dragged(atom/over, mob/user)
	SIGNAL_HANDLER
	return can_be_dragged() ? NONE : COMPONENT_CANCEL_MOUSEDROP_ONTO

/mob/living/basic/outpost_prisoner/on_floored_trait_gain(datum/source)
	. = ..()
	update_drag_resistance()

/mob/living/basic/outpost_prisoner/on_floored_trait_loss(datum/source)
	. = ..()
	update_drag_resistance()

/mob/living/basic/outpost_prisoner/on_incapacitated_trait_gain(datum/source)
	. = ..()
	update_drag_resistance()

/mob/living/basic/outpost_prisoner/on_incapacitated_trait_loss(datum/source)
	. = ..()
	update_drag_resistance()

/mob/living/basic/outpost_prisoner/set_stat(new_stat)
	. = ..()
	update_drag_resistance()

/// Heavy while awake and free, so nobody shoves them about; ordinary while they are down or cuffed, or calm and being pulled
/mob/living/basic/outpost_prisoner/proc/update_drag_resistance()
	var/draggable = can_be_dragged()
	move_resist = pull_weight()
	if(!draggable)
		// A calm prisoner goes along with a pull (outpost_prison_warden_tools.dm); anyone else shakes it off.
		if(!calm_for_pull())
			pulledby?.stop_pulling()
		if(is_rioting() && stat == CONSCIOUS)
			// Up and free again: a rioter riots on until the riot is over.
			INVOKE_ASYNC(src, PROC_REF(back_to_rioting))
		return
	if(stat != DEAD && activity)
		// Knocked down or cuffed mid-activity: whatever they were doing is over.
		INVOKE_ASYNC(src, PROC_REF(end_activity))
	if(in_trouble())
		// Stunned, beaten, cuffed or dead: threats, climbs, fights and blows stop too.
		INVOKE_ASYNC(src, PROC_REF(on_downed))

// ===== NEEDS =====

/**
 * Time passing: hunger falls (not while well fed after cooked food) and the uniform gets dirtier,
 * three times as fast at sport, where they sometimes get hurt.
 */
/mob/living/basic/outpost_prisoner/proc/adjust_needs(seconds)
	if(stat == DEAD)
		return
	var/hungry_seconds = seconds
	if(well_fed_left > 0)
		var/paused = min(seconds, well_fed_left)
		well_fed_left -= paused
		hungry_seconds -= paused
	hunger = clamp(hunger - PRISONER_HUNGER_DECAY * hungry_seconds / 60, 0, 100)
	var/sport = playing_sport()
	var/grime_rate = PRISONER_GRIME_RATE * (sport ? PRISONER_GRIME_SPORT_MULT : 1)
	uniform_grime = clamp(uniform_grime + grime_rate * seconds / 60, 0, 100)
	bubble_clock += seconds
	update_bubble()
	if(sport && prob(PRISONER_SPORT_INJURY_CHANCE * seconds / 60))
		sport_injury()

/// Shooting hoops or working out: sweaty, and now and then painful
/mob/living/basic/outpost_prisoner/proc/playing_sport()
	if(!activity?.started)
		return FALSE
	if(istype(activity, /datum/prisoner_activity/basketball))
		return TRUE
	var/datum/prisoner_activity/pace/workout = activity
	return istype(workout) && workout.exercising

/**
 * Hurt at sport: a turned ankle or the ball in the face, PRISONER_SPORT_INJURY_MIN to _MAX brute,
 * and they stop playing. No attacker, so no blame and no blood. Never while already badly hurt,
 * and never enough to put them down.
 */
/mob/living/basic/outpost_prisoner/proc/sport_injury()
	if(stat != CONSCIOUS || health_factor() <= PRISONER_SPORT_INJURY_ABOVE)
		return FALSE
	var/damage = min(rand(PRISONER_SPORT_INJURY_MIN, PRISONER_SPORT_INJURY_MAX), health - 1)
	if(damage < 1)
		return FALSE
	if(istype(activity, /datum/prisoner_activity/basketball))
		manual_emote(pick("goes down clutching an ankle.", "takes the ball to the face.", "lands badly and hops off the court."))
	else
		manual_emote(pick("goes down clutching an ankle.", "pulls something and sits down hard.", "grabs at [p_their()] back mid push-up."))
	adjustBruteLoss(damage)
	end_activity()
	return TRUE

/mob/living/basic/outpost_prisoner/proc/set_hunger(amount)
	hunger = clamp(amount, 0, 100)
	update_bubble()

/mob/living/basic/outpost_prisoner/proc/set_uniform_grime(amount)
	uniform_grime = clamp(amount, 0, 100)
	update_bubble()

/// Fed, 0-100: full marks until they are hungry, then down to nothing once they are starving
/mob/living/basic/outpost_prisoner/proc/fed_factor()
	return clamp(100 * (hunger - PRISONER_HUNGER_STARVING) / (PRISONER_HUNGER_HUNGRY - PRISONER_HUNGER_STARVING), 0, 100)

/// Clean, 0-100: full marks until the uniform is dirty, then down to nothing once it is filthy
/mob/living/basic/outpost_prisoner/proc/clean_factor()
	return clamp(100 * (PRISONER_GRIME_FILTHY - uniform_grime) / (PRISONER_GRIME_FILTHY - PRISONER_GRIME_DIRTY), 0, 100)

/mob/living/basic/outpost_prisoner/proc/health_factor()
	return stat == DEAD ? 0 : clamp(100 * health / maxHealth, 0, 100)

/// Care, 0-100: the mean of fed, clean and health
/mob/living/basic/outpost_prisoner/proc/care()
	return (fed_factor() + clean_factor() + health_factor()) / 3

/// What their needs do to their mood per minute: list(gain, loss), before personality
/mob/living/basic/outpost_prisoner/proc/needs_mood_per_minute()
	var/loss = 0
	if(hunger < PRISONER_HUNGER_STARVING)
		loss += PRISONER_MOOD_STARVING
	else if(hunger < PRISONER_HUNGER_HUNGRY)
		loss += PRISONER_MOOD_HUNGRY
	if(uniform_grime >= PRISONER_GRIME_FILTHY)
		loss += PRISONER_MOOD_FILTHY
	else if(uniform_grime >= PRISONER_GRIME_DIRTY)
		loss += PRISONER_MOOD_DIRTY
	// Scrapes cost pay and show a bubble; only real injuries sour them.
	var/health_percent = health_factor()
	if(health_percent < PRISONER_HURT_MOOD_BELOW)
		loss += PRISONER_MOOD_HURT * (PRISONER_HURT_MOOD_BELOW - health_percent) / PRISONER_HURT_MOOD_BELOW
	return list(0, loss)

/mob/living/basic/outpost_prisoner/proc/wants_food()
	return stat == CONSCIOUS && hunger < PRISONER_HUNGER_SEEK && well_fed_left <= 0

/mob/living/basic/outpost_prisoner/proc/wants_clean_uniform()
	return stat == CONSCIOUS && uniform_grime >= PRISONER_GRIME_DIRTY

/// Whether they would take this off the floor or the hatch and change into it
/mob/living/basic/outpost_prisoner/proc/would_change_into(obj/item/thing)
	var/obj/item/clothing/under/rank/prisoner/outpost/fresh = thing
	return istype(fresh) && wants_clean_uniform() && fresh.grime < PRISONER_GRIME_DIRTY && fresh.grime < uniform_grime

// ===== THOUGHT BUBBLE =====

/// The needs that want attention now, most urgent first: hungry, hurt, dirty
/mob/living/basic/outpost_prisoner/proc/bubble_needs()
	var/list/needs = list()
	if(hunger < PRISONER_HUNGER_HUNGRY)
		needs += "hungry"
	if(health_factor() < PRISONER_INJURED_BELOW)
		needs += "hurt"
	if(uniform_grime >= PRISONER_GRIME_DIRTY)
		needs += "dirty"
	return needs

/**
 * The need their thought bubble shows, if any, and only when something needs attention. Rioting
 * or loose (a shiv) and being an experiment's subject (a syringe) show on their own. Otherwise it
 * cycles through their needs every PRISONER_BUBBLE_CYCLE, most urgent first.
 */
/mob/living/basic/outpost_prisoner/proc/wanted_bubble(list/needs)
	if(stat == DEAD || phase != PRISONER_PRESENT)
		return null
	if(is_rioting() || trouble == PRISONER_TROUBLE_LOOSE)
		return "riot"
	if(experiment_subject)
		return "experiment"
	if(isnull(needs))
		needs = bubble_needs()
	if(!length(needs))
		return null
	var/cycle_seconds = PRISONER_BUBBLE_CYCLE / (1 SECONDS)
	return needs[(round(bubble_clock / cycle_seconds) % length(needs)) + 1]

/**
 * Picks the bubble's need and the grime stage, redrawing only when the grime changes. A new set of needs
 * starts at the most urgent. The bubble itself pops up now and then (see schedule_bubble()); a need that
 * has just come up, a riot or a dose pops it soon.
 */
/mob/living/basic/outpost_prisoner/proc/update_bubble()
	var/list/needs = bubble_needs()
	var/needs_text = jointext(needs, ",")
	var/fresh = FALSE
	if(needs_text != shown_needs)
		fresh = length(needs - splittext(shown_needs, ",")) > 0
		shown_needs = needs_text
		bubble_clock = 0
	var/new_bubble = wanted_bubble(needs)
	if(new_bubble != bubble && (new_bubble == "riot" || new_bubble == "experiment"))
		fresh = TRUE
	bubble = new_bubble
	var/new_stage = 0
	if(stat != DEAD)
		if(uniform_grime >= PRISONER_GRIME_FILTHY)
			new_stage = 2
		else if(uniform_grime >= PRISONER_GRIME_DIRTY)
			new_stage = 1
	if(new_stage != grime_stage)
		grime_stage = new_stage
		update_appearance(UPDATE_OVERLAYS)
	schedule_bubble(needs, fresh)

/**
 * Pops the bubble when it is due, but not while what they last said is still up over their head
 * (hush_bubble()). One that no longer holds fades early, and a riot takes over at once.
 */
/mob/living/basic/outpost_prisoner/proc/schedule_bubble(list/needs, fresh)
	if(popped_bubble && popped_bubble != bubble && (!(popped_bubble in needs) || bubble == "riot"))
		fade_bubble()
	if(!bubble)
		return
	if(fresh)
		bubble_next_pop = min(bubble_next_pop, world.time + rand(0, PRISONER_BUBBLE_FRESH_DELAY))
	if(!popped_bubble && world.time >= bubble_next_pop && COOLDOWN_FINISHED(src, bubble_hush))
		pop_bubble()

/// They said or emoted something: see hush_bubble()
/mob/living/basic/outpost_prisoner/proc/on_speech(datum/source)
	SIGNAL_HANDLER
	hush_bubble()

/mob/living/basic/outpost_prisoner/manual_emote(text)
	. = ..()
	if(.)
		hush_bubble()

/**
 * Their words go up in runechat over their head for PRISONER_BUBBLE_HUSH. A bubble that is up
 * sinks away out of the text's way, and none pops until the words are gone; then a need that
 * still holds comes back within PRISONER_BUBBLE_FRESH_DELAY.
 */
/mob/living/basic/outpost_prisoner/proc/hush_bubble()
	COOLDOWN_START(src, bubble_hush, PRISONER_BUBBLE_HUSH)
	if(!popped_bubble)
		return
	fade_bubble(sink = TRUE)
	bubble_next_pop = min(bubble_next_pop, world.time + PRISONER_BUBBLE_HUSH + rand(0, PRISONER_BUBBLE_FRESH_DELAY))

/// Pops the bubble up with a little bounce; it bobs, then fades on its own
/mob/living/basic/outpost_prisoner/proc/pop_bubble()
	if(!bubble || QDELETED(src))
		return
	popped_bubble = bubble
	var/gap = bubble == "riot" ? rand(PRISONER_BUBBLE_RIOT_GAP_MIN, PRISONER_BUBBLE_RIOT_GAP_MAX) : rand(PRISONER_BUBBLE_GAP_MIN, PRISONER_BUBBLE_GAP_MAX)
	bubble_next_pop = world.time + PRISONER_BUBBLE_SHOW + PRISONER_BUBBLE_FADE + gap
	if(!thought)
		thought = new(null)
	thought.pop(bubble, src)
	vis_contents |= thought
	deltimer(bubble_timer)
	bubble_timer = addtimer(CALLBACK(src, PROC_REF(end_bubble)), PRISONER_BUBBLE_SHOW + PRISONER_BUBBLE_FADE, TIMER_STOPPABLE | TIMER_DELETE_ME)

/// Fades the bubble out early, sinking with `sink` (see /obj/effect/abstract/outpost_thought/proc/fade())
/mob/living/basic/outpost_prisoner/proc/fade_bubble(sink = FALSE)
	popped_bubble = null
	if(!thought)
		return
	thought.fade(sink)
	deltimer(bubble_timer)
	bubble_timer = addtimer(CALLBACK(src, PROC_REF(end_bubble)), PRISONER_BUBBLE_FADE, TIMER_STOPPABLE | TIMER_DELETE_ME)

/// Takes the faded bubble down
/mob/living/basic/outpost_prisoner/proc/end_bubble()
	bubble_timer = null
	popped_bubble = null
	if(thought)
		vis_contents -= thought

/// Takes any bubble down at once, with no fade: for when they beam in or out
/mob/living/basic/outpost_prisoner/proc/drop_bubble()
	deltimer(bubble_timer)
	end_bubble()

/mob/living/basic/outpost_prisoner/update_overlays()
	. = ..()
	if(grime_stage)
		var/mutable_appearance/grime = mutable_appearance('icons/effects/blood.dmi', "uniformblood")
		grime.color = "#5a4630"
		grime.alpha = grime_stage == 2 ? 200 : 130
		. += grime
	if(grime_stage == 2)
		. += mutable_appearance('icons/effects/effects.dmi', "fly-surrounding", ABOVE_MOB_LAYER)
	if(cuffs)
		// tg's own cuff overlay, as people wear it
		. += mutable_appearance('icons/mob/simple/mob.dmi', "handcuff1")
	if(held_item)
		// In hand the way a player holds it, turning with them (npc_inhand_look() in bounty_ai.dm)
		var/list/inhand = npc_inhand_look(held_item)
		if(inhand)
			var/mutable_appearance/carried = mutable_appearance(inhand[1], inhand[2])
			carried.plane = FLOAT_PLANE
			carried.layer = FLOAT_LAYER
			. += carried
		else
			// No in-hand sprite: the item itself, small, in the same hand whichever way they face
			var/mutable_appearance/carried = new(held_item.appearance)
			carried.plane = FLOAT_PLANE
			carried.layer = FLOAT_LAYER
			carried.dir = SOUTH
			carried.pixel_x = 0
			carried.pixel_y = 0
			carried.pixel_w = ((dir & WEST) || dir == NORTH) ? -7 : 7
			carried.pixel_z = -4
			carried.transform = matrix().Scale(0.6)
			. += carried

/// Turning moves what they carry to the other side
/mob/living/basic/outpost_prisoner/setDir(newdir)
	var/old_dir = dir
	. = ..()
	if(held_item && dir != old_dir)
		update_appearance(UPDATE_OVERLAYS)

/**
 * tg's thought bubble, as a point uses, with the needed item's own sprite inset. A prisoner's pops up
 * now and then through their vis_contents, so it animates apart from them.
 *
 * It sits over their head, a little to the right. At 0.85 scale it is 27 pixels across, from 29 to
 * 55 pixels up and 10 to 36 across, its trailing dots on top of their head. tg's runechat starts 32
 * pixels up and draws on RUNECHAT_PLANE, above this POINT_PLANE, so what they say would hide it;
 * it is never up while they talk (hush_bubble()).
 */
/obj/effect/abstract/outpost_thought
	name = "thought"
	icon = 'icons/effects/effects.dmi'
	icon_state = "thought_bubble"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	appearance_flags = KEEP_APART | RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM | PIXEL_SCALE
	vis_flags = NONE
	plane = POINT_PLANE
	// Over their head, a little to the right, its trailing dots on top of it
	pixel_w = 8
	pixel_z = 26
	alpha = 0
	/// Size and height it settles at; it bobs 2 pixels above that
	var/rest_scale = 0.85
	var/rest_z = 26

/// Shows a need's item and bounces up: it grows past full size, settles, bobs and fades
/obj/effect/abstract/outpost_thought/proc/pop(need, atom/movable/owner)
	overlays.Cut()
	var/mutable_appearance/item_look = outpost_prisoner_bubble_item(need)
	if(item_look)
		var/mutable_appearance/inset = new(item_look)
		inset.blend_mode = BLEND_INSET_OVERLAY
		inset.plane = FLOAT_PLANE
		inset.layer = FLOAT_LAYER
		inset.dir = SOUTH
		inset.pixel_x = 0
		inset.pixel_y = 0
		inset.pixel_w = 0
		inset.pixel_z = 0
		overlays += inset
	SET_PLANE_EXPLICIT(src, POINT_PLANE, owner)
	alpha = 0
	pixel_z = rest_z - 6
	transform = matrix().Scale(rest_scale * 0.3)
	var/bob = max(1, (PRISONER_BUBBLE_SHOW - 0.5 SECONDS) / 2)
	animate(src, alpha = 230, pixel_z = rest_z, transform = matrix().Scale(rest_scale * 1.15), time = 0.3 SECONDS, easing = BACK_EASING | EASE_OUT)
	animate(transform = matrix().Scale(rest_scale), time = 0.2 SECONDS, easing = SINE_EASING)
	animate(pixel_z = rest_z + 2, time = bob, easing = SINE_EASING)
	animate(pixel_z = rest_z, time = bob, easing = SINE_EASING)
	animate(alpha = 0, pixel_z = rest_z + 5, transform = matrix().Scale(rest_scale * 0.8), time = PRISONER_BUBBLE_FADE, easing = SINE_EASING | EASE_IN)

/// Fades out from wherever it is, drifting up, or with `sink`, down out of the way of what they are saying
/obj/effect/abstract/outpost_thought/proc/fade(sink = FALSE)
	animate(src, alpha = 0, pixel_z = rest_z + (sink ? -4 : 5), transform = matrix().Scale(rest_scale * 0.8), time = PRISONER_BUBBLE_FADE, easing = SINE_EASING | EASE_IN)

/// The item a thought bubble shows for a need
/proc/outpost_prisoner_bubble_item_type(need)
	switch(need)
		if("hungry")
			return /obj/item/food/burger/plain
		if("dirty")
			return /obj/item/clothing/under/rank/prisoner
		if("hurt")
			return /obj/item/stack/medical/bruise_pack
		if("riot")
			return /obj/item/knife/shiv
		if("experiment")
			return /obj/item/reagent_containers/syringe
	return null

/// The look of a need's item, copied once from a real one so greyscale items come out right
/proc/outpost_prisoner_bubble_item(need)
	var/static/list/looks = list()
	if(looks[need])
		return looks[need]
	var/item_type = outpost_prisoner_bubble_item_type(need)
	if(!item_type)
		return null
	var/obj/item/sample = new item_type(null)
	var/mutable_appearance/look = new(sample.appearance)
	qdel(sample)
	looks[need] = look
	return look

// ===== HANDS =====

/**
 * Picks up `thing` and carries it. Only within arm's reach: on their own tile or beside them (and
 * through an open window door, for a serving hatch), or in something or someone beside them. They
 * turn to it, lean in, and it visibly goes into their hand. With `announce`, the room is told what
 * they took and from where. Returns TRUE if they hold it.
 */
/mob/living/basic/outpost_prisoner/proc/take_item(obj/item/thing, announce = FALSE)
	if(held_item || QDELETED(thing))
		return FALSE
	if(thing.loc != src)
		var/turf/from = get_turf(thing)
		// Never from further off: nothing flies into their hand.
		if(!from || get_dist(src, from) > 1)
			return FALSE
		if(isturf(thing.loc) && thing.loc != loc && !Adjacent(thing))
			return FALSE
		face_atom(thing)
		if(from != loc)
			reach_animation(from)
		thing.do_pickup_animation(src, from)
		if(announce)
			var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in from
			var/message = hatch ? "[src] takes [thing] off [hatch]." : "[src] picks up [thing]."
			visible_message(span_notice(message))
	thing.forceMove(src)
	if(thing.loc != src)
		return FALSE
	held_item = thing
	update_appearance(UPDATE_OVERLAYS)
	return TRUE

/// Leans towards `target` for a moment, as a hand goes out to it
/mob/living/basic/outpost_prisoner/proc/reach_animation(atom/target)
	var/direction = get_dir(src, target)
	if(!direction)
		return
	var/shift_x = (direction & EAST) ? 4 : ((direction & WEST) ? -4 : 0)
	var/shift_y = (direction & NORTH) ? 4 : ((direction & SOUTH) ? -4 : 0)
	animate(src, pixel_x = pixel_x + shift_x, pixel_y = pixel_y + shift_y, time = 1, easing = SINE_EASING, flags = ANIMATION_PARALLEL)
	animate(pixel_x = pixel_x - shift_x, pixel_y = pixel_y - shift_y, time = 2, easing = SINE_EASING, flags = ANIMATION_PARALLEL)

/// Puts down whatever they carry, on `where` or their own tile
/mob/living/basic/outpost_prisoner/proc/drop_held_item(atom/where)
	if(!held_item)
		return null
	var/obj/item/dropped = held_item
	dropped.forceMove(where || drop_location())
	return dropped

/**
 * Whether they can reach `thing` from where they stand. At a serving hatch they open their side
 * first: PRISONER_REACH_WAIT means it is opening.
 */
/mob/living/basic/outpost_prisoner/proc/try_reach(obj/item/thing)
	if(QDELETED(thing) || !isturf(thing.loc))
		return PRISONER_REACH_FAILED
	if(thing.loc == loc)
		return PRISONER_REACH_OK
	if(get_dist(src, thing) > 1)
		return PRISONER_REACH_FAILED
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in thing.loc
	if(hatch && !hatch.open_for_prisoner(src))
		var/obj/machinery/door/window/yard_door = hatch.yard_windoor()
		return (yard_door?.operating || yard_door?.hasPower()) ? PRISONER_REACH_WAIT : PRISONER_REACH_FAILED
	return Adjacent(thing) ? PRISONER_REACH_OK : PRISONER_REACH_FAILED

/**
 * An activity reaching for `thing` where they stand, as try_reach() does, but never in one go: the
 * first time it is in reach they turn to it and hold out a hand (PRISONER_REACH_WAIT), and only on
 * the next call, about a second later, is it PRISONER_REACH_OK to take it.
 */
/mob/living/basic/outpost_prisoner/proc/reach_for(obj/item/thing)
	var/result = try_reach(thing)
	if(result != PRISONER_REACH_OK)
		reaching_ref = null
		return result
	face_atom(thing)
	if(reaching_ref?.resolve() == thing)
		reaching_ref = null
		return PRISONER_REACH_OK
	reaching_ref = WEAKREF(thing)
	return PRISONER_REACH_WAIT

/// Sits on a chair, stool or toilet, facing `facing` if given
/mob/living/basic/outpost_prisoner/proc/sit_on(obj/structure/seat, facing)
	if(buckled != seat)
		if(loc != seat.loc)
			return FALSE
		stand_up()
		if(!seat.buckle_mob(src, force = TRUE))
			return FALSE
	if(facing)
		setDir(facing)
	return TRUE

/// Gets up from whatever they sit or lie on
/mob/living/basic/outpost_prisoner/proc/stand_up()
	remove_offsets(PRISONER_SITTING_OFFSET)
	buckled?.unbuckle_mob(src, force = TRUE)

/**
 * Settles on the bed under them. There is no sitting pose for a bed, and a standing sprite shifted down
 * reads as someone standing on it, so they lie on it, awake. With no bed to lie on, they crouch.
 */
/mob/living/basic/outpost_prisoner/proc/sit_on_edge(facing)
	var/obj/structure/bed/bed = locate() in loc
	if(bed && buckled != bed)
		stand_up()
		bed.buckle_mob(src, force = TRUE)
	if(!buckled)
		add_offsets(PRISONER_SITTING_OFFSET, y_add = -4)
	if(facing)
		setDir(facing)

/// Whether they crouch where they are, as sit_on_edge() leaves them with no bed under them
/mob/living/basic/outpost_prisoner/proc/is_crouching()
	return !!has_offset(PRISONER_SITTING_OFFSET)

/**
 * Sits down where they stand in their cell: in the chair under them if nobody else is in it, else
 * on the bed under them (lying on it, see sit_on_edge()), else crouching. In a chair they face the
 * way it faces; `facing` is for the bed and the crouch. The bed is for lying down, so any sitting in
 * the cell goes to the chair first (home_seat()).
 */
/mob/living/basic/outpost_prisoner/proc/sit_in_cell(facing)
	var/obj/structure/chair/chair = locate() in loc
	if(chair && (buckled == chair || !chair.has_buckled_mobs()) && sit_on(chair))
		return
	sit_on_edge(facing)

/**
 * Where they sit down in their own cell: its chair if they can use it (seat_usable()), else its bed
 * on the same terms, lying on it. Null if the cell has neither they can use.
 */
/mob/living/basic/outpost_prisoner/proc/home_seat()
	if(!cell)
		return null
	var/obj/structure/chair/chair = cell.chair()
	if(chair && seat_usable(chair))
		return chair
	var/obj/structure/bed/bed = cell.bed()
	if(bed && seat_usable(bed))
		return bed
	return null

/// Whether they can walk to `seat` and use it: nobody else on its tile or in it, and nobody else has claimed it
/mob/living/basic/outpost_prisoner/proc/seat_usable(obj/structure/seat)
	var/turf/tile = get_turf(seat)
	if(!tile || !walkable?[tile] || (tile != loc && tile_taken(tile)))
		return FALSE
	if(seat.has_buckled_mobs() && !(src in seat.buckled_mobs))
		return FALSE
	return !prison?.claimed_by_other(seat, src)

// ===== FOOD =====

/**
 * How good a piece of food is: "ration" (the prison's own, and the Sustenance Vendor's tofu and
 * candy corn), "cooked" (anything from a real recipe), "snack" (simple food and junk food) or
 * "poor" (raw, rotten, poisonous or plain produce, and the vendor's moldy bread).
 */
/proc/outpost_prisoner_food_tier(obj/item/food/meal)
	var/static/list/ration_types = typecacheof(list(
		/obj/item/food/prison_ration,
		/obj/item/food/tofu/prison,
		/obj/item/food/candy_corn/prison,
	))
	if(is_type_in_typecache(meal, ration_types))
		return "ration"
	if(!istype(meal) || (meal.foodtypes & (RAW | GROSS | TOXIC)))
		return "poor"
	// Junk food is a snack however much went into it.
	if(meal.foodtypes & JUNKFOOD)
		return "snack"
	if(meal.crafting_complexity >= FOOD_COMPLEXITY_2)
		return "cooked"
	if(meal.crafting_complexity >= FOOD_COMPLEXITY_1)
		return "snack"
	return "poor"

/mob/living/basic/outpost_prisoner/proc/on_pre_eat(datum/source, atom/food, mob/living/feeder)
	SIGNAL_HANDLER
	if(cuffs)
		if(feeder)
			balloon_alert(feeder, "cuffed")
		return COMSIG_MOB_CANCEL_EAT
	if(prison?.pastime_pre_eat(src, food, feeder))
		return COMSIG_MOB_CANCEL_EAT
	if(stat != CONSCIOUS || phase != PRISONER_PRESENT || hunger >= PRISONER_HUNGER_FULL || well_fed_left > 0)
		if(feeder)
			balloon_alert(feeder, "not hungry")
		return COMSIG_MOB_CANCEL_EAT
	return NONE

/**
 * Eats `meal`: hunger and mood by how good it is, and cooked food keeps them full for
 * PRISONER_WELL_FED_TIME. Returns the tier.
 */
/mob/living/basic/outpost_prisoner/proc/eat_food(obj/item/food/meal)
	var/tier = outpost_prisoner_food_tier(meal)
	switch(tier)
		if("ration")
			set_hunger(hunger + PRISONER_FOOD_RATION)
			adjust_mood(PRISONER_MOOD_FED)
		if("cooked")
			set_hunger(hunger + PRISONER_FOOD_COOKED)
			adjust_mood(PRISONER_MOOD_FED_COOKED)
			well_fed_left = PRISONER_WELL_FED_TIME / (1 SECONDS)
		if("snack")
			set_hunger(hunger + PRISONER_FOOD_SNACK)
			adjust_mood(PRISONER_MOOD_FED_SNACK)
		else
			set_hunger(hunger + PRISONER_FOOD_POOR)
	return tier

/// What they say about a meal: praise for cooking, a complaint about poor food, else thanks to whoever fed them
/mob/living/basic/outpost_prisoner/proc/react_to_food(tier, mob/living/feeder)
	switch(tier)
		if("cooked")
			if(thank("good_food") || !feeder)
				return
		if("poor")
			say_context("poor_food")
			return
	if(feeder)
		thank("thanks_food")

/// Fed by hand
/mob/living/basic/outpost_prisoner/proc/on_ate(datum/source, atom/food, mob/living/feeder)
	SIGNAL_HANDLER
	var/tier = eat_food(food)
	if(isturf(loc) && prob(50))
		new /obj/effect/decal/cleanable/food/crumbs(loc)
	if(feeder)
		note_carer(feeder)
	INVOKE_ASYNC(src, PROC_REF(react_to_food), tier, feeder)

/**
 * Finishes a meal: crumbs where they sat and, often, the wrapper or a tray (see leave_meal_mess()).
 * `table_turf` is null when they ate standing up. Returns the wrapper when they mean to take it
 * to the bin, else null.
 */
/mob/living/basic/outpost_prisoner/proc/finish_meal(obj/item/food/meal, turf/seat_turf, turf/table_turf)
	if(QDELETED(meal))
		return null
	var/tier = eat_food(meal)
	playsound(src, 'sound/items/eatfood.ogg', 30, TRUE)
	visible_message(span_notice("[src] finishes [meal]."))
	var/obj/item/trash = leave_meal_mess(meal, seat_turf || get_turf(src), table_turf)
	qdel(meal)
	if(tier == "cooked" || tier == "poor")
		INVOKE_ASYNC(src, PROC_REF(react_to_food), tier, null)
	return trash

/**
 * What a meal leaves: crumbs (half the time at a table, always standing up) and often the food's
 * wrapper or a tray. A content prisoner (PRISONER_BIN_MOOD) usually means to bin it, and the
 * wrapper is returned for them to carry there; if the bin is full they say so and leave it. An
 * unhappy one (below PRISONER_LITTER_MOOD) drops it on the floor; anyone else leaves it where
 * they ate.
 */
/mob/living/basic/outpost_prisoner/proc/leave_meal_mess(obj/item/food/meal, turf/floor, turf/table_turf)
	if(isopenturf(floor) && (!table_turf || prob(PRISONER_TABLE_CRUMB_CHANCE)))
		new /obj/effect/decal/cleanable/food/crumbs(floor)
	var/trash_type
	if(meal?.trash_type && prob(75))
		trash_type = meal.trash_type
	else if(table_turf && prob(40))
		trash_type = /obj/item/trash/tray
	if(!ispath(trash_type, /obj/item))
		return null
	var/turf/drop = table_turf || floor
	if(mood < PRISONER_LITTER_MOOD && isopenturf(floor))
		drop = floor
	if(!drop)
		return null
	var/obj/item/trash = new trash_type(drop)
	if(mood < PRISONER_BIN_MOOD || !prob(PRISONER_BIN_CHANCE))
		return null
	var/obj/structure/closet/crate/bin/bin = prison?.find_bin(src)
	if(!bin)
		return null
	if(!outpost_bin_has_room(bin))
		INVOKE_ASYNC(src, PROC_REF(say_context), "bin_full")
		return null
	return trash

/// Puts `trash` in `bin` (or the nearest bin in reach) straight away. Returns TRUE if it went in.
/mob/living/basic/outpost_prisoner/proc/bin_litter(obj/item/trash, obj/structure/closet/crate/bin/bin)
	if(QDELETED(trash))
		return FALSE
	bin = bin || prison?.find_bin(src)
	if(!bin || !outpost_bin_has_room(bin))
		return FALSE
	if(trash == held_item)
		drop_held_item(get_turf(bin))
	if(bin.opened)
		trash.forceMove(get_turf(bin))
	else if(bin.insert(trash) != TRUE)
		return FALSE
	face_atom(bin)
	bin.do_animate()
	return TRUE

/// Whether a trash bin can take another piece
/proc/outpost_bin_has_room(obj/structure/closet/crate/bin/bin)
	if(QDELETED(bin))
		return FALSE
	if(!bin.opened)
		return length(bin.contents) < bin.storage_capacity
	var/count = 0
	for(var/obj/item/thing in get_turf(bin))
		count++
	return count < bin.storage_capacity

/// Someone fed, clothed or treated them by hand
/mob/living/basic/outpost_prisoner/proc/note_carer(mob/living/carer)
	if(!istype(carer) || is_outpost_prisoner(carer))
		return
	last_carer_ref = WEAKREF(carer)
	last_cared_at = world.time
	prison?.note_staff_care(carer, src)

// ===== UNIFORMS =====

/// Cuffs go on them (outpost_prison_capture.dm); handed a cleaner prison uniform, they change and hand the old one back
/mob/living/basic/outpost_prisoner/proc/on_item_interaction(datum/source, mob/living/user, obj/item/tool, list/modifiers)
	SIGNAL_HANDLER
	if(istype(tool, /obj/item/restraints/handcuffs))
		return on_cuffs_used(user, tool)
	if(istype(tool, /obj/item/stack/medical))
		// Treatment only shows as health coming back once the dressing is on.
		COOLDOWN_START(src, treatment_window, 20 SECONDS)
		note_carer(user)
		return NONE
	var/obj/item/clothing/under/rank/prisoner/outpost/offered = tool
	// Not while they beam in or out, invisible or half there.
	if(!istype(offered) || user.combat_mode || stat != CONSCIOUS || phase != PRISONER_PRESENT)
		return NONE
	if(cuffs)
		balloon_alert(user, "cuffed")
		return ITEM_INTERACT_BLOCKING
	if(offered.grime >= uniform_grime)
		balloon_alert(user, "no cleaner than theirs")
		return ITEM_INTERACT_BLOCKING
	if(!user.temporarilyRemoveItemFromInventory(offered))
		return ITEM_INTERACT_BLOCKING
	var/obj/item/clothing/under/rank/prisoner/outpost/old = swap_uniform(offered, drop_location())
	note_carer(user)
	// put_in_hands() can sleep (stack merging), which a signal handler must not.
	INVOKE_ASYNC(user, TYPE_PROC_REF(/mob, put_in_hands), old)
	visible_message(span_notice("[src] changes into the clean jumpsuit and hands [user] the old one."))
	INVOKE_ASYNC(src, PROC_REF(thank), "thanks_uniform")
	return ITEM_INTERACT_SUCCESS

/**
 * Picks up a cleaner uniform within arm's reach (their own tile or beside them) and changes, leaving
 * the old one in its place. They turn to it, lean in, and it visibly leaves the floor or the hatch.
 */
/mob/living/basic/outpost_prisoner/proc/take_uniform(obj/item/clothing/under/rank/prisoner/outpost/fresh)
	if(!would_change_into(fresh) || !isturf(fresh.loc) || !(fresh.loc == loc || Adjacent(fresh)))
		return FALSE
	var/turf/spot = fresh.loc
	face_atom(fresh)
	if(spot != loc)
		reach_animation(spot)
	fresh.do_pickup_animation(src, spot)
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in spot
	var/message = hatch ? "[src] takes a clean jumpsuit off [hatch], changes into it and leaves the old one there." : "[src] changes into a clean jumpsuit and leaves the old one behind."
	swap_uniform(fresh, spot)
	visible_message(span_notice(message))
	return TRUE

/**
 * Changes into `fresh` and returns their old uniform, created at `drop_spot`. The clean one goes
 * before the old one appears, so a swap on a full serving hatch never pushes it over capacity.
 */
/mob/living/basic/outpost_prisoner/proc/swap_uniform(obj/item/clothing/under/rank/prisoner/outpost/fresh, atom/drop_spot)
	var/fresh_grime = fresh.grime
	var/old_grime = uniform_grime
	qdel(fresh)
	var/obj/item/clothing/under/rank/prisoner/outpost/old = new(drop_spot)
	old.set_grime(old_grime)
	set_uniform_grime(fresh_grime)
	adjust_mood(PRISONER_MOOD_CLEAN_UNIFORM)
	return old

// ===== HURT AND TREATED =====

/// Blood on the floor from any real brute hit
/mob/living/basic/outpost_prisoner/proc/on_damaged(datum/source, damage_dealt, damagetype)
	SIGNAL_HANDLER
	if((damagetype == BRUTE || damagetype == BURN) && damage_dealt > 0)
		// Low enough and they collapse (outpost_prison_trouble.dm).
		INVOKE_ASYNC(src, PROC_REF(check_beaten))
	if(damagetype != BRUTE || damage_dealt < 3 || !isturf(loc))
		return
	add_splatter_floor(loc, damage_dealt < 10)

/mob/living/basic/outpost_prisoner/proc/on_health_update(datum/source)
	SIGNAL_HANDLER
	var/was = last_health
	last_health = health
	update_bubble()
	if(health > was && stat == CONSCIOUS && !COOLDOWN_FINISHED(src, treatment_window))
		COOLDOWN_RESET(src, treatment_window)
		adjust_mood(PRISONER_MOOD_TREATED)
		INVOKE_ASYNC(src, PROC_REF(thank), "thanks_treatment")

/// Badly hurt and untreated: now and then a drop of blood
/mob/living/basic/outpost_prisoner/proc/maybe_drip(seconds)
	if(stat == DEAD || !isturf(loc) || health_factor() >= PRISONER_BLEED_BELOW)
		return FALSE
	if(!SPT_PROB(3, seconds))
		return FALSE
	add_splatter_floor(loc, small_drip = TRUE)
	return TRUE

// ===== LEFT ALONE =====

/**
 * tg AI sleeps while no player is on the level, but hunger and grime keep ticking. So with nobody
 * on the level, a prisoner who is up and free helps themself to food and clean uniforms on a
 * serving hatch they could walk to, or food they carry, without the walk: nobody is there to see
 * it. Called every few seconds by the prison. With anyone on the level, and that includes the
 * moments tg switches the AI off after a plan that queued nothing (ai_running()), they walk over
 * and take things by hand instead.
 */
/mob/living/basic/outpost_prisoner/proc/fend_for_self()
	if(!routine_allowed() || ai_running())
		return
	if(wants_food())
		// A held cake saved for a party is not a meal (outpost_prison_pastimes.dm).
		var/obj/item/food/meal = (istype(held_item, /obj/item/food) && !prison.reserved_supply(held_item, src)) ? held_item : prison.find_supply(src)
		if(meal)
			var/obj/item/trash = finish_meal(meal, get_turf(src), null)
			if(trash)
				bin_litter(trash)
	if(wants_clean_uniform())
		var/obj/item/clothing/under/rank/prisoner/outpost/fresh = prison.find_supply(src, TRUE)
		if(fresh && isturf(fresh.loc))
			swap_uniform(fresh, fresh.loc)

/// Leaves some dirt or a wrapper where they stand
/mob/living/basic/outpost_prisoner/proc/make_mess()
	var/turf/open/floor = loc
	if(!istype(floor))
		return
	if(prob(75))
		new /obj/effect/decal/cleanable/dirt(floor)
	else
		var/trash_type = pick(/obj/item/trash/candy, /obj/item/trash/chips, /obj/item/trash/raisins)
		new trash_type(floor)

/mob/living/basic/outpost_prisoner/death(gibbed)
	var/was_alive = stat != DEAD
	. = ..()
	if(was_alive && stat == DEAD)
		end_activity()
		drop_held_item()
		remove_cuffs()
		prison?.on_prisoner_death(src)
		update_bubble()

// ===== LOOK =====

/datum/outfit/outpost_prisoner
	name = "Outpost prisoner"
	uniform = /obj/item/clothing/under/rank/prisoner
	shoes = /obj/item/clothing/shoes/sneakers/orange

/datum/outfit/outpost_prisoner/glasses
	name = "Outpost prisoner (glasses)"
	glasses = /obj/item/clothing/glasses/regular

/datum/outfit/outpost_prisoner/beanie
	name = "Outpost prisoner (beanie)"
	head = /obj/item/clothing/head/beanie/orange

#undef PRISONER_BEAM_TRAIT
#undef PRISONER_SITTING_OFFSET
