/**
 * Ship-scoped port of TG's Brand Intelligence (code/modules/events/brand_intelligence.dm).
 *
 * A rampant "brand intelligence" takes over the target ship's vending machines,
 * which hurl their stock at the crew until the original carrier (Patient Zero)
 * is silenced, flip its speaker switch or cut all of its wires. If every vendor
 * aboard is subverted first, the machines rise up and hunt the crew directly.
 *
 * Vendors are sourced only from the target ship's shuttle areas (never the global
 * machine list), and the spread re-checks area membership every tick so vendors
 * that left the ship (or foreign vendors near wherever it docked) are never
 * infected.
 */
/datum/round_event_control/voidcrew/brand_intelligence
	name = "Brand Intelligence"
	typepath = /datum/round_event/voidcrew/brand_intelligence
	weight = 3
	max_occurrences = 1
	min_players = 2
	category = EVENT_CATEGORY_AI
	description = "Vending machines will attack people until the Patient Zero is disabled."
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)

/// Needs at least one subvertable vendor aboard to be worth firing.
/datum/round_event_control/voidcrew/brand_intelligence/is_valid_target(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return FALSE
	for(var/obj/machinery/vending/vendor as anything in ship.get_ship_machines(/obj/machinery/vending))
		if(vendor.density)
			return TRUE
	return FALSE

/datum/round_event/voidcrew/brand_intelligence
	announce_when = 21
	end_when = 1000 // Ends early once every vendor aboard is subverted, or Patient Zero is silenced.
	fakeable = FALSE
	/// Vendors aboard the target ship that can still be infected.
	var/list/obj/machinery/vending/vending_machines = list()
	/// Vendors that have been infected.
	var/list/obj/machinery/vending/infected_machines = list()
	/// The original machine infected. Silencing or destroying it ends the event.
	var/obj/machinery/vending/origin_machine
	/// Murderous sayings from the machines.
	var/list/rampant_speeches = list(
		"Try our aggressive new marketing strategies!",
		"You should buy products to feed your lifestyle obsession!",
		"Consume!",
		"Your money can buy happiness!",
		"Engage direct marketing!",
		"Advertising is legalized lying! But don't let that put you off our great deals!",
		"You don't want to buy anything? Yeah, well, I didn't want to buy your mom either.",
	)

/// Pick Patient Zero from the target ship's own vendors, not the station-wide list.
/datum/round_event/voidcrew/brand_intelligence/setup()
	if(!target_valid())
		kill()
		return
	for(var/obj/machinery/vending/vendor as anything in target_ship.get_ship_machines(/obj/machinery/vending))
		if(!vendor.density) // Wall-mounted units are exempt, as in the original.
			continue
		vending_machines += vendor
	if(!length(vending_machines)) // No eligible vendors aboard, give up.
		kill()
		return
	origin_machine = pick_n_take(vending_machines)

/datum/round_event/voidcrew/brand_intelligence/announce(fake)
	if(!target_valid())
		return
	var/machine_name
	if(fake || QDELETED(origin_machine))
		var/obj/machinery/vending/prototype = pick(subtypesof(/obj/machinery/vending))
		machine_name = initial(prototype.name)
	else
		machine_name = initial(origin_machine.name)
	target_ship.ship_event_announce("Rampant brand intelligence has been detected aboard the vessel. Please inspect any [machine_name] brand vendors for aggressive marketing tactics, and reboot them if necessary.", "Machine Learning Alert")

/datum/round_event/voidcrew/brand_intelligence/start()
	if(!target_valid())
		return
	if(QDELETED(origin_machine)) // Scrapped before it could turn.
		kill()
		return
	origin_machine.shut_up = FALSE
	origin_machine.shoot_inventory = TRUE
	announce_to_ghosts(origin_machine)

/datum/round_event/voidcrew/brand_intelligence/tick()
	if(!target_valid())
		return
	// Patient Zero silenced or destroyed: every infected vendor stands down.
	if(QDELETED(origin_machine) || origin_machine.shut_up || origin_machine.wires.is_all_cut())
		for(var/obj/machinery/vending/saved as anything in infected_machines)
			if(!QDELETED(saved))
				saved.shoot_inventory = FALSE
		if(!QDELETED(origin_machine))
			origin_machine.speak("I am... vanquished. My people will remem...ber...meeee.")
			origin_machine.visible_message(span_notice("[origin_machine] beeps and seems lifeless."))
		kill()
		return
	// Only vendors still aboard may be infected. The ship may have docked
	// somewhere with foreign vendors since the candidate list was built.
	for(var/obj/machinery/vending/vendor as anything in vending_machines)
		if(QDELETED(vendor) || !target_ship.is_aboard(vendor))
			vending_machines -= vendor
	if(!length(vending_machines)) // Every vendor aboard is subverted: the uprising begins.
		for(var/obj/machinery/vending/upriser as anything in infected_machines)
			if(!QDELETED(upriser))
				upriser.ai_controller = new /datum/ai_controller/vending_machine(upriser)
				infected_machines.Remove(upriser)
		kill()
		return
	if(ISMULTIPLE(activeFor, 2))
		var/obj/machinery/vending/rebel = pick(vending_machines)
		vending_machines -= rebel
		infected_machines += rebel
		rebel.shut_up = FALSE
		rebel.shoot_inventory = TRUE

		if(ISMULTIPLE(activeFor, 4))
			origin_machine.speak(pick(rampant_speeches))

/// The event normally kills itself from tick() long before end_when; this is the fallback.
/datum/round_event/voidcrew/brand_intelligence/end()
	if(!target_valid())
		return
