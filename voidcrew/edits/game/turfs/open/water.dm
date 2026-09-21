// Voidcrew extensions to code/game/turfs/open/water.dm.

//
// /turf/open/water hangs off /turf/open directly rather than off /turf/open/floor or
// /turf/open/misc, so it inherited /atom/rcd_vals()'s bare FALSE and had no rcd_act() at
// all. rcd_create() returns NONE on a falsey rcd_vals with no message, so clicking water
// with an RCD did nothing whatsoever and said nothing about it. Ponds and rivers are all
// over the planet ruins here, which is where the report came from.
//
// Deliberately the same terms lava, chasms and open space already get (see
// /turf/open/lava/rcd_vals, /turf/open/chasm/rcd_vals, /turf/open/openspace/rcd_vals):
// 3 matter units, no delay, plating placed ON TOP so the water stays underneath it and
// comes back when the plating is pulled up. Deep water is not treated differently -
// bridging it is the point, and lava is not gated either.
/turf/open/water/rcd_vals(mob/user, obj/item/construction/rcd/the_rcd)
	if(the_rcd.mode == RCD_TURF && the_rcd.rcd_design_path == /turf/open/floor/plating/rcd)
		return list("delay" = 0, "cost" = 3)
	return FALSE

/turf/open/water/rcd_act(mob/user, obj/item/construction/rcd/the_rcd, list/rcd_data)
	if(rcd_data["[RCD_DESIGN_MODE]"] == RCD_TURF && rcd_data["[RCD_DESIGN_PATH]"] == /turf/open/floor/plating/rcd)
		place_on_top(/turf/open/floor/plating, flags = CHANGETURF_INHERIT_AIR)
		return TRUE
	return FALSE
