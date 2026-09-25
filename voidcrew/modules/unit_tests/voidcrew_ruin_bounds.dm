/**
 * # Voidcrew bounded ruin placement test
 *
 * A z-level used to hold exactly one site, so a ruin was kept off everything that
 * mattered by the indestructible cordon painted around the tenant's rectangle. A packed
 * level shares its 255x255 between up to four tenants, and all that separates them is a
 * five-turf gutter - a ruin centred near the edge of one slot writes straight across it
 * and into the neighbour's live ground.
 *
 * seedRuins()/try_to_place() therefore take an optional placement rect, and
 * ruin_placement_sample_rect() is the arithmetic that turns "this rect" into "the turfs
 * the ruin's CENTRE may be sampled from". If it is ever too generous the failure is
 * invisible at the seam and permanent: the ruin is already loaded over someone else's
 * terrain by the time anybody could notice.
 *
 * The invariant under test is that the whole template block - which
 * get_affected_turfs(centre, centered = TRUE) spans as
 * [x - round(w/2), x - round(w/2) + w - 1] - stays inside the rect for every corner of
 * the sample area, and that a template too large to satisfy that is refused up front
 * rather than sampled at until PLACEMENT_TRIES runs out.
 */
/datum/unit_test/voidcrew_ruin_bounds

/datum/unit_test/voidcrew_ruin_bounds/Run()
	// The packed lattice cell: 123x123 anchored at (3,3). Literals rather than the
	// MAP_SLOT_* defines, which live in voidcrew/_DEFINES and compile after this file -
	// the same convention voidcrew_map_packing.dm and voidcrew_ruin_reservation.dm use.
	var/slot_side = 123
	var/list/slot = list(3, 3, 3 + slot_side - 1, 3 + slot_side - 1)

	// No rect means no clamp: every upstream caller relies on this to keep sampling the
	// whole z-level exactly as it always has.
	TEST_ASSERT(isnull(ruin_placement_sample_rect(20, 20, null)), "A null rect must not produce placement bounds")
	TEST_ASSERT(isnull(ruin_placement_sample_rect(20, 20, list())), "An empty rect must not produce placement bounds")
	TEST_ASSERT(isnull(ruin_placement_sample_rect(20, 20, list(3, 3, 125))), "A malformed rect must not produce placement bounds")

	// The margin is TRANSITIONEDGE + SPACERUIN_MAP_EDGE_PAD on each side, so the widest
	// template a slot can take is slot_side - 2 * that. One turf over and it is refused.
	var/margin = TRANSITIONEDGE + SPACERUIN_MAP_EDGE_PAD
	var/widest = slot_side - (margin * 2)
	TEST_ASSERT_NOTNULL(ruin_placement_sample_rect(widest, widest, slot), "A [widest]x[widest] template must fit a [slot_side]x[slot_side] slot")
	TEST_ASSERT(isnull(ruin_placement_sample_rect(widest + 1, widest, slot)), "A template wider than [widest] must be refused, not sampled for")
	TEST_ASSERT(isnull(ruin_placement_sample_rect(widest, widest + 1, slot)), "A template taller than [widest] must be refused, not sampled for")
	TEST_ASSERT(isnull(ruin_placement_sample_rect(slot_side, slot_side, slot)), "A template the full size of the slot must be refused")

	// Odd and even sizes both, because round(w / 2) is asymmetric on even widths.
	for(var/template_width in list(1, 2, 3, 7, 8, 40, 41, widest - 1, widest))
		for(var/template_height in list(1, 2, 3, 7, 8, 40, 41, widest - 1, widest))
			var/list/sample_rect = ruin_placement_sample_rect(template_width, template_height, slot)
			TEST_ASSERT_NOTNULL(sample_rect, "[template_width]x[template_height] should fit a [slot_side]x[slot_side] slot")
			TEST_ASSERT(sample_rect[1] <= sample_rect[3] && sample_rect[2] <= sample_rect[4], "[template_width]x[template_height] produced an inverted sample rect: [sample_rect[1]],[sample_rect[2]] to [sample_rect[3]],[sample_rect[4]]")

			// Both extremes of the sample area, which is where a ruin escapes if it can.
			for(var/centre_x in list(sample_rect[1], sample_rect[3]))
				for(var/centre_y in list(sample_rect[2], sample_rect[4]))
					var/block_low_x = centre_x - round(template_width / 2)
					var/block_low_y = centre_y - round(template_height / 2)
					var/block_high_x = block_low_x + template_width - 1
					var/block_high_y = block_low_y + template_height - 1
					TEST_ASSERT(block_low_x >= slot[1], "[template_width]x[template_height] centred at [centre_x],[centre_y] runs off the low X edge ([block_low_x] < [slot[1]])")
					TEST_ASSERT(block_low_y >= slot[2], "[template_width]x[template_height] centred at [centre_x],[centre_y] runs off the low Y edge ([block_low_y] < [slot[2]])")
					TEST_ASSERT(block_high_x <= slot[3], "[template_width]x[template_height] centred at [centre_x],[centre_y] runs off the high X edge ([block_high_x] > [slot[3]])")
					TEST_ASSERT(block_high_y <= slot[4], "[template_width]x[template_height] centred at [centre_x],[centre_y] runs off the high Y edge ([block_high_y] > [slot[4]])")

	// The rect is honoured wherever it sits, not just at the origin: slot 4 of the
	// lattice starts at (131,131), and an implementation that measured from the level
	// instead of the rect would pass every check above and still fail here.
	var/list/offset_slot = list(131, 131, 131 + slot_side - 1, 131 + slot_side - 1)
	var/list/offset_rect = ruin_placement_sample_rect(41, 41, offset_slot)
	var/list/origin_rect = ruin_placement_sample_rect(41, 41, slot)
	TEST_ASSERT_NOTNULL(offset_rect, "41x41 should fit an offset [slot_side]x[slot_side] slot")
	TEST_ASSERT_NOTNULL(origin_rect, "41x41 should fit a [slot_side]x[slot_side] slot at the origin")
	TEST_ASSERT_EQUAL(offset_rect[1] - offset_slot[1], origin_rect[1] - slot[1], "The sample rect must be anchored on the bounds, not on the level")
	TEST_ASSERT(offset_rect[3] <= offset_slot[3], "The sample rect must stay inside an offset slot's high X edge")
	TEST_ASSERT(offset_rect[4] <= offset_slot[4], "The sample rect must stay inside an offset slot's high Y edge")
