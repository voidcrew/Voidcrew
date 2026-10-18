/datum/design/survey_data_disk
	name = "Survey data storage disk"
	desc = "A disk for celestial survey records."
	id = "survey_data_disk"
	build_type = PROTOLATHE
	materials = list(/datum/material/iron =SMALL_MATERIAL_AMOUNT * 3, /datum/material/glass =SMALL_MATERIAL_AMOUNT)
	build_path = /obj/item/disk/survey_data_disk
	category = list(
		RND_CATEGORY_COMPUTER + RND_SUBCATEGORY_COMPUTER_RESEARCH,
	)

// Allows you to build the survey console
/datum/design/board/survey_console
	name = "Orbital survey console board"
	desc = "The circuit board for the orbital survey console."
	id = "survey_console_board"
	build_path = /obj/item/circuitboard/computer/survey_shuttle_docker
	category = list(
		RND_CATEGORY_COMPUTER + RND_SUBCATEGORY_COMPUTER_RESEARCH
	)

// Allows shuttle docking
/datum/design/survey_ship_docking
	name = "Orbital survey mapping"
	desc = "Orbital cartography software."
	id = "survey_ship_docking"
	research_icon = 'voidcrew/icons/effects/overmap.dmi'
	research_icon_state = "globe"

// Sight capabilities - Can we view mobs, objects, turfs, etc
/datum/design/survey_map_obj_sight
	name = "Survey mapping upgrade - Visible objects"
	desc = "Surface imaging software."
	id = "survey_map_obj_sight"
	research_icon = 'voidcrew/icons/effects/overmap.dmi'
	research_icon_state = "globe"

/datum/design/survey_map_mob_sight
	name = "Survey mapping upgrade - Visible lifeforms"
	desc = "Biosignature imaging software."
	id = "survey_map_mob_sight"
	research_icon = 'voidcrew/icons/effects/overmap.dmi'
	research_icon_state = "globe"

/datum/design/survey_map_range_upg_superior
	name = "Survey mapping upgrade - Superior view range"
	desc = "Wide-field cartography software."
	id = "survey_map_range_upg_superior"
	research_icon = 'voidcrew/icons/effects/overmap.dmi'
	research_icon_state = "globe"

/datum/design/survey_map_range_upg_elite
	name = "Survey mapping upgrade - Elite view range"
	desc = "Panoramic cartography software."
	id = "survey_map_range_upg_elite"
	research_icon = 'voidcrew/icons/effects/overmap.dmi'
	research_icon_state = "globe"

// Rewards upgrades
/datum/design/survey_console_rewards_upgrade_basic
	name = "Survey basic rewards"
	desc = "Standard survey analysis software."
	id = "survey_console_rewards_upgrade_basic"
	research_icon = 'icons/obj/economy.dmi'
	research_icon_state = "spacecash1"

/datum/design/survey_console_rewards_upgrade_advanced
	name = "Survey rewards advanced upgrade"
	desc = "Refined survey analysis software."
	id = "survey_console_rewards_upgrade_advanced"
	research_icon = 'icons/obj/economy.dmi'
	research_icon_state = "spacecash1_2"

/datum/design/survey_console_rewards_upgrade_superior
	name = "Survey rewards superior upgrade"
	desc = "Precision survey analysis software."
	id = "survey_console_rewards_upgrade_superior"
	research_icon = 'icons/obj/economy.dmi'
	research_icon_state = "spacecash1_3"

/datum/design/survey_console_rewards_upgrade_elite
	name = "Survey rewards elite upgrade"
	desc = "Advanced survey analysis software."
	id = "survey_console_rewards_upgrade_elite"
	research_icon = 'icons/obj/economy.dmi'
	research_icon_state = "spacecash1_4"

// Information upgrades
/datum/design/survey_console_information_upgrade_basic
	name = "Survey basic information upgrade"
	desc = "Planetary cataloguing software."
	id = "survey_console_information_upgrade_basic"
	research_icon = 'icons/obj/service/bureaucracy.dmi'
	research_icon_state = "paperslip_words"

/datum/design/survey_console_information_upgrade_advanced
	name = "Survey advanced information upgrade"
	desc = "Planetary hazard analysis software."
	id = "survey_console_information_upgrade_advanced"
	research_icon = 'icons/obj/service/bureaucracy.dmi'
	research_icon_state = "paper_stack_words"

/datum/design/survey_console_information_upgrade_superior
	name = "Survey superior information upgrade"
	desc = "Planetary biosignature analysis software."
	id = "survey_console_information_upgrade_superior"
	research_icon = 'icons/obj/service/bureaucracy.dmi'
	research_icon_state = "docs_part"

/datum/design/survey_console_information_upgrade_elite
	name = "Survey elite information upgrade"
	desc = "Comprehensive planetary analysis software."
	id = "survey_console_information_upgrade_elite"
	research_icon = 'icons/obj/service/bureaucracy.dmi'
	research_icon_state = "docs_red"
