/**
 * Deadeye optics on a bounty fighter (voidcrew/modules/bounties/chrome/bounty_chrome_deadeye.dm).
 * Every test drives the piece's procs directly with the AI off; nothing is fired for real. Fork
 * defines are included after the tests, so a test uses the literal value with a comment naming the
 * define. The test room is a 5x5 floor.
 */
/datum/unit_test/voidcrew_bounty_chrome_deadeye
	abstract_type = /datum/unit_test/voidcrew_bounty_chrome_deadeye

/// The floor tile `dx`, `dy` from the room's bottom left
/datum/unit_test/voidcrew_bounty_chrome_deadeye/proc/tile(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// A normal criminal of `style` and `species` carrying Deadeye optics, at `where`, with the AI off
/datum/unit_test/voidcrew_bounty_chrome_deadeye/proc/new_gunman(style = "pistol", species = /datum/species/human, turf/where)
	var/datum/bounty_record/record = new
	record.archetype = "normal" // BOUNTY_ARCHETYPE_NORMAL
	record.tier = 1 // BOUNTY_TIER_PETTY
	record.style = style
	record.species = species
	record.gender = MALE
	record.name = "Test Gunman"
	record.look = bounty_roll_look(species, MALE)
	record.chrome = list("deadeye") // BOUNTY_CHROME_DEADEYE
	var/mob/living/basic/bounty_criminal/criminal = spawn_bounty_criminal(record, where || tile(0, 0), null)
	LAZYADD(allocated, criminal)
	criminal.ai_controller?.set_ai_status(AI_STATUS_OFF)
	criminal.ai_update_style()
	return criminal

/// Puts `criminal` in a fight with `hunter`, as the AI would
/datum/unit_test/voidcrew_bounty_chrome_deadeye/proc/fight(mob/living/basic/bounty_criminal/criminal, mob/living/hunter)
	criminal.ai_add_grudge(hunter)
	criminal.ai_set_mode("fighting") // BOUNTY_AI_FIGHTING
	criminal.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, hunter)

/// The icon state of the red eyes `fighter` shows (an eye sprite filled red by a colour matrix), or null
/datum/unit_test/voidcrew_bounty_chrome_deadeye/proc/red_eyes(mob/living/basic/fighter)
	for(var/mutable_appearance/overlay as anything in fighter.update_overlays())
		if(istype(overlay) && overlay.icon == 'icons/mob/human/human_face.dmi' && islist(overlay.color))
			return overlay.icon_state
	return null

/// Who rolls it: gunmen and their gun-carrying companions, from Petty up; never a melee style, the meek or a mini-boss
/datum/unit_test/voidcrew_bounty_chrome_deadeye/rolls

/datum/unit_test/voidcrew_bounty_chrome_deadeye/rolls/Run()
	var/datum/bounty_chrome/proto = GLOB.bounty_chrome_protos["deadeye"] // BOUNTY_CHROME_DEADEYE
	TEST_ASSERT_NOTNULL(proto, "No Deadeye optics prototype")
	TEST_ASSERT(proto.weight > 0, "Deadeye optics never roll")
	for(var/style in list("pistol", "smg", "revolver", "shotgun"))
		TEST_ASSERT(proto.can_roll(1, "normal", style, null, list()), "A Petty [style] criminal can't roll Deadeye optics") // BOUNTY_TIER_PETTY
		TEST_ASSERT(proto.can_roll(2, "companion", style, null, list()), "A [style] companion can't roll Deadeye optics") // BOUNTY_CHROME_COMPANION
	for(var/style in list("brawler", "knife", "club", "bottle"))
		TEST_ASSERT(!proto.can_roll(3, "normal", style, null, list()), "A [style] criminal rolled Deadeye optics")
		TEST_ASSERT(!proto.can_roll(3, "companion", style, null, list()), "A [style] companion rolled Deadeye optics")
	TEST_ASSERT(!proto.can_roll(3, "meek", "holdout", null, list()), "A meek criminal rolled Deadeye optics")
	for(var/kit in list("juggernaut", "heavy", "pyromaniac", "demolitionist", "ghost"))
		TEST_ASSERT(!proto.can_roll(3, "boss", null, kit, list()), "A [kit] mini-boss rolled Deadeye optics")
	// No organ in the look: their own eyes stay as their record has them
	TEST_ASSERT(!length(bounty_chrome_organ_looks(list("deadeye"))), "Deadeye optics change the look's eyes")
	for(var/i in 1 to 30)
		TEST_ASSERT(!("deadeye" in bounty_roll_chrome(3, "normal", "knife", null)), "A knife criminal rolled Deadeye optics")

/// The lock: it starts in a fight, holds their fire for the beat, and homes the next three rounds at the mark
/datum/unit_test/voidcrew_bounty_chrome_deadeye/lock

/datum/unit_test/voidcrew_bounty_chrome_deadeye/lock/Run()
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, tile(3, 0))
	var/mob/living/carbon/human/consistent/bystander = allocate(/mob/living/carbon/human/consistent, tile(3, 3))
	var/mob/living/basic/bounty_criminal/criminal = new_gunman("pistol")
	var/datum/bounty_chrome/deadeye/piece = bounty_chrome_piece(criminal, "deadeye")
	TEST_ASSERT_NOTNULL(piece, "A record with Deadeye optics spawned without them")
	TEST_ASSERT(!red_eyes(criminal), "Their eyes are red before any lock")
	var/list/examined = criminal.examine(hunter)
	var/found = FALSE
	for(var/line in examined)
		if(findtext(line, "milspec optics"))
			found = TRUE
	TEST_ASSERT(found, "Examining them doesn't show their optics")

	// Not in a fight, no lock
	piece.on_tick(2, FALSE)
	TEST_ASSERT_NULL(piece.mark_ref, "They locked on outside a fight")
	fight(criminal, hunter)
	TEST_ASSERT(bounty_chrome_fighting(criminal), "The test fight isn't on")
	piece.on_fight_start(hunter)
	piece.on_tick(2, TRUE)
	TEST_ASSERT_NULL(piece.mark_ref, "They locked on the moment the fight started")
	piece.next_lock_at = world.time
	piece.on_tick(2, TRUE)
	TEST_ASSERT_EQUAL(piece.mark_ref?.resolve(), hunter, "They didn't lock onto who they were fighting")
	TEST_ASSERT_NOTNULL(hunter.get_filter(piece.mark_filter), "The mark isn't on the hunter")
	TEST_ASSERT_EQUAL(red_eyes(criminal), "eyes_l", "Their eyes didn't turn red")
	var/datum/component/ranged_attacks/gun = criminal.GetComponent(/datum/component/ranged_attacks)
	TEST_ASSERT(gun.fire_cooldown >= piece.armed_at, "They didn't hold their fire for the lock's beat")

	// During the beat a round flies as aimed
	var/obj/projectile/bullet/bounty/early = allocate(/obj/projectile/bullet/bounty, tile(0, 0))
	piece.on_fire(early, hunter)
	TEST_ASSERT_NULL(early.homing_target, "A round fired during the lock's beat homed")

	// Then the next three rounds at the mark home; one at someone else doesn't, and doesn't count
	piece.armed_at = world.time
	var/obj/projectile/bullet/bounty/first = allocate(/obj/projectile/bullet/bounty, tile(0, 0))
	piece.on_fire(first, hunter)
	TEST_ASSERT_EQUAL(first.homing_target, hunter, "A round after the beat didn't home")
	TEST_ASSERT_EQUAL(piece.shots_left, 2, "A homing round didn't count")
	var/obj/projectile/bullet/bounty/stray = allocate(/obj/projectile/bullet/bounty, tile(0, 0))
	piece.on_fire(stray, bystander)
	TEST_ASSERT_NULL(stray.homing_target, "A round at someone else homed")
	TEST_ASSERT_EQUAL(piece.shots_left, 2, "A round at someone else counted")
	// A pistol's second round the same moment is a round of its own (only a shell's pellets go together)
	var/obj/projectile/bullet/bounty/second = allocate(/obj/projectile/bullet/bounty, tile(0, 0))
	piece.on_fire(second, hunter)
	TEST_ASSERT_EQUAL(piece.shots_left, 1, "A pistol round fired the same moment as the last didn't count")
	var/obj/projectile/bullet/bounty/third = allocate(/obj/projectile/bullet/bounty, tile(0, 0))
	piece.on_fire(third, hunter)
	TEST_ASSERT_EQUAL(third.homing_target, hunter, "The third round didn't home")
	TEST_ASSERT_NULL(piece.mark_ref, "The lock outlasted its rounds")
	TEST_ASSERT_NULL(hunter.get_filter(piece.mark_filter), "The mark stayed on after the lock's rounds")
	TEST_ASSERT(!red_eyes(criminal), "Their eyes stayed red after the lock")
	TEST_ASSERT(piece.next_lock_at > world.time, "No pause before the next lock")
	var/obj/projectile/bullet/bounty/fourth = allocate(/obj/projectile/bullet/bounty, tile(0, 0))
	piece.last_round_at = -1
	piece.on_fire(fourth, hunter)
	TEST_ASSERT_NULL(fourth.homing_target, "A fourth round homed")

	// A round in the air keeps steering while it sees its mark, and flies straight once a wall is between them
	var/turf/between = tile(2, 0)
	var/floor_type = between.type
	first.forceMove(tile(1, 0))
	piece.on_round_step(first)
	TEST_ASSERT_EQUAL(first.homing_target, hunter, "A round in plain view of its mark stopped homing")
	between.ChangeTurf(/turf/closed/wall)
	piece.on_round_step(first)
	TEST_ASSERT_NULL(first.homing_target, "A round kept homing on a mark behind a wall")

	// No lock through a wall, and a held lock drops when a wall comes between them
	piece.next_lock_at = world.time
	piece.on_tick(2, TRUE)
	TEST_ASSERT_NULL(piece.mark_ref, "They locked onto someone behind a wall")
	tile(2, 0).ChangeTurf(floor_type)
	piece.on_tick(2, TRUE)
	TEST_ASSERT_NOTNULL(piece.mark_ref, "They didn't lock on again")
	tile(2, 0).ChangeTurf(/turf/closed/wall)
	piece.watch_lock()
	TEST_ASSERT_NULL(piece.mark_ref, "The lock held with a wall between them")
	TEST_ASSERT_NULL(hunter.get_filter(piece.mark_filter), "The mark stayed on after they lost sight")
	tile(2, 0).ChangeTurf(floor_type)

	// Turning on someone else drops it
	piece.next_lock_at = world.time
	piece.on_tick(2, TRUE)
	TEST_ASSERT_NOTNULL(piece.mark_ref, "They didn't lock on a third time")
	criminal.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, bystander)
	piece.watch_lock()
	TEST_ASSERT_NULL(piece.mark_ref, "The lock stayed on the hunter after they turned on someone else")
	criminal.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, hunter)

	// A downed mark is let go
	piece.next_lock_at = world.time
	piece.on_tick(2, TRUE)
	TEST_ASSERT_NOTNULL(piece.mark_ref, "They didn't lock on a fourth time")
	hunter.Unconscious(10 SECONDS)
	piece.watch_lock()
	TEST_ASSERT_NULL(piece.mark_ref, "The lock held on a hunter who was down")
	hunter.SetUnconscious(0)

	// Out of the fight it ends
	piece.next_lock_at = world.time
	piece.on_tick(2, TRUE)
	TEST_ASSERT_NOTNULL(piece.mark_ref, "They didn't lock on with the hunter back up")
	criminal.ai_set_mode("calm") // BOUNTY_AI_CALM
	piece.on_tick(2, FALSE)
	TEST_ASSERT_NULL(piece.mark_ref, "The lock outlasted the fight")

/// A shotgun shell is one round: all its pellets home, and it counts once
/datum/unit_test/voidcrew_bounty_chrome_deadeye/shotgun

/datum/unit_test/voidcrew_bounty_chrome_deadeye/shotgun/Run()
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, tile(3, 0))
	var/mob/living/basic/bounty_criminal/criminal = new_gunman("shotgun")
	var/datum/bounty_chrome/deadeye/piece = bounty_chrome_piece(criminal, "deadeye")
	TEST_ASSERT(bounty_ai_real_weapon(criminal)?.pellets > 1, "The test shotgun fires no pellets")
	fight(criminal, hunter)
	piece.next_lock_at = world.time
	piece.on_tick(2, TRUE)
	TEST_ASSERT_NOTNULL(piece.mark_ref, "The shotgunner didn't lock on")
	piece.armed_at = world.time
	var/list/pellets = list()
	for(var/i in 1 to 6)
		var/obj/projectile/bullet/bounty/pellet = allocate(/obj/projectile/bullet/bounty, tile(0, 0))
		pellets += pellet
		piece.on_fire(pellet, hunter)
	for(var/obj/projectile/bullet/bounty/pellet as anything in pellets)
		TEST_ASSERT_EQUAL(pellet.homing_target, hunter, "A pellet of a homing shell flew as aimed")
	TEST_ASSERT_EQUAL(piece.shots_left, 2, "A shell's pellets counted as more than one round")

/// An EMP drops the lock, straightens the rounds in the air, and keeps them from locking while the optics are down
/datum/unit_test/voidcrew_bounty_chrome_deadeye/emp

/datum/unit_test/voidcrew_bounty_chrome_deadeye/emp/Run()
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, tile(3, 0))
	var/mob/living/basic/bounty_criminal/criminal = new_gunman("smg")
	var/datum/bounty_chrome/deadeye/piece = bounty_chrome_piece(criminal, "deadeye")
	fight(criminal, hunter)
	piece.next_lock_at = world.time
	piece.on_tick(2, TRUE)
	TEST_ASSERT_NOTNULL(piece.mark_ref, "The SMG criminal didn't lock on")
	piece.armed_at = world.time
	var/obj/projectile/bullet/bounty/flying = allocate(/obj/projectile/bullet/bounty, tile(1, 0))
	piece.on_fire(flying, hunter)
	TEST_ASSERT_EQUAL(flying.homing_target, hunter, "The SMG round didn't home")
	criminal.emp_act(EMP_HEAVY)
	TEST_ASSERT(!piece.online(), "Their optics work through an EMP")
	TEST_ASSERT_NULL(piece.mark_ref, "An EMP didn't drop the lock")
	TEST_ASSERT_NULL(hunter.get_filter(piece.mark_filter), "An EMP left the mark on the hunter")
	TEST_ASSERT_NULL(flying.homing_target, "An EMP didn't straighten a round in the air")
	TEST_ASSERT(!red_eyes(criminal), "Their eyes stayed red through an EMP")
	piece.next_lock_at = world.time
	piece.on_tick(2, TRUE)
	TEST_ASSERT_NULL(piece.mark_ref, "They locked on with their optics down")
	piece.offline_until = world.time
	var/datum/component/bounty_chrome/chrome = criminal.GetComponent(/datum/component/bounty_chrome)
	chrome.tick(2)
	TEST_ASSERT(piece.online(), "Their optics never came back")
	TEST_ASSERT_EQUAL(piece.mark_ref?.resolve(), hunter, "Back up, they didn't lock on again")

/// Death and deletion take the mark off the hunter
/datum/unit_test/voidcrew_bounty_chrome_deadeye/cleanup

/datum/unit_test/voidcrew_bounty_chrome_deadeye/cleanup/Run()
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, tile(3, 0))
	var/mob/living/basic/bounty_criminal/criminal = new_gunman("revolver")
	var/datum/bounty_chrome/deadeye/piece = bounty_chrome_piece(criminal, "deadeye")
	fight(criminal, hunter)
	piece.next_lock_at = world.time
	piece.on_tick(2, TRUE)
	TEST_ASSERT_NOTNULL(piece.mark_ref, "The revolver criminal didn't lock on")
	criminal.death()
	TEST_ASSERT_NULL(piece.mark_ref, "The lock outlived them")
	TEST_ASSERT_NULL(hunter.get_filter(piece.mark_filter), "Their mark outlived them")

	var/mob/living/basic/bounty_criminal/doomed = new_gunman("pistol", /datum/species/human, tile(0, 2))
	var/datum/bounty_chrome/deadeye/doomed_piece = bounty_chrome_piece(doomed, "deadeye")
	fight(doomed, hunter)
	doomed_piece.next_lock_at = world.time
	doomed_piece.on_tick(2, TRUE)
	var/filter_name = doomed_piece.mark_filter
	TEST_ASSERT_NOTNULL(hunter.get_filter(filter_name), "The second criminal didn't mark the hunter")
	qdel(doomed)
	TEST_ASSERT_NULL(hunter.get_filter(filter_name), "Deleting them left their mark on the hunter")
	TEST_ASSERT_NULL(doomed_piece.owner, "Their optics kept their owner after they were deleted")

/// A companion with a gun locks on the same way, and its red eyes are its own species' eyes
/datum/unit_test/voidcrew_bounty_chrome_deadeye/companion

/datum/unit_test/voidcrew_bounty_chrome_deadeye/companion/Run()
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, tile(4, 2))
	var/mob/living/basic/bounty_criminal/criminal = new_gunman("pistol", /datum/species/human, tile(1, 2))
	var/list/buddies = criminal.spawn_companions(1)
	TEST_ASSERT(length(buddies), "No companion spawned")
	var/mob/living/basic/bounty_companion/buddy = buddies[1]
	buddy.ai_controller?.set_ai_status(AI_STATUS_OFF)
	buddy.ai_take_style("revolver") // BOUNTY_STYLE_REVOLVER
	buddy.eva_look = bounty_roll_look(/datum/species/moth, MALE)
	bounty_chrome_install(buddy, list("deadeye"))
	var/datum/bounty_chrome/deadeye/piece = bounty_chrome_piece(buddy, "deadeye")
	TEST_ASSERT_NOTNULL(piece, "The companion didn't take Deadeye optics")
	criminal.ai_add_grudge(hunter)
	buddy.ai_mark_enemy(hunter)
	buddy.ai_enter_fight()
	buddy.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, hunter)
	TEST_ASSERT(bounty_chrome_fighting(buddy), "The companion isn't in the fight")
	piece.next_lock_at = world.time
	piece.on_tick(2, TRUE)
	TEST_ASSERT_EQUAL(piece.mark_ref?.resolve(), hunter, "The companion didn't lock on")
	TEST_ASSERT_EQUAL(red_eyes(buddy), "motheyes_l", "A moth companion's red eyes aren't moth eyes")
	piece.end_lock()
	QDEL_LIST(buddies)

/**
 * Not a check: draws gunmen with and without a lock up to data/bounty_chrome_renders/ for a person to
 * look at, facing south.
 */
/datum/unit_test/voidcrew_bounty_chrome_deadeye/renders

/datum/unit_test/voidcrew_bounty_chrome_deadeye/renders/Run()
	var/list/species_list = list(/datum/species/human, /datum/species/moth, /datum/species/lizard, /datum/species/jelly)
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, tile(4, 4))
	var/number = 0
	for(var/species in species_list)
		number++
		var/mob/living/basic/bounty_criminal/criminal = new_gunman("pistol", species, tile(0, 0))
		// The look goes on in the background
		for(var/wait in 1 to 50)
			if(length(criminal.overlays))
				break
			sleep(1)
		var/datum/bounty_chrome/deadeye/piece = bounty_chrome_piece(criminal, "deadeye")
		criminal.setDir(SOUTH)
		fcopy(getFlatIcon(criminal, SOUTH, no_anim = TRUE), "data/bounty_chrome_renders/deadeye_[number]_plain.png")
		fight(criminal, hunter)
		piece.next_lock_at = world.time
		piece.on_tick(2, TRUE)
		TEST_ASSERT_NOTNULL(piece.mark_ref, "The [species] gunman didn't lock on for the render")
		criminal.setDir(SOUTH)
		fcopy(getFlatIcon(criminal, SOUTH, no_anim = TRUE), "data/bounty_chrome_renders/deadeye_[number]_locked.png")
		piece.end_lock()
		qdel(criminal)
