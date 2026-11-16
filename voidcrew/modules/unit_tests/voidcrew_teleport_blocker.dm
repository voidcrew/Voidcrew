/// A live bluespace damper refuses teleports onto or off its ship, but not across its own deck (voidcrew teleport_blocker).
/datum/unit_test/voidcrew_zone_teleport/teleport_blocker

/datum/unit_test/voidcrew_zone_teleport/teleport_blocker/Run()
	zones_were_active = SSovermap_zones.zones_active
	var/turf/guarded_hull = run_loc_floor_bottom_left
	var/turf/guarded_deck = get_step(guarded_hull, EAST)
	var/turf/outside = get_step(guarded_deck, EAST)
	var/turf/blocker_spot = get_step(guarded_hull, NORTH)
	var/obj/structure/overmap/ship/guarded = make_ship(guarded_hull, make_zone_turf(get_step(outside, EAST), 1))
	var/area/shuttle/voidcrew/ship_area = get_area(guarded_hull)
	ship_area.requires_power = FALSE
	for(var/turf/extra as anything in list(guarded_deck, blocker_spot))
		original_areas[extra] = get_area(extra)
		extra.change_area(get_area(extra), ship_area)

	var/obj/machinery/teleport_blocker/damper = allocate(/obj/machinery/teleport_blocker, blocker_spot)
	damper.power_change()
	var/mob/living/carbon/human/consistent/crew = allocate(/mob/living/carbon/human/consistent, outside)

	// Off: nothing is blocked
	TEST_ASSERT(!teleport_blocked_by_ship(outside, guarded_hull), "A switched-off damper should block nothing")

	damper.field_on = TRUE
	TEST_ASSERT_EQUAL(damper.get_blocked_ship(), guarded, "A switched-on, powered damper should shield its own ship")
	TEST_ASSERT(!do_teleport(crew, guarded_hull, channel = TELEPORT_CHANNEL_QUANTUM, no_effects = TRUE), "A teleport onto a shielded ship should be refused")
	TEST_ASSERT_EQUAL(get_turf(crew), outside, "A refused teleport should leave the mob where it was")

	crew.forceMove(guarded_hull)
	TEST_ASSERT(!do_teleport(crew, outside, channel = TELEPORT_CHANNEL_BLUESPACE, no_effects = TRUE), "A teleport off a shielded ship should be refused")
	TEST_ASSERT(do_teleport(crew, guarded_deck, channel = TELEPORT_CHANNEL_BLUESPACE, no_effects = TRUE), "A teleport across the shielded ship's own deck should work")
	TEST_ASSERT_EQUAL(get_turf(crew), guarded_deck, "A same-ship teleport should arrive")

	// Hacked: the field is down until the hold runs out
	guarded.teleport_field_hacked_until = world.time + 1 MINUTES
	TEST_ASSERT(do_teleport(crew, outside, channel = TELEPORT_CHANNEL_BLUESPACE, no_effects = TRUE), "A hacked damper should let teleports through")
	TEST_ASSERT_EQUAL(damper.current_icon_state(), "scrambler_hacked", "A hacked damper should show it")
	guarded.teleport_field_hacked_until = 0

	// EMPed
	damper.emp_act(EMP_HEAVY)
	TEST_ASSERT(do_teleport(crew, guarded_hull, channel = TELEPORT_CHANNEL_BLUESPACE, no_effects = TRUE), "An EMPed damper should let teleports through")
	damper.emp_until = 0

	// Switched off by hand
	crew.forceMove(outside)
	damper.field_on = FALSE
	TEST_ASSERT(do_teleport(crew, guarded_hull, channel = TELEPORT_CHANNEL_BLUESPACE, no_effects = TRUE), "A switched-off damper should let teleports through")

	// Field passes: only a keyed pass, clipped to a worn uniform, carries its wearer through
	damper.field_on = TRUE
	var/mob/living/carbon/human/consistent/passer = allocate(/mob/living/carbon/human/consistent, outside)
	var/obj/item/clothing/under/uniform = allocate(/obj/item/clothing/under/color/grey)
	passer.equip_to_slot_or_del(uniform, ITEM_SLOT_ICLOTHING)
	var/obj/item/clothing/accessory/field_pass/pass = allocate(/obj/item/clothing/accessory/field_pass)
	passer.put_in_hands(pass)
	pass.link_to(damper)
	TEST_ASSERT(!do_teleport(passer, guarded_hull, channel = TELEPORT_CHANNEL_BLUESPACE, no_effects = TRUE), "A pass in hand should not count")
	TEST_ASSERT(uniform.attach_accessory(pass, passer, attach_message = FALSE), "The pass should clip onto the uniform")
	TEST_ASSERT(do_teleport(passer, guarded_hull, channel = TELEPORT_CHANNEL_BLUESPACE, no_effects = TRUE), "A worn, keyed pass should carry its wearer onto the shielded ship")
	TEST_ASSERT(do_teleport(passer, outside, channel = TELEPORT_CHANNEL_BLUESPACE, no_effects = TRUE), "A worn, keyed pass should carry its wearer off the shielded ship")
	var/obj/item/wrench/loose_cargo = allocate(/obj/item/wrench, outside)
	TEST_ASSERT(!do_teleport(loose_cargo, guarded_hull, channel = TELEPORT_CHANNEL_BLUESPACE, no_effects = TRUE), "Cargo sent on its own should still bounce")
	damper.reset_link_key()
	TEST_ASSERT(!do_teleport(passer, guarded_hull, channel = TELEPORT_CHANNEL_BLUESPACE, no_effects = TRUE), "A reset key should revoke the pass")

	// Keyed transporter pads carry their whole beam through, both ways
	var/obj/machinery/transporter_pad/pad = allocate(/obj/machinery/transporter_pad, guarded_deck)
	var/obj/structure/closet/crate/crate = allocate(/obj/structure/closet/crate, guarded_hull)
	TEST_ASSERT(!pad.field_beam_teleport(crate, outside, pad.get_field_beam_ship()), "An unkeyed pad should not beam through the field")
	pad.link_to_blocker(damper)
	TEST_ASSERT_EQUAL(pad.get_field_beam_ship(), guarded, "A keyed pad aboard should beam through its ship's field")
	TEST_ASSERT(pad.field_beam_teleport(crate, outside, pad.get_field_beam_ship()), "A keyed pad should beam a crate off the shielded ship")
	TEST_ASSERT(pad.field_beam_teleport(crate, guarded_hull, pad.get_field_beam_ship()), "A keyed pad should beam a crate onto the shielded ship")
	TEST_ASSERT(isnull(GLOB.teleport_field_beam_ship), "The beam bypass should not outlive the beam")
	var/obj/machinery/quantumpad/quantum_pad = allocate(/obj/machinery/quantumpad, outside)
	TEST_ASSERT(!do_teleport(crate, quantum_pad, channel = TELEPORT_CHANNEL_QUANTUM, no_effects = TRUE), "Other quantum teleports should still bounce")
	damper.reset_link_key()
	TEST_ASSERT(isnull(pad.get_field_beam_ship()), "A reset key should unkey the pad")
	TEST_ASSERT(!pad.field_beam_teleport(crate, outside, pad.get_field_beam_ship()), "A reset key should block the pad again")
