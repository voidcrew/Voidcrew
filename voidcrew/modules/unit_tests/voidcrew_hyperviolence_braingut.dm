// Hyperviolence braingut part: brain burst, gut spill and the gut tether.
// Unit tests are included before voidcrew/_DEFINES, so the HV_ tunables are not visible here:
// the tests probe the thresholds through the procs instead of copying their values.

/// The smallest blow damage (1 to 200) for which check returns TRUE, or null if none does.
/datum/unit_test/proc/hv_smallest_blow(datum/callback/check)
	for(var/blow in 1 to 200)
		if(check.Invoke(blow))
			return blow

/// A head that bursts must throw its brain out whole, still holding the mind, and destroy the head.
/datum/unit_test/voidcrew_hv_head_burst

/datum/unit_test/voidcrew_hv_head_burst/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	victim.mind_initialize()
	var/datum/mind/victim_mind = victim.mind
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	var/obj/item/organ/brain/brain = victim.get_organ_slot(ORGAN_SLOT_BRAIN)
	var/obj/item/organ/eyes/eyes = victim.get_organ_slot(ORGAN_SLOT_EYES)
	TEST_ASSERT_NOTNULL(head, "Test fixture: the victim has no head")
	TEST_ASSERT_NOTNULL(brain, "Test fixture: the victim has no brain")
	var/turf/origin = get_turf(victim)

	TEST_ASSERT(victim.hv_burst_head(NORTH), "A head that could be removed did not burst")
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_HEAD), "The victim kept a head after it burst")
	TEST_ASSERT(QDELETED(head), "The burst head was left lying around")
	TEST_ASSERT(!QDELETED(brain), "The brain was destroyed by the burst")
	TEST_ASSERT_NOTNULL(brain.throwing, "The brain was not thrown")
	TEST_ASSERT(isturf(brain.loc), "The brain was left inside something instead of on the floor")
	TEST_ASSERT(!victim.hv_burst_head(NORTH), "A headless victim burst a head that is not there")

	sleep(2 SECONDS)
	TEST_ASSERT(!QDELETED(brain), "The brain was destroyed in flight")
	TEST_ASSERT(isturf(brain.loc), "The brain did not land on the floor")
	var/fling_distance = brain.y - origin.y
	TEST_ASSERT(fling_distance >= 1 && fling_distance <= 3, "The brain landed [fling_distance] tiles away, outside one to three tiles")
	TEST_ASSERT_EQUAL(brain.x, origin.x, "The brain left the line of the blow")
	TEST_ASSERT_EQUAL(brain.damage, 0, "The burst damaged the brain, so the victim could not be revived")
	TEST_ASSERT(!(brain.organ_flags & ORGAN_FAILING), "The burst left the brain failing")
	TEST_ASSERT_EQUAL(brain.brainmob?.mind, victim_mind, "The mind did not stay with the thrown brain")
	if(eyes)
		TEST_ASSERT(!QDELETED(eyes) && !istype(eyes.loc, /obj/item/bodypart), "The eyes stayed in a head that no longer exists")

/// Only a heavy crushing or piercing blow on a downed victim's wrecked head may burst it, not a plain beheading.
/datum/unit_test/voidcrew_hv_head_burst_gating

/datum/unit_test/voidcrew_hv_head_burst_gating/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	head.set_brute_dam(head.max_damage)
	var/datum/callback/blunt = CALLBACK(head, TYPE_PROC_REF(/obj/item/bodypart/head, hv_blow_bursts), WOUND_BLUNT)
	var/datum/callback/pierce = CALLBACK(head, TYPE_PROC_REF(/obj/item/bodypart/head, hv_blow_bursts), WOUND_PIERCE)
	var/datum/callback/slash = CALLBACK(head, TYPE_PROC_REF(/obj/item/bodypart/head, hv_blow_bursts), WOUND_SLASH)
	var/datum/callback/burn = CALLBACK(head, TYPE_PROC_REF(/obj/item/bodypart/head, hv_blow_bursts), WOUND_BURN)

	TEST_ASSERT(!blunt.Invoke(200), "A conscious victim's head burst")
	victim.set_stat(HARD_CRIT)
	var/min_blunt = hv_smallest_blow(blunt)
	TEST_ASSERT_NOTNULL(min_blunt, "No crushing blow bursts a wrecked head on a victim in hard crit")
	TEST_ASSERT(min_blunt >= 10, "A crushing blow of only [min_blunt] bursts a head")
	TEST_ASSERT_EQUAL(hv_smallest_blow(pierce), min_blunt, "Crushing and piercing blows need different strength")
	TEST_ASSERT_NULL(hv_smallest_blow(slash), "A cut bursts the head instead of taking it off")
	TEST_ASSERT_NULL(hv_smallest_blow(burn), "A burn bursts the head")

	victim.set_stat(DEAD)
	TEST_ASSERT_EQUAL(hv_smallest_blow(blunt), min_blunt, "A corpse needs a different blow than a victim in hard crit")

	// a head that is not wrecked never bursts, however hard the blow
	head.set_brute_dam(0)
	TEST_ASSERT_NULL(hv_smallest_blow(blunt), "A head with no damage burst")

/// A blow that is allowed to burst the head sends the knock-off through the burst, with the brain flung out of it.
/datum/unit_test/voidcrew_hv_head_burst_blow

/datum/unit_test/voidcrew_hv_head_burst_blow/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	var/obj/item/organ/brain/brain = victim.get_organ_slot(ORGAN_SLOT_BRAIN)
	head.hv_burst_pending = TRUE
	head.hv_blow_dir = NORTH
	TEST_ASSERT(head.dismember(BRUTE, TRUE), "The head was not removed")
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_HEAD), "The victim kept a head")
	TEST_ASSERT(QDELETED(head), "A burst blow left the head lying around instead of destroying it")
	TEST_ASSERT(!QDELETED(brain), "The brain was destroyed")
	TEST_ASSERT(isturf(brain.loc), "The brain stayed inside something")

/// A head knocked off by an ordinary blow still comes off whole, with the brain inside it.
/datum/unit_test/voidcrew_hv_head_plain_decap

/datum/unit_test/voidcrew_hv_head_plain_decap/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	var/obj/item/organ/brain/brain = victim.get_organ_slot(ORGAN_SLOT_BRAIN)
	TEST_ASSERT(head.dismember(BRUTE, TRUE), "The head was not removed")
	TEST_ASSERT(!QDELETED(head), "An ordinary decapitation destroyed the head")
	TEST_ASSERT_EQUAL(brain.loc, head, "An ordinary decapitation moved the brain out of the head")

/// Which blows to a chest can spill guts.
/datum/unit_test/voidcrew_hv_gut_spill_gating

/datum/unit_test/voidcrew_hv_gut_spill_gating/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/chest/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	var/min_slash
	for(var/blow in 1 to 200)
		if(chest.hv_can_spill_guts(blow, SHARP_EDGED, 0, FALSE))
			min_slash = blow
			break
	TEST_ASSERT_NOTNULL(min_slash, "No slash to a human chest can spill guts")
	TEST_ASSERT(min_slash >= 10, "A slash of only [min_slash] can spill guts")
	TEST_ASSERT(!chest.hv_can_spill_guts(min_slash - 1, SHARP_EDGED, 0, FALSE), "A slash just under the limit can spill guts")
	TEST_ASSERT(!chest.hv_can_spill_guts(200, NONE, 0, FALSE), "A blunt blow can spill guts")
	TEST_ASSERT(!chest.hv_can_spill_guts(200, SHARP_POINTY, 0, FALSE), "A stab can spill guts")
	TEST_ASSERT(!chest.hv_can_spill_guts(200, SHARP_EDGED, CANT_WOUND, FALSE), "A blow that cannot wound can spill guts")
	TEST_ASSERT(!chest.hv_can_spill_guts(200, SHARP_EDGED, 0, TRUE), "Forced damage can spill guts")
	TEST_ASSERT(!chest.hv_owner_downed(), "A conscious victim counted as downed")
	victim.set_stat(HARD_CRIT)
	TEST_ASSERT(chest.hv_owner_downed(), "A victim in hard crit did not count as downed")
	ADD_TRAIT(victim, TRAIT_NODISMEMBER, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!chest.hv_can_spill_guts(200, SHARP_EDGED, 0, FALSE), "A victim who cannot be dismembered can spill guts")
	REMOVE_TRAIT(victim, TRAIT_NODISMEMBER, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_NOTNULL(chest.hv_spill_guts(NORTH, "test"), "The spill was refused")
	TEST_ASSERT(!chest.hv_can_spill_guts(200, SHARP_EDGED, 0, FALSE), "A chest that has already spilled can spill again")

/// The spill replaces the cut it comes from, drops guts on the floor, and keeps bleeding until they go back in.
/datum/unit_test/voidcrew_hv_gut_spill

/datum/unit_test/voidcrew_hv_gut_spill/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/chest/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	var/datum/wound/slash/flesh/severe/cut = new
	cut.apply_wound(chest)
	TEST_ASSERT_EQUAL(chest.get_wound_type(/datum/wound/slash/flesh), cut, "Test fixture: the cut was not applied")

	var/datum/wound/slash/flesh/critical/disembowel/spill = chest.hv_spill_guts(NORTH, "test")
	TEST_ASSERT_NOTNULL(spill, "The chest did not spill")
	TEST_ASSERT(QDELETED(cut), "The spill did not replace the cut it came from")
	TEST_ASSERT_EQUAL(chest.get_wound_type(/datum/wound/slash/flesh), spill, "The spill is not the chest's cut")
	TEST_ASSERT(spill.guts_out, "The wound does not count the guts as out")
	var/obj/item/hv_intestines/guts = spill.guts
	TEST_ASSERT_NOTNULL(guts, "No guts were dropped")
	TEST_ASSERT(isturf(guts.loc), "The guts were not dropped on the floor")
	TEST_ASSERT(spill.blood_flow >= spill.minimum_flow, "The spill is not bleeding")
	TEST_ASSERT(victim.has_movespeed_modifier(/datum/movespeed_modifier/hv_gut_spill), "A victim holding their guts in was not slowed")

	// the cut will not close while the guts are out, however much it is dressed
	spill.adjust_blood_flow(-100)
	TEST_ASSERT(!QDELETED(spill), "The spill closed with the guts still out")
	TEST_ASSERT_EQUAL(spill.blood_flow, spill.minimum_flow, "Treating the cut took the bleeding below its floor")

	// pushing the guts back in leaves the plain cut it was, and uses the guts up
	spill.finish_push_back(guts)
	TEST_ASSERT(QDELETED(spill), "The spill outlived the guts going back in")
	TEST_ASSERT(QDELETED(guts), "The guts were not used up")
	TEST_ASSERT_NOTNULL(chest.get_wound_type(/datum/wound/slash/flesh/severe), "Pushing the guts back in did not leave the severe cut")
	TEST_ASSERT(!victim.has_movespeed_modifier(/datum/movespeed_modifier/hv_gut_spill), "The victim stayed slowed after the guts went back in")

/// The strand is drawn, drags the guts along when the victim walks off, and cutting it hurts once.
/datum/unit_test/voidcrew_hv_gut_tether

/datum/unit_test/voidcrew_hv_gut_tether/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/chest/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	var/datum/wound/slash/flesh/critical/disembowel/spill = chest.hv_spill_guts(NORTH, "test")
	var/datum/hv_gut_tether/tether = spill.tether
	var/obj/item/hv_intestines/guts = spill.guts
	TEST_ASSERT_NOTNULL(tether, "The spill made no tether")
	TEST_ASSERT_NOTNULL(tether.strand, "The tether has no strand")

	// walking away tugs the guts along behind the victim
	var/turf/start = get_turf(victim)
	var/damage_before = chest.get_damage()
	victim.forceMove(run_loc_floor_top_right)
	TEST_ASSERT_EQUAL(get_turf(guts), start, "The guts did not follow the victim")
	TEST_ASSERT(!tether.cut, "A tug cut the tether")
	TEST_ASSERT(chest.get_damage() > damage_before, "A tug on the tether did not hurt")

	// cutting it hurts and drops the victim, and it never reconnects
	victim.SetKnockdown(0)
	tether.tear(FALSE)
	TEST_ASSERT(tether.cut, "The tether was not cut")
	TEST_ASSERT_NULL(tether.strand, "The strand outlived the cut")
	TEST_ASSERT(victim.IsKnockdown(), "Cutting the tether did not drop the victim")
	tether.refresh()
	TEST_ASSERT_NULL(tether.strand, "A cut tether reconnected")
	TEST_ASSERT(spill.guts_out, "Cutting the tether put the guts back")

/// Nothing dangles when the guts or the wound go away, and a torn tether stays torn.
/datum/unit_test/voidcrew_hv_gut_tether_cleanup

/datum/unit_test/voidcrew_hv_gut_tether_cleanup/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/chest/chest = victim.get_bodypart(BODY_ZONE_CHEST)

	// guts destroyed: the wound stays, with nothing out and nothing tethered
	var/datum/wound/slash/flesh/critical/disembowel/spill = chest.hv_spill_guts(NORTH, "test")
	var/obj/item/hv_intestines/guts = spill.guts
	var/datum/hv_gut_tether/tether = spill.tether
	qdel(guts)
	TEST_ASSERT_NULL(spill.guts, "The wound kept a reference to destroyed guts")
	TEST_ASSERT(!spill.guts_out, "The wound still counts destroyed guts as out")
	TEST_ASSERT_NULL(spill.tether, "The wound kept a tether to destroyed guts")
	TEST_ASSERT(QDELETED(tether), "The tether outlived the guts")
	TEST_ASSERT(!QDELETED(spill), "Losing the guts removed the wound")
	TEST_ASSERT(!victim.has_movespeed_modifier(/datum/movespeed_modifier/hv_gut_spill), "The victim stayed slowed with no guts out")
	qdel(spill)

	// wound removed: the strand goes, the guts stay where they lie
	spill = chest.hv_spill_guts(NORTH, "test")
	guts = spill.guts
	tether = spill.tether
	var/datum/beam/strand = tether.strand
	qdel(spill)
	TEST_ASSERT(QDELETED(tether), "The tether outlived the wound")
	TEST_ASSERT(isnull(strand) || QDELETED(strand), "The strand outlived the wound")
	TEST_ASSERT(!QDELETED(guts), "Removing the wound destroyed the guts")
	TEST_ASSERT(!victim.has_movespeed_modifier(/datum/movespeed_modifier/hv_gut_spill), "The victim stayed slowed after the wound went")

	// a tear cuts the tether for good
	spill = chest.hv_spill_guts(NORTH, "test")
	tether = spill.tether
	tether.tear(TRUE)
	TEST_ASSERT(tether.cut, "A tear did not cut the tether")
	TEST_ASSERT_NULL(tether.strand, "The strand outlived the tear")
