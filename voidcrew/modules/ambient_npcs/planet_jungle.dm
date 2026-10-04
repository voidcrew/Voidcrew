/**
 * # World population: the cannibal camp and the tribal band (owner items 7 and 8)
 *
 * Owner: PB (planet and field NPCs).
 *
 * "A cannibal npc on a jungle planet cooking up a human over a fire." (spec 4.3)
 * "A group of tribal npcs with spears on jungle." (spec 4.4)
 *
 * Both are NPC threats, and both warn before they hurt anyone:
 * - The cannibal tends a body on a burning stake and a grill of meat. The fire's light and the
 *   smell are the first warning. A stranger in sight gets an invitation; one who lingers gets a
 *   second, and the cleaver comes out; anyone who comes within two tiles, or stays in sight half
 *   a minute, is attacked. Killed: the cleaver and a cooked cut. Only the cannibal comes back
 *   each visit; while he lives, so does the body on the stake.
 * - The hunters keep a camp inside a ring of heads on bamboo poles about seven tiles out: a fire,
 *   sleeping mats, a spear rack, a practice post. They sit at the fire, practise, chant, sleep in
 *   turns and go out hunting in pairs. Crossing the ring gets a warning shout (once a minute each).
 *   Staying inside it ten seconds with a weapon in hand, or coming near the fire armed, and the
 *   whole camp attacks: spear blows, and a spear thrown from range that they walk over to pull out
 *   of the ground again, one throw at a time for the camp. They never chase more than five tiles
 *   past the ring. Come empty-handed and one of them walks up to trade a bone spear for a hide or
 *   meat (once per crew). A camp that is all asleep sees nobody coming. Killed: a spear each, and
 *   sometimes bone armour.
 * - Both site kinds' realize() (the kinds themselves are in planet_sites.dm).
 *
 * Camp fires are dense, so nobody (NPCs included) walks into one. Real objects in a camp (the fires,
 * the pikes, the meat) are made once; scenery is put back when missing.
 */

/// The hunters' ring of poles: how far out, and how far past it they chase
#define AMBIENT_TRIBAL_RING_RADIUS 7
#define AMBIENT_TRIBAL_CHASE_PAST_RING 5
/// A stranger inside the ring this long with a weapon in hand is attacked
#define AMBIENT_TRIBAL_ARMED_GRACE (10 SECONDS)
/// Armed and this near the fire: attacked at once
#define AMBIENT_TRIBAL_FIRE_RANGE 3
/// The cannibal's patience: attacked this near, or after this long in sight
#define AMBIENT_CANNIBAL_STRIKE_RANGE 2
#define AMBIENT_CANNIBAL_PATIENCE (30 SECONDS)
#define AMBIENT_CANNIBAL_WARNING (15 SECONDS)
/// How far the cannibal sees
#define AMBIENT_CANNIBAL_SIGHT 7

// =========================================================================
// CAMP FIRES
// =========================================================================

/// A camp fire that is lit as it is made. Dense: nobody walks into it.
/obj/structure/bonfire/dense/ambient_camp

/obj/structure/bonfire/dense/ambient_camp/Initialize(mapload)
	. = ..()
	return INITIALIZE_HINT_LATELOAD

// Late, so the ground's air exists (the prelit bonfire's reason too)
/obj/structure/bonfire/dense/ambient_camp/LateInitialize()
	start_burning()

/// The cannibal's fire, with a stake for his dinner (tg's own stake, as rods make it)
/obj/structure/bonfire/dense/ambient_camp/stake

/obj/structure/bonfire/dense/ambient_camp/stake/Initialize(mapload)
	. = ..()
	can_buckle = TRUE
	buckle_requires_restraints = TRUE
	var/mutable_appearance/rod_underlay = mutable_appearance('icons/obj/service/hydroponics/equipment.dmi', "bonfire_rod")
	rod_underlay.pixel_z = 16
	underlays += rod_underlay

// The first warning, before anyone sees the cook
/obj/structure/bonfire/dense/ambient_camp/stake/examine(mob/user)
	. = ..()
	if(has_buckled_mobs())
		. += span_warning("Someone is tied to the stake. It smells like roast pork.")

/// The cannibal's grill: whatever lies on it cooks
/obj/structure/bonfire/dense/ambient_camp/grill

/obj/structure/bonfire/dense/ambient_camp/grill/Initialize(mapload)
	. = ..()
	grill = TRUE
	add_overlay("bonfire_grill")

// =========================================================================
// THE CANNIBAL
// =========================================================================

/datum/outfit/ambient_cannibal
	name = "Ambient NPC: cannibal"
	uniform = /obj/item/clothing/under/color/grey/ancient
	suit = /obj/item/clothing/suit/apron/chef
	shoes = /obj/item/clothing/shoes/sandal

/// Dinner: a dead stranger in rags, already carved
/datum/outfit/ambient_victim
	name = "Ambient NPC: the cannibal's dinner"
	uniform = /obj/item/clothing/under/color/grey/ancient

/obj/effect/mob_spawn/corpse/human/ambient_victim
	name = "cannibal's dinner"
	outfit = /datum/outfit/ambient_victim
	brute_damage = 60

/mob/living/basic/ambient_npc/planet/cannibal
	name = "cannibal"
	desc = "A gaunt man in a stained apron. He smells of smoke and cooked meat."
	random_name = FALSE
	random_gender = FALSE
	gender = MALE
	outfit = /datum/outfit/ambient_cannibal
	dialogue_section = "cannibal"
	fights_back = TRUE
	weapon_type = /obj/item/knife/butcher
	watches = TRUE
	death_loot = list(/obj/item/knife/butcher, /obj/item/food/meat/steak/plain/human)
	routine = list(
		/datum/ambient_activity/camp_chore/turn_spit = 3,
		/datum/ambient_activity/camp_chore/carve = 2,
		/datum/ambient_activity/camp_chore/eat_meat = 1,
		/datum/ambient_activity/camp_chore/sharpen = 2,
		/datum/ambient_activity/camp_chore/hum = 1,
	)
	/// REF of a stranger -> world.time they came into sight
	var/list/seen = list()
	/// REF of a stranger -> world.time they may be invited again
	var/list/invited = list()
	/// REF of a stranger -> TRUE once they were warned this time in sight
	var/list/warned = list()

/mob/living/basic/ambient_npc/planet/cannibal/Destroy()
	seen = null
	invited = null
	warned = null
	return ..()

/**
 * Strangers in sight: an invitation; a second, colder one and the cleaver after a while; then an
 * attack on anyone within two tiles or in sight for half a minute. Out of sight resets the clock.
 */
/mob/living/basic/ambient_npc/planet/cannibal/watch(list/players)
	if(istype(activity, /datum/ambient_activity/fight))
		return
	players = players || ambient_players_near(src, AMBIENT_CANNIBAL_SIGHT)
	var/list/still_seen = list()
	for(var/mob/living/player as anything in players)
		if(QDELETED(player) || player.stat == DEAD || !bounty_ai_can_see(src, player, AMBIENT_CANNIBAL_SIGHT))
			continue
		var/key = REF(player)
		still_seen[key] = TRUE
		if(!seen[key])
			seen[key] = world.time
		if(invited[key] < world.time)
			invited[key] = world.time + 1 MINUTES
			face_atom(player)
			speak_context("invite", player, force = TRUE)
			continue
		var/in_sight_for = world.time - seen[key]
		if(get_dist(src, player) <= AMBIENT_CANNIBAL_STRIKE_RANGE || in_sight_for >= AMBIENT_CANNIBAL_PATIENCE)
			speak_context("attack", player, force = TRUE)
			engage(player)
			return
		if(in_sight_for >= AMBIENT_CANNIBAL_WARNING && !warned[key])
			warned[key] = TRUE
			stand_up()
			set_held(weapon_type)
			face_atom(player)
			manual_emote("gets up, cleaver in hand.")
			speak_context("warn", player, force = TRUE)
	for(var/key in seen.Copy())
		if(!still_seen[key])
			seen -= key
			warned -= key

// ----- chores -----

/datum/ambient_activity/camp_chore/turn_spit
	name = "tending the fire"
	prop_type = /obj/structure/bonfire/dense/ambient_camp/stake
	emotes = list("turns the body on the stake.", "prods the fire with a stick.", "sniffs the smoke.")
	sounds = list('sound/effects/comfyfire.ogg')
	line_context = "cooking"

/datum/ambient_activity/camp_chore/carve
	name = "carving"
	prop_type = /obj/structure/bonfire/dense/ambient_camp/grill
	held_look = /obj/item/knife/butcher
	swings = TRUE
	emotes = list("carves a strip off the roast.", "slaps a cut onto the grill.", "trims the fat off a cut.")
	sounds = list('sound/items/weapons/bladeslice.ogg')
	line_context = "cooking"

/datum/ambient_activity/camp_chore/eat_meat
	name = "eating"
	prop_type = /obj/structure/bonfire/dense/ambient_camp/grill
	crouches = TRUE
	duration_low = 30 SECONDS
	duration_high = 60 SECONDS
	held_look = /obj/item/food/meat/steak/plain/human
	emotes = list("tears into a strip of meat.", "licks his fingers.", "chews slowly, eyes half shut.")
	sounds = list('sound/items/eatfood.ogg')

/datum/ambient_activity/camp_chore/sharpen
	name = "sharpening"
	prop_type = /obj/structure/bonfire/dense/ambient_camp/stake
	stand_distance = 2
	crouches = TRUE
	held_look = /obj/item/knife/butcher
	emotes = list("sharpens a cleaver on a flat stone.", "tests the edge with a thumb.")
	sounds = list('sound/items/unsheath.ogg')

/datum/ambient_activity/camp_chore/hum
	name = "humming"
	emotes = list("hums tunelessly.", "stares into the fire, humming.")

// ----- the camp -----

/datum/ambient_site_kind/planet/cannibal/realize(datum/ambient_place/site/site)
	var/missing = site.npcs_missing()
	if(!missing)
		return FALSE
	new_visit(site)
	if(!site.data["camp_built"])
		site.data["camp_built"] = TRUE
		build_camp(site)
	for(var/i in 1 to missing)
		var/mob/living/basic/ambient_npc/planet/cannibal/cannibal = site.spawn_npc(npc_type, ambient_free_turf_near(site.center, 2) || site.center)
		if(cannibal)
			cannibal.leash_bounds = ambient_square_bounds(site.center, 10)
	// Dressing a body can sleep
	INVOKE_ASYNC(src, PROC_REF(stake_victim), site)
	return TRUE

/// The stake fire, the grill with two cuts on it, and the leftovers. Once per site.
/datum/ambient_site_kind/planet/cannibal/proc/build_camp(datum/ambient_place/site/site)
	make_prop(site, /obj/structure/bonfire/dense/ambient_camp/stake, site.center)
	var/turf/grill_turf = ambient_free_turf_near(site.center, 2)
	if(make_prop(site, /obj/structure/bonfire/dense/ambient_camp/grill, grill_turf))
		for(var/i in 1 to 2)
			var/obj/item/food/meat/slab/human/cut = new(grill_turf)
			cut.pixel_x = rand(-6, 6)
			cut.pixel_y = rand(-4, 6)
	new /obj/effect/decal/remains/human(ambient_free_turf_near(site.center, 2) || site.center)
	new /obj/effect/decal/cleanable/blood/old(ambient_free_turf_near(site.center, 1) || site.center)

/**
 * A dead stranger tied to the stake, if the stake is empty and the last one was swept away with the
 * planet's bodies. Can sleep: call it async.
 */
/datum/ambient_site_kind/planet/cannibal/proc/stake_victim(datum/ambient_place/site/site)
	var/obj/structure/bonfire/dense/ambient_camp/stake/stake = site?.get_prop(/obj/structure/bonfire/dense/ambient_camp/stake)
	if(!stake || stake.has_buckled_mobs() || site.get_prop(/mob/living/carbon/human))
		return null
	var/obj/effect/mob_spawn/corpse/human/ambient_victim/spawner = new(get_turf(stake), TRUE)
	var/mob/living/carbon/human/body = spawner.create()
	if(QDELETED(body))
		return null
	if(QDELETED(site) || QDELETED(stake))
		qdel(body)
		return null
	site.add_prop(body)
	// tg's stake wants restraints; a corpse is tied on regardless
	stake.buckle_requires_restraints = FALSE
	stake.buckle_mob(body, force = TRUE)
	stake.buckle_requires_restraints = TRUE
	return body

// =========================================================================
// THE HUNTERS
// =========================================================================

/datum/outfit/ambient_tribal
	name = "Ambient NPC: hunter"
	uniform = /obj/item/clothing/under/costume/loincloth
	shoes = /obj/item/clothing/shoes/sandal

/datum/outfit/ambient_tribal/bone
	name = "Ambient NPC: hunter in bone"
	suit = /obj/item/clothing/suit/armor/bone
	head = /obj/item/clothing/head/helmet/skull

/datum/outfit/ambient_tribal/cloak
	name = "Ambient NPC: hunter in a hide cloak"
	suit = /obj/item/clothing/suit/hooded/cloak/goliath

/mob/living/basic/ambient_npc/planet/tribal
	name = "hunter"
	desc = "A lean hunter in hide and bone, a bamboo spear in hand."
	random_name = FALSE
	outfit_choices = list(/datum/outfit/ambient_tribal, /datum/outfit/ambient_tribal/bone, /datum/outfit/ambient_tribal/cloak)
	dialogue_section = "tribal"
	speech_pace = 1.5
	fights_back = TRUE
	joins_camp_fights = TRUE
	weapon_type = /obj/item/spear/bamboospear
	idle_held = /obj/item/spear/bamboospear
	blow_interval = 1.5 SECONDS
	watches = TRUE
	death_loot = list(/obj/item/spear/bamboospear)
	routine = list(
		/datum/ambient_activity/camp_chore/fireside = 3,
		/datum/ambient_activity/camp_chore/spear_practice = 2,
		/datum/ambient_activity/camp_chore/chant = 1,
		/datum/ambient_activity/tribal_hunt = 1,
		/datum/ambient_activity/nap = 1,
		/datum/ambient_activity/chat = 2,
		/datum/ambient_activity/wander = 1,
	)
	/// Their spear is in their hand (not stuck in the ground somewhere)
	var/has_spear = TRUE
	/// Where their thrown spear stuck, if it did
	var/datum/weakref/thrown_spear_ref
	/// world.time their drawn-back spear flies, while winding up a throw
	var/throw_windup_until = 0

/mob/living/basic/ambient_npc/planet/tribal/Initialize(mapload)
	. = ..()
	if(prob(25))
		death_loot = death_loot + /obj/item/clothing/suit/armor/bone

/mob/living/basic/ambient_npc/planet/tribal/Destroy()
	drop_thrown_spear()
	return ..()

// The spear left in the ground goes too: the one they carried drops with them
/mob/living/basic/ambient_npc/planet/tribal/death(gibbed)
	drop_thrown_spear()
	return ..()

/// Their thrown spear, if it is still stuck somewhere
/mob/living/basic/ambient_npc/planet/tribal/proc/thrown_spear()
	var/obj/effect/ambient_thrown_spear/stuck = thrown_spear_ref?.resolve()
	return QDELETED(stuck) ? null : stuck

/// Forgets and removes the spear they threw
/mob/living/basic/ambient_npc/planet/tribal/proc/drop_thrown_spear()
	var/obj/effect/ambient_thrown_spear/stuck = thrown_spear()
	thrown_spear_ref = null
	if(stuck)
		qdel(stuck)

/// A spear back in hand
/mob/living/basic/ambient_npc/planet/tribal/proc/rearm()
	drop_thrown_spear()
	has_spear = TRUE
	idle_held = /obj/item/spear/bamboospear
	arm(/obj/item/spear/bamboospear)
	set_held(/obj/item/spear/bamboospear)

// Without a spear the first thing they do is get it back
/mob/living/basic/ambient_npc/planet/tribal/pick_activity()
	if(!has_spear && start_activity(new /datum/ambient_activity/fetch_spear(src)))
		return activity
	return ..()

/mob/living/basic/ambient_npc/planet/tribal/throw_reach()
	return has_spear ? 6 : 0

/**
 * A thrown spear: from three to six tiles, in plain sight, one throw at a time for the whole camp.
 * The spear is drawn back first (a wind-up anyone can see) and flies on their next beat.
 */
/mob/living/basic/ambient_npc/planet/tribal/try_ranged(mob/living/target)
	if(!has_spear)
		return FALSE
	var/distance = get_dist(src, target)
	if(throw_windup_until)
		if(distance > 6 || !bounty_ai_can_see(src, target, 6))
			throw_windup_until = 0
			return FALSE
		face_atom(target)
		if(world.time >= throw_windup_until)
			throw_windup_until = 0
			throw_spear(target)
		return TRUE
	if(distance < 3 || distance > 6 || !bounty_ai_can_see(src, target, 6))
		return FALSE
	var/list/visit = ambient_site_visit(place)
	if(visit["next_throw"] > world.time)
		return FALSE
	visit["next_throw"] = world.time + 3 SECONDS
	throw_windup_until = world.time + 0.8 SECONDS
	face_atom(target)
	visible_message(span_danger("[src] draws back a spear!"))
	return TRUE

/// Throws their spear at `target`: the spear's own throw, and it sticks where it lands
/mob/living/basic/ambient_npc/planet/tribal/proc/throw_spear(mob/living/target)
	var/turf/start = get_turf(src)
	if(!start)
		return
	var/obj/projectile/ambient_spear/spear = new(start)
	var/datum/bounty_real_weapon/weapon = bounty_real_weapon(/obj/item/spear/bamboospear)
	weapon.load_thrown(spear)
	spear.firer = src
	spear.fired_from = src
	spear.aim_projectile(target, src)
	if(QDELETED(spear))
		return
	has_spear = FALSE
	idle_held = null
	arm(null)
	set_held(null)
	do_attack_animation(target)
	playsound(src, 'sound/items/weapons/thudswoosh.ogg', 40, TRUE)
	spear.fire()

/**
 * The camp's lookout (the first of them awake) watches the ring: a warning for anyone who
 * crosses it, the whole camp on anyone who stays armed, and someone to walk up to anyone who
 * comes empty-handed.
 */
/mob/living/basic/ambient_npc/planet/tribal/watch(list/players)
	// Their own spear, if they are standing by it
	var/obj/effect/ambient_thrown_spear/stuck = thrown_spear()
	if(!has_spear && stuck && get_dist(src, stuck) <= 1 && !istype(activity, /datum/ambient_activity/fight))
		manual_emote("pulls a spear out of the ground.")
		rearm()
	var/datum/ambient_place/site/site = place
	if(!istype(site) || !site.center || camp_lookout() != src)
		return
	var/turf/center = site.center
	var/list/visit = ambient_site_visit(site)
	var/list/entered = visit["entered"]
	if(!islist(entered))
		entered = list()
		visit["entered"] = entered
	var/list/warned = visit["warned"]
	if(!islist(warned))
		warned = list()
		visit["warned"] = warned
	var/obj/structure/bonfire/fire = site.get_prop(/obj/structure/bonfire)
	players = players || ambient_players_near(center, AMBIENT_TRIBAL_RING_RADIUS)
	var/list/inside = list()
	for(var/mob/living/player as anything in players)
		var/turf/where = get_turf(player)
		if(QDELETED(player) || player.stat == DEAD || !where || get_dist(where, center) > AMBIENT_TRIBAL_RING_RADIUS)
			continue
		var/key = REF(player)
		inside[key] = TRUE
		if(!entered[key])
			entered[key] = world.time
		// A warning first, once a minute each
		if(warned[key] < world.time)
			warned[key] = world.time + 1 MINUTES
			var/mob/living/basic/ambient_npc/planet/tribal/shouter = nearest_awake(player)
			if(shouter)
				shouter.face_atom(player)
				shouter.speak_context("warn", player, force = TRUE)
			continue
		if(ambient_holds_weapon(player))
			if(world.time - entered[key] >= AMBIENT_TRIBAL_ARMED_GRACE || (fire && get_dist(where, fire) <= AMBIENT_TRIBAL_FIRE_RANGE))
				camp_attack(player)
			continue
		offer_trade(player)
	for(var/key in entered.Copy())
		if(!inside[key])
			entered -= key

/// The first of the camp who is awake and not already off somewhere: the one who keeps watch
/mob/living/basic/ambient_npc/planet/tribal/proc/camp_lookout()
	for(var/mob/living/basic/ambient_npc/planet/tribal/hunter in place?.npcs)
		if(hunter.stat == CONSCIOUS && !hunter.fading && !hunter.sleeping)
			return hunter
	return null

/// The hunter awake and nearest to `who`, or null
/mob/living/basic/ambient_npc/planet/tribal/proc/nearest_awake(atom/who)
	var/mob/living/basic/ambient_npc/planet/tribal/best
	var/best_distance = INFINITY
	for(var/mob/living/basic/ambient_npc/planet/tribal/hunter in place?.living_npcs())
		if(hunter.sleeping)
			continue
		var/distance = get_dist(hunter, who)
		if(distance < best_distance)
			best = hunter
			best_distance = distance
	return best

/// The whole camp goes for `target`, sleepers included
/mob/living/basic/ambient_npc/planet/tribal/proc/camp_attack(mob/living/target)
	var/shouted = FALSE
	for(var/mob/living/basic/ambient_npc/planet/tribal/hunter in place?.living_npcs())
		if(istype(hunter.activity, /datum/ambient_activity/fight))
			continue
		if(!shouted && !hunter.sleeping)
			shouted = TRUE
			hunter.speak_context("attack", target, force = TRUE)
		hunter.engage(target)

/// Someone walks up to an empty-handed visitor to trade, unless someone already is
/mob/living/basic/ambient_npc/planet/tribal/proc/offer_trade(mob/living/visitor)
	var/list/visit = ambient_site_visit(place)
	if(visit["offer_until"] > world.time)
		return
	var/mob/living/basic/ambient_npc/planet/tribal/trader = nearest_awake(visitor)
	if(!trader || istype(trader.activity, /datum/ambient_activity/fight) || trader.activity?.priority > AMBIENT_PRIORITY_ROUTINE)
		return
	if(trader.start_activity(new /datum/ambient_activity/tribal_offer(trader, visitor)))
		visit["offer_until"] = world.time + 90 SECONDS

/// A hide or meat for a bone spear, once per crew
/mob/living/basic/ambient_npc/planet/tribal/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(user.combat_mode || !can_act() || !(istype(tool, /obj/item/stack/sheet/animalhide) || istype(tool, /obj/item/food/meat/slab)))
		return ..()
	face_atom(user)
	if(!first_for_crew(user, "bone_spear"))
		speak_context("trade_refused", user, force = TRUE)
		return ITEM_INTERACT_BLOCKING
	var/offered_name = tool.name
	if(isstack(tool))
		var/obj/item/stack/hides = tool
		if(!hides.use(1))
			return ITEM_INTERACT_BLOCKING
	else
		if(!user.temporarilyRemoveItemFromInventory(tool))
			return ITEM_INTERACT_BLOCKING
		qdel(tool)
	manual_emote("takes the [offered_name] and hands over a bone spear.")
	var/obj/item/spear/bonespear/payment = new(drop_location())
	user.put_in_hands(payment)
	speak_context("trade_done", user, force = TRUE)
	if(istype(activity, /datum/ambient_activity/tribal_offer))
		end_activity()
	return ITEM_INTERACT_SUCCESS

// ----- the thrown spear -----

/// A bamboo spear in flight: the spear's own throw, never at the thrower's own camp; it sticks where it lands
/obj/projectile/ambient_spear
	name = "bamboo spear"
	icon = 'icons/obj/weapons/spear.dmi'
	icon_state = "bamboo_spear0"
	damage_type = BRUTE
	armor_flag = MELEE
	speed = 0.6
	range = 7
	hitsound = 'sound/items/weapons/pierce.ogg'
	/// It has stuck somewhere already
	var/landed = FALSE

/obj/projectile/ambient_spear/can_hit_target(atom/target, direct_target = FALSE, ignore_loc = FALSE, cross_failed = FALSE)
	. = ..()
	if(!. || !istype(target, /mob/living/basic/ambient_npc))
		return
	var/mob/living/basic/ambient_npc/thrower = firer
	var/mob/living/basic/ambient_npc/other = target
	if(istype(thrower) && other.place == thrower.place)
		return FALSE

/obj/projectile/ambient_spear/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	land()

/obj/projectile/ambient_spear/on_range()
	land()
	return ..()

/// Sticks in the ground where it came down, for its thrower to fetch
/obj/projectile/ambient_spear/proc/land()
	if(landed)
		return
	landed = TRUE
	var/turf/where = get_turf(src)
	var/mob/living/basic/ambient_npc/planet/tribal/thrower = firer
	if(!istype(thrower) || QDELETED(thrower) || thrower.stat == DEAD || !where || !ambient_ground_ok(where))
		return
	thrower.drop_thrown_spear()
	var/obj/effect/ambient_thrown_spear/stuck = new(where)
	thrower.thrown_spear_ref = WEAKREF(stuck)

/// A thrown spear stuck in the ground. Its thrower pulls it out again; nobody else can take it.
/obj/effect/ambient_thrown_spear
	name = "bamboo spear"
	desc = "A bamboo spear, stuck point-first in the ground."
	icon = 'icons/obj/weapons/spear.dmi'
	icon_state = "bamboo_spear0"
	anchored = TRUE
	density = FALSE
	layer = OBJ_LAYER

/obj/effect/ambient_thrown_spear/Initialize(mapload)
	. = ..()
	transform = matrix().Turn(45)
	// Nobody came back for it. Our own callback, so deleting it early takes the timer with it.
	addtimer(CALLBACK(src, PROC_REF(rot)), 5 MINUTES, TIMER_DELETE_ME)

/obj/effect/ambient_thrown_spear/proc/rot()
	qdel(src)

// ----- activities -----

/// Getting their spear back: pulled out of the ground where it stuck, or a spare off the rack
/datum/ambient_activity/fetch_spear
	name = "fetching a spear"

/datum/ambient_activity/fetch_spear/setup()
	var/mob/living/basic/ambient_npc/planet/tribal/hunter = doer
	if(!istype(hunter) || hunter.has_spear)
		return FALSE
	var/atom/target = hunter.thrown_spear()
	if(!target)
		var/datum/ambient_place/site/site = hunter.place
		target = istype(site) ? site.get_prop(/obj/effect/ambient_camp_prop/spear_rack) : null
	if(!target)
		hunter.rearm()
		return FALSE
	go_to(get_turf(target), 1)
	return TRUE

/datum/ambient_activity/fetch_spear/arrive()
	var/mob/living/basic/ambient_npc/planet/tribal/hunter = doer
	if(!istype(hunter) || hunter.has_spear)
		return
	hunter.manual_emote(hunter.thrown_spear() ? "pulls a spear out of the ground." : "takes a spear from the rack.")
	hunter.rearm()

/datum/ambient_activity/fetch_spear/act(seconds)
	return AMBIENT_STEP_DONE

/datum/ambient_activity/fetch_spear/spot_unreachable()
	var/mob/living/basic/ambient_npc/planet/tribal/hunter = doer
	// It fell somewhere they cannot get to: a spare from the rack
	if(istype(hunter))
		hunter.rearm()
	spot = null
	arrived = TRUE

/// Walking up to an empty-handed visitor with a bone spear to trade
/datum/ambient_activity/tribal_offer
	name = "offering a trade"
	duration_low = 45 SECONDS
	duration_high = 60 SECONDS
	var/datum/weakref/visitor_ref

/datum/ambient_activity/tribal_offer/New(mob/living/basic/ambient_npc/new_doer, atom/visitor)
	. = ..()
	visitor_ref = WEAKREF(visitor)

/// The visitor, while they are still in the camp
/datum/ambient_activity/tribal_offer/proc/visitor()
	var/mob/living/visitor = visitor_ref?.resolve()
	var/datum/ambient_place/site/site = doer.place
	if(QDELETED(visitor) || visitor.stat == DEAD || !istype(site) || !site.center || get_dist(visitor, site.center) > AMBIENT_TRIBAL_RING_RADIUS)
		return null
	return visitor

/datum/ambient_activity/tribal_offer/setup()
	var/mob/living/visitor = visitor()
	if(!visitor)
		return FALSE
	set_duration()
	go_to(visitor, 1)
	return TRUE

/datum/ambient_activity/tribal_offer/arrive()
	var/mob/living/visitor = visitor()
	if(!visitor)
		return
	doer.face_atom(visitor)
	doer.set_held(/obj/item/spear/bonespear)
	doer.speak_context("trade_offer", visitor, force = TRUE)

/datum/ambient_activity/tribal_offer/act(seconds)
	var/mob/living/visitor = visitor()
	if(!visitor)
		return AMBIENT_STEP_DONE
	if(get_dist(doer, visitor) > 1)
		go_to(visitor, 1)
		return AMBIENT_STEP_MOVE
	doer.face_atom(visitor)
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/tribal_offer/finish()
	. = ..()
	var/mob/living/basic/ambient_npc/planet/tribal/hunter = doer
	if(istype(hunter) && !QDELETED(hunter))
		hunter.show_idle_held()

/**
 * Out hunting: out past the fire into the brush with a partner, a long crouch, a spear into the
 * brush, and back to the fire with a haunch over the shoulder. The meat is only for show.
 */
/datum/ambient_activity/tribal_hunt
	name = "hunting"
	/// "out", "stalk", then "back"
	var/stage = "out"
	/// world.time the stalking ends
	var/stalk_until = 0

/datum/ambient_activity/tribal_hunt/setup()
	var/datum/ambient_place/site/site = doer.place
	if(!istype(site) || !site.center)
		return FALSE
	var/turf/hide
	for(var/attempt in 1 to 8)
		var/turf/far = get_ranged_target_turf(site.center, pick(GLOB.alldirs), rand(8, 11))
		hide = doer.random_tile_near(far, 2, failed_spots)
		if(hide && !ambient_off_limits(hide))
			break
		hide = null
	if(!hide)
		return FALSE
	go_to(hide)
	// A partner, if one is free
	for(var/mob/living/basic/ambient_npc/planet/tribal/mate in site.living_npcs())
		if(mate == doer || mate.sleeping || (mate.activity && !mate.activity.accepts_company))
			continue
		if(mate.start_activity(new /datum/ambient_activity/follow(mate, doer, 2, 3 MINUTES)))
			break
	return TRUE

/datum/ambient_activity/tribal_hunt/arrive()
	switch(stage)
		if("out")
			stage = "stalk"
			stalk_until = world.time + rand(20 SECONDS, 40 SECONDS)
			doer.crouch()
			doer.manual_emote("crouches low, watching the brush.")
		if("back")
			doer.manual_emote("drops a haunch of meat by the fire.")
			doer.set_held(null)
			ends_at = world.time

/datum/ambient_activity/tribal_hunt/act(seconds)
	if(stage != "stalk")
		return AMBIENT_STEP_CONTINUE
	if(world.time < stalk_until)
		chatter("hunt", 30 SECONDS, 60 SECONDS)
		return AMBIENT_STEP_CONTINUE
	doer.stand_up()
	doer.manual_emote("throws a spear into the brush, and goes to fetch the kill.")
	playsound(doer, 'sound/items/weapons/thudswoosh.ogg', 30, TRUE, -3)
	doer.set_held(/obj/item/food/meat/slab)
	stage = "back"
	var/datum/ambient_place/site/site = doer.place
	var/obj/structure/bonfire/fire = istype(site) ? site.get_prop(/obj/structure/bonfire) : null
	var/turf/back = fire ? doer.free_tile_beside(fire, 1, failed_spots) : (istype(site) ? site.center : null)
	if(!back)
		return AMBIENT_STEP_DONE
	go_to(back)
	return AMBIENT_STEP_MOVE

/datum/ambient_activity/tribal_hunt/finish()
	. = ..()
	var/mob/living/basic/ambient_npc/planet/tribal/hunter = doer
	if(istype(hunter) && !QDELETED(hunter))
		hunter.show_idle_held()

/// Sitting at the fire
/datum/ambient_activity/camp_chore/fireside
	name = "sitting at the fire"
	prop_type = /obj/structure/bonfire
	crouches = TRUE
	emotes = list("feeds a stick to the fire.", "scrapes a spear point on a stone.", "stares into the flames.")

/// Spear drills at the post
/datum/ambient_activity/camp_chore/spear_practice
	name = "practising"
	prop_type = /obj/effect/ambient_camp_prop/post
	swings = TRUE
	held_look = /obj/item/spear/bamboospear
	emote_low = 4 SECONDS
	emote_high = 8 SECONDS
	emotes = list("thrusts a spear at the post.", "spins the spear and strikes the post.", "lunges at the post.")
	sounds = list('sound/items/weapons/genhit1.ogg', 'sound/items/weapons/genhit2.ogg')

/// A low chant at the fire; whoever is near joins in
/datum/ambient_activity/camp_chore/chant
	name = "chanting"
	prop_type = /obj/structure/bonfire
	crouches = TRUE
	duration_low = 30 SECONDS
	duration_high = 60 SECONDS
	emotes = list("chants low at the fire.", "raises a hand to the smoke, chanting.")

/datum/ambient_activity/camp_chore/chant/do_chore()
	. = ..()
	var/atom/fire = prop()
	if(!fire)
		return
	for(var/mob/living/basic/ambient_npc/planet/tribal/mate in doer.place?.living_npcs())
		if(mate != doer && !mate.sleeping && get_dist(mate, fire) <= 3 && prob(50))
			mate.manual_emote("joins the chant.")

// ----- the camp -----

/datum/ambient_site_kind/planet/tribal/realize(datum/ambient_place/site/site)
	var/missing = site.npcs_missing()
	if(!missing)
		return FALSE
	new_visit(site)
	build_camp(site)
	for(var/i in 1 to missing)
		var/mob/living/basic/ambient_npc/planet/tribal/hunter = site.spawn_npc(npc_type, ambient_free_turf_near(site.center, 2) || site.center)
		if(hunter)
			hunter.leash_bounds = ambient_square_bounds(site.center, AMBIENT_TRIBAL_RING_RADIUS + AMBIENT_TRIBAL_CHASE_PAST_RING)
	return TRUE

/**
 * The fire and the ring of poles are made once; the mats, the rack and the post (scenery) are put
 * back whenever they are missing.
 */
/datum/ambient_site_kind/planet/tribal/proc/build_camp(datum/ambient_place/site/site)
	if(!site.data["camp_built"])
		site.data["camp_built"] = TRUE
		make_prop(site, /obj/structure/bonfire/dense/ambient_camp, site.center)
		build_ring(site)
	ensure_prop(site, /obj/effect/ambient_camp_prop/spear_rack, ambient_free_turf_near(site.center, 2))
	ensure_prop(site, /obj/effect/ambient_camp_prop/post, ambient_free_turf_near(site.center, 3))
	var/mats = 0
	for(var/datum/weakref/ref as anything in site.props)
		var/atom/thing = ref?.resolve()
		if(!QDELETED(thing) && istype(thing, /obj/effect/ambient_camp_prop/mat))
			mats++
	for(var/i in mats + 1 to site.npc_total)
		make_prop(site, /obj/effect/ambient_camp_prop/mat, ambient_free_turf_near(site.center, 2))

/// Six to eight heads on poles in a ring around the fire, where the ground allows
/datum/ambient_site_kind/planet/tribal/proc/build_ring(datum/ambient_place/site/site)
	var/turf/center = site.center
	var/count = rand(6, 8)
	var/start = rand(0, 359)
	for(var/i in 0 to count - 1)
		var/angle = start + i * (360 / count)
		var/turf/mark = locate(center.x + round(AMBIENT_TRIBAL_RING_RADIUS * cos(angle)), center.y + round(AMBIENT_TRIBAL_RING_RADIUS * sin(angle)), center.z)
		if(!mark)
			continue
		if(!ambient_ground_ok(mark) || ambient_off_limits(mark))
			mark = ambient_free_turf_near(mark, 1)
		if(mark && !ambient_off_limits(mark))
			make_prop(site, /obj/structure/headpike/bamboo/ambient, mark)

/**
 * A head on a bamboo pole at the edge of the hunters' ground. Taken down, only the head comes off:
 * the pole is left to rot, so the ring is no pile of free spears.
 */
/obj/structure/headpike/bamboo/ambient
	desc = "A head on a bamboo pole, facing outward. Everyone who walks past is meant to see it."

/obj/structure/headpike/bamboo/ambient/Initialize(mapload)
	. = ..()
	if(!spear)
		spear = new speartype(src)
	if(!victim)
		victim = new(src)
		victim.real_name = generate_random_name()
	update_appearance()

/obj/structure/headpike/bamboo/ambient/atom_deconstruct(disassembled)
	var/obj/item/spear/pole = spear
	. = ..(FALSE)
	qdel(pole)

#undef AMBIENT_TRIBAL_RING_RADIUS
#undef AMBIENT_TRIBAL_CHASE_PAST_RING
#undef AMBIENT_TRIBAL_ARMED_GRACE
#undef AMBIENT_TRIBAL_FIRE_RANGE
#undef AMBIENT_CANNIBAL_STRIKE_RANGE
#undef AMBIENT_CANNIBAL_PATIENCE
#undef AMBIENT_CANNIBAL_WARNING
#undef AMBIENT_CANNIBAL_SIGHT
