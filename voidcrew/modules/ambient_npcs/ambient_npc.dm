/**
 * # World population: the base NPC
 *
 * Owner: P0 seams. Packages subtype /mob/living/carbon/human/npc/ambient_npc in their own files and
 * override the procs marked "Override" below.
 *
 * Every ambient NPC is a real human body (voidcrew/modules/human_npcs/, phase E1 of the human NPC
 * migration): wounds, bleeding, crit, death, revival, cuffs, stuns, drink and drugs work on them as
 * on a player, through the same tg code. What every ambient NPC gets (spec 2.2, 2.3, 2.5):
 * - a face for life (outpost_npc_looks.dm) and an outfit, its kit locked to them (owner decision D3);
 *   what they hold for an activity is a real item in their hand (set_held(), show_work_look());
 * - a person's resistance: while awake and up, their AI breaks grabs, gets out of buckles it didn't
 *   choose, works at cuffs and climbs out of closets (/datum/ai_planning_subtree/ambient_escape); in
 *   crit or dead they are an ordinary body that can be dragged, carried, bagged and operated on. At a
 *   trader outpost a living one refuses teleports; nobody can polymorph them or change their type;
 * - a leash they walk back to, or walk out from (they never vanish in front of players);
 * - killable: a body drops a little cash (and any `death_loot`) once, never again after a revive. It
 *   lies until nobody is watching (SShuman_npcs' corpse rules; a trader outpost takes it sooner, as
 *   carried off). At a trader outpost, hurting one is violence there (the outpost's strikes, and
 *   everyone near ducks), and turrets never shoot them (FACTION_TURRET while they belong to it);
 * - a passive AI: no targeting subtree, so outpost turrets never read them as wild hostiles;
 * - dialogue from a JSON file with per-NPC and per-place cooldowns, replies to other NPCs, and an
 *   answer for a player who talks to them (an empty hand), which falls through to tg's help (shaking
 *   awake, patting out flames, helping up) while they are down, on fire or asleep;
 * - reactions: being attacked, a fight at their outpost, the kingpin's shootout, a storm, the convoy.
 *
 * Documented deviation from a player (AM-17, a performance rule like the base's dormancy): at a trader
 * outpost nobody is on, the living hold still. Their AI is off and their Life() does nothing
 * (pause_routine()), so nothing about them moves on until someone comes.
 *
 * The routine (what they do from moment to moment) is in ambient_activity.dm.
 */

/// What a hauling worker carries in hand
#define AMBIENT_CARRY_LOOK /obj/item/delivery/big

/**
 * `order` is the human NPC base's spawn order (ambient_build_npc()). Its look may carry an identity
 * (a stray's stray_identity(): list("name", "gender", "outfit", "person")) that makes them someone
 * who was here before.
 */
/mob/living/carbon/human/npc/ambient_npc/Initialize(mapload, datum/human_npc_order/order)
	var/list/identity = order?.look
	if(islist(identity))
		order.look = null
		take_identity(identity)
	if(person)
		gender = person.gender
	else
		if(random_gender)
			gender = pick(MALE, FEMALE)
		person = new_outpost_npc_person(gender)
	if(length(outfit_choices))
		outfit = pick(outfit_choices)
	if(outfit)
		npc_outfit = outfit
	npc_name = random_name ? generate_random_name(gender) : name
	. = ..()
	home = get_turf(src)
	GLOB.ambient_npcs += src
	RegisterSignal(src, COMSIG_MOVABLE_TELEPORTING, PROC_REF(refuse_teleport))
	RegisterSignal(src, COMSIG_LIVING_PRE_WABBAJACKED, PROC_REF(refuse_polymorph))
	RegisterSignal(src, COMSIG_PRE_MOB_CHANGED_TYPE, PROC_REF(refuse_type_change))
	RegisterSignal(src, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(on_attacked))
	AddElement(/datum/element/relay_attackers)
	set_pace(running = FALSE)
	next_line_at = world.time + rand(AMBIENT_SPEECH_COOLDOWN_LOW, AMBIENT_SPEECH_COOLDOWN_HIGH) * speech_pace
	refresh_hands()

/mob/living/carbon/human/npc/ambient_npc/Destroy()
	end_activity()
	QDEL_NULL(held_prop)
	QDEL_NULL(held_item)
	seat_ref = null
	set_place(null)
	GLOB.ambient_npcs -= src
	home = null
	leash_bounds = null
	person = null
	return ..()

/// Becomes the person `identity` describes (stray_identity()): their face, gender, outfit and name. Before Initialize's parent.
/mob/living/carbon/human/npc/ambient_npc/proc/take_identity(list/identity)
	var/datum/outpost_npc_look/face = identity["person"]
	if(istype(face))
		person = face.copy()
		random_gender = FALSE
	else if(identity["gender"] == MALE || identity["gender"] == FEMALE)
		random_gender = FALSE
		gender = identity["gender"]
	if(ispath(identity["outfit"], /datum/outfit))
		outfit_choices = null
		outfit = identity["outfit"]
	if(istext(identity["name"]))
		random_name = FALSE
		name = identity["name"]

/// Who they are, to make the same person again later (spawn_npc(identity =))
/mob/living/carbon/human/npc/ambient_npc/proc/ambient_identity()
	return list("name" = real_name, "gender" = gender, "outfit" = outfit, "person" = person?.copy())

// Their own face, for life, rather than a new random one
/mob/living/carbon/human/npc/ambient_npc/npc_apply_random_look()
	dna.initialize_dna(newblood_type = random_human_blood_type(), create_mutation_blocks = FALSE, randomize_features = TRUE)
	person ||= new_outpost_npc_person(gender)
	person.apply_to(src)

// What they are, after what anyone can see of them (their kit and their body)
/mob/living/carbon/human/npc/ambient_npc/examine(mob/user)
	. = ..()
	if(desc && stat != DEAD)
		. += span_notice(desc)

// =========================================================================
// WHAT THEY HOLD
// =========================================================================

/**
 * Puts what their work (`work_look`) or their activity (`held_visual`) calls for in their hand, as a
 * real item: a lit welder with any welding visor down, a wrench, a parcel, a mop, a weapon. A weapon
 * or tool they carry on them (a belt, a pocket, a bag) is taken out and put back later; anything else
 * is a prop, locked to them like their kit and deleted when they put it away. Their drink
 * (`held_item`) stays in its own hand.
 */
/mob/living/carbon/human/npc/ambient_npc/proc/refresh_hands()
	if(QDELETED(src))
		return
	var/wanted_type
	switch(work_look)
		if("weld")
			wanted_type = /obj/item/weldingtool
		if("tool")
			wanted_type = /obj/item/wrench
		if("carry")
			wanted_type = AMBIENT_CARRY_LOOK
	wanted_type ||= held_visual
	set_outpost_worker_visors(src, up = work_look != "weld")
	if(held_prop && (QDELETED(held_prop) || !is_holding(held_prop)))
		held_prop = null
	if(held_prop && wanted_type && istype(held_prop, wanted_type))
		light_prop(held_prop)
		return
	put_away_prop()
	if(!wanted_type)
		return
	// Already in a hand (a spear or a cleaver their outfit put there)
	for(var/obj/item/in_hand in held_items)
		if(istype(in_hand, wanted_type) && in_hand != held_item)
			held_prop = in_hand
			light_prop(in_hand)
			return
	var/obj/item/carried = carried_item_of(wanted_type)
	if(carried && human_npc_take_in_hand(src, carried))
		held_prop = carried
	else
		var/obj/item/prop = new wanted_type(src)
		if(!put_in_hands(prop))
			qdel(prop)
			return
		npc_lock_item(prop)
		ADD_TRAIT(prop, TRAIT_AMBIENT_PROP, AMBIENT_NPC_TRAIT)
		held_prop = prop
	light_prop(held_prop)

/// Something of `item_type` they carry on them but don't hold (a belt, a pocket, a bag), or null
/mob/living/carbon/human/npc/ambient_npc/proc/carried_item_of(item_type)
	for(var/obj/item/thing as anything in get_all_contents_type(item_type))
		if(is_holding(thing) || thing == held_item || !human_npc_can_draw(src, thing))
			continue
		return thing
	return null

/// A welder for welding is lit; any other prop is left as it is
/mob/living/carbon/human/npc/ambient_npc/proc/light_prop(obj/item/prop)
	var/obj/item/weldingtool/welder = prop
	if(istype(welder) && welder.welding != (work_look == "weld"))
		welder.set_welding(work_look == "weld")
		welder.update_appearance()

/// Puts down what they held for show: a prop goes, something of their own goes back on them
/mob/living/carbon/human/npc/ambient_npc/proc/put_away_prop()
	var/obj/item/prop = held_prop
	held_prop = null
	if(QDELETED(prop))
		return
	if(HAS_TRAIT(prop, TRAIT_AMBIENT_PROP))
		qdel(prop)
		return
	var/obj/item/weldingtool/welder = prop
	if(istype(welder) && welder.welding)
		welder.set_welding(FALSE)
	if(is_holding(prop))
		prop.equip_to_best_slot(src)

/// Shows them holding what `look` needs ("weld", "tool", "carry"), or their held item / empty hands for null. The worker component calls this.
/mob/living/carbon/human/npc/ambient_npc/proc/show_work_look(look)
	if(work_look == look)
		return
	work_look = look
	refresh_hands()

/**
 * Holds `look` (an item type, or an item instance) for show; null shows empty hands. Their own
 * drink (`held_item`) goes into their hand as it is. A change that ends up the same item type keeps
 * the item they already hold.
 */
/mob/living/carbon/human/npc/ambient_npc/proc/set_held(look)
	if(isitem(look) && look == held_item)
		var/obj/item/drink = held_item
		if(!QDELETED(drink) && !is_holding(drink))
			if(drink.loc == src)
				temporarilyRemoveItemFromInventory(drink, force = TRUE)
			if(!put_in_hands(drink))
				drink.forceMove(src)
		look = null
	var/new_held = ambient_held_look_type(look)
	if(new_held == held_visual && (!new_held || held_prop))
		return
	held_visual = new_held
	refresh_hands()

/// Walking (an unhurried pace about their business) or running (a fight, getting away)
/mob/living/carbon/human/npc/ambient_npc/proc/set_pace(running)
	var/wanted = running ? MOVE_INTENT_RUN : MOVE_INTENT_WALK
	if(move_intent != wanted)
		move_intent = wanted
		update_move_intent_slowdown()

/// Fades in where they stand, as someone stepping off the lift
/mob/living/carbon/human/npc/ambient_npc/proc/fade_in()
	alpha = 0
	animate(src, alpha = 255, time = AMBIENT_FADE_TIME)

/**
 * Gone (walked off, took the lift, slipped away), if they may go now: up and free, and on their way
 * out tile or out of every player's sight (npc_may_vanish_now()). They fade over AMBIENT_FADE_TIME and
 * are deleted; anything that puts them down, grabs or buckles them meanwhile stops it (no godmode: a
 * shot still lands). One who may not go yet (a player is watching them away from the exit) walks out
 * instead. `instant` deletes them now, for places nobody is watching. Returns TRUE if they are going.
 */
/mob/living/carbon/human/npc/ambient_npc/proc/fade_out(instant = FALSE)
	if(fading || QDELETED(src))
		return fading
	if(instant)
		fading = TRUE
		end_activity()
		qdel(src)
		return TRUE
	if(!npc_may_vanish_now())
		if(stat == CONSCIOUS && !istype(activity, /datum/ambient_activity/leave))
			start_activity(new /datum/ambient_activity/leave(src))
		return FALSE
	fading = TRUE
	end_activity()
	ADD_TRAIT(src, TRAIT_AI_PAUSED, AMBIENT_NPC_TRAIT)
	animate(src, alpha = 0, time = AMBIENT_FADE_TIME)
	addtimer(CALLBACK(src, PROC_REF(finish_fade)), AMBIENT_FADE_TIME, TIMER_DELETE_ME)
	return TRUE

/// The end of a fade: gone, unless something stopped them on the way
/mob/living/carbon/human/npc/ambient_npc/proc/finish_fade()
	if(QDELETED(src))
		return
	if(stat == CONSCIOUS && !human_npc_out_of_fight(src) && !pulledby && (!buckled || own_buckle(buckled)) && isturf(loc))
		npc_drop_not_gear()
		qdel(src)
		return
	// Shot, grabbed or put down on the way: they are still here
	fading = FALSE
	REMOVE_TRAIT(src, TRAIT_AI_PAUSED, AMBIENT_NPC_TRAIT)
	animate(src, alpha = 255, time = 0.2 SECONDS)

/**
 * Whether they may slip away right now (the base's rule for anyone walking out, N8): awake, up and
 * free (not in crit, cuffed, stunned, pulled, buckled to anything but their own seat, or carried),
 * and on their place's way out or out of every player's sight.
 */
/mob/living/carbon/human/npc/ambient_npc/proc/npc_may_vanish_now()
	if(stat != CONSCIOUS || human_npc_out_of_fight(src) || INCAPACITATED_IGNORING(src, NONE))
		return FALSE
	if(pulledby || !isturf(loc) || (buckled && !own_buckle(buckled)))
		return FALSE
	var/turf/exit = place?.exit_turf(src)
	if(exit && get_dist(src, exit) <= 1)
		return TRUE
	return !human_npc_watched(src)

// =========================================================================
// PROTECTIONS
// =========================================================================

/// At a trader outpost, a living person's teleports of any kind, forced ones too, leave them where they are
/mob/living/carbon/human/npc/ambient_npc/proc/refuse_teleport(datum/source, atom/destination, channel)
	SIGNAL_HANDLER
	if(stat == DEAD || !istype(place, /datum/ambient_place/outpost))
		return NONE
	return TRUE

/mob/living/carbon/human/npc/ambient_npc/proc/refuse_polymorph(datum/source, what_to_randomize)
	SIGNAL_HANDLER
	return STOP_WABBAJACK

/mob/living/carbon/human/npc/ambient_npc/proc/refuse_type_change(datum/source)
	SIGNAL_HANDLER
	return COMPONENT_BLOCK_MOB_CHANGE

/// Whether being buckled to `thing` is their own doing (the seat they sat on), so their AI leaves it be. Override (a boat).
/mob/living/carbon/human/npc/ambient_npc/proc/own_buckle(atom/thing)
	return !isnull(thing) && thing == seat_ref?.resolve()

// Their own steps stay on the leash. Dragged, thrown, buckled or walked by a script, they go where they are taken.
/mob/living/carbon/human/npc/ambient_npc/Move(atom/newloc, direct, glide_size_override)
	if(!own_step_allowed(newloc))
		return FALSE
	return ..()

/**
 * Whether a step of their own onto `newloc` is allowed: onto their leash always; off it from on it
 * never; already off it (shoved, thrown), anywhere safe, so they can walk back.
 */
/mob/living/carbon/human/npc/ambient_npc/proc/own_step_allowed(atom/newloc)
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
/mob/living/carbon/human/npc/ambient_npc/proc/leash_ok(turf/tile)
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
/mob/living/carbon/human/npc/ambient_npc/proc/check_leash()
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
/mob/living/carbon/human/npc/ambient_npc/proc/give_up_leash()
	fade_out()

// =========================================================================
// PLACE
// =========================================================================

/// Moves them to `new_place` (or none), keeping both places' lists right
/mob/living/carbon/human/npc/ambient_npc/proc/set_place(datum/ambient_place/new_place)
	if(place == new_place)
		return
	var/datum/ambient_place/old_place = place
	place = new_place
	old_place?.remove_npc(src)
	new_place?.add_npc(src)

/// Whether they can go about their business: awake, on their feet or in a seat, not cuffed, not fading
/mob/living/carbon/human/npc/ambient_npc/proc/can_act()
	return stat == CONSCIOUS && !fading && !HAS_TRAIT(src, TRAIT_INCAPACITATED) && !HAS_TRAIT(src, TRAIT_RESTRAINED)


// =========================================================================
// HOLDING STILL (nobody at their outpost)
// =========================================================================

/**
 * Nobody is at their outpost: they stop where they are, mid-whatever. Their AI goes off
 * (TRAIT_AI_PAUSED) and their Life() does nothing, and resume_routine() later moves everything they
 * wait for on by as long as they stood, so nothing they do runs on while nobody watches. Override to
 * put away anything that would tick on by itself; call the parent.
 */
/mob/living/carbon/human/npc/ambient_npc/proc/pause_routine()
	if(paused_at)
		return
	paused_at = max(world.time, 1)
	ADD_TRAIT(src, TRAIT_AI_PAUSED, AMBIENT_PAUSED_TRAIT)

// Holding still at an empty outpost: nothing about the living moves on (a documented performance rule,
// AM-17, like the base's dormancy). A body runs its Life() as any other NPC corpse does.
/mob/living/carbon/human/npc/ambient_npc/Life(seconds_per_tick = SSMOBS_DT, times_fired)
	if(paused_at && !client && stat != DEAD)
		return FALSE
	return ..()

/// Someone is back: they carry on from where they stopped. Override to bring back what pause_routine() put away; call the parent.
/mob/living/carbon/human/npc/ambient_npc/proc/resume_routine()
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
/mob/living/carbon/human/npc/ambient_npc/proc/shift_times(delay)
	next_line_at = ambient_shifted(next_line_at, delay)
	activity_retry_at = ambient_shifted(activity_retry_at, delay)
	leash_broken_at = ambient_shifted(leash_broken_at, delay)
	activity?.shift_times(delay)

// =========================================================================
// DEATH
// =========================================================================

/mob/living/carbon/human/npc/ambient_npc/death(gibbed)
	var/was_alive = stat != DEAD
	if(was_alive)
		// Before the base starts counting: a trader outpost carries its dead off sooner
		npc_corpse_lifetime = corpse_lifetime()
	. = ..()
	if(!was_alive || stat != DEAD)
		return
	end_activity()
	if(crouching)
		crouching = FALSE
		remove_offsets(AMBIENT_NPC_TRAIT)
	if(!death_counted)
		death_counted = TRUE
		SEND_SIGNAL(src, COMSIG_AMBIENT_NPC_DIED, place)
		place?.npc_died(src)
	drop_loot()

/**
 * How long their body lies before SShuman_npcs may take it, once nobody is near (its corpse rules,
 * N9): a trader outpost's dead go after AMBIENT_OUTPOST_BODY_TIME, as if carried off; a ship's
 * deckhands stay with their crew; anyone else as any NPC corpse does.
 */
/mob/living/carbon/human/npc/ambient_npc/proc/corpse_lifetime()
	if(istype(place, /datum/ambient_place/outpost))
		return AMBIENT_OUTPOST_BODY_TIME
	if(istype(place, /datum/ambient_place/ship))
		return 0
	return HUMAN_NPC_CORPSE_LIFETIME

/// Their cash and death loot, once: a revived NPC killed again drops nothing
/mob/living/carbon/human/npc/ambient_npc/proc/drop_loot()
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
/mob/living/carbon/human/npc/ambient_npc/proc/get_lines(context)
	var/list/lines = ambient_dialogue_lines(dialogue_file, dialogue_section, context)
	if(!length(lines))
		lines = ambient_dialogue_lines(dialogue_file, "any", context)
	if(!length(lines) && dialogue_file != AMBIENT_STRINGS_CORE)
		lines = ambient_dialogue_lines(AMBIENT_STRINGS_CORE, dialogue_section, context)
	if(!length(lines))
		lines = ambient_dialogue_lines(AMBIENT_STRINGS_CORE, "default", context)
	return lines

/// A random two-person exchange from their section's "conversations": list(opener, reply), or null
/mob/living/carbon/human/npc/ambient_npc/proc/pick_conversation()
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
/mob/living/carbon/human/npc/ambient_npc/proc/speech_name()
	var/list/parts = splittext(real_name || name, " ")
	return length(parts) ? parts[1] : name

/// Fills a line's placeholders: {name} their first name, {other} who they talk to, {place} where they are
/mob/living/carbon/human/npc/ambient_npc/proc/fill_line(line, atom/other)
	line = replacetext(line, "{name}", speech_name())
	if(findtext(line, "{other}"))
		var/other_name = "friend"
		if(istype(other, /mob/living/carbon/human/npc/ambient_npc))
			var/mob/living/carbon/human/npc/ambient_npc/other_npc = other
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
/mob/living/carbon/human/npc/ambient_npc/proc/speak_context(context, atom/other, force = FALSE)
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
/mob/living/carbon/human/npc/ambient_npc/proc/say_line(line)
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
/mob/living/carbon/human/npc/ambient_npc/proc/reply_to(atom/movable/speaker, context = AMBIENT_LINE_REPLY, line)
	addtimer(CALLBACK(src, PROC_REF(do_reply), WEAKREF(speaker), context, line), rand(AMBIENT_REPLY_DELAY_LOW, AMBIENT_REPLY_DELAY_HIGH), TIMER_DELETE_ME)

/mob/living/carbon/human/npc/ambient_npc/proc/do_reply(datum/weakref/speaker_ref, context, line)
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

// An empty hand talks to them while they are up and about; down, on fire or asleep it is tg's help
// (helping them up, patting out the flames, shaking them awake, CPR). Combat mode or a right click is
// the usual attack or shove.
/mob/living/carbon/human/npc/ambient_npc/attack_hand(mob/living/carbon/human/user, list/modifiers)
	if(!user.combat_mode && !LAZYACCESS(modifiers, RIGHT_CLICK) && can_be_talked_to())
		talked_to(user)
		return TRUE
	return ..()

/// Whether an empty hand talks to them now, rather than tg's help: up and about, and not on fire
/mob/living/carbon/human/npc/ambient_npc/proc/can_be_talked_to()
	return can_act() && !on_fire && body_position == STANDING_UP

/// Whether `user` may have another answer yet, and starts their wait if so
/mob/living/carbon/human/npc/ambient_npc/proc/talk_ready(mob/user)
	var/key = REF(user)
	if(LAZYACCESS(talk_cooldowns, key) > world.time)
		return FALSE
	LAZYSET(talk_cooldowns, key, world.time + AMBIENT_TALK_COOLDOWN)
	// A long round meets many people; forget the oldest
	if(length(talk_cooldowns) > 20)
		talk_cooldowns.Cut(1, 2)
	return TRUE

/// `user` talked to them (an empty hand). Override for a menu (a stray's "Come with us").
/mob/living/carbon/human/npc/ambient_npc/proc/talked_to(mob/living/user)
	if(!talk_ready(user))
		return
	if(!buckled)
		face_atom(user)
	speak_context(AMBIENT_LINE_TALK, user, force = TRUE)

// =========================================================================
// REACTIONS
// =========================================================================

/// Whether a reaction of `kind` may happen now, and starts its cooldown if so
/mob/living/carbon/human/npc/ambient_npc/proc/reaction_ready(kind, cooldown = AMBIENT_REACTION_COOLDOWN)
	if(LAZYACCESS(reaction_cooldowns, kind) > world.time)
		return FALSE
	LAZYSET(reaction_cooldowns, kind, world.time + cooldown)
	return TRUE

/mob/living/carbon/human/npc/ambient_npc/proc/on_attacked(datum/source, atom/attacker, attack_flags)
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
/mob/living/carbon/human/npc/ambient_npc/proc/react_attacked(atom/attacker)
	if(stat != CONSCIOUS || fading || !reaction_ready("attacked"))
		return
	speak_context(AMBIENT_LINE_ATTACKED, attacker, force = TRUE)
	if(istype(place, /datum/ambient_place/outpost))
		start_activity(new /datum/ambient_activity/leave(src, null, 1 SECONDS))

/**
 * A fight broke out near them at their outpost (COMSIG_TRADER_OUTPOST_VIOLENCE): they duck, then
 * head for the lift and leave. Override to stay (a barkeep). Never sleeps.
 */
/mob/living/carbon/human/npc/ambient_npc/proc/react_violence(mob/living/offender)
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
/mob/living/carbon/human/npc/ambient_npc/proc/react_shootout(turf/refuge)
	if(stat != CONSCIOUS || fading || istype(activity, /datum/ambient_activity/leave))
		return
	if(prob(40))
		speak_context(AMBIENT_LINE_COVER, null, force = TRUE)
	start_activity(new /datum/ambient_activity/take_cover(src, refuge))

/// The shootout is over: back to what they were doing
/mob/living/carbon/human/npc/ambient_npc/proc/shootout_over()
	if(istype(activity, /datum/ambient_activity/take_cover))
		end_activity()

/**
 * A storm is coming to their planet (COMSIG_WEATHER_TELEGRAPH): a shouted warning, which doubles
 * as a telegraph for players, then shelter or a crouch until it passes. Never sleeps.
 */
/mob/living/carbon/human/npc/ambient_npc/proc/react_storm(datum/weather/storm)
	if(stat != CONSCIOUS || fading || !reaction_ready("storm", 2 MINUTES))
		return
	speak_context(AMBIENT_LINE_STORM, null, force = TRUE)
	var/duration = 2 MINUTES
	if(istype(storm))
		duration = storm.telegraph_duration + storm.weather_duration_upper
	var/datum/ambient_place/site/site = place
	start_activity(new /datum/ambient_activity/shelter(src, istype(site) ? site.shelter : null, duration))

/// The supply convoy arrived at their outpost (COMSIG_TRADER_OUTPOST_CONVOY). Override: the dock workers (PA).
/mob/living/carbon/human/npc/ambient_npc/proc/react_convoy(obj/structure/overmap/trader_outpost/outpost)
	return

// =========================================================================
// BODY
// =========================================================================

/// Sits on `seat` from its tile
/mob/living/carbon/human/npc/ambient_npc/proc/sit_on(obj/structure/chair/seat)
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

/// Down on the floor: sitting, or ducking (a pixel shift; their body stays up)
/mob/living/carbon/human/npc/ambient_npc/proc/crouch()
	if(crouching || buckled || body_position == LYING_DOWN)
		return
	crouching = TRUE
	add_offsets(AMBIENT_NPC_TRAIT, y_add = -4)

/// Up from their seat or the floor. Only a seat they sat on themselves: never out of one someone put them in.
/mob/living/carbon/human/npc/ambient_npc/proc/stand_up()
	if(crouching)
		crouching = FALSE
		remove_offsets(AMBIENT_NPC_TRAIT)
	var/obj/structure/chair/seat = seat_ref?.resolve()
	seat_ref = null
	if(seat && buckled == seat)
		seat.unbuckle_mob(src, force = TRUE)
	if(resting && stat == CONSCIOUS)
		set_resting(FALSE, silent = TRUE)

/// A drink in hand, poured for them where they got it: a real glass, held in a hand
/mob/living/carbon/human/npc/ambient_npc/proc/take_drink(reagent_type = /datum/reagent/consumable/ethanol/beer)
	var/obj/item/reagent_containers/cup/glass/drinkingglass/glass = held_item
	if(!istype(glass) || QDELETED(glass) || !(glass in get_all_contents()))
		glass = new(src)
		glass.reagents.add_reagent(reagent_type, AMBIENT_DRINK_POUR)
		held_item = glass
	set_held(glass)
	return glass

/**
 * A gulp of their drink, swallowed as anyone swallows one (the glass's own drinking: the reagents go
 * into them, so drink makes them drunk and whatever else is in it does what it does). An empty glass
 * is poured again. FALSE with no drink in hand, or when they can't drink (a mask over the mouth).
 */
/mob/living/carbon/human/npc/ambient_npc/proc/sip()
	var/obj/item/reagent_containers/cup/glass/drinkingglass/glass = held_item
	if(!istype(glass) || QDELETED(glass) || !is_holding(glass))
		return FALSE
	if(!glass.reagents.total_volume)
		glass.reagents.add_reagent(/datum/reagent/consumable/ethanol/beer, AMBIENT_DRINK_POUR)
		return TRUE
	if(!glass.canconsume(src, src))
		return FALSE
	glass.attack(src, src)
	return TRUE

/**
 * Sets their drink down on `table` if it is right there, up to AMBIENT_GLASSES_MAX glasses of
 * theirs and AMBIENT_TABLE_GLASSES_MAX on the table; otherwise it just goes.
 */
/mob/living/carbon/human/npc/ambient_npc/proc/put_drink_down(obj/structure/table/table)
	var/obj/item/glass = held_item
	held_item = null
	set_held(null)
	if(QDELETED(glass))
		return
	if(stat == CONSCIOUS && glasses_left < AMBIENT_GLASSES_MAX && !QDELETED(table) && isturf(table.loc) && isturf(loc) && Adjacent(table))
		var/on_table = 0
		for(var/obj/item/reagent_containers/cup/glass/other in table.loc)
			on_table++
		if(on_table < AMBIENT_TABLE_GLASSES_MAX && transferItemToLoc(glass, table.loc, force = TRUE))
			glasses_left++
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
