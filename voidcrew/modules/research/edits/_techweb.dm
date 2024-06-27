/datum/techweb
	///Amount of people connected to the Techweb's neural network, which it uses to generate points better.
	var/neural_network_count = 0
	///List of everything connected to this techweb via Multitool, used for R&D server deconstruction.
	var/list/connected_machines = list()
	/// Research data collected from a survey console. Used to restrict tech behind surveys
	var/datum/survey_research/survey_data

/datum/techweb/Destroy()
	survey_data = null
	return ..()

/datum/techweb/proc/have_surveys_for_node(datum/techweb_node/node)
	. = TRUE
	if(node.required_surveyed_objects)
		for(var/object in node.required_surveyed_objects)
			if(length(survey_data.survey_objects_by_type[object]) < node.required_surveyed_objects[object])
				return FALSE
	return

/datum/techweb/can_unlock_node(datum/techweb_node/node)
	return can_afford(node.get_price(src)) && have_experiments_for_node(node) && have_surveys_for_node(node)
