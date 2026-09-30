// VOIDCREW: record targeting decisions, including aggro before any attack lands.
/mob/living/simple_animal/hostile/megafauna/add_target(new_target)
	var/atom/previous_target = target
	. = ..()
	if(previous_target != target)
		log_aggro_change(previous_target, target)

/mob/living/simple_animal/hostile/megafauna/handle_target_del(datum/source)
	SIGNAL_HANDLER
	// The parent clears target before calling LoseTarget(), so capture it now.
	if(target == source)
		log_aggro_change(target, null)
	return ..()

/mob/living/simple_animal/hostile/megafauna/proc/aggro_target_description(atom/subject)
	if(!subject)
		return "none"
	var/description = "[key_name_and_tag(subject)] [REF(subject)] at [loc_name(subject)]; [overmap_zone_log_context(subject)]"
	if(ismecha(subject))
		var/obj/vehicle/sealed/mecha/mech = subject
		var/list/pilots = list()
		for(var/mob/pilot as anything in mech.occupants)
			pilots += key_name_and_tag(pilot)
		description += "; occupants: [length(pilots) ? jointext(pilots, ", ") : "none"]"
	return description

/mob/living/simple_animal/hostile/megafauna/proc/log_aggro_change(atom/previous_target, atom/new_target)
	var/action = new_target ? (previous_target ? "switched target" : "acquired target") : "lost target"
	var/message = "\[MEGAFAUNA AGGRO\] [action]; from: [aggro_target_description(previous_target)]; to: [aggro_target_description(new_target)]"
	log_message(message, LOG_ATTACK, color = "blue")
	// Keep the same event in the involved players' individual logs, too.
	var/list/mob/observers = list()
	for(var/atom/subject as anything in list(previous_target, new_target))
		if(ismob(subject))
			observers |= subject
		else if(ismecha(subject))
			var/obj/vehicle/sealed/mecha/mech = subject
			for(var/mob/pilot as anything in mech.occupants)
				observers |= pilot
	for(var/mob/observer as anything in observers)
		observer.log_message("[key_name_and_tag(src)] at [loc_name(src)]; [overmap_zone_log_context(src)]: [message]", LOG_ATTACK, color = "blue", log_globally = FALSE)
