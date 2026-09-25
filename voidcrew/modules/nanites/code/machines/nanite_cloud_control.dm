/obj/machinery/computer/nanite_cloud_controller
	name = "nanite programmer"
	desc = "Downloads nanite programs from the techweb servers, edits them, and stores and controls nanite cloud backups. Cloud networks are local to the ship this console is aboard: nanites can only join one by having their cloud ID set in a nanite chamber on the same ship, and cloud IDs on other ships are separate networks even if the numbers match."
	icon = 'voidcrew/modules/nanites/icons/research.dmi'
	icon_state = "nanite_cloud_controller"
	circuit = /obj/item/circuitboard/computer/nanite_cloud_controller
	brightness_on = FALSE
	icon_keyboard = null
	icon_screen = null

	var/obj/item/disk/nanite_program/disk
	var/list/datum/nanite_cloud_backup/cloud_backups = list()
	var/current_view = 0 //0 is the main menu, any other number is the page of the backup with that ID
	var/new_backup_id = 1
	var/datum/techweb/linked_techweb
	var/detail_view = TRUE //Whether the program list shows program descriptions
	var/datum/nanite_program/current_program //The program being edited, downloaded from research and uploaded to cloud backups

	COOLDOWN_DECLARE(nanite_programmer)

/obj/machinery/computer/nanite_cloud_controller/Initialize(mapload)
	. = ..()
	become_hearing_sensitive()

/obj/machinery/computer/nanite_cloud_controller/Destroy()
	eject()
	QDEL_NULL(current_program)
	QDEL_LIST(cloud_backups) //rip backups
	unsync_research_servers()
	return ..()

/obj/machinery/computer/nanite_cloud_controller/unsync_research_servers()
	if(linked_techweb)
		linked_techweb.connected_machines -= src
		linked_techweb = null
		if(!QDELETED(src))
			update_static_data_for_all_viewers()

/obj/machinery/computer/nanite_cloud_controller/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(QDELETED(tool.buffer) || !istype(tool.buffer, /datum/techweb))
		return TRUE
	if(!can_link_site_techweb(src, tool.buffer))
		balloon_alert(user, "server belongs to another site")
		return FALSE
	if(linked_techweb == tool.buffer)
		say("Already linked!")
		return TRUE
	unsync_research_servers()
	linked_techweb = tool.buffer
	linked_techweb.connected_machines |= src
	update_static_data_for_all_viewers()
	say("Linked to Server!")
	return TRUE

/obj/machinery/computer/nanite_cloud_controller/attackby(obj/item/I, mob/user)
	if(istype(I, /obj/item/disk/nanite_program))
		var/obj/item/disk/nanite_program/N = I
		if(user.transferItemToLoc(N, src))
			to_chat(user, span_notice("You insert [N] into [src]."))
			playsound(src, 'sound/machines/terminal/terminal_insert_disc.ogg', 50, FALSE)
			if(disk)
				eject(user)
			disk = N
			return
	return ..()

/obj/machinery/computer/nanite_cloud_controller/click_alt(mob/user)
	if(disk && user.can_perform_action(src, ALLOW_SILICON_REACH))
		to_chat(user, span_notice("You take out [disk] from [src]."))
		eject(user)
	return

/obj/machinery/computer/nanite_cloud_controller/proc/eject(mob/living/user)
	if(!disk)
		return
	if(!istype(user) || !Adjacent(user) ||!user.put_in_active_hand(disk))
		disk.forceMove(drop_location())
	disk = null

/obj/machinery/computer/nanite_cloud_controller/proc/get_backup(cloud_id)
	for(var/datum/nanite_cloud_backup/backup as anything in cloud_backups)
		if(backup.cloud_id == cloud_id)
			return backup

/**
 * Resolves a program index the UI sent us against the backup's live program list.
 *
 * The open UI can be seconds out of date - another console deleted the program, or a program was
 * qdel'd out from under it - and indexing a list past its end is a runtime, so refuse the action
 * and tell the user instead of throwing.
 */
/obj/machinery/computer/nanite_cloud_controller/proc/get_ui_program(datum/component/nanites/nanites, program_id, mob/user)
	var/index = text2num(program_id)
	if(isnull(index) || index != round(index) || index < 1 || index > length(nanites?.programs))
		to_chat(user, span_warning("[src] buzzes: that program is no longer in cloud backup #[current_view]."))
		return null
	return nanites.programs[index]

///As get_ui_program, for a rule index inside one program's rule list.
/obj/machinery/computer/nanite_cloud_controller/proc/get_ui_rule(datum/nanite_program/program, rule_id, mob/user)
	var/index = text2num(rule_id)
	if(isnull(index) || index != round(index) || index < 1 || index > length(program?.rules))
		to_chat(user, span_warning("[src] buzzes: that rule is no longer set on [program ? program.name : "that program"]."))
		return null
	return program.rules[index]

/obj/machinery/computer/nanite_cloud_controller/proc/generate_backup(cloud_id, mob/user)
	// Backups work without research; only carry a disk link while it is local.
	validate_research_site(linked_techweb)
	//Clouds are ship-local, so only IDs already used aboard this ship collide.
	//A console that somehow isn't on a ship checks globally, which is just conservative.
	if(SSnanites.get_cloud_backup(cloud_id, TRUE, get_service_site(src)))
		to_chat(user, span_warning("Cloud ID already registered on this ship's network."))
		return

	var/datum/nanite_cloud_backup/backup = new(src)
	var/datum/component/nanites/cloud_copy = backup.AddComponent(/datum/component/nanites, linked_techweb)
	backup.cloud_id = cloud_id
	backup.nanites = cloud_copy
	log_game("[key_name(user)] created a new nanite cloud backup with id #[cloud_id]")

/obj/machinery/computer/nanite_cloud_controller/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "NaniteCloudControl", name)
		ui.open()

/obj/machinery/computer/nanite_cloud_controller/ui_data()
	var/list/data = list()
	data["has_techweb"] = validate_research_site(linked_techweb)
	data["has_disk"] = istype(disk)
	data["has_program"] = istype(current_program)
	if(current_program)
		data["name"] = current_program.name
		data["desc"] = current_program.desc
		data["use_rate"] = current_program.use_rate
		data["can_trigger"] = current_program.can_trigger
		data["trigger_cost"] = current_program.trigger_cost
		data["trigger_cooldown"] = current_program.trigger_cooldown / 10

		data["activated"] = current_program.activated
		data["activation_code"] = current_program.activation_code
		data["deactivation_code"] = current_program.deactivation_code
		data["kill_code"] = current_program.kill_code
		data["trigger_code"] = current_program.trigger_code
		data["timer_restart"] = current_program.timer_restart / 10
		data["timer_shutdown"] = current_program.timer_shutdown / 10
		data["timer_trigger"] = current_program.timer_trigger / 10
		data["timer_trigger_delay"] = current_program.timer_trigger_delay / 10

		var/list/extra_settings = current_program.get_extra_settings_frontend()
		data["extra_settings"] = extra_settings
		if(LAZYLEN(extra_settings))
			data["has_extra_settings"] = TRUE
		if(istype(current_program, /datum/nanite_program/sensor))
			var/datum/nanite_program/sensor/sensor = current_program
			if(sensor.can_rule)
				data["can_rule"] = TRUE

	data["detail_view"] = detail_view

	data["new_backup_id"] = new_backup_id

	var/obj/structure/overmap/ship/host_ship = get_service_site(src)
	data["ship_name"] = host_ship ? host_ship.name : null

	data["current_view"] = current_view
	if(current_view)
		var/datum/nanite_cloud_backup/backup = get_backup(current_view)
		if(backup)
			var/datum/component/nanites/nanites = backup.nanites
			data["cloud_backup"] = TRUE
			var/list/cloud_programs = list()
			var/id = 1
			for(var/datum/nanite_program/P in nanites.programs)
				var/list/cloud_program = list()
				cloud_program["name"] = P.name
				cloud_program["desc"] = P.desc
				cloud_program["id"] = id
				cloud_program["use_rate"] = P.use_rate
				cloud_program["can_trigger"] = P.can_trigger
				cloud_program["trigger_cost"] = P.trigger_cost
				cloud_program["trigger_cooldown"] = P.trigger_cooldown / 10
				cloud_program["activated"] = P.activated
				cloud_program["timer_restart"] = P.timer_restart / 10
				cloud_program["timer_shutdown"] = P.timer_shutdown / 10
				cloud_program["timer_trigger"] = P.timer_trigger / 10
				cloud_program["timer_trigger_delay"] = P.timer_trigger_delay / 10

				cloud_program["activation_code"] = P.activation_code
				cloud_program["deactivation_code"] = P.deactivation_code
				cloud_program["kill_code"] = P.kill_code
				cloud_program["trigger_code"] = P.trigger_code
				var/list/rules = list()
				var/rule_id = 1
				for(var/X in P.rules)
					var/datum/nanite_rule/nanite_rule = X
					var/list/rule = list()
					rule["display"] = nanite_rule.display()
					rule["program_id"] = id
					rule["id"] = rule_id
					rules += list(rule)
					rule_id++
				cloud_program["rules"] = rules
				if(LAZYLEN(rules))
					cloud_program["has_rules"] = TRUE
				cloud_program["all_rules_required"] = P.all_rules_required

				var/list/extra_settings = P.get_extra_settings_frontend()
				cloud_program["extra_settings"] = extra_settings
				if(LAZYLEN(extra_settings))
					cloud_program["has_extra_settings"] = TRUE
				id++
				cloud_programs += list(cloud_program)
			data["cloud_programs"] = cloud_programs
	else
		var/list/backup_list = list()
		for(var/datum/nanite_cloud_backup/backup as anything in cloud_backups)
			var/list/cloud_backup = list()
			cloud_backup["cloud_id"] = backup.cloud_id
			backup_list += list(cloud_backup)
		data["cloud_backups"] = backup_list
	return data

/obj/machinery/computer/nanite_cloud_controller/ui_static_data(mob/user)
	var/list/data = list()
	if(!validate_research_site(linked_techweb))
		data["programs"] = null
		return data

	data["programs"] = list()
	for(var/i in linked_techweb.researched_designs)
		var/datum/design/nanites/D = SSresearch.techweb_design_by_id(i)
		if(!(D.build_type & NANITE_PROGRAM))
			continue
		var/cat_name = D.category[1] //just put them in the first category fuck it
		if(isnull(data["programs"][cat_name]))
			data["programs"][cat_name] = list()
		var/list/program_design = list()
		program_design["id"] = D.id
		program_design["name"] = D.name
		program_design["desc"] = D.desc
		data["programs"][cat_name] += list(program_design)

	if(!length(data["programs"]))
		data["programs"] = null

	return data

/obj/machinery/computer/nanite_cloud_controller/ui_act(action, params)
	. = ..()
	if(.)
		return
	switch(action)
		if("eject")
			eject(usr)
			. = TRUE
		if("set_view")
			current_view = text2num(params["view"])
			. = TRUE
		if("update_new_backup_value")
			var/backup_value = text2num(params["value"])
			if(isnull(backup_value)) //a null would get sent straight back to the UI's NumberInput, which can't render it
				return TRUE
			new_backup_id = clamp(round(backup_value, 1), 1, 100)
			. = TRUE
		if("create_backup")
			var/cloud_id = new_backup_id
			if(!isnull(cloud_id))
				playsound(src, 'sound/machines/terminal/terminal_prompt.ogg', 50, FALSE)
				cloud_id = clamp(round(cloud_id, 1),1,100)
				generate_backup(cloud_id, usr)
			. = TRUE
		if("delete_backup")
			var/datum/nanite_cloud_backup/backup = get_backup(current_view)
			if(backup)
				playsound(src, 'sound/machines/terminal/terminal_prompt.ogg', 50, FALSE)
				qdel(backup)
				log_game("[key_name(usr)] deleted the nanite cloud backup #[current_view]")
			. = TRUE
		if("upload_program")
			if(current_program)
				var/datum/nanite_cloud_backup/backup = get_backup(current_view)
				if(backup)
					playsound(src, 'sound/machines/terminal/terminal_prompt.ogg', 50, FALSE)
					var/datum/component/nanites/nanites = backup.nanites
					nanites.add_program(null, current_program.copy())
					log_game("[key_name(usr)] uploaded program [current_program.name] to cloud #[current_view]")
			. = TRUE
		if("remove_program")
			var/datum/nanite_cloud_backup/backup = get_backup(current_view)
			if(backup)
				playsound(src, 'sound/machines/terminal/terminal_prompt.ogg', 50, FALSE)
				var/datum/component/nanites/nanites = backup.nanites
				var/datum/nanite_program/P = get_ui_program(nanites, params["program_id"], usr)
				if(!P)
					return TRUE
				log_game("[key_name(usr)] deleted program [P.name] from cloud #[current_view]")
				qdel(P)
			. = TRUE
		if("add_rule")
			if(istype(current_program, /datum/nanite_program/sensor))
				var/datum/nanite_program/sensor/rule_template = current_program
				if(!rule_template.can_rule)
					return
				var/datum/nanite_cloud_backup/backup = get_backup(current_view)
				if(backup)
					playsound(src, 'sound/machines/terminal/terminal_prompt.ogg', 50, 0)
					var/datum/component/nanites/nanites = backup.nanites
					var/datum/nanite_program/P = get_ui_program(nanites, params["program_id"], usr)
					if(!P)
						return TRUE
					var/datum/nanite_rule/rule = rule_template.make_rule(P)

					log_game("[key_name(usr)] added rule [rule.display()] to program [P.name] in cloud #[current_view]")
			. = TRUE
		if("remove_rule")
			var/datum/nanite_cloud_backup/backup = get_backup(current_view)
			if(backup)
				playsound(src, 'sound/machines/terminal/terminal_prompt.ogg', 50, 0)
				var/datum/component/nanites/nanites = backup.nanites
				var/datum/nanite_program/P = get_ui_program(nanites, params["program_id"], usr)
				if(!P)
					return TRUE
				var/datum/nanite_rule/rule = get_ui_rule(P, params["rule_id"], usr)
				if(!rule)
					return TRUE
				rule.remove()

				log_game("[key_name(usr)] removed rule [rule.display()] from program [P.name] in cloud #[current_view]")
			. = TRUE
		if("toggle_rule_logic")
			var/datum/nanite_cloud_backup/backup = get_backup(current_view)
			if(backup)
				playsound(src, 'sound/machines/terminal/terminal_prompt.ogg', 50, FALSE)
				var/datum/component/nanites/nanites = backup.nanites
				var/datum/nanite_program/P = get_ui_program(nanites, params["program_id"], usr)
				if(!P)
					return TRUE
				P.all_rules_required = !P.all_rules_required
				log_game("[key_name(usr)] edited rule logic for program [P.name] into [P.all_rules_required ? "All" : "Any"] in cloud #[current_view]")
				. = TRUE
		if("store_backup")
			if(disk)
				var/datum/nanite_cloud_backup/backup = get_backup(current_view)
				if(backup)
					playsound(src, 'sound/machines/terminal/terminal_prompt.ogg', 25, FALSE)
					QDEL_LIST(disk.backup)
					var/datum/component/nanites/nanites = backup.nanites
					for(var/datum/nanite_program/program as anything in nanites.programs)
						disk.backup += program.copy()
			. = TRUE
		if("load_backup")
			if(disk)
				var/datum/nanite_cloud_backup/backup = get_backup(current_view)
				if(backup)
					playsound(src, 'sound/machines/terminal/terminal_prompt.ogg', 25, FALSE)
					var/datum/component/nanites/nanites = backup.nanites
					QDEL_LIST(nanites.programs)
					for(var/datum/nanite_program/program as anything in disk.backup)
						nanites.add_program(null, program.copy())
					log_game("[key_name(usr)] loaded a disk backup into cloud #[current_view]")
			. = TRUE
		if("download")
			if(!validate_research_site(linked_techweb))
				return
			var/datum/design/nanites/downloaded = linked_techweb.isDesignResearchedID(params["program_id"]) //check if it's a valid design
			if(!istype(downloaded))
				return
			if(current_program)
				qdel(current_program)
			current_program = new downloaded.program_type
			playsound(src, 'sound/machines/terminal/terminal_prompt.ogg', 25, FALSE)
			. = TRUE
		if("refresh")
			update_static_data(usr)
			. = TRUE
		if("toggle_details")
			detail_view = !detail_view
			. = TRUE
		else
			if(isnull(params["program_id"]))
				if(current_program)
					return edit_program(current_program, action, params)
				return
			//Inline edits of a program stored in the open cloud backup
			var/datum/nanite_cloud_backup/backup = get_backup(current_view)
			if(!backup)
				return
			var/datum/nanite_program/P = get_ui_program(backup.nanites, params["program_id"], usr)
			if(P && edit_program(P, action, params))
				log_game("[key_name(usr)] edited program [P.name] in cloud #[current_view] ([action]: [json_encode(params)])")
				return TRUE

///Handles the UI actions that edit the settings of a program, either the current program or one stored in a cloud backup.
/obj/machinery/computer/nanite_cloud_controller/proc/edit_program(datum/nanite_program/program, action, params)
	switch(action)
		if("toggle_active")
			playsound(src, "terminal_type", 25, FALSE)
			program.activated = !program.activated //we don't use the activation procs since we aren't in a mob
			. = TRUE
		if("set_code")
			var/new_code = text2num(params["code"])
			playsound(src, "terminal_type", 25, FALSE)
			var/target_code = params["target_code"]
			switch(target_code)
				if("activation")
					program.activation_code = clamp(round(new_code, 1),0,9999)
				if("deactivation")
					program.deactivation_code = clamp(round(new_code, 1),0,9999)
				if("kill")
					program.kill_code = clamp(round(new_code, 1),0,9999)
				if("trigger")
					program.trigger_code = clamp(round(new_code, 1),0,9999)
			. = TRUE
		if("set_extra_setting")
			if(!program.extra_settings[params["target_setting"]])
				return
			program.set_extra_setting(params["target_setting"], params["value"])
			playsound(src, "terminal_type", 25, FALSE)
			. = TRUE
		if("set_restart_timer")
			var/timer = text2num(params["delay"])
			if(!isnull(timer))
				playsound(src, "terminal_type", 25, FALSE)
				timer = clamp(round(timer, 1), 0, 3600)
				timer *= 10 //convert to deciseconds
				program.timer_restart = timer
			. = TRUE
		if("set_shutdown_timer")
			var/timer = text2num(params["delay"])
			if(!isnull(timer))
				playsound(src, "terminal_type", 25, FALSE)
				timer = clamp(round(timer, 1), 0, 3600)
				timer *= 10 //convert to deciseconds
				program.timer_shutdown = timer
			. = TRUE
		if("set_trigger_timer")
			var/timer = text2num(params["delay"])
			if(!isnull(timer))
				playsound(src, "terminal_type", 25, FALSE)
				timer = clamp(round(timer, 1), 0, 3600)
				timer *= 10 //convert to deciseconds
				program.timer_trigger = timer
			. = TRUE
		if("set_timer_trigger_delay")
			var/timer = text2num(params["delay"])
			if(!isnull(timer))
				playsound(src, "terminal_type", 25, FALSE)
				timer = clamp(round(timer, 1), 0, 3600)
				timer *= 10 //convert to deciseconds
				program.timer_trigger_delay = timer
			. = TRUE

/obj/machinery/computer/nanite_cloud_controller/Hear(message, atom/movable/speaker, message_language, raw_message, radio_freq, list/spans, list/message_mods = list(), message_range = 0)
	. = ..()
	var/static/regex/when = regex("(?:^\\W*when|when\\W*$)", "i") //starts or ends with when
	if(findtext(raw_message, when) && !istype(speaker, /obj/machinery/computer/nanite_cloud_controller) && COOLDOWN_FINISHED(src, nanite_programmer))
		say("When you code it!!")
		COOLDOWN_START(src, nanite_programmer, 5 SECONDS)

/datum/nanite_cloud_backup
	var/cloud_id = 0
	var/datum/component/nanites/nanites
	var/obj/machinery/computer/nanite_cloud_controller/storage

/datum/nanite_cloud_backup/New(obj/machinery/computer/nanite_cloud_controller/_storage)
	storage = _storage
	storage.cloud_backups += src
	SSnanites.cloud_backups += src

/datum/nanite_cloud_backup/Destroy()
	storage.cloud_backups -= src
	SSnanites.cloud_backups -= src
	return ..()
