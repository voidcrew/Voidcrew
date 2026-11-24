/**
 * # Curios and small finds
 *
 * What comes out of strange rocks: fossils, pottery, statuettes, instruments, scrap, now and then
 * tg's strange object, a page of research notes or a single item from a sealed research case.
 * Each dig site has a kind (Bay's: garden, animal, house, technical, temple, war), weighted by
 * the planet's climate, which decides its small finds by tier.
 *
 * Every curio and strange object that comes out of the ground is stamped with the band it was
 * dug in (origin_band). Buyers read that and `curio_class`; an unstamped one (admin spawned,
 * experimentor copies, maintenance relics) is not a find.
 *
 * Sprites: Polaris (6cd19fe0dec6) icons/obj/xenoarchaeology.dmi small-find states, CC BY-SA 3.0.
 */

// ===== Site kinds =====

/// Climate favourites: planet type -> site kinds that turn up more often there.
GLOBAL_LIST_INIT(xenoarch_site_kind_climates, list(
	/datum/planet/beach = list(XENOARCH_SITE_GARDEN, XENOARCH_SITE_HOUSE),
	/datum/planet/jungle = list(XENOARCH_SITE_GARDEN, XENOARCH_SITE_ANIMAL),
	/datum/planet/snow = list(XENOARCH_SITE_ANIMAL, XENOARCH_SITE_HOUSE),
	/datum/planet/wasteland = list(XENOARCH_SITE_TECHNICAL, XENOARCH_SITE_WAR),
	/datum/planet/lava = list(XENOARCH_SITE_TEMPLE, XENOARCH_SITE_WAR),
))

/// Picks a site kind, favouring the ones the planet's climate suits.
/proc/xenoarch_pick_site_kind(planet_type)
	var/list/weights = list()
	for(var/kind in list(XENOARCH_SITE_GARDEN, XENOARCH_SITE_ANIMAL, XENOARCH_SITE_HOUSE, XENOARCH_SITE_TECHNICAL, XENOARCH_SITE_TEMPLE, XENOARCH_SITE_WAR))
		weights[kind] = 10
	var/list/favoured = GLOB.xenoarch_site_kind_climates[planet_type]
	for(var/kind in favoured)
		weights[kind] = 30
	return pick_weight(weights)

/// A small find's tier, 1 to 3, by band.
/proc/xenoarch_roll_small_tier(band)
	var/list/odds
	switch(XENOARCH_BAND_INDEX(band))
		if(ZONE_RED)
			odds = XENOARCH_SMALL_TIER_ODDS_RED
		if(ZONE_YELLOW)
			odds = XENOARCH_SMALL_TIER_ODDS_YELLOW
		else
			odds = XENOARCH_SMALL_TIER_ODDS_GREEN
	return max(xenoarch_pick_weighted_index(odds), 1)

/// Stands in a small find table for "one item from a sealed research case".
/datum/xenoarch_research_draw

/// What a strange rock from a site of `site_kind` holds at `tier`: a type path.
/proc/xenoarch_small_find(site_kind, tier)
	switch(site_kind)
		if(XENOARCH_SITE_GARDEN)
			switch(tier)
				if(1)
					return pick(/obj/item/xenoarch_curio/plant_fossil, /obj/item/xenoarch_curio/shell)
				if(2)
					return /obj/item/xenoarch_curio/seed_pod
				else
					return /obj/item/research_notes/excavation/tiny
		if(XENOARCH_SITE_ANIMAL)
			switch(tier)
				if(1)
					return pick(/obj/item/xenoarch_curio/bone, /obj/item/xenoarch_curio/skull)
				if(2)
					return /obj/item/xenoarch_curio/skeleton
				else
					return /obj/item/research_notes/excavation/tiny
		if(XENOARCH_SITE_TECHNICAL)
			switch(tier)
				if(1)
					return /obj/item/xenoarch_curio/scrap
				if(2)
					return /obj/item/relic/excavated
				else
					return /datum/xenoarch_research_draw
		if(XENOARCH_SITE_TEMPLE)
			switch(tier)
				if(1)
					return pick(/obj/item/xenoarch_curio/urn, /obj/item/xenoarch_curio/statuette)
				if(2)
					return pick(/obj/item/xenoarch_curio/instrument, /obj/item/xenoarch_curio/idol)
				else
					return /obj/item/relic/excavated
		if(XENOARCH_SITE_WAR)
			switch(tier)
				if(1)
					return /obj/item/xenoarch_curio/sidearm
				if(2)
					return /obj/item/relic/excavated
				else
					return /obj/item/research_notes/excavation/small
	// House, and anything unknown
	switch(tier)
		if(1)
			return pick(/obj/item/xenoarch_curio/bowl, /obj/item/xenoarch_curio/urn)
		if(2)
			return pick(/obj/item/xenoarch_curio/statuette, /obj/item/xenoarch_curio/instrument)
	return /obj/item/relic/excavated

/// Makes a small find at `destination` and stamps it with `band`. Returns it.
/proc/xenoarch_spawn_small_find(find_type, atom/destination, band)
	if(find_type == /datum/xenoarch_research_draw)
		return xenoarch_research_draw(destination, band)
	if(!ispath(find_type, /atom/movable))
		return null
	var/atom/movable/find = new find_type(destination)
	xenoarch_stamp_find(find, band)
	return find

/// One item from the research loot theme, at the band's odds, as a sealed case would give it.
/proc/xenoarch_research_draw(atom/destination, band)
	var/datum/loot_theme/theme = GLOB.loot_themes[/datum/loot_theme/research]
	if(!theme)
		return null
	var/list/pools = list(
		"[LOOT_TIER_COMMON]" = theme.loot_common?.Copy(),
		"[LOOT_TIER_UNCOMMON]" = theme.loot_uncommon?.Copy(),
		"[LOOT_TIER_PRIME]" = theme.loot_prime?.Copy(),
		"[LOOT_TIER_UNIQUE]" = theme.loot_uniques?.Copy(),
	)
	var/list/odds
	switch(XENOARCH_BAND_INDEX(band))
		if(ZONE_RED)
			odds = ZONE_LOOT_ODDS_RED
		if(ZONE_YELLOW)
			odds = ZONE_LOOT_ODDS_YELLOW
		else
			odds = ZONE_LOOT_ODDS_GREEN
	var/loot_path = draw_loot_from_tier(pools, pick_weight(odds))
	if(!loot_path)
		return null
	return spawn_loot_prize(destination, loot_path)

/// What outpost buyers pay for each curio class (design: credits only).
GLOBAL_LIST_INIT(xenoarch_curio_values, list(
	XENOARCH_CURIO_SHELL = 40,
	XENOARCH_CURIO_FOSSIL = 50,
	XENOARCH_CURIO_POTTERY = 80,
	XENOARCH_CURIO_STATUETTE = 150,
	XENOARCH_CURIO_INSTRUMENT = 150,
	XENOARCH_CURIO_STRANGE_OBJECT = 200,
))

/// Stamps a curio or strange object with the band it was dug in and marks it for buyers.
/// First stamp wins. Returns TRUE if `find` is a stampable small find.
/proc/xenoarch_stamp_find(atom/movable/find, band)
	band = XENOARCH_BAND_INDEX(band)
	if(istype(find, /obj/item/xenoarch_curio))
		var/obj/item/xenoarch_curio/curio = find
		if(!isnull(curio.origin_band))
			return TRUE
		curio.origin_band = band
		xenoarch_dig_mark_find(curio, GLOB.xenoarch_curio_values[curio.curio_class])
		return TRUE
	if(istype(find, /obj/item/relic/excavated))
		var/obj/item/relic/excavated/relic = find
		if(!isnull(relic.origin_band))
			return TRUE
		relic.origin_band = band
		xenoarch_dig_mark_find(relic, GLOB.xenoarch_curio_values[XENOARCH_CURIO_STRANGE_OBJECT])
		return TRUE
	return FALSE

/**
 * Marks a freshly dug small find as one outpost buyers will take, at `value` credits. Buyers refuse
 * anything unmarked on purpose (maintenance relics, experimentor copies, admin spawns). The trade
 * module's xenoarch_mark_curio() (trade/buyers.dm) does the marking; this is the only call site.
 */
/proc/xenoarch_dig_mark_find(obj/item/find, value)
	if(!istype(find) || !value)
		return FALSE
	return xenoarch_mark_curio(find, value)

// ===== Research notes =====

/obj/item/research_notes/excavation
	origin_type = "xenoarchaeology"

/obj/item/research_notes/excavation/tiny
	value = 100

/obj/item/research_notes/excavation/small
	value = 250

// ===== Strange object =====

/// tg's strange object, as dug out of a site. Only these, stamped, count as finds.
/obj/item/relic/excavated
	/// ZONE_* it was dug in, or null
	var/origin_band

// ===== Curios =====

/obj/item/xenoarch_curio
	name = "curio"
	desc = "Something old, out of the ground."
	icon = 'voidcrew/modules/xenoarch/icons/curios.dmi'
	icon_state = "bone"
	w_class = WEIGHT_CLASS_SMALL
	resistance_flags = FIRE_PROOF
	/// XENOARCH_CURIO_*: what a buyer files it under
	var/curio_class = XENOARCH_CURIO_FOSSIL
	/// ZONE_* it was dug in, or null if it never came out of the ground
	var/origin_band
	/// Icon states to pick from
	var/list/variants
	/// Descriptions to pick from
	var/list/descs

/obj/item/xenoarch_curio/Initialize(mapload)
	. = ..()
	if(length(variants))
		icon_state = pick(variants)
	if(length(descs))
		desc = pick(descs)
	pixel_x = base_pixel_x + rand(-6, 6)
	pixel_y = base_pixel_y + rand(-4, 4)

/obj/item/xenoarch_curio/examine(mob/user)
	. = ..()
	if(!isnull(origin_band))
		. += "Grit from the dig is still packed into it."

/obj/item/xenoarch_curio/plant_fossil
	name = "plant fossil"
	curio_class = XENOARCH_CURIO_FOSSIL
	variants = list("plant1", "plant2", "plant3", "plant4")
	descs = list(
		"A flake of stone holding the print of a leaf. Nothing that grows now has leaves like it.",
		"A slab of rock with a frond pressed into it, every vein still there.",
	)

/obj/item/xenoarch_curio/shell
	name = "fossil shell"
	curio_class = XENOARCH_CURIO_SHELL
	variants = list("shell")
	descs = list(
		"A coiled shell turned to stone, from a sea that dried up long ago.",
		"A ribbed shell, stone all the way through.",
	)

/obj/item/xenoarch_curio/seed_pod
	name = "seed pod"
	curio_class = XENOARCH_CURIO_STATUETTE
	variants = list("green_lump")
	descs = list(
		"A hard green pod the size of a fist. Something rattles inside when you shake it.",
		"A seed case, glassy and green, sealed shut for longer than anyone can guess.",
	)

/obj/item/xenoarch_curio/bone
	name = "fossil bone"
	curio_class = XENOARCH_CURIO_FOSSIL
	variants = list("bone")
	descs = list(
		"A long bone gone to stone, still bedded in a little rock.",
		"A heavy limb bone from something big. It's all rock now.",
	)

/obj/item/xenoarch_curio/skull
	name = "fossil skull"
	curio_class = XENOARCH_CURIO_FOSSIL
	variants = list("skull", "hskull")
	descs = list(
		"A skull set in stone. The eye sockets face the wrong way for anything you know.",
		"A horned skull, half freed from its rock.",
	)

/obj/item/xenoarch_curio/skeleton
	name = "fossil skeleton"
	curio_class = XENOARCH_CURIO_STATUETTE
	w_class = WEIGHT_CLASS_BULKY
	variants = list("uskel", "skel")
	descs = list(
		"A whole skeleton of some long-dead creature, wired upright on a block of its own stone.",
		"Every bone of a small animal, still lying where it died.",
	)

/obj/item/xenoarch_curio/bowl
	name = "clay bowl"
	curio_class = XENOARCH_CURIO_POTTERY
	variants = list("bowl")
	descs = list(
		"A shallow bowl of fired clay, rim chipped, glaze still bright inside.",
		"A hand-thrown bowl. Somebody's thumbprint is baked into the base.",
	)

/obj/item/xenoarch_curio/urn
	name = "urn"
	curio_class = XENOARCH_CURIO_POTTERY
	variants = list("urn", "urn1", "urn2", "urn3")
	descs = list(
		"A narrow-necked urn, sealed with something that has gone hard as stone.",
		"A painted urn. The pattern repeats all the way round and never quite matches up.",
	)

/obj/item/xenoarch_curio/statuette
	name = "statuette"
	curio_class = XENOARCH_CURIO_STATUETTE
	variants = list("statuette", "statuette1", "statuette2", "statuette3")
	descs = list(
		"A small carved figure. Too many joints in the arms.",
		"A figure worn smooth by handling, long before it was buried.",
	)

/obj/item/xenoarch_curio/instrument
	name = "strange instrument"
	curio_class = XENOARCH_CURIO_INSTRUMENT
	variants = list("instrument")
	descs = list(
		"Bells, reeds or both, in a frame of dark metal. It makes no sound when shaken.",
		"Something meant to be played, though not by hands like yours.",
	)

/obj/item/xenoarch_curio/idol
	name = "idol"
	curio_class = XENOARCH_CURIO_STATUETTE
	variants = list("unknown1")
	descs = list(
		"A banded column of gold-coloured metal, stacked like a spine.",
		"A column of metal rings, stacked and worn smooth where hands once held it.",
	)

/obj/item/xenoarch_curio/scrap
	name = "corroded mechanism"
	curio_class = XENOARCH_CURIO_POTTERY
	variants = list("unknown2", "unknown3", "unknown4", "box", "sliver1", "pen1")
	descs = list(
		"A lump of machinery fused by age. Whatever it did, it stopped doing it a long time ago.",
		"A fitting of some kind, its threads clogged with ancient grit.",
	)

/obj/item/xenoarch_curio/sidearm
	name = "spent sidearm"
	curio_class = XENOARCH_CURIO_POTTERY
	w_class = WEIGHT_CLASS_NORMAL
	variants = list("egun1", "egun3", "egun5", "egun9", "gun1", "gun3", "gunold")
	descs = list(
		"A sidearm from a war nobody remembers. The works inside have rotted solid.",
		"A grip and a barrel, more or less. It will never fire again.",
	)
