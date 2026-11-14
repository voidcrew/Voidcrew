/**
 * # Outpost turret control locks
 *
 * In a lockup a portable turret's controls, and a turret control panel's, answer only to its staff;
 * on a player outpost only to the outpost's members, as a hull turret's do there (ship_defense_turret.dm).
 * Hull defense turrets keep their own rules (uses_outpost_turret_rules()).
 */

/**
 * Whether the outpost's control lock holds for this turret: for every turret players can build or
 * bring. Hull defense turrets have their own.
 */
/obj/machinery/porta_turret/proc/uses_outpost_turret_rules()
	return TRUE

/obj/machinery/porta_turret/ship_defense/uses_outpost_turret_rules()
	return FALSE

/**
 * Whether `user` may work `machine`'s controls: in a lockup only its staff; on a player outpost only
 * its members (the owner, stewards, treasurers, residents and builders), as for a hull turret bolted
 * there; anywhere else, or on a claim nobody holds, whoever tg lets.
 */
/proc/outpost_turret_controls_allowed(atom/machine, mob/user)
	if(!ismob(user) || isAdminGhostAI(user))
		return TRUE
	var/datum/outpost_prison/prison = get_outpost_prison(machine)
	if(prison)
		return prison.is_staff(user)
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(machine)
	if(isnull(home) || !home.founder_ckey)
		return TRUE
	return home.can_manage(user) || home.can_spend(user) || home.is_resident(user) || home.can_build(user)

/obj/machinery/porta_turret/proc/outpost_controls_allowed(mob/user)
	return !uses_outpost_turret_rules() || outpost_turret_controls_allowed(src, user)

/// Whether using `tool` on it works its controls: an ID swipe, a wrench while it is off, or a crowbar on its wreck
/obj/machinery/porta_turret/proc/is_control_tool(obj/item/tool)
	if(machine_stat & BROKEN)
		return tool.tool_behaviour == TOOL_CROWBAR
	if(tool.tool_behaviour == TOOL_WRENCH && !on)
		return TRUE
	return !isnull(tool.GetID())

/obj/machinery/porta_turret/ui_interact(mob/user, datum/tgui/ui)
	if(!ui && !isobserver(user) && !outpost_controls_allowed(user))
		balloon_alert(user, "controls locked!")
		return
	return ..()

/obj/machinery/porta_turret/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(!outpost_controls_allowed(ui.user))
		balloon_alert(ui.user, "controls locked!")
		return TRUE
	return ..()

/obj/machinery/porta_turret/attackby(obj/item/I, mob/user, list/modifiers, list/attack_modifiers)
	if(is_control_tool(I) && !outpost_controls_allowed(user))
		balloon_alert(user, "controls locked!")
		return TRUE
	return ..()

/obj/machinery/porta_turret/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(!outpost_controls_allowed(user))
		balloon_alert(user, "controls locked!")
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/machinery/porta_turret_cover/attackby(obj/item/I, mob/user, list/modifiers, list/attack_modifiers)
	if(parent_turret && ((I.tool_behaviour == TOOL_WRENCH && !parent_turret.on) || I.GetID()) && !parent_turret.outpost_controls_allowed(user))
		balloon_alert(user, "controls locked!")
		return TRUE
	return ..()

/obj/machinery/porta_turret_cover/multitool_act(mob/living/user, obj/item/multitool/multi_tool)
	if(parent_turret && !parent_turret.outpost_controls_allowed(user))
		balloon_alert(user, "controls locked!")
		return ITEM_INTERACT_BLOCKING
	return ..()

// A turret control panel sets every turret linked to it, so it answers to the same people.

/obj/machinery/turretid/ui_interact(mob/user, datum/tgui/ui)
	if(!ui && !isobserver(user) && !outpost_turret_controls_allowed(src, user))
		balloon_alert(user, "controls locked!")
		return
	return ..()

/obj/machinery/turretid/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(!outpost_turret_controls_allowed(src, ui.user))
		balloon_alert(ui.user, "controls locked!")
		return TRUE
	return ..()

/obj/machinery/turretid/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.GetID() && !outpost_turret_controls_allowed(src, user))
		balloon_alert(user, "controls locked!")
		return TRUE
	return ..()

/obj/machinery/turretid/multitool_act(mob/living/user, obj/item/multitool/multi_tool)
	if(!outpost_turret_controls_allowed(src, user))
		balloon_alert(user, "controls locked!")
		return ITEM_INTERACT_BLOCKING
	return ..()

// The switches, reached from the panel and from AI and cyborg clicks
/obj/machinery/turretid/toggle_on(mob/user)
	if(user && !outpost_turret_controls_allowed(src, user))
		balloon_alert(user, "controls locked!")
		return
	return ..()

/obj/machinery/turretid/toggle_lethal(mob/user)
	if(user && !outpost_turret_controls_allowed(src, user))
		balloon_alert(user, "controls locked!")
		return
	return ..()

/obj/machinery/turretid/shoot_silicons(mob/user)
	if(user && !outpost_turret_controls_allowed(src, user))
		balloon_alert(user, "controls locked!")
		return
	return ..()
