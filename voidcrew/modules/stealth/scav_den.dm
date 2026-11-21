/**
 * # The scav den (stealth step 4, owner decisions 3, 6, 10, 11, 21, 38)
 *
 * A compound of organ and cyberware harvesters dug into an asteroid. It is a rare space ruin and never seeds by itself.
 * For now the only way to it is the admin verb "Stealth: Scav Den Planet" (stealth_den_planet.dm), which loads it on a
 * jungle planet; the verb and the den stay in the game as an admin test tool.
 *
 * The tip below (a rumor chart bought from an outpost trader and revealed from the helm, rumor_charts.dm) is on no
 * shop. If it goes back on sale: one den is on the overmap at a time, so while one is out there the tip is off the
 * shelf and a sealed chart can't be revealed (it stays sealed until that den is gone), and a den nobody docks at within
 * an hour of its reveal leaves the overmap. scav_den_on_map() only counts dens on the overmap, not one the admin verb
 * built on a planet; decide then whether that one should hold the slot.
 *
 * The den's guards are the stealth guards of scav_guards.dm with names of their own, so their friends can call them
 * by name on the radio and over a body. Their skill comes from the den's zone (decision 38): a den revealed in the
 * contested lanes is yellow. The boss, a lookout, carries the only vault pass. The vault's crate rolls cyberware by
 * the den's zone, plus one piece of stealth gear from scav_vault_stealth_loot() if any module adds one (none does yet).
 *
 * Cameras: scav_camera.dm.
 */

// ===== The ruin =====

/datum/map_template/ruin/space/rare/scav_den
	id = "rare_scav_den"
	suffix = "rare_scav_den.dmm"
	name = "Scav Chop Shop"
	description = "A scav crew's den dug into a hollow rock. They take spacers apart for their organs and their chrome, and the best of it sits in the boss's vault."

/// The live den on the overmap, if there is one
/proc/scav_den_on_map()
	for(var/obj/structure/overmap/space_ruin/ruin as anything in GLOB.space_ruin_signals)
		if(!QDELETED(ruin) && istype(ruin.ruin_template, /datum/map_template/ruin/space/rare/scav_den))
			return ruin
	return null

// ===== The tip =====
// Not on sale anywhere yet (owner, 2026-11-20): the den is reached only through the admin verb in
// stealth_den_planet.dm. Add this SKU back to a shop's chart_pool to sell it.

/datum/shop_sku/ruin_chart/scav_den
	name = "contested-lane tip: scav chop shop"
	desc = "A scav crew working out of a hollow rock, buying people off the lanes and selling them back in pieces. They keep their best chrome in the boss's vault. Uploaded sealed to your helm."
	price_vouchers = 1
	price_credits = 3600
	spawn_zone = ZONE_YELLOW
	ruin_template_path = /datum/map_template/ruin/space/rare/scav_den
	chart_type = /datum/rumor_chart/scav_den
	rumor_name = "Scav chop shop"
	rumor_desc = "Scavs in a hollow rock on the contested lanes, buying people and selling them back in pieces. The boss keeps the good chrome locked up."

/datum/shop_sku/ruin_chart/scav_den/get_denial_reason(mob/living/user)
	. = ..()
	if(.)
		return
	if(scav_den_on_map())
		return "That crew's already been sold out. Wait for the dust to settle."

/// A sealed den chart. It only opens while no other den is on the overmap.
/datum/rumor_chart/scav_den

/datum/rumor_chart/scav_den/reveal(obj/structure/overmap/ship/ship)
	if(scav_den_on_map())
		return null
	. = ..()
	if(.)
		scav_den_claim(.)

/// Sets up a den the moment it's revealed.
/proc/scav_den_claim(obj/structure/overmap/space_ruin/den)
	// No contract may hold it on the chart: a held den would rebuild fresh (guards, vault and all) on the next visit.
	den.mission_exclusive = TRUE
	// A den nobody ever flies to would hold the one-den slot for the round: the scavs move on.
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(scav_den_move_on), WEAKREF(den)), 60 MINUTES)

/// Takes a revealed den off the overmap if nobody has docked at it (its interior was never built) in the hour since.
/proc/scav_den_move_on(datum/weakref/den_ref)
	var/obj/structure/overmap/space_ruin/den = den_ref?.resolve()
	if(QDELETED(den) || den.mapzone || den.loading || den.loaded)
		return
	log_mapping("Scav den '[den.name]' at ([den.x], [den.y]) was never visited and moved on.")
	qdel(den)

// ===== Guards with names =====

/// Den guards keep the random name their look gave them instead of their type's ("Scav Guard"), so the radio and
/// their friends can name them (stealth_first_name()).
/mob/living/carbon/human/npc/ruin/trooper/scav/den
	npc_name = null
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/scav_den

/mob/living/carbon/human/npc/ruin/trooper/scav/den/npc_dress(datum/human_npc_order/order)
	. = ..()
	scav_den_name_self()
	scav_den_chrome_eyes()

/mob/living/carbon/human/npc/ruin/trooper/scav/gunner/den
	npc_name = null
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/scav_den/gunner

/mob/living/carbon/human/npc/ruin/trooper/scav/gunner/den/npc_dress(datum/human_npc_order/order)
	. = ..()
	scav_den_name_self()
	scav_den_chrome_eyes()

/mob/living/carbon/human/npc/ruin/trooper/scav/lookout/den
	npc_name = null
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/scav_den/gunner

/mob/living/carbon/human/npc/ruin/trooper/scav/lookout/den/npc_dress(datum/human_npc_order/order)
	. = ..()
	scav_den_name_self()
	scav_den_chrome_eyes()

/// The den's boss: a lookout with the vault pass, dressed as the head harvester.
/mob/living/carbon/human/npc/ruin/trooper/scav/lookout/den/boss
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/scav_den/boss

/mob/living/carbon/human/npc/ruin/trooper/scav/lookout/den/boss/npc_dress(datum/human_npc_order/order)
	. = ..()
	var/obj/item/card/id/card = wear_id
	if(istype(card) && !istype(card, /obj/item/card/id/advanced/black/scav/vault))
		var/obj/item/card/id/vault_card = new /obj/item/card/id/advanced/black/scav/vault(src)
		vault_card.registered_name = real_name
		qdel(card)
		equip_to_slot_or_del(vault_card, ITEM_SLOT_ID)

/**
 * Gives a den guard a person's name if its look left it without one. Its look (a random person) names it, and with
 * npc_name null that name stays; its pass is made out to it.
 */
/mob/living/carbon/human/npc/proc/scav_den_name_self()
	if(real_name && real_name != initial(name) && real_name != "Unknown")
		return
	fully_replace_character_name(real_name, generate_random_mob_name())
	var/obj/item/card/id/card = wear_id?.GetID()
	if(istype(card, /obj/item/card/id/advanced/black/scav))
		card.registered_name = real_name

/**
 * Gives a den guard chrome eyes that glow red. tg's own robotic eyes (they flash and EMP like anyone's), recoloured;
 * the glow is only drawn, it lights nothing. Behind glasses or a mask that hides the eyes it doesn't show. Like the rest
 * of an NPC's chrome they burn out when it dies (scav_den_eyes_burn_out()), so a den is no eye farm.
 */
/mob/living/carbon/human/npc/proc/scav_den_chrome_eyes()
	var/obj/item/organ/eyes/robotic/chrome = new()
	chrome.eye_color_left = "#ff2a1a"
	chrome.eye_color_right = "#ff2a1a"
	chrome.overlay_ignore_lighting = TRUE
	if(!chrome.Insert(src, special = TRUE, movement_flags = DELETE_IF_REPLACED))
		qdel(chrome)
		return
	// npc_burn_out_chrome() only knows cyberware; these are plain tg eyes, so they listen for the death themselves.
	chrome.RegisterSignal(src, COMSIG_LIVING_DEATH, TYPE_PROC_REF(/obj/item/organ/eyes/robotic, scav_den_eyes_burn_out))
	update_body()
	// A balaclava's eye holes don't line up with bare eyes: a masked guard without lenses gets the gang's red ones.
	if(istype(wear_mask, /obj/item/clothing/mask/balaclava) && isnull(glasses))
		equip_to_slot_or_del(new /obj/item/clothing/glasses/red(src), ITEM_SLOT_EYES)

/// A den guard died with its red chrome eyes in: they go dead and come out as scrap, like the rest of an NPC's chrome.
/obj/item/organ/eyes/robotic/proc/scav_den_eyes_burn_out(mob/living/carbon/source, gibbed)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_LIVING_DEATH)
	if(owner != source)
		return
	var/atom/drop_spot = source.drop_location()
	Remove(source, special = TRUE)
	if(isnull(drop_spot))
		qdel(src)
		return
	forceMove(drop_spot)
	human_npc_burn_out_chrome(src)
	do_sparks(1, TRUE, source)

// ===== The den guards' look =====
// A chrome-mad harvester gang. The scavs' fatigues go under everything (scav_guards.dm), and every outfit leaves the
// mask slot free for the scav balaclava, so a guard still carries the disguise set (stealth_disguise.dm). The suits here
// are read into stealth_guard_suits(). Armour by zone never goes above the old sword and gunner tables.

/// Rippers: leather and a knife, red lenses.
/datum/outfit/ruin_npc/scav_den
	name = "Ruin NPC: den ripper"
	uniform = /obj/item/clothing/under/syndicate/scav
	suit = /obj/item/clothing/suit/jacket/leather/biker
	shoes = /obj/item/clothing/shoes/jackboots
	gloves = /obj/item/clothing/gloves/fingerless
	glasses = /obj/item/clothing/glasses/red
	r_hand = /obj/item/knife/combat/survival

/datum/outfit/ruin_npc/scav_den/vest
	name = "Ruin NPC: den ripper in plates"
	suit = /obj/item/clothing/suit/armor/vest
	r_hand = /obj/item/knife/combat

/datum/outfit/ruin_npc/scav_den/vest/helmet
	name = "Ruin NPC: den ripper, red zone"
	head = /obj/item/clothing/head/helmet
	l_pocket = /obj/item/reagent_containers/hypospray/medipen

/// Harvesters: the ones who do the cutting. Bloodied waders and black gloves, and a cleaver or a bone saw; no lenses over the chrome.
/datum/outfit/ruin_npc/scav_den/butcher
	name = "Ruin NPC: den harvester"
	suit = /obj/item/clothing/suit/apron/waders
	gloves = /obj/item/clothing/gloves/color/black
	head = /obj/item/clothing/head/utility/surgerycap/black
	glasses = null
	r_hand = /obj/item/knife/butcher

/datum/outfit/ruin_npc/scav_den/butcher/saw
	name = "Ruin NPC: den harvester with a saw"
	r_hand = /obj/item/circular_saw/cruel

/datum/outfit/ruin_npc/scav_den/butcher/saw/red
	name = "Ruin NPC: den harvester, red zone"
	l_pocket = /obj/item/reagent_containers/hypospray/medipen

/// Blood on the apron, the gloves and the blade.
/datum/outfit/ruin_npc/scav_den/butcher/post_equip(mob/living/carbon/human/user, visuals_only = FALSE)
	. = ..()
	var/list/blood = user.get_blood_dna_list()
	if(!length(blood))
		return
	for(var/obj/item/stained in list(user.gloves, user.wear_suit) + user.held_items)
		stained.add_blood_DNA(blood)
	user.update_clothing(ITEM_SLOT_GLOVES | ITEM_SLOT_OCLOTHING | ITEM_SLOT_HANDS)

/// Gunners: a cheap Makarov, or a mini Uzi in the red zone.
/datum/outfit/ruin_npc/scav_den/gunner
	name = "Ruin NPC: den gunner"
	suit = /obj/item/clothing/suit/jacket/leather
	r_hand = /obj/item/gun/ballistic/automatic/pistol
	l_pocket = /obj/item/ammo_box/magazine/m9mm
	r_pocket = /obj/item/ammo_box/magazine/m9mm

/datum/outfit/ruin_npc/scav_den/gunner/vest
	name = "Ruin NPC: den gunner in plates"
	suit = /obj/item/clothing/suit/armor/vest

/datum/outfit/ruin_npc/scav_den/gunner/vest/helmet
	name = "Ruin NPC: den gunner, red zone"
	head = /obj/item/clothing/head/helmet
	r_hand = /obj/item/gun/ballistic/automatic/mini_uzi
	l_pocket = /obj/item/ammo_box/magazine/uzim9mm
	r_pocket = /obj/item/ammo_box/magazine/uzim9mm

/// The head harvester: the butcher's apron with a pistol.
/datum/outfit/ruin_npc/scav_den/butcher/boss
	name = "Ruin NPC: den head harvester"
	r_hand = /obj/item/gun/ballistic/automatic/pistol
	l_pocket = /obj/item/ammo_box/magazine/m9mm
	r_pocket = /obj/item/ammo_box/magazine/m9mm

/datum/outfit/ruin_npc/scav_den/butcher/boss/smg
	name = "Ruin NPC: den head harvester, red zone"
	r_hand = /obj/item/gun/ballistic/automatic/mini_uzi
	l_pocket = /obj/item/ammo_box/magazine/uzim9mm
	r_pocket = /obj/item/ammo_box/magazine/uzim9mm

/// Den blades: rippers and harvesters, half and half.
/datum/human_npc_outfit_table/ruin/scav_den
	green = list(/datum/outfit/ruin_npc/scav_den = 1, /datum/outfit/ruin_npc/scav_den/butcher = 1)
	yellow = list(/datum/outfit/ruin_npc/scav_den/vest = 1, /datum/outfit/ruin_npc/scav_den/butcher/saw = 1)
	red = list(/datum/outfit/ruin_npc/scav_den/vest/helmet = 1, /datum/outfit/ruin_npc/scav_den/butcher/saw/red = 1)

/// Den guns: SMGs only in the red zone (the trooper weapon ladder).
/datum/human_npc_outfit_table/ruin/scav_den/gunner
	green = list(/datum/outfit/ruin_npc/scav_den/gunner = 1)
	yellow = list(/datum/outfit/ruin_npc/scav_den/gunner/vest = 1)
	red = list(/datum/outfit/ruin_npc/scav_den/gunner/vest/helmet = 1)

/datum/human_npc_outfit_table/ruin/scav_den/boss
	green = list(/datum/outfit/ruin_npc/scav_den/butcher/boss = 1)
	yellow = list(/datum/outfit/ruin_npc/scav_den/butcher/boss = 1)
	red = list(/datum/outfit/ruin_npc/scav_den/butcher/boss/smg = 1)

// ===== The den's trash =====

/**
 * tg's garbage without anything a guard trips over on its rounds: no banana peels (botanical_waste), no armed
 * mousetraps, and no glass shards, broken bottles or broken lights (caltrops). Broken glass is a floor decal here.
 */
/obj/effect/spawner/random/trash/garbage/scav_den
	name = "den garbage spawner"
	loot = list(
		/obj/effect/spawner/random/trash/food_packaging = 20,
		/obj/item/trash/can = 15,
		/obj/effect/decal/cleanable/glass = 15,
		/obj/effect/spawner/random/trash/cigbutt = 10,
		/obj/effect/spawner/random/trash/bacteria = 5,
		/obj/effect/spawner/random/trash/crushed_can = 5,
		/obj/item/reagent_containers/cup/glass/drinkingglass = 5,
		/obj/item/stack/cable_coil = 5,
		/obj/item/grown/corncob = 2,
		/obj/item/food/deadmouse = 1,
		/obj/item/trash/candle = 1,
		/obj/item/rag = 1,
		/obj/item/trash/flare = 1,
		/obj/item/popsicle_stick = 1,
		/obj/item/reagent_containers/syringe = 1,
		/obj/item/reagent_containers/cup/glass/sillycup = 1,
	)

/obj/effect/spawner/human_npc/ruin/scav/den
	name = "den guard spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/scav/den

/obj/effect/spawner/human_npc/ruin/scav/den/gunner
	name = "den gunner spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/scav/gunner/den

/obj/effect/spawner/human_npc/ruin/scav/den/lookout
	name = "den lookout spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/scav/lookout/den

/obj/effect/spawner/human_npc/ruin/scav/den/boss
	name = "den boss spawner"
	npc_type = /mob/living/carbon/human/npc/ruin/trooper/scav/lookout/den/boss

// ===== The vault =====

/// The boss's pass: the den's doors and the vault.
/obj/item/card/id/advanced/black/scav/vault
	name = "scav pass"
	desc = "A scratched black card on a cord, punched with a den's mark. This one has a second hole punched through it."
	access = list(ACCESS_SCAV, ACCESS_SCAV_VAULT)

/**
 * The boss's crate. Rolls when first opened, by the zone of the den it was mapped in (moving it doesn't change it):
 * cyberware the harvesters pulled or bought, more and better further out, and one piece of stealth gear when
 * scav_vault_stealth_loot() has any. Everything in it can be found or bought elsewhere too.
 */
/obj/structure/closet/crate/secure/scav_vault
	name = "chrome crate"
	desc = "A heavy crate lined with foam. Somebody has scratched a tally of names into the lid."
	icon_state = "weaponcrate"
	base_icon_state = "weaponcrate"
	req_access = list(ACCESS_SCAV_VAULT)
	/// The turf it was mapped on: its zone is read there
	var/turf/spawn_turf
	/// Set once it has rolled
	var/vault_rolled = FALSE

/obj/structure/closet/crate/secure/scav_vault/Initialize(mapload)
	spawn_turf = get_turf(src)
	return ..()

/obj/structure/closet/crate/secure/scav_vault/Destroy()
	spawn_turf = null
	return ..()

/obj/structure/closet/crate/secure/scav_vault/PopulateContents()
	. = ..()
	if(vault_rolled)
		return
	vault_rolled = TRUE
	var/zone = SSovermap_zones?.get_zone_type_anywhere(spawn_turf) || ZONE_GREEN
	spawn_turf = null
	scav_vault_roll(zone)

/**
 * The stealth-gear hook: typepath => weight of stealth gear a vault may pay, one piece per vault. Empty here. Other
 * modules (the garrotte, the gun-fu chip) add theirs by overriding this proc on this type with `. = ..()` and adding
 * entries to the list.
 */
/obj/structure/closet/crate/secure/scav_vault/proc/scav_vault_stealth_loot()
	return list()

/**
 * Fills it with a den vault's take for `zone`: cyberware drawn without repeats (2 in green, 3 in yellow, 4 in red),
 * the better shelf more often further out, and one stealth piece if there are any. Returns what it made.
 */
/obj/structure/closet/crate/secure/scav_vault/proc/scav_vault_roll(zone)
	var/atom/destination = src
	. = list()
	var/list/street = list(
		/obj/item/organ/cyberimp/cyberware/gecko = 4,
		/obj/item/organ/cyberimp/cyberware/dermal_mesh = 4,
		/obj/item/organ/cyberimp/cyberware/shock_coils = 4,
		/obj/item/organ/cyberimp/cyberware/chromatic_dermis = 4,
		/obj/item/organ/cyberimp/cyberware/cargo_cavity = 4,
		/obj/item/organ/cyberimp/cyberware/second_wind = 4,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw = 4,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/fixers = 4,
		/obj/item/organ/eyes/robotic/cyberware/prospector = 3,
		/obj/item/organ/heart/cybernetic = 3,
		/obj/item/organ/liver/cybernetic/tier2 = 3,
		/obj/item/organ/lungs/cybernetic/tier2 = 3,
	)
	var/list/pro = list(
		/obj/item/organ/cyberimp/cyberware/slipwire = 3,
		/obj/item/organ/cyberimp/cyberware/slabskin = 3,
		/obj/item/organ/cyberimp/cyberware/hemoglass = 3,
		/obj/item/organ/cyberimp/cyberware/doppler = 3,
		/obj/item/organ/cyberimp/cyberware/dead_channel = 3,
		/obj/item/organ/eyes/robotic/cyberware/nightshade = 3,
		/obj/item/organ/eyes/robotic/cyberware/deadeye = 3,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/icepick = 3,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/skyhook = 3,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/angler = 3,
		/obj/item/organ/cyberimp/cyberware/ghostskin = 2,
		/obj/item/organ/cyberimp/cyberware/hopper = 2,
		/obj/item/organ/cyberimp/cyberware/atlas = 2,
	)
	var/draws = 2
	var/pro_chance = 25
	switch(zone)
		if(ZONE_YELLOW)
			draws = 3
			pro_chance = 40
		if(ZONE_RED)
			draws = 4
			pro_chance = 60
	for(var/draw in 1 to draws)
		var/list/shelf = (prob(pro_chance) && length(pro)) ? pro : street
		if(!length(shelf))
			shelf = length(pro) ? pro : street
		if(!length(shelf))
			break
		var/picked = pick_weight(shelf)
		shelf -= picked
		. += new picked(destination)
	var/list/stealth = scav_vault_stealth_loot()
	if(length(stealth))
		var/stealth_path = pick_weight(stealth)
		if(ispath(stealth_path, /atom/movable))
			. += new stealth_path(destination)
