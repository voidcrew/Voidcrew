/**
 * # Tier 3 military chrome: arm weapons
 *
 * Gorilla Arms, Mantis Blades, Widowline Monowire, Popup Ronin, Bunker
 * Buster, plus the cased-pair container the paired ware ships in.
 *
 * Paired ware (Gorilla, Mantis) is TWO organs, one per arm, each carrying
 * HALF the pair's chrome load. Per-arm slots make the base's incumbent
 * netting work with no pair-aware overrides. The parlor sells one case
 * (ware_case sprite) holding both sides.
 *
 * Deployed weapons ride the toolkit base: Extend() hands them over with
 * NODROP + INDESTRUCTIBLE, Retract()/EMP stows them. Nothing here fights
 * that machinery.
 */

// ---- Cased pairs ---------------------------------------------------------

/**
 * A parlor case holding a matched set of ware, one SKU, both arm organs.
 * Crack it open in hand and the halves spill into your hands; the empty
 * case is discarded. The Cradle installs each half like any other organ.
 */
/obj/item/cyberware_pair_case
	name = "cyberware pair case"
	desc = "A foam-lined clamshell case for a matched set of chrome. Crack it open in hand."
	icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	icon_state = "ware_case"
	w_class = WEIGHT_CLASS_NORMAL
	/// Organ typepaths spawned inside on creation.
	var/list/ware_types

/obj/item/cyberware_pair_case/Initialize(mapload)
	. = ..()
	for(var/path in ware_types)
		new path(src)

/obj/item/cyberware_pair_case/examine(mob/user)
	. = ..()
	if(length(contents))
		. += span_notice("Nestled in the foam: [english_list(contents)].")
	. += span_notice("Use it in hand to crack it open.")

/obj/item/cyberware_pair_case/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	if(!length(contents))
		balloon_alert(user, "empty!")
		return TRUE
	playsound(src, 'sound/machines/click.ogg', 40, TRUE)
	user.visible_message(
		span_notice("[user] cracks open [src]."),
		span_notice("You crack open [src]."),
	)
	// Snapshot: put_in_hands() moves items out of contents mid-loop otherwise.
	for(var/obj/item/ware as anything in contents.Copy())
		user.put_in_hands(ware)
	qdel(src)
	return TRUE

/obj/item/cyberware_pair_case/gorilla_arms
	name = "\improper Gorilla Arms case"
	desc = "A heavy clamshell case stenciled with a fist. Two myomer lattices inside, one per arm. The Cradle installs the pair in one sitting."
	ware_types = list(
		/obj/item/organ/cyberimp/cyberware/gorilla_arms,
		/obj/item/organ/cyberimp/cyberware/gorilla_arms/left,
	)

/obj/item/cyberware_pair_case/mantis_blades
	name = "\improper Mantis Blades case"
	desc = "A slim clamshell case with two forearm housings socketed in cut foam. The blades themselves only exist while the hardlight emitters are running."
	ware_types = list(
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left,
	)

// =========================================================================
// GORILLA ARMS
// =========================================================================

/// Flat brute per empowered punch. Our OWN line, never strongarm's
/// doubled slam or +20 biotype bonus (ADDENDUM 2 #6).
#define CYBERWARE_GORILLA_PUNCH_DAMAGE 20
/// Damage per structure/machine smash.
#define CYBERWARE_GORILLA_STRUCTURE_DAMAGE 40
/// Gap between empowered punches, per arm.
#define CYBERWARE_GORILLA_PUNCH_COOLDOWN (4 SECONDS)
/// Gap between structure smashes / rock breaks, per arm.
#define CYBERWARE_GORILLA_SMASH_COOLDOWN (1 SECONDS)
/// How far an aggressively-grabbed victim gets hurled.
#define CYBERWARE_GORILLA_HURL_RANGE 4
/// do_after interaction key for the two-piece door pry.
#define DOAFTER_SOURCE_GORILLA_PRY "cyberware_gorilla_pry"

/**
 * # Gorilla Arms (T3, arms, arm hardware slots, load 3 per arm / 6 the pair)
 *
 * Myomer muscle lattices woven through both arms, the top rung of the
 * ladder that starts at Scrapper's Knuckles. Like every piece of arm-mounted
 * chrome it claims the arm's ONE hardware slot: installing it evicts
 * whatever the arm carried (knuckles, blades, launchers) and vice versa. Each arm's empowered punch is
 * a flat ~20 brute with a wound bonus and a one-tile knockback; punch
 * someone you have in an aggressive grab and they go across the room
 * instead. Fists also break rock like a mining tool and cave in structures
 * and machines. With BOTH arms installed (organ set bonus), closed airlocks
 * can be pried open bare-handed. Instant when the door is unpowered, a
 * slow loud pry when it has power, and never through bolts or welds
 * (bolted doors are the Icepick's problem).
 *
 * Rides the generic cyberware base, not the toolkit. Muscle isn't a
 * deployable. Each arm hooks EARLY_UNARMED_ATTACK (strongarm precedent) and
 * ignores punches thrown with the other hand.
 */
/obj/item/organ/cyberimp/cyberware/gorilla_arms
	name = "\improper Gorilla Arms myomer lattice (right)"
	desc = "A myomer weave anchored bone-deep through the arm. You don't look any stronger for it; you just start pulling closed airlocks open with your bare hands."
	icon_state = "gorilla"
	zone = BODY_ZONE_R_ARM
	slot = ORGAN_SLOT_RIGHT_ARM_AUG
	valid_zones = list(
		BODY_ZONE_R_ARM = ORGAN_SLOT_RIGHT_ARM_AUG,
		BODY_ZONE_L_ARM = ORGAN_SLOT_LEFT_ARM_AUG,
	)
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 3
	tier = CYBERWARE_TIER_3
	aug_overlay = "gorilla_right"
	/// Rate limit on this arm's empowered hits.
	COOLDOWN_DECLARE(slam_cooldown)

/obj/item/organ/cyberimp/cyberware/gorilla_arms/left
	name = "\improper Gorilla Arms myomer lattice (left)"
	zone = BODY_ZONE_L_ARM
	slot = ORGAN_SLOT_LEFT_ARM_AUG
	aug_overlay = "gorilla_left"

/obj/item/organ/cyberimp/cyberware/gorilla_arms/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/organ_set_bonus, /datum/status_effect/organ_set_bonus/cyberware_gorilla)

/**
 * Worn-chrome overlay hook. Gorilla Arms replace the limb outright, hand
 * included, but the hand is NOT part of the arm sprite. The bodypart draws it
 * as a second image (get_limb_icon()'s aux_zone) at BODYPARTS_HIGH_LAYER, which
 * sits well above CYBERWARE_WORN_LAYER, so a plate drawn only at the chrome
 * layer gets painted back over by bare knuckles.
 *
 * One image cannot fix that. The hand already draws above UNIFORM_LAYER, so
 * anything stacked over the hand is also stacked over the jumpsuit, and the
 * chrome layer exists precisely to stay under worn clothing. Instead we do what
 * tg's own toolkit augments do (augments_arms.dm's hand_state): the arm plate
 * keeps the chrome layer and hides under sleeves, and a separate "_hand" plate
 * rides at the hand's own layer, where gloves still cover it like real skin.
 *
 * The sheet may ship without the hand plate. Then this is a no-op and the arm
 * plate renders alone, exactly as it did before.
 */
/obj/item/organ/cyberimp/cyberware/gorilla_arms/get_overlay(image_layer, obj/item/bodypart/limb)
	. = ..()
	var/hand_plate = "[get_overlay_state()]_hand"
	if(!icon_exists(aug_icon, hand_plate))
		return
	. += image(icon = aug_icon, icon_state = hand_plate, layer = -BODYPARTS_HIGH_LAYER)

/obj/item/organ/cyberimp/cyberware/gorilla_arms/on_mob_insert(mob/living/carbon/arm_owner, special = FALSE, movement_flags)
	. = ..()
	if(ishuman(arm_owner))
		RegisterSignal(arm_owner, COMSIG_LIVING_EARLY_UNARMED_ATTACK, PROC_REF(on_punch))

/obj/item/organ/cyberimp/cyberware/gorilla_arms/on_mob_remove(mob/living/carbon/arm_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(arm_owner, COMSIG_LIVING_EARLY_UNARMED_ATTACK)

/**
 * Signal proc for [COMSIG_LIVING_EARLY_UNARMED_ATTACK]. Both installed arms
 * hear every punch; each one acts only when its own hand threw it. Returns
 * COMPONENT_CANCEL_ATTACK_CHAIN when the lattice handled the hit.
 */
/obj/item/organ/cyberimp/cyberware/gorilla_arms/proc/on_punch(mob/living/carbon/human/source, atom/target, proximity, modifiers)
	SIGNAL_HANDLER
	var/obj/item/bodypart/active_hand = source.get_active_hand()
	if(!active_hand || active_hand.body_zone != zone)
		return NONE
	if(!proximity || !source.combat_mode || LAZYACCESS(modifiers, RIGHT_CLICK))
		return NONE
	if(organ_flags & ORGAN_FAILING)
		return NONE
	if(HAS_TRAIT(source, TRAIT_HULK))
		return NONE
	if(!COOLDOWN_FINISHED(src, slam_cooldown))
		return NONE

	// Rock breaks like a mining tool would break it.
	if(ismineralturf(target))
		var/turf/closed/mineral/rock = target
		source.changeNext_move(CLICK_CD_MELEE)
		source.do_attack_animation(rock, ATTACK_EFFECT_SMASH)
		playsound(rock, 'sound/effects/meteorimpact.ogg', 30, TRUE)
		rock.gets_drilled(source, 1)
		COOLDOWN_START(src, slam_cooldown, CYBERWARE_GORILLA_SMASH_COOLDOWN)
		return COMPONENT_CANCEL_ATTACK_CHAIN

	// Structures, girders, machines cave in. Loose items are beneath us.
	if(isobj(target) && !isitem(target))
		var/obj/smashed = target
		if(!smashed.uses_integrity)
			return NONE
		source.changeNext_move(CLICK_CD_MELEE)
		source.do_attack_animation(smashed, ATTACK_EFFECT_SMASH)
		playsound(smashed, 'sound/effects/clang.ogg', 60, TRUE)
		source.visible_message(
			span_danger("[source] caves [smashed] in with a piston-driven fist!"),
			span_danger("You cave [smashed] in!"),
		)
		smashed.take_damage(CYBERWARE_GORILLA_STRUCTURE_DAMAGE, BRUTE, MELEE)
		COOLDOWN_START(src, slam_cooldown, CYBERWARE_GORILLA_SMASH_COOLDOWN)
		return COMPONENT_CANCEL_ATTACK_CHAIN

	if(!isliving(target))
		return NONE
	if(!source.can_unarmed_attack())
		return COMPONENT_SKIP_ATTACK

	var/mob/living/living_target = target
	source.changeNext_move(CLICK_CD_MELEE)

	if(ishuman(living_target))
		var/mob/living/carbon/human/human_target = living_target
		if(human_target.check_block(source, CYBERWARE_GORILLA_PUNCH_DAMAGE, "[source]'s piston punch"))
			source.do_attack_animation(living_target)
			playsound(living_target.loc, 'sound/items/weapons/punchmiss.ogg', 25, TRUE, -1)
			log_combat(source, living_target, "attempted to piston-punch", "gorilla arms")
			return COMPONENT_CANCEL_ATTACK_CHAIN

	// The one damage line. Flat, wounding, honest.
	var/grabbed_hurl = living_target.pulledby == source && source.grab_state >= GRAB_AGGRESSIVE
	source.do_attack_animation(living_target, ATTACK_EFFECT_SMASH)
	playsound(living_target.loc, 'sound/items/weapons/punch1.ogg', 40, TRUE, -1)
	var/target_zone = living_target.get_random_valid_zone(source.zone_selected)
	var/armor_block = living_target.run_armor_check(target_zone, MELEE, armour_penetration = active_hand.unarmed_effectiveness)
	living_target.apply_damage(CYBERWARE_GORILLA_PUNCH_DAMAGE, BRUTE, target_zone, armor_block, wound_bonus = 10)

	if(source.body_position != LYING_DOWN)
		var/atom/throw_target = get_edge_target_turf(living_target, source.dir)
		if(grabbed_hurl)
			living_target.safe_throw_at(throw_target, CYBERWARE_GORILLA_HURL_RANGE, 2, source)
			living_target.visible_message(
				span_danger("[source] hurls [living_target] across the room!"),
				span_userdanger("[source] hurls you across the room!"),
			)
		else
			living_target.throw_at(throw_target, 1, rand(1, 4), source, gentle = TRUE)
			living_target.visible_message(
				span_danger("[source] slams [living_target] with a piston-driven fist!"),
				span_userdanger("[source] slams you with a piston-driven fist!"),
			)
	to_chat(source, span_danger("You slam [living_target]!"))
	log_combat(source, living_target, "piston-punched", "gorilla arms")
	COOLDOWN_START(src, slam_cooldown, CYBERWARE_GORILLA_PUNCH_COOLDOWN)
	return COMPONENT_CANCEL_ATTACK_CHAIN

/**
 * The two-piece set bonus: with both lattices synced, closed airlocks can be
 * pried open bare-handed. Rides tg's door_pryer element (the strongarm set
 * bonus precedent), instant force on unpowered doors, a slow do_after pry
 * on powered ones, and a hard refusal on bolts/welds/seals.
 */
/datum/status_effect/organ_set_bonus/cyberware_gorilla
	id = "organ_set_bonus_cyberware_gorilla"
	organs_needed = 2
	required_biotype = NONE
	bonus_activate_text = span_notice("Your Gorilla Arms sync up. You can force closed airlocks by hand now. Walk up and pull, out of combat mode.")
	bonus_deactivate_text = span_notice("Your arms fall out of sync. Doors stay shut again.")

/datum/status_effect/organ_set_bonus/cyberware_gorilla/enable_bonus(obj/item/organ/inserted_organ)
	. = ..()
	if(!.)
		return
	owner.AddElement(/datum/element/door_pryer, pry_time = 4 SECONDS, interaction_key = DOAFTER_SOURCE_GORILLA_PRY)

/datum/status_effect/organ_set_bonus/cyberware_gorilla/disable_bonus(obj/item/organ/removed_organ)
	. = ..()
	owner.RemoveElement(/datum/element/door_pryer, pry_time = 4 SECONDS, interaction_key = DOAFTER_SOURCE_GORILLA_PRY)

// =========================================================================
// MANTIS BLADES
// =========================================================================

/// Lunge reach in tiles.
#define CYBERWARE_MANTIS_LUNGE_RANGE 5
/// Bonus brute the arriving lunge lands PER BLADE (cap 10 per ADDENDUM 2).
#define CYBERWARE_MANTIS_LUNGE_BONUS 10
/// Telegraph delay between the wind-up and the dash.
#define CYBERWARE_MANTIS_LUNGE_TELEGRAPH (0.3 SECONDS)
/// How long a connecting lunge floors its target. Above the module's usual
/// 1-1.5s band because the lunge is telegraphed and on a 20 second clock.
#define CYBERWARE_MANTIS_LUNGE_KNOCKDOWN (2 SECONDS)

/**
 * The blade itself: hardlight, ~20 force (cap 22), sharp, wounding. Only
 * ever exists inside the housing. The toolkit's Extend() puts it in hand
 * with NODROP + INDESTRUCTIBLE, so it cannot be disarmed, stolen or broken;
 * Retract() and EMP stow it.
 *
 * Every sprite comes off the cyberware sheets rather than the stock hardlight
 * sword: this is a long blade running forward past the hand out of a forearm
 * housing, not something anybody is gripping. The held sprite is blade only.
 * The housing is already on the bearer's arm as the organ's aug_overlay, and
 * drawing a second one in the hand put a metal brick over their bicep.
 *
 * base_icon_state comes along for the ride purely so it cannot disagree with
 * icon_state; update_icon_state() only consults it when sword_color_icon is
 * set, which it never is here.
 */
/obj/item/melee/energy/blade/hardlight/cyberware_mantis
	name = "mantis blade"
	desc = "A forearm's length of hardlight ground to a monomolecular edge. It comes out of the housing already swinging."
	icon = 'voidcrew/modules/cyberware/icons/cyberware_weapons.dmi'
	icon_state = "mantis"
	base_icon_state = "mantis"
	inhand_icon_state = "mantis"
	lefthand_file = 'voidcrew/modules/cyberware/icons/cyberware_lefthand.dmi'
	righthand_file = 'voidcrew/modules/cyberware/icons/cyberware_righthand.dmi'
	force = 20
	armour_penetration = 10
	wound_bonus = 10

/**
 * # Mantis Blades (T3, arms, aug slots, load 3 per arm / 6 the pair)
 *
 * Paired retractable hardlight blades on the toolkit base. Each housing
 * deploys its own blade; either housing can LUNGE, a telegraphed dash of
 * up to five tiles that closes to the target, lands a bonus cut on arrival
 * and puts them on the floor (warframe iai pattern: wind-up message and
 * sound, then a decoy trail down the line). The two housings share one lunge
 * cooldown, and with both blades out both of them land on arrival.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis
	name = "\improper Mantis Blade housing (right)"
	desc = "A forearm housing with a hardlight emitter where your wrist tendons used to be. The blade weighs nothing until it lands."
	icon_state = "mantis"
	chrome_load = 3
	tier = CYBERWARE_TIER_3
	aug_overlay = "mantis"
	items_to_create = list(/obj/item/melee/energy/blade/hardlight/cyberware_mantis)
	// A blade sliding out of a forearm housing and snapping back into it, the
	// cursed katana's pair (mining_loot/cursed_katana.dm), not a baton's ratchet.
	extend_sound = 'sound/items/unsheath.ogg'
	retract_sound = 'sound/items/sheath.ogg'
	actions_types = list(
		/datum/action/item_action/organ_action/toggle/toolkit,
		/datum/action/cooldown/cyberware/mantis_lunge,
	)

/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left
	name = "\improper Mantis Blade housing (left)"
	zone = BODY_ZONE_L_ARM
	slot = ORGAN_SLOT_LEFT_ARM_AUG

/**
 * TRUE while this housing's blade is out in a hand instead of stowed inside.
 * Same test the toolkit base uses for "did it actually deploy", the parent
 * assigns active_item before it knows a hand was free (augments_arms.dm), so
 * the question is whether the blade LEFT us, not whether the var is set.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/proc/blade_extended()
	return active_item && !(active_item in src)

/datum/action/cooldown/cyberware/mantis_lunge
	name = "Mantis Lunge"
	desc = "Dash up to five tiles onto a target with the blade leading, cutting them open and dropping them on arrival. The blade must be extended. With both blades out, both land."
	button_icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	button_icon_state = "act_mantis_lunge"
	cooldown_time = 20 SECONDS
	click_to_activate = TRUE

/**
 * How many mantis blades this owner has out right now. Every housing grants
 * exactly one of these buttons, so counting the buttons whose blade is
 * extended counts the blades that will arrive.
 */
/datum/action/cooldown/cyberware/mantis_lunge/proc/count_extended_blades()
	if(!owner)
		return 0
	var/blades = 0
	for(var/datum/action/cooldown/cyberware/mantis_lunge/lunge_action in owner.actions)
		var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = lunge_action.organ
		if(istype(housing) && housing.blade_extended())
			blades++
	return blades

/datum/action/cooldown/cyberware/mantis_lunge/Activate(atom/target)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = organ
	if(!istype(housing) || !isliving(owner))
		return FALSE
	var/mob/living/lunger = owner
	if(!housing.blade_extended())
		lunger.balloon_alert(lunger, "extend the blade first!")
		return FALSE
	if(lunger.buckled || !isturf(lunger.loc))
		lunger.balloon_alert(lunger, "can't lunge from here!")
		return FALSE
	if(!isliving(target))
		lunger.balloon_alert(lunger, "no target!")
		return FALSE
	var/mob/living/victim = target
	if(victim == lunger || victim.stat == DEAD)
		lunger.balloon_alert(lunger, "no target!")
		return FALSE
	if(get_dist(lunger, victim) > CYBERWARE_MANTIS_LUNGE_RANGE || !can_see(lunger, victim, CYBERWARE_MANTIS_LUNGE_RANGE))
		lunger.balloon_alert(lunger, "out of reach!")
		return FALSE
	// One lunge clock across both housings: start every mantis_lunge button
	// this owner has, ours included.
	for(var/datum/action/cooldown/cyberware/mantis_lunge/lunge_action in lunger.actions)
		lunge_action.StartCooldown()
	// The telegraph: readable wind-up before the dash lands.
	lunger.face_atom(victim)
	var/both_blades = count_extended_blades() > 1
	lunger.visible_message(
		span_boldwarning("[lunger] drops low, mantis blade[both_blades ? "s" : ""] laid flat along [lunger.p_their()] [both_blades ? "arms" : "arm"]!"),
		span_warning("You coil for the lunge."),
	)
	playsound(lunger, 'sound/items/weapons/sear.ogg', 50, TRUE)
	addtimer(CALLBACK(src, PROC_REF(do_lunge), WEAKREF(victim)), CYBERWARE_MANTIS_LUNGE_TELEGRAPH)
	return TRUE

/// The dash itself: walk the line to the target with a decoy per tile,
/// stop adjacent, land the bonus cut once per blade and floor them.
/datum/action/cooldown/cyberware/mantis_lunge/proc/do_lunge(datum/weakref/victim_ref)
	var/mob/living/lunger = owner
	if(QDELETED(lunger) || lunger.incapacitated || !isturf(lunger.loc))
		return
	var/mob/living/victim = victim_ref?.resolve()
	if(QDELETED(victim) || victim.stat == DEAD)
		lunger.balloon_alert(lunger, "target lost!")
		return
	var/turf/victim_turf = get_turf(victim)
	if(!victim_turf || get_dist(lunger, victim_turf) > CYBERWARE_MANTIS_LUNGE_RANGE + 1)
		lunger.balloon_alert(lunger, "target lost!")
		return
	playsound(lunger, 'sound/items/weapons/bladeslice.ogg', 60, TRUE)
	for(var/turf/step_turf as anything in get_line(get_turf(lunger), victim_turf))
		if(step_turf == get_turf(lunger))
			continue
		if(step_turf == victim_turf)
			break
		if(step_turf.is_blocked_turf(exclude_mobs = TRUE))
			break
		new /obj/effect/temp_visual/decoy/fading/halfsecond(lunger.loc, lunger)
		lunger.forceMove(step_turf)
	if(!lunger.Adjacent(victim))
		lunger.balloon_alert(lunger, "fell short!")
		return
	// Both housings deployed means both blades arrive. Floored at one: a blade
	// stowed during the 0.3s telegraph shouldn't eat the whole cooldown for
	// nothing when the dash still connected.
	var/blades = max(count_extended_blades(), 1)

	lunger.face_atom(victim)
	lunger.do_attack_animation(victim, ATTACK_EFFECT_SLASH)
	// One armor roll for the arrival, reused per blade. Both land in the same
	// instant on the same plate, and it keeps the armor message to one line.
	var/armor_block = victim.run_armor_check(BODY_ZONE_CHEST, MELEE)
	for(var/i in 1 to blades)
		victim.apply_damage(
			CYBERWARE_MANTIS_LUNGE_BONUS,
			BRUTE,
			BODY_ZONE_CHEST,
			armor_block,
			wound_bonus = 10,
			sharpness = SHARP_EDGED,
		)
	victim.Knockdown(CYBERWARE_MANTIS_LUNGE_KNOCKDOWN)
	if(blades > 1)
		victim.visible_message(
			span_danger("[lunger] flickers across the gap and shuts both blades on [victim] like a trap, dropping [victim.p_them()]!"),
			span_userdanger("[lunger] flickers across the gap. Both blades land at once and your legs go out from under you!"),
		)
	else
		victim.visible_message(
			span_danger("[lunger] flickers across the gap, opens [victim] up on arrival and puts [victim.p_them()] down!"),
			span_userdanger("[lunger] flickers across the gap. The blade is already in you, and the floor comes up fast!"),
		)
	log_combat(lunger, victim, "mantis-lunged", "mantis blades ([blades] landed)")
	playsound(victim, 'sound/items/weapons/bladeslice.ogg', 70, TRUE)

// =========================================================================
// WIDOWLINE MONOWIRE
// =========================================================================

/// Cleave fraction of the wire's damage dealt to secondary targets.
#define CYBERWARE_MONOWIRE_CLEAVE_MULT 0.75
/// Burn the charged line adds on top of the cut, every hit. Force carries the
/// brute half; this is the other quarter of the swing.
#define CYBERWARE_MONOWIRE_BURN 5

/**
 * The wire itself. Reach 2 (vorpal scythe precedent), sharp, and armor is not
 * the answer to it: full armour_penetration, because a monomolecular line
 * parts a plate carrier the same way it parts the person inside it. What it
 * costs instead is raw numbers and reach into hard targets, 15 brute plus 5
 * burn a swing, and a demolition_mod of 0.25 that leaves it useless against
 * walls, doors and machines.
 *
 * The damage splits 3:1. The cut is brute and carries the wounding; the charge
 * running down the line is burn, flat and unwounding. Both halves ignore armor
 * and both halves cleave.
 *
 * Every landed hit cleaves through mobs adjacent to the victim with line of
 * sight, allies filtered out, for CYBERWARE_MONOWIRE_CLEAVE_MULT of both.
 */
/obj/item/melee/cyberware_monowire
	name = "\improper Widowline monowire"
	desc = "A weighted spool of monomolecular line, run live. At rest it's a glitter in the air. Swung, it goes through plate and the person wearing it in the same motion, and through whoever is standing next to them."
	icon = 'voidcrew/modules/cyberware/icons/cyberware_weapons.dmi'
	icon_state = "monowire"
	inhand_icon_state = "monowire"
	// The old sprite was the borrowed chain whip, drawn pointing north; ours is
	// drawn east-facing like every other tg world weapon, so no correction.
	icon_angle = 0
	lefthand_file = 'voidcrew/modules/cyberware/icons/cyberware_lefthand.dmi'
	righthand_file = 'voidcrew/modules/cyberware/icons/cyberware_righthand.dmi'
	w_class = WEIGHT_CLASS_NORMAL
	force = 15
	demolition_mod = 0.25
	armour_penetration = 100
	sharpness = SHARP_EDGED
	wound_bonus = 20
	exposed_wound_bonus = 30
	reach = 2
	attack_verb_continuous = list("garrotes", "flenses", "lashes", "bisects")
	attack_verb_simple = list("garrote", "flense", "lash", "bisect")
	hitsound = 'voidcrew/sound/monowire1.ogg'

/obj/item/melee/cyberware_monowire/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	// The parent plays hitsound partway through the swing, so pick which of the
	// line's two voices we are before handing off.
	hitsound = pick('voidcrew/sound/monowire1.ogg', 'voidcrew/sound/monowire2.ogg')
	. = ..()
	// A truthy return means the swing was blocked or cancelled outright, no
	// cut landed, so nothing burns and nothing carries through.
	if(. || QDELETED(target) || !isliving(user))
		return

	// The charge on the line, on top of the cut. Silent armor check: the parent
	// already announced the penetration for this same swing.
	var/burn_zone = target.get_random_valid_zone(user.zone_selected)
	target.apply_damage(
		CYBERWARE_MONOWIRE_BURN,
		BURN,
		burn_zone,
		target.run_armor_check(burn_zone, MELEE, armour_penetration = armour_penetration, silent = TRUE),
	)

	var/cleaved_anyone = FALSE
	for(var/mob/living/nearby in orange(1, target))
		if(nearby == user || nearby == target || nearby.stat == DEAD)
			continue
		if(!can_see(target, nearby, 1))
			continue
		if(cyberware_is_ally(user, nearby))
			continue
		// One roll for both halves: it is one pass of the same wire.
		var/cleave_block = nearby.run_armor_check(BODY_ZONE_CHEST, MELEE, armour_penetration = armour_penetration)
		nearby.apply_damage(
			force * CYBERWARE_MONOWIRE_CLEAVE_MULT,
			BRUTE,
			BODY_ZONE_CHEST,
			cleave_block,
			wound_bonus = wound_bonus,
			sharpness = SHARP_EDGED,
		)
		nearby.apply_damage(
			CYBERWARE_MONOWIRE_BURN * CYBERWARE_MONOWIRE_CLEAVE_MULT,
			BURN,
			BODY_ZONE_CHEST,
			cleave_block,
		)
		to_chat(nearby, span_userdanger("[user]'s monowire carries through into you!"))
		cleaved_anyone = TRUE
	if(cleaved_anyone)
		user.visible_message(
			span_danger("The wire sings through everything beside [target]!"),
			span_danger("The wire carries through the whole cluster."),
		)
		playsound(target, 'sound/items/weapons/bladeslice.ogg', 50, TRUE)

/**
 * # Widowline Monowire (T3, one arm, aug slot, load 5)
 *
 * A single-arm spool housing deploying the wire above. Reach two, hits the
 * crowd around whatever it lands on, and armor does nothing to slow it down.
 * What it can't do is hard targets: a quarter demolition mod means walls,
 * doors and machines shrug it off. Bring it to bodies, not to bulkheads.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/monowire
	name = "\improper Widowline spool housing"
	desc = "A wrist spool wound with monomolecular line, on a hair-trigger tensioner. It reels back clean the moment the swing ends."
	icon_state = "monowire"
	chrome_load = 5
	tier = CYBERWARE_TIER_3
	items_to_create = list(/obj/item/melee/cyberware_monowire)
	extend_sound = 'sound/items/weapons/batonextend.ogg'

// =========================================================================
// POPUP RONIN SMG
// =========================================================================

/// Proprietary caliber: nothing else in the galaxy chambers it, and it
/// chambers nothing else. Never the outfitter's .45 (don't undercut Sarge).
#define CYBERWARE_CALIBER_RONIN "10x24mm ronin"

/obj/projectile/bullet/cyberware_ronin
	name = "10x24mm caseless bullet"
	damage = 20
	wound_bonus = -5
	exposed_wound_bonus = 5

/obj/item/ammo_casing/cyberware_ronin
	name = "10x24mm caseless round"
	desc = "A stubby caseless round in Ronin's proprietary 10x24mm. The parlor is the only place in the sector that presses these."
	caliber = CYBERWARE_CALIBER_RONIN
	projectile_type = /obj/projectile/bullet/cyberware_ronin

/obj/item/ammo_casing/cyberware_ronin/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/caseless)

/**
 * The proprietary magazine. Sold only at the parlor, the return-visit hook
 * (the shop SKU itself is the catalog wave's job; the type lives here).
 */
/obj/item/ammo_box/magazine/cyberware_ronin
	name = "\improper Ronin flush-feed magazine (10x24mm)"
	desc = "A flush-feed magazine keyed to the Popup Ronin's action and nothing else's. Twenty caseless rounds, parlor-pressed."
	icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	icon_state = "ronin_mag"
	base_icon_state = "ronin_mag"
	ammo_type = /obj/item/ammo_casing/cyberware_ronin
	caliber = CYBERWARE_CALIBER_RONIN
	max_ammo = 20

/**
 * The gun the arm unfolds. Modest SMG numbers on the standard automatic
 * chassis; NODROP while deployed comes from the toolkit Extend, so it can't
 * be disarmed, and Retract/EMP stow it mid-firefight.
 *
 * Sprites come off the cyberware weapon sheet so the unfolded gun reads as the
 * ronin housing it came out of. That sheet carries one flat state per weapon,
 * so mag_display is off. There is no separate magazine plate to composite.
 */
/obj/item/gun/ballistic/automatic/cyberware_ronin
	name = "\improper Popup Ronin machine-pistol"
	desc = "A skeletal machine-pistol that folds flat enough to live inside a forearm. Feeds from proprietary flush-feed magazines sold only at the chrome parlor."
	icon = 'voidcrew/modules/cyberware/icons/cyberware_weapons.dmi'
	icon_state = "ronin"
	inhand_icon_state = "ronin"
	lefthand_file = 'voidcrew/modules/cyberware/icons/cyberware_lefthand.dmi'
	righthand_file = 'voidcrew/modules/cyberware/icons/cyberware_righthand.dmi'
	mag_display = FALSE
	w_class = WEIGHT_CLASS_NORMAL
	accepted_magazine_type = /obj/item/ammo_box/magazine/cyberware_ronin
	burst_size = 1
	fire_delay = 0
	spread = 8
	actions_types = list()
	can_suppress = FALSE
	internal_magazine = FALSE

/obj/item/gun/ballistic/automatic/cyberware_ronin/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/automatic_fire, 0.3 SECONDS)

/**
 * # Popup Ronin SMG (T3, one arm, aug slot, load 5)
 *
 * A fold-out forearm SMG. Ships with one loaded magazine; every reload after
 * that is a trip back to Splice's shelf.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin
	name = "\improper Popup Ronin housing"
	desc = "A forearm rig that unfolds a skeletal machine-pistol into your grip and folds it away again just as fast. The mag well only takes parlor-pressed magazines."
	icon_state = "ronin"
	chrome_load = 5
	tier = CYBERWARE_TIER_3
	aug_overlay = "ronin"
	items_to_create = list(/obj/item/gun/ballistic/automatic/cyberware_ronin)
	extend_sound = 'sound/items/weapons/batonextend.ogg'

// =========================================================================
// BUNKER BUSTER
// =========================================================================

/// Proprietary rocket caliber, parlor-only reloads.
#define CYBERWARE_CALIBER_BUSTER "30mm buster"

/**
 * The shaped munition: heavy single-target and anti-structure punch with NO
 * explosion radius, it will never breach the hull you are standing in.
 * demolition_mod does the structure work (breaching-slug precedent), a
 * fake-explosion visual and thump sell the hit.
 */
/obj/projectile/bullet/cyberware_buster
	name = "shaped micro-rocket"
	icon_state = "missile"
	damage = 60
	wound_bonus = 20
	demolition_mod = 8
	sharpness = NONE
	ricochets_max = 0

/obj/projectile/bullet/cyberware_buster/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	var/turf/impact = get_turf(target)
	if(impact)
		new /obj/effect/temp_visual/explosion/fast(impact)
		playsound(impact, 'sound/effects/explosion/explosion1.ogg', 60, TRUE)
	if(isliving(target))
		var/mob/living/victim = target
		victim.Knockdown(1 SECONDS)

/obj/item/ammo_casing/cyberware_buster
	name = "30mm shaped rocket"
	desc = "A stubby shaped-charge rocket in the Buster's proprietary 30mm. All of the blast goes forward and stops at the first thing it hits."
	icon_state = "low_yield_rocket"
	base_icon_state = "low_yield_rocket"
	caliber = CYBERWARE_CALIBER_BUSTER
	projectile_type = /obj/projectile/bullet/cyberware_buster

/obj/item/ammo_casing/cyberware_buster/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/caseless)

// The base casing appends "-live" while loaded; ammo.dmi has no
// "low_yield_rocket-live" state, and a caseless rocket is always loaded.
/obj/item/ammo_casing/cyberware_buster/update_icon_state()
	. = ..()
	icon_state = base_icon_state

/// The launcher's two-round rotary rack.
/obj/item/ammo_box/magazine/internal/cylinder/cyberware_buster
	name = "buster rotary rack"
	ammo_type = /obj/item/ammo_casing/cyberware_buster
	caliber = CYBERWARE_CALIBER_BUSTER
	max_ammo = 2

/**
 * The parlor reload: a bracketed pair of rockets (the catalog wave sells
 * it). Slap it against the deployed pod to feed both tubes.
 */
/obj/item/ammo_box/cyberware_buster_rockets
	name = "\improper Buster rocket pair"
	desc = "Two 30mm shaped rockets in a carry bracket. The parlor is the only place that racks these, so don't waste them."
	icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	icon_state = "buster_rockets"
	base_icon_state = "buster_rockets"
	ammo_type = /obj/item/ammo_casing/cyberware_buster
	max_ammo = 2

/**
 * The pod itself: a two-shot micro-rocket launcher on the revolver chassis
 * (multi-shot internal cylinder, grenade-launcher reload pattern, hit it
 * with rockets or the pair bracket to reload).
 *
 * Sprites come off the cyberware weapon sheet: this is an extension of the
 * forearm, not a shoulder tube borrowed from the wide-gun rack. No base pixel
 * offset either, that -8 existed only to centre wide_guns.dmi's 48-wide cells,
 * and it would shove a normal 32x32 sprite off its tile.
 */
/obj/item/gun/ballistic/revolver/cyberware_buster
	name = "\improper Bunker Buster micro-rocket pod"
	desc = "A two-tube rocket pod that rides folded along the forearm. The munitions are shaped, so the blast goes into the target instead of the room, and instead of your hull."
	icon = 'voidcrew/modules/cyberware/icons/cyberware_weapons.dmi'
	icon_state = "bunker_buster"
	inhand_icon_state = "bunker_buster"
	lefthand_file = 'voidcrew/modules/cyberware/icons/cyberware_lefthand.dmi'
	righthand_file = 'voidcrew/modules/cyberware/icons/cyberware_righthand.dmi'
	w_class = WEIGHT_CLASS_BULKY
	weapon_weight = WEAPON_HEAVY
	accepted_magazine_type = /obj/item/ammo_box/magazine/internal/cylinder/cyberware_buster
	fire_sound = 'sound/items/weapons/gun/general/rocket_launch.ogg'
	fire_delay = 1.5 SECONDS
	cartridge_wording = "rocket"

/obj/item/gun/ballistic/revolver/cyberware_buster/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	..()
	if(istype(attacking_item, /obj/item/ammo_box) || isammocasing(attacking_item))
		chamber_round()

/**
 * # Bunker Buster (T3, one arm, aug slot, load 5)
 *
 * The arm that ends arguments with cover. Two rockets, then a walk back to
 * the parlor, an event, not a spam tool.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/bunker_buster
	name = "\improper Bunker Buster housing"
	desc = "A reinforced forearm bay built around two rocket tubes, with a recoil bed where your radius used to be. Reloads are parlor-only, so make both count."
	icon_state = "bunker_buster"
	chrome_load = 5
	tier = CYBERWARE_TIER_3
	aug_overlay = "buster"
	items_to_create = list(/obj/item/gun/ballistic/revolver/cyberware_buster)
	extend_sound = 'sound/items/weapons/batonextend.ogg'

#undef CYBERWARE_GORILLA_PUNCH_DAMAGE
#undef CYBERWARE_GORILLA_STRUCTURE_DAMAGE
#undef CYBERWARE_GORILLA_PUNCH_COOLDOWN
#undef CYBERWARE_GORILLA_SMASH_COOLDOWN
#undef CYBERWARE_GORILLA_HURL_RANGE
#undef DOAFTER_SOURCE_GORILLA_PRY
#undef CYBERWARE_MANTIS_LUNGE_RANGE
#undef CYBERWARE_MANTIS_LUNGE_BONUS
#undef CYBERWARE_MANTIS_LUNGE_TELEGRAPH
#undef CYBERWARE_MANTIS_LUNGE_KNOCKDOWN
#undef CYBERWARE_MONOWIRE_CLEAVE_MULT
#undef CYBERWARE_MONOWIRE_BURN
#undef CYBERWARE_CALIBER_RONIN
#undef CYBERWARE_CALIBER_BUSTER
