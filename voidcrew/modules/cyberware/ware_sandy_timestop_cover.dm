/**
 * # How much of the world the Cascade slow-mo covers
 *
 * Additions to the slow-mo field in ware_sandy_timestop.dm (this file is included after it, so its procs chain onto
 * that file's):
 *
 * - Its light. The tint sits on bodies, items, turfs and decals, but a room's coloured light is drawn on the lighting
 *   plane, which multiplies over all of them: a purple club room stayed purple under the wash. While the slow-mo runs,
 *   the user's own lighting plane (and that of any crewmate the field holds) is drawn in grey, so the slowed world
 *   reads the same under any light. This is a filter on that player's own plane masters: nobody else's screen changes.
 *   Anyone else looking on (a ghost, a player beyond the witness range) sees the per-atom tint under the room's own
 *   light, as before.
 * - Its reach. The field is SANDY_STOP_FIELD_RANGE (11) tiles round the user: a 19x15 view with two columns and four
 *   rows to spare. It also takes the rest of the room the user stands in, out to SANDY_COVER_ROOM_REACH tiles (indoor
 *   areas only: an open planet is one huge area), when the slow-mo starts and whenever the user walks into another
 *   room. A wide room is slowed and tinted whole, not cut off at a moving edge.
 * - Its edge. Ground the field moves onto after the ring has rolled out fades into the tint over SANDY_COVER_FADE
 *   instead of switching, so the front of a moving field doesn't flicker.
 * - Never another player. A player outside the user's crew is never held, even in a room the field takes past the
 *   witness range (a player within it ends the slow-mo, ware_sandy_timestop.dm).
 * - Clocks of the mob's own. A mob that keeps its attack and move deadlines in its own vars (the kingpin's crew,
 *   bounty_kingpin.dm) pushes them back in cyberware_push_clocks(), which the field calls with every push.
 */

/// How far the field takes the room its user stands in, in tiles.
#define SANDY_COVER_ROOM_REACH 16
/// How long ground the field moves onto takes to fade into the tint.
#define SANDY_COVER_FADE (0.4 SECONDS)
/// Filter name of the slow-mo's grey light on a player's lighting plane.
#define SANDY_COVER_LIGHT "sandy_slowmo_light"
/// The field's ground turfs taken per tick when it takes a room, so a big room doesn't land in one tick.
#define SANDY_COVER_ROOM_BATCH 120

/// The slow-mo's light: every light drawn as grey of the same strength, its colour gone.
/proc/sandy_slowmo_light_matrix()
	var/static/list/grey = list(0.4,0.4,0.4,0, 0.4,0.4,0.4,0, 0.4,0.4,0.4,0, 0,0,0,1, 0,0,0,0)
	return grey

/// Draws `viewer`'s light in grey (`on`) or in its own colours again. Only `viewer`'s own screen changes.
/proc/sandy_slowmo_light(mob/viewer, on)
	var/datum/hud/hud = viewer?.hud_used
	if(!hud)
		return
	for(var/atom/movable/screen/plane_master/plate as anything in hud.get_true_plane_masters(RENDER_PLANE_LIGHTING))
		if(!on)
			plate.remove_filter(SANDY_COVER_LIGHT)
		else if(!plate.get_filter(SANDY_COVER_LIGHT))
			plate.add_filter(SANDY_COVER_LIGHT, 5, color_matrix_filter(sandy_slowmo_light_matrix())) // after the light cutoffs (3, 4)

/// How far `body` walks per step without the slow-mo's own drag on it: its move delay as its own clock counts it.
/proc/cyberware_undilated_slowdown(mob/living/body)
	var/datum/movespeed_modifier/dilation = LAZYACCESS(body.movespeed_modification, "[/datum/movespeed_modifier/cyberware_dilation]")
	return body.cached_multiplicative_slowdown - (dilation ? dilation.multiplicative_slowdown : 0)

/// A slow-mo field took `push` deciseconds from this mob: deadlines it keeps in its own vars move back by as much.
/// Only those that haven't passed yet. Negative `push` (a faster surger) brings them forward.
/mob/living/proc/cyberware_push_clocks(push)
	var/datum/component/bounty_chrome/chrome = GetComponent(/datum/component/bounty_chrome) // a chrome bounty's moves (bounty_chrome.dm)
	chrome?.cyberware_push_clocks(push)

/datum/proximity_monitor/advanced/timestop/sandevistan
	/// Set once the field has taken its first ground: what it moves onto after that fades in.
	var/cover_ready = FALSE
	/// The room the field last took, so it is taken once per visit.
	var/area/covered_room
	/// Ground of the room still to take, a batch per tick.
	var/list/room_queue = list()
	/// Players whose light this field draws grey, to TRUE.
	var/list/lit_viewers = list()

/// Whether `thing` is a player body the field must never hold: a ckey outside the user's crew.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/cover_outsider(atom/movable/thing)
	if(!isliving(thing) || thing == host)
		return FALSE
	var/mob/living/body = thing
	if(!body.ckey)
		return FALSE
	var/datum/team/user_crew = isliving(host) ? cyberware_crew_team(host) : null
	return !user_crew || cyberware_crew_team(body) != user_crew

/datum/proximity_monitor/advanced/timestop/sandevistan/freeze_atom(atom/movable/A)
	if(cover_outsider(A))
		return FALSE
	return ..()

/datum/proximity_monitor/advanced/timestop/sandevistan/freeze_turf(turf/T)
	var/fade = cover_ready && !tinted[T] && (!ring_center || world.time >= ring_start + ring_time)
	var/old_colour = T.color
	. = ..()
	if(fade && tinted[T] && T.color != old_colour)
		var/tinted_colour = T.color
		T.color = old_colour
		animate(T, color = tinted_colour, time = SANDY_COVER_FADE)

/// Before the field takes its first ground: the user's lattice is about to roll its ring out from here (try_time_stop()),
/// so what the field takes now waits for the ring's front at once, instead of being tinted, untinted by sweep_ring() and
/// tinted again a moment later.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/cover_preset_ring(atom/user) // `host` isn't set yet
	if(!isliving(user))
		return
	var/obj/item/organ/cyberimp/cyberware/cascade/lattice = cyberware_bearer_lattice(user)
	var/turf/here = get_turf(user)
	if(!lattice || !here)
		return
	ring_center = here
	ring_start = world.time
	ring_time = lattice.ring_time
	ring_reach = lattice.stop_ring_scale

/// The field has its ground: the user's light goes grey, and from here on new ground fades in.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/cover_start()
	cover_ready = TRUE
	if(ismob(host))
		cover_light(host, TRUE)

/// Every tick: the room the user is in, a batch of its ground, and who sees the grey light.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/cover_tick()
	cover_room()
	var/taken = 0
	while(length(room_queue) && taken < SANDY_COVER_ROOM_BATCH)
		var/turf/ground = room_queue[length(room_queue)]
		room_queue.len--
		taken++
		if(QDELETED(ground) || tinted[ground])
			continue
		setup_field_turf(ground)
		if(QDELETED(src))
			return
	for(var/mob/viewer as anything in lit_viewers.Copy())
		if(QDELETED(viewer) || (viewer != host && !held_mobs[viewer]))
			cover_light(viewer, FALSE)
		else if(viewer.client)
			sandy_slowmo_light(viewer, TRUE) // a reconnect or a new body builds new plane masters
	for(var/mob/living/held as anything in held_mobs)
		if(held.client && !lit_viewers[held] && !cover_outsider(held))
			cover_light(held, TRUE)

/// Queues the ground of the room the user stands in, if it is a new one.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/cover_room()
	var/turf/centre = get_turf(host)
	var/area/room = centre?.loc
	if(!room || room == covered_room)
		return
	covered_room = room
	if(room.outdoors || istype(room, /area/space))
		return
	var/list/rings = new /list(SANDY_COVER_ROOM_REACH + 1)
	for(var/turf/ground as anything in RANGE_TURFS(SANDY_COVER_ROOM_REACH, centre))
		if(ground.loc != room || tinted[ground])
			continue
		var/ring = get_dist(ground, centre) + 1
		if(!rings[ring])
			rings[ring] = list()
		rings[ring] += ground
	// farthest first in the list, nearest last: the queue is taken from its end
	room_queue.Cut()
	for(var/ring in length(rings) to 1 step -1)
		if(rings[ring])
			room_queue += rings[ring]

/// Draws `viewer`'s light grey (or not) on this field's behalf; another field still drawing it keeps it grey.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/cover_light(mob/viewer, on)
	if(on)
		lit_viewers[viewer] = TRUE
		sandy_slowmo_light(viewer, TRUE)
		return
	lit_viewers -= viewer
	for(var/datum/proximity_monitor/advanced/timestop/sandevistan/field as anything in GLOB.cyberware_time_fields)
		if(field != src && field.lit_viewers[viewer])
			return
	sandy_slowmo_light(viewer, FALSE)

/// The field is ending: everyone's light gets its colour back.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/cover_end()
	room_queue.Cut()
	for(var/mob/viewer as anything in lit_viewers.Copy())
		cover_light(viewer, FALSE)

#undef SANDY_COVER_ROOM_REACH
#undef SANDY_COVER_FADE
#undef SANDY_COVER_LIGHT
#undef SANDY_COVER_ROOM_BATCH
