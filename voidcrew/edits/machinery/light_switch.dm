/**
 * A light switch keeps a hard reference to the area it controls and never let go of it, so an
 * area deleted with its switch (a player outpost's prison wing or cargo dock, torn down with the
 * claim) could not be collected until the switch itself was. With the outposts' areas no longer
 * pinned by SSmapping.areas_in_z, the prison wing's switch was the last thing holding its area
 * (create_and_destroy reference search). Let go of it once the switch is deleted; the parent's
 * teardown can still update the icon, which reads the area.
 */
/obj/machinery/light_switch/Destroy()
	. = ..()
	area = null
