/**
 * # Outpost lockup: round metrics
 *
 * Helpers for trader-outpost lockup and bounty turn-in events in the `round_metric` SQL table. Every row
 * uses category `METRIC_LOCKUP` ("lockup", voidcrew/_DEFINES/metrics.dm). Low-volume events write one row
 * through `record_metric()`; per-tick time served and per-job time worked off aggregate through
 * `tally_metric()`. When round metrics are disabled or the database is absent, every helper returns after
 * checking `SSmetrics.accepting`.
 *
 * Event catalog:
 * * lockup_booked: a player inmate began a sentence in a lockup. `ckey` = inmate, `ship` = crew ship,
 *   `zone` = outpost band, `subject` = "<stars>_star", `points` = stars, `quantity` = total sentence seconds,
 *   `details` = list("outpost", "admin_booked").
 * * lockup_served: minute-bucketed tally of seconds served inside a lockup by a player inmate.
 *   `ckey` = inmate, `ship` = crew ship, `zone` = outpost band, `subject` = outpost name, `quantity` = seconds.
 * * lockup_worked_off: minute-bucketed tally of effective seconds knocked off a player inmate's sentence
 *   from prison jobs. `ckey` = inmate, `ship` = crew ship, `zone` = outpost band, `subject` = job kind,
 *   `quantity` = seconds.
 * * lockup_escape: a player inmate (`subject` = "inmate") or NPC prisoner (`subject` = "prisoner") escaped
 *   custody. `ckey` = inmate ckey (null for NPC prisoners), `zone` = outpost band, `quantity` = 1.
 * * lockup_break_in: a lockup cell or staff airlock was hacked, overridden or forced open while the wing
 *   held someone. `ckey` = hacker when known, `zone` = outpost band, `subject` = door typepath, `quantity` = 1.
 * * lockup_riot: a riot started in a lockup yard. `zone` = outpost band, `subject` = outpost name,
 *   `quantity` = joining rioters, `details` = list("outpost", "reason").
 * * bounty_claimed_live: a live bounty catch was handed in at a lockup Processing room (`lockup_claim()`).
 *   `ckey` = deliverer, `ship` = paid ship (if any), `zone` = outpost band, `subject` = tier label,
 *   `credits` = credits paid, `vouchers` = vouchers paid, `quantity` = 1.
 * * bounty_claimed_dead: a dead bounty catch or proof of death was turned in on a ship's mission pad
 *   (`board_claim()`). `ckey` = user pressing Turn In, `ship` = ship, `zone` = ship band, `subject` = tier label,
 *   `credits` = credits paid, `vouchers` = vouchers paid, `quantity` = 1.
 *
 * Trap: `record_metric()` and `tally_metric()` take named arguments; neither `METRIC_LOCKUP` nor any event
 * string above matches one of their parameter names.
 */

/// Zone string ("green", "yellow" or "red") for `prison`'s trader outpost, falling back to `fallback`
/proc/lockup_metric_zone(datum/outpost_prison/prison, atom/fallback = null)
	if(prison && !QDELETED(prison.outpost))
		var/outpost_zone = metric_zone(prison.outpost)
		if(outpost_zone)
			return outpost_zone
	if(prison && !QDELETED(prison.wing))
		for(var/turf/tile in prison.wing)
			return metric_zone(tile)
	return fallback ? metric_zone(fallback) : null

/// Tier label for bounty claim rows ("petty", "wanted", "most_wanted")
/proc/lockup_metric_bounty_tier(datum/criminal_bounty/posting)
	switch(posting?.record?.tier)
		if(BOUNTY_TIER_PETTY)
			return "petty"
		if(BOUNTY_TIER_WANTED)
			return "wanted"
		if(BOUNTY_TIER_MOST_WANTED)
			return "most_wanted"
	return "unknown"

/// Records a player inmate booking (`lockup_booked`)
/proc/record_lockup_booking(datum/outpost_prison/prison, mob/living/inmate, stars, total_seconds, admin_booked = FALSE)
	if(!SSmetrics.accepting || QDELETED(prison) || QDELETED(inmate))
		return
	var/place = prison.outpost_log_name()
	record_metric(
		METRIC_LOCKUP,
		"lockup_booked",
		zone = lockup_metric_zone(prison, inmate),
		subject = "[stars]_star",
		points = stars,
		quantity = round(total_seconds),
		details = list("outpost" = place, "admin_booked" = !!admin_booked),
		actor = inmate,
	)

/// Tallies seconds served by a player inmate (`lockup_served`)
/proc/tally_lockup_served(datum/outpost_prison/prison, mob/living/inmate, seconds)
	if(!SSmetrics.accepting || seconds <= 0 || QDELETED(prison) || QDELETED(inmate))
		return
	tally_metric(
		METRIC_LOCKUP,
		"lockup_served",
		ckey = metric_ckey(inmate),
		ship = ismob(inmate) ? metric_crew_ship(inmate) : null,
		zone = lockup_metric_zone(prison, inmate),
		subject = prison.outpost_log_name(),
		quantity = round(seconds),
	)

/// Tallies effective seconds worked off by a player inmate (`lockup_worked_off`)
/proc/tally_lockup_worked_off(datum/outpost_prison/prison, mob/living/inmate, kind, seconds)
	if(!SSmetrics.accepting || seconds <= 0 || QDELETED(prison) || QDELETED(inmate))
		return
	tally_metric(
		METRIC_LOCKUP,
		"lockup_worked_off",
		ckey = metric_ckey(inmate),
		ship = ismob(inmate) ? metric_crew_ship(inmate) : null,
		zone = lockup_metric_zone(prison, inmate),
		subject = "[kind]",
		quantity = round(seconds),
	)

/// Records a lockup escape (`lockup_escape`, `kind` = "inmate" or "prisoner")
/proc/record_lockup_escape(datum/outpost_prison/prison, mob/living/escapee, kind)
	if(!SSmetrics.accepting || QDELETED(prison))
		return
	var/place = prison.outpost_log_name()
	var/is_npc = is_outpost_prisoner(escapee)
	record_metric(
		METRIC_LOCKUP,
		"lockup_escape",
		zone = lockup_metric_zone(prison, escapee),
		subject = "[kind]",
		quantity = 1,
		details = list("outpost" = place, "name" = escapee?.real_name),
		actor = is_npc ? null : escapee,
	)

/// Records a hacked, overridden or forced lockup door (`lockup_break_in`)
/proc/record_lockup_break_in(datum/outpost_prison/prison, obj/machinery/door/airlock/door, mob/living/hacker)
	if(!SSmetrics.accepting || QDELETED(prison) || QDELETED(door))
		return
	var/is_npc = hacker && is_outpost_prisoner(hacker)
	record_metric(
		METRIC_LOCKUP,
		"lockup_break_in",
		zone = lockup_metric_zone(prison, door),
		subject = "[door.type]",
		quantity = 1,
		details = list("outpost" = prison.outpost_log_name(), "door" = door.name),
		actor = is_npc ? null : hacker,
	)

/// Records a lockup riot (`lockup_riot`)
/proc/record_lockup_riot(datum/outpost_prison/prison, reason, rioter_count)
	if(!SSmetrics.accepting || QDELETED(prison))
		return
	var/place = prison.outpost_log_name()
	record_metric(
		METRIC_LOCKUP,
		"lockup_riot",
		zone = lockup_metric_zone(prison),
		subject = place,
		quantity = rioter_count,
		details = list("outpost" = place, "reason" = reason),
	)

/// Records a live lockup bounty hand-in or dead ship-pad bounty turn-in (`bounty_claimed_live` / `bounty_claimed_dead`)
/proc/record_lockup_bounty_claim(datum/criminal_bounty/posting, live, mob/user, obj/structure/overmap/ship/paying_ship, atom/where, credits_paid, vouchers_paid, datum/outpost_prison/prison = null)
	if(!SSmetrics.accepting || QDELETED(posting))
		return
	var/resolved_zone = prison ? lockup_metric_zone(prison, where) : (where ? metric_zone(where) : (paying_ship ? metric_zone(paying_ship) : null))
	var/list/extra = list(
		"record_id" = posting.record?.id,
		"wanted" = posting.record?.name,
	)
	if(prison)
		extra["outpost"] = prison.outpost_log_name()
	record_metric(
		METRIC_LOCKUP,
		live ? "bounty_claimed_live" : "bounty_claimed_dead",
		ship = paying_ship,
		zone = resolved_zone,
		subject = lockup_metric_bounty_tier(posting),
		credits = credits_paid,
		vouchers = vouchers_paid,
		quantity = 1,
		details = extra,
		actor = user,
	)
