/**
 * # Stealth guards: flashlights (owner decisions 31, 39 and 41)
 *
 * A scav guard carries a real seclite clipped to its belt (or its vest, or a pocket). What it lights is a real
 * light (decision 39): a hidden lamp, /obj/effect/abstract/stealth_torch, on the guard's own tile, that throws a
 * beam the way it faces through tg's own static lighting (a directional light, as tg's wall lamps are). Everyone
 * sees the beam, round corners too, and the darkness rule (stealth_tile_is_dark()) reads the same light the
 * players see, so what looks dark is dark to the guards as well. The seclite item itself stays off and stays a
 * plain tg seclite: a looted one works like any other, and nothing draws two beams.
 *
 * The beam (decision 41): a wedge that starts at the guard's hand, half a tile ahead of it, widens to three tiles
 * and lights the floor up to four tiles ahead, brightest two and three tiles out. Its own tile, its sides and its
 * back stay dark. tg's lighting stops it at walls and closed solid doors and lets it through glass, like any lamp
 * (numbers in data/stealth/STATUS.md, decision 41).
 *
 * What the eye sees on top (decision 42): a cone in the air from the guard's lamp and a small glow there
 * (/obj/effect/abstract/stealth_beam), so the beam visibly starts at the guard. Only the eye sees it.
 *
 * The beam moves like a hand moves it. Before a turn the guard makes on its own, the beam swings halfway there
 * while the body leans (stealth_turns.dm), so the light shows where it is about to look. Any other turn of 90
 * degrees or more passes through the halfway point. A step at a walk carries the beam half a tile at a time. A
 * guard that is searching, or looking round where it thought it saw something, swings the beam to one side, back,
 * and to the other while it stands.
 *
 * The guard switches it as before: on when it stands somewhere dark (judged without any guard's light, decision 32,
 * so two guards never switch each other off), always on while suspicious, alert or searching, off in lit places
 * while unaware. It keeps it on for STEALTH_LIGHT_HOLD after it last wanted it, so walking along the edge of a lit
 * room doesn't flick it on and off. The switch clicks.
 *
 * Beating it is tg's: you see the beam coming; an EMP or the saboteur gun cuts the seclite out for a while (the scav
 * seclite takes an EMP as tg's saboteur hit; a stock seclite ignores EMPs), and it sputters twice as it dies; a
 * guard that is down, stunned, cuffed, held, asleep or dead has no light; nor does one whose seclite was taken
 * (decision 34: it can be stripped, knocked loose and looted like anyone's seclite).
 *
 * Other people's lights (decision 41): a lit light someone carries near an unaware guard that stands in the dark
 * draws its notice even from behind (stealth_look()). It only ever makes the guard suspicious: it turns to look.
 *
 * Cost: the lamp updates only when the guard's turf or the beam's direction changes, or when it switches. A step
 * at a walk is two static light updates (the half step and the landing), a turn one or two, a sweep one per
 * STEALTH_TORCH_SWEEP_STEP while the guard is suspicious or searching and standing. A guard asleep in a dormant
 * level moves, scans and sweeps nothing, so its lamp costs nothing.
 */

/// Every guard's lamp, so a guard can leave them all out when it judges how dark its own spot is (decision 32)
GLOBAL_LIST_EMPTY(stealth_guard_torches)

/// A guard's seclite: an EMP blinds it for a while, as tg's saboteur gun does.
/obj/item/flashlight/seclite/scav

/obj/item/flashlight/seclite/scav/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	on_saboteur(null, severity == EMP_HEAVY ? STEALTH_LIGHT_EMP_HEAVY : STEALTH_LIGHT_EMP_LIGHT)

/obj/item/flashlight/seclite/scav/on_saboteur(datum/source, disrupt_duration)
	. = ..()
	stealth_tell_holder(loc)

/// Off a guard's body (looted, stripped, dropped), the guard's beam goes out at once.
/obj/item/flashlight/seclite/scav/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	stealth_tell_holder(old_loc)

/// Tells the guard `holder` (if it is one) that its light changed.
/obj/item/flashlight/seclite/scav/proc/stealth_tell_holder(atom/holder)
	if(!ishumannpc(holder))
		return
	var/mob/living/carbon/human/npc/guard = holder
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = guard.ai_controller
	if(istype(stealth_ai))
		stealth_ai.stealth_update_light()

/// Decision 34: a guard's seclite is loot like anyone's, so it is never locked to the body (D3 holds for the rest).
/// Decision 40: so are the scavs' fatigues, balaclava and pass (stealth_disguise.dm).
/mob/living/carbon/human/npc/npc_lock_item(obj/item/item)
	if(istype(item, /obj/item/flashlight/seclite/scav) || istype(item, /obj/item/clothing/under/syndicate/scav))
		return FALSE
	if(istype(item, /obj/item/clothing/mask/balaclava/scav) || istype(item, /obj/item/card/id/advanced/black/scav))
		return FALSE
	return ..()

/mob/living/carbon/human/npc
	/// Weakref to the flashlight a stealth guard switches on in the dark, or null for none
	var/datum/weakref/stealth_light

/// Clips a seclite on: belt, vest, then a pocket. Returns it, or null if there was nowhere to put it.
/mob/living/carbon/human/npc/proc/stealth_give_light()
	var/obj/item/flashlight/seclite/scav/light = new(src)
	for(var/slot in list(ITEM_SLOT_BELT, ITEM_SLOT_SUITSTORE, ITEM_SLOT_LPOCKET, ITEM_SLOT_RPOCKET))
		if(equip_to_slot_if_possible(light, slot, disable_warning = TRUE))
			stealth_light = WEAKREF(light)
			return light
	qdel(light)
	return null

/**
 * The lamp behind a guard's flashlight beam: a real static light with no sprite, on the guard's own tile. It is
 * never entered into a turf (abstract_move()), so it trips nothing, and nothing can touch, move or burn it.
 */
/obj/effect/abstract/stealth_torch
	name = "flashlight beam"
	icon = null
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	blocks_emissive = EMISSIVE_BLOCK_NONE
	light_system = COMPLEX_LIGHT
	light_range = STEALTH_TORCH_RANGE
	light_power = STEALTH_TORCH_POWER
	light_color = STEALTH_TORCH_COLOR
	light_angle = STEALTH_TORCH_ANGLE
	light_flags = LIGHT_IGNORE_OFFSET
	light_on = FALSE
	/// Where the beam starts, in tiles from the middle of the lamp's tile, as tg's light offset: a negative x is east
	var/beam_x = 0
	var/beam_y = 0

/obj/effect/abstract/stealth_torch/Initialize(mapload)
	. = ..()
	GLOB.stealth_guard_torches += src

/obj/effect/abstract/stealth_torch/Destroy()
	GLOB.stealth_guard_torches -= src
	return ..()

/obj/effect/abstract/stealth_torch/get_light_offset()
	return list(beam_x, beam_y)

/**
 * What the eye sees of a guard's beam (decision 42): a cone of light in the air, narrow at its lamp and widening
 * ahead, with a small glow at the lamp. It sits on tg's overlay-light plane and adds to the light there, as tg's own
 * flashlight cones do, so it brightens what it falls on, shows in the dark and all but vanishes in a lit room. It is
 * part of the guard (vis_contents), so it glides with every step. It is only for the eye: guards see, and tiles count
 * as lit, by the real lamp alone. It stops at the first wall or solid door ahead (stealth_beam_reach()).
 * It never shows ahead of the lamp's light on the floor: a new aim waits until SSlighting has applied the lamp
 * (stealth_queue(), COMSIG_LIGHT_SOURCE_APPLIED), so when lighting runs slow the whole flashlight is slow together.
 */
/obj/effect/abstract/stealth_beam
	name = "flashlight beam"
	icon = 'voidcrew/icons/effects/stealth_beam.dmi'
	icon_state = "beam_22"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	blocks_emissive = EMISSIVE_BLOCK_NONE
	blend_mode = BLEND_ADD
	appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM | KEEP_APART | PIXEL_SCALE
	// The icon's bottom middle on the guard's tile centre
	pixel_x = -48
	pixel_y = 16
	/// The guard it is shown on, or null
	var/mob/living/holder
	/// The way it points now, or 0
	var/shown_dir = 0
	/// The facing of the guard when it was last aimed (the lamp's place on the body follows that)
	var/shown_body_dir = 0
	/// The guard it waits to be shown on once the lamp's light is applied, or null
	var/mob/living/pending_guard
	/// What it will show then: the way it points, its length and the guard's facing
	var/pending_dir = 0
	var/pending_reach = 0
	var/pending_body_dir = 0

/obj/effect/abstract/stealth_beam/Destroy()
	stealth_hide()
	return ..()

/// Takes it off its guard.
/obj/effect/abstract/stealth_beam/proc/stealth_hide()
	pending_guard = null
	if(holder)
		holder.vis_contents -= src
		holder = null
	shown_dir = 0
	shown_body_dir = 0

/// Shows it as stealth_show() once the lamp's light has been applied (stealth_flush()). Until then it stays as it was.
/obj/effect/abstract/stealth_beam/proc/stealth_queue(mob/living/guard, beam_dir, reach)
	pending_guard = guard
	pending_dir = beam_dir
	pending_reach = reach
	pending_body_dir = guard.dir

/// The lamp's light is applied: shows what was waiting for it, if its guard is still about.
/obj/effect/abstract/stealth_beam/proc/stealth_flush()
	var/mob/living/guard = pending_guard
	pending_guard = null
	if(!QDELETED(guard))
		stealth_show(guard, pending_dir, pending_reach, pending_body_dir)

/// Shows it on `guard`, pointing `beam_dir` and `reach` eighths of a tile long, for the guard facing `body_dir` (its
/// facing now by default). Touches nothing that is already so.
/obj/effect/abstract/stealth_beam/proc/stealth_show(mob/living/guard, beam_dir, reach, body_dir)
	pending_guard = null
	if(!body_dir)
		body_dir = guard.dir
	if(holder != guard)
		stealth_hide()
		holder = guard
		guard.vis_contents += src
	SET_PLANE_EXPLICIT(src, O_LIGHTING_VISUAL_PLANE, guard)
	// Pointing away from the camera, the guard's body hides the lamp: no glow, and the cone comes out past its back.
	var/away = body_dir & NORTH
	var/state = "[away ? "back" : "beam"]_[reach]"
	if(icon_state != state)
		icon_state = state
	if(shown_dir == beam_dir && shown_body_dir == body_dir)
		return
	shown_dir = beam_dir
	shown_body_dir = body_dir
	// The lamp is at its belt: a little ahead facing away, a little below the middle facing the camera or sideways.
	var/forward = away ? 4 : ((body_dir & SOUTH) ? -6 : 0)
	var/drop = (body_dir & (EAST|WEST)) && !(body_dir & (NORTH|SOUTH)) ? -3 : 0
	var/matrix/aim = matrix()
	aim.Translate(0, STEALTH_BEAM_PIVOT + forward)
	aim.Turn(dir2angle(beam_dir))
	aim.Translate(0, drop - STEALTH_BEAM_PIVOT)
	transform = aim

/// How long a guard's visible cone is from `spot` pointing `beam_dir`, in eighths of a tile: up to a little onto the
/// first wall or solid door (what stops tg's light), or STEALTH_BEAM_LENGTHS for nothing in its reach.
/proc/stealth_beam_reach(turf/spot, beam_dir)
	var/diagonal = !(beam_dir in GLOB.cardinals)
	var/turf/here = spot
	for(var/steps in 1 to STEALTH_TORCH_RANGE)
		var/turf/next = get_step(here, beam_dir)
		var/blocked = isnull(next) || IS_OPAQUE_TURF(next)
		if(!blocked && diagonal)
			// Light doesn't squeeze between two corners.
			var/turf/one_side = get_step(here, beam_dir & (NORTH|SOUTH))
			var/turf/other_side = get_step(here, beam_dir & (EAST|WEST))
			blocked = (isnull(one_side) || IS_OPAQUE_TURF(one_side)) && (isnull(other_side) || IS_OPAQUE_TURF(other_side))
		if(blocked)
			// to the blocker's near face, then 6 px onto it
			var/pixels = (steps - 0.5) * (diagonal ? 45 : 32) + 6
			return clamp(round(pixels / 8, 1), 1, STEALTH_BEAM_LENGTHS - 1)
		here = next
	return STEALTH_BEAM_LENGTHS

/// How much every guard's lamp adds to `tile` right now, in get_lumcount() units.
/proc/stealth_torch_share(turf/tile)
	. = 0
	if(!isturf(tile))
		return
	for(var/obj/effect/abstract/stealth_torch/torch as anything in GLOB.stealth_guard_torches)
		var/datum/light_source/source = torch.light
		var/list/strengths = source?.effect_str
		if(!length(strengths) || torch.z != tile.z || get_dist(torch, tile) > STEALTH_TORCH_RANGE + 2)
			continue
		var/channels = source.applied_lum_r + source.applied_lum_g + source.applied_lum_b
		for(var/datum/lighting_corner/corner as anything in list(tile.lighting_corner_NE, tile.lighting_corner_SE, tile.lighting_corner_SW, tile.lighting_corner_NW))
			if(corner)
				. += (strengths[corner] || 0) * channels
	. /= 12 // as get_lumcount(): 4 corners, 3 channels each

/// How far the lit light `who` carries reaches, in tiles: a flashlight in a hand or on a belt, a lit PDA, a flare.
/// 0 with nothing lit.
/proc/stealth_carried_light(mob/living/who)
	. = 0
	// tg's overlay lights (flashlights, PDAs, helmet lights): light => reach + 1, listed only while lit
	for(var/glow in who.affected_dynamic_lights)
		. = max(., who.affected_dynamic_lights[glow] - 1)
	// tg's static lights carried on the body (flares, lanterns)
	for(var/datum/light_source/source as anything in who.light_sources)
		if(source.top_atom == who)
			. = max(., CEILING(source.light_range, 1))

/// The swing between two facings in degrees, -180 to 179: positive when `first` is clockwise of `second`.
/proc/stealth_swing(first, second)
	return (dir2angle(first) - dir2angle(second) + 540) % 360 - 180

/datum/ai_controller/basic_controller/human_npc/stealth
	/// world.time until which it keeps its light on after it last wanted it
	var/light_hold_until = 0
	/// Whether it has its light on (the beam shows whenever it stands on a turf)
	var/light_lit = FALSE
	/// The lamp behind its beam, made the first time it is switched on
	var/obj/effect/abstract/stealth_torch/torch
	/// The cone players see over its beam (decision 42), made with the lamp
	var/obj/effect/abstract/stealth_beam/beam
	/// Where it points the beam off its facing, in 45 degree steps anticlockwise: a sweep, or the lead of a turn
	var/torch_aim = 0
	/// The way the beam points for a moment in the middle of a turn, or 0
	var/torch_pass = 0
	/// world.time of that turn: a step in the same tick (tg turns a walker before it moves) keeps it
	var/torch_passed_at = 0
	/// How far behind its tile the beam still is in the middle of a step, in tiles
	var/torch_lag_x = 0
	var/torch_lag_y = 0
	/// Counts beam moves, so a timer from an older one does nothing
	var/torch_serial = 0
	/// world.time it last stepped
	var/torch_moved_at = 0
	/// Whether its sweep timer is running
	var/sweeping = FALSE
	/// Where it is in the sweep: 1 one side, 2 back, 3 the other side, 4 back
	var/sweep_step = 0
	/// Counts switches, so a light that comes back stops a sputter
	var/sputter_serial = 0

/// Its flashlight, if it still has it on its body; else null.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_light()
	var/mob/living/carbon/human/npc/guard = pawn
	if(!ishumannpc(guard))
		return null
	var/obj/item/flashlight/light = guard.stealth_light?.resolve()
	if(QDELETED(light) || light.loc != guard)
		return null
	return light

/// Whether it can use its light at all: awake, its own, free, hands working, and the seclite on it and not cut out.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_light_usable()
	var/mob/living/carbon/human/npc/guard = pawn
	if(QDELETED(guard) || guard.stat != CONSCIOUS || stealth_driven() || stealth_captive() || HAS_TRAIT(guard, TRAIT_HANDS_BLOCKED))
		return FALSE
	var/obj/item/flashlight/light = stealth_light()
	return !isnull(light) && COOLDOWN_FINISHED(light, disabled_time)

/// Switches its light on or off for where it stands and what it is doing. Off at once when it can't use it.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_update_light()
	if(!stealth_light_usable())
		var/was_lit = light_lit
		light_hold_until = 0
		stealth_set_light(FALSE)
		if(was_lit)
			stealth_light_cut()
		return
	var/mob/living/guard = pawn
	// Its own spot judged by the room's light alone: a friend's passing beam doesn't switch it off (decision 32).
	var/wanted = stealth_state() != STEALTH_UNAWARE || stealth_tile_is_dark(get_turf(guard), no_guard_lights = TRUE)
	if(wanted)
		light_hold_until = world.time + STEALTH_LIGHT_HOLD
	else if(world.time < light_hold_until)
		stealth_place_torch()
		return
	stealth_set_light(wanted, TRUE)
	stealth_sweep_check()

/// `click`: it worked the switch itself, which is heard.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_set_light(lit, click = FALSE)
	if(lit != light_lit)
		if(click && !QDELETED(pawn))
			playsound(pawn, lit ? 'sound/items/weapons/magin.ogg' : 'sound/items/weapons/magout.ogg', STEALTH_TORCH_CLICK_VOLUME, TRUE, -4)
		sputter_serial++
		torch_serial++
		torch_aim = 0
		torch_pass = 0
		torch_lag_x = 0
		torch_lag_y = 0
	light_lit = lit
	stealth_place_torch()

/// The way its beam points now: its facing, off to a side in a sweep or ahead of a turn, or halfway through a turn.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_beam_dir()
	if(torch_pass)
		return torch_pass
	var/mob/living/guard = pawn
	return torch_aim ? turn(guard.dir, 45 * torch_aim) : guard.dir

/// Points the lamp where its beam goes now, or puts it out. Touches the light only when something changed.
/// `flash` shows the beam with the light off (a dying seclite's sputter).
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_place_torch(flash = FALSE)
	var/mob/living/guard = pawn
	var/turf/spot = ((light_lit || flash) && !QDELETED(guard) && isturf(guard.loc)) ? guard.loc : null
	if(isnull(spot))
		beam?.stealth_hide()
		if(torch?.light_on)
			torch.set_light_on(FALSE)
			torch.update_light()
		return
	if(QDELETED(torch))
		torch = new(spot)
		RegisterSignal(torch, COMSIG_LIGHT_SOURCE_APPLIED, PROC_REF(stealth_torch_applied))
	if(QDELETED(beam))
		beam = new(null)
	var/beam_dir = stealth_beam_dir()
	// The cone glides with the guard, so it needs no half steps; it is cut where the light is stopped.
	var/reach = stealth_beam_reach(spot, beam_dir)
	// The beam starts at its hand, ahead of its own tile, less whatever a step in progress still holds back.
	var/start_x = torch_lag_x - STEALTH_TORCH_FORWARD * ((beam_dir & EAST) ? 1 : ((beam_dir & WEST) ? -1 : 0))
	var/start_y = torch_lag_y - STEALTH_TORCH_FORWARD * ((beam_dir & NORTH) ? 1 : ((beam_dir & SOUTH) ? -1 : 0))
	var/changed = !torch.light_on || torch.light_dir != beam_dir || torch.beam_x != start_x || torch.beam_y != start_y
	// A move rebuilds the light by itself (the source follows its host's Moved).
	if(torch.loc != spot)
		torch.abstract_move(spot)
	if(changed)
		torch.beam_x = start_x
		torch.beam_y = start_y
		torch.set_light_dir(beam_dir)
		torch.set_light_on(TRUE)
		// tg's light setters don't rebuild a COMPLEX_LIGHT source on their own (see /obj/item/flashlight/update_brightness()).
		torch.update_light()
	// The cone never shows ahead of the light on the floor: while the lamp waits on SSlighting, so does the cone.
	if(torch.light?.needs_update)
		beam.stealth_queue(guard, beam_dir, reach)
	else
		beam.stealth_show(guard, beam_dir, reach)

/// SSlighting (or a test) applied its lamp's light: the cone catches up.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_torch_applied(datum/source)
	SIGNAL_HANDLER
	beam?.stealth_flush()

/// Whether its light is on with its beam showing (for admins and tests).
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_light_shows()
	return light_lit && !QDELETED(torch) && torch.light_on

/// It stepped from `old_loc`: the beam follows, half a tile at a time at a walk. Nothing to do with its light off.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_light_stepped(atom/old_loc)
	if(!light_lit)
		return
	if(!stealth_light_usable())
		stealth_update_light()
		return
	var/mob/living/guard = pawn
	var/walked = isturf(old_loc) && isturf(guard.loc) && guard.move_intent == MOVE_INTENT_WALK && old_loc.z == guard.z && get_dist(old_loc, guard) == 1
	torch_moved_at = world.time
	torch_aim = 0
	// A step that turns a corner keeps its turn's halfway point, so the beam doesn't snap round the corner.
	if(torch_passed_at != world.time)
		torch_pass = 0
	torch_lag_x = 0
	torch_lag_y = 0
	sweep_step = 0
	torch_serial++
	if(walked)
		torch_lag_x = 0.5 * (guard.x - old_loc.x)
		torch_lag_y = 0.5 * (guard.y - old_loc.y)
		addtimer(CALLBACK(src, PROC_REF(stealth_torch_settle), torch_serial), STEALTH_TORCH_HALF_STEP)
	else if(torch_pass)
		addtimer(CALLBACK(src, PROC_REF(stealth_torch_settle), torch_serial), STEALTH_TORCH_TURN_STEP)
	stealth_place_torch()

/// It turned from `old_dir`: the beam follows, through the halfway point when the turn is 90 degrees or more.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_light_turned(old_dir, new_dir)
	if(!light_lit)
		return
	if(!stealth_light_usable())
		stealth_update_light()
		return
	// Where the beam points now: ahead of the turn already, if it led it.
	var/was = torch?.light_on ? torch.light_dir : old_dir
	torch_aim = 0
	torch_pass = 0
	sweep_step = 0
	var/swing = stealth_swing(was, new_dir)
	// Mid-step (a diagonal step turns the walker after it moves) the half step's timer lands the beam; a turn on the
	// spot gets its own.
	if(abs(swing) > 45)
		torch_pass = turn(new_dir, swing > 0 ? -45 : 45)
		torch_passed_at = world.time
		if(!torch_lag_x && !torch_lag_y)
			torch_serial++
			addtimer(CALLBACK(src, PROC_REF(stealth_torch_settle), torch_serial), STEALTH_TORCH_TURN_STEP)
	stealth_place_torch()

/// The beam lands: the half step or the halfway point of a turn is over.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_torch_settle(serial)
	if(serial != torch_serial)
		return
	torch_pass = 0
	torch_lag_x = 0
	torch_lag_y = 0
	stealth_place_torch()

/// About to turn to `new_dir` on its own (stealth_turn_to()): the beam goes halfway there first.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_torch_lead(new_dir)
	if(!light_lit)
		return
	var/mob/living/guard = pawn
	var/swing = stealth_swing(new_dir, guard.dir)
	if(!swing)
		return
	torch_pass = 0
	torch_aim = swing > 0 ? -1 : 1
	stealth_place_torch()

/// The turn it led never came, or the sweep is over: the beam goes back to its facing.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_torch_straighten()
	if(!torch_aim)
		return
	torch_aim = 0
	stealth_place_torch()

/// Whether it swings its beam about: searching, or looking round where it thought it saw something.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_sweeps()
	if(!light_lit || !stealth_scanning())
		return FALSE
	switch(stealth_state())
		if(STEALTH_SEARCHING)
			return TRUE
		if(STEALTH_SUSPICIOUS)
			// Not while it stares at the spot, and not into the face of someone it has stopped (decision 40).
			return investigated && isnull(challenge)
	return FALSE

/// Starts its sweep if it should be sweeping and isn't.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_sweep_check()
	if(sweeping || !stealth_sweeps())
		return
	sweeping = TRUE
	sweep_step = 0
	addtimer(CALLBACK(src, PROC_REF(stealth_sweep_tick)), STEALTH_TORCH_SWEEP_STEP)

/// One move of the sweep: a side, back, the other side, back. It waits out steps and turns, and ends by itself.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_sweep_tick()
	if(!stealth_sweeps())
		sweeping = FALSE
		sweep_step = 0
		if(!turn_pending)
			stealth_torch_straighten()
		return
	addtimer(CALLBACK(src, PROC_REF(stealth_sweep_tick)), STEALTH_TORCH_SWEEP_STEP)
	// Walking, about to turn, or just turned: the beam is spoken for.
	if(turn_pending || torch_pass || world.time < torch_moved_at + STEALTH_TORCH_SWEEP_STEP || (turned_at && world.time < turned_at + STEALTH_TORCH_SWEEP_STEP))
		sweep_step = 0
		return
	sweep_step = (sweep_step % 4) + 1
	switch(sweep_step)
		if(1)
			torch_aim = look_side
		if(3)
			torch_aim = -look_side
		else
			torch_aim = 0
	stealth_place_torch()

/// Its light went out under it. A seclite that was cut out (an EMP, the saboteur gun) sputters twice, and it says so.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_light_cut()
	var/mob/living/guard = pawn
	if(QDELETED(guard) || guard.stat != CONSCIOUS || stealth_driven() || stealth_captive() || HAS_TRAIT(guard, TRAIT_HANDS_BLOCKED))
		return
	var/obj/item/flashlight/light = stealth_light()
	if(isnull(light) || COOLDOWN_FINISHED(light, disabled_time))
		return
	var/serial = sputter_serial
	for(var/flash_at in STEALTH_TORCH_SPUTTER_AT)
		addtimer(CALLBACK(src, PROC_REF(stealth_sputter), serial, TRUE), flash_at)
		addtimer(CALLBACK(src, PROC_REF(stealth_sputter), serial, FALSE), flash_at + STEALTH_TORCH_SPUTTER_FLASH)
	stealth_bark(STEALTH_BARK_LIGHT_DEAD)

/// One flash of a dying seclite, on or off again. Nothing if the light is back, gone, or its guard is down.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_sputter(serial, on)
	if(serial != sputter_serial || light_lit)
		return
	var/mob/living/guard = pawn
	if(on && (QDELETED(guard) || guard.stat != CONSCIOUS || isnull(stealth_light())))
		return
	stealth_place_torch(flash = on)
