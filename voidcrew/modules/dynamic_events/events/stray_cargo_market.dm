/**
 * Ship- and galaxy-scoped ports of TG's Stray Cargo Pod and Market Crash
 * (code/modules/events/stray_cargo.dm, code/modules/events/market_crash.dm).
 *
 * Stray Cargo Pod is a ship-scoped treat event: a supply pod carrying a random
 * cargo crate punches into the target ship, announced in advance so the crew
 * can clear the impact zone. The pod is the stock TG supplypod, so it lands
 * with its usual light explosion, free loot with a dent.
 *
 * Market Crash is a galaxy-scoped economy event: it inflates SSeconomy for a
 * while, raising vendor prices sector-wide, then lets them settle back. It has
 * no target ship (target_ship stays null) and must never touch one.
 */

/datum/round_event_control/voidcrew/stray_cargo
	name = "Stray Cargo Pod"
	typepath = /datum/round_event/voidcrew/stray_cargo
	weight = 20
	max_occurrences = 4
	earliest_start = 10 MINUTES
	category = EVENT_CATEGORY_BUREAUCRATIC
	description = "A pod containing a random supply crate lands on the target ship."
	requires_flying = TRUE // Pods do not punch into a ship parked inside a hangar.
	min_crew_aboard = 1
	/// A pod arrives with a light explosion and takes a tile with it. On a hull the size of
	/// a Pill-class that is a breach across most of the ship, and the "free loot with a
	/// dent" trade this event is built around stops being a trade.
	min_ship_mass = SHIP_MASS_MEDIUM

/datum/round_event/voidcrew/stray_cargo
	announce_chance = 75
	fakeable = FALSE // A fake version could never reach a ship, so it is not offered.
	/// Turf aboard the target ship the pod will land on. Picked in setup() so the announcement can name the area.
	var/turf/landing_turf
	/// Name of the area containing landing_turf, announced to the crew before impact.
	var/impact_area_name
	/// Supply pack typepaths the pod may contain. Filtered from the cargo list once, as in the original.
	var/static/list/stray_spawnable_supply_packs
	/// Explicit pack pool for variants. Null falls back to the filtered cargo list above.
	var/list/possible_pack_types

/**
 * Picks the landing turf and randomizes the warning delay (the original's
 * rand(20, 40) between announcement and impact, so crew can clear the area).
 */
/datum/round_event/voidcrew/stray_cargo/setup()
	if(!target_valid())
		kill()
		return
	start_when = rand(20, 40)
	landing_turf = target_ship.get_random_open_ship_turf()
	if(!landing_turf)
		kill()
		return
	var/area/impact_area = get_area(landing_turf)
	impact_area_name = impact_area.name
	if(!stray_spawnable_supply_packs)
		stray_spawnable_supply_packs = SSshuttle.supply_packs.Copy()
		for(var/datum/supply_pack/pack_type as anything in stray_spawnable_supply_packs)
			if(initial(pack_type.special))
				stray_spawnable_supply_packs -= pack_type
	if(!length(stray_spawnable_supply_packs)) // Cargo subsystem somehow has nothing to give.
		kill()
		return

/datum/round_event/voidcrew/stray_cargo/announce(fake)
	if(!target_valid())
		return
	target_ship.ship_event_announce("Stray cargo pod detected on long-range scanners. Expected location of impact: [impact_area_name].", "Collision Alert")

/// Spawns a random supply pack, puts it in a pod, and drops it on the landing turf.
/datum/round_event/voidcrew/stray_cargo/start()
	if(!target_valid())
		return
	// The landing site may have been built over or exposed to space since setup; re-pick once.
	if(!landing_turf || landing_turf.is_blocked_turf() || !target_ship.is_aboard(landing_turf))
		landing_turf = target_ship.get_random_open_ship_turf()
	if(!landing_turf)
		return
	var/pack_type = pick(length(possible_pack_types) ? possible_pack_types : stray_spawnable_supply_packs)
	var/datum/supply_pack/supply_pack = new pack_type
	var/obj/structure/closet/crate/crate = supply_pack.generate(null)
	if(crate) // Empty supply packs are a thing, as in the original.
		crate.locked = FALSE // Unlock secure crates.
		crate.update_appearance()
	var/obj/structure/closet/supplypod/pod = make_pod()
	var/obj/effect/pod_landingzone/landing_marker = new(landing_turf, pod, crate)
	var/static/mutable_appearance/target_appearance = mutable_appearance('icons/obj/supplypods_32x32.dmi', "LZ")
	notify_ghosts("[control.name] has summoned a supply crate!", source = get_turf(landing_marker), header = "Cargo Inbound", alert_overlay = target_appearance)

/// The pod itself, so variants can reskin it. A stock pod, small explosion included.
/datum/round_event/voidcrew/stray_cargo/proc/make_pod()
	return new /obj/structure/closet/supplypod

/// Nothing to clean up, the pod and crate belong to the crew now.
/datum/round_event/voidcrew/stray_cargo/end()
	if(!target_valid())
		return

/**
 * The rare one: a syndicate pod carrying thirty telecrystals of uplink gear, picked the
 * same way surplus crates are. Kept to a single occurrence and pushed late, this is the
 * best thing a crew can be handed for free, and it should stay a story rather than a
 * supply line.
 */
/datum/round_event_control/voidcrew/stray_cargo/syndicate
	name = "Stray Syndicate Cargo Pod"
	typepath = /datum/round_event/voidcrew/stray_cargo/syndicate
	weight = 6
	max_occurrences = 1
	earliest_start = 30 MINUTES
	description = "A pod containing syndicate gear lands on the target ship."
	min_wizard_trigger_potency = 3
	max_wizard_trigger_potency = 6

/datum/round_event/voidcrew/stray_cargo/syndicate
	possible_pack_types = list(/datum/supply_pack/misc/syndicate)

/datum/round_event/voidcrew/stray_cargo/syndicate/make_pod()
	var/obj/structure/closet/supplypod/pod = new
	pod.setStyle(/datum/pod_style/syndicate)
	return pod

/datum/round_event_control/voidcrew/market_crash
	name = "Market Crash"
	typepath = /datum/round_event/voidcrew/market_crash
	weight = 10
	event_scope = EVENT_SCOPE_GALAXY
	category = EVENT_CATEGORY_BUREAUCRATIC
	description = "Temporarily increases the prices of vending machines sector-wide."

/datum/round_event/voidcrew/market_crash
	/// This counts the number of ticks that the market crash event has been processing, so that we don't call vendor price updates every tick, but we still iterate for other mechanics that use inflation.
	var/tick_counter = 1

/datum/round_event/voidcrew/market_crash/setup()
	start_when = 1
	end_when = rand(100, 50)
	announce_when = 2

/datum/round_event/voidcrew/market_crash/announce(fake)
	var/list/poss_reasons = list("the alignment of the local stars",\
		"some risky housing market outcomes",\
		"speculative colonial development grants backfiring",\
		"greatly exaggerated reports of sector accountancy personnel being \"laid off\"",\
		"a \"great investment\" into \"non-fungible tokens\" by a \"moron\"",\
		"a number of pirate raids on free-trade convoys",\
		"supply chain shortages",\
		"the sector trade network's untimely downfall",\
		"the sector trade network's unfortunate success",\
		"uhh, bad luck, we guess"
	)
	var/reason = pick(poss_reasons)
	priority_announce("Due to [reason], sector-wide vendor prices will be increased for a short period.", "Sector Accounting Division")

/datum/round_event/voidcrew/market_crash/start()
	SSeconomy.update_vending_prices()
	SSeconomy.price_update()
	ADD_TRAIT(SSeconomy, TRAIT_MARKET_CRASHING, MARKET_CRASH_EVENT_TRAIT)

/datum/round_event/voidcrew/market_crash/end()
	REMOVE_TRAIT(SSeconomy, TRAIT_MARKET_CRASHING, MARKET_CRASH_EVENT_TRAIT)
	SSeconomy.price_update()
	SSeconomy.update_vending_prices()
	priority_announce("Sector-wide vendor prices have now stabilized.", "Sector Accounting Division")

/datum/round_event/voidcrew/market_crash/tick()
	tick_counter++ // TG writes `tick_counter = tick_counter++`, a DM no-op that stalls the counter at 1, fixed to match the evident intent
	SSeconomy.inflation_value = 5.5*(log(activeFor+1))
	if(tick_counter == 5)
		tick_counter = 1
		SSeconomy.update_vending_prices()
