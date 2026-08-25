/***********************************************
 Diagnostic HUDs!
************************************************/

/mob/living/proc/hud_set_nanite_indicator()
	// Only mobs whose hud_possible carries DIAG_HUD (silicons, bots) have this image;
	// humans don't, and there is no nanite hud entry wired up for them
	var/image/holder = hud_list?[DIAG_HUD]
	if(!holder)
		return
	var/icon/nanite_icon = icon(icon, icon_state, dir)
	holder.pixel_y = nanite_icon.Height() - world.icon_size
	holder.icon_state = null
	if(src in SSnanites.nanite_monitored_mobs)
		holder.icon_state = "nanite_ping"
