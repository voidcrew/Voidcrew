// The Rig Bay side of Wick's shop: the stand pools, the stands it lists, and their convoy refills.
// The shelf lists (categories, sku_types) and Wick's lines stay in shop_catalog_suit_vendor.dm.

/datum/outpost_shop/vendor/suit_fitter
	// The stand pools deal nothing on their own (slots = 0); each stand deals its own pick.
	rotations = list(
		/datum/shop_rotation/rig_bay/work,
		/datum/shop_rotation/rig_bay/combat,
		/datum/shop_rotation/rig_bay_arms,
	)
	/// The Rig Bay stands linked to this shop. Each lists its mech as one line under Exosuits.
	var/list/obj/structure/rig_bay_stand/stands = list()

/datum/outpost_shop/vendor/suit_fitter/Destroy()
	for(var/obj/structure/rig_bay_stand/stand as anything in stands)
		UnregisterSignal(stand, COMSIG_QDELETING)
		if(stand.shop == src)
			stand.stop_retry()
			stand.shop = null
	stands.Cut()
	return ..()

/// Registers a stand for convoy refills. Called from the stand's link_outpost().
/datum/outpost_shop/vendor/suit_fitter/proc/attach_stand(obj/structure/rig_bay_stand/stand)
	if(QDELETED(stand) || (stand in stands))
		return
	stands += stand
	RegisterSignal(stand, COMSIG_QDELETING, PROC_REF(on_stand_deleted))

/datum/outpost_shop/vendor/suit_fitter/proc/on_stand_deleted(obj/structure/rig_bay_stand/stand)
	SIGNAL_HANDLER
	stands -= stand

/datum/outpost_shop/vendor/suit_fitter/convoy_restock()
	. = ..()
	restock_stands()

/// Every stand hears the convoy. Empty ones whose pool is due get a new mech, beamed in.
/datum/outpost_shop/vendor/suit_fitter/proc/restock_stands()
	for(var/obj/structure/rig_bay_stand/stand as anything in stands)
		if(QDELETED(stand))
			continue
		stand.convoy_arrived()
