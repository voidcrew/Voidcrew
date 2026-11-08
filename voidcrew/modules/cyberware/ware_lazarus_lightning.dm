// =========================================================================
// LAZARUS NODE: THE CHARGE, AS EVERYONE AROUND SEES IT
// =========================================================================

/// The red of the charge, its light and its bolts
#define LAZARUS_FX_COLOR "#ff2a2a"
/// The charge's look outlasts the node's own windup by this much at most: the jolt ends it, and it ends itself if the jolt never comes
#define LAZARUS_FX_GRACE (0.5 SECONDS)
/// Red bolts jump off the body this often while it charges, more of them each time...
#define LAZARUS_FX_ARC_EVERY (0.2 SECONDS)
/// ...up to this many at once...
#define LAZARUS_FX_ARC_MOST 4
/// ...to tiles and things this far away
#define LAZARUS_FX_ARC_RANGE 3
/// The jolt throws this many bolts out at once, this far
#define LAZARUS_FX_BURST_BOLTS 8
#define LAZARUS_FX_BURST_RANGE 4
/// The filters it puts on the bearer: the outline and the halo while it charges, the glow fading after the jolt
#define LAZARUS_FX_OUTLINE "lazarus_charge_outline"
#define LAZARUS_FX_HALO "lazarus_charge_halo"
#define LAZARUS_FX_AFTERGLOW "lazarus_jolt_afterglow"

/**
 * # The Lazarus charge's red lightning
 *
 * The node (ware_military_body.dm) spends its windup between its bearer going down and the jolt. Through
 * that second red lightning crawls over the body, a red outline and halo flicker brighter as it fills,
 * red bolts jump off them onto the floor, walls and things around, more of them each beat, and a red
 * light comes up. The jolt throws a burst of red lightning every way (cyberware_lazarus_burst()).
 *
 * A picture only: nothing is hurt, lit on fire or switched off by any bolt, and the node's own rules (when
 * it fires, the heal, the cooldown, the kill window) are the node's. The node already announces the charge
 * with a line and a whine; this is the same news, louder. Started by the node's windup, it ends the moment
 * the node stops charging (it jolts, an EMP or a brownout cuts it, it comes out) or the bearer dies.
 */
/datum/status_effect/cyberware_lazarus_charge
	id = "cyberware_lazarus_charge"
	duration = 1 SECONDS
	tick_interval = LAZARUS_FX_ARC_EVERY
	status_type = STATUS_EFFECT_REPLACE
	alert_type = null
	/// Weakref to the node charging
	var/datum/weakref/node_ref
	/// How long the node's windup is
	var/charge_time = 1 SECONDS
	/// Rounds of bolts thrown so far
	var/rounds = 0
	/// The lightning crawling over the body, and its glow in the dark
	var/list/arcs
	/// The red light it gives off
	var/obj/effect/dummy/lighting_obj/moblight/glow
	/// Where its bolts may land (cyberware_lazarus_arc_candidates()), looked up from `arc_from` and kept until the body moves
	var/list/arc_floors
	var/list/arc_things
	var/turf/arc_from

/datum/status_effect/cyberware_lazarus_charge/on_creation(mob/living/new_owner, obj/item/organ/node, new_charge_time = 1 SECONDS)
	node_ref = WEAKREF(node)
	charge_time = max(new_charge_time, 0.1 SECONDS)
	duration = charge_time + LAZARUS_FX_GRACE
	return ..()

/datum/status_effect/cyberware_lazarus_charge/on_apply()
	if(owner.stat == DEAD)
		return FALSE
	arcs = cyberware_lazarus_body_arcs(owner)
	owner.add_overlay(arcs)
	// A red outline and a red halo, flickering brighter as it fills: how close it is, at a glance.
	// Colour animates cleanly; size doesn't (chromatic dermis, ware_street.dm).
	owner.add_filter(LAZARUS_FX_HALO, 2, drop_shadow_filter(0, 0, 4, 0, "#ff000000"))
	owner.add_filter(LAZARUS_FX_OUTLINE, 3, outline_filter(1, "#ff2a2a40"))
	cyberware_lazarus_build_glow(owner.get_filter(LAZARUS_FX_HALO), list("#ff000040", "#ff000020", "#ff000070", "#ff000050", "#ff0000a0", "#ff000080", "#ff1010d0", "#ff2020c0"), charge_time)
	cyberware_lazarus_build_glow(owner.get_filter(LAZARUS_FX_OUTLINE), list("#ff2a2a80", "#ff2a2a50", "#ff2a2ab0", "#ff2a2a80", "#ff4040e0", "#ff3030b0", "#ff8080ff", "#ffb0b0ff"), charge_time)
	glow = owner.mob_light(3, 1, LAZARUS_FX_COLOR)
	RegisterSignal(owner, COMSIG_LIVING_DEATH, PROC_REF(on_owner_death))
	playsound(owner, 'sound/effects/magic/lightning_chargeup.ogg', 60, TRUE)
	throw_bolts()
	return TRUE

/datum/status_effect/cyberware_lazarus_charge/tick(seconds_between_ticks)
	if(!still_charging())
		qdel(src)
		return
	throw_bolts()

/// Whether its node is still charging in its bearer
/datum/status_effect/cyberware_lazarus_charge/proc/still_charging()
	var/obj/item/organ/cyberimp/cyberware/lazarus/node = node_ref?.resolve()
	if(QDELETED(node) || node.owner != owner || owner.stat == DEAD)
		return FALSE
	return node.jolting

/// One round of red bolts off the body, more each round, and the light brighter
/datum/status_effect/cyberware_lazarus_charge/proc/throw_bolts()
	rounds++
	var/turf/here = get_turf(owner)
	if(!here)
		return
	if(here != arc_from)
		arc_from = here
		var/list/candidates = cyberware_lazarus_arc_candidates(owner, LAZARUS_FX_ARC_RANGE)
		arc_floors = candidates[1]
		arc_things = candidates[2]
	for(var/atom/struck as anything in cyberware_lazarus_pick_arcs(arc_floors, arc_things, min(1 + round(rounds / 2), LAZARUS_FX_ARC_MOST)))
		cyberware_lazarus_bolt(owner, struck, 0.2 SECONDS)
	glow?.set_light_power(min(1 + rounds * 0.4, 3))
	playsound(owner, SFX_SPARKS, min(25 + rounds * 8, 70), TRUE, SILENCED_SOUND_EXTRARANGE)

/datum/status_effect/cyberware_lazarus_charge/proc/on_owner_death(datum/source, gibbed)
	SIGNAL_HANDLER
	qdel(src)

/datum/status_effect/cyberware_lazarus_charge/on_remove()
	UnregisterSignal(owner, COMSIG_LIVING_DEATH)
	if(arcs)
		owner.cut_overlay(arcs)
	arcs = null
	owner.remove_filter(list(LAZARUS_FX_OUTLINE, LAZARUS_FX_HALO))
	QDEL_NULL(glow)
	arc_floors = null
	arc_things = null
	arc_from = null

/datum/status_effect/cyberware_lazarus_charge/Destroy()
	QDEL_NULL(glow)
	return ..()

/**
 * The jolt's burst, when the node stands `patient` up: red bolts thrown out every way, a red ring, a red
 * flash, and the body glowing red a moment longer. Pictures only.
 */
/proc/cyberware_lazarus_burst(mob/living/patient)
	var/turf/here = get_turf(patient)
	if(!here)
		return
	playsound(patient, 'sound/effects/magic/lightningbolt.ogg', 80, TRUE)
	for(var/atom/struck as anything in cyberware_lazarus_arc_targets(patient, LAZARUS_FX_BURST_RANGE, LAZARUS_FX_BURST_BOLTS))
		cyberware_lazarus_bolt(patient, struck, 0.5 SECONDS)
	var/obj/effect/temp_visual/emp/pulse/ring = new(here)
	ring.color = cyberware_lazarus_red()
	ring.transform = matrix().Scale(3)
	var/obj/effect/temp_visual/electricity/crackle = new(here)
	crackle.color = cyberware_lazarus_red()
	crackle.transform = matrix().Scale(2)
	new /obj/effect/dummy/lighting_obj(here, 5, 4, LAZARUS_FX_COLOR, 0.5 SECONDS)
	patient.add_filter(LAZARUS_FX_AFTERGLOW, 3, outline_filter(1, "#ffb0b0ff"))
	var/afterglow = patient.get_filter(LAZARUS_FX_AFTERGLOW)
	if(afterglow)
		animate(afterglow, color = "#ff000000", time = 1 SECONDS)
	addtimer(CALLBACK(patient, TYPE_PROC_REF(/datum, remove_filter), LAZARUS_FX_AFTERGLOW), 1 SECONDS, TIMER_DELETE_ME)

/// A colour matrix turning any of tg's lightning art (yellow, blue or white) a vicious red, its brightest parts nearly pink
/proc/cyberware_lazarus_red()
	return list(0.55, 0.1, 0.1, 0.55, 0.1, 0.1, 0.55, 0.1, 0.1, 0, 0, 0)

/**
 * The red lightning that crawls over a body while its node charges: a thick bolt of tg's lightning
 * through it, two layers of its arcs (one a little larger than the body, so it crawls off the edges), and
 * their glow in the dark when `body` is given. For the overlay and the renders.
 */
/proc/cyberware_lazarus_body_arcs(atom/body)
	. = list()
	var/core_state = "lightning[rand(1, 12)]"
	var/mutable_appearance/core = mutable_appearance('icons/effects/beam.dmi', core_state, ABOVE_MOB_LAYER)
	core.color = cyberware_lazarus_red()
	. += core
	var/mutable_appearance/inner = mutable_appearance('icons/effects/effects.dmi', "electricity", ABOVE_MOB_LAYER)
	inner.color = cyberware_lazarus_red()
	. += inner
	var/mutable_appearance/outer = mutable_appearance('icons/effects/effects.dmi', "electricity3", ABOVE_MOB_LAYER)
	outer.color = cyberware_lazarus_red()
	outer.transform = matrix().Scale(1.3)
	. += outer
	if(!body)
		return
	. += emissive_appearance('icons/effects/beam.dmi', core_state, body)
	. += emissive_appearance('icons/effects/effects.dmi', "electricity", body)
	var/mutable_appearance/outer_glow = emissive_appearance('icons/effects/effects.dmi', "electricity3", body)
	outer_glow.transform = matrix().Scale(1.3)
	. += outer_glow

/// Animates a glow filter (`glow`, may be null) through `steps` (colours with alpha) over `time`: a flicker that builds
/proc/cyberware_lazarus_build_glow(glow, list/steps, time)
	if(!glow || !length(steps))
		return
	var/step_time = time / length(steps)
	animate(glow, color = steps[1], time = step_time)
	for(var/i in 2 to length(steps))
		animate(color = steps[i], time = step_time)

/// Up to `count` places around `source`, in sight within `range`, for bolts off it to land (cyberware_lazarus_arc_candidates()). May be fewer, or none.
/proc/cyberware_lazarus_arc_targets(atom/source, range, count)
	var/list/candidates = cyberware_lazarus_arc_candidates(source, range)
	return cyberware_lazarus_pick_arcs(candidates[1], candidates[2], count)

/**
 * Where bolts off `source` may land, in sight within `range`, as list(floor tiles, solid things): a
 * wall, or the first solid thing on a floor tile. Never a person: the bolts are pictures and must not
 * look like they hurt anyone. Walks every tile in range once, so a charge looks it up once and keeps it.
 */
/proc/cyberware_lazarus_arc_candidates(atom/source, range)
	var/list/floors = list()
	var/list/things = list()
	var/turf/here = get_turf(source)
	if(!here)
		return list(floors, things)
	for(var/turf/spot as anything in RANGE_TURFS(range, here))
		if(spot == here || !can_see(here, spot, range))
			continue
		if(spot.density)
			things += spot
			continue
		floors += spot
		for(var/obj/thing in spot)
			if(thing.density && !thing.invisibility && !iseffect(thing))
				things += thing
				break
	return list(floors, things)

/// Up to `count` landing spots out of `floors` and `things`: a solid thing about half the time, else a floor. Anything gone since it was looked up is skipped.
/proc/cyberware_lazarus_pick_arcs(list/floors, list/things, count)
	. = list()
	for(var/i in 1 to count)
		var/atom/struck
		if(length(things) && (prob(50) || !length(floors)))
			struck = pick(things)
		else if(length(floors))
			struck = pick(floors)
		if(!QDELETED(struck))
			. += struck

/// One red bolt from `from` to `struck`, crackling where it lands, gone after `time`. A picture only.
/proc/cyberware_lazarus_bolt(atom/from, atom/struck, time)
	var/state = prob(25) ? "red_lightning" : "lightning[rand(1, 12)]"
	from.Beam(struck, icon_state = state, time = time, beam_color = LAZARUS_FX_COLOR)
	var/turf/landing = get_turf(struck)
	if(landing)
		var/obj/effect/temp_visual/electricity/crackle = new(landing)
		crackle.color = cyberware_lazarus_red()

#undef LAZARUS_FX_COLOR
#undef LAZARUS_FX_GRACE
#undef LAZARUS_FX_ARC_EVERY
#undef LAZARUS_FX_ARC_MOST
#undef LAZARUS_FX_ARC_RANGE
#undef LAZARUS_FX_BURST_BOLTS
#undef LAZARUS_FX_BURST_RANGE
#undef LAZARUS_FX_OUTLINE
#undef LAZARUS_FX_HALO
#undef LAZARUS_FX_AFTERGLOW
