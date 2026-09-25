/datum/techweb
	/// Machines and installed programs using this disk; disconnected when its physical server loses it.
	var/list/connected_machines = list()
	/// Research data collected from a survey console. Used to restrict tech behind surveys
	var/datum/survey_research/survey_data

/datum/techweb/Destroy()
	survey_data = null
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

/**
 * Gaining a design reveals every hidden node that also grants it, but the parent only drops the
 * node from hidden_nodes. Its status was last computed while it was hidden, so it never made it
 * into available_nodes: the console showed it with every prerequisite met and then refused to
 * research it. Specialist Ammunition shares the WT-550 AP/incendiary magazines with Illegal
 * Technology and always comes after Exotic Ammunition, so every crew that took it hit this.
 * Recompute each node the design revealed.
 */
/datum/techweb/add_design(datum/design/design, custom = FALSE, list/add_to)
	var/list/revealed_ids = list()
	if(istype(design))
		for(var/node_id in design.unlocked_by)
			if(hidden_nodes[node_id])
				revealed_ids += node_id
	. = ..()
	for(var/node_id in revealed_ids)
		if(!hidden_nodes[node_id])
			update_node_status(SSresearch.techweb_node_by_id(node_id))

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
	if(!force && istype(node) && !have_surveys_for_node(node))
		return FALSE
	return ..()
