#define REDACTED "???"

SUBSYSTEM_DEF(bitrunning)
	name = "Bitrunning"
	flags = SS_NO_FIRE

	var/list/all_domains = list()
	/// Domain key -> weakref of the quantum server currently running it. Domain
	/// datums are fleet-wide singletons and a fleet can have a server on every
	/// ship, so only one holder at a time is allowed per key.
	var/list/domains_in_use = list()

/datum/controller/subsystem/bitrunning/Initialize()
	InitializeDomains()
	return SS_INIT_SUCCESS

/datum/controller/subsystem/bitrunning/proc/InitializeDomains()
	for(var/path in subtypesof(/datum/lazy_template/virtual_domain))
		all_domains += new path()

/// Compiles a list of available domains.
/datum/controller/subsystem/bitrunning/proc/get_available_domains(scanner_tier, points)
	var/list/levels = list()

	for(var/datum/lazy_template/virtual_domain/domain as anything in all_domains)
		if(domain.test_only)
			continue
		var/can_view = domain.difficulty < scanner_tier && domain.cost <= points + 5
		var/can_view_reward = domain.difficulty < (scanner_tier + 1) && domain.cost <= points + 3

		UNTYPED_LIST_ADD(levels, list(
			"announce_ghosts" = domain.announce_to_ghosts,
			"cost" = domain.cost,
			"desc" = can_view ? domain.desc : "Limited scanning capabilities. Cannot infer domain details.",
			"difficulty" = domain.difficulty,
			"id" = domain.key,
			"is_modular" = domain.is_modular,
			"has_secondary_objectives" = counterlist_sum(domain.secondary_loot) ? TRUE : FALSE,
			"name" = can_view ? domain.name : REDACTED,
			"reward" = can_view_reward ? domain.reward_points : REDACTED,
		))

	return levels

/// The quantum server currently running the given domain key, if any. Clears the
/// entry if its holder has since been destroyed.
/datum/controller/subsystem/bitrunning/proc/get_domain_holder(key)
	var/datum/weakref/holder_ref = domains_in_use[key]
	if(isnull(holder_ref))
		return null

	var/obj/machinery/quantum_server/holder = holder_ref.resolve()
	if(isnull(holder))
		domains_in_use -= key
		return null

	return holder

/// Marks a domain key as running on the given server. FALSE if another server holds it.
/datum/controller/subsystem/bitrunning/proc/claim_domain(key, obj/machinery/quantum_server/server)
	if(isnull(key) || isnull(server))
		return FALSE

	var/obj/machinery/quantum_server/holder = get_domain_holder(key)
	if(holder && holder != server)
		return FALSE

	domains_in_use[key] = WEAKREF(server)
	return TRUE

/**
 * TRUE if the given turf sits inside a virtual domain that is currently loaded.
 *
 * Upstream contains a domain purely through area flags - LOCAL_TELEPORT to stop
 * teleports crossing out, allow_shuttle_docking to stop shuttles landing. That only
 * holds for tiles the template actually painted an area onto. A reservation's floor
 * is whatever the z-level was created as, which is world.area: the global
 * /area/space instance, which has no LOCAL_TELEPORT and DOES whitelist docking. Every
 * /area/template_noop tile in a domain map, and every tile of the reservation the
 * template doesn't cover, is one of those. Build a quantum pad or a shuttle frame on
 * one and the area checks wave it straight through, loot and all.
 *
 * So anything asking "may this cross the VR boundary" has to ask about the
 * reservation, not the area.
 */
/datum/controller/subsystem/bitrunning/proc/is_domain_turf(turf/checked)
	if(isnull(checked) || !length(domains_in_use))
		return FALSE

	// Domains only ever live in a turf reservation (see /datum/lazy_template/lazy_load).
	if(!is_reserved_level(checked.z))
		return FALSE

	// Deliberately not get_domain_holder(): that prunes dead keys as it goes, and
	// callers include check_teleport_valid(), which is SHOULD_BE_PURE.
	for(var/key in domains_in_use)
		var/datum/weakref/holder_ref = domains_in_use[key]
		var/obj/machinery/quantum_server/holder = holder_ref?.resolve()
		var/datum/lazy_template/virtual_domain/domain = holder?.generated_domain
		if(isnull(domain))
			continue

		for(var/datum/turf_reservation/reservation as anything in domain.reservations)
			if(reservation.contains_turf(checked))
				return TRUE

	return FALSE

/// Frees a domain key, provided the given server is the one holding it.
/datum/controller/subsystem/bitrunning/proc/release_domain(key, obj/machinery/quantum_server/server)
	if(isnull(key))
		return

	var/obj/machinery/quantum_server/holder = get_domain_holder(key)
	if(holder && holder != server)
		return

	domains_in_use -= key

/datum/controller/subsystem/bitrunning/proc/pick_secondary_loot(completed_domain)
	var/datum/lazy_template/virtual_domain/domain = completed_domain
	var/choice

	if(counterlist_sum(domain.secondary_loot))
		choice = pick_weight(domain.secondary_loot)
		domain.secondary_loot[choice] -= 1
	else
		choice = /obj/item/paper/paperslip/bitrunning_error
		CRASH("Virtual domain [domain.name] tried to pick secondary objective loot, but secondary_loot list was empty.")
	return choice

/obj/item/paper/paperslip/bitrunning_error
	name = "Apology Letter"
	desc = "Something went wrong here."

/obj/item/paper/paperslip/bitrunning_error/Initialize(mapload)
	default_raw_text = "Your reward for collecting the encrypted curiosity failed to arrive, please report this to technical support."
	return ..()

#undef REDACTED
