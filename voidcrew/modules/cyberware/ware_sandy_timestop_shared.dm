/**
 * # One slow-mo for a crew
 *
 * Crewmates' slow-mos (ware_sandy_timestop.dm) that touch become one: a /datum/sandy_session. A solo slow-mo is a
 * session of one, and the solo code is that session as it stands; the datum is made the moment a second crewmate's
 * field touches the first (fields within SANDY_SHARED_TOUCH tiles of each other), on the press or later as they move.
 *
 * - Every member keeps its own field, hosted on it: the shared bubble is the union of them, each following its member.
 * - The world runs at the deepest slow among the members whose own time is left (the "active" ones). An active member
 *   runs at its own multiplier over the world's (relative_rate()): two Cascades at normal speed, a street surger beside
 *   a Cascade at a quarter of it until the Cascade is out.
 * - A member whose own time is out (or who pressed the surge again) is slowed at the world's pace by its own field
 *   until the last one ends: tinted, no edge glow, still able to act. Its crash waits.
 * - When the last active member's time is out every field ends at once, and the one recording (the oldest field's)
 *   plays back once. Each member's view follows its own replayed self. Every crash lands after it.
 * - A player from another crew near any member's field ends it for everyone, with no replay.
 *
 * Each member is paced by its own field only: the other members' fields leave it alone (sandy_session_shares()).
 */

/// Two fields this close (their hosts' distance, in tiles) touch: two SANDY_STOP_FIELD_RANGE (9) radii and the tile between.
#define SANDY_SHARED_TOUCH 19
/// Relative rates this close to 1 count as the same speed (SANDY_STOP_SAME_RATE in ware_sandy_timestop.dm).
#define SANDY_SHARED_SAME_RATE 0.01
/// Copies of ware_sandy_replay.dm's and ware_sandy_timestop.dm's defines, which those files undefine at their end.
#define SANDY_SHARED_RECORDING 1
#define SANDY_SHARED_PUPPET 1
#define SANDY_SHARED_HOLD_RANGE 11
#define SANDY_SHARED_OUTLINE "sandy_time_stop_outline"
#define SANDY_SHARED_FRAME_X 3
#define SANDY_SHARED_FRAME_Y 4
#define SANDY_SHARED_FRAME_Z 5

/// Every shared slow-mo, by member.
GLOBAL_LIST_EMPTY(sandy_session_of)

/datum/sandy_session
	/// Every member, to its field's effect.
	var/list/members = list()
	/// Members with their own time left, to their window.
	var/list/active = list()
	/// Each member's time multiplier and slow-mo depth, from its window.
	var/list/mults = list()
	var/list/scales = list()
	/// Crashes waiting for the replay to end, by member: list(length, stamina).
	var/list/crashes = list()
	/// The one recording.
	var/datum/sandy_replay/replay
	/// Members' replay views (the recording's own user has the replay's camera), by member.
	var/list/views = list()
	/// The fields have ended; the replay plays or is about to.
	var/ending = FALSE
	/// The world's pace now, and the multiplier that sets it.
	var/world_scale = 1
	var/world_mult = 1
	/// For tests and recordings: what happened when.
	var/list/log = list()

/datum/sandy_session/Destroy()
	disband()
	return ..()

/datum/sandy_session/proc/note(text)
	log += "[world.time] [text]"

/// The window of `body`'s surge, if any.
/proc/sandy_session_window(mob/living/body)
	return body?.has_status_effect(/datum/status_effect/cyberware_cascade_window)

/// The field `effect` runs.
/proc/sandy_session_field(obj/effect/timestop/sandevistan/effect)
	return QDELETED(effect) ? null : effect.chronofield

/// Whether `field` (one of a session member's) must leave `thing` alone: it is another member of the same session.
/proc/sandy_session_shares(datum/proximity_monitor/advanced/timestop/sandevistan/field, atom/thing)
	if(!length(GLOB.sandy_session_of) || thing == field.host)
		return FALSE
	var/datum/sandy_session/session = GLOB.sandy_session_of[thing]
	return !!session && session == GLOB.sandy_session_of[field.host]

/// Whether the other members of `body`'s session still have time of their own.
/proc/sandy_session_others_active(mob/living/body)
	var/datum/sandy_session/session = GLOB.sandy_session_of[body]
	if(!session)
		return FALSE
	for(var/mob/living/member as anything in session.active)
		if(member != body)
			return TRUE
	return FALSE

// =========================================================================
// JOINING
// =========================================================================

/// Whether `field` is a player's running slow-mo that a crewmate's can join: its host's window is still slowing the
/// world (or the host is in a session not yet over), and its recording is still going.
/proc/sandy_session_joinable(datum/proximity_monitor/advanced/timestop/sandevistan/field)
	if(QDELETED(field) || QDELETED(field.stopper) || !isliving(field.host))
		return FALSE
	var/mob/living/host = field.host
	if(!host.ckey)
		return FALSE
	var/datum/sandy_session/session = GLOB.sandy_session_of[host]
	if(session)
		return !session.ending && !!session.replay && session.replay.state == SANDY_SHARED_RECORDING && !session.replay.wait_started
	var/datum/status_effect/cyberware_cascade_window/window = sandy_session_window(host)
	if(!window || window.time_stop != field.stopper || window.hold_until)
		return FALSE
	return !!field.replay && field.replay.state == SANDY_SHARED_RECORDING && !field.replay.wait_started

/// `field` and `other` are two crewmates' slow-mos that touch.
/proc/sandy_session_touching(datum/proximity_monitor/advanced/timestop/sandevistan/field, datum/proximity_monitor/advanced/timestop/sandevistan/other)
	var/turf/here = get_turf(field.host)
	var/turf/there = get_turf(other.host)
	if(!here || !there || here.z != there.z || get_dist(here, there) > SANDY_SHARED_TOUCH)
		return FALSE
	var/datum/team/crew = cyberware_crew_team(field.host) // ware_pro_combat.dm
	return !!crew && crew == cyberware_crew_team(other.host)

/**
 * Called every field tick and when a slow-mo starts: if `field` touches a crewmate's running slow-mo that isn't
 * already the same session, the two become one. The younger one joins the older one, whose recording is kept.
 */
/proc/sandy_session_check_touch(datum/proximity_monitor/advanced/timestop/sandevistan/field)
	if(QDELETED(field))
		return
	if(length(GLOB.cyberware_time_fields) < 2 || !sandy_session_joinable(field))
		return
	var/datum/sandy_session/mine = GLOB.sandy_session_of[field.host]
	for(var/datum/proximity_monitor/advanced/timestop/sandevistan/other as anything in GLOB.cyberware_time_fields)
		if(other == field || !sandy_session_joinable(other))
			continue
		var/datum/sandy_session/theirs = GLOB.sandy_session_of[other.host]
		if(mine && mine == theirs)
			continue
		if(!sandy_session_touching(field, other))
			continue
		var/datum/sandy_session/older = theirs || sandy_session_of_one(other)
		var/datum/sandy_session/younger = mine || sandy_session_of_one(field)
		if(!older || !younger)
			return
		if(older.replay.started > younger.replay.started)
			var/datum/sandy_session/swap = older
			older = younger
			younger = swap
		older.absorb(younger)
		return // one join a tick

/// A session for a solo slow-mo that's about to be joined.
/proc/sandy_session_of_one(datum/proximity_monitor/advanced/timestop/sandevistan/field)
	var/mob/living/host = field.host
	var/datum/status_effect/cyberware_cascade_window/window = sandy_session_window(host)
	if(!window || !field.replay)
		return null
	var/datum/sandy_session/session = new
	session.replay = field.replay
	session.add_member(host, window)
	session.world_scale = field.time_scale
	session.world_mult = field.user_multiplier
	session.note("solo [host] becomes a session")
	return session

/// Takes `host`'s field and window into the session.
/datum/sandy_session/proc/add_member(mob/living/host, datum/status_effect/cyberware_cascade_window/window)
	members[host] = window.time_stop
	active[host] = window
	mults[host] = window.time_multiplier
	scales[host] = window.dilation_scale
	GLOB.sandy_session_of[host] = src

/**
 * `other`'s members, fields and crashes join this session. Its recording is dropped: what this one hasn't seen in
 * the new fields is noticed now (standing there from the start if `other` only just began), and the newcomers are
 * the replay's surgers.
 */
/datum/sandy_session/proc/absorb(datum/sandy_session/other)
	var/fresh = other.replay ? world.time - other.replay.started <= world.tick_lag : FALSE
	if(other.replay && other.replay != replay)
		var/datum/sandy_replay/dropped = other.replay
		other.replay = null
		dropped.field = null
		dropped.cancel()
	for(var/mob/living/member as anything in other.members)
		members[member] = other.members[member]
		if(other.active[member])
			active[member] = other.active[member]
		mults[member] = other.mults[member]
		scales[member] = other.scales[member]
		if(other.crashes[member])
			crashes[member] = other.crashes[member]
		GLOB.sandy_session_of[member] = src
		var/datum/proximity_monitor/advanced/timestop/sandevistan/field = sandy_session_field(members[member])
		if(!field)
			continue
		field.replay = replay
		replay?.sandy_take_field(field, fresh)
		note("[member] joins ([fresh ? "on the press" : "fields met"])")
	other.members.Cut()
	other.active.Cut()
	other.crashes.Cut()
	qdel(other)
	// Members only ever run in their own field.
	for(var/mob/living/member as anything in members)
		for(var/mob/living/each as anything in members)
			if(each != member)
				sandy_session_field(members[each])?.sandy_let_go(member)
	repace()

/// The world's pace is the deepest slow among the active members: every field runs at it, the active members at
/// their own rate over it, and the recording's frames follow it.
/datum/sandy_session/proc/repace()
	var/deepest = 1
	var/fastest = 1
	for(var/mob/living/member as anything in active)
		if(scales[member] < deepest)
			deepest = scales[member]
			fastest = mults[member]
	if(!length(active))
		return
	var/changed = deepest != world_scale
	world_scale = deepest
	world_mult = fastest
	var/ends = world.time
	for(var/mob/living/member as anything in active)
		var/datum/status_effect/cyberware_cascade_window/window = active[member]
		ends = max(ends, window.hold_until || window.natural_end)
	for(var/mob/living/member as anything in members)
		var/datum/proximity_monitor/advanced/timestop/sandevistan/field = sandy_session_field(members[member])
		if(!field)
			continue
		field.ends_at = ends
		field.sandy_set_world_rate(world_scale, world_mult)
		if(active[member])
			field.sandy_pace_host(mults[member])
	if(changed)
		replay?.sandy_rebase(world_scale)
		note("world at [world_scale]")

// =========================================================================
// A MEMBER'S TIME RUNS OUT, AND THE END
// =========================================================================

/**
 * Called from the window's end_time_stop(): `window`'s own time is over (it ran out, the bearer pressed the surge
 * again, or died). TRUE when the session took care of it: the slow-mo goes on for the others, or it was the last one
 * and everything ends now. FALSE for a solo slow-mo: the window ends it as it always has.
 */
/proc/sandy_session_window_ends(datum/status_effect/cyberware_cascade_window/window)
	var/mob/living/owner = window.owner
	var/datum/sandy_session/session = owner && GLOB.sandy_session_of[owner]
	if(!session || session.active[owner] != window)
		return FALSE
	session.active -= owner
	if(length(session.active))
		session.time_out(owner, window)
	else
		session.finish_all(window)
	return TRUE

/// `member`'s own time is out while others still have theirs: it becomes part of the slowed world.
/datum/sandy_session/proc/time_out(mob/living/member, datum/status_effect/cyberware_cascade_window/window)
	window.stop_hold()
	var/obj/effect/timestop/sandevistan/effect = window.time_stop
	if(effect)
		window.UnregisterSignal(effect, COMSIG_QDELETING)
		deltimer(effect.end_timer) // the session ends it now
		effect.end_timer = null
	window.time_stop = null
	member.remove_filter(SANDY_SHARED_OUTLINE)
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = sandy_session_field(effect)
	if(member.stat != DEAD)
		member.balloon_alert(member, "lattice spent")
		member.playsound_local(get_turf(member), 'sound/effects/magic/timeparadox2.ogg', 35, FALSE, -1) // the surge's sound, backwards
		field?.sandy_host_joins_world()
	note("[member] out of time")
	repace()

/// The last active member's time is out: every field ends now and the recording plays once.
/datum/sandy_session/proc/finish_all(datum/status_effect/cyberware_cascade_window/last)
	ending = TRUE
	last.stop_hold()
	if(last.time_stop)
		last.UnregisterSignal(last.time_stop, COMSIG_QDELETING)
	last.time_stop = null
	note("ends; replay [replay ? "plays" : "none"]")
	end_fields(TRUE)
	if(replay)
		replay.field_over()
	else
		disband()

/// Ends every member's field. With `flash` each member's screen gets the release flash as the world speeds up.
/datum/sandy_session/proc/end_fields(flash)
	for(var/mob/living/member as anything in members)
		var/obj/effect/timestop/sandevistan/effect = members[member]
		var/datum/proximity_monitor/advanced/timestop/sandevistan/field = sandy_session_field(effect)
		if(field)
			field.replay = null // the session hands the recording over once, below
		var/datum/status_effect/cyberware_cascade_window/window = active[member]
		if(window && window.time_stop == effect)
			continue // still running its own time: the window hears its field go (time_stop_over())
		if(!QDELETED(effect))
			qdel(effect)
		if(!QDELETED(member))
			member.remove_filter(SANDY_SHARED_OUTLINE)
			if(flash && member.stat != DEAD)
				sandy_release_flash(member)
	for(var/mob/living/member as anything in active)
		var/datum/status_effect/cyberware_cascade_window/window = active[member]
		if(!QDELETED(window.time_stop))
			qdel(window.time_stop)

/**
 * A player from another crew came near one of the fields (or a member's body is gone): it all ends now, with no
 * replay. The members still on their own time carry on as plain surges; the others crash now.
 */
/datum/sandy_session/proc/cut_short()
	note("cut short")
	ending = TRUE
	var/datum/sandy_replay/recording = replay
	replay = null
	recording?.cancel()
	end_fields(FALSE)
	disband()

/// Called from a field's tick() when it would end itself (a player came near, or its host is gone). TRUE when the
/// session took care of it.
/proc/sandy_session_field_cut(datum/proximity_monitor/advanced/timestop/sandevistan/field)
	var/datum/sandy_session/session = GLOB.sandy_session_of[field.host]
	if(!session || session.ending)
		return FALSE
	session.cut_short()
	return TRUE

/// Lets everyone go: crashes that waited land now, views go back, and the session is over.
/datum/sandy_session/proc/disband()
	for(var/mob/living/member as anything in views)
		var/datum/sandy_session_view/view = views[member]
		view.stop()
	views.Cut()
	for(var/mob/living/member as anything in crashes)
		var/list/crash = crashes[member]
		if(!QDELETED(member) && member.stat != DEAD && cyberware_bearer_lattice(member) && !sandy_session_window(member))
			member.apply_status_effect(/datum/status_effect/cyberware_cascade_crash, crash[1], crash[2])
	crashes.Cut()
	for(var/mob/living/member as anything in members)
		if(GLOB.sandy_session_of[member] == src)
			GLOB.sandy_session_of -= member
	members.Cut()
	active.Cut()
	if(replay)
		replay = null
	if(!QDELING(src))
		qdel(src)

/// Called from sandy_replay_defer_crash(): a member's crash waits for the session's replay. TRUE if it waits.
/proc/sandy_session_defer_crash(mob/living/user, length, stamina)
	var/datum/sandy_session/session = GLOB.sandy_session_of[user]
	if(!session)
		return FALSE
	session.crashes[user] = list(length, stamina)
	return TRUE

/// Called from the replay's finish(): it is over, so the session is too.
/proc/sandy_session_replay_over(datum/sandy_replay/replay)
	for(var/mob/living/member as anything in GLOB.sandy_session_of)
		var/datum/sandy_session/session = GLOB.sandy_session_of[member]
		if(session.replay != replay)
			continue
		if(session.ending)
			session.note("replay over")
			session.disband()
		else
			session.replay = null // a hold ran past its cap: the slow-mo goes on with nothing to replay
		return

// =========================================================================
// THE FIELDS
// =========================================================================

/// Leaves `member` (another member of the session) alone from now on: its own field paces it.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/sandy_let_go(mob/living/member)
	if(GLOB.cyberware_time_dilated[member] == src)
		var/lag = cyberware_time_lag(member)
		if(lag > 0)
			push_deadlines(member, lag)
		var/list/tags = slowed_tags[member]
		unfreeze_atom(member)
		for(var/tag in tags)
			member.hv_vis_release(tag, 1)
	if(surging[member])
		surging -= member
		UnregisterSignal(member, COMSIG_QDELETING)
		cyberware_surge_refresh_perks(member)

/// Runs this field at the world's new pace: everything it holds, every surger in it at its rate over it.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/sandy_set_world_rate(scale, multiplier)
	if(scale == time_scale && multiplier == user_multiplier)
		return
	time_scale = scale
	user_multiplier = multiplier
	for(var/mob/living/surger as anything in surging)
		var/rate = relative_rate(cyberware_surge_multiplier(surger))
		var/held = GLOB.cyberware_time_dilated[surger] == src
		if(abs(rate - 1) < SANDY_SHARED_SAME_RATE)
			if(held)
				var/lag = cyberware_time_lag(surger)
				if(lag > 0)
					push_deadlines(surger, lag)
				var/list/tags = slowed_tags[surger]
				unfreeze_atom(surger)
				for(var/tag in tags)
					surger.hv_vis_release(tag, 1)
		else if(held)
			own_scales[surger] = rate
			slow_mob(surger)
		else
			take_surger(surger, cyberware_surge_multiplier(surger))
	for(var/mob/living/victim as anything in held_mobs)
		if(!own_scales[victim])
			slow_mob(victim)
	for(var/obj/projectile/shot as anything in held_shots)
		shot.speed = held_shots[shot] * scale_for(shot)
	senses?.update()

/// The field's own host, still on its own time, at its multiplier over the world's: left alone at the same rate,
/// held slower (a street surger beside a Cascade) otherwise.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/sandy_pace_host(multiplier)
	var/mob/living/body = host
	if(!istype(body) || surging[body])
		return // sandy_set_world_rate() keeps it at its rate
	if(abs(relative_rate(multiplier) - 1) < SANDY_SHARED_SAME_RATE)
		return
	immune -= body
	stopper?.immune -= body
	take_surger(body, multiplier)

/// The host's own time is out: from now on it's part of the slowed world, held at the field's pace and tinted, and
/// its shots are the world's.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/sandy_host_joins_world()
	var/mob/living/body = host
	if(!istype(body))
		return
	if(surging[body])
		if(GLOB.cyberware_time_dilated[body] == src)
			unfreeze_atom(body)
		surging -= body
		UnregisterSignal(body, COMSIG_QDELETING)
	immune -= body
	stopper?.immune -= body
	UnregisterSignal(body, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE)
	freeze_atom(body)

// =========================================================================
// THE RECORDING
// =========================================================================

/// `field` feeds this recording from now on: what stands in it is noticed. With `from_start` (the field only just
/// began) it was standing there from frame 0. The host is a surger in the replay.
/datum/sandy_replay/proc/sandy_take_field(datum/proximity_monitor/advanced/timestop/sandevistan/field, from_start)
	if(state != SANDY_SHARED_RECORDING)
		return
	covering = from_start
	for(var/turf/ground as anything in field.frozen_turfs)
		for(var/atom/movable/thing as anything in ground)
			notice(thing)
	covering = FALSE
	notice(field.host)
	var/datum/sandy_replay_track/track = tracks[field.host]
	if(track && !track.surger)
		become_surger(track)

/// The world's pace changed: frames go on from here at one a tick of the world as it runs now, so the replay
/// compresses each stretch by the pace it had.
/datum/sandy_replay/proc/sandy_rebase(scale)
	if(state != SANDY_SHARED_RECORDING || wait_started || scale <= 0)
		return
	var/exact = frame_exact()
	clock_frame = round(exact)
	clock_rate = scale / world.tick_lag
	clock_time = world.time - (exact - clock_frame) / clock_rate
	interval = world.tick_lag / scale

/// Called from hear(): a sound outside the recording's own field may be inside another member's.
/proc/sandy_session_hears(datum/sandy_replay/replay, turf/source)
	var/datum/sandy_session/session = GLOB.sandy_session_of[replay.user]
	if(!session || session.replay != replay)
		return FALSE
	for(var/mob/living/member as anything in session.members)
		var/datum/proximity_monitor/advanced/timestop/sandevistan/field = sandy_session_field(session.members[member])
		var/turf/centre = get_turf(member)
		if(field && centre && centre.z == source.z && get_dist(centre, source) <= field.current_range)
			return TRUE
	return FALSE

/// Called from hold_nearby(): everyone near every member holds still too.
/datum/sandy_replay/proc/sandy_hold_members()
	var/datum/sandy_session/session = GLOB.sandy_session_of[user]
	if(!session || session.replay != src)
		return
	for(var/mob/living/member as anything in session.members)
		if(member == user || QDELETED(member))
			continue
		lock(member)
		var/turf/here = get_turf(member)
		if(!here)
			continue
		for(var/atom/movable/found as anything in SSspatial_grid.orthogonal_range_search(here, SPATIAL_GRID_CONTENTS_TYPE_HEARING, SANDY_SHARED_HOLD_RANGE))
			if(isliving(found))
				lock(found)
			var/obj/vehicle/sealed/mecha/mech = get_atom_on_turf(found, /obj/vehicle/sealed/mecha)
			if(istype(mech))
				hold_mech(mech)

/// Called from begin(): every other member watches its own replayed self.
/datum/sandy_replay/proc/sandy_member_views()
	var/datum/sandy_session/session = GLOB.sandy_session_of[user]
	if(!session || session.replay != src)
		return
	for(var/mob/living/member as anything in session.members)
		if(member == user || session.views[member])
			continue
		var/datum/sandy_replay_track/track = tracks[member]
		if(!member.client || member.stat == DEAD || !isturf(member.loc) || track?.mode != SANDY_SHARED_PUPPET)
			continue
		var/datum/sandy_session_view/view = new(member, track)
		session.views[member] = view
		view.follow()

/// Called from play_frame(): the members' views follow their replayed selves.
/datum/sandy_replay/proc/sandy_member_follow()
	var/datum/sandy_session/session = GLOB.sandy_session_of[user]
	if(!session || session.replay != src)
		return
	for(var/mob/living/member as anything in session.views)
		var/datum/sandy_session_view/view = session.views[member]
		view.follow()

/// One member's camera for the replay: as the replay's own (sandy_replay/proc/follow()), for someone else.
/datum/sandy_session_view
	var/mob/living/viewer
	var/datum/sandy_replay_track/track
	var/obj/effect/abstract/sandy_replay_eye/eye
	var/pixel_x = 0
	var/pixel_y = 0
	var/last_cursor = -2

/datum/sandy_session_view/New(mob/living/member, datum/sandy_replay_track/member_track)
	viewer = member
	track = member_track
	eye = new(member.loc)
	pixel_x = member.client.pixel_x
	pixel_y = member.client.pixel_y
	member.reset_perspective(eye)

/datum/sandy_session_view/proc/follow()
	var/client/screen = viewer?.client
	if(!eye || !screen || !track || track.cursor < 0 || track.cursor == last_cursor)
		return
	last_cursor = track.cursor
	var/list/frames = track.frames
	var/at = track.cursor
	var/turf/spot = frames[at + SANDY_SHARED_FRAME_Z] ? locate(frames[at + SANDY_SHARED_FRAME_X], frames[at + SANDY_SHARED_FRAME_Y], frames[at + SANDY_SHARED_FRAME_Z]) : null
	if(!spot)
		return
	eye.loc = spot
	var/left = track.glide_until - world.time
	if(left > 0 && track.glide_time > 0)
		screen.pixel_x = pixel_x + track.glide_x * left / track.glide_time
		screen.pixel_y = pixel_y + track.glide_y * left / track.glide_time
		animate(screen, pixel_x = pixel_x, pixel_y = pixel_y, time = left, flags = ANIMATION_END_NOW)
	else
		animate(screen, pixel_x = pixel_x, pixel_y = pixel_y, time = 0, flags = ANIMATION_END_NOW)

/datum/sandy_session_view/proc/stop()
	var/client/screen = viewer?.client
	if(screen)
		animate(screen, pixel_x = pixel_x, pixel_y = pixel_y, time = 0, flags = ANIMATION_END_NOW)
		if(screen.eye == eye)
			viewer.reset_perspective()
	QDEL_NULL(eye)
	viewer = null
	track = null

#undef SANDY_SHARED_TOUCH
#undef SANDY_SHARED_SAME_RATE
#undef SANDY_SHARED_RECORDING
#undef SANDY_SHARED_PUPPET
#undef SANDY_SHARED_HOLD_RANGE
#undef SANDY_SHARED_OUTLINE
#undef SANDY_SHARED_FRAME_X
#undef SANDY_SHARED_FRAME_Y
#undef SANDY_SHARED_FRAME_Z
