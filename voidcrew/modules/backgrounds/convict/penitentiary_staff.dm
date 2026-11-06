/// Backgrounds: owned by P2.

/**
 * # The Penitentiary's people
 *
 * The warden and the intake clerk: mapped ambient NPCs who keep to their own rooms, sit, chat
 * and do desk work there, and talk from penitentiary_staff.json. Humanoid sentience and the
 * parent's polymorph and teleport refusals are kept [TAK-1]. The inmates and guards come from the
 * NPC wing (penitentiary_prison.dm).
 *
 * The dead officers of scenario 2 are code-spawned once per round (dress_massacre()), each with a
 * card that opens the pod bay and nothing else [ECO-5].
 */

/mob/living/basic/ambient_npc/penitentiary
	name = "corrections officer"
	desc = "Meridian staff, in a pressed uniform."
	sentience_type = SENTIENCE_HUMANOID
	dialogue_file = "penitentiary_staff.json"
	outfit = /datum/outfit/job/security
	routine = list(
		/datum/ambient_activity/idle = 3,
		/datum/ambient_activity/sit = 3,
		/datum/ambient_activity/chat = 1,
		/datum/ambient_activity/work = 3,
	)
	work_weights = list(/datum/outpost_ambient_work/paperwork = 1)
	// No pocket money on the Meridian's staff
	death_cash_low = 0
	death_cash_high = 0
	/// The Penitentiary they work at
	var/obj/structure/overmap/penitentiary/site
	/// The room they keep to
	var/area/home_area

/mob/living/basic/ambient_npc/penitentiary/Initialize(mapload)
	. = ..()
	home_area = get_area(src)

/mob/living/basic/ambient_npc/penitentiary/Destroy()
	site?.staff -= src
	site = null
	home_area = null
	return ..()

/// Called by the site's link sweep
/mob/living/basic/ambient_npc/penitentiary/proc/link_to_site(obj/structure/overmap/penitentiary/new_site)
	site = new_site
	home = get_turf(src)
	home_area = get_area(src)

// They keep to their own room
/mob/living/basic/ambient_npc/penitentiary/leash_ok(turf/tile)
	tile = get_turf(tile)
	if(!tile)
		return FALSE
	if(home_area && tile.loc != home_area)
		return FALSE
	// Never onto a doorway: a secure door opened for them would let a visitor through behind them [MP-8]
	if(locate(/obj/machinery/door) in tile)
		return FALSE
	return ..()

// Staff never slip away: they are back at their post
/mob/living/basic/ambient_npc/penitentiary/give_up_leash()
	if(home && !QDELETED(src))
		forceMove(home)
		leash_broken_at = 0

/mob/living/basic/ambient_npc/penitentiary/warden
	name = "Warden Okafor"
	desc = "The warden of the Meridian. He has seen every trick twice."
	random_name = FALSE
	random_gender = FALSE
	gender = MALE
	outfit = /datum/outfit/job/warden
	dialogue_section = "warden"

/mob/living/basic/ambient_npc/penitentiary/clerk
	name = "intake clerk"
	desc = "The clerk behind the intake counter, stamp in hand."
	dialogue_section = "clerk"
	speech_pace = 0.8

/// Shuffling papers, stamping forms and putting files away
/datum/outpost_ambient_work/paperwork
	works_on = list(
		/obj/structure/table,
		/obj/structure/filingcabinet,
	)
	leaves_alone = list(/obj/structure/table/rolling, /obj/structure/table/optable, /obj/structure/table/reinforced/prison_hatch)
	duration_low = 8 SECONDS
	duration_high = 16 SECONDS
	sounds = list('sound/items/handling/paper_pickup.ogg', 'sound/items/handling/paper_drop.ogg')
	sound_volume = 20
	sound_chance = 40

// ===== THE DEAD OFFICERS (scenario 2) =====

/obj/effect/mob_spawn/corpse/human/penitentiary_officer
	name = "Corrections Officer"
	outfit = /datum/outfit/penitentiary_officer
	brute_damage = 150
	burn_damage = 30

/datum/outfit/penitentiary_officer
	name = "Penitentiary Officer"
	uniform = /obj/item/clothing/under/rank/security/officer
	suit = /obj/item/clothing/suit/armor/vest
	suit_store = /obj/item/gun/energy/disabler
	belt = /obj/item/melee/baton/security/loaded
	shoes = /obj/item/clothing/shoes/jackboots/sec
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/penitentiary_officer

/// Opens the Meridian's pod bay and nothing else
/datum/id_trim/penitentiary_officer
	assignment = "Corrections Officer"
	trim_state = "trim_securityofficer"
	department_color = COLOR_SECURITY_RED
	subdepartment_color = COLOR_SECURITY_RED
	sechud_icon_state = SECHUD_SECURITY_OFFICER
	access = list(ACCESS_PENITENTIARY_PODBAY)
