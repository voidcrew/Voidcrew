/**
 * # Outpost floors: shop fittings and their kits
 *
 * Owner: P12 (spec 3b.4, L32). A kit is an item from the supply console. Set down on a buildable deck tile of a floor
 * with a Shop room, by someone who may build there and under the cap, it becomes a fitting: outpost property, never
 * dense (A94), never saved on a ship. A manager packs a fitting back into its kit. A hit on one goes to the police
 * (floor_fitting_hit(), P5). P0 declared the types so supply packs and the save exclusion list can name them.
 *
 * Three fittings: the till (a second register), the sale shelf (shows one listing and sells it) and the floor sign
 * (the floor's name in its colour, OPEN or SHUT under it). All of them sell from the Shop room's one stock unit; the
 * selling itself is in floor_shopfront.dm.
 *
 * Sprites are existing ones: the flat-pack box, the laptop, the wall monitor (its dark screen carries the sign's
 * text) and the cargo shelf's base.
 */

// ===== WHAT THE FLOOR KEEPS =====

/datum/outpost_floor
	/// Fittings set down from a kit: OUTPOST_FLOOR_FITTING_* -> list of weak references. A mapped nameplate is not one.
	/// Weak, so a floor deleted before its fittings (A10) holds nothing back.
	var/list/shop_fittings
	/// Weak references to the signs the shell map hangs (the nameplate by the front door): they show the name and never count
	var/list/datum/weakref/shop_plates

/// How many fittings of `kind` (OUTPOST_FLOOR_FITTING_*) are down on this floor
/datum/outpost_floor/proc/fitting_count(kind)
	return length(shop_fittings_of(kind))

/// The fittings of `kind` that are down. References to deleted ones are dropped on the way.
/datum/outpost_floor/proc/shop_fittings_of(kind)
	. = list()
	var/list/datum/weakref/down = LAZYACCESS(shop_fittings, kind)
	for(var/index in length(down) to 1 step -1)
		var/obj/fitting = down[index]?.resolve()
		if(fitting)
			. += fitting
		else
			down.Cut(index, index + 1)

/// The most fittings of `kind` a floor may have down
/datum/outpost_floor/proc/shop_fitting_max(kind)
	switch(kind)
		if(OUTPOST_FLOOR_FITTING_TILL)
			return OUTPOST_FLOOR_TILLS_MAX
		if(OUTPOST_FLOOR_FITTING_SHELF)
			return OUTPOST_FLOOR_SHELVES_MAX
		if(OUTPOST_FLOOR_FITTING_SIGN)
			return OUTPOST_FLOOR_SIGNS_MAX
	return 0

/datum/outpost_floor/proc/shop_add_fitting(obj/fitting, kind)
	var/datum/weakref/fitting_ref = WEAKREF(fitting)
	LAZYREMOVE(shop_plates, fitting_ref)
	LAZYINITLIST(shop_fittings)
	LAZYOR(shop_fittings[kind], fitting_ref)

/datum/outpost_floor/proc/shop_drop_fitting(obj/fitting)
	var/datum/weakref/fitting_ref = fitting.weak_reference
	if(!fitting_ref)
		return
	for(var/kind in shop_fittings)
		var/list/down = shop_fittings[kind]
		down -= fitting_ref
	LAZYREMOVE(shop_plates, fitting_ref)

/// Whether `fitting` was set down from a kit on this floor
/datum/outpost_floor/proc/shop_fittings_has(obj/fitting)
	var/datum/weakref/fitting_ref = fitting?.weak_reference
	if(!fitting_ref)
		return FALSE
	for(var/kind in shop_fittings)
		if(fitting_ref in shop_fittings[kind])
			return TRUE
	return FALSE

// ===== WHAT MAKES A FITTING OUTPOST PROPERTY =====

/**
 * On every fitting. It is outpost property (no tool, no blast, no EMP; trade/outpost_security.dm), with one
 * difference: the property element reports any damaging hit to the outpost as vandalism, whoever threw it. A
 * fitting belongs to the floor, so a hit on one is judged by the floor's own rule alone (floor_fitting_hit(),
 * police_floors.dm, L39): on public ground, by anyone but the floor's people. The element's own reports are
 * switched off here and the same hits are passed to that proc instead.
 */
/datum/element/outpost_floor_fitting

/datum/element/outpost_floor_fitting/Attach(datum/target)
	. = ..()
	if(!ismachinery(target) && !isstructure(target))
		return ELEMENT_INCOMPATIBLE
	var/obj/fitting = target
	fitting.AddElement(/datum/element/outpost_property)
	// As a service room's fixtures are (protect_fixture()): /obj/singularity_act() deletes whatever its flags say
	ADD_TRAIT(fitting, TRAIT_SINGULARITY_IMMUNE, ELEMENT_TRAIT(type))
	var/datum/element/outpost_property/property = SSdcs.GetElement(list(/datum/element/outpost_property))
	property.UnregisterSignal(fitting, list(
		COMSIG_ATOM_AFTER_ATTACKEDBY,
		COMSIG_PROJECTILE_PREHIT,
		COMSIG_ATOM_PREHITBY,
		COMSIG_ATOM_HULK_ATTACK,
		COMSIG_ATOM_ATTACK_MECH,
	))
	RegisterSignal(fitting, COMSIG_ATOM_AFTER_ATTACKEDBY, PROC_REF(on_melee_attack))
	RegisterSignal(fitting, COMSIG_PROJECTILE_PREHIT, PROC_REF(on_projectile_hit))
	RegisterSignal(fitting, COMSIG_ATOM_PREHITBY, PROC_REF(on_thrown_hit))
	RegisterSignal(fitting, COMSIG_ATOM_HULK_ATTACK, PROC_REF(on_hulk_attack))
	RegisterSignal(fitting, COMSIG_ATOM_ATTACK_MECH, PROC_REF(on_mech_attack))

/datum/element/outpost_floor_fitting/Detach(datum/source, ...)
	UnregisterSignal(source, list(
		COMSIG_ATOM_AFTER_ATTACKEDBY,
		COMSIG_PROJECTILE_PREHIT,
		COMSIG_ATOM_PREHITBY,
		COMSIG_ATOM_HULK_ATTACK,
		COMSIG_ATOM_ATTACK_MECH,
	))
	return ..()

/// Only a real damaging hit counts, as for any outpost property: not a shove, bare hands or a stamina weapon
/datum/element/outpost_floor_fitting/proc/report_hit(obj/fitting, atom/attacker, obj/item/tool)
	if(!isliving(attacker))
		return
	var/datum/outpost_floor/floor = get_outpost_floor_for_turf(get_turf(fitting))
	floor?.outpost?.police?.floor_fitting_hit(attacker, fitting, tool)

/datum/element/outpost_floor_fitting/proc/on_melee_attack(obj/source, obj/item/weapon, mob/attacker, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	if(!weapon.force || weapon.damtype == STAMINA)
		return
	report_hit(source, attacker, weapon)

/datum/element/outpost_floor_fitting/proc/on_projectile_hit(obj/source, obj/projectile/hit_projectile)
	SIGNAL_HANDLER
	if(!hit_projectile.is_hostile_projectile() || hit_projectile.damage_type == STAMINA)
		return
	report_hit(source, hit_projectile.firer)

/datum/element/outpost_floor_fitting/proc/on_thrown_hit(obj/source, atom/movable/hit_atom, datum/thrownthing/throwingdatum)
	SIGNAL_HANDLER
	if(!isitem(hit_atom))
		return
	var/obj/item/hit_item = hit_atom
	if(!hit_item.throwforce || hit_item.damtype == STAMINA)
		return
	report_hit(source, throwingdatum?.get_thrower(), hit_item)

/datum/element/outpost_floor_fitting/proc/on_hulk_attack(obj/source, mob/attacker)
	SIGNAL_HANDLER
	report_hit(source, attacker)

/datum/element/outpost_floor_fitting/proc/on_mech_attack(obj/source, obj/vehicle/sealed/mecha/mecha_attacker, mob/living/pilot)
	SIGNAL_HANDLER
	report_hit(source, pilot)

// ===== PACKING ONE AWAY =====

/**
 * `user` packs `fitting` back into a kit of `kit_type`: a manager of the floor (the owner or a steward), in
 * person. The kit lands in their hands. TRUE when it was packed. Sleeps for the pack time unless `instant`.
 */
/proc/outpost_fitting_pack(obj/fitting, mob/living/user, kit_type, instant = FALSE)
	var/datum/outpost_floor/floor = get_outpost_floor_for_turf(get_turf(fitting))
	// A mapped nameplate is the outpost's, not the crew's to take down
	if(!istype(user) || !floor?.host?.is_current_management_user(user) || !floor.shop_fittings_has(fitting))
		fitting.balloon_alert(user, "outpost property!")
		return FALSE
	if(!instant)
		fitting.balloon_alert(user, "packing...")
		if(!do_after(user, 2 SECONDS, target = fitting))
			return FALSE
		if(QDELETED(fitting) || QDELETED(floor) || !floor.host?.is_current_management_user(user))
			return FALSE
	var/obj/item/outpost_floor_kit/kit = new kit_type(fitting.drop_location())
	playsound(fitting, 'sound/items/deconstruct.ogg', 40, TRUE)
	log_game("OUTPOST FLOOR: [key_name(user)] packed away [fitting] at [AREACOORD(fitting)]")
	qdel(fitting)
	user.put_in_hands(kit)
	return TRUE

// ===== KITS =====

/// A fitting in its box
/obj/item/outpost_floor_kit
	name = "fitting kit"
	desc = "A shop fitting, flat-packed."
	icon = 'icons/obj/devices/circuitry_n_data.dmi'
	icon_state = "flatpack"
	w_class = WEIGHT_CLASS_BULKY
	/// OUTPOST_FLOOR_FITTING_*
	var/kind
	/// What comes out of the box
	var/fitting_type
	/// How long it takes to set down
	var/deploy_time = 3 SECONDS

/obj/item/outpost_floor_kit/till
	name = "till kit"
	desc = "A shop till, flat-packed."
	kind = OUTPOST_FLOOR_FITTING_TILL
	fitting_type = /obj/machinery/computer/outpost_shop_register/floor_till

/obj/item/outpost_floor_kit/shelf
	name = "sale shelf kit"
	desc = "A sale shelf, flat-packed."
	kind = OUTPOST_FLOOR_FITTING_SHELF
	fitting_type = /obj/structure/outpost_floor_shelf

/obj/item/outpost_floor_kit/sign
	name = "floor sign kit"
	desc = "A lit sign for a wall, flat-packed."
	kind = OUTPOST_FLOOR_FITTING_SIGN
	fitting_type = /obj/structure/sign/outpost_floor

/**
 * Why this kit may not be set down by `user` on `spot`, as balloon text, or null when it may (A82). A sign stands on
 * `spot` and hangs on `wall`. Only a buildable deck tile of a floor with a Shop room, by someone who may build
 * there, under the cap: never the landing, the goods lift, a ship or another crew's floor.
 */
/obj/item/outpost_floor_kit/proc/deploy_refusal(mob/living/user, turf/spot, turf/wall)
	var/datum/outpost_floor/floor = get_outpost_floor_for_turf(spot)
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor?.host
	if(!host || !isopenturf(spot) || !floor.is_buildable(spot))
		return "not here!"
	// L29, twice over: the building rule (floor_building.dm) and the floor's own roster
	if(!istype(user) || !outpost_floor_build_allowed(user, spot) || !(floor.is_member(user) || host.can_build(user)))
		return "not yours to build on!"
	if(!floor.shop_room())
		return "needs a shop!"
	if(floor.fitting_count(kind) >= floor.shop_fitting_max(kind))
		return "no more will fit!"
	if(kind == OUTPOST_FLOOR_FITTING_SIGN)
		// It hangs on a wall of this floor beside the tile it stands on, one to a wall face
		if(!iswallturf(wall) || !floor.contains_turf(wall) || get_dist(spot, wall) != 1 || !(get_dir(spot, wall) in GLOB.cardinals))
			return "needs a wall!"
		// Where it would be drawn. A name is up to four tiles wide: two signs side by side would write over each other.
		var/wall_dir = get_dir(spot, wall)
		var/drawn_x = spot.x * ICON_SIZE_X + ((wall_dir & EAST) ? ICON_SIZE_X : ((wall_dir & WEST) ? -ICON_SIZE_X : 0))
		var/drawn_y = spot.y * ICON_SIZE_Y + ((wall_dir & NORTH) ? ICON_SIZE_Y : ((wall_dir & SOUTH) ? -ICON_SIZE_Y : 0))
		for(var/obj/structure/sign/outpost_floor/hung in range(5, spot))
			if(abs(hung.y * ICON_SIZE_Y + hung.pixel_y - drawn_y) < ICON_SIZE_Y && abs(hung.x * ICON_SIZE_X + hung.pixel_x - drawn_x) < 4 * ICON_SIZE_X)
				return "not here!"
		return null
	if((locate(/obj/machinery/computer/outpost_shop_register) in spot) || (locate(/obj/structure/outpost_floor_shelf) in spot))
		return "not here!"
	return null

/**
 * Sets the fitting down, with every check made again at this moment. Returns the fitting, or null with a balloon
 * for `user`. Never sleeps: try_deploy() is the wait.
 */
/obj/item/outpost_floor_kit/proc/deploy(mob/living/user, turf/spot, turf/wall)
	var/refusal = deploy_refusal(user, spot, wall)
	if(refusal)
		balloon_alert(user, refusal)
		return null
	var/datum/outpost_floor/floor = get_outpost_floor_for_turf(spot)
	var/obj/fitting = new fitting_type(spot)
	floor.shop_add_fitting(fitting, kind)
	if(kind == OUTPOST_FLOOR_FITTING_SIGN)
		var/obj/structure/sign/outpost_floor/hung = fitting
		hung.hang_on(wall)
		hung.refresh()
	floor.shop_watch_stock()
	playsound(spot, 'sound/items/deconstruct.ogg', 40, TRUE)
	log_game("OUTPOST FLOOR: [key_name(user)] set down [fitting] at [AREACOORD(spot)]")
	record_floor_metric("floor_fitting", floor, user, 1)
	qdel(src)
	return fitting

/// The player's way in: the checks, the wait, then deploy()
/obj/item/outpost_floor_kit/proc/try_deploy(mob/living/user, turf/spot, turf/wall)
	var/refusal = deploy_refusal(user, spot, wall)
	if(refusal)
		balloon_alert(user, refusal)
		return FALSE
	balloon_alert(user, "setting up...")
	if(!do_after(user, deploy_time, target = spot) || QDELETED(src) || !user.is_holding(src))
		return FALSE
	return !!deploy(user, spot, wall)

/obj/item/outpost_floor_kit/attack_self(mob/user)
	if(!isliving(user))
		return
	if(kind == OUTPOST_FLOOR_FITTING_SIGN)
		balloon_alert(user, "needs a wall!")
		return
	try_deploy(user, get_turf(user))

/// Used on a deck tile or on a counter: the fitting goes there. A sign kit is used on a wall.
/obj/item/outpost_floor_kit/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(kind == OUTPOST_FLOOR_FITTING_SIGN)
		if(!iswallturf(interacting_with))
			return NONE
		return try_deploy(user, get_turf(user), interacting_with) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING
	var/turf/spot = interacting_with
	if(istype(interacting_with, /obj/structure/table))
		spot = get_turf(interacting_with)
		// A table asks the item first and puts it down only if the item does nothing (tables_racks.dm). Wherever
		// the fitting may not go, the kit is put on the table like anything else.
		if(deploy_refusal(user, spot))
			return NONE
	if(!isopenturf(spot))
		return NONE
	return try_deploy(user, spot) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING

// ===== THE TILL =====

/// A second register anywhere on the floor. It sells from the Shop room's stock (the host's owns_till()).
/obj/machinery/computer/outpost_shop_register/floor_till
	name = "till"
	desc = "A shop till."
	icon_state = "laptop"
	icon_keyboard = "laptop_key"
	icon_screen = "medlaptop"
	// A94: twenty of these must never make a wall. It sits on a counter.
	density = FALSE

/obj/machinery/computer/outpost_shop_register/floor_till/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_floor_fitting)

/obj/machinery/computer/outpost_shop_register/floor_till/Destroy()
	get_outpost_floor_for_turf(get_turf(src))?.shop_drop_fitting(src)
	return ..()

/obj/machinery/computer/outpost_shop_register/floor_till/click_alt(mob/user)
	return outpost_fitting_pack(src, user, /obj/item/outpost_floor_kit/till) ? CLICK_ACTION_SUCCESS : CLICK_ACTION_BLOCKING

/obj/machinery/computer/outpost_shop_register/floor_till/ui_interact(mob/user, datum/tgui/ui)
	// The stock unit only pushes to its room's own register: the floor watches the stock for its tills
	get_outpost_floor_for_turf(get_turf(src))?.shop_watch_stock()
	return ..()

/// Whether `user` works this shop: a manager, a pricer or a hired hand, in person
/obj/machinery/computer/outpost_shop_register/floor_till/proc/is_staff(mob/user)
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	return !!(home && get_shop() && (home.is_current_management_user(user) || home.is_current_pricing_user(user) || home.is_shop_hand(user)))

/// The buyer window's data, and for staff the open flag and the sales (OutpostShop.tsx)
/obj/machinery/computer/outpost_shop_register/floor_till/ui_data(mob/user)
	. = ..()
	var/datum/outpost_upgrade/service/shop/shop = get_shop()
	var/staff = is_staff(user)
	.["can_toggle"] = staff
	.["shop_open"] = !!shop?.is_open
	var/list/sale_rows
	if(staff)
		sale_rows = list()
		var/list/sales_log = shop?.get_stock()?.sales_log
		for(var/index in length(sales_log) to 1 step -1)
			sale_rows += list(sales_log[index])
	.["sales"] = sale_rows

/obj/machinery/computer/outpost_shop_register/floor_till/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || action != "toggle_open")
		return
	// set_open() checks who may; a visitor's forged click gets "Staff only."
	var/datum/outpost_upgrade/service/shop/shop = get_shop()
	var/mob/living/user = ui.user
	var/refusal = shop ? shop.set_open(user, !shop.is_open) : "Shop not installed."
	if(refusal)
		balloon_alert(user, LOWER_TEXT(refusal))
	return TRUE

/obj/machinery/computer/outpost_shop_register/floor_till/buy(mob/living/user, id, quantity, shown_unit_price)
	. = ..()
	if(isnull(.))
		get_outpost_floor_for_turf(get_turf(src))?.shop_note_sale(get_stock(), OUTPOST_FLOOR_FITTING_TILL)

// ===== THE SALE SHELF =====

/// Shows one listing of the shop's stock and sells it
/obj/structure/outpost_floor_shelf
	name = "sale shelf"
	desc = "A low shelf for goods on sale."
	icon = 'voidcrew/icons/obj/storage/cargo_shelf.dmi'
	icon_state = "shelf_base"
	layer = BELOW_OBJ_LAYER
	anchored = TRUE
	// A94: never dense
	density = FALSE
	/// The listing on show: its id in the shop's stock unit
	var/listing_id
	/// The stock unit that id belongs to. A Shop room placed again has a new one, whose ids start over.
	var/datum/weakref/listing_stock
	/// People with the "buy this?" question open, so a second click asks nothing
	var/list/asking

/obj/structure/outpost_floor_shelf/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_floor_fitting)

/obj/structure/outpost_floor_shelf/Destroy()
	get_outpost_floor_for_turf(get_turf(src))?.shop_drop_fitting(src)
	asking = null
	return ..()

/obj/structure/outpost_floor_shelf/click_alt(mob/user)
	return outpost_fitting_pack(src, user, /obj/item/outpost_floor_kit/shelf) ? CLICK_ACTION_SUCCESS : CLICK_ACTION_BLOCKING

/obj/structure/outpost_floor_shelf/proc/get_stock()
	var/datum/outpost_floor/floor = get_outpost_floor_for_turf(get_turf(src))
	return floor?.shop_stock()

/// The listing on show, or null: none set, forgotten, or the shop gone
/obj/structure/outpost_floor_shelf/proc/shown_listing()
	if(!listing_id)
		return null
	var/obj/machinery/outpost_shop_stock/stock = get_stock()
	if(!stock || listing_stock?.resolve() != stock)
		return null
	return stock.listings_by_id[listing_id]

/// Puts `listing` of the shop's stock on show, or nothing
/obj/structure/outpost_floor_shelf/proc/show_listing(datum/outpost_shop_listing/listing)
	var/obj/machinery/outpost_shop_stock/stock = get_stock()
	listing_id = (listing && stock) ? listing.id : null
	listing_stock = listing_id ? WEAKREF(stock) : null
	update_appearance()

/// The goods stand on the shelf: the look of the unit that sells next. An empty shelf is sold out.
/obj/structure/outpost_floor_shelf/update_overlays()
	. = ..()
	var/datum/outpost_shop_listing/listing = shown_listing()
	var/obj/item/unit = listing?.next_unit()
	if(!unit)
		return
	var/mutable_appearance/goods = new(unit)
	goods.plane = FLOAT_PLANE
	goods.layer = FLOAT_LAYER
	goods.dir = SOUTH
	goods.pixel_x = 0
	goods.pixel_y = 0
	goods.pixel_w = 0
	goods.pixel_z = 5
	goods.transform = null
	goods.appearance_flags |= RESET_COLOR | RESET_ALPHA
	. += goods

/obj/structure/outpost_floor_shelf/examine(mob/user)
	. = ..()
	var/datum/outpost_shop_listing/listing = shown_listing()
	var/obj/machinery/outpost_shop_stock/stock = get_stock()
	if(!listing || !stock || stock.closed_reason())
		return
	if(listing.price > 0 && listing.unit_count())
		. += span_notice("[listing.name], [listing.price] cr.")
	else
		. += span_notice("[listing.name]. Sold out.")

/// A stocker's item goes into the stock and the shelf shows that listing. Anyone else is asking to buy.
/obj/structure/outpost_floor_shelf/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(user.combat_mode)
		return NONE
	var/obj/machinery/outpost_shop_stock/stock = get_stock()
	if(!stock?.can_stock(user))
		INVOKE_ASYNC(src, PROC_REF(offer_sale), user)
		return ITEM_INTERACT_BLOCKING
	return stock_shelf(user, tool) ? ITEM_INTERACT_BLOCKING : ITEM_INTERACT_SUCCESS

/**
 * `user`, a stocker, puts `item` on the shelf: it goes into the shop's stock as at the stock unit, and the shelf
 * shows its listing. Null when stocked, else the refusal (with a balloon).
 */
/obj/structure/outpost_floor_shelf/proc/stock_shelf(mob/living/user, obj/item/item)
	var/obj/machinery/outpost_shop_stock/stock = get_stock()
	if(!stock)
		return "Shop not installed."
	// Taken before it goes in: a stack that tops up another is gone afterwards
	var/key = stock.refusal_reason(item) ? null : stock.listing_key(item)
	var/refusal = stock.stock_item(item, user)
	if(refusal)
		balloon_alert(user, LOWER_TEXT(refusal))
		return refusal
	show_listing(stock.listing_by_key[key])
	playsound(src, 'sound/machines/machine_vend.ogg', 30, TRUE, extrarange = -3)
	get_outpost_floor_for_turf(get_turf(src))?.shop_watch_stock()
	return null

/obj/structure/outpost_floor_shelf/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	INVOKE_ASYNC(src, PROC_REF(offer_sale), user)
	return TRUE

/// Asks `user` once whether they want the thing on the shelf, at the price they are looking at, and sells it
/obj/structure/outpost_floor_shelf/proc/offer_sale(mob/living/user)
	if(!istype(user) || (REF(user) in asking))
		return
	var/datum/outpost_shop_listing/listing = shown_listing()
	var/obj/machinery/outpost_shop_stock/stock = get_stock()
	var/closed = stock ? stock.closed_reason() : "Closed."
	if(closed)
		balloon_alert(user, LOWER_TEXT(closed))
		return
	if(!listing || listing.price <= 0 || !listing.unit_count())
		balloon_alert(user, "sold out!")
		return
	var/obj/structure/overmap/dynamic/player_outpost/home = stock.get_outpost()
	var/price = home?.can_take_shop_stock(user) ? 0 : listing.price
	LAZYADD(asking, REF(user))
	var/answer = tgui_alert(user, price ? "Buy [listing.name] for [price] cr?" : "Take [listing.name]?", "Sale shelf", list(price ? "Buy" : "Take", "No"), 20 SECONDS)
	LAZYREMOVE(asking, REF(user))
	if(QDELETED(src) || QDELETED(user) || user.stat != CONSCIOUS || (answer != "Buy" && answer != "Take"))
		return
	buy(user, listing, price)

/**
 * One unit of `listing` to `user` at the price they were quoted, through the stock unit's own sale: a moved price,
 * a shut shop, an empty listing or a step away refuses, and nothing moves. Null when sold, else the refusal.
 */
/obj/structure/outpost_floor_shelf/proc/buy(mob/living/user, datum/outpost_shop_listing/listing, shown_price)
	var/obj/machinery/outpost_shop_stock/stock = get_stock()
	var/refusal
	if(!stock || QDELETED(listing) || listing != shown_listing())
		refusal = "Sold out."
	else
		refusal = stock.sell(listing, 1, shown_price, user, src)
	if(refusal)
		balloon_alert(user, LOWER_TEXT(refusal))
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)
		return refusal
	get_outpost_floor_for_turf(get_turf(src))?.shop_note_sale(stock, OUTPOST_FLOOR_FITTING_SHELF)
	playsound(src, 'sound/effects/cashregister.ogg', 40, TRUE)
	update_appearance()
	return null

// ===== THE FLOOR SIGN =====

/// The floor's name in its colour, and OPEN or SHUT under it. The nameplate by the front door is one of these.
/obj/structure/sign/outpost_floor
	name = "floor sign"
	desc = "A lit sign."
	icon = 'icons/obj/machines/computer.dmi'
	icon_state = "plaque"
	buildable_sign = FALSE
	// The name is 24 characters at most (OUTPOST_FLOOR_NAME_MAX), and 24 of the small font's widest letter are 192
	// pixels: always one line in this box, centred on the sign, with OPEN or SHUT on the screen under it. Anything
	// more would wrap upward and be cut at the box.
	maptext_width = 192
	maptext_height = 26
	maptext_x = -80
	maptext_y = 12
	/// The side of its tile the wall it hangs on is: 0 for one the shell map placed
	var/wall_dir = NONE

/// The shell map's sign by the front door. It shows what any floor sign shows, and is the outpost's: it never
/// counts against the crew's signs and nobody packs it away.
/obj/structure/sign/outpost_floor/nameplate
	name = "nameplate"

/obj/structure/sign/outpost_floor/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_floor_fitting)
	return INITIALIZE_HINT_LATELOAD

/// A mapped sign joins its floor here when the floor already has its ground; shop_refresh_signs() finds it if not
/obj/structure/sign/outpost_floor/LateInitialize()
	refresh()

/obj/structure/sign/outpost_floor/Destroy()
	get_outpost_floor_for_turf(get_turf(src))?.shop_drop_fitting(src)
	return ..()

/// Fastens the sign to `wall`, a wall beside its tile, and shifts it onto that wall as a sign backing is
/obj/structure/sign/outpost_floor/proc/hang_on(turf/wall)
	wall_dir = get_dir(src, wall)
	pixel_x = (wall_dir & EAST) ? 32 : ((wall_dir & WEST) ? -32 : 0)
	pixel_y = (wall_dir & NORTH) ? 32 : ((wall_dir & SOUTH) ? -32 : 0)
	// The picture stays the front view whichever wall it is on, so the mount is made by hand and not by facing
	var/datum/component/wall_mounted/by_facing = GetComponent(/datum/component/wall_mounted)
	if(by_facing)
		qdel(by_facing)
	if(iswallturf(wall))
		AddComponent(/datum/component/wall_mounted, wall, knock_down_callback)

/// The wall under it is gone (a crew's own wall): it comes down as its kit, never as a sign backing
/obj/structure/sign/outpost_floor/knock_down(mob/living/user)
	if(QDELETED(src))
		return
	var/datum/outpost_floor/floor = get_outpost_floor_for_turf(get_turf(src))
	if(floor?.shop_fittings_has(src))
		new /obj/item/outpost_floor_kit/sign(drop_location())
	qdel(src)

/obj/structure/sign/outpost_floor/click_alt(mob/user)
	return outpost_fitting_pack(src, user, /obj/item/outpost_floor_kit/sign) ? CLICK_ACTION_SUCCESS : CLICK_ACTION_BLOCKING

/// Shows the floor's name and whether its shop is open. A sign the map placed joins its floor's plates here.
/obj/structure/sign/outpost_floor/proc/refresh()
	var/datum/outpost_floor/floor = get_outpost_floor_for_turf(get_turf(src))
	if(!floor)
		name = initial(name)
		maptext = null
		return
	if(!floor.shop_fittings_has(src))
		LAZYOR(floor.shop_plates, WEAKREF(src))
	// The floor's name is cleaned where it is typed (set_name(), reject_bad_text()): it holds no markup
	var/shown = floor.shop_sign_name()
	var/status = floor.shop_sign_status()
	name = shown
	var/status_line = status ? "<br><span style='color: [status == "OPEN" ? "#7be07b" : "#e06a6a"]'>[status]</span>" : ""
	maptext = MAPTEXT_TINY_UNICODE("<span style='text-align: center; vertical-align: bottom'><span style='color: [floor.accent_colour()]'>[shown]</span>[status_line]</span>")

/obj/structure/sign/outpost_floor/examine(mob/user)
	. = ..()
	var/datum/outpost_floor/floor = get_outpost_floor_for_turf(get_turf(src))
	// Read, a sign that has fallen behind its floor catches up
	floor?.shop_check_signs()
	var/status = floor?.shop_sign_status()
	if(status)
		. += span_notice("It reads: [status].")
