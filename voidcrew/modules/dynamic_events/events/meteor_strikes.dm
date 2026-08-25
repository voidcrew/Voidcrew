/**
 * Ship-scoped ports of TG's meteor family (code/modules/events/meteors/): the space
 * dust storm, the meteor waves and the stray meteor.
 *
 * Rocks are launched through voidcrew/modules/dynamic_events/ship_debris.dm, which
 * confines each one to a corridor around the target ship (see that file for why)
 * TG's "spawn at the map edge, aim at the station" model can't be used here.
 *
 * All of these require the ship to be flying. A landed ship shares its ground with
 * whatever it landed on, and cratering a ruin (or the berth next door) because one
 * crew rolled a meteor wave is not the intent.
 */

/// Fine grit. Pits the hull, breaks a window if you are unlucky, kills nobody.
GLOBAL_LIST_INIT(voidcrew_meteors_micro, list(
	/obj/effect/meteor/dust = 6,
	/obj/effect/meteor/sand = 4,
))

/// The ordinary shower: mostly rock, the occasional oddity.
GLOBAL_LIST_INIT(voidcrew_meteors_shower, list(
	/obj/effect/meteor/dust = 5,
	/obj/effect/meteor/sand = 3,
	/obj/effect/meteor/medium = 8,
	/obj/effect/meteor/big = 2,
	/obj/effect/meteor/carp = 1,
	/obj/effect/meteor/emp = 1,
))

/// Deep-band storm. Every entry here can open the hull.
GLOBAL_LIST_INIT(voidcrew_meteors_storm, list(
	/obj/effect/meteor/medium = 8,
	/obj/effect/meteor/big = 7,
	/obj/effect/meteor/flaming = 4,
	/obj/effect/meteor/irradiated = 3,
	/obj/effect/meteor/emp = 3,
	/obj/effect/meteor/bluespace = 2,
	/obj/effect/meteor/carp = 2,
))

/**
 * One-off rocks. Weighted toward the interesting ones, since a stray meteor is a
 * single event rather than a wave and a plain rock makes for a dull one.
 *
 * Two upstream types are deliberately absent from every table here:
 * /obj/effect/meteor/cluster spawns its fragments using spaceDebrisStartLoc(), which
 * picks destinations at world scale and would throw them clean out of the corridor,
 * and /obj/effect/meteor/tunguska's five-tile devastation would delete a small hull
 * outright rather than damage it.
 */
GLOBAL_LIST_INIT(voidcrew_meteors_stray, list(
	/obj/effect/meteor/big = 20,
	/obj/effect/meteor/flaming = 18,
	/obj/effect/meteor/irradiated = 15,
	/obj/effect/meteor/bluespace = 15,
	/obj/effect/meteor/emp = 12,
	/obj/effect/meteor/carp = 10,
	/obj/effect/meteor/banana = 6,
	/obj/effect/meteor/meaty = 6,
	/obj/effect/meteor/meaty/xeno = 3,
))

/**
 * Shared behaviour for the wave events: every tick divisible by `wave_interval`,
 * throw `rocks_per_wave` rocks from `meteor_table` at the target ship.
 *
 * Abstract: the control datum has no typepath, so SSevents drops it on init.
 */
/datum/round_event_control/voidcrew/meteor_strike
	category = EVENT_CATEGORY_SPACE
	requires_flying = TRUE

/datum/round_event/voidcrew/meteor_strike
	announce_when = 1
	/// Weighted table of /obj/effect/meteor types this event throws.
	var/list/meteor_table
	/// Rocks launched per wave.
	var/rocks_per_wave = 2
	/// Ticks between waves (SSevents ticks are 2 seconds). 1 fires every tick.
	var/wave_interval = 3
	/// Whether a wave rumbles the hull. Confined rocks give up TG's z-wide camera
	/// shake (it would reach every other ship on the transit z), so wave events that
	/// throw hull-breaking rock do their own ship-scoped rumble instead.
	var/rumble_on_wave = TRUE

/datum/round_event/voidcrew/meteor_strike/tick()
	if(!target_valid())
		return
	if(wave_interval > 1 && (activeFor % wave_interval))
		return
	// The corridor is sized for open transit space. If the crew put down at a ruin or
	// a planet part-way through, hold fire rather than shell a berth we are sharing.
	if(target_ship.state != OVERMAP_SHIP_FLYING || target_ship.docked)
		return
	launch_wave()

/// Throws one wave of rock. Safe to call with an empty corridor, launches just fizzle.
/datum/round_event/voidcrew/meteor_strike/proc/launch_wave()
	if(!length(meteor_table))
		return
	var/launched = 0
	for(var/turf/aim_turf as anything in target_ship.get_random_ship_turfs(rocks_per_wave))
		if(target_ship.launch_ship_debris(pick_weight(meteor_table), aim_turf))
			launched++
	if(launched && rumble_on_wave)
		target_ship.shake_ship(4, 1)

/**
 * === Micrometeoroid shower (TG: Major Space Dust) ===
 *
 * The mild one. Grit strips paint and cracks the odd window; the point is the noise and
 * a bit of hull repair rather than the damage.
 *
 * Still not a green-band event. Mild is not the same as nothing: it is glass to replace
 * and plating to weld, and the green ring is where a crew is learning which end of the
 * ship is which. Nothing that costs materials belongs there.
 */
/datum/round_event_control/voidcrew/meteor_strike/micrometeoroids
	name = "Micrometeoroid Shower"
	typepath = /datum/round_event/voidcrew/meteor_strike/micrometeoroids
	weight = 12
	max_occurrences = 4
	description = "Grit and sand pit the target ship's hull."
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)
	/// Grit still cracks windows and scores plating. On a Pill-class that is the whole
	/// pressure envelope, so even the harmless one leaves the smallest hulls alone.
	min_ship_mass = SHIP_MASS_SMALL

/datum/round_event/voidcrew/meteor_strike/micrometeoroids
	announce_chance = 85
	start_when = 3
	end_when = 33
	rocks_per_wave = 2
	wave_interval = 2
	rumble_on_wave = FALSE

/datum/round_event/voidcrew/meteor_strike/micrometeoroids/setup()
	meteor_table = GLOB.voidcrew_meteors_micro

/datum/round_event/voidcrew/meteor_strike/micrometeoroids/announce(fake)
	if(!target_valid())
		return
	var/list/reasons = list(
		"We are passing through a debris cloud. Expect minor damage to external fittings.",
		"Particulate density ahead is above safe limits. Minor hull abrasion is likely.",
		"Sensors read a dust trail across our heading. Nothing we can steer around at this range.",
		"We have hit a rough patch of space. Mind the noise.",
	)
	target_ship.ship_event_announce(pick(reasons), "Collision Alert")

/**
 * === Meteor shower (TG: Meteor Wave) ===
 *
 * Real rock, in enough quantity to open compartments. Scaled well down from the
 * station version: five meteors every three ticks would strip a shuttle to the deck.
 */
/datum/round_event_control/voidcrew/meteor_strike/shower
	name = "Meteor Shower"
	typepath = /datum/round_event/voidcrew/meteor_strike/shower
	weight = 5
	max_occurrences = 3
	earliest_start = 20 MINUTES
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)
	description = "A meteor shower crosses the target ship."
	/// Twenty rocks arriving over a minute needs a hull with compartments to lose. A small
	/// one has no spare volume: the first breach is the last one.
	min_ship_mass = SHIP_MASS_MEDIUM
	min_wizard_trigger_potency = 3
	max_wizard_trigger_potency = 7

/datum/round_event/voidcrew/meteor_strike/shower
	start_when = 6
	end_when = 36
	rocks_per_wave = 2
	wave_interval = 3

/datum/round_event/voidcrew/meteor_strike/shower/setup()
	meteor_table = GLOB.voidcrew_meteors_shower

/datum/round_event/voidcrew/meteor_strike/shower/announce(fake)
	if(!target_valid())
		return
	target_ship.ship_event_announce(
		"Meteors detected on a collision course. Seal internal doors and get clear of the hull.",
		"Meteor Alert",
		ANNOUNCER_METEORS,
	)

/datum/round_event/voidcrew/meteor_strike/shower/end()
	if(!target_valid())
		return
	target_ship.ship_event_announce("The meteor stream has passed. Check the hull for breaches.", "Meteor Alert")

/**
 * === Meteor storm ===
 *
 * The deep-band version: heavier rock, more of it, and long enough to matter. Wants a
 * crew of at least two, because one person cannot patch a hull and fly at the same time.
 */
/datum/round_event_control/voidcrew/meteor_strike/storm
	name = "Meteor Storm"
	typepath = /datum/round_event/voidcrew/meteor_strike/storm
	// Admin-only. Twenty-four hull-opening rocks over three minutes, and its own
	// announcement says we cannot clear the field. The crew is told, correctly, that
	// there is nothing to do. Damage control after the fact is not counterplay. The
	// lighter meteor events survive because their warnings name an action worth taking.
	weight = 0
	max_occurrences = 0
	earliest_start = 35 MINUTES
	min_crew_aboard = 2
	allowed_zones = list(ZONE_RED)
	description = "A heavy meteor storm batters the target ship."
	/// Every rock in the storm table opens plating. Anything short of a Delta-class is
	/// simply deleted over the event's runtime rather than damaged by it.
	min_ship_mass = SHIP_MASS_LARGE
	min_wizard_trigger_potency = 5
	max_wizard_trigger_potency = 7

/datum/round_event/voidcrew/meteor_strike/storm
	start_when = 8
	end_when = 44
	rocks_per_wave = 2
	wave_interval = 3

/datum/round_event/voidcrew/meteor_strike/storm/setup()
	meteor_table = GLOB.voidcrew_meteors_storm

/datum/round_event/voidcrew/meteor_strike/storm/announce(fake)
	if(!target_valid())
		return
	target_ship.ship_event_announce(
		"Dense meteor field ahead and closing. We cannot clear it in time. All hands brace and stay out of the outer compartments.",
		"Meteor Alert",
		ANNOUNCER_METEORS,
	)

/datum/round_event/voidcrew/meteor_strike/storm/end()
	if(!target_valid())
		return
	target_ship.ship_event_announce("We are through the field. Damage control to the hull.", "Meteor Alert")

/**
 * === Stray meteor (TG: Stray Meteor) ===
 *
 * One rock, no wave. Announced a few seconds before it arrives so the crew gets a
 * chance to be somewhere else.
 */
/datum/round_event_control/voidcrew/stray_meteor
	name = "Stray Meteor"
	typepath = /datum/round_event/voidcrew/stray_meteor
	weight = 6
	max_occurrences = 4
	earliest_start = 15 MINUTES
	category = EVENT_CATEGORY_SPACE
	description = "Throws a single meteor through the target ship."
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)
	/// One big rock is a repair job on a real hull and a hull loss on a tiny one.
	min_ship_mass = SHIP_MASS_MEDIUM
	requires_flying = TRUE
	min_wizard_trigger_potency = 3
	max_wizard_trigger_potency = 7

/datum/round_event/voidcrew/stray_meteor
	announce_when = 1
	start_when = 5
	fakeable = FALSE
	/// The rock we are about to throw, rolled in setup() so announce() can name its signature.
	var/obj/effect/meteor/chosen_type

/datum/round_event/voidcrew/stray_meteor/setup()
	chosen_type = pick_weight(GLOB.voidcrew_meteors_stray)

/datum/round_event/voidcrew/stray_meteor/announce(fake)
	if(!target_valid())
		return
	var/signature = chosen_type ? initial(chosen_type.signature) : "motion"
	target_ship.ship_event_announce(
		"Our [signature] sensors have an inbound signature on a collision heading. Brace for impact.",
		"Meteor Alert",
	)

/datum/round_event/voidcrew/stray_meteor/start()
	if(!target_valid() || !chosen_type)
		return
	target_ship.launch_ship_debris(chosen_type)

/**
 * === Dark Matt-eor (TG: code/modules/events/meteors/dark_matteor_event.dm) ===
 *
 * Admin-only, exactly as upstream (weight 0, max_occurrences 0, it never enters the
 * random roster and only ever fires from the Trigger Event panel). This is not caution
 * carried over out of habit: the rock's meteordrop is /obj/singularity/dark_matter. If it
 * runs out of hits over a ship, that crew's round is over and so is the reservation.
 *
 * It also raises the security level to red on spawn and drops it back if it misses, both
 * of which are sector-wide side effects from a single ship's event. Left in, an admin
 * firing this one is not looking for subtlety.
 */
/datum/round_event_control/voidcrew/stray_meteor/dark_matteor
	name = "Dark Matt-eor"
	typepath = /datum/round_event/voidcrew/stray_meteor/dark_matteor
	weight = 0
	max_occurrences = 0
	earliest_start = 0
	allowed_zones = null
	min_ship_mass = SHIP_MASS_ANY
	description = "Throws a singularity-bearing meteor through the target ship. Ends the round for whoever it hits."

/datum/round_event/voidcrew/stray_meteor/dark_matteor
	announce_when = 1
	start_when = 8 // A longer run-up than an ordinary stray. You are meant to see it coming.

/datum/round_event/voidcrew/stray_meteor/dark_matteor/setup()
	chosen_type = /obj/effect/meteor/dark_matteor

/datum/round_event/voidcrew/stray_meteor/dark_matteor/announce(fake)
	if(!target_valid())
		return
	target_ship.ship_event_announce(
		"Massive gravitational signature on an intercept course. We do not have a classification for this. Brace.",
		"Meteor Alert",
		'sound/announcer/alarm/airraid.ogg',
	)
