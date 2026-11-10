// Admin debug tool: spawn human NPCs around yourself, through the same throttled queue the game uses.

ADMIN_VERB(spawn_human_npcs, R_SPAWN|R_DEBUG, "Spawn Human NPCs", "Spawn human NPCs of one type around you, built a few per tick.", ADMIN_CATEGORY_DEBUG)
	var/turf/center = get_turf(user.mob)
	if(isnull(center))
		to_chat(user, span_warning("You need to be standing somewhere."), confidential = TRUE)
		return
	var/list/choices = list()
	for(var/npc_type in subtypesof(/mob/living/carbon/human/npc))
		var/mob/living/carbon/human/npc/npc_path = npc_type
		choices["[initial(npc_path.npc_name) || initial(npc_path.name)] ([npc_type])"] = npc_type
	var/choice = tgui_input_list(user, "Which human NPC?", "Spawn Human NPCs", sort_list(choices))
	if(isnull(choice) || isnull(choices[choice]))
		return
	var/count = tgui_input_number(user, "How many?", "Spawn Human NPCs", 1, 50, 1)
	if(!count)
		return
	var/list/spots = list()
	for(var/turf/open/spot in RANGE_TURFS(3, center))
		if(!spot.is_blocked_turf(exclude_mobs = TRUE))
			spots += spot
	if(!length(spots))
		spots += center
	var/npc_type = choices[choice]
	var/datum/callback/mark = CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(human_npc_mark_admin_spawned))
	for(var/i in 1 to count)
		spawn_human_npc(npc_type, pick(spots), on_spawned = mark)
	log_admin("[key_name(user)] spawned [count] [npc_type] at [AREACOORD(center)]")
	message_admins("[key_name_admin(user)] spawned [count] [npc_type] at [ADMIN_VERBOSEJMP(center)]")
	BLACKBOX_LOG_ADMIN_VERB("Spawn Human NPCs")
