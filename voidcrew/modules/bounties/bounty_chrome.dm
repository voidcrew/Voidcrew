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
 * Gorilla Arms plating) shows on the NPC the same way, under the same clothes.
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
	if(!prob(bounty_chrome_tier_chance(tier)))
		return null
	var/count = (tier >= BOUNTY_TIER_WANTED && prob(BOUNTY_CHROME_SECOND_CHANCE)) ? 2 : 1
	return bounty_pick_chrome(count, tier, archetype, style, kit)

/// The chrome key a new companion of a `tier` criminal carries, or null: rarer than its criminal's, one piece at most
/proc/bounty_roll_companion_chrome(tier, style)
	if(!prob(bounty_chrome_tier_chance(tier) / BOUNTY_CHROME_COMPANION_DIVISOR))
		return null
	return bounty_pick_chrome(1, tier, BOUNTY_CHROME_COMPANION, style, null)

/// Up to `count` different keys, weighted, among the pieces that suit them. Null if none suit.
/proc/bounty_pick_chrome(count, tier, archetype, style, kit)
	var/list/picked = list()
	for(var/i in 1 to count)
		var/list/weights = list()
		for(var/key in GLOB.bounty_chrome_protos)
			var/datum/bounty_chrome/proto = GLOB.bounty_chrome_protos[key]
			if(!(key in picked) && proto.weight > 0 && proto.can_roll(tier, archetype, style, kit, picked))
				weights[key] = proto.weight
		if(!length(weights))
			break
		picked += pick_weight(weights)
	return length(picked) ? picked : null

/// The organ typepaths the look builder puts in a dummy for chrome `keys`
/proc/bounty_chrome_organ_looks(list/keys)
	var/list/organs = list()
	for(var/key in keys)
		var/datum/bounty_chrome/proto = GLOB.bounty_chrome_protos[key]
		if(proto?.organ_looks)
			organs |= proto.organ_looks
	return organs

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

/// Gives `fighter` (a criminal or a companion) the pieces `keys`, adding to any it has. For spawning and for admins.
/proc/bounty_chrome_install(mob/living/basic/fighter, list/keys)
	if(QDELETED(fighter) || !length(keys))
		return null
	var/datum/component/bounty_chrome/chrome = fighter.GetComponent(/datum/component/bounty_chrome)
	if(chrome)
		chrome.install(keys)
		return chrome
	return fighter.AddComponent(/datum/component/bounty_chrome, keys)

/// A piece `fighter` carries, by key, or null
/proc/bounty_chrome_piece(mob/living/basic/fighter, key)
	var/datum/component/bounty_chrome/chrome = fighter?.GetComponent(/datum/component/bounty_chrome)
	return chrome?.pieces[key]

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
	var/hit = FALSE
	for(var/key in pieces)
		var/datum/bounty_chrome/piece = pieces[key]
		if(piece.emp(severity))
			hit = TRUE
	if(hit)
		var/mob/living/fighter = parent
		do_sparks(3, TRUE, fighter)
		fighter.visible_message(span_warning("[fighter]'s chrome sparks and stutters!"))

/datum/component/bounty_chrome/proc/on_examine(datum/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	var/mob/living/fighter = parent
	for(var/key in pieces)
		var/datum/bounty_chrome/piece = pieces[key]
		var/line = piece.examine_line()
		if(line)
			examine_list += span_warning(replacetext(replacetext(line, "%THEIR", fighter.p_their()), "%THEY", fighter.p_they()))

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
 * (cyberware_scan_readout()), or null if `target` isn't one. Each piece reads as its real implant;
 * a piece down from an EMP reads OFFLINE. Someone passing as a patron reads as clean.
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
	for(var/key in chrome.pieces)
		var/datum/bounty_chrome/piece = chrome.pieces[key]
		var/list/info = bounty_chrome_scan_info(piece.scan_organ)
		var/ware_name = info ? info[1] : piece.name
		var/tier = info ? info[2] : null
		var/status = piece.offline_until ? " · OFFLINE" : ""
		var/rating = tier ? "T[tier]" : "UNRATED"
		lines += cyberware_scan_line("» [uppertext(ware_name)] · [rating][status]", tier ? cyberware_tier_color(tier) : accent)
	return lines
