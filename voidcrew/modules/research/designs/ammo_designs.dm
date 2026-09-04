/**
 * Generic ballistic ammunition designs.
 *
 * voidcrew/modules/weapons_bench/ already gives every blueprint gun (C-20r, Bulldog,
 * WT-550, L6 SAW, anti-materiel rifle) its own ammo node and design. What had no
 * manufacturing path at all was the plain stuff every crew is actually carrying:
 * 9mm/10mm/.45 handgun magazines, the Saber and APS magazines, lethal 12g shells, the
 * Nagant box, the Strilka stripper clip. Upstream only ships .38, foam darts and a few
 * specialist shells, and its .357/9mm/.45/10mm designs are autolathe-only - autolathes
 * read a global autounlocking techweb, so nothing a ship researches can ever reach them.
 * That gap is why crews were flying to apocalyptic planets to feed a one-shot ruin
 * printer for a couple of magazines.
 *
 * These are all PROTOLATHE | AWAY_LATHE, so they print from the ship's own R&D suite.
 *
 * Costs sit on the ladder the weapons bench ammo designs already established
 * (vc_ammo_smgm45 / vc_ammo_m12g / vc_ammo_sniper_rounds): priced by how much gun the
 * round feeds rather than by round count. Handgun magazine = 3 sheets iron + a magazine
 * body in plastic, automatic magazine = 4 sheets + more plastic, loose lethal shell =
 * 1 sheet, and the specialist shell adds the same plasma the .38 hotshot design uses.
 */

//
// Ballistic Ammunition - what a boarding party burns through.
//

/datum/design/vc_shotgun_slug
	name = "Shotgun Slug (Lethal)"
	desc = "A 12 gauge lead slug. One heavy projectile, no spread."
	id = "vc_shotgun_slug"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT)
	build_path = /obj/item/ammo_casing/shotgun
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

/datum/design/vc_shotgun_buckshot
	name = "Buckshot Shell (Lethal)"
	desc = "A 12 gauge shell packed with pellets. Devastating up close, useless at range."
	id = "vc_shotgun_buckshot"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT)
	build_path = /obj/item/ammo_casing/shotgun/buckshot
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

/// Protolathe re-export of upstream's autolathe-only .357 casing, so a ship techweb can
/// actually own it. Same pattern as /datum/design/rubbershot/sec upstream.
/datum/design/a357/lathe
	id = "vc_a357_lathe"
	desc = "A .357 Magnum casing. Fits any revolver chambered for it."
	build_type = PROTOLATHE | AWAY_LATHE
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY
	autolathe_exportable = FALSE

/datum/design/vc_strilka310_clip
	name = "Stripper Clip (.310 Strilka) (Lethal)"
	desc = "Five rounds of .310 Strilka on a stripper clip, for bolt-action rifles."
	id = "vc_strilka310_clip"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3)
	build_path = /obj/item/ammo_box/strilka310
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

/datum/design/vc_n762
	name = "Ammo Box (7.62x38mmR) (Lethal)"
	desc = "A box of 7.62x38mmR rounds for Nagant revolvers."
	id = "vc_n762"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3)
	build_path = /obj/item/ammo_box/n762
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

/datum/design/vc_mag_m9mm
	name = "Handgun Magazine (9mm) (Lethal)"
	desc = "A 9mm handgun magazine, suitable for the Makarov pistol."
	id = "vc_mag_m9mm"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/plastic = HALF_SHEET_MATERIAL_AMOUNT * 2,
	)
	build_path = /obj/item/ammo_box/magazine/m9mm
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

/datum/design/vc_mag_m10mm
	name = "Handgun Magazine (10mm) (Lethal)"
	desc = "A 10mm handgun magazine, suitable for the Ansem pistol."
	id = "vc_mag_m10mm"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/plastic = HALF_SHEET_MATERIAL_AMOUNT * 2,
	)
	build_path = /obj/item/ammo_box/magazine/m10mm
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

/datum/design/vc_mag_m45
	name = "Handgun Magazine (.45) (Lethal)"
	desc = "A .45 handgun magazine, suitable for the M1911."
	id = "vc_mag_m45"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/plastic = HALF_SHEET_MATERIAL_AMOUNT * 2,
	)
	build_path = /obj/item/ammo_box/magazine/m45
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

//
// Automatic Ammunition - high-capacity feed devices and specialist shells.
//

/datum/design/vc_mag_m9mm_aps
	name = "Machine Pistol Magazine (9mm) (Lethal)"
	desc = "An extended 9mm magazine, suitable for the Stechkin APS machine pistol."
	id = "vc_mag_m9mm_aps"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/plastic = HALF_SHEET_MATERIAL_AMOUNT * 3,
	)
	build_path = /obj/item/ammo_box/magazine/m9mm_aps
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

/datum/design/vc_mag_smgm9mm
	name = "SMG Magazine (9mm) (Lethal)"
	desc = "A sleek 9mm magazine, suitable for the Saber SMG."
	id = "vc_mag_smgm9mm"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/plastic = HALF_SHEET_MATERIAL_AMOUNT * 3,
	)
	build_path = /obj/item/ammo_box/magazine/smgm9mm
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

/datum/design/vc_shotgun_dragonsbreath
	name = "Dragonsbreath Shell (Lethal)"
	desc = "A 12 gauge shell that fires a spread of incendiary pellets."
	id = "vc_shotgun_dragonsbreath"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT,
		/datum/material/plasma = HALF_SHEET_MATERIAL_AMOUNT * 1.5,
	)
	build_path = /obj/item/ammo_casing/shotgun/dragonsbreath
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY
