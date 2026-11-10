/**
 * # Gene injector loot (voidcrew/modules/loot/gene_injectors.dm)
 *
 * Every loot injector adds exactly one real mutation, can't be copied, and is
 * reachable from a loot theme; a failed injection never spends the injector;
 * the DNA vault mutations leave nothing behind when they fail to take; and
 * Shock Touch counts as an attack at a trader outpost.
 */

/datum/unit_test/voidcrew_gene_injector_loot_tables
	/// Loot injector subtypes deliberately built but not placed in any theme yet.
	/// Clever and the Wizardly, Superhuman and Ork hulks are held back by having no subtype at all.
	var/static/list/held_back = list()

/datum/unit_test/voidcrew_gene_injector_loot_tables/Run()
	var/list/placed = list()
	for(var/theme_path in GLOB.loot_themes)
		var/datum/loot_theme/theme = GLOB.loot_themes[theme_path]
		for(var/list/table in list(theme.loot_common, theme.loot_uncommon, theme.loot_prime, theme.loot_uniques))
			for(var/entry in table)
				if(ispath(entry, /obj/item/dnainjector))
					TEST_ASSERT(ispath(entry, /obj/item/dnainjector/loot), "[theme_path] drops a stock injector [entry]; loot uses the checked /loot subtypes")
					placed[entry] = TRUE

	var/obj/item/dnainjector/loot/base = allocate(/obj/item/dnainjector/loot)
	var/list/mutations_seen = list()
	for(var/injector_path in subtypesof(/obj/item/dnainjector/loot))
		var/obj/item/dnainjector/loot/injector = allocate(injector_path)
		TEST_ASSERT_EQUAL(length(injector.add_mutations), 1, "[injector_path] must add exactly one mutation")
		TEST_ASSERT_EQUAL(length(injector.remove_mutations), 0, "[injector_path] must not remove mutations")
		var/mutation_path = injector.add_mutations[1]
		TEST_ASSERT(ispath(mutation_path, /datum/mutation) && GET_INITIALIZED_MUTATION(mutation_path), "[injector_path] adds [mutation_path], which is not a registered mutation")
		TEST_ASSERT(!mutations_seen[mutation_path], "[injector_path] and [mutations_seen[mutation_path]] add the same mutation")
		mutations_seen[mutation_path] = injector_path
		TEST_ASSERT(injector.name != base.name, "[injector_path] has no name of its own")
		TEST_ASSERT(injector.desc != base.desc, "[injector_path] has no description of its own")
		// TRAIT_NO_REPLICATE; voidcrew defines are included after unit tests.
		TEST_ASSERT(HAS_TRAIT(injector, "no_replicate"), "[injector_path] can be copied by a duplicator")
		if(injector_path in held_back)
			TEST_ASSERT(!placed[injector_path], "[injector_path] is placed in loot but still listed as held back")
		else
			TEST_ASSERT(placed[injector_path], "[injector_path] is in no loot theme table, dead content")

/// A refused injection keeps the injector; a good one spends it.
/datum/unit_test/voidcrew_gene_injector_loot_refusal

/datum/unit_test/voidcrew_gene_injector_loot_refusal/Run()
	var/mob/living/carbon/human/corpse = allocate(/mob/living/carbon/human/consistent)
	corpse.death()
	var/obj/item/dnainjector/loot/telekinesis/tk = allocate(/obj/item/dnainjector/loot/telekinesis)
	// attack() only spends the injector when inject() succeeds; a living user on
	// another target would sit in a do_after, so call the step itself.
	TEST_ASSERT(!tk.inject(corpse, corpse), "Injecting a corpse would spend the injector")
	TEST_ASSERT_NULL(corpse.dna.get_mutation(/datum/mutation/telekinesis), "A corpse gained a mutation")

	var/mob/living/carbon/human/cat = allocate(/mob/living/carbon/human/species/felinid)
	var/obj/item/dnainjector/loot/hulk/hulk = allocate(/obj/item/dnainjector/loot/hulk)
	hulk.attack(cat, cat)
	TEST_ASSERT(!hulk.used, "A felinid spent a human-only Hulk injector")
	TEST_ASSERT_NULL(cat.dna.get_mutation(/datum/mutation/hulk), "A felinid became a hulk")

	var/mob/living/carbon/human/plasmaman = allocate(/mob/living/carbon/human/species/plasma)
	var/obj/item/dnainjector/loot/strength/strength = allocate(/obj/item/dnainjector/loot/strength)
	strength.attack(plasmaman, plasmaman)
	TEST_ASSERT(!strength.used, "A geneless plasmaman spent an injector")

	var/mob/living/carbon/human/explorer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/dnainjector/loot/cold_adaptation/cold = allocate(/obj/item/dnainjector/loot/cold_adaptation)
	cold.attack(explorer, explorer)
	TEST_ASSERT(cold.used, "A valid injection did not spend the injector")
	TEST_ASSERT_NOTNULL(explorer.dna.get_mutation(/datum/mutation/adaptation/cold), "A valid injection did not add its mutation")
	var/obj/item/dnainjector/loot/heat_adaptation/heat = allocate(/obj/item/dnainjector/loot/heat_adaptation)
	heat.attack(explorer, explorer)
	TEST_ASSERT(!heat.used, "A conflicting adaptation spent the injector")
	TEST_ASSERT_NULL(explorer.dna.get_mutation(/datum/mutation/adaptation/heat), "Two adaptations were held at once")
	var/obj/item/dnainjector/loot/cold_adaptation/second_cold = allocate(/obj/item/dnainjector/loot/cold_adaptation)
	second_cold.attack(explorer, explorer)
	TEST_ASSERT(!second_cold.used, "Injecting a gene the target already has spent the injector")

/// The DNA vault mutations must not apply their buff when acquisition fails.
/datum/unit_test/voidcrew_gene_injector_vault_guard

/datum/unit_test/voidcrew_gene_injector_vault_guard/Run()
	for(var/mutation_path in list(/datum/mutation/breathless, /datum/mutation/quick, /datum/mutation/tough, /datum/mutation/dextrous, /datum/mutation/fire_immunity, /datum/mutation/quick_recovery, /datum/mutation/plasmocile))
		var/mob/living/carbon/human/corpse = allocate(/mob/living/carbon/human/consistent)
		corpse.death()
		var/brute = corpse.physiology.brute_mod
		var/burn = corpse.physiology.burn_mod
		var/stun = corpse.physiology.stun_mod
		var/next_move = corpse.next_move_modifier
		corpse.dna.add_mutation(mutation_path, MUTATION_SOURCE_MUTATOR)
		TEST_ASSERT_NULL(corpse.dna.get_mutation(mutation_path), "[mutation_path] took on a corpse")
		TEST_ASSERT_EQUAL(corpse.physiology.brute_mod, brute, "[mutation_path] left a brute modifier after failing")
		TEST_ASSERT_EQUAL(corpse.physiology.burn_mod, burn, "[mutation_path] left a burn modifier after failing")
		TEST_ASSERT_EQUAL(corpse.physiology.stun_mod, stun, "[mutation_path] left a stun modifier after failing")
		TEST_ASSERT_EQUAL(corpse.next_move_modifier, next_move, "[mutation_path] left a click speed modifier after failing")
		TEST_ASSERT(!corpse.has_movespeed_modifier(/datum/movespeed_modifier/dna_vault_speedup), "[mutation_path] left a speed modifier after failing")
		for(var/trait in list(TRAIT_NOBREATH, TRAIT_PIERCEIMMUNE, TRAIT_RESISTHEAT, TRAIT_NOFIRE, TRAIT_VIRUSIMMUNE))
			TEST_ASSERT(!HAS_TRAIT_FROM(corpse, trait, GENETIC_MUTATION), "[mutation_path] left [trait] after failing")

/// Shock Touch on another visitor earns the caster a strike like any other attack.
/datum/unit_test/voidcrew_gene_injector_shock_touch_outpost

/datum/unit_test/voidcrew_gene_injector_shock_touch_outpost/Run()
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost)
	outpost.outpost_template = allocate(/datum/map_template/trader_outpost)
	outpost.outpost_template.width = 1
	outpost.outpost_template.height = 1
	outpost.template_bottom_left = run_loc_floor_bottom_left
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	attacker.mind_initialize()
	victim.mind_initialize()
	var/datum/action/cooldown/spell/touch/shock/shock = allocate(/datum/action/cooldown/spell/touch/shock, attacker)
	shock.cast_on_hand_hit(null, victim, attacker)
	TEST_ASSERT_EQUAL(outpost.aggressor_strikes[attacker.mind], 1, "Shock Touch on a visitor did not count as an attack")
	TEST_ASSERT_NULL(outpost.aggressor_strikes[victim.mind], "The shocked visitor was given a strike")
