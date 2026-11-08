/**
 * Redline core on a bounty fighter (voidcrew/modules/bounties/chrome/bounty_chrome_redline.dm). Every
 * test drives the procs directly with the mobs in place: a test world has no clients, so the AI is
 * off (its signal hooks still run, so a real shot or blow still starts the fight). Fork defines are
 * included after the tests, so a test uses the literal value with a comment naming the define. The
 * tell's and the burn's timers are cut short by calling their procs.
 */
/datum/unit_test/voidcrew_bounty_chrome_redline
	abstract_type = /datum/unit_test/voidcrew_bounty_chrome_redline

/// The floor tile `dx`, `dy` from the room's bottom left
/datum/unit_test/voidcrew_bounty_chrome_redline/proc/tile(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// A hunter at `where`: a human with a mind, as a player would be, with a knife out
/datum/unit_test/voidcrew_bounty_chrome_redline/proc/hunter_at(turf/where)
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, where)
	hunter.mind_initialize()
	hunter.put_in_hands(allocate(/obj/item/knife/kitchen))
	return hunter

/// A normal criminal at `where` with the core in
/datum/unit_test/voidcrew_bounty_chrome_redline/proc/redliner(turf/where)
	var/mob/living/basic/bounty_criminal/normal/criminal = allocate(/mob/living/basic/bounty_criminal/normal, where)
	bounty_chrome_install(criminal, list("redline")) // BOUNTY_CHROME_REDLINE
	return criminal

/// `piece`'s tell is over now: the roar
/datum/unit_test/voidcrew_bounty_chrome_redline/proc/roar_now(datum/bounty_chrome/redline/piece)
	deltimer(piece.burn_timer)
	piece.roar()

/// `piece`'s burn is over now: the collapse
/datum/unit_test/voidcrew_bounty_chrome_redline/proc/burn_out_now(datum/bounty_chrome/redline/piece)
	deltimer(piece.burn_timer)
	piece.burn_out()

/// `hunter` shoots `target` point-blank with a real round of `round_type`, down a gun's own path (prehit, bullet_act, on_hit). Returns the health it took.
/datum/unit_test/voidcrew_bounty_chrome_redline/proc/shoot(mob/living/hunter, mob/living/target, round_type)
	var/health_before = target.health
	var/obj/projectile/shot = new round_type(get_turf(hunter))
	shot.firer = hunter
	shot.fired_from = hunter
	shot.aim_projectile(target, hunter)
	shot.fire(get_angle(hunter, target), target)
	if(!QDELETED(shot))
		qdel(shot)
	return health_before - target.health

/// `hunter` hits `target` with `weapon` in hand, down an item's own attack (attacked_by, then the after-attack signal). Returns the health it took.
/datum/unit_test/voidcrew_bounty_chrome_redline/proc/strike(mob/living/hunter, mob/living/target, obj/item/weapon)
	var/health_before = target.health
	weapon.attack(target, hunter)
	return health_before - target.health

/**
 * `hunter` shoots `target`, which carries `piece`, with rounds of `round_type` from where it stands
 * until it is down, dead or has given up (at most 20 rounds). `tell_rounds` rounds land in the tell,
 * then it roars. Returns list("trip" = the round that tripped it or 0, "trip_percent" = its health
 * then, "after" = how many rounds landed after the trip, "resisted" = what each of those that left
 * it on its feet took, "fighting" = whether it was in the fight after the first round, "trace").
 */
/datum/unit_test/voidcrew_bounty_chrome_redline/proc/shoot_it_out(mob/living/basic/target, mob/living/hunter, datum/bounty_chrome/redline/piece, round_type, tell_rounds = 2)
	var/static/list/state_names = list("idle", "tell", "burn")
	var/list/trace = list()
	var/list/resisted = list()
	var/after = 0
	var/trip = 0
	var/trip_percent = 0
	var/fighting = FALSE
	var/tell_left = 0
	var/mob/living/basic/bounty_criminal/criminal = istype(target, /mob/living/basic/bounty_criminal) ? target : null
	var/mob/living/basic/bounty_companion/companion = istype(target, /mob/living/basic/bounty_companion) ? target : null
	for(var/shot in 1 to 20)
		if(target.stat == DEAD || criminal?.downed || companion?.ai_gave_up)
			break
		var/tripped_before = piece.state != 0 // REDLINE_IDLE
		var/taken = shoot(hunter, target, round_type)
		if(shot == 1)
			fighting = bounty_chrome_fighting(target)
		var/still_up = target.stat != DEAD && !criminal?.downed
		trace += "[shot]: -[taken] = [target.health] ([round(100 * target.health / target.maxHealth)]%) [state_names[piece.state + 1]][still_up ? "" : " DOWN"]"
		if(tripped_before)
			after++
			if(still_up)
				resisted += taken
			if(piece.state == 1) // REDLINE_WINDING
				tell_left--
				if(tell_left <= 0)
					roar_now(piece)
		else if(piece.state != 0)
			trip = shot
			trip_percent = round(100 * target.health / target.maxHealth)
			tell_left = tell_rounds
	return list("trip" = trip, "trip_percent" = trip_percent, "after" = after, "resisted" = resisted, "fighting" = fighting, "trace" = jointext(trace, "; "))

/// Who rolls it: Wanted and up, never the meek, not the armoured kits, never beside a Cascade lattice
/datum/unit_test/voidcrew_bounty_chrome_redline/rolls

/datum/unit_test/voidcrew_bounty_chrome_redline/rolls/Run()
	var/datum/bounty_chrome/proto = GLOB.bounty_chrome_protos["redline"] // BOUNTY_CHROME_REDLINE
	TEST_ASSERT_NOTNULL(proto, "No Redline core prototype")
	TEST_ASSERT(proto.weight > 0, "The Redline core never rolls")
	// Tiers: BOUNTY_TIER_PETTY 1, BOUNTY_TIER_WANTED 2, BOUNTY_TIER_MOST_WANTED 3
	TEST_ASSERT(proto.can_roll(2, "normal", "brawler", null, list()), "A Wanted brawler can't roll it")
	TEST_ASSERT(proto.can_roll(3, "normal", "pistol", null, list()), "A Most Wanted gunman can't roll it")
	TEST_ASSERT(!proto.can_roll(1, "normal", "brawler", null, list()), "A Petty criminal can roll it")
	TEST_ASSERT(!proto.can_roll(3, "meek", "holdout", null, list()), "A meek criminal can roll it")
	TEST_ASSERT(proto.can_roll(2, "companion", "knife", null, list()), "A Wanted criminal's companion can't roll it") // BOUNTY_CHROME_COMPANION
	TEST_ASSERT(!proto.can_roll(1, "companion", "knife", null, list()), "A Petty criminal's companion can roll it")
	for(var/kit in list("pyromaniac", "demolitionist", "ghost"))
		TEST_ASSERT(proto.can_roll(3, "boss", null, kit, list()), "The [kit] can't roll it")
	for(var/kit in list("juggernaut", "heavy"))
		TEST_ASSERT(!proto.can_roll(3, "boss", null, kit, list()), "The [kit], in its armour, can roll it")
	TEST_ASSERT(!proto.can_roll(3, "normal", "brawler", null, list("cascade")), "It can roll beside a Cascade lattice") // BOUNTY_CHROME_CASCADE
	var/datum/bounty_chrome/cascade = GLOB.bounty_chrome_protos["cascade"]
	TEST_ASSERT(!cascade?.can_roll(3, "normal", "brawler", null, list("redline")), "A Cascade lattice can roll beside it")

	var/rolled = FALSE
	for(var/i in 1 to 300)
		var/list/pair = bounty_pick_chrome(2, 3, "normal", "brawler", null) || list()
		TEST_ASSERT(!(("redline" in pair) && ("cascade" in pair)), "It rolled beside a Cascade lattice")
		if("redline" in pair)
			rolled = TRUE
		var/list/petty = bounty_pick_chrome(1, 1, "normal", "brawler", null) || list()
		TEST_ASSERT(!("redline" in petty), "A Petty criminal rolled it")
		var/list/meek = bounty_pick_chrome(1, 3, "meek", "holdout", null) || list()
		TEST_ASSERT(!("redline" in meek), "A meek criminal rolled it")
	TEST_ASSERT(rolled, "In 300 rolls for a Most Wanted brawler it never came up")

/// Badly hurt in a fight: the tell, the roar, the burn (shorter than the player implant's), and the collapse into the cuffs
/datum/unit_test/voidcrew_bounty_chrome_redline/burn

/datum/unit_test/voidcrew_bounty_chrome_redline/burn/Run()
	var/mob/living/basic/bounty_criminal/normal/criminal = redliner(tile(1, 1))
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(3, 1))
	var/datum/bounty_chrome/redline/piece = bounty_chrome_piece(criminal, "redline")
	TEST_ASSERT_NOTNULL(piece, "The core isn't in the criminal")
	TEST_ASSERT(findtext(jointext(criminal.examine(hunter), " "), "red-lit speaker grille"), "Examining them doesn't show the core")

	// Hurt out of a fight: nothing
	criminal.apply_damage(criminal.maxHealth * 0.45, BRUTE)
	TEST_ASSERT_EQUAL(piece.state, 0, "It tripped out of a fight") // REDLINE_IDLE
	criminal.setBruteLoss(0)
	criminal.ai_start_fight(hunter)
	TEST_ASSERT(bounty_chrome_fighting(criminal), "The criminal isn't fighting")

	// A light hit: nothing
	criminal.apply_damage(criminal.maxHealth * 0.2, BRUTE)
	TEST_ASSERT_EQUAL(piece.state, 0, "It tripped on a light hit") // REDLINE_IDLE
	// Badly hurt: the tell, and stuns slide off already
	criminal.apply_damage(criminal.maxHealth * 0.25, BRUTE)
	TEST_ASSERT_EQUAL(piece.state, 1, "A hit to 55% health didn't trip it") // REDLINE_WINDING
	TEST_ASSERT(HAS_TRAIT(criminal, TRAIT_STUNIMMUNE), "Stuns still land in the tell")
	TEST_ASSERT_NOTNULL(criminal.get_filter("bounty_chrome_redline"), "No red outline in the tell") // REDLINE_FILTER
	TEST_ASSERT_NOTNULL(piece.glow, "No red light comes up in the tell")
	var/obj/effect/tell_glow = piece.glow
	criminal.Knockdown(2 SECONDS)
	TEST_ASSERT(!criminal.IsKnockdown(), "A knockdown landed in the tell")
	TEST_ASSERT(criminal.ai_surrender_rolled, "Their surrender roll isn't held off")

	// The tell already takes the edge off a hit (REDLINE_DAMAGE_MULT 0.5)
	var/tell_before = criminal.bruteloss
	criminal.apply_damage(10, BRUTE)
	TEST_ASSERT(abs(criminal.bruteloss - tell_before - 5) < 0.1, "A hit in the tell came in at [criminal.bruteloss - tell_before], not 5") // 10 * REDLINE_DAMAGE_MULT

	// The roar: the hunter two tiles off staggers
	roar_now(piece)
	TEST_ASSERT_EQUAL(piece.state, 2, "The tell never turned into the burn") // REDLINE_BURNING
	TEST_ASSERT_NOTNULL(hunter.has_status_effect(/datum/status_effect/staggered), "The roar didn't stagger the hunter beside them")
	TEST_ASSERT_NOTNULL(piece.glow, "No red glow in the burn")
	TEST_ASSERT(QDELETED(tell_glow), "The tell's dim light stayed on under the burn's")
	// The NPC's burn (REDLINE_WINDOW 8 s), not the player implant's 12 (CYBERWARE_REDLINE_WINDOW)
	var/burn_left = timeleft(piece.burn_timer)
	TEST_ASSERT(burn_left > 7 SECONDS && burn_left <= 8 SECONDS, "The burn runs [burn_left / 10] seconds, not 8")
	TEST_ASSERT(findtext(jointext(criminal.examine(hunter), " "), "Red light pours"), "Examining them mid-burn doesn't show it")

	// The burn: hits come in at half, burns too, stamina crit slides off, blows land harder
	var/before = criminal.bruteloss
	criminal.apply_damage(10, BRUTE)
	TEST_ASSERT(abs(criminal.bruteloss - before - 5) < 0.1, "A hit in the burn came in at [criminal.bruteloss - before], not 5") // 10 * REDLINE_DAMAGE_MULT
	before = criminal.bruteloss
	criminal.apply_damage(10, BURN)
	TEST_ASSERT(abs(criminal.bruteloss - before - 5) < 0.1, "A burn in the burn came in at [criminal.bruteloss - before], not 5") // 10 * REDLINE_DAMAGE_MULT
	TEST_ASSERT(piece.next_flinch_at > world.time, "A hit mid-burn didn't show them barely flinching")
	criminal.adjustStaminaLoss(200, forced = TRUE)
	TEST_ASSERT_NULL(criminal.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "Stamina crit landed in the burn")
	criminal.setStaminaLoss(0, TRUE, TRUE)
	var/hunter_before = hunter.getBruteLoss()
	piece.on_melee_hit(hunter)
	TEST_ASSERT(abs(hunter.getBruteLoss() - hunter_before - 8) < 0.1, "A blow in the burn did [hunter.getBruteLoss() - hunter_before] extra, not 8") // REDLINE_MELEE_BONUS
	TEST_ASSERT_EQUAL(criminal.capture_state(), "free", "Mid-burn they count as caught") // BOUNTY_STATE_FREE

	// The collapse: stamina crit, cuffable, slow, and everything the burn put on them gone
	burn_out_now(piece)
	TEST_ASSERT_EQUAL(piece.state, 0, "The burn didn't end") // REDLINE_IDLE
	TEST_ASSERT(!HAS_TRAIT(criminal, TRAIT_STUNIMMUNE), "Stun immunity outlived the burn")
	TEST_ASSERT(!HAS_TRAIT(criminal, TRAIT_BATON_RESISTANCE), "Baton resistance outlived the burn")
	TEST_ASSERT_NULL(piece.glow, "The red glow outlived the burn")
	TEST_ASSERT_NULL(criminal.get_filter("bounty_chrome_redline"), "The red outline outlived the burn") // REDLINE_FILTER
	TEST_ASSERT(!criminal.ai_surrender_rolled, "Their surrender roll wasn't put back")
	TEST_ASSERT_NOTNULL(criminal.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "The collapse didn't put them in stamina crit")
	TEST_ASSERT_EQUAL(criminal.capture_state(), "stunned", "Collapsed, they don't count as stunned") // BOUNTY_STATE_STUNNED
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	TEST_ASSERT_NULL(criminal.body_cuff_refusal(null, cuffs), "Collapsed, they can't be cuffed")
	TEST_ASSERT(criminal.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_redline_crash), "No slow after the collapse")
	TEST_ASSERT(!piece.can_trip(), "It can trip again straight after the collapse")
	TEST_ASSERT(findtext(jointext(criminal.examine(hunter), " "), "is dark"), "Examining them after the collapse doesn't show it spent")
	piece.end_crash()
	TEST_ASSERT(!criminal.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_redline_crash), "The slow outlived its end")

/// A stun, a knockdown or a stamina crit in a fight trips it and never lands; caught unaware, or with a forced stun, they go down
/datum/unit_test/voidcrew_bounty_chrome_redline/stun_trip

/datum/unit_test/voidcrew_bounty_chrome_redline/stun_trip/Run()
	var/mob/living/basic/bounty_criminal/normal/criminal = redliner(tile(1, 1))
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(3, 1))
	var/datum/bounty_chrome/redline/piece = bounty_chrome_piece(criminal, "redline")

	// Unaware: a knockdown lands as on anyone
	criminal.Knockdown(2 SECONDS)
	TEST_ASSERT(criminal.IsKnockdown(), "A knockdown out of a fight didn't land")
	TEST_ASSERT_EQUAL(piece.state, 0, "A knockdown out of a fight tripped it") // REDLINE_IDLE
	criminal.SetKnockdown(0)

	// In a fight: the knockdown trips it instead
	criminal.ai_start_fight(hunter)
	criminal.Knockdown(2 SECONDS)
	TEST_ASSERT(!criminal.IsKnockdown(), "A knockdown in a fight landed")
	TEST_ASSERT_EQUAL(piece.state, 1, "A knockdown in a fight didn't trip it") // REDLINE_WINDING
	criminal.Paralyze(2 SECONDS)
	TEST_ASSERT(!criminal.IsParalyzed(), "Paralysis landed in the tell")
	// A forced stun (an admin's) always lands
	criminal.Paralyze(2 SECONDS, TRUE)
	TEST_ASSERT(criminal.IsParalyzed(), "A forced paralysis didn't land in the tell")
	criminal.SetParalyzed(0, TRUE)
	piece.end_burn(collapse = FALSE)

	// A stamina crit about to land trips a fresh core too
	var/mob/living/basic/bounty_criminal/normal/other = redliner(tile(1, 3))
	var/datum/bounty_chrome/redline/other_piece = bounty_chrome_piece(other, "redline")
	other.ai_start_fight(hunter)
	other.adjustStaminaLoss(200, forced = TRUE)
	TEST_ASSERT_NULL(other.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "A stamina crit in a fight landed")
	TEST_ASSERT_EQUAL(other_piece.state, 1, "A stamina crit in a fight didn't trip it") // REDLINE_WINDING
	other_piece.end_burn(collapse = FALSE)

/// An EMP in the burn or the tell drops them straight into the collapse; one while it is armed keeps it offline, so a stun lands
/datum/unit_test/voidcrew_bounty_chrome_redline/emp

/datum/unit_test/voidcrew_bounty_chrome_redline/emp/Run()
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(4, 4))

	// In the burn
	var/mob/living/basic/bounty_criminal/normal/burning = redliner(tile(1, 1))
	var/datum/bounty_chrome/redline/piece = bounty_chrome_piece(burning, "redline")
	burning.ai_start_fight(hunter)
	burning.apply_damage(burning.maxHealth * 0.45, BRUTE)
	roar_now(piece)
	TEST_ASSERT_EQUAL(piece.state, 2, "It never started burning") // REDLINE_BURNING
	burning.emp_act(EMP_HEAVY)
	TEST_ASSERT_EQUAL(piece.state, 0, "An EMP didn't end the burn") // REDLINE_IDLE
	TEST_ASSERT(!piece.online(), "The core works through an EMP")
	TEST_ASSERT_NOTNULL(burning.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "An EMP in the burn didn't collapse them")
	TEST_ASSERT(piece.ready_at > world.time + 80 SECONDS, "An EMP in the burn didn't start the cooldown over") // REDLINE_COOLDOWN 90 s

	// In the tell
	var/mob/living/basic/bounty_criminal/normal/winding = redliner(tile(1, 2))
	var/datum/bounty_chrome/redline/winding_piece = bounty_chrome_piece(winding, "redline")
	winding.ai_start_fight(hunter)
	winding.apply_damage(winding.maxHealth * 0.45, BRUTE)
	TEST_ASSERT_EQUAL(winding_piece.state, 1, "It never tripped") // REDLINE_WINDING
	winding.emp_act(EMP_HEAVY)
	TEST_ASSERT_EQUAL(winding_piece.state, 0, "An EMP didn't end the tell") // REDLINE_IDLE
	TEST_ASSERT_NULL(winding_piece.burn_timer, "The roar is still coming after an EMP in the tell")
	TEST_ASSERT_NULL(winding_piece.glow, "The tell's light outlived an EMP")
	TEST_ASSERT_NOTNULL(winding.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "An EMP in the tell didn't collapse them")

	// Armed: offline for its reboot, so a knockdown in a fight lands
	var/mob/living/basic/bounty_criminal/normal/armed = redliner(tile(1, 3))
	var/datum/bounty_chrome/redline/armed_piece = bounty_chrome_piece(armed, "redline")
	armed.ai_start_fight(hunter)
	armed.emp_act(EMP_HEAVY)
	TEST_ASSERT(!armed_piece.online(), "An EMP didn't knock the armed core out")
	TEST_ASSERT_NULL(armed.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "An EMP on an armed core collapsed them")
	armed.Knockdown(2 SECONDS)
	TEST_ASSERT(armed.IsKnockdown(), "A knockdown didn't land on an EMP'd core")
	TEST_ASSERT_EQUAL(armed_piece.state, 0, "An EMP'd core tripped") // REDLINE_IDLE

/// The body's rules hold through the burn: a big hit stops at the downed line, the burn ends there with no collapse, and death and deletion clean it all up
/datum/unit_test/voidcrew_bounty_chrome_redline/body_rules

/datum/unit_test/voidcrew_bounty_chrome_redline/body_rules/Run()
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(4, 4))

	// Downed mid-burn
	var/mob/living/basic/bounty_criminal/normal/criminal = redliner(tile(1, 1))
	var/datum/bounty_chrome/redline/piece = bounty_chrome_piece(criminal, "redline")
	criminal.ai_start_fight(hunter)
	criminal.apply_damage(criminal.maxHealth * 0.45, BRUTE)
	roar_now(piece)
	criminal.apply_damage(1000, BRUTE)
	TEST_ASSERT(criminal.stat != DEAD, "A big hit in the burn killed them through the mercy line")
	TEST_ASSERT(criminal.downed, "A big hit in the burn didn't put them down")
	TEST_ASSERT_EQUAL(piece.state, 0, "The burn went on while they were down") // REDLINE_IDLE
	TEST_ASSERT(!HAS_TRAIT(criminal, TRAIT_STUNIMMUNE), "Stun immunity outlived the downing")
	TEST_ASSERT_NULL(criminal.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "Downed, they collapsed as well")
	TEST_ASSERT(!criminal.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_redline_crash), "Downed, they got the collapse's slow")
	TEST_ASSERT_EQUAL(criminal.capture_state(), "downed", "Not downed") // BOUNTY_STATE_DOWNED
	// Down, no hit trips it
	criminal.apply_damage(5, BRUTE)
	TEST_ASSERT_EQUAL(piece.state, 0, "It tripped while they were down") // REDLINE_IDLE

	// Dead mid-burn
	var/mob/living/basic/bounty_criminal/normal/doomed = redliner(tile(1, 2))
	var/datum/bounty_chrome/redline/doomed_piece = bounty_chrome_piece(doomed, "redline")
	doomed.ai_start_fight(hunter)
	doomed.apply_damage(doomed.maxHealth * 0.45, BRUTE)
	roar_now(doomed_piece)
	var/obj/glow = doomed_piece.glow
	doomed.death()
	TEST_ASSERT_EQUAL(doomed_piece.state, 0, "The burn outlived its fighter") // REDLINE_IDLE
	TEST_ASSERT(QDELETED(glow), "The red glow outlived its fighter")
	TEST_ASSERT_NULL(doomed.get_filter("bounty_chrome_redline"), "The red outline outlived its fighter") // REDLINE_FILTER
	TEST_ASSERT(!HAS_TRAIT(doomed, TRAIT_STUNIMMUNE), "Stun immunity outlived its fighter")

	// Deleted mid-burn
	var/mob/living/basic/bounty_criminal/normal/deleted = redliner(tile(1, 3))
	var/datum/bounty_chrome/redline/deleted_piece = bounty_chrome_piece(deleted, "redline")
	deleted.ai_start_fight(hunter)
	deleted.apply_damage(deleted.maxHealth * 0.45, BRUTE)
	roar_now(deleted_piece)
	var/obj/deleted_glow = deleted_piece.glow
	qdel(deleted)
	TEST_ASSERT_NULL(deleted_piece.owner, "The core kept its deleted fighter")
	TEST_ASSERT(QDELETED(deleted_piece), "The core outlived its fighter")
	TEST_ASSERT(QDELETED(deleted_glow), "The red glow outlived its deleted fighter")

/// A companion's burn ends in it giving up for good
/datum/unit_test/voidcrew_bounty_chrome_redline/companion

/datum/unit_test/voidcrew_bounty_chrome_redline/companion/Run()
	var/mob/living/basic/bounty_criminal/normal/criminal = allocate(/mob/living/basic/bounty_criminal/normal, tile(1, 1))
	var/list/buddies = criminal.spawn_companions(1)
	TEST_ASSERT(length(buddies), "No companion spawned")
	var/mob/living/basic/bounty_companion/buddy = buddies[1]
	bounty_chrome_install(buddy, list("redline")) // BOUNTY_CHROME_REDLINE
	var/datum/bounty_chrome/redline/piece = bounty_chrome_piece(buddy, "redline")

	// Not in a fight yet: hurt, nothing
	buddy.apply_damage(buddy.maxHealth * 0.45, BRUTE)
	TEST_ASSERT_EQUAL(piece.state, 0, "It tripped before the companion joined a fight") // REDLINE_IDLE
	buddy.setBruteLoss(0)
	buddy.ai_enter_fight()
	buddy.apply_damage(buddy.maxHealth * 0.45, BRUTE)
	TEST_ASSERT_EQUAL(piece.state, 1, "A companion's core didn't trip") // REDLINE_WINDING
	TEST_ASSERT(buddy.ai_flee_rolled, "A companion's run roll isn't held off")
	roar_now(piece)
	burn_out_now(piece)
	TEST_ASSERT(buddy.ai_gave_up, "Collapsed, the companion didn't give up")
	TEST_ASSERT(!buddy.ai_flee_rolled, "A companion's run roll wasn't put back")
	for(var/mob/living/basic/bounty_companion/leftover in buddies)
		qdel(leftover)

/// A mini-boss trips where it tires, its armour and the burn never go under the floor, and its collapse is the capture
/datum/unit_test/voidcrew_bounty_chrome_redline/boss

/datum/unit_test/voidcrew_bounty_chrome_redline/boss/Run()
	var/mob/living/basic/bounty_criminal/boss/pyromaniac/boss = allocate(/mob/living/basic/bounty_criminal/boss/pyromaniac, tile(1, 1))
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(3, 1))
	bounty_chrome_install(boss, list("redline")) // BOUNTY_CHROME_REDLINE
	var/datum/bounty_chrome/redline/piece = bounty_chrome_piece(boss, "redline")
	boss.boss_turn_hostile(hunter)
	TEST_ASSERT(bounty_chrome_fighting(boss), "The hostile boss isn't fighting")

	// Fresh, at half health: nothing, and stuns don't land on it anyway
	boss.adjustBruteLoss(boss.maxHealth * 0.5, forced = TRUE)
	TEST_ASSERT_EQUAL(piece.state, 0, "A fresh boss tripped at half health") // REDLINE_IDLE
	boss.Knockdown(2 SECONDS)
	TEST_ASSERT_EQUAL(piece.state, 0, "A knockdown that can't land on a fresh boss tripped it") // REDLINE_IDLE
	// Tired: it trips
	boss.adjustBruteLoss(boss.maxHealth * 0.15, forced = TRUE)
	TEST_ASSERT(boss.boss_tired, "The boss at 35% isn't tired")
	TEST_ASSERT_EQUAL(piece.state, 1, "The boss's core didn't trip as it tired") // REDLINE_WINDING
	roar_now(piece)
	var/list/mods = list()
	piece.modify_damage(mods, 10, BRUTE)
	TEST_ASSERT(length(mods), "The burn doesn't change the boss's damage")
	TEST_ASSERT(mods[1] * boss.damage_coeff[BRUTE] >= 0.499, "The boss's armour and the burn go under the floor") // REDLINE_DAMAGE_FLOOR
	burn_out_now(piece)
	TEST_ASSERT_NOTNULL(boss.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "The tired boss didn't collapse into stamina crit")
	TEST_ASSERT_EQUAL(boss.capture_state(), "stunned", "Collapsed, the boss doesn't count as stunned") // BOUNTY_STATE_STUNNED

	// Riot plates (only an admin can put the core in a Juggernaut): never under the floor
	var/mob/living/basic/bounty_criminal/boss/juggernaut/juggernaut = allocate(/mob/living/basic/bounty_criminal/boss/juggernaut, tile(1, 3))
	bounty_chrome_install(juggernaut, list("redline"))
	var/datum/bounty_chrome/redline/plated = bounty_chrome_piece(juggernaut, "redline")
	plated.state = 2 // REDLINE_BURNING
	for(var/damage_type in list(BRUTE, BURN))
		var/list/plated_mods = list()
		plated.modify_damage(plated_mods, 10, damage_type)
		TEST_ASSERT(plated_mods[1] * juggernaut.damage_coeff[damage_type] >= 0.499, "Riot plates and the burn go under the floor for [damage_type]") // REDLINE_DAMAGE_FLOOR
	plated.state = 0 // REDLINE_IDLE

/**
 * The owner's playtest, with real rounds: a criminal shot point-blank with a 9mm from full health.
 * The first round starts the fight; it trips a round or two in, while the fight is still young; the
 * rounds in the tell and the burn come in at half; and the burn gets several rounds of fight before
 * the downed line, where the mercy rule still holds. Two rounds land in the tell: one hunter's fire
 * over its 1.5 seconds.
 */
/datum/unit_test/voidcrew_bounty_chrome_redline/shot

/datum/unit_test/voidcrew_bounty_chrome_redline/shot/Run()
	var/mob/living/basic/bounty_criminal/normal/criminal = redliner(tile(1, 1))
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(2, 1))
	var/datum/bounty_chrome/redline/piece = bounty_chrome_piece(criminal, "redline")
	var/obj/projectile/bullet/c9mm/nine = /obj/projectile/bullet/c9mm
	var/round_damage = initial(nine.damage)
	var/list/fight = shoot_it_out(criminal, hunter, piece, /obj/projectile/bullet/c9mm)
	TEST_NOTICE(src, "Redline, 9mm from full health ([criminal.maxHealth]): [fight["trace"]]")
	TEST_ASSERT(fight["fighting"], "The first round didn't start the fight: [fight["trace"]]")
	TEST_ASSERT(fight["trip"] && fight["trip"] <= 2, "It tripped on round [fight["trip"]] at [fight["trip_percent"]]%, not by the second: [fight["trace"]]")
	TEST_ASSERT(fight["trip_percent"] >= 55, "It tripped at [fight["trip_percent"]]%, too late in the fight: [fight["trace"]]")
	var/list/resisted = fight["resisted"]
	TEST_ASSERT(length(resisted), "No round landed between the trip and the downed line: [fight["trace"]]")
	for(var/taken in resisted)
		TEST_ASSERT(abs(taken - round_damage * 0.5) < 0.5, "A 9mm round in the tell or the burn took [taken], not half of [round_damage]: [fight["trace"]]") // REDLINE_DAMAGE_MULT
	TEST_ASSERT(fight["after"] >= 4, "Only [fight["after"]] rounds after it tripped put them down: [fight["trace"]]")
	TEST_ASSERT(criminal.downed, "Twenty rounds didn't put them down: [fight["trace"]]")
	TEST_ASSERT(criminal.stat != DEAD, "A round killed them through the mercy line: [fight["trace"]]")
	TEST_ASSERT_EQUAL(piece.state, 0, "The burn went on after they went down") // REDLINE_IDLE

/**
 * Lasers into a companion, who has no mercy line: it trips as the fight turns, lasers in the tell and
 * the burn come in at half, and it lasts several more of them.
 */
/datum/unit_test/voidcrew_bounty_chrome_redline/laser_companion

/datum/unit_test/voidcrew_bounty_chrome_redline/laser_companion/Run()
	var/mob/living/basic/bounty_criminal/normal/criminal = allocate(/mob/living/basic/bounty_criminal/normal, tile(1, 1))
	var/list/buddies = criminal.spawn_companions(1)
	TEST_ASSERT(length(buddies), "No companion spawned")
	var/mob/living/basic/bounty_companion/buddy = buddies[1]
	buddy.forceMove(tile(1, 3))
	// A knife companion, BOUNTY_COMPANION_HEALTH 110, and nothing but the core
	buddy.ai_take_style("knife") // BOUNTY_STYLE_KNIFE
	qdel(buddy.GetComponent(/datum/component/bounty_chrome))
	bounty_chrome_install(buddy, list("redline")) // BOUNTY_CHROME_REDLINE
	var/datum/bounty_chrome/redline/piece = bounty_chrome_piece(buddy, "redline")
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(2, 3))
	var/obj/projectile/beam/laser/laser = /obj/projectile/beam/laser
	var/round_damage = initial(laser.damage)
	var/list/fight = shoot_it_out(buddy, hunter, piece, /obj/projectile/beam/laser)
	TEST_NOTICE(src, "Redline, lasers into a companion ([buddy.maxHealth]): [fight["trace"]]")
	TEST_ASSERT(fight["fighting"], "The first laser didn't bring the companion into the fight: [fight["trace"]]")
	TEST_ASSERT(fight["trip"] && fight["trip"] <= 2, "It tripped on laser [fight["trip"]], not by the second: [fight["trace"]]")
	var/list/resisted = fight["resisted"]
	TEST_ASSERT(length(resisted), "No laser landed between the trip and its death: [fight["trace"]]")
	for(var/taken in resisted)
		TEST_ASSERT(abs(taken - round_damage * 0.5) < 0.5, "A laser in the tell or the burn took [taken], not half of [round_damage]: [fight["trace"]]") // REDLINE_DAMAGE_MULT
	TEST_ASSERT(fight["after"] >= 4, "Only [fight["after"]] lasers after it tripped finished it: [fight["trace"]]")
	for(var/mob/living/basic/bounty_companion/leftover in buddies)
		qdel(leftover)

/**
 * Blows with a real knife. Hurt before the fight (they never saw it coming), the stab that starts the
 * fight trips it at once, since the fight starts only after that stab lands; stabs in the tell and the
 * burn then come in at half.
 */
/datum/unit_test/voidcrew_bounty_chrome_redline/melee

/datum/unit_test/voidcrew_bounty_chrome_redline/melee/Run()
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(2, 1))
	hunter.set_combat_mode(TRUE)
	var/obj/item/knife/kitchen/knife = locate() in hunter.held_items
	TEST_ASSERT_NOTNULL(knife, "The hunter has no knife")

	// Fresh: a stab out of the blue starts the fight, at full damage, and doesn't trip it
	var/mob/living/basic/bounty_criminal/normal/fresh = redliner(tile(1, 1))
	var/datum/bounty_chrome/redline/fresh_piece = bounty_chrome_piece(fresh, "redline")
	var/full = strike(hunter, fresh, knife)
	TEST_ASSERT(full > 0, "The knife did nothing")
	TEST_ASSERT(bounty_chrome_fighting(fresh), "A stab didn't start the fight")
	TEST_ASSERT_EQUAL(fresh_piece.state, 0, "One stab at full health tripped it") // REDLINE_IDLE

	// Hurt out of a fight, then stabbed: the fight starts with them badly hurt, and it trips
	var/mob/living/basic/bounty_criminal/normal/hurt = redliner(tile(1, 2))
	var/datum/bounty_chrome/redline/piece = bounty_chrome_piece(hurt, "redline")
	hunter.forceMove(tile(2, 2))
	hurt.apply_damage(hurt.maxHealth * 0.3, BRUTE)
	TEST_ASSERT_EQUAL(piece.state, 0, "It tripped out of a fight") // REDLINE_IDLE
	strike(hunter, hurt, knife)
	TEST_ASSERT(bounty_chrome_fighting(hurt), "The stab didn't start the fight")
	TEST_ASSERT_EQUAL(piece.state, 1, "A fight that started with them at [round(100 * hurt.health / hurt.maxHealth)]% didn't trip it") // REDLINE_WINDING
	var/in_tell = strike(hunter, hurt, knife)
	TEST_ASSERT(abs(in_tell - full * 0.5) < 0.1, "A stab in the tell took [in_tell], not half of [full]") // REDLINE_DAMAGE_MULT
	roar_now(piece)
	var/in_burn = strike(hunter, hurt, knife)
	TEST_ASSERT(abs(in_burn - full * 0.5) < 0.1, "A stab in the burn took [in_burn], not half of [full]") // REDLINE_DAMAGE_MULT
	piece.end_burn(collapse = FALSE)

/// A bare-chested pair of shorts, so the worn chest chrome shows
/datum/outfit/redline_render_shorts
	name = "Redline render: shorts"
	uniform = /obj/item/clothing/under/shorts/red
	shoes = /obj/item/clothing/shoes/sneakers/black

/**
 * Not a check: draws the worn core to data/bounty_chrome_renders/ for a person to look at. A dummy per
 * look, facing south, with and without the core.
 */
/datum/unit_test/voidcrew_bounty_chrome_redline/renders

/datum/unit_test/voidcrew_bounty_chrome_redline/renders/Run()
	var/list/looks = list(
		"shorts" = list(/datum/species/human, /datum/outfit/redline_render_shorts),
		"tough" = list(/datum/species/human, /datum/outfit/bounty_criminal/tough),
		"lizard_survivor" = list(/datum/species/lizard, /datum/outfit/hermit/survivor),
	)
	for(var/look_name in looks)
		var/list/spec = looks[look_name]
		var/datum/bounty_look/look = bounty_roll_look(spec[1], MALE)
		for(var/with_chrome in list(TRUE, FALSE))
			var/mob/living/carbon/human/dummy/dummy = bounty_look_dummy(look, spec[2], null, chrome_organs = with_chrome ? bounty_chrome_organ_looks(list("redline")) : null)
			TEST_ASSERT(dummy, "The [look_name] look could not be built")
			if(!dummy)
				continue
			if(with_chrome)
				TEST_ASSERT_NOTNULL(locate(/obj/item/organ/cyberimp/cyberware/redline) in dummy.organs, "The core isn't in the [look_name] dummy")
			dummy.setDir(SOUTH)
			fcopy(getFlatIcon(dummy, SOUTH), "data/bounty_chrome_renders/redline_[look_name][with_chrome ? "" : "_plain"].png")
			qdel(dummy)
