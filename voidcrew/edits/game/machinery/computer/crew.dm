// Voidcrew extensions to code/game/machinery/computer/crew.dm.

/datum/crewmonitor
	/// Cache of data generated per sensor scope, used for serving the data within SENSOR_UPDATE_PERIOD of the last update
	var/list/data_by_scope = list()
