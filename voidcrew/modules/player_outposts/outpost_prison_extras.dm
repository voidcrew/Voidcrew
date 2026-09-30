/**
 * # Prison extras: the seams
 *
 * Owner: X0 (frozen). The prison wing's extras are built in packages, each in its own files:
 * - XA, NPC guards: outpost_prison_guards.dm, outpost_prison_guard_routine.dm;
 * - XB, the yard's feel: outpost_prison_ambience.dm (built turrets and the prison are in
 *   outpost_prison_security.dm);
 * - XC, staff reputation and the talk menu: outpost_prison_social.dm, outpost_prison_warden_tools.dm;
 * - XD, friends, games and birthdays: outpost_prison_life.dm, outpost_prison_pastimes.dm;
 * - XF, contraband and mail: outpost_prison_contraband.dm, outpost_prison_mail.dm;
 * - XG, interrogation and leads: outpost_prison_leads.dm;
 * - wildcard incidents and wing events: outpost_prison_incidents.dm, outpost_prison_wing_events.dm.
 *
 * This file joins them to the prison: one call from each place in the core files, fanning out
 * to every package that needs it, so no package edits another's file or the core files. Each
 * package's procs start as stubs that keep the prison as it was.
 *
 * Extra dialogue files hold prisoner lines under "lines", in the main file's shape. A context is
 * looked up in outpost_prisoners.json first, then in these files in order.
 *
 * Extra placeholders: lines may name {staff} and the other entries of
 * GLOB.outpost_prisoner_extra_placeholders. Such a line is only said when the speaker has a value
 * for it in extra_line_values, which say_context_with() and say_to_staff() set for one line, and
 * which a package's extra speech sets by returning list(context, other, values).
 */

/// Where the extra dialogue files live
#define OUTPOST_PRISONER_EXTRA_DIALOGUE_DIR "voidcrew/modules/player_outposts/strings"

/// Prisoner dialogue files other than outpost_prisoners.json, searched in this order for a context's lines
GLOBAL_LIST_INIT(outpost_prisoner_extra_dialogue, list(
	"outpost_prison_security.json",
	"outpost_prison_social.json",
	"outpost_prison_life.json",
	"outpost_prison_contraband.json",
	"outpost_prison_leads.json",
	"outpost_prison_guards.json",
	"outpost_prison_bounty.json", // outpost_prison_bounty.dm: a bounty prisoner's lines about who caught them
))

/// Placeholders beyond {name}, {other}, {crime} and {time_left}; a line naming one is said only with a value for it
GLOBAL_LIST_INIT(outpost_prisoner_extra_placeholders, list("{staff}", "{place}", "{band}", "{sender}", "{teller}", "{item}"))

/// A top-level entry of an extra dialogue file, or an empty list when the file has none
/proc/outpost_prisoner_extra_dialogue(file, key)
	load_strings_file(file, OUTPOST_PRISONER_EXTRA_DIALOGUE_DIR)
	var/list/cache = GLOB.string_cache?[file]
	var/list/entry = islist(cache) ? cache[key] : null
	return islist(entry) ? entry : list()

/// A context's lines ({"any": [...], "<personality>": [...]}) from the main dialogue file, else the first extras file that has it
/proc/outpost_prisoner_context_lines(context)
	var/list/lines = outpost_prisoner_dialogue("lines")
	if(islist(lines[context]))
		return lines[context]
	for(var/file in GLOB.outpost_prisoner_extra_dialogue)
		var/list/extra = outpost_prisoner_extra_dialogue(file, "lines")
		if(islist(extra[context]))
			return extra[context]
	return null

// ===== THE PRISONER =====

/mob/living/basic/outpost_prisoner
	/// Values for extra placeholders ("{staff}" = "Isaac") while one line is picked and said
	var/list/extra_line_values
	/// The last person or borg (never a machine) whose hit on them counted as staff's
	var/datum/weakref/last_staff_attacker_ref

/// Hooks up every package's own handlers; called once from Initialize()
/mob/living/basic/outpost_prisoner/proc/setup_extras()
	setup_ambience()
	setup_warden_tools()
	setup_pastimes()
	setup_contraband()

/**
 * Says a line for `context` with values for extra placeholders, list("{place}" = "the Meridian").
 * Lines naming a placeholder without a value are skipped. Returns TRUE if they said something.
 */
/mob/living/basic/outpost_prisoner/proc/say_context_with(context, list/values, mob/living/basic/outpost_prisoner/other)
	extra_line_values = values
	. = say_context(context, other)
	extra_line_values = null

/// Says a line for `context` to `person`, filling {staff} with the name the yard knows them by
/mob/living/basic/outpost_prisoner/proc/say_to_staff(context, mob/person)
	var/staff_name = prison?.staff_greeting_name(person)
	return say_context_with(context, staff_name ? list("{staff}" = staff_name) : null)

// ===== THE PRISON: TIME AND LIFE =====

/// Advances every package by `seconds`; the prison's tick() calls it after experiments_tick()
/datum/outpost_prison/proc/extras_tick(seconds)
	guards_tick(seconds)
	ambience_tick(seconds)
	social_tick(seconds)
	life_tick(seconds)
	pastimes_tick(seconds)
	contraband_tick(seconds)
	mail_tick(seconds)
	leads_tick(seconds)
	wildcard_tick(seconds)
	wing_events_tick(seconds)
	// The bounty bosses' riot moves (outpost_prison_boss_moves.dm)
	boss_moves_tick(seconds)

/// The prison is being deleted
/datum/outpost_prison/proc/extras_destroy()
	guards_destroy()
	ambience_destroy()
	social_destroy()
	life_destroy()
	contraband_destroy()
	mail_destroy()
	leads_destroy()
	wildcard_destroy()
	wing_events_destroy()
	boss_moves_destroy()

/// The outpost was abandoned, before its prisoners are transferred out
/datum/outpost_prison/proc/extras_abandon()
	guards_abandon()

/// A prisoner was booked in (admit()), with their cell and mood set
/datum/outpost_prison/proc/extras_prisoner_admitted(mob/living/basic/outpost_prisoner/prisoner)
	on_prisoner_admitted(prisoner)
	contraband_prisoner_admitted(prisoner)
	leads_prisoner_admitted(prisoner)

/// A prisoner is leaving the roster (forget()), still holding their prison and cell
/datum/outpost_prison/proc/extras_prisoner_leaving(mob/living/basic/outpost_prisoner/prisoner)
	on_prisoner_leaving(prisoner)
	contraband_prisoner_leaving(prisoner)
	mail_prisoner_leaving(prisoner)
	leads_prisoner_leaving(prisoner)
	wildcard_prisoner_leaving(prisoner)
	boss_moves_prisoner_leaving(prisoner)

/// Something went on a serving hatch; TRUE if a package took the event and the usual call-out should not follow
/datum/outpost_prison/proc/extras_hatch_stocked(obj/structure/table/reinforced/prison_hatch/hatch, list/stocked, mob/user)
	if(pastime_hatch_stocked(hatch, stocked, user))
		return TRUE
	return mail_hatch_stocked(hatch, stocked, user)

// ===== THE PRISON: SPEECH, EXAMINE AND THE TALK MENU =====

/// Something a package wants a prisoner to say now: list(context, other[, values]), or null
/datum/outpost_prison/proc/extra_speech(mob/living/basic/outpost_prisoner/prisoner)
	// A bounty prisoner who sees someone off the ship that caught them (outpost_prison_bounty.dm): rare and gated
	var/list/choice = bounty_extra_speech(prisoner)
	if(choice)
		return choice
	choice = social_extra_speech(prisoner)
	if(choice)
		return choice
	choice = contraband_extra_speech(prisoner)
	if(choice)
		return choice
	choice = mail_extra_speech(prisoner)
	if(choice)
		return choice
	return leads_extra_speech(prisoner)

/// Extra sentences for a prisoner's examine text, from every package that has one; XB's examine() shows them
/datum/outpost_prison/proc/examine_extra_lines(mob/living/basic/outpost_prisoner/prisoner, mob/user)
	var/list/lines = list()
	for(var/line in list(relationship_examine(prisoner), contraband_examine(prisoner, user), leads_examine(prisoner, user), wildcard_examine(prisoner), bounty_examine(prisoner, user)))
		if(istext(line) && length(line))
			lines += line
	return lines

/// Extra choices for the talk menu (XC's radial): name -> image, from the packages that add one
/datum/outpost_prison/proc/talk_menu_extra_choices(mob/living/basic/outpost_prisoner/prisoner, mob/living/user)
	var/list/choices = list()
	for(var/list/extra as anything in list(contraband_talk_choices(prisoner, user), leads_talk_choices(prisoner, user)))
		for(var/key in extra)
			choices[key] = extra[key]
	return choices

/// Runs an extra talk menu choice; TRUE if a package handled it. May sleep (the menu is async).
/datum/outpost_prison/proc/talk_menu_extra_act(mob/living/basic/outpost_prisoner/prisoner, mob/living/user, choice)
	if(contraband_talk_act(prisoner, user, choice))
		return TRUE
	return leads_talk_act(prisoner, user, choice)

// ===== THE PRISON: TROUBLE =====

/// What the packages do to the chance two prisoners start a fight: a multiplier, 1 for no change
/datum/outpost_prison/proc/extras_fight_mult(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	return fight_chance_mult(one, two) * contraband_fight_mult(one, two)

// ===== THE PRISON: CONSOLES =====

/// The warden console's "extras" block: the guards. Mail is on the office floor and in the log, not the console.
/datum/outpost_prison/proc/extras_payload(mob/user)
	return list(
		"guards" = guards_payload(user),
	)

/// A warden console action a package handles (guards, bounty transfers); TRUE if one did
/datum/outpost_prison/proc/extras_act(action, list/params, mob/user)
	if(guards_act(action, params, user))
		return TRUE
	// Bounty transfers (outpost_prison_bounty.dm)
	return bounty_warden_act(action, params, user)

/// The admin panel's "extras" block
/datum/outpost_prison/proc/extras_admin_payload()
	return list(
		"guards" = guards_admin_payload(),
		"social" = social_admin_payload(),
		"life" = life_admin_payload(),
		"contraband" = contraband_admin_payload(),
		"mail" = mail_admin_payload(),
		"leads" = leads_admin_payload(),
		"bounty" = bounty_admin_payload(),
	)

/// An admin action a package handles: a line for the admin log, or null when no package took it
/datum/outpost_prison/proc/extras_admin_act(action, list/params, mob/user)
	. = guards_admin_act(action, params, user)
	if(.)
		return
	. = social_admin_act(action, params, user)
	if(.)
		return
	. = life_admin_act(action, params, user)
	if(.)
		return
	. = contraband_admin_act(action, params, user)
	if(.)
		return
	. = mail_admin_act(action, params, user)
	if(.)
		return
	. = leads_admin_act(action, params, user)
	if(.)
		return
	return bounty_admin_act(action, params, user)

#undef OUTPOST_PRISONER_EXTRA_DIALOGUE_DIR
