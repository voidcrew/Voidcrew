/*
 * Voidcrew - runtime flood breaker state.
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
