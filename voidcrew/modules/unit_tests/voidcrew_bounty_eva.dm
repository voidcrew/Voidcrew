/**
 * Bounty hunting: pressure suits (voidcrew/modules/bounties/bounty_eva.dm).
 *
 * Fork defines are included after the tests, so a test uses the literal value with a comment naming
 * the define. The air is emptied on the test room's own floor and put back; breathe() is called by
 * hand, so nothing waits on Life().
 */

/// Holds the helpers the pressure suit tests share
/datum/unit_test/voidcrew_bounty_eva
	abstract_type = /datum/unit_test/voidcrew_bounty_eva
	/// The air on the test floor before it was emptied
	var/datum/gas_mixture/saved_air

/datum/unit_test/voidcrew_bounty_eva/Destroy()
	refill()
	return ..()

/// Empties the air on the test floor
/datum/unit_test/voidcrew_bounty_eva/proc/empty_air()
	var/turf/open/floor = run_loc_floor_bottom_left
	if(!saved_air)
		saved_air = floor.air.copy()
	floor.air.remove_ratio(1)

/// Puts the test floor's air back
/datum/unit_test/voidcrew_bounty_eva/proc/refill()
	var/turf/open/floor = run_loc_floor_bottom_left
	if(saved_air && floor?.air)
		floor.air.copy_from(saved_air)
	saved_air = null

/// A criminal on the test floor, wanted on nothing
/datum/unit_test/voidcrew_bounty_eva/proc/new_criminal(archetype = "normal", tier = 1)
	var/datum/bounty_record/record = new
	record.archetype = archetype
	record.tier = tier
	record.style = "brawler" // BOUNTY_STYLE_BRAWLER
	record.species = /datum/species/human
	record.gender = MALE
	record.name = "Test Criminal"
	record.look = bounty_roll_look(record.species, record.gender)
	var/mob/living/basic/bounty_criminal/criminal = spawn_bounty_criminal(record, run_loc_floor_bottom_left, null)
	LAZYADD(allocated, criminal)
	return criminal

/// The air check: a room's air is breathable, an emptied one and space are not
/datum/unit_test/voidcrew_bounty_eva/air/Run()
	TEST_ASSERT(bounty_air_safe(run_loc_floor_bottom_left), "The test room's air is not breathable")
	empty_air()
	TEST_ASSERT(!bounty_air_safe(run_loc_floor_bottom_left), "Emptied air is breathable")
	refill()
	TEST_ASSERT(!bounty_air_safe(null), "Nowhere is breathable")

/// Out of a suit in vacuum, a criminal on its feet chokes past the mercy line to death
/datum/unit_test/voidcrew_bounty_eva/choke/Run()
	var/mob/living/basic/bounty_criminal/criminal = new_criminal()
	var/datum/component/bounty_eva/eva = criminal.GetComponent(/datum/component/bounty_eva)
	TEST_ASSERT(eva, "A criminal has no pressure suit component")
	TEST_ASSERT(!eva.sealed(), "A criminal in a breathable room arrived suited")
	eva.breathe(5)
	TEST_ASSERT_EQUAL(criminal.health, criminal.maxHealth, "A criminal choked in breathable air")
	empty_air()
	for(var/i in 1 to 20)
		eva.breathe(5)
		if(criminal.stat == DEAD)
			break
	TEST_ASSERT_EQUAL(criminal.stat, DEAD, "A criminal out of a suit lived through vacuum")
	refill()
	qdel(criminal)

/// Suited, vacuum does nothing; a helmet taken off is a suit no longer sealed
/datum/unit_test/voidcrew_bounty_eva/sealed/Run()
	var/mob/living/basic/bounty_criminal/criminal = new_criminal()
	var/datum/component/bounty_eva/eva = criminal.GetComponent(/datum/component/bounty_eva)
	eva.kit_up(null)
	TEST_ASSERT(eva.sealed(), "A soft suit with its helmet is not sealed")
	TEST_ASSERT(eva.helmet?.loc == criminal && eva.suit?.loc == criminal, "The soft suit isn't on them")
	empty_air()
	eva.breathe(10)
	TEST_ASSERT_EQUAL(criminal.health, criminal.maxHealth, "A suited criminal choked in vacuum")
	var/obj/item/helmet = eva.helmet
	helmet.forceMove(run_loc_floor_top_right)
	TEST_ASSERT_NULL(eva.helmet, "A helmet that left them is still worn")
	TEST_ASSERT(!eva.sealed(), "A suit without its helmet is sealed")
	eva.breathe(5)
	TEST_ASSERT(criminal.health < criminal.maxHealth, "A criminal without a helmet didn't choke in vacuum")
	refill()
	// What fits: a pressure-proof helmet back on; a modsuit only with the soft suit off; nothing over a worn piece
	TEST_ASSERT(eva.fits("helmet", helmet), "A space helmet doesn't fit an empty head") // BOUNTY_EVA_HELMET
	var/obj/item/clothing/head/beanie/hat = allocate(/obj/item/clothing/head/beanie)
	TEST_ASSERT(!eva.fits("helmet", hat), "A beanie counts as a space helmet")
	var/obj/item/mod/control/pre_equipped/standard/modsuit = allocate(/obj/item/mod/control/pre_equipped/standard)
	TEST_ASSERT(!eva.fits("mod", modsuit), "A modsuit fits over a soft suit") // BOUNTY_EVA_MOD
	qdel(helmet)
	qdel(criminal)
	TEST_ASSERT(QDELETED(eva.suit) || isnull(eva.suit), "Their suit outlived them")

/// The outfit for their look: a modsuit on the back and nothing in its slots, a soft suit over the clothes
/datum/unit_test/voidcrew_bounty_eva/outfits/Run()
	var/mob/living/basic/bounty_criminal/criminal = new_criminal()
	var/datum/component/bounty_eva/eva = criminal.GetComponent(/datum/component/bounty_eva)
	TEST_ASSERT_EQUAL(eva.worn_outfit(/datum/outfit/bounty_criminal/tough), /datum/outfit/bounty_criminal/tough, "Unsuited, the outfit changed")
	eva.kit_up(/obj/item/mod/control/pre_equipped/standard)
	var/datum/outfit/modded = eva.worn_outfit(/datum/outfit/bounty_criminal/tough)
	TEST_ASSERT(istype(modded), "A modsuit's outfit isn't an outfit")
	TEST_ASSERT_EQUAL(modded.back, /obj/item/mod/control/pre_equipped/standard, "The modsuit isn't on their back")
	TEST_ASSERT(isnull(modded.suit) && isnull(modded.head) && isnull(modded.gloves) && isnull(modded.shoes), "A modsuit's slots are still taken")
	TEST_ASSERT_EQUAL(modded.uniform, /datum/outfit/bounty_criminal/tough::uniform, "The clothes under a modsuit were lost")
	qdel(criminal)

/// Who arrives suited: by kit for a mini-boss, a work modsuit for a Wanted normal criminal, a soft suit for the rest
/datum/unit_test/voidcrew_bounty_eva/gear/Run()
	TEST_ASSERT_NULL(bounty_eva_criminal_gear(new_criminal("meek", 2)), "A meek criminal wears a modsuit")
	TEST_ASSERT_NULL(bounty_eva_criminal_gear(new_criminal("normal", 1)), "A petty criminal wears a modsuit")
	TEST_ASSERT(ispath(bounty_eva_criminal_gear(new_criminal("normal", 2)), /obj/item/mod/control), "A Wanted criminal wears no modsuit")
	var/datum/bounty_record/record = new
	record.archetype = "boss" // BOUNTY_ARCHETYPE_BOSS
	record.tier = 3
	record.kit = "pyromaniac" // BOUNTY_KIT_PYROMANIAC
	var/mob/living/basic/bounty_criminal/boss = spawn_bounty_criminal(record, run_loc_floor_bottom_left, null)
	LAZYADD(allocated, boss)
	TEST_ASSERT_EQUAL(bounty_eva_criminal_gear(boss), /obj/item/mod/control/pre_equipped/atmospheric, "A pyromaniac's modsuit isn't the atmospheric one")
	// Placement: a ruin always suits them; a pirate ship or a breathable room never
	var/datum/criminal_bounty/ruin_posting = new
	ruin_posting.placement_kind = "ruin" // BOUNTY_PLACEMENT_RUIN
	TEST_ASSERT(bounty_site_needs_eva(ruin_posting, run_loc_floor_bottom_left), "A criminal at a space ruin needs no suit")
	var/datum/criminal_bounty/ship_posting = new
	ship_posting.placement_kind = "npc_ship" // BOUNTY_PLACEMENT_NPC_SHIP
	TEST_ASSERT(!bounty_site_needs_eva(ship_posting, run_loc_floor_bottom_left), "A criminal aboard a pressurised ship needs a suit")
	empty_air()
	TEST_ASSERT(bounty_site_needs_eva(ship_posting, run_loc_floor_bottom_left), "A criminal standing in vacuum needs no suit")
	refill()

/// Companions: a face of the species pool, and suited when their criminal is
/datum/unit_test/voidcrew_bounty_eva/companions/Run()
	var/mob/living/basic/bounty_criminal/criminal = new_criminal()
	var/datum/component/bounty_eva/eva = criminal.GetComponent(/datum/component/bounty_eva)
	eva.kit_up(null)
	var/list/buddies = criminal.spawn_companions(2)
	TEST_ASSERT(length(buddies), "No companions spawned")
	for(var/mob/living/basic/bounty_companion/buddy as anything in buddies)
		TEST_ASSERT(buddy.eva_look?.species in GLOB.bounty_species_weights, "A companion's species ([buddy.eva_look?.species]) isn't from the pool")
		TEST_ASSERT(ispath(buddy.eva_base_outfit, /datum/outfit), "A companion has no clothes")
		var/datum/component/bounty_eva/buddy_eva = buddy.GetComponent(/datum/component/bounty_eva)
		TEST_ASSERT(buddy_eva?.sealed(), "A suited criminal's companion isn't suited")
		qdel(buddy)
	qdel(criminal)

/**
 * Not a check: draws each suited look to data/bounty_eva_renders/ for a person to look at. A dummy
 * per look, facing south.
 */
/datum/unit_test/voidcrew_bounty_eva/renders/Run()
	var/list/looks = list(
		"plain_tough" = list(/datum/species/human, /datum/outfit/bounty_criminal/tough, null),
		"soft_eva" = list(/datum/species/human, /datum/outfit/bounty_criminal/tough, list(/obj/item/clothing/suit/space/eva, /obj/item/clothing/head/helmet/space/eva)),
		"soft_grey" = list(/datum/species/lizard, /datum/outfit/bounty_criminal/hauler, list(/obj/item/clothing/suit/space, /obj/item/clothing/head/helmet/space)),
		"soft_nasa" = list(/datum/species/moth, /datum/outfit/bounty_criminal/spacer, list(/obj/item/clothing/suit/space/nasavoid, /obj/item/clothing/head/helmet/space/nasavoid)),
		"soft_orange" = list(/datum/species/human/felinid, /datum/outfit/hermit/survivor, list(/obj/item/clothing/suit/space/orange, /obj/item/clothing/head/helmet/space/orange)),
		"mod_standard" = list(/datum/species/human, /datum/outfit/bounty_criminal/hauler, /obj/item/mod/control/pre_equipped/standard),
		"mod_civilian" = list(/datum/species/ethereal, /datum/outfit/bounty_criminal/hauler, /obj/item/mod/control/pre_equipped/civilian),
		"mod_engineering" = list(/datum/species/human, /datum/outfit/bounty_criminal/hauler, /obj/item/mod/control/pre_equipped/engineering),
		"boss_juggernaut_loader" = list(/datum/species/human, /datum/outfit/bounty_boss/juggernaut, /obj/item/mod/control/pre_equipped/loader),
		"boss_pyromaniac_atmos" = list(/datum/species/lizard, /datum/outfit/bounty_boss/pyromaniac, /obj/item/mod/control/pre_equipped/atmospheric),
		"boss_demolitionist_research" = list(/datum/species/human, /datum/outfit/bounty_boss/demolitionist, /obj/item/mod/control/pre_equipped/research),
		"boss_ghost_standard" = list(/datum/species/moth, /datum/outfit/bounty_boss/ghost, /obj/item/mod/control/pre_equipped/standard),
		"companion_pirate_lizard" = list(/datum/species/lizard, /datum/outfit/outpost_off_duty_pirate, null),
		"companion_hunter_pod" = list(/datum/species/pod, /datum/outfit/hermit/survivor/hunter, null),
		"companion_drifter_jelly" = list(/datum/species/jelly, /datum/outfit/bounty_criminal/drifter, null),
	)
	var/mob/living/basic/bounty_criminal/criminal = new_criminal()
	var/datum/component/bounty_eva/eva = criminal.GetComponent(/datum/component/bounty_eva)
	for(var/look_name in looks)
		var/list/spec = looks[look_name]
		for(var/obj/item/piece as anything in eva.pieces())
			qdel(piece)
		eva.suit = null
		eva.helmet = null
		eva.mod = null
		var/gear = spec[3]
		if(islist(gear))
			var/suit_type = gear[1]
			var/helmet_type = gear[2]
			eva.suit = new suit_type(criminal)
			eva.helmet = new helmet_type(criminal)
		else if(ispath(gear))
			eva.mod = new gear(criminal)
		var/datum/bounty_look/look = bounty_roll_look(spec[1], MALE)
		var/mob/living/carbon/human/dummy/dummy = bounty_look_dummy(look, eva.worn_outfit(spec[2]), null)
		TEST_ASSERT(dummy, "The [look_name] look could not be built")
		if(!dummy)
			continue
		dummy.setDir(SOUTH)
		fcopy(getFlatIcon(dummy, SOUTH), "data/bounty_eva_renders/[look_name].png")
		qdel(dummy)
