/// Seconds between scans while running. Deliberately slower than the 2s SSmachines tick so
/// a deployment reads as "leave it running and go do something", not a slot machine.
#define SURVEY_SCAN_INTERVAL (10 SECONDS)
/// Share of a site's value burned per scan at research_power 1. A better matter bin divides
/// this, so the upgrade buys a LONGER productive run rather than a bigger per-scan payout.
#define SURVEY_SCAN_DECAY 0.04
/// Once a site is worth less than this fraction, it is tapped out for the rest of the round.
#define SURVEY_MIN_PENALTY 0.20
/// Points per scan per servo rating, before the decay multiplier. 9/18/27/36.
#define SURVEY_GAIN_PER_SERVO 9

/**
 * Survey scanner
 *
 * A machine that generates research points, at the cost of power, instead of forcing
 * people to waste their time standing idle with an item in their hand.
 * Meant to be a stable way of generating points while encouraging moving to different planets
 * Without the cost of doing the same thing on repeat (like dissections).
 *
 * The whole point is that you haul it down to a planet and bolt it to the dirt, and every
 * planetoid area is always_unpowered - there is no APC down there to draw from. So this
 * deliberately opts out of the area powernet entirely and bills an internal cell instead.
 * Power is still the running cost, you just carry it with you.
 */
/obj/machinery/survey_scanner
	name = "survey scanner"
	desc = "A machine that scans whatever it is bolted to and refines the readings into research data. It runs off an internal power cell, so it works anywhere you can carry it."
	icon = 'voidcrew/modules/research/icons/objects.dmi'
	icon_state = "hivebot_fab"
	density = TRUE
	circuit = /obj/item/circuitboard/machine/survey_scanner
	processing_flags = START_PROCESSING_MANUALLY
	/// Never draw from the area. See the type comment - these get deployed where no APC exists.
	use_power = NO_POWER_USE
	idle_power_usage = NONE
	/// Joules per second pulled from the installed cell while scanning. The stock micro
	/// laser already halves this, so a high-capacity cell covers about one full planet's
	/// worth of scanning on otherwise stock parts.
	active_power_usage = BASE_MACHINE_ACTIVE_CONSUMPTION

	///Whether the machine is currently running or not.
	var/enabled = FALSE
	///The power cell we run off. Fitted through the open maintenance panel.
	var/obj/item/stock_parts/power_store/cell
	///Looping sound that plays when active.
	var/datum/looping_sound/oven/survey_audio
	///The strength of the machine, decreasing point penalty. Stretches how long a site stays
	///productive - it is NOT a payout multiplier, see process().
	var/research_power
	///The base research points you get, before taking penalty into account.
	var/research_gain
	///world.time of the next scan. Scans are paced by SURVEY_SCAN_INTERVAL, not by the tick.
	var/next_scan = 0
	///Amount of research points we've generated from processing.
	var/stored_points
	///How many times each SITE has been scanned, keyed by get_scan_history_key().
	///
	///Was keyed by z-level, which meant "this site" only while a site owned a z-level of its
	///own. Sites share levels now: crew B scanning at the encounter next door burned down
	///crew A's payout, and could push the shared counter past SURVEY_MIN_PENALTY so that A's
	///scanner reported "unable to locate valuable information" at ground nobody had touched.
	///`static` also meant the count outlived the z-level itself, so a recycled level handed
	///its next occupant a used-up site.
	var/static/list/site_scan_history = list()

/obj/machinery/survey_scanner/Initialize(mapload)
	. = ..()
	survey_audio = new(src)
	register_context()

/obj/machinery/survey_scanner/Destroy()
	QDEL_NULL(survey_audio)
	QDEL_NULL(cell)
	return ..()

/obj/machinery/survey_scanner/get_cell(atom/movable/interface, mob/user)
	return cell

/obj/machinery/survey_scanner/examine(mob/user)
	. = ..()
	if(cell)
		. += span_notice("It has \a [cell] installed, at [round(cell.percent())]% charge.")
	else
		. += span_warning("It has no power cell. Open the maintenance panel with a screwdriver to fit one.")
	if(stored_points)
		. += "It currently has [round(stored_points, 1)] points. You can Right-Click to print it."

/obj/machinery/survey_scanner/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(istype(held_item, /obj/item/stock_parts/power_store))
		context[SCREENTIP_CONTEXT_LMB] = panel_open ? "Install cell" : "Open panel first"
		return CONTEXTUAL_SCREENTIP_SET

	if(!isnull(held_item))
		return

	if(panel_open)
		if(cell)
			context[SCREENTIP_CONTEXT_LMB] = "Remove cell"
	else if(enabled)
		context[SCREENTIP_CONTEXT_LMB] = "Turn off"
	else
		context[SCREENTIP_CONTEXT_LMB] = "Turn on"
	context[SCREENTIP_CONTEXT_RMB] = "Extract Points"
	return CONTEXTUAL_SCREENTIP_SET

/obj/machinery/survey_scanner/update_icon_state()
	. = ..()
	//the panel sprite has to win, otherwise any later update_appearance() slams the hatch shut.
	if(panel_open)
		icon_state = "hivebot_fab-o"
	else if(!is_operational || !enabled)
		icon_state = "hivebot_fab"
	else
		icon_state = "hivebot_fab_on"

/// set_is_operational() is SHOULD_NOT_OVERRIDE - this is the hook meant for reacting to it.
/// Note the old override also had its condition inverted, so it shut the scanner down at
/// the moment it *became* operational rather than when it stopped being.
/obj/machinery/survey_scanner/on_set_is_operational(old_value)
	. = ..()
	if(enabled && !is_operational)
		disable()

/obj/machinery/survey_scanner/RefreshParts()
	. = ..()
	research_power = max(total_part_rating(/datum/stock_part/matter_bin), 1)
	research_gain = max(total_part_rating(/datum/stock_part/servo), 1) * SURVEY_GAIN_PER_SERVO //9, 18, 27, 36

	//cell drain is cut, not increased - better lasers mean one cell lasts longer.
	active_power_usage = initial(active_power_usage) / (1 + total_part_rating(/datum/stock_part/micro_laser))

/obj/machinery/survey_scanner/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return

	//the cell lives behind the panel, so that is what a bare hand reaches for while it is open.
	if(panel_open)
		if(!cell)
			balloon_alert(user, "no cell installed")
			return
		eject_cell(user)
		return

	if(!is_operational)
		return

	if(enabled)
		disable()
	else
		enable()

/obj/machinery/survey_scanner/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/stock_parts/power_store))
		return ..()

	if(!panel_open)
		balloon_alert(user, "open the panel first!")
		return ITEM_INTERACT_BLOCKING
	if(cell)
		balloon_alert(user, "already has a cell!")
		return ITEM_INTERACT_BLOCKING
	if(!user.transferItemToLoc(tool, src))
		return ITEM_INTERACT_BLOCKING

	cell = tool
	balloon_alert(user, "cell installed")
	to_chat(user, span_notice("You slot [tool] into [src]. Close the maintenance panel to run it."))
	playsound(src, 'sound/machines/click.ogg', 50, TRUE)
	return ITEM_INTERACT_SUCCESS

/**
 * eject_cell()
 *
 * Pops the installed cell out into the user's hands, shutting the scanner down first if
 * it is somehow still running.
 */
/obj/machinery/survey_scanner/proc/eject_cell(mob/living/user)
	if(!cell)
		return
	if(enabled)
		disable()

	var/obj/item/stock_parts/power_store/removed = cell
	cell = null
	removed.forceMove(drop_location())
	if(user)
		try_put_in_hand(removed, user)
		balloon_alert(user, "cell removed")
	playsound(src, 'sound/machines/click.ogg', 50, TRUE)

/obj/machinery/survey_scanner/attack_hand_secondary(mob/user, list/modifiers)
	. = ..()
	if(. == SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN)
		return
	if(!stored_points)
		say("No research points found, nothing to dispense.")
		return

	//accumulator is fractional (gain * decay), so only round at the point it becomes an item
	var/obj/item/research_notes/new_notes = new /obj/item/research_notes(src, round(stored_points, 1), pick(list("astronomy", "physics", "planets", "space")))
	//check for existing notes
	var/obj/item/research_notes/existing_notes = locate() in user
	if(existing_notes)
		// Fold the payout into the stack the user is already carrying. Deliberately attackby() and
		// not merge(): merge() grants a mixed-origin bonus, and the scanner rolls a random origin,
		// so routing through it would quietly pay out more than stored_points.
		existing_notes.attackby(new_notes, user)
	else
		try_put_in_hand(new_notes, user)
	stored_points = 0 //empty it now
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/machinery/survey_scanner/process(seconds_per_tick)
	// Bill the internal cell, not the area - see the type comment.
	if(!cell?.use(active_power_usage * seconds_per_tick, force = TRUE))
		say("Power cell depleted, scanning stopped.")
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 20)
		disable()
		return

	// Power is billed every tick, but scanning is on its own slower clock.
	if(world.time < next_scan)
		return
	next_scan = world.time + SURVEY_SCAN_INTERVAL

	// A site starts at full value and decays as it gets picked over. research_power divides
	// the decay, so a better matter bin keeps a site productive for longer - it does NOT
	// scale the payout. (It used to be applied as a raw multiplier, which stacked with the
	// longer run and made a maxed scanner worth ~9x the entire techweb from one planet.)
	var/scan_key = get_scan_history_key()
	var/penalty = 1 - ((site_scan_history[scan_key] - 1) * SURVEY_SCAN_DECAY / max(research_power, 1))
	if(penalty < SURVEY_MIN_PENALTY) // tapped out, and it stays that way for the round
		say("Unable to locate valuable information in current sector, scanning stopped.")
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 20)
		disable()
		return

	playsound(src, 'sound/machines/ding.ogg', 20)
	site_scan_history[scan_key]++
	stored_points += (research_gain * penalty)

/**
 * The history key for wherever this scanner is standing.
 *
 * A map region (see map_region_for_turf) is the site: the planet or encounter footprint on a
 * packed level, or the turf reservation for a ruin or asteroid field. Ground that belongs to
 * no region - a roundstart level, a ship in deep space - falls back to the z-level, which is
 * exactly what the whole list used to be.
 */
/obj/machinery/survey_scanner/proc/get_scan_history_key()
	var/turf/here = get_turf(src)
	if(!here)
		return "z_[z]"
	var/datum/region = map_region_for_turf(here)
	return region ? "site_[REF(region)]" : "z_[here.z]"

/obj/machinery/survey_scanner/wrench_act(mob/living/user, obj/item/tool)
	if(enabled)
		return FALSE
	tool.play_tool_sound(src, 15)
	set_anchored(!anchored)
	return TRUE

/obj/machinery/survey_scanner/screwdriver_act(mob/living/user, obj/item/tool)
	if(enabled)
		return FALSE
	if(!default_deconstruction_screwdriver(user, "[initial(icon_state)]-o", initial(icon_state), tool))
		return FALSE
	return TRUE

/obj/machinery/survey_scanner/crowbar_act(mob/living/user, obj/item/tool)
	if(!default_deconstruction_crowbar(tool))
		return FALSE
	return TRUE

/**
 * enable()
 *
 * Turns the machine on to start generating points and consuming power.
 */
/obj/machinery/survey_scanner/proc/enable()
	if(!anchored)
		say("Unable to operate, not anchored properly to the floor!")
		return
	if(panel_open)
		say("Unable to operate, maintenance panel is open!")
		return
	if(!cell)
		say("Unable to operate, no power cell installed!")
		return
	if(!cell.charge)
		say("Unable to operate, power cell is depleted!")
		return
	//don't have a history here, create one.
	var/scan_key = get_scan_history_key()
	if(!site_scan_history[scan_key])
		site_scan_history[scan_key] = 1
	next_scan = world.time //first scan lands on the next tick, so it visibly does something
	enabled = TRUE
	balloon_alert_to_viewers("begins to rumble...")
	begin_processing()
	update_appearance(UPDATE_ICON_STATE)
	survey_audio.start()
	// copied from janiborgs lmao
	var/base_x = base_pixel_x
	var/base_y = base_pixel_y
	animate(src, pixel_x = base_x, pixel_y = base_y, time = 1, loop = -1)
	for(var/i in 1 to 15) //Startup rumble
		var/x_offset = base_x + rand(-1, 1)
		var/y_offset = base_y + rand(-1, 1)
		animate(pixel_x = x_offset, pixel_y = y_offset, time = 1)

/**
 * disable()
 *
 * ends the processing and power usage, and spits out the points if there's any.
 */
/obj/machinery/survey_scanner/proc/disable()
	enabled = FALSE
	end_processing()
	update_appearance(UPDATE_ICON_STATE)
	survey_audio?.stop() //deconstruction can route here after Destroy() has already dropped the sound
	animate(src, pixel_x = base_pixel_x, pixel_y = base_pixel_y, time = 2)

/// Don't swallow someone's bluespace cell when they pack the scanner back up.
/obj/machinery/survey_scanner/on_deconstruction(disassembled)
	eject_cell()
	return ..()

/**
 * Design
 */
/datum/design/board/survey_scanner
	name = "Survey Scaner Machine Board"
	desc = "The Machine Circuit board for a Survey scanner which allows research generation through power."
	id = "surveyscanner"
	build_path = /obj/item/circuitboard/machine/survey_scanner
	category = list(
		RND_CATEGORY_COMPUTER + RND_SUBCATEGORY_COMPUTER_RESEARCH,
	)
	departmental_flags = DEPARTMENT_BITFLAG_MEDICAL

/**
 * Board
 */
/obj/item/circuitboard/machine/survey_scanner
	name = "Survey Scanner"
	greyscale_colors = CIRCUIT_COLOR_SCIENCE
	build_path = /obj/machinery/survey_scanner
	req_components = list(
		/obj/item/stock_parts/matter_bin = 1,
		/obj/item/stock_parts/servo = 1,
		/obj/item/stock_parts/micro_laser = 1,
		/obj/item/stack/cable_coil = 5,
	)

#undef SURVEY_SCAN_INTERVAL
#undef SURVEY_SCAN_DECAY
#undef SURVEY_MIN_PENALTY
#undef SURVEY_GAIN_PER_SERVO
