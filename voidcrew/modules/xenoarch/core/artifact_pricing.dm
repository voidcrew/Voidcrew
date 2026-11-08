/**
 * # Artifact pricing and research value
 *
 * One place that says what a large find is worth, so buyers, receipts, metrics and tests
 * all agree. Price = base by stamped band x main-effect tier x label share x condition.
 * Buyers only take finds stamped as dug; anything else is worth nothing to them.
 */

/// Credits a buyer pays for this artifact as it stands. 0 if it was never dug.
/proc/artifact_sale_value(obj/machinery/artifact/artifact)
	if(QDELETED(artifact) || !artifact.is_dug())
		return 0
	var/datum/artifact_effect/main = artifact.main_effect
	if(!main)
		return 0
	return xenoarch_price_for(artifact.origin_band, main.tier, artifact.label_accuracy(), artifact.damaged, artifact.harvests_taken())

/**
 * The pure price function behind artifact_sale_value().
 *
 * * band - stamped ZONE_*
 * * tier - ARTIFACT_TIER_* of the main effect
 * * accuracy - 0 to 1, from label_accuracy(); 0 for no label
 * * damaged - came out of the rock damaged
 * * harvests_taken - how many harvests were drained from it
 */
/proc/xenoarch_price_for(band, tier, accuracy, damaged = FALSE, harvests_taken = 0)
	var/list/base = ARTIFACT_PRICE_BASE
	var/list/tier_mult = ARTIFACT_PRICE_TIER_MULT
	var/value = base[XENOARCH_BAND_INDEX(band)] * tier_mult[clamp(tier, ARTIFACT_TIER_COMMON, ARTIFACT_TIER_EXTREME)]
	value *= xenoarch_label_share(accuracy)
	if(damaged)
		value *= ARTIFACT_DAMAGED_MULT
	if(harvests_taken > 0)
		value *= ARTIFACT_HARVEST_MULT ** harvests_taken
	return max(round(value, ARTIFACT_PRICE_ROUNDING), 0)

/// What share of full price a label of this accuracy earns.
/proc/xenoarch_label_share(accuracy)
	// A perfect label sums 0.5 + 0.3 + 0.2 in floating point; never let that read as 0.99999.
	accuracy = round(accuracy, 0.01)
	if(accuracy >= ARTIFACT_LABEL_ACCURACY_FLOOR)
		return min(accuracy, 1)
	return ARTIFACT_UNLABELLED_SHARE

/// Research points for the first full analysis of a large find.
/proc/xenoarch_research_points(band, tier)
	var/list/points = ARTIFACT_RESEARCH_POINTS
	. = points[XENOARCH_BAND_INDEX(band)]
	if(tier >= ARTIFACT_TIER_RARE)
		. *= ARTIFACT_RESEARCH_RARE_MULT
	return round(.)

/// Research points this artifact pays on its first full analysis, or 0 once paid or if it was never dug.
/proc/artifact_research_value(obj/machinery/artifact/artifact)
	if(QDELETED(artifact) || artifact.research_paid || !artifact.main_effect)
		return 0
	return xenoarch_research_points(artifact.origin_band, artifact.main_effect.tier)
