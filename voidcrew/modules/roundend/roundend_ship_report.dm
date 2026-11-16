/**
 * Voidcrew's round-end report.
 *
 * tg's report is about one station: its integrity, the evacuation, station goals and the
 * station's economy. Voidcrew has none of those, so the procs below replace tg's versions in
 * code/__HELPERS/roundend.dm (a later definition of the same proc runs instead of the earlier
 * one; none of these call ..()). The station parts become one row per player ship.
 *
 * Every figure in a row is read from the ship at round end, or when the hull left the round:
 * - Funds: the ship account balance.
 * - Research: nodes researched on the ship's research server, not counting starting nodes.
 * - Missions: missions the ship turned in (counted in finish_mission(), voidcrew/modules/missions/_missions.dm).
 * - Reputation: the crew's reputation (shared by every hull of one crew).
 * - Crew: the hull's current roster, and how many of them are dead.
 */

/// Ships that left the round before it ended, remembered when their hull detached.
GLOBAL_LIST_EMPTY(roundend_departed_ships)

/// Longest ship name shown before it is cut with "...".
#define ROUNDEND_SHIP_NAME_MAX 40

/obj/structure/overmap/ship
	/// Missions this ship turned in this round, for the round-end report.
	var/roundend_missions_done = 0
	/// TRUE once this hull has been written into GLOB.roundend_departed_ships.
	var/roundend_departure_noted = FALSE

/// One row of the round-end ship table. Everything is copied out of the ship when it is made.
/datum/roundend_ship_entry
	/// Ship name, already cut to length and HTML-encoded.
	var/name
	/// Hull class name, HTML-encoded.
	var/ship_class
	/// One or two words on how the ship ended the round.
	var/status
	/// TRUE when the status should show as a loss.
	var/bad_status = FALSE
	var/funds = 0
	/// Researched nodes, or null without a research server.
	var/research
	var/missions = 0
	/// Crew reputation, or null without a crew.
	var/reputation
	var/crew = 0
	var/dead = 0

/datum/roundend_ship_entry/New(obj/structure/overmap/ship/ship, departing = FALSE)
	. = ..()
	var/raw_name = "[ship.name]"
	if(length_char(raw_name) > ROUNDEND_SHIP_NAME_MAX)
		raw_name = "[copytext_char(raw_name, 1, ROUNDEND_SHIP_NAME_MAX)]..."
	name = html_encode(raw_name)
	var/datum/map_template/shuttle/voidcrew/template = ship.source_template
	ship_class = html_encode(template?.short_name || template?.name || "")
	funds = ship.ship_account ? round(ship.ship_account.account_balance) : 0
	research = roundend_ship_research(ship)
	missions = ship.roundend_missions_done
	var/datum/voidcrew_crew_record/record = ship.ship_team?.crew_record
	if(!QDELETED(record))
		reputation = record.reputation
	for(var/datum/mind/member as anything in ship.ship_team?.members)
		crew++
		var/mob/body = member.current
		// A departing hull deletes the bodies still aboard before it detaches; those are not deaths.
		if(body ? body.stat == DEAD : !departing)
			dead++
	if(departing)
		switch(ship.metric_removal_reason)
			if("bluespace_jump")
				status = "Jumped out"
			else
				status = ship.abandoned ? "Abandoned" : "Lost"
				bad_status = TRUE
	else if(ship.has_crash_landed)
		status = "Wrecked"
		bad_status = TRUE
	else if(ship.abandoned)
		status = "Abandoned"
		bad_status = TRUE
	else
		status = "Afloat"

/// Researched nodes on the ship's own research server, starting nodes left out. Null without one.
/proc/roundend_ship_research(obj/structure/overmap/ship/ship)
	var/datum/techweb/web
	if(ship.shuttle)
		for(var/obj/machinery/rnd/server/ship/server as anything in GLOB.ship_research_servers)
			if(QDELETED(server) || !server.stored_research)
				continue
			var/area/server_area = get_area(server)
			if(server_area && (server_area in ship.shuttle.shuttle_areas))
				web = server.stored_research
				break
		web ||= ship.find_research_web()
	if(!web)
		return null
	var/count = 0
	for(var/node_id in web.researched_nodes)
		var/datum/techweb_node/node = SSresearch.techweb_nodes[node_id]
		if(node && !node.starting_node)
			count++
	return count

/// TRUE for a hull that belongs in the report: a player ship somebody crewed.
/proc/roundend_ship_reportable(obj/structure/overmap/ship/ship)
	if(QDELETED(ship))
		return FALSE
	if(istype(ship, /obj/structure/overmap/ship/npc))
		var/obj/structure/overmap/ship/npc/npc_ship = ship
		if(!npc_ship.player_controlled)
			return FALSE
	return length(ship.manifest) || LAZYLEN(ship.ship_team?.members)

/// Called when a hull is about to leave the round (detach_shuttle()), while its crew and account still exist.
/proc/roundend_note_departed_ship(obj/structure/overmap/ship/ship)
	if(!ship || ship.roundend_departure_noted || !SSticker.IsRoundInProgress())
		return
	if(!roundend_ship_reportable(ship))
		return
	ship.roundend_departure_noted = TRUE
	GLOB.roundend_departed_ships += new /datum/roundend_ship_entry(ship, TRUE)

/// Whole number with thousands separators: 123456789 -> "123,456,789".
/proc/roundend_number(number)
	number = round(number)
	var/negative = number < 0
	var/digits = num2text(abs(number), 20)
	var/list/groups = list()
	while(length(digits) > 3)
		groups.Insert(1, copytext(digits, -3))
		digits = copytext(digits, 1, -3)
	groups.Insert(1, digits)
	return "[negative ? "-" : ""][jointext(groups, ",")]"

/proc/cmp_roundend_ship_funds(datum/roundend_ship_entry/a, datum/roundend_ship_entry/b)
	return b.funds - a.funds

/// The ship table. Ships still in the sector come first, richest first, then the ones that left.
/datum/controller/subsystem/ticker/proc/ship_crews_report()
	var/list/entries = list()
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(ship.roundend_departure_noted || !roundend_ship_reportable(ship))
			continue
		entries += new /datum/roundend_ship_entry(ship)
		CHECK_TICK
	sortTim(entries, GLOBAL_PROC_REF(cmp_roundend_ship_funds))
	entries += GLOB.roundend_departed_ships
	if(!length(entries))
		return null

	var/list/parts = list()
	parts += "<style>\
		.vc_ships {width: 100%; table-layout: fixed; border-collapse: collapse;}\
		.vc_ships th, .vc_ships td {white-space: nowrap; overflow: hidden; text-overflow: ellipsis; padding: 3px 6px; text-align: left;}\
		.vc_ships th {color: #add8e6; border-bottom: 1px solid #555;}\
		.vc_ships td {border-bottom: 1px solid #3c3c3c;}\
		.vc_ships .num {text-align: right;}\
		.vc_ships .class {color: #9a9a9a; font-size: 90%;}\
		.vc_ships .gone {color: #9a9a9a;}\
		</style>"
	parts += "<div class='panel stationborder'><span class='header'>Ships</span><br>"
	parts += "<table class='vc_ships'><colgroup>\
		<col style='width: 27%'><col style='width: 12%'><col style='width: 17%'>\
		<col style='width: 10%'><col style='width: 10%'><col style='width: 13%'><col style='width: 11%'></colgroup>"
	parts += "<tr><th>Ship</th><th>Status</th><th class='num'>Funds</th><th class='num'>Research</th>\
		<th class='num'>Missions</th><th class='num'>Reputation</th><th class='num'>Crew</th></tr>"
	for(var/datum/roundend_ship_entry/entry as anything in entries)
		var/status_text = entry.bad_status ? span_redtext(entry.status) : (entry.status == "Afloat" ? span_greentext(entry.status) : "<span class='gone'>[entry.status]</span>")
		var/crew_text = entry.dead ? "[entry.crew] ([entry.dead] dead)" : "[entry.crew]"
		parts += "<tr><td title=\"[entry.name]\"><b>[entry.name]</b><br><span class='class'>[entry.ship_class]</span></td>\
			<td>[status_text]</td>\
			<td class='num'>[roundend_number(entry.funds)] cr</td>\
			<td class='num'>[isnull(entry.research) ? "-" : roundend_number(entry.research)]</td>\
			<td class='num'>[roundend_number(entry.missions)]</td>\
			<td class='num'>[isnull(entry.reputation) ? "-" : roundend_number(entry.reputation)]</td>\
			<td class='num'>[crew_text]</td></tr>"
	parts += "</table></div>"
	return parts.Join()

// tg's report minus the station goals and the station economy, with the ship table first.
/datum/controller/subsystem/ticker/build_roundend_report()
	var/list/parts = list()

	parts += ship_crews_report()

	CHECK_TICK

	//AI laws
	parts += law_report()

	CHECK_TICK

	//Antagonists
	parts += antag_report()

	parts += hardcore_random_report()

	CHECK_TICK
	//Medals
	parts += medal_report()
	//Player Achievements
	parts += cheevo_report()

	list_clear_nulls(parts)

	return parts.Join()

// tg's survivor report without station integrity, the evacuation or the shuttle.
/datum/controller/subsystem/ticker/survivor_report(popcount)
	var/list/parts = list()

	if(GLOB.round_id)
		var/statspage = CONFIG_GET(string/roundstatsurl)
		var/info = statspage ? "<a href='byond://?action=openLink&link=[url_encode(statspage)][GLOB.round_id]'>[GLOB.round_id]</a>" : GLOB.round_id
		parts += "[FOURSPACES]Round ID: <b>[info]</b>"
	parts += "[FOURSPACES]Round Duration: <B>[DisplayTimeText(world.time - SSticker.round_start_time)]</B>"
	var/total_players = GLOB.joined_player_list.len
	if(total_players)
		parts += "[FOURSPACES]Total Population: <B>[total_players]</B>"
		parts += "[FOURSPACES]Survival Rate: <B>[popcount[POPCOUNT_SURVIVORS]] ([PERCENT(popcount[POPCOUNT_SURVIVORS]/total_players)]%)</B>"
		if(SSblackbox.first_death)
			var/list/ded = SSblackbox.first_death
			if(ded.len)
				parts += "[FOURSPACES]First Death: <b>[ded["name"]], [ded["role"]], at [ded["area"]]. Damage taken: [ded["damage"]].[ded["last_words"] ? " Their last words were: \"[ded["last_words"]]\"" : ""]</b>"
			//ignore this comment, it fixes the broken sytax parsing caused by the " above
			else
				parts += "[FOURSPACES]<i>Nobody died this round!</i>"

	parts += "[FOURSPACES]Round: [SSdynamic.current_tier.name]"
	for(var/datum/dynamic_ruleset/rule as anything in SSdynamic.executed_rulesets - SSdynamic.unreported_rulesets)
		parts += "[FOURSPACES][FOURSPACES]- <b>[rule.name]</b> ([rule.config_tag])"

	return parts.Join("<br>")

// "You survived" or "You died", with no station, shuttle or marooning.
/datum/controller/subsystem/ticker/personal_report(client/C, popcount)
	var/list/parts = list()
	var/mob/M = C.mob
	if(M.mind && !isnewplayer(M))
		if(M.stat != DEAD && !isbrain(M))
			parts += "<div class='panel greenborder'>"
			parts += span_greentext("You survived.")
		else
			parts += "<div class='panel redborder'>"
			parts += span_redtext("You died.")
	else
		parts += "<div class='panel stationborder'>"
	parts += "<br>"
	parts += GLOB.survivor_report
	parts += "</div>"

	return parts.Join()

#undef ROUNDEND_SHIP_NAME_MAX
