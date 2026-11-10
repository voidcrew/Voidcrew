/**
 * Terminal art and font. Runtime string paths, not 'compiled' resources, so the art stays
 * out of the compiled RSC and the external RSC zip and arrives with the page.
 *
 * Only art files that exist are registered: the bezel art (html/) can be missing, and then
 * the client draws its placeholder bezel.
 */
/datum/asset/simple/namespaced/lobby_terminal

/datum/asset/simple/namespaced/lobby_terminal/register()
	var/art_dir = "voidcrew/modules/lobby_terminal/html/"
	assets = list()
	if(fexists("interface/fonts/VCR_OSD_Mono.ttf"))
		assets["VCR_OSD_Mono.ttf"] = "interface/fonts/VCR_OSD_Mono.ttf"
	var/list/art = list("frame_9slice.png", "strip_top.png", "deck.png", "grille.png", "tray.png", "lamp_ready.png", "lamp_notready.png", "lamp_off.png")
	for(var/key in list("join", "ready", "notready", "observe", "character"))
		for(var/key_state in list("idle", "hover", "pressed", "disabled"))
			art += "key_[key]_[key_state].png"
	for(var/name in art)
		if(fexists("[art_dir][name]"))
			assets[name] = "[art_dir][name]"
	// The bezel's small buttons, cut from the real lobby sprites so a sprite change reaches the terminal too.
	for(var/button in list("wiki", "poll", "crew_manifest", "settings", "changelog"))
		for(var/suffix in list("", "_highlighted", "_disabled"))
			assets["lt_[button][suffix].png"] = icon('icons/hud/lobby/bottom_buttons.dmi', "[button][suffix]", frame = 1)
	assets["lt_new_poll.png"] = icon('icons/hud/lobby/poll_overlay.dmi', "new_poll")
	parents = list()
	if(fexists("[art_dir]lobby_terminal.css"))
		parents["lobby_terminal.css"] = "[art_dir]lobby_terminal.css"
	return ..()
