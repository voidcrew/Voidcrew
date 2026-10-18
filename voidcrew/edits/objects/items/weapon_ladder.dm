/// Work tools and control weapons remain available independently of the gun ladder.
/proc/is_ladder_combat_gun(item_type)
	if(!ispath(item_type, /obj/item/gun))
		return FALSE
	// Build the shared classification cache on first use.
	var/static/list/tool_guns
	if(!tool_guns)
		tool_guns = typecacheof(list(
			/obj/item/gun/energy/disabler,
			/obj/item/gun/energy/floragun,
			/obj/item/gun/energy/wiremod_gun,
			/obj/item/gun/energy/plasmacutter,
			/obj/item/gun/energy/recharge/kinetic_accelerator,
			/obj/item/gun/energy/recharge/fisher,
			/obj/item/gun/medbeam,
			/obj/item/gun/energy/laser/bluetag,
			/obj/item/gun/energy/laser/redtag,
			/obj/item/gun/energy/laser/chameleon,
			/obj/item/gun/ballistic/automatic/toy,
			/obj/item/gun/ballistic/automatic/pistol/toy,
			/obj/item/gun/ballistic/shotgun/toy,
			/obj/item/gun/magic/wand/nothing,
		))
	return item_type != /obj/item/gun/syringe && !is_type_in_typecache(item_type, tool_guns)

/// Weapons excluded from starting equipment, cargo and unguarded floor sources.
/proc/is_ladder_restricted_melee(item_type)
	if(ispath(item_type, /obj/item/knife/combat/survival) || ispath(item_type, /obj/item/knife/combat/bone) || ispath(item_type, /obj/item/shovel/serrated/dull))
		return FALSE
	var/static/list/restricted
	if(!restricted)
		restricted = typecacheof(list(
			/obj/item/knife/combat,
			/obj/item/knife/bloodletter,
			/obj/item/knife/hunting/wildhunter,
			/obj/item/claymore,
			/obj/item/katana,
			/obj/item/energy_katana,
			/obj/item/melee/energy/sword,
			/obj/item/melee/sabre,
			/obj/item/melee/cleric_mace,
			/obj/item/melee/baseball_bat/ablative,
			/obj/item/melee/parsnip_sabre,
			/obj/item/melee/supermatter_sword,
			/obj/item/fireaxe,
			/obj/item/chainsaw,
			/obj/item/kinetic_crusher,
			/obj/item/switchblade,
			/obj/item/singularityhammer,
			/obj/item/house_edge,
			/obj/item/shovel/giant_wrench,
			/obj/item/shovel/serrated,
			/obj/item/spear/explosive,
			/obj/item/spear/grey_tide,
			/obj/item/shield/riot,
			/obj/item/shield/kite,
			/obj/item/shield/buckler,
			/obj/item/shield/roman,
			/obj/item/shield/energy,
			/obj/item/storage/toolbox/mechanical/old/clean,
		))
	return is_type_in_typecache(item_type, restricted)

/proc/is_ladder_restricted_production(item_type)
	return is_ladder_combat_gun(item_type) \
		|| is_ladder_restricted_melee(item_type) \
		|| ispath(item_type, /obj/item/weaponcrafting/receiver) \
		|| ispath(item_type, /obj/item/weaponcrafting/gunkit) \
		|| ispath(item_type, /obj/item/weaponcrafting/giant_wrench) \
		|| ispath(item_type, /obj/structure/mounted_gun/pipe) \
		|| ispath(item_type, /obj/item/disk/design_disk/liberator)

// These are unguarded floor/maintenance sources, including nested random spawners.
/obj/effect/spawner/random/armory/make_item(spawn_loc, type_path_to_make)
	return ..(spawn_loc, ladder_floor_replacement(type_path_to_make))

/obj/effect/spawner/random/contraband/make_item(spawn_loc, type_path_to_make)
	return ..(spawn_loc, ladder_floor_replacement(type_path_to_make))

/obj/effect/spawner/random/exotic/make_item(spawn_loc, type_path_to_make)
	return ..(spawn_loc, ladder_floor_replacement(type_path_to_make))

/obj/effect/spawner/random/maintenance/make_item(spawn_loc, type_path_to_make)
	return ..(spawn_loc, ladder_floor_replacement(type_path_to_make))

// These consumers draw from the same global maintenance table without a spawner.
/datum/shuttle_event/simple_spawner/maintenance/get_type_to_spawn()
	return ladder_floor_replacement(..())

/datum/adventure_loot_generator/maintenance/generate()
	. = ..()
	for(var/index in 1 to length(.))
		var/atom/movable/item = .[index]
		var/replacement = ladder_floor_replacement(item.type)
		if(replacement != item.type)
			.[index] = new replacement(item.loc)
			qdel(item)

/proc/ladder_floor_replacement(item_type)
	if(is_ladder_combat_gun(item_type) || ispath(item_type, /obj/item/weaponcrafting/receiver) || ispath(item_type, /obj/item/weaponcrafting/giant_wrench))
		return /obj/item/melee/baseball_bat
	if(!is_ladder_restricted_melee(item_type))
		return item_type
	var/static/list/red_melee = typecacheof(list(
		/obj/item/katana,
		/obj/item/claymore,
		/obj/item/energy_katana,
		/obj/item/melee/energy/sword,
		/obj/item/knife/bloodletter,
		/obj/item/chainsaw/doomslayer,
		/obj/item/singularityhammer,
		/obj/item/house_edge,
		/obj/item/shield/energy,
		/obj/item/storage/toolbox/mechanical/old/clean,
	))
	if(is_type_in_typecache(item_type, red_melee) && !ispath(item_type, /obj/item/claymore/shortsword) && !ispath(item_type, /obj/item/claymore/cutlass/old))
		return /obj/item/spear
	return /obj/item/knife/combat/survival

// Availability is checked from initial values by SSmarket, including restocks.
/datum/market_item/weapon/sks_kit
	availability_prob = 0

/datum/market_item/weapon/chainsaw
	availability_prob = 0

/datum/market_item/weapon/switchblade
	availability_prob = 0

/datum/market_item/weapon/giant_wrench_parts
	availability_prob = 0

/datum/market_item/weapon/liberator
	availability_prob = 0

/datum/market_item/tool/riot_shield
	availability_prob = 0

// Rebuilt vendors must inherit the same stock as mapped ones.
/obj/machinery/vending/games
	contraband = list(
		/obj/item/dice/fudge = 9,
		/obj/item/clothing/shoes/wheelys/skishoes = 4,
		/obj/item/instrument/musicalmoth = 1,
		/obj/item/melee/baseball_bat = 1,
		/obj/item/skillchip/acrobatics = 1,
	)
