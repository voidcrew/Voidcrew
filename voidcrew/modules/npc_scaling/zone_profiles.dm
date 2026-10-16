/**
 * Spawn contract: create a context BEFORE construction, use spawn_npc_in_zone(),
 * finish source-specific body/weapon/faction setup, then context.finalize().
 * Roles are "auto" (hostile gate + named boss types), "ordinary", "boss", or
 * "exempt". Explicit combat roles also cover setpieces with otherwise passive AI.
 * Never edit a context's source, zone or role after construction. Unresolved zones
 * resolve once against source_turf, never against a moving mob's current location.
 */
/datum/npc_spawn_context
	var/source_id
	var/source_type
	var/turf/source_turf
	var/zone_type
	var/role
	var/exempt = FALSE
	/// Carries a caller's finalization request across deferred map initialization.
	var/ready_to_finalize = FALSE
	/// Weak references include replacements; discarded precursors are skipped.
	var/list/bodies = list()
	var/datum/zone_resolver/resolver

/datum/npc_spawn_context/New(datum/source, zone_type, role = "auto", exempt = FALSE, turf/source_turf)
	var/atom/source_atom = isatom(source) ? source : null
	var/datum/npc_spawn_context/inherited = source_atom?.npc_spawn_context
	src.source_id = inherited ? inherited.source_id : REF(source)
	src.source_type = inherited ? inherited.source_type : source?.type
	src.source_turf = inherited ? inherited.source_turf : (source_turf || get_turf(source_atom))
	src.zone_type = isnull(zone_type) ? inherited?.zone_type : zone_type
	src.role = role
	src.exempt = exempt || role == "exempt" || source_atom?.npc_zone_exempt || inherited?.exempt
	if(isliving(source))
		var/mob/living/owner = source
		src.exempt ||= owner.is_npc_zone_exempt()
	if(isnull(src.zone_type))
		// Start after New returns: zone_resolver may invoke its callback synchronously.
		addtimer(CALLBACK(src, PROC_REF(resolve_zone)), 0)

/datum/npc_spawn_context/Destroy()
	QDEL_NULL(resolver)
	bodies = null
	source_turf = null
	return ..()

/datum/npc_spawn_context/proc/resolve_zone()
	if(!isnull(zone_type))
		return
	resolver = new /datum/zone_resolver(source_turf, CALLBACK(src, PROC_REF(on_zone_resolved)))
	// A synchronous callback runs before the constructor's result is assigned.
	if(!isnull(zone_type))
		resolver = null

/datum/npc_spawn_context/proc/on_zone_resolved(resolved_zone)
	resolver = null
	if(!isnull(zone_type))
		return
	zone_type = isnull(resolved_zone) ? ZONE_GREEN : resolved_zone
	for(var/datum/weakref/body_ref as anything in bodies)
		var/mob/living/body = body_ref.resolve()
		if(body?.npc_zone_ready)
			body.finalize_npc_zone()

/// Call after ALL source-specific setup, including on replacement bodies.
/datum/npc_spawn_context/proc/finalize()
	ready_to_finalize = TRUE
	for(var/datum/weakref/body_ref as anything in bodies)
		var/mob/living/body = body_ref.resolve()
		if(!QDELETED(body))
			body.finalize_npc_zone(src)

/atom
	/// Also carried by environmental parents so later children use the pinned source.
	var/datum/npc_spawn_context/npc_spawn_context
	/// Permanent ownership opt-out. Child contexts copy it even after a profile is removed.
	var/npc_zone_exempt = FALSE

/mob/living
	var/npc_zone_initialization_complete = FALSE
	var/npc_zone_ready = FALSE
	var/npc_zone_applied = FALSE
	var/npc_zone_role
	var/npc_zone_health_factor = 1
	var/npc_zone_damage_factor = 1
	var/npc_zone_original_max_health
	var/npc_zone_original_melee_lower
	var/npc_zone_original_melee_upper

/// Approved boss classification, including marker types that grant a boss role
/// to otherwise ordinary bodies. Other setpiece producers pass "boss" explicitly.
/proc/npc_zone_boss_type(candidate_type)
	// A lich's disposable images are registered minions, not additional bosses.
	if(ispath(candidate_type, /mob/living/basic/lich/mirror_image))
		return FALSE
	var/static/list/boss_types = list(
		/mob/living/simple_animal/hostile/megafauna,
		/mob/living/simple_animal/hostile/asteroid/elite,
		/mob/living/basic/boss,
		/mob/living/basic/trooper/pirate/faction/boss,
		/mob/living/basic/bounty_criminal/boss,
		/mob/living/basic/bounty_criminal/kingpin,
		/mob/living/basic/bounty_lair_boss,
		/mob/living/basic/lich,
		/mob/living/basic/trooper/pirate/faction/silverscale/captain,
		/mob/living/basic/trooper/pirate/faction/skeleton/captain,
		/mob/living/basic/trooper/pirate/faction/grey/captain,
		/mob/living/basic/trooper/pirate/faction/lustrous/captain,
		/mob/living/basic/trooper/pirate/faction/interdyne/captain,
		/mob/living/basic/trooper/pirate/faction/irs/captain,
		/mob/living/basic/trooper/pirate/faction/medieval/captain,
		/mob/living/simple_animal/hostile/asteroid/old_demon,
		/mob/living/basic/mining/wolf/alpha,
		/mob/living/simple_animal/hostile/asteroid/polarbear/warrior,
		/obj/effect/zone_mobs/bug/boss,
		/obj/effect/zone_mobs/cult/boss,
		/obj/effect/zone_mobs/pirate/boss,
		/obj/effect/zone_mobs/robot/boss,
		/obj/effect/zone_mobs/syndicate/boss,
		/obj/effect/zone_mobs/undead/boss,
		/obj/effect/zone_mobs/wildlife/boss,
	)
	for(var/boss_type in boss_types)
		if(ispath(candidate_type, boss_type))
			return TRUE
	return FALSE

/// Environmental auto gate: passive fauna and mobs without autonomous AI stay baseline.
/mob/living/proc/is_npc_zone_hostile()
	if(ishostile(src))
		return TRUE
	if(!isbasicmob(src) || !ai_controller)
		return FALSE
	if(combat_mode)
		return TRUE
	// Autonomous target acquisition does not depend on the pawn's combat stance.
	for(var/datum/ai_planning_subtree/simple_find_target/targeting in ai_controller.planning_subtrees)
		if(targeting.target_key == BB_BASIC_MOB_CURRENT_TARGET)
			return TRUE
	return FALSE

/mob/living/proc/is_npc_zone_exempt()
	return npc_zone_exempt || npc_spawn_context?.exempt || client || mind || (FACTION_NEUTRAL in faction)

/mob/living/proc/finalize_npc_zone(datum/npc_spawn_context/context)
	if(QDELETED(src))
		return
	if(!npc_spawn_context)
		npc_spawn_context = context
	context = npc_spawn_context
	if(!context)
		return
	context.bodies |= WEAKREF(src)
	npc_zone_ready = TRUE
	if(!npc_zone_initialization_complete)
		return
	if(is_npc_zone_exempt())
		exempt_npc_zone()
		return
	if(npc_zone_applied || isnull(context.zone_type))
		return
	if(!isbasicmob(src) && !isanimal(src))
		return
	// Named bosses (including the lich) need not start with combat mode enabled.
	if(context.role == "auto" && !is_npc_zone_hostile() && !npc_zone_boss_type(type))
		return
	npc_zone_role = (context.role == "boss" || npc_zone_boss_type(type)) ? "boss" : "ordinary"
	npc_zone_original_max_health = maxHealth
	npc_zone_original_melee_lower = melee_damage_lower
	npc_zone_original_melee_upper = melee_damage_upper
	switch(context.zone_type)
		if(ZONE_YELLOW)
			npc_zone_health_factor = npc_zone_role == "boss" ? 1.15 : 1.35
			npc_zone_damage_factor = npc_zone_role == "boss" ? 1.1 : 1.15
		if(ZONE_RED)
			npc_zone_health_factor = npc_zone_role == "boss" ? 1.3 : 1.8
			npc_zone_damage_factor = npc_zone_role == "boss" ? 1.2 : 1.35
	npc_zone_applied = TRUE
	set_npc_zone_health(npc_zone_original_max_health)
	set_npc_zone_melee(npc_zone_original_melee_lower, npc_zone_original_melee_upper)
	RegisterSignal(src, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE, PROC_REF(npc_zone_projectile))

/// Use for raw max-health changes (posse size, phases). Retains the selected factor.
/mob/living/proc/set_npc_zone_health(raw_max_health)
	npc_zone_original_max_health = raw_max_health
	resize_npc_zone_health(raw_max_health * npc_zone_health_factor)

/// Basic and legacy simple animals both store ALL physical damage in bruteloss.
/// Scale the damage store too, so updatehealth/healing/revival cannot undo the resize.
/mob/living/proc/resize_npc_zone_health(new_max_health)
	if(maxHealth <= 0 || new_max_health <= 0)
		return
	var/ratio = new_max_health / maxHealth
	bruteloss *= ratio
	// Preserve any nonstandard extra loss stores too; do not change stamina.
	oxyloss *= ratio
	toxloss *= ratio
	fireloss *= ratio
	setMaxHealth(new_max_health)
	updatehealth()

/// Source producers call this for recruits, guards, pets, arena mobs and summons.
/// Removal is permanent and preserves health fraction, including on wounded bodies.
/mob/living/proc/exempt_npc_zone()
	npc_zone_exempt = TRUE
	if(!npc_zone_applied)
		return
	UnregisterSignal(src, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE)
	npc_zone_applied = FALSE
	npc_zone_health_factor = 1
	npc_zone_damage_factor = 1
	resize_npc_zone_health(npc_zone_original_max_health)
	melee_damage_lower = npc_zone_original_melee_lower
	melee_damage_upper = npc_zone_original_melee_upper
