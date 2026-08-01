/datum/unit_test/designs

/datum/unit_test/designs/Run()
//Can't use allocate because of bug with certain datums
	var/datum/design/default_design = new /datum/design()
	var/datum/design/surgery/default_design_surgery = new /datum/design/surgery()

	for(var/path in subtypesof(/datum/design))
		if (ispath(path, /datum/design/surgery)) //We are checking surgery design separatly later since they work differently
			continue
		var/datum/design/current_design = new path //Create an instance of each design
		if (current_design.id == DESIGN_ID_IGNORE) //Don't check designs with ignore ID
			continue
		if (isnull(current_design.name) || current_design.name == default_design.name) //Designs with ID must have non default/null Name
			TEST_FAIL("Design [current_design.type] has default or null name var but has an ID")
		if ((!isnull(current_design.materials) && LAZYLEN(current_design.materials)) || (!isnull(current_design.reagents_list) && LAZYLEN(current_design.reagents_list))) //Design requires materials
			if ((isnull(current_design.build_path) || current_design.build_path == default_design.build_path) && (isnull(current_design.make_reagent) || current_design.make_reagent == default_design.make_reagent)) //Check if design gives any output
				TEST_FAIL("Design [current_design.type] requires materials but does not have either build_path or make_reagent set")
		else if (!isnull(current_design.build_path) || !isnull(current_design.build_path)) // //Design requires no materials but creates stuff
			TEST_FAIL("Design [current_design.type] requires NO materials but has build_path or make_reagent set")
		if (length(current_design.reagents_list) && !(current_design.build_type & LIMBGROWER))
			TEST_FAIL("Design [current_design.type] requires reagents but isn't a limb grower design. Reagent costs are only supported by limb grower designs")

	for(var/path in subtypesof(/datum/design/surgery))
		var/datum/design/surgery/current_design = new path //Create an instance of each design
		if (isnull(current_design.id) || current_design.id == default_design_surgery.id) //Check if ID was not set
			TEST_FAIL("Surgery Design [current_design.type] has no ID set")
		if (isnull(current_design.id) || current_design.name == default_design_surgery.name) //Check if name was not set
			TEST_FAIL("Surgery Design [current_design.type] has default or null name var")
		if (isnull(current_design.desc) || current_design.desc == default_design_surgery.desc) //Check if desc was not set
			TEST_FAIL("Surgery Design [current_design.type] has default or null desc var")
		if (isnull(current_design.surgery) || current_design.surgery == default_design_surgery.surgery) //Check if surgery was not set
			TEST_FAIL("Surgery Design [current_design.type] has default or null surgery var")

/datum/unit_test/design_source

/datum/unit_test/design_source/Run()
	var/list/all_designs = list()
	var/list/exceptions = list(
		/datum/design/surgery/healing, // Ignored due to the above test
		// Voidcrew: station-only supply and records consoles. A ship has no station
		// cargo department to file requests with and no station payroll to audit, so
		// these are pulled out of their upstream nodes in
		// voidcrew/modules/research/techweb_nodes.dm. The designs stay behind for the
		// consoles that are already mapped in; nothing researches them.
		/datum/design/board/cargorequest,
		/datum/design/board/accounting_console,
		/datum/design/cargo_express,
		/datum/design/bluespace_pod,
		// Voidcrew: the void thruster board is a Quartermain depot contract reward and
		// is never sold or printed (see exclusive_rewards in
		// voidcrew/modules/trade/shop_catalog_outfitter.dm), so unlike the plasma and
		// expulsion thrusters it is deliberately off the shuttle research ladder.
		/datum/design/board/engine/void,
		// Voidcrew: the base nanite design is a template the real programs inherit
		// from, not a program anyone can print.
		/datum/design/nanites,
		// Voidcrew: defective nanite programs are what working programs decay into,
		// and the heart-stopper is contraband. All of them are reached through nanite
		// program disks (voidcrew/modules/nanites/code/items/items.dm) rather than
		// research, which is how the nanite nodes have always been laid out.
		/datum/design/nanites/glitch,
		/datum/design/nanites/necrotic,
		/datum/design/nanites/toxic,
		/datum/design/nanites/suffocating,
		/datum/design/nanites/brain_misfire,
		/datum/design/nanites/skin_decay,
		/datum/design/nanites/nerve_decay,
		/datum/design/nanites/brain_decay,
		/datum/design/nanites/heart_stop,
	)

	for (var/datum/design/design as anything in subtypesof(/datum/design))
		var/design_id = design::id
		if (design_id == DESIGN_ID_IGNORE || (design in exceptions))
			continue
		if (design_id in all_designs)
			TEST_FAIL("Design [design] shares an ID \"[design_id]\" with another design")
			continue
		all_designs[design_id] = design

	for (var/datum/techweb_node/node as anything in subtypesof(/datum/techweb_node))
		node = new node()
		for (var/design_id in node.design_ids)
			if (!all_designs[design_id])
				TEST_FAIL("Techweb node [node.display_name] ([node.id]) has a design_id \"[design_id]\" which doesn't correspond to any existing design!")
				continue
			all_designs -= design_id
		qdel(node)

	// Designs can also be disk-exclusive
	for (var/obj/item/disk/design_disk/design_disk as anything in subtypesof(/obj/item/disk/design_disk))
		design_disk = new design_disk()
		for (var/datum/design/design as anything in design_disk.blueprints)
			all_designs -= design.id
		qdel(design_disk)

	for (var/obj/item/disk/surgery/design_disk as anything in subtypesof(/obj/item/disk/surgery))
		design_disk = new design_disk()
		for (var/surgery_type as anything in design_disk.surgeries)
			for (var/design_id in all_designs)
				var/datum/design/surgery/design = all_designs[design_id]
				if (ispath(design, /datum/design/surgery) && design::surgery == surgery_type)
					all_designs -= design::id
		qdel(design_disk)

	// Or machine-exclusive
	for (var/datum/techweb/autounlocking/techweb as anything in subtypesof(/datum/techweb/autounlocking))
		techweb = new techweb()
		for (var/design_id in techweb.researched_designs + techweb.hacked_designs)
			var/datum/design/design = SSresearch.techweb_design_by_id(design_id)
			// If we have a design thats supposed to be printable from a protolathe and an autolathe, but only autolathes can print it
			// then we still should error because then we either have a missing design_id or redundant build flags
			if (!(design.build_type & (~techweb.allowed_buildtypes)))
				all_designs -= design_id
		qdel(techweb)

	for (var/missing_id in all_designs)
		TEST_FAIL("Design [all_designs[missing_id]] has an ID \"[missing_id]\" which is not in any of the techweb nodes or tech disks, or it is possibly misconfigured!")
