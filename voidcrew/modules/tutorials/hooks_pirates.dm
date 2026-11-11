// Tutorial checklist hooks: the Hunting pirates item (voidcrew/modules/npc_ships).
// Overrides chain with any others of the same proc and keep the parent's return value.
// Boarding a pirate ship is credited from tutorial_on_docked() in tutorial_progress.dm and
// from the interdictor force-dock in hooks_ship_combat.dm.

/// TRUE for a hostile NPC ship that no crew has claimed.
/proc/tutorial_is_pirate_ship(obj/structure/overmap/ship/ship)
	var/obj/structure/overmap/ship/npc/npc_ship = ship
	return istype(npc_ship) && !QDELETED(npc_ship) && npc_ship.hostile && !npc_ship.player_controlled

/// The wave-complete signal is only sent once a boarding wave is cleared.
/datum/ai_controller/npc_ship/start_boarding_phase()
	. = ..()
	if(.)
		RegisterSignal(src, COMSIG_BOARDING_WAVE_COMPLETE, PROC_REF(tutorial_on_wave_complete), override = TRUE)

/datum/ai_controller/npc_ship/proc/tutorial_on_wave_complete(datum/source, wave)
	SIGNAL_HANDLER
	var/obj/structure/overmap/ship/target = get_target()
	if(!QDELETED(target) && !istype(target, /obj/structure/overmap/ship/npc))
		tutorial_credit_crew(target, TUTORIAL_STEP_PIRATES_BOARDERS, aboard_only = TRUE)

/// Runs when the boss dies, or a human boss is downed or cuffed. Disabling the ship ends it.
/datum/ai_controller/npc_ship/handle_boss_killed()
	var/state_before = get_combat_state()
	var/obj/structure/overmap/ship/target = get_target()
	. = ..()
	if(state_before == NPC_COMBAT_DISABLED || get_combat_state() != NPC_COMBAT_DISABLED)
		return
	if(!QDELETED(target) && !istype(target, /obj/structure/overmap/ship/npc))
		tutorial_credit_crew(target, TUTORIAL_STEP_PIRATES_COMMANDER, aboard_only = TRUE)

/// Hull failure. Credits the crew the pirate was fighting.
/obj/structure/overmap/ship/npc/on_ship_destroyed()
	var/already_crashed = has_crash_landed
	var/was_pirate = tutorial_is_pirate_ship(src)
	var/datum/ai_controller/npc_ship/controller = ai_controller
	var/obj/structure/overmap/ship/target = istype(controller) ? controller.get_target() : null
	. = ..()
	if(already_crashed || !was_pirate || !has_crash_landed)
		return
	if(!QDELETED(target) && !istype(target, /obj/structure/overmap/ship/npc))
		tutorial_credit_crew(target, TUTORIAL_STEP_PIRATES_SHOOT, aboard_only = TRUE)

/obj/machinery/computer/helm/claim_npc_ship(obj/structure/overmap/ship/npc/npc_ship, mob/living/claimer, form_new = null)
	. = ..()
	if(. && claimer)
		tutorial_credit(claimer, TUTORIAL_STEP_PIRATES_CLAIM)

/// The hull was abandoned (crew wiped) and claimed with the helm's Claim button, no key.
/obj/structure/overmap/ship/npc/claim_abandoned_ship(mob/living/claimer, form_new = null)
	var/was_pirate = tutorial_is_pirate_ship(src)
	. = ..()
	if(. && was_pirate && claimer)
		tutorial_credit(claimer, TUTORIAL_STEP_PIRATES_CLAIM)

/// Credits whoever picked up a pirate's hail.
/obj/machinery/holopad/answer_hail(obj/structure/overmap/ship/npc/pirate/pirate, mob/user)
	. = ..()
	if(. && user)
		tutorial_credit(user, TUTORIAL_STEP_PIRATES_HAIL)

/// A pirate bounty paid out to a crew (the mission board turn-in).
/datum/pirate_bounty/complete(obj/structure/overmap/ship/winner, obj/machinery/mission_pad/pad)
	var/was_settled = completed || failed
	. = ..()
	if(!was_settled && completed && !QDELETED(winner) && !istype(winner, /obj/structure/overmap/ship/npc))
		tutorial_credit_crew(winner, TUTORIAL_STEP_PIRATES_BOUNTY)

// ---------------------------------------------------------------------------
// Live state for the Hunting pirates steps.
// ---------------------------------------------------------------------------

/// Tiles on the overmap a boardable pirate can be from the crew's ship.
#define TUTORIAL_BOARD_RANGE 2
/// Matches TUTORIAL_HIGHLIGHT_VIEW_RANGE in tutorial_highlights.dm.
#define TUTORIAL_KEY_CARRIER_RANGE 9

/// The controller of the pirate currently engaging this ship, or null.
/proc/tutorial_engaging_pirate_controller(obj/structure/overmap/ship/ship)
	if(QDELETED(ship))
		return null
	var/obj/structure/overmap/ship/npc/pirate = ship.engaging_pirate_ref?.resolve()
	if(QDELETED(pirate))
		return null
	var/datum/ai_controller/npc_ship/controller = pirate.ai_controller
	return istype(controller) ? controller : null

/// The ZONE_* type of the space a ship is in, or null when unknown.
/proc/tutorial_ship_zone_type(obj/structure/overmap/ship/ship)
	if(QDELETED(ship))
		return null
	var/turf/ship_turf = get_turf(ship)
	return ship_turf ? SSovermap_zones.get_zone_type(ship_turf) : null

/// A pirate ship near this one that a helm Dock would board: one our interdictor holds, or
/// a disabled one. Null if none.
/proc/tutorial_boardable_pirate(obj/structure/overmap/ship/ship)
	if(QDELETED(ship))
		return null
	var/obj/structure/overmap/ship/npc/held = tutorial_interdicted_ship(ship)
	if(tutorial_is_pirate_ship(held))
		return held
	var/turf/ship_turf = get_turf(ship)
	if(!ship_turf)
		return null
	for(var/obj/structure/overmap/ship/npc/pirate in range(TUTORIAL_BOARD_RANGE, ship_turf))
		if(pirate.is_disabled && tutorial_is_pirate_ship(pirate))
			return pirate
	return null

/// Downed or cuffed NPCs in view of the viewer with a ship key in a pocket.
/proc/tutorial_key_carriers(mob/user)
	. = list()
	if(!user)
		return
	for(var/mob/living/holder in view(TUTORIAL_KEY_CARRIER_RANGE, user))
		if(holder == user || holder.ckey)
			continue
		if(holder.stat == CONSCIOUS && !HAS_TRAIT(holder, TRAIT_RESTRAINED))
			continue
		if(locate(/obj/item/ship_key) in holder.contents)
			. += holder

#undef TUTORIAL_BOARD_RANGE
#undef TUTORIAL_KEY_CARRIER_RANGE
