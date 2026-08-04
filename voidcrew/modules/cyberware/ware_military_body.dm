/**
 * # Tier 3 military chrome — body systems
 *
 * Ghostskin Weave, Slabskin Plate, Lazarus Node, Atlas Frame, Void-Rated
 * Chassis, Rigger Socket. All chest/head chrome on the generic cyberware
 * base; every strong effect here keeps the PvP contract — a visible
 * telegraph and a counter.
 */

// =========================================================================
// GHOSTSKIN WEAVE
// =========================================================================

/// Cloak alpha. NEVER 0 — a shimmer stays readable point-blank.
#define CYBERWARE_GHOSTSKIN_ALPHA 40
/// How long a camo field holds before it collapses on its own.
#define CYBERWARE_GHOSTSKIN_DURATION (10 SECONDS)

/**
 * # Ghostskin Weave (T3, chest, skin slot, load 5)
 *
 * A dermal mesh of refraction cells: ten seconds of optical camo on a
 * 30-second clock. Players see a heat-shimmer outline (alpha 40, never full
 * invisibility) that ripples brighter when you move; NPC targeting honors
 * TRAIT_CYBER_CAMO through the hook in cyberware_stealth.dm, but anything
 * within two tiles spots you anyway. The field collapses the instant you
 * attack, shoot, get struck, get cuffed, or eat an EMP — the break-trigger
 * list is the MOD stealth module's, plus gunfire (nothing uncounterable
 * fires from inside a cloak on this server).
 */
/obj/item/organ/cyberimp/cyberware/ghostskin
	name = "\improper Ghostskin weave"
	desc = "A subdermal lattice of refraction cells. Engaged, you are a heat-shimmer and a rumor; swing at anyone and you are a person again, mid-swing, in the open."
	icon_state = "ghostskin"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_SKIN
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 5
	tier = CYBERWARE_TIER_3
	actions_types = list(/datum/action/cooldown/cyberware/ghostskin_cloak)
	/// TRUE while the camo field is up.
	var/camo_active = FALSE
	/// Timer for the field's natural collapse.
	var/camo_timer

/obj/item/organ/cyberimp/cyberware/ghostskin/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	break_camo(organ_owner, silent = TRUE)

/obj/item/organ/cyberimp/cyberware/ghostskin/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	if(camo_active)
		break_camo(owner, reason = "EMP discharge")

/// Raises the field: shimmer alpha, camo trait, break triggers, expiry clock.
/obj/item/organ/cyberimp/cyberware/ghostskin/proc/engage_camo(mob/living/carbon/wearer)
	if(camo_active || !wearer)
		return
	camo_active = TRUE
	ADD_TRAIT(wearer, TRAIT_CYBER_CAMO, REF(src))
	animate(wearer, alpha = CYBERWARE_GHOSTSKIN_ALPHA, time = 1 SECONDS)
	playsound(wearer, 'voidcrew/sound/machines/cloaking/on.ogg', 60, TRUE)
	wearer.visible_message(
		span_warning("[wearer] ripples and thins to a heat-shimmer outline!"),
		span_notice("The weave drinks the light. Ten seconds."),
	)
	// The MOD stealth break list (modules_ninja.dm), minus bump-off, plus
	// gunfire — shooting from inside a cloak breaks it here.
	RegisterSignal(wearer, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_unarmed_attack))
	RegisterSignal(wearer, COMSIG_ATOM_BULLET_ACT, PROC_REF(on_bullet_act))
	RegisterSignals(wearer, list(
		COMSIG_MOB_ITEM_ATTACK,
		COMSIG_ATOM_ATTACKBY,
		COMSIG_ATOM_ATTACK_HAND,
		COMSIG_ATOM_HITBY,
		COMSIG_ATOM_HULK_ATTACK,
		COMSIG_ATOM_ATTACK_PAW,
		COMSIG_CARBON_CUFF_ATTEMPTED,
		COMSIG_MOB_FIRED_GUN,
		COMSIG_LIVING_DEATH,
	), PROC_REF(on_break_trigger))
	RegisterSignal(wearer, COMSIG_MOVABLE_MOVED, PROC_REF(on_camo_move))
	camo_timer = addtimer(CALLBACK(src, PROC_REF(on_field_expired)), CYBERWARE_GHOSTSKIN_DURATION, TIMER_STOPPABLE)

/obj/item/organ/cyberimp/cyberware/ghostskin/proc/on_field_expired()
	camo_timer = null
	break_camo(owner, reason = "field capacity spent")

/// Collapses the field and returns the bearer to full visibility.
/obj/item/organ/cyberimp/cyberware/ghostskin/proc/break_camo(mob/living/carbon/wearer, reason, silent = FALSE)
	if(!camo_active)
		return
	camo_active = FALSE
	if(camo_timer)
		deltimer(camo_timer)
		camo_timer = null
	if(!wearer)
		return
	REMOVE_TRAIT(wearer, TRAIT_CYBER_CAMO, REF(src))
	UnregisterSignal(wearer, list(
		COMSIG_LIVING_UNARMED_ATTACK,
		COMSIG_ATOM_BULLET_ACT,
		COMSIG_MOB_ITEM_ATTACK,
		COMSIG_ATOM_ATTACKBY,
		COMSIG_ATOM_ATTACK_HAND,
		COMSIG_ATOM_HITBY,
		COMSIG_ATOM_HULK_ATTACK,
		COMSIG_ATOM_ATTACK_PAW,
		COMSIG_CARBON_CUFF_ATTEMPTED,
		COMSIG_MOB_FIRED_GUN,
		COMSIG_LIVING_DEATH,
		COMSIG_MOVABLE_MOVED,
	))
	animate(wearer, alpha = 255, time = 0.5 SECONDS)
	if(!silent)
		do_sparks(2, TRUE, wearer)
		wearer.visible_message(
			span_danger("[wearer] shimmers back into full view!"),
			span_warning("The weave collapses[reason ? " — [reason]" : ""]. You are visible."),
		)

/// Signal proc for the blanket break triggers: any attack, hit or cuff.
/obj/item/organ/cyberimp/cyberware/ghostskin/proc/on_break_trigger(datum/source)
	SIGNAL_HANDLER
	break_camo(owner, reason = "field contact")

/// Signal proc for [COMSIG_LIVING_UNARMED_ATTACK]: MOD precedent — only
/// swings at living things blow the cloak, not opening a door.
/obj/item/organ/cyberimp/cyberware/ghostskin/proc/on_unarmed_attack(datum/source, atom/target)
	SIGNAL_HANDLER
	if(!isliving(target))
		return
	break_camo(owner, reason = "field contact")

/// Signal proc for [COMSIG_ATOM_BULLET_ACT]: hostile rounds pop the field.
/obj/item/organ/cyberimp/cyberware/ghostskin/proc/on_bullet_act(datum/source, obj/projectile/projectile)
	SIGNAL_HANDLER
	if(!projectile.is_hostile_projectile())
		return
	break_camo(owner, reason = "field disrupted")

/// Signal proc for [COMSIG_MOVABLE_MOVED]: the moving-shimmer ripple —
/// motion makes you briefly MORE visible. Free counterplay for sharp eyes.
/obj/item/organ/cyberimp/cyberware/ghostskin/proc/on_camo_move(datum/source)
	SIGNAL_HANDLER
	var/mob/living/wearer = owner
	if(!wearer || !camo_active)
		return
	animate(wearer, alpha = 90, time = 0.15 SECONDS)
	animate(alpha = CYBERWARE_GHOSTSKIN_ALPHA, time = 0.35 SECONDS)

/datum/action/cooldown/cyberware/ghostskin_cloak
	name = "Ghostskin Field"
	desc = "Ten seconds of optical camo. Attacking, shooting, taking a hit or an EMP collapses the field; point-blank you are still spotted."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "sniper_zoom"
	cooldown_time = 30 SECONDS
	click_to_activate = FALSE

/datum/action/cooldown/cyberware/ghostskin_cloak/Activate(atom/target)
	var/obj/item/organ/cyberimp/cyberware/ghostskin/weave = organ
	if(!istype(weave) || !iscarbon(owner))
		return FALSE
	if(weave.camo_active)
		// Manual early collapse; the cooldown was already paid.
		weave.break_camo(owner, reason = "disengaged")
		return TRUE
	StartCooldown()
	weave.engage_camo(owner)
	return TRUE

// =========================================================================
// SLABSKIN PLATE
// =========================================================================

/// Built-in plate, roach-organ pattern. Ratings capped under 30 by design.
/datum/armor/cyberware_slabskin
	melee = 25
	bullet = 25
	laser = 25
	energy = 20
	bomb = 25
	fire = 20
	acid = 20
	wound = 15

/**
 * # Slabskin Plate (T3, chest, dermal slot, load 6)
 *
 * Serious all-round subdermal armor — the top rung of the dermal ladder,
 * evicting Dermal Mesh. Every solid hit visibly SPARKS and ricochets off
 * the plate, so everyone in the fight can see you are armored under the
 * jumpsuit; that legibility is the PvP tax on built-in plate. Physiology
 * armor persists through species changes by design (the physiology datum
 * survives them), and is added/removed symmetrically on install/removal.
 */
/obj/item/organ/cyberimp/cyberware/slabskin
	name = "\improper Slabskin plate"
	desc = "Sintered ceramic scales grown into the dermis in overlapping courses. Bullets leave scuffs and a noise like a dropped pan; you leave the conversation upright."
	icon_state = "slabskin"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_DERMAL
	w_class = WEIGHT_CLASS_NORMAL
	chrome_load = 6
	tier = CYBERWARE_TIER_3
	aug_overlay = "slabskin"

/obj/item/organ/cyberimp/cyberware/slabskin/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	if(ishuman(organ_owner))
		var/mob/living/carbon/human/human_owner = organ_owner
		human_owner.physiology.armor = human_owner.physiology.armor.add_other_armor(/datum/armor/cyberware_slabskin)
	RegisterSignal(organ_owner, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(on_damaged))

/obj/item/organ/cyberimp/cyberware/slabskin/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	if(ishuman(organ_owner))
		var/mob/living/carbon/human/human_owner = organ_owner
		human_owner.physiology.armor = human_owner.physiology.armor.subtract_other_armor(/datum/armor/cyberware_slabskin)
	UnregisterSignal(organ_owner, COMSIG_MOB_APPLY_DAMAGE)

/**
 * Signal proc for [COMSIG_MOB_APPLY_DAMAGE]: the telegraph. Solid brute or
 * burn hits spark and ping off the plate where everyone can see them.
 */
/obj/item/organ/cyberimp/cyberware/slabskin/proc/on_damaged(mob/living/source, damage, damagetype, def_zone)
	SIGNAL_HANDLER
	if(damagetype != BRUTE && damagetype != BURN)
		return
	if(damage < 5)
		return
	if(organ_flags & ORGAN_FAILING)
		return
	do_sparks(1, TRUE, source)
	if(prob(60))
		playsound(source, pick(
			'sound/items/weapons/effects/ric1.ogg',
			'sound/items/weapons/effects/ric2.ogg',
			'sound/items/weapons/effects/ric3.ogg',
			'sound/items/weapons/effects/ric4.ogg',
			'sound/items/weapons/effects/ric5.ogg',
		), 40, TRUE)

// =========================================================================
// LAZARUS NODE
// =========================================================================

/// Once per this long.
#define CYBERWARE_LAZARUS_COOLDOWN (6 MINUTES)
/// The visible seizure between crit entry and the jolt — the kill window.
#define CYBERWARE_LAZARUS_WINDUP (1 SECONDS)
/// Fraction of max health the jolt restores you to.
#define CYBERWARE_LAZARUS_HEAL_TO 0.3

/**
 * # Lazarus Node (T3, chest, tg heart-aid slot, load 5)
 *
 * The anti-crit charge bank. It rides tg's ORGAN_SLOT_HEART_AID — so it
 * EVICTS the printable reviver implant; the ladder, not a stack — and does
 * the opposite of the reviver's slow trickle: once per six minutes, the
 * moment you drop into crit it screams up to charge for one full second
 * (visible seizure, audible whine — you are killable the whole time) and
 * then slams you back ON YOUR FEET at 30% health with a defib crack heard
 * down the corridor. It does nothing for the dead; overkill straight past
 * crit skips the node entirely. That windup and that ceiling are the PvP
 * contract: confirm your kill.
 */
/obj/item/organ/cyberimp/cyberware/lazarus
	name = "\improper Lazarus node"
	desc = "A capacitor bank fist-deep in the chest cavity, wired straight across the heart. When the meat gives out it takes one second to disagree, loudly, and then you are standing again."
	icon_state = "lazarus"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_HEART_AID
	w_class = WEIGHT_CLASS_NORMAL
	chrome_load = 5
	tier = CYBERWARE_TIER_3
	/// TRUE during the one-second windup.
	var/jolting = FALSE
	/// The once-per-six-minutes clock.
	COOLDOWN_DECLARE(jolt_cooldown)

/obj/item/organ/cyberimp/cyberware/lazarus/examine(mob/user)
	. = ..()
	if(COOLDOWN_FINISHED(src, jolt_cooldown))
		. += span_notice("The charge bank reads <b>READY</b>.")
	else
		. += span_notice("The charge bank reads <b>RECHARGING</b> — [DisplayTimeText(COOLDOWN_TIMELEFT(src, jolt_cooldown))] left.")

/obj/item/organ/cyberimp/cyberware/lazarus/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(organ_owner, COMSIG_MOB_STATCHANGE, PROC_REF(on_stat_change))

/obj/item/organ/cyberimp/cyberware/lazarus/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(organ_owner, COMSIG_MOB_STATCHANGE)
	jolting = FALSE

/**
 * Signal proc for [COMSIG_MOB_STATCHANGE]: fires the windup on the
 * transition INTO crit. Waking up, dying outright, or already-charging
 * states all fall through.
 */
/obj/item/organ/cyberimp/cyberware/lazarus/proc/on_stat_change(mob/living/carbon/source, new_stat, old_stat)
	SIGNAL_HANDLER
	if(jolting)
		return
	if(organ_flags & ORGAN_FAILING)
		return
	if(new_stat == CONSCIOUS || new_stat == DEAD)
		return
	if(old_stat == DEAD)
		return
	if(!COOLDOWN_FINISHED(src, jolt_cooldown))
		return
	jolting = TRUE
	COOLDOWN_START(src, jolt_cooldown, CYBERWARE_LAZARUS_COOLDOWN)
	source.visible_message(
		span_boldwarning("[source] seizes — something under [source.p_their()] ribs whines up to full charge!"),
		span_userdanger("The Lazarus node screams up to charge—"),
	)
	playsound(source, 'sound/machines/defib/defib_charge.ogg', 75, TRUE)
	source.set_jitter_if_lower(4 SECONDS)
	source.do_jitter_animation(200)
	addtimer(CALLBACK(src, PROC_REF(jolt)), CYBERWARE_LAZARUS_WINDUP)

/// The discharge: heal to 30%, clear the floor out from under every stun,
/// and stand the patient up with a thunderclap. Skipped if they died (or
/// recovered) during the windup — that second belongs to the attacker.
/obj/item/organ/cyberimp/cyberware/lazarus/proc/jolt()
	jolting = FALSE
	var/mob/living/carbon/patient = owner
	if(QDELETED(src) || QDELETED(patient))
		return
	if(organ_flags & ORGAN_FAILING)
		return
	if(patient.stat == DEAD || patient.stat == CONSCIOUS)
		return
	var/needed = (patient.maxHealth * CYBERWARE_LAZARUS_HEAL_TO) - patient.health
	if(needed > 0)
		var/oxy_heal = min(needed, patient.getOxyLoss())
		if(oxy_heal > 0)
			patient.adjustOxyLoss(-oxy_heal, updating_health = FALSE)
			needed -= oxy_heal
		var/brute = patient.getBruteLoss()
		var/burn = patient.getFireLoss()
		var/pool = brute + burn
		if(needed > 0 && pool > 0)
			patient.adjustBruteLoss(-(needed * (brute / pool)), updating_health = FALSE)
			patient.adjustFireLoss(-(needed * (burn / pool)), updating_health = FALSE)
		patient.updatehealth()
	patient.SetStun(0)
	patient.SetKnockdown(0)
	patient.SetImmobilized(0)
	patient.SetParalyzed(0)
	patient.SetUnconscious(0)
	patient.setStaminaLoss(0)
	patient.set_resting(FALSE, silent = TRUE, instant = TRUE)
	playsound(patient, 'sound/machines/defib/defib_zap.ogg', 100, TRUE)
	do_sparks(3, TRUE, patient)
	patient.emote("gasp")
	patient.set_jitter_if_lower(20 SECONDS)
	patient.visible_message(
		span_boldwarning("[patient] jolts bolt upright with a thunderclap of current!"),
		span_userdanger("Your heart slams back into rhythm — ON YOUR FEET."),
	)
	patient.balloon_alert(patient, "lazarus jolt!")

// =========================================================================
// ATLAS FRAME
// =========================================================================

/**
 * # Atlas Frame (T3, chest, frame slot, load 4)
 *
 * A load-bearing endoskeletal truss: your bones cannot break. No wounds,
 * no dismemberment, your throws carry real freight (+2 tiles, +1 speed),
 * and forced knockback against you is halved — a warframe sweep that hurls
 * everyone else across the hall moves you one polite step.
 */
/obj/item/organ/cyberimp/cyberware/atlas
	name = "\improper Atlas frame"
	desc = "A titanium truss bolted through the axial skeleton. Bones stop being the part of you that breaks, and everything you throw arrives like it was fired."
	icon_state = "atlas"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_FRAME
	w_class = WEIGHT_CLASS_NORMAL
	chrome_load = 4
	tier = CYBERWARE_TIER_3
	organ_traits = list(TRAIT_NODISMEMBER, TRAIT_NEVER_WOUNDED)

/obj/item/organ/cyberimp/cyberware/atlas/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(organ_owner, COMSIG_MOB_THROW, PROC_REF(on_owner_throws))
	RegisterSignal(organ_owner, COMSIG_MOVABLE_PRE_THROW, PROC_REF(on_owner_thrown))

/obj/item/organ/cyberimp/cyberware/atlas/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(organ_owner, list(COMSIG_MOB_THROW, COMSIG_MOVABLE_PRE_THROW))

/**
 * Signal proc for [COMSIG_MOB_THROW] on the bearer: the throw target is not
 * resolved yet, so arm one-shot PRE_THROW hooks on both things it could be
 * (active-hand item, pulled mob). throw_at() runs synchronously inside this
 * same call stack; a zero-length timer sweeps the hooks up afterwards.
 */
/obj/item/organ/cyberimp/cyberware/atlas/proc/on_owner_throws(mob/living/source, atom/target)
	SIGNAL_HANDLER
	if(organ_flags & ORGAN_FAILING)
		return
	var/list/candidates = list()
	var/obj/item/held = source.get_active_held_item()
	if(held)
		candidates += held
	if(source.pulling)
		candidates += source.pulling
	if(!length(candidates))
		return
	for(var/atom/movable/candidate as anything in candidates)
		RegisterSignal(candidate, COMSIG_MOVABLE_PRE_THROW, PROC_REF(boost_throw), override = TRUE)
	addtimer(CALLBACK(src, PROC_REF(clear_throw_hooks), candidates), 0)

/// Signal proc for [COMSIG_MOVABLE_PRE_THROW] on a thrown candidate: freight.
/obj/item/organ/cyberimp/cyberware/atlas/proc/boost_throw(atom/movable/source, list/throw_args)
	SIGNAL_HANDLER
	if(throw_args[4] != owner) // someone else's throw, somehow
		return
	throw_args[2] += 2 // range
	throw_args[3] += 1 // speed

/obj/item/organ/cyberimp/cyberware/atlas/proc/clear_throw_hooks(list/candidates)
	for(var/atom/movable/candidate as anything in candidates)
		if(!QDELETED(candidate))
			UnregisterSignal(candidate, COMSIG_MOVABLE_PRE_THROW)

/**
 * Signal proc for [COMSIG_MOVABLE_PRE_THROW] on the BEARER: knockback
 * resist. Any throw of you that you didn't start travels half as far —
 * resist, not immunity, so hurl mechanics still read.
 */
/obj/item/organ/cyberimp/cyberware/atlas/proc/on_owner_thrown(mob/living/source, list/throw_args)
	SIGNAL_HANDLER
	if(organ_flags & ORGAN_FAILING)
		return
	if(throw_args[4] == source) // self-launched: jump pads etc. stay honest
		return
	var/range = throw_args[2]
	if(range <= 1)
		return
	throw_args[2] = max(1, round(range / 2))
	source.balloon_alert(source, "frame holds!")

// =========================================================================
// VOID-RATED CHASSIS
// =========================================================================

/// Breath reserve: fifteen minutes of vacuum.
#define CYBERWARE_VOID_CHASSIS_RESERVE (15 MINUTES)
/// Reserve spent per blocked breath (one breath ~ every 8s of life ticks).
#define CYBERWARE_VOID_CHASSIS_DRAIN (8 SECONDS)
/// Reserve regained per free breath in air.
#define CYBERWARE_VOID_CHASSIS_REFILL (16 SECONDS)
/// Mag-sole gait tax while engaged (advanced-magboot precedent).
#define CYBERWARE_VOID_CHASSIS_SOLE_SLOWDOWN 0.5

/**
 * # Void-Rated Chassis (T3, chest, seal slot, load 6)
 *
 * The "naked in the void" flex: full pressure seal, cold immunity, fifteen
 * minutes of internal air on the Second Wind breath-block pattern (no tank
 * object anywhere), and toggleable mag-soles. It grants NO thrust and NO
 * armor — EVA mobility and plate remain the MODsuit's job. Top rung of the
 * seal ladder; evicts Second Wind, competes with Coolant Loops.
 */
/obj/item/organ/cyberimp/cyberware/void_chassis
	name = "\improper Void-Rated chassis"
	desc = "A full-torso rebuild in vacuum-rated laminate: sealed joints, insulated marrow, a fifteen-minute air bladder and electromagnet soles. The void stops being a wall and starts being weather."
	icon_state = "void_chassis"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_SEAL
	w_class = WEIGHT_CLASS_NORMAL
	chrome_load = 6
	tier = CYBERWARE_TIER_3
	aug_overlay = "void_chassis"
	organ_traits = list(TRAIT_RESISTLOWPRESSURE, TRAIT_RESISTCOLD)
	actions_types = list(/datum/action/item_action/organ_action/toggle)
	/// Breathable reserve remaining, in deciseconds of breathing covered.
	var/reserve = CYBERWARE_VOID_CHASSIS_RESERVE
	/// TRUE while feeding the bearer from reserve.
	var/engaged = FALSE
	/// TRUE while the mag-soles are clamped.
	var/soles_engaged = FALSE

/obj/item/organ/cyberimp/cyberware/void_chassis/examine(mob/user)
	. = ..()
	var/minutes_left = round(reserve / (1 MINUTES), 0.1)
	. += span_notice("The air gauge reads <b>[minutes_left]</b> minute\s of reserve[reserve < CYBERWARE_VOID_CHASSIS_RESERVE ? ", climbing when its bearer breathes freely" : " — full"].")

/obj/item/organ/cyberimp/cyberware/void_chassis/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(organ_owner, COMSIG_CARBON_ATTEMPT_BREATHE, PROC_REF(on_attempt_breathe))

/obj/item/organ/cyberimp/cyberware/void_chassis/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(organ_owner, COMSIG_CARBON_ATTEMPT_BREATHE)
	engaged = FALSE
	if(soles_engaged)
		set_soles(organ_owner, FALSE)

/// The mag-sole toggle button (organ_action/toggle routes here).
/obj/item/organ/cyberimp/cyberware/void_chassis/ui_action_click()
	if(organ_flags & ORGAN_FAILING)
		owner.balloon_alert(owner, "chrome offline!")
		return
	set_soles(owner, !soles_engaged)

/// Clamps or releases the electromagnet soles.
/obj/item/organ/cyberimp/cyberware/void_chassis/proc/set_soles(mob/living/carbon/wearer, new_state)
	if(soles_engaged == new_state || !wearer)
		return
	soles_engaged = new_state
	if(soles_engaged)
		wearer.add_traits(list(TRAIT_NO_SLIP_ALL, TRAIT_NEGATES_GRAVITY), REF(src))
		wearer.add_movespeed_modifier(/datum/movespeed_modifier/cyberware_magsoles)
		wearer.balloon_alert(wearer, "mag-soles clamped")
	else
		wearer.remove_traits(list(TRAIT_NO_SLIP_ALL, TRAIT_NEGATES_GRAVITY), REF(src))
		wearer.remove_movespeed_modifier(/datum/movespeed_modifier/cyberware_magsoles)
		wearer.balloon_alert(wearer, "mag-soles released")
	playsound(wearer, 'sound/effects/servostep.ogg', 40, TRUE)

/datum/movespeed_modifier/cyberware_magsoles
	multiplicative_slowdown = CYBERWARE_VOID_CHASSIS_SOLE_SLOWDOWN

/**
 * Signal proc for [COMSIG_CARBON_ATTEMPT_BREATHE] — the Second Wind reserve
 * pattern verbatim, with a bigger bladder: refill in air, feed and block the
 * breath in anything unbreathable, settle the alert bookkeeping ourselves.
 */
/obj/item/organ/cyberimp/cyberware/void_chassis/proc/on_attempt_breathe(mob/living/carbon/source, seconds_per_tick, times_fired)
	SIGNAL_HANDLER
	if(organ_flags & ORGAN_FAILING)
		return NONE
	if(HAS_TRAIT(source, TRAIT_NOBREATH))
		return NONE
	if(source.internal || source.external)
		return NONE
	if(environment_is_breathable(source))
		if(engaged)
			set_engaged(source, FALSE)
		if(reserve < CYBERWARE_VOID_CHASSIS_RESERVE)
			reserve = min(reserve + CYBERWARE_VOID_CHASSIS_REFILL, CYBERWARE_VOID_CHASSIS_RESERVE)
		return NONE
	if(reserve <= 0)
		if(engaged)
			set_engaged(source, FALSE)
			source.balloon_alert(source, "air reserve empty!")
		return NONE
	if(!engaged)
		set_engaged(source, TRUE)
	reserve = max(reserve - CYBERWARE_VOID_CHASSIS_DRAIN, 0)
	source.failed_last_breath = FALSE
	source.clear_alert(ALERT_NOT_ENOUGH_OXYGEN)
	return COMSIG_CARBON_BLOCK_BREATH

/// Engage/disengage feedback beats.
/obj/item/organ/cyberimp/cyberware/void_chassis/proc/set_engaged(mob/living/carbon/source, new_state)
	if(engaged == new_state)
		return
	engaged = new_state
	if(engaged)
		source.balloon_alert(source, "chassis reserve engaged")
		playsound(source, 'sound/machines/hiss.ogg', 30, TRUE)
	else
		source.balloon_alert(source, "chassis reserve disengaged")

/**
 * Whether the surroundings hold breathable O2 — Second Wind's check, shared
 * shape: O2 partial pressure (plus pluoxium at its 8x weight) against the
 * lungs' 16 kPa floor. O2-only on purpose; exotic breathers get nothing
 * from a bladder of baseline air.
 */
/obj/item/organ/cyberimp/cyberware/void_chassis/proc/environment_is_breathable(mob/living/carbon/source)
	var/datum/gas_mixture/environment = source.loc?.return_air()
	if(!environment)
		return FALSE
	var/total_moles = environment.total_moles()
	if(total_moles <= 0)
		return FALSE
	var/list/env_gases = environment.gases
	var/oxygen_moles = env_gases[/datum/gas/oxygen] ? env_gases[/datum/gas/oxygen][MOLES] : 0
	var/pluoxium_moles = env_gases[/datum/gas/pluoxium] ? env_gases[/datum/gas/pluoxium][MOLES] : 0
	var/oxygen_pp = environment.return_pressure() * ((oxygen_moles + PLUOXIUM_PROPORTION * pluoxium_moles) / total_moles)
	return oxygen_pp >= CYBERWARE_BREATHABLE_O2_KPA

// =========================================================================
// RIGGER SOCKET
// =========================================================================

/// Walking away this soon after a hard hit rips the link out ugly.
#define CYBERWARE_RIGGER_JACKOUT_WINDOW (3 SECONDS)

/**
 * # Rigger Socket (T3, head, load 4)
 *
 * Pilot chrome: a skull jack that binds your proprioception into the hull
 * while you are flying it. "Jacked in" means actively operating a helm
 * console of the ship you are standing on (this fork's helms are consoles,
 * not chairs — there is no buckling to hook). While jacked in, hull hits
 * and missile impacts land as pain: red flash, camera shake, a jolt of
 * jitter. Hazard brushes and shield hits arrive as softer static. Step away
 * from the console within three seconds of a hard hit and the link tears
 * out with you still in it — a knockdown and a bad moment.
 *
 * (The design's "sensor readout sharpens" clause was dropped at build time:
 * sensor range is a ship+techweb property with no per-pilot hook, and we
 * don't fake one.)
 */
/obj/item/organ/cyberimp/cyberware/rigger
	name = "\improper Rigger socket"
	desc = "A skull jack that patches ship telemetry straight into the parts of you that feel. Pilots swear by it. Pilots also swear during it."
	icon_state = "rigger"
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_CYBERWARE_RIGGER
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 4
	tier = CYBERWARE_TIER_3
	/// The ship we're currently wired into (the one the bearer stands on).
	var/obj/structure/overmap/ship/linked_ship
	/// world.time of the last hard hit felt through the link.
	var/last_hard_hit = 0
	/// TRUE when the last hard hit landed while jacked in — arms the
	/// jack-out stagger.
	var/jackout_armed = FALSE

/obj/item/organ/cyberimp/cyberware/rigger/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(organ_owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_owner_moved))

/obj/item/organ/cyberimp/cyberware/rigger/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(organ_owner, COMSIG_MOVABLE_MOVED)
	relink(null)

/obj/item/organ/cyberimp/cyberware/rigger/Destroy()
	relink(null)
	return ..()

/// Organs tick with carbon life; each tick we make sure we're wired into
/// whatever hull the bearer is actually standing on.
/obj/item/organ/cyberimp/cyberware/rigger/on_life(seconds_per_tick, times_fired)
	. = ..()
	var/obj/structure/overmap/ship/current = get_ship_from_atom(owner)
	if(current != linked_ship)
		relink(current)

/// Swaps our damage-feed registration from one hull to another.
/obj/item/organ/cyberimp/cyberware/rigger/proc/relink(obj/structure/overmap/ship/new_ship)
	if(linked_ship)
		UnregisterSignal(linked_ship, list(
			COMSIG_SHIP_HULL_HIT,
			COMSIG_SHIP_MISSILE_IMPACT,
			COMSIG_SHIP_HAZARD_TRIGGERED,
			COMSIG_SHIP_SHIELD_HIT,
			COMSIG_QDELETING,
		))
	linked_ship = new_ship
	if(!linked_ship)
		return
	RegisterSignal(linked_ship, COMSIG_SHIP_HULL_HIT, PROC_REF(on_hull_hit))
	RegisterSignal(linked_ship, COMSIG_SHIP_MISSILE_IMPACT, PROC_REF(on_missile_impact))
	RegisterSignal(linked_ship, COMSIG_SHIP_HAZARD_TRIGGERED, PROC_REF(on_hazard))
	RegisterSignal(linked_ship, COMSIG_SHIP_SHIELD_HIT, PROC_REF(on_shield_hit))
	RegisterSignal(linked_ship, COMSIG_QDELETING, PROC_REF(on_ship_gone))

/obj/item/organ/cyberimp/cyberware/rigger/proc/on_ship_gone(datum/source)
	SIGNAL_HANDLER
	relink(null)

/// TRUE while the bearer is actively flying the linked ship — a live helm
/// UI open on one of its consoles.
/obj/item/organ/cyberimp/cyberware/rigger/proc/jacked_in()
	if(!linked_ship || !owner)
		return FALSE
	if(organ_flags & ORGAN_FAILING)
		return FALSE
	for(var/obj/machinery/computer/helm/console as anything in linked_ship.helm_consoles)
		if(QDELETED(console) || console.viewer)
			continue
		if(SStgui.get_open_ui(owner, console))
			return TRUE
	return FALSE

/// Signal proc for [COMSIG_SHIP_HULL_HIT]: laser fire chewing the hull.
/obj/item/organ/cyberimp/cyberware/rigger/proc/on_hull_hit(datum/source, turf/impact_loc)
	SIGNAL_HANDLER
	feel_hit(hard = TRUE, flavor = "The hull tears somewhere aft — you feel it like your own skin splitting.")

/// Signal proc for [COMSIG_SHIP_MISSILE_IMPACT]: the big one.
/obj/item/organ/cyberimp/cyberware/rigger/proc/on_missile_impact(datum/source, missile, turf/impact_turf)
	SIGNAL_HANDLER
	feel_hit(hard = TRUE, flavor = "A missile lands on the hull and your whole skeleton rings with it.")

/// Signal proc for [COMSIG_SHIP_HAZARD_TRIGGERED]: weather static.
/obj/item/organ/cyberimp/cyberware/rigger/proc/on_hazard(datum/source, hazard)
	SIGNAL_HANDLER
	feel_hit(hard = FALSE, flavor = "The storm crawls across the sensor skin like gooseflesh.")

/// Signal proc for [COMSIG_SHIP_SHIELD_HIT]: someone knocking politely.
/obj/item/organ/cyberimp/cyberware/rigger/proc/on_shield_hit(datum/source, damage_absorbed, turf/impact_location)
	SIGNAL_HANDLER
	feel_hit(hard = FALSE, flavor = "The shields flare white-hot across your senses.")

/// The pain feed. Only lands while jacked in; hard hits arm the jack-out
/// stagger and slam the screen, soft ones just prickle.
/obj/item/organ/cyberimp/cyberware/rigger/proc/feel_hit(hard, flavor)
	if(!jacked_in())
		return
	if(hard)
		shake_camera(owner, 5, 3)
		owner.set_jitter_if_lower(3 SECONDS)
		to_chat(owner, span_userdanger(flavor))
		owner.remove_client_colour(REF(src))
		owner.add_client_colour(/datum/client_colour/cyberware_rigger_pain, REF(src))
		addtimer(CALLBACK(owner, TYPE_PROC_REF(/mob, remove_client_colour), REF(src)), 0.8 SECONDS)
		last_hard_hit = world.time
		jackout_armed = TRUE
	else
		shake_camera(owner, 2, 1)
		to_chat(owner, span_warning(flavor))

/**
 * Signal proc for [COMSIG_MOVABLE_MOVED] on the bearer: stepping away from
 * the console inside the jack-out window after a hard hit rips the link.
 */
/obj/item/organ/cyberimp/cyberware/rigger/proc/on_owner_moved(datum/source)
	SIGNAL_HANDLER
	if(!jackout_armed)
		return
	if(world.time - last_hard_hit > CYBERWARE_RIGGER_JACKOUT_WINDOW)
		jackout_armed = FALSE
		return
	jackout_armed = FALSE
	var/mob/living/pilot = owner
	if(!pilot)
		return
	pilot.Knockdown(1.5 SECONDS)
	pilot.set_jitter_if_lower(6 SECONDS)
	pilot.balloon_alert(pilot, "jacked out mid-shock!")
	to_chat(pilot, span_warning("You tear out of the link with the hit still echoing in it and the deck comes up to meet you."))

/datum/client_colour/cyberware_rigger_pain
	priority = CLIENT_COLOR_IMPORTANT_PRIORITY
	color = list(1, 0, 0, 0.35, 0.85, 0, 0.35, 0, 0.85)
	fade_in = 0
	fade_out = 5

#undef CYBERWARE_GHOSTSKIN_ALPHA
#undef CYBERWARE_GHOSTSKIN_DURATION
#undef CYBERWARE_LAZARUS_COOLDOWN
#undef CYBERWARE_LAZARUS_WINDUP
#undef CYBERWARE_LAZARUS_HEAL_TO
#undef CYBERWARE_VOID_CHASSIS_RESERVE
#undef CYBERWARE_VOID_CHASSIS_DRAIN
#undef CYBERWARE_VOID_CHASSIS_REFILL
#undef CYBERWARE_VOID_CHASSIS_SOLE_SLOWDOWN
#undef CYBERWARE_RIGGER_JACKOUT_WINDOW
