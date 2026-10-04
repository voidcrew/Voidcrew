/**
 * # Outpost NPC looks
 *
 * Human-looking basic mobs on outposts (prisoners, guards, and ambient NPCs) wear an outfit on
 * a human body. tg's set_dynamic_human_appearance() builds that body on a fixed, bald, pale dummy
 * and caches one appearance per outfit, so everyone in the same outfit has the same face and a
 * male body whatever their gender.
 *
 * Here each look is a random person: skin tone, hair, facial hair and eyes, on a body that matches
 * the gender. A look is keyed by outfit, gender and a look number from 1 to OUTPOST_NPC_LOOK_COUNT,
 * built once on a throwaway dummy and cached, so a crowd costs at most OUTPOST_NPC_LOOK_COUNT x 2
 * appearances per outfit. Ambient NPCs that hold something also get a look built with a real item
 * in the dummy's hand (get_outpost_held_look()), bounded so an unusual held item never grows the
 * cache without limit.
 */

/// Held looks kept before the oldest is dropped
#define OUTPOST_NPC_HELD_LOOKS_MAX 200

/// Keys of built held looks in GLOB.outpost_npc_looks, oldest first
GLOBAL_LIST_EMPTY(outpost_npc_held_look_keys)

/// How many different people wear each outfit, per gender
#define OUTPOST_NPC_LOOK_COUNT 8
/// Chance a man's look has a beard or moustache
#define OUTPOST_NPC_FACIAL_HAIR_CHANCE 55

/// Built looks by outpost_npc_look_key()
GLOBAL_LIST_EMPTY(outpost_npc_looks)

/// A look number to give a new NPC
/proc/random_outpost_npc_look_number()
	return rand(1, OUTPOST_NPC_LOOK_COUNT)

/// The cache key of a look. Anything but FEMALE gets a male body.
/proc/outpost_npc_look_key(outfit_path, gender, look_number)
	return "[outfit_path]|[gender == FEMALE ? FEMALE : MALE]|[look_number]"

/**
 * The appearance of person `look_number` of `gender` wearing `outfit_path`, built the first time
 * it is asked for. Building equips an outfit, which can sleep, so call this from an async proc.
 */
/proc/get_outpost_npc_look(outfit_path, gender, look_number)
	gender = gender == FEMALE ? FEMALE : MALE
	var/key = outpost_npc_look_key(outfit_path, gender, look_number)
	var/look = GLOB.outpost_npc_looks[key]
	if(look)
		return look
	var/mob/living/carbon/human/dummy/dummy = new_outpost_npc_dummy(gender)
	if(outfit_path)
		dummy.equipOutfit(outfit_path, visuals_only = TRUE)
	look = dummy.appearance
	qdel(dummy)
	// Two NPCs can build the same look at once; the first one built is kept.
	if(!GLOB.outpost_npc_looks[key])
		GLOB.outpost_npc_looks[key] = look
	return GLOB.outpost_npc_looks[key]

/**
 * The appearance of person `look_number` of `gender` wearing `outfit_path`, holding `held_type` (an
 * /obj/item type) in hand, built the first time it is asked for. A `held_type` that is not an item
 * returns the plain look, with nothing in hand. Can sleep; see get_outpost_npc_look().
 */
/proc/get_outpost_held_look(outfit_path, gender, look_number, held_type)
	if(!ispath(held_type, /obj/item))
		return get_outpost_npc_look(outfit_path, gender, look_number)
	gender = gender == FEMALE ? FEMALE : MALE
	var/key = "[outpost_npc_look_key(outfit_path, gender, look_number)]|held|[held_type]"
	var/look = GLOB.outpost_npc_looks[key]
	if(look)
		return look
	var/mob/living/carbon/human/dummy/dummy = new_outpost_npc_dummy(gender)
	if(outfit_path)
		dummy.equipOutfit(outfit_path, visuals_only = TRUE)
	set_outpost_worker_visors(dummy, up = TRUE)
	var/obj/item/thing = new held_type(null)
	if(!dummy.put_in_r_hand(thing, visuals_only = TRUE))
		dummy.put_in_l_hand(thing, visuals_only = TRUE)
	look = dummy.appearance
	qdel(thing)
	qdel(dummy)
	// Two NPCs can build the same held look at once; the first one built is kept.
	if(!GLOB.outpost_npc_looks[key])
		outpost_npc_held_look_cache_add(key, look)
	return GLOB.outpost_npc_looks[key]

/// Caches `look` under `key`, dropping the oldest held look once there are more than `most`. An NPC already wearing an evicted look keeps it: their overlays hold the built appearance.
/proc/outpost_npc_held_look_cache_add(key, look, most = OUTPOST_NPC_HELD_LOOKS_MAX)
	GLOB.outpost_npc_looks[key] = look
	GLOB.outpost_npc_held_look_keys += key
	while(length(GLOB.outpost_npc_held_look_keys) > most)
		var/oldest_key = GLOB.outpost_npc_held_look_keys[1]
		GLOB.outpost_npc_held_look_keys.Cut(1, 2)
		GLOB.outpost_npc_looks -= oldest_key

/// A new random person of `gender` (MALE or FEMALE), undressed, to build looks on. The caller deletes it.
/proc/new_outpost_npc_dummy(gender)
	var/mob/living/carbon/human/dummy/dummy = new
	// As get_dynamic_human_appearance() does: a dead dummy skips mob spawner side effects.
	dummy.stat = DEAD
	randomize_human_normie(dummy, update_body = FALSE)
	dummy.gender = gender
	dummy.physique = gender
	dummy.set_hairstyle(outpost_npc_hairstyle(gender) || dummy.hairstyle, update = FALSE)
	var/facial_hair = "Shaved"
	if(gender == MALE && prob(OUTPOST_NPC_FACIAL_HAIR_CHANCE))
		facial_hair = outpost_npc_facial_hairstyle() || facial_hair
	dummy.set_facial_hairstyle(facial_hair, update = FALSE)
	dummy.skin_tone = pick(GLOB.skin_tones)
	dummy.underwear = "Nude"
	dummy.undershirt = "Nude"
	dummy.socks = "Nude"
	// Without is_creating the limbs keep the skin tone they were made with.
	dummy.update_body(is_creating = TRUE)
	return dummy

/**
 * Person `look_number` of `gender` in `outfit_path`, three ways, for NPCs that work
 * (outpost_ambient_work.dm): "idle" with free hands and any welding visor up, "weld" with a lit
 * welder and the visor down, and "tool" with a wrench. All three are one person on one dummy.
 * Can sleep, like get_outpost_npc_look().
 */
/proc/get_outpost_worker_looks(outfit_path, gender, look_number)
	gender = gender == FEMALE ? FEMALE : MALE
	var/key = "[outpost_npc_look_key(outfit_path, gender, look_number)]|work"
	var/list/looks = GLOB.outpost_npc_looks[key]
	if(looks)
		return looks
	var/mob/living/carbon/human/dummy/dummy = new_outpost_npc_dummy(gender)
	if(outfit_path)
		dummy.equipOutfit(outfit_path, visuals_only = TRUE)
	looks = list()
	set_outpost_worker_visors(dummy, up = FALSE)
	var/obj/item/weldingtool/welder = new
	welder.set_welding(TRUE)
	welder.update_appearance()
	dummy.put_in_r_hand(welder, visuals_only = TRUE)
	looks["weld"] = dummy.appearance
	qdel(welder)
	set_outpost_worker_visors(dummy, up = TRUE)
	looks["idle"] = dummy.appearance
	var/obj/item/wrench/wrench = new
	dummy.put_in_r_hand(wrench, visuals_only = TRUE)
	looks["tool"] = dummy.appearance
	qdel(wrench)
	qdel(dummy)
	if(!GLOB.outpost_npc_looks[key])
		GLOB.outpost_npc_looks[key] = looks
	return GLOB.outpost_npc_looks[key]

/// Raises or lowers every welding visor `wearer` has on
/proc/set_outpost_worker_visors(mob/living/carbon/human/wearer, up)
	var/changed = FALSE
	for(var/obj/item/clothing/gear in list(wearer.head, wearer.glasses, wearer.wear_mask))
		if(!(gear.visor_vars_to_toggle & VISOR_FLASHPROTECT) || gear.up == up)
			continue
		gear.visor_toggling()
		changed = TRUE
	if(changed)
		wearer.regenerate_icons()

/**
 * Dresses `target` as person `look_number` of `gender` wearing `outfit_path`, the way
 * set_dynamic_human_appearance() dresses a mob. Can sleep; see get_outpost_npc_look().
 */
/proc/set_outpost_npc_look(atom/target, outfit_path, gender, look_number)
	apply_outpost_npc_look(target, get_outpost_npc_look(outfit_path, gender, look_number))

/// Dresses `target` in a built look
/proc/apply_outpost_npc_look(atom/target, look)
	if(QDELETED(target) || !look)
		return
	target.icon = 'icons/mob/human/human.dmi'
	target.icon_state = ""
	target.appearance_flags |= KEEP_TOGETHER
	target.copy_overlays(look, cut_old = TRUE)

/// A random hairstyle that randomize_human_normie() would give, or null
/proc/outpost_npc_hairstyle(gender)
	for(var/attempt in 1 to 10)
		var/style_name = random_hairstyle(gender)
		var/datum/sprite_accessory/style = SSaccessories.hairstyles_list[style_name]
		if(style?.natural_spawn && !style.locked)
			return style_name
	return null

/// A random beard or moustache that randomize_human_normie() would give, or null
/proc/outpost_npc_facial_hairstyle()
	for(var/attempt in 1 to 10)
		var/style_name = random_facial_hairstyle(MALE)
		var/datum/sprite_accessory/style = SSaccessories.facial_hairstyles_list[style_name]
		if(style?.icon_state && style.natural_spawn && !style.locked)
			return style_name
	return null

#undef OUTPOST_NPC_LOOK_COUNT
#undef OUTPOST_NPC_FACIAL_HAIR_CHANCE
#undef OUTPOST_NPC_HELD_LOOKS_MAX
