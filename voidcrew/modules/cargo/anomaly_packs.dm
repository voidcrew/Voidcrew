/**
 * Raw anomaly cores are off the cargo catalogue.
 *
 * The anomaly core cap is lifted in this fork (voidcrew/modules/research/edits/
 * _experiments.dm), so a 2000 cr crate per core made them a routine order.
 * Boffin at the Quartermain Depot is now the only store that sells raw cores,
 * on a small rotating shelf, with anomaly charts as the other way to hunt one
 * (shop_catalog_outfitter_vendors.dm, anomaly_charts.dm).
 *
 * SSshuttle only registers packs with a non-null `contains`. Overriding the var
 * to null does not work for these: upstream sets `contains = list(...)`, and a
 * list default is built at New() time, after the null has been applied, so the
 * pack comes back with its contents. Clearing it in New() drops each crate from
 * every console without touching the upstream definitions.
 */
GLOBAL_LIST_INIT(voidcrew_removed_supply_packs, typecacheof(list(
	/datum/supply_pack/science/raw_flux_anomaly,
	/datum/supply_pack/science/raw_hallucination_anomaly,
	/datum/supply_pack/science/raw_grav_anomaly,
	/datum/supply_pack/science/raw_vortex_anomaly,
	/datum/supply_pack/science/raw_ectoplasm_anomaly,
	/datum/supply_pack/science/raw_bluespace_anomaly,
	/datum/supply_pack/science/raw_pyro_anomaly,
	/datum/supply_pack/science/raw_bioscrambler_anomaly,
	/datum/supply_pack/science/raw_dimensional_anomaly,
)))

// Chains onto the upstream New.
/datum/supply_pack/New()
	. = ..()
	if(GLOB.voidcrew_removed_supply_packs[type])
		contains = null
