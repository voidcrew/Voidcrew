/**
 * # Planetary trade goods
 *
 * Goods that only come from planet surfaces, existing to make traders reward
 * planetary exploration (Loot-economy: "power costs danger"). Wave 1 is raw
 * telecrystal (mineable veins seeded on the dangerous planet types) plus
 * the wanted-ledger entries in the shop catalogs that buy fauna harvests.
 * Wave 2 gives every remaining planet type its own good: glacial cores
 * (mined on ice), wild spice pods (gathered on jungle) and pearl clams
 * (fished on beach), so every world has a reason to land there with a ledger
 * in mind.
 *
 * All of these are pure trade goods: raw telecrystal is NOT refined syndicate
 * telecrystal, no ORM accepts any of the minerals, nothing refines, grows or
 * shucks any of them. Vex pays vouchers for telecrystal, the flagship,
 * which is safe under the voucher doctrine because the only supply is hostile
 * planet crust. The wave 2 goods deliberately pay credits only, keeping the
 * voucher spigot exclusive to the deadliest worlds.
 */

// DELIBERATE: this is a plain /obj/item/stack, NOT /obj/item/stack/ore, so upstream's
// vein-spread system (minerals.dm change_ore()/spread) never touches it. Telecrystal
// supply is economy-tuned per-vein; do not "fix" this by reparenting under ore.
/obj/item/stack/telecrystal_raw
	name = "raw telecrystal"
	desc = "A cloudy, unrefined telecrystal shard straight out of planetary crust. Too impure to power anything, but the Undertow pays well for the feedstock. Scanners can't pick the veins out of ordinary rock. Prospectors find these the hard way."
	singular_name = "raw telecrystal shard"
	icon = 'voidcrew/modules/trade/icons/trade.dmi'
	icon_state = "telecrystal_raw"
	w_class = WEIGHT_CLASS_TINY
	max_amount = 30
	merge_type = /obj/item/stack/telecrystal_raw

// ===== VEINS =====

/**
 * Telecrystal-bearing rock. Deliberately has no scan_state: the lattice
 * defeats mining scanners, so veins look like ordinary rock until struck,
 * prospecting on dangerous planets stays luck-and-graft, not scanner sweeps.
 */
/turf/closed/mineral/telecrystal
	mineral_type = /obj/item/stack/telecrystal_raw
	mineral_amt = 2

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

// ===== GLACIAL CORES (ice planets) =====

// DELIBERATE: plain /obj/item/stack, NOT /obj/item/stack/ore — excluded from upstream's
// vein-spread on purpose (economy-tuned supply, same as telecrystal_raw above).
/obj/item/stack/glacial_core
	name = "glacial core"
	desc = "A fist-sized crystal of ancient compressed ice, cut whole out of deep permafrost. It never melts and soaks up heat, so the depots pack cold storage and coolant jackets with them. Mining scanners read the lattice as plain ice, so the only way to find one is to swing at the wall and get lucky."
	singular_name = "glacial core"
	icon = 'icons/obj/mining_zones/artefacts.dmi'
	icon_state = "ice_crystal"
	w_class = WEIGHT_CLASS_SMALL
	max_amount = 15
	merge_type = /obj/item/stack/glacial_core

/**
 * Core-bearing permafrost. Same no-scan-state trick as the telecrystal vein:
 * the lattice reads as ordinary ice on a mining scanner, so it wears the
 * icerock face of any other ore-bearing snow wall and only shows its hand
 * when struck. Appearance and dig-through turfs mirror the ore results of
 * /turf/closed/mineral/random/snow (see its Change_Ore and the fork's
 * FROZEN-breathable edits).
 */
/turf/closed/mineral/glacial
	name = "snowy mountainside"
	icon = MAP_SWITCH('icons/turf/walls/icerock_wall.dmi', 'icons/turf/mining.dmi')
	icon_state = MAP_SWITCH("icerock_wall-0", "icerock")
	base_icon_state = "icerock_wall"
	smoothing_flags = SMOOTH_BITMASK | SMOOTH_BORDER
	canSmoothWith = SMOOTH_GROUP_CLOSED_TURFS
	mineral_type = /obj/item/stack/glacial_core
	mineral_amt = 2
	turf_type = /turf/open/misc/asteroid/snow/icemoon/breathable
	baseturfs = /turf/open/misc/asteroid/snow/icemoon/breathable
	initial_gas_mix = FROZEN_ATMOS
	defer_change = TRUE
	weak_turf = TRUE

// Vein seeding: the snow-planet random rock table lives upstream in
// code/game/turfs/closed/minerals.dm (which this fork already edits), so the
// glacial entry sits directly in /turf/closed/mineral/random/snow's
// mineral_chances(), see the VOIDCREW EDIT there.

// ===== WILD SPICE PODS (jungle planets) =====

/**
 * The jungle planets' gathered good: pod clusters ground-spawned by the
 * jungle surface biomes (see jungle_biomes.dm feature lists). No seeds, no
 * hydroponics strain, no recipe uses them, the vine refuses to grow in a
 * tray, which is exactly why the general store pays for wild stock.
 */
/obj/item/stack/spice_pods
	name = "wild spice pods"
	desc = "A cluster of pungent seed pods snipped off a strangler vine deep under the jungle canopy. Every galley cook and perfumer on the outer ring wants them, and nobody has ever coaxed the vine into growing in a tray."
	singular_name = "wild spice pod"
	icon = 'icons/obj/service/hydroponics/harvest.dmi'
	icon_state = "vanillapod"
	w_class = WEIGHT_CLASS_TINY
	amount = 3 // ground finds are a whole cluster
	max_amount = 30
	merge_type = /obj/item/stack/spice_pods

// ===== PEARL CLAMS (beach planets) =====

/**
 * The beach planets' ocean good: a rare live clam mixed into the shore-water
 * fishing table. Sold whole and unopened. There is deliberately no shucking
 * mechanic, mirroring raw telecrystal's no-refining design: the trader
 * candles them behind the counter and the pearl never enters the economy.
 */
/obj/item/pearl_clam
	name = "pearl clam"
	desc = "A heavy deep-lagoon clam, shut tight around what is hopefully a pearl. Traders candle them on a cold lamp and pay for the glow. An amateur shucking ruins whatever's inside, so they only buy them sealed."
	icon = 'icons/obj/fluff/beach.dmi'
	icon_state = "shell3"
	w_class = WEIGHT_CLASS_SMALL
	throwforce = 0

// The pearl beds: seeded into the beach shore-water catch table. Shore water
// only, the deep-water table (/datum/fish_source/ocean) stays untouched,
// and count-limited with a slow regen so a lagoon can be fished out for a
// while. The fishing portal generator uses its own separate beach table, so
// clams stay planet-gated.
/datum/fish_source/ocean/beach/New()
	. = ..()
	fish_table[/obj/item/pearl_clam] = 3
	fish_counts[/obj/item/pearl_clam] = 2
	fish_count_regen[/obj/item/pearl_clam] = 6 MINUTES
