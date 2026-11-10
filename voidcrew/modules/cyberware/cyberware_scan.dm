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
 * The reader sees the result drawn over the subject, for their eyes only
 * (cyberware_scan_overlay.dm). Nothing goes to their chat. Bystanders see the
 * reader's eyes flicker; the subject sees their own body flinch red and gets
 * the chat line naming the reader.
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

// Reach and pacing belong to the optics, so a scout model can read further or
// faster. The defaults are the read's stock numbers.
/obj/item/organ/eyes/robotic/cyberware
	/// How far this set of eyes can read a body, in tiles, with line of sight.
	var/chrome_read_range = CYBERWARE_SCAN_RANGE
	/// Cooldown on this set of eyes' chrome read.
	var/chrome_read_cooldown = CYBERWARE_SCAN_COOLDOWN

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
 * The short name a readout shows for one piece of hardware: no \improper,
 * and no "(left)" or "(right)" on paired arm chrome.
 */
/proc/cyberware_scan_label(obj/item/organ/ware)
	var/static/regex/side_suffix = regex(@"\s*\((left|right)\)$", "i")
	return side_suffix.Replace(format_text(ware.name), "")

/**
 * What a read resolves on a body, as data. The overlay
 * (cyberware_scan_overlay.dm) draws it and cyberware_scan_readout() prints it,
 * so both agree on what the bus can and can't see.
 *
 * Returns an associative list: `name` (the visible name), `count`, `load`,
 * `capacity`, `resolution` and `entries`, one list per signature in organ
 * order. At itemized resolution an entry carries `label`, `name`, `icon`,
 * `icon_state`, `color`, `tier` (0 when unrated), `rated` and `offline`. At
 * silhouette resolution entries are empty: the bus counts them and nothing
 * else.
 */
/proc/cyberware_scan_report(mob/living/carbon/target, resolution = CYBERWARE_SCAN_ITEMIZED)
	RETURN_TYPE(/list)
	if(!iscarbon(target))
		return null
	// Masks and helmets beat the bus: a body reads as whatever it looks like.
	var/subject = target.name
	if(ishuman(target))
		var/mob/living/carbon/human/human_target = target
		subject = human_target.get_visible_name()

	var/list/found = cyberware_scannable_hardware(target)
	var/list/entries = list()
	for(var/obj/item/organ/ware as anything in found)
		if(resolution < CYBERWARE_SCAN_ITEMIZED)
			entries += list(list())
			continue
		var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
		entries += list(list(
			"label" = cyberware_scan_label(ware),
			"name" = ware.name,
			"icon" = ware.icon,
			"icon_state" = ware.icon_state,
			// Anything that isn't parlor chrome has no tier to report.
			"color" = chrome ? cyberware_tier_color(chrome.tier) : CYBERWARE_SCAN_UNRATED_COLOR,
			"tier" = chrome ? chrome.tier : 0,
			"rated" = !!chrome,
			"offline" = !!(ware.organ_flags & ORGAN_FAILING),
		))
	return list(
		"name" = subject,
		"count" = length(found),
		"load" = get_chrome_load(target),
		"capacity" = get_chrome_capacity(target),
		"resolution" = resolution,
		"entries" = entries,
	)

/**
 * Builds the report for a body at the given resolution and hands back the
 * styled lines. Split out from the action so the Cradle, an admin tool or a
 * unit test can ask the same question without a pair of eyes involved.
 */
/proc/cyberware_scan_readout(mob/living/carbon/target, resolution = CYBERWARE_SCAN_ITEMIZED)
	RETURN_TYPE(/list)
	. = list()
	var/list/report = cyberware_scan_report(target, resolution)
	if(!report)
		return
	var/accent = CYBERWARE_COLOR_TIER_2
	. += cyberware_scan_line("CHROME READ: [uppertext(report["name"])]", accent)

	if(!report["count"])
		. += cyberware_scan_line("NO HARDWARE SIGNATURE", accent)
		return

	var/load = report["load"]
	var/capacity = report["capacity"]
	. += cyberware_scan_line("SIGNATURES [report["count"]] · NEURAL LOAD [load]/[capacity]", accent)
	if(resolution < CYBERWARE_SCAN_ITEMIZED)
		. += cyberware_scan_line("BUS RESOLUTION TOO LOW: IDENTITIES UNRESOLVED", accent)
	else
		for(var/list/entry as anything in report["entries"])
			var/status = entry["offline"] ? " · OFFLINE" : ""
			var/rating = entry["rated"] ? (list("STREET", "PRO", "MILITARY", "LEGEND")[clamp(entry["tier"], 1, 4)]) : "UNRATED"
			. += cyberware_scan_line("» [uppertext(entry["name"])] · [rating][status]", entry["color"])
	if(load > capacity)
		. += cyberware_scan_line("LOAD OVER CEILING: SUBJECT BROWNED OUT", CYBERWARE_COLOR_TIER_3)

// ---- The ability -------------------------------------------------------

/datum/action/cooldown/cyberware/chrome_read
	name = "Chrome Read"
	desc = "Read the chrome in a body you can see. They'll feel you do it."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "scan"
	ranged_mousepointer = 'icons/effects/mouse_pointers/scan_target.dmi'
	cooldown_time = CYBERWARE_SCAN_COOLDOWN
	click_to_activate = TRUE
	/// The readout this read is drawing for our bearer. A new read replaces it.
	var/datum/chrome_readout/current_readout

/datum/action/cooldown/cyberware/chrome_read/New(Target, original = TRUE)
	. = ..()
	var/obj/item/organ/eyes/robotic/cyberware/optics = organ
	if(istype(optics))
		cooldown_time = optics.chrome_read_cooldown

/datum/action/cooldown/cyberware/chrome_read/Destroy()
	QDEL_NULL(current_readout)
	return ..()

/// Swaps whatever we were showing for a fresh readout. A null report draws
/// the scatter.
/datum/action/cooldown/cyberware/chrome_read/proc/show_readout(mob/living/carbon/bearer, mob/living/carbon/subject, list/report)
	QDEL_NULL(current_readout)
	var/datum/chrome_readout/readout = new(bearer, subject, report, organ)
	if(QDELETED(readout))
		return
	current_readout = readout
	RegisterSignal(readout, COMSIG_QDELETING, PROC_REF(on_readout_deleted))

/// Signal proc for [COMSIG_QDELETING] on our readout: it ended on its own
/// (expired, target gone, bearer logged out), so stop holding it.
/datum/action/cooldown/cyberware/chrome_read/proc/on_readout_deleted(datum/source)
	SIGNAL_HANDLER
	if(source == current_readout)
		current_readout = null

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
	if(!self_read && !can_see(bearer, subject, optics.chrome_read_range))
		bearer.balloon_alert(bearer, "no line of sight!")
		return FALSE
	// Ghostskin scatters the handshake the same way it scatters NPC targeting:
	// the readout breaks up and drops without a lock.
	if(HAS_TRAIT(subject, TRAIT_CYBER_CAMO))
		show_readout(bearer, subject, null)
		if(!self_read)
			chrome_read_eye_glint(bearer)
		playsound(bearer, 'sound/machines/terminal/terminal_error.ogg', 20, TRUE)
		StartCooldown()
		return TRUE

	// The read draws over the subject for the reader alone; nothing goes to chat.
	var/list/report = cyberware_scan_report(subject, optics.chrome_scan_resolution)
	show_readout(bearer, subject, report)
	playsound(bearer, 'sound/machines/terminal/terminal_processing.ogg', 20, TRUE)
	if(!self_read)
		// The tell: anyone close enough sees the readout scroll across the eyes.
		// The subject only sits that message out when they're getting the
		// louder one below instead. The reader never gets it: it's their eyes.
		chrome_read_eye_glint(bearer)
		var/subject_feels_it = report["count"]
		bearer.visible_message(
			span_notice("[bearer]'s irises flicker with a scrolling readout."),
			vision_distance = 3,
			ignored_mobs = subject_feels_it ? list(subject, bearer) : list(bearer),
		)
		// The subject's own hardware reports the unauthorized handshake: it
		// flinches on their screen, and their chat names the reader.
		if(subject_feels_it)
			chrome_read_flinch(subject)
			if(can_see(subject, bearer, optics.chrome_read_range))
				to_chat(subject, span_warning("[bearer] is reading your hardware. Every piece you have just answered a handshake you never authorized."))
			else
				to_chat(subject, span_warning("Your hardware answers a handshake you never authorized. Someone nearby is reading you."))
	StartCooldown()
	return TRUE

#undef CYBERWARE_SCAN_RANGE
#undef CYBERWARE_SCAN_COOLDOWN
#undef CYBERWARE_SCAN_UNRATED_COLOR
