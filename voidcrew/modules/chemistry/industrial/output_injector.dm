/**
 * Remote injector.
 *
 * Ported from monkestation's wiremod_chem module (components/ouputs/injector_output.dm).
 *
 * A chemical tank that jabs whoever walks over it. It logs to the attack log with the ckey
 * of whoever set the dose, because this is a trivially weaponisable piece of automation and
 * the round needs to be able to say who built the trap.
 */
/obj/structure/chemical_tank/injector
	name = "remote injector"
	desc = "While anchored, injects anyone who walks over it with some stored chemicals."
	icon_state = "sprayer"
	component_name = "Injector Output"
	density = FALSE
	reagent_flags = TRANSPARENT

	var/max_inject = 20
	var/inject_amount = 0
	/// Whoever last set the dose. Recorded for the attack log.
	var/creator_ckey

/obj/structure/chemical_tank/injector/Initialize(mapload)
	. = ..()
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_entered),
	)
	AddElement(/datum/element/connect_loc, loc_connections)

/obj/structure/chemical_tank/injector/proc/on_entered(datum/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(!anchored)
		return
	if(!iscarbon(arrived))
		return
	if(!inject_amount || !reagents.total_volume)
		return

	visible_message(span_danger("[src] pricks [arrived] with a needle, injecting [inject_amount] units into them."))
	reagents.trans_to(arrived, inject_amount, methods = INJECT)
	if(creator_ckey)
		log_attack("[creator_ckey] injected [key_name(arrived)] with [inject_amount] units using a remote injector.")

/obj/structure/chemical_tank/injector/click_alt(mob/living/user)
	var/inject_choice = tgui_input_number(user, "How much to inject someone with?", name, inject_amount, max_inject, 0)
	if(!isnull(inject_choice))
		inject_amount = inject_choice
		creator_ckey = user.client?.ckey
	create_linked_component()
	return CLICK_ACTION_SUCCESS
