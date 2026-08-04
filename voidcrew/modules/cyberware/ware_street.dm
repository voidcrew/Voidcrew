/**
 * # Street chrome (Tier 1)
 *
 * The cheap shelf: job-lube and fun utility, credits only. Every ware here
 * rides /obj/item/organ/cyberimp/cyberware (chest-default generic base)
 * except Nightshade, which lives with the other optics in the eyes base.
 * The two toolkit-arm T1s (Rockjaw, Fixer's Fingers) are in
 * ware_arm_utility.dm; the T2 shelf is ware_pro_utility.dm.
 */

/// Flat damage Scrapper's Knuckles adds to an unarmed punch against mobs.
#define CYBERWARE_SCRAPPER_PUNCH_BONUS 4
/// How long the Gecko Grips chasm-lip catch takes to re-set after saving you.
#define CYBERWARE_GECKO_CATCH_COOLDOWN (30 SECONDS)
/// Disgust scrubbed from the Gastro Reactor's bearer per second — the
/// "food poisoning immunity": you never build up to retching.
#define CYBERWARE_GASTRO_DISGUST_PURGE 3
/// Perceived-quality bonus the Gastro Reactor adds to anything you eat.
/// +6 lifts gross/rotten (-5 tier) food back above "meh" so it goes down
/// without complaint; species-toxic food still refuses to become dinner.
#define CYBERWARE_GASTRO_QUALITY_BONUS 6
/// Biggest item the Cargo Cavity will swallow.
#define CYBERWARE_CAVITY_MAX_WCLASS WEIGHT_CLASS_SMALL

// ---- 1. Chromatic Dermis ----------------------------------------------

/**
 * # Chromatic Dermis (T1, chest, ink slot, load 0)
 *
 * Emissive circuit-tattoos under the skin: pure flex, everyone's first
 * install. Rendered as a coloured outline on the bearer — it flares when
 * they take a hit, strobes when any chrome ability fires, and dims to a
 * guttering trace when they're starving (the ink runs off body sugar).
 * Colour and pattern are re-keyed at the Chrome Cradle's Configure button.
 */
/obj/item/organ/cyberimp/cyberware/chromatic_dermis
	name = "\improper Chromatic Dermis ink suite"
	desc = "A sachet of programmable tattoo ink and its injector spider. The circuit patterns crawl under the skin and light up when your body does something worth watching. Colour and pattern get set at a Chrome Cradle."
	icon_state = "chromatic_dermis"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_INK
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 0
	tier = CYBERWARE_TIER_1
	/// Glow colour, "#rrggbb". Set at the Cradle; defaults to parlor cyan.
	var/tattoo_color = "#4dd8e6"
	/// Flavor pattern name, picked at the Cradle. Examine-only.
	var/tattoo_pattern = "circuit traces"
	/// Filter key on the bearer. Keyed to us so two-dermis nonsense can't collide.
	var/filter_name = "chromatic_dermis"
	/// The outline alpha the ink idles at, recomputed each life tick from
	/// nutrition and failure state. Cached so we only touch the filter on change.
	var/current_alpha = -1

/obj/item/organ/cyberimp/cyberware/chromatic_dermis/examine(mob/user)
	. = ..()
	. += span_notice("The ink is keyed to <font color='[tattoo_color]'>this colour</font> in a [tattoo_pattern] pattern.")

/obj/item/organ/cyberimp/cyberware/chromatic_dermis/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	current_alpha = -1
	organ_owner.add_filter(filter_name, 2, outline_filter(1, glow_color(140)))
	settle_glow()
	RegisterSignal(organ_owner, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(on_owner_damaged))
	RegisterSignal(organ_owner, COMSIG_MOB_ABILITY_STARTED, PROC_REF(on_ability_started))

/obj/item/organ/cyberimp/cyberware/chromatic_dermis/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(organ_owner, list(COMSIG_MOB_APPLY_DAMAGE, COMSIG_MOB_ABILITY_STARTED))
	organ_owner.remove_filter(filter_name)
	current_alpha = -1

/// The tattoo colour with an alpha byte appended, for the outline filter.
/obj/item/organ/cyberimp/cyberware/chromatic_dermis/proc/glow_color(alpha)
	return "[tattoo_color][num2hex(clamp(alpha, 0, 255), 2)]"

/**
 * Recomputes the idle glow: browned-out/EMP'd ink goes dark, a starving
 * bearer's ink gutters low, everyone else gets the full parlor shine.
 * Called every life tick — cheap, and only touches the filter on change.
 */
/obj/item/organ/cyberimp/cyberware/chromatic_dermis/proc/settle_glow()
	if(!owner)
		return
	var/target_alpha = 140
	if(organ_flags & ORGAN_FAILING)
		target_alpha = 0
	else if(owner.nutrition < NUTRITION_LEVEL_HUNGRY)
		target_alpha = 45
	if(target_alpha == current_alpha)
		return
	current_alpha = target_alpha
	var/filter = owner.get_filter(filter_name)
	if(filter)
		animate(filter, color = glow_color(target_alpha), time = 1 SECONDS)

/obj/item/organ/cyberimp/cyberware/chromatic_dermis/on_life(seconds_per_tick, times_fired)
	. = ..()
	settle_glow()

/// Signal proc for [COMSIG_MOB_APPLY_DAMAGE]: the ink flares hot when the
/// bearer takes a real hit, then eases back to idle.
/obj/item/organ/cyberimp/cyberware/chromatic_dermis/proc/on_owner_damaged(datum/source, damage, damagetype, def_zone)
	SIGNAL_HANDLER
	if(damage < 1 || (organ_flags & ORGAN_FAILING) || !owner)
		return
	var/filter = owner.get_filter(filter_name)
	if(!filter)
		return
	animate(filter, color = glow_color(255), time = 0.1 SECONDS)
	animate(color = glow_color(current_alpha), time = 0.9 SECONDS)

/// Signal proc for [COMSIG_MOB_ABILITY_STARTED]: a quick double-strobe
/// whenever any chrome cooldown ability fires. Other ability families
/// (spells, mob abilities) don't light the ink — chrome answers chrome.
/obj/item/organ/cyberimp/cyberware/chromatic_dermis/proc/on_ability_started(mob/source, datum/action/cooldown/ability)
	SIGNAL_HANDLER
	if(!istype(ability, /datum/action/cooldown/cyberware) || (organ_flags & ORGAN_FAILING) || !owner)
		return
	var/filter = owner.get_filter(filter_name)
	if(!filter)
		return
	animate(filter, color = glow_color(230), time = 0.15 SECONDS)
	animate(color = glow_color(60), time = 0.15 SECONDS)
	animate(color = glow_color(230), time = 0.15 SECONDS)
	animate(color = glow_color(current_alpha), time = 0.4 SECONDS)

/**
 * The Cradle's Configure hook: pattern list plus a colour picker. Called
 * async from chrome_cradle's ui_act, so input() is safe to block on. The
 * re-validation after each prompt matters — the patient can be pulled off
 * the chair mid-decision.
 */
/obj/item/organ/cyberimp/cyberware/chromatic_dermis/proc/configure(mob/living/carbon/user)
	if(user != owner)
		return
	var/static/list/patterns = list("circuit traces", "serpent coil", "hex weave", "starburst", "bar code")
	var/new_pattern = tgui_input_list(user, "Ink pattern", "Chromatic Dermis", patterns, tattoo_pattern)
	if(new_pattern && user == owner)
		tattoo_pattern = new_pattern
	var/new_color = input(user, "Glow colour", "Chromatic Dermis", tattoo_color) as color|null
	if(new_color && user == owner)
		tattoo_color = new_color
		var/filter = owner.get_filter(filter_name)
		if(filter)
			animate(filter, color = glow_color(255), time = 0.2 SECONDS)
			animate(color = glow_color(current_alpha), time = 0.8 SECONDS)
	if(user == owner)
		user.balloon_alert(user, "ink re-keyed")

// ---- 2. Nightshade Optics ---------------------------------------------

/**
 * # Nightshade Optics (T1, eyes, load 1)
 *
 * Darkness vision with none of the thermal line's flash weakness — purely
 * declarative: the colour cutoffs light the dark through the standard eye
 * sight-update chain, flash_protect stays at the robotic default, and
 * there's no SEE_MOBS (wallhacks are the thermal tradeoff, not ours).
 */
/obj/item/organ/eyes/robotic/cyberware/nightshade
	name = "\improper Nightshade optics"
	desc = "Matte black eyes that drink whatever light there is and hand it back green. Unlike the printable thermal and shield lines, these take a flashbang no worse than the eyes you were born with — in the dark-site lane, nothing on a fab beats them."
	icon_state = "nightshade"
	eye_color_left = "#1d3b2a"
	eye_color_right = "#1d3b2a"
	iris_overlay = null
	// Downshift red so darkness reads as a cold botanical green.
	color_cutoffs = list(10, 30, 20)
	chrome_load = 1
	tier = CYBERWARE_TIER_1

// ---- 3. Scrapper's Knuckles -------------------------------------------

/**
 * # Scrapper's Knuckles (T1, arm muscle slots, load 1 per arm)
 *
 * Reinforced knuckle plating on the arm's muscle slot — the first rung of
 * the muscle ladder Gorilla Arms evicts. Sold as a cased pair; each arm
 * carries half the pair's load, so the incumbent netting works per-arm
 * with no special casing.
 *
 * The punch hook is the strongarm implant's EARLY_UNARMED_ATTACK pattern
 * (augments_arms.dm) with our own damage line: flat +4 on the bodypart's
 * unarmed roll against mobs, and double that total against structures and
 * machines with a clang. Deliberately absent: strongarm's x2 slam
 * multiplier, its +20 biotype bonus, and its throw — this is a workman's
 * implant, not a haymaker.
 */
/obj/item/organ/cyberimp/cyberware/scrapper
	name = "\improper Scrapper's Knuckles"
	desc = "Milled knuckle caps grafted along the metacarpals, right-arm fit. Hits from a fist you were already swinging just land harder — and against plating and machine housings they land twice as hard."
	icon_state = "scrapper"
	zone = BODY_ZONE_R_ARM
	slot = ORGAN_SLOT_RIGHT_ARM_MUSCLE
	valid_zones = list(
		BODY_ZONE_R_ARM = ORGAN_SLOT_RIGHT_ARM_MUSCLE,
		BODY_ZONE_L_ARM = ORGAN_SLOT_LEFT_ARM_MUSCLE,
	)
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 1
	tier = CYBERWARE_TIER_1

/obj/item/organ/cyberimp/cyberware/scrapper/left
	desc = "Milled knuckle caps grafted along the metacarpals, left-arm fit. Hits from a fist you were already swinging just land harder — and against plating and machine housings they land twice as hard."
	zone = BODY_ZONE_L_ARM
	slot = ORGAN_SLOT_LEFT_ARM_MUSCLE

/obj/item/organ/cyberimp/cyberware/scrapper/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	if(ishuman(organ_owner))
		RegisterSignal(organ_owner, COMSIG_LIVING_EARLY_UNARMED_ATTACK, PROC_REF(on_punch))

/obj/item/organ/cyberimp/cyberware/scrapper/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(organ_owner, COMSIG_LIVING_EARLY_UNARMED_ATTACK)

/**
 * Signal proc for [COMSIG_LIVING_EARLY_UNARMED_ATTACK]. Both arms' organs
 * listen; the active-hand zone gate means exactly one acts per swing.
 * Guard set copied from strongarm: combat mode only, left-click only, no
 * hulks (their fists have their own rules), and the can_unarmed_attack
 * cancel-chain contract.
 */
/obj/item/organ/cyberimp/cyberware/scrapper/proc/on_punch(mob/living/carbon/human/source, atom/target, proximity, modifiers)
	SIGNAL_HANDLER
	var/obj/item/bodypart/active_hand = source.get_active_hand()
	if(!active_hand || active_hand.body_zone != zone || !proximity)
		return NONE
	if(!source.combat_mode || LAZYACCESS(modifiers, RIGHT_CLICK))
		return NONE
	if(HAS_TRAIT(source, TRAIT_HULK))
		return NONE
	if(organ_flags & ORGAN_FAILING) // browned out: just a fist again
		return NONE
	var/is_structure_target = ismachinery(target) || isstructure(target)
	if(!isliving(target) && !is_structure_target)
		return NONE
	if(!source.can_unarmed_attack())
		return COMPONENT_SKIP_ATTACK

	var/punch_damage = CYBERWARE_SCRAPPER_PUNCH_BONUS + rand(active_hand.unarmed_damage_low, active_hand.unarmed_damage_high)
	source.changeNext_move(CLICK_CD_MELEE)

	if(is_structure_target)
		var/obj/smashed = target
		source.do_attack_animation(smashed, ATTACK_EFFECT_SMASH)
		smashed.take_damage(punch_damage * 2, BRUTE, MELEE, TRUE, get_dir(smashed, source))
		playsound(smashed, 'sound/effects/clang.ogg', 50, TRUE)
		log_combat(source, smashed, "punched (scrapper's knuckles)")
		return COMPONENT_CANCEL_ATTACK_CHAIN

	var/mob/living/living_target = target
	if(ishuman(living_target))
		var/mob/living/carbon/human/human_target = living_target
		if(human_target.check_block(source, punch_damage, "[source]'s reinforced punch"))
			source.do_attack_animation(living_target)
			playsound(living_target.loc, 'sound/items/weapons/punchmiss.ogg', 25, TRUE, -1)
			log_combat(source, living_target, "attempted to punch (scrapper's knuckles)")
			return COMPONENT_CANCEL_ATTACK_CHAIN

	source.do_attack_animation(living_target, ATTACK_EFFECT_PUNCH)
	playsound(living_target.loc, 'sound/items/weapons/punch1.ogg', 25, TRUE, -1)
	var/target_zone = living_target.get_random_valid_zone(source.zone_selected)
	var/armor_block = living_target.run_armor_check(target_zone, MELEE, armour_penetration = active_hand.unarmed_effectiveness)
	living_target.apply_damage(punch_damage, active_hand.attack_type, target_zone, armor_block)
	living_target.visible_message(
		span_danger("[source] punches [living_target] with a metallic crunch!"),
		span_userdanger("You're punched by [source]'s reinforced fist!"),
		span_hear("You hear a heavy crunch!"),
		COMBAT_MESSAGE_RANGE,
		source,
	)
	to_chat(source, span_danger("You punch [living_target] with your reinforced fist!"))
	log_combat(source, living_target, "punched (scrapper's knuckles)")
	return COMPONENT_CANCEL_ATTACK_CHAIN

// The pair, as sold: one case, two organs, install each arm separately.

/obj/item/storage/case/cyberware
	name = "cyberware case"
	desc = "A foam-lined chrome case from the Undertow parlor."
	icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	icon_state = "ware_case"
	w_class = WEIGHT_CLASS_NORMAL

/obj/item/storage/case/cyberware/scrapper
	name = "\improper Scrapper's Knuckles case"
	desc = "A foam-lined chrome case holding a matched pair of Scrapper's Knuckles, one per arm. Install each side separately — the rig does both in one sitting."

/obj/item/storage/case/cyberware/scrapper/PopulateContents()
	new /obj/item/organ/cyberimp/cyberware/scrapper(src)
	new /obj/item/organ/cyberimp/cyberware/scrapper/left(src)

// ---- 5. Shock Coils ----------------------------------------------------

/**
 * # Shock Coils (T1, legs, load 1)
 *
 * Reflex pistons in the calves: you spring back up from knockdowns, wet
 * floors stop being a hazard (galoshes tier — soap and ice still win),
 * and drops land soft on the MOD longfall pattern. First rung of the leg
 * ladder; Hopper Pistons evict it.
 */
/obj/item/organ/cyberimp/cyberware/shock_coils
	name = "\improper Shock Coil calf pistons"
	desc = "Spring-loaded pistons sistered along the calf bones. They put you back on your feet before the floor finishes introducing itself, shrug off wet decking, and soak a drop that would crack an ankle."
	icon_state = "shock_coils"
	zone = BODY_ZONE_L_LEG
	slot = ORGAN_SLOT_CYBERWARE_LEGS
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	organ_traits = list(TRAIT_NO_SLIP_WATER)

/obj/item/organ/cyberimp/cyberware/shock_coils/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(organ_owner, COMSIG_LIVING_Z_IMPACT, PROC_REF(on_z_impact))
	if(!ishuman(organ_owner))
		return
	var/mob/living/carbon/human/human_owner = organ_owner
	// Physiology persists across species changes (physiology.dm:1), so a
	// single apply/remove pair is safe — no species-gain re-hook needed.
	human_owner.physiology.knockdown_mod *= 0.5
	human_owner.physiology.stun_mod *= 0.8

/obj/item/organ/cyberimp/cyberware/shock_coils/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(organ_owner, COMSIG_LIVING_Z_IMPACT)
	if(!ishuman(organ_owner) || QDELETED(organ_owner))
		return
	var/mob/living/carbon/human/human_owner = organ_owner
	human_owner.physiology.knockdown_mod /= 0.5
	human_owner.physiology.stun_mod /= 0.8

/// Signal proc for [COMSIG_LIVING_Z_IMPACT]: the MOD longfall pattern,
/// minus the suit's power cost. Big multi-level drops still stagger.
/obj/item/organ/cyberimp/cyberware/shock_coils/proc/on_z_impact(datum/source, levels, turf/fell_on)
	SIGNAL_HANDLER
	if(organ_flags & ORGAN_FAILING)
		return NONE
	new /obj/effect/temp_visual/mook_dust(fell_on)
	if(levels >= 2)
		owner.adjust_staggered_up_to(STAGGERED_SLOWDOWN_LENGTH * levels, 10 SECONDS)
	owner.visible_message(
		span_notice("[owner] lands on [fell_on] with a piston hiss."),
		span_notice("Your shock coils drink the impact."),
	)
	return ZIMPACT_CANCEL_DAMAGE | ZIMPACT_NO_MESSAGE | ZIMPACT_NO_SPIN

// ---- 7. Gastro Reactor -------------------------------------------------

/**
 * # Gastro Reactor (T1, chest, gut slot, load 1)
 *
 * A processing gut that treats food as feedstock. Three legs, all live
 * primitives: TRAIT_STRONG_STOMACH covers floor food and halves vomit
 * losses, TRAIT_VORACIOUS is tg's eat-fast trait, and the perceived-quality
 * signal lifts rotten/gross fare back above the disgust thresholds so it
 * goes down clean. A continuous disgust scrub mops up whatever still gets
 * through — you never build to retching. Species-toxic foodtypes stay
 * toxic (the quality chain early-returns before our bonus applies), which
 * is the addendum's "edible things only" rescope.
 */
/obj/item/organ/cyberimp/cyberware/gastro
	name = "\improper Gastro Reactor"
	desc = "A ceramic-lined digester that replaces squeamishness with throughput. Rot, floor finds, gas-station sushi: it all burns the same, faster than a natural gut and with none of the after-action regret."
	icon_state = "gastro"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_GUT
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	organ_traits = list(TRAIT_STRONG_STOMACH, TRAIT_VORACIOUS)

/obj/item/organ/cyberimp/cyberware/gastro/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(organ_owner, COMSIG_LIVING_GET_PERCEIVED_FOOD_QUALITY, PROC_REF(on_food_quality))

/obj/item/organ/cyberimp/cyberware/gastro/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(organ_owner, COMSIG_LIVING_GET_PERCEIVED_FOOD_QUALITY)

/// Signal proc for [COMSIG_LIVING_GET_PERCEIVED_FOOD_QUALITY]: everything
/// tastes like fuel, which is to say fine.
/obj/item/organ/cyberimp/cyberware/gastro/proc/on_food_quality(mob/living/source, datum/component/edible/food, list/extra_quality)
	SIGNAL_HANDLER
	if(organ_flags & ORGAN_FAILING)
		return
	extra_quality += CYBERWARE_GASTRO_QUALITY_BONUS

/obj/item/organ/cyberimp/cyberware/gastro/on_life(seconds_per_tick, times_fired)
	. = ..()
	if(organ_flags & ORGAN_FAILING)
		return
	if(owner.disgust > 0)
		owner.adjust_disgust(-CYBERWARE_GASTRO_DISGUST_PURGE * seconds_per_tick)

// ---- 9. Cargo Cavity ---------------------------------------------------

/**
 * # Cargo Cavity (T1, chest, stash slot, load 1, ORGAN_HIDDEN)
 *
 * One small item, inside your chest, off every manifest: ORGAN_HIDDEN
 * keeps it out of health analyzers, and the strip UI never lists organs —
 * PvP loot protection is the intended use. Deliberately NOT a storage
 * component (ABSTRACT/NODROP conflicts); a single tracked ref plus an
 * organ action does the whole job. The stash rides the organ on removal,
 * and the cyberware base's Destroy drops contents rather than eating them.
 */
/obj/item/organ/cyberimp/cyberware/cargo_cavity
	name = "\improper Cargo Cavity"
	desc = "A shielded compartment plumbed into the ribcage, sized for one small item. Nothing on a scanner, nothing in a pat-down. What's in your chest is your business."
	icon_state = "cargo_cavity"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_STASH
	organ_flags = ORGAN_ROBOTIC | ORGAN_HIDDEN
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	actions_types = list(/datum/action/item_action/organ_action/use)
	/// The one item riding in the cavity.
	var/obj/item/stashed

/obj/item/organ/cyberimp/cyberware/cargo_cavity/examine(mob/user)
	. = ..()
	if(stashed)
		. += span_notice("[stashed] is packed inside.")

/obj/item/organ/cyberimp/cyberware/cargo_cavity/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == stashed)
		stashed = null

/// One button, two verbs: empty cavity swallows the active-hand item,
/// loaded cavity hands it back.
/obj/item/organ/cyberimp/cyberware/cargo_cavity/ui_action_click()
	if(organ_flags & ORGAN_FAILING)
		owner.balloon_alert(owner, "cavity seized shut!")
		return
	if(stashed)
		var/obj/item/returned = stashed
		returned.forceMove(owner.drop_location())
		owner.put_in_hands(returned)
		owner.balloon_alert(owner, "[returned.name] ejected")
		playsound(owner, 'sound/machines/click.ogg', 30, TRUE)
		return
	var/obj/item/held = owner.get_active_held_item()
	if(!held)
		owner.balloon_alert(owner, "nothing in hand!")
		return
	if(held.w_class > CYBERWARE_CAVITY_MAX_WCLASS)
		owner.balloon_alert(owner, "too big for the cavity!")
		return
	if((held.item_flags & ABSTRACT) || HAS_TRAIT(held, TRAIT_NODROP))
		owner.balloon_alert(owner, "it won't come loose!")
		return
	if(!owner.transferItemToLoc(held, src))
		owner.balloon_alert(owner, "it won't come loose!")
		return
	stashed = held
	owner.balloon_alert(owner, "[held.name] stashed away")
	playsound(owner, 'sound/items/eatfood.ogg', 20, TRUE)

// ---- 10. Dermal Mesh ---------------------------------------------------

/datum/armor/cyberware_dermal_mesh
	melee = 10
	bullet = 10

/**
 * # Dermal Mesh (T1, chest, dermal slot, load 2)
 *
 * Light woven plating under the skin — the roach-organ physiology armor
 * pattern, sized at 10 melee/bullet. Exists to be the rung Slabskin Plate
 * evicts. Physiology explicitly survives species changes (physiology.dm:1),
 * so one add/subtract pair is the whole lifecycle; re-applying on species
 * gain would stack the armor.
 */
/obj/item/organ/cyberimp/cyberware/dermal_mesh
	name = "\improper Dermal Mesh weave"
	desc = "A subdermal lattice of impact polymer. It won't stop anything dramatic, but the everyday knives and small arms of a working port hurt noticeably less."
	icon_state = "dermal_mesh"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_DERMAL
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 2
	tier = CYBERWARE_TIER_1
	/// Armor mixed into the bearer's physiology while installed.
	var/datum/armor/mesh_armor = /datum/armor/cyberware_dermal_mesh

/obj/item/organ/cyberimp/cyberware/dermal_mesh/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	if(!ishuman(organ_owner))
		return
	var/mob/living/carbon/human/human_owner = organ_owner
	human_owner.physiology.armor = human_owner.physiology.armor.add_other_armor(mesh_armor)

/obj/item/organ/cyberimp/cyberware/dermal_mesh/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	if(!ishuman(organ_owner) || QDELETED(organ_owner))
		return
	var/mob/living/carbon/human/human_owner = organ_owner
	human_owner.physiology.armor = human_owner.physiology.armor.subtract_other_armor(mesh_armor)

// ---- 11. Gecko Grips ---------------------------------------------------

/**
 * # Gecko Grips (T1, arm, hands slot, load 1)
 *
 * Setae-pad palms, respec'd per the freeze addendum: NOT passive nodrop.
 * The grips clamp only when a stun would strip your hands — we pre-grip on
 * the status signals (they fire before the status applies, and therefore
 * before living's own HANDS_BLOCKED handler dumps your hands, which is
 * registered at mob init and would always beat an organ listener), then
 * release when TRAIT_HANDS_BLOCKED lifts. A deferred check un-grips
 * cleanly if the stun never actually landed.
 *
 * Kept from the anti-drop implant it apes: the EMP tradeoff — a pulse
 * spasms the pads and hurls whatever you're holding.
 *
 * Passives: TRAIT_FREERUNNING (tables stop being furniture) and a chasm
 * lip-catch. The catch arms TRAIT_CHASM_STOPPER on you (the chasm
 * component refuses to drop anything on a tile containing a STOPPER);
 * stepping onto a chasm consumes the catch — you're shoved back to the
 * lip and the pads need [CYBERWARE_GECKO_CATCH_COOLDOWN/10]s to re-set,
 * during which chasms are exactly as lethal as ever.
 */
/obj/item/organ/cyberimp/cyberware/gecko
	name = "\improper Gecko Grip palm pads"
	desc = "Van-der-Waals setae pads laminated into the palms. Your hands clamp shut of their own accord when something knocks the lights out, tables read as flat ground, and once in a while they're the reason a chasm didn't get you."
	icon_state = "gecko"
	zone = BODY_ZONE_R_ARM
	slot = ORGAN_SLOT_CYBERWARE_HANDS
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	organ_traits = list(TRAIT_FREERUNNING)
	/// Items currently clamped with our NODROP.
	var/list/obj/item/gripped = list()
	/// Whether the chasm catch is armed.
	var/catch_ready = TRUE
	/// Status signals that precede a hand-stripping incapacitation.
	var/static/list/grip_signals = list(
		COMSIG_LIVING_STATUS_STUN,
		COMSIG_LIVING_STATUS_PARALYZE,
		COMSIG_LIVING_STATUS_UNCONSCIOUS,
	)

/obj/item/organ/cyberimp/cyberware/gecko/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignals(organ_owner, grip_signals, PROC_REF(on_incapacitating_status))
	RegisterSignal(organ_owner, COMSIG_LIVING_ENTER_STAMCRIT, PROC_REF(on_stamcrit))
	RegisterSignal(organ_owner, SIGNAL_REMOVETRAIT(TRAIT_HANDS_BLOCKED), PROC_REF(on_hands_freed))
	RegisterSignal(organ_owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	if(catch_ready)
		ADD_TRAIT(organ_owner, TRAIT_CHASM_STOPPER, REF(src))

/obj/item/organ/cyberimp/cyberware/gecko/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	release_grip()
	UnregisterSignal(organ_owner, grip_signals)
	UnregisterSignal(organ_owner, list(COMSIG_LIVING_ENTER_STAMCRIT, SIGNAL_REMOVETRAIT(TRAIT_HANDS_BLOCKED), COMSIG_MOVABLE_MOVED))
	REMOVE_TRAIT(organ_owner, TRAIT_CHASM_STOPPER, REF(src))

/// Signal proc for the incapacitating status signals: clamp before the
/// status (and its item-dropping trait) lands.
/obj/item/organ/cyberimp/cyberware/gecko/proc/on_incapacitating_status(datum/source, amount)
	SIGNAL_HANDLER
	if(amount <= 0)
		return
	grip_held_items()

/// Signal proc for [COMSIG_LIVING_ENTER_STAMCRIT]: stamina collapse strips
/// hands too.
/obj/item/organ/cyberimp/cyberware/gecko/proc/on_stamcrit(datum/source)
	SIGNAL_HANDLER
	grip_held_items()

/obj/item/organ/cyberimp/cyberware/gecko/proc/grip_held_items()
	if(organ_flags & ORGAN_FAILING || !owner)
		return
	var/clamped_any = FALSE
	for(var/obj/item/held in owner.held_items)
		if(HAS_TRAIT(held, TRAIT_NODROP))
			continue
		ADD_TRAIT(held, TRAIT_NODROP, REF(src))
		RegisterSignal(held, COMSIG_ITEM_DROPPED, PROC_REF(on_gripped_item_dropped))
		gripped += held
		clamped_any = TRUE
	if(clamped_any)
		owner.balloon_alert(owner, "grips clamp!")
		// The stun may still have been blocked — if no hand-block actually
		// arrives, let go rather than welding their hands shut forever.
		addtimer(CALLBACK(src, PROC_REF(verify_grip)), 0.5 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE)

/obj/item/organ/cyberimp/cyberware/gecko/proc/verify_grip()
	if(!owner || !HAS_TRAIT(owner, TRAIT_HANDS_BLOCKED))
		release_grip()

/// Signal proc for [SIGNAL_REMOVETRAIT] of [TRAIT_HANDS_BLOCKED]: awake
/// again, hands are yours.
/obj/item/organ/cyberimp/cyberware/gecko/proc/on_hands_freed(datum/source)
	SIGNAL_HANDLER
	release_grip()

/obj/item/organ/cyberimp/cyberware/gecko/proc/release_grip()
	if(!length(gripped))
		return
	for(var/obj/item/held as anything in gripped)
		REMOVE_TRAIT(held, TRAIT_NODROP, REF(src))
		UnregisterSignal(held, COMSIG_ITEM_DROPPED)
	gripped.Cut()
	owner?.balloon_alert(owner, "grips relax")

/// Signal proc for [COMSIG_ITEM_DROPPED] on a clamped item: something with
/// more authority than us moved it — stop tracking.
/obj/item/organ/cyberimp/cyberware/gecko/proc/on_gripped_item_dropped(obj/item/source, mob/user)
	SIGNAL_HANDLER
	REMOVE_TRAIT(source, TRAIT_NODROP, REF(src))
	UnregisterSignal(source, COMSIG_ITEM_DROPPED)
	gripped -= source

/**
 * Signal proc for [COMSIG_MOVABLE_MOVED]: the chasm lip-catch. The passive
 * STOPPER trait is what kept the chasm from swallowing us during Entered;
 * by the time Moved fires we're standing on the lip and can pay for it —
 * shove back to the previous turf, disarm the trait, and re-set later.
 */
/obj/item/organ/cyberimp/cyberware/gecko/proc/on_moved(mob/living/source, atom/old_loc, movement_dir, forced)
	SIGNAL_HANDLER
	if(!catch_ready || (organ_flags & ORGAN_FAILING))
		return
	if(source.throwing) // sailing over a chasm is the throw's business, not ours
		return
	var/turf/here = get_turf(source)
	if(!ischasm(here))
		return
	var/turf/lip = old_loc
	if(!isturf(lip) || ischasm(lip) || get_dist(here, lip) > 1)
		return // thrown/teleported in — the passive trait already did its best
	catch_ready = FALSE
	REMOVE_TRAIT(source, TRAIT_CHASM_STOPPER, REF(src))
	source.forceMove(lip)
	source.balloon_alert(source, "grips catch the lip!")
	playsound(source, 'sound/effects/pickaxe/picaxe2.ogg', 40, TRUE)
	addtimer(CALLBACK(src, PROC_REF(rearm_catch)), CYBERWARE_GECKO_CATCH_COOLDOWN)

/obj/item/organ/cyberimp/cyberware/gecko/proc/rearm_catch()
	catch_ready = TRUE
	if(owner)
		ADD_TRAIT(owner, TRAIT_CHASM_STOPPER, REF(src))
		owner.balloon_alert(owner, "grips re-set")

/// The anti-drop implant's signature tradeoff, kept on purpose: an EMP
/// spasms the pads and everything you hold goes flying.
/obj/item/organ/cyberimp/cyberware/gecko/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF || !owner)
		return
	release_grip()
	var/throw_range = (severity == EMP_HEAVY) ? 5 : 3
	var/list/possible_targets = oview(throw_range, owner)
	if(!length(possible_targets))
		return
	for(var/obj/item/held in owner.held_items)
		if(!owner.dropItemToGround(held))
			continue
		held.throw_at(pick(possible_targets), throw_range, 2)
		to_chat(owner, span_warning("Your hand spasms open and hurls [held]!"))

#undef CYBERWARE_SCRAPPER_PUNCH_BONUS
#undef CYBERWARE_GECKO_CATCH_COOLDOWN
#undef CYBERWARE_GASTRO_DISGUST_PURGE
#undef CYBERWARE_GASTRO_QUALITY_BONUS
#undef CYBERWARE_CAVITY_MAX_WCLASS
