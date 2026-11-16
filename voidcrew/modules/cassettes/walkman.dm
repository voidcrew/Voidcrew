/// A personal cassette player. Only the person carrying it hears it.
/obj/item/walkman
	name = "walkman"
	desc = "A portable cassette player. Somehow these never went out of style."
	icon = 'voidcrew/modules/cassettes/icons/walkman.dmi'
	icon_state = "walkman"
	inhand_icon_state = "analyzer"
	lefthand_file = 'icons/mob/inhands/equipment/tools_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/tools_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	force = 2
	throwforce = 2
	drop_sound = 'sound/items/handling/taperecorder_drop.ogg'
	pickup_sound = 'sound/items/handling/taperecorder_pickup.ogg'
	/// The tape inside.
	var/obj/item/cassette_tape/tape
	/// Whether music is running.
	var/playing = FALSE
	/// Position on the tape's current side.
	var/track_index = 1
	/// The mob hearing it. Set when someone presses play.
	var/mob/listener
	/// The listener's client when play was pressed, so a ghosting player can still be silenced.
	var/client/listener_client
	/// The sound sent to the listener for the current track.
	var/sound/current_sound
	/// Walkman volume, 0 to 100. Scaled by the listener's jukebox volume preference.
	var/volume = 50
	/// Body colour overlay, 1 to 5.
	var/design = 1
	/// Timer that moves to the next track when this one ends.
	var/advance_timer
	/// Time left on the current track when it was paused.
	var/time_left_paused = 0
	COOLDOWN_DECLARE(skip_cooldown)

/obj/item/walkman/Initialize(mapload)
	. = ..()
	design = rand(1, 5)
	register_context()
	update_appearance()

/obj/item/walkman/Destroy()
	stop_music()
	QDEL_NULL(tape)
	return ..()

/obj/item/walkman/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone != tape)
		return
	stop_music()
	tape = null
	track_index = 1
	update_appearance()

/obj/item/walkman/update_overlays()
	. = ..()
	. += "+[design]"
	if(!tape)
		. += "+empty"
	else if(playing)
		. += "+playing"

/obj/item/walkman/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(istype(held_item, /obj/item/cassette_tape))
		if(!tape)
			context[SCREENTIP_CONTEXT_LMB] = "Insert tape"
		return CONTEXTUAL_SCREENTIP_SET
	if(held_item == src)
		context[SCREENTIP_CONTEXT_LMB] = playing ? "Pause" : "Play"
		context[SCREENTIP_CONTEXT_RMB] = "Volume"
	if(tape)
		context[SCREENTIP_CONTEXT_CTRL_LMB] = "Next track"
		context[SCREENTIP_CONTEXT_ALT_LMB] = "Eject tape"
	return CONTEXTUAL_SCREENTIP_SET

/obj/item/walkman/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/cassette_tape))
		return NONE
	if(tape)
		balloon_alert(user, "already has a tape!")
		return ITEM_INTERACT_BLOCKING
	if(!user.transferItemToLoc(tool, src))
		return ITEM_INTERACT_BLOCKING
	tape = tool
	track_index = 1
	playsound(src, 'sound/items/taperecorder/taperecorder_close.ogg', 40, FALSE)
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/item/walkman/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	playsound(src, 'sound/machines/click.ogg', 20, TRUE)
	if(!tape)
		balloon_alert(user, "no tape")
		return TRUE
	if(playing)
		pause_music()
	else if(!start_music(user))
		balloon_alert(user, "it's blank")
	return TRUE

/obj/item/walkman/attack_self_secondary(mob/user, modifiers)
	. = ..()
	if(.)
		return
	INVOKE_ASYNC(src, PROC_REF(ask_volume), user)
	return TRUE

/obj/item/walkman/proc/ask_volume(mob/user)
	var/new_volume = tgui_input_number(user, "Volume", name, volume, 100, 0)
	if(isnull(new_volume) || QDELETED(src) || !user.can_perform_action(src, FORBID_TELEKINESIS_REACH))
		return
	volume = clamp(round(new_volume), 0, 100)
	refresh_sound()

/obj/item/walkman/click_alt(mob/user)
	if(!tape)
		return NONE
	var/obj/item/cassette_tape/ejected = tape
	playsound(src, 'sound/items/taperecorder/taperecorder_open.ogg', 40, FALSE)
	ejected.forceMove(drop_location()) // Exited() clears the tape and stops the music
	user.put_in_hands(ejected)
	return CLICK_ACTION_SUCCESS

/obj/item/walkman/item_ctrl_click(mob/user)
	if(!tape)
		return NONE
	if(!COOLDOWN_FINISHED(src, skip_cooldown))
		return CLICK_ACTION_BLOCKING
	COOLDOWN_START(src, skip_cooldown, 2 SECONDS)
	playsound(src, 'sound/machines/click.ogg', 20, TRUE)
	var/list/side = tape.current_side()
	if(!length(side))
		balloon_alert(user, "it's blank")
		return CLICK_ACTION_BLOCKING
	track_index = track_index >= length(side) ? 1 : track_index + 1
	if(playing)
		play_track()
	else if(current_sound)
		// Skipped while paused: the next press of play starts the new track from the top.
		silence_listener()
		current_sound = null
		time_left_paused = 0
	return CLICK_ACTION_SUCCESS

/// Starts or resumes the tape for `user`. FALSE if there's nothing to play.
/obj/item/walkman/proc/start_music(mob/user)
	var/list/side = tape?.current_side()
	if(!length(side) || !ismob(user))
		return FALSE
	if(listener != user)
		// Someone else pressed play; the old listener stops hearing it.
		stop_music()
		set_listener(user)
	if(current_sound)
		// Paused mid-song: carry on from there.
		playing = TRUE
		refresh_sound()
		if(time_left_paused > 0)
			advance_timer = addtimer(CALLBACK(src, PROC_REF(track_ended)), time_left_paused, TIMER_STOPPABLE | TIMER_DELETE_ME)
		time_left_paused = 0
		update_appearance()
		return TRUE
	return play_track()

/// Plays the track at track_index from the start.
/obj/item/walkman/proc/play_track()
	var/list/side = tape?.current_side()
	if(!length(side) || !listener)
		return FALSE
	if(track_index > length(side))
		track_index = 1
	var/datum/track/track = side[track_index]
	deltimer(advance_timer)
	advance_timer = null
	time_left_paused = 0
	current_sound = sound(track.song_path)
	current_sound.channel = CHANNEL_WALKMAN
	current_sound.priority = 255
	current_sound.status = SOUND_STREAM
	playing = TRUE
	refresh_sound(first_send = TRUE)
	if(track.song_length > 0)
		advance_timer = addtimer(CALLBACK(src, PROC_REF(track_ended)), track.song_length, TIMER_STOPPABLE | TIMER_DELETE_ME)
	update_appearance()
	return TRUE

/// The song ran out. Moves to the next one, or stops at the end of the side.
/obj/item/walkman/proc/track_ended()
	advance_timer = null
	var/list/side = tape?.current_side()
	if(!playing || !length(side))
		return
	if(track_index >= length(side))
		track_index = 1
		stop_music()
		return
	track_index++
	play_track()

/obj/item/walkman/proc/pause_music()
	if(!playing)
		return
	playing = FALSE
	time_left_paused = advance_timer ? timeleft(advance_timer) : 0
	deltimer(advance_timer)
	advance_timer = null
	refresh_sound()
	update_appearance()

/// Silences the listener and forgets them. The tape stays where it is, at the current track.
/obj/item/walkman/proc/stop_music()
	deltimer(advance_timer)
	advance_timer = null
	time_left_paused = 0
	playing = FALSE
	current_sound = null
	silence_listener()
	if(listener)
		clear_listener()
	if(!QDELETED(src))
		update_appearance()

/obj/item/walkman/proc/silence_listener()
	var/sound/silence = sound(null, channel = CHANNEL_WALKMAN)
	if(listener_client)
		SEND_SOUND(listener_client, silence)
	if(listener?.client && listener.client != listener_client)
		SEND_SOUND(listener, silence)

/// Sends the current track's state (volume, paused, muted) to the listener.
/obj/item/walkman/proc/refresh_sound(first_send = FALSE)
	if(!listener || !current_sound)
		return
	var/pref_volume = listener.client?.prefs?.read_preference(/datum/preference/numeric/volume/sound_jukebox)
	if(isnull(pref_volume))
		pref_volume = 100
	current_sound.volume = volume * (pref_volume / 100)
	var/status = first_send ? SOUND_STREAM : (SOUND_STREAM | SOUND_UPDATE)
	if(!playing)
		status |= SOUND_PAUSED
	if(HAS_TRAIT(listener, TRAIT_DEAF) || !pref_volume || !volume)
		status |= SOUND_MUTE
	current_sound.status = status
	var/hearer = listener_client || listener
	SEND_SOUND(hearer, current_sound)

/obj/item/walkman/proc/set_listener(mob/user)
	listener = user
	listener_client = user.client
	RegisterSignals(listener, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH, COMSIG_MOB_LOGOUT), PROC_REF(on_listener_gone))
	RegisterSignals(listener, list(SIGNAL_ADDTRAIT(TRAIT_DEAF), SIGNAL_REMOVETRAIT(TRAIT_DEAF), COMSIG_MOB_JUKEBOX_PREFERENCE_APPLIED), PROC_REF(on_listener_hearing_changed))
	START_PROCESSING(SSobj, src)

/obj/item/walkman/proc/clear_listener()
	UnregisterSignal(listener, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH, COMSIG_MOB_LOGOUT, SIGNAL_ADDTRAIT(TRAIT_DEAF), SIGNAL_REMOVETRAIT(TRAIT_DEAF), COMSIG_MOB_JUKEBOX_PREFERENCE_APPLIED))
	listener = null
	listener_client = null
	STOP_PROCESSING(SSobj, src)

/obj/item/walkman/proc/on_listener_gone(datum/source)
	SIGNAL_HANDLER
	stop_music()

/obj/item/walkman/proc/on_listener_hearing_changed(datum/source)
	SIGNAL_HANDLER
	refresh_sound()

/// Stops the music once the walkman isn't on the listener any more (dropped, handed over, left in a bag on the floor).
/obj/item/walkman/process(seconds_per_tick)
	if(!listener)
		return PROCESS_KILL
	if(get(src, /mob) != listener || listener.stat == DEAD)
		stop_music()
