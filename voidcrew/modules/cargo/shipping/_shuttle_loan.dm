/**
 * Voidcrew Shuttle Loan System
 * Adapted from TG's shuttle loan events for per-ship cargo shuttles
 */

/// Global list of available loan types
GLOBAL_LIST_INIT(voidcrew_shuttle_loans, list(
	/datum/voidcrew_shuttle_loan/department_resupply,
	/datum/voidcrew_shuttle_loan/salvage_recovery,
	/datum/voidcrew_shuttle_loan/contraband_disposal,
	/datum/voidcrew_shuttle_loan/pizza_delivery,
	/datum/voidcrew_shuttle_loan/medical_emergency,
	/datum/voidcrew_shuttle_loan/antidote,
	/datum/voidcrew_shuttle_loan/syndiehijacking,
	/datum/voidcrew_shuttle_loan/lots_of_bees,
	/datum/voidcrew_shuttle_loan/jc_a_bomb,
	/datum/voidcrew_shuttle_loan/papers_please,
	/datum/voidcrew_shuttle_loan/russian_party,
	/datum/voidcrew_shuttle_loan/spider_gift,
))

// ========== ROUND EVENT ==========

/**
 * Round event control for shuttle loan offers
 * Sends loan offers to random ships with cargo consoles
 */
/datum/round_event_control/shuttle_loan_voidcrew
	name = "Shuttle Loan (Voidcrew)"
	typepath = /datum/round_event/shuttle_loan_voidcrew
	max_occurrences = 5
	earliest_start = 7 MINUTES
	category = EVENT_CATEGORY_BUREAUCRATIC
	description = "Offers a shuttle loan deal to a random ship. If accepted, fills their cargo shuttle with loot and/or enemies."

/datum/round_event_control/shuttle_loan_voidcrew/can_spawn_event(players_amt, allow_magic = FALSE)
	. = ..()
	if(!.)
		return FALSE
	// Make sure there's at least one ship that can receive a loan (must have a cargo console)
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(!ship_has_cargo_console(ship))
			continue
		var/datum/voidcrew_cargo_shuttle/cargo_shuttle = ship.get_cargo_shuttle()
		if(cargo_shuttle && !cargo_shuttle.pending_loan && cargo_shuttle.state == CARGO_SHUTTLE_AWAY)
			return TRUE
	return FALSE

/datum/round_event/shuttle_loan_voidcrew
	announce_when = 1
	end_when = 500 // ~8 minutes total to find a taker
	/// The ship that currently has the loan offer
	var/obj/structure/overmap/ship/target_ship
	/// The loan type that was offered
	var/datum/voidcrew_shuttle_loan/loan_type
	/// Ships that have already declined the offer
	var/list/declined_ships = list()
	/// Whether the loan has been accepted by any ship
	var/loan_accepted = FALSE

/datum/round_event/shuttle_loan_voidcrew/setup()
	// Pick a random loan type
	loan_type = pick(GLOB.voidcrew_shuttle_loans)

/datum/round_event/shuttle_loan_voidcrew/announce(fake)
	if(!try_send_to_next_ship())
		kill() // No eligible ships at all
		return

/datum/round_event/shuttle_loan_voidcrew/tick()
	if(loan_accepted)
		return // Already accepted, just waiting for event to end

	if(!target_ship)
		// No current target, try to find one
		if(!try_send_to_next_ship())
			end_when = activeFor + 1 // No more eligible ships
		return

	var/datum/voidcrew_cargo_shuttle/cargo_shuttle = target_ship.get_cargo_shuttle()
	if(!cargo_shuttle)
		// Ship no longer has cargo shuttle, try next ship
		declined_ships += target_ship
		target_ship = null
		if(!try_send_to_next_ship())
			end_when = activeFor + 1
		return

	// Check if loan was accepted
	if(cargo_shuttle.loan_accepted)
		loan_accepted = TRUE
		end_when = activeFor + 1
		return

	// Check if loan was declined (pending_loan is null but loan_accepted is false)
	if(!cargo_shuttle.pending_loan && !cargo_shuttle.loan_accepted)
		// Declined! Try another ship
		declined_ships += target_ship
		target_ship = null
		if(!try_send_to_next_ship())
			end_when = activeFor + 1 // No more eligible ships

/datum/round_event/shuttle_loan_voidcrew/end()
	// If the loan was accepted, don't expire it - the shuttle will handle cleanup on arrival
	if(loan_accepted)
		return

	// If the loan is still pending (not accepted) when the event ends, decline it automatically
	if(!target_ship)
		return

	var/datum/voidcrew_cargo_shuttle/cargo_shuttle = target_ship.get_cargo_shuttle()
	if(cargo_shuttle?.pending_loan && !cargo_shuttle.loan_accepted)
		target_ship.ship_notify("The shuttle loan offer has expired.", "CARGO", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 50)
		cargo_shuttle.decline_loan()

/**
 * Tries to send the loan offer to the next eligible ship
 * Returns TRUE if successful, FALSE if no eligible ships remain
 */
/datum/round_event/shuttle_loan_voidcrew/proc/try_send_to_next_ship()
	// Find eligible ships (have cargo console, cargo shuttle, shuttle is away, no pending loan, haven't declined)
	var/list/eligible_ships = list()
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(ship in declined_ships)
			continue
		if(!ship_has_cargo_console(ship))
			continue
		var/datum/voidcrew_cargo_shuttle/cargo_shuttle = ship.get_cargo_shuttle()
		if(cargo_shuttle && !cargo_shuttle.pending_loan && cargo_shuttle.state == CARGO_SHUTTLE_AWAY)
			eligible_ships += ship

	if(!length(eligible_ships))
		return FALSE // No eligible ships

	target_ship = pick(eligible_ships)

	if(!send_shuttle_loan_offer(target_ship, loan_type))
		// Failed to send, mark as declined and try again
		declined_ships += target_ship
		target_ship = null
		return try_send_to_next_ship()

	log_game("Shuttle loan event '[loan_type]' sent to ship '[target_ship.name]'.")
	return TRUE

/**
 * Checks if a ship has a functioning cargo console
 */
/proc/ship_has_cargo_console(obj/structure/overmap/ship/ship)
	if(!ship?.shuttle)
		return FALSE
	for(var/area/shuttle_area as anything in ship.shuttle.shuttle_areas)
		for(var/obj/machinery/computer/voidcrew_cargo/console in shuttle_area)
			if(!(console.machine_stat & BROKEN))
				return TRUE
	return FALSE

/**
 * Sends a random shuttle loan offer to a ship
 * Returns TRUE if the offer was sent successfully
 */
/proc/send_shuttle_loan_offer(obj/structure/overmap/ship/ship, loan_type = null)
	if(!ship)
		return FALSE

	var/datum/voidcrew_cargo_shuttle/cargo_shuttle = ship.get_cargo_shuttle()
	if(!cargo_shuttle)
		return FALSE

	if(!loan_type)
		loan_type = pick(GLOB.voidcrew_shuttle_loans)

	if(!cargo_shuttle.receive_loan_offer(loan_type))
		return FALSE

	// Announce the offer to the ship
	var/datum/voidcrew_shuttle_loan/loan = cargo_shuttle.pending_loan
	ship.ship_notify(loan.announcement_text, "CARGO", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	return TRUE

/// Shuttle loan situations available to voidcrew ships
/datum/voidcrew_shuttle_loan
	/// Who sent the offer
	var/sender = "Central Trading Hub"
	/// Announcement text for the offer
	var/announcement_text = "Unset announcement text"
	/// Text shown during shuttle transit
	var/shuttle_transit_text = "Unset transit text"
	/// Credits earned for accepting the deal
	var/bonus_credits = CARGO_CRATE_VALUE * 50
	/// Response for accepting the deal
	var/thanks_msg = "Your shuttle will return with our cargo. Payment has been transferred."
	/// Description for logging
	var/logging_desc = "generic loan"

/// Spawns items on the shuttle when it arrives
/datum/voidcrew_shuttle_loan/proc/spawn_items(datum/voidcrew_cargo_shuttle/shuttle)
	SHOULD_CALL_PARENT(FALSE)
	CRASH("Unimplemented spawn_items() on [src.type].")

/// Department resupply - free supplies, no bonus
/datum/voidcrew_shuttle_loan/department_resupply
	sender = "Nanotrasen Supply Division"
	announcement_text = "We have surplus department supplies that need to be offloaded. Send your cargo shuttle to receive them free of charge."
	shuttle_transit_text = "Department resupply incoming."
	thanks_msg = "Your shuttle will return with our surplus supplies."
	bonus_credits = 0
	logging_desc = "Resupply packages"

/datum/voidcrew_shuttle_loan/department_resupply/spawn_items(datum/voidcrew_cargo_shuttle/shuttle)
	var/list/cargo_turfs = shuttle.get_cargo_bay_turfs()
	var/list/crate_types = list(
		/datum/supply_pack/emergency/equipment,
		/datum/supply_pack/security/supplies,
		/datum/supply_pack/organic/food,
		/datum/supply_pack/engineering/tools,
		/datum/supply_pack/medical/supplies
	)
	for(var/crate_type in crate_types)
		var/datum/supply_pack/pack = SSshuttle.supply_packs[crate_type]
		if(pack && length(cargo_turfs))
			pack.generate(pick_n_take(cargo_turfs))

/// Salvage recovery - mixed loot and danger
/datum/voidcrew_shuttle_loan/salvage_recovery
	sender = "Independent Salvage Consortium"
	announcement_text = "We've recovered a derelict cargo pod but need help sorting through it. Send your shuttle for a cut of the salvage."
	shuttle_transit_text = "Salvage recovery operation complete. Contents may vary."
	thanks_msg = "Salvage inbound. Watch out for unstable materials."
	bonus_credits = CARGO_CRATE_VALUE * 75
	logging_desc = "Salvage recovery"

/datum/voidcrew_shuttle_loan/salvage_recovery/spawn_items(datum/voidcrew_cargo_shuttle/shuttle)
	var/list/cargo_turfs = shuttle.get_cargo_bay_turfs()
	if(!length(cargo_turfs))
		return

	// Random valuable materials
	var/list/possible_loot = list(
		/obj/item/stack/sheet/iron,
		/obj/item/stack/sheet/glass,
		/obj/item/stack/sheet/plasteel,
		/obj/item/stack/ore/uranium,
		/obj/item/stack/ore/plasma,
		/obj/item/stack/sheet/mineral/titanium,
		/obj/structure/closet/crate/engineering,
		/obj/structure/closet/crate/science,
	)

	// Spawn 3-5 items
	for(var/i in 1 to rand(3, 5))
		if(!length(cargo_turfs))
			break
		var/loot_type = pick(possible_loot)
		var/turf/spawn_turf = pick_n_take(cargo_turfs)
		var/obj/item/spawned = new loot_type(spawn_turf)
		// Set stack amounts for material stacks
		if(istype(spawned, /obj/item/stack))
			var/obj/item/stack/stack = spawned
			stack.amount = rand(10, 30)

	// Small chance of something dangerous
	if(prob(15) && length(cargo_turfs))
		new /obj/effect/mob_spawn/corpse/human/assistant(pick_n_take(cargo_turfs))

/// Contraband disposal - illegal goods, high reward
/datum/voidcrew_shuttle_loan/contraband_disposal
	sender = "Anonymous Benefactor"
	announcement_text = "We need to offload some... sensitive cargo. High payment for discretion."
	shuttle_transit_text = "Sensitive cargo transfer in progress."
	thanks_msg = "Payment transferred. Contents are yours to keep or dispose of."
	bonus_credits = CARGO_CRATE_VALUE * 150
	logging_desc = "Contraband disposal"

/datum/voidcrew_shuttle_loan/contraband_disposal/spawn_items(datum/voidcrew_cargo_shuttle/shuttle)
	var/list/cargo_turfs = shuttle.get_cargo_bay_turfs()
	if(!length(cargo_turfs))
		return

	// Contraband items
	var/list/contraband = list(
		/obj/item/storage/toolbox/syndicate,
		/obj/item/storage/box/syndie_kit/chameleon,
		/obj/item/stack/spacecash/c1000,
		/obj/item/reagent_containers/hypospray/medipen/stimulants,
	)

	for(var/i in 1 to rand(2, 4))
		if(!length(cargo_turfs))
			break
		var/item_type = pick(contraband)
		new item_type(pick_n_take(cargo_turfs))

/// Pizza delivery - food and fun
/datum/voidcrew_shuttle_loan/pizza_delivery
	sender = "Spinward Pizza Express"
	announcement_text = "A neighboring station accidentally ordered way too much pizza. Want some?"
	shuttle_transit_text = "Pizza delivery incoming!"
	thanks_msg = "Enjoy your pizza! No payment required for this happy accident."
	bonus_credits = 0
	logging_desc = "Pizza delivery"

/datum/voidcrew_shuttle_loan/pizza_delivery/spawn_items(datum/voidcrew_cargo_shuttle/shuttle)
	var/list/cargo_turfs = shuttle.get_cargo_bay_turfs()
	log_shuttle("LOAN DEBUG: pizza_delivery spawn_items - cargo_turfs=[length(cargo_turfs)]")
	if(!length(cargo_turfs))
		log_shuttle("LOAN DEBUG: pizza_delivery - NO TURFS, aborting spawn!")
		return

	var/list/pizza_types = list(
		/obj/item/pizzabox/margherita,
		/obj/item/pizzabox/meat,
		/obj/item/pizzabox/vegetable,
		/obj/item/pizzabox/mushroom
	)

	var/spawned_count = 0
	for(var/i in 1 to rand(4, 8))
		if(!length(cargo_turfs))
			break
		var/pizza_type = pick(pizza_types)
		var/turf/spawn_turf = pick_n_take(cargo_turfs)
		new pizza_type(spawn_turf)
		spawned_count++
	log_shuttle("LOAN DEBUG: pizza_delivery - spawned [spawned_count] pizzas")

/// Medical emergency - medical supplies
/datum/voidcrew_shuttle_loan/medical_emergency
	sender = "Emergency Medical Services"
	announcement_text = "A medical convoy was attacked. We need you to secure what's left of the supplies."
	shuttle_transit_text = "Medical supplies incoming."
	thanks_msg = "Thank you for your assistance. Keep the supplies as compensation."
	bonus_credits = CARGO_CRATE_VALUE * 50
	logging_desc = "Medical emergency"

/datum/voidcrew_shuttle_loan/medical_emergency/spawn_items(datum/voidcrew_cargo_shuttle/shuttle)
	var/list/cargo_turfs = shuttle.get_cargo_bay_turfs()
	if(!length(cargo_turfs))
		return

	// Medical supplies
	var/datum/supply_pack/pack = SSshuttle.supply_packs[/datum/supply_pack/medical/supplies]
	if(pack)
		pack.generate(pick_n_take(cargo_turfs))

	var/list/extra_supplies = list(
		/obj/item/storage/medkit/regular,
		/obj/item/storage/medkit/brute,
		/obj/item/storage/medkit/fire,
		/obj/item/reagent_containers/hypospray/medipen,
	)

	for(var/i in 1 to rand(2, 4))
		if(!length(cargo_turfs))
			break
		var/supply_type = pick(extra_supplies)
		new supply_type(pick_n_take(cargo_turfs))

// ========== TG PARITY LOAN SITUATIONS ==========

/// Antidote - Virus samples and infected corpses
/datum/voidcrew_shuttle_loan/antidote
	sender = "Nanotrasen Research Initiatives"
	announcement_text = "Your ship has been selected for an epidemiological research project. Send us your cargo shuttle to receive your research samples."
	shuttle_transit_text = "Virus samples incoming."
	thanks_msg = "Research samples inbound. Handle with care."
	bonus_credits = CARGO_CRATE_VALUE * 50
	logging_desc = "Virus shuttle"

/datum/voidcrew_shuttle_loan/antidote/spawn_items(datum/voidcrew_cargo_shuttle/shuttle)
	var/list/cargo_turfs = shuttle.get_cargo_bay_turfs()
	if(!length(cargo_turfs))
		return

	// Spawn infected corpses
	var/list/infected_types = list(
		/obj/effect/mob_spawn/corpse/human/assistant/beesease_infection,
		/obj/effect/mob_spawn/corpse/human/assistant/brainrot_infection,
		/obj/effect/mob_spawn/corpse/human/assistant/spanishflu_infection,
	)
	var/infected_type = pick(infected_types)

	for(var/i in 1 to rand(3, 5))
		if(!length(cargo_turfs))
			break
		new infected_type(pick_n_take(cargo_turfs))

	// Random medical debris
	var/list/debris = list(
		/obj/item/reagent_containers/cup/bottle,
		/obj/item/reagent_containers/syringe,
		/obj/item/shard,
	)
	for(var/i in 1 to rand(5, 10))
		if(!length(cargo_turfs))
			break
		if(prob(50))
			var/debris_type = pick(debris)
			new debris_type(pick_n_take(cargo_turfs))

	// Virus bottles
	if(length(cargo_turfs))
		new /obj/structure/closet/crate(pick_n_take(cargo_turfs))
	if(length(cargo_turfs))
		new /obj/item/reagent_containers/cup/bottle/pierrot_throat(pick_n_take(cargo_turfs))
	if(length(cargo_turfs))
		new /obj/item/reagent_containers/cup/bottle/magnitis(pick_n_take(cargo_turfs))

/// Syndicate hijacking - Hostile boarding team
/datum/voidcrew_shuttle_loan/syndiehijacking
	sender = "Nanotrasen Counterintelligence"
	announcement_text = "The Syndicate are trying to infiltrate your vessel. If you let them hijack your cargo shuttle, you'll save us a headache. Combat pay included."
	shuttle_transit_text = "Syndicate hijack team incoming."
	thanks_msg = "Hostile contacts inbound. Arm yourselves."
	bonus_credits = CARGO_CRATE_VALUE * 50
	logging_desc = "Syndicate boarding party"

/datum/voidcrew_shuttle_loan/syndiehijacking/spawn_items(datum/voidcrew_cargo_shuttle/shuttle)
	var/list/cargo_turfs = shuttle.get_cargo_bay_turfs()
	if(!length(cargo_turfs))
		return

	// Spawn special ops crate
	var/datum/supply_pack/pack = SSshuttle.supply_packs[/datum/supply_pack/imports/specialops]
	if(pack && length(cargo_turfs))
		pack.generate(pick_n_take(cargo_turfs))

	// Spawn syndicate infiltrators
	for(var/i in 1 to 2)
		if(!length(cargo_turfs))
			break
		new /mob/living/basic/trooper/syndicate/ranged/infiltrator(pick_n_take(cargo_turfs))

	// Chance for more
	if(prob(75) && length(cargo_turfs))
		new /mob/living/basic/trooper/syndicate/ranged/infiltrator(pick_n_take(cargo_turfs))
	if(prob(50) && length(cargo_turfs))
		new /mob/living/basic/trooper/syndicate/ranged/infiltrator(pick_n_take(cargo_turfs))

/// Lots of bees - Toxic bees and beekeeping equipment
/datum/voidcrew_shuttle_loan/lots_of_bees
	sender = "Nanotrasen Janitorial Division"
	announcement_text = "One of our freighters carrying a bee shipment has been attacked by eco-terrorists. Can you clean up the mess for us? Hazard pay included."
	shuttle_transit_text = "Biohazard cleanup incoming."
	thanks_msg = "Biohazard inbound. Watch out for stingers."
	bonus_credits = CARGO_CRATE_VALUE * 100 // Toxin bees can be lethal
	logging_desc = "Shuttle full of bees"

/datum/voidcrew_shuttle_loan/lots_of_bees/spawn_items(datum/voidcrew_cargo_shuttle/shuttle)
	var/list/cargo_turfs = shuttle.get_cargo_bay_turfs()
	if(!length(cargo_turfs))
		return

	// Beekeeping crate
	var/datum/supply_pack/pack = SSshuttle.supply_packs[/datum/supply_pack/organic/hydroponics/beekeeping_fullkit]
	if(pack && length(cargo_turfs))
		pack.generate(pick_n_take(cargo_turfs))

	// Corpses from the incident
	var/list/corpse_types = list(
		/obj/effect/mob_spawn/corpse/human/bee_terrorist,
		/obj/effect/mob_spawn/corpse/human/cargo_tech,
		/obj/effect/mob_spawn/corpse/human/cargo_tech,
		/obj/effect/mob_spawn/corpse/human/nanotrasensoldier,
	)
	for(var/corpse_type in corpse_types)
		if(!length(cargo_turfs))
			break
		new corpse_type(pick_n_take(cargo_turfs))

	// Weapons from the fight
	if(length(cargo_turfs))
		new /obj/item/gun/ballistic/automatic/pistol/no_mag(pick_n_take(cargo_turfs))
	if(length(cargo_turfs))
		new /obj/item/gun/ballistic/automatic/pistol/m1911/no_mag(pick_n_take(cargo_turfs))

	// Beekeeping stuff
	for(var/i in 1 to 3)
		if(!length(cargo_turfs))
			break
		new /obj/item/honey_frame(pick_n_take(cargo_turfs))
	if(length(cargo_turfs))
		new /obj/structure/beebox/unwrenched(pick_n_take(cargo_turfs))
	if(length(cargo_turfs))
		new /obj/item/queen_bee/bought(pick_n_take(cargo_turfs))
	if(length(cargo_turfs))
		new /obj/structure/closet/crate/hydroponics(pick_n_take(cargo_turfs))

	// THE BEES
	for(var/i in 1 to 8)
		if(!length(cargo_turfs))
			break
		new /mob/living/basic/bee/toxin(pick_n_take(cargo_turfs))

	// Blood and bug guts
	for(var/i in 1 to 5)
		if(!length(cargo_turfs))
			break
		var/decal = pick(/obj/effect/decal/cleanable/blood, /obj/effect/decal/cleanable/insectguts)
		new decal(pick_n_take(cargo_turfs))

/// JC a bomb - Live explosive ordnance
/datum/voidcrew_shuttle_loan/jc_a_bomb
	sender = "Nanotrasen Security Division"
	announcement_text = "We have discovered an active Syndicate bomb near our VIP shuttle's fuel lines. If you feel up to the task, we will pay handsomely for defusing it."
	shuttle_transit_text = "Live explosive ordnance incoming. Exercise extreme caution."
	thanks_msg = "Live explosive ordnance incoming via cargo shuttle. Evacuating cargo bay is recommended."
	bonus_credits = CARGO_CRATE_VALUE * 225 // High reward for high risk
	logging_desc = "Shuttle with a ticking bomb"

/datum/voidcrew_shuttle_loan/jc_a_bomb/spawn_items(datum/voidcrew_cargo_shuttle/shuttle)
	var/list/cargo_turfs = shuttle.get_cargo_bay_turfs()
	if(!length(cargo_turfs))
		return

	// THE BOMB
	new /obj/machinery/syndicatebomb/shuttle_loan(pick_n_take(cargo_turfs))

	// Instructions (maybe)
	if(length(cargo_turfs))
		if(prob(95))
			new /obj/item/paper/fluff/cargo/bomb(pick_n_take(cargo_turfs))
		else
			new /obj/item/paper/fluff/cargo/bomb/allyourbase(pick_n_take(cargo_turfs))

/// Papers please - Paperwork processing
/datum/voidcrew_shuttle_loan/papers_please
	sender = "Nanotrasen Paperwork Division"
	announcement_text = "A neighboring station needs help handling some paperwork. Could you help process it for us? Payment rendered when stamped papers are returned."
	shuttle_transit_text = "Paperwork incoming."
	thanks_msg = "Paperwork inbound. Payment will be rendered when the stamped papers are returned via cargo shuttle."
	bonus_credits = 0 // Payout is made when stamped papers are returned
	logging_desc = "Paperwork shipment"

/datum/voidcrew_shuttle_loan/papers_please/spawn_items(datum/voidcrew_cargo_shuttle/shuttle)
	var/list/cargo_turfs = shuttle.get_cargo_bay_turfs()
	if(!length(cargo_turfs))
		return

	// Get all paperwork types (excluding photocopies and ancient)
	var/list/paperwork_types = subtypesof(/obj/item/paperwork) - typesof(/obj/item/paperwork/photocopy) - typesof(/obj/item/paperwork/ancient)

	for(var/paperwork_type in paperwork_types)
		if(!length(cargo_turfs))
			break
		new paperwork_type(pick_n_take(cargo_turfs))

/// Russian party - Hostile Russians with a bear
/datum/voidcrew_shuttle_loan/russian_party
	sender = "Nanotrasen Russian Outreach Program"
	announcement_text = "A group of angry Russians want to have a party. Can you send them your cargo shuttle and then... make them disappear? Combat pay included."
	shuttle_transit_text = "Partying Russians incoming."
	thanks_msg = "Party guests inbound. They may be... rowdy."
	bonus_credits = CARGO_CRATE_VALUE * 50
	logging_desc = "Russian party squad"

/datum/voidcrew_shuttle_loan/russian_party/spawn_items(datum/voidcrew_cargo_shuttle/shuttle)
	var/list/cargo_turfs = shuttle.get_cargo_bay_turfs()
	if(!length(cargo_turfs))
		return

	// Party supplies
	var/datum/supply_pack/pack = SSshuttle.supply_packs[/datum/supply_pack/service/party]
	if(pack && length(cargo_turfs))
		pack.generate(pick_n_take(cargo_turfs))

	// The Russians
	if(length(cargo_turfs))
		new /mob/living/basic/trooper/russian(pick_n_take(cargo_turfs))
	if(length(cargo_turfs))
		new /mob/living/basic/trooper/russian/ranged(pick_n_take(cargo_turfs)) // This one drops a mateba
	if(length(cargo_turfs))
		new /mob/living/basic/bear/russian(pick_n_take(cargo_turfs))

	// Chance for more
	if(prob(75) && length(cargo_turfs))
		new /mob/living/basic/trooper/russian(pick_n_take(cargo_turfs))
	if(prob(50) && length(cargo_turfs))
		new /mob/living/basic/bear/russian(pick_n_take(cargo_turfs))

/// Spider gift - Giant spiders from the Spider Clan
/datum/voidcrew_shuttle_loan/spider_gift
	sender = "Nanotrasen Diplomatic Corps"
	announcement_text = "The Spider Clan has sent us a mysterious gift. Can we ship it to you to see what's inside? Combat pay included."
	shuttle_transit_text = "Spider Clan gift incoming."
	thanks_msg = "Gift inbound. Contents... uncertain."
	bonus_credits = CARGO_CRATE_VALUE * 50
	logging_desc = "Shuttle full of spiders"

/datum/voidcrew_shuttle_loan/spider_gift/spawn_items(datum/voidcrew_cargo_shuttle/shuttle)
	var/list/cargo_turfs = shuttle.get_cargo_bay_turfs()
	if(!length(cargo_turfs))
		return

	// Special ops crate (the "gift")
	var/datum/supply_pack/pack = SSshuttle.supply_packs[/datum/supply_pack/imports/specialops]
	if(pack && length(cargo_turfs))
		pack.generate(pick_n_take(cargo_turfs))

	// THE SPIDERS
	if(length(cargo_turfs))
		new /mob/living/basic/spider/giant(pick_n_take(cargo_turfs))
	if(length(cargo_turfs))
		new /mob/living/basic/spider/giant(pick_n_take(cargo_turfs))
	if(length(cargo_turfs))
		new /mob/living/basic/spider/giant/nurse(pick_n_take(cargo_turfs))
	if(prob(50) && length(cargo_turfs))
		new /mob/living/basic/spider/giant/hunter(pick_n_take(cargo_turfs))

	// Victim remains
	if(length(cargo_turfs))
		var/turf/victim_turf = pick_n_take(cargo_turfs)
		new /obj/effect/decal/remains/human(victim_turf)
		new /obj/item/clothing/shoes/jackboots/fast(victim_turf)
		new /obj/item/clothing/mask/balaclava(victim_turf)

	// Spider webs
	for(var/i in 1 to 5)
		if(!length(cargo_turfs))
			break
		new /obj/structure/spider/stickyweb(pick_n_take(cargo_turfs))
