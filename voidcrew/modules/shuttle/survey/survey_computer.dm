/obj/machinery/computer/survey
	name = "Planetary survey computer"
	icon_screen = "docking"
	icon_keyboard = "rd_key"
	light_color = LIGHT_COLOR_PURPLE
	icon = 'voidcrew/modules/shuttle/icons/computer.dmi'
	circuit = /obj/item/circuitboard/computer/survey
	var/object_type
	var/hostility
	var/info_level
	var/weather
	var/mob_types
	var/atmos_type
	var/visited
	var/megafauna
	var/player_list
	var/object_loaded
	var/survey_status

/obj/item/circuitboard/computer/survey
	name = "Survey computer board"
	build_path = /obj/machinery/computer/survey

/obj/machinery/computer/survey/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "SurveyComputer", name)
		ui.open()

/obj/machinery/computer/survey/ui_data(mob/user)
  var/list/data = list()
  data["type"] = object_type // The type of overmap object we're surveying
  data["loaded"] = object_loaded
  data["hostilityLevel"] = hostility /* Tranquil, cautious, hazardous, lethal */
  data["infoLevel"] = info_level
  data["weather"] = weather
  data["mobTypes"] = mob_types
  data["atmosType"] = atmos_type
  data["visited"] = visited
  data["megafauna"] = megafauna
  data["playerList"] = player_list
  data["surveyStatus"] = survey_status
  return data

/obj/machinery/computer/survey/ui_act(action, params)
	. = ..()
	if(.)
		return
