/// Cascade lattice on a bounty fighter (voidcrew/modules/bounties/chrome/bounty_chrome_cascade.dm): who rolls it, a surge from the whine to the crash, EMPs, and cleanup
/datum/unit_test/voidcrew_bounty_chrome_cascade

/datum/unit_test/voidcrew_bounty_chrome_cascade/proc/tile(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// A criminal with the lattice, fighting `hunter`, with its first surge due now
/datum/unit_test/voidcrew_bounty_chrome_cascade/proc/fighter_with_lattice(turf/where, mob/living/hunter)
	var/mob/living/basic/bounty_criminal/normal/criminal = allocate(/mob/living/basic/bounty_criminal/normal, where)
	bounty_chrome_install(criminal, list("cascade")) // BOUNTY_CHROME_CASCADE
	criminal.ai_start_fight(hunter)
	var/datum/bounty_chrome/cascade/piece = bounty_chrome_piece(criminal, "cascade")
	piece.next_surge_at = 0
	return criminal

/// Whether `criminal` carries anything a surge puts on
/datum/unit_test/voidcrew_bounty_chrome_cascade/proc/surge_leftovers(mob/living/basic/criminal)
	var/list/left = list()
	if(criminal.has_movespeed_modifier(/datum/movespeed_modifier/bounty_cascade))
		left += "window pace"
	if(criminal.has_movespeed_modifier(/datum/movespeed_modifier/bounty_cascade_crash))
		left += "crash pace"
	if(criminal.has_status_effect(/datum/status_effect/bounty_cascade))
		left += "blow timing"
	if(criminal.GetComponent(/datum/component/cyberware_dodge))
		left += "dodge"
	if(criminal.get_filter("bounty_cascade_glow") || criminal.get_filter("bounty_cascade_crash"))
		left += "filter"
	if(criminal.get_incoming_damage_modifier(10, STAMINA) != 1)
		left += "stamina soak"
	return left

/datum/unit_test/voidcrew_bounty_chrome_cascade/Run()
	var/datum/bounty_chrome/cascade/proto = GLOB.bounty_chrome_protos["cascade"] // BOUNTY_CHROME_CASCADE
	TEST_ASSERT_NOTNULL(proto, "No Cascade lattice prototype")

	// Who carries it: Wanted and up, any style, never the meek, a Ghost or a Heavy, never with Redline
	TEST_ASSERT(proto.weight > 0, "The Cascade lattice never rolls")
	TEST_ASSERT(!proto.can_roll(1, "normal", "knife", null, list()), "A petty criminal can roll it") // BOUNTY_TIER_PETTY, BOUNTY_ARCHETYPE_NORMAL
	TEST_ASSERT(proto.can_roll(2, "normal", "knife", null, list()), "A Wanted knife criminal can't roll it") // BOUNTY_TIER_WANTED
	TEST_ASSERT(proto.can_roll(2, "normal", "smg", null, list()), "A Wanted SMG criminal can't roll it")
	TEST_ASSERT(!proto.can_roll(3, "meek", "holdout", null, list()), "A meek criminal can roll it") // BOUNTY_ARCHETYPE_MEEK
	for(var/kit in list("juggernaut", "pyromaniac", "demolitionist")) // BOUNTY_KIT_*
		TEST_ASSERT(proto.can_roll(3, "boss", null, kit, list()), "A [kit] can't roll it") // BOUNTY_ARCHETYPE_BOSS
	for(var/kit in list("ghost", "heavy"))
		TEST_ASSERT(!proto.can_roll(3, "boss", null, kit, list()), "A [kit] can roll it")
	TEST_ASSERT(proto.can_roll(2, "companion", "pistol", null, list()), "A Wanted criminal's companion can't roll it") // BOUNTY_CHROME_COMPANION
	TEST_ASSERT(!proto.can_roll(2, "normal", "knife", null, list("redline")), "It rolls alongside Redline") // BOUNTY_CHROME_REDLINE
	var/datum/bounty_chrome/redline_proto = GLOB.bounty_chrome_protos["redline"]
	if(redline_proto)
		TEST_ASSERT(!redline_proto.can_roll(2, "normal", "knife", null, list("cascade")), "Redline rolls alongside it")
	var/rolled = FALSE
	for(var/i in 1 to 300)
		if("cascade" in bounty_pick_chrome(1, 2, "normal", "knife", null))
			rolled = TRUE
			break
	TEST_ASSERT(rolled, "A Wanted criminal never rolled it in 300 picks")
	for(var/i in 1 to 50)
		TEST_ASSERT(!("cascade" in bounty_pick_chrome(2, 1, "normal", "knife", null)), "A petty criminal rolled it")

	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, tile(4, 1))
	var/mob/living/basic/bounty_criminal/normal/criminal = fighter_with_lattice(tile(1, 1), hunter)
	var/datum/bounty_chrome/cascade/piece = bounty_chrome_piece(criminal, "cascade")
	var/datum/component/bounty_chrome/chrome = criminal.GetComponent(/datum/component/bounty_chrome)
	TEST_ASSERT_NOTNULL(piece, "The lattice isn't in the criminal")
	TEST_ASSERT(findtext(jointext(criminal.examine(hunter), " "), "Chrome ports glint"), "Examining them doesn't show the lattice")

	// Out of a fight it never surges
	piece.on_tick(2, FALSE)
	TEST_ASSERT_EQUAL(piece.phase, 0, "It surged out of a fight") // BOUNTY_CASCADE_IDLE

	// The first surge is due in the fight's opening seconds, and a later fight start never brings a cooldown forward
	piece.next_surge_at = 0
	piece.on_fight_start(hunter)
	var/opening = piece.next_surge_at - world.time
	TEST_ASSERT(opening >= 5 && opening <= 15, "The first surge is due [opening] deciseconds into the fight, not 5 to 15") // BOUNTY_CASCADE_FIRST_MIN, BOUNTY_CASCADE_FIRST_MAX
	piece.next_surge_at = world.time + 450
	piece.on_fight_start(hunter)
	TEST_ASSERT_EQUAL(piece.next_surge_at, world.time + 450, "A fight starting brought the cooldown forward")
	piece.next_surge_at = 0

	// In a fight, with its target in sight: the spin-up, a beat before anything else
	chrome.tick(2)
	TEST_ASSERT_EQUAL(piece.phase, 1, "It didn't spin up in a fight with its target in sight") // BOUNTY_CASCADE_SPINUP
	TEST_ASSERT_NOTNULL(criminal.get_filter("bounty_cascade_glow"), "The spin-up shows no glow")
	TEST_ASSERT(!criminal.has_movespeed_modifier(/datum/movespeed_modifier/bounty_cascade), "The spin-up already sped them up")
	TEST_ASSERT(piece.next_surge_at > world.time, "The spin-up didn't start the cooldown")

	// The window: speed on top of the AI's own pace, quicker blows, the dodge, afterimages
	var/pace_before = criminal.speed
	var/slowdown_before = criminal.cached_multiplicative_slowdown
	piece.open_window()
	TEST_ASSERT_EQUAL(piece.phase, 2, "The window didn't open") // BOUNTY_CASCADE_WINDOW
	// The window's own pace against a player's is in voidcrew_bounty_speed.dm; here, that it stacks with the AI's
	TEST_ASSERT(abs(criminal.cached_multiplicative_slowdown - (slowdown_before - 0.75)) < 0.01, "The window's pace is [criminal.cached_multiplicative_slowdown], not [slowdown_before - 0.75]")
	criminal.ai_set_pace(2.5) // BOUNTY_CALM_SPEED
	TEST_ASSERT(abs(criminal.cached_multiplicative_slowdown - (slowdown_before - pace_before + 2.5 - 0.75)) < 0.01, "The AI's pace doesn't work through the window")
	criminal.ai_set_pace(pace_before)
	criminal.changeNext_move(10)
	TEST_ASSERT(abs(criminal.next_move - world.time - 7.5) < 0.01, "Blows in the window come [criminal.next_move - world.time] apart, not 7.5") // BOUNTY_CASCADE_WINDOW_BLOWS
	TEST_ASSERT_NOTNULL(criminal.GetComponent(/datum/component/cyberware_dodge), "No dodge in the window")
	TEST_ASSERT_EQUAL(piece.dodge_chance(), 40, "The window's dodge isn't the player lattice's") // BOUNTY_CASCADE_DODGE
	TEST_ASSERT_EQUAL(piece.dodge_chance(), 0, "It rolled to dodge twice in one tick, as for a shell's pellets")
	var/turf/from = get_turf(criminal)
	var/afterimages_before = 0
	for(var/obj/effect/temp_visual/decoy/fading/cascade/afterimage in from)
		afterimages_before++
	TEST_ASSERT(afterimages_before >= 4, "The time-tear left [afterimages_before] afterimages, not 4")
	criminal.forceMove(tile(2, 1))
	var/afterimages_after = 0
	for(var/obj/effect/temp_visual/decoy/fading/cascade/afterimage in from)
		afterimages_after++
	TEST_ASSERT_EQUAL(afterimages_after, afterimages_before + 1, "A step in the window didn't leave one afterimage")
	// Standing still in the window, it still blurs: each pulse with no step leaves an afterimage sliding off it
	var/turf/standing = get_turf(criminal)
	var/blurs_before = 0
	for(var/obj/effect/temp_visual/decoy/fading/cascade/afterimage in standing)
		blurs_before++
	piece.last_step_at = world.time - 10
	piece.window_pulse()
	TEST_ASSERT_EQUAL(piece.phase, 2, "A pulse in the fight ended the window")
	var/blurs_after = 0
	for(var/obj/effect/temp_visual/decoy/fading/cascade/afterimage in standing)
		blurs_after++
	TEST_ASSERT_EQUAL(blurs_after, blurs_before + 1, "Standing still in the window, it didn't blur")
	TEST_ASSERT_EQUAL(get_turf(criminal), standing, "The blur moved them")
	TEST_ASSERT(findtext(jointext(criminal.examine(hunter), " "), "burns violet"), "Examining them in the window doesn't show it")

	// Quicker shots in the window, once a burst
	var/datum/component/ranged_attacks/gun = criminal.GetComponent(/datum/component/ranged_attacks)
	if(gun)
		gun.cooldown_time = 10
		gun.fire_cooldown = world.time + 10
		piece.on_fire(null, null)
		TEST_ASSERT(abs(gun.fire_cooldown - world.time - 7.5) < 0.01, "A shot in the window didn't ready the next one sooner") // BOUNTY_CASCADE_WINDOW_SHOTS
		piece.on_fire(null, null)
		TEST_ASSERT(abs(gun.fire_cooldown - world.time - 7.5) < 0.01, "A burst's later rounds made the gun quicker still")

	// The crash: slow, slower blows, a stamina dump, stamina hits land twice as hard, no dodge
	piece.start_crash()
	TEST_ASSERT_EQUAL(piece.phase, 3, "The window didn't crash") // BOUNTY_CASCADE_CRASH
	TEST_ASSERT(!criminal.has_movespeed_modifier(/datum/movespeed_modifier/bounty_cascade), "The window's speed outlived it")
	TEST_ASSERT(abs(criminal.cached_multiplicative_slowdown - (slowdown_before + 2.5)) < 0.01, "The crash's pace is [criminal.cached_multiplicative_slowdown], not [slowdown_before + 2.5]")
	TEST_ASSERT_NULL(criminal.GetComponent(/datum/component/cyberware_dodge), "The dodge outlived the window")
	criminal.changeNext_move(10)
	TEST_ASSERT(abs(criminal.next_move - world.time - 14) < 0.01, "Blows in the crash come [criminal.next_move - world.time] apart, not 14") // BOUNTY_CASCADE_CRASH_BLOWS
	TEST_ASSERT_EQUAL(criminal.get_incoming_damage_modifier(10, STAMINA), 2, "Stamina hits don't land harder in the crash") // BOUNTY_CASCADE_CRASH_STAMINA_MULT
	TEST_ASSERT_EQUAL(criminal.get_incoming_damage_modifier(10, BRUTE), 1, "The crash changed brute damage")
	TEST_ASSERT(criminal.staminaloss > 0, "The crash dumped no stamina")
	TEST_ASSERT_NOTNULL(criminal.get_filter("bounty_cascade_crash"), "The crash shows no colour")
	TEST_ASSERT_NULL(criminal.get_filter("bounty_cascade_glow"), "The window's glow outlived it")

	// Over: everything back as it was
	piece.end_crash()
	TEST_ASSERT_EQUAL(piece.phase, 0, "The crash didn't end")
	var/list/left = surge_leftovers(criminal)
	TEST_ASSERT(!length(left), "A finished surge left behind: [english_list(left)]")
	TEST_ASSERT(abs(criminal.cached_multiplicative_slowdown - slowdown_before) < 0.01, "Their pace after a surge is [criminal.cached_multiplicative_slowdown], not [slowdown_before]")
	criminal.changeNext_move(10)
	TEST_ASSERT(abs(criminal.next_move - world.time - 10) < 0.01, "Their blows are still changed after a surge")

	// An EMP in the window crashes it at once and re-arms the whole cooldown
	piece.spin_up()
	piece.open_window()
	criminal.emp_act(EMP_HEAVY)
	TEST_ASSERT_EQUAL(piece.phase, 3, "An EMP in the window didn't crash it")
	TEST_ASSERT(!piece.online(), "The lattice works through an EMP")
	TEST_ASSERT(piece.next_surge_at >= world.time + 450, "An EMP in the window didn't re-arm the cooldown") // BOUNTY_CASCADE_COOLDOWN
	TEST_ASSERT(findtext(jointext(criminal.examine(hunter), " "), "is dark"), "Examining an EMP'd lattice doesn't show it")
	piece.end_crash()
	TEST_ASSERT(!length(surge_leftovers(criminal)), "An EMP's crash left something behind")
	// An EMP in the spin-up crashes it too
	piece.offline_until = world.time
	chrome.tick(2)
	TEST_ASSERT(piece.online(), "The lattice didn't come back from the EMP")
	piece.spin_up()
	criminal.emp_act(EMP_HEAVY)
	TEST_ASSERT_EQUAL(piece.phase, 3, "An EMP in the spin-up didn't crash it")
	piece.end_crash()
	piece.offline_until = world.time
	chrome.tick(2)

	// The fight ending mid-window crashes it
	piece.spin_up()
	piece.open_window()
	criminal.ai_set_mode("calm") // BOUNTY_AI_CALM
	piece.window_pulse()
	TEST_ASSERT_EQUAL(piece.phase, 3, "The fight ending mid-window didn't crash it")
	piece.end_crash()
	criminal.ai_set_mode("fighting") // BOUNTY_AI_FIGHTING

	// Going down mid-window ends everything, with no crash
	piece.spin_up()
	piece.open_window()
	criminal.body_go_down()
	TEST_ASSERT_EQUAL(piece.phase, 0, "Going down left a surge running")
	left = surge_leftovers(criminal)
	TEST_ASSERT(!length(left), "Going down mid-window left behind: [english_list(left)]")
	TEST_ASSERT(!piece.dodge_chance(), "A downed criminal can still dodge")

	// Dying mid-window
	var/mob/living/basic/bounty_criminal/normal/doomed = fighter_with_lattice(tile(2, 4), hunter)
	var/datum/bounty_chrome/cascade/doomed_piece = bounty_chrome_piece(doomed, "cascade")
	doomed_piece.spin_up()
	doomed_piece.open_window()
	doomed.death()
	TEST_ASSERT_EQUAL(doomed_piece.phase, 0, "Dying left a surge running")
	left = surge_leftovers(doomed)
	TEST_ASSERT(!length(left), "Dying mid-window left behind: [english_list(left)]")
	doomed_piece.start_crash()
	TEST_ASSERT_EQUAL(doomed_piece.phase, 0, "A dead criminal crashed")

	// Deleted mid-window: the piece goes with it, its timers stopped
	var/mob/living/basic/bounty_criminal/normal/deleted = fighter_with_lattice(tile(3, 4), hunter)
	var/datum/bounty_chrome/cascade/deleted_piece = bounty_chrome_piece(deleted, "cascade")
	deleted_piece.spin_up()
	deleted_piece.open_window()
	qdel(deleted)
	TEST_ASSERT(QDELETED(deleted_piece), "The piece outlived its criminal")
	TEST_ASSERT_NULL(deleted_piece.owner, "A deleted criminal's piece kept its owner")
	TEST_ASSERT(isnull(deleted_piece.phase_timer) && isnull(deleted_piece.strafe_timer), "A deleted criminal's piece kept its timers")

	// A gunman sidesteps in the window, and keeps its distance doing it
	var/mob/living/carbon/human/consistent/gun_hunter = allocate(/mob/living/carbon/human/consistent, tile(4, 2))
	var/mob/living/basic/bounty_criminal/normal/gunman = fighter_with_lattice(tile(0, 2), gun_hunter)
	bounty_ai_apply_style(gunman, "pistol") // BOUNTY_STYLE_PISTOL
	var/datum/bounty_chrome/cascade/gunman_piece = bounty_chrome_piece(gunman, "cascade")
	gunman_piece.spin_up()
	gunman_piece.open_window()
	var/turf/gunman_was = get_turf(gunman)
	gunman_piece.sidestep()
	TEST_ASSERT(get_turf(gunman) != gunman_was, "A gunman in the window didn't sidestep")
	TEST_ASSERT_EQUAL(gunman.x, gunman_was.x, "A gunman's sidestep went toward or away from its target")
	// Held in place (a Piledriver crouch, a lunge), it neither sidesteps nor dodges
	ADD_TRAIT(gunman, TRAIT_IMMOBILIZED, TRAIT_GENERIC)
	gunman_was = get_turf(gunman)
	gunman.ai_controller.set_blackboard_key("bb_bounty_sidestep_at", 0) // BB_BOUNTY_SIDESTEP_AT
	gunman_piece.sidestep()
	TEST_ASSERT_EQUAL(get_turf(gunman), gunman_was, "Held in place, a gunman sidestepped")
	gunman_piece.last_dodge_roll = -1
	TEST_ASSERT_EQUAL(gunman_piece.dodge_chance(), 0, "Held in place, it could dodge")
	REMOVE_TRAIT(gunman, TRAIT_IMMOBILIZED, TRAIT_GENERIC)
	gunman_piece.last_dodge_roll = -1
	TEST_ASSERT_EQUAL(gunman_piece.dodge_chance(), 40, "Let go, it couldn't dodge") // BOUNTY_CASCADE_DODGE
	gunman_piece.end_surge()

	// A companion at the bar never surges; one in the fight does
	var/mob/living/basic/bounty_companion/buddy = allocate(/mob/living/basic/bounty_companion, tile(2, 3))
	bounty_chrome_install(buddy, list("cascade"))
	var/datum/bounty_chrome/cascade/buddy_piece = bounty_chrome_piece(buddy, "cascade")
	buddy.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, hunter)
	buddy_piece.on_tick(2, TRUE)
	TEST_ASSERT_EQUAL(buddy_piece.phase, 0, "A companion out of the fight surged")
	buddy.ai_in_fight = TRUE
	buddy_piece.on_tick(2, TRUE)
	TEST_ASSERT_EQUAL(buddy_piece.phase, 1, "A companion in the fight didn't surge")

	// Its criminal gone, nothing holds a companion's steps to a site: in the window it neither sidesteps nor dodges
	buddy.ai_take_style("pistol") // BOUNTY_STYLE_PISTOL
	buddy_piece.open_window()
	TEST_ASSERT_EQUAL(buddy_piece.phase, 2, "A companion's window didn't open")
	buddy_piece.last_dodge_roll = -1
	TEST_ASSERT_EQUAL(buddy_piece.dodge_chance(), 0, "A companion with no criminal could dodge")
	var/turf/buddy_was = get_turf(buddy)
	buddy.ai_controller.set_blackboard_key("bb_bounty_sidestep_at", 0) // BB_BOUNTY_SIDESTEP_AT
	buddy_piece.sidestep()
	TEST_ASSERT_EQUAL(get_turf(buddy), buddy_was, "A companion with no criminal sidestepped")
	// With its criminal, it dodges, and its own steps in the window stay on the criminal's leash
	buddy.leader_ref = WEAKREF(gunman)
	buddy_piece.last_dodge_roll = -1
	TEST_ASSERT_EQUAL(buddy_piece.dodge_chance(), 40, "A companion with its criminal couldn't dodge")
	var/turf/corner = tile(0, 0)
	gunman.site_bounds = list(corner.x, corner.y, buddy.x, buddy.y + 1, corner.z)
	TEST_ASSERT(!buddy.Move(tile(3, 3), EAST), "In the window, a companion stepped off its criminal's leash")
	TEST_ASSERT(buddy.Move(tile(1, 3), WEST), "In the window, a companion couldn't step about on its criminal's leash")
	gunman.site_bounds = null
	buddy.leader_ref = null
	buddy_piece.end_surge()

/**
 * Not a check: with -DBOUNTY_CHROME_RENDERS, draws the lattice as worn, and a surge's afterimage and crash colours, to
 * data/bounty_chrome_renders/ for a person to look at.
 */
/datum/unit_test/voidcrew_bounty_chrome_cascade/renders

/datum/unit_test/voidcrew_bounty_chrome_cascade/renders/Run()
	var/list/organs = bounty_chrome_organ_looks(list("cascade")) // BOUNTY_CHROME_CASCADE
	TEST_ASSERT(length(organs), "The lattice has no worn look")
	var/datum/outfit/jeans = new
	jeans.uniform = /obj/item/clothing/under/pants/jeans
	jeans.shoes = /obj/item/clothing/shoes/sneakers/black
	var/list/looks = list(
		"1_bare_south" = list(/datum/species/human, null, SOUTH),
		"2_bare_north" = list(/datum/species/human, null, NORTH),
		"3_jeans_lizard_north" = list(/datum/species/lizard, jeans, NORTH),
		"4_jeans_lizard_south" = list(/datum/species/lizard, jeans, SOUTH),
		"5_tough_felinid_south" = list(/datum/species/human/felinid, /datum/outfit/bounty_criminal/tough, SOUTH),
	)
	var/list/dummies = list()
	for(var/look_name in looks)
		var/list/spec = looks[look_name]
		var/datum/bounty_look/look = bounty_roll_look(spec[1], MALE)
		var/mob/living/carbon/human/dummy/dummy = bounty_look_dummy(look, spec[2], null, chrome_organs = organs)
		TEST_ASSERT(dummy, "The [look_name] look could not be built")
		if(!dummy)
			continue
		dummies[look_name] = dummy
		TEST_ASSERT_NOTNULL(locate(/obj/item/organ/cyberimp/cyberware/cascade) in dummy.organs, "The [look_name] dummy has no lattice")
		dummy.setDir(spec[3])
#ifdef BOUNTY_CHROME_RENDERS
		fcopy(getFlatIcon(dummy, spec[3]), "data/bounty_chrome_renders/cascade_[look_name].png")
#endif
#ifdef BOUNTY_CHROME_RENDERS
	// The afterimages a step leaves, tinted as the trail is, a few hues along it (flattening drops an atom's colour, so the tint is put on by hand)
	var/mob/living/carbon/human/dummy/clothed = dummies["5_tough_felinid_south"]
	if(clothed)
		clothed.setDir(SOUTH)
		var/obj/effect/temp_visual/decoy/fading/cascade/afterimage = new(run_loc_floor_bottom_left, clothed, 0)
		for(var/hue in list(0, 100, 280))
			var/icon/trail = getFlatIcon(clothed, SOUTH)
			trail.MapColors(arglist(afterimage.cascade_tint_matrix(hue)))
			fcopy(trail, "data/bounty_chrome_renders/cascade_6_afterimage_[hue].png")
		qdel(afterimage)
		// The crash colours, as the crash's colour filter has them
		var/icon/crashed = getFlatIcon(clothed, SOUTH)
		crashed.MapColors(0.55, 0.3, 0.25, 0.35, 0.55, 0.25, 0.25, 0.25, 0.5)
		fcopy(crashed, "data/bounty_chrome_renders/cascade_7_crash.png")
#endif
	for(var/look_name in dummies)
		delete_dummy(dummies[look_name])

/**
 * Deletes a look dummy with the lattice in it. tg's /obj/item/organ/cyberimp/Destroy() deletes its
 * worn overlay before it comes out of the body, so a dummy deleted with the lattice in and clothes
 * on runtimes as each piece comes off; the lattice comes out first here.
 */
/datum/unit_test/voidcrew_bounty_chrome_cascade/renders/proc/delete_dummy(mob/living/carbon/human/dummy/dummy)
	for(var/obj/item/organ/cyberimp/cyberware/cascade/lattice in dummy.organs)
		lattice.Remove(dummy, TRUE)
		qdel(lattice)
	qdel(dummy)
