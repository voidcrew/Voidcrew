/**
 * # Outpost recovery: replacement staff and returning residents
 *
 * Owner: R2 (spec-rehydrate.md 4.1, RESTAFF and REFILL). Replacement traders, checkpoint guards, the sergeant and
 * beat officers arrive together by lift and walk to their posts; each shop opens when its keeper reaches the
 * counter (shop.set_keeper(), R1). Then the ambient roles come back one at a time near clean stops.
 *
 * The state machine is recovery_core.dm's; this file holds what it asks for:
 * - the counters and desks that were ever kept (/datum/outpost_recovery_post), learned from the shops while their
 *   keepers live (register_posts(), watch()), so a dead or vanished keeper's counter is known;
 * - staff_needed() and send_staff(): the posts nobody keeps, and the people made for them at the lift;
 * - the ambient system's hooks: the places's open_slots() asks the recovery (roles_may_fill()), npc_died() no longer
 *   starts the 20 minute killed-slot wait (the recovery paces the return), settling avoids dirty stops in REFILL.
 *
 * A replacement is made from the type of the counter's first keeper and handed to shop.set_keeper(), which links it
 * to the shop, its outpost and (a guard) its checkpoint, dresses it as a new face and sends it to the counter (R1,
 * trade/trader_npc.dm take_counter()). No file here names the trader types. Traders have no ambient place.
 *
 * A guard's booth is sealed glass, so a replacement guard steps in at his desk (fading in, as anyone off a lift
 * does); a trader arrives by the public lift, crosses the checkpoint and walks to the counter, and is put there if
 * the walk fails and nobody is watching.
 */

/// A keeper away from the outpost's own box (dragged into a hangar or a docked ship) keeps the post this long, then is replaced as if dead (abuse MF3, M31)
#define RECOVERY_KEEPER_AWAY_MAX (1 MINUTES)

/// The kinds of post (recovery_staff.dm)
#define RECOVERY_POST_COUNTER "counter"
#define RECOVERY_POST_GUARD "guard"
#define RECOVERY_POST_POLICE "police"

/// A counter, a desk or a police post that someone keeps. Counters and desks are stored in `recovery.posts` by shop;
/// police posts are made by staff_needed() for the roles' missing count and not kept.
/datum/outpost_recovery_post
	/// RECOVERY_POST_*
	var/kind
	/// The shop whose counter or desk it is (counters and desks)
	var/datum/outpost_shop/shop
	/// The type of the first keeper: what a replacement is made from
	var/keeper_type
	/// Where the keeper stands
	var/turf/spot
	/// Weakref to the first keeper, and to the latest replacement
	var/datum/weakref/original
	var/datum/weakref/replacement
	/// world.time the replacement was made
	var/replacement_at = 0
	/// world.time the keeper was first found away from the outpost's own box, or 0 (abuse MF3)
	var/away_since = 0
	/// A police post: the ambient role that brings them, and how many are missing
	var/role_type
	var/missing = 0

/datum/outpost_recovery_post/Destroy()
	shop = null
	spot = null
	original = null
	replacement = null
	return ..()

// =========================================================================
// THE POSTS
// =========================================================================

/// Who keeps `shop`'s counter now, alive or dead (null once the body is gone): its keeper, else the trader linked to it
/datum/outpost_recovery/proc/counter_keeper(datum/outpost_shop/shop)
	var/mob/living/who = shop.keeper?.resolve()
	if(QDELETED(who))
		who = shop.trader_npc
	return QDELETED(who) ? null : who

/// Learns every counter and desk that has a keeper and is not known yet; never forgets one
/datum/outpost_recovery/proc/register_posts()
	if(QDELETED(outpost) || !outpost.loaded)
		return
	for(var/datum/outpost_shop/shop as anything in outpost.get_all_shops())
		if(!shop || posts[shop])
			continue
		var/mob/living/keeper = counter_keeper(shop)
		if(!keeper)
			continue
		var/datum/outpost_recovery_post/post = new
		post.shop = shop
		post.keeper_type = keeper.type
		post.original = WEAKREF(keeper)
		post.kind = RECOVERY_POST_COUNTER
		var/mob/living/carbon/human/npc/ambient_npc/walker = keeper
		post.spot = (istype(walker) && walker.home) ? walker.home : get_turf(keeper)
		// A permit desk is a guard's: his replacement keeps the same checkpoint (his type carries it)
		if(istype(shop, /datum/outpost_shop/vendor/checkpoint))
			post.kind = RECOVERY_POST_GUARD
		posts[shop] = post

/// Whether `who` is up: there, and not dead
/datum/outpost_recovery/proc/keeper_alive(mob/living/who)
	return !QDELETED(who) && who.stat != DEAD

/// Whether `who` is up and in the outpost's own box (concourse, lobby, closets): not carried off into a hangar or a docked ship
/datum/outpost_recovery/proc/keeper_on_post(mob/living/who)
	if(!keeper_alive(who))
		return FALSE
	var/turf/where = get_turf(who)
	if(!where)
		return FALSE
	if(outpost?.police)
		return outpost.police.dispatch_in_box(where)
	return get_trader_outpost_for_turf(where) == outpost

/**
 * Whether `who` still keeps `post`: alive and at the outpost, or away from it for less than RECOVERY_KEEPER_AWAY_MAX.
 * A keeper carried off alive (into a docked ship, out of the hangar) is replaced as if dead (abuse MF3, M31); the old
 * body is just a person after that.
 */
/datum/outpost_recovery/proc/keeper_holds_post(datum/outpost_recovery_post/post, mob/living/who)
	if(!keeper_alive(who))
		return FALSE
	if(keeper_on_post(who))
		post.away_since = 0
		return TRUE
	if(!post.away_since)
		post.away_since = world.time
	return world.time - post.away_since < RECOVERY_KEEPER_AWAY_MAX

/// The counters and desks with nobody keeping them: the keeper is dead, gone or carried off, and no replacement is alive
/datum/outpost_recovery/proc/vacant_posts()
	. = list()
	for(var/datum/outpost_shop/shop as anything in posts)
		var/datum/outpost_recovery_post/post = posts[shop]
		if(QDELETED(shop) || !post)
			continue
		if(keeper_holds_post(post, post.replacement?.resolve()) || keeper_holds_post(post, counter_keeper(shop)))
			continue
		. += post

/**
 * The counters and posts that need someone: the vacant counters and desks, and a post for each police role short of
 * its people (the sergeant at the desk, the beat). Each is a /datum/outpost_recovery_post; send_staff() makes them.
 */
/datum/outpost_recovery/proc/staff_needed()
	. = list()
	if(QDELETED(outpost))
		return
	register_posts()
	for(var/datum/outpost_recovery_post/post as anything in vacant_posts())
		. += post
	var/datum/ambient_place/outpost/place = recovery_place()
	var/datum/outpost_police/police = outpost.police
	if(!place || !police?.life_has_station())
		return
	for(var/role_type in list(/datum/ambient_outpost_role/police_sergeant, /datum/ambient_outpost_role/police_beat))
		var/datum/ambient_outpost_role/role = SSambient_npcs.get_outpost_role(role_type)
		if(!role?.npc_type || !role.applies_to(outpost))
			continue
		var/short = role.wanted(place)
		if(short <= 0)
			continue
		var/datum/outpost_recovery_post/post = new
		post.kind = RECOVERY_POST_POLICE
		post.role_type = role_type
		post.missing = short
		. += post

/**
 * Makes the staff staff_needed() lists at the lift and sends them to their posts: one replacement for each vacant
 * counter, the missing officers for each police post, all in the same second as far as the lift has room (what does
 * not fit comes next second). Safe to call every second.
 */
/datum/outpost_recovery/proc/send_staff()
	if(QDELETED(outpost))
		return
	for(var/datum/outpost_recovery_post/post as anything in staff_needed())
		if(post.kind == RECOVERY_POST_POLICE)
			send_officers(post)
		else
			send_keeper(post)
	check_replacements()

/**
 * A replacement for `post`'s dead or vanished keeper, made from the type of the counter's first keeper. A guard steps
 * in at his desk (the booth is sealed); a trader comes up in the public lift, crosses the checkpoint like anyone off
 * it, and walks to the counter by his own routine (R1). shop.set_keeper() does the rest: it links the replacement to
 * the shop, the outpost and (a guard) the checkpoint, dresses a new face and makes the counter his home.
 */
/datum/outpost_recovery/proc/send_keeper(datum/outpost_recovery_post/post)
	if(!ispath(post.keeper_type, /mob/living) || !post.spot)
		return
	var/turf/arrival = post.kind == RECOVERY_POST_GUARD ? post.spot : SSambient_npcs.lift_arrival_turf(outpost)
	if(!arrival || arrival.is_blocked_turf(exclude_mobs = FALSE))
		return
	var/mob/living/replacement = new post.keeper_type(arrival)
	post.replacement = WEAKREF(replacement)
	post.replacement_at = world.time
	post.shop.set_keeper(replacement)
	var/mob/living/carbon/human/npc/ambient_npc/walker = replacement
	if(istype(walker))
		walker.fade_in()
		if(post.kind != RECOVERY_POST_GUARD)
			ambient_cross_checkpoint_on_arrival(walker, outpost)

/// The missing officers of a police post step off a police lift (the ambient role's own arrival), all at once
/datum/outpost_recovery/proc/send_officers(datum/outpost_recovery_post/post)
	var/datum/ambient_place/outpost/place = recovery_place()
	var/datum/ambient_outpost_role/role = SSambient_npcs.get_outpost_role(post.role_type)
	if(!place || !role)
		return
	var/turf/fallback = SSambient_npcs.lift_arrival_turf(outpost)
	for(var/i in 1 to post.missing)
		if(!role.arrive(place, fallback))
			break

/**
 * A replacement that has not reached its counter within RECOVERY_POST_PATIENCE is put there if nobody is looking
 * at it or at the counter (a back door, a booth the walk cannot enter).
 */
/datum/outpost_recovery/proc/check_replacements()
	for(var/datum/outpost_shop/shop as anything in posts)
		var/datum/outpost_recovery_post/post = posts[shop]
		var/mob/living/replacement = post?.replacement?.resolve()
		if(!keeper_alive(replacement) || !post.spot || get_turf(replacement) == post.spot)
			continue
		if(world.time - post.replacement_at < RECOVERY_POST_PATIENCE)
			continue
		if(!isturf(replacement.loc) || human_npc_watched(replacement) || human_npc_watched(post.spot))
			continue
		replacement.forceMove(post.spot)

/**
 * The original keeper was revived while a replacement is still on the way: the original takes the counter back
 * (shop.set_keeper()) and the replacement slips away (spec-rehydrate R11). A replacement that has reached the counter
 * stays. A replacement nobody can fade out in front of a watcher is left to walk out by his own leave.
 */
/datum/outpost_recovery/proc/turn_round_replacements()
	for(var/datum/outpost_shop/shop as anything in posts)
		var/datum/outpost_recovery_post/post = posts[shop]
		var/mob/living/original = post?.original?.resolve()
		var/mob/living/replacement = post?.replacement?.resolve()
		// An original still carried off never takes the counter back (abuse MF3)
		if(!keeper_on_post(original) || !keeper_alive(replacement) || original == replacement)
			continue
		if(!post.spot || get_dist(replacement, post.spot) <= 1)
			continue
		post.shop.set_keeper(original)
		post.replacement = null
		var/mob/living/carbon/human/npc/ambient_npc/walker = replacement
		if(istype(walker))
			walker.fade_out()
		else
			qdel(replacement)

// =========================================================================
// THE AMBIENT SYSTEM'S HOOKS (the recovery paces the people coming back)
// =========================================================================

/// A role has an open slot only when the outpost's recovery lets its people come back (roles_may_fill())
/datum/ambient_place/outpost/open_slots(datum/ambient_outpost_role/role)
	. = ..()
	if(. <= 0)
		return
	var/datum/outpost_recovery/recovery = outpost()?.recovery
	if(recovery && !recovery.roles_may_fill(role))
		return 0

/// The recovery brings the dead's places back (RESTAFF, REFILL) in place of the killed-slot wait of AMBIENT_OUTPOST_KILLED_SLOT_TIME
/datum/ambient_place/outpost/npc_died(mob/living/carbon/human/npc/ambient_npc/npc)
	if(outpost()?.recovery)
		return
	return ..()

/// In REFILL each arrival sets the gap before the next
/datum/ambient_place/outpost/add_npc(mob/living/carbon/human/npc/ambient_npc/npc)
	. = ..()
	outpost()?.recovery?.note_arrival(npc)

/// In REFILL nobody settles within a patrol stop's range of a stop that is still dirty (R12: a dirty stop just stays empty)
/datum/ambient_place/outpost/settle_free(turf/tile, obj/structure/overmap/trader_outpost/outpost, mob/living/carbon/human/npc/ambient_npc/npc)
	. = ..()
	if(. && outpost?.recovery?.near_dirty_stop(tile))
		return FALSE

/// Whether, in REFILL, `tile` is within a patrol stop's range of a stop found dirty
/datum/outpost_recovery/proc/near_dirty_stop(turf/tile)
	if(state != OUTPOST_RECOVERY_REFILL || !tile)
		return FALSE
	for(var/turf/stop as anything in dirty_stops)
		if(dirty_stops[stop] && stop.z == tile.z && get_dist(stop, tile) <= OUTPOST_RECOVERY_STOP_RANGE)
			return TRUE
	return FALSE

#undef RECOVERY_KEEPER_AWAY_MAX
#undef RECOVERY_STARS_AWAY_MAX
#undef RECOVERY_WATCH_GAP
#undef RECOVERY_RESTAFF_MAX
#undef RECOVERY_REFILL_MAX
#undef RECOVERY_POST_PATIENCE
#undef RECOVERY_CREW_GRACE
#undef RECOVERY_POST_COUNTER
#undef RECOVERY_POST_GUARD
#undef RECOVERY_POST_POLICE
