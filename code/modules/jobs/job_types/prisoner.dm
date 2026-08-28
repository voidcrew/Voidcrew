/datum/job/prisoner
	title = JOB_PRISONER
	description = "Keep yourself occupied in permabrig."
	faction = FACTION_STATION
	total_positions = 0
	spawn_positions = 4
	supervisors = "the security team"
	exp_granted_type = EXP_TYPE_CREW
	paycheck = PAYCHECK_LOWER
	config_tag = "PRISONER"

	outfit = /datum/outfit/job/prisoner
	plasmaman_outfit = /datum/outfit/plasmaman/prisoner

	display_order = JOB_DISPLAY_ORDER_PRISONER
	department_for_prefs = /datum/job_department/security

	exclusive_mail_goodies = TRUE
	mail_goodies = list (
		/obj/effect/spawner/random/contraband/prison = 1
	)

	family_heirlooms = list(/obj/item/pen/blue)
	rpg_title = "Defeated Miniboss"
	job_flags = STATION_JOB_FLAGS | JOB_CANNOT_OPEN_SLOTS | JOB_ANTAG_PROTECTED & ~JOB_REOPEN_ON_ROUNDSTART_LOSS
	tgui_icon = FA_ICON_LOCK

/datum/job/prisoner/New()
	. = ..()
	RegisterSignal(SSdcs, COMSIG_GLOB_CREWMEMBER_JOINED, PROC_REF(handle_prisoner_joining))

/datum/job/prisoner/proc/handle_prisoner_joining(datum/source, mob/living/crewmember, rank)
	SIGNAL_HANDLER
	if(rank != title)
		return //not a prisoner

	// VOIDCREW EDIT ADDITION BEGIN - ships build a fresh job datum per crew slot per hull
	// (assemble_job_slots_from_list), and every one of them runs this New() and registers
	// on SSdcs. Matching on the title alone therefore matched every Pill-class in the
	// fleet, so a single prisoner joining ran this handler once per hull. Upstream has one
	// prisoner datum and set_assigned_role() stores that exact datum, so this reads the
	// same there.
	if(crewmember.mind?.assigned_role != src)
		return
	// VOIDCREW EDIT ADDITION END

	var/crime_name = crewmember.client?.prefs?.read_preference(/datum/preference/choiced/prisoner_crime)
	if(!crime_name)
		stack_trace("[crewmember] joined as a Prisoner without having a prisoner crime set.")
		crime_name = pick(assoc_to_keys(GLOB.prisoner_crimes))
	else if(crime_name == "Random")
		crime_name = pick(assoc_to_keys(GLOB.prisoner_crimes))

	var/datum/record/crew/target_record = find_record(crewmember.real_name)
	// VOIDCREW EDIT ADDITION BEGIN - COMSIG_GLOB_CREWMEMBER_JOINED fires twice on a ship
	// join: once from transfer_character(), which runs before equip_rank() and before
	// GLOB.manifest.inject() have made a crew record, and again from AttemptSpawnOnShip()
	// once the record exists. The early pass had nothing to write the crime onto. Let it
	// go; the later pass does the work (and does the to_chat below exactly once).
	if(isnull(target_record))
		return
	// VOIDCREW EDIT ADDITION END

	var/datum/prisoner_crime/crime = GLOB.prisoner_crimes[crime_name]
	var/datum/crime/past_crime = new(crime.name, crime.desc, "Central Command", "Indefinite.")
	target_record.crimes += past_crime
	target_record.recreate_manifest_photos(add_height_chart = TRUE)
	to_chat(crewmember, span_warning("You are imprisoned for \"[crime_name]\"."))
	crewmember.add_mob_memory(/datum/memory/key/permabrig_crimes, crimes = crime_name)

/datum/outfit/job/prisoner
	name = "Prisoner"
	jobtype = /datum/job/prisoner

	id = /obj/item/card/id/advanced/prisoner
	id_trim = /datum/id_trim/job/prisoner
	uniform = /obj/item/clothing/under/rank/prisoner
	belt = null
	ears = null
	shoes = /obj/item/clothing/shoes/sneakers/orange
	box = /obj/item/storage/box/survival/prisoner
	pda_slot = null

/datum/outfit/job/prisoner/pre_equip(mob/living/carbon/human/H)
	..()
	if(prob(1)) // D BOYYYYSSSSS
		head = /obj/item/clothing/head/beanie/black/dboy

/datum/outfit/job/prisoner/post_equip(mob/living/carbon/human/new_prisoner, visuals_only)
	. = ..()

	var/crime_name = new_prisoner.client?.prefs?.read_preference(/datum/preference/choiced/prisoner_crime)
	var/datum/prisoner_crime/crime = GLOB.prisoner_crimes[crime_name]
	if (isnull(crime))
		return
	var/list/limbs_to_tat = new_prisoner.get_bodyparts()
	for(var/i in 1 to crime.tattoos)
		if(!length(SSpersistence.prison_tattoos_to_use) || visuals_only)
			return
		var/obj/item/bodypart/tatted_limb = pick_n_take(limbs_to_tat)
		var/list/tattoo = pick_n_take(SSpersistence.prison_tattoos_to_use)
		tatted_limb.AddComponent(/datum/component/tattoo, tattoo["story"])
