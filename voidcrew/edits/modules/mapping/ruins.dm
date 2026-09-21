// Voidcrew extensions to code/modules/mapping/ruins.dm.

/**
 * VOIDCREW EDIT: the rectangle a ruin's CENTRE turf may be sampled from, so that the
 * template AND the margin it always keeps against a map edge land wholly inside `bounds`.
 *
 * `bounds` is an inclusive list(low_x, low_y, high_x, high_y). Returns a rect in the same
 * shape, or NULL when the ruin cannot fit in it however lucky the sampling gets.
 *
 * get_affected_turfs(centre, centered = TRUE) spans
 * [x - round(w/2), x - round(w/2) + w - 1], so a margin of round(w/2) on each side covers
 * the wider (low) half with room to spare on the other; TRANSITIONEDGE +
 * SPACERUIN_MAP_EDGE_PAD on top is the same clearance the unbounded sampler keeps against
 * the world edge, kept here so a ruin never sits flush against the cordon.
 */
/proc/ruin_placement_sample_rect(width, height, list/bounds)
	if(length(bounds) < 4)
		return null
	var/edge_x = TRANSITIONEDGE + SPACERUIN_MAP_EDGE_PAD + round(width / 2)
	var/edge_y = TRANSITIONEDGE + SPACERUIN_MAP_EDGE_PAD + round(height / 2)
	var/list/sample_rect = list(bounds[1] + edge_x, bounds[2] + edge_y, bounds[3] - edge_x, bounds[4] - edge_y)
	if(sample_rect[1] > sample_rect[3] || sample_rect[2] > sample_rect[4])
		return null
	return sample_rect
