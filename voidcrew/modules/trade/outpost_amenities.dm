/**
 * # Outpost Amenities
 *
 * The "outposts are more than just a shop" furniture: per-zone comforts that
 * live inside the sanctuary interior. Everything here follows the outpost
 * construction rules — indestructible where it's outpost property, and
 * attacking outpost property is aggression.
 *
 * - Med alcove kit (all outposts): stocked first-aid closet + tuned-up sleeper
 * - Rental stash lockers (yellow depot): pay once, locker is yours for the round
 * - Flavor loiterers (one flavor per zone): unkillable NPCs with barks and
 *   zero gameplay hooks — they just stop the room reading as a console farm
 */

// =========================================================================
// MED ALCOVE
// =========================================================================

/**
 * Stocked first-aid closet. Ordinary closet on purpose: the *supplies* are
 * the amenity, and walking off with them is restocking economics, not
 * aggression — only the fixed machinery around it is outpost property.
 */
/obj/structure/closet/outpost_medical
	name = "outpost first-aid locker"
	desc = "A well-stocked courtesy locker. A laminated note reads: 'Take what you need. We restock. Bleeding in the shop is bad for business.'"
	icon_state = "med"

/obj/structure/closet/outpost_medical/PopulateContents()
	..()
	new /obj/item/storage/medkit/regular(src)
	new /obj/item/storage/medkit/brute(src)
	new /obj/item/storage/medkit/fire(src)
	new /obj/item/reagent_containers/hypospray/medipen(src)
	new /obj/item/reagent_containers/hypospray/medipen(src)
	new /obj/item/stack/medical/gauze(src)
	new /obj/item/stack/medical/suture(src)
	new /obj/item/stack/medical/mesh(src)

/**
 * The house sleeper: same machine, torpedo-rated housing. Free to use —
 * the "safe harbor between fights" identity, made of metal.
 */
/obj/machinery/sleeper/outpost
	name = "outpost recovery sleeper"
	desc = "A heavy-duty sleeper bolted straight into the station frame. The upholstery has seen things."
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	circuit = null

/obj/machinery/sleeper/outpost/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force)
		var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
		outpost?.register_aggression(user)
	return ..()

/obj/machinery/sleeper/outpost/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	if(isliving(hitting_projectile.firer))
		var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
		outpost?.register_aggression(hitting_projectile.firer)
	return ..()

// =========================================================================
// RENTAL STASH LOCKERS (yellow depot)
// =========================================================================

/// What a round-long stash locker costs, charged to the swiped ID
#define OUTPOST_LOCKER_RENTAL_FEE 150

/**
 * Pay-to-stash locker: swipe an ID to rent it for the round, then it locks
 * to that ID like a personal closet. Emag-proof and indestructible — the
 * entire product being sold here is "nobody can get at your stuff".
 */
/obj/structure/closet/secure_closet/outpost_rental
	name = "rental stash locker"
	desc = "A torpedo-rated stash locker. Swipe an ID to rent it for the shift — the fee comes off your card, the lock answers to nobody else."
	locked = FALSE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	can_install_electronics = FALSE
	access_choices = null // no card reader shenanigans; rental is the only flow
	req_access = null

/obj/structure/closet/secure_closet/outpost_rental/PopulateContents()
	return // rented empty

/obj/structure/closet/secure_closet/outpost_rental/examine(mob/user)
	. = ..()
	if(!id_card)
		. += span_notice("Rental fee: [OUTPOST_LOCKER_RENTAL_FEE] credits, charged to the swiped ID.")

/// Renting: swipe any ID while it's unclaimed
/obj/structure/closet/secure_closet/outpost_rental/attackby(obj/item/weapon, mob/living/user, list/modifiers, list/attack_modifiers)
	var/obj/item/card/id/id = weapon.GetID()
	if(isnull(id) || opened || broken)
		return ..()
	if(id_card) // already rented — the lock handles the rest
		balloon_alert(user, "already rented!")
		return TRUE
	var/datum/bank_account/account = id.registered_account
	if(!account)
		balloon_alert(user, "no account on ID!")
		return TRUE
	if(!account.adjust_money(-OUTPOST_LOCKER_RENTAL_FEE, "Trader Outpost: locker rental"))
		balloon_alert(user, "insufficient credits!")
		return TRUE
	id_card = WEAKREF(id)
	name = "[id.registered_name]'s stash locker"
	desc = "A torpedo-rated stash locker, rented for the shift by [id.registered_name]. The management guarantees the lock, not the contents' legality."
	locked = TRUE
	play_closet_lock_sound()
	balloon_alert(user, "rented!")
	playsound(src, 'sound/effects/cashregister.ogg', 40, TRUE)
	update_appearance()
	return TRUE

// The lock is the product; no sequencer exceptions
/obj/structure/closet/secure_closet/outpost_rental/emag_act(mob/user, obj/item/card/emag/emag_card)
	balloon_alert(user, "the lock shrugs it off!")
	return FALSE

// No prying, cutting or deconstructing your way in either
/obj/structure/closet/secure_closet/outpost_rental/tool_interact(obj/item/weapon, mob/living/user)
	return FALSE

/obj/structure/closet/secure_closet/outpost_rental/bust_open()
	return

// Attacking one is attacking outpost property
/obj/structure/closet/secure_closet/outpost_rental/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force && isliving(user))
		var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
		outpost?.register_aggression(user)
	return ..()

/obj/structure/closet/secure_closet/outpost_rental/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	if(isliving(hitting_projectile.firer))
		var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
		outpost?.register_aggression(hitting_projectile.firer)
	return ..()

#undef OUTPOST_LOCKER_RENTAL_FEE

// =========================================================================
// FLAVOR LOITERERS
// =========================================================================

/**
 * A non-hostile NPC who hangs around the outpost and talks to nobody in
 * particular. No gameplay hook. Unkillable (godmode) rather than protected:
 * attacking one deliberately does NOT trip the embargo — loiterers are
 * squatters, not outpost property, and the swing accomplishes nothing anyway.
 */
/mob/living/basic/outpost_loiterer
	name = "loiterer"
	desc = "They live here now, apparently."
	icon = 'icons/mob/simple/simple_human.dmi'
	unique_name = FALSE
	combat_mode = FALSE
	mob_biotypes = MOB_ORGANIC | MOB_HUMANOID
	sentience_type = SENTIENCE_HUMANOID
	move_resist = MOVE_FORCE_VERY_STRONG // no dragging them out to space
	density = TRUE
	basic_mob_flags = NONE
	ai_controller = /datum/ai_controller/basic_controller/outpost_loiterer

	/// Corpse spawner whose outfit builds this loiterer's look
	var/spawner_path = /obj/effect/mob_spawn/corpse/human/generic_assistant
	/// Lines barked when someone takes a swing at them
	var/list/attacked_lines = list("Hey! Watch it!")
	/// Rate limit on the attacked bark
	COOLDOWN_DECLARE(attacked_bark_cooldown)

/mob/living/basic/outpost_loiterer/Initialize(mapload)
	. = ..()
	apply_dynamic_human_appearance(src, mob_spawn_path = spawner_path)
	// Unkillable, not protected: violence against them is pointless, not punished
	ADD_TRAIT(src, TRAIT_GODMODE, INNATE_TRAIT)

/mob/living/basic/outpost_loiterer/proc/bark_attacked()
	if(!COOLDOWN_FINISHED(src, attacked_bark_cooldown))
		return
	COOLDOWN_START(src, attacked_bark_cooldown, 5 SECONDS)
	say(pick(attacked_lines))

/mob/living/basic/outpost_loiterer/attackby(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	. = ..()
	if(attacking_item.force)
		bark_attacked()

/mob/living/basic/outpost_loiterer/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	. = ..()
	bark_attacked()

/mob/living/basic/outpost_loiterer/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(user.combat_mode)
		bark_attacked()

/datum/ai_controller/basic_controller/outpost_loiterer
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
	)
	ai_traits = PASSIVE_AI_FLAGS
	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = /datum/idle_behavior/idle_random_walk/outpost_loiterer

/// Loiterers never wander out of the sanctuary area (or out an airlock)
/datum/idle_behavior/idle_random_walk/outpost_loiterer
	walk_chance = 10

/datum/idle_behavior/idle_random_walk/outpost_loiterer/perform_idle_behavior(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/living_pawn = controller.pawn
	if(LAZYLEN(living_pawn.do_afters))
		return FALSE
	if(SPT_PROB(walk_chance, seconds_per_tick) && (living_pawn.mobility_flags & MOBILITY_MOVE) && isturf(living_pawn.loc) && !living_pawn.pulledby)
		var/move_dir = pick(GLOB.alldirs)
		var/turf/destination_turf = get_step(living_pawn, move_dir)
		if(!destination_turf?.can_cross_safely(living_pawn))
			return FALSE
		if(!istype(get_area(destination_turf), /area/voidcrew/trader_outpost))
			return FALSE
		living_pawn.Move(destination_turf, move_dir)
	return TRUE

// --- Green: the mechanic haunting Halcyon's repair bay ---

/mob/living/basic/outpost_loiterer/mechanic
	name = "outpost mechanic"
	desc = "Permanently mid-job. Nobody has ever seen the job finished."
	gender = FEMALE
	spawner_path = /obj/effect/mob_spawn/corpse/human/engineer
	attacked_lines = list(
		"Oi! I'm covered in welding fuel, you maniac!",
		"Swing at the walls, they're rated for it. I'm not. Well. Actually.",
	)
	ai_controller = /datum/ai_controller/basic_controller/outpost_loiterer/mechanic

/datum/ai_controller/basic_controller/outpost_loiterer/mechanic
	planning_subtrees = list(
		/datum/ai_planning_subtree/random_speech/outpost_mechanic,
	)

/datum/ai_planning_subtree/random_speech/outpost_mechanic
	speech_chance = 2
	speak = list(
		"Your port thruster sounds wrong. I can hear it from here. Through the hull.",
		"Barnaby says I can't charge for advice, so: free advice, seal your ship.",
		"I've been fixing this same compressor for six years. It's a lifestyle.",
		"You'd be amazed what people leave in the repair bay. Mostly blood.",
		"Green zone's quiet. Too quiet. No, wait — that's the compressor again.",
	)
	emote_see = list("wipes her hands on an oily rag.", "taps a pipe thoughtfully.")

// --- Yellow: the dockhand who has seen every crew type come through ---

/mob/living/basic/outpost_loiterer/dockhand
	name = "depot dockhand"
	desc = "Loads crates, unloads opinions."
	spawner_path = /obj/effect/mob_spawn/corpse/human/cargo_tech
	attacked_lines = list(
		"Hey! Take it outside — Sarge charges for cleanup and it comes out of MY pay.",
		"You hit like a cargo tech. I'd know.",
	)
	ai_controller = /datum/ai_controller/basic_controller/outpost_loiterer/dockhand

/datum/ai_controller/basic_controller/outpost_loiterer/dockhand
	planning_subtrees = list(
		/datum/ai_planning_subtree/random_speech/outpost_dockhand,
	)

/datum/ai_planning_subtree/random_speech/outpost_dockhand
	speech_chance = 2
	speak = list(
		"Rent a locker. Trust me. The yellow lanes eat cargo bays.",
		"Last crew through here left in a hurry. Their locker's still paid up.",
		"Sarge doesn't sleep. I've checked. It's a hologram thing.",
		"I stack crates and I watch the docks. The second part is the job.",
		"Convoy's late again. Convoy's always late. Convoy might be a myth.",
	)
	emote_see = list("counts crates under his breath.", "stretches his back with an audible pop.")

// --- Red: the Dregs cantina's bartender, who has poured for worse ---

/mob/living/basic/outpost_loiterer/bartender
	name = "cantina bartender"
	desc = "Pours drinks in a red-zone bar and has never once asked a follow-up question."
	gender = FEMALE
	spawner_path = /obj/effect/mob_spawn/corpse/human/bartender
	attacked_lines = list(
		"HEY. You bleed on my bar, you buy the bar.",
		"Swing again and you're cut off. From drinks AND oxygen, if Vex is feeling helpful.",
	)
	ai_controller = /datum/ai_controller/basic_controller/outpost_loiterer/bartender

/datum/ai_controller/basic_controller/outpost_loiterer/bartender
	planning_subtrees = list(
		/datum/ai_planning_subtree/random_speech/outpost_bartender,
	)

/datum/ai_planning_subtree/random_speech/outpost_bartender
	speech_chance = 2
	speak = list(
		"What'll it be? We have beer, and we have questions I won't ask.",
		"The regulars are pirates, the pirates are regular. It evens out.",
		"Vex doesn't drink. Holograms. Tragic, really.",
		"Someone paid their tab in raw telecrystal once. Kept the lights on for a month.",
		"You want intel, buy a rumor at the terminal. You want the TRUTH? Beer first.",
	)
	emote_see = list("polishes a glass that was already clean.", "restacks the same three bottles.")

// --- Red: the off-duty pirate who considers the Undertow neutral ground ---

/mob/living/basic/outpost_loiterer/off_duty_pirate
	name = "off-duty pirate"
	desc = "Off duty. The cutlass is decorative. The scars aren't."
	spawner_path = /obj/effect/mob_spawn/corpse/human/pirate
	attacked_lines = list(
		"Ha! In the Undertow? Vex would skin you if I were worth skinning.",
		"Save it for the docks, friend. In here we drink.",
	)
	ai_controller = /datum/ai_controller/basic_controller/outpost_loiterer/off_duty_pirate

/datum/ai_controller/basic_controller/outpost_loiterer/off_duty_pirate
	planning_subtrees = list(
		/datum/ai_planning_subtree/random_speech/outpost_pirate,
	)

/datum/ai_planning_subtree/random_speech/outpost_pirate
	speech_chance = 2
	speak = list(
		"Everyone's armed in the red zone. That's why it's polite here.",
		"I sold Vex a fleet admiral's flagship once. Or maybe Vex sold it to me. Long night.",
		"The turrets only shoot rude people. Beautiful system. No survivors— I mean, no complaints.",
		"Best drink this side of the sun is two zones that way. Don't go. Not worth it.",
		"You didn't see me here. I'm not here. Nobody's ever here.",
	)
	emote_see = list("polishes a decorative cutlass.", "eyes your ship through the viewport.")

// =========================================================================
// GREENHOUSE
// =========================================================================

/**
 * Indestructible grass for outpost conservatories — same sprite family as
 * /turf/open/floor/grass, but outpost property. Map icon_state grass1-3 for
 * variety (the destructible turf randomizes at init; this one stays put).
 */
/turf/open/indestructible/grass
	name = "grass"
	desc = "Real grass, grown over reinforced substrate. Somebody waters this every day."
	icon_state = "grass1"
	footstep = FOOTSTEP_GRASS
	barefootstep = FOOTSTEP_GRASS
	clawfootstep = FOOTSTEP_GRASS
	tiled_dirt = FALSE
