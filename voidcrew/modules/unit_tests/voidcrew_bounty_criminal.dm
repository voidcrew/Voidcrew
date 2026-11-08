/**
 * Bounty hunting: P2 body's tests, for voidcrew/modules/bounties/bounty_criminal.dm, bounty_restraints.dm,
 * bounty_outfits.dm and bounty_ai_human.dm.
 *
 * A criminal is a real human NPC (voidcrew/modules/human_npcs/): its crit, stamina, cuffs and death are
 * tg's. These tests drive tg's own procs on the body (apply_damage/adjustBruteLoss, Knockdown, Paralyze,
 * adjustStaminaLoss, tg handcuffs, death, revive) and check that the bounty rules read them. Fork
 * defines are included after the tests, so a test uses the literal value with a comment naming the
 * define. None relies on the AI walking anywhere (the AI is off with no player on the level).
 */

/// Holds the helpers the body tests share
/datum/unit_test/voidcrew_bounty_criminal
	abstract_type = /datum/unit_test/voidcrew_bounty_criminal
	/// How many times each bounty signal was sent in the test
	var/list/signal_counts
	/// The user each restraint signal carried, last first
	var/list/restraint_users
	/// Turfs moved into a test area, and the area each came from
	var/list/original_areas
	/// Areas made for the test
	var/list/test_areas

/datum/unit_test/voidcrew_bounty_criminal/Destroy()
	for(var/turf/location as anything in original_areas)
		location.change_area(get_area(location), original_areas[location])
	original_areas = null
	QDEL_LIST(test_areas)
	return ..()

/// Moves `turfs` into a new area of `area_type` (a ship, a hangar, an outpost), put back when the test ends
/datum/unit_test/voidcrew_bounty_criminal/proc/swap_area(list/turfs, area_type)
	var/area/new_area = new area_type()
	LAZYADD(test_areas, new_area)
	for(var/turf/location as anything in turfs)
		if(!LAZYACCESS(original_areas, location))
			LAZYSET(original_areas, location, get_area(location))
		location.change_area(get_area(location), new_area)
	return new_area

/// The proof of death lying near the test room's corner for `posting`, or null
/datum/unit_test/voidcrew_bounty_criminal/proc/proof_for(datum/criminal_bounty/posting)
	for(var/obj/item/bounty_proof/proof in range(2, run_loc_floor_bottom_left))
		if(proof.posting_ref?.resolve() == posting)
			return proof
	return null

/datum/unit_test/voidcrew_bounty_criminal/proc/on_downed(datum/source)
	SIGNAL_HANDLER
	LAZYINITLIST(signal_counts)
	signal_counts["downed"] += 1

/datum/unit_test/voidcrew_bounty_criminal/proc/on_recovered(datum/source)
	SIGNAL_HANDLER
	LAZYINITLIST(signal_counts)
	signal_counts["recovered"] += 1

/datum/unit_test/voidcrew_bounty_criminal/proc/on_restrained(datum/source, mob/user)
	SIGNAL_HANDLER
	LAZYINITLIST(signal_counts)
	signal_counts["restrained"] += 1
	LAZYINITLIST(restraint_users)
	restraint_users.Insert(1, list(list(user)))

/datum/unit_test/voidcrew_bounty_criminal/proc/on_unrestrained(datum/source, mob/user)
	SIGNAL_HANDLER
	LAZYINITLIST(signal_counts)
	signal_counts["unrestrained"] += 1
	LAZYINITLIST(restraint_users)
	restraint_users.Insert(1, list(list(user)))

/// How many times `signal_name` was counted
/datum/unit_test/voidcrew_bounty_criminal/proc/signal_count(signal_name)
	return LAZYACCESS(signal_counts, signal_name) || 0

/// The user the last restraint signal carried
/datum/unit_test/voidcrew_bounty_criminal/proc/last_restraint_user()
	if(!length(restraint_users))
		return null
	var/list/entry = restraint_users[1]
	return entry[1]

/// Listens to every bounty body signal on `criminal`
/datum/unit_test/voidcrew_bounty_criminal/proc/listen_to(mob/living/carbon/human/npc/bounty_criminal/criminal)
	RegisterSignal(criminal, "bounty_criminal_downed", PROC_REF(on_downed)) // COMSIG_BOUNTY_CRIMINAL_DOWNED
	RegisterSignal(criminal, "bounty_criminal_recovered", PROC_REF(on_recovered)) // COMSIG_BOUNTY_CRIMINAL_RECOVERED
	RegisterSignal(criminal, "bounty_criminal_restrained", PROC_REF(on_restrained)) // COMSIG_BOUNTY_CRIMINAL_RESTRAINED
	RegisterSignal(criminal, "bounty_criminal_unrestrained", PROC_REF(on_unrestrained)) // COMSIG_BOUNTY_CRIMINAL_UNRESTRAINED

/// Puts real tg handcuffs on `criminal`, as `user` would (tg's apply_cuffs(), without the do_after)
/datum/unit_test/voidcrew_bounty_criminal/proc/cuff(mob/living/carbon/criminal, mob/living/user)
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	cuffs.apply_cuffs(criminal, user || allocate(/mob/living/carbon/human/consistent), dispense = TRUE)
	return criminal.handcuffed

/// Everything examining `criminal` shows `user`, as one text
/datum/unit_test/voidcrew_bounty_criminal/proc/examine_text(mob/living/carbon/human/npc/bounty_criminal/criminal, mob/user)
	return jointext(criminal.examine(user), "\n")

// ===== THE BODY IS A PERSON'S =====

/// No stand-in body: a person's health and stamina, tg crit and death, revival works, no fire or vacuum immunity.
/datum/unit_test/voidcrew_bounty_criminal_body
	parent_type = /datum/unit_test/voidcrew_bounty_criminal

/datum/unit_test/voidcrew_bounty_criminal_body/Run()
	for(var/criminal_type in list(/mob/living/carbon/human/npc/bounty_criminal/meek, /mob/living/carbon/human/npc/bounty_criminal/normal, /mob/living/carbon/human/npc/bounty_criminal/decoy))
		var/mob/living/carbon/human/npc/bounty_criminal/criminal = allocate(criminal_type)
		TEST_ASSERT(ishuman(criminal), "[criminal_type] is not a human")
		TEST_ASSERT_EQUAL(criminal.maxHealth, 100, "[criminal_type] has a stand-in health pool")
		TEST_ASSERT_EQUAL(criminal.max_stamina, 120, "[criminal_type] has a stand-in stamina pool")
		TEST_ASSERT(!HAS_TRAIT(criminal, TRAIT_NOFIRE) && !HAS_TRAIT(criminal, TRAIT_RESISTCOLD) && !HAS_TRAIT(criminal, TRAIT_RESISTLOWPRESSURE), "[criminal_type] is immune to fire, cold or vacuum")
		TEST_ASSERT(!HAS_TRAIT(criminal, TRAIT_GODMODE), "[criminal_type] starts in godmode")
		TEST_ASSERT_EQUAL(criminal.ai_controller?.blackboard[BB_TARGET_MINIMUM_STAT], CONSCIOUS, "[criminal_type] would attack someone in crit") // HUMAN_NPC_SPARES_DOWNED

	// tg crit: a hit that takes it past 0 health puts it in soft crit, nothing holds it up.
	var/mob/living/carbon/human/npc/bounty_criminal/normal/criminal = allocate(__IMPLIED_TYPE__)
	criminal.adjustBruteLoss(90)
	TEST_ASSERT_EQUAL(criminal.stat, CONSCIOUS, "90 brute put a criminal down")
	criminal.adjustBruteLoss(20)
	TEST_ASSERT(HAS_TRAIT(criminal, TRAIT_CRITICAL_CONDITION), "A criminal at -10 health is not in crit")
	TEST_ASSERT_EQUAL(criminal.stat, SOFT_CRIT, "A criminal at -10 health is not in soft crit")
	TEST_ASSERT(criminal.health < 0, "A hit on a criminal was clipped to keep it standing")

	// Healed out of crit, it stands the tg way; nothing else heals it.
	criminal.adjustBruteLoss(-30)
	TEST_ASSERT_EQUAL(criminal.stat, CONSCIOUS, "A criminal healed out of crit is still down")
	TEST_ASSERT_EQUAL(criminal.health, 20, "Something besides the heal changed the criminal's health")

	// It dies, and can be brought back like anyone.
	criminal.death()
	TEST_ASSERT_EQUAL(criminal.stat, DEAD, "The criminal did not die")
	TEST_ASSERT(criminal.can_be_revived(), "A dead criminal can't be revived")
	criminal.revive(HEAL_ALL)
	TEST_ASSERT_EQUAL(criminal.stat, CONSCIOUS, "A revived criminal is still dead")

	// Stamina is a person's: 120 points, tg's stamcrit.
	var/mob/living/carbon/human/npc/bounty_criminal/meek/runner = allocate(__IMPLIED_TYPE__)
	runner.adjustStaminaLoss(100)
	TEST_ASSERT(!runner.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "100 stamina damage stamcritted a meek criminal")
	runner.adjustStaminaLoss(30)
	TEST_ASSERT(runner.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "130 stamina damage did not stamcrit a meek criminal")

	// Anyone can grab a free one; it isn't too heavy to move.
	var/mob/living/carbon/human/npc/bounty_criminal/normal/free = allocate(__IMPLIED_TYPE__)
	var/mob/living/carbon/human/consistent/grabber = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_bottom_left, EAST))
	grabber.start_pulling(free)
	TEST_ASSERT_EQUAL(grabber.pulling, free, "A free criminal could not be grabbed")
	grabber.stop_pulling()

	// Its kit is locked to it and not loot (D3), its toughness is its tier's (npc_damage_taken), never its health.
	var/datum/bounty_record/wanted = new
	wanted.archetype = "normal" // BOUNTY_ARCHETYPE_NORMAL
	wanted.tier = 2 // BOUNTY_TIER_WANTED
	var/mob/living/carbon/human/npc/bounty_criminal/normal/tough = spawn_bounty_criminal(wanted, run_loc_floor_bottom_left, null)
	TEST_ASSERT_EQUAL(tough.maxHealth, 100, "A Wanted criminal has more health than a person")
	TEST_ASSERT_EQUAL(tough.npc_damage_taken, 0.9, "A Wanted criminal takes the wrong damage") // BOUNTY_TOUGHNESS_WANTED
	TEST_ASSERT(istype(tough.wear_suit, /obj/item/clothing/suit/armor/vest), "A Wanted criminal wears no armour vest")
	TEST_ASSERT(human_npc_gear_locked(tough.wear_suit), "A Wanted criminal's vest is not locked to it")
	qdel(tough)

// ===== CAPTURE STATE =====

/datum/unit_test/voidcrew_bounty_criminal_states
	parent_type = /datum/unit_test/voidcrew_bounty_criminal

/datum/unit_test/voidcrew_bounty_criminal_states/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/normal/criminal = allocate(__IMPLIED_TYPE__)
	var/mob/living/carbon/human/consistent/hunter = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_bottom_left, NORTH))
	listen_to(criminal)
	TEST_ASSERT_EQUAL(criminal.capture_state(), "free", "A fresh criminal is not free") // BOUNTY_STATE_FREE

	// Knocked down, stunned, paralysed (*surrender is one), stamcritted or asleep is stunned; up again it is free.
	criminal.Knockdown(5 SECONDS)
	TEST_ASSERT_EQUAL(criminal.capture_state(), "stunned", "A knocked-down criminal is not stunned") // BOUNTY_STATE_STUNNED
	criminal.SetKnockdown(0)
	TEST_ASSERT_EQUAL(criminal.capture_state(), "free", "A criminal back on its feet is not free")
	criminal.Paralyze(5 SECONDS)
	TEST_ASSERT_EQUAL(criminal.capture_state(), "stunned", "A paralysed criminal is not stunned")
	criminal.SetParalyzed(0)
	criminal.adjustStaminaLoss(200)
	TEST_ASSERT_EQUAL(criminal.capture_state(), "stunned", "A criminal in stamina crit is not stunned")
	criminal.setStaminaLoss(0)
	criminal.remove_status_effect(/datum/status_effect/incapacitating/stamcrit)
	TEST_ASSERT_EQUAL(criminal.capture_state(), "free", "A criminal out of stamina crit is not free")
	criminal.Sleeping(5 SECONDS)
	TEST_ASSERT_EQUAL(criminal.capture_state(), "stunned", "A sleeping criminal is not stunned")
	criminal.SetSleeping(0)
	TEST_ASSERT_EQUAL(criminal.capture_state(), "free", "A criminal woken up is not free")

	// Cuffed with real tg handcuffs is restrained; the restraint signal names the cuffer it last reached for.
	criminal.body_cuffer_ref = WEAKREF(hunter)
	criminal.body_cuffed_at = world.time
	TEST_ASSERT_NOTNULL(cuff(criminal, hunter), "Real handcuffs did not go on a criminal")
	TEST_ASSERT_EQUAL(criminal.capture_state(), "restrained", "A cuffed criminal is not restrained") // BOUNTY_STATE_RESTRAINED
	TEST_ASSERT_EQUAL(signal_count("restrained"), 1, "Cuffing sent [signal_count("restrained")] restraint signals")
	TEST_ASSERT_EQUAL(last_restraint_user(), hunter, "The restraint signal didn't name the cuffer")
	TEST_ASSERT(!criminal.may_attack(hunter), "A cuffed criminal may attack")

	// In crit comes before cuffed, and getting out of crit is the tg way: healing.
	criminal.adjustBruteLoss(110)
	TEST_ASSERT_EQUAL(criminal.capture_state(), "downed", "A cuffed criminal in crit is not downed") // BOUNTY_STATE_DOWNED
	TEST_ASSERT_EQUAL(signal_count("downed"), 1, "Going into crit sent [signal_count("downed")] downed signals")
	criminal.adjustBruteLoss(-50)
	TEST_ASSERT_EQUAL(criminal.capture_state(), "restrained", "A cuffed criminal healed out of crit is not restrained")
	TEST_ASSERT_EQUAL(signal_count("recovered"), 1, "Leaving crit sent [signal_count("recovered")] recovered signals")

	// Uncuffed by someone else: the signal carries a non-null user (it didn't free itself).
	criminal.uncuff()
	TEST_ASSERT_EQUAL(signal_count("unrestrained"), 1, "Uncuffing sent [signal_count("unrestrained")] signals")
	TEST_ASSERT_NOTNULL(last_restraint_user(), "Taken out of its cuffs by someone, it counted as freeing itself")
	TEST_ASSERT_EQUAL(criminal.capture_state(), "free", "An uncuffed criminal is not free")
	// Worked out of them itself (tg's cuff_resist() started): the signal carries null.
	cuff(criminal, hunter)
	SEND_SIGNAL(criminal, COMSIG_MOB_REMOVING_CUFFS, criminal.handcuffed)
	criminal.uncuff()
	TEST_ASSERT_NULL(last_restraint_user(), "A criminal that worked its cuffs off didn't count as freeing itself")

	// Dead comes before everything.
	criminal.death()
	TEST_ASSERT_EQUAL(criminal.capture_state(), "dead", "A dead criminal is not dead") // BOUNTY_STATE_DEAD
	TEST_ASSERT(!criminal.is_downed(), "A dead criminal counts as downed")

	// Revived and brought in alive, it is judged by its condition then, not by having died.
	criminal.revive(HEAL_ALL)
	TEST_ASSERT_EQUAL(criminal.capture_state(), "free", "A revived criminal is not free")
	cuff(criminal, hunter)
	TEST_ASSERT_EQUAL(criminal.capture_state(), "restrained", "A revived, cuffed criminal is not restrained")

// ===== CUFFS =====

/// A reach for a free criminal's wrists: it steps away and runs or fights. Paralysed, stamcritted or in crit, it can't.
/datum/unit_test/voidcrew_bounty_criminal_cuffs
	parent_type = /datum/unit_test/voidcrew_bounty_criminal

/datum/unit_test/voidcrew_bounty_criminal_cuffs/Run()
	var/turf/here = run_loc_floor_bottom_left
	var/turf/cuffer_spot = get_step(here, WEST) || get_step(here, SOUTH) || get_step(here, NORTH)
	if(isnull(cuffer_spot) || cuffer_spot.is_blocked_turf())
		cuffer_spot = get_step(here, NORTH)
	var/mob/living/carbon/human/npc/bounty_criminal/normal/criminal = allocate(__IMPLIED_TYPE__, get_step(here, NORTHEAST))
	var/turf/start = get_turf(criminal)
	var/mob/living/carbon/human/consistent/cuffer = allocate(__IMPLIED_TYPE__, here)

	// Free and on its feet: it can answer, puts the cuffer on its grudge list and steps away.
	TEST_ASSERT(criminal.body_can_answer_cuffs(), "A free criminal can't answer a reach for its wrists")
	criminal.body_on_cuff_attempt(cuffer)
	TEST_ASSERT(criminal.body_has_grudge(cuffer), "Reaching for a criminal's wrists didn't make it hold a grudge")
	criminal.body_answer_cuffs(WEAKREF(cuffer))
	TEST_ASSERT(get_turf(criminal) != start, "A free criminal didn't step away from the cuffs")
	TEST_ASSERT(get_dist(criminal, cuffer) >= get_dist(start, cuffer), "A free criminal stepped toward the cuffs")

	// Paralysed (as by *surrender), stamcritted or in crit, it can't do anything about them.
	criminal.Paralyze(20 SECONDS)
	TEST_ASSERT(!criminal.body_can_answer_cuffs(), "A paralysed criminal can still answer a reach for its wrists")
	criminal.SetParalyzed(0)
	criminal.adjustStaminaLoss(200)
	TEST_ASSERT(!criminal.body_can_answer_cuffs(), "A stamcritted criminal can still answer a reach for its wrists")
	criminal.setStaminaLoss(0)
	criminal.remove_status_effect(/datum/status_effect/incapacitating/stamcrit)
	criminal.adjustBruteLoss(110)
	TEST_ASSERT(!criminal.body_can_answer_cuffs(), "A criminal in crit can still answer a reach for its wrists")
	criminal.adjustBruteLoss(-110)

	// The cuff signal never refuses tg's cuffs.
	TEST_ASSERT(!(SEND_SIGNAL(criminal, COMSIG_CARBON_CUFF_ATTEMPTED, cuffer) & COMSIG_CARBON_CUFF_PREVENT), "A criminal refused tg's cuffs")
	TEST_ASSERT_EQUAL(criminal.body_cuffer_ref?.resolve(), cuffer, "The cuff signal didn't note the cuffer")

	// A fulton never goes on one.
	var/obj/item/extraction_pack/fulton = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT_EQUAL(criminal.item_interaction(cuffer, fulton), ITEM_INTERACT_BLOCKING, "A fulton could go on a criminal")

	// A cuffed criminal's AI works at its cuffs, the player's way (tg's resist).
	var/datum/ai_planning_subtree/bounty_escape_captivity/escape = new
	cuff(criminal, cuffer)
	escape.SelectBehaviors(criminal.ai_controller, 1)
	TEST_ASSERT(locate(/datum/ai_behavior/resist) in criminal.ai_controller.planned_behaviors, "A cuffed criminal doesn't work at its cuffs")
	criminal.ai_controller.CancelActions()
	// ...but a criminal sitting down or hiding in a locker by choice doesn't fight its way out of the chair or the locker.
	criminal.uncuff()
	var/obj/structure/chair/seat = allocate(__IMPLIED_TYPE__, get_turf(criminal))
	seat.buckle_mob(criminal, force = TRUE)
	escape.SelectBehaviors(criminal.ai_controller, 1)
	TEST_ASSERT(!(locate(/datum/ai_behavior/resist) in criminal.ai_controller.planned_behaviors), "A criminal fights its way out of a chair it sat on")
	seat.unbuckle_mob(criminal, force = TRUE)
	var/obj/structure/closet/locker = allocate(__IMPLIED_TYPE__, get_turf(criminal))
	criminal.forceMove(locker)
	criminal.hidden = TRUE
	escape.SelectBehaviors(criminal.ai_controller, 1)
	TEST_ASSERT(!(locate(/datum/ai_behavior/resist) in criminal.ai_controller.planned_behaviors), "A criminal hiding in a locker fights its way out of it")
	criminal.hidden = FALSE
	criminal.forceMove(get_turf(locker))
	qdel(escape)

// ===== DEATH AND PROOF =====

/datum/unit_test/voidcrew_bounty_criminal_death
	parent_type = /datum/unit_test/voidcrew_bounty_criminal

/datum/unit_test/voidcrew_bounty_criminal_death/Run()
	// Its body is the proof: a death that leaves the body leaves no tag; gibbing the body leaves one.
	var/list/postings = list()
	var/datum/criminal_bounty/gib_posting = new
	postings += gib_posting
	var/mob/living/carbon/human/npc/bounty_criminal/normal/gibbed = allocate(__IMPLIED_TYPE__)
	gibbed.posting_ref = WEAKREF(gib_posting)
	gibbed.death()
	TEST_ASSERT(!QDELETED(gibbed), "A dead criminal's body did not stay")
	TEST_ASSERT(!(gibbed in SShuman_npcs.corpses), "A wanted criminal's body is on the corpse sweep")
	TEST_ASSERT(!gibbed.body_proof_dropped, "A dead criminal whose body stays asked for proof")
	TEST_ASSERT_NULL(proof_for(gib_posting), "A dead criminal whose body stays left a tag")
	gibbed.gib()
	TEST_ASSERT(QDELETED(gibbed), "The gibbed criminal was not deleted")
	TEST_ASSERT_NOTNULL(proof_for(gib_posting), "A gibbed criminal left no tag")

	// Gibbed alive, it dies first, and leaves a tag.
	var/datum/criminal_bounty/blast_posting = new
	postings += blast_posting
	var/mob/living/carbon/human/npc/bounty_criminal/normal/blown_up = allocate(__IMPLIED_TYPE__)
	blown_up.posting_ref = WEAKREF(blast_posting)
	blown_up.gib()
	TEST_ASSERT_NOTNULL(proof_for(blast_posting), "A criminal gibbed alive left no tag")

	// Fallen into a chasm alive, or dragged in dead: gone for good, and a tag stays up top.
	var/obj/effect/abstract/chasm_storage/depths = allocate(__IMPLIED_TYPE__)
	var/datum/criminal_bounty/fall_posting = new
	postings += fall_posting
	var/mob/living/carbon/human/npc/bounty_criminal/normal/faller = allocate(__IMPLIED_TYPE__)
	faller.posting_ref = WEAKREF(fall_posting)
	faller.forceMove(depths)
	faller.death(TRUE)
	TEST_ASSERT_NOTNULL(proof_for(fall_posting), "A criminal that fell into a chasm left no tag")
	var/datum/criminal_bounty/corpse_posting = new
	postings += corpse_posting
	var/mob/living/carbon/human/npc/bounty_criminal/normal/corpse = allocate(__IMPLIED_TYPE__)
	corpse.posting_ref = WEAKREF(corpse_posting)
	corpse.death()
	TEST_ASSERT_NULL(proof_for(corpse_posting), "A body on the floor left a tag")
	corpse.forceMove(depths)
	TEST_ASSERT_NOTNULL(proof_for(corpse_posting), "A body dragged into a chasm left no tag")

	// Deleted alive (a despawning ship, a stray delete), it was never killed: no proof (M5).
	var/datum/criminal_bounty/vanish_posting = new
	postings += vanish_posting
	var/mob/living/carbon/human/npc/bounty_criminal/normal/vanished = allocate(__IMPLIED_TYPE__)
	vanished.posting_ref = WEAKREF(vanish_posting)
	qdel(vanished)
	TEST_ASSERT(!vanished.body_proof_dropped, "A live criminal deleted asked for proof")
	TEST_ASSERT_NULL(proof_for(vanish_posting), "A live criminal deleted left a tag")

	// Removed on purpose, by P5's mark (the pad, closing, relisting, its site unloading) or ours: no proof.
	var/datum/criminal_bounty/pad_posting = new
	postings += pad_posting
	var/mob/living/carbon/human/npc/bounty_criminal/normal/beamed = allocate(__IMPLIED_TYPE__)
	beamed.posting_ref = WEAKREF(pad_posting)
	beamed.death()
	ADD_TRAIT(beamed, "bounty_removed", "bounty") // TRAIT_BOUNTY_REMOVED, BOUNTY_TRAIT
	qdel(beamed)
	TEST_ASSERT_NULL(proof_for(pad_posting), "A criminal the pad removed left a tag")
	var/mob/living/carbon/human/npc/bounty_criminal/normal/unloaded = allocate(__IMPLIED_TYPE__)
	unloaded.posting_ref = WEAKREF(pad_posting)
	unloaded.death()
	unloaded.body_mark_removed()
	qdel(unloaded)
	TEST_ASSERT(!unloaded.body_proof_dropped, "A criminal removed on purpose asked for proof")

	// A closed posting takes no proof.
	var/datum/criminal_bounty/closed_posting = new
	postings += closed_posting
	closed_posting.status = "closed" // BOUNTY_POSTING_CLOSED
	var/mob/living/carbon/human/npc/bounty_criminal/normal/late = allocate(__IMPLIED_TYPE__)
	late.posting_ref = WEAKREF(closed_posting)
	late.gib()
	TEST_ASSERT(!late.body_proof_dropped, "A criminal gibbed after its posting closed asked for proof")
	TEST_ASSERT_NULL(proof_for(closed_posting), "A criminal gibbed after its posting closed left a tag")

	// Marked closed first: deleting an open posting runs close(), which deletes it again (P5), and the
	// tags going with the test room must not send a posting off to relist.
	for(var/datum/criminal_bounty/posting as anything in postings)
		posting.status = "closed" // BOUNTY_POSTING_CLOSED
	QDEL_LIST(postings)

// ===== THE LEASH =====

/datum/unit_test/voidcrew_bounty_criminal_leash
	parent_type = /datum/unit_test/voidcrew_bounty_criminal

/datum/unit_test/voidcrew_bounty_criminal_leash/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/normal/criminal = allocate(__IMPLIED_TYPE__)
	var/turf/here = get_turf(criminal)
	var/turf/east = get_step(here, EAST)
	var/turf/north = get_step(here, NORTH)
	TEST_ASSERT(criminal.leash_ok(north), "A criminal with no site may not go somewhere")
	TEST_ASSERT(!criminal.leash_ok(null), "A criminal may go nowhere")

	// Leashed to its tile and the one east: its AI's steps keep to it.
	criminal.site_bounds = list(here.x, here.y, here.x + 1, here.y, here.z)
	TEST_ASSERT(criminal.leash_ok(east), "A tile on the site is off the leash")
	TEST_ASSERT(!criminal.leash_ok(north), "A tile off the site is on the leash")
	TEST_ASSERT(!criminal.body_move_allowed(north), "A criminal's own step may leave its site")
	TEST_ASSERT(criminal.body_move_allowed(east), "A criminal's own step may not cross its site")

	// On its site it may fight anyone on their feet, and never someone down.
	var/mob/living/carbon/human/consistent/hunter = allocate(__IMPLIED_TYPE__, north)
	TEST_ASSERT(criminal.may_attack(hunter), "A criminal on its site may not fight a hunter")
	var/mob/living/carbon/human/npc/bounty_criminal/normal/friend = allocate(__IMPLIED_TYPE__, east)
	TEST_ASSERT(!criminal.may_attack(friend), "A criminal may fight another criminal")
	TEST_ASSERT(!criminal.may_attack(criminal), "A criminal may fight itself")
	var/obj/structure/table/table = allocate(__IMPLIED_TYPE__, east)
	TEST_ASSERT(criminal.may_attack(table), "A criminal on its site may not break a table on its site")
	hunter.Unconscious(10 SECONDS)
	TEST_ASSERT(!criminal.may_attack(hunter), "A criminal may attack a hunter who is down")
	hunter.SetUnconscious(0)

	// Off its site, only its grudge list, and no structures.
	criminal.site_bounds = list(here.x + 3, here.y + 3, here.x + 4, here.y + 4, here.z)
	TEST_ASSERT(!criminal.may_attack(hunter), "A criminal off its site may fight a stranger")
	TEST_ASSERT(!criminal.may_attack(table), "A criminal off its site may break things")
	criminal.body_add_grudge(hunter)
	TEST_ASSERT(criminal.may_attack(hunter), "A criminal off its site may not fight someone it holds a grudge against")

	// Off its site, it may walk anywhere (back toward its site, say); its body is never held: dragged, it goes anywhere.
	TEST_ASSERT(criminal.body_move_allowed(north), "A criminal already off its site could not move")
	criminal.site_bounds = list(here.x, here.y, here.x, here.y, here.z)
	var/mob/living/carbon/human/consistent/dragger = allocate(__IMPLIED_TYPE__, east)
	dragger.start_pulling(criminal)
	TEST_ASSERT_EQUAL(dragger.pulling, criminal, "A free criminal could not be pulled")
	TEST_ASSERT(criminal.body_move_allowed(north), "A dragged criminal was held to its leash")
	dragger.stop_pulling()

	// No environment damage off its site, or near a dock strip.
	TEST_ASSERT(!criminal.environment_damage_allowed(north), "Environment damage allowed off its site")
	criminal.body_dock_top_y = here.y
	TEST_ASSERT(!criminal.environment_damage_allowed(here), "Environment damage allowed beside the dock strip")

	// Teleports, polymorph and type changes are refused.
	var/mob/living/carbon/human/npc/bounty_criminal/meek/runner = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(!do_teleport(runner, east, no_effects = TRUE, forced = TRUE), "A criminal was teleported")
	TEST_ASSERT_EQUAL(runner.loc, here, "A criminal moved when teleported")
	TEST_ASSERT(SEND_SIGNAL(runner, COMSIG_LIVING_PRE_WABBAJACKED, null) & STOP_WABBAJACK, "A criminal could be polymorphed")
	TEST_ASSERT(SEND_SIGNAL(runner, COMSIG_PRE_MOB_CHANGED_TYPE) & COMPONENT_BLOCK_MOB_CHANGE, "A criminal could change type")

// ===== SHIPS, OUTPOSTS AND DOCK STRIPS INSIDE ITS SITE =====

/datum/unit_test/voidcrew_bounty_criminal_ground
	parent_type = /datum/unit_test/voidcrew_bounty_criminal

/datum/unit_test/voidcrew_bounty_criminal_ground/Run()
	var/turf/here = run_loc_floor_bottom_left
	var/turf/east = get_step(here, EAST)
	var/turf/far_east = get_step(east, EAST)
	var/turf/north = get_step(here, NORTH)
	var/turf/north_east = get_step(east, NORTH)
	var/turf/two_north = get_step(north, NORTH)
	// Ship A lands over two tiles, ship B beside it, a player outpost to the north; all inside the site's rectangle.
	swap_area(list(east, north_east), /area/shuttle)
	swap_area(list(far_east), /area/shuttle)
	swap_area(list(north), /area/voidcrew/player_outpost)
	var/list/site = list(here.x, here.y, here.x + 4, here.y + 4, here.z)

	// A ship or outpost inside the site's rectangle is not its site, and it doesn't walk onto one (H1).
	var/mob/living/carbon/human/npc/bounty_criminal/normal/criminal = allocate(__IMPLIED_TYPE__)
	criminal.site_bounds = site
	TEST_ASSERT(criminal.body_on_site(here), "Plain ground inside its site is not its site")
	TEST_ASSERT(!criminal.body_on_site(east), "A landed ship inside its site's rectangle counts as its site")
	TEST_ASSERT(!criminal.leash_ok(east), "A landed ship inside its site is on its leash")
	TEST_ASSERT(!criminal.leash_ok(north), "A player outpost inside its site is on its leash")
	TEST_ASSERT(!criminal.body_move_allowed(east), "A criminal may walk onto a ship inside its site")

	// Aboard that ship it fights only its grudge list.
	var/mob/living/carbon/human/npc/bounty_criminal/normal/stowaway = allocate(__IMPLIED_TYPE__, north_east)
	stowaway.site_bounds = site
	var/mob/living/carbon/human/consistent/crew = allocate(__IMPLIED_TYPE__, two_north)
	TEST_ASSERT(!stowaway.may_attack(crew), "A criminal aboard a ship inside its site may fight anyone")
	stowaway.body_add_grudge(crew)
	TEST_ASSERT(stowaway.may_attack(crew), "A criminal aboard a ship may not fight someone it holds a grudge against")
	qdel(stowaway)

	// Off its leash aboard ship A, it walks about that ship and back to its site, never on into
	// ship B or the player outpost (M3).
	criminal.forceMove(east)
	TEST_ASSERT(criminal.body_move_allowed(north_east), "A criminal aboard a ship could not walk about it")
	TEST_ASSERT(!criminal.body_move_allowed(north), "A criminal may walk from a ship into a player outpost")
	TEST_ASSERT(!criminal.body_move_allowed(far_east), "A criminal may walk from one ship on into another")
	TEST_ASSERT(criminal.body_move_allowed(here), "A criminal aboard a ship could not walk back onto its site")
	// A scripted walk goes where it is sent.
	ADD_TRAIT(criminal, "bounty_scripted_move", "test") // TRAIT_BOUNTY_SCRIPTED_MOVE
	TEST_ASSERT(criminal.body_move_allowed(far_east), "A scripted walk was held to the leash")
	REMOVE_TRAIT(criminal, "bounty_scripted_move", "test")
	criminal.forceMove(here)

	// Its planet's dock strip, where ships land, is not its ground either (L1).
	criminal.body_dock_top_y = here.y
	TEST_ASSERT(!criminal.body_on_site(here), "The dock strip counts as its site")
	TEST_ASSERT(!criminal.leash_ok(here), "The dock strip is on its leash")
	TEST_ASSERT(criminal.leash_ok(two_north), "Ground above the dock strip is off its leash")
	criminal.body_dock_top_y = null

	// Whatever holds it can't be teleported, and lets go when it gets out (M2). A carrier is a person, not a box.
	var/obj/structure/closet/locker = allocate(__IMPLIED_TYPE__, two_north)
	criminal.forceMove(locker)
	TEST_ASSERT(HAS_TRAIT(locker, TRAIT_NO_TELEPORT), "A locker holding a criminal can be teleported")
	TEST_ASSERT(!do_teleport(locker, here, no_effects = TRUE), "A locker holding a criminal was teleported")
	TEST_ASSERT_EQUAL(locker.loc, two_north, "A locker holding a criminal moved when teleported")
	criminal.forceMove(here)
	TEST_ASSERT(!HAS_TRAIT(locker, TRAIT_NO_TELEPORT), "An empty locker still can't be teleported")

// ===== TURRETS =====

/datum/unit_test/voidcrew_bounty_criminal_turrets
	parent_type = /datum/unit_test/voidcrew_bounty_criminal

/datum/unit_test/voidcrew_bounty_criminal_turrets/Run()
	var/turf/here = run_loc_floor_bottom_left
	// Away from a trader outpost, no turret shoots a criminal in crit, stunned or cuffed (tg's states),
	// so a crew's turrets don't finish off its catch; a free one is judged like any creature.
	var/mob/living/carbon/human/npc/bounty_criminal/normal/criminal = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(!bounty_turret_ignores(criminal, FALSE), "Turrets leave a free criminal alone")
	criminal.Knockdown(5 SECONDS)
	TEST_ASSERT(bounty_turret_ignores(criminal, FALSE), "A turret would shoot a stunned criminal")
	TEST_ASSERT(!is_hostile_creature(criminal), "A turret would shoot a stunned criminal")
	criminal.SetKnockdown(0)
	cuff(criminal)
	TEST_ASSERT(bounty_turret_ignores(criminal, FALSE), "A turret would shoot a cuffed criminal")
	criminal.uncuff()
	criminal.adjustBruteLoss(110)
	TEST_ASSERT(bounty_turret_ignores(criminal, FALSE), "A turret would shoot a criminal in crit")
	criminal.adjustBruteLoss(-110)

	// At a trader outpost, criminals, decoys and companions are all left to the hunters.
	var/mob/living/carbon/human/npc/bounty_criminal/decoy/decoy = allocate(__IMPLIED_TYPE__)
	var/mob/living/carbon/human/npc/bounty_companion/companion = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(bounty_turret_ignores(criminal, TRUE), "Trader-outpost turrets would shoot a criminal")
	TEST_ASSERT(bounty_turret_ignores(decoy, TRUE), "Trader-outpost turrets would shoot a decoy")
	TEST_ASSERT(bounty_turret_ignores(companion, TRUE), "Trader-outpost turrets would shoot a companion")
	TEST_ASSERT(!bounty_turret_ignores(decoy, FALSE), "Turrets anywhere leave a free decoy alone")
	TEST_ASSERT(!bounty_turret_ignores(companion, FALSE), "Turrets anywhere leave a companion alone")
	var/turf/concourse = get_step(get_step(here, NORTH), NORTH)
	swap_area(list(concourse), /area/voidcrew/trader_outpost)
	criminal.forceMove(concourse)
	TEST_ASSERT(!is_hostile_creature(criminal), "A turret in a trader outpost's concourse would shoot a free criminal")

// ===== SPAWNING, OUTFITS AND EXAMINE =====

/datum/unit_test/voidcrew_bounty_criminal_spawn
	parent_type = /datum/unit_test/voidcrew_bounty_criminal

/datum/unit_test/voidcrew_bounty_criminal_spawn/Run()
	var/mob/living/carbon/human/consistent/hunter = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_bottom_left, EAST))

	// Every criminal type comes up and goes away with no arguments, and its body procs don't runtime.
	for(var/criminal_type in typesof(/mob/living/carbon/human/npc/bounty_criminal))
		var/mob/living/carbon/human/npc/bounty_criminal/criminal = allocate(criminal_type)
		TEST_ASSERT(!QDELETED(criminal), "[criminal_type] was deleted as it was made")
		TEST_ASSERT_EQUAL(criminal.capture_state(), "free", "A fresh [criminal_type] is not free")
		TEST_ASSERT(!criminal.may_attack(null), "[criminal_type] may attack nothing")
		TEST_ASSERT(criminal.leash_ok(get_turf(criminal)), "[criminal_type] with no site is off its leash where it stands")
		TEST_ASSERT(length(criminal.examine(hunter)), "Examining [criminal_type] shows nothing")
		TEST_ASSERT(!criminal.body_leaves_proof(), "[criminal_type] with no posting would leave proof")
		TEST_ASSERT(!criminal.hv_can_execute(), "[criminal_type] can land an execution")

	// With no record: a normal criminal.
	var/list/spawned = list()
	var/mob/living/carbon/human/npc/bounty_criminal/plain = spawn_bounty_criminal(null, run_loc_floor_bottom_left, null)
	spawned += plain
	TEST_ASSERT(istype(plain, /mob/living/carbon/human/npc/bounty_criminal/normal), "A criminal with no record is [plain?.type]")
	TEST_ASSERT_NULL(spawn_bounty_criminal(null, null, null), "A criminal spawned nowhere")

	// Meek: its record, posting, name and face, and the planet-sweep protection while wanted.
	var/datum/bounty_record/meek_record = new
	meek_record.archetype = "meek" // BOUNTY_ARCHETYPE_MEEK
	meek_record.name = "Tess Harlow"
	meek_record.gender = FEMALE
	var/datum/criminal_bounty/posting = new
	var/mob/living/carbon/human/npc/bounty_criminal/meek/runner = spawn_bounty_criminal(meek_record, run_loc_floor_bottom_left, posting)
	spawned += runner
	TEST_ASSERT(istype(runner), "A meek record spawned [runner?.type]")
	TEST_ASSERT_EQUAL(runner.record, meek_record, "A spawned criminal lost its record")
	TEST_ASSERT_EQUAL(runner.posting(), posting, "A spawned criminal lost its posting")
	TEST_ASSERT_EQUAL(runner.real_name, "Tess Harlow", "A spawned criminal lost its name")
	TEST_ASSERT_EQUAL(runner.npc_damage_taken, 1, "A meek criminal takes more or less than a person's damage") // BOUNTY_TOUGHNESS_PETTY
	TEST_ASSERT(HAS_TRAIT(runner, "mission_field_mob"), "A wanted criminal is not kept from the planet sweep") // TRAIT_MISSION_FIELD_MOB

	// Toughness by tier is armour and npc_damage_taken: Most Wanted wear a vest and a helmet.
	var/datum/bounty_record/most_record = new
	most_record.archetype = "normal" // BOUNTY_ARCHETYPE_NORMAL
	most_record.tier = 3 // BOUNTY_TIER_MOST_WANTED
	var/mob/living/carbon/human/npc/bounty_criminal/normal/most = spawn_bounty_criminal(most_record, run_loc_floor_bottom_left, null)
	spawned += most
	TEST_ASSERT_EQUAL(most.npc_damage_taken, 0.8, "A Most Wanted criminal takes the wrong damage") // BOUNTY_TOUGHNESS_MOST_WANTED
	TEST_ASSERT(istype(most.wear_suit, /obj/item/clothing/suit/armor/vest), "A Most Wanted criminal wears no vest")
	TEST_ASSERT(istype(most.head, /obj/item/clothing/head/helmet), "A Most Wanted criminal wears no helmet")
	TEST_ASSERT(!HAS_TRAIT(most, "mission_field_mob"), "A criminal with no posting is kept from the planet sweep")
	var/datum/bounty_record/petty_record = new
	petty_record.archetype = "normal"
	petty_record.tier = 1 // BOUNTY_TIER_PETTY
	var/mob/living/carbon/human/npc/bounty_criminal/normal/petty = spawn_bounty_criminal(petty_record, run_loc_floor_bottom_left, null)
	spawned += petty
	TEST_ASSERT(!istype(petty.wear_suit, /obj/item/clothing/suit/armor), "A petty criminal wears armour")

	// Mini-bosses by kit; never at a trader outpost, where a normal criminal stands in.
	var/datum/bounty_record/boss_record = new
	boss_record.archetype = "boss" // BOUNTY_ARCHETYPE_BOSS
	boss_record.kit = "ghost" // BOUNTY_KIT_GHOST
	TEST_ASSERT_EQUAL(bounty_criminal_type(boss_record, null), /mob/living/carbon/human/npc/bounty_criminal/boss/ghost, "A ghost record is the wrong type")
	var/datum/criminal_bounty/outpost_posting = new
	outpost_posting.placement_kind = "trader_outpost" // BOUNTY_PLACEMENT_TRADER_OUTPOST
	TEST_ASSERT_EQUAL(bounty_criminal_type(boss_record, outpost_posting), /mob/living/carbon/human/npc/bounty_criminal/normal, "A mini-boss was placed at a trader outpost")

	// Examine: its features, and that it gave up while it lies there; never a health line of its own.
	var/mob/living/carbon/human/npc/bounty_criminal/normal/examined = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(!findtext(examine_text(examined, hunter), "unhurt"), "Examining a criminal shows the old health line")
	examined.npc_surrendering = TRUE
	examined.Paralyze(5 SECONDS)
	var/given_up = "[examined.p_They()] [examined.p_have()] given up."
	TEST_ASSERT(findtextEx(examine_text(examined, hunter), given_up), "Examining a criminal that gave up doesn't say so")
	examined.blended = TRUE
	TEST_ASSERT(!findtextEx(examine_text(examined, hunter), given_up), "Examining a criminal blending in shows more than a decoy's layout")

	for(var/mob/living/carbon/human/npc/bounty_criminal/criminal as anything in spawned)
		qdel(criminal)
	// Marked closed first: deleting an open posting runs close(), which deletes it again (P5)
	posting.status = "closed" // BOUNTY_POSTING_CLOSED
	outpost_posting.status = "closed"
	qdel(posting)
	qdel(outpost_posting)

// ===== SELF-TREATMENT =====

/// Hurt and unthreatened, it uses a real item it carries on itself (N6): a medipen, or a bruise pack on its worst limb.
/datum/unit_test/voidcrew_bounty_criminal_treat_self
	parent_type = /datum/unit_test/voidcrew_bounty_criminal

/datum/unit_test/voidcrew_bounty_criminal_treat_self/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/normal/criminal = allocate(__IMPLIED_TYPE__)
	var/datum/ai_controller/controller = criminal.ai_controller
	var/datum/ai_planning_subtree/bounty_treat_self/treat = new
	// Only what the test gives it: whatever treatment its outfit carried goes, and it has pockets.
	for(var/obj/item/carried as anything in criminal.get_all_contents_type(/obj/item))
		if(istype(carried, /obj/item/stack/medical) || istype(carried, /obj/item/reagent_containers/hypospray/medipen) || carried == criminal.l_store || carried == criminal.r_store)
			criminal.temporarilyRemoveItemFromInventory(carried, force = TRUE)
			qdel(carried)
	if(!criminal.w_uniform)
		criminal.equip_to_slot_or_del(new /obj/item/clothing/under/pants/jeans(criminal), ITEM_SLOT_ICLOTHING)
	// Unhurt, nothing to do.
	treat.SelectBehaviors(controller, 1)
	TEST_ASSERT(!controller.blackboard_key_exists("human_npc_treat_item"), "An unhurt criminal treats itself")
	// Hurt with a bruise pack in its pocket: it picks the pack, and its worst limb.
	criminal.apply_damage(40, BRUTE, BODY_ZONE_L_ARM)
	var/obj/item/stack/medical/bruise_pack/pack = new(criminal)
	criminal.equip_to_slot_or_del(pack, ITEM_SLOT_LPOCKET)
	TEST_ASSERT_EQUAL(bounty_ai_find_medical_stack(criminal), pack, "A hurt criminal can't find its bruise pack")
	TEST_ASSERT_EQUAL(bounty_ai_worst_limb(criminal), BODY_ZONE_L_ARM, "The worst limb is not the hurt arm")
	treat.SelectBehaviors(controller, 1)
	TEST_ASSERT_EQUAL(controller.blackboard["human_npc_treat_item"], pack, "A hurt criminal didn't reach for its bruise pack")
	controller.CancelActions()
	controller.clear_blackboard_key("human_npc_treat_item")
	// A medipen comes first; a stimulant pen is never a treatment.
	var/obj/item/reagent_containers/hypospray/medipen/stimpack/stim = new(criminal)
	criminal.equip_to_slot_or_del(stim, ITEM_SLOT_RPOCKET)
	TEST_ASSERT_NULL(bounty_ai_find_medipen(criminal), "A stimulant pen counts as a treatment")
	TEST_ASSERT_EQUAL(bounty_ai_find_injector(criminal, /obj/item/reagent_containers/hypospray/medipen/stimpack), stim, "The stimulant pen isn't found as an injector")
	// With a target to fight, it doesn't stop to patch up.
	var/mob/living/carbon/human/consistent/hunter = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_bottom_left, EAST))
	controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, hunter)
	controller.clear_blackboard_key("human_npc_next_treat")
	treat.SelectBehaviors(controller, 1)
	TEST_ASSERT(!controller.blackboard_key_exists("human_npc_treat_item"), "A criminal in a fight stops to treat itself")
	qdel(treat)

// ===== MOMENT LINES =====

/**
 * The capture's moment lines always land (BUG-1): going into crit and being cuffed are said past the
 * bark cooldown, once each. No balloon says what the pay dropped to (2026-09-26: the world doesn't
 * explain the rules).
 */
/datum/unit_test/voidcrew_bounty_criminal_moments
	parent_type = /datum/unit_test/voidcrew_bounty_criminal
	/// Everything said aloud in the test
	var/list/heard = list()

/datum/unit_test/voidcrew_bounty_criminal_moments/proc/on_say(datum/source, list/speech_args)
	SIGNAL_HANDLER
	heard += speech_args[SPEECH_MESSAGE]

/// How many of the lines heard are in `pool` (say() html-encodes what it says: "I&#39;m done.")
/datum/unit_test/voidcrew_bounty_criminal_moments/proc/heard_from(list/pool)
	. = 0
	for(var/line in heard)
		if(html_decode(line) in pool)
			.++

/datum/unit_test/voidcrew_bounty_criminal_moments/Run()
	var/list/lines = bounty_identity_strings("lines")
	var/datum/criminal_bounty/posting = new

	// With no record, they use the shared lines only.
	var/mob/living/carbon/human/npc/bounty_criminal/normal/criminal = allocate(__IMPLIED_TYPE__)
	criminal.posting_ref = WEAKREF(posting)
	RegisterSignal(criminal, COMSIG_MOB_SAY, PROC_REF(on_say))
	var/datum/component/bounty_identity_voice/voice = criminal.LoadComponent(/datum/component/bounty_identity_voice)
	// They just said something: the cooldown is running.
	COOLDOWN_START(voice, line_cooldown, 8 SECONDS) // BOUNTY_SAY_COOLDOWN
	criminal.adjustBruteLoss(110)
	TEST_ASSERT(criminal.is_downed(), "The criminal did not go into crit")
	TEST_ASSERT_EQUAL(heard_from(lines["downed"]["any"]), 1, "Going into crit inside the cooldown, they said [heard_from(lines["downed"]["any"])] downed lines, not 1")
	TEST_ASSERT_NULL(criminal.body_last_alert, "Going down showed [criminal.body_last_alert] over them")
	// Cuffed a moment later, inside the cooldown of the downed line.
	cuff(criminal)
	TEST_ASSERT_EQUAL(heard_from(lines["cuffed"]["any"]), 1, "Cuffed inside the cooldown, they said [heard_from(lines["cuffed"]["any"])] cuffed lines, not 1")
	// Killed: still no balloon about the pay.
	criminal.death()
	TEST_ASSERT_NULL(criminal.body_last_alert, "Dying showed [criminal.body_last_alert] over them")

	// Marked closed first: deleting an open posting runs close(), which deletes it again (P5)
	posting.status = "closed" // BOUNTY_POSTING_CLOSED
	qdel(posting)
