/// Mechs each stand pool has dealt this round, server-wide: pool typepath -> count. See deals_per_round.
GLOBAL_LIST_EMPTY(rig_bay_pool_deals)

/**
 * # Rig Bay stand
 *
 * A gantry at Wick's that holds one exosuit for sale, hung on chains RIG_BAY_HANG_LIFT pixels up.
 * The stand owns its mech's SKU on the suit fitter's shop: stock 1 while the mech hangs there,
 * 0 otherwise. Buying it lowers the mech and frees it for the buyer's crew; the crew drives it off.
 *
 * Seam contract (data/rig-bay/spec.md sections 5, 6, 11):
 * - P1 adds the clamp/hold components and the shop wiring (attach_stand, restock_stands, dispense).
 * - P4 overrides animate_release(), animate_beam_in() and apply_hang_pose() in rig_bay_stand_visuals.dm.
 *
 * Always dense, so nobody stands or parks on it. A mech already on the tile can still drive off.
 */
/obj/structure/rig_bay_stand
	name = "rig stand"
	desc = "A heavy gantry with chains for hanging an exosuit."
	icon = 'icons/obj/machines/telepad.dmi'
	icon_state = "mechpad"
	anchored = TRUE
	density = TRUE
	move_resist = INFINITY
	/// Number painted on the stand and shown in the shop line ("Ripley, bay 2"). Set on the map.
	var/bay_number = 1
	/// /datum/shop_rotation/rig_bay typepath this stand deals its mechs from. Set on the map.
	var/pool = /datum/shop_rotation/rig_bay/work
	/// The mech on the stand: hanging for sale, being lowered, or sold but not yet driven off.
	var/obj/vehicle/sealed/mecha/held_mech
	/// This stand's line in the shop. Kept at stock 0 after a sale until the stand deals a new mech.
	var/datum/shop_sku/rig_bay_mech/sku
	/// The trader outpost this stand belongs to. Set by link_outpost().
	var/obj/structure/overmap/trader_outpost/outpost
	/// The suit fitter's shop that lists this stand's mech. Set by link_outpost().
	var/datum/outpost_shop/vendor/suit_fitter/shop
	/// Convoys this stand has waited while empty, counted against its pool's convoys_per_refill.
	var/convoys_waited = 0
	/// One of the RIG_BAY_STAND_* states.
	var/stand_state = RIG_BAY_STAND_EMPTY
	/// While a due restock waits for the stand tile to clear: retries the deal every RIG_BAY_RETRY_DELAY.
	var/retry_timer

/obj/structure/rig_bay_stand/Destroy()
	if(held_mech)
		var/obj/vehicle/sealed/mecha/mech = held_mech
		var/unsold = (stand_state == RIG_BAY_STAND_ARRIVING || stand_state == RIG_BAY_STAND_CLAMPED)
		forget_mech()
		// Shop stock never leaks out; a sold mech belongs to its buyer.
		if(unsold)
			qdel(mech)
	drop_sku()
	stop_retry()
	shop = null
	outpost = null
	return ..()

/**
 * Called once from the outpost's interior link sweep (round start and lazy load). Finds the suit
 * fitter's shop and deals the first mech without animation. The deal waits for atom init, because
 * the round-start pre-load runs before SSatoms.
 */
/obj/structure/rig_bay_stand/proc/link_outpost(obj/structure/overmap/trader_outpost/new_outpost)
	if(outpost || !new_outpost)
		return
	outpost = new_outpost
	shop = outpost.get_shop(/datum/outpost_shop/vendor/suit_fitter)
	shop?.attach_stand(src)
	if(SSatoms.initialized == INITIALIZATION_INNEW_REGULAR)
		deal_mech(animate = FALSE)
	else
		addtimer(CALLBACK(src, PROC_REF(deal_mech), FALSE), 1)

/**
 * Picks a mech from the pool (preferring one no other stand of the same pool is showing), swaps
 * the stand's old SKU for a new one in the shop and puts the mech on the stand.
 * Returns the new mech, or null if the stand isn't empty, isn't linked or its tile is blocked.
 */
/obj/structure/rig_bay_stand/proc/deal_mech(animate = TRUE)
	if(QDELETED(src) || !shop || stand_state != RIG_BAY_STAND_EMPTY || !ispath(pool, /datum/shop_rotation/rig_bay))
		return null
	if(!tile_clear() || !pool_can_deal())
		return null
	var/datum/shop_rotation/rig_bay/rotation = locate(pool) in shop.live_rotations
	var/temporary_rotation = !rotation
	if(temporary_rotation)
		rotation = new pool
	var/list/showing = list()
	for(var/datum/shop_sku/rig_bay_mech/other in shop.skus)
		if(other.stand && other.stand != src && other.stand.pool == pool)
			showing += other.type
	var/sku_type = rotation.pick_one(showing) || rotation.pick_one()
	if(temporary_rotation)
		qdel(rotation)
	if(!sku_type)
		return null
	drop_sku()
	shop.add_sku(sku_type, SHELF_CORE)
	. = receive_mech(shop.skus[length(shop.skus)], animate)
	if(.)
		GLOB.rig_bay_pool_deals[pool] = (GLOB.rig_bay_pool_deals[pool] || 0) + 1

/**
 * Takes ownership of `new_sku` (already in shop.skus) and spawns its mech on the stand with its kit,
 * anchored and marked as trader goods. With `animate` it beams in through animate_beam_in();
 * the SKU stays at stock 0 until finish_arrival(). Returns the mech, or null on a bad SKU or blocked tile.
 */
/obj/structure/rig_bay_stand/proc/receive_mech(datum/shop_sku/rig_bay_mech/new_sku, animate = TRUE)
	if(!istype(new_sku) || !ispath(new_sku.item_path, /obj/vehicle/sealed/mecha) || held_mech || !tile_clear())
		return null
	sku = new_sku
	new_sku.stand = src
	new_sku.stock = 0
	var/obj/vehicle/sealed/mecha/mech_type = new_sku.item_path
	new_sku.name = "[initial(mech_type.name)], bay [bay_number]"
	var/obj/vehicle/sealed/mecha/mech = new mech_type(loc)
	held_mech = mech
	for(var/kit_type in new_sku.spawn_kit)
		var/obj/item/mecha_parts/mecha_equipment/part = new kit_type(mech)
		if(part.can_attach(mech))
			part.attach(mech)
		else
			qdel(part)
	// Some stock builds come locked to an access no crew carries (Paddy, Justice). Sold mechs open to whoever buys them.
	mech.mecha_flags &= ~ID_LOCK_ON
	mark_trader_goods(mech)
	mech.setDir(dir)
	mech.set_anchored(TRUE)
	RegisterSignal(mech, COMSIG_QDELETING, PROC_REF(on_mech_deleted))
	RegisterSignal(mech, COMSIG_MOVABLE_MOVED, PROC_REF(on_mech_moved))
	mech.AddComponent(/datum/component/rig_bay_clamp, src)
	stand_state = RIG_BAY_STAND_ARRIVING
	if(animate)
		mech.alpha = 0
		animate_beam_in(mech, CALLBACK(src, PROC_REF(finish_arrival), mech))
	else
		apply_hang_pose(mech)
		finish_arrival(mech)
	return mech

/// Beam-in done: the mech hangs for sale and its shop line goes to stock 1.
/obj/structure/rig_bay_stand/proc/finish_arrival(obj/vehicle/sealed/mecha/mech)
	if(QDELETED(src) || QDELETED(mech) || mech != held_mech || stand_state != RIG_BAY_STAND_ARRIVING)
		return
	stand_state = RIG_BAY_STAND_CLAMPED
	if(sku)
		sku.stock = 1
	shop?.trader_npc?.shop_ui?.update_static_data_for_all_viewers()

/**
 * The sale: lowers the hanging mech and frees it for `buyer`'s crew. Called from the SKU's
 * dispense() after the shop has charged. Returns FALSE if there is no hanging mech to hand over,
 * so the caller refunds.
 */
/obj/structure/rig_bay_stand/proc/release_mech(mob/living/buyer)
	if(stand_state != RIG_BAY_STAND_CLAMPED || QDELETED(held_mech))
		return FALSE
	stand_state = RIG_BAY_STAND_RELEASING
	if(sku)
		sku.stock = 0
	// Chains off, the buyer's hold on, then the lowering. The hold keeps the mech still until it is down.
	var/datum/voidcrew_crew_record/crew = get_crew_ship(buyer)?.get_crew_record() || buyer?.mind?.get_reputation_crew()
	qdel(held_mech.GetComponent(/datum/component/rig_bay_clamp))
	held_mech.AddComponent(/datum/component/rig_bay_hold, crew)
	to_chat(buyer, span_notice("The chains on bay [bay_number] drop."))
	animate_release(held_mech, CALLBACK(src, PROC_REF(finish_release), held_mech))
	return TRUE

/// Lowering done: the mech is free to drive off. The stand stays SOLD_ON_STAND until it leaves.
/obj/structure/rig_bay_stand/proc/finish_release(obj/vehicle/sealed/mecha/mech)
	if(QDELETED(src) || QDELETED(mech) || mech != held_mech || stand_state != RIG_BAY_STAND_RELEASING)
		return
	mech.set_anchored(FALSE)
	stand_state = RIG_BAY_STAND_SOLD_ON_STAND

/**
 * Release animation. Default: instant. P4 overrides it (draft 1.1 s).
 * Must end with `mech.pixel_z` at 0 and then invoke `on_done` exactly once.
 */
/obj/structure/rig_bay_stand/proc/animate_release(obj/vehicle/sealed/mecha/mech, datum/callback/on_done)
	mech.pixel_z = 0
	on_done?.Invoke()

/**
 * Beam-in animation. Default: instant. P4 overrides it (draft 3.0 s).
 * The mech arrives at alpha 0, anchored, with its SKU at stock 0. Move it with pixel_z only,
 * end in the hang pose (apply_hang_pose) and then invoke `on_done` exactly once.
 */
/obj/structure/rig_bay_stand/proc/animate_beam_in(obj/vehicle/sealed/mecha/mech, datum/callback/on_done)
	apply_hang_pose(mech)
	on_done?.Invoke()

/// The idle look of a mech hanging on the stand. P4 adds the chains here.
/obj/structure/rig_bay_stand/proc/apply_hang_pose(obj/vehicle/sealed/mecha/mech)
	mech.alpha = 255
	mech.pixel_z = RIG_BAY_HANG_LIFT

/**
 * The convoy came through. An empty stand counts it toward its pool's convoys_per_refill and deals a
 * new mech once the count is reached. If the tile is blocked it retries every RIG_BAY_RETRY_DELAY
 * until the next convoy. A stand with a mech on it (hanging or sold) waits.
 */
/obj/structure/rig_bay_stand/proc/convoy_arrived()
	stop_retry()
	if(stand_state != RIG_BAY_STAND_EMPTY || !pool_can_deal())
		convoys_waited = 0
		return
	if(++convoys_waited < get_convoys_per_refill())
		return
	if(deal_mech(animate = TRUE))
		convoys_waited = 0
		return
	if(stand_state == RIG_BAY_STAND_EMPTY && shop)
		retry_timer = addtimer(CALLBACK(src, PROC_REF(retry_deal)), RIG_BAY_RETRY_DELAY, TIMER_STOPPABLE | TIMER_LOOP | TIMER_DELETE_ME)

/// A due restock found the tile blocked. Tries again until it deals or the next convoy takes over.
/obj/structure/rig_bay_stand/proc/retry_deal()
	if(stand_state != RIG_BAY_STAND_EMPTY || !pool_can_deal())
		stop_retry()
		return
	if(deal_mech(animate = TRUE))
		convoys_waited = 0
		stop_retry()

/obj/structure/rig_bay_stand/proc/stop_retry()
	if(retry_timer)
		deltimer(retry_timer)
		retry_timer = null

/// Convoys an empty stand waits before its next mech, from its pool.
/obj/structure/rig_bay_stand/proc/get_convoys_per_refill()
	var/datum/shop_rotation/rig_bay/rotation = shop ? (locate(pool) in shop.live_rotations) : null
	if(rotation)
		return max(1, rotation.convoys_per_refill)
	if(!ispath(pool, /datum/shop_rotation/rig_bay))
		return 1
	var/datum/shop_rotation/rig_bay/rotation_type = pool
	return max(1, initial(rotation_type.convoys_per_refill))

/// FALSE once this stand's pool has dealt its deals_per_round for the whole server.
/obj/structure/rig_bay_stand/proc/pool_can_deal()
	if(!ispath(pool, /datum/shop_rotation/rig_bay))
		return FALSE
	var/datum/shop_rotation/rig_bay/rotation_type = pool
	var/limit = initial(rotation_type.deals_per_round)
	return limit <= 0 || (GLOB.rig_bay_pool_deals[pool] || 0) < limit

/// TRUE if a new mech can be placed: no mob, mech or other dense thing on the stand tile.
/obj/structure/rig_bay_stand/proc/tile_clear()
	var/turf/tile = get_turf(src)
	if(!tile)
		return FALSE
	for(var/atom/movable/thing as anything in tile)
		if(thing == src)
			continue
		if(isliving(thing) || ismecha(thing) || thing.density)
			return FALSE
	return TRUE

/// Drops this stand's SKU from the shop and deletes it.
/obj/structure/rig_bay_stand/proc/drop_sku()
	if(!sku)
		return
	var/datum/shop_sku/rig_bay_mech/old_sku = sku
	sku = null
	if(shop)
		shop.skus -= old_sku
	qdel(old_sku)

/// Lets go of the held mech's signals and refs. Leaves the SKU listed (stock 0) until the next deal.
/obj/structure/rig_bay_stand/proc/forget_mech()
	if(!held_mech)
		return
	UnregisterSignal(held_mech, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED))
	held_mech = null
	stand_state = RIG_BAY_STAND_EMPTY
	if(sku)
		sku.stock = 0

/// The mech was deleted (gibbed, admin delete): the stand goes empty.
/obj/structure/rig_bay_stand/proc/on_mech_deleted(datum/source)
	SIGNAL_HANDLER
	forget_mech()

/// The mech left the stand tile: the stand goes empty and waits for a convoy.
/obj/structure/rig_bay_stand/proc/on_mech_moved(datum/source)
	SIGNAL_HANDLER
	if(held_mech && held_mech.loc != loc)
		forget_mech()

// ===== MAP MARKERS =====

/**
 * An open doorway that counts as a room edge for outpost ambient workers (outpost_work_barrier()),
 * so a worker's room fill stops here. Invisible and not dense; customers walk over it.
 */
/obj/effect/landmark/outpost_work_threshold
	name = "outpost work threshold"
