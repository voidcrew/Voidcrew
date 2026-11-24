/**
 * Terminal art, font and sounds. Runtime string paths, not 'compiled' resources, so they stay
 * out of the compiled RSC and the external RSC zip and arrive with the page.
 *
 * Only art files that exist are registered: the bezel art (html/) can be missing, and then
 * the client draws its placeholder bezel.
 */
/datum/asset/simple/namespaced/lobby_terminal

/// The terminal's own sound clips, played by the page (motion.ts, Boot.tsx).
#define LOBBY_SOUND_DIR "voidcrew/modules/lobby_terminal/sound/"

/**
 * Sounds the page plays itself, so a sound never costs a round trip: asset name = file.
 * The lt_boot_* clips are the start-up screen's; the lobby also uses its keystroke and its tick.
 */
GLOBAL_LIST_INIT(lobby_terminal_sounds, list(
	"lt_key1.ogg" = "sound/machines/terminal/terminal_button01.ogg",
	"lt_key2.ogg" = "sound/machines/terminal/terminal_button03.ogg",
	"lt_key3.ogg" = "sound/machines/terminal/terminal_button05.ogg",
	"lt_press.ogg" = "sound/machines/terminal/terminal_select.ogg",
	"lt_ok.ogg" = "sound/machines/terminal/terminal_prompt_confirm.ogg",
	"lt_warn.ogg" = "sound/machines/terminal/terminal_prompt_deny.ogg",
	"lt_bad.ogg" = "sound/machines/terminal/terminal_error.ogg",
	"lt_working.ogg" = "sound/machines/terminal/terminal_processing.ogg",
	"lt_boot_power.ogg" = LOBBY_SOUND_DIR + "lt_boot_power.ogg",
	"lt_boot_seq.ogg" = LOBBY_SOUND_DIR + "lt_boot_seq.ogg",
	"lt_boot_key.ogg" = LOBBY_SOUND_DIR + "lt_boot_key.ogg",
	"lt_boot_tick.ogg" = LOBBY_SOUND_DIR + "lt_boot_tick.ogg",
	"lt_boot_done.ogg" = LOBBY_SOUND_DIR + "lt_boot_done.ogg",
	"lt_boot_login.ogg" = LOBBY_SOUND_DIR + "lt_boot_login.ogg",
))

/**
 * Sounds that play a stand-in until their own clip is made: asset name = list(file, playback
 * rate, volume scale). The page plays a stand-in at that rate and volume (ui_static_data sends
 * them as sfx_tune). When a clip arrives, put it in the sound folder under its asset name and
 * delete its line here: it is then registered from there and plays as it is.
 */
GLOBAL_LIST_INIT(lobby_terminal_sound_stand_ins, list(
	"lt_wipe.ogg" = list("sound/machines/terminal/terminal_prompt.ogg", 1, 0.67),
	"lt_ready_on.ogg" = list("sound/machines/terminal/terminal_prompt_confirm.ogg", 1, 1),
	"lt_ready_off.ogg" = list("sound/machines/terminal/terminal_prompt_deny.ogg", 1, 1),
	"lt_stamp.ogg" = list("sound/machines/terminal/terminal_success.ogg", 1, 1),
	"lt_slot.ogg" = list("sound/machines/terminal/terminal_select.ogg", 0.8, 1),
	"lt_turn.ogg" = list(LOBBY_SOUND_DIR + "lt_boot_tick.ogg", 1.15, 0.86),
))

/// Every sound the terminal has a stand-in or a clip for, by asset name.
GLOBAL_LIST_INIT(lobby_terminal_new_sounds, list("lt_wipe.ogg", "lt_ready_on.ogg", "lt_ready_off.ogg", "lt_stamp.ogg", "lt_slot.ogg", "lt_turn.ogg"))

/datum/asset/simple/namespaced/lobby_terminal/register()
	var/art_dir = "voidcrew/modules/lobby_terminal/html/"
	assets = list()
	if(fexists("interface/fonts/VCR_OSD_Mono.ttf"))
		assets["VCR_OSD_Mono.ttf"] = "interface/fonts/VCR_OSD_Mono.ttf"
	for(var/name in list("frame_9slice.png", "strip_top.png", "char_floor.png"))
		if(fexists("[art_dir][name]"))
			assets[name] = "[art_dir][name]"
	for(var/name in GLOB.lobby_terminal_sounds)
		var/path = GLOB.lobby_terminal_sounds[name]
		if(fexists(path))
			assets[name] = path
	for(var/name in GLOB.lobby_terminal_new_sounds)
		var/list/stand_in = GLOB.lobby_terminal_sound_stand_ins[name]
		var/path = stand_in ? stand_in[1] : "[LOBBY_SOUND_DIR][name]"
		if(fexists(path))
			assets[name] = path
	parents = list()
	if(fexists("[art_dir]lobby_terminal.css"))
		parents["lobby_terminal.css"] = "[art_dir]lobby_terminal.css"
	return ..()

/// Playback rate and volume scale of every stand-in sound, by asset name, for the page.
/proc/lobby_terminal_sound_tune()
	var/list/tune = list()
	for(var/name in GLOB.lobby_terminal_sound_stand_ins)
		var/list/stand_in = GLOB.lobby_terminal_sound_stand_ins[name]
		tune[name] = list(stand_in[2], stand_in[3])
	return tune

#undef LOBBY_SOUND_DIR
