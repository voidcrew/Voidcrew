/**
 * Additional firearm ammunition for ship research.
 *
 * Each design builds an existing loaded magazine, speed loader or usable round.
 * Internal magazines, spent/empty props, degraded ammunition and unique-weapon
 * effects are not fabrication products. Bows and improvised junk guns retain
 * their crafting recipes.
 *
 * Specialty ammunition adds materials to the standard reload's cost. In particular,
 * every L6 load retains its iron/titanium/plasma/plastic baseline; the 150-round
 * box pays for three normal boxes before its specialty surcharge.
 */
/datum/design/vc_ammo
	build_type = PROTOLATHE | AWAY_LATHE
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

// Ship-techweb versions of ammunition boxes otherwise confined to autolathes.

/datum/design/c9mm/lathe
	id = "vc_c9mm_lathe"
	build_type = PROTOLATHE | AWAY_LATHE
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	autolathe_exportable = FALSE

/datum/design/c10mm/lathe
	id = "vc_c10mm_lathe"
	build_type = PROTOLATHE | AWAY_LATHE
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	autolathe_exportable = FALSE

/datum/design/c45/lathe
	id = "vc_c45_lathe"
	build_type = PROTOLATHE | AWAY_LATHE
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	autolathe_exportable = FALSE

/datum/design/riot_darts/lathe
	id = "vc_riot_darts_lathe"
	build_type = PROTOLATHE | AWAY_LATHE
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	autolathe_exportable = FALSE

// Basic calibers and reloads.

/datum/design/vc_ammo/m50
	name = "Desert Eagle Magazine (.50 AE)"
	id = "vc_ammo_m50"
	build_path = /obj/item/ammo_box/magazine/m50
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT,
	)

/datum/design/vc_ammo/a357
	name = "Speed Loader (.357)"
	id = "vc_ammo_a357"
	build_path = /obj/item/ammo_box/a357
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3,
	)

/datum/design/vc_ammo/harpoon
	name = "Harpoon"
	id = "vc_ammo_harpoon"
	build_path = /obj/item/ammo_casing/harpoon
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/foam_smg
	name = "Foam Force SMG Magazine (Foam Darts)"
	id = "vc_ammo_foam_smg"
	build_path = /obj/item/ammo_box/magazine/toy/smg
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/foam_pistol
	name = "Foam Force Pistol Magazine (Foam Darts)"
	id = "vc_ammo_foam_pistol"
	build_path = /obj/item/ammo_box/magazine/toy/pistol
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/foam_smgm45
	name = "Donksoft SMG Magazine (Foam Darts)"
	id = "vc_ammo_foam_smgm45"
	build_path = /obj/item/ammo_box/magazine/toy/smgm45
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/foam_m762
	name = "Donksoft Machine Gun Magazine (Foam Darts)"
	id = "vc_ammo_foam_m762"
	build_path = /obj/item/ammo_box/magazine/toy/m762
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
	)

// Automatic magazines.

/datum/design/vc_ammo/uzi
	name = "Uzi Magazine (9mm)"
	id = "vc_ammo_uzi"
	build_path = /obj/item/ammo_box/magazine/uzim9mm
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 6,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/tommygun
	name = "Tommy Gun Drum (.45)"
	id = "vc_ammo_tommygun"
	build_path = /obj/item/ammo_box/magazine/tommygunm45
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 8,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 3,
	)

/datum/design/vc_ammo/m223
	name = "Rifle Magazine (.223)"
	id = "vc_ammo_m223"
	build_path = /obj/item/ammo_box/magazine/m223
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 8,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
	)

// Specialist ammunition.

/datum/design/vc_ammo/m9mm_ap
	name = "Handgun Magazine (9mm AP)"
	id = "vc_ammo_m9mm_ap"
	build_path = /obj/item/ammo_box/magazine/m9mm/ap
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/m9mm_hp
	name = "Handgun Magazine (9mm HP)"
	id = "vc_ammo_m9mm_hp"
	build_path = /obj/item/ammo_box/magazine/m9mm/hp
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 5,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT,
	)

/datum/design/vc_ammo/m9mm_fire
	name = "Handgun Magazine (9mm Incendiary)"
	id = "vc_ammo_m9mm_fire"
	build_path = /obj/item/ammo_box/magazine/m9mm/fire
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/m10mm_ap
	name = "Handgun Magazine (10mm AP)"
	id = "vc_ammo_m10mm_ap"
	build_path = /obj/item/ammo_box/magazine/m10mm/ap
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/m10mm_hp
	name = "Handgun Magazine (10mm HP)"
	id = "vc_ammo_m10mm_hp"
	build_path = /obj/item/ammo_box/magazine/m10mm/hp
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 5,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT,
	)

/datum/design/vc_ammo/m10mm_fire
	name = "Handgun Magazine (10mm Incendiary)"
	id = "vc_ammo_m10mm_fire"
	build_path = /obj/item/ammo_box/magazine/m10mm/fire
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/aps_ap
	name = "APS Magazine (9mm AP)"
	id = "vc_ammo_aps_ap"
	build_path = /obj/item/ammo_box/magazine/m9mm_aps/ap
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 1.5,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/aps_hp
	name = "APS Magazine (9mm HP)"
	id = "vc_ammo_aps_hp"
	build_path = /obj/item/ammo_box/magazine/m9mm_aps/hp
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 6,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 1.5,
	)

/datum/design/vc_ammo/aps_fire
	name = "APS Magazine (9mm Incendiary)"
	id = "vc_ammo_aps_fire"
	build_path = /obj/item/ammo_box/magazine/m9mm_aps/fire
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 1.5,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/saber_ap
	name = "Saber Magazine (9mm AP)"
	id = "vc_ammo_saber_ap"
	build_path = /obj/item/ammo_box/magazine/smgm9mm/ap
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 1.5,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/saber_fire
	name = "Saber Magazine (9mm Incendiary)"
	id = "vc_ammo_saber_fire"
	build_path = /obj/item/ammo_box/magazine/smgm9mm/fire
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 1.5,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/c20r_ap
	name = "C-20r Magazine (.45 AP)"
	id = "vc_ammo_c20r_ap"
	build_path = /obj/item/ammo_box/magazine/smgm45/ap
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 5,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/c20r_hp
	name = "C-20r Magazine (.45 HP)"
	id = "vc_ammo_c20r_hp"
	build_path = /obj/item/ammo_box/magazine/smgm45/hp
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 7,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/c20r_fire
	name = "C-20r Magazine (.45 Incendiary)"
	id = "vc_ammo_c20r_fire"
	build_path = /obj/item/ammo_box/magazine/smgm45/incen
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 5,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/c38_match
	name = "Speed Loader (.38 Match)"
	id = "vc_ammo_c38_match"
	build_path = /obj/item/ammo_box/c38/match
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/silver = SHEET_MATERIAL_AMOUNT,
	)

/datum/design/vc_ammo/m38_match
	name = "Battle Rifle Magazine (.38 Match)"
	id = "vc_ammo_m38_match"
	build_path = /obj/item/ammo_box/magazine/m38/match
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 6,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/silver = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/c38_dumdum
	name = "Speed Loader (.38 DumDum)"
	id = "vc_ammo_c38_dumdum"
	build_path = /obj/item/ammo_box/c38/dumdum
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3,
	)

/datum/design/vc_ammo/m38_dumdum
	name = "Battle Rifle Magazine (.38 DumDum)"
	id = "vc_ammo_m38_dumdum"
	build_path = /obj/item/ammo_box/magazine/m38/dumdum
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 7,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/a357_match
	name = "Speed Loader (.357 Match)"
	id = "vc_ammo_a357_match"
	build_path = /obj/item/ammo_box/a357/match
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/silver = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/grenade_rubber
	name = "40mm Rubber Slug"
	id = "vc_ammo_grenade_rubber"
	build_path = /obj/item/ammo_casing/a40mm/rubber
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/shotgun_stun
	name = "Taser Slug"
	id = "vc_ammo_shotgun_stun"
	build_path = /obj/item/ammo_casing/shotgun/stunslug
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
		/datum/material/gold = SHEET_MATERIAL_AMOUNT,
	)

/datum/design/vc_ammo/shotgun_milspec_slug
	name = "Milspec Shotgun Slug"
	id = "vc_ammo_shotgun_milspec_slug"
	build_path = /obj/item/ammo_casing/shotgun/milspec
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT,
	)

/datum/design/vc_ammo/shotgun_milspec_buckshot
	name = "Milspec Buckshot Shell"
	id = "vc_ammo_shotgun_milspec_buckshot"
	build_path = /obj/item/ammo_casing/shotgun/buckshot/milspec
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT,
	)

/datum/design/vc_ammo/shotgun_executioner
	name = "Executioner Slug"
	id = "vc_ammo_shotgun_executioner"
	build_path = /obj/item/ammo_casing/shotgun/executioner
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/shotgun_pulverizer
	name = "Pulverizer Slug"
	id = "vc_ammo_shotgun_pulverizer"
	build_path = /obj/item/ammo_casing/shotgun/pulverizer
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/shotgun_incendiary_precision
	name = "Precision Incendiary Slug"
	id = "vc_ammo_shotgun_incendiary_precision"
	build_path = /obj/item/ammo_casing/shotgun/incendiary/no_trail
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT,
	)

/datum/design/vc_ammo/shotgun_meteor
	name = "Meteorslug Shell"
	id = "vc_ammo_shotgun_meteor"
	build_path = /obj/item/ammo_casing/shotgun/meteorslug
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/shotgun_incapacitating
	name = "Incapacitating Shot"
	id = "vc_ammo_shotgun_incapacitating"
	build_path = /obj/item/ammo_casing/shotgun/incapacitate
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/shotgun_ion
	name = "Ion Shell"
	id = "vc_ammo_shotgun_ion"
	build_path = /obj/item/ammo_casing/shotgun/ion
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/gold = SHEET_MATERIAL_AMOUNT,
		/datum/material/uranium = SHEET_MATERIAL_AMOUNT,
	)

/datum/design/vc_ammo/shotgun_dart_large
	name = "XL Shotgun Dart"
	id = "vc_ammo_shotgun_dart_large"
	build_path = /obj/item/ammo_casing/shotgun/dart/large
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
	)

/datum/design/vc_ammo/shotgun_breacher
	name = "Breaching Slug"
	id = "vc_ammo_shotgun_breacher"
	build_path = /obj/item/ammo_casing/shotgun/breacher
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT,
	)

/datum/design/vc_ammo/foam_smg_riot
	name = "Foam Force SMG Magazine (Riot Foam Darts)"
	id = "vc_ammo_foam_smg_riot"
	build_path = /obj/item/ammo_box/magazine/toy/smg/riot
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 13.5,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/foam_pistol_riot
	name = "Foam Force Pistol Magazine (Riot Foam Darts)"
	id = "vc_ammo_foam_pistol_riot"
	build_path = /obj/item/ammo_box/magazine/toy/pistol/riot
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 8.5,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/foam_smgm45_riot
	name = "Donksoft SMG Magazine (Riot Foam Darts)"
	id = "vc_ammo_foam_smgm45_riot"
	build_path = /obj/item/ammo_box/magazine/toy/smgm45/riot
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 13.5,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/foam_m762_riot
	name = "Donksoft Machine Gun Magazine (Riot Foam Darts)"
	id = "vc_ammo_foam_m762_riot"
	build_path = /obj/item/ammo_box/magazine/toy/m762/riot
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 32.25,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
	)

// Experimental ammunition.

/datum/design/vc_ammo/ronin
	name = "Ronin Magazine (10x24mm)"
	id = "vc_ammo_ronin"
	build_path = /obj/item/ammo_box/magazine/cyberware_ronin
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 8,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/silver = SHEET_MATERIAL_AMOUNT,
	)

/datum/design/vc_ammo/buster
	name = "Buster Rocket Pair (30mm)"
	id = "vc_ammo_buster"
	build_path = /obj/item/ammo_box/cyberware_buster_rockets
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 20,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 8,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 12,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/smartgun
	name = "Abielle Magazine (.160 Smart)"
	id = "vc_ammo_smartgun"
	build_path = /obj/item/ammo_box/magazine/smartgun
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/gold = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/silver = SHEET_MATERIAL_AMOUNT * 3,
	)

/datum/design/vc_ammo/reaper
	name = "Regal Condor Magazine (10mm Reaper)"
	id = "vc_ammo_reaper"
	build_path = /obj/item/ammo_box/magazine/r10mm
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/diamond = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/bluespace = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/a357_phasic
	name = "Speed Loader (.357 Phasic)"
	id = "vc_ammo_a357_phasic"
	build_path = /obj/item/ammo_box/a357/phasic
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/bluespace = SHEET_MATERIAL_AMOUNT * 3,
	)

/datum/design/vc_ammo/a357_heartseeker
	name = "Speed Loader (.357 Heartseeker)"
	id = "vc_ammo_a357_heartseeker"
	build_path = /obj/item/ammo_box/a357/heartseeker
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/gold = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/bluespace = SHEET_MATERIAL_AMOUNT * 3,
	)

/datum/design/vc_ammo/strilka_phasic
	name = "Stripper Clip (.310 Phasic)"
	id = "vc_ammo_strilka_phasic"
	build_path = /obj/item/ammo_box/strilka310/phasic
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/bluespace = SHEET_MATERIAL_AMOUNT * 3,
	)

/datum/design/vc_ammo/m223_phasic
	name = "Rifle Magazine (.223 Phasic)"
	id = "vc_ammo_m223_phasic"
	build_path = /obj/item/ammo_box/magazine/m223/phasic
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/bluespace = SHEET_MATERIAL_AMOUNT * 6,
	)

/datum/design/vc_ammo/rocket_heap
	name = "84mm HE-AP Rocket"
	id = "vc_ammo_rocket_heap"
	build_path = /obj/item/ammo_casing/rocket/heap
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 16,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 12,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 8,
		/datum/material/diamond = SHEET_MATERIAL_AMOUNT * 4,
	)

/datum/design/vc_ammo/shotgun_pulse
	name = "Pulse Slug"
	id = "vc_ammo_shotgun_pulse"
	build_path = /obj/item/ammo_casing/shotgun/pulseslug
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/gold = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/uranium = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/diamond = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/shotgun_bioterror
	name = "Bioterror Dart"
	id = "vc_ammo_shotgun_bioterror"
	build_path = /obj/item/ammo_casing/shotgun/dart/bioterror
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/silver = SHEET_MATERIAL_AMOUNT * 2,
	)

// Explosive ammunition.

/datum/design/vc_ammo/gyrojet
	name = "Gyrojet Magazine (.75)"
	id = "vc_ammo_gyrojet"
	build_path = /obj/item/ammo_box/magazine/m75
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 12,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 8,
	)

/datum/design/vc_ammo/grenade_he
	name = "40mm HE Grenade"
	id = "vc_ammo_grenade_he"
	build_path = /obj/item/ammo_casing/a40mm
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 3,
	)

/datum/design/vc_ammo/rocket_he
	name = "84mm HE Rocket"
	id = "vc_ammo_rocket_he"
	build_path = /obj/item/ammo_casing/rocket
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 12,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 8,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 4,
	)

/datum/design/vc_ammo/rocket_low_yield
	name = "84mm Low-Yield HE Rocket"
	id = "vc_ammo_rocket_low_yield"
	build_path = /obj/item/ammo_casing/rocket/weak
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 8,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/vc_ammo/shotgun_frag12
	name = "FRAG-12 Slug"
	id = "vc_ammo_shotgun_frag12"
	build_path = /obj/item/ammo_casing/shotgun/frag12
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 2,
	)

// Bulldog specialty drums.

/datum/design/vc_ammo/bulldog_stun
	name = "Bulldog Drum (12g Taser)"
	id = "vc_ammo_bulldog_stun"
	build_path = /obj/item/ammo_box/magazine/m12g/stun
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 6,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/gold = SHEET_MATERIAL_AMOUNT * 4,
	)

/datum/design/vc_ammo/bulldog_dragon
	name = "Bulldog Drum (12g Dragonsbreath)"
	id = "vc_ammo_bulldog_dragon"
	build_path = /obj/item/ammo_box/magazine/m12g/dragon
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 6,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 6,
	)

/datum/design/vc_ammo/bulldog_bioterror
	name = "Bulldog Drum (12g Bioterror)"
	id = "vc_ammo_bulldog_bioterror"
	build_path = /obj/item/ammo_box/magazine/m12g/bioterror
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 16,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT * 16,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 24,
		/datum/material/silver = SHEET_MATERIAL_AMOUNT * 16,
	)

/datum/design/vc_ammo/bulldog_meteor
	name = "Bulldog Drum (12g Meteor)"
	id = "vc_ammo_bulldog_meteor"
	build_path = /obj/item/ammo_box/magazine/m12g/meteor
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 24,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 12,
	)

/datum/design/vc_ammo/bulldog_flechette
	name = "Bulldog Drum (12g Flechette)"
	id = "vc_ammo_bulldog_flechette"
	build_path = /obj/item/ammo_box/magazine/m12g/flechette
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 8,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT * 4,
	)

/datum/design/vc_ammo/bulldog_donk
	name = "Bulldog Drum (12g Donk Spike)"
	id = "vc_ammo_bulldog_donk"
	build_path = /obj/item/ammo_box/magazine/m12g/donk
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 6,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 4,
	)

// L6 SAW specialty magazines.

/datum/design/vc_ammo/l6_ap
	name = "L6 SAW Magazine (7mm AP)"
	id = "vc_ammo_l6_ap"
	build_path = /obj/item/ammo_box/magazine/m7mm/ap
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 50,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 20,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 5,
	)

/datum/design/vc_ammo/l6_hp
	name = "L6 SAW Magazine (7mm HP)"
	id = "vc_ammo_l6_hp"
	build_path = /obj/item/ammo_box/magazine/m7mm/hollow
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 60,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 5,
	)

/datum/design/vc_ammo/l6_incendiary
	name = "L6 SAW Magazine (7mm Incendiary)"
	id = "vc_ammo_l6_incendiary"
	build_path = /obj/item/ammo_box/magazine/m7mm/incen
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 50,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 20,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 5,
	)

/datum/design/vc_ammo/l6_match
	name = "L6 SAW Magazine (7mm Match)"
	id = "vc_ammo_l6_match"
	build_path = /obj/item/ammo_box/magazine/m7mm/match
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 50,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 5,
		/datum/material/silver = SHEET_MATERIAL_AMOUNT * 5,
	)

/datum/design/vc_ammo/l6_rubber
	name = "L6 SAW Magazine (7mm Rubber)"
	id = "vc_ammo_l6_rubber"
	build_path = /obj/item/ammo_box/magazine/m7mm/bouncy
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 50,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 10,
	)

/datum/design/vc_ammo/l6_rubber_hicap
	name = "L6 SAW Magazine (7mm High-Capacity Rubber)"
	id = "vc_ammo_l6_rubber_hicap"
	build_path = /obj/item/ammo_box/magazine/m7mm/bouncy/hicap
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 150,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 30,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 30,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 30,
	)

// Anti-materiel specialty magazines.

/datum/design/vc_ammo/sniper_disruptor
	name = "Sniper Magazine (.50 BMG Disruptor)"
	id = "vc_ammo_sniper_disruptor"
	build_path = /obj/item/ammo_box/magazine/sniper_rounds/disruptor
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 8,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/gold = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/uranium = SHEET_MATERIAL_AMOUNT * 3,
	)

/datum/design/vc_ammo/sniper_incendiary
	name = "Sniper Magazine (.50 BMG Incendiary)"
	id = "vc_ammo_sniper_incendiary"
	build_path = /obj/item/ammo_box/magazine/sniper_rounds/incendiary
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 8,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 4,
	)

/datum/design/vc_ammo/sniper_penetrator
	name = "Sniper Magazine (.50 BMG Penetrator)"
	id = "vc_ammo_sniper_penetrator"
	build_path = /obj/item/ammo_box/magazine/sniper_rounds/penetrator
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 8,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/bluespace = SHEET_MATERIAL_AMOUNT * 4,
	)

/datum/design/vc_ammo/sniper_marksman
	name = "Sniper Magazine (.50 BMG Marksman)"
	id = "vc_ammo_sniper_marksman"
	build_path = /obj/item/ammo_box/magazine/sniper_rounds/marksman
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 8,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/silver = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/diamond = SHEET_MATERIAL_AMOUNT * 2,
	)
