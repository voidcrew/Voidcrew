/// Override: block jaunting/phasing on transit z-levels
/datum/controller/subsystem/mapping/add_reservation_zlevel(for_shuttles)
	num_of_res_levels++
	return add_new_zlevel("Transit/Reserved #[num_of_res_levels]", list(ZTRAIT_RESERVED = TRUE, ZTRAIT_NOPHASE = TRUE))
