// Tutorial checklist hooks. Part A: the Zones item (entering yellow and red space,
// researching Shuttle Warfare Systems). Overrides chain with any others of the same proc.

/// The crossing timer lands here once the ship is actually over the line.
/obj/structure/overmap/ship/complete_zone_transition()
	. = ..()
	if(QDELETED(src) || istype(src, /obj/structure/overmap/ship/npc) || !SSovermap_zones?.initialized)
		return
	var/zone_type = SSovermap_zones.get_zone_type(get_turf(src))
	if(zone_type == ZONE_YELLOW || zone_type == ZONE_RED)
		tutorial_credit_crew(src, TUTORIAL_STEP_ZONES_YELLOW, aboard_only = TRUE)
	if(zone_type == ZONE_RED)
		tutorial_credit_crew(src, TUTORIAL_STEP_ZONES_RED, aboard_only = TRUE)

/datum/techweb/research_node(datum/techweb_node/node, force = FALSE, auto_adjust_cost = TRUE, get_that_dosh = TRUE, atom/research_source)
	. = ..()
	if(!. || !istype(node) || node.id != TECHWEB_NODE_SHIP_COMBAT)
		return
	var/obj/structure/overmap/ship/ship = metric_techweb_ship(src)
	if(ship)
		tutorial_credit_crew(ship, TUTORIAL_STEP_ZONES_WARFARE)
