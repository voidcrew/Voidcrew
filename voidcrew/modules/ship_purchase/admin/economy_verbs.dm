// Ship Economy Admin Verbs
// Requires R_ECONOMY permission flag

/**
 * Grant credits to a player
 */
ADMIN_VERB(grant_ship_credits, R_ECONOMY, "Grant Ship Credits", "Grant credits to a player's account.", ADMIN_CATEGORY_GAME, mob/target in GLOB.player_list)
	if(!target?.client)
		to_chat(user, span_warning("Invalid target - no client."), confidential = TRUE)
		return

	var/amount = input(user, "How many credits to grant?", "Grant Credits", 1000) as num|null
	if(isnull(amount))
		return

	if(amount <= 0)
		to_chat(user, span_warning("Amount must be positive."), confidential = TRUE)
		return

	if(amount > 1000000)
		var/confirm = tgui_alert(user, "You're about to grant [amount] credits. Are you sure?", "Confirm Large Amount", list("Yes", "No"))
		if(confirm != "Yes")
			return

	// TODO: Call ShipEconomyDB.add_credits() when Worker 2 implements it
	// For now this is a stub
	to_chat(user, span_notice("Would grant [amount] credits to [target.ckey] (ShipEconomyDB not yet implemented)"), confidential = TRUE)

	log_admin("[key_name(user)] granted [amount] ship credits to [key_name(target)]")
	message_admins("[key_name_admin(user)] granted [amount] ship credits to [ADMIN_LOOKUPFLW(target)]")
	BLACKBOX_LOG_ADMIN_VERB("Grant Ship Credits")

/**
 * Grant ship parts to a player
 */
ADMIN_VERB(grant_ship_parts, R_ECONOMY, "Grant Ship Parts", "Grant parts to a player's inventory.", ADMIN_CATEGORY_GAME, mob/target in GLOB.player_list)
	if(!target?.client)
		to_chat(user, span_warning("Invalid target - no client."), confidential = TRUE)
		return

	// Rarity selection based on Q2 answer: common, uncommon, rare, epic, legendary
	var/list/rarity_options = list("common", "uncommon", "rare", "epic", "legendary")
	var/rarity = tgui_input_list(user, "Select part rarity:", "Grant Parts", rarity_options)
	if(!rarity)
		return

	var/amount = input(user, "How many [rarity] parts to grant?", "Grant Parts", 1) as num|null
	if(isnull(amount))
		return

	if(amount <= 0)
		to_chat(user, span_warning("Amount must be positive."), confidential = TRUE)
		return

	if(amount > 100)
		var/confirm = tgui_alert(user, "You're about to grant [amount] [rarity] parts. Are you sure?", "Confirm Large Amount", list("Yes", "No"))
		if(confirm != "Yes")
			return

	// TODO: Call ShipEconomyDB.add_parts() when Worker 2 implements it
	to_chat(user, span_notice("Would grant [amount]x [rarity] parts to [target.ckey] (ShipEconomyDB not yet implemented)"), confidential = TRUE)

	log_admin("[key_name(user)] granted [amount]x [rarity] ship parts to [key_name(target)]")
	message_admins("[key_name_admin(user)] granted [amount]x [rarity] ship parts to [ADMIN_LOOKUPFLW(target)]")
	BLACKBOX_LOG_ADMIN_VERB("Grant Ship Parts")

/**
 * Unlock a ship blueprint for a player
 */
ADMIN_VERB(unlock_ship_blueprint, R_ECONOMY, "Unlock Ship Blueprint", "Unlock a ship blueprint for a player.", ADMIN_CATEGORY_GAME, mob/target in GLOB.player_list)
	if(!target?.client)
		to_chat(user, span_warning("Invalid target - no client."), confidential = TRUE)
		return

	var/ship_id = input(user, "Enter ship blueprint ID (e.g. 'starter_shuttle', 'combat_frigate'):", "Unlock Blueprint", "") as text|null
	if(!ship_id || ship_id == "")
		return

	var/confirm = tgui_alert(user, "Unlock '[ship_id]' for [target.ckey]?", "Confirm", list("Yes", "No"))
	if(confirm != "Yes")
		return

	// TODO: Call ShipEconomyDB.unlock_ship() when Worker 2 implements it
	to_chat(user, span_notice("Would unlock '[ship_id]' for [target.ckey] (ShipEconomyDB not yet implemented)"), confidential = TRUE)

	log_admin("[key_name(user)] unlocked ship blueprint '[ship_id]' for [key_name(target)]")
	message_admins("[key_name_admin(user)] unlocked ship blueprint '[ship_id]' for [ADMIN_LOOKUPFLW(target)]")
	BLACKBOX_LOG_ADMIN_VERB("Unlock Ship Blueprint")

/**
 * View a player's economy data
 */
ADMIN_VERB(view_player_economy, R_ECONOMY, "View Player Economy", "View a player's credits, parts, and unlocks.", ADMIN_CATEGORY_GAME, mob/target in GLOB.player_list)
	if(!target?.client)
		to_chat(user, span_warning("Invalid target - no client."), confidential = TRUE)
		return

	// TODO: Call ShipEconomyDB.get_player_data() when Worker 2 implements it
	var/output = "<html><head><title>Economy Data: [target.ckey]</title></head><body>"
	output += "<h2>Ship Economy Data: [target.ckey]</h2>"
	output += "<p><i>ShipEconomyDB not yet implemented - showing stub data</i></p>"
	output += "<hr>"
	output += "<b>Credits:</b> ???<br>"
	output += "<b>Parts Inventory:</b><br>"
	output += "- Common: ???<br>"
	output += "- Uncommon: ???<br>"
	output += "- Rare: ???<br>"
	output += "- Epic: ???<br>"
	output += "- Legendary: ???<br>"
	output += "<br><b>Unlocked Ships:</b> ???<br>"
	output += "</body></html>"

	user << browse(output, "window=economy_[target.ckey];size=500x600")

	log_admin("[key_name(user)] viewed ship economy data for [key_name(target)]")
	BLACKBOX_LOG_ADMIN_VERB("View Player Economy")

/**
 * Reset a player's ship progress
 */
ADMIN_VERB(reset_ship_progress, R_ECONOMY, "Reset Ship Progress", "Reset a player's credits, parts, and unlocks (DANGEROUS).", ADMIN_CATEGORY_GAME, mob/target in GLOB.player_list)
	if(!target?.client)
		to_chat(user, span_warning("Invalid target - no client."), confidential = TRUE)
		return

	var/confirm = tgui_alert(user, "This will DELETE ALL ship economy data for [target.ckey]. Are you ABSOLUTELY sure?", "CONFIRM RESET", list("Yes, Reset Everything", "No, Cancel"))
	if(confirm != "Yes, Reset Everything")
		return

	// Double confirmation
	var/confirm2 = tgui_alert(user, "Last chance: Delete [target.ckey]'s credits, parts, and unlocks?", "FINAL CONFIRMATION", list("Yes", "No"))
	if(confirm2 != "Yes")
		return

	// TODO: Call ShipEconomyDB.reset_player() when Worker 2 implements it
	to_chat(user, span_warning("Would reset ALL ship economy data for [target.ckey] (ShipEconomyDB not yet implemented)"), confidential = TRUE)

	log_admin("[key_name(user)] RESET ALL ship economy data for [key_name(target)]")
	message_admins(span_danger("[key_name_admin(user)] RESET ALL ship economy data for [ADMIN_LOOKUPFLW(target)]"))
	BLACKBOX_LOG_ADMIN_VERB("Reset Ship Progress")
