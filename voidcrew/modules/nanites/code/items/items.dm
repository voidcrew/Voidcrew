/obj/item/storage/box/disks_nanite
	name = "nanite program disks box"
	illustration = "disk_kit"

/obj/item/storage/box/disks_nanite/PopulateContents()
	for(var/i in 1 to 7)
		new /obj/item/disk/nanite_program(src)

//Names are intentionally all the same - track your nanites, or use a hand labeler
//This also means that you can give flesh melting nanites to your victims if you feel like it

/obj/item/disk/nanite_program
	name = "nanite program disk"
	desc = "A disk capable of storing nanite cloud backups. Can be saved to and loaded from using a Nanite Programmer."
	icon = 'voidcrew/modules/nanites/icons/diskette.dmi'
	icon_state = "disk_map"

	///The programs of the cloud backup saved on this disk.
	var/list/datum/nanite_program/backup = list()

/obj/item/disk/nanite_program/Initialize(mapload)
	. = ..()
	add_overlay("nanite")

/obj/item/disk/nanite_program/Destroy()
	QDEL_LIST(backup)
	return ..()
