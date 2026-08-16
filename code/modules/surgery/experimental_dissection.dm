///How many research points you gain from dissecting a Human.
#define BASE_HUMAN_REWARD 100

/datum/surgery/advanced/experimental_dissection
	name = "Experimental Dissection"
	desc = "A surgical procedure which analyzes the biology of a corpse, and automatically adds new findings to the research database."
	steps = list(
		/datum/surgery_step/incise,
		/datum/surgery_step/retract_skin,
		/datum/surgery_step/experimental_dissection,
		/datum/surgery_step/close,
	)
	surgery_flags = SURGERY_REQUIRE_RESTING | SURGERY_MORBID_CURIOSITY
	possible_locs = list(BODY_ZONE_CHEST)
	target_mobtypes = list(/mob/living)

/datum/surgery/advanced/experimental_dissection/can_start(mob/user, mob/living/target)
	. = ..()
	if(!.)
		return .
	// VOIDCREW EDIT START - a body dissected at a lower tier can be reopened by a higher
	// dissection tier for the difference in yield, so researching a better dissection
	// never wastes corpses already processed under the old one. The helper and the
	// bookkeeping var live in voidcrew/modules/surgery/experimental_dissection.dm.
	if(HAS_TRAIT_FROM(target, TRAIT_DISSECTED, EXPERIMENTAL_SURGERY_TRAIT) && dissection_value_remaining(target) <= 0)
		return FALSE
	// VOIDCREW EDIT END
	if(target.stat != DEAD)
		return FALSE
	return .

/datum/surgery_step/experimental_dissection
	name = "dissection"
	implements = list(
		/obj/item/autopsy_scanner = 100,
		TOOL_SCALPEL = 60,
		TOOL_KNIFE = 20,
		/obj/item/shard = 10,
	)
	time = 12 SECONDS
	silicons_obey_prob = TRUE
	///Research points a baseline human corpse is worth. Upgraded dissection tiers raise this.
	var/base_value = BASE_HUMAN_REWARD

/datum/surgery_step/experimental_dissection/preop(mob/user, mob/living/target, target_zone, obj/item/tool, datum/surgery/surgery)
	user.visible_message(span_notice("[user] starts dissecting [target]."), span_notice("You start dissecting [target]."))

/datum/surgery_step/experimental_dissection/success(mob/user, mob/living/target, target_zone, obj/item/tool, datum/surgery/surgery, default_display_results = FALSE)
	var/points_earned = check_value(target)
	// VOIDCREW EDIT START - a reopened body only pays out what lower tiers have not already extracted
	points_earned = max(points_earned - target.dissection_points_paid, 0)
	target.dissection_points_paid += points_earned
	// VOIDCREW EDIT END
	user.visible_message(span_notice("[user] dissects [target], discovering [points_earned] point\s of data!"), span_notice("You dissect [target], finding [points_earned] point\s worth of discoveries, you also write a few notes."))

	var/obj/item/research_notes/the_dossier = new /obj/item/research_notes(user.loc, points_earned, "biology")
	if(!user.put_in_hands(the_dossier) && istype(user.get_inactive_held_item(), /obj/item/research_notes))
		var/obj/item/research_notes/hand_dossier = user.get_inactive_held_item()
		hand_dossier.merge(the_dossier)

	target.apply_damage(80, BRUTE, BODY_ZONE_CHEST)
	ADD_TRAIT(target, TRAIT_DISSECTED, EXPERIMENTAL_SURGERY_TRAIT)
	return ..()

/datum/surgery_step/experimental_dissection/failure(mob/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery)
	// VOIDCREW EDIT START - a botch pays 1% of whatever this tier could still have extracted
	// and ruins the rest of that value; only a higher tier can reopen the body afterwards.
	var/remaining_value = max(check_value(target) - target.dissection_points_paid, 0)
	var/points_earned = round(remaining_value * 0.01)
	target.dissection_points_paid += remaining_value
	// VOIDCREW EDIT END
	user.visible_message(
		span_notice("[user] dissects [target]!"),
		span_notice("You dissect [target], but do not find anything particularly interesting."),
	)

	if(points_earned > 0)
		var/obj/item/research_notes/the_dossier = new /obj/item/research_notes(user.loc, points_earned, "biology")
		if(!user.put_in_hands(the_dossier) && istype(user.get_inactive_held_item(), /obj/item/research_notes))
			var/obj/item/research_notes/hand_dossier = user.get_inactive_held_item()
			hand_dossier.merge(the_dossier)

	target.apply_damage(80, BRUTE, BODY_ZONE_CHEST)
	// A botched dissection still consumes the corpse. Without this the surgery can be cancelled and
	// re-run indefinitely on the same body, which was farmable for free notes.
	ADD_TRAIT(target, TRAIT_DISSECTED, EXPERIMENTAL_SURGERY_TRAIT)
	return TRUE

///Calculates how many research points dissecting 'target' is worth.
/datum/surgery_step/experimental_dissection/proc/check_value(mob/living/target)
	var/cost = base_value

	if(ishuman(target))
		var/mob/living/carbon/human/human_target = target
		if(human_target.dna?.species)
			if(ismonkey(human_target))
				cost /= 5
			else if(isabductor(human_target))
				cost *= 4
			else if(isgolem(human_target) || iszombie(human_target))
				cost *= 3
			else if(isjellyperson(human_target) || ispodperson(human_target))
				cost *= 2
	else if(isalienroyal(target))
		cost *= 10
	else if(isalienadult(target))
		cost *= 5
	// Fauna is graded by how dangerous it is, so the corpse is worth roughly what it cost to make.
	// melee_damage_upper lives on /mob/living, so this reads correctly on both basic and simple mobs.
	else if(ismegafauna(target))
		cost *= 10
	else if(istype(target, /mob/living/simple_animal/hostile/asteroid/elite))
		cost *= 3
	else if(target.melee_damage_upper > 0)
		cost /= 3
	else
		cost /= 6

	return max(round(cost), 1)

#undef BASE_HUMAN_REWARD

/obj/item/research_notes
	name = "research notes"
	desc = "Valuable scientific data. Use it in an ancient research server to turn it in."
	icon = 'icons/obj/service/bureaucracy.dmi'
	icon_state = "paper"
	w_class = WEIGHT_CLASS_SMALL
	///research points it holds
	var/value = 100
	///origin of the research
	var/origin_type = "debug"
	///if it ws merged with different origins to apply a bonus
	var/mixed = FALSE

/obj/item/research_notes/Initialize(mapload, value, origin_type)
	. = ..()
	// Explicitly check for null, not truthiness: a passed-in 0 must mean "worthless", not "use the default".
	if(!isnull(value))
		src.value = value
	if(origin_type)
		src.origin_type = origin_type
	change_vol()

/obj/item/research_notes/examine(mob/user)
	. = ..()
	. += span_notice("It is worth [value] research points.")

/obj/item/research_notes/attackby(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(istype(attacking_item, /obj/item/research_notes))
		var/obj/item/research_notes/notes = attacking_item
		value = value + notes.value
		change_vol()
		qdel(notes)
		return
	return ..()

/// proc that changes name and icon depending on value
/obj/item/research_notes/proc/change_vol()
	if(value >= 10000)
		name = "revolutionary discovery in the field of [origin_type]"
		icon_state = "docs_verified"
	else if(value >= 2500)
		name = "essay about [origin_type]"
		icon_state = "paper_words"
	else if(value >= 100)
		name = "notes of [origin_type]"
		icon_state = "paperslip_words"
	else
		name = "fragmentary data of [origin_type]"
		icon_state = "scrap"

///proc when you slap research notes into another one, it applies a bonus if they are of different origin (only applied once)
/obj/item/research_notes/proc/merge(obj/item/research_notes/new_paper)
	var/bonus = min(value , new_paper.value)
	value = value + new_paper.value
	if(origin_type != new_paper.origin_type && !mixed)
		value += bonus * 0.3
		origin_type = "[origin_type] and [new_paper.origin_type]"
		mixed = TRUE
	change_vol()
	qdel(new_paper)
