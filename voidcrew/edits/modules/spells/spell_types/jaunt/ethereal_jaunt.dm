// Voidcrew extensions to code/modules/spells/spell_types/jaunt/ethereal_jaunt.dm.

// VOIDCREW EDIT: reclaim reference effects even when the action loses its owner first.
/datum/action/cooldown/spell/jaunt/ethereal_jaunt/Destroy()
	clear_exit_points()
	return ..()

/datum/action/cooldown/spell/jaunt/ethereal_jaunt/proc/clear_exit_points()
	QDEL_NULL(start_point_anchor)
	QDEL_LIST(exit_point_list)
	exit_point_list = null

/// Removal, body changes and forced ejection can end the return animation early.
/datum/action/cooldown/spell/jaunt/ethereal_jaunt/on_jaunt_exited(obj/effect/dummy/phased_mob/jaunt, mob/living/unjaunter)
	UnregisterSignal(jaunt, COMSIG_MOVABLE_MOVED)
	clear_exit_points()
	REMOVE_TRAIT(unjaunter, TRAIT_IMMOBILIZED, REF(src))
	return ..()

/datum/action/cooldown/spell/jaunt/ethereal_jaunt
	var/obj/effect/abstract/jaunt_exit/start_point_anchor

/obj/effect/abstract/jaunt_exit
	name = "jaunt return reference"
	icon = null
	invisibility = INVISIBILITY_ABSTRACT
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
