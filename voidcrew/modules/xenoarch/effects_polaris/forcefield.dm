// Artifact effect: forcefield.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/forcefield.dm, also in
// VOREStation (9335d66b9fdf). Voidcrew: a ring of short-lived force walls two tiles out (three for a
// strong one) instead of Polaris' permanent sixteen-wall box. A burst or a touch raises it for a
// few seconds; a field holds it up only while the field runs and drops it the moment it rests.
// Walls skip tiles already blocked (walls, closed doors, machines) and fade in, so nobody is
// sealed into a wall. Everything it raised goes when it sleeps or is destroyed. Not harvestable.

/// How long a field keeps its ring after its last run before letting it drop
#define ARTIFACT_FORCEFIELD_AURA_GRACE (3 SECONDS)

/datum/artifact_effect/forcefield
	label_name = "Force walls"
	log_name = "Forcefield"
	tier = ARTIFACT_TIER_UNCOMMON
	harvestable = FALSE
	possible_kinds = list(ARTIFACT_ENERGY_PARTICLE, ARTIFACT_ENERGY_BLUESPACE)
	/// Tiles from the artifact to the ring
	var/ring_radius = 2
	/// How long a burst or touch keeps the ring up
	var/ring_time = 10 SECONDS
	/// The walls it raised that still stand
	var/list/obj/effect/forcefield/artifact/walls = list()
	/// world.time a field last held the ring up
	var/last_held = 0

/datum/artifact_effect/forcefield/setup()
	switch(strength)
		if(ARTIFACT_STRENGTH_LARGE)
			ring_radius = 3
			ring_time = 15 SECONDS
		if(ARTIFACT_STRENGTH_MEDIUM)
			ring_time = 12 SECONDS
		else
			ring_time = 8 SECONDS
	// A touch needs a good part of the store, so a hand can't keep the ring up for free.
	touch_cost = max(touch_cost, round(maximum_charges / 2))

/datum/artifact_effect/forcefield/copy_settings_to(datum/artifact_effect/forcefield/copy)
	copy.ring_radius = ring_radius
	copy.ring_time = ring_time

/datum/artifact_effect/forcefield/Destroy(force)
	drop_ring()
	return ..()

/datum/artifact_effect/forcefield/on_deactivate()
	drop_ring()

/datum/artifact_effect/forcefield/tick(seconds_per_tick)
	. = ..()
	if(release_method == ARTIFACT_RELEASE_AURA && length(walls) && world.time > last_held + ARTIFACT_FORCEFIELD_AURA_GRACE)
		drop_ring()

/datum/artifact_effect/forcefield/do_effect_touch(mob/living/user)
	to_chat(user, span_notice("The air around [holder] goes taut as a drumskin."))
	raise_ring(ring_time)

/datum/artifact_effect/forcefield/do_effect_aura(seconds_per_tick)
	last_held = world.time
	if(!length(walls))
		// Long enough to outlast any one run; the field drops it itself when it rests.
		raise_ring(2 MINUTES)

/datum/artifact_effect/forcefield/do_effect_pulse(power)
	raise_ring(ring_time)

/datum/artifact_effect/forcefield/do_effect_destroy()
	return

/// Raises a fresh ring around the artifact. Returns how many walls went up.
/datum/artifact_effect/forcefield/proc/raise_ring(duration)
	drop_ring()
	var/turf/center = source_turf()
	if(!center)
		return 0
	var/tint = artifact_energy_kind(energy_kind).color
	for(var/turf/open/spot in RANGE_TURFS(ring_radius, center))
		if(max(abs(spot.x - center.x), abs(spot.y - center.y)) != ring_radius)
			continue
		if(isspaceturf(spot) || isgroundlessturf(spot) || spot.is_blocked_turf(exclude_mobs = TRUE))
			continue
		var/obj/effect/forcefield/artifact/wall = new(spot, duration, tint)
		walls += wall
		RegisterSignal(wall, COMSIG_QDELETING, PROC_REF(wall_gone))
	if(length(walls))
		playsound(center, 'sound/effects/magic/forcewall.ogg', 45, TRUE)
		center.visible_message(span_warning("Walls of rippling light spring up around [holder]!"))
	return length(walls)

/// Takes down every wall it raised.
/datum/artifact_effect/forcefield/proc/drop_ring()
	if(!length(walls))
		return
	for(var/obj/effect/forcefield/artifact/wall in walls)
		UnregisterSignal(wall, COMSIG_QDELETING)
		wall.fade_out()
	walls.Cut()

/// A wall timed out or was deleted: forget it.
/datum/artifact_effect/forcefield/proc/wall_gone(datum/source)
	SIGNAL_HANDLER
	walls -= source

/// One pane of the ring.
/obj/effect/forcefield/artifact
	name = "shimmering wall"
	desc = "A pane of rippling light, hard as glass."
	icon_state = "shield-greyscale"
	alpha = 0
	initial_duration = 10 SECONDS

/obj/effect/forcefield/artifact/Initialize(mapload, duration, tint)
	if(isnum(duration))
		initial_duration = duration
	. = ..()
	if(tint)
		color = tint
	animate(src, alpha = 190, time = 0.4 SECONDS)

/// Fades and goes, rather than blinking out.
/obj/effect/forcefield/artifact/proc/fade_out()
	if(QDELETED(src))
		return
	set_density(FALSE)
	animate(src, alpha = 0, time = 0.3 SECONDS)
	QDEL_IN(src, 0.3 SECONDS)

#undef ARTIFACT_FORCEFIELD_AURA_GRACE
