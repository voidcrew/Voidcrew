// Voidcrew extensions to code/modules/logging/log_holder.dm.

/datum/log_holder
	/// VOIDCREW ADDITION: world.time until which Log() skips the structured path and writes
	/// flat world.log lines instead. Set by logging_failed().
	var/structured_logging_broken_until = 0
