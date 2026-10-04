/**
 * # World population: admin tools
 *
 * Owner: P0 seams (frozen).
 *
 * - Ambient NPCs: Spawn - any ambient NPC type, outpost role or site kind at your feet. At a trader
 *   outpost the NPC joins that outpost's crowd; a site kind builds its site around you.
 * - Ambient NPCs: List Sites - every outpost crowd, planet site and field site, with what is out.
 */

ADMIN_VERB(ambient_npc_spawn, R_ADMIN|R_DEBUG, "Ambient NPCs: Spawn", "Spawn an ambient NPC, outpost role or planet site kind at your feet.", ADMIN_CATEGORY_DEBUG)
	var/turf/here = get_turf(user.mob)
	if(!here)
		to_chat(user, span_warning("You need a physical location to spawn at."))
		return
	var/list/choices = list()
	for(var/npc_type in subtypesof(/mob/living/basic/ambient_npc) + /mob/living/basic/ambient_npc)
		choices["NPC: [replacetext("[npc_type]", "/mob/living/basic/ambient_npc", "ambient_npc")]"] = npc_type
	for(var/datum/ambient_outpost_role/role as anything in SSambient_npcs.get_outpost_roles())
		if(role.npc_type)
			choices["Role: [role.name] ([role.type])"] = role
	for(var/datum/ambient_site_kind/kind as anything in SSambient_npcs.get_site_kinds())
		choices["Site: [kind.name] ([kind.type])"] = kind
	var/choice = tgui_input_list(user, "What?", "Ambient NPCs: Spawn", sort_list(choices))
	if(!choice)
		return
	var/picked = choices[choice]
	var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(here)
	var/datum/ambient_place/outpost/outpost_place = outpost ? SSambient_npcs.outpost_place(outpost) : null
	var/result
	if(ispath(picked, /mob/living/basic/ambient_npc))
		var/mob/living/basic/ambient_npc/npc = new picked(here)
		npc.set_place(outpost_place)
		result = npc
	else if(istype(picked, /datum/ambient_outpost_role))
		var/datum/ambient_outpost_role/role = picked
		if(!outpost_place)
			to_chat(user, span_warning("Outpost roles arrive at trader outposts. Stand on a concourse."))
			return
		result = role.arrive(outpost_place, here)
	else if(istype(picked, /datum/ambient_site_kind))
		var/datum/ambient_site_kind/kind = picked
		var/datum/ambient_place/site/site = new(kind, here, null)
		site.band = SSovermap.get_zone_band_for_turf(here) || ZONE_GREEN
		site.npc_total = clamp(kind.npc_count(site.band), 1, AMBIENT_PLANET_NPCS_MAX)
		SSambient_npcs.admin_sites += site
		if(!kind.realize(site))
			to_chat(user, span_warning("[kind.name] built nothing here."))
		result = site
	if(!result)
		to_chat(user, span_warning("Nothing was spawned."))
		return
	to_chat(user, span_notice("Spawned [choice]."))
	if(outpost_place && !outpost_place.occupied && !istype(picked, /datum/ambient_site_kind))
		to_chat(user, span_notice("No living player is on this concourse: it holds still until one is."))
	message_admins("[key_name_admin(user)] spawned [choice] at [ADMIN_VERBOSEJMP(here)].")
	log_admin("[key_name(user)] spawned [choice] at [AREACOORD(here)].")
	BLACKBOX_LOG_ADMIN_VERB("Spawn Ambient NPC")

ADMIN_VERB(ambient_npc_list_sites, R_ADMIN|R_DEBUG, "Ambient NPCs: List Sites", "List every trader outpost crowd, planet site and field site, with what is out.", ADMIN_CATEGORY_DEBUG)
	var/list/lines = list("<b>Ambient NPCs</b>: [length(GLOB.ambient_npcs)] in the world")
	lines += "<b>Trader outposts</b>"
	for(var/outpost in SSambient_npcs.outposts)
		var/datum/ambient_place/outpost/place = SSambient_npcs.outposts[outpost]
		lines += "&nbsp;&nbsp;[place.describe()]"
		for(var/mob/living/basic/ambient_npc/npc as anything in place.living_npcs())
			lines += "&nbsp;&nbsp;&nbsp;&nbsp;[npc] ([npc.type]): [npc.activity?.name || "nothing"] [ADMIN_JMP(npc)]"
	lines += "<b>Planets</b>"
	for(var/key in SSambient_npcs.planets)
		var/datum/ambient_planet/record = SSambient_npcs.planets[key]
		var/obj/structure/overmap/planet/planet = record.planet()
		lines += "&nbsp;&nbsp;[planet || "(gone)"]: [record.planet_type], band [record.band], [length(record.sites)] site\s"
		for(var/datum/ambient_place/site/site as anything in record.sites)
			lines += "&nbsp;&nbsp;&nbsp;&nbsp;[site.describe()] [site.center ? ADMIN_JMP(site.center) : ""]"
	lines += "<b>Asteroid fields</b>"
	for(var/datum/ambient_place/site/site as anything in SSambient_npcs.field_sites)
		lines += "&nbsp;&nbsp;[site.describe()] [site.center ? ADMIN_JMP(site.center) : ""]"
	lines += "<b>Made by admins</b>"
	for(var/datum/ambient_place/site/site as anything in SSambient_npcs.admin_sites)
		lines += "&nbsp;&nbsp;[site.describe()] [site.center ? ADMIN_JMP(site.center) : ""]"
	to_chat(user, boxed_message(lines.Join("<br>")))
	BLACKBOX_LOG_ADMIN_VERB("List Ambient Sites")
