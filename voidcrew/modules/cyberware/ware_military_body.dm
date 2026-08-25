/**
 * # Tier 3 military chrome: body systems
 *
 * Ghostskin Weave, Slabskin Plate, Lazarus Node, Atlas Frame, Rigger Socket.
 * All chest/head chrome on the generic cyberware base; every strong effect
 * here keeps the PvP contract, a visible telegraph and a counter.
 */

// =========================================================================
// GHOSTSKIN WEAVE
// =========================================================================

/// Cloak alpha. NEVER 0: a shimmer stays readable point-blank.
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
 * attack, shoot, get struck, get cuffed, or eat an EMP, the break-trigger
 * list is the MOD stealth module's, plus gunfire (nothing uncounterable
 * fires from inside a cloak on this server).
 */
/obj/item/organ/cyberimp/cyberware/ghostskin
	name = "\improper Ghostskin weave"
	desc = "A subdermal lattice of refraction cells. Switched on, you're a faint heat-shimmer and not much else. Swing at anyone and the field drops, mid-swing, out in the open."
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
		span_notice("The weave bends the light around you. Ten seconds."),
	)
	// The MOD stealth break list (modules_ninja.dm), minus bump-off, plus
	// gunfire, shooting from inside a cloak breaks it here.
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
			span_warning("The weave collapses[reason ? ", [reason]" : ""]. You are visible."),
		)

/// Signal proc for the blanket break triggers: any attack, hit or cuff.
/obj/item/organ/cyberimp/cyberware/ghostskin/proc/on_break_trigger(datum/source)
	SIGNAL_HANDLER
	break_camo(owner, reason = "field contact")

/// Signal proc for [COMSIG_LIVING_UNARMED_ATTACK]: MOD precedent, only
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

/// Signal proc for [COMSIG_MOVABLE_MOVED]: the moving-shimmer ripple.
/// Motion makes you briefly MORE visible. Free counterplay for sharp eyes.
/obj/item/organ/cyberimp/cyberware/ghostskin/proc/on_camo_move(datum/source)
	SIGNAL_HANDLER
	var/mob/living/wearer = owner
	if(!wearer || !camo_active)
		return
	animate(wearer, alpha = 90, time = 0.15 SECONDS)
	animate(alpha = CYBERWARE_GHOSTSKIN_ALPHA, time = 0.35 SECONDS)

/datum/action/cooldown/cyberware/ghostskin_cloak
	name = "Ghostskin Field"
	desc = "Ten seconds of optical camo. Attacking, shooting, taking a hit or an EMP drops the field. Anyone standing right next to you still sees you."
	button_icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	button_icon_state = "act_ghostskin"
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
 * Serious all-round subdermal armor: the top rung of the dermal ladder,
 * evicting Dermal Mesh. Every solid hit visibly SPARKS and ricochets off
 * the plate, so everyone in the fight can see you are armored under the
 * jumpsuit; that legibility is the PvP tax on built-in plate. Physiology
 * armor persists through species changes by design (the physiology datum
 * survives them), and is added/removed symmetrically through the
 * failing-gated passive hooks (BAL-4): an EMP-scrambled or browned-out
 * plate stops armoring you until it reboots or gets repaired.
 */
/obj/item/organ/cyberimp/cyberware/slabskin
	name = "\improper Slabskin plate"
	desc = "Sintered ceramic scales grown into the skin in overlapping courses. Bullets leave scuffs and a noise like a dropped pan, and not a great deal else."
	icon_state = "slabskin"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_DERMAL
	w_class = WEIGHT_CLASS_NORMAL
	chrome_load = 6
	tier = CYBERWARE_TIER_3
	aug_overlay = "slabskin"
	/// TRUE while the plate armor is mixed into the bearer's physiology.
	/// Guards the failing-gated passive hooks against double add/subtract.
	var/plate_armor_applied = FALSE

/obj/item/organ/cyberimp/cyberware/slabskin/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(organ_owner, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(on_damaged))

/obj/item/organ/cyberimp/cyberware/slabskin/chrome_passives_on(mob/living/carbon/bearer)
	. = ..()
	if(plate_armor_applied || !ishuman(bearer))
		return
	plate_armor_applied = TRUE
	var/mob/living/carbon/human/human_bearer = bearer
	human_bearer.physiology.armor = human_bearer.physiology.armor.add_other_armor(/datum/armor/cyberware_slabskin)

/obj/item/organ/cyberimp/cyberware/slabskin/chrome_passives_off(mob/living/carbon/bearer)
	. = ..()
	if(!plate_armor_applied)
		return
	plate_armor_applied = FALSE // reset before the validity skip, or the plate never re-arms after a bearer deletes
	if(!ishuman(bearer) || QDELETED(bearer))
		return
	var/mob/living/carbon/human/human_bearer = bearer
	human_bearer.physiology.armor = human_bearer.physiology.armor.subtract_other_armor(/datum/armor/cyberware_slabskin)

/obj/item/organ/cyberimp/cyberware/slabskin/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
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
/// The visible seizure between crit entry and the jolt, the kill window.
#define CYBERWARE_LAZARUS_WINDUP (1 SECONDS)
/// Fraction of max health the jolt restores you to.
#define CYBERWARE_LAZARUS_HEAL_TO 0.3

/**
 * # Lazarus Node (T3, chest, tg heart-aid slot, load 5)
 *
 * The anti-crit charge bank. It rides tg's ORGAN_SLOT_HEART_AID, so it
 * EVICTS the printable reviver implant; the ladder, not a stack, and does
 * the opposite of the reviver's slow trickle: once per six minutes, the
 * moment you drop into crit it screams up to charge for one full second
 * (visible seizure, audible whine. You are killable the whole time) and
 * then slams you back ON YOUR FEET at 30% health with a defib crack heard
 * down the corridor. It does nothing for the dead; overkill straight past
 * crit skips the node entirely. That windup and that ceiling are the PvP
 * contract: confirm your kill.
 */
/obj/item/organ/cyberimp/cyberware/lazarus
	name = "\improper Lazarus node"
	desc = "A capacitor bank sunk fist-deep in the chest, wired straight across the heart. When you go down it spends a second charging up, then shocks you back onto your feet. Rebuilding that charge takes a lot longer."
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
		. += span_notice("The charge bank reads <b>RECHARGING</b>, [DisplayTimeText(COOLDOWN_TIMELEFT(src, jolt_cooldown))] left.")

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
	if(new_stat == STABLE || new_stat == DEAD)
		return
	if(old_stat == DEAD)
		return
	if(!COOLDOWN_FINISHED(src, jolt_cooldown))
		return
	jolting = TRUE
	COOLDOWN_START(src, jolt_cooldown, CYBERWARE_LAZARUS_COOLDOWN)
	source.visible_message(
		span_boldwarning("[source] seizes, something under [source.p_their()] ribs whines up to full charge!"),
		span_userdanger("The Lazarus node screams up to charge..."),
	)
	playsound(source, 'sound/machines/defib/defib_charge.ogg', 75, TRUE)
	source.set_jitter_if_lower(4 SECONDS)
	source.do_jitter_animation(200)
	addtimer(CALLBACK(src, PROC_REF(jolt)), CYBERWARE_LAZARUS_WINDUP)

/// The discharge: heal to 30%, clear the floor out from under every stun,
/// and stand the patient up with a thunderclap. Skipped if they died (or
/// recovered) during the windup, that second belongs to the attacker.
/obj/item/organ/cyberimp/cyberware/lazarus/proc/jolt()
	jolting = FALSE
	var/mob/living/carbon/patient = owner
	if(QDELETED(src) || QDELETED(patient))
		return
	if(organ_flags & ORGAN_FAILING)
		return
	if(patient.stat == DEAD || patient.stat == STABLE)
		return
	var/needed = (patient.maxHealth * CYBERWARE_LAZARUS_HEAL_TO) - patient.health
	if(needed > 0)
		var/oxy_heal = min(needed, patient.get_oxy_loss())
		if(oxy_heal > 0)
			patient.adjust_oxy_loss(-oxy_heal, updating_health = FALSE)
			needed -= oxy_heal
		var/brute = patient.get_brute_loss()
		var/burn = patient.get_fire_loss()
		var/pool = brute + burn
		if(needed > 0 && pool > 0)
			patient.adjust_brute_loss(-(needed * (brute / pool)), updating_health = FALSE)
			patient.adjust_fire_loss(-(needed * (burn / pool)), updating_health = FALSE)
		patient.updatehealth()
	patient.SetStun(0)
	patient.SetKnockdown(0)
	patient.SetImmobilized(0)
	patient.SetParalyzed(0)
	patient.SetUnconscious(0)
	patient.set_stamina_loss(0)
	patient.set_resting(FALSE, silent = TRUE, instant = TRUE)
	playsound(patient, 'sound/machines/defib/defib_zap.ogg', 100, TRUE)
	do_sparks(3, TRUE, patient)
	patient.emote("gasp")
	patient.set_jitter_if_lower(20 SECONDS)
	patient.visible_message(
		span_boldwarning("[patient] jolts bolt upright with a thunderclap of current!"),
		span_userdanger("Your heart slams back into rhythm, ON YOUR FEET."),
	)
	patient.balloon_alert(patient, "lazarus jolt!")

// =========================================================================
// ATLAS FRAME
// =========================================================================

/// Held by a bearer whose skeleton simply does not break. Blocks the whole
/// bone wound series, dislocations, hairline fractures, compound fractures,
/// at the wound system's own gate, and nothing else. Every other wound series
/// lands on its bearer exactly as it lands on anyone.
#define TRAIT_CYBERWARE_UNBREAKABLE_BONES "cyberware_unbreakable_bones"

/**
 * # Atlas Frame (T3, chest, frame slot, load 4)
 *
 * A load-bearing endoskeletal truss. It holds the skeleton and nothing else:
 * bones cannot break (no dislocations, no fractures) and nothing takes a
 * limb off you. Everything soft is still on its own. Slashes, punctures,
 * burns and the bleeding that comes with them land completely normally, so
 * the frame answers hammers, falls and shrapnel, not a knife.
 *
 * On top of the skeleton, your throws carry real freight (+2 tiles, +1 speed)
 * and forced knockback against you is halved, a warframe sweep that hurls
 * everyone else across the hall moves you one polite step.
 */
/obj/item/organ/cyberimp/cyberware/atlas
	name = "\improper Atlas frame"
	desc = "A titanium truss bolted through the spine and ribs. Nothing breaks your bones and nothing takes a limb off you. Everything softer than bone is still your problem, and anything you throw leaves your hand like it was fired."
	icon_state = "atlas"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_FRAME
	w_class = WEIGHT_CLASS_NORMAL
	chrome_load = 4
	tier = CYBERWARE_TIER_3
	organ_traits = list(TRAIT_NODISMEMBER, TRAIT_CYBERWARE_UNBREAKABLE_BONES)

/obj/item/organ/cyberimp/cyberware/atlas/examine(mob/user)
	. = ..()
	. += span_notice("Covers the skeleton only: no dislocations, no fractures, and no losing a limb. Slashes, punctures, burns and bleeding are untouched.")

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
 * resist. Any throw of you that you didn't start travels half as far.
 * Resist, not immunity, so hurl mechanics still read.
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

/**
 * The bone half of the frame, hooked at the wound system's own gate.
 *
 * /datum/wound_pregen_data/bone is the abstract parent of exactly the three
 * bone wounds (joint dislocation, hairline fracture, compound fracture) and
 * every other series (slash, pierce, burn) hangs off a different parent, so
 * narrowing here narrows to bone and only bone. This one gate covers BOTH
 * ways a wound can arrive: the random roll in check_wounding(), and
 * apply_wound() itself, which re-checks it (see _wounds.dm), so a scripted
 * or forced fracture is refused too, and there is no second place to patch.
 *
 * Deliberately NOT TRAIT_NEVER_WOUNDED: that trait short-circuits the whole
 * wound system, which made the frame immune to being cut, shot or burned as
 * well. Bones and limbs are the promise; soft tissue is not.
 *
 * The default argument values below are copied verbatim from the parent and
 * MUST stay that way. DM fills missing arguments from the signature of the
 * proc it actually dispatches to (this one) and callers rely on them:
 * /datum/wound/can_be_applied_to() passes only the limb and old_wound, so
 * dropping the `suggested_wounding_type` default would hand
 * wounding_types_valid() a null type and refuse EVERY bone wound, for
 * everybody, silently.
 *
 * The 2026 upstream merge made the wounding type singular: the parameter is no
 * longer a list, and the var it defaults from is `required_wounding_type`.
 */
/datum/wound_pregen_data/bone/can_be_applied_to(obj/item/bodypart/limb, suggested_wounding_type = required_wounding_type, datum/wound/old_wound, random_roll = FALSE, duplicates_allowed = src.duplicates_allowed, care_about_existing_wounds = TRUE)
	// Parent first: it is what guarantees limb and limb.owner are real before
	// we go looking for a trait on the owner.
	. = ..()
	if(!.)
		return .
	if(HAS_TRAIT(limb.owner, TRAIT_CYBERWARE_UNBREAKABLE_BONES))
		return FALSE

// =========================================================================
// RIGGER SOCKET
// =========================================================================

/// Split-attention tax while the uplink is open. Half of you is flying a
/// ship; the half still standing in the corridor walks.
#define CYBERWARE_RIGGER_SLOWDOWN 1

/**
 * # Rigger Socket (T3, head, load 4)
 *
 * Remote helm access, and that is the whole piece. A skull jack that talks to
 * the hull you are standing on: hit the button and the ship's helm console
 * opens in front of you from anywhere aboard. Fly from engineering, from a
 * corridor, from medbay with both hands in someone's chest, the pilot never
 * has to be on the bridge, and the bridge never has to be crewed.
 *
 * It is a relay, not a second bridge. The uplink borrows a REAL helm console
 * and drives it exactly as if the bearer were standing at the keyboard: the
 * console's own crew authorization still applies, the ship's state limits
 * still apply, and everyone else working that console keeps their own window.
 * Lose every helm on the hull and the socket has nothing left to call, it
 * says so and refuses.
 *
 * What takes it down: leaving the hull, blacking out, closing the panel, the
 * console dying, the ship dying, the socket going dark (browned out or
 * damaged), or an EMP, which knocks the whole ware offline for the standard
 * chrome reboot through the base emp_act.
 *
 * The cost is attention. While the uplink is open the bearer moves at a heavy
 * walk (CYBERWARE_RIGGER_SLOWDOWN): you can hold the helm from cover, but you
 * cannot fly and outrun anyone at the same time. Bystanders get the matching
 * tell, the jack lights up and the pilot's eyes go somewhere else.
 */
/obj/item/organ/cyberimp/cyberware/rigger
	name = "\improper Rigger socket"
	desc = "A skull jack that patches a ship's helm straight into your head. Anywhere aboard, you can fly it, as long as the ship still has a helm console for the socket to talk to, and as long as you don't mind walking while you do it."
	icon_state = "rigger"
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_CYBERWARE_RIGGER
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 4
	tier = CYBERWARE_TIER_3
	actions_types = list(/datum/action/cooldown/cyberware/rigger_uplink)
	/// The ship we're currently wired into (the one the bearer stands on).
	var/obj/structure/overmap/ship/linked_ship
	/// The helm console the uplink is driving right now, or null when it's down.
	var/obj/machinery/computer/helm/uplink_console

/obj/item/organ/cyberimp/cyberware/rigger/examine(mob/user)
	. = ..()
	. += span_notice("Opens the helm of whatever ship its bearer stands on, from anywhere on it. It borrows a real console. A hull with no helm left has nothing to answer with.")
	if(!owner)
		return
	if(!linked_ship)
		. += span_warning("No hull on the other end of the socket.")
	else if(!find_console())
		. += span_warning("[linked_ship] has no helm console answering.")
	else
		. += span_notice("Linked to <b>[linked_ship.name]</b>.")

/obj/item/organ/cyberimp/cyberware/rigger/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(organ_owner, COMSIG_MOB_STATCHANGE, PROC_REF(on_stat_change))

/obj/item/organ/cyberimp/cyberware/rigger/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(organ_owner, COMSIG_MOB_STATCHANGE)
	// owner is already null by the time this runs (see mob_remove), so the
	// movement tax and the window have to come off the mob we were handed.
	drop_uplink(organ_owner, silent = TRUE)
	relink(null)

/obj/item/organ/cyberimp/cyberware/rigger/Destroy()
	drop_uplink(owner, silent = TRUE)
	relink(null)
	return ..()

/obj/item/organ/cyberimp/cyberware/rigger/emp_act(severity)
	. = ..() // the base already started the standard chrome reboot
	if(. & EMP_PROTECT_SELF)
		return
	drop_uplink(owner, reason = "the pulse walks straight up the jack")

/**
 * Organs tick with carbon life. Each tick: re-wire to whatever hull the
 * bearer is actually standing on, then check that an open uplink still has
 * every one of its legs, a live socket, a console that answers, and a window
 * the bearer hasn't already shut.
 */
/obj/item/organ/cyberimp/cyberware/rigger/on_life(seconds_per_tick, times_fired)
	. = ..()
	relink(get_ship_from_atom(owner))
	if(!uplink_console)
		return
	if(organ_flags & ORGAN_FAILING)
		drop_uplink(owner, reason = "the socket has gone dark")
		return
	if(!uplink_covers(uplink_console, owner))
		drop_uplink(owner, reason = "the console on the other end stopped answering")
		return
	// Shutting the panel by hand IS jacking out; nothing to announce.
	if(!SStgui.get_open_ui(owner, uplink_console))
		drop_uplink(owner, silent = TRUE)

/**
 * Swaps which hull we're wired into. Any open uplink belongs to the hull we
 * are leaving, so it goes down with the change.
 */
/obj/item/organ/cyberimp/cyberware/rigger/proc/relink(obj/structure/overmap/ship/new_ship)
	if(linked_ship == new_ship)
		return
	if(uplink_console)
		drop_uplink(owner, reason = new_ship ? "you crossed onto another hull" : "you stepped off the hull")
	if(linked_ship)
		UnregisterSignal(linked_ship, COMSIG_QDELETING)
	linked_ship = new_ship
	if(!linked_ship)
		return
	RegisterSignal(linked_ship, COMSIG_QDELETING, PROC_REF(on_ship_gone))

/// Signal proc for [COMSIG_QDELETING] on the linked hull: no ship, no helm.
/obj/item/organ/cyberimp/cyberware/rigger/proc/on_ship_gone(datum/source)
	SIGNAL_HANDLER
	relink(null)

/// Signal proc for [COMSIG_QDELETING] on the borrowed console: someone just
/// shot the far end of the link out.
/obj/item/organ/cyberimp/cyberware/rigger/proc/on_console_gone(datum/source)
	SIGNAL_HANDLER
	drop_uplink(owner, reason = "the console on the other end just died")

/**
 * Signal proc for [COMSIG_MOB_STATCHANGE]: nobody flies a ship from inside a
 * blackout. Dropping the link here rather than waiting on the UI status poll
 * also guarantees the movement tax comes off before the bearer wakes back up,
 * on_life doesn't run at all while its owner is dead.
 */
/obj/item/organ/cyberimp/cyberware/rigger/proc/on_stat_change(mob/living/carbon/source, new_stat, old_stat)
	SIGNAL_HANDLER
	if(new_stat == STABLE)
		return
	drop_uplink(source, reason = "you go under")

/**
 * A helm on the linked hull the uplink can actually drive: alive, wired to
 * this ship, powered, and not one of the view-only viewscreens, those refuse
 * every control topic, so relaying one would hand the bearer a dead panel.
 *
 * Typed loop rather than `as anything`: a hard-deleted console leaves a null
 * in helm_consoles in place, and the istype filter is what skips it.
 */
/obj/item/organ/cyberimp/cyberware/rigger/proc/find_console()
	RETURN_TYPE(/obj/machinery/computer/helm)
	if(!linked_ship)
		return null
	for(var/obj/machinery/computer/helm/console in linked_ship.helm_consoles)
		if(console.viewer || (console.machine_stat & (BROKEN | NOPOWER)))
			continue
		return console
	return null

/**
 * Whether this socket is relaying `console` to `user` right now. THE single
 * authority on that question: the helm's ui_status exemption at the bottom of
 * this section and the socket's own upkeep both read it, so the open window
 * and the organ can never disagree about whether the uplink is live.
 */
/obj/item/organ/cyberimp/cyberware/rigger/proc/uplink_covers(obj/machinery/computer/helm/console, mob/user)
	if(QDELETED(console) || console != uplink_console)
		return FALSE
	if(!owner || user != owner || owner.stat != STABLE)
		return FALSE
	if(organ_flags & ORGAN_FAILING)
		return FALSE
	if(console.viewer || (console.machine_stat & (BROKEN | NOPOWER)))
		return FALSE
	if(!linked_ship || console.current_ship != linked_ship)
		return FALSE
	// Last, because it walks every mobile docking port: the bearer still has
	// to be standing on the hull they jacked into.
	return get_ship_from_atom(owner) == linked_ship

/**
 * Brings the uplink up on a console of the linked hull. Every refusal names
 * which of the three things is missing, a hull, a console, or a socket that
 * still works. Returns TRUE only if a helm window actually opened.
 */
/obj/item/organ/cyberimp/cyberware/rigger/proc/open_uplink(mob/living/carbon/pilot)
	if(!pilot || pilot != owner || uplink_console)
		return FALSE
	if(organ_flags & ORGAN_FAILING)
		pilot.balloon_alert(pilot, "socket offline!")
		return FALSE
	if(!linked_ship)
		pilot.balloon_alert(pilot, "no hull to reach")
		to_chat(pilot, span_warning("The socket casts around for a hull and finds solid ground. You have to be aboard a ship."))
		return FALSE
	var/obj/machinery/computer/helm/console = find_console()
	if(!console)
		pilot.balloon_alert(pilot, "no helm answering!")
		to_chat(pilot, span_warning("Nothing aboard [linked_ship] answers the uplink. The socket borrows a helm console, and there isn't a working one left on the ship."))
		return FALSE
	uplink_console = console
	RegisterSignal(console, COMSIG_QDELETING, PROC_REF(on_console_gone))
	pilot.add_movespeed_modifier(/datum/movespeed_modifier/cyberware_rigger)
	playsound(pilot, 'sound/machines/terminal/terminal_on.ogg', 40, TRUE)
	cyberware_ink_pulse(pilot, CYBERWARE_INK_HARD)
	pilot.visible_message(
		span_notice("The jack behind [pilot]'s ear lights up, and [pilot.p_their()] eyes go somewhere else."),
		span_notice("The uplink catches [console] aboard [linked_ship]. You are flying the ship from here, at a walk."),
	)
	console.ui_interact(pilot)
	return TRUE

/**
 * Takes the uplink down, from any cause. Lifts the movement tax, shuts the
 * borrowed console's window FOR THIS BEARER ONLY, anyone else standing at
 * that console keeps working, and forgets the console. Safe to call when
 * there is nothing up.
 */
/obj/item/organ/cyberimp/cyberware/rigger/proc/drop_uplink(mob/living/carbon/pilot, reason, silent = FALSE)
	if(!uplink_console)
		return
	var/obj/machinery/computer/helm/console = uplink_console
	// Cleared before the window closes: closing it re-enters through the
	// ui_close hook below, which reads this var to decide whether to act.
	uplink_console = null
	UnregisterSignal(console, COMSIG_QDELETING)
	if(!pilot)
		return
	SStgui.close_user_uis(pilot, console)
	pilot.remove_movespeed_modifier(/datum/movespeed_modifier/cyberware_rigger)
	if(silent)
		return
	pilot.balloon_alert(pilot, "uplink down")
	to_chat(pilot, span_warning("The helm uplink drops[reason ? ", [reason]" : ""]."))
	playsound(pilot, 'sound/machines/terminal/terminal_off.ogg', 30, TRUE)

/// The split-attention tax. On for exactly as long as the uplink is up.
/datum/movespeed_modifier/cyberware_rigger
	multiplicative_slowdown = CYBERWARE_RIGGER_SLOWDOWN

/datum/action/cooldown/cyberware/rigger_uplink
	name = "Helm Uplink"
	desc = "Open the ship's helm from wherever you're standing. You move at a walk while it's up, and it drops if you leave the hull, black out, or lose the socket."
	button_icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	button_icon_state = "rigger"
	cooldown_time = 5 SECONDS
	click_to_activate = FALSE

/datum/action/cooldown/cyberware/rigger_uplink/Activate(atom/target)
	var/obj/item/organ/cyberimp/cyberware/rigger/socket = organ
	if(!istype(socket) || !iscarbon(owner))
		return FALSE
	if(socket.uplink_console)
		// Manual jack-out. No new cooldown: the press that opened it paid.
		socket.drop_uplink(owner, reason = "you pull out of the link")
		return TRUE
	if(!socket.open_uplink(owner))
		return TRUE // the refusal already said why; don't charge for it
	StartCooldown()
	return TRUE

// ---- Helm-side exemption -----------------------------------------------
// Both hooks below live here rather than in _helm.dm on purpose: the
// exemption belongs to the Rigger, not to the console. A helm console knows
// nothing about chrome, and every path through these overrides that isn't a
// live uplink falls straight through to stock behaviour.

/**
 * The one safety check the uplink waives is BEING THERE.
 *
 * tg's default state clamps a user at range to UI_CLOSE, and /atom/ui_status
 * clamps again on can_interact(). Between them a remote helm window would be
 * shut before it drew. A bearer whose uplink is live on THIS console instead
 * reads as if they were standing at it. Nothing else is waived: their
 * condition still goes through shared_ui_interaction(), so a restrained or
 * downed pilot degrades exactly as they would at the keyboard, and the crew
 * authorization check in ui_act() is untouched. An unconscious bearer, or one
 * who left the hull, fails uplink_covers() and falls back to the stock
 * UI_CLOSE, which is what actually shuts the window, on the next poll.
 */
/obj/machinery/computer/helm/ui_status(mob/user, datum/ui_state/state)
	. = ..()
	if(. >= UI_INTERACTIVE)
		return .
	if(!iscarbon(user))
		return .
	var/mob/living/carbon/carbon_user = user
	var/obj/item/organ/cyberimp/cyberware/rigger/socket = carbon_user.get_organ_slot(ORGAN_SLOT_CYBERWARE_RIGGER)
	if(!istype(socket) || !socket.uplink_covers(src, carbon_user))
		return .
	return max(., carbon_user.shared_ui_interaction(src))

/**
 * A rigger's helm window closing: by hand, by the console dying, by a jump
 * sequence clearing the room. IS jacking out. Catching it here lifts the
 * movement tax on the same tick instead of waiting for the next life tick.
 */
/obj/machinery/computer/helm/ui_close(mob/user)
	. = ..()
	if(!iscarbon(user))
		return
	var/mob/living/carbon/carbon_user = user
	var/obj/item/organ/cyberimp/cyberware/rigger/socket = carbon_user.get_organ_slot(ORGAN_SLOT_CYBERWARE_RIGGER)
	if(socket?.uplink_console == src)
		socket.drop_uplink(carbon_user, silent = TRUE)

#undef CYBERWARE_GHOSTSKIN_ALPHA
#undef CYBERWARE_GHOSTSKIN_DURATION
#undef CYBERWARE_LAZARUS_COOLDOWN
#undef CYBERWARE_LAZARUS_WINDUP
#undef CYBERWARE_LAZARUS_HEAL_TO
#undef TRAIT_CYBERWARE_UNBREAKABLE_BONES
#undef CYBERWARE_RIGGER_SLOWDOWN
