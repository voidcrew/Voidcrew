/** Scoped observers, actual meal custody, and identity-sensitive work. */

/datum/unit_test/vestige_morph
	abstract_type = /datum/unit_test/vestige_morph
	var/mob/living/carbon/human/consistent/user
	var/turf/center
	var/list/terrain_originals = list()

/datum/unit_test/vestige_morph/New()
	..()
	center = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()

/datum/unit_test/vestige_morph/Destroy()
	for(var/list/record as anything in terrain_originals)
		var/turf/spot = locate(record[1], record[2], record[3])
		spot.ChangeTurf(record[4])
	return ..()

/// The perception regression needs more than the default room's five tiles.
/datum/unit_test/vestige_morph/proc/open_test_corridor(length)
	for(var/index in 0 to length)
		var/turf/spot = locate(center.x + index, center.y, center.z)
		terrain_originals += list(list(spot.x, spot.y, spot.z, spot.type))
		spot.ChangeTurf(/turf/open/floor/plating)

/datum/unit_test/vestige_morph/proc/prepare(trial_type)
	var/datum/vestige_trial/morph_scenario/trial = allocate(trial_type, user.mind)
	user.mind.active_vestige_trial = trial
	trial.on_accepted(user)
	STOP_PROCESSING(SSfastprocess, trial.invitation)
	user.dropItemToGround(trial.invitation)
	return trial

/// Arrange stations inside the five-by-five unit room. Deployment's seven-tile site is a separate player constraint.
/datum/unit_test/vestige_morph/proc/balance_fixture()
	var/datum/vestige_trial/understudy/trial = prepare(/datum/vestige_trial/understudy)
	STOP_PROCESSING(SSobj, trial.skin)
	trial.input = trial.register_loan(new /obj/structure/vestige_morph_station(center))
	trial.left_dock = trial.register_loan(new /obj/structure/vestige_morph_station(get_step(get_step(center, WEST), WEST)))
	trial.right_dock = trial.register_loan(new /obj/structure/vestige_morph_station(get_step(get_step(center, EAST), EAST)))
	for(var/obj/structure/vestige_morph_station/station in list(trial.input, trial.left_dock, trial.right_dock))
		station.trial_ref = WEAKREF(trial)
	trial.spawn_actor(center, "test custodian")
	user.forceMove(get_step(center, NORTH))
	return trial

/datum/unit_test/vestige_morph/proc/borrow_identity(datum/vestige_trial/understudy/trial)
	trial.skin.apply_form(user, trial.actor)
	trial.skin.form = 2
	trial.skin.saved_real_name = user.real_name
	user.real_name = trial.actor.real_name
	trial.skin.quarry_ref = WEAKREF(trial.actor)

/datum/unit_test/vestige_morph/copy_visibility/Run()
	var/datum/vestige_trial/perfect_copy/trial = prepare(/datum/vestige_trial/perfect_copy)
	STOP_PROCESSING(SSobj, trial.skin)
	trial.roles = list("tool", "food")
	trial.spawn_actor(get_step(center, WEST), "test scavenger")
	var/obj/item/wrench/original = allocate(/obj/item/wrench, center)
	var/obj/item/storage/backpack/bag = allocate(/obj/item/storage/backpack, center)
	TEST_ASSERT(trial.source_visible(original), "A floor original in sight must be detected.")
	original.forceMove(bag)
	TEST_ASSERT(!trial.source_visible(original), "A bag must actually hide the original despite sharing a visible turf.")
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, center)
	original.forceMove(locker)
	locker.opened = FALSE
	TEST_ASSERT(!trial.source_visible(original), "A closed locker must conceal its contents.")
	locker.opened = TRUE
	TEST_ASSERT(trial.source_visible(original), "An open locker must expose the duplicate.")
	original.forceMove(center)
	TEST_ASSERT(trial.matches_role(original), "An ordinary wrench must satisfy the requested tool role.")
	var/obj/item/food/burger/plain/food = allocate(/obj/item/food/burger/plain, center)
	TEST_ASSERT(!trial.matches_role(food), "Food cannot satisfy a tool request.")
	trial.skin.wear_object(user, original)
	trial.run_scene(user, 0.6)
	TEST_ASSERT_EQUAL(trial.skin.form, 0, "A visible original must cause actual disguise rejection.")
	TEST_ASSERT_EQUAL(trial.role_index, 1, "Rejected duplicates must not advance the performance.")

/datum/unit_test/vestige_morph/copy_approach/Run()
	var/datum/vestige_trial/perfect_copy/trial = prepare(/datum/vestige_trial/perfect_copy)
	STOP_PROCESSING(SSobj, trial.skin)
	trial.roles = list("tool", "food")
	user.forceMove(get_step(get_step(center, EAST), EAST))
	trial.spawn_actor(get_step(get_step(center, WEST), WEST), "test scavenger")
	var/obj/item/wrench/original = allocate(/obj/item/wrench, get_turf(user))
	var/obj/item/storage/backpack/bag = allocate(/obj/item/storage/backpack, get_turf(user))
	trial.skin.wear_object(user, original)
	original.forceMove(bag)
	TEST_ASSERT(!trial.reveal(user), "A disguise alone cannot count before a real approach and inspection.")
	for(var/index in 1 to 6)
		trial.next_action = 0
		trial.run_scene(user, 0.6)
	TEST_ASSERT(trial.approach_steps >= 2, "The observer must really walk toward the copied item.")
	TEST_ASSERT(trial.inspection_until > world.time, "A real approach must open the timed inspection.")
	TEST_ASSERT(trial.reveal(user), "Bursting during the adjacent inspection must count.")
	TEST_ASSERT_EQUAL(trial.role_index, 2, "The first performance must request the second role.")
	TEST_ASSERT_EQUAL(trial.skin.form, 0, "A successful reveal must restore the user.")
	trial.roles[2] = "tool"
	original.forceMove(get_turf(user))
	trial.skin.wear_object(user, original)
	original.forceMove(bag)
	QDEL_NULL(trial.watched_spot)
	trial.watched_spot = trial.mark_turf(center)
	trial.next_action = 0
	trial.run_scene(user, 0.6)
	TEST_ASSERT_EQUAL(trial.skin.form, 0, "Visible movement must shed the object disguise.")
	TEST_ASSERT_EQUAL(trial.role_index, 2, "Moving in view cannot add another performance.")

/datum/unit_test/vestige_morph/meal_custody/Run()
	var/datum/vestige_trial/snatched_meal/trial = prepare(/datum/vestige_trial/snatched_meal)
	STOP_PROCESSING(SSobj, trial.maw)
	TEST_ASSERT(!trial.can_take(user), "An undeployed pantry must not offer a meal or runtime.")
	trial.pantry = trial.register_loan(new /obj/structure/vestige_morph_station(get_step(center, WEST)))
	trial.pantry.trial_ref = WEAKREF(trial)
	trial.course = trial.register_loan(new /obj/item/food/burger/plain(trial.pantry))
	trial.spawn_actor(center, "test porter")
	TEST_ASSERT(!trial.can_take(user), "The porter beside its pantry must prevent a free pickup.")
	user.forceMove(get_turf(trial.pantry))
	var/turf/lure_site = get_step(get_step(center, EAST), EAST)
	var/result = lure_site.base_ranged_item_interaction(user, trial.maw, list())
	TEST_ASSERT(result & ITEM_INTERACT_SUCCESS, "The real ranged click must dispatch the maw's scent lure.")
	TEST_ASSERT_EQUAL(get_turf(trial.decoy), lure_site, "The lure must spawn on the aimed ground.")
	TEST_ASSERT(!trial.decoy_ready, "Spitting must consume the one available lure.")
	for(var/index in 1 to 3)
		trial.next_action = 0
		trial.run_scene(user, 0.4)
	TEST_ASSERT_EQUAL(get_turf(trial.actor), lure_site, "The porter must reach the nearest legal lure instead of stopping too close to the pantry.")
	TEST_ASSERT(trial.can_take(user), "Separating the guard by three tiles must permit the theft channel.")
	result = trial.pantry.base_item_interaction(user, trial.maw, list())
	TEST_ASSERT(result & ITEM_INTERACT_SUCCESS, "The pantry click must channel the guarded taking interaction.")
	TEST_ASSERT_EQUAL(trial.course.loc, trial.maw, "The actual guarded meal must move into the maw.")
	TEST_ASSERT_EQUAL(trial.maw.stored_course, trial.course, "The stored course must be the exact loan meal.")
	TEST_ASSERT(user.has_movespeed_modifier(/datum/movespeed_modifier/vestige_full_maw), "Carrying the swallowed meal must slow the bearer.")
	TEST_ASSERT(!trial.can_digest(user), "Standing at the pantry cannot digest the stolen meal.")
	QDEL_NULL(trial.decoy)
	trial.actor.forceMove(center)
	trial.next_action = 0
	trial.run_scene(user, 0.4)
	TEST_ASSERT_EQUAL(trial.course.loc, trial.pantry, "An adjacent pursuing porter must reclaim the real meal.")
	TEST_ASSERT_NULL(trial.maw.stored_course, "Reclamation must clear the maw's custody state.")
	TEST_ASSERT(!user.has_movespeed_modifier(/datum/movespeed_modifier/vestige_full_maw), "Reclamation must remove the burden modifier.")

/datum/unit_test/vestige_morph/meal_cleanup/Run()
	var/datum/vestige_trial/snatched_meal/trial = prepare(/datum/vestige_trial/snatched_meal)
	STOP_PROCESSING(SSobj, trial.maw)
	trial.pantry = trial.register_loan(new /obj/structure/vestige_morph_station(center))
	trial.course = trial.register_loan(new /obj/item/food/burger/plain(trial.maw))
	trial.maw.stored_course = trial.course
	trial.maw.set_fullness(TRUE, user)
	var/obj/item/wrench/player_property = allocate(/obj/item/wrench, trial.maw)
	user.dropItemToGround(trial.maw)
	TEST_ASSERT_EQUAL(trial.course.loc, trial.pantry, "Dropping a full maw must return the real meal.")
	TEST_ASSERT(!user.has_movespeed_modifier(/datum/movespeed_modifier/vestige_full_maw), "Dropping the maw must remove its slowdown immediately.")
	var/obj/item/vestige_hungry_maw/old_maw = trial.maw
	qdel(trial)
	TEST_ASSERT(QDELETED(old_maw), "Trial destruction must reclaim its registered maw.")
	TEST_ASSERT(!QDELETED(player_property), "Cancelling cannot destroy player-added maw contents.")
	TEST_ASSERT_EQUAL(get_turf(player_property), center, "Cancellation must return unrelated property to the floor.")

/datum/unit_test/vestige_morph/understudy_routine/Run()
	var/datum/vestige_trial/understudy/trial = balance_fixture()
	trial.start_demo(user)
	trial.next_action = 0
	trial.run_scene(user, 0.6)
	TEST_ASSERT(trial.actor.is_holding(trial.carried), "The demonstration must use the custodian's actual hand inventory.")
	TEST_ASSERT(length(trial.actor.held_appearances), "The custodian's real held parcel must also have a visible hand overlay.")
	for(var/index in 1 to 30)
		trial.next_action = 0
		trial.run_scene(user, 0.6)
	TEST_ASSERT(trial.ready, "Witnessing all three actual deliveries must unlock impersonation.")
	TEST_ASSERT_EQUAL(trial.observed_deliveries, 3, "Only real witnessed deliveries count as observation.")
	TEST_ASSERT_EQUAL(trial.dock_load(trial.left_dock), 2 * trial.amber_share, "The actual amber deliveries must demonstrate the chosen share.")
	TEST_ASSERT_EQUAL(trial.dock_load(trial.right_dock), 2 * trial.violet_share, "The actual violet deliveries must demonstrate the chosen share.")
	TEST_ASSERT(!trial.production && !trial.fulfilled, "Observing the worker alone must not complete or deliver the challenge shipment.")
	trial.start_shipment()
	var/total = 0
	var/heaviest = 0
	for(var/obj/item/vestige_morph_parcel/parcel as anything in trial.parcels)
		total += parcel.cargo_load
		heaviest = max(heaviest, parcel.cargo_load)
	TEST_ASSERT_EQUAL(total, 12, "The new shipment must require applying the demonstrated proportion at a new scale.")
	TEST_ASSERT_EQUAL(length(trial.parcels), 4, "The routing challenge must not add an arbitrary hauling quota.")
	TEST_ASSERT(heaviest > 2, "The challenge must require applying the routine to different weights.")

/datum/unit_test/vestige_morph/understudy_identity/Run()
	var/datum/vestige_trial/understudy/trial = balance_fixture()
	trial.production = TRUE
	var/obj/item/vestige_morph_parcel/first = trial.make_parcel(7)
	var/obj/item/vestige_morph_parcel/second = trial.make_parcel(2)
	user.put_in_hands(first)
	user.forceMove(get_step(trial.left_dock, EAST))
	TEST_ASSERT(!trial.deliver(user, first, trial.left_dock), "Receiving trays must reject a parcel without the borrowed custodian identity.")
	var/original_name = user.real_name
	borrow_identity(trial)
	TEST_ASSERT(trial.has_identity(user), "The exact custodian form and active skin must open receiving access.")
	TEST_ASSERT(trial.deliver(user, first, trial.left_dock), "An identified worker can deliver a held parcel.")
	user.put_in_hands(second)
	TEST_ASSERT(trial.deliver(user, second, trial.left_dock), "An overload must be handled as a recoverable delivery.")
	TEST_ASSERT_EQUAL(first.loc, get_turf(trial.left_dock), "Overload must spill earlier parcels for correction.")
	TEST_ASSERT_EQUAL(second.loc, get_turf(trial.left_dock), "Overload must return the last parcel too.")
	TEST_ASSERT(!trial.release(user), "An incomplete unbalanced shipment must never complete the pact.")
	var/datum/vestige_trial/understudy/replacement = allocate(/datum/vestige_trial/understudy, user.mind)
	user.mind.active_vestige_trial = replacement
	TEST_ASSERT(!trial.has_identity(user), "A stale skin cannot impersonate the same role for another attempt.")
	trial.skin.process(1)
	TEST_ASSERT_EQUAL(trial.skin.form, 0, "Replacing the active attempt must shed the borrowed face.")
	TEST_ASSERT_EQUAL(user.real_name, original_name, "Ending an attempt must restore the wearer's real name.")
	TEST_ASSERT_NULL(trial.skin.wearer_ref, "Cleanup must clear the disguise wearer binding.")

/datum/unit_test/vestige_morph/meal_escape_finish/Run()
	open_test_corridor(10)
	var/datum/vestige_trial/snatched_meal/trial = prepare(/datum/vestige_trial/snatched_meal)
	STOP_PROCESSING(SSobj, trial.maw)
	trial.pantry = trial.register_loan(new /obj/structure/vestige_morph_station(center))
	trial.course = trial.register_loan(new /obj/item/food/burger/plain(trial.maw))
	trial.maw.stored_course = trial.course
	trial.maw.set_fullness(TRUE, user)
	trial.spawn_actor(locate(center.x + 2, center.y, center.z), "test porter")
	user.forceMove(locate(center.x + 10, center.y, center.z))
	TEST_ASSERT(trial.porter_sees(user), "An open eight-tile line must be within the porter's actual pursuit sight.")
	TEST_ASSERT(!trial.can_digest(user), "A visible bearer at eight tiles must not count as escaped.")
	var/turf/obstruction = locate(center.x + 6, center.y, center.z)
	obstruction.ChangeTurf(/turf/closed/wall)
	TEST_ASSERT(!trial.porter_sees(user), "Real opaque terrain must break the porter's pursuit sight.")
	TEST_ASSERT(trial.can_digest(user), "A held actual meal beyond six pantry tiles and behind cover must be digestible.")
	var/obj/item/food/old_course = trial.course
	trial.maw.attack_self(user)
	TEST_ASSERT(QDELETED(old_course), "Successful digestion must consume the exact loan meal.")
	TEST_ASSERT(QDELETED(trial), "Successful digestion must complete and reclaim the encounter.")
	TEST_ASSERT(/datum/vestige_trial/snatched_meal in user.mind.completed_vestige_trials, "The real digestion channel must record completion.")
	TEST_ASSERT(!user.has_movespeed_modifier(/datum/movespeed_modifier/vestige_full_maw), "Finishing must remove the full-maw burden.")

/datum/unit_test/vestige_morph/understudy_finish/Run()
	var/datum/vestige_trial/understudy/trial = balance_fixture()
	trial.production = TRUE
	trial.amber_share = 2
	trial.violet_share = 1
	var/original_name = user.real_name
	borrow_identity(trial)
	for(var/load in list(4, 4, 2, 2))
		var/obj/item/vestige_morph_parcel/parcel = trial.make_parcel(load)
		user.put_in_hands(parcel)
		var/obj/structure/vestige_morph_station/destination = load == 4 ? trial.left_dock : trial.right_dock
		user.forceMove(get_step_towards(destination, center))
		var/result = destination.base_item_interaction(user, parcel, list())
		TEST_ASSERT(result & ITEM_INTERACT_SUCCESS, "A real parcel click by the borrowed worker must reach the receiving tray.")
		TEST_ASSERT_EQUAL(parcel.loc, destination, "A successful delivery must physically leave the parcel in the tray.")
	user.forceMove(center)
	trial.amber_share = 1
	TEST_ASSERT(!trial.release(user), "A complete but incorrectly proportioned shipment must be rejected.")
	trial.amber_share = 2
	var/result = trial.input.base_item_interaction(user, trial.skin, list())
	TEST_ASSERT(result & ITEM_INTERACT_SUCCESS, "The release click must reach the workstation before the skin's object interaction.")
	TEST_ASSERT(QDELETED(trial), "A whole shipment matching the demonstrated ratio must complete.")
	TEST_ASSERT(/datum/vestige_trial/understudy in user.mind.completed_vestige_trials, "The actual release must record the completed trial.")
	TEST_ASSERT_EQUAL(user.real_name, original_name, "Completing must restore the original identity immediately.")

/// Existing wounds transfer into a disguise without counting as a new strike.
/datum/unit_test/vestige_morph/mimic_existing_damage/Run()
	user.adjustBruteLoss(10)
	var/obj/item/wrench/model = allocate(/obj/item/wrench, center)
	var/datum/action/cooldown/spell/shapeshift/vestige_mimic/spell = allocate(/datum/action/cooldown/spell/shapeshift/vestige_mimic, user.mind)
	spell.Grant(user)
	TEST_ASSERT(spell.PreActivate(model), "An injured caster must be able to activate a valid object disguise.")
	var/mob/living/basic/vestige_mimic/shape = user.loc
	TEST_ASSERT(istype(shape), "The actual cast must put the caster inside its borrowed shape.")
	sleep(2)
	TEST_ASSERT(!QDELETED(shape) && user.loc == shape, "Damage transferred during initialization must not immediately break the new disguise.")
	TEST_ASSERT_EQUAL(shape.getBruteLoss(), 10, "Ignoring the initialization hit must preserve the caster's existing damage.")
	shape.apply_damage(1, BRUTE)
	sleep(2)
	TEST_ASSERT(QDELETED(shape) && isturf(user.loc), "A new hit after formation must still break the disguise and restore its caster.")
	TEST_ASSERT_EQUAL(user.getBruteLoss(), 11, "The caster must keep both the old wounds and the new disguise-breaking hit.")

/datum/unit_test/vestige_morph/gullet_transfer
	var/mob/living/replacement

/datum/unit_test/vestige_morph/gullet_transfer/proc/transfer_during_heave(mob/living/source)
	SIGNAL_HANDLER
	source.mind.transfer_to(replacement)

/datum/unit_test/vestige_morph/gullet_transfer/Run()
	var/datum/action/cooldown/spell/vestige_devour/spell = allocate(/datum/action/cooldown/spell/vestige_devour, user.mind)
	spell.Grant(user)
	var/obj/item/wrench/keeping = allocate(/obj/item/wrench, spell.stash)
	replacement = allocate(/mob/living/carbon/human/consistent, get_step(center, EAST))
	RegisterSignal(user, COMSIG_DO_AFTER_BEGAN, PROC_REF(transfer_during_heave))
	var/cast_succeeded = spell.PreActivate(user)
	UnregisterSignal(user, COMSIG_DO_AFTER_BEGAN)
	TEST_ASSERT_EQUAL(spell.owner, replacement, "The gullet must follow the real mind transfer during its channel.")
	TEST_ASSERT(!cast_succeeded, "The old body's heave must cancel when the gullet moves to another body.")
	TEST_ASSERT_EQUAL(keeping.loc, spell.stash, "Changing bodies must preserve the keeping until the new owner deliberately retrieves it.")
	TEST_ASSERT(!spell.gullet_busy, "An interrupted heave must release the busy guard.")
	TEST_ASSERT(spell.PreActivate(replacement), "The new owner must be able to begin a fresh heave after the canceled channel.")
	TEST_ASSERT(replacement.is_holding(keeping), "A fresh successful heave must retrieve the original keeping into the new owner's hand.")

/datum/unit_test/vestige_morph/gullet_reentrant
	var/datum/action/cooldown/spell/vestige_devour/spell
	var/reentrant_result

/datum/unit_test/vestige_morph/gullet_reentrant/proc/reenter_during_heave(mob/living/source)
	SIGNAL_HANDLER
	// One attempted reentry is enough; do not recurse if the guard regresses.
	UnregisterSignal(source, COMSIG_DO_AFTER_BEGAN)
	reentrant_result = spell.before_cast(source)

/datum/unit_test/vestige_morph/gullet_reentrant/Run()
	spell = allocate(/datum/action/cooldown/spell/vestige_devour, user.mind)
	spell.Grant(user)
	var/obj/item/wrench/keeping = allocate(/obj/item/wrench, spell.stash)
	RegisterSignal(user, COMSIG_DO_AFTER_BEGAN, PROC_REF(reenter_during_heave))
	TEST_ASSERT(spell.PreActivate(user), "The first heave must still finish when a second activation is attempted.")
	TEST_ASSERT(reentrant_result & SPELL_CANCEL_CAST, "The channel must reject a second activation before cooldown starts.")
	TEST_ASSERT(user.is_holding(keeping), "The original successful activation must retrieve its keeping exactly once.")
	TEST_ASSERT(!spell.gullet_busy, "Successful completion must release the busy guard.")

/datum/unit_test/vestige_morph/copy_between_ticks/Run()
	var/datum/vestige_trial/perfect_copy/trial = prepare(/datum/vestige_trial/perfect_copy)
	STOP_PROCESSING(SSobj, trial.skin)
	trial.roles = list("tool", "food")
	user.forceMove(get_step(get_step(center, EAST), EAST))
	trial.spawn_actor(get_step(get_step(center, WEST), WEST), "test scavenger")
	TEST_ASSERT(!trial.actor.compare_sentience_type(SENTIENCE_ORGANIC), "An invulnerable scripted projection must reject organic sentience and mind-transfer potions.")
	var/obj/item/wrench/original = allocate(/obj/item/wrench, get_turf(user))
	var/obj/item/storage/backpack/bag = allocate(/obj/item/storage/backpack, get_turf(user))
	trial.skin.wear_object(user, original)
	original.forceMove(bag)
	for(var/index in 1 to 6)
		trial.next_action = 0
		trial.run_scene(user, 0.6)
	TEST_ASSERT(trial.inspection_until > world.time, "A real approach must reach the inspection window.")
	TEST_ASSERT(user.Move(get_step(user, NORTH), NORTH), "The fixture must perform a real visible move before the next scene tick.")
	TEST_ASSERT_EQUAL(trial.skin.form, 0, "Movement between scene ticks must immediately shed the watched object form.")
	TEST_ASSERT(!trial.reveal(user), "Activating immediately after moving must not award the inspection.")
	TEST_ASSERT_EQUAL(trial.role_index, 1, "The moving performance must remain uncredited.")

/datum/unit_test/vestige_morph/gullet_deleted_owner/Run()
	var/datum/action/cooldown/spell/vestige_devour/spell = allocate(/datum/action/cooldown/spell/vestige_devour, user.mind)
	spell.Grant(user)
	var/obj/item/wrench/keeping = allocate(/obj/item/wrench, center)
	user.put_in_hands(keeping)
	TEST_ASSERT(spell.PreActivate(user), "The real swallow channel must finish before deleting the carrier.")
	TEST_ASSERT_EQUAL(keeping.loc, spell.stash, "The real item must be held in the nullspace gullet.")
	qdel(user)
	TEST_ASSERT(!QDELETED(keeping), "Deleting the body directly must preserve swallowed property.")
	TEST_ASSERT_EQUAL(keeping.loc, center, "The deletion callback must spill while the original body still has a turf.")
	qdel(spell)
	TEST_ASSERT(!QDELETED(keeping), "Deleting the now-ownerless action must not destroy the previously swallowed item.")

/datum/unit_test/vestige_morph/predation_pacifism/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, get_step(center, EAST))
	user.set_combat_mode(TRUE)
	user.apply_status_effect(/datum/status_effect/vestige_predation)
	ADD_TRAIT(user, TRAIT_PACIFISM, TRAIT_GENERIC)
	var/initial_health = victim.health
	user.UnarmedAttack(victim, TRUE, list())
	TEST_ASSERT_EQUAL(victim.health, initial_health, "A pacifist's refused real punch must not deliver the ambush rider first.")
	TEST_ASSERT(user.has_status_effect(/datum/status_effect/vestige_predation), "A refused punch must leave the unused ambush window intact.")
	REMOVE_TRAIT(user, TRAIT_PACIFISM, TRAIT_GENERIC)
	TEST_ASSERT(user.can_unarmed_attack() && user.combat_mode, "The second punch must remain an available harm-mode input after pacifism is removed.")
	user.UnarmedAttack(victim, TRUE, list())
	TEST_ASSERT(!user.has_status_effect(/datum/status_effect/vestige_predation), "A permitted strike must spend the ambush window once.")
	TEST_ASSERT(victim.health <= initial_health - 10, "A permitted real unarmed attack must still deliver the ambush rider: health [initial_health] to [victim.health], brute [victim.getBruteLoss()], physiology [victim.physiology.brute_mod]/[victim.physiology.damage_resistance].")

/// Beckon uses a timer instead of a do_after, but must still retain its casting body.
/datum/unit_test/vestige_morph/beckon_transfer/Run()
	var/datum/action/cooldown/spell/pointed/vestige_beckon/spell = allocate(/datum/action/cooldown/spell/pointed/vestige_beckon, user.mind)
	spell.Grant(user)
	spell.windup = 1
	spell.pull_range = 1
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, get_step(center, WEST))
	var/mob/living/carbon/human/consistent/replacement = allocate(/mob/living/carbon/human/consistent, get_step(center, EAST))
	var/turf/victim_start = get_turf(victim)
	spell.cast(victim)
	user.mind.transfer_to(replacement)
	sleep(2)
	TEST_ASSERT_EQUAL(spell.owner, replacement, "The real mind transfer must move the action during its telegraph.")
	TEST_ASSERT(!victim.IsKnockdown(), "The old body's delayed Beckon must not strike after the action changes bodies.")
	TEST_ASSERT_EQUAL(get_turf(victim), victim_start, "A changed caster must not silently redirect the telegraphed pull.")
	spell.cast(victim)
	sleep(2)
	TEST_ASSERT(victim.IsKnockdown(), "A fresh cast from the new body must still resolve its actual timer.")
	sleep(10)
