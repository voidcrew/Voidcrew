/**
 * Mech balance reverts.
 *
 * - Restores the Paddy's pre-nerf movement speed (upstream #91463).
 * - Restores MMI/posibrain/AI piloting to open-cage mechs (upstream #91118),
 *   while keeping an inherent downside: penetrating hits have a low chance of
 *   hurting the silicon pilot's brain housing / uplink.
 * - Restores the bluespace anomaly core as the Phazon's power source
 *   (upstream #83939).
 */

/// Chance that a head/chest hit to an open-cage mech hurts its silicon pilot.
#define VOIDCREW_OPEN_CAGE_NEURAL_HIT_CHANCE 15
/// Brain organ damage dealt to an MMI pilot.
#define VOIDCREW_MMI_BRAIN_DAMAGE_ON_HIT 15
/// Integrity damage dealt to a positronic brain pilot.
#define VOIDCREW_POSIBRAIN_INTEGRITY_DAMAGE_ON_HIT 10
/// Integrity/brute damage dealt to an AI pilot's uplink.
#define VOIDCREW_AI_UPLINK_DAMAGE_ON_HIT 20

// Paddy speed revert (#91463): the paddy inherits the base Ripley's speed again.
/obj/vehicle/sealed/mecha/ripley/paddy
	movedelay = 1.5
	slow_pressure_step_in = 2
	fast_pressure_step_in = 1.5

// Open-cage silicon control revert (#91118).
// The Ripley MK-I keeps its open cabin (no IS_ENCLOSED), so fleshy pilots
// remain vulnerable to overpenetration, but silicon pilots are allowed once more.
/obj/vehicle/sealed/mecha/ripley
	mecha_flags = CAN_STRAFE | HAS_LIGHTS | MMI_COMPATIBLE | AI_COMPATIBLE | BEACON_TRACKABLE | BEACON_CONTROLLABLE

/obj/vehicle/sealed/mecha/ripley/paddy/preset
	mecha_flags = CAN_STRAFE | HAS_LIGHTS | MMI_COMPATIBLE | AI_COMPATIBLE | BEACON_TRACKABLE | BEACON_CONTROLLABLE | ID_LOCK_ON

/// Deals damage to an open-cage mech's silicon pilot based on their brain housing.
/obj/vehicle/sealed/mecha/proc/voidcrew_damage_silicon_pilot()
	if(!LAZYLEN(occupants))
		return
	var/mob/living/pilot = pick(occupants)
	if(isbrain(pilot))
		var/mob/living/brain/brain_pilot = pilot
		var/obj/item/mmi/housing = brain_pilot.container
		if(!istype(housing))
			return
		if(istype(housing, /obj/item/mmi/posibrain))
			housing.take_damage(VOIDCREW_POSIBRAIN_INTEGRITY_DAMAGE_ON_HIT, BRUTE, MELEE)
			to_chat(pilot, span_userdanger("A hit rattles your positronic chassis!"))
		else if(housing.brain)
			var/obj/item/organ/brain/brain_organ = housing.brain
			if(brain_organ.owner)
				brain_organ.apply_organ_damage(VOIDCREW_MMI_BRAIN_DAMAGE_ON_HIT)
			else // Brains in an MMI have no owner; skip trauma/threshold bookkeeping.
				brain_organ.damage = clamp(brain_organ.damage + VOIDCREW_MMI_BRAIN_DAMAGE_ON_HIT, 0, brain_organ.maxHealth)
				if(brain_organ.damage >= brain_organ.maxHealth)
					brain_organ.organ_flags |= ORGAN_FAILING
				brain_organ.prev_damage = brain_organ.damage
			to_chat(pilot, span_userdanger("Your brain rattles around in the MMI!"))
	else if(isAI(pilot))
		var/mob/living/silicon/ai/ai_pilot = pilot
		if(ai_pilot.linked_core)
			ai_pilot.linked_core.take_damage(VOIDCREW_AI_UPLINK_DAMAGE_ON_HIT, BRUTE, MELEE)
		else
			ai_pilot.adjustBruteLoss(VOIDCREW_AI_UPLINK_DAMAGE_ON_HIT)
		to_chat(pilot, span_userdanger("A hit jolts your uplink connection to the exosuit!"))

/obj/vehicle/sealed/mecha/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit)
	. = ..()
	if(QDELETED(src) || (mecha_flags & IS_ENCLOSED) || !(mecha_flags & SILICON_PILOT))
		return
	if(def_zone != BODY_ZONE_HEAD && def_zone != BODY_ZONE_CHEST)
		return
	if(!prob(VOIDCREW_OPEN_CAGE_NEURAL_HIT_CHANCE))
		return
	voidcrew_damage_silicon_pilot()

/obj/vehicle/sealed/mecha/attackby(obj/item/weapon, mob/living/user, list/modifiers, list/attack_modifiers)
	var/armour_penetration_chance = 0
	if((mecha_flags & SILICON_PILOT) && !(mecha_flags & IS_ENCLOSED))
		armour_penetration_chance = clamp(weapon.armour_penetration - (get_armor_rating(MELEE)/2), 0, 100)
	. = ..()
	if(QDELETED(src) || (mecha_flags & IS_ENCLOSED) || !(mecha_flags & SILICON_PILOT) || !armour_penetration_chance)
		return
	if(!prob(armour_penetration_chance))
		return
	voidcrew_damage_silicon_pilot()

// Phazon bluespace core revert (#83939).
/obj/vehicle/sealed/mecha/phazon
	desc = "This is a Phazon exosuit. The pinnacle of scientific research and pride of Nanotrasen, it uses cutting edge bluespace technology and expensive materials."

/obj/item/mecha_parts/chassis/phazon/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/assembly/signaler/anomaly) && !istype(tool, /obj/item/assembly/signaler/anomaly/bluespace))
		to_chat(user, "The anomaly core socket only accepts bluespace anomaly cores!")
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/item/mecha_parts/part/phazon_torso
	desc = "A Phazon torso part. The socket for the bluespace core that powers the exosuit's unique phase drives is located in the middle."

/datum/component/construction/mecha/phazon/get_outer_plating_steps()
	return list(
		list(
			"key" = outer_plating,
			"amount" = 1,
			"action" = ITEM_DELETE,
			"back_key" = TOOL_WELDER,
			"desc" = "Internal armor is welded, [initial(outer_plating.name)] can be used as external armor.",
			"forward_message" = "added external armor layer",
			"backward_message" = "cut off internal armor layer"
		),
		list(
			"key" = TOOL_WRENCH,
			"back_key" = TOOL_CROWBAR,
			"desc" = "External armor is installed, and can be <b>wrenched</b> into place.",
			"forward_message" = "secured external armor layer",
			"backward_message" = "pried off external armor"
		),
		list(
			"key" = TOOL_WELDER,
			"back_key" = TOOL_WRENCH,
			"desc" = "External armor is wrenched, and can be <b>welded</b>.",
			"forward_message" = "welded external armor",
			"backward_message" = "unfastened external armor layer"
		),
		list(
			"key" = /obj/item/assembly/signaler/anomaly/bluespace,
			"action" = ITEM_DELETE,
			"back_key" = TOOL_WELDER,
			"desc" = "The external armor is welded, and the <b>bluespace anomaly core</b> socket is open.",
			"icon_state" = "phazon26",
			"forward_message" = "inserted bluespace anomaly core",
			"backward_message" = "cut off external armor"
		)
	)

/datum/bounty/item/science/ref_anomaly
	description = "Our roboticist wont shut up about making a phazon, please ship us a bluespace anomaly core."
