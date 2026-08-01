/**
 * Zone ore scaling — planets in deeper overmap zone bands yield MORE ore per
 * mineral wall (same ore tables; kinds are never zone-gated, only amounts).
 *
 * Called from the one-line VOIDCREW EDIT in the base gets_drilled()
 * (code/game/turfs/closed/minerals.dm) — the single payout choke point every
 * mining path funnels through (picks, drills, KA/plasma projectiles, ex_act,
 * blob). Scaling at payout instead of Initialize means spread-vein walls
 * (which keep the default mineralAmt of 3, never touched by
 * scale_ore_to_vent()) and mapper-placed ore walls inside planet ruins get
 * scaled too, and it costs nothing at planet init. Walls created after init
 * are equally covered — and on non-planet z-levels (space ruins,
 * asteroid-field reservations, outposts, transit) the band lookup returns
 * null, so behavior there is byte-identical to upstream.
 *
 * Deliberately NOT scaled:
 * * telecrystal + glacial core veins — the planetary trade goods
 *   (voidcrew/modules/trade/planetary_goods.dm); their supply is
 *   economy-tuned, so a richer red-band spigot would distort the
 *   voucher/credit ladder
 * * gibtonite and "very strong rock" — their gets_drilled() overrides never
 *   call the base proc, so they never reach this hook; gibtonite's
 *   mineralAmt is detonation bookkeeping, not an ore payout
 * * gulag boulder walls — they use spawned_boulder, not mineralType, so the
 *   base proc's mineralType guard already skips them
 */
/turf/closed/mineral/proc/zone_scaled_ore_amount(amount)
	if(amount <= 0)
		return amount
	// trade-good veins keep their tuned yields — see block comment
	if(istype(src, /turf/closed/mineral/telecrystal) || istype(src, /turf/closed/mineral/glacial))
		return amount
	// Resolved live, per wall. SSmapping.get_planet_zone_band_for_z() alone only
	// answers for pre-generated roundstart planets, and every planet this round
	// is dynamic, so it always came back null; planet_zone_type_for_z_level()
	// asks the overmap first and falls back to it. Not cached per z either -
	// dynamic planet z-levels are recycled, so a cached band would follow the
	// z-level onto the next planet to inherit it.
	switch(SSovermap_zones?.planet_zone_type_for_z_level(z))
		if(ZONE_YELLOW)
			return round(amount * ZONE_PLANET_ORE_MULT_YELLOW)
		if(ZONE_RED)
			return round(amount * ZONE_PLANET_ORE_MULT_RED)
	return amount

/turf/closed/mineral/random/high_chance/wasteland
	baseturfs = /turf/open/misc/dust

/turf/closed/mineral/random/high_chance/mineral_chances()
	return list(
		/obj/item/stack/ore/uranium = 35,
		/obj/item/stack/ore/diamond = 30,
		/obj/item/stack/ore/gold = 45,
		/obj/item/stack/ore/titanium = 45,
		/obj/item/stack/ore/iron = 55,
		/obj/item/stack/ore/silver = 50,
		/obj/item/stack/ore/plasma = 50,
		/obj/item/stack/ore/bluespace_crystal = 20,
		/turf/closed/mineral/gibtonite/wasteland = 4,
		/turf/closed/mineral/telecrystal/wasteland = 6,
	)

/turf/closed/mineral/gibtonite/wasteland
	baseturfs = /turf/open/misc/dust

/turf/closed/mineral/random/beach
	baseturfs = /turf/open/misc/asteroid/sand/beach/dense

/turf/closed/wall/mineral/titanium/interior/blue
	color = "#9CE9F6"
	smoothing_flags = SMOOTH_BITMASK

/turf/closed/wall/mineral/titanium/interior/blue/Initialize()
	. = ..()
	add_atom_colour("#9CE9F6", FIXED_COLOUR_PRIORITY) // fuck you
