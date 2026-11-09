/**
 * # Bounty hunting: chrome
 *
 * Owner: C0 chrome core. The pieces (C1-C4, voidcrew/modules/bounties/chrome/) and the cyberpsycho (C6)
 * build on this file; the seams are listed in the port's SEAMS notes and in the doc comments below.
 *
 * Some criminals and their companions carry cyberware: the real implants players buy at a ripperdoc
 * (voidcrew/modules/cyberware/), installed in their real body through the human NPC base's
 * npc_cyberware (owner decision 5). Nothing here stands in for an implant. A Gorilla Arms carrier
 * punches with the implant's own empowered punch, a Lazarus node jolts its bearer up by itself, an EMP
 * reboots the chrome on its real timer, a brownout browns it out, and it all burns out to scrap when the
 * NPC dies (the human NPC base, owner ruling).
 *
 * What this file adds, all of it AI or looks:
 * - Who carries what (/datum/bounty_chrome_piece, GLOB.bounty_chrome_pieces): a roll when the record is
 *   made, by tier (bounty_chrome_roll()), and a rarer one for companions (bounty_chrome_roll_companion()).
 *   A roll never puts two implants in one organ slot and never goes over the body's capacity, kit chrome
 *   included, so nothing browns out.
 * - The body (bounty_chrome_prepare(), bounty_chrome_equip()): the record's pieces become npc_cyberware
 *   before the base installs it, and carriers dress light enough that their worn chrome shows
 *   (bounty_chrome_expose_outfit()). A pressure suit or modsuit stays shut over it.
 * - How the AI uses it (/datum/bounty_chrome_move, /datum/component/bounty_chrome): a tell everyone can
 *   see and hear, at least BOUNTY_CHROME_TELL_MIN long, then the implant's own action, Trigger()ed the
 *   way a player's click does. Downed, stunned, cuffed, killed or EMP'd during the tell, nothing fires.
 *   An area move never starts while someone outside the fight stands where it would land
 *   (bounty_chrome_area_clear()). Mini-bosses use their moves through their own ability rotation
 *   (/datum/action/cooldown/mob_cooldown/bounty_boss/chrome).
 * - An EMP that knocks chrome out shows it: sparks, arcs and a flicker, as a picture only
 *   (bounty_chrome_malfunction_fx()).
 * - A bounty NPC feels a chrome read and tells the reader off (COMSIG_CARBON_CHROME_READ).
 */

// ===== THE PIECES =====

/// Every piece by key (BOUNTY_CHROME_*): built from the subtypes, so a piece needs no registry edit
GLOBAL_LIST_INIT(bounty_chrome_pieces, init_bounty_chrome_pieces())

/proc/init_bounty_chrome_pieces()
	var/list/pieces = list()
	for(var/datum/bounty_chrome_piece/piece_type as anything in subtypesof(/datum/bounty_chrome_piece))
		if(!initial(piece_type.key))
			continue
		var/datum/bounty_chrome_piece/piece = new piece_type
		pieces[piece.key] = piece
	// The moves each piece drives: every /datum/bounty_chrome_move subtype names its piece by key
	for(var/datum/bounty_chrome_move/move_type as anything in subtypesof(/datum/bounty_chrome_move))
		var/datum/bounty_chrome_piece/piece = pieces[initial(move_type.piece_key)]
		piece?.move_types += move_type
	return pieces

/**
 * The chrome a mini-boss kit (BOUNTY_KIT_*) already carries in its body, as organ typepaths: what a roll
 * must fit around. It has to match the kit's own npc_cyberware (bounty_boss_kits.dm); a test spawns
 * each kit and checks.
 */
/proc/bounty_chrome_kit_organs(kit)
	switch(kit)
		if(BOUNTY_KIT_GHOST)
			return list(/obj/item/organ/cyberimp/cyberware/slipwire, /obj/item/organ/cyberimp/cyberware/cascade)
		if(BOUNTY_KIT_CYBERPSYCHO)
			return bounty_psycho_organs()
	return list()

/**
 * One piece of chrome a criminal can carry: which real implants it is, and who can roll it. One
 * subtype per key, below. The moves that drive it in a fight are /datum/bounty_chrome_move subtypes that
 * name it by key (C1-C4), collected into move_types at start.
 */
/datum/bounty_chrome_piece
	/// BOUNTY_CHROME_*; the subtype with no key is abstract
	var/key
	/// What admins see it called
	var/name = "chrome"
	/// Roll weight among the pieces that suit. 0 never rolls and isn't offered to admins.
	var/weight = 10
	/// Lowest tier that rolls it (BOUNTY_TIER_*); a companion is checked against its criminal's tier
	var/min_tier = BOUNTY_TIER_PETTY
	/// The criminal archetypes that roll it (BOUNTY_ARCHETYPE_*). Never the meek: they run.
	var/list/archetypes = list(BOUNTY_ARCHETYPE_NORMAL, BOUNTY_ARCHETYPE_BOSS)
	/// Whether a companion can roll it
	var/companion = TRUE
	/// The fighting styles (BOUNTY_STYLE_*) that roll it, or null for any. Mini-bosses have no style.
	var/list/styles
	/// Only for styles that shoot (bounty_chrome_style_shoots())
	var/shooter = FALSE
	/// The mini-boss kits (BOUNTY_KIT_*) that roll it, or null for any kit
	var/list/kits
	/// Keys it never rolls alongside (a design choice; organ slots are checked on their own)
	var/list/exclusive_with
	/// The real implant organs it is, as typepaths
	var/list/organs
	/// The /datum/bounty_chrome_move types that drive it, filled at start
	var/list/move_types = list()

/// Whether a new `archetype` fighter of `tier`, with `style` or `kit` and the keys `picked` so far, may roll it
/datum/bounty_chrome_piece/proc/can_roll(tier, archetype, style, kit, list/picked)
	if(weight <= 0 || !tier || tier < min_tier)
		return FALSE
	if(archetype == BOUNTY_CHROME_COMPANION)
		if(!companion)
			return FALSE
	else if(!(archetype in archetypes))
		return FALSE
	if(archetype == BOUNTY_ARCHETYPE_BOSS)
		if(kits && !(kit in kits))
			return FALSE
	else
		if(styles && !(style in styles))
			return FALSE
		if(shooter && !bounty_chrome_style_shoots(style))
			return FALSE
	for(var/other in picked)
		if(other in exclusive_with)
			return FALSE
		var/datum/bounty_chrome_piece/other_piece = GLOB.bounty_chrome_pieces[other]
		if(key in other_piece?.exclusive_with)
			return FALSE
	return TRUE

/// A melee style this piece fights with when it has to change someone's style (an admin's pick), or null if any style will do
/datum/bounty_chrome_piece/proc/fitting_style(style)
	if(!styles || (style in styles))
		return null
	return styles[1]

/// Whether fighting style `style` (BOUNTY_STYLE_*) shoots a gun
/proc/bounty_chrome_style_shoots(style)
	var/datum/bounty_style/fighting_style = GLOB.bounty_styles[style]
	return !!fighting_style?.ranged && ispath(fighting_style.weapon_type, /obj/item/gun)

/datum/bounty_chrome_piece/cascade
	key = BOUNTY_CHROME_CASCADE
	name = "Cascade lattice"
	// A legend piece: rare, and only on the dangerous
	weight = 6
	min_tier = BOUNTY_TIER_WANTED
	// The Ghost carries its own; the Heavy's whole fight is being slow and flanked
	kits = list(BOUNTY_KIT_JUGGERNAUT, BOUNTY_KIT_PYROMANIAC, BOUNTY_KIT_DEMOLITIONIST)
	organs = list(/obj/item/organ/cyberimp/cyberware/cascade)

/datum/bounty_chrome_piece/redline
	key = BOUNTY_CHROME_REDLINE
	name = "Redline core"
	weight = 6
	min_tier = BOUNTY_TIER_WANTED
	// Not on the Juggernaut's riot plates or the Heavy's armour
	kits = list(BOUNTY_KIT_PYROMANIAC, BOUNTY_KIT_DEMOLITIONIST, BOUNTY_KIT_GHOST)
	organs = list(/obj/item/organ/cyberimp/cyberware/redline)

/datum/bounty_chrome_piece/piledriver
	key = BOUNTY_CHROME_PILEDRIVER
	name = "Meteor Piledriver"
	// The rarest: Wanted or worse, never a companion
	weight = 4
	min_tier = BOUNTY_TIER_WANTED
	companion = FALSE
	// Of the mini-bosses only the Pyromaniac: the others already charge, dash or fight from range
	kits = list(BOUNTY_KIT_PYROMANIAC)
	// Two gap-closers that knock people down would be one too many
	exclusive_with = list(BOUNTY_CHROME_MANTIS)
	organs = list(/obj/item/organ/cyberimp/cyberware/piledriver)

/datum/bounty_chrome_piece/gorilla
	key = BOUNTY_CHROME_GORILLA
	name = "Gorilla Arms"
	weight = 12
	// The implant powers a bare-handed punch: brawlers only. Never a mini-boss: the Juggernaut's shield fills a hand, so its grab never fires
	styles = list(BOUNTY_STYLE_BRAWLER)
	archetypes = list(BOUNTY_ARCHETYPE_NORMAL)
	organs = list(
		/obj/item/organ/cyberimp/cyberware/gorilla_arms,
		/obj/item/organ/cyberimp/cyberware/gorilla_arms/left,
	)

/datum/bounty_chrome_piece/mantis
	key = BOUNTY_CHROME_MANTIS
	name = "Mantis Blades"
	weight = 10
	// Fighters who close in. Never a mini-boss: the Juggernaut's charge and the Ghost's dash already close the gap.
	archetypes = list(BOUNTY_ARCHETYPE_NORMAL)
	styles = list(BOUNTY_STYLE_BRAWLER, BOUNTY_STYLE_KNIFE, BOUNTY_STYLE_CLUB)
	exclusive_with = list(BOUNTY_CHROME_PILEDRIVER)
	organs = list(
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left,
	)

/datum/bounty_chrome_piece/lazarus
	key = BOUNTY_CHROME_LAZARUS
	name = "Lazarus node"
	// A second round in one fight is a lot. Never a companion: putting one down has to stay the answer to every companion.
	weight = 8
	min_tier = BOUNTY_TIER_WANTED
	companion = FALSE
	organs = list(/obj/item/organ/cyberimp/cyberware/lazarus)

/datum/bounty_chrome_piece/deadeye
	key = BOUNTY_CHROME_DEADEYE
	name = "Deadeye link"
	weight = 12
	// It walks rounds onto a mark: only for those who shoot
	archetypes = list(BOUNTY_ARCHETYPE_NORMAL)
	shooter = TRUE
	organs = list(/obj/item/organ/eyes/robotic/cyberware/deadeye)

// ===== WHAT AN IMPLANT TAKES =====

/// Organ type -> list("slot", "zone", "load", "bonus", "shows"), read off the type once
GLOBAL_LIST_EMPTY(bounty_chrome_organ_facts)

/**
 * What an organ type takes in a body, read off the type (no copy is made, so it works at any time):
 * its organ slot and zone, the neural load and capacity bonus it brings (cyberware_component.dm), and
 * whether it shows on the body as worn chrome (an aug_overlay).
 */
/proc/bounty_chrome_organ_facts(organ_type)
	var/list/facts = GLOB.bounty_chrome_organ_facts[organ_type]
	if(facts)
		return facts
	if(!ispath(organ_type, /obj/item/organ))
		return null
	var/obj/item/organ/organ = organ_type
	var/load = 0
	var/bonus = 0
	var/shows = FALSE
	if(ispath(organ_type, /obj/item/organ/cyberimp/cyberware))
		var/obj/item/organ/cyberimp/cyberware/ware = organ_type
		load = initial(ware.chrome_load)
		bonus = initial(ware.chrome_capacity_bonus)
	else if(ispath(organ_type, /obj/item/organ/cyberimp/arm/toolkit/cyberware))
		var/obj/item/organ/cyberimp/arm/toolkit/cyberware/arm_ware = organ_type
		load = initial(arm_ware.chrome_load)
		bonus = initial(arm_ware.chrome_capacity_bonus)
	else if(ispath(organ_type, /obj/item/organ/eyes/robotic/cyberware))
		var/obj/item/organ/eyes/robotic/cyberware/optics = organ_type
		load = initial(optics.chrome_load)
		bonus = initial(optics.chrome_capacity_bonus)
	else if(ispath(organ_type, /obj/item/organ/cyberimp) || (initial(organ.organ_flags) & ORGAN_ROBOTIC))
		// Robotic hardware that isn't chrome costs the body's flat rate (get_installed_capacity_cost())
		load = GLOB.installed_capacity_costs["robotic_organ"]
	if(ispath(organ_type, /obj/item/organ/cyberimp))
		var/obj/item/organ/cyberimp/implant = organ_type
		shows = !!initial(implant.aug_overlay)
	facts = list("slot" = initial(organ.slot), "zone" = initial(organ.zone), "load" = load, "bonus" = bonus, "shows" = shows)
	GLOB.bounty_chrome_organ_facts[organ_type] = facts
	return facts

/// Whether the organ types `organ_types` can all be in one body at once: one per organ slot, and no more load than the body's capacity (CYBERWARE_BASE_CAPACITY plus any Governor), so nothing browns out
/proc/bounty_chrome_organs_fit(list/organ_types)
	var/list/slots = list()
	var/load = 0
	var/capacity = CYBERWARE_BASE_CAPACITY
	for(var/organ_type in organ_types)
		var/list/facts = bounty_chrome_organ_facts(organ_type)
		if(!facts)
			return FALSE
		var/slot = facts["slot"]
		if(slot)
			if(slots[slot])
				return FALSE
			slots[slot] = TRUE
		load += facts["load"]
		capacity += facts["bonus"]
	return load <= capacity

/// The organ typepaths of the pieces `keys`, in order
/proc/bounty_chrome_organ_types(list/keys)
	. = list()
	for(var/key in keys)
		var/datum/bounty_chrome_piece/piece = GLOB.bounty_chrome_pieces[key]
		if(piece)
			. += piece.organs

/**
 * The keys of `keys` that go in together on top of `existing_organs` (typepaths already bound for the
 * body: a kit's own chrome), in order: a piece that would share an organ slot or take the body over its
 * capacity is left out, and so is an unknown key or one listed twice.
 */
/proc/bounty_chrome_fit_keys(list/keys, list/existing_organs)
	. = list()
	var/list/organs = existing_organs ? existing_organs.Copy() : list()
	for(var/key in keys)
		var/datum/bounty_chrome_piece/piece = GLOB.bounty_chrome_pieces[key]
		if(!piece || (key in .))
			continue
		if(!bounty_chrome_organs_fit(organs + piece.organs))
			continue
		organs += piece.organs
		. += key

// ===== ROLLING =====

/// Percent chance a criminal of `tier` carries chrome
/proc/bounty_chrome_tier_chance(tier)
	switch(tier)
		if(BOUNTY_TIER_MOST_WANTED)
			return BOUNTY_CHROME_CHANCE_MOST_WANTED
		if(BOUNTY_TIER_WANTED)
			return BOUNTY_CHROME_CHANCE_WANTED
	return BOUNTY_CHROME_CHANCE_PETTY

/**
 * The chrome keys a new criminal carries, or null for none: a roll by tier, then one piece (two, now and
 * then, from Wanted up), weighted among the pieces that suit its archetype, style and kit and that fit in
 * its body on top of `existing_organs` (its kit's own chrome, bounty_chrome_kit_organs()). The meek
 * never carry any. Doesn't sleep.
 */
/proc/bounty_chrome_roll(tier, archetype, style, kit, list/existing_organs)
	if(archetype != BOUNTY_ARCHETYPE_NORMAL && archetype != BOUNTY_ARCHETYPE_BOSS)
		return null
	if(!prob(bounty_chrome_tier_chance(tier)))
		return null
	var/count = (tier >= BOUNTY_TIER_WANTED && prob(BOUNTY_CHROME_SECOND_CHANCE)) ? 2 : 1
	return bounty_chrome_pick(count, tier, archetype, style, kit, existing_organs)

/**
 * The chrome a new companion of a `tier` criminal carries as a list of one key, or null: rarer than its
 * criminal's, one piece at most, never Lazarus or the Piledriver. `style` is the companion's own.
 * Companions call this as they are dressed (C4); see bounty_chrome_prepare_body().
 */
/proc/bounty_chrome_roll_companion(tier, style)
	if(!prob(bounty_chrome_tier_chance(tier) / BOUNTY_CHROME_COMPANION_DIVISOR))
		return null
	return bounty_chrome_pick(1, tier, BOUNTY_CHROME_COMPANION, style, null, null)

/// Up to `count` different keys, weighted, among the pieces that suit and fit together on top of `existing_organs`. Null if none do.
/proc/bounty_chrome_pick(count, tier, archetype, style, kit, list/existing_organs)
	var/list/picked = list()
	var/list/organs = existing_organs ? existing_organs.Copy() : list()
	for(var/i in 1 to count)
		var/list/weights = list()
		for(var/key in GLOB.bounty_chrome_pieces)
			var/datum/bounty_chrome_piece/piece = GLOB.bounty_chrome_pieces[key]
			if((key in picked) || !piece.can_roll(tier, archetype, style, kit, picked))
				continue
			if(!bounty_chrome_organs_fit(organs + piece.organs))
				continue
			weights[key] = piece.weight
		if(!length(weights))
			break
		var/key = pick_weight(weights)
		picked += key
		var/datum/bounty_chrome_piece/chosen = GLOB.bounty_chrome_pieces[key]
		organs += chosen.organs
	return length(picked) ? picked : null

/**
 * The most pieces that fit in one body on top of `existing_organs`, whatever they would normally roll
 * for, for the Bounty Panel's "All of it": the largest set, then the one with the most chrome in it. The
 * cyberpsycho (C6) replaces this choice with its own kit.
 */
/proc/bounty_chrome_all_that_fits(list/existing_organs)
	var/list/keys = list()
	for(var/key in GLOB.bounty_chrome_pieces)
		var/datum/bounty_chrome_piece/piece = GLOB.bounty_chrome_pieces[key]
		if(piece.weight > 0)
			keys += key
	var/list/best = list()
	var/best_load = -1
	var/combinations = 1 << length(keys)
	for(var/mask in 1 to combinations - 1)
		var/list/chosen = list()
		for(var/i in 1 to length(keys))
			if(mask & (1 << (i - 1)))
				chosen += keys[i]
		if(length(chosen) < length(best))
			continue
		var/list/organs = (existing_organs ? existing_organs.Copy() : list()) + bounty_chrome_organ_types(chosen)
		if(!bounty_chrome_organs_fit(organs))
			continue
		var/load = 0
		for(var/organ_type in bounty_chrome_organ_types(chosen))
			var/list/facts = bounty_chrome_organ_facts(organ_type)
			load += facts["load"]
		if(length(chosen) > length(best) || load > best_load)
			best = chosen
			best_load = load
	return best

/**
 * Puts a normal criminal's record on a style its chrome fights with, for chrome it was given rather
 * than rolled (an admin's pick): Gorilla Arms and Mantis Blades never come with a gun or a bottle. Rolled
 * chrome already suits its style. Returns TRUE if the style changed.
 */
/proc/bounty_chrome_fit_style(datum/bounty_record/record)
	if(!record || record.archetype != BOUNTY_ARCHETYPE_NORMAL)
		return FALSE
	for(var/key in record.chrome)
		var/datum/bounty_chrome_piece/piece = GLOB.bounty_chrome_pieces[key]
		var/new_style = piece?.fitting_style(record.style)
		if(new_style)
			record.style = new_style
			return TRUE
	return FALSE

// ===== THE BODY =====

/// Whether `npc` is a bounty human whose record's chrome goes in its body: a normal criminal or a mini-boss. Never the meek, a decoy (it copies its fugitive's organs, body_match()) or the kingpin.
/proc/bounty_chrome_carrier(mob/living/carbon/human/npc/npc)
	return istype(npc, /mob/living/carbon/human/npc/bounty_criminal/normal) || istype(npc, /mob/living/carbon/human/npc/bounty_criminal/boss)

/**
 * Before `npc`'s body is built: the organs of the pieces `keys` that fit on top of what it already
 * carries go into its npc_cyberware, which the human NPC base installs once it is dressed (so its outfit
 * can be cut to show them, bounty_chrome_expose_outfit()). Returns the keys that went in.
 */
/proc/bounty_chrome_prepare_body(mob/living/carbon/human/npc/npc, list/keys)
	if(!ishumannpc(npc) || !length(keys))
		return list()
	var/list/existing = npc.npc_cyberware ? npc.npc_cyberware.Copy() : list()
	var/list/fitted = bounty_chrome_fit_keys(keys, existing)
	if(length(fitted))
		npc.npc_cyberware = existing + bounty_chrome_organ_types(fitted)
	return fitted

/**
 * A criminal's Initialize(), before the body is built: its record's chrome becomes npc_cyberware. What
 * doesn't fit (an admin's pick that clashes with a kit's chrome) comes off the record, so the record
 * stays the truth about the criminal.
 */
/proc/bounty_chrome_prepare(mob/living/carbon/human/npc/bounty_criminal/criminal)
	if(!bounty_chrome_carrier(criminal) || !length(criminal.record?.chrome))
		return
	var/list/fitted = bounty_chrome_prepare_body(criminal, criminal.record.chrome)
	criminal.record.chrome = length(fitted) ? fitted : null

/// A criminal's Initialize(), once its body is built: its chrome is watched for EMPs, and a carrier gets its moves
/proc/bounty_chrome_ready(mob/living/carbon/human/npc/bounty_criminal/criminal)
	// Every criminal, decoys included: a decoy carries its fugitive's chrome and must spark the same way
	criminal.AddElement(/datum/element/bounty_chrome_body)
	if(bounty_chrome_carrier(criminal) && length(criminal.record?.chrome))
		bounty_chrome_equip(criminal, criminal.record.chrome)

/**
 * Once the chrome `keys` are in `npc`'s body: the AI side of it (the component and the moves of each
 * piece), the EMP look, and for a mini-boss one ability in its rotation per move. Adds to chrome it
 * has. Returns the component, or null for no keys.
 */
/proc/bounty_chrome_equip(mob/living/carbon/human/npc/npc, list/keys)
	if(!ishumannpc(npc) || QDELETED(npc) || !length(keys))
		return null
	npc.AddElement(/datum/element/bounty_chrome_body)
	return npc.AddComponent(/datum/component/bounty_chrome, keys)

/**
 * Installs the pieces `keys` in `npc`'s live body now, real organs through the base's
 * npc_install_cyberware(), as many as fit with what it already has in it, then equips them. For tests and
 * admins with a body already built; a spawn goes through bounty_chrome_prepare_body(). Returns the keys
 * that went in.
 */
/proc/bounty_chrome_install_now(mob/living/carbon/human/npc/npc, list/keys)
	. = list()
	if(!ishumannpc(npc) || QDELETED(npc))
		return
	var/list/installed = list()
	for(var/obj/item/organ/organ in npc.organs)
		if(organ.GetComponent(/datum/component/cyberware))
			installed += organ.type
	for(var/key in bounty_chrome_fit_keys(keys, installed))
		var/datum/bounty_chrome_piece/piece = GLOB.bounty_chrome_pieces[key]
		for(var/organ_type in piece.organs)
			npc.npc_install_cyberware(organ_type)
		. += key
	if(length(.))
		bounty_chrome_equip(npc, .)

// A criminal or companion built with chrome that takes the place of an organ it was born with (a Deadeye
// link its eyes): the old organ goes, as tg's own regenerate_organs() does it, instead of the base's Insert()
// dropping it at its feet, a pair of loose eyes on the floor. Decoys copying their fugitive's chrome
// (body_match()) come through here too.
/mob/living/carbon/human/npc/bounty_criminal/npc_install_cyberware(ware_type)
	bounty_chrome_clear_natural_slot(src, ware_type)
	return ..()

/mob/living/carbon/human/npc/bounty_companion/npc_install_cyberware(ware_type)
	bounty_chrome_clear_natural_slot(src, ware_type)
	return ..()

/// Takes out and deletes the organ (never chrome) in the slot chrome of `ware_type` is about to fill in `npc`
/proc/bounty_chrome_clear_natural_slot(mob/living/carbon/human/npc/npc, ware_type)
	var/list/facts = bounty_chrome_organ_facts(ware_type)
	var/slot = facts?["slot"]
	if(!slot)
		return
	var/obj/item/organ/born_with = npc.get_organ_slot(slot)
	if(!born_with || born_with.GetComponent(/datum/component/cyberware))
		return
	born_with.Remove(npc, special = TRUE)
	qdel(born_with)

// ===== DRESSED TO SHOW IT =====

/// Where the worn chrome in `organ_types` shows on a body: list("arms", "chest", "legs") of TRUE/FALSE, or null if it shows nowhere
/proc/bounty_chrome_shows(list/organ_types)
	var/arms = FALSE
	var/chest = FALSE
	var/legs = FALSE
	for(var/organ_type in organ_types)
		var/list/facts = bounty_chrome_organ_facts(organ_type)
		if(!facts?["shows"])
			continue
		switch(facts["zone"])
			if(BODY_ZONE_R_ARM, BODY_ZONE_L_ARM)
				arms = TRUE
			if(BODY_ZONE_CHEST)
				chest = TRUE
			if(BODY_ZONE_R_LEG, BODY_ZONE_L_LEG)
				legs = TRUE
	if(!arms && !chest && !legs)
		return null
	return list("arms" = arms, "chest" = chest, "legs" = legs)

/// Whether its clothes are cut to show the chrome it carries (bounty_chrome_expose_outfit(), from the bounty outfit table): yes, but for a mini-boss, whose kit is its look. The cyberpsycho (C6) may say yes.
/mob/living/carbon/human/npc/proc/bounty_dresses_to_show_chrome()
	return !istype(src, /mob/living/carbon/human/npc/bounty_criminal/boss)

/// What a chrome carrier wears instead of a shirt: trousers over chest or arm chrome, shorts over leg chrome
/proc/bounty_chrome_bottoms(legs)
	if(legs)
		return pick(/obj/item/clothing/under/shorts/jeanshorts, /obj/item/clothing/under/shorts/black, /obj/item/clothing/under/shorts/grey)
	return pick(/obj/item/clothing/under/pants/jeans, /obj/item/clothing/under/pants/camo, /obj/item/clothing/under/pants/track)

/**
 * `outfit` (a typepath or an instance) cut so the worn chrome in `organ_types` shows, as an instance
 * (an instance passed in is changed in place). Worn chrome draws under every garment (CYBERWARE_WORN_LAYER),
 * so: no jumpsuit (trousers, or shorts over leg chrome), no coat over chest or arm chrome, no gloves over
 * arm chrome. Armour stays on: a vest is the tier's toughness. A pressure suit or a modsuit stays shut,
 * and so does everything under it. Chrome that doesn't show changes nothing. The site's layers (a
 * space suit, cold-weather wear) go on afterwards, over it, as they would on anyone.
 */
/proc/bounty_chrome_expose_outfit(outfit, list/organ_types)
	var/list/shows = bounty_chrome_shows(organ_types)
	if(!shows)
		return outfit
	var/datum/outfit/dressed = ispath(outfit, /datum/outfit) ? new outfit() : outfit
	if(!istype(dressed))
		return outfit
	var/obj/item/clothing/suit = dressed.suit
	if((ispath(suit, /obj/item/clothing) && (initial(suit.clothing_flags) & STOPSPRESSUREDAMAGE)) || ispath(dressed.back, /obj/item/mod/control))
		return dressed
	var/arms = shows["arms"]
	var/chest = shows["chest"]
	var/legs = shows["legs"]
	if((arms || chest) && dressed.suit && !ispath(dressed.suit, /obj/item/clothing/suit/armor))
		// What the coat carried goes in the bag; with no bag the coat stays, it holds their gun
		if(dressed.suit_store && dressed.back)
			LAZYADDASSOC(dressed.backpack_contents, dressed.suit_store, 1)
			dressed.suit_store = null
		if(!dressed.suit_store)
			dressed.suit = null
	if(arms)
		dressed.gloves = null
	if(dressed.uniform && !ispath(dressed.uniform, legs ? /obj/item/clothing/under/shorts : /obj/item/clothing/under/pants))
		dressed.uniform = bounty_chrome_bottoms(legs)
	return dressed

/**
 * Bares the worn chrome in `npc`'s live body, as bounty_chrome_expose_outfit() does for an outfit: the
 * coat and gloves over it come off, and the shirt is swapped for trousers or shorts, the pockets, belt
 * and ID staying where they are. What comes off is deleted (it was locked gear, D3), and what goes on is
 * locked. A pressure suit or a modsuit stays shut. For a fugitive whose act drops (bounty_outpost.dm).
 * Returns TRUE if anything came off. Doesn't sleep.
 */
/proc/bounty_chrome_bare(mob/living/carbon/human/npc/npc)
	if(!ishumannpc(npc) || QDELETED(npc))
		return FALSE
	var/list/installed = list()
	for(var/obj/item/organ/organ in npc.organs)
		if(organ.GetComponent(/datum/component/cyberware))
			installed += organ.type
	var/list/shows = bounty_chrome_shows(installed)
	if(!shows)
		return FALSE
	var/obj/item/clothing/suit = npc.wear_suit
	if((istype(suit) && (suit.clothing_flags & STOPSPRESSUREDAMAGE)) || istype(npc.back, /obj/item/mod/control))
		return FALSE
	var/arms = shows["arms"]
	var/chest = shows["chest"]
	var/legs = shows["legs"]
	var/coat_name
	. = FALSE
	if((arms || chest) && suit && !istype(suit, /obj/item/clothing/suit/armor) && !npc.s_store)
		coat_name = "[suit.name]"
		npc.temporarilyRemoveItemFromInventory(suit, force = TRUE)
		qdel(suit)
		. = TRUE
	if(arms && npc.gloves)
		var/obj/item/hand_wear = npc.gloves
		npc.temporarilyRemoveItemFromInventory(hand_wear, force = TRUE)
		qdel(hand_wear)
		. = TRUE
	var/obj/item/clothing/under/shirt = npc.w_uniform
	if(shirt && !istype(shirt, legs ? /obj/item/clothing/under/shorts : /obj/item/clothing/under/pants))
		// idrop off: the pockets, belt and ID stay when the clothes they hang on are swapped
		npc.temporarilyRemoveItemFromInventory(shirt, force = TRUE, idrop = FALSE)
		qdel(shirt)
		var/bottoms_type = bounty_chrome_bottoms(legs)
		var/obj/item/bottoms = new bottoms_type(npc)
		npc.equip_to_slot_or_del(bottoms, ITEM_SLOT_ICLOTHING, initial = TRUE)
		npc.npc_lock_item(bottoms)
		. = TRUE
	if(coat_name)
		npc.visible_message(span_warning("[npc] shrugs off the [coat_name]."))

// ===== IN A FIGHT =====

/**
 * Whether `npc` can use its chrome now: awake, on its feet and on a turf, out of crit, not cuffed,
 * stunned or knocked down, not giving up, not hiding or passing as a patron, and not driven by a
 * player. All read from tg.
 */
/proc/bounty_chrome_can_act(mob/living/carbon/human/npc/npc)
	if(!ishumannpc(npc) || QDELETED(npc) || npc.stat != CONSCIOUS || !isturf(npc.loc) || npc.client)
		return FALSE
	if(HAS_TRAIT(npc, TRAIT_CRITICAL_CONDITION) || HAS_TRAIT(npc, TRAIT_RESTRAINED) || HAS_TRAIT(npc, TRAIT_INCAPACITATED) || HAS_TRAIT(npc, TRAIT_FLOORED))
		return FALSE
	if(npc.npc_surrendering)
		return FALSE
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = npc
	if(istype(criminal) && (criminal.hidden || criminal.blended))
		return FALSE
	return TRUE

/// Whether `npc` is in a fight, by its AI's mode: a criminal fighting, a companion in it, a mini-boss turned hostile. Its state (stuns and the like) is bounty_chrome_can_act()'s.
/proc/bounty_chrome_in_fight(mob/living/carbon/human/npc/npc)
	if(QDELETED(npc) || npc.stat == DEAD)
		return FALSE
	if(istype(npc, /mob/living/carbon/human/npc/bounty_criminal/boss))
		var/mob/living/carbon/human/npc/bounty_criminal/boss/boss = npc
		return boss.boss_hostile
	if(istype(npc, /mob/living/carbon/human/npc/bounty_criminal))
		var/mob/living/carbon/human/npc/bounty_criminal/criminal = npc
		return criminal.ai_mode == BOUNTY_AI_FIGHTING
	if(istype(npc, /mob/living/carbon/human/npc/bounty_companion))
		var/mob/living/carbon/human/npc/bounty_companion/companion = npc
		return companion.ai_in_fight
	return FALSE

/// Who `npc` is going for now (a person, or a mech), or null
/proc/bounty_chrome_target(mob/living/carbon/human/npc/npc)
	var/datum/ai_controller/controller = npc?.ai_controller
	if(QDELETED(controller))
		return null
	var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET] || controller.blackboard[BB_BOUNTY_BOSS_PREY]
	return QDELETED(target) ? null : target

/**
 * The first action of `action_type` on chrome in `npc` (its implants' own buttons), preferring one
 * that can be used now, or null.
 */
/proc/bounty_chrome_action(mob/living/carbon/human/npc/npc, action_type)
	if(!ispath(action_type, /datum/action) || QDELETED(npc))
		return null
	var/datum/action/found
	for(var/obj/item/organ/organ in npc.organs)
		if(!organ.GetComponent(/datum/component/cyberware))
			continue
		for(var/datum/action/action as anything in organ.actions)
			if(!istype(action, action_type) || action.owner != npc)
				continue
			if(action.IsAvailable())
				return action
			found ||= action
	return found

/**
 * Fires `npc`'s implant action of `action_type` the way a player's click does: Trigger(), aimed at
 * `target` for an action that is clicked onto something. Only an action that can be used now. Returns
 * TRUE if it fired.
 */
/proc/bounty_chrome_trigger(mob/living/carbon/human/npc/npc, action_type, atom/target)
	var/datum/action/action = bounty_chrome_action(npc, action_type)
	if(!action || !action.IsAvailable())
		return FALSE
	var/datum/action/cooldown/cooldown_action = action
	if(istype(cooldown_action) && cooldown_action.click_to_activate)
		if(QDELETED(target))
			return FALSE
		return !!action.Trigger(target = target)
	return !!action.Trigger()

// ===== WHO AN AREA MOVE MAY CATCH =====

/**
 * Whether `person` is in `npc`'s fight, so an area move may catch them: the one it is going for or
 * `aimed` at, or a hunter after it. That is someone its side holds a grudge against (they attacked,
 * confronted or cuffed it or a companion), in a mini-boss's posse, or crewing a ship hunting its
 * bounty. Its own side never is, and nor is anyone else on the site.
 */
/proc/bounty_chrome_in_posse(mob/living/carbon/human/npc/npc, mob/living/person, atom/aimed)
	if(QDELETED(npc) || !isliving(person) || person == npc || bounty_ai_same_gang(npc, person))
		return FALSE
	for(var/atom/target in list(bounty_chrome_target(npc), aimed))
		if(target == person || (ismecha(target) && person.loc == target))
			return TRUE
	var/mob/living/carbon/human/npc/bounty_criminal/side = bounty_ai_side_of(npc)
	if(QDELETED(side))
		return FALSE
	if(side.body_has_grudge(person))
		return TRUE
	var/mob/living/carbon/human/npc/bounty_criminal/boss/boss = side
	if(istype(boss) && boss.boss_engaged[REF(person)])
		return TRUE
	if(!person.mind)
		return FALSE
	var/datum/criminal_bounty/posting = side.posting()
	for(var/obj/structure/overmap/ship/ship as anything in posting?.hunter_ships())
		if(person.mind in ship.ship_team?.members)
			return TRUE
	// A crewmate of anyone in the fight is in it too: a crew can't keep the area moves off by standing an idle friend beside the shooter
	for(var/atom/target in list(bounty_chrome_target(npc), aimed))
		if(bounty_chrome_crewmates(person, target))
			return TRUE
	for(var/datum/weakref/enemy_ref as anything in side.grudge)
		if(bounty_chrome_crewmates(person, enemy_ref?.resolve()))
			return TRUE
	return FALSE

/// Whether `person` and `other` (a person, or a mech with one in it) crew the same ship
/proc/bounty_chrome_crewmates(mob/living/person, atom/other)
	var/mob/living/other_person = ismecha(other) ? bounty_ai_pilot_of(other) : other
	if(!isliving(other_person) || other_person == person || !LAZYLEN(person?.mind?.ship_teams) || !LAZYLEN(other_person.mind?.ship_teams))
		return FALSE
	for(var/datum/team/voidcrew/crew as anything in person.mind.ship_teams)
		if(crew in other_person.mind.ship_teams)
			return TRUE
	return FALSE

/**
 * Whether `npc` may start an area move over `turfs` (owner decision 5): nobody stands there who is
 * outside its fight. Its own side and the site's people count as outside it (it doesn't land on its
 * friends); the dead and creatures with nobody behind them (site fauna) don't count. The implant itself
 * is never changed: once it fires it hits whoever is there, as it would for a player.
 */
/proc/bounty_chrome_area_clear(mob/living/carbon/human/npc/npc, list/turfs, atom/aimed, ignore_faction = FALSE)
	if(QDELETED(npc))
		return FALSE
	for(var/turf/spot as anything in turfs)
		if(!isturf(spot))
			continue
		for(var/mob/living/person in spot)
			if(person == npc || person.stat == DEAD)
				continue
			// A move that spares its own side (the Redline roar) doesn't wait on its own companions
			if(ignore_faction && bounty_ai_same_gang(npc, person))
				continue
			if(!bounty_chrome_in_posse(npc, person, aimed) && bounty_chrome_counts_as_bystander(npc, person))
				return FALSE
		for(var/obj/vehicle/sealed/mecha/mech in spot)
			for(var/mob/living/pilot in mech.occupants)
				if(!bounty_chrome_in_posse(npc, pilot, aimed) && bounty_chrome_counts_as_bystander(npc, pilot))
					return FALSE
	return TRUE

/// Whether `person`, not in `npc`'s fight, keeps an area move from starting: anyone with a player behind them, any person, and anyone on its side. Not a creature with nobody behind it.
/proc/bounty_chrome_counts_as_bystander(mob/living/carbon/human/npc/npc, mob/living/person)
	if(person.mind || person.client || ishuman(person))
		return TRUE
	return bounty_ai_same_gang(npc, person) || npc.faction_check_atom(person)

// ===== MOVES =====

/**
 * # A chrome move
 *
 * One thing an NPC's AI does with one piece of chrome: a tell, then the implant's own action. C1-C4
 * subtype it, one subtype per move, naming the piece by `piece_key`; nothing else registers it. Each
 * NPC carrying the piece gets its own instance (/datum/component/bounty_chrome), so cooldowns are its
 * own.
 *
 * How a normal criminal or a companion uses one (the bounty_chrome planning subtree): while it is in a
 * fight and can act, plan() first (a move that queues behaviours of its own, a grab, returns TRUE), then
 * a move whose can_start() passes starts: it stands still (tell_holds_still), its AI goes quiet, and
 * tell() shows the outline, plays the sound and says the line. After tell_time (never under
 * BOUNTY_CHROME_TELL_MIN) fire() runs effect(), which Trigger()s the implant's action. Downed, stunned,
 * knocked down, cuffed, EMP'd or killed during the tell: cancel() and nothing fires. A mini-boss runs the
 * same tell() and effect() through its ability rotation instead.
 *
 * The hooks below are called for every move of the NPC, in a fight or not. None may sleep.
 */
/datum/bounty_chrome_move
	/// The BOUNTY_CHROME_* key of the piece this move drives; null for an abstract type
	var/piece_key
	/// What it is called (admins, the mini-boss's ability)
	var/name = "chrome"
	/// The implant action it fires (a /datum/action subtype on the piece's organs), or null for a move that fires nothing by itself
	var/action_type
	/// How long its tell lasts. Never under BOUNTY_CHROME_TELL_MIN.
	var/tell_time = BOUNTY_CHROME_TELL_MIN
	/// It stands still through the tell (TRAIT_IMMOBILIZED, as a mini-boss winding up does)
	var/tell_holds_still = TRUE
	/// Its AI carries on through the tell (drawing, shooting, moving) instead of going quiet: a tell that is only a look, a gunman's Deadeye lock. Interrupts still cut it short.
	var/tell_keeps_acting = FALSE
	/// The outline it glows with through the tell
	var/tell_color = BOUNTY_CHROME_TELL_COLOR
	/// The sound at the start of the tell
	var/tell_sound = 'sound/effects/seedling_chargeup.ogg'
	/// Lines it may say as the tell starts (short, in character), or null
	var/list/tell_lines
	/// It catches everyone in an area: it never starts while someone outside the fight stands in area_turfs()
	var/area_move = FALSE
	/// Furthest a target may be for it to start, in tiles
	var/max_range = BOUNTY_FIGHT_VISION
	/// Nearest a target may be for it to start, in tiles
	var/min_range = 0
	/// How long after it fires before the NPC starts another chrome move (at least BOUNTY_CHROME_MOVE_GAP)
	var/recover_time = BOUNTY_CHROME_MOVE_GAP
	/// A mini-boss gets it as an ability in its rotation (a tell-then-fire move); a move that only plans behaviours sets FALSE
	var/boss_usable = TRUE
	/// The NPC it is in
	var/mob/living/carbon/human/npc/owner
	/// The mini-boss ability wrapping it, if its owner is a mini-boss
	var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/boss_ability
	/// world.time it last fired, 0 if never
	var/last_fired = 0
	/// Weakrefs to the marks it put down for its tell, removed when the tell ends
	var/list/marks

/datum/bounty_chrome_move/Destroy()
	clear_tell()
	if(boss_ability)
		boss_ability.move = null
		boss_ability = null
	owner = null
	return ..()

/// Goes into `npc`. Subtypes register what they need here; call parent first.
/datum/bounty_chrome_move/proc/attach(mob/living/carbon/human/npc/npc)
	owner = npc

/// Comes out of its NPC, which may be being deleted. Undo what attach() and the fight did; call parent last.
/datum/bounty_chrome_move/proc/detach()
	clear_tell()
	owner = null

/// Whether its implant can be used now: the action is there, its chrome running and off cooldown (an action-less move is always ready)
/datum/bounty_chrome_move/proc/ready()
	if(!action_type)
		return TRUE
	var/datum/action/action = bounty_chrome_action(owner, action_type)
	return !!action?.IsAvailable()

/**
 * Whether it should start on `target` now: its owner can act, the target is someone it may hit, in
 * sight and in range, the implant is ready, and for an area move nobody outside the fight stands where
 * it lands. Subtypes add their own reasons and call parent.
 */
/datum/bounty_chrome_move/proc/can_start(atom/target)
	if(!bounty_chrome_can_act(owner) || QDELETED(target) || !bounty_ai_may_hit(owner, target))
		return FALSE
	var/distance = bounty_ai_dist(owner, target)
	if(distance > max_range || distance < min_range || !bounty_ai_can_see(owner, target, max_range))
		return FALSE
	if(!ready())
		return FALSE
	if(area_move && !area_clear(target))
		return FALSE
	return TRUE

/// Whether nobody outside the fight stands where it would land on `target` (the bystander gate). A move whose implant spares its own side overrides it.
/datum/bounty_chrome_move/proc/area_clear(atom/target)
	return bounty_chrome_area_clear(owner, area_turfs(target), target)

/// The turfs it would catch if it fired on `target` now, for the bystander gate. Area moves override it.
/datum/bounty_chrome_move/proc/area_turfs(atom/target)
	return list()

/// What its action is clicked on (a click-to-activate action): `target`, or for a leap the turf to land on
/datum/bounty_chrome_move/proc/trigger_target(atom/target)
	return target

/**
 * The tell on `target`: an outline on its owner, the sound, a line. Subtypes add marks (add_mark()) and
 * call parent. Doesn't sleep.
 */
/datum/bounty_chrome_move/proc/tell(atom/target)
	if(QDELETED(owner))
		return
	owner.add_filter(tell_filter(), 2, outline_filter(1, tell_color))
	var/outline = owner.get_filter(tell_filter())
	if(outline)
		// A pulse, faint to full: the colour's own alpha, as filters have no alpha of their own
		animate(outline, color = "[tell_color]40", time = 0.15 SECONDS, loop = -1)
		animate(color = "[tell_color]ff", time = 0.15 SECONDS)
	if(tell_sound)
		playsound(owner, tell_sound, 60, TRUE)
	var/text = tell_text(target)
	if(text)
		owner.visible_message(span_danger(text))
	if(length(tell_lines))
		INVOKE_ASYNC(src, PROC_REF(say_line), pick(tell_lines))

/// What onlookers see as the tell starts, or null. Plain, in the world: "[owner]'s spine lights up."
/datum/bounty_chrome_move/proc/tell_text(atom/target)
	return null

/// Its owner says `line`. Sleeps (say()).
/datum/bounty_chrome_move/proc/say_line(line)
	if(!QDELETED(owner) && owner.stat == CONSCIOUS)
		owner.say(line, forced = "bounty chrome tell")

/// The outline's filter name, its own per move
/datum/bounty_chrome_move/proc/tell_filter()
	return "bounty_chrome_tell_[REF(src)]"

/// Keeps `thing` (a mark on the floor) until the tell ends
/datum/bounty_chrome_move/proc/add_mark(datum/thing)
	if(thing)
		LAZYADD(marks, WEAKREF(thing))
	return thing

/// Ends the tell's look: the outline and the marks go
/datum/bounty_chrome_move/proc/clear_tell()
	if(!QDELETED(owner))
		owner.remove_filter(tell_filter())
	for(var/datum/weakref/mark_ref as anything in marks)
		var/datum/thing = mark_ref.resolve()
		if(!QDELETED(thing))
			qdel(thing)
	marks = null

/// The tell is over: it fires on `target` (which may be gone by now). Returns what effect() does.
/datum/bounty_chrome_move/proc/fire(atom/target)
	last_fired = world.time
	return effect(target)

/// What it does once the tell is over: by default, Trigger() the implant's action. Returns TRUE if it did something.
/datum/bounty_chrome_move/proc/effect(atom/target)
	if(!action_type)
		return FALSE
	return bounty_chrome_trigger(owner, action_type, trigger_target(target))

/// The tell was cut short (BOUNTY_CHROME_CANCEL_*): nothing fires. The look is already gone.
/datum/bounty_chrome_move/proc/cancel(reason)
	return

/// For a move that drives behaviours itself (a grab, blades out): queue them on `controller` and return TRUE to end the planning. Called every planning tick in a fight, before any move starts.
/datum/bounty_chrome_move/proc/plan(datum/ai_controller/controller, atom/target)
	return FALSE

/// A fight starts against `target`
/datum/bounty_chrome_move/proc/on_fight_start(atom/target)
	return

/// The fight is over
/datum/bounty_chrome_move/proc/on_fight_end()
	return

/// Every Life tick of its owner (none while it is dormant); `fighting` is bounty_chrome_in_fight(), `target` who it is going for
/datum/bounty_chrome_move/proc/on_tick(seconds_per_tick, fighting, atom/target)
	return

/// Its owner went down into crit
/datum/bounty_chrome_move/proc/on_downed()
	return

/// Its owner died: end anything running
/datum/bounty_chrome_move/proc/on_death()
	return

/// An EMP of `severity` reached its owner (the implant reboots on its own timer)
/datum/bounty_chrome_move/proc/on_emp(severity)
	return

// ===== AN NPC'S CHROME, IN A FIGHT =====

/**
 * A bounty NPC's chrome moves, and the one tell it may have going. Added by bounty_chrome_equip(); adding
 * it again adds the new keys' moves. The tell is held to tg's state through signals: crit, a stun, a
 * knockdown, cuffs, death or an EMP cuts it short.
 */
/datum/component/bounty_chrome
	dupe_mode = COMPONENT_DUPE_UNIQUE_PASSARGS
	/// The piece keys it carries, in order
	var/list/keys = list()
	/// Its moves (/datum/bounty_chrome_move), one per move type of each piece
	var/list/moves = list()
	/// The move whose tell is running, or null
	var/datum/bounty_chrome_move/telling
	/// Weakref to what that tell is aimed at
	var/datum/weakref/tell_target
	/// Goes up with each tell, so a stale timer does nothing
	var/tell_serial = 0
	var/tell_timer
	/// In a fight at the last look (bounty_chrome_in_fight()), for the fight's start and end
	var/fighting = FALSE
	/// world.time its next chrome move may start
	var/next_move_at = 0

/datum/component/bounty_chrome/Initialize(list/new_keys)
	if(!ishumannpc(parent))
		return COMPONENT_INCOMPATIBLE
	add_keys(new_keys)

/datum/component/bounty_chrome/InheritComponent(datum/component/new_comp, i_am_original, list/new_keys)
	add_keys(new_keys)

/datum/component/bounty_chrome/Destroy(force)
	end_tell()
	for(var/datum/bounty_chrome_move/move as anything in moves)
		move.detach()
		qdel(move)
	moves.Cut()
	tell_target = null
	return ..()

/datum/component/bounty_chrome/RegisterWithParent()
	RegisterSignal(parent, COMSIG_LIVING_LIFE, PROC_REF(on_life))
	RegisterSignal(parent, COMSIG_HUMAN_NPC_DOWNED, PROC_REF(on_downed))
	RegisterSignal(parent, COMSIG_LIVING_DEATH, PROC_REF(on_death))
	RegisterSignal(parent, COMSIG_ATOM_EMP_ACT, PROC_REF(on_emp))
	RegisterSignals(parent, list(SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED), SIGNAL_ADDTRAIT(TRAIT_FLOORED)), PROC_REF(on_stunned))
	RegisterSignal(parent, SIGNAL_ADDTRAIT(TRAIT_RESTRAINED), PROC_REF(on_restrained))

/datum/component/bounty_chrome/UnregisterFromParent()
	UnregisterSignal(parent, list(
		COMSIG_LIVING_LIFE,
		COMSIG_HUMAN_NPC_DOWNED,
		COMSIG_LIVING_DEATH,
		COMSIG_ATOM_EMP_ACT,
		SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED),
		SIGNAL_ADDTRAIT(TRAIT_FLOORED),
		SIGNAL_ADDTRAIT(TRAIT_RESTRAINED),
	))

/// Adds the moves of the pieces `new_keys` it doesn't have yet; a mini-boss gets each as an ability in its rotation
/datum/component/bounty_chrome/proc/add_keys(list/new_keys)
	var/mob/living/carbon/human/npc/npc = parent
	for(var/key in new_keys)
		var/datum/bounty_chrome_piece/piece = GLOB.bounty_chrome_pieces[key]
		if(!piece || (key in keys))
			continue
		keys += key
		for(var/move_type in piece.move_types)
			var/datum/bounty_chrome_move/move = new move_type
			moves += move
			move.attach(npc)
			bounty_chrome_grant_boss_ability(npc, move)

/// Its move of `move_type`, or null
/datum/component/bounty_chrome/proc/move_of(move_type)
	for(var/datum/bounty_chrome_move/move as anything in moves)
		if(istype(move, move_type))
			return move
	return null

/// Notes the fight starting or ending, and tells the moves
/datum/component/bounty_chrome/proc/update_fight()
	var/now = bounty_chrome_in_fight(parent)
	if(now == fighting)
		return
	fighting = now
	if(now)
		next_move_at = max(next_move_at, world.time + BOUNTY_CHROME_OPENING)
		var/atom/target = bounty_chrome_target(parent)
		for(var/datum/bounty_chrome_move/move as anything in moves)
			move.on_fight_start(target)
		return
	interrupt(BOUNTY_CHROME_CANCEL_GONE)
	for(var/datum/bounty_chrome_move/move as anything in moves)
		move.on_fight_end()

/**
 * The bounty_chrome planning subtree's work: nothing else is planned while a tell runs (unless the move
 * keeps acting through it, tell_keeps_acting, when only no other move starts); in a fight, a
 * move that plans its own behaviours goes first, then, past the gap since the last one, a move that can
 * start does. Returns the subtree's result. Doesn't sleep.
 */
/datum/component/bounty_chrome/proc/plan(datum/ai_controller/controller, seconds_per_tick)
	if(telling)
		return telling.tell_keeps_acting ? null : SUBTREE_RETURN_FINISH_PLANNING
	update_fight()
	if(!fighting || !bounty_chrome_can_act(parent))
		return
	var/atom/target = bounty_chrome_target(parent)
	if(QDELETED(target))
		return
	for(var/datum/bounty_chrome_move/move as anything in moves)
		if(move.plan(controller, target))
			return SUBTREE_RETURN_FINISH_PLANNING
	if(world.time < next_move_at)
		return
	var/list/ready = list()
	for(var/datum/bounty_chrome_move/move as anything in moves)
		if(move.action_type && move.can_start(target))
			ready += move
	if(length(ready) && start_move(pick(ready), target))
		return SUBTREE_RETURN_FINISH_PLANNING

/**
 * Starts `move`'s tell on `target`: it stands still with its AI quiet, and after the tell the move
 * fires, unless something cuts it short. Returns TRUE if the tell started.
 */
/datum/component/bounty_chrome/proc/start_move(datum/bounty_chrome_move/move, atom/target)
	var/mob/living/carbon/human/npc/npc = parent
	if(telling || !(move in moves) || !bounty_chrome_can_act(npc))
		return FALSE
	tell_serial++
	telling = move
	tell_target = target ? WEAKREF(target) : null
	if(move.tell_holds_still)
		ADD_TRAIT(npc, TRAIT_IMMOBILIZED, BOUNTY_CHROME_TRAIT)
	if(!move.tell_keeps_acting)
		npc.ai_controller?.CancelActions()
	if(target)
		npc.face_atom(target)
	move.tell(target)
	tell_timer = addtimer(CALLBACK(src, PROC_REF(finish_tell), tell_serial), max(move.tell_time, BOUNTY_CHROME_TELL_MIN), TIMER_STOPPABLE | TIMER_DELETE_ME)
	return TRUE

/// The tell under `serial` is over: the move fires, if its owner can still act
/datum/component/bounty_chrome/proc/finish_tell(serial)
	if(serial != tell_serial || !telling)
		return FALSE
	var/datum/bounty_chrome_move/move = telling
	var/atom/target = tell_target?.resolve()
	tell_timer = null
	end_tell()
	if(!bounty_chrome_can_act(parent))
		move.cancel(BOUNTY_CHROME_CANCEL_STUNNED)
		return FALSE
	next_move_at = world.time + max(move.recover_time, BOUNTY_CHROME_MOVE_GAP)
	move.fire(target)
	return TRUE

/// Ends the running tell's hold and look, without firing or cancelling it
/datum/component/bounty_chrome/proc/end_tell()
	var/datum/bounty_chrome_move/move = telling
	telling = null
	tell_target = null
	if(tell_timer)
		deltimer(tell_timer)
		tell_timer = null
	if(!QDELETED(parent))
		REMOVE_TRAIT(parent, TRAIT_IMMOBILIZED, BOUNTY_CHROME_TRAIT)
	move?.clear_tell()

/// Cuts the running tell short for `reason` (BOUNTY_CHROME_CANCEL_*): nothing fires. A mini-boss's chrome wind-up is cut short too.
/datum/component/bounty_chrome/proc/interrupt(reason)
	var/mob/living/carbon/human/npc/bounty_criminal/boss/boss = parent
	if(istype(boss) && istype(boss.boss_winding(), /datum/action/cooldown/mob_cooldown/bounty_boss/chrome))
		boss.boss_interrupt()
	var/datum/bounty_chrome_move/move = telling
	if(!move)
		return FALSE
	end_tell()
	move.cancel(reason)
	return TRUE

/datum/component/bounty_chrome/proc/on_life(datum/source, seconds_per_tick, times_fired)
	SIGNAL_HANDLER
	update_fight()
	var/atom/target = fighting ? bounty_chrome_target(parent) : null
	for(var/datum/bounty_chrome_move/move as anything in moves)
		move.on_tick(seconds_per_tick, fighting, target)

/datum/component/bounty_chrome/proc/on_downed(datum/source)
	SIGNAL_HANDLER
	interrupt(BOUNTY_CHROME_CANCEL_DOWNED)
	for(var/datum/bounty_chrome_move/move as anything in moves)
		move.on_downed()

/datum/component/bounty_chrome/proc/on_death(datum/source, gibbed)
	SIGNAL_HANDLER
	interrupt(BOUNTY_CHROME_CANCEL_DEATH)
	fighting = FALSE
	for(var/datum/bounty_chrome_move/move as anything in moves)
		move.on_death()

/datum/component/bounty_chrome/proc/on_emp(datum/source, severity, protection)
	SIGNAL_HANDLER
	if(protection & (EMP_PROTECT_SELF | EMP_PROTECT_CONTENTS))
		return
	interrupt(BOUNTY_CHROME_CANCEL_EMP)
	for(var/datum/bounty_chrome_move/move as anything in moves)
		move.on_emp(severity)

/datum/component/bounty_chrome/proc/on_stunned(datum/source)
	SIGNAL_HANDLER
	interrupt(BOUNTY_CHROME_CANCEL_STUNNED)

/datum/component/bounty_chrome/proc/on_restrained(datum/source)
	SIGNAL_HANDLER
	interrupt(BOUNTY_CHROME_CANCEL_RESTRAINED)

/**
 * The AI's chrome: in the normal criminal's controller after bounty_fight_target (and in the
 * companion's, C4). Nothing for an NPC with no chrome moves.
 */
/datum/ai_planning_subtree/bounty_chrome

/datum/ai_planning_subtree/bounty_chrome/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/datum/component/bounty_chrome/chrome = controller.pawn?.GetComponent(/datum/component/bounty_chrome)
	if(!chrome)
		return
	return chrome.plan(controller, seconds_per_tick)

// ===== MINI-BOSSES =====

/// Gives mini-boss `npc` an ability in its rotation for `move`, if it is a mini-boss and the move is one its rotation can run
/proc/bounty_chrome_grant_boss_ability(mob/living/carbon/human/npc/npc, datum/bounty_chrome_move/move)
	var/mob/living/carbon/human/npc/bounty_criminal/boss/boss = npc
	if(!istype(boss) || !move.boss_usable || !move.action_type || move.boss_ability)
		return null
	var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/ability = new(boss)
	ability.set_move(move)
	ability.Grant(boss)
	boss.boss_abilities += ability
	return ability

/**
 * A mini-boss's chrome move as one of its abilities, so its rotation, its busy rule and its interrupts
 * (tg's stuns, crit, cuffs) run it the way they run its kit's: the wind-up is the move's tell, the effect
 * the implant's action.
 */
/datum/action/cooldown/mob_cooldown/bounty_boss/chrome
	name = "Chrome"
	desc = "A wanted criminal's chrome."
	cooldown_time = BOUNTY_CHROME_MOVE_GAP
	/// The move it runs, one of its boss's own (/datum/component/bounty_chrome)
	var/datum/bounty_chrome_move/move

/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/Destroy()
	if(move?.boss_ability == src)
		move.boss_ability = null
	move = null
	return ..()

/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/proc/set_move(datum/bounty_chrome_move/new_move)
	move = new_move
	new_move.boss_ability = src
	name = new_move.name
	windup = max(new_move.tell_time, BOUNTY_CHROME_TELL_MIN)
	cooldown_time = max(new_move.recover_time, BOUNTY_CHROME_MOVE_GAP)

/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/worth_using(atom/target)
	return ..() && move && move.owner == owner && move.can_start(target)

/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/telegraph(atom/target)
	move?.tell(target)

/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/effect(atom/target)
	if(!move)
		return
	move.clear_tell()
	move.fire(target)

/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/finish_windup(serial)
	var/pending = serial && serial == pending_serial
	. = ..()
	// Its boss couldn't act when the wind-up ended: the tell's look goes too
	if(pending && !. && move)
		move.clear_tell()
		move.cancel(BOUNTY_CHROME_CANCEL_STUNNED)

/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/cancel_windup()
	var/pending = pending_serial
	. = ..()
	if(pending && move)
		move.clear_tell()
		move.cancel(BOUNTY_CHROME_CANCEL_STUNNED)

// ===== A MALFUNCTION =====

/**
 * A bounty NPC's body with chrome in it, as others notice it: an EMP that knocks a piece out shows the
 * malfunction (bounty_chrome_malfunction_fx()) for as long as the piece takes to reboot, and a chrome read
 * is felt and answered (bounty_chrome_read_noticed()). On every criminal, decoys included (they carry
 * their fugitive's chrome and must answer the same way), and on chromed companions.
 */
/datum/element/bounty_chrome_body
	element_flags = ELEMENT_DETACH_ON_HOST_DESTROY

/datum/element/bounty_chrome_body/Attach(datum/target)
	. = ..()
	if(!ishumannpc(target))
		return ELEMENT_INCOMPATIBLE
	// Added again by bounty_chrome_equip() to a criminal that already has it: the same hooks
	RegisterSignal(target, COMSIG_ATOM_EMP_ACT, PROC_REF(on_emp), override = TRUE)
	RegisterSignal(target, COMSIG_CARBON_CHROME_READ, PROC_REF(on_read), override = TRUE)

/datum/element/bounty_chrome_body/Detach(datum/source)
	UnregisterSignal(source, list(COMSIG_ATOM_EMP_ACT, COMSIG_CARBON_CHROME_READ))
	return ..()

/datum/element/bounty_chrome_body/proc/on_emp(mob/living/carbon/human/npc/source, severity, protection)
	SIGNAL_HANDLER
	if(protection & (EMP_PROTECT_SELF | EMP_PROTECT_CONTENTS))
		return
	// The chrome takes the pulse after this signal (/mob/living/emp_act()): look a moment later
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(bounty_chrome_check_malfunction), WEAKREF(source)), 1)

/datum/element/bounty_chrome_body/proc/on_read(mob/living/carbon/human/npc/source, mob/living/carbon/reader)
	SIGNAL_HANDLER
	bounty_chrome_read_noticed(source, reader)

/// Whatever chrome of `npc_ref`'s an EMP just knocked out shows it, for as long as the longest reboot
/proc/bounty_chrome_check_malfunction(datum/weakref/npc_ref)
	var/mob/living/carbon/human/npc/npc = npc_ref?.resolve()
	if(QDELETED(npc) || npc.stat == DEAD)
		return
	var/longest = 0
	for(var/obj/item/organ/organ in npc.organs)
		var/datum/component/cyberware/chrome = organ.GetComponent(/datum/component/cyberware)
		if(!chrome?.emp_down)
			continue
		longest = max(longest, chrome.emp_timer ? timeleft(chrome.emp_timer) : 0)
	if(longest <= 0)
		return
	var/fresh = !npc.has_status_effect(/datum/status_effect/bounty_chrome_malfunction)
	bounty_chrome_malfunction_fx(npc, longest)
	if(fresh)
		npc.visible_message(span_warning("[npc]'s chrome sparks and stutters!"))

/**
 * Shows `npc`'s chrome malfunctioning for `duration`: arcs crawling over the body, tg's EMP sparkle, a
 * flickering chrome-blue outline and light, twitches, and sparks spat onto the tiles around them with a
 * crackle. Only a picture: nothing is hurt, set alight or switched off by it. A longer one extends it.
 */
/proc/bounty_chrome_malfunction_fx(mob/living/npc, duration)
	if(QDELETED(npc) || npc.stat == DEAD || duration <= 0)
		return null
	return npc.apply_status_effect(/datum/status_effect/bounty_chrome_malfunction, duration)

/// The arcs over a malfunctioning body, and their glow in the dark when `body` is given. For the overlay and the renders.
/proc/bounty_chrome_malfunction_arcs(atom/body)
	. = list()
	var/mutable_appearance/arcs = mutable_appearance('icons/effects/effects.dmi', "electricity", ABOVE_MOB_LAYER)
	arcs.color = BOUNTY_CHROME_MALFUNCTION_MATRIX
	. += arcs
	. += mutable_appearance('icons/effects/effects.dmi', "empdisable", ABOVE_MOB_LAYER)
	if(body)
		. += emissive_appearance('icons/effects/effects.dmi', "electricity", body)

/// The look of bounty_chrome_malfunction_fx(), for its duration. Purely visual; it ends early if they die.
/datum/status_effect/bounty_chrome_malfunction
	id = "bounty_chrome_malfunction"
	duration = 4 SECONDS
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
	// A corpse's chrome is burnt out: the look ends the moment it dies
	RegisterSignal(owner, COMSIG_LIVING_DEATH, PROC_REF(on_owner_death))
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

/datum/status_effect/bounty_chrome_malfunction/proc/on_owner_death(datum/source, gibbed)
	SIGNAL_HANDLER
	qdel(src)

/datum/status_effect/bounty_chrome_malfunction/on_remove()
	UnregisterSignal(owner, COMSIG_LIVING_DEATH)
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

// ===== A CHROME READ =====

/mob/living/carbon/human/npc
	/// world.time it may next answer a chrome read (bounty_chrome_read_noticed())
	var/chrome_read_answer_at = 0

/**
 * `reader` just read `npc`'s chrome with cyber optics, and it felt it (COMSIG_CARBON_CHROME_READ,
 * cyberware_scan.dm): one that isn't fighting turns to the reader and tells them off, at most once every
 * BOUNTY_CHROME_READ_NOTICE_COOLDOWN. Never while hiding. Everyone at a trader outpost answers the same
 * way, the fugitive and its decoys alike. Returns TRUE if it answers. Doesn't sleep.
 */
/proc/bounty_chrome_read_noticed(mob/living/carbon/human/npc/npc, mob/living/reader)
	if(!ishumannpc(npc) || !isliving(reader) || reader == npc || world.time < npc.chrome_read_answer_at)
		return FALSE
	if(npc.stat != CONSCIOUS || npc.client || bounty_chrome_in_fight(npc) || !length(cyberware_scannable_hardware(npc)))
		return FALSE
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = npc
	if(istype(criminal) && criminal.hidden)
		return FALSE
	npc.chrome_read_answer_at = world.time + BOUNTY_CHROME_READ_NOTICE_COOLDOWN
	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(bounty_chrome_answer_read), npc, reader)
	return TRUE

/// `npc` looks round at `reader` and says something about being read. Sleeps (say()).
/proc/bounty_chrome_answer_read(mob/living/carbon/human/npc/npc, mob/living/reader)
	if(QDELETED(npc) || QDELETED(reader) || npc.stat != CONSCIOUS)
		return
	if(isturf(npc.loc) && !npc.buckled && npc.body_position == STANDING_UP)
		npc.face_atom(reader)
	npc.say(pick("Who said you could scan me?", "Stop reading me, creep.", "Quit scanning me.", "Eyes off my chrome."), forced = "bounty chrome read")
