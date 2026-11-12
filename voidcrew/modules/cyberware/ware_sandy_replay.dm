/**
 * # The Sandevistan replay
 *
 * A slow-mo (ware_sandy_timestop.dm) records how everything in its field looked and where it stood. When the
 * slow-mo runs out, or the user ends it, the world shows it all again from the start at normal speed: a Cascade's
 * 8 s at 20% plays back in 1.6 s. A slow-mo that another player cut short doesn't replay.
 *
 * Nothing is moved and nothing happens twice. Every real thing stays on the tile it really ended on. For each
 * frame it is given the look it had then and is drawn at the spot it stood on with a pixel offset (a "puppet").
 * Only things that are really gone (a spent shot, a gibbed body), or that ended up inside something, get a
 * stand-in effect. When the replay ends every puppet gets its real look back.
 *
 * Recording: one sample per tick of the slowed world (world.tick_lag / time_scale of real time), so each sample is
 * one tick of the replay. A sample is the thing's appearance, turf and dir, kept only when it changed. The field
 * hands over everything it sees (freeze_atom() is the one place everything on, entering or made on a field turf
 * goes through). The field's tint and the user's edge glow are taken out of the recorded looks.
 *
 * The real look under a puppet. Game code keeps changing the real things while they are drawn as something else
 * (Life() runs on, so a body can bleed, fall, die or drop its gun mid-replay). The procs every such change goes
 * through are wrapped at the bottom of this file: they put the real look back first, let the change land on it, and
 * the puppet goes back on after. A change that writes vars directly is caught on the next frame by comparing the
 * puppet with what was drawn, and the changed vars are carried over to the real look (fold()).
 *
 * For the length of the replay AIs are paused and the user and their crewmates can't act. Life() keeps running:
 * this is a lock on decisions and input only, no stun and no damage. A player who isn't crew coming near ends the
 * replay at once, a watchdog timer ends it whatever happens, and finish() can be called any number of times.
 * The surge's crash starts when the replay ends.
 *
 * It looks and sounds like a surge: the surge-on sound plays at the start, the sounds made in the field play again
 * at normal pitch (playsound() hands them over), and every surger in it (the user, or a mob on its own surge) leaves
 * the surge's rolling-hue afterimage trail. A turn of a body (a fall) is tweened, as tg's lying turn is.
 *
 * Not replayed (they show as they really are): lights, fire, smoke and particles, turf changes, attack lunges,
 * flick()s, tweens other than steps and turns (flinches, the spin and arc of flying gore, blood drying and
 * spreading), anything in vis_contents, runechat, and looping sounds (machines, weather).
 */

/// Trait source of the replay's AI pause and input lock.
#define SANDY_REPLAY_TRAIT "sandy_replay"
/// The user's edge glow in a slow-mo (SANDY_STOP_OUTLINE in ware_sandy_timestop.dm, which is included after this file).
#define SANDY_REPLAY_OUTLINE "sandy_time_stop_outline"
/// The slow-mo's tint filter on bodies and items (SANDY_STOP_TINT in ware_sandy_timestop.dm).
#define SANDY_REPLAY_TINT "sandy_time_stop_tint"

#define SANDY_REPLAY_RECORDING 1
#define SANDY_REPLAY_PENDING 2
#define SANDY_REPLAY_PLAYING 3
#define SANDY_REPLAY_DONE 4

#define SANDY_TRACK_PUPPET 1
#define SANDY_TRACK_STANDIN 2

/// The furthest from its real tile a puppet is drawn, in tiles. Past it the thing is hidden for that frame.
#define SANDY_REPLAY_REACH 24
/// The longest move between two frames that is tweened, in pixels. Longer ones are jumps.
#define SANDY_REPLAY_GLIDE_MAX 96
/// Extra time the watchdog gives the replay before it ends it.
#define SANDY_REPLAY_WATCHDOG (1 SECONDS)
/// How long a recorded turn of a body (a fall, getting up) takes in the replay: tg's own lying turn.
#define SANDY_REPLAY_TURN_TIME 2
/// Degrees the replay trail's hue moves per step (CYBERWARE_CASCADE_HUE_STEP in ware_legend.dm).
#define SANDY_REPLAY_HUE_STEP 25
/// Everyone and everything within this many tiles of the user holds still for the replay (the slow-mo's witness range:
/// any other player this close is crew, or there would be no replay).
#define SANDY_REPLAY_HOLD_RANGE 11
/// The most sounds one recording keeps.
#define SANDY_REPLAY_MAX_SOUNDS 200

// A track's frames are a flat list, this many entries a frame.
#define SANDY_FRAME_SIZE 6
#define SANDY_FRAME_INDEX 1
#define SANDY_FRAME_LOOK 2
#define SANDY_FRAME_X 3
#define SANDY_FRAME_Y 4
#define SANDY_FRAME_Z 5
#define SANDY_FRAME_DIR 6

/// Every replay being recorded or played, by its user.
GLOBAL_LIST_EMPTY(sandy_replays)
/// Every thing drawn as a puppet right now, to its track.
GLOBAL_LIST_EMPTY(sandy_replay_masked)
/// length(GLOB.sandy_replay_masked), as a real global: the wrappers at the bottom of this file read it on every overlay change.
GLOBAL_REAL_VAR(sandy_replay_masks)
/// Numbers from the last replay that finished, for tests and recordings.
GLOBAL_LIST_EMPTY(sandy_replay_last)
/// A replay is playing a recorded sound: nobody records it again.
GLOBAL_VAR_INIT(sandy_replay_echoing, FALSE)

/// One recorded thing.
/datum/sandy_replay_track
	var/datum/sandy_replay/owner
	/// The real thing. Null once it is deleted.
	var/atom/movable/thing
	/// The frame it was first seen at. Above 0 for something made, or walking in, mid-window.
	var/first = 0
	/// The frame it was deleted at.
	var/last = INFINITY
	/// Flat list of frames: index, look, x, y, z (0 when not on a turf), dir.
	var/list/frames = list()
	/// Recorder: the thing's raw appearance at the last sample.
	var/last_raw
	/// It was on a surge during the window: the user, or a mob on its own surge in the field.
	var/surger = FALSE
	/// Surger: its surge's trail. An afterimage every this many steps (0 until its window is found), starting at this alpha.
	var/trail_every = 0
	var/trail_alpha = CYBERWARE_CASCADE_AFTERIMAGE_ALPHA
	/// Surger: the next afterimage's hue, and steps taken in the replay.
	var/trail_hue = 0
	var/trail_steps = 0
	/// Playback: a turn (transform change) being tweened: from, to, how long it takes and when it ends.
	var/turn_from
	var/turn_to
	var/turn_time = 0
	var/turn_until = 0
	/// Playback: offset in `frames` of the frame shown before the current one.
	var/came_from = -SANDY_FRAME_SIZE
	/// Playback: SANDY_TRACK_PUPPET or SANDY_TRACK_STANDIN.
	var/mode
	/// Playback: offset in `frames` of the frame showing now. Below 0 before the first.
	var/cursor = -SANDY_FRAME_SIZE
	/// Playback: the tween from the last spot, in pixels still to cover at its start, and when it ends.
	var/glide_x = 0
	var/glide_y = 0
	var/glide_time = 0
	var/glide_until = 0
	/// Puppet: the thing's real look, dir, opacity and luminosity.
	var/saved_look
	var/saved_dir
	var/saved_opacity
	var/saved_luminosity
	/// Puppet: the appearance it was last drawn with, to notice changes made by anything else.
	var/expect
	/// Puppet: wearing its real look right now, while a wrapped proc changes it.
	var/unmasked = FALSE
	/// Stand-in: the effect.
	var/obj/effect/abstract/sandy_replay_standin/standin

/// Carries the recorded look of something that is gone, or isn't on a turf any more.
/obj/effect/abstract/sandy_replay_standin
	name = ""
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	animate_movement = NO_STEPS
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/// What the user's view follows during the replay.
/obj/effect/abstract/sandy_replay_eye
	name = ""
	anchored = TRUE
	invisibility = INVISIBILITY_ABSTRACT
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	animate_movement = NO_STEPS
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/datum/sandy_replay
	/// Whose slow-mo this is.
	var/mob/living/user
	/// The field being recorded. Null once it is over.
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field
	var/state = SANDY_REPLAY_RECORDING
	/// world.time the recording began.
	var/started = 0
	/// Real time between samples.
	var/interval = 1
	var/sample_timer
	var/begin_timer
	/// Things being recorded, to their tracks.
	var/list/tracks = list()
	/// Tracks of things deleted while recording.
	var/list/gone = list()
	/// The last frame's index.
	var/total = 0
	/// The field is moving onto new turfs: what it finds there was standing there since frame 0.
	var/covering = FALSE
	/// world.time playback began.
	var/play_started = 0
	var/play_timer
	var/watchdog
	/// Tracks drawn on their real things.
	var/list/puppets = list()
	/// Tracks drawn on stand-ins.
	var/list/standins = list()
	/// Mobs with their AI paused or input locked, to their simple-animal AI status (or TRUE).
	var/list/locked = list()
	/// Mechs switched off, to what completely_disabled was.
	var/list/mechs = list()
	/// The user's own track, for the camera.
	var/datum/sandy_replay_track/user_track
	/// What the user's view follows.
	var/obj/effect/abstract/sandy_replay_eye/eye
	/// The user's client pixel offsets before the replay.
	var/eye_pixel_x = 0
	var/eye_pixel_y = 0
	/// The crash waiting for the replay to end: list(length, stamina).
	var/list/crash
	var/finished = FALSE
	/// Changes to a puppet that no wrapped proc made (fold()), and what they were.
	var/unhooked = 0
	var/list/folded = list()
	/// Times a wrapped proc changed a puppet.
	var/unmasks = 0
	/// Sounds made in the field, each list(frame, turf, the rest of playsound()'s arguments).
	var/list/sounds = list()
	/// Playback: the next sound to play.
	var/sound_at = 1
	/// Afterimages the replay's surgers left.
	var/afterimages = 0

/datum/sandy_replay/New(datum/proximity_monitor/advanced/timestop/sandevistan/_field, mob/living/_user)
	field = _field
	user = _user
	started = world.time
	interval = world.tick_lag / field.time_scale
	var/datum/sandy_replay/old = GLOB.sandy_replays[user]
	if(old)
		qdel(old) // a replay still showing ends here
	GLOB.sandy_replays[user] = src
	sample_timer = addtimer(CALLBACK(src, PROC_REF(sample)), interval, TIMER_LOOP | TIMER_STOPPABLE | TIMER_DELETE_ME)
	notice(user)

/datum/sandy_replay/Destroy()
	finish()
	deltimer(sample_timer)
	deltimer(begin_timer)
	for(var/atom/movable/thing as anything in tracks)
		UnregisterSignal(thing, COMSIG_QDELETING)
		var/datum/sandy_replay_track/track = tracks[thing]
		track.thing = null
		track.owner = null
	tracks.Cut()
	gone.Cut()
	puppets.Cut()
	standins.Cut()
	user_track = null
	if(user && GLOB.sandy_replays[user] == src)
		GLOB.sandy_replays -= user
	if(field?.replay == src)
		field.replay = null
	field = null
	user = null
	return ..()

// =========================================================================
// RECORDING
// =========================================================================

/// The frame the recording is at now.
/datum/sandy_replay/proc/frame_now()
	if(state != SANDY_REPLAY_RECORDING)
		return total
	return round((world.time - started) / interval)

/// Whether `thing` is recorded at all.
/datum/sandy_replay/proc/recordable(atom/movable/thing)
	var/static/list/skipped = typecacheof(list(
		/obj/effect/abstract,
		/obj/effect/timestop,
		/obj/effect/temp_visual/decoy/fading/cascade, // the surge's trail
		/obj/effect/temp_visual/cyberware_time_ring,
		/obj/effect/hotspot,
		/obj/effect/particle_effect,
		/obj/effect/landmark,
		/atom/movable/screen,
	))
	if(!ismovable(thing) || QDELETED(thing) || thing.invisibility >= INVISIBILITY_ABSTRACT)
		return FALSE
	if(ismob(thing) && !isliving(thing)) // ghosts and camera eyes
		return FALSE
	return !skipped[thing.type]

/// The field saw `thing`: start recording it.
/datum/sandy_replay/proc/notice(atom/movable/thing)
	if(state != SANDY_REPLAY_RECORDING || tracks[thing] || !recordable(thing))
		return
	var/datum/sandy_replay_track/track = new
	track.owner = src
	track.thing = thing
	track.first = covering ? 0 : frame_now()
	tracks[thing] = track
	RegisterSignal(thing, COMSIG_QDELETING, PROC_REF(on_thing_deleted))
	sample_track(track, track.first)

/// The field just changed how `thing` looks (its tint): take the sample again.
/datum/sandy_replay/proc/resample(atom/movable/thing)
	var/datum/sandy_replay_track/track = tracks[thing]
	if(track && state == SANDY_REPLAY_RECORDING)
		track.last_raw = null
		sample_track(track, frame_now())

/// The sample timer: one frame of everything recorded.
/datum/sandy_replay/proc/sample()
	if(state != SANDY_REPLAY_RECORDING)
		return
	var/frame = frame_now()
	for(var/atom/movable/thing as anything in tracks)
		sample_track(tracks[thing], frame)

/// Adds a frame to `track` if the thing changed since its last one.
/datum/sandy_replay/proc/sample_track(datum/sandy_replay_track/track, frame)
	var/atom/movable/thing = track.thing
	var/turf/here = thing.loc
	var/x = 0
	var/y = 0
	var/z = 0
	if(isturf(here))
		x = here.x
		y = here.y
		z = here.z
	var/raw = thing.appearance
	var/facing = thing.dir
	var/list/frames = track.frames
	var/at = length(frames) - SANDY_FRAME_SIZE
	// Wet blood dries and spreads on the client (animate()): its vars already hold the end, so it is looked at every sample.
	var/obj/effect/decal/cleanable/blood/wet = istype(thing, /obj/effect/decal/cleanable/blood) ? thing : null
	if(wet && !wet.sandy_replay_wet())
		wet = null
	if(!wet && at >= 0 && raw == track.last_raw && frames[at + SANDY_FRAME_X] == x && frames[at + SANDY_FRAME_Y] == y && frames[at + SANDY_FRAME_Z] == z && frames[at + SANDY_FRAME_DIR] == facing)
		return
	track.last_raw = raw
	if(!track.surger && (thing == user || field?.surging[thing]))
		become_surger(track)
	else if(track.surger && !track.trail_every)
		read_trail(track)
	var/look = clean_look(thing)
	if(wet)
		look = wet_look(wet, look)
	if(at >= 0)
		if(frames[at + SANDY_FRAME_LOOK] == look && frames[at + SANDY_FRAME_X] == x && frames[at + SANDY_FRAME_Y] == y && frames[at + SANDY_FRAME_Z] == z && frames[at + SANDY_FRAME_DIR] == facing)
			return
		if(frames[at + SANDY_FRAME_INDEX] >= frame) // sampled twice in one frame: the later look stands
			frames[at + SANDY_FRAME_LOOK] = look
			frames[at + SANDY_FRAME_X] = x
			frames[at + SANDY_FRAME_Y] = y
			frames[at + SANDY_FRAME_Z] = z
			frames[at + SANDY_FRAME_DIR] = facing
			return
	frames += list(frame, look, x, y, z, facing)

/// `thing`'s appearance without the slow-mo's own look: the field's tint and the user's edge glow.
/datum/sandy_replay/proc/clean_look(atom/movable/thing)
	var/tinted = field?.tinted[thing]
	var/outlined = thing == user && thing.filter_data?[SANDY_REPLAY_OUTLINE]
	if(!tinted && !outlined)
		return thing.appearance
	var/mutable_appearance/copy = new(thing)
	// Bodies and items wear the tint as a filter (cyberware_time_tints_by_filter()), the rest in `color`.
	var/filtered = tinted && cyberware_time_tints_by_filter(thing)
	if(tinted && !filtered)
		if(istype(thing, /obj/effect/decal/cleanable/blood)) // blood's colour is its own, worked out as it dries
			var/obj/effect/decal/cleanable/blood/blood = thing
			copy.color = blood.sandy_replay_colour()
		else
			copy.color = untinted_colour(thing)
		copy.appearance_flags |= KEEP_TOGETHER // update_atom_colour() leaves this on once anything was ever coloured
	if(outlined || filtered)
		copy.filters = null
		for(var/name in thing.filter_data)
			if(name == SANDY_REPLAY_OUTLINE || name == SANDY_REPLAY_TINT)
				continue
			var/list/data = thing.filter_data[name]
			var/list/arguments = data.Copy()
			arguments -= "priority"
			copy.filters += filter(arglist(arguments))
	return copy.appearance

/// The colour [/atom/proc/update_atom_colour] would give `thing` without the field's tint.
/datum/sandy_replay/proc/untinted_colour(atom/thing)
	if(!length(thing.atom_colours))
		return thing.color
	for(var/priority in 1 to length(thing.atom_colours))
		if(priority == TEMPORARY_COLOUR_PRIORITY)
			continue
		var/list/entry = thing.atom_colours[priority]
		if(!entry)
			continue
		if(entry[ATOM_COLOR_TYPE_INDEX] == ATOM_COLOR_TYPE_FILTER)
			return null
		if(length(entry[ATOM_COLOR_VALUE_INDEX]))
			return entry[ATOM_COLOR_VALUE_INDEX]
	return null

/// `track`'s thing is on a surge: the replay gives it its surge's trail.
/datum/sandy_replay/proc/become_surger(datum/sandy_replay_track/track)
	track.surger = TRUE
	track.trail_hue = rand(0, 359)
	read_trail(track)

/// Takes the trail's cadence and strength from the surger's window. The user's own window isn't listed on them yet
/// while it opens the slow-mo, so this is tried again on later samples.
/datum/sandy_replay/proc/read_trail(datum/sandy_replay_track/track)
	if(!isliving(track.thing))
		return
	var/mob/living/body = track.thing
	var/datum/status_effect/cyberware_cascade_window/window = body.has_status_effect(/datum/status_effect/cyberware_cascade_window)
	if(window)
		track.trail_every = max(1, window.afterimage_interval)
		track.trail_alpha = window.afterimage_alpha

/// `look` (wet `blood`'s appearance) as the blood is drawn on screen right now, not where its tweens end.
/datum/sandy_replay/proc/wet_look(obj/effect/decal/cleanable/blood/blood, look)
	var/colour = blood.sandy_replay_colour()
	var/list/paint = blood.sandy_replay_paint_now()
	if(!colour && !paint)
		return look
	var/mutable_appearance/copy = new(look)
	if(colour)
		copy.color = colour
	if(paint)
		copy.transform = paint[1]
		copy.alpha = paint[2]
	return copy.appearance

/// A sound was played on `source`, in the field: kept, to play again in the replay. `arguments` are the rest of
/// playsound()'s, from soundin on, without the channel.
/datum/sandy_replay/proc/hear(turf/source, list/arguments)
	if(state != SANDY_REPLAY_RECORDING || !field || length(sounds) >= SANDY_REPLAY_MAX_SOUNDS)
		return
	var/turf/centre = get_turf(field.host)
	if(!centre || centre.z != source.z || get_dist(centre, source) > field.current_range)
		return
	sounds += list(list((world.time - started) / interval, source) + arguments)

/// Signal proc for [COMSIG_QDELETING] on anything recorded.
/datum/sandy_replay/proc/on_thing_deleted(atom/movable/thing)
	SIGNAL_HANDLER
	if(thing == user)
		qdel(src)
		return
	var/datum/sandy_replay_track/track = tracks[thing]
	tracks -= thing
	if(!track)
		return
	if(GLOB.sandy_replay_masked[thing] == track)
		GLOB.sandy_replay_masked -= thing
		sandy_replay_masks = length(GLOB.sandy_replay_masked)
	track.thing = null
	if(state == SANDY_REPLAY_RECORDING || state == SANDY_REPLAY_PENDING)
		track.last = max(frame_now(), track.first + 1)
		gone += track
		return
	puppets -= track

/// A player cut the slow-mo short: nothing replays.
/datum/sandy_replay/proc/cancel()
	if(state == SANDY_REPLAY_RECORDING)
		qdel(src)

/// The field is over (it ran out, or the user ended it): playback starts next tick, once the slow-mo's own looks
/// are off everything.
/datum/sandy_replay/proc/field_over()
	if(state != SANDY_REPLAY_RECORDING)
		return
	total = max(frame_now(), 1)
	state = SANDY_REPLAY_PENDING
	field = null
	deltimer(sample_timer)
	sample_timer = null
	begin_timer = addtimer(CALLBACK(src, PROC_REF(begin)), world.tick_lag, TIMER_STOPPABLE | TIMER_DELETE_ME)

// =========================================================================
// PLAYBACK
// =========================================================================

/// Starts the replay: the last sample is everything's real final state, then everything goes back to frame 0.
/datum/sandy_replay/proc/begin()
	begin_timer = null
	if(state != SANDY_REPLAY_PENDING)
		return
	if(QDELETED(user) || cyberware_time_stop_witnessed(user))
		finish()
		return
	state = SANDY_REPLAY_PLAYING
	watchdog = addtimer(CALLBACK(src, PROC_REF(finish)), (total + 2) * world.tick_lag + SANDY_REPLAY_WATCHDOG, TIMER_STOPPABLE | TIMER_DELETE_ME)
	try
		setup_playback()
	catch(var/exception/error)
		finish()
		stack_trace("Sandevistan replay failed to start: [error] ([error.file]:[error.line])")
		return
	if(finished)
		return
	play_started = world.time
	// The surge coming on, as the replay's user did at its first frame.
	var/turf/first = user_track ? locate(user_track.frames[SANDY_FRAME_X], user_track.frames[SANDY_FRAME_Y], user_track.frames[SANDY_FRAME_Z]) : null
	playsound(first || user, 'sound/effects/magic/timeparadox2.ogg', 70, TRUE)
	play_timer = addtimer(CALLBACK(src, PROC_REF(play_frame)), world.tick_lag, TIMER_LOOP | TIMER_STOPPABLE | TIMER_DELETE_ME)
	play_frame()

/datum/sandy_replay/proc/setup_playback()
	lock(user)
	for(var/atom/movable/thing as anything in tracks)
		var/datum/sandy_replay_track/track = tracks[thing]
		track.last_raw = null
		sample_track(track, total)
		if(isliving(thing))
			lock(thing)
		else if(ismecha(thing))
			hold_mech(thing)
		if(length(track.frames) == SANDY_FRAME_SIZE && track.first == 0)
			continue // it never changed: nothing to show
		if(isturf(thing.loc))
			track.mode = SANDY_TRACK_PUPPET
			puppets += track
			mask(track)
		else
			track.mode = SANDY_TRACK_STANDIN
			standins += track
	for(var/datum/sandy_replay_track/track as anything in gone)
		track.mode = SANDY_TRACK_STANDIN
		standins += track
	gone.Cut()
	user_track = tracks[user]
	hold_nearby()
	RegisterSignal(user, COMSIG_MOVABLE_Z_CHANGED, PROC_REF(on_user_z_changed))
	if(user.client && user.stat != DEAD && isturf(user.loc) && user_track?.mode == SANDY_TRACK_PUPPET)
		eye = new(user.loc)
		eye_pixel_x = user.client.pixel_x
		eye_pixel_y = user.client.pixel_y
		user.reset_perspective(eye)

/// Holds every mob and mech near the user, in the bubble or not: a crewmate or an NPC just outside it can't act on
/// the held ones (or on the user) while the replay plays. Called at the start and every frame, for arrivals.
/datum/sandy_replay/proc/hold_nearby()
	var/turf/here = get_turf(user)
	if(!here)
		return
	for(var/atom/movable/found as anything in SSspatial_grid.orthogonal_range_search(here, SPATIAL_GRID_CONTENTS_TYPE_HEARING, SANDY_REPLAY_HOLD_RANGE))
		if(isliving(found))
			lock(found)
		var/obj/vehicle/sealed/mecha/mech = get_atom_on_turf(found, /obj/vehicle/sealed/mecha)
		if(istype(mech)) // a pilot, or something hearing inside one
			hold_mech(mech)

/// Switches `mech` off for the replay.
/datum/sandy_replay/proc/hold_mech(obj/vehicle/sealed/mecha/mech)
	if(!isnull(mechs[mech]) || QDELETED(mech))
		return
	mechs[mech] = mech.completely_disabled
	mech.completely_disabled = TRUE

/// Pauses `body`'s AI and locks its player's input. No stun: decisions and input only.
/datum/sandy_replay/proc/lock(mob/living/body)
	if(locked[body] || QDELETED(body))
		return
	locked[body] = TRUE
	if(body.ckey && body.stat != DEAD)
		body.add_traits(list(TRAIT_IMMOBILIZED, TRAIT_INCAPACITATED), SANDY_REPLAY_TRAIT)
	if(body.ai_controller)
		ADD_TRAIT(body, TRAIT_AI_PAUSED, SANDY_REPLAY_TRAIT)
	if(isanimal(body))
		var/mob/living/simple_animal/animal = body
		locked[body] = animal.AIStatus
		animal.toggle_ai(AI_OFF)

/datum/sandy_replay/proc/unlock(mob/living/body)
	var/was = locked[body]
	if(QDELETED(body))
		return
	body.remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_INCAPACITATED, TRAIT_AI_PAUSED), SANDY_REPLAY_TRAIT)
	if(isanimal(body) && isnum(was))
		var/mob/living/simple_animal/animal = body
		if(animal.AIStatus == AI_OFF)
			animal.toggle_ai(was)

/// Puts the puppet on `track`'s thing: its real look is kept, and it is drawn as its current frame.
/datum/sandy_replay/proc/mask(datum/sandy_replay_track/track)
	var/atom/movable/thing = track.thing
	keep_real(track)
	GLOB.sandy_replay_masked[thing] = track
	sandy_replay_masks = length(GLOB.sandy_replay_masked)
	RegisterSignal(thing, COMSIG_MOVABLE_MOVED, PROC_REF(on_puppet_moved))
	RegisterSignal(thing, COMSIG_ATOM_DIR_CHANGE, PROC_REF(on_puppet_turned))
	show(track)

/// Takes `track`'s thing as it is now for its real look.
/datum/sandy_replay/proc/keep_real(datum/sandy_replay_track/track)
	var/atom/movable/thing = track.thing
	track.saved_look = thing.appearance
	track.saved_dir = thing.dir
	track.saved_opacity = thing.opacity
	track.saved_luminosity = thing.luminosity

/// Gives `track`'s thing its real look back. Assigning an appearance never touches density, and opacity and
/// luminosity are pinned while it is a puppet, so nothing the game reads changes.
/datum/sandy_replay/proc/wear_real(datum/sandy_replay_track/track)
	var/atom/movable/thing = track.thing
	if(thing.appearance != track.expect)
		fold(track)
	animate(thing, time = 0, flags = ANIMATION_END_NOW)
	thing.appearance = track.saved_look
	thing.dir = track.saved_dir
	pin(track)

/// Appearance assignment copies opacity and luminosity: keep the real ones.
/datum/sandy_replay/proc/pin(datum/sandy_replay_track/track)
	var/atom/movable/thing = track.thing
	if(thing.opacity != track.saved_opacity)
		thing.opacity = track.saved_opacity
	if(thing.luminosity != track.saved_luminosity)
		thing.luminosity = track.saved_luminosity

/// A wrapped proc is about to change `track`'s thing: it gets its real look for that.
/datum/sandy_replay/proc/unmask(datum/sandy_replay_track/track)
	wear_real(track)
	track.unmasked = TRUE
	unmasks++

/// The change is done: what the thing looks like now is its real look, and the puppet goes back on.
/datum/sandy_replay/proc/remask(datum/sandy_replay_track/track)
	if(!track.unmasked || QDELETED(track.thing))
		return
	track.unmasked = FALSE
	keep_real(track)
	show(track)

/**
 * Something changed a puppet without going through a wrapped proc (a direct var write, an animate()). Carries the
 * vars that differ from what was drawn over to the real look. Best effort: a var set to the very value the puppet
 * was showing can't be seen.
 */
/datum/sandy_replay/proc/fold(datum/sandy_replay_track/track)
	var/mutable_appearance/now = new(track.thing)
	var/mutable_appearance/drawn = new(track.expect)
	var/mutable_appearance/real = new(track.saved_look)
	var/list/changed = list()
	// pixel_x and pixel_y are taken as plain writes (tg sets them far more often than it shifts them). pixel_w and
	// pixel_z carry the puppet's own shift, so only what was added to them is carried over.
	for(var/name in list("icon", "icon_state", "alpha", "layer", "plane", "invisibility", "name", "blend_mode", "pixel_x", "pixel_y"))
		if(now.vars[name] != drawn.vars[name])
			real.vars[name] = now.vars[name]
			changed += name
	if(!(now.color ~= drawn.color))
		real.color = now.color
		changed += "color"
	if(!(now.transform ~= drawn.transform))
		real.transform = now.transform
		changed += "transform"
	for(var/name in list("pixel_w", "pixel_z"))
		if(now.vars[name] != drawn.vars[name])
			real.vars[name] += now.vars[name] - drawn.vars[name]
			changed += name
	if(!length(changed))
		return
	track.saved_look = real.appearance
	unhooked++
	folded += "[track.thing.type]: [changed.Join(",")]"

/// Moves `track` on to the newest frame at or before `frame`. Returns TRUE if that is a new one.
/datum/sandy_replay/proc/advance(datum/sandy_replay_track/track, frame)
	var/list/frames = track.frames
	var/old = track.cursor
	var/at = old
	var/end = length(frames)
	while(at + SANDY_FRAME_SIZE < end && frames[at + SANDY_FRAME_SIZE + SANDY_FRAME_INDEX] <= frame)
		at += SANDY_FRAME_SIZE
	if(at == old)
		return FALSE
	track.came_from = old
	track.cursor = at
	var/left = track.glide_until - world.time
	var/carry_x = 0
	var/carry_y = 0
	if(left > 0 && track.glide_time > 0)
		carry_x = track.glide_x * left / track.glide_time
		carry_y = track.glide_y * left / track.glide_time
	track.glide_until = 0
	if(old < 0 || !frames[old + SANDY_FRAME_Z] || frames[old + SANDY_FRAME_Z] != frames[at + SANDY_FRAME_Z])
		track.turn_until = 0
		return TRUE
	var/mutable_appearance/was = frames[old + SANDY_FRAME_LOOK]
	var/mutable_appearance/now = frames[at + SANDY_FRAME_LOOK]
	// A turn (a fall, getting up) is a tween on the client: the recording only saw where it ended.
	if(!(was.transform ~= now.transform))
		var/matrix/start = matrix(was.transform)
		var/turn_left = track.turn_until - world.time
		if(turn_left > 0 && track.turn_time > 0)
			var/matrix/turning = track.turn_from
			start = turning.Interpolate(track.turn_to, 1 - turn_left / track.turn_time)
		track.turn_from = start
		track.turn_to = matrix(now.transform)
		track.turn_time = SANDY_REPLAY_TURN_TIME
		track.turn_until = world.time + SANDY_REPLAY_TURN_TIME
	// Tween from where it was drawn to where it is now.
	var/stepped = frames[old + SANDY_FRAME_X] != frames[at + SANDY_FRAME_X] || frames[old + SANDY_FRAME_Y] != frames[at + SANDY_FRAME_Y]
	var/move_x = (frames[old + SANDY_FRAME_X] - frames[at + SANDY_FRAME_X]) * ICON_SIZE_X + (was.pixel_x + was.pixel_w) - (now.pixel_x + now.pixel_w) + carry_x
	var/move_y = (frames[old + SANDY_FRAME_Y] - frames[at + SANDY_FRAME_Y]) * ICON_SIZE_Y + (was.pixel_y + was.pixel_z) - (now.pixel_y + now.pixel_z) + carry_y
	if((!move_x && !move_y) || abs(move_x) > SANDY_REPLAY_GLIDE_MAX || abs(move_y) > SANDY_REPLAY_GLIDE_MAX)
		return TRUE
	var/time = world.tick_lag
	if(stepped)
		// A step glides until the next one, like a walk does.
		var/ticks = 2
		for(var/next = at + SANDY_FRAME_SIZE, next < end, next += SANDY_FRAME_SIZE)
			if(frames[next + SANDY_FRAME_X] != frames[at + SANDY_FRAME_X] || frames[next + SANDY_FRAME_Y] != frames[at + SANDY_FRAME_Y] || frames[next + SANDY_FRAME_Z] != frames[at + SANDY_FRAME_Z])
				ticks = frames[next + SANDY_FRAME_INDEX] - frames[at + SANDY_FRAME_INDEX]
				break
		time = clamp(ticks, 1, 5) * world.tick_lag
	else if(left > 0)
		time = left
	track.glide_x = move_x
	track.glide_y = move_y
	track.glide_time = time
	track.glide_until = world.time + time
	return TRUE

/// Draws `track`'s current frame on its thing or its stand-in.
/datum/sandy_replay/proc/show(datum/sandy_replay_track/track)
	var/list/frames = track.frames
	var/at = track.cursor
	var/visible = at >= 0 && frames[at + SANDY_FRAME_Z]
	if(track.mode == SANDY_TRACK_STANDIN)
		var/turf/spot = visible ? locate(frames[at + SANDY_FRAME_X], frames[at + SANDY_FRAME_Y], frames[at + SANDY_FRAME_Z]) : null
		if(!spot)
			if(track.standin)
				track.standin.loc = null
			return
		if(!track.standin)
			track.standin = new(spot)
		else
			track.standin.loc = spot // ours, abstract and on no grid: nothing to tell
		var/obj/effect/abstract/sandy_replay_standin/standin = track.standin
		standin.appearance = frames[at + SANDY_FRAME_LOOK]
		standin.dir = frames[at + SANDY_FRAME_DIR]
		standin.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		standin.opacity = FALSE
		standin.luminosity = 0
		settle(track, standin, 0, 0)
		return
	var/atom/movable/thing = track.thing
	if(QDELETED(thing) || track.unmasked)
		return
	var/turf/here = thing.loc
	var/off_x = 0
	var/off_y = 0
	if(!isturf(here))
		visible = FALSE
	if(visible)
		off_x = frames[at + SANDY_FRAME_X] - here.x
		off_y = frames[at + SANDY_FRAME_Y] - here.y
		if(frames[at + SANDY_FRAME_Z] != here.z || abs(off_x) > SANDY_REPLAY_REACH || abs(off_y) > SANDY_REPLAY_REACH)
			visible = FALSE
	if(!visible) // not there yet at this frame, or not anywhere it can be drawn
		animate(thing, time = 0, flags = ANIMATION_END_NOW)
		thing.appearance = track.saved_look
		thing.dir = track.saved_dir
		pin(track)
		thing.alpha = 0
		thing.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		track.expect = thing.appearance
		return
	thing.appearance = frames[at + SANDY_FRAME_LOOK]
	thing.dir = frames[at + SANDY_FRAME_DIR]
	pin(track)
	thing.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	settle(track, thing, off_x * ICON_SIZE_X, off_y * ICON_SIZE_Y)
	track.expect = thing.appearance

/// Shifts `body` (just given a frame's look) by `off_x`, `off_y` pixels, and plays what is left of its tween.
/datum/sandy_replay/proc/settle(datum/sandy_replay_track/track, atom/movable/body, off_x, off_y)
	var/to_w = body.pixel_w + off_x
	var/to_z = body.pixel_z + off_y
	var/turn_left = track.turn_until - world.time
	var/turning = turn_left > 0 && track.turn_time > 0 && track.turn_from && (body.transform ~= track.turn_to)
	if(turning)
		var/matrix/from = track.turn_from
		body.transform = from.Interpolate(track.turn_to, 1 - turn_left / track.turn_time)
	var/left = track.glide_until - world.time
	if(left > 0 && track.glide_time > 0)
		body.pixel_w = to_w + track.glide_x * left / track.glide_time
		body.pixel_z = to_z + track.glide_y * left / track.glide_time
		animate(body, pixel_w = to_w, pixel_z = to_z, time = left, flags = ANIMATION_END_NOW)
	else
		animate(body, pixel_w = to_w, pixel_z = to_z, time = 0, flags = ANIMATION_END_NOW)
	if(turning)
		animate(body, transform = track.turn_to, time = turn_left, easing = SINE_EASING, flags = ANIMATION_PARALLEL)

/// The user's view follows their puppet.
/datum/sandy_replay/proc/follow()
	var/client/viewer = user?.client
	if(!eye || !viewer || !user_track || user_track.cursor < 0)
		return
	var/list/frames = user_track.frames
	var/at = user_track.cursor
	var/turf/spot = frames[at + SANDY_FRAME_Z] ? locate(frames[at + SANDY_FRAME_X], frames[at + SANDY_FRAME_Y], frames[at + SANDY_FRAME_Z]) : null
	if(!spot)
		return
	eye.loc = spot
	var/left = user_track.glide_until - world.time
	if(left > 0 && user_track.glide_time > 0)
		viewer.pixel_x = eye_pixel_x + user_track.glide_x * left / user_track.glide_time
		viewer.pixel_y = eye_pixel_y + user_track.glide_y * left / user_track.glide_time
		animate(viewer, pixel_x = eye_pixel_x, pixel_y = eye_pixel_y, time = left, flags = ANIMATION_END_NOW)
	else
		animate(viewer, pixel_x = eye_pixel_x, pixel_y = eye_pixel_y, time = 0, flags = ANIMATION_END_NOW)

/**
 * A surger's puppet (the user's, or a surging NPC's) just moved on to a new frame. The place where the surge's
 * own look and sound join the replay: `track.came_from` and `track.cursor` are the frames it went from and to
 * (offsets in `track.frames`; came_from is below 0 on its first), so a step is the two frames standing on
 * different turfs. Each step leaves the surge's own rolling-hue afterimage on the tile it left, as a surge does
 * outside a slow-mo (cyberware_cascade_window/on_move()).
 */
/datum/sandy_replay/proc/surger_frame(datum/sandy_replay_track/track)
	var/list/frames = track.frames
	var/from = track.came_from
	var/dest = track.cursor
	if(from < 0 || !frames[from + SANDY_FRAME_Z] || frames[from + SANDY_FRAME_Z] != frames[dest + SANDY_FRAME_Z])
		return
	if(frames[from + SANDY_FRAME_X] == frames[dest + SANDY_FRAME_X] && frames[from + SANDY_FRAME_Y] == frames[dest + SANDY_FRAME_Y])
		return
	var/turf/left = locate(frames[from + SANDY_FRAME_X], frames[from + SANDY_FRAME_Y], frames[from + SANDY_FRAME_Z])
	var/turf/reached = locate(frames[dest + SANDY_FRAME_X], frames[dest + SANDY_FRAME_Y], frames[dest + SANDY_FRAME_Z])
	if(!left || !reached || get_dist(left, reached) > SANDY_REPLAY_GLIDE_MAX / ICON_SIZE_X)
		return // a jump, not steps
	// Two steps can fall between two samples: each tile it crossed gets its afterimage, as each step would.
	var/list/crossed = get_line(left, reached)
	crossed -= reached
	for(var/turf/step_from as anything in crossed)
		track.trail_steps++
		if(track.trail_steps % max(1, track.trail_every))
			continue
		new /obj/effect/temp_visual/decoy/fading/cascade/replay(step_from, frames[dest + SANDY_FRAME_LOOK], frames[dest + SANDY_FRAME_DIR], track.trail_hue, track.trail_alpha)
		afterimages++
		track.trail_hue = (track.trail_hue + SANDY_REPLAY_HUE_STEP) % 360

/// Plays the recorded sounds due by `frame`.
/datum/sandy_replay/proc/play_sounds(frame)
	while(sound_at <= length(sounds))
		var/list/heard = sounds[sound_at]
		if(heard[1] > frame)
			return
		sound_at++
		var/turf/source = heard[2]
		if(QDELETED(source))
			continue
		GLOB.sandy_replay_echoing = TRUE
		playsound(source, heard[3], heard[4], heard[5], heard[6], falloff_exponent = heard[7], frequency = heard[8], pressure_affected = heard[9], ignore_walls = heard[10], falloff_distance = heard[11], use_reverb = heard[12], volume_preference = heard[13])
		GLOB.sandy_replay_echoing = FALSE

/// One afterimage of a surger's trail in the replay: a recorded look, washed in one hue like the live trail.
/obj/effect/temp_visual/decoy/fading/cascade/replay

/obj/effect/temp_visual/decoy/fading/cascade/replay/Initialize(mapload, look, facing, hue = 0, start_alpha = CYBERWARE_CASCADE_AFTERIMAGE_ALPHA)
	. = ..(mapload, null, hue, start_alpha)
	if(look)
		appearance = look
	dir = facing
	name = ""
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	opacity = FALSE
	alpha = start_alpha
	color = cascade_tint_matrix(hue)
	animate(src, alpha = 0, time = duration)

/// The playback timer: one frame a tick.
/datum/sandy_replay/proc/play_frame()
	if(finished || state != SANDY_REPLAY_PLAYING)
		return
	try
		if(QDELETED(user) || cyberware_time_stop_witnessed(user))
			finish()
			return
		var/frame = round((world.time - play_started) / world.tick_lag)
		if(frame > total + 1) // the last frame's tween has played out
			finish()
			return
		frame = min(frame, total)
		hold_nearby()
		play_sounds(frame)
		for(var/datum/sandy_replay_track/track as anything in puppets)
			var/atom/movable/thing = track.thing
			if(QDELETED(thing))
				continue
			var/redraw = FALSE
			if(track.unmasked) // a wrapped proc never came back
				track.unmasked = FALSE
				keep_real(track)
				redraw = TRUE
			else if(thing.appearance != track.expect)
				fold(track)
				redraw = TRUE
			var/moved_on = advance(track, frame)
			if(moved_on || redraw)
				show(track)
				if(track == user_track)
					follow()
			if(moved_on && track.surger)
				surger_frame(track)
		for(var/datum/sandy_replay_track/track as anything in standins.Copy())
			if(frame >= track.last)
				QDEL_NULL(track.standin)
				standins -= track
				continue
			if(advance(track, frame))
				show(track)
	catch(var/exception/error)
		GLOB.sandy_replay_echoing = FALSE
		finish()
		stack_trace("Sandevistan replay frame failed: [error] ([error.file]:[error.line])")

/// Signal proc for [COMSIG_MOVABLE_MOVED] on a puppet: its real tile changed, so its offset does too.
/datum/sandy_replay/proc/on_puppet_moved(atom/movable/thing, atom/old_loc)
	SIGNAL_HANDLER
	if(finished)
		return
	if(thing == user && isturf(old_loc) && get_dist(old_loc, thing) > 2) // a shuttle, a teleport: the recorded tiles mean nothing now
		finish()
		return
	var/datum/sandy_replay_track/track = GLOB.sandy_replay_masked[thing]
	if(track && !track.unmasked)
		show(track)

/// Signal proc for [COMSIG_ATOM_DIR_CHANGE] on a puppet: the game turned it for real.
/datum/sandy_replay/proc/on_puppet_turned(atom/movable/thing, old_dir, new_dir)
	SIGNAL_HANDLER
	var/datum/sandy_replay_track/track = GLOB.sandy_replay_masked[thing]
	if(track)
		track.saved_dir = new_dir

/// Signal proc for [COMSIG_MOVABLE_Z_CHANGED] on the user.
/datum/sandy_replay/proc/on_user_z_changed(datum/source)
	SIGNAL_HANDLER
	finish()

/**
 * Ends the replay: every puppet gets its real look back, stand-ins go, AIs and players are let go, the view goes
 * home and the crash lands. Safe to call at any point and any number of times; one bad thing can't stop the rest.
 */
/datum/sandy_replay/proc/finish()
	if(finished)
		return
	finished = TRUE
	var/was_playing = state == SANDY_REPLAY_PLAYING
	state = SANDY_REPLAY_DONE
	deltimer(play_timer)
	deltimer(watchdog)
	deltimer(sample_timer)
	deltimer(begin_timer)
	play_timer = null
	watchdog = null
	var/list/problems
	for(var/datum/sandy_replay_track/track as anything in puppets)
		try
			var/atom/movable/thing = track.thing
			if(thing)
				if(GLOB.sandy_replay_masked[thing] == track)
					GLOB.sandy_replay_masked -= thing
				UnregisterSignal(thing, list(COMSIG_MOVABLE_MOVED, COMSIG_ATOM_DIR_CHANGE))
				if(!QDELETED(thing) && !track.unmasked)
					wear_real(track)
					thing.sandy_replay_resume()
			track.unmasked = FALSE
		catch(var/exception/error)
			LAZYADD(problems, "[error] ([error.file]:[error.line])")
	sandy_replay_masks = length(GLOB.sandy_replay_masked)
	for(var/datum/sandy_replay_track/track as anything in standins)
		QDEL_NULL(track.standin)
	for(var/mob/living/body as anything in locked)
		try
			unlock(body)
		catch(var/exception/error)
			LAZYADD(problems, "[error] ([error.file]:[error.line])")
	locked.Cut()
	for(var/obj/vehicle/sealed/mecha/mech as anything in mechs)
		if(!QDELETED(mech))
			mech.completely_disabled = mechs[mech]
	mechs.Cut()
	if(!QDELETED(user))
		UnregisterSignal(user, COMSIG_MOVABLE_Z_CHANGED)
		if(eye)
			var/client/viewer = user.client
			if(viewer)
				animate(viewer, pixel_x = eye_pixel_x, pixel_y = eye_pixel_y, time = 0, flags = ANIMATION_END_NOW)
				if(viewer.eye == eye)
					user.reset_perspective()
	QDEL_NULL(eye)
	GLOB.sandy_replay_last = list("played" = was_playing, "frames" = total, "puppets" = length(puppets), "standins" = length(standins), "unhooked" = unhooked, "folded" = folded.Copy(), "unmasks" = unmasks, "afterimages" = afterimages, "sounds" = length(sounds), "sounds_played" = sound_at - 1)
	if(crash && !QDELETED(user) && user.stat != DEAD && cyberware_bearer_lattice(user))
		user.apply_status_effect(/datum/status_effect/cyberware_cascade_crash, crash[1], crash[2])
	crash = null
	if(!QDELING(src))
		qdel(src)
	if(problems)
		stack_trace("Sandevistan replay restore problems: [problems.Join("; ")]")

/**
 * `src` just got its real look back after the replay. A look's vars hold where its animate()s end, so anything that
 * was mid-tween when it became a puppet starts its tween again here from where it has got to by now.
 */
/atom/movable/proc/sandy_replay_resume()
	return

/// Whether the decal is in the middle of drying or spreading, which happen on the client.
/obj/effect/decal/cleanable/blood/proc/sandy_replay_wet()
	return (!dried && can_dry && total_dry_time && drying_time > 0) || length(hv_vis_painting) >= 2

/// The colour update_blood_color() gives it right now without the slow-mo's tint: dried, or partway there while it
/// dries (it animates from this to the dried colour). Null when that isn't a plain colour.
/obj/effect/decal/cleanable/blood/proc/sandy_replay_colour()
	var/base
	for(var/priority in 1 to length(atom_colours)) // the slow-mo's tint is a filter at TEMPORARY_COLOUR_PRIORITY
		if(priority == TEMPORARY_COLOUR_PRIORITY)
			continue
		var/list/entry = atom_colours[priority]
		if(!entry)
			continue
		if(entry[ATOM_COLOR_TYPE_INDEX] == ATOM_COLOR_TYPE_FILTER || !istext(entry[ATOM_COLOR_VALUE_INDEX]))
			return null
		base = entry[ATOM_COLOR_VALUE_INDEX]
		break
	if(!base)
		var/list/blood_DNA = GET_ATOM_BLOOD_DECALS(src)
		if(!length(blood_DNA))
			blood_DNA = GET_ATOM_BLOOD_DNA(src)
		base = length(blood_DNA) ? get_color_from_blood_list(blood_DNA) : BLOOD_COLOR_RED
	if(!istext(base))
		return null
	if(dried || drying_time <= 0)
		return get_dried_color(base)
	if(!total_dry_time)
		return base
	return BlendRGB(base, get_dried_color(base), round(1 - drying_time / total_dry_time, 0.01))

/// Where its hyperviolence paint (hv_vis_paint()) has got to right now: list(transform, alpha), or null.
/obj/effect/decal/cleanable/blood/proc/sandy_replay_paint_now()
	var/list/keys = hv_vis_painting
	if(length(keys) < 2)
		return null
	var/now = world.time
	for(var/i in 2 to length(keys))
		var/list/ahead = keys[i]
		if(now >= ahead[3])
			continue
		var/list/behind = keys[i - 1]
		if(now <= behind[3])
			return list(behind[1], behind[2])
		var/span = ahead[3] - behind[3]
		var/progress = span > 0 ? hv_vis_eased(clamp((now - behind[3]) / span, 0, 1), ahead[4]) : 1
		var/matrix/from = behind[1]
		return list(from.Interpolate(ahead[1], progress), behind[2] + (ahead[2] - behind[2]) * progress)
	return null

/// Wet blood dries (and spreads) by animate(): without this it jumps to its dried look as the replay ends.
/// update_blood_color() works out how far it has got and plays the rest (hv_vis_paint_on() for the spread).
/obj/effect/decal/cleanable/blood/sandy_replay_resume()
	if(!dried || length(hv_vis_painting))
		update_atom_colour()

/// The surge window is closing on `user`: if their replay is about to play or playing, the crash waits for it.
/// Returns TRUE if it took the crash.
/proc/sandy_replay_defer_crash(mob/living/user, length, stamina)
	var/datum/sandy_replay/replay = GLOB.sandy_replays[user]
	if(!replay || replay.finished || (replay.state != SANDY_REPLAY_PENDING && replay.state != SANDY_REPLAY_PLAYING))
		return FALSE
	replay.crash = list(length, stamina)
	return TRUE

/// Called from playsound(): a sound played in a slow-mo is recorded for its replay. A /sound datum is a looping
/// sound's next segment (machines, weather), which plays on live and isn't recorded.
/proc/sandy_replay_hear(turf/source, soundin, vol, vary, extrarange, falloff_exponent, frequency, pressure_affected, ignore_walls, falloff_distance, use_reverb, volume_preference)
	if(GLOB.sandy_replay_echoing || isdatum(soundin))
		return
	for(var/user in GLOB.sandy_replays)
		var/datum/sandy_replay/replay = GLOB.sandy_replays[user]
		replay.hear(source, list(soundin, vol, vary, extrarange, falloff_exponent, frequency, pressure_affected, ignore_walls, falloff_distance, use_reverb, volume_preference))

/// Whether a replay is showing on (or about to show for) `user`.
/proc/sandy_replay_showing(mob/living/user)
	var/datum/sandy_replay/replay = GLOB.sandy_replays[user]
	return !!replay && !replay.finished && (replay.state == SANDY_REPLAY_PENDING || replay.state == SANDY_REPLAY_PLAYING)

// =========================================================================
// CHANGES TO A PUPPET
// =========================================================================
// Overlays, update_appearance(), atom colours, filters, lying turns and deaths all change a thing's look step by
// step from what it is now. On a puppet that would land on the recorded look and be lost, so each goes through a
// wrapper: real look on, the change, puppet back on. With no replay running each costs one number check.

/// `thing` is about to be changed: if it is a puppet it wears its real look until sandy_replay_remask(). Returns
/// its track if this call took the puppet off.
/proc/sandy_replay_unmask(atom/thing)
	var/datum/sandy_replay_track/track = GLOB.sandy_replay_masked[thing]
	if(!track || track.unmasked || !track.owner)
		return null
	track.owner.unmask(track)
	return track

/proc/sandy_replay_remask(datum/sandy_replay_track/track)
	track.owner?.remask(track)

/atom/add_overlay(list/add_overlays)
	if(!sandy_replay_masks)
		return ..()
	var/datum/sandy_replay_track/track = sandy_replay_unmask(src)
	. = ..()
	if(track)
		sandy_replay_remask(track)

/atom/cut_overlay(list/remove_overlays)
	if(!sandy_replay_masks)
		return ..()
	var/datum/sandy_replay_track/track = sandy_replay_unmask(src)
	. = ..()
	if(track)
		sandy_replay_remask(track)

/atom/cut_overlays()
	if(!sandy_replay_masks)
		return ..()
	var/datum/sandy_replay_track/track = sandy_replay_unmask(src)
	. = ..()
	if(track)
		sandy_replay_remask(track)

/atom/update_appearance(updates = ALL)
	if(!sandy_replay_masks)
		return ..()
	var/datum/sandy_replay_track/track = sandy_replay_unmask(src)
	. = ..()
	if(track)
		sandy_replay_remask(track)

/atom/update_atom_colour()
	if(!sandy_replay_masks)
		return ..()
	var/datum/sandy_replay_track/track = sandy_replay_unmask(src)
	. = ..()
	if(track)
		sandy_replay_remask(track)

/atom/update_filters()
	if(!sandy_replay_masks)
		return ..()
	var/datum/sandy_replay_track/track = sandy_replay_unmask(src)
	. = ..()
	if(track)
		sandy_replay_remask(track)

/mob/living/update_transform(resize = RESIZE_DEFAULT_SIZE)
	if(!sandy_replay_masks)
		return ..()
	var/datum/sandy_replay_track/track = sandy_replay_unmask(src)
	. = ..()
	if(track)
		sandy_replay_remask(track)

/mob/living/set_body_position(new_value)
	if(!sandy_replay_masks)
		return ..()
	var/datum/sandy_replay_track/track = sandy_replay_unmask(src)
	. = ..()
	if(track)
		sandy_replay_remask(track)

/mob/living/death(gibbed)
	if(!sandy_replay_masks)
		return ..()
	var/datum/sandy_replay_track/track = sandy_replay_unmask(src)
	. = ..()
	if(track)
		sandy_replay_remask(track)

/mob/living/revive(full_heal_flags = NONE, excess_healing = 0, force_grab_ghost = FALSE)
	if(!sandy_replay_masks)
		return ..()
	var/datum/sandy_replay_track/track = sandy_replay_unmask(src)
	. = ..()
	if(track)
		sandy_replay_remask(track)

#undef SANDY_REPLAY_TRAIT
#undef SANDY_REPLAY_OUTLINE
#undef SANDY_REPLAY_TINT
#undef SANDY_REPLAY_RECORDING
#undef SANDY_REPLAY_PENDING
#undef SANDY_REPLAY_PLAYING
#undef SANDY_REPLAY_DONE
#undef SANDY_TRACK_PUPPET
#undef SANDY_TRACK_STANDIN
#undef SANDY_REPLAY_REACH
#undef SANDY_REPLAY_GLIDE_MAX
#undef SANDY_REPLAY_WATCHDOG
#undef SANDY_REPLAY_TURN_TIME
#undef SANDY_REPLAY_HUE_STEP
#undef SANDY_REPLAY_MAX_SOUNDS
#undef SANDY_REPLAY_HOLD_RANGE
#undef SANDY_FRAME_SIZE
#undef SANDY_FRAME_INDEX
#undef SANDY_FRAME_LOOK
#undef SANDY_FRAME_X
#undef SANDY_FRAME_Y
#undef SANDY_FRAME_Z
#undef SANDY_FRAME_DIR
