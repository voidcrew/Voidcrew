/// Old discoveries must remain distinct when BYOND reuses a deleted atom's ref.
/datum/unit_test/voidcrew_survey_identity/Run()
	var/datum/survey_research/original = allocate(/datum/survey_research)
	var/datum/survey_research/copied = allocate(/datum/survey_research)
	var/obj/structure/overmap/star/survey_reference_reuse/first = allocate(/obj/structure/overmap/star/survey_reference_reuse)
	first.name = "Original discovery"
	original.update_survey_data(first)
	copied.merge_completed_surveys(original)
	var/first_ref = ref(first)
	first.force_reference_reuse = TRUE
	qdel(first)
	var/obj/structure/overmap/star/survey_reference_reuse/replacement
	for(var/attempt in 1 to 128)
		var/obj/structure/overmap/star/survey_reference_reuse/candidate = allocate(/obj/structure/overmap/star/survey_reference_reuse)
		if(ref(candidate) == first_ref)
			replacement = candidate
			break
	TEST_ASSERT_NOTNULL(replacement, "The fixture could not obtain the deleted atom's recycled reference")
	replacement.name = "New discovery"
	original.update_survey_data(replacement)
	TEST_ASSERT_EQUAL(length(original.survey_objects_by_type["stars"]), 2, "A recycled reference replaced an unrelated completed discovery")
	TEST_ASSERT_EQUAL(length(copied.survey_objects_by_type["stars"]), 1, "An independent archive changed before synchronization")
	copied.merge_completed_surveys(original)
	TEST_ASSERT_EQUAL(length(copied.survey_objects_by_type["stars"]), 2, "Synchronization merged two different discoveries with a recycled reference")
	original.merge_completed_surveys(copied)
	copied.merge_completed_surveys(original)
	TEST_ASSERT_EQUAL(length(copied.survey_objects_by_type["stars"]), 2, "Repeating synchronization duplicated completed discoveries")
	var/datum/surveyed_celestial_object/old_record = copied.survey_objects_by_type["stars"][1]
	TEST_ASSERT_EQUAL(old_record.object_name, "Original discovery", "Losing the original object erased its surviving record")

/// Explicitly armed only by this test; generic construction retains normal cleanup.
/obj/structure/overmap/star/survey_reference_reuse
	var/force_reference_reuse = FALSE

/obj/structure/overmap/star/survey_reference_reuse/Destroy()
	. = ..()
	if(force_reference_reuse)
		return QDEL_HINT_HARDDEL_NOW
