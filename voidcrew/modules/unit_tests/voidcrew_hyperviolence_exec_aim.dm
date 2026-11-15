/**
 * A gun execution's aimed pose (voidcrew/modules/hyperviolence/visuals/execution_aim.dm).
 *
 * A headless world draws nothing, so these check what the server keeps: where the pose puts the barrel's end against
 * where the victim's head is drawn, from every side and for both ways a body lies, and that nothing of the pose is
 * left on the shooter or the floor however the execution ends.
 */

/// Shared helpers; not a test itself
/datum/unit_test/voidcrew_hv_exec_aim
	abstract_type = /datum/unit_test/voidcrew_hv_exec_aim

/// The floor `dx`, `dy` tiles from the test room's bottom-left corner
/datum/unit_test/voidcrew_hv_exec_aim/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// A shooter in the middle of the room with a pistol in hand, aiming at the head
/datum/unit_test/voidcrew_hv_exec_aim/proc/make_shooter()
	var/mob/living/carbon/human/consistent/shooter = allocate(/mob/living/carbon/human/consistent, spot(2, 2))
	var/obj/item/gun/ballistic/automatic/pistol/gun = allocate(/obj/item/gun/ballistic/automatic/pistol)
	gun.can_misfire = FALSE
	shooter.put_in_active_hand(gun, forced = TRUE)
	shooter.zone_selected = BODY_ZONE_HEAD
	return shooter

/// A body on the floor `way` of the middle of the room, lying at `angle` (90: head to the east, 270: to the west)
/datum/unit_test/voidcrew_hv_exec_aim/proc/make_victim(way, angle)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, get_step(spot(2, 2), way))
	ADD_TRAIT(victim, TRAIT_PIERCEIMMUNE, INNATE_TRAIT) // no stray shrapnel
	ADD_TRAIT(victim, TRAIT_DESIGNATED_TARGET, TRAIT_SOURCE_UNIT_TESTS) // tg's zone roll never sends the round off the head
	victim.Knockdown(60 SECONDS)
	victim.set_lying_angle(angle)
	TEST_ASSERT_EQUAL(victim.body_position, LYING_DOWN, "Test fixture: the victim isn't on the floor")
	return victim

/// The rig's pictures standing anywhere near the middle of the room
/datum/unit_test/voidcrew_hv_exec_aim/proc/pictures_up()
	. = 0
	for(var/obj/effect/abstract/chrome_puppet/picture in range(2, spot(2, 2)))
		. += !QDELETED(picture)

/// Fails if anything of the pose is left on `shooter`, their `gun` or the floor
/datum/unit_test/voidcrew_hv_exec_aim/proc/check_nothing_left(mob/living/carbon/human/shooter, obj/item/gun/gun, how)
	TEST_ASSERT_EQUAL(pictures_up(), 0, "Pictures of the aimed pose are still standing after the execution [how]")
	if(!QDELETED(gun))
		TEST_ASSERT_NULL(gun.hv_aim, "The gun still has its aimed pose after the execution [how]")
		TEST_ASSERT(!gun.hv_aim_out_of_hand, "The gun is still left out of its holder's hand after the execution [how]")
	if(QDELETED(shooter))
		return
	TEST_ASSERT(!shooter.filter_data?["chrome_rig_hide"], "The shooter is still hidden after the execution [how]")
	TEST_ASSERT_EQUAL(shooter.mouse_opacity, initial(shooter.mouse_opacity), "The shooter's click area was not put back after the execution [how]")
	TEST_ASSERT_EQUAL(shooter.pixel_w, 0, "The shooter is left [shooter.pixel_w] pixels aside after the execution [how]")
	TEST_ASSERT_EQUAL(shooter.pixel_z, 0, "The shooter is left [shooter.pixel_z] pixels up after the execution [how]")
	if(shooter.body_position == STANDING_UP) // on the floor tg has turned him itself
		var/matrix/turned = shooter.transform
		TEST_ASSERT(abs(turned.a - 1) < 0.001 && abs(turned.b) < 0.001 && abs(turned.c) < 0.001 && abs(turned.f) < 0.001, "The shooter is left turned or moved after the execution [how]")
	if(QDELETED(gun) || !shooter.is_holding(gun))
		return
	var/list/hands = shooter.overlays_standing[HANDS_LAYER]
	if(hands && !islist(hands))
		hands = list(hands)
	TEST_ASSERT(length(hands), "The shooter's held gun isn't drawn after the execution [how]")
	for(var/mutable_appearance/held as anything in hands)
		TEST_ASSERT(held.alpha, "The gun in the shooter's hand is still drawn as nothing after the execution [how]")

/**
 * From each side, and for a body lying each way, the aimed pose ends the barrel on the head as it is drawn, pointing at
 * it: never at the other end of the body. The gun's picture really is posed there, and the shooter's own look keeps
 * its gun.
 */
/datum/unit_test/voidcrew_hv_exec_aim/on_the_head

/datum/unit_test/voidcrew_hv_exec_aim/on_the_head/Run()
	var/mob/living/carbon/human/shooter = make_shooter()
	var/obj/item/gun/gun = shooter.get_active_held_item()
	for(var/way in GLOB.cardinals)
		for(var/angle in list(90, 270))
			var/mob/living/carbon/human/victim = make_victim(way, angle)
			var/what = "from the [dir2text(REVERSE_DIR(way))] of a body lying [angle == 90 ? "head-east" : "head-west"]"
			shooter.face_atom(victim)
			var/datum/hv_exec_aim/aim = new(gun, shooter, victim)
			TEST_ASSERT(aim.raise(), "The shooter couldn't be drawn aiming [what]")
			// Where the head is drawn, from the middle of the shooter's tile
			var/list/head_at = victim.hv_vis_head_offset()
			var/head_x = (victim.x - shooter.x) * ICON_SIZE_X + head_at[1]
			var/head_y = (victim.y - shooter.y) * ICON_SIZE_Y + head_at[2]
			TEST_ASSERT_EQUAL(head_at[1], angle == 90 ? 9 : -9, "Test fixture: the head isn't drawn at the end the body lies toward")
			var/off_x = head_x - aim.muzzle[1]
			var/off_y = head_y - aim.muzzle[2]
			var/off = sqrt(off_x * off_x + off_y * off_y)
			// On the skull: HV_AIM_GAP (4) short of its middle, a little more where the arm is at its longest
			TEST_ASSERT(off >= 2.5 && off <= 6.5, "The barrel ends [off] pixels from the middle of the head [what]: [aim.muzzle[1]],[aim.muzzle[2]] against [head_x],[head_y]")
			// The other end of the body: its boots
			var/boots_x = (victim.x - shooter.x) * ICON_SIZE_X - head_at[1] * 1.5
			TEST_ASSERT(abs(aim.muzzle[1] - boots_x) > 12, "The barrel ends at the boots [what]")
			TEST_ASSERT((off_x * aim.aim_x + off_y * aim.aim_y) / off > 0.95, "The barrel doesn't point at the head [what]")
			// The gun's picture is posed with its barrel's end there
			var/obj/effect/abstract/chrome_puppet/gun_picture = aim.rig.puppet("gun")
			TEST_ASSERT_NOTNULL(gun_picture, "No picture of the gun stands [what]")
			var/list/drawn_end = chrome_rig_apply(gun_picture.transform, aim.shape[3], aim.shape[4])
			TEST_ASSERT(abs(drawn_end[1] - aim.muzzle[1]) < 0.5 && abs(drawn_end[2] - aim.muzzle[2]) < 0.5, "The gun's picture ends at [drawn_end[1]],[drawn_end[2]], not on the head, [what]")
			// He leans toward the victim, never away
			var/obj/effect/abstract/chrome_puppet/body_picture = aim.rig.puppet("body")
			var/matrix/leaned = body_picture.transform
			var/list/middle = chrome_rig_apply(leaned, 0, 0)
			TEST_ASSERT(middle[1] * (victim.x - shooter.x) + middle[2] * (victim.y - shooter.y) > 0, "The shooter doesn't lean toward the victim [what]")
			TEST_ASSERT(shooter.filter_data?["chrome_rig_hide"], "The real body shows under its aimed pose [what]")
			TEST_ASSERT(!gun.hv_aim_out_of_hand, "The gun stays out of the shooter's own look during the hold [what]")
			qdel(aim)
			check_nothing_left(shooter, gun, "was dropped [what]")
			qdel(victim)

/// However an execution ends, nothing of the aimed pose is left: fired, called off, the shooter moved or knocked down,
/// the gun dropped, the victim or the shooter deleted.
/datum/unit_test/voidcrew_hv_exec_aim/nothing_left

/datum/unit_test/voidcrew_hv_exec_aim/nothing_left/Run()
	for(var/ending in list("fired", "called off", "the shooter moved", "the shooter fell", "the gun dropped", "the victim deleted", "the shooter deleted"))
		var/mob/living/carbon/human/shooter = make_shooter()
		var/obj/item/gun/gun = shooter.get_active_held_item()
		// Head-east, the shooter to the west: the head is at the far end
		var/mob/living/carbon/human/victim = make_victim(EAST, 90)
		INVOKE_ASYNC(gun, TYPE_PROC_REF(/obj/item/gun, hv_start_execution), shooter, victim, null)
		sleep(0.5 SECONDS)
		TEST_ASSERT(gun.hv_aim?.is_up(), "No aimed pose during the hold (ending: [ending])")
		TEST_ASSERT(pictures_up() >= 3, "The aimed pose has [pictures_up()] pictures up, not its three (ending: [ending])")
		switch(ending)
			if("fired")
				sleep(1.1 SECONDS) // the 1.5 s hold is over: the shot
				TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_HEAD), "Test fixture: the execution didn't burst the head")
				TEST_ASSERT(gun.hv_aim?.is_up(), "The aimed pose went on the shot's own tick, before its recoil")
				sleep(1 SECONDS)
			if("called off")
				shooter.zone_selected = BODY_ZONE_CHEST
				sleep(0.6 SECONDS)
			if("the shooter moved")
				shooter.forceMove(spot(2, 3))
				sleep(world.tick_lag * 2)
			if("the shooter fell")
				shooter.Knockdown(5 SECONDS)
				sleep(world.tick_lag * 2)
			if("the gun dropped")
				shooter.dropItemToGround(gun, force = TRUE)
				sleep(world.tick_lag * 2)
			if("the victim deleted")
				qdel(victim)
				sleep(0.6 SECONDS)
			if("the shooter deleted")
				qdel(shooter)
				sleep(world.tick_lag * 2)
		check_nothing_left(shooter, gun, "ended with [ending]")
		// Past the wind-up, whatever it was: nothing comes back
		sleep(1.2 SECONDS)
		check_nothing_left(shooter, gun, "ended with [ending], a moment later")
		if(!QDELETED(victim))
			qdel(victim)
		if(!QDELETED(gun))
			qdel(gun)
		if(!QDELETED(shooter))
			qdel(shooter)

/**
 * The shot's flash is at the end of the barrel as the aimed pose draws it, from every side, and the flashes tg and gun
 * feel draw at the hip are not made for it. The next shot has its own again.
 */
/datum/unit_test/voidcrew_hv_exec_aim/flash_at_the_barrel

/datum/unit_test/voidcrew_hv_exec_aim/flash_at_the_barrel/Run()
	for(var/way in GLOB.cardinals)
		var/mob/living/carbon/human/shooter = make_shooter()
		var/obj/item/gun/gun = shooter.get_active_held_item()
		var/mob/living/carbon/human/victim = make_victim(way, 90)
		var/turf/victim_turf = get_turf(victim)
		var/what = "from the [dir2text(REVERSE_DIR(way))]"
		INVOKE_ASYNC(gun, TYPE_PROC_REF(/obj/item/gun, hv_start_execution), shooter, victim, null)
		sleep(1.4 SECONDS)
		var/datum/hv_exec_aim/aim = gun.hv_aim
		TEST_ASSERT(aim?.is_up(), "No aimed pose at the end of the hold [what]")
		var/list/barrel_end = aim.muzzle_from(victim_turf)
		var/list/head_at = victim.hv_vis_head_offset()
		// The 1.5 s hold ends: the shot. Its flash lasts 0.4 s.
		var/obj/effect/temp_visual/hv_muzzle_flash/flash
		var/until = world.time + 0.5 SECONDS
		while(!flash && world.time < until)
			sleep(world.tick_lag)
			flash = locate() in victim_turf
		TEST_ASSERT_NOTNULL(flash, "The execution made no flash [what]")
		// The flash art's bright end is HV_VIS_FLASH_CORE (9) pixels off its middle, the way it faces
		var/core_x = flash.pixel_w + ((flash.dir & EAST) ? 9 : ((flash.dir & WEST) ? -9 : 0))
		var/core_y = flash.pixel_z + ((flash.dir & NORTH) ? 9 : ((flash.dir & SOUTH) ? -9 : 0))
		TEST_ASSERT(abs(core_x - barrel_end[1]) <= 1 && abs(core_y - barrel_end[2]) <= 1, "The flash is at [core_x],[core_y], the barrel's end at [barrel_end[1]],[barrel_end[2]], [what]")
		var/to_head = sqrt((core_x - head_at[1]) ** 2 + (core_y - head_at[2]) ** 2)
		TEST_ASSERT(to_head <= 7.5, "The flash is [to_head] pixels from the head [what]")
		TEST_ASSERT_NULL(locate(/obj/effect/temp_visual/gun_feel_muzzle_flash) in shooter, "The execution made gun feel's flash at the hip [what]")
		TEST_ASSERT_NULL(locate(/obj/effect/temp_visual/dir_setting/firing_effect) in shooter, "The execution made tg's flash at the hip [what]")
		TEST_ASSERT(!gun.hv_firing_execution, "The gun still counts as firing an execution round [what]")
		sleep(1 SECONDS)
		check_nothing_left(shooter, gun, "fired [what]")
		// A plain shot after it has its flash at the hip as ever
		var/obj/item/ammo_casing/next_round = gun.chambered
		TEST_ASSERT_NOTNULL(next_round, "Test fixture: no round chambered after the execution")
		TEST_ASSERT_EQUAL(next_round.firing_effect_type, initial(next_round.firing_effect_type), "The next round lost its flash [what]")
		qdel(victim)
		qdel(gun)
		qdel(shooter)

/// A cuffed victim on his feet, held off the middle of his tile as a grab holds him: the barrel is on the head where it
/// is drawn. He lies down during the hold: the barrel follows the head to the floor.
/datum/unit_test/voidcrew_hv_exec_aim/follows_the_head

/datum/unit_test/voidcrew_hv_exec_aim/follows_the_head/Run()
	var/mob/living/carbon/human/shooter = make_shooter()
	var/obj/item/gun/gun = shooter.get_active_held_item()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, get_step(spot(2, 2), EAST))
	ADD_TRAIT(victim, TRAIT_RESTRAINED, TRAIT_SOURCE_UNIT_TESTS)
	victim.add_offsets(TRAIT_SOURCE_UNIT_TESTS, x_add = -12, animate = FALSE) // an aggressive grab's
	var/datum/hv_exec_aim/aim = new(gun, shooter, victim)
	TEST_ASSERT(aim.raise(), "The shooter couldn't be drawn aiming at a victim on his feet")
	gun.hv_aim = aim
	var/list/head_at = victim.hv_vis_head_offset()
	TEST_ASSERT_EQUAL(head_at[1], -12, "A head held off the middle of its tile isn't found where it is drawn")
	var/off = sqrt((ICON_SIZE_X + head_at[1] - aim.muzzle[1]) ** 2 + (head_at[2] - aim.muzzle[2]) ** 2)
	TEST_ASSERT(off <= 6.5, "The barrel ends [off] pixels from the head of a victim on his feet")
	victim.remove_offsets(TRAIT_SOURCE_UNIT_TESTS, animate = FALSE)
	victim.Knockdown(60 SECONDS)
	victim.set_lying_angle(90)
	sleep(world.tick_lag * 4)
	TEST_ASSERT(aim.is_up(), "The aimed pose went when the victim lay down")
	head_at = victim.hv_vis_head_offset()
	TEST_ASSERT_EQUAL(head_at[1], 9, "Test fixture: the victim's head isn't at the far end")
	off = sqrt((ICON_SIZE_X + head_at[1] - aim.muzzle[1]) ** 2 + (head_at[2] - aim.muzzle[2]) ** 2)
	TEST_ASSERT(off <= 6.5, "The barrel stayed [off] pixels from the head after the victim lay down")
	TEST_ASSERT_EQUAL(pictures_up(), 3, "The aimed pose has [pictures_up()] pictures up after following the head, not three")
	qdel(aim)
	check_nothing_left(shooter, gun, "followed the head down")
