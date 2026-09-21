// Voidcrew extensions to code/modules/research/designs.dm.

/// Rebuild the finite experimental deck only when its current cycle is exhausted.
/proc/refill_experimental_technology_deck()
	if(length(SSresearch.techweb_nodes_experimental))
		return
	for(var/node_id in SSresearch.techweb_nodes)
		var/datum/techweb_node/node = SSresearch.techweb_nodes[node_id]
		if(node.experimental)
			SSresearch.techweb_nodes_experimental[node_id] = TRUE
