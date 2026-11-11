/**
 * # Stealth guards: flashlights (owner decisions 31 and 39)
 *
 * A scav guard carries a real seclite clipped to its belt (or its vest, or a pocket). What it lights is a real
 * light (decision 39): a hidden lamp, /obj/effect/abstract/stealth_torch, that sits on the floor a few tiles ahead
 * of the guard, where the beam would land, and lights a small pool through tg's own static lighting. Everyone sees
 * the pool, around corners too, and the darkness rule (stealth_tile_is_dark()) reads the same light the players
 * see, so what looks dark is dark to the guards as well. The seclite item itself stays off and stays a plain tg
 * seclite: a looted one works like any other, and nothing draws two beams.
 *
 * Where the pool goes: STEALTH_TORCH_REACH tiles ahead along its facing (STEALTH_TORCH_REACH_DIAGONAL on a
 * diagonal), or the last open tile before the first wall, opaque thing or closed door. It shines through glass. The
 * nearer the pool has to sit, the smaller it is, so it never lights the guard's own back (stealth_torch_range()).
 * Facing a wall at its nose it has no pool at all.
 *
 * The guard switches it as before: on when it stands somewhere dark (judged without any guard's light, decision 32,
 * so two guards never switch each other off), always on while suspicious, alert or searching, off in lit places
 * while unaware. It keeps it on for STEALTH_LIGHT_HOLD after it last wanted it, so walking along the edge of a lit
 * room doesn't flick it on and off.
 *
 * Beating it is tg's: you see the pool coming; an EMP or the saboteur gun cuts the seclite out for a while (the scav
 * seclite takes an EMP as tg's saboteur hit; a stock seclite ignores EMPs); a guard that is down, stunned, cuffed,
 * held, asleep or dead has no light; nor does one whose seclite was taken (decision 34: it can be stripped, knocked
 * loose and looted like anyone's seclite).
 *
 * Cost: the pool moves only when the guard's turf or facing changes, or when it switches on or off (at most once a
 * scan). A move is one abstract_move() of the lamp, which queues one static light update. A guard asleep in a
 * dormant level moves and scans nothing, so its lamp costs nothing.
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

/// Off a guard's body (looted, stripped, dropped), the guard's pool goes out at once.
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
/mob/living/carbon/human/npc/npc_lock_item(obj/item/item)
	if(istype(item, /obj/item/flashlight/seclite/scav))
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
 * The pool of a guard's flashlight on the floor: a real static light with no sprite. It is never entered into a
 * turf (abstract_move()), so it trips nothing, and nothing can touch, move or burn it.
 */
/obj/effect/abstract/stealth_torch
	name = "flashlight beam"
	icon = null
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	blocks_emissive = EMISSIVE_BLOCK_NONE
	light_system = COMPLEX_LIGHT
	light_range = STEALTH_TORCH_RANGE_FAR
	light_power = STEALTH_TORCH_POWER
	light_color = STEALTH_TORCH_COLOR
	light_on = FALSE

/obj/effect/abstract/stealth_torch/Initialize(mapload)
	. = ..()
	GLOB.stealth_guard_torches += src

/obj/effect/abstract/stealth_torch/Destroy()
	GLOB.stealth_guard_torches -= src
	return ..()

/// How much every guard's lamp adds to `tile` right now, in get_lumcount() units.
/proc/stealth_torch_share(turf/tile)
	. = 0
	if(!isturf(tile))
		return
	for(var/obj/effect/abstract/stealth_torch/torch as anything in GLOB.stealth_guard_torches)
		var/datum/light_source/source = torch.light
		var/list/strengths = source?.effect_str
		if(!length(strengths) || torch.z != tile.z || get_dist(torch, tile) > STEALTH_TORCH_RANGE_FAR + 1)
			continue
		var/channels = source.applied_lum_r + source.applied_lum_g + source.applied_lum_b
		for(var/datum/lighting_corner/corner as anything in list(tile.lighting_corner_NE, tile.lighting_corner_SE, tile.lighting_corner_SW, tile.lighting_corner_NW))
			if(corner)
				. += (strengths[corner] || 0) * channels
	. /= 12 // as get_lumcount(): 4 corners, 3 channels each

/// Whether light passes from `tile` on to `next`, the way `facing` points: not into a wall, an opaque thing or a
/// closed door (glass ones too). Glass passes. A diagonal step needs one of its two sides open.
/proc/stealth_torch_passes(turf/tile, turf/next, facing)
	if(isnull(next) || next.z != tile.z || IS_OPAQUE_TURF(next))
		return FALSE
	if(facing & (facing - 1))
		var/turf/side_a = get_step(tile, facing & (NORTH | SOUTH))
		var/turf/side_b = get_step(tile, facing & (EAST | WEST))
		if((isnull(side_a) || IS_OPAQUE_TURF(side_a)) && (isnull(side_b) || IS_OPAQUE_TURF(side_b)))
			return FALSE
	for(var/obj/machinery/door/door in next)
		if(door.density)
			return FALSE
	for(var/obj/structure/mineral_door/door in next)
		if(door.density)
			return FALSE
	// A closed windoor on the edge it leaves by
	for(var/obj/machinery/door/window/windoor in tile)
		if(windoor.density && (windoor.dir & facing))
			return FALSE
	return TRUE

/// Where the pool of a light carried at `from`, facing `facing`, lands: the furthest open tile within reach, or null.
/proc/stealth_torch_spot(turf/from, facing)
	if(!isturf(from) || !facing)
		return null
	var/reach = (facing & (facing - 1)) ? STEALTH_TORCH_REACH_DIAGONAL : STEALTH_TORCH_REACH
	var/turf/tile = from
	var/turf/spot
	for(var/i in 1 to reach)
		var/turf/next = get_step(tile, facing)
		if(!stealth_torch_passes(tile, next, facing))
			break
		tile = next
		spot = next
	return spot

/// How wide the pool is with its centre `distance` tiles from the guard: smaller when it has to sit near, so it
/// never lights the guard's own tile or the tile behind it (numbers in data/stealth/STATUS.md, decision 39).
/proc/stealth_torch_range(distance)
	if(distance >= 2.5)
		return STEALTH_TORCH_RANGE_FAR
	if(distance >= 2)
		return STEALTH_TORCH_RANGE_MID
	return STEALTH_TORCH_RANGE_NEAR

/datum/ai_controller/basic_controller/human_npc/stealth
	/// world.time until which it keeps its light on after it last wanted it
	var/light_hold_until = 0
	/// Whether it has its light on (the pool shows when there is room for one ahead)
	var/light_lit = FALSE
	/// The pool its light makes, made the first time it is switched on
	var/obj/effect/abstract/stealth_torch/torch

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
		light_hold_until = 0
		stealth_set_light(FALSE)
		return
	var/mob/living/guard = pawn
	// Its own spot judged by the room's light alone: a friend's passing pool doesn't switch it off (decision 32).
	var/wanted = stealth_state() != STEALTH_UNAWARE || stealth_tile_is_dark(get_turf(guard), no_guard_lights = TRUE)
	if(wanted)
		light_hold_until = world.time + STEALTH_LIGHT_HOLD
	else if(world.time < light_hold_until)
		stealth_place_torch()
		return
	stealth_set_light(wanted)

/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_set_light(lit)
	light_lit = lit
	stealth_place_torch()

/// Puts the pool where its light lands now, or puts it out. Moves the lamp only when the spot changed.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_place_torch()
	var/mob/living/guard = pawn
	var/turf/spot = (light_lit && !QDELETED(guard)) ? stealth_torch_spot(get_turf(guard), guard.dir) : null
	if(isnull(spot))
		if(torch?.light_on)
			torch.set_light_on(FALSE)
		return
	if(QDELETED(torch))
		torch = new(spot)
	var/range = stealth_torch_range(get_dist_euclidean(guard, spot))
	if(torch.light_range != range)
		torch.set_light_range(range)
	if(torch.loc != spot)
		torch.abstract_move(spot)
	if(!torch.light_on)
		torch.set_light_on(TRUE)

/// Whether its light is on with a pool on the floor (for admins and tests).
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_light_shows()
	return light_lit && !QDELETED(torch) && torch.light_on

/// It moved or turned: the pool follows. Nothing to do with its light off.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_light_follow()
	if(!light_lit)
		return
	if(!stealth_light_usable())
		stealth_update_light()
		return
	stealth_place_torch()
