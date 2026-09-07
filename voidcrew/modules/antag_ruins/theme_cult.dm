/**
 * # The Scarlet Sepulcher: cult vestige
 *
 * A votive barge whose congregation bled out waiting for an ending. Trials
 * are rites: an assembled remote offering and a blood-funded bounded fight.
 * Boons are blood magic reimplemented without IS_CULTIST checks.
 */

// ===== PATRON =====

/mob/living/basic/vestige_patron/havel
	name = "Sister Havel"
	desc = "The last acolyte of the Sepulcher, chained at the wrist to her own altar. The chain has grown into the skin. She does not seem to mind."
	gender = FEMALE
	outfit_path = /datum/outfit/job/chaplain
	appearance_tint = "#e8d5d5"
	trial_types = list(
		/datum/vestige_trial/offering,
		/datum/vestige_trial/vigil,
	)
	boon_types = list(
		/datum/vestige_boon/spell/crimson_step,
		/datum/vestige_boon/spell/crimson_step/surge,
		/datum/vestige_boon/spell/sanguine_blade,
		/datum/vestige_boon/spell/sanguine_blade/fang,
	)
	idle_lines = list(
		"The congregation is still here. You're standing in them.",
		"Blood is the only coin that never inflates.",
		"We were promised an ending. We are still owed.",
		"The altar drinks. The altar remembers. The altar pays its debts.",
	)
	accept_line = "The Sepulcher witnesses your pact."
	busy_line = "You already owe. Pay first, or renounce."
	fulfilled_line = "That rite is already written in you."
	renounce_line = "The Sepulcher remembers cowards too."
	claim_line = "The altar holds your payment. Take it before you kneel again."
	exhausted_line = "The Sepulcher has nothing left for you. Count that as a blessing."
	remember_line = "The Sepulcher keeps its ledgers somewhere death can't reach. Take back what's yours."

// ===== RITE OF OFFERING =====

/datum/vestige_trial/offering
	name = "Rite of Offering"
	// Keep the count in sync with VESTIGE_OFFERING_CANDLES
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the satchel - chalk, candles, a knife. Somewhere away from here, draw the rune, ring it with three lit candles, and lay a substantial dead organic creature on it. A carp or larger animal is enough; small vermin and machines are not. It won't work inside these walls."
	/// Whether the rune has been scribed somewhere
	var/rune_scribed = FALSE

/datum/vestige_trial/offering/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/storage/box/vestige_ritual(get_turf(user)))

/datum/vestige_trial/offering/get_progress_text()
	return rune_scribed ? "The rune is drawn. It needs three lit candles and a substantial dead organic creature." : "Draw the rune somewhere well away from the Sepulcher."

/obj/item/storage/box/vestige_ritual
	name = "ritual satchel"
	desc = "Chalk, candles, a knife and a light. Assembly is the easy part."

/obj/item/storage/box/vestige_ritual/PopulateContents()
	new /obj/item/vestige_chalk(src)
	for(var/i in 1 to VESTIGE_OFFERING_CANDLES)
		new /obj/item/flashlight/flare/candle(src)
	new /obj/item/knife/ritual/vestige(src)
	new /obj/item/lighter(src)

/obj/item/vestige_chalk
	name = "grave chalk"
	desc = "Chalk cut with ash and something darker. It only wants to draw one shape."
	icon = 'icons/obj/art/crayons.dmi'
	icon_state = "crayonwhite"
	inhand_icon_state = "pen"
	w_class = WEIGHT_CLASS_TINY

/obj/item/vestige_chalk/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isopenturf(interacting_with) || isspaceturf(interacting_with))
		return NONE
	var/turf/open/target_turf = interacting_with
	var/datum/vestige_trial/offering/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the chalk refuses your hand!")
		return ITEM_INTERACT_BLOCKING
	if(istype(get_area(target_turf), /area/ruin/space/has_grav/vestige))
		balloon_alert(user, "too close to the sepulcher!")
		return ITEM_INTERACT_BLOCKING
	if(locate(/obj/structure/vestige_rune) in target_turf)
		balloon_alert(user, "already scribed!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "scribing...")
	if(!do_after(user, 8 SECONDS, target = target_turf))
		return ITEM_INTERACT_BLOCKING
	if(user.mind?.active_vestige_trial != trial || QDELETED(src) || !user.is_holding(src))
		return ITEM_INTERACT_BLOCKING
	// Another scribe, construction, or ship movement can change the site during the channel.
	if(!isopenturf(target_turf) || isspaceturf(target_turf) || istype(get_area(target_turf), /area/ruin/space/has_grav/vestige) || (locate(/obj/structure/vestige_rune) in target_turf))
		return ITEM_INTERACT_BLOCKING
	trial.register_loan(new /obj/structure/vestige_rune(target_turf))
	trial.rune_scribed = TRUE
	trial.refresh_tracker()
	user.visible_message(
		span_warning("[user] scribes a wide crimson rune across the floor."),
		span_notice("You finish the rune. Candles next, then the body."),
	)
	return ITEM_INTERACT_SUCCESS

/obj/structure/vestige_rune
	name = "offering rune"
	desc = "A wide crimson rune. The floor under it feels like it's listening."
	icon = 'icons/obj/antags/cult/rune.dmi'
	icon_state = "1"
	anchored = TRUE
	density = FALSE
	plane = FLOOR_PLANE
	layer = RUNE_LAYER
	color = "#9e1a1a"
	resistance_flags = FIRE_PROOF

/obj/structure/vestige_rune/examine(mob/user)
	. = ..()
	. += span_notice("It needs [VESTIGE_OFFERING_CANDLES] lit candles around it, a substantial dead organic creature laid on top of it, and someone willing to use the knife. Ordinary carp and larger fauna count; small vermin and machines do not.")

/obj/structure/vestige_rune/proc/eligible_offering(mob/living/body)
	return body.stat == DEAD && (body.mob_biotypes & MOB_ORGANIC) && body.maxHealth >= 25

/obj/structure/vestige_rune/attackby(obj/item/attacking_item, mob/user, params)
	if(!istype(attacking_item, /obj/item/knife/ritual/vestige))
		return ..()
	INVOKE_ASYNC(src, PROC_REF(attempt_offering), user)
	return TRUE

/obj/structure/vestige_rune/proc/attempt_offering(mob/living/user)
	var/datum/vestige_trial/offering/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the rune ignores you!")
		return
	var/lit_candles = 0
	for(var/obj/item/flashlight/flare/candle/candle in range(2, src))
		if(candle.light_on && isturf(candle.loc))
			lit_candles++
	if(lit_candles < VESTIGE_OFFERING_CANDLES)
		balloon_alert(user, "needs [VESTIGE_OFFERING_CANDLES] lit candles!")
		return
	var/mob/living/offering
	for(var/mob/living/body in get_turf(src))
		if(eligible_offering(body))
			offering = body
			break
	if(!offering)
		balloon_alert(user, "needs substantial organic remains!")
		return
	user.visible_message(
		span_bolddanger("[user] raises the knife over [offering] and begins a rite!"),
		span_danger("You begin the rite of offering."),
	)
	playsound(src, 'sound/effects/magic/enter_blood.ogg', 50, TRUE)
	if(!do_after(user, 8 SECONDS, target = src))
		return
	// A replacement pact cannot inherit a channel started under the old pact.
	if(user.mind?.active_vestige_trial != trial || QDELETED(src))
		return
	if(QDELETED(offering) || get_turf(offering) != get_turf(src) || !eligible_offering(offering))
		balloon_alert(user, "the offering left the rune!")
		return
	lit_candles = 0
	for(var/obj/item/flashlight/flare/candle/candle in range(2, src))
		if(candle.light_on && isturf(candle.loc))
			lit_candles++
	if(lit_candles < VESTIGE_OFFERING_CANDLES || !user.is_holding_item_of_type(/obj/item/knife/ritual/vestige))
		balloon_alert(user, "the rite was disturbed!")
		return
	offering.visible_message(span_bolddanger("[offering] collapses into a column of ash above the rune!"))
	playsound(src, 'sound/effects/magic/demon_consume.ogg', 60, TRUE)
	offering.dust(TRUE, TRUE)
	trial.complete()
	qdel(src)

/obj/item/knife/ritual/vestige
	name = "sepulcher knife"
	desc = "A ritual knife. The edge stays warm no matter how long you leave it lying around."

// ===== VIGIL OF BLOOD =====

/datum/vestige_trial/vigil
	name = "Vigil of Blood"
	desc = "Take the votive and knife. Unfold the votive in an open room: it takes thirty units of blood, or a little strength from a bloodless body, and calls three hungry clots. They are real attackers. Kill them with the knife or your own weapons while keeping the fight within six paces of the votive. Each death outside that circle breaks the rite. The votive can be packed up to retry; it never charges blood twice."
	var/list/clots = list()
	var/obj/item/vestige_blood_votive/votive
	var/paid = FALSE
	var/slain = 0
	var/running = FALSE

/datum/vestige_trial/vigil/on_accepted(mob/living/user)
	votive = hand_over(user, new /obj/item/vestige_blood_votive(get_turf(user)))
	hand_over(user, new /obj/item/knife/ritual/vestige(get_turf(user)))

/datum/vestige_trial/vigil/Destroy()
	reset_rite()
	return ..()

/datum/vestige_trial/vigil/proc/reset_rite()
	running = FALSE
	for(var/mob/living/basic/carp/vestige_clot/clot as anything in clots)
		if(QDELETED(clot))
			continue
		UnregisterSignal(clot, COMSIG_LIVING_DEATH)
		if(!clot.mind && !clot.client)
			qdel(clot)
	clots = list()
	slain = 0
	if(votive)
		votive.anchored = FALSE
	refresh_tracker()

/datum/vestige_trial/vigil/get_progress_text()
	return running ? "[slain] of three hungry clots slain inside the votive's six-pace circle." : "Use the votive in hand in a clear room. Bring a weapon."

/datum/vestige_trial/vigil/proc/unfold(mob/living/user)
	if(running || length(clots))
		reset_rite()
		to_chat(user, span_warning("You fold the broken rite away. The blood already paid will fund another attempt."))
		return
	var/list/places = list()
	for(var/turf/open/place in view(3, user))
		if(get_dist(place, user) >= 2 && !isspaceturf(place) && !place.is_blocked_turf(exclude_mobs = FALSE))
			places += place
	if(length(places) < 3)
		to_chat(user, span_warning("The votive needs three clear floor tiles two or three paces away."))
		return
	if(!paid)
		if(!HAS_TRAIT(user, TRAIT_NOBLOOD) && user.blood_volume)
			if(user.blood_volume < BLOOD_VOLUME_SAFE)
				to_chat(user, span_warning("Recover your blood first. The votive refuses an unsafe payment."))
				return
			user.blood_volume -= 30
		else
			user.adjustStaminaLoss(20)
		paid = TRUE
	votive.forceMove(get_turf(user))
	votive.anchored = TRUE
	running = TRUE
	for(var/index in 1 to 3)
		var/mob/living/basic/carp/vestige_clot/clot = new(pick_n_take(places))
		clots += clot
		RegisterSignal(clot, COMSIG_LIVING_DEATH, PROC_REF(clot_died))
	refresh_tracker()

/datum/vestige_trial/vigil/proc/clot_died(mob/living/source, gibbed)
	SIGNAL_HANDLER
	if(!running || !(source in clots))
		return
	if(source.mind || source.client)
		running = FALSE
		to_chat(owner.current, span_warning("A clot became someone else's body. Pack the rite to release them and retry."))
		return
	if(!votive || source.z != votive.z || get_dist(source, votive) > 6)
		running = FALSE
		to_chat(owner.current, span_warning("A clot died beyond the blood circle. Use the votive to pack up, then retry."))
		return
	// A revived clot is still the same participant, not a second offering.
	UnregisterSignal(source, COMSIG_LIVING_DEATH)
	slain++
	refresh_tracker()
	if(slain == 3)
		complete()

/obj/item/vestige_blood_votive
	name = "blood votive"
	desc = "Use in hand to call three hungry clots. Keep every kill within six paces. Once planted, click it with an empty hand to pack up and retry."
	icon = 'icons/obj/antags/cult/structures.dmi'
	icon_state = "talismanaltar"
	inhand_icon_state = "blankplaque"
	w_class = WEIGHT_CLASS_SMALL
	resistance_flags = INDESTRUCTIBLE

/obj/item/vestige_blood_votive/attack_self(mob/living/user, modifiers)
	var/datum/vestige_trial/vigil/trial = user.mind?.active_vestige_trial
	if(istype(trial) && trial.votive == src)
		trial.unfold(user)
	return TRUE

/obj/item/vestige_blood_votive/attack_hand(mob/living/user, list/modifiers)
	var/datum/vestige_trial/vigil/trial = user.mind?.active_vestige_trial
	if(istype(trial) && trial.votive == src && anchored)
		trial.reset_rite()
	return ..()

/mob/living/basic/carp/vestige_clot
	name = "hungry clot"
	desc = "A knot of blood with more teeth than it needs. Keep it inside the votive's circle."
	color = "#a02030"
	health = 30
	maxHealth = 30
	melee_damage_lower = 8
	melee_damage_upper = 8
	melee_attack_cooldown = 2 SECONDS
	obj_damage = 0
	butcher_results = null
	sentience_type = NONE

/mob/living/basic/carp/vestige_clot/Initialize(mapload, mob/tamer)
	. = ..()
	// Feeding the rite's attackers must not turn them into harmless pets.
	qdel(GetComponent(/datum/component/tameable))

/obj/structure/vestige_altar
	name = "sepulcher altar"
	desc = "A stone altar with a groove worn smooth down the middle. It is very obviously a drain."
	icon = 'icons/obj/antags/cult/structures.dmi'
	icon_state = "talismanaltar"
	anchored = TRUE
	density = TRUE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/obj/structure/vestige_altar/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	INVOKE_ASYNC(src, PROC_REF(attempt_donation), user)
	return TRUE

/obj/structure/vestige_altar/proc/attempt_donation(mob/living/carbon/human/user)
	to_chat(user, span_notice("The altar has no use for idle tithes. Havel's votive carries the blood rite into the field."))

// ===== BOONS =====

// Tuning constants for the Sepulcher's boons (file-local, #undef at bottom).
// Boon descs quote these numbers literally. Keep them in sync.
/// Blood units one Crimson Step drinks
#define VESTIGE_STEP_BLOOD_COST 15
/// The fold refuses a body already drained below this. Blood is the coin, not the corpse
#define VESTIGE_STEP_BLOOD_FLOOR BLOOD_VOLUME_OKAY
/// Tiles the base step reaches
#define VESTIGE_STEP_RANGE 5
/// Tiles the surge reaches
#define VESTIGE_SURGE_RANGE 7
/// Bonus force the sanguine blade lends against the fallen
#define VESTIGE_BLADE_ALTAR_BONUS 6
/// Bonus force the fang lends against the fallen
#define VESTIGE_FANG_ALTAR_BONUS 10

/datum/vestige_boon/spell/crimson_step
	name = "Crimson Step"
	// Keep the numbers in sync with VESTIGE_STEP_BLOOD_COST / VESTIGE_STEP_RANGE
	// (initial values must be constant, so no define interpolation here)
	desc = "Teleport to any open ground you can see a short way off. Each use costs your own blood and leaves a pool of it where you were standing. It won't work if you're already low."
	grant_text = "The space behind your eyes folds. Distance costs blood now."
	spell_type = /datum/action/cooldown/spell/pointed/vestige_crimson_step

/datum/vestige_boon/spell/crimson_step/surge
	name = "Crimson Surge"
	// Keep the numbers in sync with VESTIGE_SURGE_RANGE
	desc = "The same step, reaching further and coming back much faster. The blood cost doesn't change."
	grant_text = "The red place behind your eyes widens. It opens the moment you ask now."
	upgrades_from = /datum/vestige_boon/spell/crimson_step
	spell_type = /datum/action/cooldown/spell/pointed/vestige_crimson_step/surge

/**
 * The Sepulcher's step: a pointed, aimed fold to visible ground, paid for in
 * the caster's own blood. Deliberately NOT the wizard blink chassis, the
 * Athenaeum's Word of Passage already owns the random-destination blink, and
 * two patrons selling the same spell cheapens both. This one is precise where
 * the wizard's is random, and costed where the wizard's is free: blood is the
 * cult's currency (the Vigil of Blood trial teaches exactly that), the fold
 * refuses a drained body, and both ends of the step are loudly advertised.
 * The pool left behind is real blood, with everything that implies for anyone
 * who can read a deck (or bloodcrawl through it).
 *
 * do_teleport runs unforced on the magic channel, so NOTELEPORT areas and
 * TRAIT_NO_TELEPORT keep their veto; a refused fold spends no blood (the
 * cooldown is lost, this fork's Activate() ignores cast()'s return value,
 * and everything refusable up front already lives in before_cast).
 */
/datum/action/cooldown/spell/pointed/vestige_crimson_step
	name = "Crimson Step"
	desc = "Teleport a few tiles to somewhere you can see. Costs blood and leaves a pool behind. Won't work if you're low."
	button_icon = 'icons/mob/actions/actions_cult.dmi'
	button_icon_state = "tele"
	school = SCHOOL_FORBIDDEN
	cooldown_time = 15 SECONDS
	invocation_type = INVOCATION_NONE
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC
	cast_range = VESTIGE_STEP_RANGE
	aim_assist = FALSE // the step wants ground; a clicked mob resolves to its turf anyway
	active_msg = "A red crease opens in the world. Pick where you're going..."
	deactive_msg = "You let the crease smooth back out."
	/// Blood units one fold drinks
	var/blood_cost = VESTIGE_STEP_BLOOD_COST

/datum/action/cooldown/spell/pointed/vestige_crimson_step/surge
	name = "Crimson Surge"
	desc = "Teleport to somewhere you can see, further out and on a shorter cooldown. Costs blood and leaves a pool behind. Won't work if you're low."
	cooldown_time = 8 SECONDS
	cast_range = VESTIGE_SURGE_RANGE

/datum/action/cooldown/spell/pointed/vestige_crimson_step/is_valid_target(atom/cast_on)
	. = ..()
	if(!.)
		return FALSE
	var/turf/destination = get_turf(cast_on)
	if(!isopenturf(destination))
		destination?.balloon_alert(owner, "no footing there!")
		return FALSE
	if(destination == get_turf(owner))
		destination.balloon_alert(owner, "already standing there!")
		return FALSE
	if(destination.is_blocked_turf(exclude_mobs = TRUE))
		destination.balloon_alert(owner, "no room to arrive!")
		return FALSE
	return TRUE

// The blood check lives here so a refused fold never pays the cooldown
/datum/action/cooldown/spell/pointed/vestige_crimson_step/before_cast(atom/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return
	var/mob/living/caster = owner
	if(!isliving(caster))
		return . | SPELL_CANCEL_CAST
	if(HAS_TRAIT(caster, TRAIT_NOBLOOD) || !caster.blood_volume)
		caster.balloon_alert(caster, "no blood to pay with!")
		return . | SPELL_CANCEL_CAST
	if(caster.blood_volume < VESTIGE_STEP_BLOOD_FLOOR)
		caster.balloon_alert(caster, "too drained to fold!")
		to_chat(caster, span_warning("You've lost too much blood to pay for the fold. Come back when you've recovered."))
		return . | SPELL_CANCEL_CAST

/datum/action/cooldown/spell/pointed/vestige_crimson_step/cast(atom/cast_on)
	. = ..()
	var/mob/living/caster = owner
	var/turf/origin = get_turf(caster)
	var/turf/destination = get_turf(cast_on)
	if(!destination || !do_teleport(caster, destination, no_effects = TRUE, channel = TELEPORT_CHANNEL_MAGIC))
		caster.balloon_alert(caster, "something blocks the fold!")
		return
	// Paid on arrival only: a warded destination costs the cooldown, never the blood
	caster.blood_volume = max(caster.blood_volume - blood_cost, 0)
	if(origin)
		new /obj/effect/decal/cleanable/blood(origin)
		origin.visible_message(span_warning("[caster] folds out of the world, leaving [caster.p_their()] own blood pooled where [caster.p_they()] stood!"))
		playsound(origin, 'sound/effects/magic/enter_blood.ogg', 50, TRUE)
	playsound(destination, 'sound/effects/magic/exit_blood.ogg', 50, TRUE)
	caster.visible_message(
		span_warning("[caster] unfolds out of somewhere red and wet!"),
		span_notice("You step through the red place. It takes its cut of you on the way."),
	)

/datum/vestige_boon/spell/sanguine_blade
	name = "Sanguine Blade"
	// Keep the number in sync with VESTIGE_BLADE_ALTAR_BONUS
	desc = "Summon the Sepulcher's knife into your hand from anywhere, and dismiss it when you're done. It hits harder against anyone already lying on the floor."
	grant_text = "A knife-shaped weight settles against your palm. It comes when you call."
	spell_type = /datum/action/cooldown/spell/vestige_sanguine_blade

/datum/vestige_boon/spell/sanguine_blade/fang
	name = "Sanguine Fang"
	// Keep the number in sync with VESTIGE_FANG_ALTAR_BONUS
	desc = "A longer, meaner version of the knife. It cuts through armor, comes back twice as fast, and hits harder still against anyone lying down."
	grant_text = "The weight against your palm grows teeth."
	upgrades_from = /datum/vestige_boon/spell/sanguine_blade
	spell_type = /datum/action/cooldown/spell/vestige_sanguine_blade/fang

/datum/action/cooldown/spell/vestige_sanguine_blade
	name = "Sanguine Blade"
	desc = "Summon a blood-forged knife into your hand. Use again to send it back."
	// The knife's own world sprite, so the button and the thing in your hand are
	// recognisably the same object (/obj/item/knife/ritual, knives.dm)
	button_icon = 'icons/obj/weapons/khopesh.dmi'
	button_icon_state = "bone_blade"
	school = SCHOOL_CONJURATION
	cooldown_time = 10 SECONDS
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	/// The knife this spell calls
	var/blade_type = /obj/item/knife/ritual/vestige/bound
	/// Only this action's summoned knife is reclaimed when the pact leaves a body.
	var/datum/weakref/summoned_blade_ref

/datum/action/cooldown/spell/vestige_sanguine_blade/Remove(mob/remove_from)
	var/obj/item/knife/ritual/vestige/bound/summoned_blade = summoned_blade_ref?.resolve()
	summoned_blade_ref = null
	if(summoned_blade)
		qdel(summoned_blade)
	return ..()

/datum/action/cooldown/spell/vestige_sanguine_blade/fang
	name = "Sanguine Fang"
	desc = "Summon a stronger blood-forged knife into your hand. Use again to send it back."
	cooldown_time = 5 SECONDS
	blade_type = /obj/item/knife/ritual/vestige/bound/fang

/datum/action/cooldown/spell/vestige_sanguine_blade/is_valid_target(atom/cast_on)
	return iscarbon(cast_on)

// The cancel lives here: no knife to send back and no hand to call one into
// means the cast never happens and the cooldown is never paid, this fork's
// Activate() ignores cast()'s return value, so an in-cast
// reset_spell_cooldown() is dead code
/datum/action/cooldown/spell/vestige_sanguine_blade/before_cast(atom/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return
	var/mob/living/carbon/carbon_cast_on = cast_on
	if(locate(/obj/item/knife/ritual/vestige/bound) in carbon_cast_on.held_items)
		return
	if(!length(carbon_cast_on.get_empty_held_indexes()))
		carbon_cast_on.balloon_alert(carbon_cast_on, "no free hand!")
		return . | SPELL_CANCEL_CAST

/datum/action/cooldown/spell/vestige_sanguine_blade/cast(mob/living/carbon/cast_on)
	. = ..()
	var/obj/item/knife/ritual/vestige/bound/held = locate(/obj/item/knife/ritual/vestige/bound) in cast_on.held_items
	if(held)
		var/outdated = held.type != blade_type
		if(!outdated)
			cast_on.visible_message(span_warning("[held] dissolves into red mist!"), span_notice("You send the knife back."))
			playsound(cast_on, 'sound/effects/magic/exit_blood.ogg', 50, TRUE)
			qdel(held)
			return
		// An old model from before the upgrade: reshape it in place
		qdel(held)
	var/obj/item/new_blade = new blade_type(cast_on)
	summoned_blade_ref = WEAKREF(new_blade)
	if(!cast_on.put_in_hands(new_blade))
		if(!QDELETED(new_blade)) // DROPDEL usually beat us to it
			qdel(new_blade)
		cast_on.balloon_alert(cast_on, "no free hand!")
		return
	cast_on.visible_message(
		span_warning("A knife condenses out of red mist in [cast_on]'s hand!"),
		span_notice("The knife answers."),
	)
	playsound(cast_on, 'sound/effects/magic/enter_blood.ogg', 50, TRUE)

/**
 * The Sepulcher's knife: a summoned sacrificial edge whose identity is the
 * altar, not the arm, flat force stays modest, but the fallen (anyone alive
 * and flat on the deck) are cut altar_bonus points deeper. Pairs with the
 * Crimson Step's burst arrival; distinct on purpose from the armblade (flat
 * heavy melee) and the demon claws (bleed-and-rhythm melee).
 */
/obj/item/knife/ritual/vestige/bound
	name = "sanguine blade"
	desc = "The Sepulcher's knife, bound to a pact. It vanishes the moment it leaves your hand, and it cuts deepest into anyone already lying down."
	force = 18
	item_flags = ABSTRACT | DROPDEL
	/// Bonus force against living targets already flat on the deck, the altar's edge
	var/altar_bonus = VESTIGE_BLADE_ALTAR_BONUS

/obj/item/knife/ritual/vestige/bound/fang
	name = "sanguine fang"
	desc = "The Sepulcher's knife, grown long and mean on a well-kept pact. It vanishes the moment it leaves your hand, and it cuts deepest into anyone already lying down."
	force = 24
	armour_penetration = 20
	altar_bonus = VESTIGE_FANG_ALTAR_BONUS

// The altar's edge: the fallen are offerings, not opponents. Living only.
// The dead are the lantern's business, and corpse-sawing needs no buff.
/obj/item/knife/ritual/vestige/bound/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(isliving(target) && target.stat != DEAD && target.body_position == LYING_DOWN)
		MODIFY_ATTACK_FORCE(attack_modifiers, altar_bonus)
	return ..()

#undef VESTIGE_STEP_BLOOD_COST
#undef VESTIGE_STEP_BLOOD_FLOOR
#undef VESTIGE_STEP_RANGE
#undef VESTIGE_SURGE_RANGE
#undef VESTIGE_BLADE_ALTAR_BONUS
#undef VESTIGE_FANG_ALTAR_BONUS
