/datum/nanite_extra_setting/text
	setting_type = NESTYPE_TEXT

/datum/nanite_extra_setting/text/New(initial)
	value = initial

/datum/nanite_extra_setting/text/set_value(value)
	if(!istext(value))
		return
	// Programs print this into their host's chat, so no tags.
	src.value = trim(STRIP_HTML_SIMPLE(value, MAX_MESSAGE_LEN))

/datum/nanite_extra_setting/text/get_copy()
	return new /datum/nanite_extra_setting/text(value)

/datum/nanite_extra_setting/text/get_frontend_list(name)
	return list(list(
		"name" = name,
		"type" = setting_type,
		"value" = value
	))
