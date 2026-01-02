// Admin verbs for the overmap zone system

ADMIN_VERB(force_zone_shift, R_DEBUG|R_ADMIN, "Force Zone Shift", "Forces an immediate zone rotation on the overmap.", ADMIN_CATEGORY_DEBUG)
	if(!SSovermap_zones.zones_active)
		to_chat(user, span_warning("Zone system is not active!"))
		return

	SSovermap_zones.force_rotation()
	message_admins("[key_name_admin(user)] forced an overmap zone shift.")
	log_admin("[key_name(user)] forced an overmap zone shift.")
	BLACKBOX_LOG_ADMIN_VERB("Force Zone Shift")

ADMIN_VERB(set_zone_rotation, R_DEBUG|R_ADMIN, "Set Zone Rotation", "Sets the zone rotation angle (0-359 degrees).", ADMIN_CATEGORY_DEBUG)
	if(!SSovermap_zones.zones_active)
		to_chat(user, span_warning("Zone system is not active!"))
		return

	var/new_angle = input(user, "Enter rotation angle (0-359):", "Zone Rotation", SSovermap_zones.rotation_angle) as null|num
	if(isnull(new_angle))
		return

	new_angle = clamp(new_angle, 0, 359)
	SSovermap_zones.set_rotation(new_angle)
	message_admins("[key_name_admin(user)] set overmap zone rotation to [new_angle] degrees.")
	log_admin("[key_name(user)] set overmap zone rotation to [new_angle] degrees.")
	BLACKBOX_LOG_ADMIN_VERB("Set Zone Rotation")

ADMIN_VERB(check_zone_status, R_DEBUG|R_ADMIN, "Zone Status", "Shows current zone system status.", ADMIN_CATEGORY_DEBUG)
	if(!SSovermap_zones.zones_active)
		to_chat(user, span_warning("Zone system is not active!"))
		return

	var/time_remaining = SSovermap_zones.get_time_until_rotation()
	var/minutes = floor(time_remaining / 60)
	var/seconds = time_remaining % 60

	to_chat(user, span_boldnotice("=== Overmap Zone Status ==="))
	to_chat(user, span_notice("Current rotation angle: [SSovermap_zones.rotation_angle] degrees"))
	to_chat(user, span_notice("Time until next shift: [minutes]m [seconds]s"))
	to_chat(user, span_notice("Green zone turfs: [length(SSovermap_zones.zone_green.turfs)]"))
	to_chat(user, span_notice("Yellow zone turfs: [length(SSovermap_zones.zone_yellow.turfs)]"))
	to_chat(user, span_notice("Red zone turfs: [length(SSovermap_zones.zone_red.turfs)]"))
	BLACKBOX_LOG_ADMIN_VERB("Zone Status")
