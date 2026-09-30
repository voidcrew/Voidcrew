/**
 * # Prison wing fixtures
 *
 * The pieces the prison wing's map places: uniforms that get dirty, the serving hatches, the
 * Sustenance Vendor, the wing's first aid kit, bookcases, and a quieter basketball hoop and ball.
 * The machines have no circuit boards or designs and are protected outpost property, so they only
 * exist in a placed prison wing and never end up on a ship. The wing's doors and bolt buttons are
 * in outpost_prison_doors.dm.
 */

/// Whether this is an outpost prisoner
/proc/is_outpost_prisoner(atom/thing)
	return istype(thing, /mob/living/basic/outpost_prisoner)

// ===== UNIFORM =====

/// A prison jumpsuit that records how dirty it is. Only a washing machine gets it clean again.
/obj/item/clothing/under/rank/prisoner/outpost
	desc = "Standard issue for outpost prisoners, in an orange that shows every stain."
	has_sensor = NO_SENSORS
	sensor_mode = SENSOR_OFF
	random_sensor = FALSE
	// Dyeing would turn it into a different jumpsuit and lose the grime record.
	undyeable = TRUE
	flags_1 = parent_type::flags_1 | NO_NEW_GAGS_PREVIEW_1
	/// How dirty it is, from 0 (fresh) to 100
	var/grime = 0

/obj/item/clothing/under/rank/prisoner/outpost/proc/set_grime(amount)
	grime = clamp(amount, 0, 100)
	remove_atom_colour(FIXED_COLOUR_PRIORITY)
	if(grime >= PRISONER_GRIME_FILTHY)
		add_atom_colour("#9c8a6a", FIXED_COLOUR_PRIORITY)
	else if(grime >= PRISONER_GRIME_DIRTY)
		add_atom_colour("#c8b898", FIXED_COLOUR_PRIORITY)

/obj/item/clothing/under/rank/prisoner/outpost/examine(mob/user)
	. = ..()
	if(grime >= PRISONER_GRIME_FILTHY)
		. += span_warning("It's filthy.")
	else if(grime >= PRISONER_GRIME_DIRTY)
		. += span_notice("It's grimy.")
	else
		. += span_notice("It looks clean.")

/obj/item/clothing/under/rank/prisoner/outpost/machine_wash(obj/machinery/washing_machine/washer)
	. = ..()
	set_grime(0)

// ===== SERVING HATCH =====

/**
 * A reinforced counter set into the wall between the office and the yard, with a window door on
 * each side like a security front desk. Staff open their side, leave meals and clean clothes on
 * the counter and close it; prisoners open theirs and take them. Nobody climbs over it.
 *
 * It holds OUTPOST_PRISON_HATCH_CAPACITY items. Staff can't put more on it by hand or from a tray,
 * and anything dumped or thrown onto a full counter slides back off. A prisoner swapping a clean
 * uniform for their dirty one never counts against it.
 */
/obj/structure/table/reinforced/prison_hatch
	name = "serving hatch"
	desc = "A reinforced counter built into the wall, with a window door on each side. Meals and clean clothes go across it. People don't."
	pass_flags_self = LETPASSTHROW
	COOLDOWN_DECLARE(full_message_cooldown)

/obj/structure/table/reinforced/prison_hatch/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)
	// Notes which way the yard is, for when rioters smash a window door out (outpost_prison_breakout.dm)
	yard_windoor()
	staff_windoor()
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_counter_entered),
	)
	AddElement(/datum/element/connect_loc, loc_connections)

/obj/structure/table/reinforced/prison_hatch/examine(mob/user)
	. = ..()
	if(room_left() <= 0)
		. += span_notice("It's full.")
	. += windoor_examine()

/// Items on the counter
/obj/structure/table/reinforced/prison_hatch/proc/stock_count()
	var/count = 0
	for(var/obj/item/thing in loc)
		if(!(thing.item_flags & ABSTRACT))
			count++
	return count

/// How many more items fit on the counter
/obj/structure/table/reinforced/prison_hatch/proc/room_left()
	return max(0, OUTPOST_PRISON_HATCH_CAPACITY - stock_count())

/obj/structure/table/reinforced/prison_hatch/table_place_act(mob/living/user, obj/item/tool, list/modifiers)
	if(!(tool.item_flags & ABSTRACT) && room_left() <= 0)
		balloon_alert(user, "the counter is full")
		return ITEM_INTERACT_BLOCKING
	. = ..()
	if(. == ITEM_INTERACT_SUCCESS && tool.loc == loc)
		get_outpost_prison(src)?.on_hatch_stocked(src, list(tool), user)

/obj/structure/table/reinforced/prison_hatch/tray_act(mob/living/user, obj/item/storage/bag/tray/used_tray)
	if(!length(used_tray.contents))
		return NONE
	var/room = room_left()
	if(room <= 0)
		balloon_alert(user, "the counter is full")
		return ITEM_INTERACT_BLOCKING
	var/list/moved = list()
	for(var/obj/item/thing in used_tray.contents)
		if(length(moved) >= room)
			break
		used_tray.atom_storage.attempt_remove(thing, loc)
		moved += thing
	used_tray.update_appearance()
	user.visible_message(span_notice("[user] empties [length(moved) < room ? "" : "some of "][used_tray] on [src]."))
	if(length(used_tray.contents))
		balloon_alert(user, "the counter is full")
	get_outpost_prison(src)?.on_hatch_stocked(src, moved, user)
	return ITEM_INTERACT_SUCCESS

/// Something landed on the counter: dumped, thrown or dropped there. Over capacity, it slides back off.
/obj/structure/table/reinforced/prison_hatch/proc/on_counter_entered(datum/source, atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	SIGNAL_HANDLER
	if(!isitem(arrived) || stock_count() <= OUTPOST_PRISON_HATCH_CAPACITY)
		return
	var/turf/back = get_turf(old_loc)
	if(!back || back == loc || isclosedturf(back))
		back = staff_side_turf()
	if(!back)
		return
	INVOKE_ASYNC(src, PROC_REF(push_off), arrived, back)

/obj/structure/table/reinforced/prison_hatch/proc/push_off(obj/item/thing, turf/back)
	if(QDELETED(thing) || thing.loc != loc || stock_count() <= OUTPOST_PRISON_HATCH_CAPACITY)
		return
	thing.forceMove(back)
	if(COOLDOWN_FINISHED(src, full_message_cooldown))
		COOLDOWN_START(src, full_message_cooldown, 1 SECONDS)
		visible_message(span_notice("[thing] slides off [src]. The counter is full."))

/obj/structure/table/reinforced/prison_hatch/make_climbable()
	return

/// The window door on the prisoners' side, if it is still there. Notes which way it faces (yard_dir).
/obj/structure/table/reinforced/prison_hatch/proc/yard_windoor()
	var/obj/machinery/door/window/yard_door = locate(/obj/machinery/door/window/outpost_prison_yard) in loc
	if(yard_door)
		yard_dir = yard_door.dir
	return yard_door

/// The window door on the staff side, if it is still there. Notes which way the yard is, if the yard side has not.
/obj/structure/table/reinforced/prison_hatch/proc/staff_windoor()
	var/obj/machinery/door/window/staff_door = locate(/obj/machinery/door/window/brigdoor/outpost_prison_staff) in loc
	if(staff_door && !yard_dir)
		yard_dir = REVERSE_DIR(staff_door.dir)
	return staff_door

/// Where a prisoner stands to reach across: the tile beyond the yard-side window door, or where it stood
/obj/structure/table/reinforced/prison_hatch/proc/yard_side_turf()
	var/obj/machinery/door/window/yard_door = yard_windoor()
	var/facing = yard_door ? yard_door.dir : yard_dir
	return facing ? get_step(src, facing) : null

/**
 * Whether both sides are open (or broken off), leaving a way over the counter. Nothing uses this
 * yet; step 3 has prisoners try to climb out when it is true.
 */
/obj/structure/table/reinforced/prison_hatch/proc/both_sides_open()
	var/obj/machinery/door/window/yard_door = yard_windoor()
	var/obj/machinery/door/window/staff_door = staff_windoor()
	return (!yard_door || !yard_door.density) && (!staff_door || !staff_door.density)

/**
 * A prisoner reaching for the counter: opens the yard side if it is shut. Returns TRUE once it is
 * all the way open (or missing), FALSE while it is opening or closing, or when it cannot open (no
 * power). A window door stops blocking partway through its opening animation; nothing is taken
 * across the counter until the animation has finished.
 */
/obj/structure/table/reinforced/prison_hatch/proc/open_for_prisoner(mob/living/prisoner)
	var/obj/machinery/door/window/yard_door = yard_windoor()
	if(!yard_door)
		return TRUE
	if(!yard_door.density)
		return !yard_door.operating
	if(!yard_door.operating && yard_door.hasPower() && yard_door.allowed(prisoner))
		// Opens, then shuts itself a few seconds later.
		INVOKE_ASYNC(yard_door, TYPE_PROC_REF(/obj/machinery/door/window, open_and_close))
	return FALSE

// ===== RATIONS =====

/// The wing's own ration, put on the hatches by the admin panel's fill. The vendor sells tg's prison food.
/obj/item/food/prison_ration
	name = "prison ration"
	desc = "A dense protein bar in a plain wrapper. Filling, and that's all anyone says about it."
	icon = 'icons/obj/food/moth.dmi'
	icon_state = "sustenance_bar"
	trash_type = /obj/item/trash/fleet_ration
	food_reagents = list(/datum/reagent/consumable/nutriment = 10)
	tastes = list("cardboard" = 1)
	foodtypes = GRAIN
	w_class = WEIGHT_CLASS_SMALL

// ===== SUSTENANCE VENDOR =====

/**
 * The prison office's food: tg's Sustenance Vendor with its usual stock (soggy tofu, moldy bread,
 * ice cups, candy corn, plastic spoons) and no contraband. It serves the wing's members, not
 * prisoner IDs, and bills the outpost treasury OUTPOST_PRISON_RATION_COST for each item. Members
 * who can't manage or spend the treasury (residents, builders, the owner's shipmates) may take
 * OUTPOST_PRISON_RESIDENT_ORDERS items per OUTPOST_PRISON_RESIDENT_ORDER_WINDOW between them. No
 * refill canisters reach an outpost, so it restocks itself while powered: one item every
 * OUTPOST_PRISON_VENDOR_RESTOCK_TIME, most likely whatever it is shortest of. The tofu and candy
 * corn feed a prisoner like a ration (outpost_prisoner_food_tier()).
 * Uniforms and dressings come with the room: the uniforms, the first aid kit and the washing machine.
 */
/obj/machinery/vending/sustenance/outpost_prison
	desc = "The prison wing's food vendor. It bills the outpost for everything it hands out."
	contraband = list()
	refill_canister = null
	all_products_free = FALSE
	default_price = OUTPOST_PRISON_RATION_COST
	extra_price = OUTPOST_PRISON_RATION_COST
	allow_custom = FALSE
	tiltable = FALSE
	// tg's sustenance interact() refuses anyone without a prisoner ID unless req_access is set and
	// allowed() passes; allowed() below lets the wing's members through.
	req_access = list(ACCESS_BRIG)
	/// Powered time toward the next restocked item, in deciseconds
	var/restock_progress = 0

/obj/machinery/vending/sustenance/outpost_prison/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)
	// Restocked by itself, never by the crew's restock tracker
	GLOB.vending_machines_to_restock -= src
	set_outpost_prices(product_records)

/obj/machinery/vending/sustenance/outpost_prison/reset_prices(list/recordlist, list/premiumlist)
	. = ..()
	set_outpost_prices(recordlist)

/// Every item costs the treasury the same
/obj/machinery/vending/sustenance/outpost_prison/proc/set_outpost_prices(list/recordlist)
	for(var/datum/data/vending_product/record as anything in recordlist)
		record.price = OUTPOST_PRISON_RATION_COST

/obj/machinery/vending/sustenance/outpost_prison/examine(mob/user)
	. = ..()
	. += span_notice("Everything is [OUTPOST_PRISON_RATION_COST] cr, billed to the outpost.")

/// Whether `user` may buy on the treasury: a member of the wing, or without a wing, a manager, treasurer or resident
/obj/machinery/vending/sustenance/outpost_prison/proc/may_vend(mob/user)
	if(!ismob(user) || is_outpost_prisoner(user))
		return FALSE
	var/datum/outpost_prison/prison = get_outpost_prison(src)
	if(prison)
		return prison.is_member(user)
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	return home && (home.can_manage(user) || home.can_spend(user) || home.is_resident(user))

/obj/machinery/vending/sustenance/outpost_prison/interact(mob/user)
	if(isliving(user) && !HAS_AI_ACCESS(user) && !may_vend(user))
		balloon_alert(user, "members only")
		return
	return ..()

/obj/machinery/vending/sustenance/outpost_prison/allowed(mob/accessor)
	return may_vend(accessor)

/obj/machinery/vending/sustenance/outpost_prison/vend(list/params, list/greyscale_colors)
	var/datum/data/vending_product/record = locate(params["ref"])
	if(!can_vend(usr) || !istype(record) || !(record in product_records) || record.amount <= 0)
		return ..()
	var/denial = charge(usr, record)
	if(denial)
		balloon_alert(usr, denial)
		flick(icon_deny, src)
		return TRUE
	return ..()

/**
 * Bills the treasury for one of `record` for `user`. Returned items are free, as in any vendor.
 * Nothing in here can wait, so the vend that follows always happens. Returns null on success,
 * else why not.
 */
/obj/machinery/vending/sustenance/outpost_prison/proc/charge(mob/living/user, datum/data/vending_product/record)
	if(!may_vend(user))
		return "members only"
	if(LAZYLEN(record.returned_products) || record.price <= 0)
		return null
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	if(!home)
		return "no outpost link"
	var/datum/outpost_prison/prison = get_outpost_prison(src)
	var/limited = !home.can_manage(user) && !home.can_spend(user)
	if(limited && (!prison || prison.resident_orders_left() <= 0))
		return "order limit reached"
	home.ensure_home_services()
	var/datum/bank_account/treasury = home.treasury
	if(!treasury || treasury.account_balance < record.price || !treasury.adjust_money(-record.price, "Prison vendor: [record.name], bought by [user.ckey || user.name]"))
		return "insufficient funds"
	if(limited)
		prison.note_resident_orders(1)
	return null

/// The treasury stands in for the buyer's ID, so the vendor shows its balance and greys out what it can't afford
/obj/machinery/vending/sustenance/outpost_prison/ui_data(mob/user)
	. = ..()
	.["user"] = null
	if(!may_vend(user))
		return
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	.["user"] = list(
		"name" = "Outpost treasury",
		"cash" = home?.treasury ? home.treasury.account_balance : 0,
		"job" = "Prison wing",
		"department" = DEPARTMENT_UNASSIGNED,
	)

/obj/machinery/vending/sustenance/outpost_prison/process(seconds_per_tick)
	. = ..()
	if(. == PROCESS_KILL)
		return
	restock_progress += seconds_per_tick * (1 SECONDS)
	while(restock_progress >= OUTPOST_PRISON_VENDOR_RESTOCK_TIME)
		restock_progress -= OUTPOST_PRISON_VENDOR_RESTOCK_TIME
		if(!restock_one())
			restock_progress = 0
			break

/// Puts one item back on a shelf that is short, the shortest most likely. Returns its record, or null when full.
/obj/machinery/vending/sustenance/outpost_prison/proc/restock_one()
	var/list/short = list()
	for(var/datum/data/vending_product/record as anything in product_records)
		if(record.amount < record.max_amount)
			short[record] = record.max_amount - record.amount
	if(!length(short))
		return null
	var/datum/data/vending_product/picked = pick_weight(short)
	picked.amount++
	return picked

/// Items residents may still buy from the Sustenance Vendor in the current window
/datum/outpost_prison/proc/resident_orders_left()
	for(var/ordered_at in resident_orders.Copy())
		if(world.time - ordered_at >= OUTPOST_PRISON_RESIDENT_ORDER_WINDOW)
			resident_orders -= ordered_at
	return max(0, OUTPOST_PRISON_RESIDENT_ORDERS - length(resident_orders))

/datum/outpost_prison/proc/note_resident_orders(count)
	for(var/i in 1 to count)
		resident_orders += world.time

// ===== FIRST AID =====

/// The wing's first aid kit: dressings only. Prisoners are treated without chemicals.
/obj/item/storage/medkit/brute/outpost_prison
	name = "prison first aid kit"
	desc = "Bruise packs, sutures and gauze for the prison wing."

/obj/item/storage/medkit/brute/outpost_prison/PopulateContents()
	if(empty)
		return
	var/static/items_inside = list(
		/obj/item/stack/medical/bruise_pack = 2,
		/obj/item/stack/medical/suture = 2,
		/obj/item/stack/medical/gauze = 1,
		/obj/item/healthanalyzer/simple = 1,
	)
	generate_items_inside(items_inside, src)

// ===== BOOKCASE =====

/**
 * A shelf of library books for the yard. With no library database to draw on, it makes up the
 * numbers with random manuals, so there is always something to read.
 */
/obj/structure/bookcase/random/outpost_prison
	name = "bookcase"
	books_to_load = 5
	/// Fewest books the shelf holds once it has loaded
	var/min_books = 4

/obj/structure/bookcase/random/outpost_prison/after_random_load()
	var/count = 0
	for(var/obj/item/book/book in src)
		count++
	for(var/i in count + 1 to min_books)
		new /obj/item/book/manual/random(src)
	update_appearance()

// ===== BASKETBALL =====

/// The yard's hoop. Prisoners shoot at it all day, so its buzzer is half as loud as tg's.
/obj/structure/hoop/outpost_prison
	buzzer_volume = 50

/// The yard's ball, bouncing half as loud as tg's
/obj/item/toy/basketball/outpost_prison
	bounce_volume = 37

// ===== MESS =====

/// What a meal leaves on the floor
/obj/effect/decal/cleanable/food/crumbs
	name = "crumbs"
	desc = "Someone ate here and didn't clean up after themselves."
	icon_state = "flour"
	color = "#a47a4a"
