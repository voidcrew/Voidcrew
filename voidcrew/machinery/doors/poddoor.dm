/obj/machinery/door/poddoor
	name = "blast door"
	desc = "A heavy duty blast door that opens mechanically."
	/// The assembly type for this door, when it is deconstructed or broken
	var/assembly_type = /obj/machinery/door/poddoor/preopen/deconstructed

//"BLAST" doors are obviously stronger than regular doors when it comes to BLASTS.
/obj/machinery/door/poddoor/ex_act(severity, target)
	switch(severity)
		if(EXPLODE_DEVASTATE)
			take_damage(rand(500, 1000), BRUTE, BOMB, 0)
		if(EXPLODE_HEAVY)
			take_damage(rand(300, 600), BRUTE, BOMB, 0)
	if(severity <= EXPLODE_LIGHT)
		return FALSE
	return ..()
