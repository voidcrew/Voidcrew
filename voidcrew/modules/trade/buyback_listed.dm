/**
 * # Listed buybacks: shared helpers for ledger rows that name their goods
 *
 * Most buyback rows take "any X". The depot's rare-goods rows instead take a
 * fixed list of exact types (a red-zone rifle, one theme of MODsuit), so a toy
 * or printed subtype of the same parent never reaches a voucher payout. These
 * procs are shared by the outfitter, Skunkworks and Fitting Bay ledgers
 * (shop_catalog_outfitter*.dm, shop_catalog_suit_vendor.dm).
 *
 * Two extra refusals ride along:
 * - Loose goods only. The seller's contents sweep reaches inside everything,
 *   so a slime extract cycling inside a recurring crossbreed, or an anomaly
 *   core seated in a MOD module, would otherwise be ripped out and sold.
 * - Ship's issue. Gear mapped aboard a player hull when it loads is part of
 *   what the crew bought with the ship, not a find. It is flagged here and the
 *   rare rows refuse it; the plain salvage rows still take it as before.
 */

/obj/item
	/// Mapped aboard a player hull at load (see check_buyback_hull_issue()). Rare buyback rows refuse it.
	var/buyback_hull_issue = FALSE

/// Item roots the rare rows buy from. Only these get the hull check, which keeps it off the hot path.
GLOBAL_LIST_INIT(buyback_hull_watch, typecacheof(list(
	/obj/item/gun,
	/obj/item/melee,
	/obj/item/claymore,
	/obj/item/katana,
	/obj/item/cursed_katana,
	/obj/item/energy_katana,
	/obj/item/mjollnir,
	/obj/item/spear,
	/obj/item/shield,
	/obj/item/cain_and_abel,
	/obj/item/cane/shepherds_crook,
	/obj/item/garrison_standard,
	/obj/item/heave_ho,
	/obj/item/hierophant_club,
	/obj/item/knife/understudy,
	/obj/item/lava_staff,
	/obj/item/veilrender,
	/obj/item/clothing/suit,
	/obj/item/clothing/head,
	/obj/item/mod/control,
	/obj/item/mod/module,
)))

/obj/item/Initialize(mapload)
	. = ..()
	if(mapload && GLOB.buyback_hull_watch[type])
		check_buyback_hull_issue()

/**
 * Flags gear that loads with a player hull. A player ship loads with
 * SSshuttle.loading_ship (or a shipyard order) set; its upgrade modules load
 * a moment later, by which time the hull's areas know their port and ship.
 * NPC hulls use the same maps, but their loot is a find, so they stay clear.
 */
/obj/item/proc/check_buyback_hull_issue()
	var/area/shuttle/voidcrew/hull_area = get_area(src)
	if(!istype(hull_area))
		return
	var/obj/structure/overmap/ship/hull_ship = SSshuttle.loading_ship || hull_area.shuttle_port?.current_ship
	if(!hull_ship)
		if(SSshuttle.loading_order)
			buyback_hull_issue = TRUE
		return
	if(istype(hull_ship, /obj/structure/overmap/ship/npc))
		return
	buyback_hull_issue = TRUE

/// Carried loose: in hand, a pocket or slot, or a bag. Not seated inside some other device.
/proc/buyback_goods_loose(obj/item/offered)
	var/atom/holder = offered.loc
	if(ismob(holder))
		return TRUE
	return !isnull(holder?.atom_storage) && !istype(holder, /obj/item/mod/control)

/// Exact-type cache for a listed row.
/proc/buyback_exact_cache(list/types)
	return typecacheof(types, only_root_path = TRUE)

/// Shows a listed row with its display item's sprite.
/proc/buyback_use_display_icon(datum/shop_buyback/entry, obj/item/display_path)
	if(!ispath(display_path))
		return
	entry.icon_override = initial(display_path.icon)
	entry.icon_state_override = initial(display_path.icon_state)

/// Whether an item is this row's kind of goods, ignoring who owns it or where it sits. Listed rows override.
/datum/shop_buyback/proc/buyback_wanted_kind(obj/item/offered)
	return istype(offered, item_path)

/**
 * Refusal text for a listed row. The stock one keys off item_path, which a
 * listed row sets to a broad parent, so it named unrelated shop stock.
 */
/proc/buyback_listed_denial(datum/shop_buyback/entry, mob/living/user)
	if(entry.demand <= 0)
		return "Not buying any more this shift."
	if(entry.count_carried_units(user) < 1)
		for(var/obj/item/offered in user.get_all_contents())
			if(!entry.buyback_wanted_kind(offered))
				continue
			if(is_trader_good(offered))
				return "I don't buy back shop stock."
			if(offered.buyback_hull_issue)
				return "That's your ship's own kit."
		return "Carrying none of the goods: [entry.get_wanted_text()]."
	if(entry.pay_credits > 0 && !get_shop_buyback_account(user))
		return "No bank account on your ID."
	return null

/**
 * A core refined from a bought raw core is still the trader's stock. Without
 * this, a raw core off Boffin's shelf came out of the refinery as a clean
 * object and could go straight back over his counter.
 */
/obj/item/raw_anomaly_core/create_core(newloc, del_self = FALSE, count_towards_limit = FALSE)
	var/from_trader = is_trader_good(src)
	. = ..()
	if(from_trader && .)
		mark_trader_goods(.)
