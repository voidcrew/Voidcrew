// Shared role kits, also inherited by purchased hulls and module-added jobs.
/datum/outfit/job/security
	backpack_contents = list(/obj/item/evidencebag = 1, /obj/item/knife/combat/survival = 1)

/datum/outfit/job/warden
	backpack_contents = list(/obj/item/evidencebag = 1, /obj/item/knife/combat/survival = 1)

/datum/outfit/job/hos
	suit_store = null
	backpack_contents = list(
		/obj/item/evidencebag = 1,
		/obj/item/melee/baton/security/loaded/hos = 1,
		/obj/item/knife/combat/survival = 1,
	)

/datum/outfit/job/bridge_assistant
	l_pocket = null

/datum/outfit/job/proc/ladder_add_survival_knife()
	backpack_contents = backpack_contents?.Copy() || list()
	backpack_contents[/obj/item/knife/combat/survival] = 1

/datum/outfit/job/miner/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	ladder_add_survival_knife()

/datum/outfit/job/security/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	ladder_add_survival_knife()

/datum/outfit/job/warden/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	ladder_add_survival_knife()

/datum/outfit/job/hos/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	ladder_add_survival_knife()

/// Only remove kit created by this equip call, never a player's existing salvage.
/proc/remove_ladder_starting_weapons(mob/living/carbon/human/wearer, list/previous_contents)
	for(var/obj/item/item in wearer.get_all_contents() - previous_contents)
		if(is_ladder_combat_gun(item.type) || is_ladder_restricted_melee(item.type))
			qdel(item)

/datum/outfit/job/equip(mob/living/carbon/human/user, visuals_only = FALSE)
	var/list/previous_contents = user.get_all_contents()
	. = ..()
	remove_ladder_starting_weapons(user, previous_contents)
	if(visuals_only)
		return
	// Workshop pre_equip overrides can replace their parent's entire backpack list.
	// Check the finished kit rather than overwriting medical supplies or tools.
	if(!istype(src, /datum/outfit/job/miner) && !istype(src, /datum/outfit/job/security) && !istype(src, /datum/outfit/job/warden) && !istype(src, /datum/outfit/job/hos))
		return
	if(locate(/obj/item/knife/combat/survival) in user.get_all_contents())
		return
	var/obj/item/knife/combat/survival/knife = new(user)
	if(!user.equip_to_storage(knife, ITEM_SLOT_BACK, indirect_action = TRUE))
		user.put_in_hands(knife)

// Corpse and ghost-role outfits are also fixed starting placements.
/obj/effect/mob_spawn/equip(mob/living/spawned_mob)
	. = ..()
	if(ishuman(spawned_mob))
		remove_ladder_starting_weapons(spawned_mob, list())

/datum/voucher_set/mining/crusher_kit
	name = "Accelerator Kit"
	description = "A mining accelerator and a pocket extinguisher."
	icon_state = "kineticgun"
	set_items = list(/obj/item/gun/energy/recharge/kinetic_accelerator, /obj/item/extinguisher/mini)

// Direct variants remain available to guarded loot, but not to the free picker.
/obj/item/nullrod/claymore
	chaplain_spawnable = FALSE

/obj/item/nullrod/vibro
	chaplain_spawnable = FALSE

/obj/item/nullrod/hypertool
	chaplain_spawnable = FALSE

/datum/component/subtype_picker/Initialize(list/subtype2descriptions, on_picked_callback)
	if(istype(parent, /obj/item/nullrod))
		subtype2descriptions = subtype2descriptions.Copy()
		for(var/choice in subtype2descriptions)
			if(ispath(choice, /obj/item/gun) || ispath(choice, /obj/item/organ/cyberimp/arm/toolkit/shard/scythe))
				subtype2descriptions -= choice
			else
				subtype2descriptions[choice] = null
	return ..(subtype2descriptions, on_picked_callback)
