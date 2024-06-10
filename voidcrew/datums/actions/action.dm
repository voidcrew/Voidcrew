/datum/action
	var/scaling
	var/offset_x
	var/offset_y

/datum/action/proc/ScaleButton(atom/movable/screen/movable/action_button/button, x, y)
	button.scale_to(x,y)

/datum/action/ShowTo(mob/viewer)
	var/datum/hud/our_hud = viewer.hud_used
	if(!our_hud || viewers[our_hud]) // There's no point in this if you have no hud in the first place
		return

	var/atom/movable/screen/movable/action_button/button = create_button()
	SetId(button, viewer)

	button.our_hud = our_hud
	viewers[our_hud] = button
	if(viewer.client)
		viewer.client.screen += button

	button.load_position(viewer)
	if (scaling)
		button.scale_to(scaling, scaling)

	if (offset_x && offset_y)
		button.screen_loc = "[offset_x]:0,[offset_y]:0"

	viewer.update_action_buttons()
