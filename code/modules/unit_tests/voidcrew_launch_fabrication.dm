/// Run real production and recycling, including a bulk stack that splits on output.
/datum/unit_test/voidcrew_launch_protolathe_stack_recycling/Run()
	var/obj/machinery/rnd/production/protolathe/launch_fabrication_test/lathe = allocate(/obj/machinery/rnd/production/protolathe/launch_fabrication_test)
	lathe.set_machine_stat(NONE)
	lathe.efficiency_coeff = 0.4
	lathe.materials.set_local_size(1000 * SHEET_MATERIAL_AMOUNT)
	var/datum/component/material_container/container = lathe.materials.mat_container
	var/list/design_ids = list("cable_coil", "fluid_ducts", "shuttlerods")
	for(var/design_id in design_ids)
		var/datum/design/design = SSresearch.techweb_design_by_id(design_id)
		TEST_ASSERT_NOTNULL(design, "Missing stack regression design [design_id]")
		var/list/before = list()
		for(var/material in design.materials)
			container.insert_amount_mat(100 * SHEET_MATERIAL_AMOUNT, material)
			before[material] = container.materials[material]
		var/batch = design_id == "cable_coil" ? 50 : 1
		lathe.print_test_design(design, batch)
		var/list/spent = list()
		for(var/material in before)
			spent[material] = before[material] - container.materials[material]
			TEST_ASSERT(spent[material] > 0, "[design_id] must consume material before recycling")
		var/output_units = 0
		for(var/obj/item/stack/output in run_loc_floor_bottom_left)
			if(!istype(output, design.build_path))
				continue
			output_units += output.amount
			TEST_ASSERT(container.insert_item(output) > 0, "The printed [design_id] must be accepted by real material intake")
		var/obj/item/stack/stack_type = design.build_path
		TEST_ASSERT_EQUAL(output_units, initial(stack_type.amount) * batch, "Production must create the full [design_id] order")
		for(var/material in before)
			TEST_ASSERT(container.materials[material] <= before[material], "Printing and recycling [design_id] created [container.materials[material] - before[material]] material")

/// Substitute only power availability; consumption, output creation and intake are real.
/obj/machinery/rnd/production/protolathe/launch_fabrication_test/directly_use_energy(amount, force = FALSE)
	return amount

/obj/machinery/rnd/production/protolathe/launch_fabrication_test/proc/print_test_design(datum/design/design, quantity)
	var/coefficient = call(src, TYPE_PROC_REF(/obj/machinery/rnd/production, build_efficiency))(design.build_path)
	call(src, TYPE_PROC_REF(/obj/machinery/rnd/production, do_make_item))(design, quantity, 1, coefficient, 1, get_turf(src), ID_DATA(null))

/// The product must keep the payment captured at job start, even after a part swap.
/datum/unit_test/voidcrew_launch_mechfab_recycling/Run()
	var/obj/machinery/mecha_part_fabricator/fabricator = allocate(/obj/machinery/mecha_part_fabricator)
	fabricator.rmat.set_local_size(1000 * SHEET_MATERIAL_AMOUNT)
	fabricator.drop_direction = 0
	var/obj/machinery/autolathe/recycler = allocate(/obj/machinery/autolathe)
	recycler.materials.max_amount = 1000 * SHEET_MATERIAL_AMOUNT
	var/datum/design/design = SSresearch.techweb_design_by_id("basic_cell")
	TEST_ASSERT_NOTNULL(design, "Basic cell must exist for the real mechfab regression")
	var/list/spent = list()
	for(var/material in design.materials)
		fabricator.rmat.mat_container.insert_amount_mat(1000, material)
		spent[material] = fabricator.rmat.mat_container.materials[material]
	fabricator.component_coeff = 0.55
	TEST_ASSERT(fabricator.build_part(design, FALSE), "Upgraded mechfab must start the cell job")
	for(var/material in spent)
		spent[material] -= fabricator.rmat.mat_container.materials[material]
	// Completing with different parts must not inflate the already-paid salvage.
	fabricator.component_coeff = 1
	TEST_ASSERT(fabricator.dispense_built_part(design), "The paid cell must be dispensed")
	var/obj/item/stock_parts/power_store/cell/empty/product = locate() in run_loc_floor_bottom_left
	TEST_ASSERT_NOTNULL(product, "Real production must create an empty cell")
	TEST_ASSERT_EQUAL(product.charge, 0, "Fabrication must not silently charge the cell")
	TEST_ASSERT(recycler.materials.insert_item(product) > 0, "The real recycler must consume the cell")
	for(var/material in spent)
		TEST_ASSERT(recycler.materials.materials[material] <= spent[material], "Mechfab cell recycling recovered more [material] than the job consumed")

/// Tiny ingredients must not become one unit per nested item through minimum rounding.
/datum/unit_test/voidcrew_launch_mechfab_nested_recycling/Run()
	var/obj/machinery/mecha_part_fabricator/fabricator = allocate(/obj/machinery/mecha_part_fabricator)
	fabricator.rmat.set_local_size(1000 * SHEET_MATERIAL_AMOUNT)
	fabricator.component_coeff = 0.55
	fabricator.drop_direction = 0
	var/obj/machinery/autolathe/recycler = allocate(/obj/machinery/autolathe)
	recycler.materials.max_amount = 1000 * SHEET_MATERIAL_AMOUNT
	var/datum/design/design = allocate(/datum/design)
	design.build_path = /obj/item/storage/box/launch_fabrication_package
	design.materials = list(GET_MATERIAL_REF(/datum/material/iron) = 100, GET_MATERIAL_REF(/datum/material/glass) = 4)
	var/list/spent = list()
	for(var/material in design.materials)
		fabricator.rmat.mat_container.insert_amount_mat(1000, material)
		spent[material] = fabricator.rmat.mat_container.materials[material]
	TEST_ASSERT(fabricator.build_part(design, FALSE), "Nested product must consume inputs")
	for(var/material in spent)
		spent[material] -= fabricator.rmat.mat_container.materials[material]
	TEST_ASSERT(fabricator.dispense_built_part(design), "Nested product must finish printing")
	var/obj/item/storage/box/launch_fabrication_package/product = locate() in run_loc_floor_bottom_left
	TEST_ASSERT_NOTNULL(product, "The actual fabrication path must create the nested package")
	var/list/items = product.get_all_contents_type(/obj/item)
	TEST_ASSERT(length(items) > 40, "The package must include nested cells, instantiated rounds and a cable stack")
	// Feed each real output through material_container, rather than summing custom_materials.
	// Move children out first because consuming a parent deletes its contents.
	for(var/obj/item/item as anything in items)
		item.forceMove(run_loc_floor_bottom_left)
	for(var/obj/item/item as anything in items)
		recycler.materials.insert_item(item)
	for(var/material in spent)
		TEST_ASSERT(recycler.materials.materials[material] <= spent[material], "Nested mechfab outputs recover more [material] than their captured inputs")
	for(var/material in recycler.materials.materials)
		TEST_ASSERT((recycler.materials.materials[material] || 0) <= (spent[material] || 0), "A nested output introduced an unpurchased material")

/obj/item/storage/box/launch_fabrication_package/PopulateContents()
	for(var/index in 1 to 10)
		new /obj/item/stock_parts/power_store/cell/empty(src)
	new /obj/item/ammo_box/c9mm(src)
	new /obj/item/stack/cable_coil/five(src)

/// Cheaper recovery boxes must still cost more iron than the box and every round return.
/datum/unit_test/voidcrew_launch_recovery_ammo_recycling/Run()
	var/obj/machinery/autolathe/launch_fabrication_test/lathe = allocate(/obj/machinery/autolathe/launch_fabrication_test)
	lathe.set_machine_stat(NONE)
	lathe.materials.max_amount = 1000 * SHEET_MATERIAL_AMOUNT
	var/datum/material/iron = GET_MATERIAL_REF(/datum/material/iron)
	for(var/design_id in list("c9mm", "c10mm", "c45"))
		var/datum/design/design = SSresearch.techweb_design_by_id(design_id)
		lathe.materials.insert_amount_mat(100 * SHEET_MATERIAL_AMOUNT, iron)
		var/before = lathe.materials.materials[iron]
		// The most efficient autolathe is the strongest recycling case.
		call(lathe, TYPE_PROC_REF(/obj/machinery/autolathe, do_make_item))(design, 1, 1, 1, 1, design.materials, run_loc_floor_bottom_left)
		var/obj/item/ammo_box/box = locate(design.build_path) in run_loc_floor_bottom_left
		TEST_ASSERT_NOTNULL(box, "Recovery ammunition must actually print")
		var/list/rounds = box.ammo_list()
		TEST_ASSERT_EQUAL(length(rounds), box.max_ammo, "The cheaper [design_id] recipe must retain its full round count")
		for(var/obj/item/ammo_casing/round as anything in rounds)
			round.forceMove(run_loc_floor_bottom_left)
			lathe.materials.insert_item(round)
		TEST_ASSERT(lathe.materials.insert_item(box) > 0, "The empty ammo box must reach actual recycling")
		TEST_ASSERT(lathe.materials.materials[iron] <= before, "Printing, emptying and recycling [design_id] must not create iron")

/obj/machinery/autolathe/launch_fabrication_test/directly_use_energy(amount, force = FALSE)
	return amount
