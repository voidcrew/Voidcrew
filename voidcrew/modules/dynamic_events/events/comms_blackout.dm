/**
 * Ship-scoped port of TG's Communications Blackout
 * (code/modules/events/communications_blackout.dm).
 *
 * TG heavy-EMPs every entry in GLOB.telecomm_machines, because on a station every radio
 * message is relayed through a telecomms stack and knocking the stack out silences the
 * whole crew at once. Voidcrew has no telecomms at all. Vocal radio skips the machinery
 * entirely and is scoped per ship (see voidcrew/modules/comms/comms.dm), so there is no
 * relay to break and the port has to act on the radios themselves.
 *
 * The effect is the same from the crew's side: for about twenty seconds nobody aboard can
 * raise anybody, on any channel, including the galaxy-wide Wideband. Handsets, headsets,
 * intercoms and the ship's holopads all go down together. Radios come back on their own
 * (see /obj/item/radio/emp_act), so this needs no repair step and leaves nothing broken.
 */
/datum/round_event_control/voidcrew/comms_blackout
	name = "Communications Blackout"
	typepath = /datum/round_event/voidcrew/comms_blackout
	weight = 10
	max_occurrences = 4
	earliest_start = 10 MINUTES
	category = EVENT_CATEGORY_ENGINEERING
	description = "Every radio aboard the target ship cuts out for a short while."
	/// Losing comms only matters if the crew were relying on them to co-ordinate across
	/// the hull. On a hull where everyone is in shouting distance it is not an event.
	min_ship_mass = SHIP_MASS_MEDIUM
	min_crew_aboard = 2
	min_wizard_trigger_potency = 0
	max_wizard_trigger_potency = 3

/datum/round_event/voidcrew/comms_blackout
	announce_when = 1
	start_when = 1
	/// TG announces only 30% of the time so an AI can fake a blackout. There is no AI
	/// here, and an unexplained comms failure with no garbled warning first just reads as
	/// a bug, so the corrupted transmission always goes out.
	announce_chance = 100
	fakeable = TRUE

/datum/round_event/voidcrew/comms_blackout/announce(fake)
	if(!target_valid())
		return
	// The announcement degrading mid-sentence is the announcement: it arrives over the
	// same radios it is about, and gets cut off as they go.
	var/alert = pick(
		"Ionospheric anomalies detected. Temporary telecommunication failure imminent. Please contact you*%fj00)`5vc-BZZT",
		"Ionospheric anomalies detected. Temporary telecommunication failu*3mga;b4;'1v¬-BZZZT",
		"Ionospheric anomalies detected. Temporary telec#MCi46:5.;@63-BZZZZT",
		"Ionospheric anomalies dete'fZ\\kg5_0-BZZZZZT",
		"Ionospheri:%£ MCayj^j<.3-BZZZZZZT",
		"#4nd%;f4y6,>£%-BZZZZZZZT",
	)
	target_ship.ship_event_announce(alert, "Anomaly Alert")

/datum/round_event/voidcrew/comms_blackout/start()
	if(!target_valid())
		return

	// Radios live in pockets, on ears and in backpacks, not just on the deck, so the sweep
	// has to recurse into contents rather than read the areas' top level.
	var/blacked_out = 0
	for(var/area/ship_area as anything in target_ship.shuttle.shuttle_areas)
		for(var/obj/item/radio/handset as anything in ship_area.get_all_contents_type(/obj/item/radio))
			handset.emp_act(EMP_HEAVY)
			blacked_out++

	// Holopads carry the other half of ship comms here, hails, and the pirate channel.
	for(var/obj/machinery/holopad/pad as anything in target_ship.get_ship_machines(/obj/machinery/holopad))
		pad.emp_act(EMP_HEAVY)

	if(!blacked_out)
		return
	target_ship.play_ship_sound('sound/effects/empulse.ogg', 30)
