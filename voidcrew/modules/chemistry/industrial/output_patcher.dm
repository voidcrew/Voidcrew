/**
 * Remote patcher.
 *
 * Ported from monkestation's wiremod_chem module (components/ouputs/patcher_output.dm).
 *
 * The injector's harmless sibling: applies its contents by touch rather than by needle, so
 * it is the piece you actually want in a medbay corridor.
 */
/obj/structure/chemical_tank/patcher
	name = "remote patcher"
	desc = "While anchored, slaps a medicated patch onto anyone who walks over it."
	icon_state = "sprayer"
	component_name = "Patcher Output"
	density = FALSE
	reagent_flags = TRANSPARENT

	var/max_inject = 50
	var/inject_amount = 10

/obj/structure/chemical_tank/patcher/Initialize(mapload)
	. = ..()
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_entered),
	)
	AddElement(/datum/element/connect_loc, loc_connections)

/obj/structure/chemical_tank/patcher/proc/on_entered(datum/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(!anchored)
		return
	if(!iscarbon(arrived))
		return
	if(!inject_amount || !reagents.total_volume)
		return

	visible_message(span_notice("[src] slaps [arrived] with a patch containing [inject_amount] units."))
	reagents.trans_to(arrived, inject_amount, methods = TOUCH)

/obj/structure/chemical_tank/patcher/click_alt(mob/living/user)
	var/inject_choice = tgui_input_number(user, "How much to put into a patch?", name, inject_amount, max_inject, 0)
	if(!isnull(inject_choice))
		inject_amount = inject_choice
	create_linked_component()
	return CLICK_ACTION_SUCCESS
