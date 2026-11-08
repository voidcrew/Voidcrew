/**
 * # Bounty hunting: pressure suits
 *
 * Criminals and their companions breathe like anyone else. Out of a pressure suit, where a person
 * could not breathe (vacuum, thin or cold air, plasma), they choke: BOUNTY_EVA_EXPOSURE_PERCENT of
 * their health a second, forced past the mercy line and the automated floor, until they die.
 *
 * Wanted at a space ruin, or anywhere on a planet whose air would kill them, they arrive suited
 * (bounty_eva_kit_up_criminal()): a soft EVA suit for the meek and petty, a work modsuit for a
 * Wanted normal criminal, a modsuit by kit for a mini-boss. Their companions get soft suits. Aboard
 * a pirate ship or at a trader outpost they arrive in plain clothes.
 *
 * The suit is real (/datum/component/bounty_eva holds the pieces in the mob's contents). Once they
 * are down, cuffed, stunned or dead, anyone can open the strip menu (drag them onto yourself) to take
 * the helmet, suit or modsuit off, or to put one on: a captured criminal needs a suit to be carried
 * across space alive. Their look is rebuilt whenever a piece goes on or comes off.
 */

/// Health lost each second out of a suit in air a person can't breathe, in percent of max health
#define BOUNTY_EVA_EXPOSURE_PERCENT 3
/// Between two "gasps for air" lines
#define BOUNTY_EVA_GASP_COOLDOWN (6 SECONDS)
/// Least oxygen partial pressure, in kPa, a person breathes without a suit
#define BOUNTY_EVA_MIN_OXYGEN 12
/// Most plasma partial pressure, in kPa, a person breathes without a suit
#define BOUNTY_EVA_MAX_PLASMA 0.5
/// Coldest air, in kelvin, a person stands about in without a suit
#define BOUNTY_EVA_MIN_TEMP 240
/// Random tiles of a planet's site checked for air that would kill them
#define BOUNTY_EVA_SITE_SAMPLES 6

/// Which piece a strip slot holds
#define BOUNTY_EVA_HELMET "helmet"
#define BOUNTY_EVA_SUIT "suit"
#define BOUNTY_EVA_MOD "mod"

/// Soft suits, each list(suit, helmet). All green tier.
GLOBAL_LIST_INIT(bounty_eva_softsuits, list(
	list(/obj/item/clothing/suit/space/eva, /obj/item/clothing/head/helmet/space/eva),
	list(/obj/item/clothing/suit/space, /obj/item/clothing/head/helmet/space),
	list(/obj/item/clothing/suit/space/nasavoid, /obj/item/clothing/head/helmet/space/nasavoid),
	list(/obj/item/clothing/suit/space/orange, /obj/item/clothing/head/helmet/space/orange),
))

/// The strip menu's slots for a pressure suit
GLOBAL_LIST_INIT(bounty_eva_strippables, create_strippable_list(list(
	/datum/strippable_item/bounty_eva/helmet,
	/datum/strippable_item/bounty_eva/suit,
	/datum/strippable_item/bounty_eva/mod,
)))

// ===== AIR =====

/// Whether a person could stand about in the air at `where` without a suit: pressure, oxygen, cold and plasma
/proc/bounty_air_safe(atom/where)
	var/datum/gas_mixture/air = where?.return_air()
	if(!air)
		return FALSE
	var/pressure = air.return_pressure()
	if(pressure < HAZARD_LOW_PRESSURE || pressure > HAZARD_HIGH_PRESSURE)
		return FALSE
	if(air.temperature < BOUNTY_EVA_MIN_TEMP)
		return FALSE
	var/total = air.total_moles()
	if(total <= 0)
		return FALSE
	var/list/gases = air.gases
	var/oxygen = (gases[/datum/gas/oxygen] ? gases[/datum/gas/oxygen][MOLES] : 0) + (gases[/datum/gas/pluoxium] ? gases[/datum/gas/pluoxium][MOLES] * PLUOXIUM_PROPORTION : 0)
	if(pressure * oxygen / total < BOUNTY_EVA_MIN_OXYGEN)
		return FALSE
	var/plasma = gases[/datum/gas/plasma] ? gases[/datum/gas/plasma][MOLES] : 0
	return pressure * plasma / total < BOUNTY_EVA_MAX_PLASMA

/**
 * Whether a criminal wanted on `posting`, appearing at `spot`, needs a suit: always at a space ruin
 * (an asteroid is vacuum a step from any door), and wherever the spot's air, or any of a few random
 * tiles of their planet, would kill them.
 */
/proc/bounty_site_needs_eva(datum/criminal_bounty/posting, turf/spot)
	if(posting?.placement_kind == BOUNTY_PLACEMENT_RUIN)
		return TRUE
	if(spot && !bounty_air_safe(spot))
		return TRUE
	if(posting?.placement_kind != BOUNTY_PLACEMENT_PLANET)
		return FALSE
	var/list/bounds = bounty_site_bounds(posting.site_ref?.resolve())
	if(length(bounds) < 5)
		return FALSE
	for(var/i in 1 to BOUNTY_EVA_SITE_SAMPLES)
		var/turf/open/sample = locate(rand(bounds[1], bounds[3]), rand(bounds[2], bounds[4]), bounds[5])
		if(!istype(sample) || isspaceturf(sample) || istype(sample, /turf/open/openspace))
			continue
		if(!bounty_air_safe(sample))
			return TRUE
	return FALSE

// ===== WHAT THEY WEAR =====

/**
 * Suits up a criminal wanted on `posting` if its site calls for it (bounty_site_needs_eva()), at
 * the spot it stands on. Called by body_setup() before its look goes on. Doesn't sleep.
 */
/proc/bounty_eva_kit_up_criminal(mob/living/basic/bounty_criminal/criminal, datum/criminal_bounty/posting)
	var/datum/component/bounty_eva/eva = criminal?.GetComponent(/datum/component/bounty_eva)
	if(!eva || eva.sealed() || !bounty_site_needs_eva(posting, get_turf(criminal)))
		return FALSE
	return eva.kit_up(bounty_eva_criminal_gear(criminal))

/// The modsuit a criminal wears out there, or null for a soft suit: by kit for a mini-boss, a work suit for a Wanted normal criminal
/proc/bounty_eva_criminal_gear(mob/living/basic/bounty_criminal/criminal)
	if(istype(criminal, /mob/living/basic/bounty_criminal/boss/juggernaut))
		return /obj/item/mod/control/pre_equipped/loader
	if(istype(criminal, /mob/living/basic/bounty_criminal/boss/heavy))
		return /obj/item/mod/control/pre_equipped/engineering
	if(istype(criminal, /mob/living/basic/bounty_criminal/boss/pyromaniac))
		return /obj/item/mod/control/pre_equipped/atmospheric
	if(istype(criminal, /mob/living/basic/bounty_criminal/boss/demolitionist))
		return /obj/item/mod/control/pre_equipped/research
	if(istype(criminal, /mob/living/basic/bounty_criminal/boss))
		return /obj/item/mod/control/pre_equipped/standard
	if(istype(criminal, /mob/living/basic/bounty_criminal/normal) && criminal.record?.tier != BOUNTY_TIER_PETTY)
		return pick(/obj/item/mod/control/pre_equipped/standard, /obj/item/mod/control/pre_equipped/civilian, /obj/item/mod/control/pre_equipped/engineering)
	return null

// ===== THE SUIT =====

/// A criminal's or companion's pressure suit: the pieces they wear, their breathing, and the strip menu that takes them off
/datum/component/bounty_eva
	/// A soft suit's two pieces
	var/obj/item/clothing/suit/suit
	var/obj/item/clothing/head/helmet
	/// Or a modsuit
	var/obj/item/mod/control/mod
	/// Pieces a player put on them through the strip menu, left behind rather than deleted with them
	var/list/obj/item/fitted
	COOLDOWN_DECLARE(gasp_cooldown)

/datum/component/bounty_eva/Initialize()
	if(!isbasicmob(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/bounty_eva/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATOM_EXITED, PROC_REF(on_exited))
	parent.AddElement(/datum/element/strippable, GLOB.bounty_eva_strippables, strip_check_proc())

/datum/component/bounty_eva/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_ATOM_EXITED)
	parent.RemoveElement(/datum/element/strippable, GLOB.bounty_eva_strippables, strip_check_proc())

/datum/component/bounty_eva/Destroy(force)
	var/atom/movable/owner = parent
	UnregisterSignal(owner, COMSIG_ATOM_EXITED)
	// A piece a hunter put on them is theirs: it stays behind (on the pad, say). Their own goes with them.
	var/atom/drop_spot = owner.drop_location()
	for(var/obj/item/piece as anything in pieces())
		if(piece.loc != owner)
			continue
		if(drop_spot && (piece in fitted))
			piece.forceMove(drop_spot)
		else
			qdel(piece)
	fitted = null
	suit = null
	helmet = null
	mod = null
	return ..()

/// The parent's own proc saying whether `user` may open its strip menu
/datum/component/bounty_eva/proc/strip_check_proc()
	if(istype(parent, /mob/living/basic/bounty_companion))
		return /mob/living/basic/bounty_companion/proc/eva_may_strip
	return /mob/living/basic/bounty_criminal/proc/eva_may_strip

/// The pieces they have on
/datum/component/bounty_eva/proc/pieces()
	. = list()
	for(var/obj/item/piece in list(helmet, suit, mod))
		. += piece

/// Whether they are sealed in: a modsuit, or a soft suit with its helmet
/datum/component/bounty_eva/proc/sealed()
	return !QDELETED(mod) || (!QDELETED(suit) && !QDELETED(helmet))

/// What they wear in `slot` (BOUNTY_EVA_*)
/datum/component/bounty_eva/proc/piece_in(slot)
	switch(slot)
		if(BOUNTY_EVA_HELMET)
			return helmet
		if(BOUNTY_EVA_SUIT)
			return suit
		if(BOUNTY_EVA_MOD)
			return mod
	return null

/// Whether `thing` can go on in `slot`: a pressure-proof helmet or suit with no modsuit on, or a modsuit with neither
/datum/component/bounty_eva/proc/fits(slot, obj/item/thing)
	if(!thing || piece_in(slot))
		return FALSE
	var/obj/item/clothing/garment = istype(thing, /obj/item/clothing) ? thing : null
	switch(slot)
		if(BOUNTY_EVA_HELMET)
			return !mod && istype(garment, /obj/item/clothing/head) && (garment.clothing_flags & STOPSPRESSUREDAMAGE)
		if(BOUNTY_EVA_SUIT)
			return !mod && istype(garment, /obj/item/clothing/suit) && (garment.clothing_flags & STOPSPRESSUREDAMAGE)
		if(BOUNTY_EVA_MOD)
			return !suit && !helmet && istype(thing, /obj/item/mod/control)
	return FALSE

/// Puts `thing` (already in their contents, or null to clear it) in `slot`
/datum/component/bounty_eva/proc/set_piece(slot, obj/item/thing)
	switch(slot)
		if(BOUNTY_EVA_HELMET)
			helmet = thing
		if(BOUNTY_EVA_SUIT)
			suit = thing
		if(BOUNTY_EVA_MOD)
			mod = thing

/**
 * Suits them up: a new `mod_type` modsuit, or a random soft suit when it is null. Their look is
 * rebuilt when `redress`. Doesn't sleep.
 */
/datum/component/bounty_eva/proc/kit_up(mod_type, redress = FALSE)
	var/atom/movable/owner = parent
	if(ispath(mod_type, /obj/item/mod/control))
		mod = new mod_type(owner)
	else
		var/list/softsuit = pick(GLOB.bounty_eva_softsuits)
		var/suit_type = softsuit[1]
		var/helmet_type = softsuit[2]
		suit = new suit_type(owner)
		helmet = new helmet_type(owner)
	if(redress)
		redress()
	return TRUE

/// A piece left their contents some other way: they no longer wear it
/datum/component/bounty_eva/proc/on_exited(datum/source, atom/movable/gone, direction)
	SIGNAL_HANDLER
	if(gone != helmet && gone != suit && gone != mod)
		return
	LAZYREMOVE(fitted, gone)
	if(gone == helmet)
		helmet = null
	if(gone == suit)
		suit = null
	if(gone == mod)
		mod = null
	redress()

/// Rebuilds their look for what they wear now
/datum/component/bounty_eva/proc/redress()
	if(QDELETED(parent))
		return
	if(istype(parent, /mob/living/basic/bounty_criminal))
		INVOKE_ASYNC(parent, TYPE_PROC_REF(/mob/living/basic/bounty_criminal, body_dress))
	else if(istype(parent, /mob/living/basic/bounty_companion))
		INVOKE_ASYNC(parent, TYPE_PROC_REF(/mob/living/basic/bounty_companion, eva_dress))

/**
 * The outfit for their look: `base_outfit` as it is, or with what they wear on top: a soft suit over
 * it, or a modsuit in place of its suit, hat, gloves and shoes. A datum when they wear anything (built
 * every time, never cached), else `base_outfit` itself.
 */
/datum/component/bounty_eva/proc/worn_outfit(base_outfit)
	if(!length(pieces()))
		return base_outfit
	var/datum/outfit/worn = ispath(base_outfit, /datum/outfit) ? new base_outfit : new /datum/outfit
	if(mod)
		worn.back = mod.type
		worn.suit = null
		worn.suit_store = null
		worn.head = null
		worn.gloves = null
		worn.shoes = null
		return worn
	if(suit)
		worn.suit = suit.type
		worn.suit_store = null
	if(helmet)
		worn.head = helmet.type
	return worn

/// Their breath this tick: out of a suit in air that would kill a person, they choke, and nothing holds it back
/datum/component/bounty_eva/proc/breathe(seconds_per_tick)
	var/mob/living/basic/body = parent
	if(body.stat == DEAD || !body.loc || HAS_TRAIT(body, TRAIT_GODMODE) || sealed())
		return
	if(bounty_air_safe(body.loc))
		return
	body.adjustOxyLoss(body.maxHealth * BOUNTY_EVA_EXPOSURE_PERCENT / 100 * seconds_per_tick, forced = TRUE)
	if(body.stat == DEAD || !COOLDOWN_FINISHED(src, gasp_cooldown))
		return
	COOLDOWN_START(src, gasp_cooldown, BOUNTY_EVA_GASP_COOLDOWN)
	body.visible_message(span_danger("[body] gasps for air!"))

// ===== THE STRIP MENU =====

/datum/strippable_item/bounty_eva
	/// The piece this slot holds (BOUNTY_EVA_*)
	var/slot

/datum/strippable_item/bounty_eva/helmet
	key = STRIPPABLE_ITEM_HEAD
	slot = BOUNTY_EVA_HELMET

/datum/strippable_item/bounty_eva/suit
	key = STRIPPABLE_ITEM_SUIT
	slot = BOUNTY_EVA_SUIT

/datum/strippable_item/bounty_eva/mod
	key = STRIPPABLE_ITEM_BACK
	slot = BOUNTY_EVA_MOD

/datum/strippable_item/bounty_eva/get_item(atom/source)
	var/datum/component/bounty_eva/eva = source.GetComponent(/datum/component/bounty_eva)
	return eva?.piece_in(slot)

/datum/strippable_item/bounty_eva/try_equip(atom/source, obj/item/equipping, mob/user)
	. = ..()
	if(!.)
		return FALSE
	var/datum/component/bounty_eva/eva = source.GetComponent(/datum/component/bounty_eva)
	if(!eva?.fits(slot, equipping))
		to_chat(user, span_warning("[equipping] won't go on there."))
		return FALSE
	return TRUE

/datum/strippable_item/bounty_eva/start_equip(atom/source, obj/item/equipping, mob/user)
	. = ..()
	if(!.)
		return FALSE
	return do_after(user, max(equipping.equip_delay_other, 2 SECONDS), source)

/datum/strippable_item/bounty_eva/finish_equip(atom/source, obj/item/equipping, mob/user)
	var/datum/component/bounty_eva/eva = source.GetComponent(/datum/component/bounty_eva)
	if(!eva?.fits(slot, equipping) || !user.transferItemToLoc(equipping, source))
		return
	eva.set_piece(slot, equipping)
	LAZYADD(eva.fitted, equipping)
	eva.redress()
	finish_equip_mob(equipping, source, user)

/datum/strippable_item/bounty_eva/start_unequip(atom/source, mob/user)
	. = ..()
	if(!.)
		return FALSE
	return start_unequip_mob(get_item(source), source, user)

/datum/strippable_item/bounty_eva/finish_unequip(atom/source, mob/user)
	var/datum/component/bounty_eva/eva = source.GetComponent(/datum/component/bounty_eva)
	var/obj/item/piece = eva?.piece_in(slot)
	if(!piece)
		return
	// Cleared first, so the move out of their contents isn't taken for something else
	eva.set_piece(slot, null)
	LAZYREMOVE(eva.fitted, piece)
	piece.forceMove(source.drop_location())
	user.put_in_hands(piece)
	eva.redress()
	user.log_message("has stripped [key_name(source)] of [piece].", LOG_ATTACK, color="red")
	source.log_message("has been stripped of [piece] by [key_name(user)].", LOG_VICTIM, color="orange", log_globally=FALSE)

/// Whether someone hauling them by the collar (a fireman carry) isn't asking for the strip menu
/proc/bounty_eva_hauling(mob/living/body, mob/user)
	return user?.pulling == body && user.grab_state >= GRAB_AGGRESSIVE

/// Whether `user` may open its strip menu: down, cuffed, stunned or dead, and not being lifted
/mob/living/basic/bounty_criminal/proc/eva_may_strip(mob/user)
	if(hidden || bounty_eva_hauling(src, user))
		return FALSE
	return stat == DEAD || downed || is_restrained() || body_is_stunned()

// ===== COMPANIONS =====

/mob/living/basic/bounty_companion
	/// Their face, rolled once when they join
	var/datum/bounty_look/eva_look
	/// The clothes under any suit
	var/eva_base_outfit

/mob/living/basic/bounty_companion/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/bounty_eva)

/mob/living/basic/bounty_companion/Life(seconds_per_tick = SSMOBS_DT, times_fired)
	. = ..()
	var/datum/component/bounty_eva/eva = GetComponent(/datum/component/bounty_eva)
	eva?.breathe(seconds_per_tick)

/// Whether `user` may open their strip menu: out of the fight on the floor, given up, or dead
/mob/living/basic/bounty_companion/proc/eva_may_strip(mob/user)
	if(bounty_eva_hauling(src, user))
		return FALSE
	return stat != CONSCIOUS || ai_gave_up || HAS_TRAIT(src, TRAIT_FLOORED) || HAS_TRAIT(src, TRAIT_INCAPACITATED)

/**
 * Gives them a face of `species` and the clothes for `leader`'s site, suited if their criminal is.
 * Called by ai_join(). Doesn't sleep; the look goes on in the background.
 */
/mob/living/basic/bounty_companion/proc/eva_join(mob/living/basic/bounty_criminal/leader, species)
	eva_look = bounty_roll_look(species, gender)
	eva_base_outfit = bounty_companion_outfit(leader)
	var/datum/component/bounty_eva/leader_eva = leader?.GetComponent(/datum/component/bounty_eva)
	var/datum/component/bounty_eva/eva = GetComponent(/datum/component/bounty_eva)
	if(leader_eva?.sealed() && eva && !eva.sealed())
		eva.kit_up(null)
	INVOKE_ASYNC(src, PROC_REF(eva_dress))

/// Puts their look on: their face in their clothes and whatever suit they wear. Sleeps.
/mob/living/basic/bounty_companion/proc/eva_dress()
	var/datum/component/bounty_eva/eva = GetComponent(/datum/component/bounty_eva)
	var/outfit = eva ? eva.worn_outfit(eva_base_outfit) : eva_base_outfit
	if(!eva_look)
		set_outpost_npc_look(src, eva_base_outfit, gender, random_outpost_npc_look_number())
		return
	var/mob/living/carbon/human/dummy/dummy = bounty_look_dummy(eva_look, outfit, null)
	if(!dummy)
		return
	if(!QDELETED(src))
		apply_outpost_npc_look(src, dummy.appearance)
		update_appearance(UPDATE_OVERLAYS)
	qdel(dummy)

#undef BOUNTY_EVA_EXPOSURE_PERCENT
#undef BOUNTY_EVA_GASP_COOLDOWN
#undef BOUNTY_EVA_MIN_OXYGEN
#undef BOUNTY_EVA_MAX_PLASMA
#undef BOUNTY_EVA_MIN_TEMP
#undef BOUNTY_EVA_SITE_SAMPLES
#undef BOUNTY_EVA_HELMET
#undef BOUNTY_EVA_SUIT
#undef BOUNTY_EVA_MOD
