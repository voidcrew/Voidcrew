/**
 * # Vestige ruin conformance
 *
 * The vestige system (voidcrew/modules/antag_ruins/) hands out ported antag
 * abilities as payment for trials. It had no test coverage of any kind, and
 * three of its invariants are documented in prose and enforced by nothing:
 *
 * 1. **Boon pools must stay disjoint.** patron.dm spells out at length why: a
 *    trial snapshots its patron's pool when the pact is struck and only
 *    rechecks eligibility at completion, so a boon shared between two patrons
 *    lets a supplicant take it elsewhere mid-pact, complete into an empty pool,
 *    and spend the trial for nothing with no way to retake it.
 * 2. **Every vestige ruin map places exactly one patron.** A copy-paste slip
 *    gives a ruin with nothing in it, and there is no in-game signal that
 *    anything is wrong, the crew just flies to an empty hulk.
 * 3. **Ascension wiring resolves.** Arena templates deliberately bypass
 *    SSmapping.map_templates and hardcode a mappath, so a renamed file fails
 *    only at run time, inside a live one-way attempt.
 *
 * All three are checked against data and shipped map text: a CIBUILDING world
 * boots MetaStation, so nothing here may assume an overmap or a loaded ruin.
 */

/// Source root the patron-pool scan reads.
#define VESTIGE_SOURCE_ROOT "voidcrew/modules/antag_ruins/"

/datum/unit_test/vestige_boon_pools
	priority = TEST_LONGER

/datum/unit_test/vestige_boon_pools/Run()
	var/list/sources = list()
	vc_test_collect_dm_files(VESTIGE_SOURCE_ROOT, sources)
	TEST_ASSERT(length(sources) > 10, "the vestige source scan found only [length(sources)] .dm files under [VESTIGE_SOURCE_ROOT], wrong root?")

	// Pools are list vars: initial() cannot read them, and instantiating a
	// patron to read them off the instance dresses an appearance dummy through
	// an async callback that would outlive the qdel. Read the source instead.
	var/list/pools = vc_test_scan_list_var(sources, "/mob/living/basic/vestige_patron", "boon_types")
	var/list/trials = vc_test_scan_list_var(sources, "/mob/living/basic/vestige_patron", "trial_types")
	var/list/patrons = subtypesof(/mob/living/basic/vestige_patron)
	TEST_ASSERT(length(patrons), "no vestige patrons are defined")
	// If the source format ever drifts, this test must fail loudly rather than
	// pass while checking nothing.
	TEST_ASSERT_EQUAL(length(pools), length(patrons), "the boon-pool scan matched [length(pools)] of [length(patrons)] patrons. The source format changed and this test is no longer checking anything")

	var/total_boons = 0
	var/list/owner_of = list()
	for(var/patron_type in pools)
		var/list/pool = pools[patron_type]
		if(!length(pool))
			TEST_FAIL("[patron_type] offers no boons. Every trial it assigns pays out nothing")
			continue
		if(!length(trials[patron_type]))
			TEST_FAIL("[patron_type] has no trials, so nothing can ever be earned from it")
		total_boons += length(pool)
		for(var/datum/vestige_boon/boon_type as anything in pool)
			if(!ispath(boon_type, /datum/vestige_boon))
				TEST_FAIL("[patron_type] lists [boon_type], which is not a /datum/vestige_boon")
				continue
			if(owner_of[boon_type])
				TEST_FAIL("[boon_type] is in both [owner_of[boon_type]]'s and [patron_type]'s pool. Boon pools MUST stay disjoint (see boon_types in patron.dm): a supplicant can take a shared boon elsewhere mid-pact, complete into an empty pool, and spend the trial for nothing with no way to retake it. Give each patron its own /datum/vestige_boon subtype instead.")
				continue
			owner_of[boon_type] = patron_type
			var/prerequisite = initial(boon_type.upgrades_from)
			if(prerequisite && !(prerequisite in pool))
				TEST_FAIL("[patron_type] offers [boon_type], whose upgrades_from ([prerequisite]) is not in the same pool, get_eligible_vestige_boons() can never offer it, so the upgrade is unreachable through this patron.")
	TEST_ASSERT(total_boons > 50, "only [total_boons] boons were scanned across [length(pools)] patrons. The scan is not seeing the real pools")

	// A boon that is neither a spell nor an item has no icon to derive, so it
	// must supply its own or the reward radial renders the generic placeholder.
	for(var/datum/vestige_boon/boon_type as anything in subtypesof(/datum/vestige_boon))
		if(ispath(boon_type, /datum/vestige_boon/spell))
			var/datum/vestige_boon/spell/spell_boon = boon_type
			var/spell_type = initial(spell_boon.spell_type)
			if(spell_type && !ispath(spell_type, /datum/action))
				TEST_FAIL("[boon_type].spell_type ([spell_type]) is not a /datum/action")
			continue
		if(ispath(boon_type, /datum/vestige_boon/item))
			var/datum/vestige_boon/item/item_boon = boon_type
			var/item_type = initial(item_boon.item_type)
			if(item_type && !ispath(item_type, /obj/item))
				TEST_FAIL("[boon_type].item_type ([item_type]) is not an /obj/item")
			continue
		if(!owner_of[boon_type])
			continue // not offered by anyone; the pool check above owns that case
		if(isnull(initial(boon_type.radial_icon)))
			TEST_FAIL("[boon_type] is neither a spell nor an item boon and sets no radial_icon, it renders the generic placeholder in the claim radial")

/datum/unit_test/vestige_ruin_patrons
	priority = TEST_LONGER

/datum/unit_test/vestige_ruin_patrons/Run()
	var/list/patrons = subtypesof(/mob/living/basic/vestige_patron)
	TEST_ASSERT(length(patrons), "no vestige patrons are defined")
	var/list/unplaced = patrons.Copy()
	var/templates_seen = 0
	for(var/ruin_id in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/vestige/template = SSmapping.space_ruins_templates[ruin_id]
		if(!istype(template))
			continue
		templates_seen++
		var/map_path = "[template.prefix][template.suffix]"
		var/text = vc_test_file_text(map_path)
		if(!text)
			TEST_FAIL("[template.name] points at [map_path], which does not exist")
			continue
		var/found = 0
		for(var/patron_type in patrons)
			if(!vc_test_map_has_path(text, patron_type))
				continue
			found++
			unplaced -= patron_type
		if(found != 1)
			TEST_FAIL("[template.suffix] places [found] patrons; every vestige ruin must place exactly one. A ruin with none is a dead end the crew flies to for nothing, and nothing in game says so.")
	TEST_ASSERT(templates_seen >= 10, "only [templates_seen] vestige ruin templates are registered. Expected the full themed set")
	if(length(unplaced))
		TEST_FAIL("these patrons are authored but appear in no vestige ruin map, so they can never be met: [english_list(unplaced)]")

/datum/unit_test/vestige_ascension_wiring
	priority = TEST_LONGER

/datum/unit_test/vestige_ascension_wiring/Run()
	var/list/sources = list()
	vc_test_collect_dm_files(VESTIGE_SOURCE_ROOT, sources)
	var/list/pools = vc_test_scan_list_var(sources, "/mob/living/basic/vestige_patron", "boon_types")
	TEST_ASSERT(length(pools), "the boon-pool scan matched nothing; the capstone-exclusivity check below would pass vacuously")

	var/list/hosts = list()
	var/list/arenas_used = list()
	var/offers = 0
	for(var/datum/vestige_ascension/offer_type as anything in subtypesof(/datum/vestige_ascension))
		offers++
		var/patron_type = initial(offer_type.patron_type)
		var/boss_type = initial(offer_type.boss_type)
		var/boon_type = initial(offer_type.boon_type)
		var/arena_type = initial(offer_type.template_type)
		if(!ispath(patron_type, /mob/living/basic/vestige_patron))
			TEST_FAIL("[offer_type].patron_type ([patron_type]) is not a patron, so get_vestige_ascension() will never key it and the offer is unreachable")
			continue
		if(hosts[patron_type])
			TEST_FAIL("[patron_type] hosts both [hosts[patron_type]] and [offer_type]; get_vestige_ascension() keys offers by host patron and only one survives")
		hosts[patron_type] = offer_type
		if(!ispath(boss_type, /mob/living))
			TEST_FAIL("[offer_type].boss_type ([boss_type]) is not a /mob/living. The run would open an empty arena")
		if(!ispath(boon_type, /datum/vestige_boon))
			TEST_FAIL("[offer_type].boon_type ([boon_type]) is not a boon. The kill would pay out nothing")
		else if(boon_type in pools[patron_type])
			TEST_FAIL("[offer_type]'s capstone [boon_type] is also in [patron_type]'s ordinary boon pool. A plain trial could pay out the capstone without the arena")
		if(!ispath(arena_type, /datum/map_template/vestige_arena))
			TEST_FAIL("[offer_type].template_type ([arena_type]) is not an arena template; open_arena() bails with a log line and the supplicant is told nothing")
			continue
		arenas_used[arena_type] = TRUE
		var/datum/map_template/vestige_arena/arena = arena_type
		var/mappath = initial(arena.mappath)
		var/text = vc_test_file_text(mappath)
		if(!text)
			TEST_FAIL("[offer_type]'s arena map '[mappath]' does not exist. Arena templates bypass SSmapping.map_templates, so a renamed file only fails inside a live one-way attempt.")
			continue
		if(!vc_test_map_has_path(text, /obj/effect/landmark/vestige_arena/entry))
			TEST_FAIL("[mappath] has no entry landmark. The run refuses to open and the supplicant is left standing at the patron")
		if(!vc_test_map_has_path(text, /obj/effect/landmark/vestige_arena/boss))
			TEST_FAIL("[mappath] has no boss landmark, the run refuses to open")
	TEST_ASSERT(offers >= 3, "only [offers] ascension offers are defined; expected one per host patron")
	for(var/arena_type in subtypesof(/datum/map_template/vestige_arena))
		if(!arenas_used[arena_type])
			TEST_FAIL("[arena_type] is authored but no /datum/vestige_ascension points at it. The arena can never be opened")

#undef VESTIGE_SOURCE_ROOT
