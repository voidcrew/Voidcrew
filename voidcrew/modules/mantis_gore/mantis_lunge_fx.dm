// Pictures for the Mantis line's gore. Nothing here changes who gets hit, when or how hard: the
// mechanics call in after they have happened. One-shot holders and temp visuals only; every animate()
// on a mob here is relative and parallel and ends where it began, so tg's offsets, lying turn and #509's
// death throes stay right. (The impale's hoist, which turns a body upright for the hold, is in
// mantis_impale.dm and gives tg's turn back. The blades going into a body are drawn by the blade rig,
// mantis_rig.dm.)

// =========================================================================
// THE LUNGE
// =========================================================================

/// How long a charged leap's body takes to arc in: longer than the lunge's glide (MANTIS_LUNGE_GLIDE).
#define MANTIS_LEAP_GLIDE 2

/// Whether a dash must stop before [step]: a drop, lava or open space. Never crossed, whatever the reach.
/proc/mantis_lunge_unsafe_turf(turf/step)
	if(isnull(step))
		return TRUE
	return istype(step, /turf/open/chasm) || islava(step) || isspaceturf(step) || istype(step, /turf/open/openspace)

/// A hardlight afterimage left along the dash.
/obj/effect/temp_visual/decoy/fading/mantis_afterimage
	duration = 4

/obj/effect/temp_visual/decoy/fading/mantis_afterimage/Initialize(mapload, atom/mimiced_atom, model, fade = 1)
	. = ..()
	// Washed out to the blade's light, fainter the further back down the line.
	color = model == "mantis_scorch" ? list(0.5, 0.3, 0.15, 0.5, 0.3, 0.15, 0.5, 0.3, 0.15, 0.45, 0.25, 0.1) : list(0.25, 0.35, 0.5, 0.25, 0.35, 0.5, 0.25, 0.35, 0.5, 0.15, 0.3, 0.45)
	alpha = round(200 * fade)
	animate(src, alpha = 0, time = duration)

/// The streak a lunge leaves at blade height across a tile it passed.
/obj/effect/temp_visual/mantis_trail
	icon = MANTIS_GORE_ICON
	icon_state = "mantis_trail"
	layer = ABOVE_MOB_LAYER
	randomdir = FALSE
	duration = 5

/obj/effect/temp_visual/mantis_trail/Initialize(mapload, trail_dir, model)
	. = ..()
	if(model == "mantis_scorch")
		icon_state = "mantis_scorch_trail"
	// The art runs east-west and north-south; a diagonal dash uses the nearer of the two.
	setDir((trail_dir & (EAST|WEST)) ? ((trail_dir & EAST) ? EAST : WEST) : ((trail_dir & NORTH) ? NORTH : SOUTH))
	add_overlay(emissive_appearance(icon, icon_state, src))

/**
 * The dash, drawn after the lunger has already arrived: the body glides in from where it started, and
 * each afterimage and streak shows as the body passes it, so the line trails behind. Returns how long the
 * body takes to glide in, 0 if it went nowhere: what the dash does to its target waits that long, to land
 * as the body does.
 */
/proc/mantis_lunge_dash_fx(mob/living/lunger, turf/start, list/passed, charged, model)
	var/turf/finish = get_turf(lunger)
	if(isnull(finish) || isnull(start) || !length(passed))
		return 0
	var/dash_dir = get_dir(start, finish)
	var/count = length(passed)
	var/glide = charged ? MANTIS_LEAP_GLIDE : MANTIS_LUNGE_GLIDE
	// The body is already there: draw it back where it started and let it slide in.
	var/back_w = (start.x - finish.x) * ICON_SIZE_X
	var/back_z = (start.y - finish.y) * ICON_SIZE_Y
	// The client glides a move of one tile by itself. Drawn back a tile on top of that, the body would start a
	// tile behind where it stood, so here it is not drawn back: its own glide is only made to take as long.
	if(get_dist(start, finish) <= 1)
		lunger.set_glide_size(DELAY_TO_GLIDE_SIZE(glide))
		back_w = 0
		back_z = 0
	animate(lunger, pixel_w = back_w, pixel_z = back_z, time = 0, flags = ANIMATION_RELATIVE|ANIMATION_PARALLEL)
	if(charged)
		// A pounce arcs, higher the further it goes.
		var/arc = min(2 * get_dist(start, finish) + 4, 16)
		animate(pixel_w = -back_w * 0.5, pixel_z = -back_z * 0.5 + arc, time = glide * 0.5, easing = SINE_EASING|EASE_OUT, flags = ANIMATION_RELATIVE)
		animate(pixel_w = -back_w * 0.5, pixel_z = -back_z * 0.5 - arc, time = glide * 0.5, easing = SINE_EASING|EASE_IN, flags = ANIMATION_RELATIVE)
		cyberware_grey_dust(start)
	else
		animate(pixel_w = -back_w, pixel_z = -back_z, time = glide, easing = SINE_EASING|EASE_OUT, flags = ANIMATION_RELATIVE)
	var/list/spots = list()
	for(var/turf/spot as anything in passed)
		spots += WEAKREF(spot)
	for(var/i in 1 to count)
		var/delay = round(glide * (i - 1) / count, world.tick_lag)
		// Dashing away from the viewer, the last half-step afterimage would stand in front of the body it trails,
		// over its legs: that one is left out.
		var/half_step = !(i == count && (dash_dir & NORTH))
		if(delay <= 0)
			mantis_dash_ghost(WEAKREF(lunger), spots[i], dash_dir, i / (count + 1), model, half_step)
		else
			addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(mantis_dash_ghost), WEAKREF(lunger), spots[i], dash_dir, i / (count + 1), model, half_step), delay)
	return glide

/**
 * The blades of [housings], laid flat for the dash, come back to the guard once the body has glided in, [delay]
 * from now. A blade that has taken another pose since (a crouch, a raise) keeps it.
 */
/proc/mantis_lunge_settle(list/housings, delay = 0)
	if(delay > 0)
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(mantis_lunge_settle), housings), delay)
		return
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_housing_blades(housings))
		if(blade.mantis_pose == MANTIS_POSE_LUNGE)
			blade.set_mantis_pose(MANTIS_POSE_GUARD)

/// One step of the dash's wake: two afterimages half a tile apart (one without [half_step]) and the streak, on
/// the tile the body just crossed.
/proc/mantis_dash_ghost(datum/weakref/lunger_ref, datum/weakref/spot_ref, dash_dir, fade, model, half_step = TRUE)
	var/mob/living/lunger = lunger_ref?.resolve()
	var/turf/spot = spot_ref?.resolve()
	if(QDELETED(lunger) || isnull(spot))
		return
	new /obj/effect/temp_visual/decoy/fading/mantis_afterimage(spot, lunger, model, fade * 0.7)
	if(half_step)
		var/obj/effect/temp_visual/decoy/fading/mantis_afterimage/half = new(spot, lunger, model, fade)
		half.pixel_x += (dash_dir & EAST) ? 16 : ((dash_dir & WEST) ? -16 : 0)
		half.pixel_y += (dash_dir & NORTH) ? 16 : ((dash_dir & SOUTH) ? -16 : 0)
	new /obj/effect/temp_visual/mantis_trail(spot, dash_dir, model)

/// The lunge lands: one impact and a puff of dust, as the gliding body reaches them, [delay] from now (the
/// glide mantis_lunge_dash_fx() gave; none for a body already there). A [pounce] lands with both blades, the
/// second mirrored a beat later. The flash comes with the knockdown (mantis_lunge_knockdown()).
/proc/mantis_lunge_arrival_fx(mob/living/lunger, mob/living/victim, impact_state, pounce = FALSE, delay = MANTIS_LUNGE_GLIDE)
	if(QDELETED(victim))
		return
	if(delay <= 0)
		mantis_lunge_land_fx(WEAKREF(lunger), WEAKREF(victim), impact_state, pounce)
		return
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(mantis_lunge_land_fx), WEAKREF(lunger), WEAKREF(victim), impact_state, pounce), delay)

/// Knocks [victim] down when the lunging body lands on them, with the impact, rather than as the lunge
/// starts its glide in: [delay] from now, as for the impact. They flash as they go: after the fall has begun,
/// because tg's fall is a plain animate() and would end a flash already running.
/proc/mantis_lunge_knockdown(mob/living/victim, amount, delay = MANTIS_LUNGE_GLIDE)
	if(QDELETED(victim))
		return
	if(delay <= 0)
		mantis_lunge_knockdown_now(WEAKREF(victim), amount)
		return
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(mantis_lunge_knockdown_now), WEAKREF(victim), amount), delay)

/proc/mantis_lunge_knockdown_now(datum/weakref/victim_ref, amount)
	var/mob/living/victim = victim_ref?.resolve()
	if(QDELETED(victim))
		return
	victim.Knockdown(amount)
	cyberware_flash_fx(victim, 0.2 SECONDS)

/proc/mantis_lunge_land_fx(datum/weakref/lunger_ref, datum/weakref/victim_ref, impact_state, pounce)
	var/mob/living/lunger = lunger_ref?.resolve()
	var/mob/living/victim = victim_ref?.resolve()
	if(QDELETED(lunger) || QDELETED(victim))
		return
	// Skewered: the blades in them are the picture of this hit.
	if(HAS_TRAIT_FROM(victim, TRAIT_IMMOBILIZED, MANTIS_IMPALE_TRAIT))
		return
	cyberware_play_impact(lunger, victim, impact_state)
	if(pounce)
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(mantis_mirrored_impact), lunger_ref, victim_ref, impact_state), 0.4)
	var/obj/effect/temp_visual/mook_dust/dust = cyberware_grey_dust(get_turf(victim))
	if(dust)
		dust.transform = matrix(0.5, 0, 0, 0, 0.5, 0)

/// The second blade's impact, from the other side.
/proc/mantis_mirrored_impact(datum/weakref/lunger_ref, datum/weakref/victim_ref, impact_state)
	var/mob/living/lunger = lunger_ref?.resolve()
	var/mob/living/victim = victim_ref?.resolve()
	if(QDELETED(lunger) || QDELETED(victim))
		return
	// Skewered: the blades in them are the picture of this hit.
	if(HAS_TRAIT_FROM(victim, TRAIT_IMMOBILIZED, MANTIS_IMPALE_TRAIT))
		return
	var/obj/effect/abstract/cyberware_anim/impact = cyberware_play_impact(lunger, victim, impact_state)
	if(impact)
		var/matrix/flipped = matrix(impact.transform)
		flipped.a = -flipped.a
		impact.transform = flipped

// =========================================================================
// THE CUTS
// =========================================================================

/// How far over the floor the artery of [zone] opens on [victim], as the spurt's art comes: "low" (a leg, or
/// anyone lying down), "mid" (an arm, the chest) or "high" (the neck).
/proc/mantis_artery_height(mob/living/victim, zone)
	if(victim.body_position == LYING_DOWN)
		return "low"
	switch(zone)
		if(BODY_ZONE_HEAD)
			return "high"
		if(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
			return "low"
	return "mid"

/// Where the artery of [zone] opens on [body], as it stands, faces and lies now, from the middle of its tile:
/// list(x, y) in pixels. The part as it is drawn (mantis_part_point()); the neck for the head.
/proc/mantis_artery_point(mob/living/body, zone)
	if(zone != BODY_ZONE_HEAD)
		return mantis_part_point(body, zone)
	var/across = (body.dir == EAST) ? 2 : ((body.dir == WEST) ? -3 : 0)
	var/matrix/shape = body.transform
	return list(round(shape.a * across + shape.b * 5 + shape.c, 1), round(shape.d * across + shape.e * 5 + shape.f, 1))

/// How long a spurt's picture shows nothing before its drops leave the wound: the half beat a swinging blade cocks
/// back before it cuts (the slash over the target waits for it the same way, mantis_swing.dm). A tear comes with
/// the click, so without the wait its drops were in the air a frame ahead of the cut. It is the art's own first
/// frame, empty: the client plays it from the same moment as the swing, where a timer on the server could not
/// be held to it.
#define MANTIS_SPURT_WAIT (0.5 DECISECONDS)

/// The spurt's art, by [height] and whether it is a [weak] one: list(how far out its drops come down, how far
/// below the wound, how long they are in the air). Pixels and deciseconds, as the art is drawn.
/proc/mantis_spurt_shape(height, weak)
	switch(height)
		if("low")
			return list(weak ? 6.7 : 16.16, 6, 3)
		if("high")
			return list(weak ? 11.63 : 28.18, 24, 4.5)
	return list(weak ? 9.8 : 23.74, 16, 4)

/**
 * One spurt out of a torn artery: a handful of drops thrown from the wound the way the cut went ([spurt_dir]),
 * big and small in turn, that arc down and land as spots about a tile off ("spurt_[height]" in
 * MANTIS_ARTERY_ICON, drawn for each of the eight ways). A [weak] one is fewer drops that fall close by: a
 * seared artery, or a wall where the drops would have come down. Upright in the world (it does not lie down
 * with the body), in the blood's own colour. Thrown away from the viewer, or out of a limb on the body's far
 * side, the drops leave from behind the body; otherwise in front of it. Thrown straight up or down the screen
 * they lean out to the wound's side of the body (mantis_spurt_lean()). The drops leave half a beat after the
 * call (MANTIS_SPURT_WAIT), with the cut that tore the artery and never ahead of it. Returns the picture.
 */
/proc/mantis_spurt_fx(mob/living/victim, zone, spurt_dir, weak = FALSE)
	if(QDELETED(victim) || !isturf(victim.loc) || victim.can_bleed(BLOOD_COVER_TURFS) != BLEED_SPLATTER)
		return null
	if(!spurt_dir)
		spurt_dir = pick(GLOB.alldirs)
	var/height = mantis_artery_height(victim, zone)
	var/list/point = mantis_artery_point(victim, zone)
	// Which side of the body's middle line, as it is drawn, the wound is on. One on the line counts as the right.
	var/side = point[1] < 0 ? -1 : 1
	// The wound on the floor's own grid: the body may be drawn off the middle of its tile (lying down, shoved).
	var/list/from = list(point[1] + victim.pixel_x + victim.pixel_w, point[2] + victim.pixel_y + victim.pixel_z)
	var/turf/land = weak ? null : mantis_spurt_turf(victim, from, height, FALSE, spurt_dir, side)
	if(!weak && (isnull(land) || hv_blood_spray_blocked(land)))
		weak = TRUE
	if(weak)
		land = mantis_spurt_turf(victim, from, height, TRUE, spurt_dir, side)
	var/list/shape = mantis_spurt_shape(height, weak)
	var/state = "[height][weak ? "_weak" : ""]"
	// The wait, the flight, and one beat past the landing on its last frame: the spots it shows there are the ones
	// laid on the floor.
	var/obj/effect/abstract/cyberware_anim/jet = cyberware_anim_play(victim, MANTIS_ARTERY_ICON, "spurt_[state]", MANTIS_ANIM_TOP_LAYER, MANTIS_SPURT_WAIT + shape[3] + world.tick_lag)
	if(!jet)
		return null
	jet.vis_flags &= ~VIS_INHERIT_DIR
	jet.setDir(spurt_dir)
	// Blood in the air is no part of the body: drawn apart from it, so its layer sorts it against the whole body.
	jet.appearance_flags |= RESET_TRANSFORM|RESET_COLOR|KEEP_APART
	// 96x96, the wound above its middle so the drops that fall furthest (the neck's, thrown down the screen) stay
	// in the picture until they land. Drawn elsewhere, not moved: it stays on the body's own row.
	jet.pixel_w = -32 + point[1]
	jet.pixel_z = -32 - MANTIS_ARTERY_WOUND_RISE + point[2]
	jet.color = victim.get_blood_dna_color() || BLOOD_COLOR_RED
	jet.layer = ((spurt_dir & NORTH) || wire_limb_far(zone, victim.dir)) ? BELOW_MOB_LAYER : MANTIS_OVER_VICTIM_LAYER
	var/lean = mantis_spurt_lean(weak, spurt_dir, side)
	if(lean)
		// They lean from when they leave the wound, not while the picture waits.
		var/wound_w = jet.pixel_w
		animate(jet, pixel_w = wound_w, time = MANTIS_SPURT_WAIT)
		animate(pixel_w = wound_w + lean, time = shape[3], easing = SINE_EASING|EASE_OUT)
	if(land)
		var/list/spot = mantis_spurt_spot(from, height, weak, spurt_dir, side)
		var/offset_x = spot[1] - (land.x - victim.x) * ICON_SIZE_X
		var/offset_y = spot[2] - (land.y - victim.y) * ICON_SIZE_Y
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(mantis_spurt_land), land, "artery_drops_[state]", spurt_dir, offset_x, offset_y, victim.get_blood_dna_list(), victim.get_static_viruses()), MANTIS_SPURT_WAIT + shape[3])
	return jet

/// How far a spurt's drops lean sideways by the time they come down, in pixels. Thrown straight up or down the
/// screen out of a wound on one [side] of the body's middle line (-1 left as drawn, 1 right, 0 for no lean) they
/// would fly along the body, behind it or over it: they lean out to the wound's side and land clear of it.
/proc/mantis_spurt_lean(weak, spurt_dir, side)
	if(spurt_dir != NORTH && spurt_dir != SOUTH)
		return 0
	return side * (weak ? 4 : 9)

/// Where the middle of a spurt's drops comes down, from the middle of the tile the wound is on: list(x, y).
/// [point] is the wound (mantis_artery_point()), on the [side] of the body mantis_spurt_lean() takes.
/proc/mantis_spurt_spot(list/point, height, weak, spurt_dir, side = 0)
	var/list/shape = mantis_spurt_shape(height, weak)
	var/out_x = (spurt_dir & EAST) ? 1 : ((spurt_dir & WEST) ? -1 : 0)
	var/out_y = (spurt_dir & NORTH) ? 1 : ((spurt_dir & SOUTH) ? -1 : 0)
	var/reach = shape[1] * ((out_x && out_y) ? 0.7071 : 1)
	return list(point[1] + round(out_x * reach, 1) + mantis_spurt_lean(weak, spurt_dir, side), point[2] - shape[2] + round(out_y * reach, 1))

/// The tile a spurt's drops come down on, or null if there is none.
/proc/mantis_spurt_turf(mob/living/victim, list/point, height, weak, spurt_dir, side = 0)
	var/list/spot = mantis_spurt_spot(point, height, weak, spurt_dir, side)
	return locate(victim.x + round(spot[1] / ICON_SIZE_X, 1), victim.y + round(spot[2] / ICON_SIZE_Y, 1), victim.z)

/**
 * The spots a spurt of arterial blood leaves where its drops come down ("artery_drops_[...]", the last frame
 * of the spurt's own art, eight ways), and the drips at the feet off the run down the body ("artery_feet_[...]").
 * Its own kind of blood, not one of the sprays: thin, and a tile keeps only a few.
 *
 * It is one of tg's drops of blood on purpose, with tg's own list of drop pictures. tg's bleeding feeds its
 * drips to the first wet blood it finds on a tile unless that blood is drops, so someone bleeding over spots
 * that were plain blood would never stand in a pool. Onto drops it lets its own drips fall as ever, and turns
 * the lot into its pool in the end.
 */
/obj/effect/decal/cleanable/blood/drip/mantis_drops
	name = "blood drops"
	icon = MANTIS_GORE_ICON
	icon_state = "artery_drops_mid"
	mergeable_decal = FALSE
	// Thin enough that walking through it does not leave footprints.
	bloodiness = 10
	drying_time = 3 MINUTES
	beauty = -15
	base_name = null
	base_suffix = "drops"
	/// How many drips off a run have landed here, if this is the pool at someone's feet.
	var/feet_drips = 0

// Too thin to dive into.
/obj/effect/decal/cleanable/blood/drip/mantis_drops/can_bloodcrawl_in()
	return FALSE

/// A spurt's drops come down on [land]: its spots are laid, [offset_x] and [offset_y] pixels from the tile's
/// middle. Wet spots already there from the same beat of the same wound are only freshened, and a tile holds
/// no more than a few. Returns the spots.
/proc/mantis_spurt_land(turf/land, state, spurt_dir, offset_x, offset_y, list/blood_dna, list/viruses)
	if(!isturf(land) || !length(blood_dna) || hv_blood_spray_blocked(land) || isgroundlessturf(land) || !land.has_gravity())
		return null
	var/laid = 0
	for(var/obj/effect/decal/cleanable/blood/drip/mantis_drops/wet in land)
		if(wet.dried || wet.feet_drips || QDELETED(wet))
			continue
		laid++
		if(laid >= 4 || (wet.icon_state == state && wet.dir == spurt_dir && wet.pixel_x == offset_x && wet.pixel_y == offset_y))
			wet.add_blood_DNA(blood_dna, viruses)
			return wet
	var/obj/effect/decal/cleanable/blood/drip/mantis_drops/drops = new(land, viruses, blood_dna)
	if(QDELETED(drops))
		return null
	drops.icon_state = state
	drops.setDir(spurt_dir)
	drops.pixel_x = offset_x
	drops.pixel_y = offset_y
	return drops

/// The blood run down a body from a torn artery (mantis_artery_run_fx()).
/obj/effect/abstract/cyberware_anim/mantis_run
	icon = MANTIS_GORE_ICON
	layer = MANTIS_ANIM_TOP_LAYER
	/// The part it runs from.
	var/zone

/// Run its length: a still picture from here on, whichever way the body turns.
/obj/effect/abstract/cyberware_anim/mantis_run/proc/ran()
	icon_state = "artery_ran_[zone]"

/// A drip falls off the run's lower end and lands at the feet.
/obj/effect/abstract/cyberware_anim/mantis_run/proc/drip()
	var/mob/living/body = bearer
	if(QDELETED(src) || !istype(body) || QDELETED(body) || body.body_position == LYING_DOWN)
		return
	mantis_feet_drip(body, zone)

/// Where the run down a body from [zone] comes to the sole of a body facing [facing], in pixels across from the
/// middle of its tile: the lower end of the art's own run ("artery_ran_[zone]"). Where the part is on the body's
/// far side and the run can't be seen, the sole the blood comes down to all the same.
/proc/mantis_artery_run_foot(zone, facing)
	var/static/list/feet = list(
		BODY_ZONE_HEAD = list("[SOUTH]" = 0, "[NORTH]" = 0, "[EAST]" = 3, "[WEST]" = -2),
		BODY_ZONE_CHEST = list("[SOUTH]" = 1, "[NORTH]" = 0, "[EAST]" = 3, "[WEST]" = -2),
		BODY_ZONE_L_ARM = list("[SOUTH]" = 5, "[NORTH]" = -7, "[EAST]" = -1, "[WEST]" = 2),
		BODY_ZONE_R_ARM = list("[SOUTH]" = -6, "[NORTH]" = 5, "[EAST]" = -1, "[WEST]" = 2),
		BODY_ZONE_L_LEG = list("[SOUTH]" = 4, "[NORTH]" = -2, "[EAST]" = 0, "[WEST]" = 2),
		BODY_ZONE_R_LEG = list("[SOUTH]" = -3, "[NORTH]" = 2, "[EAST]" = 0, "[WEST]" = 2),
	)
	var/list/by_facing = feet[zone]
	return by_facing?["[facing]"]

/**
 * A drip off the blood run down [victim] from [zone] lands at the feet, two pixels under the sole the run comes
 * down to: a spot there ("artery_feet_1"), wider with the next, a small pool with the third. Nothing where no
 * blood would lie. Returns the spot.
 */
/proc/mantis_feet_drip(mob/living/victim, zone)
	if(QDELETED(victim) || !isturf(victim.loc) || victim.can_bleed(BLOOD_COVER_TURFS) != BLEED_SPLATTER)
		return null
	var/foot = mantis_artery_run_foot(zone, victim.dir)
	if(isnull(foot))
		return null
	// The sole is the body picture's lowest row, 15 pixels under the middle of the tile, wherever the body is drawn.
	var/matrix/shape = victim.transform
	var/drip_x = round(shape.a * foot + shape.b * -15 + shape.c, 1) + victim.pixel_x + victim.pixel_w
	var/drip_y = round(shape.d * foot + shape.e * -15 + shape.f, 1) + victim.pixel_y + victim.pixel_z - 2
	var/turf/land = locate(victim.x + round(drip_x / ICON_SIZE_X, 1), victim.y + round(drip_y / ICON_SIZE_Y, 1), victim.z)
	if(!isturf(land) || isgroundlessturf(land) || !land.has_gravity() || (land != victim.loc && hv_blood_spray_blocked(land)))
		return null
	var/offset_x = drip_x - (land.x - victim.x) * ICON_SIZE_X
	var/offset_y = drip_y - (land.y - victim.y) * ICON_SIZE_Y
	for(var/obj/effect/decal/cleanable/blood/drip/mantis_drops/wet in land)
		if(!wet.feet_drips || wet.dried || QDELETED(wet) || wet.pixel_x != offset_x || wet.pixel_y != offset_y)
			continue
		wet.feet_drips = min(wet.feet_drips + 1, 3)
		wet.icon_state = "artery_feet_[wet.feet_drips]"
		wet.add_blood_DNA(victim.get_blood_dna_list(), victim.get_static_viruses())
		return wet
	var/obj/effect/decal/cleanable/blood/drip/mantis_drops/pool = new(land, victim.get_static_viruses(), victim.get_blood_dna_list())
	if(QDELETED(pool))
		return null
	pool.feet_drips = 1
	pool.icon_state = "artery_feet_1"
	pool.pixel_x = offset_x
	pool.pixel_y = offset_y
	return pool

/**
 * The blood of a torn artery runs down [victim]'s body from the wound on [zone] to the feet: a thin broken
 * line that grows over half a second and stays ("artery_run_[zone]", then "artery_ran_[zone]", drawn for the
 * body's four facings; nothing where the part is on the body's far side). Part of the body: it turns and lies
 * down with it. It lasts as long as [torn], the wound. Only on someone upright: lying down, the blood goes
 * straight to the floor. Returns the picture.
 */
/proc/mantis_artery_run_fx(mob/living/victim, zone, datum/wound/torn)
	if(QDELETED(victim) || QDELETED(torn) || victim.body_position == LYING_DOWN)
		return null
	if(!icon_exists(MANTIS_GORE_ICON, "artery_run_[zone]"))
		return null
	var/obj/effect/abstract/cyberware_anim/mantis_run/run = new(null)
	run.bearer = victim
	run.zone = zone
	run.icon_state = "artery_run_[zone]"
	run.appearance_flags |= RESET_COLOR
	run.color = victim.get_blood_dna_color() || BLOOD_COLOR_RED
	run.RegisterSignal(victim, COMSIG_QDELETING, TYPE_PROC_REF(/obj/effect/abstract/cyberware_anim, on_bearer_deleted))
	// The wound closing, or going with its limb, takes the run with it.
	run.RegisterSignal(torn, COMSIG_QDELETING, TYPE_PROC_REF(/obj/effect/abstract/cyberware_anim, on_bearer_deleted))
	victim.vis_contents += run
	addtimer(CALLBACK(run, TYPE_PROC_REF(/obj/effect/abstract/cyberware_anim/mantis_run, ran)), 0.8 SECONDS)
	// It comes to the feet, and three drips fall off it there.
	for(var/wait in list(0.6 SECONDS, 0.95 SECONDS, 1.25 SECONDS))
		addtimer(CALLBACK(run, TYPE_PROC_REF(/obj/effect/abstract/cyberware_anim/mantis_run, drip)), wait)
	return run

/// A Scorch cut: a white-hot seam across the limb that cools to char.
/proc/mantis_scorch_seam_fx(mob/living/carbon/victim, obj/item/bodypart/limb)
	var/state = "scorch_gash_[limb.body_zone]"
	if(!icon_exists(MANTIS_GORE_ICON, state))
		return null
	return cyberware_anim_play(victim, MANTIS_GORE_ICON, state, MANTIS_ANIM_BLADE_LAYER, 1.5 SECONDS, glow = TRUE)

/// The X-slash lands: a flash of light off the blades. The two crossed strokes are drawn with the blades' own
/// swings (mantis_xslash_cross(), mantis_swing.dm).
/proc/mantis_xslash_fx(mob/living/user, mob/living/victim, impact_state)
	if(QDELETED(victim))
		return
	cyberware_flash_fx(victim, 0.15 SECONDS)
	victim.mob_light(2, 1.5, impact_state == "impact_scorch" ? LIGHT_COLOR_FIRE : "#bfe6ff", 0.2 SECONDS)

// =========================================================================
// IMPALE, SCISSOR, CROUCH
// =========================================================================

/// The way [looker] turns to look at [seen], as face_atom() picks it, whatever state [looker] is in.
/proc/mantis_face_dir(atom/looker, atom/seen)
	var/dx = seen.x - looker.x
	var/dy = seen.y - looker.y
	if(abs(dx) < abs(dy))
		return dy > 0 ? NORTH : SOUTH
	return dx > 0 ? EAST : WEST

/// How [victim] lies, for the scissor's art: "stand", or "lie90"/"lie270" by the way tg has turned them.
/proc/mantis_scissor_posture(mob/living/victim)
	if(victim.body_position != LYING_DOWN || !victim.rotate_on_lying)
		return "stand"
	return victim.lying_angle == 270 ? "lie270" : "lie90"

/// Someone under the raised blades shudders: small sideways jolts, relative, ending where they began.
/proc/mantis_struggle_fx(mob/living/victim, duration)
	if(QDELETED(victim))
		return
	var/static/list/jolts = list(1, -1, 1, 0, -1, 1, -1, 0)
	var/step_time = duration / length(jolts)
	var/offset = 0
	for(var/i in 1 to length(jolts))
		var/shift = jolts[i] - offset
		offset = jolts[i]
		if(i == 1)
			animate(victim, pixel_w = shift, time = step_time, flags = ANIMATION_RELATIVE|ANIMATION_PARALLEL)
		else
			animate(pixel_w = shift, time = step_time, flags = ANIMATION_RELATIVE)

/// The crouched blade's glow, brightening over the charge. Gone with the crouch.
/proc/mantis_coil_glow_fx(mob/living/bearer, obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade)
	var/state = "[blade.base_icon_state]_coil_glow_[blade.hand_side()]"
	if(!icon_exists(MANTIS_GORE_ICON, state))
		return null
	var/obj/effect/abstract/cyberware_anim/glow = cyberware_anim_play(bearer, MANTIS_GORE_ICON, state, MANTIS_ANIM_BLADE_LAYER, MANTIS_CHARGE_MAX_HOLD + 1 SECONDS, glow = TRUE)
	if(!glow)
		return null
	// Side on, the far blade's glow stays behind the near blade.
	glow.sort_as_arm(blade.hand_side())
	glow.alpha = 0
	animate(glow, alpha = 255, time = MANTIS_CHARGE_FULL - MANTIS_CHARGE_TAP)
	return glow

#undef MANTIS_LEAP_GLIDE
#undef MANTIS_SPURT_WAIT
