/**
 * # Bounty hunting: the cyberpsycho
 *
 * Owner: C6. A mini-boss kit (BOUNTY_KIT_CYBERPSYCHO) whose kit is its chrome, the rarest of the kits
 * (bounty_roll_kit()). Everything but its fight is any mini-boss's: the Most Wanted posting and pay, its
 * stimulants, a sealed suit where the air would kill it, capture, and in prison the Juggernaut's charge
 * (its chrome stays out of prison, decision 7).
 *
 * Its chrome is the real implants (decisions 4 and 5), as many of the seven pieces as one body's organ
 * slots take. Six go in, in this order (bounty_psycho_organs()):
 * - the Redline core in the operating-system slot. The Cascade lattice needs the same slot; Redline is
 *   its phase two, so the lattice is the piece left out;
 * - a Mantis Blade housing in its right arm and Gorilla Arms in its left, one of each pair;
 * - the Meteor Piledriver in its legs, a Lazarus node by its heart, and Deadeye optics for eyes.
 * Their load is 32 (10 + 3 + 3 + 8 + 5 + 3), over a body's 20. It is augmented beyond anyone else: its
 * Redline core carries the Governor Delete's capacity (BOUNTY_PSYCHO_EXTRA_CAPACITY) through the real
 * capacity hook, the cyberware component's capacity_bonus, which get_chrome_capacity(), the brownout
 * monitor, the cradle and a chrome read all go by. It is set on the core as the core goes in, first, so
 * nothing browns out on the way. Chrome taken out of it burns to scrap (the human NPC base), so no core
 * with that headroom ever leaves its body.
 *
 * How it fights, through the boss rotation (bounty_boss.dm), one move at a time and each with its tell:
 * - its blade is out of its right forearm while it fights, and its melee is that blade (Mantis Blades);
 * - the Mantis Lunge down a lit line, the Meteor Leap under a reticle, and a piston punch with its Gorilla
 *   fist (C2's told punch, put in its rotation here, since its melee is the blade);
 * - its Gorilla hand stays empty, so it can punch through glass it may break (boss_start_smash());
 * - the Redline is its phase two (psycho_burn_due()): hurt to BOUNTY_PSYCHO_BURN_HURT percent of its
 *   health, or winded by a stamina weapon (BOUNTY_PSYCHO_BURN_WINDED), it drops what it was winding up
 *   and burns: C3's tell, then the implant's stun-proof window, then its crash into stamina crit, which is
 *   the capture. Once a spawn. Until then it doesn't wear out and fall back; it burns instead. Its roar
 *   holds off for people outside its fight, never for its own companions (psycho_roar_clear());
 * - Lazarus stands it up out of crit by itself, the node's own jolt; its six minute recharge outlasts a
 *   fight;
 * - the Deadeye optics are only its eyes: it carries no gun for the tag to steer.
 * An EMP takes its chrome down on the real reboot timers, sparking (C0's malfunction look); one during the
 * burn crashes it, and with its core down it tires like any other mini-boss.
 */

/// Neural capacity its Redline core carries: the Governor Delete's (its chrome_capacity_bonus, ware_legend.dm)
#define BOUNTY_PSYCHO_EXTRA_CAPACITY 15
/// Hurt to this percent of its health, it burns its Redline (C3's line for any carrier)
#define BOUNTY_PSYCHO_BURN_HURT 75
/// Winded this far (stamina loss), it burns too: one disabler bolt or baton blow, so a stamina weapon gets an answer before the floor
#define BOUNTY_PSYCHO_BURN_WINDED 25

/// The cyberpsycho's chrome as organ typepaths, in the order they go in: the Redline core first, as it carries the headroom for the rest
/proc/bounty_psycho_organs()
	return list(
		/obj/item/organ/cyberimp/cyberware/redline,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis,
		/obj/item/organ/cyberimp/cyberware/gorilla_arms/left,
		/obj/item/organ/cyberimp/cyberware/piledriver,
		/obj/item/organ/cyberimp/cyberware/lazarus,
		/obj/item/organ/eyes/robotic/cyberware/deadeye,
	)

/// The pieces (BOUNTY_CHROME_*) its chrome AI drives: every one but the Cascade lattice
/proc/bounty_psycho_keys()
	return list(BOUNTY_CHROME_REDLINE, BOUNTY_CHROME_MANTIS, BOUNTY_CHROME_GORILLA, BOUNTY_CHROME_PILEDRIVER, BOUNTY_CHROME_LAZARUS, BOUNTY_CHROME_DEADEYE)

// ===== THE BOSS =====

/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho
	name = "chromed criminal"
	desc = "A twitching criminal with more chrome than skin."
	boss_kit = BOUNTY_KIT_CYBERPSYCHO
	/// Its Redline has burned once: its phase two is spent
	var/psycho_burned = FALSE

/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/Initialize(mapload, datum/human_npc_order/order)
	// Its kit is its chrome: the base installs it once it is dressed
	npc_cyberware = bounty_psycho_organs()
	. = ..()
	psycho_wire_chrome()
	RegisterSignal(src, SIGNAL_ADDTRAIT(TRAIT_STUNIMMUNE), PROC_REF(psycho_burn_started))
	RegisterSignal(src, SIGNAL_REMOVETRAIT(TRAIT_STUNIMMUNE), PROC_REF(psycho_burn_ended))

// Its Redline core goes in first, with the headroom the rest of its chrome needs
/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/npc_install_cyberware(ware_type)
	var/obj/item/organ/ware = ..()
	if(istype(ware, /obj/item/organ/cyberimp/cyberware/redline))
		var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
		if(chrome && !chrome.capacity_bonus)
			chrome.capacity_bonus = BOUNTY_PSYCHO_EXTRA_CAPACITY
			cyberware_reevaluate_brownout(src)
	return ware

/**
 * Its chrome's AI, once the implants are in (C0's bounty_chrome_equip()): every piece's moves, and its
 * rotation set to what this body can do. Its own lines say what is coming (boss_bark()), not each move's.
 * Its Redline is its own move (/datum/bounty_chrome_move/redline/psycho), its phase two, in place of the
 * one every carrier gets, and its Gorilla fist gets the piston punch. The Gorilla grab needs two Gorilla
 * fists and the Deadeye tag a gun, and it has neither, so they stay out of its rotation.
 */
/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/proc/psycho_wire_chrome()
	var/datum/component/bounty_chrome/chrome = bounty_chrome_equip(src, bounty_psycho_keys())
	if(!chrome)
		return
	for(var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/unused in boss_abilities.Copy())
		if(istype(unused.move, /datum/bounty_chrome_move/redline) || istype(unused.move, /datum/bounty_chrome_move/gorilla_grab) || istype(unused.move, /datum/bounty_chrome_move/deadeye))
			boss_abilities -= unused
			qdel(unused)
	var/datum/bounty_chrome_move/redline/plain = chrome.move_of(/datum/bounty_chrome_move/redline)
	if(plain)
		chrome.moves -= plain
		plain.detach()
		qdel(plain)
	psycho_add_move(chrome, /datum/bounty_chrome_move/redline/psycho)
	psycho_add_move(chrome, /datum/bounty_chrome_move/gorilla_punch/psycho)
	for(var/datum/bounty_chrome_move/move as anything in chrome.moves)
		move.tell_lines = null

/// Adds a move of `move_type` to its chrome AI `chrome`, as a move in its rotation (C0's adaptor). Returns the move.
/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/proc/psycho_add_move(datum/component/bounty_chrome/chrome, move_type)
	var/datum/bounty_chrome_move/move = new move_type
	chrome.moves += move
	move.attach(src)
	var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/ability = new(src)
	ability.set_move(move)
	ability.Grant(src)
	boss_abilities += ability
	return move

/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/bounty_build_outfit(zone)
	return boss_supplies(bounty_outfit_instance(/datum/outfit/bounty_boss/cyberpsycho))

// No bag over its spine rig: its stimulants and bruise pack ride in a bum bag, where it reaches them as any boss reaches its bag. The bag holds three, so its combat stimpack rides in a pocket.
/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/boss_supplies(datum/outfit/outfit)
	if(!istype(outfit))
		return outfit
	outfit.belt = /obj/item/storage/belt/fannypack/black
	LAZYINITLIST(outfit.belt_contents)
	outfit.belt_contents[BOUNTY_BOSS_STIMULANT] = BOUNTY_BOSS_STIMULANTS
	outfit.belt_contents[/obj/item/stack/medical/bruise_pack] = 1
	if(isnull(outfit.l_pocket))
		outfit.l_pocket = BOUNTY_BOSS_COMBAT_STIMULANT
	else if(isnull(outfit.r_pocket))
		outfit.r_pocket = BOUNTY_BOSS_COMBAT_STIMULANT
	return outfit

// Its chrome is its kit: it dresses to show it (C0's bounty_chrome_expose_outfit())
/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/bounty_dresses_to_show_chrome()
	return TRUE

/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/boss_gear_text()
	return "[p_They()] can't keep still, and there's more chrome on [p_them()] than skin."

/// Shorts and boots: its arms, chest and legs are chrome, and they show
/datum/outfit/bounty_boss/cyberpsycho
	name = "Bounty mini-boss: Cyberpsycho"
	uniform = /obj/item/clothing/under/shorts/black
	gloves = null

// ----- its phase two -----

/// Its Redline core, if it is in it
/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/proc/psycho_core()
	return locate(/obj/item/organ/cyberimp/cyberware/redline) in organs

/// Its Redline in its rotation, if it has one
/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/proc/psycho_burn_ability()
	var/datum/component/bounty_chrome/chrome = GetComponent(/datum/component/bounty_chrome)
	var/datum/bounty_chrome_move/redline/psycho/burn = chrome?.move_of(/datum/bounty_chrome_move/redline/psycho)
	return burn?.boss_ability

/// Whether its phase two is still to come: it has never burned, and its Redline core is in it and running (an EMP or a brownout puts that off)
/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/proc/psycho_burn_pending()
	if(psycho_burned)
		return FALSE
	var/obj/item/organ/core = psycho_core()
	var/datum/component/cyberware/ware = core?.GetComponent(/datum/component/cyberware)
	return !!ware?.is_running()

/// Hurt or winded enough to burn
/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/proc/psycho_hurt_enough()
	return health <= maxHealth * BOUNTY_PSYCHO_BURN_HURT / 100 || getStaminaLoss() >= BOUNTY_PSYCHO_BURN_WINDED

/**
 * Whether it burns its Redline now at `target` (or whoever it fights, for null): its phase two still to
 * come, hurt or winded enough, in its fight, and a Redline move's own checks but its "hurt" reading (C3's
 * line is any carrier's, this is its own): able to act, someone it may hit in sight, the implant ready,
 * and nobody outside the fight within the roar's reach (psycho_roar_clear()). Never at someone it can't
 * get at (boss_valid_target(): shot from behind glass it can't break, it takes cover instead, C5), so a
 * crew can't spend its phase two from where it can't follow.
 */
/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/proc/psycho_burn_due(atom/target)
	if(!boss_hostile || !psycho_burn_pending() || !psycho_hurt_enough())
		return FALSE
	var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/burn = psycho_burn_ability()
	var/datum/bounty_chrome_move/redline/move = burn?.move
	target ||= bounty_chrome_target(src) || boss_revenge_target()
	if(!istype(move) || QDELETED(target) || !bounty_chrome_can_act(src) || !bounty_ai_may_hit(src, target) || !boss_valid_target(target))
		return FALSE
	if(bounty_ai_dist(src, target) > move.max_range || !bounty_ai_can_see(src, target, move.max_range))
		return FALSE
	return move.ready() && psycho_roar_clear(move.area_turfs(target), target)

/**
 * Whether its Redline's roar may go off over `turfs`: nobody stands there who is outside its fight and has
 * a player behind them or is a person (C0's bystander gate, bounty_chrome_area_clear()), but its own
 * companions don't count, and nor do creatures: a cyberpsycho doesn't mind staggering its friends. Its
 * companions come in one for each extra hunter (OC-8), so C0's gate would keep its phase two shut in most
 * fights against a crew.
 */
/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/proc/psycho_roar_clear(list/turfs, atom/aimed)
	for(var/turf/spot as anything in turfs)
		if(!isturf(spot))
			continue
		var/list/people = list()
		for(var/mob/living/person in spot)
			people += person
		for(var/obj/vehicle/sealed/mecha/mech in spot)
			for(var/mob/living/pilot in mech.occupants)
				people += pilot
		for(var/mob/living/person as anything in people)
			if(person == src || person.stat == DEAD || bounty_ai_same_gang(src, person))
				continue
			if((person.mind || person.client || ishuman(person)) && !bounty_chrome_in_posse(src, person, aimed))
				return FALSE
	return TRUE

// Its phase two comes before any other move
/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/boss_choose_ability(atom/target)
	var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/burn = psycho_burn_ability()
	if(burn && !QDELETED(target) && boss_can_use_ability() && burn.IsAvailable() && burn.worth_using(target))
		return burn
	return ..()

// A stamina weapon or a bad wound: it doesn't wait its turn to burn. A moment later, once the hit is done with.
/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/boss_took_damage(damage, damagetype)
	if(!psycho_burned && psycho_hurt_enough())
		addtimer(CALLBACK(src, PROC_REF(psycho_burn_now)), 1, TIMER_UNIQUE | TIMER_DELETE_ME)

/**
 * Burns its Redline now if it should (psycho_burn_due()): whatever it was winding up, or the glass it was
 * punching, it drops, and the burn's tell starts in the next move's place. Not while it is up in a leap,
 * holding on to someone or already winding the burn up. Returns TRUE if the tell started.
 */
/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/proc/psycho_burn_now()
	var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/burn = psycho_burn_ability()
	if(QDELETED(src) || !burn || HAS_TRAIT(src, TRAIT_HANDS_BLOCKED) || !boss_can_act())
		return FALSE
	var/atom/target = bounty_chrome_target(src) || boss_revenge_target()
	if(!burn.worth_using(target))
		return FALSE
	if(boss_busy)
		// A wind-up or a smash ("smash", BOUNTY_BOSS_BUSY_SMASH) gives way; anything else it sees through
		if(boss_winding() == burn || (boss_busy != "windup" && boss_busy != "smash"))
			return FALSE
		boss_interrupt()
	boss_next_ability_at = min(boss_next_ability_at, world.time)
	boss_fallback_until = 0
	// Its own click, as its AI's Trigger() makes it: a timer's callback carries the usr of whoever hit it, and Trigger() would click as them
	return !!burn.InterceptClickOn(src, null, target)

// Tiring is what sets its Redline off: until its phase two is spent it burns instead of falling back, and burning, it doesn't tire
/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/boss_is_worn_out()
	if(psycho_burn_pending() || has_status_effect(/datum/status_effect/cyberware_redline_window))
		return FALSE
	return ..()

// The burn's tell gets its own lines, said over the cooldown on its talk
/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/boss_bark(suffix, fallback)
	var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/winding = boss_winding()
	if(suffix == "ability" && istype(winding) && istype(winding.move, /datum/bounty_chrome_move/redline/psycho))
		if(boss_kit && stat == CONSCIOUS)
			INVOKE_ASYNC(src, TYPE_PROC_REF(/mob/living, bounty_say), "[boss_kit]_redline", null, TRUE)
		return
	return ..()

/// The implant's burn started (its window's stun immunity went on): its phase two is spent
/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/proc/psycho_burn_started(datum/source)
	SIGNAL_HANDLER
	var/datum/status_effect/window = /datum/status_effect/cyberware_redline_window
	if(HAS_TRAIT_FROM(src, TRAIT_STUNIMMUNE, initial(window.id)))
		psycho_burned = TRUE

/// The burn is over (its stun immunity went), and the crash comes: it says so
/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/proc/psycho_burn_ended(datum/source)
	SIGNAL_HANDLER
	if(psycho_burned && boss_kit && stat == CONSCIOUS)
		INVOKE_ASYNC(src, TYPE_PROC_REF(/mob/living, bounty_say), "[boss_kit]_exhausted", null, TRUE)

/**
 * A player in its body (a brain transplant) loses its gear (the human NPC base's Login()), and the headroom
 * only a cyberpsycho carries: with its core's capacity gone, its chrome browns out, all of it, as anyone's
 * does over capacity. Admins driving it for an event keep it.
 */
/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/Login()
	. = ..()
	if(!. || isnull(client) || client.holder)
		return
	var/obj/item/organ/core = psycho_core()
	var/datum/component/cyberware/core_ware = core?.GetComponent(/datum/component/cyberware)
	if(core_ware?.capacity_bonus)
		core_ware.capacity_bonus = 0
		cyberware_reevaluate_brownout(src)

// ===== ITS MOVES =====

/**
 * The cyberpsycho's Redline, its phase two, in place of the one every carrier gets: C3's tell (the chest
 * speaker glowing red, standing still) and the implant's burn, on its own rules (psycho_burn_due()) and its
 * own roar gate (psycho_roar_clear()), checked again as the button is pressed. Wired by the cyberpsycho
 * itself (psycho_wire_chrome()), so no other Redline carrier gets it.
 */
/datum/bounty_chrome_move/redline/psycho
	piece_key = null

/datum/bounty_chrome_move/redline/psycho/can_start(atom/target)
	var/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/psycho = owner
	return istype(psycho) && psycho.psycho_burn_due(target)

// Someone outside the fight stepped into the roar's reach during the tell: the button stays unpressed
/datum/bounty_chrome_move/redline/psycho/effect(atom/target)
	var/mob/living/carbon/human/npc/bounty_criminal/boss/cyberpsycho/psycho = owner
	if(!istype(psycho) || !psycho.psycho_roar_clear(area_turfs(target), target))
		return FALSE
	. = bounty_chrome_trigger(owner, action_type, trigger_target(target))
	if(. && owner.has_status_effect(/datum/status_effect/cyberware_redline_window))
		owner.apply_status_effect(/datum/status_effect/bounty_redline_eyes)

/**
 * Its Gorilla fist's piston punch as a move in its rotation: C2's punch, a fist drawn back over the lit
 * tile for its tell, then the arm's own empowered punch. C2 leaves a mini-boss's Gorilla punches to its
 * melee; this one's melee is its blade. Wired by the cyberpsycho itself (psycho_wire_chrome()), so no other
 * Gorilla Arms carrier gets it.
 */
/datum/bounty_chrome_move/gorilla_punch/psycho
	piece_key = null
	boss_usable = TRUE

// Its rotation throws it; it plans nothing of its own
/datum/bounty_chrome_move/gorilla_punch/psycho/plan(datum/ai_controller/controller, atom/target)
	return FALSE

// ===== THE BOUNTY PANEL =====

// "All of it" is the cyberpsycho: its body is the only one that carries it all (C0's seam)
/datum/bounty_admin_panel/admin_chrome_all(datum/bounty_record/record, list/kit_organs)
	record.archetype = BOUNTY_ARCHETYPE_BOSS
	record.kit = BOUNTY_KIT_CYBERPSYCHO
	record.style = null
	return list()

#undef BOUNTY_PSYCHO_EXTRA_CAPACITY
#undef BOUNTY_PSYCHO_BURN_HURT
#undef BOUNTY_PSYCHO_BURN_WINDED
