/**
 * Ship Catalog UI Backend
 *
 * TGUI interface for browsing and purchasing ship blueprints.
 * Displays all available ships with preview images, crew capacity,
 * unlock costs, and purchase functionality.
 *
 * Usage:
 *   var/datum/ship_catalog_ui/catalog = new(usr)
 *   catalog.ui_interact(usr)
 */

/// Global list of all ship templates for the catalog
GLOBAL_LIST_EMPTY(ship_catalog_templates)

/// Flag to track if catalog has been initialized
GLOBAL_VAR_INIT(ship_catalog_initialized, FALSE)

/// Proc to initialize ship catalog (called lazily on first access)
/proc/ensure_ship_catalog_initialized()
	if(GLOB.ship_catalog_initialized)
		return
	GLOB.ship_catalog_initialized = TRUE

	// Build ship catalog from all voidcrew shuttle templates
	for(var/shuttle_id in SSmapping.shuttle_templates)
		var/datum/map_template/shuttle/voidcrew/template = SSmapping.shuttle_templates[shuttle_id]

		// Only include voidcrew ships (player-selectable ships)
		if(!istype(template))
			continue

		// Skip abstract types
		if(template.abstract && template.type == template.abstract)
			continue

		GLOB.ship_catalog_templates += template

	log_game("SHIP_CATALOG: Initialized with [length(GLOB.ship_catalog_templates)] ships")

/// Find a ship template by its type path string
/proc/find_ship_template_by_type(type_path)
	ensure_ship_catalog_initialized()
	for(var/datum/map_template/shuttle/voidcrew/template as anything in GLOB.ship_catalog_templates)
		if("[template.type]" == type_path)
			return template
	return null

/**
 * Whether players are allowed to buy this hull.
 *
 * Only modular hulls are for sale: a hull the player can actually preview and
 * configure in the upgrade selector. Legacy fixed hulls stay registered for
 * roundstart/NPC/admin spawning, they're just not on the shelf, unless they're
 * explicitly curated back in with force_purchasable.
 */
/proc/is_player_purchasable_ship(datum/map_template/shuttle/voidcrew/template)
	if(!istype(template))
		return FALSE
	if(template.player_hidden)
		return FALSE
	if(template.force_purchasable)
		return TRUE
	if(!template.has_upgrade_slots)
		return FALSE
	// A hull with slots but nothing to put in them and no themes has nothing to configure
	return length(template.upgrade_slot_ids) || length(template.available_themes)

/**
 * Whether a hull is allowed to be one of the ships the round starts on.
 *
 * Stricter than is_player_purchasable_ship(): the roundstart fleet is rolled at
 * random, hull, theme and modules alike, so it only uses hulls that actually have
 * slots to roll modules into. The curated force_purchasable oddities (the pills)
 * stay on the shelf but off the starting line, and fixed legacy hulls are out
 * entirely.
 */
/proc/is_roundstart_eligible_hull(datum/map_template/shuttle/voidcrew/template)
	if(!istype(template))
		return FALSE
	if(!is_roundstart_eligible_hull_type(template.type))
		return FALSE
	// A hull with no slots has nothing to roll modules into
	return length(template.upgrade_slot_ids)

/**
 * is_roundstart_eligible_hull() for callers that only have a type path.
 *
 * Skips the upgrade_slot_ids check, which needs an instance to read - and instancing a
 * map template parses its whole .dmm, which is far too expensive for the early-init
 * callers this exists for (see /datum/job/map_check).
 */
/proc/is_roundstart_eligible_hull_type(datum/map_template/shuttle/voidcrew/hull_type)
	if(!ispath(hull_type, /datum/map_template/shuttle/voidcrew))
		return FALSE
	if(initial(hull_type.player_hidden))
		return FALSE
	// Curated back onto the shelf by hand, so it never earned a place on the starting line
	if(initial(hull_type.force_purchasable))
		return FALSE
	return initial(hull_type.has_upgrade_slots)

/// Every hull the roundstart fleet is allowed to roll
/proc/get_roundstart_hull_templates()
	ensure_ship_catalog_initialized()
	var/list/eligible = list()
	for(var/datum/map_template/shuttle/voidcrew/template as anything in GLOB.ship_catalog_templates)
		if(is_roundstart_eligible_hull(template))
			eligible += template
	return eligible

/// Total parts a hull costs to unlock, across every part class
/proc/ship_template_total_part_cost(datum/map_template/shuttle/voidcrew/template)
	var/total = 0
	for(var/part_class in template.part_requirements)
		total += template.part_requirements[part_class] || 0
	return total

/**
 * Whether a hull costs nothing to unlock.
 *
 * Free hulls are owned by everyone from the start - there's no purchase step and
 * nothing is written to the database for them.
 *
 * The FREE_SHIPS config flag makes every hull free.
 */
/proc/is_ship_free(datum/map_template/shuttle/voidcrew/template)
	if(!istype(template))
		return FALSE
	if(CONFIG_GET(flag/free_ships))
		return TRUE
	return !ship_template_total_part_cost(template)

/**
 * Every hull a player can fly right now: the ones they've bought, plus every free
 * hull on the shelf. Use this instead of the raw database list anywhere ownership
 * is displayed or enforced.
 */
/proc/get_effective_unlocked_ships(ckey)
	var/list/unlocked = GLOB.ship_economy_db?.get_unlocked_ships(ckey) || list()
	for(var/datum/map_template/shuttle/voidcrew/template as anything in get_purchasable_ship_templates())
		if(is_ship_free(template))
			unlocked |= "[template.type]"
	return unlocked

/// Cheapest hulls first, then alphabetical, so the free starter is always on top
/proc/cmp_ship_template_cost_asc(datum/map_template/shuttle/voidcrew/a, datum/map_template/shuttle/voidcrew/b)
	var/difference = ship_template_total_part_cost(a) - ship_template_total_part_cost(b)
	if(difference)
		return difference
	return sorttext(b.name, a.name)

/// Every hull players can buy, cheapest first
/proc/get_purchasable_ship_templates()
	ensure_ship_catalog_initialized()
	var/list/purchasable = list()
	for(var/datum/map_template/shuttle/voidcrew/template as anything in GLOB.ship_catalog_templates)
		if(is_player_purchasable_ship(template))
			purchasable += template
	return sortTim(purchasable, GLOBAL_PROC_REF(cmp_ship_template_cost_asc))

/**
 * Spend a player's parts to unlock a hull permanently.
 *
 * Used by the ship upgrade selector, which is where hulls are bought.
 * Chats the reason to the user on every failure path.
 *
 * @param user The user attempting the unlock
 * @param template The ship template to unlock
 * @return TRUE if successful, FALSE otherwise
 */
/proc/attempt_ship_unlock(mob/user, datum/map_template/shuttle/voidcrew/template)
	if(!user?.client || !template)
		return FALSE

	var/ckey = user.client.ckey

	// Free hulls come unlocked - nothing to spend, nothing to record
	if(is_ship_free(template))
		return TRUE

	// Check if ship is already unlocked
	if(GLOB.ship_economy_db.is_ship_unlocked(ckey, "[template.type]"))
		to_chat(user, span_warning("You have already unlocked this ship!"))
		return FALSE

	// Build requirements from template's class-based part_requirements
	var/list/requirements = list()
	for(var/part_class in template.part_requirements)
		var/count = template.part_requirements[part_class] || 0
		if(count > 0)
			requirements[part_class] = count

	// Check if player has sufficient parts
	var/list/current_parts = GLOB.ship_economy_db.get_parts(ckey)
	if(!current_parts)
		to_chat(user, span_warning("Unable to retrieve your parts inventory."))
		return FALSE

	for(var/part_class in requirements)
		var/needed = requirements[part_class]
		var/have = current_parts[part_class] || 0

		if(have < needed)
			to_chat(user, span_warning("Insufficient [part_class] parts! You need [needed] but only have [have]."))
			return FALSE

	// Attempt to spend parts
	if(!GLOB.ship_economy_db.spend_parts(ckey, requirements))
		to_chat(user, span_warning("Failed to deduct parts. Transaction failed."))
		return FALSE

	// Unlock the ship
	if(!GLOB.ship_economy_db.unlock_ship(ckey, "[template.type]"))
		// Parts were deducted but unlock failed - this is bad!
		// In production, this should trigger a compensating transaction or alert
		log_game("SHIP_CATALOG ERROR: Parts deducted but unlock failed for [ckey] - ship [template.type]")
		to_chat(user, span_userdanger("Unlock failed! Please contact an administrator - parts were deducted but unlock did not complete."))
		return FALSE

	// Success!
	log_game("SHIP_CATALOG: [ckey] unlocked ship [template.type] ([template.name])")
	return TRUE

/**
 * Ship Catalog UI Datum
 *
 * Read-only browser for the hulls on offer: what they cost, what crew they
 * carry, and which ones you already own. Buying a hull happens in the ship
 * upgrade selector, which is the only place that shows you what you're buying.
 */
/datum/ship_catalog_ui
	/// Reference to the user viewing the catalog
	var/mob/user

	/// Selected ship filter (by faction)
	var/selected_faction = null

	/// Search query for filtering ships
	var/search_query = ""

/datum/ship_catalog_ui/New(mob/viewing_user)
	. = ..()
	user = viewing_user

/datum/ship_catalog_ui/Destroy()
	user = null
	return ..()

/**
 * Open the ship catalog UI for a user
 */
/datum/ship_catalog_ui/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ShipCatalog", "Ship Catalog")
		ui.open()

/**
 * UI state - accessible anytime (character creation, lobby, in-game)
 */
/datum/ship_catalog_ui/ui_state(mob/user)
	return GLOB.always_state

/**
 * Static data - ship catalog that doesn't change
 * Sent once when UI opens
 */
/datum/ship_catalog_ui/ui_static_data(mob/user)
	var/list/data = list()

	// Ensure catalog is initialized
	ensure_ship_catalog_initialized()
	// Also ensure ship upgrades/themes are initialized for themed ships
	ensure_ship_upgrades_initialized()

	// Build ship catalog - only the modular hulls players can actually buy
	var/list/ships = list()

	for(var/datum/map_template/shuttle/voidcrew/template as anything in get_purchasable_ship_templates())
		// Get job slots - either from template directly or from default theme
		var/list/job_slots_to_use = template.job_slots
		var/theme_count = 0

		// If ship has available_themes, get job slots from the default theme
		if(length(template.available_themes))
			theme_count = length(template.available_themes)
			var/datum/ship_theme/default_theme = get_default_theme_for_ship(template.type)
			if(default_theme?.job_slots)
				job_slots_to_use = default_theme.job_slots

		// Calculate crew capacity from job slots
		var/crew_capacity = 0
		for(var/list/job_definition in job_slots_to_use)
			crew_capacity += job_definition["slots"]

		// Build parts requirement list from template's class-based requirements
		var/list/parts_required = list()
		var/total_parts = 0
		for(var/part_class in GLOB.ship_part_classes)
			var/count = template.part_requirements[part_class] || 0
			if(count > 0)
				parts_required[part_class] = count
				total_parts += count

		// Determine primary class (the one with most requirements, for display/filtering)
		var/primary_class = "misc"
		var/max_count = 0
		for(var/part_class in template.part_requirements)
			var/count = template.part_requirements[part_class] || 0
			if(count > max_count)
				max_count = count
				primary_class = part_class

		// If no parts required, it's free
		if(total_parts == 0)
			primary_class = "free"

		// Display string only: a ship faction system doesn't exist, so every card reads
		// Neutral. (The mob-faction FACTION_NEUTRAL define is lowercase "neutral" and
		// would mismatch the capitalized entries in data["factions"].)
		var/faction = "Neutral"

		// Build job list for display
		var/list/jobs = list()
		for(var/list/job_definition in job_slots_to_use)
			jobs += list(list(
				"name" = job_definition["name"],
				"slots" = job_definition["slots"],
				"officer" = job_definition["officer"] ? TRUE : FALSE
			))

		ships += list(list(
			"id" = template.type,
			"name" = template.name,
			"short_name" = template.short_name || template.name,
			"suffix" = template.suffix,
			"description" = template.catalog_desc || generate_ship_description(template),
			"crew_capacity" = crew_capacity,
			"total_parts" = total_parts,
			"primary_class" = primary_class,
			"parts_required" = parts_required,
			"faction" = faction,
			"preview_image" = get_ship_preview_path(template),
			"jobs" = jobs,
			"theme_count" = theme_count,
			"has_upgrades" = template.has_upgrade_slots
		))

	data["ships"] = ships

	// Available factions for filtering (these are defined in voidcrew but need fallbacks here)
	var/list/factions = list(
		"Neutral",
		"Syndicate",
		"Nanotrasen"
	)
	data["factions"] = factions

	return data

/**
 * Dynamic data - player's credits, parts, and unlocked ships
 * Updates on every UI refresh
 */
/datum/ship_catalog_ui/ui_data(mob/user)
	var/list/data = list()

	if(!user || !user.client)
		return data

	var/ckey = user.client.ckey

	// Get player's current credits (account-wide)
	data["credits"] = GLOB.ship_economy_db?.get_credits(ckey) || 0

	// Get player's parts inventory (account-wide) - now class-based
	var/list/parts = GLOB.ship_economy_db?.get_parts(ckey)
	if(!parts)
		parts = list()
		for(var/part_class in GLOB.ship_part_classes)
			parts[part_class] = 0
	data["parts"] = parts

	// Get list of unlocked ships (bought hulls plus the free ones everyone owns)
	data["unlocked_ships"] = get_effective_unlocked_ships(ckey)

	// Current filters
	data["selected_faction"] = selected_faction
	data["search_query"] = search_query

	return data

// The catalog is a read-only browser: purchasing and previews live in the shipyard
// (ShipUpgradeSelector), and ShipCatalog.tsx sends no act() calls, so there is no
// ui_act override, filtering and search happen client-side if they happen at all.

/**
 * Generate a description for a ship based on its properties.
 * Only a fallback for hulls with no hand-written catalog_desc - prefer that.
 */
/proc/generate_ship_description(datum/map_template/shuttle/voidcrew/template)
	// Get job slots - either from template directly or from default theme
	var/list/job_slots_to_use = template.job_slots

	// If ship has available_themes, get job slots from the default theme
	if(length(template.available_themes))
		var/datum/ship_theme/default_theme = get_default_theme_for_ship(template.type)
		if(default_theme?.job_slots)
			job_slots_to_use = default_theme.job_slots

	var/crew_count = 0
	for(var/list/job_definition in job_slots_to_use)
		crew_count += job_definition["slots"]

	var/ship_class = template.short_name || template.name

	// Build role summary
	var/list/roles = list()
	for(var/list/job_definition in job_slots_to_use)
		if(job_definition["slots"] > 0)
			roles += "[job_definition["slots"]]x [job_definition["name"]]"

	var/role_summary = length(roles) ? roles.Join(", ") : "varies by theme"

	// Add theme info if applicable
	var/theme_info = ""
	if(length(template.available_themes))
		theme_info = " [length(template.available_themes)] theme variants available."

	return "[ship_class] with capacity for [crew_count] crew members. Crew roles: [role_summary].[theme_info]"

/**
 * Ship preview identifier sent to the read-only catalog card. Real, per-configuration
 * previews live in the shipyard (ShipUpgradeSelector + the baked previews manifest);
 * the catalog keeps a stable placeholder so its card layout doesn't shift.
 */
/datum/ship_catalog_ui/proc/get_ship_preview_path(datum/map_template/shuttle/voidcrew/template)
	return "ship_preview_neutral.png"

/**
 * Admin verb to open ship catalog
 */
/datum/admins/proc/open_ship_catalog()
	if(!check_rights(R_ADMIN))
		return

	var/datum/ship_catalog_ui/catalog = new(usr)
	catalog.ui_interact(usr)

/**
 * Client proc to open ship catalog (for character creation)
 */
/client/proc/open_ship_catalog()
	var/datum/ship_catalog_ui/catalog = new(mob)
	catalog.ui_interact(mob)

/**
 * Player verb to browse the ship catalog
 */
/client/verb/view_ship_catalog()
	set name = "View Ship Catalog"
	set category = "OOC"
	set desc = "Browse available ships and see what you've unlocked."

	open_ship_catalog()

