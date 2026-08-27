/datum/design/survey_data_disk
	name = "Survey data storage disk"
	desc = "Unlocks the survey data storage disk."
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
	build_path = /obj/item/circuitboard/computer/survey_shuttle_docker
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_COMPUTER_RESEARCH
	)

// Allows shuttle docking
/datum/design/survey_ship_docking
	name = "Orbital survey mapping"
	desc = "Upgrades your survey console to allow you to view a map of the planet and control where your ship docks"
	research_icon = 'voidcrew/icons/effects/overmap.dmi'
	research_icon_state = "globe"

// Sight capabilities - Can we view mobs, objects, turfs, etc
/datum/design/survey_map_obj_sight
	name = "Survey mapping upgrade - Visible objects"
	desc = "Upgrades your survey console capabilities to show flora and objects when using the map"
	research_icon = 'voidcrew/icons/effects/overmap.dmi'
	research_icon_state = "globe"

/datum/design/survey_map_mob_sight
	name = "Survey mapping upgrade - Visible lifeforms"
	desc = "Upgrades your survey mapping system to show lifeforms when using the map"
	research_icon = 'voidcrew/icons/effects/overmap.dmi'
	research_icon_state = "globe"

/datum/design/survey_map_range_upg_superior
	name = "Survey mapping upgrade - Superior view range"
	desc = "Upgrades your survey mapping system to have a larger field of view"
	research_icon = 'voidcrew/icons/effects/overmap.dmi'
	research_icon_state = "globe"

/datum/design/survey_map_range_upg_elite
	name = "Survey mapping upgrade - Elite view range"
	desc = "Upgrades your survey mapping system to have a larger field of view"
	research_icon = 'voidcrew/icons/effects/overmap.dmi'
	research_icon_state = "globe"

// Rewards upgrades
/datum/design/survey_console_rewards_upgrade_basic
	name = "Survey basic rewards"
	desc = "Your survey console will produce a small amount of research points and money per survey"
	research_icon = 'icons/obj/economy.dmi'
	research_icon_state = "spacecash1"

/datum/design/survey_console_rewards_upgrade_advanced
	name = "Survey rewards advanced upgrade"
	desc = "Upgrades your survey console to produce more research points and money"
	research_icon = 'icons/obj/economy.dmi'
	research_icon_state = "spacecash1_2"

/datum/design/survey_console_rewards_upgrade_superior
	name = "Survey rewards superior upgrade"
	desc = "Upgrades your survey console to produce a large amount of research points and money"
	research_icon = 'icons/obj/economy.dmi'
	research_icon_state = "spacecash1_3"

/datum/design/survey_console_rewards_upgrade_elite
	name = "Survey rewards elite upgrade"
	desc = "Upgrades your survey console to produce a ton of research points and money"
	research_icon = 'icons/obj/economy.dmi'
	research_icon_state = "spacecash1_4"

// Information upgrades
/datum/design/survey_console_information_upgrade_basic
	name = "Survey basic information upgrade"
	desc = "Grants you basic planetary information about a planet"
	research_icon = 'icons/obj/service/bureaucracy.dmi'
	research_icon_state = "paperslip_words"

/datum/design/survey_console_information_upgrade_advanced
	name = "Survey advanced information upgrade"
	desc = "Grants you access to the hostility level of a planet"
	research_icon = 'icons/obj/service/bureaucracy.dmi'
	research_icon_state = "paper_stack_words"

/datum/design/survey_console_information_upgrade_superior
	name = "Survey superior information upgrade"
	desc = "Grants you information about the life forms and structures found on a planet"
	research_icon = 'icons/obj/service/bureaucracy.dmi'
	research_icon_state = "docs_part"

/datum/design/survey_console_information_upgrade_elite
	name = "Survey elite information upgrade"
	desc = "Grants you even more information about things found on a planet"
	research_icon = 'icons/obj/service/bureaucracy.dmi'
	research_icon_state = "docs_red"
