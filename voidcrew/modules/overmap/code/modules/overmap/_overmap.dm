/obj/structure/overmap
	name = "overmap object"
	desc = "An unknown celestial object."
	icon = 'voidcrew/modules/overmap/icons/effects/overmap.dmi'
	icon_state = "object"
	// Disable emissive blockers - they cause visual artifacts (duplication, color inversion)
	// when viewed through popup map views like the helm console
	blocks_emissive = EMISSIVE_BLOCK_NONE

	/// Check that someone already act with this.
	var/concerned = FALSE
	/// Current integrity (turf count for ships). Updated via event-driven delta tracking.
	var/integrity = 100

	///List of other overmap objects in the same tile
	var/list/close_overmap_objects
	var/surveyed = FALSE
	/// Display name used by nav/combat UIs; defaults to name on Initialize. Ships keep theirs synced on rename.
	var/display_name

	// Hangar berth / elevator host state (see voidcrew/modules/trade/outpost_hangar.dm).
	// Trader outposts always host berths; player outposts do once a hangar elevator
	// is placed via the construction console.
	/// Bottom-left turf of this object's loaded interior template footprint, if any
	var/turf/template_bottom_left
	/// Hangar berth slots; berths[i] is the /datum/outpost_berth in slot i or null.
	/// Stays null until this object first hosts berths.
	var/list/berths
	/// Elevator alcove turfs on the concourse/lobby floor, in block() order
	var/list/turf/lobby_alcove_turfs = list()
	/// Concourse-side elevator panels
	var/list/obj/machinery/outpost_elevator/lobby_panels = list()

// voidcrew TODO: add the rest of overmap shit later

/obj/structure/overmap/proc/ship_act(mob/user, obj/structure/overmap/ship/acting)
	to_chat(user, "<span class='notice'>You don't think there's anything you can do here.</span>")

// Empty planets inherit ship_act from parent planet class to enable proper docking

/obj/structure/overmap/Initialize(mapload)
	. = ..()
	if(isnull(display_name))
		display_name = name
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_entered),
		COMSIG_ATOM_EXITED = PROC_REF(on_exited),
	)
	AddElement(/datum/element/connect_loc, loc_connections)

// ===== COMBAT TARGET API =====
// Ship weapons historically targeted only ships; these hooks let other overmap
// objects (raidable player outposts) opt in. See voidcrew/modules/ship_combat.

/// Notification hook used by combat/docking systems. Ships notify their crew,
/// player outposts their occupants and owner. No-op by default.
/obj/structure/overmap/proc/ship_notify(message, category = "ALERT", alert_level = SHIP_NOTIFY_NOTICE, sound_file = null, volume = 100)
	return

/// Whether ship weapons may acquire a lock on this object
/obj/structure/overmap/proc/is_combat_targetable()
	return FALSE

/// Areas that scope combat sounds/shakes/camera static to the target.
/// Null means "don't filter" — correct for targets that own their whole z-level.
/obj/structure/overmap/proc/get_combat_target_areas()
	return null

/// Interior rect for missile approach calculations: list(min_x, min_y, max_x, max_y), or null
/obj/structure/overmap/proc/get_combat_bounds()
	return null

/// Whether the combat camera eye may sit on the given turf of this target
/obj/structure/overmap/proc/combat_camera_can_view(turf/T)
	return FALSE

/// Turfs the combat camera generates interior static over; null = none
/obj/structure/overmap/proc/get_combat_camera_turfs()
	return null

/// A safe default aim turf on this target (fallback when no reticle position exists)
/obj/structure/overmap/proc/get_combat_default_turf()
	return null

// ===== BERTH HOST API =====
// Elevator panels and berth machinery back-reference their host loosely, so any
// overmap object that fills in the berth-host vars can serve hangar floors.
// The berth lifecycle procs themselves live in voidcrew/modules/trade/outpost_hangar.dm.

/// Called when someone attacks host-owned service machinery (elevator panels,
/// outpost doors). Trader outposts escalate to embargo/turrets; no-op by default.
/obj/structure/overmap/proc/register_aggression(mob/living/offender)
	return
/**
  * When something crosses another overmap object, add it to the nearby objects list, which are used by events and docking
  */
/obj/structure/overmap/proc/on_entered(datum/source, atom/movable/AM)
	SIGNAL_HANDLER
	if(istype(loc, /turf/) && istype(AM, /obj/structure/overmap))
		var/obj/structure/overmap/other = AM
		if(other == src)
			return
		LAZYOR(other.close_overmap_objects, src)
		LAZYOR(close_overmap_objects, other)

/**
  * See [/obj/structure/overmap/Crossed]
  */
/obj/structure/overmap/proc/on_exited(datum/source, atom/movable/AM)
	if(istype(loc, /turf/) && istype(AM, /obj/structure/overmap))
		var/obj/structure/overmap/other = AM
		if(other == src)
			return
		LAZYREMOVE(other.close_overmap_objects, src)
		LAZYREMOVE(close_overmap_objects, other)

/**
  * Mutually syncs the close-objects lists with every overmap object already sharing
  * this object's turf. on_entered only fires on movement, so an object spawned onto
  * an occupied tile (e.g. a freshly founded outpost under a still ship) is invisible
  * to docking and sensors until something re-crosses — call this to register it now.
  */
/obj/structure/overmap/proc/sync_close_overmap_objects()
	var/turf/our_turf = loc
	if(!istype(our_turf))
		return
	for(var/obj/structure/overmap/other in our_turf)
		if(other == src)
			continue
		LAZYOR(close_overmap_objects, other)
		LAZYOR(other.close_overmap_objects, src)
