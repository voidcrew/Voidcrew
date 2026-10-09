/// A physics ragdoll's bones come from the rig's skeleton, every piece of the rig follows them, and
/// joints bend the right way facing either side. With the physics library present, a ragdoll
/// steps, stays in one piece, and hands the body back to its animations after. Serverblight grows
/// on it, holds together, and comes off again cleanly.
/datum/unit_test/limb_physics

/datum/unit_test/limb_physics/Run()
	for(var/species_type in list(/datum/species/experiment, /datum/species/human, /datum/species/lizard))
		var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
		body.set_species(species_type)
		body.update_limb_rig()
		var/datum/limb_rig/sprites/rig = body.limb_rig
		TEST_ASSERT(istype(rig), "[species_type] has no sprite-built rig to simulate.")
		for(var/facing in list(EAST, SOUTH))
			var/list/segments = rig.get_physics_segments(facing)
			TEST_ASSERT_EQUAL(length(segments), 12, "[species_type] facing [dir2text(facing)] has the wrong number of physics segments.")
			var/list/identity = list()
			for(var/part_id in segments)
				var/list/segment = segments[part_id]
				TEST_ASSERT(segment["width"] > 0 && segment["density"] > 0, "[part_id] on [species_type] has no size or weight.")
				if(part_id != "chest")
					TEST_ASSERT(segments[segment["parent"]], "[part_id] on [species_type] hangs off a segment that isn't there.")
				identity[part_id] = matrix()
			// Every piece of the rig gets put somewhere: body, clothes, shoes, held items, the pivot.
			var/list/matrices = rig.get_physics_matrices(identity, facing)
			for(var/part_id in rig.parts)
				TEST_ASSERT(matrices[rig.parts[part_id]], "[species_type]'s [part_id] piece isn't placed by physics.")
			for(var/part_id in rig.cloth_parts)
				TEST_ASSERT(matrices[rig.cloth_parts[part_id]], "[species_type]'s [part_id] clothes aren't placed by physics.")
			for(var/side in list("l", "r"))
				TEST_ASSERT(matrices[rig.shoe_parts[side]] && matrices[rig.item_parts[side]], "[species_type]'s [side] shoe or held item isn't placed by physics.")
			TEST_ASSERT(matrices[rig.pivot], "[species_type]'s torso pivot isn't reset by physics.")

	// Elbows and knees bend one way facing east, and the other facing west.
	var/list/east_elbow = limb_physics_joint_limits("elbow", EAST)
	var/list/west_elbow = limb_physics_joint_limits("elbow", WEST)
	TEST_ASSERT(east_elbow[1] >= 0 && east_elbow[2] > 0, "An elbow facing east bends backwards.")
	TEST_ASSERT(west_elbow[1] < 0 && west_elbow[2] <= 0, "An elbow facing west isn't mirrored.")

	// A point pushed through a turn and back comes out where it started.
	var/matrix/turned = rig_joint_matrix(10, 20, 1, 30, 14, 5)
	var/list/at = rig_apply_matrix(turned, 10, 20)
	TEST_ASSERT(abs(at[1] - 14) < 0.001 && abs(at[2] - 5) < 0.001, "rig_apply_matrix() doesn't put a joint where rig_joint_matrix() moved it.")
	TEST_ASSERT(abs(rig_matrix_angle(turned) + 30) < 0.001, "rig_matrix_angle() doesn't read a turn back.")

	if(!vcphys_available())
		return
	var/mob/living/carbon/human/consistent/ragdoll = allocate(/mob/living/carbon/human/consistent)
	ragdoll.set_species(/datum/species/experiment)
	ragdoll.update_limb_rig()
	TEST_ASSERT(ragdoll.set_limb_physics(TRUE), "A ragdoll couldn't go physical with the library loaded.")
	var/datum/limb_physics/physics = ragdoll.limb_rig.physics
	TEST_ASSERT_EQUAL(length(physics.body_by_part), 12, "The ragdoll is missing bodies.")
	TEST_ASSERT_EQUAL(length(physics.joint_by_part), 11, "The ragdoll is missing joints.")
	physics.push("chest", 30, 5)
	for(var/i in 1 to 20)
		physics.process(0.1)
	TEST_ASSERT(!QDELETED(physics), "The ragdoll's simulation blew up.")
	TEST_ASSERT_EQUAL(physics.steps, 20 * 6, "The ragdoll didn't take a fixed number of steps.")
	ragdoll.set_limb_physics(FALSE)
	TEST_ASSERT_NULL(ragdoll.limb_rig.physics, "Turning physics off left it on.")
	// The torso moves with its pivot in a pose; left where the ragdoll had it, it'd float off on
	// its own. (animate() with no time sets the transform at once.)
	var/matrix/torso = ragdoll.limb_rig.parts["chest"].transform
	TEST_ASSERT(torso.a == 1 && torso.b == 0 && torso.c == 0 && torso.d == 0 && torso.e == 1 && torso.f == 0, "The torso stayed where the ragdoll left it after physics let go.")

	// Serverblight: long arms with six fingers each, a second pair of arms, a hand out of the mouth
	// and two mirrored heads (28 growths, 17 fingertips on 5 hands), shaking itself apart without
	// blowing up, hunting without walking tile to tile, taking someone in, and letting it all go.
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	victim.set_species(/datum/species/experiment)
	victim.update_limb_rig()
	victim.set_limb_physics(TRUE)
	var/datum/limb_physics/blight = victim.limb_rig.physics
	TEST_ASSERT(blight.blight(), "Serverblight couldn't take a physical body.")
	TEST_ASSERT(!blight.blight(), "Serverblight took the same body twice.")
	TEST_ASSERT_EQUAL(length(blight.growths), 28, "Serverblight grew the wrong number of pieces.")
	TEST_ASSERT_EQUAL(length(blight.tips), 17, "Serverblight has the wrong number of fingertips.")
	TEST_ASSERT_EQUAL(length(blight.hands), 5, "Serverblight has the wrong number of hands.")
	TEST_ASSERT(HAS_TRAIT(victim, TRAIT_IMMOBILIZED), "Serverblight's victim can still walk.")
	var/datum/serverblight_chase/chase = new(blight)
	TEST_ASSERT(!QDELETED(chase) && blight.chase == chase, "Serverblight couldn't start hunting.")
	var/obj/effect/abstract/limb_rig_part/growth = blight.growths[1][1]
	for(var/i in 1 to 30)
		blight.process(0.1)
		chase.process(0.1)
	TEST_ASSERT(!QDELETED(blight) && !QDELETED(chase), "Serverblight's simulation blew up.")
	// Killed, it lies slack; brought back, it's whole again.
	victim.death()
	chase.process(0.1)
	TEST_ASSERT(blight.dormant, "Serverblight kept going after it died.")
	chase.rise()
	TEST_ASSERT(victim.stat != DEAD, "Serverblight didn't get back up.")
	TEST_ASSERT(!blight.dormant && blight.blighted && length(blight.growths) == 28, "Serverblight got back up without its body.")
	var/mob/living/carbon/human/consistent/prey = allocate(/mob/living/carbon/human/consistent)
	prey.set_species(/datum/species/human)
	prey.update_limb_rig()
	// Slower for every hand on them, and back to normal when they're let go.
	chase.hold(prey, 2)
	var/datum/movespeed_modifier/grip = prey.has_movespeed_modifier(/datum/movespeed_modifier/serverblight_grip)
	TEST_ASSERT(grip?.multiplicative_slowdown > 0, "Serverblight's hands don't slow anyone down.")
	chase.hold(prey, 4)
	TEST_ASSERT(grip.multiplicative_slowdown > 2 * 0.8 * 0.99, "More of Serverblight's hands don't slow anyone down more.")
	chase.hold(prey, 100)
	TEST_ASSERT(grip.multiplicative_slowdown <= 6, "Serverblight's hands slow people down without limit.")
	chase.hold(null, 0)
	TEST_ASSERT(!prey.has_movespeed_modifier(/datum/movespeed_modifier/serverblight_grip), "Serverblight's hands didn't let go.")
	var/health_before = victim.maxHealth
	chase.absorb(prey)
	TEST_ASSERT_EQUAL(victim.maxHealth, health_before + 100, "Taking someone in didn't make Serverblight tougher.")
	chase.update_hitboxes()
	TEST_ASSERT_EQUAL(length(chase.hitboxes), 2, "Taking someone in didn't make Serverblight bigger to hit.")
	var/obj/effect/serverblight_hitbox/hitbox = chase.hitboxes[1]
	TEST_ASSERT_EQUAL(prey.loc, victim, "Serverblight didn't take its prey in.")
	// Their body (12), their forearms two more hands.
	TEST_ASSERT_EQUAL(length(blight.growths), 28 + 12, "Serverblight didn't grow its prey's body on.")
	TEST_ASSERT_EQUAL(length(blight.hands), 5 + 2, "Serverblight didn't get more hands from its prey.")
	TEST_ASSERT(length(blight.glued), "Serverblight didn't glue its prey into itself.")
	for(var/i in 1 to 10)
		blight.process(0.1)
		chase.process(0.1)
	TEST_ASSERT(!QDELETED(blight), "Serverblight blew up with someone grown on.")
	victim.set_limb_physics(FALSE)
	TEST_ASSERT(QDELETED(chase), "Serverblight kept hunting after physics let go.")
	TEST_ASSERT(QDELETED(hitbox), "Serverblight's hitboxes stayed after physics let go.")
	TEST_ASSERT_EQUAL(victim.maxHealth, health_before, "Serverblight's victim kept its extra health after physics let go.")
	TEST_ASSERT(isturf(prey.loc), "Serverblight kept its prey after physics let go.")
	TEST_ASSERT(!HAS_TRAIT(victim, TRAIT_IMMOBILIZED) && !HAS_TRAIT(prey, TRAIT_IMMOBILIZED), "Serverblight's victims stayed held after physics let go.")
	TEST_ASSERT(!(growth in victim.vis_contents), "Serverblight's growths stayed on after physics let go.")
	TEST_ASSERT(victim.set_dir_on_move, "Serverblight's victim can't turn to walk any more.")
