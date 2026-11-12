/**
 * # Outpost jobs: sabotage
 *
 * Owner: P3. Spec 6.1: a set of things the job places at the outpost, each with a keeper who minds it; ruining
 * every one of them is the deed.
 *
 * - /datum/mission/fixer_job/sabotage: picks a set for the outpost's zone, places it and its keeper (stage()), hears
 *   each target go (target_ruined()), and cleans up after itself (unstage()).
 * - /obj/structure/fixer_target and its three sets (crates, a drinks machine, a drive rack): anchored, unpullable,
 *   job-placed so they are not outpost property. Broken or tampered into a wreck, never deleted by the blow. Each
 *   damaging hit and each tamper step is a sabotage crime through register_aggression(), the target as victim.
 * - /mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper and its three looks: a townsperson witness who works
 *   at the target, takes a break now and then (that is the window) and reacts when it is wrecked.
 *
 * Existing sprites only. crates.dmi: "crate" (whole, with the "manifest" tag overlay) and "crateopen" (lid off).
 * vending.dmi: "soda-off" (whole, under a pale film overlay) and "soda-broken". research.dmi: "server" (whole) and
 * "server-nopower" (ruined, darkened).
 *
 * Include order: this file compiles before outpost_police, overmap, player_outposts and trade. Calls and subtypes
 * of those are fine; nothing here overrides a proc first declared there.
 */

/// The three sets
#define SABOTAGE_SET_CRATES "crates"
#define SABOTAGE_SET_KIOSK "kiosk"
#define SABOTAGE_SET_RACK "rack"
/// Crates in the consignment
#define SABOTAGE_CRATE_COUNT 3
/// A keeper on a break goes at least this far from what he minds, and looks for somewhere out of its sight
#define SABOTAGE_BREAK_MIN_DIST 7
#define SABOTAGE_BREAK_MAX_DIST 26
#define SABOTAGE_BREAK_SIGHT 12
/// Break spots looked at in one search
#define SABOTAGE_BREAK_TRIES 40
/// A wreck or crate that is let go waits this long, then goes the first time nobody is watching it
#define SABOTAGE_CART_DELAY (5 SECONDS)
#define SABOTAGE_CART_RETRY (30 SECONDS)
#define SABOTAGE_CART_TRIES 20
/// The film over the new drinks machine: the sprite again as one pale flat colour, half see-through
#define SABOTAGE_FILM_ALPHA 130
#define SABOTAGE_FILM_COLOR list(0, 0, 0, 0, 0, 0, 0, 0, 0, 0.88, 0.93, 1)
/// What the ruined drive rack is darkened by
#define SABOTAGE_SCORCH_COLOR "#8c8c8c"

// =========================================================================
// STRINGS
// =========================================================================

/// Puts job_sabotage.json in the string cache. ambient_dialogue_lines() only looks in the ambient folder, so a keeper
/// loads this first (a file missing from that folder is never asked for twice).
/proc/job_sabotage_strings()
	if(!(FIXER_STRINGS_SABOTAGE in GLOB.string_cache))
		load_strings_file(FIXER_STRINGS_SABOTAGE, FIXER_STRINGS_DIR)

/// `text` cut to `bound` characters with an ellipsis and html-encoded, for the offer's tokens and the note
/proc/job_sabotage_bound(text, bound)
	var/cut = length_char(text) > bound ? "[copytext_char(text, 1, bound)]…" : text
	return html_encode(cut)

// =========================================================================
// THE JOB
// =========================================================================

/datum/mission/fixer_job/sabotage
	job_kind = FIXER_JOB_SABOTAGE
	base_pay = FIXER_PAY_SABOTAGE
	duration = FIXER_TIME_SABOTAGE
	slate_weight = FIXER_WEIGHT_SABOTAGE
	scene_crimes = list(OUTPOST_CRIME_SABOTAGE)
	/// SABOTAGE_SET_*, chosen once for the outpost (ensure_set())
	var/set_kind
	/// Weakrefs to the targets, whole or wrecked
	var/list/datum/weakref/targets = list()
	/// Weakref to the keeper
	var/datum/weakref/keeper_ref
	/// unstage() has run
	var/unstaged = FALSE

/datum/mission/fixer_job/sabotage/Destroy()
	. = ..()
	// A wreck must never be left behind with nobody to clear it, whether or not the base's Destroy() unstaged
	if(!unstaged)
		unstage()
	targets = null
	keeper_ref = null

/// The zone of `outpost` (the job's own by default), green when it is not known
/datum/mission/fixer_job/sabotage/proc/outpost_zone(obj/structure/overmap/trader_outpost/outpost)
	outpost ||= job_outpost
	var/zone = outpost ? SSovermap_zones?.get_zone_type_anywhere(get_turf(outpost)) : null
	return (zone in list(ZONE_GREEN, ZONE_YELLOW, ZONE_RED)) ? zone : ZONE_GREEN

/// The sets this outpost's zone can have: the drinks machine in green and yellow, the drive rack in yellow and red, crates anywhere
/datum/mission/fixer_job/sabotage/proc/sets_for(obj/structure/overmap/trader_outpost/outpost)
	var/zone = outpost_zone(outpost)
	. = list(SABOTAGE_SET_CRATES)
	if(zone != ZONE_RED)
		. += SABOTAGE_SET_KIOSK
	if(zone != ZONE_GREEN)
		. += SABOTAGE_SET_RACK

/// Picks the set once, from what the outpost's zone allows
/datum/mission/fixer_job/sabotage/proc/ensure_set()
	if(set_kind)
		return set_kind
	set_kind = pick(sets_for(job_outpost))
	return set_kind

/// The target type of the chosen set
/datum/mission/fixer_job/sabotage/proc/target_type()
	switch(ensure_set())
		if(SABOTAGE_SET_KIOSK)
			return /obj/structure/fixer_target/kiosk
		if(SABOTAGE_SET_RACK)
			return /obj/structure/fixer_target/rack
	return /obj/structure/fixer_target/crate

/// The keeper type of the chosen set
/datum/mission/fixer_job/sabotage/proc/keeper_type()
	switch(ensure_set())
		if(SABOTAGE_SET_KIOSK)
			return /mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/fitter
		if(SABOTAGE_SET_RACK)
			return /mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/courier
	return /mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/dock_hand

/// The firm whose property it is, and what it looks like, for the offer and the note
/datum/mission/fixer_job/sabotage/proc/set_firm()
	switch(ensure_set())
		if(SABOTAGE_SET_KIOSK)
			return "Brightline"
		if(SABOTAGE_SET_RACK)
			return "Corvane Couriers"
	return "Kessler Haulage"

/datum/mission/fixer_job/sabotage/proc/set_look()
	switch(ensure_set())
		if(SABOTAGE_SET_KIOSK)
			return "a drinks machine in its film"
		if(SABOTAGE_SET_RACK)
			return "a rack of sealed drives"
	return "three sealed freight crates"

/// The `index`th target if it is still there
/datum/mission/fixer_job/sabotage/proc/live_target_at(index)
	if(index < 1 || index > length(targets))
		return null
	var/datum/weakref/ref = targets[index]
	var/obj/structure/fixer_target/target = ref?.resolve()
	return QDELETED(target) ? null : target

/// Where the set stands, as the note says it: a side of the concourse
/datum/mission/fixer_job/sabotage/proc/set_side()
	var/obj/structure/fixer_target/first = live_target_at(1)
	var/list/bounds = job_outpost ? bounty_outpost_bounds(job_outpost) : null
	if(!first || length(bounds) < 5)
		return "the concourse"
	var/centre_x = (bounds[1] + bounds[3]) / 2
	var/centre_y = (bounds[2] + bounds[4]) / 2
	var/dx = first.x - centre_x
	var/dy = first.y - centre_y
	var/side = abs(dx) >= abs(dy) ? (dx >= 0 ? "east" : "west") : (dy >= 0 ? "north" : "south")
	return ensure_set() == SABOTAGE_SET_CRATES ? "the [side] end" : "the [side] wall"

/datum/mission/fixer_job/sabotage/allowed_at(obj/structure/overmap/trader_outpost/outpost, datum/voidcrew_crew_record/crew)
	return !!length(sets_for(outpost))

/// What the offer says, before the job is staged: the firm, what it looks like, when it must be done by, and the outpost
/datum/mission/fixer_job/sabotage/offer_tokens()
	var/clock = station_time_timestamp("hh:mm", (time_started || world.time) + duration)
	return list(
		FIXER_TOKEN_NAME = job_sabotage_bound(set_firm(), FIXER_BOUND_NAME),
		FIXER_TOKEN_LOOK = job_sabotage_bound(set_look(), FIXER_BOUND_LOOK),
		FIXER_TOKEN_CLOCK = clock,
		FIXER_TOKEN_PLACE = job_sabotage_bound(job_outpost?.name || "the outpost", FIXER_BOUND_PLACE),
	)

/// The note, written once the set stands: who, where on the concourse, by when
/datum/mission/fixer_job/sabotage/note_lines()
	var/clock = station_time_timestamp("hh:mm", (time_started || world.time) + duration)
	return list(
		job_sabotage_bound("[set_firm()]. [capitalize(set_look())].", FIXER_BOUND_NOTE_LINE),
		job_sabotage_bound("[capitalize(set_side())]. Gone by [clock].", FIXER_BOUND_NOTE_LINE),
	)

// ----- staging -----

/datum/mission/fixer_job/sabotage/stage()
	if(QDELETED(job_outpost))
		return FALSE
	var/crates = ensure_set() == SABOTAGE_SET_CRATES
	var/wanted = crates ? SABOTAGE_CRATE_COUNT : 1
	var/list/turf/spots = fixer_job_spot(job_outpost, crates ? FIXER_SPOT_OPEN : FIXER_SPOT_WALL, null, wanted)
	if(length(spots) < wanted)
		return FALSE
	if(!build_targets(spots) || !build_keeper(spots))
		unstage()
		return FALSE
	return TRUE

/// Puts the set on `spots`, one target each, each bound to this job and tracked for the scene reading
/datum/mission/fixer_job/sabotage/proc/build_targets(list/turf/spots)
	var/target_path = target_type()
	targets = list()
	for(var/turf/spot as anything in spots)
		var/obj/structure/fixer_target/target = new target_path(spot)
		target.bind_job(src)
		targets += WEAKREF(target)
		track(target)
	unstaged = FALSE
	return length(targets) > 0

/// A free tile close to the first target that is none of `avoid`, or null
/datum/mission/fixer_job/sabotage/proc/keeper_spot(list/turf/avoid)
	var/obj/structure/fixer_target/anchor = live_target_at(1)
	var/turf/centre = get_turf(anchor)
	if(!centre)
		return null
	var/list/near = list()
	for(var/turf/tile as anything in RANGE_TURFS(2, centre))
		if(tile == centre || (tile in avoid) || !ambient_ground_ok(tile))
			continue
		near[tile] = get_dist(tile, centre)
	if(!length(near))
		return null
	near = sortTim(near, GLOBAL_PROC_REF(cmp_numeric_asc), associative = TRUE)
	var/list/nearest = list()
	for(var/turf/tile as anything in near)
		nearest += tile
		if(length(nearest) >= 3)
			break
	return pick(nearest)

/// Makes the keeper beside the set and sets him at work. FALSE if there was no room or he could not be made.
/datum/mission/fixer_job/sabotage/proc/build_keeper(list/turf/avoid)
	var/turf/spot = keeper_spot(avoid)
	if(!spot)
		return FALSE
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/keeper = ambient_build_npc(keeper_type(), spot, outpost_zone())
	if(QDELETED(keeper))
		return FALSE
	fixer_job_npc_setup(keeper, src)
	keeper.target_refs = targets.Copy()
	keeper_ref = WEAKREF(keeper)
	keeper.settle_in()
	return TRUE

/**
 * Sends the keeper off the floor and lets every target go: the wreck, or the crates that were never touched, is
 * carted off once nobody is looking at it. Nothing is deleted under a player's eyes. Safe to call twice.
 */
/datum/mission/fixer_job/sabotage/unstage()
	if(unstaged)
		return ..()
	unstaged = TRUE
	for(var/datum/weakref/ref as anything in targets)
		var/obj/structure/fixer_target/target = ref?.resolve()
		if(QDELETED(target))
			continue
		// The base deletes whatever is still tracked at once
		job_atoms?.Remove(ref)
		target.release()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/keeper = keeper_ref?.resolve()
	if(!QDELETED(keeper))
		job_atoms?.Remove(keeper_ref)
		keeper.send_away()
	return ..()

/datum/mission/fixer_job/sabotage/on_deadline()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/keeper = keeper_ref?.resolve()
	if(!QDELETED(keeper) && keeper.stat == CONSCIOUS)
		keeper.speak_context("collect", null, force = TRUE)
	return ..()

// ----- the deed -----

/// `target` was ruined: an outsider's hand spoils the job, the keeper reacts, and the last one ruined is the deed
/datum/mission/fixer_job/sabotage/proc/target_ruined(obj/structure/fixer_target/target)
	if(QDELETED(src) || deed_done || failed || completed)
		return
	var/datum/mind/who = target.hand_ref?.resolve()
	if(who && !on_roster(who))
		spoil(who.current)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/keeper = keeper_ref?.resolve()
	if(!QDELETED(keeper))
		keeper.react_wreck(target)
	check_done(who?.current)

/// `target` was deleted some way other than a blow or a tamper (a singularity, an admin): it counts as gone
/datum/mission/fixer_job/sabotage/proc/target_gone(obj/structure/fixer_target/target)
	if(QDELETED(src) || deed_done || failed || completed)
		return
	check_done(null)

/// If every target is ruined (or gone) the deed is done, by `doer`
/datum/mission/fixer_job/sabotage/proc/check_done(mob/living/doer)
	if(!length(targets))
		return
	for(var/datum/weakref/ref as anything in targets)
		var/obj/structure/fixer_target/target = ref?.resolve()
		if(!QDELETED(target) && !target.ruined)
			return
	mark_deed(doer)

// =========================================================================
// THE TARGETS
// =========================================================================

/**
 * A sabotage target the job placed. Anchored, cannot be pulled or pushed, not outpost property (it did not exist when
 * the outpost loaded). Enough damage, or the right tools for long enough, ruin it: it is wrecked where it stands, never
 * deleted by the blow. Every damaging hit and every tamper step is the sabotage crime, with it as the victim, done by
 * whoever struck it; the last player to hit or tamper is the hand that ruined it.
 */
/obj/structure/fixer_target
	name = "freight crate"
	desc = "A sealed freight crate with a Kessler Haulage tag."
	icon = 'icons/obj/storage/crates.dmi'
	icon_state = "crate"
	density = TRUE
	anchored = TRUE
	max_integrity = FIXER_TARGET_INTEGRITY
	move_resist = INFINITY
	// An acid pool or a fire would delete it with deconstruct(); a blow ruins it instead (atom_destruction())
	resistance_flags = UNACIDABLE | ACID_PROOF
	/// The state it is shown in whole and ruined
	var/whole_state = "crate"
	var/ruined_state = "crateopen"
	/// The description it has once ruined
	var/ruined_desc = "A freight crate with its lid torn off. Whatever was in it is ruined."
	/// Ruined: wrecked where it stands, whatever its job does
	var/ruined = FALSE
	/// Weakref to the job. Weak: the wreck outlives the job.
	var/datum/weakref/job_ref
	/// Weakref to the mind of the last player to hit or tamper with it
	var/datum/weakref/hand_ref
	/// Weakref to what they used
	var/datum/weakref/tool_ref
	/// A blow or tamper by a player is under way: its crime is reported when it lands
	var/hit_pending = FALSE
	/// The crime of this blow has been reported already (the destroying blow)
	var/hit_reported = FALSE
	/// The job let it go: it waits to be carted off
	var/released = FALSE
	var/cart_timer
	var/cart_tries = 0
	/// The steps of tampering, in order: list(TOOL_*, time). The next step is `tamper_index`.
	var/list/tamper_steps = list()
	var/tamper_index = 1

/obj/structure/fixer_target/Initialize(mapload)
	. = ..()
	update_appearance()

/obj/structure/fixer_target/Destroy()
	var/datum/mission/fixer_job/sabotage/job = job_ref?.resolve()
	job_ref = null
	hand_ref = null
	tool_ref = null
	if(!QDELETED(job) && !ruined && !released)
		job.target_gone(src)
	return ..()

/// The job this is part of
/obj/structure/fixer_target/proc/bind_job(datum/mission/fixer_job/sabotage/job)
	job_ref = WEAKREF(job)

/// Nobody drags, pushes or unfastens a job's target
/obj/structure/fixer_target/can_be_pulled(user, force)
	return FALSE

/obj/structure/fixer_target/update_icon_state()
	icon_state = ruined ? ruined_state : whole_state
	return ..()

// ----- the blows -----

/// `user`, if a player, struck or tampered with it using `tool`: they are the hand, and what they do now is a crime
/obj/structure/fixer_target/proc/note_hand(mob/living/user, obj/item/tool)
	hit_pending = FALSE
	if(!user?.mind || released)
		return
	hit_pending = TRUE
	hand_ref = WEAKREF(user.mind)
	tool_ref = tool ? WEAKREF(tool) : null

/// The player who is the hand now, if there is one
/obj/structure/fixer_target/proc/hand_mob()
	var/datum/mind/who = hand_ref?.resolve()
	return who?.current

/// The trader outpost this stands in
/obj/structure/fixer_target/proc/home_outpost()
	var/datum/mission/fixer_job/sabotage/job = job_ref?.resolve()
	if(!QDELETED(job) && !QDELETED(job.job_outpost))
		return job.job_outpost
	return get_trader_outpost_for_turf(get_turf(src))

/// The sabotage crime of the blow or tamper step now, by the hand, with this as its victim
/obj/structure/fixer_target/proc/report_sabotage()
	hit_reported = TRUE
	var/mob/living/offender = hand_mob()
	if(!offender?.mind)
		return
	var/obj/item/tool = tool_ref?.resolve()
	var/obj/structure/overmap/trader_outpost/outpost = home_outpost()
	outpost?.register_aggression(offender, OUTPOST_CRIME_SABOTAGE, src, isitem(tool) ? tool : null)

/obj/structure/fixer_target/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	note_hand(user, attacking_item)
	. = ..()
	hit_pending = FALSE

/obj/structure/fixer_target/attack_generic(mob/user, damage_amount = 0, damage_type = BRUTE, damage_flag = 0, sound_effect = 1, armor_penetration = 0)
	note_hand(isliving(user) ? user : null, null)
	. = ..()
	hit_pending = FALSE

/obj/structure/fixer_target/attack_hulk(mob/living/carbon/human/user)
	note_hand(user, null)
	. = ..()
	hit_pending = FALSE

/obj/structure/fixer_target/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	var/obj/item/fired_from = hitting_projectile.fired_from
	note_hand(isliving(hitting_projectile.firer) ? hitting_projectile.firer : null, isitem(fired_from) ? fired_from : null)
	. = ..()
	hit_pending = FALSE

/obj/structure/fixer_target/hitby(atom/movable/hit_by, skipcatch, hitpush, blocked, datum/thrownthing/throwingdatum)
	var/mob/living/thrower = throwingdatum?.thrower?.resolve()
	note_hand(isliving(thrower) ? thrower : null, isitem(hit_by) ? hit_by : null)
	. = ..()
	hit_pending = FALSE

/obj/structure/fixer_target/take_damage(damage_amount, damage_type = BRUTE, damage_flag = "", sound_effect = TRUE, attack_dir, armour_penetration = 0)
	var/was_ruined = ruined
	hit_reported = FALSE
	. = ..()
	// A blow that did damage is a crime (the one that wrecks it is reported in atom_destruction())
	if(. && hit_pending && !was_ruined && !hit_reported)
		report_sabotage()
	hit_reported = FALSE

/// Its integrity is gone: it is ruined, not deleted
/obj/structure/fixer_target/atom_destruction(damage_flag)
	SHOULD_CALL_PARENT(FALSE) // the parent deconstructs it, which deletes it
	if(ruined)
		return
	if(hit_pending)
		report_sabotage()
	ruin()

// ----- the quiet way -----

/obj/structure/fixer_target/crowbar_act(mob/living/user, obj/item/tool)
	return tamper_with(user, tool)

/obj/structure/fixer_target/screwdriver_act(mob/living/user, obj/item/tool)
	return tamper_with(user, tool)

/obj/structure/fixer_target/wirecutter_act(mob/living/user, obj/item/tool)
	return tamper_with(user, tool)

/obj/structure/fixer_target/multitool_act(mob/living/user, obj/item/tool)
	return tamper_with(user, tool)

/// How long `tool`'s next tamper step takes, or 0 if it is not the next step (or nothing is left to do)
/obj/structure/fixer_target/proc/step_time(obj/item/tool)
	if(ruined || released || tamper_index < 1 || tamper_index > length(tamper_steps))
		return 0
	var/list/step = tamper_steps[tamper_index]
	return tool?.tool_behaviour == step[1] ? step[2] : 0

/// Works at the next step with `tool` for as long as it takes. A tool that is not the next step does nothing here.
/obj/structure/fixer_target/proc/tamper_with(mob/living/user, obj/item/tool)
	var/time = step_time(tool)
	if(!time)
		return NONE
	// Tampering makes no sound of its own: a tool's sound is a noise officers come to look at
	if(!tool.use_tool(src, user, time, volume = 0))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src) || ruined || released)
		return ITEM_INTERACT_BLOCKING
	advance_tamper(user, tool)
	return ITEM_INTERACT_SUCCESS

/**
 * One tamper step done with `tool` by `user`: the crime, then the next step, or the ruin after the last. FALSE if it
 * is not the next step. The part of tamper_with() after the wait, so a test can call it.
 */
/obj/structure/fixer_target/proc/advance_tamper(mob/living/user, obj/item/tool)
	if(!step_time(tool))
		return FALSE
	note_hand(user, tool)
	if(hit_pending)
		report_sabotage()
	hit_pending = FALSE
	tamper_index++
	if(tamper_index > length(tamper_steps))
		ruin()
	else
		update_appearance()
	return TRUE

// ----- ruined -----

/// Wrecks it where it stands. The hand that ruined it is the last player to hit or tamper with it.
/obj/structure/fixer_target/proc/ruin()
	if(ruined)
		return
	ruined = TRUE
	// Wrecked for good: nothing more does anything to it, and a spent integrity cannot be hit again
	resistance_flags |= INDESTRUCTIBLE
	if(get_integrity() <= 0)
		repair_damage(1)
	desc = ruined_desc
	spill()
	update_appearance()
	var/datum/mission/fixer_job/sabotage/job = job_ref?.resolve()
	if(!QDELETED(job))
		job.target_ruined(src)

/// What spills or sparks when it goes. Override.
/obj/structure/fixer_target/proc/spill()
	playsound(src, 'sound/effects/bang.ogg', 50, TRUE)

// ----- let go -----

/// The job is over: it waits to be carted off, wreck or whole, the first time nobody is watching it
/obj/structure/fixer_target/proc/release()
	if(released)
		return
	released = TRUE
	job_ref = null
	resistance_flags |= INDESTRUCTIBLE
	cart_timer = addtimer(CALLBACK(src, PROC_REF(cart_off)), SABOTAGE_CART_DELAY, TIMER_STOPPABLE | TIMER_DELETE_ME)

/// Carted off: gone, unless a player is looking, in which case it is tried again later
/obj/structure/fixer_target/proc/cart_off()
	cart_timer = null
	if(QDELETED(src))
		return
	if(human_npc_watched(src) && ++cart_tries < SABOTAGE_CART_TRIES)
		cart_timer = addtimer(CALLBACK(src, PROC_REF(cart_off)), SABOTAGE_CART_RETRY, TIMER_STOPPABLE | TIMER_DELETE_ME)
		return
	qdel(src)

// ----- the consignment -----

/// One of three sealed freight crates side by side, tagged for a haulage firm
/obj/structure/fixer_target/crate
	name = "freight crate"
	desc = "A sealed freight crate with a Kessler Haulage tag."
	icon = 'icons/obj/storage/crates.dmi'
	icon_state = "crate"
	whole_state = "crate"
	ruined_state = "crateopen"
	ruined_desc = "A freight crate with its lid torn off. Whatever was in it is ruined."
	tamper_steps = list(list(TOOL_CROWBAR, FIXER_TAMPER_CRATE))

/obj/structure/fixer_target/crate/update_overlays()
	. = ..()
	if(!ruined)
		. += mutable_appearance(icon, "manifest")

/obj/structure/fixer_target/crate/spill()
	. = ..()
	visible_message(span_danger("The lid of [src] bursts and the goods spill out."))
	var/turf/where = get_turf(src)
	if(!where)
		return
	for(var/scrap in 1 to rand(1, 2))
		new /obj/item/trash/can(where)

// ----- the drinks machine -----

/// A new drinks machine still in its delivery film
/obj/structure/fixer_target/kiosk
	name = "drinks machine"
	desc = "A drinks machine, still in its delivery film."
	icon = 'icons/obj/machines/vending.dmi'
	icon_state = "soda-off"
	whole_state = "soda-off"
	ruined_state = "soda-broken"
	ruined_desc = "Its front is dark and it smells of burnt plastic."
	tamper_steps = list(list(TOOL_SCREWDRIVER, FIXER_TAMPER_KIOSK), list(TOOL_WIRECUTTER, FIXER_TAMPER_KIOSK))

/obj/structure/fixer_target/kiosk/update_overlays()
	. = ..()
	if(!ruined)
		var/mutable_appearance/film = mutable_appearance(icon, "soda-off", alpha = SABOTAGE_FILM_ALPHA)
		film.color = SABOTAGE_FILM_COLOR
		. += film

/obj/structure/fixer_target/kiosk/examine(mob/user)
	. = ..()
	if(!ruined && tamper_index > 1)
		. += span_notice("Its service panel hangs open.")

/obj/structure/fixer_target/kiosk/spill()
	. = ..()
	do_sparks(3, TRUE, src)
	visible_message(span_danger("[src] sparks and goes dark."))
	var/turf/where = get_turf(src)
	if(!where)
		return
	var/list/spots = list(where)
	for(var/turf/next as anything in get_adjacent_open_turfs(where))
		spots += next
	for(var/can in 1 to rand(2, FIXER_KIOSK_CANS))
		var/obj/item/reagent_containers/cup/soda_cans/cola/dropped = new(pick(spots))
		dropped.pixel_x = rand(-6, 6)
		dropped.pixel_y = rand(-6, 6)

// ----- the drive rack -----

/// A courier firm's rack of sealed drives
/obj/structure/fixer_target/rack
	name = "drive rack"
	desc = "A rack of sealed drives with a courier firm's lock on it."
	icon = 'icons/obj/machines/research.dmi'
	icon_state = "server"
	whole_state = "server"
	ruined_state = "server-nopower"
	ruined_desc = "The drives are scorched."
	tamper_steps = list(list(TOOL_MULTITOOL, FIXER_TAMPER_RACK))

/obj/structure/fixer_target/rack/update_icon_state()
	. = ..()
	color = ruined ? SABOTAGE_SCORCH_COLOR : null

/obj/structure/fixer_target/rack/spill()
	. = ..()
	do_sparks(4, TRUE, src)
	visible_message(span_danger("The drives in [src] click and die."))

// =========================================================================
// THE KEEPER
// =========================================================================

/// A dock hand: overalls, a hi-vis vest and a plain black cap
/datum/outfit/job_keeper_dock_hand
	name = "Freight keeper (dock hand)"
	uniform = /obj/item/clothing/under/misc/overalls
	suit = /obj/item/clothing/suit/hazardvest
	head = /obj/item/clothing/head/soft/black
	shoes = /obj/item/clothing/shoes/workboots

/// A fitter: the engineers' hazard suit, a yellow hard hat and work boots
/datum/outfit/job_keeper_fitter
	name = "Freight keeper (fitter)"
	uniform = /obj/item/clothing/under/rank/engineering/engineer/hazard
	head = /obj/item/clothing/head/utility/hardhat
	shoes = /obj/item/clothing/shoes/workboots

/// A courier: a black jumpsuit, a leather jacket and a leather satchel on the back
/datum/outfit/job_keeper_courier
	name = "Freight keeper (courier)"
	uniform = /obj/item/clothing/under/color/black
	suit = /obj/item/clothing/suit/jacket/leather
	back = /obj/item/storage/backpack/satchel/leather
	shoes = /obj/item/clothing/shoes/sneakers/black

/**
 * The person who minds a sabotage target (spec 6.1). A townsperson like any other at the outpost: a witness who
 * reports in a moment, killable, and hurting him is assault on a civilian. He works at the target, now and then
 * walks off for a minute or so (the window), and does something about a wreck.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper
	desc = "Minds the freight."
	dialogue_file = FIXER_STRINGS_SABOTAGE
	dialogue_section = "dock_hand"
	outfit_choices = list(/datum/outfit/job_keeper_dock_hand)
	/// Weakrefs to what he minds
	var/list/datum/weakref/target_refs
	/// world.time he next walks off
	var/next_break_at = 0
	/// What he does at the target: list(list(prop type or null, list of emotes), ...)
	var/list/tend_modes = list(list(null, list("looks the freight over.")))
	/// He packs up and goes when it is wrecked, instead of fetching an officer
	var/packs_up_on_wreck = FALSE

/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/Initialize(mapload, datum/human_npc_order/order)
	// Before anything speaks: ambient_dialogue_lines() reads only its own folder
	job_sabotage_strings()
	. = ..()
	next_break_at = world.time + rand(FIXER_KEEPER_BREAK_LOW, FIXER_KEEPER_BREAK_HIGH)

/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/Destroy()
	target_refs = null
	return ..()

/// The targets he minds that are still whole
/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/proc/live_targets()
	. = list()
	for(var/datum/weakref/ref as anything in target_refs)
		var/obj/structure/fixer_target/target = ref?.resolve()
		if(!QDELETED(target) && !target.ruined && !target.released)
			. += target

/// Something to do at the target: a prop in hand and what he does with it
/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/proc/pick_tend_mode()
	return length(tend_modes) ? pick(tend_modes) : list(null, list("looks the freight over."))

// Staff duck when a fight starts and carry on: he does not leave his post
/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/react_violence(mob/living/offender)
	if(stat != CONSCIOUS || fading || istype(activity, /datum/ambient_activity/leave) || !reaction_ready("violence"))
		return
	if(!start_activity(new /datum/ambient_activity/duck(src, offender)))
		return
	if(!buckled)
		face_atom(offender)
	crouch()
	if(prob(50))
		speak_context(AMBIENT_LINE_VIOLENCE, offender, force = TRUE)

/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/react_attacked(atom/attacker)
	if(stat != CONSCIOUS || fading || !reaction_ready("attacked"))
		return
	speak_context(AMBIENT_LINE_ATTACKED, attacker, force = TRUE)

/// Tends the target, now and then takes a break. With nothing left to mind he goes about as anyone does.
/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/pick_activity()
	var/list/live = live_targets()
	if(!length(live))
		return ..()
	if(world.time >= next_break_at)
		next_break_at = world.time + rand(FIXER_KEEPER_BREAK_LOW, FIXER_KEEPER_BREAK_HIGH)
		if(start_activity(new /datum/ambient_activity/job_break(src, pick(live))))
			return activity
	return pick_anchored(list(/datum/ambient_activity/tend_job = 6, /datum/ambient_activity/wander = 1, /datum/ambient_activity/idle = 1), pick(live))

/// Found already at the target when players come
/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/settle_in()
	var/list/live = live_targets()
	if(length(live))
		var/obj/structure/fixer_target/target = pick(live)
		if(settle_at(/datum/ambient_activity/tend_job, target, AMBIENT_SETTLE_TRIES, target, 3))
			return TRUE
	return ..()

/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/shift_times(delay)
	. = ..()
	next_break_at = ambient_shifted(next_break_at, delay)

/// What he does when `target` is ruined: swears and goes for an officer, or (the fitter) throws up his hands and packs up
/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/proc/react_wreck(obj/structure/fixer_target/target)
	if(stat != CONSCIOUS || fading || !reaction_ready("wreck", 15 SECONDS))
		return
	if(packs_up_on_wreck)
		speak_context("wreck", target, force = TRUE)
		manual_emote("throws up [p_their()] hands.")
		set_held(/obj/item/storage/toolbox/mechanical)
		start_activity(new /datum/ambient_activity/leave(src, null, 4 SECONDS))
		return
	start_activity(new /datum/ambient_activity/job_wreck(src, target))

/// The job is over: he goes, as anyone does at the end of a shift, and minds nothing any more
/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/proc/send_away()
	target_refs = null
	if(stat == CONSCIOUS)
		fade_out()

/// The dock hand: a clipboard, a sandwich on the crate he was told to watch
/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/dock_hand
	desc = "A dock hand with a clipboard and a pen behind the ear."
	dialogue_section = "dock_hand"
	outfit_choices = list(/datum/outfit/job_keeper_dock_hand)
	tend_modes = list(
		list(/obj/item/clipboard, list("ticks something off the manifest.", "counts the crates again.")),
		list(/obj/item/food/sandwich, list("takes a bite of a sandwich.", "chews, watching the crates.")),
	)

/// The fitter: a toolbox, a wrench, a can from the machine he is installing
/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/fitter
	desc = "A fitter in a hard hat, with a toolbox at his feet."
	dialogue_section = "fitter"
	outfit_choices = list(/datum/outfit/job_keeper_fitter)
	packs_up_on_wreck = TRUE
	tend_modes = list(
		list(/obj/item/wrench, list("tightens a bolt.", "checks the level.")),
		list(/obj/item/reagent_containers/cup/soda_cans/cola, list("takes a swig from a can.", "gives the can a shake and nods.")),
	)

/// The courier: stands by the rack, a satchel on one shoulder
/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/courier
	desc = "A courier in a dark jacket, a satchel over one shoulder."
	dialogue_section = "courier"
	outfit_choices = list(/datum/outfit/job_keeper_courier)
	tend_modes = list(
		list(null, list("checks the seal.", "glances at the lock.", "looks around the room.")),
	)

// =========================================================================
// WHAT THE KEEPER DOES
// =========================================================================

/// Stands by the target with something in hand and a word now and then
/datum/ambient_activity/tend_job
	name = "minding the job"
	accepts_company = TRUE
	duration_low = 45 SECONDS
	duration_high = 2 MINUTES
	/// list(prop type or null, list of emotes)
	var/list/mode
	var/next_beat = 0

/datum/ambient_activity/tend_job/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/keeper = doer
	if(!istype(keeper))
		return FALSE
	var/obj/structure/fixer_target/target = anchor()
	if(!istype(target) || target.ruined || target.released)
		var/list/live = keeper.live_targets()
		target = length(live) ? pick(live) : null
	if(!target)
		return FALSE
	anchor_ref = WEAKREF(target)
	var/turf/stand = keeper.free_tile_beside(target, 1, failed_spots)
	if(!stand)
		return FALSE
	go_to(stand)
	set_duration()
	mode = keeper.pick_tend_mode()
	next_beat = world.time + rand(6 SECONDS, 14 SECONDS)
	next_line = world.time + rand(10 SECONDS, 30 SECONDS)
	return TRUE

/datum/ambient_activity/tend_job/Destroy()
	mode = null
	return ..()

/datum/ambient_activity/tend_job/arrive()
	var/atom/target = anchor()
	if(target && !doer.buckled)
		doer.face_atom(target)
	doer.set_held(length(mode) ? mode[1] : null)

/datum/ambient_activity/tend_job/act(seconds)
	var/obj/structure/fixer_target/target = anchor()
	if(!istype(target) || target.ruined || target.released)
		return AMBIENT_STEP_DONE
	if(world.time >= next_beat)
		next_beat = world.time + rand(8 SECONDS, 18 SECONDS)
		if(!doer.buckled)
			doer.face_atom(target)
		var/list/emotes = length(mode) > 1 ? mode[2] : null
		if(length(emotes) && prob(70))
			doer.manual_emote(pick(emotes))
	chatter(AMBIENT_LINE_WORK, 25 SECONDS, 50 SECONDS)
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/tend_job/finish()
	if(!QDELETED(doer))
		doer.set_held(null)
	return ..()

/datum/ambient_activity/tend_job/shift_times(delay)
	. = ..()
	next_beat = ambient_shifted(next_beat, delay)

/**
 * A minute or two away from the target for a coffee or a word with someone: out of its sight where the floor has
 * such a place. That is the window.
 */
/datum/ambient_activity/job_break
	name = "on a break"
	accepts_company = TRUE
	/// How long he stays away once he is there
	var/away_for = 0
	var/next_sip = 0

/datum/ambient_activity/job_break/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/keeper = doer
	var/atom/target = anchor()
	if(!istype(keeper) || !target)
		return FALSE
	var/turf/spot = pick_spot(keeper, target)
	if(!spot)
		return FALSE
	go_to(spot)
	away_for = rand(FIXER_KEEPER_AWAY_LOW, FIXER_KEEPER_AWAY_HIGH)
	keeper.speak_context("break", null, force = TRUE)
	return TRUE

/// Somewhere to stand off: the coffee machine if there is one far enough, else a loiter tile out of the target's sight
/datum/ambient_activity/job_break/proc/pick_spot(mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/keeper, atom/target)
	var/turf/centre = get_turf(target)
	if(!centre)
		return null
	var/obj/structure/overmap/trader_outpost/outpost = keeper.get_outpost()
	var/obj/machinery/vending/coffee/machine = ambient_outpost_find(outpost, /obj/machinery/vending/coffee)
	if(machine && machine.z == centre.z && get_dist(machine, centre) >= SABOTAGE_BREAK_MIN_DIST)
		var/turf/beside = keeper.free_tile_beside(machine, 1, failed_spots)
		if(beside)
			return beside
	var/datum/ambient_place/outpost/outpost_place = keeper.place
	if(!istype(outpost_place))
		return null
	var/list/floor = outpost_place.get_loiter_floor()
	if(!length(floor))
		return null
	var/list/hidden = list()
	var/list/any = list()
	for(var/try_number in 1 to SABOTAGE_BREAK_TRIES)
		var/turf/tile = pick(floor)
		if(tile.z != centre.z)
			continue
		var/distance = get_dist(centre, tile)
		if(distance < SABOTAGE_BREAK_MIN_DIST || distance > SABOTAGE_BREAK_MAX_DIST || !keeper.loiter_spot_ok(tile, failed_spots))
			continue
		any += tile
		if(!can_see(centre, tile, SABOTAGE_BREAK_SIGHT))
			hidden += tile
	if(!length(any))
		return null
	return pick(length(hidden) ? hidden : any)

/datum/ambient_activity/job_break/arrive()
	ends_at = world.time + away_for
	doer.take_drink(/datum/reagent/consumable/coffee)
	next_sip = world.time + rand(6 SECONDS, 12 SECONDS)
	next_line = world.time + rand(10 SECONDS, 20 SECONDS)

/datum/ambient_activity/job_break/act(seconds)
	if(world.time >= next_sip)
		next_sip = world.time + rand(12 SECONDS, 25 SECONDS)
		doer.sip()
	chatter(AMBIENT_LINE_IDLE, 20 SECONDS, 40 SECONDS)
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/job_break/finish()
	if(!QDELETED(doer) && arrived && doer.stat == CONSCIOUS)
		doer.speak_context("back", null, force = TRUE)
	return ..()

/datum/ambient_activity/job_break/shift_times(delay)
	. = ..()
	next_sip = ambient_shifted(next_sip, delay)

/// A wreck: he swears, goes to the nearest officer and tells him
/datum/ambient_activity/job_wreck
	name = "reporting a wreck"
	priority = AMBIENT_PRIORITY_REACTION
	/// Weakref to the officer he is going to
	var/datum/weakref/officer_ref

/datum/ambient_activity/job_wreck/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/keeper = doer
	if(!istype(keeper))
		return FALSE
	var/obj/structure/overmap/trader_outpost/outpost = keeper.get_outpost()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer
	var/nearest = INFINITY
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/candidate as anything in outpost?.police?.officers)
		if(QDELETED(candidate) || candidate.stat == DEAD || candidate.z != keeper.z)
			continue
		var/distance = get_dist(keeper, candidate)
		if(distance < nearest)
			nearest = distance
			officer = candidate
	keeper.speak_context("wreck", anchor(), force = TRUE)
	// Up to half a minute to get to him; with no officer to be had, a few seconds of standing there swearing
	ends_at = world.time + (officer ? 30 SECONDS : 6 SECONDS)
	if(officer)
		officer_ref = WEAKREF(officer)
		go_to(get_turf(officer), 2)
	return TRUE

/datum/ambient_activity/job_wreck/arrive()
	var/mob/living/officer = officer_ref?.resolve()
	if(QDELETED(officer) || officer.stat != CONSCIOUS)
		return
	if(!doer.buckled)
		doer.face_atom(officer)
	doer.speak_context("officer", officer, force = TRUE)
	ends_at = world.time + 4 SECONDS

#undef SABOTAGE_SET_CRATES
#undef SABOTAGE_SET_KIOSK
#undef SABOTAGE_SET_RACK
#undef SABOTAGE_CRATE_COUNT
#undef SABOTAGE_BREAK_MIN_DIST
#undef SABOTAGE_BREAK_MAX_DIST
#undef SABOTAGE_BREAK_SIGHT
#undef SABOTAGE_BREAK_TRIES
#undef SABOTAGE_CART_DELAY
#undef SABOTAGE_CART_RETRY
#undef SABOTAGE_CART_TRIES
#undef SABOTAGE_FILM_ALPHA
#undef SABOTAGE_FILM_COLOR
#undef SABOTAGE_SCORCH_COLOR
