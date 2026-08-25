// Clients aren't datums so we have to define these procs indpendently.
// These verbs are called for all key press and release events
GAME_VERB_HIDDEN_INSTANT(/client, keyDown, "keyDown", _key as text, mousepos_x as num, mousepos_y as num, sizex as num, sizey as num)

	client_keysend_amount += 1

	// VOIDCREW EDIT START - lag-tolerant flood detection.
	// The original was a one-second world.time window plus a single two-second "tripped"
	// confirmation, and a server-side lag spike satisfies both on its own: world.time
	// stretches while the server is behind, and the client's buffered input all flushes
	// inside the confirmation window. Round 6 (2026-08-15) autokicked ckey viterfly twice
	// in 40 seconds, at 87% and 105% tick usage - the server was the thing flooding.
	// Three changes: the window is real time so it measures an actual per-second rate, a
	// burst delivered while the server is over budget is not held against the client, and
	// a kick now needs several over-threshold seconds inside a much longer window, with a
	// warning first. Thresholds are invented, see code/__DEFINES/admin.dm.
	var/keysend_realtime = REALTIMEOFDAY

	if(keysend_strikes && next_keysend_trip_reset <= keysend_realtime)
		keysend_strikes = 0

	if(next_keysend_reset <= keysend_realtime)
		client_keysend_amount = 1 // this keypress opens the new window
		next_keysend_reset = keysend_realtime + (1 SECONDS)

	if(client_keysend_amount >= MAX_KEYPRESS_AUTOKICK)
		// Exactly one strike per window - otherwise a genuine flood would burn through
		// every strike inside a single second and we would be back to kicking on one burst.
		if(client_keysend_amount == MAX_KEYPRESS_AUTOKICK && TICK_USAGE < KEYPRESS_FLOOD_LAG_TICK_USAGE)
			keysend_strikes += 1
			next_keysend_trip_reset = keysend_realtime + KEYPRESS_FLOOD_STRIKE_MEMORY
			if(keysend_strikes == KEYPRESS_FLOOD_STRIKES_TO_WARN)
				to_chat(src, span_userdanger("You are sending keypresses much faster than a person can type. If this keeps up you will be disconnected automatically - check for a plugged-in game controller."))
		if(keysend_strikes >= KEYPRESS_FLOOD_STRIKES_TO_KICK)
			to_chat(src, span_userdanger("Flooding keysends! This could have been caused by lag, or due to a plugged-in game controller. You have been disconnected from the server automatically."))
			log_admin("Client [ckey] was just autokicked for flooding keysends; [KEYPRESS_FLOOD_STRIKES_TO_KICK] over-threshold seconds within [KEYPRESS_FLOOD_STRIKE_MEMORY / 10] seconds, none of them during server lag.")
			message_admins("Client [ckey] was just autokicked for flooding keysends; [KEYPRESS_FLOOD_STRIKES_TO_KICK] over-threshold seconds within [KEYPRESS_FLOOD_STRIKE_MEMORY / 10] seconds, none of them during server lag.")
			qdel(src)
			return
	// VOIDCREW EDIT END

	///Check if the key is short enough to even be a real key
	if(LAZYLEN(_key) > MAX_KEYPRESS_COMMANDLENGTH)
		to_chat(src, span_userdanger("Invalid KeyDown detected! You have been disconnected from the server automatically."))
		log_admin("Client [ckey] just attempted to send an invalid keypress. Keymessage was over [MAX_KEYPRESS_COMMANDLENGTH] characters, autokicking due to likely abuse.")
		message_admins("Client [ckey] just attempted to send an invalid keypress. Keymessage was over [MAX_KEYPRESS_COMMANDLENGTH] characters, autokicking due to likely abuse.")
		qdel(src)
		return

	//Focus Chat failsafe. Overrides movement checks to prevent WASD.
	if(!hotkeys && length(_key) == 1 && _key != "Alt" && _key != "Ctrl" && _key != "Shift")
		winset(src, null, "input.focus=true ; input.text=[url_encode(_key)]")
		return

	if(length(keys_held) >= HELD_KEY_BUFFER_LENGTH && !keys_held[_key])
		keyUp(keys_held[1], mousepos_x, mousepos_y, sizex, sizey) //We are going over the number of possible held keys, so let's remove the first one.

	//the time a key was pressed isn't actually used anywhere (as of 2019-9-10) but this allows easier access usage/checking
	keys_held[_key] = world.time
	var/movement = movement_keys[_key]
	if(movement)
		calculate_move_dir()
		if(!movement_locked && !(next_move_dir_sub & movement))
			next_move_dir_add |= movement

	// Client-level keybindings are ones anyone should be able to do at any time
	// Things like taking screenshots, hitting tab, and adminhelps.
	var/AltMod = keys_held["Alt"] ? "Alt" : ""
	var/CtrlMod = keys_held["Ctrl"] ? "Ctrl" : ""
	var/ShiftMod = keys_held["Shift"] ? "Shift" : ""
	var/full_key
	switch(_key)
		if("Alt", "Ctrl", "Shift")
			full_key = "[AltMod][CtrlMod][ShiftMod]"
		else
			if(AltMod || CtrlMod || ShiftMod)
				full_key = "[AltMod][CtrlMod][ShiftMod][_key]"
				key_combos_held[_key] = full_key
			else
				full_key = _key

	var/list/click_data = get_loc_from_mousepos(mousepos_x, mousepos_y, sizex, sizey, src)

	var/keycount = 0
	for(var/kb_name in prefs.key_bindings_by_key[full_key])
		keycount++
		var/datum/keybinding/kb = GLOB.keybindings_by_name[kb_name]
		if(kb.can_use(src) && kb.down(src, click_data[1], click_data[2], click_data[3]) && keycount >= MAX_COMMANDS_PER_KEY)
			break

	holder?.key_down(_key, src, full_key)
	mob.focus?.key_down(_key, src, full_key)
	mob.update_mouse_pointer()

GAME_VERB_HIDDEN_INSTANT(/client, keyUp, "keyUp", _key as text, mousepos_x as num, mousepos_y as num, sizex as num, sizey as num)

	var/key_combo = key_combos_held[_key]
	if(key_combo)
		key_combos_held -= _key
		keyUp(key_combo, mousepos_x, mousepos_y, sizex, sizey)

	if(!keys_held[_key])
		return

	keys_held -= _key

	var/movement = movement_keys[_key]
	if(movement)
		calculate_move_dir()
		if(!movement_locked && !(next_move_dir_add & movement))
			next_move_dir_sub |= movement
	var/list/click_data
	//manual calls of keyup
	if(mousepos_x && mousepos_y)
		click_data = get_loc_from_mousepos(mousepos_x, mousepos_y, sizex, sizey, src)
	// We don't do full key for release, because for mod keys you
	// can hold different keys and releasing any should be handled by the key binding specifically
	for (var/kb_name in prefs.key_bindings_by_key[_key])
		var/datum/keybinding/kb = GLOB.keybindings_by_name[kb_name]
		if(kb.can_use(src) && kb.up(src, click_data?[1]))
			break
	holder?.key_up(_key, src)
	mob.focus?.key_up(_key, src)
	mob.update_mouse_pointer()

