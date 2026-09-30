/**
 * # World population: wandering traders (owner item 11)
 *
 * Owner: PB (planet and field NPCs).
 *
 * "Wandering traders on planets." (spec 4.7)
 *
 * A peddler walks in from one side of the planet with a pack pony (and, in yellow and red, a hired
 * guard), stops two or three times to spread a rug and trade for a few minutes, then walks out the
 * far side and is gone for the round. Click the peddler for the radial: Trade opens the ordinary
 * TraderShop window on the peddler's own small shop (credits only, no vouchers anywhere); Talk gets
 * a word, and once per crew, where the nearest ruin on this planet lies. The shop buys a few
 * planetary goods, for less than the outposts pay. Anyone in the caravan can be killed. A dead pony
 * closes the shop (the stock was on its back), and so does a dead peddler.
 *
 * In yellow and red, three walks in ten are jumped once on the road: the guard shouts, and five
 * seconds later a pack of pirates comes at the caravan from ten tiles out, kept near it and paid for
 * out of the planet's fauna budget. Crews who fight them get a better price for the rest of the
 * visit.
 *
 * Deviations from the spec, and why:
 * - The peddler is an ambient NPC, not an /mob/living/basic/outpost_trader subtype: planet NPCs
 *   spawn through site.spawn_npc(), which takes only ambient NPCs, and the routine, leash, place and
 *   budget come with it. It owns its shop and opens the TraderShop window through the same facet
 *   datum the traders use (/datum/outpost_trader_ui/shop): the facet only asks its host for
 *   `shop`, `outpost`, `name`, speak_line() and play_denial(), which the peddler has.
 * - The ruin tip is spoken ("old walls to the northeast"), not a helm waypoint: helm waypoints are
 *   overmap coordinates, and the crew is already on the planet.
 */

/// How long a camp lasts
#define AMBIENT_PEDDLER_CAMP_LOW (3 MINUTES)
#define AMBIENT_PEDDLER_CAMP_HIGH (5 MINUTES)
/// Tiles per stretch of the walk (a path the NPC's pathfinding can always take)
#define AMBIENT_CARAVAN_HOP 16
/// How long the caravan waits for the pony and guard to catch up, per stretch
#define AMBIENT_CARAVAN_WAIT (20 SECONDS)
/// A customer at the peddler holds the caravan this long
#define AMBIENT_PEDDLER_HOLD (30 SECONDS)
/// Percent of walks in yellow and red that are jumped once
#define AMBIENT_AMBUSH_CHANCE 30
/// The guard's shout comes this long before the pack
#define AMBIENT_AMBUSH_WARNING (5 SECONDS)
/// The pack comes from this far out
#define AMBIENT_AMBUSH_DISTANCE 10
/// A pack still around after this long slinks off
#define AMBIENT_AMBUSH_TIMEOUT (3 MINUTES)
/// The pack keeps this near the caravan
#define AMBIENT_AMBUSH_LEASH 14
/// Percent off the peddler's prices for a crew who fought the pack
#define AMBIENT_AMBUSH_DISCOUNT 20
/// The peddler pays this share of what an outpost pays for the same goods
#define AMBIENT_PEDDLER_BUYBACK_RATE 0.7

// =========================================================================
// THE SHOP
// =========================================================================

/datum/outfit/ambient_peddler
	name = "Ambient NPC: peddler"
	uniform = /obj/item/clothing/under/costume/buttondown/slacks
	suit = /obj/item/clothing/suit/costume/poncho
	head = /obj/item/clothing/head/cowboy
	shoes = /obj/item/clothing/shoes/laceup
	back = /obj/item/storage/backpack/satchel/leather

/**
 * What a walking trader carries: survival basics a crew forgot, one odd thing, credits only. The
 * ledger buys a few planetary goods at AMBIENT_PEDDLER_BUYBACK_RATE of an outpost's price, never
 * for vouchers. One shop per peddler, fresh each visit.
 */
/datum/outpost_shop/vendor/peddler
	outpost_name = "Peddler's pack"
	outpost_desc = "Whatever a walking trader can carry."
	trader_name = "Peddler"
	trader_outfit = /datum/outfit/ambient_peddler
	categories = list(
		"Supplies",
		"Odds and Ends",
		"Wanted",
	)
	sku_types = list(
		/datum/shop_sku/peddler/water,
		/datum/shop_sku/peddler/flare,
		/datum/shop_sku/peddler/gauze,
		/datum/shop_sku/peddler/ration,
		/datum/shop_sku/peddler/flashlight,
		/datum/shop_sku/peddler/fishing_rod,
	)
	rotating_pool = list(
		/datum/shop_sku/peddler/odd/harmonica,
		/datum/shop_sku/peddler/odd/cards,
		/datum/shop_sku/peddler/odd/cowboy_hat,
		/datum/shop_sku/peddler/odd/binoculars,
		/datum/shop_sku/peddler/odd/lighter,
		/datum/shop_sku/peddler/odd/whiskey,
		/datum/shop_sku/peddler/odd/bandana,
	)
	rotating_picks = 1
	// The outposts' own ledger entries, repriced in New()
	buyback_types = list(
		/datum/shop_buyback/general/spice_pods,
		/datum/shop_buyback/general/pearl_clam,
		/datum/shop_buyback/general/bear_pelt,
		/datum/shop_buyback/outfitter/glacial_core,
		/datum/shop_buyback/outfitter/goliath_plates,
	)
	trader_lines = list(
		TRADER_LINE_GREETING = list(
			"Goods for sale! Nothing stolen, nothing cursed, nothing refunded.",
			"Water, bandages, flares. Everything you forgot on the ship.",
			"Have a look. The pony won't mind.",
		),
		TRADER_LINE_SALE = list(
			"Pleasure doing business.",
			"Good choice. Probably.",
			"Sold. No refunds, no regrets.",
		),
		TRADER_LINE_REFUSAL = list(
			"Not from you, friend.",
		),
		TRADER_LINE_IDLE = list(
			"Goods for sale!",
			"Fresh off the road!",
		),
	)
	/// Crews who fought off an ambush with the caravan (ship REF -> TRUE): a better price this visit
	var/list/helpers = list()

/datum/outpost_shop/vendor/peddler/New(obj/structure/overmap/trader_outpost/outpost)
	. = ..()
	// The outposts' entries: the same goods, the peddler's lower price, credits only, a short list
	for(var/datum/shop_buyback/buyback as anything in buybacks)
		var/obj/item/goods = buyback.item_path
		buyback.pay_credits = round(buyback.pay_credits * AMBIENT_PEDDLER_BUYBACK_RATE, 5)
		buyback.pay_vouchers = 0
		buyback.demand = rand(1, 3)
		buyback.category = "Wanted"
		buyback.desc = goods ? initial(goods.desc) : buyback.desc

/datum/outpost_shop/vendor/peddler/Destroy()
	helpers = null
	return ..()

// Helping fight off the pack is worth a better price
/datum/outpost_shop/vendor/peddler/get_discount_pct(obj/structure/overmap/ship/crew_ship)
	. = ..()
	if(crew_ship && helpers?[REF(crew_ship)])
		. = max(., AMBIENT_AMBUSH_DISCOUNT)

/datum/shop_sku/peddler
	category = "Supplies"
	stock_min = 2
	stock_max = 4

/datum/shop_sku/peddler/water
	item_path = /obj/item/reagent_containers/cup/glass/waterbottle
	price_credits = 30
	stock_min = 3
	stock_max = 6

/datum/shop_sku/peddler/flare
	item_path = /obj/item/flashlight/flare
	price_credits = 50
	stock_min = 3
	stock_max = 6

/datum/shop_sku/peddler/gauze
	item_path = /obj/item/stack/medical/gauze
	price_credits = 150

/datum/shop_sku/peddler/ration
	item_path = /obj/item/food/rationpack
	price_credits = 50
	stock_min = 3
	stock_max = 6

/datum/shop_sku/peddler/flashlight
	item_path = /obj/item/flashlight
	price_credits = 60
	stock_min = 1
	stock_max = 2

/datum/shop_sku/peddler/fishing_rod
	item_path = /obj/item/fishing_rod
	price_credits = 200
	stock_min = 1
	stock_max = 1

/datum/shop_sku/peddler/odd
	category = "Odds and Ends"
	stock_min = 1
	stock_max = 1

/datum/shop_sku/peddler/odd/harmonica
	item_path = /obj/item/instrument/harmonica
	price_credits = 150

/datum/shop_sku/peddler/odd/cards
	item_path = /obj/item/toy/cards/deck
	price_credits = 60

/datum/shop_sku/peddler/odd/cowboy_hat
	item_path = /obj/item/clothing/head/cowboy
	price_credits = 120

/datum/shop_sku/peddler/odd/binoculars
	item_path = /obj/item/binoculars
	price_credits = 250

/datum/shop_sku/peddler/odd/lighter
	item_path = /obj/item/lighter
	price_credits = 80

/datum/shop_sku/peddler/odd/whiskey
	item_path = /obj/item/reagent_containers/cup/glass/bottle/whiskey
	price_credits = 120

/datum/shop_sku/peddler/odd/bandana
	item_path = /obj/item/clothing/mask/bandana/red
	price_credits = 40

// =========================================================================
// THE CARAVAN
// =========================================================================

/// Walking with players anywhere on the level, not only near: the caravan crosses the planet
/datum/ai_controller/basic_controller/ambient_npc/roaming
	can_idle = FALSE

/**
 * The peddler: owns a shop, leads the caravan along its route (the site's data: "route", the
 * waypoints; "camps", the waypoints it camps at; "leg", the last one reached). Killable like
 * anyone; a trader carries more cash than most, and the shop dies with them.
 */
/mob/living/basic/ambient_npc/planet/peddler
	name = "peddler"
	desc = "A walking trader under a wide hat, bags hanging off every strap."
	death_cash_low = 30
	death_cash_high = 80
	outfit = /datum/outfit/ambient_peddler
	dialogue_section = "peddler"
	speech_pace = 0.8
	ai_controller = /datum/ai_controller/basic_controller/ambient_npc/roaming
	routine = list(/datum/ambient_activity/idle = 1)
	/// Their stock and ledger
	var/datum/outpost_shop/vendor/peddler/shop
	/// The TraderShop window's host (the same facet the outpost traders use)
	var/datum/outpost_trader_ui/shop/shop_ui
	/// Always null: the shop window asks its host for an outpost (embargoes), and the road has none
	var/obj/structure/overmap/trader_outpost/outpost
	/// The pony is dead: nothing left to sell
	var/shop_closed = FALSE
	/// world.time the caravan may move on, while someone is buying
	var/hold_until = 0
	COOLDOWN_DECLARE(trade_line_cooldown)

/mob/living/basic/ambient_npc/planet/peddler/Initialize(mapload)
	. = ..()
	shop = new(null)
	shop.trader_name = real_name
	shop_ui = new(src)

/mob/living/basic/ambient_npc/planet/peddler/Destroy()
	save_ledger()
	QDEL_NULL(shop_ui)
	QDEL_NULL(shop)
	return ..()

/**
 * Leaves what the ledger still wants with the site, so a caravan swept away and brought back next
 * visit is not a fresh market for the same goods (load_ledger() puts it back).
 */
/mob/living/basic/ambient_npc/planet/peddler/proc/save_ledger()
	var/datum/ambient_place/site/site = place
	if(!istype(site) || !shop)
		return
	var/list/demand = list()
	for(var/datum/shop_buyback/buyback as anything in shop.buybacks)
		demand[buyback.type] = buyback.demand
	site.data["demand"] = demand

/// Takes up the ledger where the last visit's peddler left it
/mob/living/basic/ambient_npc/planet/peddler/proc/load_ledger()
	var/datum/ambient_place/site/site = place
	var/list/demand = istype(site) ? site.data["demand"] : null
	if(!islist(demand) || !shop)
		return
	for(var/datum/shop_buyback/buyback as anything in shop.buybacks)
		if(!isnull(demand[buyback.type]))
			buyback.demand = demand[buyback.type]

/// A line from the shop's own lines (the shop window calls this, as it does on a trader)
/mob/living/basic/ambient_npc/planet/peddler/proc/speak_line(category)
	var/line = shop?.get_line(category)
	if(!line || !COOLDOWN_FINISHED(src, trade_line_cooldown))
		return
	COOLDOWN_START(src, trade_line_cooldown, 3 SECONDS)
	say_line(line)

/// The "no" noise (the shop window calls this, as it does on a trader)
/mob/living/basic/ambient_npc/planet/peddler/proc/play_denial()
	playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)

// A customer: the Trade and Talk radial, and the caravan waits for them
/mob/living/basic/ambient_npc/planet/peddler/talked_to(mob/living/user)
	if(!talk_ready(user))
		return
	hold_until = world.time + AMBIENT_PEDDLER_HOLD
	INVOKE_ASYNC(src, PROC_REF(open_menu), user)

/mob/living/basic/ambient_npc/planet/peddler/proc/open_menu(mob/living/user)
	face_atom(user)
	var/list/options = list(
		"Trade" = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_buy"),
		"Talk" = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_talk"),
	)
	var/choice = show_radial_menu(user, src, options, custom_check = CALLBACK(src, PROC_REF(menu_ok), user), tooltips = TRUE)
	if(!choice || !menu_ok(user))
		return
	hold_until = world.time + AMBIENT_PEDDLER_HOLD
	switch(choice)
		if("Trade")
			open_shop(user)
		if("Talk")
			chat_with(user)

/// Whether `user` can still do business: near, awake, in sight
/mob/living/basic/ambient_npc/planet/peddler/proc/menu_ok(mob/living/user)
	return istype(user) && !IS_DEAD_OR_INCAP(user) && can_act() && get_dist(src, user) <= 2 && (src in view(2, user))

/// Opens the shop window for `user`, unless the stock went down with the pony
/mob/living/basic/ambient_npc/planet/peddler/proc/open_shop(mob/living/user)
	if(shop_closed || !shop)
		speak_context("pack_lost", user, force = TRUE)
		return
	shop_ui.ui_interact(user)
	speak_line(TRADER_LINE_GREETING)

/// A word; the first time for a crew, where the nearest ruin on this planet lies
/mob/living/basic/ambient_npc/planet/peddler/proc/chat_with(mob/living/user)
	var/turf/ruin = ruin_to_tell()
	if(ruin && first_for_crew(user, "ruin_tip"))
		var/list/lines = get_lines("ruin_tip")
		if(length(lines))
			var/line = replacetext(pick(lines), "{dir}", dir2text(get_dir(src, ruin)) || "north")
			say_line(fill_line(line, user))
			return
	speak_context(AMBIENT_LINE_TALK, user, force = TRUE)

/// A ruin on their planet, looked for once (a few hundred random tiles) and remembered by the site, or null
/mob/living/basic/ambient_npc/planet/peddler/proc/ruin_to_tell()
	var/datum/ambient_place/site/site = place
	if(!istype(site) || length(site.planet?.bounds) < 5)
		return null
	var/turf/known = site.data["ruin_turf"]
	if(known || site.data["ruin_looked"])
		return known
	site.data["ruin_looked"] = TRUE
	var/list/bounds = site.planet.bounds
	for(var/attempt in 1 to 300)
		var/turf/tile = locate(rand(bounds[1], bounds[3]), rand(bounds[2], bounds[4]), bounds[5])
		if(tile && istype(get_area(tile), /area/ruin))
			site.data["ruin_turf"] = tile
			return tile
	return null

/// The pony is dead: the stock went with it
/mob/living/basic/ambient_npc/planet/peddler/proc/lose_pack()
	if(shop_closed)
		return
	shop_closed = TRUE
	SStgui.close_uis(shop_ui)
	speak_context("pack_lost", null, force = TRUE)

// A word, the guard deals with it, and the peddler gets out of the way
/mob/living/basic/ambient_npc/planet/peddler/react_attacked(atom/attacker)
	if(stat != CONSCIOUS || fading || !reaction_ready("attacked"))
		return
	speak_context(AMBIENT_LINE_ATTACKED, attacker, force = TRUE)
	if(isliving(attacker))
		camp_alert(attacker)
		run_from(attacker)

// Killed: the shop goes with them. Its stock is a ledger, never items on the body.
/mob/living/basic/ambient_npc/planet/peddler/death(gibbed)
	var/was_alive = stat != DEAD
	. = ..()
	if(!was_alive)
		return
	shop_closed = TRUE
	SStgui.close_uis(shop_ui)

/**
 * The caravan's next move: camp at a camp stop not yet camped at, walk to the next waypoint (jumped
 * on the way, maybe), or walk off the planet at the end of the route.
 */
/mob/living/basic/ambient_npc/planet/peddler/pick_activity()
	var/datum/ambient_place/site/site = place
	var/list/route = istype(site) ? site.data["route"] : null
	if(!length(route) || world.time < hold_until)
		return ..()
	var/leg = site.data["leg"] || 1
	var/list/camps = site.data["camps"]
	var/list/camped = site.data["camped"]
	if(!islist(camped))
		camped = list()
		site.data["camped"] = camped
	if((leg in camps) && !(leg in camped))
		camped += leg
		return start_activity(new /datum/ambient_activity/caravan_camp(src))
	if(leg >= length(route))
		leave_planet()
		return null
	if(site.data["ambush_leg"] == leg + 1 && !site.data["ambushed"])
		if(length(ambient_players_near(src, 12)))
			site.data["ambushed"] = TRUE
			if(start_activity(new /datum/ambient_activity/caravan_ambush(src)))
				return activity
		else
			// Nobody near to see it: maybe on a later stretch
			site.data["ambush_leg"] = leg + 2
	return start_activity(new /datum/ambient_activity/caravan_walk(src, route[leg + 1], leg + 1))

/// The end of the road: the caravan walks off, and the site is done for the round
/mob/living/basic/ambient_npc/planet/peddler/proc/leave_planet()
	var/datum/ambient_place/site/site = place
	speak_context("farewell", null, force = TRUE)
	if(!istype(site))
		fade_out()
		return
	// Spent before anyone goes, so nobody comes back on the next visit
	site.state = AMBIENT_SITE_SPENT
	for(var/mob/living/basic/ambient_npc/member as anything in site.living_npcs())
		member.fade_out()

/**
 * The pack pony. Killable; a dead pony closes the shop. It follows the peddler, and runs a little
 * way when hit.
 */
/mob/living/basic/ambient_npc/planet/pack_pony
	name = "pack pony"
	desc = "A sturdy pony under a mountain of bags and bundles."
	icon = 'icons/mob/simple/animal.dmi'
	icon_state = "pony"
	icon_living = "pony"
	icon_dead = "pony_dead"
	greyscale_config = /datum/greyscale_config/pony
	random_name = FALSE
	random_gender = FALSE
	mob_biotypes = MOB_ORGANIC | MOB_BEAST
	maxHealth = 60
	health = 60
	// A pony carries bags, not a purse
	death_cash_low = 0
	death_cash_high = 0
	speak_emote = list("neighs")
	ai_controller = /datum/ai_controller/basic_controller/ambient_npc/roaming
	routine = list(/datum/ambient_activity/idle = 1)

/mob/living/basic/ambient_npc/planet/pack_pony/Initialize(mapload)
	. = ..()
	set_greyscale(colors = list("#8a5a3c", "#3b2a1e"))

// A pony, not a person: no human look
/mob/living/basic/ambient_npc/planet/pack_pony/build_look()
	return

// It lies as its own sprite does
/mob/living/basic/ambient_npc/planet/pack_pony/look_dead()
	. = ..()
	transform = matrix()

// Snorts and whickers instead of words
/mob/living/basic/ambient_npc/planet/pack_pony/speak_context(context, atom/other, force = FALSE)
	if(stat != CONSCIOUS || fading)
		return FALSE
	if(!force && world.time < next_line_at)
		return FALSE
	next_line_at = world.time + rand(60 SECONDS, 120 SECONDS)
	manual_emote(pick("snorts.", "whickers.", "stamps a hoof.", "flicks its ears."))
	playsound(src, 'sound/mobs/non-humanoids/pony/snort.ogg', 30, TRUE, -3)
	return TRUE

/mob/living/basic/ambient_npc/planet/pack_pony/pick_activity()
	var/mob/living/basic/ambient_npc/planet/peddler/leader = caravan_leader(src)
	if(leader && start_activity(new /datum/ambient_activity/follow(src, leader, 2)))
		return activity
	return ..()

// The stock was on its back
/mob/living/basic/ambient_npc/planet/pack_pony/death(gibbed)
	var/was_alive = stat != DEAD
	. = ..()
	if(!was_alive)
		return
	var/datum/ambient_place/site/site = place
	if(istype(site))
		site.data["pack_lost"] = TRUE
	var/mob/living/basic/ambient_npc/planet/peddler/leader = caravan_leader(src)
	leader?.lose_pack()

/datum/outfit/ambient_caravan_guard
	name = "Ambient NPC: caravan guard"
	uniform = /obj/item/clothing/under/pants/camo
	suit = /obj/item/clothing/suit/armor/vest
	head = /obj/item/clothing/head/soft/black
	shoes = /obj/item/clothing/shoes/jackboots
	mask = /obj/item/clothing/mask/bandana/red

/// The hired guard, in yellow and red: follows the peddler, fights anyone who goes for the caravan and the pack that jumps it
/mob/living/basic/ambient_npc/planet/caravan_guard
	name = "caravan guard"
	desc = "A hired guard in a flak vest, a bat over one shoulder."
	outfit = /datum/outfit/ambient_caravan_guard
	dialogue_section = "caravan_guard"
	fights_back = TRUE
	joins_camp_fights = TRUE
	weapon_type = /obj/item/melee/baseball_bat
	idle_held = /obj/item/melee/baseball_bat
	watches = TRUE
	death_loot = list(/obj/item/melee/baseball_bat)
	ai_controller = /datum/ai_controller/basic_controller/ambient_npc/roaming
	routine = list(/datum/ambient_activity/idle = 1)

/mob/living/basic/ambient_npc/planet/caravan_guard/pick_activity()
	var/mob/living/basic/ambient_npc/planet/peddler/leader = caravan_leader(src)
	if(leader && start_activity(new /datum/ambient_activity/follow(src, leader, 3)))
		return activity
	return ..()

// The pack that jumped the caravan
/mob/living/basic/ambient_npc/planet/caravan_guard/watch(list/players)
	if(istype(activity, /datum/ambient_activity/fight))
		return
	var/list/pack = ambient_site_visit(place)["pack"]
	for(var/datum/weakref/ref as anything in pack)
		var/mob/living/raider = ref?.resolve()
		if(!QDELETED(raider) && raider.stat != DEAD && get_dist(src, raider) <= 9)
			engage(raider)
			return

/// The peddler leading `member`'s caravan, if they are still about
/proc/caravan_leader(mob/living/basic/ambient_npc/member)
	for(var/mob/living/basic/ambient_npc/planet/peddler/leader in member?.place?.living_npcs())
		return leader
	return null

// =========================================================================
// ON THE ROAD
// =========================================================================

/**
 * One stretch of the route: to waypoint `leg_index` (`goal`), a hop of AMBIENT_CARAVAN_HOP tiles
 * at a time, waiting a little for the pony and the guard. Remembers where it got to, so a caravan
 * swept away mid-walk picks up there on the next visit.
 */
/datum/ambient_activity/caravan_walk
	name = "on the road"
	/// Where this stretch ends
	var/turf/goal
	/// Its index in the route
	var/leg_index
	/// Hops that could not be walked
	var/failures = 0
	/// world.time they started waiting for the others, or 0
	var/waiting_since = 0

/datum/ambient_activity/caravan_walk/New(mob/living/basic/ambient_npc/new_doer, turf/goal, leg_index)
	. = ..()
	src.goal = goal
	src.leg_index = leg_index

/datum/ambient_activity/caravan_walk/Destroy()
	goal = null
	return ..()

/datum/ambient_activity/caravan_walk/setup()
	if(!goal || goal.z != doer.z)
		return FALSE
	var/turf/hop = next_hop()
	if(!hop)
		reached()
		return FALSE
	doer.stand_up()
	go_to(hop)
	next_line = world.time + rand(30 SECONDS, 60 SECONDS)
	return TRUE

/// The next hop toward the goal: the goal itself when near, else a tile AMBIENT_CARAVAN_HOP along the way
/datum/ambient_activity/caravan_walk/proc/next_hop()
	var/turf/here = get_turf(doer)
	if(!here)
		return null
	var/dx = goal.x - here.x
	var/dy = goal.y - here.y
	var/distance = max(abs(dx), abs(dy))
	// A shorter hop when the full one lands in a ruin, a rock face or water
	for(var/hop in list(AMBIENT_CARAVAN_HOP, 10, 5))
		var/turf/aim = goal
		if(distance > hop)
			aim = locate(here.x + round(dx * hop / distance), here.y + round(dy * hop / distance), here.z)
		if(!aim)
			continue
		if(hop_ok(aim))
			return aim
		var/turf/near = doer.random_tile_near(aim, 3, failed_spots)
		if(hop_ok(near))
			return near
	return null

/// Dry ground they could walk to, outside any ruin
/datum/ambient_activity/caravan_walk/proc/hop_ok(turf/tile)
	return tile && doer.standable(tile, failed_spots) && !istype(tile, /turf/open/water) && !ambient_off_limits(tile)

/// The stretch is done (walked, or given up on): the route moves on
/datum/ambient_activity/caravan_walk/proc/reached()
	var/datum/ambient_place/site/site = doer.place
	if(istype(site))
		site.data["leg"] = max(site.data["leg"] || 1, leg_index)
		site.data["last_turf"] = get_turf(doer)

/datum/ambient_activity/caravan_walk/act(seconds)
	var/datum/ambient_place/site/site = doer.place
	if(istype(site))
		site.data["last_turf"] = get_turf(doer)
	if(get_dist(doer, goal) <= 2)
		reached()
		return AMBIENT_STEP_DONE
	var/mob/living/basic/ambient_npc/planet/peddler/peddler = doer
	if(istype(peddler) && world.time < peddler.hold_until)
		return AMBIENT_STEP_CONTINUE
	// The others catch up first, for a while
	if(others_behind())
		if(!waiting_since)
			waiting_since = world.time
		if(world.time - waiting_since < AMBIENT_CARAVAN_WAIT)
			return AMBIENT_STEP_CONTINUE
	waiting_since = 0
	chatter(low = 40 SECONDS, high = 80 SECONDS)
	var/turf/hop = next_hop()
	if(!hop)
		reached()
		return AMBIENT_STEP_DONE
	go_to(hop)
	return AMBIENT_STEP_MOVE

/// Whether the pony or the guard has fallen well behind
/datum/ambient_activity/caravan_walk/proc/others_behind()
	for(var/mob/living/basic/ambient_npc/member in doer.place?.living_npcs())
		if(member != doer && get_dist(member, doer) > 5)
			return TRUE
	return FALSE

// A hop they cannot walk is skipped; too many and the waypoint is given up
/datum/ambient_activity/caravan_walk/spot_unreachable()
	. = ..()
	if(++failures >= 4)
		reached()
		ends_at = world.time

/// A camp by the road: a rug and a lantern set out, the wares on show, for a few minutes
/datum/ambient_activity/caravan_camp
	name = "trading by the road"
	duration_low = AMBIENT_PEDDLER_CAMP_LOW
	duration_high = AMBIENT_PEDDLER_CAMP_HIGH
	/// The rug and lantern set out here
	var/list/gear = list()

/datum/ambient_activity/caravan_camp/setup()
	go_to(null)
	set_duration()
	next_line = world.time + rand(10 SECONDS, 20 SECONDS)
	return TRUE

/datum/ambient_activity/caravan_camp/arrive()
	var/turf/here = get_turf(doer)
	if(here)
		gear += WEAKREF(new /obj/effect/ambient_camp_prop/rug(here))
		var/turf/beside = ambient_free_turf_near(here, 1)
		if(beside)
			gear += WEAKREF(new /obj/effect/ambient_camp_prop/lamp(beside))
	doer.manual_emote("spreads a rug and sets out the wares.")
	doer.crouch()
	doer.speak_context("camp", null, force = TRUE)

/datum/ambient_activity/caravan_camp/act(seconds)
	if(prob(3))
		doer.manual_emote(pick("rearranges the wares.", "polishes a lantern on a sleeve.", "counts a handful of coins."))
	chatter("hawk", 40 SECONDS, 80 SECONDS)
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/caravan_camp/finish()
	var/packed = FALSE
	for(var/datum/weakref/ref as anything in gear)
		var/atom/thing = ref?.resolve()
		if(!QDELETED(thing))
			qdel(thing)
			packed = TRUE
	gear.Cut()
	if(packed && !QDELETED(doer) && doer.stat == CONSCIOUS && !doer.fading)
		doer.manual_emote("rolls up the rug and loads the pony.")
	return ..()

/**
 * The caravan is jumped: the guard (or the peddler) shouts, and AMBIENT_AMBUSH_WARNING later a pack
 * of pirates comes from AMBIENT_AMBUSH_DISTANCE out. It is kept near the caravan, paid for out of
 * the planet's fauna budget, and goes when it is dead or after AMBIENT_AMBUSH_TIMEOUT. The peddler
 * keeps their head down meanwhile. Any crew who lands a blow on the pack gets the helpers' price.
 */
/datum/ambient_activity/caravan_ambush
	name = "ambushed"
	priority = AMBIENT_PRIORITY_REACTION
	/// "warning", then "fight"
	var/stage = "warning"
	/// world.time the pack arrives
	var/pack_at = 0
	/// world.time a pack still about slinks off
	var/give_up_at = 0
	/// The pack (weakrefs)
	var/list/pack = list()

/datum/ambient_activity/caravan_ambush/setup()
	go_to(null)
	pack_at = world.time + AMBIENT_AMBUSH_WARNING
	var/mob/living/basic/ambient_npc/shouter = locate(/mob/living/basic/ambient_npc/planet/caravan_guard) in doer.place?.living_npcs()
	shouter = shouter || doer
	shouter.speak_context("ambush", null, force = TRUE)
	return TRUE

/datum/ambient_activity/caravan_ambush/Destroy()
	for(var/datum/weakref/ref as anything in pack)
		var/mob/living/raider = ref?.resolve()
		if(raider)
			UnregisterSignal(raider, COMSIG_ATOM_WAS_ATTACKED)
	pack = null
	return ..()

/datum/ambient_activity/caravan_ambush/arrive()
	doer.crouch()

/datum/ambient_activity/caravan_ambush/act(seconds)
	if(stage == "warning")
		if(world.time < pack_at)
			return AMBIENT_STEP_CONTINUE
		stage = "fight"
		give_up_at = world.time + AMBIENT_AMBUSH_TIMEOUT
		if(!spawn_pack())
			return AMBIENT_STEP_DONE
		return AMBIENT_STEP_CONTINUE
	var/alive = 0
	for(var/datum/weakref/ref as anything in pack)
		var/mob/living/raider = ref?.resolve()
		if(!QDELETED(raider) && raider.stat != DEAD)
			alive++
	if(!alive)
		doer.speak_context("ambush_over", null, force = TRUE)
		return AMBIENT_STEP_DONE
	if(world.time >= give_up_at)
		return AMBIENT_STEP_DONE
	return AMBIENT_STEP_CONTINUE

// Whatever is left of the pack slinks off when it is over
/datum/ambient_activity/caravan_ambush/finish()
	for(var/datum/weakref/ref as anything in pack)
		var/mob/living/raider = ref?.resolve()
		if(!QDELETED(raider) && raider.stat != DEAD && !raider.client)
			qdel(raider)
	var/list/visit = ambient_site_visit(doer?.place)
	visit -= "pack"
	return ..()

/// How many pirates jump a caravan in `band`: none in green
/proc/ambient_ambush_size(band)
	switch(band)
		if(ZONE_RED)
			return 3
		if(ZONE_YELLOW)
			return 2
	return 0

/**
 * Makes the pack out of what the planet's budget has left, ten tiles off, turns it on the caravan
 * and keeps it near it. Returns how many came.
 */
/datum/ambient_activity/caravan_ambush/proc/spawn_pack()
	var/datum/ambient_place/site/site = doer.place
	if(!istype(site))
		return 0
	var/count = ambient_ambush_size(site.band)
	// Paid for out of the planet's fauna budget, like the people
	var/datum/planet_mob_tracker/tracker = site.planet ? SSplanet_mobs.tracked_planets[site.planet.key] : null
	if(tracker)
		var/planet_cap = tracker.mob_cap || SSplanet_mobs.per_planet_mob_cap
		count = min(count, planet_cap - tracker.spawned_count, SSplanet_mobs.global_mob_cap - SSplanet_mobs.total_managed_mobs)
	if(count <= 0)
		return 0
	var/turf/here = get_turf(doer)
	var/turf/landing
	for(var/attempt in 1 to 6)
		var/turf/far = get_ranged_target_turf(here, pick(GLOB.alldirs), AMBIENT_AMBUSH_DISTANCE)
		if(far && site.leash_ok(far) && ambient_ground_ok(far))
			landing = far
			break
	if(!landing)
		return 0
	var/mob/living/bait = locate(/mob/living/basic/ambient_npc/planet/pack_pony) in site.living_npcs()
	bait = bait || locate(/mob/living/basic/ambient_npc/planet/caravan_guard) in site.living_npcs()
	var/list/visit = ambient_site_visit(site)
	var/list/pack_refs = list()
	var/static/list/raiders = list(
		/mob/living/basic/trooper/pirate/faction/grey/melee = 2,
		/mob/living/basic/trooper/pirate/faction/skeleton/melee = 2,
		/mob/living/basic/trooper/pirate/faction/grey/ranged = 1,
	)
	for(var/i in 1 to count)
		var/turf/where = ambient_free_turf_near(landing, 2) || landing
		var/raider_type = i == 3 ? /mob/living/basic/trooper/pirate/faction/grey/ranged : pick_weight(raiders - /mob/living/basic/trooper/pirate/faction/grey/ranged)
		var/mob/living/raider = new raider_type(where)
		// Not the planet's own: it comes for the caravan, and is kept near it
		var/list/kept = list()
		for(var/faction_token in raider.faction)
			if(!findtext("[faction_token]", "planetary_"))
				kept += faction_token
		raider.faction = kept
		raider.AddComponent(/datum/component/leash, doer, AMBIENT_AMBUSH_LEASH)
		raider.AddElement(/datum/element/relay_attackers)
		RegisterSignal(raider, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(on_pack_attacked))
		if(bait)
			raider.ai_controller?.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, bait)
		var/datum/weakref/ref = WEAKREF(raider)
		pack += ref
		pack_refs += ref
	visit["pack"] = pack_refs
	if(tracker)
		tracker.spawned_count += count
		SSplanet_mobs.total_managed_mobs += count
	return count

/// Someone hit the pack: their crew gets the helpers' price
/datum/ambient_activity/caravan_ambush/proc/on_pack_attacked(datum/source, atom/attacker, attack_flags)
	SIGNAL_HANDLER
	var/mob/living/basic/ambient_npc/planet/peddler/peddler = doer
	if(!istype(peddler) || !peddler.shop || !ismob(attacker))
		return
	var/obj/structure/overmap/ship/ship = get_crew_ship(attacker)
	if(ship)
		peddler.shop.helpers[REF(ship)] = TRUE

// =========================================================================
// THE SITE
// =========================================================================

/**
 * Brings the caravan out: plans its route the first time, then puts whoever is missing (and was
 * not killed) where it last got to.
 */
/datum/ambient_site_kind/planet/peddler/realize(datum/ambient_place/site/site)
	var/missing = site.npcs_missing()
	if(!missing)
		return FALSE
	new_visit(site)
	if(!islist(site.data["route"]))
		plan_route(site)
	var/list/route = site.data["route"]
	var/turf/start = site.data["last_turf"] || route[min(site.data["leg"] || 1, length(route))]
	if(!ambient_ground_ok(start))
		start = ambient_free_turf_near(start, 3) || site.center
	var/list/killed = site.data["killed"] || list()
	var/list/wanted = list(/mob/living/basic/ambient_npc/planet/peddler, /mob/living/basic/ambient_npc/planet/pack_pony)
	if(site.npc_total >= 3)
		wanted += /mob/living/basic/ambient_npc/planet/caravan_guard
	for(var/mob/living/basic/ambient_npc/present as anything in site.living_npcs())
		wanted -= present.type
	var/spawned = 0
	for(var/member_type in wanted)
		if(member_type in killed)
			continue
		if(spawned >= missing)
			break
		var/turf/where = spawned ? (ambient_free_turf_near(start, 2) || start) : start
		var/mob/living/basic/ambient_npc/planet/peddler/member = site.spawn_npc(member_type, where)
		if(!member)
			continue
		spawned++
		if(istype(member))
			member.load_ledger()
			if(site.data["pack_lost"])
				member.shop_closed = TRUE
	return spawned > 0

/datum/ambient_site_kind/planet/peddler/on_npc_died(datum/ambient_place/site/site, mob/living/basic/ambient_npc/npc)
	var/list/killed = site.data["killed"]
	if(!islist(killed))
		killed = list()
		site.data["killed"] = killed
	killed += npc.type

/**
 * The walk for the round, into site.data: "route" (waypoints: in from one side, the site's middle
 * and one or two more camps, out the far side), "camps" (the waypoints camped at), "leg" (1, the
 * way in) and, three walks in ten in yellow and red, "ambush_leg" (the stretch jumped). Away from
 * a planet (an admin's site) it only camps where it is.
 */
/datum/ambient_site_kind/planet/peddler/proc/plan_route(datum/ambient_place/site/site)
	var/list/route = list()
	var/list/camps = list()
	site.data["route"] = route
	site.data["camps"] = camps
	site.data["leg"] = 1
	var/list/rect = spot_rect(site.planet)
	if(!rect)
		route += site.center
		camps += 1
		return
	var/west_to_east = prob(50)
	var/entry_x = west_to_east ? rect[1] : rect[3]
	var/exit_x = west_to_east ? rect[3] : rect[1]
	route += edge_point(entry_x, site.center.y, rect, west_to_east ? EAST : WEST) || site.center
	route += site.center
	camps += length(route)
	var/stops = prob(40) ? 2 : 1
	for(var/i in 1 to stops)
		var/stop_x = round(site.center.x + (exit_x - site.center.x) * i / (stops + 1))
		var/turf/stop = camp_spot_near(locate(stop_x, rand(rect[2], rect[4]), rect[5]), rect)
		if(stop)
			route += stop
			camps += length(route)
	route += edge_point(exit_x, rand(rect[2], rect[4]), rect, west_to_east ? WEST : EAST) || route[length(route)]
	if((site.band == ZONE_YELLOW || site.band == ZONE_RED) && prob(AMBIENT_AMBUSH_CHANCE))
		site.data["ambush_leg"] = rand(2, length(route))

/// Open ground at the edge of `rect` near (x, y), looked for inward (`inward`, EAST or WEST) up to ten tiles, or null
/datum/ambient_site_kind/planet/peddler/proc/edge_point(x, y, list/rect, inward)
	for(var/attempt in 1 to 5)
		var/row = clamp(y + (attempt == 1 ? 0 : rand(-8, 8)), rect[2], rect[4])
		for(var/step in 0 to 10)
			var/turf/tile = locate(x + (inward == EAST ? step : -step), row, rect[5])
			if(tile && ambient_ground_ok(tile) && istype(get_area(tile), /area/overmap_encounter))
				return tile
	return null

/// A spot for a camp near `aim`, inside `rect`, or null
/datum/ambient_site_kind/planet/peddler/proc/camp_spot_near(turf/aim, list/rect)
	if(!aim)
		return null
	for(var/attempt in 1 to 20)
		var/turf/tile = locate(clamp(aim.x + rand(-6, 6), rect[1], rect[3]), clamp(aim.y + rand(-6, 6), rect[2], rect[4]), rect[5])
		if(spot_ok(tile))
			return tile
	return null

#undef AMBIENT_PEDDLER_CAMP_LOW
#undef AMBIENT_PEDDLER_CAMP_HIGH
#undef AMBIENT_CARAVAN_HOP
#undef AMBIENT_CARAVAN_WAIT
#undef AMBIENT_PEDDLER_HOLD
#undef AMBIENT_AMBUSH_CHANCE
#undef AMBIENT_AMBUSH_WARNING
#undef AMBIENT_AMBUSH_DISTANCE
#undef AMBIENT_AMBUSH_TIMEOUT
#undef AMBIENT_AMBUSH_LEASH
#undef AMBIENT_AMBUSH_DISCOUNT
#undef AMBIENT_PEDDLER_BUYBACK_RATE
