/mob/living/silicon/Login()
	if(mind)
		mind?.remove_antags_for_borging()
	// Set voice bark from prefs
	if(!voice_bark)
		voice_bark = new()
	voice_bark.set_from_prefs(client?.prefs)
	return ..()


/mob/living/silicon/auto_deadmin_on_login()
	if(!client?.holder)
		return TRUE
	if(CONFIG_GET(flag/auto_deadmin_silicons) || (client.prefs?.toggles & DEADMIN_POSITION_SILICON))
		return client.holder.auto_deadmin()
	return ..()
