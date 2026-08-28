/datum/design/research
	name = "Research & Development Kit"
	build_type = AUTOLATHE
	materials = list(/datum/material/iron = 2000, /datum/material/glass = 4000) // The materials for one box + all boards inside exactly.
	build_path = /obj/item/storage/box/rndboards/all
	category = list(
		RND_CATEGORY_INITIAL,
		RND_CATEGORY_CONSTRUCTION + RND_SUBCATEGORY_CONSTRUCTION_MACHINERY,
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING
	// This design prints a filled box, and the five boards plus the disk inside already carry their
	// own materials, so the cardboard box must carry none - otherwise a printed kit is worth its
	// whole price at the ORM *plus* the value of everything inside it.
	//
	// It must be DONT, not SPECIAL. SPECIAL only exempts the design from the design_mats unit test
	// (code/modules/unit_tests/designs.dm:143); the transfer itself is still made, because
	// autolathe.dm:418 tests `!= DESIGN_DONT_INHERIT_MATS`. With SPECIAL the whole 3200 iron /
	// 6400 glass landed on the box on top of the contents' own materials, and recycling a printed
	// kit returned more than it cost.
	inherit_materials = DESIGN_DONT_INHERIT_MATS

/datum/design/ship_disk
	name = "R&D Server Source Code"
	build_type = AUTOLATHE
	materials = list(/datum/material/glass = SHEET_MATERIAL_AMOUNT * 2)
	build_path = /obj/item/disk/computer/ship_disk
	category = list(
		RND_CATEGORY_INITIAL,
		RND_CATEGORY_MODULAR_COMPUTERS + RND_SUBCATEGORY_MODULAR_COMPUTERS_PARTS,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_ENGINEERING

/**
 * Crews here live off salvaged ballistics, and on a station-less map "hack the
 * autolathe" is the only path tg leaves to the common calibers - running dry
 * mid-fight was a recorded playtest death (BAL-6). Unlock the basic lethal
 * calibers on every autolathe from the start.
 *
 * Kept to the workhorse rounds looted guns actually chamber (9mm, 10mm, .45,
 * .310 surplus). The .357 casing, incendiary slugs and chemical darts stay
 * behind the hacked list on purpose.
 */
/datum/techweb/autounlocking/autolathe/New()
	. = ..()
	var/static/list/voidcrew_extra_designs = list(
		/datum/design/c9mm,
		/datum/design/c10mm,
		/datum/design/c45,
		/datum/design/strilka310_surplus,
	)
	for(var/design_path in voidcrew_extra_designs)
		add_design(design_path)
		// All four carry RND_CATEGORY_HACKED, so the parent already filed them in hacked_designs.
		// A hacked lathe concatenates both lists (autolathe.dm:194-199) and would render each of
		// them twice; they are unconditionally available here, so drop the hacked copy.
		hacked_designs -= design_path
