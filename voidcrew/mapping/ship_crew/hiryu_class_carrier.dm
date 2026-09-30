// Ship Workshop crew outfits. Edit these through the crew editor.

/datum/outfit/job/workshop_hiryu_class_carrier_job_20
	parent_type = /datum/outfit/job/bartender
	name = "Hiryu-class Carrier — Barmaid"
	uniform = /obj/item/clothing/under/costume/maid
	head = /obj/item/clothing/head/costume/maid_headband
	neck = null
	suit_store = /obj/item/gun/ballistic/shotgun/doublebarrel
	accessory = null
	backpack_contents = list(/obj/item/storage/box/lethalshot = 1)

/datum/outfit/job/workshop_hiryu_class_carrier_job_20/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/costume/maid
	head = /obj/item/clothing/head/costume/maid_headband
	neck = null
	suit_store = /obj/item/gun/ballistic/shotgun/doublebarrel
	accessory = null
	backpack_contents = list(/obj/item/storage/box/lethalshot = 1)

/datum/outfit/job/workshop_hiryu_class_carrier_job_12
	parent_type = /datum/outfit/job/bartender
	name = "Hiryu-class Carrier — Bartender"
	suit_store = /obj/item/gun/ballistic/shotgun/doublebarrel
	accessory = null
	backpack_contents = list(/obj/item/storage/box/lethalshot = 1)

/datum/outfit/job/workshop_hiryu_class_carrier_job_12/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	suit_store = /obj/item/gun/ballistic/shotgun/doublebarrel
	accessory = null
	backpack_contents = list(/obj/item/storage/box/lethalshot = 1)

/datum/outfit/job/workshop_hiryu_class_carrier_job_14
	parent_type = /datum/outfit/job/bartender
	name = "Hiryu-class Carrier — Bartender"
	uniform = /obj/item/clothing/under/syndicate
	suit_store = /obj/item/gun/ballistic/shotgun/doublebarrel
	accessory = null
	backpack_contents = list(/obj/item/storage/box/lethalshot = 1)

/datum/outfit/job/workshop_hiryu_class_carrier_job_14/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate
	suit_store = /obj/item/gun/ballistic/shotgun/doublebarrel
	accessory = null
	backpack_contents = list(/obj/item/storage/box/lethalshot = 1)

/datum/outfit/job/workshop_hiryu_class_carrier_job_21
	parent_type = /datum/outfit/job/cook
	name = "Hiryu-class Carrier — Maid"
	uniform = /obj/item/clothing/under/costume/maid
	suit = null
	head = /obj/item/clothing/head/costume/maid_headband
	mask = null
	glasses = null
	shoes = /obj/item/clothing/shoes/laceup
	l_pocket = null
	l_hand = null
	r_hand = null
	accessory = /obj/item/clothing/accessory/maidapron
	backpack_contents = list(/obj/item/knife/combat = 1, /obj/item/sharpener = 1, /obj/item/storage/box/ingredients/carnivore = 3)

/datum/outfit/job/workshop_hiryu_class_carrier_job_21/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/costume/maid
	suit = null
	head = /obj/item/clothing/head/costume/maid_headband
	mask = null
	glasses = null
	shoes = /obj/item/clothing/shoes/laceup
	l_pocket = null
	l_hand = null
	r_hand = null
	accessory = /obj/item/clothing/accessory/maidapron
	backpack_contents = list(/obj/item/knife/combat = 1, /obj/item/sharpener = 1, /obj/item/storage/box/ingredients/carnivore = 3)

/datum/outfit/job/workshop_hiryu_class_carrier_job_9
	parent_type = /datum/outfit/job/cook
	name = "Hiryu-class Carrier — Cook"
	uniform = /obj/item/clothing/under/rank/civilian/cookjorts
	suit = /obj/item/clothing/suit/apron/chef
	head = null
	mask = null
	glasses = /obj/item/clothing/glasses/sunglasses
	shoes = /obj/item/clothing/shoes/cookflops
	l_pocket = null
	l_hand = /obj/item/kitchen/tongs
	r_hand = /obj/item/reagent_containers/cup/soda_cans/beer
	backpack_contents = list(/obj/item/knife/kitchen = 1, /obj/item/sharpener = 1, /obj/item/storage/box/ingredients/carnivore = 3)

/datum/outfit/job/workshop_hiryu_class_carrier_job_9/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/civilian/cookjorts
	suit = /obj/item/clothing/suit/apron/chef
	head = null
	mask = null
	glasses = /obj/item/clothing/glasses/sunglasses
	shoes = /obj/item/clothing/shoes/cookflops
	l_pocket = null
	l_hand = /obj/item/kitchen/tongs
	r_hand = /obj/item/reagent_containers/cup/soda_cans/beer
	backpack_contents = list(/obj/item/knife/kitchen = 1, /obj/item/sharpener = 1, /obj/item/storage/box/ingredients/carnivore = 3)

/datum/outfit/job/workshop_hiryu_class_carrier_job_15
	parent_type = /datum/outfit/job/cook
	name = "Hiryu-class Carrier — Cook"
	uniform = /obj/item/clothing/under/rank/civilian/cookjorts
	suit = /obj/item/clothing/suit/apron/chef
	head = null
	mask = null
	glasses = /obj/item/clothing/glasses/sunglasses
	shoes = /obj/item/clothing/shoes/cookflops
	l_pocket = null
	l_hand = /obj/item/kitchen/tongs
	r_hand = /obj/item/reagent_containers/cup/soda_cans/beer
	backpack_contents = list(/obj/item/knife/kitchen = 1, /obj/item/sharpener = 1, /obj/item/storage/box/ingredients/carnivore = 3)

/datum/outfit/job/workshop_hiryu_class_carrier_job_15/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/civilian/cookjorts
	suit = /obj/item/clothing/suit/apron/chef
	head = null
	mask = null
	glasses = /obj/item/clothing/glasses/sunglasses
	shoes = /obj/item/clothing/shoes/cookflops
	l_pocket = null
	l_hand = /obj/item/kitchen/tongs
	r_hand = /obj/item/reagent_containers/cup/soda_cans/beer
	backpack_contents = list(/obj/item/knife/kitchen = 1, /obj/item/sharpener = 1, /obj/item/storage/box/ingredients/carnivore = 3)

/datum/outfit/job/workshop_hiryu_class_carrier_job_16
	parent_type = /datum/outfit/job/doctor
	name = "Hiryu-class Carrier — Medical Doctor"
	uniform = /obj/item/clothing/under/rank/medical/scrubs/purple
	suit = null
	head = /obj/item/clothing/head/beret/medical
	neck = /obj/item/clothing/neck/scarf/pink

/datum/outfit/job/workshop_hiryu_class_carrier_job_16/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/medical/scrubs/purple
	suit = null
	head = /obj/item/clothing/head/beret/medical
	neck = /obj/item/clothing/neck/scarf/pink

/datum/outfit/job/workshop_hiryu_class_carrier_job_17
	parent_type = /datum/outfit/job/miner
	name = "Hiryu-class Carrier — Mining Exosuit Pilot"
	uniform = /obj/item/clothing/under/costume/mech_suit
	suit = null
	glasses = null
	shoes = /obj/item/clothing/shoes/combat
	belt = /obj/item/storage/belt/utility/full/inducer
	l_pocket = /obj/item/modular_computer/pda/shaftminer
	backpack_contents = list(/obj/item/clothing/head/utility/welding = 1, /obj/item/flashlight/seclite = 1, /obj/item/knife/combat/survival = 1, /obj/item/t_scanner/adv_mining_scanner/lesser = 1, /obj/item/weldingtool/hugetank = 1)

/datum/outfit/job/workshop_hiryu_class_carrier_job_17/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/costume/mech_suit
	suit = null
	glasses = null
	shoes = /obj/item/clothing/shoes/combat
	belt = /obj/item/storage/belt/utility/full/inducer
	l_pocket = /obj/item/modular_computer/pda/shaftminer
	backpack_contents = list(/obj/item/clothing/head/utility/welding = 1, /obj/item/flashlight/seclite = 1, /obj/item/knife/combat/survival = 1, /obj/item/t_scanner/adv_mining_scanner/lesser = 1, /obj/item/weldingtool/hugetank = 1)

/datum/outfit/job/workshop_hiryu_class_carrier_job_7
	parent_type = /datum/outfit/job/miner
	name = "Hiryu-class Carrier — Mining Exosuit Pilot"
	uniform = /obj/item/clothing/under/pants/track
	suit = /obj/item/clothing/suit/hooded/cloak/goliath
	glasses = /obj/item/clothing/glasses/sunglasses/gar/orange
	shoes = /obj/item/clothing/shoes/sandal
	belt = /obj/item/storage/belt/utility/full/inducer
	l_pocket = /obj/item/modular_computer/pda/shaftminer
	backpack_contents = list(/obj/item/clothing/head/utility/welding = 1, /obj/item/flashlight/seclite = 1, /obj/item/knife/combat/survival = 1, /obj/item/t_scanner/adv_mining_scanner/lesser = 1, /obj/item/weldingtool/hugetank = 1)

/datum/outfit/job/workshop_hiryu_class_carrier_job_7/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/pants/track
	suit = /obj/item/clothing/suit/hooded/cloak/goliath
	glasses = /obj/item/clothing/glasses/sunglasses/gar/orange
	shoes = /obj/item/clothing/shoes/sandal
	belt = /obj/item/storage/belt/utility/full/inducer
	l_pocket = /obj/item/modular_computer/pda/shaftminer
	backpack_contents = list(/obj/item/clothing/head/utility/welding = 1, /obj/item/flashlight/seclite = 1, /obj/item/knife/combat/survival = 1, /obj/item/t_scanner/adv_mining_scanner/lesser = 1, /obj/item/weldingtool/hugetank = 1)

/datum/outfit/job/workshop_hiryu_class_carrier_job_3
	parent_type = /datum/outfit/job/miner
	name = "Hiryu-class Carrier — Mining Exosuit Pilot"
	uniform = /obj/item/clothing/under/pants/track
	suit = /obj/item/clothing/suit/hooded/cloak/goliath
	glasses = /obj/item/clothing/glasses/sunglasses/gar/orange
	shoes = /obj/item/clothing/shoes/sandal
	belt = /obj/item/storage/belt/utility/full/inducer
	l_pocket = /obj/item/modular_computer/pda/shaftminer
	backpack_contents = list(/obj/item/clothing/head/utility/welding = 1, /obj/item/flashlight/seclite = 1, /obj/item/knife/combat/survival = 1, /obj/item/t_scanner/adv_mining_scanner/lesser = 1, /obj/item/weldingtool/hugetank = 1)

/datum/outfit/job/workshop_hiryu_class_carrier_job_3/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/pants/track
	suit = /obj/item/clothing/suit/hooded/cloak/goliath
	glasses = /obj/item/clothing/glasses/sunglasses/gar/orange
	shoes = /obj/item/clothing/shoes/sandal
	belt = /obj/item/storage/belt/utility/full/inducer
	l_pocket = /obj/item/modular_computer/pda/shaftminer
	backpack_contents = list(/obj/item/clothing/head/utility/welding = 1, /obj/item/flashlight/seclite = 1, /obj/item/knife/combat/survival = 1, /obj/item/t_scanner/adv_mining_scanner/lesser = 1, /obj/item/weldingtool/hugetank = 1)

/datum/outfit/job/workshop_hiryu_class_carrier_job_19
	parent_type = /datum/outfit/job/roboticist
	name = "Hiryu-class Carrier — Roboticist"
	suit = /obj/item/clothing/suit/jacket/leather_trenchcoat
	head = /obj/item/clothing/head/beret/science
	neck = /obj/item/clothing/neck/scarf/pink

/datum/outfit/job/workshop_hiryu_class_carrier_job_19/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	suit = /obj/item/clothing/suit/jacket/leather_trenchcoat
	head = /obj/item/clothing/head/beret/science
	neck = /obj/item/clothing/neck/scarf/pink

/datum/outfit/job/workshop_hiryu_class_carrier_job_13
	parent_type = /datum/outfit/job/roboticist
	name = "Hiryu-class Carrier — Roboticist"
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/jacket/leather_trenchcoat

/datum/outfit/job/workshop_hiryu_class_carrier_job_13/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/jacket/leather_trenchcoat

/datum/outfit/job/workshop_hiryu_class_carrier_job_18
	parent_type = /datum/outfit/job/security
	name = "Hiryu-class Carrier — Combat Exosuit Pilot"
	uniform = /obj/item/clothing/under/costume/mech_suit
	suit = /obj/item/clothing/suit/hooded/wintercoat/security
	head = /obj/item/clothing/head/beret/sec
	glasses = null
	neck = null
	belt = /obj/item/storage/belt/utility/full/inducer
	r_pocket = /obj/item/modular_computer/pda/security
	l_hand = null
	accessory = /obj/item/clothing/accessory/medal/silver/security
	backpack_contents = list(/obj/item/clothing/head/utility/welding = 1, /obj/item/weldingtool/hugetank = 1)

/datum/outfit/job/workshop_hiryu_class_carrier_job_18/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/costume/mech_suit
	suit = /obj/item/clothing/suit/hooded/wintercoat/security
	head = /obj/item/clothing/head/beret/sec
	glasses = null
	neck = null
	belt = /obj/item/storage/belt/utility/full/inducer
	r_pocket = /obj/item/modular_computer/pda/security
	l_hand = null
	accessory = /obj/item/clothing/accessory/medal/silver/security
	backpack_contents = list(/obj/item/clothing/head/utility/welding = 1, /obj/item/weldingtool/hugetank = 1)

/datum/outfit/job/workshop_hiryu_class_carrier_job_8
	parent_type = /datum/outfit/job/security
	name = "Hiryu-class Carrier — Combat Exosuit Pilot"
	uniform = /obj/item/clothing/under/rank/security/officer/grey
	suit = /obj/item/clothing/suit/hooded/wintercoat/security
	head = /obj/item/clothing/head/beret/sec
	glasses = /obj/item/clothing/glasses/hud/security/sunglasses/gars
	neck = null
	belt = /obj/item/storage/belt/utility/full/inducer
	r_pocket = /obj/item/modular_computer/pda/security
	l_hand = null
	accessory = /obj/item/clothing/accessory/medal/silver/security
	backpack_contents = list(/obj/item/clothing/head/utility/welding = 1, /obj/item/weldingtool/hugetank = 1)

/datum/outfit/job/workshop_hiryu_class_carrier_job_8/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/security/officer/grey
	suit = /obj/item/clothing/suit/hooded/wintercoat/security
	head = /obj/item/clothing/head/beret/sec
	glasses = /obj/item/clothing/glasses/hud/security/sunglasses/gars
	neck = null
	belt = /obj/item/storage/belt/utility/full/inducer
	r_pocket = /obj/item/modular_computer/pda/security
	l_hand = null
	accessory = /obj/item/clothing/accessory/medal/silver/security
	backpack_contents = list(/obj/item/clothing/head/utility/welding = 1, /obj/item/weldingtool/hugetank = 1)

/datum/outfit/job/workshop_hiryu_class_carrier_job_5
	parent_type = /datum/outfit/job/security
	name = "Hiryu-class Carrier — Combat Exosuit Pilot"
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/armor/hos/trenchcoat
	head = /obj/item/clothing/head/hats/hos/beret/syndicate
	glasses = /obj/item/clothing/glasses/hud/security/sunglasses/gars
	neck = null
	gloves = /obj/item/clothing/gloves/combat
	shoes = /obj/item/clothing/shoes/combat
	belt = /obj/item/storage/belt/utility/full/inducer
	r_pocket = /obj/item/modular_computer/pda/security
	l_hand = null
	accessory = /obj/item/clothing/accessory/medal/silver/security
	backpack_contents = list(/obj/item/clothing/head/utility/welding = 1, /obj/item/weldingtool/hugetank = 1)

/datum/outfit/job/workshop_hiryu_class_carrier_job_5/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/armor/hos/trenchcoat
	head = /obj/item/clothing/head/hats/hos/beret/syndicate
	glasses = /obj/item/clothing/glasses/hud/security/sunglasses/gars
	neck = null
	gloves = /obj/item/clothing/gloves/combat
	shoes = /obj/item/clothing/shoes/combat
	belt = /obj/item/storage/belt/utility/full/inducer
	r_pocket = /obj/item/modular_computer/pda/security
	l_hand = null
	accessory = /obj/item/clothing/accessory/medal/silver/security
	backpack_contents = list(/obj/item/clothing/head/utility/welding = 1, /obj/item/weldingtool/hugetank = 1)

/datum/outfit/job/workshop_hiryu_class_carrier_job_28
	parent_type = /datum/outfit/job/captain
	name = "Hiryu-class Carrier — Captain"
	uniform = /obj/item/clothing/under/suit/black_really
	suit = /obj/item/clothing/suit/armor/vest
	head = /obj/item/clothing/head/caphat/beret
	neck = /obj/item/clothing/neck/scarf/pink
	back = /obj/item/storage/backpack/captain

/datum/outfit/job/workshop_hiryu_class_carrier_job_28/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/suit/black_really
	suit = /obj/item/clothing/suit/armor/vest
	head = /obj/item/clothing/head/caphat/beret
	neck = /obj/item/clothing/neck/scarf/pink
	back = /obj/item/storage/backpack/captain

/datum/outfit/job/workshop_hiryu_class_carrier_job_29
	parent_type = /datum/outfit/job/engineer
	name = "Hiryu-class Carrier — Ship Engineer"
	uniform = /obj/item/clothing/under/rank/engineering/engineer/hazard
	suit = /obj/item/clothing/suit/hooded/wintercoat/engineering
	head = /obj/item/clothing/head/beret/engi
	glasses = /obj/item/clothing/glasses/welding/up
	neck = /obj/item/clothing/neck/scarf/pink

/datum/outfit/job/workshop_hiryu_class_carrier_job_29/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/engineering/engineer/hazard
	suit = /obj/item/clothing/suit/hooded/wintercoat/engineering
	head = /obj/item/clothing/head/beret/engi
	glasses = /obj/item/clothing/glasses/welding/up
	neck = /obj/item/clothing/neck/scarf/pink

/datum/outfit/job/workshop_hiryu_class_carrier_job_30
	parent_type = /datum/outfit/job/assistant
	name = "Hiryu-class Carrier — Deckhand"
	uniform = /obj/item/clothing/under/costume/seifuku
	head = null
	glasses = null
	neck = null
	shoes = /obj/item/clothing/shoes/laceup

/datum/outfit/job/workshop_hiryu_class_carrier_job_30/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/costume/seifuku
	head = null
	glasses = null
	neck = null
	shoes = /obj/item/clothing/shoes/laceup

/datum/outfit/job/workshop_hiryu_class_carrier_job_25
	parent_type = /datum/outfit/job/captain/syndicate
	name = "Hiryu-class Carrier — Captain"
	suit_store = null
	l_pocket = null
	r_pocket = null

/datum/outfit/job/workshop_hiryu_class_carrier_job_25/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	suit_store = null
	l_pocket = null
	r_pocket = null

/datum/outfit/job/workshop_hiryu_class_carrier_job_27
	parent_type = /datum/outfit/job/assistant/syndicate
	name = "Hiryu-class Carrier — Deckhand"
	uniform = /obj/item/clothing/under/syndicate
	suit = null
	glasses = null
	back = null
	belt = null
	suit_store = null

/datum/outfit/job/workshop_hiryu_class_carrier_job_27/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate
	suit = null
	glasses = null
	back = null
	belt = null
	suit_store = null
