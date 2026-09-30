/atom/MouseExited(location, control, params)
	var/client/hovering_client = usr?.client
	if(!hovering_client)
		return
	// The pointer can leave before the deferred MouseEntered has been processed.
	if(SSmouse_entered.hovers[hovering_client] == src)
		SSmouse_entered.hovers[hovering_client] = null
	hovering_client.mob?.hud_used?.screentip_text?.clear_hover(src)
