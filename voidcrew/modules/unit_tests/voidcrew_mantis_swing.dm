/// An ordinary hit swings the hand that hit (voidcrew/modules/mantis_gore/mantis_swing.dm): the swing plays on
/// the bearer, the held blade hides under it, and putting the blade away ends it.
/datum/unit_test/voidcrew_mantis_gore/swing

/datum/unit_test/voidcrew_mantis_gore/swing/Run()
	var/mob/living/carbon/human/user = bearer(spot(0, 0))
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = right_blade(user)
	user.swap_hand(user.get_held_index_of_item(blade))
	user.set_combat_mode(TRUE)
	// The unfold still hides the blade; that wait is over in play.
	blade.show_inhand()

	blade.melee_attack_chain(user, target)
	var/obj/effect/abstract/cyberware_anim/swing = blade.mantis_swing()
	TEST_ASSERT(swing && (swing in user.vis_contents), "A hit didn't swing the blade")
	TEST_ASSERT_EQUAL(swing.icon_state, "mantis_swing_right", "The right hand swung the wrong picture")
	TEST_ASSERT(blade.inhand_hidden_until > world.time, "The held blade draws under its own swing")

	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/right = housings(user)[1]
	right.Retract()
	TEST_ASSERT(QDELETED(swing), "Putting the blade away left its swing playing")
