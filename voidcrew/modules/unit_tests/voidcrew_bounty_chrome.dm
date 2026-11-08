/// A piece for the tests only: weight 0, so it never rolls. It counts the hooks it gets.
/datum/bounty_chrome/unit_test
	key = "unit_test"
	name = "test chrome"
	weight = 0
	organ_looks = list(/obj/item/organ/cyberimp/cyberware/cascade)
	examine_text = "%THEIR test chrome hums."
	var/fights = 0
	var/ticks = 0
	var/emps = 0
	var/reboots = 0

/datum/bounty_chrome/unit_test/on_fight_start(atom/target)
	fights++

/datum/bounty_chrome/unit_test/on_tick(seconds_per_tick, fighting)
	ticks++

/datum/bounty_chrome/unit_test/on_emp(severity)
	emps++

/datum/bounty_chrome/unit_test/on_reboot()
	reboots++

/// The chrome framework: rolling, installing, the hooks, an EMP, examine, and the worn look on the dummy
/datum/unit_test/voidcrew_bounty_chrome

/datum/unit_test/voidcrew_bounty_chrome/Run()
	// Rolling: every key a roll gives is a real piece; nobody gets a piece that doesn't suit them
	for(var/i in 1 to 50)
		for(var/key in bounty_roll_chrome(3, "normal", "pistol", null)) // BOUNTY_TIER_MOST_WANTED, BOUNTY_ARCHETYPE_NORMAL
			var/datum/bounty_chrome/proto = GLOB.bounty_chrome_protos[key]
			TEST_ASSERT_NOTNULL(proto, "A roll gave the unknown chrome [key]")
			TEST_ASSERT(proto.can_roll(3, "normal", "pistol", null, list()), "A roll gave [key], which doesn't suit a pistol criminal")
	var/datum/bounty_chrome/test_proto = GLOB.bounty_chrome_protos["unit_test"]
	TEST_ASSERT_NOTNULL(test_proto, "The test piece has no prototype")
	for(var/i in 1 to 20)
		TEST_ASSERT(!("unit_test" in bounty_roll_chrome(3, "normal", "brawler", null)), "A weight 0 piece rolled")
	// A companion's roll is one key, in a list the install takes as it is (companions joining used to wrap it again and get nothing)
	var/list/companion_roll
	for(var/i in 1 to 500)
		companion_roll = bounty_roll_companion_chrome(3, "knife") // BOUNTY_TIER_MOST_WANTED, BOUNTY_STYLE_KNIFE
		if(companion_roll)
			break
	TEST_ASSERT(islist(companion_roll) && length(companion_roll) == 1, "A companion's chrome roll gave [companion_roll || "nothing in 500 tries"], not one key")
	var/mob/living/basic/bounty_companion/rolled_buddy = allocate(/mob/living/basic/bounty_companion, run_loc_floor_bottom_left)
	bounty_chrome_install(rolled_buddy, companion_roll)
	TEST_ASSERT_NOTNULL(bounty_chrome_piece(rolled_buddy, companion_roll[1]), "A companion's rolled [companion_roll[1]] didn't go in")

	// Installing, and the hooks
	var/mob/living/basic/bounty_criminal/normal/criminal = allocate(/mob/living/basic/bounty_criminal/normal, run_loc_floor_bottom_left)
	var/datum/component/bounty_chrome/chrome = bounty_chrome_install(criminal, list("unit_test"))
	TEST_ASSERT_NOTNULL(chrome, "Installing chrome gave no component")
	var/datum/bounty_chrome/unit_test/piece = bounty_chrome_piece(criminal, "unit_test")
	TEST_ASSERT_NOTNULL(piece, "The installed piece can't be found")
	TEST_ASSERT_EQUAL(piece.owner, criminal, "The piece isn't in its criminal")
	bounty_chrome_install(criminal, list("unit_test"))
	TEST_ASSERT_EQUAL(length(chrome.pieces), 1, "Installing the same piece twice gave two")
	chrome.fight_started(null)
	chrome.tick(2)
	TEST_ASSERT_EQUAL(piece.fights, 1, "The piece didn't hear the fight start")
	TEST_ASSERT_EQUAL(piece.ticks, 1, "The piece didn't tick")

	// An EMP knocks it out, and it comes back
	criminal.emp_act(EMP_HEAVY)
	TEST_ASSERT_EQUAL(piece.emps, 1, "An EMP didn't reach the piece")
	TEST_ASSERT(!piece.online(), "The piece works through an EMP")
	chrome.tick(2)
	TEST_ASSERT_EQUAL(piece.ticks, 1, "A piece down from an EMP still ticks")
	criminal.emp_act(EMP_HEAVY)
	TEST_ASSERT_EQUAL(piece.emps, 1, "A second EMP hit a piece already down")
	piece.offline_until = world.time
	chrome.tick(2)
	TEST_ASSERT_EQUAL(piece.reboots, 1, "The piece never came back from the EMP")
	TEST_ASSERT(piece.online(), "The piece is still down after its reboot")

	// Examining shows it
	var/list/examined = criminal.examine(criminal)
	var/found = FALSE
	for(var/line in examined)
		if(findtext(line, "test chrome hums"))
			found = TRUE
	TEST_ASSERT(found, "Examining them doesn't show their chrome")

	// Cyber optics read it: each piece as its real implant, OFFLINE while down
	bounty_chrome_install(criminal, list("gorilla")) // BOUNTY_CHROME_GORILLA
	var/report = jointext(bounty_chrome_scan_readout(criminal), " ")
	TEST_ASSERT(findtext(report, "GORILLA ARMS"), "A chrome read doesn't name their Gorilla Arms: [report]")
	TEST_ASSERT(findtext(report, "SIGNATURES 2"), "A chrome read miscounts their chrome: [report]")
	TEST_ASSERT(!findtextEx(report, "· T"), "A chrome read labels a piece with its tier: [report]")
	var/datum/bounty_chrome/gorilla_piece = bounty_chrome_piece(criminal, "gorilla")
	gorilla_piece.offline_until = world.time + 10 SECONDS
	TEST_ASSERT(findtext(jointext(bounty_chrome_scan_readout(criminal), " "), "OFFLINE"), "An EMP'd piece doesn't read offline")
	gorilla_piece.offline_until = 0
	var/mob/living/basic/bounty_criminal/normal/clean = allocate(/mob/living/basic/bounty_criminal/normal, run_loc_floor_top_right)
	TEST_ASSERT(findtext(jointext(bounty_chrome_scan_readout(clean), " "), "NO HARDWARE SIGNATURE"), "A criminal with no chrome reads as chromed")
	TEST_ASSERT_NULL(bounty_chrome_scan_readout(allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)), "A bounty chrome read answered for a player")

	// The worn look: the implant goes into the look dummy
	var/datum/bounty_look/look = bounty_roll_look(/datum/species/human, MALE)
	var/mob/living/carbon/human/dummy/dummy = bounty_look_dummy(look, null, null, chrome_organs = bounty_chrome_organ_looks(list("unit_test")))
	TEST_ASSERT_NOTNULL(dummy, "The look dummy failed with chrome")
	TEST_ASSERT_NOTNULL(locate(/obj/item/organ/cyberimp/cyberware/cascade) in dummy.organs, "The chrome's implant isn't in the look dummy")
	qdel(dummy)

	// Gone with the component, and no hooks after death
	qdel(chrome)
	TEST_ASSERT_NULL(piece.owner, "A removed piece kept its owner")

/// Chrome carriers are dressed light enough that their worn chrome shows: renders every piece in every criminal outfit, and checks the clothes come off
/datum/unit_test/voidcrew_bounty_chrome/exposed

/datum/unit_test/voidcrew_bounty_chrome/exposed/Run()
	var/list/outfits = list(
		"local" = /datum/outfit/bounty_criminal/local,
		"spacer" = /datum/outfit/bounty_criminal/spacer,
		"hauler" = /datum/outfit/bounty_criminal/hauler,
		"drifter" = /datum/outfit/bounty_criminal/drifter,
		"tough" = /datum/outfit/bounty_criminal/tough,
	)
	var/list/look_sets = list(
		"none" = list(),
		"gorilla" = list("gorilla"),
		"mantis" = list("mantis"),
		"cascade" = list("cascade"),
		"redline" = list("redline"),
		"piledriver" = list("piledriver"),
		"cascade_gorilla" = list("cascade", "gorilla"),
	)
	var/datum/bounty_look/look = bounty_roll_look(/datum/species/human, MALE)
	for(var/set_name in look_sets)
		var/list/organs = bounty_chrome_organ_looks(look_sets[set_name])
		for(var/outfit_name in outfits)
			var/mob/living/carbon/human/dummy/dummy = bounty_look_dummy(look, outfits[outfit_name], null, chrome_organs = organs)
			TEST_ASSERT_NOTNULL(dummy, "[set_name] in [outfit_name]: the look failed")
			if(set_name == "gorilla")
				TEST_ASSERT_NULL(dummy.gloves, "[set_name] in [outfit_name]: gloves still cover the arms")
				TEST_ASSERT_NULL(dummy.wear_suit, "[set_name] in [outfit_name]: a jacket still covers the arms")
			if(set_name == "cascade" || set_name == "gorilla")
				var/obj/item/clothing/under/uniform = dummy.w_uniform
				TEST_ASSERT(istype(uniform, /obj/item/clothing/under/pants) || uniform?.adjusted == ALT_STYLE, "[set_name] in [outfit_name]: a shirt still covers the chrome")
			if(set_name == "piledriver")
				TEST_ASSERT(istype(dummy.w_uniform, /obj/item/clothing/under/shorts), "[set_name] in [outfit_name]: trousers still cover the legs")
#ifdef BOUNTY_CHROME_RENDERS
			// Only when asked for (dm.exe -DBOUNTY_CHROME_RENDERS): renders to look at, into data/
			fcopy(getFlatIcon(dummy, SOUTH), "data/bounty_chrome_renders/exposed_[set_name]_[outfit_name]_s.png")
			fcopy(getFlatIcon(dummy, NORTH), "data/bounty_chrome_renders/exposed_[set_name]_[outfit_name]_n.png")
#endif
			qdel(dummy)

/// Everything examining `fighter` shows `viewer`, as one text
/datum/unit_test/voidcrew_bounty_chrome/proc/examined(mob/living/fighter, mob/viewer)
	return jointext(fighter.examine(viewer), "\n")

/**
 * What examining a chromed fighter shows: its chrome while it is on show, none of it while it passes
 * as a patron, hides or wears a pressure suit, sparks while an EMP has it down, and one line once it is
 * dead, when a chrome read also finds it all offline.
 */
/datum/unit_test/voidcrew_bounty_chrome/shows

/datum/unit_test/voidcrew_bounty_chrome/shows/Run()
	var/mob/living/carbon/human/consistent/viewer = allocate(__IMPLIED_TYPE__, run_loc_floor_top_right)
	var/mob/living/basic/bounty_criminal/normal/criminal = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	bounty_chrome_install(criminal, list("unit_test"))
	var/datum/bounty_chrome/unit_test/piece = bounty_chrome_piece(criminal, "unit_test")
	// The test piece's line starts with a placeholder, and still starts with a capital
	var/line = capitalize("[criminal.p_their()] test chrome hums.")
	TEST_ASSERT(findtextEx(examined(criminal, viewer), line), "Examining them doesn't show '[line]': [examined(criminal, viewer)]")

	criminal.blended = TRUE
	TEST_ASSERT(!findtext(examined(criminal, viewer), "test chrome"), "A fighter passing as a patron shows their chrome")
	criminal.blended = FALSE
	criminal.hidden = TRUE
	TEST_ASSERT(!findtext(examined(criminal, viewer), "test chrome"), "A hidden fighter shows their chrome")
	criminal.hidden = FALSE

	// Down from an EMP, it sparks
	piece.offline_until = world.time + 10 SECONDS
	TEST_ASSERT(findtext(examined(criminal, viewer), "Sparks crawl over"), "Chrome down from an EMP examines as working")
	piece.offline_until = 0
	TEST_ASSERT(!findtext(examined(criminal, viewer), "Sparks crawl over"), "Working chrome sparks")

	// Under a pressure suit it doesn't show
	var/datum/component/bounty_eva/eva = criminal.GetComponent(/datum/component/bounty_eva)
	TEST_ASSERT_NOTNULL(eva, "A criminal has no suit to put on")
	eva.kit_up(null)
	TEST_ASSERT(!findtext(examined(criminal, viewer), "test chrome"), "Chrome shows through a pressure suit")
	eva.own_suit = null
	eva.own_helmet = null
	TEST_ASSERT(findtext(examined(criminal, viewer), "test chrome"), "Chrome doesn't show once the suit is off")
	// A modsuit covers it too
	eva.kit_up(/obj/item/mod/control/pre_equipped/standard)
	TEST_ASSERT(!findtext(examined(criminal, viewer), "test chrome"), "Chrome shows through a modsuit")
	eva.own_mod = null

	// Dead, it is burnt out: one line, and a chrome read finds it offline
	criminal.death()
	var/dead_text = examined(criminal, viewer)
	TEST_ASSERT(findtext(dead_text, "chrome is burnt out") && !findtext(dead_text, "test chrome"), "Dead chrome examines as working: [dead_text]")
	TEST_ASSERT(findtext(jointext(bounty_chrome_scan_readout(criminal), " "), "OFFLINE"), "Dead chrome reads as working")

/**
 * Chrome makes a normal criminal or a companion tougher, BOUNTY_CHROME_HEALTH_PER_PIECE (0.15) a piece
 * on top of the rest of its health, from the start; put in someone already hurt, it raises the
 * ceiling and never their health. Companions never roll Lazarus.
 */
/datum/unit_test/voidcrew_bounty_chrome/health

/datum/unit_test/voidcrew_bounty_chrome/health/Run()
	// Two pieces that leave a pistol a pistol
	var/datum/bounty_record/chromed_record = new
	chromed_record.archetype = "normal" // BOUNTY_ARCHETYPE_NORMAL
	chromed_record.tier = 2 // BOUNTY_TIER_WANTED
	chromed_record.style = "pistol" // BOUNTY_STYLE_PISTOL
	chromed_record.chrome = list("cascade", "lazarus") // BOUNTY_CHROME_CASCADE, BOUNTY_CHROME_LAZARUS
	var/mob/living/basic/bounty_criminal/normal/chromed = spawn_bounty_criminal(chromed_record, run_loc_floor_bottom_left, null)
	allocated += chromed
	var/datum/bounty_record/plain_record = new
	plain_record.archetype = "normal"
	plain_record.tier = 2
	plain_record.style = "pistol"
	var/mob/living/basic/bounty_criminal/normal/plain = spawn_bounty_criminal(plain_record, run_loc_floor_bottom_left, null)
	allocated += plain
	TEST_ASSERT(abs(chromed.maxHealth - plain.maxHealth * 1.3) <= 2, "Two pieces of chrome gave [chromed.maxHealth] health over a plain [plain.maxHealth], not 30% more")
	TEST_ASSERT_EQUAL(chromed.health, chromed.maxHealth, "A chromed criminal didn't start at full health")

	// Sized up against a crew, its chrome's share comes along: three hunters make it twice its chromed health (BOUNTY_NORMAL_POSSE_HEALTH 50)
	var/chromed_max = chromed.maxHealth
	var/list/crew = list()
	for(var/dx in 1 to 3)
		var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
		hunter.mind_initialize()
		chromed.body_add_grudge(hunter)
		crew += hunter
	TEST_ASSERT(chromed.body_size_up(crew[1], engaging = TRUE), "A crew of three didn't size up a chromed criminal")
	TEST_ASSERT_EQUAL(chromed.maxHealth, chromed_max * 2, "A chromed criminal fighting three has [chromed.maxHealth] health, not twice its [chromed_max]")
	TEST_ASSERT(abs(chromed.damage_coeff[STAMINA] - 100 / chromed.maxHealth) < 0.0001, "The chromed criminal's stamina pool didn't follow its health")

	// Hurt, then chrome put in: a higher ceiling, the same health
	plain.adjustBruteLoss(40)
	var/before = plain.health
	var/old_max = plain.maxHealth
	bounty_chrome_install(plain, list("unit_test"))
	TEST_ASSERT(plain.maxHealth > old_max, "Chrome put in didn't raise their max health from [old_max]")
	TEST_ASSERT(abs(plain.health - before) < 0.01, "Chrome put in a hurt criminal took them from [before] to [plain.health] health")

	// A companion: the same share on its own health
	var/mob/living/basic/bounty_criminal/normal/leader = allocate(__IMPLIED_TYPE__, run_loc_floor_top_right)
	var/list/buddies = leader.spawn_companions(1)
	TEST_ASSERT(length(buddies), "No companion spawned")
	allocated += buddies
	var/mob/living/basic/bounty_companion/buddy = buddies[1]
	qdel(buddy.GetComponent(/datum/component/bounty_chrome))
	buddy.ai_take_style("knife") // BOUNTY_STYLE_KNIFE
	var/bare = buddy.maxHealth
	bounty_chrome_install(buddy, list("cascade"))
	TEST_ASSERT(abs(buddy.maxHealth - bare * 1.15) <= 1, "A piece of chrome took a companion from [bare] to [buddy.maxHealth] health, not 15% more")
	TEST_ASSERT_EQUAL(buddy.health, buddy.maxHealth, "A fresh companion's chrome left them hurt")
	// A hurt companion put on a tougher style keeps the health it had
	buddy.adjustBruteLoss(30)
	var/hurt_health = buddy.health
	buddy.ai_take_style("brawler") // BOUNTY_STYLE_BRAWLER, the toughest
	TEST_ASSERT(abs(buddy.health - hurt_health) < 0.01, "A new style took a hurt companion from [hurt_health] to [buddy.health] health")

	// Never Lazarus on a companion: a stamina takedown is the answer to every one of them
	for(var/i in 1 to 300)
		TEST_ASSERT(!("lazarus" in bounty_roll_companion_chrome(3, "knife")), "A companion rolled Lazarus") // BOUNTY_TIER_MOST_WANTED, BOUNTY_CHROME_LAZARUS

/// An area move catches only those in the fight: whoever it is going for and anyone who attacked it, never a bystander on the site
/datum/unit_test/voidcrew_bounty_chrome/posse

/datum/unit_test/voidcrew_bounty_chrome/posse/Run()
	var/mob/living/basic/bounty_criminal/normal/criminal = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/bystander = allocate(__IMPLIED_TYPE__, run_loc_floor_top_right)
	bystander.mind_initialize()
	var/mob/living/carbon/human/consistent/attacker = allocate(__IMPLIED_TYPE__, run_loc_floor_top_right)
	attacker.mind_initialize()
	TEST_ASSERT(bounty_ai_may_hit(criminal, bystander), "On its site it may not hit a person at all")
	TEST_ASSERT(!bounty_chrome_may_splash(criminal, bystander), "An area move catches a bystander")
	TEST_ASSERT(bounty_chrome_may_splash(criminal, bystander, bystander), "A move spares the one it is aimed at")
	criminal.body_add_grudge(attacker)
	TEST_ASSERT(bounty_chrome_may_splash(criminal, attacker), "An area move spares someone who attacked it")
	criminal.ai_controller?.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, bystander)
	TEST_ASSERT(bounty_chrome_may_splash(criminal, bystander), "An area move spares the one it is going for")
	criminal.ai_controller?.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)

/// A calm fighter feels a chrome read and tells the reader off, once in a while; passing as a patron, or with no chrome, they never do
/datum/unit_test/voidcrew_bounty_chrome/read_noticed

/datum/unit_test/voidcrew_bounty_chrome/read_noticed/Run()
	var/mob/living/carbon/human/consistent/reader = allocate(__IMPLIED_TYPE__, run_loc_floor_top_right)
	var/mob/living/basic/bounty_criminal/normal/criminal = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	bounty_chrome_install(criminal, list("unit_test"))
	criminal.blended = TRUE
	TEST_ASSERT(!bounty_chrome_read_noticed(criminal, reader), "A fighter passing as a patron felt a read")
	criminal.blended = FALSE
	TEST_ASSERT(bounty_chrome_read_noticed(criminal, reader), "A calm fighter with chrome didn't feel a read")
	TEST_ASSERT(!bounty_chrome_read_noticed(criminal, reader), "A fighter told off two reads in a row")
	var/mob/living/basic/bounty_criminal/normal/clean = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	TEST_ASSERT(!bounty_chrome_read_noticed(clean, reader), "A fighter with no chrome felt a read")

/**
 * A chromed fugitive passing as a patron looks and examines like its decoys: nothing of its chrome in
 * its look and nothing taken off over it, no chrome lines, and a chrome read finds nothing. Once the
 * act is over, the chrome is on show again. P6's helpers (voidcrew_bounty_outpost.dm) make the outpost.
 */
/datum/unit_test/voidcrew_bounty_outpost/chrome_fugitive

/datum/unit_test/voidcrew_bounty_outpost/chrome_fugitive/Run()
	outpost = make_outpost(/obj/structure/overmap/trader_outpost/general)
	var/datum/criminal_bounty/outpost_test/posting = make_posting(null, /mob/living/basic/bounty_criminal/normal)
	var/datum/bounty_record/record = posting.record
	record.archetype = "normal" // BOUNTY_ARCHETYPE_NORMAL
	record.style = "brawler" // BOUNTY_STYLE_BRAWLER
	// Plating on both arms, which the patron's jacket would come off over
	record.chrome = list("gorilla") // BOUNTY_CHROME_GORILLA
	var/mob/living/basic/bounty_criminal/fugitive = posting.criminal()
	bounty_chrome_install(fugitive, record.chrome)
	TEST_ASSERT(posting.setup_outpost_blend(), "The posting could not be set up to blend in")
	var/list/decoys = decoys_of(posting)
	TEST_ASSERT(length(decoys), "No decoys to compare with")
	var/mob/living/basic/bounty_criminal/decoy/decoy = decoys[1]
	decoy.gender = fugitive.gender
	var/mob/living/carbon/human/viewer = make_hunter()

	// Examine: a decoy's, with no chrome in it, and a chrome read finds nothing
	var/datum/bounty_chrome/gorilla = bounty_chrome_piece(fugitive, "gorilla")
	var/chrome_line = replacetext(replacetext(gorilla.examine_line(), "%THEIR", fugitive.p_their()), "%THEY", fugitive.p_they())
	TEST_ASSERT(!findtext(plain_examine(fugitive, viewer), chrome_line), "The blended fugitive's chrome shows on examine")
	TEST_ASSERT_EQUAL(plain_examine(decoy, viewer), plain_examine(fugitive, viewer), "The chromed fugitive examines differently from a decoy")
	TEST_ASSERT(findtext(jointext(bounty_chrome_scan_readout(fugitive), " "), "NO HARDWARE SIGNATURE"), "A chrome read finds the blended fugitive's chrome")

	// The look: the patron's clothes all on, as on a decoy, and no implant drawn
	var/outfit = bounty_outpost_outfit(outpost)
	var/mob/living/carbon/human/dummy/blended_look = new
	var/mob/living/carbon/human/dummy/decoy_look = new
	TEST_ASSERT(bounty_dress_record_dummy(blended_look, record, outfit, TRUE), "The fugitive's patron look failed")
	TEST_ASSERT(bounty_dress_record_dummy(decoy_look, decoy.record, outfit), "The decoy's patron look failed")
	for(var/slot in list(ITEM_SLOT_OCLOTHING, ITEM_SLOT_GLOVES, ITEM_SLOT_ICLOTHING, ITEM_SLOT_FEET))
		var/obj/item/fugitive_wears = blended_look.get_item_by_slot(slot)
		var/obj/item/decoy_wears = decoy_look.get_item_by_slot(slot)
		TEST_ASSERT_EQUAL(fugitive_wears?.type, decoy_wears?.type, "Passing as a patron, the fugitive wears [fugitive_wears?.type || "nothing"] where a decoy wears [decoy_wears?.type || "nothing"]")
	var/obj/item/clothing/under/fugitive_uniform = blended_look.w_uniform
	var/obj/item/clothing/under/decoy_uniform = decoy_look.w_uniform
	TEST_ASSERT_EQUAL(fugitive_uniform?.adjusted, decoy_uniform?.adjusted, "Passing as a patron, the fugitive wears their shirt differently from a decoy")
	for(var/obj/item/organ/cyberimp/implant in blended_look.organs)
		TEST_FAIL("Passing as a patron, the fugitive's look has [implant] in it")
	qdel(blended_look)
	qdel(decoy_look)

	// Out of the act, in the same clothes: the plating shows, with the jacket and gloves off
	var/mob/living/carbon/human/dummy/exposed_look = new
	TEST_ASSERT(bounty_dress_record_dummy(exposed_look, record, outfit), "The fugitive's exposed look failed")
	TEST_ASSERT_NOTNULL(locate(/obj/item/organ/cyberimp/cyberware/gorilla_arms) in exposed_look.organs, "The exposed fugitive's look has no plating")
	TEST_ASSERT(!exposed_look.wear_suit && !exposed_look.gloves, "The exposed fugitive's jacket or gloves still cover the plating")
	qdel(exposed_look)
	// Cached apart, so the patron's look never serves the one with chrome
	var/patron_look = get_bounty_look(record, outfit, TRUE)
	var/chrome_look = get_bounty_look(record, outfit)
	TEST_ASSERT(patron_look && chrome_look, "A look of the fugitive in the patron's clothes failed")
	TEST_ASSERT(patron_look != chrome_look, "The look with chrome and the patron's look are the same")

	// The warrant ends the act: the chrome is on show again
	posting.outpost_confront(fugitive, viewer)
	TEST_ASSERT(!fugitive.blended, "The confronted fugitive is still blending in")
	TEST_ASSERT(findtext(plain_examine(fugitive, viewer), chrome_line), "The exposed fugitive's chrome doesn't show on examine")
