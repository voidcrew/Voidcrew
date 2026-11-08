/**
 * # Human NPCs
 *
 * A human NPC is a real /mob/living/carbon/human driven by an AI (human_npc_ai.dm). Everything a
 * player's body does, it does through the same tg code: wounds, bleeding, dismemberment, soft and hard
 * crit, suffocation, stamina damage and stamcrit, stuns, cuffs, grabs, pulling, death, revival,
 * organ decay, and the hyperviolence gore and executions. There are no stand-in states, health
 * pools or heals. Phases B-E of the human NPC migration build pirates, troopers, hermits and bounty
 * criminals on this type; the developer notes are in the kit vault (modules/human_npcs.md).
 *
 * Making one: spawn_human_npc() (human_npc_spawning.dm) queues it, so a wave is built a body or two
 * per tick, never all at once. Maps place /obj/effect/spawner/human_npc. A subtype sets its look,
 * outfit, name, faction, rank, toughness and death drops with the vars below.
 *
 * What differs from a player's body, and why. These are the only deviations:
 * - Dormancy (performance). Life() does nothing while no player is on the NPC's z-level, alive or
 *   dead (npc_dormant()), the same test tg uses to switch the AI off. While dormant nothing in Life()
 *   runs: bleeding, wound and organ processing, metabolism, breathing, body temperature, pressure,
 *   crit oxygen loss, natural healing, disease. A dormant NPC is frozen in time; a wounded one doesn't
 *   bleed out until someone arrives. A corpse that wakes catches up the organ decay it missed while
 *   dormant (npc_catch_up_decay()), so the defib window and organ rot match a player's corpse; its
 *   body temperature is not caught up. Stamina recovery is a timer, not Life(), so it is not paused.
 *   This has to be a guard on this type's own Life(): COMSIG_LIVING_LIFE's cancel flag only stops
 *   /mob/living/Life(), and carbon and human Life() run organs, wounds, limbs and temperature around it.
 * - No mood datum and TRAIT_NOHUNGER (performance, and an NPC never eats over a 6 hour round).
 * - Gear lock (owner decision D3, human_npc_gear.dm): its kit can't be stripped, dropped or looted.
 * - Aimed crits and gun executions only from elites and bosses (owner decision D4, npc_rank).
 */
/mob/living/carbon/human/npc
	name = "stranger"
	faction = list(FACTION_HOSTILE)
	ai_controller = /datum/ai_controller/basic_controller/human_npc
	/// What it wears and holds: an outfit typepath. Weapons go in its r_hand and l_hand, spare
	/// magazines in pockets or belt_contents, an air tank with internals_slot set.
	var/datum/outfit/npc_outfit
	/**
	 * How it looks. Null: an ordinary random person of the default species. A
	 * /obj/effect/mob_spawn typepath: that spawner's species, hair and skin, and its outfit if
	 * npc_outfit is unset (the corpse spawners of today's NPCs). spawn_human_npc(look =) also takes a
	 * /datum/bounty_look or a /datum/bounty_record.
	 */
	var/npc_look
	/// Its name. Null keeps the random name its look rolled.
	var/npc_name
	/// HUMAN_NPC_RANK_*. Only elites and bosses land aimed crits and gun executions.
	var/npc_rank = HUMAN_NPC_RANK_REGULAR
	/**
	 * Toughness: brute and burn damage taken is multiplied by this, through the body's physiology,
	 * as species and cyberware do it for players. Never touches stamina or stuns. 1 is a person.
	 * Change it on a live NPC with set_npc_toughness().
	 */
	var/npc_damage_taken = 1
	/// A /datum/armor added to the body's own physiology armour (dermal plating on a player). Null for none.
	var/datum/armor/npc_body_armor
	/**
	 * Cyberware organ typepaths installed at spawn (voidcrew/modules/cyberware/). It works as it does
	 * in a player: a dodge shunt dodges, plating armours, a brownout browns out. It burns out to scrap
	 * when the NPC dies or the ware is taken out of it (owner ruling), so it is never salvaged working.
	 */
	var/list/npc_cyberware
	/// Opens an air tank it carries if it has a mask or helmet that takes one and its outfit didn't.
	var/npc_internals = TRUE
	/// Typepaths spawned under it the first time it dies (its designed loot). Never a second time.
	var/list/npc_death_loot
	/// Credits dropped as a holochip the first time it dies.
	var/npc_death_cash = 0
	/// How long its corpse lies before SShuman_npcs may delete it once nobody is near. 0: never; the
	/// system that owns the NPC cleans it up.
	var/npc_corpse_lifetime = HUMAN_NPC_CORPSE_LIFETIME
	/// Apply the dormancy and life trims. Only the measurement harness turns this off.
	var/npc_trim_life = TRUE

	/// TRUE once its death loot has dropped
	var/npc_loot_dropped = FALSE
	/// world.time it last died, or 0
	var/npc_died_at = 0
	/// world.time its current dormant spell began, or 0 while awake
	var/npc_dormant_since = 0
	/// The damage multiplier set_npc_toughness() last applied
	var/npc_damage_taken_applied = 1
	/// Weakrefs to limbs and organs that came off it, cleaned up with its corpse
	var/list/datum/weakref/npc_remains

/mob/living/carbon/human/npc/Initialize(mapload, datum/human_npc_order/order)
	. = ..()
	if(npc_trim_life)
		ADD_TRAIT(src, TRAIT_NOHUNGER, INNATE_TRAIT)
	npc_dress(order)
	for(var/ware_type in npc_cyberware)
		npc_install_cyberware(ware_type)
	npc_conceal_presence()
	npc_lock_all_gear()
	for(var/obj/item/held as anything in held_items)
		if(held)
			human_npc_ready_weapon(src, held)
	npc_open_internals()
	set_npc_toughness(npc_damage_taken)
	if(npc_body_armor)
		physiology.armor = physiology.armor.add_other_armor(npc_body_armor)
	AddElement(/datum/element/human_npc_body)

/mob/living/carbon/human/npc/Destroy()
	SShuman_npcs?.forget_corpse(src)
	npc_remains = null
	return ..()

/mob/living/carbon/human/npc/setup_mood()
	if(npc_trim_life)
		return
	return ..()

// ===== DORMANCY =====

/mob/living/carbon/human/npc/Life(seconds_per_tick = SSMOBS_DT, times_fired)
	if(npc_trim_life)
		if(npc_dormant())
			npc_dormant_since ||= world.time
			return FALSE
		if(npc_dormant_since)
			npc_catch_up_decay((world.time - npc_dormant_since) / (1 SECONDS), times_fired)
			npc_dormant_since = 0
#ifdef HUMAN_NPC_SPIKE_HARNESS
	GLOB.human_npc_spike_life_passes++
#endif
	return ..()

/// TRUE while this NPC's Life() should not run: no player is on its z-level.
/mob/living/carbon/human/npc/proc/npc_dormant()
	return !npc_players_on_level()

/// Whether any living player shares this NPC's z-level. Same test as get_expected_ai_status().
/mob/living/carbon/human/npc/proc/npc_players_on_level()
	var/turf/our_turf = get_turf(src)
	if(isnull(our_turf))
		return FALSE
	return length(SSmobs.clients_by_zlevel[our_turf.z]) > 0

/**
 * A corpse that slept for `slept_seconds` decays its organs for that long at once, through tg's own
 * handle_organs() (which skips frozen and robotic organs and bodies kept in formaldehyde or
 * cryostylane), so its defib window closes when a player's would. A living NPC catches nothing up.
 */
/mob/living/carbon/human/npc/proc/npc_catch_up_decay(slept_seconds, times_fired)
	if(stat != DEAD || slept_seconds <= 0 || HAS_TRAIT(src, TRAIT_STASIS))
		return
	handle_organs(slept_seconds, times_fired)

// ===== DRESSING =====

/// Puts on its look, outfit, name and faction. `order` may override the type's own.
/mob/living/carbon/human/npc/proc/npc_dress(datum/human_npc_order/order)
	var/look = order?.look || npc_look
	var/outfit = order?.outfit || npc_outfit
	var/datum/bounty_record/record
	if(istype(look, /datum/bounty_record))
		record = look
		look = bounty_ensure_look(record)
	if(ispath(look, /obj/effect/mob_spawn))
		var/spawner_outfit = npc_apply_spawner_look(look)
		outfit ||= spawner_outfit
	else if(istype(look, /datum/bounty_look))
		npc_apply_bounty_look(look)
	else
		npc_apply_random_look()
	// Plasmamen and other species that need their own kit to live get it first, as from a spawner.
	dna.species.give_important_for_life(src)
	// Dressed directly, not through /obj/effect/mob_spawn/equip(), whose ladder strip
	// (voidcrew/edits/mobs/ladder_outfits.dm) would delete the guns an NPC fights with.
	if(outfit)
		equipOutfit(outfit)
	if(record)
		bounty_wear_features(src, record.features)
	var/new_name = order?.name || npc_name
	if(new_name)
		fully_replace_character_name(real_name, new_name)
	if(length(order?.faction))
		faction = order.faction.Copy()

/// An ordinary random person, as tg's corpse spawners make them.
/mob/living/carbon/human/npc/proc/npc_apply_random_look()
	randomize_human_normie(src, update_body = FALSE)
	update_body(is_creating = TRUE)

/// The look of a /obj/effect/mob_spawn typepath, applied the way its special() applies it. Returns its outfit.
/mob/living/carbon/human/npc/proc/npc_apply_spawner_look(obj/effect/mob_spawn/spawner)
	var/datum/species/species = initial(spawner.mob_species)
	if(ispath(species, /datum/species) && dna.species.type != species)
		set_species(species)
	underwear = "Nude"
	undershirt = "Nude"
	socks = "Nude"
	randomize_human_normie(src, update_body = FALSE)
	var/hairstyle = initial(spawner.hairstyle)
	if(hairstyle)
		set_hairstyle(hairstyle, update = FALSE)
	var/facial_hairstyle = initial(spawner.facial_hairstyle)
	if(facial_hairstyle)
		set_facial_hairstyle(facial_hairstyle, update = FALSE)
	var/haircolor = initial(spawner.haircolor)
	if(haircolor)
		set_haircolor(haircolor, update = FALSE)
	var/facial_haircolor = initial(spawner.facial_haircolor)
	if(facial_haircolor)
		set_facial_haircolor(facial_haircolor, update = FALSE)
	var/spawner_skin = initial(spawner.skin_tone)
	if(spawner_skin)
		skin_tone = spawner_skin
	update_body(is_creating = TRUE)
	return initial(spawner.outfit)

/// A bounty record's face (voidcrew/modules/bounties/), applied in the order bounty_dress_dummy() uses.
/mob/living/carbon/human/npc/proc/npc_apply_bounty_look(datum/bounty_look/look)
	// Before the species: its visible organs take their shape from dna.features as they go in.
	for(var/feature in look.features)
		dna.features[feature] = look.features[feature]
	gender = look.physique == FEMALE ? FEMALE : MALE
	physique = gender
	if(ispath(look.species, /datum/species) && dna.species.type != look.species)
		set_species(look.species)
	if(look.skin_tone)
		skin_tone = look.skin_tone
	set_hairstyle(look.hairstyle || "Bald", update = FALSE)
	if(look.hair_color)
		set_haircolor(look.hair_color, update = FALSE)
	set_facial_hairstyle(look.facial_hairstyle || "Shaved", update = FALSE)
	if(look.facial_hair_color || look.hair_color)
		set_facial_haircolor(look.facial_hair_color || look.hair_color, update = FALSE)
	if(look.eye_color)
		set_eye_color(look.eye_color)
	underwear = "Nude"
	undershirt = "Nude"
	socks = "Nude"
	update_body(is_creating = TRUE)

/// Keeps its PDA off messenger lists and its suit sensors off crew monitors, as corpse spawners do.
/mob/living/carbon/human/npc/proc/npc_conceal_presence()
	var/obj/item/modular_computer/pda/messenger = locate() in src
	if(messenger)
		var/datum/computer_file/program/messenger/message_app = locate() in messenger.stored_files
		if(message_app)
			message_app.invisible = TRUE
	var/obj/item/clothing/under/sensor_clothes = w_uniform
	if(istype(sensor_clothes))
		sensor_clothes.sensor_mode = SENSOR_OFF
		update_suit_sensors()

/// Turns on an air tank it wears, if it has something to breathe it through, the way a player does.
/mob/living/carbon/human/npc/proc/npc_open_internals()
	if(!npc_internals || internal || !can_breathe_internals())
		return
	for(var/obj/item/tank/internals/tank in get_equipped_items(INCLUDE_POCKETS | INCLUDE_HELD))
		if(open_internals(tank))
			return

/**
 * Sets how much brute and burn damage it takes, as a multiple of a person's. Scales the
 * physiology mods it set before, so other changes to them (species, implants) are kept.
 */
/mob/living/carbon/human/npc/proc/set_npc_toughness(damage_taken)
	if(damage_taken <= 0)
		CRASH("[src] ([type]) was given a damage multiplier of [damage_taken]")
	var/change = damage_taken / npc_damage_taken_applied
	physiology.brute_mod *= change
	physiology.burn_mod *= change
	npc_damage_taken_applied = damage_taken
	npc_damage_taken = damage_taken

// ===== RULES OF ENGAGEMENT =====

// The strip menu never opens on a human NPC (D3). Carrying and dragging are unaffected.
/mob/living/carbon/human/npc/should_strip(mob/user)
	return FALSE

// D4: an NPC's hits become aimed crits and executions only if it is an elite or a boss, or a
// person is driving the body.
/mob/living/carbon/human/npc/hv_can_land_aimed_crits()
	return client || npc_rank >= HUMAN_NPC_RANK_ELITE

/mob/living/carbon/human/npc/Login()
	. = ..()
	// A player in control of the body (a brain transplant) can't keep its gear (D3). Admins
	// driving an NPC for an event keep it.
	if(!. || isnull(client) || client.holder)
		return
	npc_delete_locked_gear()

// ===== DEATH AND REMAINS =====

/mob/living/carbon/human/npc/death(gibbed)
	if(stat == DEAD)
		return ..()
	. = ..()
	if(stat != DEAD)
		return
	npc_died_at = world.time
	npc_drop_death_loot()
	npc_drop_not_gear()
	npc_burn_out_chrome()
	if(!gibbed && npc_corpse_lifetime && !QDELING(src))
		SShuman_npcs.track_corpse(src)

/// Drops its designed loot under it, once in its life however often it dies.
/mob/living/carbon/human/npc/proc/npc_drop_death_loot()
	if(npc_loot_dropped)
		return
	npc_loot_dropped = TRUE
	var/atom/drop_spot = drop_location()
	if(isnull(drop_spot))
		return
	// As death_drops does for basic mobs (voidcrew/edits/mobs/weapon_drops.dm): admin-spawned NPCs drop no guns.
	var/no_guns = (flags_1 & ADMIN_SPAWNED_1) || npc_spawn_context?.suppress_gun_loot
	for(var/loot_type in npc_roll_death_loot())
		if(no_guns && ispath(loot_type, /obj/item/gun))
			continue
		new loot_type(drop_spot)
	if(npc_death_cash > 0)
		new /obj/item/holochip(drop_spot, npc_death_cash)

/// The typepaths it drops on its first death. Override to roll them (zone ladders, rare pools).
/mob/living/carbon/human/npc/proc/npc_roll_death_loot()
	return npc_death_loot

/// Back from the dead (defib, strange reagent): no longer a corpse to clean up.
/mob/living/carbon/human/npc/proc/npc_revived()
	npc_died_at = 0
	SShuman_npcs.forget_corpse(src)

/// A limb or organ came off: remember it, so it goes when the corpse does.
/mob/living/carbon/human/npc/proc/npc_lost_part(obj/item/part)
	LAZYADD(npc_remains, WEAKREF(part))

// ===== CYBERWARE =====

/**
 * Installs a cyberware organ at spawn, the way the cyberware code's own staging inserts do
 * (special = TRUE skips the install-context gate; the brownout monitor still applies). Returns the
 * organ, or null if it didn't go in.
 */
/mob/living/carbon/human/npc/proc/npc_install_cyberware(ware_type)
	var/obj/item/organ/ware = new ware_type()
	if(!ware.GetComponent(/datum/component/cyberware))
		stack_trace("[type] was given [ware_type] as cyberware, which isn't chrome")
		qdel(ware)
		return null
	if(!ware.Insert(src, special = TRUE))
		qdel(ware)
		return null
	return ware

/// Owner ruling: an NPC's chrome burns out when it dies. Every piece comes out and turns to scrap.
/mob/living/carbon/human/npc/proc/npc_burn_out_chrome()
	var/atom/drop_spot = drop_location()
	var/burnt = 0
	for(var/obj/item/organ/ware in organs.Copy())
		if(!ware.GetComponent(/datum/component/cyberware))
			continue
		ware.Remove(src, special = TRUE)
		if(drop_spot)
			ware.forceMove(drop_spot)
		human_npc_burn_out_chrome(ware)
		burnt++
	if(burnt && drop_spot)
		do_sparks(min(burnt, 3), TRUE, src)
		visible_message(span_warning("[src]'s chrome sparks and goes dead."))

/// Turns a piece of a human NPC's chrome that has left its body into scrap where it lies.
/proc/human_npc_burn_out_chrome(obj/item/organ/ware)
	if(QDELETED(ware) || ware.owner)
		return
	var/turf/floor = get_turf(ware)
	if(isnull(floor))
		qdel(ware)
		return
	var/mob/living/holder = ismob(ware.loc) ? ware.loc : null
	var/obj/item/burnt_chrome/scrap = new(floor, ware)
	qdel(ware)
	holder?.put_in_hands(scrap)

/// What a human NPC's cyberware leaves once it burns out: scrap, never a working implant.
/obj/item/burnt_chrome
	name = "burnt-out chrome"
	desc = "Cyberware fused black inside. Only good for scrap."
	icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	icon_state = "scrapper"
	w_class = WEIGHT_CLASS_SMALL
	color = "#4a4a4a"
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT)

/obj/item/burnt_chrome/Initialize(mapload, obj/item/organ/ware)
	. = ..()
	if(isnull(ware))
		return
	name = "burnt-out [format_text(ware.name)]"
	icon = ware.icon
	icon_state = ware.icon_state

/**
 * Listens to a human NPC's body for the base type. An element, not RegisterSignal(src) on the mob,
 * so a subtype can register these signals on itself without replacing the base's handlers.
 */
/datum/element/human_npc_body
	element_flags = ELEMENT_DETACH_ON_HOST_DESTROY

/datum/element/human_npc_body/Attach(datum/target)
	. = ..()
	if(!ishumannpc(target))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_CARBON_REMOVE_LIMB, PROC_REF(on_lost_limb))
	RegisterSignal(target, COMSIG_CARBON_LOSE_ORGAN, PROC_REF(on_lost_organ))
	RegisterSignal(target, COMSIG_LIVING_REVIVE, PROC_REF(on_revived))

/datum/element/human_npc_body/Detach(datum/source)
	UnregisterSignal(source, list(COMSIG_CARBON_REMOVE_LIMB, COMSIG_CARBON_LOSE_ORGAN, COMSIG_LIVING_REVIVE))
	return ..()

/datum/element/human_npc_body/proc/on_lost_limb(mob/living/carbon/human/npc/source, obj/item/bodypart/limb, special, dismembered)
	SIGNAL_HANDLER
	if(!special)
		source.npc_lost_part(limb)

/datum/element/human_npc_body/proc/on_lost_organ(mob/living/carbon/human/npc/source, obj/item/organ/organ, special)
	SIGNAL_HANDLER
	// Chrome taken out of an NPC, by surgery, a lost limb, gibbing or dusting, burns out like it does at
	// death. Next tick, once whatever moved it has put it down.
	if(organ.GetComponent(/datum/component/cyberware))
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(human_npc_burn_out_chrome), organ), 0)
		return
	if(!special)
		source.npc_lost_part(organ)

/datum/element/human_npc_body/proc/on_revived(mob/living/carbon/human/npc/source, full_heal_flags)
	SIGNAL_HANDLER
	source.npc_revived()

/**
 * Whether its corpse may be cleaned up now: dead for npc_corpse_lifetime, with no player within
 * HUMAN_NPC_CORPSE_WATCH_RANGE, and not being dragged, carried or held.
 */
/mob/living/carbon/human/npc/proc/npc_corpse_expired()
	if(stat != DEAD || !npc_corpse_lifetime || !npc_died_at)
		return FALSE
	if(world.time < npc_died_at + npc_corpse_lifetime)
		return FALSE
	if(pulledby || buckled || ismob(loc))
		return FALSE
	return !human_npc_watched(src)

/// Deletes its corpse, and the limbs and organs it lost that lie unwatched on the floor.
/mob/living/carbon/human/npc/proc/npc_fade()
	for(var/datum/weakref/remain_ref as anything in npc_remains)
		var/obj/item/remain = remain_ref.resolve()
		if(QDELETED(remain) || !isturf(remain.loc) || remain.pulledby)
			continue
		var/obj/item/bodypart/limb = remain
		if(istype(limb) && limb.owner)
			continue
		var/obj/item/organ/organ = remain
		if(istype(organ) && organ.owner)
			continue
		if(human_npc_watched(remain))
			continue
		qdel(remain)
	npc_remains = null
	qdel(src)

/// Whether a player is within HUMAN_NPC_CORPSE_WATCH_RANGE of `thing`.
/proc/human_npc_watched(atom/thing)
	var/turf/spot = get_turf(thing)
	if(isnull(spot) || !length(SSmobs.clients_by_zlevel[spot.z]))
		return FALSE
	for(var/mob/viewer as anything in SSspatial_grid.orthogonal_range_search(spot, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS, HUMAN_NPC_CORPSE_WATCH_RANGE))
		if(get_dist(viewer, spot) <= HUMAN_NPC_CORPSE_WATCH_RANGE)
			return TRUE
	return FALSE

/// Whether tg weather should act on `candidate`, a mob that has never had a mind: a human NPC that
/// isn't dormant. Read by the mind gates in tg's weather code.
/proc/human_npc_weathered(mob/living/candidate)
	if(!ishumannpc(candidate))
		return FALSE
	var/mob/living/carbon/human/npc/npc = candidate
	return !npc.npc_dormant()
