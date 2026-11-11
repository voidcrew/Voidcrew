/**
 * # Xenoarchaeology research
 *
 * Large finds: the first full analysis of a dug find pays research once, whichever crew runs it.
 * The flag lives on the find (research_paid), so passing one find between crews pays nothing
 * more. The points come out of the analyser as research notes, which any R&D console takes, so
 * no machine here needs a techweb link.
 *
 * Small finds: each curio type pays once per techweb through the destructive analyzer, by tg's
 * own techweb_point_items table (subtypes count as their nearest listed type).
 */

/**
 * Claims the research for analysing `find`, once per find. Marks it paid and logs the metric;
 * the caller prints the notes. Returns the points, or 0 if it was never dug or already paid.
 */
/proc/xenoarch_claim_analysis(obj/machinery/artifact/find, atom/analyser, mob/user)
	if(QDELETED(find) || !find.is_dug())
		return 0
	var/points = artifact_research_value(find)
	if(points <= 0)
		return 0
	find.research_paid = TRUE
	record_metric(
		category = METRIC_RESEARCH,
		event = XENOARCH_METRIC_ANALYSED,
		subject = "[find.main_effect?.type]",
		points = points,
		zone = xenoarch_band_name(find.origin_band),
		details = list("serial" = find.serial, "tier" = find.main_effect?.tier),
		actor = user,
		location = analyser,
	)
	return points

/// Prints claimed analysis research as notes at `where`.
/proc/xenoarch_print_analysis_notes(atom/where, points)
	if(!where || points <= 0)
		return null
	return new /obj/item/research_notes(where, points, "xenoarchaeology")

/**
 * Research the destructive analyzer pays once per techweb for each kind of small find.
 * Points sit between 20 and 60, under the cheapest research node, so a full set of curios is a
 * pleasant extra rather than a research route.
 */
GLOBAL_LIST_INIT(xenoarch_curio_research_points, list(
	/obj/item/xenoarch_curio/shell = 20,
	/obj/item/xenoarch_curio/plant_fossil = 25,
	/obj/item/xenoarch_curio/bone = 25,
	/obj/item/xenoarch_curio/bowl = 25,
	/obj/item/xenoarch_curio/skull = 30,
	/obj/item/xenoarch_curio/urn = 30,
	/obj/item/xenoarch_curio/scrap = 30,
	/obj/item/xenoarch_curio/sidearm = 35,
	/obj/item/xenoarch_curio/seed_pod = 40,
	/obj/item/xenoarch_curio/statuette = 45,
	/obj/item/xenoarch_curio/instrument = 45,
	/obj/item/xenoarch_curio/idol = 50,
	/obj/item/xenoarch_curio/skeleton = 60,
	// The strange object a site gives up is tg's relic. Only a dug one pays: maintenance relics and
	// experimentor copies are the plain type.
	/obj/item/relic/excavated = 60,
))

/// Adds the curio table to tg's destructive-analyzer payouts.
/proc/xenoarch_register_curio_research()
	for(var/curio_type in GLOB.xenoarch_curio_research_points)
		if(SSresearch.techweb_point_items[curio_type])
			continue
		SSresearch.techweb_point_items[curio_type] = list(TECHWEB_POINT_TYPE_GENERIC = GLOB.xenoarch_curio_research_points[curio_type])

/datum/controller/subsystem/research/Initialize()
	. = ..()
	xenoarch_register_curio_research()
