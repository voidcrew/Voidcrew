/datum/design/research
	name = "Research & Development Kit"
	id = "rndkit"
	build_type = AUTOLATHE
	materials = list(/datum/material/iron = 2000, /datum/material/glass = 4000) // The materials for one box + all boards inside exactly.
	build_path = /obj/item/storage/box/rndboards/all
	category = list(
		RND_CATEGORY_INITIAL,
		RND_CATEGORY_CONSTRUCTION + RND_SUBCATEGORY_CONSTRUCTION_MACHINERY,
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING

/datum/design/ship_disk
	name = "R&D Server Source Code"
	id = "ship_disk"
	build_type = AUTOLATHE
	materials = list(/datum/material/glass = SHEET_MATERIAL_AMOUNT * 2)
	build_path = /obj/item/computer_disk/ship_disk
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
		"c9mm",
		"c10mm",
		"c45",
		"strilka310_surplus",
	)
	for(var/design_id in voidcrew_extra_designs)
		add_design_by_id(design_id)
