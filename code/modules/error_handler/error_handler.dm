GLOBAL_VAR_INIT(total_runtimes, GLOB.total_runtimes || 0)
GLOBAL_VAR_INIT(total_runtimes_skipped, 0)

/*
 * VOIDCREW ADDITION - runtime flood breaker state.
 *
 * Plain numbers on purpose. The failure these guard against (round-7, 2026-08-16) is one
 * where EVERY list operation in the world starts throwing "bad list" - a boot-time,
 * never-mutated list like the config subsystem's entries_by_type failed a plain read,
 * as did client keybinding caches, SSgarbage's queues and this handler's own static
 * error_last_seen. Anything here that touched a list or a config entry would throw on the
 * way to the breaker and hand control back to BYOND's built-in handler, which is what
 * actually wrote 337 MB of dd.log in 46 seconds. GLOB var reads are a global slot lookup
 * and kept working throughout (GLOB.total_runtimes counted the whole flood), so the
 * breaker is built out of those and nothing else.
 */
/// world.time-derived index of the flood window we are currently counting in.
GLOBAL_VAR_INIT(error_flood_window, 0)
/// Runtimes handled so far in this window.
GLOBAL_VAR_INIT(error_flood_count, 0)
/// Runtimes dropped by the breaker in this window.
GLOBAL_VAR_INIT(error_flood_suppressed, 0)
/// While world.time is below this, world/Error emits one flat line per runtime and does
/// nothing else - set when the handler itself threw. See the catch in world/Error.
GLOBAL_VAR_INIT(error_handler_degraded_until, 0)

#ifdef USE_CUSTOM_ERROR_HANDLER
#define ERROR_USEFUL_LEN 2

/// Length of a flood-breaker window, in deciseconds.
#define ERROR_FLOOD_WINDOW 10
/// Runtimes fully handled per ERROR_FLOOD_WINDOW before the breaker starts dropping them.
/// Normal play sits under one runtime a second; round-7's flood ran at 81,000 log lines a
/// second, so this only ever trips in a catastrophe. Set well clear of a legitimate burst
/// because world.time does not advance inside blocking code - a bad map init can pile its
/// whole runtime output into one window - and losing boot diagnostics to the breaker would
/// be a bad trade for a guard that exists to survive a once-a-fortnight event.
#define ERROR_FLOOD_LIMIT 300
/// How long world/Error stays on its flat one-line path after throwing while handling a
/// runtime. Short, because a single unlucky exception should not blind the log for long.
#define ERROR_HANDLER_DEGRADE_TIME 50

/world/Error(exception/E, datum/e_src)
	GLOB.total_runtimes++

	if(!istype(E)) //Something threw an unusual exception
		log_world("uncaught runtime error: [E]")
		return ..()

	//this is snowflake because of a byond bug (ID:2306577), do not attempt to call non-builtin procs in this block OR BEFORE IT
	if(copytext(E.name, 1, 32) == "Maximum recursion level reached")//32 == length() of that string + 1
		var/list/proc_path_to_count = list()
		var/crashed = FALSE
		try
			var/callee/stack_entry = caller
			while(!isnull(stack_entry))
				proc_path_to_count[stack_entry.proc] += 1
				stack_entry = stack_entry.caller
		catch
			//union job. avoids crashing the stack again
			//I just do not trust this construct to work reliably
			crashed = TRUE

		var/list/split = splittext(E.desc, "\n")
		for (var/i in 1 to split.len)
			if (split[i] != "" || copytext(split[1], 1, 2) != "  ")
				split[i] = "  [split[i]]"
		split += "--Stack Info [crashed ? "(Crashed, may be missing info)" : ""]:"
		for(var/path in proc_path_to_count)
			split += "  [path] = [proc_path_to_count[path]]"
		E.desc = jointext(split, "\n")
		SEND_TEXT(world.log, "\[[time2text(world.timeofday,"hh:mm:ss")]\] Runtime Error: [E.name]\n[E.desc]")
		//log to world while intentionally triggering the byond bug. this does not DO anything, it just errors
		//(seemingly because of the extra proc call to logger inside log_world interestingly enough)
		log_world("runtime error: [E.name]\n[E.desc]")
		//if we got to here without silently ending, the byond bug has been fixed.
		log_world("The \"bug\" with recursion runtimes has been fixed. Please remove the snowflake check from world/Error in [__FILE__]:[__LINE__]")
		return //this will never happen.

	// Proc calls are allowed past this point
	else if(copytext(E.name, 1, 18) == "Out of resources!")//18 == length() of that string + 1
		log_world("BYOND out of memory. Restarting ([E?.file]:[E?.line])")
		TgsEndProcess()
		. = ..()
		Reboot(reason = 1)
		return

	// VOIDCREW ADDITION - RUNTIME FLOOD BREAKER.
	//
	// The per-error-site silencer further down (error_cooldown/error_limit, the "silenced
	// for 10 minutes" line) is keyed on "[E.file][E.line]" and lives BELOW the first list
	// access in this proc. In round-7 it protected nothing twice over: the flood came from
	// thirty-odd distinct sites, and the handler threw before ever reaching it, so BYOND's
	// built-in handler printed a full call stack for every runtime in the world at
	// 81,000 lines a second until the host died.
	//
	// This is the site-blind backstop: a hard ceiling on how many runtimes this handler
	// will do real work for per window, whatever they are and wherever they came from.
	// Suppressed runtimes still count into GLOB.total_runtimes (so CI's zero-runtime gate
	// and the round-end tally are unaffected) and the window reports what it dropped.
	//
	// Off under UNIT_TESTS: a dropped runtime never reaches GLOB.current_test.Fail(), and
	// a test suite that silently stops failing is worse than a slow one.
#ifndef UNIT_TESTS
	var/flood_window = round(world.time / ERROR_FLOOD_WINDOW)
	if(flood_window != GLOB.error_flood_window)
		var/dropped = GLOB.error_flood_suppressed
		GLOB.error_flood_window = flood_window
		GLOB.error_flood_count = 0
		GLOB.error_flood_suppressed = 0
		if(dropped)
			SEND_TEXT(world.log, "\[[time2text(world.timeofday, "hh:mm:ss")]\] RUNTIME FLOOD BREAKER: dropped [dropped] runtime(s) in the previous window.")
	GLOB.error_flood_count++
	if(GLOB.error_flood_count > ERROR_FLOOD_LIMIT)
		GLOB.error_flood_suppressed++
		return
#endif

	var/static/regex/stack_workaround
	if(isnull(stack_workaround))
		stack_workaround = regex("[WORKAROUND_IDENTIFIER](.+?)[WORKAROUND_IDENTIFIER]")
	var/static/list/error_last_seen = list()
	var/static/list/error_cooldown = list() /* Error_cooldown items will either be positive(cooldown time) or negative(silenced error)
												If negative, starts at -1, and goes down by 1 each time that error gets skipped*/

	if(!error_last_seen) // A runtime is occurring too early in start-up initialization
		return ..()

	// VOIDCREW ADDITION: the handler threw recently, so don't try the rich path again yet -
	// just get the runtime on the record in one line. See the catch below.
#ifndef UNIT_TESTS
	if(world.time < GLOB.error_handler_degraded_until)
		SEND_TEXT(world.log, "\[[time2text(world.timeofday, "hh:mm:ss")]\] Runtime in [E.file],[E.line]: [E] (handler degraded)")
		return
#endif

	// VOIDCREW ADDITION: everything from here down touches lists, the config subsystem, the
	// error cache and the structured logger, and every one of those threw in round-7. A
	// runtime handler that raises its own runtime drops the world onto BYOND's built-in
	// handler, which prints the full call stack of the ORIGINAL error once per unwound
	// frame - roughly a twenty-line block per runtime with no rate limit of any kind
	// attached to it. Catch it here and fall back to a flat line instead.
	try
		if(stack_workaround.Find(E.name))
			if(length(stack_workaround.group) > 0)
				var/list/data = json_decode(stack_workaround.group[1])
				E.file = data[1]
				E.line = data[2]
				E.name = stack_workaround.Replace(E.name, "")

		var/erroruid = "[E.file][E.line]"
		var/last_seen = error_last_seen[erroruid]
		var/cooldown = error_cooldown[erroruid] || 0

		if(last_seen == null)
			error_last_seen[erroruid] = world.time
			last_seen = world.time

		if(cooldown < 0)
			error_cooldown[erroruid]-- //Used to keep track of skip count for this error
			GLOB.total_runtimes_skipped++
			return //Error is currently silenced, skip handling it
		//Handle cooldowns and silencing spammy errors
		var/silencing = FALSE

		// We can runtime before config is initialized because BYOND initialize objs/map before a bunch of other stuff happens.
		// This is a bunch of workaround code for that. Hooray!
		var/configured_error_cooldown
		var/configured_error_limit
		var/configured_error_silence_time
		if(config?.entries)
			configured_error_cooldown = CONFIG_GET(number/error_cooldown)
			configured_error_limit = CONFIG_GET(number/error_limit)
			configured_error_silence_time = CONFIG_GET(number/error_silence_time)
		else
			var/datum/config_entry/CE = /datum/config_entry/number/error_cooldown
			configured_error_cooldown = initial(CE.default)
			CE = /datum/config_entry/number/error_limit
			configured_error_limit = initial(CE.default)
			CE = /datum/config_entry/number/error_silence_time
			configured_error_silence_time = initial(CE.default)


		//Each occurence of a unique error adds to its cooldown time...
		cooldown = max(0, cooldown - (world.time - last_seen)) + configured_error_cooldown
		// ... which is used to silence an error if it occurs too often, too fast
		if(cooldown > configured_error_cooldown * configured_error_limit)
			cooldown = -1
			silencing = TRUE
			spawn(0)
				usr = null
				sleep(configured_error_silence_time)
				var/skipcount = abs(error_cooldown[erroruid]) - 1
				error_cooldown[erroruid] = 0
				if(skipcount > 0)
					SEND_TEXT(world.log, "\[[time_stamp()]] Skipped [skipcount] runtimes in [E.file],[E.line].")
					GLOB.error_cache.log_error(E, skip_count = skipcount)

		error_last_seen[erroruid] = world.time
		error_cooldown[erroruid] = cooldown

		var/list/usrinfo = null
		var/locinfo
		if(istype(usr))
			usrinfo = list("  usr: [key_name(usr)]")
			locinfo = loc_name(usr)
			if(locinfo)
				usrinfo += "  usr.loc: [locinfo]"
		// The proceeding mess will almost definitely break if error messages are ever changed
		var/list/splitlines = splittext(E.desc, "\n")
		var/list/desclines = list()
#ifndef DISABLE_DREAMLUAU
		var/list/state_stack = GLOB.lua_state_stack
		var/is_lua_call = length(state_stack)
		var/list/lua_stacks = list()
		if(is_lua_call)
			for(var/level in 1 to state_stack.len)
				lua_stacks += list(splittext(DREAMLUAU_GET_TRACEBACK(level), "\n"))
#endif
		if(LAZYLEN(splitlines) > ERROR_USEFUL_LEN) // If there aren't at least three lines, there's no info
			for(var/line in splitlines)
				if(LAZYLEN(line) < 3 || findtext(line, "source file:") || findtext(line, "usr.loc:"))
					continue
				if(findtext(line, "usr:"))
					if(usrinfo)
						desclines.Add(usrinfo)
						usrinfo = null
					continue // Our usr info is better, replace it
				if(copytext(line, 1, 3) != "  ")//3 == length("  ") + 1
					desclines += ("  " + line) // Pad any unpadded lines, so they look pretty
				else
					desclines += line
		if(usrinfo) //If this info isn't null, it hasn't been added yet
			desclines.Add(usrinfo)
#ifndef DISABLE_DREAMLUAU
		if(is_lua_call)
			SSlua.log_involved_runtime(E, desclines, lua_stacks)
#endif
		if(silencing)
			desclines += "  (This error will now be silenced for [DisplayTimeText(configured_error_silence_time)])"
		if(GLOB.error_cache)
			GLOB.error_cache.log_error(E, desclines)

		var/main_line = "\[[time_stamp()]] Runtime in [E.file],[E.line]: [E]"
		SEND_TEXT(world.log, main_line)
		for(var/line in desclines)
			SEND_TEXT(world.log, line)

#ifdef UNIT_TESTS
		if(GLOB.current_test)
			//good day, sir
			GLOB.current_test.Fail("[main_line]\n[desclines.Join("\n")]", file = E.file, line = E.line)
#endif

		if(Debugger?.enabled)
			to_chat(world, span_alertwarning("[main_line]"), type = MESSAGE_TYPE_DEBUG)

		// This writes the regular format (unwrapping newlines and inserting timestamps as needed).
		log_runtime("runtime error: [E.name]\n[E.desc]")
	catch(var/exception/handler_failure)
		// Two flat lines and a short degrade window. Nothing in here indexes a list, calls
		// into config, or goes near the structured logger, because in the state this exists
		// for none of those work. handler_failure is interpolated but never dereferenced -
		// a thrown string lands here as readily as an /exception does.
		GLOB.error_handler_degraded_until = world.time + ERROR_HANDLER_DEGRADE_TIME
		SEND_TEXT(world.log, "\[[time2text(world.timeofday, "hh:mm:ss")]\] Runtime in [E.file],[E.line]: [E]")
		SEND_TEXT(world.log, "  RUNTIME HANDLER FAILED reporting the above ([handler_failure]) - flat logging for [ERROR_HANDLER_DEGRADE_TIME / 10] seconds.")
#endif

#undef ERROR_USEFUL_LEN
#undef ERROR_FLOOD_WINDOW
#undef ERROR_FLOOD_LIMIT
#undef ERROR_HANDLER_DEGRADE_TIME

/// Exists to trigger infinite recursion runtimes in testing
/proc/recurse(times)
	if(times <= 0)
		return
	recurse(times - 1)
