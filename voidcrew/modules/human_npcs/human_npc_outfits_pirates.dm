/**
 * # Pirate faction outfits for human NPCs (N7, for phase B)
 *
 * The faction looks are today's faction pirate corpse outfits (voidcrew/modules/npc_ships/code/
 * faction_pirates/faction_pirate_corpses.dm), so a human pirate looks like the pirate players already
 * know. These subtypes add what the basic mob only drew: the real weapon in hand, and the real spare
 * magazines, shells or backup knife it fights on with (human_npc_ai.dm reloads from them the way a player
 * does). Energy guns can't be reloaded by hand, so energy gunners carry a knife.
 *
 * Guns per faction follow PR #500's crew gun weights; melee weapons, captains and bosses hold what the
 * basic mobs hold today, the bosses' with their own attack verbs (faction_pirate_humans.dm). The melee
 * crew carry a crowbar for unpowered doors. The ship crews that wear these are in
 * voidcrew/modules/npc_ships/code/faction_pirates/faction_pirate_humans.dm.
 *
 * Tables (one per faction): /datum/human_npc_outfit_table/pirate/<faction> dresses a mixed crew (melee
 * and gunners, the faction's captain for elites and its boss for bosses);
 * /datum/human_npc_outfit_table/pirate/<faction>/gunners only gunners. The ship crews add a boarding
 * table per faction (sealed for vacuum) and pick by their crew_role (faction_pirate_humans.dm). In vacuum
 * each faction gets its own space suit (vacuum_layer).
 */

/datum/human_npc_outfit_table/pirate
	vacuum_layer = /datum/human_npc_layer/eva/pirate
	/// Melee crew outfits: outfit typepath => weight
	var/list/melee
	/// Gunner outfits: outfit typepath => weight, as the faction's crew guns
	var/list/gunners
	/// Dress only gunners
	var/gunners_only = FALSE

/datum/human_npc_outfit_table/pirate/New()
	. = ..()
	if(!isnull(green))
		return
	green = gunners?.Copy() || list()
	if(gunners_only)
		return
	for(var/outfit_type in melee)
		green[outfit_type] = melee[outfit_type]

// ===== SILVERSCALE =====

/datum/human_npc_layer/eva/silverscale
	suit = /obj/item/clothing/suit/space/pirate/silverscale
	head = /obj/item/clothing/head/helmet/space/pirate/tophat

/datum/human_npc_outfit_table/pirate/silverscale
	vacuum_layer = /datum/human_npc_layer/eva/silverscale
	melee = list(/datum/outfit/piratecorpse/faction/silverscale/melee/armed = 4)
	gunners = list(
		/datum/outfit/piratecorpse/faction/silverscale/ranged/energy_gun = 3,
		/datum/outfit/piratecorpse/faction/silverscale/ranged/laser_rifle = 2,
		/datum/outfit/piratecorpse/faction/silverscale/ranged/pistol = 3,
		/datum/outfit/piratecorpse/faction/silverscale/ranged/shotgun = 1,
	)
	elite = list(/datum/outfit/piratecorpse/faction/silverscale/captain/armed = 1)
	boss = list(/datum/outfit/piratecorpse/faction/silverscale/highlord/armed = 1)

/datum/human_npc_outfit_table/pirate/silverscale/gunners
	gunners_only = TRUE

/datum/outfit/piratecorpse/faction/silverscale/melee/armed
	name = "Human NPC: Silverscale Duelist"
	r_hand = /obj/item/melee/energy/sword/pirate
	l_pocket = /obj/item/crowbar

/datum/outfit/piratecorpse/faction/silverscale/ranged/energy_gun
	name = "Human NPC: Silverscale Marksman (energy gun)"
	r_hand = /obj/item/gun/energy/e_gun/lethal
	l_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/silverscale/ranged/laser_rifle
	name = "Human NPC: Silverscale Marksman (laser rifle)"
	r_hand = /obj/item/gun/energy/laser
	l_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/silverscale/ranged/pistol
	name = "Human NPC: Silverscale Marksman (pistol)"
	r_hand = /obj/item/gun/ballistic/automatic/pistol
	l_pocket = /obj/item/ammo_box/magazine/m9mm
	r_pocket = /obj/item/ammo_box/magazine/m9mm

/datum/outfit/piratecorpse/faction/silverscale/ranged/shotgun
	name = "Human NPC: Silverscale Marksman (shotgun)"
	r_hand = /obj/item/gun/ballistic/shotgun/lethal
	belt = /obj/item/storage/belt/bandolier
	belt_contents = list(/obj/item/ammo_casing/shotgun/buckshot = 8)

/datum/outfit/piratecorpse/faction/silverscale/captain/armed
	name = "Human NPC: Silverscale Noble"
	r_hand = /obj/item/melee/sabre

/datum/outfit/piratecorpse/faction/silverscale/highlord/armed
	name = "Human NPC: Silverscale Highlord"
	r_hand = /obj/item/melee/energy/sword/pirate/boss

// ===== SKELETON =====

/datum/human_npc_layer/eva/pirate/bandana
	head = /obj/item/clothing/head/helmet/space/pirate/bandana

// Skeletons don't breathe and shrug off vacuum and cold (their species), so they rarely need the suit.
/datum/human_npc_outfit_table/pirate/skeleton
	vacuum_layer = /datum/human_npc_layer/eva/pirate/bandana
	melee = list(/datum/outfit/piratecorpse/faction/skeleton/melee/armed = 4)
	gunners = list(
		/datum/outfit/piratecorpse/faction/skeleton/ranged/laser_rifle = 1,
		/datum/outfit/piratecorpse/faction/skeleton/ranged/pistol = 2,
		/datum/outfit/piratecorpse/faction/skeleton/ranged/smg = 2,
		/datum/outfit/piratecorpse/faction/skeleton/ranged/shotgun = 3,
	)
	elite = list(/datum/outfit/piratecorpse/faction/skeleton/captain/armed = 1)
	boss = list(/datum/outfit/piratecorpse/faction/skeleton/davyjones/armed = 1)

/datum/human_npc_outfit_table/pirate/skeleton/gunners
	gunners_only = TRUE

/datum/outfit/piratecorpse/faction/skeleton/melee/armed
	name = "Human NPC: Skeleton Swashbuckler"
	r_hand = /obj/item/melee/energy/sword/pirate
	l_pocket = /obj/item/crowbar

/datum/outfit/piratecorpse/faction/skeleton/ranged/laser_rifle
	name = "Human NPC: Skeleton Gunner (laser rifle)"
	r_hand = /obj/item/gun/energy/laser
	l_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/skeleton/ranged/pistol
	name = "Human NPC: Skeleton Gunner (pistol)"
	r_hand = /obj/item/gun/ballistic/automatic/pistol
	l_pocket = /obj/item/ammo_box/magazine/m9mm
	r_pocket = /obj/item/ammo_box/magazine/m9mm

/datum/outfit/piratecorpse/faction/skeleton/ranged/smg
	name = "Human NPC: Skeleton Gunner (SMG)"
	r_hand = /obj/item/gun/ballistic/automatic/mini_uzi
	l_pocket = /obj/item/ammo_box/magazine/uzim9mm
	r_pocket = /obj/item/ammo_box/magazine/uzim9mm

/datum/outfit/piratecorpse/faction/skeleton/ranged/shotgun
	name = "Human NPC: Skeleton Gunner (shotgun)"
	r_hand = /obj/item/gun/ballistic/shotgun/lethal
	belt = /obj/item/storage/belt/bandolier
	belt_contents = list(/obj/item/ammo_casing/shotgun/buckshot = 8)

/datum/outfit/piratecorpse/faction/skeleton/captain/armed
	name = "Human NPC: Skeleton Captain"
	r_hand = /obj/item/claymore/cutlass

// His flask of cursed grog (voidcrew/modules/npc_ships/code/faction_pirates/faction_pirate_humans.dm) where
// the corpse kept a doubloon.
/datum/outfit/piratecorpse/faction/skeleton/davyjones/armed
	name = "Human NPC: Davy Jones"
	r_hand = /obj/item/claymore/cutlass/davy_jones
	l_pocket = /obj/item/reagent_containers/cup/glass/flask/davy_jones

// ===== GREY TIDE =====

// Assistants in the station's grey EVA suits: slow, but sealed.
/datum/human_npc_outfit_table/pirate/grey
	vacuum_layer = /datum/human_npc_layer/eva
	melee = list(/datum/outfit/piratecorpse/faction/grey/melee/armed = 4)
	gunners = list(
		/datum/outfit/piratecorpse/faction/grey/ranged/energy_gun = 3,
		/datum/outfit/piratecorpse/faction/grey/ranged/laser_rifle = 3,
		/datum/outfit/piratecorpse/faction/grey/ranged/smg = 1,
	)
	elite = list(/datum/outfit/piratecorpse/faction/grey/captain/armed = 1)
	boss = list(/datum/outfit/piratecorpse/faction/grey/robust/armed = 1)

/datum/human_npc_outfit_table/pirate/grey/gunners
	gunners_only = TRUE

/datum/outfit/piratecorpse/faction/grey/melee/armed
	name = "Human NPC: Grey Tider"
	r_hand = /obj/item/storage/toolbox/mechanical
	l_pocket = /obj/item/crowbar

/datum/outfit/piratecorpse/faction/grey/ranged/energy_gun
	name = "Human NPC: Grey Tider Gunner (energy gun)"
	r_hand = /obj/item/gun/energy/e_gun/lethal
	l_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/grey/ranged/laser_rifle
	name = "Human NPC: Grey Tider Gunner (laser rifle)"
	r_hand = /obj/item/gun/energy/laser
	l_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/grey/ranged/smg
	name = "Human NPC: Grey Tider Gunner (SMG)"
	r_hand = /obj/item/gun/ballistic/automatic/mini_uzi
	l_pocket = /obj/item/ammo_box/magazine/uzim9mm
	r_pocket = /obj/item/ammo_box/magazine/uzim9mm

/datum/outfit/piratecorpse/faction/grey/captain/armed
	name = "Human NPC: Tidemaster"
	r_hand = /obj/item/storage/toolbox/syndicate

/datum/outfit/piratecorpse/faction/grey/robust/armed
	name = "Human NPC: The Robust One"
	r_hand = /obj/item/storage/toolbox/mechanical/old/clean/robust_one

// ===== LUSTROUS =====

/datum/human_npc_outfit_table/pirate/lustrous
	melee = list(/datum/outfit/piratecorpse/faction/lustrous/melee/armed = 4)
	gunners = list(
		/datum/outfit/piratecorpse/faction/lustrous/ranged/energy_gun = 3,
		/datum/outfit/piratecorpse/faction/lustrous/ranged/laser_rifle = 3,
		/datum/outfit/piratecorpse/faction/lustrous/ranged/pistol = 1,
	)
	elite = list(/datum/outfit/piratecorpse/faction/lustrous/captain/armed = 1)
	boss = list(/datum/outfit/piratecorpse/faction/lustrous/radiant/armed = 1)

/datum/human_npc_outfit_table/pirate/lustrous/gunners
	gunners_only = TRUE

/datum/outfit/piratecorpse/faction/lustrous/melee/armed
	name = "Human NPC: Lustrous Scintillant"
	r_hand = /obj/item/switchblade
	l_pocket = /obj/item/crowbar

/datum/outfit/piratecorpse/faction/lustrous/ranged/energy_gun
	name = "Human NPC: Lustrous Coruscant (energy gun)"
	r_hand = /obj/item/gun/energy/e_gun/lethal
	l_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/lustrous/ranged/laser_rifle
	name = "Human NPC: Lustrous Coruscant (laser rifle)"
	r_hand = /obj/item/gun/energy/laser
	l_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/lustrous/ranged/pistol
	name = "Human NPC: Lustrous Coruscant (pistol)"
	r_hand = /obj/item/gun/ballistic/automatic/pistol
	l_pocket = /obj/item/ammo_box/magazine/m9mm
	r_pocket = /obj/item/ammo_box/magazine/m9mm

/datum/outfit/piratecorpse/faction/lustrous/captain/armed
	name = "Human NPC: Lustrous Radiant"
	r_hand = /obj/item/melee/energy/sword/pirate

/datum/outfit/piratecorpse/faction/lustrous/radiant/armed
	name = "Human NPC: The Radiant One"
	r_hand = /obj/item/melee/energy/sword/pirate/boss/radiant

// ===== INTERDYNE =====

/datum/human_npc_layer/eva/interdyne
	suit = /obj/item/clothing/suit/space/syndicate/black/med
	head = /obj/item/clothing/head/helmet/space/syndicate/black/med

/datum/human_npc_outfit_table/pirate/interdyne
	vacuum_layer = /datum/human_npc_layer/eva/interdyne
	melee = list(/datum/outfit/piratecorpse/faction/interdyne/melee/armed = 4)
	gunners = list(
		/datum/outfit/piratecorpse/faction/interdyne/ranged/energy_gun = 2,
		/datum/outfit/piratecorpse/faction/interdyne/ranged/pistol = 2,
		/datum/outfit/piratecorpse/faction/interdyne/ranged/smg = 3,
		/datum/outfit/piratecorpse/faction/interdyne/ranged/shotgun = 1,
	)
	elite = list(/datum/outfit/piratecorpse/faction/interdyne/captain/armed = 1)
	boss = list(/datum/outfit/piratecorpse/faction/interdyne/prime/armed = 1)

/datum/human_npc_outfit_table/pirate/interdyne/gunners
	gunners_only = TRUE

/datum/outfit/piratecorpse/faction/interdyne/melee/armed
	name = "Human NPC: Interdyne Enforcer"
	r_hand = /obj/item/scalpel
	l_pocket = /obj/item/crowbar

/datum/outfit/piratecorpse/faction/interdyne/ranged/energy_gun
	name = "Human NPC: Interdyne Pharmacist (energy gun)"
	r_hand = /obj/item/gun/energy/e_gun/lethal
	l_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/interdyne/ranged/pistol
	name = "Human NPC: Interdyne Pharmacist (pistol)"
	r_hand = /obj/item/gun/ballistic/automatic/pistol
	l_pocket = /obj/item/ammo_box/magazine/m9mm
	r_pocket = /obj/item/ammo_box/magazine/m9mm

/datum/outfit/piratecorpse/faction/interdyne/ranged/smg
	name = "Human NPC: Interdyne Pharmacist (SMG)"
	r_hand = /obj/item/gun/ballistic/automatic/mini_uzi
	l_pocket = /obj/item/ammo_box/magazine/uzim9mm
	r_pocket = /obj/item/ammo_box/magazine/uzim9mm

/datum/outfit/piratecorpse/faction/interdyne/ranged/shotgun
	name = "Human NPC: Interdyne Pharmacist (shotgun)"
	r_hand = /obj/item/gun/ballistic/shotgun/lethal
	belt = /obj/item/storage/belt/bandolier
	belt_contents = list(/obj/item/ammo_casing/shotgun/buckshot = 8)

/datum/outfit/piratecorpse/faction/interdyne/captain/armed
	name = "Human NPC: Interdyne Director"
	r_hand = /obj/item/melee/energy/sword/pirate

// Today's Director Prime shoots lasers from its body; the human one holds the gun, with its combat
// hypospray in a pocket for phase B's self-treatment.
/datum/outfit/piratecorpse/faction/interdyne/prime/armed
	name = "Human NPC: Interdyne Director Prime"
	r_hand = /obj/item/gun/energy/e_gun/lethal
	l_pocket = /obj/item/knife/combat/survival
	r_pocket = /obj/item/reagent_containers/hypospray/combat

// ===== IRS =====

/datum/human_npc_layer/eva/irs
	suit = /obj/item/clothing/suit/space/syndicate/black
	head = /obj/item/clothing/head/helmet/space/syndicate/black

/datum/human_npc_outfit_table/pirate/irs
	vacuum_layer = /datum/human_npc_layer/eva/irs
	melee = list(/datum/outfit/piratecorpse/faction/irs/melee/armed = 4)
	gunners = list(
		/datum/outfit/piratecorpse/faction/irs/ranged/energy_gun = 1,
		/datum/outfit/piratecorpse/faction/irs/ranged/pistol = 3,
		/datum/outfit/piratecorpse/faction/irs/ranged/smg = 2,
		/datum/outfit/piratecorpse/faction/irs/ranged/shotgun = 2,
	)
	elite = list(/datum/outfit/piratecorpse/faction/irs/captain/armed = 1)
	boss = list(/datum/outfit/piratecorpse/faction/irs/chief/armed = 1)

/datum/human_npc_outfit_table/pirate/irs/gunners
	gunners_only = TRUE

// A real telescopic baton: it knocks people down, where the basic mob's only did brute.
/datum/outfit/piratecorpse/faction/irs/melee/armed
	name = "Human NPC: IRS Enforcer"
	r_hand = /obj/item/melee/baton/telescopic
	l_pocket = /obj/item/crowbar

/datum/outfit/piratecorpse/faction/irs/ranged/energy_gun
	name = "Human NPC: IRS Agent (energy gun)"
	r_hand = /obj/item/gun/energy/e_gun/lethal
	l_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/irs/ranged/pistol
	name = "Human NPC: IRS Agent (pistol)"
	r_hand = /obj/item/gun/ballistic/automatic/pistol
	l_pocket = /obj/item/ammo_box/magazine/m9mm
	r_pocket = /obj/item/ammo_box/magazine/m9mm

/datum/outfit/piratecorpse/faction/irs/ranged/smg
	name = "Human NPC: IRS Agent (SMG)"
	r_hand = /obj/item/gun/ballistic/automatic/mini_uzi
	l_pocket = /obj/item/ammo_box/magazine/uzim9mm
	r_pocket = /obj/item/ammo_box/magazine/uzim9mm

/datum/outfit/piratecorpse/faction/irs/ranged/shotgun
	name = "Human NPC: IRS Agent (shotgun)"
	r_hand = /obj/item/gun/ballistic/shotgun/lethal
	belt = /obj/item/storage/belt/bandolier
	belt_contents = list(/obj/item/ammo_casing/shotgun/buckshot = 8)

/datum/outfit/piratecorpse/faction/irs/captain/armed
	name = "Human NPC: IRS Head Auditor"
	r_hand = /obj/item/gun/energy/e_gun/lethal
	l_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/irs/chief/armed
	name = "Human NPC: IRS Chief Auditor"
	r_hand = /obj/item/gun/energy/e_gun/lethal
	l_pocket = /obj/item/knife/combat/survival
	r_pocket = /obj/item/reagent_containers/hypospray/medipen/stimulants

// ===== MEDIEVAL =====

// Footsoldiers and the warlord hate guns (TRAIT_NOGUNS, set by phase B on their types); only the
// crossbowmen shoot, and their crossbows recharge by themselves.
/datum/human_npc_outfit_table/pirate/medieval
	melee = list(/datum/outfit/piratecorpse/faction/medieval/melee/armed = 2)
	gunners = list(/datum/outfit/piratecorpse/faction/medieval/ranged/crossbow = 1)
	elite = list(/datum/outfit/piratecorpse/faction/medieval/captain/armed = 1)
	boss = list(/datum/outfit/piratecorpse/faction/medieval/blackknight/armed = 1)

/datum/human_npc_outfit_table/pirate/medieval/gunners
	gunners_only = TRUE

/datum/outfit/piratecorpse/faction/medieval/melee/armed
	name = "Human NPC: Medieval Footsoldier"
	r_hand = /obj/item/claymore/shortsword
	l_pocket = /obj/item/crowbar

/datum/outfit/piratecorpse/faction/medieval/ranged/crossbow
	name = "Human NPC: Medieval Crossbowman"
	r_hand = /obj/item/gun/energy/recharge/ebow/large
	l_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/medieval/captain/armed
	name = "Human NPC: Medieval Warlord"
	r_hand = /obj/item/fireaxe/boardingaxe/warlord

/datum/outfit/piratecorpse/faction/medieval/blackknight/armed
	name = "Human NPC: The Black Knight"
	r_hand = /obj/item/claymore/black_knight
