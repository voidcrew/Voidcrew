/**
 * # Chrome read
 *
 * Every set of cyberware optics carries the same diagnostic bus the Chrome
 * Cradle uses to enumerate a body before it cuts. Pointed at someone else
 * that bus is an intel tool: what hardware they are running, what tier it is,
 * what has gone offline, and how close their nervous system is to its
 * ceiling. Pointed at yourself it is the load readout you would otherwise
 * walk back to the parlor for.
 *
 * It reads ALL robotic organs, not just ours, a printable reviver or a
 * prosthetic heart comes back UNRATED, with no tier and no load, because the
 * bus only knows what answers it. Telling parlor chrome apart from fab-printed
 * augments at a glance is most of the point.
 *
 * The rules are the counterplay the module already promised elsewhere:
 * - ORGAN_HIDDEN chrome never resolves. The Cargo Cavity's desc says
 *   "nothing on a scanner", and this is the scanner that has to honor it.
 * - Ghostskin camo (TRAIT_CYBER_CAMO) scatters the read outright.
 * - A subject carrying resolvable hardware always FEELS the read, and names
 *   the reader whenever they can see them. No silent intel on a PvP server.
 * - Resolution belongs to the optics, not to the reader: the street-tier
 *   Nightshade counts signatures, everything above it names them.
 *
 * The action rides the shared /datum/action/cooldown/cyberware bridge, so a
 * browned-out or EMP-scrambled set of eyes reads nothing at all.
 */

/// How far the bus reaches, in tiles, with line of sight required.
#define CYBERWARE_SCAN_RANGE 7
#define CYBERWARE_SCAN_COOLDOWN (12 SECONDS)
/// Readout colour for hardware the bus can see but can't rate, anything
/// robotic that isn't parlor chrome.
#define CYBERWARE_SCAN_UNRATED_COLOR "#8fa1a8"

// ---- Readout -----------------------------------------------------------

/**
 * The hardware on a target a read can actually resolve: our chrome plus every
 * other robotic organ in there, minus anything flagged ORGAN_HIDDEN. Chrome is
 * matched on its component as well as the flag so a ware that ever drops
 * ORGAN_ROBOTIC still reads.
 */
/proc/cyberware_scannable_hardware(mob/living/carbon/target)
	RETURN_TYPE(/list)
	. = list()
	if(!iscarbon(target))
		return
	// Typed, not `as anything`: a hard-deleted organ leaves a null in place
	// inside `organs`, and the istype filter is what drops it.
	for(var/obj/item/organ/organ in target.organs)
		if(organ.organ_flags & ORGAN_HIDDEN)
			continue
		if(!(organ.organ_flags & ORGAN_ROBOTIC) && !organ.GetComponent(/datum/component/cyberware))
			continue
		. += organ

/**
 * One monospace readout line in the given accent, the BIOS boot splash's
 * visual language (cyberware_base.dm). Returned rather than sent so a whole
 * report lands as a single chat message instead of five.
 */
/proc/cyberware_scan_line(text, accent)
	return "<span style='color: [accent]; font-weight: bold; font-family: \"Courier New\", monospace;'>[text]</span>"

/**
 * Builds the report for a body at the given resolution and hands back the
 * styled lines. Split out from the action so the Cradle, an admin tool or a
 * unit test can ask the same question without a pair of eyes involved.
 */
/proc/cyberware_scan_readout(mob/living/carbon/target, resolution = CYBERWARE_SCAN_ITEMIZED)
	RETURN_TYPE(/list)
	. = list()
	if(!iscarbon(target))
		return
	var/accent = CYBERWARE_COLOR_TIER_2
	// Masks and helmets beat the bus: a body reads as whatever it looks like.
	var/subject = target.name
	if(ishuman(target))
		var/mob/living/carbon/human/human_target = target
		subject = human_target.get_visible_name()
	. += cyberware_scan_line("CHROME READ: [uppertext(subject)]", accent)

	var/list/found = cyberware_scannable_hardware(target)
	if(!length(found))
		. += cyberware_scan_line("NO HARDWARE SIGNATURE", accent)
		return

	var/load = get_chrome_load(target)
	var/capacity = get_chrome_capacity(target)
	. += cyberware_scan_line("SIGNATURES [length(found)] · NEURAL LOAD [load]/[capacity]", accent)
	if(resolution < CYBERWARE_SCAN_ITEMIZED)
		. += cyberware_scan_line("BUS RESOLUTION TOO LOW: IDENTITIES UNRESOLVED", accent)
	else
		for(var/obj/item/organ/ware as anything in found)
			var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
			var/status = (ware.organ_flags & ORGAN_FAILING) ? " · OFFLINE" : ""
			// Anything that isn't parlor chrome has no tier to report.
			var/rating = chrome ? "T[chrome.tier]" : "UNRATED"
			var/line_color = chrome ? cyberware_tier_color(chrome.tier) : CYBERWARE_SCAN_UNRATED_COLOR
			. += cyberware_scan_line("» [uppertext(ware.name)] · [rating][status]", line_color)
	if(load > capacity)
		. += cyberware_scan_line("LOAD OVER CEILING: SUBJECT BROWNED OUT", CYBERWARE_COLOR_TIER_3)

// ---- The ability -------------------------------------------------------

/datum/action/cooldown/cyberware/chrome_read
	name = "Chrome Read"
	desc = "Read a body's hardware bus: what's installed, what tier it is, and how loaded their nervous system is. They'll feel you do it."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "scan"
	ranged_mousepointer = 'icons/effects/mouse_pointers/scan_target.dmi'
	cooldown_time = CYBERWARE_SCAN_COOLDOWN
	click_to_activate = TRUE

/datum/action/cooldown/cyberware/chrome_read/Activate(atom/target)
	var/obj/item/organ/eyes/robotic/cyberware/optics = organ
	var/mob/living/carbon/bearer = organ?.owner
	if(!istype(optics) || !iscarbon(bearer))
		return FALSE
	if(!iscarbon(target))
		bearer.balloon_alert(bearer, "no chrome bus!")
		return FALSE
	var/mob/living/carbon/subject = target
	var/self_read = (subject == bearer)
	// Flashed, hooded or otherwise blind: the bus is behind the eyes, and the
	// eyes are what's down.
	if(bearer.is_blind())
		bearer.balloon_alert(bearer, "optics dark!")
		return FALSE
	if(!self_read && !can_see(bearer, subject, CYBERWARE_SCAN_RANGE))
		bearer.balloon_alert(bearer, "no line of sight!")
		return FALSE
	// Ghostskin scatters the handshake the same way it scatters NPC targeting.
	if(HAS_TRAIT(subject, TRAIT_CYBER_CAMO))
		bearer.balloon_alert(bearer, "signature scatter!")
		to_chat(bearer, cyberware_scan_line("CHROME READ: SIGNAL SCATTER, NO LOCK", CYBERWARE_COLOR_TIER_3))
		playsound(bearer, 'sound/machines/terminal/terminal_error.ogg', 20, TRUE)
		StartCooldown()
		return TRUE

	var/list/report = cyberware_scan_readout(subject, optics.chrome_scan_resolution)
	to_chat(bearer, jointext(report, "<br>"))
	playsound(bearer, 'sound/machines/terminal/terminal_processing.ogg', 20, TRUE)
	if(!self_read)
		// The tell: anyone close enough sees the readout scroll across the eyes.
		// The subject only sits that message out when they're getting the
		// louder one below instead.
		var/subject_feels_it = length(cyberware_scannable_hardware(subject))
		bearer.visible_message(
			span_notice("[bearer]'s irises flicker with a scrolling readout."),
			vision_distance = 3,
			ignored_mobs = subject_feels_it ? list(subject) : null,
		)
		// The subject's own hardware reports the unauthorized handshake.
		if(subject_feels_it)
			if(can_see(subject, bearer, CYBERWARE_SCAN_RANGE))
				to_chat(subject, span_warning("[bearer] is reading your hardware. Every piece you have just answered a handshake you never authorized."))
			else
				to_chat(subject, span_warning("Your hardware answers a handshake you never authorized. Someone nearby is reading you."))
	StartCooldown()
	return TRUE

#undef CYBERWARE_SCAN_RANGE
#undef CYBERWARE_SCAN_COOLDOWN
#undef CYBERWARE_SCAN_UNRATED_COLOR
