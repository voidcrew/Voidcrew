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

/datum/action_group/palette/refresh_actions()
	var/atom/movable/screen/button_palette/palette = owner.toggle_palette
	var/atom/movable/screen/palette_scroll/scroll_down = owner.palette_down
	var/atom/movable/screen/palette_scroll/scroll_up = owner.palette_up

	var/actions_above = round((owner.listed_actions.size() - 1) / owner.listed_actions.column_max)
	north_offset = initial(north_offset) + actions_above

	if (!isnull(scale_x) && scale_x != 1)
		palette.screen_loc = ui_action_palette_offset_with_scale(scale_x, actions_above)
	else
		palette.screen_loc = ui_action_palette_offset(actions_above)

	var/action_count = length(owner?.mymob?.actions)
	var/our_row_count = round((length(actions) - 1) / column_max)
	if(!action_count)
		palette.screen_loc = null

	if(palette.expanded && action_count && our_row_count >= max_rows)
		if (!isnull(scale_x) && scale_x != 1)
			scroll_down.screen_loc = ui_palette_scroll_offset_with_scale(scale_x, actions_above)
		else
			scroll_up.screen_loc = ui_palette_scroll_offset(actions_above)
	else
		scroll_down.screen_loc = null
		scroll_up.screen_loc = null

	return ..()

/**
 * Takes the health doll off the client's screen and puts it straight back, so the client
 * re-establishes the doll's visual contents.
 *
 * The doll draws each limb as a separate screen object in its own vis_contents
 * (/atom/movable/screen/healthdoll/human/update_body_zones in screen_objects.dm), because
 * upstream wants per-limb outline filters it can animate. On a z change - which here is
 * every single dock and undock - the BYOND client drops those children and never gets
 * them back. This is a known client-side bug class, not a DM one: BYOND id:2303806
 * ("Visual contents were not taken into account by the client-side garbage collector...
 * The objects still exist, just aren't visible unless you change an appearance var to
 * bring them back into the view") and id:2359025 ("visual contents no longer showed up
 * after changing Z levels"). Server side the limbs stay alive with correct icon_states
 * throughout - there are no runtimes for them in any round log, and nothing in DM touches
 * the doll on a z change.
 *
 * vis_contents is not part of an atom's appearance, and the doll has no icon_state and no
 * overlays of its own, so its appearance never changes for its entire life and the client
 * is never told about it a second time. That leaves a limb's own icon_state as the only
 * thing that can bring it back, which is exactly what players reported ("get damage on
 * that limb and heal it to fix it") and why the limbs surviving a dock were always the
 * ones that had taken or healed damage since.
 *
 * Re-adding the doll to client.screen re-sends it and its children. This is the same
 * treatment the parallax backdrop already gets by accident: it is the only other screen
 * object built on vis_contents, and update_parallax_pref() above tears its holder off the
 * screen and adds it back (remove_parallax/create_parallax in parallax.dm) on every z
 * change, which is why parallax does not rot the way the doll did.
 *
 * Do not "simplify" this into update_appearance() or update_body_zones(). The first
 * changes nothing about the doll's appearance so nothing is sent; the second rebuilds six
 * screen objects to repair a link that was never broken server side.
 */
/datum/hud/proc/resend_healthdoll()
	var/client/our_client = mymob?.client
	if(isnull(our_client) || isnull(healthdoll))
		return
	// Hud hidden with F12? The doll is deliberately off the screen, leave it off.
	if(!(healthdoll in our_client.screen))
		return
	our_client.screen -= healthdoll
	our_client.screen += healthdoll
// VOIDCREW EDIT ADDITION END
