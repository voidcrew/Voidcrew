// Plasma burn care: picking slag out in the field, the slag surgery and the slag bead.
// The wound itself (slag, heat, stored healing, remove_slag(), quench()) lives in plasma_wounds.dm.

/// Tools that can pick slag out of a plasma burn in the field
#define PLASMA_PICK_TOOLS list(TOOL_HEMOSTAT, TOOL_WIRECUTTER, TOOL_SCALPEL)

/// Picking tools are only claimed while there is slag to pick, so a cleaned burn leaves them alone.
/datum/wound/burn/flesh/plasma/item_can_treat(obj/item/potential_treater, mob/user)
	if(slag > 0 && (potential_treater.tool_behaviour in PLASMA_PICK_TOOLS))
		return TRUE
	return ..()

/datum/wound/burn/flesh/plasma/treat(obj/item/I, mob/user)
	if(slag > 0 && (I.tool_behaviour in PLASMA_PICK_TOOLS))
		return pick_slag(I, user)
	return ..()

/// Picks slag out of a plasma burn with a tool, one bead at a time, until it is all out or the medic stops.
/datum/wound/burn/flesh/plasma/proc/pick_slag(obj/item/tool, mob/user)
	var/improvised = tool.tool_behaviour != TOOL_HEMOSTAT
	var/delay = PLASMA_WOUND_PICK_TIME
	if(user == victim)
		delay *= 1.5
	if(improvised)
		delay *= PLASMA_WOUND_IMPROVISED_TIME
	if(HAS_TRAIT(src, TRAIT_WOUND_SCANNED))
		delay *= 0.5
	var/brute = improvised ? PLASMA_WOUND_PICK_BRUTE_IMPROVISED : PLASMA_WOUND_PICK_BRUTE

	var/mob/living/carbon/patient = victim
	var/obj/item/bodypart/part = limb
	var/whose = user == patient ? "[patient.p_their()]" : "[patient]'s"
	var/your_whose = user == patient ? "your" : "[patient]'s"
	user.visible_message(
		span_notice("[user] begins picking slag out of [whose] [part.plaintext_zone] with [tool]..."),
		span_notice("You begin picking slag out of [your_whose] [part.plaintext_zone] with [tool]..."),
	)

	while(slag > 0)
		if(!do_after(user, delay, target = patient, extra_checks = CALLBACK(src, PROC_REF(still_exists))))
			break
		// The wound may have changed under the tool: healed, upgraded away or emptied by someone else
		if(QDELETED(src) || victim != patient || limb != part || slag <= 0)
			break
		var/was_hot = heat > 0
		remove_slag(PLASMA_WOUND_PICK_SLAG, user)
		if(PLASMA_SOUND_SLAG_PICK)
			playsound(patient, PLASMA_SOUND_SLAG_PICK, 40, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)
		patient.apply_damage(brute, BRUTE, part, wound_bonus = CANT_WOUND, attacking_item = tool)
		if(was_hot)
			patient.emote("scream")
		if(QDELETED(src) || slag <= 0)
			user.visible_message(
				span_notice("[user] pulls the last of the slag from [whose] [part.plaintext_zone]."),
				span_notice("You pull the last of the slag from [your_whose] [part.plaintext_zone]."),
			)
			break
		user.visible_message(
			span_notice("[user] pulls a bead of slag from [whose] [part.plaintext_zone]."),
			span_notice("You pull a bead of slag from [your_whose] [part.plaintext_zone]."),
		)
	return TRUE

#undef PLASMA_PICK_TOOLS

///// Excise plasma slag
/datum/surgery/excise_slag
	name = "Excise plasma slag"
	surgery_flags = SURGERY_REQUIRE_RESTING | SURGERY_REQUIRE_LIMB | SURGERY_REQUIRES_REAL_LIMB
	targetable_wound = /datum/wound/burn/flesh/plasma
	possible_locs = list(
		BODY_ZONE_R_ARM,
		BODY_ZONE_L_ARM,
		BODY_ZONE_R_LEG,
		BODY_ZONE_L_LEG,
		BODY_ZONE_CHEST,
		BODY_ZONE_HEAD,
	)
	steps = list(
		/datum/surgery_step/excise_slag,
		/datum/surgery_step/dress,
	)

/datum/surgery/excise_slag/can_start(mob/living/user, mob/living/carbon/target)
	. = ..()
	if(!.)
		return .
	var/obj/item/bodypart/part = target.get_bodypart(user.zone_selected)
	var/datum/wound/burn/flesh/plasma/plasma_burn = part?.get_wound_type(targetable_wound)
	return plasma_burn?.slag > 0

/datum/surgery_step/excise_slag
	name = "excise slag (hemostat)"
	implements = list(
		TOOL_HEMOSTAT = 100,
		TOOL_SCALPEL = 85,
		TOOL_SAW = 60,
		TOOL_WIRECUTTER = 40)
	time = 2 SECONDS
	repeatable = TRUE
	preop_sound = 'sound/items/handling/surgery/scalpel1.ogg'
	success_sound = 'sound/items/handling/surgery/retractor2.ogg'
	failure_sound = 'sound/items/handling/surgery/organ1.ogg'
	surgery_effects_mood = TRUE

/// The wound this step works on, while it is still a plasma burn on the operated limb
/datum/surgery_step/excise_slag/proc/get_plasma_burn(datum/surgery/surgery)
	var/datum/wound/burn/flesh/plasma/plasma_burn = surgery.operated_wound
	if(!istype(plasma_burn) || QDELETED(plasma_burn) || plasma_burn.limb != surgery.operated_bodypart)
		return null
	return plasma_burn

/datum/surgery_step/excise_slag/preop(mob/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery)
	var/datum/wound/burn/flesh/plasma/plasma_burn = get_plasma_burn(surgery)
	if(!plasma_burn)
		user.visible_message(span_notice("[user] looks for [target]'s [target.parse_zone_with_bodypart(user.zone_selected)]."), span_notice("You look for [target]'s [target.parse_zone_with_bodypart(user.zone_selected)]..."))
		return SURGERY_STEP_FAIL
	if(plasma_burn.slag <= 0)
		// Someone got it all out already: go straight on to the dressing
		to_chat(user, span_notice("[target]'s [target.parse_zone_with_bodypart(user.zone_selected)] has no slag left to remove!"))
		surgery.status++
		repeatable = FALSE
		return SURGERY_STEP_FAIL
	display_results(
		user,
		target,
		span_notice("You begin to excise slag from [target]'s [target.parse_zone_with_bodypart(user.zone_selected)]..."),
		span_notice("[user] begins to excise slag from [target]'s [target.parse_zone_with_bodypart(user.zone_selected)] with [tool]."),
		span_notice("[user] begins to excise slag from [target]'s [target.parse_zone_with_bodypart(user.zone_selected)]."),
	)
	display_pain(target, "The slag in your [target.parse_zone_with_bodypart(user.zone_selected)] stings like hell! It feels like you're being stabbed!")

/datum/surgery_step/excise_slag/success(mob/living/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery, default_display_results = FALSE)
	var/datum/wound/burn/flesh/plasma/plasma_burn = get_plasma_burn(surgery)
	if(plasma_burn)
		plasma_burn.remove_slag(PLASMA_WOUND_SURGERY_SLAG, user)
		var/done = QDELETED(plasma_burn) || plasma_burn.slag <= 0
		var/how_much = done ? "the last of the" : "some of the"
		display_results(
			user,
			target,
			span_notice("You successfully excise [how_much] slag from [target]'s [target.parse_zone_with_bodypart(target_zone)]."),
			span_notice("[user] successfully excises [how_much] slag from [target]'s [target.parse_zone_with_bodypart(target_zone)] with [tool]!"),
			span_notice("[user] successfully excises [how_much] slag from [target]'s [target.parse_zone_with_bodypart(target_zone)]!"),
		)
		log_combat(user, target, "excised plasma slag in", addition = "COMBAT MODE: [uppertext(user.combat_mode)]")
		if(done)
			repeatable = FALSE
	else
		to_chat(user, span_warning("[target] has no slag there!"))
		repeatable = FALSE
	return ..()

/datum/surgery_step/excise_slag/failure(mob/user, mob/living/target, target_zone, obj/item/tool, datum/surgery/surgery, fail_prob = 0)
	..()
	display_results(
		user,
		target,
		span_notice("You carve away some of the healthy flesh from [target]'s [target.parse_zone_with_bodypart(target_zone)]."),
		span_notice("[user] carves away some of the healthy flesh from [target]'s [target.parse_zone_with_bodypart(target_zone)] with [tool]!"),
		span_notice("[user] carves away some of the healthy flesh from [target]'s [target.parse_zone_with_bodypart(target_zone)]!"),
	)
	target.apply_damage(rand(4, 8), BRUTE, surgery.operated_bodypart, sharpness = SHARP_EDGED, attacking_item = tool)

/datum/surgery_step/excise_slag/initiate(mob/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery, try_to_fail = FALSE)
	if(!..())
		return
	while(get_plasma_burn(surgery)?.slag > 0)
		if(!..())
			break

/// What comes out of a plasma burn. Worth nothing: no materials, no reagents, no export.
/obj/item/plasma_slag
	name = "plasma slag"
	desc = "A bead of black glass with a purple heart. It came out of somebody."
	icon = 'voidcrew/modules/plasma_weapons/icons/plasma_wounds.dmi'
	icon_state = "slag_bead"
	w_class = WEIGHT_CLASS_TINY

/obj/item/plasma_slag/Initialize(mapload)
	. = ..()
	pixel_x = rand(-6, 6)
	pixel_y = rand(-6, 6)
