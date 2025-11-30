/obj/structure/overmap
	name = "overmap object"
	desc = "An unknown celestial object."
	icon = 'voidcrew/modules/overmap/icons/effects/overmap.dmi'
	icon_state = "object"
	// Disable emissive blockers - they cause visual artifacts (duplication, color inversion)
	// when viewed through popup map views like the helm console
	blocks_emissive = EMISSIVE_BLOCK_NONE

	/// Check that someone already act with this.
	var/concerned = FALSE
	/// Current integrity (turf count for ships). Updated by calculate_mass() via SSovermap.
	var/integrity = 100

	///List of other overmap objects in the same tile
	var/list/close_overmap_objects
	var/surveyed = FALSE

// voidcrew TODO: add the rest of overmap shit later

/obj/structure/overmap/proc/ship_act(mob/user, obj/structure/overmap/ship/acting)
	to_chat(user, "<span class='notice'>You don't think there's anything you can do here.</span>")

// Empty planets inherit ship_act from parent planet class to enable proper docking

/obj/structure/overmap/Initialize(mapload)
	. = ..()
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_entered),
		COMSIG_ATOM_EXITED = PROC_REF(on_exited),
	)
	AddElement(/datum/element/connect_loc, loc_connections)
/**
  * When something crosses another overmap object, add it to the nearby objects list, which are used by events and docking
  */
/obj/structure/overmap/proc/on_entered(datum/source, atom/movable/AM)
	SIGNAL_HANDLER
	if(istype(loc, /turf/) && istype(AM, /obj/structure/overmap))
		var/obj/structure/overmap/other = AM
		if(other == src)
			return
		LAZYOR(other.close_overmap_objects, src)
		LAZYOR(close_overmap_objects, other)

/**
  * See [/obj/structure/overmap/Crossed]
  */
/obj/structure/overmap/proc/on_exited(datum/source, atom/movable/AM)
	if(istype(loc, /turf/) && istype(AM, /obj/structure/overmap))
		var/obj/structure/overmap/other = AM
		if(other == src)
			return
		LAZYREMOVE(other.close_overmap_objects, src)
		LAZYREMOVE(close_overmap_objects, other)
