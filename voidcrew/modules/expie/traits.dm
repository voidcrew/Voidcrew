// What being an Experiment is like, beyond the look: yellow-orange blood, claws and teeth that
// cut, and a body that tears more easily than it should.

/datum/blood_type/experiment
	name = BLOOD_TYPE_EXPERIMENT
	desc = "Thin yellow-orange blood. Nothing else on the chart matches it."
	dna_string = "Experiment DNA"
	color = BLOOD_COLOR_EXPERIMENT

/// How much more easily an Experiment's limbs take wounds than a human's.
#define EXPIE_WOUND_WEAKNESS 10

/// Bites instead of swinging when its hands are no use, or it has someone held tight.
/obj/item/organ/brain/experiment

/obj/item/organ/brain/experiment/get_attacking_limb(mob/living/carbon/human/target)
	var/obj/item/bodypart/head/jaws = owner.get_bodypart(BODY_ZONE_HEAD)
	if(jaws && (owner.handcuffed || !owner.usable_hands || (target.pulledby == owner && owner.grab_state >= GRAB_AGGRESSIVE)))
		return jaws
	return ..()

/obj/item/bodypart/head/experiment
	wound_resistance = 5 - EXPIE_WOUND_WEAKNESS
	unarmed_attack_verbs = list("bite", "chomp", "gnaw")
	unarmed_attack_verbs_continuous = list("bites", "chomps", "gnaws")
	unarmed_attack_effect = ATTACK_EFFECT_BITE
	unarmed_attack_sound = 'sound/items/weapons/bite.ogg'
	unarmed_miss_sound = 'sound/items/weapons/bite.ogg'
	unarmed_damage_low = 4
	unarmed_damage_high = 9
	unarmed_sharpness = SHARP_POINTY

/obj/item/bodypart/chest/experiment
	wound_resistance = -EXPIE_WOUND_WEAKNESS

/obj/item/bodypart/arm/left/experiment
	wound_resistance = -EXPIE_WOUND_WEAKNESS
	unarmed_attack_verbs = list("slash", "scratch", "claw")
	unarmed_attack_verbs_continuous = list("slashes", "scratches", "claws")
	grappled_attack_verb = "lacerate"
	grappled_attack_verb_continuous = "lacerates"
	unarmed_attack_effect = ATTACK_EFFECT_CLAW
	unarmed_attack_sound = 'sound/items/weapons/slash.ogg'
	unarmed_miss_sound = 'sound/items/weapons/slashmiss.ogg'
	unarmed_sharpness = SHARP_EDGED

/obj/item/bodypart/arm/right/experiment
	wound_resistance = -EXPIE_WOUND_WEAKNESS
	unarmed_attack_verbs = list("slash", "scratch", "claw")
	unarmed_attack_verbs_continuous = list("slashes", "scratches", "claws")
	grappled_attack_verb = "lacerate"
	grappled_attack_verb_continuous = "lacerates"
	unarmed_attack_effect = ATTACK_EFFECT_CLAW
	unarmed_attack_sound = 'sound/items/weapons/slash.ogg'
	unarmed_miss_sound = 'sound/items/weapons/slashmiss.ogg'
	unarmed_sharpness = SHARP_EDGED

/obj/item/bodypart/leg/left/experiment
	wound_resistance = -EXPIE_WOUND_WEAKNESS

/obj/item/bodypart/leg/right/experiment
	wound_resistance = -EXPIE_WOUND_WEAKNESS

#undef EXPIE_WOUND_WEAKNESS
