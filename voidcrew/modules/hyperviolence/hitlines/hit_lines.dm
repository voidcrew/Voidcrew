// Hyperviolence hit lines: one hit, one chat line.
//
// tg prints the attack ("X slashes Y in the arm!") and then every wound or dismember message as
// its own line. This module holds the attack line for a moment, collects the bold lines queued by
// hv_add_hit_line() while the hit resolves, and sends them as one message:
//   "X slashes Y in the neck! **An artery is torn!** ***The arm is severed!***"
// A line queued with no attack line waiting (a wound from an explosion, a fall) goes out as its
// own message on the next tick, merged with anything else queued on the same mob that tick.
//
// The idea comes from Septic Shock's COMSIG_CARBON_ADD_TO_WOUND_MESSAGE (wound text appended to the
// attack message). This is a fresh implementation, not a port.
//
// The held attack line is sent by the outermost wrapper of each attack path (attacked_by,
// bullet_act, hitby, attack_animal and the unarmed harm), so there is no hook to add in the
// upstream procs besides swapping their output for hv_hold_attack_message().

/// Longest queue of lines on one hit (twice that for the worst lines). Anything more is dropped so one blast cannot flood chat.
#define HV_MAX_HIT_LINES 6

// Indexes into one queued line, see hv_add_hit_line()
#define HV_LINE_TEXT 1
#define HV_LINE_SELF 2
#define HV_LINE_SEVERITY 3
#define HV_LINE_RANGE 4

/// The hit being resolved on one mob: the attack line held back and the lines queued behind it.
/datum/hv_hit
	/// The attack line as onlookers read it. Null when no attack line is held (lines only).
	var/others_text
	/// The attack line as the victim reads it.
	var/victim_text
	/// The attack line as the attacker reads it. Null when the attacker is not told separately.
	var/attacker_text
	/// What onlookers who cannot see the hit are told.
	var/blind_text
	/// Who dealt the hit. Cleared when the hit is sent.
	var/mob/attacker
	/// How far the attack line carries.
	var/vision_range = COMBAT_MESSAGE_RANGE
	/// Queued lines, each list(text, self_text, severity, range)
	var/list/lines = list()

	// What compose() works out
	/// How far the first message carries
	var/near_range
	/// What onlookers within near_range read
	var/others_message
	/// What the victim reads
	var/victim_message
	/// What the attacker reads, when told separately
	var/attacker_message
	/// Lines that carry beyond near_range, for the viewers further out. Null if none do.
	var/far_message
	/// How far far_message carries
	var/far_range

/// Works out what each reader gets: the held attack line, if any, with the queued lines after it.
/// With no attack line held, the lines are the message and the nearest one sets how far it carries.
/// Returns FALSE when there is nothing to say.
/datum/hv_hit/proc/compose()
	near_range = vision_range
	if(!others_text)
		near_range = INFINITY
		for(var/list/line as anything in lines)
			near_range = min(near_range, line[HV_LINE_RANGE])
		if(near_range == INFINITY)
			return FALSE

	var/others_lines = ""
	var/victim_lines = ""
	var/far_lines = ""
	far_range = near_range
	for(var/list/line as anything in lines)
		var/severity = line[HV_LINE_SEVERITY]
		var/others_line = " [hv_format_hit_line(line[HV_LINE_TEXT], severity)]"
		others_lines += others_line
		victim_lines += " [hv_format_hit_line(line[HV_LINE_SELF], severity)]"
		if(line[HV_LINE_RANGE] > near_range)
			far_lines += others_line
			far_range = max(far_range, line[HV_LINE_RANGE])

	if(others_text)
		others_message = span_danger("[others_text][others_lines]")
		victim_message = span_userdanger("[victim_text][victim_lines]")
		if(attacker_text)
			attacker_message = span_danger("[attacker_text][others_lines]")
	else
		others_message = span_danger(copytext(others_lines, 2))
		victim_message = span_userdanger(copytext(victim_lines, 2))
	if(far_lines)
		far_message = span_danger(copytext(far_lines, 2))
	return TRUE

/mob/living
	/// The hit being resolved on this mob (voidcrew/modules/hyperviolence/hitlines). Null between hits.
	var/datum/hv_hit/hv_hit

/// Gets the hit being resolved on this mob, starting one if none is. A hit nobody sends is sent on the next tick.
/mob/living/proc/hv_get_hit()
	if(!hv_hit)
		hv_hit = new
		addtimer(CALLBACK(src, PROC_REF(hv_send_stale_hit), hv_hit), 0)
	return hv_hit

/// Sends a hit that nothing sent in the tick it began. A hit sent already (or replaced) is left alone.
/mob/living/proc/hv_send_stale_hit(datum/hv_hit/stale)
	if(hv_hit == stale)
		hv_flush_hit()

/**
 * Adds a line to the combat message of the hit being resolved on src.
 *
 * Arguments:
 * * text - what bystanders and the attacker read, "The bone in Y's arm snaps!"
 * * severity - HV_LINE_BOLD, or HV_LINE_HUGE for a severed limb or a burst head
 * * self_text - what src reads in place of text, "Your arm snaps!". Null reads text
 * * range - how far the line carries. A line that carries further than the attack line is also
 *   sent on its own to the extra viewers, so tg's message ranges hold
 */
/mob/living/proc/hv_add_hit_line(text, severity = HV_LINE_BOLD, self_text, range = COMBAT_MESSAGE_RANGE)
	if(!text || QDELETED(src))
		return
	var/datum/hv_hit/hit = hv_get_hit()
	if(length(hit.lines) >= (severity >= HV_LINE_HUGE ? HV_MAX_HIT_LINES * 2 : HV_MAX_HIT_LINES))
		return
	hit.lines += list(list(text, self_text || text, severity, range))

/**
 * Holds an attack line so the wound lines queued behind it join it. The attack path's wrapper sends it
 * with hv_flush_hit() once the damage is done. Texts are plain; the danger styling is added when sent.
 *
 * Arguments:
 * * others_text - the line for onlookers
 * * victim_text - the line src reads
 * * attacker_text - the line the attacker reads. Null if the attacker gets none
 * * attacker - who dealt the hit. Skipped when the onlookers are told
 * * blind_text - what onlookers who cannot see are told
 * * vision_range - how far the line carries
 */
/mob/living/proc/hv_hold_attack_message(others_text, victim_text, attacker_text, mob/attacker, blind_text, vision_range = COMBAT_MESSAGE_RANGE)
	if(hv_hit)
		// A new hit begins: whatever was still waiting is a different event
		hv_flush_hit()
	var/datum/hv_hit/hit
	if(QDELETED(src))
		// Nothing will send a hit held on a deleted mob, so the line goes out as it is
		hit = new
	else
		hit = hv_get_hit()
	hit.others_text = others_text
	hit.victim_text = victim_text
	hit.attacker_text = attacker_text
	hit.blind_text = blind_text
	hit.attacker = attacker
	hit.vision_range = vision_range
	if(QDELETED(src))
		hv_send_hit(hit)

/// One line as chat markup: bold, or bold italic for the worst of it. It sits inside the danger span of the message.
/proc/hv_format_hit_line(text, severity)
	if(severity >= HV_LINE_HUGE)
		return "<b><i>[text]</i></b>"
	return "<b>[text]</b>"

/// Sends the held attack line and the lines queued behind it, then ends the hit. Safe to call with no hit.
/mob/living/proc/hv_flush_hit()
	var/datum/hv_hit/hit = hv_hit
	if(!hit)
		return
	hv_hit = null
	hv_send_hit(hit)

/// Says a hit to everyone who should read it.
/mob/living/proc/hv_send_hit(datum/hv_hit/hit)
	var/mob/attacker = hit.attacker
	hit.attacker = null
	if(QDELETED(attacker))
		attacker = null
	if(!hit.compose())
		return

	visible_message(
		hit.others_message,
		hit.victim_message,
		hit.blind_text ? span_hear(hit.blind_text) : null,
		hit.near_range,
		attacker,
	)
	if(attacker && hit.attacker_message)
		to_chat(attacker, hit.attacker_message)

	// A line that carries further than the message above also reaches the viewers beyond it, once.
	if(hit.far_message)
		var/list/already_told = get_hearers_in_view(hit.near_range, src)
		already_told += src
		if(attacker && hit.attacker_message)
			already_told += attacker
		visible_message(hit.far_message, vision_distance = hit.far_range, ignored_mobs = already_told)

/// A mob about to be deleted still says what was done to it.
/mob/living/Destroy()
	hv_flush_hit()
	return ..()

/// What follows a blow (a knockdown, a spray) reads after the hit, and so does a death.
/mob/living/attack_effects(damage_done, hit_zone, armor_block, obj/item/attacking_item, mob/living/attacker)
	hv_flush_hit()
	return ..()

/mob/living/death(gibbed)
	hv_flush_hit()
	return ..()

// Each attack path ends in a wrapper that sends the held line. A voidcrew definition of a proc runs
// outside the upstream one, so these run after the whole hit is resolved.

/mob/living/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	. = ..()
	hv_flush_hit()

/mob/living/bullet_act(obj/projectile/proj, def_zone, piercing_hit = FALSE, blocked = 0)
	. = ..()
	hv_flush_hit()

/mob/living/hitby(atom/movable/AM, skipcatch, hitpush = TRUE, blocked = FALSE, datum/thrownthing/throwingdatum)
	. = ..()
	hv_flush_hit()

/mob/living/attack_animal(mob/living/simple_animal/user, list/modifiers)
	. = ..()
	hv_flush_hit()

/datum/species/harm(mob/living/carbon/human/user, mob/living/carbon/human/target, datum/martial_art/attacker_style)
	. = ..()
	target?.hv_flush_hit()

#undef HV_LINE_RANGE
#undef HV_LINE_SEVERITY
#undef HV_LINE_SELF
#undef HV_LINE_TEXT
