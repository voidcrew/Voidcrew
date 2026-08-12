/**
 * # Drug recipe
 *
 * One rolled formula for the drug smuggling mission: three wild-harvested
 * ingredients (each tied to a planet type), a generated street name, and the
 * minigame charts the lab machines run against.
 *
 * Everything downstream of `seed` comes from the recipe's own PRNG, never
 * BYOND's global rand, so every chart is re-derivable at any time (the TGUI
 * clients rebuild them from scratch) and a seed fully identifies a recipe.
 * Chart times are in MILLISECONDS for the JS clients, not deciseconds.
 */

/// Xorshift sticks at zero forever, so zeroed states land here instead
#define DRUG_RNG_FALLBACK_STATE 48879
// Per-builder salts xor'd into the seed, so each chart's stream is independent
// of the others and independently re-derivable
#define DRUG_RNG_SALT_MIXER 42405
#define DRUG_RNG_SALT_CATALYST 23130
#define DRUG_RNG_SALT_CRYSTALLIZER 3990

/datum/drug_recipe
	/// Generated street name of the product, e.g. "Crimson Halo"
	var/street_name
	/// One-line flavor description of the finished product
	var/product_desc_line
	/// Three entries of list("type" = item path, "name" = text, "biome" = planet datum path)
	var/list/ingredients
	/// The rolled identity of this recipe; everything else derives from it
	var/seed
	/// Current PRNG state, advanced by next_rand()
	var/rng_state

	/// Which ingredients grow where: planet datum path -> two candidate item paths
	var/static/list/ingredient_pool = list(
		/datum/overmap/planet/jungle = list(
			/obj/item/drug_ingredient/wraithvine_resin,
			/obj/item/drug_ingredient/chromacap_spores,
		),
		/datum/overmap/planet/lava = list(
			/obj/item/drug_ingredient/ashrose_petals,
			/obj/item/drug_ingredient/magmatic_salt,
		),
		/datum/overmap/planet/ice = list(
			/obj/item/drug_ingredient/cryoheart_extract,
			/obj/item/drug_ingredient/glimmerfrost_crystal,
		),
		/datum/overmap/planet/beach = list(
			/obj/item/drug_ingredient/tidelily_nectar,
			/obj/item/drug_ingredient/driftcoral_powder,
		),
		/datum/overmap/planet/wasteland = list(
			/obj/item/drug_ingredient/rustweed_tar,
			/obj/item/drug_ingredient/scrapland_lichen,
		),
	)

	var/static/list/street_prefixes = list(
		"Crimson", "Void", "Static", "Glacier", "Saturn", "Neon", "Phantom", "Ember",
		"Cobalt", "Rogue", "Hollow", "Solar", "Grave", "Velvet", "Feral", "Zero",
		"Lunar", "Rust", "Sugar", "Widow",
	)
	var/static/list/street_suffixes = list(
		"Halo", "Glass", "Dust", "Wire", "Tide", "Bloom", "Ash", "Spark",
		"Honey", "Fang", "Drift", "Circuit", "Sting", "Frost", "Smoke", "Nova",
		"Thorn", "Echo", "Shard", "Crush",
	)
	var/static/list/desc_lines = list(
		"It hums faintly against the packaging, which nobody involved wants to explain.",
		"The crystals catch the light in a way that feels illegal on its own.",
		"It smells like ozone, fruit, and very poor decisions.",
		"Rumor says one dose makes the whole galaxy look brand new.",
		"The cook swore the shimmer means it's working. The cook also has no eyebrows.",
	)

/**
 * Roll a fresh recipe. `present_biomes` is the list of /datum/overmap/planet
 * subtype paths currently in the galaxy; returns FALSE if fewer than three
 * biomes from the ingredient pool are present to build a formula from.
 */
/datum/drug_recipe/proc/generate(list/present_biomes)
	var/list/usable = list()
	for(var/biome in ingredient_pool)
		if(biome in present_biomes)
			usable += biome
	if(length(usable) < 3)
		return FALSE
	seed = rand(1, 65535)
	roll_recipe(usable)
	return TRUE

/**
 * Derive ingredients, street name and flavor from the current seed.
 * `usable` must be the pool-filtered biome list; callers other than
 * generate() (tests, debugging) may set `seed` themselves first.
 */
/datum/drug_recipe/proc/roll_recipe(list/usable)
	reset_rng(0)
	var/list/pool = usable.Copy()
	ingredients = list()
	for(var/i in 1 to 3)
		var/datum/overmap/planet/biome = pool[next_rand(length(pool))]
		pool -= biome
		var/list/pair = ingredient_pool[biome]
		var/obj/item/drug_ingredient/ingredient_type = pair[next_rand(length(pair))]
		ingredients += list(list(
			"type" = ingredient_type,
			"name" = initial(ingredient_type.name),
			"biome" = biome,
		))
	street_name = "[street_prefixes[next_rand(length(street_prefixes))]] [street_suffixes[next_rand(length(street_suffixes))]]"
	product_desc_line = "A batch of [street_name]. [desc_lines[next_rand(length(desc_lines))]]"

/// Reset the PRNG stream to the seed xor a per-builder salt
/datum/drug_recipe/proc/reset_rng(salt)
	rng_state = seed ^ salt
	if(!rng_state)
		rng_state = DRUG_RNG_FALLBACK_STATE

/**
 * Advance the PRNG and return 1..max. 16-bit xorshift (Metcalf's 7/9/8
 * triple, full period 65535), BYOND bitwise ops only go to 24 bits, so a
 * true xorshift32 can't be expressed; this width is plenty for chart rolls.
 */
/datum/drug_recipe/proc/next_rand(max)
	rng_state ^= (rng_state << 7) & 0xFFFF
	rng_state ^= rng_state >> 9
	rng_state ^= (rng_state << 8) & 0xFFFF
	return (rng_state % max) + 1

/**
 * Hopper order for one mixer round: a list of hopper indices
 * (1..DRUG_MIXER_HOPPER_COUNT), growing from 4 to 8 entries over rounds 1-5.
 */
/datum/drug_recipe/proc/build_mixer_sequence(round_num)
	reset_rng(DRUG_RNG_SALT_MIXER ^ (round_num * 1543))
	var/list/sequence = list()
	for(var/i in 1 to 3 + round_num)
		sequence += next_rand(DRUG_MIXER_HOPPER_COUNT)
	return sequence

/**
 * Rhythm chart for the catalyst station: 40-60 notes of
 * list("lane" = 1..4, "t" = ms), ascending, spread over ~45 seconds.
 * Notes are at least 120ms apart overall and 350ms apart within a lane,
 * built in time order with the gaps enforced by construction, so no sort.
 */
/datum/drug_recipe/proc/build_catalyst_chart()
	reset_rng(DRUG_RNG_SALT_CATALYST)
	var/note_count = 39 + next_rand(21)
	var/base_gap = round(45000 / note_count)
	var/list/chart = list()
	var/list/lane_last = list(-600, -600, -600, -600)
	var/t = 500 + next_rand(500)
	for(var/i in 1 to note_count)
		// gaps bottom out at 121ms, so at most two prior notes sit inside any
		// lane's 350ms cooldown window. At least two lanes are always open
		var/list/open_lanes = list()
		for(var/lane in 1 to DRUG_CATALYST_LANE_COUNT)
			if(t - lane_last[lane] >= 350)
				open_lanes += lane
		var/lane = open_lanes[next_rand(length(open_lanes))]
		chart += list(list("lane" = lane, "t" = t))
		lane_last[lane] = t
		t += 120 + next_rand(2 * (base_gap - 120))
	return chart

/**
 * Falling-crystal table for the crystallizer station: exactly 35 pure and 15
 * tainted entries of list("col" = 1..5, "t" = ms, "tainted" = 0|1),
 * ascending, at least 250ms apart, spread over ~40 seconds.
 */
/datum/drug_recipe/proc/build_crystallizer_table()
	reset_rng(DRUG_RNG_SALT_CRYSTALLIZER)
	var/total = 50
	var/tainted_left = 15
	var/base_gap = round(40000 / total)
	var/list/table = list()
	var/t = 400 + next_rand(400)
	for(var/i in 1 to total)
		// hypergeometric draw: exact tainted count, deterministic placement
		var/tainted = 0
		if(next_rand(total - i + 1) <= tainted_left)
			tainted = 1
			tainted_left--
		table += list(list("col" = next_rand(DRUG_CRYSTALLIZER_COL_COUNT), "t" = t, "tainted" = tainted))
		t += 250 + next_rand(2 * (base_gap - 250))
	return table

#undef DRUG_RNG_FALLBACK_STATE
#undef DRUG_RNG_SALT_MIXER
#undef DRUG_RNG_SALT_CATALYST
#undef DRUG_RNG_SALT_CRYSTALLIZER
