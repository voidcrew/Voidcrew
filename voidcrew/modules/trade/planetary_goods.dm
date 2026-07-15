/**
 * # Planetary trade goods
 *
 * Goods that only come from planet surfaces, existing to make traders reward
 * planetary exploration (Loot-economy: "power costs danger"). Wave 1 is raw
 * telecrystal — mineable veins seeded on the dangerous planet types — plus
 * the wanted-ledger entries in the shop catalogs that buy fauna harvests.
 *
 * Raw telecrystal is a pure trade good: it is NOT refined syndicate
 * telecrystal, no ORM accepts it, and nothing converts it. Vex pays vouchers
 * for it, which is safe under the voucher doctrine because the only supply
 * is hostile planet crust.
 */

/obj/item/stack/telecrystal_raw
	name = "raw telecrystal"
	desc = "A cloudy, unrefined telecrystal shard straight out of planetary crust. Too impure to power anything, but the Undertow pays well for the feedstock. Scanners can't pick the veins out of ordinary rock — prospectors find these the hard way."
	singular_name = "raw telecrystal shard"
	icon = 'icons/obj/stack_objects.dmi'
	icon_state = "telecrystal"
	// Duller than the refined article until it gets its own sprite (sprite pass, phase 5)
	color = "#b8cbb0"
	w_class = WEIGHT_CLASS_TINY
	max_amount = 30
	merge_type = /obj/item/stack/telecrystal_raw

// ===== VEINS =====

/**
 * Telecrystal-bearing rock. Deliberately has no scan_state: the lattice
 * defeats mining scanners, so veins look like ordinary rock until struck —
 * prospecting on dangerous planets stays luck-and-graft, not scanner sweeps.
 */
/turf/closed/mineral/telecrystal
	mineralType = /obj/item/stack/telecrystal_raw
	mineralAmt = 2

/turf/closed/mineral/telecrystal/volcanic
	turf_type = /turf/open/misc/asteroid/basalt/lava_land_surface
	baseturfs = /turf/open/misc/asteroid/basalt/lava_land_surface
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	defer_change = TRUE

/turf/closed/mineral/telecrystal/wasteland
	baseturfs = /turf/open/misc/dust

// ===== VEIN SEEDING (lava planets) =====
// The lava biomes point at these instead of the stock volcanic random rock;
// they carry the upstream ore table plus a telecrystal chance. The wasteland
// table gets its entry directly in voidcrew/turfs/closed/minerals.dm, which
// this fork already owns.

/turf/closed/mineral/random/volcanic/voidcrew/mineral_chances()
	var/list/chances = ..()
	chances[/turf/closed/mineral/telecrystal/volcanic] = 3
	return chances

/turf/closed/mineral/random/high_chance/volcanic/voidcrew/mineral_chances()
	var/list/chances = ..()
	chances[/turf/closed/mineral/telecrystal/volcanic] = 5
	return chances
