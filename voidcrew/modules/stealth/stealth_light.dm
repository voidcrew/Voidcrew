/**
 * # Stealth guards: flashlights (owner decision 31)
 *
 * A scav guard carries a real seclite clipped to its belt (or its vest, or a pocket). tg's own overlay
 * light draws it, cast the way the guard faces, and adds to the lit turfs' dynamic_lumcount, which the
 * darkness rule (stealth_tile_is_dark()) already reads. So the light shows a guard what it lights and
 * nothing more: there is no "sees in the dark" rule.
 *
 * The guard switches it with the light's own toggle (its click and all): on when it stands somewhere dark,
 * always on while suspicious, alert or searching, off in lit places while unaware so a lit patrol looks
 * the same as before. It keeps it on for STEALTH_LIGHT_HOLD after it last wanted it, so walking along the
 * edge of a lit room doesn't flick it on and off.
 *
 * Beating it is tg's: you see the beam coming; an EMP or the saboteur gun cuts it out for a while (the
 * scav seclite takes an EMP as tg's saboteur hit; a stock seclite ignores EMPs); a guard that is down,
 * stunned, cuffed, asleep or dead doesn't touch it. A light that is gone from its body (deleted, burnt,
 * forced off) is gone: the guard goes without. Like the rest of its kit it is locked gear (human NPC
 * decision D3), so it can't be stripped or looted.
 */

/// A guard's seclite: an EMP blinds it for a while, as tg's saboteur gun does.
/obj/item/flashlight/seclite/scav

/obj/item/flashlight/seclite/scav/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	on_saboteur(null, severity == EMP_HEAVY ? STEALTH_LIGHT_EMP_HEAVY : STEALTH_LIGHT_EMP_LIGHT)

/mob/living/carbon/human/npc
	/// Weakref to the flashlight a stealth guard switches on in the dark, or null for none
	var/datum/weakref/stealth_light

/// Clips a seclite on: belt, vest, then a pocket. Returns it, or null if there was nowhere to put it.
/mob/living/carbon/human/npc/proc/stealth_give_light()
	var/obj/item/flashlight/seclite/scav/light = new(src)
	for(var/slot in list(ITEM_SLOT_BELT, ITEM_SLOT_SUITSTORE, ITEM_SLOT_LPOCKET, ITEM_SLOT_RPOCKET))
		if(equip_to_slot_if_possible(light, slot, disable_warning = TRUE))
			stealth_light = WEAKREF(light)
			return light
	qdel(light)
	return null

/// How much `light` adds to `tile` right now (tg's overlay light: a flat share on every turf it reaches).
/proc/stealth_light_share(obj/item/flashlight/light, turf/tile)
	if(!light?.light_on)
		return 0
	var/datum/component/overlay_lighting/glow = light.GetComponent(/datum/component/overlay_lighting)
	if(isnull(glow) || !(tile in glow.affected_turfs))
		return 0
	return glow.lum_power

/datum/ai_controller/basic_controller/human_npc/stealth
	/// world.time until which it keeps its light on after it last wanted it
	var/light_hold_until = 0

/// Its flashlight, if it still has it on its body; else null.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_light()
	var/mob/living/carbon/human/npc/guard = pawn
	if(!ishumannpc(guard))
		return null
	var/obj/item/flashlight/light = guard.stealth_light?.resolve()
	if(QDELETED(light) || light.loc != guard)
		return null
	return light

/// Switches its light on or off for where it stands and what it is doing. Does nothing while it can't use
/// its hands, while a player has the body, or while the light is cut out.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_update_light()
	var/mob/living/carbon/human/npc/guard = pawn
	if(QDELETED(guard) || guard.stat != CONSCIOUS || stealth_driven() || stealth_captive() || HAS_TRAIT(guard, TRAIT_HANDS_BLOCKED))
		return
	var/obj/item/flashlight/light = stealth_light()
	if(isnull(light) || !COOLDOWN_FINISHED(light, disabled_time))
		return
	var/wanted = stealth_state() != STEALTH_UNAWARE || stealth_tile_is_dark(get_turf(guard), light)
	if(wanted)
		light_hold_until = world.time + STEALTH_LIGHT_HOLD
	else if(world.time < light_hold_until)
		return
	if(wanted != light.light_on)
		light.toggle_light(guard)
