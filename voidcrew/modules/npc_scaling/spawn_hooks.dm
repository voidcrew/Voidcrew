/// Construction scope only; InitAtom does not sleep. Nested spawn calls restore it.
GLOBAL_VAR(npc_zone_construction_context)

/**
 * The single constructor for profiled producers. A context is per construction,
 * including its replacement chain. Pass finalize = FALSE when the caller still
 * has body/weapon/faction setup to do; call context.finalize() afterwards.
 * Returns the surviving replacement when Initialize deletes the requested body.
 * Non-mob outputs (nests, portals) keep the context for their later spawns.
 * constructor_args, when supplied, are the Initialize arguments after location.
 */
/proc/spawn_npc_in_zone(spawn_type, atom/location, datum/npc_spawn_context/context, finalize = TRUE, list/constructor_args)
	var/datum/npc_spawn_context/previous = GLOB.npc_zone_construction_context
	GLOB.npc_zone_construction_context = context
	var/list/spawn_args = list(location)
	if(constructor_args)
		spawn_args += constructor_args
	var/atom/created = new spawn_type(arglist(spawn_args))
	GLOB.npc_zone_construction_context = previous
	if(QDELETED(created))
		for(var/datum/weakref/body_ref as anything in context.bodies)
			var/mob/living/body = body_ref.resolve()
			if(!QDELETED(body))
				created = body
				break
	else
		created.npc_spawn_context = context
		if(isliving(created))
			context.bodies |= WEAKREF(created)
	if(finalize)
		context.finalize()
	return created

/// Pin an environmental parent's source before its first emission, not at child death.
/atom/proc/get_npc_spawn_context()
	if(!npc_spawn_context)
		npc_spawn_context = GLOB.npc_zone_construction_context || new /datum/npc_spawn_context(src)
	return npc_spawn_context

// The initialization-complete signal is emitted even for INITIALIZE_HINT_QDEL.
// Wrapping InitAtom keeps context active through the ENTIRE subtype Initialize,
// including replacement rolls after ..(), without modifying those mob types.
/datum/controller/subsystem/atoms/InitAtom(atom/target, from_template = FALSE, list/arguments)
	if(!isliving(target) || QDELETED(target))
		return ..()
	var/datum/npc_spawn_context/previous = GLOB.npc_zone_construction_context
	var/datum/npc_spawn_context/context = previous
	var/owns_context = FALSE
	if(isliving(target))
		context ||= target.npc_spawn_context
		if(!context && arguments && arguments[1])
			context = new /datum/npc_spawn_context(target)
			owns_context = TRUE
		if(context)
			GLOB.npc_zone_construction_context = context
			target.npc_spawn_context = context
			context.bodies |= WEAKREF(target)
		RegisterSignal(target, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZE, PROC_REF(npc_zone_initialized))
	. = ..()
	GLOB.npc_zone_construction_context = previous
	if(owns_context || (context?.ready_to_finalize && previous != context))
		context.finalize()

/datum/controller/subsystem/atoms/proc/npc_zone_initialized(mob/living/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZE)
	if(QDELETED(source))
		return
	source.npc_zone_initialization_complete = TRUE
	source.apply_npc_weapon_ladder()
	// Ownership can change long after spawn. Signals are installed once per body.
	RegisterSignals(source, list(COMSIG_MOB_LOGIN, COMSIG_MOB_MIND_INITIALIZED, COMSIG_MOB_MIND_TRANSFERRED_INTO), PROC_REF(npc_zone_owned))
	RegisterSignal(source, COMSIG_LIVING_BEFRIENDED, PROC_REF(npc_zone_befriended))
	if(source.npc_zone_ready)
		source.finalize_npc_zone()

/datum/controller/subsystem/atoms/proc/npc_zone_owned(mob/living/source)
	SIGNAL_HANDLER
	source.exempt_npc_zone()

/datum/controller/subsystem/atoms/proc/npc_zone_befriended(mob/living/source, mob/living/friend)
	SIGNAL_HANDLER
	if(friend && (friend.client || friend.mind || friend.npc_zone_exempt))
		source.exempt_npc_zone()

// Replace upstream's bare constructor so the regular megafauna attack inherits its source.
// No parent call: it would create an additional, unprofiled skull.
/datum/action/cooldown/mob_cooldown/create_legion_skull/create(atom/target)
	owner.get_npc_spawn_context()
	var/datum/npc_spawn_context/context = new(owner, role = "ordinary")
	var/mob/living/basic/legion_brood/minion = spawn_npc_in_zone(/mob/living/basic/legion_brood, owner.loc, context, FALSE)
	minion.assign_creator(owner)
	minion.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, target)
	context.finalize()
