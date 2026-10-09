/**
 * vcphys: Box2D for the limb rig, in a native library.
 *
 * The source is in tools/vcphys (Rust, on box2d-rs, a port of Box2D). It builds to vcphys.dll,
 * which sits next to the game like rust_g.dll (32-bit, like BYOND); libvcphys.so on Linux.
 *
 * Box2D's worlds, bodies, fixtures and joints all live in the library. The game only holds their
 * handles, as numbers, and talks to it through call_ext: text in, text out. Every reply is a value,
 * "OK", or "ERR:<why>". vcphys_call() turns an ERR into a stack trace and a null, so a bad call is
 * easy to spot and never crashes anything.
 *
 * Without the library (it isn't built for the unit tests' Linux, say), vcphys_available() is FALSE
 * and nothing physical happens.
 */

/// Where the library was found, FALSE if it couldn't be, or null before anyone's asked.
GLOBAL_VAR(vcphys_library)
/// Whether every call and reply is kept, for debugging (see the Limb Physics: Inspect verb).
GLOBAL_VAR_INIT(vcphys_logging, FALSE)
/// The last calls and replies, while logging.
GLOBAL_LIST_EMPTY(vcphys_log)

/// How many calls the log keeps.
#define VCPHYS_LOG_LENGTH 60

/proc/vcphys_library_path()
	if(world.system_type == UNIX)
		return fexists("./libvcphys.so") ? "./libvcphys.so" : "libvcphys.so"
	return "vcphys"

/// Whether the library is there and answering. Checked once, then remembered.
/proc/vcphys_available()
	if(isnull(GLOB.vcphys_library))
		var/path = vcphys_library_path()
		var/version
		try
			version = call_ext(path, "vcphys_version")()
		catch
			version = null
		if(istext(version) && findtext(version, "vcphys") == 1)
			GLOB.vcphys_library = path
			log_world("vcphys: loaded [version] from [path]")
		else
			GLOB.vcphys_library = FALSE
			log_world("vcphys: [path] isn't there or isn't answering. Limb physics is off.")
	return !!GLOB.vcphys_library

/**
 * Calls one of the library's commands (see tools/vcphys/src/lib.rs), without its "vcphys_" prefix.
 * Numbers are sent with enough digits not to lose anything. Returns the reply as text, or null if
 * the library isn't there or said ERR (which leaves a stack trace saying why).
 */
/proc/vcphys_call(command, ...)
	if(!vcphys_available())
		return null
	var/list/call_args = list()
	for(var/i in 2 to length(args))
		var/value = args[i]
		call_args += isnum(value) ? num2text(value, 12) : "[value]"
	var/reply
	try
		reply = call_ext(GLOB.vcphys_library, "vcphys_[command]")(arglist(call_args))
	catch(var/exception/error)
		stack_trace("vcphys: calling [command] failed: [error]")
		return null
	if(GLOB.vcphys_logging)
		GLOB.vcphys_log += "[command]([jointext(call_args, ", ")]) -> [length(reply) > 200 ? "[copytext(reply, 1, 200)]..." : reply]"
		if(length(GLOB.vcphys_log) > VCPHYS_LOG_LENGTH)
			GLOB.vcphys_log.Cut(1, 2)
	if(!istext(reply) || findtext(reply, "ERR:") == 1)
		stack_trace("vcphys: [command]([jointext(call_args, ", ")]) said [reply]")
		return null
	return reply

#undef VCPHYS_LOG_LENGTH
