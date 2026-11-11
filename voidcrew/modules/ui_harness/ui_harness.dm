/**
 * UI test harness (dev builds only).
 *
 * Lets a local tool drive a connected client's tgui windows (click, type, press keys, read the page)
 * without touching the real mouse or keyboard. The tool talks to world/Topic over TCP from 127.0.0.1;
 * this file forwards each command to the page as a tgui message, and the page module
 * (tgui/packages/voidcrew_tgui/utils/harness.ts) fires real DOM events and replies with "harness/result".
 *
 * None of this exists unless the world is compiled with -DUI_HARNESS. Never build a live server with it.
 */
#ifdef UI_HARNESS

#warn compiling with UI_HARNESS: local tools can drive clients' tgui windows. Never run this build on a live server.

/// Longest a single harness command waits for the page to answer, in deciseconds.
#define UI_HARNESS_MAX_WAIT (15 SECONDS)
/// Default wait for the page to answer, in deciseconds.
#define UI_HARNESS_DEFAULT_WAIT (8 SECONDS)

/// Most pieces one page reply may come in (about 1 KB each).
#define UI_HARNESS_MAX_PARTS 40

/// Command id -> REF() of the window it was sent to, or the page's reply list once it arrives.
GLOBAL_LIST_EMPTY(ui_harness_pending)
/// Command id -> the reply pieces received so far.
GLOBAL_LIST_EMPTY(ui_harness_chunks)
GLOBAL_VAR_INIT(ui_harness_next_id, 0)

/world/Topic(T, addr, master, key)
	var/list/input = params2list(T)
	if(!("ui_harness" in input))
		return ..()
	if(!ui_harness_is_local(addr))
		log_topic("ui_harness refused from [addr]")
		return json_encode(list("error" = "local connections only"))
	return json_encode(ui_harness_command(input))

/// TRUE if [addr] is the loopback address (BYOND may append a port).
/proc/ui_harness_is_local(addr)
	if(!istext(addr))
		return FALSE
	var/list/parts = splittext(addr, ":")
	return parts[1] == "127.0.0.1"

/// Runs one harness command and returns a list to hand back as JSON.
/proc/ui_harness_command(list/input)
	var/op = input["ui_harness"]
	if(op == "list")
		return list("ok" = TRUE, "clients" = ui_harness_list_clients())

	var/client/target_client = ui_harness_find_client(input["ckey"])
	if(!target_client)
		return list("error" = "no such client (pass ckey= when several are connected)")

	switch(op)
		if("open")
			return ui_harness_open(target_client, input["what"])
		if("click", "type", "key", "query", "scroll", "layout")
			var/datum/tgui_window/window = ui_harness_find_window(target_client, input["window"], input["interface"])
			if(!window)
				return list("error" = "no such tgui window (pass window= or interface=)", "windows" = ui_harness_list_windows(target_client))
			var/wait = clamp(text2num(input["timeout"]) * 10 || UI_HARNESS_DEFAULT_WAIT, 1 SECONDS, UI_HARNESS_MAX_WAIT)
			var/list/args_out = input.Copy()
			args_out -= list("ui_harness", "ckey", "window", "interface", "timeout")
			return ui_harness_send(window, op, args_out, wait)
	return list("error" = "unknown command [op]")

/proc/ui_harness_list_clients()
	var/list/out = list()
	for(var/client/client as anything in GLOB.clients)
		out += list(list(
			"ckey" = client.ckey,
			"mob" = "[client.mob?.type]",
			"windows" = ui_harness_list_windows(client),
		))
	return out

/proc/ui_harness_list_windows(client/client)
	var/list/out = list()
	for(var/window_id in client.tgui_windows)
		var/datum/tgui_window/window = client.tgui_windows[window_id]
		out += list(list(
			"id" = window.id,
			"status" = window.status,
			"visible" = window.visible,
			"is_browser" = window.is_browser,
			"interface" = window.locked_by?.interface,
			"title" = window.locked_by?.title,
		))
	return out

/proc/ui_harness_find_client(wanted_ckey)
	if(wanted_ckey)
		return GLOB.directory[ckey(wanted_ckey)]
	if(length(GLOB.clients) == 1)
		return GLOB.clients[1]
	return null

/proc/ui_harness_find_window(client/client, window_id, interface_name)
	if(window_id)
		return client.tgui_windows[window_id]
	if(!interface_name)
		return null
	for(var/id in client.tgui_windows)
		var/datum/tgui_window/window = client.tgui_windows[id]
		if(window.status == TGUI_WINDOW_READY && window.locked_by?.interface == interface_name)
			return window
	return null

/// Opens one of a short list of UIs a lobby client can't otherwise reach without a mouse.
/proc/ui_harness_open(client/client, what)
	switch(what)
		if("preferences")
			client.prefs.ui_interact(client.mob)
			return list("ok" = TRUE, "opened" = what)
	return list("error" = "unknown UI [what] (known: preferences)")

/// Sends [op] to [window]'s page and waits up to [wait] for its reply.
/proc/ui_harness_send(datum/tgui_window/window, op, list/op_args, wait)
	var/id = "[++GLOB.ui_harness_next_id]"
	GLOB.ui_harness_pending[id] = REF(window)
	window.send_message("harness/enable")
	window.send_message("harness/run", list("id" = id, "op" = op, "args" = op_args))
	var/give_up = REALTIMEOFDAY + wait
	while(REALTIMEOFDAY < give_up && !islist(GLOB.ui_harness_pending[id]))
		sleep(1)
	var/reply = GLOB.ui_harness_pending[id]
	GLOB.ui_harness_pending -= id
	GLOB.ui_harness_chunks -= id
	if(!islist(reply))
		return list("error" = "no reply from the page within [wait / 10] s", "window" = window.id)
	var/list/result = reply
	result["window"] = window.id
	return result

/datum/tgui_window/on_message(type, payload, href_list)
	if(type != "harness/result")
		return ..()
	// Only replies to a command this world sent to this exact window are kept.
	if(!islist(payload))
		return
	var/id = "[payload["id"]]"
	if(GLOB.ui_harness_pending[id] != REF(src))
		return
	// The page sends its reply as JSON in numbered pieces, since topic links have a length limit.
	var/parts = text2num(payload["parts"])
	var/part = text2num(payload["part"])
	if(!isnum(parts) || parts < 1 || parts > UI_HARNESS_MAX_PARTS || !isnum(part) || part < 1 || part > parts)
		return
	var/list/chunks = GLOB.ui_harness_chunks[id]
	if(!chunks)
		chunks = new /list(parts)
		GLOB.ui_harness_chunks[id] = chunks
	if(length(chunks) != parts)
		return
	chunks[part] = "[payload["chunk"]]"
	for(var/chunk in chunks)
		if(isnull(chunk))
			return
	GLOB.ui_harness_chunks -= id
	var/json = jointext(chunks, "")
	if(!rustg_json_is_valid(json))
		GLOB.ui_harness_pending[id] = list("error" = "the page's reply was not valid JSON")
		return
	var/list/reply = json_decode(json)
	GLOB.ui_harness_pending[id] = islist(reply) ? reply : list("error" = "the page's reply was not an object")

#undef UI_HARNESS_MAX_WAIT
#undef UI_HARNESS_MAX_PARTS
#undef UI_HARNESS_DEFAULT_WAIT

#endif
