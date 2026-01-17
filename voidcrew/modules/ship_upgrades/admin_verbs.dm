/**
 * Admin verbs for ship economy management
 */

ADMIN_VERB(give_ship_parts, R_ADMIN, "Give Ship Parts", "Give ship parts to a player.", ADMIN_CATEGORY_GAME)
	// Get list of connected player ckeys for easy selection
	var/list/connected_ckeys = list()
	for(var/client/C in GLOB.clients)
		connected_ckeys += C.ckey

	var/target_ckey = tgui_input_list(user, "Select a player or enter a ckey:", "Give Ship Parts", connected_ckeys)
	if(!target_ckey)
		target_ckey = tgui_input_text(user, "Enter the player's ckey:", "Give Ship Parts")
	if(!target_ckey)
		return

	target_ckey = ckey(target_ckey) // Normalize

	var/part_class = tgui_input_list(user, "Select part class:", "Give Ship Parts", GLOB.ship_part_classes)
	if(!part_class)
		return

	var/quantity = tgui_input_number(user, "Enter quantity to give:", "Give Ship Parts", 1, 100, 1)
	if(!quantity || quantity < 1)
		return

	if(!GLOB.ship_economy_db)
		to_chat(user, span_warning("Ship economy database is not available."))
		return

	if(GLOB.ship_economy_db.add_part(target_ckey, part_class, quantity, "admin_grant"))
		to_chat(user, span_notice("Successfully gave [quantity] [part_class] part(s) to [target_ckey]."))
		message_admins("[key_name_admin(user)] gave [quantity] [part_class] ship part(s) to [target_ckey].")
		log_admin("[key_name(user)] gave [quantity] [part_class] ship part(s) to [target_ckey].")
	else
		to_chat(user, span_warning("Failed to give parts. Check that the database is connected."))

	BLACKBOX_LOG_ADMIN_VERB("Give Ship Parts")

ADMIN_VERB(give_ship_credits, R_ADMIN, "Give Ship Credits", "Give ship credits to a player.", ADMIN_CATEGORY_GAME)
	// Get list of connected player ckeys for easy selection
	var/list/connected_ckeys = list()
	for(var/client/C in GLOB.clients)
		connected_ckeys += C.ckey

	var/target_ckey = tgui_input_list(user, "Select a player or enter a ckey:", "Give Ship Credits", connected_ckeys)
	if(!target_ckey)
		target_ckey = tgui_input_text(user, "Enter the player's ckey:", "Give Ship Credits")
	if(!target_ckey)
		return

	target_ckey = ckey(target_ckey) // Normalize

	var/amount = tgui_input_number(user, "Enter amount of credits to give:", "Give Ship Credits", 100, 10000, 1)
	if(!amount)
		return

	if(!GLOB.ship_economy_db)
		to_chat(user, span_warning("Ship economy database is not available."))
		return

	if(GLOB.ship_economy_db.add_credits(target_ckey, amount, "admin_grant"))
		to_chat(user, span_notice("Successfully gave [amount] credits to [target_ckey]."))
		message_admins("[key_name_admin(user)] gave [amount] ship credits to [target_ckey].")
		log_admin("[key_name(user)] gave [amount] ship credits to [target_ckey].")
	else
		to_chat(user, span_warning("Failed to give credits. Check that the database is connected."))

	BLACKBOX_LOG_ADMIN_VERB("Give Ship Credits")

ADMIN_VERB(check_ship_economy, R_ADMIN, "Check Ship Economy", "View a player's ship parts and credits.", ADMIN_CATEGORY_GAME)
	// Get list of connected player ckeys for easy selection
	var/list/connected_ckeys = list()
	for(var/client/C in GLOB.clients)
		connected_ckeys += C.ckey

	var/target_ckey = tgui_input_list(user, "Select a player or enter a ckey:", "Check Ship Economy", connected_ckeys)
	if(!target_ckey)
		target_ckey = tgui_input_text(user, "Enter the player's ckey:", "Check Ship Economy")
	if(!target_ckey)
		return

	target_ckey = ckey(target_ckey) // Normalize

	if(!GLOB.ship_economy_db)
		to_chat(user, span_warning("Ship economy database is not available."))
		return

	var/credits = GLOB.ship_economy_db.get_credits(target_ckey)
	var/list/parts = GLOB.ship_economy_db.get_parts(target_ckey)

	var/list/msg = list()
	msg += span_notice("<b>Ship Economy for [target_ckey]:</b>")
	msg += span_notice("Credits: [credits]")
	msg += span_notice("<b>Parts:</b>")
	if(parts)
		for(var/part_class in parts)
			msg += span_notice("[capitalize(part_class)]: [parts[part_class]]")
	else
		msg += span_warning("Unable to retrieve parts data.")

	to_chat(user, msg.Join("\n"))
	BLACKBOX_LOG_ADMIN_VERB("Check Ship Economy")
