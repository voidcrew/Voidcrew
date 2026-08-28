/datum/techweb
	///List of everything connected to this techweb via Multitool, used for R&D server deconstruction.
	var/list/connected_machines = list()
	/// Research data collected from a survey console. Used to restrict tech behind surveys
	var/datum/survey_research/survey_data

/**
 * Upstream's Destroy nulls the node/design lists but never clears the three membership lists, so
 * a dead techweb leaves every machine that was multitooled to it still holding it - a gutted
 * datum whose researched_designs and available_nodes are null. The console keeps reporting
 * itself linked and its catalogue stays empty for the rest of the round.
 *
 * That never mattered for the station's permanent web. Here a techweb dies whenever its ship
 * disk does, so cut the machines loose while there is still something to cut them loose from.
 */
/datum/techweb/Destroy()
	survey_data = null
	// The union is already a fresh list, which it needs to be: unsync_research_servers() removes
	// entries from connected_machines and consoles_accessing as it goes.
	for(var/atom/linked in (connected_machines | consoles_accessing))
		linked.unsync_research_servers()
	// Servers live in their own list and aren't reached by the above.
	for(var/obj/machinery/rnd/server/server in techweb_servers)
		server.stored_research = null
	connected_machines?.Cut()
	consoles_accessing?.Cut()
	techweb_servers?.Cut()
	return ..()

/datum/techweb/proc/have_surveys_for_node(datum/techweb_node/node)
	if(!LAZYLEN(node.required_surveyed_objects))
		return TRUE
	// No survey console has been multitool-linked to this web yet, so there is no survey data
	// and no way for the crew to gather any. The gated node stays locked, rather than us
	// dereferencing a null survey_data (which runtimed and read as "locked" by accident).
	if(isnull(survey_data))
		return FALSE
	for(var/object in node.required_surveyed_objects)
		if(length(survey_data.survey_objects_by_type[object]) < node.required_surveyed_objects[object])
			return FALSE
	return TRUE

/datum/techweb/can_unlock_node(datum/techweb_node/node)
	return can_afford(node.get_price(src)) && have_experiments_for_node(node) && have_surveys_for_node(node)

/**
 * The survey requirement has to be enforced here as well as in can_unlock_node. That proc only
 * drives the console UI's button states, whereas research_node is what every path that actually
 * unlocks a node funnels through: the R&D console, the Science Hub app, and SSresearch's
 * automatic processing of the research queue. Without this a survey-gated node can simply be
 * enqueued and researched on the next SSresearch fire with none of the surveys done.
 *
 * force is honoured so roundstart/starting-node and admin research still bypass it, matching
 * the point and experiment gates in the parent proc.
 */
/datum/techweb/research_node(datum/techweb_node/node, force = FALSE, auto_adjust_cost = TRUE, get_that_dosh = TRUE, atom/research_source)
	// Upstream's parent now accepts a raw typepath and resolves it itself (research_node_id()
	// was folded in), so a queued path with only an istype() guard here would sail past the
	// survey gate. Resolve first, gate second.
	if(ispath(node))
		node = SSresearch.techweb_nodes[node]
	if(!force && istype(node) && !have_surveys_for_node(node))
		return FALSE
	return ..()

/**
 * Point-item lookup with a subtype fallback. Ported from the fork's edit to the deleted
 * code/modules/research/techweb/__techweb_helpers.dm: SSresearch.techweb_point_items is keyed
 * by the BASE path (/obj/item/assembly/signaler/anomaly, which only ever exists as subtypes),
 * so upstream's exact-type `techweb_point_items[thing.type]` lookups never match a single real
 * item and the deconstruction payout is unreachable. First matching entry wins.
 * Callers (each a VOIDCREW EDIT): items.dm examine hint, destructive_analyzer ui_data + payout.
 */
/datum/controller/subsystem/research/proc/point_items_for(obj/item/thing)
	var/list/exact = techweb_point_items[thing.type]
	if(exact)
		return exact
	for(var/point_path in techweb_point_items)
		if(istype(thing, point_path))
			return techweb_point_items[point_path]
	return null
