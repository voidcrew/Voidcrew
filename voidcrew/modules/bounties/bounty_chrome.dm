/**
 * # Bounty hunting: chrome
 *
 * Some criminals and their companions carry cyberware: the same chrome players buy at a ripperdoc,
 * fought the way an NPC fights. Each piece is a /datum/bounty_chrome subtype, one per key
 * (BOUNTY_CHROME_*), in voidcrew/modules/bounties/chrome/. A mob's pieces live in its
 * /datum/component/bounty_chrome, one instance each, so every piece keeps its own cooldowns.
 *
 * Who carries chrome: the record rolls it once, when it is made (bounty_roll_chrome(), more often
 * the higher the tier), so the same criminal always has the same chrome. A companion rolls its own
 * when it joins (bounty_roll_companion_chrome(), rarer, one piece at most). Nothing here drops:
 * NPC chrome is the fight, never loot.
 *
 * How it looks: a piece names the real implant organs it shows (organ_looks). The look builder puts
 * them in its dummy (bounty_dress_dummy()), so the worn chrome a player shows (a Cascade spine rig,
 * Gorilla Arms plating) shows on the NPC the same way, under the same clothes. A fugitive passing as a
 * patron shows none of it until the act drops (get_bounty_look()'s hide_chrome), and examine only
 * describes chrome that shows (bounty_chrome_on_show()).
 *
 * How it fights: the component passes the fight's moments to each piece (bounty_chrome hooks
 * below). A piece knocked out by an EMP sparks and stays down for its emp_reboot; while it is down
 * none of its hooks run.
 */

/// One prototype of every piece by key, for rolling and for the look builder. Never attached to a mob.
GLOBAL_LIST_INIT(bounty_chrome_protos, init_bounty_chrome_protos())

/proc/init_bounty_chrome_protos()
	var/list/protos = list()
	for(var/datum/bounty_chrome/chrome_type as anything in subtypesof(/datum/bounty_chrome))
		var/key = initial(chrome_type.key)
		if(key)
			protos[key] = new chrome_type
	return protos

/// Percent chance a criminal of `tier` carries chrome
/proc/bounty_chrome_tier_chance(tier)
	switch(tier)
		if(BOUNTY_TIER_MOST_WANTED)
			return BOUNTY_CHROME_CHANCE_MOST_WANTED
		if(BOUNTY_TIER_WANTED)
			return BOUNTY_CHROME_CHANCE_WANTED
	return BOUNTY_CHROME_CHANCE_PETTY

/**
 * The chrome keys a new criminal carries, or null for none: a roll by tier, then one piece (two, now
 * and then, for Wanted and up), weighted among the pieces that suit their archetype, style and kit.
 */
/proc/bounty_roll_chrome(tier, archetype, style, kit)
	// The cyberpsycho is its chrome: all of it, every time (chrome/bounty_cyberpsycho.dm)
	if(kit == BOUNTY_KIT_CYBERPSYCHO)
		return bounty_psycho_chrome_keys()
	if(!prob(bounty_chrome_tier_chance(tier)))
		return null
	var/count = (tier >= BOUNTY_TIER_WANTED && prob(BOUNTY_CHROME_SECOND_CHANCE)) ? 2 : 1
	return bounty_pick_chrome(count, tier, archetype, style, kit)

/**
 * The chrome a new companion of a `tier` criminal carries, as a list of one key, or null: rarer than
 * its criminal's, one piece at most, and never Lazarus. A companion gives up to a stamina takedown, and
 * a jolt standing it back up would take away the answer that works on every companion.
 */
/proc/bounty_roll_companion_chrome(tier, style)
	var/static/list/never_on_companions = list(BOUNTY_CHROME_LAZARUS)
	if(!prob(bounty_chrome_tier_chance(tier) / BOUNTY_CHROME_COMPANION_DIVISOR))
		return null
	return bounty_pick_chrome(1, tier, BOUNTY_CHROME_COMPANION, style, null, never_on_companions)

/// Up to `count` different keys, weighted, among the pieces that suit them and aren't in `excluded`. Null if none suit.
/proc/bounty_pick_chrome(count, tier, archetype, style, kit, list/excluded)
	var/list/picked = list()
	for(var/i in 1 to count)
		var/list/weights = list()
		for(var/key in GLOB.bounty_chrome_protos)
			if(excluded && (key in excluded))
				continue
			var/datum/bounty_chrome/proto = GLOB.bounty_chrome_protos[key]
			if(!(key in picked) && proto.weight > 0 && proto.can_roll(tier, archetype, style, kit, picked))
				weights[key] = proto.weight
		if(!length(weights))
			break
		picked += pick_weight(weights)
	return length(picked) ? picked : null

/**
 * The organ typepaths the look builder puts in a dummy for chrome `keys`. A slot holds one implant, as
 * on a player, so the first piece listed for a slot keeps it (a second would evict the first as it
 * goes in). Arms are shared out: with two pieces that each take both arms (Mantis Blades and Gorilla
 * Arms), the first listed keeps its right arm and the second gets its left, and any more get none.
 */
/proc/bounty_chrome_organ_looks(list/keys)
	var/list/organs = list()
	var/list/slots_taken = list()
	var/list/arm_sharers = list()
	for(var/key in keys)
		var/datum/bounty_chrome/proto = GLOB.bounty_chrome_protos[key]
		if(proto && bounty_chrome_takes_both_arms(proto.organ_looks))
			arm_sharers += key
	var/sharing = length(arm_sharers) > 1
	for(var/key in keys)
		var/datum/bounty_chrome/proto = GLOB.bounty_chrome_protos[key]
		if(!proto?.organ_looks)
			continue
		var/sharer = sharing ? arm_sharers.Find(key) : 0
		for(var/obj/item/organ/organ_type as anything in proto.organ_looks)
			if(sharer)
				var/zone = initial(organ_type.zone)
				if((zone == BODY_ZONE_R_ARM && sharer != 1) || (zone == BODY_ZONE_L_ARM && sharer != 2))
					continue
			var/slot = initial(organ_type.slot)
			if(slot)
				if(slots_taken[slot])
					continue
				slots_taken[slot] = TRUE
			organs |= organ_type
	return organs

/// Whether `organ_types` put chrome on both arms
/proc/bounty_chrome_takes_both_arms(list/organ_types)
	var/right = FALSE
	var/left = FALSE
	for(var/obj/item/organ/organ_type as anything in organ_types)
		switch(initial(organ_type.zone))
			if(BODY_ZONE_R_ARM)
				right = TRUE
			if(BODY_ZONE_L_ARM)
				left = TRUE
	return right && left

/**
 * Puts the real implants `organ_types` in a look dummy, so its worn chrome draws as a player's does.
 * Special insertion: no surgery, no capacity check, no boot splash. Anything that won't go in is
 * deleted and skipped.
 */
/proc/bounty_chrome_dress_dummy(mob/living/carbon/human/dummy/dummy, list/organ_types)
	for(var/organ_type in organ_types)
		var/obj/item/organ/organ = new organ_type
		if(!organ.Insert(dummy, special = TRUE))
			qdel(organ)

/**
 * Strips `dummy`'s clothes off the worn chrome in `organ_types`, so it shows: arm and chest chrome
 * lose the jacket (and arm chrome the gloves), and the jumpsuit is rolled down to the waist, or
 * swapped for trousers when it can't be; leg chrome loses the shoes and trousers (shorts go on). A pressure suit or a modsuit stays on, and so does what is under it: the
 * air would kill them.
 */
/proc/bounty_chrome_expose(mob/living/carbon/human/dummy/dummy, list/organ_types)
	var/arms = FALSE
	var/chest = FALSE
	var/legs = FALSE
	for(var/organ_type in organ_types)
		var/obj/item/organ/cyberimp/implant = organ_type
		if(!ispath(organ_type, /obj/item/organ/cyberimp) || !initial(implant.aug_overlay))
			continue
		switch(initial(implant.zone))
			if(BODY_ZONE_R_ARM, BODY_ZONE_L_ARM)
				arms = TRUE
			if(BODY_ZONE_CHEST)
				chest = TRUE
			if(BODY_ZONE_R_LEG, BODY_ZONE_L_LEG)
				legs = TRUE
	if(!arms && !chest && !legs)
		return
	var/obj/item/clothing/suit = dummy.wear_suit
	if((istype(suit) && (suit.clothing_flags & STOPSPRESSUREDAMAGE)) || istype(dummy.back, /obj/item/mod/control))
		return
	if(suit && (arms || chest))
		bounty_chrome_take_off(dummy, suit)
	if(arms && dummy.gloves)
		bounty_chrome_take_off(dummy, dummy.gloves)
	if(legs && dummy.shoes)
		bounty_chrome_take_off(dummy, dummy.shoes)
	if(!arms && !chest && !legs)
		return
	// Arm or chest chrome: a jumpsuit rolled down to the waist, the way a player wears one
	var/obj/item/clothing/under/uniform = dummy.w_uniform
	if(!legs && istype(uniform) && uniform.can_adjust && !uniform.alt_covers_chest && uniform.adjusted == NORMAL_STYLE)
		uniform.toggle_jumpsuit_adjust()
		dummy.update_worn_undersuit()
		return
	// Trousers for chest or arm chrome, shorts for leg chrome: the belt goes back on over them
	var/static/list/trousers = list(/obj/item/clothing/under/pants/jeans, /obj/item/clothing/under/pants/camo, /obj/item/clothing/under/pants/track)
	var/static/list/shorts = list(/obj/item/clothing/under/shorts/jeanshorts, /obj/item/clothing/under/shorts/black, /obj/item/clothing/under/shorts/grey)
	var/obj/item/belt = dummy.belt
	if(belt)
		dummy.temporarilyRemoveItemFromInventory(belt, force = TRUE)
	if(dummy.w_uniform)
		bounty_chrome_take_off(dummy, dummy.w_uniform)
	var/bottoms = pick(legs ? shorts : trousers)
	dummy.equip_to_slot_or_del(new bottoms(dummy), ITEM_SLOT_ICLOTHING, initial = TRUE)
	if(belt && !QDELETED(belt) && !dummy.equip_to_slot_if_possible(belt, ITEM_SLOT_BELT, disable_warning = TRUE, initial = TRUE))
		qdel(belt)

/// Takes `thing` off a look dummy and deletes it
/proc/bounty_chrome_take_off(mob/living/carbon/human/dummy/dummy, obj/item/thing)
	dummy.temporarilyRemoveItemFromInventory(thing, force = TRUE)
	qdel(thing)

/// Gives `fighter` (a criminal or a companion) the pieces `keys`, adding to any it has, and the health they bring (bounty_chrome_fit_health()). For spawning and for admins.
/proc/bounty_chrome_install(mob/living/basic/fighter, list/keys)
	if(QDELETED(fighter) || !length(keys))
		return null
	var/datum/component/bounty_chrome/chrome = fighter.GetComponent(/datum/component/bounty_chrome)
	if(chrome)
		chrome.install(keys)
	else
		chrome = fighter.AddComponent(/datum/component/bounty_chrome, keys)
	bounty_chrome_fit_health(fighter)
	return chrome

/**
 * How much tougher its chrome makes `fighter`: BOUNTY_CHROME_HEALTH_PER_PIECE more for each piece, as
 * a multiplier on the rest of its health (body_tier_health(), ai_style_health()), for a normal
 * criminal or a companion.
 * A criminal counts its record's chrome too, so its health is right before the pieces go in. A
 * mini-boss's health is its kit's table: 1.
 */
/proc/bounty_chrome_health_mult(mob/living/basic/fighter)
	if(!istype(fighter, /mob/living/basic/bounty_criminal/normal) && !istype(fighter, /mob/living/basic/bounty_companion))
		return 1
	var/list/keys = list()
	var/mob/living/basic/bounty_criminal/criminal = fighter
	if(istype(criminal) && length(criminal.record?.chrome))
		keys |= criminal.record.chrome
	var/datum/component/bounty_chrome/chrome = fighter.GetComponent(/datum/component/bounty_chrome)
	if(chrome)
		keys |= chrome.keys()
	return 1 + length(keys) * BOUNTY_CHROME_HEALTH_PER_PIECE

/**
 * Raises `fighter`'s max health to what its tier, style and chrome give it now, as chrome goes in.
 * Never lowers it, and never heals: a fighter already hurt keeps the health it has and only its ceiling
 * rises (a fresh one rises with it). The zone's health factor stays on top. TRUE if it rose.
 */
/proc/bounty_chrome_fit_health(mob/living/basic/fighter)
	if(QDELETED(fighter) || fighter.stat == DEAD)
		return FALSE
	var/raw
	if(istype(fighter, /mob/living/basic/bounty_criminal/normal))
		var/mob/living/basic/bounty_criminal/criminal = fighter
		raw = criminal.body_tier_health()
	else if(istype(fighter, /mob/living/basic/bounty_companion))
		var/mob/living/basic/bounty_companion/companion = fighter
		raw = companion.ai_style_health(bounty_ai_style(companion))
	if(!raw)
		return FALSE
	var/wanted = fighter.npc_zone_applied ? raw * fighter.npc_zone_health_factor : raw
	var/old_max = fighter.maxHealth
	if(wanted <= old_max)
		return FALSE
	var/hurt = fighter.health < old_max
	if(fighter.npc_zone_applied)
		fighter.npc_zone_original_max_health = raw
	fighter.setMaxHealth(wanted)
	// Basic mobs keep all their damage as bruteloss: more of it keeps their health where it was
	if(hurt)
		fighter.bruteloss += wanted - old_max
	fighter.updatehealth()
	if(istype(fighter, /mob/living/basic/bounty_criminal))
		var/mob/living/basic/bounty_criminal/criminal = fighter
		criminal.body_update_stamina_coeff()
	return TRUE

/// A piece `fighter` carries, by key, or null
/proc/bounty_chrome_piece(mob/living/basic/fighter, key)
	var/datum/component/bounty_chrome/chrome = fighter?.GetComponent(/datum/component/bounty_chrome)
	return chrome?.pieces[key]

/// Whether a piece `fighter` carries makes their ordinary blow its own now (blades out, empowered fists), so their style's extras (a brawler's shove, a bat's knock-back) stay out of it
/proc/bounty_chrome_owns_blow(mob/living/basic/fighter)
	var/datum/component/bounty_chrome/chrome = fighter?.GetComponent(/datum/component/bounty_chrome)
	if(!chrome)
		return FALSE
	for(var/datum/bounty_chrome/piece as anything in chrome.online_pieces())
		if(piece.owns_blow())
			return TRUE
	return FALSE

/**
 * Puts `fighter` on a style its chrome fights with: theirs if it is one of `allowed` (BOUNTY_STYLE_*),
 * otherwise `fallback`. Chrome that is a blade or a fist never comes with a gun or a bottle, however
 * it was installed (an admin's pick, all of it at once). A criminal's record is fixed too, as its AI
 * keeps to the record, and its health follows the new style. A meek criminal and a mini-boss keep
 * their own ways. Returns TRUE if the style changed.
 */
/proc/bounty_chrome_fit_style(mob/living/basic/fighter, list/allowed, fallback)
	if(QDELETED(fighter) || !GLOB.bounty_styles[fallback])
		return FALSE
	if(istype(fighter, /mob/living/basic/bounty_criminal/normal))
		var/mob/living/basic/bounty_criminal/normal/criminal = fighter
		if(!criminal.record || (criminal.ai_wanted_style() in allowed))
			return FALSE
		criminal.record.style = fallback
		var/health = criminal.body_tier_health()
		if(health)
			criminal.maxHealth = health
			criminal.updatehealth()
		criminal.body_update_stamina_coeff()
		criminal.ai_update_style()
		// A gun already in hand goes, for the style's own weapon if they are fighting
		if(criminal.ai_hand)
			bounty_ai_hold(criminal, criminal.ai_mode == BOUNTY_AI_FIGHTING ? bounty_ai_held_look(criminal) : null)
		return TRUE
	if(istype(fighter, /mob/living/basic/bounty_companion))
		var/mob/living/basic/bounty_companion/companion = fighter
		if(bounty_ai_style(companion)?.key in allowed)
			return FALSE
		companion.ai_take_style(fallback)
		if(companion.ai_hand)
			bounty_ai_hold(companion, companion.ai_in_fight ? bounty_ai_held_look(companion) : null)
		return TRUE
	return FALSE

/// Whether `fighter` is in a fight it can take part in: a criminal fighting, a companion that hasn't broken, a hostile mini-boss able to act
/proc/bounty_chrome_fighting(mob/living/basic/fighter)
	if(istype(fighter, /mob/living/basic/bounty_criminal/boss))
		var/mob/living/basic/bounty_criminal/boss/boss = fighter
		return boss.boss_hostile && boss.boss_can_act()
	return bounty_ai_fighting(fighter)

/// What `fighter` is fighting now, or null
/proc/bounty_chrome_target(mob/living/basic/fighter)
	var/datum/ai_controller/controller = fighter?.ai_controller
	if(QDELETED(controller))
		return null
	return controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET] || controller.blackboard[BB_BOUNTY_BOSS_PREY]

// ===== THE COMPONENT =====

/**
 * A fighter's chrome: one /datum/bounty_chrome per piece, and the hooks that drive them. Fight start,
 * the tick and the downed moment are called by the AI (bounty_ai_normal.dm, bounty_companions.dm,
 * bounty_boss.dm, bounty_criminal.dm); hits, shots, damage, EMPs, death and examine come by signal,
 * so they work for every kind of fighter.
 */
/datum/component/bounty_chrome
	/// Key -> its /datum/bounty_chrome, in install order
	var/list/pieces = list()
	/// Running after they tell off someone reading their chrome (bounty_chrome_read_noticed())
	COOLDOWN_DECLARE(read_noticed)

/datum/component/bounty_chrome/Initialize(list/keys)
	if(!istype(parent, /mob/living/basic/bounty_criminal) && !istype(parent, /mob/living/basic/bounty_companion))
		return COMPONENT_INCOMPATIBLE
	install(keys)

/datum/component/bounty_chrome/Destroy(force)
	for(var/key in pieces)
		var/datum/bounty_chrome/piece = pieces[key]
		piece.detach()
		qdel(piece)
	pieces.Cut()
	return ..()

/datum/component/bounty_chrome/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATOM_EMP_ACT, PROC_REF(on_emp))
	RegisterSignal(parent, COMSIG_ATOM_EXAMINE, PROC_REF(on_examine))
	RegisterSignal(parent, COMSIG_HOSTILE_POST_ATTACKINGTARGET, PROC_REF(on_melee_hit))
	RegisterSignal(parent, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE, PROC_REF(on_fire))
	RegisterSignal(parent, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS, PROC_REF(on_damage_modifiers))
	RegisterSignal(parent, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(on_damaged))
	RegisterSignal(parent, COMSIG_LIVING_DEATH, PROC_REF(on_death))
	RegisterSignal(parent, COMSIG_BOUNTY_CRIMINAL_DOWNED, PROC_REF(on_downed_signal))

/datum/component/bounty_chrome/UnregisterFromParent()
	UnregisterSignal(parent, list(
		COMSIG_ATOM_EMP_ACT,
		COMSIG_ATOM_EXAMINE,
		COMSIG_HOSTILE_POST_ATTACKINGTARGET,
		COMSIG_PROJECTILE_FIRER_BEFORE_FIRE,
		COMSIG_MOB_APPLY_DAMAGE_MODIFIERS,
		COMSIG_MOB_APPLY_DAMAGE,
		COMSIG_LIVING_DEATH,
		COMSIG_BOUNTY_CRIMINAL_DOWNED,
	))

/// Adds the pieces `keys` it doesn't have yet
/datum/component/bounty_chrome/proc/install(list/keys)
	for(var/key in keys)
		if(pieces[key])
			continue
		var/datum/bounty_chrome/proto = GLOB.bounty_chrome_protos[key]
		if(!proto)
			stack_trace("Unknown bounty chrome [key]")
			continue
		var/datum/bounty_chrome/piece = new proto.type
		pieces[key] = piece
		piece.attach(parent)

/// The keys it carries
/datum/component/bounty_chrome/proc/keys()
	var/list/keys = list()
	for(var/key in pieces)
		keys += key
	return keys

/// Each working piece, in install order
/datum/component/bounty_chrome/proc/online_pieces()
	var/list/online = list()
	for(var/key in pieces)
		var/datum/bounty_chrome/piece = pieces[key]
		if(piece.online())
			online += piece
	return online

/// A fight starts against `target`. Called by the AI; may sleep nothing.
/datum/component/bounty_chrome/proc/fight_started(atom/target)
	for(var/datum/bounty_chrome/piece as anything in online_pieces())
		piece.on_fight_start(target)

/// Every Life tick, fighting or not
/datum/component/bounty_chrome/proc/tick(seconds_per_tick)
	var/fighting = bounty_chrome_fighting(parent)
	for(var/key in pieces)
		var/datum/bounty_chrome/piece = pieces[key]
		piece.check_reboot()
		if(piece.online())
			piece.on_tick(seconds_per_tick, fighting)

/// Down at the downed line (a criminal) or gave up (a companion)
/datum/component/bounty_chrome/proc/downed()
	for(var/datum/bounty_chrome/piece as anything in online_pieces())
		piece.on_downed()

/datum/component/bounty_chrome/proc/on_downed_signal(datum/source)
	SIGNAL_HANDLER
	INVOKE_ASYNC(src, PROC_REF(downed))

/datum/component/bounty_chrome/proc/on_melee_hit(datum/source, atom/target, result)
	SIGNAL_HANDLER
	if(!result || !isliving(target))
		return
	for(var/datum/bounty_chrome/piece as anything in online_pieces())
		INVOKE_ASYNC(piece, TYPE_PROC_REF(/datum/bounty_chrome, on_melee_hit), target)

/datum/component/bounty_chrome/proc/on_fire(datum/source, obj/projectile/shot, atom/fired_from, atom/original)
	SIGNAL_HANDLER
	for(var/datum/bounty_chrome/piece as anything in online_pieces())
		piece.on_fire(shot, original)

/datum/component/bounty_chrome/proc/on_damage_modifiers(datum/source, list/damage_mods, damage, damagetype, def_zone, sharpness, attack_direction, obj/item/attacking_item)
	SIGNAL_HANDLER
	for(var/datum/bounty_chrome/piece as anything in online_pieces())
		piece.modify_damage(damage_mods, damage, damagetype)

/datum/component/bounty_chrome/proc/on_damaged(datum/source, damage, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, attacking_item)
	SIGNAL_HANDLER
	for(var/datum/bounty_chrome/piece as anything in online_pieces())
		piece.on_damaged(damage, damagetype)

/datum/component/bounty_chrome/proc/on_death(datum/source, gibbed)
	SIGNAL_HANDLER
	for(var/key in pieces)
		var/datum/bounty_chrome/piece = pieces[key]
		piece.on_death()

/datum/component/bounty_chrome/proc/on_emp(datum/source, severity, protection)
	SIGNAL_HANDLER
	if(protection & EMP_PROTECT_SELF)
		return
	// The malfunction shows for as long as the longest piece it knocked out stays down
	var/longest = 0
	for(var/key in pieces)
		var/datum/bounty_chrome/piece = pieces[key]
		if(piece.emp(severity))
			longest = max(longest, piece.emp_reboot)
	if(longest)
		var/mob/living/fighter = parent
		bounty_chrome_malfunction_fx(fighter, longest)
		fighter.visible_message(span_warning("[fighter]'s chrome sparks and stutters!"))

/**
 * What their chrome looks like up close, while it shows (bounty_chrome_on_show()). Dead, it is burnt
 * out, as all NPC chrome is. Knocked out by an EMP, it sparks. Each line starts with a capital,
 * whatever placeholder it starts with.
 */
/datum/component/bounty_chrome/proc/on_examine(datum/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	var/mob/living/basic/fighter = parent
	if(!bounty_chrome_on_show(fighter))
		return
	if(fighter.stat == DEAD)
		examine_list += span_warning("[fighter.p_Their()] chrome is burnt out.")
		return
	var/sparking = FALSE
	for(var/key in pieces)
		var/datum/bounty_chrome/piece = pieces[key]
		if(piece.offline_until)
			sparking = TRUE
		var/line = piece.examine_line()
		if(line)
			examine_list += span_warning(capitalize(replacetext(replacetext(line, "%THEIR", fighter.p_their()), "%THEY", fighter.p_they())))
	if(sparking)
		examine_list += span_warning("Sparks crawl over [fighter.p_their()] chrome.")

/**
 * Whether someone looking at `fighter` can see its chrome: not while it passes as a patron or hides
 * (a trader-outpost fugitive keeps it under the patron's clothes, as its decoys have none), and not
 * through a pressure suit or a modsuit.
 */
/proc/bounty_chrome_on_show(mob/living/basic/fighter)
	if(QDELETED(fighter))
		return FALSE
	var/mob/living/basic/bounty_criminal/criminal = fighter
	if(istype(criminal) && (criminal.blended || criminal.hidden))
		return FALSE
	var/datum/component/bounty_eva/eva = fighter.GetComponent(/datum/component/bounty_eva)
	if(eva && (!QDELETED(eva.suit) || !QDELETED(eva.mod)))
		return FALSE
	return TRUE

// ===== A MALFUNCTION =====

/**
 * Shows `fighter`'s chrome malfunctioning for `duration`: arcs crawling over the body, tg's EMP
 * sparkle, a flickering chrome-blue outline and light, twitches, and sparks spat onto the tiles around
 * them with a crackle. Only a picture: nothing is hurt, set alight or switched off by it. An EMP that
 * knocks chrome out shows it (/datum/component/bounty_chrome/proc/on_emp()); a longer one extends it.
 */
/proc/bounty_chrome_malfunction_fx(mob/living/fighter, duration)
	if(QDELETED(fighter) || fighter.stat == DEAD || duration <= 0)
		return null
	return fighter.apply_status_effect(/datum/status_effect/bounty_chrome_malfunction, duration)

/// The arcs over a malfunctioning body, and their glow in the dark when `fighter` is given. For the overlay and the renders.
/proc/bounty_chrome_malfunction_arcs(atom/fighter)
	. = list()
	var/mutable_appearance/arcs = mutable_appearance('icons/effects/effects.dmi', "electricity", ABOVE_MOB_LAYER)
	arcs.color = BOUNTY_CHROME_MALFUNCTION_MATRIX
	. += arcs
	. += mutable_appearance('icons/effects/effects.dmi', "empdisable", ABOVE_MOB_LAYER)
	if(fighter)
		. += emissive_appearance('icons/effects/effects.dmi', "electricity", fighter)

/**
 * A fighter's chrome malfunctioning: the look of bounty_chrome_malfunction_fx(), for its duration.
 * Purely visual. It ends early if they die.
 */
/datum/status_effect/bounty_chrome_malfunction
	id = "bounty_chrome_malfunction"
	duration = BOUNTY_CHROME_EMP_REBOOT
	tick_interval = BOUNTY_CHROME_MALFUNCTION_PULSE
	status_type = STATUS_EFFECT_REFRESH
	alert_type = null
	/// The arcs and the sparkle on the body
	var/list/arcs
	/// The flickering light they give off
	var/obj/effect/dummy/lighting_obj/moblight/glow

/datum/status_effect/bounty_chrome_malfunction/on_creation(mob/living/new_owner, new_duration)
	if(new_duration > 0)
		duration = new_duration
	return ..()

/datum/status_effect/bounty_chrome_malfunction/refresh(effect, new_duration)
	duration = max(duration, world.time + max(new_duration, 0))

/datum/status_effect/bounty_chrome_malfunction/on_apply()
	if(owner.stat == DEAD)
		return FALSE
	arcs = bounty_chrome_malfunction_arcs(owner)
	owner.add_overlay(arcs)
	owner.add_filter(BOUNTY_CHROME_MALFUNCTION_FILTER, 3, outline_filter(1, BOUNTY_CHROME_MALFUNCTION_COLOR))
	var/outline = owner.get_filter(BOUNTY_CHROME_MALFUNCTION_FILTER)
	if(outline)
		// A flicker, never steady
		animate(outline, color = "#7fd4ff20", time = 0.1 SECONDS, loop = -1)
		animate(color = "#7fd4ffff", time = 0.1 SECONDS)
		animate(color = "#7fd4ff60", time = 0.2 SECONDS)
		animate(color = "#c8f0ffff", time = 0.1 SECONDS)
	glow = owner.mob_light(2, 1, BOUNTY_CHROME_MALFUNCTION_COLOR)
	playsound(owner, 'sound/effects/empulse.ogg', 40, TRUE)
	playsound(owner, SFX_SPARKS, 60, TRUE)
	pulse()
	return TRUE

/datum/status_effect/bounty_chrome_malfunction/tick(seconds_between_ticks)
	if(owner.stat == DEAD)
		qdel(src)
		return
	pulse()

/// One beat of it: a twitch, sparks spat onto a tile or two around them, a crackle, the light jumping
/datum/status_effect/bounty_chrome_malfunction/proc/pulse()
	if(prob(60))
		owner.Shake(rand(1, 2), rand(0, 1), 0.2 SECONDS)
	glow?.set_light_power(pick(0.4, 1, 1.6))
	var/turf/here = get_turf(owner)
	if(!here)
		return
	var/list/spots = list()
	for(var/turf/spot as anything in RANGE_TURFS(1, here))
		if(spot != here && !isclosedturf(spot))
			spots += spot
	for(var/i in 1 to rand(1, 2))
		if(!length(spots))
			break
		var/turf/spot = pick_n_take(spots)
		new /obj/effect/temp_visual/bounty_chrome_spark(spot, (here.x - spot.x) * ICON_SIZE_X / 2, (here.y - spot.y) * ICON_SIZE_Y / 2)
	if(prob(50))
		playsound(owner, SFX_SPARKS, 35, TRUE, SILENCED_SOUND_EXTRARANGE)

/datum/status_effect/bounty_chrome_malfunction/on_remove()
	if(arcs)
		owner.cut_overlay(arcs)
	arcs = null
	owner.remove_filter(BOUNTY_CHROME_MALFUNCTION_FILTER)
	QDEL_NULL(glow)

/datum/status_effect/bounty_chrome_malfunction/Destroy()
	QDEL_NULL(glow)
	return ..()

/// Sparks flung from a malfunctioning body onto a tile beside it: tg's spark art, and nothing else. Starts `from_x`, `from_y` pixels back toward the body.
/obj/effect/temp_visual/bounty_chrome_spark
	icon = 'icons/effects/effects.dmi'
	icon_state = "sparks"
	layer = ABOVE_MOB_LAYER
	duration = 0.5 SECONDS
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/obj/effect/temp_visual/bounty_chrome_spark/Initialize(mapload, from_x = 0, from_y = 0)
	. = ..()
	setDir(pick(GLOB.cardinals))
	pixel_x = from_x
	pixel_y = from_y
	animate(src, pixel_x = 0, pixel_y = 0, time = 0.2 SECONDS, easing = QUAD_EASING | EASE_OUT)
	animate(alpha = 0, time = 0.3 SECONDS)

// ===== A PIECE =====

/**
 * One piece of chrome on one fighter. Subtypes (voidcrew/modules/bounties/chrome/) set what it is
 * and override the hooks they need. The prototype in GLOB.bounty_chrome_protos is never attached;
 * a fighter's own piece is made from its type in /datum/component/bounty_chrome/proc/install().
 *
 * Hooks are only called while the piece is online (not EMP'd, its owner alive). The fight hooks
 * must not sleep unless they say they may; use timers or INVOKE_ASYNC for anything slow.
 */
/datum/bounty_chrome
	/// BOUNTY_CHROME_*; the subtype with no key is abstract
	var/key
	/// What it is called: the implant's own name
	var/name = "chrome"
	/// Roll weight among the pieces that suit
	var/weight = 10
	/// Lowest tier that can roll it (BOUNTY_TIER_*); a companion is checked against its criminal's tier
	var/min_tier = BOUNTY_TIER_PETTY
	/// The archetypes that can roll it: BOUNTY_ARCHETYPE_* and BOUNTY_CHROME_COMPANION
	var/list/archetypes = list(BOUNTY_ARCHETYPE_NORMAL, BOUNTY_ARCHETYPE_BOSS, BOUNTY_CHROME_COMPANION)
	/// The fighting styles (BOUNTY_STYLE_*) that can roll it, or null for any style. Mini-bosses have no style.
	var/list/styles
	/// The mini-boss kits (BOUNTY_KIT_*) that can roll it, or null for any kit
	var/list/kits
	/// Keys it never rolls alongside
	var/list/exclusive_with
	/// The real implant organs the look builder puts on their body, so the worn chrome shows
	var/list/organ_looks
	/// The real implant a chrome read (cyber optics) names it as: its name and tier come off this type
	var/scan_organ
	/// What examining them shows, or null for nothing (chrome under the skin). %THEIR and %THEY are replaced.
	var/examine_text
	/// How long it stays down after an EMP
	var/emp_reboot = BOUNTY_CHROME_EMP_REBOOT
	/// The fighter it is in, while attached
	var/mob/living/basic/owner
	/// world.time it comes back from an EMP; 0 while it isn't down
	var/offline_until = 0

/datum/bounty_chrome/Destroy(force)
	owner = null
	return ..()

/// Whether a new `archetype` fighter of `tier`, with `style` or `kit` and the pieces `picked` so far, may roll it
/datum/bounty_chrome/proc/can_roll(tier, archetype, style, kit, list/picked)
	if(tier < min_tier || !(archetype in archetypes))
		return FALSE
	if(styles && !(style in styles))
		return FALSE
	if(kits && kit && !(kit in kits))
		return FALSE
	for(var/other in picked)
		if(other in exclusive_with)
			return FALSE
		var/datum/bounty_chrome/other_proto = GLOB.bounty_chrome_protos[other]
		if(key in other_proto?.exclusive_with)
			return FALSE
	return TRUE

/// Goes into `fighter`. Subtypes add their abilities, signals and looks here; call parent first.
/datum/bounty_chrome/proc/attach(mob/living/basic/fighter)
	owner = fighter

/// Comes out of its fighter, which may be being deleted. Undo everything attach() and the fight did; call parent last.
/datum/bounty_chrome/proc/detach()
	owner = null

/// Working: attached, its owner alive, not down from an EMP
/datum/bounty_chrome/proc/online()
	return owner && owner.stat != DEAD && !offline_until

/// Brings it back once its EMP reboot is over
/datum/bounty_chrome/proc/check_reboot()
	if(!offline_until || world.time < offline_until)
		return
	offline_until = 0
	on_reboot()

/// Hit by an EMP of `severity`: it goes down for emp_reboot, cutting off whatever it was doing. TRUE if it was knocked out now.
/datum/bounty_chrome/proc/emp(severity)
	if(!owner || owner.stat == DEAD || offline_until)
		return FALSE
	offline_until = world.time + emp_reboot
	on_emp(severity)
	return TRUE

// ----- hooks for subtypes -----

/// A fight starts against `target`
/datum/bounty_chrome/proc/on_fight_start(atom/target)
	return

/// Every Life tick while online; `fighting` is bounty_chrome_fighting()
/datum/bounty_chrome/proc/on_tick(seconds_per_tick, fighting)
	return

/// Their blow landed on `target`. Called async: may sleep.
/datum/bounty_chrome/proc/on_melee_hit(mob/living/target)
	return

/// They are about to fire `shot` at `original` (a gun's round or a thrown bottle). Inside a signal handler: must not sleep.
/datum/bounty_chrome/proc/on_fire(obj/projectile/shot, atom/original)
	return

/// They are about to take `damage` of `damagetype`: add multipliers to `damage_mods` (tg's COMSIG_MOB_APPLY_DAMAGE_MODIFIERS). Must not sleep.
/datum/bounty_chrome/proc/modify_damage(list/damage_mods, damage, damagetype)
	return

/// They took `damage` of `damagetype`. Must not sleep.
/datum/bounty_chrome/proc/on_damaged(damage, damagetype)
	return

/// Down at the downed line (a criminal) or gave up (a companion). Called async: may sleep.
/datum/bounty_chrome/proc/on_downed()
	return

/// They died: end anything running. Called whether or not it is online. Must not sleep.
/datum/bounty_chrome/proc/on_death()
	return

/// An EMP knocked it out: end anything running now. Must not sleep.
/datum/bounty_chrome/proc/on_emp(severity)
	return

/// It came back from an EMP
/datum/bounty_chrome/proc/on_reboot()
	return

/// What examining them shows, or null
/datum/bounty_chrome/proc/examine_line()
	return examine_text

/// Whether their ordinary blow is this piece's now, in place of their style's extras (bounty_chrome_owns_blow()). Must not sleep.
/datum/bounty_chrome/proc/owns_blow()
	return FALSE

// ===== A CHROME READ =====

// The implant each piece reads as through cyber optics (cyberware_scan.dm)
/datum/bounty_chrome/cascade
	scan_organ = /obj/item/organ/cyberimp/cyberware/cascade
/datum/bounty_chrome/mantis
	scan_organ = /obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis
/datum/bounty_chrome/gorilla
	scan_organ = /obj/item/organ/cyberimp/cyberware/gorilla_arms
/datum/bounty_chrome/redline
	scan_organ = /obj/item/organ/cyberimp/cyberware/redline
/datum/bounty_chrome/piledriver
	scan_organ = /obj/item/organ/cyberimp/cyberware/piledriver
/datum/bounty_chrome/lazarus
	scan_organ = /obj/item/organ/cyberimp/cyberware/lazarus
/datum/bounty_chrome/deadeye
	scan_organ = /obj/item/organ/eyes/robotic/cyberware/deadeye

/// What a chrome read calls an implant type: list(name, tier), read once off a copy and kept
/proc/bounty_chrome_scan_info(organ_type)
	var/static/list/cache = list()
	if(!ispath(organ_type, /obj/item/organ))
		return null
	if(!cache[organ_type])
		var/obj/item/organ/ware = new organ_type
		var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
		cache[organ_type] = list(ware.name, chrome?.tier)
		qdel(ware)
	return cache[organ_type]

/**
 * A chrome read of a bounty criminal or companion, in the same words cyber optics use for a body
 * (cyberware_scan_readout()), or null if `target` isn't one. Each piece reads as its real implant, in
 * its tier's colour; a piece down from an EMP, and all of it on a corpse, reads OFFLINE. Someone
 * passing as a patron reads as clean.
 */
/proc/bounty_chrome_scan_readout(mob/living/target, resolution = CYBERWARE_SCAN_ITEMIZED)
	if(!istype(target, /mob/living/basic/bounty_criminal) && !istype(target, /mob/living/basic/bounty_companion))
		return null
	var/accent = CYBERWARE_COLOR_TIER_2
	var/list/lines = list(cyberware_scan_line("CHROME READ: [uppertext(target.name)]", accent))
	var/datum/component/bounty_chrome/chrome = target.GetComponent(/datum/component/bounty_chrome)
	var/mob/living/basic/bounty_criminal/criminal = target
	if(!length(chrome?.pieces) || (istype(criminal) && criminal.blended))
		lines += cyberware_scan_line("NO HARDWARE SIGNATURE", accent)
		return lines
	lines += cyberware_scan_line("SIGNATURES [length(chrome.pieces)]", accent)
	if(resolution < CYBERWARE_SCAN_ITEMIZED)
		lines += cyberware_scan_line("BUS RESOLUTION TOO LOW: IDENTITIES UNRESOLVED", accent)
		return lines
	var/dead = target.stat == DEAD
	for(var/key in chrome.pieces)
		var/datum/bounty_chrome/piece = chrome.pieces[key]
		var/list/info = bounty_chrome_scan_info(piece.scan_organ)
		var/ware_name = info ? info[1] : piece.name
		var/tier = info ? info[2] : null
		var/status = (dead || piece.offline_until) ? " · OFFLINE" : ""
		// The colour carries the tier; only hardware the bus can't rate says so
		var/rating = tier ? "" : " · UNRATED"
		lines += cyberware_scan_line("» [uppertext(ware_name)][rating][status]", tier ? cyberware_tier_color(tier) : accent)
	return lines

/// What a fighter says to someone reading their chrome
GLOBAL_LIST_INIT(bounty_chrome_read_lines, list(
	"Get out of my head.",
	"Stop reading me, creep.",
	"Quit scanning me.",
	"Eyes off my chrome.",
))

/**
 * `reader` just read `fighter`'s chrome with cyber optics. They feel it, as anyone with chrome does:
 * one who isn't fighting turns to the reader and tells them off. Not while passing as a patron or
 * hiding (the read finds nothing then), and at most once every BOUNTY_CHROME_READ_NOTICE_COOLDOWN.
 * Returns TRUE if they answered. Doesn't sleep.
 */
/proc/bounty_chrome_read_noticed(mob/living/basic/fighter, mob/living/reader)
	var/datum/component/bounty_chrome/chrome = fighter?.GetComponent(/datum/component/bounty_chrome)
	if(!chrome || !length(chrome.pieces) || !isliving(reader) || reader == fighter || !COOLDOWN_FINISHED(chrome, read_noticed))
		return FALSE
	if(fighter.stat != CONSCIOUS || fighter.client || fighter.mind || bounty_chrome_fighting(fighter))
		return FALSE
	var/mob/living/basic/bounty_criminal/criminal = fighter
	if(istype(criminal) && (criminal.blended || criminal.hidden))
		return FALSE
	COOLDOWN_START(chrome, read_noticed, BOUNTY_CHROME_READ_NOTICE_COOLDOWN)
	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(bounty_chrome_answer_read), fighter, reader)
	return TRUE

/// `fighter` looks round at `reader` and says something about being read. Sleeps (say()).
/proc/bounty_chrome_answer_read(mob/living/basic/fighter, mob/living/reader)
	if(QDELETED(fighter) || QDELETED(reader) || fighter.stat != CONSCIOUS)
		return
	if(isturf(fighter.loc) && !fighter.buckled && fighter.body_position == STANDING_UP)
		fighter.setDir(get_dir(fighter, reader))
	fighter.say(pick(GLOB.bounty_chrome_read_lines), forced = "bounty chrome read")

// ===== WHO AN AREA MOVE CATCHES =====

/**
 * Whether `victim` (a person, or a mech with one in it) is in `fighter`'s fight: the one it is going
 * for now, or a hunter after it. That is someone on its criminal's grudge list (they attacked,
 * confronted or cuffed it, or attacked one of its companions), in a mini-boss's posse, or crewing a
 * ship that hunts its bounty. Anyone else on the site, a bystander, is none of these. A leaderless
 * companion has only the one it is going for.
 */
/proc/bounty_chrome_in_posse(mob/living/basic/fighter, atom/victim)
	if(QDELETED(fighter) || QDELETED(victim))
		return FALSE
	var/list/people = list()
	if(isliving(victim))
		people += victim
	else if(ismecha(victim))
		var/obj/vehicle/sealed/mecha/mech = victim
		for(var/mob/living/pilot in mech.occupants)
			people += pilot
	var/atom/target = bounty_chrome_target(fighter)
	if(target && (target == victim || (target in people) || (isliving(victim) && target == victim.loc)))
		return TRUE
	var/mob/living/basic/bounty_criminal/side = bounty_ai_side_of(fighter)
	if(QDELETED(side))
		return FALSE
	var/mob/living/basic/bounty_criminal/boss/boss = side
	var/datum/criminal_bounty/posting = side.posting()
	var/list/hunter_ships = posting?.hunter_ships()
	for(var/mob/living/person as anything in people)
		if(side.body_has_grudge(person))
			return TRUE
		if(istype(boss) && boss.boss_engaged[REF(person)])
			return TRUE
		if(!person.mind)
			continue
		for(var/obj/structure/overmap/ship/ship as anything in hunter_ships)
			if(person.mind in ship.ship_team?.members)
				return TRUE
	return FALSE

/**
 * Whether one of `fighter`'s area moves (a lunge's line, a landing's shockwave, a roar) catches
 * `victim`: someone it may hit (bounty_ai_may_hit()) who is in its fight (bounty_chrome_in_posse()).
 * A bystander on the site is spared, so a chromed criminal is never a weapon to point at other crews.
 */
/proc/bounty_chrome_may_splash(mob/living/basic/fighter, atom/victim)
	return bounty_ai_may_hit(fighter, victim) && bounty_chrome_in_posse(fighter, victim)
