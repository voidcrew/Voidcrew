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
 * The colour is still one global, GLOB.starlight_color and the shared space overlays
 * move for the whole sector on every step. What is scoped is the per-turf relight:
 * TG's map is one station z, but this fork runs dozens of space z-levels, and relighting
 * every starlight turf on all of them per colour step floods SSlighting for the whole
 * event. Each sweep therefore only relights z-stacks that currently hold a player, and
 * the fade-out ends with one flat restore over every z the event ever tinted.
 *
 * Dropped from the original: the kitchen. TG's version has a 1% chance to ignite an oven
 * in `/area/station/service/kitchen` and make the cook scream about a ruined roast. There
 * is no station kitchen area here, and chasing the gag onto ship galleys would mean
 * setting a random crew's food on fire during the harmless pretty-lights event.
 *
 * DISABLED. Kept in the tree for the starlight-fade machinery, but no longer rolls
 * in the event rotation (weight 0, max_occurrences 0); admins can still force it.
 */
/datum/round_event_control/voidcrew/aurora_caelus
	name = "Aurora Caelus"
	typepath = /datum/round_event/voidcrew/aurora_caelus
	weight = 0
	max_occurrences = 0
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
	/// Every z-level a sweep has actually tinted; the fade-out's final restore
	/// covers these even after their crews have flown elsewhere.
	var/list/tinted_zs = list()

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
	// Range/power ride along so a z-stack first watched mid-event comes up at full
	// aurora brightness, not just the colour; already-boosted turfs no-op on them.
	sweep_starlight(
		hsl_gradient((activeFor - start_when) / (end_when - start_when), 0, "#A2FF80", 1, "#A2FFEE"),
		GLOB.starlight_range * 1.75,
		GLOB.starlight_power * 0.6,
	)

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
		sweep_starlight(
			hsl_gradient(i / 5, 0, start_color, 1, end_color),
			LERP(start_range, end_range, i / 5),
			LERP(start_power, end_power, i / 5),
		)
		sleep(2 SECONDS)

	if(fade_in)
		return
	// Crews can fly off a tinted z-level mid-event, taking it out of every later
	// sweep while its turfs still hold some step of the gradient. One flat restore
	// over everything ever tinted trues the sector back up.
	set_starlight(end_color, end_range, end_power, tinted_zs)

/// Z-stacks with at least one player in them. The only turfs whose relight anyone can see.
/datum/round_event/voidcrew/aurora_caelus/proc/get_watched_zs()
	var/list/watched = list()
	for(var/mob/watcher as anything in GLOB.player_list)
		var/turf/watched_turf = get_turf(watcher)
		if(!watched_turf)
			continue
		if(watched_turf.z in watched)
			continue
		watched |= SSmapping.get_connected_levels(watched_turf) || list(watched_turf.z)
	return watched

/// One aurora colour step: pays the per-turf relight only on watched z-stacks, and
/// remembers every z it has tinted so the fade-out can restore them all.
/datum/round_event/voidcrew/aurora_caelus/proc/sweep_starlight(star_color, range, power)
	var/list/watched = get_watched_zs()
	tinted_zs |= watched
	set_starlight(star_color, range, power, watched)
