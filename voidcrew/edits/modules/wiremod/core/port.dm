// Voidcrew extensions to code/modules/wiremod/core/port.dm.

/datum/port/output
	/// How many input ports are currently reading from this output.
	var/connected_inputs = 0
	/// How many input ports may read from this output at once. Unlimited by default,
	/// which is the historic behaviour and what every stock component still gets.
	var/max_inputs = INFINITY
