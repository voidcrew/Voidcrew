/*
 * Monkestation gives Acetone Oxide and Hydrogen Peroxide effects when they are
 * actually metabolised, instead of only when splashed.
 *
 * Deliberately NOT ported: monkestation's expose_mob overrides for both of
 * these. This fork's upstream already implements them, and does it better -
 * ours scales the burn by touch_protection, so gloves and suits matter.
 * Monkestation's also has a precedence bug, `methods & TOUCH | VAPOR | INGEST`,
 * which parses as `(methods & TOUCH) | VAPOR | INGEST` and is therefore always
 * true, burning on every exposure method.
 */

/// Wrecks your stomach and eyes on the way through.
/datum/reagent/acetone_oxide/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	if(SPT_PROB(2.5, seconds_per_tick))
		to_chat(affected_mob, span_notice(pick(
			"You rub your eyes.",
			"Your eyes lose focus for a second.",
			"Your stomach cramps!",
		)))
	// REM RESTORATION: both were 2 * REM(0.5) * spt == 2 organ damage per 2s tick (1.0/s). REM is now 2.5,
	// which made them 5x. Default metabolization_rate (0.2) => metabolization_ratio == 1.0 at a normal 2s
	// tick, so the coefficient halves to 1: 1 * 1.0 * 2 == 2 per tick. Uncapped (no `maximum` arg).
	affected_mob.adjust_organ_loss(ORGAN_SLOT_STOMACH, 1 * metabolization_ratio * seconds_per_tick, required_organ_flag = affected_organ_flags)
	affected_mob.adjust_organ_loss(ORGAN_SLOT_EYES, 1 * metabolization_ratio * seconds_per_tick, required_organ_flag = affected_organ_flags)

/// The wimpier cousin - stomach only.
/datum/reagent/hydrogen_peroxide/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	if(SPT_PROB(2.5, seconds_per_tick))
		to_chat(affected_mob, span_notice(pick(
			"Your stomach rumbles.",
			"Your stomach is upset!",
			"You don't feel very good...",
		)))
	// REM RESTORATION: was 2 * REM(0.5) * spt == 2 stomach damage per 2s tick (1.0/s). Default
	// metabolization_rate (0.2) => metabolization_ratio == 1.0 at a normal 2s tick, so the coefficient
	// halves to 1: 1 * 1.0 * 2 == 2 per tick.
	affected_mob.adjust_organ_loss(ORGAN_SLOT_STOMACH, 1 * metabolization_ratio * seconds_per_tick, required_organ_flag = affected_organ_flags)

/// Spilled peroxide is slick. Upstream's expose_turf rusts plating; this runs
/// alongside it rather than replacing it.
/datum/reagent/hydrogen_peroxide/expose_turf(turf/exposed_turf, reac_volume)
	. = ..()
	var/turf/open/open_turf = exposed_turf
	if(!istype(open_turf))
		return
	if(reac_volume >= 5)
		open_turf.MakeSlippery(TURF_WET_WATER, 10 SECONDS, min(reac_volume * 1.5 SECONDS, 60 SECONDS))
