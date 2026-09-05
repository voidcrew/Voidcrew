#define MAX_MANIFEST_PENALTY CARGO_CRATE_VALUE * 2.5

// Approved manifest.
// At most20 credits or10% of payment: cheap goodies and flash coupons cannot subsidize themselves.
/datum/export/manifest_correct
	cost = CARGO_CRATE_VALUE * 0.1
	k_elasticity = 0
	unit_name = "approved manifest"
	export_types = list(/obj/item/paper/fluff/jobs/cargo/manifest)
	scannable = FALSE

/datum/export/manifest_correct/get_cost(obj/O, apply_elastic = TRUE)
	var/obj/item/paper/fluff/jobs/cargo/manifest/manifest = O
	return max(0, min(..(), FLOOR(manifest.order_cost * 0.1, 1)))

/datum/export/manifest_correct/applies_to(obj/O)
	if(!..())
		return FALSE

	var/obj/item/paper/fluff/jobs/cargo/manifest/M = O
	if(M.is_approved() && !M.errors)
		return TRUE
	return FALSE

// Correctly denied manifest.
// Refunds the recorded payment minus the original 200-credit handling allowance.
/datum/export/manifest_error_denied
	cost = -CARGO_CRATE_VALUE
	k_elasticity = 0
	unit_name = "correctly denied manifest"
	export_types = list(/obj/item/paper/fluff/jobs/cargo/manifest)
	scannable = FALSE

/datum/export/manifest_error_denied/applies_to(obj/O)
	if(!..())
		return FALSE

	var/obj/item/paper/fluff/jobs/cargo/manifest/M = O
	if(M.is_denied() && M.errors)
		return TRUE
	return FALSE

/datum/export/manifest_error_denied/get_cost(obj/O)
	var/obj/item/paper/fluff/jobs/cargo/manifest/M = O
	return ..() + M.order_cost


// Erroneously approved manifest.
// Subtracts half the package cost. (max -500 credits)
/datum/export/manifest_error
	unit_name = "erroneously approved manifest"
	k_elasticity = 0
	export_types = list(/obj/item/paper/fluff/jobs/cargo/manifest)
	allow_negative_cost = TRUE
	scannable = FALSE

/datum/export/manifest_error/applies_to(obj/O)
	if(!..())
		return FALSE

	var/obj/item/paper/fluff/jobs/cargo/manifest/M = O
	if(M.is_approved() && M.errors)
		return TRUE
	return FALSE

/datum/export/manifest_error/get_cost(obj/O)
	var/obj/item/paper/fluff/jobs/cargo/manifest/M = O
	return -min(M.order_cost * 0.5, MAX_MANIFEST_PENALTY)


// Erroneously denied manifest.
// Subtracts half the package cost. (max -500 credits)
/datum/export/manifest_correct_denied
	k_elasticity = 0
	unit_name = "erroneously denied manifest"
	export_types = list(/obj/item/paper/fluff/jobs/cargo/manifest)
	allow_negative_cost = TRUE
	scannable = FALSE

/datum/export/manifest_correct_denied/applies_to(obj/O)
	if(!..())
		return FALSE

	var/obj/item/paper/fluff/jobs/cargo/manifest/M = O
	if(M.is_denied() && !M.errors)
		return TRUE
	return FALSE

/datum/export/manifest_correct_denied/get_cost(obj/O)
	var/obj/item/paper/fluff/jobs/cargo/manifest/M = O
	return -min(M.order_cost * 0.5, MAX_MANIFEST_PENALTY)

#undef MAX_MANIFEST_PENALTY
