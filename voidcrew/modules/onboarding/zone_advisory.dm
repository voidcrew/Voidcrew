/**
 * # Zone Advisory
 *
 * The in-world half of new-crew orientation: warnings aimed at a ship that is
 * about to fly somewhere its research cannot protect it.
 *
 * The zone bands are the sharpest difficulty step in the round and the least
 * signposted one. Nothing stops a fresh hull from thrusting straight out of the
 * Neutral band, and once it is in Contested space another crew may interdict it,
 * force a dock and board it - with no shields, no turrets and no weapons console
 * to answer with, because all three sit behind a single research node the crew
 * has probably not looked at yet.
 *
 * So the advisory fires on the one action that commits them: the zone
 * transition. It runs for ten seconds, it can be cancelled from the helm, and
 * that is the window this warning is written for. The helm keeps a standing
 * version of the same warning on its alert rail for as long as the ship is out
 * of its depth (see /obj/structure/overmap/ship/proc/zone_advisory_state).
 *
 * The gate is Shuttle Warfare Systems research, not built hardware - see
 * has_ship_combat_research() in ship_combat/research.dm.
 */

/// Gap between spoken zone advisories, so bouncing across a border doesn't spam
/// the crew's chat. Long enough to cover a cancel-and-retry, short enough that
/// the next border they reach warns them again.
#define ZONE_ADVISORY_COOLDOWN (2 MINUTES)

/obj/structure/overmap/ship
	COOLDOWN_DECLARE(zone_advisory_cooldown)
	/// Band the last spoken advisory was about, so the cooldown only silences a
	/// repeat of the same warning.
	var/zone_advisory_last_band

/**
 * The standing advisory for the helm's alert rail: is this ship somewhere its
 * research cannot cover, and how badly.
 *
 * Returns null when there is nothing to say, or list("label", "critical") ready
 * for the UI. The label is built here rather than in TGUI so the wording and the
 * band names stay in one place. Crossing counts as being there: the rail is most
 * useful while the transition can still be cancelled.
 */
/obj/structure/overmap/ship/proc/zone_advisory_state()
	if(!SSovermap_zones?.zones_active)
		return null
	var/datum/overmap_zone/zone = SSovermap_zones.get_zone(zone_transitioning ? zone_transition_target : get_turf(src))
	if(!zone || zone.zone_type == ZONE_GREEN)
		return null
	if(has_ship_combat_research())
		return null
	var/lawless = zone.zone_type == ZONE_RED
	var/consequence = lawless ? "ship weapons are live here" : "boarding is permitted here"
	return list(
		"label" = "[zone.name]: [consequence], and this hull has no warfare research",
		"critical" = lawless,
	)

/**
 * Tells the crew, at the moment they commit to crossing a border, what the band
 * on the far side allows and what they have not researched to meet it.
 *
 * Called from start_zone_transition() with the zone being entered.
 */
/obj/structure/overmap/ship/proc/warn_zone_unprepared(datum/overmap_zone/target_zone)
	if(!target_zone || target_zone.zone_type == ZONE_GREEN)
		return
	if(has_ship_combat_research())
		return
	// The cooldown only silences a repeat of the same warning. Crossing into
	// Contested and then pressing on into Lawless a minute later must not
	// swallow the second advisory, which is the one that matters most.
	if(target_zone.zone_type == zone_advisory_last_band && !COOLDOWN_FINISHED(src, zone_advisory_cooldown))
		return
	zone_advisory_last_band = target_zone.zone_type
	COOLDOWN_START(src, zone_advisory_cooldown, ZONE_ADVISORY_COOLDOWN)

	var/lawless = target_zone.zone_type == ZONE_RED
	var/threat = lawless \
		? "ship weapons are live" \
		: "boarding is permitted"

	ship_notify(
		"[uppertext(target_zone.name)] AHEAD: [threat] past this border, and this hull has no Shuttle Warfare Systems research. Stop at the helm to cancel.",
		"NAVIGATION ADVISORY",
		SHIP_NOTIFY_DANGER,
	) // no sound: the generic zone-transition chime already plays

#undef ZONE_ADVISORY_COOLDOWN
