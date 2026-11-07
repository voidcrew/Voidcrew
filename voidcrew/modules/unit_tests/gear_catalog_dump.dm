/**
 * Item catalog dump, off by default.
 *
 * Compile with -DCIBUILDING -DGEAR_CATALOG_DUMP and this replaces the whole test run: it creates every
 * /obj/item type the way create_and_destroy does, skipping the same uncreatables, and appends one
 * JSON line per type to data/gear_catalog/dump.jsonl. tools/gear_catalog runs the world and reads that file.
 * Without the define this file compiles to nothing.
 *
 * Creation is deliberately not inside a try block. stack_trace() is a CRASH(), which on its own ends only
 * its own frame, but inside a try it unwinds into the catch and leaves the item half built. A runtime reaches
 * Fail() through the error handler instead, and is harvested into the row of the type being created.
 */
#ifdef GEAR_CATALOG_DUMP

#define GEAR_CATALOG_DIR "data/gear_catalog/"
#define GEAR_CATALOG_OUTPUT (GEAR_CATALOG_DIR + "dump.jsonl")
#define GEAR_CATALOG_DONE (GEAR_CATALOG_DIR + "done.txt")
#define GEAR_CATALOG_CURRENT (GEAR_CATALOG_DIR + "current.txt")
/// How deep to follow nested lists
#define GEAR_CATALOG_LIST_DEPTH 4
/// How many entries of one list to keep
#define GEAR_CATALOG_LIST_CAP 256

/// While dumping: every AddElement call, as list(target, arguments). Null otherwise.
GLOBAL_VAR(gear_catalog_element_log)

/datum/_AddElement(list/arguments)
	if(GLOB.gear_catalog_element_log)
		GLOB.gear_catalog_element_log += list(list(src, arguments.Copy()))
	return ..()

/datum/unit_test/gear_catalog_dump
	focus = TRUE
	/// Where everything is created
	var/turf/spawn_at
	/// Var name to JSON text of the base /obj/item value
	var/list/item_base = list()
	/// Var name to JSON text of the base /obj/projectile value
	var/list/projectile_base = list()
	/// Casing type to its facts
	var/list/casing_cache = list()
	/// Projectile type to its facts
	var/list/projectile_cache = list()

/datum/unit_test/gear_catalog_dump/Run()
	spawn_at = run_loc_floor_bottom_left
	var/list/cached_contents = spawn_at.contents.Copy()
	var/start_time = REALTIMEOFDAY

	// Nothing here waits on deletes, and hard delete lookups take far longer than the dump.
	SSgarbage.can_fire = FALSE
	GLOB.running_create_and_destroy = TRUE

	var/list/uncreatable_lookup = list()
	for(var/path in uncreatables)
		uncreatable_lookup[path] = TRUE

	var/obj/item/base_item = new /obj/item(spawn_at)
	var/obj/projectile/base_projectile = new /obj/projectile(spawn_at)
	cached_contents += base_item
	cached_contents += base_projectile
	item_base = base_values(base_item)
	projectile_base = base_values(base_projectile)

	// A world that dies part way can be started again and carries on from where it stopped.
	rustg_file_write("", GEAR_CATALOG_DIR + ".keep")
	var/list/done = list()
	var/crashed_on
	if(rustg_file_exists(GEAR_CATALOG_DONE))
		for(var/line in splittext(rustg_file_read(GEAR_CATALOG_DONE), "\n"))
			if(line)
				done[line] = TRUE
	if(rustg_file_exists(GEAR_CATALOG_CURRENT))
		crashed_on = rustg_file_read(GEAR_CATALOG_CURRENT)
	if(!length(done))
		write_row(meta_row())

	var/list/counts = list()
	for(var/type_path in typesof(/obj/item))
		var/path_text = "[type_path]"
		if(done[path_text])
			continue
		rustg_file_write(path_text, GEAR_CATALOG_CURRENT)
		var/list/row
		if(crashed_on == path_text)
			row = list("path" = path_text, "status" = "error", "runtimes" = list("the world died while creating this type"))
		else
			row = record_type(type_path, uncreatable_lookup[type_path])
		// A runtime in the recording itself ends record_type() and lands here with nothing to write.
		if(!islist(row))
			row = list("path" = path_text, "status" = "error", "runtimes" = harvest_runtimes())
		write_row(row)
		rustg_file_append("[path_text]\n", GEAR_CATALOG_DONE)
		counts[row["status"]]++

		var/list/to_del = spawn_at.contents - cached_contents
		for(var/atom/to_kill in to_del)
			qdel(to_kill, force = TRUE)
		CHECK_TICK

	GLOB.running_create_and_destroy = FALSE
	GLOB.gear_catalog_element_log = null
	rustg_file_write("", GEAR_CATALOG_CURRENT)
	write_row(list("summary" = TRUE, "seconds" = (REALTIMEOFDAY - start_time) / 10, "counts" = counts))
	log_world("gear catalog dump finished: [json_encode(counts)]")

/datum/unit_test/gear_catalog_dump/proc/write_row(list/row)
	rustg_file_append("[json_encode(row)]\n", GEAR_CATALOG_OUTPUT)

/// Constants the scripts need to read the numbers, taken from the compiled game rather than from source.
/datum/unit_test/gear_catalog_dump/proc/meta_row()
	return list(
		"meta" = TRUE,
		"byond" = "[world.byond_version].[world.byond_build]",
		"click_cd_range" = CLICK_CD_RANGE,
		"click_cd_melee" = CLICK_CD_MELEE,
		"armor_weakened_multiplier" = ARMOR_WEAKENED_MULTIPLIER,
		"armor_max_block" = ARMOR_MAX_BLOCK,
		"body_parts" = list(
			"CHEST" = CHEST,
			"GROIN" = GROIN,
			"HEAD" = HEAD,
			"LEG_LEFT" = LEG_LEFT,
			"LEG_RIGHT" = LEG_RIGHT,
			"FOOT_LEFT" = FOOT_LEFT,
			"FOOT_RIGHT" = FOOT_RIGHT,
			"ARM_LEFT" = ARM_LEFT,
			"ARM_RIGHT" = ARM_RIGHT,
			"HAND_LEFT" = HAND_LEFT,
			"HAND_RIGHT" = HAND_RIGHT,
			"NECK" = NECK,
		),
		"slot_flags" = list(
			"OCLOTHING" = ITEM_SLOT_OCLOTHING,
			"ICLOTHING" = ITEM_SLOT_ICLOTHING,
			"GLOVES" = ITEM_SLOT_GLOVES,
			"EYES" = ITEM_SLOT_EYES,
			"EARS" = ITEM_SLOT_EARS,
			"MASK" = ITEM_SLOT_MASK,
			"HEAD" = ITEM_SLOT_HEAD,
			"FEET" = ITEM_SLOT_FEET,
			"ID" = ITEM_SLOT_ID,
			"BELT" = ITEM_SLOT_BELT,
			"BACK" = ITEM_SLOT_BACK,
			"NECK" = ITEM_SLOT_NECK,
			"SUITSTORE" = ITEM_SLOT_SUITSTORE,
			"LPOCKET" = ITEM_SLOT_LPOCKET,
			"RPOCKET" = ITEM_SLOT_RPOCKET,
		),
		"flags_cover" = list(
			"GLASSESCOVERSEYES" = GLASSESCOVERSEYES,
			"MASKCOVERSEYES" = MASKCOVERSEYES,
			"HEADCOVERSEYES" = HEADCOVERSEYES,
			"MASKCOVERSMOUTH" = MASKCOVERSMOUTH,
			"HEADCOVERSMOUTH" = HEADCOVERSMOUTH,
			"PEPPERPROOF" = PEPPERPROOF,
			"EARS_COVERED" = EARS_COVERED,
		),
		"mod_module_type" = list(
			"[MODULE_PASSIVE]" = "passive",
			"[MODULE_USABLE]" = "usable",
			"[MODULE_TOGGLE]" = "toggle",
			"[MODULE_ACTIVE]" = "active",
		),
		"mod_allow_flags" = list(
			"PHASEOUT" = MODULE_ALLOW_PHASEOUT,
			"INCAPACITATED" = MODULE_ALLOW_INCAPACITATED,
			"INACTIVE" = MODULE_ALLOW_INACTIVE,
		),
		"bitfields" = gear_catalog_bitfields(),
		"sight_flags" = list(
			"SEE_INFRA" = SEE_INFRA,
			"SEE_SELF" = SEE_SELF,
			"SEE_MOBS" = SEE_MOBS,
			"SEE_OBJS" = SEE_OBJS,
			"SEE_TURFS" = SEE_TURFS,
			"SEE_PIXELS" = SEE_PIXELS,
			"SEE_THRU" = SEE_THRU,
			"SEE_BLACKNESS" = SEE_BLACKNESS,
			"BLIND" = BLIND,
		),
		"weapon_weight" = list("WEAPON_LIGHT" = WEAPON_LIGHT, "WEAPON_MEDIUM" = WEAPON_MEDIUM, "WEAPON_HEAVY" = WEAPON_HEAVY),
		"bolt_type" = list(
			"BOLT_TYPE_STANDARD" = BOLT_TYPE_STANDARD,
			"BOLT_TYPE_OPEN" = BOLT_TYPE_OPEN,
			"BOLT_TYPE_NO_BOLT" = BOLT_TYPE_NO_BOLT,
			"BOLT_TYPE_LOCKING" = BOLT_TYPE_LOCKING,
		),
		"weight_class" = list(
			"[WEIGHT_CLASS_TINY]" = "tiny",
			"[WEIGHT_CLASS_SMALL]" = "small",
			"[WEIGHT_CLASS_NORMAL]" = "normal",
			"[WEIGHT_CLASS_BULKY]" = "bulky",
			"[WEIGHT_CLASS_HUGE]" = "huge",
			"[WEIGHT_CLASS_GIGANTIC]" = "gigantic",
		),
		"see_invisible_living" = SEE_INVISIBLE_LIVING,
		"item_base" = item_base,
		"projectile_base" = projectile_base,
	)

/datum/unit_test/gear_catalog_dump/proc/record_type(type_path, uncreatable)
	var/obj/item/proto = type_path
	var/list/row = list(
		"path" = "[type_path]",
		"parent" = "[initial(proto.parent_type)]",
		"name" = gear_catalog_text(initial(proto.name)),
		"desc" = gear_catalog_text(initial(proto.desc)),
		"status" = "ok",
	)
	if(uncreatable)
		row["status"] = "uncreatable"
		return row

	// Random names and offsets come out the same every run, whatever else changed in the game.
	rand_seed(text2num(copytext(md5("[type_path]"), 1, 7), 16))
	GLOB.gear_catalog_element_log = list()
	fail_reasons = null

	var/list/before = spawn_at.contents.Copy()
	var/atom/creation = new type_path(spawn_at)
	var/list/runtimes = harvest_runtimes()

	var/list/spawned = spawn_at.contents - before
	spawned -= creation
	if(length(spawned))
		row["spawned"] = gear_catalog_type_counts(spawned)

	if(isnull(creation))
		row["status"] = "error"
	else if(QDELETED(creation))
		row["status"] = length(runtimes) ? "error" : "self_deleted"
	else
		if(length(runtimes))
			row["status"] = "error"
		read_item(creation, row)
		runtimes += harvest_runtimes()
		qdel(creation, force = TRUE)
		creation = null
		// Runtimes on the way out are not creation failures.
		var/list/delete_runtimes = harvest_runtimes()
		if(length(delete_runtimes))
			row["delete_runtimes"] = delete_runtimes

	if(length(runtimes))
		row["runtimes"] = runtimes
	return row

/// Takes everything the error handler reported since the last call. First line only: the rest is a stack.
/datum/unit_test/gear_catalog_dump/proc/harvest_runtimes()
	var/list/found = list()
	for(var/list/reason as anything in fail_reasons)
		var/list/lines = splittext("[reason[1]]", "\n")
		found += copytext(lines[1], 1, 400)
	fail_reasons = null
	return found

/datum/unit_test/gear_catalog_dump/proc/read_item(obj/item/item, list/row)
	var/list/errors = list()

	row["icon"] = "[item.icon]"
	row["icon_state"] = item.icon_state
	row["no_sprite"] = !icon_exists(item.icon, item.icon_state)

	try
		var/list/refs = list()
		row["vars"] = diff_vars(item, item_base, refs)
		row["refs"] = refs
	catch(var/exception/vars_error)
		errors += "vars: [vars_error]"

	try
		var/list/parts = read_components(item)
		if(length(parts))
			row["components"] = parts
		parts = read_elements(item)
		if(length(parts))
			row["elements"] = parts
		if(length(item._status_traits))
			var/list/traits = list()
			for(var/trait in item._status_traits)
				traits += "[trait]"
			row["traits"] = traits
		if(length(item.actions))
			var/list/action_types = list()
			for(var/datum/action/action as anything in item.actions)
				action_types += "[action.type]"
			row["actions"] = action_types
		if(length(item.contents))
			row["contents"] = gear_catalog_type_counts(item.contents)
	catch(var/exception/parts_error)
		errors += "parts: [parts_error]"

	try
		var/datum/armor/armor = item.get_armor()
		if(armor)
			var/list/ratings = armor.get_rating_list()
			var/any_rating = FALSE
			for(var/rating in ratings)
				if(ratings[rating])
					any_rating = TRUE
					break
			if(any_rating)
				ratings["type"] = "[armor.type]"
				row["armor"] = ratings
	catch(var/exception/armor_error)
		errors += "armor: [armor_error]"

	try
		if(item.atom_storage)
			row["storage"] = gear_catalog_read(item.atom_storage, list(
				"max_slots",
				"max_specific_storage",
				"max_total_storage",
				"locked",
				"numerical_stacking",
				"insert_preposition",
			))
		if(istype(item, /obj/item/gun))
			row["gun"] = read_gun(item)
		if(istype(item, /obj/item/ammo_box))
			row["ammo_box"] = read_ammo_box(item)
		if(istype(item, /obj/item/ammo_casing))
			row["casing"] = read_casing(item.type)
		if(istype(item, /obj/item/clothing))
			row["clothing"] = read_clothing(item)
	catch(var/exception/section_error)
		errors += "sections: [section_error]"

	try
		if(length(item.actions_types))
			row["action_types"] = gear_catalog_simple(item.actions_types)
		var/datum/embedding/embed = item.get_embed()
		if(embed)
			var/list/embed_facts = gear_catalog_read(embed, list(
				"embed_chance",
				"fall_chance",
				"pain_chance",
				"pain_mult",
				"impact_pain_mult",
				"remove_pain_mult",
				"rip_time",
				"ignore_throwspeed_threshold",
				"jostle_chance",
				"jostle_pain_mult",
				"pain_stam_pct",
			))
			embed_facts["type"] = "[embed.type]"
			row["embed"] = embed_facts
		if(item.reagents)
			row["reagents"] = read_reagents(item.reagents)
		var/list/inner = list()
		for(var/atom/movable/thing as anything in item.contents)
			if(thing.reagents?.total_volume)
				var/list/held = read_reagents(thing.reagents)
				held["type"] = "[thing.type]"
				inner += list(held)
		if(length(inner))
			row["inner_reagents"] = inner
	catch(var/exception/extras_error)
		errors += "extras: [extras_error]"

	try
		var/obj/item/stock_parts/power_store/cell = item.get_cell()
		if(istype(cell))
			row["cell"] = list("type" = "[cell.type]", "maxcharge" = cell.maxcharge, "charge" = cell.charge())
	catch(var/exception/cell_error)
		errors += "cell: [cell_error]"

	try
		if(istype(item, /obj/item/mod/control))
			row["mod_theme"] = read_mod_theme(item)
		if(istype(item, /obj/item/mecha_parts/mecha_equipment/weapon))
			var/obj/item/mecha_parts/mecha_equipment/weapon/weapon = item
			if(ispath(weapon.projectile, /obj/projectile))
				row["mech_projectile"] = read_projectile_type(weapon.projectile)
	catch(var/exception/gear_error)
		errors += "gear: [gear_error]"

	if(length(errors))
		row["section_errors"] = errors

/// Every usable var of a thing, as var name to JSON text, for comparing against
/datum/unit_test/gear_catalog_dump/proc/base_values(datum/thing)
	var/list/values = list()
	for(var/name in thing.vars)
		if(GLOB.gear_catalog_skipped_vars[name])
			continue
		values[name] = json_encode(list(gear_catalog_simple(thing.vars[name])))
	return values

/// Vars that differ from the base. Vars the base doesn't have count when they hold anything at all.
/datum/unit_test/gear_catalog_dump/proc/diff_vars(datum/thing, list/base, list/refs)
	var/list/found = list()
	for(var/name in thing.vars)
		if(GLOB.gear_catalog_skipped_vars[name])
			continue
		var/raw = thing.vars[name]
		var/value = gear_catalog_simple(raw)
		var/in_base = (name in base)
		if(!in_base && !value)
			continue
		if(in_base && base[name] == json_encode(list(value)))
			continue
		if(istype(raw, /datum) && refs)
			refs[name] = value
			continue
		found[name] = value
	return found

/datum/unit_test/gear_catalog_dump/proc/read_components(datum/thing)
	var/list/found = list()
	var/list/seen = list()
	for(var/key in thing._datum_components)
		var/entry = thing._datum_components[key]
		var/list/instances = islist(entry) ? entry : list(entry)
		for(var/datum/component/component as anything in instances)
			if(seen[component])
				continue
			seen[component] = TRUE
			found += list(list("type" = "[component.type]", "vars" = diff_vars(component, list(), null)))
	return found

/datum/unit_test/gear_catalog_dump/proc/read_elements(datum/thing)
	var/list/found = list()
	for(var/list/entry as anything in GLOB.gear_catalog_element_log)
		if(entry[1] != thing)
			continue
		var/list/arguments = entry[2]
		var/list/element = list("type" = "[arguments[1]]")
		if(length(arguments) > 1)
			element["args"] = gear_catalog_simple(arguments.Copy(2))
		found += list(element)
	return found

/datum/unit_test/gear_catalog_dump/proc/read_gun(obj/item/gun/gun)
	var/list/facts = gear_catalog_read(gun, list(
		"fire_delay",
		"burst_size",
		"burst_delay",
		"spread",
		"randomspread",
		"recoil",
		"weapon_weight",
		"w_class",
		"dual_wield_spread",
		"can_suppress",
		"can_unsuppress",
		"suppressed",
		"projectile_damage_multiplier",
		"projectile_wound_bonus",
		"projectile_speed_multiplier",
		"pb_knockback",
		"pin",
		"pinless",
		"can_hold_up",
		"sawn_off",
		"force",
		"slowdown",
	))

	var/datum/component/automatic_fire/autofire = gun.GetComponent(/datum/component/automatic_fire)
	if(autofire)
		facts["autofire_shot_delay"] = autofire.autofire_shot_delay
		facts["autofire_windup"] = autofire.windup_autofire
	var/datum/component/two_handed/two_handed = gun.GetComponent(/datum/component/two_handed)
	if(two_handed)
		facts["two_handed"] = gear_catalog_read(two_handed, list("require_twohands", "force_wielded", "force_unwielded"))

	if(istype(gun, /obj/item/gun/ballistic))
		var/obj/item/gun/ballistic/ballistic = gun
		facts["kind"] = "ballistic"
		facts += gear_catalog_read(ballistic, list(
			"accepted_magazine_type",
			"spawn_magazine_type",
			"spawnwithmagazine",
			"internal_magazine",
			"bolt_type",
			"semi_auto",
			"rack_delay",
			"tac_reloads",
			"can_be_sawn_off",
			"special_mags",
			"must_hold_to_load",
			"can_modify_ammo",
			"initial_caliber",
			"alternative_caliber",
			"can_misfire",
			"misfire_probability",
			"misfire_percentage_increment",
			"burst_fire_selection",
		))
		if(ballistic.magazine)
			facts["magazine"] = read_ammo_box(ballistic.magazine)
		else if(ballistic.spawn_magazine_type)
			var/obj/item/ammo_box/spare = new ballistic.spawn_magazine_type(spawn_at)
			facts["magazine"] = read_ammo_box(spare)
			qdel(spare, force = TRUE)
		if(ballistic.accepted_magazine_type && !ballistic.internal_magazine)
			var/list/spares = list()
			for(var/spare_type in typesof(ballistic.accepted_magazine_type))
				spares += "[spare_type]"
			facts["spare_magazines"] = spares
	else if(istype(gun, /obj/item/gun/energy))
		var/obj/item/gun/energy/energy = gun
		facts["kind"] = "energy"
		facts += gear_catalog_read(energy, list(
			"cell_type",
			"selfcharge",
			"charge_delay",
			"self_charge_amount",
			"can_charge",
			"can_select",
			"use_cyborg_cell",
			"dead_cell",
		))
		if(energy.cell)
			facts["cell_maxcharge"] = energy.cell.maxcharge
		var/list/modes = list()
		for(var/obj/item/ammo_casing/energy/shot as anything in energy.ammo_type)
			var/list/mode = read_casing(shot.type)
			if(energy.cell && shot.e_cost > 0)
				mode = mode.Copy()
				mode["shots_per_cell"] = round(energy.cell.maxcharge / shot.e_cost)
			modes += list(mode)
		facts["modes"] = modes
	else if(istype(gun, /obj/item/gun/magic))
		var/obj/item/gun/magic/magic = gun
		facts["kind"] = "magic"
		facts += gear_catalog_read(magic, list("max_charges", "recharge_rate", "can_charge", "ammo_type"))
		if(magic.chambered)
			facts["chambered"] = read_casing(magic.chambered.type)
	else
		facts["kind"] = "other"
		if(gun.chambered)
			facts["chambered"] = read_casing(gun.chambered.type)
	return facts

/datum/unit_test/gear_catalog_dump/proc/read_ammo_box(obj/item/ammo_box/box)
	var/list/facts = gear_catalog_read(box, list("caliber", "max_ammo", "ammo_type", "multiload", "start_empty"))
	facts["type"] = "[box.type]"
	if(ispath(box.ammo_type, /obj/item/ammo_casing))
		facts["casing"] = read_casing(box.ammo_type)
	return facts

/// What one casing type fires. Cached, so a shared casing is only built once.
/datum/unit_test/gear_catalog_dump/proc/read_casing(casing_type)
	if(casing_cache[casing_type])
		return casing_cache[casing_type]
	var/obj/item/ammo_casing/casing = new casing_type(spawn_at)
	var/list/facts = gear_catalog_read(casing, list(
		"caliber",
		"projectile_type",
		"pellets",
		"variance",
		"randomspread",
		"delay",
		"click_cooldown_override",
		"harmful",
		"can_misfire",
		"misfire_increment",
		"integrity_damage",
		"newtonian_force",
		"e_cost",
		"select_name",
	))
	facts["type"] = "[casing_type]"
	var/obj/projectile/projectile = casing.loaded_projectile
	if(!projectile && casing.projectile_type)
		projectile = new casing.projectile_type(spawn_at)
	if(projectile)
		facts["projectile"] = read_projectile(projectile)
	if(projectile && projectile != casing.loaded_projectile)
		qdel(projectile, force = TRUE)
	qdel(casing, force = TRUE)
	casing_cache[casing_type] = facts
	return facts

/datum/unit_test/gear_catalog_dump/proc/read_projectile(obj/projectile/projectile)
	var/list/facts = gear_catalog_read(projectile, list(
		"damage",
		"damage_type",
		"stamina",
		"pass_flags",
		"armor_flag",
		"armour_penetration",
		"weak_against_armour",
		"wound_bonus",
		"exposed_wound_bonus",
		"sharpness",
		"demolition_mod",
		"range",
		"maximum_range",
		"speed",
		"projectile_piercing",
		"projectile_phasing",
		"max_pierces",
		"ricochets_max",
		"ricochet_chance",
		"stun",
		"knockdown",
		"paralyze",
		"immobilize",
		"unconscious",
		"eyeblur",
		"drowsy",
		"jitter",
		"stutter",
		"slur",
		"dismemberment",
		"embed_type",
		"shrapnel_type",
		"damage_falloff_tile",
		"stamina_falloff_tile",
		"wound_falloff_tile",
		"embed_falloff_tile",
		"accuracy_falloff",
		"accurate_range",
		"hitscan",
		"reflectable",
	))
	facts["type"] = "[projectile.type]"
	facts["vars"] = diff_vars(projectile, projectile_base, null)
	return facts

/// What one projectile type does. Cached, so a shared one is only built once.
/datum/unit_test/gear_catalog_dump/proc/read_projectile_type(projectile_type)
	if(projectile_cache[projectile_type])
		return projectile_cache[projectile_type]
	var/obj/projectile/projectile = new projectile_type(spawn_at)
	var/list/facts = read_projectile(projectile)
	qdel(projectile, force = TRUE)
	projectile_cache[projectile_type] = facts
	return facts

/datum/unit_test/gear_catalog_dump/proc/read_reagents(datum/reagents/holder)
	var/list/held = list()
	for(var/datum/reagent/reagent as anything in holder.reagent_list)
		held["[reagent.type]"] = reagent.volume
	return list("maximum_volume" = holder.maximum_volume, "total_volume" = holder.total_volume, "held" = held)

/// A control unit's theme is a shared datum, not an item, so it gets a section of its own.
/datum/unit_test/gear_catalog_dump/proc/read_mod_theme(obj/item/mod/control/control)
	var/datum/mod_theme/theme = control.theme
	if(!istype(theme))
		return null
	var/list/facts = gear_catalog_read(theme, list(
		"name",
		"slot_flags",
		"armor_type",
		"resistance_flags",
		"atom_flags",
		"max_heat_protection_temperature",
		"min_cold_protection_temperature",
		"siemens_coefficient",
		"complexity_max",
		"charge_drain",
		"slowdown_deployed",
		"activation_step_time",
		"inbuilt_modules",
		"allowed_suit_storage",
	))
	facts["type"] = "[theme.type]"
	var/datum/armor/armor = get_armor_by_type(theme.armor_type)
	if(armor)
		facts["armor"] = armor.get_rating_list()
	return facts

/datum/unit_test/gear_catalog_dump/proc/read_clothing(obj/item/clothing/clothing)
	var/list/facts = gear_catalog_read(clothing, list(
		"flash_protect",
		"tint",
		"clothing_flags",
		"clothing_traits",
		"body_parts_covered",
		"cold_protection",
		"heat_protection",
		"min_cold_protection_temperature",
		"max_heat_protection_temperature",
		"slowdown",
		"limb_integrity",
		"visor_flags",
		"visor_vars_to_toggle",
		"vision_flags",
		"invis_view",
		"invis_override",
		"lighting_cutoff",
		"color_cutoffs",
		"glass_colour_type",
		"forced_glass_color",
	))
	return facts

/// The flag tables the game already keeps for the variable viewer, for the vars the catalog decodes
/proc/gear_catalog_bitfields()
	var/list/found = list()
	for(var/name in list("clothing_flags", "flags_1", "flags_inv", "item_flags", "obj_flags", "organ_flags", "pass_flags", "resistance_flags", "sharpness"))
		found[name] = GLOB.bitfields[name]
	return found

/// The vars named, where the thing has them, whatever their value. Names rather than typed access so
/// shared lists can name vars only some subtypes have.
/proc/gear_catalog_read(datum/thing, list/names)
	var/list/found = list()
	for(var/name in names)
		if(name in thing.vars)
			found[name] = gear_catalog_simple(thing.vars[name])
	return found

/proc/gear_catalog_text(text)
	return istext(text) ? format_text(text) : text

/proc/gear_catalog_type_counts(list/things)
	var/list/counts = list()
	for(var/atom/thing as anything in things)
		counts["[thing.type]"]++
	return counts

/// A value json_encode can write whatever it was: numbers, text, type paths, datums as their type, lists of those.
/proc/gear_catalog_simple(value, depth = 0)
	if(isnull(value))
		return null
	if(isnum(value))
		if(value == INFINITY)
			return "inf"
		if(value == -INFINITY)
			return "-inf"
		if(value != value)
			return "nan"
		return value
	if(istext(value))
		return gear_catalog_text(value)
	if(ispath(value))
		return "[value]"
	if(islist(value))
		return gear_catalog_simple_list(value, depth)
	if(istype(value, /datum))
		var/datum/thing = value
		return "[thing.type]"
	return null

/proc/gear_catalog_simple_list(list/values, depth)
	if(!length(values) || depth >= GEAR_CATALOG_LIST_DEPTH)
		return null
	var/list/plain = list()
	var/list/assoc = list()
	var/is_assoc = FALSE
	var/kept = 0
	for(var/key in values)
		if(++kept > GEAR_CATALOG_LIST_CAP)
			break
		var/entry = isnum(key) ? null : values[key]
		if(!isnull(entry))
			is_assoc = TRUE
		var/simple_key = gear_catalog_simple(key, depth + 1)
		plain += list(simple_key)
		if(!isnull(simple_key))
			assoc["[simple_key]"] = gear_catalog_simple(entry, depth + 1)
	return is_assoc ? assoc : plain

/// Vars that are never item facts: engine state, ownership, and things that move around from run to run.
GLOBAL_LIST_INIT(gear_catalog_skipped_vars, list(
	"vars" = TRUE,
	"verbs" = TRUE,
	"type" = TRUE,
	"parent_type" = TRUE,
	"tag" = TRUE,
	"loc" = TRUE,
	"locs" = TRUE,
	"x" = TRUE,
	"y" = TRUE,
	"z" = TRUE,
	"contents" = TRUE,
	"overlays" = TRUE,
	"underlays" = TRUE,
	"vis_contents" = TRUE,
	"vis_locs" = TRUE,
	"appearance" = TRUE,
	"transform" = TRUE,
	"filters" = TRUE,
	"filter_data" = TRUE,
	"pixel_x" = TRUE,
	"pixel_y" = TRUE,
	"pixel_w" = TRUE,
	"pixel_z" = TRUE,
	"step_x" = TRUE,
	"step_y" = TRUE,
	"dir" = TRUE,
	"icon" = TRUE,
	"name" = TRUE,
	"desc" = TRUE,
	"parent" = TRUE,
	"gc_destroyed" = TRUE,
	"weak_reference" = TRUE,
	"cached_ref" = TRUE,
	"cooldowns" = TRUE,
	"_active_timers" = TRUE,
	"_status_traits" = TRUE,
	"_datum_components" = TRUE,
	"_listen_lookup" = TRUE,
	"_signal_procs" = TRUE,
	"_clear_signal_refs" = TRUE,
	"signal_enabled" = TRUE,
	"managed_overlays" = TRUE,
	"managed_vis_overlays" = TRUE,
	"active_timers" = TRUE,
	"update_on_z" = TRUE,
	"light" = TRUE,
	"hud_list" = TRUE,
	"atom_colours" = TRUE,
	"fingerprints" = TRUE,
	"fingerprintshidden" = TRUE,
	"forensics" = TRUE,
	"blood_DNA" = TRUE,
	"actions" = TRUE,
	"actions_types" = TRUE,
	"atom_storage" = TRUE,
))

#undef GEAR_CATALOG_DIR
#undef GEAR_CATALOG_OUTPUT
#undef GEAR_CATALOG_DONE
#undef GEAR_CATALOG_CURRENT
#undef GEAR_CATALOG_LIST_DEPTH
#undef GEAR_CATALOG_LIST_CAP

#endif
