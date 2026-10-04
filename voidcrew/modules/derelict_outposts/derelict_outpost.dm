/**
 * # Derelict outpost
 *
 * Owner: P1 (after the seams commit). One per round: an unclaimed player outpost that sits on the chart as an
 * unknown signal and builds the first time a ship docks (dark, dressed, with a prison wing and hostiles).
 * Claimed at its console like any unowned outpost; after that an ordinary player outpost.
 */
/obj/structure/overmap/dynamic/player_outpost/derelict
	name = "unknown signal"
	desc = "A faint signal of unknown origin. Survey to learn more."
	icon_state = "strange_event"
	sensor_category = "Ruins"
	/// DERELICT_STATE_*; only this file writes it
	var/derelict_state = DERELICT_STATE_DORMANT
	/// The name it answers to once found, from GLOB.derelict_outpost_names
	var/true_name
	/// DERELICT_THEME_*
	var/theme_id
	/// ZONE_YELLOW or ZONE_RED: the band it spawned in
	var/derelict_band = ZONE_YELLOW
	/// The shell it is built from
	var/datum/map_template/player_outpost/derelict_shell_type
	/// Weakrefs to every hostile the theme spawned (derelict_themes.dm writes; everyone else reads)
	var/list/datum/weakref/derelict_hostiles = list()
	/// Where the fuel was left (derelict_layout.dm writes)
	var/list/turf/derelict_fuel_spots = list()
	/// Weakref to the shell airlock the prison wing's door was joined to; null when it was not joined (derelict_layout.dm writes)
	var/datum/weakref/derelict_prison_airlock
	/// Tests set this to build without a theme
	var/derelict_skip_theme = FALSE
	/// Counts builds, so a stalled watchdog or a superseded build can tell whether it is still its own
	var/derelict_build_serial = 0
	/// The build watchdog timer (DERELICT_BUILD_WATCHDOG); stopped and nulled on every exit
	var/derelict_watchdog_timer

/obj/structure/overmap/dynamic/player_outpost/derelict/Initialize(mapload)
	. = ..()
	if(!GLOB.derelict_outpost)
		GLOB.derelict_outpost = src

/obj/structure/overmap/dynamic/player_outpost/derelict/Destroy()
	if(GLOB.derelict_outpost == src)
		GLOB.derelict_outpost = null
	derelict_hostiles.Cut()
	derelict_fuel_spots.Cut()
	derelict_prison_airlock = null
	deltimer(derelict_watchdog_timer)
	derelict_watchdog_timer = null
	derelict_build_serial++
	return ..()

/// Picks what this derelict is: its shell, theme, band and the name it answers to once found
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/setup_derelict(shell_type, theme, band)
	derelict_shell_type = shell_type
	theme_id = theme
	derelict_band = band
	true_name = pick(GLOB.derelict_outpost_names)

/**
 * Builds the derelict now: the level and shell, the prison wing, dead power, the theme.
 * Returns TRUE when it stands built.
 */
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/build_derelict(obj/structure/overmap/ship/waiting_ship)
	if(derelict_state != DERELICT_STATE_DORMANT)
		if(is_loaded())
			SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, TRUE)
		return is_loaded()
	derelict_state = DERELICT_STATE_BUILDING
	var/serial = ++derelict_build_serial
	derelict_watchdog_timer = addtimer(CALLBACK(src, PROC_REF(derelict_build_watchdog), serial), DERELICT_BUILD_WATCHDOG, TIMER_STOPPABLE)
	name = true_name
	display_name = true_name
	desc = "An outpost gone dark. Nobody answers."
	shell_template = new derelict_shell_type
	founded_zone = derelict_band
	resident_mode = "closed"
	if(!load_level())
		abort_derelict_build(waiting_ship)
		return FALSE
	if(QDELETED(src) || serial != derelict_build_serial)
		return FALSE
	sync_close_overmap_objects()
	place_derelict_prison()
	drain_derelict_power()
	if(!derelict_skip_theme)
		apply_derelict_theme()
	set_derelict_ambience(TRUE)
	if(QDELETED(src) || serial != derelict_build_serial)
		return FALSE
	finish_derelict_build()
	return TRUE

/// Cleans up after a build that could not load its level, and reverts to an unfound signal
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/abort_derelict_build(obj/structure/overmap/ship/waiting_ship)
	deltimer(derelict_watchdog_timer)
	derelict_watchdog_timer = null
	derelict_build_serial++
	shell_template = null
	name = initial(name)
	display_name = name
	desc = initial(desc)
	derelict_state = DERELICT_STATE_DORMANT
	if(SSmapping.at_z_level_ceiling())
		site_load_refused_for_capacity(waiting_ship)
	else
		log_mapping("DERELICT OUTPOST: '[true_name]' could not load its level")
	SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)

/// Marks the build complete and tells anyone waiting on it
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/finish_derelict_build()
	deltimer(derelict_watchdog_timer)
	derelict_watchdog_timer = null
	derelict_state = DERELICT_STATE_READY
	log_game("DERELICT OUTPOST: '[name]' built ([theme_id], [shell_template?.name], band [derelict_band]) with [derelict_hostiles_alive()] hostile\s")
	SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, TRUE)

/// Gives up on a build that never finished: recovers if the level itself loaded, otherwise reverts to dormant
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/derelict_build_watchdog(serial)
	derelict_watchdog_timer = null
	if(serial != derelict_build_serial || derelict_state != DERELICT_STATE_BUILDING)
		return
	derelict_build_serial++
	log_mapping("DERELICT OUTPOST: '[true_name]' stalled while building.")
	message_admins("The derelict outpost '[true_name]' stalled while building.")
	if(loaded)
		derelict_state = DERELICT_STATE_READY
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, TRUE)
	else
		name = initial(name)
		display_name = name
		desc = initial(desc)
		derelict_state = DERELICT_STATE_DORMANT
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)

/// Count of derelict_hostiles that still resolve to a living, non-dead mob
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/derelict_hostiles_alive()
	. = 0
	for(var/datum/weakref/hostile_ref as anything in derelict_hostiles)
		var/mob/living/hostile = hostile_ref.resolve()
		if(!istype(hostile) || QDELETED(hostile))
			continue
		if(hostile.stat != DEAD)
			.++

/obj/structure/overmap/dynamic/player_outpost/derelict/is_loaded()
	return loaded && (derelict_state == DERELICT_STATE_READY || derelict_state == DERELICT_STATE_CLAIMED)

/obj/structure/overmap/dynamic/player_outpost/derelict/is_loading()
	return derelict_state == DERELICT_STATE_BUILDING

// ===== LAZY DOCK (the space-ruin pattern) =====

/obj/structure/overmap/dynamic/player_outpost/derelict/ship_act(mob/user, obj/structure/overmap/ship/acting, obj/structure/overmap/ship/optional_partner, dock_variant)
	if(!is_loaded())
		if(acting.is_interdicted)
			to_chat(user, span_warning("Cannot dock while interdicted!"))
			return
		acting.request_site_load(src, user)
		return
	return ..()

/obj/structure/overmap/dynamic/player_outpost/derelict/start_level_load(mob/user, obj/structure/overmap/ship/waiting_ship)
	INVOKE_ASYNC(src, PROC_REF(build_derelict), waiting_ship)

// ===== BERTHS =====

/obj/structure/overmap/dynamic/player_outpost/derelict/allocate_berth(obj/structure/overmap/ship/ship)
	. = ..()
	if(. && derelict_state != DERELICT_STATE_CLAIMED)
		set_berth_dark(., TRUE)

// ===== CLAIM =====

/obj/structure/overmap/dynamic/player_outpost/derelict/can_claim(mob/living/user)
	if(derelict_state == DERELICT_STATE_DORMANT || derelict_state == DERELICT_STATE_BUILDING)
		return FALSE
	return ..()

/obj/structure/overmap/dynamic/player_outpost/derelict/transfer_ownership(mob/living/new_owner, mob/user, admin_override = FALSE)
	if(derelict_state == DERELICT_STATE_DORMANT || derelict_state == DERELICT_STATE_BUILDING)
		return FALSE
	var/was_ready = derelict_state == DERELICT_STATE_READY
	. = ..()
	if(. && was_ready)
		on_derelict_claimed(new_owner, user)

/// Called when the derelict is claimed for the first time
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/on_derelict_claimed(mob/living/new_owner, mob/user)
	derelict_state = DERELICT_STATE_CLAIMED
	icon_state = "station"
	sensor_category = "Outposts"
	desc = "An independent outpost."
	relight_berths()
	set_derelict_ambience(FALSE)
	log_game("DERELICT OUTPOST: [key_name(new_owner)] claimed '[name]' ([theme_id]) with [derelict_hostiles_alive()] hostile\s alive")
	message_admins("[key_name_admin(new_owner)] claimed the derelict outpost '[name]'.")

// ===== PRESENTATION WHILE UNCLAIMED (each falls through to ..() once claimed) =====

/obj/structure/overmap/dynamic/player_outpost/derelict/get_contact_variant()
	if(derelict_state == DERELICT_STATE_CLAIMED)
		return ..()
	return null

/obj/structure/overmap/dynamic/player_outpost/derelict/get_dock_description()
	if(derelict_state == DERELICT_STATE_CLAIMED)
		return ..()
	return "[name] (boarding)"

/obj/structure/overmap/dynamic/player_outpost/derelict/examine(mob/user)
	if(derelict_state == DERELICT_STATE_CLAIMED)
		return ..()
	. = list()
	. += get_name_chaser(user)
	if(desc)
		. += "<i>[desc]</i>"

/// The name this contact shows `viewer` in place of its own, exactly like an unsurveyed ruin
/obj/structure/overmap/dynamic/player_outpost/derelict/identified_contact_name(obj/structure/overmap/ship/viewer)
	if(derelict_state != DERELICT_STATE_DORMANT || !true_name)
		return null
	if(surveyed || viewer?.can_identify_ruins())
		return true_name
	return null

/// Only a claimed derelict is home to anyone; unclaimed, visiting hulls take the ordinary clocks
/obj/structure/overmap/dynamic/player_outpost/derelict/shelters_docked_hulls()
	return derelict_state == DERELICT_STATE_CLAIMED

// ===== SPAWNING =====

/// Places this round's derelict on an empty yellow or red tile, if there is none yet. Returns it, or null.
/datum/controller/subsystem/overmap/proc/spawn_derelict_outpost(theme, datum/map_template/player_outpost/shell_type, band)
	if(GLOB.derelict_outpost)
		return null
	band ||= pick(ZONE_YELLOW, ZONE_RED)
	var/turf/spot = get_unused_overmap_square_in_zone_band(band, tries = DERELICT_PLACEMENT_TRIES)
	if(!spot)
		band = (band == ZONE_YELLOW) ? ZONE_RED : ZONE_YELLOW
		spot = get_unused_overmap_square_in_zone_band(band, tries = DERELICT_PLACEMENT_TRIES)
	if(!spot)
		log_mapping("DERELICT OUTPOST: no empty yellow or red tile, none this round")
		return null
	shell_type ||= pick(outpost_selectable_shells())
	theme ||= pick(DERELICT_THEMES)
	var/obj/structure/overmap/dynamic/player_outpost/derelict/site = new(spot)
	site.setup_derelict(shell_type, theme, band)
	log_mapping("DERELICT OUTPOST: '[site.true_name]' ([site.theme_id], [initial(shell_type.name)]) placed at ([spot.x], [spot.y]) in band [band]")
	return site

// ===== ADMIN =====

ADMIN_VERB(admin_spawn_derelict_outpost, R_ADMIN, "Spawn Derelict Outpost", "Place this round's derelict outpost on the overmap. It builds when a ship first docks.", ADMIN_CATEGORY_EVENTS)
	if(GLOB.derelict_outpost)
		var/list/coords = GLOB.derelict_outpost.get_relative_overmap_coords()
		to_chat(user, span_warning("A derelict outpost already exists this round[coords ? " (at grid [coords[1]], [coords[2]])" : ""]."))
		return
	var/theme_choice = tgui_input_list(user, "Theme", "Spawn Derelict Outpost", list("Random") + DERELICT_THEMES)
	if(isnull(theme_choice))
		return
	var/band_choice = tgui_input_list(user, "Zone band", "Spawn Derelict Outpost", list("Random", "Yellow", "Red"))
	if(isnull(band_choice))
		return
	var/list/shells = list("Random" = null)
	for(var/datum/map_template/player_outpost/shell_type as anything in outpost_selectable_shells())
		shells[initial(shell_type.name)] = shell_type
	var/style_choice = tgui_input_list(user, "Style", "Spawn Derelict Outpost", shells)
	if(isnull(style_choice))
		return
	var/band = (band_choice == "Yellow") ? ZONE_YELLOW : (band_choice == "Red") ? ZONE_RED : null
	var/theme = (theme_choice == "Random") ? null : theme_choice
	var/obj/structure/overmap/dynamic/player_outpost/derelict/site = SSovermap.spawn_derelict_outpost(theme, shells[style_choice], band)
	if(!site)
		to_chat(user, span_warning("Failed to place the derelict outpost. No free overmap square?"))
		return
	log_admin("[key_name(user)] spawned the derelict outpost '[site.true_name]'.")
	message_admins("[key_name_admin(user)] spawned the derelict outpost '[site.true_name]'.")
	BLACKBOX_LOG_ADMIN_VERB("Spawn Derelict Outpost")

ADMIN_VERB(admin_load_derelict_outpost, R_ADMIN, "Load Derelict Outpost", "Build this round's derelict outpost now instead of waiting for a ship.", ADMIN_CATEGORY_EVENTS)
	var/obj/structure/overmap/dynamic/player_outpost/derelict/site = GLOB.derelict_outpost
	if(!site)
		to_chat(user, span_warning("There is no derelict outpost this round."))
		return
	if(site.derelict_state != DERELICT_STATE_DORMANT)
		to_chat(user, span_warning("The derelict outpost is already building or built."))
		return
	INVOKE_ASYNC(site, TYPE_PROC_REF(/obj/structure/overmap/dynamic/player_outpost/derelict, build_derelict), null)
	log_admin("[key_name(user)] force-loaded the derelict outpost '[site.true_name]'.")
	message_admins("[key_name_admin(user)] force-loaded the derelict outpost '[site.true_name]'.")
