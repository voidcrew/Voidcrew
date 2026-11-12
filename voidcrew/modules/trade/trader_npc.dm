/**
 * # Outpost Trader NPC
 *
 * The outpost's shopkeeper: a real person behind the counter, an ambient outpost NPC with a human body that
 * bleeds, goes into crit, dies and can be revived like anyone (owner decision 14, spec-rehydrate.md 1). Clicking
 * them opens a radial, Trade, Talk, and (for the outpost's main trader) Contracts, which consolidates what used to
 * be a holopad, a shop terminal and a mission board into one person.
 *
 * The trade and contract radials open the same TraderShop / OutpostMissionBoard tgui windows as before; the mob
 * hosts them through two small facet datums (one interface per tgui src_object) so both can be open at once.
 *
 * The shop lives on its /datum/outpost_shop, not on the person: stock, prices, demand and reputation outlast a
 * keeper. The shop trades only while its keeper is up and at the counter (shop.is_open(), shop.dm), so a dead,
 * dragged-off or held-up keeper shuts it until they are back or a replacement walks in (outpost recovery,
 * outpost_police/recovery_*.dm). The first keeper of a counter drops one thing off their own shelf when killed
 * (drop_from_shelf()); nothing else they wear or carry is loot.
 *
 * Hitting one is aggression against the outpost's staff (OUTPOST_CRIME_ASSAULT_STAFF, with the trader as the
 * victim); a killing is KILL_STAFF (outpost_police/police_wanted.dm). A fight nearby sends them down behind the
 * counter; a badly hurt one runs for the lift. While alive they refuse teleports and closets, and their AI
 * resists grabs and buckles like any ambient NPC. Checkpoint guards are a subtype (outpost_checkpoint_guard.dm).
 *
 * Speech lines come from the outpost's shop datum, so each trader has their
 * own voice (see the trader_lines lists on the /datum/outpost_shop subtypes).
 */

#define TRADER_NPC_OPTION_TRADE "Trade"
#define TRADER_NPC_OPTION_TALK "Talk"
#define TRADER_NPC_OPTION_CONTRACTS "Contracts"
/// Bounty hunting (bounty_outpost.dm): a ship hunting a fugitive here asks for a clue
#define TRADER_NPC_OPTION_ASK "Ask about the wanted person"

/// How far a customer may stand from a trader and still be served, in tiles.
/// Two, so the counter itself doesn't have to be walked around.
#define TRADER_COUNTER_RANGE 2
/// Below this share of their health, a hurt keeper runs for the lift (guards stay in their booth)
#define TRADER_FLEE_HEALTH 0.5
/// How long a keeper keeps their head down after a fight nearby
#define TRADER_DUCK_LOW (15 SECONDS)
#define TRADER_DUCK_HIGH (30 SECONDS)
/// Trait source for what a living keeper refuses (closets, storage)
#define TRADER_ALIVE_TRAIT "outpost_trader_alive"

/mob/living/carbon/human/npc/ambient_npc/outpost/trader
	name = "trader"
	desc = "An independent merchant behind a well-worn counter."
	// The shop's outfit replaces it once the shop is known (setup_from_shop())
	outfit = /datum/outfit/outpost_trader_generic
	random_name = FALSE
	// Nothing on them is loot but the one shelf item (spec-rehydrate 1.3)
	death_cash_low = 0
	death_cash_high = 0
	// The outpost turrets and police skip faction-mates; aggression is per mind
	faction = list(FACTION_TURRET, FACTION_NEUTRAL)
	routine = list(/datum/ambient_activity/keep_counter = 1)

	/// The outpost this trader works for (set by the outpost on interior link)
	var/obj/structure/overmap/trader_outpost/outpost
	/// The shop this trader fronts: null for the outpost's main shop, or a
	/// /datum/outpost_shop typepath for a vendor stall (the bar, the clinic, ...)
	var/shop_type
	/// The resolved live shop (set by the outpost on interior link, or by shop.set_keeper())
	var/datum/outpost_shop/shop
	/// Facet hosting the TraderShop tgui
	var/datum/outpost_trader_ui/shop_ui
	/// Facet hosting the OutpostMissionBoard tgui (main trader only in practice)
	var/datum/outpost_trader_ui/contracts_ui
	/// Whether the shop-driven name/appearance/voice have been applied
	var/shop_setup_done = FALSE
	/// Made already in the shop's look (the pre-load path: the shop was linked before Initialize)
	var/dressed_for_shop = FALSE
	/// The first keeper of their counter: only they drop anything when killed
	var/first_keeper = FALSE
	/// Minimum delay between idle chatter lines
	COOLDOWN_DECLARE(idle_line_cooldown)
	/// Minimum delay between any spoken lines (don't spam on bulk purchases)
	COOLDOWN_DECLARE(speak_cooldown)

// The roundstart pre-load path links the outpost (and sets shop on) this mob before SSatoms initializes it, so the
// body is made in the shop's look at once. The lazy-load path links an initialized mob and redresses it
// (setup_from_shop()). A replacement walking in is linked by shop.set_keeper().
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/Initialize(mapload, datum/human_npc_order/order)
	if(shop)
		take_shop_look()
	. = ..()
	// NOMOBSWAP stops help-intent walkers from place-swapping through the counter
	ADD_TRAIT(src, TRAIT_NOMOBSWAP, INNATE_TRAIT)
	RegisterSignal(src, COMSIG_MOUSEDROP_ONTO, PROC_REF(block_being_dragged))
	RegisterSignal(src, COMSIG_LIVING_GET_PULLED, PROC_REF(on_pulled))
	RegisterSignal(src, COMSIG_LIVING_REVIVE, PROC_REF(on_revived))
	guard_alive(TRUE)
	leash_to(home)
	shop_ui = new /datum/outpost_trader_ui/shop(src)
	contracts_ui = new /datum/outpost_trader_ui/contracts(src)
	setup_from_shop()
	hook_holdup() // the stick-up (outpost_police/recovery_robbery.dm, R7)

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/Destroy()
	QDEL_NULL(shop_ui)
	QDEL_NULL(contracts_ui)
	if(shop?.trader_npc == src)
		shop.trader_npc = null
	if(shop?.keeper?.resolve() == src)
		shop.set_keeper(null)
	shop = null
	if(outpost)
		UnregisterSignal(outpost, COMSIG_TRADER_OUTPOST_VIOLENCE)
		outpost.traders -= src
		if(outpost.trader == src)
			outpost.trader = null
		outpost = null
	return ..()

/**
 * Takes the counter of `new_shop` at `counter`: links them to the shop and its outpost, makes the counter their
 * home and leash, and puts on the shop's look. Called by shop.set_keeper(); the counter's first keeper is the
 * shop's named trader, anyone after is a new face (spec-rehydrate 1.2).
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/take_counter(datum/outpost_shop/new_shop, turf/counter, is_first)
	shop = new_shop
	first_keeper = is_first
	var/obj/structure/overmap/trader_outpost/new_outpost = new_shop.outpost
	if(new_outpost && new_outpost != outpost)
		if(outpost)
			UnregisterSignal(outpost, COMSIG_TRADER_OUTPOST_VIOLENCE)
		outpost = new_outpost
	if(outpost)
		shop_type = (new_shop == outpost.shop) ? null : new_shop.type
		outpost.traders |= src
		if(isnull(shop_type))
			outpost.trader = src
		RegisterSignal(outpost, COMSIG_TRADER_OUTPOST_VIOLENCE, PROC_REF(on_outpost_violence), override = TRUE)
	if(counter)
		home = counter
		leash_to(counter)
	setup_from_shop()

/// Their leash: within OUTPOST_TRADER_COUNTER_REACH of `counter`, or none
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/leash_to(turf/counter)
	if(!counter)
		leash_bounds = null
		return
	leash_bounds = list(counter.x - OUTPOST_TRADER_COUNTER_REACH, counter.y - OUTPOST_TRADER_COUNTER_REACH, counter.x + OUTPOST_TRADER_COUNTER_REACH, counter.y + OUTPOST_TRADER_COUNTER_REACH, counter.z)

/// The shop's outfit, name and gender for a body not made yet (before Initialize's parent)
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/take_shop_look()
	dressed_for_shop = TRUE
	outfit_choices = null
	outfit = shop.trader_outfit || /datum/outfit/outpost_trader_generic
	random_gender = FALSE
	person = new_outpost_npc_person(shop.trader_gender == FEMALE ? FEMALE : MALE)
	name = shop.trader_name

/**
 * Applies the shop's identity to the mob: name, outfit and bark voice. Runs once, after the shop is linked: from
 * Initialize (pre-load path, shop already linked), from the outpost's interior link (lazy-load path, mob already
 * made) or from take_counter(). A body not yet registered as its shop's keeper is registered first.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/setup_from_shop()
	if(shop_setup_done || !shop || !(flags_1 & INITIALIZED_1))
		return
	if(shop.keeper?.resolve() != src)
		shop.set_keeper(src) // comes back here through take_counter()
		return
	shop_setup_done = TRUE
	if(!dressed_for_shop)
		dress_for_shop()
	if(first_keeper && (shop.trader_gender == PLURAL || shop.trader_gender == NEUTER))
		gender = shop.trader_gender
	if(shop.trader_voice_pack)
		set_bark_voice_pack(shop.trader_voice_pack)
		var/datum/atom_voice/bark_voice = get_bark_voice()
		if(bark_voice)
			bark_voice.pitch = shop.trader_voice_pitch

/// Redresses a body already made in the shop's outfit: the shop's named trader for the first keeper, a new face for anyone after
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/dress_for_shop()
	dressed_for_shop = TRUE
	var/new_gender = first_keeper ? (shop.trader_gender == FEMALE ? FEMALE : MALE) : pick(MALE, FEMALE)
	if(new_gender != person?.gender)
		person = new_outpost_npc_person(new_gender)
		person.apply_to(src)
	npc_delete_locked_gear()
	outfit = shop.trader_outfit || /datum/outfit/outpost_trader_generic
	equipOutfit(outfit)
	npc_lock_all_gear()
	refresh_hands()
	var/new_name = first_keeper ? shop.trader_name : generate_random_name(gender)
	if(new_name)
		fully_replace_character_name(real_name, new_name)

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/examine(mob/user)
	. = ..()
	if(stat == DEAD)
		return
	// A checkpoint guard keeps a desk, not a counter (their desc says so)
	if(shop && !istype(src, /mob/living/carbon/human/npc/ambient_npc/outpost/trader/checkpoint_guard))
		. += span_notice("[name] runs the counter at [shop.outpost_name].")
	if(outpost?.is_user_barred(user))
		. += span_warning("[name] is pointedly ignoring you.")

// ===== THE COUNTER (their routine) =====

// Nothing but the counter: back to it, and standing there
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/pick_activity()
	return start_activity(new /datum/ambient_activity/keep_counter(src))

// Off their counter (shoved, dragged): they walk back however long it takes, and never slip away for it
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/give_up_leash()
	leash_broken_at = 0

// Alive, they stay at the outpost: no teleport of any kind moves them, wherever they are
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/refuse_teleport(datum/source, atom/destination, channel)
	if(stat == DEAD)
		return NONE
	return TRUE

/**
 * Minding the counter: back on the counter tile, standing there, now and then facing about. The trader's idle
 * lines come from their shop (Life()), not the ambient files.
 */
/datum/ambient_activity/keep_counter
	name = "minding the counter"
	duration_low = 1 MINUTES
	duration_high = 3 MINUTES

/datum/ambient_activity/keep_counter/setup()
	set_duration()
	if(doer.home && doer.loc != doer.home)
		go_to(doer.home)
	return TRUE

/datum/ambient_activity/keep_counter/act(seconds)
	if(prob(5) && !doer.buckled)
		doer.setDir(pick(GLOB.cardinals))
	return AMBIENT_STEP_CONTINUE

// They can't get back on the tile (someone stands there): beside it will do
/datum/ambient_activity/keep_counter/spot_unreachable()
	if(spot && spot_distance == 0)
		spot_distance = 1
		arrived = FALSE
		return
	return ..()

/// A fight nearby: down behind the counter until it is over
/datum/ambient_activity/trader_duck
	name = "keeping their head down"
	priority = AMBIENT_PRIORITY_REACTION
	duration_low = TRADER_DUCK_LOW
	duration_high = TRADER_DUCK_HIGH

/datum/ambient_activity/trader_duck/setup()
	set_duration()
	return TRUE

/datum/ambient_activity/trader_duck/arrive()
	doer.crouch()

/datum/ambient_activity/trader_duck/act(seconds)
	if(!doer.crouching)
		doer.crouch()
	return AMBIENT_STEP_CONTINUE

// ===== INTERACTION =====

/// Cancels drag-dropping a living trader onto something (beds, crates, disposals); a body is moved like any other
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/block_being_dragged(atom/over, mob/user)
	SIGNAL_HANDLER
	if(stat == DEAD)
		return NONE
	return COMPONENT_CANCEL_MOUSEDROP_ONTO

/// Alive, closets and bags can't take them (a bluespace body bag once took a whole outpost's traders, #131)
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/guard_alive(alive)
	if(alive)
		ADD_TRAIT(src, TRAIT_NO_CONTAINMENT, TRADER_ALIVE_TRAIT)
		ADD_TRAIT(src, TRAIT_NO_STORAGE_INSERT, TRADER_ALIVE_TRAIT)
	else
		REMOVE_TRAIT(src, TRAIT_NO_CONTAINMENT, TRADER_ALIVE_TRAIT)
		REMOVE_TRAIT(src, TRAIT_NO_STORAGE_INSERT, TRADER_ALIVE_TRAIT)

/// Someone grabs a living keeper: moving staff against their will is assault on the staff (M31)
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/on_pulled(datum/source, mob/living/puller)
	SIGNAL_HANDLER
	if(stat == DEAD || !isliving(puller) || puller == src || !outpost)
		return
	outpost.register_aggression(puller, OUTPOST_CRIME_ASSAULT_STAFF, src)

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/on_revived(datum/source, full_heal_flags)
	SIGNAL_HANDLER
	guard_alive(TRUE)
	if(shop?.keeper?.resolve() == src && home)
		leash_to(home)
	shop?.update_signs()

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/attack_hand(mob/living/carbon/human/user, list/modifiers)
	if(!user.combat_mode && !LAZYACCESS(modifiers, RIGHT_CLICK))
		return ..() // talked_to() opens the radial while they are up
	var/was_alive = stat != DEAD
	. = ..()
	if(was_alive)
		outpost?.register_aggression(user, OUTPOST_CRIME_ASSAULT_STAFF, src)

// An empty hand at the counter is a customer
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/talked_to(mob/living/user)
	if(!buckled)
		face_atom(user)
	// show_radial_menu sleeps; don't hold up the click chain
	INVOKE_ASYNC(src, PROC_REF(open_trader_menu), user)

// Empty-handed clicks from across the counter (see edits/_onclick/ranged_hand.dm).
// Combat mode is already filtered out upstream, so anything arriving here is a
// customer, not an assailant.
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/ranged_attack_hand(mob/living/user, list/modifiers)
	if(get_dist(src, user) > TRADER_COUNTER_RANGE || !can_be_talked_to())
		return FALSE
	if(!customer_in_reach(user))
		balloon_alert(user, "no clear line to the counter!")
		return TRUE
	INVOKE_ASYNC(src, PROC_REF(open_trader_menu), user)
	return TRUE

/**
 * Whether a customer is close enough to do business: within counter range, with
 * nothing solid in the way. Adjacency isn't enough on its own here, the whole
 * point is being able to stand on the customer side of a counter.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/customer_in_reach(mob/user)
	if(QDELETED(user) || get_dist(src, user) > TRADER_COUNTER_RANGE)
		return FALSE
	return (src in view(TRADER_COUNTER_RANGE, user))

/**
 * The Trade / Talk / Contracts radial. Contracts only shows on the outpost's
 * main trader, vendor stalls don't post work. Barred customers get refused
 * before the menu even opens; a shut counter (shop.is_open()) opens nothing.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/open_trader_menu(mob/living/user)
	// outpost may legitimately be null: standalone stalls (the colosseum's
	// lanista) run a shop with no station behind it
	if(!shop || !is_serving())
		return
	if(outpost?.is_user_barred(user))
		speak_line(TRADER_LINE_REFUSAL)
		return
	var/list/options = list(
		TRADER_NPC_OPTION_TRADE = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_buy"),
		TRADER_NPC_OPTION_TALK = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_talk"),
	)
	if(bounty_outpost_ask_posting(src, user))
		options[TRADER_NPC_OPTION_ASK] = image(icon = 'voidcrew/icons/hud/radial.dmi', icon_state = "radial_crime")
	if(isnull(shop_type)) // the main trader also runs the contract ledger
		options[TRADER_NPC_OPTION_CONTRACTS] = image(icon = 'voidcrew/icons/hud/radial.dmi', icon_state = "radial_quest")
	// No require_near: that one is hardcoded to adjacency, so check_menu does the
	// distance test at counter range instead
	var/choice = show_radial_menu(user, src, options, custom_check = CALLBACK(src, PROC_REF(check_menu), user), tooltips = TRUE)
	if(!choice || !check_menu(user))
		return
	switch(choice)
		if(TRADER_NPC_OPTION_TRADE)
			shop_ui.ui_interact(user)
		if(TRADER_NPC_OPTION_TALK)
			speak_line(TRADER_LINE_IDLE, shop.get_back_room_line(user))
		if(TRADER_NPC_OPTION_ASK)
			bounty_outpost_ask(src, user)
		if(TRADER_NPC_OPTION_CONTRACTS)
			outpost.ensure_shop_offers()
			contracts_ui.ui_interact(user)

/// Whether they keep their shop's counter and it is open: the keeper, up, at the counter, not held up. A shop whose counter never had a keeper (a bare test stall) is served by whoever fronts it.
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/is_serving()
	if(!shop)
		return FALSE
	if(!shop.counter_turf)
		return stat == CONSCIOUS
	return shop.keeper?.resolve() == src && shop.is_open()

/// Radial validity: customer still there, still conscious, still at the counter, and the counter open
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/check_menu(mob/living/user)
	if(!istype(user))
		return FALSE
	if(IS_DEAD_OR_INCAP(user) || !customer_in_reach(user))
		return FALSE
	if(shop && !is_serving())
		return FALSE
	return TRUE

/**
 * Says a random personality line from the given TRADER_LINE_* category.
 * Rate-limited except for aggression lines, which always go through. Barks
 * fire automatically through the mob's say() (see modules/voice_barks).
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/speak_line(category, line)
	if(!shop || stat != CONSCIOUS)
		return
	if(category != TRADER_LINE_AGGRESSION && !COOLDOWN_FINISHED(src, speak_cooldown))
		return
	line ||= shop.get_line(category)
	if(!line)
		return
	COOLDOWN_START(src, speak_cooldown, 3 SECONDS)
	say(line)

// Idle chatter on the mob's life tick, roughly once every few minutes, from the counter
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/Life(seconds_per_tick, times_fired)
	. = ..()
	// Walked off, held up, back again: the stall sign follows (shop.update_signs() only acts on a change)
	if(shop?.keeper?.resolve() == src)
		shop.update_signs()
	if(!shop || stat != CONSCIOUS || !COOLDOWN_FINISHED(src, idle_line_cooldown) || !is_serving())
		return
	if(!prob(15))
		return
	// Only chatter when someone's around to hear it
	var/audience = FALSE
	for(var/mob/living/visitor in view(7, src))
		if(visitor.client)
			audience = TRUE
			break
	if(!audience)
		return
	COOLDOWN_START(src, idle_line_cooldown, 2 MINUTES)
	speak_line(TRADER_LINE_IDLE)

/// The polite "no" noise for refused purchases and sales
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/play_denial()
	playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)

// ===== AGGRESSION =====
// Swinging at the staff is aggression like attacking anything else here, and the blow lands as on anyone.

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force && outpost && stat != DEAD)
		outpost.register_aggression(user, OUTPOST_CRIME_ASSAULT_STAFF, src, attacking_item)
	return ..()

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE, blocked = 0)
	if(outpost && stat != DEAD && isliving(hitting_projectile.firer))
		var/obj/item/fired_from = hitting_projectile.fired_from
		outpost.register_aggression(hitting_projectile.firer, OUTPOST_CRIME_ASSAULT_STAFF, src, isitem(fired_from) ? fired_from : null)
	return ..()

// Hurt: a line, then down behind the counter, or off to the lift when it is bad (a guard stays in the booth)
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/react_attacked(atom/attacker)
	if(stat != CONSCIOUS || fading)
		return
	if(reaction_ready("attacked"))
		speak_line(TRADER_LINE_AGGRESSION)
	if(may_flee() && health < maxHealth * TRADER_FLEE_HEALTH)
		flee()
		return
	duck(attacker)

// A fight near the counter
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/react_violence(mob/living/offender)
	if(stat != CONSCIOUS || fading || istype(activity, /datum/ambient_activity/leave) || !reaction_ready("violence"))
		return
	duck(offender)

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/on_outpost_violence(datum/source, mob/living/offender)
	SIGNAL_HANDLER
	if(offender && get_dist(src, offender) <= AMBIENT_VIOLENCE_RANGE)
		react_violence(offender)

/// Down behind the counter for a while, facing the trouble
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/duck(atom/trouble)
	if(istype(activity, /datum/ambient_activity/leave))
		return
	if(!istype(activity, /datum/ambient_activity/trader_duck) && !start_activity(new /datum/ambient_activity/trader_duck(src)))
		return
	if(trouble && !buckled)
		face_atom(trouble)
	crouch()

/// Whether they may leave their post to save themselves. A guard's booth is sealed.
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/may_flee()
	return !!outpost

/// Off to the nearest lift, leash dropped, running
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/flee()
	if(istype(activity, /datum/ambient_activity/leave))
		return
	var/turf/exit = bounty_outpost_exit_turf(src, outpost)
	if(!exit)
		duck()
		return
	leash_bounds = null
	set_pace(running = TRUE)
	start_activity(new /datum/ambient_activity/leave(src, exit))

// ===== DEATH =====

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/death(gibbed)
	var/was_alive = stat != DEAD
	. = ..()
	if(!was_alive || stat != DEAD)
		return
	guard_alive(FALSE)
	shop?.update_signs()

// No ambient place of their own: an outpost's staff lie as long as its other dead (outpost recovery may change it on note_death())
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/corpse_lifetime()
	return outpost ? AMBIENT_OUTPOST_BODY_TIME : ..()

// Cash and death_loot are off; the one drop is a shelf item
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/drop_loot()
	if(loot_dropped)
		return
	loot_dropped = TRUE
	drop_from_shelf()

/**
 * Killed: one item off this trader's own shelf (spec-rehydrate.md 1.3): a credit-priced SKU in stock, at or under
 * OUTPOST_TRADER_DROP_CAP and within recovery.loss_room() (the outpost's cap shared with the stick-up), its stock
 * down by one. Only the first keeper of a counter, and only once per counter; nothing for a replacement, a
 * checkpoint guard, a stall with no outpost, or a counter whose till was robbed. A gun past the checkpoint comes
 * sealed, as a bought one does. Returns the item, or null.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/drop_from_shelf()
	if(!shop || !outpost || !first_keeper || shop.drop_spent)
		return null
	shop.drop_spent = TRUE
	if(shop.till_robbed_by) // robbing and then killing never pays twice (M37)
		return null
	var/datum/outpost_recovery/recovery = outpost.recovery
	if(!recovery)
		return null
	var/room = min(OUTPOST_TRADER_DROP_CAP, recovery.loss_room())
	if(room <= 0)
		return null
	var/list/datum/shop_sku/eligible = list()
	for(var/datum/shop_sku/sku as anything in shop.skus)
		if(sku.stock <= 0 || sku.shelf == SHELF_FAVOR || sku.price_vouchers > 0 || sku.is_chart)
			continue
		if(istype(sku, /datum/shop_sku/barter) || !ispath(sku.item_path, /obj/item))
			continue
		var/price = sku.get_credit_price()
		if(price <= 0 || price > room)
			continue
		eligible += sku
	if(!length(eligible))
		return null
	var/turf/drop_turf = drop_location()
	if(!drop_turf)
		return null
	var/datum/shop_sku/picked = pick(eligible)
	picked.stock--
	recovery.note_loss(picked.get_credit_price())
	var/atom/movable/goods = create_trader_goods(picked.item_path, drop_turf, picked.dispense_amount)
	var/atom/movable/handed = outpost_seal_goods(goods)
	mark_trader_goods(handed)
	return handed

// ===== VENDOR STALL VARIANTS (the outposts' side businesses) =====

// The Undertow's stalls (shop_catalog_black_market_vendors.dm)

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/dregs_barkeep
	shop_type = /datum/outpost_shop/vendor/dregs_bar

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/clinic_doctor
	shop_type = /datum/outpost_shop/vendor/patchup_clinic

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/ripperdoc
	shop_type = /datum/outpost_shop/vendor/ripperdoc

// Halcyon's stalls (shop_catalog_general_vendors.dm, shop_catalog_diner.dm)

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/potting_shed
	shop_type = /datum/outpost_shop/vendor/potting_shed

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/bait_shop
	shop_type = /datum/outpost_shop/vendor/bait_shop

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/diner_cook
	shop_type = /datum/outpost_shop/vendor/diner

// The Quartermain's stalls (shop_catalog_outfitter_vendors.dm,
// shop_catalog_suit_vendor.dm)

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/skunkworks
	shop_type = /datum/outpost_shop/vendor/skunkworks

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/suit_fitter
	shop_type = /datum/outpost_shop/vendor/suit_fitter

// =========================================================================
// THE STALL SIGN
// =========================================================================

/**
 * A stall's sign: OPEN while the counter trades, CLOSED while it does not
 * (spec-rehydrate 1.2). It belongs to the counter it hangs within OUTPOST_TRADER_SIGN_RANGE of, found when that
 * counter gets its first keeper (shop.set_keeper()).
 */
/obj/machinery/status_display/outpost_sign/stall
	name = "stall sign"
	desc = "A stall's sign."
	top_line = "OPEN"
	bottom_line = ""
	/// Weakref to the shop whose counter it shows (set by shop.link_signs())
	var/datum/weakref/shop_ref

/// Shows its counter open or shut
/obj/machinery/status_display/outpost_sign/stall/proc/show_open(open)
	top_line = open ? "OPEN" : "CLOSED"
	bottom_line = ""
	set_messages(top_line, bottom_line)

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/status_display/outpost_sign/stall, 32)

// =========================================================================
// UI FACETS
// =========================================================================

/**
 * # Trader UI facet
 *
 * tgui allows one interface per (user, src_object) pair, so the trader hosts
 * each of its two windows on a small datum facet. The facet delegates
 * physicality to the mob via ui_host. Distance checks run against the trader.
 */
/datum/outpost_trader_ui
	/// The trader this facet fronts for
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/npc

/datum/outpost_trader_ui/New(mob/living/carbon/human/npc/ambient_npc/outpost/trader/npc)
	..()
	src.npc = npc

/datum/outpost_trader_ui/Destroy()
	SStgui.close_uis(src)
	npc = null
	return ..()

/datum/outpost_trader_ui/ui_host()
	return npc

/datum/outpost_trader_ui/ui_state(mob/user)
	return GLOB.trader_counter_state

/// Account choices contain only live hulls belonging to the viewer's current crew.
/datum/outpost_trader_ui/proc/add_crew_context_data(list/data, mob/user)
	var/list/ships = list()
	for(var/obj/structure/overmap/ship/ship in get_crew_ships(user))
		ships += list(list("ref" = REF(ship), "name" = ship.name))
	var/obj/structure/overmap/ship/selected = get_crew_ship(user)
	data["crew_ships"] = ships
	data["crew_ship_ref"] = selected ? REF(selected) : null
	return selected

/datum/outpost_trader_ui/proc/select_service_ship(mob/living/user, ship_ref)
	if(QDELETED(npc) || !npc.check_menu(user) || npc.outpost?.is_user_barred(user))
		return FALSE
	if(npc.outpost && !npc.outpost.contains_site_turf(get_turf(npc)))
		return FALSE
	var/obj/structure/overmap/ship/selected = locate(ship_ref) in get_crew_ships(user)
	return selected && user.mind.select_crew_service_ship(selected)

/**
 * # tgui state: the trader's counter
 *
 * physical_state with a longer arm. Upstream only counts a UI as interactive at
 * one tile, which would grey out every button the moment you stepped back off
 * the counter, so this promotes the whole counter range to interactive and
 * keeps the greyed-out-then-closed bands past it.
 */
GLOBAL_DATUM_INIT(trader_counter_state, /datum/ui_state/trader_counter, new)

/datum/ui_state/trader_counter/can_use_topic(atom/src_object, mob/user)
	. = user.shared_ui_interaction(src_object)
	if(. <= UI_CLOSE)
		return UI_CLOSE
	if(!isliving(user))
		return UI_CLOSE
	// A counter that shuts (its keeper dead, gone or held up) closes its windows
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/keeper = src_object
	if(istype(keeper) && keeper.shop && !keeper.is_serving())
		return UI_CLOSE
	// Obscured by a wall closes it, same as physical_state
	if(!(src_object in view(user)))
		return UI_CLOSE
	var/dist = get_dist(src_object, user)
	if(dist <= TRADER_COUNTER_RANGE)
		return min(., UI_INTERACTIVE)
	if(dist <= 5)
		return min(., UI_DISABLED)
	return UI_CLOSE

/**
 * # The storefront window
 *
 * The buy/sell tgui, sold against the outpost's shared /datum/outpost_shop
 * stock. Payment is stateless. Nothing is inserted or escrowed. At purchase
 * time it checks the buyer's hands for vouchers / barter goods and the selected
 * ship's bank account for credits, then charges and dispenses.
 */
/datum/outpost_trader_ui/shop/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TraderShop", npc.shop ? npc.shop.outpost_name : npc.name)
		ui.open()

/// The full catalog: everything that doesn't change between purchases.
/// Volatile state (stock, wallet, denials) rides ui_data and joins by ref.
/datum/outpost_trader_ui/shop/ui_static_data(mob/user)
	var/list/data = list()
	var/datum/outpost_shop/shop = npc.shop

	data["shop_name"] = shop ? shop.outpost_name : "OFFLINE"
	data["trader_name"] = shop ? shop.trader_name : ""
	data["categories"] = shop ? shop.categories : list()
	data["restock_interval"] = OUTPOST_RESTOCK_INTERVAL

	var/list/catalog = list()
	if(shop)
		for(var/datum/shop_sku/sku as anything in shop.skus)
			catalog += list(list(
				"ref" = REF(sku),
				"name" = sku.name,
				"desc" = sku.desc,
				"category" = sku.category,
				"shelf" = sku.shelf,
				"icon" = sku.get_ui_icon(),
				"price_credits" = sku.price_credits,
				"final_credits" = sku.get_credit_price(),
				"price_vouchers" = sku.price_vouchers,
				// Today's special; the convoy can change it, so final_credits also rides ui_data
				"discount_pct" = sku.discount_pct,
				"price_text" = sku.get_price_text(),
				"barter" = istype(sku, /datum/shop_sku/barter),
				"crew_limit" = sku.crew_limit,
			))
	data["catalog"] = catalog

	// The wanted ledger: what the trader buys (volatile half in ui_data)
	var/list/ledger = list()
	if(shop)
		for(var/datum/shop_buyback/buyback as anything in shop.buybacks)
			ledger += list(list(
				"ref" = REF(buyback),
				"name" = buyback.name,
				"desc" = buyback.desc,
				"category" = buyback.category,
				"icon" = buyback.get_ui_icon(),
				"wanted_text" = buyback.get_wanted_text(),
				"payment_text" = buyback.get_payment_text(),
				"pays_vouchers" = buyback.pay_vouchers > 0,
			))
	data["ledger"] = ledger

	return data

/datum/outpost_trader_ui/shop/ui_data(mob/user)
	var/list/data = list()
	var/datum/outpost_shop/shop = npc.shop

	data["barred"] = npc.outpost ? npc.outpost.is_user_barred(user) : FALSE
	// All vendors at an outpost share its convoy timer. Standalone shops may
	// restock through events instead, so they have no scheduled countdown.
	var/restock_remaining = timeleft(npc.outpost?.restock_timer)
	data["restock_remaining"] = isnull(restock_remaining) ? null : max(0, restock_remaining)

	var/obj/structure/overmap/ship/crew_ship = add_crew_context_data(data, user)
	// Sent as null too, so a stale number never lingers in tgui's merged data
	data["reputation"] = reputation_ui_data(crew_ship?.get_crew_record())

	// The same selected ship account used for purchases. Vouchers remain personal.
	data["held_vouchers"] = isliving(user) ? count_trade_vouchers(user) : 0
	data["account_credits"] = crew_ship?.ship_account?.account_balance
	var/datum/bank_account/sell_account = isliving(user) ? get_shop_buyback_account(user) : null
	data["sell_account_credits"] = sell_account?.account_balance

	var/list/stock_states = list()
	if(shop)
		for(var/datum/shop_sku/sku as anything in shop.skus)
			var/denial = isliving(user) ? sku.get_denial_reason(user) : "Unavailable."
			var/in_supply = sku.shelf == SHELF_FAVOR || sku.stock > 0
			stock_states += list(list(
				"ref" = REF(sku),
				"stock" = sku.stock,
				"can_buy" = !data["barred"] && in_supply && isnull(denial),
				"denial" = denial,
				// Per-viewer price: a peddler's thanks depends on who's asking
				"final_credits" = isliving(user) ? sku.get_credit_price(user) : sku.get_credit_price(),
				// Back room only: units this crew may still buy this round
				"crew_remaining" = (sku.shelf == SHELF_FAVOR && sku.crew_limit > 0 && shop) \
					? max(0, sku.crew_limit - shop.get_crew_purchases(crew_ship, sku.type)) \
					: null,
				// TRUE when the reputation gate or crew cap is what's refusing them
				"favor_locked" = isliving(user) && !isnull(sku.get_favor_denial(user)),
			))
	data["stock_states"] = stock_states

	// Sell side volatile state: demand, what the seller is carrying, denials
	var/list/ledger_states = list()
	if(shop)
		for(var/datum/shop_buyback/buyback as anything in shop.buybacks)
			var/denial = isliving(user) ? buyback.get_denial_reason(user) : "Unavailable."
			ledger_states += list(list(
				"ref" = REF(buyback),
				"demand" = buyback.demand,
				"carrying" = isliving(user) ? buyback.count_carried_units(user) : 0,
				"can_sell" = !data["barred"] && buyback.demand > 0 && isnull(denial),
				"denial" = denial,
			))
	data["ledger_states"] = ledger_states

	return data

/datum/outpost_trader_ui/shop/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/living/user = ui.user
	if(action == "select_ship")
		return select_service_ship(user, params["ref"])
	var/datum/outpost_shop/shop = npc.shop
	if(!istype(user) || !shop || !npc.check_menu(user))
		return
	if(npc.outpost && !npc.outpost.contains_site_turf(get_turf(npc)))
		return

	switch(action)
		if("buy")
			if(npc.outpost?.is_user_barred(user))
				npc.speak_line(TRADER_LINE_REFUSAL)
				to_chat(user, span_warning("Service refused."))
				npc.play_denial()
				return TRUE
			var/datum/shop_sku/sku = locate(params["ref"]) in shop.skus
			if(!sku)
				return TRUE
			if(sku.stock <= 0 && sku.shelf != SHELF_FAVOR)
				to_chat(user, span_warning("Out of stock."))
				npc.play_denial()
				return TRUE
			if(!sku.can_trade(user, npc))
				return TRUE
			var/denial = sku.get_denial_reason(user)
			if(denial)
				to_chat(user, span_warning(denial))
				npc.play_denial()
				return TRUE
			if(sku.try_purchase(user, npc))
				playsound(npc, 'sound/effects/cashregister.ogg', 40, TRUE)
				npc.speak_line(TRADER_LINE_SALE)
			return TRUE
		if("sell")
			if(npc.outpost?.is_user_barred(user))
				npc.speak_line(TRADER_LINE_REFUSAL)
				to_chat(user, span_warning("Service refused."))
				npc.play_denial()
				return TRUE
			var/datum/shop_buyback/buyback = locate(params["ref"]) in shop.buybacks
			if(!buyback)
				return TRUE
			if(buyback.demand <= 0)
				to_chat(user, span_warning("Not buying any more this shift."))
				npc.play_denial()
				return TRUE
			var/denial = buyback.get_denial_reason(user)
			if(denial)
				to_chat(user, span_warning(denial))
				npc.play_denial()
				return TRUE
			if(buyback.try_sell(user, npc))
				playsound(npc, 'sound/effects/cashregister.ogg', 40, TRUE)
				npc.speak_line(TRADER_LINE_SALE)
			return TRUE
		if("sell_all")
			if(npc.outpost?.is_user_barred(user))
				npc.speak_line(TRADER_LINE_REFUSAL)
				to_chat(user, span_warning("Service refused."))
				npc.play_denial()
				return TRUE
			var/datum/shop_buyback/buyback = locate(params["ref"]) in shop.buybacks
			if(!buyback)
				return TRUE
			var/denial = buyback.get_denial_reason(user)
			if(denial)
				to_chat(user, span_warning(denial))
				npc.play_denial()
				return TRUE
			if(buyback.try_sell_bulk(user, npc) > 0)
				playsound(npc, 'sound/effects/cashregister.ogg', 40, TRUE)
				npc.speak_line(TRADER_LINE_SALE)
			else
				npc.play_denial()
			return TRUE

/**
 * # The contract ledger window
 *
 * The posting side of the outpost mission loop (see outpost_missions.dm for
 * the offers themselves). Accepting puts the contract in the ship's active
 * list; item contracts can also be turned in right here, at the trader.
 */
/datum/outpost_trader_ui/contracts/ui_interact(mob/user, datum/tgui/ui)
	npc.outpost?.ensure_shop_offers()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OutpostMissionBoard", "[npc.name]'s contracts")
		ui.open()

/datum/outpost_trader_ui/contracts/ui_data(mob/user)
	var/list/data = list()
	var/obj/structure/overmap/trader_outpost/outpost = npc.outpost

	var/datum/outpost_shop/shop = outpost?.shop
	data["shop_name"] = shop ? shop.outpost_name : "OFFLINE"
	data["trader_name"] = shop ? shop.trader_name : ""
	data["barred"] = outpost ? outpost.is_user_barred(user) : FALSE

	var/obj/structure/overmap/ship/ship = add_crew_context_data(data, user)
	data["ship_name"] = ship ? ship.name : null
	data["ship_mission_slots_free"] = ship ? (ship.max_missions - length(ship.active_missions)) : 0
	data["reputation"] = reputation_ui_data(ship?.get_crew_record())

	var/list/offers = list()
	if(outpost)
		for(var/datum/mission/offer as anything in outpost.get_contract_offers_for(ship))
			if(QDELETED(offer))
				continue
			var/list/offer_data = offer.get_ui_data(ship.get_crew_record())
			offer_data["quote_value"] = offer.contract_quote
			offer_data["wanted_text"] = offer.get_progress_string()
			offers += list(offer_data)
	data["offers"] = offers

	// The ship's active contracts, with per-contract turn-in readiness at
	// THIS trader: any item mission can be turned in here (couriers only at
	// their destination), so crews can settle up without flying home
	var/list/ship_missions = list()
	if(ship)
		for(var/datum/mission/mission as anything in ship.active_missions)
			if(QDELETED(mission))
				continue
			var/list/mission_data = mission.get_ui_data()
			mission_data["quote_value"] = mission.contract_quote
			mission_data["from_this_shop"] = (mission.shop == outpost?.shop)
			var/location_ok = mission.can_turn_in_at(npc)
			mission_data["location_ok"] = location_ok
			// A near-miss (right goods, wrong count) comes back too, so the
			// tooltip can say why rather than "hold the goods" at someone who is
			var/obj/item/offered = mission.pick_offered_item(user)
			var/holding_valid = offered && mission.can_turn_in(offered)
			mission_data["holding_valid_item"] = !!holding_valid
			var/turn_in_hint
			if(!mission.requires_item)
				turn_in_hint = "Not an item contract."
			else if(!location_ok)
				turn_in_hint = mission.get_wrong_location_reason(npc)
			else if(!holding_valid)
				turn_in_hint = offered ? mission.get_failure_reason(offered) : "Shipment declined."
			mission_data["turn_in_hint"] = turn_in_hint
			ship_missions += list(mission_data)
	data["ship_missions"] = ship_missions

	return data

/datum/outpost_trader_ui/contracts/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/living/user = ui.user
	if(action == "select_ship")
		return select_service_ship(user, params["ref"])
	var/obj/structure/overmap/trader_outpost/outpost = npc.outpost
	if(!istype(user) || !outpost?.shop || !npc.can_use_contracts(user))
		return

	switch(action)
		if("accept")
			if(outpost.is_user_barred(user))
				npc.speak_line(TRADER_LINE_REFUSAL)
				to_chat(user, span_warning("Service refused."))
				return TRUE
			var/obj/structure/overmap/ship/ship = get_crew_ship(user)
			if(!ship)
				npc.balloon_alert(user, "you have no ship!")
				return TRUE
			var/datum/mission/offer = locate(params["ref"]) in outpost.shop_offers
			if(!offer || QDELETED(offer) || offer.active || offer.failed || offer.completed || world.time - offer.posted_at >= OUTPOST_CONTRACT_EXPIRY)
				npc.balloon_alert(user, "offer closed!")
				return TRUE

			// Ride the standard accept path so limits/bookkeeping all apply
			ship.available_missions += offer
			var/result = ship.accept_mission(offer)
			if(result != TRUE)
				ship.available_missions -= offer
				npc.balloon_alert(user, "[result]")
				npc.play_denial()
				return TRUE

			outpost.shop_offers -= offer
			npc.balloon_alert(user, "contract accepted!")
			playsound(npc, 'sound/machines/ding.ogg', 50, TRUE)
			npc.speak_line(TRADER_LINE_GREETING)
			return TRUE

		if("turn_in")
			if(outpost.is_user_barred(user))
				npc.speak_line(TRADER_LINE_REFUSAL)
				to_chat(user, span_warning("Service refused."))
				return TRUE
			var/obj/structure/overmap/ship/ship = get_crew_ship(user)
			if(!ship)
				npc.balloon_alert(user, "you have no ship!")
				return TRUE
			var/datum/mission/mission = locate(params["ref"]) in ship.active_missions
			if(!mission || QDELETED(mission))
				npc.balloon_alert(user, "contract not found!")
				return TRUE
			// Passes the near-miss through on failure so the balloon names the
			// shortfall instead of "No item provided."
			var/obj/item/offered = mission.pick_offered_item(user)
			var/result = ship.complete_mission(mission, npc, offered)
			if(result != TRUE)
				npc.balloon_alert(user, "[result]")
				npc.play_denial()
				return TRUE
			// Counted hand-overs accept the item but keep the contract open
			npc.balloon_alert(user, QDELETED(mission) ? "contract fulfilled!" : "goods received!")
			playsound(npc, 'sound/effects/cashregister.ogg', 50, TRUE)
			npc.speak_line(TRADER_LINE_SALE)
			return TRUE

/// Stale UI actions must still originate from a crew member at the actual counter.
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/can_use_contracts(mob/living/user)
	if(!check_menu(user) || QDELETED(outpost) || outpost.trader != src || shop != outpost.shop)
		return FALSE
	if(!outpost.contains_site_turf(get_turf(src)))
		return FALSE
	if(!get_crew_ship(user))
		to_chat(user, span_warning("Crew access only."))
		return FALSE
	return TRUE

#undef TRADER_COUNTER_RANGE
#undef TRADER_FLEE_HEALTH
#undef TRADER_DUCK_LOW
#undef TRADER_DUCK_HIGH
#undef TRADER_ALIVE_TRAIT
#undef TRADER_NPC_OPTION_TRADE
#undef TRADER_NPC_OPTION_TALK
#undef TRADER_NPC_OPTION_CONTRACTS
#undef TRADER_NPC_OPTION_ASK
