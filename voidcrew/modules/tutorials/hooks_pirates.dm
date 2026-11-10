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
