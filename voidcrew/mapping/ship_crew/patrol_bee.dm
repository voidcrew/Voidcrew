// Ship Workshop crew outfits. Edit these through the crew editor.

/datum/outfit/job/workshop_patrol_bee_job_16
	parent_type = /datum/outfit/job/bitrunner
	name = "Patrol Bee — Bitrunner"
	uniform = /obj/item/clothing/under/syndicate/sniper
	id = /obj/item/card/id/advanced/black/syndicate_command

/datum/outfit/job/workshop_patrol_bee_job_16/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate/sniper
	id = /obj/item/card/id/advanced/black/syndicate_command

/datum/outfit/job/workshop_patrol_bee_job_5
	parent_type = /datum/outfit/job/cargo_tech
	name = "Patrol Bee — Cargo Mechanic"
	uniform = /obj/item/clothing/under/rank/engineering/engineer/hazard
	suit = /obj/item/clothing/suit/apron/overalls
	head = /obj/item/clothing/head/utility/hardhat/welding/orange
	gloves = /obj/item/clothing/gloves/color/fyellow/old
	belt = /obj/item/storage/belt/utility
	r_pocket = /obj/item/modular_computer/pda/cargo

/datum/outfit/job/workshop_patrol_bee_job_5/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/engineering/engineer/hazard
	suit = /obj/item/clothing/suit/apron/overalls
	head = /obj/item/clothing/head/utility/hardhat/welding/orange
	gloves = /obj/item/clothing/gloves/color/fyellow/old
	belt = /obj/item/storage/belt/utility
	r_pocket = /obj/item/modular_computer/pda/cargo

/datum/outfit/job/workshop_patrol_bee_job_29
	parent_type = /datum/outfit/job/cargo_tech
	name = "Patrol Bee — Cargo Mechanic"
	uniform = /obj/item/clothing/under/rank/engineering/engineer/hazard
	suit = /obj/item/clothing/suit/apron/overalls
	head = /obj/item/clothing/head/utility/hardhat/welding/orange
	gloves = /obj/item/clothing/gloves/color/fyellow/old
	belt = /obj/item/storage/belt/utility
	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id
	r_pocket = /obj/item/modular_computer/pda/cargo

/datum/outfit/job/workshop_patrol_bee_job_29/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/engineering/engineer/hazard
	suit = /obj/item/clothing/suit/apron/overalls
	head = /obj/item/clothing/head/utility/hardhat/welding/orange
	gloves = /obj/item/clothing/gloves/color/fyellow/old
	belt = /obj/item/storage/belt/utility
	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id
	r_pocket = /obj/item/modular_computer/pda/cargo

/datum/outfit/job/workshop_patrol_bee_job_6
	parent_type = /datum/outfit/job/doctor
	name = "Patrol Bee — Surgeon"
	suit = /obj/item/clothing/suit/apron/surgical
	head = /obj/item/clothing/head/utility/surgerycap
	mask = /obj/item/clothing/mask/surgical
	gloves = /obj/item/clothing/gloves/latex/nitrile

/datum/outfit/job/workshop_patrol_bee_job_6/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	suit = /obj/item/clothing/suit/apron/surgical
	head = /obj/item/clothing/head/utility/surgerycap
	mask = /obj/item/clothing/mask/surgical
	gloves = /obj/item/clothing/gloves/latex/nitrile

/datum/outfit/job/workshop_patrol_bee_job_18
	parent_type = /datum/outfit/job/doctor/interdyne
	name = "Patrol Bee — Surgeon"
	suit = /obj/item/clothing/suit/apron/surgical
	mask = /obj/item/clothing/mask/surgical
	gloves = /obj/item/clothing/gloves/latex/coroner
	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id

/datum/outfit/job/workshop_patrol_bee_job_18/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	suit = /obj/item/clothing/suit/apron/surgical
	mask = /obj/item/clothing/mask/surgical
	gloves = /obj/item/clothing/gloves/latex/coroner
	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id

/datum/outfit/job/workshop_patrol_bee_job_11
	parent_type = /datum/outfit/job/hop
	name = "Patrol Bee — Head of Personnel"
	backpack_contents = list(/obj/item/plant_analyzer = 1, /obj/item/sharpener = 1)

/datum/outfit/job/workshop_patrol_bee_job_11/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	backpack_contents = list(/obj/item/plant_analyzer = 1, /obj/item/sharpener = 1)

/datum/outfit/job/workshop_patrol_bee_job_23
	parent_type = /datum/outfit/job/hop
	name = "Patrol Bee — Head of Personnel"
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/armor/vest/marine
	head = /obj/item/clothing/head/hats/hos/cap/syndicate
	id = /obj/item/card/id/advanced/black/syndicate_command
	backpack_contents = list(/obj/item/plant_analyzer = 1, /obj/item/sharpener = 1)

/datum/outfit/job/workshop_patrol_bee_job_23/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/armor/vest/marine
	head = /obj/item/clothing/head/hats/hos/cap/syndicate
	id = /obj/item/card/id/advanced/black/syndicate_command
	backpack_contents = list(/obj/item/plant_analyzer = 1, /obj/item/sharpener = 1)

/datum/outfit/job/workshop_patrol_bee_job_15
	parent_type = /datum/outfit/job/miner
	name = "Patrol Bee — Miner"
	uniform = /obj/item/clothing/under/syndicate
	id = /obj/item/card/id/advanced/black/syndicate_command

/datum/outfit/job/workshop_patrol_bee_job_15/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate
	id = /obj/item/card/id/advanced/black/syndicate_command

/datum/outfit/job/workshop_patrol_bee_job_7
	parent_type = /datum/outfit/job/chemist
	name = "Patrol Bee — Chemist"
	backpack_contents = list(/obj/item/clothing/suit/hooded/wintercoat/medical/chemistry = 1)

/datum/outfit/job/workshop_patrol_bee_job_7/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	backpack_contents = list(/obj/item/clothing/suit/hooded/wintercoat/medical/chemistry = 1)

/datum/outfit/job/workshop_patrol_bee_job_19
	parent_type = /datum/outfit/job/chemist
	name = "Patrol Bee — Chemist"
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/toggle/labcoat/interdyne
	back = /obj/item/storage/backpack/coroner
	id = /obj/item/card/id/advanced/black/syndicate_command
	backpack_contents = list(/obj/item/clothing/suit/hooded/wintercoat/medical/chemistry = 1)

/datum/outfit/job/workshop_patrol_bee_job_19/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/toggle/labcoat/interdyne
	back = /obj/item/storage/backpack/coroner
	id = /obj/item/card/id/advanced/black/syndicate_command
	backpack_contents = list(/obj/item/clothing/suit/hooded/wintercoat/medical/chemistry = 1)

/datum/outfit/job/workshop_patrol_bee_job_20
	parent_type = /datum/outfit/job/scientist/consistent
	name = "Patrol Bee — Scientist"
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/toggle/labcoat/interdyne
	id = /obj/item/card/id/advanced/black/syndicate_command

/datum/outfit/job/workshop_patrol_bee_job_20/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/toggle/labcoat/interdyne
	id = /obj/item/card/id/advanced/black/syndicate_command

/datum/outfit/job/workshop_patrol_bee_job_9
	parent_type = /datum/outfit/job/cook
	name = "Patrol Bee — Chef"
	gloves = /obj/item/clothing/gloves/the_sleeping_carp
	backpack_contents = list(/obj/item/choice_beacon/ingredient = 1, /obj/item/knife/butcher = 1, /obj/item/sharpener = 1)

/datum/outfit/job/workshop_patrol_bee_job_9/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	gloves = /obj/item/clothing/gloves/the_sleeping_carp
	backpack_contents = list(/obj/item/choice_beacon/ingredient = 1, /obj/item/knife/butcher = 1, /obj/item/sharpener = 1)

/datum/outfit/job/workshop_patrol_bee_job_21
	parent_type = /datum/outfit/job/cook
	name = "Patrol Bee — Chef"
	gloves = /obj/item/clothing/gloves/the_sleeping_carp
	id = /obj/item/card/id/advanced/black/syndicate_command/captain_id/syndie_spare
	backpack_contents = list(/obj/item/choice_beacon/ingredient = 1, /obj/item/knife/butcher = 1, /obj/item/sharpener = 1)

/datum/outfit/job/workshop_patrol_bee_job_21/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	gloves = /obj/item/clothing/gloves/the_sleeping_carp
	id = /obj/item/card/id/advanced/black/syndicate_command/captain_id/syndie_spare
	backpack_contents = list(/obj/item/choice_beacon/ingredient = 1, /obj/item/knife/butcher = 1, /obj/item/sharpener = 1)

/datum/outfit/job/workshop_patrol_bee_job_1
	parent_type = /datum/outfit/job/hos
	name = "Patrol Bee — Captain"
	id = /obj/item/card/id/advanced/gold
	backpack_contents = list(/obj/item/evidencebag = 1, /obj/item/gun/energy/e_gun/hos = 1, /obj/item/melee/baton/telescopic/gold = 1)

/datum/outfit/job/workshop_patrol_bee_job_1/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	id = /obj/item/card/id/advanced/gold
	backpack_contents = list(/obj/item/evidencebag = 1, /obj/item/gun/energy/e_gun/hos = 1, /obj/item/melee/baton/telescopic/gold = 1)

/datum/outfit/job/workshop_patrol_bee_job_27
	parent_type = /datum/outfit/job/atmos
	name = "Patrol Bee — Atmospheric Technician"
	gloves = /obj/item/clothing/gloves/color/yellow

/datum/outfit/job/workshop_patrol_bee_job_27/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	gloves = /obj/item/clothing/gloves/color/yellow

/datum/outfit/job/workshop_patrol_bee_job_28
	parent_type = /datum/outfit/job/cargo_tech
	name = "Patrol Bee — Cargo Technician"
	head = /obj/item/clothing/head/soft
	gloves = /obj/item/clothing/gloves/cargo_gauntlet

/datum/outfit/job/workshop_patrol_bee_job_28/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	head = /obj/item/clothing/head/soft
	gloves = /obj/item/clothing/gloves/cargo_gauntlet

/datum/outfit/job/workshop_patrol_bee_job_2
	parent_type = /datum/outfit/job/security
	name = "Patrol Bee — Patrolling Officer"
	head = /obj/item/clothing/head/soft/sec

/datum/outfit/job/workshop_patrol_bee_job_2/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	head = /obj/item/clothing/head/soft/sec

/datum/outfit/job/workshop_patrol_bee_job_30
	parent_type = /datum/outfit/job/quartermaster
	name = "Patrol Bee — Quartermaster"
	suit = /obj/item/clothing/suit/hooded/wintercoat/cargo/qm
	head = /obj/item/clothing/head/beret/cargo
	backpack_contents = list()

/datum/outfit/job/workshop_patrol_bee_job_30/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	suit = /obj/item/clothing/suit/hooded/wintercoat/cargo/qm
	head = /obj/item/clothing/head/beret/cargo
	backpack_contents = list()

/datum/outfit/job/workshop_patrol_bee_job_14
	parent_type = /datum/outfit/job/captain/syndicate
	name = "Patrol Bee — Captain"
	l_pocket = null

/datum/outfit/job/workshop_patrol_bee_job_14/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	l_pocket = null

/datum/outfit/job/workshop_patrol_bee_job_12
	parent_type = /datum/outfit/job/engineer/syndicate
	name = "Patrol Bee — Ship Engineer"
	gloves = /obj/item/clothing/gloves/combat

/datum/outfit/job/workshop_patrol_bee_job_12/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	gloves = /obj/item/clothing/gloves/combat

/datum/outfit/job/workshop_patrol_bee_job_13
	parent_type = /datum/outfit/job/atmos/syndicate
	name = "Patrol Bee — Atmospheric Technician"
	gloves = /obj/item/clothing/gloves/combat

/datum/outfit/job/workshop_patrol_bee_job_13/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	gloves = /obj/item/clothing/gloves/combat

/datum/outfit/job/workshop_patrol_bee_job_24
	parent_type = /datum/outfit/job/cargo_tech
	name = "Patrol Bee — Cargo Technician"
	uniform = /obj/item/clothing/under/syndicate
	head = /obj/item/clothing/head/soft
	neck = /obj/item/clothing/neck/large_scarf/syndie
	gloves = /obj/item/clothing/gloves/cargo_gauntlet
	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id

/datum/outfit/job/workshop_patrol_bee_job_24/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate
	head = /obj/item/clothing/head/soft
	neck = /obj/item/clothing/neck/large_scarf/syndie
	gloves = /obj/item/clothing/gloves/cargo_gauntlet
	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id

/datum/outfit/job/workshop_patrol_bee_job_25
	parent_type = /datum/outfit/job/security
	name = "Patrol Bee — Patrolling Officer"
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/armor/bulletproof
	head = /obj/item/clothing/head/hats/hos/beret/syndicate
	ears = /obj/item/radio/headset/syndicate/alt
	gloves = /obj/item/clothing/gloves/color/black/security/blu
	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id

/datum/outfit/job/workshop_patrol_bee_job_25/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/armor/bulletproof
	head = /obj/item/clothing/head/hats/hos/beret/syndicate
	ears = /obj/item/radio/headset/syndicate/alt
	gloves = /obj/item/clothing/gloves/color/black/security/blu
	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id

/datum/outfit/job/workshop_patrol_bee_job_17
	parent_type = /datum/outfit/job/quartermaster
	name = "Patrol Bee — Quartermaster"
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/hooded/wintercoat/cargo/qm
	head = /obj/item/clothing/head/hats/hos/beret/syndicate
	neck = /obj/item/clothing/neck/large_scarf/syndie
	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id
	backpack_contents = list()

/datum/outfit/job/workshop_patrol_bee_job_17/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/hooded/wintercoat/cargo/qm
	head = /obj/item/clothing/head/hats/hos/beret/syndicate
	neck = /obj/item/clothing/neck/large_scarf/syndie
	id = /obj/item/card/id/advanced/black/syndicate_command/crew_id
	backpack_contents = list()
