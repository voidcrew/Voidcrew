// Real-time positional sound system
// Unlike looping_sound, this updates directional audio as listeners move
// Supports deaf traits and ambience volume preferences

/// A sound that updates its position in real-time as listeners move
/datum/realtime_positional_sound
	/// The sound file to play
	var/sound_file
	/// The atom this sound originates from
	var/atom/source
	/// Base volume of the sound (0-100), scaled by player preference
	var/volume = 50
	/// How far the sound can be heard (in tiles)
	var/range = 7
	/// The sound channel we're using
	var/sound_channel
	/// List of mobs currently listening and their status flags
	var/list/listeners = list()
	/// The active sound datum
	var/sound/active_sound
	/// Whether the sound is currently playing
	var/playing = FALSE
	/// Timer for periodic listener refresh (catches ghosts, new mobs entering range, etc.)
	var/refresh_timer

/datum/realtime_positional_sound/New(atom/sound_source, sound_path, vol = 50, hear_range = 7)
	source = sound_source
	sound_file = sound_path
	volume = vol
	range = hear_range
	sound_channel = SSsounds.random_available_channel()

	RegisterSignal(source, COMSIG_QDELETING, PROC_REF(on_source_deleted))

/datum/realtime_positional_sound/Destroy()
	stop()
	if(source)
		UnregisterSignal(source, COMSIG_QDELETING)
	source = null
	return ..()

/datum/realtime_positional_sound/proc/on_source_deleted(datum/src_datum)
	SIGNAL_HANDLER
	qdel(src)

/// Starts playing the sound
/datum/realtime_positional_sound/proc/start()
	if(playing)
		return
	playing = TRUE

	// Create the base sound
	active_sound = sound(sound_file)
	active_sound.channel = sound_channel
	active_sound.repeat = TRUE
	active_sound.volume = volume
	active_sound.falloff = 1
	active_sound.environment = SOUND_ENVIRONMENT_NONE

	// Find and register all listeners in range
	refresh_listeners()

	// Register for source movement to update all listeners
	RegisterSignal(source, COMSIG_MOVABLE_MOVED, PROC_REF(on_source_moved))

	// Start periodic refresh to catch ghosts, new mobs entering range, etc.
	refresh_timer = addtimer(CALLBACK(src, PROC_REF(periodic_refresh)), 2 SECONDS, TIMER_STOPPABLE | TIMER_LOOP)

/// Stops the sound completely
/datum/realtime_positional_sound/proc/stop()
	if(!playing)
		return
	playing = FALSE

	// Stop the periodic refresh timer
	if(refresh_timer)
		deltimer(refresh_timer)
		refresh_timer = null

	UnregisterSignal(source, COMSIG_MOVABLE_MOVED)

	// Stop sound for all tracked listeners and unregister signals
	for(var/mob/listener in listeners)
		stop_for_listener(listener)
		UnregisterSignal(listener, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING, COMSIG_MOB_LOGIN, COMSIG_MOB_LOGOUT, COMSIG_LIVING_DEATH, SIGNAL_ADDTRAIT(TRAIT_DEAF), SIGNAL_REMOVETRAIT(TRAIT_DEAF)))

	// Also stop for any mob in range that might not be in our listeners list
	// This catches edge cases like mobs that entered range but weren't registered yet
	if(source)
		for(var/mob/M in range(range, source))
			if(M?.client && !(M in listeners))
				M.stop_sound_channel(sound_channel)

	listeners.Cut()
	active_sound = null

/// Refreshes the listener list - call periodically or when players might enter/leave range
/datum/realtime_positional_sound/proc/refresh_listeners()
	if(!playing || !source)
		return

	var/turf/source_turf = get_turf(source)
	if(!source_turf)
		return

	// Find all mobs in range (both living and observers/ghosts)
	for(var/mob/M in range(range, source))
		if(!M.client)
			continue
		// Only living mobs and observers (ghosts)
		if(!isliving(M) && !isobserver(M))
			continue
		if(M in listeners)
			continue
		register_listener(M)

	// Also check for listeners who left range or lost their client
	for(var/mob/listener in listeners)
		// If listener lost their client (e.g., they ghosted), stop sound and deregister
		if(!listener.client)
			deregister_listener(listener)
			continue
		var/turf/listener_turf = get_turf(listener)
		if(!listener_turf || get_dist(source_turf, listener_turf) > range)
			deregister_listener(listener)

/// Called periodically to catch new mobs entering range (ghosts, teleports, etc.)
/datum/realtime_positional_sound/proc/periodic_refresh()
	refresh_listeners()

/// Registers a new listener
/datum/realtime_positional_sound/proc/register_listener(mob/listener)
	if(listener in listeners)
		return

	// Don't register if sound isn't playing
	if(!playing)
		return

	// If no client yet, wait for login
	if(!listener?.client)
		RegisterSignal(listener, COMSIG_MOB_LOGIN, PROC_REF(on_listener_login), override = TRUE)
		return

	listeners[listener] = NONE

	RegisterSignal(listener, COMSIG_MOVABLE_MOVED, PROC_REF(on_listener_moved), override = TRUE)
	RegisterSignal(listener, COMSIG_QDELETING, PROC_REF(on_listener_deleted), override = TRUE)
	RegisterSignal(listener, COMSIG_MOB_LOGIN, PROC_REF(on_listener_login), override = TRUE)
	RegisterSignal(listener, COMSIG_MOB_LOGOUT, PROC_REF(on_listener_logout), override = TRUE)
	// Only register death signal for living mobs
	if(isliving(listener))
		RegisterSignal(listener, COMSIG_LIVING_DEATH, PROC_REF(on_listener_died), override = TRUE)
		RegisterSignals(listener, list(SIGNAL_ADDTRAIT(TRAIT_DEAF), SIGNAL_REMOVETRAIT(TRAIT_DEAF)), PROC_REF(on_listener_deaf_changed), override = TRUE)

	// Check if listener is deaf or has ship ambience muted
	var/pref_volume = listener.client?.prefs.read_preference(/datum/preference/numeric/volume/sound_ship_ambience_volume)
	if(HAS_TRAIT(listener, TRAIT_DEAF) || !pref_volume)
		listeners[listener] |= SOUND_MUTE

	// Play the sound for this listener (first time, no SOUND_UPDATE)
	update_listener(listener, first_play = TRUE)

	// After first play, add SOUND_UPDATE flag for future updates
	listeners[listener] |= SOUND_UPDATE

/// Deregisters a listener
/datum/realtime_positional_sound/proc/deregister_listener(mob/listener)
	if(!(listener in listeners))
		return

	stop_for_listener(listener)
	UnregisterSignal(listener, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING, COMSIG_MOB_LOGIN, COMSIG_MOB_LOGOUT, COMSIG_LIVING_DEATH, SIGNAL_ADDTRAIT(TRAIT_DEAF), SIGNAL_REMOVETRAIT(TRAIT_DEAF)))
	listeners -= listener

/// Stops the sound for a specific listener
/datum/realtime_positional_sound/proc/stop_for_listener(mob/listener)
	if(!listener?.client)
		return
	listener.stop_sound_channel(sound_channel)

/// Updates the sound position for a listener
/datum/realtime_positional_sound/proc/update_listener(mob/listener, first_play = FALSE)
	if(!playing || !listener?.client || !active_sound || !source)
		return

	var/turf/source_turf = get_turf(source)
	var/turf/listener_turf = get_turf(listener)

	if(!source_turf || !listener_turf)
		return

	// Get listener's status flags (includes SOUND_MUTE if deaf)
	var/status_flags = listeners[listener] & ~SOUND_UPDATE
	if(!first_play)
		status_flags |= SOUND_UPDATE

	// Different z-levels - mute
	if(source_turf.z != listener_turf.z)
		active_sound.status = SOUND_MUTE | status_flags
		SEND_SOUND(listener, active_sound)
		return

	// Calculate relative position (sound x/z = world x/y)
	var/rel_x = source_turf.x - listener_turf.x
	var/rel_z = source_turf.y - listener_turf.y

	// Out of range - mute
	if(abs(rel_x) > range || abs(rel_z) > range)
		active_sound.status = SOUND_MUTE | status_flags
		SEND_SOUND(listener, active_sound)
		return

	// Update position
	active_sound.x = rel_x
	active_sound.z = rel_z
	active_sound.y = 0
	active_sound.status = status_flags

	// Apply volume preference
	var/pref_volume = listener.client?.prefs.read_preference(/datum/preference/numeric/volume/sound_ship_ambience_volume)
	active_sound.volume = volume * (pref_volume / 100)

	SEND_SOUND(listener, active_sound)

/// Called when a listener moves
/datum/realtime_positional_sound/proc/on_listener_moved(mob/listener)
	SIGNAL_HANDLER
	update_listener(listener)

/// Called when the sound source moves
/datum/realtime_positional_sound/proc/on_source_moved(atom/movable/mover)
	SIGNAL_HANDLER
	// Update all listeners
	for(var/mob/listener in listeners)
		update_listener(listener)
	// Also check for new listeners
	refresh_listeners()

/// Called when a listener is deleted
/datum/realtime_positional_sound/proc/on_listener_deleted(mob/listener)
	SIGNAL_HANDLER
	listeners -= listener

/// Called when a listener dies - stop the sound for them
/datum/realtime_positional_sound/proc/on_listener_died(mob/listener)
	SIGNAL_HANDLER
	deregister_listener(listener)

/// Called when a listener's deaf status changes
/datum/realtime_positional_sound/proc/on_listener_deaf_changed(mob/listener)
	SIGNAL_HANDLER
	if(!(listener in listeners))
		return

	if(HAS_TRAIT(listener, TRAIT_DEAF))
		listeners[listener] |= SOUND_MUTE
	else
		listeners[listener] &= ~SOUND_MUTE

	update_listener(listener)

/// Called when a listener logs in (reconnects) - re-register them to refresh sound state
/datum/realtime_positional_sound/proc/on_listener_login(mob/listener)
	SIGNAL_HANDLER
	// Remove and re-add to refresh their sound state with new client
	listeners -= listener
	UnregisterSignal(listener, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING, COMSIG_MOB_LOGIN, COMSIG_MOB_LOGOUT, COMSIG_LIVING_DEATH, SIGNAL_ADDTRAIT(TRAIT_DEAF), SIGNAL_REMOVETRAIT(TRAIT_DEAF)))
	register_listener(listener)

/// Called when a listener logs out (e.g., ghosting or disconnecting) - stop the sound but keep them registered for login
/datum/realtime_positional_sound/proc/on_listener_logout(mob/listener)
	SIGNAL_HANDLER
	// Stop the sound for them - client might still exist at this point during Logout()
	// We need to stop it NOW before the client is nulled
	if(listener?.client)
		listener.stop_sound_channel(sound_channel)
	// Mute them while disconnected but keep them registered so we can restart on reconnect
	if(listener in listeners)
		listeners[listener] |= SOUND_MUTE
