/**
 * Disk stacking vs. the ship disk.
 *
 * Upstream (tg #94112) turned every /obj/item/disk into a stackable one: clicking any disk on
 * any other builds an /obj/item/disk_stack and moves both inside it
 * (code/game/objects/items/floppy_disk.dm). There is no opt-out - no blacklist, no type filter -
 * and the ship disk became an /obj/item/disk subtype when it was repathed for its sprite.
 *
 * Two things go wrong for a stacked ship disk, and the first is silent:
 *
 * 1. The held item is now the STACK, not the disk. /obj/machinery/rnd/server/ship/attacked_by
 *    tests istype(attacking_item, /obj/item/disk/computer/ship_disk), which a stack fails, so the
 *    player just whacks the server with it and nothing at all happens.
 * 2. /obj/item/disk_stack/Destroy() runs QDEL_LIST(stacked_disks), and /atom/movable/Destroy()
 *    qdels whatever is left in contents. Either one reaches the ship disk's Destroy, which
 *    QDEL_NULLs stored_research - the hull's entire techweb, gone because someone tidied two
 *    disks together and the stack later burned.
 *
 * So ship disks refuse to stack at all. The check is a var rather than an istype so any other
 * disk carrying irreplaceable state can opt out the same way.
 */
/obj/item/disk
	/// If TRUE this disk can never be put into an /obj/item/disk_stack. See the file comment.
	var/unstackable = FALSE

/obj/item/disk/computer/ship_disk
	unstackable = TRUE

/obj/item/disk/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	// Refuse before ..() rather than inside add_to_stack: upstream's handler creates the stack
	// first and adds to it second, so a refusal further in would strand an empty stack on the turf.
	var/obj/item/disk/other_disk = tool
	if(istype(other_disk) && (unstackable || other_disk.unstackable))
		balloon_alert(user, "won't stack!")
		return ITEM_INTERACT_BLOCKING
	if(unstackable && istype(tool, /obj/item/disk_stack))
		balloon_alert(user, "won't stack!")
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/item/disk_stack/add_to_stack(mob/living/user, obj/item/disk/newdisk)
	// Backstop for the stack-is-the-target route (disk clicked onto an existing stack), which does
	// not go through the handler above. Stack-onto-stack uses merge_stacks() and needs no guard:
	// with both entry points closed no stack can ever be holding an unstackable disk to merge.
	if(newdisk.unstackable)
		balloon_alert(user, "won't stack!")
		return ITEM_INTERACT_BLOCKING
	return ..()
