/**
 * The cyberpsycho (voidcrew/modules/bounties/chrome/bounty_cyberpsycho.dm): where it sits among the kits,
 * its chrome (the real implants, every one that fits, nothing browned out), its rotation, its Redline phase
 * two against damage and against stamina weapons, Lazarus, an EMP, death, and the Bounty Panel.
 *
 * Real human NPCs with the real implants in them; the tests read tg's own state. The AI is switched off,
 * so the tests drive the boss's procs and nothing else happens in between; timers run as they would. Fork
 * defines are included after the tests, so a test uses the literal value with a comment naming the define.
 * The test room is 5x5.
 *
 * Renders: compile with -DBOUNTY_CHROME_RENDERS and the renders test writes flat icons to
 * data/bounty_chrome_renders/ (cyberpsycho_<state>_<dir>.png).
 */
/datum/unit_test/voidcrew_bounty_cyberpsycho
	abstract_type = /datum/unit_test/voidcrew_bounty_cyberpsycho

/// The floor tile `dx`, `dy` from the room's bottom left
/datum/unit_test/voidcrew_bounty_cyberpsycho/proc/tile(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// A hunter at `where`: a human with a mind, as a player would be
/datum/unit_test/voidcrew_bounty_cyberpsycho/proc/hunter_at(turf/where)
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, where)
	hunter.mind_initialize()
	return hunter

/// A Most Wanted cyberpsycho's record, of `species`
/datum/unit_test/voidcrew_bounty_cyberpsycho/proc/psycho_record(species = /datum/species/human)
	var/datum/bounty_record/record = generate_bounty_record(3, "boss", "planet", species) // BOUNTY_TIER_MOST_WANTED, BOUNTY_ARCHETYPE_BOSS, BOUNTY_PLACEMENT_PLANET
	record.kit = "cyberpsycho" // BOUNTY_KIT_CYBERPSYCHO
	record.chrome = null
	return record

/// A cyberpsycho at `where`, spawned as the board spawns one, its AI off; with `hunter`, turned on them (on its grudge list, in its posse, its target)
/datum/unit_test/voidcrew_bounty_cyberpsycho/proc/psycho_at(turf/where, mob/living/hunter)
	var/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/psycho = spawn_bounty_criminal(psycho_record(), where, null)
	if(!psycho)
		return null
	allocated += psycho
	psycho.ai_controller?.set_ai_status(AI_STATUS_OFF)
	if(hunter)
		psycho.body_add_grudge(hunter)
		psycho.boss_turn_hostile(hunter)
		psycho.ai_controller?.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, hunter)
		var/datum/component/bounty_chrome/chrome = psycho.GetComponent(/datum/component/bounty_chrome)
		chrome?.update_fight()
	return psycho

/// The organ types of the chrome in `body`
/datum/unit_test/voidcrew_bounty_cyberpsycho/proc/chrome_in(mob/living/carbon/body)
	. = list()
	for(var/obj/item/organ/organ in body.organs)
		if(organ.GetComponent(/datum/component/cyberware))
			. += organ.type

/// Its ability running `move_type`, if it has one
/datum/unit_test/voidcrew_bounty_cyberpsycho/proc/ability_for(mob/living/carbon/human/npc/bounty_criminal/boss/boss, move_type)
	for(var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/ability in boss.boss_abilities)
		if(istype(ability.move, move_type))
			return ability
	return null

/// Ready for another move straight away: no gap, no ability cooldowns, hands free to click
/datum/unit_test/voidcrew_bounty_cyberpsycho/proc/ready(mob/living/carbon/human/npc/bounty_criminal/boss/boss)
	boss.boss_next_ability_at = 0
	boss.next_move = 0
	boss.next_click = 0
	for(var/datum/action/cooldown/ability as anything in boss.boss_abilities)
		ability.next_use_time = 0

/// Puts out its blade, as its chrome does on a Life tick in its fight
/datum/unit_test/voidcrew_bounty_cyberpsycho/proc/blade_out(mob/living/carbon/human/npc/bounty_criminal/boss/boss, atom/target)
	var/datum/component/bounty_chrome/chrome = boss.GetComponent(/datum/component/bounty_chrome)
	var/datum/bounty_chrome_move/mantis_blades/blades = chrome?.move_of(/datum/bounty_chrome_move/mantis_blades)
	blades?.on_tick(2, TRUE, target)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = locate() in boss.organs
	return housing?.blade_extended()

// ===== WHERE IT SITS =====

/**
 * Where it sits: a kit like the others, the rarest; its record rolls no chrome on top (its kit is its
 * chrome); its card's lines, its alias, the Bounty Panel's kit list and its prison riot move are a kit's.
 */
/datum/unit_test/voidcrew_bounty_cyberpsycho/kit

/datum/unit_test/voidcrew_bounty_cyberpsycho/kit/Run()
	var/list/counts = list()
	for(var/i in 1 to 2000)
		var/kit = bounty_roll_kit()
		counts[kit] = (counts[kit] || 0) + 1
	TEST_ASSERT(counts["cyberpsycho"] > 0, "The cyberpsycho never rolled as a kit")
	for(var/kit in list("juggernaut", "pyromaniac", "demolitionist", "ghost", "heavy")) // BOUNTY_KIT_*
		TEST_ASSERT(counts["cyberpsycho"] < counts[kit], "The cyberpsycho ([counts["cyberpsycho"]]) rolled as often as the [kit] ([counts[kit]])")
	var/datum/bounty_record/record = psycho_record()
	TEST_ASSERT_EQUAL(bounty_criminal_type(record, null), /mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho, "A cyberpsycho record spawns the wrong type")
	TEST_ASSERT_EQUAL(bounty_boss_move_type(record), /datum/prison_boss_move/charge, "A caught cyberpsycho's riot move is [bounty_boss_move_type(record)]")
	for(var/i in 1 to 100)
		TEST_ASSERT_NULL(bounty_chrome_roll(3, "boss", null, "cyberpsycho", bounty_chrome_kit_organs("cyberpsycho")), "A cyberpsycho's record rolled chrome on top of its own")
	var/list/lines = bounty_identity_strings("lines")
	for(var/context in list("intro", "ability", "redline", "exhausted", "posse", "cover"))
		TEST_ASSERT(length(lines["cyberpsycho_[context]"]?["any"]) >= 6, "The cyberpsycho has fewer than 6 [context] lines")
	var/list/aliases = bounty_identity_strings("aliases")
	TEST_ASSERT(length(aliases["cyberpsycho"]) >= 5, "The cyberpsycho has too few aliases")
	var/datum/bounty_admin_panel/panel = allocate(/datum/bounty_admin_panel, null)
	TEST_ASSERT_EQUAL(panel.kit_choices()["Cyberpsycho"], "cyberpsycho", "The Bounty Panel doesn't offer the cyberpsycho")

// ===== ITS CHROME =====

/**
 * Its chrome: the six real implants that fit one body, Cascade left out for Redline's operating-system slot,
 * Mantis in the right arm and Gorilla in the left; the kit's chrome as the rolls know it; its load over a
 * body's 20 with its Redline core carrying the Governor's 15 of capacity through the real hook, so nothing
 * browns out. Its rotation is the burn, the lunge, the leap and the piston punch, each told for at least
 * 0.8 s. It dresses to show the chrome, and seals up like any mini-boss in the void.
 */
/datum/unit_test/voidcrew_bounty_cyberpsycho/chrome

/datum/unit_test/voidcrew_bounty_cyberpsycho/chrome/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/psycho = psycho_at(tile(2, 2))
	TEST_ASSERT(istype(psycho), "No cyberpsycho spawned")
	TEST_ASSERT_EQUAL(psycho.boss_kit, "cyberpsycho", "The cyberpsycho has the kit [psycho.boss_kit]")
	var/list/carried = chrome_in(psycho)
	var/list/expected = list(
		/obj/item/organ/cyberimp/cyberware/redline,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis,
		/obj/item/organ/cyberimp/cyberware/gorilla_arms/left,
		/obj/item/organ/cyberimp/cyberware/piledriver,
		/obj/item/organ/cyberimp/cyberware/lazarus,
		/obj/item/organ/eyes/robotic/cyberware/deadeye,
	)
	TEST_ASSERT_EQUAL(length(carried), length(expected), "The cyberpsycho carries [length(carried)] pieces of chrome: [jointext(carried, ", ")]")
	for(var/organ_type in expected)
		TEST_ASSERT(organ_type in carried, "The cyberpsycho doesn't carry [organ_type]")
	var/list/known = bounty_chrome_kit_organs("cyberpsycho")
	TEST_ASSERT_EQUAL(length(known), length(carried), "The rolls know of [length(known)] of its pieces")
	for(var/organ_type in known)
		TEST_ASSERT(organ_type in carried, "The rolls fit around [organ_type], which the cyberpsycho doesn't carry")
	TEST_ASSERT_NULL(locate(/obj/item/organ/cyberimp/cyberware/cascade) in psycho.organs, "The cyberpsycho has a Cascade lattice beside its Redline core")
	TEST_ASSERT_NULL(psycho.record.chrome, "The cyberpsycho's record lists rolled chrome")
	TEST_ASSERT_NULL(locate(/obj/item/organ/eyes) in get_turf(psycho), "The eyes it was born with lie on the floor")

	// The real capacity: 32 load in a body that holds 35, its Redline core carrying the extra
	TEST_ASSERT_EQUAL(get_chrome_load(psycho), 32, "The cyberpsycho's chrome loads it [get_chrome_load(psycho)]")
	TEST_ASSERT_EQUAL(get_chrome_capacity(psycho), 35, "The cyberpsycho's body holds [get_chrome_capacity(psycho)]") // CYBERWARE_BASE_CAPACITY + BOUNTY_PSYCHO_EXTRA_CAPACITY
	var/obj/item/organ/core = locate(/obj/item/organ/cyberimp/cyberware/redline) in psycho.organs
	var/datum/component/cyberware/core_ware = core?.GetComponent(/datum/component/cyberware)
	TEST_ASSERT_EQUAL(core_ware?.capacity_bonus, 15, "Its Redline core doesn't carry the Governor's capacity") // BOUNTY_PSYCHO_EXTRA_CAPACITY
	for(var/obj/item/organ/organ in psycho.organs)
		var/datum/component/cyberware/ware = organ.GetComponent(/datum/component/cyberware)
		if(!ware)
			continue
		TEST_ASSERT(!ware.browned_out, "The cyberpsycho's [organ] browned out")
		TEST_ASSERT(ware.is_running(), "The cyberpsycho's [organ] isn't running")

	// Its chrome AI, and its rotation: four moves, all told
	var/datum/component/bounty_chrome/chrome = psycho.GetComponent(/datum/component/bounty_chrome)
	TEST_ASSERT_NOTNULL(chrome, "The cyberpsycho has no chrome AI")
	for(var/key in list("redline", "mantis", "gorilla", "piledriver", "lazarus", "deadeye")) // BOUNTY_CHROME_*
		TEST_ASSERT(key in chrome.keys, "The cyberpsycho's chrome AI doesn't know its [key]")
	var/list/moves = list(
		/datum/bounty_chrome_move/redline,
		/datum/bounty_chrome_move/mantis_lunge,
		/datum/bounty_chrome_move/piledriver,
		/datum/bounty_chrome_move/gorilla_punch/psycho,
	)
	TEST_ASSERT_EQUAL(length(psycho.boss_abilities), length(moves), "The cyberpsycho has [length(psycho.boss_abilities)] abilities, not its four moves")
	for(var/move_type in moves)
		var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/ability = ability_for(psycho, move_type)
		TEST_ASSERT_NOTNULL(ability, "The cyberpsycho's [move_type] isn't in its rotation")
		TEST_ASSERT(ability?.windup >= 0.8 SECONDS, "The cyberpsycho's [move_type] tells for [ability?.windup / 10] s") // BOUNTY_CHROME_TELL_MIN
		TEST_ASSERT(!length(ability?.move?.tell_lines), "The cyberpsycho's [move_type] has its own lines besides the cyberpsycho's")
	var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/burn = ability_for(psycho, /datum/bounty_chrome_move/redline)
	TEST_ASSERT(istype(burn?.move, /datum/bounty_chrome_move/redline/psycho), "Its Redline isn't its phase two: [burn?.move?.type]")
	var/count = 0
	for(var/datum/bounty_chrome_move/redline/move in chrome.moves)
		count++
	TEST_ASSERT_EQUAL(count, 1, "It has [count] Redline moves, not its own one")

	// Dressed to show it: shorts and boots, nothing on its arms or chest
	TEST_ASSERT(psycho.bounty_dresses_to_show_chrome(), "The cyberpsycho dresses to hide its chrome")
	TEST_ASSERT(istype(psycho.w_uniform, /obj/item/clothing/under/shorts), "The cyberpsycho wears [psycho.w_uniform] over its legs")
	TEST_ASSERT_NULL(psycho.wear_suit, "The cyberpsycho wears [psycho.wear_suit] over its chrome")
	TEST_ASSERT_NULL(psycho.gloves, "The cyberpsycho wears gloves over its arms")
	TEST_ASSERT(psycho.boss_gear_text(), "The cyberpsycho has no gear line on examine")
	// Its two stimulants and a bruise pack, as every mini-boss, where it can reach them; no bag over its spine rig
	TEST_ASSERT_EQUAL(length(psycho.get_all_contents_type(/obj/item/reagent_containers/hypospray/medipen/stimpack)) - length(psycho.get_all_contents_type(/obj/item/reagent_containers/hypospray/medipen/stimpack/traitor)), 2, "The cyberpsycho doesn't carry its two stimulants") // BOUNTY_BOSS_STIMULANTS
	// Its combat stimpack rides in a pocket, the bum bag being full (BOUNTY_BOSS_COMBAT_STIMULANT)
	var/obj/item/combat_pen = locate(/obj/item/reagent_containers/hypospray/medipen/stimpack/traitor) in list(psycho.l_store, psycho.r_store)
	TEST_ASSERT_NOTNULL(combat_pen, "The cyberpsycho has no combat stimpack in a pocket")
	TEST_ASSERT_EQUAL(length(psycho.get_all_contents_type(/obj/item/reagent_containers/hypospray/medipen/stimpack/traitor)), 1, "The cyberpsycho doesn't carry one combat stimpack")
	TEST_ASSERT(human_npc_gear_consumable(combat_pen), "The cyberpsycho's combat stimpack isn't issued to it")
	TEST_ASSERT(length(psycho.get_all_contents_type(/obj/item/stack/medical/bruise_pack)), "The cyberpsycho carries nothing to patch itself up with")
	TEST_ASSERT_NOTNULL(bounty_ai_find_injector(psycho, /obj/item/reagent_containers/hypospray/medipen/stimpack), "The cyberpsycho can't reach its stimulants")
	TEST_ASSERT_NULL(psycho.back, "The cyberpsycho wears [psycho.back] over its spine rig")
	// In the void, a civilian MODsuit: it wears no armour in good air either
	var/list/gear = bounty_vacuum_gear(psycho)
	TEST_ASSERT(length(gear) == 1 && gear[1] == /obj/item/mod/control/pre_equipped/bounty_boss/civilian, "The cyberpsycho's void suit isn't a civilian MODsuit: [jointext(gear, ", ")]")

	// Dead, its chrome burns out to scrap, all six pieces
	var/turf/here = get_turf(psycho)
	psycho.death()
	TEST_ASSERT_EQUAL(length(chrome_in(psycho)), 0, "A dead cyberpsycho still carries working chrome")
	var/scrap = 0
	for(var/obj/item/burnt_chrome/burnt in here)
		scrap++
	TEST_ASSERT_EQUAL(scrap, 6, "A dead cyberpsycho's six implants left [scrap] pieces of scrap")

// ===== ONE MOVE AT A TIME =====

/**
 * The blade comes out of its right forearm in a fight and is its melee; its left hand, the Gorilla fist,
 * stays empty, so it can punch through glass (C5). The piston punch is a told move: the arm's own punch
 * lands only after the tell. While one move winds up, no other starts.
 */
/datum/unit_test/voidcrew_bounty_cyberpsycho/rotation

/datum/unit_test/voidcrew_bounty_cyberpsycho/rotation/Run()
	var/mob/living/carbon/human/hunter = hunter_at(tile(3, 2))
	var/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/psycho = psycho_at(tile(2, 2), hunter)
	TEST_ASSERT(istype(psycho), "No cyberpsycho spawned")
	TEST_ASSERT(psycho.boss_hostile, "The cyberpsycho didn't turn on the hunter")
	TEST_ASSERT(blade_out(psycho, hunter), "The cyberpsycho's blade didn't come out in its fight")
	var/obj/item/blade = psycho.get_item_for_held_index(RIGHT_HANDS)
	TEST_ASSERT(istype(blade, /obj/item/melee/energy/blade/hardlight/cyberware_mantis), "The blade isn't in its right hand: [blade]")
	TEST_ASSERT_NULL(psycho.get_item_for_held_index(LEFT_HANDS), "Its Gorilla hand holds [psycho.get_item_for_held_index(LEFT_HANDS)]")
	TEST_ASSERT_EQUAL(human_npc_held_melee_weapon(psycho), blade, "Its melee isn't its blade")
	TEST_ASSERT(psycho.boss_has_gorilla_fist(), "It has no Gorilla fist free to punch through glass with")

	// The piston punch, through its rotation: the tell, then the arm's own punch
	ready(psycho)
	var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/punch = ability_for(psycho, /datum/bounty_chrome_move/gorilla_punch/psycho)
	TEST_ASSERT(punch.worth_using(hunter), "The piston punch isn't worth using on a hunter beside it")
	TEST_ASSERT(punch.Trigger(target = hunter), "The piston punch wouldn't start")
	TEST_ASSERT_EQUAL(psycho.boss_busy, "windup", "The piston punch doesn't wind up")
	TEST_ASSERT_NOTNULL(psycho.get_filter(punch.move.tell_filter()), "The piston punch's tell has no outline")
	// One at a time: nothing else starts while it winds up
	for(var/datum/action/cooldown/mob_cooldown/bounty_boss/ability as anything in psycho.boss_abilities)
		ability.next_use_time = 0
	TEST_ASSERT_NULL(psycho.boss_choose_ability(hunter), "Another move would start while the piston punch winds up")
	TEST_ASSERT_EQUAL(hunter.getBruteLoss(), 0, "The punch landed before its tell")
	sleep(1 SECONDS)
	TEST_ASSERT(hunter.getBruteLoss() >= 15, "The piston punch did [hunter.getBruteLoss()] brute, not the implant's") // CYBERWARE_GORILLA_PUNCH_DAMAGE
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm = locate() in psycho.organs
	TEST_ASSERT(!bounty_gorilla_loaded(arm), "The punch wasn't the Gorilla arm's own")
	TEST_ASSERT_NULL(psycho.boss_busy, "Still busy after the punch")
	TEST_ASSERT(world.time < psycho.boss_next_ability_at, "No gap after the punch before its next move")

// ===== ITS PHASE TWO =====

/**
 * A stamina weapon is answered with its Redline: one disabler bolt's worth and, a moment later, the burn's
 * tell starts, cutting short whatever it was winding up. It doesn't wear out while its phase two is to
 * come. After the tell, the implant's burn: stun-proof, so more stamina doesn't floor it, and still not worn
 * out; then the crash floors it in stamina crit, the capture. Once: it never burns again.
 */
/datum/unit_test/voidcrew_bounty_cyberpsycho/burn_stamina

/datum/unit_test/voidcrew_bounty_cyberpsycho/burn_stamina/Run()
	var/mob/living/carbon/human/hunter = hunter_at(tile(4, 2))
	var/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/psycho = psycho_at(tile(1, 2), hunter)
	TEST_ASSERT(istype(psycho), "No cyberpsycho spawned")
	TEST_ASSERT(blade_out(psycho, hunter), "The cyberpsycho's blade didn't come out")
	ready(psycho)
	var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/burn = ability_for(psycho, /datum/bounty_chrome_move/redline)
	var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/lunge = ability_for(psycho, /datum/bounty_chrome_move/mantis_lunge)
	TEST_ASSERT(!burn.worth_using(hunter), "An unhurt cyberpsycho reaches for its Redline")
	// Winding up a lunge when the bolt lands
	TEST_ASSERT(lunge.worth_using(hunter), "The lunge isn't worth using on a hunter three tiles off")
	TEST_ASSERT(lunge.Trigger(target = hunter), "The lunge wouldn't start")
	TEST_ASSERT_EQUAL(psycho.boss_winding(), lunge, "The lunge isn't winding up")
	psycho.apply_damage(30, STAMINA) // a disabler bolt
	TEST_ASSERT(!psycho.boss_is_worn_out(), "One bolt wore it out")
	sleep(0.2 SECONDS)
	TEST_ASSERT_EQUAL(psycho.boss_winding(), burn, "A stamina hit didn't start its Redline's tell")
	TEST_ASSERT(!lunge.pending_serial, "The lunge it was winding up still goes")
	psycho.adjustStaminaLoss(30)
	TEST_ASSERT(!psycho.boss_is_worn_out(), "Winded with its phase two to come, it wears out instead of burning")
	TEST_ASSERT_NULL(psycho.has_status_effect(/datum/status_effect/cyberware_redline_window), "The burn started before its tell was over")
	sleep(1.1 SECONDS)

	// The implant's own burn
	TEST_ASSERT_NOTNULL(psycho.has_status_effect(/datum/status_effect/cyberware_redline_window), "The tell ended but the implant's burn didn't start")
	TEST_ASSERT(psycho.psycho_burned, "Its phase two isn't spent")
	TEST_ASSERT(HAS_TRAIT(psycho, TRAIT_STUNIMMUNE), "The burn gives no stun immunity")
	psycho.apply_damage(60, STAMINA)
	TEST_ASSERT_NULL(psycho.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "Stamina floored it in the burn")
	TEST_ASSERT(!psycho.boss_is_worn_out(), "It wears out in the burn")
	TEST_ASSERT(!burn.worth_using(hunter), "It would burn again while burning")

	// The crash: stamina crit, the capture
	sleep(12.4 SECONDS)
	TEST_ASSERT_NULL(psycho.has_status_effect(/datum/status_effect/cyberware_redline_window), "The burn outlasted the implant's 12 seconds")
	TEST_ASSERT_NOTNULL(psycho.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "The crash didn't floor it in stamina crit")
	TEST_ASSERT_EQUAL(psycho.capture_state(), "stunned", "The crash isn't a stunned capture") // BOUNTY_STATE_STUNNED
	// Once a spawn: back on its feet and winded again, no second burn, and now it tires like any mini-boss
	psycho.remove_status_effect(/datum/status_effect/incapacitating/stamcrit)
	psycho.setStaminaLoss(70)
	burn.next_use_time = 0
	TEST_ASSERT(!burn.worth_using(hunter), "It would burn its Redline a second time")
	TEST_ASSERT(psycho.boss_is_worn_out(), "With its phase two spent, it doesn't tire")

/**
 * Damage sets it off too: hurt to three quarters of its health, it burns. Not with someone outside its
 * fight in the roar's reach (the bystander gate). An EMP in the tell fires nothing and takes its core
 * down, sparking; with its core down it tires like any mini-boss.
 */
/datum/unit_test/voidcrew_bounty_cyberpsycho/burn_hurt

/datum/unit_test/voidcrew_bounty_cyberpsycho/burn_hurt/Run()
	var/mob/living/carbon/human/hunter = hunter_at(tile(4, 2))
	var/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/psycho = psycho_at(tile(1, 2), hunter)
	TEST_ASSERT(istype(psycho), "No cyberpsycho spawned")
	ready(psycho)
	var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/burn = ability_for(psycho, /datum/bounty_chrome_move/redline)
	// A bystander in the roar's reach keeps it shut
	var/mob/living/carbon/human/bystander = hunter_at(tile(1, 4))
	psycho.adjustBruteLoss(30)
	TEST_ASSERT(psycho.psycho_hurt_enough(), "Hurt to [psycho.health] doesn't count")
	TEST_ASSERT(!burn.worth_using(hunter), "It burns with a bystander in the roar's reach")
	qdel(bystander)
	TEST_ASSERT(burn.worth_using(hunter), "Hurt to [psycho.health] in its fight, it won't burn")
	// Its own companion beside it doesn't keep it shut: a crew of hunters brings those in (C0's gate would)
	var/datum/human_npc_order/order = bounty_spawn_companion(psycho, tile(1, 3), null, TRUE, bounty_test_company_member("brawler", null)) // BOUNTY_STYLE_BRAWLER
	var/mob/living/carbon/human/npc/bounty_companion/buddy = order?.spawned_ref?.resolve()
	qdel(order)
	TEST_ASSERT_NOTNULL(buddy, "Test fixture: no companion was made")
	allocated += buddy
	buddy.ai_controller?.set_ai_status(AI_STATUS_OFF)
	TEST_ASSERT(bounty_ai_same_gang(psycho, buddy), "Test fixture: the companion isn't on its side")
	var/datum/bounty_chrome_move/redline/move = burn.move
	TEST_ASSERT(!bounty_chrome_area_clear(psycho, move.area_turfs(hunter), hunter), "Test fixture: C0's gate lets the roar go over its own companion")
	TEST_ASSERT(burn.worth_using(hunter), "Its own companion beside it keeps its phase two shut")
	TEST_ASSERT_EQUAL(psycho.boss_choose_ability(hunter), burn, "Its rotation doesn't put its phase two first")
	TEST_ASSERT(psycho.psycho_burn_now(), "The burn's tell didn't start")
	TEST_ASSERT_EQUAL(psycho.boss_winding(), burn, "The burn isn't winding up")

	// An EMP in the tell: nothing fires, its chrome sparks and reboots, and now it tires
	psycho.emp_act(EMP_HEAVY)
	TEST_ASSERT_NULL(psycho.boss_winding(), "An EMP didn't cut the burn's tell short")
	sleep(1.2 SECONDS)
	TEST_ASSERT_NULL(psycho.has_status_effect(/datum/status_effect/cyberware_redline_window), "It burned through an EMP in the tell")
	TEST_ASSERT(!psycho.psycho_burned, "An EMP'd tell spent its phase two")
	TEST_ASSERT_NOTNULL(psycho.has_status_effect(/datum/status_effect/bounty_chrome_malfunction), "Its chrome doesn't spark after the EMP")
	var/obj/item/organ/core = locate(/obj/item/organ/cyberimp/cyberware/redline) in psycho.organs
	var/datum/component/cyberware/core_ware = core?.GetComponent(/datum/component/cyberware)
	TEST_ASSERT(core_ware?.emp_down, "The EMP didn't take its core down")
	TEST_ASSERT(!psycho.psycho_burn_pending(), "With its core down, its phase two still waits")
	psycho.setStaminaLoss(70)
	TEST_ASSERT(psycho.boss_is_worn_out(), "With its core down, it doesn't tire")
	TEST_ASSERT_EQUAL(get_chrome_capacity(psycho), 35, "An EMP took its capacity away, browning its chrome out") // CYBERWARE_BASE_CAPACITY + BOUNTY_PSYCHO_EXTRA_CAPACITY

// ===== LAZARUS =====

/// Beaten into crit, the node's own jolt stands it up after its charge; down again in the same fight, it stays down
/datum/unit_test/voidcrew_bounty_cyberpsycho/lazarus

/datum/unit_test/voidcrew_bounty_cyberpsycho/lazarus/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/psycho = psycho_at(tile(2, 2))
	TEST_ASSERT(istype(psycho), "No cyberpsycho spawned")
	var/obj/item/organ/cyberimp/cyberware/lazarus/node = locate() in psycho.organs
	TEST_ASSERT_NOTNULL(node, "The cyberpsycho has no Lazarus node")
	for(var/i in 1 to 30)
		if(psycho.stat != CONSCIOUS)
			break
		psycho.adjustBruteLoss(10)
		psycho.updatehealth()
	TEST_ASSERT(psycho.is_downed(), "The beating didn't put it in crit (health [psycho.health])")
	TEST_ASSERT(node.jolting, "Going into crit didn't start the node's charge")
	sleep(1.3 SECONDS)
	TEST_ASSERT_EQUAL(psycho.stat, CONSCIOUS, "The node didn't stand it up (health [psycho.health])")
	for(var/i in 1 to 30)
		if(psycho.stat != CONSCIOUS)
			break
		psycho.adjustBruteLoss(10)
		psycho.updatehealth()
	TEST_ASSERT(psycho.is_downed(), "The second beating didn't put it in crit")
	sleep(1.3 SECONDS)
	TEST_ASSERT(psycho.is_downed(), "It got up a second time in one fight")

// ===== THE BOUNTY PANEL =====

/// The panel spawns one by its kit, and "All of it" is the cyberpsycho whatever archetype was picked
/datum/unit_test/voidcrew_bounty_cyberpsycho/admin

/datum/unit_test/voidcrew_bounty_cyberpsycho/admin/Run()
	var/mob/living/carbon/human/operator = allocate(/mob/living/carbon/human/consistent, tile(4, 4))
	var/datum/bounty_admin_panel/unit_test/panel = allocate(/datum/bounty_admin_panel/unit_test, operator)
	var/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/spawned = panel.admin_spawn_criminal(operator, 3, "boss", "cyberpsycho", null, tile(1, 1), "roll") // BOUNTY_ADMIN_CHROME_ROLL
	allocated += spawned
	TEST_ASSERT(istype(spawned), "The panel's cyberpsycho spawned as [spawned?.type]: [panel.error]")
	TEST_ASSERT_EQUAL(length(chrome_in(spawned)), 6, "The panel's cyberpsycho carries [length(chrome_in(spawned))] pieces")
	TEST_ASSERT_NULL(spawned?.record?.chrome, "Rolled as usual, the cyberpsycho rolled chrome on top of its own")
	var/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/all = panel.admin_spawn_criminal(operator, 3, "normal", "brawler", null, tile(3, 1), "all") // BOUNTY_ADMIN_CHROME_ALL
	allocated += all
	TEST_ASSERT(istype(all), "All of it spawned [all?.type], not the cyberpsycho")
	TEST_ASSERT_EQUAL(all?.record?.archetype, "boss", "All of it's record isn't a mini-boss's") // BOUNTY_ARCHETYPE_BOSS
	TEST_ASSERT_NULL(all?.record?.style, "All of it kept a fighting style")
	TEST_ASSERT_EQUAL(length(chrome_in(all)), 6, "All of it carries [length(chrome_in(all))] pieces")
	TEST_ASSERT(!panel.said("didn't fit"), "The admin was told some of it didn't fit")

// ===== RENDERS =====

/// Not a check: with -DBOUNTY_CHROME_RENDERS, writes the cyberpsycho as spawned and with its blade out, every way it faces
/datum/unit_test/voidcrew_bounty_cyberpsycho/renders

/datum/unit_test/voidcrew_bounty_cyberpsycho/renders/Run()
#ifdef BOUNTY_CHROME_RENDERS
	var/mob/living/carbon/human/hunter = hunter_at(tile(4, 4))
	for(var/datum/species/kind as anything in list(/datum/species/human, /datum/species/lizard, /datum/species/moth))
		var/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/psycho = spawn_bounty_criminal(psycho_record(kind), tile(2, 2), null)
		allocated += psycho
		psycho.ai_controller?.set_ai_status(AI_STATUS_OFF)
		var/name = "[initial(kind.id)]"
		for(var/facing in list(SOUTH, EAST, NORTH, WEST))
			fcopy(getFlatIcon(psycho, facing, no_anim = TRUE), "data/bounty_chrome_renders/cyberpsycho_[name]_[dir2text(facing)].png")
		psycho.body_add_grudge(hunter)
		psycho.boss_turn_hostile(hunter)
		blade_out(psycho, hunter)
		for(var/facing in list(SOUTH, EAST, NORTH, WEST))
			fcopy(getFlatIcon(psycho, facing, no_anim = TRUE), "data/bounty_chrome_renders/cyberpsycho_[name]_blade_[dir2text(facing)].png")
		qdel(psycho)
#endif
