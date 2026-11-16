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
	desc = "A foam-lined clamshell case for a matched set of chrome."
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
	desc = "A heavy clamshell case stenciled with a fist. Two myomer lattices inside, one per arm."
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
	desc = "A myomer weave anchored bone-deep through the arm. You don't look any stronger for it; doors just stop being your problem."
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
	// The defines above are the Gorilla defaults. They live in vars so the other
	// models of the line (ware_line_models_a.dm) can retune by setting them.
	/// Flat brute per empowered punch.
	var/punch_damage = CYBERWARE_GORILLA_PUNCH_DAMAGE
	/// Damage per structure/machine smash.
	var/structure_damage = CYBERWARE_GORILLA_STRUCTURE_DAMAGE
	/// Gap between empowered punches, per arm.
	var/punch_cooldown_time = CYBERWARE_GORILLA_PUNCH_COOLDOWN
	/// Gap between structure smashes / rock breaks, per arm.
	var/smash_cooldown_time = CYBERWARE_GORILLA_SMASH_COOLDOWN
	/// How far an aggressively-grabbed victim gets hurled. 0 or less: no hurl,
	/// the grabbed victim takes the ordinary slam.
	var/hurl_range = CYBERWARE_GORILLA_HURL_RANGE
	/// Whether a matched pair of these pries closed airlocks (the set bonus).
	var/pries_doors = TRUE
	/// The set bonus a matched pair of this model syncs into. Each model has its own, so a mixed pair syncs into neither.
	var/pair_bonus = /datum/status_effect/organ_set_bonus/cyberware_gorilla

/obj/item/organ/cyberimp/cyberware/gorilla_arms/left
	name = "\improper Gorilla Arms myomer lattice (left)"
	zone = BODY_ZONE_L_ARM
	slot = ORGAN_SLOT_LEFT_ARM_AUG
	aug_overlay = "gorilla_left"

/obj/item/organ/cyberimp/cyberware/gorilla_arms/Initialize(mapload)
	. = ..()
	if(pries_doors && pair_bonus)
		AddElement(/datum/element/organ_set_bonus, pair_bonus)
	// Each real arm winds up a haymaker; both share the pistons' cooldown (hyperviolence_gorilla/gorilla_haymaker.dm)
	if(heavy_moves)
		add_item_action(/datum/action/cooldown/cyberware/gorilla_haymaker)

/**
 * Worn-chrome overlay hook. Gorilla Arms replace the limb outright, hand
 * included, but the hand is NOT part of the arm sprite. The bodypart draws it
 * as a second image (get_limb_icon()'s aux_zone) at BODYPARTS_HIGH_LAYER, which
 * sits well above CYBERWARE_WORN_LAYER, so a plate drawn only at the chrome
 * layer gets painted back over by bare knuckles.
 *
 * Lifting the whole arm plate above the hand would also lift it over the worn
 * ID. Instead we do what tg's own toolkit augments do (augments_arms.dm's
 * hand_state): the arm plate keeps the chrome layer, over the sleeve, and a
 * separate "_hand" plate rides at the hand's own layer, where gloves still
 * cover it like real skin.
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
		COOLDOWN_START(src, slam_cooldown, smash_cooldown_time)
		return COMPONENT_CANCEL_ATTACK_CHAIN

	// Someone held in an aggressive grab, brought down on the floor or a table (hyperviolence_gorilla/gorilla_punch.dm).
	// Before the structure smash, so a table click while grabbing slams them instead of caving the table in.
	switch(try_slam(source, target, active_hand))
		if(GORILLA_SLAM_DONE)
			COOLDOWN_START(src, slam_cooldown, punch_cooldown_time)
			return COMPONENT_CANCEL_ATTACK_CHAIN
		if(GORILLA_SLAM_PASS)
			return NONE

	// A trader outpost's doors hold against a fist as they do against a pry, and trying counts against you
	// (hyperviolence_gorilla/gorilla_pry.dm).
	if(istype(target, /obj/machinery/door) && gorilla_pry_refused(target))
		source.changeNext_move(CLICK_CD_MELEE)
		source.do_attack_animation(target, ATTACK_EFFECT_SMASH)
		playsound(target, 'sound/items/weapons/tap.ogg', 50, TRUE)
		target.balloon_alert(source, "it won't budge!")
		gorilla_pry_aggression(target, source)
		source.log_message("punched [target] at a trader outpost, located at [loc_name(target)].", LOG_GAME)
		COOLDOWN_START(src, slam_cooldown, smash_cooldown_time)
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
		smashed.take_damage(structure_damage, BRUTE, MELEE)
		COOLDOWN_START(src, slam_cooldown, smash_cooldown_time)
		return COMPONENT_CANCEL_ATTACK_CHAIN

	// A pacifist's punch at a living thing is the ordinary punch, which refuses it.
	if(!isliving(target) || HAS_TRAIT(source, TRAIT_PACIFISM))
		return NONE
	if(!source.can_unarmed_attack())
		return COMPONENT_SKIP_ATTACK

	var/mob/living/living_target = target
	source.changeNext_move(CLICK_CD_MELEE)

	if(ishuman(living_target))
		var/mob/living/carbon/human/human_target = living_target
		if(human_target.check_block(source, punch_damage, "[source]'s piston punch"))
			source.do_attack_animation(living_target)
			playsound(living_target.loc, 'sound/items/weapons/punchmiss.ogg', 25, TRUE, -1)
			log_combat(source, living_target, "attempted to piston-punch", "gorilla arms")
			return COMPONENT_CANCEL_ATTACK_CHAIN

	// Someone in crit or stunned, with the aimed zone picking the finisher (hyperviolence_gorilla/gorilla_finisher.dm).
	if(gorilla_try_finisher(source, living_target))
		return COMPONENT_CANCEL_ATTACK_CHAIN

	// The one damage line, through #509, with the knockback on the safe path (hyperviolence_gorilla/gorilla_punch.dm).
	piston_hit(source, living_target, active_hand)
	COOLDOWN_START(src, slam_cooldown, punch_cooldown_time)
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
	bonus_activate_text = span_notice("Your Gorilla Arms sync up.")
	bonus_deactivate_text = span_notice("Your arms fall out of sync.")
	/// How long the pair takes to force a powered airlock.
	var/pry_time = GORILLA_PRY_TIME
	/// The ground pound chip the pair grants.
	var/pound_type = /datum/action/cooldown/cyberware/gorilla_pound
	/// Whether the arms flex as they sync.
	var/flexes = TRUE

/datum/status_effect/organ_set_bonus/cyberware_gorilla/enable_bonus(obj/item/organ/inserted_organ)
	. = ..()
	if(!.)
		return
	// The pry refuses trader outpost doors and plays the strain (hyperviolence_gorilla/gorilla_pry.dm)
	owner.AddElement(/datum/element/door_pryer/gorilla, pry_time = pry_time, interaction_key = DOAFTER_SOURCE_GORILLA_PRY)
	// The ground pound chip, and the flex as the arms come online (hyperviolence_gorilla/gorilla_pound.dm)
	grant_pound()
	if(flexes)
		gorilla_flex(owner)

/datum/status_effect/organ_set_bonus/cyberware_gorilla/disable_bonus(obj/item/organ/removed_organ)
	. = ..()
	owner.RemoveElement(/datum/element/door_pryer/gorilla, pry_time = pry_time, interaction_key = DOAFTER_SOURCE_GORILLA_PRY)
	take_pound()

/datum/status_effect/organ_set_bonus/cyberware_gorilla/on_remove()
	take_pound()
	return ..()

// =========================================================================
// MANTIS BLADES
// =========================================================================

// These four are the Mantis defaults. The housing reads them into vars so the
// other models in the line (ware_line_mantis.dm) can retune by setting vars.

/// Lunge reach in tiles.
#define CYBERWARE_MANTIS_LUNGE_RANGE 5
/// Bonus brute the arriving lunge lands PER BLADE (cap 10 per ADDENDUM 2).
#define CYBERWARE_MANTIS_LUNGE_BONUS 10
/// Telegraph delay between the wind-up and the dash.
#define CYBERWARE_MANTIS_LUNGE_TELEGRAPH (0.3 SECONDS)
/// How long a connecting lunge floors its target. Above the module's usual
/// 1-1.5s band because the lunge is telegraphed and on a 20 second clock.
#define CYBERWARE_MANTIS_LUNGE_KNOCKDOWN (2 SECONDS)
/// How long a shown-line dash (dash_aim) takes per tile: a real run down the line, one tick a step.
#define CYBERWARE_MANTIS_LUNGE_STEP (0.5)
/// How long tg's attack lunge takes to reach its target (do_attack_animation()): the arrival's cut lands no sooner.
#define CYBERWARE_MANTIS_LUNGE_THRUST (0.1 SECONDS)

/**
 * The blade itself: hardlight, ~20 force (cap 22), sharp, wounding. Only
 * ever exists inside the housing. The toolkit's Extend() puts it in hand
 * with NODROP + INDESTRUCTIBLE, so it cannot be disarmed, stolen or broken;
 * Retract() and EMP stow it.
 *
 * Every sprite comes off the cyberware sheets rather than the stock hardlight
 * sword: this is a long blade running forward past the hand out of a forearm
 * housing, not something anybody is gripping. The held sprite is the blade
 * along the forearm. The organ's worn overlay (the housing with the blade
 * folded in) hides while the blade is out, see hide_worn_while_deployed.
 *
 * base_icon_state names the blade's model for its held poses: the held sprite
 * is "[base_icon_state]_[pose]" (voidcrew/modules/mantis_gore/), the raised
 * guard while nothing else is going on. update_icon_state() only consults it
 * when sword_color_icon is set, which it never is here.
 */
/obj/item/melee/energy/blade/hardlight/cyberware_mantis
	name = "mantis blade"
	desc = "A forearm's length of hardlight ground to a monomolecular edge. It comes out of the housing already swinging."
	icon = 'voidcrew/modules/cyberware/icons/cyberware_weapons.dmi'
	icon_state = "mantis"
	base_icon_state = "mantis"
	inhand_icon_state = "mantis_guard"
	lefthand_file = MANTIS_LEFTHAND_ICON
	righthand_file = MANTIS_RIGHTHAND_ICON
	force = 20
	armour_penetration = 10
	wound_bonus = 10
	/// Set by afterattack() during attack()'s parent call, which only a swing that
	/// connected reaches. attack()'s own FALSE can't tell a cut from a pacifist's
	/// pulled swing or a signal-skipped one. The Widowline does the same.
	var/swing_landed = FALSE

/obj/item/melee/energy/blade/hardlight/cyberware_mantis/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	// A head swing at someone dying is the scissor, not a cut (mantis_gore/mantis_scissor.dm).
	if(mantis_swing_taken(target, user))
		return TRUE
	swing_landed = FALSE
	// What the cut does to the body is read while the hit resolves, so its lines join the attack line.
	mantis_watch_cut(target, user)
	. = ..()
	mantis_unwatch_cut(target)
	var/landed = swing_landed
	swing_landed = FALSE
	// Only a cut that landed counts: not a blocked or cancelled swing, not a pulled
	// one. Never the wielder, whoever is in the way.
	if(. || !landed || QDELETED(target) || target == user)
		return
	on_cut_landed(target, user)

/obj/item/melee/energy/blade/hardlight/cyberware_mantis/afterattack(atom/target, mob/user, list/modifiers, list/attack_modifiers)
	. = ..()
	swing_landed = TRUE

/// A swing with this blade connected with [target]. The line's models add to it.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/on_cut_landed(mob/living/target, mob/living/user)
	return

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
	// The worn housing sprite carries the folded blade, so it hides while the blade is out.
	hide_worn_while_deployed = TRUE
	items_to_create = list(/obj/item/melee/energy/blade/hardlight/cyberware_mantis)
	// A blade sliding out of a forearm housing and snapping back into it, the
	// cursed katana's pair (mining_loot/cursed_katana.dm), not a baton's ratchet.
	extend_sound = 'sound/items/unsheath.ogg'
	retract_sound = 'sound/items/sheath.ogg'
	actions_types = list(
		/datum/action/item_action/organ_action/toggle/toolkit,
		/datum/action/cooldown/cyberware/mantis_lunge,
	)
	/// Lunge reach in tiles.
	var/lunge_range = CYBERWARE_MANTIS_LUNGE_RANGE
	/// Bonus brute the arriving lunge lands per blade out.
	var/lunge_bonus = CYBERWARE_MANTIS_LUNGE_BONUS
	/// Delay between the wind-up and the dash.
	var/lunge_telegraph = CYBERWARE_MANTIS_LUNGE_TELEGRAPH
	/// How long a connecting lunge floors its target.
	var/lunge_knockdown = CYBERWARE_MANTIS_LUNGE_KNOCKDOWN
	/// Fire stacks the arriving lunge puts on its target (and lights them
	/// with). 0 for no fire. The most of any blade that arrives lands, not the sum.
	var/lunge_fire_stacks = 0

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
	desc = "Dash up to five tiles onto a target, cutting them open and dropping them on arrival."
	button_icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	button_icon_state = "act_mantis_lunge"
	cooldown_time = 20 SECONDS
	click_to_activate = TRUE
	// A stunned, paralysed or bound body, or one with its hands tied, does not lunge.
	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_INCAPACITATED | AB_CHECK_IMMOBILE | AB_CHECK_HANDS_BLOCKED
	/// Set by a bearer that showed its line before pressing (a bounty NPC's tell): the next press runs down
	/// that line to this tile with real movement (dash()) instead of the ordinary lunge. Spent by the press.
	var/turf/dash_aim

/**
 * The housings whose blade is out right now and will arrive with the lunge.
 * Every lunging housing grants exactly one of these buttons, so walking the
 * buttons whose blade is extended finds the blades. A model with no lunge
 * button never lands in this list.
 */
/datum/action/cooldown/cyberware/mantis_lunge/proc/get_extended_housings()
	var/list/housings = list()
	if(!owner)
		return housings
	// Chrome abilities have no button and so never join mob.actions (chrome_hud.dm).
	for(var/datum/action/cooldown/cyberware/mantis_lunge/lunge_action in get_chrome_wheel_actions(owner))
		var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = lunge_action.organ
		if(istype(housing) && housing.blade_extended())
			housings += housing
	return housings

/// How many mantis blades this owner has out right now.
/datum/action/cooldown/cyberware/mantis_lunge/proc/count_extended_blades()
	return length(get_extended_housings())

/datum/action/cooldown/cyberware/mantis_lunge/Activate(atom/target)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = organ
	if(!istype(housing) || !isliving(owner))
		return FALSE
	var/mob/living/lunger = owner
	if(HAS_TRAIT(lunger, TRAIT_PACIFISM))
		to_chat(lunger, span_warning("You don't want to harm other living beings!"))
		return FALSE
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
	var/turf/aim = dash_aim
	dash_aim = null
	if(victim == lunger || victim.stat == DEAD)
		lunger.balloon_alert(lunger, "no target!")
		return FALSE
	if(get_dist(lunger, victim) > housing.lunge_range || !can_see(lunger, victim, housing.lunge_range))
		lunger.balloon_alert(lunger, "out of reach!")
		return FALSE
	// The blade is about to be used on someone.
	cyberware_camo_drop(lunger)
	// A shown line out of reach is no line: the ordinary lunge
	if(aim && (aim.z != lunger.z || get_dist(lunger, aim) > housing.lunge_range))
		aim = null
	// One lunge clock across both housings: start every mantis_lunge button
	// this owner has, ours included.
	for(var/datum/action/cooldown/cyberware/mantis_lunge/lunge_action in get_chrome_wheel_actions(lunger))
		lunge_action.StartCooldown()
	// The telegraph: readable wind-up before the dash lands.
	lunger.face_atom(victim)
	var/both_blades = count_extended_blades() > 1
	lunger.visible_message(
		span_boldwarning("[lunger] drops low, mantis blade[both_blades ? "s" : ""] laid flat along [lunger.p_their()] [both_blades ? "arms" : "arm"]!"),
		span_warning("You coil for the lunge."),
	)
	// The blades go flat along the arms for the wind-up (mantis_gore/mantis_poses.dm).
	mantis_pose_blades(get_extended_housings(), MANTIS_POSE_LUNGE)
	playsound(lunger, 'sound/items/weapons/sear.ogg', 50, TRUE)
	addtimer(CALLBACK(src, PROC_REF(do_lunge), WEAKREF(victim), null, FALSE, aim), housing.lunge_telegraph)
	return TRUE

/// The dash itself: walk the line to the target, stop adjacent, land the bonus
/// cut once per blade and floor them. [range] is how far it may reach (a charged
/// leap reaches further, mantis_gore/mantis_charge.dm); [charged] is TRUE for a
/// leap out of a crouch. With a shown line ([aim], from dash_aim) it runs down
/// that line instead (dash()).
/datum/action/cooldown/cyberware/mantis_lunge/proc/do_lunge(datum/weakref/victim_ref, range, charged = FALSE, turf/aim)
	var/mob/living/lunger = owner
	if(QDELETED(lunger))
		return
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = organ
	if(!istype(housing))
		return
	// The blades go back to the guard however the dash ends.
	var/list/posed = get_extended_housings()
	if(lunger.incapacitated || !isturf(lunger.loc))
		mantis_pose_blades(posed, MANTIS_POSE_GUARD)
		return
	if(isnull(range))
		range = housing.lunge_range
	var/mob/living/victim = victim_ref?.resolve()
	if(QDELETED(victim) || victim.stat == DEAD)
		lunger.balloon_alert(lunger, "target lost!")
		mantis_pose_blades(posed, MANTIS_POSE_GUARD)
		return
	if(aim)
		if(aim.z != lunger.z)
			lunger.balloon_alert(lunger, "target lost!")
			mantis_pose_blades(posed, MANTIS_POSE_GUARD)
			return
		INVOKE_ASYNC(src, PROC_REF(dash), lunger, victim_ref, aim, range, charged, posed)
		return
	// The ordinary lunge: walk the line to the target with a decoy per tile and stop adjacent
	var/turf/victim_turf = get_turf(victim)
	if(!victim_turf || get_dist(lunger, victim_turf) > range + 1)
		lunger.balloon_alert(lunger, "target lost!")
		mantis_pose_blades(posed, MANTIS_POSE_GUARD)
		return
	playsound(lunger, 'sound/items/weapons/bladeslice.ogg', 60, TRUE)
	var/turf/start = get_turf(lunger)
	var/list/passed = list()
	for(var/turf/step_turf as anything in get_line(start, victim_turf))
		if(step_turf == start)
			continue
		if(step_turf == victim_turf)
			break
		if(step_turf.is_blocked_turf(exclude_mobs = TRUE))
			break
		// Never over a drop, into lava or out into space: the dash stops at the edge.
		if(mantis_lunge_unsafe_turf(step_turf))
			break
		passed += lunger.loc
		lunger.forceMove(step_turf)
	// Hardlight afterimages and a streak down the line, and the body glides into place (mantis_gore/mantis_lunge_fx.dm).
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/lunge_blade = housing.active_item
	var/glide = mantis_lunge_dash_fx(lunger, start, passed, charged, istype(lunge_blade) ? lunge_blade.base_icon_state : "mantis")
	if(!lunger.Adjacent(victim))
		lunger.balloon_alert(lunger, "fell short!")
		// The blades stay flat while the body is still gliding in.
		mantis_lunge_settle(posed, glide)
		return
	land_lunge(lunger, victim, housing, lunge_blade, charged, posed, start, glide)

/**
 * A shown-line dash (dash_aim, a bounty NPC's tell): a real run down the line it showed, a tile a tick with
 * a decoy per tile, up to the tile before `aim`. Anything that stops a walker stops it there: a wall, a
 * window, a shut door, a standing body, a stun or a grab. The lunge lands only where the line said: on a
 * target still on the marked tile, or one who stepped into its way, next to it where it stops. Anyone who
 * stepped off the line is missed. It goes no further than [range] tiles, never over a drop, lava or
 * space, and leaves the lunge's afterimages and streak behind it (mantis_gore/mantis_lunge_fx.dm).
 * [posed] are the blades laid flat for the wind-up: they go back to the guard however it ends.
 */
/datum/action/cooldown/cyberware/mantis_lunge/proc/dash(mob/living/lunger, datum/weakref/victim_ref, turf/aim, range, charged = FALSE, list/posed)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = organ
	if(!istype(housing))
		mantis_pose_blades(posed, MANTIS_POSE_GUARD)
		return
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/lunge_blade = housing.active_item
	var/model = istype(lunge_blade) ? lunge_blade.base_icon_state : "mantis"
	var/turf/start = get_turf(lunger)
	var/turf/stopped_at
	var/dash_dir = get_dir(start, aim)
	var/steps = 0
	playsound(lunger, 'sound/items/weapons/bladeslice.ogg', 60, TRUE)
	for(var/turf/step_turf as anything in get_line(start, aim))
		if(step_turf == start)
			continue
		if(steps >= range || mantis_lunge_unsafe_turf(step_turf))
			break
		if(step_turf == aim || QDELETED(lunger) || lunger.incapacitated || lunger.body_position == LYING_DOWN || !isturf(lunger.loc) || lunger.pulledby?.grab_state > GRAB_PASSIVE)
			break
		var/blocked = FALSE
		for(var/mob/living/body in step_turf)
			if(body.density)
				blocked = TRUE
				break
		if(blocked)
			stopped_at = step_turf
			break
		var/turf/from = lunger.loc
		lunger.set_glide_size(DELAY_TO_GLIDE_SIZE(CYBERWARE_MANTIS_LUNGE_STEP))
		if(!lunger.Move(step_turf, get_dir(from, step_turf)) || lunger.loc != step_turf)
			break
		steps++
		// The lunge's wake on the tile it just left: hardlight afterimages and the streak.
		mantis_dash_ghost(WEAKREF(lunger), WEAKREF(from), dash_dir, steps / (range + 1), model)
		sleep(CYBERWARE_MANTIS_LUNGE_STEP)
	if(QDELETED(lunger) || lunger.stat != CONSCIOUS)
		mantis_pose_blades(posed, MANTIS_POSE_GUARD)
		return
	var/mob/living/victim = victim_ref?.resolve()
	var/turf/victim_turf = get_turf(victim)
	if(QDELETED(victim) || victim.stat == DEAD || (victim_turf != aim && victim_turf != stopped_at) || !lunger.Adjacent(victim))
		lunger.balloon_alert(lunger, "fell short!")
		mantis_pose_blades(posed, MANTIS_POSE_GUARD)
		return
	// The run was real movement: the body is already there.
	land_lunge(lunger, victim, housing, lunge_blade, charged, posed, null, 0)

/// The arrival: the bonus cut once per blade, and they go down. [housing] is the housing that lunged and
/// [lunge_blade] its blade, [charged] is TRUE for a leap out of a crouch, and [posed] are the blades laid
/// flat for the wind-up. [from] is where the ordinary lunge set out, for the impale's glide in; a shown-line
/// dash ran here on its own feet and gives none. [glide] is how long the body still takes to glide in
/// (mantis_lunge_dash_fx()): the impact, the knockdown and the blades' return to the guard wait for it, and for
/// the body's thrust at the target when it is already there.
/datum/action/cooldown/cyberware/mantis_lunge/proc/land_lunge(mob/living/lunger, mob/living/victim, obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing, obj/item/melee/energy/blade/hardlight/cyberware_mantis/lunge_blade, charged = FALSE, list/posed, turf/from, glide = 0)
	// Both housings deployed means both blades arrive. Floored at one: a blade
	// stowed during the 0.3s telegraph shouldn't eat the whole cooldown for
	// nothing when the dash still connected.
	var/list/blade_housings = get_extended_housings()
	if(!length(blade_housings))
		blade_housings = list(housing)
	var/blades = length(blade_housings)
	// Judged as they arrive, before the arrival cut: someone already hurt or down.
	var/skewer = mantis_can_impale(lunger, victim, blade_housings)

	lunger.face_atom(victim)
	lunger.do_attack_animation(victim, no_effect = TRUE)
	// The cut lands as the body does, and not before its thrust has reached them.
	var/lands_in = max(glide, CYBERWARE_MANTIS_LUNGE_THRUST)
	// The blade's own impact over the target (both blades for a pounce), and a burst of light and dust (mantis_gore/mantis_lunge_fx.dm).
	mantis_lunge_arrival_fx(lunger, victim, istype(lunge_blade) ? lunge_blade.impact_state : "impact_mantis", charged && blades > 1, lands_in)
	// The arrival counts toward the lunger's kill (mantis_gore/mantis_cuts.dm).
	mantis_note_hit(victim, lunger)
	// One armor roll for the arrival, reused per blade. Both land in the same
	// instant on the same plate, and it keeps the armor message to one line.
	var/armor_block = victim.run_armor_check(BODY_ZONE_CHEST, MELEE)
	var/lunge_fire = 0
	for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/blade_housing as anything in blade_housings)
		victim.apply_damage(
			blade_housing.lunge_bonus,
			BRUTE,
			BODY_ZONE_CHEST,
			armor_block,
			wound_bonus = 10,
			sharpness = SHARP_EDGED,
		)
		lunge_fire = max(lunge_fire, blade_housing.lunge_fire_stacks)
	if(lunge_fire)
		cyberware_scorch_target(victim, lunge_fire)
	// Both blades into someone already hurt: held up on them, then ripped free (mantis_gore/mantis_impale.dm).
	// The knockdown waits for the rip.
	if(skewer && !QDELETED(victim) && victim.stat != DEAD && mantis_start_impale(src, lunger, victim, blade_housings, housing.lunge_knockdown, from, charged ? 2 : MANTIS_LUNGE_GLIDE))
		log_combat(lunger, victim, "mantis-lunged and impaled", "mantis blades ([blades] landed)")
		playsound(victim, 'sound/effects/wounds/pierce3.ogg', 70, TRUE)
		return
	// The blades stay flat through the glide and come back to the guard as the body lands, and they go down
	// then, with the impact (mantis_gore/mantis_lunge_fx.dm).
	mantis_lunge_settle(posed, lands_in)
	mantis_lunge_knockdown(victim, housing.lunge_knockdown, lands_in)
	if(charged)
		if(blades > 1)
			victim.visible_message(
				span_danger("[lunger] springs at [victim] and shuts both blades on [victim.p_them()], dropping [victim.p_them()]!"),
				span_userdanger("[lunger] springs at you. Both blades land at once and your legs go out from under you!"),
			)
		else
			victim.visible_message(
				span_danger("[lunger] springs at [victim], opens [victim.p_them()] up and puts [victim.p_them()] down!"),
				span_userdanger("[lunger] springs at you. The blade is already in you, and the floor comes up fast!"),
			)
	else if(blades > 1)
		victim.visible_message(
			span_danger("[lunger] flickers across the gap and shuts both blades on [victim] like a trap, dropping [victim.p_them()]!"),
			span_userdanger("[lunger] flickers across the gap. Both blades land at once and your legs go out from under you!"),
		)
	else
		victim.visible_message(
			span_danger("[lunger] flickers across the gap, opens [victim] up on arrival and puts [victim.p_them()] down!"),
			span_userdanger("[lunger] flickers across the gap. The blade is already in you, and the floor comes up fast!"),
		)
	log_combat(lunger, victim, charged ? "mantis-leapt" : "mantis-lunged", "mantis blades ([blades] landed)")
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
 * and both halves carry through.
 *
 * Every landed hit carries on into one body at most: the one standing right
 * behind the victim along the swing, allies filtered out, for
 * CYBERWARE_MONOWIRE_CLEAVE_MULT of both, never taking a limb. The
 * through-cut, severs and the garrote live in voidcrew/modules/hyperviolence/wire/.
 */
/obj/item/melee/cyberware_monowire
	name = "\improper Widowline monowire"
	desc = "A weighted spool of monomolecular line, run live. At rest it's a glitter in the air."
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
	/// Cleave fraction of the wire's damage dealt to secondary targets.
	var/cleave_mult = CYBERWARE_MONOWIRE_CLEAVE_MULT
	/// Burn the charged line adds on top of the cut, every hit.
	var/charge_burn = CYBERWARE_MONOWIRE_BURN
	/// Set by afterattack() during attack()'s parent call. Only a swing that
	/// connected gets that far, and attack()'s own return can't tell a hit from
	/// a pacifist's pulled swing or a signal-skipped one (both return FALSE).
	var/swing_landed = FALSE

/obj/item/melee/cyberware_monowire/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	// The parent plays hitsound partway through the swing, so pick which of the
	// line's two voices we are before handing off.
	hitsound = pick('voidcrew/sound/monowire1.ogg', 'voidcrew/sound/monowire2.ogg')
	swing_landed = FALSE
	// The cut rides the hit: clean severs and the through-cut land
	// while tg resolves it, so their lines join its message (hyperviolence/wire/wire_cut.dm).
	wire_cut_begin(target, user)
	. = ..()
	var/landed = swing_landed
	swing_landed = FALSE
	// No cut landed (blocked, cancelled, pulled), so nothing burns.
	if(. || !landed || QDELETED(target) || !isliving(user))
		wire_cut_end(target)
		return

	// The charge on the line, on top of the cut. Silent armor check: the parent
	// already announced the penetration for this same swing. Still part of the clean
	// cut: a wound the cut just opened throws no blood when the charge lands on it.
	var/burn_zone = target.get_random_valid_zone(user.zone_selected)
	target.apply_damage(
		charge_burn,
		BURN,
		burn_zone,
		target.run_armor_check(burn_zone, MELEE, armour_penetration = armour_penetration, silent = TRUE),
	)
	wire_cut_end(target)

/obj/item/melee/cyberware_monowire/afterattack(atom/target, mob/user, list/modifiers, list/attack_modifiers)
	. = ..()
	swing_landed = TRUE
	if(!isliving(user) || QDELETED(target) || target == user)
		return
	// The wire lashes out of the hand to what it hit (hyperviolence/wire/wire_held.dm), standing in for the held wire.
	wire_lash_at(user, target, lash_zone)
	lash_zone = null

/**
 * # Widowline Monowire (T3, one arm, aug slot, load 5)
 *
 * A single-arm spool housing deploying the wire above. Reach two, carries on
 * into whoever stands behind what it lands on, and armor does nothing to slow it down.
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
	extend_sound = 'voidcrew/sound/monowire_deploy.ogg'
	retract_sound = 'voidcrew/sound/monowire_retract.ogg'

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
	desc = "A stubby caseless round in Ronin's proprietary 10x24mm."
	caliber = CYBERWARE_CALIBER_RONIN
	projectile_type = /obj/projectile/bullet/cyberware_ronin

/obj/item/ammo_casing/cyberware_ronin/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/caseless)

/**
 * The proprietary magazine. Sold at the parlor, with a costly fabrication
 * alternative unlocked by Experimental Ammunition research.
 */
/obj/item/ammo_box/magazine/cyberware_ronin
	name = "\improper Ronin flush-feed magazine (10x24mm)"
	desc = "A flush-feed magazine keyed to the Popup Ronin's action and nothing else's."
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
	desc = "A skeletal machine-pistol that folds flat enough to live inside a forearm. Feeds from proprietary flush-feed magazines."
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
	desc = "A forearm rig that unfolds a skeletal machine-pistol into your grip and folds it away again just as fast."
	icon_state = "ronin"
	chrome_load = 5
	tier = CYBERWARE_TIER_3
	aug_overlay = "ronin"
	items_to_create = list(/obj/item/gun/ballistic/automatic/cyberware_ronin)
	extend_sound = 'sound/items/weapons/batonextend.ogg'

// =========================================================================
// BUNKER BUSTER
// =========================================================================

/// Proprietary rocket caliber, sold at the parlor and fabricable with late research.
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
	desc = "A stubby shaped-charge rocket in the Buster's proprietary 30mm."
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
	desc = "Two 30mm shaped rockets in a carry bracket, keyed to the Buster's rotary rack."
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
	desc = "A two-tube rocket pod that rides folded along the forearm."
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
 * The arm that ends arguments with cover. Two rockets before reloading;
 * replacements require a parlor visit or expensive late-research fabrication.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/bunker_buster
	name = "\improper Bunker Buster housing"
	desc = "A reinforced forearm bay built around two rocket tubes, with a recoil bed where your radius used to be."
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
#undef CYBERWARE_MANTIS_LUNGE_STEP
#undef CYBERWARE_MANTIS_LUNGE_THRUST
#undef CYBERWARE_MONOWIRE_CLEAVE_MULT
#undef CYBERWARE_MONOWIRE_BURN
#undef CYBERWARE_CALIBER_RONIN
#undef CYBERWARE_CALIBER_BUSTER
