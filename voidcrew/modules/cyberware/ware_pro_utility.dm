/**
 * # Pro utility chrome (Tier 2)
 *
 * The "I chose this build" shelf: Icepick Jack, Skyhook Wrist, Prospector
 * Suite, Hemoglass Filter, Coolant Loops, Heartbeat Doppler, Graverobber's
 * Jack and the Harpoon Spool. Arm hardware rides the toolkit base, optics the
 * eyes base, the rest the generic chest base. Every active ability hangs
 * off the /datum/action/cooldown/cyberware bridge, which supplies the
 * owner guard and the ORGAN_FAILING blackout.
 */

// Ranges and timings. The 15s/10s turret windows and the 9-tile pulse and
// sonar ranges are the design's numbers; the cooldowns are builder picks.
#define CYBERWARE_ICEPICK_TURRET_RANGE 7
#define CYBERWARE_ICEPICK_SUPPRESS_CHANNEL (3 SECONDS)
#define CYBERWARE_ICEPICK_SUPPRESS_DURATION (15 SECONDS)
#define CYBERWARE_ICEPICK_SUBVERT_CHANNEL (6 SECONDS)
#define CYBERWARE_ICEPICK_SUBVERT_DURATION (10 SECONDS)
#define CYBERWARE_ICEPICK_DOOR_CHANNEL (6 SECONDS)
#define CYBERWARE_SKYHOOK_RANGE 7
#define CYBERWARE_PROSPECTOR_RANGE 9
#define CYBERWARE_DOPPLER_RANGE 9
/// How long a Doppler contact stays painted after its last step. Every step
/// pushes it back out, so the paint lasts exactly as long as the motion does.
#define CYBERWARE_DOPPLER_FADE (4 SECONDS)
/// Floor on how often the Doppler re-derives who is in range. The sweep runs
/// off the bearer's own movement, which at a hard walk is five a second.
#define CYBERWARE_DOPPLER_SWEEP (0.5 SECONDS)
#define CYBERWARE_GRAVEROBBER_SWEEP_RANGE 14
#define CYBERWARE_GRAVEROBBER_DEEP_SWEEP_RANGE 24
#define CYBERWARE_ANGLER_RANGE 6
/// Seconds of continuous filtration to scrub a radiation dose.
#define CYBERWARE_HEMOGLASS_RAD_PURGE_TIME 30
/// Trait string stamped on corpses the Graverobber has drained.
#define CYBERWARE_TRAIT_JACKED "cyberware_graverobber_jacked"

// ---- Shared HUD marks --------------------------------------------------

/**
 * One HUD mark: a coloured blip only its viewer can see, sitting over some
 * target atom and (this is the whole point) drawn THROUGH walls.
 *
 * The image is parented to the VIEWER's own turf and pushed onto the target
 * with pixel offsets, never to the target itself. A client image parented to
 * the target is occluded exactly like the target is: put a wall between the
 * two and it simply never renders, which defeats every ware that uses this.
 * Sitting it on a turf the viewer is guaranteed to see and offsetting it is
 * the same trick tg's MODsuit sonar plays (temporary_visuals/miscellaneous.dm).
 *
 * Both ends are watched for movement, so the blip stays glued over a moving
 * target while its viewer walks around, and it tears itself down when either
 * end is deleted or its timer runs out.
 */
/datum/cyberware_hud_mark
	/// The only person this is drawn for.
	var/mob/living/viewer
	/// What the blip sits over.
	var/atom/target
	/// The client image doing the work.
	var/image/mark
	/// The list we were filed into, so we can strike ourselves off it.
	var/list/registry
	/// Our key in that list when it's associative; null for a flat list.
	var/registry_key
	/// Expiry timer handle, restarted by refresh().
	var/timer_id

/datum/cyberware_hud_mark/New(mob/living/new_viewer, atom/new_target, mark_color, duration, mark_state)
	. = ..()
	viewer = new_viewer
	target = new_target
	mark = image('icons/effects/effects.dmi', get_turf(viewer), mark_state, ABOVE_ALL_MOB_LAYER)
	mark.color = mark_color
	RegisterSignal(viewer, COMSIG_MOVABLE_MOVED, PROC_REF(on_end_moved))
	RegisterSignal(viewer, COMSIG_MOB_LOGIN, PROC_REF(on_viewer_login))
	RegisterSignal(viewer, COMSIG_QDELETING, PROC_REF(on_end_deleted))
	RegisterSignal(target, COMSIG_MOVABLE_MOVED, PROC_REF(on_end_moved))
	RegisterSignal(target, COMSIG_QDELETING, PROC_REF(on_end_deleted))
	reposition()
	refresh(duration)

/datum/cyberware_hud_mark/Destroy(force)
	if(timer_id)
		deltimer(timer_id)
		timer_id = null
	if(viewer)
		UnregisterSignal(viewer, list(COMSIG_MOVABLE_MOVED, COMSIG_MOB_LOGIN, COMSIG_QDELETING))
		viewer.client?.images -= mark
	if(target)
		UnregisterSignal(target, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
	if(registry)
		if(isnull(registry_key))
			registry -= src
		else if(registry[registry_key] == src)
			registry -= registry_key
		registry = null
		registry_key = null
	QDEL_NULL(mark)
	viewer = null
	target = null
	return ..()

/**
 * Re-aims the blip: parks the image on the viewer's turf and offsets it onto
 * the target. Runs on creation and on every move by either end.
 */
/datum/cyberware_hud_mark/proc/reposition()
	if(QDELETED(viewer) || QDELETED(target))
		qdel(src)
		return
	var/turf/viewer_turf = get_turf(viewer)
	var/turf/target_turf = get_turf(target)
	if(isnull(viewer_turf) || isnull(target_turf) || viewer_turf.z != target_turf.z)
		// Nothing sane to draw across a z jump. Park it until they line back up.
		viewer.client?.images -= mark
		return
	mark.loc = viewer_turf
	mark.pixel_w = ((target_turf.x - viewer_turf.x) * ICON_SIZE_X) + target.pixel_w
	mark.pixel_z = ((target_turf.y - viewer_turf.y) * ICON_SIZE_Y) + target.pixel_z
	SET_PLANE_EXPLICIT(mark, ABOVE_LIGHTING_PLANE, viewer_turf)
	viewer.client?.images |= mark

/// Pushes expiry back out. The Doppler leans on this: a contact that keeps
/// moving keeps its blip, a contact that stops loses it.
/datum/cyberware_hud_mark/proc/refresh(duration)
	if(timer_id)
		deltimer(timer_id)
	timer_id = QDEL_IN_STOPPABLE(src, duration)

/// Signal proc for [COMSIG_MOVABLE_MOVED] on either end: the offset between
/// them changed, so the blip has to be re-aimed.
/datum/cyberware_hud_mark/proc/on_end_moved(datum/source)
	SIGNAL_HANDLER
	reposition()

/// Signal proc for [COMSIG_QDELETING] on either end: no viewer or no target
/// means there is nothing left to draw.
/datum/cyberware_hud_mark/proc/on_end_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/// Signal proc for [COMSIG_MOB_LOGIN]: a fresh client starts with an empty
/// image list, so the blip has to be handed over again.
/datum/cyberware_hud_mark/proc/on_viewer_login(datum/source)
	SIGNAL_HANDLER
	reposition()

/**
 * Raises one HUD mark. Returns it, or null if there was nothing to mark.
 *
 * Pass `registry` to file the mark into a list the caller owns, so that owner
 * can drop it early. Every ware that raises marks clears them on the way
 * out. Add `registry_key` for an associative list; the mark strikes itself
 * off either shape when it dies, so no caller is left holding a dead ref.
 */
/proc/cyberware_hud_mark(mob/living/viewer, atom/target, mark_color = "#ffb347", duration = 6 SECONDS, mark_state = "sonar_ping", list/registry, registry_key)
	if(!isliving(viewer) || QDELETED(viewer) || QDELETED(target) || viewer == target)
		return null
	var/datum/cyberware_hud_mark/new_mark = new(viewer, target, mark_color, duration, mark_state)
	if(QDELETED(new_mark))
		return null
	if(isnull(registry))
		return new_mark
	new_mark.registry = registry
	new_mark.registry_key = registry_key
	if(isnull(registry_key))
		registry += new_mark
	else
		registry[registry_key] = new_mark
	return new_mark

// ---- 12. Icepick Jack --------------------------------------------------

/**
 * # Icepick Jack (T2, arm aug, load 3)
 *
 * The raid hacker's data spike. Two channels on hostile turrets in line of
 * sight, a 3s suppress that drops one offline for 15s, and a 6s subvert
 * that turns its IFF your way for 10s, plus a slow force on bolted or
 * unpowered doors, spike to frame.
 *
 * The hard rules: outpost sanctuary turrets are IMMUNE (the embargo lever
 * stays sacred); jacking anything mounted on a player-owned ship works but
 * instantly trips an intrusion alarm to the owning crew; NPC and ruin
 * hardware goes down silently. Each turret family is disabled through its
 * own machinery, porta-turrets via toggle_on plus their disabled_time
 * cooldown, ship laser turrets via their own fire_cooldown, never a raw
 * emp_act.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/icepick
	name = "\improper Icepick Jack"
	desc = "A slim data spike folded into the wrist, tipped in monocrystal. Turret IFF buses and door motor controllers all run the same handful of protocols, and the spike knows every one of them. Outpost security hardware is the one exception; nobody has cracked that firmware."
	icon_state = "icepick"
	chrome_load = 3
	tier = CYBERWARE_TIER_2
	actions_types = list(
		/datum/action/cooldown/cyberware/icepick/suppress,
		/datum/action/cooldown/cyberware/icepick/subvert,
	)

/// Restores a subverted turret's faction. Global so the restore survives
/// the organ (or its bearer) being deleted mid-window.
/proc/cyberware_restore_turret_faction(obj/machinery/porta_turret/turret, list/old_faction)
	if(QDELETED(turret))
		return
	turret.faction = old_faction

/// If the jacked machine sits on a player-owned ship, the owning crew
/// hears about it immediately. NPC hulls and ruins stay silent.
/proc/cyberware_turret_intrusion_alarm(atom/machine, mob/living/user)
	var/obj/structure/overmap/ship/owning_ship = get_ship_from_atom(machine)
	if(!istype(owning_ship) || istype(owning_ship, /obj/structure/overmap/ship/npc))
		return
	owning_ship.ship_notify("WARNING: Intrusion countermeasure alert, [machine.name] interface breached.", "SECURITY", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 40)

/// Shared trunk for both Icepick channels: the LOS/range gate lives here,
/// off the general cyberware bridge, so nothing else inherits it.
/datum/action/cooldown/cyberware/icepick
	button_icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	button_icon_state = "icepick"
	click_to_activate = TRUE

/// Shared LOS/range gate for turret spikes.
/datum/action/cooldown/cyberware/icepick/proc/spike_in_range(mob/living/bearer, atom/target, range)
	if(get_dist(bearer, target) > range || !(target in view(range, bearer)))
		bearer.balloon_alert(bearer, "no line to it!")
		return FALSE
	return TRUE

/datum/action/cooldown/cyberware/icepick/suppress
	name = "Icepick: Suppress"
	desc = "Spike a hostile turret in line of sight to knock it offline for a while, or slowly force open a bolted or unpowered door you're standing at."
	// Both channels are on the same spike, so both need their own face on the
	// HUD: two identical buttons is a misclick waiting to happen.
	button_icon_state = "act_icepick_suppress"
	cooldown_time = 30 SECONDS

/datum/action/cooldown/cyberware/icepick/suppress/Activate(atom/target)
	var/mob/living/carbon/bearer = organ.owner
	if(istype(target, /obj/machinery/porta_turret))
		if(istype(target, /obj/machinery/porta_turret/outpost))
			bearer.balloon_alert(bearer, "hardened firmware!")
			return FALSE
		if(!spike_in_range(bearer, target, CYBERWARE_ICEPICK_TURRET_RANGE))
			return FALSE
		bearer.balloon_alert(bearer, "spiking turret...")
		playsound(bearer, 'sound/machines/click.ogg', 40, TRUE)
		if(!do_after(bearer, CYBERWARE_ICEPICK_SUPPRESS_CHANNEL, target))
			return FALSE
		var/obj/machinery/porta_turret/turret = target
		turret.toggle_on(FALSE)
		COOLDOWN_START(turret, disabled_time, CYBERWARE_ICEPICK_SUPPRESS_DURATION)
		addtimer(CALLBACK(turret, TYPE_PROC_REF(/obj/machinery/porta_turret, toggle_on), TRUE), CYBERWARE_ICEPICK_SUPPRESS_DURATION)
		do_sparks(2, TRUE, turret)
		playsound(turret, 'sound/effects/magic/disable_tech.ogg', 50, TRUE)
		bearer.balloon_alert(bearer, "turret suppressed")
		cyberware_turret_intrusion_alarm(turret, bearer)
		StartCooldown()
		return TRUE

	if(istype(target, /obj/machinery/ship_combat/laser_turret))
		if(!spike_in_range(bearer, target, CYBERWARE_ICEPICK_TURRET_RANGE))
			return FALSE
		bearer.balloon_alert(bearer, "spiking turret...")
		if(!do_after(bearer, CYBERWARE_ICEPICK_SUPPRESS_CHANNEL, target))
			return FALSE
		var/obj/machinery/ship_combat/laser_turret/laser = target
		COOLDOWN_START(laser, fire_cooldown, CYBERWARE_ICEPICK_SUPPRESS_DURATION)
		laser.visible_message(span_warning("[laser]'s targeting array stutters and dies."))
		playsound(laser, 'sound/effects/magic/disable_tech.ogg', 50, TRUE)
		cyberware_turret_intrusion_alarm(laser, bearer)
		StartCooldown()
		return TRUE

	if(istype(target, /obj/machinery/door/airlock))
		var/obj/machinery/door/airlock/door = target
		if(!bearer.Adjacent(door))
			bearer.balloon_alert(bearer, "need to reach the frame!")
			return FALSE
		if(!door.density)
			bearer.balloon_alert(bearer, "already open!")
			return FALSE
		if(door.hasPower() && !door.locked)
			bearer.balloon_alert(bearer, "door's live, just open it!")
			return FALSE
		bearer.balloon_alert(bearer, "forcing door...")
		playsound(door, 'sound/machines/airlock/airlockforced.ogg', 30, TRUE)
		if(!do_after(bearer, CYBERWARE_ICEPICK_DOOR_CHANNEL, door))
			return FALSE
		if(!door.open(BYPASS_DOOR_CHECKS))
			bearer.balloon_alert(bearer, "mechanism jammed!")
			return FALSE
		StartCooldown()
		return TRUE

	bearer.balloon_alert(bearer, "no port for the spike!")
	return FALSE

/datum/action/cooldown/cyberware/icepick/subvert
	name = "Icepick: Subvert"
	desc = "A longer crack that rewrites a hostile turret's IFF: for ten seconds it fights for you."
	button_icon_state = "act_icepick_subvert"
	cooldown_time = 90 SECONDS

/datum/action/cooldown/cyberware/icepick/subvert/Activate(atom/target)
	var/mob/living/carbon/bearer = organ.owner
	if(!istype(target, /obj/machinery/porta_turret))
		bearer.balloon_alert(bearer, "no targeting bus!")
		return FALSE
	if(istype(target, /obj/machinery/porta_turret/outpost))
		bearer.balloon_alert(bearer, "hardened firmware!")
		return FALSE
	if(istype(target, /obj/machinery/porta_turret/ship_defense))
		// Hull defense turrets can't be aimed at people at all, there is
		// nothing for a subverted IFF to shoot. Suppress them instead.
		bearer.balloon_alert(bearer, "targeting bus rejects the handshake!")
		return FALSE
	if(!spike_in_range(bearer, target, CYBERWARE_ICEPICK_TURRET_RANGE))
		return FALSE
	bearer.balloon_alert(bearer, "rewriting IFF...")
	playsound(bearer, 'sound/machines/click.ogg', 40, TRUE)
	if(!do_after(bearer, CYBERWARE_ICEPICK_SUBVERT_CHANNEL, target))
		return FALSE
	var/obj/machinery/porta_turret/turret = target
	var/list/old_faction = turret.faction.Copy()
	turret.faction = bearer.faction.Copy()
	turret.toggle_on(TRUE)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(cyberware_restore_turret_faction), turret, old_faction), CYBERWARE_ICEPICK_SUBVERT_DURATION)
	do_sparks(3, TRUE, turret)
	playsound(turret, 'sound/effects/magic/disable_tech.ogg', 60, TRUE)
	turret.visible_message(span_warning("[turret] swivels with new purpose."))
	cyberware_turret_intrusion_alarm(turret, bearer)
	StartCooldown()
	return TRUE

// ---- 14. Skyhook Wrist -------------------------------------------------

/**
 * # Skyhook Wrist (T2, arm aug, load 3)
 *
 * A launched anchor and motorised winch in the forearm, the grapple gun's
 * zipline, surgically installed. Pick a dense, anchored wall or structure
 * within seven tiles and the line hauls you across, obstacle checks
 * courtesy of the throw physics. The cable is drawn with the same
 * zipline_hook beam the mining grapple uses; PvP legibility comes free.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/skyhook
	name = "\improper Skyhook wrist winch"
	desc = "A barbed anchor over a spooled monofilament winch, built through the wrist bones. Fire it into anything solid within seven tiles and hold on."
	icon_state = "skyhook"
	chrome_load = 3
	tier = CYBERWARE_TIER_2
	actions_types = list(/datum/action/cooldown/cyberware/skyhook)

/datum/action/cooldown/cyberware/skyhook
	name = "Skyhook"
	desc = "Grapple to a wall or anchored structure within seven tiles and zip across."
	button_icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	button_icon_state = "skyhook"
	cooldown_time = 8 SECONDS
	click_to_activate = TRUE
	/// The zipline visual for the current pull.
	var/datum/beam/zipline
	/// Traits worn for the duration of the pull, per the grapple gun.
	var/static/list/zipline_traits = list(
		TRAIT_IMMOBILIZED,
		TRAIT_MOVE_FLOATING,
		TRAIT_FORCED_STANDING,
	)

/datum/action/cooldown/cyberware/skyhook/Destroy()
	QDEL_NULL(zipline)
	return ..()

/// A skyhook anchor must be something the winch can trust: a dense closed
/// turf, or a dense anchored structure/machine.
/datum/action/cooldown/cyberware/skyhook/proc/valid_anchor(atom/target)
	if(isclosedturf(target))
		return TRUE
	if((isstructure(target) || ismachinery(target)) && target.density)
		var/obj/anchored_thing = target
		return anchored_thing.anchored
	return FALSE

/datum/action/cooldown/cyberware/skyhook/Activate(atom/target)
	var/mob/living/carbon/bearer = organ.owner
	if(!valid_anchor(target))
		bearer.balloon_alert(bearer, "nothing to bite on!")
		return FALSE
	var/dist = get_dist(bearer, target)
	if(dist < 2)
		bearer.balloon_alert(bearer, "too close to winch!")
		return FALSE
	if(dist > CYBERWARE_SKYHOOK_RANGE || !(target in view(CYBERWARE_SKYHOOK_RANGE, bearer)))
		bearer.balloon_alert(bearer, "out of line!")
		return FALSE
	if(bearer.buckled)
		bearer.balloon_alert(bearer, "buckled down!")
		return FALSE
	QDEL_NULL(zipline)
	zipline = bearer.Beam(target, icon_state = "zipline_hook", time = 3 SECONDS, maxdistance = CYBERWARE_SKYHOOK_RANGE + 2, layer = BELOW_MOB_LAYER)
	playsound(bearer, 'sound/items/weapons/zipline_fire.ogg', 60, TRUE)
	bearer.visible_message(
		span_warning("[bearer] fires a barbed line into [target] and zips along it!"),
		span_notice("The skyhook bites and the winch hauls you in."),
	)
	bearer.add_traits(zipline_traits, LEAPING_TRAIT)
	bearer.throw_at(target, CYBERWARE_SKYHOOK_RANGE + 1, 2, bearer, spin = FALSE, gentle = TRUE, callback = CALLBACK(src, PROC_REF(land), bearer))
	StartCooldown()
	return TRUE

/// Touchdown: shed the flight traits, cut the line. Takes the flier
/// explicitly so a mid-flight organ removal can't strand the traits.
/datum/action/cooldown/cyberware/skyhook/proc/land(mob/living/carbon/bearer)
	QDEL_NULL(zipline)
	if(QDELETED(bearer))
		return
	bearer.remove_traits(zipline_traits, LEAPING_TRAIT)
	new /obj/effect/temp_visual/mook_dust(get_turf(bearer))
	playsound(bearer, 'sound/items/weapons/zipline_hit.ogg', 40, TRUE)

// ---- 18. Prospector Suite ----------------------------------------------

/**
 * # Prospector Suite (T2, eyes, load 2)
 *
 * Surveyor optics on the golem ore-sight pattern: a player-triggered pulse
 * (never periodic processing) that lights ore veins through rock out to
 * nine tiles, the printable scanner can't see through walls, this can,
 * and flags any zone loot caches in the same sweep.
 */
/obj/item/organ/eyes/robotic/cyberware/prospector
	name = "\improper Prospector Suite optics"
	desc = "Amber-ringed surveyor eyes. Blink the command and they thump out a resonance pulse: ore veins light up straight through the rock, and any cache transponders in range echo back with them. The handheld scanner needs line of sight. These don't."
	icon_state = "prospector"
	eye_color_left = "#b8860b"
	eye_color_right = "#b8860b"
	iris_overlay = null
	chrome_load = 2
	tier = CYBERWARE_TIER_2
	actions_types = list(
		/datum/action/cooldown/cyberware/prospector_pulse,
		/datum/action/cooldown/cyberware/chrome_read,
	)
	/// Cache marks the last pulse raised, so pulling the optics takes them out
	/// with it instead of leaving blips on a client that no longer owns them.
	var/list/hud_marks = list()

/obj/item/organ/eyes/robotic/cyberware/prospector/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	clear_marks()
	return ..()

/obj/item/organ/eyes/robotic/cyberware/prospector/Destroy()
	clear_marks()
	return ..()

/// Drops every mark the pulse raised. Walks a copy: each mark strikes itself
/// off the list as it dies.
/obj/item/organ/eyes/robotic/cyberware/prospector/proc/clear_marks()
	for(var/datum/cyberware_hud_mark/mark as anything in hud_marks.Copy())
		qdel(mark)
	hud_marks.Cut()

/datum/action/cooldown/cyberware/prospector_pulse
	name = "Resonance Pulse"
	desc = "Ping ore veins through rock and flag nearby cache signatures."
	button_icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	button_icon_state = "prospector"
	cooldown_time = 10 SECONDS

/datum/action/cooldown/cyberware/prospector_pulse/Activate(atom/target)
	var/mob/living/carbon/bearer = organ.owner
	var/obj/item/organ/eyes/robotic/cyberware/prospector/optics = organ
	var/list/marks = istype(optics) ? optics.hud_marks : null
	mineral_scan_pulse(get_turf(bearer), CYBERWARE_PROSPECTOR_RANGE, scanner = bearer)
	playsound(bearer, 'sound/machines/sonar-ping.ogg', 25, TRUE)
	var/caches = 0
	for(var/obj/structure/closet/crate/zone_loot/cache in range(CYBERWARE_PROSPECTOR_RANGE, bearer))
		// Marks go up through the rock the same way the ore reveal does, a
		// cache you can already see was never the thing worth pinging for.
		cyberware_hud_mark(bearer, cache, "#ffb347", 6 SECONDS, registry = marks)
		caches++
	if(caches)
		bearer.balloon_alert(bearer, "[caches] cache signature[caches == 1 ? "" : "s"]")
	StartCooldown()
	return TRUE

// ---- 16. Hemoglass Filter ----------------------------------------------

/**
 * # Hemoglass Filter (T2, chest, filter slot, load 2)
 *
 * A glass-lined dialysis loop on the bloodstream. Toxins scrub out
 * continuously; drugs and alcohol scrub even faster, effective immunity,
 * unless you flip party mode, which idles those two channels rather than
 * fighting your evening. Radiation takes about thirty seconds of
 * filtration to clear. Toxin scrubbing never stops, party or not.
 */
/obj/item/organ/cyberimp/cyberware/hemoglass
	name = "\improper Hemoglass filter"
	desc = "A dialysis loop in borosilicate, teed into the vena cava. It strips poisons, chems and radiation out of your blood a little faster than most things can put them in. Party mode tells it to leave the recreational chems alone."
	icon_state = "hemoglass"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_FILTER
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 2
	tier = CYBERWARE_TIER_2
	actions_types = list(/datum/action/item_action/organ_action/toggle)
	/// TRUE while the drug/alcohol channels are deliberately idled.
	var/party_mode = FALSE
	/// Seconds of filtration accumulated against the current radiation dose.
	var/rad_purge_progress = 0

/obj/item/organ/cyberimp/cyberware/hemoglass/ui_action_click()
	party_mode = !party_mode
	owner.balloon_alert(owner, party_mode ? "party mode, recreational channels open" : "filter scrubbing everything")

/obj/item/organ/cyberimp/cyberware/hemoglass/on_life(seconds_per_tick, times_fired)
	. = ..()
	if(organ_flags & ORGAN_FAILING)
		return
	// Toxin purge runs regardless of the valve.
	owner.reagents?.remove_reagent(/datum/reagent/toxin, 0.8 * seconds_per_tick, include_subtypes = TRUE)
	if(!party_mode)
		owner.reagents?.remove_reagent(/datum/reagent/consumable/ethanol, 2 * seconds_per_tick, include_subtypes = TRUE)
		owner.reagents?.remove_reagent(/datum/reagent/drug, 2 * seconds_per_tick, include_subtypes = TRUE)
	// Radiation: slow, steady, deterministic.
	var/datum/component/irradiated/dose = owner.GetComponent(/datum/component/irradiated)
	if(dose)
		rad_purge_progress += seconds_per_tick
		if(rad_purge_progress >= CYBERWARE_HEMOGLASS_RAD_PURGE_TIME)
			qdel(dose)
			rad_purge_progress = 0
			owner.balloon_alert(owner, "radiation scrubbed")
	else
		rad_purge_progress = 0

// ---- 20. Coolant Loops -------------------------------------------------

/**
 * # Coolant Loops (T2, chest, seal slot, load 3)
 *
 * Circulating coolant woven through the torso: heat exposure damage is
 * trait-gated off, burns hit at half strength, and open flame on you gets
 * starved down fast. Deliberately NOT fireproof, enough flamer fuel still
 * wins, which keeps the buyable MOD flamethrower an honest counter. Sits
 * on the seal ladder above Second Wind: pick your climate.
 */
/obj/item/organ/cyberimp/cyberware/coolant
	name = "\improper Coolant Loop lattice"
	desc = "Kilometres of microbore coolant line threaded between muscle and skin: a full climate system for your body. You can work in lava country and walk out of fires that would cook anyone else. It eats a lot of chrome load to run."
	icon_state = "coolant"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_SEAL
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 3
	tier = CYBERWARE_TIER_2
	organ_traits = list(TRAIT_RESISTHEAT)

/obj/item/organ/cyberimp/cyberware/coolant/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	if(!ishuman(organ_owner))
		return
	var/mob/living/carbon/human/human_owner = organ_owner
	// Physiology persists across species changes (physiology.dm:1).
	human_owner.physiology.burn_mod *= 0.5

/obj/item/organ/cyberimp/cyberware/coolant/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	if(!ishuman(organ_owner) || QDELETED(organ_owner))
		return
	var/mob/living/carbon/human/human_owner = organ_owner
	human_owner.physiology.burn_mod /= 0.5

/obj/item/organ/cyberimp/cyberware/coolant/on_life(seconds_per_tick, times_fired)
	. = ..()
	if(organ_flags & ORGAN_FAILING)
		return
	if(owner.fire_stacks > 0)
		owner.adjust_fire_stacks(-1 * seconds_per_tick)

// ---- 21. Heartbeat Doppler ---------------------------------------------

/**
 * # Heartbeat Doppler (T2, head, ears slot, load 2)
 *
 * Toggle sonar in the mastoid bone. Living things that MOVE within nine
 * tiles paint through walls; hold still for four seconds and you drop off
 * the display entirely, the Aliens rule, and the PvP counterplay. Machines
 * never paint. The ping is real, symmetric audio: it plays at your
 * position with normal falloff, so anyone close can faintly hear you
 * listening.
 *
 * A contact's blip rides the contact rather than the tile it happened to be
 * on when the sonar last swept, and it re-aims whenever the BEARER moves as
 * well, both ends run off COMSIG_MOVABLE_MOVED, so the display is live
 * rather than a two-second-old snapshot. Every step a contact takes pushes
 * its blip's expiry back out, which is the whole motion gate: stop walking
 * and you fade off the display without the sonar having to compare turfs.
 *
 * That leaves the life tick two jobs, both of them bookkeeping: the audio,
 * and picking up anything that wandered into range while the bearer stood
 * still (nothing outside the watchlist can tell us it moved).
 */
/obj/item/organ/cyberimp/cyberware/doppler
	name = "\improper Heartbeat Doppler"
	desc = "A sonar transceiver socketed into the bone behind your ear. Anything alive and moving within nine tiles shows up through walls; anything holding still doesn't register at all. The ping is quiet, but it's out loud, so you're not the only one who knows it's running."
	icon_state = "doppler"
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_CYBERWARE_EARS
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 2
	tier = CYBERWARE_TIER_2
	actions_types = list(/datum/action/item_action/organ_action/toggle)
	/// Whether the sonar is running.
	var/active = FALSE
	/// Living things in range we hold movement and death hooks on. Assoc for
	/// the O(1) membership test; the values are dummies.
	var/list/watched = list()
	/// mob -> /datum/cyberware_hud_mark for every contact currently painted.
	/// A contact is in here only while it keeps moving.
	var/list/contacts = list()
	/// Earliest world.time the next watchlist sweep may run.
	var/next_sweep = 0

/obj/item/organ/cyberimp/cyberware/doppler/ui_action_click()
	if(active)
		stop_sonar(owner)
		owner.balloon_alert(owner, "sonar offline")
		return
	start_sonar()
	owner.balloon_alert(owner, "sonar online")
	playsound(owner, 'sound/machines/sonar-ping.ogg', 20, TRUE)

/obj/item/organ/cyberimp/cyberware/doppler/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	// A ware pulled and re-seated always comes up dark, and never carrying
	// hooks or blips from whoever wore it last.
	stop_sonar(organ_owner)

/obj/item/organ/cyberimp/cyberware/doppler/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	stop_sonar(organ_owner)
	return ..()

/obj/item/organ/cyberimp/cyberware/doppler/Destroy()
	stop_sonar(owner)
	return ..()

/// Brings the sonar up: one hook on the bearer for their own movement, then
/// a first sweep to find who is already standing in range.
/obj/item/organ/cyberimp/cyberware/doppler/proc/start_sonar()
	if(QDELETED(owner))
		return
	active = TRUE
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_bearer_moved), override = TRUE)
	sweep_watchlist(force = TRUE)

/**
 * Takes the sonar down and leaves nothing behind: every contact hook
 * unregistered, every blip dropped off the bearer's client. Takes the bearer
 * explicitly because organ removal nulls owner before on_mob_remove() runs.
 */
/obj/item/organ/cyberimp/cyberware/doppler/proc/stop_sonar(mob/living/carbon/bearer)
	active = FALSE
	next_sweep = 0
	for(var/mob/living/contact as anything in watched.Copy())
		unwatch_contact(contact)
	watched.Cut()
	for(var/mob/living/contact as anything in contacts.Copy())
		drop_contact(contact)
	contacts.Cut()
	if(bearer)
		UnregisterSignal(bearer, COMSIG_MOVABLE_MOVED)

/**
 * Re-derives which living things are close enough to be worth a hook.
 * Throttled, because it runs off the bearer's own movement.
 */
/obj/item/organ/cyberimp/cyberware/doppler/proc/sweep_watchlist(force = FALSE)
	if(!active || QDELETED(owner))
		return
	if(!force && world.time < next_sweep)
		return
	next_sweep = world.time + CYBERWARE_DOPPLER_SWEEP
	var/list/in_range = list()
	for(var/mob/living/contact in range(CYBERWARE_DOPPLER_RANGE, owner))
		if(contact == owner || contact.stat == DEAD)
			continue
		in_range[contact] = TRUE
		if(!watched[contact])
			watch_contact(contact)
	for(var/mob/living/contact as anything in watched.Copy())
		// A hard-deleted contact leaves a null key behind; drop it silently.
		if(isnull(contact))
			watched -= contact
			continue
		if(!QDELETED(contact) && in_range[contact])
			continue
		unwatch_contact(contact)

/// Starts listening to one contact. Its movement is what paints it.
/obj/item/organ/cyberimp/cyberware/doppler/proc/watch_contact(mob/living/contact)
	watched[contact] = TRUE
	RegisterSignal(contact, COMSIG_MOVABLE_MOVED, PROC_REF(on_contact_moved), override = TRUE)
	RegisterSignal(contact, COMSIG_LIVING_DEATH, PROC_REF(on_contact_lost), override = TRUE)
	RegisterSignal(contact, COMSIG_QDELETING, PROC_REF(on_contact_lost), override = TRUE)

/// Stops listening to one contact and takes its blip with it.
/obj/item/organ/cyberimp/cyberware/doppler/proc/unwatch_contact(mob/living/contact)
	drop_contact(contact)
	watched -= contact
	if(isnull(contact))
		return
	UnregisterSignal(contact, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_DEATH, COMSIG_QDELETING))

/// Drops one contact's blip. The mark clears itself out of contacts as it
/// dies, so the explicit subtract is only for a key that was nulled in place.
/obj/item/organ/cyberimp/cyberware/doppler/proc/drop_contact(mob/living/contact)
	if(isnull(contact))
		contacts -= contact
		return
	var/datum/cyberware_hud_mark/blip = contacts[contact]
	if(blip)
		qdel(blip)
	contacts -= contact

/**
 * Paints a contact, or pushes an existing blip's expiry back out. Called
 * from the contact's own movement, so this is the live half of the display.
 */
/obj/item/organ/cyberimp/cyberware/doppler/proc/paint_contact(mob/living/contact)
	if(!active || (organ_flags & ORGAN_FAILING) || QDELETED(owner) || QDELETED(contact))
		return
	if(contact.stat == DEAD || get_dist(owner, contact) > CYBERWARE_DOPPLER_RANGE || contact.z != owner.z)
		unwatch_contact(contact)
		return
	var/datum/cyberware_hud_mark/blip = contacts[contact]
	if(blip)
		blip.refresh(CYBERWARE_DOPPLER_FADE)
		return
	cyberware_hud_mark(owner, contact, "#9fd8ff", CYBERWARE_DOPPLER_FADE, "sonar_ping_small", contacts, contact)

/// Signal proc for [COMSIG_MOVABLE_MOVED] on the bearer: the set of things
/// close enough to hook changed. The blips re-aim themselves.
/obj/item/organ/cyberimp/cyberware/doppler/proc/on_bearer_moved(datum/source)
	SIGNAL_HANDLER
	sweep_watchlist()

/// Signal proc for [COMSIG_MOVABLE_MOVED] on a contact: motion is the only
/// thing the sonar can see.
/obj/item/organ/cyberimp/cyberware/doppler/proc/on_contact_moved(datum/source)
	SIGNAL_HANDLER
	paint_contact(source)

/// Signal proc for [COMSIG_LIVING_DEATH] and [COMSIG_QDELETING] on a contact:
/// a corpse has no heartbeat to hear, and a deleted mob must not be left as a
/// key in either list.
/obj/item/organ/cyberimp/cyberware/doppler/proc/on_contact_lost(datum/source)
	SIGNAL_HANDLER
	unwatch_contact(source)

/obj/item/organ/cyberimp/cyberware/doppler/on_life(seconds_per_tick, times_fired)
	. = ..()
	if(!active)
		return
	if(organ_flags & ORGAN_FAILING)
		// Browned out: the display goes with it, the hooks stay so it comes
		// straight back when the ware reboots.
		for(var/mob/living/contact as anything in contacts.Copy())
			drop_contact(contact)
		contacts.Cut()
		return
	// Backstop for anything that walked into range while we stood still, an
	// unhooked contact has no way to tell us it moved.
	sweep_watchlist()
	var/nearest_mover = INFINITY
	for(var/mob/living/contact as anything in contacts)
		if(isnull(contact))
			continue
		nearest_mover = min(nearest_mover, get_dist(owner, contact))
	if(nearest_mover == INFINITY)
		return
	// Louder as they close; audible around you either way. That's the deal.
	var/ping_volume = clamp(45 - nearest_mover * 3, 15, 45)
	playsound(owner, 'sound/machines/sonar-ping.ogg', ping_volume, TRUE)
	if(nearest_mover <= 3) // close contact: the beep doubles up
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(playsound), owner, 'sound/machines/sonar-ping.ogg', ping_volume, TRUE), 0.4 SECONDS)

// ---- 22. Graverobber's Jack --------------------------------------------

/**
 * # Graverobber's Jack (T2, arm aug, load 2)
 *
 * A data spike for the dead: three seconds in a corpse's skull reads whatever
 * duty data rotted in there. Loot caches nearby paint amber, patrol contacts
 * paint red, both through walls, which is the only reason the intel is worth
 * the twenty-second cooldown, and once in a while a stale vault phrase
 * decrypts cache transponders across the whole site. Every officer corpse
 * becomes a lockpick for the level. Each body reads once; the spike burns
 * what it drains.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/graverobber
	name = "\improper Graverobber's Jack"
	desc = "A spike for reading the dead. A skull holds onto more than anyone bothers to wipe: patrol routes, cargo manifests, the occasional vault phrase. Three seconds a body."
	icon_state = "graverobber"
	chrome_load = 2
	tier = CYBERWARE_TIER_2
	actions_types = list(/datum/action/cooldown/cyberware/graverobber)
	/// Intel marks the last read raised, so pulling the spike takes them out
	/// with it instead of leaving blips on a client that no longer owns them.
	var/list/hud_marks = list()

/obj/item/organ/cyberimp/arm/toolkit/cyberware/graverobber/on_mob_remove(mob/living/carbon/arm_owner, special = FALSE, movement_flags)
	clear_marks()
	return ..()

/obj/item/organ/cyberimp/arm/toolkit/cyberware/graverobber/Destroy()
	clear_marks()
	return ..()

/// Drops every mark the last read raised. Walks a copy: each mark strikes
/// itself off the list as it dies.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/graverobber/proc/clear_marks()
	for(var/datum/cyberware_hud_mark/mark as anything in hud_marks.Copy())
		qdel(mark)
	hud_marks.Cut()

/datum/action/cooldown/cyberware/graverobber
	name = "Data-Spike the Dead"
	desc = "Read a corpse's skull for cache and patrol intel."
	button_icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	button_icon_state = "graverobber"
	cooldown_time = 20 SECONDS
	click_to_activate = TRUE

/// A jackable source is a body, and only a body.
/datum/action/cooldown/cyberware/graverobber/proc/valid_source(atom/target)
	if(!isliving(target))
		return FALSE
	var/mob/living/body = target
	return body.stat == DEAD

/datum/action/cooldown/cyberware/graverobber/Activate(atom/target)
	var/mob/living/carbon/bearer = organ.owner
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/graverobber/spike = organ
	var/list/marks = istype(spike) ? spike.hud_marks : null
	if(!valid_source(target))
		bearer.balloon_alert(bearer, isliving(target) ? "still breathing!" : "no body to read!")
		return FALSE
	if(!bearer.Adjacent(target))
		bearer.balloon_alert(bearer, "get closer!")
		return FALSE
	if(HAS_TRAIT(target, CYBERWARE_TRAIT_JACKED))
		bearer.balloon_alert(bearer, "already drained!")
		return FALSE
	bearer.balloon_alert(bearer, "spiking skull...")
	playsound(target, 'sound/machines/click.ogg', 40, TRUE)
	if(!do_after(bearer, 3 SECONDS, target))
		return FALSE
	ADD_TRAIT(target, CYBERWARE_TRAIT_JACKED, REF(organ))
	playsound(target, 'sound/effects/magic/disable_tech.ogg', 40, TRUE)

	var/caches = 0
	for(var/obj/structure/closet/crate/zone_loot/cache in range(CYBERWARE_GRAVEROBBER_SWEEP_RANGE, bearer))
		cyberware_hud_mark(bearer, cache, "#ffb347", 12 SECONDS, registry = marks)
		caches++
	var/patrols = 0
	for(var/mob/living/contact in range(CYBERWARE_GRAVEROBBER_SWEEP_RANGE, bearer))
		if(contact == bearer || contact.stat == DEAD || contact.client)
			continue
		cyberware_hud_mark(bearer, contact, "#ff5050", 8 SECONDS, "sonar_ping_small", marks)
		patrols++
	to_chat(bearer, span_notice("The spike pulls [caches] cache signature[caches == 1 ? "" : "s"] and [patrols] patrol track[patrols == 1 ? "" : "s"]."))

	if(prob(15))
		var/deep_caches = 0
		for(var/obj/structure/closet/crate/zone_loot/cache in range(CYBERWARE_GRAVEROBBER_DEEP_SWEEP_RANGE, bearer))
			cyberware_hud_mark(bearer, cache, "#ffb347", 20 SECONDS, registry = marks)
			deep_caches++
		if(deep_caches)
			to_chat(bearer, span_boldnotice("A stale duty log coughs up a vault phrase. Cache transponders answer all across the site."))
	StartCooldown()
	return TRUE

// ---- 23. Harpoon Spool -------------------------------------------------

/**
 * # Harpoon Spool (T2, arm aug, load 2)
 *
 * The Skyhook's hardware wound the other way round. That one fires a line
 * into an anchor and drags you to it; this one fires a line at a target and
 * drags the target to you, a loose item or a small creature, up to six
 * tiles out. Anything oversized or bolted down wins the tug and hauls YOU
 * one tile toward it instead, which is a fair chunk of the appeal.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/angler
	name = "\improper Harpoon Spool"
	desc = "A forearm winch spooled with monofilament under a barbed head. Fired, it drags loose gear and small creatures to you from six tiles out, anything heavier drags you instead."
	icon_state = "angler"
	chrome_load = 2
	tier = CYBERWARE_TIER_2
	actions_types = list(/datum/action/cooldown/cyberware/harpoon)

/datum/action/cooldown/cyberware/harpoon
	name = "Harpoon Barb"
	desc = "Fire the barb up to six tiles: loose items and small creatures come to you. Anything heavier drags you a tile toward it instead."
	button_icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	button_icon_state = "angler"
	cooldown_time = 8 SECONDS
	click_to_activate = TRUE

/datum/action/cooldown/cyberware/harpoon/Activate(atom/target)
	var/mob/living/carbon/bearer = organ.owner
	if(isturf(target) || QDELETED(target))
		bearer.balloon_alert(bearer, "barb skitters off!")
		return FALSE
	if(get_dist(bearer, target) > CYBERWARE_ANGLER_RANGE || !(target in view(CYBERWARE_ANGLER_RANGE, bearer)))
		bearer.balloon_alert(bearer, "out of line!")
		return FALSE

	// Loose small-enough item: reel it in, catch it if it lands close.
	if(isitem(target))
		var/obj/item/caught = target
		if(!caught.anchored && caught.w_class <= WEIGHT_CLASS_NORMAL)
			fire_line(bearer, caught)
			caught.throw_at(get_turf(bearer), CYBERWARE_ANGLER_RANGE + 1, 2, callback = CALLBACK(src, PROC_REF(catch_item), caught))
			StartCooldown()
			return TRUE

	// Small creature: it comes to you, gently and against its wishes.
	if(isliving(target))
		var/mob/living/victim = target
		if(victim.mob_size <= MOB_SIZE_SMALL)
			fire_line(bearer, victim)
			victim.visible_message(
				span_warning("[bearer]'s line yanks [victim] through the air!"),
				span_userdanger("A barbed line yanks you off your feet!"),
			)
			victim.throw_at(get_turf(bearer), CYBERWARE_ANGLER_RANGE, 1, bearer, spin = FALSE, gentle = TRUE)
			StartCooldown()
			return TRUE

	// Everything else holds its ground. The winch moves the lighter end.
	fire_line(bearer, target)
	bearer.visible_message(
		span_warning("[bearer]'s line goes taut against [target] and hauls [bearer.p_them()] forward!"),
		span_notice("The line goes taut. [target] isn't coming, so you are."),
	)
	bearer.throw_at(get_step(bearer, get_dir(bearer, target)), 1, 1, spin = FALSE, gentle = TRUE)
	StartCooldown()
	return TRUE

/// The shared line visual + launch sound. Same monofilament the Skyhook
/// throws, so the two read as one piece of kit. The beam self-expires.
/datum/action/cooldown/cyberware/harpoon/proc/fire_line(mob/living/bearer, atom/target)
	bearer.Beam(target, icon_state = "zipline_hook", time = 1 SECONDS, maxdistance = CYBERWARE_ANGLER_RANGE + 2, emissive = FALSE, layer = BELOW_MOB_LAYER)
	playsound(bearer, 'sound/items/weapons/zipline_fire.ogg', 50, TRUE)

/// Reeled an item all the way home: into the hand if it's within reach.
/datum/action/cooldown/cyberware/harpoon/proc/catch_item(obj/item/caught)
	var/mob/living/carbon/bearer = organ?.owner
	if(QDELETED(caught) || !bearer)
		return
	if(caught.loc == get_turf(bearer) || bearer.Adjacent(caught))
		bearer.put_in_hands(caught)
		bearer.balloon_alert(bearer, "caught!")

#undef CYBERWARE_ICEPICK_TURRET_RANGE
#undef CYBERWARE_ICEPICK_SUPPRESS_CHANNEL
#undef CYBERWARE_ICEPICK_SUPPRESS_DURATION
#undef CYBERWARE_ICEPICK_SUBVERT_CHANNEL
#undef CYBERWARE_ICEPICK_SUBVERT_DURATION
#undef CYBERWARE_ICEPICK_DOOR_CHANNEL
#undef CYBERWARE_SKYHOOK_RANGE
#undef CYBERWARE_PROSPECTOR_RANGE
#undef CYBERWARE_DOPPLER_RANGE
#undef CYBERWARE_DOPPLER_FADE
#undef CYBERWARE_DOPPLER_SWEEP
#undef CYBERWARE_GRAVEROBBER_SWEEP_RANGE
#undef CYBERWARE_GRAVEROBBER_DEEP_SWEEP_RANGE
#undef CYBERWARE_ANGLER_RANGE
#undef CYBERWARE_HEMOGLASS_RAD_PURGE_TIME
#undef CYBERWARE_TRAIT_JACKED
