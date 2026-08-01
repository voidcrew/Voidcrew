/datum/action_group
	var/scale_x = null
	var/scale_y = null

/// Accepts a number represeting our position in the group, indexes at 0 to make the math nicer
/datum/action_group/ButtonNumberToScreenCoords(number, landing = FALSE)
	var/row = round(number / column_max)
	row -= row_offset // If you're less then 0, you don't get to render, this lets us "scroll" rows ya feel?
	if(row < 0)
		return null

	// Could use >= here, but I think it's worth noting that the two start at different places, since row is based on number here
	if(row > max_rows - 1)
		if(!landing) // If you're not a landing, go away please. thx
			return null
		// We always want to render landings, even if their action button can't be displayed.
		// So we set a row equal to the max amount of rows + 1. Willing to overrun that max slightly to properly display the landing spot
		row = max_rows // Remembering that max_rows indexes at 1, and row indexes at 0

		// We're going to need to set our column to match the first item in the last row, so let's set number properly now
		number = row * column_max

	var/visual_row = row + north_offset
	var/coord_row = visual_row ? "-[visual_row]" : "+0"

	var/visual_column = number % column_max
	var/coord_col = "+[visual_column]"
	var/coord_col_offset = 4 + 2 * (visual_column + 1)

	if(!isnull(scale_x) && scale_x != 1)
		coord_col = "+[(visual_column * scale_x) + 1]"
		coord_col_offset = coord_col_offset * scale_x
	if(!isnull(scale_y) && scale_y != 1)
		coord_row = visual_row ? "-[visual_row * scale_y]" : "-[scale_y]"
		pixel_north_offset = 6 * scale_y
	else
		pixel_north_offset = 6

	return "WEST[coord_col]:[coord_col_offset],NORTH[coord_row]:-[pixel_north_offset]"

/**
 * Re-places the palette and its scroll arrows at scaled offsets.
 *
 * VOIDCREW EDIT: upstream's own /datum/action_group/palette/refresh_actions() moved out of
 * code/_onclick/hud/hud.dm into code/_onclick/hud/action_group.dm, which is included long before
 * this file (tgstation.dme 631 vs 7251). The pre-merge fork commented upstream's copy out and
 * replaced it wholesale; this version instead lets ..() run upstream's body first - laying
 * everything out at the unscaled offsets - and then moves the three screen objects that the
 * scale affects. Nothing upstream has to be edited, and future upstream changes to the unscaled
 * layout are inherited instead of silently dropped.
 *
 * The direct owner.toggle_palette / palette_down / palette_up vars are gone; every HUD screen
 * object now lives in owner.screen_objects, keyed by the HUD_MOB_* defines.
 *
 * Both scroll arrows are placed here. Upstream sets both, and the pre-merge fork version set only
 * one per branch (scroll_down when scaled, scroll_up when not) - a copy-paste slip that left the
 * other arrow with a null screen_loc, i.e. invisible.
 */
/datum/action_group/palette/refresh_actions()
	. = ..()
	if(isnull(scale_x) || scale_x == 1)
		return

	var/atom/movable/screen/button_palette/palette = owner.screen_objects[HUD_MOB_TOGGLE_PALETTE]
	var/atom/movable/screen/palette_scroll/scroll_down = owner.screen_objects[HUD_MOB_PALETTE_DOWN]
	var/atom/movable/screen/palette_scroll/scroll_up = owner.screen_objects[HUD_MOB_PALETTE_UP]

	var/actions_above = round((owner.listed_actions.size() - 1) / owner.listed_actions.column_max)
	var/action_count = length(owner?.mymob?.actions)
	// No actions at all means upstream just hid the palette; leave it hidden.
	if(action_count)
		palette.screen_loc = ui_action_palette_offset_with_scale(scale_x, actions_above)

	var/our_row_count = round((length(actions) - 1) / column_max)
	if(!palette.expanded || !action_count || our_row_count < max_rows)
		return // upstream already nulled both arrows out

	scroll_down.screen_loc = ui_palette_scroll_offset_with_scale(scale_x, actions_above)
	scroll_up.screen_loc = ui_palette_scroll_offset_with_scale(scale_x, actions_above)
