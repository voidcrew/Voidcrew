/obj/structure/closet/wall
	name = "wall closet"
	desc = "It's a basic storage unit. Now wallmounted."
	anchored = TRUE
	density = FALSE
	icon = 'voidcrew/icons/obj/storage/wallcloset.dmi'
	icon_state = "generic"
	max_mob_size = MOB_SIZE_TINY
	storage_capacity = 15

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall, 32)

/obj/structure/closet/wall/Initialize(mapload)
	. = ..()
	if(mapload)
		find_and_hang_on_wall()

/obj/structure/closet/wall/animate_door(closing = FALSE)
	if(!door_anim_time)
		return ..()
	if(!door_obj)
		door_obj = new
	// The animated door is a separate atom, so it must match the wall locker's direction.
	door_obj.dir = dir
	return ..()

/obj/structure/closet/wall/close(mob/living/user)
	if(!opened || !can_close(user))
		return FALSE
	if(!before_close(user) || (SEND_SIGNAL(src, COMSIG_CLOSET_PRE_CLOSE, user) & BLOCK_CLOSE))
		return FALSE
	take_contents()
	playsound(loc, close_sound, close_sound_volume, TRUE, -3)
	opened = FALSE
	animate_door(TRUE)
	update_appearance()
	after_close(user)
	SEND_SIGNAL(src, COMSIG_CLOSET_POST_CLOSE, user)
	return TRUE

/obj/structure/closet/wall/engineering
	name = "engineer's wall locker"
	icon_state = "engi"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/engineering, 32)

/obj/structure/closet/wall/engineering/atmospherics
	name = "atmospheric technician's wall locker"
	icon_door = "atmos"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/engineering/atmospherics, 32)

/obj/structure/closet/wall/medical
	name = "medical doctor's wall locker"
	icon_state = "med"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/medical, 32)

/obj/structure/closet/wall/medical/chemistry
	name = "chemist's wall locker"
	icon_door = "chem"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/medical/chemistry, 32)

/obj/structure/closet/wall/science
	name = "scientist's wall locker"
	icon_state = "sci"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/science, 32)

/obj/structure/closet/wall/science/robotics
	name = "roboticist's wall locker"
	icon_door = "robo"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/science/robotics, 32)

/obj/structure/closet/wall/security
	name = "security officer's wall locker"
	icon_state = "sec"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/security, 32)

/obj/structure/closet/wall/cargo
	name = "cargo technician's wall locker"
	icon_state = "cargo"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/cargo, 32)

/obj/structure/closet/wall/cargo/mining
	name = "miner's wall locker"
	icon_door = "miner"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/cargo/mining, 32)

/obj/structure/closet/wall/botany
	name = "botanist's wall locker"
	icon_door = "hydro"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/botany, 32)

/obj/structure/closet/wall/janitor
	name = "janitor's wall locker"
	icon_door = "jani"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/janitor, 32)

/obj/structure/closet/wall/emergency
	name = "emergency wall locker"
	icon_state = "emergency"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/emergency, 32)

/obj/structure/closet/wall/emergency/PopulateContents()
	..()

	if (prob(40))
		new /obj/item/storage/toolbox/emergency(src)

	switch (pick_weight(list("small" = 20, "aid" = 20, "tank" = 20, "both" = 30, "nothing" = 10)))
		if ("small")
			new /obj/item/tank/internals/emergency_oxygen(src)
			new /obj/item/tank/internals/emergency_oxygen(src)
			new /obj/item/clothing/mask/breath(src)
			new /obj/item/clothing/mask/breath(src)

		if ("aid")
			new /obj/item/tank/internals/emergency_oxygen(src)
			new /obj/item/storage/medkit/emergency(src)
			new /obj/item/clothing/mask/breath(src)

		if ("tank")
			new /obj/item/tank/internals/oxygen(src)
			new /obj/item/clothing/mask/breath(src)

		if ("both")
			new /obj/item/tank/internals/emergency_oxygen(src)
			new /obj/item/clothing/mask/breath(src)

		if ("nothing")
			pass()

/obj/structure/closet/wall/nanotrasen
	name = "nanotrasen's wall locker"
	icon_state = "nanotrasen"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/nanotrasen, 32)

/obj/structure/closet/wall/syndicate
	name = "syndicate's wall locker"
	icon_state = "syndicate"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/syndicate, 32)
