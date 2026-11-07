/**
 * A deathrattle implant only hears from its /datum/deathrattle_group, and nothing makes a group
 * for one found in the world, so a found implant never did anything. One with no group answers
 * to its wearer's crew instead: it reports any crewmate's death, whether or not they carry one.
 */
/obj/item/implant/deathrattle
	/// TRUE once a deathrattle group holds this implant. The group does the reporting then.
	var/in_group = FALSE

/datum/deathrattle_group/register(obj/item/implant/deathrattle/implant)
	implant.in_group = TRUE
	return ..()

/obj/item/implant/deathrattle/implant(mob/living/target, mob/user, silent = FALSE, force = FALSE)
	. = ..()
	if(. && imp_in == target)
		RegisterSignal(SSdcs, COMSIG_GLOB_MOB_DEATH, PROC_REF(on_mob_death))

/obj/item/implant/deathrattle/removed(mob/living/source, silent = FALSE, special = 0)
	UnregisterSignal(SSdcs, COMSIG_GLOB_MOB_DEATH)
	return ..()

/// Whether a mob is on the crew of whoever wears this right now. The wearer doesn't count.
/obj/item/implant/deathrattle/proc/is_wearers_crewmate(mob/living/other)
	if(other == imp_in || !other.mind)
		return FALSE
	var/datum/voidcrew_crew_record/crew = imp_in?.mind?.get_reputation_crew()
	return crew && (other.mind in crew.minds)

/// Signal handler for [COMSIG_GLOB_MOB_DEATH]. Same words and knell as a group's rattle.
/obj/item/implant/deathrattle/proc/on_mob_death(datum/source, mob/living/dead, gibbed)
	SIGNAL_HANDLER

	if(in_group || !is_wearers_crewmate(dead))
		return
	to_chat(imp_in, "<i>You hear a strange, robotic voice in your head...</i> \"[span_robot("<b>[dead.mind.name]</b> has died at <b>[get_area_name(get_turf(dead))]</b>.")]\"")
	var/knell = pick(
		'sound/items/knell/knell1.ogg',
		'sound/items/knell/knell2.ogg',
		'sound/items/knell/knell3.ogg',
		'sound/items/knell/knell4.ogg',
	)
	imp_in.playsound_local(get_turf(imp_in), knell, vol = 75, vary = FALSE, pressure_affected = FALSE, use_reverb = FALSE)
