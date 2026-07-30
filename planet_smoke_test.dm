// TEMPORARY. Only keeps a clientless world ticking so SSovermap's lobby fire() runs;
// everything being measured is production logging. Included only by planets_check.dme.
SUBSYSTEM_DEF(planet_smoke)
	name = "Planet Smoke"
	init_order = -100
	flags = SS_NO_FIRE

/datum/controller/subsystem/planet_smoke/Initialize()
	Master.sleep_offline_after_initializations = FALSE
	return SS_INIT_SUCCESS
