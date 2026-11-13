/**
 * # Outpost police: units
 *
 * Owner: P2. The officer bodies (types are declared in police_core.dm: /police/beat, /sergeant, /officer,
 * /tactical, /marshal), their kit, the three zone profiles and the police cuffs. Spec 5.1 and 5.5.
 *
 * An officer is a real human NPC (voidcrew/modules/human_npcs/) and an ambient outpost NPC. They take damage,
 * bleed, crit, get cuffed and die through tg's own code, like a player. What is different, all documented
 * here:
 * - Their kit is locked to their body (human_npc_gear.dm) and they drop nothing when killed or gibbed: no
 *   cash, no loot, no item a player can hold (abuse M8). The ID card carries ACCESS_OUTPOST_POLICE, which
 *   opens the police doors, and it is locked like the rest.
 * - Hitting one is a police matter, not the base NPC's "violence at the outpost" report: on_attacked() hands
 *   the blow to police.officer_struck() and a cuff attempt goes to police.officer_cuff_attempt() (abuse M3).
 * - They never duck, flee or take cover as bystanders (abuse M17).
 * - Their leash is the whole outpost (concourse, lobby and hangars), not the concourse the base NPC keeps to.
 */

// =========================================================================
// PROFILES
// =========================================================================

/**
 * The base profile dresses its officers as Halcyon's do, so an outpost with no profile of its own (a test's
 * plain outpost) still has officers in uniform. The three zones below set every var.
 */
/datum/outpost_police_profile
	outfits = list(
		POLICE_UNIT_BEAT = /datum/outfit/outpost_police/beat/halcyon,
		POLICE_UNIT_SERGEANT = /datum/outfit/outpost_police/sergeant/halcyon,
		POLICE_UNIT_OFFICER = /datum/outfit/outpost_police/officer/halcyon,
		POLICE_UNIT_TACTICAL = /datum/outfit/outpost_police/tactical/halcyon,
		POLICE_UNIT_MARSHAL = /datum/outfit/outpost_police/marshal/halcyon,
	)

/// Waystation Halcyon (green): by the book, navy, spares the downed
/datum/outpost_police_profile/halcyon
	force_name = "Halcyon Security"
	beat_count = 3
	fine_multiplier = 1
	comply_time = 4 SECONDS
	spares_downed = TRUE
	voice_section = "halcyon"

/// Quartermain Depot (yellow): clipped, corporate grey, spares the downed
/datum/outpost_police_profile/quartermain
	force_name = "Quartermain Depot Security"
	beat_count = 2
	fine_multiplier = 1.5
	comply_time = 3 SECONDS
	spares_downed = TRUE
	voice_section = "quartermain"
	outfits = list(
		POLICE_UNIT_BEAT = /datum/outfit/outpost_police/beat/quartermain,
		POLICE_UNIT_SERGEANT = /datum/outfit/outpost_police/sergeant/quartermain,
		POLICE_UNIT_OFFICER = /datum/outfit/outpost_police/officer/quartermain,
		POLICE_UNIT_TACTICAL = /datum/outfit/outpost_police/tactical/quartermain,
		POLICE_UNIT_MARSHAL = /datum/outfit/outpost_police/marshal/quartermain,
	)

/// The Undertow Exchange (red): bored, mean, black, finishes the downed
/datum/outpost_police_profile/undertow
	force_name = "the Exchange's security"
	beat_count = 2
	fine_multiplier = 2
	comply_time = 2 SECONDS
	spares_downed = FALSE
	voice_section = "undertow"
	outfits = list(
		POLICE_UNIT_BEAT = /datum/outfit/outpost_police/beat/undertow,
		POLICE_UNIT_SERGEANT = /datum/outfit/outpost_police/sergeant/undertow,
		POLICE_UNIT_OFFICER = /datum/outfit/outpost_police/officer/undertow,
		POLICE_UNIT_TACTICAL = /datum/outfit/outpost_police/tactical/undertow,
		POLICE_UNIT_MARSHAL = /datum/outfit/outpost_police/marshal/undertow,
	)

/// The profile for this outpost's zone (called once, from /datum/outpost_police/New())
/datum/outpost_police/proc/make_profile()
	if(istype(outpost, /obj/structure/overmap/trader_outpost/general))
		return new /datum/outpost_police_profile/halcyon
	if(istype(outpost, /obj/structure/overmap/trader_outpost/outfitter))
		return new /datum/outpost_police_profile/quartermain
	if(istype(outpost, /obj/structure/overmap/trader_outpost/black_market))
		return new /datum/outpost_police_profile/undertow
	return new /datum/outpost_police_profile

// =========================================================================
// ID
// =========================================================================

/**
 * What an officer's ID carries. The access is a plain string no tg trim knows, so it has to come from a trim
 * of its own: a card takes a trim's access as it is, while one added to a card afterwards is asked to fit a
 * wildcard slot, finds none for a string tg has no flag for, and is refused.
 */
/datum/id_trim/outpost_police
	assignment = "Outpost Security"
	trim_state = "trim_securityofficer"
	department_color = COLOR_SECURITY_RED
	subdepartment_color = COLOR_SECURITY_RED
	sechud_icon_state = SECHUD_SECURITY_OFFICER
	access = list(ACCESS_OUTPOST_POLICE)

// =========================================================================
// KIT
// =========================================================================

/**
 * The cuffs an officer carries. Putting them on someone always dispenses a fresh pair (/used) and keeps the
 * officer's own, so the pair in the belt is never lost. The pair on the suspect is DROPDEL: it is gone the
 * moment it comes off, so nobody ends up holding police cuffs (abuse M8). Never sold, printed or crafted.
 */
/obj/item/restraints/handcuffs/outpost_police
	name = "security handcuffs"
	desc = "Handcuffs with a security stamp."
	custom_price = null
	custom_materials = null
	trashtype = /obj/item/restraints/handcuffs/outpost_police/used

/**
 * Tg's apply_cuffs() with `dispense` forced on, but without taking the officer's own pair out of its hand
 * first (tg does that before it looks at `dispense`, which leaves a pair held in a hand sitting unslotted in
 * the officer). The suspect gets the same thing: a pair of `trashtype` on their wrists.
 */
/obj/item/restraints/handcuffs/outpost_police/apply_cuffs(mob/living/carbon/target, mob/user, dispense = FALSE)
	if(target.handcuffed)
		return
	target.equip_to_slot(new trashtype(), ITEM_SLOT_HANDCUFFED)

/// The pair on a suspect. Gone when it comes off, and it cuffs nobody itself.
/obj/item/restraints/handcuffs/outpost_police/used
	item_flags = parent_type::item_flags | DROPDEL
	trashtype = null

/obj/item/restraints/handcuffs/outpost_police/used/attack()
	return

/obj/item/restraints/handcuffs/outpost_police/used/apply_cuffs(mob/living/carbon/target, mob/user, dispense = FALSE)
	return

/// Security belt storage that also holsters an officer's miniature energy sidearm so both pockets stay empty
/datum/storage/security_belt/outpost_police

/datum/storage/security_belt/outpost_police/New(atom/parent, max_slots, max_specific_storage, max_total_storage, rustle_sound, remove_rustle_sound)
	. = ..()
	set_holdable(list(
		/obj/item/ammo_box,
		/obj/item/ammo_casing/shotgun,
		/obj/item/assembly/flash/handheld,
		/obj/item/clothing/glasses,
		/obj/item/clothing/gloves,
		/obj/item/flashlight/seclite,
		/obj/item/food/donut,
		/obj/item/grenade,
		/obj/item/gun/energy/e_gun/mini,
		/obj/item/holosign_creator/security,
		/obj/item/knife/combat,
		/obj/item/melee/baton,
		/obj/item/radio,
		/obj/item/reagent_containers/spray/pepper,
		/obj/item/restraints/handcuffs,
		/obj/item/restraints/legcuffs/bola,
	))

/// Security belt worn by outpost officers: holds baton, cuffs and sidearm without using a pocket
/obj/item/storage/belt/security/outpost_police
	storage_type = /datum/storage/security_belt/outpost_police

// ----- outfits -----
// Built from clothing that already exists (npc-outfit skill), each worn look checked on a mannequin.
// Every outfit has a uniform, so each one equips on its own (tg's outfit_sanity test builds them all).
// Halcyon is navy, Quartermain corporate grey, the Undertow black. The ID, headset, baton, cuffs and an
// energy gun are on every officer; response officers add a vest, a helmet and sunglasses; the tactical
// officer and the marshal add a gas mask, flash-proof eyewear and a ballistic long gun (abuse M5: no gas
// or flash trick, and no energy weapon for an EMP to take).

/// Every officer: radio, an ID that opens the police doors, and a belt with baton, cuffs and sidearm (pockets empty)
/datum/outfit/outpost_police
	name = "Outpost Police"
	uniform = /obj/item/clothing/under/rank/security/officer/spacepol
	shoes = /obj/item/clothing/shoes/jackboots
	gloves = /obj/item/clothing/gloves/color/black
	ears = /obj/item/radio/headset/headset_sec
	belt = /obj/item/storage/belt/security/outpost_police
	belt_contents = list(
		/obj/item/melee/baton/security/loaded = 1,
		/obj/item/restraints/handcuffs/outpost_police = 1,
		/obj/item/gun/energy/e_gun/mini = 1,
	)
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/outpost_police

// ----- beat officers: the uniform and a cap -----

/datum/outfit/outpost_police/beat
	name = "Outpost Police: beat officer"

/datum/outfit/outpost_police/beat/halcyon
	name = "Outpost Police: Halcyon beat officer"
	head = /obj/item/clothing/head/hats/warden/police

/datum/outfit/outpost_police/beat/quartermain
	name = "Outpost Police: Quartermain beat officer"
	uniform = /obj/item/clothing/under/rank/security/officer/grey
	head = /obj/item/clothing/head/soft/sec

/datum/outfit/outpost_police/beat/undertow
	name = "Outpost Police: Undertow beat officer"
	uniform = /obj/item/clothing/under/syndicate
	head = /obj/item/clothing/head/soft/black

// ----- desk sergeants: the beat look under a drill hat -----

/datum/outfit/outpost_police/sergeant
	name = "Outpost Police: desk sergeant"
	head = /obj/item/clothing/head/hats/warden/drill

/datum/outfit/outpost_police/sergeant/halcyon
	name = "Outpost Police: Halcyon desk sergeant"

/datum/outfit/outpost_police/sergeant/quartermain
	name = "Outpost Police: Quartermain desk sergeant"
	uniform = /obj/item/clothing/under/rank/security/officer/grey

/datum/outfit/outpost_police/sergeant/undertow
	name = "Outpost Police: Undertow desk sergeant"
	uniform = /obj/item/clothing/under/syndicate

// ----- response officers: a vest, a helmet and sunglasses (abuse M5) -----

/datum/outfit/outpost_police/officer
	name = "Outpost Police: response officer"
	glasses = /obj/item/clothing/glasses/sunglasses

/datum/outfit/outpost_police/officer/halcyon
	name = "Outpost Police: Halcyon response officer"
	suit = /obj/item/clothing/suit/armor/vest/blueshirt
	head = /obj/item/clothing/head/helmet/blueshirt

/datum/outfit/outpost_police/officer/quartermain
	name = "Outpost Police: Quartermain response officer"
	uniform = /obj/item/clothing/under/rank/security/officer/grey
	suit = /obj/item/clothing/suit/armor/vest/alt/sec
	head = /obj/item/clothing/head/helmet/sec

/datum/outfit/outpost_police/officer/undertow
	name = "Outpost Police: Undertow response officer"
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/armor/vest/leather
	head = /obj/item/clothing/head/helmet/alt

// ----- tactical officers: riot armour, a gas mask, a flash-proof visor and the zone's long gun -----

/// The shared tactical kit. Spare rounds ride in a backpack, a flashbang joins the belt, the long gun is in hand.
/datum/outfit/outpost_police/tactical
	name = "Outpost Police: tactical officer"
	suit = /obj/item/clothing/suit/armor/riot
	mask = /obj/item/clothing/mask/gas/sechailer
	glasses = /obj/item/clothing/glasses/sunglasses
	back = /obj/item/storage/backpack/security
	belt_contents = list(
		/obj/item/melee/baton/security/loaded = 1,
		/obj/item/restraints/handcuffs/outpost_police = 1,
		/obj/item/gun/energy/e_gun/mini = 1,
		/obj/item/grenade/flashbang = 1,
	)

/// Halcyon's ballistic rifle
/datum/outfit/outpost_police/tactical/halcyon
	name = "Outpost Police: Halcyon tactical officer"
	head = /obj/item/clothing/head/helmet/blueshirt
	r_hand = /obj/item/gun/ballistic/automatic/ar
	backpack_contents = list(/obj/item/ammo_box/magazine/m223 = 3)

/// Quartermain's combat shotgun
/datum/outfit/outpost_police/tactical/quartermain
	name = "Outpost Police: Quartermain tactical officer"
	uniform = /obj/item/clothing/under/rank/security/officer/grey
	head = /obj/item/clothing/head/helmet/sec
	r_hand = /obj/item/gun/ballistic/shotgun/automatic/combat
	backpack_contents = list(/obj/item/storage/box/lethalshot = 2)

/// The Undertow's WT-550
/datum/outfit/outpost_police/tactical/undertow
	name = "Outpost Police: Undertow tactical officer"
	uniform = /obj/item/clothing/under/syndicate
	head = /obj/item/clothing/head/helmet/alt
	r_hand = /obj/item/gun/ballistic/automatic/wt550
	backpack_contents = list(/obj/item/ammo_box/magazine/wt550m9 = 3)

// ----- the marshal: heavy plate, and the same long gun as the zone's tactical officer -----

/datum/outfit/outpost_police/marshal
	name = "Outpost Police: marshal"
	suit = /obj/item/clothing/suit/armor/vest/marine/security
	head = /obj/item/clothing/head/helmet/marine/security
	mask = /obj/item/clothing/mask/gas/sechailer
	glasses = /obj/item/clothing/glasses/sunglasses
	back = /obj/item/storage/backpack/security
	belt_contents = list(
		/obj/item/melee/baton/security/loaded = 1,
		/obj/item/restraints/handcuffs/outpost_police = 1,
		/obj/item/gun/energy/e_gun/mini = 1,
		/obj/item/grenade/flashbang = 1,
	)

/datum/outfit/outpost_police/marshal/halcyon
	name = "Outpost Police: Halcyon marshal"
	r_hand = /obj/item/gun/ballistic/automatic/ar
	backpack_contents = list(/obj/item/ammo_box/magazine/m223 = 3)

/datum/outfit/outpost_police/marshal/quartermain
	name = "Outpost Police: Quartermain marshal"
	uniform = /obj/item/clothing/under/rank/security/officer/grey
	r_hand = /obj/item/gun/ballistic/shotgun/automatic/combat
	backpack_contents = list(/obj/item/storage/box/lethalshot = 2)

/datum/outfit/outpost_police/marshal/undertow
	name = "Outpost Police: Undertow marshal"
	uniform = /obj/item/clothing/under/syndicate
	r_hand = /obj/item/gun/ballistic/automatic/wt550
	backpack_contents = list(/obj/item/ammo_box/magazine/wt550m9 = 3)

// =========================================================================
// THE BODIES
// =========================================================================

/**
 * What every officer is, whatever the unit: nothing drops (cash, loot or kit), the body goes in three minutes,
 * kit locked to the body. The outfit set on each unit below is Halcyon's; Initialize() swaps in the zone's.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police
	// dialogue_file and the voice are police_life.dm's (P3); Initialize() below only picks the zone's section
	outfit = /datum/outfit/outpost_police/beat/halcyon
	/// What struck them by throw or shot this tick, kept for on_attacked() (the attack relay names only who did it)
	var/datum/weakref/struck_source_ref
	/// world.time struck_source_ref was noted
	var/struck_source_at = -1
	// Nothing drops (abuse M8): the base NPC's cash and loot, and the human NPC base's
	death_cash_low = 0
	death_cash_high = 0
	death_loot = null
	npc_death_cash = 0
	npc_death_loot = null
	// Kit locked to the body (human_npc_gear.dm)
	npc_gear_locked = TRUE
	npc_corpse_lifetime = OUTPOST_POLICE_CORPSE_LIFETIME
	// On the station's radio net (stealth_radio.dm): the headset in their ears carries their calls. No light: the
	// concourse is lit, and a stealth guard's seclite is loot (abuse M8)
	stealth_radio = TRUE
	// Whom they leave down; set from the profile at Initialize(). Whom they go for is police_force.dm's.
	npc_target_stat = HUMAN_NPC_SPARES_DOWNED

/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat
	outfit = /datum/outfit/outpost_police/beat/halcyon

/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant
	outfit = /datum/outfit/outpost_police/sergeant/halcyon

/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer
	outfit = /datum/outfit/outpost_police/officer/halcyon

/mob/living/carbon/human/npc/ambient_npc/outpost/police/tactical
	outfit = /datum/outfit/outpost_police/tactical/halcyon

/// The top of the ladder: an elite (aimed crits), in heavy plate
/mob/living/carbon/human/npc/ambient_npc/outpost/police/marshal
	outfit = /datum/outfit/outpost_police/marshal/halcyon
	npc_rank = HUMAN_NPC_RANK_ELITE

/**
 * The outpost they are built at, its police and that zone's profile decide what they wear, what they say
 * and whom they leave down; all of it is read before the base builds the body. One built where there is no
 * outpost (a test's bare floor) wears Halcyon's and answers to nobody.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/Initialize(mapload, datum/human_npc_order/order)
	var/datum/outpost_police_profile/kit = kit_profile()
	var/kit_outfit = kit.outfits[unit_kind]
	if(ispath(kit_outfit, /datum/outfit))
		outfit = kit_outfit
	npc_target_stat = kit.spares_downed ? HUMAN_NPC_SPARES_DOWNED : HUMAN_NPC_FINISHES_DOWNED
	dialogue_section = kit.voice_section
	// Before ..(): the attack relay (added in the parent's Initialize) must hear of a throw or shot after these do
	RegisterSignal(src, COMSIG_ATOM_PREHITBY, PROC_REF(note_thrown_at))
	RegisterSignal(src, COMSIG_PROJECTILE_PREHIT, PROC_REF(note_shot))
	. = ..()
	ban_from_containment()
	RegisterSignal(src, COMSIG_CARBON_CUFF_ATTEMPTED, PROC_REF(on_cuff_attempt))
	RegisterSignals(src, list(COMSIG_MOB_MIND_INITIALIZED, COMSIG_MOB_MIND_TRANSFERRED_INTO), PROC_REF(on_player_mind))
	// Their ID reads their name, as a person's does
	var/obj/item/card/id/card = wear_id
	if(istype(card))
		card.registered_name = real_name
		card.update_label()
	desc = "[unit_title()], [kit.force_name]."
	// On the roster of the police who keep this outpost, if any (roles and dispatch add them as well: no harm)
	if(!mind && !client)
		home_police()?.add_officer(src)

/**
 * A person is never on an officer's side: players and officers share the neutral faction, and stealth's scan,
 * hearing and touch would otherwise pass over every visitor as a friend. Their warrant decides what an officer does
 * about them (police_force.dm); creatures and staff go by faction as before.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/faction_check_atom(atom/movable/target, exact_match)
	var/mob/living/person = target
	if(isliving(person) && (person.mind || person.client))
		return FALSE
	return ..()

/// The outpost they stand at, or null
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/home_outpost()
	return police?.outpost || get_trader_outpost_for_turf(get_turf(src))

/// The police of the outpost they stand at, or null
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/home_police()
	return police || home_outpost()?.ensure_police()

/// This zone's profile, or Halcyon's where they stand at no outpost
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/kit_profile()
	var/datum/outpost_police/keepers = home_police()
	if(keepers?.profile)
		return keepers.profile
	return human_npc_singleton(/datum/outpost_police_profile/halcyon)

/// What a person would call them
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/unit_title()
	switch(unit_kind)
		if(POLICE_UNIT_SERGEANT)
			return "Desk sergeant"
		if(POLICE_UNIT_OFFICER)
			return "Response officer"
		if(POLICE_UNIT_TACTICAL)
			return "Tactical officer"
		if(POLICE_UNIT_MARSHAL)
			return "Marshal"
	return "Beat officer"

/// Their body lies three minutes (the base asks this in death(); a trader outpost's own five would win otherwise)
/mob/living/carbon/human/npc/ambient_npc/outpost/police/corpse_lifetime()
	return OUTPOST_POLICE_CORPSE_LIFETIME

// ----- being struck -----

/**
 * Someone hit, shot, shoved or stunned them. The police are told (abuse M3: a stamina blow or a shove counts,
 * not only damage). The base NPC's own report, "a visitor was hurt", is left out: an officer struck is a crime
 * of its own kind and would otherwise count twice.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/on_attacked(datum/source, atom/attacker, attack_flags)
	SIGNAL_HANDLER
	if(!(attack_flags & (ATTACKER_DAMAGING_ATTACK | ATTACKER_STAMINA_ATTACK | ATTACKER_SHOVING)))
		return
	// A thrown item or the gun that fired, noted this tick; otherwise the wanted core takes the weapon in hand
	var/obj/item/weapon = struck_source_at == world.time ? struck_source_ref?.resolve() : null
	struck_source_ref = null
	struck_source_at = -1
	if(mind || client)
		return
	police?.officer_struck(src, attacker, attack_flags, weapon)
	react_attacked(attacker)

/// A thrown item is about to hit them: remember it for on_attacked()
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/note_thrown_at(datum/source, atom/movable/hit_atom, datum/thrownthing/throwingdatum)
	SIGNAL_HANDLER
	if(isitem(hit_atom))
		struck_source_ref = WEAKREF(hit_atom)
		struck_source_at = world.time

/// A projectile is about to hit them: remember the gun it came from for on_attacked()
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/note_shot(datum/source, obj/projectile/hit_projectile)
	SIGNAL_HANDLER
	if(isitem(hit_projectile?.fired_from))
		struck_source_ref = WEAKREF(hit_projectile.fired_from)
		struck_source_at = world.time

// Abuse SF3: a player in an officer's body (a brain transplant) is a person, not an officer: off the roster, so no
// stray sweep, recall or corpse cap ever deletes them
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/leave_roster_for_player()
	if(!police)
		return
	police.remove_officer(src)
	police.dispatch_strays -= src

/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/on_player_mind(datum/source, datum/extra)
	SIGNAL_HANDLER
	if(mind || client)
		leave_roster_for_player()

/mob/living/carbon/human/npc/ambient_npc/outpost/police/Login()
	. = ..()
	if(. && client)
		leave_roster_for_player()

/// Someone is putting cuffs on them (abuse M3)
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/on_cuff_attempt(datum/source, mob/living/user)
	SIGNAL_HANDLER
	if(user == src || mind || client)
		return
	police?.officer_cuff_attempt(src, user)

// ----- bystander reactions: they have none (abuse M17) -----

/mob/living/carbon/human/npc/ambient_npc/outpost/police/react_attacked(atom/attacker)
	return

/mob/living/carbon/human/npc/ambient_npc/outpost/police/react_violence(mob/living/offender)
	return

/mob/living/carbon/human/npc/ambient_npc/outpost/police/react_shootout(turf/refuge)
	return

// ----- the leash -----

/// Anywhere on their outpost: the concourse, the lobby and the hangars, not the concourse only
/mob/living/carbon/human/npc/ambient_npc/outpost/police/leash_ok(turf/tile)
	var/obj/structure/overmap/trader_outpost/keep = police?.outpost
	if(!keep)
		return ..()
	tile = get_turf(tile)
	if(!tile)
		return FALSE
	return get_trader_outpost_for_turf(tile) == keep

/**
 * Carried off their outpost with no way back. Never gone in front of a player: while anyone is within
 * HUMAN_NPC_CORPSE_WATCH_RANGE they stay and carry on (their AI is on); out of every player's sight they are
 * deleted. Rostering and the caps are police_dispatch.dm's (abuse M12).
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/give_up_leash()
	if(human_npc_watched(src) || outpost_npc_played(src))
		return
	npc_drop_not_gear()
	fade_out(instant = TRUE)

// ----- what they carry -----

/// Their baton, or null
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/get_baton()
	return locate(/obj/item/melee/baton) in get_all_contents()

/// Their own cuffs: not the pair they may be wearing themselves, nor a pair already on someone
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/get_cuffs()
	for(var/obj/item/restraints/handcuffs/cuffs in get_all_contents())
		if(cuffs == handcuffed || istype(cuffs, /obj/item/restraints/handcuffs/outpost_police/used))
			continue
		return cuffs
	return null

/// Puts `thing` from their hand back where it is carried (the belt, the bag or a non-pocket worn slot). TRUE once it is out of their hands.
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_put_away(obj/item/thing)
	if(QDELETED(thing) || !is_holding(thing))
		return TRUE
	for(var/obj/item/holder in list(belt, back))
		if(holder?.atom_storage?.attempt_insert(thing, src, messages = FALSE))
			return TRUE
	var/static/list/non_pocket_slots = list(
		ITEM_SLOT_SUITSTORE,
		ITEM_SLOT_BACK,
		ITEM_SLOT_BELT,
		ITEM_SLOT_HEAD,
		ITEM_SLOT_MASK,
		ITEM_SLOT_EYES,
		ITEM_SLOT_EARS,
		ITEM_SLOT_GLOVES,
		ITEM_SLOT_FEET,
		ITEM_SLOT_OCLOTHING,
		ITEM_SLOT_ICLOTHING,
		ITEM_SLOT_ID,
	)
	for(var/slot in non_pocket_slots)
		if(equip_to_slot_if_possible(thing, slot, disable_warning = TRUE))
			return TRUE
	return !is_holding(thing)

/// First usable empty hand index (not a missing limb), or 0
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_empty_hand()
	for(var/i in 1 to length(held_items))
		if(!held_items[i] && has_hand_for_held_index(i))
			return i
	return 0

/// A hand free for what they are about to take: if all usable hands are full, something held goes away. TRUE if a usable hand is free.
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_free_hand()
	var/hand = police_empty_hand()
	if(hand)
		swap_hand(hand, silent = TRUE)
		return TRUE
	for(var/obj/item/held in held_items)
		if(istype(held, /obj/item/outpost_sealed_case/evidence))
			continue
		if(police_put_away(held))
			hand = police_empty_hand()
			if(hand)
				swap_hand(hand, silent = TRUE)
				return TRUE
	// Still full (for instance a tactical long gun with no sling slot): an evidence case that fits in the bag can ride there
	for(var/obj/item/held in held_items)
		if(!istype(held, /obj/item/outpost_sealed_case/evidence))
			continue
		if(police_put_away(held))
			hand = police_empty_hand()
			if(hand)
				swap_hand(hand, silent = TRUE)
				return TRUE
	return FALSE

/// Takes `thing` into a free hand (making one free), or failing that into the belt or the bag. TRUE if they have it.
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_carry(obj/item/thing)
	if(QDELETED(thing))
		return FALSE
	var/hand = police_free_hand() ? police_empty_hand() : 0
	if(hand && put_in_hand(thing, hand))
		return TRUE
	for(var/obj/item/holder in list(belt, back))
		if(holder?.atom_storage?.attempt_insert(thing, src, messages = FALSE))
			return TRUE
	return thing in get_all_contents()

/// Their energy gun (every officer has one), or null
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/get_sidearm()
	return locate(/obj/item/gun/energy) in get_all_contents()

/// The tactical officer's and the marshal's ballistic long gun, or null for anyone else
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/get_longgun()
	return locate(/obj/item/gun/ballistic) in get_all_contents()
