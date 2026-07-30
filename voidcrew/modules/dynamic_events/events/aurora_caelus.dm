/**
 * Ship-scoped-in-name-only port of TG's Aurora Caelus (code/modules/events/aurora_caelus.dm).
 *
 * This is the one ported event that is deliberately galaxy-scoped. The whole thing is
 * starlight: TG walks GLOB.starlight_color through a green-to-cyan gradient and every lit
 * space tile follows. There is exactly one starlight colour in the game and every ship in
 * the sector is lit by it, so there is no version of this that happens to one crew and not
 * another. Rather than fake it with a per-ship overlay, it is honest about being weather:
 * a cloud drifts through the sector and everyone gets the show.
 *
 * Dropped from the original: the kitchen. TG's version has a 1% chance to ignite an oven
 * in `/area/station/service/kitchen` and make the cook scream about a ruined roast. There
 * is no station kitchen area here, and chasing the gag onto ship galleys would mean
 * setting a random crew's food on fire during the harmless pretty-lights event.
 */
/datum/round_event_control/voidcrew/aurora_caelus
	name = "Aurora Caelus"
	typepath = /datum/round_event/voidcrew/aurora_caelus
	weight = 2
	max_occurrences = 1
	earliest_start = 15 MINUTES
	event_scope = EVENT_SCOPE_GALAXY
	category = EVENT_CATEGORY_FRIENDLY
	description = "A harmless ion cloud lights the sector green for a few minutes."

/datum/round_event_control/voidcrew/aurora_caelus/can_spawn_event(players_amt, allow_magic = FALSE)
	. = ..()
	if(!.)
		return FALSE
	// Nothing to light if the round has no open space in it.
	return !!SSmapping.empty_space

/datum/round_event/voidcrew/aurora_caelus
	announce_when = 1
	start_when = 21
	end_when = 80

/datum/round_event/voidcrew/aurora_caelus/announce(fake)
	priority_announce(
		"A harmless cloud of ions is drifting through the sector and will spend the next several minutes battering everyone's hull to no particular effect. \
		Starlight will be bright but gentle, shifting between quiet green and blue. Crews who would like to watch may proceed to the nearest viewport. \
		There is nothing to do about this and nothing that needs doing. Enjoy the lights.",
		"Sector Meteorology",
		sound = 'sound/announcer/notice/notice2.ogg',
		sender_override = "Sector Meteorology Division",
	)
	if(fake)
		return

	for(var/mob/watcher as anything in GLOB.player_list)
		var/pref_volume = watcher.client?.prefs?.read_preference(/datum/preference/numeric/volume/sound_midi)
		if(pref_volume > 0)
			watcher.playsound_local(watcher, 'sound/ambience/aurora_caelus/aurora_caelus.ogg', 20 * (pref_volume / 100), FALSE, pressure_affected = FALSE)
	fade_starlight(fade_in = TRUE)

/datum/round_event/voidcrew/aurora_caelus/tick()
	if(activeFor % 8)
		return
	set_starlight(hsl_gradient((activeFor - start_when) / (end_when - start_when), 0, "#A2FF80", 1, "#A2FFEE"))

/datum/round_event/voidcrew/aurora_caelus/end()
	fade_starlight()
	priority_announce(
		"The aurora is passing out of the sector and starlight will return to normal over the next few minutes. Thank you for watching with us.",
		"Sector Meteorology",
		sound = 'sound/announcer/notice/notice2.ogg',
		sender_override = "Sector Meteorology Division",
	)

/**
 * Walks starlight colour, range and power between normal and aurora values over five
 * steps. Straight copy-adapt of TG's fade_space(), which is not reusable directly because
 * it is defined on the upstream event datum.
 */
/datum/round_event/voidcrew/aurora_caelus/proc/fade_starlight(fade_in = FALSE)
	set waitfor = FALSE

	var/start_color = hsl_gradient(1, 0, "#A2FF80", 1, "#A2FFEE")
	var/start_range = GLOB.starlight_range * 1.75
	var/start_power = GLOB.starlight_power * 0.6
	var/end_color = GLOB.base_starlight_color
	var/end_range = GLOB.starlight_range
	var/end_power = GLOB.starlight_power
	if(fade_in)
		end_color = hsl_gradient(0, 0, "#A2FF80", 1, "#A2FFEE")
		end_range = start_range
		end_power = start_power
		start_color = GLOB.base_starlight_color
		start_range = GLOB.starlight_range
		start_power = GLOB.starlight_power

	for(var/i in 1 to 5)
		set_starlight(
			hsl_gradient(i / 5, 0, start_color, 1, end_color),
			LERP(start_range, end_range, i / 5),
			LERP(start_power, end_power, i / 5),
		)
		sleep(2 SECONDS)
