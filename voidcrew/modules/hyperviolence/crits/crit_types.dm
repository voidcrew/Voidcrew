// Hyperviolence aimed crits: the six kinds. Thresholds and minimum damage are explained at the top
// of crit_roll.dm. Hit lines are short and say what happened, nothing about why.

/// Chance per sharp hit that an eye already ruined past tg's high damage threshold is torn out,
/// with no roll and no minimum damage. This is how repeated eye stabs with a knife end.
#define HV_EYE_RUINED_CHANCE 25
/// The skull bursts instead of caving in when the victim is already in crit and the hit is this big.
#define HV_SKULL_BURST_DAMAGE 20
/// Melee armour on the head (after armour penetration) that stops the skull caving in.
#define HV_SKULL_HELMET_ARMOUR 30
/// Melee armour on an armoured collar (after armour penetration) that stops a throat slash.
#define HV_THROAT_COLLAR_ARMOUR 10
/// Chest armour against the hit (after armour penetration) that stops a torn aorta.
#define HV_AORTA_CHEST_ARMOUR 40

// ---------------------------------------------------------------------------------------------
// Eye torn out: a slash or stab aimed at the eyes. Any eye cover (glasses, visor, sealed helmet)
// stops it. Knives and screwdrivers stab eyes through tg's eyestab element for small damage, so
// they never pass the roll; they get the eye through HV_EYE_RUINED_CHANCE once it is ruined.

/datum/hv_crit/eye
	name = "torn-out eye"
	limb_zone = BODY_ZONE_HEAD
	aim_zones = list(BODY_ZONE_PRECISE_EYES)
	wounding_types = list(WOUND_SLASH, WOUND_PIERCE)
	min_damage = 12
	threshold = 80
	wound_type = /datum/wound/pierce/bleed/severe/eye/hv_gouged
	basic_effect = /datum/status_effect/hv_crit_basic/eye
	hit_sound = 'sound/effects/wounds/pierce2.ogg'
	shake = 4

/datum/hv_crit/eye/blocked_on_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, atom/source)
	return !!victim.is_eyes_covered()

/datum/hv_crit/eye/can_apply_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, wounding_type)
	var/obj/item/organ/eyes/eyes = victim.get_organ_slot(ORGAN_SLOT_EYES)
	if(!eyes || eyes.bodypart_owner != limb || (eyes.organ_flags & ORGAN_UNREMOVABLE))
		return FALSE
	if(limb.get_wound_type(/datum/wound/pierce/bleed/severe/eye/hv_gouged))
		return TRUE // the socket wound is already there; this one takes the other eye
	return ..()

/datum/hv_crit/eye/happens_anyway(mob/living/carbon/victim, obj/item/bodypart/limb)
	var/obj/item/organ/eyes/eyes = victim.get_organ_slot(ORGAN_SLOT_EYES)
	return eyes && eyes.damage >= eyes.high_threshold && prob(HV_EYE_RUINED_CHANCE)

/datum/hv_crit/eye/apply_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, damage, attack_direction, atom/source, mob/living/attacker)
	var/obj/item/organ/eyes/eyes = victim.get_organ_slot(ORGAN_SLOT_EYES)
	if(!eyes)
		return FALSE
	var/list/open_sides = list()
	if(!(eyes.scarring & RIGHT_EYE_SCAR))
		open_sides += RIGHT_EYE_SCAR
	if(!(eyes.scarring & LEFT_EYE_SCAR))
		open_sides += LEFT_EYE_SCAR
	var/side = length(open_sides) ? pick(open_sides) : RIGHT_EYE_SCAR
	var/last_eye = length(open_sides) <= 1

	var/datum/wound/pierce/bleed/severe/eye/hv_gouged/socket = limb.get_wound_type(/datum/wound/pierce/bleed/severe/eye/hv_gouged)
	if(socket)
		if(last_eye)
			socket.lose_other_eye()
		else // a fresh pair of eyes went in since the last one
			socket.set_blood_flow(max(socket.blood_flow, socket.initial_flow))
	else
		socket = new
		if(!socket.apply_wound(limb, silent = TRUE, attack_direction = attack_direction, wound_source = source, right_side = (side == RIGHT_EYE_SCAR)))
			return FALSE
		if(last_eye)
			socket.lose_other_eye()

	// tg's eye scarring does the seeing: one scarred eye is nearsighted, two are blind.
	if(length(open_sides))
		eyes.apply_scar(side)
	victim.adjust_eye_blur(20 SECONDS)
	victim.add_mood_event("eye_stab", /datum/mood_event/eye_stab)

	var/line
	if(last_eye)
		// Nothing left to see with: the whole organ comes out.
		eyes.Remove(victim)
		var/turf/drop_turf = victim.drop_location()
		eyes.forceMove(drop_turf)
		var/turf/landing = get_step(drop_turf, attack_direction)
		if(landing && !landing.is_blocked_turf())
			eyes.throw_at(landing, 1, 1)
		line = length(open_sides) ? "[victim]'s [side == RIGHT_EYE_SCAR ? "right" : "left"] eye is torn out!" : "[victim]'s eyes are torn out!"
	else
		line = "[victim]'s [side == RIGHT_EYE_SCAR ? "right" : "left"] eye is torn out!"
	victim.hv_blood_spray(attack_direction, 2)
	announce(victim, attack_direction, line)
	return TRUE

/datum/hv_crit/eye/hit_line(mob/living/victim)
	return "[victim]'s [pick("left", "right")] eye is torn out!"

// ---------------------------------------------------------------------------------------------
// Tongue cut off: a slash aimed at the mouth. A mask or helmet over the mouth stops it.

/datum/hv_crit/tongue
	name = "severed tongue"
	limb_zone = BODY_ZONE_HEAD
	aim_zones = list(BODY_ZONE_PRECISE_MOUTH)
	wounding_types = list(WOUND_SLASH)
	min_damage = 12
	threshold = 80
	wound_type = /datum/wound/slash/flesh/moderate/hv_tongue
	basic_effect = /datum/status_effect/hv_crit_basic/tongue
	hit_sound = 'sound/effects/wounds/blood2.ogg'

/datum/hv_crit/tongue/blocked_on_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, atom/source)
	return !!victim.is_mouth_covered()

/datum/hv_crit/tongue/can_apply_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, wounding_type)
	var/obj/item/organ/tongue/tongue = victim.get_organ_slot(ORGAN_SLOT_TONGUE)
	if(!tongue || tongue.bodypart_owner != limb || (tongue.organ_flags & ORGAN_UNREMOVABLE))
		return FALSE
	return ..()

/datum/hv_crit/tongue/apply_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, damage, attack_direction, atom/source, mob/living/attacker)
	var/obj/item/organ/tongue/tongue = victim.get_organ_slot(ORGAN_SLOT_TONGUE)
	if(!tongue || !hv_crit_apply_wound(limb, wound_type, attack_direction, source))
		return FALSE
	tongue.Remove(victim)
	var/turf/drop_turf = victim.drop_location()
	tongue.forceMove(drop_turf)
	var/turf/landing = get_step(drop_turf, attack_direction)
	if(landing && !landing.is_blocked_turf())
		tongue.throw_at(landing, 1, 1)
	victim.hv_blood_spray(attack_direction, 1)
	announce(victim, attack_direction)
	return TRUE

/datum/hv_crit/tongue/hit_line(mob/living/victim)
	return "[victim]'s tongue is cut off!"

// ---------------------------------------------------------------------------------------------
// Throat slit: a slash aimed at the head. A sealed helmet or an armoured collar stops it.

/datum/hv_crit/throat
	name = "slit throat"
	limb_zone = BODY_ZONE_HEAD
	aim_zones = list(BODY_ZONE_HEAD)
	wounding_types = list(WOUND_SLASH)
	min_damage = 18
	threshold = 90
	wound_type = /datum/wound/slash/flesh/critical/hv_carotid
	basic_effect = /datum/status_effect/hv_crit_basic/bleed/throat
	line_severity = HV_LINE_HUGE
	hit_sound = 'sound/effects/wounds/blood3.ogg'
	shake = 5

/datum/hv_crit/throat/blocked_on_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, atom/source)
	if(victim.is_mouth_covered(ITEM_SLOT_HEAD))
		return TRUE
	if(!ishuman(victim))
		return FALSE
	var/mob/living/carbon/human/human_victim = victim
	var/obj/item/clothing/collar = human_victim.wear_neck
	if(!istype(collar))
		return FALSE
	return collar.get_armor_rating(MELEE) - hv_crit_armour_pen(source) >= HV_THROAT_COLLAR_ARMOUR

/datum/hv_crit/throat/apply_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, damage, attack_direction, atom/source, mob/living/attacker)
	if(!hv_crit_apply_wound(limb, wound_type, attack_direction, source))
		return FALSE
	victim.hv_blood_spray(attack_direction, 3)
	announce(victim, attack_direction)
	return TRUE

/datum/hv_crit/throat/hit_line(mob/living/victim)
	return "[victim]'s throat is slit open!"

// ---------------------------------------------------------------------------------------------
// Aorta torn: a huge stab, slash or shot aimed at the chest. Heavy chest armour against that kind
// of hit stops it; ordinary vests only make it rarer through their wound armour.

/datum/hv_crit/aorta
	name = "torn aorta"
	limb_zone = BODY_ZONE_CHEST
	aim_zones = list(BODY_ZONE_CHEST)
	wounding_types = list(WOUND_SLASH, WOUND_PIERCE)
	min_damage = 25
	threshold = 90
	allow_projectiles = TRUE
	wound_type = /datum/wound/pierce/bleed/critical/hv_aorta
	basic_effect = /datum/status_effect/hv_crit_basic/bleed/aorta
	hit_sound = 'sound/effects/wounds/pierce3.ogg'
	shake = 4

/datum/hv_crit/aorta/blocked_on_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, atom/source)
	return hv_crit_cover_rating(victim, limb, hv_crit_attack_flag(source), hv_crit_armour_pen(source)) >= HV_AORTA_CHEST_ARMOUR

/datum/hv_crit/aorta/apply_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, damage, attack_direction, atom/source, mob/living/attacker)
	if(!hv_crit_apply_wound(limb, wound_type, attack_direction, source))
		return FALSE
	victim.hv_blood_spray(attack_direction, 2)
	announce(victim, attack_direction)
	return TRUE

/datum/hv_crit/aorta/hit_line(mob/living/victim)
	return "[victim]'s aorta is torn open!"

// ---------------------------------------------------------------------------------------------
// Skull caved in: a heavy blunt blow aimed at the head. A real helmet, or anything that blocks
// head injuries (hard hats, riot helmets), stops it. If the victim is already in crit the head
// bursts instead (hv_burst_head(), owned by the brain-and-guts part).

/datum/hv_crit/skull
	name = "caved-in skull"
	limb_zone = BODY_ZONE_HEAD
	aim_zones = list(BODY_ZONE_HEAD)
	wounding_types = list(WOUND_BLUNT)
	min_damage = 20
	threshold = 95
	allow_dead = TRUE
	wound_type = /datum/wound/blunt/bone/critical/hv_skull
	basic_effect = /datum/status_effect/hv_crit_basic/skull
	line_severity = HV_LINE_HUGE
	hit_sound = 'sound/effects/wounds/crack2.ogg'
	shake = 8

/datum/hv_crit/skull/blocked_on_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, atom/source)
	if(HAS_TRAIT(victim, TRAIT_HEAD_INJURY_BLOCKED))
		return TRUE
	return hv_crit_cover_rating(victim, limb, MELEE, hv_crit_armour_pen(source)) >= HV_SKULL_HELMET_ARMOUR

/datum/hv_crit/skull/can_apply_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, wounding_type)
	if(victim.stat >= SOFT_CRIT && limb.can_dismember())
		return TRUE // the head can still burst even if the skull is already broken
	if(victim.stat == DEAD)
		return FALSE
	return ..()

/datum/hv_crit/skull/apply_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, damage, attack_direction, atom/source, mob/living/attacker)
	if(victim.stat >= SOFT_CRIT && damage >= HV_SKULL_BURST_DAMAGE && victim.hv_burst_head(attack_direction))
		playsound(get_turf(victim), hit_sound, 80, TRUE, falloff_exponent = SOUND_FALLOFF_EXPONENT + 2, ignore_walls = FALSE, falloff_distance = 0)
		return TRUE
	if(victim.stat == DEAD || !hv_crit_apply_wound(limb, wound_type, attack_direction, source))
		return FALSE
	announce(victim, attack_direction)
	return TRUE

/datum/hv_crit/skull/hit_line(mob/living/victim)
	return "[victim]'s skull caves in!"

// ---------------------------------------------------------------------------------------------
// Jaw shattered: a blunt blow aimed at the mouth. A helmet that covers the mouth stops it.

/datum/hv_crit/jaw
	name = "shattered jaw"
	limb_zone = BODY_ZONE_HEAD
	aim_zones = list(BODY_ZONE_PRECISE_MOUTH)
	wounding_types = list(WOUND_BLUNT)
	min_damage = 12
	threshold = 75
	wound_type = /datum/wound/blunt/bone/severe/hv_jaw
	basic_effect = /datum/status_effect/hv_crit_basic/jaw
	hit_sound = 'sound/effects/wounds/crack1.ogg'
	shake = 3

/datum/hv_crit/jaw/blocked_on_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, atom/source)
	return !!victim.is_mouth_covered(ITEM_SLOT_HEAD)

/datum/hv_crit/jaw/apply_carbon(mob/living/carbon/victim, obj/item/bodypart/limb, damage, attack_direction, atom/source, mob/living/attacker)
	if(!hv_crit_apply_wound(limb, wound_type, attack_direction, source))
		return FALSE
	victim.add_splatter_floor(get_turf(victim), small_drip = TRUE)
	announce(victim, attack_direction)
	return TRUE

/datum/hv_crit/jaw/hit_line(mob/living/victim)
	return "[victim]'s jaw shatters!"

#undef HV_EYE_RUINED_CHANCE
#undef HV_SKULL_BURST_DAMAGE
#undef HV_SKULL_HELMET_ARMOUR
#undef HV_THROAT_COLLAR_ARMOUR
#undef HV_AORTA_CHEST_ARMOUR
