/**
 * Bounty hunting: chrome core's tests (C0), for voidcrew/modules/bounties/bounty_chrome.dm.
 *
 * Fork defines are included after the tests, so a test uses the literal value with a comment naming the
 * define. Criminals are real human NPCs with the real implants in them; the tests read tg's own state.
 * Their AI is switched off where a test drives the chrome by hand, so nothing else happens in between.
 *
 * Renders: compile with -DBOUNTY_CHROME_RENDERS and the dressed_to_show and malfunction tests write
 * flat icons to data/bounty_chrome_renders/ (before: the same body and implants in the outfit it would
 * have worn; after: the criminal as spawned).
 */

/// A piece for the tests only: weight 0, so it never rolls and no admin is offered it. A Cascade lattice.
/datum/bounty_chrome_piece/unit_test
	key = "unit_test"
	name = "test chrome"
	weight = 0
	organs = list(/obj/item/organ/cyberimp/cyberware/cascade)

/// The test piece's move: a one second tell, then the lattice's own surge. It counts its hooks.
/datum/bounty_chrome_move/unit_test
	piece_key = "unit_test"
	name = "test surge"
	action_type = /datum/action/cooldown/cyberware/cascade_surge
	tell_time = 1 SECONDS
	tell_sound = null
	var/fights = 0
	var/ends = 0
	var/downs = 0
	var/deaths = 0
	var/emps = 0
	var/fired = 0
	var/list/cancels = list()

/datum/bounty_chrome_move/unit_test/on_fight_start(atom/target)
	fights++

/datum/bounty_chrome_move/unit_test/on_fight_end()
	ends++

/datum/bounty_chrome_move/unit_test/on_downed()
	downs++

/datum/bounty_chrome_move/unit_test/on_death()
	deaths++

/datum/bounty_chrome_move/unit_test/on_emp(severity)
	emps++

/datum/bounty_chrome_move/unit_test/cancel(reason)
	cancels += reason

/datum/bounty_chrome_move/unit_test/effect(atom/target)
	fired++
	return ..()

/// The chrome core's tests, and their helpers
/datum/unit_test/voidcrew_bounty_chrome
	abstract_type = /datum/unit_test/voidcrew_bounty_chrome

/// A record of `tier`, `archetype` and `style` or `kit`, carrying `chrome`, for a human
/datum/unit_test/voidcrew_bounty_chrome/proc/make_record(tier = 2, archetype = "normal", style = "brawler", kit, list/chrome)
	var/datum/bounty_record/record = generate_bounty_record(tier, archetype, "planet", /datum/species/human) // BOUNTY_PLACEMENT_PLANET
	record.tier = tier
	record.archetype = archetype
	record.style = archetype == "boss" ? null : style // BOUNTY_ARCHETYPE_BOSS
	record.kit = kit
	record.chrome = chrome
	return record

/// The criminal for `record` at `where`, built now, with no posting, deleted with the test
/datum/unit_test/voidcrew_bounty_chrome/proc/make_criminal(datum/bounty_record/record, turf/where)
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = spawn_bounty_criminal(record, where || run_loc_floor_bottom_left, null)
	if(criminal)
		allocated += criminal
	return criminal

/// The organ types of the chrome in `body`
/datum/unit_test/voidcrew_bounty_chrome/proc/chrome_types(mob/living/carbon/body)
	. = list()
	for(var/obj/item/organ/organ in body.organs)
		if(organ.GetComponent(/datum/component/cyberware))
			. += organ.type

/// A person with a mind at `where`, deleted with the test
/datum/unit_test/voidcrew_bounty_chrome/proc/make_person(turf/where)
	var/mob/living/carbon/human/person = allocate(/mob/living/carbon/human/consistent, where || run_loc_floor_top_right)
	person.mind_initialize()
	return person

/// A turf `dx`, `dy` from the bottom left of the test room
/datum/unit_test/voidcrew_bounty_chrome/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

// ===== THE PIECES =====

/// Every piece is real chrome that fits in a body on its own; the roll rules hold the design (companions never Lazarus or the Piledriver, the meek nothing, the fists and blades melee only); and the Ghost's kit chrome is what the roll fits around
/datum/unit_test/voidcrew_bounty_chrome/pieces

/datum/unit_test/voidcrew_bounty_chrome/pieces/Run()
	var/list/keys = list("cascade", "mantis", "gorilla", "redline", "piledriver", "lazarus", "deadeye") // BOUNTY_CHROME_*
	for(var/key in keys)
		var/datum/bounty_chrome_piece/piece = GLOB.bounty_chrome_pieces[key]
		TEST_ASSERT_NOTNULL(piece, "There is no [key] piece")
		TEST_ASSERT(length(piece.organs), "The [key] piece has no implants")
		TEST_ASSERT(piece.weight > 0, "The [key] piece never rolls")
		TEST_ASSERT(bounty_chrome_organs_fit(piece.organs), "The [key] piece doesn't fit in a body on its own")
		for(var/organ_type in piece.organs)
			TEST_ASSERT(ispath(organ_type, /obj/item/organ/cyberimp/cyberware) || ispath(organ_type, /obj/item/organ/cyberimp/arm/toolkit/cyberware) || ispath(organ_type, /obj/item/organ/eyes/robotic/cyberware), "The [key] piece's [organ_type] isn't chrome")
		TEST_ASSERT(!("meek" in piece.archetypes), "The meek roll [key]") // BOUNTY_ARCHETYPE_MEEK
	var/datum/bounty_chrome_piece/lazarus = GLOB.bounty_chrome_pieces["lazarus"]
	var/datum/bounty_chrome_piece/piledriver = GLOB.bounty_chrome_pieces["piledriver"]
	TEST_ASSERT(!lazarus.companion && !piledriver.companion, "Companions can roll Lazarus or the Piledriver")
	for(var/melee_key in list("gorilla", "mantis"))
		var/datum/bounty_chrome_piece/melee = GLOB.bounty_chrome_pieces[melee_key]
		for(var/gun_style in list("pistol", "shotgun", "bottle"))
			TEST_ASSERT(!melee.can_roll(3, "normal", gun_style, null, list()), "[melee_key] rolls on a [gun_style] criminal")
	var/datum/bounty_chrome_piece/deadeye = GLOB.bounty_chrome_pieces["deadeye"]
	TEST_ASSERT(deadeye.can_roll(1, "normal", "pistol", null, list()), "A pistol criminal can't roll Deadeye")
	TEST_ASSERT(!deadeye.can_roll(3, "normal", "brawler", null, list()), "A brawler can roll Deadeye")
	// Cascade and Redline share the operating-system slot
	TEST_ASSERT(!bounty_chrome_organs_fit(bounty_chrome_organ_types(list("cascade", "redline"))), "Cascade and Redline fit in one body")
	TEST_ASSERT(!bounty_chrome_organs_fit(bounty_chrome_organ_types(list("gorilla", "mantis"))), "Gorilla Arms and Mantis Blades fit in one pair of arms")

	// The Ghost's chrome, as the roll knows it, is what the real Ghost carries
	var/mob/living/carbon/human/npc/bounty_criminal/ghost = make_criminal(make_record(3, "boss", null, "ghost")) // BOUNTY_TIER_MOST_WANTED, BOUNTY_KIT_GHOST
	TEST_ASSERT(istype(ghost, /mob/living/carbon/human/npc/bounty_criminal/boss/ghost), "No Ghost spawned")
	var/list/known = bounty_chrome_kit_organs("ghost")
	var/list/carried = chrome_types(ghost)
	for(var/organ_type in known)
		TEST_ASSERT(organ_type in carried, "The Ghost doesn't carry [organ_type], which its rolls fit around")
	for(var/organ_type in carried)
		TEST_ASSERT(organ_type in known, "The Ghost carries [organ_type], which its rolls don't know about")
	for(var/kit in list("juggernaut", "pyromaniac", "demolitionist", "heavy"))
		var/mob/living/carbon/human/npc/bounty_criminal/boss = make_criminal(make_record(3, "boss", null, kit))
		TEST_ASSERT_EQUAL(length(chrome_types(boss)), length(bounty_chrome_kit_organs(kit)), "The [kit] carries chrome its rolls don't know about")

// ===== ROLLING =====

/// Chrome rolls by tier, 10, 35 and 60 percent, with a second piece now and then from Wanted up; companions far less often, one piece, never Lazarus or the Piledriver; the meek never
/datum/unit_test/voidcrew_bounty_chrome/roll_odds

/datum/unit_test/voidcrew_bounty_chrome/roll_odds/Run()
	var/list/expected = list(10, 35, 60) // BOUNTY_CHROME_CHANCE_PETTY, _WANTED, _MOST_WANTED
	var/tries = 1000
	for(var/tier in 1 to 3)
		var/carriers = 0
		var/pairs = 0
		for(var/i in 1 to tries)
			var/list/rolled = bounty_chrome_roll(tier, "normal", "brawler", null, list())
			if(!rolled)
				continue
			carriers++
			if(length(rolled) == 2)
				pairs++
			TEST_ASSERT(length(rolled) <= (tier >= 2 ? 2 : 1), "A tier [tier] criminal rolled [length(rolled)] pieces")
		var/percent = carriers * 100 / tries
		TEST_ASSERT(abs(percent - expected[tier]) <= 5, "Tier [tier] carries chrome [percent]% of the time, not about [expected[tier]]%")
		if(tier == 3)
			var/second = pairs * 100 / max(carriers, 1)
			TEST_ASSERT(abs(second - 30) <= 7, "A Most Wanted carrier has a second piece [second]% of the time, not about 30%") // BOUNTY_CHROME_SECOND_CHANCE
	for(var/i in 1 to 200)
		TEST_ASSERT_NULL(bounty_chrome_roll(3, "meek", "holdout", null, list()), "A meek criminal rolled chrome")
	var/companions = 0
	for(var/i in 1 to tries)
		var/list/rolled = bounty_chrome_roll_companion(3, "knife")
		if(!rolled)
			continue
		companions++
		TEST_ASSERT_EQUAL(length(rolled), 1, "A companion rolled [length(rolled)] pieces")
		TEST_ASSERT(!(rolled[1] in list("lazarus", "piledriver")), "A companion rolled [rolled[1]]")
	var/companion_percent = companions * 100 / tries
	TEST_ASSERT(abs(companion_percent - 20) <= 5, "A Most Wanted criminal's companion carries chrome [companion_percent]% of the time, not about 20%") // 60 / BOUNTY_CHROME_COMPANION_DIVISOR

/// No roll ever puts two implants in one slot or goes over capacity, for any tier, style or kit (the Ghost's own chrome included), and the real bodies agree: nothing browns out
/datum/unit_test/voidcrew_bounty_chrome/no_brownout

/datum/unit_test/voidcrew_bounty_chrome/no_brownout/Run()
	var/list/styles = list("brawler", "knife", "pistol", "shotgun", "club", "bottle")
	var/list/kits = list("juggernaut", "pyromaniac", "demolitionist", "ghost", "heavy")
	for(var/tier in 1 to 3)
		for(var/style in styles)
			for(var/i in 1 to 150)
				var/list/rolled = bounty_chrome_roll(tier, "normal", style, null, list())
				TEST_ASSERT(bounty_chrome_organs_fit(bounty_chrome_organ_types(rolled)), "A tier [tier] [style] criminal rolled [jointext(rolled, ", ")], which won't fit")
		for(var/kit in kits)
			var/list/kit_organs = bounty_chrome_kit_organs(kit)
			for(var/i in 1 to 150)
				var/list/rolled = bounty_chrome_roll(tier, "boss", null, kit, kit_organs)
				TEST_ASSERT(bounty_chrome_organs_fit(kit_organs + bounty_chrome_organ_types(rolled)), "A [kit] rolled [jointext(rolled, ", ")], which won't fit beside its kit's chrome")
	// Real bodies: each piece alone, all that fits, and the most that fits beside the Ghost's chrome
	var/list/sets = list()
	for(var/key in list("cascade", "mantis", "gorilla", "redline", "piledriver", "lazarus", "deadeye"))
		sets += list(list("normal", key == "deadeye" ? "pistol" : (key == "mantis" ? "knife" : "brawler"), null, list(key)))
	sets += list(list("normal", "brawler", null, bounty_chrome_all_that_fits(list())))
	sets += list(list("boss", null, "ghost", bounty_chrome_all_that_fits(bounty_chrome_kit_organs("ghost"))))
	sets += list(list("boss", null, "juggernaut", list("cascade", "gorilla")))
	for(var/list/body_set as anything in sets)
		var/list/chrome = body_set[4]
		var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_criminal(make_record(3, body_set[1], body_set[2], body_set[3], chrome.Copy()))
		TEST_ASSERT_NOTNULL(criminal, "No criminal spawned with [jointext(chrome, ", ")]")
		TEST_ASSERT(get_chrome_load(criminal) <= get_chrome_capacity(criminal), "[jointext(chrome, ", ")] put [get_chrome_load(criminal)] load on a body of [get_chrome_capacity(criminal)]")
		var/list/carried = chrome_types(criminal)
		for(var/organ_type in bounty_chrome_organ_types(chrome))
			TEST_ASSERT(organ_type in carried, "[jointext(chrome, ", ")]: [organ_type] isn't in the body")
		for(var/obj/item/organ/organ in criminal.organs)
			var/datum/component/cyberware/ware = organ.GetComponent(/datum/component/cyberware)
			TEST_ASSERT(!ware?.browned_out, "[jointext(chrome, ", ")]: [organ] browned out")
		TEST_ASSERT(isnull(locate(/obj/item/organ/eyes) in get_turf(criminal)), "[jointext(chrome, ", ")]: the eyes it was born with lie on the floor")
		qdel(criminal)

// ===== THE BODY =====

/// The record's chrome is real implants in the body, with its moves; they burn out to scrap when the criminal dies
/datum/unit_test/voidcrew_bounty_chrome/installed

/datum/unit_test/voidcrew_bounty_chrome/installed/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_criminal(make_record(2, "normal", "brawler", null, list("gorilla", "lazarus"))) // BOUNTY_TIER_WANTED
	var/list/carried = chrome_types(criminal)
	for(var/organ_type in list(/obj/item/organ/cyberimp/cyberware/gorilla_arms, /obj/item/organ/cyberimp/cyberware/gorilla_arms/left, /obj/item/organ/cyberimp/cyberware/lazarus))
		TEST_ASSERT(organ_type in carried, "A criminal with Gorilla Arms and Lazarus doesn't carry [organ_type]")
	TEST_ASSERT_EQUAL(length(criminal.record.chrome), 2, "The record lost chrome that fits")
	var/datum/component/bounty_chrome/chrome = criminal.GetComponent(/datum/component/bounty_chrome)
	TEST_ASSERT_NOTNULL(chrome, "A chromed criminal has no chrome AI")
	TEST_ASSERT(("gorilla" in chrome.keys) && ("lazarus" in chrome.keys), "The chrome AI doesn't know what it carries")
	var/turf/here = get_turf(criminal)
	criminal.death()
	TEST_ASSERT_EQUAL(length(chrome_types(criminal)), 0, "A dead criminal still carries working chrome")
	var/scrap = 0
	for(var/obj/item/burnt_chrome/burnt in here)
		scrap++
	TEST_ASSERT_EQUAL(scrap, 3, "A dead criminal's three implants left [scrap] pieces of scrap")
	// Prisoners and decoys never take the record's chrome, nor does the kingpin's record roll any
	var/datum/bounty_record/kingpin_record = generate_bounty_record(3, "normal", "kingpin_lounge") // BOUNTY_PLACEMENT_KINGPIN
	TEST_ASSERT_NULL(kingpin_record.chrome, "A kingpin's record rolled chrome")
	var/mob/living/carbon/human/npc/bounty_criminal/meek = make_criminal(make_record(2, "meek", "holdout", null, list("gorilla")), spot(1, 1))
	TEST_ASSERT_NULL(locate(/obj/item/organ/cyberimp/cyberware/gorilla_arms) in meek.organs, "A meek criminal took the chrome on its record")
	TEST_ASSERT_NULL(meek.GetComponent(/datum/component/bounty_chrome), "A meek criminal got a chrome AI")

/// Carriers dress light enough that the chrome shows: no shirt, no coat over arm or chest chrome, no gloves over arm chrome, shorts over leg chrome; armour stays on; a mini-boss wears its kit
/datum/unit_test/voidcrew_bounty_chrome/dressed_to_show

/datum/unit_test/voidcrew_bounty_chrome/dressed_to_show/Run()
	var/list/cases = list(
		list("gorilla", "brawler", 1),
		list("gorilla", "brawler", 2),
		list("mantis", "knife", 1),
		list("cascade", "brawler", 2),
		list("redline", "club", 2),
		list("piledriver", "brawler", 2),
		list("lazarus", "brawler", 2),
		list("deadeye", "pistol", 1),
	)
	for(var/list/dress_case as anything in cases)
		var/key = dress_case[1]
		var/tier = dress_case[3]
		var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_criminal(make_record(tier, "normal", dress_case[2], null, list(key)))
		var/label = "A tier [tier] [key] carrier"
		switch(key)
			if("gorilla", "mantis")
				TEST_ASSERT_NULL(criminal.gloves, "[label] wears gloves over the arms")
				TEST_ASSERT(istype(criminal.w_uniform, /obj/item/clothing/under/pants), "[label] wears [criminal.w_uniform] over the arms")
			if("cascade", "redline")
				TEST_ASSERT(istype(criminal.w_uniform, /obj/item/clothing/under/pants), "[label] wears [criminal.w_uniform] over the spine")
			if("piledriver")
				TEST_ASSERT(istype(criminal.w_uniform, /obj/item/clothing/under/shorts), "[label] wears [criminal.w_uniform] over the legs")
			if("lazarus", "deadeye")
				TEST_ASSERT(!istype(criminal.w_uniform, /obj/item/clothing/under/pants) && !istype(criminal.w_uniform, /obj/item/clothing/under/shorts), "[label] undressed for chrome nobody can see")
		if(tier >= 2)
			TEST_ASSERT(istype(criminal.wear_suit, /obj/item/clothing/suit/armor/vest), "[label] took its armour vest off")
		else if(key in list("gorilla", "mantis", "cascade", "redline"))
			TEST_ASSERT_NULL(criminal.wear_suit, "[label] wears a coat over the chrome")
		TEST_ASSERT(criminal.belt || dress_case[2] == "brawler" || dress_case[2] == "knife" || dress_case[2] == "club", "[label] lost the belt its style carries")
#ifdef BOUNTY_CHROME_RENDERS
		render_pair(criminal, "[key]_t[tier]")
#endif
		qdel(criminal)
	// A mini-boss keeps its kit on
	var/mob/living/carbon/human/npc/bounty_criminal/juggernaut = make_criminal(make_record(3, "boss", null, "juggernaut", list("gorilla"))) // BOUNTY_KIT_JUGGERNAUT
	TEST_ASSERT(istype(juggernaut.wear_suit, /obj/item/clothing/suit/armor/riot), "A Juggernaut with Gorilla Arms took its riot armour off")
	TEST_ASSERT((/obj/item/organ/cyberimp/cyberware/gorilla_arms in chrome_types(juggernaut)), "A Juggernaut's Gorilla Arms didn't go in")
	// An outfit with a sealed suit stays shut
	var/datum/outfit/sealed = new
	sealed.uniform = /obj/item/clothing/under/color/grey
	sealed.suit = /obj/item/clothing/suit/space/eva
	sealed.head = /obj/item/clothing/head/helmet/space/eva
	bounty_chrome_expose_outfit(sealed, list(/obj/item/organ/cyberimp/cyberware/cascade))
	TEST_ASSERT_EQUAL(sealed.uniform, /obj/item/clothing/under/color/grey, "Chrome under a space suit undressed it")
	TEST_ASSERT_EQUAL(sealed.suit, /obj/item/clothing/suit/space/eva, "Chrome under a space suit took the suit off")
	qdel(sealed)

#ifdef BOUNTY_CHROME_RENDERS
/// Writes `criminal` as spawned, and the same face and implants in the outfit it would have worn, to data/bounty_chrome_renders/
/datum/unit_test/voidcrew_bounty_chrome/proc/render_pair(mob/living/carbon/human/npc/bounty_criminal/criminal, name)
	for(var/facing in list(SOUTH, NORTH))
		fcopy(getFlatIcon(criminal, facing), "data/bounty_chrome_renders/[name]_after_[dir2text(facing)].png")
	var/mob/living/carbon/human/dummy/before = bounty_look_dummy(criminal.record.look, criminal.bounty_build_outfit("green"), null) // ZONE_GREEN
	if(!before)
		return
	for(var/organ_type in chrome_types(criminal))
		var/obj/item/organ/organ = new organ_type
		organ.Insert(before, special = TRUE, movement_flags = DELETE_IF_REPLACED)
	for(var/facing in list(SOUTH, NORTH))
		fcopy(getFlatIcon(before, facing), "data/bounty_chrome_renders/[name]_before_[dir2text(facing)].png")
	qdel(before)
#endif

// ===== MOVES =====

/// A move tells for its tell_time (never under 0.8 s), standing still and outlined, then fires the implant's own action; the fight's hooks reach it
/datum/unit_test/voidcrew_bounty_chrome/moves

/datum/unit_test/voidcrew_bounty_chrome/moves/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(3, 0))
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_criminal(make_record(2, "normal", "brawler", null, list("unit_test")))
	criminal.ai_controller?.set_ai_status(AI_STATUS_OFF)
	var/datum/component/bounty_chrome/chrome = criminal.GetComponent(/datum/component/bounty_chrome)
	TEST_ASSERT_NOTNULL(chrome, "The test chrome gave no chrome AI")
	var/datum/bounty_chrome_move/unit_test/move = chrome.move_of(/datum/bounty_chrome_move/unit_test)
	TEST_ASSERT_NOTNULL(move, "The test piece's move wasn't made")
	TEST_ASSERT_EQUAL(move.owner, criminal, "The move isn't in its criminal")
	TEST_ASSERT_NULL(chrome.plan(criminal.ai_controller, 1), "A criminal out of a fight planned a chrome move")

	TEST_ASSERT(criminal.ai_start_fight(hunter), "The criminal wouldn't fight")
	chrome.update_fight()
	TEST_ASSERT_EQUAL(move.fights, 1, "The move didn't hear the fight start")
	TEST_ASSERT_NULL(chrome.plan(criminal.ai_controller, 1), "A chrome move started before the fight's opening")
	chrome.next_move_at = 0
	TEST_ASSERT(move.can_start(hunter), "The move won't start on a hunter in sight")
	TEST_ASSERT_EQUAL(chrome.plan(criminal.ai_controller, 1), SUBTREE_RETURN_FINISH_PLANNING, "A ready move didn't start")
	TEST_ASSERT_EQUAL(chrome.telling, move, "The move's tell isn't running")
	TEST_ASSERT(HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome"), "The criminal doesn't stand still through the tell") // BOUNTY_CHROME_TRAIT
	TEST_ASSERT_NOTNULL(criminal.get_filter(move.tell_filter()), "The tell has no outline")
	TEST_ASSERT_EQUAL(chrome.plan(criminal.ai_controller, 1), SUBTREE_RETURN_FINISH_PLANNING, "Something else was planned during the tell")
	sleep(0.6 SECONDS)
	TEST_ASSERT_EQUAL(move.fired, 0, "The move fired before its tell was over")
	sleep(0.6 SECONDS)
	TEST_ASSERT_EQUAL(move.fired, 1, "The move didn't fire after its tell")
	TEST_ASSERT_NOTNULL(criminal.has_status_effect(/datum/status_effect/cyberware_cascade_window), "The tell ended but the lattice's own surge didn't run")
	TEST_ASSERT(!HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome"), "The criminal still stands still after the tell")
	TEST_ASSERT_NULL(criminal.get_filter(move.tell_filter()), "The tell's outline stayed on")
	TEST_ASSERT(chrome.next_move_at >= world.time + 3 SECONDS, "Another chrome move may start straight away") // BOUNTY_CHROME_MOVE_GAP
	TEST_ASSERT(!move.can_start(hunter), "The move would start again with the lattice cycling")

	// The floor of a tell: a move asking for less still tells for 0.8 s
	var/datum/bounty_chrome_move/unit_test/quick = new
	quick.tell_time = 1
	var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/wrapped = new(criminal)
	wrapped.set_move(quick)
	TEST_ASSERT(wrapped.windup >= 0.8 SECONDS, "A mini-boss chrome ability winds up for [wrapped.windup / 10] s") // BOUNTY_CHROME_TELL_MIN
	qdel(wrapped)
	qdel(quick)

	// The fight ending, and death, reach the move
	criminal.ai_calm_down()
	chrome.update_fight()
	TEST_ASSERT_EQUAL(move.ends, 1, "The move didn't hear the fight end")
	criminal.death()
	TEST_ASSERT_EQUAL(move.deaths, 1, "The move didn't hear its criminal die")

/// A tell cut short by a stun, an EMP, crit or cuffs fires nothing; a criminal that can't act starts nothing
/datum/unit_test/voidcrew_bounty_chrome/interrupted

/datum/unit_test/voidcrew_bounty_chrome/interrupted/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(3, 0))
	var/list/ways = list("stunned", "emp", "downed", "restrained")
	for(var/way in ways)
		var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_criminal(make_record(2, "normal", "brawler", null, list("unit_test")))
		criminal.ai_controller?.set_ai_status(AI_STATUS_OFF)
		var/datum/component/bounty_chrome/chrome = criminal.GetComponent(/datum/component/bounty_chrome)
		var/datum/bounty_chrome_move/unit_test/move = chrome.move_of(/datum/bounty_chrome_move/unit_test)
		criminal.ai_start_fight(hunter)
		chrome.update_fight()
		TEST_ASSERT(chrome.start_move(move, hunter), "[way]: the tell didn't start")
		switch(way)
			if("stunned")
				criminal.Paralyze(3 SECONDS)
			if("emp")
				criminal.emp_act(EMP_HEAVY)
			if("downed")
				// Into soft crit, short of hard crit and death
				criminal.setOxyLoss(criminal.health + 20)
			if("restrained")
				var/obj/item/restraints/handcuffs/cuffs = new(criminal)
				criminal.set_handcuffed(cuffs)
				criminal.update_handcuffed()
		TEST_ASSERT_NULL(chrome.telling, "[way]: the tell kept running")
		TEST_ASSERT(length(move.cancels), "[way]: the move wasn't told its tell was cut short")
		TEST_ASSERT(!HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome"), "[way]: the hold stayed on")
		sleep(1.2 SECONDS)
		TEST_ASSERT_EQUAL(move.fired, 0, "[way]: the move fired anyway")
		TEST_ASSERT_NULL(criminal.has_status_effect(/datum/status_effect/cyberware_cascade_window), "[way]: the lattice surged anyway")
		chrome.next_move_at = 0
		if(way != "emp")
			TEST_ASSERT(!move.can_start(hunter), "[way]: a criminal that can't act would start a move")
		if(way == "emp")
			TEST_ASSERT_EQUAL(move.emps, 1, "The EMP didn't reach the move")
			TEST_ASSERT(!move.ready(), "The lattice is ready through its EMP reboot")
		if(way == "downed")
			TEST_ASSERT_EQUAL(move.downs, 1, "Going down didn't reach the move")
		qdel(criminal)

/// A mini-boss uses its chrome through its own ability rotation: the wind-up is the move's tell, the effect the implant's own action
/datum/unit_test/voidcrew_bounty_chrome/boss

/datum/unit_test/voidcrew_bounty_chrome/boss/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(3, 0))
	var/mob/living/carbon/human/npc/bounty_criminal/boss/boss = make_criminal(make_record(3, "boss", null, "juggernaut", list("unit_test")))
	boss.ai_controller?.set_ai_status(AI_STATUS_OFF)
	var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/ability = locate() in boss.boss_abilities
	TEST_ASSERT_NOTNULL(ability, "The Juggernaut's chrome isn't in its ability rotation")
	var/datum/bounty_chrome_move/unit_test/move = ability.move
	TEST_ASSERT_NOTNULL(move, "The chrome ability runs no move")
	TEST_ASSERT_EQUAL(move.owner, boss, "The chrome ability runs someone else's move")
	TEST_ASSERT(ability.windup >= 0.8 SECONDS, "The chrome ability winds up for [ability.windup / 10] s") // BOUNTY_CHROME_TELL_MIN
	TEST_ASSERT(ability.worth_using(hunter), "The chrome ability isn't worth using on a hunter in sight")
	// A move with its own lines says one of them, and the kit's ability line stays unsaid: one line per tell
	move.tell_lines = list("Watch this.")
	var/datum/component/bounty_identity_voice/voice = boss.LoadComponent(/datum/component/bounty_identity_voice)
	COOLDOWN_RESET(voice, line_cooldown)
	voice.last_line = null
	TEST_ASSERT(ability.Trigger(target = hunter), "The chrome ability wouldn't start")
	TEST_ASSERT_NULL(voice.last_line, "The Juggernaut barked its kit's ability line over its chrome's own tell line")
	TEST_ASSERT_EQUAL(boss.boss_busy, "windup", "The Juggernaut isn't winding up")
	TEST_ASSERT_NOTNULL(boss.get_filter(move.tell_filter()), "The wind-up has no outline")
	sleep(1.3 SECONDS)
	TEST_ASSERT_EQUAL(move.fired, 1, "The chrome ability didn't fire after its wind-up")
	TEST_ASSERT_NOTNULL(boss.has_status_effect(/datum/status_effect/cyberware_cascade_window), "The wind-up ended but the lattice's own surge didn't run")
	TEST_ASSERT_NULL(boss.get_filter(move.tell_filter()), "The wind-up's outline stayed on")
	// Cut short, nothing fires and the look goes
	var/mob/living/carbon/human/npc/bounty_criminal/boss/second = make_criminal(make_record(3, "boss", null, "juggernaut", list("unit_test")))
	second.ai_controller?.set_ai_status(AI_STATUS_OFF)
	var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/second_ability = locate() in second.boss_abilities
	var/datum/bounty_chrome_move/unit_test/second_move = second_ability.move
	TEST_ASSERT(second_ability.Trigger(target = hunter), "The second chrome ability wouldn't start")
	second.emp_act(EMP_HEAVY)
	TEST_ASSERT_NULL(second.boss_busy, "An EMP didn't cut the Juggernaut's chrome wind-up short")
	TEST_ASSERT_NULL(second.get_filter(second_move.tell_filter()), "The cut-short wind-up's outline stayed on")
	sleep(1.3 SECONDS)
	TEST_ASSERT_EQUAL(second_move.fired, 0, "A cut-short chrome wind-up fired anyway")

// ===== WHO AN AREA MOVE MAY CATCH =====

/// An area move never starts with someone outside the fight where it lands: a bystander, its own companion; the one it is going for, someone it holds a grudge against, the dead and the site's creatures don't stop it
/datum/unit_test/voidcrew_bounty_chrome/bystanders

/datum/unit_test/voidcrew_bounty_chrome/bystanders/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_criminal(make_record(2, "normal", "brawler"))
	criminal.ai_controller?.set_ai_status(AI_STATUS_OFF)
	var/turf/hunter_spot = spot(2, 0)
	var/turf/bystander_spot = spot(2, 1)
	var/mob/living/carbon/human/hunter = make_person(hunter_spot)
	var/mob/living/carbon/human/bystander = make_person(bystander_spot)
	TEST_ASSERT(!bounty_chrome_area_clear(criminal, list(hunter_spot)), "An area move starts on someone not in its fight")
	criminal.body_add_grudge(hunter)
	TEST_ASSERT(bounty_chrome_area_clear(criminal, list(hunter_spot)), "An area move won't start on someone who attacked it")
	TEST_ASSERT(!bounty_chrome_area_clear(criminal, list(hunter_spot, bystander_spot)), "An area move starts with a bystander in it")
	TEST_ASSERT(bounty_chrome_area_clear(criminal, list(bystander_spot), bystander), "An area move won't start on the one it is aimed at")
	criminal.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, bystander)
	TEST_ASSERT(bounty_chrome_area_clear(criminal, list(bystander_spot)), "An area move won't start on the one it is going for")
	criminal.ai_controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	// A crewmate of someone it holds a grudge against is in the fight too: an idle friend can't shield the crew
	var/datum/team/voidcrew/crew = new
	LAZYADD(hunter.mind.ship_teams, crew)
	LAZYADD(bystander.mind.ship_teams, crew)
	var/crewmate_clear = bounty_chrome_area_clear(criminal, list(bystander_spot))
	hunter.mind.ship_teams = null
	bystander.mind.ship_teams = null
	qdel(crew)
	TEST_ASSERT(crewmate_clear, "An idle crewmate of the one who attacked it stops an area move")
	// Its own companion is in the way, never a target
	var/list/buddies = criminal.spawn_companions(1, TRUE)
	TEST_ASSERT(length(buddies), "No companion spawned")
	allocated += buddies
	var/mob/living/carbon/human/npc/bounty_companion/buddy = buddies[1]
	var/turf/buddy_spot = spot(4, 1)
	buddy.forceMove(buddy_spot)
	TEST_ASSERT(!bounty_chrome_area_clear(criminal, list(buddy_spot)), "An area move starts on its own companion")
	TEST_ASSERT(!bounty_chrome_in_posse(buddy, criminal), "A companion counts its own criminal as fair game")
	// The dead, and creatures with nobody behind them, don't stop it
	bystander.death()
	TEST_ASSERT(bounty_chrome_area_clear(criminal, list(bystander_spot)), "A dead bystander stops an area move")
	var/turf/mouse_spot = spot(4, 0)
	allocate(/mob/living/basic/mouse, mouse_spot)
	TEST_ASSERT(bounty_chrome_area_clear(criminal, list(mouse_spot)), "A mouse stops an area move")

// ===== NOTICED =====

/// A bounty NPC feels a chrome read through real optics and tells the reader off, once in a while; never while hiding or fighting, and never with nothing to read
/datum/unit_test/voidcrew_bounty_chrome/read_noticed

/datum/unit_test/voidcrew_bounty_chrome/read_noticed/Run()
	var/mob/living/carbon/human/reader = make_person(spot(3, 0))
	var/obj/item/organ/eyes/robotic/cyberware/deadeye/optics = new
	TEST_ASSERT(optics.Insert(reader, special = TRUE, movement_flags = DELETE_IF_REPLACED), "The reader's optics didn't go in")
	var/datum/action/cooldown/cyberware/chrome_read/read = locate() in reader.actions
	TEST_ASSERT_NOTNULL(read, "The reader's optics have no chrome read")
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_criminal(make_record(1, "normal", "brawler", null, list("gorilla")))
	criminal.ai_controller?.set_ai_status(AI_STATUS_OFF)
	TEST_ASSERT(read.Trigger(target = criminal), "The chrome read didn't go off")
	TEST_ASSERT(criminal.chrome_read_answer_at > world.time, "A calm criminal didn't feel the read")
	TEST_ASSERT(!bounty_chrome_read_noticed(criminal, reader), "A criminal answered two reads in a row")
	criminal.chrome_read_answer_at = 0
	criminal.hidden = TRUE
	TEST_ASSERT(!bounty_chrome_read_noticed(criminal, reader), "A hiding criminal answered a read")
	criminal.hidden = FALSE
	criminal.ai_start_fight(reader)
	TEST_ASSERT(!bounty_chrome_read_noticed(criminal, reader), "A fighting criminal stopped to answer a read")
	var/mob/living/carbon/human/npc/bounty_criminal/clean = make_criminal(make_record(1, "normal", "brawler"), spot(1, 1))
	TEST_ASSERT(!bounty_chrome_read_noticed(clean, reader), "A criminal with no chrome answered a read")

/// An NPC under fire says its dodge at most once every 1.5 s; a player always hears theirs
/datum/unit_test/voidcrew_bounty_chrome/dodge_line

/datum/unit_test/voidcrew_bounty_chrome/dodge_line/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_criminal(make_record(1, "normal", "brawler"))
	criminal.ai_controller?.set_ai_status(AI_STATUS_OFF)
	var/datum/component/cyberware_dodge/arbiter = criminal.LoadComponent(/datum/component/cyberware_dodge)
	var/obj/projectile/bullet/shot = allocate(/obj/projectile/bullet)
	arbiter.perform_sidestep(criminal, shot)
	TEST_ASSERT_EQUAL(arbiter.last_message_at, world.time, "An NPC's first dodge wasn't said")
	var/said_at = world.time - 1 SECONDS
	arbiter.last_message_at = said_at
	arbiter.perform_sidestep(criminal, shot)
	TEST_ASSERT_EQUAL(arbiter.last_message_at, said_at, "An NPC said a second dodge within 1.5 s") // CYBERWARE_DODGE_LINE_GAP
	arbiter.last_message_at = world.time - 2 SECONDS
	arbiter.perform_sidestep(criminal, shot)
	TEST_ASSERT_EQUAL(arbiter.last_message_at, world.time, "An NPC never said its dodge again")

// ===== A MALFUNCTION =====

/// An EMP that knocks chrome out shows it for the reboot, as a picture only; it ends when the NPC dies, and an NPC with no chrome shows nothing
/datum/unit_test/voidcrew_bounty_chrome/malfunction

/datum/unit_test/voidcrew_bounty_chrome/malfunction/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_criminal(make_record(2, "normal", "brawler", null, list("gorilla")))
	criminal.ai_controller?.set_ai_status(AI_STATUS_OFF)
	var/health_before = criminal.health
	criminal.emp_act(EMP_HEAVY)
	sleep(2)
	var/datum/status_effect/bounty_chrome_malfunction/sparks = criminal.has_status_effect(/datum/status_effect/bounty_chrome_malfunction)
	TEST_ASSERT_NOTNULL(sparks, "An EMP knocked chrome out with no malfunction to see")
	TEST_ASSERT(sparks.duration > world.time + 5 SECONDS, "The malfunction is shorter than the chrome's reboot")
	TEST_ASSERT_EQUAL(criminal.health, health_before, "The malfunction hurt them")
#ifdef BOUNTY_CHROME_RENDERS
	fcopy(getFlatIcon(criminal, SOUTH), "data/bounty_chrome_renders/malfunction_south.png")
#endif
	criminal.death()
	TEST_ASSERT_NULL(criminal.has_status_effect(/datum/status_effect/bounty_chrome_malfunction), "A corpse kept malfunctioning")
	var/mob/living/carbon/human/npc/bounty_criminal/clean = make_criminal(make_record(2, "normal", "brawler"), spot(1, 1))
	clean.emp_act(EMP_HEAVY)
	sleep(2)
	TEST_ASSERT_NULL(clean.has_status_effect(/datum/status_effect/bounty_chrome_malfunction), "An EMP on a criminal with no chrome showed a malfunction")

// ===== FUGITIVES =====

/**
 * A chromed fugitive passing as a patron looks and examines like its decoys, who carry the same chrome
 * under the same clothes; when the act drops, the coat and gloves over its chrome come off and it shows.
 * P6's helpers (voidcrew_bounty_outpost.dm) make the outpost.
 */
/datum/unit_test/voidcrew_bounty_outpost/chrome_fugitive

/datum/unit_test/voidcrew_bounty_outpost/chrome_fugitive/Run()
	outpost = make_outpost(/obj/structure/overmap/trader_outpost/outfitter)
	outpost.lobby_alcove_turfs = list(run_loc_floor_top_right)
	var/datum/bounty_record/record = generate_bounty_record(2, "normal", "trader_outpost", /datum/species/human) // BOUNTY_TIER_WANTED, BOUNTY_PLACEMENT_TRADER_OUTPOST
	record.style = "brawler" // BOUNTY_STYLE_BRAWLER
	record.chrome = list("gorilla") // BOUNTY_CHROME_GORILLA
	var/datum/criminal_bounty/outpost_test/posting = allocate(/datum/criminal_bounty/outpost_test)
	posting.record = record
	posting.placement_kind = "trader_outpost"
	posting.site_ref = WEAKREF(outpost)
	posting.value = 1234
	var/mob/living/carbon/human/npc/bounty_criminal/fugitive = make_fugitive(/mob/living/carbon/human/npc/bounty_criminal/normal, null, record)
	fugitive.posting_ref = WEAKREF(posting)
	posting.criminal_ref = WEAKREF(fugitive)
	GLOB.criminal_bounties += posting
	fugitive.ai_controller?.set_ai_status(AI_STATUS_OFF)
	TEST_ASSERT(locate(/obj/item/organ/cyberimp/cyberware/gorilla_arms) in fugitive.organs, "The fugitive's Gorilla Arms didn't go in")
	TEST_ASSERT(posting.setup_outpost_blend(TRUE), "The posting could not be set up to blend in")
	var/list/decoys = decoys_of(posting)
	TEST_ASSERT(length(decoys), "No decoys to compare with")
	var/mob/living/carbon/human/npc/bounty_criminal/decoy/decoy = decoys[1]
	TEST_ASSERT(locate(/obj/item/organ/cyberimp/cyberware/gorilla_arms) in decoy.organs, "A decoy doesn't carry its fugitive's chrome")
	TEST_ASSERT_NULL(locate(/obj/item/organ/eyes) in get_turf(decoy), "A decoy's own eyes lie on the floor")
	// Under the same clothes
	for(var/slot in list(ITEM_SLOT_ICLOTHING, ITEM_SLOT_OCLOTHING, ITEM_SLOT_GLOVES, ITEM_SLOT_FEET))
		var/obj/item/fugitive_wears = fugitive.get_item_by_slot(slot)
		var/obj/item/decoy_wears = decoy.get_item_by_slot(slot)
		TEST_ASSERT_EQUAL(fugitive_wears?.type, decoy_wears?.type, "Passing as a patron, the fugitive wears [fugitive_wears || "nothing"] where a decoy wears [decoy_wears || "nothing"]")
	var/mob/living/carbon/human/viewer = make_hunter()
	TEST_ASSERT_EQUAL(examine_without_features(decoy, viewer), examine_without_features(fugitive, viewer), "The chromed fugitive examines differently from a decoy")
	// The act drops: the coat and gloves come off over the plating, the pockets stay
	var/obj/item/pocketed = fugitive.l_store
	posting.outpost_confront(fugitive, viewer)
	TEST_ASSERT(!fugitive.blended, "The confronted fugitive is still blending in")
	TEST_ASSERT_NULL(fugitive.wear_suit, "The exposed fugitive's coat still covers the plating")
	TEST_ASSERT_NULL(fugitive.gloves, "The exposed fugitive's gloves still cover the plating")
	TEST_ASSERT(istype(fugitive.w_uniform, /obj/item/clothing/under/pants), "The exposed fugitive's shirt still covers the plating")
	TEST_ASSERT(human_npc_gear_locked(fugitive.w_uniform), "The exposed fugitive's trousers aren't locked to it")
	if(pocketed)
		TEST_ASSERT_EQUAL(fugitive.l_store, pocketed, "The exposed fugitive lost what was in its pocket")
	TEST_ASSERT_NOTNULL(decoy.wear_suit, "A decoy took its coat off with the fugitive")

/**
 * `patron`'s examine as plain text without its own features: their lines, and the lines naming the
 * glasses or scarf it wears for them, matched by the item's own name (an embedded "[item]" reads "the
 * circle glasses", where examine says "some circle glasses").
 */
/datum/unit_test/voidcrew_bounty_outpost/chrome_fugitive/proc/examine_without_features(mob/living/carbon/human/npc/bounty_criminal/patron, mob/viewer)
	var/list/features = list()
	for(var/line in patron.record?.feature_lines())
		features += trim(STRIP_HTML_FULL("[line]", MAX_MESSAGE_LEN))
	var/list/feature_items = list()
	for(var/obj/item/worn in list(patron.glasses, patron.wear_neck))
		feature_items += worn.name
	var/list/lines = list()
	for(var/line in patron.examine(viewer))
		var/plain = trim(STRIP_HTML_FULL("[line]", MAX_MESSAGE_LEN))
		if(plain in features)
			continue
		var/names_feature_item = FALSE
		for(var/item_name in feature_items)
			if(findtext(plain, item_name))
				names_feature_item = TRUE
				break
		if(!names_feature_item)
			lines += plain
	return lines.Join(" | ")

// ===== THE BOUNTY PANEL =====

/// The panel spawns a criminal with exactly the chrome asked for (any piece, none, all that fits) or rolls it as usual for the style or kit picked; a style the chrome can't fight with is changed, and what won't fit beside a kit's own chrome is left off with a word to the admin
/datum/unit_test/voidcrew_bounty_admin/chrome

/datum/unit_test/voidcrew_bounty_admin/chrome/Run()
	var/turf/spot = run_loc_floor_bottom_left
	var/mob/living/carbon/human/operator = make_operator(run_loc_floor_top_right)
	var/datum/bounty_admin_panel/unit_test/panel = allocate(__IMPLIED_TYPE__, operator)
	var/list/choices = panel.chrome_choices()
	TEST_ASSERT_EQUAL(length(choices), 10, "The chrome menu offers [length(choices)] choices, not rolled, none, the seven pieces and all of it")
	TEST_ASSERT_EQUAL(choices["All of it"], "all", "The chrome menu has no all of it") // BOUNTY_ADMIN_CHROME_ALL

	// Deadeye on a brawler: a style it would never roll on, kept
	var/mob/living/carbon/human/npc/bounty_criminal/deadeye = panel.admin_spawn_criminal(operator, 2, "normal", "brawler", null, spot, list("deadeye"))
	allocated += deadeye
	TEST_ASSERT(locate(/obj/item/organ/eyes/robotic/cyberware/deadeye) in deadeye.organs, "The chosen Deadeye isn't in them")
	TEST_ASSERT(length(deadeye.record.chrome) == 1 && deadeye.record.chrome[1] == "deadeye", "The record doesn't carry the chosen chrome")
	TEST_ASSERT_EQUAL(deadeye.record.style, "brawler", "Deadeye changed a brawler's style")
	// Gorilla Arms on a pistol criminal: they fight with their fists instead
	var/mob/living/carbon/human/npc/bounty_criminal/gorilla = panel.admin_spawn_criminal(operator, 2, "normal", "pistol", null, spot, list("gorilla"))
	allocated += gorilla
	TEST_ASSERT_EQUAL(gorilla.record.style, "brawler", "A pistol criminal given Gorilla Arms came out a [gorilla.record.style]")
	TEST_ASSERT(locate(/obj/item/organ/cyberimp/cyberware/gorilla_arms/left) in gorilla.organs, "The chosen Gorilla Arms aren't in them")
	// None
	var/mob/living/carbon/human/npc/bounty_criminal/clean = panel.admin_spawn_criminal(operator, 3, "normal", null, null, spot, list())
	allocated += clean
	TEST_ASSERT_NULL(clean.record.chrome, "Asking for no chrome still gave them some")
	TEST_ASSERT_NULL(clean.GetComponent(/datum/component/bounty_chrome), "Asking for no chrome still gave them a chrome AI")
	// All of it: the cyberpsycho (C6, chrome/bounty_cyberpsycho.dm), whose body carries it all, nothing browned out
	var/mob/living/carbon/human/npc/bounty_criminal/all = panel.admin_spawn_criminal(operator, 3, "normal", "brawler", null, spot, "all")
	allocated += all
	TEST_ASSERT(istype(all, /mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho), "All of it spawned [all?.type], not the cyberpsycho")
	TEST_ASSERT_EQUAL(all?.record?.kit, "cyberpsycho", "All of it isn't on the record as the cyberpsycho's kit") // BOUNTY_KIT_CYBERPSYCHO
	TEST_ASSERT(get_chrome_load(all) > 20, "All of it carries only [get_chrome_load(all)] load") // CYBERWARE_BASE_CAPACITY
	TEST_ASSERT(get_chrome_load(all) <= get_chrome_capacity(all), "All of it browned them out")
	// Redline on a Ghost: its own Cascade has the slot, so it's left off and the admin hears why
	var/mob/living/carbon/human/npc/bounty_criminal/ghost = panel.admin_spawn_criminal(operator, 3, "boss", "ghost", null, spot, list("redline"))
	allocated += ghost
	TEST_ASSERT_NULL(ghost.record.chrome, "A Ghost took a Redline core beside its Cascade lattice")
	TEST_ASSERT_NULL(locate(/obj/item/organ/cyberimp/cyberware/redline) in ghost.organs, "A Ghost has a Redline core in it")
	TEST_ASSERT(panel.said("didn't fit"), "The admin wasn't told the Redline didn't fit")
	// Rolled as usual: for the style asked for
	for(var/i in 1 to 40)
		var/datum/bounty_record/pistol = generate_bounty_record(3, "normal", "planet")
		pistol.style = "pistol"
		panel.admin_set_chrome(pistol, "roll") // BOUNTY_ADMIN_CHROME_ROLL
		for(var/key in pistol.chrome)
			var/datum/bounty_chrome_piece/piece = GLOB.bounty_chrome_pieces[key]
			TEST_ASSERT(piece?.can_roll(3, "normal", "pistol", null, list()), "A pistol criminal rolled as usual got [key]")
	// Through the menu
	panel.answers = list("Spawn a criminal with chosen chrome", "Normal", "Wanted", "Brawler", "Gorilla Arms", "None")
	panel.run_menu(operator)
	TEST_ASSERT_EQUAL(length(panel.missed), 0, "The chrome spawn menu did not offer: [jointext(panel.missed, "; ")]")
	var/mob/living/carbon/human/npc/bounty_criminal/from_menu
	for(var/mob/living/carbon/human/npc/bounty_criminal/found in get_turf(operator))
		from_menu = found
	TEST_ASSERT_NOTNULL(from_menu, "The chrome spawn menu put nobody at the admin's feet")
	allocated += from_menu
	TEST_ASSERT(locate(/obj/item/organ/cyberimp/cyberware/gorilla_arms) in from_menu.organs, "The chrome spawn menu's criminal has no Gorilla Arms")
