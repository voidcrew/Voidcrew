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
 * - Outpost crew outfits: the mechanic and off-duty pirate looks reused by the
 *   ambient mechanic role and NPC-ship bounty companions
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
	new /obj/item/stack/medical/gauze(src)
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
	// Bolted to the depot floor: nobody drags a rented locker into the elevator
	anchored = TRUE
	anchorable = FALSE
	move_resist = INFINITY
	// Nobody hides inside one; a locked-in person could never get out
	divable = FALSE

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
	metric_outpost_service("locker_rental", user, src, OUTPOST_LOCKER_RENTAL_FEE, 0, type)
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

// No prying, cutting or deconstructing your way in either. An open locker takes
// whatever is clicked into it, like any other closet.
/obj/structure/closet/secure_closet/outpost_rental/tool_interact(obj/item/weapon, mob/living/user)
	if(!opened || user.combat_mode)
		return FALSE
	user.transfer_item_to_turf(weapon, drop_location())
	return TRUE

/obj/structure/closet/secure_closet/outpost_rental/bust_open()
	return

// Knock does not open a lock the outpost guarantees
/obj/structure/closet/secure_closet/outpost_rental/on_magic_unlock(datum/source, datum/action/cooldown/spell/aoe/knock/spell, atom/caster)
	SIGNAL_HANDLER
	return

// Items only: a person shut in a rented locker could never get out
/obj/structure/closet/secure_closet/outpost_rental/insertion_allowed(atom/movable/AM)
	if(ismob(AM))
		return FALSE
	return ..()

// Shoves and anything else that puts a mob straight inside land it back on the tile
/obj/structure/closet/secure_closet/outpost_rental/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	if(ismob(arrived))
		arrived.forceMove(drop_location())

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
// OUTPOST CREW OUTFITS
// =========================================================================

// Worn looks reused by ambient NPCs: the mechanic role at Halcyon, and
// NPC-ship bounty companions in the off-duty pirate look.

// --- Green: the mechanics keeping Halcyon running ---

/**
 * Hi-vis, a welding hard hat, insulated gloves and a full tool belt: everything for the
 * compressor job she is permanently mid-way through. No ID, no radio, nothing that says anyone
 * employs her. The other outfits are the rest of the crew; each mechanic wears one of them.
 * Hands stay empty: a mechanic picks up a welder or a wrench only to work (outpost_ambient_work.dm).
 */
/datum/outfit/outpost_mechanic
	name = "Outpost mechanic"
	uniform = /obj/item/clothing/under/rank/engineering/engineer/hazard
	head = /obj/item/clothing/head/utility/hardhat/welding/orange
	gloves = /obj/item/clothing/gloves/color/yellow
	belt = /obj/item/storage/belt/utility/full
	shoes = /obj/item/clothing/shoes/workboots

/// Laborer's overalls and a proper welding helmet
/datum/outfit/outpost_mechanic/overalls
	name = "Outpost mechanic (overalls)"
	uniform = /obj/item/clothing/under/misc/overalls
	head = /obj/item/clothing/head/utility/welding
	gloves = /obj/item/clothing/gloves/color/black
	belt = /obj/item/storage/belt/utility

/// A hazard vest over plain engineering blues, goggles pushed up on a yellow hard hat
/datum/outfit/outpost_mechanic/hivis
	name = "Outpost mechanic (hi-vis)"
	uniform = /obj/item/clothing/under/rank/engineering/engineer
	suit = /obj/item/clothing/suit/hazardvest
	head = /obj/item/clothing/head/utility/hardhat
	glasses = /obj/item/clothing/glasses/welding

/// Coveralls over a grey jumpsuit and a beanie. Welding goggles for the hot work.
/datum/outfit/outpost_mechanic/coveralls
	name = "Outpost mechanic (coveralls)"
	uniform = /obj/item/clothing/under/color/grey
	suit = /obj/item/clothing/suit/apron/overalls
	head = /obj/item/clothing/head/beanie/orange
	glasses = /obj/item/clothing/glasses/welding
	gloves = /obj/item/clothing/gloves/fingerless
	belt = /obj/item/storage/belt/utility

/// The atmos hand: blue welding hard hat, atmos jumpsuit
/datum/outfit/outpost_mechanic/atmos
	name = "Outpost mechanic (atmos)"
	uniform = /obj/item/clothing/under/rank/engineering/atmospheric_technician
	head = /obj/item/clothing/head/utility/hardhat/welding/dblue
	gloves = /obj/item/clothing/gloves/color/black

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
	tiled_dirt = FALSE

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
