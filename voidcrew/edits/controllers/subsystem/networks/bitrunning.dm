// Voidcrew extensions to code/controllers/subsystem/networks/bitrunning.dm.

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

/datum/controller/subsystem/bitrunning
	/// Domain key -> weakref of the quantum server currently running it. Domain
	/// datums are fleet-wide singletons and a fleet can have a server on every
	/// ship, so only one holder at a time is allowed per key.
	var/list/domains_in_use = list()
