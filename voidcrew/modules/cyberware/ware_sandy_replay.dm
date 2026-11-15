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
 * A slow-mo never ends while its user is in the middle of an execution or finisher: it holds until the move is over
 * (cyberware_cascade_window/proc/slowmo_time_up(), ware_sandy_timestop.dm), so the whole move is in the recording and
 * the replay's hold never cuts it short. Another body still mid-move when it ends (an NPC's execution) is waited out:
 * the world goes back to normal speed, nobody is held, and the recording runs on until the move is over
 * (moves_running()). A move still going after SANDY_REPLAY_WAIT_MAX gets no replay at all.
 * While any recorded body is mid-move a frame is one real tick, not one tick of the slowed world: the walk-up replays
 * compressed, the move itself at the speed it really had, so its poses (a tick or two each) can be shown.
 * The surge's crash starts when the replay ends. A user who went down in the slow-mo still watches it: their crit,
 * oxygen, damage and knocked-out screens are off their view while it plays and back as it ends (clear_view()).
 *
 * It looks and sounds like a surge: the surge-on sound plays at the start, the sounds made in the field play again
 * at normal pitch (playsound() hands them over), and every surger in it (the user, or a mob on its own surge) leaves
 * the surge's afterimage trail, coloured by age. A turn of a body (a fall) is tweened, as tg's lying turn is.
 *
 * A finisher rig hides a body and draws it as posed pictures (chrome_puppet_rig.dm, mantis_rig.dm). Those pictures are
 * recorded like anything else, and the animate() chains that pose them are journaled (sandy_replay_animate(), routed
 * there by a macro in the rig and finisher files) and played again on their stand-ins: the replay shows the move.
 *
 * Not replayed (they show as they really are): lights, fire, smoke and particles, turf changes, attack lunges,
 * flick()s, tweens on bodies other than steps and turns (flinches, a gun execution's lean, the spin and arc of flying
 * gore, blood drying and spreading), anything in vis_contents, runechat, camera shakes, and looping sounds.
 */

/// Trait source of the replay's AI pause and input lock.
#define SANDY_REPLAY_TRAIT "sandy_replay"
/// The user's edge glow in a slow-mo (SANDY_STOP_OUTLINE in ware_sandy_timestop.dm, which is included after this file).
#define SANDY_REPLAY_OUTLINE "sandy_time_stop_outline"
/// The slow-mo's tint filter on bodies and items (SANDY_STOP_TINT in ware_sandy_timestop.dm).
#define SANDY_REPLAY_TINT "sandy_time_stop_tint"
/// The filter that hides what turned up after the recording, for the length of the replay.
#define SANDY_REPLAY_UNBORN "sandy_replay_unborn"
/// Filter name hiding what the recording saw change, in the tick between the slow-mo's end and the replay's start.
#define SANDY_REPLAY_PENDING_HIDE "sandy_replay_pending_hide"
/// Fullscreen category of the slow-mo's release flash (SANDY_STOP_FLASH in ware_sandy_timestop.dm).
#define SANDY_REPLAY_RELEASE_FLASH "sandy_time_stop_flash"

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
/// The same for a surger. One frame is half a second of a Cascade's slow-mo: at a run he crosses three or four tiles in
/// it, and a lunge on top of that is more. Counted as a jump, he blinked across the room in the replay with no trail.
#define SANDY_REPLAY_SURGE_GLIDE_MAX 256
/// The most steps kept for a surger between two frames. More than that and the trail is laid in a straight line.
#define SANDY_REPLAY_PATH_MAX 16
/// Extra time the watchdog gives the replay before it ends it.
#define SANDY_REPLAY_WATCHDOG (1 SECONDS)
/// How long a recorded turn of a body (a fall, getting up) takes in the replay: tg's own lying turn.
#define SANDY_REPLAY_TURN_TIME 2
/// The most times a replay plays a surger's external cue as he bursts off (surger_frame()).
#define SANDY_REPLAY_BURST_CUES_MAX 6
/// Everyone and everything within this many tiles of the user holds still for the replay (the slow-mo's witness range:
/// any other player this close is crew, or there would be no replay).
#define SANDY_REPLAY_HOLD_RANGE 11
/// How far from a surger a recording takes what calls sandy_replay_made(): a slowed room reaches 16 tiles from him
/// (SANDY_COVER_ROOM_REACH), and a blow throws blood five tiles on.
#define SANDY_REPLAY_MADE_REACH 21
/// The longest the replay stays on its last frame while gore from a kill in its last moments lands (land()).
#define SANDY_REPLAY_LANDING_MAX (1.5 SECONDS)
/// The longest of that it waits for its own animations of that gore to play out, before the real gore flies on.
#define SANDY_REPLAY_LANDING_TWEENS (0.5 SECONDS)
/// A kill this close to the recording's end, in its frames, has its gore landed for it.
#define SANDY_REPLAY_LANDING_FRAMES 10
/// How long a slash over someone hit stays in the replay once shown: through its strike frames. Its whole length
/// (0.4 s) left it hanging on the body well after the replayed attacker had gone, and read as a slash from nowhere.
#define SANDY_REPLAY_PICTURE_TIME (0.2 SECONDS)
/// The most sounds one recording keeps of the world around the user (footsteps, casings, NPCs' guns).
#define SANDY_REPLAY_MAX_SOUNDS 200
/// The most it keeps in all: past SANDY_REPLAY_MAX_SOUNDS only the user's and its crewmates' own sounds go in (their
/// blows, shots and steps, and anything on the user's own or next tile), so a busy room can't crowd out the fight.
#define SANDY_REPLAY_MAX_OWN_SOUNDS 500
/// Recorded sounds play this loud in the replay: under the surge's own sound, which leads it.
#define SANDY_REPLAY_SOUND_VOLUME 0.6
/// One sound file starting again this soon in the replay is skipped: thirteen seconds of fight squeezed into one
/// would otherwise pile the same shot or step on itself.
#define SANDY_REPLAY_SOUND_GAP (2 * world.tick_lag)
/// The longest the replay waits, after the slow-mo, for an execution or finisher in it to end. A move still going
/// then gets no replay rather than being cut short by the replay's hold.
#define SANDY_REPLAY_WAIT_MAX (8 SECONDS)
/// The filters the finisher rigs hide a body under while its posed pictures stand in for it (CHROME_RIG_HIDE_FILTER in
/// chrome_puppet_rig.dm, MANTIS_RIG_HIDE_FILTER in mantis_rig.dm). A body wearing one is in the middle of a move.
#define SANDY_REPLAY_RIG_HIDES list("chrome_rig_hide", "mantis_rig_hide")

/// The most shots in the air one recording follows at once. A room's worth of rounds is far fewer; past it a new shot is
/// left out of the replay and the recording says so (shots_capped, and once in the game log).
#define SANDY_REPLAY_MAX_SHOTS 64

/// The shortest a one-shot effect's animation plays in the replay: two frames. Compressed ten times a muzzle flash or an
/// impact ring would be over between two frames and never drawn. Longer and it hangs behind the action it belongs to.
#define SANDY_REPLAY_ONESHOT_MIN (world.tick_lag * 2)
/// The fewest frames a one-shot effect that only plays its icon's own frames (a muzzle flash) is drawn for.
#define SANDY_REPLAY_ONESHOT_FRAMES 2

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
/// A replay starting: a playsound() in its begin() goes to its viewers, from their views (sandy_replay_hear()).
GLOBAL_DATUM(sandy_replay_routing, /datum/sandy_replay)
/// The world.time that was set, so a start that failed partway can't route later sounds.
GLOBAL_VAR_INIT(sandy_replay_routing_time, -1)
#ifdef UNIT_TESTS
/// For tests: every sound the replay played to someone, as list(listener, /sound).
GLOBAL_LIST_EMPTY(sandy_replay_heard)
#endif

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
	/// Surger: the frames its own surge ran between. A crewmate walks in before he surges, and goes on slowed after his
	/// own time is out while the shared slow-mo runs: those steps leave no trail (surger_frame()).
	var/surge_from = 0
	var/surge_until = INFINITY
	/// Surger: its surge's trail (ware_legend.dm): afterimages behind it while it moves, per tile, and the newest one's alpha.
	var/trail_length = CYBERWARE_CASCADE_TRAIL_LENGTH
	var/trail_per_tile = CYBERWARE_CASCADE_TRAIL_PER_TILE
	var/trail_alpha = CYBERWARE_CASCADE_AFTERIMAGE_ALPHA
	/// Surger: whether the trail's numbers were read from its window yet.
	var/trail_read = FALSE
	/// Surger: how many frames its last step took, for a step after a pause.
	var/trail_step_frames = 0
	/// Surger: the tile its last replayed step left, for the afterimages spread back along that step (surger_frame()).
	var/turf/trail_prev
	/// Recorder, surger: the tiles it stepped onto since its last frame, as flat x, y pairs (on_surger_stepped()).
	var/list/path
	/// Surger: the steps it took to reach a frame where it took more than one, by that frame's index as text. A corner
	/// turned between two samples is two frames a diagonal apart: the trail goes round it as he did (surger_frame()).
	var/list/ways
	/// Recorder, surger: the recording's clock (frame_exact()) at its last step.
	var/stepped_at = 0
	/// Surger: the clock at the last step it took to reach a frame, by that frame's index as text. Steps are paced by
	/// when they were really taken: two fall in one frame and three in the next at one steady run (surger_frame()).
	var/list/step_clock
	/// Playback, surger: the clock of the last step replayed.
	var/trail_stepped_at = 0
	/// Surger: how long a step takes it (its movement delay, in deciseconds), as of its last recorded step. The live
	/// trail gives the first step after a pause that long (cyberware_cascade_window/on_move()), and so does the replay's.
	var/stride = 0
	/// Playback, surger: world.time its last external cue played.
	var/burst_cue_at = 0
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
	/// Playback, surger: the tween's way when it isn't a straight line (a corner turned between two frames): flat x, y
	/// pixel offsets from where it ends, the first where it starts and the last 0, 0, each leg taking the same time.
	var/list/glide_way
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
	/// Animations played on the thing while it was recorded (sandy_replay_journal()), each list(frame, look before it,
	/// time scale, list(step arguments...)).
	var/list/events
	/// Playback: the next animation to play, and when the ones playing end.
	var/event_at = 1
	var/anim_until = 0
	/// Puppet: the chain playing on it (its animate() argument lists), when it started and the pixel shift it was
	/// played with: a redraw mid-chain (a new frame's look) plays the rest of it again (resume_chain()).
	var/list/chain
	var/chain_start = 0
	var/list/chain_shift
	/// Playback: the look the stand-in was last given.
	var/drawn_look
	/// A shot (a projectile): it flies in a line between its frames, a frame at a time (fly()).
	var/flier = FALSE
	/// A one-shot effect (a temp visual: a muzzle flash, an impact ring, cracks): its animations play for at least
	/// SANDY_REPLAY_ONESHOT_MIN, so a compressed one is drawn at all, and its stand-in stays until they are done.
	var/oneshot = FALSE
	/// Gore handed back early, flying on for real under the replay's last frame (land()): the replay leaves it be.
	var/landing = FALSE
	/// A one-shot whose animation is its icon's own frames (a slash over someone hit): how long its stand-in stays once
	/// shown, so the frames play through at their own pace instead of ending with the one replay frame it lasted.
	var/plays_out = 0
	/// Playback: the glide playing now is a step to another tile, not a pose's own shift on the spot.
	var/glide_step = FALSE
	/// Each shot it fired: list(the frame it is first drawn in, x, y of the real tile it was fired from), where its
	/// muzzle flash and bullet are recorded. A step glides onto that tile by then, or they are drawn ahead of the gun
	/// (shooting_at()).
	var/list/shot_frames

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
	/// Held mobs with an AI controller, to list(the status it had, the status tg would have given it) as the hold began.
	var/list/ai_before = list()
	/// Things that turned up after the recording ended (gore still landing from the last blow), hidden until the end.
	var/list/unborn = list()
	/// Live rig pictures hidden for the replay (by invisibility, see hide_rig_picture()), to their own invisibility.
	var/list/rig_hidden = list()
	/// Things hidden in the tick between the slow-mo's end and the replay's start (hide_pending()).
	var/list/pending_hidden = list()
	/// Progress bars hidden for the replay (hide_progress_bars()), shown again at the end if still there.
	var/list/hidden_bars = list()
	/// Mechs switched off, to what completely_disabled was.
	var/list/mechs = list()
	/// Turrets and lit grenades whose clocks the hold has stopped (hold_machines()), to TRUE.
	var/list/held_machines = list()
	/// The user's own track, for the camera.
	var/datum/sandy_replay_track/user_track
	/// What the user's view follows.
	var/obj/effect/abstract/sandy_replay_eye/eye
	/// Sound files played in the replay, to the world.time each last started (play_sounds()).
	var/list/sound_started = list()
	/// The user's client pixel offsets before the replay.
	var/eye_pixel_x = 0
	var/eye_pixel_y = 0
	/// The user's crit and knocked-out screens were taken off their view for the replay (clear_view()).
	var/view_cleared = FALSE
	/// The same for the other members of a shared slow-mo watching this replay, to TRUE.
	var/list/members_cleared = list()
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
	/// How many replayed steps laid their trail along the way the surger really went (surger_way()).
	var/ways_followed = 0
	/// External cues played as its surgers burst off (SANDY_REPLAY_BURST_CUES_MAX).
	var/burst_cues = 0
	/// The slow-mo is over but a move in it is still going (moves_running()): recording goes on, on the same clock, from
	/// this world.time, until it ends.
	var/wait_started = 0
	/// The recording's clock: frames are counted from `clock_frame` at world.time `clock_time`, `clock_rate` frames a
	/// decisecond. A frame is one tick of the slowed world, all the way through: the replay (a frame a tick) plays
	/// everything, an execution in it included, as many times faster as the user was faster than the world (owner,
	/// 2026-11-12: "based on facts"). 10x for the Cascade, 4x for the service model, 2.5x for the street model.
	var/clock_frame = 0
	var/clock_time = 0
	var/clock_rate = 1
	/// The clock's rate through the recording: list(the frame it began at, the rate), in order. A shared slow-mo changes
	/// pace as its members' time runs out (sandy_rebase()), and what the replay scales by the rate (a trail's step, a
	/// body's turn) takes the rate its frame was recorded at (rate_at()).
	var/list/clock_rates
	/// The last frame the sample timer took.
	var/last_sampled = -1
	/// Recording: the animation being journaled now (sandy_replay_journal()), to add its next steps to.
	var/list/open_event
	/// Animations journaled, for tests and recordings.
	var/journaled = 0
	/// How long the last wait was, for tests and recordings.
	var/waited = 0
	/// Playback: journaled animations played, and chains played again after a redraw, for tests and recordings.
	var/events_played = 0
	var/chains_resumed = 0
	/// Playback: what each journaled animation was played on and when, for tests and recordings.
	var/list/event_log = list()
	/// Every body that was mid-move during the wait: what turns up around them is recorded.
	var/list/wait_bodies = list()
	/// Shots being recorded that are still in the air.
	var/shots_live = 0
	/// Shots left out because SANDY_REPLAY_MAX_SHOTS were already in the air.
	var/shots_capped = 0
	/// Shots still flying when the recording ended, held where they are until the replay is over (hold_shots()).
	var/list/held_shots = list()
	/// Gore in flight held for the replay (hold_gore()): move loops, tumbles to the time left to their next step, and
	/// throws to list(world.time they were held at, the delay they had counted).
	var/list/held_gore = list()
	/// The recording has run out and the replay is staying on its last frame while gore lands (land()): 2 once the real
	/// gore flies on. world.time it began, and the gore flying on.
	var/landing_stage = 0
	var/landing_started = 0
	var/list/landing = list()
	/// The afterimages the replay has left behind its surgers: gone with it, however long it stayed on its last frame.
	var/list/trail_copies = list()
	/// world.time the last of it to land has left its last drops by: the replay stays that long.
	var/landing_settle = 0
	/// Where and when a finisher's posed pictures were first drawn (sandy_rig_picture()): list(frame, x, y) each. A
	/// surger gliding onto that tile is there by then (advance()).
	var/list/rig_frames = list()
	/// world.time the recording ended at. What was mid-tween then (a spray painting in) carries on from there when it is
	/// handed back, as if the replay took no time.
	var/ended_at = 0
	/// world.time the sprays still painting in when the recording ended are done by, once land() lets them carry on.
	var/paint_until = 0
	/// The longest one frame's sample of everything recorded took, in milliseconds, for tests and recordings.
	var/sample_cost = 0

/datum/sandy_replay/New(datum/proximity_monitor/advanced/timestop/sandevistan/_field, mob/living/_user)
	field = _field
	user = _user
	started = world.time
	interval = world.tick_lag / field.time_scale
	clock_time = started
	clock_rate = 1 / interval
	clock_rates = list(list(0, clock_rate))
	var/datum/sandy_replay/old = GLOB.sandy_replays[user]
	if(old)
		qdel(old) // a replay still showing ends here
	GLOB.sandy_replays[user] = src
	sample_timer = addtimer(CALLBACK(src, PROC_REF(sample)), world.tick_lag, TIMER_LOOP | TIMER_STOPPABLE | TIMER_DELETE_ME)
	notice(user)
	last_sampled = 0

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
	wait_bodies.Cut()
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
	return clock_frame + round((world.time - clock_time) * clock_rate + 0.001)

/// The frame the recording is at now, with the part of it gone by.
/datum/sandy_replay/proc/frame_exact()
	if(state != SANDY_REPLAY_RECORDING)
		return total
	return clock_frame + (world.time - clock_time) * clock_rate

/**
 * The frame a change made right now is drawn from. Everything recorded is sampled once a frame, in one pass: once this
 * frame's pass has run, what else changes in this tick (the rig hiding the body its pictures stand in for, or showing
 * it again) is only seen in the next frame's pass. So a picture made, or a pose started, after the pass belongs to the
 * next frame too, or the replay shows it a frame before the body's matching change: the user drawn twice as a move
 * starts, and fading with its pictures as it ends.
 */
/datum/sandy_replay/proc/frame_due()
	return max(frame_exact(), last_sampled + 1)

/// Whether `thing` is recorded at all.
/datum/sandy_replay/proc/recordable(atom/movable/thing)
	var/static/list/skipped = typecacheof(list(
		/obj/effect/abstract,
		/obj/effect/timestop,
		/obj/effect/temp_visual/decoy/fading/cascade, // the surge's trail
		/obj/effect/temp_visual/cyberware_time_ring,
		/obj/effect/hotspot,
		/obj/effect/particle_effect,
		/obj/effect/dummy/lighting_obj, // a flash of light (a gunshot's): its light is an underlay, drawn whole on a stand-in
		/obj/effect/landmark,
		/atom/movable/screen,
	))
	if(!ismovable(thing) || QDELETED(thing) || thing.invisibility >= INVISIBILITY_ABSTRACT)
		return FALSE
	if(ismob(thing) && !isliving(thing)) // ghosts and camera eyes
		return FALSE
	if(sandy_rig_picture(thing)) // a finisher rig's posed piece of a body: the move is replayed with it
		return TRUE
	if(sandy_bearer_picture(thing)) // a swing or a slash a chrome weapon plays on a body
		return TRUE
	if(isprojectile(thing))
		var/obj/projectile/shot = thing
		if(shot.hitscan) // crosses the room in a tick: its tracer, muzzle and impact effects are what is seen, and recorded
			return FALSE
	return !skipped[thing.type]

/// The field saw `thing`: start recording it.
/datum/sandy_replay/proc/notice(atom/movable/thing)
	if(state != SANDY_REPLAY_RECORDING || tracks[thing] || !recordable(thing))
		return
	if(isprojectile(thing) && !shot_room())
		return
	var/datum/sandy_replay_track/track = new
	track.owner = src
	track.thing = thing
	track.flier = isprojectile(thing)
	track.first = (covering && !sandy_rig_picture(thing)) ? 0 : round(frame_due()) // a rig picture is made by the move: it was never there before it
	tracks[thing] = track
	RegisterSignal(thing, COMSIG_QDELETING, PROC_REF(on_thing_deleted))
	if(track.flier && !shot_fired(thing))
		// Seen as it is put on the floor, before fire() turns it the way it flies: its first frame is taken once it is
		// fired (on_shot_fired()), or the replay draws it upright on the shooter for a frame.
		RegisterSignal(thing, COMSIG_PROJECTILE_FIRE, PROC_REF(on_shot_fired))
	sample_track(track, track.first)
	if(istype(thing, /obj/effect/temp_visual))
		track.oneshot = TRUE
		intro(track)
		if(ismovable(thing.loc) && shown_on(thing)) // a muzzle flash, drawn on the shooter's tile
			shot_from(thing.loc, track.first)
	else if(sandy_bearer_picture(thing))
		track.oneshot = TRUE
		// On someone hit it plays through where they are. On the surger it would be left behind as he moves on: it
		// lasts its own replay frame there.
		var/obj/effect/abstract/cyberware_anim/picture = thing
		if(picture.bearer != user && !sandy_session_member(src, picture.bearer))
			track.plays_out = SANDY_REPLAY_PICTURE_TIME
	else if(track.flier && shot_fired(thing))
		var/obj/projectile/shot = thing
		shot_from(shot.firer, track.first)
	if(sandy_rig_picture(thing) && length(rig_frames) < SANDY_REPLAY_MAX_SHOTS * 4)
		var/turf/posed_on = shown_on(thing)
		if(posed_on)
			rig_frames += list(list(track.first, posed_on.x, posed_on.y))
	if(sandy_rig_picture(thing) || track.oneshot || track.flier)
		var/matrix/turned = thing.transform
		event_log += "notice [thing.type] f[frame_exact()] first=[track.first] on=[shown_on(thing) ? "map" : "off"] dir=[thing.dir] T=[turned.a],[turned.b],[turned.d],[turned.e]"

/**
 * A temp visual that animates itself in its own Initialize() (tg's ring) is first seen with its vars already at the
 * tween's end (grown, faded out): it would replay as nothing. Its sandy_replay_intro() gives the look it starts with and
 * the animations it plays, and those go in its track as if journaled.
 */
/datum/sandy_replay/proc/intro(datum/sandy_replay_track/track)
	var/obj/effect/temp_visual/effect = track.thing
	var/list/intro = effect.sandy_replay_intro()
	if(!length(intro))
		return
	// The look it starts with goes on as an animation of no length before the rest: a later sample of it (the field's
	// tint coming on in the same frame) can't take its place.
	var/list/start = intro[1]
	start["time"] = 0
	LAZYADD(track.events, list(list(track.first, null, world.tick_lag * clock_rate, list(start))))
	for(var/list/steps as anything in intro[2])
		LAZYADD(track.events, list(list(track.first, null, world.tick_lag * clock_rate, steps)))
		journaled++
	event_log += "intro [effect.type] f[track.first] chains=[length(intro[2])]"

/// The field just changed how `thing` looks (its tint): take the sample again.
/datum/sandy_replay/proc/resample(atom/movable/thing)
	var/datum/sandy_replay_track/track = tracks[thing]
	if(track && state == SANDY_REPLAY_RECORDING)
		track.last_raw = null
		sample_track(track, covering ? track.first : round(frame_due()))

/// The sample timer, every tick: one frame of everything recorded, when the clock is on a new one.
/datum/sandy_replay/proc/sample()
	if(state != SANDY_REPLAY_RECORDING)
		return
	for(var/atom/movable/thing as anything in tracks)
		var/datum/sandy_replay_track/track = tracks[thing]
		if(track.surger && !track.trail_read)
			read_trail(track)
	var/list/moving = moves_running()
	var/frame = frame_now()
	if(frame <= last_sampled)
		return
	last_sampled = frame
	if(wait_started)
		// No field hands things over now: what the move leaves around the bodies doing it (a torn-off limb, a head,
		// blood, gibs) is picked up here, and drawn from the frame it turns up in. The bodies are kept to the end, so
		// what the move's last blow makes, in the tick it ends, is picked up too.
		wait_bodies |= moving
		for(var/mob/living/body as anything in wait_bodies)
			if(QDELETED(body) || !isturf(body.loc))
				continue
			for(var/atom/movable/thing in range(3, body))
				notice(thing)
	var/cost_from = TICK_USAGE
	for(var/atom/movable/thing as anything in tracks)
		sample_track(tracks[thing], frame)
	sample_cost = max(sample_cost, TICK_USAGE_TO_MS(cost_from))
	if(wait_started && (!length(moving) || world.time - wait_started >= SANDY_REPLAY_WAIT_MAX))
		end_wait(!length(moving))

/// Adds a frame to `track` if the thing changed since its last one.
/datum/sandy_replay/proc/sample_track(datum/sandy_replay_track/track, frame)
	var/atom/movable/thing = track.thing
	if(track.flier && !shot_fired(thing))
		return // not turned the way it flies yet (notice())
	var/turf/here = shown_on(thing)
	var/x = 0
	var/y = 0
	var/z = 0
	if(isturf(here))
		x = here.x
		y = here.y
		z = here.z
	// The Cascade's spine nodes light one by one over the first frame's span (cyberware_anim.dm): frame 0 opens with
	// them lit, as the rest of the surge has them, without touching the live boot.
	var/mob/living/carbon/carbon_bearer = iscarbon(thing) ? thing : null
	var/obj/item/organ/cyberimp/cyberware/cascade/lattice = carbon_bearer ? cyberware_bearer_lattice(carbon_bearer) : null
	var/old = (lattice && findtext(lattice.node_look, "boot") == 1) ? lattice.node_look : null
	if(old)
		lattice.node_look = "lit"
		carbon_bearer.update_body_parts()
	var/raw = thing.appearance
	var/facing = thing.dir
	var/obj/effect/abstract/cyberware_anim/picture = sandy_bearer_picture(thing) ? thing : null
	if(picture?.bearer)
		facing = picture.bearer.dir // drawn the way its bearer faces (VIS_INHERIT_DIR)
	var/list/frames = track.frames
	var/at = length(frames) - SANDY_FRAME_SIZE
	// Wet blood dries and spreads on the client (animate()): its vars already hold the end, so it is looked at every sample.
	var/obj/effect/decal/cleanable/blood/wet = istype(thing, /obj/effect/decal/cleanable/blood) ? thing : null
	if(wet && !wet.sandy_replay_wet())
		wet = null
	if(track.path && at >= 0 && frames[at + SANDY_FRAME_X] == x && frames[at + SANDY_FRAME_Y] == y && frames[at + SANDY_FRAME_Z] == z)
		track.path = null // back where its last frame has it: nothing to go round
	if(!wet && at >= 0 && raw == track.last_raw && frames[at + SANDY_FRAME_X] == x && frames[at + SANDY_FRAME_Y] == y && frames[at + SANDY_FRAME_Z] == z && frames[at + SANDY_FRAME_DIR] == facing)
		if(old)
			lattice.node_look = old
			carbon_bearer.update_body_parts()
		return
	track.last_raw = raw
	if(!track.surger && (thing == user || field?.surging[thing]))
		become_surger(track)
	else if(track.surger && !track.trail_read)
		read_trail(track)
	var/look = clean_look(thing)
	if(carbon_bearer)
		look = unfolded_look(carbon_bearer, look)
	if(old)
		lattice.node_look = old
		carbon_bearer.update_body_parts()
	if(wet)
		look = wet_look(wet, look)
	if(track.flier)
		look = shot_look(thing, look)
	if(picture)
		look = picture_look(picture, look)
	if(at >= 0)
		if(frames[at + SANDY_FRAME_LOOK] == look && frames[at + SANDY_FRAME_X] == x && frames[at + SANDY_FRAME_Y] == y && frames[at + SANDY_FRAME_Z] == z && frames[at + SANDY_FRAME_DIR] == facing)
			return
		if(frames[at + SANDY_FRAME_INDEX] >= frame) // sampled twice in one frame: the later look stands
			if(track.path) // it stepped on since the first take: those steps follow the ones that led to it
				var/key = "[frames[at + SANDY_FRAME_INDEX]]"
				var/list/way = (LAZYACCESS(track.ways, key) || list(frames[at + SANDY_FRAME_X], frames[at + SANDY_FRAME_Y])) + track.path
				if(length(way) <= SANDY_REPLAY_PATH_MAX * 2)
					LAZYSET(track.ways, key, way)
				else
					LAZYREMOVE(track.ways, key)
				track.path = null
			if(track.stepped_at)
				LAZYSET(track.step_clock, "[frames[at + SANDY_FRAME_INDEX]]", track.stepped_at)
			frames[at + SANDY_FRAME_LOOK] = look
			frames[at + SANDY_FRAME_X] = x
			frames[at + SANDY_FRAME_Y] = y
			frames[at + SANDY_FRAME_Z] = z
			frames[at + SANDY_FRAME_DIR] = facing
			return
	if(length(track.path) > 2) // more than one step since its last frame
		LAZYSET(track.ways, "[frame]", track.path)
	track.path = null
	if(track.stepped_at)
		LAZYSET(track.step_clock, "[frame]", track.stepped_at)
	frames += list(frame, look, x, y, z, facing)

/**
 * The turf `thing` is drawn on: its loc, or, for an effect shown in the vis_contents of what it was made in (tg's muzzle
 * flash, made inside the shooter), the turf that holder stands on. Null when it isn't drawn on the map.
 */
/datum/sandy_replay/proc/shown_on(atom/movable/thing)
	var/atom/here = thing.loc
	if(isturf(here))
		return here
	if(sandy_bearer_picture(thing)) // in nothing: only in the vis_contents of the body it plays on
		var/obj/effect/abstract/cyberware_anim/picture = thing
		var/atom/movable/worn_by = picture.bearer
		return (worn_by && isturf(worn_by.loc) && (thing in worn_by.vis_contents)) ? worn_by.loc : null
	if(!istype(thing, /obj/effect/temp_visual) || !ismovable(here) || !isturf(here.loc))
		return null
	var/atom/movable/holder = here
	return (thing in holder.vis_contents) ? holder.loc : null

/**
 * `look` (a picture a chrome weapon plays on a body) as a stand-in on the floor can draw it. On the body it takes the
 * body's plane and sorts among the body's overlays by a float layer, and the far arm's is cut around what the near hand
 * holds by a mask of that item: a stand-in has none of those, so it goes on the body's plane just over mobs, uncut.
 */
/datum/sandy_replay/proc/picture_look(obj/effect/abstract/cyberware_anim/picture, look)
	var/mutable_appearance/copy = new(look)
	var/atom/movable/worn_by = picture.bearer
	if(worn_by) // on the body it is drawn wherever the body is drawn: held in a grab, lying off its tile
		copy.pixel_x += worn_by.pixel_x
		copy.pixel_y += worn_by.pixel_y
		copy.pixel_w += worn_by.pixel_w
		copy.pixel_z += worn_by.pixel_z
	copy.plane = worn_by ? worn_by.plane : GAME_PLANE
	copy.layer = ABOVE_MOB_LAYER
	copy.filters = null
	return copy.appearance

/// `thing`'s appearance without the slow-mo's own look: the field's tint and the user's edge glow.
/datum/sandy_replay/proc/clean_look(atom/movable/thing)
	// In a shared slow-mo another member's field may tint it, and every member wears the edge glow (ware_sandy_timestop_shared.dm).
	var/tinted = field?.tinted[thing] || sandy_session_tints(src, thing)
	var/outlined = (thing == user || sandy_session_member(src, thing)) && thing.filter_data?[SANDY_REPLAY_OUTLINE]
	if(!tinted && !outlined)
		return thing.appearance
	var/mutable_appearance/copy = new(thing)
	// Bodies and items wear the tint as a filter (cyberware_time_tints_by_filter()), the rest in `color`.
	var/filtered = tinted && cyberware_time_tints_by_filter(thing)
	if(tinted && !filtered)
		if(istype(thing, /obj/effect/decal/cleanable/blood)) // blood's colour is its own, worked out as it dries
			var/obj/effect/decal/cleanable/blood/blood = thing
			copy.color = blood.sandy_replay_colour()
			if(istype(blood, /obj/effect/decal/cleanable/blood/gibs)) // its meat overlay carries the tint too
				var/obj/effect/decal/cleanable/blood/gibs/gibs = blood
				gibs.sandy_untinted_overlays(copy)
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

/**
 * `look` (`body`'s) with its arm blades drawn in its hands while they swing out of their housings. The swing is a picture
 * in the body's vis_contents, which no look carries, and the held blade isn't drawn under it
 * (/obj/item/melee/energy/blade/hardlight/cyberware_mantis/build_worn_icon()): recorded as it is, the replay would open on
 * bare arms for the frames the swing plays. The swing ends on the held blade, so that is what is drawn.
 */
/datum/sandy_replay/proc/unfolded_look(mob/living/carbon/body, look)
	var/unfolding = FALSE
	for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/housing in body.organs)
		var/obj/effect/abstract/cyberware_anim/swing = housing.blade_anim()
		if(swing && swing.icon_state == housing.blade_anim_state("unfold"))
			unfolding = TRUE
			break
	if(!unfolding)
		return look
	var/hidden = FALSE
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade in body.held_items)
		if(world.time < blade.inhand_hidden_until)
			hidden = TRUE
			break
	var/list/hands = body.overlays_standing[HANDS_LAYER]
	if(hands && !islist(hands))
		hands = list(hands)
	if(!hidden || !length(hands))
		return look
	var/mutable_appearance/copy = new(look)
	for(var/mutable_appearance/held as anything in hands)
		if(held.alpha)
			continue
		copy.overlays -= held
		var/mutable_appearance/shown = new(held)
		shown.alpha = 255
		copy.overlays += shown
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

/// How many frames a decisecond the recording's clock ran at `frame`.
/datum/sandy_replay/proc/rate_at(frame)
	. = clock_rate
	for(var/list/stretch as anything in clock_rates)
		if(stretch[1] > frame)
			break
		. = stretch[2]

/// `track`'s thing is on a surge: the replay gives it its surge's trail.
/datum/sandy_replay/proc/become_surger(datum/sandy_replay_track/track)
	track.surger = TRUE
	track.surge_from = frame_now()
	read_trail(track)
	if(state == SANDY_REPLAY_RECORDING && track.thing)
		RegisterSignal(track.thing, COMSIG_MOVABLE_MOVED, PROC_REF(on_surger_stepped))

/// Signal proc for [COMSIG_MOVABLE_MOVED] on a surger while it is recorded: the tile it stepped onto is kept, so the
/// replay's trail follows the way it really went between two frames.
/datum/sandy_replay/proc/on_surger_stepped(atom/movable/source, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	var/datum/sandy_replay_track/track = tracks[source]
	if(!track || state != SANDY_REPLAY_RECORDING)
		return
	track.stepped_at = frame_exact()
	if(isliving(source))
		var/mob/living/walker = source
		track.stride = walker.cached_multiplicative_slowdown
	if(length(track.path) >= SANDY_REPLAY_PATH_MAX * 2)
		return
	var/turf/here = source.loc
	LAZYADD(track.path, isturf(here) ? here.x : 0)
	track.path += isturf(here) ? here.y : 0

/// The recording is over: the surgers' steps aren't followed any more (their puppets take the signal from here, mask()).
/datum/sandy_replay/proc/stop_paths()
	for(var/atom/movable/thing as anything in tracks)
		var/datum/sandy_replay_track/track = tracks[thing]
		if(track.surger)
			UnregisterSignal(thing, COMSIG_MOVABLE_MOVED)

/// `body`'s own surge is over while the recording goes on (a shared slow-mo's member out of time): no trail from here.
/datum/sandy_replay/proc/surge_over(mob/living/body)
	var/datum/sandy_replay_track/track = tracks[body]
	if(track?.surger && track.surge_until == INFINITY && state == SANDY_REPLAY_RECORDING)
		track.surge_until = frame_now()

/// Takes the trail's cadence and strength from the surger's window. The user's own window isn't listed on them yet
/// while it opens the slow-mo, so this is tried again on later samples.
/datum/sandy_replay/proc/read_trail(datum/sandy_replay_track/track)
	if(!isliving(track.thing))
		return
	var/mob/living/body = track.thing
	var/datum/status_effect/cyberware_cascade_window/window = body.has_status_effect(/datum/status_effect/cyberware_cascade_window)
	if(window)
		track.trail_length = max(1, window.trail_length)
		track.trail_per_tile = max(1, window.trail_per_tile)
		track.trail_alpha = window.afterimage_alpha
		track.trail_read = TRUE

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
/datum/sandy_replay/proc/hear(turf/source, list/arguments, mob/actor)
	if(state != SANDY_REPLAY_RECORDING || (!field && !wait_started) || length(sounds) >= SANDY_REPLAY_MAX_OWN_SOUNDS)
		return
	// Waiting out a move after the slow-mo: the sounds around the user, as the hold's reach.
	var/turf/centre = get_turf(field ? field.host : user)
	if(!centre || centre.z != source.z || get_dist(centre, source) > (field ? field.current_range : SANDY_REPLAY_HOLD_RANGE))
		if(!sandy_session_hears(src, source)) // or in a crewmate's field of a shared slow-mo (ware_sandy_timestop_shared.dm)
			return
	if(length(sounds) >= SANDY_REPLAY_MAX_SOUNDS && !own_sound(source, actor))
		return
	var/now = frame_exact()
	// The same sound on the same tile in the same frame (a burst's echoes, a crowd's steps) is kept once.
	for(var/index in length(sounds) to 1 step -1)
		var/list/kept = sounds[index]
		if(floor(kept[1]) != floor(now))
			break
		if(kept[2] == source && kept[3] == arguments[1])
			return
	sounds += list(list(now, source) + arguments)

/// Whether a sound set off by `actor` on `source` is the user's or a crewmate's own: kept past the cap on the world's.
/datum/sandy_replay/proc/own_sound(turf/source, mob/actor)
	if(actor && (actor == user || (actor in sandy_session_others(src, FALSE))))
		return TRUE
	var/turf/here = get_turf(user)
	return here && here.z == source.z && get_dist(here, source) <= 1

/// Signal proc for [COMSIG_QDELETING] on anything recorded.
/datum/sandy_replay/proc/on_thing_deleted(atom/movable/thing)
	SIGNAL_HANDLER
	if(thing == user)
		qdel(src)
		return
	var/datum/sandy_replay_track/track = tracks[thing]
	tracks -= thing
	pending_hidden -= thing
	held_shots -= thing
	unborn -= thing
	rig_hidden -= thing
	if(!track)
		return
	if(GLOB.sandy_replay_masked[thing] == track)
		GLOB.sandy_replay_masked -= thing
		sandy_replay_masks = length(GLOB.sandy_replay_masked)
	var/ended = (track.flier || istype(thing, /obj/effect/projectile)) ? shot_gone(track) : 0
	track.thing = null
	if(state == SANDY_REPLAY_RECORDING || state == SANDY_REPLAY_PENDING)
		// Drawn up to the frame the recording next sampled without it: a rig picture goes in the frame its body's
		// own look comes back, not one before (the body would be gone for a frame).
		track.last = max(last_sampled + 1, track.first + ((track.oneshot && !track.flier) ? SANDY_REPLAY_ONESHOT_FRAMES : 1), ended)
		gone += track
		return
	puppets -= track
	if(track.flier && state == SANDY_REPLAY_PLAYING)
		shot_to_standin(track)

/// A player cut the slow-mo short: nothing replays.
/datum/sandy_replay/proc/cancel()
	if(state == SANDY_REPLAY_RECORDING)
		qdel(src)

/// The field is over (it ran out, or the user ended it): playback starts next tick, once the slow-mo's own looks
/// are off everything.
/datum/sandy_replay/proc/field_over()
	if(state != SANDY_REPLAY_RECORDING || wait_started)
		return
	field = null
	if(!length(moves_running()))
		end_wait(TRUE)
		return
	// An execution or finisher in the field is still going. The replay's hold would cut it short (its checks fail on a
	// held body), so the world goes on at normal speed and the recording with it, a frame a tick, until it's done.
	wait_started = world.time

/**
 * The recording is over: playback starts next tick, once the slow-mo's own looks are off everything. Without
 * [replays] (a move still going when the wait ran out) nothing replays.
 */
/datum/sandy_replay/proc/end_wait(replays)
	if(state != SANDY_REPLAY_RECORDING)
		return
	total = max(frame_now(), 1)
	waited = wait_started ? world.time - wait_started : 0
	stop_paths()
	ended_at = world.time
	state = SANDY_REPLAY_PENDING
	if(replays)
		hide_progress_bars()
		hide_pending()
		hold_shots()
		hold_gore()
	deltimer(sample_timer)
	sample_timer = null
	if(!replays)
		finish()
		return
	if(watched())
		// The cut into the replay is one frame: the slow-mo's last frame, then the replay's first, in this same tick,
		// so no frame of the world as it really is now (the dead where they fell, the gore at its landing spots) goes
		// out between them. What ends the slow-mo after this (the outline coming off, the release flash) lands on the
		// real looks under the puppets. With nobody looking on nobody sees the cut: the replay starts next tick.
		begin()
		return
	begin_timer = addtimer(CALLBACK(src, PROC_REF(begin)), world.tick_lag, TIMER_STOPPABLE | TIMER_DELETE_ME)

/// Whether anyone sees the replay start: its user, a crewmate of a shared slow-mo (ware_sandy_timestop_shared.dm), or
/// any other client looking on from near one of them (a ghost, a crewmate whose own time is out).
/datum/sandy_replay/proc/watched()
	if(user?.client || sandy_session_watched(src))
		return TRUE
	var/list/here = centres()
	if(!length(here))
		return FALSE
	for(var/client/viewer as anything in GLOB.clients)
		var/turf/eye_at = get_turf(viewer?.eye)
		if(!eye_at)
			continue
		for(var/turf/centre as anything in here)
			if(eye_at.z == centre.z && get_dist(eye_at, centre) <= SANDY_REPLAY_REACH)
				return TRUE
	return FALSE

/// The bodies in the recording in the middle of an execution or finisher, either side of it.
/datum/sandy_replay/proc/moves_running()
	. = list()
	for(var/atom/movable/thing as anything in tracks)
		if(isliving(thing) && sandy_replay_mid_move(thing))
			. += thing

// =========================================================================
// THE ANIMATION JOURNAL
// =========================================================================
// A finisher rig poses its pictures with animate() chains. The server only holds where each chain ends, so a sample
// can't see the poses on the way. The rig and finisher files send their animate() calls through
// sandy_replay_animate() (a file-local macro, SANDY_REPLAY_JOURNAL_ON in those files), which plays them as usual and,
// while a replay records their target, journals them to play again on its stand-in.

/// An animate() call on `target` (null: a further step of the last one) with these named arguments.
/datum/sandy_replay/proc/journal(target, list/step, atom/movable/started_on)
	if(state != SANDY_REPLAY_RECORDING)
		return
	if(isnull(target))
		if(open_event)
			var/list/steps = open_event[4]
			steps += list(step)
		return
	open_event = null
	var/datum/sandy_replay_track/track = ismovable(target) ? tracks[target] : null
	if(!track && (sandy_rig_picture(target) || istype(target, /obj/effect/temp_visual)) && near_centre(target))
		notice(target) // made this tick (a shot's muzzle flash, a drop of blood): its first pose is this call
		track = tracks[target]
	// Gore a move puts on the floor and then moves itself: a burst head's gib, the Gorilla's thrown arm and the blood
	// drops that show as it lands (gorilla_finisher.dm)
	var/thrown_gib = istype(target, /obj/effect/decal/cleanable/blood) || istype(target, /obj/item/bodypart) || istype(target, /obj/item/organ)
	if(!track || !(sandy_rig_picture(target) || isliving(target) || track.oneshot || thrown_gib))
		return
	if(thrown_gib)
		// A burst head's gib (flying_gore.dm): tg has already stepped it off the head's tile, and its arc starts back at
		// the head from there. Its first frame is taken again where it is now, so the arc is drawn from the head to its
		// landing in the replay too, not as a gib lying on the floor from the blow on. The thrown arm starts where the
		// hauled one was, and a drop that shows later starts unseen, the same way.
		var/list/frames = track.frames
		if(length(frames) && frames[length(frames) - SANDY_FRAME_SIZE + SANDY_FRAME_INDEX] >= frame_now())
			track.last_raw = null
			sample_track(track, frames[length(frames) - SANDY_FRAME_SIZE + SANDY_FRAME_INDEX])
	// The look it had before this call: what it was drawn as when the chain began, direct writes included.
	open_event = list(frame_due(), started_on ? clean_look(started_on) : null, world.tick_lag * clock_rate, list(step))
	LAZYADD(track.events, list(open_event))
	journaled++
	event_log += "journal [track.thing.type] f[open_event[1]] tag=[step["tag"]] t=[step["time"]] pw=[step["pixel_w"]]"

/// Plays `track`'s journaled animations due by `frame` on its stand-in, or on its puppet (a body's lean or flinch:
/// shifted to where the puppet is drawn).
/datum/sandy_replay/proc/play_events(datum/sandy_replay_track/track, frame)
	var/atom/movable/standin = track.mode == SANDY_TRACK_STANDIN ? track.standin : track.thing
	var/shift_x = 0
	var/shift_y = 0
	if(track.mode == SANDY_TRACK_PUPPET && standin && track.cursor >= 0 && isturf(standin.loc))
		var/turf/here = standin.loc
		shift_x = (track.frames[track.cursor + SANDY_FRAME_X] - here.x) * ICON_SIZE_X
		shift_y = (track.frames[track.cursor + SANDY_FRAME_Y] - here.y) * ICON_SIZE_Y
	while(track.event_at <= length(track.events))
		var/list/event = track.events[track.event_at]
		if(event[1] >= frame + 1)
			return
		// Still gliding to the tile it starts on: it starts when the glide is done. A glide on the spot is the frame's own
		// shift, the pose this chain moves it to (the lift of a body put on the blades): it doesn't hold the chain.
		if(track.mode == SANDY_TRACK_PUPPET && track.glide_step && track.glide_until > world.time + max(event[1] - frame, 0) * world.tick_lag && standin?.loc && !track.unmasked)
			return
		track.event_at++
		if(!standin?.loc || (track.mode == SANDY_TRACK_PUPPET && (track.unmasked || (standin.alpha == 0 && !track.oneshot)))) // a one-shot's alpha is its own animation's
			event_log += "skip [track.thing?.type] f[event[1]] at [frame] a=[standin?.alpha] u=[track.unmasked]"
			continue
		events_played++
		var/list/steps = event[4]
		var/list/first = steps[1]
		var/parallel = first["flags"] & ANIMATION_PARALLEL
		var/relative = first["flags"] & ANIMATION_RELATIVE
		var/look = event[2]
		if(track.mode == SANDY_TRACK_STANDIN && look && look != track.drawn_look && !parallel)
			animate(standin, time = 0, flags = ANIMATION_END_NOW)
			standin.appearance = look
			standin.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
			track.drawn_look = look
		var/scale = event[3]
		var/length = 0
		var/list/chain = list()
		for(var/i in 1 to length(steps))
			var/list/arguments = list()
			if(i == 1)
				arguments += standin
			var/list/step = steps[i]
			for(var/name in step)
				var/value = step[name]
				if(name == "time" || name == "delay")
					value *= scale
				else if(!relative && name == "pixel_w")
					value += shift_x
				else if(!relative && name == "pixel_z")
					value += shift_y
				arguments[name] = value
			if(i == 1 && event[1] > frame) // when in this tick it started
				arguments["delay"] = (arguments["delay"] || 0) + (event[1] - frame) * world.tick_lag
			chain += list(arguments)
		var/loops = first["loop"]
		// Started late (it waited out a glide): it plays from where it would have got to by now, so it ends on time.
		var/late = (frame - event[1]) * world.tick_lag
		if(late > 0 && !relative && (!loops || loops == 1))
			chain = trim_chain(chain, late, standin)
		if(track.mode == SANDY_TRACK_PUPPET && !relative)
			keep_flip(chain, standin.transform)
		if(track.oneshot && (!loops || loops == 1))
			stretch_oneshot(chain)
		for(var/list/arguments as anything in chain)
			length += (arguments["time"] || 0) + (arguments["delay"] || 0)
			animate(arglist(arguments))
		if(loops && loops < 0)
			length = INFINITY
		else if(loops > 1)
			length *= loops
		track.anim_until = parallel ? max(track.anim_until, world.time + length) : world.time + length
		event_log += "play [track.thing?.type] f[event[1]] at [frame] len=[length] steps=[length(chain)] pw=[chain[1]["pixel_w"]] t=[chain[1]["time"]] tag=[chain[1]["tag"]] shift=[shift_x],[shift_y]"
		if(track.mode == SANDY_TRACK_PUPPET)
			track.expect = standin.appearance // the chain's end values are ours, not game code's: nothing to fold
			if(!parallel && !relative)
				track.chain = chain
				track.chain_start = world.time
				track.chain_shift = list(shift_x, shift_y)

/**
 * `chain` (animate() argument lists, changed in place) is a one-shot effect's animation, compressed: one shorter than
 * SANDY_REPLAY_ONESHOT_MIN is stretched to it, or it would be over before a frame is drawn. One that only fades out (a
 * muzzle flash) is shown whole for a frame first and fades in the next.
 */
/datum/sandy_replay/proc/stretch_oneshot(list/chain)
	var/span = 0
	for(var/list/arguments as anything in chain)
		span += arguments["time"] || 0
	if(span <= 0 || span >= SANDY_REPLAY_ONESHOT_MIN)
		return
	var/list/first = chain[1]
	var/fades = length(chain) == 1 && first["alpha"] == 0
	var/factor = (fades ? world.tick_lag : SANDY_REPLAY_ONESHOT_MIN) / span
	for(var/i in 1 to length(chain))
		var/list/arguments = chain[i]
		if(arguments["time"])
			arguments["time"] *= factor
		if(i > 1 && arguments["delay"])
			arguments["delay"] *= factor
	if(!fades)
		return
	// Held whole for a frame by a step that changes nothing, then faded. Not by a `delay` on the fade: through a delay the
	// client draws where the chain ends (faded out), so an execution's flash showed a frame after its head burst.
	var/atom/movable/target = first[1]
	if(!ismovable(target))
		return
	var/list/hold = list(target)
	hold["alpha"] = target.alpha
	hold["time"] = world.tick_lag
	for(var/name in list("tag", "flags", "delay", "loop"))
		if(!isnull(first[name]))
			hold[name] = first[name]
			first -= name
	first.Cut(1, 2)
	chain.Insert(1, list(hold))

/// `chain` (animate() argument lists, the first naming `thing`) with its first `late` deciseconds already gone by: the
/// steps that were over are dropped, the one under way is shortened. A chain wholly over jumps to its last step's pose.
/datum/sandy_replay/proc/trim_chain(list/chain, late, atom/movable/thing)
	var/list/rest = list()
	var/at = 0
	for(var/list/step as anything in chain)
		var/delay = step["delay"] || 0
		var/span = (step["time"] || 0) + delay
		if(!length(rest) && at + span <= late)
			at += span
			continue
		var/list/arguments = step.Copy()
		if(!length(rest))
			if(arguments[1] != thing)
				arguments.Insert(1, thing)
			for(var/name in list("tag", "flags"))
				if(isnull(arguments[name]) && !isnull(chain[1][name]))
					arguments[name] = chain[1][name]
			var/into = late - at
			if(into < delay)
				arguments["delay"] = delay - into
			else
				arguments -= "delay"
				arguments["time"] = max((arguments["time"] || 0) - (into - delay), 0)
		else if(arguments[1] == thing)
			arguments.Cut(1, 2)
		rest += list(arguments)
		at += span
	if(length(rest))
		return rest
	var/list/last = chain[length(chain)].Copy()
	if(last[1] != thing)
		last.Insert(1, thing)
	for(var/name in list("tag", "flags"))
		if(isnull(last[name]) && !isnull(chain[1][name]))
			last[name] = chain[1][name]
	last -= "delay"
	last["time"] = 0
	return list(last)

/**
 * A pose chain (a lift, a lean) holds the body's turn as it was when the chain started. A rig that flips a lying body
 * the other way in that same tick leaves the chain on the old turn and the recorded frame on the new one, and a tween
 * between the two halves passes through a matrix of no size: the body vanishes for it. Such a turn in `chain` (animate()
 * argument lists, changed in place) is set to `now`, the turn the recorded frame shows.
 */
/datum/sandy_replay/proc/keep_flip(list/chain, matrix/now)
	if(!istype(now))
		return
	var/size = abs(now.a * now.e - now.b * now.d)
	// A chain that ends on the frame's own turn is drawing that turn (a body hauled round end for end, step by step:
	// mantis_turn_head_toward()), not holding an old one: it plays as it was recorded.
	var/matrix/last_turn
	for(var/list/arguments as anything in chain)
		if(istype(arguments["transform"], /matrix))
			last_turn = arguments["transform"]
	if(last_turn)
		var/matrix/ending = matrix(now).Interpolate(last_turn, 0.5)
		if(abs(ending.a * ending.e - ending.b * ending.d) >= size * 0.9)
			return
	for(var/list/arguments as anything in chain)
		var/matrix/target = arguments["transform"]
		if(!istype(target))
			continue
		var/matrix/halfway = matrix(now).Interpolate(target, 0.5)
		if(abs(halfway.a * halfway.e - halfway.b * halfway.d) < size * 0.25)
			arguments["transform"] = matrix(now)
			event_log += "keep_flip [now.a],[now.b],[now.d],[now.e] over [target.a],[target.b],[target.d],[target.e]"

/**
 * A puppet was given a new frame's look while a journaled chain was playing on it, which ends the chain: plays the
 * rest of it again from where it had got to. `shift_x`, `shift_y`: the pixel shift the puppet is drawn with now.
 */
/datum/sandy_replay/proc/resume_chain(datum/sandy_replay_track/track, shift_x, shift_y)
	var/list/chain = track.chain
	if(!length(chain) || track.anim_until <= world.time || !track.chain_shift)
		return
	var/atom/movable/thing = track.thing
	var/list/first = chain[1]
	var/cycle = 0
	for(var/list/step as anything in chain)
		cycle += (step["time"] || 0) + (step["delay"] || 0)
	if(cycle <= 0)
		return
	var/elapsed = world.time - track.chain_start
	var/loops = first["loop"] || 1
	var/done_loops = round(elapsed / cycle)
	if(loops > 0 && done_loops >= loops)
		return
	elapsed -= done_loops * cycle
	var/move_x = shift_x - track.chain_shift[1]
	var/move_y = shift_y - track.chain_shift[2]
	var/list/rest = list()
	var/at = 0
	for(var/list/step as anything in chain)
		var/span = (step["time"] || 0) + (step["delay"] || 0)
		if(at + span <= elapsed && !length(rest))
			at += span
			continue
		var/list/arguments = step.Copy()
		if(!length(rest))
			if(arguments[1] != thing)
				arguments.Insert(1, thing)
			var/into = elapsed - at
			var/delay = arguments["delay"] || 0
			if(into < delay)
				arguments["delay"] = delay - into
			else
				arguments -= "delay"
				arguments["time"] = max((arguments["time"] || 0) - (into - delay), 0)
			arguments["loop"] = loops > 0 ? loops - done_loops : loops
			arguments["flags"] = (arguments["flags"] || 0) | ANIMATION_END_NOW
		else if(arguments[1] == thing)
			arguments.Cut(1, 2)
		if(!isnull(arguments["pixel_w"]))
			arguments["pixel_w"] += move_x
		if(!isnull(arguments["pixel_z"]))
			arguments["pixel_z"] += move_y
		rest += list(arguments)
		at += span
	keep_flip(rest, thing.transform)
	for(var/list/arguments as anything in rest)
		animate(arglist(arguments))
	track.expect = thing.appearance
	chains_resumed++

// =========================================================================
// SHOTS
// =========================================================================
// A shot's own loop moves it a few pixels a tick and keeps its spot in the tile in pixel_x and pixel_y, so a frame's
// sample (its turf and look) is where it was, to the pixel. On top of that a shot needs: the spot it stopped at when it
// hits (it is deleted between two samples), a straight line from frame to frame, and the shots still flying when the
// recording ends held where they are for the replay, so the one real shot is never drawn twice or jumping ahead.

/// Whether `thing` (a shot) has been fired: turned the way it flies and on its way.
/datum/sandy_replay/proc/shot_fired(atom/movable/thing)
	var/obj/projectile/shot = thing
	return shot.fired

/// Signal proc for [COMSIG_PROJECTILE_FIRE] on a shot seen before it was fired: its first frame, in the frame it was
/// seen in, now that it is turned the way it flies.
/datum/sandy_replay/proc/on_shot_fired(obj/projectile/shot)
	SIGNAL_HANDLER
	UnregisterSignal(shot, COMSIG_PROJECTILE_FIRE)
	var/datum/sandy_replay_track/track = tracks[shot]
	if(!track || state != SANDY_REPLAY_RECORDING)
		return
	track.last_raw = null
	var/frame = max(track.first, frame_now())
	sample_track(track, frame)
	shot_from(shot.firer, frame)

/// `shooter` fired a shot first drawn in `frame`, on the tile it stands on for real (shooting_at()).
/datum/sandy_replay/proc/shot_from(atom/movable/shooter, frame)
	var/datum/sandy_replay_track/track = shooter && tracks[shooter]
	var/turf/spot = track && get_turf(shooter)
	if(spot)
		LAZYADD(track.shot_frames, list(list(frame, spot.x, spot.y)))

/// The first frame from `from` on that `track`'s thing has a shot of its own drawn in on tile `x`, `y`, or 0. A shot
/// fired from the tile it stepped off in the same frame isn't one: it is drawn there, where the step starts.
/datum/sandy_replay/proc/shooting_at(datum/sandy_replay_track/track, from, x, y)
	var/next = 0
	for(var/list/shot as anything in track.shot_frames)
		if(shot[1] >= from && shot[2] == x && shot[3] == y && (!next || shot[1] < next))
			next = shot[1]
	return next

/// The first frame from `from` on that a finisher's posed pictures are drawn on tile `x`, `y`, or 0. One frame before
/// counts too: a picture made as he lands is drawn from the frame it was made in, and his step is sampled in the next.
/datum/sandy_replay/proc/posed_at(from, x, y)
	var/next = 0
	for(var/list/posed as anything in rig_frames)
		if(posed[1] >= from - 1 && posed[2] == x && posed[3] == y && (!next || posed[1] < next))
			next = posed[1]
	return next

/// Whether one more shot in the air can be recorded. Logs it, once a recording, when one can't.
/datum/sandy_replay/proc/shot_room()
	if(shots_live < SANDY_REPLAY_MAX_SHOTS)
		shots_live++
		return TRUE
	if(!shots_capped)
		log_game("Sandevistan replay of [key_name(user)]: more than [SANDY_REPLAY_MAX_SHOTS] shots in the air at once, the rest are not replayed.")
	shots_capped++
	return FALSE

/// `look` (`shot`'s) as it is on screen. A shot that has hit fades out on the client as it reaches the spot
/// (process_movement()), and its vars already hold the end of that: it is drawn reaching the spot.
/datum/sandy_replay/proc/shot_look(obj/projectile/shot, look)
	if(!shot.deletion_queued || shot.alpha == initial(shot.alpha))
		return look
	var/mutable_appearance/copy = new(look)
	copy.alpha = initial(shot.alpha)
	return copy.appearance

/// `track`'s shot, or a beam's tracer, muzzle or impact effect, is being deleted: the spot and look it ends with are
/// recorded. Returns the first frame it is gone in (0 when it isn't being recorded).
/datum/sandy_replay/proc/shot_gone(datum/sandy_replay_track/track)
	if(state != SANDY_REPLAY_RECORDING)
		return 0
	var/list/frames = track.frames
	var/at = length(frames) ? frames[length(frames) - SANDY_FRAME_SIZE + SANDY_FRAME_INDEX] : track.first
	var/end
	if(track.flier)
		shots_live--
		if(!shot_fired(track.thing))
			return 0 // spent before it flew (a shot at point blank lands inside fire()): never drawn, as it never is live
		end = max(last_sampled + 1, at + 1) // its last frame is where it was a frame ago; this one is where it stopped
	else
		end = max(round(frame_due()), at) // an effect made and gone between two samples: one frame, with its finished look
	track.last_raw = null
	sample_track(track, end)
	return end + 1

/// A shot flies in a straight line from the spot it was drawn at to this frame's, over the `frames` frames between them
/// (one, unless the replay's timer skipped one: it can come every other tick), as it did between the samples.
/datum/sandy_replay/proc/fly(datum/sandy_replay_track/track, move_x, move_y, frames)
	if((!move_x && !move_y) || abs(move_x) > SANDY_REPLAY_REACH * ICON_SIZE_X || abs(move_y) > SANDY_REPLAY_REACH * ICON_SIZE_Y)
		return TRUE
	track.glide_x = move_x
	track.glide_y = move_y
	track.glide_time = clamp(frames, 1, 4) * world.tick_lag
	track.glide_until = world.time + track.glide_time
	return TRUE

/**
 * The recording is over: the shots still flying stop where they are until the replay is over, as everyone near the
 * user holds still for it. The replay draws them flying up to that spot and they fly on from it after, so a shot is
 * never drawn twice (the replay's and the real one) or jumping on by however far it got while the replay played.
 */
/datum/sandy_replay/proc/hold_shots()
	for(var/atom/movable/thing as anything in tracks)
		var/datum/sandy_replay_track/track = tracks[thing]
		if(!track.flier)
			continue
		var/obj/projectile/shot = thing
		if(shot.paused || shot.deletion_queued || !shot.fired)
			continue
		shot.paused = TRUE
		held_shots += shot

/// The replay is over: the shots it held fly on.
/datum/sandy_replay/proc/release_shots()
	for(var/obj/projectile/shot as anything in held_shots)
		if(!QDELETED(shot))
			shot.paused = FALSE
	held_shots.Cut()
	release_gore()

/**
 * Gore still flying when the recording ends (a gib sliding off on tg's streak, a torn-off part or organ on its
 * tumble) holds where it is until the replay is over, as the shots do. Left to fly on, it lands while the replay plays
 * and pops to its landing spot, with the blood it left on the way, the moment the replay hands back. A body or a thing
 * knocked flying in the recording's last moments (tg's throw) holds in the air the same way: left to fly on under the
 * replay, a corpse or a dropped gun is drawn where the recording last saw it and jumps to where it landed at the cut.
 */
/datum/sandy_replay/proc/hold_gore()
	for(var/atom/movable/thing as anything in tracks)
		if(QDELETED(thing) || track_is_shot(thing))
			continue
		var/datum/thrownthing/flight = thing.throwing
		if(flight && !flight.paused)
			flight.paused = TRUE
			held_gore[flight] = list(world.time, flight.delayed_time)
		if(isliving(thing))
			continue
		var/datum/move_loop/loop = thing.move_packet?.running_loop
		if(loop && (loop.status & MOVELOOP_STATUS_RUNNING) && !(loop.status & MOVELOOP_STATUS_PAUSED))
			loop.pause_loop()
			held_gore += loop
		var/datum/component/hv_tumble/tumble = thing.GetComponent(/datum/component/hv_tumble)
		if(tumble?.step_timer)
			held_gore[tumble] = max(timeleft(tumble.step_timer), world.tick_lag)
			deltimer(tumble.step_timer)
			tumble.step_timer = null

/**
 * The recording has run out. A kill in its last moments leaves its gore in the air: the replay would stop on the burst's
 * first frames, and the real gore, held since the slow-mo ended, would jump to wherever it had got to and then finish
 * its flight in the present, the same burst a second time. So the replay stays on its last frame while the gore lands:
 * its own animations of it play out (a gib's arc) while the held gore is handed back and flies on for real under the
 * replay, and only then does the replay hand everything back, with the gore at rest. Never longer than
 * SANDY_REPLAY_LANDING_MAX. Returns whether it is still landing.
 */
/datum/sandy_replay/proc/land()
	if(!landing_stage)
		var/list/painting = paints_left()
		if(!length(held_gore) && !gore_playing() && !oneshots_playing() && !length(painting))
			return FALSE
		landing_stage = 2
		landing_started = world.time
		deltimer(watchdog)
		watchdog = addtimer(CALLBACK(src, PROC_REF(finish)), SANDY_REPLAY_LANDING_MAX + SANDY_REPLAY_WATCHDOG, TIMER_STOPPABLE | TIMER_DELETE_ME)
		for(var/datum/held as anything in held_gore)
			var/atom/movable/thing
			if(istype(held, /datum/move_loop))
				var/datum/move_loop/loop = held
				thing = loop.moving
			else if(istype(held, /datum/component))
				var/datum/component/tumble = held
				thing = tumble.parent
				// The time it had left to its next step was counted in the slow-mo, many times too long for now
				held_gore[held] = world.tick_lag
			else if(istype(held, /datum/thrownthing))
				var/datum/thrownthing/flight = held
				thing = flight.thrownthing
			if(QDELETED(thing))
				continue
			landing |= thing // waited for whether this recording draws it or not
			var/datum/sandy_replay_track/track = tracks[thing]
			if(!track || track.landing || !(track in puppets))
				continue
			unmask(track)
			track.landing = TRUE
			thing.sandy_replay_resume(world.time - ended_at)
		release_gore()
		// A spray laid in the slow-mo's last moments was still painting in, slowed, when the recording ended, and the
		// last frame has it half there. Its real paint ran on under the replay: handed back at the end as it is, it
		// jumped to full at the cut. It carries on here from where the last frame has it, and the replay waits for it.
		for(var/datum/sandy_replay_track/track as anything in painting)
			paint_until = max(paint_until, painting[track])
			unmask(track)
			track.landing = TRUE
			track.thing.sandy_replay_resume(world.time - ended_at)
		// The surger's own last shot, held in the air at his gun, would hang there too: it flies on. Anyone else's
		// stays held until everyone can move again.
		for(var/obj/projectile/shot as anything in held_shots)
			if(QDELETED(shot) || !(shot.firer == user || sandy_session_member(src, shot.firer)))
				continue
			var/datum/sandy_replay_track/shot_track = tracks[shot]
			if(shot_track && !shot_track.landing && (shot_track in puppets))
				unmask(shot_track)
				shot_track.landing = TRUE
			shot.paused = FALSE
			held_shots -= shot
		// A flash still lit when the recording ended (the slow-mo stretched it) would hang there for as long as this
		// takes: it goes out
		for(var/datum/sandy_replay_track/track as anything in puppets + standins)
			if(!track.oneshot || track.landing || track.anim_until > world.time || track.last <= total + 1)
				continue
			var/atom/movable/drawn = track.mode == SANDY_TRACK_STANDIN ? track.standin : track.thing
			if(QDELETED(drawn))
				continue
			track.landing = TRUE
			animate(drawn, alpha = 0, time = 0.1 SECONDS)
	if(world.time - landing_started >= SANDY_REPLAY_LANDING_MAX)
		return FALSE
	for(var/atom/movable/thing as anything in landing)
		if(QDELETED(thing))
			landing -= thing
			continue
		var/datum/move_loop/loop = thing.move_packet?.running_loop
		var/datum/component/hv_tumble/tumble = thing.GetComponent(/datum/component/hv_tumble)
		if(!(loop && (loop.status & MOVELOOP_STATUS_RUNNING)) && !tumble?.step_timer && !thing.throwing)
			landing -= thing
			landing_settle = world.time + 0.15 SECONDS
	return length(landing) > 0 || world.time < landing_settle || world.time < paint_until || (world.time - landing_started < SANDY_REPLAY_LANDING_TWEENS && (gore_playing() || oneshots_playing()))

/// The sprays the replay draws that were still painting in when the recording ended (hv_vis_paint(), slowed like the
/// rest): each track with the world.time its paint is done by once it carries on from where the last frame has it.
/// Not a smear running down a wall or a pool creeping wider: those take seconds, and nobody waits for them.
/datum/sandy_replay/proc/paints_left()
	. = list()
	if(!ended_at)
		return
	var/held_for = world.time - ended_at
	for(var/datum/sandy_replay_track/track as anything in puppets)
		var/obj/effect/decal/cleanable/blood/hv_spray/spray = track.thing
		if(track.landing || track.unmasked || QDELETED(spray) || !istype(spray) || istype(spray, /obj/effect/decal/cleanable/blood/hv_spray/wall))
			continue
		var/left = spray.sandy_replay_paint_carry(held_for, FALSE)
		if(left > 0)
			.[track] = world.time + left

/// Whether the replay is still playing its own animation of gore thrown in the recording's last moments (a gib's arc
/// from a head that burst as the slow-mo ended).
/datum/sandy_replay/proc/gore_playing()
	for(var/datum/sandy_replay_track/track as anything in puppets)
		if(track.anim_until <= world.time || !length(track.events))
			continue
		var/atom/movable/thing = track.thing
		// Not a pool: one creeps wider for seconds, and nobody waits for that
		if(QDELETED(thing) || !(istype(thing, /obj/effect/decal/cleanable/blood/gibs) || istype(thing, /obj/item/bodypart) || istype(thing, /obj/item/organ)))
			continue
		var/list/last_event = track.events[length(track.events)]
		if(last_event[1] >= total - SANDY_REPLAY_LANDING_FRAMES)
			return TRUE
	return FALSE

/// Whether a one-shot effect is still playing out in the replay (the splash of a hit in the recording's last moments).
/datum/sandy_replay/proc/oneshots_playing()
	for(var/datum/sandy_replay_track/track as anything in standins)
		if(track.oneshot && track.standin && track.anim_until > world.time)
			return TRUE
	return FALSE

/// Whether `thing` is a shot (held by hold_shots()).
/datum/sandy_replay/proc/track_is_shot(atom/movable/thing)
	var/datum/sandy_replay_track/track = tracks[thing]
	return track?.flier

/// The replay is over: the gore hold_gore() held flies on from where it was.
/datum/sandy_replay/proc/release_gore()
	for(var/datum/held as anything in held_gore)
		if(QDELETED(held))
			continue
		if(istype(held, /datum/move_loop))
			var/datum/move_loop/loop = held
			loop.resume_loop()
		else if(istype(held, /datum/component/hv_tumble))
			var/datum/component/hv_tumble/tumble = held
			if(!tumble.step_timer)
				tumble.step_timer = addtimer(CALLBACK(tumble, TYPE_PROC_REF(/datum/component/hv_tumble, take_step)), held_gore[held], TIMER_STOPPABLE|TIMER_DELETE_ME)
		else if(istype(held, /datum/thrownthing))
			// It flies on from where it hung: its clock starts again as if the hold never was
			var/datum/thrownthing/flight = held
			var/list/hung = held_gore[held]
			flight.start_time += world.time - hung[1]
			flight.delayed_time = hung[2]
			flight.paused = FALSE
	held_gore.Cut()

/// A shot drawn on itself was deleted mid-replay (it hit something in the recording's last tick): a stand-in flies
/// the rest of its path.
/datum/sandy_replay/proc/shot_to_standin(datum/sandy_replay_track/track)
	track.mode = SANDY_TRACK_STANDIN
	track.last = total + 1
	standins += track
	show(track)

// =========================================================================
// PLAYBACK
// =========================================================================

/// No progress bar shows during a replay (owner, 2026-11-12): tg's do_after bars (client images on the body's own
/// screen) of the user and every body the replay holds, and the execution bars (finisher_bar.dm, objects on the
/// executioner's tile, seen by all) within the replay's reach. Bars made while it plays are hidden as they are made
/// (sandy_replay_hides_bars_at()). Whatever is still running at the end is shown again.
/datum/sandy_replay/proc/hide_progress_bars()
	hide_body_bars(user)
	for(var/obj/effect/abstract/hv_exec_bar/bar as anything in GLOB.hv_exec_bars)
		if(bar.invisibility < INVISIBILITY_ABSTRACT && bar_reach(get_turf(bar)))
			bar.invisibility = INVISIBILITY_ABSTRACT
			hidden_bars += bar

/// Hides `body`'s own do_after bars from its client.
/datum/sandy_replay/proc/hide_body_bars(mob/living/body)
	for(var/target in body?.progressbars)
		for(var/datum/progressbar/progress as anything in body.progressbars[target])
			if(progress.user_client && (progress.bar in progress.user_client.images))
				progress.user_client.images -= progress.bar
				hidden_bars += progress

/// Playback, every frame: what turned up near the user after the recording ended (a gib or blood still landing
/// from the last blow, anything made since) isn't in the past being shown: it is hidden, by a filter (looks only),
/// until the replay ends.
/datum/sandy_replay/proc/hide_unborn()
	for(var/turf/here as anything in centres())
		for(var/atom/movable/thing in range(SANDY_REPLAY_HOLD_RANGE, here))
			if(tracks[thing] || unborn[thing] || rig_hidden[thing] || thing == user || !recordable(thing))
				continue
			if(sandy_rig_picture(thing))
				hide_rig_picture(thing)
				continue
			unborn[thing] = TRUE
			thing.add_filter(SANDY_REPLAY_UNBORN, 1, color_matrix_filter(list(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0)))

/**
 * Hides a live rig picture (a pose a finisher left on a body, held past the slow-mo) for the replay, which draws it on
 * a stand-in. Not by a filter: the backbreaker's broken back carried a hiding filter all through its replay and was still
 * drawn, the live pose on the floor while the replayed body was lifted (its pictures had a colour filter animated on them
 * by the hit flash). Invisible, it isn't sent to anyone; shown again as the replay ends, it is drawn as it is by then.
 */
/datum/sandy_replay/proc/hide_rig_picture(atom/movable/thing)
	if(!isnull(rig_hidden[thing]))
		return
	rig_hidden[thing] = thing.invisibility
	thing.invisibility = INVISIBILITY_ABSTRACT

/// Where the replay is watched from: the user, and in a shared slow-mo every other member (ware_sandy_timestop_shared.dm).
/datum/sandy_replay/proc/centres()
	. = list()
	var/turf/here = get_turf(user)
	if(here)
		. += here
	for(var/mob/living/member as anything in sandy_session_others(src, FALSE))
		var/turf/there = get_turf(member)
		if(there)
			. |= there

/// Whether `target` is within `reach` (SANDY_REPLAY_HOLD_RANGE unless given) of the user or another member of its
/// shared slow-mo.
/datum/sandy_replay/proc/near_centre(atom/target, reach = SANDY_REPLAY_HOLD_RANGE)
	var/turf/spot = get_turf(target)
	if(!spot)
		return FALSE
	for(var/turf/here as anything in centres())
		if(spot.z == here.z && get_dist(spot, here) <= reach)
			return TRUE
	return FALSE

/**
 * The slow-mo is over and the replay starts next tick. For that tick the world would show as it really is, in its own
 * colours: the last blow's gore at its landing spots, the dead where they fell, a moment before the replay jumps back.
 * What the recording saw change or turn up is hidden for it (the user stays, so the view has someone in it).
 */
/datum/sandy_replay/proc/hide_pending()
	for(var/atom/movable/thing as anything in tracks)
		var/datum/sandy_replay_track/track = tracks[thing]
		if(thing == user || QDELETED(thing) || (length(track.frames) == SANDY_FRAME_SIZE && track.first == 0))
			continue
		pending_hidden += thing
		thing.add_filter(SANDY_REPLAY_PENDING_HIDE, 1, color_matrix_filter(list(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0)))

/// The replay is starting (or isn't coming): what hide_pending() hid is drawn again, before the replay takes its looks.
/datum/sandy_replay/proc/show_pending()
	for(var/atom/movable/thing as anything in pending_hidden)
		if(!QDELETED(thing))
			thing.remove_filter(SANDY_REPLAY_PENDING_HIDE)
	pending_hidden.Cut()

/// Whether `spot` is close enough to the user for the replay to hide a bar on it.
/datum/sandy_replay/proc/bar_reach(turf/spot)
	return spot && near_centre(spot)

/// Shows again the bars the replay hid that still exist.
/datum/sandy_replay/proc/show_progress_bars()
	for(var/datum/thing as anything in hidden_bars)
		if(QDELETED(thing))
			continue
		if(istype(thing, /obj/effect/abstract/hv_exec_bar))
			var/obj/effect/abstract/hv_exec_bar/bar = thing
			bar.invisibility = initial(bar.invisibility)
		else if(istype(thing, /datum/progressbar))
			var/datum/progressbar/progress = thing
			if(progress.user_client && progress.bar)
				progress.user_client.images |= progress.bar
	hidden_bars.Cut()

/// Starts the replay: the last sample is everything's real final state, then everything goes back to frame 0.
/datum/sandy_replay/proc/begin()
	begin_timer = null
	if(state != SANDY_REPLAY_PENDING)
		return
	if(QDELETED(user) || cyberware_time_stop_witnessed(user))
		finish()
		return
	state = SANDY_REPLAY_PLAYING
	show_pending()
	hide_progress_bars()
	watchdog = addtimer(CALLBACK(src, PROC_REF(finish)), (total + 2) * world.tick_lag + SANDY_REPLAY_WATCHDOG, TIMER_STOPPABLE | TIMER_DELETE_ME)
	try
		setup_playback()
	catch(var/exception/error)
		finish()
		stack_trace("Sandevistan replay failed to start: [error] ([error.file]:[error.line])")
		return
	if(finished)
		return
	// The cut to the replay is the change of scene: the slow-mo's pale release flash would only wash out its first frames.
	// It is already fading on its own (out of user.screens), so it is taken off the client's screen directly.
	for(var/mob/living/viewer as anything in list(user) + sandy_session_others(src)) // every member of a shared slow-mo
		viewer.clear_fullscreen(SANDY_REPLAY_RELEASE_FLASH, FALSE)
		for(var/atom/movable/screen/fullscreen/flash/sandy_release/flash in viewer.client?.screen)
			viewer.client.screen -= flash
	play_started = world.time
	// The surge sound below goes to the replay's viewers from where each watches, not from their real bodies.
	GLOB.sandy_replay_routing = src
	GLOB.sandy_replay_routing_time = world.time
	sandy_member_views() // each member of a shared slow-mo watches its own replayed self (ware_sandy_timestop_shared.dm)
	// The surge coming on, as anyone near heard the replay's user at its first frame (ware_sandy_sound.dm).
	var/turf/first = user_track ? locate(user_track.frames[SANDY_FRAME_X], user_track.frames[SANDY_FRAME_Y], user_track.frames[SANDY_FRAME_Z]) : null
	play_to_viewers(first || get_turf(user), SANDEVISTAN_EXTERNAL_SOUND, 100, TRUE, 0, SOUND_FALLOFF_EXPONENT, rand(100 - SANDEVISTAN_EXTERNAL_SPREAD, 100 + SANDEVISTAN_EXTERNAL_SPREAD) / 100, TRUE, TRUE, SOUND_DEFAULT_FALLOFF_DISTANCE, TRUE)
	play_timer = addtimer(CALLBACK(src, PROC_REF(play_frame)), world.tick_lag, TIMER_LOOP | TIMER_STOPPABLE | TIMER_DELETE_ME)
	play_frame()
	GLOB.sandy_replay_routing = null

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
		if(sandy_rig_picture(thing))
			// A rig picture still showing (fading out as the move hands the body back, or holding the body in a pose
			// past the slow-mo): drawn on a stand-in, and the real one is hidden for the replay (hide_rig_picture()).
			// finish() shows it again as it really is by then.
			hide_rig_picture(thing)
			track.mode = SANDY_TRACK_STANDIN
			standins += track
		else if(isturf(thing.loc))
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
	// What is left of the trail the surge itself drew stands where the slow-mo ended: the replay draws its own
	for(var/turf/here as anything in centres())
		for(var/obj/effect/temp_visual/decoy/fading/cascade/left_over in range(SANDY_REPLAY_HOLD_RANGE, here))
			if(!istype(left_over, /obj/effect/temp_visual/decoy/fading/cascade/replay))
				qdel(left_over)
		// A surge's ring still spreading is the slow-mo's own look too
		for(var/obj/effect/temp_visual/cyberware_time_ring/ring in range(SANDY_REPLAY_HOLD_RANGE, here))
			qdel(ring)
	hold_nearby()
	RegisterSignal(user, COMSIG_MOVABLE_Z_CHANGED, PROC_REF(on_user_z_changed))
	if(user.client && user.stat != DEAD && isturf(user.loc) && user_track?.mode == SANDY_TRACK_PUPPET)
		eye = new(user.loc)
		eye_pixel_x = user.client.pixel_x
		eye_pixel_y = user.client.pixel_y
		user.reset_perspective(eye)
		clear_view()

/// Fullscreens that follow the user's real health (update_damage_hud()): crit, crit vision, oxygen and the brute and
/// burn vignette. With the blindness of being knocked out (only when nothing else blinds them) they'd paint the
/// user's present state over a replay of the moments before it.
#define SANDY_REPLAY_CRIT_SCREENS list("crit", "critvision", "oxy", "brute")

/**
 * A user who went down in the slow-mo watches their replay like anyone else: their health and knocked-out screens
 * come off their client's view (not off the mob, so tg keeps updating them) and go back in finish(). Called at the
 * start and every frame, as Life() can put one back. In a shared slow-mo every other member with a client too.
 */
/datum/sandy_replay/proc/clear_view()
	if(eye && sandy_replay_clear_view_of(user))
		view_cleared = TRUE
	for(var/mob/living/member as anything in sandy_session_others(src))
		if(sandy_replay_clear_view_of(member))
			members_cleared[member] = TRUE

/// Takes `body`'s health and knocked-out screens off its client's view. TRUE if any came off.
/proc/sandy_replay_clear_view_of(mob/living/body)
	var/client/viewer = body?.client
	if(!viewer)
		return FALSE
	for(var/category in SANDY_REPLAY_CRIT_SCREENS)
		var/atom/movable/screen/fullscreen/screen = body.screens[category]
		if(screen && (screen in viewer.screen))
			viewer.screen -= screen
			. = TRUE
	var/datum/status_effect/grouped/blindness/blind = body.has_status_effect(/datum/status_effect/grouped/blindness)
	if(!blind || length(blind.sources) != 1 || !(UNCONSCIOUS_TRAIT in blind.sources))
		return
	var/atom/movable/screen/fullscreen/dark = body.screens[blind.id]
	if(dark && (dark in viewer.screen))
		viewer.screen -= dark
		. = TRUE
	if(body.remove_client_colour(REF(blind)))
		. = TRUE

/// Puts back what clear_view() took off, as each viewer's real state now has it.
/datum/sandy_replay/proc/restore_view()
	for(var/mob/living/member as anything in members_cleared)
		sandy_replay_restore_view_of(member)
	members_cleared.Cut()
	if(!view_cleared)
		return
	view_cleared = FALSE
	sandy_replay_restore_view_of(user)

/proc/sandy_replay_restore_view_of(mob/living/body)
	if(QDELETED(body))
		return
	// Worked out again from the body's state now (Life() ran on through the replay), then shown.
	body.update_damage_hud()
	var/datum/status_effect/grouped/blindness/blind = body.has_status_effect(/datum/status_effect/grouped/blindness)
	blind?.update_blindness()
	body.reload_fullscreen()

#undef SANDY_REPLAY_CRIT_SCREENS

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
	sandy_hold_members() // and around every member of a shared slow-mo (ware_sandy_timestop_shared.dm)
	hold_machines()

/// Stops the clocks of the turrets and lit grenades the slow-mo slows (cyberware_push_machine_deadlines()) near the
/// user and every member: a turret doesn't track or fire (see tryToShootAt() below) and a fuse doesn't burn while the
/// replay holds everyone. A turret someone is steering by hand is theirs and is left alone.
/datum/sandy_replay/proc/hold_machines()
	for(var/turf/here as anything in centres())
		for(var/obj/thing in range(SANDY_REPLAY_HOLD_RANGE, here))
			if(held_machines[thing] || QDELETED(thing))
				continue
			if(istype(thing, /obj/machinery/porta_turret))
				var/obj/machinery/porta_turret/turret = thing
				if(turret.manual_control)
					continue
			else if(!cyberware_lit_grenade(thing))
				continue
			held_machines[thing] = TRUE
			sandy_replay_clock_stop(thing)

/// A turret a replay holds doesn't pick a target. Every automatic turret's scan ends here (cyberware_stealth.dm);
/// manual control goes through target() and isn't touched.
/obj/machinery/porta_turret/tryToShootAt(list/atom/movable/targets)
	if(GLOB.sandy_replay_stopped_clocks[src])
		return FALSE
	return ..()

/// Switches `mech` off for the replay.
/datum/sandy_replay/proc/hold_mech(obj/vehicle/sealed/mecha/mech)
	if(!isnull(mechs[mech]) || QDELETED(mech))
		return
	mechs[mech] = mech.completely_disabled
	mech.completely_disabled = TRUE
	sandy_replay_clock_stop(mech)

/// Things whose clocks a replay's hold has stopped, to list(world.time they were last pushed to, holds on it now).
GLOBAL_LIST_EMPTY(sandy_replay_stopped_clocks)

/**
 * The replay's hold is a pause for an NPC or a machine: every clock the slow-mo slows (cyberware_push_deadlines(),
 * cyberware_push_machine_deadlines()) is pushed back every frame of the hold by the time that passed, so it picks up
 * where it was when the hold ends instead of finding every cooldown run out at once. Two replays holding the same thing
 * at once push it once. Players' clocks are left alone.
 */
/proc/sandy_replay_clock_stop(atom/movable/thing)
	if(ismob(thing))
		var/mob/body = thing
		if(body.ckey)
			return
	var/list/stop = GLOB.sandy_replay_stopped_clocks[thing]
	if(stop)
		stop[2] += 1
	else
		GLOB.sandy_replay_stopped_clocks[thing] = list(world.time, 1)

/// Pushes `thing`'s stopped clocks back by the time since they were last pushed.
/proc/sandy_replay_clock_catch_up(atom/movable/thing)
	var/list/stop = GLOB.sandy_replay_stopped_clocks[thing]
	if(!stop)
		return
	var/since = stop[1]
	var/held = world.time - since
	if(held <= 0)
		return
	stop[1] = world.time
	if(QDELETED(thing))
		return
	if(isliving(thing))
		cyberware_push_deadlines(thing, held, since)
	else
		cyberware_push_machine_deadlines(thing, held, since)

/// Every replay frame: everything held stays where its clocks were.
/proc/sandy_replay_clocks_tick()
	for(var/atom/movable/thing as anything in GLOB.sandy_replay_stopped_clocks)
		sandy_replay_clock_catch_up(thing)

/// A replay let `thing` go: its clocks catch up, and run again once no other replay holds it.
/proc/sandy_replay_clock_start(atom/movable/thing)
	var/list/stop = GLOB.sandy_replay_stopped_clocks[thing]
	if(!stop)
		return
	sandy_replay_clock_catch_up(thing)
	stop[2] -= 1
	if(stop[2] <= 0)
		GLOB.sandy_replay_stopped_clocks -= thing

/// Pauses `body`'s AI and locks its player's input. No stun: decisions and input only.
/datum/sandy_replay/proc/lock(mob/living/body)
	if(locked[body] || QDELETED(body))
		return
	locked[body] = TRUE
	sandy_replay_clock_stop(body)
	hide_body_bars(body)
	if(body.ckey && body.stat != DEAD)
		body.add_traits(list(TRAIT_IMMOBILIZED, TRAIT_INCAPACITATED), SANDY_REPLAY_TRAIT)
	if(body.ai_controller)
		// Taken before the pause: lifting it makes tg work the status out afresh (update_able_to_run())
		ai_before[body] = list(body.ai_controller.ai_status, body.ai_controller.get_expected_ai_status())
		ADD_TRAIT(body, TRAIT_AI_PAUSED, SANDY_REPLAY_TRAIT)
	if(isanimal(body))
		var/mob/living/simple_animal/animal = body
		locked[body] = animal.AIStatus
		animal.toggle_ai(AI_OFF)

/datum/sandy_replay/proc/unlock(mob/living/body)
	var/was = locked[body]
	sandy_replay_clock_start(body) // its clocks pick up where they were
	if(QDELETED(body))
		return
	body.remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_INCAPACITATED, TRAIT_AI_PAUSED), SANDY_REPLAY_TRAIT)
	// The hold is a pause: an AI goes on as it was. Lifting the pause has tg set the status it expects, which undoes a
	// status something set on purpose (a captive's AI switched off, one switched on by hand). With nothing else changed
	// since the hold began (tg expects what it expected then), the AI gets back the status it was taken with.
	var/list/before = ai_before[body]
	var/datum/ai_controller/brain = body.ai_controller
	if(before && brain?.able_to_run && before[1] != before[2] && brain.ai_status != before[1] && brain.get_expected_ai_status() == before[2])
		brain.set_ai_status(before[1])
	// A knockdown or crit that ended mid-replay tried to stand them up then (get_up()'s do_after), and the lock's
	// TRAIT_INCAPACITATED failed it: nothing would try again, so they'd lie there. tg's own end-of-floored step.
	if(body.stat != DEAD && body.body_position == LYING_DOWN && !HAS_TRAIT(body, TRAIT_FLOORED))
		body.on_floored_end()
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

/**
 * The replay is over: `track`'s thing gets its real look back. With `turns`, a body that really got up or went down
 * while the replay played (a knockdown running out under the hold) turns from the way it was last drawn to the way it
 * really lies, as tg turns a body, instead of snapping upright at the cut.
 */
/datum/sandy_replay/proc/hand_back(datum/sandy_replay_track/track, turns)
	var/atom/movable/thing = track.thing
	var/matrix/drawn = (turns && isliving(thing) && track.cursor >= 0 && thing.alpha) ? matrix(thing.transform) : null
	wear_real(track)
	if(!drawn || (drawn ~= thing.transform))
		return
	var/matrix/real = matrix(thing.transform)
	var/matrix/halfway = drawn.Interpolate(real, 0.5)
	if(abs(halfway.a * halfway.e - halfway.b * halfway.d) < 0.25) // a half turn blends through nothing: it flips at once
		return
	thing.transform = drawn
	animate(thing, transform = real, time = SANDY_REPLAY_TURN_TIME, easing = SINE_EASING)

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
		var/list/still = glide_at(track, left)
		carry_x = still[1]
		carry_y = still[2]
	track.glide_until = 0
	track.glide_way = null
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
		// On the replay's clock, as everything else: compressed ten times a fall is a fifth of a frame. A rig's own
		// snap (a body brought upright onto the blades) is then upright the frame it was, not turning through the move.
		track.turn_time = SANDY_REPLAY_TURN_TIME * world.tick_lag * rate_at(frames[at + SANDY_FRAME_INDEX])
		track.turn_until = world.time + track.turn_time
		// A half turn (a body flipped from lying one way to the other, as a rig move leaves it) blends through a
		// matrix of no size halfway: the body would vanish for the tween. It flips at once instead.
		var/matrix/halfway = start.Interpolate(track.turn_to, 0.5)
		if(abs(halfway.a * halfway.e - halfway.b * halfway.d) < 0.25)
			track.turn_until = 0
	// Tween from where it was drawn to where it is now.
	var/stepped = frames[old + SANDY_FRAME_X] != frames[at + SANDY_FRAME_X] || frames[old + SANDY_FRAME_Y] != frames[at + SANDY_FRAME_Y]
	var/move_x = (frames[old + SANDY_FRAME_X] - frames[at + SANDY_FRAME_X]) * ICON_SIZE_X + (was.pixel_x + was.pixel_w) - (now.pixel_x + now.pixel_w) + carry_x
	var/move_y = (frames[old + SANDY_FRAME_Y] - frames[at + SANDY_FRAME_Y]) * ICON_SIZE_Y + (was.pixel_y + was.pixel_z) - (now.pixel_y + now.pixel_z) + carry_y
	if(track.flier)
		return fly(track, move_x, move_y, frames[at + SANDY_FRAME_INDEX] - frames[old + SANDY_FRAME_INDEX])
	var/glide_max = track.surger ? SANDY_REPLAY_SURGE_GLIDE_MAX : SANDY_REPLAY_GLIDE_MAX
	if((!move_x && !move_y) || abs(move_x) > glide_max || abs(move_y) > glide_max)
		return TRUE
	var/time = world.tick_lag
	if(stepped)
		// A step glides until the next one, like a walk does.
		// The last step of a walk glides two ticks, or less if the thing's next frame (a move starting on that tile)
		// comes sooner: it is on its tile by then.
		var/ticks = at + SANDY_FRAME_SIZE < end ? min(2, frames[at + SANDY_FRAME_SIZE + SANDY_FRAME_INDEX] - frames[at + SANDY_FRAME_INDEX]) : 2
		for(var/next = at + SANDY_FRAME_SIZE, next < end, next += SANDY_FRAME_SIZE)
			if(frames[next + SANDY_FRAME_X] != frames[at + SANDY_FRAME_X] || frames[next + SANDY_FRAME_Y] != frames[at + SANDY_FRAME_Y] || frames[next + SANDY_FRAME_Z] != frames[at + SANDY_FRAME_Z])
				ticks = frames[next + SANDY_FRAME_INDEX] - frames[at + SANDY_FRAME_INDEX]
				break
		time = clamp(ticks, 1, 5) * world.tick_lag
		// A move's first pose due sooner (an execution started as the step landed): the glide is done by then.
		if(track.events && track.event_at <= length(track.events))
			var/list/next_event = track.events[track.event_at]
			var/due = (next_event[1] - frame) * world.tick_lag
			if(due >= 0 && due < time)
				time = max(due, world.tick_lag / 2)
		// It shoots sooner (it stepped and stopped to fire): it is on the tile by the frame its muzzle flash and bullet are
		// drawn on it, or they are drawn ahead of the gun while it is still gliding there.
		var/shot_frame = shooting_at(track, frames[at + SANDY_FRAME_INDEX], frames[at + SANDY_FRAME_X], frames[at + SANDY_FRAME_Y])
		if(shot_frame)
			time = min(time, max((shot_frame - frame) * world.tick_lag, 0))
		// A surger who starts a finisher as he lands (a dash straight into an execution): the move's pictures, his blades
		// and the slashes are drawn on that tile from their first frame, and he was still gliding in under them.
		if(track.surger)
			var/posed_frame = posed_at(frames[at + SANDY_FRAME_INDEX], frames[at + SANDY_FRAME_X], frames[at + SANDY_FRAME_Y])
			if(posed_frame)
				time = min(time, max((posed_frame - frame) * world.tick_lag, world.tick_lag / 2))
	else if(left > 0)
		time = left
	track.glide_x = move_x
	track.glide_y = move_y
	track.glide_step = stepped || (left > 0 && track.glide_step) // what is left of a step glides on with this one
	track.glide_time = time
	track.glide_until = world.time + time
	if(track.surger && stepped)
		track.glide_way = glide_corners(track, old, at, move_x, move_y)
	return TRUE

/**
 * The way a surger glides from frame `old` to frame `at` when it turned a corner between them (kept_way()): flat x, y
 * pixel offsets from where it ends, from `move_x`, `move_y` (where it starts) through each tile it stepped on to 0, 0.
 * Null for a straight run, which glides as everything else does. Gliding straight across a corner, the puppet was
 * never on the tiles its trail is laid on.
 */
/datum/sandy_replay/proc/glide_corners(datum/sandy_replay_track/track, old, at, move_x, move_y)
	var/list/frames = track.frames
	var/turf/left = locate(frames[old + SANDY_FRAME_X], frames[old + SANDY_FRAME_Y], frames[old + SANDY_FRAME_Z])
	var/turf/reached = locate(frames[at + SANDY_FRAME_X], frames[at + SANDY_FRAME_Y], frames[at + SANDY_FRAME_Z])
	if(!left || !reached)
		return null
	var/list/way = kept_way(track, left, reached)
	if(!way || way_is_straight(way, left, reached))
		return null
	. = list(move_x, move_y)
	for(var/i in 2 to length(way) - 1)
		var/turf/corner = way[i]
		. += (corner.x - reached.x) * ICON_SIZE_X
		. += (corner.y - reached.y) * ICON_SIZE_Y
	. += 0
	. += 0

/// Whether `way` (tiles from `left` to `reached`) is the straight line between them.
/datum/sandy_replay/proc/way_is_straight(list/way, turf/left, turf/reached)
	var/list/straight = get_line(left, reached)
	if(length(way) != length(straight))
		return FALSE
	for(var/i in 1 to length(way))
		if(way[i] != straight[i])
			return FALSE
	return TRUE

/// Where a track's tween is with `left` of its time to go: list(x, y) pixels from where it ends.
/datum/sandy_replay/proc/glide_at(datum/sandy_replay_track/track, left)
	var/list/way = track.glide_way
	if(!way)
		return list(track.glide_x * left / track.glide_time, track.glide_y * left / track.glide_time)
	var/legs = length(way) / 2 - 1
	var/along = clamp(1 - left / track.glide_time, 0, 1) * legs
	var/leg = min(round(along), legs - 1) // the leg it is on, from 0
	var/part = along - leg
	return list(way[leg * 2 + 1] + (way[leg * 2 + 3] - way[leg * 2 + 1]) * part, way[leg * 2 + 2] + (way[leg * 2 + 4] - way[leg * 2 + 2]) * part)

/**
 * The legs a track's tween has still to cover with `left` of its time to go, for an animate() chain: a list of
 * list(x, y, time), each the pixels from where it ends that a leg stops at and how long the leg takes. One leg for a
 * straight tween.
 */
/datum/sandy_replay/proc/glide_legs(datum/sandy_replay_track/track, left)
	var/list/way = track.glide_way
	if(!way)
		return list(list(0, 0, left))
	. = list()
	var/legs = length(way) / 2 - 1
	var/leg_time = track.glide_time / legs
	var/along = clamp(1 - left / track.glide_time, 0, 1) * legs
	var/leg = min(round(along), legs - 1)
	for(var/i in leg to legs - 1)
		. += list(list(way[i * 2 + 3], way[i * 2 + 4], i == leg ? (1 - (along - leg)) * leg_time : leg_time))

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
		if(track.anim_until > world.time)
			return // a journaled animation is playing on it: it ends where this frame's look is
		standin.appearance = frames[at + SANDY_FRAME_LOOK]
		track.drawn_look = frames[at + SANDY_FRAME_LOOK]
		standin.dir = frames[at + SANDY_FRAME_DIR]
		standin.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		standin.opacity = FALSE
		standin.luminosity = 0
		settle(track, standin, 0, 0)
		if(track.plays_out)
			track.anim_until = world.time + track.plays_out
			track.plays_out = 0
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
		// Game code writing its alpha or colour straight on (blood a later spray lands on) would show it until the next
		// frame's fold(): a filter that draws nothing keeps it hidden through that. Its next look replaces the filters.
		thing.filters += filter(type = "color", color = list(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0))
		thing.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		track.expect = thing.appearance
		return
	thing.appearance = frames[at + SANDY_FRAME_LOOK]
	thing.dir = frames[at + SANDY_FRAME_DIR]
	pin(track)
	thing.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	settle(track, thing, off_x * ICON_SIZE_X, off_y * ICON_SIZE_Y)
	track.expect = thing.appearance
	resume_chain(track, off_x * ICON_SIZE_X, off_y * ICON_SIZE_Y)

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
		var/list/still = glide_at(track, left)
		body.pixel_w = to_w + still[1]
		body.pixel_z = to_z + still[2]
		var/first = TRUE
		for(var/list/leg as anything in glide_legs(track, left))
			if(first)
				animate(body, pixel_w = to_w + leg[1], pixel_z = to_z + leg[2], time = leg[3], flags = ANIMATION_END_NOW)
				first = FALSE
			else
				animate(pixel_w = to_w + leg[1], pixel_z = to_z + leg[2], time = leg[3])
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
		var/list/still = glide_at(user_track, left)
		viewer.pixel_x = eye_pixel_x + still[1]
		viewer.pixel_y = eye_pixel_y + still[2]
		var/first = TRUE
		for(var/list/leg as anything in glide_legs(user_track, left))
			if(first)
				animate(viewer, pixel_x = eye_pixel_x + leg[1], pixel_y = eye_pixel_y + leg[2], time = leg[3], flags = ANIMATION_END_NOW)
				first = FALSE
			else
				animate(pixel_x = eye_pixel_x + leg[1], pixel_y = eye_pixel_y + leg[2], time = leg[3])
	else
		animate(viewer, pixel_x = eye_pixel_x, pixel_y = eye_pixel_y, time = 0, flags = ANIMATION_END_NOW)

/**
 * A surger's puppet (the user's, or a surging NPC's) just moved on to a new frame. The place where the surge's
 * own look and sound join the replay: `track.came_from` and `track.cursor` are the frames it went from and to
 * (offsets in `track.frames`; came_from is below 0 on its first), so a step is the two frames standing on
 * different turfs. Each step leaves the surge's own afterimage on the tile it left, as a surge does
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
	if(frames[dest + SANDY_FRAME_INDEX] < track.surge_from || frames[dest + SANDY_FRAME_INDEX] > track.surge_until)
		return // a step taken before its surge came on, or after it ran out
	var/turf/left = locate(frames[from + SANDY_FRAME_X], frames[from + SANDY_FRAME_Y], frames[from + SANDY_FRAME_Z])
	var/turf/reached = locate(frames[dest + SANDY_FRAME_X], frames[dest + SANDY_FRAME_Y], frames[dest + SANDY_FRAME_Z])
	if(!left || !reached || get_dist(left, reached) > SANDY_REPLAY_SURGE_GLIDE_MAX / ICON_SIZE_X)
		return // a jump, not steps
	// Several steps can fall between two samples: each tile it crossed gets its afterimages, as each step would. The
	// way it really went where that was kept (a corner), a straight line where it wasn't.
	var/list/crossed = surger_way(track, left, reached) || get_line(left, reached)
	var/steps = length(crossed) - 1
	// The trail is laid as the live one is (cyberware_cascade_window/on_move()), on the replay's clock: a step takes as
	// many frames as it took in the recording, and an afterimage lives trail_length / trail_per_tile steps, so a walk at
	// any speed drags the trail's length behind it. It is gone a frame after the replay is.
	// The steps were taken between the last one replayed and the last one of this frame, where that was kept: counted
	// by the frame, a steady run's pace wobbles with how many of its steps each frame happens to hold, and a leg laid
	// in a fuller frame faded before an older one.
	var/span = frames[dest + SANDY_FRAME_INDEX] - frames[from + SANDY_FRAME_INDEX]
	var/stepped = LAZYACCESS(track.step_clock, "[frames[dest + SANDY_FRAME_INDEX]]")
	if(stepped && track.trail_stepped_at && stepped > track.trail_stepped_at)
		span = stepped - track.trail_stepped_at
	track.trail_stepped_at = stepped || frames[dest + SANDY_FRAME_INDEX]
	var/step_frames = span / steps
	var/step_max = CYBERWARE_CASCADE_TRAIL_STEP_MAX * rate_at(frames[dest + SANDY_FRAME_INDEX])
	if(step_frames > step_max) // the first step, or one after a pause: as long as a step takes him, as the live trail has it
		var/stride_frames = track.stride * rate_at(frames[dest + SANDY_FRAME_INDEX])
		step_frames = stride_frames > 0 ? min(stride_frames, step_max) : (track.trail_step_frames || step_max)
		// Within SANDEVISTAN_BURST_GAP of the surge itself, the opening cue just played (ware_sandy_sound.dm).
		if((stepped || frames[dest + SANDY_FRAME_INDEX]) - track.surge_from >= SANDEVISTAN_BURST_GAP * rate_at(frames[dest + SANDY_FRAME_INDEX]))
			sandy_burst_cue(track, left)
	track.trail_step_frames = step_frames
	var/per_tile = max(1, track.trail_per_tile)
	var/life_frames = step_frames * (max(1, track.trail_length) / per_tile + 1)
	var/frames_left = max(total + 2 - frames[dest + SANDY_FRAME_INDEX], 1)
	for(var/k in 1 to steps)
		var/turf/step_from = crossed[k]
		// As the live trail: one on the tile left, the rest back along the step before, never ahead of the puppet
		var/turf/before = k > 1 ? crossed[k - 1] : track.trail_prev
		if(before && (before.z != step_from.z || get_dist(before, step_from) != 1))
			before = null
		// Several tiles between two frames: the puppet is still gliding over them, and a copy laid before the tick after he
		// leaves its tile stands ahead of him. It waits to that tick, and starts at the age and life it has left by then.
		var/wait = track.glide_until > world.time ? (track.glide_until - world.time) * (k - 1) / steps : 0
		var/ticks = wait > 0 ? max(ROUND_UP(wait / world.tick_lag - 0.001), 1) : 0
		var/delay = ticks * world.tick_lag
		// Each copy faces the way he was going as he left its tile: only the last step's facing is in the frame
		var/facing = steps > 1 ? get_dir(step_from, crossed[k + 1]) : frames[dest + SANDY_FRAME_DIR]
		for(var/i in 0 to (before ? per_tile - 1 : 0))
			var/fraction = i / per_tile
			var/left_frames = life_frames - (steps - k + 1 + fraction) * step_frames - ticks // left when it is laid
			if(left_frames <= 0)
				continue
			var/life = clamp(left_frames + ticks, 1, frames_left) * world.tick_lag
			var/shift_x = before ? round((before.x - step_from.x) * fraction * ICON_SIZE_X) : 0
			var/shift_y = before ? round((before.y - step_from.y) * fraction * ICON_SIZE_Y) : 0
			var/age_time = left_frames * world.tick_lag
			if(delay)
				addtimer(CALLBACK(src, PROC_REF(lay_copy), step_from, frames[dest + SANDY_FRAME_LOOK], facing, 1 - left_frames / life_frames, track.trail_alpha * left_frames / life_frames, life > delay ? life - delay : world.tick_lag, shift_x, shift_y, age_time), delay, TIMER_DELETE_ME)
			else
				lay_copy(step_from, frames[dest + SANDY_FRAME_LOOK], facing, 1 - left_frames / life_frames, track.trail_alpha * left_frames / life_frames, life, shift_x, shift_y, age_time)
			afterimages++
	track.trail_prev = crossed[steps]

/// One afterimage of a surger's replayed trail on `spot` (surger_frame()). Every copy is laid the one way: one that
/// waited inside its own animation for the puppet to pass came out translucent and fading where the rest stay solid
/// and change colour, and a trail's newer leg read as fading before its older one.
/datum/sandy_replay/proc/lay_copy(turf/spot, look, facing, age, start_alpha, life, shift_x, shift_y, age_time)
	if(finished || QDELETED(spot))
		return
	trail_copies += new /obj/effect/temp_visual/decoy/fading/cascade/replay(spot, look, facing, age, start_alpha, life, shift_x, shift_y, age_time)

/// The tiles a surger crossed from `left` to `reached` (both included) as it stepped them in the recording, or null
/// when they weren't kept or don't join the two up a step at a time (it was moved by something other than walking).
/datum/sandy_replay/proc/kept_way(datum/sandy_replay_track/track, turf/left, turf/reached)
	var/list/kept = LAZYACCESS(track.ways, "[track.frames[track.cursor + SANDY_FRAME_INDEX]]")
	if(!kept)
		return null
	var/list/way = list(left)
	var/turf/last = left
	for(var/i in 1 to length(kept) step 2)
		var/turf/next = locate(kept[i], kept[i + 1], left.z)
		if(!next || get_dist(last, next) != 1)
			return null
		way += next
		last = next
	return last == reached ? way : null

/// kept_way() for the trail, counted (ways_followed).
/datum/sandy_replay/proc/surger_way(datum/sandy_replay_track/track, turf/left, turf/reached)
	. = kept_way(track, left, reached)
	if(.)
		ways_followed++

/// A surger's replayed self bursts off from `from` after a pause: its viewers hear the snap anyone near heard
/// (ware_sandy_sound.dm), at most every SANDEVISTAN_BURST_GAP as the replay plays (the outside view's time) and a few
/// times a replay.
/datum/sandy_replay/proc/sandy_burst_cue(datum/sandy_replay_track/track, turf/from)
	if(burst_cues >= SANDY_REPLAY_BURST_CUES_MAX || (track.burst_cue_at && world.time - track.burst_cue_at < SANDEVISTAN_BURST_GAP))
		return
	burst_cues++
	track.burst_cue_at = world.time
	var/frequency = rand(100 - SANDEVISTAN_EXTERNAL_SPREAD, 100 + SANDEVISTAN_EXTERNAL_SPREAD) / 100
	play_to_viewers(from, SANDEVISTAN_EXTERNAL_SOUND, SANDEVISTAN_EXTERNAL_VOLUME, TRUE, 0, SOUND_FALLOFF_EXPONENT, frequency, TRUE, TRUE, SOUND_DEFAULT_FALLOFF_DISTANCE, TRUE)

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
		var/key = "[heard[3]]"
		if(world.time - (sound_started[key] || -INFINITY) < SANDY_REPLAY_SOUND_GAP)
			continue // the same sound just started: one is heard
		sound_started[key] = world.time
		var/volume = heard[4] * SANDY_REPLAY_SOUND_VOLUME
		if(volume < SOUND_AUDIBLE_VOLUME_MIN)
			continue
		play_to_viewers(source, heard[3], volume, heard[5], heard[6], heard[7], heard[8], heard[9], heard[10], heard[11], heard[12], heard[13])

/**
 * Who hears the replay, to the turf each hears it from: the user from where their view is (the replayed self it
 * follows, not the real body standing where the fight ended), every other member of a shared slow-mo from its own
 * view, and everyone else the replay holds from where they stand (their view is their own). Nobody else hears it.
 */
/datum/sandy_replay/proc/sound_viewers()
	. = list()
	var/turf/user_view = get_turf(eye || user)
	if(eye && user_track && user_track.cursor < 0) // the view hasn't been taken to the first frame yet: it's going there
		user_view = locate(user_track.frames[SANDY_FRAME_X], user_track.frames[SANDY_FRAME_Y], user_track.frames[SANDY_FRAME_Z]) || user_view
	if(user_view)
		.[user] = user_view
	var/datum/sandy_session/session = sandy_session_of_replay(src)
	for(var/mob/living/member as anything in sandy_session_others(src, FALSE))
		var/datum/sandy_session_view/view = session?.views[member]
		var/turf/member_view = get_turf(view?.eye || member)
		if(member_view)
			.[member] = member_view
	for(var/mob/living/body as anything in locked)
		if(.[body] || QDELETED(body))
			continue
		var/turf/there = get_turf(body)
		if(there)
			.[body] = there

/// Plays a sound on `source` to each of sound_viewers(), placed and faded as from where that viewer is watching.
/// The arguments from `soundin` on are playsound()'s. Returns who it went to.
/datum/sandy_replay/proc/play_to_viewers(turf/source, soundin, vol, vary, extrarange, falloff_exponent, frequency, pressure_affected, ignore_walls, falloff_distance, use_reverb, volume_preference)
	. = list()
	if(vary && !frequency)
		frequency = get_rand_frequency() // the same pitch for everyone, as playsound() does
	var/list/viewers = sound_viewers()
	for(var/mob/listener as anything in viewers)
		var/sound/heard = sandy_replay_sound_for(listener, viewers[listener], source, soundin, vol, vary, extrarange, falloff_exponent, frequency, pressure_affected, ignore_walls, falloff_distance, use_reverb, volume_preference)
		if(!heard)
			continue
#ifdef UNIT_TESTS
		GLOB.sandy_replay_heard += list(list(listener, heard))
#endif
		if(listener.client && listener.can_hear())
			SEND_SOUND(listener, heard)
			. += listener

/**
 * The sound `listener` hears of `soundin` on `source` when listening from `hear_from`, or null if it doesn't reach
 * them: playsound()'s reach and playsound_local()'s fade, pan, air and room, measured from `hear_from` in place of the
 * body. Never slowed: the slow-mo is over.
 */
/proc/sandy_replay_sound_for(mob/listener, turf/hear_from, turf/source, soundin, vol, vary, extrarange, falloff_exponent = SOUND_FALLOFF_EXPONENT, frequency, pressure_affected = TRUE, ignore_walls = TRUE, falloff_distance = SOUND_DEFAULT_FALLOFF_DISTANCE, use_reverb = TRUE, volume_preference)
	if(!hear_from || !source || hear_from.z != source.z || vol < SOUND_AUDIBLE_VOLUME_MIN)
		return null
	var/max_distance = SOUND_RANGE + extrarange
	var/distance = get_dist(hear_from, source)
	if(distance > CALCULATE_MAX_SOUND_AUDIBLE_DISTANCE(vol, max_distance, falloff_distance, falloff_exponent))
		return null
	if(!ignore_walls && !(hear_from in view(distance, source)))
		return null
	var/sound/heard = sound(get_sfx(soundin))
	heard.wait = 0
	heard.channel = SSsounds.random_available_channel()
	heard.volume = vol
	if(vary)
		heard.frequency = frequency || get_rand_frequency()
	heard.volume -= CALCULATE_SOUND_VOLUME(vol, distance, max_distance, falloff_distance, falloff_exponent)
	if(pressure_affected)
		var/pressure_factor = 0
		var/datum/gas_mixture/hearer_env = hear_from.return_air_readonly()
		var/datum/gas_mixture/source_env = source.return_air_readonly()
		if(hearer_env && source_env)
			var/pressure = min(hearer_env.return_pressure(), source_env.return_pressure())
			pressure_factor = pressure < ONE_ATMOSPHERE ? max((pressure - SOUND_MINIMUM_PRESSURE) / (ONE_ATMOSPHERE - SOUND_MINIMUM_PRESSURE), 0) : 1
		if(distance <= 1)
			pressure_factor = max(pressure_factor, 0.15)
		heard.volume *= pressure_factor
	if(heard.volume < SOUND_AUDIBLE_VOLUME_MIN)
		return null
	heard.x = source.x - hear_from.x
	heard.z = source.y - hear_from.y
	heard.y = 0
	heard.falloff = max_distance || 1
	if(listener.sound_environment_override != SOUND_ENVIRONMENT_NONE)
		heard.environment = listener.sound_environment_override
	else
		var/area/room = get_area(hear_from)
		heard.environment = room.sound_environment
	if(!use_reverb || heard.environment == SOUND_ENVIRONMENT_NONE)
		heard.echo ||= new /list(18)
		heard.echo[3] = -10000
		heard.echo[4] = -10000
	if(ispath(volume_preference) && listener.client?.prefs)
		heard.volume *= listener.client.prefs.read_preference(volume_preference) / 100
		if(heard.volume < SOUND_AUDIBLE_VOLUME_MIN)
			return null
	return heard

/// One afterimage of a surger's trail in the replay: a recorded look, coloured by age like the live trail.
/obj/effect/temp_visual/decoy/fading/cascade/replay

/obj/effect/temp_visual/decoy/fading/cascade/replay/Initialize(mapload, look, facing, age = 0, start_alpha = CYBERWARE_CASCADE_AFTERIMAGE_ALPHA, life, shift_x = 0, shift_y = 0, age_time)
	if(life)
		duration = life // before the parent's timer and fade read it
	. = ..(mapload, null, age, start_alpha)
	// The whole look goes on in one assignment, then the fade starts on it. Set piece by piece under the parent's fade,
	// the client tweened the hue in from full colour: the first afterimage read as a copy of the user beside them.
	var/mutable_appearance/copy = new(look || src)
	copy.name = ""
	copy.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	copy.alpha = start_alpha
	copy.color = cyberware_cascade_tint_at(age)
	copy.pixel_w += shift_x // along the step, toward the tile reached
	copy.pixel_z += shift_y
	copy.appearance_flags |= KEEP_TOGETHER // a recorded look need not draw as one piece; the colour must reach all of it
	// Drawn on the floor, under everyone standing: a trail lies behind its surger, never over them (on the game plane a
	// copy a row nearer the camera would sort over the surger).
	SET_PLANE_EXPLICIT(copy, FLOOR_PLANE, src)
	copy.layer = CLEANABLE_FLOOR_OBJECT_LAYER
	animate(src)
	appearance = copy.appearance
	dir = facing
	opacity = FALSE
	animate(src, alpha = 0, time = duration)
	age_colours(age, age_time || duration)

/// The playback timer: one frame a tick.
/datum/sandy_replay/proc/play_frame()
	if(finished || state != SANDY_REPLAY_PLAYING)
		return
	try
		if(QDELETED(user) || cyberware_time_stop_witnessed(user))
			finish()
			return
		var/frame = round((world.time - play_started) / world.tick_lag)
		if(frame > total + 1 && !land()) // the last frame's tween has played out, and nothing is left in the air
			finish()
			return
		frame = min(frame, total)
		hold_nearby()
		sandy_replay_clocks_tick() // the held stay paused
		if(landing_stage < 2) // what gore flying on for real leaves behind it is seen as it is left
			hide_unborn()
		clear_view()
		play_sounds(frame)
		for(var/datum/sandy_replay_track/track as anything in puppets)
			var/atom/movable/thing = track.thing
			if(QDELETED(thing))
				continue
			var/redraw = FALSE
			if(track.landing)
				continue
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
			if(track.events)
				play_events(track, frame)
		for(var/datum/sandy_replay_track/track as anything in standins.Copy())
			// A one-shot plays out its animation. While gore lands, what was only drawn to the last frame goes.
			if((frame >= track.last || (landing_stage && track.last <= total + 1)) && !(track.oneshot && track.anim_until > world.time))
				QDEL_NULL(track.standin)
				standins -= track
				continue
			if(advance(track, frame))
				show(track)
			if(track.events)
				play_events(track, frame)
		sandy_member_follow() // ware_sandy_timestop_shared.dm
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
	if(state == SANDY_REPLAY_RECORDING)
		stop_paths()
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
					hand_back(track, was_playing)
					thing.sandy_replay_resume((was_playing && ended_at) ? world.time - ended_at : 0)
			track.unmasked = FALSE
		catch(var/exception/error)
			LAZYADD(problems, "[error] ([error.file]:[error.line])")
	sandy_replay_masks = length(GLOB.sandy_replay_masked)
	for(var/datum/sandy_replay_track/track as anything in standins)
		QDEL_NULL(track.standin)
	QDEL_LIST(trail_copies)
	release_shots()
	show_progress_bars()
	show_pending()
	for(var/atom/movable/thing as anything in unborn)
		if(!QDELETED(thing))
			thing.remove_filter(SANDY_REPLAY_UNBORN)
	unborn.Cut()
	for(var/atom/movable/thing as anything in rig_hidden)
		if(!QDELETED(thing))
			thing.invisibility = rig_hidden[thing]
	rig_hidden.Cut()
	for(var/mob/living/body as anything in locked)
		try
			unlock(body)
		catch(var/exception/error)
			LAZYADD(problems, "[error] ([error.file]:[error.line])")
	locked.Cut()
	ai_before.Cut()
	for(var/obj/vehicle/sealed/mecha/mech as anything in mechs)
		sandy_replay_clock_start(mech)
		if(!QDELETED(mech))
			mech.completely_disabled = mechs[mech]
	mechs.Cut()
	for(var/obj/thing as anything in held_machines)
		sandy_replay_clock_start(thing)
	held_machines.Cut()
	if(!QDELETED(user))
		UnregisterSignal(user, COMSIG_MOVABLE_Z_CHANGED)
		if(eye)
			var/client/viewer = user.client
			if(viewer)
				animate(viewer, pixel_x = eye_pixel_x, pixel_y = eye_pixel_y, time = 0, flags = ANIMATION_END_NOW)
				if(viewer.eye == eye)
					user.reset_perspective()
	try
		restore_view()
	catch(var/exception/error)
		LAZYADD(problems, "[error] ([error.file]:[error.line])")
	QDEL_NULL(eye)
	GLOB.sandy_replay_last = list("played" = was_playing, "frames" = total, "puppets" = length(puppets), "standins" = length(standins), "unhooked" = unhooked, "folded" = folded.Copy(), "unmasks" = unmasks, "afterimages" = afterimages, "ways_followed" = ways_followed, "sounds" = length(sounds), "sounds_played" = sound_at - 1, "events_played" = events_played, "chains_resumed" = chains_resumed, "event_log" = event_log.Copy())
	if(crash && !QDELETED(user) && user.stat != DEAD && cyberware_bearer_lattice(user))
		user.apply_status_effect(/datum/status_effect/cyberware_cascade_crash, crash[1], crash[2])
	crash = null
	sandy_session_replay_over(src) // a shared slow-mo's other crashes and views (ware_sandy_timestop_shared.dm)
	if(!QDELING(src))
		qdel(src)
	if(problems)
		stack_trace("Sandevistan replay restore problems: [problems.Join("; ")]")

/**
 * `src` just got its real look back after the replay. A look's vars hold where its animate()s end, so anything that
 * was mid-tween when it became a puppet starts its tween again here from where it has got to by now. `held_for` is how
 * long ago the recording ended: what the replay's last frame shows partway through is that much behind by now.
 */
/atom/movable/proc/sandy_replay_resume(held_for = 0)
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
/// A paint still going when the recording ended (a spray growing in, a pool creeping wider) ran on unseen under the
/// replay, whose last frame has it where it was then: it carries on from what was last shown instead of jumping ahead.
/obj/effect/decal/cleanable/blood/sandy_replay_resume(held_for = 0)
	if(held_for > 0)
		sandy_replay_paint_carry(held_for)
	if(!dried || length(hv_vis_painting))
		update_atom_colour()

/**
 * Moves the paint's keyframes (hv_vis_painting) so it carries on now from where it was `held_for` ago, and returns how
 * long it has left. What is left takes its own time, not the slow-mo's stretch of it: the keyframes were timed when the
 * blood landed, for a slow-mo meant to run on, and one that a held finisher kept open ends sooner than that. Without
 * [apply] nothing is moved.
 */
/obj/effect/decal/cleanable/blood/proc/sandy_replay_paint_carry(held_for, apply = TRUE)
	var/list/keys = hv_vis_painting
	var/count = length(keys)
	if(count < 2)
		return 0
	var/then = world.time - held_for
	var/heading = 0
	var/list/times = list()
	for(var/i in 1 to count)
		var/list/key = keys[i]
		times += key[3]
		if(!heading && i >= 2 && then < key[3])
			heading = i
	if(!heading)
		return 0
	var/list/ahead = keys[heading]
	var/span = times[heading] - times[heading - 1]
	var/done = span > 0 ? clamp((then - times[heading - 1]) / span, 0, 1) : 1
	var/own = length(ahead) >= 5 ? ahead[5] : span
	var/reached = world.time + (1 - done) * own
	var/back = world.time - done * own - times[heading - 1]
	if(apply)
		for(var/i in 1 to heading - 1)
			var/list/key = keys[i]
			key[3] = times[i] + back
		ahead[3] = reached
	for(var/i in heading + 1 to count)
		var/list/key = keys[i]
		reached += length(key) >= 5 ? key[5] : times[i] - times[i - 1]
		if(apply)
			key[3] = reached
	return reached - world.time

/// The surge window is closing on `user`: if their replay is about to play or playing, the crash waits for it.
/// Returns TRUE if it took the crash.
/proc/sandy_replay_defer_crash(mob/living/user, length, stamina)
	if(sandy_session_defer_crash(user, length, stamina)) // a shared slow-mo's crashes wait for its one replay (ware_sandy_timestop_shared.dm)
		return TRUE
	var/datum/sandy_replay/replay = GLOB.sandy_replays[user]
	if(!replay || replay.finished)
		return FALSE
	if(replay.state != SANDY_REPLAY_PENDING && replay.state != SANDY_REPLAY_PLAYING && !(replay.state == SANDY_REPLAY_RECORDING && replay.wait_started))
		return FALSE
	replay.crash = list(length, stamina)
	return TRUE

/**
 * Whether `body` is in the middle of an execution or a finisher, either side of it: a #509 finisher (the Gorilla
 * moves, the scissor, the garrote, the bosses'), a gun's execution wind-up, or a rig move (the impale, the slam, the
 * haymaker) with the body hidden under its posed pictures.
 */
/proc/sandy_replay_mid_move(mob/living/body)
	if(QDELETED(body))
		return FALSE
	if(body.has_status_effect(/datum/status_effect/hv_finishing) || body.has_status_effect(/datum/status_effect/hv_finisher_hold))
		return TRUE
	if(DOING_INTERACTION(body, DOAFTER_SOURCE_HV_EXECUTION))
		return TRUE
	if(body.GetComponent(/datum/component/gorilla_fold))
		return FALSE // a broken back left drawn bent (gorilla_finisher.dm): a pose that lasts, not a move
	return sandy_rig_hidden(body)

/// Whether a finisher rig hides `body` behind its puppets.
/proc/sandy_rig_hidden(atom/body)
	for(var/name in SANDY_REPLAY_RIG_HIDES)
		if(body.filter_data?[name])
			return TRUE
	return FALSE

/// Whether an execution bar at `spot` falls inside a replay showing now (owner: no progress bar in a replay).
/proc/sandy_replay_hides_bars_at(turf/spot)
	for(var/user in GLOB.sandy_replays)
		var/datum/sandy_replay/replay = GLOB.sandy_replays[user]
		if(replay.state == SANDY_REPLAY_PLAYING && !replay.finished && replay.bar_reach(spot))
			return TRUE
	return FALSE

/**
 * Called from playsound(): a sound played in a slow-mo is recorded for its replay. A /sound datum is a looping
 * sound's next segment (machines, weather), which plays on live and isn't recorded. A sound played while a replay
 * starts (its surge sound in begin()) goes to that replay's viewers from where each is watching: the list of who
 * heard it is returned, and playsound() plays it to nobody else.
 */
/proc/sandy_replay_hear(turf/source, soundin, vol, vary, extrarange, falloff_exponent, frequency, pressure_affected, ignore_walls, falloff_distance, use_reverb, volume_preference)
	if(GLOB.sandy_replay_echoing || isdatum(soundin))
		return null
	for(var/user in GLOB.sandy_replays)
		var/datum/sandy_replay/replay = GLOB.sandy_replays[user]
		replay.hear(source, list(soundin, vol, vary, extrarange, falloff_exponent, frequency, pressure_affected, ignore_walls, falloff_distance, use_reverb, volume_preference), usr)
	var/datum/sandy_replay/starting = GLOB.sandy_replay_routing
	if(!starting || GLOB.sandy_replay_routing_time != world.time || starting.state != SANDY_REPLAY_PLAYING || starting.finished)
		return null
	return starting.play_to_viewers(source, soundin, vol, vary, extrarange, falloff_exponent, frequency, pressure_affected, ignore_walls, falloff_distance, use_reverb, volume_preference)

#define SANDY_ANIM_UNSET "\[sandy_replay_unset]"
/**
 * animate(), journaled for the Sandevistan replay. The rig and finisher files call this in place of animate() through
 * a file-local macro (`#define animate(arguments...) sandy_replay_animate(arguments)`). It takes every named argument
 * those files use; one it doesn't know is a runtime error, so add it here before using it there.
 */
/proc/sandy_replay_animate(Object = SANDY_ANIM_UNSET, time = SANDY_ANIM_UNSET, loop = SANDY_ANIM_UNSET, easing = SANDY_ANIM_UNSET, flags = SANDY_ANIM_UNSET, delay = SANDY_ANIM_UNSET, tag = SANDY_ANIM_UNSET, transform = SANDY_ANIM_UNSET, pixel_x = SANDY_ANIM_UNSET, pixel_y = SANDY_ANIM_UNSET, pixel_w = SANDY_ANIM_UNSET, pixel_z = SANDY_ANIM_UNSET, alpha = SANDY_ANIM_UNSET, color = SANDY_ANIM_UNSET, layer = SANDY_ANIM_UNSET, dir = SANDY_ANIM_UNSET, icon_state = SANDY_ANIM_UNSET, x = SANDY_ANIM_UNSET, y = SANDY_ANIM_UNSET, size = SANDY_ANIM_UNSET, offset = SANDY_ANIM_UNSET, radius = SANDY_ANIM_UNSET)
	var/static/list/names = list("time", "loop", "easing", "flags", "delay", "tag", "transform", "pixel_x", "pixel_y", "pixel_w", "pixel_z", "alpha", "color", "layer", "dir", "icon_state", "x", "y", "size", "offset", "radius")
	var/list/values = list(time, loop, easing, flags, delay, tag, transform, pixel_x, pixel_y, pixel_w, pixel_z, alpha, color, layer, dir, icon_state, x, y, size, offset, radius)
	var/list/step = list()
	for(var/i in 1 to length(names))
		var/value = values[i]
		if(value == SANDY_ANIM_UNSET)
			continue
		var/name = names[i]
		if(isnull(value))
			// arglist() drops a named null; animate() reads these as their plain values
			switch(name)
				if("transform")
					value = matrix()
				if("color")
					value = COLOR_WHITE
				else
					continue
		step[name] = value
	var/given = Object != SANDY_ANIM_UNSET
	if(length(GLOB.sandy_replays))
		for(var/user in GLOB.sandy_replays)
			var/datum/sandy_replay/replay = GLOB.sandy_replays[user]
			replay.journal(given ? Object : null, step, (given && ismovable(Object)) ? Object : null)
	var/list/arguments = given ? list(Object) : list()
	for(var/name in step)
		arguments[name] = step[name]
	animate(arglist(arguments))
#undef SANDY_ANIM_UNSET

/// Whether `thing` is a finisher rig's posed piece of a body, or a loose picture of the move's (a blood spray, an
/// execution's muzzle flash).
/proc/sandy_rig_picture(atom/thing)
	return istype(thing, /obj/effect/abstract/chrome_puppet) || istype(thing, /obj/effect/abstract/mantis_puppet) || istype(thing, /obj/effect/abstract/mantis_rig_fx) || istype(thing, /obj/effect/temp_visual/hv_muzzle_flash)

/// A short picture a chrome weapon plays on a body (a Mantis swing on its bearer, a slash over someone hit): it is in
/// nothing, only in that body's vis_contents, so no field ever sees it (cyberware_anim.dm).
/proc/sandy_bearer_picture(atom/thing)
	return istype(thing, /obj/effect/abstract/cyberware_anim)

/// A one-shot effect was just made: every recording near it takes it now, from this frame. Called by effects whose
/// animation isn't journaled (it is in their Initialize()), and by those a move makes after its slow-mo has ended, when no
/// field hands new things over.
/proc/sandy_replay_made(atom/movable/thing)
	if(!length(GLOB.sandy_replays))
		return
	var/turf/where = get_turf(thing)
	if(!where && sandy_bearer_picture(thing))
		var/obj/effect/abstract/cyberware_anim/picture = thing
		where = get_turf(picture.bearer)
	if(!where)
		return
	for(var/user in GLOB.sandy_replays)
		var/datum/sandy_replay/replay = GLOB.sandy_replays[user]
		if(replay.state == SANDY_REPLAY_RECORDING && replay.user && replay.near_centre(where, SANDY_REPLAY_MADE_REACH))
			replay.notice(thing)

/// tg's muzzle flash is made inside the shooter and shown in their vis_contents, where no field sees it: every
/// recording near it takes it here, so a replayed shot has its flash (shown_on() draws it on the shooter's tile).
/obj/effect/temp_visual/dir_setting/firing_effect/Initialize(mapload, set_dir)
	. = ..()
	sandy_replay_made(src)

/// Blood is laid wherever a blow throws it, and a slowed room is wider than the field that hands new things to the
/// recording (a shared slow-mo slows a whole hall): the recording takes it here as it is made. Missed, it lay on the
/// floor from the replay's first frame, before the replay had reached the blow that spilled it.
/obj/effect/decal/cleanable/blood/Initialize(mapload, list/datum/disease/diseases, list/blood_or_dna = get_default_blood_type())
	. = ..()
	if(!mapload && . != INITIALIZE_HINT_QDEL && length(GLOB.sandy_replays) && isturf(loc))
		sandy_replay_made(src)

/// tg's blood splash is put on the floor, where the field hands it over at once, and only then (Initialize()) turns the
/// way the blow went, takes its colour and flies off fading. The recording took it bare: it is looked at again here,
/// with its flight, or a replayed hit has no splash.
/obj/effect/temp_visual/dir_setting/bloodsplatter/Initialize(mapload, set_dir, set_color = BLOOD_COLOR_RED)
	. = ..()
	if(!length(GLOB.sandy_replays))
		return
	for(var/user in GLOB.sandy_replays)
		var/datum/sandy_replay/replay = GLOB.sandy_replays[user]
		replay.retake(src)

/obj/effect/temp_visual/dir_setting/bloodsplatter/sandy_replay_intro()
	if(alpha) // not flying yet: once it is, its vars hold where the flight ends
		return null
	return list(list("pixel_x" = 0, "pixel_y" = 0, "alpha" = initial(alpha)), list(
		list(list("pixel_x" = pixel_x, "pixel_y" = pixel_y, "alpha" = 0, "time" = duration, "easing" = CUBIC_EASING | EASE_OUT)),
	))

/// A one-shot the recording took as it was put down has since been set up (turned, coloured, set flying): its first
/// frame is taken again, and its own animation goes in its track.
/datum/sandy_replay/proc/retake(obj/effect/temp_visual/effect)
	var/datum/sandy_replay_track/track = tracks[effect]
	if(!track || state != SANDY_REPLAY_RECORDING)
		return
	track.last_raw = null
	sample_track(track, track.first)
	track.events = null
	intro(track)

/**
 * What a temp visual that animates itself in Initialize() looks like before its animation, and the animation: list(the
 * vars it starts with, as animate() arguments; list(chains: each a list of animate() argument lists, the first without
 * the object)). Null when it has none.
 */
/obj/effect/temp_visual/proc/sandy_replay_intro()
	return null

/obj/effect/temp_visual/circle_wave/sandy_replay_intro()
	return list(list("transform" = matrix().Scale(0.1), "alpha" = initial(alpha)), list(
		list(list("transform" = matrix().Scale(amount_to_scale), "time" = duration, "flags" = ANIMATION_PARALLEL)),
		list(list("alpha" = max_alpha, "time" = duration * 0.6, "flags" = ANIMATION_PARALLEL), list("alpha" = 0, "time" = duration * 0.4)),
	))

/obj/effect/temp_visual/cyberware_impact_cracks
	/// The alpha it was made with, before its fade (sandy_replay_intro()). Null if no replay took it.
	var/sandy_peak_alpha

/// Called before its fade starts: the alpha it has now is the one it starts with.
/obj/effect/temp_visual/cyberware_impact_cracks/sandy_replay_intro()
	sandy_peak_alpha = alpha
	return list(list("alpha" = alpha), list(list(list("alpha" = alpha, "time" = duration - 2 SECONDS), list("alpha" = 0, "time" = 2 SECONDS))))

/// Its alpha var already holds the end of its fade (0): handed back as it was, the cracks would vanish as the replay
/// ends. They are drawn as the real ones are by now instead, and fade out on their own clock.
/obj/effect/temp_visual/cyberware_impact_cracks/sandy_replay_resume(held_for = 0)
	var/left = timerid ? timeleft(timerid) : 0
	if(isnull(sandy_peak_alpha) || !left)
		return
	if(left > 2 SECONDS)
		alpha = sandy_peak_alpha
		animate(src, alpha = sandy_peak_alpha, time = left - 2 SECONDS)
		animate(alpha = 0, time = 2 SECONDS)
	else
		alpha = round(sandy_peak_alpha * left / (2 SECONDS))
		animate(src, alpha = 0, time = left)

/// The slow-mo's release flash isn't put on the screen of a user whose replay is starting: the cut to the replay is the
/// change of scene (begin()).
/atom/movable/screen/fullscreen/flash/sandy_release/should_show_to(mob/mymob)
	if(isliving(mymob) && sandy_replay_showing(mymob))
		return FALSE
	return ..()

/// Whether a replay is showing on (or about to show for) `user`.
/proc/sandy_replay_showing(mob/living/user)
	var/datum/sandy_replay/replay = GLOB.sandy_replays[user] || sandy_session_replay_of(user) // or a shared slow-mo's (ware_sandy_timestop_shared.dm)
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

// tg's offsets (grabs, lying, a finisher's lean) write all four pixel offsets outright. On a puppet that would
// overwrite the shift that draws it on its recorded tile, and fold() would carry the difference over to the real
// body as an offset: the body left drawn tiles away from where it stands after the replay.
/mob/living/update_offsets(animate = FALSE)
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
#undef SANDY_REPLAY_UNBORN
#undef SANDY_REPLAY_PENDING_HIDE
#undef SANDY_REPLAY_RECORDING
#undef SANDY_REPLAY_PENDING
#undef SANDY_REPLAY_PLAYING
#undef SANDY_REPLAY_DONE
#undef SANDY_TRACK_PUPPET
#undef SANDY_TRACK_STANDIN
#undef SANDY_REPLAY_REACH
#undef SANDY_REPLAY_MAX_SHOTS
#undef SANDY_REPLAY_ONESHOT_MIN
#undef SANDY_REPLAY_GLIDE_MAX
#undef SANDY_REPLAY_SURGE_GLIDE_MAX
#undef SANDY_REPLAY_WATCHDOG
#undef SANDY_REPLAY_TURN_TIME
#undef SANDY_REPLAY_BURST_CUES_MAX
#undef SANDY_REPLAY_MAX_SOUNDS
#undef SANDY_REPLAY_MAX_OWN_SOUNDS
#undef SANDY_REPLAY_SOUND_VOLUME
#undef SANDY_REPLAY_SOUND_GAP
#undef SANDY_REPLAY_HOLD_RANGE
#undef SANDY_REPLAY_MADE_REACH
#undef SANDY_REPLAY_LANDING_MAX
#undef SANDY_REPLAY_LANDING_TWEENS
#undef SANDY_REPLAY_LANDING_FRAMES
#undef SANDY_REPLAY_ONESHOT_FRAMES
#undef SANDY_REPLAY_PICTURE_TIME
#undef SANDY_REPLAY_WAIT_MAX
#undef SANDY_REPLAY_RIG_HIDES
#undef SANDY_FRAME_SIZE
#undef SANDY_FRAME_INDEX
#undef SANDY_FRAME_LOOK
#undef SANDY_FRAME_X
#undef SANDY_FRAME_Y
#undef SANDY_FRAME_Z
#undef SANDY_FRAME_DIR
