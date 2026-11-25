// Voidcrew extensions to code/modules/awaymissions/away_props.dm.

/**
 * An invisible wall stops everyone (CanAllowThrough()) though it is not dense, and tg's pathfinder only asks things
 * that are dense, so every path planned round someone went through one and stopped at it. Quartermain's stock-room
 * hall has a row of them along one side: an outpost officer walking a prisoner, told to plan round a colleague
 * standing in that hall, planned through the row and stood still (outpost police, pass 12 soak).
 */
/obj/effect/invisible_wall
	can_astar_pass = CANASTARPASS_ALWAYS_PROC

/obj/effect/invisible_wall/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	return FALSE
