/**
 * # Pro utility chrome (Tier 2)
 *
 * The "I chose this build" shelf: Icepick Jack, Skyhook Wrist, Prospector
 * Suite, Hemoglass Filter, Coolant Loops, Heartbeat Doppler, Graverobber's
 * Jack and Angler's Spool. Arm hardware rides the toolkit base, optics the
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
#define CYBERWARE_GRAVEROBBER_SWEEP_RANGE 14
#define CYBERWARE_GRAVEROBBER_DEEP_SWEEP_RANGE 24
#define CYBERWARE_ANGLER_RANGE 6
/// Seconds of continuous filtration to scrub a radiation dose.
#define CYBERWARE_HEMOGLASS_RAD_PURGE_TIME 30
/// Trait string stamped on corpses/consoles the Graverobber has drained.
#define CYBERWARE_TRAIT_JACKED "cyberware_graverobber_jacked"

// ---- Shared HUD marks --------------------------------------------------

/**
 * Paints a client-image mark over a target only the viewer can see —
 * Prospector cache pings and Graverobber intel both use it. The image is
 * attached to the target atom, so it follows movers for its lifetime.
 */
/proc/cyberware_hud_mark(mob/living/viewer, atom/target, mark_color = "#ffb347", duration = 6 SECONDS)
	if(!viewer?.client || QDELETED(target))
		return
	var/image/mark = image('icons/effects/effects.dmi', target, "sonar_ping", ABOVE_ALL_MOB_LAYER)
	SET_PLANE_EXPLICIT(mark, ABOVE_LIGHTING_PLANE, target)
	mark.color = mark_color
	viewer.client.images += mark
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(cyberware_hud_mark_expire), viewer, mark), duration)

/proc/cyberware_hud_mark_expire(mob/living/viewer, image/mark)
	viewer?.client?.images -= mark

// ---- 12. Icepick Jack --------------------------------------------------

/**
 * # Icepick Jack (T2, arm aug, load 3)
 *
 * The raid hacker's data spike. Two channels on hostile turrets in line of
 * sight — a 3s suppress that drops one offline for 15s, and a 6s subvert
 * that turns its IFF your way for 10s — plus a slow force on bolted or
 * unpowered doors, spike to frame.
 *
 * The hard rules: outpost sanctuary turrets are IMMUNE (the embargo lever
 * stays sacred); jacking anything mounted on a player-owned ship works but
 * instantly trips an intrusion alarm to the owning crew; NPC and ruin
 * hardware goes down silently. Each turret family is disabled through its
 * own machinery — porta-turrets via toggle_on plus their disabled_time
 * cooldown, ship laser turrets via their own fire_cooldown — never a raw
 * emp_act.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/icepick
	name = "\improper Icepick Jack"
	desc = "A slim data spike folded into the wrist, tipped in monocrystal. Turret IFF buses and door motor controllers all speak the same few dialects, and the spike is fluent. Outpost enforcement hardware runs firmware it has never cracked."
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
	owning_ship.ship_notify("WARNING: Intrusion countermeasure alert — [machine.name] interface breached.", "SECURITY", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 40)

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
	name = "Icepick — Suppress"
	desc = "Spike a hostile turret in line of sight to force it offline for a spell, or slowly force a bolted or unpowered door you're standing at."
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
			bearer.balloon_alert(bearer, "door's live — just open it!")
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
	name = "Icepick — Subvert"
	desc = "A longer crack that rewrites a hostile turret's IFF: for ten seconds it fights for you."
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
		// Hull defense turrets can't be aimed at people at all — there is
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
 * A launched anchor and motorised winch in the forearm — the grapple gun's
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
		span_notice("The skyhook bites. The winch does not negotiate."),
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
 * nine tiles — the printable scanner can't see through walls, this can —
 * and flags any zone loot caches in the same sweep.
 */
/obj/item/organ/eyes/robotic/cyberware/prospector
	name = "\improper Prospector Suite optics"
	desc = "Amber-ringed surveyor eyes. On a blink-command they thump out a resonance pulse: ore veins light up straight through the rock, and cargo transponder echoes — cache signatures — come back with them. The handheld scanner needs line of sight; these don't."
	icon_state = "prospector"
	eye_color_left = "#b8860b"
	eye_color_right = "#b8860b"
	iris_overlay = null
	chrome_load = 2
	tier = CYBERWARE_TIER_2
	actions_types = list(/datum/action/cooldown/cyberware/prospector_pulse)

/datum/action/cooldown/cyberware/prospector_pulse
	name = "Resonance Pulse"
	desc = "Ping ore veins through rock and flag nearby cache signatures."
	button_icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	button_icon_state = "prospector"
	cooldown_time = 10 SECONDS

/datum/action/cooldown/cyberware/prospector_pulse/Activate(atom/target)
	var/mob/living/carbon/bearer = organ.owner
	mineral_scan_pulse(get_turf(bearer), CYBERWARE_PROSPECTOR_RANGE, scanner = bearer)
	playsound(bearer, 'sound/machines/sonar-ping.ogg', 25, TRUE)
	var/caches = 0
	for(var/obj/structure/closet/crate/zone_loot/cache in range(CYBERWARE_PROSPECTOR_RANGE, bearer))
		cyberware_hud_mark(bearer, cache, "#ffb347", 6 SECONDS)
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
 * continuously; drugs and alcohol scrub even faster — effective immunity —
 * unless you flip party mode, which idles those two channels rather than
 * fighting your evening. Radiation takes about thirty seconds of
 * filtration to clear. Toxin scrubbing never stops, party or not.
 */
/obj/item/organ/cyberimp/cyberware/hemoglass
	name = "\improper Hemoglass filter"
	desc = "A dialysis loop in borosilicate, teed into the vena cava. It pulls poisons, chems and rads out of the blood a little faster than trouble puts them in. The party-mode valve exists because the engineers were honest about their customers."
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
	owner.balloon_alert(owner, party_mode ? "party mode — recreational channels open" : "filter scrubbing everything")

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
 * starved down fast. Deliberately NOT fireproof — enough flamer fuel still
 * wins, which keeps the buyable MOD flamethrower an honest counter. Sits
 * on the seal ladder against the Void Chassis: pick your climate.
 */
/obj/item/organ/cyberimp/cyberware/coolant
	name = "\improper Coolant Loop lattice"
	desc = "Kilometres of microbore coolant line threaded between muscle and skin, trading a chunk of chrome load for a working climate system. Lava country stops being a hard wall and fire fights become arithmetic you can win — mostly."
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
 * tiles paint through walls as short-lived blips; hold still and you are
 * simply not there — the Aliens rule, and the PvP counterplay. Machines
 * never paint. The ping is real, symmetric audio: it plays at your
 * position with normal falloff, so anyone close can faintly hear you
 * listening.
 *
 * Motion gating is honest: positions are keyed by REF text and compared
 * turf-to-turf between life ticks, so only genuine movers blip, and the
 * blip is a snapshot of where the contact was — it doesn't track.
 */
/obj/item/organ/cyberimp/cyberware/doppler
	name = "\improper Heartbeat Doppler"
	desc = "A sonar transceiver socketed into the mastoid. Anything alive and moving within nine tiles paints straight through the walls; anything holding still doesn't exist. It pings out loud — quiet, but out loud."
	icon_state = "doppler"
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_CYBERWARE_EARS
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 2
	tier = CYBERWARE_TIER_2
	actions_types = list(/datum/action/item_action/organ_action/toggle)
	/// Whether the sonar is running.
	var/active = FALSE
	/// REF(mob) -> turf from the previous sweep; the motion gate.
	var/list/last_positions = list()

/obj/item/organ/cyberimp/cyberware/doppler/ui_action_click()
	active = !active
	last_positions.Cut()
	owner.balloon_alert(owner, active ? "sonar online" : "sonar offline")
	if(active)
		playsound(owner, 'sound/machines/sonar-ping.ogg', 20, TRUE)

/obj/item/organ/cyberimp/cyberware/doppler/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	active = FALSE
	last_positions.Cut()

/obj/item/organ/cyberimp/cyberware/doppler/on_life(seconds_per_tick, times_fired)
	. = ..()
	if(!active)
		return
	if(organ_flags & ORGAN_FAILING)
		last_positions.Cut() // no stale motion baseline when we come back
		return
	var/list/new_positions = list()
	var/nearest_mover = INFINITY
	for(var/mob/living/contact in range(CYBERWARE_DOPPLER_RANGE, owner))
		if(contact == owner || contact.stat == DEAD)
			continue
		var/key = REF(contact)
		var/turf/where = get_turf(contact)
		new_positions[key] = where
		var/turf/was = last_positions[key]
		if(isnull(was) || was == where)
			continue // new contact settling in, or a statue — no paint
		new /obj/effect/temp_visual/sonar_ping(owner.loc, owner, contact, "sonar_ping_small", FALSE)
		nearest_mover = min(nearest_mover, get_dist(owner, contact))
	last_positions = new_positions
	if(nearest_mover == INFINITY)
		return
	// Louder as they close; audible around you either way — that's the deal.
	var/ping_volume = clamp(45 - nearest_mover * 3, 15, 45)
	playsound(owner, 'sound/machines/sonar-ping.ogg', ping_volume, TRUE)
	if(nearest_mover <= 3) // close contact: the beep doubles up
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(playsound), owner, 'sound/machines/sonar-ping.ogg', ping_volume, TRUE), 0.4 SECONDS)

// ---- 22. Graverobber's Jack --------------------------------------------

/**
 * # Graverobber's Jack (T2, arm aug, load 2)
 *
 * A data spike for the dead: three seconds in a corpse's skull or a dead,
 * unpowered console reads whatever duty data rotted in there. Loot caches
 * nearby paint amber, patrol contacts paint red, and once in a while a
 * stale vault phrase decrypts cache transponders across the whole site.
 * Every officer corpse becomes a lockpick for the level. Each source reads
 * once — the spike burns what it drains.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/graverobber
	name = "\improper Graverobber's Jack"
	desc = "A corpse-reader spike with a charnel-house reputation. Skulls and dead consoles keep more than anyone bothers to wipe: patrol beats, cargo manifests, the occasional vault phrase. Three seconds of bad manners per read."
	icon_state = "graverobber"
	chrome_load = 2
	tier = CYBERWARE_TIER_2
	actions_types = list(/datum/action/cooldown/cyberware/graverobber)

/datum/action/cooldown/cyberware/graverobber
	name = "Data-Spike the Dead"
	desc = "Read a corpse's skull or a dead console for cache and patrol intel."
	button_icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	button_icon_state = "graverobber"
	cooldown_time = 20 SECONDS
	click_to_activate = TRUE

/// A jackable source: a dead mob, or a console that's broken or unpowered.
/datum/action/cooldown/cyberware/graverobber/proc/valid_source(atom/target)
	if(isliving(target))
		var/mob/living/body = target
		return body.stat == DEAD
	if(istype(target, /obj/machinery/computer))
		var/obj/machinery/computer/console = target
		return (console.machine_stat & (BROKEN | NOPOWER)) ? TRUE : FALSE
	return FALSE

/datum/action/cooldown/cyberware/graverobber/Activate(atom/target)
	var/mob/living/carbon/bearer = organ.owner
	if(!valid_source(target))
		bearer.balloon_alert(bearer, "nothing readable!")
		return FALSE
	if(!bearer.Adjacent(target))
		bearer.balloon_alert(bearer, "get closer!")
		return FALSE
	if(HAS_TRAIT(target, CYBERWARE_TRAIT_JACKED))
		bearer.balloon_alert(bearer, "already drained!")
		return FALSE
	bearer.balloon_alert(bearer, "spiking [isliving(target) ? "skull" : "console"]...")
	playsound(target, 'sound/machines/click.ogg', 40, TRUE)
	if(!do_after(bearer, 3 SECONDS, target))
		return FALSE
	ADD_TRAIT(target, CYBERWARE_TRAIT_JACKED, REF(organ))
	playsound(target, 'sound/effects/magic/disable_tech.ogg', 40, TRUE)

	var/caches = 0
	for(var/obj/structure/closet/crate/zone_loot/cache in range(CYBERWARE_GRAVEROBBER_SWEEP_RANGE, bearer))
		cyberware_hud_mark(bearer, cache, "#ffb347", 12 SECONDS)
		caches++
	var/patrols = 0
	for(var/mob/living/contact in range(CYBERWARE_GRAVEROBBER_SWEEP_RANGE, bearer))
		if(contact == bearer || contact.stat == DEAD || contact.client)
			continue
		cyberware_hud_mark(bearer, contact, "#ff5050", 8 SECONDS)
		patrols++
	to_chat(bearer, span_notice("The spike drinks: [caches] cache signature[caches == 1 ? "" : "s"], [patrols] patrol track[patrols == 1 ? "" : "s"]."))

	if(prob(15))
		var/deep_caches = 0
		for(var/obj/structure/closet/crate/zone_loot/cache in range(CYBERWARE_GRAVEROBBER_DEEP_SWEEP_RANGE, bearer))
			cyberware_hud_mark(bearer, cache, "#ffb347", 20 SECONDS)
			deep_caches++
		if(deep_caches)
			to_chat(bearer, span_boldnotice("A stale duty log gives up a vault phrase — cache transponders answer across the site."))
	StartCooldown()
	return TRUE

// ---- 23. Angler's Spool ------------------------------------------------

/**
 * # Angler's Spool (T2, arm aug, load 2)
 *
 * A winch-harpoon in the forearm that is also, sincerely, a fishing rod —
 * the toolkit extends it into your hand and you fish, no gear bought. The
 * harpoon action fires the barb up to six tiles to yank a loose item or a
 * small creature back to you; anything oversized or bolted down wins the
 * tug and drags YOU one tile toward it instead.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/angler
	name = "\improper Angler's Spool"
	desc = "A forearm winch spooled with monofilament, terminating in a barbed jig. Extended, it's an honest fishing rod; fired, it's a six-tile answer to the question 'can I have that from here?'. Heavy catches answer back."
	icon_state = "angler"
	chrome_load = 2
	tier = CYBERWARE_TIER_2
	items_to_create = list(/obj/item/fishing_rod/cyberware)
	actions_types = list(
		/datum/action/item_action/organ_action/toggle,
		/datum/action/cooldown/cyberware/harpoon,
	)

/// The rod half of the spool. Stock rod behavior — the implant's pitch is
/// that it's always on your arm, not that it out-fishes a real rod.
/obj/item/fishing_rod/cyberware
	name = "angler's spool"
	desc = "A winch-mounted fishing line running off a forearm implant. The reel hums when it's happy."
	ui_description = "A forearm-implant fishing rod. It only comes off the arm at a Chrome Cradle."
	show_in_wiki = FALSE
	force = 5

/datum/action/cooldown/cyberware/harpoon
	name = "Harpoon Barb"
	desc = "Fire the barb up to six tiles: loose items and small creatures come to you. Heavier catches drag you a tile toward them."
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

	// Everything else holds its ground — the winch moves the lighter end.
	fire_line(bearer, target)
	bearer.visible_message(
		span_warning("[bearer]'s line goes taut against [target] and hauls [bearer.p_them()] forward!"),
		span_notice("The line goes taut — [target] isn't coming, so you are."),
	)
	bearer.throw_at(get_step(bearer, get_dir(bearer, target)), 1, 1, spin = FALSE, gentle = TRUE)
	StartCooldown()
	return TRUE

/// The shared line visual + launch sound. The beam self-expires.
/datum/action/cooldown/cyberware/harpoon/proc/fire_line(mob/living/bearer, atom/target)
	bearer.Beam(target, icon_state = "fishing_line", time = 1 SECONDS, maxdistance = CYBERWARE_ANGLER_RANGE + 2, emissive = FALSE)
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
#undef CYBERWARE_GRAVEROBBER_SWEEP_RANGE
#undef CYBERWARE_GRAVEROBBER_DEEP_SWEEP_RANGE
#undef CYBERWARE_ANGLER_RANGE
#undef CYBERWARE_HEMOGLASS_RAD_PURGE_TIME
#undef CYBERWARE_TRAIT_JACKED
