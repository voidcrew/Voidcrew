/datum/techweb
	/// Machines and installed programs using this disk; disconnected when its physical server loses it.
	var/list/connected_machines = list()
	/// Research data collected from a survey console. Used to restrict tech behind surveys
	var/datum/survey_research/survey_data
	/// Node id -> remaining actual payment by currency and the discounts still owed to that purchase.
	/// These receipts belong only to this web; research transfers never copy them.
	var/list/experiment_payment_receipts = list()
	/// Completion grants for webs without a crew or player outpost to hold their claims.
	var/list/local_experiment_reward_ledger = list()

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
	return have_zone_permission_for_node(node) && can_afford(node.get_price(src)) && have_experiments_for_node(node) && have_surveys_for_node(node)

/// A relay exposes this same web, but only its installed physical source grants standing.
/datum/techweb/proc/get_research_zone_permission()
	for(var/obj/machinery/rnd/server/ship/server in techweb_servers)
		if(QDELETED(server) || server.stored_research != src || !server.source_code_hdd || server.source_code_hdd.loc != server || server.source_code_hdd.stored_research != src)
			continue
		var/datum/voidcrew_crew_record/record = server.get_research_crew_record()
		return QDELETED(record) ? ZONE_PERMISSION_PUBLIC : record.get_zone_permission()
	return ZONE_PERMISSION_PUBLIC

/datum/techweb/proc/have_zone_permission_for_node(datum/techweb_node/node)
	if(!istype(node))
		return FALSE
	return node.zone_permission == ZONE_PERMISSION_PUBLIC || node.zone_permission <= get_research_zone_permission()

/// Authorization is the sole blocker only after prerequisites and every research requirement pass.
/datum/techweb/proc/is_only_zone_permission_blocked(datum/techweb_node/node)
	if(!istype(node) || have_zone_permission_for_node(node) || !available_nodes[node.id])
		return FALSE
	return can_afford(node.get_price(src)) && have_experiments_for_node(node) && have_surveys_for_node(node)

/datum/techweb/enqueue_node(id, mob/user)
	if(!have_zone_permission_for_node(SSresearch.techweb_node_by_id(id)))
		if(user)
			to_chat(user, span_warning("Authorization declined."))
		return FALSE
	return ..()

/// Called immediately after a successful purchase's debit, before the node is marked researched.
/datum/techweb/proc/record_node_payment(datum/techweb_node/node, list/points_before)
	if(node.starting_node || researched_nodes[node.id])
		return
	var/list/pending_discounts = list()
	for(var/experiment_type in node.discount_experiments)
		if(!completed_experiments[experiment_type] && node.discount_experiments[experiment_type] > 0)
			pending_discounts[experiment_type] = node.discount_experiments[experiment_type]
	if(!length(pending_discounts))
		return
	var/list/paid_points = list()
	for(var/point_type in points_before)
		var/paid = points_before[point_type] - research_points[point_type]
		if(paid > 0)
			paid_points[point_type] = paid
	if(length(paid_points))
		experiment_payment_receipts[node.id] = list("remaining" = paid_points, "discounts" = pending_discounts)

/// Each missing experiment may refund its discount once per paid node, capped in each currency.
/datum/techweb/proc/refund_experiment_discounts(datum/experiment/experiment)
	var/list/refund = list()
	for(var/node_id in experiment_payment_receipts)
		var/list/receipt = experiment_payment_receipts[node_id]
		var/list/discounts = receipt["discounts"]
		var/discount = discounts[experiment.type]
		if(!discount)
			continue
		discounts -= experiment.type
		var/list/remaining = receipt["remaining"]
		for(var/point_type in remaining)
			var/amount = min(discount, remaining[point_type])
			remaining[point_type] -= amount
			refund[point_type] += amount
	add_point_list(refund)
	return refund

/// Direct calls and queued work recheck surveys and live source standing before the debit.
/// Forced imports, starting nodes and admin grants retain the parent's bypass.
/datum/techweb/research_node(datum/techweb_node/node, force = FALSE, auto_adjust_cost = TRUE, get_that_dosh = TRUE, atom/research_source)
	if(!force && istype(node) && (!have_surveys_for_node(node) || !have_zone_permission_for_node(node)))
		return FALSE
	var/mob/metric_queued_by = force ? null : metric_node_queued_by(node) // round metrics, voidcrew/modules/metrics/research_metrics.dm
	. = ..()
	if(. && !force)
		record_node_researched(node, research_source, metric_queued_by)
