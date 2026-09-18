/obj/machinery/door/poddoor
	icon = 'voidcrew/icons/obj/doors/blast_door.dmi'
	animation_sound = 'voidcrew/sound/machines/doors/blast_door.ogg'

/obj/machinery/door/poddoor/shutters
	var/door_open_sound = 'voidcrew/sound/machines/doors/shutters_open.ogg'
	var/door_close_sound = 'voidcrew/sound/machines/doors/shutters_close.ogg'

/obj/machinery/door/poddoor/shutters/animation_effects(animation)
	switch(animation)
		if(DOOR_OPENING_ANIMATION)
			playsound(src, door_open_sound, 30, TRUE)
		if(DOOR_OPENING_ANIMATION)
			playsound(src, door_close_sound, 30, TRUE)
