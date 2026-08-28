/**
 * The parent of this component will be destroyed if it's on the ground during a storm
 */
/datum/component/storm_hating
	/// Types of weather which trigger the effect
	var/static/list/stormy_weather = list(
		/datum/weather/particle/ash_storm,
		/datum/weather/snow_storm,
		/datum/weather/void_storm,
	)
	// VOIDCREW EDIT ADDITION: the area whose weather signals we are currently holding.
	// COMSIG_ENTER_AREA is not guaranteed to arrive exactly once per transition and is not
	// guaranteed to be preceded by a matching COMSIG_EXIT_AREA - a ship landing on a planet
	// rewrites the landing turfs' area with set_turf_to_area() (which fires both signals by
	// hand at everything standing on the tile) and then evict_landing_stowaways() forceMoves
	// the leftovers back out onto the site, so one piece of ash can be told it entered the
	// same area twice. Registering blind then produced six
	// "weather_(began|ended)_in_area_... overridden" runtimes per landing and, in the
	// mirror case, left registrations behind on areas the parent had already left.
	var/area/watched_area
	// VOIDCREW EDIT ADDITION END

/datum/component/storm_hating/Initialize()
	. = ..()
	if (!isatom(parent))
		return COMPONENT_INCOMPATIBLE
	on_area_entered(parent, get_area(parent))

/datum/component/storm_hating/RegisterWithParent()
	. = ..()
	RegisterSignal(parent, COMSIG_ENTER_AREA, PROC_REF(on_area_entered))
	RegisterSignal(parent, COMSIG_EXIT_AREA, PROC_REF(on_area_exited))
	RegisterSignal(parent, COMSIG_MOB_LOGIN, PROC_REF(on_login))

/datum/component/storm_hating/UnregisterFromParent()
	. = ..()
	UnregisterSignal(parent, list(COMSIG_ENTER_AREA, COMSIG_EXIT_AREA))
	// VOIDCREW EDIT: unconditional now - on_area_exited() drops whatever watched_area holds
	// and no-ops when we hold nothing, so a parent sitting in nullspace no longer leaves its
	// weather registrations behind on the area it was last in.
	on_area_exited(parent, null)

/datum/component/storm_hating/proc/on_area_entered(atom/source, area/new_area)
	SIGNAL_HANDLER
	// VOIDCREW EDIT ADDITION: guard re-entry - see watched_area.
	if(watched_area == new_area)
		return
	if(!isnull(watched_area))
		for (var/weather in stormy_weather)
			UnregisterSignal(watched_area, COMSIG_WEATHER_BEGAN_IN_AREA(weather))
			UnregisterSignal(watched_area, COMSIG_WEATHER_ENDED_IN_AREA(weather))
		watched_area = null
	if(isnull(new_area))
		return
	watched_area = new_area
	// VOIDCREW EDIT ADDITION END
	for (var/weather in stormy_weather)
		RegisterSignal(new_area, COMSIG_WEATHER_BEGAN_IN_AREA(weather), PROC_REF(on_storm_event))
		RegisterSignal(new_area, COMSIG_WEATHER_ENDED_IN_AREA(weather), PROC_REF(on_storm_event))

/datum/component/storm_hating/proc/on_area_exited(atom/source, area/old_area)
	SIGNAL_HANDLER
	// VOIDCREW EDIT ADDITION: drop exactly the registrations we are holding rather than
	// whichever area the caller named. UnregisterFromParent() passes get_area(parent), which
	// is not necessarily the area we last registered on.
	if(isnull(watched_area))
		return
	old_area = watched_area
	watched_area = null
	// VOIDCREW EDIT ADDITION END
	for (var/weather in stormy_weather)
		UnregisterSignal(old_area, COMSIG_WEATHER_BEGAN_IN_AREA(weather))
		UnregisterSignal(old_area, COMSIG_WEATHER_ENDED_IN_AREA(weather))

/datum/component/storm_hating/proc/on_storm_event()
	SIGNAL_HANDLER
	var/atom/parent_atom = parent
	if (!isturf(parent_atom.loc))
		return
	parent_atom.fade_into_nothing(life_time = 3 SECONDS, fade_time = 2 SECONDS)
	qdel(src)

/datum/component/storm_hating/proc/on_login(datum/source)
	SIGNAL_HANDLER
	qdel(src)
