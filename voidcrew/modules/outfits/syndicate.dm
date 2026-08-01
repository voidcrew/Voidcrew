/**
 * Syndicate
 */
/datum/outfit/job/captain/syndicate
	name = "Captain (Syndicate)"

	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/armor/vest/capcarapace/syndicate
	suit_store = /obj/item/gun/ballistic/revolver/mateba
	head = /obj/item/clothing/head/hats/hos/beret/syndicate
	glasses = /obj/item/clothing/glasses/thermal/eyepatch

	l_pocket = /obj/item/melee/energy/sword/saber/red
	r_pocket = /obj/item/melee/baton/telescopic

	id = /obj/item/card/id/advanced/black/syndicate_command/captain_id
	id_trim = /datum/id_trim/syndicom/captain

//medical
/datum/outfit/job/cmo/syndicate
	name = "Chief Medical Officer (Syndicate)"

	uniform = /obj/item/clothing/under/syndicate
	shoes = /obj/item/clothing/shoes/jackboots

	id = /obj/item/card/id/advanced/black/syndicate_command/captain_id

/datum/outfit/job/doctor/syndicate
	name = "Medical Doctor (Syndicate)"

	uniform = /obj/item/clothing/under/syndicate
	shoes = /obj/item/clothing/shoes/jackboots

	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id

/datum/outfit/job/paramedic/syndicate/gorlex
	name = "Paramedic (Syndicate)"

	uniform = /obj/item/clothing/under/syndicate
	shoes = /obj/item/clothing/shoes/jackboots

	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id

//service
/datum/outfit/job/botanist/syndicate
	name = "Botanist (Syndicate)"

	uniform = /obj/item/clothing/under/syndicate
	shoes = /obj/item/clothing/shoes/jackboots
	glasses = /obj/item/clothing/glasses/science

	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id

//engineering
/datum/outfit/job/ce/syndicate
	name = "Chief Engineer (Syndicate)"

	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/hazardvest
	shoes = /obj/item/clothing/shoes/jackboots
	gloves = /obj/item/clothing/gloves/combat

	id = /obj/item/card/id/advanced/black/syndicate_command/captain_id

/datum/outfit/job/engineer/syndicate
	name = "Station Engineer (Syndicate)"

	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/hazardvest
	head = /obj/item/clothing/head/utility/hardhat

	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id

/datum/outfit/job/atmos/syndicate
	name = "Atmospheric Technician (Syndicate)"
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/hazardvest
	head = /obj/item/clothing/head/utility/hardhat

	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id

//supply
/datum/outfit/job/miner/syndicate
	name = "Shaft Miner (Syndicate)"

	uniform = /obj/item/clothing/under/syndicate
	accessory = /obj/item/clothing/accessory/armband/cargo
	head = /obj/item/clothing/head/utility/hardhat/orange

	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id

//assistant
/datum/outfit/job/assistant/syndicate
	name = "Assistant (Syndicate)"

	glasses = /obj/item/clothing/glasses/night
	belt = /obj/item/storage/belt/military
	back = /obj/item/storage/backpack/duffelbag/syndie
	suit = /obj/item/clothing/suit/armor/vest/blueshirt
	suit_store = /obj/item/gun/ballistic/automatic/pistol
	shoes = /obj/item/clothing/shoes/combat

	l_pocket = /obj/item/ammo_box/magazine/m10mm
	r_pocket = /obj/item/knife/combat/survival

	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id

/datum/outfit/job/assistant/syndicate/give_jumpsuit(mob/living/carbon/human/target)
	uniform = /obj/item/clothing/under/syndicate/camo

/**
 * Syndicate Cutter theme crew (purchasable goon hull).
 *
 * Reskins of the standard job outfits, NOT the legacy syndicate loadouts
 * above. The legacy ones were written for the off-shelf NPC hulls and carry
 * antag-tier gear (Mateba, energy saber, thermals, Stechkins) plus IDs with
 * ACCESS_SYNDICATE, which opens syndicate ruin and outpost doors for free.
 * These keep the look while inheriting the same IDs, access and standard
 * kit as every other purchasable theme's crew.
 */
/datum/outfit/job/captain/syndicate_cutter
	name = "Team Leader (Syndicate Cutter)"

	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/armor/vest/capcarapace/syndicate
	head = /obj/item/clothing/head/hats/hos/beret/syndicate
	glasses = /obj/item/clothing/glasses/eyepatch
	shoes = /obj/item/clothing/shoes/jackboots

/datum/outfit/job/engineer/syndicate_cutter
	name = "Combat Engineer (Syndicate Cutter)"

	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/hazardvest
	head = /obj/item/clothing/head/utility/hardhat

/datum/outfit/job/doctor/syndicate_cutter
	name = "Field Medic (Syndicate Cutter)"

	uniform = /obj/item/clothing/under/syndicate
	shoes = /obj/item/clothing/shoes/jackboots

/datum/outfit/job/miner/syndicate_cutter
	name = "Salvage Operative (Syndicate Cutter)"

	uniform = /obj/item/clothing/under/syndicate
	accessory = /obj/item/clothing/accessory/armband/cargo
	head = /obj/item/clothing/head/utility/hardhat/orange

/datum/outfit/job/assistant/syndicate_cutter
	name = "Operative (Syndicate Cutter)"

	back = /obj/item/storage/backpack/duffelbag/syndie
	belt = /obj/item/storage/belt/military
	shoes = /obj/item/clothing/shoes/combat
	l_pocket = /obj/item/modular_computer/pda/assistant
	r_pocket = /obj/item/knife/combat/survival

/datum/outfit/job/assistant/syndicate_cutter/give_jumpsuit(mob/living/carbon/human/target)
	uniform = /obj/item/clothing/under/syndicate/camo
