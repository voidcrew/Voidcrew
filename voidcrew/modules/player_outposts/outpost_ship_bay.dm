/// The permanent ship bay: one map per outpost style (outpost_styles.dm). The base has none.
/datum/map_template/outpost_hangar/ship_bay
	name = "Outpost Ship Bay"
	mappath = null

/// The Grease Pit
/datum/map_template/outpost_hangar/ship_bay/rundown
	mappath = "voidcrew/_maps/map_files/outposts/outpost_ship_bay_greasepit.dmm"
	outpost_style = OUTPOST_STYLE_RUNDOWN

/datum/map_template/outpost_hangar/ship_bay/clean
	mappath = "voidcrew/_maps/map_files/outposts/outpost_ship_bay_clean.dmm"
	outpost_style = OUTPOST_STYLE_CLEAN

/// The shared ship bay template for `style`, or null when no bay map loads
/proc/outpost_ship_bay_template(style)
	var/static/list/templates = list()
	var/map_type = outpost_style_map(/datum/map_template/outpost_hangar/ship_bay, style || OUTPOST_STYLE_DEFAULT)
	if(!map_type)
		return null
	if(!(map_type in templates))
		templates[map_type] = new map_type
	var/datum/map_template/template = templates[map_type]
	return template?.width ? template : null

/// The baked picture of the ship bay drawn for `style` (tools/outpost_upgrade_previews), or null until it exists
/proc/outpost_ship_bay_preview(style)
	var/map_type = outpost_style_map(/datum/map_template/outpost_hangar/ship_bay, style || OUTPOST_STYLE_DEFAULT)
	var/preview = map_type && outpost_map_preview_name(map_type)
	if(!preview || !fexists("[OUTPOST_PREVIEW_DIR][preview].png"))
		return null
	return "[preview].png"

/obj/structure/overmap/dynamic/player_outpost
	var/ship_bay_installed = FALSE
	var/ship_bay_installing = FALSE
	/// A permanent interior in the level's bay zone, exclusively reserved for its current ship or rebuild.
	var/list/datum/outpost_berth/ship_bay/bay_berths = list()
	/// Never reuse an elevator destination while an old ride could still be pending.
	var/next_bay_floor_id = OUTPOST_MAX_BERTHS + 2
	var/list/pending_dock_variants = list()
	/// Service storage can be selected without connecting a construction tool.
	var/datum/weakref/service_silo

/obj/structure/overmap/dynamic/player_outpost/proc/ship_bay_material_cost()
	return list(/datum/material/iron = 100 * SHEET_MATERIAL_AMOUNT, /datum/material/glass = 50 * SHEET_MATERIAL_AMOUNT)

/// Prefer an explicit selection, then the existing construction link, then the only local silo.
/obj/structure/overmap/dynamic/player_outpost/proc/ship_bay_silo()
	var/obj/machinery/ore_silo/selected = service_silo?.resolve()
	if(!QDELETED(selected) && get_outpost_from_atom(selected) == src)
		return selected
	var/obj/machinery/ore_silo/silo = construction_console?.get_linked_silo()
	if(!QDELETED(silo) && get_outpost_from_atom(silo) == src)
		return silo
	var/list/available = service_silos()
	return length(available) == 1 ? available[1] : null

/obj/structure/overmap/dynamic/player_outpost/proc/service_silos()
	var/list/available = list()
	for(var/obj/machinery/ore_silo/silo as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/ore_silo))
		if(!QDELETED(silo) && get_outpost_from_atom(silo) == src)
			available += silo
	return available

/obj/structure/overmap/dynamic/player_outpost/proc/select_service_silo(mob/user, obj/machinery/ore_silo/silo)
	if(!is_current_treasury_user(user))
		return FALSE
	return link_service_silo(silo)

/// Permission is checked by the player panel or the admin manipulator before calling.
/obj/structure/overmap/dynamic/player_outpost/proc/link_service_silo(obj/machinery/ore_silo/silo)
	if(QDELETED(silo) || get_outpost_from_atom(silo) != src)
		return FALSE
	service_silo = WEAKREF(silo)
	for(var/datum/outpost_berth/ship_bay/bay as anything in bay_berths)
		bay?.reconcile_silo()
	return TRUE

/obj/structure/overmap/dynamic/player_outpost/proc/ship_bay_install_denial(mob/user)
	if(!is_current_management_user(user) || !can_spend(user))
		return "Not authorized."
	var/denial = ship_bay_setup_denial()
	if(denial)
		return denial
	if(!treasury || treasury.account_balance < OUTPOST_SHIP_BAY_COST)
		return "Insufficient outpost funds."
	var/obj/machinery/ore_silo/silo = ship_bay_silo()
	if(!silo)
		return "No silo selected."
	if(!silo.materials?.has_materials(ship_bay_material_cost()))
		return "Silo short of iron or glass."
	return null

/// Structural requirements shared by paid installation and administrative grants.
/obj/structure/overmap/dynamic/player_outpost/proc/ship_bay_setup_denial()
	if(ship_bay_installed || ship_bay_installing)
		return "Ship bay already installed or being prepared."
	if(loading || !loaded || !has_hangar_elevator())
		return "Needs a working elevator."
	return null

/// Load the permanent interior before granting the upgrade or taking payment.
/obj/structure/overmap/dynamic/player_outpost/proc/enable_ship_bays()
	var/denial = ship_bay_setup_denial()
	if(denial)
		return denial
	ship_bay_installing = TRUE
	var/datum/outpost_berth/ship_bay/bay = create_ship_bay()
	ship_bay_installing = FALSE
	if(QDELETED(src) || QDELETED(bay))
		return "The ship bay could not be prepared."
	ship_bay_installed = TRUE
	refresh_elevator_uis()
	return null

/obj/structure/overmap/dynamic/player_outpost/proc/install_ship_bay(mob/user)
	var/denial = ship_bay_install_denial(user)
	if(denial)
		return denial
	ship_bay_installing = TRUE
	var/datum/outpost_berth/ship_bay/bay = create_ship_bay()
	ship_bay_installing = FALSE
	if(QDELETED(src) || QDELETED(bay))
		return "The ship bay could not be prepared. No payment was taken."
	// Loading yields: revalidate ownership, funds and the selected silo before paying.
	denial = ship_bay_install_denial(user)
	if(denial)
		qdel(bay)
		return denial
	var/obj/machinery/ore_silo/silo = ship_bay_silo()
	if(!treasury.adjust_money(-OUTPOST_SHIP_BAY_COST, "Ship bay installation by [user.ckey]"))
		qdel(bay)
		return "Insufficient outpost funds."
	silo.materials.use_materials(ship_bay_material_cost())
	ship_bay_installed = TRUE
	refresh_elevator_uis()
	log_game("[key_name(user)] installed a permanent ship bay at [src].")
	return null

/**
 * Only installation creates the interior; docking never replaces its map or fixtures. The bay
 * loads into the level's bay zone (outpost_level_layout.dm), which it keeps until the bay is
 * removed or the outpost is deleted.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/create_ship_bay()
	if(length(bay_berths) && bay_berths[1])
		return null
	var/datum/outpost_berth/ship_bay/bay = new(src, next_bay_floor_id++, null)
	bay.bay_number = 1
	bay_berths = list(bay)
	var/datum/map_template/outpost_hangar/ship_bay/template = outpost_ship_bay_template(outpost_style)
	var/datum/outpost_zone/bay_zone = level_zone(OUTPOST_ZONE_BAY)
	if(!template || !bay_zone || template.width > bay_zone.get_width() || template.height > bay_zone.get_height())
		qdel(bay)
		return null
	// A bay removed a moment ago may still be wiping its zone.
	if(bay_zone.state == OUTPOST_ZONE_WIPING)
		var/deadline = world.time + 30 SECONDS
		UNTIL(bay_zone.state != OUTPOST_ZONE_WIPING || world.time > deadline)
		if(QDELETED(src) || QDELETED(bay))
			if(!QDELETED(bay))
				qdel(bay)
			return null
	if(!bay_zone.claim(bay))
		qdel(bay)
		return null
	bay.zone = bay_zone
	var/turf/origin = bay_zone.get_bottom_left()
	bay.hangar_bottom_left = origin
	bay.hangar_width = template.width
	bay.hangar_height = template.height
	bay.building = TRUE
	var/loaded_bay = template.load(origin)
	bay.building = FALSE
	if(!loaded_bay || QDELETED(src) || QDELETED(bay))
		if(QDELETED(bay))
			// Destroy() left the zone to us while the loader was writing into it.
			bay_zone.release()
		else
			qdel(bay)
		return null
	if(!bay.link_hangar_contents())
		qdel(bay)
		return null
	bay_zone.occupy()
	return bay

/obj/structure/overmap/dynamic/player_outpost/proc/available_ship_bay()
	var/datum/outpost_berth/ship_bay/bay = LAZYACCESS(bay_berths, 1)
	return ship_bay_installed && bay?.is_available() ? bay : null

/obj/structure/overmap/dynamic/player_outpost/proc/allocate_ship_bay(obj/structure/overmap/ship/visitor, datum/rebuild_owner)
	var/datum/outpost_berth/ship_bay/bay = LAZYACCESS(bay_berths, 1)
	if(!ship_bay_installed || QDELETED(visitor) || QDELETED(visitor.shuttle) || !bay?.assign_ship(visitor, rebuild_owner))
		return null
	return bay

/// Claim the empty bay before waiting for a loader or placing any part of a ship.
/obj/structure/overmap/dynamic/player_outpost/proc/reserve_rebuild_bay(datum/owner)
	var/datum/outpost_berth/ship_bay/bay = available_ship_bay()
	if(!bay || QDELETED(owner))
		return null
	bay.rebuild_owner = WEAKREF(owner)
	bay.update_status()
	return bay

/obj/structure/overmap/dynamic/player_outpost/proc/revoke_bay_materials()
	for(var/datum/outpost_berth/ship_bay/bay as anything in bay_berths)
		bay?.revoke_silo()

/obj/structure/overmap/dynamic/player_outpost/refresh_elevator_uis()
	. = ..()
	for(var/datum/outpost_berth/ship_bay/bay as anything in bay_berths)
		if(bay?.panel)
			SStgui.update_uis(bay.panel)

/datum/outpost_berth/ship_bay
	var/bay_number
	var/obj/machinery/computer/camera_advanced/base_construction/ship/bay/console
	var/silo_requested_at
	var/datum/weakref/approved_silo
	var/silo_owner_ckey
	var/datum/weakref/rebuild_owner
	var/release_pending = FALSE
	var/release_timer

/datum/outpost_berth/ship_bay/proc/is_available()
	return !QDELETED(src) && has_ground() && !QDELETED(dock) && !ship && !rebuild_owner && !release_pending && !dock.get_docked()

/datum/outpost_berth/ship_bay/proc/status_text()
	if(!has_ground())
		return "Preparing"
	if(rebuild_owner)
		var/datum/checkpoint_construction/job = rebuild_owner.resolve()
		return istype(job) ? job.bay_status() : "Rebuilding"
	if(is_ship_present())
		return "Docked"
	if(release_pending || ship?.state == OVERMAP_SHIP_UNDOCKING)
		return "Departing"
	return is_available() ? "Available" : "Reserved"

/datum/outpost_berth/ship_bay/proc/update_status()
	for(var/obj/machinery/status_display/outpost_berth/sign as anything in status_signs)
		sign.set_messages("SHIP BAY", ship?.name || status_text())
	outpost?.refresh_elevator_uis()

/datum/outpost_berth/ship_bay/proc/assign_ship(obj/structure/overmap/ship/visitor, datum/owner)
	if(QDELETED(src) || !has_ground() || QDELETED(dock))
		return FALSE
	if(owner)
		if(!IS_WEAKREF_OF(owner, rebuild_owner) || ship || dock?.get_docked())
			return FALSE
	else if(!is_available())
		return FALSE
	ship = visitor
	arrived = FALSE
	release_retries = 0
	reset_reserve_dock_to_home(dock)
	console?.attempt_ship_connection()
	setup_signals()
	if(rebuild_owner && arrival_watchdog)
		deltimer(arrival_watchdog)
		arrival_watchdog = null
	update_status()
	return TRUE

/datum/outpost_berth/ship_bay/proc/finish_rebuild(datum/owner)
	if(!IS_WEAKREF_OF(owner, rebuild_owner))
		return
	rebuild_owner = null
	if(release_pending || !ship)
		release()
	update_status()

/// A staged rebuild has already landed its hull here; hand the bay to its new ship record.
/datum/outpost_berth/ship_bay/proc/complete_rebuild(obj/structure/overmap/ship/rebuilt, datum/owner)
	if(QDELETED(src) || !IS_WEAKREF_OF(owner, rebuild_owner) || ship || QDELETED(rebuilt) || QDELETED(rebuilt.shuttle) || dock?.get_docked() != rebuilt.shuttle)
		return FALSE
	ship = rebuilt
	arrived = TRUE
	release_retries = 0
	RegisterSignal(ship, COMSIG_VOIDCREW_SHIP_DOCKED, PROC_REF(on_ship_docked))
	RegisterSignal(ship, COMSIG_QDELETING, PROC_REF(on_ship_deleted))
	rebuild_owner = null
	console?.attempt_ship_connection()
	update_status()
	return TRUE

/// Departure releases the visitor, never the outpost's permanent bay zone.
/datum/outpost_berth/ship_bay/release(force = FALSE)
	if(QDELETED(src))
		return
	if(rebuild_owner)
		return
	release_pending = TRUE
	if(dock?.get_docked())
		if(!release_timer && release_retries++ < 10)
			release_timer = addtimer(CALLBACK(src, PROC_REF(retry_release)), 1 SECONDS, TIMER_STOPPABLE)
		return
	if(arrival_watchdog)
		deltimer(arrival_watchdog)
		arrival_watchdog = null
	if(ship)
		UnregisterSignal(ship, list(COMSIG_VOIDCREW_SHIP_DOCKED, COMSIG_QDELETING))
	ship = null
	if(release_timer)
		deltimer(release_timer)
		release_timer = null
	arrived = FALSE
	release_pending = FALSE
	release_retries = 0
	revoke_silo()
	if(console)
		console.unset_machine()
		console.clear_construction_queue()
		console.clear_repair_journal(TRUE)
		for(var/obj/structure/ship_repair_drone/drone as anything in console.repair_drones.Copy())
			drone.unlink_console()
		console.disconnect_materials()
		console.current_ship = null
	reset_reserve_dock_to_home(dock)
	refresh_hangar_air()
	update_status()

/// The hangar keeps its own atmosphere. A departing hull leaves its own air on the pad, vacuum
/// from its outer plating included, and the sealed hangar would spend the next few minutes (and
/// a lot of atmos time) evening that out, drawing its pressure down for good. Every hangar
/// tile not under a ship goes back to the hangar's own air instead, already settled.
/datum/outpost_berth/ship_bay/proc/refresh_hangar_air()
	for(var/turf/open/tile in get_block())
		if(!tile.air || tile.blocks_air || istype(tile.loc, /area/shuttle))
			continue
		tile.air.copy_from(tile.create_gas_mixture())
		SSair.remove_from_active(tile)

/datum/outpost_berth/ship_bay/proc/retry_release()
	release_timer = null
	if(release_pending)
		release()

/datum/outpost_berth/ship_bay/check_arrival()
	if(rebuild_owner)
		return
	return ..()

/datum/outpost_berth/ship_bay/Destroy()
	if(release_timer)
		deltimer(release_timer)
		release_timer = null
	var/obj/structure/overmap/dynamic/player_outpost/home = outpost
	if(home && bay_number && LAZYACCESS(home.bay_berths, bay_number) == src)
		home.bay_berths[bay_number] = null
	rebuild_owner = null
	if(dock)
		dock.ship_bay = null
	revoke_silo()
	if(console)
		console.disconnect_materials()
		console.current_ship = null
		console.berth = null
		qdel(console)
		console = null
	return ..()

/datum/outpost_berth/ship_bay/link_hangar_contents()
	if(!..())
		return FALSE
	for(var/turf/location as anything in get_block())
		console = locate(/obj/machinery/computer/camera_advanced/base_construction/ship/bay) in location
		if(console)
			break
	if(!console)
		log_mapping("OUTPOST SHIP BAY: missing construction console.")
		return FALSE
	console.berth = src
	console.attempt_ship_connection()
	dock.name = "[outpost.name] Ship Bay"
	dock.ship_bay = src
	dock.mark_reserve_home()
	update_status()
	return TRUE

/datum/outpost_berth/ship_bay/on_ship_docked(datum/source)
	SIGNAL_HANDLER
	if(QDELETED(ship) || dock?.get_docked() != ship.shuttle)
		return
	arrived = TRUE
	update_status()
	if(arrival_watchdog)
		deltimer(arrival_watchdog)
		arrival_watchdog = null
	if(!console?.use_outpost_silo())
		console?.use_ship_silo()
	ship.ship_notify("Docked at [outpost.name], Ship Bay [bay_number]. The construction console is beside the south elevator. Bay equipment connects automatically to your outpost's silo, or your ship's silo when visiting. Choose the material source at the console.", "SHIP BAY", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

/datum/outpost_berth/ship_bay/proc/is_ship_present()
	return !QDELETED(outpost) && !QDELETED(ship) && !QDELETED(ship.shuttle) && ship.docked == outpost && ship.state == OVERMAP_SHIP_IDLE && dock?.get_docked() == ship.shuttle

/datum/outpost_berth/ship_bay/proc/request_silo(mob/user)
	if(!is_ship_present() || !console?.is_crew_member(user))
		return FALSE
	var/obj/structure/overmap/dynamic/player_outpost/home = outpost
	if(!home.founder_ckey || !home.ship_bay_silo())
		return FALSE
	if(console.use_outpost_silo())
		silo_requested_at = null
		return TRUE
	if(!silo_requested_at)
		silo_requested_at = world.time || 1
		home.notify_owner("[ship.name] requests outpost materials in Ship Bay [bay_number].", "SHIP BAY")
	return TRUE

/datum/outpost_berth/ship_bay/proc/approve_silo(mob/user)
	reconcile_silo()
	var/obj/structure/overmap/dynamic/player_outpost/home = outpost
	if(!is_ship_present() || !home.is_current_management_user(user) || !home.can_spend(user) || !silo_requested_at)
		return FALSE
	return grant_silo(user)

/// Called after owner approval or an authenticated administrative override.
/datum/outpost_berth/ship_bay/proc/grant_silo(mob/user)
	var/obj/structure/overmap/dynamic/player_outpost/home = outpost
	if(!is_ship_present() || !home.founder_ckey || QDELETED(console))
		return FALSE
	var/obj/machinery/ore_silo/silo = home.ship_bay_silo()
	if(!silo)
		return FALSE
	approved_silo = WEAKREF(silo)
	silo_owner_ckey = home.founder_ckey
	silo_requested_at = null
	if(!console.link_materials(silo))
		revoke_silo()
		return FALSE
	log_game("[key_name(user)] approved outpost silo access for [ship] at [home] Ship Bay [bay_number].")
	return TRUE

/datum/outpost_berth/ship_bay/proc/revoke_silo()
	silo_requested_at = null
	approved_silo = null
	silo_owner_ckey = null
	if(console && !QDELETED(console.get_linked_silo()) && get_outpost_from_atom(console.get_linked_silo()) == outpost)
		console.disconnect_materials()
		console.use_ship_silo()

/datum/outpost_berth/ship_bay/proc/reconcile_silo()
	if(release_pending && !dock?.get_docked())
		release()
	if(silo_requested_at && world.time - silo_requested_at >= OUTPOST_DOCK_REQUEST_TIMEOUT)
		silo_requested_at = null
	var/obj/structure/overmap/dynamic/player_outpost/home = outpost
	if(approved_silo && (!is_ship_present() || home.founder_ckey != silo_owner_ckey || home.ship_bay_silo() != approved_silo.resolve() || !console?.can_link_silo(approved_silo.resolve())))
		revoke_silo()
	// Automatic owner access is checked on every tool use too. Never retain a
	// stale connection after ownership, crew membership or the selected silo changes.
	var/obj/machinery/ore_silo/linked = console?.get_linked_silo()
	if(linked && !console.can_link_silo(linked))
		console.disconnect_materials()
		if(!console.use_outpost_silo())
			console.use_ship_silo()
	if(silo_requested_at && home?.is_owner_crew_ship(ship))
		silo_requested_at = null

/// A shore-side console exclusively bound to this visit, even before the ship lands.
/obj/machinery/computer/camera_advanced/base_construction/ship/bay
	name = "ship bay construction console"
	desc = "An outpost fabrication console for the ship in this bay. Includes construction, tiling, piping, lighting, paint, and repair controls."
	circuit = null
	console_upgrades = SHIP_CONSTRUCTION_ALL_UPGRADES
	var/datum/outpost_berth/ship_bay/berth

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/Initialize(mapload)
	. = ..()
	internal_rcd.construction_upgrades = RCD_ALL_UPGRADES
	internal_rcd.silo_link = TRUE
	internal_rtd = new(src)
	internal_rtd.ship_console = src
	internal_rtd.silo_mats = internal_rtd.AddComponent(/datum/component/remote_materials, FALSE, FALSE)
	internal_rtd.silo_link = TRUE
	internal_rtd.matter = 0
	internal_rpd = new(src)
	internal_rpd.ship_console = src
	internal_rpd.upgrade_flags |= RPD_UPGRADE_UNWRENCH
	internal_rpd.silo_mats = internal_rpd.AddComponent(/datum/component/remote_materials, FALSE, FALSE)
	internal_rpd.silo_link = TRUE
	internal_rld = new(src)
	internal_rld.ship_console = src
	internal_rld.construction_upgrades |= RCD_UPGRADE_SILO_LINK
	internal_rld.silo_mats = internal_rld.AddComponent(/datum/component/remote_materials, FALSE, FALSE)
	internal_rld.silo_link = TRUE
	internal_rld.matter = 0
	internal_painter = new(src)
	internal_painter.ship_console = src

/// A new visit must not mint RCD charge on each docking.
/obj/machinery/computer/camera_advanced/base_construction/ship/bay/restock_materials()
	return

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/Destroy()
	disconnect_materials()
	if(berth?.console == src)
		berth.console = null
	berth = null
	current_ship = null
	return ..()

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/attempt_ship_connection()
	current_ship = berth?.ship
	return !QDELETED(current_ship)

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/connect_to_shuttle(mapload, obj/docking_port/mobile/voidcrew/port, obj/docking_port/stationary/dock)
	return FALSE

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/is_crew_member(mob/user)
	return current_ship?.ship_team && ..()

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/can_operate()
	return !QDELETED(berth) && berth.ship == current_ship && berth.contains_turf(get_turf(src)) && berth.is_ship_present() && ..()

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/can_link_silo(obj/machinery/ore_silo/silo)
	if(QDELETED(silo) || !can_operate())
		return FALSE
	if(get_ship_from_atom(silo) == current_ship)
		return TRUE
	var/obj/structure/overmap/dynamic/player_outpost/home = berth.outpost
	if(!home.founder_ckey || home.ship_bay_silo() != silo || get_outpost_from_atom(silo) != home)
		return FALSE
	return home.is_owner_crew_ship(current_ship) || (home.founder_ckey == berth.silo_owner_ckey && berth.approved_silo?.resolve() == silo)

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(!can_operate() || !is_crew_member(user))
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/proc/disconnect_materials()
	internal_rcd?.silo_mats?.disconnect()
	internal_rtd?.silo_mats?.disconnect()
	internal_rpd?.silo_mats?.disconnect()
	internal_rld?.silo_mats?.disconnect()

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/proc/link_materials(obj/machinery/ore_silo/silo)
	if(!can_link_silo(silo))
		return FALSE
	link_internal_device(internal_rcd, internal_rcd.silo_mats, silo)
	link_internal_device(internal_rtd, internal_rtd.silo_mats, silo)
	link_internal_device(internal_rpd, internal_rpd.silo_mats, silo)
	link_internal_device(internal_rld, internal_rld.silo_mats, silo)
	return TRUE

/// Owners use their selected outpost storage directly; visitors need a current grant.
/obj/machinery/computer/camera_advanced/base_construction/ship/bay/proc/use_outpost_silo()
	var/obj/structure/overmap/dynamic/player_outpost/home = berth?.outpost
	return link_materials(home?.ship_bay_silo())

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/proc/use_ship_silo()
	if(!can_operate())
		return FALSE
	disconnect_materials()
	for(var/obj/machinery/ore_silo/silo as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/ore_silo))
		if(get_ship_from_atom(silo) == current_ship)
			return link_materials(silo)
	return FALSE

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/ui_data(mob/user)
	berth?.reconcile_silo()
	. = ..()
	var/obj/machinery/ore_silo/silo = get_linked_silo()
	var/obj/structure/overmap/dynamic/player_outpost/home = berth?.outpost
	.["bay"] = list(
		"silo" = silo && can_link_silo(silo) ? silo.name : null,
		"outpost_materials" = !!silo && get_outpost_from_atom(silo) == home,
		"requested" = !!berth?.silo_requested_at,
		"available" = can_link_silo(home?.ship_bay_silo()),
	)

/obj/machinery/computer/camera_advanced/base_construction/ship/bay/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(action in list("bay_request_silo", "bay_ship_silo", "bay_outpost_silo"))
		if(ui.user != usr || ui.src_object != src || !is_crew_member(usr) || !can_operate() || ui_status(usr, state) != UI_INTERACTIVE)
			return TRUE
		switch(action)
			if("bay_request_silo")
				last_operation_success = berth.request_silo(usr)
				last_operation_message = last_operation_success ? (berth.silo_requested_at ? "Outpost materials requested." : "Using outpost materials.") : "No outpost silo is available."
			if("bay_ship_silo")
				last_operation_success = use_ship_silo()
				last_operation_message = last_operation_success ? "Using ship materials." : "No silo found aboard this ship."
			if("bay_outpost_silo")
				last_operation_success = use_outpost_silo()
				last_operation_message = last_operation_success ? "Using outpost materials." : "Outpost access unavailable."
		return TRUE
	return ..()

/// Material invoice shared by the ship-bay installation and construction UI.
/proc/outpost_material_data(list/cost, obj/machinery/ore_silo/silo)
	var/list/result = list()
	for(var/material_type in cost)
		var/datum/material/material = GET_MATERIAL_REF(material_type)
		result += list(list("name" = material.name, "sheets" = cost[material_type] / SHEET_MATERIAL_AMOUNT, "available" = (silo?.materials?.get_material_amount(material_type) || 0) / SHEET_MATERIAL_AMOUNT))
	return result

/// Both the advertised docking check and the physical move enforce the reservation.
/obj/docking_port/stationary
	var/datum/outpost_berth/ship_bay/ship_bay

/obj/docking_port/stationary/proc/allows_ship_bay_docking(obj/docking_port/mobile/visitor)
	return !ship_bay || (!QDELETED(ship_bay.ship) && ship_bay.ship.shuttle == visitor)
