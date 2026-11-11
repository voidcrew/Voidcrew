/**
 * # Stealth guards: skill by zone (owner decision 38)
 *
 * How sharp a guard's eyes and ears are. One profile per skill level; yellow is the tuning the den was built
 * and playtested on, so a yellow guard behaves exactly as before. The numbers are argued in
 * data/stealth/STATUS.md, "Decisions 37-38".
 *
 * Skill is perception only. It never touches damage, health, armour, aim or fire rate: a red guard sees and
 * hears better, it doesn't shoot better or take more killing. Armour and weapons stay the zone's job.
 *
 * Which profile a guard gets, first that applies:
 * 1. an admin's pick (Stealth Guards > the guard > Set skill), which lasts until changed;
 * 2. the mapper's `stealth_skill` on the guard, or on the spawner that made it;
 * 3. the overmap zone of the planet or ruin it stands on when it first scans;
 * 4. yellow, when that place can't be tied to a zone.
 */
/datum/stealth_skill
	/// For admins
	var/name = "yellow"
	/// Tiles it notices someone at in its cone, in the light
	var/sight_range = 8
	/// Tiles within which a sighting can turn into an alert (decision 18 holds it at 7 or under: on screen)
	var/alert_max_range = 7
	/// Tiles it notices someone at in its cone, in the dark
	var/dark_sight_range = 4
	/// Cone half-angle, calm
	var/cone_half_angle = 60
	/// Cone half-angle while wary
	var/wary_half_angle = 75
	/// Cone half-angle while searching (90 at most: the cone never takes in what is behind it)
	var/search_half_angle = 90
	/// Notice gained per second on someone in plain view at its feet (less further off)
	var/notice_rate = 1.0
	/// In its cone, seen plainly, this close: an alert on that look (decision 32)
	var/point_blank_range = 2
	/// In its cone this close: notice fills near_mult times faster (decision 32)
	var/near_range = 4
	var/near_mult = 3
	/// All round, in light that is there anyway, this close: noticed (abuse P7). Never in the dark (decision 32).
	var/close_range = 2
	/// Multiplies how far it hears quiet noises (steps, doors, glass, knocks, voices). Gunfire, blasts, screams
	/// and shouts are heard as before: they already carry as far as a player hears them (abuse H2).
	var/hearing_mult = 1
	/// How long a suspicious guard stares before it walks over to look
	var/reaction_delay = 2 SECONDS
	/// How long it searches before it gives up
	var/search_time = 40 SECONDS
	/// How long it stays wary with nothing new
	var/wary_time = 60 SECONDS
	/// After it turns where it stands, how long before anything is plain to it at a glance (decision 39)
	var/turn_grace = 1 SECONDS

/datum/stealth_skill/yellow

/// Sloppy: a narrower cone, slower to notice, shorter sight and hearing, quicker to give up.
/datum/stealth_skill/green
	name = "green"
	sight_range = 7
	alert_max_range = 6
	dark_sight_range = 3
	cone_half_angle = 45
	wary_half_angle = 60
	search_half_angle = 75
	notice_rate = 0.7
	point_blank_range = 1
	near_range = 3
	near_mult = 2
	close_range = 1
	hearing_mult = 0.75
	reaction_delay = 3 SECONDS
	search_time = 25 SECONDS
	wary_time = 40 SECONDS
	turn_grace = 1.2 SECONDS

/// Sharp: sees further and wider, notices faster, hears more, searches longer. Still blind behind in the dark.
/datum/stealth_skill/red
	name = "red"
	sight_range = 9
	alert_max_range = 7
	dark_sight_range = 5
	cone_half_angle = 65
	wary_half_angle = 80
	search_half_angle = 90
	notice_rate = 1.3
	point_blank_range = 2
	near_range = 5
	near_mult = 3
	close_range = 2
	hearing_mult = 1.25
	reaction_delay = 1 SECONDS
	search_time = 60 SECONDS
	wary_time = 90 SECONDS
	turn_grace = 0.8 SECONDS

/// The shared profile of type `skill_type`, or null if it isn't one.
/proc/stealth_skill_of(skill_type)
	var/static/list/profiles = list()
	if(!ispath(skill_type, /datum/stealth_skill))
		return null
	var/datum/stealth_skill/profile = profiles[skill_type]
	if(isnull(profile))
		profile = new skill_type()
		profiles[skill_type] = profile
	return profile

/// The profile type for a ZONE_* (yellow when the zone is unknown).
/proc/stealth_skill_type_for_zone(zone)
	switch(zone)
		if(ZONE_GREEN)
			return /datum/stealth_skill/green
		if(ZONE_RED)
			return /datum/stealth_skill/red
	return /datum/stealth_skill/yellow

/// The ZONE_* of the planet or ruin `where` belongs to, or null when it can't be tied to the overmap.
/proc/stealth_zone_of(turf/where)
	if(isnull(where))
		return null
	return get_zone_type_for_player_turf(where)

/mob/living/carbon/human/npc
	/// Mapper's override of a stealth guard's skill: a /datum/stealth_skill subtype, or null for its zone's
	var/stealth_skill

/obj/effect/spawner/human_npc
	/// Mapper's override of the skill of the stealth guard this makes: a /datum/stealth_skill subtype, or null
	var/stealth_skill

/obj/effect/spawner/human_npc/npc_spawned_callback()
	if(ispath(stealth_skill, /datum/stealth_skill))
		return CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(stealth_set_mapped_skill), stealth_skill)
	return ..()

/// A spawner's skill override, handed to the guard it made. A global proc so the order holds no ref to the spawner.
/proc/stealth_set_mapped_skill(skill_type, mob/living/carbon/human/npc/made)
	if(!istype(made))
		return
	made.stealth_skill = skill_type
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = made.ai_controller
	if(istype(stealth_ai) && !stealth_ai.skill_forced)
		stealth_ai.skill = null

/datum/ai_controller/basic_controller/human_npc/stealth
	/// Its skill profile (stealth_skill()); null until first asked for
	var/datum/stealth_skill/skill
	/// Set when an admin picked its skill: the mapper's and the zone's no longer apply
	var/skill_forced = FALSE

/// Its skill profile: an admin's pick, else the mapper's, else its zone's, else yellow. Settled the first time it is asked.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_skill()
	if(skill)
		return skill
	var/mob/living/carbon/human/npc/guard = pawn
	var/skill_type = istype(guard) ? guard.stealth_skill : null
	if(!ispath(skill_type, /datum/stealth_skill))
		skill_type = stealth_skill_type_for_zone(istype(guard) ? stealth_zone_of(get_turf(guard)) : null)
	skill = stealth_skill_of(skill_type)
	return skill

/// Admins: sets its skill to `skill_type`, or back to the mapper's or zone's with null.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_force_skill(skill_type)
	skill_forced = ispath(skill_type, /datum/stealth_skill)
	skill = skill_forced ? stealth_skill_of(skill_type) : null
	stealth_skill()
	for(var/datum/stealth_sight_overlay/overlay as anything in watchers)
		overlay.refresh()
