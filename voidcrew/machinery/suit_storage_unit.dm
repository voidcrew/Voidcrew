/// Uniform base-tier suit stock shared by machines and the loose ruin spawner.
GLOBAL_LIST_INIT(base_tier_modsuits, list(
	/obj/item/mod/control/pre_equipped/standard,
	/obj/item/mod/control/pre_equipped/civilian,
	/obj/item/mod/control/pre_equipped/engineering,
	/obj/item/mod/control/pre_equipped/atmospheric,
	/obj/item/mod/control/pre_equipped/mining,
	/obj/item/mod/control/pre_equipped/medical,
))

/obj/machinery/suit_storage_unit/base_tier

/obj/machinery/suit_storage_unit/base_tier/Initialize(mapload)
	mod_type = pick(GLOB.base_tier_modsuits)
	return ..()

/obj/effect/spawner/random/modsuit/base_tier
	name = "base MODsuit spawner"
	icon_state = "circuit"

/obj/effect/spawner/random/modsuit/base_tier/Initialize(mapload)
	loot = GLOB.base_tier_modsuits.Copy()
	return ..()

/obj/machinery/suit_storage_unit/ruin_zone
	/// Pinned before parent initialization; moving the machine never changes its tier.
	var/turf/stock_spawn_turf
	/// A resolved or checkpoint-scrubbed unit can never create stock again.
	var/stock_consumed = FALSE
	/// Keep retrieval blocked throughout suit initialization, even if it yields.
	var/stock_resolving = FALSE

/obj/machinery/suit_storage_unit/ruin_zone/Initialize(mapload)
	stock_spawn_turf = get_turf(src)
	mod_type = null
	suit_type = null
	helmet_type = null
	. = ..()
	return INITIALIZE_HINT_LATELOAD

/obj/machinery/suit_storage_unit/ruin_zone/LateInitialize()
	. = ..()
	if(!stock_consumed)
		new /datum/zone_resolver(stock_spawn_turf, CALLBACK(src, PROC_REF(stock_for_zone)))

/obj/machinery/suit_storage_unit/ruin_zone/Destroy()
	stock_spawn_turf = null
	return ..()

/obj/machinery/suit_storage_unit/ruin_zone/proc/stock_for_zone(zone_type)
	if(QDELETED(src) || stock_consumed || stock_resolving)
		return
	stock_resolving = TRUE
	stock_spawn_turf = null
	switch(zone_type)
		if(ZONE_RED)
			mod_type = /obj/item/mod/control/pre_equipped/nuclear/unrestricted
		if(ZONE_YELLOW)
			mod_type = /obj/item/mod/control/pre_equipped/security
		else
			mod_type = pick(GLOB.base_tier_modsuits)
	var/obj/item/mod/control/reward = new mod_type(src)
	stock_resolving = FALSE
	// A checkpoint scrub or deletion may have happened during initialization.
	if(QDELETED(src) || stock_consumed)
		qdel(reward)
		return
	stock_consumed = TRUE
	mod = reward
	update_appearance()

/obj/machinery/suit_storage_unit/ruin_zone/check_interactable(mob/user)
	if(!stock_consumed || stock_resolving)
		return FALSE
	return ..()

/obj/machinery/suit_storage_unit/ert
	mask_type = /obj/item/clothing/mask/gas/atmos/centcom
	storage_type = /obj/item/tank/jetpack/oxygen/captain
	mod_type = /obj/item/mod/control/pre_equipped/responsory

/obj/machinery/suit_storage_unit/ert/commander
	mod_type = /obj/item/mod/control/pre_equipped/responsory/commander

/obj/machinery/suit_storage_unit/ert/security
	mod_type = /obj/item/mod/control/pre_equipped/responsory/security

/obj/machinery/suit_storage_unit/ert/medic
	mod_type = /obj/item/mod/control/pre_equipped/responsory/medic

/obj/machinery/suit_storage_unit/ert/engineer
	mod_type = /obj/item/mod/control/pre_equipped/responsory/engineer

/obj/machinery/suit_storage_unit/ert/janitor
	mod_type = /obj/item/mod/control/pre_equipped/responsory/janitor

/obj/machinery/suit_storage_unit/ert/clown
	mod_type = /obj/item/mod/control/pre_equipped/responsory/clown

/obj/machinery/suit_storage_unit/ert/chaplain
	mod_type = /obj/item/mod/control/pre_equipped/responsory/chaplain
