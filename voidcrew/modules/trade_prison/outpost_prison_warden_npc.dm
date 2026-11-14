/**
 * # Outpost lockup: the warden
 *
 * Each trader outpost's lockup has an NPC warden standing behind the front-room desk (`desk_turf`), across from the
 * lift alcove and beside Processing's outer door. The warden is an `/mob/living/carbon/human/npc/ambient_npc/outpost/trader`
 * subtype with a zone-voiced `/datum/outpost_shop/lockup_warden` that has no stock, no till and no UI:
 * - Real human body (bleeds, crits, dies, revives) with gear locked to the body (`human_npc_gear.dm`) and no shelf drop.
 * - Clicking them speaks a short line in the outpost's voice and opens nothing.
 * - Assaulting or grabbing them reports `OUTPOST_CRIME_ASSAULT_STAFF`; killing them reports `OUTPOST_CRIME_KILL_STAFF`.
 * - Outpost recovery (`outpost_police/recovery_staff.dm`) tracks the desk like a checkpoint guard's post: a replacement
 *   comes on shift from the office staff closet (or steps onto an unwatched desk) and takes over `warden_ref`.
 */

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden
	name = "warden"
	desc = "The lockup's warden. Has seen your sort before."

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/Destroy()
	if(outpost?.prison?.warden_ref?.resolve() == src)
		outpost.prison.warden_ref = null
	return ..()

// Their police card carries their name, as a checkpoint guard's does
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/setup_from_shop()
	. = ..()
	var/obj/item/card/id/card = wear_id
	if(istype(card))
		card.registered_name = real_name
		card.update_label()

// They keep the lockup desk rather than fleeing to a concourse lift
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/may_flee()
	return FALSE

// Nothing on the lockup desk is for sale or dropped
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/drop_from_shelf()
	if(shop)
		shop.drop_spent = TRUE
	return null

// Binds the initial warden or a recovery replacement to the outpost's prison
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/take_counter(datum/outpost_shop/new_shop, turf/counter, is_first)
	. = ..()
	if(outpost?.prison)
		outpost.prison.warden_ref = WEAKREF(src)

// Clicking the warden speaks a short line and opens no radial or shop window
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/open_trader_menu(mob/living/user)
	if(!shop || !is_serving() || IS_DEAD_OR_INCAP(user) || !customer_in_reach(user))
		return
	if(outpost?.is_user_barred(user))
		speak_line(TRADER_LINE_REFUSAL)
		return
	speak_line(TRADER_LINE_IDLE)

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/halcyon
	shop_type = /datum/outpost_shop/lockup_warden/halcyon

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/quartermain
	shop_type = /datum/outpost_shop/lockup_warden/quartermain

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/undertow
	shop_type = /datum/outpost_shop/lockup_warden/undertow

// =========================================================================
// OUTFITS AND DESKS
// =========================================================================

/// Abstract: a lockup warden's desk. Sells nothing and holds no till.
/datum/outpost_shop/lockup_warden
	outpost_name = "\improper Lockup"
	trader_name = "Warden"
	categories = list()
	sku_types = list()
	rotating_picks = 0
	rare_picks_max = 0
	chart_picks = 0

/// Vance keeps Halcyon's lockup desk: formal blue shirt and armored warden's jacket, face uncovered
/datum/outfit/lockup_warden_halcyon
	name = "Halcyon lockup warden"
	uniform = /obj/item/clothing/under/rank/security/warden/formal
	suit = /obj/item/clothing/suit/armor/vest/warden
	gloves = /obj/item/clothing/gloves/color/black
	shoes = /obj/item/clothing/shoes/jackboots
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/outpost_police

/datum/outpost_shop/lockup_warden/halcyon
	outpost_name = "\improper Halcyon Lockup"
	trader_name = "Vance"
	trader_outfit = /datum/outfit/lockup_warden_halcyon
	trader_gender = MALE
	trader_voice_pack = "goon.speak_2"
	trader_voice_pitch = 0.9
	trader_lines = list(
		TRADER_LINE_REFUSAL = list(
			"Move along, please.",
			"Nothing for you at this desk.",
		),
		TRADER_LINE_AGGRESSION = list(
			"Security! Front desk!",
			"Hands off!",
		),
		TRADER_LINE_IDLE = list(
			"Quiet cells today.",
			"Glass is clean. Let's keep it that way.",
			"Shift's half done and nobody's yelled yet.",
			"You're on the good side of the glass. Stay there.",
		),
	)

/// Keller works the Quartermain's lockup: depot grey and a worn security leather coat
/datum/outfit/lockup_warden_quartermain
	name = "Quartermain lockup warden"
	uniform = /obj/item/clothing/under/rank/security/warden/grey
	suit = /obj/item/clothing/suit/armor/vest/leather
	gloves = /obj/item/clothing/gloves/color/black
	shoes = /obj/item/clothing/shoes/jackboots
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/outpost_police

/datum/outpost_shop/lockup_warden/quartermain
	outpost_name = "\improper Depot Lockup"
	trader_name = "Keller"
	trader_outfit = /datum/outfit/lockup_warden_quartermain
	trader_gender = FEMALE
	trader_voice_pack = "goon.speak_4"
	trader_voice_pitch = 0.95
	trader_lines = list(
		TRADER_LINE_REFUSAL = list(
			"Not talking to you. Out.",
			"Clear the desk.",
		),
		TRADER_LINE_AGGRESSION = list(
			"Hands off!",
			"Officers to the lockup!",
		),
		TRADER_LINE_IDLE = list(
			"Don't lean on the glass.",
			"Six cells, two guards, one desk. Move it along.",
			"Coffee's gone cold again.",
			"State your business or clear the floor.",
		),
	)

/// Morrow runs the Undertow's desk: dark suit, armored trenchcoat and sunglasses
/datum/outfit/lockup_warden_undertow
	name = "Undertow lockup warden"
	uniform = /obj/item/clothing/under/rank/security/detective/noir
	suit = /obj/item/clothing/suit/armor/hos/trenchcoat
	glasses = /obj/item/clothing/glasses/sunglasses
	gloves = /obj/item/clothing/gloves/color/black
	shoes = /obj/item/clothing/shoes/jackboots
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/outpost_police

/datum/outpost_shop/lockup_warden/undertow
	outpost_name = "\improper Undertow Lockup"
	trader_name = "Morrow"
	trader_outfit = /datum/outfit/lockup_warden_undertow
	trader_gender = MALE
	trader_voice_pack = "goon.speak_3"
	trader_voice_pitch = 0.8
	trader_lines = list(
		TRADER_LINE_REFUSAL = list(
			"Walk away.",
			"Nothing to say to you.",
		),
		TRADER_LINE_AGGRESSION = list(
			"Bad mistake.",
			"Put them down!",
		),
		TRADER_LINE_IDLE = list(
			"Keep your hands where I can see them.",
			"Everybody in there had a plan too.",
			"Don't tap the glass.",
			"Bringing someone in, or just looking?",
		),
	)

// =========================================================================
// THE PRISON'S SIDE
// =========================================================================

/datum/outpost_prison
	/// Weakref to the wing's current lockup warden
	var/datum/weakref/warden_ref
	/// Whether the wing has spawned its initial warden at `desk_turf`
	var/warden_spawned = FALSE

/// The warden mob subtype for this prison's host outpost
/datum/outpost_prison/proc/warden_type_for_outpost()
	if(istype(outpost, /obj/structure/overmap/trader_outpost/outfitter))
		return /mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/quartermain
	if(istype(outpost, /obj/structure/overmap/trader_outpost/black_market))
		return /mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/undertow
	return /mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/halcyon

/// Spawns the initial warden behind `desk_turf` on the wing's first tick and registers the desk with outpost recovery
/datum/outpost_prison/proc/ensure_warden()
	if(warden_spawned || !desk_turf || QDELETED(outpost))
		return null
	warden_spawned = TRUE
	var/mob/living/existing = warden_ref?.resolve()
	if(!QDELETED(existing))
		return existing
	var/warden_type = warden_type_for_outpost()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/warden = new warden_type(desk_turf)
	var/datum/outpost_shop/desk_shop = outpost.get_shop(warden.shop_type)
	desk_shop.counter_turf = desk_turf
	desk_shop.set_keeper(warden)
	outpost.recovery?.register_posts()
	return warden

/// Resolves the wing's warden when alive, conscious, unrestrained, out of crit and within 1 tile of `desk_turf`, else null
/datum/outpost_prison/proc/warden_at_desk()
	if(!desk_turf)
		return null
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/warden = warden_ref?.resolve()
	if(QDELETED(warden) || warden.stat != CONSCIOUS || outpost_npc_played(warden))
		return null
	if(HAS_TRAIT(warden, TRAIT_INCAPACITATED) || HAS_TRAIT(warden, TRAIT_RESTRAINED) || HAS_TRAIT(warden, TRAIT_CRITICAL_CONDITION))
		return null
	if(warden.fading || istype(warden.activity, /datum/ambient_activity/leave) || warden.has_status_effect(/datum/status_effect/grouped/heldup))
		return null
	var/turf/standing = get_turf(warden)
	if(!standing || standing.z != desk_turf.z || get_dist(standing, desk_turf) > 1)
		return null
	return warden

/// Where a replacement warden enters on RESTAFF: the unwatched office staff closet (walking out through the office door to `desk_turf`), else an unwatched open `desk_turf`
/datum/outpost_prison/proc/warden_arrival_spot(turf/fallback_desk)
	if(length(staff_closet_turfs))
		var/turf/closet_tile = guard_arrival_spot()
		if(closet_tile)
			return closet_tile
	var/turf/desk = fallback_desk || desk_turf
	if(desk && !desk.is_blocked_turf(exclude_mobs = FALSE) && !human_npc_watched(desk))
		return desk
	return null

/// Makes the warden at the desk speak `line` (always when `forced`, rate-limited otherwise)
/datum/outpost_prison/proc/warden_say(line, forced = FALSE)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/warden = warden_at_desk()
	if(!warden || !line)
		return FALSE
	if(forced)
		warden.say(line)
		return TRUE
	if(!COOLDOWN_FINISHED(warden, speak_cooldown))
		return FALSE
	COOLDOWN_START(warden, speak_cooldown, 3 SECONDS)
	warden.say(line)
	return TRUE

/// Cleans up the warden when the prison is deleted
/datum/outpost_prison/proc/warden_destroy()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/warden = warden_ref?.resolve()
	warden_ref = null
	if(!QDELETED(warden) && !warden.npc_ever_played())
		qdel(warden)
