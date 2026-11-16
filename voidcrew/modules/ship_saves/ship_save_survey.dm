/// One priced kind of machine: the part class that pays for it, parts each, and its line on the bill.
/// With no label the line takes the machine's own name.
#define SHIP_SAVE_PRICE(part_class, each_machine, label_text) list("class" = part_class, "each" = each_machine, "label" = label_text)

/**
 * What upgraded machines cost to save, since their stock parts come back. A machine at stock parts, or one
 * not on this table, is free. Subtypes inherit, and a later,
 * more specific entry wins: a null takes a subtype back off the table.
 */
GLOBAL_LIST_INIT(ship_save_priced_machines, zebra_typecacheof(list(
	/obj/machinery/ship_combat/laser_turret = SHIP_SAVE_PRICE(PART_CLASS_COMBAT, 1, null),
	/obj/machinery/ship_combat/missile_launcher = SHIP_SAVE_PRICE(PART_CLASS_COMBAT, 1, null),
	/obj/machinery/ship_combat/pod_launcher = SHIP_SAVE_PRICE(PART_CLASS_COMBAT, 1, null),
	/obj/machinery/shuttle_scrambler/ship_siphon = SHIP_SAVE_PRICE(PART_CLASS_COMBAT, 1, "Ship siphon"),
	/obj/machinery/ship_combat/shield_generator = SHIP_SAVE_PRICE(PART_CLASS_COMBAT, 2, "Shield generator"),
	/obj/machinery/ship_combat/interdictor = SHIP_SAVE_PRICE(PART_CLASS_COMBAT, 2, null),
	/obj/machinery/ship_combat/cloak_device = SHIP_SAVE_PRICE(PART_CLASS_COMBAT, 2, null),
	/obj/machinery/ship_combat/ew_suite = SHIP_SAVE_PRICE(PART_CLASS_COMBAT, 2, null),
	/obj/machinery/porta_turret = SHIP_SAVE_PRICE(PART_CLASS_COMBAT, 0.5, "Defense turret"),

	/obj/machinery/rnd/production/protolathe = SHIP_SAVE_PRICE(PART_CLASS_SCIENCE, 1, "Protolathe"),
	/obj/machinery/rnd/production/circuit_imprinter = SHIP_SAVE_PRICE(PART_CLASS_SCIENCE, 1, "Circuit imprinter"),
	/obj/machinery/rnd/production/techfab = SHIP_SAVE_PRICE(PART_CLASS_SCIENCE, 1, "Techfab"),
	/obj/machinery/rnd/server = SHIP_SAVE_PRICE(PART_CLASS_SCIENCE, 1, "R&D server"),
	/obj/machinery/rnd/destructive_analyzer = SHIP_SAVE_PRICE(PART_CLASS_SCIENCE, 1, null),
	/obj/machinery/rnd/experimentor = SHIP_SAVE_PRICE(PART_CLASS_SCIENCE, 1, "Experimentor"),
	/obj/machinery/mecha_part_fabricator = SHIP_SAVE_PRICE(PART_CLASS_SCIENCE, 1, "Exosuit fabricator"),
	/obj/machinery/chem_dispenser = SHIP_SAVE_PRICE(PART_CLASS_SCIENCE, 1, "Chem dispenser"),
	/obj/machinery/chem_dispenser/drinks = null,
	/obj/machinery/chem_master = SHIP_SAVE_PRICE(PART_CLASS_SCIENCE, 1, "ChemMaster"),
	/obj/machinery/chem_master/condimaster = null,
	/obj/machinery/nanite_chamber = SHIP_SAVE_PRICE(PART_CLASS_SCIENCE, 1, "Nanite chamber"),
	/obj/machinery/public_nanite_chamber = SHIP_SAVE_PRICE(PART_CLASS_SCIENCE, 1, "Nanite chamber"),
	/obj/machinery/computer/nanite_cloud_controller = SHIP_SAVE_PRICE(PART_CLASS_SCIENCE, 1, null),
	/obj/machinery/dna_scannernew = SHIP_SAVE_PRICE(PART_CLASS_SCIENCE, 1, null),
	/obj/machinery/processor/slime = SHIP_SAVE_PRICE(PART_CLASS_SCIENCE, 1, null),
	/obj/machinery/quantum_server = SHIP_SAVE_PRICE(PART_CLASS_SCIENCE, 1, null),

	/obj/machinery/computer/voidcrew_cargo = SHIP_SAVE_PRICE(PART_CLASS_TRADE, 1, "Cargo console"),
	/obj/machinery/computer/cargo = SHIP_SAVE_PRICE(PART_CLASS_TRADE, 1, "Cargo console"),
	/obj/machinery/mineral/ore_redemption = SHIP_SAVE_PRICE(PART_CLASS_TRADE, 1, "Ore redemption machine"),
	/obj/machinery/ore_silo = SHIP_SAVE_PRICE(PART_CLASS_TRADE, 1, null),
	/obj/machinery/computer/order_console/mining = SHIP_SAVE_PRICE(PART_CLASS_TRADE, 1, "Mining order console"),
	/obj/machinery/piratepad = SHIP_SAVE_PRICE(PART_CLASS_TRADE, 1, "Pirate pad"),
), clear_nulls = TRUE))

#undef SHIP_SAVE_PRICE

/// The bill's name for a priced machine. Never the instance's: players can rename those.
/proc/ship_save_machine_line_name(list/price, obj/machinery/machine_type)
	return price["label"] || capitalize(ship_save_plain_text(initial(machine_type.name)))

/**
 * What a save of this hull would keep and cost, from one walk of its owned tiles. Doesn't sleep, because
 * ui_data calls it through /obj/structure/overmap/ship/proc/save_survey(). Null if the hull is gone.
 */
/proc/ship_save_survey(obj/docking_port/mobile/voidcrew/port)
	SHOULD_NOT_SLEEP(TRUE)
	if(QDELETED(port) || !port.z)
		return null
	var/list/bounds = port.return_coords()
	var/turf/corner = locate(min(bounds[1], bounds[3]), min(bounds[2], bounds[4]), port.z)
	if(!corner)
		return null
	var/list/rooms = list()
	for(var/area/room as anything in hull_owned_areas(port))
		rooms[room] = TRUE
	return ship_save_survey_block(corner, abs(bounds[3] - bounds[1]) + 1, abs(bounds[4] - bounds[2]) + 1, rooms, port.current_ship?.job_definitions)

/**
 * The walk itself, over any block of tiles. rooms is area -> TRUE for the areas that are part of the hull.
 * Returns mass, crew, plan, bill and total for the screens, and cost (class -> parts) for spend_parts().
 */
/proc/ship_save_survey_block(turf/corner, width, height, list/rooms, list/job_definitions)
	SHOULD_NOT_SLEEP(TRUE)
	// Highest priority first, for a tile holding several.
	var/static/list/plan_rank = list("w" = 1, "s" = 2, "t" = 3, "e" = 4, "#" = 5, "g" = 6, "o" = 7)
	var/static/list/class_mark = list(PART_CLASS_COMBAT = "w", PART_CLASS_SCIENCE = "s", PART_CLASS_TRADE = "t")
	var/mass = 0
	var/research_nodes = 0
	/// Line name -> list("class", "each", "count")
	var/list/lines = list()
	var/list/plan_rows = list()
	for(var/offset_y in (height - 1) to 0 step -1)
		var/list/plan_row = list()
		for(var/offset_x in 0 to (width - 1))
			var/turf/tile = locate(corner.x + offset_x, corner.y + offset_y, corner.z)
			if(!tile || !rooms[tile.loc])
				plan_row += "."
				continue
			mass += get_turf_mass_weight_instance(tile)
			var/mark = isclosedturf(tile) ? "#" : "o"
			for(var/obj/object in tile)
				if(!ship_save_keeps_object(object))
					continue
				var/object_mark
				if(istype(object, /obj/structure/window) || istype(object, /obj/structure/grille))
					object_mark = "g"
				else if(ismachinery(object))
					var/obj/machinery/machine = object
					// What comes back, which is what gets paid for: a machine rebuilds as its board's product.
					var/saved_type = machine.checkpoint_type()
					var/list/price = GLOB.ship_save_priced_machines[saved_type]
					// A stock machine comes back the same for free. Only upgrades are paid for, because only they carry.
					if(price && ship_save_machine_upgraded(machine))
						var/line_name = ship_save_machine_line_name(price, saved_type)
						var/list/line = lines[line_name]
						if(!line)
							line = list("class" = price["class"], "each" = price["each"], "count" = 0)
							lines[line_name] = line
						line["count"]++
					if(price)
						object_mark = class_mark[price["class"]]
					else if(istype(machine, /obj/machinery/power/shuttle_engine))
						object_mark = "e"
					if(istype(machine, /obj/machinery/rnd/server/ship))
						var/obj/machinery/rnd/server/ship/server = machine
						research_nodes = max(research_nodes, server.saved_research_count())
				if(object_mark && plan_rank[object_mark] < plan_rank[mark])
					mark = object_mark
			plan_row += mark
		plan_rows += list(plan_row)
	var/crew = 0
	for(var/list/definition in job_definitions)
		crew += definition["slots"] || 1
	var/list/survey = ship_save_price_bill(lines, mass, research_nodes)
	survey["research"] = research_nodes
	survey["mass"] = mass
	survey["crew"] = crew
	survey["plan"] = ship_save_encode_plan(plan_rows)
	return survey

/// Rounds each line up and adds them into bill, total and cost.
/proc/ship_save_price_bill(list/lines, mass, research_nodes = 0)
	SHOULD_NOT_SLEEP(TRUE)
	var/list/items_by_class = list()
	var/total = 0
	for(var/part_class in GLOB.ship_part_classes)
		items_by_class[part_class] = list()
	for(var/line_name in lines)
		var/list/line = lines[line_name]
		var/parts = CEILING(line["count"] * line["each"], 1)
		items_by_class[line["class"]] += list(list("name" = line_name, "count" = line["count"], "parts" = parts))
		total += parts
	if(research_nodes > 0)
		var/research_parts = CEILING(research_nodes / SHIP_SAVE_NODES_PER_PART, 1)
		items_by_class[PART_CLASS_SCIENCE] += list(list("name" = "Research, [research_nodes] nodes", "count" = null, "parts" = research_parts, "carry" = 1))
		total += research_parts
	// Machines and research together never cost more than SHIP_SAVE_PRICE_MAX. The biggest class gives first.
	if(total > SHIP_SAVE_PRICE_MAX)
		var/list/class_parts = list()
		for(var/part_class in items_by_class)
			for(var/list/item as anything in items_by_class[part_class])
				class_parts[part_class] += item["parts"]
		var/list/discount = list()
		while(total > SHIP_SAVE_PRICE_MAX)
			var/biggest
			for(var/part_class in GLOB.ship_part_classes)
				if(class_parts[part_class] - discount[part_class] > (biggest ? class_parts[biggest] - discount[biggest] : 0))
					biggest = part_class
			discount[biggest]++
			total--
		for(var/part_class in discount)
			items_by_class[part_class] += list(list("name" = "Yard discount", "count" = null, "parts" = -discount[part_class]))
	var/list/misc_items = items_by_class[PART_CLASS_MISC]
	var/hull_parts = CEILING(mass / SHIP_SAVE_MASS_PER_PART, 1)
	if(hull_parts)
		misc_items += list(list("name" = "Hull, [mass] t", "count" = null, "parts" = hull_parts))
		total += hull_parts
	if(total < SHIP_SAVE_PRICE_MIN)
		misc_items += list(list("name" = "Yard minimum", "count" = null, "parts" = SHIP_SAVE_PRICE_MIN - total))
		total = SHIP_SAVE_PRICE_MIN
	var/list/bill = list()
	var/list/cost = list()
	for(var/part_class in GLOB.ship_part_classes)
		var/list/items = items_by_class[part_class]
		if(!length(items))
			continue
		var/class_parts = 0
		for(var/list/item as anything in items)
			class_parts += item["parts"]
		sortTim(items, GLOBAL_PROC_REF(cmp_ship_save_bill_line))
		bill += list(list("class" = part_class, "parts" = class_parts, "items" = items))
		cost[part_class] = class_parts
	return list("bill" = bill, "total" = total, "cost" = cost)

/// Biggest first, then by name so the order doesn't jump around between refreshes.
/proc/cmp_ship_save_bill_line(list/line_a, list/line_b)
	return (line_b["parts"] - line_a["parts"]) || sorttext(line_b["name"], line_a["name"])

/**
 * Rows of one-character marks, top row first, into the text the screens draw: rows of runs joined by "/",
 * where a run is an optional count and one character. Empties at the end of a row and empty rows at the top
 * and bottom are trimmed. Null if there is nothing to draw or it comes out too long to send.
 */
/proc/ship_save_encode_plan(list/rows)
	SHOULD_NOT_SLEEP(TRUE)
	var/list/encoded = list()
	for(var/list/row as anything in rows)
		encoded += ship_save_encode_plan_row(row)
	while(length(encoded) && !length(encoded[1]))
		encoded.Cut(1, 2)
	while(length(encoded) && !length(encoded[length(encoded)]))
		encoded.Cut(length(encoded))
	if(!length(encoded))
		return null
	var/plan = encoded.Join("/")
	return length(plan) > SHIP_SAVE_PLAN_MAX_LENGTH ? null : plan

/proc/ship_save_encode_plan_row(list/row)
	SHOULD_NOT_SLEEP(TRUE)
	var/last = length(row)
	while(last && row[last] == ".")
		last--
	var/list/runs = list()
	var/start = 1
	while(start <= last)
		var/mark = row[start]
		var/stop = start
		while(stop < last && row[stop + 1] == mark)
			stop++
		runs += stop > start ? "[stop - start + 1][mark]" : mark
		start = stop + 1
	return runs.Join()

/// Copies the survey's keys for the screens onto an entry, leaving out what it charges.
/proc/ship_save_add_survey(list/entry, list/survey)
	for(var/key in survey)
		if(key != "cost")
			entry[key] = survey[key]
	return entry

/// The summary column back into a survey. Anything that isn't one, including bad JSON, reads as no survey.
/proc/ship_save_read_summary(text)
	if(!istext(text))
		return null
	var/list/survey = safe_json_decode(text)
	if(!islist(survey) || !isnum(survey["mass"]) || !isnum(survey["crew"]) || !isnum(survey["total"]) || !islist(survey["bill"]))
		return null
	var/plan = survey["plan"]
	return list("mass" = survey["mass"], "crew" = survey["crew"], "plan" = istext(plan) ? plan : null, "bill" = survey["bill"], "total" = survey["total"], "research" = isnum(survey["research"]) ? survey["research"] : 0, "funds" = isnum(survey["funds"]) ? survey["funds"] : 0)

/// "3 combat, 4 science and 7 misc parts"
/proc/ship_save_cost_text(list/cost)
	var/list/amounts = list()
	for(var/part_class in cost)
		amounts += "[cost[part_class]] [part_class]"
	return "[english_list(amounts)] parts"

/// One way to pay for a save: list("parts" = class -> parts, "credits" = credits, "short" = class -> parts
/// missing). Only misc parts can be paid in credits. Uses the misc parts held first, or all_credits uses none.
/proc/ship_save_payment(list/cost, list/held, all_credits = FALSE)
	var/list/parts = list()
	var/list/short = list()
	var/credits = 0
	for(var/part_class in cost)
		var/due = cost[part_class]
		var/used = min(due, held?[part_class] || 0)
		if(part_class == PART_CLASS_MISC)
			if(all_credits)
				used = 0
			credits += (due - used) * SHIP_SAVE_CREDITS_PER_PART
		else if(due > used)
			short[part_class] = due - used
		if(used)
			parts[part_class] = used
	return list("parts" = parts, "credits" = credits, "short" = short)

/**
 * The ways a captain can afford to pay for a save, as button label -> payment, parts first. Empty if there
 * are none. Only the hull's misc parts ever have a choice, so with none on the bill there is only one way.
 */
/proc/ship_save_payment_options(list/cost, list/held, balance)
	var/list/options = list()
	var/list/first = ship_save_payment(cost, held)
	if(length(first["short"]))
		return options
	if(balance >= first["credits"])
		options[ship_save_payment_label(first)] = first
	var/list/second = ship_save_payment(cost, held, all_credits = TRUE)
	if(second["credits"] != first["credits"] && balance >= second["credits"])
		var/label = ship_save_payment_label(second)
		// Both can use parts and credits, when the misc parts held only cover some of the hull.
		options[options[label] ? "Hull in credits" : label] = second
	return options

/proc/ship_save_payment_label(list/payment)
	if(!payment["credits"])
		return "Parts"
	return length(payment["parts"]) ? "Parts and credits" : "Credits"

/// Why nothing in ship_save_payment_options() can be paid.
/proc/ship_save_payment_denial(list/cost, list/held)
	var/list/payment = ship_save_payment(cost, held)
	if(length(payment["short"]))
		return "You need [ship_save_cost_text(payment["short"])]."
	return "You need [ship_save_credits_text(payment["credits"])]."

/// "1 combat and 2 misc parts and 7,500 cr"
/proc/ship_save_payment_text(list/payment)
	var/list/amounts = list()
	if(length(payment["parts"]))
		amounts += ship_save_cost_text(payment["parts"])
	if(payment["credits"])
		amounts += ship_save_credits_text(payment["credits"])
	return amounts.Join(" and ")

/// "15,000 cr"
/proc/ship_save_credits_text(credits)
	var/digits = num2text(credits, 12)
	var/list/groups = list()
	while(length(digits) > 3)
		groups.Insert(1, copytext(digits, -3))
		digits = copytext(digits, 1, -3)
	groups.Insert(1, digits)
	return "[groups.Join(",")] cr"

/// A copy of a survey with funds on its bill, which the screen adds the same way. The survey itself is cached.
/proc/ship_save_add_funds(list/survey, funds_parts)
	if(funds_parts <= 0)
		return survey
	var/funds = funds_parts * SHIP_SAVE_FUNDS_PER_TRADE_PART
	var/list/line = list("name" = "Funds, [ship_save_credits_text(funds)]", "count" = null, "parts" = funds_parts, "carry" = 1)
	var/list/old_bill = survey["bill"]
	var/list/entries = list()
	for(var/list/entry as anything in old_bill)
		entries[entry["class"]] = entry
	var/list/trade_entry = entries[PART_CLASS_TRADE]
	var/list/trade_items = trade_entry ? trade_entry["items"] : list()
	trade_items = trade_items.Copy()
	trade_items += list(line)
	sortTim(trade_items, GLOBAL_PROC_REF(cmp_ship_save_bill_line))
	entries[PART_CLASS_TRADE] = list("class" = PART_CLASS_TRADE, "parts" = (trade_entry?["parts"] || 0) + funds_parts, "items" = trade_items)
	var/list/bill = list()
	for(var/part_class in GLOB.ship_part_classes)
		if(entries[part_class])
			bill += list(entries[part_class])
	var/list/cost = survey["cost"]
	cost = cost.Copy()
	cost[PART_CLASS_TRADE] += funds_parts
	var/list/priced = survey.Copy()
	priced["bill"] = bill
	priced["cost"] = cost
	priced["total"] = survey["total"] + funds_parts
	priced["funds"] = funds
	return priced

/obj/structure/overmap/ship
	/// This hull's last ship_save_survey(), so an open window doesn't rescan it every tick.
	var/list/save_survey_cache
	/// When that survey was taken.
	var/save_survey_taken = 0

/// This hull's survey, at most SHIP_SAVE_SURVEY_LIFE old unless it is about to be paid for.
/obj/structure/overmap/ship/proc/save_survey(fresh = FALSE)
	SHOULD_NOT_SLEEP(TRUE)
	if(fresh || !save_survey_cache || world.time >= save_survey_taken + SHIP_SAVE_SURVEY_LIFE)
		save_survey_cache = ship_save_survey(shuttle)
		save_survey_taken = world.time
	return save_survey_cache
