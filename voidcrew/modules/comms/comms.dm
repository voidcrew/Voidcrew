/*
 * # Voidcrew comms
 *
 * Upstream radio depends on telecomms machinery and z-level routing, neither of which
 * works in the overmap: ships have no telecomms, hop between recycled z-levels, and
 * share a z-level with whatever else is parked at the same overmap tile.
 *
 * Instead, vocal radio signals here skip telecomms entirely (see
 * /datum/signal/subspace/vocal/voidcrew, created in /obj/item/radio/talk_into_impl)
 * and are scoped by network key rather than z-level:
 *
 * * Ship channel: every frequency except the unscoped ones below. Messages are stamped
 *   with the speaker's network (bound ship, or physical location as fallback) and only
 *   reach radios matching that network. Radios bind to a ship lazily the first time they
 *   send/receive while physically aboard, at job spawn for headsets, or via multitool.
 *   Binding is sticky, so away teams and boarding parties keep their crew channel.
 * * Wideband (:w): galaxy-wide hailing channel carried by every headset.
 *
 * Counterplay stays at the item level: EMPs, radio jammers, and stealing headsets
 * (a stolen headset stays bound to its home ship until re-tuned with a multitool).
 */

/// Frequencies that are never scoped to a ship/zone: anyone tuned in hears them galaxy-wide.
GLOBAL_LIST_INIT(voidcrew_unscoped_frequencies, list(
	"[FREQ_WIDEBAND]" = TRUE,
	"[FREQ_SYNDICATE]" = TRUE,
	"[FREQ_ENTERTAINMENT]" = TRUE,
	"[FREQ_CENTCOM]" = TRUE,
))

/obj/item/radio
	/// Weakref to the /obj/docking_port/mobile this radio's ship-scoped channels are bound to.
	/// Sticky: leaving the ship does not unbind, only re-tuning or the ship being destroyed.
	var/datum/weakref/comms_ship_ref

/// Resolve (and lazily establish) the ship this radio is bound to.
/// Returns a mobile docking port, or null if unbound and not currently aboard a ship.
/obj/item/radio/proc/get_bound_comms_ship()
	var/obj/docking_port/mobile/bound = comms_ship_ref?.resolve()
	if(!QDELETED(bound))
		return bound
	comms_ship_ref = null
	bound = SSshuttle.get_containing_shuttle(src)
	if(!bound)
		return null
	comms_ship_ref = WEAKREF(bound)
	return bound

/// Bind this radio's ship-scoped channels to the given ship (or unbind with null).
/obj/item/radio/proc/bind_comms_to_ship(obj/docking_port/mobile/ship)
	comms_ship_ref = ship ? WEAKREF(ship) : null

/**
 * Network key for a physical location, for anything speaking off a ship.
 *
 * "zone_[z]" meant "this encounter" only for as long as each encounter owned a z-level of its
 * own. Sites share levels now, and the net key is the ENTIRE filter here (broadcast() sends
 * with levels = list(0), no range gate at all), so a bare z key hands crew A's away team every
 * local transmission from crew B standing on the next site over - silent, PvP-relevant and
 * with no feedback that it is happening.
 *
 * Keyed on the map region rather than on SSovermap_zones.get_overmap_object_for_turf(): this
 * runs inside matches_comms_net(), once per candidate radio per transmission, and the region
 * lookup is one list index plus at most four rectangle tests where the overmap-object walk is
 * a scan of every site in the galaxy. Ground that belongs to no region keeps "zone_[z]", which
 * is what it always meant there - a roundstart level, transit.
 *
 * Does NOT touch the ship-channel architecture: bound radios still key on "ship_[REF(port)]"
 * and matches_comms_net() still matches on either, so boarders keep their own crew channel
 * while overhearing local traffic.
 */
/proc/voidcrew_physical_comms_net(turf/here)
	if(!here)
		return null
	var/datum/region = map_region_for_turf(here)
	if(region)
		return "site_[REF(region)]"
	return "zone_[here.z]"

/// Network key for wherever this radio physically is right now.
/obj/item/radio/proc/get_physical_comms_net()
	var/obj/docking_port/mobile/container = SSshuttle.get_containing_shuttle(src)
	if(container)
		return "ship_[REF(container)]"
	return voidcrew_physical_comms_net(get_turf(src))

/// Network key this radio stamps onto scoped transmissions.
/obj/item/radio/proc/get_comms_net()
	var/obj/docking_port/mobile/bound = get_bound_comms_ship()
	if(bound)
		return "ship_[REF(bound)]"
	return get_physical_comms_net()

/// Whether this radio can hear a message scoped to the given network key. Matches on
/// either our bound ship or wherever we physically are, so boarders keep their own crew
/// channel while also overhearing local traffic of the ship they're standing in.
/obj/item/radio/proc/matches_comms_net(net)
	if(isnull(net))
		return TRUE
	var/obj/docking_port/mobile/bound = get_bound_comms_ship()
	if(bound && net == "ship_[REF(bound)]")
		return TRUE
	return net == get_physical_comms_net()

/// Human-readable name of the ship this radio is bound to, for chat tags and feedback.
///
/// display_name, not name: a ship's `name` is copied off its mobile docking port
/// (SSshuttle.create_ship), and that port name carries two pieces of bookkeeping the
/// crew was never meant to read - the hull variant letter the template picked, and the
/// duplicate-id counter tg appends in /obj/docking_port/mobile/Initialize. An unrenamed
/// hull tagged every line it spoke "[Goon-class Repurposed Emergency Shuttle C 10]".
/// display_name is the template name, which is what every other player-facing readout
/// (holopads, sensors, dock listings) already uses.
/obj/item/radio/proc/get_comms_ship_name()
	var/obj/docking_port/mobile/voidcrew/bound = get_bound_comms_ship()
	if(!bound)
		return null
	if(istype(bound) && bound.current_ship)
		return bound.current_ship.display_name || bound.current_ship.name
	return bound.name

/// Multitool re-tunes the radio's ship channel to whatever ship it is currently aboard.
/obj/item/radio/multitool_act(mob/living/user, obj/item/tool)
	var/obj/docking_port/mobile/here = SSshuttle.get_containing_shuttle(src)
	if(!here)
		balloon_alert(user, "no ship signature here!")
		return ITEM_INTERACT_BLOCKING
	bind_comms_to_ship(here)
	tool.play_tool_sound(src, 25)
	balloon_alert(user, "tuned to [get_comms_ship_name()]")
	return ITEM_INTERACT_SUCCESS

/**
 * Telecomms-free vocal signal. /obj/item/radio/talk_into_impl creates this subtype in
 * place of the upstream one; instead of waiting on telecomms machinery to process and
 * rebroadcast it, it stamps itself with the speaker's comms network and broadcasts
 * immediately, with the network filter applied in broadcast().
 */
/datum/signal/subspace/vocal/voidcrew

/datum/signal/subspace/vocal/voidcrew/send_to_receivers()
	var/turf/source_turf = get_turf(source)
	var/obj/item/radio/origin = source

	// Scope everything but the galaxy-wide channels to the speaker's network
	if(!GLOB.voidcrew_unscoped_frequencies["[frequency]"])
		if(istype(origin))
			data["voidcrew_net"] = origin.get_comms_net()
		else if(source_turf)
			// Same site key the listening radios compute for themselves - see
			// voidcrew_physical_comms_net(). A z-level key here would put every speaker on a
			// packed encounter level onto one net.
			data["voidcrew_net"] = voidcrew_physical_comms_net(source_turf)

	// Channel tag shown in chat
	if(isnull(data["frequency_name"]))
		if(frequency == FREQ_COMMON)
			data["frequency_name"] = (istype(origin) && origin.get_comms_ship_name()) || "Local"
		else
			for(var/channel in GLOB.default_radio_channels)
				if(GLOB.default_radio_channels[channel] == frequency)
					data["frequency_name"] = channel
					break

	// No telecomms means no signal degradation
	data["compression"] = 0
	// 0 = no z-level restriction; the source z is included so the delayed mundane
	// rebroadcast in /obj/item/radio/backup_transmission stands down
	levels = list(0)
	if(source_turf)
		levels |= source_turf.z
	mark_done()
	broadcast()

/// Past this amount of compression, gibberish replaces characters outright.
/// Mirrors the same define in code/game/machinery/telecomms/broadcasting.dm.
#define COMPRESSION_REPLACE_CHARACTER_THRESHOLD 30

// Copy of /datum/signal/subspace/vocal/broadcast() with the comms-network filter
// replacing z-level routing and the syndicate hear-everything special case removed
// (a galaxy with no z-restrictions would let syndicate radios snoop every ship).
/datum/signal/subspace/vocal/voidcrew/broadcast()
	set waitfor = FALSE

	// Perform final composition steps on the message.
	var/message = copytext_char(data["message"], 1, MAX_BROADCAST_LEN)
	if(!message)
		return
	var/compression = data["compression"]
	if(compression > 0)
		message = Gibberish(message, compression >= COMPRESSION_REPLACE_CHARACTER_THRESHOLD)

	var/list/signal_reaches_every_z_level = levels
	if(0 in levels)
		signal_reaches_every_z_level = RADIO_NO_Z_LEVEL_RESTRICTION

	var/net = data["voidcrew_net"]

	// Assemble the list of radios
	var/list/radios = list()
	switch (transmission_method)
		if (TRANSMISSION_SUBSPACE)
			var/list/all_radios_of_our_frequency = GLOB.all_radios["[frequency]"]
			if(LAZYLEN(all_radios_of_our_frequency))
				radios = all_radios_of_our_frequency.Copy()

			for(var/obj/item/radio/candidate as anything in radios.Copy())
				if(!candidate.can_receive(frequency, signal_reaches_every_z_level))
					radios -= candidate
					continue
				if(net && !candidate.matches_comms_net(net))
					radios -= candidate

		if (TRANSMISSION_RADIO)
			// Only radios not currently in subspace mode
			for(var/obj/item/radio/candidate in GLOB.all_radios["[frequency]"])
				if(candidate.subspace_transmission || !candidate.can_receive(frequency, signal_reaches_every_z_level))
					continue
				if(net && !candidate.matches_comms_net(net))
					continue
				radios += candidate

		if (TRANSMISSION_SUPERSPACE)
			// Only radios which are independent
			for(var/obj/item/radio/candidate in GLOB.all_radios["[frequency]"])
				if((candidate.special_channels & RADIO_SPECIAL_CENTCOM) && candidate.can_receive(frequency, signal_reaches_every_z_level))
					radios += candidate

	for(var/obj/item/radio/called_radio as anything in radios)
		called_radio.on_receive_message(data)

	// From the list of radios, find all mobs who can hear those.
	var/list/receive = get_hearers_in_radio_ranges(radios)

	// Add observers who have ghost radio enabled.
	for(var/mob/dead/observer/ghost in GLOB.player_list)
		if(get_chat_toggles(ghost.client) & CHAT_GHOSTRADIO)
			receive |= ghost

	// Render the message and have everybody hear it.
	// Always call this on the virtualspeaker to avoid issues.
	var/spans = data["spans"]
	var/list/message_mods = data["mods"]
	// Hear() lost its leading pre-rendered `message` argument upstream (tg #93020): every
	// hearer now composes its own message from the raw one, so the compose_message() call
	// that used to feed this loop is gone with it.

	for(var/atom/movable/hearer as anything in receive)
		if(!hearer)
			stack_trace("null found in the hearers list returned by the spatial grid. this is bad")
			continue
		spans -= blacklisted_spans
		hearer.Hear(virt, language, message, frequency, data["frequency_name"], data["frequency_color"], spans, message_mods, message_range = INFINITY)

	// This following recording is intended for research and feedback in the use of department radio channels
	if(length(receive))
		SSblackbox.LogBroadcast(frequency)

	var/spans_part = ""
	if(length(spans))
		spans_part = "(spans:"
		for(var/span in spans)
			spans_part = "[spans_part] [span]"
		spans_part = "[spans_part] ) "

	var/lang_name = data["language"]
	var/log_text = "\[[get_radio_name(frequency)]\] [spans_part]\"[message]\" (language: [lang_name])"

	var/mob/source_mob = virt.source

	if(ismob(source_mob))
		source_mob.log_message(log_text, LOG_TELECOMMS)
	else
		log_telecomms("[virt.source] [log_text] [loc_name(get_turf(virt.source))]")

	QDEL_IN(virt, 5 SECONDS)  // Make extra sure the virtualspeaker gets qdeleted

#undef COMPRESSION_REPLACE_CHARACTER_THRESHOLD
