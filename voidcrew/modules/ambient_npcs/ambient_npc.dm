/**
 * # World population: the base NPC
 *
 * Owner: P0 seams (frozen). Packages subtype /mob/living/basic/ambient_npc in their own files and
 * override the procs marked "Override" below; they never edit this file.
 *
 * What every ambient NPC gets (spec 2.2, 2.3, 2.5):
 * - a look: a random person in their outfit (outpost_npc_looks.dm), with working looks when they
 *   do work at objects;
 * - protections: no dragging (a body neither), buckling, closets, crates or bags; no teleports,
 *   polymorph or type change; SENTIENCE_HUMANOID (sentience, transference and lazarus refuse them);
 *   immune to air, cold, heat and weather damage; a leash they walk back to, or fade from;
 * - killable: a body lies down and drops a little cash (and any `death_loot`) once, never again
 *   after a revive; at a trader outpost, hurting one is violence there (the outpost's strikes, and
 *   everyone near ducks), and turrets never shoot them (FACTION_TURRET while they belong to it);
 * - a passive AI: no targeting subtree, so outpost turrets never read them as wild hostiles;
 * - dialogue from a JSON file with per-NPC and per-place cooldowns, replies to other NPCs, and an
 *   answer for a player who talks to them (an empty hand);
 * - reactions: being attacked, a fight at their outpost, the kingpin's shootout, a storm, the convoy.
 *
 * The routine (what they do from moment to moment) is in ambient_activity.dm.
 */

/// What a hauling worker's carried look shows in hand
#define AMBIENT_CARRY_LOOK /obj/item/delivery/big

/mob/living/basic/ambient_npc/Initialize(mapload)
	if(random_gender)
		gender = pick(MALE, FEMALE)
	if(length(outfit_choices))
		outfit = pick(outfit_choices)
	if(isnull(look_number))
		look_number = random_outpost_npc_look_number()
	. = ..()
	if(random_name)
		name = generate_random_name(gender)
		real_name = name
	home = get_turf(src)
	GLOB.ambient_npcs += src
	// A closet sweeps its tile without asking the drag path (#131); bags and boxes ask this trait
	add_traits(list(TRAIT_NO_CONTAINMENT, TRAIT_NO_STORAGE_INSERT, TRAIT_WEATHER_IMMUNE), AMBIENT_NPC_TRAIT)
	RegisterSignal(src, COMSIG_MOUSEDROP_ONTO, PROC_REF(refuse_drag))
	RegisterSignal(src, COMSIG_MOVABLE_TELEPORTING, PROC_REF(refuse_teleport))
	RegisterSignal(src, COMSIG_LIVING_PRE_WABBAJACKED, PROC_REF(refuse_polymorph))
	RegisterSignal(src, COMSIG_PRE_MOB_CHANGED_TYPE, PROC_REF(refuse_type_change))
	RegisterSignal(src, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(on_attacked))
	AddElement(/datum/element/relay_attackers)
	AddElement(/datum/element/footstep, footstep_type = FOOTSTEP_MOB_SHOE)
	next_line_at = world.time + rand(AMBIENT_SPEECH_COOLDOWN_LOW, AMBIENT_SPEECH_COOLDOWN_HIGH) * speech_pace
	// Dressing a dummy can sleep
	INVOKE_ASYNC(src, PROC_REF(build_look))

/mob/living/basic/ambient_npc/Destroy()
	end_activity()
	set_held(null)
	QDEL_NULL(held_item)
	seat_ref = null
	set_place(null)
	GLOB.ambient_npcs -= src
	home = null
	leash_bounds = null
	return ..()

// =========================================================================
// LOOK
// =========================================================================

/**
 * Dresses them as person `look_number` of their gender in `outfit`, holding whatever `work_look`
 * or `held_visual` calls for, the way a player holds an item: a dummy built in the same outfit,
 * with a real item in hand, cached (outpost_npc_looks.dm). Can sleep.
 */
/mob/living/basic/ambient_npc/proc/build_look()
	if(QDELETED(src))
		return
	var/serial = ++look_serial
	if(length(work_weights))
		work_looks = get_outpost_worker_looks(outfit, gender, look_number)
	var/look
	if((work_look == "weld" || work_look == "tool") && work_looks)
		look = work_looks[work_look]
	else
		var/hand = (work_look == "carry") ? AMBIENT_CARRY_LOOK : held_visual
		if(hand)
			look = get_outpost_held_look(outfit, gender, look_number, hand)
		else if(work_looks)
			look = work_looks["idle"]
		else
			look = get_outpost_npc_look(outfit, gender, look_number)
	// A later build already landed while this one slept; leave its look alone.
	if(QDELETED(src) || serial != look_serial)
		return
	apply_outpost_npc_look(src, look)
	// Applying a look wipes every overlay, sparks included: put the work loop's back.
	var/datum/component/outpost_ambient_worker/worker = GetComponent(/datum/component/outpost_ambient_worker)
	if(worker?.work_overlay)
		add_overlay(worker.work_overlay)

/// Redresses them in `new_outfit` (a new job, a disguise). Can be called from anywhere; the look is built async.
/mob/living/basic/ambient_npc/proc/set_outfit(new_outfit)
	outfit = new_outfit
	work_looks = null
	INVOKE_ASYNC(src, PROC_REF(build_look))

/// Shows them holding what `look` needs ("weld", "tool", "carry"), or their held item / empty hands for null. The worker component calls this.
/mob/living/basic/ambient_npc/proc/show_work_look(look)
	work_look = look
	INVOKE_ASYNC(src, PROC_REF(build_look))

/// Shows `look` (an item type, or an item instance) in their hand as part of their look; null shows empty hands. A change that ends up the same item type is not rebuilt.
/mob/living/basic/ambient_npc/proc/set_held(look)
	var/new_held = ambient_held_look_type(look)
	if(new_held == held_visual)
		return
	held_visual = new_held
	INVOKE_ASYNC(src, PROC_REF(build_look))

/// Fades in where they stand, as someone stepping off the lift
/mob/living/basic/ambient_npc/proc/fade_in()
	alpha = 0
	animate(src, alpha = 255, time = AMBIENT_FADE_TIME)

/**
 * Gone: they fade and are deleted (walked off, took the lift, slipped away). Nothing starts once
 * this has. `instant` deletes them now, for places nobody is watching.
 */
/mob/living/basic/ambient_npc/proc/fade_out(instant = FALSE)
	if(fading || QDELETED(src))
		return
	fading = TRUE
	end_activity()
	ADD_TRAIT(src, TRAIT_AI_PAUSED, AMBIENT_NPC_TRAIT)
	if(instant)
		qdel(src)
		return
	ADD_TRAIT(src, TRAIT_GODMODE, AMBIENT_NPC_TRAIT)
	animate(src, alpha = 0, time = AMBIENT_FADE_TIME)
	QDEL_IN(src, AMBIENT_FADE_TIME)

/// Scales their health by `multiplier` (a planet NPC by band at its spawn site, never on the type)
/mob/living/basic/ambient_npc/proc/scale_health(multiplier)
	if(multiplier <= 0 || multiplier == 1)
		return
	maxHealth = round(maxHealth * multiplier)
	health = maxHealth
	updatehealth()

// =========================================================================
// PROTECTIONS
// =========================================================================

/// Nobody drag-drops them onto a bed, into a crate, a disposal unit or a vehicle
/mob/living/basic/ambient_npc/proc/refuse_drag(datum/source, atom/over, mob/user)
	SIGNAL_HANDLER
	return COMPONENT_CANCEL_MOUSEDROP_ONTO

/// Teleports of any kind, forced ones included, leave them where they are
/mob/living/basic/ambient_npc/proc/refuse_teleport(datum/source, atom/destination, channel)
	SIGNAL_HANDLER
	return TRUE

/mob/living/basic/ambient_npc/proc/refuse_polymorph(datum/source, what_to_randomize)
	SIGNAL_HANDLER
	return STOP_WABBAJACK

/mob/living/basic/ambient_npc/proc/refuse_type_change(datum/source)
	SIGNAL_HANDLER
	return COMPONENT_BLOCK_MOB_CHANGE

// Their own steps stay on the leash. Dragged, thrown, buckled or walked by a script, they go where they are taken.
/mob/living/basic/ambient_npc/Move(atom/newloc, direct, glide_size_override)
	if(!own_step_allowed(newloc))
		return FALSE
	return ..()

/**
 * Whether a step of their own onto `newloc` is allowed: onto their leash always; off it from on it
 * never; already off it (shoved, thrown), anywhere safe, so they can walk back.
 */
/mob/living/basic/ambient_npc/proc/own_step_allowed(atom/newloc)
	if(!isturf(newloc) || !isturf(loc) || pulledby || buckled || throwing || stat == DEAD)
		return TRUE
	var/turf/destination = newloc
	if(leash_ok(destination))
		return TRUE
	if(leash_ok(loc))
		return FALSE
	return destination.can_cross_safely(src)

/**
 * Whether they may be on `tile` by their own steps: inside `leash_bounds` if they have them, and
 * on their place's ground (an outpost's concourse, a planet's ground above its dock strip).
 * Override for a leash of another shape.
 */
/mob/living/basic/ambient_npc/proc/leash_ok(turf/tile)
	tile = get_turf(tile)
	if(!tile)
		return FALSE
	if(leash_bounds && !ambient_in_bounds(tile, leash_bounds))
		return FALSE
	if(place && !place.leash_ok(tile, src))
		return FALSE
	return TRUE

/**
 * Keeps them on their leash, while their AI is on. Off it, they walk back; still off it after
 * AMBIENT_LEASH_GIVE_UP, or somewhere they cannot walk back from, they give up (give_up_leash()).
 * TRUE while they are off it.
 */
/mob/living/basic/ambient_npc/proc/check_leash()
	var/turf/here = get_turf(src)
	if(!here || leash_ok(here))
		leash_broken_at = 0
		return FALSE
	if(!leash_broken_at)
		leash_broken_at = world.time
	if(!isturf(loc) || here.z != home?.z || world.time - leash_broken_at > AMBIENT_LEASH_GIVE_UP)
		give_up_leash()
		return TRUE
	if(istype(activity, /datum/ambient_activity/go_home) || istype(activity, /datum/ambient_activity/leave))
		return TRUE
	// No way back from here (home is gone or off the leash): no point waiting out the clock
	if(!start_activity(new /datum/ambient_activity/go_home(src)) && !(activity?.priority > AMBIENT_PRIORITY_REACTION))
		give_up_leash()
	return TRUE

/// They cannot get back to their leash: they slip away. Override to put them home instead.
/mob/living/basic/ambient_npc/proc/give_up_leash()
	fade_out()

// =========================================================================
// PLACE
// =========================================================================

/// Moves them to `new_place` (or none), keeping both places' lists right
/mob/living/basic/ambient_npc/proc/set_place(datum/ambient_place/new_place)
	if(place == new_place)
		return
	var/datum/ambient_place/old_place = place
	place = new_place
	old_place?.remove_npc(src)
	new_place?.add_npc(src)

/// Whether they can do anything: awake, on their feet or in a seat, not fading
/mob/living/basic/ambient_npc/proc/can_act()
	return stat == CONSCIOUS && !fading && !HAS_TRAIT(src, TRAIT_INCAPACITATED)

// =========================================================================
// HOLDING STILL (nobody at their outpost)
// =========================================================================

/**
 * Nobody is at their outpost: they stop where they are, mid-whatever. Their AI goes off
 * (TRAIT_AI_PAUSED), and resume_routine() later moves everything they wait for on by as long as
 * they stood, so nothing they do runs on while nobody watches. Override to put away anything that
 * would tick on by itself; call the parent.
 */
/mob/living/basic/ambient_npc/proc/pause_routine()
	if(paused_at)
		return
	paused_at = max(world.time, 1)
	ADD_TRAIT(src, TRAIT_AI_PAUSED, AMBIENT_PAUSED_TRAIT)

// Holding still at an empty outpost: nothing about them moves on (they are proof against air, cold and heat anyway)
/mob/living/basic/ambient_npc/Life(seconds_per_tick = SSMOBS_DT, times_fired)
	if(paused_at && !client)
		return
	return ..()

/// Someone is back: they carry on from where they stopped. Override to bring back what pause_routine() put away; call the parent.
/mob/living/basic/ambient_npc/proc/resume_routine()
	if(!paused_at)
		return
	var/stood = world.time - paused_at
	paused_at = 0
	if(stood > 0)
		shift_times(stood)
	REMOVE_TRAIT(src, TRAIT_AI_PAUSED, AMBIENT_PAUSED_TRAIT)

/**
 * They stood still for `delay`: every world.time they wait for (their next line, the end of their
 * visit, their activity's steps) moves on by as much. Override for your own; call the parent.
 */
/mob/living/basic/ambient_npc/proc/shift_times(delay)
	next_line_at = ambient_shifted(next_line_at, delay)
	activity_retry_at = ambient_shifted(activity_retry_at, delay)
	leash_broken_at = ambient_shifted(leash_broken_at, delay)
	activity?.shift_times(delay)

// =========================================================================
// DEATH
// =========================================================================

/mob/living/basic/ambient_npc/death(gibbed)
	var/was_alive = stat != DEAD
	. = ..()
	if(!was_alive)
		return
	end_activity()
	set_held(null)
	SEND_SIGNAL(src, COMSIG_AMBIENT_NPC_DIED, place)
	if(!death_counted)
		death_counted = TRUE
		place?.npc_died(src)
	drop_loot()

/// Their cash and death loot, once: a revived NPC killed again drops nothing
/mob/living/basic/ambient_npc/proc/drop_loot()
	if(loot_dropped)
		return
	loot_dropped = TRUE
	var/turf/drop_turf = drop_location()
	if(!drop_turf)
		return
	var/cash = (death_cash_high > 0) ? rand(max(0, death_cash_low), death_cash_high) : 0
	if(cash && place)
		cash = place.cash_for(src, cash)
	if(cash > 0)
		new /obj/item/stack/spacecash/c1(drop_turf, cash)
	for(var/item_type in death_loot)
		new item_type(drop_turf)

// A body lies down, and gets up again if they are revived. Types that turn as they lie (rotate_on_lying) turn by themselves.
/mob/living/basic/ambient_npc/look_dead()
	. = ..()
	if(!rotate_on_lying)
		transform = matrix().Turn(90)

/mob/living/basic/ambient_npc/look_alive()
	. = ..()
	if(!rotate_on_lying)
		transform = matrix()

// =========================================================================
// DIALOGUE
// =========================================================================

/**
 * The list under `context` in `section` of dialogue `file` (in AMBIENT_STRINGS_DIR), or an empty
 * list. Unlike strings(), never crashes on a missing file, section or context: a stub file is fine.
 */
/proc/ambient_dialogue_lines(file, section, context)
	var/list/entry = ambient_dialogue_section(file, section)
	var/list/lines = entry?[context]
	return islist(lines) ? lines : list()

/// Section `section` of dialogue `file`, or null
/proc/ambient_dialogue_section(file, section)
	if(!file || !section)
		return null
	var/static/list/missing_files = list()
	if(missing_files[file])
		return null
	if(!(file in GLOB.string_cache))
		if(!fexists("[AMBIENT_STRINGS_DIR]/[file]"))
			missing_files[file] = TRUE
			return null
		load_strings_file(file, AMBIENT_STRINGS_DIR)
	var/list/cache = GLOB.string_cache?[file]
	var/list/entry = islist(cache) ? cache[section] : null
	return islist(entry) ? entry : null

/**
 * The lines they have for `context`: their own section, then their file's "any" section, then the
 * core file's "default" section. Override to add lines from elsewhere (a trader's shop).
 */
/mob/living/basic/ambient_npc/proc/get_lines(context)
	var/list/lines = ambient_dialogue_lines(dialogue_file, dialogue_section, context)
	if(!length(lines))
		lines = ambient_dialogue_lines(dialogue_file, "any", context)
	if(!length(lines) && dialogue_file != AMBIENT_STRINGS_CORE)
		lines = ambient_dialogue_lines(AMBIENT_STRINGS_CORE, dialogue_section, context)
	if(!length(lines))
		lines = ambient_dialogue_lines(AMBIENT_STRINGS_CORE, "default", context)
	return lines

/// A random two-person exchange from their section's "conversations": list(opener, reply), or null
/mob/living/basic/ambient_npc/proc/pick_conversation()
	var/list/entry = ambient_dialogue_section(dialogue_file, dialogue_section)
	var/list/conversations = entry?["conversations"]
	if(!length(conversations))
		return null
	var/list/conversation = pick(conversations)
	if(!islist(conversation) || !istext(conversation["opener"]))
		return null
	var/list/replies = conversation["replies"]
	return list(conversation["opener"], length(replies) ? pick(replies) : null)

/// Their first name, as someone would call them
/mob/living/basic/ambient_npc/proc/speech_name()
	var/list/parts = splittext(real_name || name, " ")
	return length(parts) ? parts[1] : name

/// Fills a line's placeholders: {name} their first name, {other} who they talk to, {place} where they are
/mob/living/basic/ambient_npc/proc/fill_line(line, atom/other)
	line = replacetext(line, "{name}", speech_name())
	if(findtext(line, "{other}"))
		var/other_name = "friend"
		if(istype(other, /mob/living/basic/ambient_npc))
			var/mob/living/basic/ambient_npc/other_npc = other
			other_name = other_npc.speech_name()
		else if(ismob(other))
			var/mob/other_mob = other
			other_name = first_name(other_mob.real_name || other_mob.name)
		line = replacetext(line, "{other}", other_name)
	line = replacetext(line, "{place}", place?.name || "here")
	return line

/**
 * Says a line for `context` (to `other`, if given). A spontaneous line waits out their own pause and
 * the pause shared by their place; `force` skips both (replies, reactions). TRUE if they spoke.
 */
/mob/living/basic/ambient_npc/proc/speak_context(context, atom/other, force = FALSE)
	if(stat != CONSCIOUS || fading)
		return FALSE
	if(!force && (world.time < next_line_at || (place && world.time < place.next_line_at)))
		return FALSE
	var/list/lines = get_lines(context)
	if(!length(lines))
		return FALSE
	var/line = pick(lines)
	if(!istext(line))
		return FALSE
	say_line(fill_line(line, other))
	return TRUE

/// Says `line` now and starts their pauses. Never sleeps.
/mob/living/basic/ambient_npc/proc/say_line(line)
	if(!line || stat != CONSCIOUS)
		return
	next_line_at = world.time + rand(AMBIENT_SPEECH_COOLDOWN_LOW, AMBIENT_SPEECH_COOLDOWN_HIGH) * speech_pace
	if(place)
		place.next_line_at = world.time + AMBIENT_PLACE_SPEECH_COOLDOWN
	INVOKE_ASYNC(src, TYPE_PROC_REF(/atom/movable, say), line)

/**
 * Answers `speaker` a moment from now: `line` if given, otherwise a line for `context`. Only if
 * they are still awake and near each other then.
 */
/mob/living/basic/ambient_npc/proc/reply_to(atom/movable/speaker, context = AMBIENT_LINE_REPLY, line)
	addtimer(CALLBACK(src, PROC_REF(do_reply), WEAKREF(speaker), context, line), rand(AMBIENT_REPLY_DELAY_LOW, AMBIENT_REPLY_DELAY_HIGH), TIMER_DELETE_ME)

/mob/living/basic/ambient_npc/proc/do_reply(datum/weakref/speaker_ref, context, line)
	var/atom/movable/speaker = speaker_ref?.resolve()
	if(QDELETED(speaker) || stat != CONSCIOUS || fading || get_dist(src, speaker) > 3)
		return
	if(!buckled)
		face_atom(speaker)
	if(line)
		say_line(fill_line(line, speaker))
	else
		speak_context(context, speaker, force = TRUE)

// =========================================================================
// PLAYERS
// =========================================================================

// An empty hand talks to them; combat mode or a right click is the usual attack or shove
/mob/living/basic/ambient_npc/attack_hand(mob/living/carbon/human/user, list/modifiers)
	if(!user.combat_mode && !LAZYACCESS(modifiers, RIGHT_CLICK) && can_act())
		talked_to(user)
		return TRUE
	return ..()

/// Whether `user` may have another answer yet, and starts their wait if so
/mob/living/basic/ambient_npc/proc/talk_ready(mob/user)
	var/key = REF(user)
	if(LAZYACCESS(talk_cooldowns, key) > world.time)
		return FALSE
	LAZYSET(talk_cooldowns, key, world.time + AMBIENT_TALK_COOLDOWN)
	// A long round meets many people; forget the oldest
	if(length(talk_cooldowns) > 20)
		talk_cooldowns.Cut(1, 2)
	return TRUE

/// `user` talked to them (an empty hand). Override for a menu (a stray's "Come with us").
/mob/living/basic/ambient_npc/proc/talked_to(mob/living/user)
	if(!talk_ready(user))
		return
	if(!buckled)
		face_atom(user)
	speak_context(AMBIENT_LINE_TALK, user, force = TRUE)

// =========================================================================
// REACTIONS
// =========================================================================

/// Whether a reaction of `kind` may happen now, and starts its cooldown if so
/mob/living/basic/ambient_npc/proc/reaction_ready(kind, cooldown = AMBIENT_REACTION_COOLDOWN)
	if(LAZYACCESS(reaction_cooldowns, kind) > world.time)
		return FALSE
	LAZYSET(reaction_cooldowns, kind, world.time + cooldown)
	return TRUE

/mob/living/basic/ambient_npc/proc/on_attacked(datum/source, atom/attacker, attack_flags)
	SIGNAL_HANDLER
	if(!(attack_flags & (ATTACKER_DAMAGING_ATTACK | ATTACKER_STAMINA_ATTACK | ATTACKER_SHOVING)))
		return
	// Their place hears of it first (a trader outpost counts a real blow as violence), even if it killed them
	place?.npc_attacked(src, attacker, attack_flags)
	react_attacked(attacker)

/**
 * Someone went for them. Override: a planet NPC fights back or runs (PB). The default is a line,
 * and at a trader outpost they duck out to the lift. Never sleeps.
 */
/mob/living/basic/ambient_npc/proc/react_attacked(atom/attacker)
	if(stat != CONSCIOUS || fading || !reaction_ready("attacked"))
		return
	speak_context(AMBIENT_LINE_ATTACKED, attacker, force = TRUE)
	if(istype(place, /datum/ambient_place/outpost))
		start_activity(new /datum/ambient_activity/leave(src, null, 1 SECONDS))

/**
 * A fight broke out near them at their outpost (COMSIG_TRADER_OUTPOST_VIOLENCE): they duck, then
 * head for the lift and leave. Override to stay (a barkeep). Never sleeps.
 */
/mob/living/basic/ambient_npc/proc/react_violence(mob/living/offender)
	if(stat != CONSCIOUS || fading || istype(activity, /datum/ambient_activity/leave) || !reaction_ready("violence"))
		return
	// Leaving first: starting it finishes what they were doing, which stands them up
	if(!start_activity(new /datum/ambient_activity/leave(src, null, AMBIENT_DUCK_TIME)))
		return
	if(!buckled)
		face_atom(offender)
	crouch()
	if(prob(50))
		speak_context(AMBIENT_LINE_VIOLENCE, offender, force = TRUE)

/// The kingpin's crew is fighting: they head for `refuge` and keep their heads down. Never sleeps.
/mob/living/basic/ambient_npc/proc/react_shootout(turf/refuge)
	if(stat != CONSCIOUS || fading || istype(activity, /datum/ambient_activity/leave))
		return
	if(prob(40))
		speak_context(AMBIENT_LINE_COVER, null, force = TRUE)
	start_activity(new /datum/ambient_activity/take_cover(src, refuge))

/// The shootout is over: back to what they were doing
/mob/living/basic/ambient_npc/proc/shootout_over()
	if(istype(activity, /datum/ambient_activity/take_cover))
		end_activity()

/**
 * A storm is coming to their planet (COMSIG_WEATHER_TELEGRAPH): a shouted warning, which doubles
 * as a telegraph for players, then shelter or a crouch until it passes. Never sleeps.
 */
/mob/living/basic/ambient_npc/proc/react_storm(datum/weather/storm)
	if(stat != CONSCIOUS || fading || !reaction_ready("storm", 2 MINUTES))
		return
	speak_context(AMBIENT_LINE_STORM, null, force = TRUE)
	var/duration = 2 MINUTES
	if(istype(storm))
		duration = storm.telegraph_duration + storm.weather_duration_upper
	var/datum/ambient_place/site/site = place
	start_activity(new /datum/ambient_activity/shelter(src, istype(site) ? site.shelter : null, duration))

/// The supply convoy arrived at their outpost (COMSIG_TRADER_OUTPOST_CONVOY). Override: the dock workers (PA).
/mob/living/basic/ambient_npc/proc/react_convoy(obj/structure/overmap/trader_outpost/outpost)
	return

// =========================================================================
// BODY
// =========================================================================

/// Sits on `seat` from its tile
/mob/living/basic/ambient_npc/proc/sit_on(obj/structure/chair/seat)
	if(QDELETED(seat))
		return FALSE
	if(buckled == seat)
		return TRUE
	if(loc != seat.loc || seat.has_buckled_mobs())
		return FALSE
	stand_up()
	if(!seat.buckle_mob(src, force = TRUE))
		return FALSE
	seat_ref = WEAKREF(seat)
	return TRUE

/// Down on the floor: sitting, or ducking
/mob/living/basic/ambient_npc/proc/crouch()
	if(crouching || buckled)
		return
	crouching = TRUE
	add_offsets(AMBIENT_NPC_TRAIT, y_add = -4)

/// Up from their seat or the floor. Only a seat they sat on themselves: never out of one someone put them in.
/mob/living/basic/ambient_npc/proc/stand_up()
	if(crouching)
		crouching = FALSE
		remove_offsets(AMBIENT_NPC_TRAIT)
	var/obj/structure/chair/seat = seat_ref?.resolve()
	seat_ref = null
	if(seat && buckled == seat)
		seat.unbuckle_mob(src, force = TRUE)

/// A drink in hand, poured for the occasion: a real glass in their contents
/mob/living/basic/ambient_npc/proc/take_drink(reagent_type = /datum/reagent/consumable/ethanol/beer)
	var/obj/item/reagent_containers/cup/glass/drinkingglass/glass = held_item
	if(!istype(glass) || QDELETED(glass))
		glass = new(src)
		glass.reagents.add_reagent(reagent_type, 25)
		held_item = glass
	set_held(glass)
	return glass

/// A sip of their drink; an empty glass is filled again. FALSE with no drink in hand.
/mob/living/basic/ambient_npc/proc/sip()
	var/obj/item/reagent_containers/cup/glass/drinkingglass/glass = held_item
	if(!istype(glass) || QDELETED(glass) || glass.loc != src)
		return FALSE
	if(!glass.reagents.total_volume)
		glass.reagents.add_reagent(/datum/reagent/consumable/ethanol/beer, 25)
	else
		glass.reagents.remove_all(5)
		playsound(src, 'sound/items/drink.ogg', 20, TRUE, -4)
	set_held(glass)
	return TRUE

/**
 * Sets their drink down on `table` if it is right there, up to AMBIENT_GLASSES_MAX glasses of
 * theirs and AMBIENT_TABLE_GLASSES_MAX on the table; otherwise it just goes.
 */
/mob/living/basic/ambient_npc/proc/put_drink_down(obj/structure/table/table)
	var/obj/item/glass = held_item
	held_item = null
	set_held(null)
	if(QDELETED(glass))
		return
	if(stat == CONSCIOUS && glasses_left < AMBIENT_GLASSES_MAX && !QDELETED(table) && isturf(table.loc) && isturf(loc) && Adjacent(table))
		var/on_table = 0
		for(var/obj/item/reagent_containers/cup/glass/other in table.loc)
			on_table++
		if(on_table < AMBIENT_TABLE_GLASSES_MAX)
			glasses_left++
			glass.forceMove(table.loc)
			glass.pixel_x = rand(-6, 6)
			glass.pixel_y = rand(0, 6)
			return
	qdel(glass)

// =========================================================================
// HELPERS
// =========================================================================

/// Whether `tile` is inside `bounds`, list(min x, min y, max x, max y, z)
/proc/ambient_in_bounds(turf/tile, list/bounds)
	return tile && length(bounds) >= 5 && tile.z == bounds[5] && tile.x >= bounds[1] && tile.x <= bounds[3] && tile.y >= bounds[2] && tile.y <= bounds[4]

/// Whether an NPC could stand on `tile` at all: open ground, not space, lava, a chasm or an open drop, nothing dense on it
/proc/ambient_ground_ok(turf/tile, allow_water = FALSE)
	if(!isopenturf(tile) || isspaceturf(tile) || isgroundlessturf(tile) || islava(tile) || ischasm(tile))
		return FALSE
	if(!allow_water && istype(tile, /turf/open/water))
		return FALSE
	return !tile.is_blocked_turf(exclude_mobs = TRUE)

/**
 * The /obj/item type `look` should show in an NPC's hand, or null for empty hands. `look` is an
 * item type, an item instance, or a structure type/instance stood in for an item. A drinking glass
 * shows what's in it; a few other things with no in-hand sprite of their own show a stand-in that
 * has one; anything else shows its own type, or nothing if it isn't an item at all.
 */
/proc/ambient_held_look_type(look)
	if(isnull(look))
		return null
	// istype() on a type path is always FALSE, which is what we want here: only a real glass instance matches.
	if(isitem(look) && istype(look, /obj/item/reagent_containers/cup/glass/drinkingglass))
		var/obj/item/reagent_containers/cup/glass/drinkingglass/glass = look
		if(glass.reagents?.has_reagent(/datum/reagent/consumable/coffee))
			return /obj/item/reagent_containers/cup/glass/mug
		return /obj/item/reagent_containers/cup/glass/bottle/beer
	if(ispath(look, /obj/structure/closet/crate))
		return /obj/item/delivery/big
	if(ispath(look, /obj/item/storage/box/papersack))
		return /obj/item/delivery/small
	if(ispath(look, /obj/item/storage/bag/tray))
		return /obj/item/reagent_containers/cup/bucket
	if(ispath(look, /obj/item/reagent_containers/cup/glass/flask))
		return /obj/item/reagent_containers/cup/glass/bottle/holywater
	if(ispath(look, /obj/item/stack/ore) || ispath(look, /obj/item/food/meat/slab) || ispath(look, /obj/item/food/meat/steak))
		return null
	if(ispath(look, /obj/item))
		return look
	if(isitem(look))
		var/obj/item/item = look
		return item.type
	return null

#undef AMBIENT_CARRY_LOOK
