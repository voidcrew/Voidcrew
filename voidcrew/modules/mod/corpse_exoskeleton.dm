// Ported from Monkestation (Monkestation/Monkestation2.0#9889).

///Corpse Exoskeleton - allows your MODsuit to stand up right whilst the person inside is dead. Great for MOD AIs, I guess!
/obj/item/mod/module/magboot/corpse_exoskeleton
	name = "MOD corpse exoskeleton module"
	desc = "An exosuit that goes around the whole body. Upon an internal health sensor detecting the user getting fatally injured, \
		or on a manual toggle, activates servos around the full body to ensure the user stays upright, come stun or death, the user remains vertical."
	icon_state = "bulwark"
	complexity = 2
	active_power_cost = DEFAULT_CHARGE_DRAIN * 0.4
	slowdown_active = 0.3
	incompatible_modules = list(/obj/item/mod/module/magboot/corpse_exoskeleton)
	active_traits = list(TRAIT_FORCED_STANDING)
	/// Whether it turns itself on when the wearer goes into crit.
	var/autotrigger = TRUE

/obj/item/mod/module/magboot/corpse_exoskeleton/get_configuration(mob/user)
	. = ..()
	.["autotrigger"] = add_ui_configuration("Autotrigger", "bool", autotrigger)

/obj/item/mod/module/magboot/corpse_exoskeleton/configure_edit(key, value)
	switch(key)
		if("autotrigger")
			autotrigger = text2num(value)

/obj/item/mod/module/magboot/corpse_exoskeleton/on_part_activation()
	RegisterSignal(mod.wearer, COMSIG_LIVING_HEALTH_UPDATE, PROC_REF(health_check))

/obj/item/mod/module/magboot/corpse_exoskeleton/on_part_deactivation(deleting = FALSE)
	UnregisterSignal(mod.wearer, COMSIG_LIVING_HEALTH_UPDATE)

/obj/item/mod/module/magboot/corpse_exoskeleton/proc/health_check(datum/source)
	SIGNAL_HANDLER
	if(active || !autotrigger || mod.wearer.health > mod.wearer.crit_threshold)
		return
	INVOKE_ASYNC(src, PROC_REF(dead_reckoning))

/// They're going down: catches them.
/obj/item/mod/module/magboot/corpse_exoskeleton/proc/dead_reckoning()
	if(active || !mod?.wearer)
		return
	if(activate())
		mod.wearer.visible_message(
			span_danger("[src] inside [mod.wearer]'s [mod.name] activates!"),
			span_danger("Your body is quickly caught by your suit."),
		)
		playsound(src, 'sound/vehicles/mecha/mechmove04.ogg', 50, TRUE)
	else
		mod.wearer.visible_message(span_danger("[src] inside [mod.wearer]'s [mod.name] fails to actuate."))
		playsound(src, 'sound/vehicles/mecha/mechmove04.ogg', 25, TRUE)

/datum/design/module/mod_springlock
	name = "Springlock Module"
	id = "mod_springlock"
	materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 2.5, /datum/material/titanium = HALF_SHEET_MATERIAL_AMOUNT, /datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT * 1.5)
	build_path = /obj/item/mod/module/springlock
	category = list(
		RND_CATEGORY_MODSUIT_MODULES + RND_SUBCATEGORY_MODSUIT_MODULES_SERVICE
	)
	departmental_flags = DEPARTMENT_BITFLAG_SERVICE

/datum/design/module/mod_corpse
	name = "Corpse Exoskeleton Module"
	id = "mod_corpse"
	materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 2.5, /datum/material/titanium = HALF_SHEET_MATERIAL_AMOUNT, /datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT * 1.5)
	build_path = /obj/item/mod/module/magboot/corpse_exoskeleton
	category = list(
		RND_CATEGORY_MODSUIT_MODULES + RND_SUBCATEGORY_MODSUIT_MODULES_SERVICE
	)

/// Unlocked by analysing either module, found in maintenance.
/datum/techweb_node/mod_mortality
	id = TECHWEB_NODE_MOD_MORTALITY
	display_name = "MOD Mortality Modules"
	description = "Obsolete modules involving the users body, for worse or even worse. Pulled from the market for being too dangerous to users, or for being utterly useless."
	prereq_ids = list(TECHWEB_NODE_MOD_EQUIP)
	design_ids = list(
		"mod_springlock",
		"mod_corpse",
	)
	required_items_to_unlock = list(
		/obj/item/mod/module/springlock,
		/obj/item/mod/module/magboot/corpse_exoskeleton,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_1_POINTS / 4)
	hidden = TRUE
