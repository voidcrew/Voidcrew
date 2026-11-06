/// Backgrounds: owned by P0 (frozen). See data/backgrounds/spec.md.

// Shared helpers for the backgrounds tests. Unit tests compile before voidcrew defines: use literals.

/// A human with a mind and a fake ckey, deleted with the running test
/proc/bg_test_human(turf/where)
	var/static/serial = 0
	var/datum/unit_test/test = GLOB.current_test
	var/mob/living/carbon/human/consistent/person
	if(test)
		person = test.allocate(/mob/living/carbon/human/consistent, where)
	else
		person = new(where)
	person.key = "bgtestplayer[++serial]"
	person.mind_initialize()
	ADD_TRAIT(person, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, "bg_test")
	return person

/// Starts a background state on this body's mind. `key` is a literal ("convict" is BACKGROUND_CONVICT).
/proc/bg_test_state(mob/living/carbon/human/body, key)
	return background_begin(body.mind, key)

/// Spawns a hull from this template, deleted with the running test
/proc/bg_test_ship(template_type)
	var/obj/structure/overmap/ship/ship = SSshuttle.create_ship(template_type)
	var/datum/unit_test/test = GLOB.current_test
	if(ship && test)
		test.allocated += ship
	return ship
