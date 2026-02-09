/**
 * Modular fix for upstream TG power leak bug
 *
 * Problem: When machinery moves between areas (e.g., shuttle transit),
 * on_exit_area() calls unset_static_power() which uses get_area(src).
 * But by the time on_exit_area is called, the machine has already moved
 * to the new area, so get_area(src) returns the NEW area, not the OLD
 * area where power was registered. This causes phantom power drain that
 * persists even after the machinery is deleted.
 *
 * Fix: Use the area passed to on_exit_area (the correct old area) instead
 * of calling get_area(src).
 */
/obj/machinery/on_exit_area(datum/source, area/area_to_unregister)
	SIGNAL_HANDLER
	if(always_area_sensitive && use_power == NO_POWER_USE)
		return
	// FIX: Remove power from the PASSED area (old area), not get_area(src) (new area)
	if(area_to_unregister && static_power_usage)
		area_to_unregister.removeStaticPower(static_power_usage, DYNAMIC_TO_STATIC_CHANNEL(power_channel))
		static_power_usage = 0
	UnregisterSignal(area_to_unregister, COMSIG_AREA_POWER_CHANGE)
