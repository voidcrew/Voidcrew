PROCESSING_SUBSYSTEM_DEF(nanites)
	name = "Nanites"
	ss_flags = SS_BACKGROUND|SS_POST_FIRE_TIMING|SS_NO_INIT
	wait = 10

	///List of all mobs that have nanites, used by Nanite HUD
	var/list/mob/living/nanite_monitored_mobs = list()

	var/list/datum/nanite_cloud_backup/cloud_backups = list()
	var/list/datum/nanite_program/relay/nanite_relays = list()

/datum/controller/subsystem/processing/nanites/proc/check_hardware(datum/nanite_cloud_backup/backup)
	if(QDELETED(backup.storage) || (backup.storage.machine_stat & (NOPOWER|BROKEN)))
		return FALSE
	return TRUE

/**
 * ##get_cloud_backup
 *
 * Goes through all nanite cloud backups and checks:
 * 1- It is the same ID as the one we are looking for.
 * 2- (If a ship is given) it is stored on a cloud controller aboard that ship.
 *    Nanite clouds are ship-local; the same ID number on another ship's controller
 *    is a different, unrelated cloud.
 * 3- It works properly (or is forced).
 * Args:
 * cloud_id - the cloud ID we are looking for
 * force - Whether we should skip the hardware check.
 * ship - the ship whose cloud network we are searching. Null searches every ship
 *        (used for admin/debug and conservative duplicate checks).
 */
/datum/controller/subsystem/processing/nanites/proc/get_cloud_backup(cloud_id, force = FALSE, obj/structure/overmap/ship/ship)
	for(var/datum/nanite_cloud_backup/backup as anything in cloud_backups)
		if(backup.cloud_id != cloud_id)
			continue
		if(ship && get_ship_from_atom(backup.storage) != ship)
			continue
		if(!force && !check_hardware(backup))
			continue //this cloud's hardware is down; another ship may still serve this ID
		return backup
