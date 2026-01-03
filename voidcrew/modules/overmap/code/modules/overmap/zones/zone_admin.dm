// Admin verbs for the overmap zone system

ADMIN_VERB(check_zone_status, R_DEBUG|R_ADMIN, "Zone Status", "Shows current zone system status.", ADMIN_CATEGORY_DEBUG)
	if(!SSovermap_zones.zones_active)
		to_chat(user, span_warning("Zone system is not active!"))
		return

	to_chat(user, span_boldnotice("=== Overmap Zone Status ==="))
	to_chat(user, span_notice("Zone layout: Concentric rings based on distance from sun"))
	to_chat(user, span_notice("Inner ring (<33%): Lawless - Dangerous (weapons + interdiction)"))
	to_chat(user, span_notice("Middle ring (33-66%): Contested - Caution (interdiction only)"))
	to_chat(user, span_notice("Outer ring (>66%): Neutral - Safe (no PvP)"))
	to_chat(user, span_notice("---"))
	to_chat(user, span_notice("Lawless zone turfs: [length(SSovermap_zones.zone_red.turfs)]"))
	to_chat(user, span_notice("Contested zone turfs: [length(SSovermap_zones.zone_yellow.turfs)]"))
	to_chat(user, span_notice("Neutral zone turfs: [length(SSovermap_zones.zone_green.turfs)]"))
	BLACKBOX_LOG_ADMIN_VERB("Zone Status")
