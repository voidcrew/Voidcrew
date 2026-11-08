/**
 * # Specimen crate
 *
 * A heavy crate built to hold one large find. Effects stop while it is shut inside (an
 * artifact off a turf never stirs), so a crew can haul a dangerous find without it going off.
 * Any shut crate gets a find past an outpost checkpoint and up to a buyer; this one takes only
 * the find and small things, never people or other machines, and shows the find's field tag on
 * the lid so a hold full of crates can be told apart.
 *
 * Art: a recolour of tg's plain crate (icons/obj/storage/crates.dmi "crate"/"crateopen"), lead
 * grey with padded straps; "manifest" and "welded" are tg's own, copied so crate overlays line up.
 */
/obj/structure/closet/crate/specimen
	name = "specimen crate"
	desc = "A padded, lead-lined crate big enough for one large find."
	icon = 'voidcrew/modules/xenoarch/icons/specimen_crate.dmi'
	icon_state = "specimen"
	base_icon_state = "specimen"
	allow_dense = TRUE
	allow_objects = TRUE
	storage_capacity = 10
	// Its own sprite sheet holds no other crate's states
	paint_jobs = null

/obj/structure/closet/crate/specimen/insertion_allowed(atom/movable/thing)
	// The only dense thing it takes is one artifact. No people, no other machines.
	if(istype(thing, /obj/machinery/artifact))
		var/obj/machinery/artifact/find = thing
		if(find.anchored || (locate(/obj/machinery/artifact) in contents))
			return FALSE
		return TRUE
	if(ismob(thing) || (isobj(thing) && thing.density))
		return FALSE
	return ..()

/obj/structure/closet/crate/specimen/examine(mob/user)
	. = ..()
	if(opened)
		return
	var/obj/machinery/artifact/find = locate() in contents
	if(!find)
		return
	. += "Something heavy is strapped in."
	if(find.is_dug())
		. += "A field tag clipped to the lid reads <b>[find.serial]</b>."
