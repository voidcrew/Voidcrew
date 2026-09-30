// Voidcrew extensions to code/modules/cargo/exports/manifest.dm.

/datum/export/manifest_correct/get_cost(obj/O, apply_elastic = TRUE)
	var/obj/item/paper/fluff/jobs/cargo/manifest/manifest = O
	return max(0, min(..(), FLOOR(manifest.order_cost * 0.1, 1)))
