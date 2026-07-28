/**
 * # Hoarfrost Matriarch - the kit
 *
 * Three abilities, each asking a different spatial question:
 *
 * - **Rimebreath** - *sidestep the line.* A telegraphed five-tile cone in her
 *   facing. Step perpendicular or eat twenty burn and four seconds of heavy
 *   chill, and mind the rime it leaves in the lane.
 * - **Killing Cold** - *run toward the thing killing you.* She plants, roars,
 *   and everything more than two tiles away freezes. She is completely inert
 *   for the whole window and staggered afterwards, so committing to melee range
 *   is not just survival, it pays out. Locked out for six seconds after a
 *   Rimebreath so she can never chain "you are slowed" into "the floor is
 *   lethal" - a solo player physically could not cross the gap.
 * - **Avalanche** - *reposition, and lose your firing lane.* A gapped ring of
 *   destructible ice at radius three to four. Fragments the arena and cuts
 *   sightlines; the gaps are the whole point.
 *
 * At the Calving (see hoarfrost_matriarch.dm) Rimebreath doubles up at a 45
 * degree offset and Avalanche chains straight into Killing Cold, so the ring
 * walls off part of the safe zone you now have to reach.
 *
 * The Killing Cold field itself is NOT implemented here - it lives in
 * hoarfrost_objects.dm as [/obj/effect/hoarfrost_killing_zone], because the
 * Matriarch's Heart deployable spawns exactly the same object. One code path,
 * two callers: retune the field there and the loot drop retunes with it.
 */

// =========================================================================
// RIMEBREATH
// =========================================================================

/**
 * Her bread and butter. Subtyped off the ice whelp's breath so we inherit the
 * forecast overlay, the line walker and the turf burn, and overridden into a
 * cone that leaves rime behind and chills instead of encasing.
 */
/datum/action/cooldown/mob_cooldown/fire_breath/ice/rimebreath
	name = "Rimebreath"
	desc = "Breathe a cone of frost five tiles long. Deals 20 burn and badly slows anything it hits for 4 seconds."
	// The fire_breath parent's button is a flame; hers is not.
	button_icon = 'voidcrew/icons/mob/actions/hoarfrost.dmi'
	button_icon_state = "rimebreath"
	cooldown_time = 12 SECONDS
	fire_range = 5
	fire_damage = 20
	fire_delay = 0.8 DECISECONDS
	forecast_delay = 1.2 SECONDS
	/// Angles either side of the aim point that the cone's lines follow.
	var/list/cone_angles = list(-30, 0, 30)
	/// How long the heavy chill from a direct hit lasts.
	var/chill_duration = 4 SECONDS
	/// Killing Cold stays locked out this long after a breath goes off.
	var/killing_cold_lockout = 6 SECONDS
	/// Degrees the Calving's follow-up cone is rotated from the first.
	var/second_cone_offset = 45
	/// Delay before the Calving's follow-up cone.
	var/second_cone_delay = 0.8 SECONDS
	/// Mobs already burned by the cone currently in flight. Shared across all
	/// three lines - they overlap near her mouth, and without this a point
	/// blank hit would triple-dip a hit that the spec prices at twenty burn.
	var/list/cone_hit_list

/datum/action/cooldown/mob_cooldown/fire_breath/ice/rimebreath/Activate(atom/target_atom)
	var/mob/living/basic/hoarfrost_matriarch/matriarch = owner
	if(istype(matriarch) && matriarch.inert)
		return FALSE
	return ..()

/datum/action/cooldown/mob_cooldown/fire_breath/ice/rimebreath/attack_sequence(atom/target)
	. = ..()
	var/mob/living/basic/hoarfrost_matriarch/matriarch = owner
	if(istype(matriarch))
		COOLDOWN_START(matriarch, rimebreath_lockout, killing_cold_lockout)
	announce_windup()
	telegraph_cone(target_turf)

/// Flavour for the windup. Overridden by the horn, which is a person breathing
/// through a piece of her rather than the thing itself.
/datum/action/cooldown/mob_cooldown/fire_breath/ice/rimebreath/proc/announce_windup()
	owner.visible_message(span_danger("[owner] rears back, frost boiling off [owner.p_their()] jaws!"))

/// Paint the turfs the cone is about to cover, for the length of the windup.
/datum/action/cooldown/mob_cooldown/fire_breath/ice/rimebreath/proc/telegraph_cone(turf/aim_at)
	if(isnull(aim_at) || QDELETED(owner))
		return
	var/turf/mouth = get_turf(owner)
	var/list/painted = list()
	for(var/offset in cone_angles)
		var/turf/edge = get_ranged_target_turf_direct(owner, aim_at, fire_range, offset)
		if(isnull(edge))
			continue
		for(var/turf/step_turf as anything in get_line(owner, edge))
			if(step_turf == mouth)
				continue
			if(step_turf.is_blocked_turf(exclude_mobs = TRUE))
				break
			painted |= step_turf
	for(var/turf/marked as anything in painted)
		new /obj/effect/temp_visual/hoarfrost_cone_telegraph(marked, forecast_delay)

/datum/action/cooldown/mob_cooldown/fire_breath/ice/rimebreath/breath_attack()
	var/turf/aim_at = target_turf
	target_turf = null
	if(isnull(aim_at))
		return
	breathe_cone(aim_at, 0)
	var/mob/living/basic/hoarfrost_matriarch/matriarch = owner
	if(istype(matriarch) && matriarch.calved)
		// The Calving's second cone. Punishes a lazy sidestep - you have to
		// commit to a direction rather than shuffling one tile and waiting.
		addtimer(CALLBACK(src, PROC_REF(breathe_cone), aim_at, second_cone_offset), second_cone_delay)

/// Breathe one full cone at the aim point, optionally rotated.
/datum/action/cooldown/mob_cooldown/fire_breath/ice/rimebreath/proc/breathe_cone(turf/aim_at, extra_offset = 0)
	if(QDELETED(owner) || owner.stat == DEAD || isnull(aim_at))
		return
	cone_hit_list = list(owner)
	owner.face_atom(aim_at)
	playsound(owner.loc, fire_sound, 200, TRUE)
	for(var/offset in cone_angles)
		fire_line(aim_at, offset + extra_offset)

/datum/action/cooldown/mob_cooldown/fire_breath/ice/rimebreath/progressive_fire_line(list/burn_turfs)
	if(QDELETED(owner) || owner.stat == DEAD)
		return
	// Identical to the parent except the hit list is the cone's, not this line's.
	var/list/hit_list = cone_hit_list || list(owner)
	for(var/turf/burning as anything in burn_turfs)
		if(burning.is_blocked_turf(exclude_mobs = TRUE))
			return
		burn_turf(burning, hit_list, owner)
		sleep(fire_delay)

/**
 * Deliberately does NOT call parent.
 *
 * `/fire_breath/burn_turf()` spawns an `/obj/effect/hotspot` and calls
 * `hotspot_expose()` on the turf - i.e. it lights an actual fire and dumps heat
 * into the air. The `/ice` subtype only drops `fire_temperature` to TCMB; it never
 * removes the hotspot, so an "ice" breath still scatters flame sprites across
 * every turf of the cone. Everything the parent does that we actually want (hit
 * the mobs, hurt the mechs) is reproduced here without lighting the glacier on
 * fire.
 */
/datum/action/cooldown/mob_cooldown/fire_breath/ice/rimebreath/burn_turf(turf/fire_turf, list/hit_list, mob/living/source)
	for(var/mob/living/frozen in fire_turf.contents)
		if(frozen in hit_list)
			continue
		hit_list |= frozen
		on_burn_mob(frozen, source)

	for(var/obj/vehicle/sealed/mecha/robotron in fire_turf.contents)
		if(robotron in hit_list)
			continue
		hit_list |= robotron
		robotron.take_damage(mech_damage, BURN, FIRE)

	if(isopenturf(fire_turf))
		new /obj/effect/hoarfrost_rime(fire_turf)
	return null

/datum/action/cooldown/mob_cooldown/fire_breath/ice/rimebreath/on_burn_mob(mob/living/barbecued, mob/living/source)
	if(hoarfrost_shrugs_off_cold(barbecued, spared_factions()))
		return
	barbecued.apply_damage(fire_damage, BURN, spread_damage = TRUE)
	barbecued.apply_status_effect(/datum/status_effect/hoarfrost_chill, chill_duration)
	to_chat(barbecued, span_userdanger("[source]'s breath scours the warmth straight out of you!"))

/// Who the breath spares: the caster's own side, but never "neutral", or a
/// player firing the rimebreath horn would spare every other player alive.
/datum/action/cooldown/mob_cooldown/fire_breath/ice/rimebreath/proc/spared_factions()
	var/mob/living/caster = owner
	if(!isliving(caster) || !length(caster.faction))
		return null
	return caster.faction - FACTION_NEUTRAL

/datum/action/cooldown/mob_cooldown/fire_breath/ice/rimebreath/Destroy()
	cone_hit_list = null
	return ..()

// =========================================================================
// KILLING COLD
// =========================================================================

/**
 * The signature. Nothing else in the codebase makes melee range the safe zone,
 * and nothing else punishes kiting - which is the exact habit that powerful
 * ranged gear teaches.
 *
 * Telegraph, bloom, recovery. She cannot move, melee or cast for the whole of
 * it: the demand is getting to her and holding, and the stagger at the end is
 * the payout for doing it.
 */
/datum/action/cooldown/mob_cooldown/hoarfrost_killing_cold
	name = "Killing Cold"
	desc = "Plant yourself and freeze everything more than two tiles away for 5 seconds, dealing 16 burn a second. You cannot move, attack or cast while it runs."
	button_icon = 'voidcrew/icons/mob/actions/hoarfrost.dmi'
	button_icon_state = "killing_cold"
	cooldown_time = 35 SECONDS
	click_to_activate = FALSE
	shared_cooldown = NONE
	/// How long she rears up before the field blooms.
	var/telegraph_time = 2.5 SECONDS
	/// How long she is staggered after the field drops. Your free damage window.
	var/recovery_time = 1.5 SECONDS

/datum/action/cooldown/mob_cooldown/hoarfrost_killing_cold/IsAvailable(feedback = FALSE)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/basic/hoarfrost_matriarch/matriarch = owner
	if(!istype(matriarch))
		return TRUE
	if(matriarch.inert)
		return FALSE
	// Fairness rule: never chain a heavy slow straight into a lethal floor.
	return COOLDOWN_FINISHED(matriarch, rimebreath_lockout)

/datum/action/cooldown/mob_cooldown/hoarfrost_killing_cold/Activate(atom/target)
	if(!isliving(owner))
		return FALSE
	StartCooldown()
	var/mob/living/caster = owner
	caster.visible_message(
		span_boldwarning("[caster] plants [caster.p_their()] feet and ROARS - the air starts freezing everywhere but right beside [caster.p_them()]!"),
		span_boldwarning("You plant yourself and let the cold out."),
	)
	playsound(caster, 'sound/mobs/non-humanoids/space_dragon/space_dragon_roar.ogg', 100, TRUE)
	caster.Shake(pixelshiftx = 1, pixelshifty = 1, duration = telegraph_time)
	hoarfrost_paint_zone(caster, telegraph_time)
	set_caster_inert(TRUE)
	addtimer(CALLBACK(src, PROC_REF(bloom)), telegraph_time)
	return TRUE

/// The windup is over: drop the shared field and time the recovery off it.
/datum/action/cooldown/mob_cooldown/hoarfrost_killing_cold/proc/bloom()
	var/mob/living/caster = owner
	if(QDELETED(caster) || caster.stat == DEAD)
		set_caster_inert(FALSE)
		return
	var/obj/effect/hoarfrost_killing_zone/field = new(get_turf(caster), caster)
	// Read the live window off the field rather than restating it, so retuning
	// the zone retunes how long she stands there for.
	addtimer(CALLBACK(src, PROC_REF(recover)), field.zone_duration)

/// Field's done. She sags - hit her.
/datum/action/cooldown/mob_cooldown/hoarfrost_killing_cold/proc/recover()
	var/mob/living/caster = owner
	if(!QDELETED(caster) && caster.stat != DEAD)
		caster.visible_message(span_boldwarning("[caster] sags, spent and wide open!"))
		caster.Shake(pixelshiftx = 2, pixelshifty = 0, duration = recovery_time)
	addtimer(CALLBACK(src, PROC_REF(release)), recovery_time)

/// Hand her back her legs and her kit.
/datum/action/cooldown/mob_cooldown/hoarfrost_killing_cold/proc/release()
	set_caster_inert(FALSE)

/// Freeze or unfreeze the caster for the duration of the cast.
/datum/action/cooldown/mob_cooldown/hoarfrost_killing_cold/proc/set_caster_inert(inert)
	var/mob/living/basic/hoarfrost_matriarch/matriarch = owner
	if(!istype(matriarch))
		return
	matriarch.set_inert(inert)

// =========================================================================
// AVALANCHE
// =========================================================================

/**
 * Calves a gapped ring of glacier ice down around her. This is what turns the
 * fight spatial instead of an open-field duel - and because the chunks are
 * destructible and melt on their own, it is never a hard trap.
 */
/datum/action/cooldown/mob_cooldown/hoarfrost_avalanche
	name = "Avalanche"
	desc = "Drop a ring of ice chunks three to four tiles out. They block movement and sight, and melt after 20 seconds."
	button_icon = 'voidcrew/icons/mob/actions/hoarfrost.dmi'
	button_icon_state = "avalanche"
	cooldown_time = 20 SECONDS
	click_to_activate = FALSE
	shared_cooldown = NONE
	/// How long the shadows hang before the ice arrives.
	var/telegraph_time = 1.5 SECONDS
	/// Nearest ring the chunks land on.
	var/inner_radius = 3
	/// Furthest ring the chunks land on.
	var/outer_radius = 4
	/// Fewest chunks a cast can drop.
	var/min_chunks = 6
	/// Most chunks a cast can drop.
	var/max_chunks = 10

/datum/action/cooldown/mob_cooldown/hoarfrost_avalanche/IsAvailable(feedback = FALSE)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/basic/hoarfrost_matriarch/matriarch = owner
	return !istype(matriarch) || !matriarch.inert

/datum/action/cooldown/mob_cooldown/hoarfrost_avalanche/Activate(atom/target)
	if(!isliving(owner))
		return FALSE
	var/list/landing_zone = pick_landing_turfs()
	if(!length(landing_zone))
		return FALSE
	StartCooldown()
	owner.visible_message(span_boldwarning("The ice overhead splits with a crack like a gunshot!"))
	playsound(owner, 'sound/effects/glass/glassbash.ogg', 90, TRUE)
	for(var/turf/marked as anything in landing_zone)
		new /obj/effect/temp_visual/shadow_telegraph/hoarfrost(marked, telegraph_time)
	addtimer(CALLBACK(src, PROC_REF(calve), landing_zone), telegraph_time)
	return TRUE

/// Roll the ring. Deliberately fewer chunks than there are turfs - the gaps are
/// the ability; a solid wall would be a hard trap rather than a repositioning
/// problem.
/datum/action/cooldown/mob_cooldown/hoarfrost_avalanche/proc/pick_landing_turfs()
	var/turf/centre = get_turf(owner)
	if(isnull(centre))
		return list()
	var/list/candidates = list()
	for(var/turf/open/candidate in RANGE_TURFS(outer_radius, centre))
		var/distance = get_dist(centre, candidate)
		if(distance < inner_radius || distance > outer_radius)
			continue
		if(candidate.is_blocked_turf(exclude_mobs = TRUE))
			continue
		candidates += candidate
	if(!length(candidates))
		return list()
	candidates = shuffle(candidates)
	var/wanted = min(rand(min_chunks, max_chunks), length(candidates))
	return candidates.Copy(1, wanted + 1)

/// The ice arrives.
/datum/action/cooldown/mob_cooldown/hoarfrost_avalanche/proc/calve(list/landing_zone)
	if(QDELETED(owner))
		return
	playsound(owner, 'sound/effects/meteorimpact.ogg', 90, TRUE)
	for(var/turf/landing as anything in landing_zone)
		if(QDELETED(landing) || landing.is_blocked_turf(exclude_mobs = TRUE))
			continue
		new /obj/structure/hoarfrost_ice_chunk(landing)
	var/mob/living/basic/hoarfrost_matriarch/matriarch = owner
	if(istype(matriarch))
		matriarch.on_avalanche_landed()

// =========================================================================
// THE CHILL
// =========================================================================

/// A direct Rimebreath hit. Heavy, short, and the reason you learn to sidestep.
/datum/status_effect/hoarfrost_chill
	id = "hoarfrost_chill"
	duration = 4 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_REFRESH
	alert_type = /atom/movable/screen/alert/status_effect/hoarfrost_chill
	/// Movespeed modifier applied for as long as we are up.
	var/slowdown_type = /datum/movespeed_modifier/hoarfrost_chill

/datum/status_effect/hoarfrost_chill/on_creation(mob/living/new_owner, set_duration)
	if(isnum(set_duration))
		duration = set_duration
	return ..()

/datum/status_effect/hoarfrost_chill/on_apply()
	owner.add_movespeed_modifier(slowdown_type)
	return TRUE

/datum/status_effect/hoarfrost_chill/on_remove()
	owner.remove_movespeed_modifier(slowdown_type)
	return ..()

/// Walking back through the rime she left in the lane. A tax, not a punishment.
/datum/status_effect/hoarfrost_chill/mild
	id = "hoarfrost_chill_mild"
	duration = 3 SECONDS
	alert_type = /atom/movable/screen/alert/status_effect/hoarfrost_chill/mild
	slowdown_type = /datum/movespeed_modifier/hoarfrost_chill/mild

/atom/movable/screen/alert/status_effect/hoarfrost_chill
	name = "Rimebitten"
	desc = "You have been flash-frozen to the bone. You are moving much slower until it wears off."
	icon_state = "cold3"

/atom/movable/screen/alert/status_effect/hoarfrost_chill/mild
	name = "Frostbitten"
	desc = "You are walking through rime. It is slowing you down."
	icon_state = "cold1"

/datum/movespeed_modifier/hoarfrost_chill
	multiplicative_slowdown = 2.5

/datum/movespeed_modifier/hoarfrost_chill/mild
	multiplicative_slowdown = 0.75
