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
	for(var/name in list("frame_9slice.png", "strip_top.png", "char_floor.png"))
		if(fexists("[art_dir][name]"))
			assets[name] = "[art_dir][name]"
	// Key clicks the page plays itself when the focus moves or a key is pressed (nav.tsx).
	var/list/sounds = list(
		"lt_key1.ogg" = "sound/machines/terminal/terminal_button01.ogg",
		"lt_key2.ogg" = "sound/machines/terminal/terminal_button03.ogg",
		"lt_key3.ogg" = "sound/machines/terminal/terminal_button05.ogg",
		"lt_press.ogg" = "sound/machines/terminal/terminal_select.ogg",
	)
	for(var/name in sounds)
		if(fexists(sounds[name]))
			assets[name] = sounds[name]
	// The start-up screen's sounds (Boot.tsx), played by the page the same way.
	var/sound_dir = "voidcrew/modules/lobby_terminal/sound/"
	for(var/name in list("lt_boot_power.ogg", "lt_boot_seq.ogg", "lt_boot_key.ogg", "lt_boot_tick.ogg", "lt_boot_done.ogg", "lt_boot_login.ogg"))
		if(fexists("[sound_dir][name]"))
			assets[name] = "[sound_dir][name]"
	parents = list()
	if(fexists("[art_dir]lobby_terminal.css"))
		parents["lobby_terminal.css"] = "[art_dir]lobby_terminal.css"
	return ..()
