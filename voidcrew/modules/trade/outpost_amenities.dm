/**
 * # Outpost Amenities
 *
 * The "outposts are more than just a shop" furniture: per-zone comforts that
 * live inside the sanctuary interior. Everything here follows the outpost
 * construction rules, indestructible where it's outpost property, and
 * attacking outpost property is aggression.
 *
 * - Med alcove kit (all outposts): stocked first-aid closet + tuned-up sleeper
 * - Rental stash lockers (yellow depot): pay once, locker is yours for the round
 * - Flavor loiterers (one flavor per zone): unkillable NPCs with barks and
 *   zero gameplay hooks, they just stop the room reading as a console farm
 */

// =========================================================================
// MED ALCOVE
// =========================================================================

/**
 * Stocked first-aid closet. Ordinary closet on purpose: the *supplies* are
 * the amenity, and walking off with them is restocking economics, not
 * aggression, only the fixed machinery around it is outpost property.
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
	new /obj/item/stack/medical/wrap/gauze(src) // VOIDCREW: upstream moved gauze under /wrap
	new /obj/item/stack/medical/suture(src)
	new /obj/item/stack/medical/mesh(src)

/**
 * The house sleeper: same machine, torpedo-rated housing. Free to use,
 * the "safe harbor between fights" identity, made of metal.
 *
 * `controls_inside` is the whole point: a solo pilot has nobody outside to
 * press the buttons, and the default sleeper closes the occupant's own UI.
 * The board is kept (not nulled) so `apply_default_parts()` actually runs and
 * the chem list gets populated, sleepers with no servo offer zero chems.
 * It still can't be stripped for parts: `deconstructable` is FALSE, so
 * `/obj/machinery/sleeper/Initialize` deletes the board after parts apply.
 */
/obj/machinery/sleeper/outpost
	name = "outpost recovery sleeper"
	desc = "A heavy-duty sleeper bolted straight into the station frame. The upholstery has seen things."
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	controls_inside = TRUE
	circuit = /obj/item/circuitboard/machine/sleeper/outpost

/**
 * Tier-3 servo, tier-1 bin: full damage-type coverage (libital/aiuri/convermol
 * /multiver) without reaching the tier-4 omnizine, and the stock 20u per-chem
 * cap. A patch-up station between fights, not a fountain. Never built by
 * players, it exists so the mapped machine gets the right parts.
 */
/obj/item/circuitboard/machine/sleeper/outpost
	build_path = /obj/machinery/sleeper/outpost
	req_components = list(
		/datum/stock_part/matter_bin = 1,
		/datum/stock_part/servo/tier3 = 1,
		/obj/item/stack/cable_coil = 1,
		/obj/item/stack/sheet/glass = 2)

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
 * to that ID like a personal closet. Emag-proof and indestructible, the
 * entire product being sold here is "nobody can get at your stuff".
 */
/obj/structure/closet/secure_closet/outpost_rental
	name = "rental stash locker"
	desc = "A torpedo-rated stash locker. Swipe an ID to rent it for the shift. The fee comes off your card, the lock answers to nobody else."
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
	if(id_card) // already rented, the lock handles the rest
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

/**
 * No prying, cutting or deconstructing your way in either.
 *
 * VOIDCREW: this used to be one `tool_interact()` override returning FALSE. Upstream
 * split that proc along two seams, so the single refusal became several:
 * - `item_interaction()` inherited the airlock painter, the electronics install, the
 *   card reader install and — load-bearing — the swipe-an-ID-to-toggle-the-lock branch.
 *   Letting the parent run that last one would eat the swipe before
 *   [/obj/structure/closet/secure_closet/outpost_rental/attackby] ever sees it, and the
 *   locker could never be rented. NONE means "not handled", which is what lets the
 *   attackby chain below run, exactly as `tool_interact() = FALSE` used to.
 * - the electronics screwdriver, the card-reader crowbar and the weld/cut welder each
 *   became their own `*_act()`, reached through `tool_act()` before `item_interaction()`.
 */
/obj/structure/closet/secure_closet/outpost_rental/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	return NONE

/obj/structure/closet/secure_closet/outpost_rental/screwdriver_act(mob/living/user, obj/item/tool)
	return NONE

/obj/structure/closet/secure_closet/outpost_rental/crowbar_act(mob/living/user, obj/item/tool)
	return NONE

/obj/structure/closet/secure_closet/outpost_rental/welder_act(mob/living/user, obj/item/tool)
	return NONE

/obj/structure/closet/secure_closet/outpost_rental/multitool_act(mob/living/user, obj/item/tool)
	return NONE

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
 * attacking one deliberately does NOT trip the embargo, loiterers are
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

	/// Outfit whose worn appearance builds this loiterer's look
	var/outfit_path = /datum/outfit/job/assistant
	/// Lines barked when someone takes a swing at them
	var/list/attacked_lines = list("Hey! Watch it!")
	/// Rate limit on the attacked bark
	COOLDOWN_DECLARE(attacked_bark_cooldown)

/mob/living/basic/outpost_loiterer/Initialize(mapload)
	. = ..()
	apply_dynamic_human_appearance(src, outfit_path = outfit_path)
	// Unkillable, not protected: violence against them is pointless, not punished
	ADD_TRAIT(src, TRAIT_GODMODE, INNATE_TRAIT)
	// move_resist only stops pulling; drag-drops (buckling to beds, stuffing
	// into crates/disposals) never check it, so cancel them at the source.
	RegisterSignal(src, COMSIG_MOUSEDROP_ONTO, PROC_REF(block_being_dragged))

/// Cancels any attempt to drag-drop the loiterer onto something (beds, crates,
/// disposals, ...): they live here now, apparently, and they're staying.
/mob/living/basic/outpost_loiterer/proc/block_being_dragged(atom/over, mob/user)
	SIGNAL_HANDLER
	return COMPONENT_CANCEL_MOUSEDROP_ONTO

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

/**
 * VOIDCREW: `idle_behavior` and the whole `/datum/idle_behavior` family are gone;
 * idle wandering is now a behavior-tree leaf like everything else. These controllers
 * are small enough (one or two leaves, no branching) that they use a flat
 * `behavior_nodes` typepath list rather than a `.bt.json` — `SelectBehaviors()` walks
 * that list in order and stops at the first node returning BT_RUNNING, which is all
 * the structure a loiterer needs.
 */
/datum/ai_controller/basic_controller/outpost_loiterer
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
	)
	ai_traits = PASSIVE_AI_FLAGS
	ai_movement = /datum/ai_movement/basic_avoidance
	behavior_nodes = list(
		/datum/bt_node/ai_behavior/idle_random_walk/outpost_loiterer,
	)

/// Loiterers never wander out of the sanctuary area (or out an airlock)
/datum/bt_node/ai_behavior/idle_random_walk/outpost_loiterer
	walk_chance = 10

/**
 * Upstream's `try_random_step()` verbatim, plus the area gate. It is copied rather
 * than wrapped because the check has to land between picking the destination turf and
 * moving onto it, and the parent does both in one go.
 */
/datum/bt_node/ai_behavior/idle_random_walk/outpost_loiterer/try_random_step(mob/living/living_pawn, seconds_per_tick, step_walk_chance)
	if(LAZYLEN(living_pawn.do_afters))
		return FALSE
	if(!SPT_PROB(step_walk_chance, seconds_per_tick) || !can_move(living_pawn))
		return FALSE
	var/move_dir = pick(GLOB.alldirs)
	var/turf/destination_turf = get_step(living_pawn, move_dir)
	if(!destination_turf?.can_cross_safely(living_pawn))
		return FALSE
	if(!istype(get_area(destination_turf), /area/voidcrew/trader_outpost))
		return FALSE
	living_pawn.Move(destination_turf, move_dir)
	return TRUE

// --- Green: the mechanic haunting Halcyon's repair bay ---

/**
 * Hi-vis, hard hat, insulated gloves and a welder she has not put down in six
 * years. Everything here is the compressor job she is permanently mid-way
 * through, no ID, no radio, nothing that says anyone employs her.
 */
/datum/outfit/outpost_mechanic
	name = "Outpost mechanic"
	uniform = /obj/item/clothing/under/rank/engineering/engineer/hazard
	head = /obj/item/clothing/head/utility/hardhat/orange
	gloves = /obj/item/clothing/gloves/color/yellow
	belt = /obj/item/storage/belt/utility/full
	shoes = /obj/item/clothing/shoes/workboots
	r_hand = /obj/item/weldingtool

/mob/living/basic/outpost_loiterer/mechanic
	name = "outpost mechanic"
	desc = "Permanently mid-job. Nobody has ever seen the job finished."
	gender = FEMALE
	outfit_path = /datum/outfit/outpost_mechanic
	attacked_lines = list(
		"Oi! I'm covered in welding fuel, you maniac!",
		"Swing at the walls if you have to, they're rated for it. I'd rather you didn't swing at me.",
	)
	ai_controller = /datum/ai_controller/basic_controller/outpost_loiterer/mechanic

/**
 * The barks sit *after* the wander leaf on purpose: a `random_speech` leaf reports
 * BT_RUNNING for its one-second cooldown after a successful line, and
 * `SelectBehaviors()` stops at the first BT_RUNNING. Last in the list, that costs
 * nothing; first, it would swallow a second of wandering every time they spoke.
 */
/datum/ai_controller/basic_controller/outpost_loiterer/mechanic
	behavior_nodes = list(
		/datum/bt_node/ai_behavior/idle_random_walk/outpost_loiterer,
		/datum/bt_node/ai_behavior/random_speech/outpost_mechanic,
	)

/datum/bt_node/ai_behavior/random_speech/outpost_mechanic
	speech_chance = 2
	speak = list(
		"Your port thruster sounds wrong. I can hear it from here. Through the hull.",
		"Barnaby says I can't charge for advice, so: free advice, seal your ship.",
		"I've been fixing this same compressor for six years. It's a lifestyle.",
		"You'd be amazed what people leave in the repair bay. Mostly blood.",
		"Green zone's quiet. Too quiet. No, wait. That's the compressor again.",
	)
	emote_see = list("wipes her hands on an oily rag.", "taps a pipe thoughtfully.")

// --- Yellow: the dockhand who has seen every crew type come through ---

/**
 * Hazard vest over a cargo sweater and gauntlets rated for dragging things
 * that don't want to be dragged. The vest is the whole read: on a dock, being
 * seen before you're run over is the job.
 */
/datum/outfit/outpost_dockhand
	name = "Depot dockhand"
	uniform = /obj/item/clothing/under/rank/cargo/tech
	suit = /obj/item/clothing/suit/hazardvest
	gloves = /obj/item/clothing/gloves/cargo_gauntlet
	head = /obj/item/clothing/head/soft/black
	shoes = /obj/item/clothing/shoes/workboots

/mob/living/basic/outpost_loiterer/dockhand
	name = "depot dockhand"
	desc = "Loads crates, unloads opinions."
	outfit_path = /datum/outfit/outpost_dockhand
	attacked_lines = list(
		"Hey! Take it outside. Sarge charges for cleanup and it comes out of MY pay.",
		"You hit like a cargo tech. I'd know.",
	)
	ai_controller = /datum/ai_controller/basic_controller/outpost_loiterer/dockhand

/datum/ai_controller/basic_controller/outpost_loiterer/dockhand
	behavior_nodes = list(
		/datum/bt_node/ai_behavior/idle_random_walk/outpost_loiterer,
		/datum/bt_node/ai_behavior/random_speech/outpost_dockhand,
	)

/datum/bt_node/ai_behavior/random_speech/outpost_dockhand
	speech_chance = 2
	speak = list(
		"Rent a locker. Trust me. The yellow lanes eat cargo bays.",
		"Last crew through here left in a hurry. Their locker's still paid up.",
		"Sarge doesn't sleep. I've checked. Nobody knows how she does it.",
		"I stack crates and I watch the docks. The second part is the job.",
		"Convoy's late again. Convoy's always late. Convoy might be a myth.",
	)
	emote_see = list("counts crates under their breath.", "stretches their back with an audible pop.")

// --- Red: the Dregs cantina's bartender, who has poured for worse ---

/**
 * The Dregs' other apron. Same shirt and slacks as Dram behind the counter,
 * white apron instead of his blue one. She works the floor, he works the bar,
 * and the glass in her hand was already clean.
 */
/datum/outfit/outpost_cantina_bartender
	name = "Cantina bartender"
	uniform = /obj/item/clothing/under/costume/buttondown/slacks/service
	suit = /obj/item/clothing/suit/apron/chef
	shoes = /obj/item/clothing/shoes/laceup
	r_hand = /obj/item/reagent_containers/cup/glass/drinkingglass

/mob/living/basic/outpost_loiterer/bartender
	name = "cantina bartender"
	desc = "Pours drinks in a red-zone bar and has never once asked a follow-up question."
	gender = FEMALE
	outfit_path = /datum/outfit/outpost_cantina_bartender
	attacked_lines = list(
		"HEY. You bleed on my bar, you buy the bar.",
		"Swing again and you're cut off. From drinks AND oxygen, if Vex is feeling helpful.",
	)
	ai_controller = /datum/ai_controller/basic_controller/outpost_loiterer/bartender

/datum/ai_controller/basic_controller/outpost_loiterer/bartender
	behavior_nodes = list(
		/datum/bt_node/ai_behavior/idle_random_walk/outpost_loiterer,
		/datum/bt_node/ai_behavior/random_speech/outpost_bartender,
	)

/datum/bt_node/ai_behavior/random_speech/outpost_bartender
	speech_chance = 2
	speak = list(
		"Dram works the counter. I work the floor. Guess which of us breaks up the fights.",
		"Ice machine's been dead since the last convoy. Everything's warm. So am I.",
		"Two rules. Pay first, and don't lean on the tap handles.",
		"Third stool from the end wobbles. Always has. Sit somewhere else.",
		"Glasses go back on the bar, not the floor. I sweep, and I remember who made me sweep.",
	)
	emote_see = list("polishes a glass that was already clean.", "restacks the same three bottles.")

// --- Red: the off-duty pirate who considers the Undertow neutral ground ---

/**
 * Full kit minus the parts that matter: coat, boots and cutlass, but a bandana
 * instead of the hat and no armor anywhere. Dressed to be recognized as a
 * pirate by people who are not currently being robbed by one.
 */
/datum/outfit/outpost_off_duty_pirate
	name = "Off-duty pirate"
	uniform = /obj/item/clothing/under/costume/pirate
	suit = /obj/item/clothing/suit/costume/pirate
	head = /obj/item/clothing/head/costume/pirate/bandana
	shoes = /obj/item/clothing/shoes/pirate
	r_hand = /obj/item/claymore/cutlass

/mob/living/basic/outpost_loiterer/off_duty_pirate
	name = "off-duty pirate"
	desc = "Off duty, and about as relaxed as a pirate gets. The cutlass is mostly decorative."
	outfit_path = /datum/outfit/outpost_off_duty_pirate
	attacked_lines = list(
		"Ha! In the Undertow? Vex would skin you if I were worth skinning.",
		"Save it for the docks, friend. In here we drink.",
	)
	ai_controller = /datum/ai_controller/basic_controller/outpost_loiterer/off_duty_pirate

/datum/ai_controller/basic_controller/outpost_loiterer/off_duty_pirate
	behavior_nodes = list(
		/datum/bt_node/ai_behavior/idle_random_walk/outpost_loiterer,
		/datum/bt_node/ai_behavior/random_speech/outpost_pirate,
	)

/datum/bt_node/ai_behavior/random_speech/outpost_pirate
	speech_chance = 2
	speak = list(
		"Everyone's armed in the red zone. That's why it's polite here.",
		"My captain thinks I'm out resupplying. I am. Slowly.",
		"The turrets only shoot rude people. Beautiful system. No survivors... I mean, no complaints.",
		"Shore leave's four days. Two getting here, one drinking, one regretting it.",
		"You didn't see me here. I'm not here. Nobody's ever here.",
	)
	emote_see = list("polishes a decorative cutlass.", "eyes your ship through the viewport.")

// =========================================================================
// GREENHOUSE
// =========================================================================

/**
 * Indestructible grass for outpost conservatories: same sprite family as
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
	tiled_turf = FALSE // VOIDCREW: tiled_dirt was renamed tiled_turf upstream

// =========================================================================
// FISHING POND
// =========================================================================

/**
 * Halcyon's indoor fishing hole. Nobody approved it; it's load-bearing now.
 * Water can't be pried up or scraped away (baseturfs is itself, all the way
 * down), so the sanctuary stays sealed no matter what happens to the pond.
 * Stocked with honest river fish: Pike insists they arrive through the
 * water recyclers.
 */
/turf/open/water/outpost_pond
	name = "waystation pond"
	desc = "A pond sunk straight into the deck plating. The fish are real and the water is warmer than you'd expect. Nobody has confirmed the koi."
	baseturfs = /turf/open/water/outpost_pond
	planetary_atmos = FALSE

// =========================================================================
// FIXED KITCHEN GEAR
// =========================================================================

/**
 * The cook's line and the shop fridges. Stock tg kitchen machines are built to be
 * taken apart, a crowbar alone reduces a griddle or a range to a frame, since
 * both pass ignore_panel to default_deconstruction_crowbar, and none of them
 * register aggression, so the diner could be stripped to bare frames without the
 * turrets ever reacting. These are the same machines with the outpost's own
 * construction rules applied.
 *
 * Cooking is untouched: only the tool and part-swap paths are closed, so a visiting
 * chef can still use every one of them normally. Contents are fair game as ever.
 * Food walking out of a fridge is restocking economics, the same call the med
 * alcove makes.
 */
/obj/machinery/griddle/outpost
	desc = "A flat-top griddle welded to the deck frame. The house owns it; you're welcome to cook on it."
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/obj/machinery/griddle/outpost/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/machinery/oven/range/outpost
	desc = "A gas range bolted into the deck frame. Runs hot, runs constantly, and isn't going anywhere."
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/obj/machinery/oven/range/outpost/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/machinery/processor/outpost
	desc = "An industrial food processor anchored to the deck frame. Keep hands clear of the intake."
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/obj/machinery/processor/outpost/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/machinery/deepfryer/outpost
	desc = "A deep fryer plumbed straight into the deck. The oil is changed more often than you'd expect."
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/obj/machinery/deepfryer/outpost/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/machinery/microwave/outpost
	desc = "A microwave bolted to the counter. Scratched, scorched, and still working."
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/obj/machinery/microwave/outpost/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/machinery/smartfridge/food/outpost
	desc = "A refrigerated storage unit welded to the deck. Take what you're buying."
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/obj/machinery/smartfridge/food/outpost/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/machinery/smartfridge/organ/outpost
	desc = "A refrigerated organ locker welded to the deck. The Undertow does not discuss its supply chain."
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/obj/machinery/smartfridge/organ/outpost/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)
