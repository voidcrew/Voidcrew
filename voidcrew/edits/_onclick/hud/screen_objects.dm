// Voidcrew extensions to code/_onclick/hud/screen_objects.dm.

/atom/movable/screen/skills/Click()
	usr.view_skills()
	return TRUE

/atom/movable/screen/skills
	name = "view skills and experience"
	icon = 'icons/hud/screen_midnight.dmi'
	icon_state = "skills"
	mouse_over_pointer = MOUSE_HAND_POINTER
