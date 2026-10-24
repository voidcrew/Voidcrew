/datum/record/crew/prisoner_photo_test
	var/photos_generated = 0

/datum/record/crew/prisoner_photo_test/make_photo(field_name, orientation, add_height_chart)
	photos_generated++
	return ..()

/// A shared title must not let every ship's prisoner job process the same arrival.
/datum/unit_test/prisoner_join_photo_count/Run()
	var/datum/job/prisoner/assigned_job = allocate(/datum/job/prisoner)
	assigned_job.title = "Head Prisoner"
	for(var/i in 1 to 50)
		var/datum/job/prisoner/other_ship_job = allocate(/datum/job/prisoner)
		other_ship_job.title = assigned_job.title

	var/mob/living/carbon/human/consistent/prisoner = allocate(__IMPLIED_TYPE__)
	prisoner.real_name = "Prisoner photo test [REF(src)]"
	prisoner.mind_initialize()
	prisoner.mind.set_assigned_role(assigned_job)
	var/datum/client_interface/player_client = allocate(/datum/client_interface)
	player_client.prefs = new(player_client)
	allocated += player_client.prefs
	prisoner.mock_client = player_client
	TEST_ASSERT(player_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/choiced/prisoner_crime], "Random"), "Could not set the prisoner's crime preference.")

	// An early notification must not runtime or create a crime without a record.
	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_CREWMEMBER_JOINED, prisoner, assigned_job.title)
	var/datum/record/crew/prisoner_photo_test/record = new(
		name = prisoner.real_name,
		character_appearance = new /mutable_appearance(prisoner.appearance),
	)
	allocated += record
	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_CREWMEMBER_JOINED, prisoner, assigned_job.title)
	TEST_ASSERT_EQUAL(length(record.crimes), 1, "Other ships' prisoner jobs added duplicate crimes.")
	TEST_ASSERT_EQUAL(record.photos_generated, 2, "A prisoner arrival must generate exactly one front and one side photo.")
	allocated += record.crimes

	var/datum/job/assistant/same_title_job = allocate(/datum/job/assistant)
	same_title_job.title = assigned_job.title
	prisoner.mind.set_assigned_role(same_title_job)
	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_CREWMEMBER_JOINED, prisoner, same_title_job.title)
	TEST_ASSERT_EQUAL(length(record.crimes), 1, "A matching title treated an unrelated job as a prisoner.")
	TEST_ASSERT_EQUAL(record.photos_generated, 2, "A matching title regenerated an unrelated job's portraits.")

/// Rendering both views repeatedly must leave the stored appearance unchanged.
/datum/unit_test/prisoner_photo_appearance/Run()
	var/mutable_appearance/saved_appearance = mutable_appearance('icons/mob/human/human.dmi', "human_basic")
	saved_appearance.setDir(NORTH)
	saved_appearance.underlays += mutable_appearance('icons/obj/machines/photobooth.dmi', "height_chart")
	var/original_underlays = length(saved_appearance.underlays)
	var/datum/record/crew/record = new(character_appearance = saved_appearance)
	allocated += record
	for(var/i in 1 to 5)
		record.recreate_manifest_photos(add_height_chart = TRUE)
		TEST_ASSERT_EQUAL(length(saved_appearance.underlays), original_underlays, "Portrait generation accumulated height-chart underlays.")
		TEST_ASSERT_EQUAL(saved_appearance.dir, NORTH, "Portrait generation rotated the saved character appearance.")
	TEST_ASSERT_NOTNULL(record.get_front_photo(), "The front portrait was not generated.")
	TEST_ASSERT_NOTNULL(record.get_side_photo(), "The side portrait was not generated.")

/// Record cleanup must delete the cached photo objects, not their string keys.
/datum/unit_test/prisoner_photo_cleanup/Run()
	var/datum/record/crew/record = new(character_appearance = mutable_appearance('icons/mob/human/human.dmi', "human_basic"))
	allocated += record
	record.recreate_manifest_photos(add_height_chart = TRUE)
	var/obj/item/photo/front = record.get_front_photo()
	var/obj/item/photo/side = record.get_side_photo()
	allocated += front
	allocated += side
	qdel(record)
	TEST_ASSERT(QDELETED(front), "Deleting a crew record left its front photo alive.")
	TEST_ASSERT(QDELETED(side), "Deleting a crew record left its side photo alive.")
	TEST_ASSERT_NULL(record.record_photos, "Deleting a crew record retained its photo cache.")

/// Transferring a key must not announce a latejoin before its record exists.
/datum/unit_test/prisoner_join_notification_timing
	var/mob/living/expected_crew
	var/notifications = 0
	var/record_was_ready = FALSE

/datum/unit_test/prisoner_join_notification_timing/Run()
	RegisterSignal(SSdcs, COMSIG_GLOB_CREWMEMBER_JOINED, PROC_REF(on_crew_joined))
	var/mob/living/carbon/human/consistent/crew = allocate(__IMPLIED_TYPE__)
	crew.real_name = "Join notification test [REF(src)]"
	crew.mind_initialize()
	crew.mind.set_assigned_role(SSjob.get_job_type(/datum/job/assistant))
	expected_crew = crew
	var/mob/dead/new_player/latejoin_player = allocate(/mob/dead/new_player)
	latejoin_player.new_character = crew
	TEST_ASSERT_EQUAL(latejoin_player.transfer_character(), crew, "Key transfer did not return the character.")
	TEST_ASSERT_EQUAL(notifications, 0, "Key transfer announced a latejoin before equipment and record setup.")

	// Roundstart already builds the manifest before the ticker transfers characters.
	var/datum/record/crew/record = new(name = crew.real_name)
	allocated += record
	var/mob/dead/new_player/roundstart_player = allocate(/mob/dead/new_player)
	roundstart_player.new_character = crew
	GLOB.new_player_list -= roundstart_player
	var/list/saved_players = GLOB.new_player_list
	GLOB.new_player_list = list(roundstart_player)
	SSticker.transfer_characters()
	GLOB.new_player_list = saved_players
	TEST_ASSERT_EQUAL(notifications, 1, "Roundstart must announce a crew member exactly once.")
	TEST_ASSERT(record_was_ready, "Roundstart announced a crew member without a manifest record.")

/datum/unit_test/prisoner_join_notification_timing/proc/on_crew_joined(datum/source, mob/living/crew, rank)
	SIGNAL_HANDLER
	if(crew != expected_crew)
		return
	notifications++
	record_was_ready = !isnull(find_record(crew.real_name))
