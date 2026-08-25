/**
 * # Deliver Objectives
 *
 * The "bring me X" family: a typed item ask handed over at the mission pad
 * or an outpost trader. One shared implementation covers stacks (consume N
 * off one stack), loose items (counted one hand-over at a time), and the
 * specialty asks (bound quest items, gas tanks, fish).
 */
/datum/mission_objective/deliver
	requires_item = TRUE
	/// The item type that satisfies the ask
	var/required_type
	/// Display name for the ask
	var/required_name = "goods"
	/// How many are asked for. Stacks consume this off one stack in a single
	/// turn-in; loose items are handed over one at a time and counted.
	var/required_amount = 1
	/// Loose-item hand-overs so far
	var/delivered_count = 0

/datum/mission_objective/deliver/reset()
	. = ..()
	delivered_count = 0

/// The ask as a short phrase: "10 iron ore" / "silver ring"
/datum/mission_objective/deliver/proc/describe_ask()
	return required_amount > 1 ? "[required_amount] [required_name]" : required_name

/datum/mission_objective/deliver/get_progress_string()
	if(required_amount > 1 && delivered_count > 0)
		return "Deliver [describe_ask()] ([delivered_count]/[required_amount])"
	return "Deliver [describe_ask()]"

/datum/mission_objective/deliver/can_turn_in(obj/item/item)
	if(!item || !istype(item, required_type))
		return FALSE
	if(isstack(item))
		var/obj/item/stack/stack = item
		if(stack.amount < required_amount)
			return FALSE
	return TRUE

/datum/mission_objective/deliver/matches_ask(obj/item/item)
	return item && required_type && istype(item, required_type)

/datum/mission_objective/deliver/describe_turn_in_failure(obj/item/item)
	if(!item)
		return "No item provided."
	if(!istype(item, required_type))
		return "Wrong item type."
	if(isstack(item))
		var/obj/item/stack/stack = item
		if(stack.amount < required_amount)
			return "Need [required_amount], only have [stack.amount]."
	return ..()

/datum/mission_objective/deliver/accept_item(obj/item/item, atom/reward_anchor)
	// The delivered item is often the mission's tracked quest atom; stop the
	// destruction watch before consuming it, or qdel fires it synchronously and
	// handle_quest_loss() voids the contract mid-turn-in (outpost_quests.dm
	// already forgets-first for the same reason)
	mission?.forget_quest_atom(item)
	if(isstack(item))
		var/obj/item/stack/stack = item
		stack.use(required_amount)
		complete()
		return MISSION_ITEM_COMPLETE
	qdel(item)
	delivered_count++
	if(delivered_count >= required_amount)
		complete()
		return MISSION_ITEM_COMPLETE
	notify_crew("[mission.name]: [delivered_count]/[required_amount] [required_name] received.")
	return MISSION_ITEM_PROGRESS

// =========================================================================
// BOUND ITEM: a specific quest item this mission spawned
// =========================================================================

/**
 * Accepts only an /obj/item/mission_recovery whose binding resolves to this
 * objective's mission, the recovery family's carry-home step.
 */
/datum/mission_objective/deliver/bound
	required_name = "the objective"
	required_amount = 1

/datum/mission_objective/deliver/bound/describe_ask()
	return mission?.objective_name || required_name

/datum/mission_objective/deliver/bound/get_progress_string()
	return "Return the [describe_ask()] to the pad"

/datum/mission_objective/deliver/bound/can_turn_in(obj/item/item)
	if(!istype(item, /obj/item/mission_recovery))
		return FALSE
	var/obj/item/mission_recovery/bound_item = item
	if(bound_item.mission_ref?.resolve() != mission)
		return FALSE
	return bound_item.binding_serial == mission.binding_serial

/datum/mission_objective/deliver/bound/matches_ask(obj/item/item)
	return istype(item, /obj/item/mission_recovery)

/datum/mission_objective/deliver/bound/describe_turn_in_failure(obj/item/item)
	if(!item)
		return "No item provided."
	if(!istype(item, /obj/item/mission_recovery))
		return "Wrong item type."
	var/obj/item/mission_recovery/bound_item = item
	if(bound_item.mission_ref?.resolve() != mission)
		return "That item belongs to a different contract."
	if(bound_item.binding_serial != mission.binding_serial)
		return "That item's contract binding lapsed when the target relocated."
	return ..()

// =========================================================================
// GAS TANK: a tank carrying enough of a specific gas
// =========================================================================

/**
 * Any tank holding at least required_moles of gas_type counts; the tank is
 * consumed with its contents. Same matching pattern as the exotic-gas
 * buyback ledgers (shop_buyback.dm).
 */
/datum/mission_objective/deliver/gas_tank
	required_type = /obj/item/tank
	/// The /datum/gas typepath the tank must carry
	var/gas_type
	/// Minimum moles of that gas in the one offered tank
	var/required_moles = 400

/datum/mission_objective/deliver/gas_tank/describe_ask()
	return "a tank holding [required_moles] mol of [required_name]"

/datum/mission_objective/deliver/gas_tank/get_progress_string()
	return "Deliver [required_moles] mol of [required_name] in one tank"

/datum/mission_objective/deliver/gas_tank/can_turn_in(obj/item/item)
	if(!istype(item, /obj/item/tank))
		return FALSE
	var/obj/item/tank/tank = item
	var/datum/gas_mixture/mix = tank.return_air()
	if(!mix || !(gas_type in mix.moles))
		return FALSE
	return mix.moles[gas_type] >= required_moles

/datum/mission_objective/deliver/gas_tank/describe_turn_in_failure(obj/item/item)
	if(!item)
		return "No item provided."
	if(!istype(item, /obj/item/tank))
		return "The contract wants a gas tank."
	var/obj/item/tank/tank = item
	var/datum/gas_mixture/mix = tank.return_air()
	var/carried = (mix && (gas_type in mix.moles)) ? mix.moles[gas_type] : 0
	return "Tank holds [round(carried)]/[required_moles] mol of [required_name]."

// =========================================================================
// FISH: the angler's ask
// =========================================================================

/**
 * Real fish, optionally over a trophy weight. Counted one hand-over at a
 * time like any loose-item ask.
 */
/datum/mission_objective/deliver/fish
	required_type = /obj/item/fish
	required_name = "fresh fish"
	/// Minimum weight in grams (0 = any fish)
	var/min_weight = 0

/datum/mission_objective/deliver/fish/can_turn_in(obj/item/item)
	if(!..())
		return FALSE
	if(min_weight > 0)
		var/obj/item/fish/offered_fish = item
		if(offered_fish.weight < min_weight)
			return FALSE
	return TRUE

/datum/mission_objective/deliver/fish/describe_turn_in_failure(obj/item/item)
	if(item && istype(item, required_type) && min_weight > 0)
		var/obj/item/fish/offered_fish = item
		if(offered_fish.weight < min_weight)
			return "Too small - [required_name] means [min_weight / 1000] kg or better."
	return ..()

// =========================================================================
// COOKED DISH: the diner's ask
// =========================================================================

/**
 * Real cooking, counted one plate at a time. A dish only counts if somebody's
 * own hands made it — TRAIT_HANDMADE comes off the grill, the oven, the
 * fryer and the crafting menu, never off factory packaging — and if its recipe
 * runs at least min_complexity deep. The outpost diner's own plates carry the
 * same trait from TRAIT_SOURCE_OUTPOST_KITCHEN alone and are refused, so a
 * Kitchen Order can't be settled off Roux's own counter.
 */
/datum/mission_objective/deliver/cooked
	required_type = /obj/item/food
	required_name = "cooked meals"
	/// Minimum crafting_complexity (FOOD_COMPLEXITY_*) for a dish to count
	var/min_complexity = FOOD_COMPLEXITY_2

/datum/mission_objective/deliver/cooked/can_turn_in(obj/item/item)
	if(!..())
		return FALSE
	if(!HAS_TRAIT_NOT_FROM(item, TRAIT_HANDMADE, TRAIT_SOURCE_OUTPOST_KITCHEN))
		return FALSE
	var/obj/item/food/dish = item
	return dish.crafting_complexity >= min_complexity

/datum/mission_objective/deliver/cooked/describe_turn_in_failure(obj/item/item)
	if(item && istype(item, required_type))
		if(!HAS_TRAIT_NOT_FROM(item, TRAIT_HANDMADE, TRAIT_SOURCE_OUTPOST_KITCHEN))
			return "Factory-made won't do - the order wants a dish cooked by hand."
		var/obj/item/food/dish = item
		if(dish.crafting_complexity < min_complexity)
			return "Too simple - the order wants real cooking, not a snack."
	return ..()
