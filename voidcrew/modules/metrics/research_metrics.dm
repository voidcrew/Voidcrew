// Round metrics for research: points gained by source, and nodes researched or copied.
// See voidcrew/modules/metrics/metrics_helpers.dm for record_metric() and tally_metric().
//
// Every row here is category METRIC_RESEARCH, and `points` is always General Research points.
// When a row concerns a techweb, the ship is the one whose R&D server hosts that web; outpost
// webs have no ship, and the row falls back to the player's own crew ship. details.web is the
// web's id (the server disk's name), which tells a ship web from an outpost web.
//
// HOW POINTS MOVE. Most sources don't feed a techweb directly: they print research notes, and
// the points only reach a web when someone slots the notes into an R&D console
// (notes_redeemed, whose subject is the notes' origin). So there are two kinds of row:
//   - Straight into a web: experiment_completed, destructive_analysis, notes_redeemed.
//   - Notes or banked points, not in a web yet: survey_completed, survey_notes_printed,
//     scanner_scan, scanner_notes_printed, dissection, points_stolen, and mission rewards
//     (mission_completed in mission_metrics.dm).
// Sum the first kind for what webs actually gained. Adding the second kind counts the same
// points again. Notes found as ruin loot only ever show up as notes_redeemed.
//
// EVENT CATALOG
//
// node_researched - a node was bought with points: at an R&D console, from a Science Hub
//     program, or by the research queue. Forced unlocks (roundstart nodes, disk copies,
//     admin) are not recorded here. Hook: the voidcrew /datum/techweb/research_node().
//     ckey: the player who clicked, or who queued the node. subject: node id. points: its
//     price. zone: the console's. details: via ("console", "program" or "queue"), tier,
//     nodes (nodes the web holds now, starting nodes included), web.
// tech_disk_uploaded - a technology disk was uploaded into a web at an R&D console, which
//     unlocks every node on the disk for free. One row per upload. ckey, ship (the web's).
//     quantity: nodes gained. details: nodes (list of node ids), web.
// tech_disk_saved - a web was copied onto a technology disk. Same columns; quantity and
//     nodes are what the disk gained.
// source_disk_installed - an R&D source disk went into a ship server, bringing its whole web.
//     ckey, ship (the server's). quantity: nodes on the web beyond the starting set. points:
//     points it holds. details: web, foreign (the disk was first installed on a different
//     ship this round), home_ship (that ship's name).
// points_stolen - a player siphoned points out of a ship server into notes. ckey: the thief.
//     ship: the thief's crew ship. points: taken. details: web, victim_ship, victim_ship_id.
// notes_redeemed - research notes slotted into an R&D console. ckey, ship (the web's).
//     subject: the notes' origin ("survey results", "biology", "thievery", "xenofauna",
//     "exotic particle physics"...). points: their value. details: web, mixed (notes of
//     several origins merged for a bonus).
// experiment_completed - an experiment finished on a web, from a scanner, a machine or a
//     published paper. subject: experiment typepath. points: everything the web gained for it
//     (flat pay, experiment reward and any skipped-experiment refund). ckey: whoever held the
//     scanner, or the player whose action finished it when they are standing at it.
//     details: web.
// destructive_analysis - the destructive analyzer broke an item down for points. Rows only
//     when points were gained. ckey, ship (the web's). subject: the loaded item's typepath.
//     points. details: web.
// dissection - an experimental dissection finished and wrote notes. ckey: the surgeon.
//     subject: the body's typepath. points: the notes' value. details: tier_value (the
//     surgery tier's base value, 100/200/400/600).
// scanner_scan (tally) - a survey scanner machine's scans. ckey and ship: the player who
//     switched it on, and their crew ship. zone: where it was switched on. quantity: scans.
//     points: points generated (each scan rounded).
// scanner_notes_printed - a player took a survey scanner's points out as notes. ckey.
//     points: the notes' value.
// survey_completed - the orbital survey console finished surveying a celestial object and
//     banked its payout on the console. ckey: the player who started the survey. ship: the
//     console's. zone: the object's. subject: the object's typepath. credits: cash banked
//     (not in any account yet; see survey_cash_out). points: points banked. details: first
//     (first survey of that object this round), at_range (storm scanned from a nearby tile),
//     tier (the console's best survey upgrade).
// survey_notes_printed - banked survey points printed as notes. ckey, ship. points.
// survey_cash_out - banked survey cash printed as bills. ckey, ship. credits: the cash.

/datum/techweb
	/// metric_ship_id() of the first ship whose server this web's disk went into this round
	var/metric_home_ship_id
	/// That ship's name at the time
	var/metric_home_ship_name

/obj/machinery/computer/camera_advanced/shuttle_docker/survey
	/// ckey of the player who started the survey in progress
	var/metric_surveyor_ckey

/obj/machinery/survey_scanner
	/// ckey of the player who last switched the scanner on
	var/metric_operator_ckey
	/// That player's crew ship
	var/datum/weakref/metric_operator_ship
	/// Zone the scanner was switched on in; it can't be unbolted while it runs
	var/metric_scan_zone

/// General Research points a techweb holds.
/proc/metric_web_points(datum/techweb/web)
	if(!web)
		return 0
	return web.research_points[TECHWEB_POINT_TYPE_GENERIC] || 0

/// The ship whose R&D server hosts a techweb, or null for outpost webs and webs with no server.
/proc/metric_techweb_ship(datum/techweb/web)
	for(var/obj/machinery/rnd/server/server as anything in web?.techweb_servers)
		var/obj/structure/overmap/ship/ship = get_ship_from_atom(server)
		if(ship)
			return ship
	return null

/**
 * The player to credit for something `source` just did: whoever is holding it, or else the
 * player whose action is running this proc chain, as long as they are standing at it. The
 * range check keeps a stray usr (a signal fired by something else) from being credited.
 */
/proc/metric_research_operator(atom/source)
	if(ismovable(source))
		var/atom/movable/thing = source
		if(ismob(thing.loc))
			return thing.loc
	if(ismob(usr) && source && get_dist(usr, source) <= 1)
		return usr
	return null

// ===== NODES =====

/// Who queued a node for automatic research, read before research_node() takes it off the queue.
/datum/techweb/proc/metric_node_queued_by(datum/techweb_node/node)
	if(!istype(node))
		return null
	var/mob/queued_by = research_queue_nodes[node.id]
	return ismob(queued_by) ? queued_by : null

/**
 * node_researched. Called from research_node() after a paid (not forced) unlock succeeds.
 * The console and the Science Hub run inside a player's UI action, so usr is the researcher;
 * the research queue runs from SSresearch with no usr, so the player who queued it is used.
 */
/datum/techweb/proc/record_node_researched(datum/techweb_node/node, atom/research_source, mob/queued_by)
	if(!SSmetrics.accepting || !istype(node))
		return
	var/mob/researcher = ismob(usr) ? usr : queued_by
	var/via = research_source ? "console" : (ismob(usr) ? "program" : "queue")
	// research_node() doesn't complete experiments, so the price now is the price just paid
	var/list/price = node.get_price(src)
	var/list/details = list(
		"via" = via,
		"tier" = tiers[node.id],
		"nodes" = length(researched_nodes),
		"web" = id,
	)
	record_metric(METRIC_RESEARCH, "node_researched", ship = metric_techweb_ship(src), subject = node.id, points = price[TECHWEB_POINT_TYPE_GENERIC], details = details, actor = researcher, location = research_source)

/// The web a tech-disk action is about to add nodes to, and what it holds now, or null if the
/// action isn't one. Read before the R&D console's ui_act() runs the copy.
/obj/machinery/computer/rdconsole/proc/metric_tech_disk_before(action, list/params)
	if(!SSmetrics.accepting || !stored_research || !t_disk?.stored_research)
		return null
	if(action == "uploadDisk" && params["type"] == "tech")
		return stored_research.researched_nodes.Copy()
	if(action == "loadTech")
		return t_disk.stored_research.researched_nodes.Copy()
	return null

/// tech_disk_uploaded or tech_disk_saved: one summary row for the whole copy. Nothing if the
/// copy was refused (busy, no disk) or brought nothing new.
/obj/machinery/computer/rdconsole/proc/record_tech_disk_copy(action, list/nodes_before)
	if(isnull(nodes_before) || !SSmetrics.accepting)
		return
	var/uploading = (action != "loadTech")
	var/datum/techweb/receiver = uploading ? stored_research : t_disk?.stored_research
	if(!receiver)
		return
	var/list/gained = list()
	for(var/node_id in receiver.researched_nodes)
		if(!nodes_before[node_id])
			gained += node_id
	if(!length(gained))
		return
	record_metric(METRIC_RESEARCH, uploading ? "tech_disk_uploaded" : "tech_disk_saved", ship = metric_techweb_ship(stored_research), quantity = length(gained), details = list("nodes" = gained, "web" = stored_research?.id), actor = usr, location = src)

/// source_disk_installed. Called once the server has taken the disk's web.
/obj/machinery/rnd/server/ship/proc/record_source_disk_installed(mob/user)
	if(!SSmetrics.accepting || !stored_research)
		return
	var/datum/techweb/web = stored_research
	var/obj/structure/overmap/ship/ship = get_ship_from_atom(src)
	var/list/details = list("web" = web.id)
	if(ship)
		var/ship_id = metric_ship_id(ship)
		if(isnull(web.metric_home_ship_id))
			web.metric_home_ship_id = ship_id
			web.metric_home_ship_name = ship.name
		else if(web.metric_home_ship_id != ship_id)
			details["foreign"] = TRUE
			details["home_ship"] = web.metric_home_ship_name
	var/nodes = max(length(web.researched_nodes) - length(SSresearch.techweb_nodes_starting), 0)
	record_metric(METRIC_RESEARCH, "source_disk_installed", ship = ship, quantity = nodes, points = metric_web_points(web), details = details, actor = user, location = src)

// ===== POINTS =====

/// points_stolen. Called once the siphoned points are in the thief's notes.
/obj/machinery/rnd/server/ship/proc/record_research_stolen(mob/thief, stolen)
	if(!SSmetrics.accepting || stolen <= 0)
		return
	var/obj/structure/overmap/ship/victim = get_ship_from_atom(src)
	var/list/details = list("web" = source_code_hdd?.stored_research?.id)
	if(victim)
		details["victim_ship"] = victim.name
		details["victim_ship_id"] = metric_ship_id(victim)
	record_metric(METRIC_RESEARCH, "points_stolen", points = stolen, details = details, actor = thief, location = src)

/// notes_redeemed. Called once the notes' points are in the console's web.
/obj/machinery/computer/rdconsole/proc/record_notes_redeemed(obj/item/research_notes/notes, mob/user)
	if(!SSmetrics.accepting || !notes)
		return
	var/list/details = list("web" = stored_research?.id)
	if(notes.mixed)
		details["mixed"] = TRUE
	record_metric(METRIC_RESEARCH, "notes_redeemed", ship = metric_techweb_ship(stored_research), subject = notes.origin_type, points = notes.value, details = details, actor = user, location = src)

/**
 * experiment_completed. `points` is what the web gained, measured around the completion, so
 * it covers the flat experiment pay in voidcrew/modules/research/edits/_experiments.dm, the
 * experiment's own reward and any refund for a skipped discount experiment. `source` is the
 * scanner or machine that finished it; published papers have none, and credit usr.
 */
/proc/record_experiment_completed(datum/techweb/web, experiment_type, points, atom/source)
	if(!SSmetrics.accepting || !web)
		return
	var/mob/credited = source ? metric_research_operator(source) : (ismob(usr) ? usr : null)
	record_metric(METRIC_RESEARCH, "experiment_completed", ship = metric_techweb_ship(web), subject = experiment_type, points = points, details = list("web" = web.id), actor = credited, location = source)

/**
 * destructive_analysis. Wraps the upstream proc rather than editing it: the points are the
 * web's gain across the whole breakdown, which covers everything inside the loaded item too.
 * Both callers are in the analyzer's ui_act(), so usr is the player at the machine.
 */
/obj/machinery/rnd/destructive_analyzer/destroy_item(gain_research_points = FALSE)
	var/item_type = loaded_item?.type
	var/datum/techweb/web = stored_research
	var/points_before = metric_web_points(web)
	. = ..()
	if(.)
		record_metric_analysis(web, item_type, metric_web_points(web) - points_before)

/obj/machinery/rnd/destructive_analyzer/proc/record_metric_analysis(datum/techweb/web, item_type, points)
	if(!SSmetrics.accepting || points <= 0)
		return
	record_metric(METRIC_RESEARCH, "destructive_analysis", ship = metric_techweb_ship(web), subject = item_type, points = points, details = list("web" = web?.id), actor = ismob(usr) ? usr : null, location = src)

/**
 * dissection. Wraps the upstream step rather than editing it. The body's
 * dissection_points_paid (voidcrew/modules/surgery/experimental_dissection.dm) grows by exactly
 * what the notes are worth, so its change is the payout.
 */
/datum/surgery_step/experimental_dissection/success(mob/user, mob/living/target, target_zone, obj/item/tool, datum/surgery/surgery, default_display_results = FALSE)
	var/paid_before = target.dissection_points_paid
	. = ..()
	record_metric_dissection(user, target, target.dissection_points_paid - paid_before)

/datum/surgery_step/experimental_dissection/proc/record_metric_dissection(mob/user, mob/living/target, points)
	if(!SSmetrics.accepting || points <= 0)
		return
	record_metric(METRIC_RESEARCH, "dissection", subject = target.type, points = points, details = list("tier_value" = base_value), actor = user)

// ===== SURVEY SCANNER MACHINE =====

/// Remembers who switched the scanner on, and where, for its scan tallies.
/obj/machinery/survey_scanner/proc/note_metric_operator()
	if(!SSmetrics.accepting)
		return
	metric_operator_ckey = metric_acting_ckey()
	var/obj/structure/overmap/ship/ship = ismob(usr) ? metric_crew_ship(usr) : null
	metric_operator_ship = ship ? WEAKREF(ship) : null
	metric_scan_zone = metric_zone(src)

/// scanner_scan. Every 10 seconds per running scanner, so it is a tally.
/obj/machinery/survey_scanner/proc/tally_metric_scan(gain)
	if(!SSmetrics.accepting)
		return
	tally_metric(METRIC_RESEARCH, "scanner_scan", ckey = metric_operator_ckey, ship = metric_operator_ship?.resolve(), zone = metric_scan_zone, points = round(gain))

/// scanner_notes_printed.
/obj/machinery/survey_scanner/proc/record_metric_notes(mob/user, points)
	if(!SSmetrics.accepting || points <= 0)
		return
	record_metric(METRIC_RESEARCH, "scanner_notes_printed", points = points, actor = user, location = src)

// ===== ORBITAL SURVEY CONSOLE =====

/// survey_completed. Called after the payout is banked and before the object is marked surveyed.
/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/record_metric_survey(obj/structure/overmap/object, list/values)
	if(!SSmetrics.accepting || !object || !values)
		return
	var/points = values["points"]
	var/cash = values["cash"]
	if(!points && !cash)
		return
	var/list/details = list()
	if(!object.surveyed)
		details["first"] = TRUE
	if(is_survey_at_range(object))
		details["at_range"] = TRUE
	for(var/tier in list("elite", "superior", "advanced"))
		if(tier in survey_research_tiers)
			details["tier"] = tier
			break
	record_metric(METRIC_RESEARCH, "survey_completed", ckey = metric_surveyor_ckey, ship = ship_port?.current_ship, zone = metric_overmap_tile_zone(object), subject = object.type, credits = cash, points = points, details = details)

/// survey_notes_printed.
/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/record_metric_notes_printed(mob/user, points)
	if(!SSmetrics.accepting || points <= 0)
		return
	record_metric(METRIC_RESEARCH, "survey_notes_printed", ship = ship_port?.current_ship, points = points, actor = user, location = src)

/// survey_cash_out. Bills are only printed in whole credits.
/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/record_metric_cash_out(mob/user, amount)
	amount = FLOOR(amount, 1)
	if(!SSmetrics.accepting || amount <= 0)
		return
	record_metric(METRIC_RESEARCH, "survey_cash_out", ship = ship_port?.current_ship, credits = amount, actor = user, location = src)
