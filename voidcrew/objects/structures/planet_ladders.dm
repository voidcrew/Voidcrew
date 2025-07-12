// Used to get to different z levels on planets
// generated during procgen
/obj/structure/ladder/cave
	icon = 'voidcrew/icons/obj/animal_spawner.dmi'
	icon_state = "cave_den"
	name = "deep cavern"
	desc = "A cave. Maybe it leads somewhere?"

/obj/structure/ladder/cave/Initialize(mapload)
	AddElement(/datum/element/update_icon_blocker)
	return ..()
