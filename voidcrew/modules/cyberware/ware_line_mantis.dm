/**
 * # Mantis Blades line: the Shiv and Scorch models
 *
 * Two more ways to buy the same forearm blades (ware_military_arms.dm):
 * - Shiv Blades, the street model. A duller blade, no lunge, light on the
 *   nervous system, sold for credits in the yellow zone and bought back.
 * - Scorch Blades, the fire model. Mantis in every number, but every cut
 *   sets the target alight and the lunge lights them harder.
 *
 * Both are subtypes of the Mantis housing, so they share its arm hardware slot:
 * installing one evicts the other. Both ship as cased pairs (left and right),
 * like the parent. The tuning rides vars on the housing (lunge_range,
 * lunge_bonus, lunge_fire_stacks and friends), so a model retunes by setting
 * them, not by copying the lunge.
 */

// ---- Fire --------------------------------------------------------------

/**
 * Puts fire stacks on a living target and lights them. The only fire this
 * line makes. It never touches the attacker and never lights a turf: any
 * heat the surroundings get is what a burning mob already gives off. Corpses
 * are left alone, so a body is never cooked out from under a revive or a salvage.
 * Returns TRUE if the target caught fire just now.
 */
/proc/cyberware_scorch_target(mob/living/victim, stacks)
	if(!istype(victim) || QDELETED(victim) || victim.stat == DEAD || stacks <= 0)
		return FALSE
	victim.adjust_fire_stacks(stacks)
	return victim.ignite_mob()

// ---- Blades --------------------------------------------------------------

/**
 * The Shiv's blade. The same hardlight on a worse emitter: dull grey, and it
 * hits softer.
 */
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/street
	name = "shiv blade"
	desc = "A dull grey sliver of hardlight with no shine to it. It still cuts."
	icon_state = "mantis_street"
	base_icon_state = "mantis_street"
	inhand_icon_state = "mantis_street"
	force = 14

/**
 * The Scorch's blade. Cuts like a Mantis, then lights what it cut. The edge runs
 * orange and the blade throws a little firelight while it is out.
 */
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/scorch
	name = "scorch blade"
	desc = "A forearm's length of hardlight gone orange along the edge. The air above it shimmers."
	icon_state = "mantis_scorch"
	base_icon_state = "mantis_scorch"
	inhand_icon_state = "mantis_scorch"
	light_range = 2
	light_power = 1
	light_color = LIGHT_COLOR_FIRE
	/// Fire stacks each landed cut puts on its target.
	var/fire_stacks_per_hit = 2
	/// Set by afterattack() during attack()'s parent call, which only a swing that
	/// connected reaches. attack()'s own FALSE can't tell a cut from a pacifist's
	/// pulled swing or a signal-skipped one. The Widowline does the same.
	var/swing_landed = FALSE

// The glow is only for a blade that is out. Stowed inside the housing it is dark.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/scorch/equipped(mob/user, slot, initial = FALSE)
	. = ..()
	set_light_on(TRUE)

/obj/item/melee/energy/blade/hardlight/cyberware_mantis/scorch/dropped(mob/user, silent = FALSE)
	. = ..()
	set_light_on(FALSE)

/obj/item/melee/energy/blade/hardlight/cyberware_mantis/scorch/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	swing_landed = FALSE
	. = ..()
	var/landed = swing_landed
	swing_landed = FALSE
	// Only a cut that landed burns: not a blocked or cancelled swing, not a pulled
	// one. Never the wielder, whoever is in the way.
	if(. || !landed || QDELETED(target) || target == user)
		return
	// Embers off the cut; the blade's impact is the slash (cyberware_anim2.dm).
	cyberware_scorch_trail_fx(user, target)
	if(cyberware_scorch_target(target, fire_stacks_per_hit))
		log_combat(user, target, "set alight", src, "(scorch blade)")

/obj/item/melee/energy/blade/hardlight/cyberware_mantis/scorch/afterattack(atom/target, mob/user, list/modifiers, list/attack_modifiers)
	. = ..()
	swing_landed = TRUE

// ---- Shiv Blades (street) ------------------------------------------------

/**
 * # Shiv Blades (T2, arms, arm hardware slots, load 2 per arm / 4 the pair)
 *
 * The street answer to Mantis Blades: the same hardlight forearm housing built
 * from salvage. The blade is weaker and there is no lunge, so no button besides
 * the blade toggle. Cheap in credits and light on the nervous system, and Splice
 * takes a pulled housing back toward the real thing.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/street
	name = "\improper Shiv Blade housing (right)"
	desc = "A forearm housing with the serial plate filed off and an emitter wired in by someone who skipped the manual."
	icon_state = "mantis_street"
	chrome_load = 2
	tier = CYBERWARE_TIER_2
	aug_overlay = "mantis_street"
	items_to_create = list(/obj/item/melee/energy/blade/hardlight/cyberware_mantis/street)
	actions_types = list(/datum/action/item_action/organ_action/toggle/toolkit)

/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/street/left
	name = "\improper Shiv Blade housing (left)"
	zone = BODY_ZONE_L_ARM
	slot = ORGAN_SLOT_LEFT_ARM_AUG

/obj/item/cyberware_pair_case/mantis_street
	name = "\improper Shiv Blades case"
	desc = "A scuffed clamshell case with two forearm housings jammed into mismatched foam."
	ware_types = list(
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/street,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/street/left,
	)

// ---- Scorch Blades (fire) ------------------------------------------------

/**
 * # Scorch Blades (T3, arms, arm hardware slots, load 4 per arm / 8 the pair)
 *
 * Mantis Blades with a heat sink grafted onto the emitter rail. The blade, the
 * lunge and the cooldown are the Mantis numbers. What is added is fire: each cut
 * leaves the target burning, and the lunge lights them harder. It heats the
 * wrist, but never sets the wearer alight.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/scorch
	name = "\improper Scorch Blade housing (right)"
	desc = "A forearm housing with a heat sink grafted onto the emitter rail. The wrist runs warm even with nothing out."
	icon_state = "mantis_scorch"
	chrome_load = 4
	tier = CYBERWARE_TIER_3
	aug_overlay = "mantis_scorch"
	items_to_create = list(/obj/item/melee/energy/blade/hardlight/cyberware_mantis/scorch)
	lunge_fire_stacks = 4

/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/scorch/left
	name = "\improper Scorch Blade housing (left)"
	zone = BODY_ZONE_L_ARM
	slot = ORGAN_SLOT_LEFT_ARM_AUG

/obj/item/cyberware_pair_case/mantis_scorch
	name = "\improper Scorch Blades case"
	desc = "A heavy clamshell case, scorched at the corners, with two forearm housings set in heat-proof foam."
	ware_types = list(
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/scorch,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/scorch/left,
	)

// ---- The parlor's shelf --------------------------------------------------

/datum/shop_sku/ripperdoc/mantis_street
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Street Chrome"
	name = "Shiv Blades (pair)"
	desc = "A cased pair of cheap forearm blades."
	item_path = /obj/item/cyberware_pair_case/mantis_street
	price_credits = 2400
	stock_min = 1
	stock_max = 2
	fixed_price = TRUE
	contract_reward = FALSE

/datum/shop_sku/ripperdoc/mantis_scorch
	zone_permission = ZONE_PERMISSION_ELITE
	category = "Military Chrome"
	name = "Scorch Blades (pair)"
	desc = "A cased pair of forearm blades with heat sinks on the emitter rails."
	item_path = /obj/item/cyberware_pair_case/mantis_scorch
	price_vouchers = 4
	stock_min = 1
	stock_max = 1
	convoys_per_unit = 3
	fixed_price = TRUE
	contract_reward = FALSE

/// Half the credit price of one housing, either side, as the other street rungs
/// pay. Credits only, so turning a pair around is always a loss.
/datum/shop_buyback/ripperdoc/mantis_street
	name = "Shiv Blade housing (pulled)"
	desc = "A secondhand forearm housing, either side."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/street
	match_subtypes = TRUE
	pay_credits = 600
	demand_min = 2
	demand_max = 4
