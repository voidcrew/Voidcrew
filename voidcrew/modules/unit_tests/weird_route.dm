/// The Weird Route's pieces are all there: its icons, every sheet the Meat Factory lays out, and all of
/// Moffer's lines for the asking.
/datum/unit_test/weird_route

/datum/unit_test/weird_route/Run()
	var/list/ground = icon_states('voidcrew/modules/weird_route/icons/weird_route.dmi')
	for(var/state in list("path", "grass", "shore", "water", "water_far", "white", "leaves1", "shadow", "solid"))
		TEST_ASSERT(state in ground, "The lake has no \"[state]\" to draw.")
	var/list/box = icon_states('voidcrew/modules/weird_route/icons/weird_route_box.dmi')
	TEST_ASSERT(("fill" in box) && ("border" in box) && ("moffer" in box), "The text box or Moffer's face is missing.")
	TEST_ASSERT_EQUAL(length(icon_states('voidcrew/modules/weird_route/icons/weird_route_pinwheel.dmi')), 4, "The pinwheel's memories or its wedge are missing.")
	TEST_ASSERT("fade" in icon_states('voidcrew/modules/weird_route/icons/weird_route_fade.dmi'), "The ominous fade is missing.")
	var/list/sheet_states = icon_states('voidcrew/modules/weird_route/icons/weird_route_sheets.dmi')
	for(var/list/sheet as anything in GLOB.weird_route_sheets)
		for(var/column in 0 to sheet[2] - 1)
			for(var/row in 0 to sheet[3] - 1)
				TEST_ASSERT("[sheet[1]]_[column]_[row]" in sheet_states, "The Meat Factory's sheet [sheet[1]] has no square [column], [row].")
	// The game asks 36 different ways, the last over and over; and has five answers to "Stop".
	TEST_ASSERT_EQUAL(length(GLOB.weird_route_proceed_lines), 36, "Moffer's lines for the asking are off.")
	TEST_ASSERT_EQUAL(length(GLOB.weird_route_stop_lines), 5, "Moffer's answers to \"Stop\" are off.")
	TEST_ASSERT_EQUAL(weird_route_blend("#ffffff", "#ff0000", 0.4), "#ff9999", "Colours don't blend partway.")
	TEST_ASSERT_EQUAL(weird_route_blend("#000000", "#ffffff", 2), "#ffffff", "Blending goes past the second colour.")
