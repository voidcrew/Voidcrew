/*
 * Fixtures a ship's crew should be able to rearrange.
 *
 * Both types below are bolted-down metal furniture that upstream never gave a tool path
 * to. Neither is protected by INDESTRUCTIBLE or move_resist - they are simply anchored
 * with nothing that can unanchor them, and their atom_deconstruct() payouts were only
 * ever reachable by beating them to pieces. Each gets the same two-step every other
 * piece of bolted furniture uses: left-click wrench to bolt and unbolt, right-click
 * wrench to take it apart once it is unbolted.
 */

/*
 * Handrail (code/game/objects/structures/beds_chairs/chair.dm)
 *
 * anchored = TRUE with no wrench_act and no atom_deconstruct at all, so a handrail
 * mapped into a corridor could never be moved and left nothing behind when smashed. It
 * is a single sheet of iron by its own custom_materials, so that is what it pays out.
 */
/obj/structure/handrail/examine(mob/user)
	. = ..()
	if(anchored)
		. += span_notice("It is <b>bolted</b> to the floor.")
	else
		. += span_notice("It is <i>unbolted</i> from the floor and can be dragged elsewhere. <b>Right-click</b> it with a wrench to take it apart.")

/obj/structure/handrail/wrench_act(mob/living/user, obj/item/tool)
	. = ..()
	if(.)
		return .
	if(has_buckled_mobs())
		balloon_alert(user, "someone's holding on!")
		return ITEM_INTERACT_BLOCKING
	if(default_unfasten_wrench(user, tool, time = 1 SECONDS) == SUCCESSFUL_UNFASTEN)
		return ITEM_INTERACT_SUCCESS
	return ITEM_INTERACT_BLOCKING

/obj/structure/handrail/wrench_act_secondary(mob/living/user, obj/item/tool)
	. = ..()
	if(.)
		return .
	if(anchored)
		balloon_alert(user, "unbolt it first!")
		return ITEM_INTERACT_BLOCKING
	if(has_buckled_mobs())
		balloon_alert(user, "someone's holding on!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "taking apart...")
	if(!tool.use_tool(src, user, 3 SECONDS, volume = 50))
		return ITEM_INTERACT_BLOCKING
	deconstruct(TRUE)
	return ITEM_INTERACT_SUCCESS

/obj/structure/handrail/atom_deconstruct(disassembled)
	new /obj/item/stack/sheet/iron(drop_location(), 1)

/*
 * Morgue and crematorium (code/game/objects/structures/morgue.dm)
 *
 * /obj/structure/bodycontainer is anchored with no tool acts of any kind; its
 * atom_deconstruct() already pays out 5 iron but only ever ran when the thing was
 * destroyed. The tray is a separate anchored structure that lives inside the container,
 * so the container has to be closed before it will unbolt - otherwise the tray is left
 * standing on the old tile with a container that no longer knows where it is.
 * Destroy() already dumps the contents out of the front, so a body inside is not lost.
 */
/obj/structure/bodycontainer/examine(mob/user)
	. = ..()
	if(anchored)
		. += span_notice("It is <b>bolted</b> to the floor.")
	else
		. += span_notice("It is <i>unbolted</i> from the floor and can be dragged elsewhere. <b>Right-click</b> it with a wrench to take it apart.")

/obj/structure/bodycontainer/wrench_act(mob/living/user, obj/item/tool)
	. = ..()
	if(.)
		return .
	if(connected && connected.loc != src)
		balloon_alert(user, "close the tray first!")
		return ITEM_INTERACT_BLOCKING
	if(default_unfasten_wrench(user, tool, time = 3 SECONDS) == SUCCESSFUL_UNFASTEN)
		return ITEM_INTERACT_SUCCESS
	return ITEM_INTERACT_BLOCKING

/obj/structure/bodycontainer/wrench_act_secondary(mob/living/user, obj/item/tool)
	. = ..()
	if(.)
		return .
	if(anchored)
		balloon_alert(user, "unbolt it first!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "taking apart...")
	if(!tool.use_tool(src, user, 5 SECONDS, volume = 50))
		return ITEM_INTERACT_BLOCKING
	deconstruct(TRUE)
	return ITEM_INTERACT_SUCCESS
