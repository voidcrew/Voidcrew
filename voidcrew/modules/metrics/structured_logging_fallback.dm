/// Voidcrew: how long the structured log path stays parked after it throws.
/// Short - one unlucky file write should not blind the round's logs for long.
#define LOG_HOLDER_FAILURE_BACKOFF (5 SECONDS)

/**
 * Voidcrew: last resort for when the structured logger itself throws.
 *
 * Writes the line flat to world.log and parks the structured path for a few seconds, so a
 * world whose list allocator is failing produces one line per log call instead of a
 * BYOND-default stack dump per log call. Touches no lists and calls nothing that logs -
 * this proc has to work in the state where nothing else does.
 *
 * The message body does go to world.log here, secret categories included. That is a
 * deliberate trade: world.log is host-side only, and the alternative is losing the record
 * of whatever was happening at the moment the server stopped being able to write records.
 */
/datum/log_holder/proc/logging_failed(category, message, failure)
	structured_logging_broken_until = world.time + LOG_HOLDER_FAILURE_BACKOFF
	SEND_TEXT(world.log, "\[LOG FALLBACK]\[[category]] [message]")
	SEND_TEXT(world.log, "  STRUCTURED LOGGING FAILED ([failure]) - flat world.log lines for the next [LOG_HOLDER_FAILURE_BACKOFF / 10] seconds.")

#undef LOG_HOLDER_FAILURE_BACKOFF // Voidcrew: metrics falls back to world logging when structured writes fail.
