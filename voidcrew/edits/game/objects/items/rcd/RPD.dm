// Voidcrew extensions to code/game/objects/items/rcd/RPD.dm.

/// Installs an upgrade disk into the RPD, checking first that the upgrade isn't already present.
/// Returns TRUE if the disk was consumed.
/obj/item/pipe_dispenser/proc/install_upgrade(obj/item/rpd_upgrade/rpd_disk, mob/user)
	// Check if the upgrade's already present
	if(rpd_disk.upgrade_flags & upgrade_flags)
		balloon_alert(user, "already installed!")
		return FALSE

	// Adds the upgrade from the disk and then deletes the disk
	upgrade_flags |= rpd_disk.upgrade_flags
	playsound(loc, 'sound/machines/click.ogg', 50, vary = TRUE)
	balloon_alert(user, "upgrade installed")
	qdel(rpd_disk)
	return TRUE

/// Clicking an upgrade disk onto the RPD installs it, same as clicking the RPD onto the disk.
/obj/item/pipe_dispenser/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/rpd_upgrade) && ISADVANCEDTOOLUSER(user))
		return install_upgrade(tool, user) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING
	return ..()
