/obj/machinery/door/poddoor
	name = "blast door"
	desc = "A heavy duty blast door that opens mechanically."
	/// The assembly type for this door, when it is deconstructed or broken
	var/assembly_type = /obj/machinery/door/poddoor/preopen/deconstructed

/obj/machinery/door/poddoor/preopen/deconstructed
	deconstruction = BLASTDOOR_NEEDS_WIRES

/obj/machinery/door/poddoor/on_deconstruction(disassembled)
	var/obj/machinery/door/poddoor/A

	if(deconstruction == BLASTDOOR_NEEDS_WIRES)
		var/datum/crafting_recipe/recipe = locate(recipe_type) in GLOB.crafting_recipes
		if(!recipe)
			return ..()
		var/amount = recipe.reqs[/obj/item/stack/sheet/plasteel]
		if(amount)
			new /obj/item/stack/sheet/plasteel(loc, amount)
		return ..()

	if(assembly_type)
		A = new assembly_type(loc)

	if(!disassembled)
		A?.update_integrity(A.max_integrity * 0.5)
		record_ship_repair_wreckage(src, A)

//"BLAST" doors are obviously stronger than regular doors when it comes to BLASTS.
/obj/machinery/door/poddoor/ex_act(severity, target)
	switch(severity)
		if(EXPLODE_DEVASTATE)
			take_damage(rand(500, 1000), BRUTE, BOMB, 0)
		if(EXPLODE_HEAVY)
			take_damage(rand(300, 600), BRUTE, BOMB, 0)
	if(severity <= EXPLODE_LIGHT)
		return FALSE
	return TRUE
