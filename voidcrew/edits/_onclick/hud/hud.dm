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
		coord_col = "+[visual_column * scale_x]"
		coord_col_offset = coord_col_offset * scale_x
	if(!isnull(scale_y) && scale_y != 1)
		coord_row = visual_row ? "-[visual_row * scale_y]" : "-[scale_y]"
		pixel_north_offset = 6 * scale_y
	else
		pixel_north_offset = 6

	return "WEST[coord_col]:[coord_col_offset],NORTH[coord_row]:-[pixel_north_offset]"
