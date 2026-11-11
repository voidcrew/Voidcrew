/**
 * # Rescued strays raise the crew's reputation when let go at an outpost
 *
 * A stray rescued from being stranded (`gives_gifts`: the crashed pod and lifeboat survivors) remembers
 * the overmap zone they were found in, and the ship and crew that took them aboard. Let go at a trader
 * outpost by that ship's crew ("Time to go" in crew_menu(), which runs dismiss()), the rescuing crew gets
 * reputation through claim_zone_work(): green pays as easy work (1), yellow as medium (2), red as hard
 * (3), under the same zone ceilings as every other job.
 *
 * Abuse limits:
 * - Once per person: `rescue_paid`, plus a one-off receipt key on the crew record.
 * - Only strays who came from a real stranded site (their place was a site when they agreed to come),
 *   so a stray made outside the site flow (admin spawn, tests) pays nothing.
 * - The zone is their site's (where the pod or lifeboat came down), not where they stand, and is fixed once
 *   they come aboard.
 * - Only the crew that took them aboard is paid, and only while the ship they live on is still that
 *   crew's. Nobody else can let a deckhand go (crew_menu() checks the ship).
 * - Living and able to walk off only (can_act()); a body pays nothing. Never while a player controls them.
 */

/// Hands out one-off receipt keys for rescues
GLOBAL_VAR_INIT(ambient_rescue_serial, 0)

/mob/living/carbon/human/npc/ambient_npc/stray
	/// The overmap zone (ZONE_GREEN/YELLOW/RED) they were found in, or null if they were never rescued
	var/rescue_zone
	/// The ship that took them aboard
	var/datum/weakref/rescue_ship_ref
	/// The crew record of that ship when they came aboard
	var/datum/weakref/rescue_crew_ref
	/// The receipt key their drop-off is claimed under
	var/rescue_receipt
	/// Their drop-off has paid out (or was spent)
	var/rescue_paid = FALSE

/// The zone of the site they were found at: its centre's overmap tile now (a lifeboat drifts), else the band it was
/// made in. Never where they stand, so dragging them off somewhere worse before asking them along changes nothing.
/mob/living/carbon/human/npc/ambient_npc/stray/proc/rescue_site_zone(datum/ambient_place/site/site)
	var/zone = get_zone_type_for_player_turf(site.center)
	if(!(zone in list(ZONE_GREEN, ZONE_YELLOW, ZONE_RED)))
		zone = site.band
	return (zone in list(ZONE_GREEN, ZONE_YELLOW, ZONE_RED)) ? zone : null

/// They agreed to come along: a rescued stray from a stranded site remembers the zone they were found in
/mob/living/carbon/human/npc/ambient_npc/stray/proc/note_rescue_zone()
	var/datum/ambient_place/site/site = place
	if(!gives_gifts || rescue_receipt || !istype(site))
		return
	rescue_zone = rescue_site_zone(site)

/// They came aboard `ship`: the ship and its crew are who rescued them
/mob/living/carbon/human/npc/ambient_npc/stray/proc/note_rescuers(obj/structure/overmap/ship/ship)
	if(!gives_gifts || !rescue_zone || rescue_receipt || QDELETED(ship))
		return
	var/datum/voidcrew_crew_record/crew = ship.get_crew_record()
	if(QDELETED(crew))
		return
	rescue_ship_ref = WEAKREF(ship)
	rescue_crew_ref = WEAKREF(crew)
	rescue_receipt = "rescue:[++GLOB.ambient_rescue_serial]"

/**
 * Let go by `user` at the trader outpost their ship is docked at: the crew that rescued them gets
 * reputation for the zone they were found in. Returns the reputation added (0 for none). Never yields.
 */
/mob/living/carbon/human/npc/ambient_npc/stray/proc/claim_rescue(mob/living/user)
	if(rescue_paid || !rescue_receipt || !rescue_zone || ckey || stat != CONSCIOUS || !is_deckhand())
		return 0
	var/obj/structure/overmap/ship/ship = get_ship()
	if(!ship || rescue_ship_ref?.resolve() != ship)
		return 0
	var/datum/ambient_place/ship/deck = place
	if(!istype(deck) || !deck.docked_outpost())
		return 0
	var/datum/voidcrew_crew_record/crew = rescue_crew_ref?.resolve()
	if(QDELETED(crew) || ship.get_crew_record() != crew)
		return 0
	rescue_paid = TRUE
	var/permission_before = crew.get_zone_permission()
	var/gain = crew.claim_zone_work(rescue_zone, rescue_zone, rescue_receipt)
	record_zone_work_rows(ship, type, rescue_zone, zone_work_reward(rescue_zone), gain, permission_before, crew.get_zone_permission(), user, list("rescue" = real_name))
	log_game("AMBIENT: [src], rescued in zone [rescue_zone], was let go at an outpost by [key_name(user)] of the [ship.name]: +[gain] reputation")
	return gain
