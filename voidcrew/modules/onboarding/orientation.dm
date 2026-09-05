/**
 * # Orientation Briefing
 *
 * The screen a player gets the first time they spawn into a round. It covers the
 * three things a new crew has no other way to find out: that the server is in an
 * early testing phase and where bugs go, what the overmap's three zone bands
 * actually permit, and that the gear which makes the deep bands survivable is
 * researched rather than bought.
 *
 * One tab each, and every tab kept short. This opens four seconds after spawn, on
 * top of a player who is still working out which way their ship faces, anything
 * longer than a screen gets closed unread.
 *
 * Shown once per client per round - a respawn twenty minutes later does not
 * re-open it - and available afterwards from the OOC tab, since the one time it
 * opens automatically is also the busiest moment of a player's round.
 *
 * The zone rows are built here rather than written into the TSX so that a change
 * to what a band permits is a change to one file, next to the defines that
 * enforce it. The advisory this screen sets up is enforced in the field by
 * zone_advisory.dm.
 */

/// Where bug reports go during the testing phase.
#define VOIDCREW_DISCORD_URL "https://discord.gg/6z9wQTYJmK"

/// The player wiki. Kept in step with WIKIURL in config/voidcrew/voidcrew_config.txt,
/// which is what the standard tg wiki verb reads.
#define VOIDCREW_WIKI_URL "https://wiki.voidcrew-lrp.com"

/// Gap between spawning and the briefing opening. Long enough that it lands
/// after the client has finished loading into its body rather than on top of the
/// spawn, short enough that it is still the first thing they read.
#define ORIENTATION_BRIEFING_DELAY (4 SECONDS)

/// Ckeys already shown the briefing this round.
GLOBAL_LIST_EMPTY(orientation_briefing_seen)

/// One datum for the whole server: it holds no per-player state, and TGUI keys
/// its windows on (user, datum) so any number of players can have it open.
GLOBAL_DATUM_INIT(orientation_briefing, /datum/orientation_briefing, new)

/datum/orientation_briefing

/datum/orientation_briefing/ui_state(mob/user)
	return GLOB.always_state

/datum/orientation_briefing/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OrientationBriefing")
		ui.open()

/datum/orientation_briefing/ui_data(mob/user)
	var/list/data = list()
	var/obj/structure/overmap/ship/ship = get_ship_from_atom(user)
	data["ship_name"] = ship?.name
	// Hard boolean rather than ship?.: a null here would read as "not
	// researched" in the UI anyway, and saying so plainly is what a ghost or
	// someone standing on a ruin should see.
	data["combat_researched"] = ship ? ship.has_ship_combat_research() : FALSE
	return data

/datum/orientation_briefing/ui_static_data(mob/user)
	var/list/data = list()

	data["zones"] = list(
		list(
			"name" = ZONE_NAME_GREEN,
			"color" = ZONE_COLOR_GREEN,
			"summary" = "The outer ring, where every ship starts. Weapons will not fire and nobody can board you.",
			"rules" = list(
				"No ship weapons, no boarding, no interdiction",
				"Nothing out here damages your ship or attacks your crew",
				"Lowest ore yields and contract pay",
			),
		),
		list(
			"name" = ZONE_NAME_YELLOW,
			"color" = ZONE_COLOR_YELLOW,
			"summary" = "The middle ring. Weapons still will not fire, but a crew can raid you.",
			"rules" = list(
				"No ship weapons",
				"Boarding and interdiction are allowed",
				"Player vs player requires escalation. Robbery is accepted, and combat is acceptable if they resist",
				"About 50% more ore, about 70% more contract pay",
			),
		),
		list(
			"name" = ZONE_NAME_RED,
			"color" = ZONE_COLOR_RED,
			"summary" = "The inner ring. Nothing is off limits. Your hull can be shot at, and the ships out here are equipped for it.",
			"rules" = list(
				"Ship weapons are live: you can be shot",
				"PLAYERS CAN KILL YOU FOR NOTHING",
				"Boarding and interdiction are allowed",
				"Double ore, about 160% more pay plus a trade voucher",
			),
		),
	)

	// Pulled off the live nodes so a rename in ship_combat/research.dm follows.
	var/list/research_path = list()
	for(var/node_id in list(TECHWEB_NODE_SHIP_COMBAT, TECHWEB_NODE_SHIP_COMBAT_SHIELDS, TECHWEB_NODE_SHIP_COMBAT_LASERS, TECHWEB_NODE_SHIP_COMBAT_MISSILES, TECHWEB_NODE_SHIP_COMBAT_INTERDICTOR))
		var/datum/techweb_node/node = SSresearch.techweb_node_by_id(node_id)
		if(!node)
			continue
		research_path += list(list(
			"name" = node.display_name,
			"desc" = node.description,
		))
	data["research_path"] = research_path

	return data

/datum/orientation_briefing/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	switch(action)
		if("open_discord")
			// Hands the link to the player's own browser; TGUI itself has no way
			// out to an external site.
			DIRECT_OUTPUT(ui.user, link(VOIDCREW_DISCORD_URL))
			return TRUE
		if("open_wiki")
			DIRECT_OUTPUT(ui.user, link(VOIDCREW_WIKI_URL))
			return TRUE

/**
 * Opens the briefing for a player who has not seen it yet this round.
 *
 * Called from the spawn path. The seen-list is marked immediately rather than
 * when the window opens, so a player who spawns, dies and respawns inside the
 * delay still only queues one.
 */
/proc/try_show_orientation_briefing(mob/user)
	if(!user?.client || !user.ckey)
		return
	if(user.ckey in GLOB.orientation_briefing_seen)
		return
	GLOB.orientation_briefing_seen += user.ckey
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(show_orientation_briefing), user), ORIENTATION_BRIEFING_DELAY)

/// Timer landing point for try_show_orientation_briefing().
/proc/show_orientation_briefing(mob/user)
	if(!user?.client)
		return
	GLOB.orientation_briefing.ui_interact(user)

/client/verb/orientation_briefing()
	set name = "Orientation Briefing"
	set category = "OOC"
	set desc = "Re-open the new player briefing: testing phase, zones, and ship combat gear."
	if(!mob)
		return
	GLOB.orientation_briefing.ui_interact(mob)

#undef ORIENTATION_BRIEFING_DELAY
#undef VOIDCREW_DISCORD_URL
#undef VOIDCREW_WIKI_URL
