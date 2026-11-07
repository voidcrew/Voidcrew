/atom/movable/screen/screentip
	icon = null
	icon_state = null
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	screen_loc = "TOP,LEFT"
	maptext_height = 480
	maptext_width = 480
	maptext = ""
	layer = SCREENTIP_LAYER //Added to make screentips appear above action buttons (and other /atom/movable/screen objects)

/atom/movable/screen/screentip/Initialize(mapload, datum/hud/hud_owner)
	. = ..()
	update_view()
	// VOIDCREW EDIT START: Initialize the persistent hover and overmap fallback lifecycle in voidcrew/edits/_onclick/hud/screen_extensions.dm.
	update_fallback()
	START_PROCESSING(SSprocessing, src)
	if(hud?.mymob)
		RegisterSignal(hud.mymob, list(COMSIG_MOB_LOGIN, COMSIG_MOB_LOGOUT), PROC_REF(on_connection_changed))
	// VOIDCREW EDIT END


/atom/movable/screen/screentip/proc/update_view(datum/source)
	SIGNAL_HANDLER
	if(!hud || !hud.mymob.canon_client?.view_size) //Might not have been initialized by now
		return
	maptext_width = view_to_pixels(hud.mymob.canon_client.view_size.getView())[1]
