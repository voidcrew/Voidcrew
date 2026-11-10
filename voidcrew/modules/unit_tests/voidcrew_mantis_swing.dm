/// An ordinary hit swings the hand that hit (voidcrew/modules/mantis_gore/mantis_swing.dm): the swing plays on
/// the bearer, the held blade hides under it, and putting the blade away ends it. Each hand's slash over the target
/// runs the way its own blade cuts.
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
	// The slash over the target goes up with the swing, so the client plays both from the same moment.
	var/obj/effect/abstract/cyberware_anim/slash = blade.swing_impact_ref?.resolve()
	TEST_ASSERT(slash && (slash in target.vis_contents), "The swing put no slash over its target")

	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/right = housings(user)[1]
	right.Retract()
	TEST_ASSERT(QDELETED(swing), "Putting the blade away left its swing playing")

	// Facing south the two hands cut toward each other, so their slashes are mirror images.
	TEST_ASSERT(mantis_swing_impact_mirrored(SOUTH, "right") != mantis_swing_impact_mirrored(SOUTH, "left"), "Facing south both hands' swings show the same slash")
	// The swing's say goes over the side the target is on (east of the user here, which draws it plain).
	var/obj/effect/abstract/cyberware_anim/impact = cyberware_play_impact(user, target, "impact_mantis", TRUE)
	TEST_ASSERT(impact, "No impact was drawn on the target")
	var/matrix/turned = impact.transform
	TEST_ASSERT(turned.a < 0, "An impact told to mirror was drawn plain")

/// The name of the mask on a far arm's picture (CHROME_ANIM_ARM_COVER_FILTER, cyberware_anim.dm).
#define MANTIS_TEST_SWING_COVER "chrome_arm_cover"

/// Whether [under] is drawn under [over] on [body]: pictures in vis_contents draw in the order they went in.
/datum/unit_test/voidcrew_mantis_gore/proc/drawn_under(mob/living/body, atom/movable/under, atom/movable/over)
	var/list/order = list()
	for(var/atom/movable/picture as anything in body.vis_contents)
		order += picture
	var/low = order.Find(under)
	var/high = order.Find(over)
	return low && high && low < high

/// [body]'s other held Mantis blade, not [blade].
/datum/unit_test/voidcrew_mantis_gore/proc/other_blade(mob/living/carbon/body, obj/item/blade)
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/held in body.held_items)
		if(held != blade)
			return held

/// Side on, the far arm swings behind the near one: what the near hand holds is cut out of the far swing while
/// it is drawn in the hand, and not while the near blade swings itself, nor once the bearer turns around.
/datum/unit_test/voidcrew_mantis_gore/swing_far

/datum/unit_test/voidcrew_mantis_gore/swing_far/Run()
	var/mob/living/carbon/human/user = bearer(spot(0, 0))
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	ADD_TRAIT(target, TRAIT_GODMODE, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/near = right_blade(user)
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/far = other_blade(user, near)
	TEST_ASSERT(far, "Fixture: the bearer holds one blade")
	near.show_inhand()
	far.show_inhand()
	user.set_combat_mode(TRUE)
	user.setDir(EAST)

	user.swap_hand(user.get_held_index_of_item(far))
	far.melee_attack_chain(user, target)
	var/obj/effect/abstract/cyberware_anim/mantis_swing/far_swing = far.mantis_swing()
	TEST_ASSERT(far_swing, "The far hand didn't swing")
	TEST_ASSERT(far_swing.get_filter(MANTIS_TEST_SWING_COVER), "The far arm's swing draws over the near blade")

	// The near blade swings too: it leaves the hand, and its own swing is drawn in front.
	user.swap_hand(user.get_held_index_of_item(near))
	near.melee_attack_chain(user, target)
	var/obj/effect/abstract/cyberware_anim/mantis_swing/near_swing = near.mantis_swing()
	TEST_ASSERT(near_swing, "The near hand didn't swing")
	TEST_ASSERT(!near_swing.get_filter(MANTIS_TEST_SWING_COVER), "Something is cut out of the near arm's swing")
	TEST_ASSERT(drawn_under(user, far_swing, near_swing), "The near arm's swing is under the far arm's")
	TEST_ASSERT(!far_swing.get_filter(MANTIS_TEST_SWING_COVER), "The far swing is still cut around a blade that left the hand")

	// Back in the hand, it is cut out again.
	near.show_inhand()
	far_swing.fit_to_facing()
	TEST_ASSERT(far_swing.get_filter(MANTIS_TEST_SWING_COVER), "The near blade came back and the far swing draws over it")

	// Facing west the left hand is the near one.
	user.setDir(WEST)
	TEST_ASSERT(!far_swing.get_filter(MANTIS_TEST_SWING_COVER), "Turning around kept the left swing cut")
	TEST_ASSERT(drawn_under(user, near_swing, far_swing), "Turning around kept the left swing under the right")

/// Side on, the far blade unfolds and folds behind the near one, as it swings behind it: the near blade is cut out
/// of the far arm's picture, which goes under the near arm's.
/datum/unit_test/voidcrew_mantis_gore/unfold_far

/datum/unit_test/voidcrew_mantis_gore/unfold_far/Run()
	var/mob/living/carbon/human/user = bearer(spot(0, 0), out = FALSE)
	user.setDir(EAST)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/right = housings(user)[1]
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left = housings(user)[2]

	// Facing east the right arm is the near one. Its blade is out and drawn in the hand.
	right.Extend(right.contents[1])
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/near = right.active_item
	near.show_inhand()
	var/obj/effect/abstract/cyberware_anim/near_unfold = right.blade_anim()
	TEST_ASSERT(near_unfold, "Fixture: the near blade's unfold never played")
	TEST_ASSERT(!near_unfold.get_filter(MANTIS_TEST_SWING_COVER), "Something is cut out of the near arm's unfold")

	left.Extend(left.contents[1])
	var/obj/effect/abstract/cyberware_anim/far_unfold = left.blade_anim()
	TEST_ASSERT(far_unfold, "Fixture: the far blade's unfold never played")
	TEST_ASSERT(far_unfold.get_filter(MANTIS_TEST_SWING_COVER), "The far blade unfolds over the near blade")
	TEST_ASSERT(drawn_under(user, far_unfold, near_unfold), "The far blade's unfold isn't under the near blade's")

	// And back in: the far blade folds behind the near one.
	left.Retract()
	var/obj/effect/abstract/cyberware_anim/far_fold = left.blade_anim()
	TEST_ASSERT(far_fold, "Fixture: the far blade's fold never played")
	TEST_ASSERT(far_fold.get_filter(MANTIS_TEST_SWING_COVER), "The far blade folds over the near blade")

	// Turned around, the left arm is the near one: nothing is cut out of its pictures.
	left.Extend(left.contents[1])
	user.setDir(WEST)
	var/obj/effect/abstract/cyberware_anim/left_unfold = left.blade_anim()
	TEST_ASSERT(left_unfold && !left_unfold.get_filter(MANTIS_TEST_SWING_COVER), "The near blade's unfold is cut around the far blade")

/// Only the blade that hit takes the blood: a hit or a kill with one blade leaves the other clean. The X-slash
/// cuts with both, so both run red.
/datum/unit_test/voidcrew_mantis_gore/swing_blood

/datum/unit_test/voidcrew_mantis_gore/swing_blood/Run()
	var/mob/living/carbon/human/user = bearer(spot(0, 0))
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = right_blade(user)
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/other = other_blade(user, blade)
	TEST_ASSERT(other, "Fixture: the bearer holds one blade")
	blade.show_inhand()
	user.set_combat_mode(TRUE)
	user.swap_hand(user.get_held_index_of_item(blade))

	// Ordinary hits, on two people in turn so none is an X-slash: any blood is on the blade that swung.
	var/mob/living/carbon/human/consistent/first = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	var/mob/living/carbon/human/consistent/second = allocate(/mob/living/carbon/human/consistent, spot(0, 1))
	for(var/i in 1 to 6)
		blade.melee_attack_chain(user, i % 2 ? first : second)
		TEST_ASSERT(!other.is_bloody(), "A hit with one blade bloodied the other")

	// A kill: only the blade that made it runs red.
	var/mob/living/carbon/human/consistent/killed = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	killed.adjustOxyLoss(185)
	cut(blade, user, killed, BODY_ZONE_CHEST, 30)
	TEST_ASSERT_EQUAL(killed.stat, DEAD, "Fixture: the cut didn't kill (health [killed.health])")
	TEST_ASSERT(blade.drenched_until > world.time, "The killing blade didn't run red")
	TEST_ASSERT(!other.is_bloody() && !other.drenched_until, "A kill with one blade bloodied the other")

	// The X-slash lands at once with no swing playing; both blades cut, both run red.
	qdel(blade.mantis_swing())
	var/mob/living/carbon/human/consistent/crossed = allocate(/mob/living/carbon/human/consistent, spot(2, 0))
	for(var/i in 1 to 3)
		cut(blade, user, crossed, BODY_ZONE_CHEST)
	TEST_ASSERT(crossed.has_status_effect(/datum/status_effect/staggered), "Fixture: the third cut was no X-slash")
	TEST_ASSERT(other.drenched_until > world.time, "The X-slash left the other blade clean")

#undef MANTIS_TEST_SWING_COVER
