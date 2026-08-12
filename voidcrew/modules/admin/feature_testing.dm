/**
 * # Feature-testing admin verbs
 *
 * One toolkit of admin verbs for playtesting the big voidcrew systems without
 * waiting on their natural schedules or RNG:
 *
 * - Vestige system: surface a chosen ruin, hand a chosen trial to a player,
 *   force-fulfill it, grant boons directly, inspect or wipe a player's ledger.
 * - Zone loot: spawn any cache with a forced zone tier, preview every table,
 *   spawn every rare-loot unique at once.
 * - Dynamic events: fire a chosen event at a chosen ship.
 * - Missions: hand a chosen mission type to a ship, force-resolve any active one.
 * - Trade: grant vouchers, reveal rare rumor-chart ruins, spawn gun blueprints.
 * - Overmap: spawn gas nebulas (ram scoop testing), surface a contested cache.
 *
 * Complements the per-module verbs that already exist: colosseum match control
 * (colosseum_controller.dm), ship economy grants (ship_upgrades/admin_verbs.dm),
 * NPC ship tools (npc_ships/code/admin_verbs.dm) and zone status (zone_admin.dm).
 *
 * All verbs live under the Debug category, prefixed by system so they group
 * together in the panel.
 */

// ===== SHARED PICKERS =====

/// Presents every living, minded player for selection. Returns the mob, or null on cancel.
/proc/voidcrew_admin_pick_player(client/user, title = "Select Player")
	var/list/choices = list()
	for(var/mob/living/candidate in GLOB.player_list)
		if(!candidate.mind)
			continue
		choices["[candidate.real_name || candidate.name] ([candidate.ckey])"] = candidate
	if(!length(choices))
		to_chat(user, span_warning("No living players with minds are connected."))
		return null
	var/choice = tgui_input_list(user, "Select a player:", title, sort_list(choices))
	if(!choice)
		return null
	var/mob/living/chosen = choices[choice]
	return QDELETED(chosen) ? null : chosen

/**
 * Presents every carbon body worth operating on: the players, plus whatever
 * the admin has marked in VV. The marked slot is the only way to reach a body
 * with no client (a spawned test dummy or a monkey) which is most of what
 * chrome gets tried on. Returns the mob, or null on cancel.
 */
/proc/voidcrew_admin_pick_carbon(client/user, title = "Select Body")
	var/list/choices = list()
	var/mob/living/carbon/marked = user.holder?.marked_datum
	if(istype(marked) && !QDELETED(marked))
		choices["(VV marked) [marked.real_name || marked.name]"] = marked
	for(var/mob/living/carbon/candidate in GLOB.player_list)
		choices["[candidate.real_name || candidate.name] ([candidate.ckey])"] = candidate
	if(!length(choices))
		to_chat(user, span_warning("No carbon bodies are connected. Mark one in VV to reach a body with no client."))
		return null
	var/choice = tgui_input_list(user, "Which body?", title, sort_list(choices))
	if(!choice)
		return null
	var/mob/living/carbon/chosen = choices[choice]
	return QDELETED(chosen) ? null : chosen

/// Presents every loaded ship for selection. Returns the overmap ship, or null on cancel.
/proc/voidcrew_admin_pick_ship(client/user, title = "Select Ship")
	var/list/choices = list()
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(QDELETED(ship) || ship.abandoned || !ship.shuttle)
			continue
		choices["[ship.display_name || ship.name]: [length(ship.get_event_crew())] crew aboard"] = ship
	if(!length(choices))
		to_chat(user, span_warning("No loaded ships exist."))
		return null
	var/choice = tgui_input_list(user, "Select a ship:", title, sort_list(choices))
	if(!choice)
		return null
	var/obj/structure/overmap/ship/chosen = choices[choice]
	return QDELETED(chosen) ? null : chosen

/// Zone band picker. Returns ZONE_GREEN/ZONE_YELLOW/ZONE_RED, or null on cancel.
/proc/voidcrew_admin_pick_zone_band(client/user, title = "Select Zone Band")
	var/choice = tgui_input_list(user, "Which zone band?", title, list("Red (dangerous)", "Yellow (contested)", "Green (safe ring)"))
	switch(choice)
		if("Red (dangerous)")
			return ZONE_RED
		if("Yellow (contested)")
			return ZONE_YELLOW
		if("Green (safe ring)")
			return ZONE_GREEN
	return null

/**
 * One row per patron subtype: display name, trial typepaths, boon typepaths.
 * Read off a throwaway nullspace instance because initial() can't read list vars.
 */
/proc/voidcrew_admin_vestige_registry()
	var/list/registry = list()
	for(var/patron_type in subtypesof(/mob/living/basic/vestige_patron))
		var/mob/living/basic/vestige_patron/patron = new patron_type(null)
		registry[patron_type] = list(
			"name" = patron.name,
			"trials" = patron.trial_types.Copy(),
			"boons" = patron.boon_types.Copy(),
		)
		qdel(patron)
	return registry

// ===== VESTIGE SYSTEM =====

ADMIN_VERB(vestige_spawn_ruin, R_ADMIN|R_DEBUG, "Vestige: Spawn Ruin", "Surface a specific vestige ruin's dread signal on the overmap immediately.", ADMIN_CATEGORY_DEBUG)
	var/list/choices = list()
	for(var/ruin_id in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/vestige/template = SSmapping.space_ruins_templates[ruin_id]
		if(!istype(template))
			continue
		var/surfaced = (template in SSovermap.spawned_vestige_templates) ? " (already surfaced)" : ""
		choices["[template.name][surfaced]"] = template
	if(!length(choices))
		to_chat(user, span_warning("No vestige ruin templates are registered."))
		return
	var/choice = tgui_input_list(user, "Which vestige ruin should surface?", "Spawn Vestige Ruin", sort_list(choices))
	if(!choice)
		return
	var/datum/map_template/ruin/space/vestige/template = choices[choice]

	var/turf/spawn_turf = SSovermap.get_unused_overmap_square()
	if(!spawn_turf)
		to_chat(user, span_warning("Could not find an unused overmap square."))
		return
	var/obj/structure/overmap/space_ruin/vestige/signal = new(spawn_turf)
	signal.set_ruin_template(template)
	SSovermap.spawned_vestige_templates |= template

	if(tgui_alert(user, "Broadcast the arrival announcement to the galaxy?", "Spawn Vestige Ruin", list("Announce", "Silent")) == "Announce")
		priority_announce(template.arrival_announcement, "Deep Space Advisory", sender_override = "Sector Sensor Net")

	var/list/coords = signal.get_relative_overmap_coords()
	to_chat(user, span_notice("'[template.name]' surfaced at overmap ([coords[1]], [coords[2]])."))
	message_admins("[key_name_admin(user)] surfaced vestige ruin '[template.name]' at overmap ([coords[1]], [coords[2]]).")
	log_admin("[key_name(user)] surfaced vestige ruin '[template.name]'.")
	BLACKBOX_LOG_ADMIN_VERB("Vestige Spawn Ruin")

ADMIN_VERB(vestige_assign_trial, R_ADMIN|R_DEBUG, "Vestige: Assign Trial", "Hand a specific vestige trial to a player, bypassing the patron conversation.", ADMIN_CATEGORY_DEBUG)
	var/mob/living/target = voidcrew_admin_pick_player(user, "Assign Vestige Trial")
	if(!target)
		return
	var/datum/mind/mind = target.mind

	var/list/registry = voidcrew_admin_vestige_registry()
	var/list/choices = list()
	for(var/patron_type in registry)
		var/list/entry = registry[patron_type]
		for(var/datum/vestige_trial/trial_type as anything in entry["trials"])
			var/flag = ""
			if(trial_type in mind.completed_vestige_trials)
				flag = " (completed)"
			else if(mind.active_vestige_trial?.type == trial_type)
				flag = " (active)"
			choices["[entry["name"]], [initial(trial_type.name)][flag]"] = list("trial" = trial_type, "patron" = entry["name"], "boons" = entry["boons"])
	var/choice = tgui_input_list(user, "Which trial should [target] undertake?", "Assign Vestige Trial", choices)
	if(!choice)
		return
	if(QDELETED(target) || target.mind != mind)
		to_chat(user, span_warning("The target is gone or changed minds, aborting."))
		return
	var/list/picked = choices[choice]
	var/datum/vestige_trial/trial_type = picked["trial"]

	if(mind.active_vestige_trial)
		if(tgui_alert(user, "[target] already has an active pact ([mind.active_vestige_trial.name]). Replace it?", "Assign Vestige Trial", list("Replace", "Cancel")) != "Replace")
			return
		if(QDELETED(target) || target.mind != mind)
			return
		qdel(mind.active_vestige_trial)
	if(mind.vestige_pending_reward)
		to_chat(user, span_warning("Note: [target] has an unclaimed boon. Completing this trial will fulfill the pact but skip the payout until the claim is spent."))

	// Force-assigning re-opens a fulfilled trial so it can be tested fresh
	LAZYREMOVE(mind.completed_vestige_trials, trial_type)
	var/datum/vestige_record/record = get_vestige_record(mind)
	if(record)
		record.completed_trials -= trial_type

	var/list/boon_pool = picked["boons"]
	var/datum/vestige_trial/trial = new trial_type(mind, picked["patron"], boon_pool.Copy())
	mind.active_vestige_trial = trial
	trial.begin(target)
	to_chat(user, span_notice("[target] is now bound to '[trial.name]' under [trial.patron_name]."))
	message_admins("[key_name_admin(user)] assigned vestige trial '[trial.name]' ([picked["patron"]]) to [key_name_admin(target)].")
	log_admin("[key_name(user)] assigned vestige trial '[trial.name]' to [key_name(target)].")
	BLACKBOX_LOG_ADMIN_VERB("Vestige Assign Trial")

ADMIN_VERB(vestige_complete_trial, R_ADMIN|R_DEBUG, "Vestige: Complete Trial", "Force-fulfill a player's active vestige pact, running the full boon payout.", ADMIN_CATEGORY_DEBUG)
	var/mob/living/target = voidcrew_admin_pick_player(user, "Complete Vestige Trial")
	if(!target)
		return
	var/datum/mind/mind = target.mind
	var/datum/vestige_trial/active = mind.active_vestige_trial
	if(!active)
		to_chat(user, span_warning("[target] has no active vestige pact."))
		return
	var/warning = mind.vestige_pending_reward ? "\nWARNING: they hold an unclaimed boon. The payout will be skipped until it's spent." : ""
	if(tgui_alert(user, "[active.name] ([active.patron_name])\n[active.get_progress_text()][warning]\n\nForce-fulfill this pact?", "Complete Vestige Trial", list("Fulfill", "Cancel")) != "Fulfill")
		return
	if(QDELETED(target) || target.mind != mind || mind.active_vestige_trial != active)
		to_chat(user, span_warning("The pact changed while you were deciding, aborting."))
		return
	var/trial_name = active.name
	active.complete()
	to_chat(user, span_notice("'[trial_name]' fulfilled for [target]."))
	message_admins("[key_name_admin(user)] force-fulfilled vestige trial '[trial_name]' for [key_name_admin(target)].")
	log_admin("[key_name(user)] force-fulfilled vestige trial '[trial_name]' for [key_name(target)].")
	BLACKBOX_LOG_ADMIN_VERB("Vestige Complete Trial")

ADMIN_VERB(vestige_grant_boon, R_ADMIN|R_DEBUG, "Vestige: Grant Boon", "Grant a specific vestige boon to a player directly, with ledger write-through.", ADMIN_CATEGORY_DEBUG)
	var/mob/living/target = voidcrew_admin_pick_player(user, "Grant Vestige Boon")
	if(!target)
		return
	var/datum/mind/mind = target.mind

	var/list/registry = voidcrew_admin_vestige_registry()
	var/list/choices = list()
	for(var/patron_type in registry)
		var/list/entry = registry[patron_type]
		for(var/datum/vestige_boon/boon_type as anything in entry["boons"])
			var/flag = ""
			if(boon_type in mind.vestige_boons)
				flag = " (owned)"
			else
				var/datum/vestige_boon/prerequisite = initial(boon_type.upgrades_from)
				if(prerequisite && !(prerequisite in mind.vestige_boons))
					flag = " (upgrade of [initial(prerequisite.name)])"
			choices["[entry["name"]], [initial(boon_type.name)][flag]"] = boon_type

	// Capstones hang off /datum/vestige_ascension rather than any patron's boon pool
	// (ascension.dm), so the registry cannot see them, and must not, because
	// vestige_assign_trial pays a forced trial out of that same list and a capstone
	// must never drop from an ordinary trial. Fold them in here, for this verb only.
	for(var/patron_type in registry)
		var/datum/vestige_ascension/capstone = get_vestige_ascension(patron_type)
		if(!capstone?.boon_type)
			continue
		var/list/entry = registry[patron_type]
		var/datum/vestige_boon/capstone_boon = capstone.boon_type
		var/flag = (capstone_boon in mind.vestige_boons) ? " (owned)" : " (CAPSTONE)"
		choices["[entry["name"]], [initial(capstone_boon.name)][flag]"] = capstone_boon

	var/choice = tgui_input_list(user, "Which boon should [target] receive?", "Grant Vestige Boon", choices)
	if(!choice)
		return
	if(QDELETED(target) || target.mind != mind)
		to_chat(user, span_warning("The target is gone or changed minds, aborting."))
		return
	var/datum/vestige_boon/boon_type = choices[choice]
	if(mind.vestige_boons && (boon_type in mind.vestige_boons))
		if(tgui_alert(user, "[target] already owns [initial(boon_type.name)]. Grant a duplicate anyway?", "Grant Vestige Boon", list("Grant", "Cancel")) != "Grant")
			return
		if(QDELETED(target) || target.mind != mind)
			return

	var/datum/vestige_boon/boon = new boon_type()
	boon.grant(target, mind)
	qdel(boon)
	if(!(boon_type in mind.vestige_boons))
		LAZYADD(mind.vestige_boons, boon_type)
	var/datum/vestige_record/record = get_vestige_record(mind, create = TRUE)
	if(record)
		record.boons |= boon_type
	to_chat(user, span_notice("[initial(boon_type.name)] granted to [target]."))
	message_admins("[key_name_admin(user)] granted vestige boon '[initial(boon_type.name)]' to [key_name_admin(target)].")
	log_admin("[key_name(user)] granted vestige boon '[initial(boon_type.name)]' to [key_name(target)].")
	BLACKBOX_LOG_ADMIN_VERB("Vestige Grant Boon")

ADMIN_VERB(vestige_inspect_player, R_ADMIN|R_DEBUG, "Vestige: Inspect Player", "Show a player's full vestige state: pact, pending claim, boons, completions, assignments.", ADMIN_CATEGORY_DEBUG)
	var/mob/living/target = voidcrew_admin_pick_player(user, "Inspect Vestige State")
	if(!target)
		return
	var/datum/mind/mind = target.mind
	var/list/lines = list(span_boldnotice("Vestige state for [target] ([target.ckey]):"))

	var/datum/vestige_trial/active = mind.active_vestige_trial
	lines += "Active pact: [active ? "[active.name] ([active.patron_name]), [active.get_progress_text()]" : "none"]"

	var/datum/action/vestige_reward/pending = mind.vestige_pending_reward
	if(pending)
		var/list/candidate_names = list()
		for(var/datum/vestige_boon/candidate as anything in pending.candidates)
			candidate_names += initial(candidate.name)
		lines += "Unclaimed boon from [pending.patron_name]: [candidate_names.Join(", ")]"
	else
		lines += "Unclaimed boon: none"

	var/list/boon_names = list()
	for(var/datum/vestige_boon/boon_type as anything in mind.vestige_boons)
		boon_names += initial(boon_type.name)
	lines += "Boons owned ([length(boon_names)]): [length(boon_names) ? boon_names.Join(", ") : "none"]"

	var/list/trial_names = list()
	for(var/datum/vestige_trial/trial_type as anything in mind.completed_vestige_trials)
		trial_names += initial(trial_type.name)
	lines += "Trials fulfilled ([length(trial_names)]): [length(trial_names) ? trial_names.Join(", ") : "none"]"

	if(LAZYLEN(mind.vestige_trial_assignments))
		lines += "Sticky assignments:"
		for(var/patron_type in mind.vestige_trial_assignments)
			var/datum/vestige_trial/assigned = mind.vestige_trial_assignments[patron_type]
			lines += "- [patron_type] → [initial(assigned.name)]"

	var/datum/vestige_record/record = get_vestige_record(mind)
	if(record)
		lines += "Soul record (ckey ledger): [length(record.boons)] boons, [length(record.completed_trials)] completions[length(record.pending_candidates) ? ", pending claim from [record.pending_patron_name]" : ""]"
	else
		lines += "Soul record: none"

	to_chat(user, lines.Join("\n"))
	BLACKBOX_LOG_ADMIN_VERB("Vestige Inspect Player")

ADMIN_VERB(vestige_reset_player, R_ADMIN|R_DEBUG, "Vestige: Reset Player", "Wipe a player's vestige state: pact, unclaimed claim, boons, completions and soul record.", ADMIN_CATEGORY_DEBUG)
	var/mob/living/target = voidcrew_admin_pick_player(user, "Reset Vestige State")
	if(!target)
		return
	var/datum/mind/mind = target.mind
	if(tgui_alert(user, "Wipe ALL vestige state for [target]? Spell boons are stripped from the body; conjured items stay in the world.", "Reset Vestige State", list("Wipe", "Cancel")) != "Wipe")
		return
	if(QDELETED(target) || target.mind != mind)
		return

	if(mind.active_vestige_trial)
		qdel(mind.active_vestige_trial)
	if(mind.vestige_pending_reward)
		qdel(mind.vestige_pending_reward)

	// Strip the actions spell boons granted. Removing a shapeshift can delete the
	// current body, so re-resolve it from the mind every pass.
	var/list/owned = mind.vestige_boons?.Copy()
	for(var/datum/vestige_boon/spell/boon_type as anything in owned)
		if(!ispath(boon_type, /datum/vestige_boon/spell))
			continue
		var/spell_type = initial(boon_type.spell_type)
		if(!spell_type)
			continue
		var/mob/living/body = mind.current
		if(!body)
			break
		for(var/datum/action/old_action as anything in body.actions)
			if(old_action.type == spell_type)
				qdel(old_action)
				break

	mind.vestige_boons = null
	mind.completed_vestige_trials = null
	mind.vestige_trial_assignments = null
	if(mind.key)
		GLOB.vestige_records -= ckey(mind.key)

	to_chat(user, span_notice("Vestige state wiped for [target]."))
	message_admins("[key_name_admin(user)] wiped all vestige state for [key_name_admin(target)].")
	log_admin("[key_name(user)] wiped all vestige state for [key_name(target)].")
	BLACKBOX_LOG_ADMIN_VERB("Vestige Reset Player")

// ===== ZONE LOOT =====

ADMIN_VERB(spawn_zone_loot_cache, R_ADMIN|R_DEBUG, "Loot: Spawn Zone Cache", "Spawn a zone loot cache at your feet with a forced zone tier. Contents roll on first open.", ADMIN_CATEGORY_DEBUG)
	var/turf/drop_turf = get_turf(user.mob)
	if(!drop_turf)
		to_chat(user, span_warning("You need a physical location to spawn a cache at."))
		return
	var/list/choices = list()
	for(var/obj/structure/closet/crate/zone_loot/cache_type as anything in subtypesof(/obj/structure/closet/crate/zone_loot))
		var/short = replacetext("[cache_type]", "/obj/structure/closet/crate/zone_loot/", "")
		choices["[short]: [initial(cache_type.name)]"] = cache_type
	var/choice = tgui_input_list(user, "Which cache?", "Spawn Zone Cache", sort_list(choices))
	if(!choice)
		return
	var/cache_type = choices[choice]
	var/zone_label = tgui_input_list(user, "Force which zone tier? (Auto resolves from where you stand.)", "Spawn Zone Cache", list("Red (best)", "Yellow", "Green (weakest)", "Auto"))
	if(!zone_label)
		return

	var/obj/structure/closet/crate/zone_loot/cache = new cache_type(drop_turf)
	switch(zone_label)
		if("Red (best)")
			cache.loot_zone = ZONE_RED
		if("Yellow")
			cache.loot_zone = ZONE_YELLOW
		if("Green (weakest)")
			cache.loot_zone = ZONE_GREEN
	to_chat(user, span_notice("[cache] spawned ([zone_label] band[cache.bonus_draws ? ", +[cache.bonus_draws] bonus draws" : ""]). Open it to roll its contents."))
	message_admins("[key_name_admin(user)] spawned a [choice] zone loot cache ([zone_label]) at [ADMIN_VERBOSEJMP(drop_turf)].")
	log_admin("[key_name(user)] spawned a [choice] zone loot cache ([zone_label]).")
	BLACKBOX_LOG_ADMIN_VERB("Spawn Zone Loot Cache")

ADMIN_VERB(preview_zone_loot_tables, R_ADMIN|R_DEBUG, "Loot: Preview Zone Tables", "Show every weighted loot table of a zone cache type, with drop percentages.", ADMIN_CATEGORY_DEBUG)
	var/list/choices = list()
	for(var/obj/structure/closet/crate/zone_loot/cache_type as anything in subtypesof(/obj/structure/closet/crate/zone_loot))
		var/short = replacetext("[cache_type]", "/obj/structure/closet/crate/zone_loot/", "")
		choices["[short]: [initial(cache_type.name)]"] = cache_type
	var/choice = tgui_input_list(user, "Which cache type?", "Preview Zone Tables", sort_list(choices))
	if(!choice)
		return
	var/cache_type = choices[choice]

	var/obj/structure/closet/crate/zone_loot/sample = new cache_type(null)
	var/datum/loot_theme/theme = GLOB.loot_themes[sample.theme]
	if(!theme)
		to_chat(user, span_warning("[cache_type] has no registered loot theme."))
		qdel(sample)
		return
	var/list/sections = list(
		"Common" = theme.loot_common,
		"Uncommon" = theme.loot_uncommon,
		"Prime" = theme.loot_prime,
		"Uniques" = theme.loot_uniques,
	)
	// Zone never picks a table any more: it picks how many draws and how those
	// draws lean across the four tiers. Show that first, because it is the part
	// that decides what a band actually feels like.
	var/list/html = list(
		"<h2>[sample.name]</h2>",
		"<p>Every band draws from all four tiers below. The band sets the draw count and the odds\
		[sample.bonus_draws ? ", and this crate adds [sample.bonus_draws] bonus draws on top" : ""].</p>",
		"<table border='1' cellpadding='4'><tr><th>Band</th><th>Draws</th><th>Common</th><th>Uncommon</th><th>Prime</th><th>Unique</th></tr>",
	)
	var/list/bands = list(
		"Green" = list(ZONE_LOOT_DRAWS_MIN_GREEN, ZONE_LOOT_DRAWS_MAX_GREEN, ZONE_LOOT_ODDS_GREEN),
		"Yellow" = list(ZONE_LOOT_DRAWS_MIN_YELLOW, ZONE_LOOT_DRAWS_MAX_YELLOW, ZONE_LOOT_ODDS_YELLOW),
		"Red" = list(ZONE_LOOT_DRAWS_MIN_RED, ZONE_LOOT_DRAWS_MAX_RED, ZONE_LOOT_ODDS_RED),
	)
	for(var/band in bands)
		var/list/spec = bands[band]
		var/list/odds = spec[3]
		var/odds_total = 0
		for(var/tier in odds)
			odds_total += odds[tier]
		html += "<tr><td>[band]</td><td>[spec[1]]-[spec[2]][sample.bonus_draws ? " (+[sample.bonus_draws])" : ""]</td>"
		for(var/tier in list(LOOT_TIER_COMMON, LOOT_TIER_UNCOMMON, LOOT_TIER_PRIME, LOOT_TIER_UNIQUE))
			html += "<td>[round(odds[tier] / odds_total * 100, 0.1)]%</td>"
		html += "</tr>"
	html += "</table>"
	for(var/section in sections)
		var/list/table = sections[section]
		if(!length(table))
			continue
		var/total = 0
		for(var/entry in table)
			total += table[entry]
		html += "<h3>[section] (total weight [total])</h3><ul>"
		for(var/entry in table)
			var/weight = table[entry]
			html += "<li>[entry]: [weight] ([round(weight / total * 100, 0.1)]%)</li>"
		html += "</ul>"
	qdel(sample)

	var/datum/browser/popup = new(user.mob, "zoneloottables", "Zone Loot Tables", 620, 700)
	popup.set_content(html.Join(""))
	popup.open()
	BLACKBOX_LOG_ADMIN_VERB("Preview Zone Loot Tables")

ADMIN_VERB(spawn_all_uniques, R_ADMIN|R_DEBUG, "Loot: Spawn All Uniques", "Spawn every loot unique in rows south of you, one row per cache theme.", ADMIN_CATEGORY_DEBUG)
	var/turf/origin = get_turf(user.mob)
	if(!origin)
		to_chat(user, span_warning("You need a physical location to spawn the uniques at."))
		return
	// "Unique" is defined by the trait rather than a hand-kept list: spawn each
	// entry and keep it only if it carries TRAIT_NO_REPLICATE (every unique
	// ADD_TRAITs it in Initialize, so this never drifts when items are added or
	// cut). The loot_uniques shelf should be all uniques by construction, but
	// the trait check stays as the actual authority. Companion spawns (the Vow's
	// twin ring, No Quarter's ammo kit) ride along with their owner.
	var/list/seen_types = list()
	var/list/summary = list()
	var/total = 0
	var/row = 0
	for(var/theme_path in GLOB.loot_themes)
		var/datum/loot_theme/theme = GLOB.loot_themes[theme_path]
		var/col = 0
		for(var/list/table in list(theme.loot_uniques))
			for(var/entry in table)
				if(seen_types[entry])
					continue
				seen_types[entry] = TRUE
				var/turf/drop = locate(origin.x + col, origin.y - 1 - row, origin.z) || origin
				var/atom/movable/candidate = new entry(drop)
				if(!HAS_TRAIT(candidate, TRAIT_NO_REPLICATE))
					qdel(candidate)
					continue
				col++
				total++
		if(col)
			summary += "[theme.name] [col]"
			row++
	if(!total)
		to_chat(user, span_warning("No uniques found in any rare loot table."))
		return
	to_chat(user, span_notice("Spawned [total] uniques south of you, one row per theme, green to red running east: [summary.Join(", ")]."))
	message_admins("[key_name_admin(user)] spawned all [total] rare-loot uniques at [ADMIN_VERBOSEJMP(origin)].")
	log_admin("[key_name(user)] spawned all [total] rare-loot uniques.")
	BLACKBOX_LOG_ADMIN_VERB("Spawn All Uniques")

// ===== DYNAMIC EVENTS =====

ADMIN_VERB(force_dynamic_event, R_ADMIN|R_DEBUG, "Events: Force Dynamic Event", "Fire a specific voidcrew dynamic event now, at a ship of your choosing.", ADMIN_CATEGORY_DEBUG)
	if(!length(SSdynamic_events.control))
		to_chat(user, span_warning("SSdynamic_events has no event roster."))
		return
	var/list/choices = list()
	for(var/datum/round_event_control/voidcrew/event as anything in SSdynamic_events.control)
		choices["[event.name] ([event.event_scope == EVENT_SCOPE_SHIP ? "ship" : "galaxy"]), ran [event.occurrences]x"] = event
	var/choice = tgui_input_list(user, "Which event?", "Force Dynamic Event", sort_list(choices))
	if(!choice)
		return
	var/datum/round_event_control/voidcrew/event = choices[choice]

	var/target_label = "the galaxy"
	if(event.event_scope == EVENT_SCOPE_SHIP)
		var/list/ship_choices = list("(random valid ship)" = "random")
		for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
			if(QDELETED(ship) || ship.abandoned || !ship.shuttle)
				continue
			ship_choices["[ship.display_name || ship.name]: [length(ship.get_event_crew())] crew aboard"] = ship
		var/ship_choice = tgui_input_list(user, "Target which ship?", "Force Dynamic Event", ship_choices)
		if(!ship_choice)
			return
		if(ship_choices[ship_choice] != "random")
			var/obj/structure/overmap/ship/target = ship_choices[ship_choice]
			if(QDELETED(target))
				to_chat(user, span_warning("That ship no longer exists."))
				return
			if(!event.is_valid_target(target))
				to_chat(user, span_warning("Note: [target.display_name || target.name] fails the event's normal targeting rules (crew/cooldown/zone/harbor), firing anyway."))
			event.pending_target = target
			target_label = target.display_name || target.name
		else
			target_label = "a random valid ship"

	event.run_event(random = FALSE, admin_forced = TRUE, event_cause = "feature-testing verb")
	to_chat(user, span_notice("[event.name] fired at [target_label]."))
	message_admins("[key_name_admin(user)] force-fired dynamic event '[event.name]' at [target_label].")
	log_admin("[key_name(user)] force-fired dynamic event '[event.name]' at [target_label].")
	BLACKBOX_LOG_ADMIN_VERB("Force Dynamic Event")

// ===== MISSIONS =====

ADMIN_VERB(give_ship_mission, R_ADMIN|R_DEBUG, "Missions: Give Mission", "Hand a specific mission type to a ship: onto its board, or already accepted.", ADMIN_CATEGORY_DEBUG)
	var/list/choices = list()
	for(var/datum/mission/mission_type as anything in subtypesof(/datum/mission))
		var/short = replacetext("[mission_type]", "/datum/mission/", "")
		choices["[short]: [initial(mission_type.name)][initial(mission_type.weight) ? "" : " (never natural)"]"] = mission_type
	var/choice = tgui_input_list(user, "Which mission type?", "Give Mission", sort_list(choices))
	if(!choice)
		return
	var/mission_type = choices[choice]
	var/obj/structure/overmap/ship/ship = voidcrew_admin_pick_ship(user, "Give Mission")
	if(!ship)
		return
	var/mode = tgui_alert(user, "Start it immediately, or post it to the ship's board for the crew to accept?", "Give Mission", list("Start Now", "Post To Board", "Cancel"))
	if(!mode || mode == "Cancel" || QDELETED(ship))
		return

	var/datum/mission/mission = new mission_type(null)
	if(mission.generation_failed)
		qdel(mission)
		to_chat(user, span_warning("Mission generation failed. No valid target/setup exists right now for that type."))
		return
	if(mode == "Start Now")
		mission.start_mission(ship)
	else
		ship.available_missions += mission
	to_chat(user, span_notice("'[mission.name]' [mode == "Start Now" ? "started for" : "posted to"] [ship.display_name || ship.name]."))
	message_admins("[key_name_admin(user)] gave mission '[mission.name]' to [ship.display_name || ship.name] ([mode]).")
	log_admin("[key_name(user)] gave mission '[mission.name]' to [ship.display_name || ship.name] ([mode]).")
	BLACKBOX_LOG_ADMIN_VERB("Give Ship Mission")

ADMIN_VERB(force_resolve_mission, R_ADMIN|R_DEBUG, "Missions: Resolve Mission", "Force-complete (full payout at your feet) or force-fail any active mission.", ADMIN_CATEGORY_DEBUG)
	var/list/choices = list()
	for(var/datum/mission/mission as anything in SSmissions.all_active_missions)
		if(QDELETED(mission))
			continue
		choices["[mission.name]: [mission.servant ? (mission.servant.display_name || mission.servant.name) : "no ship"]"] = mission
	if(!length(choices))
		to_chat(user, span_warning("No missions are active anywhere."))
		return
	var/choice = tgui_input_list(user, "Which active mission?", "Resolve Mission", sort_list(choices))
	if(!choice)
		return
	var/datum/mission/mission = choices[choice]
	var/action = tgui_alert(user, "Resolve '[choice]' how? Completing pays out at your location.", "Resolve Mission", list("Complete", "Fail", "Cancel"))
	if(!action || action == "Cancel" || QDELETED(mission))
		return
	var/mission_name = mission.name
	if(action == "Complete")
		if(!mission.turn_in(user.mob, null, force = TRUE))
			to_chat(user, span_warning("'[mission_name]' refused to complete (already resolved?)."))
			return
	else
		mission.fail("Failed by admin intervention.")
	to_chat(user, span_notice("'[mission_name]' [action == "Complete" ? "completed" : "failed"]."))
	message_admins("[key_name_admin(user)] force-[action == "Complete" ? "completed" : "failed"] mission '[mission_name]'.")
	log_admin("[key_name(user)] force-[action == "Complete" ? "completed" : "failed"] mission '[mission_name]'.")
	BLACKBOX_LOG_ADMIN_VERB("Force Resolve Mission")

// ===== TRADE =====

ADMIN_VERB(give_trade_vouchers, R_ADMIN|R_DEBUG, "Trade: Give Vouchers", "Put a stack of trade vouchers in a player's hands.", ADMIN_CATEGORY_DEBUG)
	var/mob/living/target = voidcrew_admin_pick_player(user, "Give Trade Vouchers")
	if(!target)
		return
	var/amount = tgui_input_number(user, "How many vouchers?", "Give Trade Vouchers", 10, 1000, 1)
	if(!amount)
		return
	if(QDELETED(target))
		return
	var/obj/item/stack/trade_voucher/vouchers = new(get_turf(target), amount)
	target.put_in_hands(vouchers)
	to_chat(user, span_notice("[amount] trade voucher\s given to [target]."))
	message_admins("[key_name_admin(user)] gave [amount] trade vouchers to [key_name_admin(target)].")
	log_admin("[key_name(user)] gave [amount] trade vouchers to [key_name(target)].")
	BLACKBOX_LOG_ADMIN_VERB("Give Trade Vouchers")

ADMIN_VERB(reveal_rare_ruin, R_ADMIN|R_DEBUG, "Trade: Reveal Rare Ruin", "Spawn a specific rumor-chart rare ruin on the overmap, as if its chart were revealed.", ADMIN_CATEGORY_DEBUG)
	var/list/choices = list()
	for(var/ruin_id in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/rare/template = SSmapping.space_ruins_templates[ruin_id]
		if(!istype(template))
			continue
		choices["[template.name][GLOB.claimed_rumor_charts[template.type] ? " (chart already sold)" : ""]"] = template
	if(!length(choices))
		to_chat(user, span_warning("No rare ruin templates are registered."))
		return
	var/choice = tgui_input_list(user, "Which rare ruin?", "Reveal Rare Ruin", sort_list(choices))
	if(!choice)
		return
	var/datum/map_template/ruin/space/rare/template = choices[choice]
	var/band = voidcrew_admin_pick_zone_band(user, "Reveal Rare Ruin")
	if(isnull(band))
		return

	var/turf/spawn_turf = SSovermap.get_unused_overmap_square_in_zone_band(band)
	if(!spawn_turf)
		spawn_turf = SSovermap.get_unused_overmap_square()
	if(!spawn_turf)
		to_chat(user, span_warning("Could not find an unused overmap square."))
		return
	var/obj/structure/overmap/space_ruin/ruin = new(spawn_turf)
	ruin.set_ruin_template(template)
	ruin.mark_rare()
	// Same claim the shop purchase makes, so outposts stop selling a chart to a ruin that already exists
	GLOB.claimed_rumor_charts[template.type] = TRUE

	var/list/coords = ruin.get_relative_overmap_coords()
	to_chat(user, span_notice("'[template.name]' spawned at overmap ([coords[1]], [coords[2]]) and its rumor chart marked as sold."))
	message_admins("[key_name_admin(user)] revealed rare ruin '[template.name]' at overmap ([coords[1]], [coords[2]]).")
	log_admin("[key_name(user)] revealed rare ruin '[template.name]'.")
	BLACKBOX_LOG_ADMIN_VERB("Reveal Rare Ruin")

ADMIN_VERB(spawn_gun_blueprint, R_ADMIN|R_DEBUG, "Trade: Spawn Blueprint", "Spawn a specific weapons-bench gun blueprint at your feet.", ADMIN_CATEGORY_DEBUG)
	var/turf/drop_turf = get_turf(user.mob)
	if(!drop_turf)
		to_chat(user, span_warning("You need a physical location to spawn a blueprint at."))
		return
	var/list/choices = list()
	for(var/obj/item/blueprint/blueprint_type as anything in subtypesof(/obj/item/blueprint))
		if(blueprint_type == /obj/item/blueprint/gun)
			continue
		choices[initial(blueprint_type.name)] = blueprint_type
	var/choice = tgui_input_list(user, "Which blueprint?", "Spawn Blueprint", sort_list(choices))
	if(!choice)
		return
	var/blueprint_type = choices[choice]
	var/obj/item/blueprint/blueprint = new blueprint_type(drop_turf)
	var/mob/living/admin_mob = user.mob
	if(isliving(admin_mob))
		admin_mob.put_in_hands(blueprint)
	to_chat(user, span_notice("[blueprint] spawned."))
	message_admins("[key_name_admin(user)] spawned blueprint '[blueprint]'.")
	log_admin("[key_name(user)] spawned blueprint '[blueprint]'.")
	BLACKBOX_LOG_ADMIN_VERB("Spawn Gun Blueprint")

// ===== OVERMAP / GAS ECONOMY =====

ADMIN_VERB(spawn_gas_nebula, R_ADMIN|R_DEBUG, "Overmap: Spawn Nebula", "Spawn a gas nebula on the overmap, under a ship for instant ram scoop testing, or on an empty square.", ADMIN_CATEGORY_DEBUG)
	var/list/choices = list("(random, roll the zone's gas table)" = /obj/structure/overmap/event/nebula)
	for(var/obj/structure/overmap/event/nebula/nebula_type as anything in subtypesof(/obj/structure/overmap/event/nebula))
		var/datum/gas/gas_path = initial(nebula_type.gas_type)
		choices[gas_path ? initial(gas_path.name) : "[nebula_type]"] = nebula_type
	var/choice = tgui_input_list(user, "Which gas?", "Spawn Nebula", choices)
	if(!choice)
		return
	var/nebula_type = choices[choice]

	var/turf/spawn_turf
	var/placement = tgui_alert(user, "Where should it form?", "Spawn Nebula", list("Under A Ship", "Empty Square", "Cancel"))
	switch(placement)
		if("Under A Ship")
			var/obj/structure/overmap/ship/ship = voidcrew_admin_pick_ship(user, "Spawn Nebula")
			if(!ship)
				return
			spawn_turf = get_turf(ship)
		if("Empty Square")
			var/band = voidcrew_admin_pick_zone_band(user, "Spawn Nebula")
			if(isnull(band))
				return
			spawn_turf = SSovermap.get_unused_overmap_square_in_zone_band(band)
			if(!spawn_turf)
				spawn_turf = SSovermap.get_unused_overmap_square()
		else
			return
	if(!spawn_turf)
		to_chat(user, span_warning("Could not find a valid overmap square."))
		return

	var/obj/structure/overmap/event/nebula/cloud = new nebula_type(spawn_turf)
	to_chat(user, span_notice("[cloud.name] formed ([cloud.get_scoop_rate()] mol/s base scoop rate). Hold a ship still inside it with the intake open to harvest."))
	message_admins("[key_name_admin(user)] spawned a [cloud.name] on the overmap.")
	log_admin("[key_name(user)] spawned a [cloud.name] on the overmap.")
	BLACKBOX_LOG_ADMIN_VERB("Spawn Gas Nebula")

ADMIN_VERB(spawn_contested_cache_now, R_ADMIN|R_DEBUG, "Overmap: Spawn Contested Cache", "Surface a contested cache drop platform now, skipping the round schedule.", ADMIN_CATEGORY_DEBUG)
	if(SSovermap.contested_caches_spawned >= CONTESTED_CACHE_MAX_PER_ROUND)
		if(tgui_alert(user, "The round budget ([CONTESTED_CACHE_MAX_PER_ROUND]) is already spent. Spawn another anyway?", "Spawn Contested Cache", list("Spawn", "Cancel")) != "Spawn")
			return
	var/datum/map_template/ruin/space/contested_cache/template
	for(var/ruin_id in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/contested_cache/candidate = SSmapping.space_ruins_templates[ruin_id]
		if(istype(candidate))
			template = candidate
			break
	if(!template)
		to_chat(user, span_warning("The contested cache map template is not registered."))
		return
	// Same placement rule as the natural scheduler: never in the safe outer ring
	var/turf/spawn_turf = SSovermap.get_unused_overmap_square_in_zone_band(pick(ZONE_YELLOW, ZONE_RED))
	if(!spawn_turf)
		spawn_turf = SSovermap.get_unused_overmap_square()
	if(!spawn_turf)
		to_chat(user, span_warning("Could not find an unused overmap square."))
		return
	var/obj/structure/overmap/space_ruin/contested_cache/signal = new(spawn_turf)
	signal.set_ruin_template(template)
	signal.start_event()
	SSovermap.contested_caches_spawned++

	var/list/coords = signal.get_relative_overmap_coords()
	to_chat(user, span_notice("Contested cache surfaced at overmap ([coords[1]], [coords[2]]). The galaxy has been told."))
	message_admins("[key_name_admin(user)] surfaced a contested cache at overmap ([coords[1]], [coords[2]]).")
	log_admin("[key_name(user)] surfaced a contested cache.")
	BLACKBOX_LOG_ADMIN_VERB("Spawn Contested Cache")
