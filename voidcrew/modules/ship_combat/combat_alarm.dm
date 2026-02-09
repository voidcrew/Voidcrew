// Combat Alarm System
// Plays a looping alarm to all mobs on a ship when weapons are locked on them

/// Combat alarm manager for a ship
/datum/combat_alarm
	/// The ship this alarm belongs to
	var/obj/structure/overmap/ship/linked_ship
	/// The sound channel used for the alarm (each mob gets this channel)
	var/sound_channel
	/// Whether the alarm is currently playing
	var/playing = FALSE
	/// List of mobs currently hearing the alarm
	var/list/mob/listeners = list()
	/// Timer for the sound loop
	var/sound_timer

/datum/combat_alarm/New(obj/structure/overmap/ship/ship)
	linked_ship = ship
	sound_channel = SSsounds.random_available_channel()
	RegisterSignal(linked_ship, COMSIG_QDELETING, PROC_REF(on_ship_deleted))

/datum/combat_alarm/Destroy()
	stop()
	if(linked_ship)
		UnregisterSignal(linked_ship, COMSIG_QDELETING)
	linked_ship = null
	return ..()

/datum/combat_alarm/proc/on_ship_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/// Starts the combat alarm
/datum/combat_alarm/proc/start()
	if(playing)
		return
	playing = TRUE

	// Play immediately, then loop
	play_sound_loop()

/// Stops the combat alarm
/datum/combat_alarm/proc/stop()
	if(!playing)
		return
	playing = FALSE

	// Stop the sound timer
	if(sound_timer)
		deltimer(sound_timer)
		sound_timer = null

	// Stop sound for all listeners
	for(var/mob/listener in listeners)
		stop_for_listener(listener)
		UnregisterSignal(listener, COMSIG_QDELETING)

	listeners.Cut()

/// Plays the alarm sound to all mobs on the ship and schedules the next play
/datum/combat_alarm/proc/play_sound_loop()
	sound_timer = null

	if(!playing || !linked_ship?.shuttle?.shuttle_areas)
		stop()
		return

	// Track which mobs are currently in ship areas
	var/list/mobs_in_ship = list()

	// Find and play to all mobs with clients in the ship's areas (living and ghosts)
	for(var/area/ship_area as anything in linked_ship.shuttle.shuttle_areas)
		for(var/mob/M in ship_area)
			if(!M.client)
				continue
			// Only living mobs and ghosts
			if(!isliving(M) && !isobserver(M))
				continue
			mobs_in_ship += M

			// Add to listeners if new
			if(!(M in listeners))
				listeners += M
				RegisterSignal(M, COMSIG_QDELETING, PROC_REF(on_listener_deleted))

			// Skip deaf living mobs for sound
			if(isliving(M) && HAS_TRAIT(M, TRAIT_DEAF))
				continue

			// Play directly to mob
			var/sound/alarm_sound = sound('voidcrew/sound/combatalarm.ogg')
			alarm_sound.channel = sound_channel
			alarm_sound.volume = 50
			alarm_sound.environment = SOUND_ENVIRONMENT_NONE
			SEND_SOUND(M, alarm_sound)

	// Stop sound for mobs who left the ship
	var/list/mobs_to_remove = listeners - mobs_in_ship
	for(var/mob/M in mobs_to_remove)
		stop_for_listener(M)
		UnregisterSignal(M, COMSIG_QDELETING)
		listeners -= M

	// Schedule next play - use the sound file length for seamless looping
	// combatalarm.ogg should be checked for its actual length, using 2 seconds as default
	sound_timer = addtimer(CALLBACK(src, PROC_REF(play_sound_loop)), 2 SECONDS, TIMER_STOPPABLE)

/// Stops the alarm sound for a specific listener
/datum/combat_alarm/proc/stop_for_listener(mob/listener)
	if(!listener?.client)
		return
	listener.stop_sound_channel(sound_channel)

/datum/combat_alarm/proc/on_listener_deleted(mob/source)
	SIGNAL_HANDLER
	listeners -= source
