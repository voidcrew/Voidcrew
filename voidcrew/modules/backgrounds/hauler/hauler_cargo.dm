/// Backgrounds: owned by P5.

/*
 * What a Mule-class hauler carries and who crews it (ECO-7, ECO-8, TAK-1): the markers its hull
 * map carries, the freight cases the Undertow fences, the marked case a Hijack contract wants,
 * the strongbox a crew hands over when it gives up, and the two or three freighter hands aboard.
 */

/// The crew's dialogue file, in AMBIENT_STRINGS_DIR
#define HAULER_STRINGS "hauler_crew.json"
/// The crew's section of it
#define HAULER_STRINGS_SECTION "hauler"
/// What they say with their hands up
#define HAULER_LINE_SURRENDER "surrender"

/// A line of the hauler crew's for `context` ("hail", "surrender", ...), or null if the file has none
/proc/hauler_line(context)
	var/list/lines = ambient_dialogue_lines(HAULER_STRINGS, HAULER_STRINGS_SECTION, context)
	return length(lines) ? pick(lines) : null

// =========================================================================
// MAP MARKERS (map-contracts.md M4: five cargo, three crew)
// =========================================================================

/obj/effect/landmark/hauler

/// Where freight is loaded, and where the strongbox is set down
/obj/effect/landmark/hauler/cargo
	name = "hauler cargo"

/// Where a crew hand starts
/obj/effect/landmark/hauler/crew
	name = "hauler crew"

// =========================================================================
// FREIGHT
// =========================================================================

/// Trade goods off a hauler. Worth something only at the Undertow's window.
/obj/item/hauler_cargo
	name = "freight case"
	desc = "A sealed freight case stencilled with a hauler's mark."
	icon = 'icons/obj/storage/case.dmi'
	icon_state = "cargobox"
	inhand_icon_state = "lockbox"
	lefthand_file = 'icons/mob/inhands/equipment/briefcase_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/briefcase_righthand.dmi'
	w_class = WEIGHT_CLASS_BULKY
	/// The hauler it was loaded on
	var/datum/weakref/hauler_ref

/// The case a Hijack contract wants. The fence's window takes only the plain type, never this one.
/obj/item/hauler_cargo/marked
	desc = "A sealed freight case. Someone has scratched a mark on the lid."
	/// The Hijack contract it was marked for
	var/datum/weakref/mission_ref

/// The hold, handed over by a crew that gave up
/obj/item/storage/hauler_strongbox
	name = "strongbox"
	desc = "A dented freight strongbox."
	icon = 'icons/obj/storage/case.dmi'
	icon_state = "lockbox"
	inhand_icon_state = "lockbox"
	lefthand_file = 'icons/mob/inhands/equipment/briefcase_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/briefcase_righthand.dmi'
	w_class = WEIGHT_CLASS_BULKY
	/// Credits it is packed with, as one holochip
	var/packed_credits = 0

/obj/item/storage/hauler_strongbox/Initialize(mapload, credits = 0)
	packed_credits = max(0, round(credits))
	return ..()

/obj/item/storage/hauler_strongbox/PopulateContents()
	if(packed_credits > 0)
		new /obj/item/holochip(src, packed_credits)

/**
 * Swaps one plain case still sitting aboard a live hauler for a marked one, made for `mission`,
 * and returns it; null when no hauler has one. A case already in someone's hands or bags is
 * never swapped. The case is the mission's to bind and track (P4).
 */
/proc/hauler_mark_case(datum/mission/criminal/hijack/mission)
	var/list/candidates = list()
	for(var/obj/structure/overmap/ship/npc/hauler/hauler in hauler_live_haulers())
		for(var/obj/item/hauler_cargo/cargo in hauler.cargo_aboard())
			if(cargo.type == /obj/item/hauler_cargo && isturf(cargo.loc))
				candidates += cargo
	if(!length(candidates))
		return null
	var/obj/item/hauler_cargo/plain = pick(candidates)
	var/obj/structure/overmap/ship/npc/hauler/carrier = plain.hauler_ref?.resolve()
	if(!istype(carrier))
		return null
	var/obj/item/hauler_cargo/marked/marked = new(plain.loc)
	marked.mission_ref = WEAKREF(mission)
	carrier.track_cargo(marked)
	qdel(plain)
	return marked

// =========================================================================
// THE UNDERTOW'S WINDOW
// =========================================================================

/// Vex fences hauler freight, a few cases a round, for credits only (ECO-7)
/datum/shop_buyback/black_market/hauler_cargo
	item_path = /obj/item/hauler_cargo
	match_subtypes = FALSE
	pay_credits = BACKGROUND_HAULER_CASE_PAY
	pay_vouchers = 0
	demand_min = BACKGROUND_HAULER_FENCE_DEMAND
	demand_max = BACKGROUND_HAULER_FENCE_DEMAND

// Added per shop before the parent builds its live ledger from buyback_types (precedent: the peddler's New())
/datum/outpost_shop/black_market/New(obj/structure/overmap/trader_outpost/outpost)
	buyback_types += /datum/shop_buyback/black_market/hauler_cargo
	return ..()

// =========================================================================
// THE CREW
// =========================================================================

/**
 * A freighter hand: an ordinary ambient NPC (humanoid sentience, no polymorph, no drag, no
 * teleport) that keeps to its own hull, goes about its day aboard, and puts its hands up when
 * the ship gives up. Spawned on the hull's crew markers by the hauler, never mapped.
 */
/mob/living/basic/ambient_npc/hauler_crew
	desc = "Works the freight lanes."
	dialogue_file = HAULER_STRINGS
	dialogue_section = HAULER_STRINGS_SECTION
	outfit_choices = list(
		/datum/outfit/ambient_stranded/hauler,
		/datum/outfit/ambient_stranded,
		/datum/outfit/job/cargo_tech,
	)
	// TAK-1: kept from the base, restated so a later base change cannot drop them here
	sentience_type = SENTIENCE_HUMANOID
	// A breached hold must not kill them in forty seconds (basic mob defaults do)
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	minimum_survivable_temperature = 0
	/// The hauler they crew
	var/datum/weakref/hauler_ref

/mob/living/basic/ambient_npc/hauler_crew/Destroy()
	hauler_ref = null
	return ..()

/// The hauler they crew, while it exists
/mob/living/basic/ambient_npc/hauler_crew/proc/get_hauler()
	var/obj/structure/overmap/ship/npc/hauler/hauler = hauler_ref?.resolve()
	return QDELETED(hauler) ? null : hauler

// Their own hull only: never across a docking collar onto the ship that robbed them
/mob/living/basic/ambient_npc/hauler_crew/leash_ok(turf/tile)
	. = ..()
	if(!.)
		return
	var/obj/structure/overmap/ship/npc/hauler/hauler = get_hauler()
	if(!hauler?.shuttle?.shuttle_areas)
		return
	var/area/tile_area = get_area(tile)
	return istype(tile_area, /area/shuttle/voidcrew/hauler) && !!hauler.shuttle.shuttle_areas[tile_area]

/// Their ship gave up: hands up for whoever comes aboard
/mob/living/basic/ambient_npc/hauler_crew/proc/hands_up()
	if(stat != CONSCIOUS || fading)
		return FALSE
	return !!start_activity(new /datum/ambient_activity/hauler_hands_up(src))

/**
 * Hands up where they stand. It starts when someone is there to see it (the routine runs only
 * with a player near): a line, then still with their hands up for BACKGROUND_HAULER_SURRENDER_TIME.
 * Boarders who turn up long after the surrender find them back at work instead.
 */
/datum/ambient_activity/hauler_hands_up
	name = "hands up"
	priority = AMBIENT_PRIORITY_REACTION
	/// world.time after which raising them would be old news
	var/stale_at = 0

/datum/ambient_activity/hauler_hands_up/setup()
	stale_at = world.time + BACKGROUND_HAULER_SURRENDER_TIME * 2
	go_to(null)
	return TRUE

/datum/ambient_activity/hauler_hands_up/arrive()
	if(world.time >= stale_at)
		ends_at = world.time
		return
	ends_at = world.time + BACKGROUND_HAULER_SURRENDER_TIME
	next_line = world.time + rand(40 SECONDS, 80 SECONDS)
	doer.manual_emote("puts [doer.p_their()] hands up.")
	// One of them speaks; the others just put their hands up
	var/mob/living/basic/ambient_npc/hauler_crew/hand = doer
	var/obj/structure/overmap/ship/npc/hauler/hauler = istype(hand) ? hand.get_hauler() : null
	if(!hauler || hauler.claim_crew_line())
		doer.speak_context(HAULER_LINE_SURRENDER, force = TRUE)

/datum/ambient_activity/hauler_hands_up/act(seconds)
	chatter(HAULER_LINE_SURRENDER, 40 SECONDS, 80 SECONDS)
	return AMBIENT_STEP_CONTINUE

#undef HAULER_STRINGS
#undef HAULER_STRINGS_SECTION
#undef HAULER_LINE_SURRENDER
