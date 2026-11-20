/**
 * # Scav den cameras (owner decision 10)
 *
 * A wall camera that sweeps a visible cone back and forth across the room in front of it. A player caught in the cone,
 * in light (or right under it), fills its notice; while it fills the camera stops and follows them and the cone turns
 * amber. Full, it sounds the compound's siren and the den's guards answer as they answer any alarm (stealth_noise() at
 * the spot, so the nearest few run there and search, the rest hold wary and the lookouts call it in on the radio).
 *
 * It sees by the guards' rules: dark tiles hide you past one tile, lockers and boxes hide you, cloaks hide you, and a
 * scav disguise of fatigues and mask passes, except in a room marked off limits (stealth_restricted). It never sees
 * through walls (stealth_can_see()). The cone is drawn on the lighting visual plane and lights nothing: what it shows is where
 * it looks, nothing more.
 *
 * Players can EMP it (off for a while), break it (it has an integrity like any machine) or cut its feed with
 * wirecutters (from beside it: the tile under it is in its cone). The guards' skill profile for the den's zone sets
 * how fast its notice fills (decision 38).
 *
 * It runs on SSfastprocess, and only while a player is on its level; otherwise it stands still and costs nothing.
 */

/// Sweeping its arc
#define SCAV_CAM_SCAN 1
/// Holding on someone while its notice fills
#define SCAV_CAM_TRACK 2
/// Siren going
#define SCAV_CAM_ALARM 3
/// EMP'd, cut or broken
#define SCAV_CAM_OFF 4

/// Seconds a camera at yellow skill takes to fill on someone in plain view
#define SCAV_CAM_FILL_TIME 1.5
/// How much faster it fills within this many tiles
#define SCAV_CAM_NEAR_RANGE 2
#define SCAV_CAM_NEAR_MULT 3
/// Notice lost per second with nobody in view
#define SCAV_CAM_DECAY 0.5
/// Degrees a second it turns to follow someone
#define SCAV_CAM_TRACK_SPEED 120
/// How long the siren runs
#define SCAV_CAM_ALARM_TIME (12 SECONDS)
/// Time between two alarms from one camera
#define SCAV_CAM_ALARM_COOLDOWN (30 SECONDS)
/// After losing someone, how long it stays on the spot before it sweeps again
#define SCAV_CAM_LOST_HOLD (2 SECONDS)
/// Pause at each end of the sweep
#define SCAV_CAM_END_PAUSE (1 SECONDS)
/// Cone colours: sweeping, following someone, siren
#define SCAV_CAM_COLOR_SCAN "#a8d4ff"
#define SCAV_CAM_COLOR_TRACK "#ffb347"
#define SCAV_CAM_COLOR_ALARM "#ff3b30"
/// How the drawn cone is widened to match the view (the beam icon is about 15 degrees each side)
#define SCAV_CAM_CONE_SCALE 1.25

/**
 * The swivel frames of tg's camera sprite (copied one still per frame into scav_camera.dmi as "scan_<dir>_<frame>" and
 * "track_<dir>_<frame>"), so the server shows the head where it aims instead of the client running its own swivel loop.
 * Keyed by sprite dir; each frame is list(head angle, lens x, lens y): the angle in degrees clockwise from north, from
 * the arm joint to the green lens pixel, and the lens pixel's centre in pixels from the tile's centre (y up).
 * Measured from the pixels.
 */
GLOBAL_LIST_INIT(scav_cam_frames, list(
	"1" = list(list(214, -12.5, 6.5), list(207, -12.5, 5.5), list(194, -11.5, 5.5), list(180, -10.5, 5.5), list(166, -9.5, 5.5), list(153, -8.5, 5.5), list(146, -8.5, 6.5)), // north wall, top left
	"2" = list(list(34, -8.5, -6.5), list(27, -8.5, -5.5), list(14, -9.5, -5.5), list(0, -10.5, -5.5), list(346, -11.5, -5.5), list(333, -12.5, -5.5), list(326, -12.5, -6.5)), // south wall, bottom left
	"4" = list(list(315, 6.5, 13.5), list(297, 5.5, 12.5), list(284, 5.5, 11.5), list(270, 5.5, 10.5), list(256, 5.5, 9.5), list(243, 5.5, 8.5), list(236, 6.5, 8.5)), // east wall, top right
	"5" = list(list(34, 12.5, -6.5), list(27, 12.5, -5.5), list(14, 11.5, -5.5), list(0, 10.5, -5.5), list(346, 9.5, -5.5), list(333, 8.5, -5.5), list(326, 8.5, -6.5)), // south wall, bottom right
	"6" = list(list(225, 6.5, -13.5), list(243, 5.5, -12.5), list(256, 5.5, -11.5), list(270, 5.5, -10.5), list(284, 5.5, -9.5), list(297, 5.5, -8.5), list(304, 6.5, -8.5)), // east wall, bottom right
	"8" = list(list(124, -6.5, 8.5), list(117, -5.5, 8.5), list(104, -5.5, 9.5), list(90, -5.5, 10.5), list(76, -5.5, 11.5), list(63, -5.5, 12.5), list(45, -6.5, 13.5)), // west wall, top left
	"9" = list(list(214, 8.5, 6.5), list(207, 8.5, 5.5), list(194, 9.5, 5.5), list(180, 10.5, 5.5), list(166, 11.5, 5.5), list(153, 12.5, 5.5), list(146, 12.5, 6.5)), // north wall, top right
	"10" = list(list(56, -6.5, -8.5), list(63, -5.5, -8.5), list(76, -5.5, -9.5), list(90, -5.5, -10.5), list(104, -5.5, -11.5), list(117, -5.5, -12.5), list(135, -6.5, -13.5)), // west wall, bottom left
))

/// For a camera in a room's corner, the two sprite dirs whose mounts sit in that corner (one on each wall).
GLOBAL_LIST_INIT(scav_cam_corner_sprites, list(
	"[SOUTHWEST]" = list(SOUTH, SOUTHWEST),
	"[NORTHWEST]" = list(NORTH, WEST),
	"[NORTHEAST]" = list(EAST, NORTHWEST),
	"[SOUTHEAST]" = list(NORTHEAST, SOUTHEAST),
))

/obj/machinery/scav_camera
	name = "security camera"
	desc = "A scuffed camera on a swivel mount. A wire runs from it into the wall."
	icon = 'voidcrew/icons/obj/machines/scav_camera.dmi'
	icon_state = "camera"
	base_icon_state = "camera"
	layer = WALL_OBJ_LAYER
	use_power = NO_POWER_USE
	subsystem_type = /datum/controller/subsystem/processing/fastprocess
	anchored = TRUE
	density = FALSE
	max_integrity = 60
	integrity_failure = 0.5
	armor_type = /datum/armor/machinery_camera
	/// Degrees each side of its facing that it sweeps
	var/sweep = 50
	/// Degrees clockwise its mount is turned from straight out of its wall (a corner camera looks along both corridors)
	var/facing_offset = 0
	/// Degrees each side of its aim that it sees
	var/view_half = 18
	/// Tiles it sees
	var/view_range = 5
	/// Seconds from one end of the sweep to the other
	var/sweep_time = 4
	/// Its aim now, degrees clockwise from north
	var/aim = 0
	/// Which way it is sweeping: 1 clockwise, -1 back
	var/heading = 1
	/// SCAV_CAM_*
	var/cam_state = SCAV_CAM_SCAN
	/// 0 to 1: how sure it is about whoever it is following
	var/notice = 0
	/// Who it is following, if anyone
	var/datum/weakref/watched
	/// world.time it last saw them
	var/last_seen_at = 0
	/// world.time the sweep resumes after a pause at its end
	var/paused_until = 0
	/// world.time the siren stops
	var/alarm_until = 0
	/// world.time it may raise the alarm again
	var/alarm_ready_at = 0
	/// world.time an EMP wears off
	var/emp_until = 0
	/// Its feed is cut for good (wirecutters)
	var/feed_cut = FALSE
	/// Sprite dirs it may show (one for a camera on a wall, two for one in a corner)
	var/list/sprite_dirs
	/// The sprite dir it shows now (a GLOB.scav_cam_frames key)
	var/frame_dir
	/// The swivel frame it shows now, 1 to 7
	var/frame = 4
	/// The drawn cone
	var/obj/effect/abstract/scav_camera_cone/cone
	/// Weakref to its den's guards, once found
	var/datum/weakref/group_ref
	/// The guards' skill for its zone, once worked out
	var/datum/stealth_skill/profile

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/scav_camera, 0)

/obj/machinery/scav_camera/Initialize(mapload)
	. = ..()
	aim = scav_cam_facing()
	sprite_dirs = scav_cam_sprite_dirs()
	scav_cam_pick_frame()
	update_appearance(UPDATE_ICON_STATE)
	cone = new(src)
	vis_contents += cone
	SET_PLANE_EXPLICIT(cone, O_LIGHTING_VISUAL_PLANE, src)
	scav_cam_draw(TRUE)

/obj/machinery/scav_camera/Destroy()
	if(cone)
		vis_contents -= cone
		QDEL_NULL(cone)
	watched = null
	group_ref = null
	profile = null
	return ..()

/// The way it looks out from its wall, in degrees clockwise from north (a camera hung on the north wall faces south)
/obj/machinery/scav_camera/proc/scav_cam_facing()
	return SIMPLIFY_DEGREES(dir2angle(REVERSE_DIR(dir)) + facing_offset)

/// The sprite dirs it may show: its own, or for a corner camera turned off its wall, the two whose mounts sit in that corner.
/obj/machinery/scav_camera/proc/scav_cam_sprite_dirs()
	if(!facing_offset || !(dir in GLOB.cardinals))
		return list(dir)
	// The other wall of its corner is the one it turns away from.
	var/other_wall = angle2dir_cardinal(dir2angle(REVERSE_DIR(dir)) + (facing_offset > 0 ? 270 : 90))
	var/list/corner = GLOB.scav_cam_corner_sprites["[dir | other_wall]"]
	return corner ? corner.Copy() : list(dir)

/// Shows the swivel frame whose head points nearest its aim. Returns TRUE when the frame changed.
/obj/machinery/scav_camera/proc/scav_cam_pick_frame()
	if(!length(sprite_dirs))
		sprite_dirs = scav_cam_sprite_dirs()
	var/best_dir = frame_dir
	var/best_frame = frame
	var/best_off = INFINITY
	for(var/sprite_dir in sprite_dirs)
		var/list/frames = GLOB.scav_cam_frames["[sprite_dir]"]
		for(var/i in 1 to length(frames))
			var/off = abs(closer_angle_difference(aim, frames[i][1]))
			if(off < best_off)
				best_off = off
				best_dir = sprite_dir
				best_frame = i
	if(best_dir == frame_dir && best_frame == frame)
		return FALSE
	frame_dir = best_dir
	frame = best_frame
	return TRUE

/obj/machinery/scav_camera/examine(mob/user)
	. = ..()
	if(cam_state == SCAV_CAM_OFF)
		. += span_notice(feed_cut ? "Its wire hangs cut." : "It's dark.")

/obj/machinery/scav_camera/update_icon_state()
	if(machine_stat & BROKEN)
		icon_state = "[base_icon_state]_off"
	else if(cam_state == SCAV_CAM_OFF)
		icon_state = "[base_icon_state]_[emp_until > world.time ? "emp" : "off"]"
	else
		if(isnull(frame_dir))
			scav_cam_pick_frame()
		icon_state = "[cam_state == SCAV_CAM_SCAN ? "scan" : "track"]_[frame_dir]_[frame - 1]"
	return ..()

/obj/machinery/scav_camera/atom_break(damage_flag)
	. = ..()
	scav_cam_off()

/obj/machinery/scav_camera/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	emp_until = max(emp_until, world.time + (severity == EMP_LIGHT ? 30 SECONDS : 60 SECONDS))
	scav_cam_off()

/obj/machinery/scav_camera/wirecutter_act(mob/living/user, obj/item/tool)
	if(feed_cut || (machine_stat & BROKEN))
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "cutting the feed...")
	if(!tool.use_tool(src, user, 3 SECONDS, volume = 30))
		return ITEM_INTERACT_BLOCKING
	if(feed_cut)
		return ITEM_INTERACT_BLOCKING
	feed_cut = TRUE
	user.log_message("cut the feed of [src] at [AREACOORD(src)].", LOG_GAME)
	balloon_alert(user, "feed cut")
	scav_cam_off()
	return ITEM_INTERACT_SUCCESS

/// Stops it where it is and hides its cone.
/obj/machinery/scav_camera/proc/scav_cam_off()
	cam_state = SCAV_CAM_OFF
	notice = 0
	watched = null
	if(cone)
		cone.alpha = 0
	update_appearance(UPDATE_ICON_STATE)

/// Its den's guards, or null when there are none in reach.
/obj/machinery/scav_camera/proc/scav_cam_group()
	var/datum/stealth_group/group = group_ref?.resolve()
	if(!QDELETED(group))
		return group
	group = stealth_group_for(get_turf(src))
	group_ref = group ? WEAKREF(group) : null
	return group

/obj/machinery/scav_camera/process(seconds_per_tick)
	var/turf/eye = get_turf(src)
	if(isnull(eye))
		return
	// Nobody to play for: it stands still with its level.
	if(eye.z > length(SSmobs.clients_by_zlevel) || !length(SSmobs.clients_by_zlevel[eye.z]))
		return
	if(cam_state == SCAV_CAM_OFF)
		if(feed_cut || (machine_stat & BROKEN) || emp_until > world.time)
			return
		cam_state = SCAV_CAM_SCAN
		aim = scav_cam_facing()
		update_appearance(UPDATE_ICON_STATE)
		scav_cam_draw(TRUE)
	if(isnull(profile))
		profile = stealth_skill_of(stealth_skill_type_for_zone(stealth_zone_of(eye)))

	var/mob/living/target = watched?.resolve()
	if(!QDELETED(target) && !scav_cam_sees(target, eye))
		target = null
	if(isnull(target))
		target = scav_cam_find(eye)

	if(target)
		watched = WEAKREF(target)
		last_seen_at = world.time
		scav_cam_follow(target, eye, seconds_per_tick)
		if(cam_state == SCAV_CAM_SCAN)
			cam_state = SCAV_CAM_TRACK
			playsound(src, 'sound/machines/beep/twobeep.ogg', 30, FALSE, -3)
			update_appearance(UPDATE_ICON_STATE)
		if(cam_state == SCAV_CAM_TRACK)
			var/rate = (profile?.notice_rate || 1) / SCAV_CAM_FILL_TIME
			if(get_dist(eye, target) <= SCAV_CAM_NEAR_RANGE)
				rate *= SCAV_CAM_NEAR_MULT
			notice = min(1, notice + rate * seconds_per_tick)
			if(notice >= 1 && world.time >= alarm_ready_at)
				scav_cam_alarm(target)
	else
		notice = max(0, notice - SCAV_CAM_DECAY * seconds_per_tick)
		if(cam_state == SCAV_CAM_TRACK && !notice && world.time - last_seen_at > SCAV_CAM_LOST_HOLD)
			cam_state = SCAV_CAM_SCAN
			watched = null
			update_appearance(UPDATE_ICON_STATE)

	if(cam_state == SCAV_CAM_ALARM && world.time >= alarm_until)
		cam_state = target ? SCAV_CAM_TRACK : SCAV_CAM_SCAN
		notice = 0
		update_appearance(UPDATE_ICON_STATE)
	if(cam_state == SCAV_CAM_SCAN)
		scav_cam_sweep(seconds_per_tick)
	scav_cam_draw()

/// Moves its aim along the sweep, pausing at each end.
/obj/machinery/scav_camera/proc/scav_cam_sweep(seconds_per_tick)
	if(world.time < paused_until)
		return
	var/facing = scav_cam_facing()
	var/offset = closer_angle_difference(facing, aim)
	offset += heading * (2 * sweep / max(sweep_time, 0.5)) * seconds_per_tick
	if(abs(offset) >= sweep)
		offset = clamp(offset, -sweep, sweep)
		heading = -heading
		paused_until = world.time + SCAV_CAM_END_PAUSE
	aim = SIMPLIFY_DEGREES(facing + offset)

/// Turns its aim toward `target`, no further round than a little past its sweep.
/obj/machinery/scav_camera/proc/scav_cam_follow(mob/living/target, turf/eye, seconds_per_tick)
	var/turf/spot = get_turf(target)
	var/wanted = delta_to_angle(spot.x - eye.x, spot.y - eye.y)
	var/turn = closer_angle_difference(aim, wanted)
	var/step = SCAV_CAM_TRACK_SPEED * seconds_per_tick
	aim = SIMPLIFY_DEGREES(aim + clamp(turn, -step, step))
	var/facing = scav_cam_facing()
	var/offset = closer_angle_difference(facing, aim)
	if(abs(offset) > sweep + view_half)
		aim = SIMPLIFY_DEGREES(facing + clamp(offset, -(sweep + view_half), sweep + view_half))

/// The nearest person (or player-driven mob) it sees now, or null.
/obj/machinery/scav_camera/proc/scav_cam_find(turf/eye)
	var/mob/living/best
	var/best_dist = INFINITY
	for(var/mob/living/found in SSspatial_grid.orthogonal_range_search(eye, SPATIAL_GRID_CONTENTS_TYPE_HEARING, view_range))
		// People and anyone a player drives; not rats and roaches.
		if(!found.ckey && !ishuman(found))
			continue
		var/dist = get_dist(eye, found)
		if(dist >= best_dist || !scav_cam_sees(found, eye))
			continue
		best = found
		best_dist = dist
	return best

/// Whether it sees `who` from `eye` now.
/obj/machinery/scav_camera/proc/scav_cam_sees(mob/living/who, turf/eye)
	if(!istype(who) || who.stat == DEAD || (FACTION_SCAV in who.faction))
		return FALSE
	var/turf/spot = get_turf(who)
	if(isnull(spot) || spot.z != eye.z || spot == eye)
		return FALSE
	var/dist = get_dist(eye, spot)
	if(dist > view_range)
		return FALSE
	if(abs(closer_angle_difference(aim, delta_to_angle(spot.x - eye.x, spot.y - eye.y))) > view_half)
		return FALSE
	if(stealth_shell_of(who) || stealth_is_cloaked(who))
		return FALSE
	if(dist > 1 && stealth_tile_is_dark(spot))
		return FALSE
	if(!stealth_can_see(eye, spot, view_range))
		return FALSE
	return !scav_cam_waves_through(who, spot)

/// Whether a scav disguise gets `who` past it: fatigues and a mask, anywhere but an off-limits room (a pass excuses
/// one that allows it).
/obj/machinery/scav_camera/proc/scav_cam_waves_through(mob/living/who, turf/spot)
	var/pieces = stealth_disguise_of(who)
	if(stealth_disguise_stage(pieces) < 3)
		return FALSE
	var/datum/stealth_group/group = scav_cam_group()
	var/list/off_limits = group?.off_limits()
	if(isnull(off_limits) || isnull(off_limits[spot]))
		return TRUE
	return off_limits[spot] && (pieces & STEALTH_PIECE_ID)

/// Sounds the siren and sends the guards to `target`'s spot.
/obj/machinery/scav_camera/proc/scav_cam_alarm(mob/living/target)
	cam_state = SCAV_CAM_ALARM
	alarm_until = world.time + SCAV_CAM_ALARM_TIME
	alarm_ready_at = world.time + SCAV_CAM_ALARM_COOLDOWN
	update_appearance(UPDATE_ICON_STATE)
	playsound(src, 'sound/effects/siren.ogg', 70, FALSE, 6)
	var/turf/spot = get_turf(target)
	target.log_message("was seen by [src] at [AREACOORD(spot)], which sounded the den's alarm.", LOG_GAME)
	var/datum/stealth_group/group = scav_cam_group()
	if(group)
		// Wired to the whole compound: every guard of the den hears it, as if it went off where they were seen.
		stealth_noise(spot, STEALTH_NOISE_BLAST, STEALTH_GROUP_RADIUS, target, group)

/// Points and colours the cone to match its aim and state. `instant` skips the glide.
/obj/machinery/scav_camera/proc/scav_cam_draw(instant = FALSE)
	if(isnull(cone))
		return
	if(cam_state == SCAV_CAM_OFF)
		cone.alpha = 0
		return
	var/wanted_color = cam_state == SCAV_CAM_SCAN ? SCAV_CAM_COLOR_SCAN : (cam_state == SCAV_CAM_TRACK ? SCAV_CAM_COLOR_TRACK : SCAV_CAM_COLOR_ALARM)
	if(cone.color != wanted_color)
		cone.color = wanted_color
	var/wanted_alpha = cam_state == SCAV_CAM_ALARM ? (round(world.time / (3 DECISECONDS)) % 2 ? 255 : 120) : 220
	cone.alpha = wanted_alpha
	if(scav_cam_pick_frame())
		update_appearance(UPDATE_ICON_STATE)
	var/list/lens = GLOB.scav_cam_frames["[frame_dir]"][frame]
	var/state = "beam_[scav_cam_reach(lens)]"
	if(cone.icon_state != state)
		cone.icon_state = state
	var/matrix/pointing = matrix()
	pointing.Scale(SCAV_CAM_CONE_SCALE, 1)
	// The beam's bottom middle (its apex) onto the turning point, turned, then onto the lens of the frame the head shows.
	pointing.Translate(0, STEALTH_BEAM_PIVOT)
	pointing.Turn(aim)
	pointing.Translate(lens[2], lens[3] - STEALTH_BEAM_PIVOT)
	if(instant)
		animate(cone, transform = pointing, time = 0)
	else
		// Linear: a turned and stretched matrix tweened by angle can flip and swing the cone the long way round.
		animate(cone, transform = pointing, time = 2 DECISECONDS, flags = ANIMATION_LINEAR_TRANSFORM)

/// How long the drawn cone is along its aim from `lens` (a GLOB.scav_cam_frames entry), in quarter tiles: to the first
/// wall or solid door, at most the beam's full length.
/obj/machinery/scav_camera/proc/scav_cam_reach(list/lens)
	var/turf/eye = get_turf(src)
	if(isnull(eye))
		return STEALTH_BEAM_LENGTHS
	var/dx = sin(aim)
	var/dy = cos(aim)
	var/lens_x = lens ? lens[2] / 32 : 0
	var/lens_y = lens ? lens[3] / 32 : 0
	for(var/step in 1 to STEALTH_BEAM_LENGTHS)
		// a step is a quarter tile, the beam icon's own unit
		var/along = step / 4
		var/turf/at = locate(eye.x + round(lens_x + dx * along, 1), eye.y + round(lens_y + dy * along, 1), eye.z)
		if(isnull(at) || (at != eye && IS_OPAQUE_TURF(at)))
			return clamp(step, 1, STEALTH_BEAM_LENGTHS)
	return STEALTH_BEAM_LENGTHS

/// The drawn cone of a den camera: light on the lighting visual plane, lighting nothing.
/obj/effect/abstract/scav_camera_cone
	name = "camera sweep"
	// The guards' flashlight cone (stealth_beam.dmi) made white and about 4x as opaque, so a tint shows it.
	icon = 'voidcrew/icons/effects/scav_camera_cone.dmi'
	icon_state = "beam_22"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	blocks_emissive = EMISSIVE_BLOCK_NONE
	blend_mode = BLEND_ADD
	appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM | KEEP_APART | PIXEL_SCALE
	vis_flags = NONE
	// The icon's bottom middle on the camera tile's centre
	pixel_x = -48
	pixel_y = 16

#undef SCAV_CAM_SCAN
#undef SCAV_CAM_TRACK
#undef SCAV_CAM_ALARM
#undef SCAV_CAM_OFF
#undef SCAV_CAM_FILL_TIME
#undef SCAV_CAM_NEAR_RANGE
#undef SCAV_CAM_NEAR_MULT
#undef SCAV_CAM_DECAY
#undef SCAV_CAM_TRACK_SPEED
#undef SCAV_CAM_ALARM_TIME
#undef SCAV_CAM_ALARM_COOLDOWN
#undef SCAV_CAM_LOST_HOLD
#undef SCAV_CAM_END_PAUSE
#undef SCAV_CAM_COLOR_SCAN
#undef SCAV_CAM_COLOR_TRACK
#undef SCAV_CAM_COLOR_ALARM
#undef SCAV_CAM_CONE_SCALE
