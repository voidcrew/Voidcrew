/**
 * Dock terminal CHARACTER: the ROLES and KIT server side (voidcrew/modules/lobby_terminal/lobby_character.dm).
 * Role berth lists in char_static, the uniform going back to automatic on a role change, the accessory
 * layer and the lipstick (style and colour), and the notice on a refused kit item name.
 * Uses the mock terminal /datum/lobby_terminal/lobby_char_test from lobby_character.dm.
 */
/datum/unit_test/lobby_character_kit_roles

/datum/unit_test/lobby_character_kit_roles/Run()
	var/datum/client_interface/mock = new
	var/datum/preferences/prefs = new(mock)
	mock.prefs = prefs
	var/datum/lobby_terminal/lobby_char_test/term = new(prefs)

	check_static()
	check_roles(term, prefs)
	check_layer(term, prefs)
	check_lipstick(term, prefs)
	check_name_notice(term, prefs)

	qdel(term)

/// char_static.roles: every category sent has 1 to 6 berth titles; none is sent empty.
/datum/unit_test/lobby_character_kit_roles/proc/check_static()
	var/list/static_data = lobby_char_static()
	var/list/roles = static_data["roles"]
	TEST_ASSERT(length(roles), "no roles in char_static")
	for(var/list/entry in roles)
		TEST_ASSERT_EQUAL(length(entry), 2, "a role entry is not \[category, titles\]")
		var/category = entry[1]
		var/list/titles = entry[2]
		TEST_ASSERT(istext(category) && (category in GLOB.job_categories), "unknown role category [category]")
		TEST_ASSERT(islist(titles), "role [category] titles are not a list")
		TEST_ASSERT(length(titles) >= 1, "role [category] sent with no berths")
		TEST_ASSERT(length(titles) <= 6, "role [category] sent [length(titles)] titles")
		for(var/title in titles)
			TEST_ASSERT(istext(title) && length(title), "role [category] has an empty title")

/// A role change puts the preview back on the top role's uniform.
/datum/unit_test/lobby_character_kit_roles/proc/check_roles(datum/lobby_terminal/lobby_char_test/term, datum/preferences/prefs)
	// Category names as text: the unit tests are included before JOB_CAT_* is defined.
	TEST_ASSERT(term.act("char_dress", list("category" = "Medical")), "char_dress refused")
	TEST_ASSERT_EQUAL(term.char_dress, "Medical", "char_dress not kept")
	var/level = prefs.ship_category_preferences["Engineering"] == JP_HIGH ? JP_LOW : JP_HIGH
	TEST_ASSERT(term.act("char_role", list("category" = "Engineering", "level" = level)), "role change refused")
	TEST_ASSERT(isnull(term.char_dress), "a role change kept the chosen uniform")
	TEST_ASSERT(term.act("char_dress", list("category" = "Medical")), "char_dress refused after a role change")
	TEST_ASSERT(!term.act("char_role", list("category" = "Engineering", "level" = level)), "setting the same level accepted")
	TEST_ASSERT_EQUAL(term.char_dress, "Medical", "a refused role change reset the uniform")
	term.act("char_role", list("category" = "Engineering", "level" = 0))

/// char_kit_layer: packed accessories only; it flips INFO_LAYER and the char block sends it.
/datum/unit_test/lobby_character_kit_roles/proc/check_layer(datum/lobby_terminal/lobby_char_test/term, datum/preferences/prefs)
	var/datum/loadout_item/accessory/accessory
	var/datum/loadout_item/other
	for(var/path in GLOB.all_loadout_datums)
		var/datum/loadout_item/item = GLOB.all_loadout_datums[path]
		if(!accessory && istype(item, /datum/loadout_item/accessory))
			var/datum/loadout_item/accessory/candidate = item
			if(candidate.can_be_layer_adjusted)
				accessory = candidate
		if(!other && !istype(item, /datum/loadout_item/accessory))
			other = item
	TEST_ASSERT(accessory, "no layer-adjustable accessory in the loadout")
	TEST_ASSERT(other, "no non-accessory loadout item")

	var/other_path = "[other.item_path]"
	TEST_ASSERT(term.act("char_kit", list("path" = other_path, "on" = 1)), "packing [other_path] refused")
	TEST_ASSERT(!term.act("char_kit_layer", list("path" = other_path)), "char_kit_layer accepted on a non-accessory")
	term.act("char_kit", list("path" = other_path, "on" = 0))

	var/path = "[accessory.item_path]"
	TEST_ASSERT(!term.act("char_kit_layer", list("path" = path)), "char_kit_layer accepted on an unpacked accessory")
	TEST_ASSERT(!term.act("char_kit_layer", list("path" = "nonsense")), "char_kit_layer accepted a nonsense path")
	TEST_ASSERT(term.act("char_kit", list("path" = path, "on" = 1)), "packing [path] refused")
	TEST_ASSERT(term.act("char_kit_layer", list("path" = path)), "char_kit_layer refused on a packed accessory")
	var/list/loadout = prefs.read_preference(/datum/preference/loadout)
	TEST_ASSERT(loadout[accessory.item_path][INFO_LAYER], "char_kit_layer did not put the accessory over the suit")
	var/list/built = term.char_build(prefs, null)
	TEST_ASSERT(built["kit"][path]["layer"], "char block does not send the layer")
	TEST_ASSERT(term.act("char_kit_layer", list("path" = path)), "flipping the layer back refused")
	loadout = prefs.read_preference(/datum/preference/loadout)
	TEST_ASSERT(!loadout[accessory.item_path][INFO_LAYER], "char_kit_layer did not flip back")
	term.act("char_kit", list("path" = path, "on" = 0))

/// The lipstick: style through char_kit_lip, colour through char_kit_color slot 0.
/datum/unit_test/lobby_character_kit_roles/proc/check_lipstick(datum/lobby_terminal/lobby_char_test/term, datum/preferences/prefs)
	var/datum/loadout_item/lipstick = GLOB.all_loadout_datums[/obj/item/lipstick]
	TEST_ASSERT(istype(lipstick, /datum/loadout_item/pocket_items/lipstick), "no lipstick in the loadout")
	TEST_ASSERT_EQUAL(lobby_char_kit_color_count(lipstick), 1, "the lipstick does not count one colour")
	var/path = "[/obj/item/lipstick]"
	TEST_ASSERT(!term.act("char_kit_lip", list("path" = path, "style" = UPPER_LIP)), "char_kit_lip accepted on an unpacked lipstick")
	TEST_ASSERT(term.act("char_kit", list("path" = path, "on" = 1)), "packing the lipstick refused")
	var/list/built = term.char_build(prefs, null)
	TEST_ASSERT_EQUAL(built["kit"][path]["greyscale"], /obj/item/lipstick::lipstick_color, "untouched lipstick does not send its own colour")
	TEST_ASSERT(!term.act("char_kit_lip", list("path" = path, "style" = "Sideways")), "char_kit_lip accepted a bad style")
	TEST_ASSERT(!term.act("char_kit_lip", list("path" = path, "style" = list(UPPER_LIP))), "char_kit_lip accepted a list")
	TEST_ASSERT(!term.act("char_kit_lip", list("path" = "[/obj/item/clothing/accessory/waistcoat]", "style" = UPPER_LIP)), "char_kit_lip accepted another item")
	TEST_ASSERT(term.act("char_kit_lip", list("path" = path, "style" = LOWER_LIP)), "char_kit_lip refused a good style")
	var/list/loadout = prefs.read_preference(/datum/preference/loadout)
	TEST_ASSERT_EQUAL(loadout[/obj/item/lipstick][INFO_LAYER], LOWER_LIP, "lipstick style not written")
	TEST_ASSERT(!term.act("char_kit_lip", list("path" = path, "style" = LOWER_LIP)), "setting the same style accepted")
	TEST_ASSERT(term.act("char_kit_color", list("path" = path, "slot" = 0, "color" = "#a1b2c3")), "lipstick colour refused")
	TEST_ASSERT(!term.act("char_kit_color", list("path" = path, "slot" = 1, "color" = "#a1b2c3")), "a second lipstick colour accepted")
	loadout = prefs.read_preference(/datum/preference/loadout)
	TEST_ASSERT_EQUAL(loadout[/obj/item/lipstick][INFO_GREYSCALE], "#a1b2c3", "lipstick colour not written")
	built = term.char_build(prefs, null)
	TEST_ASSERT_EQUAL(built["kit"][path]["layer"], LOWER_LIP, "char block does not send the lipstick style")
	term.act("char_kit", list("path" = path, "on" = 0))

/// A refused kit item name says so on the notice row.
/datum/unit_test/lobby_character_kit_roles/proc/check_name_notice(datum/lobby_terminal/lobby_char_test/term, datum/preferences/prefs)
	var/datum/loadout_item/named_item
	for(var/path in GLOB.all_loadout_datums)
		var/datum/loadout_item/item = GLOB.all_loadout_datums[path]
		if(item.can_be_named)
			named_item = item
			break
	if(!named_item)
		return
	var/path = "[named_item.item_path]"
	TEST_ASSERT(term.act("char_kit", list("path" = path, "on" = 1)), "nameable item [path] refused")
	term.notice = null
	TEST_ASSERT(!term.act("char_kit_name", list("path" = path, "name" = "<b>x</b>")), "markup kit name accepted")
	TEST_ASSERT(islist(term.notice), "a refused kit name set no notice")
	TEST_ASSERT_EQUAL(term.notice?["kind"], "warn", "a refused kit name notice is not a warning")
	term.notice = null
	TEST_ASSERT(term.act("char_kit_name", list("path" = path, "name" = "Lucky")), "plain kit name refused")
	TEST_ASSERT(isnull(term.notice), "an accepted kit name set a notice")
	term.act("char_kit", list("path" = path, "on" = 0))
