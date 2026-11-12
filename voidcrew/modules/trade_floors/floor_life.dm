/**
 * # Outpost floors: liveliness
 *
 * Owner: P8 (spec 12, items 8-10, 12 and 13). Strings: strings/floor_life.json.
 *
 * - **Tenants.** Every floor nobody holds is let to a named NPC business (name_tenants(), from the outpost's own list).
 *   Their people are ordinary concourse traffic: a clerk with a folder or a courier with a parcel steps off the lift,
 *   does business at a counter, sits a while and goes back up. They are an outpost role (/datum/ambient_outpost_role
 *   /floor_tenant), so SSambient_npcs counts, paces and refills them like any other concourse visitor.
 * - **Moving day** (on_let()). Two movers come down the lift with the old tenant's boxes, take them through the
 *   checkpoint to a counter and go. Only while a player is on the concourse to see it, and once a letting.
 * - **Fitters** (on_room_placed()). Two fitters come up the goods lift, weld the new room's outer seams for a couple of
 *   minutes and go back down. Once a placed room, and only while someone is upstairs. The room works from the start.
 * - **The building answers back.** The lift chimes on the floor when the car arrives (on_lift_arriving()); a buzzer
 *   beside the front door sounds through the floor; a note from the outpost waits just inside the door.
 *
 * Caps (A47): movers and fitters count against AMBIENT_OUTPOST_TRANSIENT_CAP with the concourse's people
 * (floor_life_npc_count()). When the outpost is full, one or two of its shoppers or drinkers head for the lift a little
 * early to make room (floor_life_make_room()); nobody is made over the cap. Their dropped cash comes out of the
 * concourse's AMBIENT_OUTPOST_CASH_CAP. Killing them brings nobody sooner: movers come once a letting and fitters once a
 * room, whatever happens to them.
 *
 * Fitters use the goods lift and the deck outside the room, never a door: an NPC cannot get through a crew's keyed door,
 * and holding one open for them would let anyone behind them in.
 */

/// Movers on moving day
#define FLOOR_LIFE_MOVERS 2
/// How long a mover or fitter visit waits for room at the outpost before it is called off
#define FLOOR_LIFE_EVENT_WAIT (90 SECONDS)
/// How often a waiting visit looks for room
#define FLOOR_LIFE_TICK (1 SECONDS)
/// The lift chimes at most this often
#define FLOOR_LIFE_CHIME_GAP (2 SECONDS)
/// The buzzer sounds at most this often
#define FLOOR_LIFE_BUZZ_GAP (5 SECONDS)
/// A fitter still here this long after their time is up goes, watched or not
#define FLOOR_LIFE_FITTER_OVERSTAY (2 MINUTES)
/// The strings file and where it is
#define FLOOR_LIFE_STRINGS "floor_life.json"
#define FLOOR_LIFE_STRINGS_DIR "voidcrew/modules/trade_floors/strings"
/// Kinds of visit
#define FLOOR_LIFE_VISIT_MOVERS "movers"
#define FLOOR_LIFE_VISIT_FITTERS "fitters"

/datum/outpost_floor
	/// The ambient place this floor's fitters belong to, made with the first of them
	var/datum/ambient_place/floor_life/life_place
	/// Weakrefs to the rooms fitters have already been sent for (or would have been, had anyone been there)
	var/list/life_fitted
	/// Visits waiting for room at the outpost: lists of kind, people still to come, deadline and the room's weakref
	var/list/life_visits
	/// world.time the lift last chimed here
	var/life_chimed_at = 0
	/// Tests: the people who count as here, upstairs and on the concourse alike. Null reads the real clients.
	var/list/life_audience

// ===== STRINGS =====

/// `key` of strings/floor_life.json, or null. Loads it the first time; a missing file is not an error.
/proc/floor_life_strings(key)
	if(!GLOB.string_cache || !(FLOOR_LIFE_STRINGS in GLOB.string_cache))
		if(!fexists("[FLOOR_LIFE_STRINGS_DIR]/[FLOOR_LIFE_STRINGS]"))
			return null
		load_strings_file(FLOOR_LIFE_STRINGS, FLOOR_LIFE_STRINGS_DIR)
	var/list/cache = GLOB.string_cache?[FLOOR_LIFE_STRINGS]
	return islist(cache) ? cache[key] : null

/// The lines under `context` in section `section` (mover_lines, fitter_lines, tenant_lines), or an empty list
/proc/floor_life_lines(section, context)
	var/list/entry = floor_life_strings(section)
	var/list/lines = islist(entry) ? entry[context] : null
	return islist(lines) ? lines : list()

/// Which of the three outposts' voices `outpost` speaks in: "general", "outfitter" or "black_market"
/proc/floor_life_outpost_kind(obj/structure/overmap/trader_outpost/outpost)
	if(istype(outpost, /obj/structure/overmap/trader_outpost/black_market))
		return "black_market"
	if(istype(outpost, /obj/structure/overmap/trader_outpost/outfitter))
		return "outfitter"
	return "general"

// ===== TENANTS =====

/**
 * Gives every floor of this outpost without one a tenant business from the outpost's own list, no two the same. A name
 * stays with its floor for the round: it is the old tenant on moving day, and the tenant again if a letting falls
 * through. Cheap and safe to call often; the board reads `tenant_name` directly.
 */
/obj/structure/overmap/trader_outpost/proc/name_tenants()
	if(!length(floors))
		return
	var/list/names = floor_life_strings("tenants_[floor_life_outpost_kind(src)]")
	var/list/taken = list()
	for(var/datum/outpost_floor/floor in floors)
		if(floor.tenant_name)
			taken[floor.tenant_name] = TRUE
	for(var/datum/outpost_floor/floor in floors)
		if(floor.tenant_name)
			continue
		var/list/free = list()
		for(var/business in names)
			if(istext(business) && !taken[business])
				free += business
		floor.tenant_name = length(free) ? pick(free) : "Suite [floor.number]"
		taken[floor.tenant_name] = TRUE

/// The businesses still let on this outpost's floors
/obj/structure/overmap/trader_outpost/proc/tenant_businesses()
	. = list()
	name_tenants()
	for(var/datum/outpost_floor/floor in floors)
		if(floor.state == OUTPOST_FLOOR_STATE_TENANT && floor.tenant_name)
			. += floor.tenant_name

/// A clerk in a dark suit and tie
/datum/outfit/floor_tenant_clerk
	name = "Floor tenant (clerk)"
	uniform = /obj/item/clothing/under/suit/charcoal
	neck = /obj/item/clothing/neck/tie/blue
	shoes = /obj/item/clothing/shoes/laceup

/// A clerk in navy with a jacket
/datum/outfit/floor_tenant_clerk/navy
	name = "Floor tenant (clerk, navy)"
	uniform = /obj/item/clothing/under/suit/navy
	suit = /obj/item/clothing/suit/toggle/lawyer
	neck = null

/// A courier in a mail carrier's uniform
/datum/outfit/floor_tenant_courier
	name = "Floor tenant (courier)"
	uniform = /obj/item/clothing/under/misc/mailman
	head = /obj/item/clothing/head/costume/mailman
	shoes = /obj/item/clothing/shoes/workboots

/// Someone who works for a tenant upstairs, down on an errand: a counter, a seat, a word, and back up the lift
/mob/living/carbon/human/npc/ambient_npc/outpost/customer/floor_tenant
	desc = "Works upstairs."
	outfit_choices = list(
		/datum/outfit/floor_tenant_clerk,
		/datum/outfit/floor_tenant_clerk/navy,
		/datum/outfit/floor_tenant_courier,
	)
	/// The business they work for
	var/life_business

/mob/living/carbon/human/npc/ambient_npc/outpost/customer/floor_tenant/Initialize(mapload, datum/human_npc_order/order)
	// Loaded before anything can ask for their lines, so the dialogue cache never marks the file missing
	floor_life_strings("tenant_lines")
	held_visual = pick(/obj/item/folder/yellow, /obj/item/clipboard, /obj/item/delivery/small)
	. = ..()

/// They work for `business`
/mob/living/carbon/human/npc/ambient_npc/outpost/customer/floor_tenant/proc/life_take_business(business)
	if(!istext(business))
		return
	life_business = business
	desc = "Works upstairs, at [business]."

/mob/living/carbon/human/npc/ambient_npc/outpost/customer/floor_tenant/get_lines(context)
	var/list/lines = floor_life_lines("tenant_lines", context)
	return length(lines) ? lines : ..()

/mob/living/carbon/human/npc/ambient_npc/outpost/customer/floor_tenant/fill_line(line, atom/other)
	. = ..()
	. = replacetext(., "{business}", life_business || "the office")

/// A tenant's people at the outpost below: one while there is a tenant, two while most floors are still let
/datum/ambient_outpost_role/floor_tenant
	name = "tenant's clerk"
	npc_type = /mob/living/carbon/human/npc/ambient_npc/outpost/customer/floor_tenant
	max_count = 2
	weight = 2
	gap_low = 2 MINUTES
	gap_high = 5 MINUTES

/datum/ambient_outpost_role/floor_tenant/wanted(datum/ambient_place/outpost/place)
	var/obj/structure/overmap/trader_outpost/outpost = place?.outpost()
	if(!outpost || !length(ambient_outpost_traders(place)))
		return 0
	var/tenants = length(outpost.tenant_businesses())
	if(!tenants)
		return 0
	return tenants >= 4 ? max_count : 1

/datum/ambient_outpost_role/floor_tenant/arrive(datum/ambient_place/outpost/place, turf/where)
	. = ..()
	brief(., place)

/datum/ambient_outpost_role/floor_tenant/settle(datum/ambient_place/outpost/place)
	. = ..()
	brief(., place)

/// Tells `npc` which business upstairs they work for
/datum/ambient_outpost_role/floor_tenant/proc/brief(mob/living/carbon/human/npc/ambient_npc/outpost/customer/floor_tenant/npc, datum/ambient_place/outpost/place)
	if(!istype(npc))
		return
	var/obj/structure/overmap/trader_outpost/outpost = place?.outpost()
	var/list/businesses = outpost?.tenant_businesses()
	if(length(businesses))
		npc.life_take_business(pick(businesses))

// ===== WHO IS THERE, AND THE CAP =====

/// Living players on this floor now, the ones who would see a visit
/datum/outpost_floor/proc/life_people_upstairs()
	if(islist(life_audience))
		return life_audience
	. = list()
	if(length(bounds) < 5)
		return
	for(var/mob/living/person in outpost_site_clients(locate(bounds[1], bounds[2], bounds[5])))
		if(person.client && person.stat != DEAD)
			. += person

/// Living players on the concourse below now
/datum/outpost_floor/proc/life_people_downstairs()
	if(islist(life_audience))
		return life_audience
	if(QDELETED(outpost))
		return list()
	return SSambient_npcs.outpost_players(outpost)

/**
 * Ambient NPCs at `outpost` now: its concourse's and the fitters on its floors. Movers belong to the concourse.
 * Floor customers (floor_customers.dm, P11) keep their own count, outpost_floor_ambient_count(); the two are joined at
 * integration so both read the same number.
 */
/proc/floor_life_npc_count(obj/structure/overmap/trader_outpost/outpost)
	. = 0
	if(QDELETED(outpost))
		return
	var/datum/ambient_place/outpost/concourse = SSambient_npcs.outposts[outpost]
	if(concourse)
		. += length(concourse.living_npcs())
	for(var/datum/outpost_floor/floor in outpost.floors)
		if(floor.life_place)
			. += length(floor.life_place.living_npcs())

/**
 * The outpost is full and `needed` more people are waiting to come: that many of its shoppers and drinkers, less any
 * already on their way out, head for the lift a little early. They go as anyone leaving goes; the role system brings
 * people back as it always does. Officers, staff and traders are never sent. Returns how many were sent.
 */
/proc/floor_life_make_room(obj/structure/overmap/trader_outpost/outpost, needed)
	. = 0
	var/datum/ambient_place/outpost/concourse = SSambient_npcs.outposts[outpost]
	if(!concourse || needed <= 0)
		return
	var/list/candidates = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/npc as anything in concourse.living_npcs())
		if(istype(npc.activity, /datum/ambient_activity/leave))
			needed--
			continue
		if(!istype(npc, /mob/living/carbon/human/npc/ambient_npc/outpost/customer) && !istype(npc, /mob/living/carbon/human/npc/ambient_npc/outpost/drinker))
			continue
		if(!npc.can_act() || (npc.activity && npc.activity.priority >= AMBIENT_PRIORITY_REACTION))
			continue
		candidates += npc
	while(needed > 0 && length(candidates))
		var/mob/living/carbon/human/npc/ambient_npc/npc = pick_n_take(candidates)
		if(npc.start_activity(new /datum/ambient_activity/leave(npc)))
			needed--
			.++

// ===== VISITS =====

/// A visit of `count` people of `kind` (FLOOR_LIFE_VISIT_*) waits for room; `room` for fitters. Tries at once.
/datum/outpost_floor/proc/life_queue_visit(kind, count, datum/outpost_upgrade/room)
	LAZYADD(life_visits, list(list(kind, count, world.time + FLOOR_LIFE_EVENT_WAIT, room ? WEAKREF(room) : null)))
	life_tick()

/**
 * Brings what waiting visits can come now, as many people as there is room for under the outpost's cap, and makes
 * room for the rest. A visit whose people can no longer see it, or that has waited too long, is called off. Runs
 * every FLOOR_LIFE_TICK while anything waits.
 */
/datum/outpost_floor/proc/life_tick()
	if(QDELETED(src) || QDELETED(outpost))
		LAZYNULL(life_visits)
		return
	for(var/list/visit in life_visits?.Copy())
		var/kind = visit[1]
		var/left = visit[2]
		var/datum/weakref/room_ref = visit[4]
		var/datum/outpost_upgrade/room = room_ref?.resolve()
		var/still_wanted = world.time <= visit[3] && state == OUTPOST_FLOOR_STATE_OWNED
		if(kind == FLOOR_LIFE_VISIT_FITTERS)
			still_wanted = still_wanted && !QDELETED(room) && length(room.footprint_bounds) >= 5 && length(life_people_upstairs())
		else
			still_wanted = still_wanted && length(life_people_downstairs())
		if(!still_wanted || left <= 0)
			LAZYREMOVE(life_visits, list(visit))
			continue
		var/room_left = AMBIENT_OUTPOST_TRANSIENT_CAP - floor_life_npc_count(outpost)
		while(left > 0 && room_left > 0)
			var/mob/living/carbon/human/npc/ambient_npc/brought = (kind == FLOOR_LIFE_VISIT_FITTERS) ? life_bring_fitter(room) : life_bring_mover()
			if(!brought)
				break
			left--
			room_left--
		visit[2] = left
		if(left <= 0)
			LAZYREMOVE(life_visits, list(visit))
		else if(room_left <= 0)
			floor_life_make_room(outpost, left)
	if(length(life_visits))
		addtimer(CALLBACK(src, PROC_REF(life_tick)), FLOOR_LIFE_TICK, TIMER_UNIQUE | TIMER_DELETE_ME)

/// This floor's place for its fitters, made if it has none
/datum/outpost_floor/proc/life_place_for()
	if(QDELETED(life_place))
		life_place = new /datum/ambient_place/floor_life(src)
	return life_place

// ===== MOVING DAY =====

/**
 * A crew has just taken this floor. The old tenant's things come down with two movers while someone downstairs is
 * there to see it; a note from the outpost waits inside the front door; the door gets its buzzer.
 */
/datum/outpost_floor/proc/on_let(mob/buyer)
	outpost?.name_tenants()
	life_leave_note(buyer)
	life_fit_buzzer()
	if(length(life_people_downstairs()))
		life_queue_visit(FLOOR_LIFE_VISIT_MOVERS, FLOOR_LIFE_MOVERS)

/// One mover steps off the concourse lift with a box, or null when the lift is busy
/datum/outpost_floor/proc/life_bring_mover()
	var/datum/ambient_place/outpost/concourse = SSambient_npcs.outpost_place(outpost)
	var/turf/arrival = concourse ? SSambient_npcs.lift_arrival_turf(outpost) : null
	if(!arrival)
		return null
	var/mob/living/carbon/human/npc/ambient_npc/outpost/worker/floor_mover/mover = new(arrival)
	mover.set_place(concourse)
	mover.fade_in()
	ambient_cross_checkpoint_on_arrival(mover, outpost)
	return mover

/// Two movers in hi-vis, with the old tenant's boxes
/mob/living/carbon/human/npc/ambient_npc/outpost/worker/floor_mover
	desc = "Moving somebody's things out."
	dialogue_section = "dock_worker"
	outfit_choices = list(
		/datum/outfit/ambient_dock_worker,
		/datum/outfit/ambient_dock_worker/overalls,
	)
	held_visual = /obj/item/delivery/big
	routine = list(/datum/ambient_activity/idle = 1)
	/// They have set their box down
	var/life_hauled = FALSE

/mob/living/carbon/human/npc/ambient_npc/outpost/worker/floor_mover/Initialize(mapload, datum/human_npc_order/order)
	floor_life_strings("mover_lines")
	return ..()

/mob/living/carbon/human/npc/ambient_npc/outpost/worker/floor_mover/get_lines(context)
	var/list/lines = floor_life_lines("mover_lines", context)
	return length(lines) ? lines : ..()

/// Box to a counter, then back to the lift
/mob/living/carbon/human/npc/ambient_npc/outpost/worker/floor_mover/pick_activity()
	if(!life_hauled)
		life_hauled = TRUE
		if(start_activity(new /datum/ambient_activity/floor_haul_down(src)))
			return activity
	if(prob(50))
		speak_context(AMBIENT_LINE_LEAVE)
	return start_activity(new /datum/ambient_activity/leave(src))

/// Their box carried to the loading space in front of a trader's counter and set down there
/datum/ambient_activity/floor_haul_down
	name = "carrying boxes out"
	/// The trader whose counter they set it down by
	var/datum/weakref/trader_ref
	/// world.time they are done here
	var/done_at = 0

/datum/ambient_activity/floor_haul_down/setup()
	var/list/traders = ambient_outpost_traders(doer.place)
	var/mob/living/trader = length(traders) ? pick(traders) : null
	var/turf/target = trader ? ambient_waiting_spot(doer, trader, 2, 4, failed_spots, loiter = FALSE) : null
	if(!target)
		target = doer.place?.settle_turf(doer, doer, 10)
	if(!target)
		return FALSE
	trader_ref = trader ? WEAKREF(trader) : null
	go_to(target)
	return TRUE

/datum/ambient_activity/floor_haul_down/Destroy()
	trader_ref = null
	return ..()

/datum/ambient_activity/floor_haul_down/arrive()
	var/mob/living/trader = trader_ref?.resolve()
	if(trader && !QDELETED(trader))
		doer.face_atom(trader)
	done_at = world.time + rand(4 SECONDS, 8 SECONDS)
	doer.set_held(null)
	playsound(doer, 'sound/items/handling/cardboard_box/cardboardbox_drop.ogg', 40, TRUE, -3)
	if(prob(60))
		doer.speak_context("crate", force = TRUE)

/datum/ambient_activity/floor_haul_down/act(seconds)
	return world.time >= done_at ? AMBIENT_STEP_DONE : AMBIENT_STEP_CONTINUE

/datum/ambient_activity/floor_haul_down/shift_times(delay)
	. = ..()
	done_at = ambient_shifted(done_at, delay)

// ===== FITTERS =====

/**
 * A room has just been placed. Two fitters come up the goods lift and work its outer seams for a while, if anyone is
 * upstairs to see it. Once a room: the same room never brings them again, whatever happens to them or to it.
 */
/datum/outpost_floor/proc/on_room_placed(datum/outpost_upgrade/room)
	if(!room || state != OUTPOST_FLOOR_STATE_OWNED || length(bounds) < 5)
		return
	for(var/datum/weakref/done as anything in life_fitted)
		if(done.resolve() == room)
			return
	LAZYADD(life_fitted, WEAKREF(room))
	if(!length(life_people_upstairs()))
		return
	life_queue_visit(FLOOR_LIFE_VISIT_FITTERS, OUTPOST_FLOOR_FITTERS, room)

/// A free goods lift tile, or null while every tile has something on it
/datum/outpost_floor/proc/life_goods_arrival()
	for(var/turf/tile as anything in shuffle(goods_turfs.Copy()))
		if(contains_turf(tile) && !tile.is_blocked_turf(exclude_mobs = FALSE))
			return tile
	return null

/// One fitter comes up the goods lift for `room`, or null when it is taken
/datum/outpost_floor/proc/life_bring_fitter(datum/outpost_upgrade/room)
	var/turf/arrival = life_goods_arrival()
	if(!arrival)
		return null
	var/mob/living/carbon/human/npc/ambient_npc/outpost/worker/floor_fitter/fitter = new(arrival)
	fitter.life_room = WEAKREF(room)
	fitter.life_until = world.time + OUTPOST_FLOOR_FITTER_TIME
	fitter.set_place(life_place_for())
	fitter.fade_in()
	playsound(arrival, 'sound/machines/ding_short.ogg', 35, TRUE)
	return fitter

/// The outpost's fitters, in mechanics' kit
/mob/living/carbon/human/npc/ambient_npc/outpost/worker/floor_fitter
	desc = "Here to fit a room."
	dialogue_section = "mechanic"
	outfit_choices = list(
		/datum/outfit/outpost_mechanic,
		/datum/outfit/outpost_mechanic/overalls,
		/datum/outfit/outpost_mechanic/hivis,
		/datum/outfit/outpost_mechanic/coveralls,
	)
	routine = list(
		/datum/ambient_activity/idle = 2,
		/datum/ambient_activity/chat = 2,
	)
	/// The room they came to fit
	var/datum/weakref/life_room
	/// world.time they pack up
	var/life_until = 0

/mob/living/carbon/human/npc/ambient_npc/outpost/worker/floor_fitter/Initialize(mapload, datum/human_npc_order/order)
	floor_life_strings("fitter_lines")
	return ..()

/mob/living/carbon/human/npc/ambient_npc/outpost/worker/floor_fitter/Destroy()
	life_room = null
	return ..()

/mob/living/carbon/human/npc/ambient_npc/outpost/worker/floor_fitter/get_lines(context)
	var/list/lines = floor_life_lines("fitter_lines", context)
	return length(lines) ? lines : ..()

/// Seams until their time is up, a break and a word now and then, then back down the goods lift
/mob/living/carbon/human/npc/ambient_npc/outpost/worker/floor_fitter/pick_activity()
	if(world.time >= life_until)
		if(world.time >= life_until + FLOOR_LIFE_FITTER_OVERSTAY)
			fade_out(instant = !human_npc_watched(src))
			return null
		if(prob(50))
			speak_context(AMBIENT_LINE_LEAVE)
		return start_activity(new /datum/ambient_activity/leave(src))
	if(prob(75) && start_activity(new /datum/ambient_activity/floor_fit(src)))
		return activity
	return ..()

/mob/living/carbon/human/npc/ambient_npc/outpost/worker/floor_fitter/shift_times(delay)
	. = ..()
	life_until = ambient_shifted(life_until, delay)

/**
 * Welding one of the new room's outer seams: a deck tile just outside its footprint, facing the wall. The weld is the
 * mechanics' own (outpost_ambient_work.dm): the lit torch, the sparks and the sound. Nothing is changed.
 */
/datum/ambient_activity/floor_fit
	name = "fitting a room"
	/// The worker component, on them for this seam only
	var/datum/component/outpost_ambient_worker/worker
	/// The wall they weld
	var/turf/wall

/datum/ambient_activity/floor_fit/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/worker/floor_fitter/fitter = doer
	var/datum/outpost_upgrade/room = istype(fitter) ? fitter.life_room?.resolve() : null
	if(QDELETED(room) || length(room.footprint_bounds) < 5)
		return FALSE
	var/list/seams = floor_life_seams(doer, room.footprint_bounds, failed_spots)
	if(!length(seams))
		return FALSE
	var/list/seam = pick(seams)
	wall = seam[2]
	go_to(seam[1])
	next_line = world.time + rand(10 SECONDS, 30 SECONDS)
	return TRUE

/datum/ambient_activity/floor_fit/Destroy()
	drop_worker()
	wall = null
	return ..()

/// Takes the worker component off again
/datum/ambient_activity/floor_fit/proc/drop_worker()
	if(QDELETED(worker))
		worker = null
		return
	var/datum/component/outpost_ambient_worker/old = worker
	worker = null
	old.stop_work()
	qdel(old)
	if(!QDELETED(doer) && doer.work_look)
		doer.show_work_look(null)

/datum/ambient_activity/floor_fit/arrive()
	if(!isturf(doer.loc) || !wall || get_dist(doer, wall) > 1)
		ends_at = world.time
		return
	worker = doer.AddComponent(/datum/component/outpost_ambient_worker, list(/datum/outpost_ambient_work/weld = 1), FALSE, CALLBACK(doer, TYPE_PROC_REF(/mob/living/carbon/human/npc/ambient_npc, show_work_look)))
	if(QDELETED(worker))
		ends_at = world.time
		return
	worker.planned_work = outpost_ambient_work(/datum/outpost_ambient_work/weld)
	if(!worker.start_work(wall))
		ends_at = world.time

/datum/ambient_activity/floor_fit/act(seconds)
	if(QDELETED(worker) || !worker.continue_work())
		return AMBIENT_STEP_DONE
	chatter(AMBIENT_LINE_WORK, 20 SECONDS, 45 SECONDS)
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/floor_fit/finish()
	drop_worker()
	return ..()

/datum/ambient_activity/floor_fit/spot_unreachable()
	. = ..()
	ends_at = world.time

/datum/ambient_activity/floor_fit/shift_times(delay)
	. = ..()
	if(!QDELETED(worker))
		worker.work_ends_at = ambient_shifted(worker.work_ends_at, delay)

/**
 * Where `npc` could weld the outside of a room whose footprint is `footprint` (min x, min y, max x, max y, z): pairs of
 * list(deck tile just outside, wall tile of the room beside it), the deck tile one they may stand on and nobody else
 * stands on or is headed for, and not in `avoid`.
 */
/proc/floor_life_seams(mob/living/carbon/human/npc/ambient_npc/npc, list/footprint, list/avoid)
	. = list()
	var/datum/outpost_ambient_work/weld = outpost_ambient_work(/datum/outpost_ambient_work/weld)
	var/z = footprint[5]
	var/list/pairs = list()
	for(var/x in footprint[1] to footprint[3])
		pairs += list(list(locate(x, footprint[2] - 1, z), locate(x, footprint[2], z)))
		pairs += list(list(locate(x, footprint[4] + 1, z), locate(x, footprint[4], z)))
	for(var/y in footprint[2] to footprint[4])
		pairs += list(list(locate(footprint[1] - 1, y, z), locate(footprint[1], y, z)))
		pairs += list(list(locate(footprint[3] + 1, y, z), locate(footprint[3], y, z)))
	for(var/list/pair in pairs)
		var/turf/outside = pair[1]
		var/turf/seam = pair[2]
		if(!outside || !seam || !weld.accepts(seam) || LAZYACCESS(avoid, outside))
			continue
		if(!npc.standable(outside) || outside.is_blocked_turf(exclude_mobs = FALSE))
			continue
		if(npc.place?.crowd_count(outside, npc) == INFINITY)
			continue
		. += list(pair)

// ===== THE FLOOR'S OWN PLACE =====

/**
 * A floor's fitters. They keep to the floor, off the landing; they leave by the goods lift. SSambient_npcs never ticks
 * it: their AI drives them, and they go when their time is up. Their dropped cash comes out of the concourse's cap.
 */
/datum/ambient_place/floor_life
	name = "a floor"
	/// The floor
	var/datum/weakref/floor_ref

/datum/ambient_place/floor_life/New(datum/outpost_floor/floor)
	. = ..()
	floor_ref = WEAKREF(floor)
	name = "floor [floor.number] of [floor.outpost || "an outpost"]"
	RegisterSignal(floor, COMSIG_QDELETING, PROC_REF(on_floor_deleted))

/datum/ambient_place/floor_life/Destroy()
	var/datum/outpost_floor/floor = served_floor()
	if(floor)
		UnregisterSignal(floor, COMSIG_QDELETING)
		if(floor.life_place == src)
			floor.life_place = null
	for(var/mob/living/carbon/human/npc/ambient_npc/npc as anything in npcs.Copy())
		if(!QDELETED(npc))
			qdel(npc)
	floor_ref = null
	return ..()

/// The floor, if it is still there
/datum/ambient_place/floor_life/proc/served_floor()
	var/datum/outpost_floor/floor = floor_ref?.resolve()
	return QDELETED(floor) ? null : floor

/datum/ambient_place/floor_life/proc/on_floor_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/datum/ambient_place/floor_life/leash_ok(turf/tile, mob/living/carbon/human/npc/ambient_npc/npc)
	var/datum/outpost_floor/floor = served_floor()
	return !!floor?.contains_turf(tile)

// The deck, never the landing (the crew's door is between) nor the lift alcove
/datum/ambient_place/floor_life/spot_allowed(turf/tile, mob/living/carbon/human/npc/ambient_npc/npc)
	var/datum/outpost_floor/floor = served_floor()
	return !!floor && floor.contains_turf(tile) && !floor.in_landing(tile) && !(tile in floor.alcove_turfs)

// Back down the goods lift
/datum/ambient_place/floor_life/exit_turf(mob/living/carbon/human/npc/ambient_npc/npc)
	var/datum/outpost_floor/floor = served_floor()
	if(!floor || !length(floor.goods_turfs))
		return null
	return get_closest_atom(/turf, floor.goods_turfs, npc)

/datum/ambient_place/floor_life/cash_for(mob/living/carbon/human/npc/ambient_npc/npc, amount)
	var/datum/outpost_floor/floor = served_floor()
	var/datum/ambient_place/outpost/concourse = floor?.outpost ? SSambient_npcs.outpost_place(floor.outpost) : null
	return concourse ? concourse.cash_for(npc, amount) : 0

// A real blow on ground the law covers is violence there, as against a visitor downstairs
/datum/ambient_place/floor_life/npc_attacked(mob/living/carbon/human/npc/ambient_npc/npc, atom/attacker, attack_flags)
	if(!(attack_flags & ATTACKER_DAMAGING_ATTACK) || !isliving(attacker))
		return
	var/obj/structure/overmap/trader_outpost/outpost = served_floor()?.outpost
	if(outpost && get_trader_outpost_for_turf(get_turf(npc)) == outpost)
		outpost.register_aggression(attacker, OUTPOST_CRIME_ASSAULT_CIVILIAN, npc)

/datum/ambient_place/floor_life/describe()
	return "[name]: [length(living_npcs())] fitter\s"

// ===== THE LIFT CHIME =====

/// The car has come up: the lift chimes across the floor
/datum/outpost_floor/proc/on_lift_arriving()
	if(world.time < life_chimed_at + FLOOR_LIFE_CHIME_GAP || !length(alcove_turfs))
		return
	var/turf/middle = alcove_turfs[CEILING(length(alcove_turfs) / 2, 1)]
	if(!middle)
		return
	life_chimed_at = world.time
	playsound(middle, 'sound/machines/chime.ogg', 50, FALSE, 10)

// ===== THE FRONT DOOR: NOTE AND BUZZER =====

/// The floor's front door, or null
/datum/outpost_floor/proc/life_front_door()
	if(length(landing_bounds) < 5)
		return null
	for(var/turf/tile as anything in block(landing_bounds[1] - 1, landing_bounds[2] - 1, landing_bounds[5], landing_bounds[3] + 1, landing_bounds[4] + 1, landing_bounds[5]))
		var/obj/machinery/door/airlock/outpost_floor_front/door = locate() in tile
		if(door)
			return door
	return null

/// The neighbour of `door` on the landing side (`landing` TRUE) or the floor side
/datum/outpost_floor/proc/life_door_side(obj/machinery/door/door, landing)
	for(var/direction in GLOB.cardinals)
		var/turf/next = get_step(door, direction)
		if(next && isopenturf(next) && contains_turf(next) && in_landing(next) == !!landing)
			return next
	return null

/// The note under the door: on the deck just inside the front door, or by the landing when there is no door
/datum/outpost_floor/proc/life_leave_note(mob/buyer)
	var/list/notes = floor_life_strings("note_[floor_life_outpost_kind(outpost)]")
	if(!length(notes) || length(bounds) < 5)
		return null
	var/obj/machinery/door/airlock/outpost_floor_front/door = life_front_door()
	var/turf/spot = door ? life_door_side(door, landing = FALSE) : null
	if(!spot && length(landing_bounds) >= 5)
		spot = locate(round((landing_bounds[1] + landing_bounds[3]) / 2), landing_bounds[4] + 1, landing_bounds[5])
	if(!spot || !isopenturf(spot))
		return null
	var/text = pick(notes)
	text = replacetext(text, "{outpost}", html_encode(outpost?.name || "the outpost"))
	text = replacetext(text, "{floor}", "floor [number]")
	text = replacetext(text, "{holder}", html_encode(buyer?.real_name || "tenant"))
	var/obj/item/paper/note = new(spot)
	note.name = "note"
	note.add_raw_text(text)
	note.pixel_x = rand(-6, 6)
	note.pixel_y = rand(-6, 2)
	note.update_appearance()
	return note

/// The buzzer goes on the wall beside the front door, on the landing side, where no sign hangs. Once a floor's ground.
/datum/outpost_floor/proc/life_fit_buzzer()
	var/obj/machinery/door/airlock/outpost_floor_front/door = life_front_door()
	var/turf/front = door ? life_door_side(door, landing = TRUE) : null
	if(!front)
		return null
	var/towards_door = get_dir(front, door)
	for(var/turf/tile as anything in block(landing_bounds[1], landing_bounds[2], landing_bounds[5], landing_bounds[3], landing_bounds[4], landing_bounds[5]))
		var/obj/structure/outpost_floor_buzzer/fitted = locate() in tile
		if(fitted)
			return fitted
	for(var/side in list(turn(towards_door, -90), turn(towards_door, 90)))
		var/turf/beside = get_step(front, side)
		var/turf/wall = get_step(beside, towards_door)
		if(!beside || !in_landing(beside) || (beside in alcove_turfs) || !isclosedturf(wall))
			continue
		if(locate(/obj/structure/sign) in beside)
			continue
		var/obj/structure/outpost_floor_buzzer/buzzer = new(beside)
		buzzer.floor_ref = WEAKREF(src)
		buzzer.hang(towards_door)
		return buzzer
	return null

/// A buzzer beside a floor's front door. It sounds through the floor.
/obj/structure/outpost_floor_buzzer
	name = "door buzzer"
	desc = "A buzzer for the floor beyond the door."
	icon = 'icons/obj/machines/wallmounts.dmi'
	icon_state = "access_button_standby"
	anchored = TRUE
	density = FALSE
	obj_flags = NONE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	move_resist = INFINITY
	/// The floor it rings
	var/datum/weakref/floor_ref
	/// world.time it may sound again
	var/next_buzz = 0

/obj/structure/outpost_floor_buzzer/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/// Moves it onto the wall in `direction` from its tile
/obj/structure/outpost_floor_buzzer/proc/hang(direction)
	pixel_x = (direction & EAST) ? 24 : ((direction & WEST) ? -24 : 0)
	pixel_y = (direction & NORTH) ? 24 : ((direction & SOUTH) ? -24 : 0)

/obj/structure/outpost_floor_buzzer/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	buzz(user)
	return TRUE

/obj/structure/outpost_floor_buzzer/attack_paw(mob/living/user, list/modifiers)
	return attack_hand(user, modifiers)

/// Sounds on the landing and through the floor, and everyone upstairs off the landing hears the door
/obj/structure/outpost_floor_buzzer/proc/buzz(mob/user)
	if(world.time < next_buzz)
		return FALSE
	next_buzz = world.time + FLOOR_LIFE_BUZZ_GAP
	flick("access_button_cycle", src)
	playsound(src, 'sound/machines/buzz/buzz-two.ogg', 40, FALSE)
	var/datum/outpost_floor/floor = floor_ref?.resolve()
	if(QDELETED(floor))
		return TRUE
	var/obj/machinery/door/airlock/outpost_floor_front/door = floor.life_front_door()
	var/turf/inside = door ? floor.life_door_side(door, landing = FALSE) : null
	if(inside)
		playsound(inside, 'sound/machines/buzz/buzz-two.ogg', 50, FALSE, 12)
	for(var/mob/living/person as anything in floor.life_people_upstairs())
		if(person != user && !floor.in_landing(get_turf(person)))
			to_chat(person, span_notice("The front door buzzes."))
	return TRUE

#undef FLOOR_LIFE_MOVERS
#undef FLOOR_LIFE_EVENT_WAIT
#undef FLOOR_LIFE_TICK
#undef FLOOR_LIFE_CHIME_GAP
#undef FLOOR_LIFE_BUZZ_GAP
#undef FLOOR_LIFE_FITTER_OVERSTAY
#undef FLOOR_LIFE_STRINGS
#undef FLOOR_LIFE_STRINGS_DIR
#undef FLOOR_LIFE_VISIT_MOVERS
#undef FLOOR_LIFE_VISIT_FITTERS
