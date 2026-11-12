/**
 * # What the Sandevistan user sees and hears of the slowed world
 *
 * Only the user's own client changes; nobody else's view or speakers do.
 *
 * Sound: a sound from a tile inside the field reaches the user pitched down and slowed by the field's scale
 * (the `frequency` of the sound datum, set in playsound_local). The user's own sounds stay normal: anything
 * from their own tile, and anything their own action set off (`usr` is the user: their gun, their swings,
 * their callbacks). The weather and ship-hum loops already playing on the user's channels are slowed in place with SOUND_UPDATE, and the loop's next segments go out
 * slowed too.
 *
 * Weather: area overlays are shared by everyone on a planet, so they are left alone. Each weathered area in
 * the user's view gets one override image, shown to the user's client only: a copy of the area's appearance
 * with every weather overlay swapped for a pre-baked slowed copy from
 * sandy_weather.dmi. There is no particle weather to slow.
 */

#define SANDY_WEATHER_ICON 'voidcrew/modules/cyberware/icons/sandy_weather.dmi'
/// Tiles past the edge of the user's view that still get slowed weather, so a step never shows a fast edge.
#define SANDY_WEATHER_VIEW_MARGIN 1

/// The field `listener` is the user of, if any.
/proc/cyberware_field_of_user(mob/listener)
	for(var/datum/proximity_monitor/advanced/timestop/sandevistan/field as anything in GLOB.cyberware_time_fields)
		if(field.host == listener)
			return field

/**
 * How fast `listener` hears a sound from `source`: 1 normally, the field's pace for a sound from inside the
 * user's field. `actor` is whoever set the sound off (`usr`).
 */
/proc/cyberware_heard_speed(mob/listener, turf/source, mob/actor)
	if(!isturf(source) || actor == listener)
		return 1
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = cyberware_field_of_user(listener)
	if(!field)
		return 1
	var/turf/here = get_turf(listener)
	if(!here || source == here || source.z != here.z || get_dist(source, here) > field.current_range)
		return 1
	return field.time_scale

/// Slows `heard` for `listener` if it comes from the slowed world. Called from playsound_local.
/proc/cyberware_dilate_heard(mob/listener, turf/source, sound/heard, mob/actor)
	var/speed = cyberware_heard_speed(listener, source, actor)
	if(speed == 1)
		return
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = cyberware_field_of_user(listener)
	field?.senses?.note_one_shot(heard)
	heard.frequency = cyberware_scaled_frequency(heard.frequency, speed)

/// `frequency` (0 for as-is, a multiplier within -100..100, or a rate in Hz) played `speed` times as fast.
/proc/cyberware_scaled_frequency(frequency, speed)
	if(!frequency)
		frequency = 1
	return frequency * speed

// ----- looping sounds sent straight to a mob (weather) -----

/datum/looping_sound
	/// The last file this loop sent straight to its mob, to slow it in place.
	var/sandy_last_file
	/// The volume it went at.
	var/sandy_last_volume
	/// The channel it went on (ash storm loops take a random one).
	var/sandy_last_channel

/// The direct branch of the base play(), done here so the channel a loop took is known and the sound can
/// go out slowed to a dilation user.
/datum/looping_sound/play(soundfile, volume_override)
	if(!direct)
		return ..()
	var/sound/sound_to_play = sound(soundfile)
	sound_to_play.channel = sound_channel || SSsounds.random_available_channel()
	sound_to_play.volume = volume_override || volume //Use volume as fallback if theres no override
	sandy_last_file = soundfile
	sandy_last_volume = sound_to_play.volume
	sandy_last_channel = sound_to_play.channel
	if(length(GLOB.cyberware_time_fields) && ismob(parent))
		var/datum/proximity_monitor/advanced/timestop/sandevistan/field = cyberware_field_of_user(parent)
		if(field?.senses)
			sound_to_play.frequency = field.senses.loop_speed
	SEND_SOUND(parent, sound_to_play)

// =========================================================================
// THE USER'S SENSES
// =========================================================================

/// Lives with a dilation field and keeps its user's weather and sound loops in step with the field's pace.
/datum/sandy_senses
	/// The field whose pace this follows.
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field
	/// The user.
	var/mob/living/user
	/// The client the images are shown to.
	var/client/viewer
	/// Weathered areas in view, to the override image shown for each.
	var/list/area_images = list()
	/// Areas, to what their image was built from, to rebuild it only when that changes.
	var/list/area_keys = list()
	/// How fast the user's loops play now.
	var/loop_speed = 1
	/// Channels of world sounds sent slowed and maybe still playing, to an unslowed copy of each, to retune them.
	var/list/one_shots = list()
	/// The same channels, to when each went out.
	var/list/one_shot_times = list()

/datum/sandy_senses/New(datum/proximity_monitor/advanced/timestop/sandevistan/field)
	src.field = field
	user = field.host
	RegisterSignal(user, COMSIG_MOB_LOGOUT, PROC_REF(on_logout))
	update()

/datum/sandy_senses/Destroy()
	if(user)
		UnregisterSignal(user, COMSIG_MOB_LOGOUT)
		set_loops(1)
	clear_images()
	field = null
	user = null
	return ..()

/// The field started: bring the loops and the weather in line with its pace.
/datum/sandy_senses/proc/update()
	set_loops(field.time_scale)
	refresh_weather()

/// Signal proc for [COMSIG_MOB_LOGOUT]: the client keeps its images when it leaves, so take them back.
/datum/sandy_senses/proc/on_logout(datum/source)
	SIGNAL_HANDLER
	clear_images()

// ----- sound loops -----

/// Plays the user's weather and ship-hum loops at `speed` times normal, in place.
/datum/sandy_senses/proc/set_loops(speed)
	if(loop_speed == speed)
		return
	loop_speed = speed
	if(!user.client)
		return
	retune_one_shots(speed)
	for(var/datum/component/area_sound_manager/manager as anything in user.GetComponents(/datum/component/area_sound_manager))
		var/datum/looping_sound/loop = manager.our_loop
		if(!loop?.direct || !loop.sandy_last_channel || !loop.sandy_last_file)
			continue
		update_channel(loop.sandy_last_file, loop.sandy_last_channel, loop.sandy_last_volume, speed)
	var/buzz = user.client.current_ambient_sound
	var/area/here = get_area(user)
	if(buzz && here?.ambient_buzz == buzz)
		var/buzz_pref = user.client.prefs.read_preference(/datum/preference/numeric/volume/sound_ship_ambience_volume)
		update_channel(buzz, CHANNEL_BUZZ, here.ambient_buzz_vol * (buzz_pref / 100), speed, TRUE)

/// Notes a world sound about to go out slowed (`heard` still unslowed), to speed it back up later.
/datum/sandy_senses/proc/note_one_shot(sound/heard)
	if(!heard.channel || heard.repeat)
		return
	var/sound/copy = sound(heard.file, 0, 0, heard.channel, heard.volume)
	copy.frequency = heard.frequency
	copy.x = heard.x
	copy.y = heard.y
	copy.z = heard.z
	copy.falloff = heard.falloff
	copy.environment = heard.environment
	copy.echo = heard.echo
	one_shots["[heard.channel]"] = copy
	one_shot_times["[heard.channel]"] = world.time

/// World sounds still playing from earlier in the effect take the new pace: full speed when it ends.
/datum/sandy_senses/proc/retune_one_shots(speed)
	for(var/channel in one_shots.Copy())
		if(world.time - one_shot_times[channel] > 15 SECONDS) // long finished
			one_shots -= channel
			one_shot_times -= channel
			continue
		var/sound/copy = one_shots[channel]
		var/sound/update = sound(copy.file, 0, 0, copy.channel, copy.volume)
		update.frequency = cyberware_scaled_frequency(copy.frequency, speed) // never 0: an update with 0 keeps the old pace
		update.x = copy.x
		update.y = copy.y
		update.z = copy.z
		update.falloff = copy.falloff
		update.environment = copy.environment
		update.echo = copy.echo
		update.status = SOUND_UPDATE
		SEND_SOUND(user, update)
	if(speed == 1)
		one_shots.Cut()
		one_shot_times.Cut()

/// Changes the pace and volume of what is playing on `channel` for the user, without restarting it.
/datum/sandy_senses/proc/update_channel(file, channel, volume, speed, repeat = FALSE)
	var/sound/update = sound(file, repeat, 0, channel, volume)
	update.frequency = speed
	update.status = SOUND_UPDATE
	SEND_SOUND(user, update)

// ----- weather -----

/// Shows slowed weather over every weathered area in the user's view, and drops images for the rest.
/datum/sandy_senses/proc/refresh_weather(force = FALSE)
	var/client/now_viewer = user.client
	if(viewer && viewer != now_viewer)
		clear_images()
	viewer = now_viewer
	if(!viewer && !force)
		return
	var/tag = cyberware_weather_tag(field.time_scale)
	var/list/wanted = list()
	var/turf/centre = get_turf(user)
	if(centre)
		var/list/weathers = list()
		for(var/datum/weather/weather as anything in SSweather.processing)
			if(weather.stage != END_STAGE && length(weather.overlay_cache) && (centre.z in weather.impacted_z_levels))
				weathers += weather
		if(length(weathers))
			var/list/size = getviewsize(viewer?.view || world.view)
			var/reach_x = round(size[1] / 2) + SANDY_WEATHER_VIEW_MARGIN
			var/reach_y = round(size[2] / 2) + SANDY_WEATHER_VIEW_MARGIN
			var/list/seen = list()
			for(var/turf/spot as anything in block(max(centre.x - reach_x, 1), max(centre.y - reach_y, 1), centre.z, min(centre.x + reach_x, world.maxx), min(centre.y + reach_y, world.maxy), centre.z))
				seen[spot.loc] = TRUE
			for(var/area/place as anything in seen)
				var/list/caches = list()
				for(var/datum/weather/weather as anything in weathers)
					if(weather.impacted_areas_lookup[place])
						caches += list(weather.overlay_cache)
				if(length(caches))
					wanted[place] = caches
	for(var/area/place as anything in area_images.Copy())
		if(!wanted[place])
			drop_image(place)
	for(var/area/place as anything in wanted)
		var/list/caches = wanted[place]
		var/key = "[tag]|[length(place.overlays)]"
		for(var/list/cache as anything in caches)
			key += "|[REF(cache)]"
		if(area_keys[place] == key)
			continue
		drop_image(place)
		var/image/slowed = cyberware_slowed_weather_image(place, tag)
		area_images[place] = slowed
		area_keys[place] = key
		viewer?.images += slowed

/// Takes `place`'s image off the user's screen.
/datum/sandy_senses/proc/drop_image(area/place)
	var/image/slowed = area_images[place]
	if(slowed)
		viewer?.images -= slowed
	area_images -= place
	area_keys -= place

/// Takes every image off the user's screen: the real weather shows again.
/datum/sandy_senses/proc/clear_images()
	if(viewer)
		for(var/area/place as anything in area_images)
			viewer.images -= area_images[place]
	area_images.Cut()
	area_keys.Cut()
	viewer = null

/// The sandy_weather.dmi suffix for a field running at `scale`: the nearest baked pace.
/proc/cyberware_weather_tag(scale)
	if(scale <= 0.27)
		return "s20"
	if(scale <= 0.42)
		return "s35"
	return "s50"

/// An override image of `place` as it looks now, with its weather overlays swapped for slowed (`tag`) copies.
/proc/cyberware_slowed_weather_image(area/place, tag)
	var/static/list/baked
	if(!baked)
		baked = list()
		for(var/state in icon_states(SANDY_WEATHER_ICON))
			baked[state] = TRUE
	var/image/slowed = image(loc = place)
	slowed.appearance = place.appearance
	slowed.override = TRUE
	var/list/swapped = list()
	for(var/overlay in slowed.overlays)
		var/state
		if(overlay:icon == 'icons/effects/weather_effects.dmi')
			state = "[overlay:icon_state]_[tag]"
		else if(overlay:icon == 'icons/effects/glow_weather.dmi')
			state = "glow_[overlay:icon_state]_[tag]"
		if(!state || !baked[state])
			swapped += overlay
			continue
		var/mutable_appearance/copy = new(overlay)
		copy.icon = SANDY_WEATHER_ICON
		copy.icon_state = state
		swapped += copy
	slowed.overlays = swapped
	return slowed

#undef SANDY_WEATHER_ICON
#undef SANDY_WEATHER_VIEW_MARGIN
