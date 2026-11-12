/**
 * # Outpost floors: NPC customers and patrons
 *
 * Owner: P11 (spec 3b.6, 12; L23, L36). Customers come up to an Open floor whose shop is open while one of its
 * people or hands is there, buy one cheap thing at a sale point and leave. One who buys food or a drink sits down and
 * really consumes it. Every NPC sale on a floor draws on the one budget here (A64, A76): OUTPOST_FLOOR_NPC_ITEM_MAX an
 * item, OUTPOST_FLOOR_NPC_BUDGET per OUTPOST_FLOOR_NPC_BUDGET_WINDOW, kept as a "ready at" time so that no toggle,
 * re-placed shop or extra till raises it. The sale itself is P12's (npc_buy()). Strings: strings/floor_customers.json.
 *
 * How a visit goes:
 * - The building's directory board (floor_directory.dm) ticks each of its outpost's floors every few seconds
 *   (npc_custom_tick()). A customer comes no sooner than OUTPOST_FLOOR_NPC_VISIT_LOW to _HIGH after the last, and only
 *   while npc_custom_denial() has nothing against it: an Open floor, its shop open, one of its people or hands on the
 *   floor (A64), a free tile in the lift alcove, room under the outpost's ambient cap (A47), and a sale point a visitor
 *   can walk to from the lift by doors that let anyone through (A96: the route is searched once a visit, over the
 *   floor's rectangle only; no route, no customer).
 * - They step out of the lift (the floor's chime, P8), walk to a sale point, look it over and buy one thing with
 *   npc_buy() when the budget covers it (it is too dear for them otherwise), then walk back to the lift and go.
 * - A patron (L36): what they bought is food or a drink. They find a free chair within OUTPOST_FLOOR_PATRON_SEAT_RANGE,
 *   at a table if there is one, sit, and eat or drink it bite by bite through tg's own eating and drinking (the food's
 *   own bite, the cup's own gulp: the reagents go into them), set the empty down on the table and go.
 *
 * Customers are ordinary ambient NPCs: killable, cuffable, robbable, with nothing more than every ambient outpost NPC
 * has. Their place (/datum/ambient_place/outpost_floor) keeps them on their floor, takes their dropped cash out of the
 * outpost's cash cap (AMBIENT_OUTPOST_CASH_CAP) and makes a killing keep the floor's next customer away for
 * AMBIENT_OUTPOST_KILLED_SLOT_TIME (A47, A74, A87). What they leave with goes with them; killed, it drops with them.
 */

#define FLOOR_CUSTOMERS_STRINGS_FILE "voidcrew/modules/trade_floors/strings/floor_customers.json"
/// How often the board looks a floor over for custom
#define FLOOR_CUSTOMER_TICK (5 SECONDS)
/// How long a floor with no way to a sale point waits before it is searched again
#define FLOOR_CUSTOMER_NO_ROUTE_WAIT (1 MINUTES)
/// Customers on one floor at once
#define FLOOR_CUSTOMERS_AT_ONCE 2
/// Sale points one customer looks over
#define FLOOR_CUSTOMER_LOOKS 2
/// The longest a customer stays, whatever they are at
#define FLOOR_CUSTOMER_STAY (9 MINUTES)
/// How long they look a sale point over before they make up their mind
#define FLOOR_CUSTOMER_BROWSE_LOW (5 SECONDS)
#define FLOOR_CUSTOMER_BROWSE_HIGH (12 SECONDS)
/// How long they stand there after
#define FLOOR_CUSTOMER_LINGER_LOW (3 SECONDS)
#define FLOOR_CUSTOMER_LINGER_HIGH (8 SECONDS)
/// Between two bites or gulps
#define FLOOR_PATRON_BITE_LOW (8 SECONDS)
#define FLOOR_PATRON_BITE_HIGH (15 SECONDS)
/// The longest a patron sits over one thing; what is left goes with them
#define FLOOR_PATRON_SIT_MAX (4 MINUTES)
/// Fuller than this (tg's get_fullness()) and a patron leaves the rest
#define FLOOR_PATRON_FULL 550
/// Where a customer is in their visit
#define FLOOR_VISIT_SHOPPING "shopping"
#define FLOOR_VISIT_EATING "eating"
#define FLOOR_VISIT_DONE "done"

/datum/outpost_floor
	/// The NPC budget's "ready at" time: from this world.time the budget is full (A64, A76). Spending moves it on.
	var/npc_ready_at = 0
	/// world.time the next customer may come, or 0 before the first is planned
	var/npc_next_visit = 0
	/// world.time the board last looked this floor over for custom
	var/npc_ticked_at = 0
	/// The ambient place this floor's customers belong to, made with the first of them
	var/datum/ambient_place/outpost_floor/npc_place

// ===== THE BUDGET =====

/// Credits NPC custom may still spend on this floor now: OUTPOST_FLOOR_NPC_BUDGET at most, coming back at that much a
/// window. One clock a floor, so nothing about the shop, its tills, its hands or the floor's settings raises it.
/datum/outpost_floor/proc/npc_budget_left()
	var/budget = OUTPOST_FLOOR_NPC_BUDGET
	if(budget <= 0)
		return 0
	var/until_full = npc_ready_at - world.time
	if(until_full <= 0)
		return budget
	return clamp(round((OUTPOST_FLOOR_NPC_BUDGET_WINDOW - until_full) * budget / OUTPOST_FLOOR_NPC_BUDGET_WINDOW), 0, budget)

/// Takes `amount` from the budget. FALSE, and nothing taken, when it is not all there or is more than an NPC pays for
/// one thing (OUTPOST_FLOOR_NPC_ITEM_MAX).
/datum/outpost_floor/proc/npc_budget_spend(amount)
	var/budget = OUTPOST_FLOOR_NPC_BUDGET
	if(!isnum(amount) || amount <= 0 || budget <= 0 || amount > OUTPOST_FLOOR_NPC_ITEM_MAX || amount > npc_budget_left())
		return FALSE
	// The budget is full again as much later as the amount takes to come back
	npc_ready_at = max(npc_ready_at, world.time) + amount * OUTPOST_FLOOR_NPC_BUDGET_WINDOW / budget
	return TRUE

// ===== WHETHER A CUSTOMER COMES =====

/**
 * Why no customer may come up now, or null when one may: "unlet", "setting", "shut", "unminded", "alcove", "full" or
 * "route". Cheap checks first; the route search last, and only with `check_route`. `present` and `points` stand in for
 * who is on the floor and the floor's sale points (tests); null asks the game.
 */
/datum/outpost_floor/proc/npc_custom_denial(list/present, list/points, check_route = TRUE)
	if(state != OUTPOST_FLOOR_STATE_OWNED || QDELETED(host) || length(bounds) < 5 || !length(alcove_turfs))
		return "unlet"
	if(entry_policy != OUTPOST_FLOOR_ENTRY_OPEN)
		return "setting"
	if(!shop_open())
		return "shut"
	if(!npc_minded(present))
		return "unminded"
	if(!npc_arrival_turf())
		return "alcove"
	if(npc_outpost_full())
		return "full"
	if(check_route && !length(npc_points_in_reach(npc_reach(), isnull(points) ? npc_sale_points() : points)))
		return "route"
	return null

/// Whether one of the floor's own people or its hands is on the floor, alive, with a player at the controls (A64).
/// `present` stands in for the floor's client mobs (tests).
/datum/outpost_floor/proc/npc_minded(list/present)
	if(isnull(present))
		if(!length(alcove_turfs))
			return FALSE
		present = outpost_site_clients(alcove_turfs[1])
	for(var/mob/living/person in present)
		if(person.stat == DEAD || !contains_turf(get_turf(person)))
			continue
		if(is_member(person) || is_hand(person))
			return TRUE
	return FALSE

/// A free tile of the lift alcove to step out on, or null while the alcove is taken
/datum/outpost_floor/proc/npc_arrival_turf()
	for(var/turf/alcove as anything in shuffle(alcove_turfs.Copy()))
		if(!alcove.is_blocked_turf(exclude_mobs = FALSE))
			return alcove
	return null

/// Whether the outpost already has as many ambient NPCs as it may: its concourse's and every floor's together (A47)
/datum/outpost_floor/proc/npc_outpost_full()
	return outpost_floor_ambient_count(outpost) >= AMBIENT_OUTPOST_TRANSIENT_CAP

/**
 * Living ambient NPCs of `outpost`: its concourse's and every floor's (customers, patrons, fitters). The one count the
 * outpost's cap is held to by the concourse (SSambient_npcs), the customers and the fitters alike (A47).
 */
/proc/outpost_floor_ambient_count(obj/structure/overmap/trader_outpost/outpost)
	. = 0
	if(QDELETED(outpost))
		return
	var/datum/ambient_place/outpost/concourse = SSambient_npcs.outposts[outpost]
	if(concourse)
		. += length(concourse.living_npcs())
	. += outpost_floor_npc_count(outpost)

/// Living ambient NPCs up on `outpost`'s floors: customers and patrons (npc_place) and fitters (life_place)
/proc/outpost_floor_npc_count(obj/structure/overmap/trader_outpost/outpost)
	. = 0
	for(var/datum/outpost_floor/floor in outpost?.floors)
		if(floor.npc_place)
			. += length(floor.npc_place.living_npcs())
		if(floor.life_place)
			. += length(floor.life_place.living_npcs())

/**
 * Every tile a visitor could walk to from `start` (the first alcove tile if null) on this floor, by doors that let
 * anyone through, as turf = TRUE. Searched over the floor's own rectangle only, so a maze costs no more than an empty
 * deck (A96). Anything dense on a tile (a table, a counter, a machine) is not walked over.
 */
/datum/outpost_floor/proc/npc_reach(turf/start)
	. = list()
	if(!start && length(alcove_turfs))
		start = alcove_turfs[1]
	if(!contains_turf(start))
		return
	.[start] = TRUE
	var/list/turf/queue = list(start)
	var/index = 1
	while(index <= length(queue))
		var/turf/here = queue[index]
		index++
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(here, direction)
			if(!next || .[next] || !contains_turf(next) || !npc_step_ok(here, next))
				continue
			.[next] = TRUE
			queue += next

/// Whether a visitor steps from `here` onto its neighbour `next`: the outpost door rules for no one in particular (a
/// Public door, or a keyed door's free side), no door that wants an ID, and nothing dense on `next`
/datum/outpost_floor/proc/npc_step_ok(turf/here, turf/next)
	if(!outpost_door_step_ok(here, next))
		return FALSE
	for(var/obj/thing in next)
		if(thing.flags_1 & ON_BORDER_1)
			continue
		if(istype(thing, /obj/machinery/door))
			if(!istype(thing, /obj/machinery/door/firedoor) && !thing.check_access(null))
				return FALSE
			continue
		if(thing.density)
			return FALSE
	return TRUE

/// Of `points`, those a visitor walking `reach` could buy at: each with a tile in reach right beside it
/datum/outpost_floor/proc/npc_points_in_reach(list/reach, list/points)
	. = list()
	for(var/atom/point as anything in points)
		if(!QDELETED(point) && npc_stand_tile(point, reach))
			. += point

/**
 * A free tile of `reach` right beside `point` with nothing between (Adjacent()), the nearest to `near` if given. The
 * point's own tile only when nothing else will do: a shelf stands against a wall, and its buyers stand in front of it.
 */
/datum/outpost_floor/proc/npc_stand_tile(atom/point, list/reach, list/avoid, atom/near)
	var/turf/center = get_turf(point)
	if(!center || !length(reach))
		return null
	var/turf/best
	var/best_score = INFINITY
	for(var/turf/tile as anything in RANGE_TURFS(1, center))
		if(!reach[tile] || LAZYACCESS(avoid, tile) || !tile.Adjacent(point))
			continue
		if((!near || near.loc != tile) && tile.is_blocked_turf(exclude_mobs = FALSE))
			continue
		var/score = (tile == center ? 100 : 0) + (near ? get_dist(near, tile) : 0)
		if(score < best_score)
			best = tile
			best_score = score
	return best

// ===== THE TICK =====

/// The board's tick for this floor: customers of a floor that is no longer let go, and the next comes when it is time
/datum/outpost_floor/proc/npc_custom_tick()
	if(world.time < npc_ticked_at + FLOOR_CUSTOMER_TICK)
		return
	npc_ticked_at = world.time
	if(npc_place && (state != OUTPOST_FLOOR_STATE_OWNED || QDELETED(host) || length(bounds) < 5))
		npc_send_all_away()
		return
	if(!npc_next_visit)
		npc_next_visit = world.time + rand(OUTPOST_FLOOR_NPC_VISIT_LOW, OUTPOST_FLOOR_NPC_VISIT_HIGH)
		return
	if(world.time < npc_next_visit)
		return
	if(npc_place && length(npc_place.living_npcs()) >= FLOOR_CUSTOMERS_AT_ONCE)
		return
	var/denial = npc_custom_denial(check_route = FALSE)
	if(denial == "full")
		// A shopper or drinker downstairs heads home a little early, and the customer comes once there is room
		floor_life_make_room(outpost, 1)
		return
	if(denial)
		return
	if(npc_bring_customer())
		npc_next_visit = world.time + rand(OUTPOST_FLOOR_NPC_VISIT_LOW, OUTPOST_FLOOR_NPC_VISIT_HIGH)
	else
		npc_next_visit = world.time + FLOOR_CUSTOMER_NO_ROUTE_WAIT

/// One customer steps out of the lift, the route to the sale points searched once for their visit (A96). Returns
/// them, or null when there is no free alcove tile or no sale point a visitor can walk to.
/datum/outpost_floor/proc/npc_bring_customer()
	var/turf/arrival = npc_arrival_turf()
	if(!arrival)
		return null
	var/list/reach = npc_reach(arrival)
	if(!length(npc_points_in_reach(reach, npc_sale_points())))
		return null
	npc_place ||= new /datum/ambient_place/outpost_floor(src)
	var/mob/living/carbon/human/npc/ambient_npc/floor_customer/customer = new(arrival)
	customer.begin_visit(src, reach, arrival)
	customer.set_place(npc_place)
	customer.fade_in()
	on_lift_arriving()
	log_game("OUTPOST FLOOR: a customer came up to floor [number] of '[outpost?.name]'")
	return customer

/// Everyone who came for the shop goes now: the floor is no longer let
/datum/outpost_floor/proc/npc_send_all_away()
	var/datum/ambient_place/outpost_floor/place = npc_place
	npc_place = null
	if(!place)
		return
	for(var/mob/living/carbon/human/npc/ambient_npc/customer as anything in place.living_npcs())
		customer.fade_out(instant = !human_npc_watched(customer))
	qdel(place)

// ===== THE PLACE =====

/**
 * Where a floor's customers belong. It keeps them on the floor, sends them out by its lift and shares the outpost's
 * caps: their deaths drop cash out of the outpost's cash cap, and a killing keeps the floor's next customer away a good
 * while. SSambient_npcs never ticks it; the directory board ticks its floor.
 */
/datum/ambient_place/outpost_floor
	name = "a floor"
	/// The floor
	var/datum/weakref/floor_ref

/datum/ambient_place/outpost_floor/New(datum/outpost_floor/floor)
	. = ..()
	floor_ref = WEAKREF(floor)
	name = "floor [floor?.number] of [floor?.outpost?.name || "an outpost"]"

/datum/ambient_place/outpost_floor/Destroy()
	floor_ref = null
	return ..()

/// The floor, if it is still there
/datum/ambient_place/outpost_floor/proc/served_floor()
	var/datum/outpost_floor/floor = floor_ref?.resolve()
	return QDELETED(floor) ? null : floor

/datum/ambient_place/outpost_floor/leash_ok(turf/tile, mob/living/carbon/human/npc/ambient_npc/npc)
	var/datum/outpost_floor/floor = served_floor()
	return !!floor?.contains_turf(tile)

// A customer keeps to where a visitor could walk from the lift
/datum/ambient_place/outpost_floor/spot_allowed(turf/tile, mob/living/carbon/human/npc/ambient_npc/npc)
	var/mob/living/carbon/human/npc/ambient_npc/floor_customer/customer = npc
	if(istype(customer) && customer.reach)
		return !!customer.reach[tile]
	return leash_ok(tile, npc)

/datum/ambient_place/outpost_floor/exit_turf(mob/living/carbon/human/npc/ambient_npc/npc)
	var/mob/living/carbon/human/npc/ambient_npc/floor_customer/customer = npc
	if(istype(customer) && customer.arrived_at)
		return customer.arrived_at
	var/datum/outpost_floor/floor = served_floor()
	return length(floor?.alcove_turfs) ? floor.alcove_turfs[1] : null

// The outpost's people and its floors' drop no more than AMBIENT_OUTPOST_CASH_CAP between them in a round
/datum/ambient_place/outpost_floor/cash_for(mob/living/carbon/human/npc/ambient_npc/npc, amount)
	var/datum/outpost_floor/floor = served_floor()
	var/datum/ambient_place/outpost/concourse = floor?.outpost ? SSambient_npcs.outpost_place(floor.outpost) : null
	return concourse ? concourse.cash_for(npc, amount) : 0

// Killed here: the floor's next customer stays away as long as a killed concourse NPC's place does (A47, A74)
/datum/ambient_place/outpost_floor/npc_died(mob/living/carbon/human/npc/ambient_npc/npc)
	var/datum/outpost_floor/floor = served_floor()
	if(floor)
		floor.npc_next_visit = max(floor.npc_next_visit, world.time + AMBIENT_OUTPOST_KILLED_SLOT_TIME)

// A real blow on ground the law covers is violence there, as against a visitor downstairs
/datum/ambient_place/outpost_floor/npc_attacked(mob/living/carbon/human/npc/ambient_npc/npc, atom/attacker, attack_flags)
	if(!(attack_flags & ATTACKER_DAMAGING_ATTACK) || !isliving(attacker))
		return
	var/datum/outpost_floor/floor = served_floor()
	var/obj/structure/overmap/trader_outpost/outpost = floor?.outpost
	if(outpost && get_trader_outpost_for_turf(get_turf(npc)) == outpost)
		outpost.register_aggression(attacker, OUTPOST_CRIME_ASSAULT_CIVILIAN, npc)

/datum/ambient_place/outpost_floor/describe()
	var/datum/outpost_floor/floor = served_floor()
	return "[name]: [length(living_npcs())] customer\s, [floor?.npc_budget_left() || 0] cr of custom left"

// ===== THE CUSTOMER =====

/// Someone off one of the ships, come up to a crew's shop
/mob/living/carbon/human/npc/ambient_npc/floor_customer
	desc = "Someone off one of the ships, doing their shopping."
	dialogue_file = AMBIENT_STRINGS_PATRONS
	dialogue_section = "customer"
	outfit_choices = list(
		/datum/outfit/ambient_customer,
		/datum/outfit/ambient_customer/pilot,
		/datum/outfit/ambient_customer/engineer,
		/datum/outfit/ambient_customer/medic,
		/datum/outfit/ambient_customer/prospector,
		/datum/outfit/ambient_customer/scientist,
		/datum/outfit/ambient_customer/casual,
		/datum/outfit/ambient_customer/quartermaster,
	)
	// They keep to their visit (pick_activity())
	routine = list()
	/// The floor they came up to
	var/datum/weakref/floor_ref
	/// Where they may walk: the floor from the lift by doors anyone may use, as turf = TRUE (npc_reach())
	var/list/reach
	/// The alcove tile they stepped out on, and leave from
	var/turf/arrived_at
	/// FLOOR_VISIT_*
	var/visit_stage = FLOOR_VISIT_SHOPPING
	/// Sale points left to look over
	var/looks_left = FLOOR_CUSTOMER_LOOKS
	/// Weakrefs to the sale points they looked at
	var/list/points_seen
	/// What they bought, while they still have it
	var/datum/weakref/bought_ref
	/// world.time they go, whatever they are at
	var/leave_at = 0

/mob/living/carbon/human/npc/ambient_npc/floor_customer/Destroy()
	reach = null
	arrived_at = null
	points_seen = null
	bought_ref = null
	floor_ref = null
	return ..()

/// They step out of the lift onto `floor` at `arrival`, free to walk `reach`
/mob/living/carbon/human/npc/ambient_npc/floor_customer/proc/begin_visit(datum/outpost_floor/floor, list/reach, turf/arrival)
	floor_ref = WEAKREF(floor)
	src.reach = reach
	arrived_at = arrival
	home = arrival
	leave_at = world.time + FLOOR_CUSTOMER_STAY
	if(prob(40))
		say_customer_line("arrive", force = TRUE)

/// The floor they came up to, if it is still there
/mob/living/carbon/human/npc/ambient_npc/floor_customer/proc/served_floor()
	var/datum/outpost_floor/floor = floor_ref?.resolve()
	return QDELETED(floor) ? null : floor

/// What they bought, while it is still on them
/mob/living/carbon/human/npc/ambient_npc/floor_customer/proc/bought()
	var/obj/item/good = bought_ref?.resolve()
	if(QDELETED(good) || !(good in get_all_contents()))
		return null
	return good

/// They have bought `good`: it goes in a hand, and food or a drink they mean to have here (`consumable`)
/mob/living/carbon/human/npc/ambient_npc/floor_customer/proc/took(obj/item/good, consumable)
	if(QDELETED(good))
		return
	if(!(good in get_all_contents()) && !put_in_hands(good))
		return
	bought_ref = WEAKREF(good)
	visit_stage = (consumable && floor_patron_can_have(good)) ? FLOOR_VISIT_EATING : FLOOR_VISIT_DONE

/**
 * Says a line from strings/floor_customers.json: `context` under customer_lines, or under patron_lines with
 * `as_patron`. `item` fills {item}. Waits out their own pause unless `force`. TRUE if they spoke.
 */
/mob/living/carbon/human/npc/ambient_npc/floor_customer/proc/say_customer_line(context, item, as_patron = FALSE, force = FALSE)
	if(stat != CONSCIOUS || fading)
		return FALSE
	if(!force && world.time < next_line_at)
		return FALSE
	var/list/lines = floor_customer_lines(as_patron ? "patron_lines" : "customer_lines", context)
	if(!length(lines))
		return FALSE
	var/line = pick(lines)
	if(!istext(line))
		return FALSE
	// A listing's name is an item's name; cleaned here before it is spoken
	line = replacetext(line, "{item}", item ? html_encode(item) : "this")
	say_line(fill_line(line))
	return TRUE

/// They keep to their visit: shop, then sit with what they bought if it is to eat or drink, then go
/mob/living/carbon/human/npc/ambient_npc/floor_customer/pick_activity()
	if(!served_floor() || world.time >= leave_at)
		return go_home_by_lift()
	if(visit_stage == FLOOR_VISIT_EATING)
		visit_stage = FLOOR_VISIT_DONE
		if(bought() && start_activity(new /datum/ambient_activity/floor_patron(src)))
			return activity
	if(visit_stage == FLOOR_VISIT_SHOPPING)
		while(looks_left > 0)
			looks_left--
			if(start_activity(new /datum/ambient_activity/floor_shop(src)))
				return activity
	return go_home_by_lift()

/// Back to the lift and away
/mob/living/carbon/human/npc/ambient_npc/floor_customer/proc/go_home_by_lift()
	if(prob(40))
		say_customer_line("leave")
	return start_activity(new /datum/ambient_activity/leave(src, arrived_at))

// Off where a visitor may walk (shoved through a door): back by the lift
/mob/living/carbon/human/npc/ambient_npc/floor_customer/give_up_leash()
	if(stat == CONSCIOUS && !istype(activity, /datum/ambient_activity/leave))
		start_activity(new /datum/ambient_activity/leave(src, arrived_at))
		return
	fade_out()

// Hit: they say so and go
/mob/living/carbon/human/npc/ambient_npc/floor_customer/react_attacked(atom/attacker)
	if(stat != CONSCIOUS || fading || !reaction_ready("attacked"))
		return
	speak_context(AMBIENT_LINE_ATTACKED, attacker, force = TRUE)
	start_activity(new /datum/ambient_activity/leave(src, arrived_at, 1 SECONDS))

// Up here they are still at the outpost: no teleport takes a living one off it, as downstairs
/mob/living/carbon/human/npc/ambient_npc/floor_customer/refuse_teleport(datum/source, atom/destination, channel)
	SIGNAL_HANDLER
	if(stat == DEAD)
		return NONE
	return TRUE

// Leaving (alive, at the lift or out of sight) they take what they bought with them; killed, it drops with them
/mob/living/carbon/human/npc/ambient_npc/floor_customer/npc_drop_not_gear()
	if(stat != DEAD && fading)
		var/obj/item/good = bought()
		if(good)
			qdel(good)
	return ..()

/// Whether `good` is food or a drink someone could have at a table: food with something left, or a cup with a drink in it
/proc/floor_patron_can_have(obj/item/good)
	if(QDELETED(good) || !good.reagents?.total_volume)
		return FALSE
	if(IS_EDIBLE(good))
		return TRUE
	return istype(good, /obj/item/reagent_containers/cup)

/**
 * A bite of what they bought, or a gulp, as anyone takes one: the food's own bite (its reagents go into them, with its
 * taste, its buff and its trash when it is gone) or the cup's own gulp. A can or a capped bottle is opened first, by
 * hand. FALSE when there is nothing left, they are too full, or they cannot (a mask, a cork).
 */
/mob/living/carbon/human/npc/ambient_npc/floor_customer/proc/take_bite()
	var/obj/item/good = bought()
	if(!good || stat != CONSCIOUS || !good.reagents?.total_volume)
		return FALSE
	if(IS_EDIBLE(good))
		var/datum/component/edible/food = good.GetComponent(/datum/component/edible)
		if(!food || get_fullness() > FLOOR_PATRON_FULL || !food.CanConsume(src, src))
			return FALSE
		var/verb_used = length(food.eatverbs) ? pick(food.eatverbs) : "eat"
		visible_message(span_notice("[src] [verb_used]s \the [good]."))
		food.TakeBite(src, src)
		return TRUE
	var/obj/item/reagent_containers/cup/drink = good
	if(!istype(drink))
		return FALSE
	if(!drink.spillable && !open_drink(drink))
		return FALSE
	if(!drink.reagents?.total_volume || !drink.canconsume(src, src))
		return FALSE
	visible_message(span_notice("[src] takes a drink from \the [drink]."))
	drink.attack(src, src)
	return TRUE

/// Opens a can or a capped bottle as a hand does. FALSE for anything that takes more than a hand (a cork).
/mob/living/carbon/human/npc/ambient_npc/floor_customer/proc/open_drink(obj/item/reagent_containers/cup/drink)
	if(istype(drink, /obj/item/reagent_containers/cup/soda_cans))
		var/obj/item/reagent_containers/cup/soda_cans/can = drink
		can.open_soda(src)
	else if(istype(drink, /obj/item/reagent_containers/cup/glass/waterbottle))
		var/obj/item/reagent_containers/cup/glass/waterbottle/bottle = drink
		if(bottle.cap_on && !bottle.cap_lost)
			bottle.click_alt(src)
	return drink.spillable

/// Sets down what they are done with: on `table` if it is right beside them, else at their feet. Only trash and empty
/// cups: anything else, and anything with something left in it, goes with them.
/mob/living/carbon/human/npc/ambient_npc/floor_customer/proc/set_down_empties(obj/structure/table/table)
	for(var/obj/item/thing in held_items.Copy())
		if(thing == held_prop || HAS_TRAIT(thing, TRAIT_HUMAN_NPC_GEAR) || HAS_TRAIT(thing, TRAIT_AMBIENT_PROP))
			continue
		// Trash, or an empty glass, can or bottle: never anything else they have
		if(!istype(thing, /obj/item/trash) && !(istype(thing, /obj/item/reagent_containers/cup) && !thing.reagents?.total_volume))
			continue
		var/turf/drop_at = (!QDELETED(table) && isturf(table.loc) && Adjacent(table)) ? table.loc : drop_location()
		if(!isturf(drop_at) || !transferItemToLoc(thing, drop_at, force = TRUE))
			continue
		thing.pixel_x = rand(-6, 6)
		thing.pixel_y = rand(0, 6)

// ===== THE VISIT =====

/**
 * A look at one sale point: walk up to it, look it over, buy one thing if the floor's budget covers it (the sale is
 * npc_buy()'s), linger a moment and move on.
 */
/datum/ambient_activity/floor_shop
	name = "shopping upstairs"
	/// The sale point
	var/datum/weakref/point_ref
	/// world.time they make up their mind, once there
	var/decide_at = 0
	/// world.time they are done there
	var/done_at = 0
	/// They made up their mind
	var/decided = FALSE

/datum/ambient_activity/floor_shop/Destroy()
	point_ref = null
	return ..()

/datum/ambient_activity/floor_shop/setup()
	var/mob/living/carbon/human/npc/ambient_npc/floor_customer/shopper = doer
	var/datum/outpost_floor/floor = istype(shopper) ? shopper.served_floor() : null
	if(!floor)
		return FALSE
	var/list/choices = list()
	for(var/atom/point as anything in floor.npc_sale_points())
		var/seen = FALSE
		for(var/datum/weakref/ref as anything in shopper.points_seen)
			if(ref.resolve() == point)
				seen = TRUE
				break
		if(!seen)
			choices += point
	for(var/atom/point as anything in shuffle(choices))
		var/turf/stand = floor.npc_stand_tile(point, shopper.reach, failed_spots, doer)
		if(!stand)
			continue
		point_ref = WEAKREF(point)
		LAZYADD(shopper.points_seen, WEAKREF(point))
		go_to(stand)
		return TRUE
	return FALSE

/// The sale point, if it is still there
/datum/ambient_activity/floor_shop/proc/point()
	var/atom/point = point_ref?.resolve()
	return QDELETED(point) ? null : point

/datum/ambient_activity/floor_shop/arrive()
	var/atom/point = point()
	if(point && !doer.buckled)
		doer.face_atom(point)
	decide_at = world.time + rand(FLOOR_CUSTOMER_BROWSE_LOW, FLOOR_CUSTOMER_BROWSE_HIGH)
	if(prob(50))
		var/mob/living/carbon/human/npc/ambient_npc/floor_customer/shopper = doer
		shopper.say_customer_line("browse")

/datum/ambient_activity/floor_shop/act(seconds)
	var/atom/point = point()
	if(!point)
		return AMBIENT_STEP_DONE
	if(!decided)
		if(world.time >= decide_at)
			decide(point)
		return AMBIENT_STEP_CONTINUE
	return world.time >= done_at ? AMBIENT_STEP_DONE : AMBIENT_STEP_CONTINUE

/// Buys the thing at `point` if the floor's budget covers it, and says so either way
/datum/ambient_activity/floor_shop/proc/decide(atom/point)
	decided = TRUE
	done_at = world.time + rand(FLOOR_CUSTOMER_LINGER_LOW, FLOOR_CUSTOMER_LINGER_HIGH)
	var/mob/living/carbon/human/npc/ambient_npc/floor_customer/shopper = doer
	var/datum/outpost_floor/floor = shopper.served_floor()
	var/list/offer = floor?.npc_offer(point)
	if(!islist(offer))
		shopper.say_customer_line("nothing", force = prob(50))
		return
	var/price = offer["price"]
	var/item_name = offer["name"]
	if(!isnum(price) || price <= 0 || price > OUTPOST_FLOOR_NPC_ITEM_MAX || price > floor.npc_budget_left())
		shopper.say_customer_line("too_dear", item_name, force = prob(60))
		return
	var/obj/item/good = floor.npc_buy(doer, point)
	if(QDELETED(good))
		shopper.say_customer_line("nothing", force = prob(50))
		return
	shopper.took(good, offer["consumable"])
	shopper.say_customer_line("buy", item_name, force = TRUE)
	// They have what they came for
	shopper.looks_left = 0

/datum/ambient_activity/floor_shop/spot_unreachable()
	. = ..()
	var/mob/living/carbon/human/npc/ambient_npc/floor_customer/shopper = doer
	var/atom/point = point()
	var/datum/outpost_floor/floor = shopper.served_floor()
	var/turf/stand = (point && floor) ? floor.npc_stand_tile(point, shopper.reach, failed_spots, doer) : null
	if(stand)
		go_to(stand)
		return
	// Nowhere to stand at it: this look is over
	decided = TRUE
	done_at = world.time

/datum/ambient_activity/floor_shop/shift_times(delay)
	. = ..()
	decide_at = ambient_shifted(decide_at, delay)
	done_at = ambient_shifted(done_at, delay)

/**
 * A patron's meal (L36): a free chair near where they bought it, at a table if there is one, and what they bought had
 * bite by bite or gulp by gulp until it is gone or they are full. The empty goes on the table.
 */
/datum/ambient_activity/floor_patron
	name = "eating upstairs"
	accepts_company = TRUE
	var/datum/weakref/seat_ref
	var/datum/weakref/table_ref
	/// world.time of the next bite or gulp
	var/next_bite = 0
	/// world.time they get up, the meal done or not
	var/up_at = 0
	/// Nothing more to have
	var/finished = FALSE

/datum/ambient_activity/floor_patron/Destroy()
	seat_ref = null
	table_ref = null
	return ..()

/datum/ambient_activity/floor_patron/setup()
	var/mob/living/carbon/human/npc/ambient_npc/floor_customer/patron = doer
	if(!istype(patron) || !patron.bought())
		return FALSE
	// A seat at a table first, then any seat
	var/obj/structure/chair/seat = doer.find_seat(doer, OUTPOST_FLOOR_PATRON_SEAT_RANGE, TRUE, failed_spots)
	seat ||= doer.find_seat(doer, OUTPOST_FLOOR_PATRON_SEAT_RANGE, FALSE, failed_spots)
	if(!seat)
		return FALSE
	seat_ref = WEAKREF(seat)
	go_to(get_turf(seat))
	up_at = world.time + FLOOR_PATRON_SIT_MAX
	return TRUE

/datum/ambient_activity/floor_patron/arrive()
	var/obj/structure/chair/seat = seat_ref?.resolve()
	if(seat && !doer.sit_on(seat))
		seat_ref = null
	var/obj/structure/table/table = doer.table_beside(doer)
	table_ref = table ? WEAKREF(table) : null
	if(table && !doer.buckled)
		doer.face_atom(table)
	next_bite = world.time + rand(3 SECONDS, 6 SECONDS)
	next_line = world.time + rand(20 SECONDS, 45 SECONDS)
	if(prob(50))
		var/mob/living/carbon/human/npc/ambient_npc/floor_customer/patron = doer
		patron.say_customer_line("sit", as_patron = TRUE)

/datum/ambient_activity/floor_patron/act(seconds)
	var/mob/living/carbon/human/npc/ambient_npc/floor_customer/patron = doer
	if(finished)
		return AMBIENT_STEP_CONTINUE
	if(world.time >= up_at)
		return AMBIENT_STEP_DONE
	if(world.time >= next_bite)
		next_bite = world.time + rand(FLOOR_PATRON_BITE_LOW, FLOOR_PATRON_BITE_HIGH)
		if(!patron.take_bite())
			finished = TRUE
			// A moment more in the chair before they go
			ends_at = world.time + rand(5 SECONDS, 15 SECONDS)
			if(prob(50))
				patron.say_customer_line("done", as_patron = TRUE, force = TRUE)
			return AMBIENT_STEP_CONTINUE
	if(world.time >= next_line)
		next_line = world.time + rand(30 SECONDS, 60 SECONDS)
		patron.say_customer_line("chat", as_patron = TRUE)
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/floor_patron/finish()
	var/mob/living/carbon/human/npc/ambient_npc/floor_customer/patron = doer
	if(istype(patron) && !QDELETED(patron) && patron.stat == CONSCIOUS)
		patron.set_down_empties(table_ref?.resolve())
	return ..()

/datum/ambient_activity/floor_patron/spot_unreachable()
	. = ..()
	seat_ref = null

/datum/ambient_activity/floor_patron/shift_times(delay)
	. = ..()
	next_bite = ambient_shifted(next_bite, delay)
	up_at = ambient_shifted(up_at, delay)

// ===== STRINGS =====

/// The lines for `context` under `key` ("customer_lines" or "patron_lines") in strings/floor_customers.json, or none
/proc/floor_customer_lines(key, context)
	var/static/list/loaded
	if(isnull(loaded))
		loaded = list()
		if(fexists(FLOOR_CUSTOMERS_STRINGS_FILE))
			var/list/parsed = json_decode(file2text(FLOOR_CUSTOMERS_STRINGS_FILE))
			if(islist(parsed))
				loaded = parsed
	var/list/section = loaded[key]
	var/list/lines = islist(section) ? section[context] : null
	return islist(lines) ? lines : list()

#undef FLOOR_CUSTOMERS_STRINGS_FILE
#undef FLOOR_CUSTOMER_TICK
#undef FLOOR_CUSTOMER_NO_ROUTE_WAIT
#undef FLOOR_CUSTOMERS_AT_ONCE
#undef FLOOR_CUSTOMER_LOOKS
#undef FLOOR_CUSTOMER_STAY
#undef FLOOR_CUSTOMER_BROWSE_LOW
#undef FLOOR_CUSTOMER_BROWSE_HIGH
#undef FLOOR_CUSTOMER_LINGER_LOW
#undef FLOOR_CUSTOMER_LINGER_HIGH
#undef FLOOR_PATRON_BITE_LOW
#undef FLOOR_PATRON_BITE_HIGH
#undef FLOOR_PATRON_SIT_MAX
#undef FLOOR_PATRON_FULL
#undef FLOOR_VISIT_SHOPPING
#undef FLOOR_VISIT_EATING
#undef FLOOR_VISIT_DONE
