/**
 * # Outpost safe storage
 *
 * A service room (outpost_service_rooms.dm) of rental lockers. A visitor pays the outpost's
 * locker price once and the locker is theirs for the rest of the round; members rent free.
 *
 * The lock answers to the renter's ckey and nothing else: not an ID card, not access, not the
 * outpost owner. Closets ignore access on Voidcrew (ship_access.dm), so the lock never goes
 * near allowed(): can_unlock() is overridden and id_card is never set. The same player opens
 * their locker from any body: after a death, a clone, a respawn or a cryo rejoin.
 *
 * A rental ends only when the renter gives it up (while it is open, so the contents are
 * already out), when an admin releases it, or when the outpost is deleted, which deletes the
 * lockers and everything in them.
 *
 * What a locker refuses: mobs of any kind at any depth (a locked-in person could never get out),
 * explosives and trigger devices (a signaler works from anywhere, and the owner cannot open the
 * locker to disarm a bomb). Explosions that start inside are cancelled, and gas leaking from a
 * stored tank is absorbed rather than let into the room.
 */

/// Everything refused inside a locker besides mobs: explosives and anything that triggers one
GLOBAL_LIST_INIT(outpost_storage_refused, typecacheof(list(
	/obj/item/grenade,
	/obj/item/transfer_valve,
	/obj/item/bombcore,
	/obj/item/gibtonite,
	/obj/item/assembly_holder,
	/obj/item/assembly/signaler,
	/obj/item/assembly/timer,
	/obj/item/assembly/prox_sensor,
	/obj/item/assembly/voice,
	/obj/item/assembly/health,
	/obj/item/assembly/infra,
)))

// ===== THE ROOM =====

/// Authored with its entrance on the south edge; placement rotates it.
/datum/map_template/outpost_upgrade/storage
	name = "Outpost Safe Storage"

/datum/map_template/outpost_upgrade/storage/rundown
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_storage_rundown.dmm"
	outpost_style = OUTPOST_STYLE_RUNDOWN

/datum/map_template/outpost_upgrade/storage/clean
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_storage_clean.dmm"
	outpost_style = OUTPOST_STYLE_CLEAN

/datum/outpost_upgrade/service/storage
	id = "storage"
	name = "Safe Storage"
	desc = "Thirteen rental lockers."
	price = OUTPOST_STORAGE_COST
	template_type = /datum/map_template/outpost_upgrade/storage
	area_type = /area/voidcrew/player_outpost/service_room/storage
	/// Weakrefs to the room's lockers, in number order
	var/list/datum/weakref/lockers

/datum/outpost_upgrade/service/storage/Destroy()
	// Never touch the lockers' contents: deleting the outpost deletes them with the level (M4)
	lockers = null
	return ..()

/datum/outpost_upgrade/service/storage/on_service_installed(mob/user)
	lockers = list()
	var/number = 0
	for(var/turf/tile as anything in room_turfs())
		for(var/obj/structure/closet/secure_closet/outpost_storage/locker in tile)
			number++
			locker.locker_number = number
			locker.room_ref = WEAKREF(src)
			locker.name = "rental locker [number]"
			lockers += WEAKREF(locker)
	if(number != OUTPOST_STORAGE_LOCKERS)
		log_mapping("OUTPOST STORAGE: the storage room at '[outpost?.name]' loaded with [number] lockers, expected [OUTPOST_STORAGE_LOCKERS]")

/// The room's lockers that still exist, in number order
/datum/outpost_upgrade/service/storage/proc/live_lockers()
	var/list/found = list()
	for(var/datum/weakref/locker_ref as anything in lockers)
		var/obj/structure/closet/secure_closet/outpost_storage/locker = locker_ref.resolve()
		if(!QDELETED(locker))
			found += locker
	return found

/// The locker in this room rented by `renter_ckey`, or null
/datum/outpost_upgrade/service/storage/proc/rental_of(renter_ckey)
	if(!istext(renter_ckey) || !length(renter_ckey))
		return null
	for(var/obj/structure/closet/secure_closet/outpost_storage/locker as anything in live_lockers())
		if(locker.renter_ckey == renter_ckey)
			return locker
	return null

// A renter always reaches a paid locker, whatever the room's entrance is keyed to
/datum/outpost_upgrade/service/storage/admits_visitor_extra(mob/user)
	if(!user?.ckey)
		return FALSE
	var/obj/structure/closet/secure_closet/outpost_storage/locker = rental_of(user.ckey)
	return !!locker?.is_renter(user)

// The card is the room's name; never contents, never who rents what
/datum/outpost_upgrade/service/storage/service_ui_data(mob/user)
	return list("kind" = "storage")

/// One manipulator row per locker. Admins see who rents it; a rented row can be released.
/datum/outpost_upgrade/service/storage/admin_ui_data()
	var/list/rows = list()
	for(var/obj/structure/closet/secure_closet/outpost_storage/locker as anything in live_lockers())
		if(locker.renter_ckey)
			rows += list(list(
				"label" = "Locker [locker.locker_number]: rented by [locker.renter_ckey][locker.paid ? " ([locker.paid] cr)" : ""]",
				"action" = "release",
				"ref" = REF(locker),
			))
		else
			rows += list(list(
				"label" = "Locker [locker.locker_number]: vacant",
				"action" = null,
				"ref" = null,
			))
	return rows

/datum/outpost_upgrade/service/storage/admin_ui_act(mob/user, action, list/params)
	if(action != "release")
		return FALSE
	var/locker_ref = params?["ref"]
	if(!istext(locker_ref))
		return TRUE
	var/obj/structure/closet/secure_closet/outpost_storage/locker = locate(locker_ref)
	// Only this room's lockers, whatever ref the client sent
	if(locker in live_lockers())
		locker.admin_release(user)
	return TRUE

// ===== THE LOCKER =====

/obj/structure/closet/secure_closet/outpost_storage
	name = "rental locker"
	desc = "A heavy storage locker bolted to the floor. Its lock is keyed to whoever rents it."
	locked = FALSE
	anchored = TRUE
	anchorable = FALSE
	move_resist = INFINITY
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF | FREEZE_PROOF
	can_weld_shut = FALSE
	can_install_electronics = FALSE
	access_choices = null
	req_access = null
	paint_jobs = null
	divable = FALSE
	// An open locker still blocks anything built on its tile
	dense_when_open = TRUE
	// Nothing cuts it apart
	cutting_tool = null
	/// The renter's ckey; null while vacant. The only thing the lock checks.
	var/renter_ckey
	/// world.time the rental started
	var/rented_at
	/// What the renter paid, for logs and admins. Never refunded.
	var/paid = 0
	/// Painted number, set by the room at install
	var/locker_number
	/// The storage room this locker stands in
	var/datum/weakref/room_ref
	/// Counts what the current close() left outside, for the closer's message
	var/refused_on_close = 0
	/// The first thing the current close() left outside
	var/refused_example

/obj/structure/closet/secure_closet/outpost_storage/Initialize(mapload)
	. = ..()
	// Otherwise EX_ACT explodes the contents before the locker's own INDESTRUCTIBLE check
	flags_1 |= PREVENT_CONTENTS_EXPLOSION_1
	AddElement(/datum/element/outpost_property)
	ADD_TRAIT(src, TRAIT_BLOCKS_RECALL, INNATE_TRAIT)
	RegisterSignal(src, COMSIG_ATOM_INTERNAL_EXPLOSION, PROC_REF(contain_explosion))

/obj/structure/closet/secure_closet/outpost_storage/Destroy()
	room_ref = null
	return ..()

/obj/structure/closet/secure_closet/outpost_storage/PopulateContents()
	return

/// The storage room this locker belongs to, if it is installed
/obj/structure/closet/secure_closet/outpost_storage/proc/get_room()
	var/datum/outpost_upgrade/service/storage/room = room_ref?.resolve()
	if(QDELETED(room) || !room.installed)
		return null
	return room

/obj/structure/closet/secure_closet/outpost_storage/proc/get_home()
	var/datum/outpost_upgrade/service/storage/room = get_room()
	if(!room || QDELETED(room.outpost))
		return null
	return room.outpost

/**
 * Whether `user` is the renter: the same ckey, with a player connected to it. A body the player
 * left behind (disconnected, or an admin's "@" body) keeps the ckey but not the key to the lock.
 */
/obj/structure/closet/secure_closet/outpost_storage/proc/is_renter(mob/user)
	if(!renter_ckey || !istype(user) || user.ckey != renter_ckey)
		return FALSE
	if(IS_FAKE_KEY(user.key) || IS_FAKE_KEY(user.ckey))
		return FALSE
	return !!GET_CLIENT(user)

// Vacant: anyone. Rented: the renter only. Never allowed(), which every closet passes on Voidcrew.
/obj/structure/closet/secure_closet/outpost_storage/can_unlock(mob/living/user, obj/item/card/id/player_id, obj/item/card/id/registered_id)
	return !renter_ckey || is_renter(user)

// A vacant locker has nobody to lock it for
/obj/structure/closet/secure_closet/outpost_storage/togglelock(mob/living/user, silent)
	if(!renter_ckey && !locked)
		if(!silent && user)
			balloon_alert(user, "not rented!")
		return
	return ..()

// Closing a rented locker locks it
/obj/structure/closet/secure_closet/outpost_storage/after_close(mob/living/user)
	. = ..()
	if(renter_ckey)
		lock()

// ===== RENTING =====

/**
 * Why `user` cannot rent this locker now, or null. `shown_fee` is the fee they were shown (what
 * service_price_for() gave them), checked against what they would pay now; null skips that check.
 */
/obj/structure/closet/secure_closet/outpost_storage/proc/rent_denial(mob/living/user, shown_fee)
	if(!isliving(user))
		return "Not available."
	if(renter_ckey)
		return "Already rented."
	if(opened)
		return "Close it first."
	var/datum/outpost_upgrade/service/storage/room = get_room()
	var/obj/structure/overmap/dynamic/player_outpost/home = get_home()
	if(!room || !home || !home.loaded)
		return "Out of service."
	if(!user.ckey || IS_FAKE_KEY(user.ckey) || !GET_CLIENT(user))
		return "Not available."
	var/obj/structure/closet/secure_closet/outpost_storage/current = room.rental_of(user.ckey)
	if(current)
		return "You already rent locker [current.locker_number] here."
	var/fee = home.service_price_for(user, home.get_price(OUTPOST_PRICE_STORAGE_RENT))
	if(!isnull(shown_fee) && shown_fee != fee)
		return "Price changed to [fee] cr."
	if(fee > 0)
		var/datum/bank_account/account = user.get_idcard(TRUE)?.registered_account
		if(!account)
			return "No bank account on your ID."
		if(!account.has_money(fee))
			return "Insufficient credits."
	return null

/// Quotes the rental, asks, then rents. Sleeps on the prompt.
/obj/structure/closet/secure_closet/outpost_storage/proc/try_rent(mob/living/user)
	var/denial = rent_denial(user, null)
	if(denial)
		balloon_alert(user, lowertext(denial))
		return FALSE
	var/obj/structure/overmap/dynamic/player_outpost/home = get_home()
	var/fee = home.service_price_for(user, home.get_price(OUTPOST_PRICE_STORAGE_RENT))
	var/datum/bank_account/account = user.get_idcard(TRUE)?.registered_account
	var/terms = fee > 0 \
		? "Rent for [fee] cr from [account.account_holder]'s account. Locked to you for the shift. No refunds." \
		: "Rent free. Locked to you for the shift."
	if(tgui_alert(user, terms, "Rent [name]", list("Rent", "Cancel")) != "Rent")
		return FALSE
	var/refusal = complete_rental(user, fee)
	if(refusal)
		balloon_alert(user, lowertext(refusal))
		return FALSE
	return TRUE

/**
 * Rents the locker to `user` after the prompt: checks everything again, charges the fee they
 * were shown (the effective fee, 0 for members), then locks. Null when rented, else the
 * refusal. Never sleeps.
 */
/obj/structure/closet/secure_closet/outpost_storage/proc/complete_rental(mob/living/user, shown_fee)
	if(!isnum(shown_fee))
		return "Price changed."
	var/denial = rent_denial(user, shown_fee)
	if(denial)
		return denial
	if(!user.CanReach(src))
		return "Too far away."
	var/obj/structure/overmap/dynamic/player_outpost/home = get_home()
	var/refusal = home.charge_service(user, OUTPOST_PRICE_STORAGE_RENT, home.get_price(OUTPOST_PRICE_STORAGE_RENT), shown_fee, "Locker rental")
	if(refusal)
		return refusal
	renter_ckey = user.ckey
	rented_at = world.time
	paid = shown_fee
	lock()
	if(shown_fee > 0)
		playsound(src, 'sound/effects/cashregister.ogg', 40, TRUE)
	to_chat(user, span_notice("You rent [name] for the shift."))
	log_game("PLAYER OUTPOST: [key_name(user)] rented [name] at '[home.name]' for [shown_fee] cr")
	return null

// ===== GIVING IT UP =====

/// Whether `user` may give up the rental now: theirs, and open, so the contents are already out
/obj/structure/closet/secure_closet/outpost_storage/proc/release_denial(mob/user)
	if(!renter_ckey)
		return "Not rented."
	if(!is_renter(user))
		return "Not your locker."
	if(!opened)
		return "Open it first."
	return null

/// Ends the renter's rental. No refund. Null when done, else the refusal.
/obj/structure/closet/secure_closet/outpost_storage/proc/release(mob/user)
	var/denial = release_denial(user)
	if(denial)
		return denial
	log_game("PLAYER OUTPOST: [key_name(user)] gave up [name] at '[get_home()?.name]'")
	clear_rental()
	to_chat(user, span_notice("You give up [name]."))
	return null

/obj/structure/closet/secure_closet/outpost_storage/proc/confirm_release(mob/user)
	if(tgui_alert(user, "Give up [name]? The rental is not refunded.", "Give up locker", list("Give up", "Keep it")) != "Give up")
		return
	var/denial = release(user)
	if(denial)
		balloon_alert(user, lowertext(denial))

/obj/structure/closet/secure_closet/outpost_storage/click_alt(mob/user)
	if(!is_renter(user))
		return NONE
	var/denial = release_denial(user)
	if(denial)
		balloon_alert(user, lowertext(denial))
		return CLICK_ACTION_BLOCKING
	INVOKE_ASYNC(src, PROC_REF(confirm_release), user)
	return CLICK_ACTION_SUCCESS

/// Admin release from the Outpost Manipulator. The contents stay inside, unlocked.
/obj/structure/closet/secure_closet/outpost_storage/proc/admin_release(mob/user)
	if(!renter_ckey)
		return FALSE
	log_admin("[key_name(user)] released [name] (rented by [renter_ckey]) at '[get_home()?.name]' [AREACOORD(src)]")
	message_admins("[key_name_admin(user)] released [name] (rented by [renter_ckey]) at '[get_home()?.name]'.")
	clear_rental()
	unlock()
	return TRUE

/obj/structure/closet/secure_closet/outpost_storage/proc/clear_rental()
	renter_ckey = null
	rented_at = null
	paid = 0

// ===== CLICKS =====

// Right-click on a closed vacant locker rents it, paid from the worn ID
/obj/structure/closet/secure_closet/outpost_storage/attack_hand_secondary(mob/user, modifiers)
	if(opened || renter_ckey || broken)
		return ..()
	if(!isliving(user) || !user.can_perform_action(src) || !isturf(loc))
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
	INVOKE_ASYNC(src, PROC_REF(try_rent), user)
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/structure/closet/secure_closet/outpost_storage/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	// An ID on a closed locker: rent it if vacant, else work the lock
	if(!opened && tool.GetID())
		if(renter_ckey)
			togglelock(user)
		else
			INVOKE_ASYNC(src, PROC_REF(try_rent), user)
		return ITEM_INTERACT_SUCCESS
	// Anything else on an open locker goes in, as with any closet
	if(opened && !user.combat_mode)
		if(user.transfer_item_to_turf(tool, drop_location()))
			return ITEM_INTERACT_SUCCESS
		return ITEM_INTERACT_BLOCKING
	return NONE

// Tools act before item_interaction(), and the property element refuses every tool, so an open
// locker takes a tool here as it takes any other item
/obj/structure/closet/secure_closet/outpost_storage/tool_act(mob/living/user, obj/item/tool, list/modifiers)
	if(opened && !user.combat_mode && !LAZYACCESS(modifiers, RIGHT_CLICK))
		return item_interaction(user, tool, modifiers)
	return ..()

// No painting, electronics, card readers, pens, welding or cutting
/obj/structure/closet/secure_closet/outpost_storage/tool_interact(obj/item/weapon, mob/living/user)
	return FALSE

// ===== WHAT GOES IN =====

/// What stops `thing` going into the locker (itself or something inside it), or null
/obj/structure/closet/secure_closet/outpost_storage/proc/storage_refusal(atom/movable/thing)
	for(var/atom/movable/inner as anything in thing.get_all_contents())
		if(ismob(inner))
			return inner
		// Cryo keeps these in the round for the same reason: a locked locker would bury them
		if(is_type_in_typecache(inner, GLOB.cryo_undeletable_items))
			return inner
		// Anomaly cores are signalers in name only
		if(is_type_in_typecache(inner, GLOB.outpost_storage_refused) && !istype(inner, /obj/item/assembly/signaler/anomaly))
			return inner
		if(istype(inner, /obj/item/tank))
			var/obj/item/tank/tank = inner
			if(tank.tank_assembly)
				return inner
	return null

/obj/structure/closet/secure_closet/outpost_storage/insertion_allowed(atom/movable/AM)
	var/atom/movable/refused = ismob(AM) ? AM : storage_refusal(AM)
	if(refused)
		refused_on_close++
		if(!refused_example)
			refused_example = refused.name
		return FALSE
	return ..()

/obj/structure/closet/secure_closet/outpost_storage/close(mob/living/user)
	refused_on_close = 0
	refused_example = null
	. = ..()
	if(. && user && refused_on_close)
		to_chat(user, span_warning("[src] will not take [refused_example][refused_on_close > 1 ? " or [refused_on_close - 1] other thing\s" : ""]."))
	refused_on_close = 0
	refused_example = null

// Whatever forces a mob inside (a shove, a teleport) puts it straight back on the tile
/obj/structure/closet/secure_closet/outpost_storage/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	if(ismob(arrived) || length(arrived.get_all_contents_type(/mob)))
		arrived.forceMove(drop_location())

// ===== PROTECTION =====

/// An explosion that starts inside the locker never leaves it
/obj/structure/closet/secure_closet/outpost_storage/proc/contain_explosion(datum/source, list/arguments)
	SIGNAL_HANDLER
	var/atom/origin = arguments?[EXARG_KEY_ORIGIN]
	log_bomber(null, "An explosion from [origin || "something"] was contained by", src)
	visible_message(span_warning("[src] shudders with a muffled thump."))
	return COMSIG_CANCEL_EXPLOSION

// A leaking stored tank vents into the locker, not the room
/obj/structure/closet/secure_closet/outpost_storage/assume_air(datum/gas_mixture/giver)
	return null

/obj/structure/closet/secure_closet/outpost_storage/emag_act(mob/user, obj/item/card/emag/emag_card)
	if(user)
		balloon_alert(user, "no effect!")
	return FALSE

/obj/structure/closet/secure_closet/outpost_storage/on_magic_unlock(datum/source, datum/action/cooldown/spell/aoe/knock/spell, atom/caster)
	SIGNAL_HANDLER
	return

/obj/structure/closet/secure_closet/outpost_storage/bust_open()
	return

/obj/structure/closet/secure_closet/outpost_storage/singularity_act()
	return 0

/obj/structure/closet/secure_closet/outpost_storage/singularity_pull(atom/singularity, current_size)
	return

/obj/structure/closet/secure_closet/outpost_storage/locker_living(datum/source, mob/living/shover, mob/living/target, shove_flags, obj/item/weapon)
	SIGNAL_HANDLER
	return NONE

/obj/structure/closet/secure_closet/outpost_storage/grey_tide(datum/source, list/grey_tide_areas)
	SIGNAL_HANDLER
	return

// ===== EXAMINE =====

/obj/structure/closet/secure_closet/outpost_storage/examine(mob/user)
	. = ..()
	if(renter_ckey)
		. += span_notice(is_renter(user) ? "Rented by you." : "Rented.")
		return
	var/obj/structure/overmap/dynamic/player_outpost/home = get_home()
	if(!home)
		. += span_notice("Out of service.")
		return
	var/fee = home.service_price_for(user, home.get_price(OUTPOST_PRICE_STORAGE_RENT))
	. += span_notice((fee > 0 ? "Vacant. [fee] cr for the shift." : "Vacant. Free for the shift."))

/obj/structure/closet/secure_closet/outpost_storage/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(renter_ckey)
		if(opened && is_renter(user))
			context[SCREENTIP_CONTEXT_ALT_LMB] = "Give up rental"
			. = CONTEXTUAL_SCREENTIP_SET
		return
	var/obj/structure/overmap/dynamic/player_outpost/home = get_home()
	if(opened || !home)
		return
	var/fee = home.service_price_for(user, home.get_price(OUTPOST_PRICE_STORAGE_RENT))
	var/rent_label = fee > 0 ? "Rent ([fee] cr)" : "Rent (free)"
	if(isnull(held_item))
		context[SCREENTIP_CONTEXT_RMB] = rent_label
		. = CONTEXTUAL_SCREENTIP_SET
	else if(held_item.GetID())
		context[SCREENTIP_CONTEXT_LMB] = rent_label
		. = CONTEXTUAL_SCREENTIP_SET
